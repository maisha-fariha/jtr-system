import 'package:freezed_annotation/freezed_annotation.dart';

part 'login_role_model.freezed.dart';
part 'login_role_model.g.dart';

@freezed
abstract class LoginRoleModel with _$LoginRoleModel {
  const factory LoginRoleModel({
    required int id,
    required String name,
  }) = _LoginRoleModel;

  factory LoginRoleModel.fromJson(Map<String, dynamic> json) =>
      _$LoginRoleModelFromJson(json);
}
