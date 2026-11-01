# shellcheck shell=bash
# Fonctions communes aux scripts de build matOS. À sourcer, pas à exécuter.

set -euo pipefail

MATOS_ROOT="${MATOS_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../versions.env
. "$MATOS_ROOT/versions.env"

BUILD_DIR="${BUILD_DIR:-$MATOS_ROOT/build}"
CACHE_DIR="${CACHE_DIR:-$BUILD_DIR/cache}"
DEBS_DIR="${DEBS_DIR:-$BUILD_DIR/debs}"

log()  { printf '\033[1;34m[matOS]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[matOS] ERREUR :\033[0m %s\n' "$*" >&2; exit 1; }

# fetch URL SHA256 [NOM]
# Télécharge dans le cache (une seule fois), vérifie le SHA256 et affiche
# le chemin du fichier. Essaie d'abord MATOS_MIRROR/NOM s'il est défini.
fetch() {
    local url="$1" sha="$2" name="${3:-$(basename "${1%%\?*}")}"
    local dest="$CACHE_DIR/$name"
    mkdir -p "$CACHE_DIR"
    if [ -f "$dest" ] && echo "$sha  $dest" | sha256sum -c --status; then
        echo "$dest"; return 0
    fi
    rm -f "$dest" "$dest.part"
    local src
    for src in ${MATOS_MIRROR:+"$MATOS_MIRROR/$name"} "$url"; do
        log "Téléchargement $src" >&2
        if curl -fL --retry 5 --retry-delay 5 --connect-timeout 30 -o "$dest.part" "$src" >&2 \
           && echo "$sha  $dest.part" | sha256sum -c --status; then
            mv "$dest.part" "$dest"; echo "$dest"; return 0
        fi
        log "Échec ou SHA256 invalide pour $src" >&2
        rm -f "$dest.part"
    done
    die "impossible d'obtenir $name avec le SHA256 attendu ($sha)"
}

# build_deb DOSSIER_RACINE
# DOSSIER_RACINE contient DEBIAN/control et l'arborescence du paquet.
# Remplace les marqueurs @MATOS_VERSION@, @SAGE_VERSION@... (hors /opt)
# puis ajoute Installed-Size.
build_deb() {
    local root="$1"
    local ctl="$root/DEBIAN/control"
    [ -f "$ctl" ] || die "control manquant dans $root"
    local mathlib_version="${MATHLIB_REV#v}" expr="" var
    for var in MATOS_VERSION MATOS_APT_URL SAGE_VERSION LEAN_TOOLCHAIN GEOGEBRA_VERSION mathlib_version; do
        expr="$expr;s|@$(echo "$var" | tr '[:lower:]' '[:upper:]')@|${!var}|g"
    done
    # grep renvoie 1 quand rien ne correspond : ce n'est pas une erreur
    { grep -rlIZ --exclude-dir=opt '@[A-Z_]*@' "$root" || [ $? -eq 1 ]; } \
        | xargs -0 -r sed -i "${expr#;}"
    local size
    size=$(du -sk --exclude=DEBIAN "$root" | cut -f1)
    sed -i '/^Installed-Size:/d' "$ctl"
    echo "Installed-Size: $size" >> "$ctl"
    find "$root/DEBIAN" -maxdepth 1 -type f \
        \( -name preinst -o -name postinst -o -name prerm -o -name postrm \) \
        -exec chmod 0755 {} +
    mkdir -p "$DEBS_DIR"
    local pkg ver
    pkg=$(sed -n 's/^Package: //p' "$ctl")
    ver=$(sed -n 's/^Version: //p' "$ctl")
    dpkg-deb --root-owner-group -Zzstd -z9 --build "$root" "$DEBS_DIR/${pkg}_${ver}_$(sed -n 's/^Architecture: //p' "$ctl").deb" >&2
    log "Paquet construit : $pkg $ver"
}

# stage NOM : copie packages/NOM vers un dossier de travail propre et l'affiche
stage() {
    local name="$1" dir="$BUILD_DIR/stage/$1"
    rm -rf "$dir"; mkdir -p "$dir"
    cp -a "$MATOS_ROOT/packages/$name/." "$dir/"
    echo "$dir"
}
