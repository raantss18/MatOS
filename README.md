# matOS RALAMBO

Distribution Linux orientée mathématiques, construite avec [mkosi](https://github.com/systemd/mkosi) à partir de Debian Bookworm.

matOS RALAMBO (v0.6) est la version reproductible et open-source de matOS, une distribution conçue pour l'enseignement et la recherche en mathématiques. Elle succède à **matOS 0.5 Archimedes**.

---

## Logiciels inclus

| Domaine | Logiciels |
|---|---|
| Calcul formel | SageMath 9.5, Maxima/wxMaxima, ECL, Coq |
| Théorie des groupes | GAP 4.12 (avec bibliothèques alnuth, polycyclic, primgrp…) |
| Théorie des nombres | PARI/GP 2.15, gp2c |
| Géométrie algébrique | Singular 4.3 |
| Géométrie interactive | GeoGebra, Gfan |
| Statistiques | R 4.2 + packages CRAN essentiels |
| Python scientifique | NumPy, SciPy, SymPy, Matplotlib, Jupyter |
| LaTeX | TeXLive 2022 (base + science + bibtex-extra + lang-greek) |
| Optimisation | COIN-OR (CBC, CLP, CGL…) |

---

## Prérequis

- Système hôte : Debian 12 / Ubuntu 24.04 ou ultérieur
- `mkosi` ≥ 20.0 : `sudo apt install mkosi`
- `systemd-container` : `sudo apt install systemd-container`
- Accès root (nécessaire pour la construction de l'image)

---

## Construction

```bash
git clone https://github.com/<votre-username>/matos.git
cd matos
sudo mkosi
```

L'image produite est `matos-ralambo.raw` (ou `matos-ralambo.raw.zst` si la compression est activée).

### Options utiles

```bash
sudo mkosi --force          # Reconstruction complète (supprime le cache)
sudo mkosi summary          # Affiche la configuration qui sera utilisée
sudo mkosi genkey           # Génère les clés pour le Secure Boot
```

---

## Test local

### Démarrage dans un conteneur systemd-nspawn

```bash
sudo systemd-nspawn -bi matos-ralambo.raw
```

Le système démarre en mode conteneur. Connexion : `matos` / `matos` (ou `root` / `matos`).

### Test en machine virtuelle QEMU

```bash
sudo mkosi qemu
```

---

## Structure du dépôt

```
matos/
├── mkosi.conf          ← Configuration principale (distribution, format, paquets de base)
├── mkosi.packages      ← Paquets supplémentaires (mathématiques, LaTeX, Python…)
├── mkosi.postinst      ← Script post-installation (utilisateur, autologin, locale)
├── mkosi.extra/        ← Arborescence superposée sur l'image finale
│   └── etc/
│       ├── skel/       ← Configuration utilisateur par défaut (XFCE, menus, ressources PDF)
│       └── xfce4/      ← Paramètres XFCE système
└── .github/
    └── workflows/
        └── build-iso.yml   ← CI/CD GitHub Actions
```

---

## Personnalisation

### Ajouter des paquets

Éditez `mkosi.packages` : un paquet par ligne, commentaires avec `#`.

### Modifier la configuration par défaut

Les fichiers dans `mkosi.extra/` sont copiés tels quels dans l'image. Pour modifier le bureau XFCE par défaut, éditez les fichiers dans `mkosi.extra/etc/skel/.config/xfce4/`.

### Changer le mot de passe par défaut

Éditez `mkosi.postinst` et modifiez la ligne `echo "matos:matos" | chpasswd`.

---

## GitHub Actions

Le workflow `.github/workflows/build-iso.yml` construit automatiquement l'image à chaque push sur `main`.

Pour déclencher manuellement :

```bash
gh workflow run build-iso.yml
```

Ou depuis l'interface GitHub : **Actions → Build matOS → Run workflow**.

---

## Origine

matOS RALAMBO est la suite directe de matOS 0.5 Archimedes, lui-même basé sur MX Linux 23 (antiX + Debian Bookworm + Xfce).

---

## Licence

[GPL-3.0](LICENSE) — Antsa Malala RANIRIAMANJAKA
