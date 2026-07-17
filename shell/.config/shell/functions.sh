# ~/.config/shell/functions.sh
# Funciones portables, compartidas entre bash y zsh (sintaxis POSIX).

# dotfiles-sync-docs — recopia los manuales del repo de dotfiles al vault de
# Obsidian (carpeta 01_Core_Geofront/Dotfiles). Úsalo tras actualizar el repo.
dotfiles-sync-docs() {
	src="$HOME/dotfiles"
	dst="/storage/emulated/0/Obsidian/01_Core_Geofront/Dotfiles"
	[ -f "$src/README.md" ] || { echo "✗ No encuentro $src/README.md" >&2; return 1; }
	mkdir -p "$dst/assets" || return 1
	cp "$src/README.md"       "$dst/PocketArch — Dotfiles (README).md" &&
	cp "$src/docs/TERMUX.md"  "$dst/PocketArch — Termux (setup).md"   &&
	cp "$src"/assets/*.svg    "$dst/assets/"                          &&
	echo "✅ Manuales de dotfiles sincronizados → $dst"
}
