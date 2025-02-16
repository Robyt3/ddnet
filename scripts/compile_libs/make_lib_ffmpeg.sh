#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/android/_android_build_common.sh
source "${SCRIPT_DIR}/../android/_android_build_common.sh"

ANDROID_TOOLCHAIN_ROOT="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64"
export ANDROID_TOOLCHAIN_ROOT

TARGET_PLATFORM="${1}"
export TARGET_PLATFORM

function make_ffmpeg() {
	BUILD_FOLDER="${1}"
	ARCH="${2}"
	CPU="${3}"
	TOOLCHAIN_NAME="${4}"
	EXTRA_CFLAGS="${5}"
	EXTRA_LDFLAGS="${6}"
	X264_PATH=$(realpath "../x264/${BUILD_FOLDER}")
	if [ ! -f "${X264_PATH}/libx264.a" ]; then
		print "ERROR: compile x264 for ${ARCH} first, library file expected at ${X264_PATH}/libx264.a"
		exit 1
	fi

	mkdir -p "${BUILD_FOLDER}"
	(
		cd "${BUILD_FOLDER}"

		if [ ! -f "./Makefile" ]; then
			PKG_CONFIG_PATH="${X264_PATH}" ../configure \
				--sysroot="${ANDROID_TOOLCHAIN_ROOT}/sysroot" \
				--arch="${ARCH}" \
				--cpu="${CPU}" \
				--enable-cross-compile \
				--target-os="android" \
				--cross-prefix="${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-" \
				--cc="${ANDROID_TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_NAME}${ANDROID_API}-clang" \
				--cxx="${ANDROID_TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_NAME}${ANDROID_API}-clang++" \
				--pkg-config="/usr/bin/pkg-config" \
				--extra-cflags="${EXTRA_CFLAGS} -I${X264_PATH} -I${X264_PATH}/.." \
				--extra-cxxflags="${EXTRA_CFLAGS} -I${X264_PATH} -I${X264_PATH}/.." \
				--extra-ldflags="${EXTRA_LDFLAGS} -L${X264_PATH} -ldl" \
				--extra-libs="-lm" \
				--pkg-config-flags="--static" \
				--enable-static \
				--enable-shared \
				--enable-pic \
				--disable-asm \
				--disable-all \
				--disable-network \
				--disable-doc \
				--disable-debug \
				--disable-runtime-cpudetect \
				--disable-pthreads \
				--disable-vdpau \
				--disable-vaapi \
				--disable-libdrm \
				--disable-alsa \
				--disable-iconv \
				--disable-libxcb \
				--disable-libxcb-shape \
				--disable-libxcb-xfixes \
				--disable-sdl2 \
				--disable-xlib \
				--disable-zlib \
				--enable-avcodec \
				--enable-avformat \
				--enable-encoder=libx264,aac \
				--enable-muxer=mp4,mov \
				--enable-protocol=file \
				--enable-libx264 \
				--enable-swresample \
				--enable-swscale \
				--enable-gpl \
				--enable-hardcoded-tables
		fi

		make "${BUILD_FLAGS}"
	)
}

function make_all_ffmpeg() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_ffmpeg build_android_arm arm armv7-a armv7a-linux-androideabi \
			"-march=armv7a -mtune=cortex-a8 -mfloat-abi=softfp -mfpu=neon -mthumb" \
			"-march=armv7a -Wl,--fix-cortex-a8"
		make_ffmpeg build_android_arm64 arm64 armv8-a aarch64-linux-android \
			"-march=armv8-a" \
			""
		make_ffmpeg build_android_x86 x86 i686 i686-linux-android \
			"-march=i686 -msse3 -mfpmath=sse" \
			""
		make_ffmpeg build_android_x86_64 x86_64 x86-64 x86_64-linux-android \
			"-march=x86-64 -msse4.2 -mpopcnt" \
			""
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		print "ERROR: compiling ffmpeg for webasm not currently supported"
		exit 1
	else
		print "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_ffmpeg
