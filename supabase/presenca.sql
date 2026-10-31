-- ================================================================
-- CONFIRMAÇÃO DE PRESENÇA — eventos DAJ
-- O gestor cria eventos na aba /confirmacao-presenca (só João Alex).
-- Página pública (repo code-clarity-engine, sem login): a pessoa abre
-- o link do evento e confirma com empresa, função, nome e telefone.
-- ================================================================

create table if not exists public.presence_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  created_by uuid null default auth.uid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]{3,80}$'),
  title text not null check (char_length(btrim(title)) between 1 and 140),
  starts_at timestamptz not null,
  ends_at timestamptz null,
  location text null check (location is null or char_length(location) <= 200),
  description text null check (description is null or char_length(description) <= 2000),
  success_message text null check (success_message is null or char_length(success_message) <= 500),
  theme text not null default 'calm' check (theme in ('calm', 'claro', 'escuro')),
  is_open boolean not null default true
);

create table if not exists public.presence_rsvps (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  event_id uuid not null references public.presence_events(id) on delete cascade,
  company text not null check (char_length(btrim(company)) between 1 and 160),
  job_title text not null check (char_length(btrim(job_title)) between 1 and 120),
  full_name text not null check (char_length(btrim(full_name)) between 1 and 160),
  phone text not null check (phone ~ '^[0-9]{10,13}$'),
  -- Mesmo telefone confirma uma vez só por evento.
  constraint presence_rsvps_event_phone_key unique (event_id, phone)
);

create index if not exists presence_events_starts_idx on public.presence_events (starts_at);
create index if not exists presence_rsvps_event_idx on public.presence_rsvps (event_id, created_at);

alter table public.presence_events enable row level security;
alter table public.presence_rsvps enable row level security;

-- Evento: qualquer um lê (a página pública precisa do nome/horário); só gestor cria e muda.
drop policy if exists "Presence events: anyone can view" on public.presence_events;
create policy "Presence events: anyone can view"
on public.presence_events for select to anon, authenticated using (true);

drop policy if exists "Presence events: admin manages" on public.presence_events;
create policy "Presence events: admin manages"
on public.presence_events for all to authenticated
using (public.is_manager() or public.is_master_admin()) with check (public.is_manager() or public.is_master_admin());

-- Confirmação: qualquer um envia enquanto o evento está aberto; só gestor vê e apaga.
drop policy if exists "Presence rsvps: anyone can confirm" on public.presence_rsvps;
create policy "Presence rsvps: anyone can confirm"
on public.presence_rsvps for insert to anon, authenticated
with check (exists (select 1 from public.presence_events e where e.id = event_id and e.is_open));

drop policy if exists "Presence rsvps: admin can view" on public.presence_rsvps;
create policy "Presence rsvps: admin can view"
on public.presence_rsvps for select to authenticated using (public.is_manager() or public.is_master_admin());

drop policy if exists "Presence rsvps: admin can delete" on public.presence_rsvps;
create policy "Presence rsvps: admin can delete"
on public.presence_rsvps for delete to authenticated using (public.is_manager() or public.is_master_admin());

grant select on public.presence_events to anon, authenticated;
grant insert, update, delete on public.presence_events to authenticated;
grant insert on public.presence_rsvps to anon, authenticated;
grant select, delete on public.presence_rsvps to authenticated;

-- A aba do gestor atualiza na hora em que chega confirmação nova.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'presence_rsvps'
  ) then
    alter publication supabase_realtime add table public.presence_rsvps;
  end if;
end $$;

-- ================================================================
-- V2: vagas, prazo, cancelamento, proteção contra envio em massa
-- (pode rodar mais de uma vez; não apaga nada)
-- ================================================================

alter table public.presence_events add column if not exists capacity int null check (capacity is null or capacity > 0);
alter table public.presence_events add column if not exists registration_deadline timestamptz null;
alter table public.presence_events add column if not exists cancelled boolean not null default false;

