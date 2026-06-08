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

_version_ge() {
  local v1="$1" v2="$2"
  [[ "$v1" == "-" ]] && v1="0.0.0"
  [[ "$v2" == "-" ]] && v2="0.0.0"
  [[ -z "$v1" ]] && v1="0.0.0"
  [[ -z "$v2" ]] && v2="0.0.0"
  # sort -V ascending, -C checks input is sorted
  # Returns 0 (true) if v1 >= v2
  printf '%s\n%s\n' "$v2" "$v1" | sort -C -V 2>/dev/null
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
  # Clean destination so stale files from prior versions don't linger
  find "$dest" -mindepth 1 -maxdepth 1 ! -name '.version' -exec rm -rf {} +

  local tmp_json
  tmp_json="$(mktemp)"

  if ! curl -sfL --retry 2 --retry-delay 3 "$api_url" -o "$tmp_json"; then
    err "Network error querying GitHub API."
    rm -f "$tmp_json"
    exit 1
  fi

  # .txt files at the root of tool/
  jq -r '.[] | select(.type == "file" and (.name | endswith(".txt"))) | "\(.name)\t\(.download_url)"' "$tmp_json" | \
    while IFS=$'\t' read -r name url; do
      curl -sfL --retry 2 --retry-delay 3 "$url" -o "$dest/$name"
    done

  # Subdirectories (shell/)
  jq -r '.[] | select(.type == "dir") | .name' "$tmp_json" | while read -r dir; do
    local sub_url="$api_base/$dir?ref=$tag"
    local sub_json
    sub_json="$(mktemp)"
    if curl -sfL --retry 2 --retry-delay 3 "$sub_url" -o "$sub_json"; then
      mkdir -p "$dest/$dir"
      jq -r '.[] | select(.type == "file" and (.name | endswith(".txt"))) | "\(.name)\t\(.download_url)"' "$sub_json" | \
        while IFS=$'\t' read -r name url; do
          curl -sfL --retry 2 --retry-delay 3 "$url" -o "$dest/$dir/$name"
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
  echo ""
  status
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

  local ref_ver last_ver
  ref_ver="$(read_version_file "$TOOLS_REF")"
  last_ver="$(read_version_file "$TOOLS_LAST")"

  # Guard: do not promote an older version over ref/
  if [[ "$ref_ver" != "-" ]] && ! _version_ge "$last_ver" "$ref_ver"; then
    err "Cannot promote: last/ ($last_ver) is older than ref/ ($ref_ver)."
    err "Run 'capture' to sync ref/ with the installed version."
    exit 1
  fi

  if [[ "$ref_ver" == "$last_ver" ]]; then
    info "ref/ and last/ are both at version $last_ver. Nothing to promote."
    return 0
  fi

  info "Promoting last/ → ref/ ($last_ver)"

  rm -rf "$TOOLS_REF"
  cp -r "$TOOLS_LAST" "$TOOLS_REF"
  echo "$last_ver" > "$TOOLS_REF/.version"

  info "ref/ updated to version $last_ver"
  dim "  $TOOLS_REF/"
}

update() {
  # Step 1: fetch latest (skips if last/ is already current)
  fetch

  # Step 2: compare ref/ vs last/ versions
  local ref_ver last_ver
  ref_ver="$(read_version_file "$TOOLS_REF")"
  last_ver="$(read_version_file "$TOOLS_LAST")"

  if [[ "$ref_ver" == "$last_ver" ]]; then
    info "Already up to date (ref/ matches last/)."
    return 0
  fi

  echo ""
  info "ref/ ($ref_ver) differs from last/ ($last_ver)."
  echo ""

  # Step 3: show diff
  diff --all

  # Step 4: decide whether to auto-promote or prompt
  local core_output
  core_output="$(_diff_core "$TOOLS_REF" "$TOOLS_LAST")"

  if [[ -n "$core_output" ]]; then
    echo ""
    info "Run '${BOLD}promote${NC}' to adopt the new version (last/ → ref/)."
  else
    # No content differences — safe to promote silently
    promote
  fi
}

