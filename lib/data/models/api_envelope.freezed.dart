// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_envelope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApiEnvelope<T> {

 bool get success; int get status; String? get locale; String? get message; T? get data;
/// Create a copy of ApiEnvelope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiEnvelopeCopyWith<T, ApiEnvelope<T>> get copyWith => _$ApiEnvelopeCopyWithImpl<T, ApiEnvelope<T>>(this as ApiEnvelope<T>, _$identity);

  /// Serializes this ApiEnvelope to a JSON map.
  Map<String, dynamic> toJson(Object? Function(T) toJsonT);


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiEnvelope<T>&&(identical(other.success, success) || other.success == success)&&(identical(other.status, status) || other.status == status)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,status,locale,message,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'ApiEnvelope<$T>(success: $success, status: $status, locale: $locale, message: $message, data: $data)';
}


}

/// @nodoc
abstract mixin class $ApiEnvelopeCopyWith<T,$Res>  {
  factory $ApiEnvelopeCopyWith(ApiEnvelope<T> value, $Res Function(ApiEnvelope<T>) _then) = _$ApiEnvelopeCopyWithImpl;
@useResult
$Res call({
 bool success, int status, String? locale, String? message, T? data
});




}
/// @nodoc
class _$ApiEnvelopeCopyWithImpl<T,$Res>
    implements $ApiEnvelopeCopyWith<T, $Res> {
  _$ApiEnvelopeCopyWithImpl(this._self, this._then);

  final ApiEnvelope<T> _self;
  final $Res Function(ApiEnvelope<T>) _then;

/// Create a copy of ApiEnvelope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? status = null,Object? locale = freezed,Object? message = freezed,Object? data = freezed,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as T?,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiEnvelope].
extension ApiEnvelopePatterns<T> on ApiEnvelope<T> {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiEnvelope<T> value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiEnvelope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiEnvelope<T> value)  $default,){
final _that = this;
switch (_that) {
case _ApiEnvelope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiEnvelope<T> value)?  $default,){
final _that = this;
switch (_that) {
case _ApiEnvelope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  int status,  String? locale,  String? message,  T? data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiEnvelope() when $default != null:
return $default(_that.success,_that.status,_that.locale,_that.message,_that.data);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  int status,  String? locale,  String? message,  T? data)  $default,) {final _that = this;
switch (_that) {
case _ApiEnvelope():
return $default(_that.success,_that.status,_that.locale,_that.message,_that.data);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  int status,  String? locale,  String? message,  T? data)?  $default,) {final _that = this;
switch (_that) {
case _ApiEnvelope() when $default != null:
return $default(_that.success,_that.status,_that.locale,_that.message,_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable(genericArgumentFactories: true)

class _ApiEnvelope<T> implements ApiEnvelope<T> {
  const _ApiEnvelope({required this.success, required this.status, this.locale, this.message, this.data});
  factory _ApiEnvelope.fromJson(Map<String, dynamic> json,T Function(Object?) fromJsonT) => _$ApiEnvelopeFromJson(json,fromJsonT);

@override final  bool success;
@override final  int status;
@override final  String? locale;
@override final  String? message;
@override final  T? data;

/// Create a copy of ApiEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiEnvelopeCopyWith<T, _ApiEnvelope<T>> get copyWith => __$ApiEnvelopeCopyWithImpl<T, _ApiEnvelope<T>>(this, _$identity);

@override
Map<String, dynamic> toJson(Object? Function(T) toJsonT) {
  return _$ApiEnvelopeToJson<T>(this, toJsonT);
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiEnvelope<T>&&(identical(other.success, success) || other.success == success)&&(identical(other.status, status) || other.status == status)&&(identical(other.locale, locale) || other.locale == locale)&&(identical(other.message, message) || other.message == message)&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,status,locale,message,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'ApiEnvelope<$T>(success: $success, status: $status, locale: $locale, message: $message, data: $data)';
}


}

/// @nodoc
abstract mixin class _$ApiEnvelopeCopyWith<T,$Res> implements $ApiEnvelopeCopyWith<T, $Res> {
  factory _$ApiEnvelopeCopyWith(_ApiEnvelope<T> value, $Res Function(_ApiEnvelope<T>) _then) = __$ApiEnvelopeCopyWithImpl;
@override @useResult
$Res call({
 bool success, int status, String? locale, String? message, T? data
});




}
/// @nodoc
class __$ApiEnvelopeCopyWithImpl<T,$Res>
    implements _$ApiEnvelopeCopyWith<T, $Res> {
  __$ApiEnvelopeCopyWithImpl(this._self, this._then);

  final _ApiEnvelope<T> _self;
  final $Res Function(_ApiEnvelope<T>) _then;

/// Create a copy of ApiEnvelope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? status = null,Object? locale = freezed,Object? message = freezed,Object? data = freezed,}) {
  return _then(_ApiEnvelope<T>(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as int,locale: freezed == locale ? _self.locale : locale // ignore: cast_nullable_to_non_nullable
as String?,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,data: freezed == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as T?,
  ));
}


}

// dart format on
