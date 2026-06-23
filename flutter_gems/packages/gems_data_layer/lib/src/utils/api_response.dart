/// Generic API Response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  const ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
    this.errors,
  });

  factory ApiResponse.success(T data, {String? message, int? statusCode}) {
    return ApiResponse<T>(
      success: true,
      data: data,
      message: message,
      statusCode: statusCode ?? 200,
    );
  }

  factory ApiResponse.error(
    String message, {
    int? statusCode,
    Map<String, dynamic>? errors,
  }) {
    return ApiResponse<T>(
      success: false,
      message: message,
      statusCode: statusCode ?? 500,
      errors: errors,
    );
  }

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    if (json['success'] == true || json['status'] == 'success') {
      return ApiResponse.success(
        fromJsonT != null ? fromJsonT(json['data'] ?? json) : json as T,
        message: json['message'],
        statusCode: json['statusCode'] ?? 200,
      );
    }
    return ApiResponse.error(
      json['message'] ?? 'An error occurred',
      statusCode: json['statusCode'] ?? 500,
      errors: json['errors'],
    );
  }
}

