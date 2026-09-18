import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

typedef ServerMessageCallback = void Function(Map<String, dynamic> message);

class NetworkService {
  final String serverAddr;
  final int serverPort;
  final String username;

  Socket? _socket;
  StreamSubscription? _subscription;
  String id = '0';
  bool isConnected = false;
  String _recvBuffer = '';
  bool _handshakeComplete = false;

  final List<ServerMessageCallback> _listeners = [];
  final List<String> _outgoingQueue = [];
  Timer? _sendTimer;

  final bool isOffline;

  NetworkService({
    required this.serverAddr,
    required this.serverPort,
    required this.username,
  }) : isOffline = false;

  NetworkService.offline({
    required this.username,
  })  : serverAddr = 'offline',
        serverPort = 0,
        isOffline = true,
        isConnected = true,
        id = '1';

  void addListener(ServerMessageCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(ServerMessageCallback listener) {
    _listeners.remove(listener);
  }

  void dispatchServerMessage(Map<String, dynamic> message) {
    for (final listener in List.of(_listeners)) {
      listener(message);
    }
  }

  Future<void> connect() async {
    if (isOffline) {
      isConnected = true;
      _handshakeComplete = true;
      return;
    }
    try {
      _socket = await Socket.connect(
        serverAddr,
        serverPort,
        timeout: const Duration(seconds: 5),
      );
      isConnected = true;

      // Start periodic sender queue
      _sendTimer = Timer.periodic(
        const Duration(milliseconds: 33),
        (_) => _flushOutgoingQueue(),
      );

      _subscription = _socket!.listen(
        _onData,
        onError: (err) {
          debugPrint('[Network] Socket error: $err');
          close();
        },
        onDone: () {
          debugPrint('[Network] Socket closed by server.');
          close();
        },
      );
    } catch (e) {
      isConnected = false;
      rethrow;
    }
  }

  void _onData(Uint8List data) {
    final raw = utf8.decode(data, allowMalformed: true);

    if (!_handshakeComplete) {
      _recvBuffer += raw;
      // First message is the player ID
      if (_recvBuffer.contains('\n')) {
        final parts = _recvBuffer.split('\n');
        id = parts[0].trim();
        _recvBuffer = parts.sublist(1).join('\n');
      } else {
        id = _recvBuffer.trim();
        _recvBuffer = '';
      }

      if (id.isNotEmpty) {
        _handshakeComplete = true;
        debugPrint('[Network] Handshake success. Assigned ID: $id');
        // Reply with username
        _socket?.add(utf8.encode('$username\n'));
      }
    } else {
      _recvBuffer += raw;
    }

    _parseBuffer();
  }

  void _parseBuffer() {
    while (_recvBuffer.isNotEmpty) {
      final startIndex = _recvBuffer.indexOf('{');
      if (startIndex == -1) {
        // No JSON object start found
        _recvBuffer = '';
        break;
      }

      if (startIndex > 0) {
        _recvBuffer = _recvBuffer.substring(startIndex);
      }

      // Count braces
      int depth = 0;
      int endIndex = -1;
      bool inQuotes = false;
      bool escape = false;

      for (int i = 0; i < _recvBuffer.length; i++) {
        final char = _recvBuffer[i];
        if (escape) {
          escape = false;
          continue;
        }
        if (char == '\\') {
          escape = true;
          continue;
        }
        if (char == '"') {
          inQuotes = !inQuotes;
          continue;
        }

        if (!inQuotes) {
          if (char == '{') {
            depth++;
          } else if (char == '}') {
            depth--;
            if (depth == 0) {
              endIndex = i;
              break;
            }
          }
        }
      }

      if (endIndex != -1) {
        final jsonStr = _recvBuffer.substring(0, endIndex + 1);
        _recvBuffer = _recvBuffer.substring(endIndex + 1);
        try {
          final decoded = jsonDecode(jsonStr);
          if (decoded is Map<String, dynamic>) {
            _dispatchMessage(decoded);
          }
        } catch (e) {
          debugPrint('[Network] JSON parse error: $e');
        }
      } else {
        // Incomplete JSON object, wait for next socket chunk
        break;
      }
    }
  }

  void _dispatchMessage(Map<String, dynamic> msg) {
    for (final listener in List.of(_listeners)) {
      try {
        listener(msg);
      } catch (e) {
        debugPrint('[Network] Listener error: $e');
      }
    }
  }

  void sendPlayer(Vector3 pos, double rotationY, int health) {
    if (!isConnected || !_handshakeComplete) return;
    final payload = {
      "object": "player",
      "id": id,
      "position": [pos.x, pos.y, pos.z],
      "rotation": rotationY,
      "health": health,
      "joined": false,
      "left": false,
    };
    _queueSend(payload);
  }

  void sendBullet(
    Vector3 pos,
    int damage,
    double direction,
    double xDirection,
  ) {
    if (!isConnected) return;
    final payload = {
      "object": "bullet",
      "position": [pos.x, pos.y, pos.z],
      "damage": damage,
      "direction": direction,
      "x_direction": xDirection,
    };
    _queueSend(payload);
  }

  void sendHealth(String targetId, int health) {
    if (!isConnected) return;
    final payload = {
      "object": "health_update",
      "id": targetId,
      "health": health,
    };
    _queueSend(payload, priority: true);
  }

  void sendRespawn(Vector3 pos, int health) {
    if (!isConnected) return;
    final payload = {
      "object": "respawn",
      "id": id,
      "position": [pos.x, pos.y, pos.z],
      "health": health,
    };
    _queueSend(payload);
  }

  void _queueSend(Map<String, dynamic> data, {bool priority = false}) {
    try {
      final jsonStr = '${jsonEncode(data)}\n';
      if (priority) {
        _outgoingQueue.insert(0, jsonStr);
      } else {
        _outgoingQueue.add(jsonStr);
      }
    } catch (e) {
      debugPrint('[Network] Error encoding packet: $e');
    }
  }

  void _flushOutgoingQueue() {
    if (!isConnected || _socket == null || _outgoingQueue.isEmpty) return;
    try {
      // The current server reads one JSON object per socket read. Sending one
      // queued packet at a time prevents a health update being hidden behind
      // a coalesced movement or bullet packet.
      final packet = _outgoingQueue.removeAt(0);
      _socket!.add(utf8.encode(packet));
    } catch (e) {
      debugPrint('[Network] Socket write error: $e');
      close();
    }
  }

  void close() {
    isConnected = false;
    _sendTimer?.cancel();
    _subscription?.cancel();
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
  }
}
