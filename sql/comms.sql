-- =====================================================================
--  СВЯЗЬ МЕЖДУ МОДУЛЯМИ И ПЕРСОНАЖАМИ
--  Supabase → SQL Editor → вставить целиком → Run. Повторный запуск безопасен.
--  Медиа сообщений (голос, фото) — в хранилище content-media, папка comms/.
-- =====================================================================

-- Канал связи: куда можно писать (модуль или конкретный персонаж) и что можно отправлять
create table if not exists comm_channels (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null,
  target_module_id    uuid references modules(id) on delete cascade,
  target_character_id uuid references characters(id) on delete cascade,   -- если задан — личный канал персонажу
  two_way             boolean default true,     -- адресат может ответить
  allow_text          boolean default true,
  allow_voice         boolean default true,
  allow_photo         boolean default true,
  unlock_code         text,                      -- QR-код, открывающий канал (необязательно)
  unlock_scope        text default 'module' check (unlock_scope in ('module','character')),  -- кому открывает QR
  active              boolean default true,
  created_at          timestamptz default now()
);

-- Доступ к каналу: модулю или персонажу (выдан мастером или открыт QR-кодом)
create table if not exists comm_grants (
  id           uuid primary key default gen_random_uuid(),
  channel_id   uuid references comm_channels(id) on delete cascade,
  module_id    uuid references modules(id) on delete cascade,
  character_id uuid references characters(id) on delete cascade,
  source       text default 'master' check (source in ('master','qr')),
  created_at   timestamptz default now()
);

-- Сообщения
create table if not exists comm_messages (
  id                uuid primary key default gen_random_uuid(),
  channel_id        uuid references comm_channels(id) on delete set null,
  from_master       boolean default false,
  from_module_id    uuid references modules(id) on delete set null,
  from_character_id uuid references characters(id) on delete set null,
  to_master         boolean default false,
  to_module_id      uuid references modules(id) on delete cascade,
  to_character_id   uuid references characters(id) on delete cascade,     -- личное: читает только этот персонаж после входа
  kind              text not null default 'text' check (kind in ('text','audio','photo')),
  text              text,
  media_path        text,
  reply_to          uuid references comm_messages(id) on delete set null,
  allow_reply       boolean default true,
  read_at           timestamptz,
  created_at        timestamptz default now()
);
create index if not exists comm_messages_to_idx on comm_messages (to_module_id, created_at desc);

alter table comm_channels enable row level security;
alter table comm_grants   enable row level security;
alter table comm_messages enable row level security;
drop policy if exists "allow all for anon" on comm_channels;
drop policy if exists "allow all for anon" on comm_grants;
drop policy if exists "allow all for anon" on comm_messages;
create policy "allow all for anon" on comm_channels for all using (true) with check (true);
create policy "allow all for anon" on comm_grants   for all using (true) with check (true);
create policy "allow all for anon" on comm_messages for all using (true) with check (true);

do $$ begin alter publication supabase_realtime add table comm_messages; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table comm_grants;   exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table comm_channels; exception when duplicate_object then null; end $$;
