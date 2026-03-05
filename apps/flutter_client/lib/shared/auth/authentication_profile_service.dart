import "dart:convert";

import "package:http/http.dart" as http;
import "package:polyphony_flutter_client/shared/config/polyphony_config.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/network/api_models.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

class AuthenticationProfileService {
  const AuthenticationProfileService({required http.Client httpClient})
      : _httpClient = httpClient;

  final http.Client _httpClient;

  Future<Result<ApiMe>> getMe({required String bearerToken}) async {
    try {
      final response = await _httpClient.get(
        Uri.parse("${PolyphonyConfig.backendBaseUrl}/api/v1/me"),
        headers: <String, String>{
          "Authorization": "Bearer $bearerToken",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Error<ApiMe>(
          ApiRequestException(
            operation: "get me",
            statusCode: response.statusCode,
            responseBody: response.body,
          ),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return Error<ApiMe>(
          Exception("Failed to get me: invalid response payload"),
        );
      }

      return Ok<ApiMe>(ApiMe.fromJson(Map<String, dynamic>.from(decoded)));
    } on Exception catch (error) {
      return Error<ApiMe>(error);
    }
  }
}
