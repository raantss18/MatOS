#!/bin/bash
# Vérifie un livre candidat pour la bibliothèque matOS et imprime la ligne
# à ajouter à MATOS_BOOKS dans versions.env.
#
# Usage : scripts/livre-verifier.sh DOSSIER/fichier.pdf URL
#         scripts/livre-verifier.sh --fichier DOSSIER/fichier.pdf CHEMIN_LOCAL
#
# Contrôles : c'est un vrai PDF, taille raisonnable, SHA256, et mention d'une
# licence libre dans le texte (16 premières et 5 dernières pages). Sans licence libre
# trouvée, le livre est refusé : la décision finale reste humaine, mais un
# livre sans mention de licence n'entre jamais dans l'image.
# Hôte : nécessite curl et pdftotext (paquet poppler-utils).

set -euo pipefail

if [ "${1:-}" = --fichier ]; then
    rel=$2 src=$3 url=
else
    rel=${1:?usage}; url=${2:?usage}
fi
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
pdf="$work/livre.pdf"

if [ -n "$url" ]; then
    curl -fsSL --retry 3 --max-time 300 -o "$pdf" "$url" || { echo "REFUSÉ  $rel : téléchargement impossible ($url)"; exit 1; }
else
    cp "$src" "$pdf"
fi

[ "$(head -c4 "$pdf")" = "%PDF" ] || { echo "REFUSÉ  $rel : ce n'est pas un PDF"; exit 1; }
size=$(stat -c %s "$pdf")
pages=$(pdfinfo "$pdf" 2>/dev/null | awk '/^Pages:/{print $2}')
title=$(pdfinfo "$pdf" 2>/dev/null | sed -n 's/^Title: *//p')
sha=$(sha256sum "$pdf" | cut -d' ' -f1)

{ pdftotext -f 1 -l 16 "$pdf" - 2>/dev/null
  [ "${pages:-0}" -gt 3 ] && pdftotext -f $((pages > 5 ? pages - 4 : 1)) -l "$pages" "$pdf" - 2>/dev/null
  true; } | tr '\n' ' ' | tr -s ' ' > "$work/texte"

licence=""
for motif in 'CC BY-NC-ND[ 0-9.]*' 'CC BY-NC-SA[ 0-9.]*' 'CC BY-SA[ 0-9.]*' 'CC BY-ND[ 0-9.]*' 'CC BY[ 0-9.]*' \
             'Attribution-NonCommercial-ShareAlike' 'Attribution-ShareAlike' 'Attribution-NoDerivatives' \
             'Creative Commons[^.]{0,60}' 'GNU Free Documentation' 'Apache License' 'MIT License' \
             'LaTeX Project Public License' 'GNU General Public License' 'Licence Art Libre' 'Licence Ouverte'; do
    m=$(grep -oiE "$motif" "$work/texte" | head -1 || true)
    [ -n "$m" ] && { licence="$m"; break; }
done

echo "Livre      : $rel"
echo "Titre PDF  : ${title:--}"
echo "Taille     : $((size / 1048576)) Mio, ${pages:-?} pages"
echo "Licence    : ${licence:-AUCUNE MENTION TROUVÉE}"
if [ -z "$licence" ]; then
    echo "REFUSÉ  $rel : pas de licence libre repérée dans le texte"
    exit 2
fi
echo "Ligne MATOS_BOOKS :"
echo "$rel|$url|$sha"
