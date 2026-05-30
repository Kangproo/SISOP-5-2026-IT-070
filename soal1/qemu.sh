#!/bin/bash

case "$1" in
    --single)
        qemu-system-x86_64 \
            -kernel osboot/bzImage \
            -initrd osboot/single.gz \
            -append "console=ttyS0 init=/init panic=-1" \
            -nographic \
            -no-reboot \
            -netdev user,id=net0 \
            -device e1000,netdev=net0
        ;;

    --multi)
        qemu-system-x86_64 \
            -kernel osboot/bzImage \
            -initrd osboot/multi.gz \
            -append "console=ttyS0 init=/init panic=-1" \
            -nographic \
            -no-reboot \
            -netdev user,id=net0 \
            -device e1000,netdev=net0
        ;;

    --all)
        qemu-system-x86_64 \
            -cdrom osboot/farewell.iso \
            -boot d \
            -m 512M \
            -no-reboot \
            -netdev user,id=net0 \
            -device e1000,netdev=net0
        ;;

    *)
        echo "Usage:"
        echo "./qemu.sh --single"
        echo "./qemu.sh --multi"
        echo "./qemu.sh --all"
        ;;
esac