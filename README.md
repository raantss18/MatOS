# matOS RALAMBO

Distribution Linux pour les étudiants et enseignants en mathématiques :
légère (XFCE), complète et **utilisable entièrement hors ligne**.
Basée sur **Debian 13 « Trixie »**, construite avec
[live-build](https://live-team.pages.debian.net/live-manual/), l'outil officiel
de Debian pour les images live.

matOS RALAMBO succède à matOS 0.5 Archimedes (MX Linux 23). Elle est
dédiée à la mémoire du Professeur Ralambo (Université d'Antananarivo).

La version 0.7 tient sur une **clé USB de 8 Go** (ISO de 3,9 Go) et se complète, toujours hors
ligne, par des **modules** qu'on se passe de main en main : Lean + Mathlib, Coq, Scilab, RStudio,
livres de L3 à M2, Wikipédia en français.

---

## Site web

**https://raantss18.github.io/MatOS/** — téléchargement, documentation et espace d'échange des utilisateurs.
Les sources sont dans `site/src/` (charte : `site/DESIGN.md`) ; `python3 scripts/generer-site.py --verifier`
génère et contrôle le site, qui est publié automatiquement à chaque fusion dans `main`.
Questions et idées : [Discussions](https://github.com/raantss18/MatOS/discussions) ; voir aussi [CONTRIBUTING.md](CONTRIBUTING.md).

## Télécharger

L'ISO (3,9 Go) est publiée dans les [releases GitHub](https://github.com/raantss18/MatOS/releases),
découpée en parts de 1,9 Go (limite de 2 Go par fichier). Le script recompose l'ISO, **vérifie chaque
part (SHA256)** et reprend après une coupure de connexion :

```bash
curl -fLO https://raw.githubusercontent.com/raantss18/MatOS/main/scripts/telecharger-matos.sh
bash telecharger-matos.sh            # dernière version ; ou : bash telecharger-matos.sh v0.7
bash telecharger-matos.sh --modules  # l'ISO et tous les modules (≈ 9 Go en tout)
bash telecharger-matos.sh --sans-iso --module=lean   # un seul module
```

Prévoir ≈ 6 Go d'espace libre pour l'ISO. Puis la copier sur une clé USB de 8 Go ou plus.

## Modules hors ligne

L'ISO de base contient ce dont presque tout le monde a besoin. Le reste est dans des modules :
un fichier `.matmod` par module, à copier sur une clé et à installer **sans connexion** par le
menu **Modules matOS** (ou `sudo matos-modules installer FICHIER.matmod`). matOS vérifie
l'empreinte SHA256 de chaque module avant de l'installer.

| Module | Taille | Contenu |
|---|---|---|
| `lean` | 2,8 Go | Lean 4, Mathlib précompilée, VSCodium (extensions Lean, LaTeX, Python, Jupyter) |
| `preuve-calcul` | 0,96 Go | Coq et CoqIDE, Scilab, RStudio, outils de développement R |
| `bibliotheque` | 0,44 Go | 13 livres de L3 à M2, documentation de Python, SymPy, R, Singular, Git et des extensions LaTeX |
| `encyclopedie` | 0,80 Go | Wikipédia en français hors ligne (mathématiques, informatique, physique) |

`lean` et `preuve-calcul` installent des paquets : il leur faut un système installé, ou une
clé avec persistance (ci-dessous). En session live simple, `matos-modules` le dit et n'installe rien.

## Garder ses fichiers sur la clé (persistance)

Sans installer matOS : menu **Conserver mes fichiers sur la clé** (ou `sudo matos-persistance creer`).
L'outil crée une partition dans la place libre de la clé ; au démarrage suivant, fichiers, réglages
et modules installés sont conservés. La clé doit avoir été écrite directement (`dd`, balenaEtcher,
GNOME Disques) et garder au moins 1 Go libre ; avec Ventoy, utiliser la persistance de Ventoy.

## Logiciels inclus

| Domaine | Logiciels |
|---|---|
| Calcul formel | **SageMath 10.9** (cœur ; extras installables : `sudo matos-sage-extras liste`), Maxima/wxMaxima, Xcas/Giac, SymPy |
| Algèbre, nombres | PARI/GP, GAP (+ bibliothèques), Singular |
| Preuves formelles | modules : **Lean 4 + Mathlib précompilée** (`lean`), Coq/CoqIDE (`preuve-calcul`) |
| Géométrie | **GeoGebra Classic 6**, Kig |
| Calcul numérique | GNU Octave, NumPy/SciPy ; Scilab (module `preuve-calcul`) |
| Statistiques | R + paquets recommandés ; **RStudio** (module `preuve-calcul`) |
| Python scientifique | NumPy, SciPy, SymPy, Matplotlib, pandas, scikit-learn, statsmodels, NetworkX, Manim, JupyterLab |
| Rédaction | TeX Live (français, sciences, TikZ, beamer, XeTeX, LuaTeX), TeXstudio, Geany, LibreOffice ; **VSCodium** (module `lean`) |
| Enseigner | modèles LaTeX (cours, feuille de TD, sujet d'examen, diaporama), **Partage en salle** (`matos-partage`) |
| Bibliothèque | 23 livres libres rangés par niveau (L1, L2, Outils), licence vérifiée ; 13 de plus (L3, M1-M2) dans le module `bibliotheque` : voir [la liste](packages/matos-bibliotheque/usr/share/matos/bibliotheque/LISEZMOI.md) |
| Documentation hors ligne | Maxima, Octave, Gnuplot, LibreOffice (aide en français), pages de manuel en français, *Debian Reference* ; Python, SymPy, R, Singular, Git dans le module `bibliotheque` |
| Encyclopédie | Wikipédia en français, portails de mathématiques, d'informatique et de physique (module `encyclopedie`) |

---

## Construire l'ISO

Seul prérequis : **Docker** ou **Podman** (le build se fait dans un conteneur
`debian:trixie`, sur n'importe quelle distribution hôte). Prévoir ~80 Go de
disque libre et une bonne connexion pour le premier build.

```bash
./build.sh                  # ISO (3,9 Go) et les quatre modules, plusieurs heures
./build.sh --rapide         # ISO de test sans SageMath ni module
./build.sh --modules="lean" # ISO et seulement ces modules ("" : aucun)
./build.sh --reprise        # après l'échec d'un module : garde le système de base déjà construit
./build.sh --paquets        # seulement les paquets matos-* (build/debs/)
./build.sh --test           # démarre l'ISO dans QEMU (UEFI si OVMF est installé)
scripts/test-iso.sh         # test sans écran : 4 Go, processeur Core 2, rapport sur le port série
scripts/test-iso.sh --modules   # installe et essaie aussi les modules (MATOS_TEST_MEM=12G)
```

Résultat : `out/matos-0.7-ralambo-amd64.hybrid.iso` (+ `.sha256` et la liste
des paquets) et `out/modules/*.matmod`. L'ISO est hybride : graver sur DVD ou copier sur une
clé USB (8 Go ou plus) avec `dd`, Ventoy, Etcher ou GNOME Disques. Elle démarre en BIOS et en
UEFI, Secure Boot compris.

Session live : utilisateur `matos`, mot de passe `live`. L'installation
(icône **Installer matOS**) copie tout le système, sans réseau ; il n'y a pas
de mot de passe root, l'utilisateur créé est administrateur via `sudo`.

---

## Utiliser matOS

| Pour… | Commande ou menu |
|---|---|
| SageMath en terminal | `sage` |
| Carnets Jupyter (noyaux SageMath et Python) | menu *Mathématiques › JupyterLab*, ou `matos-jupyterlab` |
| Python scientifique complet (Manim, scikit-learn…) | `matos-python` (le `python3` du système reste celui de Debian) |
| Nouveau projet Lean 4 + Mathlib (module `lean`) | `matos-lean-projet MonProjet`, puis `codium MonProjet` |
| Modules hors ligne | menu *Modules matOS*, ou `matos-modules liste` |
| Encyclopédie hors ligne (module `encyclopedie`) | menu *Encyclopédie hors ligne*, ou `matos-encyclopedie` |
| Partager un dossier avec la salle | menu *Partage en salle*, ou `matos-partage` |
| GeoGebra Classic 6 | menu *Mathématiques*, ou `geogebra6` |
| Livres libres | dossier **Bibliothèque** du bureau |
| Statistiques anonymes | *Paramètres › Statistiques anonymes*, ou `matos-stats --montrer` |

Dans un projet Lean créé par `matos-lean-projet`, ne lancez pas `lake update` :
Mathlib y est partagée en lecture seule et figée à la version de matOS.

---

## Allègement et extras

- **SageMath** : le cœur (Jupyter, NumPy, SciPy, SymPy, Matplotlib, pandas, NetworkX) est dans
  l'ISO. Les compilateurs conda, Java/Jmol, giac, pandoc et les extras Python (scikit-learn,
  statsmodels, numba, plotly, seaborn, manim) s'ajoutent à l'identique, avec réseau :
  `sudo matos-sage-extras installer python|compilateurs|java-3d|giac|pandoc`.
- **RStudio** (module `preuve-calcul`) : paquet officiel sans sa dépendance `libclang-dev`
  (≈ 1 Go de LLVM évités) ; la complétion C++ est dégradée, `sudo apt install libclang-dev` la rétablit.
- **Lean + Mathlib** (module `lean`) : aucun élagage possible (Lake reconstruit tout module dont
  une sortie manque). Le projet modèle n'importe que `Mathlib.Tactic` et les réels : `import Mathlib`
  charge toute la bibliothèque et demande beaucoup de mémoire.
- **Traductions et documentation** : seuls le français, l'anglais et le malgache sont gardés ;
  la documentation de TeX Live (400 Mo) n'est pas installée (celle des extensions courantes est
  dans le module `bibliotheque`).
- **Dépendances recommandées** : Java, LLVM, Node.js et les firmwares NVIDIA sont bloqués pendant
  la construction (`live/config/archives/matos.pref.chroot`), sans laisser de blocage dans le système.
- **Compression** : zstd niveau 22. Blocs de 256 Kio pour le système (un logiciel qui démarre lit
  de petits morceaux : moins de données décompressées par accès sur une clé ou un disque dur),
  1 Mio pour les modules, sauf Lean (128 Kio : Mathlib, ce sont cent mille petits fichiers lus dans
  le désordre ; la première compilation passe de 250 s à 45 s). xz gagnerait ≈ 13 % mais serait 3 fois plus lent à décompresser.

## Machines modestes

matOS vise les PC anciens : vieux Atom 64 bits, 4 Go de RAM.

- **Mémoire** : swap compressé zram (zstd), `earlyoom` (termine le plus gros
  consommateur avant que le système ne gèle, bureau protégé), journaux limités.
- **Disque** : ordonnanceur BFQ sur les disques durs et les clés USB (le bureau reste réactif
  pendant une copie), le démarrage n'attend pas le réseau.
- **Bureau** : XFCE. Au premier démarrage, `matos-adaptatif` coupe la composition
  d'xfwm4 sur une machine à 4 Go ou sans accélération 3D.
- **Processeur** : noyau et paquets Debian amd64 (x86-64 de base, sans AVX exigé).
  GRUB UEFI 32 bits (`bootia32.efi`) pour les tablettes et mini-PC Atom à
  micrologiciel UEFI 32 bits avec processeur 64 bits.
- **Pas de 32 bits** : les Atom 32 bits (N270, N450…) ne sont pas pris en charge.

Ce qui tient à 4 Go : bureau, navigateur, LaTeX, Python, Xcas, Maxima, GAP,
PARI/GP, Singular, R, Octave, Geany. SageMath et LibreOffice demandent de la patience.
**Lean + Mathlib, RStudio, VSCodium et GeoGebra 6 sont lourds** (Electron) :
fermez le reste avant de les lancer, ou préférez Xcas, wxMaxima et Geany.
Mesuré dans QEMU (4 Go, Core 2, deux cœurs) : session complète 45 s après le lancement,
1,9 Go de mémoire occupée avec la page de bienvenue ouverte dans Firefox.
Les mesures sur matériel réel restent à faire (voir « Limites connues »).

---

## Principes de conception

1. **Le build échoue plutôt que de produire une image incomplète.** Pas de
   `|| true` sur les installations ; un hook final
   (`live/config/hooks/normal/9900-matos-verification.hook.chroot`) vérifie
   la présence de chaque logiciel. C'est ce qui manquait aux versions
   précédentes : `sagemath` n'existe plus dans Trixie, ce qui annulait en
   silence l'installation de *tous* les logiciels mathématiques.
2. **Tout est figé.** Chaque ressource téléchargée (SageMath via conda-forge,
   Lean, Mathlib, GeoGebra, VSCodium et ses extensions, RStudio, curseur, livres, Wikipédia)
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
4. **Hors ligne d'abord.** Les modules s'installent depuis un fichier, avec leur propre dépôt
   de paquets. Mathlib est précompilée et partagée en lecture seule ;
   `matos-lean-projet MonProjet` crée un projet qui l'utilise sans réseau. Les
   tests de build lancent SageMath et Lean en utilisateur sans droits pour le
   vérifier. L'installateur trouve sur l'ISO elle-même (dossier `pool/`) les
   paquets GRUB (BIOS ou UEFI) et LUKS qu'il installe : l'installation ne
   demande aucune connexion.

---

## Structure du dépôt

```
build.sh                 point d'entrée (lance le conteneur de build)
versions.env             versions et SHA256 de tout ce qui est téléchargé
scripts/
  lib.sh                 téléchargement vérifié, construction des .deb
  build-debs.sh          construit les paquets matos-* (+ tests de fumée)
  build-modules.sh       construit les modules hors ligne (.matmod) et leur catalogue
  container-build.sh     outils, paquets, configuration et lancement de live-build
  test-iso.sh            démarre l'ISO dans QEMU sans écran et contrôle son rapport
  publish-repo.sh        dépôt APT matOS signé (release GitHub « depot »)
  publier-release.sh     découpe l'ISO en parts et crée la release GitHub
  telecharger-matos.sh   pour les utilisateurs : télécharge, vérifie et recompose l'ISO
  livre-verifier.sh      contrôle un livre candidat (PDF, licence libre, SHA256)
packages/                sources des paquets matOS
  matos-base             identité, zram, sysctl, NetworkManager, GRUB, persistance sur clé
  matos-modules          gestionnaire des modules hors ligne (matos-modules)
  matos-enseignant       modèles LaTeX et partage en salle
  matos-stats            statistiques anonymes (désactivables)
  matos-desktop          XFCE, thème MatOS-Dark, LightDM, Plymouth, bienvenue
  matos-math             métapaquet des logiciels mathématiques de Debian
  matos-installer        Calamares (dérivé de calamares-settings-debian)
  matos-sagemath         SageMath + Python scientifique (conda-forge figé)
  matos-geogebra         GeoGebra Classic 6
  matos-vscodium-config  extensions et réglages VSCodium (module lean)
  matos-bibliotheque     livres libres L1, L2 et outils (licence vérifiée, SHA256)
  matos-documentation    documentation hors ligne des logiciels (Debian)
  matos-archive-keyring  clé du dépôt APT matOS (si keys/ la contient)
modules/                 sources des modules hors ligne (lean, preuve-calcul, bibliotheque, encyclopedie)
live/                    configuration live-build (listes, hooks, écran de boot)
live/config/package-lists/installateur.list.binary   paquets d'amorçage embarqués
docs/stats/               migration Supabase des statistiques
keys/                    clés et points d'accès non versionnés (voir keys/README.md)
CHANGELOG.md             historique des versions
```

## Publier une nouvelle version

L'ISO se construit en local (≈ 80 Go de disque, plusieurs heures : trop pour les exécuteurs gratuits
de GitHub Actions) ; la release est liée au dépôt par la version de `versions.env`.

```bash
# 1. changer MATOS_VERSION dans versions.env, noter les changements dans CHANGELOG.md, committer
./build.sh                           # 2. construire, puis tester : scripts/test-iso.sh, ./build.sh --test
# 3. fusionner la branche dans main (pull request)
scripts/publier-release.sh --a-blanc # 4. vérifier le découpage et les notes (rien n'est envoyé)
scripts/publier-release.sh           # 5. brouillon de release v<version> : parts de l'ISO, modules, SHA256SUMS
scripts/publier-release.sh --publier # 6. rendre la release publique (« dernière version »)
```

Le script refuse de publier si la version n'est pas dans `main`. Les machines déjà installées
reçoivent les mises à jour des paquets Debian par `apt` ; celles des paquets `matos-*` passent par le
dépôt APT matOS (voir plus bas).

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

## Tests réalisés

Sur l'ISO 0.7 (3,9 Go), dans QEMU avec 4 Go de RAM et un processeur de génération Core 2
(`scripts/test-iso.sh`) : démarrage jusqu'au bureau XFCE en 45 s, aucun service en échec, système
identifié comme matOS, écran non verrouillable en session live, logiciels présents.
Avec 12 Go (`--modules`) : les quatre modules s'installent sans réseau ; un projet Lean est créé
et compilé, Coq, Scilab, RStudio, Kiwix et les livres sont présents.
Installation avec Calamares sur un disque de 20 Go, sans réseau, en BIOS : « Effacer le disque »
présélectionné, dates en français, environ 4 minutes ; le système installé occupe 12 Go, démarre
sans service en échec et utilise 660 Mo de mémoire au repos (console). Les modules `preuve-calcul`
et `lean` s'y installent en une minute chacun (18 Go occupés ensuite) ; un premier projet Lean se
compile en 45 s. Persistance : partition créée sur une clé simulée de 7,4 Go, fichiers et réglages
retrouvés aux deux démarrages suivants.
Chargeurs d'amorçage : menu matOS puis bureau en BIOS (clé USB simulée, isolinux) et en UEFI
(OVMF, GRUB). L'installation en UEFI n'a été testée qu'en 0.6.
Non testés : vrai matériel, UEFI 32 bits, Secure Boot, disque chiffré, double amorçage,
consommation mémoire de SageMath et de Lean en usage réel.

## Limites connues

- L'ISO fait 3,9 Go : elle tient sur une clé de 8 Go, pas sur un DVD simple couche (4,7 Go
  suffisent en théorie, mais ce n'est pas testé) ni, en général, sur une clé de 4 Go.
- Place sur le disque : 12 Go pour matOS, 3 Go de plus pour chacun des modules `lean` et
  `preuve-calcul`. L'installateur exige 16 Go ; prévoir 32 Go pour tout installer.
- Les modules `lean` et `preuve-calcul` ne s'installent pas dans une session live sans
  persistance sur une machine à 4 Go : les paquets se décompresseraient en mémoire vive.
- Le module `lean` (2,8 Go) dépasse la limite de 2 Go par fichier de GitHub : il est publié en
  deux parts que `telecharger-matos.sh` recompose.
- Certaines adresses de livres changent de contenu sans changer de nom : la construction échoue
  alors sur l'empreinte. Un miroir des sources est à prévoir.
- RStudio ne publie pas de paquet propre à Debian 13 : c'est le paquet officiel
  « jammy », compatible et figé par SHA256.
- Le classement de la bibliothèque (L1 à M2) suit un parcours de licence classique, pas encore
  les unités d'enseignement de l'Université d'Antananarivo.
- Seule l'architecture **64 bits** (amd64) est prise en charge. Debian 13 ne fournit
  plus de noyau 32 bits.

---

## Licence

[GPL-3.0](LICENSE) — Antsa Malala RANIRIAMANJAKA. Les logiciels et livres inclus
gardent leurs licences respectives.
