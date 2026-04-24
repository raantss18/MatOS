#!/bin/bash
# build-iso-remaster.sh — Remaster matOS 0.5→0.6 à partir de l'ISO fonctionnelle
# Usage: sudo bash build-iso-remaster.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OLD_ISO="/home/raantss/Documents/GitHub/MatOS/MatOS-0.5-Archimedes.iso"
WORK_DIR="/home/raantss/matos-remaster"
ROOT_DIR="$WORK_DIR/rootfs"
ISO_MNT="$WORK_DIR/iso-mnt"
OUTPUT="$SCRIPT_DIR/matos-ralambo-0.6.iso"

echo "=== matOS RALAMBO 0.6 — Remaster de l'ISO fonctionnelle ==="
echo "Source : $OLD_ISO"
echo "Sortie : $OUTPUT"

# ── Nettoyage ──────────────────────────────────────────────────────────
for mnt in "$ROOT_DIR/dev/pts" "$ROOT_DIR/dev" "$ROOT_DIR/proc" "$ROOT_DIR/sys" "$ROOT_DIR/run" "$ISO_MNT"; do
    umount -l "$mnt" 2>/dev/null || true
done
rm -rf "$ROOT_DIR"
mkdir -p "$ROOT_DIR" "$ISO_MNT"

# ── Étape 1 : Monter et extraire le filesystem de l'ancienne ISO ───────
echo ""
echo "=== Étape 1/6 : Extraction du filesystem ==="
mount -o loop,ro "$OLD_ISO" "$ISO_MNT"
echo "Extraction du squashfs (12 Go, ~10-15 min)..."
unsquashfs -d "$ROOT_DIR" "$ISO_MNT/antiX/linuxfs"
echo "Extraction terminée."

# ── Étape 2 : Préparer le chroot ───────────────────────────────────────
echo ""
echo "=== Étape 2/6 : Préparation du chroot ==="
mount -t proc proc "$ROOT_DIR/proc"
mount -t sysfs sys "$ROOT_DIR/sys"
mount -o bind /dev "$ROOT_DIR/dev"
mount -o bind /dev/pts "$ROOT_DIR/dev/pts"
mount -o bind /run "$ROOT_DIR/run"
cp /etc/resolv.conf "$ROOT_DIR/etc/resolv.conf"

# Empêcher le démarrage de services pendant l'install
cat > "$ROOT_DIR/usr/sbin/policy-rc.d" << 'POLICY'
#!/bin/sh
exit 101
POLICY
chmod +x "$ROOT_DIR/usr/sbin/policy-rc.d"

# ── Corriger les sources APT (HTTP → HTTPS, désactiver incompatibles) ──
sed -i 's|http://deb.debian.org|https://deb.debian.org|g
        s|http://security.debian.org|https://security.debian.org|g' \
    "$ROOT_DIR/etc/apt/sources.list.d/debian.list" \
    "$ROOT_DIR/etc/apt/sources.list.d/debian-stable-updates.list" 2>/dev/null || true
sed -i 's|http://mirrors.rit.edu/mxlinux|https://mirrors.rit.edu/mxlinux|g' \
    "$ROOT_DIR/etc/apt/sources.list.d/mx.list" 2>/dev/null || true
for f in cubic-wizard-release.list vivaldi.list; do
    [ -f "$ROOT_DIR/etc/apt/sources.list.d/$f" ] && \
    mv "$ROOT_DIR/etc/apt/sources.list.d/$f" \
       "$ROOT_DIR/etc/apt/sources.list.d/$f.disabled" 2>/dev/null || true
done
cat > "$ROOT_DIR/etc/apt/apt.conf.d/99-matos-build" << 'APTCONF'
Acquire::ForceIPv4 "true";
Acquire::Retries "10";
Acquire::https::Verify-Peer "false";
Acquire::https::Verify-Host "false";
APTCONF

