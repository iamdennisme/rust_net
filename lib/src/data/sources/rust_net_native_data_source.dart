import '../dto/native_http_client_config_dto.dart';
import '../dto/native_http_request_dto.dart';
import '../dto/native_http_result_dto.dart';

abstract interface class RustNetNativeDataSource {
  int createClient(NativeHttpClientConfigDto config);

  Future<NativeHttpResultDto> execute(int clientId, NativeHttpRequestDto request);

  void closeClient(int clientId);
}
