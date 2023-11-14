echo '

this might work, but use on Vanilla Arch w/ KDE'

sudo wget https://bit.ly/get-arcolinux-keys

sudo chmod +x get-arcolinux-keys

sudo ./get-arcolinux-keys

sudo pacman -Syu archlinux-tweak-tool-dev-git

sudo pacman -S yay pacseek git wget curl --noconfirm --needed

sudo git clone https://github.com/rubixcube199/configs

sudo git clone https://github.com/rubixcube199/Wallpapers

sudo curl -O https://blackarch.org/strap.sh

sudo chmod +x strap.sh

sudo ./strap.sh

sudo pacman -Syu
