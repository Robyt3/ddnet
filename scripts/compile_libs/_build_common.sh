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
export ANDROID_TOOLCHAIN_ROOT="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64"

# ANDROID_API must specify the _minimum_ supported SDK version, otherwise this will cause linking errors at launch
ANDROID_API=24
export ANDROID_API

export ANDROID_ARM_ABI="armeabi-v7a"
export ANDROID_ARM64_ABI="arm64-v8a"
export ANDROID_X86_ABI="x86"
export ANDROID_X64_ABI="x86_64"

export ANDROID_ARM_ARCH="arm"
export ANDROID_ARM64_ARCH="arm64"
export ANDROID_X86_ARCH="x86"
export ANDROID_X64_ARCH="x86_64"

export ANDROID_ARM_CPU="armv7-a"
export ANDROID_ARM64_CPU="armv8-a"
export ANDROID_X86_CPU="i686"
export ANDROID_X64_CPU="x86-64"

export ANDROID_ARM_HOST="arm-linux"
export ANDROID_ARM64_HOST="aarch64-linux"
export ANDROID_X86_HOST="i686-linux"
export ANDROID_X64_HOST="x86_64-linux"

export ANDROID_ARM_TRIPLE="armv7a-linux-androideabi"
export ANDROID_ARM64_TRIPLE="aarch64-linux-android"
export ANDROID_X86_TRIPLE="i686-linux-android"
export ANDROID_X64_TRIPLE="x86_64-linux-android"

export ANDROID_ARM_BUILD_FOLDER="build_android_arm"
export ANDROID_ARM64_BUILD_FOLDER="build_android_arm64"
export ANDROID_X86_BUILD_FOLDER="build_android_x86"
export ANDROID_X64_BUILD_FOLDER="build_android_x86_64"

# Refer to https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md and
# build/cmake/android-legacy.toolchain.cmake in the Android NDK. These flags must be updated together
# with the NDK for libraries that cannot make use of the CMake toolchain yet.
export ANDROID_COMMON_CFLAGS="-g -DANDROID -fdata-sections -ffunction-sections -funwind-tables \
	-fstack-protector-strong -no-canonical-prefixes -D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security \
	-fPIC -O3 -DNDEBUG"
export ANDROID_ARM_CFLAGS="${ANDROID_COMMON_CFLAGS} \
	-march=armv7-a \
	-mthumb"
export ANDROID_ARM64_CFLAGS="${ANDROID_COMMON_CFLAGS}"
export ANDROID_X86_CFLAGS="${ANDROID_COMMON_CFLAGS}"
export ANDROID_X64_CFLAGS="${ANDROID_COMMON_CFLAGS}"

export ANDROID_COMMON_LDFLAGS="-static-libstdc++ -Wl,--build-id=sha1 -Wl,--no-rosegment -Wl,--no-undefined-version \
	-Wl,--fatal-warnings -Wl,--no-undefined -Qunused-arguments -fPIC -pie -Wl,--gc-sections"
export ANDROID_ARM_LDFLAGS="${ANDROID_COMMON_LDFLAGS}"
export ANDROID_ARM64_LDFLAGS="${ANDROID_COMMON_LDFLAGS} \
	-Wl,-z,max-page-size=16384"
export ANDROID_X86_LDFLAGS="${ANDROID_COMMON_LDFLAGS}"
export ANDROID_X64_LDFLAGS="${ANDROID_COMMON_LDFLAGS} \
	-Wl,-z,max-page-size=16384"

export EMSCRIPTEN_WASM_BUILD_FOLDER="build_webasm_wasm"

# Refer to https://emscripten.org/docs/tools_reference/settings_reference.html
export EMSCRIPTEN_WASM_CFLAGS="-pthread -O3 -g -s USE_PTHREADS=1"
export EMSCRIPTEN_WASM_LDFLAGS="-pthread -O3 -g -s USE_PTHREADS=1 -s ASYNCIFY=1 -s WASM=1"

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

log_info_header() {
	local header="$1"
	local len
	len=$((${#header} + 4))
	local border
	border=$(printf '%*s' "$len" '' | tr ' ' '#')
	printf "\n${COLOR_CYAN}%s\n# %s #\n%s${COLOR_RESET}\n" "$border" "$header" "$border"
}
