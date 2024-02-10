#!/bin/bash

# Экспортирую переменную PATH
# для работоспособности
export PATH="$PATH:/usr/sbin:/sbin:/bin:/usr/bin"

# Имя хоста
echo "${HOST_NAME}" > /etc/hostname
tee /etc/hosts > /dev/null << EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOST_NAME.localdomain $HOST_NAME
EOF

# Не предлогать мне пакеты
tee /etc/apt/apt.conf.d/80nosug.conf > /dev/null << EOF
APT::Install-Suggests "false";
EOF

# Оптимизация зеркал с помощью Netselect-apt
# LOCATION=$(curl -s https://ipinfo.io/country)
# netselect-apt -a amd64 -c "${LOCATION}" -n -o /etc/apt/sources.list "${SUITE}"
# Добавляю non-free-firmware репозиторий
# add-apt-repository non-free-firmware

# Ручное добавление зеркал
# TODO: Может добавить backports? Linux ядро и другие пакеты будут по свежее,
# однако свежие драйвера графики Nvidia и AMD (mesa) пока не предвидятся в будущем
tee /etc/apt/sources.list > /dev/null << EOF
deb [arch=amd64,i386] http://ftp.ru.debian.org/debian/ $SUITE main contrib non-free non-free-firmware
deb [arch=amd64,i386] http://mirror.docker.ru/debian/ $SUITE main contrib non-free non-free-firmware
deb [arch=amd64,i386] http://mirror.truenetwork.ru/debian/ $SUITE main contrib non-free non-free-firmware
deb [arch=amd64,i386] http://security.debian.org/debian-security $SUITE-security main contrib non-free non-free-firmware
EOF

# Запускается генератор локалей
# Выбрал en_US.UTF-8 UTF-8 и ru_RU.UTF-8 UTF-8
# Потом по умолчанию для окружения системы выставил ru_RU.UTF-8
dpkg-reconfigure locales

# Приятная сортировка и сравнения строк
echo "LC_COLLATE=C" | tee -a /etc/default/locale > /dev/null

# Принудительно использовать выставленный язык
source /etc/default/locale

# Запускается настройка часового пояса
dpkg-reconfigure tzdata

# Запускается настройщик tty и консоли
# UTF-8 - Cyrillic - Slavic languages (also Bosnian and Serbian Latin)
# Для себя я используя TerminusBold с размеров 11x22
# TODO: Более приятный шрифт но только мелкий ruscii_8x16
dpkg-reconfigure console-setup

# Запускается настройщик раскладки
# Модель Обычная 105, Другая, страна первой раскладки Русская,
# раскладка Русская, способ переключения Alt+Shift, нет временного переключателя
# обычная раскладка клавиатуры, нет ключа compose
dpkg-reconfigure keyboard-configuration

# Установка необходимых пакетов
# FIXME: Установка должна происходить из входного файла с обработкой
apt update
eatmydata apt install -yy linux-image-amd64 linux-headers-amd64 firmware-misc-nonfree firmware-linux-nonfree sudo vim systemd-zram-generator zstd git zsh htop neofetch wget dbus-broker efibootmgr efivar command-not-found manpages man-db grub-efi-amd64 plocate fonts-terminus network-manager ssh build-essential ca-certificates xdg-user-dirs

# Добавление глобальных переменных системы
tee -a /etc/environment > /dev/null << EOF

# Принудительно включаю icd RADV драйвер (если установлен)
AMD_VULKAN_ICD=RADV
EOF

# Не знаю будет ли работать?
# Для работы граф. планшета Xp-Pen G640 с OpenTabletDriver
echo "blacklist hid_uclogic" > /etc/modprobe.d/blacklist.conf

# Отключение системного звукового сигнала
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

# Установка универсального host файла от StevenBlack (убирает рекламу и вредоносы из WEB'а)
# Обновление host файла выполняется командой: $ uphosts (доступна в dotfiles/base/zsh/funtctions.zsh)
wget -qO- https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts \
 | grep '^0\.0\.0\.0' \
 | grep -v '^0\.0\.0\.0 [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*$' \
 | sed '1s/^/\n/' \
 | tee --append /etc/hosts >/dev/null

