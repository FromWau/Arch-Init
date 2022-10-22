#!/bin/sh

# curl -O https://raw.githubusercontent.com/FromWau/Arch-Init/Asus/asus-setup.sh && chmod +x asus-setup.sh && ./asus-setup.sh


# Colors
Purple='\033[0;35m'	    # Purple process or sub-process still running
Green='\033[0;32m'      # Green for success
Yellow='\033[0;33m'     # Yellow for warnings
Red='\033[0;31m'        # Red for errors
Color_Off='\033[0m'	    # Resets colors 

# Symbols
CheckMark='✔'
Cross='✗'

# ======================
# Functions
# ======================

# asks for swicthing the keyboad layout
new_keyboardlayout() {
    printf "Change keyboad layout [N (use current %s)/ ? (list available layouts)/ name of layout]: " "$KEYLAYOUT" &&
    read -r new_keylayout && 
    case $new_keylayout in
        [?]* ) 
            localectl list-keymaps && 
            new_keyboardlayout
            ;;
    [Nn] | '') 
            ;;
           * ) 
            if localectl list-keymaps | grep -P "^($new_keylayout)$" > /dev/null && localectl set-keymap "$new_keylayout"
            then
                KEYLAYOUT=$new_keylayout && 
                return 
            else
                printf "${Yellow}%s\n" "$new_keylayout not found ... try again!${Color_Off}" && 
                new_keyboardlayout
            fi
            ;;
    esac
}


# Checks if system is connected to the internet
check_internet() {
    #dig -x 1.1.1.1 443
    # nc (netcat not installed)
    nc -zw 5 8.8.8.8 443 > /dev/null 2>&1
}

# checks if dir is mounted
is_mounted() {
    mount | awk -v DIR="$1" '{ if ($3 == DIR) {exit 0} } ENDFILE{exit -1}'
}


# Writes or overrites via echo
# keep track of to overwriting lines
task_count=1
one_line_printf() {
    printf "\n"
    while read -r line;
    do 
        printf "\033[s\033[1A\033[0K%s\033[u" "$line"; 
    done
    printf "\033[s\033[1A\033[0K"
}


Section_Size=45
section() {
    if [ "$1" = '--task' ];
    then
        task_count=$((task_count+1)) && 
        shift
    fi

    word=$*
    word_size=${#word}
    x=$((Section_Size-word_size))
    L=$((x/2))
    if [ $((x%2)) = "0" ]; 
    then 
        R=$L
    else
        R=$((L+1))
    fi

    format=$(printf "%${L}s${Green}%s${Color_Off}%${R}s\n" "" "$word" "" | awk 'match($0,/^( *)(.*[^ ])(.*)/,a){$0=gensub(/ /,"=","g",a[1]) a[2] gensub(/ /,"=","g",a[3])} 1'  )
    printf "%s\n" "$format"
}


# runs a programm and prints the output, just meant to show a table like lsblk to user
cmd_length=0
run() {
    eval " $1"
    cmd_length=$( $1 | wc -l )
}

# clean all lines to current printing line, use with run 
line_cleaner() {
    case $1 in
        '--task')
            l=$((task_count-1))
            task_count=1
            ;;
        *)
            l=$cmd_length
            cmd_length=0
            ;;
    esac

    rows=$l
    # clean all lines under cursor
    while [ "$rows" -gt "0" ];
    do
        printf "\033[s\033[%sA\033[0K\033[u" "$rows"
        rows=$((rows-1))
    done
    
    # set cursor to top position
    printf "\033[s\033[%sA\033[0K" "$l"
}


# text that gets overwritten
task() {
    task_count=$((task_count+1)) &&
    printf "%s\n" "$1" &&
    case "$3" in
        '-1')
            eval " $2" 2>&1 | one_line_printf
            ;;
           *)
            eval " $2" > /dev/null 2>&1
            ;;
    esac
}


# prompt in wrong line and not encoded
task_read() {
	printf "%s" "$@" &&
    read -r input &&
    task_count="$((task_count+1))"
}

