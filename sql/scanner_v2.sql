-- =====================================================================
--  СКАНЕР NFC v2: вход персонажем, контент мастерки, три типа сканера
--  Supabase → SQL Editor → вставить целиком → Run. Повторный запуск безопасен.
-- =====================================================================

-- тип сканера персонажа: medic | tech | sci; пусто — доступ к сканеру запрещён
alter table characters add column if not exists scanner_mode text
  check (scanner_mode is null or scanner_mode in ('medic', 'tech', 'sci'));

update characters set scanner_mode = 'sci'   where name ilike '%Шарма%' or name ilike 'Ганеш%';
update characters set scanner_mode = 'tech'  where name ilike '%Рязин %' or name ilike '%Рязин';
update characters set scanner_mode = 'sci'   where name ilike '%Чирзанне%';
update characters set scanner_mode = 'tech'  where name ilike '%Зиппер%';
update characters set scanner_mode = 'medic' where name ilike '%Исайро%';
update characters set scanner_mode = 'tech'  where name ilike '%Цзинь%';

-- профили сканеров: цвета интерфейса (в приложении цвет задаётся типом, здесь — для панели меток)
insert into scan_modes (id, name, color, subtitle, sort) values
  ('medic', 'Медицинский', '#F4F8FB', 'Биомонитор полевого медика', 1),
  ('tech',  'Технический', '#3DB8FF', 'Диагностика оборудования и конструкций', 2),
  ('sci',   'Научный',     '#46F08C', 'Спектральный и биологический анализ', 3)
on conflict (id) do update set name = excluded.name, color = excluded.color;

-- проверка
select name, qr_code, scanner_mode from characters where scanner_mode is not null order by scanner_mode, name;
