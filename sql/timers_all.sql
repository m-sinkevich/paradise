-- =====================================================================
--  ВСЕМ ПЕРСОНАЖАМ: сессия 3 минуты, бездействие 30 секунд.
--  Нужен выполненный sql/inactivity_seconds.sql (поле в секундах).
--  Supabase → SQL Editor → вставить → Run.
-- =====================================================================
alter table characters add column if not exists inactivity_timeout_seconds int;

update characters set
  session_timeout_minutes    = 3,
  inactivity_timeout_seconds = 30,
  inactivity_timeout_minutes = null;

select name, session_timeout_minutes as "сессия, мин", inactivity_timeout_seconds as "бездействие, с"
from characters order by name;
