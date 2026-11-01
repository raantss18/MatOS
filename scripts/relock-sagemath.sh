#!/bin/bash
# Régénère les fichiers figés de SageMath dans packages/matos-sagemath :
#   environment.lock          le CŒUR installé dans l'image (nom=version=build)
#   extras/python.lock        paquets Python facultatifs (scikit-learn, manim...)
#   extras/<groupe>.lock      paquets retirés de l'image (voir groupes.conf)
#
# Résolution VOLONTAIREMENT indépendante de la machine qui la lance :
#   - CONDA_OVERRIDE_ARCHSPEC=x86_64 : niveau de base x86-64 (sans AVX2 ni SSE4).
#     Sans cela le solveur choisit les variantes optimisées pour le processeur
#     de l'hôte, qui plantent sur un vieil Atom ou Core 2.
#   - CONDA_OVERRIDE_GLIBC / LINUX : ceux de Debian 13 (celui du conteneur de build).
# Les extras sont résolus AVEC le cœur épinglé : leurs paquets s'installent donc
# par-dessus l'image, avec --no-deps, sans rien changer au cœur.
# Usage : scripts/relock-sagemath.sh   (puis reconstruire)

. "$(dirname "$0")/lib.sh"

pkg="$MATOS_ROOT/packages/matos-sagemath/usr/share/matos/sagemath"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mm="$tmp/micromamba"
install -m 0755 "$(fetch "$MICROMAMBA_URL" "$MICROMAMBA_SHA256" "micromamba-$MICROMAMBA_VERSION")" "$mm"

export CONDA_OVERRIDE_ARCHSPEC=x86_64 CONDA_OVERRIDE_GLIBC=2.41 CONDA_OVERRIDE_LINUX=6.12 \
       MAMBA_ROOT_PREFIX="$tmp/root"

# Cœur : SageMath, Jupyter et l'essentiel du calcul scientifique
CORE_SPECS=(python=3.13 "sage=$SAGE_VERSION" jupyterlab notebook ipywidgets ipympl
            numpy scipy sympy matplotlib pandas networkx
            setuptools)  # setuptools : distutils pour %cython (retiré de Python 3.13)
# Facultatifs : apprentissage automatique, visualisation avancée, animations
PYTHON_EXTRAS=(scikit-learn statsmodels numba plotly seaborn manim pylatex)

solve() { "$mm" create --dry-run --json -p "$tmp/env" --override-channels -c conda-forge -y "$@"; }

solve "${CORE_SPECS[@]}" > "$tmp/core.json"
python3 - "$tmp/core.json" "$tmp/core.lock" "$SAGE_VERSION" <<'PY'
import json, sys
solve, out, sage = sys.argv[1:4]
links = json.load(open(solve))["actions"]["LINK"]
levels = [p["version"] for p in links if p["name"] == "_x86_64-microarch-level"]
assert not levels or levels == ["1"], f"niveau de microarchitecture {levels} : variante non portable"
assert any(p["name"] == "sage" and p["version"] == sage for p in links), "sage manquant"
open(out, "w").write("".join(f"{p['name']}={p['version']}={p['build_string']}\n" for p in sorted(links, key=lambda p: p["name"])))
print(len(links), "paquets dans le cœur")
PY

# Extras Python : résolus avec le cœur épinglé
mapfile -t pins < "$tmp/core.lock"
solve "${pins[@]}" "${PYTHON_EXTRAS[@]}" > "$tmp/full.json"

python3 - "$tmp" "$pkg" <<'PY'
import json, os, sys
tmp, pkg = sys.argv[1:3]
core = [l.strip() for l in open(f"{tmp}/core.lock") if l.strip()]
core_names = {l.split("=")[0]: l for l in core}
full = {p["name"]: f"{p['name']}={p['version']}={p['build_string']}"
        for p in json.load(open(f"{tmp}/full.json"))["actions"]["LINK"]}
changed = [n for n in core_names if full.get(n) != core_names[n]]
assert not changed, f"le solveur a modifié des paquets du cœur : {changed}"

def write(path, header, lines):
    with open(path, "w") as f:
        f.write(header)
        f.write("".join(l + "\n" for l in lines))

os.makedirs(f"{pkg}/extras", exist_ok=True)
write(f"{pkg}/environment.lock",
      "# matOS — CŒUR de l'environnement conda figé (SageMath + Python scientifique).\n"
      "# Généré par scripts/relock-sagemath.sh (conda-forge, linux-64, x86-64 de base).\n"
      "# Une ligne = un paquet exact. Les extras sont dans extras/.\n", core)
python_extra = sorted(l for n, l in full.items() if n not in core_names)
write(f"{pkg}/extras/python.lock", "# Extras Python : voir scripts/relock-sagemath.sh\n", python_extra)
print(len(python_extra), "paquets dans l'extra « python »")

for ligne in open(f"{pkg}/groupes.conf"):
    ligne = ligne.strip()
    if not ligne or ligne.startswith("#"):
        continue
    nom, _desc, noms = [c.strip() for c in ligne.split("|")]
    noms = noms.split()
    absents = [n for n in noms if n not in core_names]
    if absents:
        print(f"AVERTISSEMENT {nom} : absents du cœur : {absents}", file=sys.stderr)
    write(f"{pkg}/extras/{nom}.lock", f"# Extra « {nom} » : voir groupes.conf\n",
          [core_names[n] for n in noms if n in core_names])
    print(f"extra {nom} : {len([n for n in noms if n in core_names])} paquets")
PY
