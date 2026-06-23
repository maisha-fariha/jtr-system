// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TodoImpl _$$TodoImplFromJson(Map<String, dynamic> json) => _$TodoImpl(
  id: _idFromJson(json['id']),
  title: json['title'] as String,
  isCompleted: json['completed'] as bool? ?? false,
  userId: (json['userId'] as num).toInt(),
);

Map<String, dynamic> _$$TodoImplToJson(_$TodoImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'completed': instance.isCompleted,
      'userId': instance.userId,
    };
