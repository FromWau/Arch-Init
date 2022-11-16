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
Arrow=''

# ======================
# Functions
# ======================


# Checks if system is connected to the internet
check_internet() {
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
    while read -r line
    do 
        printf "\033[s\033[1A\033[0K%s\033[u" "$line"
    done
    printf "\033[s\033[1A\033[0K"
}


Section_Size=43
section() {
    if [ "$1" = '--task' ]
    then
        task_count=$((task_count+1)) && 
        shift
    fi

    word=$1
    word_size=${#word}
    x=$((Section_Size-word_size))
    L=$((x/2))
    if [ $((x%2)) = "0" ]
    then 
        R=$L
    else
        R=$((L+1))
    fi
    shift
    
    if [ "$1" = '-' ]
    then
        format=$(printf "%${L}s${Green}%s${Color_Off}%${R}s\n" "" " $word " "" | awk 'match($0,/^( *)(.*[^ ])(.*)/,a){$0=gensub(/ /,"-","g",a[1]) a[2] gensub(/ /,"-","g",a[3])} 1'  )
    else
        format=$(printf "%${L}s${Green}%s${Color_Off}%${R}s\n" "" " $word " "" | awk 'match($0,/^( *)(.*[^ ])(.*)/,a){$0=gensub(/ /,"=","g",a[1]) a[2] gensub(/ /,"=","g",a[3])} 1'  )
    fi

    printf "%s\n" "$format"
}



# runs a programm and prints the output, just meant to show a table like lsblk to user
cmd_length=0
run() {
    out=$( eval " $1" 2>&1 | tee /dev/tty )
    cmd_length=$( echo "$out" | wc -l )
}


# asks for swicthing the keyboad layout
new_keyboardlayout() {
    printf "Change keyboad layout [N (use current %s)/ ? (list available layouts)/ name of layout]: " "$KEYLAYOUT"
    read -r new_keylayout
    
    cmd_length=$((cmd_length+1))
    case $new_keylayout in
        [?]* ) 
            localectl list-keymaps | less && 
            new_keyboardlayout
            ;;
    [Nn] | '') 
            ;;
           * ) 
            kb="$(localectl list-keymaps | grep -P "^($new_keylayout)$")" > /dev/null 2>&1
            if [ "$(echo "$kb" | wc -l)" -eq "1" ] && localectl set-keymap "$new_keylayout"
            then
                KEYLAYOUT=$new_keylayout &&
                return 
            else
                printf "${Yellow}%s${Color_Off}\n" "$new_keylayout not found ... try again!" &&
                cmd_length=$((cmd_length+1)) &&
                new_keyboardlayout
            fi
            ;;
    esac
}



# TODO
# not accepting correct answer
new_timezone() {
    printf "Change timezone [N (use current %s)/ ? (list timezones)/ timezone]: " "$TIMEZONE"
    read -r new_tz
    
    cmd_length=$((cmd_length+1))
    case $new_tz in
        [?]* )
            timedatectl list-timezones | less &&
            new_timezone
            ;;
        [Nn] | '')
            ;;
        *)
            tz="$( timedatectl list-timezones | grep -P "^($new_tz)" )" > /dev/null 2>&1
            if [ "$(echo "$tz" | wc -l)" -eq '1' ] && timedatectl set-timezone "$new_tz"
            then
                TIMEZONE=$tz
                return 
            else
                printf "${Yellow}%s${Color_Off}\n" "$new_tz not found ... try again!" &&
                cmd_length=$((cmd_length+1)) &&
                new_timezone
            fi
            ;;
    esac
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
    while [ "$rows" -gt "0" ]
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
    printf "${Purple}${Arrow} %s${Color_Off}\n" "$1" &&
    case "$3" in
        '-1')
            eval " $2" 2>&1 | one_line_printf
            ;;
           *)
            eval " $2" > /dev/null 2>&1
            ;;
    esac
}

# Same as normal task but Yellow text
task_warning() {
    task_count=$((task_count+1)) &&
    printf "${Yellow}${CheckMark} %s${Color_Off}\n" "$1" &&
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
    printf "${Green}\033[s\033[1A\033[0K${CheckMark} %s\033[u${Color_Off}" "$@"
}

