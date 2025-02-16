#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/compile_libs/_build_common.sh
source "${SCRIPT_DIR}/_build_common.sh"

TARGET_PLATFORM="${1}"
export TARGET_PLATFORM

function make_sqlite3() {
	local BUILD_FOLDER="${1}"
	local BUILD_ANDROID_TRIPLE="${2}"

	# TODO: should be unused, all c code
	export CXXFLAGS="${3}"
	export CFLAGS="${3}"
	# TODO: check if this was necessary, just avoid the exports and pass directly to compiler/linker
	#export CPPFLAGS="${4}"
	export LDFLAGS="${4} -L./"

	mkdir -p "${BUILD_FOLDER}"
	(
		cd "${BUILD_FOLDER}"

		# TODO: Switch to using ./configure and make with autoconf package instead of amalgamation
		CC=""
		AR=""
		if [[ "${TARGET_PLATFORM}" == "android" ]]; then
			CC="${ANDROID_TOOLCHAIN_ROOT}/bin/${BUILD_ANDROID_TRIPLE}${ANDROID_API}-clang"
			AR="${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-ar"
		elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			CC="emcc"
			AR="emar"
		fi

		${CC} \
			-c \
			-fPIC \
			-DSQLITE_ENABLE_ATOMIC_WRITE=1 \
			-DSQLITE_ENABLE_BATCH_ATOMIC_WRITE=1 \
			-DSQLITE_ENABLE_MULTITHREADED_CHECKS=1 \
			-DSQLITE_THREADSAFE=1 \
			-DSQLITE_OMIT_LOAD_EXTENSION=1 \
			../sqlite3.c \
			-o sqlite3.o

		${AR} \
			rvs \
			sqlite3.a \
			sqlite3.o
	)
}

function make_all_sqlite3() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_sqlite3 build_android_arm "${ANDROID_ARM_TRIPLE}" \
			"${ANDROID_ARM_CFLAGS}" "${ANDROID_ARM_LDFLAGS}"
		make_sqlite3 build_android_arm64 "${ANDROID_ARM64_TRIPLE}" \
			"${ANDROID_ARM64_CFLAGS}" "${ANDROID_ARM64_LDFLAGS}"
		make_sqlite3 build_android_x86 "${ANDROID_X86_TRIPLE}" \
			"${ANDROID_X86_CFLAGS}" "${ANDROID_X86_LDFLAGS}"
		make_sqlite3 build_android_x86_64 "${ANDROID_X64_TRIPLE}" \
			"${ANDROID_X64_CFLAGS}" "${ANDROID_X64_LDFLAGS}"
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_sqlite3 build_webasm_wasm "" \
			"${EMSCRIPTEN_WASM_CFLAGS}" "${EMSCRIPTEN_WASM_LDFLAGS}"
	else
		log_error "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_sqlite3
