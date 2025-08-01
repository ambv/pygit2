#!/bin/sh

set -x # Print every command and variable
set -e # Fail fast

PROJECT_DIR=${1}
BUILD_DIR="$PROJECT_DIR/build"
FAKE_PKG_CONFIG="$PROJECT_DIR/misc/pkg-config"
FORCE_STATIC_INCLUDE="$PROJECT_DIR/misc/force-static.cmake"
TEMP_WHEELS_SRC="/Users/ambv/Python/beeware-cpython-apple-source-deps/wheels"
TEMP_WHEELS_DEST="$BUILD_DIR/dependency-wheels"
SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")

# Install cffi for the runtime platform of the build (will be either macOS or iPhone or iPhone simulator)
pip install --no-cache-dir --pre --find-links $TEMP_WHEELS_DEST cffi==2.0.0.dev0

# But *also* install the latest cffi for the build-time platform (always macOS)
pip install --no-cache-dir --pre --find-links $TEMP_WHEELS_DEST --ignore-installed  --no-deps --only-binary=:all: --platform macosx_11_0_arm64 --target $SITE_PACKAGES cffi==2.0.0.dev0

# Those are actually in pyproject.toml but for some reason they are not installed
pip install setuptools wheel

# Ideally this should have been all that's needed
pip install -r requirements.txt
