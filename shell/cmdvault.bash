# cmdvault in bash, sourced from ~/.bashrc:
#   save            save the last command
#   save N          pick some of the last N commands, saved as one recipe
#   save 'CMD'      save CMD
#   Ctrl+X s        save the line being typed (it stays on the prompt)
#   Ctrl+G          search the vault (the typed line is the query), the result replaces the line
#   cv [QUERY]      search the vault, cv --tldr CMD and cv --cheatsh QUERY search tldr and cheat.sh,
#                   the result lands on the next prompt (in tmux) or in the history (press Up)
#   rec NAME        record a terminal session with asciinema, then save or link it

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

_cmdvault_search_line() {
  local OUT
  OUT=$(_cmdvault find -- "$READLINE_LINE") && [ -n "$OUT" ] || return
  READLINE_LINE=$OUT
  READLINE_POINT=${#READLINE_LINE}
}

bind -x '"\C-g": _cmdvault_search_line'

# cv puts its result on the next prompt by typing C-x C-g into its own pane, the binding
# inserts _CMDVAULT_PENDING (pasting would run a multi-line recipe, bash only turns
# bracketed paste on once the prompt is shown)
cv() {
  local OUT
  OUT=$(_cmdvault find "$@") && [ -n "$OUT" ] || return
  if [ -n "$TMUX" ]; then
    _CMDVAULT_PENDING=$OUT
    tmux send-keys -t "$TMUX_PANE" C-x C-g
  else
    history -s -- "$OUT"
    echo "cv: press Up to get it on the prompt" >&2
  fi
}

_cmdvault_insert_pending() {
  READLINE_LINE=${READLINE_LINE:0:READLINE_POINT}$_CMDVAULT_PENDING${READLINE_LINE:READLINE_POINT}
  READLINE_POINT=$((READLINE_POINT + ${#_CMDVAULT_PENDING}))
  _CMDVAULT_PENDING=
}

bind -x '"\C-x\C-g": _cmdvault_insert_pending'

# rec NAME: record with asciinema, then save or link it (the history file gives the typed commands)
rec() {
  history -a
  HISTFILE=$HISTFILE _cmdvault rec "$@"
  history -n
}
