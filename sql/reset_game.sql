-- =====================================================================
--  СБРОС ИГРЫ: чистый лист перед игрой (или после прогона).
--  Supabase → SQL Editor → вставить целиком → Run.  ОТМЕНИТЬ НЕЛЬЗЯ.
--
--  Удаляется:
--    • журнал действий (logs) и бортовые журналы модулей (journal_entries);
--    • все сообщения (каналы, «Центр управления»), запросы и снимки камеры;
--    • каналы, созданные игроками, и доступы к каналам, открытые по QR
--      (каналы мастера и выданные мастером участники остаются);
--    • прогресс персонажей (что открывали), отметки «просмотрено», внесённая энергия;
--      все кристаллы снова активны;
--    • все запущенные и запланированные угрозы и их прогресс
--      (свои шаблоны угроз и настройки шаблонов остаются);
--    • файлы голосовых записей журнала, сообщений и снимков камеры в хранилище
--      (папки journal/, comms/, photos/ — картинки и звуки контента не трогаются).
--
--  Остаются: персонажи, модули, контент, кристаллы (коды и группы), шаблоны угроз, каналы мастера.
--
--  ПЕРЕД ЗАПУСКОМ: сделайте синхронизацию на всех сканерах и «Отправить накопленное» на
--  терминалах в оффлайн-режиме — иначе старые записи из их очередей придут уже после сброса.
--  ПОСЛЕ: перезагрузите терминалы (F5) и на оффлайн-терминалах заново «Выгрузить базу»;
--  на сканерах — «Обновить базу».
-- =====================================================================
do $$
declare
  n bigint;
  report text := '';
  -- удалить все строки таблицы, если она есть
  procedure_tables text[] := array['logs', 'journal_entries', 'comm_messages', 'camera_requests',
                                   'character_progress', 'content_payments', 'threat_progress', 'alerts'];
  t text;
begin
  foreach t in array procedure_tables loop
    if to_regclass('public.' || t) is not null then
      execute format('delete from public.%I', t);
      get diagnostics n = row_count;
      report := report || format('%s: удалено %s; ', t, n);
    end if;
  end loop;

  -- каналы игроков и доступы по QR
  if to_regclass('public.comm_channels') is not null then
    if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'comm_channels' and column_name = 'created_by_character_id') then
      delete from comm_channels where created_by_character_id is not null;
      get diagnostics n = row_count;
      report := report || format('каналов игроков: %s; ', n);
    end if;
  end if;
  if to_regclass('public.comm_members') is not null then
    delete from comm_members where coalesce(source, 'master') <> 'master';
    get diagnostics n = row_count;
    report := report || format('участников по QR/игроков: %s; ', n);
  end if;
  if to_regclass('public.comm_grants') is not null then
    delete from comm_grants where coalesce(source, 'master') <> 'master';
    get diagnostics n = row_count;
    report := report || format('доступов по QR: %s; ', n);
  end if;

  -- кристаллы снова активны
  if to_regclass('public.crystals') is not null then
    update crystals set spent_at = null where spent_at is not null;
    get diagnostics n = row_count;
    report := report || format('кристаллов включено снова: %s; ', n);
    -- остальные «spent_*» колонки (кто, за что, где) — если есть
    for t in select column_name from information_schema.columns
             where table_schema = 'public' and table_name = 'crystals' and column_name like 'spent\_%' and column_name <> 'spent_at' loop
      execute format('update public.crystals set %I = null', t);
    end loop;
  end if;

  -- отметки «просмотрено» у контента
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'content_items' and column_name = 'viewed') then
    update content_items set viewed = false where viewed is distinct from false;
    get diagnostics n = row_count;
    report := report || format('контента «не просмотрено»: %s; ', n);
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'content_items' and column_name = 'viewed_at') then
    update content_items set viewed_at = null where viewed_at is not null;
  end if;

  -- таймер «тишины журнала» модулей — отсчёт заново
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'modules' and column_name = 'last_journal_entry_at') then
    update modules set last_journal_entry_at = null;
  end if;

  raise notice 'СБРОС: %', report;
end $$;

-- файлы голосовых журналов, сообщений и снимков камеры
do $$
declare n bigint;
begin
  -- Supabase запрещает удалять из хранилища SQL-запросом без этого флага (действует только до конца запроса)
  perform set_config('storage.allow_delete_query', 'true', true);
  delete from storage.objects
   where bucket_id = 'content-media'
     and (name like 'journal/%' or name like 'comms/%' or name like 'photos/%');
  get diagnostics n = row_count;
  raise notice 'ФАЙЛЫ: удалено %', n;
exception when others then
  raise notice 'ФАЙЛЫ не удалены (%): удалите папки journal, comms, photos вручную — Storage → content-media', sqlerrm;
end $$;

-- проверка: всё по нулям
select 'журнал действий' as "что", count(*) as "осталось" from logs
union all select 'бортовые журналы', count(*) from journal_entries
union all select 'сообщения', count(*) from comm_messages
union all select 'прогресс персонажей', count(*) from character_progress
union all select 'внесённая энергия', count(*) from content_payments
union all select 'угрозы', count(*) from alerts
union all select 'потраченные кристаллы', count(*) from crystals where spent_at is not null
union all select 'файлы журналов/сообщений/камеры', count(*) from storage.objects
  where bucket_id = 'content-media' and (name like 'journal/%' or name like 'comms/%' or name like 'photos/%');
