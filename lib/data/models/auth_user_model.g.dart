// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AuthUserModel _$AuthUserModelFromJson(Map<String, dynamic> json) =>
    _AuthUserModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      username: json['username'] as String?,
      cardNumber: json['card_number'] as String?,
      profilePhoto: json['profile_photo'] as String?,
      lastLogin: json['last_login'] as String?,
      isOnline: json['is_online'] as bool?,
      isActive: json['is_active'] as bool?,
      isSuperuser: json['is_superuser'] as bool?,
      role: json['role'] as String?,
      permissions: json['permissions'] as List<dynamic>? ?? const [],
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );

Map<String, dynamic> _$AuthUserModelToJson(_AuthUserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'username': instance.username,
      'card_number': instance.cardNumber,
      'profile_photo': instance.profilePhoto,
      'last_login': instance.lastLogin,
      'is_online': instance.isOnline,
      'is_active': instance.isActive,
      'is_superuser': instance.isSuperuser,
      'role': instance.role,
      'permissions': instance.permissions,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
    };
