#!/bin/bash
set -euo pipefail
shopt -s nullglob

# Caminho da pasta onde estão os scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/scripts" && pwd)"

# Sourcing de todos os módulos
for file in "$SCRIPT_DIR"/*.sh; do
  source "$file"
done

# Função principal com menu interativo
main() {
  trap "echo -e '\nInterrupção detectada. Saindo...'; exit 1" SIGINT

  while true; do
    clear
    echo "========== MENU DE INSTALAÇÃO =========="
    echo "1) Instalação de Pacotes"
    echo "2) Instalação de Codecs"
    echo "3) Instalação de Drivers AMD"
    echo "4) Instalação do Bluetooth"
    echo "5) Instalação do LeftWM"
    echo "6) Instalação do LunarVim"
    echo "7) Configurações"
    echo "8) Instalação Completa"
    echo "9) Sair"
    echo "========================================"
    read -rp "Escolha uma opção [1-9]: " opt

    case $opt in
      1)
        echo "Iniciando instalação de pacotes..."
        install_packages \
          base base-devel git curl sha256sum base64 \
          firefox zen-browser-bin alacritty wezterm yazi xorg-server xorg-xinit jq \
          lsd bat arandr fastfetch zoxide fzf \
          pipewire pipewire-pulse pipewire-alsa pipewire-jack \
          libnotify dmenu xclip xdotool \
          go rust python nodejs npm \
          libreoffice-fresh
        ;;
      2) install_codecs ;;
      3) install_amd_drivers ;;
      4) install_bluetooth ;;
      5) install_leftwm ;;
      6) install_lunarvim ;;
      7)
        configure_pacman
        configure_sudoers
        copy_default_configs
        configure_xinitrc
        ;;
      8)
        install_packages \
          base base-devel git curl sha256sum base64 \
          firefox zen-browser-bin alacritty wezterm yazi xorg-server xorg-xinit jq \
          lsd bat arandr fastfetch zoxide fzf \
          pipewire pipewire-pulse pipewire-alsa pipewire-jack \
          libnotify dmenu xclip xdotool \
          go rust python nodejs npm \
          libreoffice-fresh

        install_codecs
        install_amd_drivers
        install_bluetooth
        install_leftwm
        install_lunarvim

        configure_pacman
        configure_sudoers
        copy_default_configs
        configure_xinitrc

        log INFO "Script finalizado com sucesso!"
        ;;
      9) echo "Saindo..."; break ;;
      *) echo "Opção inválida. Tente novamente." ;;
    esac

    echo -e "\nPressione Enter para continuar..."
    read -r
  done
}

main "$@"

