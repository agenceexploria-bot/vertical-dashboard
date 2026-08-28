-- ═══════════════════════════════════════════════════════════════
-- MB03 — Le collaborateur peut MODIFIER (affaires + planning)
-- Suppression réservée à l'admin. Lecteur = lecture seule.
-- À exécuter dans Supabase → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════

-- AFFAIRES : création + modification par admin & collaborateur ; suppression = admin
drop policy if exists aff_ins on public.affaires;
drop policy if exists aff_upd on public.affaires;
create policy aff_ins on public.affaires for insert to authenticated
  with check (my_role() in ('admin','collaborateur'));
create policy aff_upd on public.affaires for update to authenticated
  using (my_role() in ('admin','collaborateur'))
  with check (my_role() in ('admin','collaborateur'));
-- (aff_del reste : admin uniquement — inchangé)

-- PLANNING : création + modification par admin & collaborateur ; suppression = admin
drop policy if exists pl_ins on public.planning;
drop policy if exists pl_upd on public.planning;
create policy pl_ins on public.planning for insert to authenticated
  with check (my_role() in ('admin','collaborateur'));
create policy pl_upd on public.planning for update to authenticated
  using (my_role() in ('admin','collaborateur'))
  with check (my_role() in ('admin','collaborateur'));
-- (pl_del reste : admin uniquement — inchangé)
