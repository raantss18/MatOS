#!/bin/bash
# Construit tous les paquets matOS dans build/debs/.
# Exécuté en root dans le conteneur Debian de build (voir build.sh).
#
# Usage : build-debs.sh [PAQUET...]   (par défaut : tous)
# MATOS_SKIP_HEAVY=1 saute SageMath et Lean (build de test rapide).

. "$(dirname "$0")/lib.sh"

[ "$(id -u)" = 0 ] || die "à exécuter en root (dans le conteneur de build)"

# ── Paquets sans étape de construction particulière ─────────────────────
build_simple() { build_deb "$(stage "$1")"; }

# ── matos-archive-keyring : seulement si la clé publique est fournie ────
build_matos_archive_keyring() {
    local key="$MATOS_ROOT/keys/matos-archive-keyring.gpg"
    if [ ! -f "$key" ]; then
        log "Pas de keys/matos-archive-keyring.gpg : dépôt APT matOS non activé"
        return 0
    fi
    local dir; dir=$(stage matos-archive-keyring)
    install -m 0644 "$key" "$dir/usr/share/keyrings/matos-archive-keyring.gpg"
    build_deb "$dir"
}

# ── matos-stats : point d'accès injecté depuis keys/stats.env (non versionné) ─
build_matos_stats() {
    local dir; dir=$(stage matos-stats)
    local env="$MATOS_ROOT/keys/stats.env"
    if [ -f "$env" ]; then
        # shellcheck source=/dev/null
        . "$env"
    fi
    if [ -n "${MATOS_STATS_URL:-}" ] && [ -n "${MATOS_STATS_ANON_KEY:-}" ]; then
        case "$MATOS_STATS_URL" in https://*) ;; *) die "MATOS_STATS_URL doit commencer par https://" ;; esac
        printf 'STATS_URL=%s\nSTATS_ANON_KEY=%s\n' "$MATOS_STATS_URL" "$MATOS_STATS_ANON_KEY" \
            > "$dir/usr/lib/matos/stats-endpoint"
        log "Statistiques anonymes : envoi vers $MATOS_STATS_URL"
    else
        log "Pas de keys/stats.env : statistiques désactivées dans cette image"
    fi
    build_deb "$dir"
}

# ── matos-desktop : + curseur Bibata ────────────────────────────────────
build_matos_desktop() {
    local dir; dir=$(stage matos-desktop)
    local tarball; tarball=$(fetch "$BIBATA_URL" "$BIBATA_SHA256" "Bibata-Modern-Classic-$BIBATA_VERSION.tar.xz")
    mkdir -p "$dir/usr/share/icons"
    tar -xJf "$tarball" -C "$dir/usr/share/icons"
    [ -f "$dir/usr/share/icons/Bibata-Modern-Classic/cursor.theme" ] || die "archive Bibata inattendue"
    build_deb "$dir"
}

# ── matos-bibliotheque : + livres libres figés (SHA256) et table des licences ─
build_matos_bibliotheque() {
    local dir; dir=$(stage matos-bibliotheque)
    local lib="$dir/usr/share/matos/bibliotheque"
    local rel url sha licence file
    {
        printf '\n## Livres téléchargés à la construction (version et SHA256 figés)\n\n'
        printf '| Fichier | Licence |\n|---|---|\n'
        while IFS='|' read -r rel url sha licence; do
            [ -n "$rel" ] || continue
            file=$(fetch "$url" "$sha" "livre-$(basename "$rel")")
            install -D -m 0644 "$file" "$lib/$rel"
            printf '| `%s` | %s |\n' "$rel" "$licence"
        done <<< "$MATOS_BOOKS"
    } >> "$lib/LISEZMOI.md"
    build_deb "$dir"
}

