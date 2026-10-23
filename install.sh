#!/usr/bin/env bash
# PocketArch — instalación idempotente.
# Reconstruye el entorno en un contenedor arch-arm limpio: bootstrap de
# pacman, paquetes de packages.txt, symlinks vía stow, shell por defecto,
# Claude Code, plugins, parsers y herramientas de Neovim, y verificación
# final de pacman. Re-ejecutable sin romper nada.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"
# shellcheck source=scripts/lib-pacman-check.sh
. "$DOTFILES_DIR/scripts/lib-pacman-check.sh"

# PATH sin Termux ni Android: los parsers de Treesitter se compilan con el
# gcc del contenedor, no con el clang de Termux.
export PATH="$HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/bin"
export CC=gcc

die() {
	echo "ERROR: $*" >&2
	exit 1
}

# --- 0. Precondiciones (fallar claro, no en silencio) ---
[ "$(id -u)" -eq 0 ] || die "este script debe correr como root (lo normal dentro de arch-arm)"
command -v pacman >/dev/null || die "pacman no encontrado; ¿estás dentro del contenedor arch-arm?"
[ -f "$DOTFILES_DIR/packages.txt" ] || die "falta $DOTFILES_DIR/packages.txt (¿clon incompleto?)"
[ -s "$DOTFILES_DIR/packages.txt" ] || die "$DOTFILES_DIR/packages.txt está vacío"
for f in bootstrap.sh nvim-bootstrap.lua; do
	[ -f "$DOTFILES_DIR/scripts/$f" ] || die "falta $DOTFILES_DIR/scripts/$f (¿clon incompleto?)"
done

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
# Se compara con /etc/passwd: $SHELL refleja la sesión actual, no la cuenta.
zsh_path="$(command -v zsh)"
login_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [ "$login_shell" != "$zsh_path" ]; then
	echo "==> Estableciendo zsh como shell por defecto"
	chsh -s "$zsh_path"
fi

# --- 7. Claude Code (instalador nativo, fuera de pacman) ---
# Queda en ~/.local/bin/claude y se actualiza solo; no figura en packages.txt.
if [ ! -x "$HOME/.local/bin/claude" ]; then
	echo "==> Instalando Claude Code (instalador nativo)"
	if ! curl -fsSL https://claude.ai/install.sh | bash; then
		echo "AVISO: la instalación de Claude Code falló (¿sin red?). Reintenta con:" >&2
		echo "       curl -fsSL https://claude.ai/install.sh | bash" >&2
	fi
fi

# --- 8. Neovim: plugins, parsers de Treesitter y paquetes de Mason ---
# `Lazy! sync` sale antes de que Treesitter y Mason terminen; el script Lua
# espera a ambos. Un parser que falte hace fallar la instalación; un paquete
# de Mason que falte solo avisa (LazyVim lo reintenta al abrir nvim).
if [ "$(command -v gcc)" != /usr/bin/gcc ] || ! gcc --version >/dev/null; then
	die "/usr/bin/gcc no funciona (¿enlaces duros sin reparar? pocketarch-fix-hardlinks --all)"
fi
echo "==> Neovim: plugins, Treesitter y Mason (puede tardar, necesita red)"
nvim --headless "+Lazy! sync" "+luafile $DOTFILES_DIR/scripts/nvim-bootstrap.lua" ||
	die "Neovim incompleto; reintenta: nvim --headless \"+Lazy! sync\" \"+luafile $DOTFILES_DIR/scripts/nvim-bootstrap.lua\""

# --- 9. Verificación ---
pacman_check || die "instalación incompleta"

echo "==> Listo. Abrí una shell nueva (o 'exec zsh') para que tome efecto."
