# The rofi menu (cheatsheet entry of linux-setup): Enter asks for the placeholders and copies
# the command to the clipboard, Ctrl+P plays the linked recording.

# rofi_menu PROMPT [ROFI OPTION...]: rofi -dmenu with the look of the linux-setup menus
rofi_menu() {
  local THEME=()
  [ -f "$ROFI_THEME" ] && THEME=(-theme "$ROFI_THEME")
  rofi -dmenu -i -p "$1" "${THEME[@]}" -theme-str 'window { width: 1100px; }' \
    -theme-str 'listview { lines: 18; spacing: 2px; }' -theme-str 'element { padding: 5px 14px; }' "${@:2}"
}

# rofi_fill FILE LINE COMMAND: COMMAND with its placeholders asked with rofi,
# the values of the $ lines are offered, typing something else is allowed
rofi_fill() {
  local FILE=$1 LINE=$2 COMMAND=$3 NAME GENERATOR VALUE
  local -A GENERATORS=()
  while IFS=$'\t' read -r NAME GENERATOR; do
    GENERATORS[$NAME]=$GENERATOR
  done < <(cheat_vars "$FILE" "$LINE")

  while read -r NAME; do
    [ -n "$NAME" ] || continue
    GENERATOR=${GENERATORS[$NAME]:-}
    VALUE=$({ [ -n "$GENERATOR" ] && bash -c "$GENERATOR" </dev/null 2>/dev/null; } |
      rofi_menu "$NAME" -mesg "$(escape "$COMMAND")   ·   Ctrl+Enter: use what is typed") || return 1
    COMMAND=${COMMAND//<$NAME>/$VALUE}
    # later $ lines can use the earlier values, as in navi
    [[ $NAME =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && export "$NAME=$VALUE"
  done < <(cheat_placeholders "$COMMAND")
  printf '%s' "$COMMAND"
}

cmd_rofi() {
  need rofi xclip
  need_data
  local -a ROWS
  mapfile -t ROWS < <(cheat_parse)
  [ ${#ROWS[@]} -gt 0 ] || die "the vault is empty"

  local ENTRIES="" ROW FILE LINE TAGS DESCRIPTION REC COMMAND SHOWN MARK
  for ROW in "${ROWS[@]}"; do
    read_entry "$ROW"
    SHOWN=${COMMAND//\\$'\037'/}
    SHOWN=${SHOWN//$'\037'/ ⏎ }
    MARK=""
    [ -n "$REC" ] && MARK=" <span alpha='70%'>▶</span>"
    ENTRIES+="<b>$(escape "$DESCRIPTION")</b>$MARK  <span alpha='55%'>$(escape "$TAGS")</span>  "
    ENTRIES+="<span font_desc='DejaVu Sans Mono 9' alpha='75%'>$(escape "${SHOWN:0:100}")</span>"$'\n'
  done

  local CHOICE STATUS
  CHOICE=$(printf '%s' "$ENTRIES" | rofi_menu "Cmd vault" -markup-rows -format i -no-custom \
    -mesg "↵ fill and copy   ·   Ctrl+P play the recording (▶)   ·   type to search" \
    -kb-row-up Up -kb-custom-1 Control+p)
  STATUS=$?
  [ -n "$CHOICE" ] || exit 0

  read_entry "${ROWS[$CHOICE]}"
  COMMAND=${COMMAND//$'\037'/$'\n'}

  if [ "$STATUS" = 10 ]; then
    if [ -n "$REC" ]; then
      play_in_terminal "$REC"
    else
      notify-send -a cmdvault "No recording" "$(escape "$DESCRIPTION")"
    fi
    exit 0
  fi

  COMMAND=$(rofi_fill "$FILE" "$LINE" "$COMMAND") || exit 0
  printf '%s' "$COMMAND" | xclip -selection clipboard
  printf '%s' "$COMMAND" | xclip -selection primary
  notify-send -a cmdvault "Copied to the clipboard" "$(escape "$COMMAND")"
}
