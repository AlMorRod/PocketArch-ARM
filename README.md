# dotfiles — PocketArch

Config versionada para el contenedor `arch-arm` (Arch Linux ARM sobre PRoot/Termux).
Fuente de verdad de progreso y contexto: `PocketArch-plan.md` / `CLAUDE.md` en el proyecto PocketArch.

## Estructura (stow-friendly)

Cada carpeta de primer nivel es un "paquete" de [GNU Stow](https://www.gnu.org/software/stow/),
enlazado a `$HOME` con:

```sh
stow -d ~/dotfiles -t ~ <paquete>
```

Paquetes actuales:

- `zsh/` — shell, historial, alias, init de starship/zoxide (`ZDOTDIR=~/.config/zsh`)
- `starship/` — prompt (`~/.config/starship.toml`)
- `fastfetch/` — system info (`~/.config/fastfetch/`)

Pendientes de fases siguientes: `nvim`, `tmux`, `yazi`, `lazygit`, `git`.

## Paleta

Material Monokai — ver tabla en `CLAUDE.md` del proyecto PocketArch. Toda config de color
de este repo deriva de esa tabla; no se introducen colores fuera de ella.

## packages.txt

`pacman -Qqe > packages.txt`, regenerado al instalar/quitar paquetes.
