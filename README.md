# Laporan Praktikum Sistem Operasi

## Identitas

Nama: Sultan Ahmad Maulana Bahyshidqi

NRP: 5027251070

---

# Soal 1 - Farewell Party OS

## Deskripsi Soal

Pada soal ini, saya diminta membuat mini operating system yang dapat dijalankan melalui QEMU. Sistem ini menggunakan kernel Linux 6.1.1, lalu memiliki dua jenis filesystem, yaitu **single-user filesystem** dan **multi-user filesystem**. Selain itu, sistem juga harus dapat dibungkus menjadi ISO bootable, memiliki akses internet, memiliki package manager sederhana bernama `party`, menjalankan demo FUSE, serta memiliki script backup hasil build.

Target utama dari soal ini adalah menghasilkan file berikut di dalam folder `osboot/`:

```text
bzImage
single.gz
multi.gz
farewell.iso
```

---

## Penjelasan Solusi

Pengerjaan soal ini dibagi menjadi beberapa script agar setiap tahap build lebih terstruktur:

* `kernel.sh` digunakan untuk mengunduh dan mengompilasi kernel Linux 6.1.1.
* `single.sh` digunakan untuk membuat root filesystem single-user.
* `multi.sh` digunakan untuk membuat root filesystem multi-user dengan beberapa user dan aturan permission.
* `iso.sh` digunakan untuk membuat ISO bootable yang dapat memilih single-user atau multi-user.
* `qemu.sh` digunakan untuk menjalankan hasil build melalui QEMU.
* `backup.sh` digunakan untuk mengarsipkan file hasil build.

Pada bagian kernel, script akan memakai file `.config` jika tersedia. Jika `.config` kosong, script akan memakai konfigurasi default melalui `make defconfig`. Kernel kemudian dikompilasi dengan `gcc-12` untuk menghindari masalah compiler baru terhadap kernel Linux 6.1.1.

Pada filesystem single-user, hanya user `root` yang digunakan. Pada filesystem multi-user, terdapat user `root`, `henn`, `hann`, `viii`, dan `kids`. Permission folder `/home` diatur agar sesuai dengan ketentuan akses masing-masing user.

Untuk fitur tambahan, root filesystem juga diberikan konfigurasi jaringan menggunakan `udhcpc`, package manager sederhana bernama `party`, dan demo FUSE sederhana melalui program `fuse_demo`.

---

## Struktur Folder

Struktur folder utama yang digunakan:

```text
modul5/
├── soal1/
│   ├── .config
│   ├── backup.sh
│   ├── iso.sh
│   ├── kernel.sh
│   ├── multi.sh
│   ├── osboot/
│   ├── qemu.sh
│   └── single.sh
└── soal2/
    ├── Makefile
    ├── README.md
    ├── bochsrc.txt
    ├── bootloader.asm
    ├── build.sh
    ├── kernel.asm
    └── kernel.c
```

Catatan: folder `osboot/` pada repository berisi `.gitkeep` agar folder tetap masuk Git. File hasil build seperti `bzImage`, `single.gz`, `multi.gz`, dan `farewell.iso` dapat dibuat ulang dengan menjalankan script yang tersedia.

---

## Kode Program

### 1. `kernel.sh`

```bash
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
```

### 2. `single.sh`

```bash
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
```

### 3. `multi.sh`

```bash
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
```

### 4. `iso.sh`

```bash
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
```

### 5. `qemu.sh`

```bash
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
```

### 6. `backup.sh`

```bash
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
```

---

## Penjelasan Kode per Bagian

### 1. `kernel.sh`

Script `kernel.sh` bertugas membangun kernel Linux 6.1.1.

Tahap yang dilakukan:

1. membuat folder `osboot/`
2. mengunduh source kernel `linux-6.1.1.tar.xz`
3. mengekstrak source kernel
4. menyalin `.config` jika tersedia
5. memakai `make defconfig` jika `.config` kosong
6. menjalankan `make olddefconfig`
7. mengompilasi kernel dengan `gcc-12`
8. menyalin hasil `bzImage` ke `osboot/bzImage`

Bagian pentingnya adalah:

```bash
make CC=gcc-12 HOSTCC=gcc-12 olddefconfig
make CC=gcc-12 HOSTCC=gcc-12 -j"$(nproc)" bzImage
```

`gcc-12` digunakan karena kernel 6.1.1 dapat bermasalah jika dikompilasi dengan compiler yang terlalu baru.

