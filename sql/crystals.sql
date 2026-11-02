-- =====================================================================
--  КРИСТАЛЛЫ — игровая валюта. Каждый кристалл — наклейка с QR-кодом (4 символа).
--  Некоторые объекты контента стоят N кристаллов: персонаж сканирует N разных кристаллов,
--  потраченный кристалл больше не принимается. Оплачено один раз — дальше объект открывается бесплатно.
--  Supabase → SQL Editor → вставить целиком → Run. Повторный запуск безопасен.
--  После этого файла выполните sql/crystals_v2.sql (энергия для вариантов, сброс с возвратом кристаллов).
-- =====================================================================

create table if not exists crystal_groups (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  note       text,
  created_at timestamptz default now()
);

create table if not exists crystals (
  id           uuid primary key default gen_random_uuid(),
  group_id     uuid references crystal_groups(id) on delete cascade,
  code         text not null unique,
  spent_at     timestamptz,
  spent_by     uuid references characters(id) on delete set null,
  spent_for    uuid references content_items(id) on delete set null,
  spent_module uuid references modules(id) on delete set null,
  spent_source text,                       -- terminal | scanner
  created_at   timestamptz default now()
);
create index if not exists crystals_group_idx on crystals (group_id);

-- оплата объекта персонажем: сколько кристаллов внесено; completed_at — объект оплачен
create table if not exists content_payments (
  character_id uuid references characters(id) on delete cascade,
  content_id   uuid references content_items(id) on delete cascade,
  paid         int not null default 0,
  completed_at timestamptz,
  updated_at   timestamptz default now(),
  primary key (character_id, content_id)
);

-- цена объекта в кристаллах (0 — бесплатно)
alter table content_items add column if not exists price int not null default 0;

alter table crystal_groups   enable row level security;
alter table crystals         enable row level security;
alter table content_payments enable row level security;
drop policy if exists "allow all for anon" on crystal_groups;
drop policy if exists "allow all for anon" on crystals;
drop policy if exists "allow all for anon" on content_payments;
create policy "allow all for anon" on crystal_groups   for all using (true) with check (true);
create policy "allow all for anon" on crystals         for all using (true) with check (true);
create policy "allow all for anon" on content_payments for all using (true) with check (true);

-- Списание одного кристалла за объект — атомарно: один кристалл нельзя потратить дважды,
-- даже если два терминала сканируют его одновременно.
-- Ответ: { result: ok | spent | unknown | already_paid, paid, price, completed }
create or replace function spend_crystal(p_code text, p_character uuid, p_content uuid, p_module uuid default null, p_source text default 'terminal')
returns json language plpgsql as $$
declare
  v_price int; v_paid int; v_done timestamptz; v_id uuid;
begin
  select coalesce(price, 0) into v_price from content_items where id = p_content;
  select paid, completed_at into v_paid, v_done from content_payments where character_id = p_character and content_id = p_content;
  if v_done is not null or (v_price <= 0) then
    return json_build_object('result', 'already_paid', 'paid', coalesce(v_paid, 0), 'price', v_price, 'completed', true);
  end if;
  update crystals set spent_at = now(), spent_by = p_character, spent_for = p_content, spent_module = p_module, spent_source = p_source
    where upper(code) = upper(btrim(p_code)) and spent_at is null
    returning id into v_id;
  if v_id is null then
    if exists (select 1 from crystals where upper(code) = upper(btrim(p_code))) then
      return json_build_object('result', 'spent', 'paid', coalesce(v_paid, 0), 'price', v_price, 'completed', false);
    end if;
    return json_build_object('result', 'unknown', 'paid', coalesce(v_paid, 0), 'price', v_price, 'completed', false);
  end if;
  insert into content_payments (character_id, content_id, paid, updated_at) values (p_character, p_content, 1, now())
    on conflict (character_id, content_id) do update set paid = content_payments.paid + 1, updated_at = now()
    returning paid into v_paid;
  if v_paid >= v_price then
    update content_payments set completed_at = now() where character_id = p_character and content_id = p_content;
  end if;
  return json_build_object('result', 'ok', 'paid', v_paid, 'price', v_price, 'completed', v_paid >= v_price);
end $$;
grant execute on function spend_crystal(text, uuid, uuid, uuid, text) to anon, authenticated;

do $$ begin
  begin alter publication supabase_realtime add table crystals; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table content_payments; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table logs; exception when duplicate_object then null; end;
end $$;

select 'ok' as "кристаллы готовы";
