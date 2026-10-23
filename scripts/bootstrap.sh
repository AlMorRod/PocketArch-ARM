#!/usr/bin/env bash
# PocketArch — bootstrap del contenedor arch-arm (idempotente).
# Deja pacman operativo bajo PRoot: keyring de ALARM, sandbox desactivado y
# sistema actualizado con git. Lo ejecutan `make bootstrap` (desde Termux)
# e install.sh (dentro del contenedor).
set -euo pipefail

die() {
	echo "ERROR: $*" >&2
	exit 1
}

[ "$(id -u)" -eq 0 ] || die "este script debe correr como root (lo normal dentro de arch-arm)"
command -v pacman >/dev/null || die "pacman no encontrado; ¿estás dentro del contenedor arch-arm?"

# --- 1. Keyring de Arch Linux ARM ---
# gpg crea archivos de bloqueo con enlaces duros, que bajo PRoot tumban la
# sesión (signal 11). lock-never va en gpg.conf antes de pacman-key --init y
# se queda: las actualizaciones de archlinuxarm-keyring vuelven a usar gpg.
gnupg=/etc/pacman.d/gnupg
install -d -m 755 "$gnupg"
if ! grep -qx 'lock-never' "$gnupg/gpg.conf" 2>/dev/null; then
	echo "==> Añadiendo lock-never a $gnupg/gpg.conf"
	echo 'lock-never' >>"$gnupg/gpg.conf"
fi
chmod 644 "$gnupg/gpg.conf"

# trustdb.gpg solo existe cuando pacman-key --init terminó.
if [ ! -f "$gnupg/trustdb.gpg" ]; then
	echo "==> Inicializando pacman-key (archlinuxarm)"
	pacman-key --init
	pacman-key --populate archlinuxarm
fi

# --- 2. pacman.conf: sandbox desactivado, DownloadUser comentado ---
# Bajo PRoot el sandbox de descarga de pacman falla (sin Landlock en el
# kernel). Se usa la forma separada que trae la plantilla de [options];
# DisableSandbox suelto equivale a las dos y sobra.
conf=/etc/pacman.conf
sed -i '/^[[:space:]]*DisableSandbox[[:space:]]*$/d' "$conf"
for opt in DisableSandboxFilesystem DisableSandboxSyscalls; do
	pacman-conf | grep -qx "$opt" && continue
	echo "==> Activando $opt en $conf"
	if grep -q "^#[[:space:]]*${opt}[[:space:]]*$" "$conf"; then
		sed -i "s/^#[[:space:]]*${opt}[[:space:]]*$/$opt/" "$conf"
	else
		sed -i "/^\[options\]/a $opt" "$conf"
	fi
done
sed -i 's/^DownloadUser/#DownloadUser/' "$conf"

# --- 3. Sync + upgrade del sistema (git hace falta para clonar el repo) ---
echo "==> pacman -Syu"
pacman -Syu --needed --noconfirm git
