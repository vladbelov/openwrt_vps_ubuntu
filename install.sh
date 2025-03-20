!#/bin/sh

OPENWRT_IMAGE="squashfs-combined.img.gz" # Path to the OpenWRT image
MOUNT_POINT_ROOT="/mnt/openwrt-rootfs"
MOUNT_POINT_BOOT="/mnt/openwrt-boot"
TEMP_MOUNT="/mnt/tmpfs"
GRUB_CONFIG="/etc/grub.d/40_custom"
BOOT_DIR="/boot"
DEVICE_ROOT="/dev/sda1"
DEVICE_BOOT="/dev/sda2"

# Ensure the script is running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script will work with superuser only."
    exit 1
fi

# Check if the OpenWRT image is compressed (.gz) and decompress it if needed
if [[ "$OPENWRT_IMAGE" == *.gz ]]; then
    echo "The image is compressed (.gz). Decompressing it..."
    gunzip "$OPENWRT_IMAGE"
    OPENWRT_IMAGE="${OPENWRT_IMAGE%.gz}"  # Remove the .gz extension
fi

echo "Installing OpenWRT on Ubuntu system..."
export DEBIAN_FRONTEND=noninteractive

# Install necessary utilities
echo "Installing utilities for working with images..."
apt update
apt install -y rsync util-linux squashfs-tools debootstrap grub2-common

# Create mount points
echo "Creating mount point..."
mkdir -p $MOUNT_POINT_ROOT
mkdir -p $MOUNT_POINT_BOOT
mkdir -p $TEMP_MOUNT

# Attach the OpenWRT image to a loop device
echo "Attaching the OpenWRT image to a loop device..."
LOOP_DEVICE=$(losetup --find --show $OPENWRT_IMAGE)

echo "Loading partitions from the image..."
partx -a $LOOP_DEVICE

# Mount the boot partition (usually first partition)
echo "Mounting the boot partition from the OpenWRT image..."
mount ${LOOP_DEVICE}p1 $MOUNT_POINT_BOOT

# Mount the root filesystem partition (usually second partition)
echo "Mounting the root filesystem partition from the OpenWRT image..."
mount ${LOOP_DEVICE}p2 $MOUNT_POINT_ROOT

# Create directories for temporary storage in Ubuntu
echo "Creating directories for temporary mounting in Ubuntu..."
mkdir -p "$TEMP_MOUNT/boot"
mkdir -p "$TEMP_MOUNT/rootfs"

# Copy files from OpenWRT to Ubuntu temporary directories (excluding unnecessary directories)
echo "Copying files from OpenWRT to temporary directories..."
rsync -a --exclude={proc,sys,dev,tmp,run,var/lock,var/run,var/tmp} "$MOUNT_POINT_ROOT/" "$TEMP_MOUNT/rootfs/"
rsync -a --exclude=boot/grub "$MOUNT_POINT_BOOT/" "$TEMP_MOUNT/boot/"

# Move files from the temporary directory to the root filesystem of Ubuntu
echo "Moving files from the temporary directory to the root filesystem of Ubuntu..."
rsync -a --delete "$TEMP_MOUNT/rootfs/" /
rsync -a --delete "$TEMP_MOUNT/boot/" $BOOT_DIR/
