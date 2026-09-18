from collections import defaultdict
from datetime import timedelta
from math import radians, sin, cos, atan2, sqrt
from django.utils import timezone
from crop_api.models import Farmer, Scan, Notification


def distance_km(lat1, lon1, lat2, lon2):
    dlat, dlon = radians(lat2-lat1), radians(lon2-lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1))*cos(radians(lat2))*sin(dlon/2)**2
    return 6371.0088 * 2 * atan2(sqrt(max(0, a)), sqrt(max(0, 1-a)))


def shareable_scans():
    return Scan.objects.filter(shared=True, user__share_reports=True, status='issue', confidence__gte=80,
        latitude__isnull=False, longitude__isnull=False, parent__isnull=True,
        created_at__gte=timezone.now()-timedelta(days=14)).exclude(category__in=['nutrition','unknown']).exclude(outcome='resolved')


def nearby_summary(user):
    if user.latitude is None or user.longitude is None:
        return {'status': 'location_required', 'results': []}
    grouped = defaultdict(lambda: {'reports': 0, 'last_reported': None})
    for scan in shareable_scans().exclude(user=user).iterator():
        if distance_km(user.latitude, user.longitude, scan.latitude, scan.longitude) <= user.alert_radius_km:
            item = grouped[(scan.crop, scan.condition)]
            item['reports'] += 1
            item['last_reported'] = max(item['last_reported'] or scan.created_at, scan.created_at)
    return {'status': 'available', 'radius_km': user.alert_radius_km, 'window_days': 14,
            'notice': 'Possible AI-reported cases, not confirmed outbreaks. Inspect your own plants before treatment.',
            'results': [{'crop': key[0], 'condition': key[1], **value} for key,value in grouped.items()]}


def publish_nearby(scan):
    if not shareable_scans().filter(pk=scan.pk).exists():
        return
    for user in Farmer.objects.filter(nearby_alerts=True, is_active=True, latitude__isnull=False, longitude__isnull=False).exclude(pk=scan.user_id).iterator():
        if distance_km(user.latitude,user.longitude,scan.latitude,scan.longitude) <= user.alert_radius_km:
            # At most one alert for the same condition per recipient per UTC day.
            Notification.objects.get_or_create(user=user, event_key=f'nearby:{scan.predicted_label}:{timezone.now().date()}', defaults={
                'kind': 'nearby', 'title': f'Crop watch within {user.alert_radius_km} km',
                'body': f'A possible {scan.condition} case was reported nearby. Inspect your own crop. Use your own analysis and local advice before treatment.',
            })


def create_due_reminders(user=None):
    scans = Scan.objects.filter(follow_up_due__lte=timezone.now(), follow_up_done=False).exclude(outcome='resolved')
    if user is not None:
        scans = scans.filter(user=user)
    count = 0
    for scan in scans.iterator():
        _, created = Notification.objects.get_or_create(user=scan.user, event_key=f'followup:{scan.id}', defaults={
            'kind': 'followup', 'scan': scan, 'title': 'How is your plant now?',
            'body': f'Your seven-day check for {scan.condition} is due. Has it improved? Add a new leaf photo and record your progress.',
        })
        count += int(created)
    return count