### 2. `single.sh`

Script `single.sh` membuat filesystem single-user. Di dalamnya dibuat folder dasar seperti:

```text
bin/
dev/
proc/
sys/
etc/
tmp/
root/
```

BusyBox disalin ke `/bin/busybox`, lalu beberapa command dibuat sebagai symbolic link, misalnya:

```text
sh, ls, cat, echo, mount, whoami, id, ping, wget, ifconfig, udhcpc
```

Script ini juga membuat:

* `/etc/passwd` berisi user `root`
* `/etc/group` berisi group `root`
* `/etc/motd` berisi banner `Farewell Party`
* `/init` sebagai proses awal saat OS boot
* `/bin/party` sebagai package manager sederhana
* `/bin/fuse_demo` saat `party install fuse` dijalankan

Filesystem kemudian dikompres menjadi:

```text
osboot/single.gz
```

### 3. `multi.sh`

Script `multi.sh` membuat filesystem multi-user. User yang dibuat adalah:

```text
root : root123
henn : henn123
hann : hann123
viii : viii123
kids : kids123
```

Script ini membuat file:

```text
/etc/passwd
/etc/group
/etc/motd
/bin/login_party
/bin/user_session
/bin/party
/init
```

Login tidak memakai sistem login Linux penuh, tetapi memakai script `login_party` yang membaca username dan password, lalu menjalankan session user dengan `su`.

Permission folder diatur menggunakan `chmod` dan `chown`, sehingga:

* `root` bisa mengakses semuanya
* `henn` bisa mengakses semua `/home/*`, tetapi tidak bisa `/root`
* `hann` bisa mengakses `/home/hann`, `/home/viii`, dan `/home/kids`
* `viii` bisa mengakses `/home/viii` dan `/home/kids`
* `kids` hanya bisa mengakses `/home/kids`

Karena ada `chown`, script ini sebaiknya dijalankan dengan:

```bash
sudo ./multi.sh
```

Output akhirnya adalah:

```text
osboot/multi.gz
```

### 4. `iso.sh`

Script `iso.sh` membuat ISO bootable menggunakan GRUB. Script ini mengambil:

```text
osboot/bzImage
osboot/single.gz
osboot/multi.gz
```

lalu memasukkannya ke folder `iso_root/` dan membuat konfigurasi GRUB dengan dua menu:

```text
Farewell Party - Single User
Farewell Party - Multi User
```

Output akhirnya:

```text
osboot/farewell.iso
```

### 5. `qemu.sh`

Script `qemu.sh` menyediakan tiga mode:

```bash
./qemu.sh --single
./qemu.sh --multi
./qemu.sh --all
```

Mode `--single` menjalankan kernel dengan `single.gz`, mode `--multi` menjalankan kernel dengan `multi.gz`, sedangkan mode `--all` menjalankan ISO `farewell.iso`.

Pada mode single dan multi, QEMU memakai opsi:

```bash
-netdev user,id=net0 -device e1000,netdev=net0
```

Opsi ini digunakan agar OS di dalam QEMU dapat memperoleh akses jaringan.

### 6. `backup.sh`

Script `backup.sh` membuat file backup dengan format:

```text
farewell_backup_DDMMYYYY-HHMMSS.zip
```

Isi backup adalah:

```text
bzImage
single.gz
multi.gz
farewell.iso
```

Jika dijalankan tanpa opsi, file asli di `osboot/` tidak dihapus. Jika dijalankan dengan opsi `--clean`, file hasil build di `osboot/` akan dihapus.

---

## Cara Menjalankan

### 1. Install dependency

```bash
sudo apt update
sudo apt install -y build-essential wget xz-utils bc bison flex libssl-dev libelf-dev \
busybox-static cpio gzip qemu-system-x86 xorriso grub-pc-bin grub-common zip \
pkg-config libfuse3-dev gcc-12 g++-12
```

### 2. Build kernel

```bash
cd soal1
chmod +x *.sh
./kernel.sh
```

Cek hasil:

```bash
ls -lh osboot/
```

Output yang diharapkan:

```text
bzImage
```

### 3. Build dan test single-user

```bash
./single.sh
./qemu.sh --single
```

Di dalam QEMU:

```sh
whoami
id
cat /etc/motd
ls /
cd /root
pwd
```

Output yang diharapkan:

