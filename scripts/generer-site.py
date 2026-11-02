#!/usr/bin/env python3
"""Assemble le site matOS : fragments de pages + gabarit -> site/public/ (HTML statique).

Chaque fragment (site/src/pages/**/*.html) commence par :
    <!-- titre: Titre de la page -->
    <!-- description: Une phrase pour les moteurs de recherche et les partages -->
    <!-- section: accueil|telecharger|documentation|communaute -->   (entrée de menu active)
Dans les fragments et le gabarit, {{racine}} vaut le préfixe relatif vers la racine du site
(« », « ../ »...), ce qui permet d'héberger le site sous un sous-dossier (GitHub Pages).
Bibliothèque standard uniquement. Usage : python3 scripts/generer-site.py [--verifier]
"""
import html, re, shutil, sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent / "site"
SRC, SORTIE = RACINE / "src", RACINE / "public"
VERSION = ""
for ligne in (RACINE.parent / "versions.env").read_text().splitlines():
    if ligne.startswith("MATOS_VERSION="):
        VERSION = ligne.split("=", 1)[1].strip()

MENU = [("accueil", "Accueil", ""), ("telecharger", "Télécharger", "telecharger.html"),
        ("documentation", "Documentation", "documentation/"), ("communaute", "Communauté", "communaute.html")]

DOCS = [("./", "Vue d'ensemble"), ("installer.html", "Installer matOS"), ("premiers-pas.html", "Premiers pas"),
        ("logiciels.html", "Les logiciels"), ("machines-modestes.html", "Machines modestes"),
        ("compatibilite.html", "Compatibilité matérielle"), ("faq.html", "Questions fréquentes"),
        ("confidentialite.html", "Confidentialité"), ("construire.html", "Construire et contribuer")]

def menu_doc(rel: Path) -> str:
    """Menu latéral de la documentation ; la page courante est marquée aria-current."""
    courant = "./" if rel.name == "index.html" else rel.name
    liens = "".join(f'<a href="{url}"{" aria-current=\"page\"" if url == courant else ""}>{nom}</a>' for url, nom in DOCS)
    return f'<nav class="doc-menu" aria-label="Documentation"><p>Documentation</p>{liens}</nav>'

def meta(texte, cle):
    m = re.search(rf"<!--\s*{cle}:\s*(.*?)\s*-->", texte)
    return m.group(1) if m else ""

def assembler(chemin: Path, gabarit: str) -> tuple[Path, str]:
    rel = chemin.relative_to(SRC / "pages")
    profondeur = len(rel.parts) - 1
    racine = "../" * profondeur
    texte = chemin.read_text(encoding="utf-8")
    titre, desc, section = meta(texte, "titre"), meta(texte, "description"), meta(texte, "section")
    if not titre or not desc:
        raise SystemExit(f"{rel} : titre et description obligatoires")
    contenu = re.sub(r"<!--\s*(titre|description|section):.*?-->\n?", "", texte)
    menu = "".join(
        f'<li><a href="{racine}{url}"{" aria-current=\"page\"" if cle == section else ""}>{nom}</a></li>'
        for cle, nom, url in MENU)
    if rel.parts[0] == "documentation":
        contenu = contenu.replace("{{menu-doc}}", menu_doc(rel))
    page = (gabarit.replace("{{contenu}}", contenu).replace("{{menu}}", menu)
            .replace("{{titre}}", html.escape(titre if section == "accueil" else f"{titre} · matOS"))
            .replace("{{description}}", html.escape(desc, quote=True))
            .replace("{{version}}", VERSION).replace("{{racine}}", racine))
    return rel, page

def main():
    gabarit = (SRC / "layout.html").read_text(encoding="utf-8")
    if SORTIE.exists():
        shutil.rmtree(SORTIE)
    SORTIE.mkdir(parents=True)
    pages = sorted((SRC / "pages").rglob("*.html"))
    for p in pages:
        rel, page = assembler(p, gabarit)
        cible = SORTIE / rel
        cible.parent.mkdir(parents=True, exist_ok=True)
        cible.write_text(page, encoding="utf-8")
    for nom in ("style.css", "app.js"):
        shutil.copy(SRC / nom, SORTIE / nom)
    if (SRC / "assets").exists():
        shutil.copytree(SRC / "assets", SORTIE / "assets")
    (SORTIE / ".nojekyll").write_text("")
    # Jeu de pages pour les moteurs de recherche
    print(f"{len(pages)} pages -> {SORTIE}")
    if "--verifier" in sys.argv:
        sys.exit(verifier())

def verifier() -> int:
    """Liens internes, ancres, images et attributs alt."""
    erreurs = []
    pages = sorted(SORTIE.rglob("*.html"))
    ids = {p: set(re.findall(r'\bid="([^"]+)"', p.read_text(encoding="utf-8"))) for p in pages}
    for p in pages:
        t = p.read_text(encoding="utf-8")
        for m in re.finditer(r'<img\b[^>]*>', t):
            if " alt=" not in m.group(0):
                erreurs.append(f"{p.relative_to(SORTIE)} : image sans alt : {m.group(0)[:60]}")
        for m in re.finditer(r'(?:href|src)="(?![a-z][a-z0-9+.-]*:)([^"#]*)(#[^"]*)?"', t):
            cible, ancre = m.group(1), m.group(2)
            if not cible:          # ancre de la page elle-même : contrôlée plus bas
                continue
            f = (p.parent / cible).resolve()
            if f.is_dir():
                f = f / "index.html"
            if not f.exists():
                erreurs.append(f"{p.relative_to(SORTIE)} : lien cassé {cible}")
            elif ancre and f.suffix == ".html" and ancre[1:] not in ids.get(f, set()):
                erreurs.append(f"{p.relative_to(SORTIE)} : ancre absente {cible}{ancre}")
        for m in re.finditer(r'href="#([^"]+)"', t):
            if m.group(1) not in ids[p]:
                erreurs.append(f"{p.relative_to(SORTIE)} : ancre locale absente #{m.group(1)}")
        if t.count("<h1") != 1:
            erreurs.append(f"{p.relative_to(SORTIE)} : {t.count('<h1')} titres h1 (1 attendu)")
    for e in erreurs:
        print("ERREUR", e)
    print("vérification :", "échec" if erreurs else "aucune erreur", f"({len(pages)} pages)")
    return 1 if erreurs else 0

if __name__ == "__main__":
    main()
