-- =====================================================================
--  АРТЕФАКТ А-01 «универсальная деталь».
--   • все — неопознанный искусственный обломок, явно не с Сола;
--   • Степан Рязин и Арсен Серосян — заменяет 1 деталь в большинстве ремонтов и конструкций.
--  Код QR: SDT558. Supabase → SQL Editor → Run. Повторный запуск обновляет тот же объект.
-- =====================================================================
do $$
declare tech uuid[]; id1 uuid;
  gen text := $q$## Неопознанный объект · А-01
Небольшой кусок чего-то явно **искусственно созданного**: слишком правильные грани, гладкие стыки, внутри при повороте пробегают отблески, будто по тонким каналам. Похоже на деталь — обломок или часть механизма.

Материал холодный и неожиданно лёгкий. Ни маркировки, ни заводских клейм, ни одного знакомого стандарта крепежа. **Сделано точно не на Соле** — ни один известный завод Метрополии так не работает.

> Назначение неизвестно. Нужен техник, который разберётся, на что это годится.$q$;
  tch text := $q$## Универсальная деталь · А-01 · техническая сводка
*Неземное изделие. Сплав неизвестного состава с кристаллической решёткой внутри.*

При контакте с любым механизмом объект **подстраивается под него**. Решётка внутри перестраивается, и через несколько минут деталь принимает нужную форму, размер и проводимость.

**Применение.** Заменяет **одну любую недостающую деталь** в большинстве ремонтов и конструкций:
- шестерню, вал, клапан, плату, фильтр, крепёж, проводник;
- силовой элемент или узел связи.

Приложить к месту установки и подождать, пока форма «сядет». Дальше деталь работает как родная.

**Ограничения:**
- одноразово: принявшая форму деталь обратно не перестраивается;
- одна деталь заменяет одну деталь, а не целый узел;
- не подходит для оружия и систем, которые прямо сейчас под высоким напряжением: решётка «гаснет».

**Наблюдение.** Похожий сплав упоминается в закрытых сводках по Гелиосу и Бетельгейзе. Если военные узнают о находке, её заберут. Вопрос, кому показывать.

> *Игровое правило:* предъявите эту карточку мастеру или на ремонте вместо одной требуемой детали. После использования объект считается потраченным.$q$;
begin
  select array_agg(id) into tech from characters where lower(btrim(name)) like 'степан рязин%' or lower(btrim(name)) like 'арсен серосян%';
  if coalesce(cardinality(tech), 0) < 2 then raise exception 'Не найдены Степан Рязин и/или Арсен Серосян'; end if;
  if exists (select 1 from content_items where upper(trigger_code) = 'SDT558' and coalesce(summary, '') not like 'Артефакт А-01%') then
    raise exception 'Код SDT558 уже занят другим объектом';
  end if;
  select id into id1 from content_items where trigger_code = 'SDT558';
  if id1 is null then
    insert into content_items (trigger_code, type, body, playback, unlock_condition) values ('SDT558', 'text', gen, 'unlimited', '{"type":"always"}') returning id into id1;
  end if;
  update content_items set
    type = 'text', body = gen, playback = 'unlimited', unlock_condition = '{"type":"always"}'::jsonb,
    module_scope = null, character_scope = null, choice_options = null, price = 0,
    summary = 'Артефакт А-01: универсальная деталь (техники — Степан, Арсен)',
    blocks = jsonb_build_array(jsonb_build_object('type', 'text', 'md', gen, 'width', 'full', 'style', 'plain')),
    variants = jsonb_build_array(jsonb_build_object('id', 'techsdt558', 'price', 0, 'character_ids', to_jsonb(tech), 'module_ids', '[]'::jsonb,
      'body', tch, 'choice_options', '[]'::jsonb,
      'blocks', jsonb_build_array(jsonb_build_object('type', 'text', 'md', tch, 'width', 'full', 'style', 'plain')))),
    viewed = coalesce(viewed, false)
  where id = id1;
end $$;

select trigger_code as "код QR", summary from content_items where summary like 'Артефакт А-01%';
