#!/bin/sh
# dotfiles installer — POSIX sh, works on Termux (Android) and GNU/Linux.
# Idempotent. Backs up existing configs, then symlinks the repo ones.
#
# Usage:
#   ./install.sh              # install everything
#   DRY_RUN=1 ./install.sh    # preview only, no changes
#   ./install.sh --no-termux  # skip Termux app assets

set -u

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR="$REPO_DIR/configs"
HOME_DIR=${HOME:-$HOME}

DRY_RUN=${DRY_RUN:-0}
SKIP_TERMUX=${SKIP_TERMUX:-0}
[ "${1:-}" = "--no-termux" ] && SKIP_TERMUX=1

# Platform detection: $PREFIX is set only on Termux.
IS_TERMUX=0
[ -n "${PREFIX:-}" ] && [ -d "$PREFIX/bin" ] && IS_TERMUX=1

say() { printf '[dotfiles] %s\n' "$*"; }
die() { printf '[dotfiles] ERROR: %s\n' "$*" >&2; exit 1; }

run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '[dotfiles] (dry-run) %s\n' "$*"
  else
    "$@"
  fi
}

# link <source> <dest> — symlink source -> dest, backing up any existing file.
link() {
  src="$1"
  dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    run mv "$dest" "$dest.bak.$(date +%Y%m%d%H%M%S)"
    say "backed up existing $dest"
  fi
  run ln -sfn "$src" "$dest"
  say "linked $dest -> $src"
}

main() {
  [ -d "$CONFIG_DIR" ] || die "configs/ not found next to install.sh"

  # Always-installed shell/tool configs (platform-independent)
  link "$CONFIG_DIR/bashrc"    "$HOME_DIR/.bashrc"
  link "$CONFIG_DIR/tmux.conf" "$HOME_DIR/.tmux.conf"
  link "$CONFIG_DIR/gitconfig" "$HOME_DIR/.gitconfig"

  # Local overrides the installer never touches.
  if [ ! -e "$HOME_DIR/.bashrc.local" ]; then
    run touch "$HOME_DIR/.bashrc.local"
    say "created empty $HOME_DIR/.bashrc.local (your per-host overrides)"
  fi
  if [ ! -e "$HOME_DIR/.gitconfig.local" ]; then
    run touch "$HOME_DIR/.gitconfig.local"
    say "created empty $HOME_DIR/.gitconfig.local (set your name/email here)"
  fi

  # Termux app assets (only meaningful on Android)
  if [ "$IS_TERMUX" = "1" ] && [ "$SKIP_TERMUX" = "0" ]; then
    mkdir -p "$HOME_DIR/.termux"
    link "$CONFIG_DIR/termux/colors.properties" "$HOME_DIR/.termux/colors.properties"
    link "$CONFIG_DIR/termux/font.ttf"          "$HOME_DIR/.termux/font.ttf"
    link "$CONFIG_DIR/termux/termux.properties" "$HOME_DIR/.termux/termux.properties"
    if [ "$DRY_RUN" = "0" ] && command -v termux-reload-settings >/dev/null 2>&1; then
      termux-reload-settings
      say "reloaded Termux settings"
    fi
  fi

  # Zellij config + custom themes (works on Termux and Linux)
  mkdir -p "$HOME_DIR/.config/zellij"
  link "$CONFIG_DIR/zellij/config.kdl" "$HOME_DIR/.config/zellij/config.kdl"
  mkdir -p "$HOME_DIR/.config/zellij/themes"
  link "$CONFIG_DIR/zellij/themes/catppuccin-mocha-custom.kdl" \
       "$HOME_DIR/.config/zellij/themes/catppuccin-mocha-custom.kdl"

  # tmux plugin manager (TPM) — required for catppuccin/resurrect/continuum
  if [ ! -d "$HOME_DIR/.tmux/plugins/tpm" ]; then
    say "TPM not found. Install it:"
    say "  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
  fi

  say "Done. Start a new shell (or 'source ~/.bashrc') to apply."
}

main "$@"
