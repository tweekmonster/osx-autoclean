#!/usr/bin/env bash
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_FILE="$CONFIG_DIR/dirclean.conf"
CONF=()

[[ ! -d "$CONFIG_DIR" ]] && mkdir -p "$CONFIG_DIR"


load_config() {
  [[ ! -f "$CONFIG_FILE" ]] && return
  local IFS=$'\n'
  CONF=($(<"$CONFIG_FILE"))
}


displaytime() {
  # http://unix.stackexchange.com/a/27014/116535
  local T=$1
  local D=$((T/60/60/24))
  local H=$((T/60/60%24))
  local M=$((T/60%60))
  local S=$((T%60))
  (( $D > 0 )) && printf '%d days ' $D
  (( $H > 0 )) && printf '%d hours ' $H
  (( $M > 0 )) && printf '%d minutes ' $M
  (( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
  printf '%d seconds\n' $S
}


mdls_latest_time() {
  local times=($(mdls -raw -nullMarker '' -name kMDItemFSContentChangeDate \
    -name kMDItemFSCreationDate -name kMDItemLastUsedDate \
    -name kMDItemDateAdded "$@" \
    | xargs -0 -I'{}' echo '{}' | xargs -I'{}' date -u -j -f '%Y-%m-%d %T +0000' '{}' +"%s" \
    | sort -r -u))
  echo "${times[0]}"
}


filetime() {
  # Get the access, modification, or creation time.  Whichever is the most
  # recent.  If the filename is a directory, get the most recent time for sub
  # directories or files.  If the directory is a bundle or package, only check
  # the directory's date.
  local oIFS="$IFS"
  local IFS=$'\n'
  local time=0
  local files=("$1")

  if [[ -d "$1" ]]; then
    type=$(mdls -raw -name kMDItemContentTypeTree "$1")
    if [[ "$type" =~ .*com\.apple\.(bundle|package).* ]]; then
      mdls_latest_time "$filename"
      return
    fi

    files+=($(find "$1" -name '*'))
  fi

  mdls_latest_time "${files[@]}"
}

clean_directory() {
  shopt -s nullglob
  local now=$(date -u +"%s")
  local interval="$1"
  for filename in "$2/"*; do
    time=$(filetime "$filename")
    delta=$(( now - time ))
    echo "$filename" >&2
    displaytime $delta >&2

    if (( delta > $1 )); then
      osascript -e "tell application \"Finder\" to delete POSIX file \"$filename\"" > /dev/null
      if (( $? != 0 )); then
        echo "Could not delete: $filename"
        echo "Age: $(displaytime $delta)"
      fi
    fi
  done
}

load_config

if [[ "$1" == "--clean" ]]; then
  for line in "${CONF[@]}"; do
    interval="${line%%;*}"
    dirname="${line##*;}"
    clean_directory "$interval" "$dirname"
  done

  exit 0
fi

if (( $# == 2 )); then
  IFS=$'\n'
  new_interval="$1"
  new_dirname="${2/#\~/$HOME}"

  if [[ ! "$new_interval" =~ ^[0-9]+$ ]]; then
    echo "First argument must be the max age in days" >&2
    exit 1
  fi

  if [[ ! -d "$new_dirname" ]]; then
    echo "The second argument must be a directory" >&2
    exit 1
  fi

  new_interval=$(( new_interval * 86400 ))

  new_lines=("$new_interval;${new_dirname%/}")
  for line in "${CONF[@]}"; do
    interval="${line%%;*}"
    dirname="${line##*;}"
    if [[ "$dirname" != "$new_dirname" ]]; then
      new_lines+=("$interval;$dirname")
    fi
  done

  echo "${new_lines[*]}" > "$CONFIG_FILE"
  exit 0
fi

script_dir=$(cd "$(dirname "$0")"; pwd)
script_name="${0##*/}"
cat <<HELP

Monitor a directory and moves old files to ~/.Trash

Add a monitored directory:

  $script_name {days} {directory}

  - days: Number of days since any of the file's time attributes have been
    updated.
  - directory: The directory to monitor for old files.

Perform a scan:

  $script_name --clean

Example for deleting files older than 5 days in the ~/Downloads directory:

  $script_name 5 ~/Downloads

Example crontab to scan every day at 04:00:

  0 4 * * * $script_dir/$script_name --clean

HELP
