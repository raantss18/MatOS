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
| Calcul formel | **SageMath 10.9** (cœur ; extras installables : `sudo matos-sage-extras liste`), Maxima/wxMaxima, Xcas/Giac, SymPy |
| Algèbre, nombres | PARI/GP, GAP (+ bibliothèques), Singular |
| Preuves formelles | **Lean 4 + Mathlib précompilée**, Coq/CoqIDE |
| Géométrie | **GeoGebra Classic 6**, Kig |
| Calcul numérique | GNU Octave, Scilab, NumPy/SciPy |
| Statistiques | R + paquets recommandés, **RStudio** |
| Python scientifique | NumPy, SciPy, SymPy, Matplotlib, pandas, scikit-learn, statsmodels, NetworkX, Manim, JupyterLab |
| Rédaction | TeX Live (français, sciences, TikZ, beamer, XeTeX, LuaTeX), TeXstudio, **VSCodium** (Lean, LaTeX, Python, Jupyter), LibreOffice |
| Bibliothèque | 23 livres libres (licence vérifiée) : Exo7, analyse, équations différentielles, mathématiques discrètes, logique, probabilités, algorithmique, SICP, Python, Git, LaTeX, *Mathematics in Lean*… voir [la liste](packages/matos-bibliotheque/usr/share/matos/bibliotheque/LISEZMOI.md) |
| Documentation hors ligne | Python, SymPy, R, Maxima, Octave, Gnuplot, Coq, Singular, Git, LibreOffice (aide en français), pages de manuel en français, *Debian Reference* |

---

## Construire l'ISO

Seul prérequis : **Docker** ou **Podman** (le build se fait dans un conteneur
`debian:trixie`, sur n'importe quelle distribution hôte). Prévoir ~80 Go de
disque libre et une bonne connexion pour le premier build.

```bash
./build.sh            # ISO complète (≈ 8,3 Go), plusieurs heures
./build.sh --rapide   # ISO de test sans SageMath ni Lean
./build.sh --paquets  # seulement les paquets matos-* (build/debs/)
./build.sh --test     # démarre l'ISO dans QEMU (UEFI si OVMF est installé)
```

Résultat : `out/matos-0.6-ralambo-amd64.hybrid.iso` (+ `.sha256` et la liste
des paquets). L'ISO est hybride : graver sur DVD ou copier sur une clé USB
(16 Go) avec `dd`, Ventoy, Etcher ou GNOME Disques. Elle démarre en BIOS et en
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
| Nouveau projet Lean 4 + Mathlib | `matos-lean-projet MonProjet`, puis `codium MonProjet` |
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
- **RStudio** : paquet officiel sans sa dépendance `libclang-dev` (≈ 1 Go de LLVM évités) ;
  la complétion C++ est dégradée, `sudo apt install libclang-dev` la rétablit.
- **Lean + Mathlib** : aucun élagage possible (Lake reconstruit tout module dont une sortie manque).
- **Compression** : zstd niveau 22, blocs de 1 Mio (mesuré : −6 % sans ralentir la lecture ;
  xz serait −13,5 % mais 3 fois plus lent à décompresser sur un vieux processeur).

## Machines modestes

matOS vise les PC anciens : vieux Atom 64 bits, 4 Go de RAM.

- **Mémoire** : swap compressé zram (zstd), `earlyoom` (termine le plus gros
  consommateur avant que le système ne gèle, bureau protégé), journaux limités.
- **Bureau** : XFCE. Au premier démarrage, `matos-adaptatif` coupe la composition
  d'xfwm4 sur une machine à 4 Go ou sans accélération 3D.
- **Processeur** : noyau et paquets Debian amd64 (x86-64 de base, sans AVX exigé).
  GRUB UEFI 32 bits (`bootia32.efi`) pour les tablettes et mini-PC Atom à
  micrologiciel UEFI 32 bits avec processeur 64 bits.
- **Pas de 32 bits** : les Atom 32 bits (N270, N450…) ne sont pas pris en charge.

Ce qui tient à 4 Go : bureau, navigateur, LaTeX, Python, Xcas, Maxima, GAP,
PARI/GP, Singular, R, Octave. SageMath et LibreOffice demandent de la patience.
**Lean + Mathlib, RStudio, VSCodium et GeoGebra 6 sont lourds** (Electron ou JVM) :
fermez le reste avant de les lancer, ou préférez Xcas, wxMaxima et Mousepad.
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
  container-build.sh     outils, paquets, configuration et lancement de live-build
  publish-repo.sh        dépôt APT matOS signé (release GitHub « depot »)
  livre-verifier.sh      contrôle un livre candidat (PDF, licence libre, SHA256)
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
  matos-bibliotheque     livres libres (licence vérifiée, SHA256)
  matos-documentation    documentation hors ligne des logiciels (Debian)
  matos-archive-keyring  clé du dépôt APT matOS (si keys/ la contient)
live/                    configuration live-build (listes, hooks, écran de boot)
live/config/package-lists/installateur.list.binary   paquets d'amorçage embarqués
docs/stats/               migration Supabase des statistiques
keys/                    clés et points d'accès non versionnés (voir keys/README.md)
CHANGELOG.md             historique des versions
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

## Limites connues

- L'ISO complète fait 8,3 Go : il faut une clé USB de 16 Go (pas de DVD, et la clé de 8 Go ne suffit pas).
  Descendre sous 5 Go impose de sortir Mathlib (1,7 Go compressé) ou SageMath (≈ 1 Go) de l'ISO.
  L'installation occupe environ 25 Go, et l'installateur exige 32 Go libres.
- RStudio ne publie pas de paquet propre à Debian 13 : c'est le paquet officiel
  « jammy », compatible et figé par SHA256.
- Les besoins mémoire réels (SageMath, Lean + Mathlib) ne sont pas encore mesurés sur
  un vieux PC ; ils seront contrôlés dans QEMU limité à 4 Go avec un processeur ancien.
- Une release GitHub limite chaque fichier à 2 Gio ; les paquets SageMath et Lean
  peuvent dépasser cette taille et devront alors être hébergés ailleurs.
- Seule l'architecture **64 bits** (amd64) est prise en charge. Debian 13 ne fournit
  plus de noyau 32 bits ; une édition 32 bits devrait reposer sur Debian 12 et sans
  SageMath récent, Lean ni Electron : voir « Machines modestes ».

---

## Licence

[GPL-3.0](LICENSE) — Antsa Malala RANIRIAMANJAKA. Les logiciels et livres inclus
gardent leurs licences respectives.
