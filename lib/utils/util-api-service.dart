import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bushra_mobile/utils/providers/provider-session.dart';
import 'package:bushra_mobile/utils/util-app-exception.dart';
import 'package:bushra_mobile/utils/util-get-imei.dart';
import 'package:bushra_mobile/utils/util-log-service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../remote-config-services.dart';
import 'api_module.dart';

class ApiService {

  static const String _getTokenEndpoint = '/oauth2/token';
  static String? _cachedToken;
  static DateTime? _tokenExpiry;

  String generateBasicAuthToken() {
    String credentials = "${RemoteConfigService.clientId}:${RemoteConfigService.clientSecret}";
    String encodedCredentials = base64Encode(utf8.encode(credentials));
    return encodedCredentials;
  }

  //TODO Create a custom HTTP client that trusts self-signed certificates
  static http.Client _createCustomHttpClient() {
    final HttpClient client = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true; // Trust all certificates
    client.connectionTimeout = RemoteConfigService.connectionTimeout;
    client.idleTimeout = RemoteConfigService.readTimeout;
    client.maxConnectionsPerHost = 10; // Set max connections per host
    client.autoUncompress = true; // Enable automatic decompression
    return IOClient(client);
  }

  Future<String> getToken() async {
    try {
      if (_cachedToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
        return _cachedToken!;
      }

      final authHeader = generateBasicAuthToken();

      if(RemoteConfigService.isProdBuild == 'false') {
        if (kDebugMode) {
          print("--- API DEV PROFILE --");
        }
      } else {
        if (kDebugMode) {
          print("--- API PROD PROFILE --");
        }
      }

      final client = _createCustomHttpClient();
      final scope = await DeviceIdentifier.getDeviceIdentifier();
      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic MzhrWjlGdUVMaUN5UHpGZnBEMWZsSXdGaEhzYTpCYVlqRHJiQ1BPUm5jTWVlRjh3WEtiR0lSdlVh',
      };

      final response = await client.post(
        Uri.parse(RemoteConfigService.baseUrlToken + _getTokenEndpoint),
        headers: headers,
        body: {
          'grant_type': 'client_credentials',
          'scope': scope
        },
      ).timeout(const Duration(seconds: 30)); // Added timeout

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        _cachedToken = responseData['access_token'];
        _tokenExpiry = DateTime.now().add(const Duration(hours: 1)); // Set TTL to 1 hour
        return _cachedToken!;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw AppException('SEC101'); // Unauthorized
      }else{
        throw AppException('SEC100'); // Other server error
      }

    } on SocketException catch (e) {
      if (kDebugMode) {
        print('Network error while fetching token: $e');
      }
      throw AppException('NET100'); // Network connectivity error

    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('Token request timed out: $e');
      }
      throw AppException('NET101'); // Request timeout

    } on FormatException catch (e) {
      if (kDebugMode) {
        print('Invalid response format: $e');
      }
      throw AppException('API100'); // Invalid response format

    } on HttpException catch (e) {
      if (kDebugMode) {
        print('HTTP error: $e');
      }
      throw AppException('API101'); // HTTP error

    } on http.ClientException catch (e) {
      if (kDebugMode) {
        print('Client error: $e');
      }
      throw AppException('API102'); // Client error

    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Unexpected error in getToken: $e');
        print('Stack trace: $stackTrace');
      }
      throw AppException('SYS100'); // Unexpected system error
    }
  }

  Future<dynamic> makeApiCall(
      String endpoint,
      ApiModule module,
      {
        String method = 'GET',
        Map<String, dynamic>? body,
      }
      ) async {
    final context = navigatorKey.currentContext;
    final userToken = Provider.of<SessionProvider>(context!, listen: false).userToken;
    final stopwatch = Stopwatch()..start();
    var token = userToken.trim();

    bool isTokenInvalid(String token) => token.trim().isEmpty || token.trim() == 'null';
    if (isTokenInvalid(token)) {
      token = (await getToken()).trim();
    }

    final headers = {
      'Content-Type': 'application/json',
      'apikey': RemoteConfigService.apiKey,
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    headers.removeWhere((key, value) => value.isEmpty);

    final client = _createCustomHttpClient();
    late http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await client.get(Uri.parse(RemoteConfigService.baseUrl + endpoint),
              headers: headers);
          break;
        case 'POST':
          response = await client.post(Uri.parse(RemoteConfigService.baseUrl + endpoint),
              headers: headers,
              body: jsonEncode(body));
          break;
        case 'PUT':
          response = await client.put(Uri.parse(RemoteConfigService.baseUrl + endpoint),
              headers: headers,
              body: jsonEncode(body));
          break;
        case 'DELETE':
          response = await client.delete(Uri.parse(RemoteConfigService.baseUrl + endpoint),
              headers: headers);
          break;
        default:
          throw AppException('${module.prefix}003'); // Unsupported method
      }
    } on SocketException {
      throw AppException('${module.prefix}100'); // Network issue
    } on HttpException {
      throw AppException('SYS100'); // Server unreachable
    } catch (_) {
      throw AppException('SYS001'); // Unknown error
    }

    if (!(response.statusCode == 200 || response.statusCode == 201)) {
      LoggerService.reportHttpError(response, Uri.parse(RemoteConfigService.baseUrl + endpoint), method);
    }
    if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 404) {
      stopwatch.stop();
      logApiCall(
        method: method,
        endpoint: endpoint,
        headers: headers,
        body: body,
        response: response,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      _cachedToken = null;
      _tokenExpiry = null;
      stopwatch.stop();
      logApiCall(
        method: method,
        endpoint: endpoint,
        headers: headers,
        body: body,
        response: response,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      return makeApiCall(endpoint, module, method: method, body: body); // Retry with a new token
    } else if (response.statusCode == 500) {
      stopwatch.stop();
      LoggerService.reportHttpError(response, Uri.parse(RemoteConfigService.baseUrl + endpoint), method);
      logApiCall(
        method: method,
        endpoint: endpoint,
        headers: headers,
        body: body,
        response: response,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      throw AppException('SYS002'); // Server error
    } else {
      stopwatch.stop();
      logApiCall(
        method: method,
        endpoint: endpoint,
        headers: headers,
        body: body,
        response: response,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      throw AppException('SYS001'); // Generic fallback
    }
  }

  void logApiCall({
    required String method,
    required String endpoint,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
    required http.Response response,
    required int durationMs,
  }) {
    if (kDebugMode) {
      print('➡️ [$method] ${RemoteConfigService.baseUrl}$endpoint');
      print('➡️ Headers: $headers');
      print('➡️ Request Body: $body');
      print('⬅️ Status: ${response.statusCode} (in Duration : ${durationMs}ms)');
      print('⬅️ Body: ${response.body}');
    }
  }
}
