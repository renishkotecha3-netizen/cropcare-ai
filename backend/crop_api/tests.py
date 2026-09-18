import io
import tempfile
from datetime import timedelta
from unittest.mock import patch
import numpy as np
from PIL import Image
from django.test import TestCase, override_settings
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from rest_framework.test import APIClient
from .authentication import issue_session
from .models import Farmer, Scan, Notification
from .services.inference import interpret, labels, prepare_image, ModelUnavailable
from .services.alerts import create_due_reminders, distance_km, nearby_summary
from .services.weather import get_weather, advisory


def photo():
    buffer = io.BytesIO()
    Image.new('RGB',(300,300),(25,160,40)).save(buffer,format='PNG')
    return SimpleUploadedFile('leaf.png',buffer.getvalue(),content_type='image/png')


def predicted(label='Tomato_Late_blight',confidence=92):
    names = labels()
    values = np.full(len(names),(1-confidence/100)/(len(names)-1))
    values[names.index(label)] = confidence/100
    return interpret(values,names,'Tomato' if label.startswith('Tomato') else 'Auto')


@override_settings(SECURE_SSL_REDIRECT=False, ALLOWED_HOSTS=['testserver'])
class ApiTests(TestCase):
    def setUp(self):
        cache.clear()
        self.temp = tempfile.TemporaryDirectory()
        self.media = override_settings(MEDIA_ROOT=self.temp.name)
        self.media.enable()
        self.addCleanup(self.media.disable)
        self.addCleanup(self.temp.cleanup)
        self.user = Farmer.objects.create_user(username='one@example.com',email='one@example.com',password='A-strong-secret-539!',full_name='Farmer One',latitude=23.,longitude=72.,share_reports=True)
        self.other = Farmer.objects.create_user(username='two@example.com',email='two@example.com',password='Other-secret-984!',full_name='Farmer Two',latitude=23.01,longitude=72.01,nearby_alerts=True)
        self.client = APIClient()
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+issue_session(self.user))
        self.other_client = APIClient()
        self.other_client.credentials(HTTP_AUTHORIZATION='Bearer '+issue_session(self.other))

    def scan(self, result=None, **fields):
        with patch('crop_api.views.predict',return_value=result or predicted()):
            return self.client.post('/api/scans/',{'image':photo(),'crop':'Tomato',**fields},format='multipart')

    def test_registration_login_case_insensitive_and_logout_revocation(self):
        client = APIClient()
        response = client.post('/api/auth/register/',{'email':'New@Example.com','full_name':'New Farmer','password':'Test-strong-7842!'},format='json')
        self.assertEqual(response.status_code,201,response.data)
        user = Farmer.objects.get(email='new@example.com')
        self.assertTrue(user.check_password('Test-strong-7842!'))
        self.assertFalse(user.share_reports)
        self.assertEqual(client.post('/api/auth/login/',{'email':'NEW@example.com','password':'Test-strong-7842!'},format='json').status_code,200)
        client.credentials(HTTP_AUTHORIZATION='Bearer '+response.data['token'])
        self.assertEqual(client.post('/api/auth/logout/').status_code,204)
        self.assertEqual(client.get('/api/profile/').status_code,401)

    def test_private_endpoints_require_login(self):
        anonymous = APIClient()
        for endpoint in ['scans/','profile/','nearby/','weather/','notifications/','reminders/']:
            self.assertEqual(anonymous.get('/api/'+endpoint).status_code,401)

    def test_weak_password_rejected(self):
        result = APIClient().post('/api/auth/register/',{'email':'weak@example.com','full_name':'Weak','password':'12345678'},format='json')
        self.assertEqual(result.status_code,400)

    def test_scan_history_and_private_image(self):
        response = self.scan()
        self.assertEqual(response.status_code,201,response.data)
        self.assertEqual(response.data['condition'],'Tomato Late blight')
        self.assertEqual(self.client.get('/api/scans/').data['count'],1)
        self.assertEqual(self.other_client.get('/api/scans/').data['count'],0)
        pk = response.data['id']
        self.assertEqual(self.other_client.get(f'/api/scans/{pk}/').status_code,404)
        self.assertEqual(self.other_client.get(f'/api/scans/{pk}/image/').status_code,404)
        image = self.client.get(f'/api/scans/{pk}/image/')
        self.assertEqual(image.status_code,200)
        self.assertEqual(image['Cache-Control'],'private, no-store')
        self.assertNotIn('latitude',response.data)
        image.close()

    def test_invalid_image_fails_before_model(self):
        with patch('crop_api.views.predict') as mock:
            response = self.client.post('/api/scans/',{'image':SimpleUploadedFile('bad.jpg',b'not an image'),'crop':'Tomato'},format='multipart')
        self.assertEqual(response.status_code,400)
        mock.assert_not_called()

    def test_missing_model_never_fabricates_result(self):
        with patch('crop_api.views.predict',side_effect=ModelUnavailable('Model is unavailable.')):
            response = self.client.post('/api/scans/',{'image':photo()},format='multipart')
        self.assertEqual(response.status_code,503)
        self.assertEqual(Scan.objects.count(),0)

    def test_nearby_reports_consent_radius_and_anonymity(self):
        response = self.scan()
        self.assertEqual(response.status_code,201)
        self.assertEqual(Notification.objects.filter(user=self.other,kind='nearby').count(),1)
        data = self.other_client.get('/api/nearby/').data
        self.assertEqual(data['results'][0]['reports'],1)
        self.assertNotIn('one@example',str(data))
        for key in ['latitude','longitude','image','user_id','scan_id']:
            self.assertNotIn(key,data['results'][0])
        self.other.latitude=10;self.other.longitude=10;self.other.save()
        self.assertEqual(nearby_summary(self.other)['results'],[])
        self.client.patch('/api/profile/',{'share_reports':False},format='json')
        self.assertFalse(Scan.objects.get().shared)

    def test_low_confidence_healthy_and_nutrition_do_not_broadcast(self):
        for result in [predicted(confidence=69),predicted('Tomato_healthy'),predicted('Tomato_Nitrogen Deficiency')]:
            self.assertEqual(self.scan(result).status_code,201)
        self.assertEqual(Notification.objects.filter(kind='nearby').count(),0)
        self.assertEqual(nearby_summary(self.other)['results'],[])

    def test_nearby_deduplicated_per_disease_per_day(self):
        self.scan();self.scan()
        self.assertEqual(Notification.objects.filter(kind='nearby',user=self.other).count(),1)

    def test_no_sharing_or_no_recipient_consent_means_no_alert(self):
        self.user.share_reports=False;self.user.save()
        self.scan()
        self.assertEqual(Notification.objects.count(),0)
        self.user.share_reports=True;self.user.save()
        self.other.nearby_alerts=False;self.other.save()
        self.scan()
        self.assertEqual(Notification.objects.count(),0)

    def test_reminder_due_boundary_and_idempotency(self):
        response=self.scan();scan=Scan.objects.get(pk=response.data['id'])
        self.assertAlmostEqual((scan.follow_up_due-scan.created_at).total_seconds(),7*86400,delta=2)
        self.assertEqual(create_due_reminders(self.user),0)
        Scan.objects.filter(pk=scan.pk).update(follow_up_due=timezone.now()-timedelta(seconds=1))
        self.assertEqual(create_due_reminders(self.user),1)
        self.assertEqual(create_due_reminders(self.user),0)
        self.assertEqual(self.client.get('/api/notifications/').data['count'],1)

    def test_follow_up_links_owner_and_stops_original_reminder(self):
        first=self.scan().data
        cross=self.other_client.post('/api/scans/',{'image':photo(),'parent_id':first['id']},format='multipart')
        self.assertEqual(cross.status_code,404)
        follow=self.scan(parent_id=first['id'])
        self.assertEqual(follow.status_code,201,follow.data)
        self.assertEqual(str(follow.data['parent_id']),first['id'])
        self.assertTrue(Scan.objects.get(pk=first['id']).follow_up_done)
        self.assertEqual(self.scan(parent_id=first['id']).status_code,400)

    def test_resolved_stops_follow_up_and_nearby_visibility(self):
        first=self.scan().data
        self.assertEqual(self.client.patch(f"/api/scans/{first['id']}/",{'outcome':'resolved'},format='json').status_code,200)
        self.assertEqual(self.client.get('/api/reminders/').data['results'],[])
        self.assertEqual(nearby_summary(self.other)['results'],[])

    def test_zero_coordinates_valid_and_nonfinite_rejected(self):
        self.assertEqual(self.client.patch('/api/profile/',{'latitude':0,'longitude':0},format='json').status_code,200)
        for data in [{'latitude':91,'longitude':0},{'latitude':'NaN','longitude':0},{'latitude':None}]:
            self.assertEqual(self.client.patch('/api/profile/',data,format='json').status_code,400)
        self.assertAlmostEqual(distance_km(0,179.99,0,-179.99),2.2239,places=2)

    def test_notification_ownership_and_read(self):
        self.scan();note=Notification.objects.get(user=self.other)
        url=f'/api/notifications/{note.pk}/read/'
        self.assertEqual(self.client.post(url).status_code,404)
        self.assertEqual(self.other_client.post(url).status_code,200)
        note.refresh_from_db();self.assertIsNotNone(note.read_at)

    def test_password_change_revokes_other_sessions(self):
        extra=APIClient();extra.credentials(HTTP_AUTHORIZATION='Bearer '+issue_session(self.user))
        response=self.client.post('/api/auth/password/',{'current_password':'A-strong-secret-539!','new_password':'Changed-secret-953!'},format='json')
        self.assertEqual(response.status_code,200)
        self.assertEqual(extra.get('/api/profile/').status_code,401)
        self.client.credentials(HTTP_AUTHORIZATION='Bearer '+response.data['token'])
        self.assertEqual(self.client.get('/api/profile/').status_code,200)

    def test_delete_removes_photo_and_history(self):
        response=self.scan();obj=Scan.objects.get(pk=response.data['id']);path=obj.image.path
        self.assertEqual(self.client.delete(f'/api/scans/{obj.pk}/').status_code,204)
        from pathlib import Path
        self.assertFalse(Path(path).exists())
        self.assertEqual(Scan.objects.count(),0)

    def test_weather_location_required(self):
        self.user.latitude=None;self.user.longitude=None;self.user.save()
        self.assertEqual(self.client.get('/api/weather/').data['status'],'location_required')

    def test_weather_context_is_specific_to_authenticated_farmer(self):
        self.scan()
        payload={'status':'available','current':{'relative_humidity_2m':90,'precipitation':1},'advice':[]}
        with patch('crop_api.views.get_weather',return_value=payload):
            own=self.client.get('/api/weather/').data
            other=self.other_client.get('/api/weather/').data
        self.assertEqual(own['crop_context']['condition'],'Tomato Late blight')
        self.assertIn('wet conditions',own['crop_context']['advice'])
        self.assertNotIn('crop_context',other)
        self.assertNotIn('crop_context',payload)


