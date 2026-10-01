-- Adiciona colunas de i18n (pt/en) na tabela `snakes` para suportar a UI em inglês.
--
-- Contexto: campos dinâmicos vindos do banco (description, venom_type,
-- effective_antivenom, e o novo popular_name) não podem ser traduzidos com
-- chaves estáticas do easy_localization, então ganham uma coluna "_en" ao
-- lado da coluna existente em português.
--
-- Ficam de fora desta migração:
--   - dentition_type: enum de ~4 valores fixos, traduzido no app via .tr()
--     (ver lib/utils/dentition_helper.dart).
--   - family, genus, specie: nomenclatura científica, universal, não se
--     traduzem.
--
-- Rode este script uma vez no SQL Editor do Supabase (ou via psql / Supabase
-- CLI). É idempotente: pode ser executado de novo sem erro nem sobrescrever
-- conteúdo já curado.

alter table public.snakes
  add column if not exists popular_name_pt text,
  add column if not exists popular_name_en text,
  add column if not exists description_en text,
  add column if not exists venom_type_en text,
  add column if not exists effective_antivenom_en text;

-- Backfill das espécies já cadastradas: nenhum conteúdo é gerado ou
-- traduzido automaticamente. Tudo fica marcado como 'REVISAR' para
-- curadoria manual posterior — seguindo o mesmo padrão já usado em
-- lib/scripts/enrich.py — especialmente importante para venom_type_en e
-- effective_antivenom_en, que são conteúdo clínico.
--
-- effective_antivenom_en segue a mesma regra estrutural da coluna pt: só
-- recebe 'REVISAR' onde effective_antivenom (pt) já tem conteúdo a
-- traduzir; onde a coluna pt é NULL (espécie sem antiveneno aplicável),
-- a coluna en permanece NULL também, em vez de ganhar um 'REVISAR' que
-- nunca vai se aplicar.
update public.snakes
set
  popular_name_pt = coalesce(popular_name_pt, 'REVISAR'),
  popular_name_en = coalesce(popular_name_en, 'REVISAR'),
  description_en = coalesce(description_en, 'REVISAR'),
  venom_type_en = coalesce(venom_type_en, 'REVISAR'),
  effective_antivenom_en = case
    when effective_antivenom is not null then coalesce(effective_antivenom_en, 'REVISAR')
    else effective_antivenom_en
  end;
