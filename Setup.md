#!/bin/sh

# Set Keyboard layout to ex. german
localectl list-keymaps | grep de
localectl set-keymap de-latin1

# Wifi setup
iwctl list
iwctl station DEVICE get-networks
iwctl station DEVICE connect SSID 

# Setting Time
timedatectl set-ntp true

# Setting fastest mirror
reflector -c Austria -a 6 --sort rate --save /etc/pacman.d/mirrorlist

# Create btrfs Filesystem, subvolumes and mount dirs
lsblk

# cryptsetup
#nvme0n1     259:0    0 476.9G  0 disk
#├─nvme0n1p1 259:1    0   256M  0 part (EFI)
#├─nvme0n1p2 259:2    0   512M  0 part (BOOT not encrypted)
#└─nvme0n1p3 259:6    0 476.2G  0 part (ROOT actual encrypted drive)

cryptsetup luksFormat /dev/nvme0n1p3
cryptsetup luksOpen /dev/nvme0n1p3 cryptroot

mkfs.btrfs /dev/mapper/cryptroot -f
mount /dev/mapper/cryptroot /mnt

btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var
umount /mnt

mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@ /dev/mapper/cryptroot /mnt
mkdir /mnt/{home,.snapshots,var}
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@home /dev/mapper/cryptroot /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@var /dev/mapper/cryptroot /mnt/var

mkdir -p /mnt/boot/efi
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd /dev/nvme0n1p2 /mnt/boot
mount /dev/nvme0n1p1 /mnt/boot/efi


# no encytption DUAL Boot setup
#cfdisk /dev/nvme0n1
#1... EFI (/dev/nvme0n1p1)
#2... Microsoft reserved (/dev/nvme0n1p2)
#3... Microsoft basic data (win10 data) (/dev/nvme0n1p3)
#4... Linux Filesystem (/dev/nvme0n1p4)
#write and quit
mkfs.btfrs /dev/nvme0n1p4 -f

mount /dev/nvme0n1p4 /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var
umount /mnt

mount -o noatime,compress=lzo,space_cache=v2,discard=async,ssd,subvol=@ /dev/nvme0n1p4 /mnt
mkdir /mnt/{boot,home,.snapshots,var}
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@home /dev/nvme0n1p4 /mnt/home
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@snapshots /dev/nvme0n1p4 /mnt/.snapshots
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@var /dev/nvme0n1p4 /mnt/var

mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi


## add ntfs drives
mkdir /mnt/{win10,games,documents,vault}

lsblk

mount /dev/nvme0n1p3 /mnt/win10
mount /dev/nvme1n1p2 /mnt/games
mount /dev/nvme1n1p1 /mnt/documents
mount /dev/sda3 /mnt/vault


# Configure pacman
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "/Color/s/^#//" /etc/pacman.conf
sed -i "/ParallelDownloads/s/^#//" /etc/pacman.conf
pacman -Syy

# CPU: AMD + NTFS
pacstrap /mnt base base-devel  linux linux-firmware btrfs-progs os-prober vim openssh git dialog amd-ucode ntfs-3g mtools dosfstools grub grub-btrfs efibootmgr networkmanager
# CPU: Intel
pacstrap /mnt base base-devel linux linux-firmware btrfs-progs vim openssh git dialog intel-ucode grub grub-btrfs efibootmgr networkmanager

# if error with pacman
# Sync Packages, update keyring, install packages
pacman -S gnupg
pacman -Sy archlinux-keyring
pacman-key --populate archlinux
pacman-key --refresh-keys
pacman -Syu

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configuration
arch-chroot /mnt

## Timezone
ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime
hwclock --systohc

## Locale
sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen
locale-gen 

echo "LANG=en_US.UTF-8" >> /etc/locale.conf 

## Hostname
echo "archner" >> /etc/hostname

## Hosts
echo "127.0.0.1  localhost" >> /etc/hosts
echo "::1        localhost" >> /etc/hosts
echo "127.0.1.1  archner.local  archner" >> /etc/hosts

## Grub setup
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

### crypt 
sed -i '/^BINARIES=/ s/()/(btrfs)/i' /etc/mkinitcpio.conf
sed -i '/^HOOKS=/ s/block filesystems/block encrypt filesystems/i' /etc/mkinitcpio.conf
mkinitcpio -p linux

blkid
blkid |tr '\n' ' '  |awk '{ sub(/.*\/dev\/nvme0n1p3: /, ""); sub(/TYPE="crypto_LUKS"*.*/, ""); print }'


sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"loglevel=3 quiet"/"loglevel=3 quiet cryptdevice=$CRYPT_UUID:cryptroot root=\/dev\/mapper\/cryptroot"/i' /etc/default/grub 

### vim /etc/default/grub
### change GRUB_CMDLINE_LINUX_DEFAULT to 
### GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet cryptdevice=UUID=414add01-4b9d-476f-a5e8-a72624343468:cryptroot root=/dev/mapper/cryptroot"

### no crypt but NTFS and Win dual boot 
vim /etc/default/grub
uncomment GRUB_DISABLE_OS_PROBER
## everyone

grub-mkconfig -o /boot/grub/grub.cfg

## Root password
passwd

## Useradd
useradd -mG wheel fromml
passwd fromml 


# Install packages
yay -Syyyu nvidia nvidia-utils xorg xorg-server sddm sddm-dke plasma-desktop powerdevil \
dolphin dolphin-plugins konsole kde-plasma-addons kdeconnect kde-gtk-config kscreen kinfocenter khotkeys user-manager firefox \
bluedevil pulseaudio plasma-pa pulseaudio-bluetooth bluez bluez-utils pulseaudio-alsa alsa-plugins \
kitty zsh dash nvim spotify thunderbird steam discord nvtop btop timeshift exa proton

# Setup dash
sudo ln -sfT dash /usr/bin/sh

# Setup Grub Themes (custom grup)
cd ~
git clone https://github.com/vinceliuice/grub2-themes.git
cd grub2-themes
sudo ./install.sh -b -t vimix

# Enable Services
systemctl enable NetworkManager
systemctl enable sshd
sudo systemctl enable cronie
sudo systemctl enable sddm
sudo systemctl enable bluetooth
sudo systemctl enable upower


umount -R /mnt

reboot


EDITOR=vim visudo
uncomment wheel ALL=(ALL:ALL) ALL

# Install yay
cd ~
git clone https://aur.archlinux.org/yay-git.git
cd yay-git
makepkg -si
cd .. && sudo rm -r yay-git

# Install and setup Zsh
echo "ZDOTDIR=$HOME/.config/zsh/" > .zshenv
chsh -s /bin/zsh


# Setup tmux
yay -S tmux xclip
cd
mkdir -p .config/tmux
git clone https://github.com/gpakosz/.tmux.git
mv .tmux/.tmux.conf .config/tmux/tmux.conf
mv .tmux/.tmux.conf.local .config/tmux/tmux.conf.local
ln -sf .config/tmux/tmux.conf ~/.tmux.conf
ln -sf .config/tmux/tmux.conf.local .tmux.conf.local
rm -rf .tmux
echo '# if run as "tmux attach", create a session if one does not exist\nnew-session -n $HOST' >> .config/tmux/tmux.conf.local 
### add tmux attach to the terminal shortcut(via kde custom shortcuts) zB. for kitty: /bin/kitty tmux attach
