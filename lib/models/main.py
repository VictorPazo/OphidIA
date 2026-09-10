import io
import json

from pathlib import Path

from fastapi import FastAPI, UploadFile, File

import torch
import torch.nn as nn
import torch.nn.functional as F

from torchvision import transforms, models

from PIL import Image

from ultralytics import YOLO

# =========================
# CONFIG
# =========================

# Caminhos resolvidos a partir do próprio arquivo, e não do diretório de
# trabalho: assim o servidor pode ser iniciado de qualquer lugar.
BASE_DIR = Path(__file__).resolve().parent

MODEL_PATH = BASE_DIR / "best_model.pth"

CLASSES_PATH = BASE_DIR / "classes.json"

# 🐍 YOLO — DETECÇÃO
# Ajuste o nome do arquivo para o .pt que você já treinou.
YOLO_MODEL_PATH = BASE_DIR / "detector_cobra.pt"

# Confiança mínima para considerar que a detecção "achou" uma cobra.
# Ajuste conforme testar com fotos reais — muito baixo deixa passar
# falso positivo, muito alto manda gente real pro pop-up de "não achei".
YOLO_CONF_THRESHOLD = 0.5

# Estes três valores PRECISAM bater com o treino que gerou best_model.pth
# (ver treino_v2/config_utilizada.json). Divergir aqui não gera erro — só
# derruba a acurácia silenciosamente.
ARCHITECTURE = "convnext_tiny"

IMG_SIZE = 384

DROPOUT = 0.4

# TTA por espelhamento horizontal, igual à avaliação final do treino.
# É o que produz os 76,82% de accuracy relatados; sem TTA são 76,42%.
# Custa uma segunda passagem pela rede por imagem.
USE_TTA = True

IMAGENET_MEAN = [0.485, 0.456, 0.406]

IMAGENET_STD = [0.229, 0.224, 0.225]

# =========================
# APP
# =========================

app = FastAPI(title="OphidIA — inferência de serpentes")

# =========================
# DEVICE
# =========================

DEVICE = torch.device(
    "cuda" if torch.cuda.is_available()
    else "cpu"
)

# =========================
# LOAD CLASSES
# =========================

with open(CLASSES_PATH, "r", encoding="utf-8") as f:
    class_names = json.load(f)


def to_scientific_name(class_name: str) -> str:
    """
    O classes.json guarda o nome da PASTA do dataset ('Bothrops_jararaca'),
    enquanto o app e a coluna `specie` da tabela `snakes` usam o nome
    científico com espaço.

    Três classes ('Chironius', 'Hydrodynastes', 'Thamnodynastes') são de
    gênero apenas, sem epíteto, e passam por aqui inalteradas.
    """
    return class_name.replace("_", " ")


# =========================
# SPECIE -> DATABASE ID
# =========================

# O modelo reconhece 246 espécies, mas só as já cadastradas na tabela
# `snakes` têm id. As demais retornam snake_id: null — o app trata esse
# caso. Conforme o pipeline de lib/scripts/ for rodando para novos
# gêneros, acrescente as espécies aqui.

SPECIE_TO_ID = {

    "Bothrops alcatraz": 1,
    "Bothrops alternatus": 2,
    "Bothrops atrox": 3,

    "Bothrops bilineatus": 4,
    "Bothrops brazili": 5,
    "Bothrops cotiara": 6,

    "Bothrops diporus": 7,
    "Bothrops erythromelas": 8,
    "Bothrops fonsecai": 9,

    "Bothrops insularis": 10,
    "Bothrops itapetiningae": 11,
    "Bothrops jabrensis": 12,

    "Bothrops jararaca": 13,
    "Bothrops jararacussu": 14,
    "Bothrops leucurus": 15,

    "Bothrops lutzi": 16,
    "Bothrops marajoensis": 17,
    "Bothrops marmoratus": 18,

    "Bothrops mattogrossensis": 19,
    "Bothrops moojeni": 20,
    "Bothrops muriciensis": 21,

    "Bothrops neuwiedi": 22,
    "Bothrops pauloensis": 23,
    "Bothrops pirajai": 24,

    "Bothrops pubescens": 25,
    "Bothrops taeniatus": 26,
}

