import hashlib
import numpy as np
from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from crop_api.services.inference import get_model, labels, ModelUnavailable

class Command(BaseCommand):
    help = 'Load the real model, validate labels and run a synthetic tensor (not an accuracy test).'
    def handle(self,*args,**options):
        try:
            model = get_model()
            scores = model(np.zeros((1,224,224,3),dtype=np.float32),training=False).numpy()
            if scores.shape!=(1,33) or not np.isfinite(scores).all() or not np.isclose(scores.sum(),1,atol=.01):
                raise CommandError('Invalid model output.')
            self.stdout.write(self.style.SUCCESS(f'Model loads; {len(labels())} labels; shape {scores.shape}; finite softmax.'))
            self.stdout.write('SHA256: '+hashlib.sha256(settings.MODEL_PATH.read_bytes()).hexdigest())
            self.stdout.write('Synthetic execution verifies compatibility, not diagnostic accuracy.')
        except ModelUnavailable as exc:
            raise CommandError(str(exc)) from exc
