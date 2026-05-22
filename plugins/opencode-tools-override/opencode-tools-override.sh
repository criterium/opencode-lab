#!/usr/bin/env bash
set -euo pipefail

# ─── Config ─────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_SRC="$SCRIPT_DIR/opencode-tools-override.ts"
PLUGIN_DEST="$HOME/.config/opencode/plugin/opencode-tools-override.ts"
PLUGIN_DIR="$HOME/.config/opencode/plugin"
OVERRIDES_DIR="$SCRIPT_DIR/overrides"
TOOLS_REF="$SCRIPT_DIR/ref"
TOOLS_LAST="$SCRIPT_DIR/last"

# ─── Colors (if terminal) ───────────────────────────────────────────────────
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[1;33m'
  RED=$'\033[0;31m'
  CYAN=$'\033[0;36m'
  GRAY=$'\033[0;90m'
  NC=$'\033[0m'
else
  BOLD=''; GREEN=''; YELLOW=''; RED=''; CYAN=''; GRAY=''; NC=''
fi

info()  { echo -e "${GREEN}▸${NC} $*"; }
warn()  { echo -e "${YELLOW}▸ WARN${NC} $*" >&2; }
err()   { echo -e "${RED}▸ ERROR${NC} $*" >&2; }
header(){ echo -e "${BOLD}$*${NC}"; }
dim()   { echo -e "${GRAY}$*${NC}"; }

# ─── Helpers ────────────────────────────────────────────────────────────────

current_version() {
  opencode --version 2>/dev/null || echo "?"
}

check_plugin_src() {
  if [[ ! -f "$PLUGIN_SRC" ]]; then
    err "Cannot find $PLUGIN_SRC"
    err "Run this script from plugins/opencode-tools-override/"
    exit 1
  fi
}

plugin_installed() {
  [[ -L "$PLUGIN_DEST" ]] || [[ -f "$PLUGIN_DEST" ]]
}

plugin_valid() {
  if [[ -L "$PLUGIN_DEST" ]]; then
    local target
    target="$(readlink "$PLUGIN_DEST")"
    [[ -f "$target" ]]
  elif [[ -f "$PLUGIN_DEST" ]]; then
    true
  else
    false
  fi
}

count_overrides() {
  if [[ -d "$OVERRIDES_DIR" ]]; then
    find "$OVERRIDES_DIR" -maxdepth 1 -name '*.txt' 2>/dev/null | wc -l
  else
    echo 0
  fi
}

read_version_file() {
  local dir="$1"
  local f="$dir/.version"
  if [[ -f "$f" ]]; then
    cat "$f"
  else
    echo "-"
  fi
}

# ─── Download helper ──────────────────────────────────────────────────────────
# Shared logic used by capture() and fetch() to download tool descriptions
# from the OpenCode GitHub repository via the Contents API.
_download_tools() {
  local dest="$1" tag="$2"
  local api_base="https://api.github.com/repos/anomalyco/opencode/contents/packages/opencode/src/tool"
  local api_url="$api_base?ref=$tag"

  if ! command -v curl &>/dev/null; then
    err "curl is required. Install it with: sudo apt install curl"
    exit 1
  fi
  if ! command -v jq &>/dev/null; then
    err "jq is required. Install it with: sudo apt install jq"
    exit 1
  fi

  mkdir -p "$dest"

  local tmp_json
  tmp_json="$(mktemp)"

  if ! curl -sfL "$api_url" -o "$tmp_json"; then
    err "Network error querying GitHub API."
    rm -f "$tmp_json"
    exit 1
  fi

  # .txt files at the root of tool/
  jq -r '.[] | select(.type == "file" and (.name | endswith(".txt"))) | "\(.name)\t\(.download_url)"' "$tmp_json" | \
    while IFS=$'\t' read -r name url; do
      curl -sfL "$url" -o "$dest/$name"
    done

  # Subdirectories (shell/)
  jq -r '.[] | select(.type == "dir") | .name' "$tmp_json" | while read -r dir; do
    local sub_url="$api_base/$dir?ref=$tag"
    local sub_json
    sub_json="$(mktemp)"
    if curl -sfL "$sub_url" -o "$sub_json"; then
      mkdir -p "$dest/$dir"
      jq -r '.[] | select(.type == "file" and (.name | endswith(".txt"))) | "\(.name)\t\(.download_url)"' "$sub_json" | \
        while IFS=$'\t' read -r name url; do
          curl -sfL "$url" -o "$dest/$dir/$name"
        done
    fi
    rm -f "$sub_json"
  done

  # Verify download: warn if expected vs actual mismatch
  local expected
  expected="$(jq -r '[.[] | select(.type == "file" and (.name | endswith(".txt")))] | length' "$tmp_json" 2>/dev/null || echo 0)"
  local actual
  actual="$(find "$dest" -maxdepth 1 -name '*.txt' -type f 2>/dev/null | wc -l)"

  if [[ "$actual" -ne "$expected" ]] && [[ "$expected" -ne 0 ]]; then
    warn "Download mismatch: expected $expected top-level files, got $actual."
  fi

  rm -f "$tmp_json"
}

# ─── Commands ───────────────────────────────────────────────────────────────

install() {
  check_plugin_src

  # Create plugin directory
  mkdir -p "$PLUGIN_DIR"

  # Migrate: if a physical file exists (old install), remove it and switch to symlink
  if [[ -f "$PLUGIN_DEST" ]] && [[ ! -L "$PLUGIN_DEST" ]]; then
    rm -f "$PLUGIN_DEST"
    warn "Migrated: physical file removed, now symlink."
  fi

  # Warn if symlink already exists
  if [[ -L "$PLUGIN_DEST" ]]; then
    warn "Symlink already exists. It will be re-created with the current path."
  fi

  # Create/update symlink
  ln -sf "$PLUGIN_SRC" "$PLUGIN_DEST"
  info "Plugin symlink created: $PLUGIN_DEST → $PLUGIN_SRC"

  # Create overrides directory in the repo if it doesn't exist
  mkdir -p "$OVERRIDES_DIR"

  if [[ $(count_overrides) -eq 0 ]]; then
    dim "  (empty — add .txt files for each tool you want to override)"
  fi

  echo ""
  info "${BOLD}Installation complete.${NC} Restart OpenCode to load the plugin."
}

uninstall() {
  local had_plugin=false

  if [[ -L "$PLUGIN_DEST" ]] || [[ -f "$PLUGIN_DEST" ]]; then
    had_plugin=true
    rm -f "$PLUGIN_DEST"
    info "Symlink removed: $PLUGIN_DEST"
  else
    warn "No plugin installed at $PLUGIN_DEST"
  fi

  # Clean up plugin directory if empty
  rmdir "$PLUGIN_DIR" 2>/dev/null || true

  if $had_plugin; then
    echo ""
    info "${BOLD}Plugin uninstalled.${NC} Restart OpenCode to unload it."
  fi
}

init() {
  info "Initializing opencode-tools-override environment ..."
  echo ""

  # Create overrides directory if it doesn't exist
  mkdir -p "$OVERRIDES_DIR"
  info "Overrides directory: $OVERRIDES_DIR"

  # Create last/ for future fetch
  mkdir -p "$TOOLS_LAST"
  info "Downloads directory:  $TOOLS_LAST"

  # Capture descriptions for the current version
  echo ""
  capture

  echo ""
  info "${BOLD}Initialization complete.${NC}"
  info "Run 'install' to install the plugin, or 'status' to check state."
}

capture() {
  local version
  version="$(current_version)"

  if [[ "$version" == "?" ]]; then
    err "Cannot determine OpenCode version."
    err "Make sure 'opencode --version' works."
    exit 1
  fi

  local tag="v$version"
  info "Downloading tool descriptions from OpenCode $tag ..."

  # Verify the tag exists on GitHub
  if curl -sfI "https://github.com/anomalyco/opencode/releases/tag/$tag" &>/dev/null; then
    _download_tools "$TOOLS_REF" "$tag"
  else
    err "Tag $tag not found in the OpenCode repository."
    err "Is the installed version correct ($version)?"
    exit 1
  fi

  echo "$version" > "$TOOLS_REF/.version"

  local count
  count="$(find "$TOOLS_REF" -name '*.txt' | wc -l)"
  info "ref updated: $count descriptions, version $version"
  dim "  $TOOLS_REF/"
}

fetch() {
  info "Fetching latest OpenCode version from GitHub ..."

  local latest_tag
  latest_tag="$(curl -sfL "https://api.github.com/repos/anomalyco/opencode/releases/latest" | jq -r '.tag_name' 2>/dev/null || true)"

  if [[ -z "$latest_tag" ]] || [[ "$latest_tag" == "null" ]]; then
    err "Could not get the latest release from GitHub."
    err "Check your internet connection."
    exit 1
  fi

  local version="${latest_tag#v}"
  local ref_ver last_ver
  ref_ver="$(read_version_file "$TOOLS_REF")"
  last_ver="$(read_version_file "$TOOLS_LAST")"

  echo ""
  info "Latest available version: $version"
  dim "  ref/:  $ref_ver"
  dim "  last/: $last_ver"
  echo ""

  if [[ "$last_ver" == "$version" ]]; then
    info "last/ already has version $version. To re-download, delete last/ manually."
    return 0
  fi

  info "Downloading tool descriptions from $latest_tag ..."
  mkdir -p "$TOOLS_LAST"
  rm -rf "${TOOLS_LAST:?}"/*

  _download_tools "$TOOLS_LAST" "$latest_tag"

  echo "$version" > "$TOOLS_LAST/.version"

  local count
  count="$(find "$TOOLS_LAST" -name '*.txt' | wc -l)"
  info "last/ updated: $count descriptions, version $version"
  dim "  $TOOLS_LAST/"
  echo ""

  if [[ "$ref_ver" != "-" ]] && [[ "$ref_ver" != "$version" ]]; then
    info "ref/ has version $ref_ver. Run 'diff' or 'update' to review changes."
  fi
}

promote() {
  if [[ ! -d "$TOOLS_LAST" ]] || [[ ! -f "$TOOLS_LAST/.version" ]]; then
    err "last/ is not populated. Run 'fetch' first."
    exit 1
  fi

  local count
  count="$(find "$TOOLS_LAST" -name '*.txt' | wc -l)"
  if [[ $count -eq 0 ]]; then
    err "last/ contains no descriptions. Run 'fetch' first."
    exit 1
  fi

  local last_ver
  last_ver="$(read_version_file "$TOOLS_LAST")"

  info "Promoting last/ → ref/ ($last_ver)"

  rm -rf "$TOOLS_REF"
  cp -r "$TOOLS_LAST" "$TOOLS_REF"
  echo "$last_ver" > "$TOOLS_REF/.version"

  info "ref/ updated to version $last_ver"
  dim "  $TOOLS_REF/"
}

update() {
  # Step 1: fetch latest; skip diff if nothing was downloaded
  local last_ver_before
  last_ver_before="$(read_version_file "$TOOLS_LAST")"

  fetch

  local last_ver_after
  last_ver_after="$(read_version_file "$TOOLS_LAST")"
  if [[ "$last_ver_before" == "$last_ver_after" ]] && [[ "$last_ver_before" != "-" ]]; then
    info "Already up to date (last/ unchanged)."
    return 0
  fi

  # Step 2: check for changes affecting overrides
  echo ""
  header "update — checking overrides..."
  echo ""

  local core_output
  core_output="$(_diff_core "$TOOLS_REF" "$TOOLS_LAST")"

  local changed=0 affected=0

  while IFS=' ' read -r status rel; do
    local tool_id="${rel%.txt}"
    case "$status" in
      C!)
        affected=$((affected + 1))
        echo "  ${YELLOW}⚠${NC} $rel ${RED}(has override)${NC}"
        changed=$((changed + 1))
        ;;
      R)
        changed=$((changed + 1))
        if [[ -f "$OVERRIDES_DIR/$tool_id.txt" ]]; then
          affected=$((affected + 1))
          echo "  ${RED}❌${NC} $rel ${RED}REMOVED (has override)${NC}"
        fi
        ;;
      C|A) changed=$((changed + 1)) ;;
    esac
  done <<< "$core_output"

  echo ""
  if [[ $affected -gt 0 ]]; then
    warn "${BOLD}$affected override(s) affected — update blocked.${NC}"
    info "Review changes with 'diff', then run 'promote' if safe."
    exit 1
  elif [[ $changed -gt 0 ]]; then
    info "No overrides affected — auto-promoting."
    promote
  else
    info "Already up to date."
  fi
}

_has_overrides() {
  ls -1 "$OVERRIDES_DIR"/*.txt &>/dev/null
}

# Core diff logic shared by diff() and update().
# Output: one line per changed/removed/added tool.
# Format: "<STATUS> <relative_path>"
# STATUS: R (removed), A (added), C (changed, no override), C! (changed, has override)
_diff_core() {
  local dir_a="$1" dir_b="$2"

  local a_files b_files all_files
  a_files="$(cd "$dir_a" 2>/dev/null && find . -name '*.txt' -type f || true)"
  b_files="$(cd "$dir_b" 2>/dev/null && find . -name '*.txt' -type f || true)"
  all_files="$(printf '%s\n%s\n' "$a_files" "$b_files" | sort -u)"

  while IFS= read -r rel; do
    rel="${rel#./}"
    local file_a="$dir_a/$rel" file_b="$dir_b/$rel"
    local tool_id="${rel%.txt}"

    if [[ ! -f "$file_b" ]]; then
      echo "R $rel"
    elif [[ ! -f "$file_a" ]]; then
      echo "A $rel"
    elif ! cmp -s "$file_a" "$file_b"; then
      if [[ -f "$OVERRIDES_DIR/$tool_id.txt" ]]; then
        echo "C! $rel"
      else
        echo "C $rel"
      fi
    fi
  done <<< "$all_files"
}

diff() {
  local impact=false show_all=false mode_auto=false
  local arg="${1:-}"

  case "$arg" in
    --impact) impact=true ;;
    --all|-a) show_all=true ;;
    --help|-h) echo "Usage: diff [--impact|--all]"; return 0 ;;
    "")
      # Auto-detect: if overrides exist, default to impact mode
      if _has_overrides; then
        impact=true
        mode_auto=true
      fi
      ;;
    *) err "Unknown argument: $arg. Use: diff [--impact|--all]"; exit 1 ;;
  esac

  if [[ ! -d "$TOOLS_REF" ]] || [[ ! -f "$TOOLS_REF/.version" ]]; then
    err "ref/ is not populated. Run 'capture' or 'init' first."
    exit 1
  fi

  if [[ ! -d "$TOOLS_LAST" ]] || [[ ! -f "$TOOLS_LAST/.version" ]]; then
    err "last/ is not populated. Run 'fetch' first."
    exit 1
  fi

  local ref_ver last_ver
  ref_ver="$(read_version_file "$TOOLS_REF")"
  last_ver="$(read_version_file "$TOOLS_LAST")"

  echo ""
  header "diff — ref/ ($ref_ver) vs last/ ($last_ver)"
  if $mode_auto; then
    dim "  (impact mode: overrides detected — use --all for full diff)"
  fi
  echo ""

  local core_output
  core_output="$(_diff_core "$TOOLS_REF" "$TOOLS_LAST")"

  local changed=0 removed=0 added=0 impact_count=0

  while IFS=' ' read -r status rel; do
    case "$status" in
      R) echo "  ${RED}❌ Only in ref/${NC} $rel";    removed=$((removed + 1)) ;;
      A) echo "  ${GREEN}✚ New in last/${NC} $rel";  added=$((added + 1)) ;;
      C!)
        echo "  ${YELLOW}⚠ CHANGED${NC} $rel ${RED}(HAS OVERRIDE)${NC}"
        changed=$((changed + 1))
        impact_count=$((impact_count + 1))
        ;;
      C)
        changed=$((changed + 1))
        if $impact && ! $show_all; then
          : # impact mode: silence changes without override
        else
          echo "  ${YELLOW}⚠ changed${NC} $rel"
        fi
        ;;
    esac
  done <<< "$core_output"

  echo ""
  if [[ $changed -eq 0 && $removed -eq 0 && $added -eq 0 ]]; then
    info "No changes between ref/ and last/."
  else
    echo "  ${BOLD}Summary:${NC} $changed changed, $removed removed, $added added"
    if $impact || $mode_auto; then
      if [[ $impact_count -gt 0 ]]; then
        warn "${BOLD}$impact_count override(s) affected — review overrides/${NC}"
      elif $impact; then
        info "None of the changes affect your overrides."
      fi
    fi
  fi
  echo ""
}

status() {
  local version
  version="$(current_version)"

  echo ""
  header "opencode-tools-override — Status"
  echo ""

  # ── Versions ──
  echo "  ${BOLD}OpenCode version:${NC}  ${CYAN}$version${NC}"

  local ref_ver last_ver
  ref_ver="$(read_version_file "$TOOLS_REF")"
  last_ver="$(read_version_file "$TOOLS_LAST")"

  if [[ "$ref_ver" != "-" ]]; then
    echo "  ref:            ${CYAN}$ref_ver${NC}"
    if [[ "$ref_ver" != "$version" ]]; then
      warn "ref does not match installed version ($version). Run 'capture'."
    fi
  else
    dim "  ref:            — (empty, run 'capture')"
  fi

  if [[ "$last_ver" != "-" ]]; then
    echo "  last:           ${CYAN}$last_ver${NC}"
    if [[ -d "$TOOLS_LAST" ]] && [[ -d "$TOOLS_REF" ]]; then
      if [[ "$ref_ver" != "-" ]] && [[ "$last_ver" != "$ref_ver" ]]; then
        warn "last ($last_ver) ≠ ref ($ref_ver). Run 'diff' or 'update'."
      fi
    fi
  else
    dim "  last:           — (empty, use 'fetch' when available)"
  fi

  echo ""

  # ── Plugin ──
  if plugin_installed; then
    if plugin_valid; then
      info "Plugin:    ${GREEN}installed${NC}"
      if [[ -L "$PLUGIN_DEST" ]]; then
        local target
        target="$(readlink "$PLUGIN_DEST")"
        dim "  symlink: $PLUGIN_DEST → $target"
      fi
    else
      warn "Plugin:    broken symlink (target not found)"
      dim "  $PLUGIN_DEST"
    fi
  else
    warn "Plugin:    ${YELLOW}NOT installed${NC}"
    dim "  Run 'install' to install it"
  fi

  # ── Active overrides ──
  local n
  n="$(count_overrides)"
  if [[ -d "$OVERRIDES_DIR" ]] && [[ "$n" -gt 0 ]]; then
    info "Overrides: ${CYAN}$n file(s)${NC} in $OVERRIDES_DIR"
    for f in "$OVERRIDES_DIR"/*.txt; do
      [[ -f "$f" ]] || continue
      local base
      base="$(basename "$f" .txt)"
      dim "    • $base"
    done
  elif [[ -d "$OVERRIDES_DIR" ]]; then
    dim "Overrides: empty directory"
  else
    dim "Overrides: (none)"
  fi

  echo ""
}

help() {
  echo ""
  header "opencode-tools-override.sh — Tool Description Override Plugin Manager"
  echo ""
  echo "Plugin that overrides OpenCode tool descriptions with plain"
  echo ".txt files in overrides/. The plugin finds the overrides/"
  echo "directory automatically next to its .ts file in the repo."
  echo ""
  echo "Uses the 'tool.definition' hook of the plugin system."
  echo ""
  echo "${BOLD}Important:${NC}"
  echo "  Overrides are cached in memory when OpenCode starts."
  echo "  If you create or modify a .txt file in overrides/, the change"
  echo "  will NOT take effect until you restart OpenCode."
  echo ""
  echo "${BOLD}Commands:${NC}"
  echo "  ${GREEN}init${NC}       Set up the environment: create directories and capture ref/"
  echo "  ${GREEN}install${NC}    Create plugin symlink (OpenCode auto-discovery)"
  echo "  ${GREEN}uninstall${NC}  Remove the plugin symlink (does not touch overrides/)"
  echo "  ${GREEN}capture${NC}    Download tool descriptions for the installed version (opencode --version)"
  echo "  ${GREEN}fetch${NC}      Download tools from the latest GitHub release → last/"
  echo "  ${GREEN}update${NC}     Fetch + auto-promote if no overrides affected, block otherwise"
  echo "  ${GREEN}diff${NC}       Compare ref/ vs last/ (use --all for full diff, --impact for overrides only)"
  echo "  ${GREEN}promote${NC}    Copy last/ → ref/ (after verifying compatibility)"
  echo "  ${GREEN}status${NC}     Show versions, plugin status, and overrides"
  echo "  ${GREEN}help${NC}       This help text"
  echo ""
  echo "${BOLD}Examples:${NC}"
  echo "  opencode-tools-override.sh fetch"
  echo "  opencode-tools-override.sh update"
  echo "  opencode-tools-override.sh diff"
  echo "  opencode-tools-override.sh diff --impact"
  echo "  opencode-tools-override.sh diff --all"
  echo ""
  echo "${BOLD}Files:${NC}"
  echo "  $PLUGIN_SRC"
  echo "  $PLUGIN_DEST  (symlink)"
  echo "  $OVERRIDES_DIR/     (your overrides)"
  echo "  $TOOLS_REF/"
  echo "  $TOOLS_LAST/"
  echo ""
}

# ─── Dispatch ───────────────────────────────────────────────────────────────
cmd="${1:-}"
shift 2>/dev/null || true

case "$cmd" in
  init)      init ;;
  install)   install ;;
  uninstall) uninstall ;;
  capture)   capture ;;
  fetch)     fetch ;;
  update)    update ;;
  promote)   promote ;;
  diff)      diff "${1:-}" ;;
  status)    status ;;
  help|--help|-h|"") help ;;
  *)
    err "Unknown command: $cmd"
    err "Use: opencode-tools-override.sh help"
    exit 1
    ;;
esac