task_done() {
    printf "\033[s\033[1A\033[0K%s\033[u" "$@"
}

task_failed() {
    printf "%s\n" "$@"
    exit 1
}

tasks_done() {
    printf "\033[s\033[%sA\033[0K%s\033[u" "$task_count" "$@" &&
    task_count=1
}


# just for debug
test_command() {
    for i in 1 2 3
    do
        printf "task %s done...\n" "$i" && sleep 1
    done
}


debug_text() {

    run "lsblk"
    line_cleaner

    
    printf "Tasks running\n"
    

    if task "0) test" "sleep 1" 
    then
        task_done "0) TASK DONE"
    else
        task_failed "0) TASK failed"
    fi


    if task "1) Counting to 3" "test_command" "-1"
    then
        task_done "1) TASK DONE"
    else
        task_failed "1) TASK failed"
    fi

    if task "2) Count again but no output" "test_command"
    then 
        task_done "2) TASK DONE"
    else
        task_failed "2) TASK failed"
    fi

    tasks_done "ALL TASKS DONE"
    printf "===================\n"

    printf "Tasks reading\n"
    task_read "Prompt: "
    
    if task "Doing stuff with $input" "sleep 1"
    then
        task_done "Read TASK DONE"
    else
        task_failed "Read TASK failed"
    fi
    tasks_done "ALL TASKS DONE"
    printf "=== DONE ===\n"

    exit 0
}





#TODO add direct color output to tasks

# Lets start ======================================================================================
printf "${Green}%s\n${Color_Off}" "
    _             _          ___       _ _   
   / \   _ __ ___| |__      |_ _|_ __ (_) |_ 
  / _ \ | '__/ __| '_ \ _____| || '_ \| | __|
 / ___ \| | | (__| | | |_____| || | | | | |_ 
/_/   \_\_|  \___|_| |_|    |___|_| |_|_|\__|
=============================================    
"

# TODO Some intro stuff idk yet.


# setting en if keyboad layout is n/a
KEYLAYOUT=$( localectl status | awk -F 'VC Keymap:' '{print $2}' | xargs )
if [ "$KEYLAYOUT" = "n/a" ];
then
    KEYLAYOUT='en'
    localectl set-keymap $KEYLAYOUT
fi


# read Settings
new_keyboardlayout
printf "${Green}${CheckMark} Keyboard layout set to %s${Color_Off}\n" "${KEYLAYOUT}"


# checking for internet
has_internet=true
if ! check_internet;
then
	has_internet=false
fi


# Set Settings
section --task "= Some questions "
if ! "$has_internet";
then
    task_read 'WLAN SSID: ' && WLAN_SSID=$input
    task_read 'WLAN PASS: ' && WLAN_PASS=$input
fi

task_read 'CRYPT PASS: ' && CRYPT_PASS=$input
task_read 'ROOT PASS: ' && ROOT_PASS=$input
task_read 'USER NAME: ' && USER_NAME=$input
task_read 'USER PASS: ' && USER_PASS=$input

line_cleaner --task


# Making sure everything is good to go
section " Settings Summary "

if ! $has_internet;
then
    printf "WLAN SSID: %34s\n" "${WLAN_SSID}"
	printf "WLAN password: %30s\n" "${WLAN_PASS}"
fi
printf "Keyboard layout: %28s\n" "${KEYLAYOUT}"
printf "Crypt password: %29s\n" "${CRYPT_PASS}"                                                                    
printf "Root password: %30s\n" "${ROOT_PASS}"                                                                     
printf "User name: %34s\n" " ${USER_NAME}"                                                                     
printf "User password: %30s\n" "${USER_PASS}"




# TODO
# Keymap and check_internet should be tasked and get cleared

exit 0

















#IP=$(dig +short myip.opendns.com @resolver1.opendns.com)
#TIMEZONE=$(curl -s ipinfo.io/${IP} | jq .timezone)


# get all disks that are not hotplugable (no usb or sd card)
disks=$(lsblk -o type,path,hotplug | awk '$1 == "disk" && $3 == 0 { print $2 }')
filesystem='btrfs'



if [ $( echo "$disks" | wc -l ) -eq "1" ]; then
    echo "1 -- skip frage"
    DISK=$disks
elif [ $( echo "$disks" | wc -l ) -gt "1" ]; then
    echo "$disks" | awk '{ print NR ") "$s }'
    read -p "Choose one disk: " input_disk
    DISK=$( echo "$disks" | sed -n ${input_disk}p )
else
    echo "WTF no available disks or all are hotplug" 
    exit 1
fi

echo $DISK

# bonus stuff: search if another filesystems or boot /efi is already here. maybe look into fstab


# partition disk normal 





write "====================  ${Green}Disk Layout${Color_Off}  ====================="
write "nvme0n1       259:0    0 476.9G  0 disk"                                                              
write "├─nvme0n1p1   259:1    0   256M  0 part  /mnt/boot/efi"                                                  
write "├─nvme0n1p2   259:2    0   512M  0 part  /mnt/boot"                                                
write "└─nvme0n1p3   259:3    0 476.2G  0 part"                                                           
write "  └─cryptroot 254:0    0 476.2G  0 crypt /mnt/var"                                                
write "                                         /mnt/.snapshots"                                            
write "                                         /mnt/home"                                                  
write "                                         /mnt\n"

read -p "Are these settings and disk layout correct [Y/n]? " yn
case $yn in
  [Nn]* ) exit 0;;
      * ) break;;
