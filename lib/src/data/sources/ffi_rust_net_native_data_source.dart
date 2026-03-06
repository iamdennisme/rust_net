import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:rust_net/rust_net_bindings_generated.dart';

import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_request_dto.dart';
import '../dto/native_http_result_dto.dart';
import 'rust_net_native_data_source.dart';

typedef _FfiExecuteArgs = ({String libraryPath, int clientId, String requestJson});

class FfiRustNetNativeDataSource implements RustNetNativeDataSource {
  FfiRustNetNativeDataSource({required this.libraryPath})
      : _dynamicLibrary = _openDynamicLibrary(libraryPath),
        _bindings = RustNetBindings(_openDynamicLibrary(libraryPath));

  final String libraryPath;
  final DynamicLibrary _dynamicLibrary;
  final RustNetBindings _bindings;

  @override
  int createClient(NativeHttpClientConfigDto config) {
    final configPointer = jsonEncode(config.toJson()).toNativeUtf8();
    try {
      final clientId = _bindings.rust_net_client_create(configPointer.cast());
      if (clientId == 0) {
        throw StateError(
          'Rust native library failed to create an HTTP client.',
        );
      }
      return clientId;
    } finally {
      calloc.free(configPointer);
    }
  }

  @override
  Future<NativeHttpResultDto> execute(
    int clientId,
    NativeHttpRequestDto request,
  ) async {
    final localLibraryPath = libraryPath;
    final requestJson = jsonEncode(request.toJson());
    final responseJson = await Isolate.run<String>(
      () => _executeNativeRequest(
        (
          libraryPath: localLibraryPath,
          clientId: clientId,
          requestJson: requestJson,
        ),
      ),
    );
    final decoded =
        Map<String, dynamic>.from(jsonDecode(responseJson) as Map<dynamic, dynamic>);
    return NativeHttpResultDto.fromJson(decoded);
  }

  @override
  void closeClient(int clientId) {
    _bindings.rust_net_client_close(clientId);
    _dynamicLibrary.close();
  }
}

String _executeNativeRequest(_FfiExecuteArgs args) {
  final bindings = RustNetBindings(_openDynamicLibrary(args.libraryPath));
  final requestPointer = args.requestJson.toNativeUtf8();
  try {
    final responsePointer =
        bindings.rust_net_client_execute(args.clientId, requestPointer.cast());
    if (responsePointer.address == 0) {
      return jsonEncode(<String, Object?>{
        'type': 'error',
        'error': <String, Object?>{
          'code': 'ffi_null_response',
          'message': 'Rust native library returned a null response.',
          'is_timeout': false,
        },
      });
    }

    try {
      return responsePointer.cast<Utf8>().toDartString();
    } finally {
      bindings.rust_net_string_free(responsePointer);
    }
  } finally {
    calloc.free(requestPointer);
  }
}

DynamicLibrary _openDynamicLibrary(String libraryPath) {
  return DynamicLibrary.open(libraryPath);
}
