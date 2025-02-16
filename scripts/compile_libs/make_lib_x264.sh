#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/compile_libs/_build_common.sh
source "${SCRIPT_DIR}/_build_common.sh"

TARGET_PLATFORM="${1}"
export TARGET_PLATFORM

function make_x264() {
	local build_folder="${1}"
	local build_host="${2}"
	local build_android_triple="${3}"
	local build_extra_cflags="${4}"
	local build_extra_ldflags="${5}"

	mkdir -p "${build_folder}"
	(
		cd "${build_folder}"

		if [ ! -f "./Makefile" ]; then
			CC="${ANDROID_TOOLCHAIN_ROOT}/bin/${build_android_triple}${ANDROID_API}-clang"
			export CC
			CXX="${ANDROID_TOOLCHAIN_ROOT}/bin/${build_android_triple}${ANDROID_API}-clang++"
			export CXX
			../configure \
				--sysroot="${ANDROID_TOOLCHAIN_ROOT}/sysroot" \
				--host="${build_host}" \
				--cross-prefix="${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-" \
				--extra-cflags="${build_extra_cflags}" \
				--extra-ldflags="${build_extra_ldflags}" \
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
				--disable-swscale
		fi

		make "${BUILD_FLAGS}"
	)
}

function make_all_x264() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_x264 build_android_arm "${ANDROID_ARM_HOST}" "${ANDROID_ARM_TRIPLE}" \
			"${ANDROID_ARM_CFLAGS}" "${ANDROID_ARM_LDFLAGS}"
		make_x264 build_android_arm64 "${ANDROID_ARM64_HOST}" "${ANDROID_ARM64_TRIPLE}" \
			"${ANDROID_ARM64_CFLAGS}" "${ANDROID_ARM64_LDFLAGS}"
		make_x264 build_android_x86 "${ANDROID_X86_HOST}" "${ANDROID_X86_TRIPLE}" \
			"${ANDROID_X86_CFLAGS}" "${ANDROID_X86_LDFLAGS}"
		make_x264 build_android_x86_64 "${ANDROID_X64_HOST}" "${ANDROID_X64_TRIPLE}" \
			"${ANDROID_X64_CFLAGS}" "${ANDROID_X64_LDFLAGS}"
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		log_error "ERROR: compiling x264 for webasm not currently supported"
		exit 1
	else
		log_error "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_x264
