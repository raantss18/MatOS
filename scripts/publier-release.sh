#!/bin/bash
# Publie l'ISO matOS dans une release GitHub.
#
# GitHub limite chaque fichier d'une release à 2 Gio ; l'ISO est donc découpée en parts de
# 1900 Mio, avec un fichier SHA256SUMS. Les utilisateurs la récupèrent avec
# scripts/telecharger-matos.sh, qui vérifie chaque part et recompose l'ISO. Les modules hors
# ligne (out/modules/*.matmod) sont joints tels quels, ou découpés de la même façon s'ils
# dépassent 2 Gio (Lean + Mathlib).
#
# Usage : scripts/publier-release.sh [--a-blanc | --publier]
#   (sans option)  crée la release en BROUILLON (invisible du public) et envoie les fichiers
#   --publier      la rend publique et « dernière version »
#   --a-blanc      prépare out/release/ et les notes, sans rien envoyer à GitHub
#
# Prérequis : l'ISO de la version dans out/ (./build.sh), la version fusionnée dans main,
# gh (GitHub CLI) authentifié. L'ISO se construit en local (elle exige ~80 Go de disque
# et des heures : trop pour les exécuteurs gratuits de GitHub Actions).

. "$(dirname "$0")/lib.sh"

mode=${1:-brouillon}
case "$mode" in brouillon|--publier|--a-blanc) ;; *) die "option inconnue : $mode" ;; esac

tag="v$MATOS_VERSION"
iso_nom="matos-$MATOS_VERSION-$MATOS_CODENAME-amd64.hybrid.iso"
iso="$MATOS_ROOT/out/$iso_nom"
sortie="$MATOS_ROOT/out/release"
taille_part=${MATOS_PART_SIZE:-1900M}
# Modules de plus de 2 Gio : parts plus petites, qu'une connexion lente envoie sans coupure (HTTP 408)
taille_part_module=${MATOS_PART_SIZE_MODULES:-400M}

[ -f "$iso" ] || die "ISO absente : $iso (lancer ./build.sh)"
if [ -f "$iso.sha256" ]; then
    (cd "$(dirname "$iso")" && sha256sum -c --status "$iso_nom.sha256") \
        || die "l'ISO ne correspond plus à son fichier .sha256 : reconstruire"
fi

rm -rf "$sortie"; mkdir -p "$sortie"
log "Découpage en parts de $taille_part"
split -b "$taille_part" -d -a 2 "$iso" "$sortie/$iso_nom.part-"
(cd "$sortie" && sha256sum "$iso_nom.part-"* > SHA256SUMS)
(cd "$(dirname "$iso")" && sha256sum "$iso_nom") >> "$sortie/SHA256SUMS"
[ -f "$MATOS_ROOT/out/matos-$MATOS_VERSION-$MATOS_CODENAME-amd64.paquets.txt" ] \
    && cp "$MATOS_ROOT/out/matos-$MATOS_VERSION-$MATOS_CODENAME-amd64.paquets.txt" "$sortie/paquets.txt"

limite=$((2 * 1024 * 1024 * 1024 - 1))   # taille maximale d'un fichier de release GitHub
# Modules hors ligne : seulement ceux que le catalogue de cette ISO reconnaît (même build)
catalogue="$MATOS_ROOT/out/modules/catalogue"
nb_modules=0; liste_modules=""
if [ -f "$catalogue" ]; then
    while IFS='|' read -r m_sha m_nom m_version m_taille m_desc; do
        case "$m_sha" in ''|'#'*) continue ;; esac
        m="$MATOS_ROOT/out/modules/matos-$m_nom-$m_version.matmod"
        [ -f "$m" ] || die "module du catalogue absent : $m"
        [ "$(sha256sum "$m" | cut -d' ' -f1)" = "$m_sha" ] \
            || die "$(basename "$m") ne correspond pas au catalogue de l'ISO : reconstruire (./build.sh)"
        if [ "$m_taille" -gt "$limite" ]; then
            split -b "$taille_part_module" -d -a 2 "$m" "$sortie/$(basename "$m").part-"
            (cd "$sortie" && sha256sum "$(basename "$m").part-"* >> SHA256SUMS)
        else
            ln "$m" "$sortie/" 2>/dev/null || cp "$m" "$sortie/"
        fi
        echo "$m_sha  $(basename "$m")" >> "$sortie/SHA256SUMS"
        nb_modules=$((nb_modules + 1))
        liste_modules="$liste_modules| \`$m_nom\` | $((m_taille / 1048576)) Mio | $m_desc |"$'\n'
    done < "$catalogue"
