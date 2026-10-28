# Looking after the cheats repo: ls, edit, sync.

cmd_ls() {
  need_data
  cheat_parse | awk -F'\t' '{
    split($6, lines, "\037")
    more = (length(lines) > 1) ? "  \033[2m(+" length(lines) - 1 " lines)\033[0m" : ""
    rec = ($5 != "") ? "  \033[2m▶ " $5 "\033[0m" : ""
    printf "\033[1m%s\033[0m  \033[36m%s\033[0m%s\n    %s%s\n", $4, $3, rec, lines[1], more
  }'
}

# cmd_edit [TAG]: edit a cheat file in $EDITOR, commit it when it changed
cmd_edit() {
  need_data
  local FILE
  if [ -n "${1:-}" ]; then
    FILE=$(cheat_file "$1")
  else
    need fzf
    FILE=$(find "$CHEATS_DIR" -name '*.cheat' -printf '%f\n' | sort | fzf --height 40% --reverse --prompt "Edit: ") || exit 0
    FILE="$CHEATS_DIR/$FILE"
  fi
  "${VISUAL:-${EDITOR:-vi}}" "$FILE"
  [ -e "$FILE" ] || exit 0
  if [ -n "$(git -C "$CMDVAULT_DATA" status --porcelain -- "$FILE" 2>/dev/null)" ]; then
    vault_commit "edit: $(basename "$FILE")" "$FILE"
  fi
}

cmd_sync() {
  [ -n "$(git -C "$CMDVAULT_DATA" remote 2>/dev/null)" ] ||
    die "the cheats repo has no remote, add one with: git -C $CMDVAULT_DATA remote add origin URL"
  git -C "$CMDVAULT_DATA" pull --rebase && git -C "$CMDVAULT_DATA" push
}