# ── Étape 3 : Mise à jour des paquets ──────────────────────────────────
echo ""
echo "=== Étape 3/6 : Mise à jour des paquets (peut prendre 30-60 min) ==="
export DEBIAN_FRONTEND=noninteractive

chroot "$ROOT_DIR" apt-get update
chroot "$ROOT_DIR" apt-get upgrade -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    2>&1 | grep -E "^(Get:|Unpacking|Setting up|E:|Err:)" || true

# ── Étape 4 : Ajout des paquets manquants ─────────────────────────────
echo ""
echo "=== Étape 4/6 : Installation des paquets supplémentaires ==="

# Mises à jour et ajouts pour la version 0.6
chroot "$ROOT_DIR" apt-get install -y \
    gnuplot-x11 \
    fonts-noto-color-emoji \
    python3-matplotlib python3-mpmath python3-sympy \
    cython3 \
    ecl eclib-tools \
    mathpiper \
    gap-atlasrep gap-table-of-marks gap-smallgrp gap-transgrp \
    gap-alnuth gap-autpgrp gap-utils \
    fflas-ffpack fflas-ffpack-common \
    coinor-libcbc3 coinor-libcgl1 coinor-libclp1 \
    coinor-libcoinmp1v5 coinor-libcoinutils3v5 coinor-libosi1v5 \
    flintqs \
    r-cran-foreign r-cran-boot r-cran-class r-cran-cluster \
    r-cran-codetools r-cran-kernsmooth r-cran-lattice \
    r-cran-mass r-cran-matrix r-cran-mgcv r-cran-nlme \
    r-cran-nnet r-cran-rpart r-cran-spatial r-cran-survival \
    texlive-lang-greek biber preview-latex-style \
    default-jre default-jre-headless \
    gfortran cargo \
    python3-cysignals-pari \
    2>&1 | grep -E "^(Get:|Unpacking|Setting up|E:|Err:)" || true

# Vérifier et réinstaller sagemath si besoin (version la plus récente bookworm)
chroot "$ROOT_DIR" apt-get install -y --reinstall sagemath 2>&1 | tail -3 || true

# ── Étape 5 : Personnalisation matOS RALAMBO ───────────────────────────
echo ""
echo "=== Étape 5/6 : Personnalisation ==="

# Hostname
echo "matos" > "$ROOT_DIR/etc/hostname"
sed -i "s/127\.0\.1\.1.*/127.0.1.1\tmatos/" "$ROOT_DIR/etc/hosts" 2>/dev/null || \
    echo "127.0.1.1 matos" >> "$ROOT_DIR/etc/hosts"

# Mot de passe root
echo "root:MOT_DE_PASSE_SUPPRIME" | chroot "$ROOT_DIR" chpasswd

# Créer l'utilisateur matos (en plus de demo)
if ! chroot "$ROOT_DIR" id matos &>/dev/null; then
    chroot "$ROOT_DIR" useradd -m -s /bin/bash \
        -G sudo,audio,video,plugdev,netdev,cdrom,floppy,dialout matos
fi
echo "matos:matos" | chroot "$ROOT_DIR" chpasswd

# Configurer autologin LightDM sur matos
mkdir -p "$ROOT_DIR/etc/lightdm/lightdm.conf.d/"
cat > "$ROOT_DIR/etc/lightdm/lightdm.conf.d/50-matos.conf" << 'EOF'
[Seat:*]
autologin-user=matos
autologin-user-timeout=0
user-session=xfce
EOF

# Appliquer les personnalisations matOS (thèmes, logos, etc.)
if [ -d "$SCRIPT_DIR/mkosi.extra" ]; then
    rsync -a "$SCRIPT_DIR/mkosi.extra/" "$ROOT_DIR/" 2>/dev/null || true
fi