_has_overrides() {
  local f
  f="$(compgen -G "$OVERRIDES_DIR"/*.txt 2>/dev/null)"
  [[ -n "$f" ]]
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
      local tool_base="${tool_id##*/}"
      if [[ -f "$OVERRIDES_DIR/$tool_base.txt" ]]; then
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
  echo "Sobrescribe las descripciones de herramientas de OpenCode con archivos"
  echo ".txt propios. Las descripciones de referencia se descargan de GitHub"
  echo "y los overrides/ se aplican al arrancar OpenCode."
  echo ""
  echo "${BOLD}Flujo normal (día a día):${NC}"
  echo ""
  echo "  ${GREEN}capture${NC}  1. Descarga en ref/ las tools de la versión instalada"
  echo "                  (opencode --version). Se usa al actualizar OpenCode"
  echo "                  o para resetear ref/ a un estado conocido."
  echo "  ${GREEN}status${NC}   2. Muestra versiones, plugin, overrides activos."
  echo "                  Confirma que todo está en orden tras capture."
  echo "  ${GREEN}update${NC}   3. Un solo paso: fetch (descarga last/ desde la"
  echo "                  última release de GitHub) + diff + auto-promote"
  echo "                  (copia last/ → ref/) si no hay cambios de contenido."
  echo "                  Si hay cambios, muestra el diff y pide confirmación."
  echo ""
  echo "${BOLD}Comandos:${NC}"
  echo ""
  echo "  ${GREEN}capture${NC}    Descarga tools de la versión instalada a ref/"
  echo "  ${GREEN}fetch${NC}      Descarga tools de la última release a last/"
  echo "  ${GREEN}diff${NC}       Compara ref/ vs last/ (--all diff completo, --impact solo overrides)"
  echo "  ${GREEN}promote${NC}    Copia last/ → ref/ (solo si last/ >= ref/)"
  echo "  ${GREEN}update${NC}     fetch + diff + auto-promote (si no hay cambios de contenido)"
  echo "  ${GREEN}status${NC}     Muestra versiones, plugin y overrides activos"
  echo "  ${GREEN}init${NC}       Primera configuración: crea directorios + capture"
  echo "  ${GREEN}install${NC}    Instala el plugin (symlink en ~/.config/opencode)"
  echo "  ${GREEN}uninstall${NC}  Elimina el symlink del plugin"
  echo ""
  echo "${BOLD}Notas:${NC}"
  echo "  • Los overrides se cachean en memoria al arrancar OpenCode."
  echo "    Crear o modificar un .txt en overrides/ requiere reiniciar."
  echo "  • promote rechaza sobrescribir ref/ con una versión anterior."
  echo "  • capture y fetch descargan desde GitHub (requieren conexión)."
  echo "  • diff, promote y update requieren que existan tanto ref/ como last/."
  echo ""
  echo "${BOLD}Estructura de directorios:${NC}"
  echo "  $PLUGIN_SRC"
  echo "  $OVERRIDES_DIR/     (tus overrides — un .txt por herramienta)"
  echo "  $TOOLS_REF/         (tools de la versión actual de OpenCode)"
  echo "  $TOOLS_LAST/        (tools de la última release en GitHub)"
  echo ""
  echo "${BOLD}Ejemplo completo:${NC}"
  echo "  opencode-tools-override.sh init       # Primera vez"
  echo "  opencode-tools-override.sh install    # Activar plugin"
  echo "  # Crear .txt en overrides/ para las tools que quieras personalizar"
  echo "  opencode-tools-override.sh status     # Ver estado"
  echo "  # ... tiempo después, al salir una nueva versión de OpenCode ..."
  echo "  opencode-tools-override.sh capture    # Sincronizar ref/ con versión instalada"
  echo "  opencode-tools-override.sh update     # Actualizar a la última versión"
  echo "  opencode-tools-override.sh status     # Verificar resultado"
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
