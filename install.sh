#!/usr/bin/env bash

# Installs cmdvault: navi, fzf (and optionally agg) into ~/.local/bin, the cmdvault command,
# and the cheats repo ($CMDVAULT_DATA, default ~/git/cmdvault-cheats).
# Safe to run again. No sudo needed.
#
# Usage: ./install.sh [--with-agg | --no-agg] [--data-remote GIT_URL]

set -euo pipefail

NAVI_VERSION=2.24.0
FZF_VERSION=0.74.5
AGG_VERSION=1.9.0

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
BIN="$HOME/.local/bin"
DATA="${CMDVAULT_DATA:-$HOME/git/cmdvault-cheats}"

WITH_AGG=ask
DATA_REMOTE=""
while [ $# -gt 0 ]; do
  case $1 in
    --with-agg) WITH_AGG=yes ;;
    --no-agg) WITH_AGG=no ;;
    --data-remote)
      DATA_REMOTE=$2
      shift
      ;;
    -h | --help)
      sed -n '3,7p' "$0"
      exit 0
      ;;
    *)
      echo "unknown option $1" >&2
      exit 1
      ;;
  esac
  shift
done

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$BIN"

# has_version CMD VERSION: CMD is installed and reports VERSION
has_version() {
  command -v "$1" >/dev/null 2>&1 && "$1" --version 2>/dev/null | grep -qF "$2"
}

if has_version navi "$NAVI_VERSION"; then
  echo "navi $NAVI_VERSION already installed"
else
  echo "installing navi $NAVI_VERSION"
  curl -fsSL "https://github.com/denisidoro/navi/releases/download/v$NAVI_VERSION/navi-v$NAVI_VERSION-x86_64-unknown-linux-musl.tar.gz" | tar -xz -C "$TMP"
  install -m 755 "$TMP/navi" "$BIN/navi"
fi

if has_version fzf "$FZF_VERSION"; then
  echo "fzf $FZF_VERSION already installed"
else
  echo "installing fzf $FZF_VERSION"
  curl -fsSL "https://github.com/junegunn/fzf/releases/download/v$FZF_VERSION/fzf-$FZF_VERSION-linux_amd64.tar.gz" | tar -xz -C "$TMP"
  install -m 755 "$TMP/fzf" "$BIN/fzf"
fi

if [ "$WITH_AGG" = ask ] && ! has_version agg "$AGG_VERSION"; then
  read -r -p "Install agg $AGG_VERSION for GIF export of recordings? [y/N] " ANSWER
  [[ $ANSWER =~ ^[Yy] ]] && WITH_AGG=yes
fi
if [ "$WITH_AGG" = yes ]; then
  if has_version agg "$AGG_VERSION"; then
    echo "agg $AGG_VERSION already installed"
  else
    echo "installing agg $AGG_VERSION"
    curl -fsSL -o "$TMP/agg" "https://github.com/asciinema/agg/releases/download/v$AGG_VERSION/agg-x86_64-unknown-linux-musl"
    install -m 755 "$TMP/agg" "$BIN/agg"
  fi
fi

ln -sfn "$REPO/bin/cmdvault" "$BIN/cmdvault"
echo "linked $BIN/cmdvault"

# the cheats repo
if [ -d "$DATA/.git" ]; then
  echo "cheats repo $DATA already exists"
elif [ -n "$DATA_REMOTE" ]; then
  git clone "$DATA_REMOTE" "$DATA"
else
  echo "creating the cheats repo $DATA"
  mkdir -p "$DATA/recordings"
  cp -r --update=none "$REPO/template/." "$DATA/"
  git -C "$DATA" init -q
  git -C "$DATA" add -A
  git -C "$DATA" commit -q -m "Initial cheats"
fi
mkdir -p "$DATA/cheats" "$DATA/recordings"

cat <<EOF

Done. Hooks (already in linux-setup, add them yourself elsewhere):
  ~/.bashrc:     [ -f $REPO/shell/cmdvault.bash ] && source $REPO/shell/cmdvault.bash
  ~/.tmux.conf:  source-file -q $REPO/tmux/cmdvault.tmux
  rofi menu:     $BIN/cmdvault rofi
EOF
[ "$DATA" = "$HOME/git/cmdvault-cheats" ] || echo "  and export CMDVAULT_DATA=$DATA before sourcing cmdvault.bash"
