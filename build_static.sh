#!/bin/sh

#
# Synopsis:
#
#   sh build_static.sh macos - Build statically linked ARM64 macOS wheel
#
# This script builds pygit2 wheels with statically linked dependencies:
# - OpenSSL is copied from pre-built directory
# - libssh2 is built for static linking from source
# - libgit2 is built as a shared object from source with static linking its dependencies
# - The final wheel contains pygit2.dylib with all dependencies
#

set -x # Print every command and variable
set -e # Fail fast

# Variables
BUILD_TARGET=${1:-macos}
ARCH=$(uname -m)

# Paths
PROJECT_DIR=$(pwd)
BUILD_DIR="$PROJECT_DIR/build"
FAKE_PKG_CONFIG="$PROJECT_DIR/misc/pkg-config"
FORCE_STATIC_INCLUDE="$PROJECT_DIR/misc/force-static.cmake"
TEMP_WHEELS_SRC="/Users/ambv/Python/beeware-cpython-apple-source-deps/wheels"
TEMP_WHEELS_DEST="$BUILD_DIR/dependency-wheels"

if [ "$ARCH" != "arm64" ]; then
    echo "This script is designed for ARM64 architecture"
    exit 1
fi

if [ "$BUILD_TARGET" == "macos" ]; then
    export SDK="macosx"
    export GNU_ARCH="aarch64"
    export MACOSX_DEPLOYMENT_TARGET=15.0
    export CIBW_PLATFORM="macos"
    export CMAKE_SYSTEM_NAME="Darwin"
    export OPENSSL_SOURCE="/Users/ambv/Python/beeware-cpython-apple-source-deps/openssl-3.0.16-2-darwin.arm64"
    export CIBW_BUILD="cp*-${SDK}_${ARCH}"
    export CIBW_ARCHS="$ARCH"
elif [ "$BUILD_TARGET" == "simulator" ]; then
    export SDK="iphonesimulator"
    export GNU_ARCH="aarch64"
    export MACOSX_DEPLOYMENT_TARGET=13.0
    export CIBW_PLATFORM="ios"
    export CMAKE_SYSTEM_NAME="iOS"
    export OPENSSL_SOURCE="/Users/ambv/Python/beeware-cpython-apple-source-deps/openssl-3.0.16-2-iphonesimulator.arm64"
    export CIBW_BUILD="cp*-${CIBW_PLATFORM}_${ARCH}_${SDK}"
    export CIBW_ARCHS="${ARCH}_${SDK}"
else
    echo "Only 'macos' and 'simulator' target is currently supported"
    exit 1
fi

export SDK_PATH=$(xcrun --sdk $SDK --show-sdk-path)
export CIBW_ENVIRONMENT="MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET"
export CMAKE_FLAGS="-DCMAKE_SYSTEM_NAME=$CMAKE_SYSTEM_NAME -DCMAKE_SYSTEM_PROCESSOR=$GNU_ARCH -DCMAKE_OSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET -DCMAKE_OSX_SYSROOT=$SDK_PATH -DCMAKE_FIND_ROOT_PATH=$BUILD_DIR;$SDK_PATH"

# Clean and create build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Copy pre-built OpenSSL
echo "Copying OpenSSL..."
cp -r "$OPENSSL_SOURCE" "$BUILD_DIR/openssl"

# Copy temporary wheels for packages with no released iOS wheels
echo "Copying temporary wheels..."
mkdir $TEMP_WHEELS_DEST
cp -r $TEMP_WHEELS_SRC/* "$TEMP_WHEELS_DEST/"

# Clone and build libssh2
echo "Building libssh2..."
cd "$BUILD_DIR"
git clone git@github.com:libssh2/libssh2.git libssh2-src
cd libssh2-src

# Configure libssh2 with static build
cmake $CMAKE_FLAGS \
      -DBUILD_SHARED_LIBS=OFF \
      -DCRYPTO_BACKEND=OpenSSL \
      -DENABLE_ZLIB_COMPRESSION=ON \
      -DOPENSSL_ROOT_DIR="$BUILD_DIR/openssl" \
      -B build-static

# Build libssh2
cmake --build build-static
cmake --install build-static --prefix $BUILD_DIR/libssh2

# Set up environment variables for the build
export CFLAGS="-I$BUILD_DIR/openssl/include -I$BUILD_DIR/libssh2/include"
export LDFLAGS="-L$BUILD_DIR/openssl/lib -L$BUILD_DIR/libssh2/lib"

# Clone and build libgit2
echo "Building libgit2..."
cd "$BUILD_DIR"
git clone --depth 1 --branch v1.9.1 https://github.com/libgit2/libgit2.git libgit2-src
cd libgit2-src

# Configure libgit2 as shared library with statically linked dependencies
cmake $CMAKE_FLAGS \
      -DPKG_CONFIG_EXECUTABLE="$FAKE_PKG_CONFIG" \
      -DCMAKE_PROJECT_INCLUDE="$FORCE_STATIC_INCLUDE" \
      -DUSE_I18N=OFF \
      -DUSE_ICONV=OFF \
      -DLINK_WITH_STATIC_LIBRARIES=ON \
      -DBUILD_SHARED_LIBS=ON \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_TESTS=OFF \
      -DUSE_BUNDLED_ZLIB=OFF \
      -DUSE_HTTPS=OpenSSL \
      -DUSE_SSH=libssh2 \
      -DZLIB_LIBRARY=$SDK_PATH/usr/lib/libz.1.tbd \
      -B build-shared

# Build libgit2
cmake --build build-shared
cmake --install build-shared --prefix $BUILD_DIR/libgit2

# Set up Python environment
cd "$PROJECT_DIR"
echo "Setting up Python virtual environment..."
python3 -m venv "$BUILD_DIR/venv"
source "$BUILD_DIR/venv/bin/activate"

# Install cibuildwheel
pip install --upgrade pip wheel cibuildwheel

# Set up environment for pygit2 build
export LIBGIT2="$BUILD_DIR/libgit2"
export LIBGIT2_LIB="$LIBGIT2/lib"
export LIBGIT2_INCLUDE="$LIBGIT2/include"
export CFLAGS="-I$LIBGIT2_INCLUDE"
export LDFLAGS="-L$LIBGIT2_LIB -lgit2"

# Build the wheel with cibuildwheel
echo "Building pygit2 wheel..."

# Export environment variables that cibuildwheel will pass to the build
export CIBW_SKIP="cp38-* cp39-* cp310-* cp311-* cp312-* cp314t-* pp*"
export CIBW_ENVIRONMENT="$CIBW_ENVIRONMENT LIBGIT2=$LIBGIT2 LIBGIT2_LIB=$LIBGIT2_LIB CFLAGS='$CFLAGS' LDFLAGS='$LDFLAGS'"
export CIBW_BEFORE_ALL="unset PKG_CONFIG_PATH"
export CIBW_BEFORE_BUILD="pip install --no-cache-dir --pre --find-links $TEMP_WHEELS_DEST cffi==2.0.0.dev0 && pip install wheel && pip install -r requirements.txt"
export CIBW_REPAIR_WHEEL_COMMAND_MACOS="DYLD_LIBRARY_PATH=$LIBGIT2_LIB delocate-wheel -vv --require-archs {delocate_archs} -w {dest_dir} {wheel}"
# Sadly no isolation because we need this $CIBW_BEFORE_BUILD dance to work in our build venv
export CIBW_BUILD_FRONTEND="build; args: --no-isolation"

cibuildwheel

echo "Build complete. Wheels are in the wheelhouse/ directory."
