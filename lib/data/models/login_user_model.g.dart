// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LoginUserModel _$LoginUserModelFromJson(Map<String, dynamic> json) =>
    _LoginUserModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      username: json['username'] as String?,
      isActive: json['is_active'] as bool?,
      isOnline: json['is_online'] as bool?,
      role: json['role'] as String?,
      profilePhoto: json['profile_photo'] as String?,
    );

Map<String, dynamic> _$LoginUserModelToJson(_LoginUserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'username': instance.username,
      'is_active': instance.isActive,
      'is_online': instance.isOnline,
      'role': instance.role,
      'profile_photo': instance.profilePhoto,
    };
