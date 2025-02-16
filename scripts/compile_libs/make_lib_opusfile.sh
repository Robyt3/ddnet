#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/compile_libs/_build_common.sh
source "${SCRIPT_DIR}/_build_common.sh"

TARGET_PLATFORM="${1}"
export TARGET_PLATFORM

function make_opusfile() {
	local build_folder="${1}"
	local build_android_triple="${2}"
	# TODO: should be unused, all c code
	export CXXFLAGS="${3}"
	export CFLAGS="${3}"
	# TODO: check if this was necessary, just avoid the exports and pass directly to compiler/linker
	#export CPPFLAGS="${4}"
	export LDFLAGS="${4}"

	local library_path
	library_path=$(realpath "..")
	local ogg_include_path="${library_path}/ogg/include"
	if [ ! -d "${ogg_include_path}" ]; then
		log_error "ERROR: download ogg first, include folder expected at ${ogg_include_path}"
		exit 1
	fi
	local opus_include_path="${library_path}/opus/include"
	if [ ! -d "${opus_include_path}" ]; then
		log_error "ERROR: download opus for first, include folder expected at ${opus_include_path}"
		exit 1
	fi
	local ogg_include_path_build="${library_path}/ogg/${build_folder}/include"
	if [ ! -d "${ogg_include_path_build}" ]; then
		log_error "ERROR: compile ogg for ${build_android_triple} first, include folder expected at ${ogg_include_path_build}"
		exit 1
	fi

	mkdir -p "${build_folder}"
	(
		cd "${build_folder}"

		# TODO: use ./configure to generate Makefile?
		local cc=""
		local ar=""
		if [[ "${TARGET_PLATFORM}" == "android" ]]; then
			cc="${ANDROID_TOOLCHAIN_ROOT}/bin/${build_android_triple}${ANDROID_API}-clang"
			ar="${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-ar"
		elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			cc="emcc"
			ar="emar"
		fi

		${cc} \
			-c \
			-fPIC \
			-I"${PWD}"/../include \
			-I"${ogg_include_path}" \
			-I"${opus_include_path}" \
			-I"${ogg_include_path_build}" \
			../src/opusfile.c \
			../src/info.c \
			../src/internal.c
		${cc} \
			-c \
			-fPIC \
			-I"${PWD}"/../include \
			-I"${ogg_include_path}" \
			-I"${opus_include_path}" \
			-I"${ogg_include_path_build}" \
			-include stdio.h \
			../src/stream.c
		${ar} \
			rvs \
			libopusfile.a \
			opusfile.o \
			info.o \
			stream.o \
			internal.o
	)
}

function make_all_opusfile() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_opusfile build_android_arm "${ANDROID_ARM_TRIPLE}" \
			"${ANDROID_ARM_CFLAGS}" "${ANDROID_ARM_LDFLAGS}"
		make_opusfile build_android_arm64 "${ANDROID_ARM64_TRIPLE}" \
			"${ANDROID_ARM64_CFLAGS}" "${ANDROID_ARM64_LDFLAGS}"
		make_opusfile build_android_x86 "${ANDROID_X86_TRIPLE}" \
			"${ANDROID_X86_CFLAGS}" "${ANDROID_X86_LDFLAGS}"
		make_opusfile build_android_x86_64 "${ANDROID_X64_TRIPLE}" \
			"${ANDROID_X64_CFLAGS}" "${ANDROID_X64_LDFLAGS}"
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_opusfile build_webasm_wasm "" \
			"${EMSCRIPTEN_WASM_CFLAGS}" "${EMSCRIPTEN_WASM_LDFLAGS}"
	else
		log_error "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_opusfile
