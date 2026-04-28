#!/usr/bin/env bash
# Install this repo's skills into selected local agent skill folders.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
DRY_RUN=false
BACKUP=true
declare -a PROVIDER_ARGS=()
declare -a SELECTED_PROVIDERS=()

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  RESET=$'\033[0m'
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  CYAN=$'\033[36m'
else
  RESET=""
  BOLD=""
  DIM=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  CYAN=""
fi

usage() {
  cat <<EOF
Usage: ./setup.sh [OPTIONS]

Installs every top-level skill directory from this repo into one or more
local agent skill folders.

Providers:
  claude, claude-code   ${CLAUDE_HOME}/skills
  codex                 ${CODEX_HOME}/skills

Options:
  -p, --provider <name>       Install to one provider. Can be repeated
      --provider=<name>       Same as --provider <name>
      --providers <list>      Comma-separated providers, e.g. claude,codex
      --providers=<list>      Same as --providers <list>
      --dry-run              Print what would be installed without changing files
      --no-backup            Replace existing installed skills without backups
  -h, --help                 Show this help

If no provider is passed, the script opens an interactive checklist.

Examples:
  ./setup.sh
  ./setup.sh --dry-run --providers claude,codex
  ./setup.sh --provider claude --provider codex
  CLAUDE_HOME=/path/to/.claude CODEX_HOME=/path/to/.codex ./setup.sh
EOF
}

title() { printf "%s%s%s\n" "$BOLD$BLUE" "$1" "$RESET"; }
section() { printf "%s%s%s\n" "$BOLD$CYAN" "$1" "$RESET"; }
info() { printf "  %s%s%s\n" "$DIM" "$1" "$RESET"; }
ok() { printf "  %s✓%s %s\n" "$GREEN" "$RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$YELLOW" "$RESET" "$1"; }
error() { printf "  %sx%s %s\n" "$RED" "$RESET" "$1" >&2; }

provider_label() {
  case "$1" in
    claude) printf "Claude Code" ;;
    codex) printf "Codex" ;;
  esac
}

provider_dest_root() {
  case "$1" in
    claude) printf "%s/skills" "$CLAUDE_HOME" ;;
    codex) printf "%s/skills" "$CODEX_HOME" ;;
  esac
}

provider_restart_message() {
  case "$1" in
    claude) printf "Open a new Claude Code session so skill discovery refreshes." ;;
    codex) printf "Restart Codex to pick up new skills." ;;
  esac
}

normalize_provider() {
  local provider="$1"

  case "$provider" in
    claude|claude-code|claude_code|claudecode)
      printf "claude"
      ;;
    codex)
      printf "codex"
      ;;
    *)
      error "Unknown provider: $provider"
      info "Supported providers: claude, codex"
      exit 1
      ;;
  esac
}

add_provider() {
  local provider
  provider="$(normalize_provider "$1")"

  if [ "${#SELECTED_PROVIDERS[@]}" -gt 0 ]; then
    for selected in "${SELECTED_PROVIDERS[@]}"; do
      if [ "$selected" = "$provider" ]; then
        return
      fi
    done
  fi

  SELECTED_PROVIDERS+=("$provider")
}

add_provider_list() {
  local list="$1"
  local old_ifs="$IFS"
  local provider

  IFS=","
  for provider in $list; do
    provider="${provider#"${provider%%[![:space:]]*}"}"
    provider="${provider%"${provider##*[![:space:]]}"}"
    if [ -n "$provider" ]; then
      PROVIDER_ARGS+=("$provider")
    fi
  done
  IFS="$old_ifs"
}

select_providers_interactively() {
  if [ -t 0 ] && [ -t 1 ]; then
    select_providers_with_checklist
    return
  fi

  select_providers_by_prompt
}

select_providers_by_prompt() {
  local answer
  local old_ifs
  local token

  title "Install Local Agent Skills"
  section "Select providers"
  echo "  1) Claude Code ($(provider_dest_root claude))"
  echo "  2) Codex ($(provider_dest_root codex))"
  echo ""
  printf "Enter choices (e.g. 1,2 or all): "

  if ! IFS= read -r answer; then
    error "No provider selection received."
    exit 1
  fi

  case "$answer" in
    all|ALL|All)
      add_provider claude
      add_provider codex
      return
      ;;
  esac

  old_ifs="$IFS"
  IFS=", "
  for token in $answer; do
    case "$token" in
      1) add_provider claude ;;
      2) add_provider codex ;;
      "") ;;
      *) add_provider "$token" ;;
    esac
  done
  IFS="$old_ifs"

  if [ "${#SELECTED_PROVIDERS[@]}" -eq 0 ]; then
    error "No providers selected."
    exit 1
  fi
}

