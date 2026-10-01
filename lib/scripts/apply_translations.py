"""
Grava no Supabase a tradução automática (MT) gerada a partir de
`pending_translations.json` -> `pending_translations_translated.json`
(o segundo arquivo é o primeiro com os campos "_en" pendentes preenchidos).

Cada linha atualizada recebe translation_reviewed = false, para marcar que
o conteúdo "_en" foi gerado por tradução automática e ainda não passou por
revisão humana/especializada — decisão tomada deliberadamente para a
apresentação do TCC (ver
lib/scripts/migrations/0002_add_translation_reviewed_flag.sql).

Uso:
    python apply_translations.py

Requer SUPABASE_URL e SUPABASE_SERVICE_KEY em lib/scripts/.env (mesma
convenção do restante do pipeline), e que 0001/0002 já tenham sido rodadas
no Supabase.
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

EN_COLUMNS = [
    "popular_name_en",
    "description_en",
    "venom_type_en",
    "effective_antivenom_en",
]

INPUT_FILE = "pending_translations_translated.json"


def build_update(row):
    update = {}
    for col in EN_COLUMNS:
        value = row.get(col)
        # Só grava o que de fato mudou pra uma tradução real. Se o campo
        # ainda estiver "REVISAR" (ex: não havia conteúdo em pt pra
        # traduzir), não sobrescreve nada.
        if value and value != PENDING:
            update[col] = value
    return update


if __name__ == "__main__":
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        rows = json.load(f)

    updated = 0
    skipped = 0

    for row in rows:
        update = build_update(row)
        if not update:
            skipped += 1
            continue

        update["translation_reviewed"] = False

        supabase.table(TABLE_NAME).update(update).eq("id", row["id"]).execute()
        updated += 1
        print(f"Traduzido: {row['specie']} ({updated}/{len(rows)})")

    print(
        f"\nConcluído: {updated} espécies atualizadas com tradução automática "
        f"(translation_reviewed=false), {skipped} sem alteração (nenhum campo "
        f"com conteúdo pt disponível para traduzir)."
    )
