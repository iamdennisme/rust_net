# rust_net workspace

[English](#english) | [中文](#中文)

## English

Monorepo for the `rust_net` Dart/Flutter packages.

### Packages

- `packages/rust_net_core`: Pure Dart domain contracts and models (`RustNetRequest`, `RustNetResponse`, `RustNetException`, `HttpExecutor`, etc.).
- `packages/rust_net`: Flutter FFI transport implementation backed by Rust `reqwest`, plus `Dio` adapter integration.

### Local development

```bash
dart pub get
dart run melos bootstrap
dart run melos analyze
dart run melos test
```

### Build Native Libraries

When Rust native code changes, rebuild binaries and commit updated artifacts:

```bash
./scripts/build_native_all.sh release
git add packages/rust_net/android/src/main/jniLibs \
        packages/rust_net/ios/Frameworks \
        packages/rust_net/macos/Libraries \
        packages/rust_net/linux/Libraries \
        packages/rust_net/windows/Libraries
```

You can also build one platform at a time:

```bash
./scripts/build_native_macos.sh
./scripts/build_native_android.sh
./scripts/build_native_ios.sh
./scripts/build_native_linux.sh
./scripts/build_native_windows.sh
```

Android notes:

- The plugin prefers prebuilt `jniLibs` in the repository.
- It falls back to source build only when any ABI library is missing, or when `RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true` is set.
- Source fallback requires Rust toolchain + Android NDK on the build machine.

### Use In Flutter

`pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.9.0
  rust_net: ^0.1.0
  # optional
  rust_net_core: ^0.1.0
```

Use as a Dio adapter:

```dart
import 'package:dio/dio.dart';
import 'package:rust_net/rust_net_dio.dart';

final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter.client(
    config: RustNetClientConfig(
      baseUrl: Uri.parse('https://api.example.com/'),
      timeout: const Duration(seconds: 10),
    ),
  );
```

Use the core client directly:

```dart
import 'package:rust_net/rust_net.dart';

final client = RustNetClient(
  config: RustNetClientConfig(baseUrl: Uri.parse('https://api.example.com/')),
);
final response = await client.execute(
  RustNetRequest.get(uri: Uri(path: '/healthz')),
);
await client.close();
```

### Network Test Tooling

All local network test utilities are grouped under `fixture_server/`:

- `fixture_server/http_fixture_server.dart`
- `fixture_server/proxy_smoke_test.sh`
- `fixture_server/docker-compose.yml`
- `fixture_server/nginx/`

To run only Rust crate compile locally:

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

### Prebuilt strategy

This repository commits prebuilt native artifacts directly in source:

- Android: `packages/rust_net/android/src/main/jniLibs/*/librust_net_native.so`
- iOS: `packages/rust_net/ios/Frameworks/*.dylib`
- macOS: `packages/rust_net/macos/Libraries/librust_net_native.dylib`
- Linux: `packages/rust_net/linux/Libraries/librust_net_native.so` (for local/native validation; Linux Flutter plugin wrapper is not declared yet)
- Windows: `packages/rust_net/windows/Libraries/rust_net_native.dll`

`packages/rust_net/android/build.gradle` prefers prebuilt `jniLibs` and falls back to Rust compilation only when prebuilt files are missing.

To force source rebuild on Android:

```bash
RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true flutter build apk
```

### rust_net_core integration

`rust_net_core` remains a separate package under `packages/rust_net_core`. Consumers can reference both packages from this monorepo using git `path` dependencies (as Kino does).

## 中文

`rust_net` Dart/Flutter 包的 monorepo 工作区。

### 包结构

- `packages/rust_net_core`：纯 Dart 领域契约与模型（`RustNetRequest`、`RustNetResponse`、`RustNetException`、`HttpExecutor` 等）。
- `packages/rust_net`：基于 Rust `reqwest` 的 Flutter FFI 传输实现，并提供 `Dio` 适配器集成。

### 本地开发

```bash
dart pub get
dart run melos bootstrap
dart run melos analyze
dart run melos test
```

### 编译原生库

当 Rust 原生代码变更后，可重新编译并提交预编译产物：

```bash
./scripts/build_native_all.sh release
git add packages/rust_net/android/src/main/jniLibs \
        packages/rust_net/ios/Frameworks \
        packages/rust_net/macos/Libraries \
        packages/rust_net/linux/Libraries \
        packages/rust_net/windows/Libraries
```

也可以按平台单独编译：

```bash
./scripts/build_native_macos.sh
./scripts/build_native_android.sh
./scripts/build_native_ios.sh
./scripts/build_native_linux.sh
./scripts/build_native_windows.sh
```

Android 说明：

- 默认优先使用仓库内预编译 `jniLibs`。
- 仅在 ABI 库缺失，或设置 `RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true` 时，回退到源码编译。
- 源码回退模式需要构建机具备 Rust toolchain 和 Android NDK。

### Flutter 使用方式

`pubspec.yaml`：

```yaml
dependencies:
  dio: ^5.9.0
  rust_net: ^0.1.0
  # 可选
  rust_net_core: ^0.1.0
```

作为 Dio adapter 使用：

```dart
import 'package:dio/dio.dart';
import 'package:rust_net/rust_net_dio.dart';

final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter.client(
    config: RustNetClientConfig(
      baseUrl: Uri.parse('https://api.example.com/'),
      timeout: const Duration(seconds: 10),
    ),
  );
```

直接使用核心客户端：

```dart
import 'package:rust_net/rust_net.dart';

final client = RustNetClient(
  config: RustNetClientConfig(baseUrl: Uri.parse('https://api.example.com/')),
);
final response = await client.execute(
  RustNetRequest.get(uri: Uri(path: '/healthz')),
);
await client.close();
```

### 网络测试工具

本地网络测试工具统一放在 `fixture_server/`：

- `fixture_server/http_fixture_server.dart`
- `fixture_server/proxy_smoke_test.sh`
- `fixture_server/docker-compose.yml`
- `fixture_server/nginx/`

如果只想单独验证 Rust crate 编译：

```bash
cargo build --manifest-path packages/rust_net/native/rust_net_native/Cargo.toml
```

### 预编译策略

仓库直接提交各平台预编译产物：

- Android：`packages/rust_net/android/src/main/jniLibs/*/librust_net_native.so`
- iOS：`packages/rust_net/ios/Frameworks/*.dylib`
- macOS：`packages/rust_net/macos/Libraries/librust_net_native.dylib`
- Linux：`packages/rust_net/linux/Libraries/librust_net_native.so`（用于本地/原生验证；当前未声明 Linux Flutter plugin wrapper）
- Windows：`packages/rust_net/windows/Libraries/rust_net_native.dll`

`packages/rust_net/android/build.gradle` 会优先使用预编译 `jniLibs`，仅在缺失时回退到 Rust 编译。

如需强制 Android 源码编译：

```bash
RUST_NET_ANDROID_FORCE_SOURCE_BUILD=true flutter build apk
```

### rust_net_core 集成

`rust_net_core` 作为独立包保留在 `packages/rust_net_core`。消费方可以通过 git `path` 依赖同时引用两个包（例如 Kino）。