task_failed() {
    printf "${Red}${Cross} %s${Color_Off}" "$@"
    exit 1
}

tasks_done() {
    printf "${Green}\033[s\033[%sA\033[0K${CheckMark} %s\033[u${Color_Off}" "$task_count" "$@" &&
    task_count=1
}

header() {
    printf "${Purple}${Arrow} %s${Color_Off}\n" "$1"
    task_count=1
}






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
if [ "$KEYLAYOUT" = "n/a" ]
then
    KEYLAYOUT='en'
    localectl set-keymap $KEYLAYOUT
fi


if task 'Set keyboard layout' && new_keyboardlayout && line_cleaner
then
    task_done "Keyboard layout set to ${KEYLAYOUT}"
else
    task_failed "Failed setting keyboard to ${KEYLAYOUT}"
fi


# checking for internet
has_internet=true
if ! check_internet
then
	has_internet=false
fi


# Set Settings
section --task "Installer settings"
if ! "$has_internet";
then
    task_read 'WLAN SSID: ' && WLAN_SSID=$input
    task_read 'WLAN PASS: ' && WLAN_PASS=$input
fi
CRYPT_WANT='0'
task_read 'Encrypt disk? [Y/n] '
case $input in
  [Nn]* ) 
    CRYPT_WANT='1'
    ;;
  [Yy]* | '')
    task_read 'CRYPT PASS: ' && CRYPT_PASS=$input
    ;;
    * ) ;;
esac

task_read 'ROOT PASS: ' && ROOT_PASS=$input
task_read 'USER NAME: ' && USER_NAME=$input
task_read 'USER PASS: ' && USER_PASS=$input
task_read 'Country (for faster mirrors/ blank for None): ' && COUNTRY=$input

TIMEZONE='Europe/Vienna'
new_timezone

task_read 'Locale [Default en_US.UTF-8]: '
case $input in
    '' ) 
        LOCALE='en_US.UTF-8'
        ;;
    * )
        LOCALE="$input"
        ;;
esac

task_read 'Host name: ' && HOST=$input




# get all disks that are not hotplugable (no usb or sd card)
disks=$(lsblk -o type,path,hotplug | awk '$1 == "disk" && $3 == 0 { print $2 }')

if [ "$( echo "$disks" | wc -l )" -eq "1" ]
then
    DISK=$disks
elif [ "$( echo "$disks" | wc -l )" -gt "1" ]
then
    prompt=$( echo "$disks" | awk '{ print NR ") "$s }')
    task "$prompt"
    cmd_length=$((cmd_length + $(echo "$prompt" | wc -l) ))

    task_read "Choose one disk: "
    DISK="$( echo "$disks" | sed -n "${input}"p )"
else
    task_failed "WTF no available disks or all are hotplug" 
    exit 1
fi


# Get the filesystem
filesystems="btrfs lvm2"
filesystems=$(echo "$filesystems" | sed "s/ /\\n/g")

if [ "$( echo "$filesystems" | wc -l )" -eq "1" ] 
then
    FILESYSTEM=$filesystems
elif [ "$( echo "$filesystems" | wc -l )" -gt "1" ] 
then
    echo "Select a filesystem: "
    prompt="$(echo "$filesystems" | sed "s/ /\\n/g" | awk '{ print NR ") "$s }')"
    echo "$prompt"
    cmd_length=$((cmd_length + $(echo "$prompt" | wc -l) + 1))

    task_read "Choose one filesystem: "
    FILESYSTEM="$( echo "$filesystems" | sed "s/ /\\n/g" | sed -n "${input}"p )"
else
    task_failed "WTF no available filesystem in $filesystems" 
    exit 1
fi


bootls="GRUB Systemd"
bootls=$( echo "$bootls" | sed "s/ /\\n/g" )

if [ "$( echo "$bootls" | wc -l )" -eq "1" ]
then
    BOOTLOADER=$bootls
elif [ "$( echo "$bootls" | wc -l )" -gt "1" ]
then
    echo "Select a bootloader: "
    prompt="$(echo "$bootls" | sed "s/ /\\n/g" | awk '{ print NR ") "$s }')"
    echo "$prompt"
    cmd_length=$((cmd_length + $(echo "$prompt" | wc -l) + 1))

    task_read "Choose one Bootloader: "
    BOOTLOADER="$( echo "$bootls" | sed "s/ /\\n/g" | sed -n "${input}"p )"