-- Situação de inscrição de um evento: ok | fechado | cancelado | prazo | lotado | inexistente
create or replace function public.presence_registration_state(p_event_id uuid)
returns text language sql stable security definer set search_path = public as $$
  select case
    when e.id is null then 'inexistente'
    when e.cancelled then 'cancelado'
    when not e.is_open then 'fechado'
    when e.registration_deadline is not null and now() > e.registration_deadline then 'prazo'
    when e.capacity is not null and (select count(*) from public.presence_rsvps r where r.event_id = e.id) >= e.capacity then 'lotado'
    else 'ok' end
  from (select 1) one left join public.presence_events e on e.id = p_event_id;
$$;
grant execute on function public.presence_registration_state(uuid) to anon, authenticated;

-- Página do convidado: só os dados publicáveis do evento + situação.
create or replace function public.presence_public_event(p_slug text)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', e.id, 'slug', e.slug, 'title', e.title, 'starts_at', e.starts_at, 'ends_at', e.ends_at,
    'location', e.location, 'description', e.description, 'success_message', e.success_message, 'theme', e.theme,
    'state', public.presence_registration_state(e.id))
  from public.presence_events e where e.slug = p_slug;
$$;
grant execute on function public.presence_public_event(text) to anon, authenticated;

drop policy if exists "Presence rsvps: anyone can confirm" on public.presence_rsvps;
create policy "Presence rsvps: anyone can confirm"
on public.presence_rsvps for insert to anon, authenticated
with check (public.presence_registration_state(event_id) = 'ok');

-- Freio contra robô: no máximo 30 confirmações por minuto no mesmo evento.
create or replace function public.presence_rsvps_throttle()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.presence_rsvps where event_id = new.event_id and created_at > now() - interval '1 minute') >= 30 then
    raise exception 'muitas_inscricoes' using errcode = '54000';
  end if;
  return new;
end $$;
drop trigger if exists presence_rsvps_throttle on public.presence_rsvps;
create trigger presence_rsvps_throttle before insert on public.presence_rsvps
for each row execute function public.presence_rsvps_throttle();

-- ================================================================
-- PAINEL DO GESTOR na página pública (code-clarity-engine)
-- Entrada por código de acesso: só o hash fica no banco.
-- Funções security definer: a página nunca lê as tabelas direto.
-- ================================================================

create table if not exists public.presence_admin (
  id int primary key default 1 check (id = 1),
  code_hash text not null
);
alter table public.presence_admin enable row level security;
revoke all on public.presence_admin from anon, authenticated;

insert into public.presence_admin (id, code_hash) values (1, '<sha256 do código de acesso>')
on conflict (id) do update set code_hash = excluded.code_hash;

create or replace function public.presence_admin_ok(p_code text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.presence_admin
    where code_hash = encode(sha256(convert_to(coalesce(p_code, ''), 'UTF8')), 'hex')
  );
$$;

create or replace function public.presence_admin_list(p_code text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.presence_admin_ok(p_code) then raise exception 'codigo_invalido' using errcode = '28000'; end if;
  return coalesce((
    select jsonb_agg(to_jsonb(e) || jsonb_build_object('rsvps', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.created_at)
      from public.presence_rsvps r where r.event_id = e.id
    ), '[]'::jsonb)) order by e.starts_at)
    from public.presence_events e
  ), '[]'::jsonb);
end $$;

