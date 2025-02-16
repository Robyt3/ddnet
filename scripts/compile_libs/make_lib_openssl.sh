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
export LDFLAGS="${3}"

function make_openssl() {
	local build_folder="${1}"
	local build_target_name="${2}"

	mkdir -p "${build_folder}"
	(
		cd "${build_folder}"

		PATH="${ANDROID_TOOLCHAIN_ROOT}/bin:$PATH"
		if [ ! -f "./Makefile" ]; then
			if [[ "${TARGET_PLATFORM}" == "android" ]]; then
				../Configure "${build_target_name}" \
					no-asm \
					no-shared \
					-D__ANDROID_API__="${ANDROID_API}"
				# We need to define __ANDROID_API__ for the configure script so it will choose the
				# correct compiler for the selected API version, but we remove it from the build flags
				# in the Makefile manually because the NDK compiler already defines it and this would
				# cause a warning due to the macro being redefined.
				sed -i "s|^CPPFLAGS=-D__ANDROID_API__=${ANDROID_API} -fPIC\$|CPPFLAGS=-fPIC|g" Makefile
			elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
				emconfigure ../Configure "${build_target_name}" \
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

		local make_wrapper=""
		if [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			make_wrapper="emmake"
		fi
		${make_wrapper} make "${BUILD_FLAGS}" build_generated
		${make_wrapper} make "${BUILD_FLAGS}" libcrypto.a
		${make_wrapper} make "${BUILD_FLAGS}" libssl.a
	)
}

function make_all_openssl() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_openssl build_android_arm "android-${ANDROID_ARM_ARCH}"
		make_openssl build_android_arm64 "android-${ANDROID_ARM64_ARCH}"
		make_openssl build_android_x86 "android-${ANDROID_X86_ARCH}"
		make_openssl build_android_x86_64 "android-${ANDROID_X64_ARCH}"
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_openssl build_webasm_wasm linux-generic64
	else
		print "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_openssl