else
    task_failed "WTF no available bootloaders for $bootls"
fi


#CPU
cpus="AMD Intel"
cpus=$( echo "$cpus" | sed "s/ /\\n/g" )

prompt="$(echo "$cpus" | sed "s/ /\\n/g" | awk '{ print NR ") "$s }')"
echo "$prompt"
cmd_length=$((cmd_length + $(echo "$prompt" | wc -l) ))

task_read "Choose one CPU: "
CPU="$( echo "$cpus" | sed "s/ /\\n/g" | sed -n "${input}"p )"


#GPU
gpus="AMD Intel Nvidia"
gpus=$( echo "$gpus" | sed "s/ /\\n/g" )

prompt="$(echo "$gpus" | sed "s/ /\\n/g" | awk '{ print NR ") "$s }')"
echo "$prompt"
cmd_length=$((cmd_length + $(echo "$prompt" | wc -l) ))

task_read "Choose one GPU: "
GPU="$( echo "$gpus" | sed "s/ /\\n/g" | sed -n "${input}"p )"




enviroments="KDE awesome none"
enviroments=$( echo "$enviroments" | sed "s/ /\\n/g" )

prompt="$(echo "$enviroments" | sed "s/ /\\n/g" | awk '{ print NR ") "$s }')"
echo "$prompt"
cmd_length=$((cmd_length + $(echo "$prompt" | wc -l) ))

task_read "Choose one enviroment: "
ENVIROMENT="$( echo "$enviroments" | sed "s/ /\\n/g" | sed -n "${input}"p )"



line_cleaner
line_cleaner --task



# Making sure everything is good to go
section "Settings Summary"


if ! $has_internet;
then
    section "Network Settings" '-'
    printf "WLAN SSID: %34s\n" "${WLAN_SSID}"
	printf "WLAN password: %30s\n" "${WLAN_PASS}"
fi
section "Locale" '-'
printf "Keyboard layout: %28s\n" "${KEYLAYOUT}"
if [ "$COUNTRY" ]
then
    printf "Country: %36s\n" "${COUNTRY}"
fi
printf "Timezone: %35s\n" "${TIMEZONE}"
printf "Locale: %37s\n" "${LOCALE}"

section "System" '-'
printf "Host name: %34s\n" "${HOST}"
printf "Enviroment: %33s\n" "${ENVIROMENT}"

section "User/passwd" '-'
if [ "$CRYPT_WANT" ]
then
    printf "Crypt password: %29s\n" "${CRYPT_PASS}"
fi
printf "Root password: %30s\n" "${ROOT_PASS}"                                                                     
printf "User name: %34s\n" " ${USER_NAME}"                                                                     
printf "User password: %30s\n" "${USER_PASS}"

section "Disk/partitions" '-'
printf "Disk for the system: %24s\n" "${DISK}"
printf "Filesystem: %33s\n" "${FILESYSTEM}"
printf "Bootloader: %33s\n" "${BOOTLOADER}"

printf "CPU: %40s\n" "$CPU"
printf "GPU: %40s\n" "$GPU"





# has Touchpad
# cat /proc/bus/input/devices | grep 'Touchpad'

# has battery
# cat /sys/class/power_supply/BAT0/capacity



# bonus stuff: search if another filesystems or boot /efi is already here. maybe look into fstab


section "Partition Table" '-'
if [ $CRYPT_WANT ]
then
    # Format disk with crypt
    printf "nvme0n1       disk\n"                                                              
    printf "├─nvme0n1p1   part  /mnt/boot/efi\n"                                                  
    printf "├─nvme0n1p2   part  /mnt/boot\n"                                                
    printf "└─nvme0n1p3   part\n"                                                           
    printf "  └─cryptroot crypt /mnt/var\n"                                                
    printf "                    /mnt/.snapshots\n"                                            
    printf "                    /mnt/home\n"                                                  
    printf "                    /mnt\n"
