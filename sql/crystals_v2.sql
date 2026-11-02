-- =====================================================================
--  КРИСТАЛЛЫ v2: энергия для основной страницы и для каждого варианта — раздельно;
--  сброс энергии объекта (снята отметка «просмотрено») возвращает кристаллы в оборот.
--  Выполнить ПОСЛЕ sql/crystals.sql. Supabase → SQL Editor → вставить целиком → Run. Повторный запуск безопасен.
-- =====================================================================

-- оплата: персонаж + объект + вариант ('' — основная страница, иначе id варианта)
alter table content_payments add column if not exists variant text not null default '';
do $$ begin
  if exists (select 1 from pg_constraint where conname = 'content_payments_pkey') then
    alter table content_payments drop constraint content_payments_pkey;
  end if;
  alter table content_payments add constraint content_payments_pkey primary key (character_id, content_id, variant);
end $$;

alter table crystals add column if not exists spent_variant text;
alter table content_items add column if not exists variants jsonb not null default '[]'::jsonb;

-- цена: основная страница — content_items.price, вариант — поле price в content_items.variants
create or replace function content_price(p_content uuid, p_variant text) returns int language sql stable as $$
  select case when coalesce(p_variant, '') = '' then (select coalesce(price, 0) from content_items where id = p_content)
    else coalesce((select nullif(v->>'price', '')::int from content_items ci, jsonb_array_elements(ci.variants) v
                   where ci.id = p_content and v->>'id' = p_variant limit 1), 0) end
$$;

drop function if exists spend_crystal(text, uuid, uuid, uuid, text);
create or replace function spend_crystal(p_code text, p_character uuid, p_content uuid, p_module uuid default null,
                                         p_source text default 'terminal', p_variant text default '')
returns json language plpgsql as $$
declare
  v_var text := coalesce(p_variant, ''); v_price int; v_paid int; v_done timestamptz; v_id uuid;
begin
  v_price := content_price(p_content, v_var);
  select paid, completed_at into v_paid, v_done from content_payments
    where character_id = p_character and content_id = p_content and variant = v_var;
  if v_done is not null or v_price <= 0 then
    return json_build_object('result', 'already_paid', 'paid', coalesce(v_paid, 0), 'price', v_price, 'completed', true);
  end if;
  update crystals set spent_at = now(), spent_by = p_character, spent_for = p_content, spent_variant = v_var,
                      spent_module = p_module, spent_source = p_source
    where upper(code) = upper(btrim(p_code)) and spent_at is null
    returning id into v_id;
  if v_id is null then
    if exists (select 1 from crystals where upper(code) = upper(btrim(p_code))) then
      return json_build_object('result', 'spent', 'paid', coalesce(v_paid, 0), 'price', v_price, 'completed', false);
    end if;
    return json_build_object('result', 'unknown', 'paid', coalesce(v_paid, 0), 'price', v_price, 'completed', false);
  end if;
  insert into content_payments (character_id, content_id, variant, paid, updated_at) values (p_character, p_content, v_var, 1, now())
    on conflict (character_id, content_id, variant) do update set paid = content_payments.paid + 1, updated_at = now()
    returning paid into v_paid;
  if v_paid >= v_price then
    update content_payments set completed_at = now() where character_id = p_character and content_id = p_content and variant = v_var;
  end if;
  return json_build_object('result', 'ok', 'paid', v_paid, 'price', v_price, 'completed', v_paid >= v_price);
end $$;
grant execute on function spend_crystal(text, uuid, uuid, uuid, text, text) to anon, authenticated;

-- сброс энергии объекта: оплаты удаляются, потраченные на него кристаллы снова активны
create or replace function reset_content_energy(p_content uuid) returns json language plpgsql as $$
declare v_c int; v_p int;
begin
  with c as (update crystals set spent_at = null, spent_by = null, spent_for = null, spent_variant = null,
                                 spent_module = null, spent_source = null
             where spent_for = p_content returning 1)
  select count(*) into v_c from c;
  with d as (delete from content_payments where content_id = p_content returning 1)
  select count(*) into v_p from d;
  return json_build_object('crystals', v_c, 'payments', v_p);
end $$;
grant execute on function reset_content_energy(uuid) to anon, authenticated;

select 'ok' as "кристаллы v2 готовы";
