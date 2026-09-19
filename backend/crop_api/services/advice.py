import re


REFERENCE_URL = (
    "https://extension.umn.edu/agriculture/specialty-crops/"
    "vegetable-farming/disease-management/late-blight"
)


# =========================================================
# LABEL HELPERS
# =========================================================

def readable(label):
    return (
        re.sub(r"_+", " ", label)
        .replace("Pottassium", "Potassium")
        .strip()
    )


def category_for(label):
    s = label.lower()

    if "healthy" in s:
        return "healthy"

    if "deficiency" in s:
        return "nutrition"

    if "virus" in s or "viral" in s:
        return "viral"

    if "bacteria" in s or "bacterial" in s or "soft_rot" in s:
        return "bacterial"

    if any(word in s for word in [
        "pest",
        "miner",
        "mite",
        "nematode",
    ]):
        return "pest"

    if any(word in s for word in [
        "blight",
        "fung",
        "mold",
        "mildew",
        "septoria",
        "target",
        "shot_hole",
        "phytopthora",
        "fusarium",
    ]):
        return "fungal"

    return "unknown"


# =========================================================
# ALL 33 DISEASE ADVICE
# =========================================================

DISEASE_ADVICE = {

    # -----------------------------------------------------
    # PEPPER
    # -----------------------------------------------------

    "Pepper__bell___Bacterial_spot": [
        "Remove badly infected leaves and avoid touching healthy plants after handling infected leaves.",
        "Avoid overhead watering and improve air circulation around the plant.",
        "Use only locally approved bacterial disease products according to the product label."
    ],

    "Pepper__bell___healthy": [
        "No clear disease was detected in this pepper plant image.",
        "Continue regular watering, sunlight, field monitoring and pest inspection."
    ],


    # -----------------------------------------------------
    # POTATO
    # -----------------------------------------------------

    "Potato_Bacteria": [
        "Remove severely infected plant parts and keep the foliage dry.",
        "Avoid overhead irrigation and disinfect tools after use.",
        "Confirm the bacterial cause locally before selecting any treatment."
    ],

    "Potato_Bacterial_Soft_Rot": [
        "Remove rotting tubers or plant parts immediately to reduce spread.",
        "Avoid excess moisture and improve drainage in the field.",
        "Store harvested potatoes in a clean, cool and well-ventilated place."
    ],

    "Potato_Early_blight": [
        "Remove severely infected leaves and dispose of them away from the field.",
        "Avoid wetting the leaves during irrigation and maintain proper plant spacing.",
        "Use a locally approved fungicide only according to its label."
    ],

    "Potato_Fungal_Late_Blight": [
        "Inspect nearby potato plants because late blight can spread quickly in cool, wet weather.",
        "Remove severely infected plant parts and avoid moving wet foliage between plants.",
        "Take prompt local agricultural advice before selecting a fungicide."
    ],

    "Potato_Fungi": [
        "Remove infected leaves and plant debris from the growing area.",
        "Improve airflow, drainage and sunlight around the plants.",
        "Confirm the exact fungal disease before using any treatment."
    ],

    "Potato_Late_blight": [
        "Inspect the entire field because late blight may spread rapidly.",
        "Avoid overhead watering and remove severely infected leaves carefully.",
        "Use only a locally approved product and follow the label instructions."
    ],

    "Potato_Nematode": [
        "Remove severely affected plants and avoid moving contaminated soil to healthy areas.",
        "Practice crop rotation and use clean planting material.",
        "Ask a local agricultural expert for soil testing and nematode confirmation."
    ],

    "Potato_Pest": [
        "Inspect the underside of leaves, stems and soil for insects or larvae.",
        "Remove heavily infested leaves and protect beneficial insects.",
        "Identify the pest before choosing any pest-control product."
    ],

    "Potato_Phytopthora": [
        "Remove infected plant parts and avoid excess moisture around the crop.",
        "Improve field drainage and avoid working in the field when plants are wet.",
        "Confirm the disease locally before selecting a fungicide."
    ],

    "Potato_Viral_Leaf_Roll": [
        "Remove suspected infected plants to reduce virus spread.",
        "Inspect for aphids and other insect vectors.",
        "Use clean seed potatoes and avoid transferring plant sap through tools."
    ],

    "Potato_Viral_PVX": [
        "Remove suspected infected plants and maintain good field hygiene.",
        "Use certified disease-free seed potatoes.",
        "Clean tools and avoid handling healthy plants after infected plants."
    ],

    "Potato_Viral_PVY": [
        "Remove suspected infected plants from the field.",
        "Control aphids and other possible insect vectors through approved methods.",
        "Use certified seed and avoid reusing infected planting material."
    ],

    "Potato_Virus": [
        "Remove suspected infected plants and maintain proper field sanitation.",
        "Use certified disease-free seed potatoes.",
        "Seek local confirmation because viral diseases cannot usually be cured with fungicides."
    ],

    "Potato_healthy": [
        "No clear disease was detected in this potato plant image.",
        "Continue proper watering, earthing-up, nutrition and regular field monitoring."
    ],


    # -----------------------------------------------------
    # TOMATO
    # -----------------------------------------------------

    "Tomato_Bacterial_spot": [
        "Remove severely infected leaves and avoid handling plants when they are wet.",
        "Avoid overhead irrigation and disinfect pruning tools.",
        "Use only locally approved bacterial disease products according to the label."
    ],

    "Tomato_Early_blight": [
        "Remove affected lower leaves and clear infected plant debris.",
        "Improve air circulation and avoid watering the foliage.",
        "Use a locally approved fungicide only according to the product label."
    ],

    "Tomato_Fusarium_Wilt": [
        "Remove severely infected plants and dispose of them away from healthy plants.",
        "Improve soil drainage and avoid moving contaminated soil between beds.",
        "Practice crop rotation and ask for local confirmation before replanting."
    ],

    "Tomato_Late_blight": [
        "Inspect nearby tomato plants because late blight can spread quickly.",
        "Remove infected leaves and avoid overhead irrigation.",
        "Take prompt local advice before selecting a fungicide."
    ],

    "Tomato_Leaf_Mold": [
        "Improve air circulation and reduce humidity around the plant.",
        "Avoid wetting leaves during irrigation and remove severely infected leaves.",
        "Use a locally approved fungicide only when confirmed and follow the label."
    ],

    "Tomato_Leaf_miner": [
        "Inspect leaves for winding mines and remove badly affected leaves.",
        "Protect beneficial insects and avoid unnecessary broad-spectrum pesticides.",
        "Identify the leaf-miner species before selecting targeted control."
    ],

    "Tomato_Magnesium Deficiency": [
        "Check soil and leaf nutrients before applying fertilizer.",
        "Provide magnesium only according to soil-test results or local agricultural advice.",
        "Maintain balanced watering because root stress can also cause similar symptoms."
    ],

    "Tomato_Nitrogen Deficiency": [
        "Check soil fertility before adding nitrogen fertilizer.",
        "Apply a balanced nutrient correction according to soil-test results.",
        "Avoid excess nitrogen because it can cause weak growth and increase disease risk."
    ],

    "Tomato_Pottassium Deficiency": [
        "Check soil and leaf nutrients before applying potassium fertilizer.",
        "Provide potassium according to soil-test results and local crop advice.",
        "Avoid excessive fertilizer because it can damage roots and disturb nutrient balance."
    ],

    "Tomato_Powdery_mildew": [
        "Remove severely infected leaves and improve airflow around the plant.",
        "Avoid excessive humidity and crowding between plants.",
        "Use a locally approved fungicide according to the product label if confirmed."
    ],

    "Tomato_Septoria_leaf_spot": [
        "Remove infected lower leaves and dispose of plant debris safely.",
        "Avoid overhead watering and keep foliage dry.",
        "Improve air circulation and use a locally approved fungicide if confirmed."
    ],

    "Tomato_Shot_Hole_Disease": [
        "Remove affected leaves and clear infected debris from around the plant.",
        "Avoid overhead irrigation and improve air movement.",
        "Confirm the cause locally before using a fungicide."
    ],

    "Tomato_Spider_mites_Two_spotted_spider_mite": [
        "Inspect the underside of leaves for mites, webbing and yellow speckling.",
        "Wash dust from leaves with appropriate water pressure and protect beneficial insects.",
        "Use targeted, locally approved mite control only after confirming the pest."
    ],

    "Tomato__Target_Spot": [
        "Remove severely affected leaves and plant debris.",
        "Improve air circulation and avoid keeping the foliage wet.",
        "Use a locally approved fungicide according to the product label if confirmed."
    ],

    "Tomato__Tomato_YellowLeaf__Curl_Virus": [
        "Remove severely infected plants to reduce virus spread.",
        "Inspect and manage whiteflies using locally approved methods.",
        "Do not use fungicides for viral disease; seek local confirmation."
    ],

    "Tomato__Tomato_mosaic_virus": [
        "Remove suspected infected plants and avoid transferring sap by hand or tools.",
        "Disinfect tools and wash hands after handling infected plants.",
        "Use clean seeds and seek local confirmation because viral diseases have no direct cure."
    ],

    "Tomato_healthy": [
        "No clear disease was detected in this tomato plant image.",
        "Continue balanced watering, proper nutrition, airflow and regular inspection."
    ],
}


