-- =====================================================================
--  ТАЙМАУТ БЕЗДЕЙСТВИЯ В СЕКУНДАХ
--  Новое поле characters.inactivity_timeout_seconds; старые значения в минутах переносятся (× 60).
--  Supabase → SQL Editor → вставить → Run. Повторный запуск безопасен.
-- =====================================================================
alter table characters add column if not exists inactivity_timeout_seconds int;
update characters set inactivity_timeout_seconds = inactivity_timeout_minutes * 60
  where inactivity_timeout_seconds is null and inactivity_timeout_minutes is not null;
select name, inactivity_timeout_seconds from characters where inactivity_timeout_seconds is not null order by name;
