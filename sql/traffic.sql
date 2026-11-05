-- =====================================================================
--  ЭКОНОМИЯ ТРАФИКА: время изменения объектов контента.
--  Сканеры сверяют «id + updated_at» и скачивают контент, только если он изменился.
--  Триггер ставит updated_at при любой правке контента (в том числе SQL-скриптами),
--  кроме отметки «просмотрено» — от неё сканеры не перекачивают базу.
--  Supabase → SQL Editor → Run. Повторный запуск безопасен.
-- =====================================================================
alter table content_items add column if not exists updated_at timestamptz default now();

create or replace function content_items_touch() returns trigger language plpgsql as $$
begin
  if (to_jsonb(new) - 'viewed' - 'viewed_at' - 'updated_at') is distinct from (to_jsonb(old) - 'viewed' - 'viewed_at' - 'updated_at') then
    new.updated_at := now();
  else
    new.updated_at := old.updated_at;
  end if;
  return new;
end $$;

drop trigger if exists content_items_touch on content_items;
create trigger content_items_touch before update on content_items for each row execute function content_items_touch();

-- индексы для быстрых «лёгких проверок» последних записей
do $$ begin
  begin create index if not exists logs_timestamp_idx on logs (timestamp desc); exception when others then null; end;
  begin create index if not exists comm_messages_created_idx on comm_messages (created_at desc); exception when others then null; end;
end $$;

select 'ok' as "экономия трафика включена";
