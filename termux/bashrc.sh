# PocketArch — alias y selector de arranque de Termux.
# Lo carga el bloque gestionado de ~/.bashrc (make termux).
#
# El selector solo aparece cuando existe ~/.config/pocketarch/ready, que
# escribe un `make install` completo. Sin la marca: un aviso de una línea con
# el paso que falta y shell de Termux. Con la marca: g geofront · a Arch (por
# defecto a los 5 s); la tecla t queda en Termux local sin figurar en el menú.
# Escotillas: POCKETARCH_NO_PROMPT=1 (sin menú, Termux local) y ~/.no-geo
# (sin menú, directo a Arch). Salir de Arch con error o por señal vuelve a
# la shell de Termux.

alias arch='pocketarch'

_PA_REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
_PA_READY="${XDG_CONFIG_HOME:-$HOME/.config}/pocketarch/ready"

_pa_geo() {
	mosh geo -- tmux new -As main || ssh -t geo 'tmux new -As main'
}

_pa_arch() {
	local pink=$'\e[38;2;249;38;114m' r=$'\e[0m' rc=0
	clear
	pocketarch || rc=$?
	if [ "$rc" -gt 128 ]; then
		printf '\n   %s  Arch terminó por señal %s (%d) · sigues en Termux%s\n\n' \
			"$pink" "$(kill -l "$((rc - 128))" 2>/dev/null || echo '?')" "$rc" "$r"
	elif [ "$rc" -ne 0 ]; then
		printf '\n   %s  Arch salió con código %d · sigues en Termux%s\n\n' "$pink" "$rc" "$r"
	fi
	return 0
}

_pa_select() {
	local pink=$'\e[38;2;249;38;114m' cyan=$'\e[38;2;102;217;239m'
	local purple=$'\e[38;2;174;129;255m' dim=$'\e[38;2;103;117;124m'
	local bold=$'\e[1m' r=$'\e[0m' key step

	if ! pocketarch --installed; then
		step="make container"
	elif [ ! -e "$_PA_READY" ]; then
		step="make install"
	fi
	if [ -n "${step:-}" ]; then
		printf '%s󰣇  Arch no está listo: falta cd %s && %s%s\n' "$dim" "${_PA_REPO/#$HOME/\~}" "$step" "$r"
		return
	fi

	if [ -e "$HOME/.no-geo" ]; then
		_pa_arch
		return
	fi

	while :; do
		printf '\n   %s%s󰣇  PocketArch%s\n\n' "$bold" "$pink" "$r"
		printf '   %s%sg  geofront%s  %smosh geo → tmux main%s\n' "$bold" "$purple" "$r" "$dim" "$r"
		printf '   %s%sa  Arch%s      %sarch-arm%s\n\n' "$bold" "$cyan" "$r" "$dim" "$r"
		printf '   %s󰔟  Arch en 5s · Enter = Arch%s\n\n' "$dim" "$r"
		printf '   %s❯%s ' "$pink" "$r"

		key=
		read -r -s -t 5 -n 1 key || true
		printf '\n'
		[ -n "$key" ] || key=a

		case "$key" in
		g | G)
			clear
			_pa_geo && return
			printf '\n   %s  geofront no responde (mosh y ssh fallaron)%s\n' "$pink" "$r"
			;;
		a | A)
			_pa_arch
			return
			;;
		t | T)
			return
			;;
		esac
	done
}

if [ -t 0 ] && [ -z "${POCKETARCH_NO_PROMPT:-}" ] && command -v pocketarch >/dev/null 2>&1; then
	_pa_select
fi
