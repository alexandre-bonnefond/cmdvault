# Searching with navi: the vault, tldr pages, cheat.sh. The filled command is printed, never run.

TLDR_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/cmdvault/tldr"
TLDR_URL="https://raw.githubusercontent.com/tldr-pages/tldr/main/pages"

# tldr_page NAME: the markdown of a tldr page, downloaded once into TLDR_CACHE
# (the Haskell tldr client of Ubuntu can no longer update its own cache)
tldr_page() {
  local NAME PLATFORM FILE
  NAME=$(printf '%s' "$*" | tr 'A-Z ' 'a-z-')
  for PLATFORM in linux common; do
    FILE="$TLDR_CACHE/$PLATFORM/$NAME.md"
    if [ ! -s "$FILE" ] || [ -n "$(find "$FILE" -mtime +30 2>/dev/null)" ]; then
      mkdir -p "$TLDR_CACHE/$PLATFORM"
      curl -fsSL -o "$FILE.part" "$TLDR_URL/$PLATFORM/$NAME.md" 2>/dev/null && mv "$FILE.part" "$FILE"
      rm -f "$FILE.part"
    fi
    [ -s "$FILE" ] && cat "$FILE" && return 0
  done
  return 1
}

# tldr_to_cheat NAME < page.md: a tldr page as a navi cheat,
# {{path/to/file}} becomes <path_to_file>, {{[-c|--create]}} becomes -c
tldr_to_cheat() {
  NAME="$1" perl -ne '
    BEGIN { print "% tldr, $ENV{NAME}\n" }
    sub var {
      my $v = lc shift;
      $v =~ s/[^a-z0-9]+/_/g;
      $v = substr($v, 0, 30);
      $v =~ s/^_+|_+$//g;
      return $v eq "" ? "value" : $v;
    }
    if (/^- (.*?):?\s*$/) { $desc = ucfirst $1 =~ s/[\[\]`]//gr; next }
    if (defined $desc && /^`(.*)`\s*$/) {
      my $cmd = $1;
      $cmd =~ s/\{\{\[([^|\]]*)\|[^\]]*\]\}\}/$1/g;
      $cmd =~ s/\{\{(.*?)\}\}/"<" . var($1) . ">"/ge;
      print "\n# $desc\n$cmd\n";
      undef $desc;
    }
  '
}

# cmd_find [--tldr | --cheatsh] [--] [QUERY]
cmd_find() {
  local MODE=vault
  while [ $# -gt 0 ]; do
    case $1 in
      -t | --tldr) MODE=tldr ;;
      -c | --cheatsh) MODE=cheatsh ;;
      --) shift && break ;;
      -*) die "find: unknown option $1" ;;
      *) break ;;
    esac
    shift
  done
  local QUERY="$*"
  need navi fzf

  case $MODE in
    vault)
      need_data
      navi --print --path "$CHEATS_DIR" ${QUERY:+--query "$QUERY"}
      ;;
    cheatsh)
      [ -n "$QUERY" ] || die "usage: cv --cheatsh QUERY"
      need curl
      navi --print --cheatsh "$QUERY"
      ;;
    tldr)
      [ -n "$QUERY" ] || die "usage: cv --tldr COMMAND"
      local DIR PAGE
      PAGE=$(tldr_page "$QUERY") || die "no tldr page for '$QUERY'"
      DIR=$(mktemp -d)
      tldr_to_cheat "$QUERY" <<<"$PAGE" >"$DIR/tldr.cheat"
      navi --print --path "$DIR"
      local STATUS=$?
      rm -rf "$DIR"
      return $STATUS
      ;;
  esac
}

# cmd_popup [PANE]: pick in a tmux popup, paste the result into PANE (bracketed, so it is not run),
# by default the pane the popup was opened from (@cmdvault-pane, set by tmux/cmdvault.tmux)
cmd_popup() {
  local PANE=${1:-$(tmux show-option -gqv @cmdvault-pane)} OUT
  [ -n "$PANE" ] || die "usage: cmdvault popup PANE"
  OUT=$(cmd_find) && [ -n "$OUT" ] || exit 0
  tmux set-buffer -b cmdvault -- "$OUT"
  tmux paste-buffer -p -d -b cmdvault -t "$PANE"
}
