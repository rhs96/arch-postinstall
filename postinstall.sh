#!/bin/bash
set -euo pipefail
shopt -s nullglob

LOG_FILE="$HOME/install_arch.log"
VERBOSE=1

USER_HOME=$(eval echo "~$USER")
CONFIG_SRC_DIR="./default_configs" # pasta com configs default do repo/script (ajuste se precisar)

log() {
  local level="$1"
  shift
  case "$level" in
    ERROR) echo "[$(date +'%F %T')] ERROR: $*" | tee -a "$LOG_FILE" >&2 ;;
    WARN)  [[ $VERBOSE -ge 1 ]] && echo "[$(date +'%F %T')] WARN: $*" | tee -a "$LOG_FILE" ;;
    INFO)  [[ $VERBOSE -ge 1 ]] && echo "[$(date +'%F %T')] INFO: $*" | tee -a "$LOG_FILE" ;;
    DEBUG) [[ $VERBOSE -ge 2 ]] && echo "[$(date +'%F %T')] DEBUG: $*" | tee -a "$LOG_FILE" ;;
    *) echo "[$(date +'%F %T')] LOG: $*" | tee -a "$LOG_FILE" ;;
  esac
}

section() {
  echo
  echo "==== $* ===="
  echo
}

is_installed() {
  local pkg="$1"
  pacman -Qs "^$pkg$" &>/dev/null || paru -Qs "^$pkg$" &>/dev/null
}

