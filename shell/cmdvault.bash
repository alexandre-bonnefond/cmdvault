# cmdvault in bash, sourced from ~/.bashrc:
#   save            save the last command
#   save N          pick some of the last N commands, saved as one recipe
#   save 'CMD'      save CMD
#   Ctrl+X s        save the line being typed (it stays on the prompt)

[[ $- == *i* ]] || return 0

CMDVAULT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

_cmdvault() {
  "$CMDVAULT_ROOT/bin/cmdvault" "$@"
}

# _cmdvault_history N: the last N commands, oldest first, one per line, without cmdvault's own
_cmdvault_history() {
  fc -ln -$(($1 + 50)) -1 2>/dev/null | sed 's/^[[:space:]]*//' |
    grep -vE '^(save|rec|cv|cmdvault)([[:space:]]|$)' | tail -n "$1"
}

save() {
  local -a PICKED
  if [ $# -eq 0 ]; then
    mapfile -t PICKED < <(_cmdvault_history 1)
  elif [ $# -eq 1 ] && [[ $1 =~ ^[0-9]+$ ]]; then
    # newest first, all selected, saved back in the order they were run
    mapfile -t PICKED < <(_cmdvault_history "$1" | awk '{ print NR "\t" $0 }' | tac |
      fzf --multi --height 40% --reverse --bind 'load:select-all' --delimiter '\t' --with-nth 2.. \
        --header 'Tab: unselect/select · Enter: save the selected commands as one recipe' |
      sort -n | cut -f2-)
  else
    PICKED=("$*")
  fi
  [ ${#PICKED[@]} -gt 0 ] && [ -n "${PICKED[0]}" ] || {
    echo "save: nothing to save" >&2
    return 1
  }
  _cmdvault save -- "${PICKED[@]}"
}

# _cmdvault_cooked CMD...: run CMD from a bind -x widget with the terminal in its normal mode,
# readline only echoes what is typed when it starts with echo on
_cmdvault_cooked() {
  local TTY_STATE
  TTY_STATE=$(stty -g)
  stty sane
  "$@"
  stty "$TTY_STATE"
}

_cmdvault_save_line() {
  [ -n "$READLINE_LINE" ] && _cmdvault_cooked _cmdvault save -- "$READLINE_LINE"
}

bind -x '"\C-xs": _cmdvault_save_line'
