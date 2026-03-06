# rust_net

`rust_net` is a Flutter HTTP SDK with a Rust `reqwest` execution core.

The public SDK surface lives in Dart. Rust is only responsible for HTTP
execution, connection reuse, timeout handling, and transport-level failures.
Compatibility layers such as a `dio` adapter belong in Dart.

## Layout

- `lib/`: Dart SDK surface, DTOs, mappers, and the FFI data source
- `native/rust_net_native/`: Rust `cdylib` built with `reqwest`
- `example/`: minimal macOS demo application
- `src/`: C header used by `ffigen`

## Local Development

1. Build the Rust library:

   ```bash
   cargo build --manifest-path native/rust_net_native/Cargo.toml
   ```

2. Install/update Dart dependencies and regenerate code:

   ```bash
   flutter pub get
   dart run ffigen --config ffigen.yaml
   dart run build_runner build --delete-conflicting-outputs
   ```

3. Run checks:

   ```bash
   cargo test --manifest-path native/rust_net_native/Cargo.toml
   flutter analyze
   ```

4. Run the macOS example:

   ```bash
   flutter run -d macos
   ```

`RustNetClient` first honors `RUST_NET_NATIVE_LIB_PATH`, then searches for the
built Rust library under `native/rust_net_native/target/{debug,release}` by
walking up from the current working directory and the executable path.

## Local Fixture Server

Use the local fixture server instead of relying on external services:

```bash
dart run scripts/http_fixture_server.dart --port 8080
```

The example app targets `http://127.0.0.1:8080` by default. Override it with:

```bash
flutter run -d macos --dart-define=RUST_NET_EXAMPLE_BASE_URL=http://127.0.0.1:8081
```

Optional Nginx proxy config for higher-level local testing lives under
`nginx/`.

Fixture endpoints currently cover:

- `GET /healthz`
- `GET /get`
- `POST|PUT|PATCH /echo`
- `DELETE /delete`
- `HEAD /head`
- `OPTIONS /options`
- `GET /slow?delay_ms=200`
- `GET /status/{code}`
- `GET /redirect/{301|302|303|307|308}?location=/get?source=redirected`

Run the local proxy smoke matrix with:

```bash
bash scripts/proxy_smoke_test.sh
```

## Optional Nginx Proxy Layer

If you want to test reverse-proxy behavior locally:

```bash
dart run scripts/http_fixture_server.dart --port 8080
docker compose up -d nginx
```

Then point the example app at:

```bash
flutter run -d macos --dart-define=RUST_NET_EXAMPLE_BASE_URL=http://127.0.0.1:8081
```
