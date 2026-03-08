import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

// ── TTL cache ──────────────────────────────────────────────────────────────

class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;
  _CacheEntry(this.data, Duration ttl)
      : expiresAt = DateTime.now().add(ttl);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class _CacheInterceptor extends Interceptor {
  final _store = <String, _CacheEntry>{};

  Duration _ttl(String path) {
    if (path.contains('/tasks/today')) return const Duration(seconds: 30);
    if (path.contains('/events/this-week')) return const Duration(minutes: 3);
    if (path.contains('/users/me/karma')) return const Duration(minutes: 2);
    if (path.contains('/families') && !path.contains('/members')) {
      return const Duration(minutes: 5);
    }
    if (path.contains('/shopping/my-lists')) return const Duration(minutes: 2);
    if (path.contains('/notifications/')) return const Duration(seconds: 15);
    return Duration.zero;
  }

  void _invalidate(String pathFragment) {
    _store.removeWhere((k, _) => k.contains(pathFragment));
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.method == 'GET') {
      final ttl = _ttl(options.path);
      if (ttl > Duration.zero) {
        final key = options.uri.toString();
        final entry = _store[key];
        if (entry != null && !entry.isExpired) {
          handler.resolve(
            Response(requestOptions: options, data: entry.data, statusCode: 200),
          );
          return;
        }
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final method = response.requestOptions.method;
    final path = response.requestOptions.path;

    if (method == 'GET') {
      final ttl = _ttl(path);
      if (ttl > Duration.zero) {
        _store[response.requestOptions.uri.toString()] =
            _CacheEntry(response.data, ttl);
      }
    } else {
      // Invalidate related caches on mutations
      if (path.contains('/tasks')) _invalidate('/tasks');
      if (path.contains('/events')) {
        _invalidate('/events');
        _invalidate('/tasks'); // today tasks include event tasks
      }
      if (path.contains('/shopping')) _invalidate('/shopping');
      if (path.contains('/families')) _invalidate('/families');
      if (path.contains('/users/me')) _invalidate('/users/me');
      if (path.contains('/notifications')) _invalidate('/notifications');
    }
    handler.next(response);
  }
}

// ── ApiClient singleton ────────────────────────────────────────────────────

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: kApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'ngrok-skip-browser-warning': 'true'},
    ));

    // Auth interceptor — injects JWT from SharedPreferences
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );

    // Cache interceptor — TTL-based GET caching with mutation invalidation
    dio.interceptors.add(_CacheInterceptor());
  }
}
