#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/compile_libs/_build_common.sh
source "${SCRIPT_DIR}/_build_common.sh"

export TARGET_PLATFORM="${1}"

function make_sqlite3() {
	local build_folder="${1}"
	local build_android_triple="${2}"
	local build_extra_cflags="${3}"

	log_info "Building to ${build_folder}..."
	mkdir -p "${build_folder}"
	(
		cd "${build_folder}"

		# This does not use the sqlite3 autoconf version as the ./configure script does
		# not support building a static library especially for Android/Emscripten.
		local cc=""
		local ar=""
		local extra_arguments=()
		if [[ "${TARGET_PLATFORM}" == "android" ]]; then
			cc="${ANDROID_TOOLCHAIN_ROOT}/bin/${build_android_triple}${ANDROID_API}-clang"
			ar="${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-ar"
			extra_arguments+=("-DSQLITE_ENABLE_ATOMIC_WRITE=1")
			extra_arguments+=("-DSQLITE_ENABLE_BATCH_ATOMIC_WRITE=1")
		elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			cc="emcc"
			ar="emar"
		fi

		if [[ ! -f Makefile ]]; then
			cat > Makefile << EOF
CC=${cc}
AR=${ar}
CFLAGS=${build_extra_cflags} \
	${extra_arguments[*]} \
	-DSQLITE_ENABLE_MULTITHREADED_CHECKS=1 \
	-DSQLITE_THREADSAFE=1 \
	-DSQLITE_OMIT_LOAD_EXTENSION=1

sqlite3.a: sqlite3.o
	\$(AR) rvs sqlite3.a sqlite3.o

sqlite3.o: ../sqlite3.c
	\$(CC) -c \$(CFLAGS) ../sqlite3.c -o sqlite3.o
EOF
		fi

		make "${BUILD_FLAGS}"
	)
}

function make_all_sqlite3() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_sqlite3 "${ANDROID_ARM_BUILD_FOLDER}" "${ANDROID_ARM_TRIPLE}" "${ANDROID_ARM_CFLAGS}"
		make_sqlite3 "${ANDROID_ARM64_BUILD_FOLDER}" "${ANDROID_ARM64_TRIPLE}" "${ANDROID_ARM64_CFLAGS}"
		make_sqlite3 "${ANDROID_X86_BUILD_FOLDER}" "${ANDROID_X86_TRIPLE}" "${ANDROID_X86_CFLAGS}"
		make_sqlite3 "${ANDROID_X64_BUILD_FOLDER}" "${ANDROID_X64_TRIPLE}" "${ANDROID_X64_CFLAGS}"
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_sqlite3 "${EMSCRIPTEN_WASM_BUILD_FOLDER}" "" "${EMSCRIPTEN_WASM_CFLAGS}"
	else
		log_error "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_sqlite3
