#!/bin/bash
set -e

TIMESTAMP=$(date +"%d%m%Y-%H%M%S")
BACKUP_NAME="farewell_backup_${TIMESTAMP}.zip"

REQUIRED_FILES=(
    "osboot/bzImage"
    "osboot/single.gz"
    "osboot/multi.gz"
    "osboot/farewell.iso"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Error: $file tidak ditemukan."
        exit 1
    fi
done

zip -j "$BACKUP_NAME" \
    osboot/bzImage \
    osboot/single.gz \
    osboot/multi.gz \
    osboot/farewell.iso

echo "Backup berhasil dibuat: $BACKUP_NAME"

if [ "$1" = "--clean" ]; then
    rm -f osboot/bzImage osboot/single.gz osboot/multi.gz osboot/farewell.iso
    echo "File hasil build di osboot sudah dihapus karena memakai opsi --clean."
else
    echo "File asli di osboot tidak dihapus."
fi