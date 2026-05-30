#!/usr/bin/env bash
set -euo pipefail

KERNEL_VERSION="6.1.1"
KERNEL_TAR="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/${KERNEL_TAR}"
SRC_DIR="linux-${KERNEL_VERSION}"
OUT_DIR="osboot"

mkdir -p "$OUT_DIR"

if [ ! -f "$KERNEL_TAR" ]; then
    echo "[kernel] Download Linux kernel ${KERNEL_VERSION}..."
    wget "$KERNEL_URL"
fi

if [ ! -d "$SRC_DIR" ]; then
    echo "[kernel] Extract kernel source..."
    tar -xf "$KERNEL_TAR"
fi

cp .config "$SRC_DIR/.config" 2>/dev/null || true
cd "$SRC_DIR"

if [ ! -s .config ]; then
    make defconfig
fi

make CC=gcc-12 HOSTCC=gcc-12 olddefconfig
make CC=gcc-12 HOSTCC=gcc-12 -j"$(nproc)" bzImage

cd ..
cp "$SRC_DIR/arch/x86/boot/bzImage" "$OUT_DIR/bzImage"
echo "[kernel] Done: $OUT_DIR/bzImage"
