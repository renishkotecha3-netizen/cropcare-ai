import time
from django.core.management.base import BaseCommand
from django.db import close_old_connections
from django.utils import timezone
from crop_api.models import ApiSession
from crop_api.services.alerts import create_due_reminders
from crop_api.services.push import send_pending

class Command(BaseCommand):
    help = 'Create due reminders and deliver optional nearby push notifications. Run one worker.'
    def add_arguments(self,parser):
        parser.add_argument('--watch',action='store_true')
    def handle(self,*args,**options):
        while True:
            close_old_connections()
            ApiSession.objects.filter(expires_at__lte=timezone.now()).delete()
            count = create_due_reminders()
            sent = send_pending()
            self.stdout.write(f'Reminders created: {count}; pushes completed: {sent}')
            if not options['watch']:
                break
            time.sleep(60)
