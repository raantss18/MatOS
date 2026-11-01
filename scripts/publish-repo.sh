#!/bin/bash
# Prépare le dépôt APT matOS (dépôt « plat » signé) à partir de build/debs,
# puis, avec --envoyer, le publie comme release GitHub « depot ».
#
# Usage : scripts/publish-repo.sh CLE_GPG [--envoyer]
#   CLE_GPG : identifiant de la clé de signature (voir keys/README.md)
#
# Les systèmes matOS lisent ce dépôt via MATOS_APT_URL (versions.env).
# Les releases GitHub limitent chaque fichier à 2 Gio : un paquet plus gros
# doit être hébergé ailleurs (MATOS_APT_URL vers un autre serveur).

. "$(dirname "$0")/lib.sh"

key="${1:-}"
[ -n "$key" ] || die "usage : $0 CLE_GPG [--envoyer]"
send="${2:-}"

repo="$BUILD_DIR/repo"
rm -rf "$repo"; mkdir -p "$repo"
shopt -s nullglob
debs=("$DEBS_DIR"/*.deb)
[ ${#debs[@]} -gt 0 ] || die "aucun paquet dans $DEBS_DIR (lancez ./build.sh --paquets)"

limit=$((2 * 1024 * 1024 * 1024 - 1))
for deb in "${debs[@]}"; do
    size=$(stat -c %s "$deb")
    [ "$size" -le "$limit" ] || die "$(basename "$deb") dépasse 2 Gio : impossible en release GitHub"
    # GitHub renomme les fichiers contenant « + » : on l'évite
    name=$(basename "$deb"); cp "$deb" "$repo/${name//+/-}"
done

cd "$repo"
# Filename sans « ./ » : les URL de release GitHub ne normalisent pas « /./ »
apt-ftparchive packages . | sed 's|^Filename: \./|Filename: |' > Packages
xz -k9 Packages
apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=matOS \
    -o APT::FTPArchive::Release::Label=matOS \
    -o APT::FTPArchive::Release::Suite="$DEBIAN_SUITE" \
    -o APT::FTPArchive::Release::Codename="$MATOS_CODENAME" \
    -o APT::FTPArchive::Release::Description="Paquets matOS $MATOS_VERSION" \
    release . > Release
gpg --batch --yes --local-user "$key" --clearsign -o InRelease Release
gpg --batch --yes --local-user "$key" -abs -o Release.gpg Release
log "Dépôt prêt dans $repo"

if [ "$send" = --envoyer ]; then
    command -v gh >/dev/null || die "gh (GitHub CLI) est requis pour --envoyer"
    gh release view depot >/dev/null 2>&1 \
        || gh release create depot --title "Dépôt APT matOS" \
             --notes "Dépôt APT des paquets matos-* (mis à jour par scripts/publish-repo.sh)."
    gh release upload depot --clobber ./*
    log "Dépôt publié : $MATOS_APT_URL"
fi
