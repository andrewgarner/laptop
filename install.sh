#!/bin/bash

set -e

ask() {
  # https://djm.me/ask
  local prompt default reply

  if [ "${2:-}" = "Y" ]; then
    prompt="Y/n"
    default=Y
  elif [ "${2:-}" = "N" ]; then
    prompt="y/N"
    default=N
  else
    prompt="y/n"
    default=
  fi

  while true; do

    # Ask the question (not using "read -p" as it uses stderr not stdout)
    echo -n "$1 [$prompt] "

    # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
    read -r reply </dev/tty

    # Default?
    if [ -z "$reply" ]; then
      reply=$default
    fi

    # Check if the reply is valid
    case "$reply" in
    Y* | y*) return 0 ;;
    N* | n*) return 1 ;;
    esac

  done
}

configure_homebrew() {
  if ! command -v brew >/dev/null; then
    echo "Installing Homebrew ..."
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh | sh
  else
    echo "Updating Homebrew ..."
    brew update
  fi
}

configure_stow() {
  if ! command -v stow >/dev/null; then
    echo "Installing GNU Stow ..."
    brew install stow
    echo
  fi
}

configure_sudo_touchid() {
  if ! grep "pam_tid" /etc/pam.d/sudo >/dev/null 2>&1; then
    echo "Configuring Touch ID for sudo ..."
    brew install gnu-sed --quiet
    sudo sh -c "gsed -i '2 i auth       sufficient     pam_tid.so' /etc/pam.d/sudo"
    echo
  fi
}

update_dotfiles() {
  local dotfiles_path
  dotfiles_path="$HOME/dotfiles"

  if [ ! -d "$dotfiles_path" ]; then
    echo "Cloning 'andrewgarner/dotfiles' from GitHub ..."
    git clone --recurse-submodules https://github.com/andrewgarner/dotfiles.git "$dotfiles_path"
    echo

    echo "Hiding '$dotfiles_path' from macOS Finder ..."
    chflags hidden "$dotfiles_path"
    echo
  fi

  echo "Installing dotfiles ..."
  sh -c "cd $dotfiles_path && ./install.sh"
  echo
}

update_packages() {
  echo "Installing or upgrading all dependencies in global Brewfile ..."
  brew bundle install --global
  echo

  if ask "Do you want to install or upgrade all dependencies in developer Brewfile?" Y; then
    brew bundle install --file=~/dotfiles/brew/.Brewfile-developer
    echo
  fi

  if ask "Do you want to install or upgrade all dependencies in personal Brewfile?" N; then
    brew bundle install --file=~/dotfiles/brew/.Brewfile-personal
    echo
  fi

  echo "Cleaning up outdated downloads and old versions of installed formulae ..."
  brew cleanup
  echo
}

update_shell() {
  local shell_name="$1"
  local shell_login="$2"
  local shell_path
  shell_path="$(command -v "$shell_name")"

  if [ "$SHELL" != "$shell_path" ]; then
    if ! grep "$shell_path" /etc/shells >/dev/null 2>&1; then
      echo "Adding '$shell_path' to /etc/shells ..."
      sudo sh -c "echo $shell_path >> /etc/shells"
      echo
    fi

    # shellcheck disable=SC2154
    if [ -n "$shell_login" ] && [ "$SHELL" != "$shell_path" ]; then
      echo "Changing your shell to $shell_name ..."
      sudo chsh -s "$shell_path" "$USER"
      echo
    fi
  fi
}

update_tool_versions() {
  if command -v asdf >/dev/null; then
    while read -r plugin _; do
      if ! asdf plugin list | grep "$plugin" >/dev/null 2>&1; then
        echo "Installing $plugin asdf plugin"
        asdf plugin add "$plugin"
        echo

        if [ "$plugin" == "nodejs" ]; then
          echo "Importing the Node.js release team's OpenPGP keys to main keyring ..."
          bash -c '${ASDF_DATA_DIR:=$HOME/.asdf}/plugins/nodejs/bin/import-release-team-keyring'
          echo
        fi
      fi
    done <"$HOME/.tool-versions"

    echo "Updating asdf plugins ..."
    asdf plugin update --all
    echo

    echo "Installing default tool versions ..."
    asdf install
    echo
  fi
}

configure_homebrew
configure_stow
configure_sudo_touchid
update_dotfiles
update_packages
update_shell bash
update_shell fish true
update_tool_versions