esac


# Connecting and checking for network connectivity
if ! $has_internet; 
then
    	write_rep "${Purple}Setting Internet...${Color_Off}" &&
    	echo "[Security]" > /var/lib/iwd/$WLAN_SSID.psk &&
    	wpa_passphrase $WLAN_SSID $WLAN_PASS |grep psk |sed 's/#psk=/Passphrase=/g' \
        	|sed 's/[[:space:]]//g' |sed 's/psk=/PreSharedKey=/g' >> /var/lib/iwd/$WLAN_SSID.psk && 
	
    	iwctl station wlan0 disconnect && iwctl station wlan0 connect $WLAN_SSID > /dev/null 2>&1 && sleep 10
	
	if check_internet;
	then
        	write "${Green}${CheckMark} Internet connected via iwctl${Color_Off}" && has_internet=true
	else
        	write "${Red}${Cross} No Internet - is the ssid or password correct?${Color_Off}" && exit -1
	fi
else
	write "${Green}${CheckMark} Using current Internet connection${Color_Off}"
fi


# Enable the NTP service
write_rep "${Purple}Enabling NTP service...${Color_Off}" &&
timedatectl set-ntp true &&
write "${Green}${CheckMark} Enabled NTP service${Color_Off}"


# Disk Setup
list=$(write "${Purple}Starting disk setup...${Color_Off}" | tee /dev/tty)"\n" &&

## Check is everything dismounted and crypt closed
DIR=/mnt &&
if is_mounted $DIR;
then
    umount -R $DIR &&
    list+=$(write "${Yellow}├─ ${CheckMark} $DIR is mounted -- unmounted${Color_Off}" | tee /dev/tty)"\n" 
fi
CRY_CLOSE=$(dmsetup ls |grep crypt |cut -f1) &&
if [[ ! -z "$CRY_CLOSE" ]]
then
    cryptsetup close /dev/mapper/$CRY_CLOSE &&
    list+=$(write "${Yellow}├─ ${CheckMark} luks mapper ($CRY_CLOSE) is open -- closed${Color_Off}" | tee /dev/tty)"\n"
fi

## Wipe everything
shred -fvzn 0 /dev/nvme0n1 2>&1 | while read i; do write_rep "$i"; done && O_LINES=1 &&
list+=$(write "${Green}├─ ${CheckMark} wiped /dev/nvme0n1${Color_Off}" | tee /dev/tty)"\n" && O_LINES=0 &&

## create partitions EFI, BOOT, ROOT
fdisk /dev/nvme0n1 <<EOF > /dev/null 2>&1 &&
n
p
1

+256M

n
p
2

