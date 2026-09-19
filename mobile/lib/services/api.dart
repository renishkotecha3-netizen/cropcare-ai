import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

class Api {
static const String baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://cropcare-aix.onrender.com/api',
);
  final storage = const FlutterSecureStorage();
  String? token;
  void Function()? onUnauthorized;

  Map<String, String> get headers => {
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
  Uri uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/$path');
  Future<void> restore() async {
    token = await storage.read(key: 'session');
  }

  Future<void> saveToken(String value) async {
    token = value;
    await storage.write(key: 'session', value: value);
  }

  Future<void> clear() async {
    token = null;
    await storage.delete(key: 'session');
  }

  dynamic decode(http.Response response) {
    dynamic body;
    try {
      body = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        'The server returned an unexpected response. Check the API address.',
        response.statusCode,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    if (response.statusCode == 401 && token != null) onUnauthorized?.call();
    String describe(dynamic value) {
      if (value is List) return value.map(describe).join('\n');
      if (value is Map)
        return value.entries
            .where((e) => e.key != 'code')
            .map(
              (e) => e.key == 'detail'
                  ? describe(e.value)
                  : '${e.key}: ${describe(e.value)}',
            )
            .join('\n');
      return value.toString();
    }

    throw ApiException(
      body == null
          ? 'Request failed (${response.statusCode}).'
          : describe(body),
      response.statusCode,
    );
  }

  Future<dynamic> call(
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    final client = http.Client();
    try {
      final request = http.Request(method, uri(path))
        ..headers.addAll({...headers, 'Content-Type': 'application/json'});
      if (data != null) request.body = jsonEncode(data);
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 25));
      return decode(response);
    } on TimeoutException {
      throw ApiException('The server took too long. Please try again.');
    } on http.ClientException {
      throw ApiException(
        'Cannot reach the server. Check your internet connection and API address.',
      );
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> analyze(
    XFile image,
    String crop,
    String notes, {
    String? parentId,
  }) async {
    final client = http.Client();
    try {
      final request = http.MultipartRequest('POST', uri('scans/'))
        ..headers.addAll(headers);
      request.fields.addAll({
        'crop': crop,
        'notes': notes,
        if (parentId != null) 'parent_id': parentId,
      });
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          await image.readAsBytes(),
          filename: image.name,
        ),
      );
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 120));
      return Map<String, dynamic>.from(decode(response));
    } on TimeoutException {
      throw ApiException(
        'Analysis is taking longer than expected. Check History before submitting again.',
      );
    } on http.ClientException {
      throw ApiException('Upload failed. Check your connection and try again.');
    } finally {
      client.close();
    }
  }
}
