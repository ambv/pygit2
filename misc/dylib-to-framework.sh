#!/bin/sh

set -e

# Convert a dylib into an iOS Framework
# Usage: dylib-to-framework.sh <dylib_path> <framework_output_dir> <bundle_id>

DYLIB_PATH=$1
FRAMEWORK_OUTPUT_DIR=$2
BUNDLE_ID=$3

if [ -z "$DYLIB_PATH" ] || [ -z "$FRAMEWORK_OUTPUT_DIR" ] || [ -z "$BUNDLE_ID" ]; then
    echo "Usage: $0 <dylib_path> <framework_output_dir> <bundle_id>"
    exit 1
fi

# Extract the library name from the dylib path
DYLIB_NAME=$(basename "$DYLIB_PATH" .dylib)
FRAMEWORK_NAME="${DYLIB_NAME}.framework"
FRAMEWORK_PATH="$FRAMEWORK_OUTPUT_DIR/$FRAMEWORK_NAME"

# Create framework structure
mkdir -p "$FRAMEWORK_PATH"

# Create Info.plist
cat > "$FRAMEWORK_PATH/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>$DYLIB_NAME</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>iPhoneOS</string>
		<string>MacOSX</string>
	</array>
	<key>MinimumOSVersion</key>
	<string>13.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
</dict>
</plist>
EOF

# Copy the dylib into the framework
cp "$DYLIB_PATH" "$FRAMEWORK_PATH/$DYLIB_NAME"

# Update the install name
install_name_tool -id "@rpath/$FRAMEWORK_NAME/$DYLIB_NAME" "$FRAMEWORK_PATH/$DYLIB_NAME"

# Create dSYM file for debugging
DSYM_PATH="$FRAMEWORK_OUTPUT_DIR/$DYLIB_NAME.dSYM"
echo "Creating dSYM file..."
dsymutil "$FRAMEWORK_PATH/$DYLIB_NAME" -o "$DSYM_PATH"

# Strip debug symbols from the framework binary to avoid debug map errors
echo "Stripping debug symbols from framework..."
strip -S "$FRAMEWORK_PATH/$DYLIB_NAME"

echo "Created framework: $FRAMEWORK_PATH"
echo "Created dSYM: $DSYM_PATH"