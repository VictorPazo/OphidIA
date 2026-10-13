"""
Ponto de entrada do AWS Lambda.

O `main.py` é um app FastAPI comum, feito para o uvicorn. O Lambda não fala
ASGI: ele entrega um evento JSON e espera outro de volta. O Mangum faz essa
tradução nos dois sentidos, então o mesmo `main.py` roda localmente com uvicorn
e na nuvem sem nenhuma alteração.

Sobre o carregamento dos modelos: o `main.py` os carrega no momento do import,
com a intenção de aproveitar a fase de inicialização do Lambda, que recebe mais
CPU e não é cobrada da mesma forma que a execução.

Medimos em 12/10/2026 que essa intenção NÃO se cumpre. O CloudWatch registra:

    INIT_REPORT Init Duration: 9999.77 ms  Phase: init  Status: timeout

A inicialização tem teto de 10 segundos e carregar o PyTorch mais os dois
modelos não cabe nele. O Lambda desiste e refaz o carregamento dentro da
primeira requisição, que por isso foi cobrada por 23,7 s inteiros — e, vista do
celular, levou 34,6 s.

Não há como contornar: o teto de 10 s é fixo e os modelos são o que são. O que
resolve na prática é a regra `ophidia-aquecimento` do EventBridge, que invoca a
função a cada 5 minutos e nunca deixa o ambiente morrer — medimos 0,35 s depois
de 14 minutos sem nenhum uso real, contra os 34,6 s de antes.
"""

from mangum import Mangum

from main import app

# lifespan desligado: o FastAPI não tem eventos de startup/shutdown aqui, e
# mantê-lo ligado só adiciona latência a cada invocação.
_asgi = Mangum(app, lifespan="off")


def _e_aquecimento(event) -> bool:
    """O evento é um ping de aquecimento, e não uma requisição de verdade?

    O Mangum só traduz eventos HTTP — Function URL, API Gateway, ALB. A regra
    do EventBridge que mantém o ambiente quente entrega um JSON de agendamento,
    que ele não reconhece: sem este desvio cada ping terminaria em erro, e a
    cada cinco minutos isso soma centenas de erros por dia nas métricas,
    escondendo os erros de verdade.

    Reconhece os três formatos possíveis: a carga padrão de uma regra clássica
    (`source: aws.events`), a do EventBridge Scheduler sem entrada configurada
    (um objeto vazio) e uma entrada personalizada `{"warmup": true}`.
    """
    if not isinstance(event, dict) or not event:
        return True

    return (
        event.get("source") == "aws.events"
        or event.get("detail-type") == "Scheduled Event"
        or event.get("warmup") is True
    )


def handler(event, context):

    # Responde antes de qualquer inferência. O ping não precisa processar nada:
    # o que mantém a função rápida é o ambiente continuar vivo, e os modelos já
    # foram carregados no import, durante a inicialização.
    if _e_aquecimento(event):
        return {"status": "warm"}

    return _asgi(event, context)