# Mettre à jour /etc/os-release avec le branding RALAMBO
cat > "$ROOT_DIR/etc/os-release" << 'EOF'
PRETTY_NAME="matOS RALAMBO 0.6 (Debian Bookworm)"
NAME="matOS"
VERSION_ID="0.6"
VERSION="0.6 (RALAMBO)"
VERSION_CODENAME=ralambo
ID=matos
ID_LIKE=debian
HOME_URL="https://github.com/raantss18/MatOS"
SUPPORT_URL="https://github.com/raantss18/MatOS/issues"
BUG_REPORT_URL="https://github.com/raantss18/MatOS/issues"
EOF

# ── Nettoyage avant squashfs ───────────────────────────────────────────
chroot "$ROOT_DIR" apt-get clean
chroot "$ROOT_DIR" apt-get autoremove -y 2>/dev/null || true
rm -f "$ROOT_DIR/usr/sbin/policy-rc.d"
rm -f "$ROOT_DIR/etc/resolv.conf"
rm -rf "$ROOT_DIR/tmp/"* "$ROOT_DIR/var/tmp/"* 2>/dev/null || true
rm -f "$ROOT_DIR/var/cache/apt/archives/"*.deb 2>/dev/null || true

# Démonter les systèmes virtuels
for fs in dev/pts dev proc sys run; do
    umount -l "$ROOT_DIR/$fs" 2>/dev/null || true
done

# ── Générer la liste des paquets ───────────────────────────────────────
PKG_LIST="$WORK_DIR/package_list"
chroot "$ROOT_DIR" dpkg-query -W --showformat='${Package}\t${Version}\n' | \
    column -t > "$PKG_LIST" 2>/dev/null || \
    chroot "$ROOT_DIR" dpkg -l | awk '/^ii/{printf "%-45s %s\n", $2, $3}' > "$PKG_LIST"

# ── Étape 5b : Nouveau squashfs ────────────────────────────────────────
echo ""
echo "=== Étape 5b/6 : Création du squashfs (compression xz, ~20-30 min) ==="
NEW_LINUXFS="$WORK_DIR/linuxfs"
mksquashfs "$ROOT_DIR" "$NEW_LINUXFS" \
    -comp xz -noappend \
    -e boot \
    2>&1 | tail -5
echo "Taille du squashfs : $(ls -lh "$NEW_LINUXFS" | awk '{print $5}')"

# ── Étape 6 : Création de l'ISO avec le même format antiX ─────────────
echo ""
echo "=== Étape 6/6 : Création de l'ISO finale ==="

# Préparer le GRUB mis à jour
GRUB_CFG="$WORK_DIR/grub.cfg"
sed 's/MatOS 0.5 Archimedes.*x64/matOS RALAMBO 0.6 x64/g
     s/MatOS-MatOS 0.5 Archimedes/matOS RALAMBO 0.6/g
     s/avril 10, 2024/avril 2026/g' \
    "$ISO_MNT/boot/grub/grub.cfg" > "$GRUB_CFG"

# Créer la nouvelle ISO en remplaçant linuxfs, grub.cfg et package_list
xorriso \
    -indev "$OLD_ISO" \
    -outdev "$OUTPUT" \
    -volid "MATOS_RALAMBO_0.6" \
    -map "$NEW_LINUXFS" /antiX/linuxfs \
    -map "$GRUB_CFG" /boot/grub/grub.cfg \
    -mkdir /MatOS-0.6-Ralambo \
    -map "$PKG_LIST" /MatOS-0.6-Ralambo/package_list \
    -commit 2>&1 | tail -10

# Calculer MD5 du nouveau squashfs
echo ""
md5sum "$NEW_LINUXFS" | awk '{print $1}' | \
    xorriso -indev "$OUTPUT" -outdev "$OUTPUT" \
    -overwrite on \
    -commit 2>/dev/null || true

# Démonter l'ancienne ISO
umount "$ISO_MNT" 2>/dev/null || true

echo ""
echo "=== Construction terminée ! ==="
ls -lh "$OUTPUT"
echo ""
echo "Pour tester : qemu-system-x86_64 -m 4G -enable-kvm -cdrom $OUTPUT"
