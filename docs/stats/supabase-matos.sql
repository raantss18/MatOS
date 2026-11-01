-- Statistiques anonymes de matOS : à exécuter une fois dans Supabase › SQL Editor
-- (projet partagé avec Tontolo ; migration additive, aucune table de Tontolo n'est touchée).
--
-- Les systèmes matOS peuvent seulement AJOUTER des lignes avec la clé « anon », et
-- uniquement ces quatre colonnes. Personne d'autre que le propriétaire (tableau de bord
-- ou clé service) ne peut lire, modifier ou supprimer les données.
-- Aucun identifiant n'est transmis : on compte des envois, pas des utilisateurs uniques.
begin;

create table if not exists public.matos_pings (
  id            bigint generated always as identity primary key,
  received_at   timestamptz not null default now(),
  matos_version text not null check (matos_version ~ '^[0-9A-Za-z.+~-]{0,20}$'),
  mode          text not null check (mode in ('live', 'installe')),
  langue        text not null check (langue ~ '^([a-z]{2,3})?$'),
  pays          text not null check (pays ~ '^([A-Z]{2})?$')
);

alter table public.matos_pings enable row level security;
revoke all on public.matos_pings from anon, authenticated;
grant insert (matos_version, mode, langue, pays) on public.matos_pings to anon;

drop policy if exists "matos insert pings" on public.matos_pings;
create policy "matos insert pings" on public.matos_pings
  for insert to anon with check (true);

create index if not exists matos_pings_received_at on public.matos_pings (received_at);

-- Vues de synthèse (tableau de bord uniquement).
create or replace view public.matos_stats_jour as
  select date_trunc('day', received_at)::date as jour,
         count(*) filter (where mode = 'installe') as envois_installes,
         count(*) filter (where mode = 'live')     as envois_live
  from public.matos_pings group by 1 order by 1 desc;

create or replace view public.matos_stats_repartition as
  select matos_version, mode, nullif(langue, '') as langue, nullif(pays, '') as pays,
         count(*) as envois
  from public.matos_pings where received_at > now() - interval '30 days'
  group by 1, 2, 3, 4 order by 5 desc;

revoke all on public.matos_stats_jour, public.matos_stats_repartition from anon, authenticated;

commit;
