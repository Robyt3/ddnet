#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/android/_android_build_common.sh
source "${SCRIPT_DIR}/../android/_android_build_common.sh"

TARGET_PLATFORM="${1}"
export TARGET_PLATFORM

# TODO: move to common file
export CXXFLAGS="${2}"
export CFLAGS="${2}"
export CPPFLAGS="${3}"
LDFLAGS="${3} -L./"
export LDFLAGS

function make_sqlite3() {
	local BUILD_FOLDER="${1}"
	local BUILD_ANDROID_TRIPLE="${2}"

	mkdir -p "${BUILD_FOLDER}"
	(
		cd "${BUILD_FOLDER}"

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
		make_sqlite3 build_android_arm "${ANDROID_ARM_TRIPLE}"
		make_sqlite3 build_android_arm64 "${ANDROID_ARM64_TRIPLE}"
		make_sqlite3 build_android_x86 "${ANDROID_X86_TRIPLE}"
		make_sqlite3 build_android_x86_64 "${ANDROID_X64_TRIPLE}"
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_sqlite3 build_webasm_wasm ""
	else
		print "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_sqlite3
