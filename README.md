# rust_net workspace

Monorepo for the `rust_net` Dart/Flutter packages.

## Packages

- `packages/rust_net_core`: Pure Dart domain contracts and models (`RustNetRequest`, `RustNetResponse`, `RustNetException`, `HttpExecutor`, etc.).
- `packages/rust_net`: Flutter FFI transport implementation backed by Rust `reqwest`, plus `Dio` adapter integration.

## Local development

```bash
dart pub get
dart run melos bootstrap
dart run melos analyze
dart run melos test
```

## Network Test Tooling

All local network test utilities are grouped under `fixture_server/`:

- `fixture_server/http_fixture_server.dart`
- `fixture_server/proxy_smoke_test.sh`
- `fixture_server/docker-compose.yml`
- `fixture_server/nginx/`

To build the native Rust library:

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

For one-by-one multi-platform builds (release by default):

```bash
./scripts/build_native_macos.sh
./scripts/build_native_android.sh
./scripts/build_native_ios.sh
./scripts/build_native_linux.sh
./scripts/build_native_windows.sh
```

Or run them sequentially with one command:

```bash
./scripts/build_native_all.sh
```

## Prebuilt strategy

This repository commits prebuilt native artifacts directly in source:

- Android: `packages/rust_net/android/src/main/jniLibs/*/librust_net_native.so`
- iOS: `packages/rust_net/ios/Frameworks/*.dylib`
- macOS: `packages/rust_net/macos/Libraries/librust_net_native.dylib`
- Linux: `packages/rust_net/linux/Libraries/librust_net_native.so` (for local/native validation; Linux Flutter plugin wrapper is not declared yet)
- Windows: `packages/rust_net/windows/Libraries/rust_net_native.dll`

`packages/rust_net/android/build.gradle` now prefers prebuilt `jniLibs` and only
falls back to Rust compilation when prebuilt files are missing.

To force source rebuild on Android:

```bash
RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true flutter build apk
```

## Update prebuilt binaries

When native code changes, rebuild locally then commit binaries:

```bash
./scripts/build_native_all.sh release
git add packages/rust_net/android/src/main/jniLibs \
        packages/rust_net/ios/Frameworks \
        packages/rust_net/macos/Libraries \
        packages/rust_net/linux/Libraries \
        packages/rust_net/windows/Libraries
```

## rust_net_core integration

`rust_net_core` remains a separate package under `packages/rust_net_core`.
Consumers can reference both packages from this monorepo using git `path`
dependencies (as Kino does).
