-- Marca se o conteúdo dos campos "_en" (popular_name_en, description_en,
-- venom_type_en, effective_antivenom_en) já passou por revisão humana ou
-- ainda é fruto só de tradução automática (MT).
--
-- Default false: nenhum conteúdo "_en" no banco até este momento passou por
-- revisão humana/especializada — nem o que ainda está "REVISAR", nem o que
-- vai ser preenchido por MT em lib/scripts/fetch_pending_translations.py +
-- apply_translations.py.
--
-- Rode este script uma vez no SQL Editor do Supabase (ou via psql / Supabase
-- CLI), depois de 0001_add_translation_columns.sql. É idempotente.

alter table public.snakes
  add column if not exists translation_reviewed boolean not null default false;
