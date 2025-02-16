#!/bin/bash
set -e

CURDIR="$PWD"
if [ -z ${1+x} ]; then
	echo "Give a destination path where to run this script, please choose a path other than in the source directory"
	exit 1
fi

if [ -z ${2+x} ]; then
	echo "Specify the target platform: android, webasm"
	exit 1
fi

BUILD_FOLDER="$1"
TARGET_PLATFORM="$2"

# TODO: move all common flags to _android_build_common.sh
COMPILEFLAGS=""
LINKFLAGS=""
if [[ "${TARGET_PLATFORM}" == "android" ]]; then
	COMPILEFLAGS="-fPIC"
	LINKFLAGS="-fPIC"
elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
	COMPILEFLAGS="-pthread -O3 -g -s USE_PTHREADS=1"
	LINKFLAGS="-pthread -O3 -g -s USE_PTHREADS=1 -s ASYNCIFY=1 -s WASM=1"
else
	echo "Specify the target platform: android, webasm"
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
		"${CURDIR}"/scripts/compile_libs/cmake_lib_compile.sh "$TARGET_PLATFORM" "$COMPILEFLAGS" "$LINKFLAGS"
	)
}

mkdir -p compile_libs
cd compile_libs

# openssl
(
	if [ ! -d "openssl" ]; then
		git clone https://github.com/openssl/openssl openssl
	fi
	(
		cd openssl
		"${CURDIR}"/scripts/compile_libs/make_lib_openssl.sh "$TARGET_PLATFORM" "$COMPILEFLAGS" "$LINKFLAGS"
	)
)

# zlib is only necessary for webasm
if [[ "$TARGET_PLATFORM" == "webasm" ]]; then
	build_cmake_lib zlib https://github.com/madler/zlib
fi

build_cmake_lib png https://github.com/glennrp/libpng

build_cmake_lib curl https://github.com/curl/curl "curl-8_8_0"

build_cmake_lib freetype2 https://gitlab.freedesktop.org/freetype/freetype

build_cmake_lib sdl https://github.com/libsdl-org/SDL SDL2

# ogg, opus, opusfile
build_cmake_lib ogg https://github.com/xiph/ogg
build_cmake_lib opus https://github.com/xiph/opus
(
	_WAS_THERE_OPUSFILE=1
	if [ ! -d "opusfile" ]; then
		git clone https://github.com/xiph/opusfile opusfile
		_WAS_THERE_OPUSFILE=0
	fi
	cd opusfile
	if [[ "$_WAS_THERE_OPUSFILE" == 0 ]]; then
		./autogen.sh
	fi
	"${CURDIR}"/scripts/compile_libs/make_lib_opusfile.sh "$TARGET_PLATFORM" "$COMPILEFLAGS" "$LINKFLAGS"
)

# SQLite
(
	if [ ! -d "sqlite3" ]; then
		SQLITE_ARCHIVE_FILENAME="sqlite-amalgamation-3360000.zip"
		wget "https://www.sqlite.org/2021/${SQLITE_ARCHIVE_FILENAME}"
		7z e "${SQLITE_ARCHIVE_FILENAME}" -osqlite3
		rm "${SQLITE_ARCHIVE_FILENAME}"
	fi
	(
		cd sqlite3
		"${CURDIR}"/scripts/compile_libs/make_lib_sqlite3.sh "$TARGET_PLATFORM" "$COMPILEFLAGS" "$LINKFLAGS"
	)
)

# x264 and ffmpeg not supported for webasm yet
if [[ "$TARGET_PLATFORM" == "android" ]]; then
	# x264
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
fi

# Copy files into ddnet-libs structure
cd ..
mkdir -p ddnet-libs

function copy_arches_for_lib() {
	if [[ "${TARGET_PLATFORM}" == "android" ]]; then
		${1} arm arm
		${1} arm64 arm64
		${1} x86 32
		${1} x86_64 64
	elif [[ "${TARGET_PLATFORM}" == "webasm" ]]; then
		${1} wasm wasm
	fi
}

function _copy_curl() {
	mkdir -p ddnet-libs/curl/"$TARGET_PLATFORM"/lib"$2"
	cp compile_libs/curl/build_"$TARGET_PLATFORM"_"$1"/lib/libcurl.a ddnet-libs/curl/"$TARGET_PLATFORM"/lib"$2"/libcurl.a
}
copy_arches_for_lib _copy_curl

function _copy_freetype2() {
	mkdir -p ddnet-libs/freetype/"$TARGET_PLATFORM"/lib"$2"
	cp compile_libs/freetype2/build_"$TARGET_PLATFORM"_"$1"/libfreetype.a ddnet-libs/freetype/"$TARGET_PLATFORM"/lib"$2"/libfreetype.a
}
copy_arches_for_lib _copy_freetype2

