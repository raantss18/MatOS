#!/bin/bash
# Construit l'ISO matOS. Exécuté en root dans un conteneur debian:trixie
# (lancé par build.sh), le dépôt étant monté sur /matos.
# Option --paquets : s'arrêter après la construction des paquets matos-*.

. "$(dirname "$0")/lib.sh"

export DEBIAN_FRONTEND=noninteractive
[ "$(id -u)" = 0 ] || die "à exécuter en root"

# ── Outils de build ─────────────────────────────────────────────────────
if [ -n "$DEBIAN_SNAPSHOT" ]; then
    mirror="http://snapshot.debian.org/archive/debian/$DEBIAN_SNAPSHOT"
    security_mirror="http://snapshot.debian.org/archive/debian-security/$DEBIAN_SNAPSHOT"
else
    mirror="$DEBIAN_MIRROR"
    security_mirror="$DEBIAN_SECURITY_MIRROR"
fi
cat > /etc/apt/sources.list.d/debian.sources <<EOF
Types: deb
URIs: $mirror
Suites: $DEBIAN_SUITE $DEBIAN_SUITE-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: $security_mirror
Suites: $DEBIAN_SUITE-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
[ -z "$DEBIAN_SNAPSHOT" ] || echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/90snapshot
apt-get update
apt-get install -y --no-install-recommends \
    live-build debootstrap squashfs-tools xorriso mtools dosfstools \
    isolinux syslinux-common grub-pc-bin grub-efi-amd64-bin grub-efi-amd64-signed shim-signed \
    librsvg2-bin fonts-dejavu-core apt-utils dpkg-dev ca-certificates curl unzip xz-utils \
    zstd git util-linux build-essential polkitd pkexec

# ── 1. Paquets matOS ────────────────────────────────────────────────────
log "Étape 1/3 : paquets matOS"
rm -rf "$DEBS_DIR"
"$MATOS_ROOT/scripts/build-debs.sh"
if [ "${1:-}" = --paquets ]; then
    log "Paquets prêts dans build/debs (option --paquets : pas d'ISO)"
    exit 0
fi

# ── 2. Configuration live-build ─────────────────────────────────────────
log "Étape 2/3 : configuration live-build"
LB="$BUILD_DIR/live"
# Le cache de paquets de live-build survit d'un build à l'autre (gain de temps) ;
# build/lb-cache se supprime à la main pour repartir de zéro.
KEEP="$BUILD_DIR/lb-cache"
if [ -d "$LB/cache" ]; then rm -rf "$KEEP"; mv "$LB/cache" "$KEEP"; fi
if [ -d "$LB/chroot" ]; then umount -R "$LB/chroot/proc" "$LB/chroot/sys" "$LB/chroot/dev" 2>/dev/null || true; fi
rm -rf "$LB"; mkdir -p "$LB"
if [ -d "$KEEP" ]; then mv "$KEEP" "$LB/cache"; fi
cp -a "$MATOS_ROOT/live/config" "$LB/config"
mkdir -p "$LB/config/packages.chroot"
cp "$DEBS_DIR"/*.deb "$LB/config/packages.chroot/"
if compgen -G "$DEBS_DIR/matos-archive-keyring_*.deb" >/dev/null; then
    echo matos-archive-keyring > "$LB/config/package-lists/matos-depot.list.chroot"
fi

attendus="$LB/config/includes.chroot_after_packages/usr/share/matos/paquets-attendus"
mkdir -p "$(dirname "$attendus")"
if [ "${MATOS_SKIP_HEAVY:-0}" = 1 ]; then
    rm "$LB/config/package-lists/matos-lourds.list.chroot"
    : > "$attendus"
else
    grep -v '^#' "$MATOS_ROOT/live/config/package-lists/matos-lourds.list.chroot" | grep . > "$attendus"
fi

# Chargeurs d'amorçage : modèles de live-build + écran matOS
cp -a /usr/share/live/build/bootloaders "$LB/config/bootloaders"
cp "$MATOS_ROOT/live/bootloaders/splash.svg" "$LB/config/bootloaders/splash.svg"

image="matos-$MATOS_VERSION-$MATOS_CODENAME"
live_params="boot=live components quiet splash locales=fr_FR.UTF-8 keyboard-layouts=fr timezone=Indian/Antananarivo"

cd "$LB"
lb config noauto \
    --mode debian \
    --distribution "$DEBIAN_SUITE" \
    --architectures amd64 \
    --linux-flavours amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --mirror-bootstrap "$mirror" \
    --mirror-chroot "$mirror" \
    --mirror-chroot-security "$security_mirror" \
    --mirror-binary "$DEBIAN_MIRROR" \
    --mirror-binary-security "$DEBIAN_SECURITY_MIRROR" \
    --security true --updates true \
    --apt-recommends true \
    --debian-installer none \
    --binary-images iso-hybrid \
    --bootloaders "syslinux grub-efi" \
    --uefi-secure-boot enable \
    --firmware-chroot true --firmware-binary true \
    # zstd niveau 22, blocs de 1 Mio : -6 % par rapport à (19, 128 Kio), même vitesse de lecture
    # (mesuré sur les vraies données) ; les options passent telles quelles à mksquashfs
    --chroot-squashfs-compression-type "zstd -b 1M" \
    --chroot-squashfs-compression-level 22 \
    --checksums sha256 \
    --memtest none \
    --cache-packages true \
    --image-name "$image" \
    --iso-application "$MATOS_NAME $MATOS_VERSION" \
    --iso-publisher "matOS ; $MATOS_URL" \
    --iso-volume "MATOS_${MATOS_VERSION//./_}" \
    --bootappend-live "$live_params" \
    --bootappend-live-failsafe "boot=live components noapic noapm nodma nomce nosmp nosplash vga=788 nomodeset"

# ── 3. Construction ─────────────────────────────────────────────────────
log "Étape 3/3 : lb build (long : 1 à 3 h selon la machine et le réseau)"
lb build 2>&1 | tee "$BUILD_DIR/lb-build.log"
[ "${PIPESTATUS[0]}" = 0 ] || die "lb build a échoué (voir build/lb-build.log)"

# live-build ajoute lui-même « -amd64 » au nom de l'image
iso="$LB/$image-amd64.hybrid.iso"
[ -f "$iso" ] || die "ISO absente après lb build"
mkdir -p "$MATOS_ROOT/out"
mv "$iso" "$MATOS_ROOT/out/"
(cd "$MATOS_ROOT/out" && sha256sum "$image-amd64.hybrid.iso" > "$image-amd64.hybrid.iso.sha256")
cp "$LB/chroot/usr/share/matos/paquets.txt" "$MATOS_ROOT/out/$image-amd64.paquets.txt"
log "ISO prête : out/$image-amd64.hybrid.iso"
