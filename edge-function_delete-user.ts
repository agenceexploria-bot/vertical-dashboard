// ═══════════════════════════════════════════════════════════════
// Supabase Edge Function : delete-user
// Supprime DÉFINITIVEMENT un compte (auth + profil), réservé aux admins.
//
// Déploiement (sans terminal) :
//   Supabase → menu gauche « Edge Functions » → « Deploy a new function »
//   → nom exact : delete-user
//   → coller TOUT ce fichier → Deploy.
// Les variables SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY
// sont fournies automatiquement, rien à configurer.
// ═══════════════════════════════════════════════════════════════
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const { userId } = await req.json();
    if (!userId) return json({ error: "userId manquant" }, 400);

    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // 1) Identifier l'appelant via son jeton
    const authHeader = req.headers.get("Authorization") ?? "";
    const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await caller.auth.getUser();
    if (!user) return json({ error: "Non authentifié" }, 401);

    // 2) Vérifier qu'il est admin
    const admin = createClient(url, service);
    const { data: prof } = await admin.from("profiles").select("role").eq("id", user.id).single();
    if (!prof || prof.role !== "admin") return json({ error: "Réservé aux administrateurs" }, 403);

    // 3) Ne pas se supprimer soi-même
    if (userId === user.id) return json({ error: "Vous ne pouvez pas supprimer votre propre compte." }, 400);

    // 4) Suppression définitive (le profil part en cascade)
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) return json({ error: error.message }, 500);

    return json({ ok: true });
  } catch (e) {
    return json({ error: String((e as Error)?.message ?? e) }, 500);
  }
});
