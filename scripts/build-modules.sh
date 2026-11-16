#!/bin/bash
# Construit les modules hors ligne de matOS (fichiers .matmod) dans out/modules/.
# Exécuté en root dans le conteneur Debian de build, après « lb chroot » : les modules
# qui embarquent des paquets Debian calculent ce qui manque à l'image de base à partir
# de la liste des paquets du chroot.
#
# Usage : build-modules.sh [MODULE...]   (par défaut : tous)
# Format d'un module : voir packages/matos-modules/usr/bin/matos-modules.
# Sortie : out/modules/matos-NOM-VERSION.matmod et build/catalogue (une ligne par module).

. "$(dirname "$0")/lib.sh"

[ "$(id -u)" = 0 ] || die "à exécuter en root (dans le conteneur de build)"

SORTIE="$MATOS_ROOT/out/modules"
CATALOGUE_BUILD="$BUILD_DIR/catalogue"
CHROOT_STATUS="${CHROOT_STATUS:-$BUILD_DIR/live/chroot/var/lib/dpkg/status}"
MATHLIB_VERSION="${MATHLIB_REV#v}"

# stage_module NOM : copie modules/NOM dans un dossier de travail, remplace les marqueurs
stage_module() {
    local nom="$1" dir="$BUILD_DIR/module/$1" var expr=""
    rm -rf "$dir"; mkdir -p "$dir"
    cp -a "$MATOS_ROOT/modules/$nom/." "$dir/"
    for var in MATOS_VERSION MATHLIB_VERSION ZIM_DATE; do
        expr="$expr;s|@$var@|${!var}|g"
    done
    { grep -rlIZ '@[A-Z_]*@' "$dir" || [ $? -eq 1 ]; } | xargs -0 -r sed -i "${expr#;}"
    echo "$dir"
}

# depot_module DOSSIER "PAQUETS" [DEB_LOCAL...] : dépôt APT des paquets absents de la base
# (avec toutes leurs dépendances, sans les paquets seulement recommandés).
depot_module() {
    local dir="$1" paquets="$2"; shift 2
    [ -f "$CHROOT_STATUS" ] || die "liste des paquets de la base absente ($CHROOT_STATUS) : lancer d'abord lb chroot"
    local depot="$dir/depot" deb
    mkdir -p "$depot/partial"
    for deb in "$@"; do cp "$deb" "$depot/"; done
    # shellcheck disable=SC2086
    apt-get -y --no-install-recommends --download-only \
        -o Dir::State::status="$CHROOT_STATUS" \
        -o Dir::Cache::archives="$depot" \
        -o Debug::NoLocking=true \
        install $(for deb in "$@"; do echo "$depot/$(basename "$deb")"; done) \
                $(for p in $paquets; do compgen -G "$depot/${p}_*.deb" >/dev/null || echo "$p"; done) >&2
    rmdir "$depot/partial"; rm -f "$depot/lock"
    (cd "$depot" && dpkg-scanpackages -m . > Packages 2>/dev/null && gzip -9 -k Packages)
    # place nécessaire sur le disque une fois les paquets installés (vérifiée par matos-modules)
    echo "INSTALLE_MIO=$(awk '/^Installed-Size:/{s+=$2} END{print int(s/1024)+1}' "$depot/Packages")" >> "$dir/module.conf"
    log "Dépôt du module : $(find "$depot" -name '*.deb' | wc -l) paquets, $(du -sm "$depot" | cut -f1) Mo"
}

# pack_module DOSSIER : image squashfs + ligne de catalogue
pack_module() {
    local dir="$1" nom version desc out sha taille
    nom=$(sed -n 's/^NOM=//p' "$dir/module.conf")
    version=$(sed -n 's/^VERSION=//p' "$dir/module.conf")
    desc=$(sed -n 's/^DESCRIPTION=//p' "$dir/module.conf")
    [ -n "$nom" ] && [ -n "$version" ] || die "module.conf incomplet dans $dir"
    ! grep -q '@[A-Z_]*@' "$dir/module.conf" || die "marqueur non remplacé dans $dir/module.conf"
    mkdir -p "$SORTIE"
    out="$SORTIE/matos-$nom-$version.matmod"
    rm -f "$out"
    # Blocs de 1 Mio par défaut : PDF, archives et paquets sont lus en grands morceaux.
    # BLOC= dans module.conf le réduit pour un arbre fait de milliers de petits fichiers lus
    # dans le désordre : chaque lecture décompresse un bloc entier. Mesuré pour Lean + Mathlib
    # (4 Go de RAM) : première compilation d'un projet en 45 s avec 128 Kio, 250 s avec 1 Mio.
    local bloc; bloc=$(sed -n 's/^BLOC=//p' "$dir/module.conf"); bloc=${bloc:-1M}
    [[ "$bloc" =~ ^[0-9]+[KM]$ ]] || die "BLOC invalide dans $dir/module.conf : $bloc"
    mksquashfs "$dir" "$out" -comp zstd -Xcompression-level 22 -b "$bloc" -all-root -noappend -quiet >&2
    sha=$(sha256sum "$out" | cut -d' ' -f1); taille=$(stat -c %s "$out")
    touch "$CATALOGUE_BUILD"
    sed -i "/|$nom|/d" "$CATALOGUE_BUILD"
    echo "$sha|$nom|$version|$taille|$desc" >> "$CATALOGUE_BUILD"
    log "Module prêt : $(basename "$out") ($((taille / 1048576)) Mio)"
}