ensure_paru() {
  if ! command -v paru &>/dev/null; then
    section "Instalando paru (AUR helper)"
    install_packages base-devel git
    if [[ ! -d "/tmp/paru" ]]; then
      git clone https://aur.archlinux.org/paru.git /tmp/paru | tee -a "$LOG_FILE"
    fi
    pushd /tmp/paru
    makepkg -si --noconfirm | tee -a "$LOG_FILE"
    popd
  else
    section "Paru já instalado"
  fi
}

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

  if (( ${#pacman_pkgs[@]} )); then
    log INFO "Instalando via pacman: ${pacman_pkgs[*]}"
    sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}"
  fi

  if (( ${#paru_pkgs[@]} )); then
    ensure_paru
    log INFO "Instalando via paru (AUR): ${paru_pkgs[*]}"
    paru -S --needed --noconfirm "${paru_pkgs[@]}"
  fi
}

install_codecs() {
  section "Instalando codecs de áudio e vídeo"
  install_packages gst-libav gst-plugins-good gst-plugins-ugly ffmpeg
}

install_amd_drivers() {
  section "Instalando drivers AMD"
  install_packages xf86-video-amdgpu mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon
}

install_bluetooth() {
  section "Configurando Bluetooth"
  install_packages bluez bluez-utils bluez-libs
  # habilitar serviços bluetooth
  sudo systemctl enable bluetooth.service
  sudo systemctl start bluetooth.service
}

install_leftwm() {
    section "Instalando LeftWM e dependências"

    # Instalar LeftWM e dependências
    install_packages leftwm leftwm-config-git leftwm-theme-git

    # Verifica se a instalação foi bem-sucedida
    if ! command -v leftwm &>/dev/null || ! command -v leftwm-config &>/dev/null; then
        log ERROR "LeftWM ou leftwm-config não foi instalado corretamente."
        return 1
    fi

    # Geração da configuração padrão com leftwm-config
    log INFO "Gerando configuração padrão do LeftWM com leftwm-config"
    leftwm-config --new

    # Verifica se o arquivo principal de configuração foi criado
    if [[ -f "$USER_HOME/.config/leftwm/config.ron" ]]; then
        log INFO "Configuração padrão do LeftWM gerada com sucesso."
    else
        log ERROR "Falha ao gerar configuração padrão do LeftWM."
    fi

    # Instalar tema desejado
    if command -v leftwm-theme &>/dev/null; then
        leftwm-theme install "Catppuccin Mocha" && \
        leftwm-theme apply "Catppuccin Mocha" && \
        log INFO "Tema Catppuccin Mocha aplicado com sucesso."
    else
        log WARN "leftwm-theme não encontrado. Tema não aplicado."
    fi

    # Configurar .xinitrc para iniciar LeftWM
    local xinitrc="$USER_HOME/.xinitrc"
    if ! grep -q "exec leftwm" "$xinitrc"; then
        echo "exec leftwm" >> "$xinitrc"
        log INFO "Adicionado 'exec leftwm' ao final de $xinitrc"
    else
        log INFO "Linha 'exec leftwm' já presente em $xinitrc"
    fi

    # Habilitar serviços necessários
    sudo systemctl enable --now dbus.service
    log INFO "Serviço dbus habilitado e iniciado."

    # Verificar se o LeftWM foi instalado corretamente
    if command -v leftwm &>/dev/null; then
        log INFO "LeftWM instalado com sucesso."
    else
        log ERROR "Falha na instalação do LeftWM."
    fi
}

install_lunarvim() {
  section "Instalando LunarVim"
  install_packages neovim
  if ! command -v lvim &>/dev/null; then
    LV_BRANCH='release-1.3/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh)
  else
    log INFO "LunarVim já instalado"
  fi
}

configure_pacman() {
  section "Configurando pacman (parallel downloads)"
  local pacman_conf="/etc/pacman.conf"
  sudo cp "$pacman_conf" "${pacman_conf}.bak"  # backup

  # Ajustar ParallelDownloads para 5 (cria se não existir)
  if sudo grep -q "^ParallelDownloads" "$pacman_conf"; then
    sudo sed -i 's/^ParallelDownloads.*/ParallelDownloads = 5/' "$pacman_conf"
  else
    sudo sed -i '/\[options\]/a ParallelDownloads = 5' "$pacman_conf"
  fi
}

configure_sudoers() {
  section "Configurando sudoers para mostrar **** na senha"
  local sudoers_file="/etc/sudoers"
  sudo cp "$sudoers_file" "${sudoers_file}.bak" # backup

  # Procura a linha com pwfeedback (não é criada por padrão no Arch)
  if sudo grep -q "Defaults.*pwfeedback" "$sudoers_file"; then
    log INFO "pwfeedback já está habilitado no sudoers"
  else
    # Adiciona a opção para mostrar **** ao digitar senha
    echo "Defaults pwfeedback" | sudo tee -a "$sudoers_file"
  fi
}

copy_default_configs() {
  section "Copiando configs padrão para o usuário"

  # Exemplo: configs típicas no ./default_configs para cada app
  # Ajuste os caminhos conforme sua estrutura de configs default

  local configs=(
    "leftwm"
    "alacritty"
    "yazi"
    "dmenu"
    "lvim"
  )

  for cfg in "${configs[@]}"; do
    local src_dir="$CONFIG_SRC_DIR/$cfg"
    local dest_dir="$USER_HOME/.config/$cfg"
    if [[ -d "$src_dir" ]]; then
      mkdir -p "$dest_dir"
      cp -rT "$src_dir" "$dest_dir"
      log INFO "Configurações copiadas para $dest_dir"
    else
      log WARN "Config padrão não encontrada: $src_dir"
    fi
  done
}

configure_xinitrc() {
  section "Configurando .xinitrc para iniciar LeftWM"

  local xinitrc="$USER_HOME/.xinitrc"
  # Backup
  if [[ -f "$xinitrc" ]]; then
    cp "$xinitrc" "$xinitrc.bak"
  fi

  cat > "$xinitrc" << EOF
#!/bin/sh
exec leftwm
EOF

  chmod +x "$xinitrc"
  log INFO ".xinitrc configurado para iniciar LeftWM"
}

main() {
  section "Início do script"

  # Instalar pacotes essenciais
  install_packages \
    base base-devel git \
    firefox alacritty yazi xorg-server xorg-xinit \
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
}

main "$@"