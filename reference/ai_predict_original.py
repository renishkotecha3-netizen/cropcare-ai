import os
import threading

import numpy as np
import tensorflow as tf
from tensorflow.keras.models import load_model


# =========================================================
# BASE DIRECTORY
# Keep this prediction file in its existing location.
# =========================================================

BASE_DIR = os.path.dirname(
    os.path.dirname(
        os.path.abspath(__file__)
    )
)

AI_MODEL_DIR = os.path.join(
    BASE_DIR,
    "crop_api",
    "ai_model"
)


# =========================================================
# MODEL AND LABEL PATHS
# Use both files from the new MobileNet ZIP.
# =========================================================

MODEL_PATH = os.path.join(
    AI_MODEL_DIR,
    "crop_model_33_mobilenet.keras"
)

LABEL_PATH = os.path.join(
    AI_MODEL_DIR,
    "labels.txt"
)

IMAGE_SIZE = (224, 224)
CONFIDENCE_THRESHOLD = 60.0


# =========================================================
# LOAD LABELS
# Preserve the training order. Do not sort these labels.
# =========================================================

if not os.path.isfile(LABEL_PATH):
    raise FileNotFoundError(
        f"Labels file not found: {LABEL_PATH}"
    )

with open(LABEL_PATH, "r", encoding="utf-8-sig") as file:
    CLASS_NAMES = [
        line.strip()
        for line in file
        if line.strip()
    ]

if len(CLASS_NAMES) != 33:
    raise ValueError(
        "Expected 33 labels for this MobileNet model, "
        f"but found {len(CLASS_NAMES)}."
    )

if len(set(CLASS_NAMES)) != len(CLASS_NAMES):
    raise ValueError(
        "Duplicate labels found in labels.txt."
    )


# =========================================================
# TREATMENTS
# Existing treatment mapping retained.
# These are advisory messages, not confirmed diagnoses.
# =========================================================

TREATMENTS = {

    # -------------------------
    # PEPPER: 2 CLASSES
    # -------------------------

    "Pepper__bell___Bacterial_spot":
        "Remove infected leaves and use a suitable treatment for bacterial infection.",

    "Pepper__bell___healthy":
        "Pepper plant is healthy. No treatment required.",

    # -------------------------
    # POTATO: 14 CLASSES
    # -------------------------

    "Potato_Bacteria":
        "Remove infected leaves and use a suitable bactericide.",

    "Potato_Bacterial_Soft_Rot":
        "Remove infected plant parts and avoid excess moisture.",

    "Potato_Early_blight":
        "Use a suitable fungicide and remove severely infected leaves.",

    "Potato_Fungal_Late_Blight":
        "Use a suitable fungicide and remove infected leaves.",

    "Potato_Fungi":
        "Remove infected leaves and use an appropriate fungicide.",

    "Potato_Late_blight":
        "Use a suitable fungicide and remove infected plant parts.",

    "Potato_Nematode":
        "Remove affected plants and maintain proper soil management.",

    "Potato_Pest":
        "Remove affected leaves and use a suitable pest-control treatment.",

    "Potato_Phytopthora":
        "Remove infected plant parts and avoid excess moisture.",

    "Potato_Viral_Leaf_Roll":
        "Remove infected plants and control insect vectors such as aphids.",

    "Potato_Viral_PVX":
        "Remove infected plants and maintain proper field hygiene.",

    "Potato_Viral_PVY":
        "Remove infected plants and control insect vectors.",

    "Potato_Virus":
        "Remove infected plants and maintain proper field hygiene.",

    "Potato_healthy":
        "Potato plant is healthy. No treatment required.",

    # -------------------------
    # TOMATO: 17 CLASSES
    # -------------------------

    "Tomato_Bacterial_spot":
        "Remove infected leaves and use a suitable treatment for bacterial infection.",

    "Tomato_Early_blight":
        "Remove affected leaves and use a suitable fungicide.",

    "Tomato_Fusarium_Wilt":
        "Remove severely infected plants and maintain proper soil and field hygiene.",

    "Tomato_Late_blight":
        "Remove infected leaves and use a suitable fungicide.",

    "Tomato_Leaf_Mold":
        "Improve air circulation, avoid excess moisture on leaves, and use a suitable fungicide if necessary.",

    "Tomato_Leaf_miner":
        "Remove affected leaves and use a suitable pest-control treatment.",

    "Tomato_Magnesium Deficiency":
        "This plant is affected by magnesium deficiency. Provide proper magnesium treatment according to soil requirements.",

    "Tomato_Nitrogen Deficiency":
        "This plant is affected by nitrogen deficiency. Provide proper nitrogen treatment according to soil requirements.",

    "Tomato_Pottassium Deficiency":
        "This plant is affected by potassium deficiency. Provide proper potassium treatment according to soil requirements.",

    "Tomato_Powdery_mildew":
        "Remove severely infected leaves and use a suitable fungicide.",

    "Tomato_Septoria_leaf_spot":
        "Remove infected leaves and use a suitable fungicide.",

    "Tomato_Shot_Hole_Disease":
        "Remove infected leaves and use a suitable fungicide.",

    "Tomato_Spider_mites_Two_spotted_spider_mite":
        "Remove affected leaves and use an appropriate pest-control treatment.",

    "Tomato__Target_Spot":
        "Remove affected leaves and use a suitable fungicide.",

    "Tomato__Tomato_YellowLeaf__Curl_Virus":
        "Remove infected plants and control insect vectors such as whiteflies.",

    "Tomato__Tomato_mosaic_virus":
        "Remove infected plants and maintain proper field hygiene.",

    "Tomato_healthy":
        "Tomato plant is healthy. No treatment required."
}