else
    # Format without crypt
    printf "nvme0n1       disk\n"                                                              
    printf "├─nvme0n1p1   part  /mnt/boot/efi\n"                                                  
    printf "├─nvme0n1p2   part  /mnt/boot\n"                                                
    printf "└─nvme0n1p3   part\n"
    
    printf "NOT yet implemented/n"
fi
echo

printf "Everything correct and ready to go? [Y/n] "
read -r input
case $input in
  [Nn]* ) exit 0;;
      * ) ;;
esac


echo
section "Lets go"



# TODO check if its work and clears correctly
# Connecting and checking for network connectivity
if ! $has_internet 
then
    	task "Setting Internet..." &&
    	echo "[Security]" > /var/lib/iwd/"$WLAN_SSID".psk &&
    	wpa_passphrase "$WLAN_SSID" "$WLAN_PASS" | grep psk |sed 's/#psk=/Passphrase=/g' \
        	|sed 's/[[:space:]]//g' |sed 's/psk=/PreSharedKey=/g' >> /var/lib/iwd/"$WLAN_SSID".psk && 
	
    	iwctl station wlan0 disconnect && iwctl station wlan0 connect "$WLAN_SSID" > /dev/null 2>&1 && sleep 10
	
	if check_internet;
	then
        	task_done "Internet connected via iwctl" && has_internet=true
	else
        	task_failed "No Internet - is the ssid or password correct?" && exit 1
	fi
fi



# Enable the NTP service
if task "Enabling NTP service..." "timedatectl set-ntp true"
then
    task_done "Enabled NTP service"
else
    task_failed "Failed Enabling" 
fi


if [ $CRYPT_WANT ]
then

    # Disk Setup
    header "Start disk setup..."

    ## Check is everything dismounted and crypt closed
    DIR=/mnt
    if is_mounted $DIR
    then
        if task_warning "├─ $DIR is mounted! -- trying unmounting" "umount -R $DIR"
        then
            task_done "├─ Unmounted $DIR"
        else
            task_failed "├─ Failed unmounting $DIR "
        fi
    fi


    CRY_CLOSE=$(dmsetup ls |grep crypt |cut -f1)
    if [ -n "$CRY_CLOSE" ]
    then
        if task_warning "├─ Luks mapper ($CRY_CLOSE) is open -- trying closing" "cryptsetup close /dev/mapper/$CRY_CLOSE"
        then
            task_done "├─ Closed $CRY_CLOSE"
        else
            task_failed "├─ Failed closing $CRY_CLOSE"
        fi
    fi


    ## Wipe everything
    if task "Start wiping $DISK (this will take a few minutes)" "shred -fvzn 0 $DISK 2>&1" "-1" 
    then
        task_done "├─ Wiped $DISK"
    else
        task_failed "├─ Failed wiping $DISK"
    fi


    ## create partitions EFI, BOOT, ROOT
    if task "├─ Start partitioning $DISK" "fdisk /dev/nvme0n1 <<EOF > /dev/null 2>&1
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
    EOF"
    then
        task_done "├─ Partitions created"
    else
        task_failed "├─ Partitioning failed"
    fi


    PART_EFI="${DISK}p1"
    PART_BOOT="${DISK}p2"
    PART_ROOT="${DISK}p3"

    ## Create cryptroot and open it 
    if task "├─ Start encrypting $PART_ROOT" &&
        printf "%s" "$CRYPT_PASS" | cryptsetup luksFormat "$PART_ROOT" - &&
        printf "%s" "$CRYPT_PASS" | cryptsetup luksOpen "$PART_ROOT" cryptroot -
    then
        task_done "├─ Encrypted and opened $PART_ROOT"
    else
        task_failed "├─ Failed encrypting $PART_ROOT"
    fi


    ## Creating filesystems and subvolumes
    if task "├─ Create filesystems for partitions and create subvolumes" && 
        mkfs.vfat "$PART_EFI" > /dev/null &&
        mkfs.btrfs "$PART_BOOT" -f > /dev/null &&
        mkfs.btrfs /dev/mapper/cryptroot -f > /dev/null &&
        mount /dev/mapper/cryptroot /mnt &&
        btrfs su cr /mnt/@ > /dev/null &&
        btrfs su cr /mnt/@home > /dev/null &&
        btrfs su cr /mnt/@snapshots > /dev/null &&
        btrfs su cr /mnt/@var > /dev/null &&
        umount /mnt
    then
        task_done "├─ Created filesystems for partitions and subvolumes"
    else
        task_failed "├─ Failed creating filesystem for partitions and subvolumes"
    fi


    ## Mount EFI, Boot and subvolumes
    if task "└─ Mount EFI, boot and subvolumes" && 
        mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@ /dev/mapper/cryptroot /mnt &&
        mkdir -p /mnt/home &&
        mkdir -p /mnt/.snapshots &&
        mkdir -p /mnt/var &&
        mkdir -p /mnt/boot &&
        mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@home /dev/mapper/cryptroot /mnt/home &&
        mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@snapshots /dev/mapper/cryptroot /mnt/.snapshots &&
        mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd,subvol=@var /dev/mapper/cryptroot /mnt/var &&
        mount -o noatime,compress=zstd,space_cache=v2,discard=async,ssd "$PART_BOOT" /mnt/boot &&
        mkdir -p /mnt/boot/efi &&
        mount "$PART_EFI" /mnt/boot/efi
    then
        task_done "└─ Mounted EFI, boot and subvolumes"
    else
        task_failed "└─ Failed mounting EFI, boot and subvolumes"
    fi


    ## Setting Task to done.
    tasks_done "Successfully setup $DISK"

