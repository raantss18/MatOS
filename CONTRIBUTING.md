# Contribuer à matOS

Merci de vouloir aider ! Pas besoin d'être développeur : tester, traduire, recommander des livres libres et corriger la documentation comptent autant que le code.

- **Une question, une idée, un retour d'expérience** : [Discussions](https://github.com/raantss18/MatOS/discussions).
- **Un problème** : [nouveau signalement](https://github.com/raantss18/MatOS/issues/new/choose).
- **Une machine testée** : [rapport de compatibilité](https://github.com/raantss18/MatOS/issues/new?template=compatibilite.yml).

## Proposer une modification

1. Créez une branche, faites vos changements, **testez-les** (voir ci-dessous).
2. Ouvrez une *pull request* qui dit ce que vous avez changé, pourquoi, et comment vous l'avez testé.
3. Une modification par pull request, de préférence.

## Règles du projet

- **Le build échoue plutôt que de produire une image incomplète** : pas de `|| true` sur une installation.
- **Tout ce qui est téléchargé a une version et un SHA256** dans `versions.env` (jamais « latest »).
- **Les personnalisations sont des paquets `matos-*`** et ne modifient jamais les fichiers d'un autre paquet.
- **Un livre n'entre dans la bibliothèque que si sa licence libre est constatée dans le PDF** : `scripts/livre-verifier.sh`.
- **Dites ce qui est testé et ce qui ne l'est pas**, dans le code comme dans la documentation.

## Tester

- Documentation et site : `python3 scripts/generer-site.py --verifier` puis `python3 -m http.server -d site/public 8000`.
- Scripts : `bash -n` sur chaque script modifié.
- Image : `./build.sh --rapide` puis `./build.sh --test` (ISO sans SageMath ni Lean) ; voir la documentation « Construire et contribuer ».

Le projet est sous licence [GPL-3.0](LICENSE). En contribuant, vous acceptez que votre contribution soit publiée sous cette licence. Soyez courtois : [code de conduite](CODE_OF_CONDUCT.md).
