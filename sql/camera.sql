-- =====================================================================
--  СНИМКИ С КАМЕРЫ ТЕРМИНАЛА (по кнопке в терминале мастера)
--  Supabase → SQL Editor → вставить целиком → Run. Повторный запуск безопасен.
--  Фото сохраняются в хранилище content-media, папка photos/<id модуля>/.
-- =====================================================================
create table if not exists camera_requests (
  id           uuid primary key default gen_random_uuid(),
  module_id    uuid references modules(id) on delete cascade,
  status       text not null default 'pending' check (status in ('pending','processing','done','error')),
  photo_path   text,
  error        text,
  requested_at timestamptz default now(),
  taken_at     timestamptz
);
create index if not exists camera_requests_module_idx on camera_requests (module_id, requested_at desc);

alter table camera_requests enable row level security;
drop policy if exists "allow all for anon" on camera_requests;
create policy "allow all for anon" on camera_requests for all using (true) with check (true);

do $$ begin
  alter publication supabase_realtime add table camera_requests;
exception when duplicate_object then null; end $$;

-- журнал действий читается из logs — индекс для быстрого просмотра по модулю
create index if not exists logs_module_time_idx on logs (module_id, timestamp desc);