# =========================
# TRANSFORM
# =========================

# Precisa ser idêntico ao eval_transform do treino: redimensiona o lado
# menor para 1,14x e recorta o centro. Trocar por um Resize((N, N)) achata
# a imagem e distorce a proporção que a rede viu no treino.

transform = transforms.Compose([

    transforms.Resize(int(IMG_SIZE * 1.14)),

    transforms.CenterCrop(IMG_SIZE),

    transforms.ToTensor(),

    transforms.Normalize(
        IMAGENET_MEAN,
        IMAGENET_STD
    )
])

# =========================
# LOAD MODEL (CLASSIFICADOR)
# =========================

# A cabeça é montada exatamente como em create_model() do treino:
# classifier[2] vira um Sequential(Dropout, Linear), o que produz as
# chaves 'classifier.2.0' / 'classifier.2.1' no state_dict.

model = models.convnext_tiny(weights=None)

in_features = model.classifier[2].in_features

model.classifier[2] = nn.Sequential(
    nn.Dropout(DROPOUT),
    nn.Linear(in_features, len(class_names)),
)

model.load_state_dict(
    torch.load(
        MODEL_PATH,
        map_location=DEVICE
    )
)

model.to(DEVICE)

model.eval()

# =========================
# LOAD MODEL (YOLO — DETECÇÃO)
# =========================

yolo_model = YOLO(str(YOLO_MODEL_PATH))

# =========================
# DETECT ENDPOINT
# =========================

@app.post("/detect")

async def detect(
        file: UploadFile = File(...)
):
    """
    Roda o YOLO na imagem enviada para checar se há uma cobra visível.

    Retorna as coordenadas do bounding box em PIXELS, no espaço da
    imagem ORIGINAL enviada (o ultralytics já reprojeta internamente,
    então não é preciso reescalar aqui) — junto com a largura/altura
    da imagem, para o app calcular o recorte sem precisar redecodificar
    o arquivo do zero.
    """

    image_bytes = await file.read()

    image = Image.open(
        io.BytesIO(image_bytes)
    ).convert("RGB")

    width, height = image.size

    results = yolo_model.predict(
        image,
        conf=YOLO_CONF_THRESHOLD,
        verbose=False,
    )

    boxes = results[0].boxes

    if boxes is None or len(boxes) == 0:

        return {
            "found": False,
            "image_width": width,
            "image_height": height,
        }

    # 🔍 MELHOR DETECÇÃO
    # Se o YOLO achar mais de uma "cobra" na imagem, fica com a de
    # maior confiança — o app só precisa de um quadrado pra dar zoom.
    best_idx = boxes.conf.argmax().item()

    x1, y1, x2, y2 = boxes.xyxy[best_idx].tolist()

    confidence = boxes.conf[best_idx].item()

    return {

        "found": True,

        "confidence": round(confidence * 100, 2),

        "bbox": {
            "x1": x1,
            "y1": y1,
            "x2": x2,
            "y2": y2,
        },

        "image_width": width,
        "image_height": height,
    }


# =========================
# PREDICT ENDPOINT
# =========================

@app.post("/predict")

async def predict(
        file: UploadFile = File(...)
):

    image_bytes = await file.read()

    image = Image.open(
        io.BytesIO(image_bytes)
    ).convert("RGB")

    image = transform(image)\
        .unsqueeze(0)\
        .to(DEVICE)

    with torch.no_grad():

        probs = F.softmax(
            model(image),
            dim=1
        )

        if USE_TTA:

            probs_flip = F.softmax(
                model(torch.flip(image, dims=[3])),
                dim=1
            )

            probs = (probs + probs_flip) / 2

        confidence, predicted = torch.max(probs, 1)

    specie = to_scientific_name(
        class_names[predicted.item()]
    )

    return {

        "snake_id": SPECIE_TO_ID.get(specie),

        "specie": specie,

        "confidence":
        round(confidence.item() * 100, 2)
    }