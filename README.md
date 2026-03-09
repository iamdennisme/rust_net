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

All local network test utilities are grouped under `Fixture server/`:

- `Fixture server/http_fixture_server.dart`
- `Fixture server/proxy_smoke_test.sh`
- `Fixture server/docker-compose.yml`
- `Fixture server/nginx/`

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

## Publish order

1. Publish `rust_net_core`.
2. Publish `rust_net` (depends on `rust_net_core`).
