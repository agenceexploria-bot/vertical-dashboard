# Vertical – Dashboard

Dashboard opérationnel interne pour le suivi des affaires, de l'OTIFIQ et du planning de production/installation des monte-charges **Vertical** (Actiwork) — ticket **MB03**.

## Architecture

L'application tient dans un fichier HTML unique (`index_12.html`) : React, Chart.js et PapaParse sont chargés via CDN, et le JSX est transpilé dans le navigateur par Babel — aucune étape de build n'est nécessaire.

Le backend est **Supabase** :
- **Auth** pour l'authentification par email/mot de passe ;
- **Postgres** avec trois tables de données (`affaires`, `otifiq`, `planning`), chacune au format `id` (texte) + `data` (`jsonb`) — une ligne = un enregistrement, ce qui corrige le bug d'écrasement multi-utilisateur qu'entraînait un stockage en un seul bloc JSON ;
- **RLS (Row Level Security)** pour appliquer les droits par rôle directement en base ;
- **Realtime** pour synchroniser les modifications entre utilisateurs connectés ;
- une **Edge Function** (`delete-user`) pour la suppression définitive d'un compte.

L'ensemble est hébergé sur **Netlify**.

## Structure du dépôt

```
.
├── index_12.html   # Application complète (React + Chart.js + PapaParse, via CDN)
├── setup.sql       # Script SQL de configuration Supabase (tables, rôles, RLS, Realtime)
└── index.ts        # Edge Function Supabase "delete-user"
```

## Rôles et droits

| Rôle | Droits |
|---|---|
| `admin` | Accès complet : consultation, saisie/édition, suppression, gestion des comptes (rôles) |
| `collaborateur` | Consultation + saisie/édition, sans suppression ni gestion des comptes |
| `collaborateur2` | Lecture seule — rôle attribué par défaut à l'inscription |
| `desactive` | Aucun accès |

## Déploiement sur un projet Supabase neuf

1. Créer un nouveau projet sur [Supabase](https://supabase.com).
2. Ouvrir **SQL Editor** et exécuter l'intégralité de `setup.sql`.
3. Déployer l'Edge Function sous le nom exact `delete-user` en y collant le contenu de `index.ts` (Supabase → **Edge Functions** → *Deploy a new function*).
4. Désactiver la confirmation d'email : **Authentication** → **Sign In / Providers** → **Email** → décocher *Confirm email*.
5. Renseigner les constantes `SUPA_URL` et `SUPA_ANON` en tête de `index_12.html` avec l'URL du projet et la clé publique *anon* (Supabase → **Project Settings** → **API**).
6. Créer le premier compte via l'écran d'inscription, puis le passer administrateur en SQL :
   ```sql
   update public.profiles set role = 'admin' where email = '...';
   ```
7. Déposer `index_12.html` sur l'hébergeur (Netlify).

## Notes de sécurité

- La clé `SUPA_ANON` présente dans `index_12.html` est publique par conception : la sécurité de l'application repose sur les **policies RLS** définies dans `setup.sql`, pas sur la confidentialité de cette clé.
- La clé `service_role` ne doit **jamais** être commitée dans ce dépôt : elle n'est utilisée que côté serveur, dans l'Edge Function `delete-user`, où elle est fournie automatiquement par l'environnement Supabase.