+512M

n
p
3



t
1
EF

t
2
83

t
3
83

w
EOF
list+=$(write "${Green}├─ ${CheckMark} Created partitions${Color_Off}" | tee /dev/tty)"\n"

## Create cryptroot
cryptsetup luksFormat /dev/nvme0n1p3 <<EOF > /dev/null &&
$CRYPT_PASS
EOF
cryptsetup luksOpen /dev/nvme0n1p3 cryptroot <<EOF &&
$CRYPT_PASS
EOF
list+=$(write "${Green}├─ ${CheckMark} created cryptsetup and opened device${Color_Off}" | tee /dev/tty)"\n"

## Creating filesystems and subvolumes
mkfs.vfat /dev/nvme0n1p1 > /dev/null &&
mkfs.btrfs /dev/nvme0n1p2 -f > /dev/null &&
mkfs.btrfs /dev/mapper/cryptroot -f > /dev/null &&
list+=$(write "${Green}├─ ${CheckMark} created filesystems for partitions${Color_Off}" | tee /dev/tty)"\n"

mount /dev/mapper/cryptroot /mnt &&
btrfs su cr /mnt/@ > /dev/null &&
btrfs su cr /mnt/@home > /dev/null &&
btrfs su cr /mnt/@snapshots > /dev/null &&
btrfs su cr /mnt/@var > /dev/null &&
umount /mnt &&
list+=$(write "${Green}├─ ${CheckMark} created btrfs subvolumes${Color_Off}" | tee /dev/tty)"\n"

## Mount EFI, Boot and subvolumes
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@ /dev/mapper/cryptroot /mnt &&
mkdir -p /mnt/{home,.snapshots,var,boot} &&

mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@home /dev/mapper/cryptroot /mnt/home &&
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots &&
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@var /dev/mapper/cryptroot /mnt/var &&
mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd /dev/nvme0n1p2 /mnt/boot &&

mkdir -p /mnt/boot/efi &&
mount /dev/nvme0n1p1 /mnt/boot/efi &&
list+=$(write "${Green}└─ ${CheckMark} Created mount points${Color_Off}" | tee /dev/tty)

## Setting Task to done.
O_LINES=$(echo -e "$list" | wc -l) &&
write "${Green}${CheckMark} Setup Disk${Color_Off}" &&
O_LINES=0


# Configure pacman, set mirrorlist and install needed pkgs
write_rep "${Purple}Updating pacman.conf...${Color_Off}"
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf &&
sed -i "/Color/s/^#//" /etc/pacman.conf &&
sed -i "/ParallelDownloads/s/^#//" /etc/pacman.conf &&
write "${Green}${CheckMark} Configured /etc/pacman.conf${Color_Off}"


# reflector
write_rep "${Purple}Updating pacman.d/mirrorlist${Color_Off}" &&
reflector -a 15 --sort rate --save /etc/pacman.d/mirrorlist > /dev/null 2>&1 &&
write "${Green}${CheckMark} Set fastest mirrors for $COUNTRY${Color_Off}"


# install pkgs via pacstrap
write_rep "${Purple}Installing basic packages via pacstrap${Color_Off}" &&
pacstrap /mnt base base-devel linux linux-firmware btrfs-progs vim openssh git dialog jq man intel-ucode grub grub-btrfs efibootmgr networkmanager go &&
write "${Green}${CheckMark} Installed packages${Color_Off}"


# generate fstab
write_rep "${Purple}Generating fstab...${Color_Off}" &&
genfstab -U /mnt > /mnt/etc/fstab &&
write "${Green}${CheckMark} Generated fstab${Color_Off}"
 

# Timezone
write_rep "${Purple}Setting timezone to Vienna...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c 'ln -sf /usr/share/zoneinfo/Europe/Vienna /etc/localtime && hwclock --systohc' &&
write "${Green}${CheckMark} Set timezone to Vienna${Color_Off}"


# Locale
write_rep "${Purple}Generating locales...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "sed -i '/en_US.UTF-8/s/^#//g' /etc/locale.gen && 
    locale-gen && 
    echo 'LANG=en_US.UTF-8' > /etc/locale.conf" > /dev/null 2>&1 &&
