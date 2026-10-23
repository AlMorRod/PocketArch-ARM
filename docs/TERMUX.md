<div align="center">

<img src="../assets/termux-banner.svg" alt="TERMUX.md — PocketArch (capa host)" width="740"/>

</div>

Todo lo que vive **fuera** del contenedor `arch-arm`, en la app Termux, y cómo se despliega el conjunto desde ahí.

La capa Termux está versionada en `termux/` y la aplica `make termux`. Lo que no es versionable (permisos de Android, llaves SSH, la sesión de `gh`) se hace a mano y está indicado en cada sección.

---

## ❯ Las dos capas

| Capa | Gestor | Qué controla |
|------|--------|--------------|
| **Termux** (esta) | `pkg` + `make` | Fuente, colores del terminal, proot-distro, entrada al contenedor, selector, backups |
| **Arch PRoot** (`arch-arm`) | `pacman` | El entorno de desarrollo: zsh, nvim, tmux, yazi, etc. |

Regla mental: **si se ve o se arranca, es Termux. Si se usa, es Arch.**
Los colores y la fuente los renderiza Termux, aunque el programa corra dentro de Arch. Por eso `eza`, `bat` y `fastfetch` obedecen a esta capa, no a la otra.

<img src="../assets/divider.svg" alt=""/>

# ❯ Parte 1 — Despliegue con `make`

## 1.1 Prerrequisitos

Termux y sus plugins salen de la misma fuente (F-Droid). El repo es privado: se clona con `gh` (HTTPS autenticado).

```bash
pkg update && pkg install gh git make proot-distro curl unzip
gh auth login
gh repo clone AlMorRod/PocketArch-ARM ~/PocketArch-ARM
cd ~/PocketArch-ARM && make
```

`make` comprueba esos seis comandos antes de empezar y se niega a correr dentro del contenedor.

## 1.2 Objetivos

| Objetivo | Qué hace |
|----------|----------|
| `make termux` | Paquetes (`openssh`, `mosh`), fuente (1.3), paleta (1.4), `termux-setup-storage`, comando `pocketarch` (1.5), bloque en `~/.bashrc` (1.6) y `Host geo` (1.7) |
| `make container` | Instala `arch-arm` desde el tarball de Arch Linux ARM (Parte 2), comprueba `aarch64` y ejecuta la sonda (1.5) si no hay resultado |
| `make probe` | Repite la sonda |
| `make bootstrap` | Ejecuta `scripts/bootstrap.sh` dentro del contenedor (2.4) |
| `make install` | Sincroniza `~/.pocket-arch` dentro del contenedor desde `~/PocketArch-ARM` y ejecuta `install.sh` |
| `make` / `make all` | `termux`, `container`, `bootstrap`, `install`, en ese orden |

Todos son idempotentes: lo que ya está hecho se salta.

`make install` usa `scripts/sync-repo.sh`, con la copia de Termux montada en el contenedor (`--bind`):

- **Primera vez:** `git clone --no-hardlinks` en `/root/.pocket-arch` y `origin` apuntando a `git@github.com:AlMorRod/PocketArch-ARM.git`.
- **Después:** `fetch` + `merge --ff-only`. Si el contenedor tiene commits propios o cambios locales que el merge pisaría, se detiene con un error y no toca nada.
- Viajan los **commits** de la copia de Termux, no los cambios sin commitear.

---

## 1.3 Fuente (Nerd Font)

Sin Nerd Font, los iconos de eza, fastfetch, starship y yazi salen como cuadros vacíos. `make termux` descarga `CascadiaCode.zip` de las releases de Nerd Fonts y copia `*NerdFontMono-Regular.ttf` a `~/.termux/font.ttf`, solo si ese archivo no existe.

Verificar:

```bash
ls -lh ~/.termux/font.ttf
echo "󰣇   "        # si ves cuadros vacíos, la fuente no cargó
```

