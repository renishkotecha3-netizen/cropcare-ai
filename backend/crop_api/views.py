from datetime import timedelta
from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.db import transaction, IntegrityError
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, serializers, status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from .authentication import issue_session
from .models import Scan, Notification, Device
from .serializers import ProfileSerializer, RegistrationSerializer, UploadSerializer, ScanSerializer, OutcomeSerializer, NotificationSerializer
from .services.inference import predict, ModelUnavailable
from .services.alerts import nearby_summary, publish_nearby, create_due_reminders
from .services.weather import get_weather, crop_advice


class RegisterView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'auth'
    def post(self, request):
        serializer = RegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            with transaction.atomic():
                user = serializer.save()
                token = issue_session(user)
        except IntegrityError:
            raise serializers.ValidationError({'email': 'An account with this email already exists.'})
        return Response({'token': token,'user': ProfileSerializer(user).data}, status=201)


class LoginView(RegisterView):
    def post(self, request):
        email = str(request.data.get('email','')).strip().lower()
        password = request.data.get('password','')
        if not isinstance(password,str) or len(password)>128 or len(email)>150:
            raise serializers.ValidationError('Invalid login details.')
        user = authenticate(username=email,password=password)
        if not user:
            return Response({'detail':'Email or password is incorrect.'},status=401)
        return Response({'token':issue_session(user),'user':ProfileSerializer(user).data})


class LogoutView(APIView):
    def post(self, request):
        if request.data.get('device_token'):
            request.user.devices.filter(token=request.data['device_token']).delete()
        request.auth.delete()
        return Response(status=204)


class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = ProfileSerializer
    http_method_names = ['get','patch','head','options']
    def get_object(self):
        return self.request.user


