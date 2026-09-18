import numpy as np
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing import image
import os
import tensorflow as tf


# =========================================================
# BASE DIRECTORY
# =========================================================

BASE_DIR = os.path.dirname(
    os.path.dirname(
        os.path.abspath(__file__)
    )
)


# =========================================================
# MODEL PATH
# =========================================================

MODEL_PATH = os.path.join(
    BASE_DIR,
    "crop_api",
    "ai_model",
    "crop_model_33.keras"
)


# =========================================================
# MODEL LOADING
# =========================================================

model = None


def get_model():
    global model

    if model is None:
        model = load_model(MODEL_PATH)

    return model


# =========================================================
# LABELS
# SAME ORDER AS TRAINING
# =========================================================

LABEL_PATH = os.path.join(
    BASE_DIR,
    "crop_api",
    "ai_model",
    "labels.txt"
)


with open(
    LABEL_PATH,
    "r",
    encoding="utf-8"
) as f:

    CLASS_NAMES = [
        line.strip()
        for line in f.readlines()
        if line.strip()
    ]


# =========================================================
# TREATMENTS
# =========================================================

TREATMENTS = {

    # -------------------------
    # PEPPER
    # -------------------------

    "Pepper__bell___Bacterial_spot":
        "Remove infected leaves and use a suitable treatment for bacterial infection.",

    "Pepper__bell___healthy":
        "Pepper plant is healthy. No treatment required.",


    # -------------------------
    # POTATO
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
    # TOMATO
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
        "Provide an appropriate magnesium supplement according to soil requirements.",

    "Tomato_Nitrogen Deficiency":
        "Provide an appropriate nitrogen fertilizer according to soil requirements.",

    "Tomato_Pottassium Deficiency":
        "Provide an appropriate potassium fertilizer according to soil requirements.",

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
# PREDICT DISEASE
# =========================================================

def predict_disease(img_path):

    # -------------------------
    # Load image
    # -------------------------

    img = image.load_img(
        img_path,
        target_size=(224, 224)
    )


    # -------------------------
    # Convert image to array
    # -------------------------

    img_array = image.img_to_array(img)


    # -------------------------
    # Add batch dimension
    # -------------------------

    img_array = np.expand_dims(
        img_array,
        axis=0
    )


    # -------------------------
    # EfficientNet preprocessing
    # -------------------------

    img_array = tf.keras.applications.efficientnet.preprocess_input(
        img_array
    )


    # -------------------------
    # Prediction
    # -------------------------

    prediction = get_model().predict(
        img_array,
        verbose=0
    )


    # -------------------------
    # Highest probability
    # -------------------------

    class_index = np.argmax(prediction)

    confidence = float(
        np.max(prediction) * 100
    )


    disease = CLASS_NAMES[class_index]


    # =====================================================
    # UNKNOWN IMAGE CHECK
    # =====================================================

    if confidence < 60:

        return {
            "disease": "Not Matched",
            "confidence": round(confidence, 2),
            "treatment":
                "This image does not appear to be a supported, Potato or Tomato leaf."
        }


    # =====================================================
    # SPECIAL NUTRIENT DEFICIENCY CASES
    # =====================================================

    if disease == "Tomato_Magnesium Deficiency":

        return {
            "disease": disease,
            "confidence": round(confidence, 2),
            "treatment":
                "This plant is affected by magnesium deficiency. Provide proper magnesium treatment according to soil requirements."
        }


    if disease == "Tomato_Nitrogen Deficiency":

        return {
            "disease": disease,
            "confidence": round(confidence, 2),
            "treatment":
                "This plant is affected by nitrogen deficiency. Provide proper nitrogen treatment according to soil requirements."
        }


    if disease == "Tomato_Pottassium Deficiency":

        return {
            "disease": disease,
            "confidence": round(confidence, 2),
            "treatment":
                "This plant is affected by potassium deficiency. Provide proper potassium treatment according to soil requirements."
        }


    # =====================================================
    # NORMAL RESULT
    # =====================================================

    return {
        "disease": disease,
        "confidence": round(confidence, 2),
        "treatment": TREATMENTS.get(
            disease,
            "No treatment information available."
        )
    }