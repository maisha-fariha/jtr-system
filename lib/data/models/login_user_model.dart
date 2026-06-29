import 'package:freezed_annotation/freezed_annotation.dart';

import '../../models/user_suggestion.dart';

part 'login_user_model.freezed.dart';
part 'login_user_model.g.dart';

@freezed
abstract class LoginUserModel with _$LoginUserModel {
  const LoginUserModel._();

  const factory LoginUserModel({
    required int id,
    required String name,
    String? username,
    @JsonKey(name: 'is_active') bool? isActive,
    @JsonKey(name: 'is_online') bool? isOnline,
    String? role,
    @JsonKey(name: 'profile_photo') String? profilePhoto,
  }) = _LoginUserModel;

  factory LoginUserModel.fromJson(Map<String, dynamic> json) =>
      _$LoginUserModelFromJson(json);

  UserSuggestion toSuggestion() => UserSuggestion(
        id: id.toString(),
        name: name,
        role: (role ?? '-').toUpperCase(),
      );
}
