import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:gems_data_layer/gems_data_layer.dart';

part 'todo_model.freezed.dart';
part 'todo_model.g.dart';

@freezed
class Todo with _$Todo implements BaseModel {
  // ignore: invalid_annotation_target
  const factory Todo({
    // ignore: invalid_annotation_target
    @JsonKey(fromJson: _idFromJson) required String id,
    required String title,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'completed', defaultValue: false) @Default(false) bool isCompleted,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'userId') required int userId,
  }) = _Todo;

  factory Todo.fromJson(Map<String, dynamic> json) => _$TodoFromJson(json);
}

// Helper functions for JSON conversion
String _idFromJson(dynamic value) {
  if (value is int) return value.toString();
  if (value is String) return value;
  return value?.toString() ?? '';
}
