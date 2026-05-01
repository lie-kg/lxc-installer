#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
#   LXC + LXD AUTO INSTALLER (LEVEL ∞ EDITION)
#   Ubuntu / Debian - Production Ready
# =========================================================

# ---------------- CONFIG ----------------
LOG_FILE="/tmp/lxd_installer.log"
MAX_RETRIES=3
RETRY_DELAY=3
FAST_MODE="${FAST_MODE:-0}"

# ---------------- COLORS ----------------
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"
BLUE="\e[34m"; CYAN="\e[36m"; MAGENTA="\e[35m"
BOLD="\e[1m"; RESET="\e[0m"

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

# ---------------- LOG ----------------
init_log() {
    echo "=== LXD INSTALL LOG ===" > "$LOG_FILE"
    echo "Date: $(date)" >> "$LOG_FILE"
}

log() {
    echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# ---------------- HEADER ----------------
show_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat <<EOF
██╗     ██╗  ██╗ ██████╗ ██╗  ██╗██████╗
██║     ╚██╗██╔╝██╔═══██╗██║  ██║██╔══██╗
██║      ╚███╔╝ ██║   ██║███████║██████╔╝
██║      ██╔██╗ ██║   ██║██╔══██║██╔═══╝
███████╗██╔╝ ██╗╚██████╔╝██║  ██║██║
╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝

   LXC + LXD INSTALLER LEVEL ∞
EOF
    echo -e "${RESET}"
}

# ---------------- FAST CONTROL ----------------
run() {
    log "RUN: $*"
    "$@" >>"$LOG_FILE" 2>&1
}

wait_snap() {
    local i=0
    while ! snap changes >/dev/null 2>&1; do
        sleep 1
        ((i++))
        [ $i -gt 30 ] && break
    done
}

# ---------------- INSTALL ----------------
install_base() {
    log "Installing base packages"
    run $SUDO apt update -y
    run $SUDO apt install -y lxc bridge-utils uidmap curl wget snapd
}

install_lxd() {
    log "Installing snapd + LXD"

    run $SUDO systemctl enable --now snapd.socket

    wait_snap

    run $SUDO snap install core || true
    run $SUDO snap refresh core

    if ! snap list lxd >/dev/null 2>&1; then
        run $SUDO snap install lxd --channel=latest/stable
    fi
}

# ---------------- USER SETUP ----------------
setup_user() {
    USERNAME="${SUDO_USER:-$USER}"
    log "Adding user $USERNAME to lxd"
    run $SUDO usermod -aG lxd "$USERNAME"
}

# ---------------- LXD INIT ----------------
init_lxd() {
    log "Initializing LXD"

    if ! command -v lxd >/dev/null 2>&1; then
        echo -e "${RED}LXD not found${RESET}"
        exit 1
    fi

    $SUDO lxd init --auto || {
        echo -e "${YELLOW}Auto init failed → fallback interactive${RESET}"
        $SUDO lxd init
    }
}

# ---------------- NETWORK FIX ----------------
fix_bridge() {
    log "Checking lxd network"

    if ! $SUDO lxc network list | grep -q lxdbr0; then
        echo -e "${CYAN}Creating default bridge...${RESET}"
        $SUDO lxc network create lxdbr0 ipv4.address=auto ipv6.address=auto || true
    fi
}

# ---------------- VALIDATION ----------------
validate() {
    log "Validating install"

    $SUDO lxc version || true
    $SUDO lxc list || true
}

# ---------------- CLEAN EXIT ----------------
cleanup() {
    log "Cleaning up"
}
trap cleanup EXIT

# ---------------- MAIN ----------------
main() {
    init_log
    show_header

    install_base
    install_lxd
    setup_user
    init_lxd
    fix_bridge
    validate

    echo -e "${GREEN}${BOLD}✔ INSTALL COMPLETE${RESET}"
    echo -e "${BLUE}Run: newgrp lxd OR reboot${RESET}"
}

main "$@"
