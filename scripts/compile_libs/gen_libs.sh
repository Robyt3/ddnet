#!/bin/bash
set -e

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
# shellcheck source=scripts/compile_libs/_build_common.sh
source "${SCRIPT_DIR}/_build_common.sh"

CURDIR="$PWD"
if [ -z ${1+x} ]; then
	log_error "Specify the destination path where to run this script, please choose a path other than in the source directory"
	exit 1
fi
BUILD_FOLDER="$1"

if [ -z ${2+x} ]; then
	log_error "Specify the target platform: android, webasm"
	exit 1
fi
TARGET_PLATFORM="$2"
if [[ "${TARGET_PLATFORM}" != "android" && "${TARGET_PLATFORM}" != "webasm" ]]; then
	log_error "Specify the target platform: android, webasm"
	exit 1
fi

mkdir -p "${BUILD_FOLDER}"
cd "${BUILD_FOLDER}"

function build_cmake_lib() {
	if [ ! -d "${1}" ]; then
		if [ -z ${3+x} ]; then
			git clone "${2}" "${1}"
		else
			git clone --single-branch --branch "${3}" "${2}" "${1}"
		fi
	fi
	(
		cd "${1}"
		"${SCRIPT_DIR}"/cmake_lib_compile.sh "${1}" "$TARGET_PLATFORM"
	)
}

mkdir -p compile_libs
cd compile_libs

# BoringSSL
log_info_header "Building BoringSSL..."
build_cmake_lib boringssl https://boringssl.googlesource.com/boringssl

# zlib (required to build libpng, curl and freetype for webasm)
if [[ "$TARGET_PLATFORM" == "webasm" ]]; then
	# Need to use latest develop branch as the cmake option ZLIB_BUILD_STATIC is
	# not available in the latest release v1.3.1 and the build fails without.
	log_info_header "Building zlib..."
	build_cmake_lib zlib https://github.com/madler/zlib "5a82f71ed1dfc0bec044d9702463dbdf84ea3b71"
fi

# libpng (also required to build freetype)
log_info_header "Building libpng..."
build_cmake_lib png https://github.com/glennrp/libpng "v1.6.43"

# curl
log_info_header "Building curl..."
build_cmake_lib curl https://github.com/curl/curl "curl-8_8_0"

# freetype
log_info_header "Building freetype..."
build_cmake_lib freetype https://gitlab.freedesktop.org/freetype/freetype "VER-2-13-2"

# SDL
log_info_header "Building SDL..."
build_cmake_lib sdl https://github.com/libsdl-org/SDL "release-2.32.10"

# ogg, opus, opusfile
log_info_header "Building ogg..."
build_cmake_lib ogg https://github.com/xiph/ogg "v1.3.5"
log_info_header "Building opus..."
build_cmake_lib opus https://github.com/xiph/opus "v1.5.2"
(
	log_info_header "Building opusfile..."
	local was_there_opusfile=1
	if [ ! -d "opusfile" ]; then
		git clone --single-branch --branch "v0.12" https://github.com/xiph/opusfile opusfile
		was_there_opusfile=0
	fi
	cd opusfile
	if [[ "$was_there_opusfile" == 0 ]]; then
		./autogen.sh
	fi
	"${SCRIPT_DIR}"/make_lib_opusfile.sh "$TARGET_PLATFORM"
)

# sqlite3
log_info_header "Building sqlite3..."
(
	if [ ! -d "sqlite3" ]; then
		local sqlite_archive_filename="sqlite-amalgamation-3460000.zip"
		wget "https://www.sqlite.org/2024/${sqlite_archive_filename}"
		7z e "${sqlite_archive_filename}" -osqlite3
		rm "${sqlite_archive_filename}"
	fi
	(
		cd sqlite3
		"${SCRIPT_DIR}"/make_lib_sqlite3.sh "$TARGET_PLATFORM"
	)
)

# Copy files into ddnet-libs structure
log_info_header "Copying files into ddnet-libs structure..."
cd ..
mkdir -p ddnet-libs

function copy_libs_for_arches() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		${1} "${ANDROID_ARM_BUILD_FOLDER}" libarm
		${1} "${ANDROID_ARM64_BUILD_FOLDER}" libarm64
		${1} "${ANDROID_X86_BUILD_FOLDER}" lib32
		${1} "${ANDROID_X64_BUILD_FOLDER}" lib64
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		${1} "${EMSCRIPTEN_WASM_BUILD_FOLDER}" libwasm
	fi
}

