#!/usr/bin/env bash
# PocketArch — sincroniza el repo del contenedor desde la copia de Termux.
# Lo ejecuta `make install` dentro de arch-arm, con la copia de Termux
# montada en SRC. Uso: sync-repo.sh SRC DEST REMOTE
#
# Primera vez: clon sin enlaces duros (PRoot no los soporta) y origin
# apuntando a REMOTE. Después: fetch + fast-forward; git rechaza el merge
# si pisaría cambios locales o si las ramas divergen.
set -euo pipefail

die() {
	echo "ERROR: $*" >&2
	exit 1
}

[ $# -eq 3 ] || die "uso: $0 SRC DEST REMOTE"
src=$1 dest=$2 remote=$3

[ -d "$src/.git" ] || die "$src no es un repo git (¿falta el --bind?)"
command -v git >/dev/null || die "git no está instalado (make bootstrap)"

# La copia montada pertenece al usuario de Termux.
git() { command git -c safe.directory="$src" "$@"; }

if [ ! -e "$dest" ]; then
	echo "==> Clonando $src en $dest"
	git clone --no-hardlinks "$src" "$dest"
	git -C "$dest" remote set-url origin "$remote"
elif [ -d "$dest/.git" ]; then
	echo "==> Actualizando $dest desde $src"
	git -C "$dest" fetch --no-tags "$src" HEAD
	git -C "$dest" merge --ff-only FETCH_HEAD ||
		die "no se puede avanzar $dest en fast-forward (cambios locales o commits divergentes); resuélvelo dentro del contenedor"
else
	die "$dest existe y no es un repo git"
fi