```text
whoami              -> root
id                  -> uid=0(root) gid=0(root)
cat /etc/motd       -> Farewell Party / Welcome, root
ls /                -> bin dev etc init proc root sys tmp
pwd                 -> /root
```

### 4. Test internet single-user

```sh
ping -c 4 8.8.8.8
wget example.com
ls
```

Output yang diharapkan:

```text
4 packets transmitted, 4 packets received, 0% packet loss
index.html berhasil tersimpan
```

### 5. Test party dan FUSE demo

```sh
party
party list
party install fuse
fuse_demo /tmp/fusement
ls /tmp/fusement
cat /tmp/fusement/hello.txt
```

Output yang diharapkan:

```text
Available packages:
- fuse

Package fuse berhasil diinstall.
Program demo tersedia sebagai: fuse_demo

hello.txt
Hello from FUSE demo
```

### 6. Build dan test multi-user

Keluar dari QEMU terlebih dahulu. Jika shortcut tidak bisa, gunakan terminal lain:

```bash
pkill -9 -f qemu
```

Build multi-user:

```bash
sudo ./multi.sh
./qemu.sh --multi
```

Test login user:

```text
login: root
password: root123

login: henn
password: henn123

login: hann
password: hann123

login: viii
password: viii123

login: kids
password: kids123
```

Test permission:

```sh
cd /home/henn
cd /home/hann
cd /home/viii
cd /home/kids
cd /root
```

Expected permission:

| User | Akses yang Diizinkan | Akses yang Ditolak |
|---|---|---|
| root | semua direktori | - |
| henn | `/home/henn`, `/home/hann`, `/home/viii`, `/home/kids` | `/root` |
| hann | `/home/hann`, `/home/viii`, `/home/kids` | `/home/henn`, `/root` |
| viii | `/home/viii`, `/home/kids` | `/home/henn`, `/home/hann`, `/root` |
| kids | `/home/kids` | `/home/henn`, `/home/hann`, `/home/viii`, `/root` |

### 7. Build dan test ISO

```bash
./iso.sh
./qemu.sh --all
```

Yang harus muncul:

```text
Farewell Party - Single User
Farewell Party - Multi User
```

Jika memilih Single User, sistem masuk ke single-user filesystem. Jika memilih Multi User, sistem masuk ke multi-user filesystem.

### 8. Backup

```bash
./backup.sh
```

Cek hasil backup:

```bash
ls -lh
unzip -l $(ls -t farewell_backup_*.zip | head -1)
```

Isi backup yang benar:

```text
bzImage
single.gz
multi.gz
farewell.iso
```

---

## Hasil Output yang Diharapkan

### Single-user

```text
Farewell Party
Welcome, root

~ # whoami
root
~ # id
uid=0(root) gid=0(root)
```

### Multi-user

```text
Farewell Party Login

login: hann
password: hann123

Farewell Party
Welcome, hann
```

Contoh akses user `hann`:

```text
/home/hann  -> bisa
/home/viii  -> bisa
/home/kids  -> bisa
/home/henn  -> Permission denied
/root       -> Permission denied
```

### Internet

```text
ping -c 4 8.8.8.8
4 packets transmitted, 4 packets received, 0% packet loss
```

### Party dan FUSE demo

```text
party list
Available packages:
- fuse

party install fuse
Package fuse berhasil diinstall.
Program demo tersedia sebagai: fuse_demo

cat /tmp/fusement/hello.txt
Hello from FUSE demo
```

### Backup

```text
farewell_backup_DDMMYYYY-HHMMSS.zip
```

berisi:

```text
bzImage
single.gz
multi.gz
farewell.iso
```

---

## Kendala yang Dihadapi

Beberapa kendala yang muncul saat mengerjakan Soal 1:

* kernel Linux 6.1.1 sempat gagal dikompilasi karena compiler terlalu baru
* folder `osboot/` sempat kosong karena `bzImage` belum berhasil dibuat
* QEMU tidak langsung keluar dengan shortcut biasa
* internet sempat gagal karena interface belum dikonfigurasi dengan DHCP
* permission multi-user tidak sesuai jika `multi.sh` tidak dijalankan dengan `sudo`
* file hasil build sempat terhapus setelah backup
* FUSE asli cukup sulit dijalankan di root filesystem minimal

Solusi yang digunakan:

