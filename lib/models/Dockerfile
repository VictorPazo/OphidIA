# Imagem do servidor de inferência para o AWS Lambda.
#
# Construir e publicar a partir de lib/models/:
#   docker build -t ophidia .
#
# O passo a passo completo (ECR, criação da função, Function URL) está em
# lib/models/DEPLOY-LAMBDA.md.
#
# ---------------------------------------------------------------------------
# Por que NÃO usamos public.ecr.aws/lambda/python
#
# A imagem base oficial da AWS é o caminho mais comum, mas aqui ela falhava com
# "exec format error" mesmo na tag explícita de x86_64, e mesmo com o host e a
# imagem reportando amd64. Como `alpine` e `python:3.12-slim` rodavam sem
# problema na mesma máquina, o defeito era da imagem e não do Docker.
#
# A alternativa é documentada pela própria AWS: partir de uma imagem Python
# comum e instalar o `awslambdaric`, o cliente que conversa com o runtime do
# Lambda. O resultado é equivalente — o que a base oficial traz pronto, nós
# montamos em três linhas.
# ---------------------------------------------------------------------------

FROM python:3.12-slim

# libgomp é a biblioteca de paralelismo que o PyTorch usa em CPU; a imagem slim
# não a inclui e o import de torch falharia.
RUN apt-get update && \
    apt-get install -y --no-install-recommends libgomp1 && \
    rm -rf /var/lib/apt/lists/*

# Cliente de runtime do Lambda: é ele que recebe os eventos e devolve as
# respostas, papel que a imagem base oficial cumpriria.
RUN pip install --no-cache-dir awslambdaric

# ---------------------------------------------------------------------------
# PyTorch de CPU
#
# A build padrão traz as bibliotecas CUDA, cerca de 2,5 GB, inúteis num Lambda
# sem GPU: só engordam a imagem e atrasam a partida a frio, que é justamente o
# ponto fraco desta arquitetura.
# ---------------------------------------------------------------------------
RUN pip install --no-cache-dir \
        torch torchvision \
        --index-url https://download.pytorch.org/whl/cpu

RUN pip install --no-cache-dir \
        fastapi \
        python-multipart \
        pillow \
        ultralytics \
        mangum

# ---------------------------------------------------------------------------
# OpenCV sem interface gráfica
#
# O ultralytics puxa `opencv-python`, que depende de libGL — biblioteca de vídeo
# ausente em imagem de servidor. O import falharia com
# "libGL.so.1: cannot open shared object file".
#
# A versão headless tem as mesmas funções de processamento, sem a parte de
# janela. Instalada depois para substituir a que veio junto.
# ---------------------------------------------------------------------------
RUN pip uninstall -y opencv-python opencv-contrib-python 2>/dev/null || true && \
    pip install --no-cache-dir opencv-python-headless

# ---------------------------------------------------------------------------
# Sistema de arquivos somente leitura
#
# No Lambda, só /tmp é gravável. O ultralytics tenta escrever um settings.json
# na inicialização e o matplotlib um cache de fontes; sem estas variáveis os
# dois quebram antes de o modelo carregar.
# ---------------------------------------------------------------------------
ENV YOLO_CONFIG_DIR=/tmp \
    MPLCONFIGDIR=/tmp \
    HOME=/tmp \
    TORCH_HOME=/tmp

WORKDIR /var/task

COPY main.py classes.json lambda_handler.py ./

# O detector (22 MB) está versionado no repositório.
COPY detector_cobra.pt ./

# ---------------------------------------------------------------------------
# O classificador (107 MB) NÃO está no git: passa do limite de 100 MB por
# arquivo do GitHub e é distribuído como anexo de release. Baixar aqui deixa a
# imagem reproduzível a partir do repositório limpo, sem exigir que o arquivo
# esteja no disco de quem constrói.
# ---------------------------------------------------------------------------
RUN python -c "\
import urllib.request, os;\
u='https://github.com/VictorPazo/OphidIA/releases/download/ModeloConvNeXt-Tiny_v2/best_model.pth';\
urllib.request.urlretrieve(u,'best_model.pth');\
assert os.path.getsize('best_model.pth')==112104519, 'download incompleto do best_model.pth';\
print('classificador baixado e conferido')"

ENTRYPOINT ["python", "-m", "awslambdaric"]
CMD ["lambda_handler.handler"]
