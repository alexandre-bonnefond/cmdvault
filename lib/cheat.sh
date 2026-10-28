# Reading and writing entries of the navi .cheat files.
#
# Entry format written by cmdvault (each entry has its own % block, so the $ lines,
# which navi scopes to a % block, belong to that entry only):
#
#   % tag1, tag2
#   # description
#   ; rec: recording-name
#   ; added: 2026-10-28
#   command <placeholder>
#   $ placeholder: command printing the values

# cheat_file TAGS: the file of an entry, named after its first tag
cheat_file() {
  local TAG=${1%%,*}
  TAG=$(printf '%s' "$TAG" | tr 'A-Z' 'a-z' | tr -cs 'a-z0-9_.-' '-' | sed 's/^-*//; s/-*$//')
  echo "$CHEATS_DIR/${TAG:-misc}.cheat"
}

# cheat_append FILE TAGS DESCRIPTION COMMAND REC VARS
# VARS: newline separated "name<TAB>command printing the values" lines
cheat_append() {
  local FILE=$1 TAGS=$2 DESCRIPTION=$3 COMMAND=$4 REC=$5 VARS=$6 NAME GENERATOR
  mkdir -p "$(dirname "$FILE")"
  {
    [ -s "$FILE" ] && echo
    echo "% $TAGS"
    echo "# $DESCRIPTION"
    [ -n "$REC" ] && echo "; rec: $REC"
    echo "; added: $(date +%F)"
    printf '%s\n' "$COMMAND"
    if [ -n "$VARS" ]; then
      while IFS=$'\t' read -r NAME GENERATOR; do
        printf '$ %s: %s\n' "$NAME" "$GENERATOR"
      done <<<"$VARS"
    fi
  } >>"$FILE"
}

# cheat_parse [FILE...]: one TSV line per entry:
#   file, line of the description, tags, description, recording, command
# the lines of a multi-line command are joined with \x1f
cheat_parse() {
  [ $# -gt 0 ] || set -- "$CHEATS_DIR"/*.cheat
  [ -e "$1" ] || return 0
  awk '
    function flush() {
      if (cmd != "") print file "\t" dline "\t" tags "\t" desc "\t" rec "\t" cmd
      cmd = ""
    }
    FNR == 1 { flush(); file = FILENAME; tags = ""; desc = ""; rec = "" }
    /^%/ { flush(); tags = $0; sub(/^%[ \t]*/, "", tags); desc = ""; rec = ""; next }
    /^#/ { flush(); desc = $0; sub(/^#[ \t]*/, "", desc); dline = FNR; rec = ""; next }
    /^;[ \t]*rec:/ { rec = $0; sub(/^;[ \t]*rec:[ \t]*/, "", rec); next }
    /^[;@]/ { next }
    /^\$/ { flush(); next }
    /^[ \t]*$/ { flush(); next }
    { cmd = (cmd == "" ? $0 : cmd "\037" $0) }
    END { flush() }
  ' "$@"
}

# cheat_vars FILE LINE: "name<TAB>command" for the $ lines of the % block holding LINE,
# without navi's "--- options"
cheat_vars() {
  awk -v target="$2" '
    /^%/ { if (FNR > target) exit; delete vars; n = 0 }
    /^\$[ \t]*[^:]+:/ {
      line = $0
      sub(/^\$[ \t]*/, "", line)
      name = line; sub(/[ \t]*:.*/, "", name)
      gen = line; sub(/^[^:]*:[ \t]*/, "", gen); sub(/[ \t]+---[ \t].*$/, "", gen)
      vars[++n] = name "\t" gen
    }
    END { for (i = 1; i <= n; i++) print vars[i] }
  ' "$1"
}

# cheat_set_rec FILE LINE NAME: link a recording to the entry described at LINE
cheat_set_rec() {
  local TMP
  TMP=$(mktemp)
  awk -v target="$2" -v rec="$3" '
    FNR == target { print; print "; rec: " rec; skip = 1; next }
    skip && /^;[ \t]*rec:/ { next }
    { skip = 0; print }
  ' "$1" >"$TMP" && cat "$TMP" >"$1"
  rm -f "$TMP"
}

# cheat_placeholders COMMAND: the <placeholder> names, in order, once each
cheat_placeholders() {
  printf '%s\n' "$1" | grep -oE '<[A-Za-z_][A-Za-z0-9_-]*>' | tr -d '<>' | awk '!seen[$0]++'
}

# cheat_tags: all the tags in use, comma separated
cheat_tags() {
  cat "$CHEATS_DIR"/*.cheat 2>/dev/null | sed -n 's/^%[[:space:]]*//p' | tr ',' '\n' |
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | sort -u | paste -sd, | sed 's/,/, /g'
}
