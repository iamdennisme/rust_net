import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rust_net/rust_net.dart';
import 'package:rust_net/src/data/dto/native_http_client_config_dto.dart';
import 'package:rust_net/src/data/dto/native_http_error_dto.dart';
import 'package:rust_net/src/data/dto/native_http_request_dto.dart';
import 'package:rust_net/src/data/dto/native_http_response_dto.dart';
import 'package:rust_net/src/data/dto/native_http_result_dto.dart';
import 'package:rust_net/src/data/sources/rust_net_native_data_source.dart';

void main() {
  test('resolves relative URLs and maps successful responses', () async {
    final dataSource = _FakeRustNetNativeDataSource(
      result: NativeHttpResultDto.success(
        response: NativeHttpResponseDto(
          statusCode: 200,
          headers: const <String, List<String>>{
            'content-type': <String>['application/json'],
          },
          bodyBase64: base64Encode(utf8.encode('ok')),
        ),
      ),
    );

    final client = RustNetClient(
      config: RustNetClientConfig(
        baseUrl: Uri.parse('https://example.com/api/'),
        defaultHeaders: const <String, String>{'x-sdk': 'rust-net'},
        userAgent: 'rust-net-test',
      ),
      dataSource: dataSource,
    );

    final response = await client.execute(
      RustNetRequest.get(uri: Uri.parse('users')),
    );

    expect(dataSource.lastRequest?.url, 'https://example.com/api/users');
    expect(dataSource.lastRequest?.headers['x-sdk'], 'rust-net');
    expect(dataSource.lastRequest?.headers['user-agent'], 'rust-net-test');
    expect(response.statusCode, 200);
    expect(response.bodyText, 'ok');
  });

  test('maps native transport errors to RustNetException', () async {
    final client = RustNetClient(
      dataSource: _FakeRustNetNativeDataSource(
        result: const NativeHttpResultDto.error(
          error: NativeHttpErrorDto(
            code: 'timeout',
            message: 'Request timed out.',
            isTimeout: true,
          ),
        ),
      ),
    );

    expect(
      () => client.execute(
        RustNetRequest.get(uri: Uri.parse('https://example.com/timeout')),
      ),
      throwsA(
        isA<RustNetException>().having(
          (exception) => exception.isTimeout,
          'isTimeout',
          isTrue,
        ),
      ),
    );
  });

  test('rejects relative URLs when baseUrl is missing', () async {
    final client = RustNetClient(
      dataSource: _FakeRustNetNativeDataSource(
        result: NativeHttpResultDto.success(
          response: NativeHttpResponseDto(
            statusCode: 200,
            headers: const <String, List<String>>{},
            bodyBase64: base64Encode(const <int>[]),
          ),
        ),
      ),
    );

    expect(
      () => client.execute(RustNetRequest.get(uri: Uri.parse('users'))),
      throwsA(
        isA<RustNetException>().having(
          (exception) => exception.code,
          'code',
          'invalid_request',
        ),
      ),
    );
  });

  test('does not allow requests after close', () async {
    final client = RustNetClient(
      dataSource: _FakeRustNetNativeDataSource(
        result: NativeHttpResultDto.success(
          response: NativeHttpResponseDto(
            statusCode: 204,
            headers: const <String, List<String>>{},
            bodyBase64: base64Encode(const <int>[]),
          ),
        ),
      ),
    );

    await client.close();

    expect(
      () => client.execute(
        RustNetRequest.get(uri: Uri.parse('https://example.com/ping')),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

class _FakeRustNetNativeDataSource implements RustNetNativeDataSource {
  _FakeRustNetNativeDataSource({required this.result});

  final NativeHttpResultDto result;
  NativeHttpRequestDto? lastRequest;

  @override
  void closeClient(int clientId) {}

  @override
  int createClient(NativeHttpClientConfigDto config) => 1;

  @override
  Future<NativeHttpResultDto> execute(
    int clientId,
    NativeHttpRequestDto request,
  ) async {
    lastRequest = request;
    return result;
  }
}
