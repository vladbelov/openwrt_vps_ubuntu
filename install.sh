!#/bin/sh

OPENWRT_IMAGE="squashfs-combined.img.gz" # Path to the OpenWRT image
MOUNT_POINT_ROOT="/mnt/openwrt-rootfs"
MOUNT_POINT_BOOT="/mnt/openwrt-boot"
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
mkdir -p $MOUNT_POINT_ROOT $MOUNT_POINT_BOOT

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

# Копируем только ядро и initrd в /boot
echo "Копирование ядра и initrd в /boot..."
cp -v $MOUNT_POINT_BOOT/boot/vmlinuz $BOOT_DIR/vmlinuz-openwrt

# Настройка GRUB
echo "Настройка GRUB для загрузки OpenWRT..."
cat <<EOF | tee $GRUB_CONFIG > /dev/null
#!/bin/sh
exec tail -n +3 \$0

menuentry "OpenWRT" {
    insmod ext4
    set root=(hd0,1)
    insmod ext4  # Убедимся, что поддержка ext4 активирована (или используйте нужную файловую систему, например, squashfs)
    linux /boot/vmlinuz-openwrt root=/dev/sda2 rw
}
EOF

chmod +x $GRUB_CONFIG

# Установка OpenWRT как по умолчанию
echo "Устанавливаем OpenWRT как загрузку по умолчанию в GRUB..."
sed -i 's/GRUB_DEFAULT=0/GRUB_DEFAULT="OpenWRT"/' /etc/default/grub

update-grub