* menggunakan `gcc-12` saat kompilasi kernel
* mengecek output `bzImage`, `single.gz`, `multi.gz`, dan `farewell.iso` secara bertahap
* menggunakan `pkill -9 -f qemu` jika QEMU tidak bisa keluar
* menambahkan `ifconfig`, `udhcpc`, dan konfigurasi DNS di root filesystem
* menjalankan `sudo ./multi.sh` agar `chown` berhasil
* membuat `backup.sh` tidak menghapus file kecuali memakai opsi `--clean`
* membuat demo FUSE sederhana melalui package manager `party`

---

# Soal 2 - Final Challenge

## Deskripsi Soal

Pada soal ini, saya diminta melengkapi mini kernel/shell sederhana yang dijalankan melalui emulator. Template menyebutkan bahwa file yang perlu diedit hanya:

```text
kernel.asm
kernel.c
```

Program harus dapat menerima input keyboard, menampilkan output ke layar, dan menjalankan beberapa command sederhana, yaitu:

```text
check
add <a> <b>
sub <a> <b>
fac <n>
season <name>
triangle <n>
clear
about
help
```

Soal juga memiliki batasan:

* tidak memakai standard library
* menghindari operator pembagian `/`
* menghindari operator modulo `%`

---

## Penjelasan Solusi

Pengerjaan Soal 2 dibagi menjadi dua bagian utama.

Pertama, pada `kernel.asm`, saya melengkapi fungsi `_getChar`. Fungsi ini menggunakan interrupt BIOS `int 0x16` untuk membaca input keyboard.

Kedua, pada `kernel.c`, saya melengkapi fungsi dasar shell, seperti:

* `printChar()`
* `printString()`
* `clearScreen()`
* `readString()`
* `strcmp()`
* `startsWith()`
* `atoi()`
* `intToString()`
* `factorial()`
* handler command

Karena soal melarang penggunaan `/` dan `%`, saya membuat fungsi `divInt()` dan `modInt()` dengan pengurangan berulang. Fungsi ini digunakan ketika perlu menghitung pembagian dan sisa bagi, terutama pada `intToString()` dan perpindahan baris.

Command `add` dan `sub` juga sudah mendukung input angka negatif, misalnya:

```text
add -5 3
sub -5 3
sub 5 10
```

---

## Struktur Folder

```text
soal2/
├── Makefile
├── README.md
├── bochsrc.txt
├── bootloader.asm
├── build.sh
├── kernel.asm
└── kernel.c
```

---

## Kode Program

### 1. `kernel.asm`

```asm
bits 16

global _start
global _putInMemory
global _getChar
extern _main

_start:
    cli

    mov ax, cs
    mov ds, ax
    mov es, ax

    sti

    call _main

.hang:
    jmp .hang


_putInMemory:
    push bp
    mov bp, sp

    push ds

    mov ax, [bp+4]
    mov si, [bp+6]
    mov cl, [bp+8]

    mov ds, ax
    mov [si], cl

    pop ds

    pop bp
    ret


_getChar:
    mov ah, 0x00
    int 0x16
    xor ah, ah
    ret
```

### 2. `kernel.c`

