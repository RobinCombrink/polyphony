import "dart:convert";

import "package:dio/dio.dart";
import "package:polyphony_flutter_client/shared/errors/polyphony_exceptions.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

abstract class RestRequestServiceBase {
  RestRequestServiceBase({required Dio dio}) : _dio = dio;

  final Dio _dio;

  List<Map<String, dynamic>> decodeList(Object? data) {
    if (data is! List<dynamic>) {
      return const <Map<String, dynamic>>[];
    }

    return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<Result<List<T>>> performListRequest<T>({
    required String endpoint,
    required String operation,
    required T Function(Map<String, dynamic>) decodeItem,
  }) async {
    try {
      final response = await _dio.get<Object?>(endpoint);
      final statusCode = response.statusCode ?? 0;

      if (statusCode < 200 || statusCode >= 300) {
        return Error<List<T>>(
          apiRequestException(
            operation: operation,
            statusCode: statusCode,
            responseBody: responseBodyString(response.data),
          ),
        );
      }

      final items = decodeList(response.data).map(decodeItem).toList();
      return Ok<List<T>>(items);
    } on DioException catch (error) {
      return _dioError<List<T>>(operation: operation, error: error);
    } on Exception catch (error) {
      return Error<List<T>>(error);
    }
  }

  Future<Result<T>> performGetRequest<T>({
    required String endpoint,
    required String operation,
    required T Function(Map<String, dynamic>) decodeItem,
  }) async {
    try {
      final response = await _dio.get<Object?>(endpoint);
      final statusCode = response.statusCode ?? 0;

      if (statusCode < 200 || statusCode >= 300) {
        return Error<T>(
          apiRequestException(
            operation: operation,
            statusCode: statusCode,
            responseBody: responseBodyString(response.data),
          ),
        );
      }

      final decoded = decodeMap(response.data);
      if (decoded == null) {
        return Error<T>(
          Exception("Failed to $operation: invalid response payload"),
        );
      }

      return Ok<T>(decodeItem(decoded));
    } on DioException catch (error) {
      return _dioError<T>(operation: operation, error: error);
    } on Exception catch (error) {
      return Error<T>(error);
    }
  }

  Future<Result<T>> performPostRequest<T>({
    required String endpoint,
    required String operation,
    required Map<String, dynamic> body,
    required int expectedStatusCode,
    required T Function(Map<String, dynamic>) decodeItem,
  }) async {
    try {
      final response = await _dio.post<Object?>(endpoint, data: body);
      final statusCode = response.statusCode ?? 0;

      if (statusCode != expectedStatusCode) {
        return Error<T>(
          apiRequestException(
            operation: operation,
            statusCode: statusCode,
            responseBody: responseBodyString(response.data),
          ),
        );
      }

      final decoded = decodeMap(response.data);
      if (decoded == null) {
        return Error<T>(
          Exception("Failed to $operation: invalid response payload"),
        );
      }

      return Ok<T>(decodeItem(decoded));
    } on DioException catch (error) {
      return _dioError<T>(operation: operation, error: error);
    } on Exception catch (error) {
      return Error<T>(error);
    }
  }

  Future<Result<T>> performPatchRequest<T>({
    required String endpoint,
    required String operation,
    required Map<String, dynamic> body,
    required int expectedStatusCode,
    required T Function(Map<String, dynamic>) decodeItem,
  }) async {
    try {
      final response = await _dio.patch<Object?>(endpoint, data: body);
      final statusCode = response.statusCode ?? 0;

      if (statusCode != expectedStatusCode) {
        return Error<T>(
          apiRequestException(
            operation: operation,
            statusCode: statusCode,
            responseBody: responseBodyString(response.data),
          ),
        );
      }

      final decoded = decodeMap(response.data);
      if (decoded == null) {
        return Error<T>(
          Exception("Failed to $operation: invalid response payload"),
        );
      }

      return Ok<T>(decodeItem(decoded));
    } on DioException catch (error) {
      return _dioError<T>(operation: operation, error: error);
    } on Exception catch (error) {
      return Error<T>(error);
    }
  }

  Future<Result<void>> performPatchRequestWithoutResponseBody({
    required String endpoint,
    required String operation,
    required Map<String, dynamic> body,
    required int expectedStatusCode,
  }) async {
    try {
      final response = await _dio.patch<Object?>(endpoint, data: body);
      final statusCode = response.statusCode ?? 0;

      if (statusCode != expectedStatusCode) {
        return Error<void>(
          apiRequestException(
            operation: operation,
            statusCode: statusCode,
            responseBody: responseBodyString(response.data),
          ),
        );
      }

      return const Ok<void>(null);
    } on DioException catch (error) {
      return _dioError<void>(operation: operation, error: error);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  Future<Result<void>> performDeleteRequest({
    required String endpoint,
    required String operation,
    required int expectedStatusCode,
  }) async {
    try {
      final response = await _dio.delete<Object?>(endpoint);
      final statusCode = response.statusCode ?? 0;

      if (statusCode != expectedStatusCode) {
        return Error<void>(
          apiRequestException(
            operation: operation,
            statusCode: statusCode,
            responseBody: responseBodyString(response.data),
          ),
        );
      }

      return const Ok<void>(null);
    } on DioException catch (error) {
      return _dioError<void>(operation: operation, error: error);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  Future<Result<void>> performPostRequestWithoutResponseBody({
    required String endpoint,
    required String operation,
    required Map<String, dynamic> body,
    required int expectedStatusCode,
  }) async {
    try {
      final response = await _dio.post<Object?>(endpoint, data: body);
      final statusCode = response.statusCode ?? 0;

      if (statusCode != expectedStatusCode) {
        return Error<void>(
          apiRequestException(
            operation: operation,
            statusCode: statusCode,
            responseBody: responseBodyString(response.data),
          ),
        );
      }

      return const Ok<void>(null);
    } on DioException catch (error) {
      return _dioError<void>(operation: operation, error: error);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  Map<String, dynamic>? decodeMap(Object? data) {
    return switch (data) {
      Map<dynamic, dynamic>() => Map<String, dynamic>.from(data),
      _ => null,
    };
  }

  String responseBodyString(Object? data) {
    return switch (data) {
      null => "",
      final String value => value,
      _ => jsonEncode(data),
    };
  }

  Error<T> _dioError<T>({
    required String operation,
    required DioException error,
  }) {
    final response = error.response;
    final statusCode = response?.statusCode;

    if (statusCode == null) {
      return Error<T>(error);
    }

    return Error<T>(
      apiRequestException(
        operation: operation,
        statusCode: statusCode,
        responseBody: responseBodyString(response?.data),
      ),
    );
  }

  ApiRequestException apiRequestException({
    required String operation,
    required int statusCode,
    required String responseBody,
  }) {
    return ApiRequestException(
      operation: operation,
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }
}
