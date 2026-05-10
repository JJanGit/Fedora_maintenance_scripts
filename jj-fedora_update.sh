#!/bin/bash

# Formatting variables
R='\e[0m' # Reset
B='\e[1m' # Bold
GREEN='\e[32m'
CYAN='\e[36m'
RED='\e[31m'
YELLOW='\e[33m'

echo -e "${B}========== JJ FEDORA UPDATE SCRIPT ==========${R}"
echo

# Function to ask user which command to run
ask_run() {
    local title="$1"
    local question="$2"
    local cmd="$3"
    local answer

    echo -e "${B}$title${R}"

    while true; do
        read -r -p "${question}" answer

        case "${answer,,}" in
            y)
                echo -e "${CYAN}${B}Executing:${R} ${CYAN}$cmd${R}"
                echo

                # Execute command and stop script if it fails
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

# Check for root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${B}Please run this script as root.${R}"
    exit 1
fi

ask_run \
"----- 1. Update system packages -----" \
"Do you want to update all system packages? (y/n): " \
"dnf upgrade --refresh"

ask_run \
"----- 2. Update flatpaks -----" \
"Do you want to update flatpaks? (y/n): " \
"flatpak update"

echo -e "${B}----- 3. Waiting for akmods jobs -----${R}"
echo

if rpm -q akmod-nvidia &>/dev/null; then
    echo -e "${CYAN}akmod-nvidia detected.${R}"
    echo -e "${CYAN}Waiting for background akmods jobs to finish...${R}"
    echo

    # Wait for running akmod processes
    while pgrep -f akmods > /dev/null; do
        echo -e "${YELLOW}Still waiting...${R}"
        sleep 5
    done
    echo -e "${GREEN}akmods jobs finished.${R}"
else
    echo -e "${YELLOW}No akmod-nvidia installation detected. Skipping.${R}"
fi
echo

if rpm -q akmod-nvidia &>/dev/null; then
    ask_run \
    "----- 4. Rebuild NVIDIA kernel modules -----" \
    "Do you want to rebuild the NVIDIA kernel modules? Only needed if there was a kernel update in the first section. (y/n): " \
    "akmods --force"
fi

if rpm -q akmod-nvidia &>/dev/null; then
    ask_run \
    "----- 5. Rebuild initramfs -----" \
    "Do you want to rebuild the initramfs? Only needed if there was a kernel update in the first section. (y/n): " \
    "dracut --force"
fi

echo -e "${B}----- 6. Reboot system -----${R}"
read -r -p "Do you want to reboot now? Required for kernel updates and NVIDIA/initramfs changes to take effect. (y/n): " reboot_answer

if [[ "$reboot_answer" = "y" ]]; then
    echo -e "${CYAN}Rebooting system...${R}"
    echo

    sleep 3
    systemctl reboot
elif [[ "$reboot_answer" = "n" ]]; then

    echo -e "${CYAN}Alright, skipped the reboot!${R}"
else

    echo -e "${RED}Invalid input: '$reboot_answer'. Answer with a ${B}${RED}y${R} ${RED}or a ${B}n${R}."
    exit 1
fi

echo
echo -e "${B}========== JJ FEDORA UPDATE FINISHED ==========${R}"
echo