```c
int cursor = 0;
char color = 0x07;

void putInMemory(int segment, int address, char character);
int getChar();

int divInt(int a, int b);
int modInt(int a, int b);

void printChar(char c);
void printString(char *str);
void newline();
void clearScreen();
void readString(char *buf);

int strcmp(char *a, char *b);
int startsWith(char *str, char *prefix);
int atoi(char *str);
void intToString(int num, char *buf);
int factorial(int n);
void getArg(char *cmd, int index, char *out);
void handleCommand(char *cmd);

int divInt(int a, int b) {
    int count;

    count = 0;

    while (a >= b) {
        a = a - b;
        count++;
    }

    return count;
}

int modInt(int a, int b) {
    while (a >= b) {
        a = a - b;
    }

    return a;
}

void printChar(char c) {
    int addr;
    int col;

    if (c == '\n') {
        col = modInt(cursor, 80);
        cursor = cursor + (80 - col);
        return;
    }

    if (c == '\b') {
        if (cursor > 0) {
            cursor--;
            addr = cursor * 2;
            putInMemory(0xB800, addr, ' ');
            putInMemory(0xB800, addr + 1, color);
        }
        return;
    }

    addr = cursor * 2;
    putInMemory(0xB800, addr, c);
    putInMemory(0xB800, addr + 1, color);
    cursor++;

    if (cursor >= 80 * 25) {
        clearScreen();
    }
}

void printString(char *str) {
    int i;

    i = 0;

    while (str[i] != 0) {
        printChar(str[i]);
        i++;
    }
}

void newline() {
    printChar('\n');
}

void clearScreen() {
    int i;
    int addr;

    for (i = 0; i < 80 * 25; i++) {
        addr = i * 2;
        putInMemory(0xB800, addr, ' ');
        putInMemory(0xB800, addr + 1, color);
    }

    cursor = 0;
}

void readString(char *buf) {
    int i;
    char c;

    i = 0;

    while (1) {
        c = getChar();

        if (c == 13) {
            buf[i] = 0;
            return;
        }

        if (c == 8) {
            if (i > 0) {
                i--;
                printChar('\b');
            }
        } else {
            if (i < 63) {
                buf[i] = c;
                i++;
                printChar(c);
            }
        }
    }
}

int strcmp(char *a, char *b) {
    int i;

    i = 0;

    while (a[i] != 0 && b[i] != 0) {
        if (a[i] != b[i]) {
            return 0;
        }
        i++;
    }

    if (a[i] == b[i]) {
        return 1;
    }

    return 0;
}

int startsWith(char *str, char *prefix) {
    int i;

    i = 0;

    while (prefix[i] != 0) {
        if (str[i] != prefix[i]) {
            return 0;
        }
        i++;
    }

    return 1;
}

int atoi(char *str) {
    int i;
    int result;
    int sign;

    i = 0;
    result = 0;
    sign = 1;

    while (str[i] == ' ') {
        i++;
    }

    if (str[i] == '-') {
        sign = -1;
        i++;
    }

    while (str[i] >= '0' && str[i] <= '9') {
        result = result * 10 + (str[i] - '0');
        i++;
    }

    return result * sign;
}

void intToString(int num, char *buf) {
    int i;
    int j;
    int temp;
    char rev[16];

    i = 0;

    if (num == 0) {
        buf[0] = '0';
        buf[1] = 0;
        return;
    }

    if (num < 0) {
        buf[i] = '-';
        i++;
        num = -num;
    }

    j = 0;

    while (num > 0) {
        temp = modInt(num, 10);
        rev[j] = temp + '0';
        num = divInt(num, 10);
        j++;
    }

    while (j > 0) {
        j--;
        buf[i] = rev[j];
        i++;
    }

    buf[i] = 0;
}

int factorial(int n) {
    int i;
    int result;

    result = 1;

    if (n < 0) {
        return -1;
    }

    if (n > 7) {
        return -1;
    }

    for (i = 1; i <= n; i++) {
        result = result * i;
    }

    return result;
}

void getArg(char *cmd, int index, char *out) {
    int i;
    int arg;
    int j;

    i = 0;
    arg = 0;
    j = 0;

    while (cmd[i] != 0 && cmd[i] != ' ') {
        i++;
    }

    while (cmd[i] == ' ') {
        i++;
    }

    while (arg < index) {
        while (cmd[i] != 0 && cmd[i] != ' ') {
            i++;
        }

        while (cmd[i] == ' ') {
            i++;
        }

        arg++;
    }

    while (cmd[i] != 0 && cmd[i] != ' ') {
        out[j] = cmd[i];
        i++;
        j++;
    }

    out[j] = 0;
}

void handleCommand(char *cmd) {
    char arg1[32];
    char arg2[32];
    char result[32];
    int a;
    int b;
    int res;
    int i;
    int j;

    if (strcmp(cmd, "check")) {
        printString("ok");
        newline();
        return;
    }

    if (strcmp(cmd, "help")) {
        printString("check add sub fac season triangle clear about");
        newline();
        return;
    }

    if (strcmp(cmd, "about")) {
        printString("Assistant's Last Gift");
        newline();
        return;
    }

    if (strcmp(cmd, "clear")) {
        clearScreen();
        return;
    }

    if (startsWith(cmd, "add ")) {
        getArg(cmd, 0, arg1);
        getArg(cmd, 1, arg2);

        a = atoi(arg1);
        b = atoi(arg2);
        res = a + b;

        intToString(res, result);
        printString(result);
        newline();
        return;
    }

    if (startsWith(cmd, "sub ")) {
        getArg(cmd, 0, arg1);
        getArg(cmd, 1, arg2);

        a = atoi(arg1);
        b = atoi(arg2);
        res = a - b;

        intToString(res, result);
        printString(result);
        newline();
        return;
    }

    if (startsWith(cmd, "fac ")) {
        getArg(cmd, 0, arg1);

        a = atoi(arg1);
        res = factorial(a);

        if (res < 0) {
            printString("know your limit little bro.");
            newline();
        } else {
            intToString(res, result);
            printString(result);
            newline();
        }

        return;
    }

    if (startsWith(cmd, "season ")) {
        getArg(cmd, 0, arg1);

        if (strcmp(arg1, "winter")) {
            color = 0x09;
            printString("winter mode");
        } else if (strcmp(arg1, "spring")) {
            color = 0x0A;
            printString("spring mode");
        } else if (strcmp(arg1, "summer")) {
            color = 0x0E;
            printString("summer mode");
        } else if (strcmp(arg1, "fall")) {
            color = 0x06;
            printString("fall mode");
        } else if (strcmp(arg1, "radiant")) {
            color = 0x0D;
            printString("radiant mode");
        } else {
            printString("unknown season");
        }

        newline();
        return;
    }

    if (startsWith(cmd, "triangle ")) {
        getArg(cmd, 0, arg1);
        a = atoi(arg1);

        if (a < 0) {
            printString("triangle size must be positive");
            newline();
            return;
        }

        for (i = 1; i <= a; i++) {
            for (j = 0; j < i; j++) {
                printChar('x');
            }
            newline();
        }

        return;
    }

    printString("unknown command");
    newline();
}

void main() {
    char cmd[64];

    clearScreen();

    printString("Welcome to Assistant's Last Gift");
    newline();

    printString("type 'help'");
    newline();
    newline();

    while (1) {
        printString("> ");

        readString(cmd);

        newline();

        handleCommand(cmd);

        newline();
    }
}
```

