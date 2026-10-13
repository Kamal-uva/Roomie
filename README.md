# Roomie — Apartment HQ

A mobile-friendly shared apartment dashboard for four roommates. Tracks the last trash run, the owner of the washer and dryer, and a rotating vacuum schedule. Built with React, Vite and Supabase.

## Run locally

1. Install Node.js.
2. Run `npm install`.
3. Copy `.env.example` to `.env`, then set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` from Supabase.
4. Run `npm run dev`, then open http://localhost:5173.

## Deploy

Import this GitHub repository into Vercel. Framework: Vite. Build command: `npm run build`. Output directory: `dist`. Add both `VITE_SUPABASE_...` environment variables in Vercel, then deploy. Add the deployed URL to Supabase Authentication → URL Configuration → Site URL and Redirect URLs. Keep localhost for development.

## Supabase

For new databases, run `supabase/schema.sql` in the SQL editor. For an existing Roomie database already set up locally, **do not rerun the schema**. Reuse the same Supabase project, so roommates share their apartment and existing activity.

Use the **public publishable/anon key**, never the service-role/secret key. Keep `.env` out of GitHub. Sign in by email, create an apartment, and share the six-character code privately with the other three roommates.

## Notes

Laundry must be marked free manually when finished. The vacuum turn is rotated by join order. There are no push notifications or timed wash-cycle alerts. All changes are stored in Supabase; users can see updated activity with realtime subscriptions or a page refresh.
