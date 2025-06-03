#!/bin/bash

set -euo pipefail

# Função para exibir seções
section() {
  echo
  echo "===> $1"
  echo "----------------------------------------------"
}

# Função para verificar se estamos no chroot
is_chroot() {
  if [ -f /etc/arch-release ]; then
    echo "Modo: Chroot"
    return 0
  else
    echo "Modo: Usuário Logado"
    return 1
  fi
}

# Função para instalar pacotes
install_packages() {
  local packages=("$@")
  section "Instalando pacotes: ${packages[*]}"
  sudo pacman -S --needed --noconfirm "${packages[@]}"
}

# Função para configurar pacman.conf
configure_pacman() {
  section "Configurando pacman.conf"
  sudo sed -i '/\[options\]/a ParallelDownloads = 5' /etc/pacman.conf
}

# Função para configurar sudoers
configure_sudoers() {
  section "Configurando sudoers"
  echo 'Defaults        pwfeedback' | sudo tee /etc/sudoers.d/0pwfeedback
}

# Função para configurar arquivos de configuração padrão
configure_dotfiles() {
  section "Configurando arquivos de configuração padrão"
  mkdir -p ~/.config/{leftwm,alacritty,yazi,dmenu}
  # Adicione aqui os arquivos de configuração padrão para cada aplicativo
}

# Função para instalar ferramentas de desenvolvimento
install_dev_tools() {
  section "Instalando ferramentas de desenvolvimento"
  install_packages go rust nodejs python python-pip
  install_packages libreoffice-fresh
}

# Função para instalar LeftWM e tema Catppuccin Mocha
install_leftwm() {
  section "Instalando LeftWM e tema Catppuccin Mocha"
  install_packages leftwm
  paru -S --noconfirm leftwm-theme-git
  leftwm-theme install catppuccin-mocha
  leftwm-theme load catppuccin-mocha
}

# Função para configurar .xinitrc
configure_xinitrc() {
  section "Configurando .xinitrc"
  cat > ~/.xinitrc <<EOF
#!/bin/sh
exec leftwm
EOF
  chmod +x ~/.xinitrc
}

# Função para configurar .bashrc
configure_bashrc() {
  section "Configurando .bashrc"
  if ! grep -q "startx" ~/.bashrc; then
    echo 'alias startx="startx ~/.xinitrc"' >> ~/.bashrc
  fi
}

# Função para instalar Paru (AUR helper)
install_paru() {
  section "Instalando Paru (AUR helper)"
  git clone https://aur.archlinux.org/paru.git /tmp/paru
  cd /tmp/paru
  makepkg -si --noconfirm
  cd ~
}

# Função para instalar LunarVim
install_lunarvim() {
  section "Instalando LunarVim"
  LV_BRANCH='release-1.4/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/LunarVim/LunarVim/master/utils/installer/install.sh)
}

# Função para instalar driver xpadneo para controle Xbox
install_xpadneo() {
  section "Instalando driver xpadneo para controle Xbox"
  sudo pacman -S --needed --noconfirm dkms linux-headers
  git clone https://github.com/atar-axis/xpadneo.git /tmp/xpadneo
  cd /tmp/xpadneo
  sudo ./install.sh
  cd ~
}

# Função para instalar Firefox, Alacritty, Yazi, Dmenu
install_apps() {
  section "Instalando Firefox, Alacritty, Yazi, Dmenu"
  install_packages firefox alacritty yazi dmenu
}

# Função para instalar PipeWire e Bluetooth
install_pipewire_bluetooth() {
  section "Instalando PipeWire e Bluetooth"
  install_packages pipewire pipewire-alsa pipewire-pulse wireplumber bluez bluez-utils bluetuith
  sudo systemctl enable --now pipewire-pulse
  sudo systemctl enable --now wireplumber
  sudo systemctl enable --now bluetooth
}

# Função para instalar codecs de áudio e vídeo
install_codecs() {
  section "Instalando codecs de áudio e vídeo"
  install_packages gst-libav gst-plugins-good gst-plugins-bad gst-plugins-ugly ffmpeg
}

# Função para instalar drivers AMD
install_amd_drivers() {
  section "Instalando drivers para AMD RX 580"
  install_packages mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon
}

# Função para configurar arquivos de configuração padrão
configure_config_files() {
  section "Configurando arquivos de configuração padrão"
  # Adicione aqui os arquivos de configuração padrão para cada aplicativo
}

# Função para configurar sudoers
configure_sudoers() {
  section "Configurando sudoers"
  echo 'Defaults        pwfeedback' | sudo tee /etc/sudoers.d/0pwfeedback
}

# Função para configurar pacman.conf
configure_pacman() {
  section "Configurando pacman.conf"
  sudo sed -i '/\[options\]/a ParallelDownloads = 5' /etc/pacman.conf
}

# Função para exibir mensagem final
final_message() {
  section "Instalação concluída!"
  echo "Reinicie o sistema e digite 'startx' para iniciar o ambiente com LeftWM e tema Catppuccin Mocha."
}

# Execução do script
main() {
  if is_chroot; then
    section "Modo: Chroot"
    install_packages base-devel git
    install_paru
    install_apps
    install_pipewire_bluetooth
    install_codecs
    install_amd_drivers
    install_leftwm
    install_lunarvim
    install_xpadneo
    configure_pacman
    configure_sudoers
    configure_config_files
    configure_xinitrc
    configure_bashrc
    install_dev_tools
    final_message
  else
    section "Modo: Usuário comum logado"
    install_paru
    install_apps
    install_pipewire_bluetooth
    install_codecs
    install_amd_drivers
    install_leftwm
    install_lunarvim
    install_xpadneo
    configure_pacman
    configure_sudoers
    configure_config_files
    configure_xinitrc
    configure_bashrc
    install_dev_tools
    final_message
  fi
}

main

