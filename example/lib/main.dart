// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:covaone_sdk/covaone_chat.dart';

/// Entry point — initialise the Covaone SDK before the first frame renders.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CovaoneChat.init(
    publicKey:
        '<YOUR PUBLIC KEY>', // TODO: replace with your account public key
    // apiBase defaults to https://api.covaone.com/
    apiBase: 'http://localhost:8081/',
    // wsBase defaults to https://sync-c.covaone.com/
    // Override for local Socket.IO: wsBase: 'ws://localhost:4000/',
    // When your app already knows the signed-in user, pass their identity here
    // to skip the in-chat email/name form:
    userEmail: '<YOUR EMAIL>',
    userFullName: '<YOUR FULL NAME>',
    autoIntercept: true,
    helpCardPosition: CovaoneHelpCardPosition.top,
  );

  // Optional: receive a native callback whenever an incoming call arrives.
  CovaoneChat.onIncomingCall((callId, agentName) {
    print('[CovaoneChat] Incoming call from $agentName (id: $callId)');
  });

  // Optional: logs host-app API errors captured by any integration path.
  CovaoneChat.onAppApiError((event) {
    print(
      '[CovaoneChat][HostApiError] source=${event.source.name} '
      'status=${event.statusCode} method=${event.method} uri=${event.uri}',
    );
  });

  runApp(const CovaoneExampleApp());
}

class CovaoneExampleApp extends StatelessWidget {
  const CovaoneExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Covaone Chat Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF592C83),
        useMaterial3: true,
      ),
      home: const _DemoHome(),
    );
  }
}

