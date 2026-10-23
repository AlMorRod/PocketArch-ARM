# PocketArch — despliegue completo desde Termux.
#
#   make            = make all
#   make termux     paquetes, fuente, paleta, almacenamiento, ~/.bashrc, ~/.ssh/config
#   make container  instala arch-arm (tarball ALARM), comprueba aarch64
#   make probe      diagnóstico: sonda de link2symlink (no cambia nada)
#   make bootstrap  repara pacman, keyring, sin kernel, pacman -Syu y verificación
#   make install    sincroniza el repo, corre install.sh y activa el selector
#   make shell      abre el contenedor (pocketarch)
#
# Se ejecuta en Termux desde la copia del repo (~/PocketArch-ARM). Cada
# objetivo es idempotente y guarda su salida en ~/.cache/pocketarch/OBJETIVO.log.
# Al contenedor se entra siempre con termux/pocketarch. La marca
# ~/.config/pocketarch/ready (selector con Arch) se borra al empezar
# bootstrap e install y solo la escribe un install completo.

PREFIX ?= /data/data/com.termux/files/usr
SHELL := $(firstword $(wildcard $(PREFIX)/bin/bash) /bin/bash)
.SHELLFLAGS := -euo pipefail -c
.ONESHELL:
.NOTPARALLEL:
.DEFAULT_GOAL := all

REPO := $(CURDIR)
PA := $(REPO)/termux/pocketarch
ALIAS := arch-arm
TARBALL := http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
FONT_URL := https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip
PREREQS := make git gh proot-distro curl unzip
PKGS := openssh mosh
SRC_MNT := /mnt/pocketarch-src
DEST := /root/.pocket-arch
REMOTE := git@github.com:AlMorRod/PocketArch-ARM.git
MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
LOGGED := termux container probe bootstrap install
LOGDIR = $${XDG_CACHE_HOME:-$$HOME/.cache}/pocketarch
READY = $${XDG_CONFIG_HOME:-$$HOME/.config}/pocketarch/ready

.PHONY: all check help shell $(LOGGED) $(addprefix _,$(LOGGED))

all: termux container bootstrap install

help:
	@sed -n '3,9s/^# \{0,1\}//p' "$(MAKEFILE)"

# Cada objetivo público corre su gemelo _OBJETIVO con la salida en
# LOGDIR/OBJETIVO.log; pipefail conserva su código de salida.
$(LOGGED): check
	@mkdir -p "$(LOGDIR)"
	$(MAKE) --no-print-directory -f "$(MAKEFILE)" _$@ 2>&1 | tee "$(LOGDIR)/$@.log"

shell: check
	@"$(PA)" --installed || { echo "ERROR: $(ALIAS) no existe (make container)" >&2; exit 1; }
	exec "$(PA)"

check:
	@[ -x "$(PREFIX)/bin/pkg" ] || { echo "ERROR: make se ejecuta en Termux, no dentro del contenedor" >&2; exit 1; }
	# Termux sin actualizar: libcurl más nuevo que openssl y git/gh/curl no
	# arrancan (símbolo SSL_* sin resolver).
	for c in git gh curl; do
		command -v "$$c" >/dev/null || continue
		if ! out=$$("$$c" --version 2>&1); then
			echo "ERROR: $$c no arranca: $$(printf '%s\n' "$$out" | head -n 1)" >&2
			echo "       Termux sin actualizar: ejecuta termux-change-repo y pkg upgrade (README, paso 0)" >&2
			exit 1
		fi
	done
	missing=
	for c in $(PREREQS); do command -v "$$c" >/dev/null || missing="$$missing $$c"; done
	[ -z "$$missing" ] || { echo "ERROR: faltan prerrequisitos:$$missing (pkg install$$missing)" >&2; exit 1; }

