-- =====================================================================
--  УДАЛЕНИЕ КОНТЕНТА И СООБЩЕНИЙ, СОЗДАННЫХ ДО СЕГОДНЯШНЕГО ДНЯ
--  Граница: 28.10.2026 00:00 по Тбилиси (UTC+4). Всё, что создано РАНЬШЕ, удаляется.
--  Чтобы взять другую дату — замените '2026-10-28 00:00:00+04' в обоих шагах.
--
--  Supabase → SQL Editor. Сначала ШАГ 1 (только просмотр), затем ШАГ 2.
--  Файлы (картинки, голосовые) в хранилище не удаляются — только записи в базе.
-- =====================================================================

-- ШАГ 1. Что будет удалено (ничего не меняет)
select 'контент' as "что", count(*) as "будет удалено",
       (select count(*) from content_items where created_at >= '2026-10-28 00:00:00+04') as "останется"
from content_items where created_at < '2026-10-28 00:00:00+04'
union all
select 'сообщения', count(*),
       (select count(*) from comm_messages where created_at >= '2026-10-28 00:00:00+04')
from comm_messages where created_at < '2026-10-28 00:00:00+04';

-- список удаляемого контента
select trigger_code as "код", type as "тип", left(coalesce(body, ''), 60) as "начало текста", created_at as "создан"
from content_items where created_at < '2026-10-28 00:00:00+04' order by created_at;


-- ШАГ 2. Удаление (выделите блок от do до end $$; и нажмите Run)
do $$
declare
  r record; n int;
  old_c uuid[] := array(select id from content_items where created_at < '2026-10-28 00:00:00+04');
  old_m uuid[] := array(select id from comm_messages where created_at < '2026-10-28 00:00:00+04');
begin

  -- все таблицы, которые ссылаются на удаляемые строки (прогресс персонажей, события, текущий контент модуля,
  -- ответы на сообщения и т.п.): необязательная ссылка обнуляется, обязательная — строка удаляется
  for r in
    select cl.relname as tbl, a.attname as col, a.attnotnull as notnull, rf.relname as ref
    from pg_constraint c
    join pg_class cl on cl.oid = c.conrelid
    join pg_class rf on rf.oid = c.confrelid
    join pg_namespace ns on ns.oid = cl.relnamespace
    join pg_attribute a on a.attrelid = c.conrelid and a.attnum = any(c.conkey)
    where c.contype = 'f' and ns.nspname = 'public' and rf.relname in ('content_items', 'comm_messages')
  loop
    if r.tbl = r.ref then continue; end if;   -- ссылки внутри той же таблицы (ответы) — ниже
    if r.notnull then
      execute format('delete from public.%I where %I = any($1)', r.tbl, r.col)
        using case when r.ref = 'content_items' then old_c else old_m end;
    else
      execute format('update public.%I set %I = null where %I = any($1)', r.tbl, r.col, r.col)
        using case when r.ref = 'content_items' then old_c else old_m end;
    end if;
    get diagnostics n = row_count;
    if n > 0 then raise notice '%.%: затронуто строк — %', r.tbl, r.col, n; end if;
  end loop;

  -- ответы на удаляемые сообщения остаются, но без ссылки
  update comm_messages set reply_to = null where reply_to = any(old_m);

  -- в оставшемся контенте убрать ссылки на удалённый: ветвления и «требует предварительного открытия»
  update content_items set choice_options = (
      select coalesce(jsonb_agg(o), '[]'::jsonb) from jsonb_array_elements(choice_options) o
      where coalesce(o->>'nextContentId', '') = '' or (o->>'nextContentId')::uuid <> all(old_c))
  where jsonb_typeof(choice_options) = 'array' and id <> all(old_c);
  update content_items set requires_previous = array(select x from unnest(requires_previous) x where x <> all(old_c))
  where requires_previous && old_c and id <> all(old_c);

  delete from content_items where id = any(old_c);
  get diagnostics n = row_count; raise notice 'Удалено объектов контента: %', n;
  delete from comm_messages where id = any(old_m);
  get diagnostics n = row_count; raise notice 'Удалено сообщений: %', n;
end $$;

-- Проверка: оба числа должны быть 0
select (select count(*) from content_items where created_at < '2026-10-28 00:00:00+04') as "старого контента",
       (select count(*) from comm_messages where created_at < '2026-10-28 00:00:00+04') as "старых сообщений";
