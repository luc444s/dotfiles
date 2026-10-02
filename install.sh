#!/bin/sh
# dotfiles installer — POSIX sh, works on Termux (Android) and GNU/Linux.
# Idempotent and non-destructive: it never overwrites a real config file unless
# you explicitly ask for it (--clobber / --link-bashrc).
#
# Usage:
#   ./install.sh                 # install everything (safe by default)
#   DRY_RUN=1 ./install.sh       # preview only, no changes
#   ./install.sh --no-termux     # skip Termux app assets
#   ./install.sh --link-bashrc   # also symlink ~/.bashrc (backs up current)
#   ./install.sh --skip-bashrc   # never touch ~/.bashrc
#   ./install.sh --clobber       # allow overwriting real files (backs them up)
#
# Real files are never clobbered by default: if ~/.bashrc (or any config) is a
# real file instead of a symlink, it is left alone and reported.
#
# Workflow: shell configs are SYMLINKED, so editing the repo applies instantly.
# The Termux app assets under ~/.termux are COPIED instead (see copy_asset),
# so editing configs/termux/* in the repo does NOT apply until you re-run this
# script. To edit terminal settings: change the file in this repo, re-run
# ./install.sh, then force-stop the Termux app.

set -u

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR="$REPO_DIR/configs"
HOME_DIR=${HOME:?HOME is not set}

DRY_RUN=${DRY_RUN:-0}
SKIP_TERMUX=${SKIP_TERMUX:-0}
CLOBBER=${CLOBBER:-0}
BASHRC_MODE=auto          # auto | link | skip

# Platform detection: $PREFIX is set only on Termux.
IS_TERMUX=0
[ -n "${PREFIX:-}" ] && [ -d "$PREFIX/bin" ] && IS_TERMUX=1

say()  { printf '[dotfiles] %s\n' "$*"; }
die()  { printf '[dotfiles] ERROR: %s\n' "$*" >&2; exit 1; }
# warn goes to stdout too: this is a user-facing installer where the order of
# lines matters more than stream separation.
warn() { printf '[dotfiles] WARN: %s\n' "$*"; }

# usage() — print the header comment block, stopping at the first blank line.
usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }

# run <cmd...> — execute, or just show it under DRY_RUN.
run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '[dotfiles] (dry-run) %s\n' "$*"
  else
    "$@"
  fi
}

# done <msg> — print a success line only when we really did the thing.
ok() {
  [ "$DRY_RUN" = "0" ] && say "$1"
  return 0
}

# mkdirp <dir> — dry-run safe mkdir.
mkdirp() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '[dotfiles] (dry-run) mkdir -p %s\n' "$1"
  else
    mkdir -p "$1"
  fi
}

# touchf <file> — create empty file only if missing.
touchf() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    return 0
  fi
  run touch "$1"
  ok "created empty $1"
}

# link <source> <dest> — point dest at source, repairing broken symlinks and
# refusing to clobber real files unless CLOBBER=1.
link() {
  src="$1"
  dest="$2"

  [ -e "$src" ] || die "missing source: $src"

  # Already pointing at the right place.
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    say "ok (already linked) $dest"
    return 0
  fi

  # A symlink (possibly broken) is ours to manage — no data at risk.
  if [ -L "$dest" ]; then
    [ -e "$dest" ] || warn "repairing broken symlink: $dest"
    run ln -sfn "$src" "$dest"
    ok "linked $dest -> $src"
    return 0
  fi

  # Real file: back it up only when explicitly allowed.
  if [ -e "$dest" ]; then
    if [ "$CLOBBER" = "1" ]; then
      bak="$dest.bak.$(date +%Y%m%d%H%M%S)"
      run mv "$dest" "$bak"
      ok "backed up $dest -> $bak"
    else
      say "SKIPPED $dest — real file exists, left untouched."
      say "         repo version: $src"
      say "         to overwrite:  ./install.sh --clobber  (backs it up first)"
      return 0
    fi
  fi

  run ln -sfn "$src" "$dest"
  ok "linked $dest -> $src"
}

