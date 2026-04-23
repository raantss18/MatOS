#!/bin/bash
# build-iso.sh — Script de construction de l'ISO matOS RALAMBO (via Podman)
# Usage: sudo bash build-iso.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="/tmp/matos-build"
ROOT_DIR="$BUILD_DIR/rootfs"
ISO_DIR="$BUILD_DIR/iso"
OUTPUT="$SCRIPT_DIR/matos-ralambo.iso"
CONTAINER="matos-rootfs-$$"

echo "=== matOS RALAMBO — Construction de l'ISO (Podman) ==="
echo "Dossier projet : $SCRIPT_DIR"
echo "Dossier build  : $BUILD_DIR"

# ── Nettoyage ──────────────────────────────────────────────────────────
if [ -d "$BUILD_DIR" ]; then
    echo "Nettoyage du build précédent..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$ROOT_DIR" "$ISO_DIR/live" "$ISO_DIR/boot/grub"

# Nettoyer tout conteneur résiduel
podman rm -f "$CONTAINER" 2>/dev/null || true

# ── Étape 1 : Pull debian:trixie via Podman ───────────────────────────
echo ""
echo "=== Étape 1/6 : Pull debian:trixie ==="
podman pull docker.io/debian:trixie

# ── Étape 2–4 : Installation et configuration dans le conteneur ───────
echo ""
echo "=== Étapes 2-4/6 : Installation des paquets et personnalisation ==="

# Préparer l'archive avec les fichiers de personnalisation
EXTRA_TAR="$BUILD_DIR/extra.tar"
tar -cf "$EXTRA_TAR" -C "$SCRIPT_DIR" mkosi.extra mkosi.postinst

podman run --name "$CONTAINER" \
    --privileged \
    --network=host \
    -e DEBIAN_FRONTEND=noninteractive \
    -v "$EXTRA_TAR:/tmp/extra.tar:ro" \
    -v "$SCRIPT_DIR/container-setup.sh:/tmp/container-setup.sh:ro" \
    docker.io/debian:trixie \
    bash /tmp/container-setup.sh

# ── Étape 5 : Export du rootfs ────────────────────────────────────────
echo ""
echo "=== Étape 5a/6 : Export du rootfs depuis le conteneur ==="
podman export "$CONTAINER" | tar -x -C "$ROOT_DIR"
podman rm "$CONTAINER"

# ── Régénérer l'initrd si absent (chroot avec proc/sys/dev montés) ───
if ! ls "$ROOT_DIR/boot/initrd.img-"* &>/dev/null; then
    echo "initrd absent — régénération via chroot..."
    mount -t proc proc "$ROOT_DIR/proc"
    mount -t sysfs sys "$ROOT_DIR/sys"
    mount -o bind /dev "$ROOT_DIR/dev"
    mount -o bind /dev/pts "$ROOT_DIR/dev/pts"
    chroot "$ROOT_DIR" update-initramfs -c -k all || \
    chroot "$ROOT_DIR" update-initramfs -u -k all || true
    umount -l "$ROOT_DIR/dev/pts" "$ROOT_DIR/dev" "$ROOT_DIR/sys" "$ROOT_DIR/proc" 2>/dev/null || true
fi
echo "Contenu /boot : $(ls "$ROOT_DIR/boot/")"

# ── Étape 5b : Création du squashfs et de la structure ISO ───────────
echo ""
echo "=== Étape 5b/6 : Création du squashfs ==="
echo "Création du squashfs (compression xz)..."
mksquashfs "$ROOT_DIR" "$ISO_DIR/live/filesystem.squashfs" \
    -comp xz -noappend \
    -e boot \
    2>&1 | tail -3

# Copier le noyau et initrd
KERNEL_VER=$(ls "$ROOT_DIR/boot/vmlinuz-"* 2>/dev/null | head -1 | xargs basename | sed 's/vmlinuz-//')
echo "Noyau détecté : $KERNEL_VER"
cp "$ROOT_DIR/boot/vmlinuz-$KERNEL_VER" "$ISO_DIR/live/vmlinuz"
cp "$ROOT_DIR/boot/initrd.img-$KERNEL_VER" "$ISO_DIR/live/initrd.img"

# ── Étape 6 : Création du GRUB et de l'ISO ────────────────────────────
echo ""
echo "=== Étape 6/6 : Création de l'ISO avec GRUB ==="

if [ -d "$ROOT_DIR/usr/share/MatOS/background" ]; then
    mkdir -p "$ISO_DIR/boot/grub/themes/matos"
    cp "$ROOT_DIR/usr/share/MatOS/background/grub1.png" \
       "$ISO_DIR/boot/grub/themes/matos/" 2>/dev/null || true
fi

cat > "$ISO_DIR/boot/grub/grub.cfg" << 'GRUBEOF'
set default=0
set timeout=10
set gfxmode=1024x768
set gfxpayload=keep

insmod all_video
insmod gfxterm
insmod png
terminal_output gfxterm

menuentry "matOS RALAMBO 0.6 (Live)" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}

menuentry "matOS RALAMBO 0.6 (Safe mode)" {
    linux /live/vmlinuz boot=live nomodeset
    initrd /live/initrd.img
}

menuentry "Installer matOS RALAMBO sur disque" {
    linux /live/vmlinuz boot=live quiet splash calamares
    initrd /live/initrd.img
}
GRUBEOF

echo "Génération de l'ISO finale..."
grub-mkrescue -o "$OUTPUT" "$ISO_DIR" \
    --compress=xz 2>&1 | tail -5

echo ""
echo "=== Construction terminée ! ==="
ls -lh "$OUTPUT"
echo ""
echo "Pour tester : sudo qemu-system-x86_64 -m 4G -enable-kvm -cdrom $OUTPUT"