# =========================================================
# GENERAL FALLBACK ADVICE
# =========================================================

UNCERTAIN_ADVICE = [
    "Retake a sharp photo of one leaf in natural light.",
    "Keep both affected and healthy areas visible in the image.",
    "Select the correct crop and ask a local agricultural expert if symptoms continue."
]


UNKNOWN_ADVICE = [
    "The detected label does not have specific guidance yet.",
    "Inspect the plant and nearby plants for spreading symptoms.",
    "Ask a local agricultural expert before applying any pesticide or fertilizer."
]


# =========================================================
# MAIN ADVICE FUNCTION
# =========================================================

def guidance(label, status="confirmed"):
    """
    Returns advice for the predicted disease.

    status:
        confirmed  -> disease-specific advice
        uncertain  -> photo retake and expert advice
    """

    if status == "uncertain":
        return UNCERTAIN_ADVICE.copy()

    return DISEASE_ADVICE.get(
        label,
        UNKNOWN_ADVICE.copy()
    )


# =========================================================
# OPTIONAL VALIDATION
# =========================================================

def validate_labels(class_names):
    """
    Check whether all model labels have advice.
    """

    missing = set(class_names) - set(DISEASE_ADVICE.keys())
    extra = set(DISEASE_ADVICE.keys()) - set(class_names)

    return {
        "missing_advice": sorted(missing),
        "extra_advice": sorted(extra),
        "model_label_count": len(class_names),
        "advice_label_count": len(DISEASE_ADVICE),
    }
