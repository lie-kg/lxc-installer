#!/usr/bin/env bash
set -Eeuo pipefail

# =========================================================
#   LXC + LXD AUTO INSTALLER (KALI/UBUNTU/DEBIAN)
#   VPS SAFE VERSION
#   Author: lie_kg
# =========================================================

export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

# ---------------- COLORS ----------------

RESET="\033[0m"
BOLD="\033[1m"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
MAGENTA="\033[35m"

# ---------------- SYMBOLS ----------------

OK="[OK]"
FAIL="[FAIL]"
WARN="[WARN]"
INFO="[INFO]"
ARROW=">>"

# ---------------- CONFIG ----------------

INSTALL_LOG="/tmp/lxd_installer.log"

# ---------------- ROOT CHECK ----------------

SUDO=""

if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

# ---------------- LOGGING ----------------

init_log() {
    echo "=== LXC/LXD INSTALLER LOG ===" > "$INSTALL_LOG"
    echo "Started: $(date)" >> "$INSTALL_LOG"
}

log_message() {
    local level="$1"
    local msg="$2"

    echo "[$(date '+%H:%M:%S')] [$level] $msg" >> "$INSTALL_LOG"
}

# ---------------- HEADER ----------------

show_header() {

    clear

    echo -e "${BLUE}${BOLD}"

cat << "EOF"

██╗      ██╗  ██╗ ██████╗  ██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     ███████╗██████╗
██║      ╚██╗██╔╝██╔════╝  ██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     ██╔════╝██╔══██╗
██║       ╚███╔╝ ██║       ██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     █████╗  ██████╔╝
██║       ██╔██╗ ██║       ██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     ██╔══╝  ██╔══██╗
███████╗ ██╔╝ ██╗╚██████╗  ██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗███████╗██║  ██║
╚══════╝ ╚═╝  ╚═╝ ╚═════╝  ╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝╚═╝  ╚═╝

EOF

    echo -e "${RESET}"

    echo -e "${MAGENTA}${BOLD}AUTO LXC + LXD INSTALLER${RESET}"
    echo -e "${CYAN}Made by lie_kg${RESET}"

    echo
}

# ---------------- BOX ----------------

print_box() {
    local msg="$1"

    echo
    echo "+================================================+"
    printf "| %-46s |\n" "$msg"
    echo "+================================================+"
}

# ---------------- SPINNER ----------------

_spinner() {

    local pid=$1
    local delay=0.10
    local spin='-\|/'

    while ps -p $pid > /dev/null 2>&1; do
        for i in $(seq 0 3); do
            printf "\r${CYAN}[%c]${RESET} " "${spin:$i:1}"
            sleep $delay
        done
    done

    printf "\r"
}

# ---------------- RUN WITH SPINNER ----------------

run_with_spinner() {

    local desc="$1"
    shift

    printf "${CYAN}${INFO}${RESET} %s\n" "$desc"

    (
        "$@"
    ) >> "$INSTALL_LOG" 2>&1 &

    local pid=$!

    _spinner $pid

    if wait $pid; then
        printf "${GREEN}${OK}${RESET} %s\n\n" "$desc"
        log_message "SUCCESS" "$desc"
    else
        printf "${RED}${FAIL}${RESET} %s\n\n" "$desc"
        log_message "ERROR" "$desc"
        return 1
    fi
}

# ---------------- DETECT OS ----------------

detect_os() {

    if [ -f /etc/os-release ]; then
        . /etc/os-release

        OS_ID="${ID:-unknown}"
        OS_VERSION="${VERSION_ID:-unknown}"
    else
        echo -e "${RED}${FAIL} Cannot detect OS${RESET}"
        exit 1
    fi

    case "$OS_ID" in
        ubuntu|debian|kali|linuxmint|parrot)
            echo -e "${GREEN}${OK} Supported OS detected: ${OS_ID} ${OS_VERSION}${RESET}"
            ;;
        *)
            echo -e "${YELLOW}${WARN} Unknown distro detected: ${OS_ID}${RESET}"
            echo -e "${CYAN}${INFO}${RESET} Continuing anyway..."
            ;;
    esac

    if systemd-detect-virt --quiet openvz; then
        echo -e "${RED}${FAIL} OpenVZ is not supported by LXD${RESET}"
        exit 1
    fi

    virt=$(systemd-detect-virt || echo "none")

    echo -e "${CYAN}${INFO}${RESET} Virtualization: ${virt}"
    echo
}

