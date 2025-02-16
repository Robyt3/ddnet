#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/compile_libs/_build_common.sh
source "${SCRIPT_DIR}/_build_common.sh"

TARGET_LIBRARY="${1}"
TARGET_PLATFORM="${2}"
export TARGET_PLATFORM

function make_cmake() {
	local build_folder="${1}"
	local build_extra_cflags=""
	local build_extra_ldflags=""
	local cmake_arguments=()
	local cmake_wrapper=""
	local cmake_targets=""

	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		local build_android_abi="${2}"
		cmake_arguments+=("-DANDROID_PLATFORM=android-${ANDROID_API}")
		cmake_arguments+=("-DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake")
		cmake_arguments+=("-DANDROID_NDK=${ANDROID_NDK_HOME}")
		cmake_arguments+=("-DANDROID_ABI=${build_android_abi}")
		cmake_arguments+=("-DANDROID_ARM_NEON=ON")
		cmake_arguments+=("-DANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES=ON")
		cmake_arguments+=("-DCMAKE_ANDROID_NDK=${ANDROID_NDK_HOME}")
		cmake_arguments+=("-DCMAKE_SYSTEM_NAME=Android")
		cmake_arguments+=("-DCMAKE_SYSTEM_VERSION=${ANDROID_API}")
		cmake_arguments+=("-DCMAKE_ANDROID_ARCH_ABI=${build_android_abi}")
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		cmake_wrapper="emcmake"
		build_extra_cflags="${EMSCRIPTEN_WASM_CFLAGS}"
		build_extra_ldflags="${EMSCRIPTEN_WASM_LDFLAGS}"
	fi

	if [[ "${TARGET_LIBRARY}" == "boringssl" ]]; then
		cmake_targets="--target crypto ssl"
		if [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			# BoringSSL configuration fails when specifying -O3 because this causes a warning
			# in the Emscripten compiler that is treated as an error.
			build_extra_cflags="${build_extra_cflags//"-O3"/}"
			build_extra_ldflags="${build_extra_ldflags//"-O3"/}"
			cmake_arguments+=("-DOPENSSL_NO_ASM=ON")
		fi
	elif [[ "${TARGET_LIBRARY}" == "curl" ]]; then
		local ssl_path="${PWD}/../boringssl"
		cmake_targets="--target libcurl.a"
		cmake_arguments+=("-DCURL_USE_OPENSSL=ON")
		cmake_arguments+=("-DCURL_DISABLE_DICT=ON")
		cmake_arguments+=("-DCURL_DISABLE_GOPHER=ON")
		cmake_arguments+=("-DCURL_DISABLE_IMAP=ON")
		cmake_arguments+=("-DCURL_DISABLE_POP3=ON")
		cmake_arguments+=("-DCURL_DISABLE_RTSP=ON")
		cmake_arguments+=("-DCURL_DISABLE_SMTP=ON")
		cmake_arguments+=("-DCURL_DISABLE_TELNET=ON")
		cmake_arguments+=("-DCURL_DISABLE_TFTP=ON")
		cmake_arguments+=("-DCURL_DISABLE_SMB=ON")
		cmake_arguments+=("-DCURL_DISABLE_LDAP=ON")
		cmake_arguments+=("-DCURL_ENABLE_FILE=ON")
		cmake_arguments+=("-DOPENSSL_ROOT_DIR=${ssl_path}/${build_folder}")
		cmake_arguments+=("-DOPENSSL_CRYPTO_LIBRARY=${ssl_path}/${build_folder}/libcrypto.a")
		cmake_arguments+=("-DOPENSSL_SSL_LIBRARY=${ssl_path}/${build_folder}/libssl.a")
		cmake_arguments+=("-DOPENSSL_INCLUDE_DIR=${ssl_path}/include")
	elif [[ "${TARGET_LIBRARY}" == "freetype" ]]; then
		if [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			cmake_arguments+=("-DFT_DISABLE_HARFBUZZ=ON")
			cmake_arguments+=("-DFT_DISABLE_BZIP2=ON")
			cmake_arguments+=("-DFT_DISABLE_BROTLI=ON")
			cmake_arguments+=("-DFT_REQUIRE_ZLIB=ON")
		fi
	elif [[ "${TARGET_LIBRARY}" == "ogg" ]]; then
		cmake_targets="--target ogg"
	elif [[ "${TARGET_LIBRARY}" == "opus" ]]; then
		if [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			cmake_arguments+=("-DOPUS_HARDENING=OFF")
			cmake_arguments+=("-DOPUS_STACK_PROTECTOR=OFF")
		fi
	elif [[ "${TARGET_LIBRARY}" == "png" ]]; then
		cmake_targets="--target png_shared"
		if [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			cmake_arguments+=("-DPNG_STATIC=OFF")
		fi
	elif [[ "${TARGET_LIBRARY}" == "sdl" ]]; then
		cmake_targets="--target SDL2-static SDL2main sdl_headers_copy"
		if [[ "${TARGET_PLATFORM}" == "android" ]]; then
			cmake_arguments+=("-DSDL_HIDAPI=OFF")
			cmake_arguments+=("-DHIDAPI_SKIP_LIBUSB=ON")
		elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			cmake_arguments+=("-DSDL_PTHREADS=ON")
			cmake_arguments+=("-DSDL_THREADS=ON")
			cmake_arguments+=("-DSDL_STATIC=ON")
		fi
	elif [[ "${TARGET_LIBRARY}" == "opusfile" ]]; then
		# TODO: Currently unused because https://github.com/xiph/opusfile is not a CMake project yet in the latest release version
		cmake_targets="--target opusfile"
		cmake_arguments+=("-DOP_DISABLE_HTTP=ON")
		cmake_arguments+=("-DOP_DISABLE_EXAMPLES=ON")
		cmake_arguments+=("-DOP_DISABLE_DOCS=ON")
	elif [[ "${TARGET_LIBRARY}" == "zlib" ]]; then
		cmake_targets="--target zlib"
		if [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
			cmake_arguments+=("-DZLIB_BUILD_STATIC=OFF")
		fi
	else
		log_error "ERROR: unsupported target library: ${TARGET_LIBRARY}"
		exit 1
	fi

	if [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		if [[ "${TARGET_LIBRARY}" == "curl" || "${TARGET_LIBRARY}" == "freetype" || "${TARGET_LIBRARY}" == "png" ]]; then
			local zlib_path="${PWD}/../zlib"
			cmake_arguments+=("-DZLIB_LIBRARY=${zlib_path}/${build_folder}/libz.a")
			cmake_arguments+=("-DZLIB_INCLUDE_DIR=${zlib_path};${zlib_path}/${build_folder}")
		fi
	fi

	${cmake_wrapper} cmake \
		-H. \
		-G "Ninja" \
		-DCMAKE_BUILD_TYPE=Release \
		-B"${build_folder}" \
		"${cmake_arguments[@]}" \
		-DCMAKE_C_FLAGS="${build_extra_cflags}" \
		-DCMAKE_C_FLAGS_RELEASE="${build_extra_cflags}" \
		-DCMAKE_CXX_FLAGS="${build_extra_cflags}" \
		-DCMAKE_CXX_FLAGS_RELEASE="${build_extra_cflags}" \
		-DCMAKE_EXE_LINKER_FLAGS="${build_extra_ldflags}" \
		-DCMAKE_EXE_LINKER_FLAGS_RELEASE="${build_extra_ldflags}" \
		-DCMAKE_SHARED_LINKER_FLAGS="${build_extra_ldflags}" \
		-DCMAKE_SHARED_LINKER_FLAGS_RELEASE="${build_extra_ldflags}" \
		-DBUILD_SHARED_LIBS=OFF

	(
		cd "${build_folder}"
		# We want word splitting
		# shellcheck disable=SC2086
		cmake --build . $cmake_targets $BUILD_FLAGS
	)
}

function make_all_cmake() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		make_cmake build_android_arm "${ANDROID_ARM_ABI}"
		make_cmake build_android_arm64 "${ANDROID_ARM64_ABI}"
		make_cmake build_android_x86 "${ANDROID_X86_ABI}"
		make_cmake build_android_x86_64 "${ANDROID_X64_ABI}"
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		make_cmake build_webasm_wasm ""
	else
		log_error "ERROR: unsupported target platform: ${TARGET_PLATFORM}"
		exit 1
	fi
}

make_all_cmake
