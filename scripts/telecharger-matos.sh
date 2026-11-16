#!/bin/bash
# Télécharge matOS depuis les releases GitHub : récupère les parts de l'ISO, vérifie chacune
# (SHA256), recompose l'ISO et vérifie le résultat. Reprend après une coupure de connexion.
#
# Usage : bash telecharger-matos.sh [VERSION] [--modules | --module=NOM ...] [--sans-iso]
#   VERSION        ex. v0.7 (défaut : la dernière version)
#   --modules      télécharge aussi tous les modules hors ligne (fichiers .matmod)
#   --module=NOM   télécharge aussi ce module (lean, preuve-calcul, bibliotheque, encyclopedie)
#   --sans-iso     seulement les modules demandés
#   MATOS_DEST=dossier   où écrire les fichiers (défaut : dossier courant)
# Prérequis : bash, curl, sha256sum (ou shasum sous macOS).
# Espace disque : taille du fichier + 2 Go (chaque part est supprimée dès qu'elle est ajoutée).
set -euo pipefail

REPO=${MATOS_REPO:-raantss18/MatOS}
VERSION=latest; tous_modules=0; modules=""; avec_iso=1
for a in "$@"; do
    case "$a" in
        --modules)    tous_modules=1 ;;
        --module=*)   modules="$modules ${a#--module=}" ;;
        --sans-iso)   avec_iso=0 ;;
        -h|--help)    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*)           builtin echo "Option inconnue : $a" >&2; exit 2 ;;
        *)            VERSION=$a ;;
    esac
done
if [ -n "${MATOS_API:-}" ]; then api=$MATOS_API
elif [ "$VERSION" = latest ]; then api="https://api.github.com/repos/$REPO/releases/latest"
else api="https://api.github.com/repos/$REPO/releases/tags/$VERSION"; fi
DEST=${MATOS_DEST:-.}

sha() { if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
echo() { builtin echo "[matOS] $*"; }
erreur() { builtin echo "[matOS] ERREUR : $*" >&2; exit 1; }
command -v curl >/dev/null || erreur "curl est requis"

mkdir -p "$DEST"; cd "$DEST"
echo "Recherche de la version « $VERSION » sur GitHub…"
json=$(curl -fsSL "$api") || erreur "version introuvable ($api). Vérifier le nom, ex. v0.7, ou la connexion."
urls=$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4)
[ -n "$urls" ] || erreur "aucun fichier dans cette release"
url_de() { printf '%s\n' "$urls" | grep "/$1\$" | head -1; }

curl -fsSL -o SHA256SUMS "$(url_de SHA256SUMS)" || erreur "SHA256SUMS absent de la release"
attendu_de() { awk -v f="$1" '$2 == f {print $1}' SHA256SUMS; }
iso=$(awk '$2 ~ /\.iso$/ {print $2}' SHA256SUMS | head -1)
[ -n "$iso" ] || erreur "SHA256SUMS illisible"

# telecharger_verifie FICHIER : téléchargement avec reprise, 3 essais, empreinte de SHA256SUMS
telecharger_verifie() {
    local f="$1" attendu essai
    attendu=$(attendu_de "$f")
    [ -n "$attendu" ] || erreur "$f n'est pas dans SHA256SUMS"
    for essai in 1 2 3; do
        if curl -fL -C - --retry 5 --retry-delay 5 --connect-timeout 30 -o "$f" "$(url_de "$f")"; then
            [ "$(sha "$f")" = "$attendu" ] && return 0
            echo "Empreinte incorrecte, nouveau téléchargement"; rm -f "$f"
        fi
    done
    erreur "$f : téléchargement impossible ou incorrect après 3 essais"
}

# obtenir FICHIER : le télécharge entier, ou part par part s'il est découpé dans la release
# (GitHub limite chaque fichier à 2 Go), puis vérifie l'empreinte du fichier complet.
obtenir() {
    local f="$1" parts total n=0 fait=0 part etat=".$1.etat" tmp="$1.en-cours"
    if [ -f "$f" ] && [ "$(sha "$f")" = "$(attendu_de "$f")" ]; then
        echo "$f est déjà là et correct."; return 0
    fi
    parts=$(awk -v p="$f.part-" 'index($2, p) == 1 {print $2}' SHA256SUMS | sort)
    if [ -z "$parts" ]; then
        echo "Téléchargement : $f"
        telecharger_verifie "$f"; return 0
    fi
    [ -f "$etat" ] && fait=$(cat "$etat")
    [ -f "$tmp" ] || fait=0
    if [ "$fait" -eq 0 ]; then : > "$tmp"; fi
    total=$(printf '%s\n' "$parts" | wc -l | tr -d ' ')
    for part in $parts; do
        n=$((n + 1))
        [ "$n" -le "$fait" ] && continue
        echo "Part $n/$total : $part"
        telecharger_verifie "$part"
        cat "$part" >> "$tmp"; rm -f "$part"; builtin echo "$n" > "$etat"
    done
    echo "Vérification de $f…"
    [ "$(sha "$tmp")" = "$(attendu_de "$f")" ] || erreur "$f recomposé est incorrect (supprimer $tmp et recommencer)"
    mv "$tmp" "$f"; rm -f "$etat"
}

if [ "$avec_iso" = 1 ]; then
    obtenir "$iso"
    echo "ISO prête : $(pwd)/$iso"
    echo "Copier sur une clé USB de 8 Go ou plus (Ventoy, balenaEtcher, GNOME Disques ou dd)."
fi

# Modules hors ligne : un fichier .matmod par module, à installer avec « Modules matOS »
dispo=$(awk '$2 ~ /\.matmod$/ {print $2}' SHA256SUMS)
choisis=""
if [ "$tous_modules" = 1 ]; then
    choisis=$dispo
    [ -n "$choisis" ] || echo "Cette version n'a pas de module."
else
    for m in $modules; do
        f=$(printf '%s\n' "$dispo" | grep "^matos-$m-[^-]*\.matmod\$" | head -1) || true
        [ -n "$f" ] || erreur "module inconnu : $m (disponibles : $(printf '%s ' $dispo))"
        choisis="$choisis $f"
    done
fi
for f in $choisis; do obtenir "$f"; done
[ -z "$choisis" ] || echo "Modules prêts. Dans matOS : menu « Modules matOS », ou sudo matos-modules installer FICHIER"
rm -f SHA256SUMS
