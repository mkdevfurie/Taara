import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:taara/config/env.dart';
import 'package:taara/services/api_service.dart';

/// Connexion temps réel au backend TAARA (Socket.IO, namespace /chat).
///
/// - `messages` : nouveaux messages des chats ouverts (room `job:<id>`)
/// - `jobUpdates` : changement de statut d'un job (accepté, démarré, terminé…)
/// - `notifications` : toute nouvelle notification de l'utilisateur
/// - `typing` : l'autre personne est en train d'écrire
///
/// La connexion suit la session : ouverte à la connexion, fermée à la déconnexion.
class RealtimeService {
  static io.Socket? _socket;
  static final Set<String> _jobRooms = {};
  static bool _started = false;

  static final _messages = StreamController<Map<String, dynamic>>.broadcast();
  static final _jobUpdates = StreamController<Map<String, dynamic>>.broadcast();
  static final _notifications =
      StreamController<Map<String, dynamic>>.broadcast();
  static final _typing = StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get messages => _messages.stream;
  static Stream<Map<String, dynamic>> get jobUpdates => _jobUpdates.stream;
  static Stream<Map<String, dynamic>> get notifications =>
      _notifications.stream;
  static Stream<Map<String, dynamic>> get typing => _typing.stream;

  /// État de la connexion, utile pour afficher « en direct » dans l'UI.
  static final ValueNotifier<bool> connected = ValueNotifier(false);

  /// À appeler une fois au démarrage (après le chargement de la session).
  static void start() {
    if (_started) return;
    _started = true;
    ApiService.currentUser.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  static void _onSessionChanged() {
    if (ApiService.isLoggedIn) {
      _connect();
    } else {
      _disconnect();
    }
  }

  static String get _origin {
    final u = Uri.parse(Env.apiBaseUrl);
    return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}';
  }

  static void _connect() {
    if (_socket != null) return;
    final socket = io.io(
      '$_origin/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': ApiService.accessToken ?? ''})
          .enableReconnection()
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          .disableAutoConnect()
          .build(),
    );

    socket.onConnect((_) {
      connected.value = true;
      // Après une reconnexion, on rejoint de nouveau les chats ouverts
      for (final jobId in _jobRooms) {
        socket.emit('job:join', {'jobId': jobId});
      }
    });
    socket.onDisconnect((_) => connected.value = false);
    socket.onConnectError((_) async {
      connected.value = false;
      // Jeton d'accès expiré (15 min) : on le rafraîchit pour la prochaine tentative
      if (await ApiService.refreshSession()) {
        socket.auth = {'token': ApiService.accessToken ?? ''};
      }
    });

    socket.on('message:new', (d) => _emit(_messages, d));
    socket.on('job:updated', (d) => _emit(_jobUpdates, d));
    socket.on('notification:new', (d) => _emit(_notifications, d));
    socket.on('typing', (d) => _emit(_typing, d));

    _socket = socket..connect();
  }

  static void _emit(StreamController<Map<String, dynamic>> c, dynamic data) {
    if (data is Map) c.add(Map<String, dynamic>.from(data));
  }

  static void _disconnect() {
    _jobRooms.clear();
    _socket?.dispose();
    _socket = null;
    connected.value = false;
  }

  /// Écoute en direct les messages d'un job (écran de chat ouvert).
  static void joinJob(String jobId) {
    _jobRooms.add(jobId);
    _socket?.emit('job:join', {'jobId': jobId});
  }

  static void leaveJob(String jobId) {
    _jobRooms.remove(jobId);
    _socket?.emit('job:leave', {'jobId': jobId});
  }

  static void sendTyping(String jobId, bool isTyping) {
    _socket?.emit('typing', {'jobId': jobId, 'typing': isTyping});
  }
}
