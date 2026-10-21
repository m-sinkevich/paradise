-- =====================================================================
--  УДАЛЕНИЕ МОДУЛЯ «MOD-03» вместе со всем, что на него ссылается.
--  Supabase → SQL Editor. Сначала выполните ШАГ 1 (только просмотр),
--  убедитесь, что найден нужный модуль, затем выполните ШАГ 2.
--  Чтобы удалить другой модуль, замените 'MOD-03' в обоих шагах.
-- =====================================================================

-- ШАГ 1. Что будет удалено (ничего не меняет)
with m as (select id, name, access_code from modules where upper(access_code) = 'MOD-03')
select m.name, m.access_code,
  (select count(*) from journal_entries j where j.module_id = m.id) as "записей журнала",
  (select count(*) from logs l where l.module_id = m.id)            as "записей лога",
  (select count(*) from alerts a where a.target_module_id = m.id)    as "угроз только на нём",
  (select count(*) from characters c where m.id = any(c.module_access)) as "персонажей с доступом",
  (select count(*) from content_items ci where m.id = any(ci.module_scope)) as "объектов контента с привязкой"
from m;

-- ШАГ 2. Удаление (выделите блок от begin до commit и нажмите Run)
begin;
  create temp table _del on commit drop as
    select id from modules where upper(access_code) = 'MOD-03';

  -- журнал, лог, прогресс угроз, снимки камеры этого модуля
  delete from journal_entries where module_id in (select id from _del);
  delete from logs            where module_id in (select id from _del);
  delete from threat_progress where module_id in (select id from _del);
  delete from camera_requests where module_id in (select id from _del);

  -- угрозы, назначенные только этому модулю, — удалить;
  -- в угрозах на несколько модулей — убрать модуль из списков
  delete from alerts where target_module_id in (select id from _del)
    and coalesce(array_length(target_module_ids, 1), 1) <= 1;
  update alerts set
    target_module_ids  = array(select x from unnest(target_module_ids) x where x not in (select id from _del)),
    target_module_id   = case when target_module_id in (select id from _del)
                              then (select x from unnest(target_module_ids) x where x not in (select id from _del) limit 1)
                              else target_module_id end,
    excluded_module_ids = array(select x from unnest(coalesce(excluded_module_ids, '{}')) x where x not in (select id from _del))
  where target_module_id in (select id from _del)
     or target_module_ids && array(select id from _del)
     or excluded_module_ids && array(select id from _del);

  -- убрать модуль из доступов персонажей и областей контента
  update characters set module_access = array(select x from unnest(module_access) x where x not in (select id from _del))
    where module_access && array(select id from _del);
  update content_items set module_scope = array(select x from unnest(module_scope) x where x not in (select id from _del))
    where module_scope && array(select id from _del);

  delete from modules where id in (select id from _del);
commit;

-- Проверка: должно вернуть 0 строк
select * from modules where upper(access_code) = 'MOD-03';