function _copy_boringssl() {
	local target_libs_folder="ddnet-libs/boringssl/$TARGET_PLATFORM/$2"
	local target_include_folder="ddnet-libs/boringssl/include/$TARGET_PLATFORM"
	mkdir -p "$target_libs_folder"
	mkdir -p "$target_include_folder"
	cp compile_libs/boringssl/"$1"/libcrypto.a "$target_libs_folder"/libcrypto.a
	cp compile_libs/boringssl/"$1"/libssl.a "$target_libs_folder"/libssl.a
	cp -R compile_libs/boringssl/include/openssl "$target_include_folder"
}
copy_libs_for_arches _copy_boringssl

if [[ "$TARGET_PLATFORM" == "webasm" ]]; then
	function _copy_zlib() {
		local target_libs_folder="ddnet-libs/zlib/$TARGET_PLATFORM/$2"
		local target_include_folder="ddnet-libs/zlib/include/$TARGET_PLATFORM"
		mkdir -p "$target_libs_folder"
		mkdir -p "$target_include_folder"
		cp compile_libs/zlib/"$1"/libz.a "$target_libs_folder"/libz.a
		cp -R compile_libs/zlib/*.h "$target_include_folder"
		cp -R compile_libs/zlib/"$1"/*.h "$target_include_folder"
	}
	copy_libs_for_arches _copy_zlib
fi

function _copy_png() {
	local target_libs_folder="ddnet-libs/png/$TARGET_PLATFORM/$2"
	mkdir -p "$target_libs_folder"
	cp compile_libs/png/"$1"/libpng16.a "$target_libs_folder"/libpng16.a
}
copy_libs_for_arches _copy_png

function _copy_curl() {
	local target_libs_folder="ddnet-libs/curl/$TARGET_PLATFORM/$2"
	mkdir -p "$target_libs_folder"
	cp compile_libs/curl/"$1"/lib/libcurl.a "$target_libs_folder"/libcurl.a
}
copy_libs_for_arches _copy_curl

function _copy_freetype() {
	local target_libs_folder="ddnet-libs/freetype/$TARGET_PLATFORM/$2"
	mkdir -p "$target_libs_folder"
	cp compile_libs/freetype/"$1"/libfreetype.a "$target_libs_folder"/libfreetype.a
}
copy_libs_for_arches _copy_freetype

function _copy_sdl() {
	local target_libs_folder="ddnet-libs/sdl/$TARGET_PLATFORM/$2"
	local target_include_folder="ddnet-libs/sdl/include/$TARGET_PLATFORM"
	mkdir -p "$target_libs_folder"
	mkdir -p "$target_include_folder"
	cp compile_libs/sdl/"$1"/libSDL2.a "$target_libs_folder"/libSDL2.a
	cp -R compile_libs/sdl/include/* "$target_include_folder"
}
copy_libs_for_arches _copy_sdl

# copy java code from SDL2
if [[ "$TARGET_PLATFORM" == "android" ]]; then
	local target_java_folder="ddnet-libs/sdl/java"
	rm -R -f "$target_java_folder"
	mkdir -p "$target_java_folder"
	cp -R compile_libs/sdl/android-project/app/src/main/java/org "$target_java_folder"/
fi

function _copy_opus() {
	local target_libs_folder="ddnet-libs/opus/$TARGET_PLATFORM/$2"
	mkdir -p "$target_libs_folder"
	cp compile_libs/ogg/"$1"/libogg.a "$target_libs_folder"/libogg.a
	cp compile_libs/opus/"$1"/libopus.a "$target_libs_folder"/libopus.a
	cp compile_libs/opusfile/"$1"/libopusfile.a "$target_libs_folder"/libopusfile.a
}
copy_libs_for_arches _copy_opus

function _copy_sqlite3() {
	local target_libs_folder="ddnet-libs/sqlite3/$TARGET_PLATFORM/$2"
	mkdir -p "$target_libs_folder"
	cp compile_libs/sqlite3/"$1"/sqlite3.a "$target_libs_folder"/libsqlite3.a
}
copy_libs_for_arches _copy_sqlite3
