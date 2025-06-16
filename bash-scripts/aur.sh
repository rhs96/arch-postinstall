ensure_paru() {
  if ! command -v paru &>/dev/null; then
    section "Instalando paru (AUR helper)"
    install_packages base-devel git

    local paru_dir="/tmp/paru"
    [[ -d "$paru_dir" ]] || git clone https://aur.archlinux.org/paru.git "$paru_dir" | tee -a "$LOG_FILE"

    pushd "$paru_dir" >/dev/null
    makepkg -si --noconfirm | tee -a "$LOG_FILE"
    popd >/dev/null
  else
    section "Paru já está instalado"
  fi
}

