# Changelog matOS

## [0.7] — RALAMBO *(en préparation)*

Objectif : une image qui tient sur une clé de 8 Go, démarre plus vite sur un PC à 4 Go avec
disque dur, et se complète hors ligne par des modules passés de main en main.

### Ruptures
- **ISO de base de 3,9 Go** (8,3 Go en 0.6). Lean + Mathlib, VSCodium, Coq, Scilab, RStudio et
  une partie de la bibliothèque quittent l'ISO pour devenir des **modules hors ligne**.
- Le paquet `matos-lean` disparaît (module `lean`) ; la liste `matos-lourds` devient `matos-sagemath`.
- L'installateur exige 16 Go libres (32 Go en 0.6) ; le système installé occupe 12 Go.

### Nouveau
- **Modules hors ligne** (`.matmod`) : un fichier par module, vérifié par SHA256 contre le
  catalogue de l'image, installé sans réseau par le menu **Modules matOS** ou
  `sudo matos-modules installer FICHIER`. Quatre modules :

  | Module | Taille | Contenu |
  |---|---|---|
  | `lean` | 2,8 Go | Lean 4, Mathlib précompilée, VSCodium et ses extensions |
  | `preuve-calcul` | 0,96 Go | Coq et CoqIDE, Scilab, RStudio, outils de développement R |
  | `bibliotheque` | 0,44 Go | 13 livres L3 à M2, documentation de Python, SymPy, R, Singular, Git et des extensions LaTeX |
  | `encyclopedie` | 0,80 Go | Wikipédia en français hors ligne (mathématiques, informatique, physique), lue avec Kiwix |

- **Persistance sur clé USB** : `matos-persistance` (menu **Conserver mes fichiers sur la clé**)
  crée une partition dans la place libre de la clé ; fichiers, réglages et modules installés
  sont alors gardés d'un démarrage à l'autre, sans installer matOS.
- **Bibliothèque rangée par niveau** (L1, L2, Outils dans l'ISO ; L3 et M1-M2 dans le module),
  avec *Linear Algebra Done Right*, *Think Stats*, *Scipy Lecture Notes*…
- **Outils pour enseignants** (`matos-enseignant`) : modèles LaTeX (cours, feuille de TD, sujet
  d'examen, diaporama) dans le dossier Modèles, et **Partage en salle** (`matos-partage`) pour
  distribuer un dossier aux ordinateurs du même réseau, sans Internet.
- **Geany** remplace VSCodium comme éditeur de code de l'image de base (quelques Mo de mémoire
  contre plusieurs centaines).
- `./build.sh --modules=…` et `--reprise` ; `scripts/test-iso.sh` démarre l'ISO dans QEMU sans
  écran (4 Go, processeur Core 2) et lit le rapport que la session écrit sur le port série.
- `telecharger-matos.sh --modules` télécharge et vérifie aussi les modules.

### Plus rapide sur une machine modeste
- Image système compressée par blocs de 256 Kio (1 Mio en 0.6) : lancer un logiciel depuis une
  clé ou un disque dur lit et décompresse quatre fois moins de données par accès.
- Ordonnanceur de disque BFQ pour les disques durs et les clés USB ; le démarrage n'attend
  plus le réseau (`NetworkManager-wait-online` masqué) ; réserves mémoire réglées pour zram.
- Module Lean compressé par blocs de 128 Kio : première compilation d'un projet en 45 s au
  lieu de 250 s avec 4 Go de RAM.
- Mesuré dans QEMU (4 Go, Core 2, deux cœurs) : session de bureau complète 45 s après le lancement, dont 10 s de démarrage du système.

### Plus léger
- Traductions limitées au français, à l'anglais et au malgache ; documentation de TeX Live,
  pages de manuel anglaises et aides inutilisées exclues à l'installation des paquets.
- Dépendances seulement « recommandées » et lourdes bloquées pendant la construction
  (Java, LLVM, Node.js, firmwares de cartes NVIDIA et de serveurs) ; ces blocages ne restent
  pas dans le système installé, et le build le vérifie.

### Corrections
- `/etc/os-release` identifiait le système comme Debian : c'est maintenant matOS, et le test
  de l'ISO le contrôle.
- **L'écran ne se verrouille plus en session live.**
- **Dates en français par défaut** dans l'installateur (elles passaient en malgache avec le
  fuseau de Madagascar). Pour des dates en malgache après l'installation :
  `sudo dpkg-reconfigure locales`.
- **« Effacer le disque » présélectionné**, sans partition d'échange (zram suffit).
- L'image d'accueil de l'installateur n'affiche plus un numéro de version périmé.
- Le modèle de cours LaTeX compile (il manquait `xcolor`) ; le build compile désormais tous
  les modèles.

