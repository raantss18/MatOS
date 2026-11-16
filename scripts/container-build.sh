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
LB="$BUILD_DIR/live"
image="matos-$MATOS_VERSION-$MATOS_CODENAME"
lb_etape() {
    lb "$1" 2>&1 | tee -a "$BUILD_DIR/lb-build.log"
    [ "${PIPESTATUS[0]}" = 0 ] || die "lb $1 a échoué (voir build/lb-build.log)"
}
# Reprise (./build.sh --reprise) : le système de base d'un build précédent est gardé tel quel,
# seuls les modules demandés et l'image sont refaits. Sert quand un module ou « lb binary »
# a échoué : à ne pas utiliser après une modification des paquets ou de live/config.
if [ "${MATOS_REPRISE:-0}" = 1 ]; then
    [ -f "$LB/.build/chroot_hooks" ] && [ -f "$LB/chroot/usr/share/matos/modules/catalogue" ] \
        || die "reprise impossible : pas de système de base complet dans build/live (relancer sans --reprise)"
    log "Reprise : étapes 1 à 3 gardées du build précédent"
    cd "$LB"
else

log "Étape 1/5 : paquets matOS"
rm -rf "$DEBS_DIR"
"$MATOS_ROOT/scripts/build-debs.sh"
if [ "${1:-}" = --paquets ]; then
    log "Paquets prêts dans build/debs (option --paquets : pas d'ISO)"
    exit 0
fi

# ── 2. Configuration live-build ─────────────────────────────────────────
log "Étape 2/5 : configuration live-build"
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
    rm "$LB/config/package-lists/matos-sagemath.list.chroot"
    : > "$attendus"
else
    grep -v '^#' "$MATOS_ROOT/live/config/package-lists/matos-sagemath.list.chroot" | grep . > "$attendus"
fi

# Chargeurs d'amorçage : modèles de live-build + écran matOS
cp -a /usr/share/live/build/bootloaders "$LB/config/bootloaders"
cp "$MATOS_ROOT/live/bootloaders/splash.svg" "$LB/config/bootloaders/splash.svg"

# « persistence » : sans effet tant que la clé n'a pas de partition de ce nom (matos-persistance)
live_params="boot=live components persistence quiet splash locales=fr_FR.UTF-8 keyboard-layouts=fr timezone=Indian/Antananarivo"

cd "$LB"
# Squashfs : zstd niveau 22. Blocs de 256 Kio pour le système : lancer un logiciel lit de
# petits morceaux un peu partout, et chaque lecture décompresse un bloc entier ; avec 1 Mio,
# un disque dur ou une clé USB lente et 4 Go de RAM le paient à chaque démarrage d'application.
# Les modules, lus en grands morceaux, gardent 1 Mio (scripts/build-modules.sh).
# Le « type » est passé tel quel à mksquashfs.
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
    --firmware-chroot false --firmware-binary false \
    --chroot-squashfs-compression-type "zstd -b ${MATOS_SQUASHFS_BLOCK:-256K}" \
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

# ── 3. Système de base (chroot) ─────────────────────────────────────────
log "Étape 3/5 : système de base (lb bootstrap, lb chroot)"
: > "$BUILD_DIR/lb-build.log"
lb_etape bootstrap
lb_etape chroot
# Les épinglages de construction ne doivent pas rester dans le système installé
if grep -rqs 'Pin-Priority: -1' "$LB/chroot/etc/apt/preferences" "$LB/chroot/etc/apt/preferences.d"; then
    die "des épinglages de construction sont restés dans l'image (/etc/apt/preferences.d)"
fi
: > "$BUILD_DIR/catalogue"

fi  # fin des étapes sautées par la reprise

# ── 4. Modules hors ligne ───────────────────────────────────────────────
# Construits ici : leurs dépôts se calculent par rapport aux paquets du chroot, et leurs
# empreintes entrent dans le catalogue de l'image avant sa compression.
log "Étape 4/5 : modules hors ligne (${MATOS_MODULES-tous})"
if [ "${MATOS_MODULES-tous}" = tous ]; then
    "$MATOS_ROOT/scripts/build-modules.sh"
elif [ -n "$MATOS_MODULES" ]; then
    # shellcheck disable=SC2086
    "$MATOS_ROOT/scripts/build-modules.sh" $MATOS_MODULES
fi
catalogue="$LB/chroot/usr/share/matos/modules/catalogue"
[ -f "$catalogue" ] || die "catalogue des modules absent du chroot (paquet matos-modules ?)"
# réécrit (et non complété) : une reprise ne doit pas doubler les lignes
{ grep '^#' "$catalogue" || true; cat "$BUILD_DIR/catalogue"; } > "$catalogue.nouveau"
mv "$catalogue.nouveau" "$catalogue"
mkdir -p "$MATOS_ROOT/out/modules"
cp "$catalogue" "$MATOS_ROOT/out/modules/catalogue"

# ── 5. Image ISO ────────────────────────────────────────────────────────
log "Étape 5/5 : lb binary (compression de l'image : long)"
lb_etape binary

# live-build ajoute lui-même « -amd64 » au nom de l'image
iso="$LB/$image-amd64.hybrid.iso"
[ -f "$iso" ] || die "ISO absente après lb build"
mkdir -p "$MATOS_ROOT/out"
mv "$iso" "$MATOS_ROOT/out/"
(cd "$MATOS_ROOT/out" && sha256sum "$image-amd64.hybrid.iso" > "$image-amd64.hybrid.iso.sha256")
cp "$LB/chroot/usr/share/matos/paquets.txt" "$MATOS_ROOT/out/$image-amd64.paquets.txt"
log "ISO prête : out/$image-amd64.hybrid.iso"