fi



# Configure pacman, set mirrorlist and install needed pkgs
if task "Update pacman.conf" &&
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf &&
    sed -i "/Color/s/^#//" /etc/pacman.conf &&
    sed -i "/ParallelDownloads/s/^#//" /etc/pacman.conf
then
    task_done "Updated pacman.conf"
else
    task_failed "Failed to update pacman.conf"
fi



# reflector
if [ -n "$COUNTRY" ]
then
    if task "Update pacman.d/mirrorlist" &&
        reflector --protocol https --country "$COUNTRY" --score 50 --sort rate --save /etc/pacman.d/mirrorlist > /dev/null 2>&1
    then
        task_done "Updated pacman.d/mirrorlist"
    else
        task_failed "Failed updating pacman.d/mirrorlist"
    fi
else
    if task "Update pacman.d/mirrorlist" &&
        reflector --protocol https --latest 50 --score 50 --sort rate --save /etc/pacman.d/mirrorlist > /dev/null 2>&1
    then
        task_done "Updated pacman.d/mirrorlist"
    else
        task_failed "Failed updating pacman.d/mirrorlist"
    fi
fi





# TODO
# if wanna use grub and btrfs
if [ "$CPU" = "AMD" ]
then
    cpu_pkg="amd-ucode"
elif [ "$CPU" = "Intel" ]
then
    cpu_pkg="intel-ucode"
fi

if [ "$GPU" = "AMD" ]
then
    gpu_pkg="mesa vulkan-radeon"
elif [ "$GPU" = "Intel" ]
then
    gpu_pkg="mesa vulkan-intel"
elif [ "$GPU" = "Nvidia" ]
then
    gpu_pkg="nvidia"
fi


#TODO output to other tty or just normal output
# install pkgs via pacstrap
if task "Install basic packages via pacstrap" &&
    pacstrap /mnt base base-devel linux linux-firmware vim openssh git dialog jq man \
            $cpu_pkg $gpu_pkg btrfs-progs grub grub-btrfs efibootmgr networkmanager go ttf-firacode-nerd
then
    echo 
    task_done "Installed pacman packages"
else
    echo 
    task_failed "Failed installing pacman packages"
fi



# generate fstab
if task "Generate fstab" &&
    genfstab -U /mnt > /mnt/etc/fstab
then
    task_done "Generated fstab into /mnt/etc/fstab"
else
    task_failed "Failed Generating fstab"
fi



# Locale
if task "Generating locales" &&
    sed -i "/$LOCALE/s/^#//g" /mnt/etc/locale.gen && 
    arch-chroot /mnt /bin/bash -c "locale-gen > /dev/null 2>&1" && 
    echo "LANG=$LOCALE" > /mnt/etc/locale.conf
then
    task_done "Generated locale to $LOCALE"
else
    task_failed "Failed Generating locale $LOCALE"
fi


