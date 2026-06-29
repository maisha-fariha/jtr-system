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
}
