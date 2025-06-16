install_lunarvim() {
  section "Instalando LunarVim"
  install_packages neovim

  command -v lvim &>/dev/null && { log INFO "LunarVim já está instalado"; return; }

  local url="https://api.github.com/repos/lunarvim/lunarvim/contents/utils/installer/install.sh?ref=master"
  local encoded=$(curl -fsSL "$url" | jq -r '.content' | tr -d '\n')
  [[ "$encoded" == "null" || -z "$encoded" ]] && { log ERROR "Erro ao obter script"; return 1; }

  local tmp_file="$(mktemp)"
  echo "$encoded" | base64 -d > "$tmp_file"
  local expected_hash=$(sha256sum "$tmp_file" | awk '{print $1}')

  local raw_url="https://raw.githubusercontent.com/lunarvim/lunarvim/master/utils/installer/install.sh"
  local tmp_installer="$(mktemp)"
  curl -fsSL "$raw_url" -o "$tmp_installer"

  local actual_hash=$(sha256sum "$tmp_installer" | awk '{print $1}')
  [[ "$actual_hash" != "$expected_hash" ]] && { log ERROR "Hash inválido"; return 1; }

  LV_BRANCH='release-1.3/neovim-0.9' bash "$tmp_installer"
}

