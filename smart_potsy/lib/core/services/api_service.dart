import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class ApiService {
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<ApiResponse> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return ApiResponse(success: false, error: 'კავშირის შეცდომა: $e');
    }
  }

  Future<ApiResponse> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _headers,
      );
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return ApiResponse(success: false, error: 'კავშირის შეცდომა: $e');
    }
  }

  Future<ApiResponse> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: _headers,
      );
      return ApiResponse.fromResponse(response);
    } catch (e) {
      return ApiResponse(success: false, error: 'კავშირის შეცდომა: $e');
    }
  }
}

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;
  final int? statusCode;

  ApiResponse({required this.success, this.data, this.error, this.statusCode});

  factory ApiResponse.fromResponse(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    final success = response.statusCode >= 200 && response.statusCode < 300;

    // Extract the 'data' field from the API response wrapper
    // Backend returns: { success: bool, data: {...}, timestamp: string }
    final data = body is Map ? body['data'] : body;
    final errorInfo = body is Map ? body['error'] : null;
    final errorMessage =
        errorInfo is Map ? errorInfo['message'] : errorInfo?.toString();

    return ApiResponse(
      success: success && (body?['success'] ?? true),
      data: data,
      error: success ? null : (errorMessage ?? 'Unknown error'),
      statusCode: response.statusCode,
    );
  }
}