write "${Green}${CheckMark} Generated locales for en_US.UTF-8${Color_Off}"


# Hostname
write_rep "${Purple}Setting hostname...${Color_Off}" &&
echo "arsus" > /mnt/etc/hostname &&
write "${Green}${CheckMark} Set hostname${Color_Off}"


# Hosts
write_rep "${Purple}Setting hosts...${Color_Off}" &&
echo -e "127.0.0.1  localhost\n::1        localhost\n127.0.1.1  arsus.local  arsus" > /mnt/etc/hosts &&
write "${Green}${CheckMark} Set hosts${Color_Off}"


write "${Purple}Make it bootable...${Color_Off}"
# Start Grub setup
## Grub setup
write_rep "${Purple}├─ Installing grub...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c 'grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB' > /dev/null 2>&1 &&
write "${Green}├─ ${CheckMark} Installed grub${Color_Off}"

## crypt 
write_rep "${Purple}├─ Configuring and running mkinitcpio...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "sed -i '/^BINARIES=/ s/()/(btrfs)/i' /etc/mkinitcpio.conf &&
    sed -i '/^HOOKS=/ s/block filesystems/block encrypt filesystems/i' /etc/mkinitcpio.conf &&
    mkinitcpio -p linux" > /dev/null 2>&1 &&
write "${Green}├─ ${CheckMark} Configurated /etc/mkinitcpio.conf${Color_Off}"

## set crypt option in /etc/default/grub
write_rep "${Purple}├─ Configuring default grub...${Color_Off}" &&
CRYPT_UUID=$(blkid |tr '\n' ' '  |awk '{ sub(/.*\/dev\/nvme0n1p3: /, ""); sub(/TYPE="crypto_LUKS"*.*/, ""); print }' |tr -d '"' |xargs) &&
sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/g" /mnt/etc/default/grub &&
sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"loglevel=3 quiet\"/\"loglevel=3 quiet cryptdevice=$CRYPT_UUID:cryptroot root=\/dev\/mapper\/cryptroot\"/i" /mnt/etc/default/grub &&
write "${Green}├─ ${CheckMark} Configurated /etc/default/grub${Color_Off}"

## generate grub config
write_rep "${Purple}├─ Generating grub config...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg" > /dev/null 2>&1 &&
write "${Green}├─ ${CheckMark} Generated grub config${Color_Off}"

## Setup Grub Themes (custom grup)
write_rep "${Purple}└─ Installing grub2 vimix theme...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "cd / &&
    git clone https://github.com/vinceliuice/grub2-themes.git > /dev/null 2>&1 &&
    cd grub2-themes && 
    ./install.sh -b -t vimix > /dev/null 2>&1 &&
    rm -rf /grub2-themes" &&
write "${Green}└─ ${CheckMark} Installed vimix grub2 theme${Color_Off}"

O_LINES=5
write "${Green}${CheckMark} Made it bootable${Color_Off}"
O_LINES=0


# update pacman.conf 
write_rep "${Purple}Updating pacman.conf...${Color_Off}" &&
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf &&
sed -i "/Color/s/^#//" /mnt/etc/pacman.conf &&
sed -i "/ParallelDownloads/s/^#//" /mnt/etc/pacman.conf &&
write "${Green}${CheckMark} Updated pacman.conf${Color_Off}"


# Install packages
write "${Purple}Installing packages...${Color_Off}" &&
pacstrap /mnt mesa vulkan-intel wayland plasma-wayland-session sddm sddm-kcm plasma-desktop plasma-nm iwd powerdevil \
dolphin dolphin-plugins kdeplasma-addons kdeconnect kde-gtk-config kscreen kinfocenter firefox \
bluedevil pulseaudio plasma-pa pulseaudio-bluetooth bluez bluez-utils pulseaudio-alsa \
alsa-firmware alsa-ucm-conf sof-firmware alsa-plugins \
kitty zsh dash neovim nerd-fonts reflector thunderbird discord btop exa procs ripgrep intellij-idea-community-edition jdk-openjdk neofetch tldr && 
write "${Green}${CheckMark} Installed GPU drivers, KDE, wayland, audio, bluetooth and standart programms${Color_Off}"


