# Searching with navi: the vault, tldr pages, cheat.sh. The filled command is printed, never run.

TLDR_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/cmdvault/tldr"
TLDR_URL="https://raw.githubusercontent.com/tldr-pages/tldr/main/pages"

# tldr_page NAME: the markdown of a tldr page, downloaded once into TLDR_CACHE
# (the Haskell tldr client of Ubuntu can no longer update its own cache),
# a page that does not exist is not asked for again for 30 days
tldr_page() {
  local NAME PLATFORM FILE MISSING STATUS=0
  NAME=$(printf '%s' "$*" | tr 'A-Z ' 'a-z-')
  MISSING="$TLDR_CACHE/missing/$NAME"
  [ -e "$MISSING" ] && [ -z "$(find "$MISSING" -mtime +30 2>/dev/null)" ] && return 1
  for PLATFORM in linux common; do
    FILE="$TLDR_CACHE/$PLATFORM/$NAME.md"
    if [ ! -s "$FILE" ] || [ -n "$(find "$FILE" -mtime +30 2>/dev/null)" ]; then
      mkdir -p "$TLDR_CACHE/$PLATFORM"
      curl -fsSL --connect-timeout 3 --max-time 10 -o "$FILE.part" "$TLDR_URL/$PLATFORM/$NAME.md" 2>/dev/null &&
        mv "$FILE.part" "$FILE" || STATUS=$?
      rm -f "$FILE.part"
    fi
    [ -s "$FILE" ] && cat "$FILE" && return 0
  done
  # 22: the server answered 404 for both platforms (not offline)
  [ "$STATUS" = 22 ] && mkdir -p "${MISSING%/*}" && touch "$MISSING"
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

# tldr_cheat QUERY DIR: write the tldr examples of QUERY into DIR/tldr.cheat,
# leaving out the ones already saved in the vault
tldr_cheat() {
  local PAGE
  PAGE=$(tldr_page "$1") || return 1
  tldr_to_cheat "$1" <<<"$PAGE" | awk -v saved="$([ -d "$CHEATS_DIR" ] && cheat_parse | cut -f6)" '
    BEGIN { n = split(saved, s, "\n"); for (i = 1; i <= n; i++) have[s[i]] = 1 }
    /^# / { desc = $0; next }
    desc != "" { if (!($0 in have)) print "\n" desc "\n" $0; desc = ""; next }
    /^%/ { print }
  ' >"$2/tldr.cheat"
  grep -q '^# ' "$2/tldr.cheat"
}

# picked_template OUTPUT DIR: the command templates of the entries in the cheat dir DIR
# that navi can print as OUTPUT (its <placeholders> filled with anything), one per line
picked_template() {
  local OUTPUT=$1
  shift
  CHEATS_DIR="$1" cheat_parse | cut -f6 | OUTPUT="$OUTPUT" perl -ne '
    chomp;
    (my $cmd = $_) =~ s/\x1f/\n/g;
    my $re = join ".*?", map { quotemeta } split /<[A-Za-z0-9_-]+>/, $cmd, -1;
    print "$_\n" if $ENV{OUTPUT} =~ /^$re$/s;
  '
}

# offer_save OUTPUT TLDR_DIR QUERY: when OUTPUT was picked from the tldr examples (and could not
# have come from the vault), offer to save the example to the vault
offer_save() {
  local TEMPLATE DESCRIPTION ANSWER
  { : </dev/tty; } 2>/dev/null || return 0
  [ -n "$(picked_template "$1" "$CHEATS_DIR")" ] && return 0
  TEMPLATE=$(picked_template "$1" "$2" | head -n1)
  [ -n "$TEMPLATE" ] || return 0
  ANSWER=$(ask "That one came from tldr. Save it to your vault too? [y/N] ") || return 0
  [[ $ANSWER == [yY]* ]] || return 0
  DESCRIPTION=$(awk -v cmd="$TEMPLATE" '/^# / { d = substr($0, 3) } $0 == cmd { print d; exit }' "$2/tldr.cheat")
  # a subshell, cmd_save exits on errors and on Ctrl+C
  (cmd_save -D "$DESCRIPTION" -T "$3" -- "$TEMPLATE") >&2 </dev/tty || true
}

# cmd_find [--tldr | --cheatsh] [--] [QUERY]
# a QUERY that is the name of an installed command also lists its tldr examples, after the vault entries
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
  local QUERY="$*" DIR OUT STATUS
  need navi fzf

  case $MODE in
    vault)
      need_data
      if [[ $QUERY =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] && command -v "$QUERY" >/dev/null 2>&1; then
        DIR=$(mktemp -d)
        if tldr_cheat "$QUERY" "$DIR"; then
          # in file order, vault first (the tldr examples all match the query anyway),
          # --fzf-overrides replaces the overrides of config/navi.yaml
          OUT=$(navi --print --path "$CHEATS_DIR:$DIR" --query "$QUERY" \
            --fzf-overrides '--height 80% --layout reverse --border none --no-sort')
          STATUS=$?
          [ $STATUS = 0 ] && [ -n "$OUT" ] && offer_save "$OUT" "$DIR" "$QUERY"
          rm -rf "$DIR"
          [ -n "$OUT" ] && printf '%s\n' "$OUT"
          return $STATUS
        fi
        rm -rf "$DIR"
      fi
      navi --print --path "$CHEATS_DIR" ${QUERY:+--query "$QUERY"}
      ;;
    cheatsh)
      [ -n "$QUERY" ] || die "usage: cv --cheatsh QUERY"
      need curl
      navi --print --cheatsh "$QUERY"
      ;;
    tldr)
      [ -n "$QUERY" ] || die "usage: cv --tldr COMMAND"
      DIR=$(mktemp -d)
      tldr_cheat "$QUERY" "$DIR" || { rm -rf "$DIR"; die "no tldr page for '$QUERY' (or all its examples are in the vault)"; }
      OUT=$(navi --print --path "$DIR")
      STATUS=$?
      [ $STATUS = 0 ] && [ -n "$OUT" ] && [ -d "$CHEATS_DIR" ] && offer_save "$OUT" "$DIR" "$QUERY"
      rm -rf "$DIR"
      [ -n "$OUT" ] && printf '%s\n' "$OUT"
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
