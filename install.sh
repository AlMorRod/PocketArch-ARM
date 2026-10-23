#!/usr/bin/env bash
# PocketArch — instalación idempotente.
# Reconstruye el entorno en un contenedor arch-arm limpio: pacman-key,
# paquetes de packages.txt, symlinks vía stow, shell por defecto y
# bootstrap de plugins de Neovim. Re-ejecutable sin romper nada.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

# --- 0. Precondiciones (fallar claro, no en silencio) ---
[ "$(id -u)" -eq 0 ] || die "este script debe correr como root (lo normal dentro de arch-arm)"
command -v pacman >/dev/null || die "pacman no encontrado; ¿estás dentro del contenedor arch-arm?"
[ -f "$DOTFILES_DIR/packages.txt" ] || die "falta $DOTFILES_DIR/packages.txt (¿clon incompleto?)"
[ -s "$DOTFILES_DIR/packages.txt" ] || die "$DOTFILES_DIR/packages.txt está vacío"
[ -f "$DOTFILES_DIR/scripts/bootstrap.sh" ] || die "falta $DOTFILES_DIR/scripts/bootstrap.sh (¿clon incompleto?)"

echo "==> PocketArch install (${DOTFILES_DIR})"

# --- 1-3. Bootstrap: keyring, pacman.conf y pacman -Syu ---
bash "$DOTFILES_DIR/scripts/bootstrap.sh"

# --- 4. Paquetes de packages.txt (--needed: idempotente, no reinstala) ---
echo "==> Instalando paquetes de packages.txt"
# shellcheck disable=SC2046
pacman -S --needed --noconfirm $(cat "$DOTFILES_DIR/packages.txt")

# --- 5. Symlinks vía stow (idempotente: no pisa lo ya enlazado) ---
command -v stow >/dev/null || die "stow no está instalado y no llegó vía packages.txt"
echo "==> Enlazando dotfiles con stow"
for pkg_dir in */; do
	pkg="${pkg_dir%/}"
	[ -d "$pkg/.config" ] || [ -d "$pkg/.claude" ] || continue
	stow -v "$pkg" || die "stow falló en '$pkg' (¿archivo real en ~/.config chocando con el symlink? muévelo y reintenta)"
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
if ! nvim --headless "+Lazy! sync" +qa; then
	echo "AVISO: 'Lazy! sync' falló (¿sin red?). El entorno queda usable;" >&2
	echo "       abre nvim manualmente y corre :Lazy sync para completar." >&2
fi

echo "==> Listo. Abrí una shell nueva (o 'exec zsh') para que tome efecto."