# Hostname
if task "Setting hostname $HOST" &&
    echo "${HOST}" > /mnt/etc/hostname 
then
    task_done "Set hostname to $HOST"
else
    task_failed "Failed setting hostname $HOST"
fi


# Hosts 
if task "Setting hosts" &&
    printf "127.0.0.1  localhost\n::1        localhost\n127.0.1.1  %s.local  %s\n" "$HOST" "$HOST" > /mnt/etc/hosts 
then
    task_done "Set hosts"
else
    task_failed "Failed setting hosts"
fi



# Start Grub setup
header "Make it bootable"


## Grub setup
if task "├─ Installing $BOOTLOADER" &&
    arch-chroot /mnt /bin/bash -c 'grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB' > /dev/null 2>&1
then
    task_done "├─ Installed $BOOTLOADER"
else
    task_failed "├─ Failed installing $BOOTLOADER"
fi




## crypt 
if task "├─ Configuring and running mkinitcpio" &&
    sed -i '/^BINARIES=/ s/()/(btrfs)/i' /mnt/etc/mkinitcpio.conf &&
    sed -i '/^HOOKS=/ s/autodetect modconf block filesystems keyboard/btrfs autodetect modconf block keyboard keymap encrypt filesystems/i' /mnt/etc/mkinitcpio.conf &&
    arch-chroot /mnt /bin/bash -c "mkinitcpio -p linux > /dev/null 2>&1"
then
    task_done "├─ Configured /etc/mkinitcpio.conf and run mkinitcpio"
else
    task_failed "├─ Failed Configuring and running mkinitcpio"
fi





## set crypt option in /etc/default/grub
if task "├─ Configuring default grub" &&
    CRYPT_UUID=$( blkid |tr '\n' ' ' | awk "{ sub(/.*\$DISK: /, \"\"); sub(/TYPE=\"crypto_LUKS\"*.*/, \"\"); print }" | tr -d '"' | awk -F ' ' '{print $2}' ) &&
    sed -i "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=3/g" /mnt/etc/default/grub &&
    sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"loglevel=3 quiet\"/\"loglevel=3 quiet cryptdevice=$CRYPT_UUID:cryptroot root=\/dev\/mapper\/cryptroot\"/i" /mnt/etc/default/grub
then
    task_done "├─ Configured default grub /etc/default/grub"
else
   task_failed "├─ Failed Configuring grub /etc/default/grub" 
fi



## Setup Grub Themes (custom grup)
if task "├─ Installing grub2 vimix theme" &&
    arch-chroot /mnt /bin/bash -c "git clone https://github.com/vinceliuice/grub2-themes.git /grub2-themes > /dev/null 2>&1" &&
    mkdir -p /mnt/boot/grub/themes &&
    /mnt/grub2-themes/install.sh -t vimix -g /mnt/boot/grub/themes > /dev/null 2>&1  &&
    rm -rf /mnt/grub2-themes &&
    sed -i "s|.*GRUB_THEME=.*|GRUB_THEME=\"boot\/grub\/themes\/vimix/theme.txt\"|" /mnt/etc/default/grub &&
    sed -i "s|.*GRUB_GFXMODE=.*|GRUB_GFXMODE=1920x1080,auto|" /mnt/etc/default/grub
then
    task_done "├─ Installed grub2 vimix theme"
else
    task_failed "├─ Failed installing grub2 vimix theme"
fi


## generate grub config
if task "└─ Generating grub config" &&
    arch-chroot /mnt /bin/bash -c "grub-mkconfig -o /boot/grub/grub.cfg" > /dev/null 2>&1 
then 
    task_done "└─ Generated grub config"
else
    task_failed "└─ Failed Generating grub config"
fi


tasks_done "Made it bootable"


if [ "$ENVIROMENT" = "none" ]
then
    echo "Installed basic Arch."
    echo
    printf "before rebooting run\n"
    printf "umount -R /mnt && reboot\n"

    exit 0
fi




# TODO not setting done or faile
# update pacman.conf 
if task "Updating pacman.conf for the new system" &&
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf &&
    sed -i "/Color/s/^#//" /mnt/etc/pacman.conf &&
    sed -i "/ParallelDownloads/s/^#//" /mnt/etc/pacman.conf
