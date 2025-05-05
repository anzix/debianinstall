# Мой скрипт установки Debian Linux (Для личного использования)

Установка Debian из под [образа Arch Linux](https://archlinux.org/download/)

> Также присутствует метод установки из под [Debian ISO образа вариации Standard](https://github.com/anzix/debianinstall/tree/debiso)

После загрузки Arch Linux образа ISO необходимо подождать минуту чтобы сервис `pacman-init.service` **успешно** инициализировал связку ключей\
Если всё же вы столкнулись с ключами при скачивании git просто выполните `systemctl restart pacman-init.service` и снова произойдёт инициализация ключей\

## [Для ноутбуков] Установка Wi-Fi-соединения и проверка сети

Вот что нужно делать как только вы вошли в установщик Arch Linux

```sh
# Необходимо узнать сетевой интерфейс устройства (device)
ip a

# Входим в интерактивный промпт
iwctl

# Сканируем на наличие новых сетей
# Вместо `device` должен быть ваш интерфейс полученный из предыдущей команды
[iwd] station device scan

# Выводим список сетей
[iwd] station device get-networks

# Подключаемся к сети заполняя свои данные
[iwd] station device connect SSID --passphrase ""

# Проверяем сеть
ping archlinux.org
```

***

Обновляем зеркала и устанавливаем git

```sh
pacman -Sy git
```

Клонируем репо и переходим в него

```sh
git clone https://github.com/anzix/debianinstall && cd debianinstall
```

> Перед тем как начать установку пробегитесь по выбору пакетов которые я указал в ``packages/base`` открыв любым текстовым редактором vim или nano\
> Выберете (закомментировав/раскомментировав) используя # (хэш) те пакеты которые вы нуждаетесь\
> Предоставляется выбор для драйверов между AMD и Nvidia

Начинаем установку

```sh
./0-preinstall.sh
```

Как только установка завершится вам нужно перезагрузится командой `sudo reboot` и вытащить носитель\
И вас будет встречать чистый Debian 12

## Установка софта из моих файлов

Перемещаем папку со скриптами в домашнюю директорию

```sh
sudo mv /debianinstall ~
cd ~/debianinstall

# Установка базовых пакетов с обработкой используя sed
sudo apt install $(sed -e '/^#/d' -e 's/#.*//' -e "s/'//g" -e '/^\s*$/d' -e 's/ /\n/g' packages/base | column -t)
```

Подобным образом вместо `base` вставляем другой файл

## Для тестирования на виртуалке

1. Для QEMU/KVM качаем пакеты `qemu-guest-agent spice-vdagent xserver-xorg-video-qxl xserver-xspice`

> В оконных менеджерах (WM) для активации Shared Clipboard в терминале надо ввести `spice-vdagent`

2. Для VirtualBox (не проверенно):

   - Качаем пакеты `virtualbox-guest-addition-iso xserver-xorg-video-vmware`
   - Присваиваем пользователю группу vboxfs командой `usermod -a -G vboxsf $(whoami)`
   <!-- - Активируем systemd сервис `sudo systemctl enable vboxservice.service` -->

## Восстановление Debian, chroot из под LiveISO если выбрали Btrfs

Используя ISO образ [Arch Linux](https://archlinux.org/download/)

```sh
# Монтируем
mount -v -o subvol=@ /dev/vda2 /mnt
mount -v /dev/vda1 /mnt/boot/efi
for i in dev proc sys; do
  mount -v --rbind "/$i" "/mnt/$i"; mount -v --make-rslave "/mnt/$i"
done

# Без экспорта этой переменной я не мог чрутнутся
export PATH="$PATH:/usr/sbin:/sbin:/bin:/usr/bin"

# Чрутимся
chroot /mnt
```

## Установка шрифтов семейства Nerd в Debian

Так как нету данных шрифтов в репозиториях придётся устанавливать их вручную\
Выполняем данный скрипт и выбираем шрифт на выбор и готово.

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.sh)"
```

## TODO: Установка Wine и Steam

Так как я уже добавил в ``/etc/apt/sources.list`` поддержку архитектуры i386 все необходимые библиотеки wine будут включены

```sh
# Установка всех пакетов wine
sudo apt install wine wine64 libwine libwine:i386 fonts-wine

# Установка steam amd64 вместе с i386 библиотеками
sudo apt install steam-installer
```

### Ускорение скачивания игр Steam (из пакетного менеджера)

Прирост скачивания очень заметен, в 3 раза быстрее

```sh
tee $HOME/.steam/steam/steam_dev.cfg > /dev/null << EOF
@nClientDownloadEnableHTTP2PlatformLinux 0
@fDownloadRateImprovementToAddAnotherConnection 1.0
EOF
```

## TODO: Пакеты для ноутбуков (на заметку)

```sh
firmware-iwlwifi # Беспроводные драйвера
task-laptop # Мета-пакет необходимых программ для ноутбука
powertop # Мониторинг энергопотребления и управлением питанием
```

## TODO: Апгрейд на новую маджорную версию Debian (возможно с 12 Bookworm на 13 Trixie)

Просто выполняем

```sh
sudo apt dist-upgrade
# Или
sudo apt full-upgrade # при вопросе не нажимайте автоматически yes, оно может удалить пакеты которые вы хотите оставить
```

## Проприетарные драйвера Nvidia (не проверено)

1. Убедитесь чтобы в ``/etc/apt/sources.list`` был non-free-firmware репозиторий
2. И был скачен пакет: `firmware-mics-nonfree`

Скачиваем пакеты nvidia:

```sh
sudo apt install nvidia-driver nvidia-cuda-dev nvidia-cuda-toolkit
```

Если не уверены о выборе драйвера качаем пакет

```su
sudo apt install nvidia-detect
```

И запускаем командой: `nvidia-detect`

Дополнительно открываем с root привилегиями редактором ``/etc/default/grub`` и прописываем

```conf
...
GRUB_CMDLINE_LINUX_DEFAULT="quiet nvidia-drm.modeset=1"
...
```

Обновляем конфиг grub командой

```sh
sudo update-grub
```

Это позволит модулям nvidia загружатся сразу при загрузке

## (Не рекомендуется) Последние проприетарные драйвера на Debian Testing (Не проверено)

- [Источник Nvidia Docs](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#debian)
- [Инструкция от A1RM4X](https://www.youtube.com/live/6E59GOY9QrM?si=6PmPaYcQ0XrVnLak&t=8392)

> Последние проприетарные драйвера на Debian Testing\
> Не предназначены для Linux Desktop! Это только для AI CUDA\
> Ещё у вас не будет DLSS и Raytracing\
> Для запуска игр необходимо "убрать "переменную PROTON_ENABLE_NVAPI=1

Подготовка

- Архитектура i386 должно присутствовать
- Пакет `firmware-mics-nonfree` должен присутствовать

Установка последних драйверов

```sh
sudo apt-get install linux-headers-$(uname -r)
sudo add-apt-repository contrib
wget https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-archive-keyring.gpg
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt install nvidia-driver
```

## LightDM не сохраняет выбранного пользователя

- [Источник решения](https://wiki.debian.org/LightDM)

От рута открываем файл ``/etc/lightdm/lightdm.conf``

И раскомментируем строчку

```conf
[Seat:*]
...
greeter-hide-users=false
```

## LightDM не появляется при входе в Read-only снимок Snapper

Необходимо отредактировать конфиг ``/etc/lightdm/lightdm.conf``, раскомментировать и изменить значение на true

```conf
[LightDM]
...
user-authority-in-system-dir=true
```

## Flatpak

```sh
# Включить поддержку Flatpak
sudo apt install flatpak

# Добавляем репозиторий flahub
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Изменения вступят в силу после выхода из системы или перезагрузки системы.

# [Для окружения KDE Plasma] Поддержка Flatpak в магазин приложений Discover
sudo apt install plasma-discover-backend-flatpak

# [Для окружения GNOME] Поддержка Flatpak в магазин приложений Gnome Software
sudo apt install gnome-software-plugin-flatpak
```

## TODO: Qemu KVM в Debian 12

```sh
# Минимальный набор
sudo apt install -y \
 qemu-kvm `# Основной пакет KVM` \
 libvirt-daemon-system `# Автозапуск модулей KVM` \
 libvirt-clients `# Бинарные файлы клиента такие как virsh` \
 virtinst `# Группа cli инструментов такие как virt-install, virt-clone, virt-xml и т.д` \
 virt-manager `# GUI менеджер виртуальных машин` \
 libguestfs-tools `# Монтировать гостевой образ виртуалки qemu в хост используя guestmount`

# Проверить доступные элементы
# Обращайте внимание только на раздел Qemu
virt-host-validate

# TODO: Добавить инструкцию по изолированной сети используя bridge (мост)

# Автозапуск вирт. сети default при запуске системы
sudo virsh net-autostart default
# Включить default вирт. сеть
sudo virsh net-start default
```

## Итог по Debian 12 Bookworm с BTRFS + Snapper + Snapper-Rollback

У меня получилось завести Read-only снимки подобно Arch Linux, стоит отметить что без примонтированного ``/tmp`` с опцией **rw** (чтение-запись) у меня иксы не запускаются. Из-за этого дисплейный менеджер не может загрузится, что невозможно зайти в само окружение. Такое происходит на Bookworm (stable) и на Sid (unstable)

```txt
systemd-tmpfiles[573]: rm_rf(/tmp): Read-only file system
systemd-tmpfiles[573]: Failed to create directory or subvolume "/tmp/.X11-unix": Read-only file system
systemd-tmpfiles[573]: Failed to create directory or subvolume "/tmp/.ICE-unix": Read-only file system
systemd-tmpfiles[573]: Failed to create directory or subvolume "/tmp/.XIM-unix": Read-only file system
systemd-tmpfiles[573]: Failed to create directory or subvolume "/tmp/.font-unix": Read-only file system
```

Также без этой опции все systemd сервисы тупо не запускались, однако на Sid (unstable) они все запускаются

```txt
dbus-broker.service: Failed to set up mount namespacing: /run/systemd/unit-root/dev: Read-only file system
dbus-broker.service: Failed at step NAMESPACE spawning /usr/bin/dbus-broker-launch: Read-only file system
```

## Проблемы и способы их решения

1. При первом запуске, systemd сервис `console-setup` фейлится с такой ошибкой

   ```txt
   systemd[1]: Starting console-setup.service - Set console font and keymap...
   console-setup.sh[518]: /usr/bin/setupcon: 999: cannot open /tmp/tmpkbd.cOVVxC: No such file
   console-setup.service: Main process exited, code=exited, status=1/FAILURE
   systemd[1]: console-setup.service: Failed with result 'exit-code'.
   systemd[1]: Failed to start console-setup.service - Set console font and keymap.
   ```

   Решение это просто перезагрузить данный сервис

   ```sh
   sudo systemctl restart console-setup
   ```

Поддержите меня за мои старания (´｡• ᵕ •｡`)

> [DonationAlerts](https://www.donationalerts.com/r/givefly)
