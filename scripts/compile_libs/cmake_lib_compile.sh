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
	local build_folder="${1}"
	local build_android_abi="${2}"

	local openssl_path="${PWD}/../openssl"

	cmake \
		-H. \
		-G "Ninja" \
		-DCMAKE_BUILD_TYPE=Release \
		-B"${build_folder}" \
		-DANDROID_PLATFORM="android-${ANDROID_API}" \
		-DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake" \
		-DANDROID_NDK="${ANDROID_NDK_HOME}" \
		-DANDROID_ABI="${build_android_abi}" \
		-DANDROID_ARM_NEON=TRUE \
		-DCMAKE_ANDROID_NDK="${ANDROID_NDK_HOME}" \
		-DCMAKE_SYSTEM_NAME=Android \
		-DCMAKE_SYSTEM_VERSION="${ANDROID_API}" \
		-DCMAKE_ANDROID_ARCH_ABI="${build_android_abi}" \
		-DCMAKE_C_FLAGS="${COMPILEFLAGS}" \
		-DCMAKE_C_FLAGS_RELEASE="${COMPILEFLAGS}" \
		-DCMAKE_CXX_FLAGS="${COMPILEFLAGS}" \
		-DCMAKE_CXX_FLAGS_RELEASE="${COMPILEFLAGS}" \
		-DCMAKE_SHARED_LINKER_FLAGS="${LINKFLAGS}" \
		-DCMAKE_SHARED_LINKER_FLAGS_RELEASE="${LINKFLAGS}" \
		-DBUILD_SHARED_LIBS=OFF \
		-DHIDAPI_SKIP_LIBUSB=TRUE \
		-DCURL_USE_OPENSSL=ON \
		-DSDL_HIDAPI=OFF \
		-DOP_DISABLE_HTTP=ON \
		-DOP_DISABLE_EXAMPLES=ON \
		-DOP_DISABLE_DOCS=ON \
		-DOPENSSL_ROOT_DIR="${openssl_path}/${build_folder}" \
		-DOPENSSL_CRYPTO_LIBRARY="${openssl_path}/${build_folder}/libcrypto.a" \
		-DOPENSSL_SSL_LIBRARY="${openssl_path}/${build_folder}/libssl.a" \
		-DOPENSSL_INCLUDE_DIR="${openssl_path}/include;${openssl_path}/${build_folder}/include"

	(
		cd "${build_folder}"
		# We want word splitting
		# shellcheck disable=SC2086
		cmake --build . $BUILD_FLAGS
	)
}

function make_cmake_webasm() {
	local build_folder="${1}"

	local openssl_path="${PWD}/../openssl"
	local zlib_path="${PWD}/../zlib"

	emcmake cmake \
		-H. \
		-G "Ninja" \
		-DCMAKE_BUILD_TYPE=Release \
		-B"${build_folder}" \
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
		-DPNG_STATIC=OFF \
		-DOPUS_HARDENING=OFF \
		-DOPUS_STACK_PROTECTOR=OFF \
		-DZLIB_BUILD_STATIC=OFF \
		-DOPENSSL_ROOT_DIR="${openssl_path}/${build_folder}" \
		-DOPENSSL_CRYPTO_LIBRARY="${openssl_path}/${build_folder}/libcrypto.a" \
		-DOPENSSL_SSL_LIBRARY="${openssl_path}/${build_folder}/libssl.a" \
		-DOPENSSL_INCLUDE_DIR="${openssl_path}/include;${openssl_path}/${build_folder}/include" \
		-DZLIB_LIBRARY="${zlib_path}/${build_folder}/libz.a" \
		-DZLIB_INCLUDE_DIR="${zlib_path};${zlib_path}/${build_folder}"

	(
		cd "${build_folder}"
		# We want word splitting
		# shellcheck disable=SC2086
		cmake --build . $BUILD_FLAGS
	)
}

function make_all_cmake() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_cmake_android build_android_arm "${ANDROID_ARM_ABI}"
		make_cmake_android build_android_arm64 "${ANDROID_ARM64_ABI}"
		make_cmake_android build_android_x86 "${ANDROID_X86_ABI}"
		make_cmake_android build_android_x86_64 "${ANDROID_X64_ABI}"
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		sed -i "s/include(CheckSizes)//g" CMakeLists.txt
		make_cmake_webasm build_webasm_wasm
	else
		print "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_cmake
