import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:rust_net/rust_net.dart';

const String _exampleBaseUrl = String.fromEnvironment(
  'RUST_NET_EXAMPLE_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

void main() {
  runApp(const RustNetExampleApp());
}

class RustNetExampleApp extends StatelessWidget {
  const RustNetExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      debugShowCheckedModeBanner: false,
      home: RustNetExamplePage(),
    );
  }
}

class RustNetExamplePage extends StatefulWidget {
  const RustNetExamplePage({super.key});

  @override
  State<RustNetExamplePage> createState() => _RustNetExamplePageState();
}

class _RustNetExamplePageState extends State<RustNetExamplePage> {
  RustNetClient? _client;
  String? _nativeLibraryPath;
  String? _error;
  String _result = 'Ready';
  bool _isLoading = false;
  bool _hasSentInitialRequest = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeClient());
  }

  @override
  void dispose() {
    final client = _client;
    if (client != null) {
      unawaited(client.close());
    }
    super.dispose();
  }

  Future<void> _initializeClient() async {
    try {
      final nativeLibraryPath = RustNetClient.resolveNativeLibraryPath();
      final client = RustNetClient(
        config: const RustNetClientConfig(
          timeout: Duration(seconds: 10),
          userAgent: 'rust_net_example/0.0.1',
        ),
        nativeLibraryPath: nativeLibraryPath,
      );

      if (!mounted) {
        await client.close();
        return;
      }

      setState(() {
        _client = client;
        _nativeLibraryPath = nativeLibraryPath;
        _error = null;
      });
      debugPrint(
        'rust_net example client initialized: library=$nativeLibraryPath, baseUrl=$_exampleBaseUrl',
      );

      if (!_hasSentInitialRequest) {
        _hasSentInitialRequest = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_sendRequest());
          }
        });
      }
    } catch (error) {
      debugPrint('rust_net example client init failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
      });
    }
  }

  Future<void> _sendRequest() async {
    final client = _client;
    if (client == null) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = 'Sending GET $_exampleBaseUrl/get ...';
    });

    try {
      final response = await client.execute(
        RustNetRequest.get(
          uri: Uri.parse(
            '$_exampleBaseUrl/get?source=rust_net_example',
          ),
          headers: const <String, String>{
            'accept': 'application/json',
          },
        ),
      );

      if (!mounted) {
        return;
      }

      final preview = response.bodyText;
      debugPrint(
        'rust_net example request succeeded: '
        'status=${response.statusCode}, body=${preview.length > 200 ? '${preview.substring(0, 200)}...' : preview}',
      );
      setState(() {
        _result = 'Status: ${response.statusCode}\n\n'
            '${preview.length > 500 ? '${preview.substring(0, 500)}...' : preview}';
      });
    } on RustNetException catch (error) {
      debugPrint(
        'rust_net example request failed: ${error.code}: ${error.message}',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '${error.code}: ${error.message}';
      });
    } catch (error) {
      debugPrint('rust_net example request crashed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = CupertinoTheme.of(context).textTheme;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('rust_net Example'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Rust reqwest core',
                style: textTheme.navLargeTitleTextStyle,
              ),
              const SizedBox(height: 12),
              Text(
                _nativeLibraryPath == null
                    ? 'Native library path not resolved yet.'
                    : 'Native library: $_nativeLibraryPath',
                style: textTheme.textStyle,
              ),
              const SizedBox(height: 8),
              Text(
                'Fixture base URL: $_exampleBaseUrl',
                style: textTheme.textStyle,
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: _isLoading || _client == null ? null : _sendRequest,
                child: Text(_isLoading ? 'Requesting...' : 'Send Request'),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Text(
                  _error!,
                  style: textTheme.textStyle.copyWith(
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                ),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CupertinoColors.secondarySystemBackground
                        .resolveFrom(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _result,
                      style: textTheme.textStyle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
