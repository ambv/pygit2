# Building pygit2 for iOS

## Building for individual platforms

Build wheels and xcarchives for each platform:

```bash
# For iOS Simulator
./build_static.sh simulator

# For iOS Device
./build_static.sh iphone

# For macOS (optional, for universal xcframework)
./build_static.sh macos
```

Each build creates:
- A Python wheel in `wheelhouse/`
- An xcarchive containing the libgit2 Framework in `wheelhouse/`

## Creating an XCFramework

After building for all desired platforms, combine the xcarchives:

```bash
# For iOS (simulator + device)
./misc/create-xcframework.sh \
    libgit2.xcframework \
    wheelhouse/libgit2-ios-arm64-simulator.xcarchive \
    wheelhouse/libgit2-ios-arm64.xcarchive

# For universal (iOS + macOS)
./misc/create-xcframework.sh \
    libgit2.xcframework \
    wheelhouse/libgit2-ios-arm64-simulator.xcarchive \
    wheelhouse/libgit2-ios-arm64.xcarchive \
    wheelhouse/libgit2-macos-arm64.xcarchive
```

## Using in your Xcode project

1. Add the `libgit2.xcframework` to your Xcode project's Frameworks
2. Install the appropriate pygit2 wheel for your target platform
3. The pygit2 extensions will automatically find the Framework at runtime

## Notes

- The Framework uses `@rpath` for dynamic linking
- Each platform wheel is built against the same libgit2 version (1.9.1)
- OpenSSL and libssh2 are statically linked into libgit2