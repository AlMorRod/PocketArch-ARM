# update: actualiza el sistema y regenera packages.txt en dotfiles
update() {
  pacman -Syu "$@" && pacman -Qqe > "$HOME/PocketArch-ARM/packages.txt" \
    && echo "packages.txt regenerado"
}

# extract <archivo> [destino]: extractor universal (bsdtar cubre tar.*, zip, 7z, rar)
extract() {
  [[ -f "$1" ]] || { echo "extract: '$1' no existe" >&2; return 1 }
  local dest="${2:-.}"
  mkdir -p "$dest"
  case "$1" in
    *.tar.*|*.tar|*.tgz|*.tbz2|*.txz|*.zip|*.7z|*.rar|*.iso)
      bsdtar -xf "$1" -C "$dest" ;;
    *.gz)  gunzip -k "$1" ;;
    *.bz2) bunzip2 -k "$1" ;;
    *.xz)  unxz -k "$1" ;;
    *.zst) unzstd "$1" ;;
    *) echo "extract: formato no reconocido: $1" >&2; return 1 ;;
  esac
}

# mkcd <dir>: crea el directorio y entra
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# weather [ciudad]: clima vía wttr.in (formato compacto por defecto)
weather() {
  curl -s "wttr.in/${1:-}?format=3"
}

# backup <archivo>: copia con timestamp junto al original
backup() {
  [[ -e "$1" ]] || { echo "backup: '$1' no existe" >&2; return 1 }
  cp -a "$1" "$1.$(date +%Y%m%d-%H%M%S).bak"
}
