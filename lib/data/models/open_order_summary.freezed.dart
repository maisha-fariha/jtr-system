// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'open_order_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OpenOrderSummary {

 int get id;@JsonKey(name: 'order_number') String get orderNumber;@JsonKey(name: 'table_id') int? get tableId;@JsonKey(name: 'table_number') int? get tableNumber; String get status;@JsonKey(name: 'total_price') String get totalPrice;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of OpenOrderSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenOrderSummaryCopyWith<OpenOrderSummary> get copyWith => _$OpenOrderSummaryCopyWithImpl<OpenOrderSummary>(this as OpenOrderSummary, _$identity);

  /// Serializes this OpenOrderSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenOrderSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.tableId, tableId) || other.tableId == tableId)&&(identical(other.tableNumber, tableNumber) || other.tableNumber == tableNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.totalPrice, totalPrice) || other.totalPrice == totalPrice)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,tableId,tableNumber,status,totalPrice,createdAt);

@override
String toString() {
  return 'OpenOrderSummary(id: $id, orderNumber: $orderNumber, tableId: $tableId, tableNumber: $tableNumber, status: $status, totalPrice: $totalPrice, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $OpenOrderSummaryCopyWith<$Res>  {
  factory $OpenOrderSummaryCopyWith(OpenOrderSummary value, $Res Function(OpenOrderSummary) _then) = _$OpenOrderSummaryCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'order_number') String orderNumber,@JsonKey(name: 'table_id') int? tableId,@JsonKey(name: 'table_number') int? tableNumber, String status,@JsonKey(name: 'total_price') String totalPrice,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$OpenOrderSummaryCopyWithImpl<$Res>
    implements $OpenOrderSummaryCopyWith<$Res> {
  _$OpenOrderSummaryCopyWithImpl(this._self, this._then);

  final OpenOrderSummary _self;
  final $Res Function(OpenOrderSummary) _then;

/// Create a copy of OpenOrderSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? orderNumber = null,Object? tableId = freezed,Object? tableNumber = freezed,Object? status = null,Object? totalPrice = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,tableId: freezed == tableId ? _self.tableId : tableId // ignore: cast_nullable_to_non_nullable
as int?,tableNumber: freezed == tableNumber ? _self.tableNumber : tableNumber // ignore: cast_nullable_to_non_nullable
as int?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,totalPrice: null == totalPrice ? _self.totalPrice : totalPrice // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [OpenOrderSummary].
extension OpenOrderSummaryPatterns on OpenOrderSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OpenOrderSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OpenOrderSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OpenOrderSummary value)  $default,){
final _that = this;
switch (_that) {
case _OpenOrderSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OpenOrderSummary value)?  $default,){
final _that = this;
switch (_that) {
case _OpenOrderSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'order_number')  String orderNumber, @JsonKey(name: 'table_id')  int? tableId, @JsonKey(name: 'table_number')  int? tableNumber,  String status, @JsonKey(name: 'total_price')  String totalPrice, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OpenOrderSummary() when $default != null:
return $default(_that.id,_that.orderNumber,_that.tableId,_that.tableNumber,_that.status,_that.totalPrice,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'order_number')  String orderNumber, @JsonKey(name: 'table_id')  int? tableId, @JsonKey(name: 'table_number')  int? tableNumber,  String status, @JsonKey(name: 'total_price')  String totalPrice, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _OpenOrderSummary():
return $default(_that.id,_that.orderNumber,_that.tableId,_that.tableNumber,_that.status,_that.totalPrice,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'order_number')  String orderNumber, @JsonKey(name: 'table_id')  int? tableId, @JsonKey(name: 'table_number')  int? tableNumber,  String status, @JsonKey(name: 'total_price')  String totalPrice, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _OpenOrderSummary() when $default != null:
return $default(_that.id,_that.orderNumber,_that.tableId,_that.tableNumber,_that.status,_that.totalPrice,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OpenOrderSummary implements OpenOrderSummary {
  const _OpenOrderSummary({required this.id, @JsonKey(name: 'order_number') required this.orderNumber, @JsonKey(name: 'table_id') this.tableId, @JsonKey(name: 'table_number') this.tableNumber, required this.status, @JsonKey(name: 'total_price') required this.totalPrice, @JsonKey(name: 'created_at') this.createdAt});
  factory _OpenOrderSummary.fromJson(Map<String, dynamic> json) => _$OpenOrderSummaryFromJson(json);

@override final  int id;
@override@JsonKey(name: 'order_number') final  String orderNumber;
@override@JsonKey(name: 'table_id') final  int? tableId;
@override@JsonKey(name: 'table_number') final  int? tableNumber;
@override final  String status;
@override@JsonKey(name: 'total_price') final  String totalPrice;
@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of OpenOrderSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenOrderSummaryCopyWith<_OpenOrderSummary> get copyWith => __$OpenOrderSummaryCopyWithImpl<_OpenOrderSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpenOrderSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenOrderSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.orderNumber, orderNumber) || other.orderNumber == orderNumber)&&(identical(other.tableId, tableId) || other.tableId == tableId)&&(identical(other.tableNumber, tableNumber) || other.tableNumber == tableNumber)&&(identical(other.status, status) || other.status == status)&&(identical(other.totalPrice, totalPrice) || other.totalPrice == totalPrice)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,orderNumber,tableId,tableNumber,status,totalPrice,createdAt);