# Setup dash
write_rep "${Purple}Setting dash as default shell and creating pacman hook...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "ln -sfT dash /usr/bin/sh && 
    echo '[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = bash

[Action]
Description = Re-pointing /bin/sh symlink to dash...
When = PostTransaction
Exec = /usr/bin/ln -sfT dash /usr/bin/sh
Depends = dash' > /usr/share/libalpm/hooks/update-bash.look" &&
write "${Green}${CheckMark} Set dash as default shell and created pacman hook${Color_Off}"


# root passwd
write_rep "${Purple}Setting root pass...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "echo 'root:$ROOT_PASS' |chpasswd" &&
write "${Green}${CheckMark} Set root pass${Color_Off}"


# Useradd and passwd
write_rep "${Purple}Creating user and setting pass...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "useradd -mG wheel -s /usr/bin/zsh $USER_NAME && echo '$USER_NAME:$USER_PASS' |chpasswd" &&
write "${Green}${CheckMark} Created user and set pass${Color_Off}"


# Install yay
## uncomment no pass wheel for yay install
write_rep "${Purple}Activating wheel no passwd...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "chmod +w /etc/sudoers &&
    sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers &&
    chmod 0440 /etc/sudoers" &&
write "${Green}${CheckMark} Activated wheel nopasswd${Color_Off}"


## install yay as new user
write "${Purple}Installing yay and aur packages...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "runuser -l $USER_NAME -c 'git clone https://aur.archlinux.org/yay-git.git ~/yay-git > /dev/null 2>&1 &&
    cd ~/yay-git &&
    makepkg -si --noconfirm > /dev/null 2>&1 &&
    rm -rf ~/yay-git &&
    yay -Syyyu timeshift spotify touchegg tmux wl-clipboard --noconfirm --removemake'" &&
write "${Green}${CheckMark} Installed yay and aur packages${Color_Off}"


# Install and setup Zsh
write_rep "${Purple}Creating .zshenv...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "runuser -l $USER_NAME -c 'echo "ZDOTDIR=/home/$USER_NAME/.config/zsh/" > .zshenv'" &&
write "${Green}${CheckMark} Created .zshenv${Color_Off}"


