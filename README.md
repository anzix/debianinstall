# Мой скрипт установки Debian Linux (Для личного использования)

В качестве LiveISO я использую Standard который схож с Arch ISO, находится он по [ссылке](https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/)

В списке при загрузке в меню выбираем Live ISO (первый вариант)

## [Для ноутбуков] Установка Wi-Fi-соединения и проверка сети (набросок)

- [Arch Wiki](https://wiki.archlinux.org/title/wpa_supplicant#Connecting_with_wpa_passphrase)

Вот что нужно делать как только вы вошли в установщик Debian

```sh
# Вводите заполняя свои данные
wpa_passphrase МОЙ_SSID парольная_фраза

# Вы увидите нечто похожее у себя
network={
    ssid="MYSSID"
    #psk="passphrase"
    psk=59e0d07fa4c7741797a4e394f38a5c321e3bed51d54ad5fcbd3f84bc7415d73d
}

# Необходимо узнать сетевой `интерфейс`
ip a

# Переходим в оболочку root
sudo su

# Для окончательного подключения вводите заполняя свои данные
wpa_supplicant -B -i интерфейс -c <(wpa_passphrase МОЙ_SSID парольная_фраза)
```

***

## Подключение по SSH и установка

Если вы хотите подключится по ssh вот что нужно сделать

```sh
# Обновляем зеркала и качаем пакет ssh
sudo apt update && sudo apt -yy install ssh

# Проверяем статус сервиса (должен быть включён автоматически)
systemctl status sshd

# Запоминаем ip для подключения
ip a

# С хоста входим по ssh в гостевую машину
# Пароль пользователя (НЕ root): live
ssh user@ip
```

***

Обновляем зеркала и устанавливаем git

```sh
sudo apt update && sudo apt -yy install git
```

Клонируем репо и переходим в него

```sh
git clone https://github.com/anzix/debianinstall && cd debianinstall
```

Входим в оболочку root

```sh
sudo su
```

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

## Восстановление Debian, chroot из под LiveISO

Используя тот же [Standard](https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/) образ Debian LiveISO

```sh
# Монтируем
mount -v -o subvol=@rootfs /dev/vda2 /mnt
mount -v /dev/vda1 /mnt/boot
for i in dev proc sys; do
  mount -v --rbind "/$i" "/mnt/$i"; mount -v --make-rslave "/mnt/$i"
done

# Без экспорта этой переменной я не мог чрутнутся
export PATH="$PATH:/usr/sbin:/sbin:/bin"

# Чрутимся
chroot /mnt
```

## Установка шрифтов семейства Nerd в Debian

Так как нету данных шрифтов в репозиториях придётся устанавливать их вручную\
Выполняем данный скрипт и выбираем шрифт на выбор и готово.

```sh
bash -c  "$(curl -fsSL https://raw.githubusercontent.com/officialrajdeepsingh/nerd-fonts-installer/main/install.sh)"
```

## TODO: Установка Wine и Steam

Так как я уже добавил в ``/etc/apt/sources.list`` поддержку архитектуры i386 все необходимые библиотеки wine будут включены

```sh
# Установка всех пакетов wine
sudo apt install wine wine64 libwine libwine:i386 fonts-wine

# Установка steam amd64 вместе с i386 библиотеками
sudo apt install steam-installer
```

## TODO: Пакеты для ноутбуков (на заметку)

```sh
firmware-iwlwifi # Беспроводные драйвера
task-laptop
powertop
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

# Поддержка Flatpak в KDE Plasma
sudo apt install plasma-discover-backend-flatpak

# Поддержка Flatpak в Gnome Software
sudo apt install gnome-software-plugin-flatpak
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

Все systemd сервисы тупо не запускались, однако на Sid (unstable) они все запускаются

```txt
dbus-broker.service: Failed to set up mount namespacing: /run/systemd/unit-root/dev: Read-only file system
dbus-broker.service: Failed at step NAMESPACE spawning /usr/bin/dbus-broker-launch: Read-only file system
```

Поддержите меня за мои старания (´｡• ᵕ •｡`)

> [DonationAlerts](https://www.donationalerts.com/r/givefly)