# Не позволять системе становится раздудой
# Выставляю максимальный размер журнала systemd
sed -i 's/#SystemMaxUse=/SystemMaxUse=50M/g' /etc/systemd/journald.conf

# Разрешение на вход по SSH отключено для пользователя root
sed -ri -e "s/^#PermitRootLogin.*/PermitRootLogin\ no/g" /etc/ssh/sshd_config

# Пароль root пользователя
echo "root:${USER_PASSWORD}" | chpasswd

# Добавления юзера с созданием $HOME и присваивание групп к юзеру, оболочка zsh
# Так как не существует wheel группа нужно просто присвоить sudo группу пользователю
# bluetooth почему-то тоже не существует
useradd -m -G sudo,adm,dialout,dip,plugdev,netdev,audio,video,input,cdrom,users,uucp,games -s /bin/zsh "${USER_NAME}"

# Пароль пользователя
echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd

# Не добавлять в $HOME каждый раз при использовании sudo файл .sudo_as_admin_successful
tee /etc/sudoers.d/disable-admin-file-in-home >/dev/null <<EOT
# Disable ~/.sudo_as_admin_successful file
Defaults !admin_flag
EOT

# Создание пользовательских XDG директорий
# Используются английские названия для удобной работы с терминала
LC_ALL=C sudo -u "${USER_NAME}" xdg-user-dirs-update --force

