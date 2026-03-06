import 'dart:convert';

import '../../domain/entities/rust_net_response.dart';
import '../dto/native_http_response_dto.dart';

final class NativeHttpResponseMapper {
  const NativeHttpResponseMapper._();

  static RustNetResponse toDomain(NativeHttpResponseDto dto) {
    return RustNetResponse(
      statusCode: dto.statusCode,
      headers: dto.headers,
      bodyBytes: base64Decode(dto.bodyBase64),
    );
  }
}