### Limites connues
- Un module qui installe des paquets (`lean`, `preuve-calcul`) demande de la place : en session
  live sans persistance, `matos-modules` refuse avec un message clair plutôt que d'échouer à
  moitié. Utiliser la persistance ou installer matOS.
- Les adresses de quelques livres sont « glissantes » (le PDF change sans changer d'adresse) :
  la construction échoue alors sur l'empreinte ; un miroir des sources est à prévoir.
- Toujours aucun test sur du vrai matériel.

---

## [0.6] — RALAMBO *(novembre 2026)*

### Pourquoi une reconstruction complète
Les essais précédents de la 0.6 ne démarraient pas ou étaient incomplets :
- l'ISO remasterisée depuis la 0.5 avait perdu ses enregistrements de boot
  (El Torito) : ni BIOS ni UEFI ne pouvaient la démarrer ;
- les builds mkosi et Podman installaient `sagemath`, retiré de Debian 13, en
  ignorant les erreurs (`|| true`) : aucun logiciel mathématique n'était installé ;
- le thème Plymouth n'avait pas d'images et le branding Calamares référençait un
  `welcome.png` absent ;
- les lanceurs « Bienvenue » et « Visite » appelaient des outils MX Linux absents.

### Ruptures
- **Base** : MX Linux 23 (Debian 12) → **Debian 13 « Trixie »**, construite avec
  **live-build** dans un conteneur `debian:trixie` (`./build.sh`).
- **Installateur** : gazelle-installer → **Calamares** (configuration dérivée de
  celle de Debian), installation entièrement hors ligne.
- **Sécurité** : plus de mot de passe root en clair ; l'utilisateur créé à
  l'installation est administrateur via `sudo`.
- **Audio** : PulseAudio → PipeWire.

### Nouveau
- **SageMath 10.9** et pile Python scientifique (NumPy, SciPy, SymPy, Matplotlib,
  pandas, scikit-learn, statsmodels, NetworkX, Manim, JupyterLab), environnement
  conda-forge figé paquet par paquet dans `/opt/matos/sagemath`.
- **Lean 4 + Mathlib précompilée**, hors ligne ; `matos-lean-projet` crée un projet.
- **GeoGebra Classic 6** (Debian ne fournit que la 4.0), **VSCodium** avec
  extensions Lean, LaTeX, Python, Jupyter, **RStudio**.
- Octave, Scilab, Kig, Xcas, Coq/CoqIDE, LibreOffice, TeXstudio.
- **Bibliothèque** de 23 livres libres sur le bureau (Exo7, Lebl, Levin, Open Logic,
  Grinstead & Snell, MIT *Mathematics for Computer Science*, Erickson, SICP, Pro Git,
  *Mathematics in Lean*…). Chaque livre a une licence libre vérifiée dans son texte
  (`scripts/livre-verifier.sh`) et un SHA256 figé.
- **Documentation hors ligne** (Python, R, Maxima, Octave, Coq, Git, LibreOffice…).
- **ISO de 8,3 Go** (9,99 Go avant allègement) : SageMath en cœur + extras réinstallables
  (`matos-sage-extras`), RStudio sans LLVM, firmwares de serveurs retirés, zstd 22.
- **Machines modestes** : zram, earlyoom, composition coupée automatiquement à 4 Go,
  démarrage UEFI 32 bits sur processeur 64 bits. 64 bits uniquement.
- Page de **bienvenue** hors ligne, dédiée au Professeur Ralambo.
- Thème **MatOS-Dark** (sur Greybird-dark), icônes Papirus, curseur Bibata,
  polices IBM Plex, fonds d'écran mathématiques, écrans de démarrage GRUB et
  Plymouth (avec saisie de phrase de passe pour les disques chiffrés).
- Menu **Mathématiques**, swap compressé **zram**.
- **Statistiques anonymes** désactivables : au plus un envoi par jour de la
  version, du mode live/installé, de la langue et du pays du fuseau horaire,
  sans identifiant.
- Dépôt APT matOS signé optionnel pour les mises à jour des paquets `matos-*`.

### Robustesse
- Toute ressource téléchargée a une version et un SHA256 (`versions.env`).
- Personnalisations livrées en paquets `.deb` : `/etc/xdg/matos`, `dpkg-divert`,
  fichiers *drop-in* ; aucune mise à jour Debian ne les écrase.
- Le build échoue si un logiciel attendu manque (hook de vérification), et teste
  SageMath et Lean en utilisateur sans droits.

---

## [0.5] — Archimedes *(avril 2024)*
- Version initiale basée sur MX Linux 23 Xfce (Debian 12 Bookworm)
- SageMath, GAP, PARI/GP, Singular, Maxima, R, TeX Live, GeoGebra
- Installateur gazelle-installer personnalisé
- Ressources PDF (algèbre, analyse, géométrie, LaTeX, SageMath)
- Logo et fond d'écran torus.png personnalisés
