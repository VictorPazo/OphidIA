"""
Grava no Supabase os nomes populares em português preenchidos à mão em
`nomes_populares.csv`.

O CSV é gerado por `fetch_popular_names.py` e contém uma linha por espécie
que o modelo reconhece e que ainda está sem `popular_name_pt`. Você preenche
a última coluna e roda este script.

Por que CSV e não JSON, diferente de `apply_translations.py`: aqui o trabalho
é digitação em massa, e uma planilha deixa várias pessoas dividirem as linhas
entre si. O arquivo sai em utf-8-sig porque o Excel no Windows lê os acentos
errado sem o BOM.

Deixar uma linha em branco é esperado e seguro. Boa parte das espécies de
Atractus e Apostolepis simplesmente não tem nome popular consagrado em
português, e inventar um seria pior que deixar vazio: a ficha já cai no nome
científico sozinha quando o campo está vazio.

Uso:
    python apply_popular_names.py           # simulação, não grava nada
    python apply_popular_names.py --gravar  # grava de verdade

Requer SUPABASE_URL e SUPABASE_SERVICE_KEY em lib/scripts/.env (mesma
convenção do restante do pipeline).
"""

import csv
import os
import sys

from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

TABLE_NAME = "snakes"
INPUT_FILE = "nomes_populares.csv"
PENDING = "REVISAR"

# Simulação por padrão, igual ao resto do pipeline: rodar sem querer não pode
# escrever em produção. Ver lib/scripts/README.md.
DRY_RUN = "--gravar" not in sys.argv


def ler_csv():
    with open(INPUT_FILE, "r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def nome_limpo(linha):
    """Devolve o nome digitado, ou None quando a linha deve ser ignorada."""
    valor = (linha.get("popular_name_pt") or "").strip()

    # Vazio é uma resposta legítima: a espécie não tem nome popular.
    if not valor:
        return None

    # Protege contra o placeholder voltar para o banco por descuido.
    if valor.upper() == PENDING:
        return None

    return valor


if __name__ == "__main__":

    linhas = ler_csv()

    preenchidas = [(l, nome_limpo(l)) for l in linhas]
    gravaveis = [(l, n) for l, n in preenchidas if n]
    vazias = len(linhas) - len(gravaveis)

    print(f"Linhas no CSV: {len(linhas)}")
    print(f"  com nome preenchido: {len(gravaveis)}")
    print(f"  em branco (ignoradas): {vazias}")
    print()

    if DRY_RUN:
        print("SIMULAÇÃO — nada será gravado. Use --gravar para valer.\n")
        for linha, nome in gravaveis[:15]:
            print(f"  {linha['specie']:38s} -> {nome}")
        if len(gravaveis) > 15:
            print(f"  ... e mais {len(gravaveis) - 15}")
        print(f"\n{len(gravaveis)} espécies seriam atualizadas.")
        sys.exit(0)

    gravadas = 0
    for linha, nome in gravaveis:
        supabase.table(TABLE_NAME).update(
            {"popular_name_pt": nome}
        ).eq("id", int(linha["id"])).execute()

        gravadas += 1
        print(f"{gravadas}/{len(gravaveis)}  {linha['specie']} -> {nome}")

    print(f"\nConcluído: {gravadas} nomes populares gravados.")
    print(
        "\nPróximo passo, se quiser o inglês: rode fetch_pending_translations.py "
        "e apply_translations.py, que já existem e preenchem popular_name_en a "
        "partir do português."
    )
