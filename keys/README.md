# Clés et points d'accès matOS

Rien de secret n'est versionné ici, à part ce README.

## Clé du dépôt APT matOS

Déposez ici la clé **publique** du dépôt sous le nom
`matos-archive-keyring.gpg` (format binaire). Si elle est présente, le
build ajoute le paquet `matos-archive-keyring` à l'image et le système
installé reçoit les mises à jour des paquets `matos-*`.

Créer la clé (une seule fois, à garder hors du dépôt Git) :

```bash
gpg --quick-generate-key "matOS archive <raantss@gmail.com>" rsa4096 sign never
gpg --export "matOS archive" > keys/matos-archive-keyring.gpg
```

Ne jamais committer la clé privée.

## Statistiques anonymes : `stats.env`

Fichier `keys/stats.env` (ignoré par Git), lu au build par `scripts/build-debs.sh` :

```bash
MATOS_STATS_URL=https://<projet>.supabase.co
MATOS_STATS_ANON_KEY=<clé anon du projet Supabase>
```

Pour reprendre ceux de Tontolo :

```bash
{ echo "MATOS_STATS_URL=$(gh variable get STATS_URL -R raantss18/TONTOLO)"
  echo "MATOS_STATS_ANON_KEY=$(gh variable get STATS_ANON_KEY -R raantss18/TONTOLO)"; } > keys/stats.env
```

La clé `anon` est une clé publique d'insertion (voir `docs/stats/supabase-matos.sql`).
Sans ce fichier, l'image est construite sans envoi de statistiques.
