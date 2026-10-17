import 'package:flutter_test/flutter_test.dart';
import 'package:tokigo/core/network/api_client.dart';
import 'package:tokigo/core/network/api_error.dart';
import 'package:tokigo/core/network/api_result.dart';
import 'package:tokigo/core/repositories/impl/home_repository_impl.dart';

class _HomeApiClient implements ApiClient {
  _HomeApiClient(this.payload);

  final List<dynamic> payload;

  @override
  String get baseUrl => 'http://test';

  @override
  Duration get defaultTimeout => const Duration(seconds: 1);

  @override
  Map<String, String> get defaultHeaders => const {};

  @override
  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) async => ApiResult.success(payload as T);

  @override
  Future<ApiResult<T>> post<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) => _unsupported();

  @override
  Future<ApiResult<T>> put<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) => _unsupported();

  @override
  Future<ApiResult<T>> patch<T>(
    String path, {
    Object? body,
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) => _unsupported();

  @override
  Future<ApiResult<T>> delete<T>(
    String path, {
    Map<String, String>? headers,
    Duration? timeout,
    RequestToken? token,
  }) => _unsupported();

  @override
  ApiResult<T> mapError<T>(Object error, {StackTrace? stackTrace}) =>
      const ApiResult.failure(ApiUnknownError());

  Future<ApiResult<T>> _unsupported<T>() =>
      Future<ApiResult<T>>.error(UnimplementedError());
}

void main() {
  test(
    'parses the Home backend schema without losing card presentation fields',
    () async {
      final repository = HomeRepositoryImpl(
        _HomeApiClient([
          {
            'id': 'section-1',
            'title': 'Recommended',
            'subtitle': 'For you',
            'layout': 'horizontal',
            'cards': [
              {
                'id': 'card-1',
                'type': 'hotel',
                'title': 'Grand Palm',
                'price': 250,
                'rating': 4.8,
                'reviewCount': 120,
                'action': 'View hotel',
                'rawPrice': 300,
                'metadata': {'city': 'Cairo'},
              },
            ],
          },
        ]),
      );

      final result = await repository.getHomeSections();
      final sections = result.valueOrNull!;
      final card = sections.single.items.single;

      expect(sections.single.layout.name, 'horizontal');
      expect(card.type.name, 'hotel');
      expect(card.reviewCount, 120);
      expect(card.actionLabel, 'View hotel');
      expect(card.rawPrice, 300);
      expect(card.metadata['city'], 'Cairo');
    },
  );
}
