#!/bin/bash

# gu (git-user): A tool to manage Git user and email information

CONFIG_FILE="$HOME/.git_user_profiles"
VERSION="v1.1.0"
UPDATE_URL="https://raw.githubusercontent.com/hnrobert/gu/develop/gu.sh"

highlight_text() {
  echo "$(tput setaf 2)$(tput bold)$1$(tput sgr0)"
}

show_version() {
  echo "gu version: $VERSION"
}

upgrade_gu() {
  local tmp_file
  tmp_file=$(mktemp) || {
    echo "Failed to create a temporary file for download."
    return 1
  }

  echo "Downloading latest gu from $UPDATE_URL ..."
  if ! curl -fsSL "$UPDATE_URL" -o "$tmp_file"; then
    echo "Download failed."
    rm -f "$tmp_file"
    return 1
  fi

  chmod +x "$tmp_file" || {
    echo "Failed to mark the downloaded script as executable."
    rm -f "$tmp_file"
    return 1
  }

  local target_path
  target_path=$(command -v gu 2>/dev/null)
  if [[ -z "$target_path" ]]; then
    target_path="$0"
  fi

  echo "Installing update to $target_path ..."
  if mv "$tmp_file" "$target_path" 2>/dev/null; then
    echo "Update successful."
  elif sudo mv "$tmp_file" "$target_path"; then
    echo "Update successful (used sudo)."
  else
    echo "Failed to install update. Check permissions."
    rm -f "$tmp_file"
    return 1
  fi

  echo "Updated version:"
  "$target_path" --version
}

set_user_info() {
  local scope="local"
  local user_alias=""

  # Create config file if it doesn't exist
  if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
  fi

  # Parse arguments for --global and --user
  while [[ $# -gt 0 ]]; do
    case $1 in
    --global | -g)
      scope="global"
      shift
      ;;
    --user | -u)
      user_alias="$2"
      shift 2
      ;;
    *)
      # If no --user flag was specified but there's a remaining argument,
      # treat it as the user alias
      if [[ -z "$user_alias" && -n "$1" ]]; then
        user_alias="$1"
      fi
      shift
      ;;
    esac
  done

  # If --user specified, try to use existing profile; only prompt to create when missing
  if [[ -n "$user_alias" ]]; then
    if grep -q "^$user_alias|" "$CONFIG_FILE" 2>/dev/null; then
      local selected_profile=$(grep "^$user_alias|" "$CONFIG_FILE")
      IFS='|' read -r alias name email <<<"$selected_profile"
      git config --$scope user.name "$name"
      git config --$scope user.email "$email"
      echo "Set to profile: Alias: $alias, Name: $name, Email: $email (Scope: $scope)"
      return
    else
      echo "Profile '$user_alias' not found."
      read -p "Create a new profile named '$user_alias'? [y/N]: " create_choice
      if [[ ! "$create_choice" =~ ^[Yy]$ ]]; then
        echo "No changes made."
        return 1
      fi
      read -p "Enter git user name: " name
      read -p "Enter email: " email
      alias="$user_alias"
    fi
  else
    # No alias provided: fall back to interactive creation
    read -p "Enter git user name: " name
    read -p "Enter email: " email
    read -p "Enter alias (default: $name): " alias
    alias=${alias:-$name}
  fi

  git config --$scope user.name "$name"
  git config --$scope user.email "$email"
  echo "User information set to Name: $name, Email: $email (Scope: $scope)"

  add_user_profile "$alias" "$name" "$email"
}

