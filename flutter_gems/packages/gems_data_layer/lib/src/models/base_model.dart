/// Base Model interface for type safety
/// Freezed models should implement this to ensure toJson() exists
abstract class BaseModel {
  Map<String, dynamic> toJson();
}

