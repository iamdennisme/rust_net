# rust_net

`rust_net` is a Flutter HTTP SDK with a Rust `reqwest` execution core.

Repository: https://github.com/iamdennisme/rust_net

The public SDK surface lives in Dart. Rust is only responsible for HTTP
execution, connection reuse, timeout handling, and transport-level failures.
Compatibility layers such as a `dio` adapter belong in Dart.

## Dio Adapter

Projects already built on `Dio` can reuse `rust_net` by swapping the adapter:

```dart
import 'package:dio/dio.dart';
import 'package:rust_net/rust_net_dio.dart';

final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter.client(
    config: RustNetClientConfig(
      baseUrl: Uri.parse('https://api.example.com/'),
      timeout: const Duration(seconds: 10),
      defaultHeaders: const <String, String>{'x-sdk': 'rust_net'},
    ),
  );

final response = await dio.get<Map<String, dynamic>>('/users');
```

If you already own a custom `HttpExecutor`, wrap it directly:

```dart
final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter(
    executor: myHttpExecutor,
    closeExecutor: false,
  );
```

Current adapter behavior:

- Supported methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`
- Dio request bodies are buffered in Dart and passed to the Rust core as bytes
- Dio timeout fields are reduced to the smallest positive timeout and mapped onto
  `rust_net`'s single request timeout
- Rust client-level timeouts are surfaced to Dio as `receiveTimeout`
- Cancellation is best-effort: Dio returns a cancel error immediately, but the
  in-flight Rust request is not interrupted yet
- Redirect handling still follows the Rust `reqwest` client policy, and redirect
  history is not exposed back to Dio yet

## Consumer Project Integration

For another macOS Flutter app that already uses `Dio`, the recommended flow is:

1. Add `rust_net` and `dio` to the consuming app.
2. Package the Rust dylib into the plugin's macOS distribution directory.
3. Build or run the app normally. No `nativeLibraryPath` is required once the
   dylib has been packaged.

Consumer app `pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.9.0
  rust_net:
    path: ../rust_net
```

Package the macOS native library:

```bash
dart run rust_net:prepare_macos_native --configuration debug
```

Then wire `Dio` to `rust_net`:

```dart
import 'package:dio/dio.dart';
import 'package:rust_net/rust_net_dio.dart';

final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter.client(
    config: RustNetClientConfig(
      baseUrl: Uri.parse('http://127.0.0.1:8080'),
      timeout: const Duration(seconds: 10),
    ),
  );
```

The packaged dylib is copied to `macos/Libraries/librust_net_native.dylib`, and
the macOS plugin ships it as a resource bundle so the runtime resolver can find
it inside the built app.

For sandboxed macOS apps, make sure the Runner entitlements include
`com.apple.security.network.client`, or outbound HTTP requests will fail even
though the bundled Rust dylib loads correctly.

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
   dart run rust_net:prepare_macos_native --configuration debug
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
built Rust library in this order:

- explicit path / `RUST_NET_NATIVE_LIB_PATH`
- packaged app bundle resource on macOS
- packaged plugin distribution under `macos/Libraries/`
- local development build output under `native/rust_net_native/target/{debug,release}`

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

## Consumer Example App

A standalone consumer app that integrates `rust_net` through `Dio` lives in
`examples/rust_net_dio_consumer/`.
