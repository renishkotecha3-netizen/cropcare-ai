"""RGB 224x224, pixel values 0..255; EfficientNet contains its own rescaling.

Preserves the supplied predictor's nearest-neighbour resize. Never divides by
255 again, never retrains, and loads the supplied ordered labels unchanged.
"""
import threading
from pathlib import Path
import numpy as np
from PIL import Image, ImageOps
from django.conf import settings
from .advice import readable, category_for, guidance

_model = None
_lock = threading.RLock()


class ModelUnavailable(Exception):
    pass


def labels():
    try:
        names = [x.strip() for x in Path(settings.LABELS_PATH).read_text(encoding='utf-8-sig').splitlines() if x.strip()]
    except OSError as exc:
        raise ModelUnavailable('The ordered labels.txt file is missing. Contact the app administrator.') from exc
    if len(names) != 33 or len(set(names)) != len(names):
        raise ModelUnavailable('The label file must contain exactly 33 unique labels in training order.')
    return names


def get_model():
    global _model
    with _lock:
        if _model is None:
            try:
                import tensorflow as tf
                loaded = tf.keras.models.load_model(settings.MODEL_PATH, compile=False, safe_mode=True)
                if loaded.input_shape != (None, 224, 224, 3) or loaded.output_shape[-1] != len(labels()):
                    raise ValueError('Unexpected model input/output shape')
                _model = loaded
            except Exception as exc:
                raise ModelUnavailable('The prediction model could not be loaded. Run python manage.py check_model on the server.') from exc
        return _model


def prepare_image(source):
    with Image.open(source) as raw:
        rgb = ImageOps.exif_transpose(raw).convert('RGB').resize((224, 224), Image.Resampling.NEAREST)
        return np.expand_dims(np.asarray(rgb, dtype=np.float32), axis=0)


def interpret(scores, names, selected_crop='Auto'):
    vector = np.asarray(scores, dtype=float).reshape(-1)
    if len(vector) != len(names) or not np.isfinite(vector).all() or (vector < 0).any() or (vector > 1).any() or abs(vector.sum() - 1) > .02:
        raise ModelUnavailable('The model returned invalid prediction scores.')
    order = np.argsort(vector)[::-1][:3]
    label = names[int(order[0])]
    confidence = round(float(vector[order[0]]) * 100, 2)
    crop = label.split('_')[0]
    mismatch = selected_crop != 'Auto' and selected_crop != crop
    status = 'uncertain' if confidence < 60 or mismatch else ('healthy' if 'healthy' in label.lower() else 'issue')
    return {'predicted_label': label, 'condition': 'Inconclusive — retake photo' if status == 'uncertain' else readable(label),
            'confidence': confidence, 'status': status, 'crop': selected_crop if mismatch else crop,
            'category': category_for(label) if status != 'uncertain' else 'unknown',
            'recommendations': guidance(label, status),
            'alternatives': [{'condition': readable(names[int(i)]), 'confidence': round(float(vector[i]) * 100, 2)} for i in order]}


def predict(source, selected_crop='Auto'):
    batch = prepare_image(source)
    with _lock:
        result = get_model()(batch, training=False).numpy()[0]
    return interpret(result, labels(), selected_crop)
