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

