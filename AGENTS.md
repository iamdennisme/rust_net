# Repository Guidelines

## Project Structure & Module Organization
- `lib/` contains the Dart SDK surface and internal layers.
- `native/rust_net_native/` contains the Rust `reqwest` core exported as a `cdylib`.
- `android/`, `ios/`, `macos/`, and `windows/` contain Flutter FFI plugin wrappers and packaged native-library locations.
- `example/` contains the macOS demo application.
- `scripts/` contains local automation such as the HTTP fixture server.
- `nginx/` contains optional local proxy configs for higher-level manual testing.
- `docker-compose.yml` starts the optional local Nginx proxy layer.
- `tooling/` contains shared local test and fixture infrastructure.
- `src/` contains the C header used by `ffigen` and a placeholder native source file for the plugin shell.

## Build, Test, and Development Commands
- `flutter pub get` installs Dart dependencies.
- `flutter pub get` in a consuming app resolves the Android/iOS/macOS/Windows FFI plugin metadata from this package.
- `dart run ffigen --config ffigen.yaml` regenerates FFI bindings from `src/rust_net.h`.
- `dart run build_runner build --delete-conflicting-outputs` regenerates `freezed` and JSON code.
- `cargo build --manifest-path native/rust_net_native/Cargo.toml` builds the Rust native library.
- `cargo test --manifest-path native/rust_net_native/Cargo.toml` runs Rust unit tests.
- `dart run scripts/http_fixture_server.dart --port 8080` starts the local HTTP fixture server.
- `docker compose up -d nginx` starts the optional local Nginx proxy.
- `bash scripts/proxy_smoke_test.sh` runs local proxy smoke checks across methods and representative status codes.
- `flutter analyze` runs Dart static analysis.
- `flutter run -d macos` runs the example app.

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
