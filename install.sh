#!/bin/bash

set -e

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
  fi
}

update_dotfiles() {
  local dotfiles_path
  dotfiles_path="$HOME/dotfiles"

  if [ ! -d "$dotfiles_path" ]; then
    echo "Cloning 'andrewgarner/dotfiles' from GitHub ..."
    git clone --recurse-submodules https://github.com/andrewgarner/dotfiles.git dotfiles_path

    echo "Hiding '$dotfiles_path' from macOS Finder ..."
    chflags hidden "$dotfiles_path"
  fi

  echo "Installing dotfiles ..."
  sh -c "cd $dotfiles_path && ./install.sh"
}

update_packages() {
  echo "Installing or upgrading all dependencies in Brewfile ..."
  brew bundle install --global
}

update_shell() {
  local shell_name="$1"
  local shell_login"$2"
  local shell_path
  shell_path="$(command -v "$shell_name")"

  if [ "$SHELL" != shell_path ]; then
    if ! grep "$shell_path" /etc/shells >/dev/null 2>&1; then
      echo "Adding '$shell_path' to /etc/shells ..."
      sudo sh -c "echo $shell_path >> /etc/shells"
    fi

    # shellcheck disable=SC2154
    if [ -n "${shell_login}" ] && [ "$SHELL" != "$shell_path" ]; then
      echo "Changing your shell to $shell_name ..."
      sudo chsh -s "$shell_path" "$USER"
    fi
  fi
}

update_tool_versions() {
  if ! command -v asdf >/dev/null; then
    bash -c '${ASDF_DATA_DIR:=$HOME/.asdf}/plugins/nodejs/bin/import-release-team-keyring'
    asdf install
  fi
}

configure_homebrew
configure_stow
update_dotfiles
update_packages
update_shell bash
update_shell fish true
update_tool_versions