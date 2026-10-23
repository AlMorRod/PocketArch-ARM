#!/usr/bin/env bash
# PocketArch — bootstrap del contenedor arch-arm (idempotente).
# Deja pacman operativo bajo PRoot: base de datos sana, keyring de ALARM,
# sandbox desactivado, hook de enlaces duros, sin kernel y sistema
# actualizado con git. Lo ejecutan `make bootstrap` (desde Termux) e
# install.sh (dentro del contenedor).
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib-pacman-check.sh
. "$SCRIPTS_DIR/lib-pacman-check.sh"

# Sin rutas de Termux ni Android: cc o gcc no deben resolver fuera de /usr/bin.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/bin

die() {
	echo "ERROR: $*" >&2
	exit 1
}

[ "$(id -u)" -eq 0 ] || die "este script debe correr como root (lo normal dentro de arch-arm)"
command -v pacman >/dev/null || die "pacman no encontrado; ¿estás dentro del contenedor arch-arm?"

# --- 1. Base de datos de pacman tras una transacción interrumpida ---
# Si proot cae a mitad de una transacción quedan db.lck huérfano y registros
# sin desc o sin files. El lock solo se borra si no hay ningún pacman vivo;
# los registros rotos se apartan y se reinstalan en el -Syu (paso 6).
dbpath=/var/lib/pacman
if [ -e "$dbpath/db.lck" ]; then
	pgrep -x pacman >/dev/null && die "pacman está en ejecución ($dbpath/db.lck); espera a que termine"
	echo "==> Borrando $dbpath/db.lck huérfano"
	rm -f "$dbpath/db.lck"
fi

broken=()
for entry in "$dbpath"/local/*/; do
	entry=${entry%/}
	[ -d "$entry" ] || continue
	[ -f "$entry/desc" ] && [ -f "$entry/files" ] && continue
	# Nombre del directorio: NOMBRE-PKGVER-PKGREL.
	name=$(basename "$entry")
	broken+=("${name%-*-*}")
	echo "==> Registro a medias: $name (se aparta a $dbpath/local.broken y se reinstala)"
	install -d "$dbpath/local.broken"
	rm -rf "$dbpath/local.broken/$name"
	mv "$entry" "$dbpath/local.broken/"
done

# --- 2. Keyring de Arch Linux ARM ---
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

# --- 3. pacman.conf: sandbox desactivado, DownloadUser comentado ---
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

# --- 4. Hook de enlaces duros ---
# Se entra con --no-link2symlink, así que pacman no puede crear los enlaces
# duros de los paquetes; el hook los recrea tras cada transacción.
hooks=/etc/pacman.d/hooks
install -Dm755 "$SCRIPTS_DIR/fix-hardlinks.sh" /usr/local/bin/pocketarch-fix-hardlinks
install -Dm644 "$SCRIPTS_DIR/pocketarch-hardlinks.hook" "$hooks/zz-pocketarch-hardlinks.hook"

# --- 5. Sin kernel ---
# Un contenedor proot nunca arranca un kernel, y los hooks de mkinitcpio
# fallan en proot (/sys sin permisos, signal 11) y matan pacman a mitad.
# diffutils solo llega como dependencia de mkinitcpio: se marca explícito
# para que -Rs no se lo lleve. Los hooks se enmascaran antes de quitar.
if pacman -Q diffutils >/dev/null 2>&1; then
	pacman -D --asexplicit diffutils >/dev/null
fi
install -d "$hooks"
for h in 60-mkinitcpio-remove.hook 90-mkinitcpio-install.hook; do
	ln -sfn /dev/null "$hooks/$h"
done
kernel=()
for p in linux-aarch64 linux-firmware mkinitcpio; do
	pacman -Q "$p" >/dev/null 2>&1 && kernel+=("$p")
done
if [ ${#kernel[@]} -gt 0 ]; then
	echo "==> Quitando ${kernel[*]} (innecesarios en proot)"
	pacman -Rs --noconfirm "${kernel[@]}" ||
		echo "AVISO: no se pudo quitar ${kernel[*]}; el bootstrap continúa" >&2
fi

# --- 6. Sync + upgrade del sistema (git hace falta para clonar el repo) ---
# Los registros rotos del paso 1 se reinstalan en la misma transacción, que
# resuelve sus dependencias (glibc requiere tzdata). Sus archivos siguen en
# disco: --overwrite evita el conflicto "exists in filesystem".
if [ ${#broken[@]} -gt 0 ]; then
	echo "==> pacman -Syu (reinstalando ${broken[*]})"
	pacman -Syu --needed --noconfirm --overwrite '*' git "${broken[@]}"
else
	echo "==> pacman -Syu"
	pacman -Syu --needed --noconfirm git
fi

# --- 7. Enlaces duros que faltaban antes de instalar el hook ---
pocketarch-fix-hardlinks --all || echo "AVISO: fix-hardlinks no reparó todo (ver la verificación)" >&2

# --- 8. Verificación ---
pacman_check || die "bootstrap incompleto"
echo "==> Bootstrap completo"
