#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/compile_libs/_build_common.sh
source "${SCRIPT_DIR}/_build_common.sh"

export TARGET_PLATFORM="${1}"

function make_x264() {
	local build_folder="${1}"
	local build_host="${2}"
	local build_android_triple="${3}"
	local build_extra_cflags="${4}"
	local build_extra_ldflags="${5}"

	log_info "Building to ${build_folder}..."
	mkdir -p "${build_folder}"
	(
		cd "${build_folder}"

		if [ ! -f "./Makefile" ]; then
			local extra_arguments=()
			if [[ "${TARGET_PLATFORM}" == "android" ]]; then
				export CC="${ANDROID_TOOLCHAIN_ROOT}/bin/${build_android_triple}${ANDROID_API}-clang"
				export CXX="${ANDROID_TOOLCHAIN_ROOT}/bin/${build_android_triple}${ANDROID_API}-clang++"
				extra_arguments+=("--sysroot=${ANDROID_TOOLCHAIN_ROOT}/sysroot")
				extra_arguments+=("--cross-prefix=${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-")
			elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
				export CC="emcc"
				export CXX="emar"
				extra_arguments+=("--cross-prefix=${EMSDK}/upstream/bin/llvm-")
			fi
			../configure \
				--host="${build_host}" \
				"${extra_arguments[@]}" \
				--extra-cflags="${build_extra_cflags}" \
				--extra-ldflags="${build_extra_ldflags}" \
				--enable-static \
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
		make_x264 "${ANDROID_ARM_BUILD_FOLDER}" "${ANDROID_ARM_HOST}" "${ANDROID_ARM_TRIPLE}" \
			"${ANDROID_ARM_CFLAGS}" "${ANDROID_ARM_LDFLAGS}"
		make_x264 "${ANDROID_ARM64_BUILD_FOLDER}" "${ANDROID_ARM64_HOST}" "${ANDROID_ARM64_TRIPLE}" \
			"${ANDROID_ARM64_CFLAGS}" "${ANDROID_ARM64_LDFLAGS}"
		make_x264 "${ANDROID_X86_BUILD_FOLDER}" "${ANDROID_X86_HOST}" "${ANDROID_X86_TRIPLE}" \
			"${ANDROID_X86_CFLAGS}" "${ANDROID_X86_LDFLAGS}"
		make_x264 "${ANDROID_X64_BUILD_FOLDER}" "${ANDROID_X64_HOST}" "${ANDROID_X64_TRIPLE}" \
			"${ANDROID_X64_CFLAGS}" "${ANDROID_X64_LDFLAGS}"
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_x264 "${EMSCRIPTEN_WASM_BUILD_FOLDER}" "i686-gnu" "" \
			"${EMSCRIPTEN_WASM_CFLAGS}" "${EMSCRIPTEN_WASM_LDFLAGS}"
	else
		log_error "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_x264
