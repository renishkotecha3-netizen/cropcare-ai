import os
import tensorflow as tf
from tensorflow.keras import layers, models
from tensorflow.keras.applications import EfficientNetB0
from tensorflow.keras.callbacks import (
    EarlyStopping,
    ModelCheckpoint,
    ReduceLROnPlateau
)

# ============================================================
# DATASET PATH
# ============================================================

DATASET_PATH = r"C:\Users\Divyesh Chauhan\OneDrive\Desktop\crop_dataset"


# ============================================================
# SETTINGS
# ============================================================

IMG_SIZE = (224, 224)
BATCH_SIZE = 16
EPOCHS = 20
SEED = 123

EXPECTED_CLASSES = 33


# ============================================================
# MODEL DIRECTORY
# ============================================================

AI_MODEL_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "crop_api",
    "ai_model"
)

os.makedirs(AI_MODEL_DIR, exist_ok=True)


# ============================================================
# MODEL PATH
# ============================================================

MODEL_PATH = os.path.join(
    AI_MODEL_DIR,
    "crop_model_33.keras"
)


# ============================================================
# LOAD TRAINING DATA
# ============================================================

print("\n========================================")
print("LOADING TRAINING DATA")
print("========================================\n")

train_ds = tf.keras.utils.image_dataset_from_directory(
    DATASET_PATH,
    validation_split=0.2,
    subset="training",
    seed=SEED,
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    shuffle=True
)


# ============================================================
# LOAD VALIDATION DATA
# ============================================================

val_ds = tf.keras.utils.image_dataset_from_directory(
    DATASET_PATH,
    validation_split=0.2,
    subset="validation",
    seed=SEED,
    image_size=IMG_SIZE,
    batch_size=BATCH_SIZE,
    shuffle=False
)


# ============================================================
# CLASS NAMES
# ============================================================

class_names = train_ds.class_names
num_classes = len(class_names)

print("\n========================================")
print("TOTAL CLASSES:", num_classes)
print("========================================")

for i, name in enumerate(class_names):
    print(i, "=", name)


# ============================================================
# CHECK NUMBER OF CLASSES
# ============================================================

if num_classes != EXPECTED_CLASSES:
    raise ValueError(
        f"\nExpected {EXPECTED_CLASSES} classes, "
        f"but found {num_classes} classes.\n"
        f"Please check the dataset folders."
    )


# ============================================================
# SAVE LABELS
# ============================================================

LABEL_PATH = os.path.join(
    AI_MODEL_DIR,
    "labels.txt"
)

with open(
    LABEL_PATH,
    "w",
    encoding="utf-8"
) as f:

    for name in class_names:
        f.write(name + "\n")


print("\nLabels saved to:")
print(LABEL_PATH)


# ============================================================
# PERFORMANCE
# ============================================================

AUTOTUNE = tf.data.AUTOTUNE

train_ds = train_ds.prefetch(AUTOTUNE)
val_ds = val_ds.prefetch(AUTOTUNE)


# ============================================================
# DATA AUGMENTATION
# ============================================================

data_augmentation = tf.keras.Sequential([
    layers.RandomFlip("horizontal"),
    layers.RandomRotation(0.15),
    layers.RandomZoom(0.15),
    layers.RandomContrast(0.1),
])


# ============================================================
# BASE MODEL
# ============================================================

print("\n========================================")
print("LOADING EfficientNetB0")
print("========================================\n")

base_model = EfficientNetB0(
    include_top=False,
    weights="imagenet",
    input_shape=(224, 224, 3)
)

base_model.trainable = False


# ============================================================
# BUILD MODEL
# ============================================================

inputs = layers.Input(
    shape=(224, 224, 3)
)

# Data augmentation
x = data_augmentation(inputs)

# EfficientNet preprocessing
x = tf.keras.applications.efficientnet.preprocess_input(x)

# EfficientNetB0
x = base_model(
    x,
    training=False
)

# Global pooling
x = layers.GlobalAveragePooling2D()(x)

# Dropout
x = layers.Dropout(0.3)(x)

# 33 classes
outputs = layers.Dense(
    num_classes,
    activation="softmax"
)(x)

model = models.Model(
    inputs,
    outputs
)


# ============================================================
# COMPILE MODEL
# ============================================================

model.compile(
    optimizer=tf.keras.optimizers.Adam(
        learning_rate=0.001
    ),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"]
)


# ============================================================
# MODEL SUMMARY
# ============================================================

model.summary()


# ============================================================
# CALLBACKS
# ============================================================

checkpoint = ModelCheckpoint(
    MODEL_PATH,
    monitor="val_accuracy",
    save_best_only=True,
    mode="max",
    verbose=1
)


early_stop = EarlyStopping(
    monitor="val_accuracy",
    patience=5,
    mode="max",
    restore_best_weights=True,
    verbose=1
)


reduce_lr = ReduceLROnPlateau(
    monitor="val_loss",
    factor=0.2,
    patience=2,
    min_lr=1e-6,
    verbose=1
)


# ============================================================
# START TRAINING
# ============================================================

print("\n========================================")
print("STARTING TRAINING")
print("========================================\n")

history = model.fit(
    train_ds,
    validation_data=val_ds,
    epochs=EPOCHS,
    callbacks=[
        checkpoint,
        early_stop,
        reduce_lr
    ]
)


# ============================================================
# SAVE FINAL MODEL
# ============================================================

model.save(MODEL_PATH)


# ============================================================
# TRAINING COMPLETE
# ============================================================

print("\n========================================")
print("TRAINING COMPLETE")
print("========================================")

print("Classes:", num_classes)

print("\nModel saved at:")
print(MODEL_PATH)

print("\nLabels saved at:")
print(LABEL_PATH)

print("\n========================================")
print("SUCCESS")
print("========================================")