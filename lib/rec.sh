# Recordings: asciinema casts in $REC_DIR, linked from entries with "; rec: NAME".

rec_file() {
  echo "$REC_DIR/$1.cast"
}

# play_in_terminal NAME: replay a recording in a new terminal window (from rofi)
play_in_terminal() {
  setsid -f "${TERMINAL:-urxvt}" -e bash -c 'asciinema play "$1"; read -rsn1 -p "Press a key to close"' _ \
    "$(rec_file "$1")" >/dev/null 2>&1 </dev/null
}

# pick_entry PROMPT: choose an entry with fzf, prints its cheat_parse line
pick_entry() {
  cheat_parse | fzf --height 50% --reverse --prompt "$1" --delimiter '\t' --with-nth '{4}  [{3}]  {6}'
}

# cmd_rec NAME: record, then link the recording to an entry or save a new entry with it
cmd_rec() {
  local NAME=${1:-}
  [[ $NAME =~ ^[A-Za-z0-9._-]+$ ]] || die "usage: rec NAME (letters, digits, . _ -)"
  need asciinema fzf
  need_data
  local CAST HISTORY BEFORE ANSWER
  CAST=$(rec_file "$NAME")
  mkdir -p "$REC_DIR"
  if [ -e "$CAST" ]; then
    ANSWER=$(ask "$NAME is already recorded, overwrite it? [y/N] ") || exit 0
    [[ $ANSWER == [yY]* ]] || exit 0
  fi

  # the commands typed during the recording are the new lines of the history file
  HISTORY=${HISTFILE:-$HOME/.bash_history}
  BEFORE=$(wc -l <"$HISTORY" 2>/dev/null || echo 0)

  printf '\e[1mRecording %s\e[0m, exit the shell (Ctrl+D) to stop.\n' "$NAME"
  asciinema rec --overwrite -q -i 2 -t "$NAME" "$CAST" || die "asciinema failed"
  [ -s "$CAST" ] || die "nothing recorded"
  vault_commit "rec: $NAME" "$CAST"
  printf 'Saved %s\n' "${CAST#"$CMDVAULT_DATA"/}"

  local ACTION
  ACTION=$(printf '%s\n' "Save a new entry with it" "Link it to an existing entry" "Keep it unlinked" |
    fzf --height 6 --reverse --no-info --prompt "$NAME: ") || exit 0

  case $ACTION in
    Save*)
      local -a TYPED
      mapfile -t TYPED < <(tail -n +$((BEFORE + 1)) "$HISTORY" 2>/dev/null | grep -vE '^#[0-9]+$|^(exit|logout)$' |
        awk '{ print NR "\t" $0 }' | tac |
        fzf --multi --height 40% --reverse --bind 'load:select-all' --delimiter '\t' --with-nth 2.. \
          --header 'Commands typed during the recording · Tab: unselect/select · Enter: save' |
        sort -n | cut -f2-)
      if [ ${#TYPED[@]} -eq 0 ] || [ -z "${TYPED[0]}" ]; then
        TYPED=("$(ask "Command: ")") || exit 0
      fi
      cmd_save -r "$NAME" -- "${TYPED[@]}"
      ;;
    Link*)
      local ROW FILE LINE
      ROW=$(pick_entry "Link $NAME to: ") || exit 0
      IFS=$'\t' read -r FILE LINE _ <<<"$ROW"
      cheat_set_rec "$FILE" "$LINE" "$NAME"
      vault_commit "rec: link $NAME" "$FILE"
      printf 'Linked to %s\n' "$(cut -f4 <<<"$ROW")"
      ;;
  esac
}

# cmd_play [NAME] [ASCIINEMA PLAY OPTION...]
cmd_play() {
  need asciinema
  local NAME=""
  if [ $# -gt 0 ] && [[ $1 != -* ]]; then
    NAME=$1
    shift
  fi
  if [ -z "$NAME" ]; then
    need fzf
    # recording names, with the descriptions of the entries linking them
    NAME=$(
      {
        cheat_parse | awk -F'\t' '$5 != "" { print $5 "\t" $4 }'
        find "$REC_DIR" -maxdepth 1 -name '*.cast' -printf '%f\n' 2>/dev/null | sed 's/\.cast$//'
      } | awk -F'\t' '!seen[$1]++' | fzf --height 40% --reverse --prompt "Play: " --delimiter '\t' | cut -f1
    ) || exit 0
  fi
  [ -s "$(rec_file "$NAME")" ] || die "no recording $NAME in $REC_DIR"
  asciinema play "$@" "$(rec_file "$NAME")"
}

# cmd_gif NAME [AGG OPTION...]: NAME.gif next to the cast (not committed)
cmd_gif() {
  local NAME=${1:-}
  [ -n "$NAME" ] || die "usage: cmdvault gif NAME [agg options]"
  shift
  need agg
  [ -s "$(rec_file "$NAME")" ] || die "no recording $NAME in $REC_DIR"
  agg "$@" "$(rec_file "$NAME")" "$REC_DIR/$NAME.gif" && echo "$REC_DIR/$NAME.gif"
}
