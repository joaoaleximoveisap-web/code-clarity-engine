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

create or replace function public.presence_admin_save_event(
  p_code text, p_id uuid, p_slug text, p_title text, p_starts_at timestamptz, p_ends_at timestamptz,
  p_location text, p_description text, p_success_message text, p_theme text, p_is_open boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.presence_events;
begin
  if not public.presence_admin_ok(p_code) then raise exception 'codigo_invalido' using errcode = '28000'; end if;
  if p_id is null then
    insert into public.presence_events (slug, title, starts_at, ends_at, location, description, success_message, theme, is_open, created_by)
    values (p_slug, p_title, p_starts_at, p_ends_at, p_location, p_description, p_success_message, p_theme, p_is_open, null)
    returning * into v;
  else
    update public.presence_events set title = p_title, starts_at = p_starts_at, ends_at = p_ends_at, location = p_location,
      description = p_description, success_message = p_success_message, theme = p_theme, is_open = p_is_open
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
grant execute on function public.presence_admin_save_event(text, uuid, text, text, timestamptz, timestamptz, text, text, text, text, boolean) to anon, authenticated;
grant execute on function public.presence_admin_delete(text, uuid, uuid) to anon, authenticated;

notify pgrst, 'reload schema';
