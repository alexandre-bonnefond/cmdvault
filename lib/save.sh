# Saving a command, or several as one recipe, as a new entry.

# recipe CMD...: the commands joined with " && \" line continuations
recipe() {
  local OUT="" CMD
  for CMD in "$@"; do
    [ -n "$OUT" ] && OUT+=$' && \\\n'
    OUT+=$CMD
  done
  printf '%s' "$OUT"
}

# values_generator "a, b, c" | "!command": the $ line command for a placeholder
values_generator() {
  local VALUES=$1 VALUE OUT="printf '%s\\n'"
  if [[ $VALUES == !* ]]; then
    printf '%s' "${VALUES:1}"
    return
  fi
  IFS=',' read -r -a LIST <<<"$VALUES"
  for VALUE in "${LIST[@]}"; do
    VALUE=$(printf '%s' "$VALUE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$VALUE" ] && OUT+=" $(printf '%q' "$VALUE")"
  done
  printf '%s' "$OUT"
}

# edit_in_editor TEXT: TEXT after editing it in $EDITOR
edit_in_editor() {
  local TMP
  TMP=$(mktemp --suffix .sh)
  printf '%s\n' "$1" >"$TMP"
  "${VISUAL:-${EDITOR:-vi}}" "$TMP" </dev/tty >/dev/tty
  cat "$TMP"
  rm -f "$TMP"
}

# cmd_save [-d DESCRIPTION] [-t TAGS] [-r RECORDING] [--] CMD...
# asks for what is not given, -d and -t together make it non-interactive
cmd_save() {
  local DESCRIPTION="" TAGS="" REC="" INTERACTIVE=1
  while [ $# -gt 0 ]; do
    case $1 in
      -d) DESCRIPTION=$2 && shift ;;
      -t) TAGS=$2 && shift ;;
      -r) REC=$2 && shift ;;
      --) shift && break ;;
      -*) die "save: unknown option $1" ;;
      *) break ;;
    esac
    shift
  done
  [ $# -gt 0 ] || die "usage: cmdvault save [-d DESCRIPTION] [-t TAGS] [-r RECORDING] -- CMD..."
  need_data
  [ -n "$DESCRIPTION" ] && [ -n "$TAGS" ] && INTERACTIVE=0
  [ $INTERACTIVE = 0 ] || { : </dev/tty; } 2>/dev/null || die "save: no terminal, pass -d and -t"

  local COMMAND
  COMMAND=$(recipe "$@")

  if [ $INTERACTIVE = 1 ]; then
    printf '\e[1mSaving to the vault\e[0m (Ctrl+C aborts). Turn the parts that change into <placeholders>.\n' >/dev/tty
    if [[ $COMMAND == *$'\n'* ]]; then
      printf '%s\n' "$COMMAND" >/dev/tty
      local ANSWER
      ANSWER=$(ask "Enter keeps it, e edits it in ${VISUAL:-${EDITOR:-vi}}: ") || die "aborted"
      [[ $ANSWER == [eE]* ]] && COMMAND=$(edit_in_editor "$COMMAND")
    else
      COMMAND=$(ask "Command: " "$COMMAND") || die "aborted"
    fi
  fi

  # navi ends a command at an empty line, and reads lines starting with % # ; $ @ as metadata
  COMMAND=$(printf '%s\n' "$COMMAND" | sed '/^[[:space:]]*$/d')
  [ -n "$COMMAND" ] || die "save: empty command"
  if printf '%s\n' "$COMMAND" | grep -q '^[%#;$@]'; then
    die "save: a line of the command starts with one of % # ; \$ @, indent it to save it"
  fi

  local EXISTING
  EXISTING=$(cheat_parse | awk -F'\t' -v cmd="$(printf '%s' "$COMMAND" | tr '\n' '\037')" '$6 == cmd { print $4 " (" $1 ")"; exit }')
  if [ -n "$EXISTING" ] && [ $INTERACTIVE = 1 ]; then
    ANSWER=$(ask "Already saved as: $EXISTING. Save it again? [y/N] ") || die "aborted"
    [[ $ANSWER == [yY]* ]] || exit 0
  fi

  while [ -z "$DESCRIPTION" ]; do
    DESCRIPTION=$(ask "Description: ") || die "aborted"
  done
  DESCRIPTION=$(printf '%s' "$DESCRIPTION" | tr '\n' ' ')

  if [ -z "$TAGS" ]; then
    local KNOWN
    KNOWN=$(cheat_tags)
    [ -n "$KNOWN" ] && printf '\e[2mTags in use: %s\e[0m\n' "$KNOWN" >/dev/tty
    TAGS=$(ask "Tags (comma separated, the first one picks the file): ") || die "aborted"
  fi
  TAGS=$(printf '%s' "$TAGS" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | paste -sd, | sed 's/,/, /g')
  [ -n "$TAGS" ] || TAGS=misc

  local VARS="" NAME VALUES
  if [ $INTERACTIVE = 1 ]; then
    while read -r NAME; do
      [ -n "$NAME" ] || continue
      VALUES=$(ask "Values for <$NAME> (a, b, c | !command | empty: typed when used): ") || die "aborted"
      [ -n "$VALUES" ] && VARS+="$NAME"$'\t'"$(values_generator "$VALUES")"$'\n'
    done < <(cheat_placeholders "$COMMAND")
  fi

  local FILE
  FILE=$(cheat_file "$TAGS")
  cheat_append "$FILE" "$TAGS" "$DESCRIPTION" "$COMMAND" "$REC" "${VARS%$'\n'}"
  vault_commit "save: $DESCRIPTION" "$FILE"
  printf 'Saved to %s\n' "${FILE#"$CMDVAULT_DATA"/}" >&2
}
