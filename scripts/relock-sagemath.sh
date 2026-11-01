#!/bin/bash
# Régénère packages/matos-sagemath/usr/share/matos/sagemath/environment.lock :
# la résolution exacte (nom=version=build) de SageMath et de la pile Python.
#
# Résolution VOLONTAIREMENT indépendante de la machine qui la lance :
#   - CONDA_OVERRIDE_ARCHSPEC=x86_64 : niveau de base x86-64 (sans AVX2 ni SSE4).
#     Sans cela le solveur choisit les variantes optimisées pour le processeur
#     de l'hôte, qui plantent sur un vieil Atom ou Core 2.
#   - CONDA_OVERRIDE_GLIBC / LINUX : ceux de Debian 13 (celui du conteneur de build).
# Usage : scripts/relock-sagemath.sh   (puis reconstruire)

. "$(dirname "$0")/lib.sh"

lock="$MATOS_ROOT/packages/matos-sagemath/usr/share/matos/sagemath/environment.lock"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mm="$tmp/micromamba"
install -m 0755 "$(fetch "$MICROMAMBA_URL" "$MICROMAMBA_SHA256" "micromamba-$MICROMAMBA_VERSION")" "$mm"

export CONDA_OVERRIDE_ARCHSPEC=x86_64 CONDA_OVERRIDE_GLIBC=2.41 CONDA_OVERRIDE_LINUX=6.12 \
       MAMBA_ROOT_PREFIX="$tmp/root"
"$mm" create --dry-run --json -p "$tmp/env" --override-channels -c conda-forge -y \
    python=3.13 "sage=$SAGE_VERSION" jupyterlab notebook ipywidgets ipympl \
    numpy scipy sympy matplotlib pandas scikit-learn statsmodels networkx numba \
    plotly seaborn manim pylatex > "$tmp/solve.json"

python3 - "$tmp/solve.json" "$lock" "$SAGE_VERSION" <<'PY'
import json, sys
solve, lock, sage = sys.argv[1:4]
links = json.load(open(solve))["actions"]["LINK"]
levels = [p["version"] for p in links if p["name"] == "_x86_64-microarch-level"]
assert not levels or levels == ["1"], f"niveau de microarchitecture {levels} : variante non portable"
assert any(p["name"] == "sage" and p["version"] == sage for p in links), "sage manquant"
with open(lock, "w") as f:
    f.write("# matOS — environnement conda figé (SageMath + Python scientifique)\n")
    f.write("# Généré par scripts/relock-sagemath.sh (conda-forge, linux-64, niveau x86-64 de base).\n")
    f.write("# Une ligne = un paquet exact.\n")
    for p in sorted(links, key=lambda p: p["name"]):
        f.write(f"{p['name']}={p['version']}={p['build_string']}\n")
print(len(links), "paquets, niveau microarch :", levels or "aucune contrainte")
PY
