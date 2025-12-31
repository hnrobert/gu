#!/bin/bash

# gutemp: set Git identity environment for forced-command SSH sessions (alias-only)

CONFIG_FILE="$HOME/.gu/profiles"
GU_DIR="$HOME/.gu"

if [[ $# -ne 1 ]]; then
  echo "Usage: gutemp <alias>" >&2
  exit 1
fi

profile_alias="$1"

mkdir -p "$GU_DIR"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Profile file not found at $CONFIG_FILE. Run 'gu add' first." >&2
  exit 1
fi

if ! grep -q "^$profile_alias|" "$CONFIG_FILE" 2>/dev/null; then
  echo "Alias '$profile_alias' not found in $CONFIG_FILE" >&2
  exit 1
fi

IFS='|' read -r _ user email < <(grep "^$profile_alias|" "$CONFIG_FILE")

if [[ -z "$user" || -z "$email" ]]; then
  echo "Alias '$profile_alias' is missing user/email in $CONFIG_FILE" >&2
  exit 1
fi

export GIT_AUTHOR_NAME="$user"
export GIT_AUTHOR_EMAIL="$email"
export GIT_COMMITTER_NAME="$user"
export GIT_COMMITTER_EMAIL="$email"
export EMAIL="$email"

# If SSH_ORIGINAL_COMMAND is actually the RemoteCommand wrapper (contains gutemp), ignore it.
if [[ -n "$SSH_ORIGINAL_COMMAND" && "$SSH_ORIGINAL_COMMAND" == *gutemp* ]]; then
  unset SSH_ORIGINAL_COMMAND
fi

# Preserve original command if present; otherwise start an interactive shell.
cmd=${SSH_ORIGINAL_COMMAND:-${SHELL:-/bin/sh}}
exec "$cmd"