drop function if exists public.presence_admin_save_event(text, uuid, text, text, timestamptz, timestamptz, text, text, text, text, boolean);
create or replace function public.presence_admin_save_event(
  p_code text, p_id uuid, p_slug text, p_title text, p_starts_at timestamptz, p_ends_at timestamptz,
  p_location text, p_description text, p_success_message text, p_theme text, p_is_open boolean,
  p_capacity int, p_registration_deadline timestamptz, p_cancelled boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.presence_events;
begin
  if not public.presence_admin_ok(p_code) then raise exception 'codigo_invalido' using errcode = '28000'; end if;
  if p_id is null then
    insert into public.presence_events (slug, title, starts_at, ends_at, location, description, success_message, theme, is_open, capacity, registration_deadline, cancelled, created_by)
    values (p_slug, p_title, p_starts_at, p_ends_at, p_location, p_description, p_success_message, p_theme, p_is_open, p_capacity, p_registration_deadline, coalesce(p_cancelled, false), null)
    returning * into v;
  else
    update public.presence_events set title = p_title, starts_at = p_starts_at, ends_at = p_ends_at, location = p_location,
      description = p_description, success_message = p_success_message, theme = p_theme, is_open = p_is_open,
      capacity = p_capacity, registration_deadline = p_registration_deadline, cancelled = coalesce(p_cancelled, false)
    where id = p_id returning * into v;
  end if;
  return to_jsonb(v);
end $$;

create or replace function public.presence_admin_delete(p_code text, p_event_id uuid, p_rsvp_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.presence_admin_ok(p_code) then raise exception 'codigo_invalido' using errcode = '28000'; end if;
  if p_rsvp_id is not null then delete from public.presence_rsvps where id = p_rsvp_id; end if;
  if p_event_id is not null then delete from public.presence_events where id = p_event_id; end if;
end $$;

revoke all on function public.presence_admin_ok(text) from public, anon, authenticated;
grant execute on function public.presence_admin_list(text) to anon, authenticated;
grant execute on function public.presence_admin_save_event(text, uuid, text, text, timestamptz, timestamptz, text, text, text, text, boolean, int, timestamptz, boolean) to anon, authenticated;
grant execute on function public.presence_admin_delete(text, uuid, uuid) to anon, authenticated;

notify pgrst, 'reload schema';

-- ================================================================
-- V3: CADA GESTOR COM A SUA ÁREA (João Alex e Rodrigo Vicente)
-- Cada código de acesso tem um dono; cada evento tem um dono.
-- O painel do site e a aba Eventos do CRM só mostram os eventos do dono.
-- Pode rodar mais de uma vez; não apaga nenhum evento nem inscrição.
-- ================================================================

-- 1) Dono do evento. Os eventos que já existem são do João Alex.
alter table public.presence_events add column if not exists owner_user_id uuid;
update public.presence_events set owner_user_id = 'fc79a8fa-7a00-419a-87d3-c6d7808903b5' where owner_user_id is null;
alter table public.presence_events alter column owner_user_id set not null;
alter table public.presence_events alter column owner_user_id set default auth.uid();
create index if not exists presence_events_owner_idx on public.presence_events (owner_user_id, starts_at);

-- 2) Códigos de acesso com dono (só o hash fica no banco; ninguém lê a tabela direto).
create table if not exists public.presence_admin_codes (
  code_hash text primary key,
  owner_user_id uuid not null,
  owner_name text not null
);
alter table public.presence_admin_codes enable row level security;
revoke all on public.presence_admin_codes from anon, authenticated;

insert into public.presence_admin_codes (code_hash, owner_user_id, owner_name) values
  ('<sha256 do código do João>', 'fc79a8fa-7a00-419a-87d3-c6d7808903b5', 'João Alex'),
  ('<sha256 do código do Rodrigo>', '419bde53-3a04-49bc-91ec-456f557da7ec', 'Rodrigo Vicente')
on conflict (code_hash) do update set owner_user_id = excluded.owner_user_id, owner_name = excluded.owner_name;

-- 3) Dono do código (null = código inválido).
create or replace function public.presence_admin_owner(p_code text)
returns uuid language sql stable security definer set search_path = public as $$
  select owner_user_id from public.presence_admin_codes
  where code_hash = encode(sha256(convert_to(coalesce(p_code, ''), 'UTF8')), 'hex');
$$;