# copy_asset <source> <dest> — install as a REAL file, not a symlink.
# Termux >= 0.119 stats termux.properties, and if it is a symlink it logs
#   "Ignoring properties file ... of type: symlink"
# and silently loads built-in defaults instead. Hard links are not an option
# either: link() is denied for untrusted_app on Android's f2fs/data partition.
# So these assets must be copied, and kept in sync one way.
copy_asset() {
  src="$1"
  dest="$2"

  [ -e "$src" ] || die "missing source: $src"

  if [ -L "$dest" ]; then
    run rm -f "$dest"
  elif [ -e "$dest" ]; then
    bak="$dest.bak.$(date +%Y%m%d%H%M%S)"
    run mv "$dest" "$bak"
    ok "backed up existing $dest -> $bak"
  fi

  run cp -f "$src" "$dest"
  run chmod 600 "$dest"
  ok "copied $src -> $dest (real file, not a symlink)"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --no-termux)  SKIP_TERMUX=1 ;;
    --link-bashrc) BASHRC_MODE=link; CLOBBER=1 ;;
    --skip-bashrc) BASHRC_MODE=skip ;;
    --clobber)    CLOBBER=1 ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

main() {
  [ -d "$CONFIG_DIR" ] || die "configs/ not found next to install.sh"

  # ~/.bashrc — the one file people customize most, so it gets special care.
  case "$BASHRC_MODE" in
    skip)
      say "skipping ~/.bashrc (--skip-bashrc)"
      ;;
    link)
      link "$CONFIG_DIR/bashrc" "$HOME_DIR/.bashrc"
      ;;
    *)
      if [ -e "$HOME_DIR/.bashrc" ] && [ ! -L "$HOME_DIR/.bashrc" ]; then
        say "SKIPPED ~/.bashrc — real file present, keeping your local edits."
        say "         repo version: $CONFIG_DIR/bashrc"
        say "         to link it:    ./install.sh --link-bashrc"
      else
        link "$CONFIG_DIR/bashrc" "$HOME_DIR/.bashrc"
      fi
      ;;
  esac

  # Always-installed shell/tool configs (platform-independent)
  link "$CONFIG_DIR/tmux.conf" "$HOME_DIR/.tmux.conf"
  link "$CONFIG_DIR/gitconfig" "$HOME_DIR/.gitconfig"

  # Local overrides the installer never writes to.
  touchf "$HOME_DIR/.bashrc.local"
  touchf "$HOME_DIR/.gitconfig.local"

  # Termux app assets (only meaningful on Android)
  if [ "$IS_TERMUX" = "1" ] && [ "$SKIP_TERMUX" = "0" ]; then
    mkdirp "$HOME_DIR/.termux"
    copy_asset "$CONFIG_DIR/termux/colors.properties" "$HOME_DIR/.termux/colors.properties"
    copy_asset "$CONFIG_DIR/termux/font.ttf"          "$HOME_DIR/.termux/font.ttf"
    copy_asset "$CONFIG_DIR/termux/termux.properties" "$HOME_DIR/.termux/termux.properties"
    if [ "$DRY_RUN" = "0" ] && command -v termux-reload-settings >/dev/null 2>&1; then
      termux-reload-settings
      say "reloaded Termux settings"
    fi
  fi

  # Zellij config + custom themes (works on Termux and Linux)
  mkdirp "$HOME_DIR/.config/zellij/themes"
  link "$CONFIG_DIR/zellij/config.kdl" "$HOME_DIR/.config/zellij/config.kdl"
  link "$CONFIG_DIR/zellij/themes/catppuccin-mocha-custom.kdl" \
       "$HOME_DIR/.config/zellij/themes/catppuccin-mocha-custom.kdl"

  # tmux plugin manager (TPM) — required for catppuccin/resurrect/continuum
  if [ ! -d "$HOME_DIR/.tmux/plugins/tpm" ]; then
    say "TPM not found. Install it:"
    say "  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
  fi

  say "Done. Start a new shell (or 'source ~/.bashrc') to apply."
}

main