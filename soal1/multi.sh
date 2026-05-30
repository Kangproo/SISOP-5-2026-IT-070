#!/bin/bash
set -e

BUILD_DIR="build_multi"
ROOTFS="$BUILD_DIR/rootfs"

rm -rf "$BUILD_DIR"

mkdir -p "$ROOTFS/bin"
mkdir -p "$ROOTFS/dev"
mkdir -p "$ROOTFS/proc"
mkdir -p "$ROOTFS/sys"
mkdir -p "$ROOTFS/etc"
mkdir -p "$ROOTFS/tmp"
mkdir -p "$ROOTFS/root"
mkdir -p "$ROOTFS/home/henn"
mkdir -p "$ROOTFS/home/hann"
mkdir -p "$ROOTFS/home/viii"
mkdir -p "$ROOTFS/home/kids"
mkdir -p "$ROOTFS/opt/party/packages"
mkdir -p "$ROOTFS/usr/share/udhcpc"
mkdir -p osboot

cp /bin/busybox "$ROOTFS/bin/busybox"

for cmd in sh ls cat echo mount umount mkdir dmesg clear whoami id ping wget poweroff halt reboot sync sleep pwd su ifconfig ip route udhcpc chmod; do
    ln -sf /bin/busybox "$ROOTFS/bin/$cmd"
done

cat > "$ROOTFS/etc/passwd" << 'EOF'
root:x:0:0:root:/root:/bin/sh
henn:x:1001:1001:henn:/home/henn:/bin/sh
hann:x:1002:1002:hann:/home/hann:/bin/sh
viii:x:1003:1003:viii:/home/viii:/bin/sh
kids:x:1004:1004:kids:/home/kids:/bin/sh
EOF

cat > "$ROOTFS/etc/group" << 'EOF'
root:x:0:
henn:x:1001:
hann:x:1002:
viii:x:1003:
kids:x:1004:
access_hann:x:2002:henn
access_viii:x:2003:henn,hann
access_kids:x:2004:henn,hann,viii
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

cat > "$ROOTFS/bin/user_session" << 'EOF'
#!/bin/sh

clear
cat /etc/motd
echo "Welcome, $(whoami)"
echo

USER_NOW="$(whoami)"

case "$USER_NOW" in
    root)
        cd /root 2>/dev/null || cd /
        ;;
    henn)
        cd /home/henn 2>/dev/null || cd /
        ;;
    hann)
        cd /home/hann 2>/dev/null || cd /
        ;;
    viii)
        cd /home/viii 2>/dev/null || cd /
        ;;
    kids)
        cd /home/kids 2>/dev/null || cd /
        ;;
    *)
        cd /
        ;;
esac

/bin/sh

echo
echo "Logout dari user $(whoami)."
echo "Kembali ke halaman login..."
sleep 1
EOF

chmod +x "$ROOTFS/bin/user_session"

cat > "$ROOTFS/bin/login_party" << 'EOF'
#!/bin/sh

while true
do
    clear
    echo "Farewell Party Login"
    echo

    echo -n "login: "
    read LOGIN_USER

    echo -n "password: "
    read LOGIN_PASS

    case "$LOGIN_USER:$LOGIN_PASS" in
        root:root123)
            su root -c /bin/user_session
            ;;
        henn:henn123)
            su henn -c /bin/user_session
            ;;
        hann:hann123)
            su hann -c /bin/user_session
            ;;
        viii:viii123)
            su viii -c /bin/user_session
            ;;
        kids:kids123)
            su kids -c /bin/user_session
            ;;
        *)
            echo
            echo "Login incorrect"
            sleep 1
            ;;
    esac
done
EOF

chmod +x "$ROOTFS/bin/login_party"

cat > "$ROOTFS/init" << 'EOF'
#!/bin/sh

mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev 2>/dev/null

ifconfig lo up 2>/dev/null
ifconfig eth0 up 2>/dev/null
udhcpc -i eth0 -s /usr/share/udhcpc/default.script 2>/dev/null

/bin/login_party
EOF

chmod +x "$ROOTFS/init"

chmod 755 "$ROOTFS"
chmod 755 "$ROOTFS/bin"
chmod 755 "$ROOTFS/dev"
chmod 755 "$ROOTFS/proc"
chmod 755 "$ROOTFS/sys"
chmod 755 "$ROOTFS/etc"
chmod 755 "$ROOTFS/home"

chmod 700 "$ROOTFS/root"
chmod 1777 "$ROOTFS/tmp"

chown 0:0 "$ROOTFS/root"

chown 1001:1001 "$ROOTFS/home/henn"
chmod 700 "$ROOTFS/home/henn"

chown 1002:2002 "$ROOTFS/home/hann"
chmod 770 "$ROOTFS/home/hann"

chown 1003:2003 "$ROOTFS/home/viii"
chmod 770 "$ROOTFS/home/viii"

chown 1004:2004 "$ROOTFS/home/kids"
chmod 770 "$ROOTFS/home/kids"

echo "Cek permission rootfs multi sebelum compress:"
ls -ld "$ROOTFS/root" "$ROOTFS/home/henn" "$ROOTFS/home/hann" "$ROOTFS/home/viii" "$ROOTFS/home/kids" "$ROOTFS/tmp"

cd "$ROOTFS"
find . | cpio -H newc -o | gzip > "../../osboot/multi.gz"
cd ../..

if [ -n "$SUDO_UID" ] && [ -n "$SUDO_GID" ]; then
    chown "$SUDO_UID:$SUDO_GID" osboot/multi.gz
fi

echo "multi.gz berhasil dibuat di osboot/multi.gz"