then
    task_done "Updated pacman.conf"
else
    task_failed "Failed updating pacman.conf"
fi






# Install packages
if [ "$ENVIROMENT" = "KDE" ]
then

    if task "Installing $ENVIROMENT enviroment" &&
        pacstrap /mnt wayland plasma-wayland-session sddm sddm-kcm plasma-desktop plasma-nm iwd powerdevil \
            dolphin dolphin-plugins kdeplasma-addons kdeconnect kde-gtk-config kscreen kinfocenter firefox \
            bluedevil pulseaudio plasma-pa pulseaudio-bluetooth bluez bluez-utils pulseaudio-alsa \
            alsa-firmware alsa-ucm-conf sof-firmware alsa-plugins \
            kitty zsh dash neovim reflector thunderbird discord btop exa procs ripgrep intellij-idea-community-edition jdk-openjdk neofetch tldr
    then
        echo
        task_done "Installed $ENVIROMENT packages"
    else
        echo
        task_failed "Failed installing $ENVIROMENT packages"
    fi

elif [ "$ENVIROMENT" = "awesome" ]
then
    
    if task "Installing $ENVIROMENT enviroment" &&
        pacstrap /mnt picom sxhkd sddm iwd powerdevil \
            ranger  rofi rofi-calc kdeconnect \
            neofetch tldr reflector btop exa procs ripgrep \
            firefox kitty zsh dash neovim  thunderbird discord  \
            alsa-firmware alsa-ucm-conf sof-firmware pipewire pipewire-alsa pipewire-audio playerctl \
            bluedevil bluez bluez-utils blueberry
    then
        echo
        task_done "Installed $ENVIROMENT packages"
    else
        echo
        task_failed "Failed installing $ENVIROMENT packages"
    fi

else
    task_failed "$ENVIROMENT unknown"
fi
    


# Setup dash
if task "Setting dash as default shell and creating pacman hook" &&
    arch-chroot /mnt /bin/bash -c "ln -sfT dash /usr/bin/sh" &&
    echo '[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = bash

[Action]
Description = Re-pointing /bin/sh symlink to dash...
When = PostTransaction
Exec = /usr/bin/ln -sfT dash /usr/bin/sh
Depends = dash' > /mnt/usr/share/libalpm/hooks/update-bash.look
then
    task_done "Set dash as default shell and created pacman hook"
else
    task_failed "Failed setting dash as default shell and creating pacman hook"
fi


# root passwd
if task "Setting root pass" &&
    arch-chroot /mnt /bin/bash -c "echo 'root:$ROOT_PASS' |chpasswd"
then
    task_done "Set root pass"
else
    task_failed "Failed setting root pass"
fi


# Useradd and passwd
if task "Creating user $USER_NAME and setting pass" &&
    arch-chroot /mnt /bin/bash -c "useradd -mG wheel -s /usr/bin/zsh $USER_NAME && echo '$USER_NAME:$USER_PASS' | chpasswd"
then
    task_done "Created $USER_NAME, set pass and added to wheel"
else
    task_failed "Failed creating user $USER_NAME"
fi


# works until here ===============================================

# Install yay
## uncomment no pass wheel for yay install
if task "Activating wheel no passwd (for further user configuration)" &&
    arch-chroot /mnt /bin/bash -c "chmod +w /etc/sudoers &&
    sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers &&
    chmod 0440 /etc/sudoers"
then
    task_done "Activated wheel no passwd (for further config)"
else
    task_failed "Failed activating wheel no passwd"
fi


# TODO
# has Touchpad install touchegg

## install yay as new user
if task "Installing yay and aur packages" &&
    arch-chroot /mnt /bin/bash -c "runuser -l $USER_NAME -c 'git clone https://aur.archlinux.org/yay-git.git ~/yay-git > /dev/null 2>&1 &&
    cd ~/yay-git &&
    makepkg -si --noconfirm > /dev/null 2>&1 &&
    rm -rf ~/yay-git &&
    yay -Syyyu timeshift touchegg polybar-git ranger_devicons-git ncspot-cover awesome-git --noconfirm --removemake'" 
then
    echo
    task_done "Installed yay and aur pkgs"
