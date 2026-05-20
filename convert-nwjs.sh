#!/usr/bin/env bash
set -euo pipefail

# nwjs-win2linux - Convert Windows NW.js apps to Linux
# Usage: ./convert-nwjs.sh [windows-app-dir]
# If no dir given, scans ~/Downloads for candidates.

DOWNLOAD_DIR="${2:-$HOME/Downloads}"
BASE_NWJS="${3:-$DOWNLOAD_DIR/nwjs-v0.110.1-linux-x64}"

# Windows NW.js runtime files to EXCLUDE when copying game assets
WINDOWS_RT_FILES=(
  "*.exe" "*.dll"
  "natives_blob.bin" "snapshot_blob.bin"
  "notification_helper.exe"
)

detect_windows_apps() {
  local dir="$1"
  echo "Scanning $dir for Windows NW.js apps ..." >&2
  for d in "$dir"/*/; do
    [ -d "$d" ] || continue
    # Heuristic: has nw.dll or nw_elf.dll (Windows NW.js runtime marker)
    if [ -f "$d/nw.dll" ] || [ -f "$d/nw_elf.dll" ]; then
      # Also check for exe
      local exe
      exe=$(find "$d" -maxdepth 1 -name '*.exe' -print -quit 2>/dev/null)
      if [ -n "$exe" ]; then
        basename "$d"
      fi
    fi
  done
}

copy_game_files() {
  local src="$1" dst="$2"
  rsync -a "$src/package.json" "$dst/" 2>/dev/null || true

  # Copy www/ if it exists
  [ -d "$src/www" ] && rsync -a "$src/www/" "$dst/www/"

  # Copy any .nw package
  for f in "$src"/*.nw; do
    [ -f "$f" ] && cp "$f" "$dst/"
  done

  # Copy any other top-level files/dirs that aren't Windows NW.js runtime
  for item in "$src"/*; do
    local base
    base=$(basename "$item")
    # Skip known Windows runtime files
    case "$base" in
      *.exe|*.dll) continue ;;
      natives_blob.bin|snapshot_blob.bin|notification_helper.exe) continue ;;
    esac
    # Skip if it already exists in dest (base runtime file)
    [ -e "$dst/$base" ] && continue
    # Skip package.json and www (already handled above)
    [ "$base" = "package.json" ] && continue
    [ "$base" = "www" ] && continue
    # Copy the rest (game-specific data)
    cp -r "$item" "$dst/"
  done
}

convert_app() {
  local win_app="$1" app_name="$2"
  local out_dir="$DOWNLOAD_DIR/nwjs-$app_name"

  if [ -d "$out_dir" ]; then
    echo "  Output $out_dir already exists. Skipping."
    return
  fi

  echo "  Converting: $win_app -> $out_dir"

  # 1. Copy base Linux NW.js runtime
  rsync -a "$BASE_NWJS/" "$out_dir/"
  [ -f "$out_dir/nw" ] && chmod +x "$out_dir/nw"

  # 2. Overlay game files
  copy_game_files "$win_app" "$out_dir"

  # 3. Update package.json name
  local pkg="$out_dir/package.json"
  if [ -f "$pkg" ]; then
    if command -v jq &>/dev/null; then
      jq --arg name "$app_name" '.name = $name' "$pkg" > "${pkg}.tmp" && mv "${pkg}.tmp" "$pkg"
    else
      sed -i "s/\"name\": \"\"/\"name\": \"$app_name\"/" "$pkg"
    fi
  fi

  echo "  Done: $out_dir"
}

main() {
  local target="${1:-}"

  if [ -n "$target" ]; then
    # Convert a specific app
    local app_name
    app_name=$(basename "$target" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g' | sed 's/-\+/-/g; s/^-\+//; s/-\+$//')
    if [ ! -d "$target" ] || [ ! -f "$target/nw.dll" ]; then
      echo "Error: $target is not a valid Windows NW.js app (no nw.dll found)"
      exit 1
    fi
    convert_app "$target" "$app_name"
  else
    # Scan Downloads
    local candidates=()
    while IFS= read -r name; do
      candidates+=("$name")
    done < <(detect_windows_apps "$DOWNLOAD_DIR")

    if [ ${#candidates[@]} -eq 0 ]; then
      echo "No Windows NW.js apps found in $DOWNLOAD_DIR"
      echo "Usage: $0 [path-to-windows-nwjs-app]"
      exit 0
    fi

    echo ""
    echo "Found ${#candidates[@]} Windows NW.js app(s):"
    for i in "${!candidates[@]}"; do
      echo "  $((i+1)). ${candidates[$i]}"
    done
    echo ""
    echo -n "Enter numbers to convert (e.g. 1 3 5), or 'all': "
    read -r selection

    if [ "$selection" = "all" ]; then
      for name in "${candidates[@]}"; do
        convert_app "$DOWNLOAD_DIR/$name" "$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g; s/-\+/-/g; s/^-\+//; s/-\+$//')"
      done
    else
      for num in $selection; do
        local idx=$((num - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#candidates[@]}" ]; then
          local name="${candidates[$idx]}"
          convert_app "$DOWNLOAD_DIR/$name" "$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g; s/-\+/-/g; s/^-\+//; s/-\+$//')"
        else
          echo "Invalid selection: $num"
        fi
      done
    fi
  fi
}

main "$@"