# ── matos-installer : dérivé de calamares-settings-debian ───────────────
build_matos_installer() {
    local dir; dir=$(stage matos-installer)
    local work="$BUILD_DIR/csd"
    rm -rf "$work"; mkdir -p "$work"
    (cd "$work" && apt-get download calamares-settings-debian)
    local deb; deb=$(echo "$work"/calamares-settings-debian_*.deb)
    [ -f "$deb" ] || die "calamares-settings-debian introuvable"
    local csd_version csd_depends
    csd_version=$(dpkg-deb -f "$deb" Version)
    csd_depends=$(dpkg-deb -f "$deb" Depends)
    dpkg-deb -x "$deb" "$work/root"

    # Reprendre configuration, modules et scripts d'aide de Debian
    cp -a "$work/root/etc/calamares/modules" "$dir/etc/calamares/"
    cp -a "$work/root/etc/calamares/settings.conf" "$dir/etc/calamares/"
    cp -a "$work/root/etc/xdg" "$dir/etc/"
    mkdir -p "$dir/usr"
    cp -a "$work/root/usr/bin" "$work/root/usr/lib" "$dir/usr/"
    mkdir -p "$dir/usr/share"
    cp -a "$work/root/usr/share/calamares" "$work/root/usr/share/applications" \
          "$work/root/usr/share/glib-2.0" "$dir/usr/share/"

    local c="$dir/etc/calamares"
    sed -i 's/^branding: .*/branding: matos/' "$c/settings.conf"
    grep -q '^branding: matos$' "$c/settings.conf" || die "settings.conf : branding non remplacé"
    # Supprimer aussi l'installateur et Calamares du système installé
    sed -i "s/^\( *\)- 'calamares-settings-debian'/\1- 'calamares-settings-debian'\n\1- 'matos-installer'\n\1- 'calamares'/" \
        "$c/modules/packages.conf"
    grep -q "'matos-installer'" "$c/modules/packages.conf" || die "packages.conf non modifié"
    # matOS installé occupe ~25 Go
    sed -i 's/^\( *requiredStorage: *\).*/\132/' "$c/modules/welcome.conf"
    # Lanceur : nom et icône matOS
    local app="$dir/usr/share/applications/calamares-install-debian.desktop"
    sed -i 's/^Name=.*/Name=Install matOS\nName[fr]=Installer matOS/; s/^Icon=.*/Icon=matos/; s/Debian Live/matOS/' "$app"
    # Icône de bureau : Debian utilise ~/Desktop en dur, faux en français (« Bureau »)
    sed -i 's|~/Desktop/|$DESKTOP/|g' "$dir/usr/bin/add-calamares-desktop-icon"

    # remplacement bash : les dépendances contiennent « | », inutilisable avec sed
    local ctl; ctl=$(<"$dir/DEBIAN/control")
    ctl=${ctl//@CSD_VERSION@/$csd_version}
    ctl=${ctl//@CSD_DEPENDS@/$csd_depends}
    printf '%s\n' "$ctl" > "$dir/DEBIAN/control"
    build_deb "$dir"
}

# ── matos-geogebra ──────────────────────────────────────────────────────
build_matos_geogebra() {
    local dir; dir=$(stage matos-geogebra)
    local zip; zip=$(fetch "$GEOGEBRA_URL" "$GEOGEBRA_SHA256")
    local work="$BUILD_DIR/geogebra"
    rm -rf "$work"; mkdir -p "$work"
    unzip -q "$zip" -d "$work"
    mkdir -p "$dir/opt/matos"
    mv "$work/GeoGebra-linux-x64" "$dir/opt/matos/geogebra"
    chmod 0755 "$dir/opt/matos/geogebra/GeoGebra" "$dir/opt/matos/geogebra/chrome_crashpad_handler"
    chmod -R a+rX "$dir/opt/matos/geogebra"
    build_deb "$dir"
}

# ── Paquets amont figés (copiés tels quels, SHA256 vérifié) ─────────────
build_upstream() {
    local url="$1" sha="$2" name="$3" file
    file=$(fetch "$url" "$sha" "$name")
    mkdir -p "$DEBS_DIR"
    cp "$file" "$DEBS_DIR/$name"
    log "Paquet amont figé : $name"
}
build_codium()  { build_upstream "$VSCODIUM_URL" "$VSCODIUM_SHA256" "codium_${VSCODIUM_VERSION}_amd64.deb"; }
# RStudio dépend de libclang-dev (complétion C++) : ce qui installe ~1 Go de LLVM/Clang
# (llvm-19-dev, libclang-19-dev...). On retire cette seule dépendance ; le reste du paquet
# est celui d'origine (SHA256 vérifié). Sans libclang, seule la complétion de code C++
# est dégradée ; « sudo apt install libclang-dev » la rétablit.
build_rstudio() {
    local file; file=$(fetch "$RSTUDIO_URL" "$RSTUDIO_SHA256" "rstudio_${RSTUDIO_VERSION}_amd64.deb")
    local work="$BUILD_DIR/rstudio"
    rm -rf "$work"; mkdir -p "$work"
    dpkg-deb -R "$file" "$work"
    sed -i '/^Depends:/ { s/libclang-dev, //; s/, libclang-dev//; s/libclang-dev//; }' "$work/DEBIAN/control"
    sed -i 's/^Version: \(.*\)$/Version: \1+matos1/' "$work/DEBIAN/control"
    ! grep -q 'libclang' "$work/DEBIAN/control" || die "RStudio : dépendance libclang toujours présente"
    mkdir -p "$DEBS_DIR"
    dpkg-deb --root-owner-group -Zzstd -z9 --build "$work" "$DEBS_DIR/rstudio_${RSTUDIO_VERSION}+matos1_amd64.deb" >&2
    log "RStudio repaqueté sans libclang-dev"
}

# ── matos-vscodium-config : extensions intégrées ────────────────────────
build_matos_vscodium_config() {
    local dir; dir=$(stage matos-vscodium-config)
    local ext="$dir/usr/share/codium/resources/app/extensions"
    mkdir -p "$ext"
    local id version sha publisher name file work
    while IFS='|' read -r id version sha; do
        [ -n "$id" ] || continue
        publisher=${id%%.*}; name=${id#*.}
        file=$(fetch "https://open-vsx.org/api/$publisher/$name/$version/file/$id-$version.vsix" \
                     "$sha" "$id-$version.vsix")
        work="$BUILD_DIR/vsix/$id"
        rm -rf "$work"; mkdir -p "$work"
        unzip -q "$file" 'extension/*' -d "$work"
        mv "$work/extension" "$ext/${id,,}-$version"
    done <<< "$VSCODIUM_EXTENSIONS"
    chmod -R a+rX "$ext"
    build_deb "$dir"
}

# run_as_nobody COMMANDE : exécute en utilisateur sans droits avec un HOME
# temporaire, pour vérifier qu'une appli marche depuis un /opt en lecture seule.
run_as_nobody() {
    local home; home=$(mktemp -d)
    chown nobody:nogroup "$home"
    (cd "$home" && runuser -u nobody -- env -i HOME="$home" PATH=/usr/bin:/bin LANG=C.UTF-8 "$@")
    rm -rf "$home"
}

# ── matos-sagemath : environnement conda figé ───────────────────────────
build_matos_sagemath() {
    local dir; dir=$(stage matos-sagemath)
    local prefix=/opt/matos/sagemath
    local mm; mm=$(fetch "$MICROMAMBA_URL" "$MICROMAMBA_SHA256" "micromamba-$MICROMAMBA_VERSION")
    install -m 0755 "$mm" "$BUILD_DIR/micromamba"
    local lock="$dir/usr/share/matos/sagemath/environment.lock"
    grep -q "^sage=$SAGE_VERSION=" "$lock" || die "environment.lock ne contient pas sage=$SAGE_VERSION"

    rm -rf "$prefix"
    grep -v '^#' "$lock" > "$BUILD_DIR/sage-specs.txt"
    # Niveau x86-64 de base, quel que soit le processeur de la machine de build :
    # l'image doit tourner sur de vieux Atom et Core 2 (voir scripts/relock-sagemath.sh)
    export CONDA_OVERRIDE_ARCHSPEC=x86_64
    MAMBA_ROOT_PREFIX="$BUILD_DIR/mamba" "$BUILD_DIR/micromamba" create -y \
        -p "$prefix" --override-channels -c conda-forge --file "$BUILD_DIR/sage-specs.txt"
    # Trace exacte (URL + empreinte) de ce qui a été installé
    MAMBA_ROOT_PREFIX="$BUILD_DIR/mamba" "$BUILD_DIR/micromamba" env export \
        -p "$prefix" --explicit --md5 > "$dir/usr/share/matos/sagemath/environment.explicit.txt"
    if compgen -G "$prefix/conda-meta/_x86_64-microarch-level-*" >/dev/null \
       && ! compgen -G "$prefix/conda-meta/_x86_64-microarch-level-1-*" >/dev/null; then
        die "environnement SageMath optimisé pour processeurs récents : relancer scripts/relock-sagemath.sh"
    fi
    rm -rf "$prefix/pkgs"

    # ── Allègement : retire les extras (réinstallables avec matos-sage-extras) ──
    local sage_dir="$dir/usr/share/matos/sagemath" avant apres nom desc noms
    avant=$(du -sm "$prefix" | cut -f1)
    while IFS='|' read -r nom desc noms; do
        case "$nom" in ''|'#'*) continue ;; esac
        # shellcheck disable=SC2086
        MAMBA_ROOT_PREFIX="$BUILD_DIR/mamba" "$BUILD_DIR/micromamba" remove -y --force -p "$prefix" $noms
        compgen -G "$prefix/conda-meta/${noms%% *}-[0-9]*.json" >/dev/null \
            && die "l'extra « $nom » n'a pas été retiré"
    done < "$sage_dir/groupes.conf"
    # bibliothèques statiques : utiles seulement pour compiler des programmes en C
    find "$prefix" -name '*.a' -delete
    rm -rf "$prefix/conda-meta/history"
    apres=$(du -sm "$prefix" | cut -f1)
    log "SageMath allégé : $avant Mo -> $apres Mo"
    install -D -m 0755 "$BUILD_DIR/micromamba" "$dir/opt/matos/bin/micromamba"
    chmod -R a+rX "$prefix"

    log "Test SageMath (utilisateur sans droits)"
    run_as_nobody "$prefix/bin/sage" -c 'f = factor(2^64+1); assert [(int(p), e) for p, e in f] == [(274177, 1), (67280421310721, 1)], f; assert f.value() == 2^64+1; print("sage OK", version())'
    run_as_nobody "$prefix/bin/python" -c 'import numpy, scipy, sympy, matplotlib, pandas, networkx, jupyterlab, ipywidgets; print("python OK")'
    # compilation d'une extension avec le gcc de Debian (le gcc de conda est un extra)
    run_as_nobody sh "$dir/usr/bin/sage" -c 'import os; open("carre.pyx", "w").write("def carre(int n):\n    return n * n\n"); from sage.misc.cython import cython_import_all; cython_import_all(os.path.abspath("carre.pyx"), globals()); assert carre(12) == 144; print("cython OK")'
    # un graphique 3D sans Java (threejs) et le calcul symbolique
    run_as_nobody "$prefix/bin/sage" -c 'x, y = var("x y"); p = plot3d(sin(x*y), (x, -2, 2), (y, -2, 2)); assert p is not None; assert (integrate(x*exp(x), x) - (x - 1)*exp(x)).simplify_full() == 0; print("3d+symbolique OK")'

    log "Test des extras (installation puis retrait d'un extra)"
    export MATOS_SAGE_PREFIX="$prefix" MATOS_SAGE_DIR="$sage_dir" MATOS_MM="$BUILD_DIR/micromamba" \
           MAMBA_ROOT_PREFIX="$BUILD_DIR/mamba"
    sh "$dir/usr/bin/matos-sage-extras" liste
    sh "$dir/usr/bin/matos-sage-extras" installer pandoc
    "$prefix/bin/pandoc" --version | head -1
    MAMBA_ROOT_PREFIX="$BUILD_DIR/mamba" "$BUILD_DIR/micromamba" remove -y --force -p "$prefix" pandoc
    rm -rf "$prefix/conda-meta/history"
    unset MATOS_SAGE_PREFIX MATOS_SAGE_DIR MATOS_MM
    sh "$dir/usr/bin/matos-sage-extras" liste >/dev/null || true

    mkdir -p "$dir/opt/matos"
    mv "$prefix" "$dir/opt/matos/sagemath"
    build_deb "$dir"
}

# ── matos-lean : Lean 4 + Mathlib précompilée ───────────────────────────
build_matos_lean() {
    local dir; dir=$(stage matos-lean)
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
    cat > "$modele/Projet/Basic.lean" <<'EOF'
import Mathlib

/-! Premier fichier de votre projet Lean 4 (Mathlib est disponible hors ligne). -/

open Real

example (a b : ℝ) : (a + b) ^ 2 = a ^ 2 + 2 * a * b + b ^ 2 := by ring

theorem racine_deux_irrationnelle : Irrational (√2) := irrational_sqrt_two
EOF
    # cache des oleans Mathlib conservé entre deux builds (plusieurs Go)
    export MATHLIB_CACHE_DIR="$BUILD_DIR/mathlib-cache"; mkdir -p "$MATHLIB_CACHE_DIR"
    (cd "$modele" && lake update && lake exe cache get)
    # La toolchain doit être exactement celle de Mathlib, sinon tout serait recompilé
    cmp -s "$modele/lean-toolchain" "$modele/.lake/packages/mathlib/lean-toolchain" \
        || die "LEAN_TOOLCHAIN ($LEAN_TOOLCHAIN) ≠ toolchain de Mathlib $MATHLIB_REV"
    (cd "$modele" && lake build)
    rm -rf "$modele/.lake/build"
    chmod -R a+rX "$prefix"

    log "Test Lean + Mathlib (utilisateur sans droits, /opt en lecture seule)"
    # même réglage que DEBIAN/postinst de matos-lean
    git config --system --add safe.directory "$prefix/modele/.lake/packages/*"
    run_as_nobody env ELAN_HOME="$ELAN_HOME" PATH="$ELAN_HOME/bin:/usr/bin:/bin" sh -c '
        sh "$0" essai && cd essai && lake build && echo "lean OK"' \
        "$dir/usr/bin/matos-lean-projet"

    export PATH="$path_save"; unset ELAN_HOME
    mkdir -p "$dir/opt/matos"
    mv "$prefix" "$dir/opt/matos/lean"
    build_deb "$dir"
}

# ── Sélection ───────────────────────────────────────────────────────────
ALL="matos-base matos-archive-keyring matos-stats matos-desktop matos-math matos-documentation matos-installer matos-bibliotheque
     matos-geogebra codium rstudio matos-vscodium-config"
HEAVY="matos-sagemath matos-lean"
[ "${MATOS_SKIP_HEAVY:-0}" = 1 ] || ALL="$ALL $HEAVY"

for pkg in ${@:-$ALL}; do
    fn="build_${pkg//-/_}"
    if declare -F "$fn" >/dev/null; then "$fn"; else build_simple "$pkg"; fi
done
log "Paquets prêts dans $DEBS_DIR"
