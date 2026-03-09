# Repository Guidelines

## Project Structure & Module Organization
- `packages/rust_net_core/` contains pure Dart domain entities/contracts shared by integrations.
- `packages/rust_net/` contains the Flutter FFI transport package and Dio adapter.
- `packages/rust_net/native/rust_net_native/` contains the Rust `reqwest` core exported as a `cdylib`.
- `packages/rust_net/android/`, `ios/`, `macos/`, and `windows/` contain Flutter FFI plugin wrappers and packaged native-library locations.
- `packages/rust_net/example/` contains the macOS demo application.
- `packages/rust_net/scripts/` contains local automation such as the HTTP fixture server.
- `nginx/` contains optional local proxy configs for higher-level manual testing.
- `docker-compose.yml` starts the optional local Nginx proxy layer.
- `tooling/` contains shared local test and fixture infrastructure.
- `packages/rust_net/src/` contains the C header used by `ffigen` and a placeholder native source file for the plugin shell.

## Build, Test, and Development Commands
- `dart pub get` installs workspace dependencies.
- `dart run melos bootstrap` links local workspace packages.
- `dart run melos exec --scope=rust_net -- dart run ffigen --config ffigen.yaml` regenerates FFI bindings from `packages/rust_net/src/rust_net.h`.
- `dart run melos exec --scope=rust_net -- dart run build_runner build --delete-conflicting-outputs` regenerates `freezed` and JSON code.
- `cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml` builds the Rust native library.
- Android consumer builds compile and package `librust_net_native.so` during Gradle pre-build when Rust + Android NDK are available.
- `cargo test --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml` runs Rust unit tests.
- `dart run packages/rust_net/scripts/http_fixture_server.dart --port 8080` starts the local HTTP fixture server.
- `docker compose up -d nginx` starts the optional local Nginx proxy.
- `bash packages/rust_net/scripts/proxy_smoke_test.sh` runs local proxy smoke checks across methods and representative status codes.
- `dart run melos analyze` runs static analysis for all packages.
- `dart run melos test` runs tests for all packages.
- `flutter run -d macos` (from `packages/rust_net/example`) runs the example app.

## Coding Style & Naming Conventions
- Keep Dart public types small and SDK-focused; compatibility adapters belong in Dart, not Rust.
- Use `snake_case` for Rust modules, JSON keys, and file names where appropriate.
- Keep Rust FFI exports coarse-grained and stable. Avoid chatty cross-language calls.

## Testing Guidelines
- Validate Rust HTTP behavior with `cargo test`.
- Validate Dart mapping and client behavior with Flutter tests or `flutter analyze`.
- Build the Rust library before running the macOS example so the client can resolve the dynamic library.

## Security & Configuration Tips
- Use `RUST_NET_NATIVE_LIB_PATH` when the automatic native library search path is insufficient.
- Keep secrets and environment-specific endpoints out of source control.

## Agent-Specific Instructions
- Update this guide when directories, scripts, or build flows change.
