import 'data/mappers/native_http_client_config_mapper.dart';
import 'data/mappers/native_http_error_mapper.dart';
import 'data/mappers/native_http_request_mapper.dart';
import 'data/mappers/native_http_response_mapper.dart';
import 'data/sources/ffi_rust_net_native_data_source.dart';
import 'data/sources/rust_net_native_data_source.dart';
import 'domain/entities/rust_net_client_config.dart';
import 'domain/entities/rust_net_request.dart';
import 'domain/entities/rust_net_response.dart';
import 'domain/repositories/http_executor.dart';
import 'ffi/rust_net_native_library_resolver.dart';

class RustNetClient implements HttpExecutor {
  RustNetClient({
    this.config = const RustNetClientConfig(),
    String? nativeLibraryPath,
    RustNetNativeDataSource? dataSource,
  }) : _dataSource =
            dataSource ??
            FfiRustNetNativeDataSource(
              libraryPath: RustNetNativeLibraryResolver.resolve(
                explicitPath: nativeLibraryPath,
              ),
            ) {
    _clientId = _dataSource.createClient(
      NativeHttpClientConfigMapper.toDto(config),
    );
  }

  final RustNetClientConfig config;
  final RustNetNativeDataSource _dataSource;
  late final int _clientId;
  bool _isClosed = false;

  static String resolveNativeLibraryPath({String? explicitPath}) {
    return RustNetNativeLibraryResolver.resolve(explicitPath: explicitPath);
  }

  String? get resolvedNativeLibraryPath {
    final dataSource = _dataSource;
    if (dataSource is FfiRustNetNativeDataSource) {
      return dataSource.libraryPath;
    }
    return null;
  }

  @override
  Future<RustNetResponse> execute(RustNetRequest request) async {
    _ensureOpen();

    final result = await _dataSource.execute(
      _clientId,
      NativeHttpRequestMapper.toDto(
        clientConfig: config,
        request: request,
      ),
    );

    return result.when(
      success: NativeHttpResponseMapper.toDomain,
      error: (error) => throw NativeHttpErrorMapper.toDomain(error),
    );
  }

  @override
  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _dataSource.closeClient(_clientId);
    _isClosed = true;
  }

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError('RustNetClient has already been closed.');
    }
  }
}
