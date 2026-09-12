#!/usr/bin/env bash
# Constrói a imagem do Lambda dentro do WSL.
#
# Existe porque passar o comando direto pelo PowerShell exigia escapar aspas e
# cifrões duas vezes, e um erro de escape parecia falha de build. O log completo
# fica em /tmp/build.log.
#
# Uso:  wsl -d Ubuntu -u root -- bash "/mnt/d/.../build_lambda.sh"

set -o pipefail

cd "/mnt/d/Nova pasta/snakes_of_imt/lib/models" || exit 1

docker build -t ophidia . > /tmp/build.log 2>&1
code=$?

echo "exit=$code"
tail -20 /tmp/build.log

exit $code
