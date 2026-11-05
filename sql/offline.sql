-- =====================================================================
--  ОФФЛАЙН-РЕЖИМ: досылка оплат кристаллами, сделанных без сети (терминал и сканер).
--  Без сети устройство не может проверить, не потрачен ли кристалл на другом устройстве.
--  Поэтому при досылке оплата засчитывается ВСЕГДА, а повторное использование кристалла
--  записывается в журнал действий как «crystal_conflict» — мастер увидит его во вкладке «Журнал».
--  Supabase → SQL Editor → Run. Повторный запуск безопасен.
-- =====================================================================
create or replace function spend_crystal_offline(p_code text, p_character uuid, p_content uuid, p_module uuid default null,
                                                 p_source text default 'terminal', p_variant text default '',
                                                 p_at timestamptz default now())
returns json language plpgsql as $$
declare
  v_var text := coalesce(p_variant, ''); v_price int; v_paid int; v_done timestamptz; v_id uuid; v_res text := 'ok';
  v_prev record;
begin
  v_price := content_price(p_content, v_var);
  select paid, completed_at into v_paid, v_done from content_payments
    where character_id = p_character and content_id = p_content and variant = v_var;
  if v_done is not null or v_price <= 0 then
    return json_build_object('result', 'already_paid', 'paid', coalesce(v_paid, 0), 'price', v_price, 'completed', true);
  end if;
  update crystals set spent_at = coalesce(p_at, now()), spent_by = p_character, spent_for = p_content, spent_variant = v_var,
                      spent_module = p_module, spent_source = coalesce(p_source, 'terminal') || ' · оффлайн'
    where upper(code) = upper(btrim(p_code)) and spent_at is null
    returning id into v_id;
  if v_id is null then
    select c.spent_at, c.spent_by, c.spent_for, c.spent_source, ch.name as who into v_prev
      from crystals c left join characters ch on ch.id = c.spent_by
      where upper(c.code) = upper(btrim(p_code)) limit 1;
    if not found then
      return json_build_object('result', 'unknown', 'paid', coalesce(v_paid, 0), 'price', v_price, 'completed', false);
    end if;
    -- кристалл уже потрачен (на другом устройстве или раньше): оплату всё равно засчитываем, пишем конфликт
    v_res := 'conflict';
    insert into logs (module_id, character_id, action_type, details, timestamp)
    values (p_module, p_character, 'crystal_conflict',
            jsonb_build_object('code', upper(btrim(p_code)), 'contentId', p_content, 'variant', v_var, 'source', p_source,
                               'offline', true, 'at', p_at, 'firstSpentAt', v_prev.spent_at, 'firstSpentBy', v_prev.who,
                               'firstSpentFor', v_prev.spent_for, 'firstSource', v_prev.spent_source),
            now());
  end if;
  insert into content_payments (character_id, content_id, variant, paid, updated_at) values (p_character, p_content, v_var, 1, now())
    on conflict (character_id, content_id, variant) do update set paid = content_payments.paid + 1, updated_at = now()
    returning paid into v_paid;
  if v_paid >= v_price then
    update content_payments set completed_at = coalesce(p_at, now()) where character_id = p_character and content_id = p_content and variant = v_var;
  end if;
  return json_build_object('result', v_res, 'paid', v_paid, 'price', v_price, 'completed', v_paid >= v_price);
end $$;
grant execute on function spend_crystal_offline(text, uuid, uuid, uuid, text, text, timestamptz) to anon, authenticated;

select 'ok' as "оффлайн-досылка кристаллов готова";
