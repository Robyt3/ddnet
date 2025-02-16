#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/android/_android_build_common.sh
source "${SCRIPT_DIR}/../android/_android_build_common.sh"

ANDROID_TOOLCHAIN_ROOT="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64"
export ANDROID_TOOLCHAIN_ROOT

TARGET_PLATFORM="${1}"
export TARGET_PLATFORM

export CXXFLAGS="${2}"
export CFLAGS="${2}"
export CPPFLAGS="${3}"
LINKER_FLAGS="${3}"

function make_sqlite3() {
	BUILD_FOLDER="${1}"
	ANDROID_TARGET="${2}"

	mkdir -p "${BUILD_FOLDER}"
	(
		cd "${BUILD_FOLDER}"

		CC=""
		AR=""
		if [[ "${TARGET_PLATFORM}" == "android" ]]; then
			CC="${ANDROID_TOOLCHAIN_ROOT}/bin/${ANDROID_TARGET}${ANDROID_API}-clang"
			AR="${ANDROID_TOOLCHAIN_ROOT}/bin/llvm-ar"
		elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			CC="emcc"
			AR="emar"
		fi

		LDFLAGS="${LINKER_FLAGS} -L./" \
			${CC} \
			-c \
			-fPIC \
			-DSQLITE_ENABLE_ATOMIC_WRITE=1 \
			-DSQLITE_ENABLE_BATCH_ATOMIC_WRITE=1 \
			-DSQLITE_ENABLE_MULTITHREADED_CHECKS=1 \
			-DSQLITE_THREADSAFE=1 \
			../sqlite3.c \
			-o sqlite3.o

		LDFLAGS="${LINKER_FLAGS} -L./" \
			${AR} \
			rvs \
			sqlite3.a \
			sqlite3.o
	)
}

function make_all_sqlite3() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_sqlite3 build_android_arm armv7a-linux-androideabi
		make_sqlite3 build_android_arm64 aarch64-linux-android
		make_sqlite3 build_android_x86 i686-linux-android
		make_sqlite3 build_android_x86_64 x86_64-linux-android
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_sqlite3 build_webasm_wasm ""
	else
		print "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_sqlite3
