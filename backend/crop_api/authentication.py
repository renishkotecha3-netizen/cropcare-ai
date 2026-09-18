import hashlib
import secrets
from datetime import timedelta
from django.utils import timezone
from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework.exceptions import AuthenticationFailed
from .models import ApiSession


def issue_session(user):
    raw = secrets.token_urlsafe(40)
    ApiSession.objects.create(user=user, token_hash=hashlib.sha256(raw.encode()).hexdigest(),
                              expires_at=timezone.now() + timedelta(days=30))
    return raw


class BearerAuthentication(BaseAuthentication):
    def authenticate(self, request):
        header = get_authorization_header(request).split()
        if not header:
            return None
        if len(header) != 2 or header[0].lower() != b'bearer':
            raise AuthenticationFailed('Invalid authorization header.')
        digest = hashlib.sha256(header[1]).hexdigest()
        session = ApiSession.objects.select_related('user').filter(token_hash=digest, expires_at__gt=timezone.now()).first()
        if not session or not session.user.is_active:
            raise AuthenticationFailed('Your session has expired. Please sign in again.')
        return session.user, session

    def authenticate_header(self, request):
        return 'Bearer'
