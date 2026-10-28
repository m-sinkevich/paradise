-- =====================================================================
--  КОНТЕНТ: краткое описание, доступ персонажам, статус «просмотрено»
--  Supabase → SQL Editor → вставить целиком → Run. Повторный запуск безопасен.
-- =====================================================================
alter table content_items add column if not exists summary         text;        -- краткое описание для мастеров
alter table content_items add column if not exists character_scope uuid[];      -- кому доступно (пусто = всем)
alter table content_items add column if not exists viewed          boolean;     -- просмотрено (ставит терминал, меняет мастер)
alter table content_items add column if not exists viewed_at       timestamptz;
alter table content_items add column if not exists variants        jsonb not null default '[]'::jsonb;

-- уже открытые персонажами объекты отмечаем просмотренными
update content_items c set viewed = true, viewed_at = coalesce(c.viewed_at, p.first_at)
from (select content_id, min(first_opened_at) as first_at from character_progress group by content_id) p
where p.content_id = c.id and c.viewed is null;
update content_items set viewed = false where viewed is null;
