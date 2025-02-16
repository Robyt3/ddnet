#!/bin/bash
set -e

ANDROID_HOME=~/Android/Sdk
ANDROID_NDK_ROOT="$(find "$ANDROID_HOME/ndk" -maxdepth 1 | sort -n | tail -1)"
export ANDROID_NDK_ROOT

TOOLCHAIN_ROOT="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64"
export TOOLCHAIN_ROOT

MAKEFLAGS=-j$(nproc)
export MAKEFLAGS

ANDROID_API="${1}"
export ANDROID_API

TARGET_PLATFORM="${2}"
export TARGET_PLATFORM

function make_x264() {
	BUILD_FOLDER="${1}"
	HOST="${2}"
	TOOLCHAIN_NAME="${3}"
	EXTRA_CFLAGS="${4}"
	EXTRA_LDFLAGS="${5}"
	EXISTS_PROJECT=0
	if [ -d "${BUILD_FOLDER}" ]; then
		EXISTS_PROJECT=1
	else
		mkdir "${BUILD_FOLDER}"
	fi
	(
		# TODO: is either -fPIC or --enable--pic enough?
		cd "${BUILD_FOLDER}"
		if [[ "${EXISTS_PROJECT}" == "0" ]]; then
			CC="${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_NAME}${ANDROID_API}-clang"
			export CC
			CXX="${TOOLCHAIN_ROOT}/bin/${TOOLCHAIN_NAME}${ANDROID_API}-clang++"
			export CXX
			ASM_OPTION=""
			if [[ "${HOST}" == "i686-linux" || "${HOST}" == x86_64-linux ]]; then
				ASM_OPTION="--disable-asm"
			fi
			../configure \
				--sysroot="${TOOLCHAIN_ROOT}/sysroot" \
				--host="${HOST}" \
				--cross-prefix="${TOOLCHAIN_ROOT}/bin/llvm-" \
				--extra-cflags="-O2 -fPIC ${EXTRA_CFLAGS}" \
				--extra-cxxflags="-O2 -fPIC ${EXTRA_CFLAGS}" \
				--extra-ldflags="-O2 -fPIC ${EXTRA_LDFLAGS}" \
				--enable-static \
				--enable-shared \
				--enable-strip \
				--enable-pic \
				"${ASM_OPTION}" \
				--disable-cli \
				--disable-gpl \
				--disable-avs \
				--disable-swscale \
				--disable-lavf \
				--disable-ffms \
				--disable-gpac \
				--disable-lsmash \
				--disable-interlaced
		fi
		make "${MAKEFLAGS}"
	)
}

function compile_all_x264() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_x264 build_android_arm arm-linux armv7a-linux-androideabi \
			"-march=armv7a -mtune=cortex-a8 -mfloat-abi=softfp -mfpu=neon -mthumb" \
			"-march=armv7a -Wl,--fix-cortex-a8"
		make_x264 build_android_arm64 aarch64-linux aarch64-linux-android \
			"-march=armv8-a" \
			""
		make_x264 build_android_x86 i686-linux i686-linux-android \
			"-march=i686 -m32 -msse3 -mfpmath=sse" \
			"-m32"
		make_x264 build_android_x86_64 x86_64-linux x86_64-linux-android \
			"-march=x86-64 -m64 -msse4.2 -mpopcnt" \
			""
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		print "ERROR: compiling x264 for webasm not currently supported"
		exit 1
	else
		print "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

compile_all_x264
