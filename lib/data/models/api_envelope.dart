import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_envelope.freezed.dart';
part 'api_envelope.g.dart';

@Freezed(genericArgumentFactories: true)
abstract class ApiEnvelope<T> with _$ApiEnvelope<T> {
  const factory ApiEnvelope({
    required bool success,
    required int status,
    String? locale,
    String? message,
    T? data,
  }) = _ApiEnvelope<T>;

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) fromJsonT,
  ) =>
      _$ApiEnvelopeFromJson(json, fromJsonT);

  /// Tolerant parser for endpoints that omit `status` or `success`.
  factory ApiEnvelope.parseResponse(
    Map<String, dynamic> json, {
    T Function(Object? json)? fromJsonT,
  }) {
    final rawSuccess = json['success'];
    final success = rawSuccess is bool
        ? rawSuccess
        : json['message'] == null;

    return ApiEnvelope(
      success: success,
      status: (json['status'] as num?)?.toInt() ?? 200,
      locale: json['locale'] as String?,
      message: json['message'] as String?,
      data: json['data'] == null
          ? null
          : (fromJsonT != null ? fromJsonT(json['data']) : json['data'] as T?),
    );
  }
}
