// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'leaf_category_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LeafCategoryModel {

 int get id; String get name; String? get color; String? get icon;@JsonKey(name: 'is_active') bool get isActive;@JsonKey(name: 'has_children') bool get hasChildren;@JsonKey(name: 'children_count') int get childrenCount; int? get position; LeafCategoryParent? get parent;
/// Create a copy of LeafCategoryModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeafCategoryModelCopyWith<LeafCategoryModel> get copyWith => _$LeafCategoryModelCopyWithImpl<LeafCategoryModel>(this as LeafCategoryModel, _$identity);

  /// Serializes this LeafCategoryModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeafCategoryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.hasChildren, hasChildren) || other.hasChildren == hasChildren)&&(identical(other.childrenCount, childrenCount) || other.childrenCount == childrenCount)&&(identical(other.position, position) || other.position == position)&&(identical(other.parent, parent) || other.parent == parent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,color,icon,isActive,hasChildren,childrenCount,position,parent);

@override
String toString() {
  return 'LeafCategoryModel(id: $id, name: $name, color: $color, icon: $icon, isActive: $isActive, hasChildren: $hasChildren, childrenCount: $childrenCount, position: $position, parent: $parent)';
}


}

/// @nodoc
abstract mixin class $LeafCategoryModelCopyWith<$Res>  {
  factory $LeafCategoryModelCopyWith(LeafCategoryModel value, $Res Function(LeafCategoryModel) _then) = _$LeafCategoryModelCopyWithImpl;
@useResult
$Res call({
 int id, String name, String? color, String? icon,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'has_children') bool hasChildren,@JsonKey(name: 'children_count') int childrenCount, int? position, LeafCategoryParent? parent
});


$LeafCategoryParentCopyWith<$Res>? get parent;

}
/// @nodoc
class _$LeafCategoryModelCopyWithImpl<$Res>
    implements $LeafCategoryModelCopyWith<$Res> {
  _$LeafCategoryModelCopyWithImpl(this._self, this._then);

  final LeafCategoryModel _self;
  final $Res Function(LeafCategoryModel) _then;

/// Create a copy of LeafCategoryModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? color = freezed,Object? icon = freezed,Object? isActive = null,Object? hasChildren = null,Object? childrenCount = null,Object? position = freezed,Object? parent = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String?,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,hasChildren: null == hasChildren ? _self.hasChildren : hasChildren // ignore: cast_nullable_to_non_nullable
as bool,childrenCount: null == childrenCount ? _self.childrenCount : childrenCount // ignore: cast_nullable_to_non_nullable
as int,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int?,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as LeafCategoryParent?,
  ));
}
/// Create a copy of LeafCategoryModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LeafCategoryParentCopyWith<$Res>? get parent {
    if (_self.parent == null) {
    return null;
  }

  return $LeafCategoryParentCopyWith<$Res>(_self.parent!, (value) {
    return _then(_self.copyWith(parent: value));
  });
}
}


