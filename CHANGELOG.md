# Changelog matOS

## [0.6] — RALAMBO *(en préparation)*

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
