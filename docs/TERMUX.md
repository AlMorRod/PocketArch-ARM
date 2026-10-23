<div align="center">

<img src="../assets/termux-banner.svg" alt="TERMUX.md — PocketArch (capa host)" width="740"/>

</div>

> No es necesario para desplegar; `make termux` ya aplica esta configuración.
> El despliegue está en el [README](../README.md#-despliegue-desde-cero).

Qué deja `make termux` en la app Termux y cómo cambiarlo a mano. Los
archivos versionados viven en `termux/`; un `make termux` posterior
devuelve cada pieza a lo que dice el repo.

## Fuente

`~/.termux/font.ttf`: CaskaydiaCove Nerd Font Mono, descargada de las
releases de Nerd Fonts solo si el archivo no existe. Termux no lee ningún
otro nombre.

Cambiarla: copia otro `.ttf` como `~/.termux/font.ttf` y ejecuta
`termux-reload-settings`. Comprobación: `echo "󰣇   "` (cuadros vacíos =
la fuente no cargó).

## Paleta

`~/.termux/colors.properties`, copia de `termux/colors.properties`
(Material Monokai, mapeo hecho a mano). Se copia cuando difiere y se aplica
con `termux-reload-settings`.

Cambiarla: edita `termux/colors.properties` en el repo y repite
`make termux`. Por ejemplo, `color11` va a naranja (`#fd971f`); para un
amarillo más suave, `#e6db74`. *Termux:Styling* escribe en el mismo
archivo, y `make termux` lo devuelve al del repo.

## `pocketarch` y alias `arch`

`$PREFIX/bin/pocketarch` enlaza a `termux/pocketarch`, la única entrada a
`proot-distro login` (siempre con `--no-link2symlink`, ver
[gotchas](../README.md#-gotchas-del-entorno)). `arch` es su alias.

```sh
pocketarch                       # sesión interactiva en arch-arm
pocketarch -- uname -m           # un comando, con PATH limpio
pocketarch --bind A:B -- cmd     # opciones de proot-distro login antes de --
pocketarch --installed           # código de salida 0 si arch-arm existe
pocketarch --probe               # diagnóstico de link2symlink (= make probe)
```

## Selector de arranque

`~/.bashrc` lleva un bloque entre `# >>> PocketArch >>>` y
`# <<< PocketArch <<<` que carga `termux/bashrc.sh`. `make termux` reescribe
solo ese bloque y avisa si encuentra un selector o un `alias arch=` fuera
de él.

Con `~/.config/pocketarch/ready` (la escribe `make install`):

```
   󰣇  PocketArch

   g  geofront  mosh geo → tmux main
   a  Arch      arch-arm

   󰔟  Arch en 5s · Enter = Arch
```

| Tecla | Destino |
|-------|---------|
| `a`, Enter o 5 s sin tecla | Arch (`pocketarch`) |
| `g` | geofront: `mosh geo -- tmux new -As main`; si falla, `ssh -t geo 'tmux new -As main'`; si ambos fallan, vuelve al menú |
| `t` | Termux local (no figura en el menú) |
| al salir | geofront con éxito → Arch (solo con la marca) · Arch con 0 → cierra la sesión de Termux · otro código o una señal → muestra el motivo y conserva la sesión (`exit` hereda el código del último comando; `exit 0` fuerza el cierre) |

Sin la marca, una línea indica el paso que falta y queda la shell de Termux.

Cambiarlo a mano:
- `POCKETARCH_NO_PROMPT=1` → sin menú, Termux local.
- `touch ~/.no-geo` → sin menú, directo a Arch (`rm ~/.no-geo` lo quita).
- Teclas, textos o tiempo de espera: `termux/bashrc.sh`. Probar sin cerrar
  Termux: `bash -i`.

## Alias SSH `geo`

Si `~/.ssh/config` no tiene un `Host geo`, `make termux` añade:

```
Host geo
    HostName lotusproject.xyz
    User tyr
    ConnectTimeout 5
    ServerAliveInterval 30
```

Cambiarlo: edita esa entrada en `~/.ssh/config`; `make termux` no la vuelve
a tocar mientras exista. Las llaves no se gestionan.

## Backup de la capa

El backup del contenedor no incluye la capa Termux. La mayor parte se
rehace con `make termux`; lo que no está en el repo se guarda aparte:

```sh
tar czf ~/storage/downloads/termux-config-$(date +%F).tar.gz -C ~ .ssh .config/pocketarch
```