select_providers_with_checklist() {
  local selection_file
  local picker_script
  local status
  local provider

  if ! command -v python3 >/dev/null 2>&1; then
    warn "python3 is not available; falling back to typed selection"
    select_providers_by_prompt
    return
  fi

  selection_file="$(mktemp "${TMPDIR:-/tmp}/skill-providers.XXXXXX")"
  picker_script="$(mktemp "${TMPDIR:-/tmp}/skill-picker.XXXXXX.py")"

  cat > "$picker_script" <<'PY'
import curses
import sys

output_path, claude_home, codex_home = sys.argv[1:4]
providers = [
    ("claude", "Claude Code", f"{claude_home}/skills"),
    ("codex", "Codex", f"{codex_home}/skills"),
]
checked = [False] * len(providers)
current = 0


def addstr(stdscr, row, col, text, attr=0):
    height, width = stdscr.getmaxyx()
    if row >= height or col >= width:
        return
    stdscr.addstr(row, col, text[: max(0, width - col - 1)], attr)


def run(stdscr):
    global current

    curses.curs_set(0)
    if curses.has_colors():
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_CYAN, -1)
        curses.init_pair(2, curses.COLOR_GREEN, -1)
        curses.init_pair(3, curses.COLOR_YELLOW, -1)
        accent = curses.color_pair(1) | curses.A_BOLD
        selected = curses.color_pair(2) | curses.A_BOLD
        hint = curses.A_DIM
    else:
        accent = curses.A_BOLD
        selected = curses.A_BOLD
        hint = curses.A_DIM

    while True:
        stdscr.erase()
        addstr(stdscr, 0, 0, "Install Local Agent Skills", accent)
        addstr(stdscr, 1, 0, "Up/Down: move  Space: select  Enter: install  q: cancel", hint)

        row = 3
        for index, (_, label, path) in enumerate(providers):
            pointer = ">" if index == current else " "
            marker = "[x]" if checked[index] else "[ ]"
            attr = selected if checked[index] else curses.A_NORMAL
            if index == current:
                attr |= curses.A_REVERSE
            addstr(stdscr, row, 2, f"{pointer} {marker} {label}", attr)
            addstr(stdscr, row + 1, 6, path, hint)
            row += 2

        stdscr.refresh()
        key = stdscr.getch()

        if key in (curses.KEY_UP, ord("k")):
            current = (current - 1) % len(providers)
        elif key in (curses.KEY_DOWN, ord("j")):
            current = (current + 1) % len(providers)
        elif key == ord(" "):
            checked[current] = not checked[current]
        elif key in (curses.KEY_ENTER, 10, 13):
            break
        elif key in (ord("q"), ord("Q")):
            raise KeyboardInterrupt


try:
    curses.wrapper(run)
except KeyboardInterrupt:
    sys.exit(130)

selected_providers = [provider for index, (provider, _, _) in enumerate(providers) if checked[index]]
if not selected_providers:
    sys.exit(2)

with open(output_path, "w", encoding="utf-8") as output:
    output.write("\n".join(selected_providers))
    output.write("\n")
