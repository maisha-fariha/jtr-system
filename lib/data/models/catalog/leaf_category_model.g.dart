// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leaf_category_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LeafCategoryModel _$LeafCategoryModelFromJson(Map<String, dynamic> json) =>
    _LeafCategoryModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      hasChildren: json['has_children'] as bool? ?? false,
      childrenCount: (json['children_count'] as num?)?.toInt() ?? 0,
      position: (json['position'] as num?)?.toInt(),
      parent: json['parent'] == null
          ? null
          : LeafCategoryParent.fromJson(json['parent'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$LeafCategoryModelToJson(_LeafCategoryModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'color': instance.color,
      'icon': instance.icon,
      'is_active': instance.isActive,
      'has_children': instance.hasChildren,
      'children_count': instance.childrenCount,
      'position': instance.position,
      'parent': instance.parent,
    };

_LeafCategoryParent _$LeafCategoryParentFromJson(Map<String, dynamic> json) =>
    _LeafCategoryParent(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      color: json['color'] as String?,
    );

Map<String, dynamic> _$LeafCategoryParentToJson(_LeafCategoryParent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'color': instance.color,
    };
