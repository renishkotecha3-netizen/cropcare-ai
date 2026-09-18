import io
import math
import warnings
from PIL import Image, ImageOps, UnidentifiedImageError
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.files.base import ContentFile
from django.utils import timezone
from rest_framework import serializers
from .models import Farmer, Scan, Notification


class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Farmer
        fields = ['id','email','full_name','village','farm_name','latitude','longitude','location_updated_at','share_reports','nearby_alerts','alert_radius_km']
        read_only_fields = ['id','email','location_updated_at']

    def validate(self, attrs):
        lat = attrs.get('latitude', getattr(self.instance, 'latitude', None))
        lon = attrs.get('longitude', getattr(self.instance, 'longitude', None))
        if (lat is None) != (lon is None):
            raise serializers.ValidationError('Provide both latitude and longitude, or clear both.')
        if lat is not None and (not math.isfinite(lat) or not math.isfinite(lon) or not -90 <= lat <= 90 or not -180 <= lon <= 180):
            raise serializers.ValidationError('Invalid coordinates.')
        if 'latitude' in attrs or 'longitude' in attrs:
            attrs['location_updated_at'] = timezone.now() if lat is not None else None
        return attrs

    def validate_alert_radius_km(self, value):
        if not 1 <= value <= 50:
            raise serializers.ValidationError('Choose a radius from 1 to 50 km.')
        return value

    def update(self, instance, validated_data):
        result = super().update(instance, validated_data)
        if not result.share_reports:
            result.scans.filter(shared=True).update(shared=False)
        if not result.nearby_alerts:
            result.notifications.filter(kind='nearby', read_at__isnull=True).update(read_at=timezone.now())
        return result


class RegistrationSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=150)
    full_name = serializers.CharField(max_length=100)
    password = serializers.CharField(write_only=True, trim_whitespace=False, max_length=128)

    def validate_email(self, value):
        value = value.strip().lower()
        if Farmer.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return value

    def validate(self, attrs):
        user = Farmer(username=attrs['email'],email=attrs['email'],full_name=attrs['full_name'])
        try:
            validate_password(attrs['password'],user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({'password': list(exc.messages)})
        return attrs

    def create(self, validated_data):
        return Farmer.objects.create_user(username=validated_data['email'], **validated_data)


class UploadSerializer(serializers.Serializer):
    image = serializers.FileField()
    crop = serializers.ChoiceField(choices=['Auto','Tomato','Potato','Pepper'], default='Auto')
    notes = serializers.CharField(max_length=2000, required=False, allow_blank=True, default='')
    parent_id = serializers.UUIDField(required=False)

    def validate_image(self, upload):
        if upload.size > 8*1024*1024:
            raise serializers.ValidationError('Choose an image smaller than 8 MB.')
        try:
            with warnings.catch_warnings():
                warnings.simplefilter('error', Image.DecompressionBombWarning)
                with Image.open(upload) as original:
                    if original.format not in ['JPEG','PNG','WEBP']:
                        raise serializers.ValidationError('Use a JPEG, PNG or WebP photo.')
                    if original.width*original.height > 20_000_000 or min(original.size) < 64:
                        raise serializers.ValidationError('Use a clear photo between 64 pixels and 20 megapixels.')
                    original.load()
                    clean = ImageOps.exif_transpose(original).convert('RGB')
                    clean.thumbnail((2048,2048))
                    buffer = io.BytesIO()
                    clean.save(buffer, format='JPEG', quality=95)
            return ContentFile(buffer.getvalue(),name='leaf.jpg')
        except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning):
            raise serializers.ValidationError('The image could not be opened. Choose another leaf photo.')


class ScanSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    parent_id = serializers.UUIDField(read_only=True)
    class Meta:
        model = Scan
        fields = ['id','image_url','crop','predicted_label','condition','confidence','status','category','recommendations',
                  'alternatives','notes','created_at','follow_up_due','follow_up_done','parent_id','outcome','shared']
        read_only_fields = fields

    def get_image_url(self, obj):
        return self.context['request'].build_absolute_uri(f'/api/scans/{obj.id}/image/')


class OutcomeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Scan
        fields = ['outcome','notes']
        extra_kwargs = {'notes': {'max_length': 2000}}


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id','kind','title','body','scan_id','created_at','read_at']
