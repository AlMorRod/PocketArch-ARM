#!/usr/bin/env bash
# PocketArch — prueba de scripts/fix-hardlinks.sh con un paquete sintético.
# No toca el sistema: pacman es un doble y todo vive en un directorio temporal.
#
#   tests/fix-hardlinks.sh
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fix="$repo/scripts/fix-hardlinks.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/cache" "$tmp/root"

fail() {
	echo "FALLO: $*" >&2
	exit 1
}

# Paquete demo-1.0-1 con un grupo de enlaces duros en usr/bin, otro miembro
# del grupo en otro directorio y un nombre con espacio.
python3 -I - "$tmp/cache/demo-1.0-1-aarch64.pkg.tar.gz" <<'EOF'
import io, sys, tarfile
with tarfile.open(sys.argv[1], "w:gz") as t:
    def reg(name, data):
        i = tarfile.TarInfo(name); i.size = len(data); i.mode = 0o755
        t.addfile(i, io.BytesIO(data))
    def hard(name, target):
        i = tarfile.TarInfo(name); i.type = tarfile.LNKTYPE; i.linkname = target
        t.addfile(i)
    for d in ("usr", "usr/bin", "usr/lib", "usr/lib/demo"):
        i = tarfile.TarInfo(d); i.type = tarfile.DIRTYPE; i.mode = 0o755; t.addfile(i)
    reg(".PKGINFO", b"pkgname = demo\n")
    reg("usr/bin/demo-real", b"#!/bin/sh\necho demo\n")
    hard("usr/bin/demo", "usr/bin/demo-real")
    hard("usr/bin/demo alias", "usr/bin/demo-real")
    hard("usr/lib/demo/demo-core", "usr/bin/demo-real")
    reg("usr/lib/demo/data", b"x\n")
EOF

# Doble de pacman: demo instalado con 3 archivos faltantes; base completo.
cat >"$tmp/bin/pacman" <<'EOF'
#!/usr/bin/env bash
case "$1" in
-Q) [ "$2" = demo ] && echo "demo 1.0-1" || exit 1 ;;
-Qk) echo "base: 1 total files, 0 missing files"
     echo "demo: 5 total files, 3 missing files"; exit 1 ;;
-Sw) echo "pacman -Sw $*" >>"$PACMAN_LOG" ;;
esac
EOF
chmod +x "$tmp/bin/pacman"
export PATH="$tmp/bin:$PATH" PACMAN_LOG="$tmp/pacman.log"

# Simula la extracción bajo proot: solo los registros regulares.
mkdir -p "$tmp/root/usr/bin" "$tmp/root/usr/lib/demo"
printf '#!/bin/sh\necho demo\n' >"$tmp/root/usr/bin/demo-real"
chmod 755 "$tmp/root/usr/bin/demo-real"
echo x >"$tmp/root/usr/lib/demo/data"

run() { bash "$fix" --root "$tmp/root" --cache "$tmp/cache" "$@"; }

# 1. --dry-run lista los tres y no crea nada.
out=$(run --dry-run demo)
[ "$(grep -c '^==> demo: ' <<<"$out")" -eq 3 ] || fail "dry-run no lista 3 enlaces: $out"
[ ! -e "$tmp/root/usr/bin/demo" ] || fail "dry-run creó archivos"

# 2. Modo hook (stdin): recrea los tres como symlinks relativos.
echo demo | run >/dev/null
for p in "usr/bin/demo" "usr/bin/demo alias" "usr/lib/demo/demo-core"; do
	[ -L "$tmp/root/$p" ] || fail "/$p no es symlink"
	[ "$("$tmp/root/$p")" = demo ] || fail "/$p no ejecuta el original"
done
[ "$(readlink "$tmp/root/usr/bin/demo")" = demo-real ] || fail "symlink no relativo"
[ "$(readlink "$tmp/root/usr/lib/demo/demo-core")" = ../../bin/demo-real ] ||
	fail "symlink entre directorios mal calculado"

# 3. Idempotente: segunda pasada sin cambios.
[ -z "$(echo demo | run)" ] || fail "la segunda pasada cambió algo"

# 4. Un archivo real no se pisa.
rm "$tmp/root/usr/bin/demo"
echo propio >"$tmp/root/usr/bin/demo"
run demo >/dev/null
[ ! -L "$tmp/root/usr/bin/demo" ] || fail "pisó un archivo existente"

# 5. --all toma de pacman -Qk solo los paquetes con faltantes.
rm "$tmp/root/usr/bin/demo alias"
out=$(run --all)
grep -q '^==> demo: /usr/bin/demo alias ' <<<"$out" || fail "--all no reparó demo: $out"
[ ! -e "$PACMAN_LOG" ] || fail "--all descargó algo que ya estaba en caché"

# 6. Sin el paquete en caché: --all lo pide con pacman -Sw y falla con aviso.
mv "$tmp/cache/demo-1.0-1-aarch64.pkg.tar.gz" "$tmp/"
if run --all 2>/dev/null; then fail "sin caché debería fallar"; fi
grep -qx 'pacman -Sw -Sw --noconfirm demo' "$PACMAN_LOG" || fail "--all no descargó demo"

# 7. El original del grupo también falta: aviso y error, no inventa nada.
mv "$tmp/demo-1.0-1-aarch64.pkg.tar.gz" "$tmp/cache/"
rm -f "$tmp/root/usr/bin/demo-real" "$tmp/root/usr/lib/demo/demo-core"
if run demo 2>/dev/null; then fail "sin original debería fallar"; fi
[ ! -e "$tmp/root/usr/lib/demo/demo-core" ] || fail "creó un enlace a un original ausente"

echo "OK: fix-hardlinks"
