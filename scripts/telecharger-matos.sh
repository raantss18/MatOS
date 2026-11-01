#!/bin/bash
# Télécharge matOS depuis les releases GitHub : récupère les parts de l'ISO, vérifie chacune
# (SHA256), recompose l'ISO et vérifie le résultat. Reprend après une coupure de connexion.
#
# Usage : bash telecharger-matos.sh [VERSION]      ex. v0.6   (défaut : la dernière version)
#   MATOS_DEST=dossier   où écrire l'ISO (défaut : dossier courant)
# Prérequis : bash, curl, sha256sum (ou shasum sous macOS).
# Espace disque : taille de l'ISO + 2 Go (chaque part est supprimée dès qu'elle est ajoutée).
set -euo pipefail

REPO=${MATOS_REPO:-raantss18/MatOS}
VERSION=${1:-latest}
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
json=$(curl -fsSL "$api") || erreur "version introuvable ($api). Vérifier le nom, ex. v0.6, ou la connexion."
urls=$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*"' | cut -d'"' -f4)
[ -n "$urls" ] || erreur "aucun fichier dans cette release"
url_de() { printf '%s\n' "$urls" | grep "/$1\$" | head -1; }

curl -fsSL -o SHA256SUMS "$(url_de SHA256SUMS)" || erreur "SHA256SUMS absent de la release"
iso=$(awk '$2 !~ /\.part-/ {print $2}' SHA256SUMS | head -1)
iso_sha=$(awk -v f="$iso" '$2 == f {print $1}' SHA256SUMS)
[ -n "$iso" ] || erreur "SHA256SUMS illisible"

if [ -f "$iso" ] && [ "$(sha "$iso")" = "$iso_sha" ]; then
    echo "$iso est déjà là et correct."; rm -f SHA256SUMS; exit 0
fi

etat=".$iso.etat"; tmp="$iso.en-cours"
fait=0; [ -f "$etat" ] && fait=$(cat "$etat")
[ -f "$tmp" ] || fait=0
if [ "$fait" -eq 0 ]; then : > "$tmp"; fi
parts=$(awk '$2 ~ /\.part-/ {print $2}' SHA256SUMS | sort)
total=$(printf '%s\n' "$parts" | wc -l)
n=0
for part in $parts; do
    n=$((n + 1))
    [ "$n" -le "$fait" ] && continue
    attendu=$(awk -v f="$part" '$2 == f {print $1}' SHA256SUMS)
    for essai in 1 2 3; do
        echo "Part $n/$total : $part (essai $essai)"
        curl -fL -C - --retry 5 --retry-delay 5 --connect-timeout 30 -o "$part" "$(url_de "$part")" \
            || { [ "$essai" = 3 ] && erreur "téléchargement impossible"; continue; }
        [ "$(sha "$part")" = "$attendu" ] && break
        echo "Empreinte incorrecte, nouveau téléchargement"; rm -f "$part"
        [ "$essai" = 3 ] && erreur "la part $part reste incorrecte après 3 essais"
    done
    cat "$part" >> "$tmp"; rm -f "$part"; builtin echo "$n" > "$etat"
done

echo "Vérification de l'ISO complète…"
[ "$(sha "$tmp")" = "$iso_sha" ] || erreur "l'ISO recomposée est incorrecte (supprimer $tmp et recommencer)"
mv "$tmp" "$iso"; rm -f "$etat" SHA256SUMS
echo "Terminé : $(pwd)/$iso"
echo "Copier sur une clé USB de 16 Go (Ventoy, balenaEtcher, GNOME Disques ou dd)."
