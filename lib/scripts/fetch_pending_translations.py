"""
Busca todas as espécies com pelo menos um campo "_en" ainda marcado como
"REVISAR", para alimentar a etapa de tradução automática (MT) descrita em
lib/scripts/README.md. Gera `pending_translations.json` com o conteúdo
original em português ao lado dos campos "_en" pendentes.

Uso:
    python fetch_pending_translations.py

Requer SUPABASE_URL e SUPABASE_SERVICE_KEY em lib/scripts/.env (mesma
convenção do restante do pipeline).
"""

import json
import os

from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]

supabase: Client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

TABLE_NAME = "snakes"
PENDING = "REVISAR"

COLUMNS = [
    "id",
    "specie",
    "poisonous",
    "popular_name_pt",
    "popular_name_en",
    "description",
    "description_en",
    "venom_type",
    "venom_type_en",
    "effective_antivenom",
    "effective_antivenom_en",
]

EN_COLUMNS = [
    "popular_name_en",
    "description_en",
    "venom_type_en",
    "effective_antivenom_en",
]


def fetch_pending_rows():
    rows = []
    page_size = 1000
    start = 0
    or_filter = ",".join(f"{col}.eq.{PENDING}" for col in EN_COLUMNS)

    while True:
        resp = (
            supabase.table(TABLE_NAME)
            .select(",".join(COLUMNS))
            .or_(or_filter)
            .range(start, start + page_size - 1)
            .execute()
        )
        batch = resp.data
        if not batch:
            break
        rows.extend(batch)
        if len(batch) < page_size:
            break
        start += page_size

    return rows


if __name__ == "__main__":
    rows = fetch_pending_rows()
    print(f"Espécies com pelo menos um campo _en pendente: {len(rows)}")

    with open("pending_translations.json", "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)

    print("Salvo em pending_translations.json")
