// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'login_user_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LoginUserModel {

 int get id; String get name; String? get username;@JsonKey(name: 'is_active') bool? get isActive;@JsonKey(name: 'is_online') bool? get isOnline; String? get role;@JsonKey(name: 'profile_photo') String? get profilePhoto;
/// Create a copy of LoginUserModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LoginUserModelCopyWith<LoginUserModel> get copyWith => _$LoginUserModelCopyWithImpl<LoginUserModel>(this as LoginUserModel, _$identity);

  /// Serializes this LoginUserModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LoginUserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.username, username) || other.username == username)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.role, role) || other.role == role)&&(identical(other.profilePhoto, profilePhoto) || other.profilePhoto == profilePhoto));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,username,isActive,isOnline,role,profilePhoto);

@override
String toString() {
  return 'LoginUserModel(id: $id, name: $name, username: $username, isActive: $isActive, isOnline: $isOnline, role: $role, profilePhoto: $profilePhoto)';
}


}

/// @nodoc
abstract mixin class $LoginUserModelCopyWith<$Res>  {
  factory $LoginUserModelCopyWith(LoginUserModel value, $Res Function(LoginUserModel) _then) = _$LoginUserModelCopyWithImpl;
@useResult
$Res call({
 int id, String name, String? username,@JsonKey(name: 'is_active') bool? isActive,@JsonKey(name: 'is_online') bool? isOnline, String? role,@JsonKey(name: 'profile_photo') String? profilePhoto
});




}
/// @nodoc
class _$LoginUserModelCopyWithImpl<$Res>
    implements $LoginUserModelCopyWith<$Res> {
  _$LoginUserModelCopyWithImpl(this._self, this._then);

  final LoginUserModel _self;
  final $Res Function(LoginUserModel) _then;

/// Create a copy of LoginUserModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? username = freezed,Object? isActive = freezed,Object? isOnline = freezed,Object? role = freezed,Object? profilePhoto = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,isOnline: freezed == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,profilePhoto: freezed == profilePhoto ? _self.profilePhoto : profilePhoto // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LoginUserModel].
extension LoginUserModelPatterns on LoginUserModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LoginUserModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LoginUserModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LoginUserModel value)  $default,){
final _that = this;
switch (_that) {
case _LoginUserModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LoginUserModel value)?  $default,){
final _that = this;
switch (_that) {
case _LoginUserModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String? username, @JsonKey(name: 'is_active')  bool? isActive, @JsonKey(name: 'is_online')  bool? isOnline,  String? role, @JsonKey(name: 'profile_photo')  String? profilePhoto)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LoginUserModel() when $default != null:
return $default(_that.id,_that.name,_that.username,_that.isActive,_that.isOnline,_that.role,_that.profilePhoto);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String? username, @JsonKey(name: 'is_active')  bool? isActive, @JsonKey(name: 'is_online')  bool? isOnline,  String? role, @JsonKey(name: 'profile_photo')  String? profilePhoto)  $default,) {final _that = this;
switch (_that) {
case _LoginUserModel():
return $default(_that.id,_that.name,_that.username,_that.isActive,_that.isOnline,_that.role,_that.profilePhoto);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String? username, @JsonKey(name: 'is_active')  bool? isActive, @JsonKey(name: 'is_online')  bool? isOnline,  String? role, @JsonKey(name: 'profile_photo')  String? profilePhoto)?  $default,) {final _that = this;
switch (_that) {
case _LoginUserModel() when $default != null:
return $default(_that.id,_that.name,_that.username,_that.isActive,_that.isOnline,_that.role,_that.profilePhoto);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LoginUserModel extends LoginUserModel {
  const _LoginUserModel({required this.id, required this.name, this.username, @JsonKey(name: 'is_active') this.isActive, @JsonKey(name: 'is_online') this.isOnline, this.role, @JsonKey(name: 'profile_photo') this.profilePhoto}): super._();
  factory _LoginUserModel.fromJson(Map<String, dynamic> json) => _$LoginUserModelFromJson(json);

@override final  int id;
@override final  String name;
@override final  String? username;
@override@JsonKey(name: 'is_active') final  bool? isActive;
@override@JsonKey(name: 'is_online') final  bool? isOnline;
@override final  String? role;
@override@JsonKey(name: 'profile_photo') final  String? profilePhoto;

/// Create a copy of LoginUserModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LoginUserModelCopyWith<_LoginUserModel> get copyWith => __$LoginUserModelCopyWithImpl<_LoginUserModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LoginUserModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LoginUserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.username, username) || other.username == username)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.role, role) || other.role == role)&&(identical(other.profilePhoto, profilePhoto) || other.profilePhoto == profilePhoto));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,username,isActive,isOnline,role,profilePhoto);

@override
String toString() {
  return 'LoginUserModel(id: $id, name: $name, username: $username, isActive: $isActive, isOnline: $isOnline, role: $role, profilePhoto: $profilePhoto)';
}


}

/// @nodoc
abstract mixin class _$LoginUserModelCopyWith<$Res> implements $LoginUserModelCopyWith<$Res> {
  factory _$LoginUserModelCopyWith(_LoginUserModel value, $Res Function(_LoginUserModel) _then) = __$LoginUserModelCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String? username,@JsonKey(name: 'is_active') bool? isActive,@JsonKey(name: 'is_online') bool? isOnline, String? role,@JsonKey(name: 'profile_photo') String? profilePhoto
});




}
/// @nodoc
class __$LoginUserModelCopyWithImpl<$Res>
    implements _$LoginUserModelCopyWith<$Res> {
  __$LoginUserModelCopyWithImpl(this._self, this._then);

  final _LoginUserModel _self;
  final $Res Function(_LoginUserModel) _then;

/// Create a copy of LoginUserModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? username = freezed,Object? isActive = freezed,Object? isOnline = freezed,Object? role = freezed,Object? profilePhoto = freezed,}) {
  return _then(_LoginUserModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,isActive: freezed == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool?,isOnline: freezed == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,profilePhoto: freezed == profilePhoto ? _self.profilePhoto : profilePhoto // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
