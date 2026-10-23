# PocketArch — alias y selector de arranque de Termux.
# Lo carga el bloque gestionado de ~/.bashrc (make termux).
#
# Menú: g geofront · a Arch (por defecto a los 5 s). La tecla t queda en
# Termux local sin figurar en el menú. Sin contenedor: g geofront · t Termux
# (por defecto). Escotillas: POCKETARCH_NO_PROMPT=1 (sin menú, Termux local)
# y ~/.no-geo (sin menú, directo a Arch).

alias arch='pocketarch'

_pa_geo() {
	mosh geo -- tmux new -As main || ssh -t geo 'tmux new -As main'
}

_pa_select() {
	local pink=$'\e[38;2;249;38;114m' green=$'\e[38;2;166;226;46m'
	local cyan=$'\e[38;2;102;217;239m' purple=$'\e[38;2;174;129;255m'
	local dim=$'\e[38;2;103;117;124m' bold=$'\e[1m' r=$'\e[0m'
	local has_arch=0 def key

	pocketarch --installed && has_arch=1

	if [ -e "$HOME/.no-geo" ]; then
		if [ "$has_arch" -eq 1 ]; then
			clear
			pocketarch
		else
			printf '\n   %s󰣇  arch-arm no instalado · make container%s\n\n' "$dim" "$r"
		fi
		return
	fi

	if [ "$has_arch" -eq 1 ]; then def=a; else def=t; fi

	while :; do
		printf '\n   %s%s󰣇  PocketArch%s\n\n' "$bold" "$pink" "$r"
		printf '   %s%sg  geofront%s  %smosh geo → tmux main%s\n' "$bold" "$purple" "$r" "$dim" "$r"
		if [ "$has_arch" -eq 1 ]; then
			printf '   %s%sa  Arch%s      %sarch-arm%s\n\n' "$bold" "$cyan" "$r" "$dim" "$r"
			printf '   %s󰔟  Arch en 5s · Enter = Arch%s\n\n' "$dim" "$r"
		else
			printf '   %s%st  Termux%s    %slocal%s\n\n' "$bold" "$green" "$r" "$dim" "$r"
			printf '   %s󰔟  Termux en 5s · arch-arm no instalado (make container)%s\n\n' "$dim" "$r"
		fi
		printf '   %s❯%s ' "$pink" "$r"

		key=
		read -r -s -t 5 -n 1 key || true
		printf '\n'
		[ -n "$key" ] || key=$def

		case "$key" in
		g | G)
			clear
			_pa_geo && return
			printf '\n   %s  geofront no responde (mosh y ssh fallaron)%s\n' "$pink" "$r"
			;;
		a | A)
			[ "$has_arch" -eq 1 ] || continue
			clear
			pocketarch
			return
			;;
		t | T)
			printf '   %s  Termux local%s\n\n' "$green" "$r"
			return
			;;
		esac
	done
}

if [ -t 0 ] && [ -z "${POCKETARCH_NO_PROMPT:-}" ] && command -v pocketarch >/dev/null 2>&1; then
	_pa_select
fi
