#!/usr/bin/env bash
set -e

# Backup a conflicting target path in $HOME before stowing (moves the entire path aside).
backup_path() {
  local path="$1"
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return
  fi

  local suffix=".pre-stow.$(date +%s)"
  local backup="${path}${suffix}"
  while [ -e "$backup" ] || [ -L "$backup" ]; do
    suffix=".pre-stow.$(date +%s)"
    backup="${path}${suffix}"
  done
  echo "Preserving existing $path as $backup"
  mv "$path" "$backup"
}

dotfiles_realpath() {
  # Resolve a path to its real (dereferenced) location when possible.
  local path="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$path"
  else
    echo "$path"
  fi
}

maybe_backup_conflict() {
  local dest="$1"
  local expected_source="$2"

  if [ -L "$dest" ] && [ -n "$expected_source" ]; then
    local resolved
    resolved="$(dotfiles_realpath "$dest")"
    if [ "$resolved" = "$expected_source" ]; then
      return
    fi
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup_path "$dest"
  fi
}

# Ensure a directory exists; if a non-directory exists at the path (including a dangling symlink),
# move it aside before creating the directory.
ensure_directory() {
  local dir="$1"

  if [ -d "$dir" ]; then
    return 0
  fi

  if [ -e "$dir" ] || [ -L "$dir" ]; then
    backup_path "$dir"
  fi

  mkdir -p "$dir"
}

# Stow all packages under ./config into $HOME, backing up any conflicting existing files first.
stow_all() {
  local roots=(config)
  local any_dotfiles=0
  local root
  for root in "${roots[@]}"; do
    if [ -d "$root" ] && [ -n "$(find "$root" -mindepth 1 -print -quit 2>/dev/null)" ]; then
      any_dotfiles=1
      break
    fi
  done

  if [ "$any_dotfiles" -eq 0 ]; then
    echo "No dotfiles found under config/; skipping stow."
    return 0
  fi

  if ! command -v stow >/dev/null; then
    echo "Stow is missing; install it and rerun bootstrap."
    return 0
  fi

  ensure_directory "$HOME/.config"

  local dotfiles_root
  dotfiles_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

  stow_root() {
    local root="$1"

    if [ ! -d "$root" ] || [ -z "$(find "$root" -mindepth 1 -print -quit 2>/dev/null)" ]; then
      return 0
    fi

    local stow_packages=()
    local pkg
    local pkg_base
    shopt -s dotglob nullglob
    for pkg in "$root"/*; do
      [ -d "$pkg" ] || continue
      pkg_base="$(basename "$pkg")"
      [ "$pkg_base" = ".config" ] && continue
      stow_packages+=("$pkg_base")
    done
    shopt -u dotglob nullglob

    if [ ${#stow_packages[@]} -eq 0 ]; then
      echo "No stow packages found under $root/; nothing to link."
      return 0
    fi

    # Backup conflicts at the directory/file level we intend to link, to allow directory symlinks.
    local pkg_name
    for pkg_name in "${stow_packages[@]}"; do
      if [ "$root" = "config" ] && [ "$pkg_name" = "shells" ]; then
        local shells_target="$HOME/.config/shells"
        ensure_directory "$shells_target"

        local entry
        local name
        shopt -s dotglob nullglob
        for entry in "$root/$pkg_name"/*; do
          [ -e "$entry" ] || continue
          name="$(basename "$entry")"
          maybe_backup_conflict "$shells_target/$name" "$dotfiles_root/$root/$pkg_name/$name"
        done
        shopt -u dotglob nullglob
        continue
      fi

      local name
      shopt -s dotglob nullglob
      for entry in "$root/$pkg_name"/*; do
        [ -e "$entry" ] || continue
        name="$(basename "$entry")"

        if [ "$name" = ".config" ] && [ -d "$entry" ]; then
          local xdg_name
          for xdg_entry in "$entry"/*; do
            [ -e "$xdg_entry" ] || continue
            xdg_name="$(basename "$xdg_entry")"
            maybe_backup_conflict "$HOME/.config/$xdg_name" "$dotfiles_root/$root/$pkg_name/.config/$xdg_name"
          done
          continue
        fi

        maybe_backup_conflict "$HOME/$name" "$dotfiles_root/$root/$pkg_name/$name"
      done
      shopt -u dotglob nullglob
    done

    local final_packages=()
    local pkg
    for pkg in "${stow_packages[@]}"; do
      if [ "$root" = "config" ] && [ "$pkg" = "shells" ]; then
        ensure_directory "$HOME/.config/shells"
        stow -d "$root" -t "$HOME/.config/shells" shells
      else
        final_packages+=("$pkg")
      fi
    done

    if [ ${#final_packages[@]} -gt 0 ]; then
      stow -d "$root" -t "$HOME" "${final_packages[@]}"
    fi
  }

  for root in "${roots[@]}"; do
    stow_root "$root"
  done
}

# Run a command as root: directly when already root, otherwise through sudo.
as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

# Numeric uid that owns a path (GNU stat on Linux, BSD stat on macOS).
path_owner_uid() {
  stat -c %u "$1" 2>/dev/null || stat -f %u "$1"
}

# Refuse to write to $HOME as root when $HOME belongs to someone else (e.g. sudo -E, or
# HOME=/home/user set by a provisioning tool): everything created there would be root-owned.
refuse_root_in_foreign_home() {
  if [ "$(id -u)" -eq 0 ] && [ "$(path_owner_uid "$HOME")" != "0" ]; then
    echo "Refusing to set up $HOME as root: it belongs to another user, and the files" >&2
    echo "created there would be owned by root. Run this as that user instead, or run" >&2
    echo "'bootstrap.sh --system' as root and 'bootstrap.sh --user' as the user." >&2
    exit 1
  fi
}
