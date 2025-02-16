#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/android/_android_build_common.sh
source "${SCRIPT_DIR}/../android/_android_build_common.sh"

TARGET_PLATFORM="${1}"
export TARGET_PLATFORM

COMPILEFLAGS="${2}"
LINKFLAGS="${3}"

function make_cmake_android() {
	BUILD_FOLDER="${1}"
	ANDROID_TARGET="${2}"
	cmake \
		-H. \
		-G "Ninja" \
		-DCMAKE_BUILD_TYPE=Release \
		-DANDROID_PLATFORM="android-${ANDROID_API}" \
		-DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake" \
		-DANDROID_NDK="${ANDROID_NDK_HOME}" \
		-DANDROID_ABI="${ANDROID_TARGET}" \
		-DANDROID_ARM_NEON=TRUE \
		-DCMAKE_ANDROID_NDK="${ANDROID_NDK_HOME}" \
		-DCMAKE_SYSTEM_NAME=Android \
		-DCMAKE_SYSTEM_VERSION="$1" \
		-DCMAKE_ANDROID_ARCH_ABI="${ANDROID_TARGET}" \
		-DCMAKE_C_FLAGS="${COMPILEFLAGS}" \
		-DCMAKE_C_FLAGS_RELEASE="${COMPILEFLAGS}" \
		-DCMAKE_CXX_FLAGS="${COMPILEFLAGS}" \
		-DCMAKE_CXX_FLAGS_RELEASE="${COMPILEFLAGS}" \
		-DCMAKE_SHARED_LINKER_FLAGS="${LINKFLAGS}" \
		-DCMAKE_SHARED_LINKER_FLAGS_RELEASE="${LINKFLAGS}" \
		-B"${BUILD_FOLDER}" \
		-DBUILD_SHARED_LIBS=OFF \
		-DHIDAPI_SKIP_LIBUSB=TRUE \
		-DCURL_USE_OPENSSL=ON \
		-DSDL_HIDAPI=OFF \
		-DOP_DISABLE_HTTP=ON \
		-DOP_DISABLE_EXAMPLES=ON \
		-DOP_DISABLE_DOCS=ON \
		-DOPENSSL_ROOT_DIR="${PWD}"/../openssl/"${BUILD_FOLDER}" \
		-DOPENSSL_CRYPTO_LIBRARY="${PWD}"/../openssl/"${BUILD_FOLDER}"/libcrypto.a \
		-DOPENSSL_SSL_LIBRARY="${PWD}"/../openssl/"${BUILD_FOLDER}"/libssl.a \
		-DOPENSSL_INCLUDE_DIR="${PWD}/../openssl/include;${PWD}/../openssl/${BUILD_FOLDER}/include"
	(
		cd "${BUILD_FOLDER}"
		# We want word splitting
		# shellcheck disable=SC2086
		cmake --build . $BUILD_FLAGS
	)
}

function make_cmake_webasm() {
	BUILD_FOLDER="${1}"
	emcmake cmake \
		-H. \
		-DCMAKE_BUILD_TYPE=Release \
		-B"${BUILD_FOLDER}" \
		-DSDL_STATIC=TRUE \
		-DFT_DISABLE_HARFBUZZ=ON \
		-DFT_DISABLE_BZIP2=ON \
		-DFT_DISABLE_BROTLI=ON \
		-DFT_REQUIRE_ZLIB=TRUE \
		-DCMAKE_C_FLAGS="${COMPILEFLAGS} -DGLEW_STATIC" \
		-DCMAKE_C_FLAGS_RELEASE="${COMPILEFLAGS} -DGLEW_STATIC" \
		-DCMAKE_CXX_FLAGS="${COMPILEFLAGS}" \
		-DCMAKE_CXX_FLAGS_RELEASE="${COMPILEFLAGS}" \
		-DCMAKE_SHARED_LINKER_FLAGS="${LINKFLAGS}" \
		-DCMAKE_SHARED_LINKER_FLAGS_RELEASE="${LINKFLAGS}" \
		-DSDL_PTHREADS=ON \
		-DSDL_THREADS=ON \
		-DCURL_USE_OPENSSL=ON \
		-DOPUS_HARDENING=OFF \
		-DOPUS_STACK_PROTECTOR=OFF \
		-DOPENSSL_ROOT_DIR="${PWD}"/../openssl/"${BUILD_FOLDER}" \
		-DOPENSSL_CRYPTO_LIBRARY="${PWD}"/../openssl/"${BUILD_FOLDER}"/libcrypto.a \
		-DOPENSSL_SSL_LIBRARY="${PWD}"/../openssl/"${BUILD_FOLDER}"/libssl.a \
		-DOPENSSL_INCLUDE_DIR="${PWD}/../openssl/include;${PWD}/../openssl/${BUILD_FOLDER}/include" \
		-DZLIB_LIBRARY="${PWD}/../zlib/${BUILD_FOLDER}/libz.a" \
		-DZLIB_INCLUDE_DIR="${PWD}/../zlib;${PWD}/../zlib/${BUILD_FOLDER}"
	(
		cd "${BUILD_FOLDER}"
		# We want word splitting
		# shellcheck disable=SC2086
		cmake --build . $BUILD_FLAGS
	)
}

function make_all_cmake() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_cmake_android build_android_arm armeabi-v7a
		make_cmake_android build_android_arm64 arm64-v8a
		make_cmake_android build_android_x86 x86
		make_cmake_android build_android_x86_64 x86_64
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		sed -i "s/include(CheckSizes)//g" CMakeLists.txt
		make_cmake_webasm build_webasm_wasm
	else
		print "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_cmake
