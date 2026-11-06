-- =====================================================================
--  РАЗГЕРМЕТИЗАЦИЯ: QR-датчики пробоя обшивки MFFAKJ, 79M6BS, 5CSV79.
--  Наклеиваются снаружи модуля. Во время угрозы «Разгерметизация» скан в терминале засчитывает
--  устранение пробоя (коды прописаны в шаблоне угрозы). Вне угрозы — этот текст.
--  Содержимое у всех трёх одинаковое. 4 копии QR каждого — по одной на модуль.
--  Supabase → SQL Editor → Run. Повторный запуск безопасен.
-- =====================================================================
alter table content_items add column if not exists qr_copies int not null default 1;
do $$
declare c text; n int := 0; id1 uuid;
  b text := $q$## ◎ Датчик пробоя обшивки
**Код связи с блоком контроля обшивки принят.**

Аварийный датчик внешнего контура: срабатывает при пробое купола и ведёт к месту повреждения.

Датчик снят с обшивки. Сектор помечен как проверенный, сигнал передан в систему герметизации модуля.

> Если модуль в режиме **разгерметизации** — сканируйте все датчики, снятые с обшивки: каждый подтверждает герметизацию своего сектора.$q$;
begin
  foreach c in array array['MFFAKJ', '79M6BS', '5CSV79'] loop
    n := n + 1;
    id1 := null;
    select id into id1 from content_items where upper(trigger_code) = c;
    if id1 is null then
      insert into content_items (trigger_code, type, body, playback, unlock_condition) values (c, 'text', b, 'unlimited', '{"type":"always"}') returning id into id1;
    end if;
    update content_items set
      trigger_code = c, type = 'text', body = b, playback = 'unlimited', unlock_condition = '{"type":"always"}'::jsonb,
      module_scope = null, character_scope = null, choice_options = null, price = 0, qr_copies = 4,
      summary = 'Разгерметизация: датчик пробоя обшивки ' || n,
      blocks = jsonb_build_array(jsonb_build_object('type', 'text', 'md', b, 'width', 'full', 'style', 'plain')),
      variants = '[]'::jsonb
    where id = id1;
  end loop;
end $$;

select trigger_code as "код QR", summary, qr_copies as "копий" from content_items
where upper(trigger_code) in ('MFFAKJ', '79M6BS', '5CSV79') order by summary;
