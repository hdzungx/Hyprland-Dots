#!/bin/bash

# ==== Check if running Arch ==== #

# Import OS info as variables
. /etc/os-release

if [[ $ID != 'arch' ]]; then
  echo 'Arch Linux not detected.'
  echo 'This script only works on Arch or Arch based distros.'
  read -p 'Continue anyways? (y/N) ' confirmation
  confirmation=$(echo "$confirmation" | tr '[:lower:]' '[:upper:]')
  if [[ "$confirmation" == 'N' ]] || [[ "$confirmation" == '' ]]; then
    exit 1
  fi
fi


printf '\033[1;33mWARNING:\033[0m Most of the script has undergone VERY minimal testing and some parts have recieved none at all.\n'
read -p 'Continue anyways? (y/N) ' confirmation
confirmation=$(echo "$confirmation" | tr '[:lower:]' '[:upper:]')
if [[ "$confirmation" == 'N' ]] || [[ "$confirmation" == '' ]]; then
  exit 0
fi

# Function for installing packages
install_pacman_package() {
  # Checking if package is already installed
  if pacman -Q "$1" &>/dev/null ; then
    echo "$1 is already installed. Skipping..."
  else
    # Package not installed
    echo "Installing $1 ..."
    sudo pacman -S --noconfirm "$1"
    # Making sure package is installed
    if pacman -Q "$1" &>/dev/null ; then
      echo "Package $1 has been successfully installed!"
    else
      # Something is missing, exiting to review
      echo "$1 failed to install. Please check manually."
      exit 1
    fi
  fi
}

install_aur_package() {
  # Checking if package is already installed
  if paru -Q "$1" &>> /dev/null ; then
    echo "$1 is already installed. Skipping..."
  else
    # Package not installed
    echo "Installing $1 ..."
    paru -S --noconfirm "$1"
    # Making sure package is installed
    if paru -Q "$1" &>> /dev/null ; then
      echo "Package $1 has been successfully installed!"
    else
      # Something is missing, exiting to review
      echo "$1 failed to install :( , please check manually!"
      exit 1
    fi
  fi
}

# ==== Install packages ==== #

read -p 'Confirm package operations? (y/N) ' pacConfirm
pacConfirm=$(echo "$pacConfirm" | tr '[:lower:]' '[:upper:]')
if [[ ! $pacConfirm == 'Y' ]]; then
  pacArgs=('--noconfirm')  # An array in case I want to add more later
fi

# Update system
sudo pacman -Syu --noconfirm

# Install official repository packages
pacman_packages=(
    base-devel pacman-contrib libnotify ffmpeg ffmpegthumbnailer jq parallel kitty fastfetch lsd bat brightnessctl
    automake blueman bluez bluez-utils dunst fakeroot dpkg gcc git gnu-netcat btop mat2 dolphin papirus-icon-theme
    pavucontrol pamixer pipewire pipewire-pulse pipewire-audio pipewire-jack pipewire-alsa wireplumber python-pyalsa
    ranger redshift reflector sudo tree unrar zip unzip uthash ark cmake clang gzip make openssh shellcheck vlc loupe
    usbutils openvpn networkmanager-openvpn p7zip gparted sshfs wget netctl ttf-jetbrains-mono ttf-jetbrains-mono-nerd
    ttf-fira-code ttf-iosevka-nerd playerctl starship upower udiskie zenity gvfs qt5ct qt6ct timeshift sddm
    qt5-graphicaleffects qt5-svg qt5-quickcontrols2 clipnotify xdg-desktop-portal-gtk gnome-disk-utility evince neovim tmux
    cowsay polkit-gnome rofi-wayland rofimoji wmname pyenv xdg-desktop-portal ttf-hack-nerd hyprland waybar
    cliphist wl-clipboard xdg-desktop-portal-hyprland qt5-wayland qt6-wayland xdg-desktop-portal-wlr hypridle zsh swww
    python python-pip zathura-pdf-poppler nemo nwg-look peaclock yt-dlp fcitx5 fcitx5-bamboo fcitx5-configtool fcitx5-gtk fcitx5-qt
    gnome-keyring libsecret
)

