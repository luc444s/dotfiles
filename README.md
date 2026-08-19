# dotfiles

Configuracion personal de shell/terminal — compatible con **Termux (Android)** y **GNU/Linux**.

## Que incluye

| Archivo | Descripcion |
|---|---|
| `configs/bashrc` | Prompt con git branch + venv, auto-activacion de Python venv, wrappers de zellij/tmux. Deteccion automatica de plataforma. |
| `configs/tmux.conf` | Tema Catppuccin Mocha, navegacion vim, copiado a clipboard cross-platform (`termux-clipboard-set` / `xclip` / `wl-copy`), tmux-resurrect + continuum. |
| `configs/gitconfig` | Credencial via `gh`, incluye `~/.gitconfig.local` para identidad por host. |
| `configs/termux/` | `colors.properties` (Catppuccin Mocha), `font.ttf`, `termux.properties` (fullscreen, extra-keys, back-key, etc.). |

## Instalacion rapida

```bash
# desde cualquier lado
git clone <tu-repo-url> ~/dotfiles
cd ~/dotfiles
./install.sh
```

En **Termux** detecta la plataforma solo y ademas instala los assets de la app
(`~/.termux/*`). En **Linux** omite esa parte. Tambien acepta `--no-termux`.

```bash
DRY_RUN=1 ./install.sh   # solo muestra que haria
./install.sh --no-termux # salta assets de la app Termux
```

## Como funciona

- El instalador **hace symlink** de `configs/*` a tu `$HOME`. Idempotente: hace backup
  de cualquier config existente (`*.bak.<timestamp>`).
- La config es **unica fuente de verdad**; editas el repo, no `~/.bashrc`.
- Overrides por maquina en **`~/.bashrc.local`** (PATH, project dirs, aliases) y
  **`~/.gitconfig.local`** (nombre/email) — el instalador nunca los toca.

## Dependencias por host

- `gh` (GitHub CLI) para credenciales git.
- Tmux plugins requieren **TPM**:
  ```bash
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  ```
- Clipboard en Linux: `xclip` (X11) o `wl-clipboard` (Wayland).
- En Termux: `termux-clipboard-set` viene con el paquete `termux-tools`.

## Personalizacion (por host)

```bash
# ~/.bashrc.local  — rutas y project venvs de TU maquina
export PATH="$HOME/mi/path:$PATH"
PROJECT_DIRS=("$HOME/Proyectos/MiApp")
PROJECT_VENVS=("$HOME/Proyectos/MiApp/.venv")
```

## Licencia

MIT — ver `LICENSE`.
