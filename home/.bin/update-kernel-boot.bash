#!/usr/bin/env bash

[[ -z "$DEBUG" ]] && DEBUG=false
$DEBUG && set -Eeuxo pipefail

SCRIPT="$(realpath -s "${BASH_SOURCE[0]}")"
SCRIPT_DIR=$(dirname "$SCRIPT")
source "$SCRIPT_DIR"/include/log

function run_root {
    DRIVE="/dev/nvme0n1"
    ESP="/boot/efi"
    KERNEL="linux-zen"
    KERNEL_PARAMS=("lsm=landlock,lockdown,yama,integrity,apparmor,bpf")
    ENABLE_FULL_DRIVE_ENCRYPTION=false

    P2="2"
    if [[ "$DRIVE" == *"nvme"* ]]; then
        P2="p2"
    fi

    swapfile="/swapfile"
    if [[ -f "$swapfile" ]]; then
        log "Applying swapfile params"
        SWAP_DEVICE=$(findmnt -no UUID -T "$swapfile")
        SWAP_FILE_OFFSET=$(filefrag -v "$swapfile" | awk '$1=="0:" {print substr($4, 1, length($4)-2)}')
        KERNEL_PARAMS+=(resume="$SWAP_DEVICE" resume_offset="$SWAP_FILE_OFFSET")
    fi

    [[ ! -r "/etc/mkinitcpio.d/linux.preset.backup" ]] && mv /etc/mkinitcpio.d/linux.preset /etc/mkinitcpio.d/linux.preset.backup

    log "Creating linux preset for mkinitcpio"
    local splash
    splash="/usr/share/systemd/bootctl/splash-arch.bmp"
    {
        echo "ALL_config=\"/etc/mkinitcpio.conf\""
        echo "ALL_kver=\"/boot/vmlinuz-linux\""
        echo "ALL_microcode=(/boot/*-ucode.img)"

        echo "PRESETS=('default')"

        echo "default_image=\"/boot/initramfs-linux.img\""
        echo "default_efi_image=\"$ESP/EFI/BOOT/bootx64.efi\""
        echo "default_options=\"--splash $splash\""

        # echo "fallback_image=\"/boot/initramfs-linux-fallback.img\""
        # echo "fallback_efi_image=\"$ESP/EFI/Linux/linux-fallback.efi\""
        # echo "fallback_options=\"-S autodetect\""
    } >/etc/mkinitcpio.d/linux.preset

    log "Creating linux-zen preset for mkinitcpio"
    cp -f /etc/mkinitcpio.d/linux.preset /etc/mkinitcpio.d/linux-zen.preset
    sed -i "s|linux|linux-zen|" /etc/mkinitcpio.d/linux-zen.preset

    local uuid root_params
    uuid=$(blkid -s UUID -o value "$DRIVE$P2")
    root_params="root=UUID=$uuid"
    [[ "$ENABLE_FULL_DRIVE_ENCRYPTION" ]] && root_params="cryptdevice=UUID=$uuid:root root=/dev/mapper/root"

    log "Applying kernel parameters"
    echo "$root_params rw bgrt_disable nowatchdog ${KERNEL_PARAMS[*]}" >/etc/kernel/cmdline

    mkdir -p "$ESP"/EFI/Arch
    mkdir -p "$ESP"/EFI/BOOT

    log "Starting mkinitcpio"
    rm -rf "${ESP:?}"/*
    mkinitcpio -p $KERNEL

    log "Creating UEFI boot entry"
    local model
    model=$(lsblk --output=MODEL --noheadings --ascii "$DRIVE" | tr -d '\n')
    efibootmgr --create --disk "$DRIVE" --part 1 --label "Arch ($model)" --loader "EFI\BOOT\bootx64.efi" --verbose
}

case $1 in
"linux") KERNEL="linux" ;;
esac

if [[ $(id -u) -eq 0 ]]; then
    run_root "$@"
else
    sudo "$SCRIPT_PATH" "$@"
fi
