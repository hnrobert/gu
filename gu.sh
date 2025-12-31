#!/bin/bash

# gu (git-user): A tool to manage Git user and email information

REPO_BASE_URL="https://raw.githubusercontent.com/hnrobert/gu"
VERSION="v1.2.0"
GU_DIR="$HOME/.gu"
CONFIG_FILE="$GU_DIR/profiles"
LAST_SELECTED_ALIAS=""

highlight_text() {
  echo "$(tput setaf 2)$(tput bold)$1$(tput sgr0)"
}

ensure_storage() {
  mkdir -p "$GU_DIR"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
  fi
}

default_alias_from_name() {
  local input="$1"
  local first_part="${input%% *}"
  if [[ -z "$first_part" ]]; then
    first_part="$input"
  fi
  local lowered
  lowered=$(printf '%s' "$first_part" | tr '[:upper:]' '[:lower:]')
  if [[ -z "$lowered" ]]; then
    lowered="user"
  fi
  echo "$lowered"
}

show_version() {
  echo "gu version: $VERSION"
}

upgrade_gu() {
  local target_branch="main"

  while [[ $# -gt 0 ]]; do
    case $1 in
    -d | --develop)
      target_branch="develop"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      return 1
      ;;
    esac
  done

  local script_url="$REPO_BASE_URL/$target_branch/gu.sh"
  local gutemp_url="$REPO_BASE_URL/$target_branch/gutemp.sh"

  local tmp_gu
  tmp_gu=$(mktemp) || {
    echo "Failed to create a temporary file for download."
    return 1
  }

  local tmp_gutemp
  tmp_gutemp=$(mktemp) || {
    echo "Failed to create a temporary file for gutemp download."
    rm -f "$tmp_gu"
    return 1
  }

  echo "Downloading latest gu from $script_url ..."
  if ! curl -fsSL -H "Cache-Control: no-cache" "$script_url" -o "$tmp_gu"; then
    echo "Download failed."
    rm -f "$tmp_gu" "$tmp_gutemp"
    return 1
  fi

  echo "Downloading latest gutemp from $gutemp_url ..."
  if ! curl -fsSL -H "Cache-Control: no-cache" "$gutemp_url" -o "$tmp_gutemp"; then
    echo "Download of gutemp failed."
    rm -f "$tmp_gu" "$tmp_gutemp"
    return 1
  fi

  chmod +x "$tmp_gu" || {
    echo "Failed to mark the downloaded script as executable."
    rm -f "$tmp_gu" "$tmp_gutemp"
    return 1
  }

  chmod +x "$tmp_gutemp" || {
    echo "Failed to mark the downloaded gutemp as executable."
    rm -f "$tmp_gu" "$tmp_gutemp"
    return 1
  }

  local target_path
  target_path=$(command -v gu 2>/dev/null)
  if [[ -z "$target_path" ]]; then
    target_path="$0"
  fi

  local target_gutemp
  target_gutemp=$(command -v gutemp 2>/dev/null)
  if [[ -z "$target_gutemp" ]]; then
    target_gutemp="/usr/local/bin/gutemp"
  fi

  echo "Installing update to $target_path ..."
  if mv "$tmp_gu" "$target_path" 2>/dev/null; then
    echo "Update successful."
  elif sudo mv "$tmp_gu" "$target_path"; then
    echo "Update successful (used sudo)."
  else
    echo "Failed to install update. Check permissions."
    rm -f "$tmp_gu" "$tmp_gutemp"
    return 1
  fi

  echo "Installing gutemp update to $target_gutemp ..."
  if mv "$tmp_gutemp" "$target_gutemp" 2>/dev/null; then
    echo "gutemp update successful."
  elif sudo mv "$tmp_gutemp" "$target_gutemp"; then
    echo "gutemp update successful (used sudo)."
  else
    echo "Failed to install gutemp update. Check permissions."
    rm -f "$tmp_gutemp"
    return 1
  fi

  echo "Updated version:"
  "$target_path" --version
}

set_user_info() {
  local scope="local"
  local user_alias=""
  local create_new=0
  local apply_git=1

  ensure_storage

  # Parse arguments for --global and --user
  while [[ $# -gt 0 ]]; do
    case $1 in
    --no-apply)
      apply_git=0
      shift
      ;;
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

  # If no alias provided, offer selection from existing profiles with an "add other" option
  if [[ -z "$user_alias" ]]; then
    if [[ -s "$CONFIG_FILE" ]]; then
      echo "Available profiles:"
      local aliases=()
      local names=()
      local emails=()
      local i=1
      while IFS='|' read -r a n e; do
        aliases+=("$a")
        names+=("$n")
        emails+=("$e")
        echo "$i) Alias: $a, Name: $n, Email: $e"
        ((i++))
      done <"$CONFIG_FILE"
      local add_option="$i"
      echo "$add_option) Add another profile"

      read -p "Select number or enter alias: " selection
      if [[ -z "$selection" ]]; then
        echo "No selection made."
        return 1
      fi

      local valid_num_regex='^[0-9]+$'
      if [[ $selection =~ $valid_num_regex ]]; then
        if ((selection >= 1 && selection < add_option)); then
          user_alias="${aliases[$selection - 1]}"
        elif ((selection == add_option)); then
          create_new=1
        else
          echo "Invalid selection."
          return 1
        fi
      else
        user_alias="$selection"
      fi
    else
      create_new=1
    fi
  fi

  # If alias provided and profile exists, apply it
  if [[ $create_new -eq 0 && -n "$user_alias" ]]; then
    if grep -q "^$user_alias|" "$CONFIG_FILE" 2>/dev/null; then
      local selected_profile=$(grep "^$user_alias|" "$CONFIG_FILE")
      IFS='|' read -r alias name email <<<"$selected_profile"
      if ((apply_git == 1)); then
        git config --$scope user.name "$name"
        git config --$scope user.email "$email"
      fi
      LAST_SELECTED_ALIAS="$alias"
      echo "Set to profile: Alias: $alias, Name: $name, Email: $email (Scope: $scope)"
      return
    else
      echo "Profile '$user_alias' not found."
      read -p "Create a new profile named '$user_alias'? [y/N]: " create_choice
      if [[ ! "$create_choice" =~ ^[Yy]$ ]]; then
        echo "No changes made."
        return 1
      fi
      create_new=1
      alias="$user_alias"
    fi
  fi

  # Creation flow
  if [[ $create_new -eq 1 ]]; then
    read -p "Enter git user name: " name
    read -p "Enter email: " email
    read -p "Enter alias (default: $(default_alias_from_name "$name")): " alias
    alias=${alias:-$(default_alias_from_name "$name")}

    git config --$scope user.name "$name"
    git config --$scope user.email "$email"
    echo "User information set to Name: $name, Email: $email (Scope: $scope)"

    add_user_profile "$alias" "$name" "$email"
    LAST_SELECTED_ALIAS="$alias"
  fi
}

update_user_info() {
  local user_alias=""

  ensure_storage

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
    list_profiles
    # If listing shows no profiles, exit early
    if [[ ! -s "$CONFIG_FILE" ]]; then
      return 1
    fi

    local aliases=($(awk -F'|' '{print $1}' "$CONFIG_FILE" 2>/dev/null))
    read -p "Enter alias or number to update: " user_choice
    if [[ -z "$user_choice" ]]; then
      echo "No alias provided."
      return 1
    fi

    local valid_num_regex='^[0-9]+$'
    if [[ $user_choice =~ $valid_num_regex ]] && [ "$user_choice" -ge 1 ] && [ "$user_choice" -le "${#aliases[@]}" ]; then
      user_alias="${aliases[$user_choice - 1]}"
    else
      user_alias="$user_choice"
    fi
  fi

  if grep -q "^$user_alias|" "$CONFIG_FILE" 2>/dev/null; then
    local selected_profile=$(grep "^$user_alias|" "$CONFIG_FILE")
    IFS='|' read -r alias name email <<<"$selected_profile"
    read -p "Enter alias [$alias]: " new_alias
    new_alias=${new_alias:-$alias}
    read -p "Enter git user name [$name]: " new_name
    new_name=${new_name:-$name}
    read -p "Enter email [$email]: " new_email
    new_email=${new_email:-$email}

    if [[ "$new_alias" != "$alias" ]] && grep -q "^$new_alias|" "$CONFIG_FILE" 2>/dev/null; then
      echo "Alias '$new_alias' already exists. No changes made."
      return 1
    fi

    local tmp_file
    tmp_file=$(mktemp) || {
      echo "Failed to create a temporary file for update."
      return 1
    }

    if awk -F'|' -v old_alias="$alias" -v new_alias="$new_alias" -v new_name="$new_name" -v new_email="$new_email" 'BEGIN{OFS="|"} {if($1==old_alias){$1=new_alias;$2=new_name;$3=new_email} print}' "$CONFIG_FILE" >"$tmp_file" && mv "$tmp_file" "$CONFIG_FILE"; then
      echo "Profile '$old_alias' updated to Alias: $new_alias, Name: $new_name, Email: $new_email"
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

config_auth_key() {
  local alias="$1"
  local alias_provided=0
  local auth_keys="$HOME/.ssh/authorized_keys"

  if [[ -n "$alias" ]]; then
    alias_provided=1
  fi

  mkdir -p "$HOME/.ssh"
  ensure_storage
  touch "$auth_keys"

  local lines=()
  local selectable=()
  local idx=1

  while IFS= read -r line || [[ -n "$line" ]]; do
    lines+=("$line")
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue

    local working="$line"
    local options=""
    local key_type=""
    local key_body=""
    local comment=""

    if [[ "$working" =~ ^([[:print:]]*?)\s*(ssh-[^[:space:]]+|ecdsa-[^[:space:]]+|sk-[^[:space:]]+)\s+([^[:space:]]+)([[:space:]]+(.*))?$ ]]; then
      options=$(printf '%s' "${BASH_REMATCH[1]}" | sed 's/[[:space:]]*$//')
      key_type="${BASH_REMATCH[2]}"
      key_body="${BASH_REMATCH[3]}"
      comment="${BASH_REMATCH[5]}"
    fi

    [[ -z "$key_type" || -z "$key_body" ]] && continue

    local assigned_alias=""
    if [[ -n "$options" && "$options" =~ command=\"([^\"]*)\" ]]; then
      local cmd_value="${BASH_REMATCH[1]}"
      if [[ "$cmd_value" =~ (^|[[:space:]])gutemp[[:space:]]+([^[:space:]]+)([[:space:]]|$) ]]; then
        assigned_alias="${BASH_REMATCH[2]}"
      fi
    fi

    local prefix=${key_body:0:5}
    local display_comment=${comment:-<no-comment>}
    local display_line="$idx) $key_type ${prefix}... $display_comment"
    if [[ -n "$assigned_alias" ]]; then
      display_line="$display_line -> $(highlight_text "$assigned_alias")"
    fi
    echo "$display_line"
    selectable+=("$line")
    ((idx++))
  done <"$auth_keys"

  if ((${#selectable[@]} == 0)); then
    echo "No keys found in $auth_keys."
    return 1
  fi

  local choice
  read -p "Select key number to bind: " choice
  local valid_num_regex='^[0-9]+$'
  if ! [[ $choice =~ $valid_num_regex ]] || ((choice < 1 || choice > ${#selectable[@]})); then
    echo "Invalid selection."
    return 1
  fi

  local selected_line="${selectable[$((choice - 1))]}"

  # Recompose the selected line with enforced command option
  local options=""
  local key_type=""
  local key_body=""
  local comment=""

  if [[ "$selected_line" =~ ^([[:print:]]*?)\s*(ssh-[^[:space:]]+|ecdsa-[^[:space:]]+|sk-[^[:space:]]+)\s+([^[:space:]]+)([[:space:]]+(.*))?$ ]]; then
    options=$(printf '%s' "${BASH_REMATCH[1]}" | sed 's/[[:space:]]*$//')
    key_type="${BASH_REMATCH[2]}"
    key_body="${BASH_REMATCH[3]}"
    comment="${BASH_REMATCH[5]}"
  fi

  if [[ -z "$key_type" || -z "$key_body" ]]; then
    echo "Failed to parse the selected key."
    return 1
  fi

  local had_command=0
  local existing_command=""
  if [[ -n "$options" && "$options" =~ command=\"([^\"]*)\" ]]; then
    had_command=1
    existing_command="${BASH_REMATCH[1]}"
  fi

  if [[ $had_command -eq 1 && $alias_provided -eq 0 ]]; then
    echo "Selected key already has command=\"$existing_command\"."
    read -p "Delete existing command or overwrite with gutemp alias? [d/o]: " command_choice
    if [[ "$command_choice" =~ ^[Dd]$ ]]; then
      if [[ -n "$options" ]]; then
        options=$(printf '%s' "$options" | sed 's/command="[^"]*"//g; s/^,*//; s/,*$//; s/,,*/,/g')
      fi
      local cleaned_line=""
      if [[ -n "$options" ]]; then
        cleaned_line="$options $key_type $key_body"
      else
        cleaned_line="$key_type $key_body"
      fi
      if [[ -n "$comment" ]]; then
        cleaned_line="$cleaned_line $comment"
      fi

      local tmp_file
      tmp_file=$(mktemp) || {
        echo "Failed to create temp file."
        return 1
      }

      for line in "${lines[@]}"; do
        if [[ "${line}" == "${selected_line}" ]]; then
          echo "$cleaned_line" >>"$tmp_file"
        else
          echo "$line" >>"$tmp_file"
        fi
      done

      mv "$tmp_file" "$auth_keys"
      chmod 600 "$auth_keys"
      echo "Removed existing command= from selected key; no alias binding applied."
      return 0
    elif [[ "$command_choice" =~ ^[Oo]$ ]]; then
      : # continue to overwrite path
    else
      echo "No changes made."
      return 1
    fi
  fi

  # Determine alias if not provided
  if [[ -z "$alias" ]]; then
    echo "No alias provided. Please choose or create one."
    set_user_info --no-apply
    if [[ -z "$LAST_SELECTED_ALIAS" ]]; then
      echo "Alias selection failed."
      return 1
    fi
    alias="$LAST_SELECTED_ALIAS"
  fi

  if ! grep -q "^$alias|" "$CONFIG_FILE" 2>/dev/null; then
    echo "Alias '$alias' not found in $CONFIG_FILE. Run 'gu set -u $alias' to create it first."
    return 1
  fi

  local gutemp_cmd
  gutemp_cmd=$(command -v gutemp 2>/dev/null || true)
  if [[ -z "$gutemp_cmd" ]]; then
    gutemp_cmd="/usr/local/bin/gutemp"
  fi
  if [[ ! -x "$gutemp_cmd" ]]; then
    echo "gutemp not found or not executable at $gutemp_cmd. Reinstall and try again."
    return 1
  fi

  local command_value="command=\"$gutemp_cmd $alias\""

  # Remove any existing command="..." in options before inserting ours
  if [[ -n "$options" ]]; then
    options=$(printf '%s' "$options" | sed 's/command="[^"]*"//g; s/^,*//; s/,*$//; s/,,*/,/g')
  fi

  local new_line=""
  if [[ -n "$options" ]]; then
    new_line="$command_value,$options $key_type $key_body"
  else
    new_line="$command_value $key_type $key_body"
  fi

  if [[ -n "$comment" ]]; then
    new_line="$new_line $comment"
  fi

  local tmp_file
  tmp_file=$(mktemp) || {
    echo "Failed to create temp file."
    return 1
  }

  for line in "${lines[@]}"; do
    if [[ "${line}" == "${selected_line}" ]]; then
      echo "$new_line" >>"$tmp_file"
    else
      echo "$line" >>"$tmp_file"
    fi
  done

  mv "$tmp_file" "$auth_keys"
  chmod 600 "$auth_keys"
  echo "Bound alias '$alias' to selected key via command='$gutemp_cmd $alias'."
}

config_command() {
  local mode=""
  local alias=""

  while [[ $# -gt 0 ]]; do
    case $1 in
    -k | --auth-key)
      mode="authkey"
      shift
      ;;
    -u | --user)
      alias="$2"
      shift 2
      ;;
    *)
      if [[ -z "$alias" ]]; then
        alias="$1"
      fi
      shift
      ;;
    esac
  done

  case "$mode" in
  authkey)
    config_auth_key "$alias"
    ;;
  *)
    echo "Unsupported config command. Use: gu config -k [ALIAS]"
    return 1
    ;;
  esac
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

  ensure_storage

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

  ensure_storage

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
  ensure_storage

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

  ensure_storage

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
  echo "  show                                          Show the current user info."
  echo "  list                                          List all available user profiles with the current one highlighted."
  echo "  add [-u|--user ALIAS | ALIAS]                 Add a new user profile with a unique alias."
  echo "  set [-g|--global] [-u|--user ALIAS | ALIAS]   Switch to an existing profile and apply it. If missing, optionally create."
  echo "  delete [-u|--user ALIAS | ALIAS]              Delete an existing user profile."
  echo "  update [-u|--user ALIAS | ALIAS]              Update profile alias/name/email in the config file (create on request)."
  echo "  config -k|--auth-key [ALIAS]                  Bind an SSH authorized_key entry to a gu alias via forced command."
  echo "  upgrade [-d|--develop]                        Download and install the latest version of gu (default main, -d uses develop)."
  echo "  help | -h | --help                            Show this help message and exit."
  echo "  version | -v | --version                      Show the current tool version."
  echo ""
  echo "Examples:"
  echo "  gu list                                       List all Git User profiles."
  echo "  gu show                                       Show the current Git user name and email."
  echo "  gu add work                                   Add a new Git user profile with alias 'work'."
  echo "  gu set -g                                     Set global Git user name and email interactively."
  echo "  gu set -u hnrobert                            Switch to 'hnrobert' profile or create it if not exists."
  echo "  gu set hnrobert                               Same as above without -u flag."
  echo "  gu set -g workuser                            Switch to 'workuser' profile globally."
  echo "  gu delete prev                                Delete the 'prev' user profile."
  echo "  gu update                                     Update an existing profile interactively."
  echo "  gu update -u workuser                         Update the 'workuser' profile interactively."
  echo "  gu config -k workuser                         Bind an SSH key to the 'workuser' gu alias."
  echo "  gu upgrade -d                                 Upgrade gu from the develop branch (omit -d for main)."
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
  shift
  upgrade_gu "$@"
  ;;
update)
  shift
  update_user_info "$@"
  ;;
config)
  shift
  config_command "$@"
  ;;
*)
  echo "Invalid command. Showing help:"
  show_help
  exit 1
  ;;
esac

exit 0
