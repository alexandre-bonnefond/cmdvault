# cmdvault

Save important commands and multi-command recipes once and get them back from bash, tmux and rofi.
Entries are plain [navi](https://github.com/denisidoro/navi) `.cheat` files with descriptions, tags
and `<placeholders>`, kept in their own git repo. Terminal recordings (asciinema) can be linked to them.

New to it? Open `docs/quick-start.html` in a browser: short recordings of every workflow
(also playable in a terminal, e.g. `asciinema play docs/demos/01-save.cast`).

## Install

```bash
git clone <this repo> ~/git/cmdvault
~/git/cmdvault/install.sh [--with-agg] [--data-remote GIT_URL]
```

No sudo. It installs pinned releases of navi, fzf (and agg for GIFs) into `~/.local/bin`, links
`~/.local/bin/cmdvault`, and creates the cheats repo `~/git/cmdvault-cheats` (or clones it from
`--data-remote`). Then add the hooks (linux-setup already has them):

```bash
# ~/.bashrc
[ -f ~/git/cmdvault/shell/cmdvault.bash ] && source ~/git/cmdvault/shell/cmdvault.bash
# ~/.tmux.conf
source-file -q ~/git/cmdvault/tmux/cmdvault.tmux
```

and a launcher for `~/.local/bin/cmdvault rofi` (linux-setup: the cheatsheet, Super+/ or the `?` icon).

## Use

| Where | What | Does |
|---|---|---|
| bash | `save` | save the last command |
| bash | `save N` | pick among the last N commands (all preselected), saved as one recipe |
| bash | `save 'CMD'` | save CMD |
| bash | Ctrl+X s | save the line being typed, it stays on the prompt |
| bash | Ctrl+G | search the vault, the typed line is the query, the filled command replaces it (not run) |
| bash | `cv [QUERY]` | search the vault, the result lands on the next prompt |
| bash | `cv tar`, `tar` Ctrl+G | a query that is a command name also lists its tldr examples, after your entries; picking one offers to save it |
| bash | `cv --tldr CMD` | only the tldr page of CMD, its `{{args}}` become placeholders |
| bash | `cv --cheatsh QUERY` | only cheat.sh (online, community cheat sheets, `QUERY` is a command or `lang/topic`) |
| bash | `rec NAME` | record with asciinema, then save the typed commands as an entry or link an entry |
| tmux | prefix + ? | the vault in a popup, the result is pasted into the pane (not run) |
| rofi | `cmdvault rofi` | Enter asks for the placeholders and copies the command, Ctrl+P plays the recording |
| any | `cmdvault play [NAME]` | replay a recording (`asciinema play` options after NAME) |
| any | `cmdvault gif NAME` | export a recording to `recordings/NAME.gif` (agg options after NAME) |
| any | `cmdvault ls` / `edit [TAG]` / `sync` | list entries, edit a cheat file, pull --rebase and push the cheats repo |

Saving asks for the command (editable, turn what changes into `<placeholders>`), a description, tags
(the first one names the file) and, for each placeholder, its values: `a, b, c`, `!command printing
them`, or nothing to type it when used. Every save is committed in the cheats repo, never pushed.

## Cheats repo

`$CMDVAULT_DATA`, default `~/git/cmdvault-cheats`:

```
cheats/<first tag>.cheat
recordings/<name>.cast      # .gif files are ignored, cmdvault gif rebuilds them
```

Each entry has its own `%` block, because navi scopes the `$` lines to a block:

```
% docker, logs
# Follow the logs of a container
; rec: docker-logs
; added: 2026-10-28
docker logs -f --tail <lines> <container>
$ container: docker ps --format '{{.Names}}'
$ lines: printf '%s\n' 100 500 1000
```

`; ` lines are comments for navi, cmdvault keeps the linked recording and the date there. A recipe is
one command per line joined with ` && \`. Hand-written navi cheats work too.

Settings (environment): `CMDVAULT_DATA`, `CMDVAULT_AUTOCOMMIT=0` to commit yourself, `TERMINAL` for
the replay window from rofi (default urxvt).

## Notes

- Ubuntu's `tldr` (Haskell client 0.9.2) can no longer update its cache, so `cv --tldr` downloads the
  pages from tldr-pages into `~/.cache/cmdvault/tldr` (refreshed after 30 days, a command without a page
  is not asked for again for 30 days). Examples already saved in the vault are not listed twice.
- `cv` types C-x C-g into its own tmux pane to put the result on the next prompt; outside tmux it adds
  it to the history instead (press Up).
- Commands typed in `rec` are read from the history file, so commands starting with a space
  (`HISTCONTROL=ignoreboth`) are not offered.

## Tests

`tests/run.sh` checks the writer, the parser, the tldr conversion and that navi reads what is written,
against a temporary cheats repo (plus shellcheck when it is installed).

## License

MIT, see `LICENSE`.
