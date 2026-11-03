-- =====================================================================
--  ЦЕНА СОЗДАНИЯ КАНАЛА СВЯЗИ В КРИСТАЛЛАХ
--  У персонажа, который может создавать каналы, задаётся цена (characters.channel_price).
--  Каждое создание канала — столько кристаллов; кристаллы списываются и канал создаётся
--  одной операцией: не хватило / кристалл уже истощён — ничего не списано и канал не создан.
--  Нужны sql/channels_v2.sql, sql/crystals.sql, sql/crystals_v2.sql.
--  Supabase → SQL Editor → вставить целиком → Run. Повторный запуск безопасен.
-- =====================================================================
alter table characters add column if not exists channel_price int not null default 0;
alter table crystals   add column if not exists spent_purpose text;   -- на что потрачен, если не на объект контента

create or replace function create_channel_paid(
  p_character uuid, p_module uuid, p_source text, p_name text,
  p_allow_text boolean, p_allow_voice boolean, p_allow_photo boolean, p_hidden boolean,
  p_member_modules uuid[], p_member_chars uuid[], p_codes text[] default '{}')
returns json language plpgsql as $$
declare
  c record; v_price int; v_codes text[]; v_bad text[]; v_n int; v_ch uuid;
begin
  select * into c from characters where id = p_character;
  if c.id is null or not (coalesce(c.can_create_channels, false) or coalesce(c.is_hacker, false)) then
    return json_build_object('result', 'forbidden');
  end if;
  if coalesce(btrim(p_name), '') = '' then return json_build_object('result', 'no_name'); end if;
  v_price := greatest(coalesce(c.channel_price, 0), 0);
  select array_agg(distinct upper(btrim(x))) into v_codes from unnest(coalesce(p_codes, '{}')) x where btrim(x) <> '';
  v_codes := coalesce(v_codes, '{}');
  if cardinality(v_codes) < v_price then
    return json_build_object('result', 'need', 'price', v_price, 'given', cardinality(v_codes));
  end if;
  v_codes := v_codes[1:v_price];
  if v_price > 0 then
    select array_agg(x) into v_bad from unnest(v_codes) x
      where not exists (select 1 from crystals k where upper(k.code) = x and k.spent_at is null);
    if v_bad is not null then return json_build_object('result', 'rejected', 'bad', v_bad, 'price', v_price); end if;
    update crystals set spent_at = now(), spent_by = p_character, spent_for = null, spent_variant = null,
                        spent_module = p_module, spent_source = coalesce(p_source, 'terminal'),
                        spent_purpose = 'канал «' || btrim(p_name) || '»'
      where upper(code) = any(v_codes) and spent_at is null;
    get diagnostics v_n = row_count;
    if v_n <> v_price then raise exception 'кристаллы изменились во время оплаты, повторите'; end if;
  end if;
  insert into comm_channels (name, active, created_by_character_id, created_from_module_id, allow_text, allow_voice, allow_photo)
    values (btrim(p_name), true, p_character, p_module, coalesce(p_allow_text, true), coalesce(p_allow_voice, true), coalesce(p_allow_photo, true))
    returning id into v_ch;
  insert into comm_members (channel_id, module_id, source) select v_ch, m, 'player' from unnest(coalesce(p_member_modules, '{}')) m;
  insert into comm_members (channel_id, character_id, source) select v_ch, x, 'player' from unnest(coalesce(p_member_chars, '{}')) x where x <> p_character;
  insert into comm_members (channel_id, character_id, hidden, source) values (v_ch, p_character, coalesce(p_hidden, false) and coalesce(c.is_hacker, false), 'player');
  return json_build_object('result', 'ok', 'channel_id', v_ch, 'spent', v_price);
end $$;
grant execute on function create_channel_paid(uuid, uuid, text, text, boolean, boolean, boolean, boolean, uuid[], uuid[], text[]) to anon, authenticated;

select 'ok' as "цена каналов готова";