# install dotfiles
write_rep "${Purple}Installing dotfiles...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "runuser -l $USER_NAME -c 'git clone https://github.com/FromWau/dotfiles.git > /dev/null 2>&1 &&
    cp -r dotfiles/.config/* /home/$USER_NAME/.config &&
    rm -rf dotfiles'" &&
write "${Green}${CheckMark} Installed dotfiles${Color_Off}"


# setup nvim
write_rep "${Purple}Setting up neovim...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "runuser -l $USER_NAME -c 'git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim > /dev/null 2>&1 &&
    nvim .config/nvim/lua/user/packer.lua --headless +source +PackerSync +qa > /dev/null 2>&1'" &&
write "${Red}${Cross} NOT installed nvim packer and plugins for user${Color_Off}"


# Set Kde to use German(Austria) keyboad layout
write_rep "${Purple}Setting KDE keyboard layout to Austria...${Color_Off}" &&
echo "\n[Layout]\nLayoutList=at\nUse=true" >> /mnt/home/$USER_NAME/.config/kxkbrc &&
write "${Green}${CheckMark} Set KDE keyboard layout to Austria${Color_Off}"


# set keymap
write_rep "${Purple}Setting timezone to Vienna...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "echo 'KEYMAP=de-latin1' > /etc/vconsole.conf" &&
write "${Green}${CheckMark} Set keymap for new system${Color_Off}"


# Setup tmux
write_rep "${Purple}Setting up tmux...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "runuser -l $USER_NAME -c 'if [[ ! -d ~/.config/tmux ]] &&
    then
	    mkdir -p .config/tmux &&
	    git clone https://github.com/gpakosz/.tmux.git ~/.tmux > /dev/null 2>&1 &&
	    mv .tmux/.tmux.conf .config/tmux/tmux.conf &&
	    mv .tmux/.tmux.conf.local .config/tmux/tmux.conf.local &&
	    rm -rf .tmux
    fi
    ln -sf .config/tmux/tmux.conf ~/.tmux.conf &&
    ln -sf .config/tmux/tmux.conf.local .tmux.conf.local &&
    echo -e \"# if run as <tmux attach>, create a session if one does not exist\nnew-session -n $HOST\" >> .config/tmux/tmux.conf.local'" &&
write "${Green}${CheckMark} Setup tmux${Color_Off}" &&


# update kcminputrc -- kcminputrc not existing 
write_rep "${Purple}Set KDE inputrc...${Color_Off}" &&
#arch-chroot /mnt /bin/bash -c "runuser -l $USER_NAME -c \"sed -i 's/TapToClick=false/TapToClick=true/g' ~/.config/kcminputrc &&
#    sed -i 's/NaturalScroll=false/NaturalScroll=true/g' ~/.config/kcminputrc\"" &&
write "${Red}${Cross} NO KDE inputrc${Color_Off}"


write_rep "${Purple}Creating KDE shortcuts...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "runuser -l $USER_NAME -c 'echo -e \"[kitty-3.desktop]\n_k_friendly_name=kitty tmux attach\n_launch=Meta+Return,none,kitty tmux attac\" >> ~/.config/kglobalshortcutsrc'" &&
write "${Green}${CheckMark} Created KDE shortcut${Color_Off}"


# Enable Services
write_rep "${Purple}Enabling systemd services...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager --quiet &&
    systemctl enable sshd.service --quiet &&
    systemctl enable sddm.service --quiet &&
    systemctl enable cronie.service --quiet &&
    systemctl enable bluetooth.service --quiet &&
    systemctl enable upower.service --quiet" &&
write "${Green}${CheckMark} Enabled systemd services${Color_Off}"


# enable experimental bluetooth features to be able to see the bluetooth headset battery
write_rep "${Purple}Updating bluetooth.service...${Color_Off}" &&
sed -i "s/ExecStart\=\/usr\/lib\/bluetooth\/bluetoothd/ExecStart\=\/usr\/lib\/bluetooth\/bluetoothd --experimental/g" /mnt/usr/lib/systemd/system/bluetooth.service &&
write "${Green}${CheckMark} Updated bluetooth.service to use experimental features, because headset battery${Color_Off}"


# setup NetworkManager use iwd as backend and copy already setup networks
write_rep "${Purple}Setting NetworkManager backend to iwd and copy known psk files...${Color_Off}" &&
echo -e "[device]\nwifi.backend=iwd" > /mnt/etc/NetworkManager/conf.d/wifi_backend.conf && 
mkdir -p /mnt/var/lib/iwd/ &&
cp -r /var/lib/iwd/* /mnt/var/lib/iwd/ &&
write "${Green}${CheckMark} Updated NetworkManager and copied known psk files${Color_Off}"


# Set SDDM keyboard layout to de
write_rep "${Purple}Setting SDDM keyboard layout to german...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "localectl set-x11-keymap de" &&
write "${Green}${CheckMark} Set SDDM keyboard layout to german${Color_Off}"


# enable wheel properly
write_rep "${Purple}Activating wheel group and deactivating wheel nopasswd...${Color_Off}" &&
arch-chroot /mnt /bin/bash -c "chmod +w /etc/sudoers &&
    sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers &&
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers &&
    chmod 0440 /etc/sudoers" &&
write "${Green}Activated wheel group and deactivated wheel nopasswd${Color_Off}"

echo -e "POST Install Summary"
echo -e "\n${Yellow}====== Things that dont work or should be checked ======= 
keyboard layout not de 
kde setup

${Red}
====== Errors =====================
====================================

${Yellow}
when done run:

umount -R /mnt && reboot
${Color_Off}"



