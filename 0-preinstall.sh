#!/bin/bash

# Позаимствовано
# https://github.com/gtrogdon/linux-install-scripts

# Минимальный скрипт установки Debian

# Русские шрифты
setfont cyr-sun16
sed -i "s/#\(en_US\.UTF-8\)/\1/; s/#\(ru_RU\.UTF-8\)/\1/" /etc/locale.gen
locale-gen
export LANG=ru_RU.UTF-8

clear

# Синхронизация часов материнской платы
timedatectl set-ntp true

# Выпуск Debian
export SUITE="stable"

read -p "Имя хоста (пустое поле - debian): " HOST_NAME
export HOST_NAME=${HOST_NAME:-debian}

read -p "Имя пользователя (Может быть только в нижнем регистре и без знаков, пустое поле - user): " USER_NAME
export USER_NAME=${USER_NAME:-user}

read -p "Пароль пользователя: " USER_PASSWORD
export USER_PASSWORD

PS3="Выберите диск, на который будет установлен Debian: "
select ENTRY in $(lsblk -dpnoNAME | grep -P "/dev/sd|nvme|vd"); do
	export DISK=$ENTRY
	export DISK_EFI=${DISK}1
	export DISK_MNT=${DISK}2
	# export DISK_HOME=${DISK}3
	echo "Установка Debian на ${DISK}."
	break
done

PS3="Выберите файловую систему: "
select ENTRY in "ext4" "btrfs"; do
	export FS=$ENTRY
	echo "Выбран ${FS}."
	break
done

# Удаляем старую схему разделов и перечитываем таблицу разделов
sgdisk --zap-all --clear $DISK # Удаляет (уничтожает) структуры данных GPT и MBR
partprobe $DISK # Информировать ОС об изменениях в таблице разделов

# Разметка диска и перечитываем таблицу разделов
sgdisk -n 0:0:+512MiB -t 0:ef00 -c 0:boot $DISK
sgdisk -n 0:0:0 -t 0:8300 -c 0:root $DISK
partprobe $DISK

# Файловая система
if [ ${FS} = 'ext4' ]; then
	yes | mkfs.ext4 -L DebianLinux $DISK_MNT
	# Отдельный раздел под /home
	# yes | mkfs.ext4 -L home $DISK_HOME
	mount -v $DISK_MNT /mnt
	# mkdir /mnt/home
	# mount $DISK_HOME /mnt/hom

elif [ ${FS} = 'btrfs' ]; then
	mkfs.btrfs -L DebianLinux -f $DISK_MNT
	mount -v $DISK_MNT /mnt

	btrfs su cr /mnt/@
	btrfs su cr /mnt/@home
	btrfs su cr /mnt/@snapshots
	btrfs su cr /mnt/@home_snapshots
	btrfs su cr /mnt/@var_log
	btrfs su cr /mnt/@var_lib_containers
	btrfs su cr /mnt/@var_lib_docker
	btrfs su cr /mnt/@var_lib_machines
	btrfs su cr /mnt/@var_lib_portables
	btrfs su cr /mnt/@var_lib_libvirt_images
	btrfs su cr /mnt/@var_lib_AccountsService
	btrfs su cr /mnt/@var_lib_gdm

	umount -v /mnt

	# BTRFS сам обнаруживает и добавляет опцию "ssd" при монтировании
	# BTRFS с версией ядра 6.2 по умолчанию включена опция "discard=async"
	# TODO: Добавить подтом @var_lib_blueman (/var/lib/blueman) для использования bluetooth мышек внутри read-only снимка?
	mount -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@ $DISK_MNT /mnt
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@home $DISK_MNT /mnt/home
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@snapshots $DISK_MNT /mnt/.snapshots
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@home_snapshots $DISK_MNT /mnt/home/.snapshots
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_log $DISK_MNT /mnt/var/log
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_containers $DISK_MNT /mnt/var/lib/containers
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_docker $DISK_MNT /mnt/var/lib/docker
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_machines $DISK_MNT /mnt/var/lib/machines
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_portables $DISK_MNT /mnt/var/lib/portables
	mount --mkdir -v -o noatime,nodatacow,compress=zstd:2,space_cache=v2,subvol=@var_lib_libvirt_images $DISK_MNT /mnt/var/lib/libvirt/images
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvolid=5 $DISK_MNT /mnt/.btrfsroot
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_AccountsService $DISK_MNT /mnt/var/lib/AccountsService
	mount --mkdir -v -o noatime,compress=zstd:2,space_cache=v2,subvol=@var_lib_gdm $DISK_MNT /mnt/var/lib/gdm3

	# Востановление прав доступа по требованию пакетов
	chmod -v 775 /mnt/var/lib/AccountsService/
	chmod -v 1770 /mnt/var/lib/gdm3/
else
	echo "FS type"
	exit 1
fi

# Форматирование и монтирование загрузочного раздела
yes | mkfs.fat -F32 -n BOOT $DISK_EFI
mount -v --mkdir $DISK_EFI /mnt/boot/efi

# Установка необходимых пакетов
pacman -Sy --noconfirm debootstrap debian-archive-keyring

# Установка базовой системы с некоторыми пакетами
debootstrap --arch amd64 --include locales,console-setup,console-setup-linux,eatmydata $SUITE /mnt http://ftp.ru.debian.org/debian/

# Выполняю bind монтирование для подготовки к chroot
for i in dev proc sys; do
  mount -v --rbind "/$i" "/mnt/$i"; mount -v --make-rslave "/mnt/$i"
done

# Генерирую fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Добавление дополнительных разделов
tee -a /mnt/etc/fstab >/dev/null << EOF
# tmpfs
# Чтобы не изнашивать SSD во время сборки
# Также без него не запускается Xorg и все systemd сервисы при загрузке в Read-only снимок Grub-Btrfs
tmpfs                   /tmp            tmpfs           rw,nosuid,nodev,noatime,size=4G,mode=1777,inode64   0 0

# /dev/sdb
# Мои дополнительные разделы HDD диска
UUID=F46C28716C2830B2   /media/Distrib  ntfs-3g         rw,nofail,errors=remount-ro,noatime,prealloc,fmask=0022,dmask=0022,uid=1000,gid=984,windows_names   0 0
UUID=CA8C4EB58C4E9BB7   /media/Other    ntfs-3g         rw,nofail,errors=remount-ro,noatime,prealloc,fmask=0022,dmask=0022,uid=1000,gid=984,windows_names   0 0
UUID=A81C9E2F1C9DF890   /media/Media    ntfs-3g         rw,nofail,errors=remount-ro,noatime,prealloc,fmask=0022,dmask=0022,uid=1000,gid=984,windows_names   0 0
UUID=30C4C35EC4C32546   /media/Games    ntfs-3g         rw,nofail,errors=remount-ro,noatime,prealloc,fmask=0022,dmask=0022,uid=1000,gid=984,windows_names   0 0
EOF

# Зачем-то копирует идентичный DNS resolv.conf в /mnt
# Copy DNS info over
# cp /etc/resolv.conf /mnt/etc/resolv.conf

# Копирование папки установочных скриптов
cp -r /root/debianinstall /mnt

# Chroot'имся
chroot /mnt /bin/bash /debianinstall/1-chroot.sh

# Действия после chroot
if read -re -p "chroot /mnt? [y/N]: " ans && [[ $ans == 'y' || $ans == 'Y' ]]; then
	chroot /mnt ; echo "Не забудьте самостоятельно размонтировать /mnt перед reboot!"
else
	umount -R /mnt
fi
