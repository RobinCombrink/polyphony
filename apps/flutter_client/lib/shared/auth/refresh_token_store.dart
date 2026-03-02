import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:polyphony_flutter_client/shared/result/result.dart";

sealed class RefreshTokenStore {
  Future<Result<String?>> readRefreshToken();
  Future<Result<void>> writeRefreshToken(String refreshToken);
  Future<Result<void>> deleteRefreshToken();
}

final class SecureRefreshTokenStore implements RefreshTokenStore {
  SecureRefreshTokenStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _refreshTokenKey = "auth0_refresh_token";

  final FlutterSecureStorage _secureStorage;

  @override
  Future<Result<String?>> readRefreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      final trimmedToken = refreshToken?.trim();
      if (trimmedToken == null || trimmedToken.isEmpty) {
        return const Ok<String?>(null);
      }

      return Ok<String?>(trimmedToken);
    } on MissingPluginException catch (error) {
      return Error<String?>(error);
    } on Exception catch (error) {
      return Error<String?>(error);
    }
  }

  @override
  Future<Result<void>> writeRefreshToken(String refreshToken) async {
    final trimmedToken = refreshToken.trim();

    if (trimmedToken.isEmpty) {
      return const Ok<void>(null);
    }

    try {
      await _secureStorage.write(key: _refreshTokenKey, value: trimmedToken);
      return const Ok<void>(null);
    } on MissingPluginException catch (error) {
      return Error<void>(error);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }

  @override
  Future<Result<void>> deleteRefreshToken() async {
    try {
      await _secureStorage.delete(key: _refreshTokenKey);
      return const Ok<void>(null);
    } on MissingPluginException catch (error) {
      return Error<void>(error);
    } on Exception catch (error) {
      return Error<void>(error);
    }
  }
}

final class UnsupportedRefreshTokenStore implements RefreshTokenStore {
  const UnsupportedRefreshTokenStore();

  @override
  Future<Result<String?>> readRefreshToken() async {
    return const Ok<String?>(null);
  }

  @override
  Future<Result<void>> writeRefreshToken(String refreshToken) async {
    return const Ok<void>(null);
  }

  @override
  Future<Result<void>> deleteRefreshToken() async {
    return const Ok<void>(null);
  }
}

RefreshTokenStore createRefreshTokenStore() {
  switch (kIsWeb) {
    case true:
      return const UnsupportedRefreshTokenStore();
    case false:
      return SecureRefreshTokenStore();
  }
}
