#!/bin/sh

set -e

# Create an xcframework from multiple xcarchives
# Usage: create-xcframework.sh <output_path> <xcarchive1> <xcarchive2> ...

if [ $# -lt 2 ]; then
    echo "Usage: $0 <output_path> <xcarchive1> <xcarchive2> ..."
    exit 1
fi

OUTPUT_PATH=$1
shift

# Collect all framework paths
FRAMEWORK_ARGS=""
for ARCHIVE in "$@"; do
    if [ -d "$ARCHIVE" ]; then
        FRAMEWORK_PATH="$ARCHIVE/Products/Library/Frameworks/libgit2.1.9.framework"
        if [ -d "$FRAMEWORK_PATH" ]; then
            FRAMEWORK_ARGS="$FRAMEWORK_ARGS -framework $FRAMEWORK_PATH"
        else
            echo "Warning: No framework found in $ARCHIVE"
        fi
    else
        echo "Warning: Archive not found: $ARCHIVE"
    fi
done

if [ -z "$FRAMEWORK_ARGS" ]; then
    echo "Error: No valid frameworks found in the provided archives"
    exit 1
fi

# Remove existing xcframework if it exists
if [ -d "$OUTPUT_PATH" ]; then
    rm -rf "$OUTPUT_PATH"
fi

# Create the xcframework
echo "Creating xcframework at: $OUTPUT_PATH"
xcodebuild -create-xcframework $FRAMEWORK_ARGS -output "$OUTPUT_PATH"

echo "Created xcframework: $OUTPUT_PATH"