@override
String toString() {
  return 'OpenOrderSummary(id: $id, orderNumber: $orderNumber, tableId: $tableId, tableNumber: $tableNumber, status: $status, totalPrice: $totalPrice, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$OpenOrderSummaryCopyWith<$Res> implements $OpenOrderSummaryCopyWith<$Res> {
  factory _$OpenOrderSummaryCopyWith(_OpenOrderSummary value, $Res Function(_OpenOrderSummary) _then) = __$OpenOrderSummaryCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'order_number') String orderNumber,@JsonKey(name: 'table_id') int? tableId,@JsonKey(name: 'table_number') int? tableNumber, String status,@JsonKey(name: 'total_price') String totalPrice,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$OpenOrderSummaryCopyWithImpl<$Res>
    implements _$OpenOrderSummaryCopyWith<$Res> {
  __$OpenOrderSummaryCopyWithImpl(this._self, this._then);

  final _OpenOrderSummary _self;
  final $Res Function(_OpenOrderSummary) _then;

/// Create a copy of OpenOrderSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? orderNumber = null,Object? tableId = freezed,Object? tableNumber = freezed,Object? status = null,Object? totalPrice = null,Object? createdAt = freezed,}) {
  return _then(_OpenOrderSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,orderNumber: null == orderNumber ? _self.orderNumber : orderNumber // ignore: cast_nullable_to_non_nullable
as String,tableId: freezed == tableId ? _self.tableId : tableId // ignore: cast_nullable_to_non_nullable
as int?,tableNumber: freezed == tableNumber ? _self.tableNumber : tableNumber // ignore: cast_nullable_to_non_nullable
as int?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,totalPrice: null == totalPrice ? _self.totalPrice : totalPrice // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$OpenOrdersData {

@JsonKey(name: 'hasOpenOrders') bool get hasOpenOrders;@JsonKey(name: 'openOrdersCount') int get openOrdersCount;@JsonKey(name: 'openOrders') List<OpenOrderSummary> get openOrders;
/// Create a copy of OpenOrdersData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OpenOrdersDataCopyWith<OpenOrdersData> get copyWith => _$OpenOrdersDataCopyWithImpl<OpenOrdersData>(this as OpenOrdersData, _$identity);

  /// Serializes this OpenOrdersData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OpenOrdersData&&(identical(other.hasOpenOrders, hasOpenOrders) || other.hasOpenOrders == hasOpenOrders)&&(identical(other.openOrdersCount, openOrdersCount) || other.openOrdersCount == openOrdersCount)&&const DeepCollectionEquality().equals(other.openOrders, openOrders));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hasOpenOrders,openOrdersCount,const DeepCollectionEquality().hash(openOrders));

@override
String toString() {
  return 'OpenOrdersData(hasOpenOrders: $hasOpenOrders, openOrdersCount: $openOrdersCount, openOrders: $openOrders)';
}


}

/// @nodoc
abstract mixin class $OpenOrdersDataCopyWith<$Res>  {
  factory $OpenOrdersDataCopyWith(OpenOrdersData value, $Res Function(OpenOrdersData) _then) = _$OpenOrdersDataCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'hasOpenOrders') bool hasOpenOrders,@JsonKey(name: 'openOrdersCount') int openOrdersCount,@JsonKey(name: 'openOrders') List<OpenOrderSummary> openOrders
});




}
/// @nodoc
class _$OpenOrdersDataCopyWithImpl<$Res>
    implements $OpenOrdersDataCopyWith<$Res> {
  _$OpenOrdersDataCopyWithImpl(this._self, this._then);

  final OpenOrdersData _self;
  final $Res Function(OpenOrdersData) _then;

/// Create a copy of OpenOrdersData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? hasOpenOrders = null,Object? openOrdersCount = null,Object? openOrders = null,}) {
  return _then(_self.copyWith(
hasOpenOrders: null == hasOpenOrders ? _self.hasOpenOrders : hasOpenOrders // ignore: cast_nullable_to_non_nullable
as bool,openOrdersCount: null == openOrdersCount ? _self.openOrdersCount : openOrdersCount // ignore: cast_nullable_to_non_nullable
as int,openOrders: null == openOrders ? _self.openOrders : openOrders // ignore: cast_nullable_to_non_nullable
as List<OpenOrderSummary>,
  ));
}

}


