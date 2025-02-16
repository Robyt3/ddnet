#!/bin/bash
set -e

# Ensure that binaries from MSYS2 are preferred over Windows-native commands like find and sort which work differently.
PATH="/usr/bin/:$PATH"

# $ANDROID_HOME can be used-defined, else the default location is used. Important notes:
# - The path must not contain spaces on Windows.
# - $HOME must be used instead of ~ else cargo-ndk cannot find the folder.
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_HOME

ANDROID_NDK_ROOT="$(find "${ANDROID_HOME}/ndk" -maxdepth 1 | sort -n | tail -1)"
export ANDROID_NDK_ROOT
# ANDROID_NDK_HOME must be exported for cargo-ndk
export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"

# ANDROID_API must specify the _minimum_ supported SDK version, otherwise this will cause linking errors at launch
ANDROID_API=24
export ANDROID_API

BUILD_FLAGS="${BUILD_FLAGS:--j$(nproc)}"
export BUILD_FLAGS

COLOR_RED="\e[1;31m"
COLOR_YELLOW="\e[1;33m"
COLOR_CYAN="\e[1;36m"
COLOR_RESET="\e[0m"

log_info() {
	printf "${COLOR_CYAN}%s${COLOR_RESET}\n" "$1"
}

log_warn() {
	printf "${COLOR_YELLOW}%s${COLOR_RESET}\n" "$1" 1>&2
}

log_error() {
	printf "${COLOR_RED}%s${COLOR_RESET}\n" "$1" 1>&2
}
