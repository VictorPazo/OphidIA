#!/usr/bin/env bash
# Publica a imagem local `ophidia` no ECR da conta configurada.
#
# Roda dentro do WSL, mas usa o aws.exe do Windows: o CLI está instalado lá e
# as credenciais também, então não há motivo para duplicar nenhum dos dois
# dentro do Linux.
#
# Uso:  wsl -d Ubuntu -u root -- bash "/mnt/d/.../push_ecr.sh"

set -euo pipefail

AWS="/mnt/c/Program Files/Amazon/AWSCLIV2/aws.exe"
REGIAO="sa-east-1"
REPO="ophidia"

conta=$("$AWS" sts get-caller-identity --query Account --output text | tr -d '\r\n')
uri="${conta}.dkr.ecr.${REGIAO}.amazonaws.com/${REPO}"

echo "conta: $conta"
echo "destino: $uri"

echo "--- autenticando no ECR ---"
"$AWS" ecr get-login-password --region "$REGIAO" | tr -d '\r' \
  | docker login --username AWS --password-stdin "$uri"

echo "--- marcando e enviando ---"
docker tag ophidia:latest "${uri}:latest"
docker push "${uri}:latest"

echo "--- pronto ---"
echo "IMAGEM=${uri}:latest"
