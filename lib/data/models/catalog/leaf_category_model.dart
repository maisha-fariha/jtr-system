import 'package:freezed_annotation/freezed_annotation.dart';

part 'leaf_category_model.freezed.dart';
part 'leaf_category_model.g.dart';

@freezed
abstract class LeafCategoryModel with _$LeafCategoryModel {
  const factory LeafCategoryModel({
    required int id,
    required String name,
    String? color,
    String? icon,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'has_children') @Default(false) bool hasChildren,
    @JsonKey(name: 'children_count') @Default(0) int childrenCount,
    int? position,
    LeafCategoryParent? parent,
  }) = _LeafCategoryModel;

  factory LeafCategoryModel.fromJson(Map<String, dynamic> json) =>
      _$LeafCategoryModelFromJson(json);
}

@freezed
abstract class LeafCategoryParent with _$LeafCategoryParent {
  const factory LeafCategoryParent({
    required int id,
    required String name,
    String? color,
  }) = _LeafCategoryParent;

  factory LeafCategoryParent.fromJson(Map<String, dynamic> json) =>
      _$LeafCategoryParentFromJson(json);
}