class PasswordView(APIView):
    def post(self, request):
        current = request.data.get('current_password','')
        new = request.data.get('new_password','')
        if not isinstance(current,str) or not request.user.check_password(current):
            raise serializers.ValidationError({'current_password':'Current password is incorrect.'})
        if not isinstance(new,str) or len(new)>128:
            raise serializers.ValidationError({'new_password':'Use a password of at most 128 characters.'})
        try:
            validate_password(new,request.user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({'new_password':list(exc.messages)})
        with transaction.atomic():
            request.user.set_password(new)
            request.user.save(update_fields=['password'])
            request.user.apisession_set.all().delete()
            token = issue_session(request.user)
        return Response({'token':token})


class ScanListView(generics.ListCreateAPIView):
    serializer_class = ScanSerializer
    def get_queryset(self):
        qs = self.request.user.scans.all()
        if self.request.query_params.get('status') in ['healthy','issue','uncertain']:
            qs = qs.filter(status=self.request.query_params['status'])
        if self.request.query_params.get('search'):
            qs = qs.filter(condition__icontains=self.request.query_params['search'][:120])
        return qs

    def get_throttles(self):
        if self.request.method == 'POST':
            self.throttle_scope = 'scan'
            return [ScopedRateThrottle()]
        return super().get_throttles()

    def create(self, request, *args, **kwargs):
        upload = UploadSerializer(data=request.data)
        upload.is_valid(raise_exception=True)
        data = upload.validated_data
        parent = None
        if data.get('parent_id'):
            parent = get_object_or_404(Scan,user=request.user,id=data['parent_id'])
            if parent.follow_up_done or parent.outcome == 'resolved':
                raise serializers.ValidationError('This check is already complete. Start a new scan instead.')
            if data['crop'] != 'Auto' and parent.crop != data['crop']:
                raise serializers.ValidationError('A follow-up must use the same crop as the original scan.')
            data['crop'] = parent.crop
        try:
            result = predict(data['image'],data['crop'])
        except ModelUnavailable as exc:
            return Response({'detail':str(exc),'code':'model_unavailable'},status=503)
        scan = Scan(user=request.user,notes=data['notes'],**result)
        if request.user.latitude is not None:
            scan.latitude,scan.longitude = round(request.user.latitude,2),round(request.user.longitude,2)
        scan.shared = request.user.share_reports and scan.latitude is not None
        if scan.status == 'issue':
            scan.follow_up_due = timezone.now()+timedelta(days=7)
        try:
            with transaction.atomic():
                if parent:
                    parent = Scan.objects.select_for_update().get(pk=parent.pk)
                    if parent.follow_up_done or parent.outcome == 'resolved':
                        raise serializers.ValidationError('This check is already complete.')
                    parent.follow_up_done = True
                    parent.save(update_fields=['follow_up_done'])
                    parent.notification_set.filter(kind='followup').update(read_at=timezone.now())
                    scan.parent = parent
                data['image'].seek(0)
                scan.image.save('leaf.jpg',data['image'],save=False)
                scan.save()
                publish_nearby(scan)
        except Exception:
            if scan.image.name:
                scan.image.delete(save=False)
            raise
        return Response(ScanSerializer(scan,context={'request':request}).data,status=201)


class ScanDetailView(generics.RetrieveUpdateDestroyAPIView):
    http_method_names = ['get','patch','delete','head','options']
    def get_queryset(self):
        return self.request.user.scans.all()
    def get_serializer_class(self):
        return OutcomeSerializer if self.request.method=='PATCH' else ScanSerializer
    def perform_update(self, serializer):
        obj = serializer.save()
        if obj.outcome == 'resolved':
            obj.follow_up_done = True
            obj.save(update_fields=['follow_up_done'])
            obj.notification_set.filter(kind='followup').update(read_at=timezone.now())
    def perform_destroy(self, instance):
        image = instance.image
        instance.delete()
        image.delete(save=False)


class ScanImageView(APIView):
    def get(self, request, pk):
        scan = get_object_or_404(Scan,pk=pk,user=request.user)
        response = FileResponse(scan.image.open('rb'),content_type='image/jpeg')
        response['Cache-Control'] = 'private, no-store'
        return response


class ReminderView(APIView):
    def get(self, request):
        create_due_reminders(request.user)
        scans = request.user.scans.filter(follow_up_done=False,follow_up_due__isnull=False).exclude(outcome='resolved').order_by('follow_up_due')
        return Response({'results':[{'id':str(s.id),'condition':s.condition,'due_at':s.follow_up_due} for s in scans[:60]]})


class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    def get_queryset(self):
        create_due_reminders(self.request.user)
        return self.request.user.notifications.all()


class ReadNotificationView(APIView):
    def post(self, request, pk):
        obj = get_object_or_404(Notification,user=request.user,pk=pk)
        if not obj.read_at:
            obj.read_at = timezone.now()
            obj.save(update_fields=['read_at'])
        return Response({'read_at':obj.read_at})


class NearbyView(APIView):
    def get(self, request):
        return Response(nearby_summary(request.user))


class WeatherView(APIView):
    def get(self, request):
        if request.user.latitude is None or request.user.longitude is None:
            return Response({'status':'location_required','detail':'Save your farm location in Profile to see local weather.','advice':[]})
        result = dict(get_weather(request.user.latitude,request.user.longitude))
        recent = request.user.scans.filter(status='issue', created_at__gte=timezone.now()-timedelta(days=30)).exclude(outcome='resolved').first()
        if recent and result['status'] == 'available':
            result['crop_context'] = crop_advice(recent, result['current'])
        return Response(result)


class DeviceView(APIView):
    def post(self, request):
        token = request.data.get('token','')
        if not isinstance(token,str) or not 20 <= len(token) <= 512:
            raise serializers.ValidationError('Invalid device token.')
        Device.objects.update_or_create(token=token,defaults={'user':request.user})
        return Response(status=204)
    def delete(self, request):
        request.user.devices.filter(token=request.data.get('token','')).delete()
        return Response(status=204)


class HealthView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []
    def get(self,request):
        return Response({'status':'ok','service':'CropCare AI API'})
