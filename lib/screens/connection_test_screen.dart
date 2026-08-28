import 'package:flutter/material.dart';
import '../models/mikrotik_connection.dart';
import '../services/mikrotik_service.dart';
import '../utils/app_theme.dart';

/// ???? ??? ????? ?? MikroTik RouterOS
class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController(text: '192.168.88.1');
  final _portController = TextEditingController(text: '8728');
  final _usernameController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();

  bool _useSsl = false;
  bool _isConnecting = false;
  String? _connectionResult;
  bool? _isConnected;
  MikroTikService? _service;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _service?.disconnect();
    super.dispose();
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionResult = null;
      _isConnected = null;
    });

    try {
      // ???? ????? ???? ??? ???? ????
      _service?.disconnect();

      // ????? ????? ????
      _service = MikroTikService();

      // ????? ?????
      final connection = MikroTikConnection(
        host: _hostController.text.trim(),
        port: MikroTikConnection.apiPort,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        useSsl: _useSsl,
      );

      final success = await _service!.connect(connection);

      setState(() {
        _isConnecting = false;
        _isConnected = success;
        if (success) {
          _connectionResult = '????? ?? ?????? ?????? ??! ?';
        } else {
          _connectionResult =
              '????? ?????? ???. ????? ??????? ?? ????? ????. ?';
        }
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _connectionResult = '???: $e';
      });
    }
  }

  Future<void> _testGetClients() async {
    if (_service == null || !_service!.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('????? ????? ?? ?????? ????')),
      );
      return;
    }

    try {
      setState(() {
        _isConnecting = true;
      });

      final result = await _service!.getAllClients();

      setState(() {
        _isConnecting = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('????? ???'),
            content: Text(
              '????? ?????????: ${result['total_count']}\n'
              'Hotspot: ${result['by_type']['hotspot']}\n'
              'Wireless: ${result['by_type']['wireless']}\n'
              'DHCP: ${result['by_type']['dhcp']}\n'
              'PPP: ${result['by_type']['ppp']}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('????'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('???: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = AppTheme.primaryFor(theme.brightness);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.appBarFor(theme.brightness),
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: AppBar(
            title: Text(
              '??? ????? MikroTik',
              style: TextStyle(
                color: AppTheme.onAppBar(theme.brightness),
              ),
            ),
            backgroundColor: Colors.transparent,
            foregroundColor: AppTheme.onAppBar(theme.brightness),
            iconTheme: IconThemeData(color: AppTheme.onAppBar(theme.brightness)),
            elevation: 0,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ???? Host/IP
                  TextFormField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: '???? IP ?? Hostname',
                      hintText: '192.168.88.1',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.router),
                    ),
                    keyboardType: TextInputType.text,
                    textDirection: TextDirection.ltr,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '????? ???? IP ?? ???? ????';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ???? Port
                  TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: '????',
                      hintText: '8728',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    textDirection: TextDirection.ltr,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '????? ???? ?? ???? ????';
                      }
                      final port = int.tryParse(value.trim());
                      if (port == null || port < 1 || port > 65535) {
                        return '???? ???? ???? ??? 1 ?? 65535 ????';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ???? Username
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '??? ??????',
                      hintText: 'admin',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    textDirection: TextDirection.ltr,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '????? ??? ?????? ?? ???? ????';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ???? Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: '??? ????',
                      hintText: '??? ???? ?? ???? ????',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true,
                    textDirection: TextDirection.ltr,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '????? ??? ???? ?? ???? ????';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Checkbox SSL
                  CheckboxListTile(
                    title: const Text('??????? ?? SSL'),
                    subtitle: const Text(
                      '???? ????? ??? ?? SSL ??? ???? 8729 ??????? ????',
                    ),
                    value: _useSsl,
                    onChanged: (value) {
                      setState(() {
                        _useSsl = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 24),

                  // ???? ??? ?????
                  ElevatedButton.icon(
                    onPressed: _isConnecting ? null : _testConnection,
                    icon: _isConnecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      _isConnecting ? '?? ??? ?????...' : '??? ?????',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ???? ??? ?????? ????????? (??? ??? ???? ????)
                  if (_isConnected == true)
                    ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _testGetClients,
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.people),
                      label: Text(
                        _isConnecting
                            ? '?? ??? ??????...'
                            : '??? ?????? ?????????',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  if (_isConnected == true) const SizedBox(height: 16),

                  // ????? ?????
                  if (_connectionResult != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isConnected == true
                            ? AppTheme.successSurfaceFor(theme.brightness)
                            : Colors.red.shade50,
                        border: Border.all(
                          color: _isConnected == true
                              ? AppTheme.successBorderFor(theme.brightness)
                              : Colors.red,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isConnected == true
                                ? Icons.check_circle
                                : Icons.error,
                            color: _isConnected == true
                                ? AppTheme.successForegroundFor(
                                    theme.brightness,
                                  )
                                : Colors.red,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _connectionResult!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isConnected == true
                                    ? AppTheme.successForegroundFor(
                                        theme.brightness,
                                      )
                                    : Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
