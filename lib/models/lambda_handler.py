"""
Ponto de entrada do AWS Lambda.

O `main.py` é um app FastAPI comum, feito para o uvicorn. O Lambda não fala
ASGI: ele entrega um evento JSON e espera outro de volta. O Mangum faz essa
tradução nos dois sentidos, então o mesmo `main.py` roda localmente com uvicorn
e na nuvem sem nenhuma alteração.

Importante: o `main.py` carrega os dois modelos no momento do import, e isso é
proposital aqui. O Lambda executa o import durante a fase de inicialização, que
recebe mais CPU que a execução normal e não é cobrada da mesma forma — carregar
os modelos ali sai mais barato e mais rápido do que na primeira requisição.
"""

from mangum import Mangum

from main import app

# lifespan desligado: o FastAPI não tem eventos de startup/shutdown aqui, e
# mantê-lo ligado só adiciona latência a cada invocação.
handler = Mangum(app, lifespan="off")
