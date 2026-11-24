-- =====================================================================
--  «Будильник» Supabase: функция, которую раз в день вызывает GitHub Actions
--  (.github/workflows/supabase-keepalive.yml). Запись в базу — более весомый сигнал
--  активности, чем одно чтение. На игру не влияет: отдельная служебная таблица.
--  Supabase → SQL Editor → Run. Повторный запуск безопасен.
-- =====================================================================
create table if not exists keepalive (
  id int primary key default 1 check (id = 1),
  pinged_at timestamptz not null default now(),
  pings bigint not null default 0
);

create or replace function keepalive_ping()
returns json language sql security definer set search_path = public as $$
  insert into keepalive (id, pinged_at, pings) values (1, now(), 1)
  on conflict (id) do update set pinged_at = now(), pings = keepalive.pings + 1
  returning json_build_object('pinged_at', pinged_at, 'pings', pings);
$$;
grant execute on function keepalive_ping() to anon, authenticated;

select keepalive_ping() as "будильник работает";
