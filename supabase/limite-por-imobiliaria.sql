-- ================================================================
-- EVENTOS DAJ — LIMITE DE PESSOAS POR IMOBILIÁRIA (02/11/2026)
-- Rodar uma vez no SQL editor do banco do CRM (Lovable → More → Database → Manage → SQL editor).
-- Não apaga nada: só acrescenta a coluna e atualiza as funções.
-- ================================================================

-- 1) Nova coluna: quantas pessoas cada imobiliária pode inscrever (vazio = sem limite).
alter table public.presence_events add column if not exists company_limit int null;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'presence_events_company_limit_check') then
    alter table public.presence_events add constraint presence_events_company_limit_check
      check (company_limit is null or company_limit > 0);
  end if;
end $$;

-- 2) Nome da imobiliária "limpo" para comparar: sem acento, sem maiúscula, sem espaço e pontuação.
--    "Aurora Imóveis Ltda." e "aurora imoveis ltda" contam como a mesma.
create or replace function public.presence_company_key(p text)
returns text language sql immutable as $$
  select regexp_replace(translate(lower(coalesce(p, '')),
    'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'), '[^a-z0-9]', '', 'g');
$$;

-- 3) Trava no banco: a próxima pessoa da mesma imobiliária além do limite é recusada.
create or replace function public.presence_rsvps_company_limit()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_limit int;
begin
  select company_limit into v_limit from public.presence_events where id = new.event_id;
  if v_limit is not null and (
    select count(*) from public.presence_rsvps r
    where r.event_id = new.event_id
      and public.presence_company_key(r.company) = public.presence_company_key(new.company)
  ) >= v_limit then
    raise exception 'limite_imobiliaria' using errcode = '23514';
  end if;
  return new;
end $$;
drop trigger if exists presence_rsvps_company_limit on public.presence_rsvps;
create trigger presence_rsvps_company_limit before insert on public.presence_rsvps
for each row execute function public.presence_rsvps_company_limit();

-- 4) Salvar evento com o limite por imobiliária.
--    p_company_limit: número = limite | 0 = tirar o limite | sem enviar (-1) = mantém como está.
drop function if exists public.presence_admin_save_event(text, uuid, text, text, timestamptz, timestamptz, text, text, text, text, boolean, int, timestamptz, boolean);
create or replace function public.presence_admin_save_event(
  p_code text, p_id uuid, p_slug text, p_title text, p_starts_at timestamptz, p_ends_at timestamptz,
  p_location text, p_description text, p_success_message text, p_theme text, p_is_open boolean,
  p_capacity int, p_registration_deadline timestamptz, p_cancelled boolean, p_company_limit int default -1)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_owner uuid := public.presence_admin_owner(p_code);
  v_slug text := p_slug;
  v public.presence_events;
begin
  if v_owner is null then raise exception 'codigo_invalido' using errcode = '28000'; end if;
  if p_id is null then
    -- O link é único entre todos os gestores: se o nome já existe na área do outro, ganha um final.
    while exists (select 1 from public.presence_events where slug = v_slug) loop
      v_slug := left(regexp_replace(p_slug, '-+$', ''), 75) || '-' || substr(md5(random()::text), 1, 3);
    end loop;
    insert into public.presence_events (slug, title, starts_at, ends_at, location, description, success_message, theme, is_open, capacity, registration_deadline, cancelled, created_by, owner_user_id, company_limit)
    values (v_slug, p_title, p_starts_at, p_ends_at, p_location, p_description, p_success_message, p_theme, p_is_open, p_capacity, p_registration_deadline, coalesce(p_cancelled, false), null, v_owner,
      case when p_company_limit > 0 then p_company_limit end)
    returning * into v;
  else
    update public.presence_events set title = p_title, starts_at = p_starts_at, ends_at = p_ends_at, location = p_location,
      description = p_description, success_message = p_success_message, theme = p_theme, is_open = p_is_open,
      capacity = p_capacity, registration_deadline = p_registration_deadline, cancelled = coalesce(p_cancelled, false),
      company_limit = case when p_company_limit is null or p_company_limit = -1 then company_limit
                           when p_company_limit > 0 then p_company_limit end
    where id = p_id and owner_user_id = v_owner returning * into v;
    if v.id is null then raise exception 'evento_de_outro_gestor' using errcode = '42501'; end if;
  end if;
  return to_jsonb(v);
end $$;
grant execute on function public.presence_admin_save_event(text, uuid, text, text, timestamptz, timestamptz, text, text, text, text, boolean, int, timestamptz, boolean, int) to anon, authenticated;

-- 5) Página do convidado: mesma de antes + o limite por imobiliária (para mostrar no convite).
create or replace function public.presence_public_event(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', e.id, 'slug', e.slug, 'title', e.title, 'starts_at', e.starts_at, 'ends_at', e.ends_at,
    'location', e.location, 'description', e.description, 'success_message', e.success_message, 'theme', e.theme,
    'invite_image', e.invite_image, 'company_limit', e.company_limit, 'state', public.presence_registration_state(e.id))
  from public.presence_events e where e.slug = p_slug;
$$;
grant execute on function public.presence_public_event(text) to anon, authenticated;

notify pgrst, 'reload schema';

-- Conferência (deve mostrar a coluna company_limit e a trava criada):
select column_name from information_schema.columns where table_name = 'presence_events' and column_name = 'company_limit'
union all
select tgname::text from pg_trigger where tgname = 'presence_rsvps_company_limit';
