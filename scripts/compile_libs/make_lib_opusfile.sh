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
export LDFLAGS="${3}"

function make_opusfile() {
	BUILD_FOLDER="${1}"
	ANDROID_TARGET="${2}"
	LIBRARY_PATH=$(realpath "..")
	OGG_INCLUDE_PATH="${LIBRARY_PATH}/ogg/${BUILD_FOLDER}/include"
	if [ ! -d "${OGG_INCLUDE_PATH}" ]; then
		print "ERROR: compile ogg for ${ARCH} first, include folder expected at ${OGG_INCLUDE_PATH}"
		exit 1
	fi

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

		${CC} \
			-c \
			-fPIC \
			-I"${PWD}"/../include \
			-I"${LIBRARY_PATH}"/ogg/include \
			-I"${LIBRARY_PATH}"/opus/include \
			-I"${OGG_INCLUDE_PATH}" \
			../src/opusfile.c \
			../src/info.c \
			../src/internal.c
		${CC} \
			-c \
			-fPIC \
			-I"${PWD}"/../include \
			-I"${LIBRARY_PATH}"/ogg/include \
			-I"${LIBRARY_PATH}"/opus/include \
			-I"${OGG_INCLUDE_PATH}" \
			-include stdio.h \
			../src/stream.c
		${AR} \
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
		make_opusfile build_android_arm armv7a-linux-androideabi
		make_opusfile build_android_arm64 aarch64-linux-android
		make_opusfile build_android_x86 i686-linux-android
		make_opusfile build_android_x86_64 x86_64-linux-android
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_opusfile build_webasm_wasm ""
	else
		print "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_opusfile
