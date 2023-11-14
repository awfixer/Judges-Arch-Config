#!/bin/sh

echo '

This Script is broken, use at your own risk'


# mirror file to fetch and write
MIRROR_F="blackarch-mirrorlist"

# simple error message wrapper
err()
{
  echo >&2 "$(tput bold; tput setaf 1)[-] ERROR: ${*}$(tput sgr0)"

  exit 1337
}

# simple warning message wrapper
warn()
{
  echo >&2 "$(tput bold; tput setaf 1)[!] WARNING: ${*}$(tput sgr0)"
}

# simple echo wrapper
msg()
{
  echo "$(tput bold; tput setaf 2)[+] ${*}$(tput sgr0)"
}

# check for root privilege
check_priv()
{
  if [ "$(id -u)" -ne 0 ]; then
    err "you must be root"
  fi
}

# make a temporary directory and cd into
make_tmp_dir()
{
  tmp="$(mktemp -d /tmp/blackarch_strap.XXXXXXXX)"

  trap 'rm -rf $tmp' EXIT

  cd "$tmp" || err "Could not enter directory $tmp"
}

set_umask()
{
  OLD_UMASK=$(umask)

  umask 0022

  trap 'reset_umask' TERM
}

reset_umask()
{
  umask $OLD_UMASK
}

check_internet()
{
  tool='curl'
  tool_opts='-s --connect-timeout 8'

  if ! $tool $tool_opts https://blackarch.org/ > /dev/null 2>&1; then
    err "You don't have an Internet connection!"
  fi

  return $SUCCESS
}

# retrieve the BlackArch Linux keyring
fetch_keyring()
{
  curl -s -O \
  'https://www.blackarch.org/keyring/blackarch-keyring.pkg.tar.xz'

  curl -s -O \
  'https://www.blackarch.org/keyring/blackarch-keyring.pkg.tar.xz.sig'
}

# verify the keyring signature
# note: this is pointless if you do not verify the key fingerprint
verify_keyring()
{
  if ! gpg --keyserver keyserver.ubuntu.com \
     --recv-keys 4345771566D76038C7FEB43863EC0ADBEA87E4E3 > /dev/null 2>&1
  then
    if ! gpg --keyserver hkps://keyserver.ubuntu.com:443 \
       --recv-keys 4345771566D76038C7FEB43863EC0ADBEA87E4E3 > /dev/null 2>&1
    then
      if ! gpg --keyserver hkp://pgp.mit.edu:80 \
         --recv-keys 4345771566D76038C7FEB43863EC0ADBEA87E4E3 > /dev/null 2>&1
      then
        err "could not verify the key. Please check: https://blackarch.org/faq.html"
      fi
    fi
  fi

  if ! gpg --keyserver-options no-auto-key-retrieve \
    --with-fingerprint blackarch-keyring.pkg.tar.xz.sig > /dev/null 2>&1
  then
    err "invalid keyring signature. please stop by https://matrix.to/#/#/BlackaArch:matrix.org"
  fi
}

# delete the signature files
delete_signature()
{
  if [ -f "blackarch-keyring.pkg.tar.xz.sig" ]; then
    rm blackarch-keyring.pkg.tar.xz.sig
  fi
}

# make sure /etc/pacman.d/gnupg is usable
check_pacman_gnupg()
{
  pacman-key --init
}

# install the keyring
install_keyring()
{
  if ! pacman --config /dev/null --noconfirm \
    -U blackarch-keyring.pkg.tar.xz ; then
      err 'keyring installation failed'
  fi

  # just in case
  pacman-key --populate
}

# ask user for mirror
get_mirror()
{
  mirror_p="/etc/pacman.d"
  mirror_r="https://blackarch.org"

  msg "fetching new mirror list..."
  if ! curl -s "$mirror_r/$MIRROR_F" -o "$mirror_p/$MIRROR_F" ; then
    err "we couldn't fetch the mirror list from: $mirror_r/$MIRROR_F"
  fi

  msg "you can change the default mirror under $mirror_p/$MIRROR_F"
}

# update pacman.conf
update_pacman_conf()
{
  # delete blackarch related entries if existing
  sed -i '/blackarch/{N;d}' /etc/pacman.conf

  cat >> "/etc/pacman.conf" << EOF
[blackarch]
Include = /etc/pacman.d/$MIRROR_F
EOF
}

# synchronize and update
pacman_update()
{
  if pacman -Syy; then
    return $SUCCESS
  fi

  warn "Synchronizing pacman has failed. Please try manually: pacman -Syy"

  return $FAILURE
}