Notas:
- El zip se llama `CascadiaCode.zip` (con *c*, la fuente original de Microsoft), pero la fuente parcheada dentro se llama **Caskaydia Cove** (con *k* — Nerd Fonts renombra por licencia).
- El archivo **debe** llamarse `font.ttf`. Termux no lee ningún otro nombre.
- La variante *Mono* alinea mejor los iconos.
- Para cambiar de fuente: borra `~/.termux/font.ttf` y repite `make termux`, o copia otro `.ttf` con ese nombre y corre `termux-reload-settings`.

---

## 1.4 Paleta de colores (Material Monokai)

Los 16 colores ANSI los define **Termux**, no el contenedor. `termux/colors.properties` es lo que alinea `eza`, `bat`, `fastfetch` y todo lo que use ANSI con la identidad visual del proyecto. `make termux` lo copia a `~/.termux/colors.properties` cuando difiere y aplica con `termux-reload-settings`.

Notas:
- Mapeo derivado a mano de Material Monokai; **no es un port oficial**.
- `color11` va a naranja (`#fd971f`). Si en `ls` la columna de usuario resulta chillona, cámbialo a `#e6db74` en `termux/colors.properties`.
- *Termux:Styling* escribe en este mismo archivo y trae Monokai clásico (`#272822`), no el material; `make termux` lo vuelve a dejar como en el repo.

---

## 1.5 `pocketarch`: entrada única al contenedor

`termux/pocketarch` (enlazado en `$PREFIX/bin/pocketarch`) es el único punto de entrada a `proot-distro login`. Lo usan el Makefile, el alias `arch` y el selector.

```bash
pocketarch                       # sesión interactiva en arch-arm
pocketarch -- uname -m           # un comando
pocketarch --bind A:B -- cmd     # opciones de proot-distro login antes de --
pocketarch --probe               # repite la sonda (= make probe)
pocketarch --installed           # código de salida 0 si arch-arm existe
```

**link2symlink.** proot emula los enlaces duros con symlinks (link2symlink, activa por defecto). En algunos dispositivos esa emulación tumba la sesión con *signal 11* ante cualquier `ln`. Con `--no-link2symlink`, el kernel devuelve EPERM y la sesión sigue. La decisión es por dispositivo:

- **La sonda** ejecuta un `ln` en un directorio temporal del contenedor sin `--no-link2symlink`, y después borra el directorio desde una segunda sesión con `--no-link2symlink` (así se limpia aunque la primera caiga). Guarda el resultado en `~/.config/pocketarch/link2symlink`: `on` si el `ln` funcionó, `off` si no.
- **`pocketarch`** añade `--no-link2symlink` salvo que ese archivo diga `on`. Sin resultado de sonda, también lo añade: un EPERM es recuperable; una sesión caída, no.

Entra siempre con `arch` o `pocketarch`. Un `proot-distro login arch-arm` a pelo se salta la decisión de la sonda.

---

## 1.6 Alias y selector de arranque

`make termux` mantiene en `~/.bashrc` un bloque entre `# >>> PocketArch >>>` y `# <<< PocketArch <<<` que carga `termux/bashrc.sh`. El bloque se reescribe en cada `make termux`; el resto de `~/.bashrc` no se toca. Si encuentra un selector o un `alias arch=` fuera del bloque, avisa para que lo borres.

`termux/bashrc.sh` define el alias `arch` (= `pocketarch`) y, en un terminal interactivo, muestra el selector:

```
   󰣇  PocketArch

   g  geofront  mosh geo → tmux main
   a  Arch      arch-arm

   󰔟  Arch en 5s · Enter = Arch
```

| Tecla | Destino |
|-------|---------|
| `a`, Enter o 5 s sin tecla | Arch (`pocketarch`) |
| `g` | geofront: `mosh geo -- tmux new -As main`, y si falla `ssh -t geo 'tmux new -As main'` |
| `t` | Termux local (no figura en el menú) |

