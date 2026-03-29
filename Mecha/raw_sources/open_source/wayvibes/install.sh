#!/bin/env bash
# Wayvibes Auto-Installer - Downloads and installs wayvibes from GitHub

set -e

REPO_URL="https://github.com/sahaj-b/wayvibes"
INSTALL_DIR="$HOME/wayvibes"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

ensure_prerequisites() {
  if ! command -v git &>/dev/null; then
    echo -e "${RED}❌ Git is not installed.${RESET}"
    exit 1
  fi

  if ! command -v make &>/dev/null; then
    echo -e "${RED}❌ Make is not installed.${RESET}"
    exit 1
  fi
}

install_dependencies() {
  echo -e "${CYAN}🔧 Install dependencies...${RESET}"

  DISTRO_PACKAGES=""
  INSTALL_CMD_PREFIX=""

  if command -v apt &>/dev/null; then
    echo -e "${CYAN}📦 Detected Debian/Ubuntu-based system${RESET}"
    DISTRO_PACKAGES="libevdev-dev nlohmann-json3-dev"
    INSTALL_CMD_PREFIX="sudo apt update && sudo apt install -y"
  elif command -v pacman &>/dev/null; then
    echo -e "${CYAN}📦 Detected Arch-based system${RESET}"
    DISTRO_PACKAGES="libevdev nlohmann-json"
    INSTALL_CMD_PREFIX="sudo pacman -S --needed --noconfirm"
  elif command -v dnf &>/dev/null; then
    echo -e "${CYAN}📦 Detected Fedora-based system${RESET}"
    DISTRO_PACKAGES="libevdev-devel nlohmann-json-devel"
    INSTALL_CMD_PREFIX="sudo dnf install -y"
  else
    echo -e "${YELLOW}⚠️ Could not detect a supported package manager (apt, pacman, dnf).${RESET}"
    echo -e "${YELLOW}Please ensure the following dependencies for your distribution:${RESET}"
    echo -e "${CYAN}  - Debian/Ubuntu: libevdev-dev nlohmann-json3-dev${RESET}"
    echo -e "${CYAN}  - Arch: libevdev nlohmann-json${RESET}"
    echo -e "${CYAN}  - Fedora: libevdev-devel nlohmann-json-devel${RESET}"
    echo -e "${CYAN}  - RPM: libevdev-devel nlohmann_json-devel${RESET}"
    echo -ne "${CYAN}Ensured? (y/n): ${RESET}"
    read -r ENSURED
    if ! [[ "$ENSURED" =~ ^[Yy]$ ]]; then
      echo -e "${RED}Exiting due to missing dependencies.${RESET}"
      exit 1
    fi
    return
  fi

  if [ -n "$INSTALL_CMD_PREFIX" ] && [ -n "$DISTRO_PACKAGES" ]; then
    echo -e "${YELLOW}Executing: $INSTALL_CMD_PREFIX $DISTRO_PACKAGES${RESET}"
    # Using subshell to capture status without set -e exiting prematurely from the main script
    (eval "$INSTALL_CMD_PREFIX $DISTRO_PACKAGES")
    INSTALL_STATUS=$?
    if [ $INSTALL_STATUS -ne 0 ]; then
      echo -e "${RED}❌ Failed to install dependencies with command: $INSTALL_CMD_PREFIX $DISTRO_PACKAGES${RESET}"
      echo -e "${RED}Please try installing them manually and re-run the script.${RESET}"
      exit 1
    else
      echo -e "${GREEN}✅ Done.${RESET}"
    fi
  fi
}

