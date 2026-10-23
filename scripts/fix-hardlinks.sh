#!/usr/bin/env bash
# PocketArch — recrea los enlaces duros que pacman no pudo extraer.
#
#   fix-hardlinks.sh [opciones] PAQUETE…   repara esos paquetes
#   fix-hardlinks.sh [opciones] --all      repara los que `pacman -Qk` da con
#                                          archivos faltantes (descarga con
#                                          pacman -Sw los que no estén en caché)
#   fix-hardlinks.sh [opciones]            nombres por stdin (hook de pacman)
#
#   --root DIR    raíz donde se comprueba y se repara (por defecto /)
#   --cache DIR   caché de paquetes (por defecto CacheDir de pacman-conf)
#   --dry-run     solo lista lo que haría
#
# Bajo proot con --no-link2symlink el kernel devuelve EPERM al crear un
# enlace duro: libarchive avisa ("Can't create"), la transacción termina con
# éxito y el archivo falta. `bsdtar -tvf` lista esos miembros como
# "link to ORIGINAL", donde ORIGINAL es el primer registro regular del grupo,
# que sí se extrajo. Cada miembro que falte se recrea como symlink relativo a
# ORIGINAL y no como copia: grupos como git-core costarían cientos de MB
# copiados, el programa ve el mismo argv[0] y `pacman -Qk` lo da por presente.
#
# Solo usa bash, coreutils y bsdtar (dependencia de pacman): el hook corre
# antes de que python esté instalado. En modo hook nunca descarga (pacman
# tiene la base de datos bloqueada): solo consulta con pacman -Q y lee la caché.
set -euo pipefail

root=/ dry=0 all=0 caches=()
pkgs=()
while [ $# -gt 0 ]; do
	case "$1" in
	--root) root=$2; shift ;;
	--cache) caches+=("$2"); shift ;;
	--dry-run) dry=1 ;;
	--all) all=1 ;;
	-h | --help) sed -n '2,25s/^# \{0,1\}//p' "$0"; exit ;;
	-*) echo "ERROR: opción desconocida: $1" >&2; exit 2 ;;
	*) pkgs+=("$1") ;;
	esac
	shift
done
root=${root%/}
[ ${#caches[@]} -gt 0 ] || mapfile -t caches < <(pacman-conf CacheDir)

if [ "$all" -eq 1 ]; then
	# pacman -Qk sale con error si falta algo; el resumen va a stdout.
	mapfile -t pkgs < <(pacman -Qk 2>/dev/null |
		awk '/ missing files$/ && !/ 0 missing files$/ { sub(/:.*/, ""); print }' || true)
elif [ ${#pkgs[@]} -eq 0 ] && [ ! -t 0 ]; then
	mapfile -t pkgs
fi

# Paquete cacheado que corresponde a la versión instalada de $1.
cached() {
	local ver f c
	ver=$(pacman -Q "$1" | cut -d' ' -f2) || return 1
	for c in "${caches[@]}"; do
		for f in "${c%/}/$1-$ver-"*.pkg.tar*; do
			case "$f" in *.sig | *'*'*) continue ;; esac
			echo "$f"
			return 0
		done
	done
	return 1
}

re='^h[^ ]+ +[0-9]+ +[^ ]+ +[^ ]+ +[0-9]+ +[^ ]+ +[^ ]+ +[^ ]+ (.+) link to (.+)$'
fixed=0 failed=0
for pkg in "${pkgs[@]}"; do
	[ -n "$pkg" ] || continue
	if ! file=$(cached "$pkg"); then
		if [ "$all" -eq 1 ] && [ "$dry" -eq 0 ]; then
			pacman -Sw --noconfirm "$pkg" >/dev/null || true
		fi
		file=$(cached "$pkg") || {
			echo "AVISO: $pkg: no está en caché la versión instalada; no se repara" >&2
			failed=$((failed + 1))
			continue
		}
	fi
	while IFS= read -r line; do
		[[ $line =~ $re ]] || continue
		path=${BASH_REMATCH[1]#./} target=${BASH_REMATCH[2]#./}
		dest="$root/$path" src="$root/$target"
		if [ -e "$dest" ] || [ -L "$dest" ]; then continue; fi
		if [ ! -e "$src" ]; then
			echo "AVISO: $pkg: /$path enlaza a /$target, que también falta" >&2
			failed=$((failed + 1))
			continue
		fi
		echo "==> $pkg: /$path -> /$target"
		fixed=$((fixed + 1))
		[ "$dry" -eq 1 ] && continue
		ln -sr "$src" "$dest"
	done < <(bsdtar -tvf "$file")
done

verb=recreados
[ "$dry" -eq 0 ] || verb="por recrear (--dry-run)"
[ "$fixed" -eq 0 ] || echo "==> fix-hardlinks: $fixed enlaces $verb"
[ "$failed" -eq 0 ]
