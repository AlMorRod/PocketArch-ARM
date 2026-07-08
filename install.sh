#!/usr/bin/env bash
# PocketArch — instalación idempotente.
# Reconstruye el entorno en un contenedor arch-arm limpio: pacman-key,
# paquetes de packages.txt, symlinks vía stow, shell por defecto y
# bootstrap de plugins de Neovim. Re-ejecutable sin romper nada.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

echo "==> PocketArch install (${DOTFILES_DIR})"

# --- 1. Keyring de Arch Linux ARM (idempotente: solo si no existe) ---
if [ ! -d /etc/pacman.d/gnupg ]; then
	echo "==> Inicializando pacman-key (archlinuxarm)"
	pacman-key --init
	pacman-key --populate archlinuxarm
fi

# --- 2. pacman.conf: DisableSandbox activo, DownloadUser comentado ---
# (Landlock no existe bajo PRoot; sin DisableSandbox, pacman falla.)
if ! grep -q "^DisableSandbox" /etc/pacman.conf; then
	echo "==> Activando DisableSandbox en /etc/pacman.conf"
	sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf
fi
sed -i 's/^DownloadUser/#DownloadUser/' /etc/pacman.conf

# --- 3. Sync + upgrade del sistema ---
echo "==> pacman -Syu"
pacman -Syu --noconfirm

# --- 4. Paquetes de packages.txt (--needed: idempotente, no reinstala) ---
echo "==> Instalando paquetes de packages.txt"
# shellcheck disable=SC2046
pacman -S --needed --noconfirm $(cat "$DOTFILES_DIR/packages.txt")

# --- 5. Symlinks vía stow (idempotente: no pisa lo ya enlazado) ---
echo "==> Enlazando dotfiles con stow"
for pkg_dir in */; do
	pkg="${pkg_dir%/}"
	[ -d "$pkg/.config" ] || continue
	stow -v "$pkg"
done

# --- 6. Zsh como shell por defecto ---
zsh_path="$(command -v zsh)"
if [ "${SHELL:-}" != "$zsh_path" ]; then
	echo "==> Estableciendo zsh como shell por defecto"
	chsh -s "$zsh_path"
fi

# --- 7. Bootstrap de plugins de Neovim (LazyVim) ---
# Mason (LSP/formatters por lenguaje) se instala solo, la primera vez que
# abrís un archivo de cada lenguaje (ensure_installed en cada lang-*.lua).
echo "==> Sincronizando plugins de Neovim (puede tardar, necesita red)"
nvim --headless "+Lazy! sync" +qa || echo "    (falló o se pudo completar parcial; reintentá abriendo nvim manualmente)"

echo "==> Listo. Abrí una shell nueva (o 'exec zsh') para que tome efecto."
