#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/android/_android_build_common.sh
source "${SCRIPT_DIR}/../android/_android_build_common.sh"

ANDROID_TOOLCHAIN_ROOT="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64"
export ANDROID_TOOLCHAIN_ROOT

TARGET_PLATFORM="${1}"
export TARGET_PLATFORM

function make_x264() {
	BUILD_FOLDER="${1}"
	TARGET_HOST="${2}"
	TOOLCHAIN_NAME="${3}"
	EXTRA_CFLAGS="${4}"
	EXTRA_LDFLAGS="${5}"

	mkdir -p "${BUILD_FOLDER}"
	(
		cd "${BUILD_FOLDER}"

		if [ ! -f "./Makefile" ]; then
			CC="${ANDROID_TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_NAME}${ANDROID_API}-clang"
			export CC
			CXX="${ANDROID_TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_NAME}${ANDROID_API}-clang++"
			export CXX
			../configure \
				--sysroot="${ANDROID_TOOLCHAIN_ROOT}/sysroot" \
				--host="${TARGET_HOST}" \
				--cross-prefix="${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-" \
				--extra-cflags="${EXTRA_CFLAGS}" \
				--extra-ldflags="${EXTRA_LDFLAGS}" \
				--enable-static \
				--enable-shared \
				--enable-strip \
				--enable-pic \
				--disable-asm \
				--disable-avs \
				--disable-cli \
				--disable-ffms \
				--disable-gpac \
				--disable-gpl \
				--disable-interlaced \
				--disable-lavf \
				--disable-lsmash \
				--disable-opencl \
				--disable-swscale \
				--disable-thread
		fi

		make "${BUILD_FLAGS}"
	)
}

function make_all_x264() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_x264 build_android_arm arm-linux armv7a-linux-androideabi \
			"-march=armv7a -mtune=cortex-a8 -mfloat-abi=softfp -mfpu=neon -mthumb" \
			"-march=armv7a -Wl,--fix-cortex-a8"
		make_x264 build_android_arm64 aarch64-linux aarch64-linux-android \
			"-march=armv8-a" \
			""
		make_x264 build_android_x86 i686-linux i686-linux-android \
			"-march=i686 -msse3 -mfpmath=sse" \
			""
		make_x264 build_android_x86_64 x86_64-linux x86_64-linux-android \
			"-march=x86-64 -msse4.2 -mpopcnt" \
			""
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		print "ERROR: compiling x264 for webasm not currently supported"
		exit 1
	else
		print "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_x264
