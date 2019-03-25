#!/bin/sh
# jwalk: a streaming JSON parser for Unix
# (c) Sam Stephenson / https://jwalk.sh

set -e
[ -z "$JWALK_DEBUG" ] || set -x

warn() {
  printf "%s\n" "$1" >&2
}

error() {
  warn "jwalk: $1"
}

usage() {
  warn "usage: jwalk [-e script ...] [-f script-file ...] [json-file]"
  [ -z "$1" ] || exit "$1"
}


# Find ourselves

realpath_dirname() {
  path="$1"
  while :; do
    cd -P "${path%/*}"
    name="${path##*/}"
    if [ -L "$name" ]; then
      link="$(ls -l "$name")"
      path="${link##* $name -> }"
    else
      break
    fi
  done
  pwd
}

LIB="$(realpath_dirname "$0")"
TMPDIR="${TMPDIR:-/tmp}"


# Process command-line arguments

unset args stored_scripts json_file

store() {
  path="${TMPDIR%/}/jwalk.$$.$1"
  escaped_path="$(escape "$path")"
  append stored_scripts "$escaped_path "
  printf '%s\n' "$2" > "$path"
  trap 'eval "rm -f $stored_scripts"' EXIT
}

append() {
  eval "shift; $1=\"\$$1\$@ \""
}

escape() {
  printf '%s\n' "$1" | sed "s/'/'\\\\''/g;1s/^/'/;\$s/\$/'/"
}

index=1

while [ $index -le $# ]; do
  eval 'this="$'$index'"'
  eval 'next="$'$(( index + 1 ))'"'
  incr=1

  case "$this" in
    -e)
      [ -n "$next" ] || usage 1
      store $index "$next"
      append args -f "$escaped_path"
      incr=2
      ;;
    -f)
      [ -n "$next" ] || usage 1
      append args -f '"$'$(( index + 1 ))'"'
      incr=2
      ;;
    -h|--help)
      usage 0
      ;;
    -*)
      usage 1
      ;;
    *)
      [ -z "$json_file" ] || usage 1
      json_file="$this"
      ;;
  esac

  index=$(( index + incr ))
done

eval "set -- $args"


# Run jwalk

walk() {
  tokenize | parse
}

examine() {
  awk -f "$LIB/jwalk/examine.awk" "$@"
}

parse() {
  awk -f "$LIB/jwalk/parse.awk"
}

tokenize() {
  sh "$LIB/jwalk/tokenize.sh"
}

if [ -n "$json_file" ] && [ "$json_file" != "-" ]; then
  exec < "$json_file"
fi

if [ $# = 0 ]; then
  walk
else
  walk | examine "$@"
fi