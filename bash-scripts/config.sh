configure_pacman() {
  section "Configurando pacman (parallel downloads)"
  local conf="/etc/pacman.conf"
  local backup="${conf}.bak"
  [[ ! -f "$backup" ]] && sudo cp "$conf" "$backup"

  if ! sudo grep -q "^ParallelDownloads = 5" "$conf"; then
    sudo sed -i '/^\[options\]/a ParallelDownloads = 5' "$conf"
  fi
}

configure_sudoers() {
  section "Configurando sudoers (pwfeedback)"
  local file="/etc/sudoers.d/pwfeedback"
  echo "Defaults pwfeedback" | sudo tee "$file" >/dev/null
  sudo chmod 440 "$file"
  sudo visudo -c -f "$file" || { sudo rm "$file"; log ERROR "Erro na sintaxe do sudoers"; }
}

copy_default_configs() {
  section "Copiando configs padrão"
  local dirs=(leftwm alacritty yazi dmenu lvim)
  for cfg in "${dirs[@]}"; do
    rsync -a --delete "./default_configs/$cfg/" "$USER_HOME/.config/$cfg/"
  done
}

configure_xinitrc() {
  section "Configurando .xinitrc"
  local file="$USER_HOME/.xinitrc"
  echo -e "#!/bin/sh\nexec leftwm" > "$file"
  chmod +x "$file"
}

