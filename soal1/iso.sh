#!/bin/bash
set -e

ISO_DIR="iso_root"

if [ ! -f osboot/bzImage ]; then
    echo "Error: osboot/bzImage belum ada. Jalankan ./kernel.sh dulu."
    exit 1
fi

if [ ! -f osboot/single.gz ]; then
    echo "Error: osboot/single.gz belum ada. Jalankan ./single.sh dulu."
    exit 1
fi

if [ ! -f osboot/multi.gz ]; then
    echo "Error: osboot/multi.gz belum ada. Jalankan ./multi.sh dulu."
    exit 1
fi

rm -rf "$ISO_DIR"
mkdir -p "$ISO_DIR/boot/grub"

cp osboot/bzImage "$ISO_DIR/boot/bzImage"
cp osboot/single.gz "$ISO_DIR/boot/single.gz"
cp osboot/multi.gz "$ISO_DIR/boot/multi.gz"

cat > "$ISO_DIR/boot/grub/grub.cfg" << 'EOF'
set timeout=10
set default=0

menuentry "Farewell Party - Single User" {
    linux /boot/bzImage init=/init quiet loglevel=3
    initrd /boot/single.gz
}

menuentry "Farewell Party - Multi User" {
    linux /boot/bzImage init=/init quiet loglevel=3
    initrd /boot/multi.gz
}
EOF

grub-mkrescue -o osboot/farewell.iso "$ISO_DIR"

echo "farewell.iso berhasil dibuat di osboot/farewell.iso"