/// Adds pattern-matching-related methods to [OpenOrdersData].
extension OpenOrdersDataPatterns on OpenOrdersData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OpenOrdersData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OpenOrdersData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OpenOrdersData value)  $default,){
final _that = this;
switch (_that) {
case _OpenOrdersData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OpenOrdersData value)?  $default,){
final _that = this;
switch (_that) {
case _OpenOrdersData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'hasOpenOrders')  bool hasOpenOrders, @JsonKey(name: 'openOrdersCount')  int openOrdersCount, @JsonKey(name: 'openOrders')  List<OpenOrderSummary> openOrders)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OpenOrdersData() when $default != null:
return $default(_that.hasOpenOrders,_that.openOrdersCount,_that.openOrders);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'hasOpenOrders')  bool hasOpenOrders, @JsonKey(name: 'openOrdersCount')  int openOrdersCount, @JsonKey(name: 'openOrders')  List<OpenOrderSummary> openOrders)  $default,) {final _that = this;
switch (_that) {
case _OpenOrdersData():
return $default(_that.hasOpenOrders,_that.openOrdersCount,_that.openOrders);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'hasOpenOrders')  bool hasOpenOrders, @JsonKey(name: 'openOrdersCount')  int openOrdersCount, @JsonKey(name: 'openOrders')  List<OpenOrderSummary> openOrders)?  $default,) {final _that = this;
switch (_that) {
case _OpenOrdersData() when $default != null:
return $default(_that.hasOpenOrders,_that.openOrdersCount,_that.openOrders);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OpenOrdersData implements OpenOrdersData {
  const _OpenOrdersData({@JsonKey(name: 'hasOpenOrders') required this.hasOpenOrders, @JsonKey(name: 'openOrdersCount') required this.openOrdersCount, @JsonKey(name: 'openOrders') required final  List<OpenOrderSummary> openOrders}): _openOrders = openOrders;
  factory _OpenOrdersData.fromJson(Map<String, dynamic> json) => _$OpenOrdersDataFromJson(json);

@override@JsonKey(name: 'hasOpenOrders') final  bool hasOpenOrders;
@override@JsonKey(name: 'openOrdersCount') final  int openOrdersCount;
 final  List<OpenOrderSummary> _openOrders;
@override@JsonKey(name: 'openOrders') List<OpenOrderSummary> get openOrders {
  if (_openOrders is EqualUnmodifiableListView) return _openOrders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_openOrders);
}


/// Create a copy of OpenOrdersData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OpenOrdersDataCopyWith<_OpenOrdersData> get copyWith => __$OpenOrdersDataCopyWithImpl<_OpenOrdersData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OpenOrdersDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OpenOrdersData&&(identical(other.hasOpenOrders, hasOpenOrders) || other.hasOpenOrders == hasOpenOrders)&&(identical(other.openOrdersCount, openOrdersCount) || other.openOrdersCount == openOrdersCount)&&const DeepCollectionEquality().equals(other._openOrders, _openOrders));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,hasOpenOrders,openOrdersCount,const DeepCollectionEquality().hash(_openOrders));

@override
String toString() {
  return 'OpenOrdersData(hasOpenOrders: $hasOpenOrders, openOrdersCount: $openOrdersCount, openOrders: $openOrders)';
}


}

/// @nodoc
abstract mixin class _$OpenOrdersDataCopyWith<$Res> implements $OpenOrdersDataCopyWith<$Res> {
  factory _$OpenOrdersDataCopyWith(_OpenOrdersData value, $Res Function(_OpenOrdersData) _then) = __$OpenOrdersDataCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'hasOpenOrders') bool hasOpenOrders,@JsonKey(name: 'openOrdersCount') int openOrdersCount,@JsonKey(name: 'openOrders') List<OpenOrderSummary> openOrders
});




}
/// @nodoc
class __$OpenOrdersDataCopyWithImpl<$Res>
    implements _$OpenOrdersDataCopyWith<$Res> {
  __$OpenOrdersDataCopyWithImpl(this._self, this._then);

  final _OpenOrdersData _self;
  final $Res Function(_OpenOrdersData) _then;

/// Create a copy of OpenOrdersData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? hasOpenOrders = null,Object? openOrdersCount = null,Object? openOrders = null,}) {
  return _then(_OpenOrdersData(
hasOpenOrders: null == hasOpenOrders ? _self.hasOpenOrders : hasOpenOrders // ignore: cast_nullable_to_non_nullable
as bool,openOrdersCount: null == openOrdersCount ? _self.openOrdersCount : openOrdersCount // ignore: cast_nullable_to_non_nullable
as int,openOrders: null == openOrders ? _self._openOrders : openOrders // ignore: cast_nullable_to_non_nullable
as List<OpenOrderSummary>,
  ));
}


}

// dart format on
