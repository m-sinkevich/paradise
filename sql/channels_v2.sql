-- =====================================================================
--  КАНАЛЫ СВЯЗИ v2 + ВАРИАНТЫ КОНТЕНТА
--  Supabase → SQL Editor → вставить целиком → Run. Повторный запуск безопасен.
--  Нужен уже выполненный sql/comms.sql.
--
--  Канал теперь — общий чат: участники — модули и/или персонажи (сколько угодно).
--  Хакер может быть скрытым участником: остальные его не видят в списке.
--  Старые каналы («куда пишут» + «кому выдан доступ») переносятся в участников.
-- =====================================================================

-- Участники канала
create table if not exists comm_members (
  id           uuid primary key default gen_random_uuid(),
  channel_id   uuid not null references comm_channels(id) on delete cascade,
  module_id    uuid references modules(id) on delete cascade,
  character_id uuid references characters(id) on delete cascade,
  hidden       boolean not null default false,        -- скрытый участник (хакер): не виден остальным
  source       text default 'master',                  -- master | qr | player
  created_at   timestamptz default now(),
  check (module_id is not null or character_id is not null)
);
create index if not exists comm_members_channel_idx on comm_members (channel_id);

-- Кто создал канал (персонаж с терминала) и его модуль
alter table comm_channels add column if not exists created_by_character_id uuid references characters(id) on delete set null;
alter table comm_channels add column if not exists created_from_module_id  uuid references modules(id) on delete set null;

-- Сообщения: подпись мастера «от кого», анонимно (скрытый участник)
alter table comm_messages add column if not exists from_label text;
alter table comm_messages add column if not exists anon boolean not null default false;
create index if not exists comm_messages_channel_idx on comm_messages (channel_id, created_at desc);

-- Способности персонажа
alter table characters add column if not exists can_create_channels boolean not null default false;
alter table characters add column if not exists is_hacker boolean not null default false;

-- Варианты текста контента для конкретных персонажей:
-- [{ "character_ids": ["uuid", ...], "body": "текст (markdown)" }, ...]
alter table content_items add column if not exists variants jsonb not null default '[]'::jsonb;

alter table comm_members enable row level security;
drop policy if exists "allow all for anon" on comm_members;
create policy "allow all for anon" on comm_members for all using (true) with check (true);

do $$ begin
  begin alter publication supabase_realtime add table comm_members; exception when duplicate_object then null; end;
end $$;

-- Перенос старых каналов: адресат канала и все, кому был выдан доступ, становятся участниками
insert into comm_members (channel_id, module_id, character_id, source)
select c.id, c.target_module_id, c.target_character_id, 'master'
from comm_channels c
where (c.target_module_id is not null or c.target_character_id is not null)
  and not exists (select 1 from comm_members m where m.channel_id = c.id
                  and m.module_id is not distinct from c.target_module_id
                  and m.character_id is not distinct from c.target_character_id);

insert into comm_members (channel_id, module_id, character_id, source)
select g.channel_id, g.module_id, g.character_id, coalesce(g.source, 'master')
from comm_grants g
where not exists (select 1 from comm_members m where m.channel_id = g.channel_id
                  and m.module_id is not distinct from g.module_id
                  and m.character_id is not distinct from g.character_id);

-- Проверка
select c.name as "канал", count(m.id) as "участников"
from comm_channels c left join comm_members m on m.channel_id = c.id
group by c.id, c.name order by c.name;
