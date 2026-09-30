#!/bin/bash
# Mount spruce's card at /mnt/SDCARD and hand off to it.
#
# Two card models are supported, because these RK3326 boards have two slots
# (both &sdmmc and &sdio are card slots with their own card-detect - neither
# board has an internal radio, WiFi is a USB dongle):
#
#   SD1  the built twigUI card itself: boot + system partitions and spruce on
#        the card's own FAT32 partition, labelled TWIGUI. This is the default
#        and the only model the first run knows about.
#   SD2  a separate spruce card in the other slot, the dArkMoss/moss model. If
#        one is present it WINS over SD1, so the same base card can carry a
#        throwaway payload while a full spruce card is swapped in and out.
#
# An SD2 card is recognised by the label SPRUCEOS (what dArkMoss cards use) or,
# failing that, by carrying .tmp_update/updater - spruce's own entry point. The
# search never considers the disk we booted from, so SD1 can only ever be
# reached through the TWIGUI label below.

. /etc/profile

SPRUCE_MNT="/mnt/SDCARD"
LOG="/flash/spruce-card.log"
MOUNT_OPTS="rw,noatime,umask=0000"

log() { echo "$(date -Iseconds 2>/dev/null) $*" >> "$LOG" 2>/dev/null; }

# The disk /flash lives on, e.g. /dev/mmcblk0p1 -> mmcblk0. Everything on it is
# SD1 and is out of scope for the SD2 search.
boot_disk() {
    local dev
    dev="$(awk '$2=="/flash"{print $1; exit}' /proc/mounts)"
    [ -n "$dev" ] || return 1
    dev="${dev#/dev/}"
    echo "${dev%%p[0-9]*}"
}

# Partitions on every removable mmc disk that is not the boot disk.
sd2_partitions() {
    local boot="$1" disk name part
    for disk in /sys/block/mmcblk*; do
        [ -e "$disk" ] || continue
        name="$(basename "$disk")"
        [ "$name" = "$boot" ] && continue
        case "$name" in *boot*|*rpmb*) continue ;; esac
        for part in "$disk"/"$name"p*; do
            [ -e "$part" ] && echo "/dev/$(basename "$part")"
        done
    done
}

is_spruce_card() {
    # $1 = device. Mounted read-only so a card that is not spruce's is left
    # exactly as it was.
    local dev="$1" probe="/tmp/.spruce-probe" ok=1
    mkdir -p "$probe" 2>/dev/null
    if mount -o ro "$dev" "$probe" 2>/dev/null; then
        [ -f "$probe/.tmp_update/updater" ] && ok=0
        umount "$probe" 2>/dev/null
    fi
    rmdir "$probe" 2>/dev/null
    return $ok
}

find_sd2() {
    local boot="$1" dev label
    # exFAT is a module in this kernel; a card formatted that way needs it
    # before any mount attempt can succeed.
    modprobe exfat 2>/dev/null

    # Pass 1: the dArkMoss convention, a card labelled SPRUCEOS.
    for dev in $(sd2_partitions "$boot"); do
        label="$(blkid -s LABEL -o value "$dev" 2>/dev/null)"
        if [ "$label" = "SPRUCEOS" ]; then
            echo "$dev"
            return 0
        fi
    done

    # Pass 2: any card that carries spruce's entry point, whatever its label.
    for dev in $(sd2_partitions "$boot"); do
        if is_spruce_card "$dev"; then
            echo "$dev"
            return 0
        fi
    done

    return 1
}

BOOT_DISK="$(boot_disk)"
log "boot disk: ${BOOT_DISK:-unknown}"

# SD1 first: the first run expands and formats this partition and expects it
# mounted, so nothing about that path changes.
mount -o "$MOUNT_OPTS" LABEL=TWIGUI "$SPRUCE_MNT" 2>/dev/null

if [ -f "/flash/first_run.txt" ]; then
    log "first run: installing onto SD1"
    /usr/bin/install_spruce.sh
    exit 0
fi

# An SD2 spruce card, if there is one, replaces SD1 for this boot.
if [ -n "$BOOT_DISK" ] && SD2="$(find_sd2 "$BOOT_DISK")"; then
    log "SD2 spruce card found at $SD2 - using it instead of SD1"
    umount "$SPRUCE_MNT" 2>/dev/null
    if mount -o "$MOUNT_OPTS" "$SD2" "$SPRUCE_MNT" 2>/dev/null; then
        log "mounted $SD2 at $SPRUCE_MNT"
    else
        log "could not mount $SD2 - falling back to SD1"
        mount -o "$MOUNT_OPTS" LABEL=TWIGUI "$SPRUCE_MNT" 2>/dev/null
    fi
else
    log "no SD2 spruce card - using SD1 (LABEL=TWIGUI)"
fi

if [ -f "$SPRUCE_MNT/.tmp_update/updater" ]; then
    log "handing off to $SPRUCE_MNT/.tmp_update/updater"
    "$SPRUCE_MNT/.tmp_update/updater"
else
    log "no updater on the mounted card - powering off"
    sleep 5
    show_msg 640 480 "Empty image.| |Device will power off in 30s." &
    sleep 30

    pkill show_msg
    poweroff
fi

exit 0