# Настройка snapper и btrfs в случае обнаружения
if [ "${FS}" = 'btrfs' ]; then

  # BTRFS пакеты:
  apt install -yy btrfs-progs btrfsmaintenance

  # Snapper пакеты
  apt install -yy inotify-tools gawk python3-btrfsutil snapper

  # Размонтируем и удаляем /.snapshots и /home/.snapshots
  umount -v /.snapshots /home/.snapshots
  rm -rfv /.snapshots /home/.snapshots

  # Создаю конфигурацию Snapper для / и /home
  # Snapper отслеживать /home будет создавать снимки всех пользователей (если они присутствуют)
  snapper --no-dbus -c root create-config /
  snapper --no-dbus -c home create-config /home

  # Удаляем подтом /.snapshots и /home/.snapshots Snapper'а
  btrfs subvolume delete /.snapshots /home/.snapshots

  # Пересоздаём и переподключаем /.snapshots и /home/.snapshots
  mkdir -v /.snapshots /home/.snapshots
  mount -v -a

  # Меняем права доступа для легкой замены снимка @ в любое время без потери снимков snapper.
  chmod -v 750 /.snapshots /home/.snapshots

  # Доступ к снимкам для non-root пользователям
  chown -vR :sudo /.snapshots /home/.snapshots

  # Настройка Snapper

  # Синхронизировать права на доступ к снимкам при создании и удалении
  sed -i "s|^SYNC_ACL=.*|SYNC_ACL=\"yes\"|g" /etc/snapper/configs/root
  sed -i "s|^SYNC_ACL=.*|SYNC_ACL=\"yes\"|g" /etc/snapper/configs/home

  # Установка лимата снимков для /
  sed -i "s|^TIMELINE_LIMIT_HOURLY=.*|TIMELINE_LIMIT_HOURLY=\"3\"|g" /etc/snapper/configs/root
  sed -i "s|^TIMELINE_LIMIT_DAILY=.*|TIMELINE_LIMIT_DAILY=\"6\"|g" /etc/snapper/configs/root
  sed -i "s|^TIMELINE_LIMIT_WEEKLY=.*|TIMELINE_LIMIT_WEEKLY=\"0\"|g" /etc/snapper/configs/root
  sed -i "s|^TIMELINE_LIMIT_MONTHLY=.*|TIMELINE_LIMIT_MONTHLY=\"0\"|g" /etc/snapper/configs/root
  sed -i "s|^TIMELINE_LIMIT_YEARLY=.*|TIMELINE_LIMIT_YEARLY=\"0\"|g" /etc/snapper/configs/root

  # Не создавать timeline-снимки для /home
  sed -i "s|^TIMELINE_CREATE=.*|TIMELINE_CREATE=\"no\"|g" /etc/snapper/configs/home

  # Plocate не показывает индексы найденых файлов если используется файловая система Btrfs
  # Данная правка конфига исправляет это
  # Источник: https://devctrl.blog/posts/plocate-not-a-drop-in-replacement-if-you-re-using-btfrs/
  sed -i 's/PRUNE_BIND_MOUNTS =.*/PRUNE_BIND_MOUNTS = "no"/' /etc/updatedb.conf

  # Предотвращение индексирования снимков программой "updatedb", что замедляло бы работу системы
  sed -i '/PRUNEPATHS/s/"$/ \/\.btrfsroot \/\.snapshots \/home\/\.snapshots"/' /etc/updatedb.conf

  # Не создавать снимки при загрузке системы
  systemctl disable snapper-boot.timer

  # Обслуживание BTRFS (btrfsmaintenance)
  systemctl enable btrfs-scrub.timer

  # Меню снимков Grub-Btrfs
  git clone https://github.com/Antynea/grub-btrfs /tmp/grub-btrfs
  pushd /tmp/grub-btrfs
  make install
  systemctl enable grub-btrfsd
  popd

  # Устанавливаем простой и удобный CLI инструмент для отката системы внутри снимка
  # Использование: sudo snapper-rollback <номер_снимка>
  git clone https://github.com/jrabinow/snapper-rollback.git /tmp/snapper-rollback
  pushd /tmp/snapper-rollback
  cp -v snapper-rollback.py /usr/local/bin/snapper-rollback
  cp -v snapper-rollback.conf /etc/
  # Редактирую конфигурационный файл snapper-rollback что точка монтирования /.btrfsroot
  sed -i "s|^mountpoint.*|mountpoint = /.btrfsroot|" /etc/snapper-rollback.conf
  popd

  # Другой APT хук для подробного описания пакетов pre и post снимка
  git clone https://github.com/pavinjosdev/snap-apt.git /tmp/snap-apt
  pushd /tmp/snap-apt
  chmod -v 755 scripts/snap_apt.py
  cp -v scripts/snap_apt.py /usr/bin/snap-apt
  cp -v hooks/80snap-apt /etc/apt/apt.conf.d/
  cp -v logrotate/snap-apt /etc/logrotate.d/
  rm -fv /etc/apt/apt.conf.d/80snapper
  sed -i 's/DISABLE_APT_SNAPSHOT="no"/DISABLE_APT_SNAPSHOT="yes"/g' /etc/default/snapper
  popd
fi

# Set plymouth theme
# plymouth-set-default-theme -R moonlight

# Размер Zram
tee -a /etc/systemd/zram-generator.conf >> /dev/null << EOF
zram-size = min(min(ram, 4096) + max(ram - 4096, 0) / 2, 32 * 1024)
compression-algorithm = zstd
EOF

# TODO: добавить мои sysctl настройки

# Добавления моих опций ядра grub
# intel_iommu=on - Включает драйвер intel iommu
# iommu=pt - Проброс только тех устройств которые поддерживаются
# zswap.enabled=0 - Отключает приоритетный zswap который заменяется на zram
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 mitigations=off intel_iommu=on iommu=pt amdgpu.ppfeaturemask=0xffffffff cpufreq.default_governor=performance zswap.enabled=0"/g' /etc/default/grub

# Рекурсивная правка разрешений в папке скриптов
chmod -R 700 /debianinstall
chown -R 1000:users /debianinstall

# Установка и настройка Grub
#sed -i -e 's/#GRUB_DISABLE_OS_PROBER/GRUB_DISABLE_OS_PROBER/' /etc/default/grub # Обнаруживать другие ОС и добавлять их в grub (нужен пакет os-prober)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
update-grub
