# cmdvault cheats

Commands and recipes saved with cmdvault (`~/git/cmdvault`).

- `cheats/<tag>.cheat`: [navi](https://github.com/denisidoro/navi) cheat files. Each entry has its own
  `% tags` header, a `# description`, optional `; rec: NAME` / `; added: DATE` metadata, the command
  (with `<placeholders>`), and `$ placeholder: command that prints the values` lines.
- `recordings/NAME.cast`: asciinema recordings linked from entries (`; rec: NAME`). GIFs are not
  committed, rebuild them with `cmdvault gif NAME`.

`cmdvault save` commits here automatically (local only). `cmdvault sync` pulls and pushes.
