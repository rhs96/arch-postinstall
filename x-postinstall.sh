#!/bin/bash
set -euo pipefail
shopt -s nullglob

LOG_FILE="$HOME/install_arch.log"
VERBOSE=1

USER_HOME=$(eval echo "~$USER")
CONFIG_SRC_DIR="./default_configs"

log() {
  local level="$1"
  shift
  local timestamp
  timestamp="$(date +'%F %T')"
  
  case "$level" in
    ERROR) echo "[$timestamp] ERROR: $*" | tee -a "$LOG_FILE" >&2 ;;
    WARN)  [[ $VERBOSE -ge 1 ]] && echo "[$timestamp] WARN: $*" | tee -a "$LOG_FILE" ;;
    INFO)  [[ $VERBOSE -ge 1 ]] && echo "[$timestamp] INFO: $*" | tee -a "$LOG_FILE" ;;
    DEBUG) [[ $VERBOSE -ge 2 ]] && echo "[$timestamp] DEBUG: $*" | tee -a "$LOG_FILE" ;;
    *)     echo "[$timestamp] LOG: $*" | tee -a "$LOG_FILE" ;;
  esac
}

section() {
  local msg="$*"
  echo -e "\n==== $msg ====\n"
}

is_installed() {
  local pkg="$1"
  pacman -Qq "$pkg" &>/dev/null || paru -Qq "$pkg" &>/dev/null
}

ensure_paru() {
  if ! command -v paru &>/dev/null; then
    section "Instalando paru (AUR helper)"
    install_packages base-devel git

    local paru_dir="/tmp/paru"

    if [[ ! -d "$paru_dir" ]]; then
      git clone https://aur.archlinux.org/paru.git "$paru_dir" | tee -a "$LOG_FILE"
    else
      log INFO "Diretório do paru já existe: $paru_dir"
    fi

    local prev_dir
    prev_dir="$(pwd)"
    cd "$paru_dir"
    makepkg -si --noconfirm | tee -a "$LOG_FILE"
    cd "$prev_dir"
  else
    section "Paru já está instalado"
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

  log INFO "Habilitando e iniciando o serviço Bluetooth"
  sudo systemctl enable bluetooth.service
  sudo systemctl start bluetooth.service
}


install_leftwm() {
  section "Instalando LeftWM e dependências"

  install_packages leftwm leftwm-config-git leftwm-theme-git

  # Verifica se as ferramentas foram instaladas
  if ! command -v leftwm &>/dev/null || ! command -v leftwm-config &>/dev/null; then
    log ERROR "LeftWM ou leftwm-config não foram instalados corretamente."
    return 1
  fi

  log INFO "Gerando configuração padrão do LeftWM"
  leftwm-config --new

  local config_file="$USER_HOME/.config/leftwm/config.ron"
  if [[ -f "$config_file" ]]; then
    log INFO "Configuração padrão gerada com sucesso: $config_file"
  else
    log ERROR "Falha ao gerar configuração padrão do LeftWM."
  fi

  # Instala e aplica tema
  if command -v leftwm-theme &>/dev/null; then
    if leftwm-theme install "Catppuccin Mocha" && leftwm-theme apply "Catppuccin Mocha"; then
      log INFO "Tema 'Catppuccin Mocha' aplicado com sucesso."
    else
      log WARN "Falha ao aplicar o tema 'Catppuccin Mocha'."
    fi
  else
    log WARN "leftwm-theme não encontrado. Tema não aplicado."
  fi

  # Configura .xinitrc
  local xinitrc="$USER_HOME/.xinitrc"
  if [[ ! -f "$xinitrc" ]]; then
    touch "$xinitrc"
    log INFO "Criado arquivo $xinitrc"
  fi

  if ! grep -Fxq "exec leftwm" "$xinitrc"; then
    echo "exec leftwm" >> "$xinitrc"
    log INFO "Adicionado 'exec leftwm' ao final de $xinitrc"
  else
    log INFO "'exec leftwm' já está presente em $xinitrc"
  fi

  # Habilita serviço DBus
  if sudo systemctl enable --now dbus.service; then
    log INFO "Serviço dbus habilitado e iniciado com sucesso."
  else
    log WARN "Falha ao habilitar ou iniciar o serviço dbus."
  fi

  # Verificação final
  if command -v leftwm &>/dev/null; then
    log INFO "LeftWM instalado e pronto para uso."
  else
    log ERROR "Instalação do LeftWM falhou após todas as etapas."
  fi
}

# install_lunarvim() {
#   section "Instalando LunarVim"
#   install_packages neovim
#   if ! command -v lvim &>/dev/null; then
#     LV_BRANCH='release-1.3/neovim-0.9' bash <(curl -s https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh)
#   else
#     log INFO "LunarVim já instalado"
#   fi
# }

