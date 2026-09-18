import uuid
from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.db.models import Q


class Farmer(AbstractUser):
    email = models.EmailField(unique=True)
    full_name = models.CharField(max_length=100)
    village = models.CharField(max_length=120, blank=True)
    farm_name = models.CharField(max_length=120, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    location_updated_at = models.DateTimeField(null=True, blank=True)
    share_reports = models.BooleanField(default=False)
    nearby_alerts = models.BooleanField(default=False)
    alert_radius_km = models.PositiveSmallIntegerField(default=5)


class ApiSession(models.Model):
    token_hash = models.CharField(max_length=64, primary_key=True)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    expires_at = models.DateTimeField(db_index=True)


def scan_image_path(instance, filename):
    return f'leaves/{instance.user_id}/{instance.id}.jpg'


class Scan(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='scans')
    image = models.ImageField(upload_to=scan_image_path)
    crop = models.CharField(max_length=20)
    predicted_label = models.CharField(max_length=120)
    condition = models.CharField(max_length=160)
    confidence = models.FloatField()
    status = models.CharField(max_length=15)  # healthy / issue / uncertain
    category = models.CharField(max_length=20, default='unknown')
    recommendations = models.JSONField(default=list)
    alternatives = models.JSONField(default=list)
    notes = models.TextField(blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    shared = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    follow_up_due = models.DateTimeField(null=True, blank=True, db_index=True)
    follow_up_done = models.BooleanField(default=False)
    parent = models.OneToOneField('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='recheck')
    outcome = models.CharField(max_length=20, default='open', choices=[(x,x) for x in ['open','improved','unchanged','worse','resolved']])

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['user', '-created_at']), models.Index(fields=['shared', 'created_at'])]
        constraints = [models.CheckConstraint(condition=Q(confidence__gte=0, confidence__lte=100), name='confidence_range')]


class Notification(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    scan = models.ForeignKey(Scan, on_delete=models.CASCADE, null=True, blank=True)
    event_key = models.CharField(max_length=180)
    kind = models.CharField(max_length=20)
    title = models.CharField(max_length=160)
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    read_at = models.DateTimeField(null=True, blank=True)
    pushed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        constraints = [models.UniqueConstraint(fields=['user', 'event_key'], name='unique_user_event')]


class Device(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='devices')
    token = models.CharField(max_length=512, unique=True)
    updated_at = models.DateTimeField(auto_now=True)

