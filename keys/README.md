# Clé du dépôt APT matOS

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
