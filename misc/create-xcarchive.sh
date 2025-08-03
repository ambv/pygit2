#!/bin/sh

set -e

# Create an xcarchive from a Framework
# Usage: create-xcarchive.sh <framework_path> <platform> <output_dir>

FRAMEWORK_PATH=$1
PLATFORM=$2
OUTPUT_DIR=$3

if [ -z "$FRAMEWORK_PATH" ] || [ -z "$PLATFORM" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <framework_path> <platform> <output_dir>"
    exit 1
fi

FRAMEWORK_NAME=$(basename "$FRAMEWORK_PATH" .framework)
ARCHIVE_NAME="${FRAMEWORK_NAME}-${PLATFORM}.xcarchive"
ARCHIVE_PATH="$OUTPUT_DIR/$ARCHIVE_NAME"

# Create xcarchive structure
mkdir -p "$ARCHIVE_PATH/Products/Library/Frameworks"
mkdir -p "$ARCHIVE_PATH/dSYMs"

# Copy the framework
cp -R "$FRAMEWORK_PATH" "$ARCHIVE_PATH/Products/Library/Frameworks/"

# Copy dSYM if it exists
DSYM_NAME="${FRAMEWORK_NAME%.framework}.dSYM"
DSYM_PATH="$(dirname "$FRAMEWORK_PATH")/$DSYM_NAME"
if [ -d "$DSYM_PATH" ]; then
    cp -R "$DSYM_PATH" "$ARCHIVE_PATH/dSYMs/"
    echo "Included dSYM: $DSYM_NAME"
fi

# Create Info.plist for the archive
cat > "$ARCHIVE_PATH/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ArchiveVersion</key>
    <integer>2</integer>
    <key>CreationDate</key>
    <date>$(date -u +%Y-%m-%dT%H:%M:%SZ)</date>
    <key>Name</key>
    <string>$FRAMEWORK_NAME</string>
    <key>SchemeName</key>
    <string>$FRAMEWORK_NAME</string>
</dict>
</plist>
EOF

echo "Created xcarchive: $ARCHIVE_PATH"