#!/bin/bash
# matOS — construction de l'ISO.
#
# Fonctionne sur n'importe quel Linux disposant de Docker ou Podman : le
# build se déroule dans un conteneur debian:trixie, l'hôte n'a besoin de
# rien d'autre. Résultat : out/matos-<version>-ralambo-amd64.hybrid.iso
#
# Usage :
#   ./build.sh            ISO complète (~10 Go, plusieurs heures)
#   ./build.sh --rapide   ISO de test sans SageMath ni Lean (bien plus rapide)
#   ./build.sh --paquets  construit seulement les paquets matos-* (build/debs)
#   ./build.sh --test     démarre l'ISO produite dans QEMU (UEFI si OVMF présent)
set -euo pipefail

cd "$(dirname "$0")"
MATOS_ROOT=$PWD
. ./versions.env

mode=iso
skip_heavy=0
for arg in "$@"; do
    case "$arg" in
        --rapide)  skip_heavy=1 ;;
        --paquets) mode=paquets ;;
        --test)    mode=test ;;
        -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "Option inconnue : $arg" >&2; exit 2 ;;
    esac
done

image="matos-$MATOS_VERSION-$MATOS_CODENAME-amd64"  # nom produit par live-build

if [ "$mode" = test ]; then
    iso="out/$image.hybrid.iso"
    [ -f "$iso" ] || { echo "Pas d'ISO : lancez d'abord ./build.sh" >&2; exit 1; }
    firmware=()
    for ovmf in /usr/share/edk2/x64/OVMF.4m.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/ovmf/OVMF.fd; do
        if [ -f "$ovmf" ]; then firmware=(-bios "$ovmf"); break; fi
    done
    exec qemu-system-x86_64 -enable-kvm -cpu host -smp 4 -m 6G \
        "${firmware[@]}" -cdrom "$iso" -boot d \
        -vga virtio -display gtk \
        -audiodev pa,id=snd -device intel-hda -device hda-duplex,audiodev=snd \
        -nic user,model=virtio-net-pci
fi

if command -v docker >/dev/null; then engine=docker
elif command -v podman >/dev/null; then engine=podman
else echo "Docker ou Podman est requis." >&2; exit 1
fi

script=/matos/scripts/container-build.sh
[ "$mode" = paquets ] && script="$script --paquets"

# --privileged : live-build monte /proc, /sys et des systèmes de fichiers
# temporaires dans son chroot. /opt/matos doit être le vrai chemin final
# (environnements conda et Lean non relogeables) : il reste dans le conteneur.
"$engine" run --rm --privileged \
    -v "$MATOS_ROOT:/matos" \
    -e MATOS_SKIP_HEAVY="$skip_heavy" \
    -e MATOS_ROOT=/matos \
    "docker.io/library/debian:$DEBIAN_SUITE" \
    bash -c "$script; status=\$?; mkdir -p /matos/out /matos/build/debs; \
             chown -R $(id -u):$(id -g) /matos/out /matos/build/debs; exit \$status"