/// Adds pattern-matching-related methods to [LeafCategoryModel].
extension LeafCategoryModelPatterns on LeafCategoryModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LeafCategoryModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LeafCategoryModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LeafCategoryModel value)  $default,){
final _that = this;
switch (_that) {
case _LeafCategoryModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LeafCategoryModel value)?  $default,){
final _that = this;
switch (_that) {
case _LeafCategoryModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String? color,  String? icon, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'has_children')  bool hasChildren, @JsonKey(name: 'children_count')  int childrenCount,  int? position,  LeafCategoryParent? parent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LeafCategoryModel() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.icon,_that.isActive,_that.hasChildren,_that.childrenCount,_that.position,_that.parent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String? color,  String? icon, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'has_children')  bool hasChildren, @JsonKey(name: 'children_count')  int childrenCount,  int? position,  LeafCategoryParent? parent)  $default,) {final _that = this;
switch (_that) {
case _LeafCategoryModel():
return $default(_that.id,_that.name,_that.color,_that.icon,_that.isActive,_that.hasChildren,_that.childrenCount,_that.position,_that.parent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String? color,  String? icon, @JsonKey(name: 'is_active')  bool isActive, @JsonKey(name: 'has_children')  bool hasChildren, @JsonKey(name: 'children_count')  int childrenCount,  int? position,  LeafCategoryParent? parent)?  $default,) {final _that = this;
switch (_that) {
case _LeafCategoryModel() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.icon,_that.isActive,_that.hasChildren,_that.childrenCount,_that.position,_that.parent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LeafCategoryModel implements LeafCategoryModel {
  const _LeafCategoryModel({required this.id, required this.name, this.color, this.icon, @JsonKey(name: 'is_active') this.isActive = true, @JsonKey(name: 'has_children') this.hasChildren = false, @JsonKey(name: 'children_count') this.childrenCount = 0, this.position, this.parent});
  factory _LeafCategoryModel.fromJson(Map<String, dynamic> json) => _$LeafCategoryModelFromJson(json);

@override final  int id;
@override final  String name;
@override final  String? color;
@override final  String? icon;
@override@JsonKey(name: 'is_active') final  bool isActive;
@override@JsonKey(name: 'has_children') final  bool hasChildren;
@override@JsonKey(name: 'children_count') final  int childrenCount;
@override final  int? position;
@override final  LeafCategoryParent? parent;

/// Create a copy of LeafCategoryModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LeafCategoryModelCopyWith<_LeafCategoryModel> get copyWith => __$LeafCategoryModelCopyWithImpl<_LeafCategoryModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LeafCategoryModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LeafCategoryModel&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.icon, icon) || other.icon == icon)&&(identical(other.isActive, isActive) || other.isActive == isActive)&&(identical(other.hasChildren, hasChildren) || other.hasChildren == hasChildren)&&(identical(other.childrenCount, childrenCount) || other.childrenCount == childrenCount)&&(identical(other.position, position) || other.position == position)&&(identical(other.parent, parent) || other.parent == parent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,color,icon,isActive,hasChildren,childrenCount,position,parent);

@override
String toString() {
  return 'LeafCategoryModel(id: $id, name: $name, color: $color, icon: $icon, isActive: $isActive, hasChildren: $hasChildren, childrenCount: $childrenCount, position: $position, parent: $parent)';
}


}

/// @nodoc
abstract mixin class _$LeafCategoryModelCopyWith<$Res> implements $LeafCategoryModelCopyWith<$Res> {
  factory _$LeafCategoryModelCopyWith(_LeafCategoryModel value, $Res Function(_LeafCategoryModel) _then) = __$LeafCategoryModelCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String? color, String? icon,@JsonKey(name: 'is_active') bool isActive,@JsonKey(name: 'has_children') bool hasChildren,@JsonKey(name: 'children_count') int childrenCount, int? position, LeafCategoryParent? parent
});


@override $LeafCategoryParentCopyWith<$Res>? get parent;

}
/// @nodoc
class __$LeafCategoryModelCopyWithImpl<$Res>
    implements _$LeafCategoryModelCopyWith<$Res> {
  __$LeafCategoryModelCopyWithImpl(this._self, this._then);

  final _LeafCategoryModel _self;
  final $Res Function(_LeafCategoryModel) _then;

/// Create a copy of LeafCategoryModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? color = freezed,Object? icon = freezed,Object? isActive = null,Object? hasChildren = null,Object? childrenCount = null,Object? position = freezed,Object? parent = freezed,}) {
  return _then(_LeafCategoryModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String?,icon: freezed == icon ? _self.icon : icon // ignore: cast_nullable_to_non_nullable
as String?,isActive: null == isActive ? _self.isActive : isActive // ignore: cast_nullable_to_non_nullable
as bool,hasChildren: null == hasChildren ? _self.hasChildren : hasChildren // ignore: cast_nullable_to_non_nullable
as bool,childrenCount: null == childrenCount ? _self.childrenCount : childrenCount // ignore: cast_nullable_to_non_nullable
as int,position: freezed == position ? _self.position : position // ignore: cast_nullable_to_non_nullable
as int?,parent: freezed == parent ? _self.parent : parent // ignore: cast_nullable_to_non_nullable
as LeafCategoryParent?,
  ));
}

