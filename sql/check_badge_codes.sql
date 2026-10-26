-- =====================================================================
--  ПРОВЕРКА: совпадают ли QR-коды персонажей в базе с напечатанными бейджами
--  Supabase → SQL Editor → Run. Ничего не меняет.
--  Всё в порядке, если в колонке «проблема» везде пусто.
--  Исправить: выполнить sql/catalog.sql (ставит коды как на бейджах).
-- =====================================================================
with badge(name, code) as (values
  ('Гиорги Гхвиношвили','MK8XYW'), ('Арсен Серосян','UNMCH3'), ('Степан Рязин','PN68AC'), ('Сильвио Чирзанне','VS6YE9'),
  ('Эндрю Воллас','YK5V65'), ('Антуан Зиппер','WS5NEX'), ('Магда Берт','EYRT3M'), ('Алиссия Тёрнер','TRD6W3'),
  ('Дилан Бэтч','PH2GAD'), ('Ева Форманн','QNGDK2'), ('Нателла Исайро','BN533Q'), ('Ганеш Шарма','9KH93X'),
  ('Отец Матео Альварес','22HUJR'), ('Маркус Кейн','ZT3H52'), ('Линь Цзинь','9DQMDT'), ('Тамара Орлова','FJKTZD'))
select b.name as "персонаж", b.code as "код на бейдже", c.qr_code as "код в базе",
  c.active as "активен", (c.password is not null and c.password <> '') as "есть пароль",
  (select count(*) from characters x where upper(btrim(x.qr_code)) = b.code) as "строк с этим кодом",
  case
    when c.id is null then 'персонажа с таким именем нет в базе'
    when upper(btrim(coalesce(c.qr_code,''))) <> b.code then 'код в базе другой'
    when c.qr_code <> b.code then 'код в базе с пробелами или строчными буквами'
    when c.active = false then 'персонаж неактивен — вход заблокирован'
    when (select count(*) from characters x where upper(btrim(x.qr_code)) = b.code) > 1 then 'этот код у нескольких персонажей'
    when c.password is not null and c.password <> '' then 'нужен ещё и пароль'
    else ''
  end as "проблема"
from badge b
left join lateral (select * from characters c where lower(btrim(c.name)) = lower(b.name) order by c.active desc nulls last limit 1) c on true
order by "проблема" desc, b.name;
