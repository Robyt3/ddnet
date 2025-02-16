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
		"${CURDIR}"/scripts/compile_libs/cmake_lib_compile.sh "${1}" "$TARGET_PLATFORM"
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
	build_cmake_lib zlib https://github.com/madler/zlib "develop"
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
build_cmake_lib sdl https://github.com/libsdl-org/SDL "release-2.32.x"

# ogg, opus, opusfile
log_info_header "Building ogg..."
build_cmake_lib ogg https://github.com/xiph/ogg "v1.3.5"
log_info_header "Building opus..."
build_cmake_lib opus https://github.com/xiph/opus "v1.5.2"
(
	log_info_header "Building opusfile..."
	_WAS_THERE_OPUSFILE=1
	if [ ! -d "opusfile" ]; then
		git clone --single-branch --branch "v0.12" https://github.com/xiph/opusfile opusfile
		_WAS_THERE_OPUSFILE=0
	fi
	cd opusfile
	if [[ "$_WAS_THERE_OPUSFILE" == 0 ]]; then
		./autogen.sh
	fi
	"${CURDIR}"/scripts/compile_libs/make_lib_opusfile.sh "$TARGET_PLATFORM"
)

# sqlite3
log_info_header "Building sqlite3..."
(
	if [ ! -d "sqlite3" ]; then
		SQLITE_ARCHIVE_FILENAME="sqlite-amalgamation-3460000.zip"
		wget "https://www.sqlite.org/2024/${SQLITE_ARCHIVE_FILENAME}"
		7z e "${SQLITE_ARCHIVE_FILENAME}" -osqlite3
		rm "${SQLITE_ARCHIVE_FILENAME}"
	fi
	(
		cd sqlite3
		"${CURDIR}"/scripts/compile_libs/make_lib_sqlite3.sh "$TARGET_PLATFORM"
	)
)

# x264
log_info_header "Building x264..."
if [ ! -d "x264" ]; then
	X264_ARCHIVE_FILENAME="x264-master.tar.bz2"
	wget "https://code.videolan.org/videolan/x264/-/archive/master/${X264_ARCHIVE_FILENAME}"
	tar xf "${X264_ARCHIVE_FILENAME}"
	mv x264-master x264
	rm "${X264_ARCHIVE_FILENAME}"
fi
(
	cd x264
	"${CURDIR}"/scripts/compile_libs/make_lib_x264.sh "$TARGET_PLATFORM"
)

# ffmpeg
log_info_header "Building ffmpeg..."
if [ ! -d "ffmpeg" ]; then
	FFMPEG_ARCHIVE_FILENAME="ffmpeg-7.0.1.tar.gz"
	wget "https://ffmpeg.org/releases/${FFMPEG_ARCHIVE_FILENAME}"
	tar xf "${FFMPEG_ARCHIVE_FILENAME}"
	mv ffmpeg-7.0.1 ffmpeg
	rm "${FFMPEG_ARCHIVE_FILENAME}"