# =========================================================
# CHECK TREATMENT COVERAGE
# This checks coverage, not the model's training label order.
# =========================================================

missing_treatments = set(CLASS_NAMES) - set(TREATMENTS)

if missing_treatments:
    raise ValueError(
        "Treatment information missing for: "
        + ", ".join(sorted(missing_treatments))
    )


# =========================================================
# LAZY MODEL LOADING
# One cached model per backend process.
# =========================================================

model = None
_model_lock = threading.Lock()


def get_model():
    global model

    if model is None:
        with _model_lock:
            if model is None:
                if not os.path.isfile(MODEL_PATH):
                    raise FileNotFoundError(
                        f"MobileNet model not found: {MODEL_PATH}"
                    )

                loaded_model = load_model(
                    MODEL_PATH,
                    compile=False
                )

                expected_input = (None, 224, 224, 3)
                expected_output = (None, len(CLASS_NAMES))

                if tuple(loaded_model.input_shape) != expected_input:
                    raise ValueError(
                        "Unexpected model input shape: "
                        f"{loaded_model.input_shape}. "
                        f"Expected: {expected_input}"
                    )

                if tuple(loaded_model.output_shape) != expected_output:
                    raise ValueError(
                        "Unexpected model output shape: "
                        f"{loaded_model.output_shape}. "
                        f"Expected: {expected_output}"
                    )

                model = loaded_model

                print(
                    "Loaded model:",
                    os.path.basename(MODEL_PATH)
                )
                print("Input shape:", model.input_shape)
                print("Output shape:", model.output_shape)
                print("Total labels:", len(CLASS_NAMES))

    return model


# =========================================================
# PREPARE IMAGE
#
# Uploaded model expects:
# - RGB
# - 224 x 224
# - Bilinear resize
# - Float32 pixels in the 0–255 range
#
# Rescaling to [-1, 1] is ALREADY INSIDE the saved model.
# =========================================================

def prepare_image(img_path):
    img_path = os.fspath(img_path)

    if not os.path.isfile(img_path):
        raise FileNotFoundError(
            f"Image file not found: {img_path}"
        )

    image_bytes = tf.io.read_file(img_path)

    img = tf.io.decode_image(
        image_bytes,
        channels=3,
        expand_animations=False
    )

    img = tf.cast(img, tf.float32)

    img = tf.image.resize(
        img,
        size=IMAGE_SIZE,
        method="bilinear"
    )

    # Do NOT divide by 255 or 127.5 here.
    # Do NOT apply MobileNet/EfficientNet preprocess_input.
    # The model performs its own normalization.
    return tf.expand_dims(img, axis=0)


# =========================================================
# PREDICT DISEASE
# API response remains compatible with the existing app:
# disease: string
# confidence: float, percentage
# treatment: string
# =========================================================

def predict_disease(img_path):
    current_model = get_model()
    img_batch = prepare_image(img_path)

    # training=False disables training-time augmentation
    # and dropout in the saved model.
    prediction = np.asarray(
        current_model(img_batch, training=False),
        dtype=np.float32
    )

    expected_shape = (1, len(CLASS_NAMES))

    if prediction.shape != expected_shape:
        raise ValueError(
            f"Unexpected prediction shape: {prediction.shape}. "
            f"Expected: {expected_shape}"
        )

    if not np.all(np.isfinite(prediction)):
        raise ValueError(
            "Model returned invalid prediction values."
        )

    # The uploaded model has a softmax output layer.
    probabilities = prediction[0]

    class_index = int(np.argmax(probabilities))
    confidence = float(probabilities[class_index] * 100.0)

    disease = CLASS_NAMES[class_index]

    # -----------------------------------------------------
    # LOW-CONFIDENCE RESULT
    #
    # Low confidence means uncertain.
    # This threshold is not a reliable non-leaf detector.
    # -----------------------------------------------------

    if confidence < CONFIDENCE_THRESHOLD:
        return {
            "disease": "Not Matched",
            "confidence": round(confidence, 2),
            "treatment": (
                "The prediction is uncertain. Retake a clear "
                "photo of a pepper, potato or tomato leaf in "
                "natural light. Ask a local agricultural "
                "expert if symptoms continue."
            )
        }

    # -----------------------------------------------------
    # NORMAL RESULT
    # Nutrient deficiencies are also handled by TREATMENTS.
    # -----------------------------------------------------

    treatment = TREATMENTS.get(
        disease,
        "No treatment information available."
    )

    return {
        "disease": disease,
        "confidence": round(confidence, 2),
        "treatment": treatment
    }
