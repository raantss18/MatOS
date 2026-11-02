# Charte du site matOS

Site statique (GitHub Pages) : télécharger matOS, lire la documentation, échanger entre utilisateurs.
Principes : **léger** (connexions lentes), **sans dépendance externe** (ni police, ni bibliothèque, ni
suivi), **lisible hors JavaScript** (le JavaScript n'améliore que le téléchargement et le thème),
**accessible** (WCAG 2.1 AA), **français d'abord**.

## Jetons (`src/style.css`, variables CSS)

| Jeton | Sombre (défaut) | Clair | Usage |
|---|---|---|---|
| `--fond` | `#0D1B2A` | `#F4F7FA` | page |
| `--carte` | `#14263B` | `#FFFFFF` | cartes, code |
| `--texte` | `#F0F4F8` | `#0D1B2A` | texte courant |
| `--discret` | `#A9B8C8` | `#46566A` | texte secondaire |
| `--accent` | `#00C9A7` | `#00705F` | liens, focus, titres de section |
| `--sur-accent` | `#0D1B2A` | `#FFFFFF` | texte des boutons |
| `--bord` | `#27405B` | `#CBD5E1` | filets |

Contrastes calculés (WCAG) : tous ≥ 5,6:1 (texte courant ≥ 13,8:1). Le thème suit le système
(`prefers-color-scheme`) et peut être forcé par le bouton (mémorisé localement, sans cookie).

Typographie : pile système (`IBM Plex Sans` si installée, sinon `system-ui`) ; code en `IBM Plex Mono`
ou `ui-monospace`. Échelle fluide `clamp()`. Interligne 1,6. Largeur de lecture ≤ 70 caractères.
Espacements : multiples de 0,25 rem (`--e1` … `--e8`). Rayons : 8 px (cartes), 999 px (pastilles).

## Composants

| Composant | Variantes / états | Accessibilité |
|---|---|---|
| Bouton (`.btn`) | principal, secondaire ; survol, focus, actif | vrai `<a>` ou `<button>`, focus visible 3 px |
| Carte (`.carte`) | simple, lien (toute la carte cliquable) | titre en `h2`/`h3`, pas de texte seul en couleur |
| Bloc de code (`.code`) | avec bouton « Copier » (si JS) | `<pre>` sélectionnable ; le bouton annonce « Copié » (`aria-live`) |
| Encadré (`.note`) | info, attention | icône + libellé texte (jamais la couleur seule) |
| Étapes (`.etapes`) | numérotées | `<ol>`, compteur CSS |
| Tableau (`.tableau`) | défilant sur mobile | `<caption>`, `<th scope>` |
| Question (`<details>`) | repliée / dépliée | natif, accessible au clavier |
| Navigation | courante marquée `aria-current` | repères `<header>`, `<nav>`, `<main>`, `<footer>`, lien d'évitement |

## Règles de rédaction (UX copy)

- Phrases courtes, verbes d'action (« Télécharger », « Copier sur la clé »), « vous » ; pas de jargon sans explication.
- Un conseil par encadré. Dire **ce qui est testé** et **ce qui ne l'est pas** : jamais de promesse non vérifiée.
- Commandes toujours dans un bloc de code copiable ; une commande par bloc.
- Unités et noms exacts : « clé USB de 16 Go », « 4 Go de RAM », `sudo`, `bash`.

## Fabrication

`scripts/generer-site.py` assemble `src/pages/**/*.html` (fragments) dans `src/layout.html` et copie
`style.css`, `app.js` et `assets/` vers `site/public/` (non versionné). Aucun paquet à installer.
Le déploiement est fait par `.github/workflows/site.yml`.