update_user_info() {
  local user_alias=""

  # Create config file if it doesn't exist
  if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
  fi

  # Parse arguments for --user
  while [[ $# -gt 0 ]]; do
    case $1 in
    --user | -u)
      user_alias="$2"
      shift 2
      ;;
    *)
      if [[ -z "$user_alias" && -n "$1" ]]; then
        user_alias="$1"
      fi
      shift
      ;;
    esac
  done

  if [[ -z "$user_alias" ]]; then
    read -p "Enter alias to update: " user_alias
    if [[ -z "$user_alias" ]]; then
      echo "No alias provided."
      return 1
    fi
  fi

  if grep -q "^$user_alias|" "$CONFIG_FILE" 2>/dev/null; then
    local selected_profile=$(grep "^$user_alias|" "$CONFIG_FILE")
    IFS='|' read -r alias name email <<<"$selected_profile"
    read -p "Enter git user name [$name]: " new_name
    new_name=${new_name:-$name}
    read -p "Enter email [$email]: " new_email
    new_email=${new_email:-$email}

    local tmp_file
    tmp_file=$(mktemp) || {
      echo "Failed to create a temporary file for update."
      return 1
    }

    if awk -F'|' -v alias="$alias" -v new_name="$new_name" -v new_email="$new_email" 'BEGIN{OFS="|"} {if($1==alias){$2=new_name;$3=new_email} print}' "$CONFIG_FILE" >"$tmp_file" && mv "$tmp_file" "$CONFIG_FILE"; then
      echo "Profile '$alias' updated to Name: $new_name, Email: $new_email"
    else
      echo "Failed to update profile."
      rm -f "$tmp_file"
      return 1
    fi
  else
    echo "Profile '$user_alias' not found."
    read -p "Create a new profile named '$user_alias'? [y/N]: " create_choice
    if [[ ! "$create_choice" =~ ^[Yy]$ ]]; then
      echo "No changes made."
      return 1
    fi
    read -p "Enter git user name: " name
    read -p "Enter email: " email
    add_user_profile "$user_alias" "$name" "$email"
  fi
}

show_user_info() {
  name=$(git config user.name)
  email=$(git config user.email)
  echo $(highlight_text "Name: $name, Email: $email")
}

add_user_profile() {
  local alias="$1"
  local name="$2"
  local email="$3"

  # Create config file if it doesn't exist
  if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
  fi

  if grep -q "^$alias|" "$CONFIG_FILE" 2>/dev/null; then
    echo "Profile '$alias' already exists."
    return
  fi

  echo "$alias|$name|$email" >>"$CONFIG_FILE"
  echo "Added profile '$alias' with Name: $name, Email: $email"
}

# Function to add a new user profile with --user support
add_profile_interactive() {
  local user_alias=""

  # Parse arguments - first check for --user flag, then for direct alias argument
  while [[ $# -gt 0 ]]; do
    case $1 in
    --user | -u)
      user_alias="$2"
      shift 2
      ;;
    *)
      # If no --user flag, treat first argument as alias
      if [[ -z "$user_alias" ]]; then
        user_alias="$1"
      fi
      shift
      ;;
    esac
  done

  # Create config file if it doesn't exist
  if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
  fi

  if [[ -n "$user_alias" ]]; then
    if grep -q "^$user_alias|" "$CONFIG_FILE" 2>/dev/null; then
      echo "Profile '$user_alias' already exists."
      return
    fi
    read -p "Enter git user name: " name
    read -p "Enter email: " email
    alias="$user_alias"
  else
    read -p "Enter git user name: " name
    read -p "Enter email: " email
    read -p "Enter alias: " alias
  fi

  add_user_profile "$alias" "$name" "$email"
}

# Function to list profiles and highlight the current user
list_profiles() {
  # Create config file if it doesn't exist
  if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
  fi

  # Check if file is empty
  if [[ ! -s "$CONFIG_FILE" ]]; then
    echo "No profiles available."
    return
  fi

  local current_name=$(git config user.name)
  local current_email=$(git config user.email)

  echo "Available profiles:"
  local i=1
  while IFS='|' read -r alias name email; do
    local display_info="$i) Alias: $alias, Name: $name, Email: $email"
    if [[ "$name" == "$current_name" ]] && [[ "$email" == "$current_email" ]]; then
      display_info+=" (Current)"
      echo $(highlight_text "$display_info")
    else
      echo "$display_info"
    fi
    ((i++))
  done <"$CONFIG_FILE"
}

