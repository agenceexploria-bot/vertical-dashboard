-- ═══════════════════════════════════════════════════════════════
-- MB03 — Sécurité : tout nouvel auto-inscrit = LECTEUR par défaut
-- (au lieu de collaborateur). L'admin promeut ensuite si besoin.
-- À exécuter dans Supabase → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════

-- 1) Nouveau compte créé via inscription → rôle 'lecteur'
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, email, role)
  values (new.id, new.email, 'lecteur')
  on conflict (id) do nothing;
  return new;
end; $$;

-- 2) Un utilisateur sans profil est traité comme lecteur (défaut restrictif côté RLS)
create or replace function public.my_role()
returns text language sql security definer stable set search_path = public as $$
  select coalesce((select role from public.profiles where id = auth.uid()), 'lecteur');
$$;

-- ═══════════════════════════════════════════════════════════════
-- Pour promouvoir un compte ensuite :
--   update public.profiles set role='collaborateur' where email='...';
--   update public.profiles set role='admin'         where email='...';
-- ═══════════════════════════════════════════════════════════════
