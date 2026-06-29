// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) =>
    _LoginRequest(
      type: json['type'] as String,
      userOrId: json['userOrId'] as String,
      passcode: json['passcode'] as String,
      cardNumber: json['card_number'] as String? ?? '',
      forceLogin: json['force_login'] as bool? ?? true,
    );

Map<String, dynamic> _$LoginRequestToJson(_LoginRequest instance) =>
    <String, dynamic>{
      'type': instance.type,
      'userOrId': instance.userOrId,
      'passcode': instance.passcode,
      'card_number': instance.cardNumber,
      'force_login': instance.forceLogin,
    };
