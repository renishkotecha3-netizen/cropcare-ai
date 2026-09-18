import logging
from datetime import timedelta
from django.conf import settings
from django.utils import timezone
from crop_api.models import Notification

logger = logging.getLogger(__name__)


def send_pending():
    if not settings.FCM_ENABLED:
        return 0
    import firebase_admin
    from firebase_admin import messaging
    if not firebase_admin._apps:
        firebase_admin.initialize_app()
    sent = 0
    # One worker per database. At-least-once delivery; clients deduplicate by id.
    for item in Notification.objects.filter(pushed_at__isnull=True, read_at__isnull=True, created_at__gte=timezone.now()-timedelta(days=14)).select_related('user'):
        if item.kind == 'nearby' and not item.user.nearby_alerts:
            continue
        tokens = list(item.user.devices.values_list('token', flat=True))
        if not tokens:
            continue
        # Seven-day reminders use local OS scheduling on each phone to avoid duplicate banners.
        if item.kind == 'followup':
            item.pushed_at = timezone.now()
            item.save(update_fields=['pushed_at'])
            continue
        try:
            result = messaging.send_each_for_multicast(messaging.MulticastMessage(
                tokens=tokens[:500], notification=messaging.Notification(title=item.title, body=item.body),
                data={'notification_id': str(item.id), 'kind': item.kind},
                android=messaging.AndroidConfig(ttl=timedelta(days=2), notification=messaging.AndroidNotification(channel_id='cropcare_alerts', tag=str(item.id))),
            ))
            retry = False
            for token, response in zip(tokens, result.responses):
                if not response.success:
                    if isinstance(response.exception, messaging.UnregisteredError):
                        item.user.devices.filter(token=token).delete()
                    else:
                        retry = True
            if not retry:
                item.pushed_at = timezone.now()
                item.save(update_fields=['pushed_at'])
                sent += 1
        except Exception:
            logger.exception('Push failed for notification %s; it will be retried.', item.id)
    return sent