### 3. `Makefile`

```makefile
prepare:
	dd if=/dev/zero of=floppy.img bs=512 count=2880

bootloader:
	nasm -f bin bootloader.asm -o bootloader.bin
	dd if=bootloader.bin of=floppy.img bs=512 count=1 conv=notrunc

kernel:
	nasm -f as86 kernel.asm -o kernel-asm.o
	bcc -ansi -c kernel.c -o kernel.o
	ld86 -0 -d -o kernel.bin kernel-asm.o kernel.o
	dd if=kernel.bin of=floppy.img bs=512 seek=1 conv=notrunc

build: prepare bootloader kernel

run:
	qemu-system-i386 -drive file=floppy.img,format=raw,if=floppy -boot a

clean:
	rm -f floppy.img bootloader.bin kernel.bin kernel.o kernel-asm.o bochslog.txt
```

---

## Penjelasan Kode per Bagian

### 1. `_getChar()` pada `kernel.asm`

```asm
_getChar:
    mov ah, 0x00
    int 0x16
    xor ah, ah
    ret
```

Fungsi ini membaca input keyboard melalui BIOS interrupt `0x16`. Karakter yang ditekan dikembalikan melalui register `AL`. Karena fungsi C menerima nilai integer, register `AH` dibersihkan dengan `xor ah, ah`.

### 2. `putInMemory()`

Fungsi `putInMemory()` dipakai untuk menulis karakter langsung ke memory video VGA pada segmen `0xB800`. Fungsi ini dipanggil dari `kernel.c` ketika mencetak karakter.

### 3. `printChar()`

Fungsi ini mencetak satu karakter ke layar. Jika karakter adalah newline, cursor akan dipindahkan ke awal baris berikutnya. Jika karakter adalah backspace, karakter sebelumnya dihapus dari layar.

Karena tidak memakai `%`, kolom cursor dihitung dengan:

```c
col = modInt(cursor, 80);
```

### 4. `printString()`

Fungsi ini mencetak string dengan cara memanggil `printChar()` untuk setiap karakter sampai menemukan karakter null `0`.

### 5. `clearScreen()`

Fungsi ini mengosongkan seluruh layar VGA text mode. Layar dianggap berukuran 80 x 25 karakter. Setiap karakter ditulis sebagai spasi dengan atribut warna aktif.

### 6. `readString()`

Fungsi ini membaca input keyboard karakter demi karakter menggunakan `getChar()`. Input berhenti ketika user menekan Enter. Backspace juga ditangani agar user bisa menghapus karakter.

### 7. `strcmp()` dan `startsWith()`

`strcmp()` dipakai untuk membandingkan command penuh, seperti `check` atau `clear`.

`startsWith()` dipakai untuk command yang memiliki argumen, seperti:

