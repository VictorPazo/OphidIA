"""
Aplica regras conhecidas por FAMÍLIA para preencher automaticamente
'dentition_type' e 'poisonous' (padrão bem estabelecido na herpetologia).

Campos que EXIGEM revisão manual/curadoria especializada antes de publicar:
  - description / description_en
  - venom_type / venom_type_en
  - effective_antivenom / effective_antivenom_en
  - popular_name_pt / popular_name_en

Esses ficam marcados com "REVISAR" para você (ou uma fonte como o Instituto
Butantan / SBH) preencher com precisão, especialmente nas espécies peçonhentas.

Os campos "_en" (e popular_name_pt/en) NUNCA são preenchidos por tradução
automática — mesmo os conteúdos clínicos (venom_type/effective_antivenom)
em português exigem curadoria especializada, então as versões em inglês
exigem o mesmo cuidado. Ver lib/scripts/migrations/0001_add_translation_columns.sql
para o backfill das espécies já cadastradas no banco.
"""

import json
import sys

# Regras por família (consolidado a partir da literatura herpetológica padrão)
FAMILY_RULES = {
    "Viperidae": {"dentition_type": "Solenóglifa", "poisonous": True},
    "Elapidae": {"dentition_type": "Proteróglifa", "poisonous": True},
    "Colubridae": {"dentition_type": "Áglifa", "poisonous": False},
    "Dipsadidae": {"dentition_type": "Opistóglifa", "poisonous": False},  # varia; revisar espécie a espécie se possível
    "Boidae": {"dentition_type": "Áglifa", "poisonous": False},
    "Typhlopidae": {"dentition_type": "Áglifa", "poisonous": False},
    "Leptotyphlopidae": {"dentition_type": "Áglifa", "poisonous": False},
    "Anomalepididae": {"dentition_type": "Áglifa", "poisonous": False},
}

DEFAULT_RULE = {"dentition_type": "REVISAR", "poisonous": False}


def enrich_species(species_list):
    enriched = []
    for s in species_list:
        rule = FAMILY_RULES.get(s["family"], DEFAULT_RULE)

        row = {
            "family": s["family"],
            "genus": s["genus"],
            "specie": s["specie"],
            "popular_name_pt": "REVISAR",
            "popular_name_en": "REVISAR",
            "description": "REVISAR - escrever descrição (porte, habitat, comportamento)",
            "description_en": "REVISAR - write description in English (size, habitat, behavior)",
            "poisonous": rule["poisonous"],
            "venom_type": "REVISAR" if rule["poisonous"] else "Não peçonhenta / sem relevância clínica",
            "venom_type_en": "REVISAR",
            "effective_antivenom": "REVISAR" if rule["poisonous"] else None,
            "effective_antivenom_en": "REVISAR" if rule["poisonous"] else None,
            "image_name": f"{s['genus'].lower()}_{s['specie'].split(' ')[-1].lower()}.jpg",
            "dentition_type": rule["dentition_type"],
        }
        enriched.append(row)

    return enriched


if __name__ == "__main__":
    genus = sys.argv[1] if len(sys.argv) > 1 else "Crotalus"

    input_file = f"gbif_{genus.lower()}_raw.json"
    output_file = f"snakes_enriched_{genus.lower()}.json"

    with open(input_file, "r", encoding="utf-8") as f:
        raw_species = json.load(f)

    enriched = enrich_species(raw_species)

    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(enriched, f, ensure_ascii=False, indent=2)

    n_revisar = sum(1 for e in enriched if e["poisonous"])
    print(f"Total: {len(enriched)} espécies")
    print(f"Peçonhentas (precisam de revisão clínica prioritária): {n_revisar}")
    print(f"Salvo em {output_file}")