function _copy_sdl() {
	mkdir -p ddnet-libs/sdl/"$TARGET_PLATFORM"/lib"$2"
	cp compile_libs/sdl/build_"$TARGET_PLATFORM"_"$1"/libSDL2.a ddnet-libs/sdl/"$TARGET_PLATFORM"/lib"$2"/libSDL2.a
	cp compile_libs/sdl/build_"$TARGET_PLATFORM"_"$1"/libSDL2main.a ddnet-libs/sdl/"$TARGET_PLATFORM"/lib"$2"/libSDL2main.a
	mkdir -p ddnet-libs/sdl/include/"$TARGET_PLATFORM"
	cp -R compile_libs/sdl/include/* ddnet-libs/sdl/include/"$TARGET_PLATFORM"
}
copy_arches_for_lib _copy_sdl

# copy java code from SDL2
if [[ "$TARGET_PLATFORM" == "android" ]]; then
	rm -R -f ddnet-libs/sdl/java
	mkdir -p ddnet-libs/sdl/java
	cp -R compile_libs/sdl/android-project/app/src/main/java/org ddnet-libs/sdl/java/
fi

function _copy_ogg() {
	mkdir -p ddnet-libs/opus/"$TARGET_PLATFORM"/lib"$2"
	cp compile_libs/ogg/build_"$TARGET_PLATFORM"_"$1"/libogg.a ddnet-libs/opus/"$TARGET_PLATFORM"/lib"$2"/libogg.a
}
copy_arches_for_lib _copy_ogg

function _copy_opus() {
	mkdir -p ddnet-libs/opus/"$TARGET_PLATFORM"/lib"$2"
	cp compile_libs/opus/build_"$TARGET_PLATFORM"_"$1"/libopus.a ddnet-libs/opus/"$TARGET_PLATFORM"/lib"$2"/libopus.a
}
copy_arches_for_lib _copy_opus

function _copy_opusfile() {
	mkdir -p ddnet-libs/opus/"$TARGET_PLATFORM"/lib"$2"
	cp compile_libs/opusfile/build_"$TARGET_PLATFORM"_"$1"/libopusfile.a ddnet-libs/opus/"$TARGET_PLATFORM"/lib"$2"/libopusfile.a
}
copy_arches_for_lib _copy_opusfile

function _copy_sqlite3() {
	mkdir -p ddnet-libs/sqlite3/"$TARGET_PLATFORM"/lib"$2"
	cp compile_libs/sqlite3/build_"$TARGET_PLATFORM"_"$1"/sqlite3.a ddnet-libs/sqlite3/"$TARGET_PLATFORM"/lib"$2"/libsqlite3.a
}
copy_arches_for_lib _copy_sqlite3

function _copy_openssl() {
	mkdir -p ddnet-libs/openssl/"$TARGET_PLATFORM"/lib"$2"
	mkdir -p ddnet-libs/openssl/include
	mkdir -p ddnet-libs/openssl/include/"$TARGET_PLATFORM"
	cp compile_libs/openssl/build_"$TARGET_PLATFORM"_"$1"/libcrypto.a ddnet-libs/openssl/"$TARGET_PLATFORM"/lib"$2"/libcrypto.a
	cp compile_libs/openssl/build_"$TARGET_PLATFORM"_"$1"/libssl.a ddnet-libs/openssl/"$TARGET_PLATFORM"/lib"$2"/libssl.a
	cp -R compile_libs/openssl/build_"$TARGET_PLATFORM"_"$1"/include/* ddnet-libs/openssl/include/"$TARGET_PLATFORM"
	cp -R compile_libs/openssl/include/* ddnet-libs/openssl/include
}
copy_arches_for_lib _copy_openssl

# zlib is only necessary for webasm
if [[ "$TARGET_PLATFORM" == "webasm" ]]; then
	function _copy_zlib() {
		# copy headers
		(
			cd compile_libs/zlib
			find . -maxdepth 1 -iname '*.h' -print0 | while IFS= read -r -d $'\0' file; do
				mkdir -p ../../ddnet-libs/zlib/include/"$(dirname "$file")"
				cp "$file" ../../ddnet-libs/zlib/include/"$(dirname "$file")"
			done

			cd build_"$TARGET_PLATFORM"_"$1"
			find . -maxdepth 1 -iname '*.h' -print0 | while IFS= read -r -d $'\0' file; do
				mkdir -p ../../../ddnet-libs/zlib/include/"$TARGET_PLATFORM"/"$(dirname "$file")"
				cp "$file" ../../../ddnet-libs/zlib/include/"$TARGET_PLATFORM"/"$(dirname "$file")"
			done
		)

		mkdir -p ddnet-libs/zlib/"$TARGET_PLATFORM"/lib"$2"
		cp compile_libs/zlib/build_"$TARGET_PLATFORM"_"$1"/libz.a ddnet-libs/zlib/"$TARGET_PLATFORM"/lib"$2"/libz.a
	}
	copy_arches_for_lib _copy_zlib
fi

function _copy_png() {
	mkdir -p ddnet-libs/png/"$TARGET_PLATFORM"/lib"$2"
	cp compile_libs/png/build_"$TARGET_PLATFORM"_"$1"/libpng16.a ddnet-libs/png/"$TARGET_PLATFORM"/lib"$2"/libpng16.a
}
copy_arches_for_lib _copy_png

# x264 and ffmpeg not supported for webasm yet
if [[ "$TARGET_PLATFORM" == "android" ]]; then
	function _copy_x264_ffmpeg() {
		mkdir -p ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/lib"$2"
		cp compile_libs/x264/build_"$TARGET_PLATFORM"_"$1"/libx264.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/lib"$2"/libx264.a
		cp compile_libs/ffmpeg/build_"$TARGET_PLATFORM"_"$1"/libavcodec/libavcodec.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/lib"$2"/libavcodec.a
		cp compile_libs/ffmpeg/build_"$TARGET_PLATFORM"_"$1"/libavformat/libavformat.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/lib"$2"/libavformat.a
		cp compile_libs/ffmpeg/build_"$TARGET_PLATFORM"_"$1"/libavutil/libavutil.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/lib"$2"/libavutil.a
		cp compile_libs/ffmpeg/build_"$TARGET_PLATFORM"_"$1"/libswresample/libswresample.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/lib"$2"/libswresample.a
		cp compile_libs/ffmpeg/build_"$TARGET_PLATFORM"_"$1"/libswscale/libswscale.a ddnet-libs/ffmpeg/"$TARGET_PLATFORM"/lib"$2"/libswscale.a
	}
	copy_arches_for_lib _copy_x264_ffmpeg
fi
