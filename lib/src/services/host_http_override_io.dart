import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/constants.dart';
import 'app_api_error_service.dart';

HttpOverrides? _previousOverrides;
bool _isInstalled = false;

void installHostHttpMonitoring({
  required AppApiErrorService service,
  required Uri sdkApiBaseUri,
}) {
  if (_isInstalled) return;
  _previousOverrides = HttpOverrides.current;
  HttpOverrides.global = _CovaoneHttpOverrides(
    previousOverrides: _previousOverrides,
    service: service,
    sdkApiBaseUri: sdkApiBaseUri,
  );
  _isInstalled = true;
}

void uninstallHostHttpMonitoring() {
  if (!_isInstalled) return;
  HttpOverrides.global = _previousOverrides;
  _previousOverrides = null;
  _isInstalled = false;
}

T runWithHostHttpMonitoring<T>(T Function() body) {
  // Backward-compatible no-op: monitoring is installed globally at init().
  return body();
}

class _CovaoneHttpOverrides extends HttpOverrides {
  final HttpOverrides? previousOverrides;
  final AppApiErrorService service;
  final Uri sdkApiBaseUri;

  _CovaoneHttpOverrides({
    required this.previousOverrides,
    required this.service,
    required this.sdkApiBaseUri,
  });

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    // Must use super / previousOverrides — never `HttpClient()` here.
    // Calling HttpClient() re-enters this override and stack-overflows.
    final baseClient = previousOverrides?.createHttpClient(context) ??
        super.createHttpClient(context);
    return _CovaoneMonitoringHttpClient(
      inner: baseClient,
      service: service,
      sdkApiBaseUri: sdkApiBaseUri,
    );
  }
}

class _CovaoneMonitoringHttpClient implements HttpClient {
  final HttpClient inner;
  final AppApiErrorService service;
  final Uri sdkApiBaseUri;

  _CovaoneMonitoringHttpClient({
    required this.inner,
    required this.service,
    required this.sdkApiBaseUri,
  });

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final req = await inner.openUrl(method, url);
    return _CovaoneMonitoringHttpClientRequest(
      inner: req,
      method: method,
      uri: url,
      service: service,
      sdkApiBaseUri: sdkApiBaseUri,
    );
  }

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) async {
    final req = await inner.open(method, host, port, path);
    final uri = Uri(scheme: 'https', host: host, port: port, path: path);
    return _CovaoneMonitoringHttpClientRequest(
      inner: req,
      method: method,
      uri: uri,
      service: service,
      sdkApiBaseUri: sdkApiBaseUri,
    );
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  void close({bool force = false}) => inner.close(force: force);

  @override
  Duration get idleTimeout => inner.idleTimeout;

  @override
  set idleTimeout(Duration value) => inner.idleTimeout = value;

  @override
  bool get autoUncompress => inner.autoUncompress;

  @override
  set autoUncompress(bool value) => inner.autoUncompress = value;

  @override
  String? get userAgent => inner.userAgent;

  @override
  set userAgent(String? value) => inner.userAgent = value;

  @override
  Duration? get connectionTimeout => inner.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;

  @override
  int? get maxConnectionsPerHost => inner.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) => inner.maxConnectionsPerHost = value;

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      inner.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      inner.badCertificateCallback = callback;

  @override
  set findProxy(String Function(Uri url)? f) => inner.findProxy = f;

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set keyLog(void Function(String line)? callback) => inner.keyLog = callback;

  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(
                  Uri url, String? proxyHost, int? proxyPort)?
              f) =>
      inner.connectionFactory = f;
}

class _CovaoneMonitoringHttpClientRequest implements HttpClientRequest {
  final HttpClientRequest inner;
  final String _method;
  final Uri _uri;
  final AppApiErrorService service;
  final Uri sdkApiBaseUri;

  _CovaoneMonitoringHttpClientRequest({
    required this.inner,
    required String method,
    required Uri uri,
    required this.service,
    required this.sdkApiBaseUri,
  })  : _method = method,
        _uri = uri;

  @override
  Future<HttpClientResponse> close() async {
    try {
      final response = await inner.close();
      final statusCode = response.statusCode;
      if (statusCode >= 300 && !_isSdkRequest()) {
        service.report(
          AppApiErrorEvent(
            source: AppApiErrorSource.automaticGlobalHttp,
            method: _method,
            uri: _uri,
            statusCode: statusCode,
            message: response.reasonPhrase,
            timestamp: DateTime.now(),
          ),
        );
      }
      return response;
    } on Object catch (error) {
      if (!_isSdkRequest()) {
        service.report(
          AppApiErrorEvent(
            source: AppApiErrorSource.automaticGlobalHttp,
            method: _method,
            uri: _uri,
            statusCode: null,
            message: error.toString(),
            timestamp: DateTime.now(),
          ),
        );
      }
      rethrow;
    }
  }

  bool _isSdkRequest() {
    final internalHeader =
        headers.value(CovaoneConstants.sdkInternalRequestHeader)?.toLowerCase();
    if (internalHeader == 'true') return true;
    return _sameOrigin(_uri, sdkApiBaseUri);
  }

  bool _sameOrigin(Uri a, Uri b) {
    final aPort = a.hasPort ? a.port : _defaultPortForScheme(a.scheme);
    final bPort = b.hasPort ? b.port : _defaultPortForScheme(b.scheme);
    return a.scheme == b.scheme && a.host == b.host && aPort == bPort;
  }

  int _defaultPortForScheme(String scheme) {
    if (scheme == 'https' || scheme == 'wss') return 443;
    if (scheme == 'http' || scheme == 'ws') return 80;
    return 0;
  }

  @override
  Encoding get encoding => inner.encoding;

  @override
  set encoding(Encoding value) => inner.encoding = value;

  @override
  void add(List<int> data) => inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => inner.addStream(stream);

  @override
  Future<void> flush() => inner.flush();

  @override
  void write(Object? object) => inner.write(object);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => inner.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => inner.writeln(object);

  @override
  Future<HttpClientResponse> get done => inner.done;

  @override
  HttpConnectionInfo? get connectionInfo => inner.connectionInfo;

  @override
  int get contentLength => inner.contentLength;

  @override
  set contentLength(int value) => inner.contentLength = value;

  @override
  List<Cookie> get cookies => inner.cookies;

  @override
  bool get followRedirects => inner.followRedirects;

  @override
  set followRedirects(bool value) => inner.followRedirects = value;

  @override
  int get maxRedirects => inner.maxRedirects;

  @override
  set maxRedirects(int value) => inner.maxRedirects = value;

  @override
  bool get persistentConnection => inner.persistentConnection;

  @override
  set persistentConnection(bool value) => inner.persistentConnection = value;

  @override
  String get method => inner.method;

  @override
  Uri get uri => inner.uri;

  @override
  HttpHeaders get headers => inner.headers;

  @override
  bool get bufferOutput => inner.bufferOutput;

  @override
  set bufferOutput(bool value) => inner.bufferOutput = value;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      inner.abort(exception, stackTrace);
}