- Si mosh y ssh fallan, el selector muestra un aviso y vuelve al menú.
- Al cerrar la sesión de Arch o de geofront, quedas en el shell de Termux.
- **Sin `arch-arm` instalado:** el menú ofrece `g` geofront y `t` Termux, con Termux por defecto.

Escotillas:
- `POCKETARCH_NO_PROMPT=1` → sin menú, Termux local.
- `~/.no-geo` → sin menú, directo a Arch (`touch ~/.no-geo` para activarla, `rm ~/.no-geo` para quitarla).

Probar sin cerrar Termux: `bash -i`.

---

## 1.7 Alias SSH `geo`

`make termux` añade a `~/.ssh/config`, solo si no existe ya un `Host geo`:

```
Host geo
    HostName lotusproject.xyz
    User tyr
    ConnectTimeout 5
    ServerAliveInterval 30
```

Las llaves no se gestionan: generarlas y autorizarlas en el servidor es un paso manual (`ssh-keygen`, `ssh-copy-id geo`). mosh necesita `mosh-server` en el servidor.

<img src="../assets/divider.svg" alt=""/>

# ❯ Parte 2 — Imágenes

## 2.1 Cómo funcionan las imágenes en proot-distro

proot-distro instala de dos formas:

1. **Por nombre** → `proot-distro install ubuntu:24.04`
   Resuelve contra el registro **OCI/Docker**. Depende de que la imagen publique build para tu arquitectura.
2. **Por URL de tarball** → `proot-distro install <url.tar.gz>`
   Cualquier rootfs comprimido. Es la vía que usa PocketArch, con la imagen oficial de Arch Linux ARM.

> ⚠ **No existe un comando que liste las distros instalables.** `proot-distro list` solo muestra las que ya tienes.

Y el detalle que muerde en ARM:

```
proot-distro install archlinux
[!] No image found for architecture 'arm64'. Available Linux platforms: amd64
```

Arch mainline **solo existe para x86_64**. Correrlo en el teléfono exige `qemu-user-x86-64` (emulación → lento y come RAM). Por eso PocketArch usa **Arch Linux ARM (ALARM)**, `aarch64` nativo, desde su tarball oficial.

---

## 2.2 Instalar (Arch Linux ARM)

`make container` ejecuta, si `arch-arm` no existe:

```bash
proot-distro install --override-alias arch-arm \
  http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
```

- `--override-alias arch-arm` le da nombre limpio (si no, lo nombra por la URL).
- El aviso de que la integridad no se puede verificar es **esperado** con imágenes externas.
- La URL es `http` a propósito: el certificado TLS del mirror solo cubre `archlinuxarm.org`, no el subdominio `os.`, y con `https` la descarga falla por hostname mismatch.

Después comprueba que `uname -m` sea `aarch64` y ejecuta la sonda de link2symlink (1.5).

---

## 2.3 Verificar qué tienes

```bash
# Contenedores instalados
proot-distro list

# Solo los nombres, uno por línea (útil en scripts)
proot-distro list -q

# ¿Es nativo o emulado?
pocketarch -- uname -m        # debe decir: aarch64

# Resultado de la sonda (on / off)
cat ~/.config/pocketarch/link2symlink

# Dónde vive el rootfs y cuánto ocupa
d=$(find $PREFIX/var/lib/proot-distro -maxdepth 2 -type d -name arch-arm); echo "$d"; du -sh "$d"

# Espacio libre en Termux
df -h $HOME
```

---

## 2.4 Bootstrap (`make bootstrap`)

`scripts/bootstrap.sh` deja pacman operativo bajo PRoot. Lo ejecuta `make bootstrap` desde Termux y lo repite `install.sh` dentro del contenedor:

