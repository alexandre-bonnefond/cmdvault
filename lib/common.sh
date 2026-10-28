# Shared paths and helpers, sourced by bin/cmdvault (which sets CMDVAULT_ROOT).

CMDVAULT_DATA="${CMDVAULT_DATA:-$HOME/git/cmdvault-cheats}"
CMDVAULT_AUTOCOMMIT="${CMDVAULT_AUTOCOMMIT:-1}"
CHEATS_DIR="$CMDVAULT_DATA/cheats"
REC_DIR="$CMDVAULT_DATA/recordings"
ROFI_THEME="$HOME/git/linux-setup/appconfig/i3/rofi/menu-list.rasi"

# navi reads our config instead of ~/.config/navi
export NAVI_CONFIG="$CMDVAULT_ROOT/config/navi.yaml"

# fzf colours readable on light and dark terminals: the terminal's own 16 colours, and the current
# line in reverse video (fzf's default dark grey hides the text on a light background),
# the user's FZF_DEFAULT_OPTS come after, so their colours win (same in shell/cmdvault.bash)
export FZF_DEFAULT_OPTS="--color=16,bg+:-1,fg+:-1:reverse:bold,gutter:-1${FZF_DEFAULT_OPTS:+ $FZF_DEFAULT_OPTS}"

die() {
  echo "cmdvault: $*" >&2
  exit 1
}

# need CMD...: fail unless every command is installed
need() {
  local CMD
  for CMD in "$@"; do
    command -v "$CMD" >/dev/null 2>&1 || die "$CMD is not installed (run $CMDVAULT_ROOT/install.sh)"
  done
}

need_data() {
  [ -d "$CHEATS_DIR" ] || die "no cheats directory $CHEATS_DIR (run install.sh or set CMDVAULT_DATA)"
}

# vault_commit MESSAGE PATH...: commit the paths in the cheats repo, local only, never pushes
vault_commit() {
  local MESSAGE=$1
  shift
  [ "$CMDVAULT_AUTOCOMMIT" = 1 ] || return 0
  git -C "$CMDVAULT_DATA" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$CMDVAULT_DATA" add -- "$@" &&
    git -C "$CMDVAULT_DATA" commit -q -m "$MESSAGE" -- "$@" ||
    echo "cmdvault: git commit in $CMDVAULT_DATA failed" >&2
}

# ask PROMPT [DEFAULT]: editable prompt on the terminal, prints the answer
ask() {
  local REPLY
  read -r -e -p "$1" -i "${2:-}" REPLY </dev/tty || return 1
  printf '%s' "$REPLY"
}

# pango-escape a string for rofi -markup-rows (quoted replacements, & means the match in bash 5.2)
escape() {
  local S="${1//&/"&amp;"}"
  S="${S//</"&lt;"}"
  printf '%s' "${S//>/"&gt;"}"
}

# read_entry LINE: split a cheat_parse line into FILE LINE TAGS DESCRIPTION REC COMMAND
# (with IFS=tab, read would merge the empty fields)
read_entry() {
  IFS=$'\x1e' read -r FILE LINE TAGS DESCRIPTION REC COMMAND <<<"${1//$'\t'/$'\x1e'}"
}