install_lunarvim() {
  section "Instalando LunarVim"

  install_packages neovim

  if command -v lvim &>/dev/null; then
    log INFO "LunarVim já está instalado"
    return 0
  fi

  local repo_owner="lunarvim"
  local repo_name="lunarvim"
  local file_path="utils/installer/install.sh"
  local branch="master"

  # API para pegar o conteúdo do arquivo (base64)
  local api_url="https://api.github.com/repos/$repo_owner/$repo_name/contents/$file_path?ref=$branch"

  log INFO "Buscando hash SHA256 do script de instalação via API do GitHub..."

  # Buscar conteúdo base64 do arquivo via API e calcular hash SHA256
  local encoded_content
  encoded_content=$(curl -fsSL "$api_url" | jq -r '.content' | tr -d '\n')
  if [[ -z "$encoded_content" || "$encoded_content" == "null" ]]; then
    log ERROR "Falha ao obter conteúdo do script via API do GitHub."
    return 1
  fi

  # Decodificar e calcular hash localmente (em variável)
  local tmp_file
  tmp_file="$(mktemp)"
  echo "$encoded_content" | base64 -d > "$tmp_file"
  local expected_hash
  expected_hash=$(sha256sum "$tmp_file" | awk '{print $1}')

  log INFO "Hash esperado (calculado via API): $expected_hash"

  # Baixar o script raw e comparar hash
  local raw_url="https://raw.githubusercontent.com/$repo_owner/$repo_name/$branch/$file_path"
  local tmp_installer
  tmp_installer="$(mktemp)"

  if ! curl -fsSL "$raw_url" -o "$tmp_installer"; then
    log ERROR "Falha ao baixar o script raw."
    rm -f "$tmp_file" "$tmp_installer"
    return 1
  fi

  local actual_hash
  actual_hash=$(sha256sum "$tmp_installer" | awk '{print $1}')

  if [[ "$actual_hash" != "$expected_hash" ]]; then
    log ERROR "Hash do script baixado não confere com o hash esperado."
    log ERROR "Esperado: $expected_hash"
    log ERROR "Obtido:   $actual_hash"
    rm -f "$tmp_file" "$tmp_installer"
    return 1
  fi

  log INFO "Hash verificado. Instalando LunarVim..."

  LV_BRANCH='release-1.3/neovim-0.9' bash "$tmp_installer"

  rm -f "$tmp_file" "$tmp_installer"

  echo 'export PATH=$HOME/.local/bin:$PATH' >> ~/.bashrc
  source ~/.bashrc
}


configure_pacman() {
  section "Configurando pacman (parallel downloads)"
  local pacman_conf="/etc/pacman.conf"
  local backup="${pacman_conf}.bak"

  # Fazer backup somente se ainda não existir
  if [[ ! -f "$backup" ]]; then
    sudo cp "$pacman_conf" "$backup"
    log INFO "Backup de pacman.conf criado em $backup"
  fi

  # Verificar se já está configurado corretamente
  if sudo grep -q "^ParallelDownloads = 5" "$pacman_conf"; then
    log INFO "ParallelDownloads já está configurado para 5"
    return
  fi

  # Atualizar ou inserir configuração ParallelDownloads
  if sudo grep -q "^ParallelDownloads" "$pacman_conf"; then
    # Substituir linha existente
    sudo sed -i 's/^ParallelDownloads.*/ParallelDownloads = 5/' "$pacman_conf"
  else
    # Inserir após [options]
    sudo sed -i '/^\[options\]/a ParallelDownloads = 5' "$pacman_conf"
  fi

  log INFO "ParallelDownloads configurado para 5 no pacman.conf"
}

configure_sudoers() {
  section "Configurando sudoers para mostrar **** na senha"

  # Arquivo customizado para nossa configuração (melhor que editar /etc/sudoers diretamente)
  local sudoers_custom="/etc/sudoers.d/pwfeedback"

  # Verifica se o arquivo já existe e contém a configuração
  if sudo grep -q "^Defaults\s\+pwfeedback" "$sudoers_custom" 2>/dev/null; then
    log INFO "pwfeedback já está habilitado no sudoers.d/pwfeedback"
    return
  fi

  # Criar arquivo com a configuração pwfeedback
  echo "Defaults pwfeedback" | sudo tee "$sudoers_custom" >/dev/null
  sudo chmod 440 "$sudoers_custom"

  # Validar sintaxe do sudoers após alteração
  if sudo visudo -c -f "$sudoers_custom"; then
    log INFO "pwfeedback habilitado com sucesso via sudoers.d"
  else
    log ERROR "Erro na sintaxe do arquivo sudoers.d/pwfeedback. Removendo arquivo."
    sudo rm -f "$sudoers_custom"
  fi
}


copy_default_configs() {
  section "Copiando configs padrão para o usuário"

  # Verifica se diretório HOME existe
  if [[ ! -d "$USER_HOME" ]]; then
    log ERROR "Diretório home do usuário ($USER_HOME) não encontrado."
    return 1
  fi

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

      # Copia com rsync preservando permissões, evitando sobrescrever sem necessidade
      rsync -a --delete "$src_dir"/ "$dest_dir"/

      log INFO "Configurações copiadas para $dest_dir"
    else
      log WARN "Config padrão não encontrada: $src_dir"
    fi
  done
}