class _DemoHome extends StatelessWidget {
  const _DemoHome();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Host-app content ───────────────────────────────────────────────
        Scaffold(
          appBar: AppBar(
            title: const Text('Covaone Chat Demo'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionTitle('Panel Control'),
                const SizedBox(height: 12),
                const _DemoButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Open Chat',
                  onTap: CovaoneChat.open,
                ),
                const SizedBox(height: 10),
                const _DemoButton(
                  icon: Icons.keyboard_arrow_down_rounded,
                  label: 'Close Chat',
                  onTap: CovaoneChat.close,
                ),
                const SizedBox(height: 10),
                const _DemoButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Toggle Chat',
                  onTap: CovaoneChat.toggle,
                ),
                const SizedBox(height: 32),
                const _SectionTitle('Call Control'),
                const SizedBox(height: 12),
                const _DemoButton(
                  icon: Icons.call_end_rounded,
                  label: 'End Active Call',
                  color: Color(0xFFFF4D4D),
                  onTap: CovaoneChat.endCall,
                ),
                const SizedBox(height: 32),
                const _ApiStatusSection(),
                const SizedBox(height: 32),
                const _SectionTitle('Session Info'),
                const SizedBox(height: 12),
                _DemoButton(
                  icon: Icons.info_outline_rounded,
                  label: 'Log Session Info',
                  onTap: () {
                    final info = CovaoneChat.getSessionInfo();
                    print('[CovaoneChat] $info');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('SDK v${CovaoneChat.version} | '
                            'Session: ${info.sessionId ?? "none"} | '
                            'Tab: ${info.currentTab ?? "—"}'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                const _SectionTitle('Lifecycle'),
                const SizedBox(height: 12),
                _DemoButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Destroy SDK (logout)',
                  color: const Color(0xFF9E9E9E),
                  onTap: () async {
                    await CovaoneChat.destroy();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('SDK destroyed. Call init() again.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),

        // ── Covaone Chat Launcher ───────────────────────────────────────────
        // Must be the last item in the Stack so it renders above all content.
        CovaoneChat.launcher(),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(color: const Color(0xFF9E9E9E), letterSpacing: 0.8),
    );
  }
}

class _DemoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DemoButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: c,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _ApiProbe {
  final int expectedCode;
  final String label;
  final String url;

  const _ApiProbe({
    required this.expectedCode,
    required this.label,
    required this.url,
  });
}

class _ApiStatusSection extends StatefulWidget {
  const _ApiStatusSection();

  @override
  State<_ApiStatusSection> createState() => _ApiStatusSectionState();
}

class _ApiStatusSectionState extends State<_ApiStatusSection> {
  static const _probes = [
    _ApiProbe(
      expectedCode: 200,
      label: '200 OK',
      url: 'https://jsonplaceholder.typicode.com/posts/1',
    ),
    _ApiProbe(
      expectedCode: 201,
      label: '201 Created',
      url: 'https://postman-echo.com/status/201',
    ),
    _ApiProbe(
      expectedCode: 300,
      label: '300 Multiple Choices',
      url: 'https://postman-echo.com/status/300',
    ),
    _ApiProbe(
      expectedCode: 401,
      label: '401 Unauthorized',
      url: 'https://postman-echo.com/status/401',
    ),
    _ApiProbe(
      expectedCode: 404,
      label: '404 Not Found',
      url: 'https://pokeapi.co/api/v2/pokemon/99999999',
    ),
    _ApiProbe(
      expectedCode: 500,
      label: '500 Server Error',
      url: 'https://postman-echo.com/status/500',
    ),
  ];

  bool _loading = false;
  String? _activeLabel;
  _ApiResult? _lastResult;

  Future<void> _callApi(_ApiProbe probe) async {
    setState(() {
      _loading = true;
      _activeLabel = probe.label;
      _lastResult = null;
    });

    final started = DateTime.now();
    try {
      print('[ApiProbe] GET ${probe.url}');
      final uri = Uri.parse(probe.url);
      final response = await http.get(uri).timeout(const Duration(seconds: 12));

      final elapsed = DateTime.now().difference(started).inMilliseconds;
      final result = _ApiResult(
        label: probe.label,
        url: probe.url,
        statusCode: response.statusCode,
        reasonPhrase: response.reasonPhrase ?? '—',
        elapsedMs: elapsed,
      );

      print(
          '[ApiProbe] ${probe.label} → ${response.statusCode} (${probe.url})');

      if (response.statusCode >= 400) {
        CovaoneChat.reportAppApiError(
          statusCode: response.statusCode,
          method: 'GET',
          uri: uri,
          message: response.reasonPhrase,
        );
      }

      if (!mounted) return;
      setState(() => _lastResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${probe.label}: HTTP ${response.statusCode}'),
          backgroundColor: _statusColor(response.statusCode),
        ),
      );
    } catch (e) {
      print('[ApiProbe] ${probe.label} failed: $e');
      CovaoneChat.reportAppApiError(
        method: 'GET',
        uri: Uri.parse(probe.url),
        message: e.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${probe.label} failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _activeLabel = null;
        });
      }
    }
  }

  Color _statusColor(int code) {
    if (code >= 200 && code < 300) return const Color(0xFF2E7D32);
    if (code >= 300 && code < 400) return const Color(0xFF1565C0);
    if (code >= 400 && code < 500) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('HTTP Status Simulation'),
        const SizedBox(height: 8),
        Text(
          'Tap a button to call a public API and read the real status code.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9E9E9E),
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final probe in _probes)
              _StatusCodeButton(
                label: probe.label,
                code: probe.expectedCode,
                loading: _loading && _activeLabel == probe.label,
                onTap: _loading ? null : () => _callApi(probe),
              ),
          ],
        ),
        if (_lastResult != null) ...[
          const SizedBox(height: 16),
          _ApiResultCard(result: _lastResult!),
        ],
      ],
    );
  }
}

class _ApiResult {
  final String label;
  final String url;
  final int statusCode;
  final String reasonPhrase;
  final int elapsedMs;

  const _ApiResult({
    required this.label,
    required this.url,
    required this.statusCode,
    required this.reasonPhrase,
    required this.elapsedMs,
  });
}

class _StatusCodeButton extends StatelessWidget {
  final String label;
  final int code;
  final bool loading;
  final VoidCallback? onTap;

  const _StatusCodeButton({
    required this.label,
    required this.code,
    required this.loading,
    required this.onTap,
  });

  Color _colorForCode(int c) {
    if (c >= 200 && c < 300) return const Color(0xFF2E7D32);
    if (c >= 300 && c < 400) return const Color(0xFF1565C0);
    if (c >= 400 && c < 500) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForCode(code);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Text('$code'),
    );
  }
}

class _ApiResultCard extends StatelessWidget {
  final _ApiResult result;

  const _ApiResultCard({required this.result});

  Color _statusColor(int code) {
    if (code >= 200 && code < 300) return const Color(0xFF2E7D32);
    if (code >= 300 && code < 400) return const Color(0xFF1565C0);
    if (code >= 400 && code < 500) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(result.statusCode);
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${result.statusCode}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.reasonPhrase,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  '${result.elapsedMs}ms',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF9E9E9E),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              result.url,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF9E9E9E),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
