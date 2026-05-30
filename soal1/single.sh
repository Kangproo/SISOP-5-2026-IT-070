#!/bin/bash
set -e

BUILD_DIR="build_single"
ROOTFS="$BUILD_DIR/rootfs"

rm -rf "$BUILD_DIR"

mkdir -p "$ROOTFS/bin"
mkdir -p "$ROOTFS/dev"
mkdir -p "$ROOTFS/proc"
mkdir -p "$ROOTFS/sys"
mkdir -p "$ROOTFS/etc"
mkdir -p "$ROOTFS/tmp"
mkdir -p "$ROOTFS/root"
mkdir -p "$ROOTFS/opt/party/packages"
mkdir -p "$ROOTFS/usr/share/udhcpc"
mkdir -p osboot

cp /bin/busybox "$ROOTFS/bin/busybox"

for cmd in sh ls cat echo mount umount mkdir dmesg clear whoami id ping wget poweroff halt reboot sync sleep pwd ifconfig ip route udhcpc chmod; do
    ln -sf /bin/busybox "$ROOTFS/bin/$cmd"
done

cat > "$ROOTFS/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/sh
EOF

cat > "$ROOTFS/etc/group" << 'EOF'
root:x:0:
EOF

cat > "$ROOTFS/etc/resolv.conf" << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

cat > "$ROOTFS/usr/share/udhcpc/default.script" << 'EOF'
#!/bin/sh

case "$1" in
    bound|renew)
        ifconfig "$interface" "$ip" netmask "$subnet"
        route add default gw "$router" dev "$interface" 2>/dev/null

        echo -n > /etc/resolv.conf
        for dns in $dns; do
            echo "nameserver $dns" >> /etc/resolv.conf
        done
        ;;
esac
EOF

chmod +x "$ROOTFS/usr/share/udhcpc/default.script"

cat > "$ROOTFS/etc/motd" << 'EOF'
Farewell Party
Welcome, root
EOF

cat > "$ROOTFS/bin/party" << 'EOF'
#!/bin/sh

PACKAGE_DIR="/opt/party/packages"

show_help() {
    echo "party package manager"
    echo
    echo "Usage:"
    echo "  party"
    echo "  party list"
    echo "  party install fuse"
}

case "$1" in
    list)
        echo "Available packages:"
        echo "- fuse"
        ;;

    install)
        if [ "$2" = "fuse" ]; then
            mkdir -p "$PACKAGE_DIR"
            mkdir -p /tmp/fusemnt

            cat > /bin/fuse_demo << 'FUSEEOF'
#!/bin/sh

MOUNT_POINT="$1"

if [ -z "$MOUNT_POINT" ]; then
    MOUNT_POINT="/tmp/fusemnt"
fi

mkdir -p "$MOUNT_POINT"

echo "Hello from FUSE demo" > "$MOUNT_POINT/hello.txt"

echo "FUSE demo berhasil dijalankan."
echo "Mount point simulasi: $MOUNT_POINT"
echo "Coba jalankan:"
echo "  ls $MOUNT_POINT"
echo "  cat $MOUNT_POINT/hello.txt"
FUSEEOF

            chmod +x /bin/fuse_demo

            echo "Package fuse berhasil diinstall."
            echo "Program demo tersedia sebagai: fuse_demo"
        else
            echo "Package tidak ditemukan: $2"
            echo "Coba: party list"
        fi
        ;;

    *)
        show_help
        ;;
esac
EOF

chmod +x "$ROOTFS/bin/party"

cat > "$ROOTFS/init" << 'EOF'
#!/bin/sh

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null

ifconfig lo up 2>/dev/null
ifconfig eth0 up 2>/dev/null
udhcpc -i eth0 -s /usr/share/udhcpc/default.script 2>/dev/null

clear
cat /etc/motd
echo

cd /root

while true
do
    /bin/sh
    echo
    echo "Shell exited."
    echo "Untuk keluar dari QEMU tekan Ctrl+A lalu X."
    sleep 1
done
EOF

chmod +x "$ROOTFS/init"
chmod 700 "$ROOTFS/root"
chmod 1777 "$ROOTFS/tmp"

echo "Cek isi rootfs single sebelum compress:"
ls -la "$ROOTFS/etc"
cat "$ROOTFS/etc/motd"

cd "$ROOTFS"
find . | cpio -H newc -o | gzip > "../../osboot/single.gz"
cd ../..

echo "single.gz berhasil dibuat di osboot/single.gz"