create or replace function public.presence_admin_ok(p_code text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.presence_admin_owner(p_code) is not null;
$$;

-- 4) Lista: só os eventos do dono do código, com o nome do dono para o topo do painel.
create or replace function public.presence_admin_list(p_code text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_owner uuid := public.presence_admin_owner(p_code);
begin
  if v_owner is null then raise exception 'codigo_invalido' using errcode = '28000'; end if;
  return jsonb_build_object(
    'owner_name', (select c.owner_name from public.presence_admin_codes c where c.owner_user_id = v_owner limit 1),
    'events', coalesce((
      select jsonb_agg(to_jsonb(e) || jsonb_build_object('rsvps', coalesce((
        select jsonb_agg(to_jsonb(r) order by r.created_at)
        from public.presence_rsvps r where r.event_id = e.id
      ), '[]'::jsonb)) order by e.starts_at)
      from public.presence_events e where e.owner_user_id = v_owner
    ), '[]'::jsonb));
end $$;

-- 5) Salvar: evento novo fica com o dono do código; só o dono altera o próprio evento.
create or replace function public.presence_admin_save_event(
  p_code text, p_id uuid, p_slug text, p_title text, p_starts_at timestamptz, p_ends_at timestamptz,
  p_location text, p_description text, p_success_message text, p_theme text, p_is_open boolean,
  p_capacity int, p_registration_deadline timestamptz, p_cancelled boolean)
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
    insert into public.presence_events (slug, title, starts_at, ends_at, location, description, success_message, theme, is_open, capacity, registration_deadline, cancelled, created_by, owner_user_id)
    values (v_slug, p_title, p_starts_at, p_ends_at, p_location, p_description, p_success_message, p_theme, p_is_open, p_capacity, p_registration_deadline, coalesce(p_cancelled, false), null, v_owner)
    returning * into v;
  else
    update public.presence_events set title = p_title, starts_at = p_starts_at, ends_at = p_ends_at, location = p_location,
      description = p_description, success_message = p_success_message, theme = p_theme, is_open = p_is_open,
      capacity = p_capacity, registration_deadline = p_registration_deadline, cancelled = coalesce(p_cancelled, false)
    where id = p_id and owner_user_id = v_owner returning * into v;
    if v.id is null then raise exception 'evento_de_outro_gestor' using errcode = '42501'; end if;
  end if;
  return to_jsonb(v);
end $$;

-- 6) Excluir: só evento do dono, ou inscrição de evento do dono.
create or replace function public.presence_admin_delete(p_code text, p_event_id uuid, p_rsvp_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_owner uuid := public.presence_admin_owner(p_code);
begin
  if v_owner is null then raise exception 'codigo_invalido' using errcode = '28000'; end if;
  if p_rsvp_id is not null then
    delete from public.presence_rsvps r using public.presence_events e
    where r.id = p_rsvp_id and e.id = r.event_id and e.owner_user_id = v_owner;
  end if;
  if p_event_id is not null then
    delete from public.presence_events where id = p_event_id and owner_user_id = v_owner;
  end if;
end $$;

revoke all on function public.presence_admin_owner(text) from public, anon, authenticated;
revoke all on function public.presence_admin_ok(text) from public, anon, authenticated;
grant execute on function public.presence_admin_list(text) to anon, authenticated;
grant execute on function public.presence_admin_save_event(text, uuid, text, text, timestamptz, timestamptz, text, text, text, text, boolean, int, timestamptz, boolean) to anon, authenticated;
grant execute on function public.presence_admin_delete(text, uuid, uuid) to anon, authenticated;

-- 7) CRM: cada um vê e mexe só no que é seu (a leitura pública do evento continua para a página do convidado).
drop policy if exists "Presence events: admin manages" on public.presence_events;
drop policy if exists "Presence events: owner manages" on public.presence_events;
create policy "Presence events: owner manages"
on public.presence_events for all to authenticated
using (owner_user_id = auth.uid()) with check (owner_user_id = auth.uid());

drop policy if exists "Presence rsvps: admin can view" on public.presence_rsvps;
drop policy if exists "Presence rsvps: owner can view" on public.presence_rsvps;
create policy "Presence rsvps: owner can view"
on public.presence_rsvps for select to authenticated
using (exists (select 1 from public.presence_events e where e.id = event_id and e.owner_user_id = auth.uid()));

drop policy if exists "Presence rsvps: admin can delete" on public.presence_rsvps;
drop policy if exists "Presence rsvps: owner can delete" on public.presence_rsvps;
create policy "Presence rsvps: owner can delete"
on public.presence_rsvps for delete to authenticated
using (exists (select 1 from public.presence_events e where e.id = event_id and e.owner_user_id = auth.uid()));

notify pgrst, 'reload schema';