clone_and_build() {
  if [ -d "$INSTALL_DIR" ]; then
    echo -ne "\n${CYAN}Wayvibes directory already exists. Do you want to remove it and continue? (y/n): ${RESET}"
    read -r REMOVE_CHOICE
    if ! [[ "$REMOVE_CHOICE" =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}Exiting without changes.${RESET}"
      exit 0
    fi
    echo -e "${YELLOW}🗑️  Removing existing wayvibes installation...${RESET}"
    rm -rf "$INSTALL_DIR"
  fi

  echo -e "${CYAN}📥 Cloning wayvibes repository...${RESET}"
  git clone "$REPO_URL" "$INSTALL_DIR"
  cd "$INSTALL_DIR"

  echo -e "${CYAN}🔨 Building with make...${RESET}"

  if ! make; then
    echo -e "${RED}❌ Build failed.${RESET}"
    exit 1
  else
    echo -e "${GREEN}✅ Build successful!${RESET}"
  fi
}

add_to_path() {
  echo -ne "\n${CYAN}Do you want to install wayvibes system-wide? (adds to PATH, RECOMMENDED) (y/n): ${RESET}"
  read -r INSTALL_CHOICE
  if [[ "$INSTALL_CHOICE" =~ ^[Yy]$ ]]; then
    sudo make install
    echo -e "${GREEN}✅ wayvibes installed to /usr/local/bin/${RESET}"
    return 0
  fi
  echo -e "${YELLOW}You can run it from $INSTALL_DIR/wayvibes.${RESET}"
  return 1
}

auto_start_setup() {
  echo -ne "\n${CYAN}Do you want to add wayvibes cmd to '~/.profile' for auto-starting? (y/n): ${RESET}"
  read -r PROFILE_CHOICE

  if [[ "$PROFILE_CHOICE" =~ ^[Yy]$ ]]; then
    # Try to find a soundpack directory (first subdir with config.json)
    SOUNDPACK_PATH=""
    for d in "$INSTALL_DIR"/*/; do
      if [ -f "$d/config.json" ]; then
        SOUNDPACK_PATH="$d"
        break
      fi
    done
    if [ -z "$SOUNDPACK_PATH" ]; then
      echo -e "${RED}Could not find a soundpack directory (with config.json) in $INSTALL_DIR.${RESET}"
      echo -ne "\n${CYAN}Please enter the full path to your soundpack: ${RESET}"
      read -r SOUNDPACK_PATH
      if [ ! -d "$SOUNDPACK_PATH" ] || [ ! -f "$SOUNDPACK_PATH/config.json" ]; then
        echo -e "${RED}❌ Invalid soundpack.${RESET}"
        echo -e "${RED}Wayvibes will not be added for auto-starting${RESET}"
        SOUNDPACK_PATH=""
      fi
    fi
    if [ -n "$SOUNDPACK_PATH" ]; then
      CMD="wayvibes \"$SOUNDPACK_PATH\" -v 3 -bg"
      if ! grep -Fxq "$CMD" ~/.profile; then
        echo "$CMD" >>~/.profile
        echo -en "${GREEN}✅ Added to ~/.profile:${RESET}"
        echo -e "${CYAN}$CMD${RESET}"
      else
        echo -e "${YELLOW}Command already present in ~/.profile${RESET}"
      fi
    fi
  else
    echo -e "${YELLOW}Skipping auto-start setup...${RESET}"
  fi
}

ensure_input_group() {
  if ! grep -q "^input:" /etc/group; then
    echo -e "${YELLOW}\nInput group does not exist.${RESET}"
    echo -e "${YELLOW}Creating 'input' group...${RESET}"
    sudo groupadd input
  fi

  if ! id -nG "$USER" | grep -qw "input"; then
    echo -e "${YELLOW}\n'$USER' is not in 'input' group.${RESET}"
    sudo usermod -aG input "$USER"
    echo -e "${GREEN}✅ User added to 'input' group.${RESET}"
  else
    echo -e "${GREEN}\n✅ '$USER' is already in 'input' group.${RESET}"
  fi
}

echo -e "${YELLOW}--- Wayvibes Auto-Installer ---${RESET}"
echo -e "${CYAN}Downloading from: $REPO_URL${RESET}\n"

ensure_prerequisites
install_dependencies
clone_and_build
ensure_input_group

if add_to_path; then
  auto_start_setup
fi

echo -e "${GREEN}\n🎉 Wayvibes is ready to vibe!${RESET}"
echo -e "${CYAN}Run 'wayvibes --help' for usage instructions${RESET}"