pacman_upgrade()
{
  echo 'perform full system upgrade? (pacman -Su) [Yn]:'
  read conf < /dev/tty
  case "$conf" in
    ''|y|Y) pacman -Su ;;
    n|N) warn 'some blackarch packages may not work without an up-to-date system.' ;;
  esac
}

# setup blackarch linux
blackarch_setup()
{
  check_priv
  msg 'installing blackarch keyring...'
  set_umask
  make_tmp_dir
  check_internet
  fetch_keyring
  verify_keyring
  delete_signature
  check_pacman_gnupg
  install_keyring
  echo
  msg 'keyring installed successfully'
  # check if pacman.conf has already a mirror
  if ! grep -q "\[blackarch\]" /etc/pacman.conf; then
    msg 'configuring pacman'
    get_mirror
    msg 'updating pacman.conf'
    update_pacman_conf
  fi
  msg 'updating package databases'
  pacman_update
  reset_umask
  msg 'BlackArch Linux is ready!'
}

blackarch_setup

sudo pacman -S wget --noconfirm --needed

sudo wget https://github.com/arcolinux/arcolinux_repo/raw/main/x86_64/arcolinux-keyring-20251209-3-any.pkg.tar.zst -O /tmp/arcolinux-keyring-20251209-3-any.pkg.tar.zst
sudo pacman -U --noconfirm --needed /tmp/arcolinux-keyring-20251209-3-any.pkg.tar.zst

sudo wget https://github.com/arcolinux/arcolinux_repo/raw/main/x86_64/arcolinux-mirrorlist-git-23.06-01-any.pkg.tar.zst -O /tmp/arcolinux-mirrorlist-git-23.06-01-any.pkg.tar.zst
sudo pacman -U --noconfirm --needed /tmp/arcolinux-mirrorlist-git-23.06-01-any.pkg.tar.zst
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

echo '
[athena-repository]
SigLevel = Optional TrustAll
#Include = /etc/pacman.d/athena-mirrorlist
Server = https://athena-os.github.io/$repo/$arch

[cachyos]
SigLevel = Optional TrustAll
#Include = /etc/pacman.d/cachyos-mirrorlist
Server = https://mirror.cachyos.org/repo/$arch/$repo

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist

[exodia-repo]
SigLevel = Optional TrustAll
Server = https://exodia-os.github.io/$repo/$arch

[Exodia-PenTest-Repo]
SigLevel = Optional TrustAll
Server = https://exodia-os.github.io/$repo/$arch

[exodia-community-repo]
SigLevel = Optional TrustAll
Server = https://exodia-os.github.io/$repo/$arch

[exodia-testing-repo]
SigLevel = Optional TrustAll
Server = https://exodia-os.github.io/$repo/$arch

[arcolinux_repo_testing]
SigLevel = PackageRequired DatabaseNever
Include = /etc/pacman.d/arcolinux-mirrorlist

[arcolinux_repo]
SigLevel = PackageRequired DatabaseNever
Include = /etc/pacman.d/arcolinux-mirrorlist

[arcolinux_repo_3party]
SigLevel = PackageRequired DatabaseNever
Include = /etc/pacman.d/arcolinux-mirrorlist

[arcolinux_repo_xlarge]
SigLevel = PackageRequired DatabaseNever
Include = /etc/pacman.d/arcolinux-mirrorlist' | sudo tee --append /etc/pacman.conf


sudo pacman -Sy

sudo pacman -Syyu archlinux-tweak-tool-dev-git obs-studio vivaldi steam bottles libvirtd wine wine-mono discord-update-skip-git kate qemu-full virt-manager gnome-boxes flatpak flatpak-kcm nix nix-init flatpak-builder nix-docs flatpak-docs pacseek yay thorium-browser-bin vim linux-lqx-headers autocpu-freq athena-mirrorlist athena-keyring cachyos-mirrorlist cachyos-keyring alhp-mirrorlist alhp-keyring --noconfirm


sudo systemctl enable --now libvirtd

echo '

[core-x86-64-v3]
Include = /etc/pacman.d/alhp-mirrorlist

[extra-testing]
Include = /etc/pacman,d/mirrorlist

[extra-x86-64-v3]
Include = /etc/pacman.d/alhp-mirrorlist' | sudo tee --append /etc/pacman.conf


sudo pacman -Syu mercury-browser-bin ame discord-canary discord-canary-update-skip-git

discord-canary-update-skip
discord-update-skip

sudo git clone https://github.com/rubixcube199/Wallpapers

sudo mv ~/Wallpapers /usr/share

sudo git clone https://aur.archlinux.org/guix-installer.github
sudo chmod 777 guix-installer

reboot