run_as_nobody() {
    local home; home=$(mktemp -d)
    chown nobody:nogroup "$home"
    (cd "$home" && runuser -u nobody -- env -i HOME="$home" PATH=/usr/bin:/bin LANG=C.UTF-8 "$@")
    rm -rf "$home"
}

# ── lean : Lean 4 + Mathlib précompilée ─────────────────────────────────
module_lean() {
    local dir; dir=$(stage_module lean)
    local prefix=/opt/matos/lean
    local tarball; tarball=$(fetch "$ELAN_URL" "$ELAN_SHA256" "elan-$ELAN_VERSION.tar.gz")
    rm -rf "$prefix" "$BUILD_DIR/elan"; mkdir -p "$prefix" "$BUILD_DIR/elan"
    tar -xzf "$tarball" -C "$BUILD_DIR/elan"

    export ELAN_HOME="$prefix/elan"
    "$BUILD_DIR/elan/elan-init" -y --no-modify-path --default-toolchain "$LEAN_TOOLCHAIN"
    local path_save="$PATH"
    export PATH="$ELAN_HOME/bin:$PATH"

    local modele="$prefix/modele"
    mkdir -p "$modele/Projet"
    echo "$LEAN_TOOLCHAIN" > "$modele/lean-toolchain"
    cat > "$modele/lakefile.toml" <<EOF
name = "projet"
defaultTargets = ["Projet"]

[[require]]
name = "mathlib"
git = "$MATHLIB_GIT"
rev = "$MATHLIB_REV"

[[lean_lib]]
name = "Projet"
EOF
    echo 'import Projet.Basic' > "$modele/Projet.lean"
    # Imports ciblés : « import Mathlib » charge toute la bibliothèque (plusieurs Go lus sur
    # le disque, très lent avec 4 Go de RAM et un disque dur).
    cat > "$modele/Projet/Basic.lean" <<'EOF'
import Mathlib.Tactic
import Mathlib.Basic.Real.Basic

/-!
Premier fichier de votre projet Lean 4 (Mathlib est disponible hors ligne).

Ces deux imports suffisent pour commencer et s'ouvrent vite. Ajoutez ceux dont vous avez
besoin (par exemple `import Mathlib.Analysis.SpecialFunctions.Pow.Real`). `import Mathlib`
donne toute la bibliothèque, mais demande beaucoup de mémoire et de temps sur une machine
modeste.
-/

example (a b : ℝ) : (a + b) ^ 2 = a ^ 2 + 2 * a * b + b ^ 2 := by ring

example (n : ℕ) (h : 3 ≤ n) : 2 * n + 1 ≥ 7 := by omega

theorem somme_carres_positive (x y : ℝ) : 0 ≤ x ^ 2 + y ^ 2 := by positivity
EOF
    # cache des oleans Mathlib conservé entre deux builds (plusieurs Go)
    export MATHLIB_CACHE_DIR="$BUILD_DIR/mathlib-cache"; mkdir -p "$MATHLIB_CACHE_DIR"
    (cd "$modele" && lake update && lake exe cache get)
    # La toolchain doit être exactement celle de Mathlib, sinon tout serait recompilé
    cmp -s "$modele/lean-toolchain" "$modele/.lake/packages/mathlib/lean-toolchain" \
        || die "LEAN_TOOLCHAIN ($LEAN_TOOLCHAIN) ≠ toolchain de Mathlib $MATHLIB_REV"
    # Premier passage en root avec toute la bibliothèque : Lake y écrit les empreintes (.hash)
    # absentes du cache. Sans elles, un « import Mathlib » échouerait ensuite en lecture seule.
    cp "$modele/Projet/Basic.lean" "$BUILD_DIR/lean-Basic.lean"
    echo 'import Mathlib' > "$modele/Projet/Basic.lean"
    (cd "$modele" && lake build)
    cp "$BUILD_DIR/lean-Basic.lean" "$modele/Projet/Basic.lean"
    local sortie; sortie=$(cd "$modele" && lake build 2>&1) || { echo "$sortie" >&2; die "le projet modèle Lean ne compile pas"; }
    echo "$sortie" >&2
    ! echo "$sortie" | grep -q 'deprecated' || die "le projet modèle Lean utilise un import obsolète"
    rm -rf "$modele/.lake/build"
    chmod -R a+rX "$prefix"

    log "Test Lean + Mathlib (utilisateur sans droits, /opt en lecture seule, commandes du module)"
    cp -a "$dir/bin" "$BUILD_DIR/lean-bin"; chmod -R a+rX "$BUILD_DIR/lean-bin"
    run_as_nobody env PATH="$BUILD_DIR/lean-bin:/usr/bin:/bin" sh -c '
        matos-lean-projet essai && cd essai && lake build && echo "lean OK"'
    # toute la bibliothèque doit aussi être utilisable telle quelle, sans recompilation
    run_as_nobody env PATH="$BUILD_DIR/lean-bin:/usr/bin:/bin" sh -c '
        matos-lean-projet complet && cd complet &&
        printf "import Mathlib\nopen Real\nexample : Irrational (√2) := irrational_sqrt_two\n" > Projet/Basic.lean &&
        lake build && echo "mathlib complète OK"'

    export PATH="$path_save"; unset ELAN_HOME
    mv "$prefix" "$dir/arbre"
    # VSCodium et ses extensions (Lean 4, LaTeX, Python, Jupyter) : l'éditeur de Lean
    "$MATOS_ROOT/scripts/build-debs.sh" codium matos-vscodium-config
    depot_module "$dir" "$(sed -n 's/^PAQUETS=//p' "$dir/module.conf")" \
        "$DEBS_DIR"/codium_*.deb "$DEBS_DIR"/matos-vscodium-config_*.deb
    pack_module "$dir"
}

