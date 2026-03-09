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

To build the native Rust library:

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

## Publish order

1. Publish `rust_net_core`.
2. Publish `rust_net` (depends on `rust_net_core`).