fi
log "Modules joints : $nb_modules"

# Chaque part doit tenir sous la limite de GitHub (2 Gio)
for f in "$sortie"/*; do
    [ "$(stat -c %s "$f")" -le "$limite" ] || die "$(basename "$f") dépasse 2 Gio"
done

nb=$(ls "$sortie/$iso_nom".part-* | wc -l)
taille=$(du -h "$iso" | cut -f1)
iso_sha=$(cut -d' ' -f1 < <(grep " $iso_nom\$" "$sortie/SHA256SUMS"))
cat > "$sortie/NOTES.md" <<EOF
# $MATOS_NAME $MATOS_VERSION

Distribution Linux pour les étudiants et enseignants en mathématiques, basée sur Debian 13 « Trixie »,
utilisable hors ligne. Voir le [CHANGELOG](https://github.com/raantss18/MatOS/blob/main/CHANGELOG.md).

## Télécharger

L'ISO ($taille) dépasse la limite de 2 Go par fichier de GitHub : elle est fournie en **$nb parts**.
Le script recompose l'ISO et **vérifie chaque part** ; il reprend là où il s'est arrêté après une coupure.

\`\`\`bash
curl -fLO https://raw.githubusercontent.com/raantss18/MatOS/main/scripts/telecharger-matos.sh
bash telecharger-matos.sh $tag
\`\`\`

Sans le script : télécharger toutes les parts \`$iso_nom.part-NN\` et \`SHA256SUMS\`, puis
\`cat $iso_nom.part-* > $iso_nom\` (Linux, macOS) ou \`copy /b part-00+part-01+… $iso_nom\` (Windows),
et vérifier avec \`sha256sum -c SHA256SUMS\`.

SHA256 de l'ISO : \`$iso_sha\`

## Installer

Copier l'ISO sur une clé USB de **8 Go ou plus** (Ventoy, balenaEtcher, GNOME Disques ou \`dd\`). Elle
démarre en BIOS et en UEFI. Machines modestes : 64 bits uniquement, 4 Go de RAM suffisent pour le
bureau et la plupart des logiciels ; SageMath, Lean + Mathlib et GeoGebra sont gourmands.
EOF
if [ "$nb_modules" -gt 0 ]; then
    cat >> "$sortie/NOTES.md" <<EOF

## Modules hors ligne

Compléments facultatifs, à télécharger une fois puis à passer de main en main sur une clé USB.
Dans matOS : menu **Modules matOS**, ou \`sudo matos-modules installer FICHIER.matmod\`. Chaque fichier
est vérifié (SHA256) par matOS avant l'installation.

| Module | Taille | Contenu |
|---|---|---|
$liste_modules
Avec le script : \`bash telecharger-matos.sh $tag --modules\` (ou \`--module=lean\`). Un module de plus
de 2 Go est fourni en parts \`.matmod.part-NN\`, que le script recompose (ou \`cat\`, \`copy /b\`).
EOF
fi

log "Fichiers prêts dans $sortie :"; ls -lh "$sortie" | sed 's/^/    /'
[ "$mode" = --a-blanc ] && { log "À blanc : rien n'a été envoyé."; exit 0; }

command -v gh >/dev/null || die "gh (GitHub CLI) est requis"
git -C "$MATOS_ROOT" fetch -q origin main
if ! git -C "$MATOS_ROOT" merge-base --is-ancestor HEAD origin/main; then
    die "la version courante n'est pas dans main : fusionner d'abord (la release est étiquetée sur main)"
fi

if gh release view "$tag" >/dev/null 2>&1; then
    log "La release $tag existe : les fichiers sont remplacés"
else
    gh release create "$tag" --draft --target main --title "$MATOS_NAME $MATOS_VERSION" \
        --notes-file "$sortie/NOTES.md"
fi
log "Envoi des fichiers (plusieurs Go, reprendre en relançant le script si besoin)"
gh release upload "$tag" "$sortie"/* --clobber

if [ "$mode" = --publier ]; then
    gh release edit "$tag" --draft=false --latest
    log "Release publique : $(gh release view "$tag" --json url --jq .url)"
else
    log "Brouillon créé : relancer avec --publier pour la rendre publique"
fi
