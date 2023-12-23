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

# Сканируем на наличие новых сетей
# Вместо `device` должен быть ваш интерфейс полученный из предыдущей команды
iwctl station wlan device scan

# Выводим список сетей
iwctl station wlan device get-networks

# Подключаемся к сети заполняя свои данные
iwctl station wlan device connect SSID --passphrase ""

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

## Восстановление Debian, chroot из под LiveISO

Используя тот же [Standard](https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/) образ Debian LiveISO

```sh
# Монтируем
mount -v -o subvol=@ /dev/vda2 /mnt
mount -v /dev/vda1 /mnt/boot
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

## TODO: Пакеты для ноутбуков (на заметку)

```sh
firmware-iwlwifi # Беспроводные драйвера
task-laptop # Мета-пакет необходимых программ для ноутбука
powertop # Мониторинг энергопотребления и управлением питанием
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
