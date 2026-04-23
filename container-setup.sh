#!/bin/bash
# container-setup.sh — Exécuté DANS le conteneur Podman
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== [conteneur] Démarrage de la configuration ==="

# Empêcher le démarrage des services pendant l'install
cat > /usr/sbin/policy-rc.d << 'POLICY'
#!/bin/sh
exit 101
POLICY
chmod +x /usr/sbin/policy-rc.d

# ── Configuration APT ────────────────────────────────────────────────
# Supprimer les sources dupliquées du conteneur de base
rm -f /etc/apt/sources.list.d/debian.sources

cat > /etc/apt/sources.list << 'SOURCES'
deb https://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb https://deb.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
deb https://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
SOURCES

mkdir -p /etc/apt/apt.conf.d/
cat > /etc/apt/apt.conf.d/99-build << 'APTCONF'
Acquire::ForceIPv4 "true";
Acquire::Retries "10";
Acquire::https::Verify-Peer "false";
Acquire::https::Verify-Host "false";
APTCONF

echo "=== [conteneur] apt-get update ==="
apt-get update -qq

# Fonction install avec retry automatique
apt_install() {
    local attempt
    for attempt in 1 2 3; do
        if apt-get install -y "$@"; then
            return 0
        fi
        echo "[retry $attempt/3] Mise à jour index et nouvelle tentative..."
        apt-get update -qq 2>/dev/null || true
        sleep 5
    done
    echo "[fallback] Installation avec --fix-missing..."
    apt-get install -y --fix-missing "$@" || true
}

# ── Noyau (séparé pour visibilité) ───────────────────────────────────
echo "=== [conteneur] Installation du noyau ==="
apt_install linux-image-amd64 linux-headers-amd64
echo "Noyau : $(ls /boot/vmlinuz-* 2>/dev/null || echo 'MANQUANT')"
echo "Initrd : $(ls /boot/initrd.img-* 2>/dev/null || echo 'MANQUANT')"

# ── Paquets de base + XFCE ────────────────────────────────────────────
echo "=== [conteneur] Paquets bureau ==="
apt_install --no-install-recommends \
    systemd systemd-sysv dbus sudo \
    openssh-server \
    xfce4 xfce4-goodies xfce4-terminal xfce4-taskmanager \
    xfce4-clipman-plugin xfce4-whiskermenu-plugin xfce4-notifyd \
    lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings \
    network-manager network-manager-gnome \
    firefox-esr thunar thunar-archive-plugin mousepad featherpad file-roller \
    pipewire pipewire-pulse wireplumber pavucontrol \
    firmware-linux firmware-linux-nonfree \
    amd64-microcode intel-microcode \
    blueman bluetooth \
    conky-all flatpak gparted htop \
    plymouth plymouth-themes os-prober \
    curl wget git rsync \
    fonts-liberation fonts-dejavu fonts-noto fonts-noto-color-emoji

# ── Système live ──────────────────────────────────────────────────────
echo "=== [conteneur] Système live ==="
apt_install --no-install-recommends \
    live-boot live-boot-initramfs-tools \
    live-config live-config-systemd live-tools

# ── Installateur Calamares ────────────────────────────────────────────
echo "=== [conteneur] Calamares ==="
apt_install calamares calamares-settings-debian

# ── Logiciels mathématiques ───────────────────────────────────────────
echo "=== [conteneur] Logiciels mathématiques (long...) ==="
apt_install \
    sagemath sagemath-database-conway-polynomials \
    sagemath-database-elliptic-curves sagemath-database-graphs \
    python3-sage maxima wxmaxima mathpiper ecl coq \
    gap-core gap-dev gap-libs gap-gapdoc gap-polycyclic gap-primgrp \
    pari-gp pari-gp2c python3-cypari2 \
    singular singular-data singular-modules singular-ui \
    geogebra gfan gnuplot gnuplot-x11 \
    python3-numpy python3-scipy python3-matplotlib python3-sympy \
    python3-mpmath python3-jupyter-client jupyter-core \
    r-base r-base-core r-base-dev \
    texlive texlive-latex-extra texlive-science biber \
    build-essential gfortran bc default-jre ghostscript

# ── Paquets manquants pour postinst ──────────────────────────────────
apt_install locales

# ── Personnalisation matOS ────────────────────────────────────────────
echo "=== [conteneur] Personnalisation matOS ==="
cd /tmp && tar -xf extra.tar
rsync -a mkosi.extra/ /

# Wrapper systemctl pour enable sans daemon
cat > /usr/local/bin/systemctl << 'SYSTEMCTL_WRAP'
#!/bin/bash
if [ "${1:-}" = "enable" ]; then
    /bin/systemctl --root=/ enable "${@:2}" 2>/dev/null || true
elif [ "${1:-}" = "disable" ]; then
    /bin/systemctl --root=/ disable "${@:2}" 2>/dev/null || true
else
    # Pour les autres commandes (start, stop...), ignorer silencieusement
    exit 0
fi
SYSTEMCTL_WRAP
chmod +x /usr/local/bin/systemctl

bash /tmp/mkosi.postinst

rm -f /usr/local/bin/systemctl

# ── Nettoyage ─────────────────────────────────────────────────────────
rm -f /usr/sbin/policy-rc.d
apt-get clean
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true

echo "=== [conteneur] Configuration terminée ==="
echo "Boot final : $(ls /boot/)"
