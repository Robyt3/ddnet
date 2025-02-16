#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/compile_libs/_build_common.sh
source "${SCRIPT_DIR}/_build_common.sh"

export TARGET_PLATFORM="${1}"

function make_ffmpeg() {
	local build_folder="${1}"
	local build_arch="${2}"
	local build_cpu="${3}"
	local build_android_triple="${4}"
	local build_extra_cflags="${5}"
	local build_extra_ldflags="${6}"

	local x264_path
	x264_path=$(realpath "../x264/${build_folder}")
	if [ ! -f "${x264_path}/libx264.a" ]; then
		log_error "ERROR: compile x264 for ${build_arch} first, library file expected at ${x264_path}/libx264.a"
		exit 1
	fi

	log_info "Building to ${build_folder}..."
	mkdir -p "${build_folder}"
	(
		cd "${build_folder}"

		if [ ! -f "./Makefile" ]; then
			local extra_arguments=()
			if [[ "${TARGET_PLATFORM}" == "android" ]]; then
				extra_arguments+=("--cc=${ANDROID_TOOLCHAIN_ROOT}/bin/${build_android_triple}${ANDROID_API}-clang")
				extra_arguments+=("--cxx=${ANDROID_TOOLCHAIN_ROOT}/bin/${build_android_triple}${ANDROID_API}-clang++")
				extra_arguments+=("--sysroot=${ANDROID_TOOLCHAIN_ROOT}/sysroot")
				extra_arguments+=("--cross-prefix=${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-")
				extra_arguments+=("--target-os=android")
				extra_arguments+=("--cpu=${build_cpu}")
			elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
				extra_arguments+=("--ar=emar")
				extra_arguments+=("--as=llvm-as")
				extra_arguments+=("--cc=emcc")
				extra_arguments+=("--cxx=em++")
				extra_arguments+=("--dep-cc=emcc")
				extra_arguments+=("--objcc=emcc")
				extra_arguments+=("--sysroot=${EMSDK}/upstream/emscripten/cache/sysroot")
				extra_arguments+=("--cross-prefix=${EMSDK}/upstream/bin/llvm-")
				extra_arguments+=("--target-os=none")
			fi
			PKG_CONFIG_PATH="${x264_path}" ../configure \
				--arch="${build_arch}" \
				--enable-cross-compile \
				"${extra_arguments[@]}" \
				--pkg-config="/usr/bin/pkg-config" \
				--extra-cflags="${build_extra_cflags} -I${x264_path} -I${x264_path}/.." \
				--extra-cxxflags="${build_extra_cflags} -I${x264_path} -I${x264_path}/.." \
				--extra-ldflags="${build_extra_ldflags} -L${x264_path} -ldl" \
				--extra-libs="-lm" \
				--pkg-config-flags="--static" \
				--enable-static \
				--enable-pic \
				--disable-asm \
				--disable-all \
				--disable-network \
				--disable-doc \
				--disable-debug \
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
		make_ffmpeg "${ANDROID_ARM_BUILD_FOLDER}" "${ANDROID_ARM_ARCH}" "${ANDROID_ARM_CPU}" "${ANDROID_ARM_TRIPLE}" \
			"${ANDROID_ARM_CFLAGS}" "${ANDROID_ARM_LDFLAGS}"
		make_ffmpeg "${ANDROID_ARM64_BUILD_FOLDER}" "${ANDROID_ARM64_ARCH}" "${ANDROID_ARM64_CPU}" "${ANDROID_ARM64_TRIPLE}" \
			"${ANDROID_ARM64_CFLAGS}" "${ANDROID_ARM64_LDFLAGS}"
		make_ffmpeg "${ANDROID_X86_BUILD_FOLDER}" "${ANDROID_X86_ARCH}" "${ANDROID_X86_CPU}" "${ANDROID_X86_TRIPLE}" \
			"${ANDROID_X86_CFLAGS}" "${ANDROID_X86_LDFLAGS}"
		make_ffmpeg "${ANDROID_X64_BUILD_FOLDER}" "${ANDROID_X64_ARCH}" "${ANDROID_X64_CPU}" "${ANDROID_X64_TRIPLE}" \
			"${ANDROID_X64_CFLAGS}" "${ANDROID_X64_LDFLAGS}"
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_ffmpeg "${EMSCRIPTEN_WASM_BUILD_FOLDER}" "x86_32" "" "" \
			"${EMSCRIPTEN_WASM_CFLAGS}" "${EMSCRIPTEN_WASM_LDFLAGS}"
	else
		log_error "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_ffmpeg