1. **Keyring de ALARM.** Crea `/etc/pacman.d/gnupg` (modo 755) con un `gpg.conf` que contiene `lock-never` **antes** de `pacman-key --init`, y lo mantiene ahí. Si falta `trustdb.gpg`, ejecuta `pacman-key --init` y `pacman-key --populate archlinuxarm`.
2. **pacman.conf.** Activa `DisableSandboxFilesystem` y `DisableSandboxSyscalls` en `[options]` (descomenta las líneas de la plantilla), quita un `DisableSandbox` suelto y comenta `DownloadUser`. Se comprueba con `pacman-conf`.
3. **`pacman -Syu --needed git`.**

Sin el **1**, cualquier `pacman -S` falla por firma. Sin el **2**, falla con `restricting filesystem access failed because Landlock is not supported by the kernel`.

---

## 2.5 Backup

Se hace **desde Termux**, nunca desde dentro del contenedor.

```bash
termux-setup-storage          # lo hace make termux; crea ~/storage/downloads

proot-distro backup --output ~/storage/downloads/arch-arm-$(date +%F).tar.gz arch-arm
```

> ⚠ Antes de confiar en un backup, revisa la sintaxis con `proot-distro backup --help`.

**El backup del contenedor no incluye la capa Termux.** La mayor parte se rehace con `make termux`; lo que no está en el repo se guarda aparte:

```bash
tar czf ~/storage/downloads/termux-config-$(date +%F).tar.gz -C ~ .ssh .config/pocketarch
```

---

## 2.6 Restaurar, resetear, borrar

```bash
# Restaurar desde un backup
proot-distro restore ~/storage/downloads/arch-arm-2026-07-08.tar.gz

# Volver el contenedor a estado recién instalado (destructivo)
proot-distro reset arch-arm

# Eliminarlo por completo (destructivo, irreversible)
proot-distro remove arch-arm
```

`reset` y `remove` **borran todo lo no versionado**. Antes de cualquiera de los dos, confirma que los commits del contenedor estén en GitHub o en `~/PocketArch-ARM`. Después de `reset`, `make bootstrap install` reconstruye el entorno. Después de `remove`, `make container bootstrap install`.

---

## 2.7 Imagen vs receta

No confundir dos cosas que suenan igual:

- **El repo + `make`** → la **receta**. Versionada, legible, evoluciona. Es cómo se replica PocketArch de verdad.
- **`proot-distro backup` (tar.gz)** → el **paracaídas**. Foto opaca y pesada de un momento. Sirve si el contenedor se corrompe y no quieres reconstruir.

La receta es el plan. La imagen es el respaldo. No sustituyas una por la otra.

<img src="../assets/divider.svg" alt=""/>

# ❯ Parte 3 — Claude Code

## 3.1 Por qué está en PocketArch

PocketArch funciona perfectamente sin Claude Code. Está aquí por una razón concreta: **evitar hacer el trabajo dos veces.**

El entorno se puede configurar a mano, siguiendo una guía y editando cada archivo con `nano`. Pero entonces la config queda escrita suelta en `~/.config`, y luego hay que rehacerla para meterla en el repo de dotfiles. Config a mano ≠ config reproducible.

Claude Code escribe cada archivo **directo en `~/.pocket-arch`** y lo enlaza con `stow`. Un solo flujo: configurado y versionado a la vez. Además el contenedor es aislado y desechable (`proot-distro reset`), así que darle permisos amplios tiene un costo bajo.

---

## 3.2 Instalación (dentro del contenedor)

