install_leftwm() {
  section "Instalando LeftWM e dependências"
  install_packages leftwm leftwm-config-git leftwm-theme-git

  command -v leftwm-config &>/dev/null || { log ERROR "leftwm-config não instalado."; return 1; }

  leftwm-config --new

  local config_file="$USER_HOME/.config/leftwm/config.ron"
  [[ -f "$config_file" ]] && log INFO "Configuração gerada com sucesso" || log ERROR "Falha ao gerar configuração"

  if command -v leftwm-theme &>/dev/null; then
    leftwm-theme install "Catppuccin Mocha" && leftwm-theme apply "Catppuccin Mocha"
  fi

  echo "exec leftwm" >> "$USER_HOME/.xinitrc"
  sudo systemctl enable --now dbus.service
}

