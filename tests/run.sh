#!/usr/bin/env bash

# Tests of the non-interactive parts against a temporary cheats repo: ./tests/run.sh

CMDVAULT_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export CMDVAULT_DATA="$TMP/data"
mkdir -p "$CMDVAULT_DATA/cheats" "$CMDVAULT_DATA/recordings"
git -C "$CMDVAULT_DATA" init -q
git -C "$CMDVAULT_DATA" config user.email test@example.com
git -C "$CMDVAULT_DATA" config user.name test
CMDVAULT="$CMDVAULT_ROOT/bin/cmdvault"

for LIB in "$CMDVAULT_ROOT"/lib/*.sh; do
  # shellcheck source=/dev/null
  source "$LIB"
done

FAILED=0
check() { # check NAME EXPECTED ACTUAL
  if [ "$2" == "$3" ]; then
    echo "ok   $1"
  else
    echo "FAIL $1"
    diff <(printf '%s\n' "$2") <(printf '%s\n' "$3") | sed 's/^/     /'
    FAILED=1
  fi
}

# --- writing and parsing

check "cheat_file uses the first tag" "$CHEATS_DIR/docker.cheat" "$(cheat_file "Docker , logs")"
check "cheat_file sanitizes" "$CHEATS_DIR/my-tag.cheat" "$(cheat_file "my tag/, x")"
check "placeholders, once each, in order" $'lines\ncontainer' "$(cheat_placeholders 'docker logs --tail <lines> <container> <lines> 2>&1 >out <in')"
check "values list" "printf '%s\n' 100 a\\ b x\\&y" "$(values_generator ' 100, a b ,, x&y')"
check "values command" "docker ps --format x" "$(values_generator '!docker ps --format x')"
check "recipe" $'cd /tmp && \\\nls -la' "$(recipe 'cd /tmp' 'ls -la')"

"$CMDVAULT" save -d "Follow the logs" -t "docker, logs" -- 'docker logs -f <container>' 2>/dev/null
"$CMDVAULT" save -d "Rebuild and restart" -t "docker" -- 'docker compose build' 'docker compose up -d' 2>/dev/null
cat >>"$CHEATS_DIR/docker.cheat" <<'EOF'

% docker
# Shell in a container
docker exec -it <container> <shell>
$ container: docker ps --format '{{.Names}}' --- --column 1
$ shell: printf '%s\n' bash sh
EOF

PARSED=$(cheat_parse | cut -f2- | tr '\037' '|')
check "parse" "2	docker, logs	Follow the logs		docker logs -f <container>
7	docker	Rebuild and restart		docker compose build && \\|docker compose up -d
13	docker	Shell in a container		docker exec -it <container> <shell>" "$PARSED"
check "vars of an entry, without --- options" $'container\tdocker ps --format \'{{.Names}}\'\nshell\tprintf \'%s\\n\' bash sh' "$(cheat_vars "$CHEATS_DIR/docker.cheat" 13)"
check "no vars leak from another entry" "" "$(cheat_vars "$CHEATS_DIR/docker.cheat" 2)"
check "tags" "docker, logs" "$(cheat_tags)"
check "commits" "save: Rebuild and restart
save: Follow the logs" "$(git -C "$CMDVAULT_DATA" log --format=%s)"

cheat_set_rec "$CHEATS_DIR/docker.cheat" 7 old
cheat_set_rec "$CHEATS_DIR/docker.cheat" 7 compose-demo
check "link a recording, replacing the previous one" "compose-demo" "$(cheat_parse | awk -F'\t' '$2 == 7 { print $5 }')"
check "one rec line" "1" "$(grep -c '^; rec:' "$CHEATS_DIR/docker.cheat")"

if "$CMDVAULT" save -d x -t y -- $'echo a\n# comment' 2>/dev/null; then
  check "reject lines navi reads as metadata" "failure" "success"
else
  check "reject lines navi reads as metadata" "" ""
fi

read_entry "$(cheat_parse | awk -F'\t' '$2 == 2')"
check "read an entry with an empty recording" "docker, logs|Follow the logs||docker logs -f <container>" "$TAGS|$DESCRIPTION|$REC|$COMMAND"
check "pango escape" "a &amp;&amp; b &lt;x&gt;" "$(escape 'a && b <x>')"

# --- tldr pages

TLDR_PAGE='# tar

> Archiving utility.

- [c]reate a g[z]ipped archive:

`tar czf {{path/to/target.tar.gz}} {{path/to/file1 path/to/file2 ...}}`

- E[x]tract into a `directory`:

`tar {{[-x|--extract]}} {{path/to/directory}} {{path/to/directory}}`'
check "tldr page to cheat" "% tldr, tar

# Create a gzipped archive
tar czf <path_to_target_tar_gz> <path_to_file1_path_to_file2>

# Extract into a directory
tar -x <path_to_directory> <path_to_directory>" "$(tldr_to_cheat tar <<<"$TLDR_PAGE")"

# the fixture page as the cached one, and its second example saved in the vault
TLDR_CACHE="$TMP/tldr"
mkdir -p "$TLDR_CACHE/linux"
printf '%s\n' "$TLDR_PAGE" >"$TLDR_CACHE/linux/tar.md"
cmd_save -d "Extract here" -t "tar" -- 'tar -x <path_to_directory> <path_to_directory>' 2>/dev/null
mkdir "$TMP/tldrdir"
tldr_cheat tar "$TMP/tldrdir"
check "tldr examples leave out the saved ones" "% tldr, tar

# Create a gzipped archive
tar czf <path_to_target_tar_gz> <path_to_file1_path_to_file2>" "$(cat "$TMP/tldrdir/tldr.cheat")"
check "picked from tldr" "tar czf <path_to_target_tar_gz> <path_to_file1_path_to_file2>" \
  "$(picked_template 'tar czf a.tgz x y' "$TMP/tldrdir")"
check "not picked from tldr" "" "$(picked_template 'tar xf a.tgz' "$TMP/tldrdir")"
check "picked from the vault, a recipe" $'docker compose build && \\\x1fdocker compose up -d' \
  "$(picked_template $'docker compose build && \\\ndocker compose up -d' "$CHEATS_DIR")"
mkdir -p "$TLDR_CACHE/missing" && touch "$TLDR_CACHE/missing/nosuchcmd"
check "a missing page is not fetched again" "1" "$(tldr_page nosuchcmd >/dev/null; echo $?)"

# --- navi reads what we write

if command -v navi >/dev/null; then
  export NAVI_CONFIG="$CMDVAULT_ROOT/config/navi.yaml"
  check "navi finds a recipe" $'docker compose build && \\\ndocker compose up -d' \
    "$(navi --print --best-match --path "$CHEATS_DIR" --query 'rebuild and restart' </dev/null 2>/dev/null)"
fi

if command -v shellcheck >/dev/null; then
  shellcheck -x -s bash "$CMDVAULT_ROOT"/bin/cmdvault "$CMDVAULT_ROOT"/lib/*.sh "$CMDVAULT_ROOT"/shell/*.bash \
    "$CMDVAULT_ROOT"/install.sh "$0" && echo "ok   shellcheck" || FAILED=1
fi

exit $FAILED