```text
add 5 3
sub 10 2
fac 6
season winter
triangle 5
```

### 8. `atoi()`

Fungsi `atoi()` mengubah string menjadi angka. Pada versi ini, input negatif juga didukung dengan membaca tanda `-` di awal string.

Contoh:

```text
-5 -> -5
10 -> 10
```

### 9. `intToString()`

Fungsi ini mengubah integer menjadi string agar bisa dicetak. Karena operator `/` dan `%` dihindari, fungsi ini memakai:

```c
divInt()
modInt()
```

### 10. `factorial()`

Fungsi `factorial()` menghitung faktorial dari angka kecil. Jika input negatif atau terlalu besar, fungsi mengembalikan `-1`.

Batas yang dipakai adalah `7`, karena sistem berjalan pada lingkungan 16-bit sehingga angka faktorial besar dapat menyebabkan overflow.

### 11. `handleCommand()`

Fungsi ini menjadi pusat pengendali command. Command yang dikenali:

* `check`
* `help`
* `about`
* `clear`
* `add`
* `sub`
* `fac`
* `season`
* `triangle`

Jika command tidak dikenali, program mencetak:

```text
unknown command
```

### 12. `main()`

Fungsi `main()` membersihkan layar, menampilkan pesan pembuka, lalu menjalankan shell loop.

Alur shell:

```text
tampilkan prompt >
baca input user
jalankan command handler
ulangi terus
```

---

## Cara Menjalankan

### 1. Install dependency

```bash
sudo apt update
sudo apt install -y nasm bcc bin86 qemu-system-x86 bochs bochs-sdl bochsbios vgabios
```

### 2. Build

```bash
cd soal2
make build
```

File yang terbentuk:

```text
floppy.img
bootloader.bin
kernel.bin
kernel.o
kernel-asm.o
```

### 3. Run

```bash
make run
```

Atau bisa juga menjalankan langsung dengan QEMU:

```bash
qemu-system-i386 -drive file=floppy.img,format=raw,if=floppy -boot a
```

---

## Hasil Output yang Diharapkan

Saat berhasil boot, layar akan menampilkan:

```text
Welcome to Assistant's Last Gift
type 'help'

>
```

### Test command

```text
check
```

Output:

```text
ok
```

```text
help
```

Output:

```text
check add sub fac season triangle clear about
```

```text
add 5 3
```

Output:

```text
8
```

```text
add -5 3
```

Output:

```text
-2
```

```text
sub 10 2
```

Output:

```text
8
```

```text
sub 5 10
```

Output:

```text
-5
```

```text
fac 6
```

Output:

```text
720
```

```text
fac 120
```

Output:

```text
know your limit little bro.
```

```text
season winter
season spring
season summer
season fall
season radiant
```

Output yang diharapkan:

```text
winter mode
spring mode
summer mode
fall mode
radiant mode
```

Warna teks berubah sesuai season yang dipilih.

```text
triangle 5
```

Output:

```text
x
xx
xxx
xxxx
xxxxx
```

```text
about
```

Output:

```text
Assistant's Last Gift
```

```text
clear
```

Output:

```text
layar dibersihkan
```

---

## Kendala yang Dihadapi

Beberapa kendala yang muncul saat mengerjakan Soal 2:

* `nasm`, `bcc`, `bin86`, atau `bochs` belum terinstall
* path BIOS pada `bochsrc.txt` belum sesuai
* Bochs sempat masuk debugger dan perlu command `c` untuk melanjutkan
* QEMU/Bochs sempat black screen
* ada typo pada `kernel.asm`
* penggunaan operator `%` menyebabkan error `undefined symbol: imod`
* fungsi `atoi()` awalnya belum membaca tanda minus (`-`), sehingga command seperti `add -5 3` belum menghasilkan nilai negatif yang benar
* linking kernel sempat salah urutan

Solusi yang digunakan:

* menginstall dependency yang diperlukan
* memperbaiki path BIOS pada `bochsrc.txt`
* memakai QEMU agar proses demo lebih mudah
* memperbaiki `_getChar()` pada `kernel.asm`
* menghindari `/` dan `%` dengan `divInt()` dan `modInt()`
* memperbaiki `atoi()` agar membaca tanda minus di awal input dan mengubahnya menjadi bilangan negatif
* memastikan linking menggunakan urutan `kernel-asm.o` sebelum `kernel.o`

---