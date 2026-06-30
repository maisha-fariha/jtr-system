import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_request.freezed.dart';
part 'login_request.g.dart';

@freezed
abstract class LoginRequest with _$LoginRequest {
  const factory LoginRequest({
    required String type,
    required String userOrId,
    required String passcode,
    @JsonKey(name: 'card_number') @Default('') String cardNumber,
    @JsonKey(name: 'force_login') @Default(true) bool forceLogin,
  }) = _LoginRequest;

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
}
