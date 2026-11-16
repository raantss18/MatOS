#!/bin/bash
# Démarre l'ISO matOS dans QEMU sans affichage, sur une machine modeste simulée, et lit le
# rapport que la session live écrit sur le port série (paquet matos-base, matos-test-rapport).
#
# Usage : scripts/test-iso.sh [ISO] [--modules]
#   --modules   installe aussi dans la session les modules de out/modules/ et les essaie
#
# Réglages : MATOS_TEST_MEM (4G), MATOS_TEST_CPU (Conroe : génération Core 2, sans AVX),
#            MATOS_TEST_SMP (2), MATOS_TEST_DELAI (900 secondes).
# Hôte : qemu-system-x86_64 (KVM) et bsdtar. Le noyau est lancé directement pour pouvoir lui
# passer « matos.test » : ce test ne couvre donc pas le chargeur d'amorçage (./build.sh --test).
set -euo pipefail

cd "$(dirname "$0")/.."
. ./versions.env

iso="out/matos-$MATOS_VERSION-$MATOS_CODENAME-amd64.hybrid.iso"
avec_modules=0
for a in "$@"; do
    case "$a" in --modules) avec_modules=1 ;; *) iso=$a ;; esac
done
[ -f "$iso" ] || { echo "ISO absente : $iso" >&2; exit 1; }

work=$(mktemp -d)
trap 'kill "$pid" 2>/dev/null || true; rm -rf "$work"' EXIT
pid=""
bsdtar -xf "$iso" -C "$work" 'live/vmlinuz*' 'live/initrd*'
noyau=$(find "$work/live" -name 'vmlinuz*' | sort | tail -n 1)
initrd=$(find "$work/live" -name 'initrd*' | sort | tail -n 1)
[ -f "$noyau" ] && [ -f "$initrd" ] || { echo "noyau ou initrd introuvable dans l'ISO" >&2; exit 1; }

params="boot=live components quiet locales=fr_FR.UTF-8 keyboard-layouts=fr timezone=Indian/Antananarivo"
params="$params console=tty0 console=ttyS0 matos.test=arret"
partage=()
if [ "$avec_modules" = 1 ]; then
    compgen -G 'out/modules/*.matmod' >/dev/null || { echo "aucun module dans out/modules" >&2; exit 1; }
    params="$params matos.test.modules"
    partage=(-virtfs "local,path=$PWD/out/modules,mount_tag=modules,security_model=none,readonly=on")
fi

serie="$work/serie.log"; : > "$serie"
qemu-system-x86_64 -enable-kvm -cpu "${MATOS_TEST_CPU:-Conroe}" -smp "${MATOS_TEST_SMP:-2}" \
    -m "${MATOS_TEST_MEM:-4G}" -kernel "$noyau" -initrd "$initrd" -append "$params" \
    -cdrom "$iso" -vga std -display none -serial "file:$serie" \
    -nic none "${partage[@]}" &
pid=$!

delai=${MATOS_TEST_DELAI:-900}; debut=$(date +%s)
until grep -q 'MATOS-RAPPORT-FIN' "$serie"; do
    kill -0 "$pid" 2>/dev/null || break
    if [ $(( $(date +%s) - debut )) -ge "$delai" ]; then
        echo "ÉCHEC : pas de rapport après $delai s. Fin de la console série :" >&2
        tail -n 30 "$serie" >&2
        exit 1
    fi
    sleep 5
done
rapport=$(sed -n '/MATOS-RAPPORT-DEBUT/,/MATOS-RAPPORT-FIN/p' "$serie" | tr -d '\r')
[ -n "$rapport" ] || { echo "ÉCHEC : QEMU s'est arrêté sans rapport." >&2; tail -n 30 "$serie" >&2; exit 1; }
echo "$rapport"
echo "Durée jusqu'au rapport : $(( $(date +%s) - debut )) s (mémoire ${MATOS_TEST_MEM:-4G}, processeur ${MATOS_TEST_CPU:-Conroe})"

echec=0
verifier() { echo "$rapport" | grep -q "$1" || { echo "ÉCHEC : $2" >&2; echec=1; }; }
verifier '^identite=matos$'               "le système ne s'identifie pas comme matOS (/etc/os-release)"
verifier '^session=xfce$'                 "le bureau XFCE n'a pas démarré"
verifier '^services_en_echec= *$'         "des services systemd ont échoué"
verifier '^ecran_verrouillable=false$'    "le verrouillage d'écran est actif en session live"
verifier '^epinglages=0$'                 "des épinglages de construction sont restés dans l'image"
if echo "$rapport" | grep -q '=NON$'; then
    # SageMath est absent des ISO de test rapides : seul cas toléré
    if echo "$rapport" | grep '=NON$' | grep -vq '^commande_sage='; then
        echo "ÉCHEC : commandes absentes : $(echo "$rapport" | grep '=NON$' | tr '\n' ' ')" >&2; echec=1
    fi
fi
if [ "$avec_modules" = 1 ]; then
    verifier '^modules_test=ok$' "l'installation ou l'essai d'un module a échoué"
fi
[ "$echec" = 0 ] && echo "Test de l'ISO : réussi." || exit 1