# Interactive function to delete a profile with --user support
delete_user_profile() {
  local user_alias=""

  # Create config file if it doesn't exist
  if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
  fi

  # Check if file is empty
  if [[ ! -s "$CONFIG_FILE" ]]; then
    echo "No profiles available to delete."
    return
  fi

  # Parse arguments - first check for --user flag, then for direct alias argument
  while [[ $# -gt 0 ]]; do
    case $1 in
    --user | -u)
      user_alias="$2"
      shift 2
      ;;
    *)
      # If no --user flag, treat first argument as alias
      if [[ -z "$user_alias" ]]; then
        user_alias="$1"
      fi
      shift
      ;;
    esac
  done

  if [[ -n "$user_alias" ]]; then
    if grep -q "^$user_alias|" "$CONFIG_FILE" 2>/dev/null; then
      if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "/^$user_alias|/d" "$CONFIG_FILE"
      else
        sed -i "/^$user_alias|/d" "$CONFIG_FILE"
      fi
      echo "Profile '$user_alias' deleted."
    else
      echo "Profile '$user_alias' not found."
    fi
    return
  fi

  # Interactive mode
  list_profiles

  # Check again if file is empty after listing (in case list_profiles shows "No profiles available")
  if [[ ! -s "$CONFIG_FILE" ]]; then
    return
  fi

  local profiles=($(awk -F'|' '{print $1}' "$CONFIG_FILE" 2>/dev/null))

  read -p "Enter the number of the profile to delete: " choice
  local valid_choice_regex='^[0-9]+$'
  if ! [[ $choice =~ $valid_choice_regex ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#profiles[@]}" ]; then
    echo "Invalid selection."
    return
  fi

  # Construct the pattern to avoid partial matches
  local profile_to_delete="${profiles[$choice - 1]}"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "/^$profile_to_delete|/d" "$CONFIG_FILE"
  else
    sed -i "/^$profile_to_delete|/d" "$CONFIG_FILE"
  fi
  echo "Profile deleted."
}

show_help() {
  echo "Usage: gu [COMMAND] [OPTIONS] [ALIAS]"
  echo ""
  echo "A tool to manage Git user and email information."
  echo ""
  echo "Commands:"
  echo "  set [-g|--global] [-u|--user ALIAS | ALIAS]   Switch to an existing profile and apply it. If missing, optionally create."
  echo "  show                                          Show the current user info."
  echo "  add [-u|--user ALIAS | ALIAS]                 Add a new user profile with a unique alias."
  echo "  delete [-u|--user ALIAS | ALIAS]              Delete an existing user profile."
  echo "  list                                          List all available user profiles with the current one highlighted."
  echo "  update [-u|--user ALIAS | ALIAS]              Update profile name/email in the config file (create on request)."
  echo "  version | -v | --version                      Show the current tool version."
  echo "  upgrade                                       Download and install the latest version of gu."
  echo "  help | -h | --help                            Show this help message and exit."
  echo ""
  echo "Options:"
  echo "  -g, --global                                  Apply settings globally instead of locally."
  echo "  -u, --user ALIAS                              Specify user profile alias."
  echo ""
  echo "Examples:"
  echo "  gu set -g                                     Set global Git user name and email interactively."
  echo "  gu set --global                               Same as above using long form."
  echo "  gu set -u hnrobert                            Switch to 'hnrobert' profile or create it if not exists."
  echo "  gu set hnrobert                               Same as above without -u flag."
  echo "  gu set -g workuser                            Switch to 'workuser' profile globally."
  echo "  gu add work                                   Add a new Git user profile with alias 'work'."
  echo "  gu add -u work                                Same as above using short form."
  echo "  gu delete prev                                Delete the 'prev' user profile."
  echo "  gu delete -u prev                             Same as above using short form."
  echo "  gu list                                       List all Git user profiles."
}

# Main program
case "$1" in
version | --version | -v)
  show_version
  ;;
help | --help | -h)
  show_help
  ;;
set)
  shift
  set_user_info "$@"
  ;;
show)
  show_user_info
  ;;
add)
  shift
  add_profile_interactive "$@"
  ;;
delete)
  shift
  delete_user_profile "$@"
  ;;
list)
  list_profiles
  ;;
upgrade)
  upgrade_gu
  ;;
update)
  shift
  update_user_info "$@"
  ;;
*)
  echo "Invalid command. Showing help:"
  show_help
  exit 1
  ;;
esac

exit 0
