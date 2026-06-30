import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user_model.freezed.dart';
part 'auth_user_model.g.dart';

@freezed
abstract class AuthUserModel with _$AuthUserModel {
  const factory AuthUserModel({
    required int id,
    required String name,
    String? username,
    @JsonKey(name: 'card_number') String? cardNumber,
    @JsonKey(name: 'profile_photo') String? profilePhoto,
    @JsonKey(name: 'last_login') String? lastLogin,
    @JsonKey(name: 'is_online') bool? isOnline,
    @JsonKey(name: 'is_active') bool? isActive,
    @JsonKey(name: 'is_superuser') bool? isSuperuser,
    String? role,
    @Default([]) List<dynamic> permissions,
    @JsonKey(name: 'created_at') String? createdAt,
    @JsonKey(name: 'updated_at') String? updatedAt,
  }) = _AuthUserModel;

  factory AuthUserModel.fromJson(Map<String, dynamic> json) =>
      _$AuthUserModelFromJson(json);
}
