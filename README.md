# rust_net

[English](#english) | [中文](#中文)

## English

`rust_net` is a Flutter HTTP SDK that keeps the public API in Dart while using
Rust `reqwest` as the execution core.

### What It Does

- Executes HTTP requests in Rust
- Reuses connections and centralizes transport behavior
- Exposes a direct Dart client and a `Dio` adapter
- Surfaces the final effective URL after redirects

The intended layering is:

- Dart owns request composition, adapters, and framework integration
- Rust owns transport execution, redirect following, timeouts, and low-level failures

### Public Surfaces

- `RustNetClient`
- `RustNetRequest`
- `RustNetResponse`
- `RustNetDioAdapter`

### Dio Integration

For projects that already use `Dio`, swap only the adapter:

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
```

If you already own an `HttpExecutor`, wrap it directly:

```dart
final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter(
    executor: myHttpExecutor,
    closeExecutor: false,
  );
```

Adapter notes:

- Supported methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`
- Request bodies are buffered in Dart before being passed to Rust
- Dio timeouts are reduced to a single request timeout for `rust_net`
- Final redirect target is surfaced as `RustNetResponse.finalUri`
- For Dio callers, the final redirect target is also exposed via `x-rust-net-final-uri`
- Cancellation is still best-effort at the Dart boundary

### Platform Notes

This package now declares Flutter FFI plugin wrappers for:

- Android
- iOS
- macOS
- Windows

The macOS packaging and runtime resolution path has been verified in local
development. Android, iOS, and Windows plugin wrappers are included in the
package, but you should still validate packaging in the consuming app.

### Consumer App Setup

`pubspec.yaml`:

```yaml
dependencies:
  dio: ^5.9.0
  rust_net:
    path: ../rust_net
```

Package the macOS native library for local development:

```bash
dart run rust_net:prepare_macos_native --configuration debug
```

For sandboxed macOS apps, ensure the Runner entitlements include
`com.apple.security.network.client`.

### Repository Layout

- `lib/`: Dart SDK surface, DTOs, mappers, and integrations
- `native/rust_net_native/`: Rust `cdylib` based on `reqwest`
- `android/`, `ios/`, `macos/`, `windows/`: Flutter FFI plugin wrappers
- `example/`: local demo app
- `tooling/`: local fixture handlers and support files
- `scripts/`: development automation

### Local Development

1. Build Rust:

```bash
cargo build --manifest-path native/rust_net_native/Cargo.toml
```

2. Install dependencies and regenerate generated files:

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
flutter test
```

### Local Fixture Server

```bash
dart run scripts/http_fixture_server.dart --port 8080
```

Current fixture coverage includes:

- `GET /healthz`
- `GET /get`
- `POST|PUT|PATCH /echo`
- `DELETE /delete`
- `HEAD /head`
- `OPTIONS /options`
- `GET /slow?delay_ms=200`
- `GET /status/{code}`
- `GET /redirect/{301|302|303|307|308}?location=/get?source=redirected`

## 中文

`rust_net` 是一个 Flutter HTTP SDK。公开接口保留在 Dart 层，底层 HTTP
执行由 Rust `reqwest` 负责。

### 它解决什么问题

- 在 Rust 层执行 HTTP 请求
- 统一连接复用和传输层行为
- 同时提供直接 Dart 客户端和 `Dio` 适配器
- 暴露重定向后的最终有效 URL

推荐的分层方式是：

- Dart 负责请求组装、适配器和框架集成
- Rust 负责传输执行、重定向、超时和底层网络失败

### 对外能力

- `RustNetClient`
- `RustNetRequest`
- `RustNetResponse`
- `RustNetDioAdapter`

### 与 Dio 集成

如果消费项目已经基于 `Dio`，通常只需要替换 adapter：

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
```

如果你已经有自定义 `HttpExecutor`，也可以直接包装：

```dart
final dio = Dio()
  ..httpClientAdapter = RustNetDioAdapter(
    executor: myHttpExecutor,
    closeExecutor: false,
  );
```

当前适配器说明：

- 支持 `GET`、`POST`、`PUT`、`PATCH`、`DELETE`、`HEAD`、`OPTIONS`
- Dart 侧请求体会先缓冲成字节再传给 Rust
- Dio 多种 timeout 会收敛成 `rust_net` 的单次请求 timeout
- 最终跳转 URL 会通过 `RustNetResponse.finalUri` 暴露
- 对 Dio 调用方，还会通过 `x-rust-net-final-uri` 响应头暴露最终 URL
- 取消请求目前仍然是 Dart 边界上的 best-effort

### 平台说明

当前包已经声明以下 Flutter FFI 插件封装：

- Android
- iOS
- macOS
- Windows

其中 macOS 的打包和运行时解析链路已经在本地验证过；Android、iOS、Windows
的插件封装目录和元数据已经补齐，但仍建议在消费端项目里完成实际打包验证。

### 消费项目接入

`pubspec.yaml`：

```yaml
dependencies:
  dio: ^5.9.0
  rust_net:
    path: ../rust_net
```

本地开发时准备 macOS 原生库：

```bash
dart run rust_net:prepare_macos_native --configuration debug
```

如果是 sandboxed macOS 应用，需要确保 Runner entitlement 包含
`com.apple.security.network.client`。

### 仓库结构

- `lib/`：Dart SDK、DTO、Mapper 和集成层
- `native/rust_net_native/`：基于 `reqwest` 的 Rust `cdylib`
- `android/`、`ios/`、`macos/`、`windows/`：Flutter FFI 插件封装
- `example/`：本地 demo
- `tooling/`：本地 fixture 处理逻辑
- `scripts/`：开发脚本

### 本地开发

1. 构建 Rust：

```bash
cargo build --manifest-path native/rust_net_native/Cargo.toml
```

2. 安装依赖并刷新生成代码：

```bash
flutter pub get
dart run rust_net:prepare_macos_native --configuration debug
dart run ffigen --config ffigen.yaml
dart run build_runner build --delete-conflicting-outputs
```

3. 执行检查：

```bash
cargo test --manifest-path native/rust_net_native/Cargo.toml
flutter analyze
flutter test
```

### 本地 Fixture 服务

```bash
dart run scripts/http_fixture_server.dart --port 8080
```

当前 fixture 覆盖：

- `GET /healthz`
- `GET /get`
- `POST|PUT|PATCH /echo`
- `DELETE /delete`
- `HEAD /head`
- `OPTIONS /options`
- `GET /slow?delay_ms=200`
- `GET /status/{code}`
- `GET /redirect/{301|302|303|307|308}?location=/get?source=redirected`