/// Create a copy of LeafCategoryModel
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LeafCategoryParentCopyWith<$Res>? get parent {
    if (_self.parent == null) {
    return null;
  }

  return $LeafCategoryParentCopyWith<$Res>(_self.parent!, (value) {
    return _then(_self.copyWith(parent: value));
  });
}
}


/// @nodoc
mixin _$LeafCategoryParent {

 int get id; String get name; String? get color;
/// Create a copy of LeafCategoryParent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LeafCategoryParentCopyWith<LeafCategoryParent> get copyWith => _$LeafCategoryParentCopyWithImpl<LeafCategoryParent>(this as LeafCategoryParent, _$identity);

  /// Serializes this LeafCategoryParent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LeafCategoryParent&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,color);

@override
String toString() {
  return 'LeafCategoryParent(id: $id, name: $name, color: $color)';
}


}

/// @nodoc
abstract mixin class $LeafCategoryParentCopyWith<$Res>  {
  factory $LeafCategoryParentCopyWith(LeafCategoryParent value, $Res Function(LeafCategoryParent) _then) = _$LeafCategoryParentCopyWithImpl;
@useResult
$Res call({
 int id, String name, String? color
});




}
/// @nodoc
class _$LeafCategoryParentCopyWithImpl<$Res>
    implements $LeafCategoryParentCopyWith<$Res> {
  _$LeafCategoryParentCopyWithImpl(this._self, this._then);

  final LeafCategoryParent _self;
  final $Res Function(LeafCategoryParent) _then;

/// Create a copy of LeafCategoryParent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? color = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LeafCategoryParent].
extension LeafCategoryParentPatterns on LeafCategoryParent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LeafCategoryParent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LeafCategoryParent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LeafCategoryParent value)  $default,){
final _that = this;
switch (_that) {
case _LeafCategoryParent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LeafCategoryParent value)?  $default,){
final _that = this;
switch (_that) {
case _LeafCategoryParent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String name,  String? color)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LeafCategoryParent() when $default != null:
return $default(_that.id,_that.name,_that.color);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String name,  String? color)  $default,) {final _that = this;
switch (_that) {
case _LeafCategoryParent():
return $default(_that.id,_that.name,_that.color);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String name,  String? color)?  $default,) {final _that = this;
switch (_that) {
case _LeafCategoryParent() when $default != null:
return $default(_that.id,_that.name,_that.color);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LeafCategoryParent implements LeafCategoryParent {
  const _LeafCategoryParent({required this.id, required this.name, this.color});
  factory _LeafCategoryParent.fromJson(Map<String, dynamic> json) => _$LeafCategoryParentFromJson(json);

@override final  int id;
@override final  String name;
@override final  String? color;

/// Create a copy of LeafCategoryParent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LeafCategoryParentCopyWith<_LeafCategoryParent> get copyWith => __$LeafCategoryParentCopyWithImpl<_LeafCategoryParent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LeafCategoryParentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LeafCategoryParent&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,color);

@override
String toString() {
  return 'LeafCategoryParent(id: $id, name: $name, color: $color)';
}


}

/// @nodoc
abstract mixin class _$LeafCategoryParentCopyWith<$Res> implements $LeafCategoryParentCopyWith<$Res> {
  factory _$LeafCategoryParentCopyWith(_LeafCategoryParent value, $Res Function(_LeafCategoryParent) _then) = __$LeafCategoryParentCopyWithImpl;
@override @useResult
$Res call({
 int id, String name, String? color
});




}
/// @nodoc
class __$LeafCategoryParentCopyWithImpl<$Res>
    implements _$LeafCategoryParentCopyWith<$Res> {
  __$LeafCategoryParentCopyWithImpl(this._self, this._then);

  final _LeafCategoryParent _self;
  final $Res Function(_LeafCategoryParent) _then;

/// Create a copy of LeafCategoryParent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? color = freezed,}) {
  return _then(_LeafCategoryParent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