for package in "${pacman_packages[@]}"; do
  install_pacman_package "$package"
done

# Install AUR packages
aur_packages=(
    flameshot-git bibata-cursor-theme-bin tela-circle-icon-theme-dracula themix-theme-oomox-git themix-plugin-base16-git
    themix-icons-papirus-git themix-gui-git themix-export-spotify-git themix-theme-materia-git oomox-qt5-styleplugin-git
    oomox-qt6-styleplugin-git cava youtube-dl update-grub ttf-meslo-nerd-font-powerlevel10k visual-studio-code-bin
    hyprpicker swaylock-effects-git wlr-randr-git hyprprop grimblast-git google-chrome wlogout cmatrix-git telegram-desktop-bin
)   

# Check if paru is installed, if not, install it
if ! command -v paru &>/dev/null; then
    echo "Paru not found, installing..."
    git clone https://aur.archlinux.org/paru.git
    cd paru || exit
    makepkg -si --noconfirm
    cd ..
    rm -rf paru
fi

# Install AUR packages using paru
for package in "${aur_packages[@]}"; do
  install_aur_package "$package"
done

read -p 'Do you want to install NVIDIA drivers? (y/N) ' confirmation
confirmation=$(echo "$confirmation" | tr '[:lower:]' '[:upper:]')
if [[ "$confirmation" == 'Y' ]] || [[ "$confirmation" == '' ]]; then
  nvidia_pkg=(
    nvidia-dkms
    nvidia-settings
    nvidia-utils
    libva
    libva-nvidia-driver-git
  )

  # Install additional Nvidia packages
  echo "Installing additional Nvidia packages..."
  for krnl in $(cat /usr/lib/modules/*/pkgbase); do
    for NVIDIA in "${krnl}-headers" "${nvidia_pkg[@]}"; do
      install_aur_package "$NVIDIA"
    done
  done

  # Check if the Nvidia modules are already added in mkinitcpio.conf and add if not
  if grep -qE '^MODULES=.*nvidia. *nvidia_modeset.*nvidia_uvm.*nvidia_drm' /etc/mkinitcpio.conf; then
    echo "Nvidia modules already included in /etc/mkinitcpio.conf"
  else
    sudo sed -Ei 's/^(MODULES=\([^\)]*)\)/\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    echo "Nvidia modules added in /etc/mkinitcpio.conf"
  fi

  sudo mkinitcpio -P

  # Additional Nvidia steps
  NVEA="/etc/modprobe.d/nvidia.conf"
  if [ -f "$NVEA" ]; then
    echo "Seems like nvidia-drm modeset=1 is already added in your system..moving on."
  else
    echo "Adding options to $NVEA..."
    sudo echo -e "options nvidia_drm modeset=1 fbdev=1" | sudo tee -a /etc/modprobe.d/nvidia.conf
  fi

  # Additional for GRUB users
  if [ -f /etc/default/grub ]; then
      if ! sudo grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
          sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia-drm.modeset=1"/' /etc/default/grub
          echo "nvidia-drm.modeset=1 added to /etc/default/grub"
      fi
      if ! sudo grep -q "nvidia_drm.fbdev=1" /etc/default/grub; then
          sudo sed -i -e 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia_drm.fbdev=1"/' /etc/default/grub
          echo "nvidia_drm.fbdev=1 added to /etc/default/grub"
      fi
      sudo grub-mkconfig -o /boot/grub/grub.cfg
  else
      echo "/etc/default/grub does not exist"
  fi

  # Blacklist nouveau
  if [[ -z $blacklist_nouveau ]]; then
    read -n1 -rep "Would you like to blacklist nouveau? (y/n)" blacklist_nouveau
  fi
  echo
  if [[ $blacklist_nouveau =~ ^[Yy]$ ]]; then
    NOUVEAU="/etc/modprobe.d/nouveau.conf"
    if [ -f "$NOUVEAU" ]; then
      echo "Seems like nouveau is already blacklisted..moving on."
    else
      echo "blacklist nouveau" | sudo tee -a "$NOUVEAU"
      if [ -f "/etc/modprobe.d/blacklist.conf" ]; then
        echo "install nouveau /bin/true" | sudo tee -a "/etc/modprobe.d/blacklist.conf"
      else
        echo "install nouveau /bin/true" | sudo tee "/etc/modprobe.d/blacklist.conf"
      fi
    fi
  else
    echo "Skipping nouveau blacklisting."
  fi
fi

read -p 'Do you want to install ASUS ROG packages? (y/N) ' confirmation
confirmation=$(echo "$confirmation" | tr '[:lower:]' '[:upper:]')
if [[ "$confirmation" == 'Y' ]] || [[ "$confirmation" == '' ]]; then
  echo "Installing ASUS ROG packages..."
  for ASUS in power-profiles-daemon asusctl supergfxctl rog-control-center; do
    install_aur_package "$ASUS"
    if [ $? -ne 0 ]; then
      echo "$ASUS package installation failed. Please check manually."
      exit 1
    fi
  done

  echo "Activating ROG services..."
  sudo systemctl enable supergfxd

  echo "Enabling power-profiles-daemon..."
  sudo systemctl enable power-profiles-daemon

  echo "Installation and activation ROG Package & Servicecompleted."
fi

# Final message
echo "All packages installed successfully."


if [[ ! -d $HOME/.oh-my-zsh ]]; then
  export CHSH='yes'
  export RUNZSH='no'
  export KEEP_ZSHRC='yes'
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  # Install zsh-autosuggestions and zsh-syntax-highlighting
  echo -e "\n\nClone zsh-autosuggestion and zsh-syntax-highlighting\n\n"
  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

# ==== Install sddm ==== #
if ! pacman -Q sddm &>/dev/null; then
  read -p 'Install sddm? (Y/n) ' instSDDM
  instSDDM=$(echo "$instSDDM" | tr '[:lower:]' '[:upper:]')
  if [[ "$instSDDM" == 'Y' ]] || [[ "$instSDDM" == '' ]]; then
    echo 'Installing sddm...'
    sudo pacman "${pacArgs[@]}" -S sddm
    sudo systemctl enable sddm.service
  fi
else
  echo "sddm is already installed."
fi


# start services
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth.service
sudo systemctl enable sshd
sudo systemctl start bluetooth.service
sudo systemctl start sshd

# Set open in terminal in nemo
gsettings set org.cinnamon.desktop.default-applications.terminal exec kitty

# Copy config
copy_config() {
    echo "→ Copying subdirectories from $1 to $2..."
    for dir in "$1"/*/; do
        if [ -d "$dir" ]; then
            dest_dir="$2/$(basename "$dir")"
            if [ -d "$dest_dir" ]; then
                echo "! Destination directory $dest_dir exists. Removing it..."
                rm -rf "$dest_dir"
                echo "✓ Old directory removed."
            fi
            cp -r "$dir" "$2"
            echo "✓ Copied directory: $dest_dir"
        fi
    done

    if [ $? -eq 0 ]; then
        echo "✓ Directories copied successfully."
    else
        echo "✗ ERROR: Failed to copy directories!"
        return 1
    fi
}

copy_config ".config" "$HOME/.config"
cp -r bin "$HOME"
cp -r .icons "$HOME"
cp -r .themes "$HOME"
cp .gtkrc-2.0 "$HOME"
cp -r wallpaper "$HOME"
sudo cp -r sddm_theme/catppuccin-mocha /usr/share/sddm/themes/
sudo cp sddm_theme/sddm.conf /etc/
chsh -s $(which zsh)
cp .zshrc-default $HOME/.zshrc

echo 'Installation complete!'