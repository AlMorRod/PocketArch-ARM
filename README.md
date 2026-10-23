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

## ❯ Despliegue desde cero

El despliegue completo se ejecuta **desde Termux** con `make`, sobre una
copia del repo en `~/PocketArch-ARM`. Cada objetivo es idempotente.

### 1. Prerrequisitos en Termux

1. Instala [Termux desde F-Droid](https://f-droid.org/packages/com.termux/) (la
   versión de Play Store está desactualizada).
2. El repo es privado: se clona con `gh`, autenticado por HTTPS.

```sh
pkg update && pkg install gh git make proot-distro curl unzip
gh auth login
gh repo clone AlMorRod/PocketArch-ARM ~/PocketArch-ARM
```

### 2. Desplegar

```sh
cd ~/PocketArch-ARM && make
```

| Objetivo | Qué hace |
|----------|----------|
| `make termux` | paquetes de Termux (openssh, mosh), Nerd Font, `colors.properties`, `termux-setup-storage`, comando `pocketarch`, bloque gestionado en `~/.bashrc` (alias `arch` y selector) y `Host geo` en `~/.ssh/config` |
| `make container` | instala `arch-arm` desde el tarball oficial de Arch Linux ARM, comprueba `aarch64` y ejecuta la sonda de link2symlink |
| `make bootstrap` | dentro del contenedor: keyring de ALARM, sandbox de pacman desactivado y `pacman -Syu` con git |
| `make install` | clona o actualiza `~/.pocket-arch` dentro del contenedor desde `~/PocketArch-ARM` y ejecuta `install.sh` |
| `make` / `make all` | los cuatro, en ese orden |
| `make probe` | repite la sonda de link2symlink |

`make install` lleva al contenedor los **commits** de la copia de Termux (no
los cambios sin commitear) y avanza solo en fast-forward. El clon del
contenedor tiene `origin` en `git@github.com:AlMorRod/PocketArch-ARM.git`;
para hacer push desde dentro, autentica allí con `gh auth login` y elige
**SSH** cuando pregunte por las operaciones de Git.

`install.sh` es idempotente: bootstrap (`scripts/bootstrap.sh`), paquetes de
`packages.txt` (`--needed`), symlinks vía stow, zsh como shell de login,
Claude Code (instalador nativo) y sync de plugins de Neovim. También se
ejecuta a mano dentro del contenedor: `~/.pocket-arch/install.sh`.

Detalle de cada pieza de la capa Termux en [docs/TERMUX.md](docs/TERMUX.md).

### Estructura del repo (stow-friendly)

Cada carpeta de primer nivel — salvo `assets/`, `docs/`, `scripts/` y
`termux/`, que son material del repo — es un "paquete" de [GNU Stow](https://www.gnu.org/software/stow/)
que replica la ruta desde `$HOME`; se enlaza con `stow -d ~/.pocket-arch -t ~ <paquete>`
(`install.sh` solo enlaza las carpetas que contienen `.config` o `.claude`).
Paquetes: `zsh` · `shell` · `starship` · `fastfetch` · `nvim` · `tmux` · `yazi` · `lazygit` · `git` · `bat` · `claude`.

| Fuera de stow | Contenido |
|---------------|-----------|
| `Makefile` | despliegue desde Termux |
| `scripts/` | `bootstrap.sh` (pacman operativo bajo PRoot) y `sync-repo.sh` (repo de Termux → contenedor) |
| `termux/` | capa Termux: envoltorio `pocketarch`, selector (`bashrc.sh`) y `colors.properties` |

<img src="assets/divider.svg" alt=""/>

## ❯ Capa Termux (host)

El contenedor se gestiona con `pacman`; la app Termux, con `pkg`. Lo que
vive en Termux — Nerd Font, paleta del terminal, envoltorio `pocketarch`,
selector de arranque, alias `geo` — está en `termux/` y lo aplica
`make termux`. Referencia completa: **[docs/TERMUX.md](docs/TERMUX.md)**.

<img src="assets/divider.svg" alt=""/>

## ❯ Tips de uso

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
YAML y SQL (sqlfluff). Se instalan solos al abrir el primer archivo de cada
lenguaje. `<leader>gg` abre lazygit integrado; tema monokai-pro con la paleta
del proyecto.

### Mantenimiento

- **Toda config nueva entra al repo**: crea `.pocket-arch/<pkg>/.config/...`,
  enlaza con `stow <pkg>` y commitea. Nada de config "a mano" sin versionar.
- Instala paquetes con `pacman -S ...` y luego corre `update` (o
  `pacman -Qqe > ~/.pocket-arch/packages.txt`) para dejarlo registrado.
- Commits atómicos con mensaje claro: cada cambio de config reversible.
- Contenedor roto sin remedio: `proot-distro reset arch-arm` desde Termux y
  `make container bootstrap install` (~10 min).

<img src="assets/divider.svg" alt=""/>

## ❯ Gotchas del entorno

- **No hay systemd** — nada de `systemctl`; los servicios se lanzan a mano.
- **Enlaces duros bajo PRoot** — en algunos dispositivos la emulación de
  enlaces duros de proot (link2symlink) tumba la sesión con *signal 11* ante
  cualquier `ln`; con `proot-distro login --no-link2symlink` el `ln` devuelve
  EPERM y la sesión sigue. La decisión es por dispositivo: la toma la sonda
  de `make container` y la aplica `pocketarch`. Entra siempre con `arch` o
  `pocketarch`, no con `proot-distro login` a pelo. Por la misma razón el
  repo se clona con `git clone --no-hardlinks`.
- **gpg necesita `lock-never`** — gpg crea sus archivos de bloqueo con
  enlaces duros, y `pacman-key --init` cae con *signal 11*. `bootstrap.sh`
  escribe `lock-never` en `/etc/pacman.d/gnupg/gpg.conf` antes del `--init`
  y lo mantiene; el keyring está completo cuando existe `trustdb.gpg`.
- **Sandbox de pacman desactivado** — el sandbox de descarga falla bajo PRoot
  (`Landlock is not supported by the kernel`). Van activas en `[options]` las
  directivas `DisableSandboxFilesystem` y `DisableSandboxSyscalls`, que la
  plantilla de `pacman.conf` trae comentadas (`DisableSandbox` equivale a las
  dos). Comprobación: `pacman-conf | grep DisableSandbox`.
- **Keyring propio de Arch Linux ARM** — las firmas vienen de `archlinuxarm`,
  no del keyring de Arch estándar (`pacman-key --populate archlinuxarm`).
- **Mason en ARM funciona** — pyright, ruff, bashls, marksman, etc. tienen
  builds `aarch64`. Si un binario de Mason falla raro, la causa no es falta
  de soporte ARM sino **contaminación del `PATH` con el toolchain
  de Termux** (binarios bionic del host). Asegúrate de que `gcc`, `make` y
  `python` resuelvan a los del contenedor (`command -v gcc` → `/usr/bin/gcc`).
- **Batería/temperatura no existen en el contenedor** — los sensores viven en
  Termux (termux-api); fastfetch los omite a propósito.
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