# ── preuve-calcul : Coq, Scilab, RStudio (paquets Debian + RStudio figé) ─
module_preuve_calcul() {
    local dir; dir=$(stage_module preuve-calcul)
    compgen -G "$DEBS_DIR/rstudio_*.deb" >/dev/null || "$MATOS_ROOT/scripts/build-debs.sh" rstudio
    depot_module "$dir" "$(sed -n 's/^PAQUETS=//p' "$dir/module.conf")" "$DEBS_DIR"/rstudio_*.deb
    pack_module "$dir"
}

# ── bibliotheque : livres L3 à M2 + documentation complète ──────────────
module_bibliotheque() {
    local dir; dir=$(stage_module bibliotheque)
    local lib="$dir/arbre" rel url sha licence file
    mkdir -p "$lib"
    {
        printf '# Bibliothèque matOS, niveaux L3 à M2\n\n'
        printf 'Livres libres téléchargés à la construction (version et SHA256 figés).\n\n'
        printf '| Fichier | Licence |\n|---|---|\n'
        while IFS='|' read -r rel url sha licence; do
            [ -n "$rel" ] || continue
            file=$(fetch "$url" "$sha" "livre-$(basename "$rel")")
            install -D -m 0644 "$file" "$lib/$rel"
            printf '| `%s` | %s |\n' "$rel" "$licence"
        done <<< "$MATOS_BOOKS_PLUS"
    } > "$lib/LISEZMOI.md"
    # Documentation PDF des extensions LaTeX : absente de l'image (dpkg.cfg.d/90-matos-allegement),
    # reprise ici des mêmes paquets Debian. Les paquets texlive-*-doc, non installés dans
    # l'image, ajouteraient 1,4 Go : ils restent hors du module.
    local tl="$BUILD_DIR/texlive-doc" deb
    rm -rf "$tl"; mkdir -p "$tl/debs" "$lib/Documentation LaTeX"
    (cd "$tl/debs" && apt-get download -q texlive-base texlive-latex-base texlive-latex-recommended \
        texlive-latex-extra texlive-pictures texlive-science texlive-lang-french texlive-bibtex-extra \
        texlive-luatex texlive-xetex texlive-plain-generic texlive-fonts-recommended >&2)
    for deb in "$tl"/debs/*.deb; do
        dpkg-deb --fsys-tarfile "$deb" | tar -x -C "$tl" --wildcards './usr/share/doc/texlive-doc/*' 2>/dev/null || true
    done
    [ -d "$tl/usr/share/doc/texlive-doc/latex" ] || die "documentation LaTeX introuvable dans les paquets texlive"
    cp -a "$tl/usr/share/doc/texlive-doc/." "$lib/Documentation LaTeX/"
    rm -rf "$tl"
    depot_module "$dir" "$(sed -n 's/^PAQUETS=//p' "$dir/module.conf")"
    pack_module "$dir"
}

# ── encyclopedie : Wikipédia hors ligne (fichiers ZIM de Kiwix) ─────────
module_encyclopedie() {
    local dir; dir=$(stage_module encyclopedie)
    local nom url sha file
    mkdir -p "$dir/arbre"
    while IFS='|' read -r nom url sha; do
        [ -n "$nom" ] || continue
        file=$(fetch "$url" "$sha" "$nom")
        # les ZIM sont déjà compressés : lien physique, mksquashfs les stocke tels quels
        ln "$file" "$dir/arbre/$nom" 2>/dev/null || cp "$file" "$dir/arbre/$nom"
    done <<< "$MATOS_ZIMS"
    depot_module "$dir" "$(sed -n 's/^PAQUETS=//p' "$dir/module.conf")"
    pack_module "$dir"
}

TOUS="preuve-calcul bibliotheque encyclopedie lean"
for m in ${@:-$TOUS}; do
    fn="module_${m//-/_}"
    declare -F "$fn" >/dev/null || die "module inconnu : $m"
    log "Module $m"
    "$fn"
done
log "Modules prêts dans $SORTIE"