else
    task_failed "Failed installing yay and aur pkgs"
fi


# install dotfiles
if task "Installing dotfiles" &&
    arch-chroot /mnt /bin/bash -c "git clone https://github.com/FromWau/dotfiles.git > /dev/null 2>&1" 
    cp -r /mnt/dotfiles/.zshenv /mnt/home/"$USER_NAME" &&
    cp -r /mnt/dotfiles/.config /mnt/home/"$USER_NAME"
then
    task_done "Installed dotfiles"
else
    task_failed "Failed installing dotfiles"
fi



# create playerctld.service
if task "Create playerctld.service" &&
    echo "[Unit]
Description=Keep track of media player activity

[Service]
Type=oneshot
ExecStart=/usr/bin/playerctld daemon

[Install]
WantedBy=default.target" > /mnt/usr/lib/systemd/user/playerctld.service
then
    task_done "Created /usr/lib/systemd/user/playerctld.service"
else
    task_failed "Failed creating /usr/lib/systemd/user/playerctld.service"
fi


# enable experimental bluetooth features to be able to see the bluetooth headset battery
if task "Updating bluetooth.service" &&
    sed -i "s/ExecStart\=\/usr\/lib\/bluetooth\/bluetoothd/ExecStart\=\/usr\/lib\/bluetooth\/bluetoothd --experimental/g" /mnt/usr/lib/systemd/system/bluetooth.service
then
    task_done "Set experimental bluetoothd"
else
    task_failed "Failed setting bluetoothd experimental"
fi


# Enable Services
if task "Enabling systemd services" &&
    arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager --quiet &&
    systemctl enable sshd.service --quiet &&
    systemctl enable sddm.service --quiet &&
    systemctl enable cronie.service --quiet &&
    systemctl enable bluetooth.service --quiet &&
    systemctl enable upower.service --quiet
    systemctl --user enable playerctld.service --quiet"
then
    task_done "Enabled systemd services"
else
    task_failed "Failed Enabling services"
fi




# setup NetworkManager use iwd as backend and copy already setup networks
if task "Setting NetworkManager backend to iwd and copy known psk files" &&
    printf "[device]\nwifi.backend=iwd" > /mnt/etc/NetworkManager/conf.d/wifi_backend.conf && 
    mkdir -p /mnt/var/lib/iwd/ &&
    cp -r /var/lib/iwd/* /mnt/var/lib/iwd/ 
then
    task_done "Set iwd as NetworkManager backend and copied already known networks over"
else
    task_failed "Failed setting iwd as NetworkManager backend"
fi




# enable wheel properly
if task "Activating wheel group and deactivating wheel nopasswd" &&
    arch-chroot /mnt /bin/bash -c "chmod +w /etc/sudoers &&
    sed -i 's/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers &&
    sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers &&
    chmod 0440 /etc/sudoers"
then
    task_done "Activated wheel group and deactivated wheel no passwd"
else
    task_failed "Failed activating wheel and deactivating wheel no passed"
fi


# create vconsole
if task "Setting keyboad layout $KEYLAYOUT for new system"
    echo "KEYMAP=$KEYLAYOUT" > /mnt/etc/vconsole.conf
then
    task_done "Set keyboad layout $KEYLAYOUT for new system (x11)"
else
    task_failed "Failed setting $KEYLAYOUT to new keyboad layout (x11)"
fi



# setup nvim
if task "Setting up neovim" &&
    arch-chroot /mnt /bin/bash -c "runuser -l $USER_NAME -c 'nvim --headless +source +PackerSync +qa > /dev/null 2>&1'"
then
    task_done "Setup neovim"
else
    task_failed "Failed setting up neovim"
fi


# clean home (remove cargo)
if task "Clean up /home/$USER_NAME" &&
    rm -rf /mnt/home/"$USER_NAME"/.cargo
then
    task_done "Cleaned up /home/$USER_NAME"
else
    task_failed "Failed cleaning up /home/$USER_NAME"
fi



echo 
section "POST Install Summary"
echo 'for changing the keymap use:'
echo 'localectl set-x11-keymap de'

echo
section "before rebooting"
echo "run:"
echo "umount -R /mnt && reboot"



# Check until here ==================================




