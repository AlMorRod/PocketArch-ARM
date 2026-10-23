# shellcheck shell=bash
# PocketArch — verificación final de pacman, compartida por bootstrap.sh e
# install.sh (se carga con `.`). Falla si la base de datos tiene errores o si
# algún paquete instalado tiene archivos faltantes.

pacman_check() {
	local out
	echo "==> Verificando pacman (-Dk, -Qk)"
	if ! pacman -Dk; then
		echo "ERROR: pacman -Dk encontró errores en la base de datos" >&2
		return 1
	fi
	out=$(pacman -Qk 2>&1 | grep -v ' 0 missing files' || true)
	if [ -n "$out" ]; then
		printf '%s\n' "$out" >&2
		echo "ERROR: hay paquetes con archivos faltantes (arriba)" >&2
		return 1
	fi
}
