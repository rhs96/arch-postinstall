#!/bin/bash

# Reutilizável: instala pacotes via pacman ou paru, conforme disponíveis
install_packages() {
  local pacman_pkgs=()
  local paru_pkgs=()

  for pkg in "$@"; do
    if is_installed "$pkg"; then
      log INFO "Pacote já instalado: $pkg"
      continue
    fi

    if pacman -Si "$pkg" &>/dev/null; then
      pacman_pkgs+=("$pkg")
    else
      paru_pkgs+=("$pkg")
    fi
  done

  if (( ${#pacman_pkgs[@]} > 0 )); then
    log INFO "Instalando via pacman: ${pacman_pkgs[*]}"
    sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
  fi

  if (( ${#paru_pkgs[@]} > 0 )); then
    ensure_paru
    log INFO "Instalando via paru (AUR): ${paru_pkgs[*]}"
    paru -S --needed --noconfirm "${paru_pkgs[@]}"
  fi
}

# Nova função que agrupa os pacotes principais usados no menu
install_main_packages() {
  section "Instalando pacotes principais"

  install_packages \
    base base-devel git curl sha256sum base64 \
    firefox zen-browser-bin alacritty wezterm yazi xorg-server xorg-xinit jq \
    lsd bat arandr fastfetch zoxide fzf \
    pipewire pipewire-pulse pipewire-alsa pipewire-jack \
    libnotify dmenu xclip xdotool \
    go rust python nodejs npm \
    libreoffice-fresh

  # Adiciona configurações interativas no .bashrc se necessário
  grep -qxF 'eval "$(zoxide init bash)"' "$HOME/.bashrc" || echo 'eval "$(zoxide init bash)"' >> "$HOME/.bashrc"
  grep -qxF '[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash' "$HOME/.bashrc" || echo '[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash' >> "$HOME/.bashrc"
  grep -qxF '[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash' "$HOME/.bashrc" || echo '[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash' >> "$HOME/.bashrc"
}

