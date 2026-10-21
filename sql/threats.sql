-- =====================================================================
--  УГРОЗЫ — расширение тревог для «Терминала колониста»
--  Supabase → SQL Editor → вставить целиком → Run. Повторный запуск безопасен.
-- =====================================================================

-- 1. Тревога превращается в угрозу: тип (паттерн), параметры, несколько модулей
alter table alerts add column if not exists threat_type text;                       -- seismic, bio, hull, atmo, power, meteo, comms, journal; null — простая тревога
alter table alerts add column if not exists params jsonb default '{}'::jsonb;        -- инструкция, сила, таймер, QR-коды, сценарий…
alter table alerts add column if not exists target_module_ids uuid[];               -- несколько модулей сразу
alter table alerts add column if not exists color text default '#FF6B6B';
alter table alerts add column if not exists sound_url text;
alter table alerts add column if not exists sound_loop boolean default true;
alter table alerts add column if not exists excluded_module_ids uuid[] default '{}'; -- модули, где угроза снята

-- 2. Свои угрозы мастеров (созданные из паттернов) — общие для всех мастеров
create table if not exists threat_presets (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  pattern    text not null,
  config     jsonb not null default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 3. Прогресс устранения по QR-кодам: какие коды угрозы уже отсканированы в каком модуле
create table if not exists threat_progress (
  alert_id     uuid references alerts(id) on delete cascade,
  module_id    uuid references modules(id) on delete cascade,
  code         text not null,
  character_id uuid references characters(id) on delete set null,
  created_at   timestamptz default now(),
  primary key (alert_id, module_id, code)
);

-- Доступ по публичному ключу — как у остальных таблиц терминала
alter table threat_presets  enable row level security;
alter table threat_progress enable row level security;
drop policy if exists "allow all for anon" on threat_presets;
drop policy if exists "allow all for anon" on threat_progress;
create policy "allow all for anon" on threat_presets  for all using (true) with check (true);
create policy "allow all for anon" on threat_progress for all using (true) with check (true);

-- Realtime: прогресс видно в терминале мастера сразу
do $$ begin
  alter publication supabase_realtime add table threat_progress;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table alerts;
exception when duplicate_object then null; end $$;

-- Проверка
select column_name from information_schema.columns where table_name = 'alerts' order by ordinal_position;
