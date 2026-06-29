// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_session_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthSessionModel _$AuthSessionModelFromJson(Map<String, dynamic> json) =>
    _AuthSessionModel(
      token: json['token'] as String,
      user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AuthSessionModelToJson(_AuthSessionModel instance) =>
    <String, dynamic>{'token': instance.token, 'user': instance.user};