class InferenceAndWeatherTests(TestCase):
    def setUp(self):
        cache.clear()

    def test_supplied_labels_and_preprocessing(self):
        self.assertEqual(len(labels()),33)
        buffer=io.BytesIO();Image.new('RGB',(300,250),(255,128,0)).save(buffer,format='PNG');buffer.seek(0)
        batch=prepare_image(buffer)
        self.assertEqual(batch.shape,(1,224,224,3))
        self.assertEqual(batch.dtype,np.float32)
        self.assertEqual(batch[0,0,0,0],255)

    def test_threshold_and_crop_mismatch(self):
        self.assertEqual(predicted(confidence=59)['status'],'uncertain')
        self.assertEqual(predicted(confidence=69)['status'],'issue')
        self.assertEqual(predicted('Tomato_healthy')['status'],'healthy')
        vector=np.zeros(33);vector[labels().index('Potato_Early_blight')]=1
        self.assertEqual(interpret(vector,labels(),'Tomato')['status'],'uncertain')
        with self.assertRaises(ModelUnavailable):interpret(np.full(33,np.nan),labels())

    def test_weather_success_and_cache(self):
        payload={'current':{'temperature_2m':20,'relative_humidity_2m':90,'precipitation':1,'wind_speed_10m':17,'time':'2026-09-18T12:00'},
                 'daily':{'time':['2026-09-18'],'temperature_2m_min':[19],'temperature_2m_max':[24],'precipitation_sum':[3],'precipitation_probability_max':[80]}}
        with patch('crop_api.services.weather.requests.get') as call:
            call.return_value.json.return_value=payload
            value=get_weather(23,72)
            self.assertEqual(value['status'],'available')
            self.assertTrue(any('humid' in s for s in value['advice']))
            self.assertEqual(get_weather(23,72),value)
            call.assert_called_once()

    def test_weather_outage_and_missing_values_not_fabricated(self):
        import requests
        with patch('crop_api.services.weather.requests.get',side_effect=requests.Timeout):
            value=get_weather(0,0)
        self.assertEqual(value['status'],'unavailable')
        self.assertEqual(value['advice'],[])
        with patch('crop_api.services.weather.requests.get') as call:
            call.return_value.json.return_value={'current':{'temperature_2m':None}}
            self.assertEqual(get_weather(0,0)['status'],'unavailable')
