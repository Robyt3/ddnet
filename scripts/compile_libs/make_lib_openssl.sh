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

PATH="${ANDROID_TOOLCHAIN_ROOT}/bin:$PATH"

function make_openssl() {
	BUILD_FOLDER="${1}"
	TARGET_ARCH="${2}"
	TARGET_NAME="android-${TARGET_ARCH}"

	mkdir -p "${BUILD_FOLDER}"
	(
		cd "${BUILD_FOLDER}"

		if [ ! -f "./Makefile" ]; then
			if [[ "${TARGET_PLATFORM}" == "android" ]]; then
				../Configure "${TARGET_NAME}" \
					no-asm \
					no-shared \
					-D__ANDROID_API__="${ANDROID_API}"
				# We need to define __ANDROID_API__ for the configure script so it will choose the
				# correct compiler for the selected API version, but we remove it from the build flags
				# because the NDK compiler already defines it and this would cause a warning due to
				# the macro being redefined.
				sed -i "s|^CPPFLAGS=-D__ANDROID_API__=${ANDROID_API} -fPIC\$|CPPFLAGS=-fPIC|g" Makefile
			elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
				emconfigure ../Configure "${TARGET_NAME}" \
					-no-tests \
					-no-asm \
					-static \
					-no-afalgeng \
					-DOPENSSL_SYS_NETWARE \
					-DSIG_DFL=0 \
					-DSIG_IGN=0 \
					-DHAVE_FORK=0 \
					-DOPENSSL_NO_AFALGENG=1 \
					--with-rand-seed=getrandom
				sed -i 's|^CROSS_COMPILE.*$|CROSS_COMPILE=|g' Makefile
			fi
		fi

		MAKE_WRAPPER=""
		if [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			MAKE_WRAPPER="emmake"
		fi
		${MAKE_WRAPPER} make "${BUILD_FLAGS}" build_generated
		${MAKE_WRAPPER} make "${BUILD_FLAGS}" libcrypto.a
		${MAKE_WRAPPER} make "${BUILD_FLAGS}" libssl.a
	)
}

function make_all_openssl() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_openssl build_android_arm arm
		make_openssl build_android_arm64 arm64
		make_openssl build_android_x86 x86
		make_openssl build_android_x86_64 x86_64
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_openssl build_webasm_wasm linux-generic64
	else
		print "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_openssl
