"""
Grava no Supabase as correções de dentição preenchidas à mão em
`revisao_denticao.csv`.

O CSV traz as espécies que o modelo reconhece e que estavam marcadas como
áglifas ou opistóglifas. A dentição original veio do `enrich.py`, que a
atribuía pela família e não espécie por espécie — e a taxonomia do GBIF põe
vários gêneros sul-americanos em Colubridae, que a regra marcava como áglifa.

Só as linhas com `denticao_correta` preenchida e diferente da atual são
gravadas. Linha em branco quer dizer "está certa".

A dentição decide o nível de risco que o app mostra: uma opistóglifa marcada
como áglifa aparece como risco baixo. Por isso o script recusa qualquer valor
que não seja um dos quatro tipos conhecidos, em vez de gravar um texto que o
app não saberia classificar.

Uso:
    python apply_denticao.py           # simulação, não grava nada
    python apply_denticao.py --gravar  # grava de verdade

Requer SUPABASE_URL e SUPABASE_SERVICE_KEY em lib/scripts/.env.
"""

import csv
import os
import sys
import unicodedata

from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

supabase: Client = create_client(
    os.environ["SUPABASE_URL"],
    os.environ["SUPABASE_SERVICE_KEY"],
)

TABLE_NAME = "snakes"
INPUT_FILE = "revisao_denticao.csv"

DRY_RUN = "--gravar" not in sys.argv

# Grafia exata que o app e o banco usam. A chave é a forma sem acento e em
# minúscula, para aceitar "opistoglifa" ou "OPISTÓGLIFA" digitados no CSV.
TIPOS = {
    "aglifa": "Áglifa",
    "opistoglifa": "Opistóglifa",
    "proteroglifa": "Proteróglifa",
    "solenoglifa": "Solenóglifa",
}

# Proteróglifas e solenóglifas são as peçonhentas de importância em saúde.
PECONHENTAS = {"Proteróglifa", "Solenóglifa"}


def sem_acento(texto):
    texto = unicodedata.normalize("NFKD", texto.strip().lower())
    return "".join(c for c in texto if not unicodedata.combining(c))


def ler_csv():
    with open(INPUT_FILE, "r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


if __name__ == "__main__":

    linhas = ler_csv()
    mudancas, invalidas = [], []

    for linha in linhas:
        digitado = (linha.get("denticao_correta") or "").strip()
        if not digitado:
            continue

        nova = TIPOS.get(sem_acento(digitado))
        if nova is None:
            invalidas.append((linha["specie"], digitado))
            continue

        if nova != linha["denticao_atual"]:
            mudancas.append((linha, nova))

    print(f"Linhas no CSV: {len(linhas)}")
    print(f"  dentição a corrigir: {len(mudancas)}")

    if invalidas:
        print("\nValores não reconhecidos — corrija no CSV e rode de novo:")
        for specie, valor in invalidas:
            print(f"  {specie}: {valor!r}")
        print("\nAceitos: Áglifa, Opistóglifa, Proteróglifa, Solenóglifa.")
        sys.exit(1)

    for linha, nova in mudancas:
        aviso = ""
        if nova in PECONHENTAS:
            aviso = "   <- peçonhenta: grava poisonous=true também"
        print(f"  {linha['specie']:38s} {linha['denticao_atual']} -> {nova}{aviso}")

    if DRY_RUN:
        print("\nSIMULAÇÃO — nada foi gravado. Use --gravar para valer.")
        sys.exit(0)

    for linha, nova in mudancas:
        dados = {"dentition_type": nova}
        if nova in PECONHENTAS:
            dados["poisonous"] = True
        supabase.table(TABLE_NAME).update(dados).eq(
            "id", int(linha["id"])
        ).execute()

    print(f"\nConcluído: {len(mudancas)} dentições corrigidas.")
