LOG_FILE="$HOME/install_arch.log"
VERBOSE=1
USER_HOME=$(eval echo "~$USER")

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