_termux:
	@missing=
	for p in $(PKGS); do dpkg -s "$$p" >/dev/null 2>&1 || missing="$$missing $$p"; done
	if [ -n "$$missing" ]; then echo "==> pkg install$$missing"; pkg install -y $$missing; fi

	changed=0
	mkdir -p "$$HOME/.termux"
	if [ ! -f "$$HOME/.termux/font.ttf" ]; then
		echo "==> Instalando Nerd Font (CaskaydiaCove Mono)"
		tmp=$$(mktemp -d)
		trap 'rm -rf "$$tmp"' EXIT
		curl -fL -o "$$tmp/font.zip" "$(FONT_URL)"
		unzip -q -o "$$tmp/font.zip" -d "$$tmp/font"
		ttf=$$(find "$$tmp/font" -iname '*NerdFontMono-Regular.ttf' | head -n 1)
		[ -n "$$ttf" ] || { echo "ERROR: no hay *NerdFontMono-Regular.ttf en el zip" >&2; exit 1; }
		cp "$$ttf" "$$HOME/.termux/font.ttf"
		changed=1
	fi
	if ! cmp -s "$(REPO)/termux/colors.properties" "$$HOME/.termux/colors.properties"; then
		echo "==> Copiando colors.properties"
		cp "$(REPO)/termux/colors.properties" "$$HOME/.termux/colors.properties"
		changed=1
	fi
	[ "$$changed" -eq 0 ] || termux-reload-settings

	[ -d "$$HOME/storage" ] || { echo "==> termux-setup-storage (acepta el permiso en Android)"; termux-setup-storage; }

	ln -sfn "$(PA)" "$(PREFIX)/bin/pocketarch"

	rc="$$HOME/.bashrc"
	touch "$$rc"
	block="# >>> PocketArch >>>
	# Bloque gestionado por make termux ($(REPO)). No editar a mano.
	[ -f \"$(REPO)/termux/bashrc.sh\" ] && . \"$(REPO)/termux/bashrc.sh\"
	# <<< PocketArch <<<"
	awk -v blk="$$block" '
		$$0 == "# >>> PocketArch >>>" { skip = 1; if (!done) { print blk; done = 1 }; next }
		$$0 == "# <<< PocketArch <<<" { skip = 0; next }
		!skip { print }
		END { if (!done) print blk }
	' "$$rc" >"$$rc.tmp"
	if cmp -s "$$rc.tmp" "$$rc"; then rm "$$rc.tmp"; else echo "==> Actualizando bloque PocketArch en ~/.bashrc"; mv "$$rc.tmp" "$$rc"; fi
	if awk '/^# >>> PocketArch >>>$$/ { s = 1 } !s && /_pa_has_arch|alias arch=/ { f = 1 } /^# <<< PocketArch <<<$$/ { s = 0 } END { exit !f }' "$$rc"; then
		echo "AVISO: ~/.bashrc tiene un selector o alias arch fuera del bloque gestionado; bórralo" >&2
	fi

	mkdir -p -m 700 "$$HOME/.ssh"
	cfg="$$HOME/.ssh/config"
	touch "$$cfg"
	chmod 600 "$$cfg"
	if ! grep -Eq '^[[:space:]]*Host[[:space:]]+(.*[[:space:]])?geo([[:space:]]|$$)' "$$cfg"; then
		echo "==> Añadiendo Host geo a ~/.ssh/config"
		[ ! -s "$$cfg" ] || echo >>"$$cfg"
		printf '%s\n' 'Host geo' '    HostName lotusproject.xyz' '    User tyr' \
			'    ConnectTimeout 5' '    ServerAliveInterval 30' >>"$$cfg"
	fi

_container:
	@if ! "$(PA)" --installed; then
		echo "==> Instalando $(ALIAS) desde el tarball de Arch Linux ARM"
		proot-distro install --override-alias "$(ALIAS)" "$(TARBALL)"
	fi
	arch=$$("$(PA)" -- uname -m | tr -d '\r' | tail -n 1)
	[ "$$arch" = aarch64 ] || { echo "ERROR: $(ALIAS) es $$arch, se esperaba aarch64" >&2; exit 1; }
	echo "==> $(ALIAS): aarch64"

_probe:
	@"$(PA)" --probe

_bootstrap:
	@"$(PA)" --installed || { echo "ERROR: $(ALIAS) no existe (make container)" >&2; exit 1; }
	rm -f "$(READY)"
	"$(PA)" --bind "$(REPO):$(SRC_MNT)" -- bash "$(SRC_MNT)/scripts/bootstrap.sh"

_install:
	@"$(PA)" --installed || { echo "ERROR: $(ALIAS) no existe (make container)" >&2; exit 1; }
	rm -f "$(READY)"
	"$(PA)" --bind "$(REPO):$(SRC_MNT)" -- \
		bash "$(SRC_MNT)/scripts/sync-repo.sh" "$(SRC_MNT)" "$(DEST)" "$(REMOTE)"
	"$(PA)" -- bash "$(DEST)/install.sh"
	"$(PA)" -- true || { echo "ERROR: $(ALIAS) no responde tras install.sh" >&2; exit 1; }
	mkdir -p "$$(dirname "$(READY)")"
	touch "$(READY)"
	echo "==> Arch listo: el selector de Termux lo ofrece desde la próxima sesión"
