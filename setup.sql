-- ═══════════════════════════════════════════════════════════════
-- VERTICAL DASHBOARD — Configuration Supabase (ÉTAT FINAL CONSOLIDÉ)
-- Ticket MB03 — regroupe supabase_setup.sql + update_roles 1→5.
-- À exécuter UNE FOIS sur un projet neuf : Supabase → SQL Editor → New query → Run.
-- Idempotent : ré-exécutable sans casse.
-- ═══════════════════════════════════════════════════════════════

-- 1) TABLES DE DONNÉES ------------------------------------------------
-- Chaque affaire / ligne OTIFIQ / projet = 1 ligne (id + data JSON).
-- Écriture ligne par ligne = correctif du bug multi-utilisateur.
create table if not exists public.affaires (
  id   text primary key,
  data jsonb not null,
  updated_at timestamptz default now()
);
create table if not exists public.otifiq (
  id   text primary key,
  data jsonb not null,
  updated_at timestamptz default now()
);
create table if not exists public.planning (
  id   text primary key,
  data jsonb not null,
  updated_at timestamptz default now()
);

-- 2) PROFILS + RÔLES --------------------------------------------------
-- Rôles : 'admin', 'collaborateur', 'collaborateur2' (lecture seule),
--         'desactive' (aucun accès).
create table if not exists public.profiles (
  id   uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'collaborateur2',
  email text
);

-- Contrainte de rôle (les 4 valeurs autorisées)
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('admin','collaborateur','collaborateur2','desactive'));

-- Nouvel auto-inscrit = collaborateur2 (lecture seule). L'admin promeut ensuite.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, email, role)
  values (new.id, new.email, 'collaborateur2')
  on conflict (id) do nothing;
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Rôle de l'utilisateur courant (SECURITY DEFINER = pas de récursion RLS).
-- Défaut restrictif ('collaborateur2') si le profil est absent.
create or replace function public.my_role()
returns text language sql security definer stable set search_path = public as $$
  select coalesce((select role from public.profiles where id = auth.uid()), 'collaborateur2');
$$;

-- 3) SÉCURITÉ (RLS) — règles imposées PAR LA BASE --------------------
alter table public.affaires enable row level security;
alter table public.otifiq   enable row level security;
alter table public.planning enable row level security;
alter table public.profiles enable row level security;

-- AFFAIRES : lecture = tout compte non désactivé ; écriture = admin + collaborateur ; suppression = admin
drop policy if exists aff_sel on public.affaires;
drop policy if exists aff_ins on public.affaires;
drop policy if exists aff_upd on public.affaires;
drop policy if exists aff_del on public.affaires;
create policy aff_sel on public.affaires for select to authenticated using (my_role() <> 'desactive');
create policy aff_ins on public.affaires for insert to authenticated with check (my_role() in ('admin','collaborateur'));
create policy aff_upd on public.affaires for update to authenticated using (my_role() in ('admin','collaborateur')) with check (my_role() in ('admin','collaborateur'));
create policy aff_del on public.affaires for delete to authenticated using (my_role() = 'admin');

-- PLANNING : idem affaires
drop policy if exists pl_sel on public.planning;
drop policy if exists pl_ins on public.planning;
drop policy if exists pl_upd on public.planning;
drop policy if exists pl_del on public.planning;
create policy pl_sel on public.planning for select to authenticated using (my_role() <> 'desactive');
create policy pl_ins on public.planning for insert to authenticated with check (my_role() in ('admin','collaborateur'));
create policy pl_upd on public.planning for update to authenticated using (my_role() in ('admin','collaborateur')) with check (my_role() in ('admin','collaborateur'));
create policy pl_del on public.planning for delete to authenticated using (my_role() = 'admin');

-- OTIFIQ : lecture = tout compte non désactivé ; saisie = admin + collaborateur ; suppression = admin
drop policy if exists ot_sel on public.otifiq;
drop policy if exists ot_ins on public.otifiq;
drop policy if exists ot_upd on public.otifiq;
drop policy if exists ot_del on public.otifiq;
create policy ot_sel on public.otifiq for select to authenticated using (my_role() <> 'desactive');
create policy ot_ins on public.otifiq for insert to authenticated with check (my_role() in ('admin','collaborateur'));
create policy ot_upd on public.otifiq for update to authenticated using (my_role() in ('admin','collaborateur')) with check (my_role() in ('admin','collaborateur'));
create policy ot_del on public.otifiq for delete to authenticated using (my_role() = 'admin');

-- PROFILS : chacun lit son profil ; l'admin liste et modifie les rôles
drop policy if exists pr_sel_self on public.profiles;
drop policy if exists pr_sel_admin on public.profiles;
drop policy if exists pr_upd_admin on public.profiles;
create policy pr_sel_self  on public.profiles for select to authenticated using (id = auth.uid());
create policy pr_sel_admin on public.profiles for select to authenticated using (my_role() = 'admin');
create policy pr_upd_admin on public.profiles for update to authenticated using (my_role() = 'admin') with check (my_role() = 'admin');

-- 4) TEMPS RÉEL -------------------------------------------------------
-- 'add table' échoue si la table est déjà dans la publication : on ignore l'erreur.
do $$
begin
  begin alter publication supabase_realtime add table public.affaires; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.otifiq;   exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.planning; exception when duplicate_object then null; end;
end $$;

-- ═══════════════════════════════════════════════════════════════
-- APRÈS avoir créé le premier utilisateur (Authentication → Users → Add user),
-- passe-le en admin (remplace l'email) :
--
--   update public.profiles set role = 'admin' where email = 'toi@actiwork.com';
--
-- Les autres restent 'collaborateur2' (lecture seule) à l'inscription ;
-- l'admin les promeut depuis l'onglet « Gestion des comptes ».
-- ═══════════════════════════════════════════════════════════════
