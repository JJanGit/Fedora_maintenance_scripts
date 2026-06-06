#!/bin/bash

# Formatting variables
R='\e[0m'       # Reset
B='\e[1m'       # Bold
GREEN='\e[32m'
CYAN='\e[36m'
RED='\e[31m'
YELLOW='\e[33m'

echo -e "${B}========== JJ FEDORA UPDATE SCRIPT ==========${R}"
echo

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${B}Please run this script as root.${R}"
    exit 1
fi

ask_run() {
    local title="$1"
    local question="$2"
    local cmd="$3"
    local answer

    echo -e "${B}$title${R}"
    while true; do
        read -r -p "$question" answer
        case "${answer,,}" in
            y)
                echo -e "${CYAN}${B}Executing:${R} ${CYAN}$cmd${R}"
                echo
                if ! bash -c "$cmd"; then
                    echo -e "${RED}Command failed!${R}"
                    exit 1
                fi
                break
                ;;
            n)
                echo -e "${CYAN}Alright, skipped!${R}"
                break
                ;;
            *)
                echo -e "${RED}Invalid input: '$answer'. Please answer with ${B}y${R}${RED} or ${B}n${R}${RED}.${R}"
                ;;
        esac
    done
    echo
}

# ----- 1. Update system packages -----
ask_run \
    "----- 1. Update system packages -----" \
    "Do you want to update all system packages? (y/n): " \
    "dnf upgrade --refresh"

KERNEL_UPDATED=false
if dnf history info last 2>/dev/null | grep -q "kernel-core"; then
    KERNEL_UPDATED=true
    echo -e "${YELLOW}Kernel update detected.${R}"
else
    echo -e "${CYAN}No kernel update detected.${R}"
fi
echo

# ----- 2. Update Flatpaks -----
ask_run \
    "----- 2. Update Flatpaks -----" \
    "Do you want to update Flatpaks? (y/n): " \
    "flatpak update --appstream && flatpak update"

# ----- 3. Wait for akmods jobs -----
if rpm -q akmod-nvidia &>/dev/null; then
    echo -e "${B}----- 3. Waiting for akmods jobs -----${R}"
    echo
    echo -e "${CYAN}akmod-nvidia detected.${R}"
    echo -e "${CYAN}Waiting for background akmods jobs to finish...${R}"
    echo

    while pgrep -f akmods > /dev/null; do
        echo -e "${YELLOW}Still waiting...${R}"
        sleep 5
    done
    echo -e "${GREEN}akmods jobs finished.${R}"
    echo

    if [[ "$KERNEL_UPDATED" == true ]]; then
        ask_run \
            "----- 4. Rebuild NVIDIA kernel modules -----" \
            "Kernel was updated — do you want to force-rebuild the NVIDIA kernel modules? (y/n): " \
            "akmods --force"

        ask_run \
            "----- 5. Rebuild initramfs -----" \
            "Do you want to rebuild the initramfs? (y/n): " \
            "dracut --force"
    else
        echo -e "${B}----- 4. Rebuild NVIDIA kernel modules -----${R}"
        echo -e "${CYAN}No kernel update detected, skipping akmods rebuild.${R}"
        echo
        echo -e "${B}----- 5. Rebuild initramfs -----${R}"
        echo -e "${CYAN}No kernel update detected, skipping dracut rebuild.${R}"
        echo
    fi

    # ----- 6. NVIDIA Flatpak runtime version check -----
    echo -e "${B}----- 6. NVIDIA Flatpak runtime check -----${R}"
    echo

    SYSTEM_VER=$(rpm -q --queryformat "%{VERSION}\n" xorg-x11-drv-nvidia 2>/dev/null | tr '.' '-')
    FLATPAK_RUNTIME="org.freedesktop.Platform.GL.nvidia-${SYSTEM_VER}"

    if flatpak list | grep -q "$FLATPAK_RUNTIME"; then
        echo -e "${GREEN}Flatpak NVIDIA runtime matches system driver (${SYSTEM_VER}).${R}"
    else
        echo -e "${RED}Mismatch detected! Flatpak NVIDIA runtime does not match system driver version ${SYSTEM_VER}.${R}"
        echo

        INSTALLED=$(flatpak list | grep "Platform.GL.nvidia" | awk '{print $2}')
        if [[ -n "$INSTALLED" ]]; then
            echo -e "${YELLOW}Currently installed Flatpak NVIDIA runtimes:${R}"
            echo "$INSTALLED"
            echo
        fi

        read -r -p "Do you want to fix this automatically? (y/n): " fix_answer
        if [[ "${fix_answer,,}" == "y" ]]; then
            echo -e "${CYAN}Installing ${FLATPAK_RUNTIME}...${R}"
            flatpak install flathub "$FLATPAK_RUNTIME" -y

            while IFS= read -r runtime; do
                if [[ "$runtime" != "$FLATPAK_RUNTIME" ]]; then
                    echo -e "${CYAN}Removing $runtime...${R}"
                    flatpak uninstall "$runtime" -y
                fi
            done <<< "$INSTALLED"

            echo -e "${GREEN}Flatpak NVIDIA runtime fixed.${R}"
        else
            echo -e "${YELLOW}Skipped. Make sure to fix this manually before rebooting.${R}"
        fi
    fi
    echo

else
    echo -e "${YELLOW}No akmod-nvidia installation detected. Skipping steps 3–6.${R}"
    echo
fi

# ----- 7. Reboot -----
echo -e "${B}----- 7. Reboot system -----${R}"
read -r -p "Do you want to reboot now? Required for kernel/NVIDIA changes to take effect. (y/n): " reboot_answer

case "${reboot_answer,,}" in
    y)
        echo -e "${CYAN}Rebooting system...${R}"
        echo
        sleep 3
        systemctl reboot
        ;;
    n)
        echo -e "${CYAN}Alright, skipped the reboot!${R}"
        ;;
    *)
        echo -e "${RED}Invalid input: '$reboot_answer'. Answer with ${B}y${R}${RED} or ${B}n${R}${RED}.${R}"
        exit 1
        ;;
esac

echo
echo -e "${B}========== JJ FEDORA UPDATE FINISHED ==========${R}"
echo
