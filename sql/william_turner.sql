-- =====================================================================
--  Новый персонаж: Уильям Тёрнер — капитан корабля Т-50 (военно-научный корпус).
--  Код входа (QR на бейдже): 8P82KJ · номер бейджа: T50-CAP-01
--  Модуля приписки нет (корабль), доступ на терминалы всех модулей.
--  Supabase → SQL Editor → вставить → Run. Повторный запуск безопасен (обновит запись).
-- =====================================================================
do $$
declare cid uuid;
begin
  if exists (select 1 from content_items where upper(trigger_code) = '8P82KJ') then
    raise exception 'Код 8P82KJ уже занят объектом контента — нужен другой код';
  end if;
  select id into cid from characters where lower(btrim(name)) = 'уильям тёрнер' or lower(btrim(name)) = 'уильям тернер' limit 1;
  -- код не должен остаться у другого персонажа
  update characters set qr_code = qr_code || '-OLD' where upper(qr_code) = '8P82KJ' and id is distinct from cid;
  if cid is null then
    insert into characters (name, qr_code, active) values ('Уильям Тёрнер', '8P82KJ', true) returning id into cid;
    raise notice 'Создан персонаж Уильям Тёрнер';
  end if;
  update characters set
    name = 'Уильям Тёрнер', qr_code = '8P82KJ', badge_id = 'T50-CAP-01', active = true,
    photo_url = 'catalog/photos/william.jpg', badge_url = 'badges/william.jpg',
    tagline = 'Капитан корабля Т-50',
    home_module_id = null, module_access = null,
    catalog_order = 17
  where id = cid;
end $$;

select id, name, qr_code, badge_id from characters where qr_code = '8P82KJ';
