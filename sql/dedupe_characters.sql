-- =====================================================================
--  УДАЛЕНИЕ ДУБЛИКАТОВ ПЕРСОНАЖЕЙ
--  Дубликаты — персонажи с одинаковым именем (без учёта регистра и
--  пробелов по краям). Из каждой группы остаётся созданный ПОЗДНЕЕ всех.
--  В таблице characters нет даты создания, поэтому порядок берётся из
--  служебного номера транзакции строки (xmin): чем он больше, тем позже
--  строка была записана. Если старого персонажа потом редактировали,
--  он считается «более поздним» — проверьте это в ШАГЕ 1.
--  Записи журнала, лога, сообщения и доступы удалённых дублей
--  переносятся на оставшегося персонажа — история не теряется.
--
--  Supabase → SQL Editor. Сначала ШАГ 1 (только просмотр), затем ШАГ 2.
-- =====================================================================

-- ШАГ 1. Что будет сделано (ничего не меняет)
with ranked as (
  select id, name, badge_id, qr_code, xmin::text::bigint as tx,
         first_value(id) over w as keep_id,
         row_number()    over w as rn,
         count(*)        over (partition by lower(btrim(name))) as cnt
  from characters
  where coalesce(btrim(name), '') <> ''
  window w as (partition by lower(btrim(name)) order by xmin::text::bigint desc, id desc)
)
select name, badge_id, qr_code, tx as "порядок записи",
       case when rn = 1 then 'ОСТАНЕТСЯ' else 'будет удалён' end as "действие"
from ranked
where cnt > 1
order by lower(btrim(name)), rn;


-- ШАГ 2. Удаление (выделите весь блок от do до последней строки и нажмите Run)
do $$
declare
  col record;
  n int;
  map_sql constant text :=
    '(select id, keep_id from (
        select id, first_value(id) over (partition by lower(btrim(name))
                                         order by xmin::text::bigint desc, id desc) as keep_id
        from characters where coalesce(btrim(name), '''') <> '''') r
      where id <> keep_id)';
begin
  -- 1) все ссылки на дубли (любые колонки *character_id в схеме public) — на оставшегося персонажа
  for col in
    select table_name, column_name
    from information_schema.columns
    where table_schema = 'public' and table_name <> 'characters'
      and column_name like '%character_id' and data_type = 'uuid'
  loop
    execute format('update public.%I t set %I = m.keep_id from %s m where t.%I = m.id',
                   col.table_name, col.column_name, map_sql, col.column_name);
    get diagnostics n = row_count;
    if n > 0 then raise notice '%.%: перенесено строк — %', col.table_name, col.column_name, n; end if;
  end loop;

  -- 2) удалить сами дубли
  execute 'delete from characters c using ' || map_sql || ' m where c.id = m.id';
  get diagnostics n = row_count;
  raise notice 'Удалено дублей персонажей: %', n;
end $$;

-- Проверка: должно вернуть 0 строк
select lower(btrim(name)) as name, count(*) from characters
where coalesce(btrim(name), '') <> ''
group by 1 having count(*) > 1;

-- ШАГ 3 (необязательно). Добавить дату создания, чтобы дальше порядок был точным.
-- У уже существующих персонажей будет одинаковая дата — момента выполнения.
alter table characters add column if not exists created_at timestamptz not null default now();
