<div align="center">

<img src="assets/banner.svg" alt="PocketArch — dotfiles" width="740"/>

[![Arch Linux ARM](https://img.shields.io/badge/Arch_Linux-ARM-f92672?style=flat-square&logo=archlinux&logoColor=f8f8f2&labelColor=232a2e)](https://archlinuxarm.org)
![aarch64](https://img.shields.io/badge/aarch64-nativo-66d9ef?style=flat-square&logo=arm&logoColor=f8f8f2&labelColor=232a2e)
[![Termux](https://img.shields.io/badge/Termux-host-a6e22e?style=flat-square&logoColor=f8f8f2&labelColor=232a2e)](https://termux.dev)
![Material Monokai](https://img.shields.io/badge/tema-Material_Monokai-ae81ff?style=flat-square&labelColor=232a2e)

Entorno de desarrollo Linux portátil, 100% CLI, sobre **Termux + Arch Linux ARM**
(PRoot, `aarch64` nativo, sin emulación). Minimalista, rápido, reproducible, y con
identidad visual **Material Monokai** en todas las herramientas.

Zsh + Starship · Neovim (LazyVim) · Tmux · Yazi · Lazygit · bat/eza/fzf/zoxide/rg/fd · Fastfetch

</div>

<img src="assets/divider.svg" alt=""/>

## ❯ Requisitos

- Android `aarch64` (en Termux, `uname -m` → `aarch64`).
- [Termux desde F-Droid](https://f-droid.org/packages/com.termux/); la
  versión de Play Store está desactualizada. Sus plugins (`Termux:API`,
  `Termux:Styling`) deben salir de la misma fuente o fallan por firma.
- Red y una cuenta de GitHub con acceso al repo (es privado).

<img src="assets/divider.svg" alt=""/>

## ❯ Despliegue desde cero

Todo se ejecuta **desde Termux** con `make`, sobre una copia del repo en
`~/PocketArch-ARM`. Cada objetivo es idempotente.

### 0. Termux al día

Un Termux recién instalado trae paquetes desfasados entre sí: libcurl más
nuevo que openssl, y `git`, `gh` o `curl` no arrancan
(`cannot locate symbol "SSL_set_quic_tls_early_data_enabled"`). Antes de
nada, elige mirror y actualiza:

```sh
termux-change-repo
pkg upgrade
```

`make` comprueba que `git`, `gh` y `curl` arrancan; si no, se detiene y
remite a este paso.

### 1. Prerrequisitos y clon

```sh
pkg install gh git make proot-distro curl unzip
gh auth login
gh repo clone AlMorRod/PocketArch-ARM ~/PocketArch-ARM
```

### 2. Desplegar

```sh
cd ~/PocketArch-ARM && make
```

| Objetivo | Qué hace |
|----------|----------|
| `make termux` | paquetes de Termux (openssh, mosh), Nerd Font, paleta, `termux-setup-storage`, comando `pocketarch`, bloque gestionado en `~/.bashrc` (alias `arch` y selector) y `Host geo` en `~/.ssh/config` |
| `make container` | instala `arch-arm` desde el tarball oficial de Arch Linux ARM y comprueba `aarch64` |
| `make bootstrap` | dentro del contenedor: recupera pacman interrumpido, keyring de ALARM, sandbox desactivado, hook de enlaces duros, quita el kernel, `pacman -Syu` con git y verificación |
| `make install` | sincroniza `~/.pocket-arch` dentro del contenedor desde `~/PocketArch-ARM`, ejecuta `install.sh` y activa el selector |
| `make` / `make all` | `termux`, `container`, `bootstrap`, `install`, en ese orden |
| `make shell` | abre el contenedor (`pocketarch`) |
| `make probe` | diagnóstico: ¿funciona la emulación de enlaces duros de proot? No cambia nada |

Cada objetivo guarda su salida en `~/.cache/pocketarch/<objetivo>.log`
(salvo `shell`).

`install.sh` hace: bootstrap (`scripts/bootstrap.sh`), paquetes de
`packages.txt` (`--needed`), symlinks vía stow, zsh como shell de login,
Claude Code (instalador nativo), plugins de Neovim, parsers de Treesitter y
herramientas de Mason (espera a que terminen), y la verificación final de
pacman. Un parser de Treesitter que falte hace fallar la instalación; una
herramienta de Mason que falte solo avisa y se reintenta al abrir nvim.
También se ejecuta a mano dentro del contenedor: `~/.pocket-arch/install.sh`.

`make install` lleva al contenedor los **commits** de la copia de Termux (no
los cambios sin commitear) y avanza solo en fast-forward; se detiene sin
tocar nada si el contenedor tiene commits propios o cambios que el merge
pisaría. El clon del contenedor tiene `origin` en
`git@github.com:AlMorRod/PocketArch-ARM.git`; para hacer push desde dentro,
autentica allí con `gh auth login` y elige **SSH**.

### 3. Primera sesión

Abre una sesión nueva de Termux: aparece el selector (`g` geofront ·
`a` Arch, Arch por defecto a los 5 s). El selector solo aparece cuando un
`make install` terminó entero; mientras tanto, una línea indica el paso que
falta y queda la shell de Termux.

Pasos manuales, una vez:
- Llaves SSH para `geo`: `ssh-keygen` y `ssh-copy-id geo` (mosh necesita
  `mosh-server` en el servidor).
- Dentro del contenedor, `/theme` en Claude Code → **Material Monokai** (ver
  [Claude Code](#claude-code)).

Lectura opcional: [docs/TERMUX.md](docs/TERMUX.md) explica cómo personalizar
la capa Termux (fuente, paleta, selector) y cómo hacer su backup.

### Estructura del repo (stow-friendly)

Cada carpeta de primer nivel — salvo `assets/`, `docs/`, `scripts/`,
`termux/` y `tests/`, que son material del repo — es un "paquete" de
[GNU Stow](https://www.gnu.org/software/stow/) que replica la ruta desde
`$HOME`; se enlaza con `stow -d ~/.pocket-arch -t ~ <paquete>` (`install.sh`
solo enlaza las carpetas que contienen `.config` o `.claude`).
Paquetes: `zsh` · `shell` · `starship` · `fastfetch` · `nvim` · `tmux` · `yazi` · `lazygit` · `git` · `bat` · `claude`.

| Fuera de stow | Contenido |
|---------------|-----------|
| `Makefile` | despliegue desde Termux |
| `scripts/` | `bootstrap.sh` (pacman operativo bajo PRoot), `fix-hardlinks.sh` y su hook de pacman, `lib-pacman-check.sh` (verificación final), `nvim-bootstrap.lua` (Treesitter y Mason en headless) y `sync-repo.sh` (repo de Termux → contenedor) |
| `termux/` | capa Termux: envoltorio `pocketarch`, selector (`bashrc.sh`) y `colors.properties` |
| `tests/` | pruebas sin contenedor (`tests/fix-hardlinks.sh`) |

<img src="assets/divider.svg" alt=""/>

## ❯ Uso diario

### Shell (zsh)

| Comando | Qué hace |
|---------|----------|
| `ls` / `ll` / `la` / `l` | eza con iconos, `-l --git`, ocultos, una columna |
| `cat` | bat (syntax highlight, tema Material Monokai) |
| `grep` | ripgrep |
| `z <parte>` / `zi` | salto zoxide a directorios frecuentes / interactivo |
| `update` | `pacman -Syu` **y regenera `packages.txt`** — úsalo en vez de pacman a pelo |
| `extract archivo [dest]` | extractor universal (tar.\*, zip, 7z, rar vía bsdtar) |
| `mkcd dir` | crea el directorio y entra |
| `weather [ciudad]` | clima compacto vía wttr.in |
| `backup archivo` | copia `archivo.AAAAMMDD-HHMMSS.bak` junto al original |
| `reels <link>…` | descarga y transcribe reels de Instagram ([media-transcribe](https://github.com/AlMorRod/media-transcribe)) |
| `yt <url> [--force]…` | descarga (mp4+mp3) y transcribe vídeos de YouTube |
| `dotfiles-sync-docs` | recopia los manuales del repo (`README`, `TERMUX`) al vault de Obsidian |

Historial: 50k entradas, deduplicado y compartido entre sesiones. La config
vive en archivos fuente (`aliases.zsh`, `functions.zsh`, `history.zsh`,
`exports.zsh`) bajo `~/.config/zsh/`, no en un `.zshrc` monolítico.

Los **alias y funciones portables** (compatibles con bash *y* zsh) viven en el
paquete `shell`: `~/.config/shell/aliases.sh` y `~/.config/shell/functions.sh`.
Los cargan tanto `~/.bashrc` como el `.zshrc` de zsh, así que funcionan en
cualquiera de los dos shells.

### Tmux

Prefix por defecto (`C-b`). Mouse activado, ventanas desde 1.

- `prefix + h/j/k/l` — moverse entre panes (estilo Vim)
- `prefix + H/J/K/L` — redimensionar panes (repetible)
- Barra inferior: sesión + ventanas + fecha/hora, paleta Material Monokai

### Yazi

- `g` `D` — ir a `~/.pocket-arch` · `g` `p` — ir a `~/project`
- `g` `l` — abrir **lazygit** en el directorio actual
- `Enter` sobre un archivo de texto lo abre en Neovim (`$EDITOR`)

### Neovim (LazyVim)

LSP/formatters vía Mason para Python (pyright+ruff), Bash, Markdown, JSON,
YAML y SQL (sqlfluff); `install.sh` los deja instalados junto con los
parsers de Treesitter. `<leader>gg` abre lazygit integrado; tema monokai-pro
con la paleta del proyecto.

<img src="assets/divider.svg" alt=""/>

## ❯ Mantenimiento

- **Toda config nueva entra al repo**: crea `.pocket-arch/<pkg>/.config/...`,
  enlaza con `stow <pkg>` y commitea. Nada de config "a mano" sin versionar.
- Instala paquetes con `pacman -S ...` y luego corre `update` (o
  `pacman -Qqe > ~/.pocket-arch/packages.txt`) para dejarlo registrado.
- Commits atómicos con mensaje claro: cada cambio de config reversible.
- Estado de pacman: `pacman -Qk 2>&1 | grep -v ' 0 missing files'` no debe
  imprimir nada. Si falta algún enlace duro: `pocketarch-fix-hardlinks --all`.
- Si algo falla en un `make`, el log completo está en
  `~/.cache/pocketarch/<objetivo>.log`.

Backups, desde Termux y nunca desde dentro del contenedor:

```sh
proot-distro backup --output ~/storage/downloads/arch-arm-$(date +%F).tar.gz arch-arm
proot-distro restore ~/storage/downloads/arch-arm-AAAA-MM-DD.tar.gz
```

El backup del contenedor no incluye la capa Termux.

Contenedor roto sin remedio (borra todo lo no versionado: antes, confirma
que los commits del contenedor están en GitHub o en `~/PocketArch-ARM`):

```sh
proot-distro reset arch-arm && make bootstrap install     # vuelve a recién instalado
proot-distro remove arch-arm && make container bootstrap install
```

<img src="assets/divider.svg" alt=""/>

## ❯ Gotchas del entorno

- **Enlaces duros** — la emulación de enlaces duros de proot (link2symlink)
  tumba la sesión con *signal 11*, aunque `make probe` la dé por buena. Por
  eso `pocketarch` entra siempre con `--no-link2symlink`: un `ln` devuelve
  EPERM y la sesión sigue. pacman no puede crear entonces los enlaces duros
  de los paquetes; libarchive avisa
  (`warning given when extracting /usr/bin/gcc (Can't create '/usr/bin/gcc')`),
  la transacción termina con éxito y el archivo falta. El hook
  `/etc/pacman.d/hooks/zz-pocketarch-hardlinks.hook` recrea cada enlace
  duro que falte como symlink relativo al original, tras cada instalación o
  actualización. Entra siempre con `arch`, `pocketarch` o `make shell`, no
  con `proot-distro login` a pelo. Los clones usan `git clone --no-hardlinks`.
- **Sin kernel** — un contenedor proot nunca arranca un kernel, y los hooks
  de mkinitcpio fallan bajo proot (`find: /sys/devices: Permission denied`,
  *signal 11*) y matan pacman a mitad de transacción. `bootstrap.sh`
  enmascara esos hooks y quita `linux-aarch64`, `linux-firmware` y
  `mkinitcpio` (`diffutils` queda como paquete explícito).
- **pacman interrumpido** — si proot cae a mitad de una transacción quedan
  `/var/lib/pacman/db.lck` y registros a medias, y cada pacman posterior
  falla con `unable to lock database`. `bootstrap.sh` borra el lock solo si
  no hay ningún pacman en ejecución, aparta los registros sin `desc` o
  `files` a `/var/lib/pacman/local.broken/` y los reinstala.
- **PATH** — proot-distro añade al PATH del contenedor las rutas de Termux
  y de Android detrás de `/usr/bin`, así que un `gcc` o `cc` que falte en
  el contenedor resuelve al de Termux. Los comandos de `pocketarch -- …`,
  `bootstrap.sh` e `install.sh` corren con PATH limpio
  (`/usr/local/sbin:/usr/local/bin:/usr/bin`) y `CC=gcc`; en una shell
  interactiva las rutas de Termux quedan al final. Comprobación:
  `command -v gcc` → `/usr/bin/gcc`.
- **gpg necesita `lock-never`** — gpg crea sus archivos de bloqueo con
  enlaces duros. `bootstrap.sh` escribe `lock-never` en
  `/etc/pacman.d/gnupg/gpg.conf` antes de `pacman-key --init` y lo
  mantiene; el keyring está completo cuando existe `trustdb.gpg`.
- **Sandbox de pacman desactivado** — el sandbox de descarga falla bajo PRoot
  (`Landlock is not supported by the kernel`). Van activas en `[options]` las
  directivas `DisableSandboxFilesystem` y `DisableSandboxSyscalls`, que la
  plantilla de `pacman.conf` trae comentadas (`DisableSandbox` equivale a las
  dos). Comprobación: `pacman-conf | grep DisableSandbox`.
- **Keyring propio de Arch Linux ARM** — las firmas vienen de `archlinuxarm`,
  no del keyring de Arch estándar (`pacman-key --populate archlinuxarm`).
- **Orden del selector** — `make termux` instala el selector, pero solo se
  activa con `~/.config/pocketarch/ready`, que escribe un `make install`
  completo tras comprobar que Arch responde. `make bootstrap` y
  `make install` borran la marca al empezar. Al salir de geofront con éxito
  se entra a Arch (solo con la marca). Una salida 0 de Arch cierra la
  sesión de Termux; cualquier otro código o una señal muestra el motivo y
  conserva la sesión. `exit` hereda el código del último comando, así que
  `exit 0` fuerza el cierre.
- **No hay systemd** — nada de `systemctl`; los servicios se lanzan a mano.
- **Mason en ARM funciona** — pyright, ruff, bashls, marksman, etc. tienen
  builds `aarch64`. Si un binario de Mason falla raro, revisa el PATH (arriba).
- **Batería/temperatura no existen en el contenedor** — los sensores viven en
  Termux (`Termux:API` + `termux-api`); fastfetch los omite a propósito.
- **Fastfetch reporta el disco del host Android** (`erofs [Read-only]`), no
  el del contenedor: artefacto de PRoot.
- **La Nerd Font es de Termux**, no del contenedor: un icono que no renderiza
  se arregla en la app, no aquí.
- **marksman (LSP Markdown)** necesita `DOTNET_GCHeapHardLimit`; ya viene
  configurado en `nvim/lua/plugins/lang-markdown.lua`.

<img src="assets/divider.svg" alt=""/>

## ❯ Paleta

<img src="assets/palette.svg" alt="Paleta Material Monokai: fondos, texto y seis acentos" width="740"/>

Material Monokai, mapeada a mano (no existe port oficial). Fuente única de
verdad: la tabla en `CLAUDE.md` del proyecto PocketArch. Fondo `#1e2327`,
texto `#f8f8f2`, acentos `#f92672` / `#fd971f` / `#e6db74` / `#a6e22e` /
`#66d9ef` / `#ae81ff`. Ninguna config de este repo introduce colores fuera
de esa tabla.

### Claude Code

`install.sh` lo instala con el instalador nativo en `~/.local/bin/claude`
(se actualiza solo; no figura en `packages.txt`). El primer `claude` imprime
una URL de autenticación (requiere Pro, Max, Team o API); `claude doctor`
verifica instalación, red y auth. Como root, `--dangerously-skip-permissions`
está bloqueado: los permisos amplios viven en `~/.claude/settings.json`
(paquete `claude`), con `deny` contra borrados catastróficos.

El paquete `claude` instala el tema en `~/.claude/themes/material-monokai.json`.
La selección del tema vive en `~/.claude.json` (no versionado): tras un
despliegue nuevo, dentro de Claude Code corre `/theme` y elige **Material
Monokai** (paso manual, una sola vez). Los fondos de diff y los colores de
subagentes se quedan con los del preset `dark` base: la paleta no tiene
variantes oscuras tintadas para esos roles.

La statusline (`~/.claude/statusline.sh`, activada en `settings.json`)
muestra en una línea:

| Segmento | Contenido |
|----------|-----------|
| Modelo | nombre del modelo de la sesión |
| `5h` / `7d` | uso de los límites de 5 horas y 7 días: barra, porcentaje y tiempo hasta el reinicio (`↻`) |
| `ctx` | tokens en contexto / tamaño de la ventana, y porcentaje usado |
| `$` | costo acumulado de la sesión en USD |

Barras y porcentajes en verde (< 50 %), amarillo (≥ 50 %) y rosa (≥ 80 %).
Los segmentos `5h`/`7d` requieren plan **Pro o Max**; sin ellos la línea
muestra modelo, contexto y costo. La statusline requiere `jq` (en `packages.txt`).