# ---------------- SYSTEM INFO ----------------

show_system_info() {

    print_box "SYSTEM INFORMATION"

    echo -e "${CYAN}OS:${RESET} $(lsb_release -d 2>/dev/null | cut -f2)"
    echo -e "${CYAN}Kernel:${RESET} $(uname -r)"
    echo -e "${CYAN}Architecture:${RESET} $(uname -m)"
    echo -e "${CYAN}RAM:${RESET} $(free -h | awk '/^Mem:/ {print $2}')"
    echo -e "${CYAN}Disk:${RESET} $(df -h / | awk 'NR==2 {print $4}')"

    echo
}

# ---------------- INSTALL ----------------

install_packages() {

    print_box "INSTALLING PACKAGES"

    run_with_spinner \
        "Updating repositories" \
        $SUDO apt update -y

    run_with_spinner \
        "Installing dependencies" \
        $SUDO apt install -y \
        lxc \
        snapd \
        curl \
        wget \
        uidmap \
        bridge-utils \
        squashfs-tools \
        ca-certificates \
        locales \
        software-properties-common \
        iptables \
        jq \
        nano

    run_with_spinner \
        "Generating locales" \
        $SUDO locale-gen en_US.UTF-8

    run_with_spinner \
        "Updating locale settings" \
        $SUDO update-locale LANG=en_US.UTF-8
}

# ---------------- INSTALL LXD ----------------

install_lxd() {

    print_box "INSTALLING LXD"

    run_with_spinner \
        "Enabling snapd" \
        $SUDO systemctl enable --now snapd

    run_with_spinner \
        "Restarting snapd" \
        $SUDO systemctl restart snapd

    sleep 5

    run_with_spinner \
        "Installing LXD from snap" \
        $SUDO snap install lxd --channel=latest/stable

    run_with_spinner \
        "Initializing LXD" \
        $SUDO lxd init --auto
}

# ---------------- USER CONFIG ----------------

configure_user() {

    print_box "CONFIGURING USER"

    TARGET_USER="${SUDO_USER:-$(whoami)}"

    if ! groups "$TARGET_USER" | grep -q '\blxd\b'; then

        run_with_spinner \
            "Adding user to lxd group" \
            $SUDO usermod -aG lxd "$TARGET_USER"
    fi
}

# ---------------- VALIDATE ----------------

validate_installation() {

    print_box "VALIDATING INSTALLATION"

    run_with_spinner \
        "Checking LXD status" \
        $SUDO lxc info

    run_with_spinner \
        "Checking containers" \
        $SUDO lxc list
}

# ---------------- SUCCESS ----------------

show_success() {

    print_box "INSTALL COMPLETE"

    echo -e "${GREEN}${OK} LXC/LXD installed successfully${RESET}"
    echo

    echo -e "${CYAN}Commands:${RESET}"
    echo

    echo "lxc list"
    echo "lxc info"
    echo "lxc storage list"
    echo "lxc network list"
    echo "lxc launch ubuntu:22.04 test"

    echo
    echo -e "${YELLOW}Run:${RESET} newgrp lxd"
    echo
}

# ---------------- ERROR ----------------

handle_error() {

    local exit_code=$?
    local line_number=$1
    local command="$2"

    echo
    echo -e "${RED}${FAIL} Installation failed${RESET}"
    echo -e "${RED}Line:${RESET} $line_number"
    echo -e "${RED}Command:${RESET} $command"
    echo -e "${RED}Exit:${RESET} $exit_code"
    echo

    exit $exit_code
}

trap 'handle_error ${LINENO} "${BASH_COMMAND}"' ERR

# ---------------- MAIN ----------------

main() {

    init_log

    show_header

    detect_os

    show_system_info

    install_packages

    install_lxd

    configure_user

    validate_installation

    show_success
}

main "$@"