configure_xinitrc() {
  section "Configurando .xinitrc para iniciar LeftWM"

  local xinitrc="$USER_HOME/.xinitrc"
  local new_content="#!/bin/sh
exec leftwm
"

  # Faz backup só se o arquivo existir e for diferente do conteúdo que vamos colocar
  if [[ -f "$xinitrc" ]]; then
    if ! diff -q <(echo "$new_content") "$xinitrc" &>/dev/null; then
      cp "$xinitrc" "$xinitrc.bak"
      log INFO "Backup do .xinitrc criado em $xinitrc.bak"
    else
      log INFO ".xinitrc já está configurado corretamente. Nenhuma alteração feita."
      return
    fi
  fi

  # Escreve o novo conteúdo
  echo "$new_content" > "$xinitrc"
  chmod +x "$xinitrc"
  log INFO ".xinitrc configurado para iniciar LeftWM"
}

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
	grep -qxF 'eval "$(zoxide init bash)"' $HOME/.bashrc || echo 'eval "$(zoxide init bash)"' >> $HOME/.bashrc
	grep -qxF '[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash' ~/.bashrc || echo '[ -f /usr/share/fzf/key-bindings.bash ] && source /usr/share/fzf/key-bindings.bash' >> ~/.bashrc
	grep -qxF '[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash' ~/.bashrc || echo '[ -f /usr/share/fzf/completion.bash ] && source /usr/share/fzf/completion.bash' >> ~/.bashrc
	source $HOME/.bashrc
        install_packages \
          base base-devel git curl sha256sum base64 \
          firefox zen-browser-bin alacritty zellij yazi xorg-server xorg-xinit jq \
          lsd bat arandr fastfetch zoxide fzf \
          pipewire pipewire-pulse pipewire-alsa pipewire-jack \
          libnotify dmenu xclip xdotool \
          go rust python nodejs npm \
          libreoffice-fresh || { log ERROR "Falha na instalação de pacotes"; continue; }
        ;;
      2)
        echo "Iniciando instalação de codecs..."
        install_codecs || { log ERROR "Falha na instalação de codecs"; continue; }
        ;;
      3)
        echo "Iniciando instalação de drivers AMD..."
        install_amd_drivers || { log ERROR "Falha na instalação dos drivers AMD"; continue; }
        ;;
      4)
        echo "Iniciando instalação do Bluetooth..."
        install_bluetooth || { log ERROR "Falha na instalação do Bluetooth"; continue; }
        ;;
      5)
        echo "Iniciando instalação do LeftWM..."
        install_leftwm || { log ERROR "Falha na instalação do LeftWM"; continue; }
        ;;
      6)
        echo "Iniciando instalação do LunarVim..."
        install_lunarvim || { log ERROR "Falha na instalação do LunarVim"; continue; }
        ;;
      7)
        echo "Aplicando configurações..."
        configure_pacman || { log ERROR "Falha na configuração do pacman"; continue; }
        configure_sudoers || { log ERROR "Falha na configuração do sudoers"; continue; }
        copy_default_configs || { log ERROR "Falha ao copiar configs padrão"; continue; }
        configure_xinitrc || { log ERROR "Falha ao configurar .xinitrc"; continue; }
        ;;
      8)
        echo "Iniciando instalação completa..."
        install_packages \
          base base-devel git \
          firefox zen-browser-bin alacritty yazi xorg-server xorg-xinit \
          lsd bat arandr fastfetch \
          pipewire pipewire-pulse pipewire-alsa pipewire-jack \
          libnotify dmenu xclip xdotool \
          go rust python nodejs npm \
          libreoffice-fresh || { log ERROR "Falha na instalação de pacotes"; continue; }

        install_codecs || { log ERROR "Falha na instalação de codecs"; continue; }
        install_amd_drivers || { log ERROR "Falha na instalação dos drivers AMD"; continue; }
        install_bluetooth || { log ERROR "Falha na instalação do Bluetooth"; continue; }
        install_leftwm || { log ERROR "Falha na instalação do LeftWM"; continue; }
        install_lunarvim || { log ERROR "Falha na instalação do LunarVim"; continue; }

        configure_pacman || { log ERROR "Falha na configuração do pacman"; continue; }
        configure_sudoers || { log ERROR "Falha na configuração do sudoers"; continue; }
        copy_default_configs || { log ERROR "Falha ao copiar configs padrão"; continue; }
        configure_xinitrc || { log ERROR "Falha ao configurar .xinitrc"; continue; }

        log INFO "Script finalizado com sucesso!"
        ;;
      9)
        echo "Saindo..."
        break
        ;;
      *)
        echo "Opção inválida. Tente novamente."
        ;;
    esac

    echo -e "\nPressione Enter para continuar..."
    read -r
  done
}

main "$@"