`install.sh` instala Claude Code con el instalador nativo si falta `~/.local/bin/claude`:

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude --version
claude doctor                           # verifica instalación, red y auth
```

Notas:
- El binario queda en `~/.local/bin/claude`. `install.sh` añade ese directorio al `PATH` de su propia ejecución y `exports.zsh` lo hace persistente.
- Se actualiza solo; no depende de `npm` ni de `pacman`.
- **Sin `sudo`**: en PRoot ya eres root.
- ALARM es **glibc**, así que el binario nativo funciona sin workarounds.

---

## 3.3 Permisos como root

Como root, `--dangerously-skip-permissions` **está bloqueado por diseño**. Los permisos amplios se configuran en `~/.claude/settings.json`: allowlist en modo `acceptEdits`, con `deny` contra borrados catastróficos.

Ese archivo es global del contenedor: aplica desde cualquier carpeta.

---

## 3.4 Primer arranque

Requiere cuenta de pago (Pro, Max, Team o API).

```bash
mkdir -p ~/project/PocketArch
cd ~/project/PocketArch
claude
```

El primer lanzamiento abre autenticación: imprime una URL, la abres en el navegador del teléfono y pegas el código.

En esa carpeta van `CLAUDE.md` (contexto y permisos del contenedor) y `PocketArch-plan.md` (fases y estado). Claude Code lee el `CLAUDE.md` automáticamente al trabajar ahí.

---

## 3.5 Reproducibilidad

Claude Code no es un paquete de `pacman`: **no aparece en `packages.txt`**. Lo instala `install.sh` con el instalador nativo, así que un despliegue con `make` reconstruye el entorno con la herramienta incluida. La config versionada (tema, statusline, `settings.json`) llega por el paquete stow `claude`.

<img src="../assets/divider.svg" alt=""/>

# ❯ Gotchas de esta capa

- **link2symlink tumba la sesión en algunos dispositivos** — proot emula los enlaces duros y, en algunos kernels, cualquier `ln` termina en *signal 11*. Con `--no-link2symlink` el `ln` devuelve EPERM y la sesión sigue. La sonda de `make container` decide por dispositivo y `pocketarch` aplica la decisión (1.5). Los clones locales usan `git clone --no-hardlinks`.
- **`pacman-key --init` cae con signal 11** — gpg crea sus archivos de bloqueo con enlaces duros. `lock-never` en `/etc/pacman.d/gnupg/gpg.conf`, escrito antes del `--init` y mantenido después, lo evita. El keyring está completo cuando existe `trustdb.gpg`, no cuando existe el directorio (2.4).
- **Sandbox de pacman** — la plantilla de `pacman.conf` trae `DisableSandboxFilesystem` y `DisableSandboxSyscalls` comentadas en `[options]`. PocketArch las activa; `DisableSandbox` es la forma abreviada de las dos. Comprobación: `pacman-conf | grep DisableSandbox` debe listar ambas (2.4).
- **Plugins de Termux (`Termux:API`, `Termux:Styling`) deben venir de la misma fuente que Termux** (F-Droid o donde lo instalaste). Si no, fallan por firma.
- **Sensores (batería, temperatura)** requieren la app `Termux:API` + el paquete `termux-api`. Viven aquí, **no** en el contenedor. Por eso Fastfetch dentro de Arch no los muestra.
- **`qemu-user-x86-64`** solo hace falta para contenedores x86 emulados. Con `arch-arm` nativo es innecesario: `pkg uninstall qemu-user-x86-64`.
- **Fastfetch reporta el disco del host Android** (`erofs [Read-only]`), no el del contenedor. Artefacto de PRoot, no un fallo.

<img src="../assets/divider.svg" alt=""/>

# ❯ Reinstalación desde cero (checklist)

1. Instalar Termux + plugins desde la misma fuente.
2. Prerrequisitos y clon (1.1): `pkg install gh git make proot-distro curl unzip`, `gh auth login`, `gh repo clone AlMorRod/PocketArch-ARM ~/PocketArch-ARM`.
3. Contenedor desde backup *(opcional)*: `proot-distro restore <backup.tar.gz>`.
4. `cd ~/PocketArch-ARM && make`.
5. Llaves SSH para `geo` (1.7), si no vienen del backup de `~/.ssh`.
6. Dentro del contenedor: `gh auth login` (SSH) para poder hacer push, y `/theme` en Claude Code (README, Claude Code).
