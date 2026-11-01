# matOS RALAMBO

Distribution Linux pour les étudiants et enseignants en mathématiques :
légère (XFCE), complète et **utilisable entièrement hors ligne**.
Basée sur **Debian 13 « Trixie »**, construite avec
[live-build](https://live-team.pages.debian.net/live-manual/), l'outil officiel
de Debian pour les images live.

matOS 0.6 RALAMBO succède à matOS 0.5 Archimedes (MX Linux 23). Elle est
dédiée à la mémoire du Professeur Ralambo (Université d'Antananarivo).

---

## Logiciels inclus

| Domaine | Logiciels |
|---|---|
| Calcul formel | **SageMath 10.9**, Maxima/wxMaxima, Xcas/Giac, SymPy |
| Algèbre, nombres | PARI/GP, GAP (+ bibliothèques), Singular |
| Preuves formelles | **Lean 4 + Mathlib précompilée**, Coq/CoqIDE |
| Géométrie | **GeoGebra Classic 6**, Kig |
| Calcul numérique | GNU Octave, Scilab, NumPy/SciPy |
| Statistiques | R + paquets recommandés, **RStudio** |
| Python scientifique | NumPy, SciPy, SymPy, Matplotlib, pandas, scikit-learn, statsmodels, NetworkX, Manim, JupyterLab |
| Rédaction | TeX Live (français, sciences, TikZ, beamer, XeTeX, LuaTeX), TeXstudio, **VSCodium** (Lean, LaTeX, Python, Jupyter), LibreOffice |
| Bibliothèque | Livres libres : analyse, algèbre, géométrie, Python, SICP, LaTeX, *Mathematics in Lean* |

---

## Construire l'ISO

Seul prérequis : **Docker** ou **Podman** (le build se fait dans un conteneur
`debian:trixie`, sur n'importe quelle distribution hôte). Prévoir ~80 Go de
disque libre et une bonne connexion pour le premier build.

```bash
./build.sh            # ISO complète (~10 Go), plusieurs heures
./build.sh --rapide   # ISO de test sans SageMath ni Lean
./build.sh --paquets  # seulement les paquets matos-* (build/debs/)
./build.sh --test     # démarre out/*.iso dans QEMU
```

Résultat : `out/matos-0.6-ralambo-amd64.hybrid.iso` (+ `.sha256` et la liste
des paquets). L'ISO est hybride : graver sur DVD ou copier sur une clé USB
(16 Go) avec `dd`, Ventoy, Etcher ou GNOME Disques. Elle démarre en BIOS et en
UEFI, Secure Boot compris.

Session live : utilisateur `matos`, mot de passe `live`. L'installation
(icône **Installer matOS**) copie tout le système, sans réseau ; il n'y a pas
de mot de passe root, l'utilisateur créé est administrateur via `sudo`.

---

## Principes de conception

1. **Le build échoue plutôt que de produire une image incomplète.** Pas de
   `|| true` sur les installations ; un hook final
   (`live/config/hooks/normal/9900-matos-verification.hook.chroot`) vérifie
   la présence de chaque logiciel. C'est ce qui manquait aux versions
   précédentes : `sagemath` n'existe plus dans Trixie, ce qui annulait en
   silence l'installation de *tous* les logiciels mathématiques.
2. **Tout est figé.** Chaque ressource téléchargée (SageMath via conda-forge,
   Lean, Mathlib, GeoGebra, VSCodium et ses extensions, RStudio, curseur, livres)
   a une version et un SHA256 dans [`versions.env`](versions.env). L'environnement
   SageMath est figé paquet par paquet dans
   [`environment.lock`](packages/matos-sagemath/usr/share/matos/sagemath/environment.lock).
3. **Les personnalisations résistent aux mises à jour.** Tout est livré sous
   forme de paquets `.deb` matOS, jamais par modification des fichiers d'autres
   paquets :
   - réglages XFCE dans `/etc/xdg/matos`, placé en tête de `XDG_CONFIG_DIRS` ;
   - identité système (`/usr/lib/os-release`) détournée par `dpkg-divert` ;
   - réglages système en fichiers *drop-in* (`sysctl.d`, `zram-generator.conf.d`,
     `NetworkManager/conf.d`, `lightdm.conf.d`) ;
   - applications tierces autonomes dans `/opt/matos`, sans dépôt amont ajouté :
     une mise à jour Debian ne peut ni les casser ni les remplacer.
4. **Hors ligne d'abord.** Mathlib est précompilée et partagée en lecture seule ;
   `matos-lean-projet MonProjet` crée un projet qui l'utilise sans réseau. Les
   tests de build lancent SageMath et Lean en utilisateur sans droits pour le
   vérifier.

---

## Structure du dépôt

```
build.sh                 point d'entrée (lance le conteneur de build)
versions.env             versions et SHA256 de tout ce qui est téléchargé
scripts/
  lib.sh                 téléchargement vérifié, construction des .deb
  build-debs.sh          construit les paquets matos-* (+ tests de fumée)
  container-build.sh     outils, paquets, configuration et lancement de live-build
  publish-repo.sh        dépôt APT matOS signé (release GitHub « depot »)
packages/                sources des paquets matOS
  matos-base             identité, zram, sysctl, NetworkManager, GRUB
  matos-stats            statistiques anonymes (désactivables)
  matos-desktop          XFCE, thème MatOS-Dark, LightDM, Plymouth, bienvenue
  matos-math             métapaquet des logiciels mathématiques de Debian
  matos-installer        Calamares (dérivé de calamares-settings-debian)
  matos-sagemath         SageMath + Python scientifique (conda-forge figé)
  matos-lean             Lean 4 + Mathlib précompilée
  matos-geogebra         GeoGebra Classic 6
  matos-vscodium-config  extensions et réglages VSCodium
  matos-bibliotheque     livres libres
  matos-archive-keyring  clé du dépôt APT matOS (si keys/ la contient)
live/                    configuration live-build (listes, hooks, écran de boot)
keys/                    clé publique du dépôt APT matOS (voir keys/README.md)
```

## Mettre à jour un logiciel

Modifier la version, l'URL et le SHA256 dans `versions.env`, puis reconstruire.
Pour SageMath : modifier la résolution dans `environment.lock` (une ligne
`nom=version=build` par paquet conda-forge).

## Dépôt APT en ligne (optionnel)

Pour distribuer des mises à jour des paquets `matos-*` aux machines installées :
créer une clé (voir [`keys/README.md`](keys/README.md)), reconstruire, puis
publier depuis un système Debian (ou le conteneur de build) :

```bash
scripts/publish-repo.sh "matOS archive" --envoyer
```

Sans clé dans `keys/`, aucun dépôt matOS n'est déclaré dans l'image.

## Statistiques anonymes

Même doctrine que Tontolo (projet Supabase partagé, table séparée `matos_pings`) :
au plus **un envoi par jour**, annoncé sur la page de bienvenue et désactivable
(*Paramètres › Statistiques anonymes*, ou `sudo matos-stats --desactiver`).
Liste blanche exacte : version de matOS, `live` ou `installe`, langue du système,
pays déduit du fuseau horaire. Aucun identifiant : on compte des envois, pas des
utilisateurs. `matos-stats --montrer` affiche le corps exact de la requête.

- Côté Supabase : exécuter une fois [`docs/stats/supabase-matos.sql`](docs/stats/supabase-matos.sql)
  (insertion seule pour la clé `anon`, aucune lecture publique).
- Côté build : `keys/stats.env` (non versionné) contient `MATOS_STATS_URL` et
  `MATOS_STATS_ANON_KEY`. Sans ce fichier, l'image n'envoie rien.

---

## Licence

[GPL-3.0](LICENSE) — Antsa Malala RANIRIAMANJAKA. Les logiciels et livres inclus
gardent leurs licences respectives.