PY

  set +e
  python3 "$picker_script" "$selection_file" "$CLAUDE_HOME" "$CODEX_HOME" </dev/tty >/dev/tty
  status=$?
  set -e

  rm -f "$picker_script"

  if [ "$status" -eq 130 ]; then
    rm -f "$selection_file"
    error "Cancelled."
    exit 130
  fi

  if [ "$status" -eq 2 ]; then
    rm -f "$selection_file"
    error "No providers selected."
    exit 1
  fi

  if [ "$status" -ne 0 ]; then
    rm -f "$selection_file"
    warn "Interactive checklist unavailable; falling back to typed selection"
    select_providers_by_prompt
    return
  fi

  while IFS= read -r provider; do
    if [ -n "$provider" ]; then
      add_provider "$provider"
    fi
  done < "$selection_file"

  rm -f "$selection_file"

  if [ "${#SELECTED_PROVIDERS[@]}" -eq 0 ]; then
    error "No providers selected."
    exit 1
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -p|--provider)
      if [ "$#" -lt 2 ]; then
        printf "%s requires a provider name.\n" "$1" >&2
        exit 1
      fi
      PROVIDER_ARGS+=("$2")
      shift
      ;;
    --provider=*)
      PROVIDER_ARGS+=("${1#*=}")
      ;;
    --providers)
      if [ "$#" -lt 2 ]; then
        printf "%s requires a comma-separated provider list.\n" "$1" >&2
        exit 1
      fi
      add_provider_list "$2"
      shift
      ;;
    --providers=*)
      add_provider_list "${1#*=}"
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --no-backup)
      BACKUP=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf "Unknown option: %s\n\n" "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ "${#PROVIDER_ARGS[@]}" -gt 0 ]; then
  for provider_arg in "${PROVIDER_ARGS[@]}"; do
    add_provider "$provider_arg"
  done
else
  select_providers_interactively
fi

copy_dir() {
  local src="$1"
  local dest="$2"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$src/" "$dest/"
  else
    mkdir -p "$dest"
    cp -R "$src/." "$dest/"
  fi
}

make_scripts_executable() {
  local dir="$1"

  while IFS= read -r script; do
    chmod +x "$script"
  done < <(find "$dir" -type f -name "*.sh")
}

backup_path() {
  local dest="$1"
  local timestamp="$2"
  local candidate="$dest.backup.$timestamp"
  local suffix=1

  while [ -e "$candidate" ]; do
    candidate="$dest.backup.$timestamp.$suffix"
    suffix=$((suffix + 1))
  done

  printf "%s" "$candidate"
}

install_for_provider() {
  local provider="$1"
  local dest_root
  local timestamp
  local -a installed=()

  dest_root="$(provider_dest_root "$provider")"
  timestamp="$(date +%Y%m%d%H%M%S)"

  section "Installing for $(provider_label "$provider")"
  printf "  %s%-12s%s %s\n" "$DIM" "Source" "$RESET" "$SCRIPT_DIR"
  printf "  %s%-12s%s %s\n" "$DIM" "Destination" "$RESET" "$dest_root"

  if $DRY_RUN; then
    warn "Dry run only; no files will be changed"
  else
    mkdir -p "$dest_root"
  fi

  echo ""

  for skill in "${skills[@]}"; do
    src="$SCRIPT_DIR/$skill"
    dest="$dest_root/$skill"

    if $DRY_RUN; then
      if [ -e "$dest" ]; then
        if $BACKUP; then
          warn "Would back up $dest"
          info "Backup: $(backup_path "$dest" "$timestamp")"
        else
          warn "Would replace $dest without a backup"
        fi
      fi
      info "Would install $skill"
      installed+=("$skill")
      continue
    fi

    if [ -e "$dest" ]; then
      if $BACKUP; then
        backup_dest="$(backup_path "$dest" "$timestamp")"
        mv "$dest" "$backup_dest"
        warn "Backed up existing $skill"
        info "Backup: $(basename "$backup_dest")"
      else
        rm -rf "$dest"
      fi
    fi

    mkdir -p "$dest"
    copy_dir "$src" "$dest"
    make_scripts_executable "$dest"
    ok "Installed $skill"
    installed+=("$skill")
  done

  echo ""
  ok "Installed ${#installed[@]} skills for $(provider_label "$provider")"
  printf "  %s%s%s\n" "$DIM" "${installed[*]}" "$RESET"
  echo ""
}

declare -a skills=()
for skill_dir in "$SCRIPT_DIR"/*; do
  if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
    skills+=("$(basename "$skill_dir")")
  fi
done

if [ "${#skills[@]}" -eq 0 ]; then
  error "No top-level skill directories with SKILL.md found in $SCRIPT_DIR"
  exit 1
fi

title "Install Local Agent Skills"
section "Selected providers"
for provider in "${SELECTED_PROVIDERS[@]}"; do
  printf "  %s%-12s%s %s\n" "$BOLD" "$(provider_label "$provider")" "$RESET" "$(provider_dest_root "$provider")"
done
echo ""

for provider in "${SELECTED_PROVIDERS[@]}"; do
  install_for_provider "$provider"
done

section "Next steps"
for provider in "${SELECTED_PROVIDERS[@]}"; do
  info "$(provider_restart_message "$provider")"
done
