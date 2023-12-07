# Мой скрипт установки Debian 12 Bookworm (Для личного использования)

В качестве LiveISO я использую Standard который схож с Arch ISO, находится он по [ссылке](https://cdimage.debian.org/debian-cd/current-live/amd64/iso-hybrid/)

В списке при загрузке в меню выбираем Live ISO (первый вариант)

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
sudo apt update && sudo install -yy git
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
И вас будет встречать чистый Debian 12 с BTRFS и настроенным Snapper'ом

## Для тестирования на виртуалке

Если QEMU/KVM качаем пакеты `qemu-guest-agent spice-vdagent`

> В оконных менеджерах (WM) для активации Shared Clipboard в терминале надо ввести `spice-vdagent`

Для VirtualBox (не проверенно):

- Качаем пакеты `virtualbox-guest-addition-iso xserver-xorg-video-vmware`
- Присваиваем пользователю группу vboxfs командой `usermod -a -G vboxsf $(whoami)`
<!-- - Активируем systemd сервис `sudo systemctl enable vboxservice.service` -->

Поддержите меня за мои старания (´｡• ᵕ •｡`)

> [DonationAlerts](https://www.donationalerts.com/r/givefly)