fi
(
	cd ffmpeg
	"${CURDIR}"/scripts/compile_libs/make_lib_ffmpeg.sh "$TARGET_PLATFORM"
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

function _copy_curl() {
	mkdir -p ddnet-libs/curl/"$TARGET_PLATFORM"/"$2"
	cp compile_libs/curl/"$1"/lib/libcurl.a ddnet-libs/curl/"$TARGET_PLATFORM"/"$2"/libcurl.a
}
copy_libs_for_arches _copy_curl

function _copy_freetype() {
	mkdir -p ddnet-libs/freetype/"$TARGET_PLATFORM"/"$2"
	cp compile_libs/freetype/"$1"/libfreetype.a ddnet-libs/freetype/"$TARGET_PLATFORM"/"$2"/libfreetype.a
}
copy_libs_for_arches _copy_freetype

function _copy_sdl() {
	mkdir -p ddnet-libs/sdl/"$TARGET_PLATFORM"/"$2"
	cp compile_libs/sdl/"$1"/libSDL2.a ddnet-libs/sdl/"$TARGET_PLATFORM"/"$2"/libSDL2.a
	cp compile_libs/sdl/"$1"/libSDL2main.a ddnet-libs/sdl/"$TARGET_PLATFORM"/"$2"/libSDL2main.a
	mkdir -p ddnet-libs/sdl/include/"$TARGET_PLATFORM"
	cp -R compile_libs/sdl/include/* ddnet-libs/sdl/include/"$TARGET_PLATFORM"
}
copy_libs_for_arches _copy_sdl

# copy java code from SDL2
if [[ "$TARGET_PLATFORM" == "android" ]]; then
	rm -R -f ddnet-libs/sdl/java
	mkdir -p ddnet-libs/sdl/java
	cp -R compile_libs/sdl/android-project/app/src/main/java/org ddnet-libs/sdl/java/
fi

function _copy_opus() {
	mkdir -p ddnet-libs/opus/"$TARGET_PLATFORM"/"$2"
	cp compile_libs/ogg/"$1"/libogg.a ddnet-libs/opus/"$TARGET_PLATFORM"/"$2"/libogg.a
	cp compile_libs/opus/"$1"/libopus.a ddnet-libs/opus/"$TARGET_PLATFORM"/"$2"/libopus.a
	cp compile_libs/opusfile/"$1"/libopusfile.a ddnet-libs/opus/"$TARGET_PLATFORM"/"$2"/libopusfile.a
}
copy_libs_for_arches _copy_opus

function _copy_sqlite3() {
	mkdir -p ddnet-libs/sqlite3/"$TARGET_PLATFORM"/"$2"
	cp compile_libs/sqlite3/"$1"/sqlite3.a ddnet-libs/sqlite3/"$TARGET_PLATFORM"/"$2"/libsqlite3.a
}
copy_libs_for_arches _copy_sqlite3

function _copy_boringssl() {
	mkdir -p ddnet-libs/boringssl/"$TARGET_PLATFORM"/"$2"
	cp compile_libs/boringssl/"$1"/libcrypto.a ddnet-libs/boringssl/"$TARGET_PLATFORM"/"$2"/libcrypto.a
	cp compile_libs/boringssl/"$1"/libssl.a ddnet-libs/boringssl/"$TARGET_PLATFORM"/"$2"/libssl.a
}
copy_libs_for_arches _copy_boringssl
mkdir -p ddnet-libs/boringssl/include
cp -R compile_libs/boringssl/include/openssl ddnet-libs/boringssl/include/

# Building zlib from src/engine/external in the client does not currently
# work so we also have to copy the precompiled library to ddnet-libs.
if [[ "$TARGET_PLATFORM" == "webasm" ]]; then
	function _copy_zlib() {
		# copy headers
		(
			cd compile_libs/zlib
			find . -maxdepth 1 -iname '*.h' -print0 | while IFS= read -r -d $'\0' file; do
				mkdir -p ../../ddnet-libs/zlib/include/"$(dirname "$file")"
				cp "$file" ../../ddnet-libs/zlib/include/"$(dirname "$file")"
			done

			cd "$1"
			find . -maxdepth 1 -iname '*.h' -print0 | while IFS= read -r -d $'\0' file; do
				mkdir -p ../../../ddnet-libs/zlib/include/"$TARGET_PLATFORM"/"$(dirname "$file")"
				cp "$file" ../../../ddnet-libs/zlib/include/"$TARGET_PLATFORM"/"$(dirname "$file")"
			done
		)

		mkdir -p ddnet-libs/zlib/"$TARGET_PLATFORM"/"$2"
		cp compile_libs/zlib/"$1"/libz.a ddnet-libs/zlib/"$TARGET_PLATFORM"/"$2"/libz.a
	}
	copy_libs_for_arches _copy_zlib
fi

function _copy_png() {
	mkdir -p ddnet-libs/png/"$TARGET_PLATFORM"/"$2"
	cp compile_libs/png/"$1"/libpng16.a ddnet-libs/png/"$TARGET_PLATFORM"/"$2"/libpng16.a
}
copy_libs_for_arches _copy_png

function _copy_x264_ffmpeg() {
	mkdir -p ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/"$2"
	cp compile_libs/x264/"$1"/libx264.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/"$2"/libx264.a
	cp compile_libs/ffmpeg/"$1"/libavcodec/libavcodec.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/"$2"/libavcodec.a
	cp compile_libs/ffmpeg/"$1"/libavformat/libavformat.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/"$2"/libavformat.a
	cp compile_libs/ffmpeg/"$1"/libavutil/libavutil.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/"$2"/libavutil.a
	cp compile_libs/ffmpeg/"$1"/libswresample/libswresample.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/"$2"/libswresample.a
	cp compile_libs/ffmpeg/"$1"/libswscale/libswscale.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/"$2"/libswscale.a
}
copy_libs_for_arches _copy_x264_ffmpeg
