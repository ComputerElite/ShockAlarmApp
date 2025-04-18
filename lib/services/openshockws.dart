import 'dart:convert';
import 'package:shock_alarm_app/screens/shockers/live/live_controls.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../main.dart';
import '../stores/alarm_store.dart';
import 'openshock.dart';

class _HttpClient extends http.BaseClient {
  final _httpClient = http.Client();
  final Map<String, String> headers;

  _HttpClient({required this.headers});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headers);
    return _httpClient.send(request);
  }
}

class OpenShockWS {
  Token t;

  HubConnection? connection = null;

  // Constructor
  OpenShockWS(this.t);

  // Start the connection
  Future startConnection() async {
    try {
      final httpClient = _HttpClient(headers: {
        if(t.type != TokenType.sharelink) 'OpenShockSession': t.token,
        'User-Agent': GetUserAgent(),
      });
      String url = '${t.server}/1/hubs/user';
      if(t.type == TokenType.sharelink){
        url = '${t.server}/1/hubs/share/link/${t.token}?name=${t.userId}';
      }
      connection = HubConnectionBuilder()
          .withUrl(
              url,
              HttpConnectionOptions(
                  logging: (level, message) => print(message),
                  client: httpClient,
                  skipNegotiation: true,
                  logMessageContent: true,
                  transport: HttpTransportType.webSockets))
          .withAutomaticReconnect(
              [0, 1000, 2000, 5000, 10000, 10000, 15000, 30000, 60000]).build();

      await connection!.start();
      print('Connection started');
    } catch (e) {
      print(e);
    }
  }

  // Stop the connection
  Future stopConnection() async {
    if (connection != null) {
      await connection!.stop();
      print('Connection stopped');
    } else {
      print('Connection is not established.');
    }
  }

  // Add a message handler for a specific event
  void addMessageHandler(
      String methodName, void Function(List<dynamic>? arguments) handler) {
    if (connection != null) {
      connection!.on(methodName, handler);
      print('Handler added for $methodName');
    } else {
      print('Connection not established yet.');
    }
  }

  // Remove a message handler for a specific event
  void removeMessageHandler(String methodName) {
    if (connection != null) {
      connection!.off(methodName);
      print('Handler removed for $methodName');
    } else {
      print('Connection not established yet.');
    }
  }

  Future<bool> establishConnection(int depth) async {
    if (depth > 3) {
      return false;
    }
    if (connection == null ||
        connection!.state != HubConnectionState.connected) {
      await startConnection();
      return establishConnection(depth + 1);
    }
    return true;
  }

  Future<bool> sendControls(List<Control> controls, String? customName,
      {int depth = 0}) async {
    if (!await establishConnection(0)) return false;
    try {
      // Wrap the Map in a List
      if(t.type == TokenType.sharelink) {
        // Share links don't support ControlV2
        await connection!.invoke('Control',
            args: [controls.map((e) => e.toJsonWS()).toList()]);
        return true;
      }
      await connection!.invoke('ControlV2',
          args: [controls.map((e) => e.toJsonWS()).toList(), customName]);
    } catch (e) {
      return false;
    }

    return true;
  }

  Future<String?> setCaptivePortal(Hub hub, bool enable) async {
    if (!await establishConnection(0)) return "Connection failed";
    try {
      // Wrap the Map in a List
      await connection!.invoke('CaptivePortal', args: [hub.id, enable]);
    } catch (e) {
      return "Failed to set captive portal";
    }
    return null;
  }
}

class LiveControlWS {
  WebSocketChannel? channel;
  List<int> latency = [];
  Function(Hub) onError;
  static Function()? onLatencyGlobal;
  Hub hub;
  Token? token;
  int tps = 10;
  static Map<String, LiveControlSettings> liveControlSettings = {};
  static Map<String, LivePattern> liveControlPatterns = {};

  LiveControlWS(String? host, this.hub, this.onError, this.token) {
    if (host == null || token == null) return;

    print("connecting to LCG");
    channel = IOWebSocketChannel.connect(
        Uri.parse(
            '${this.token!.server.startsWith("https") ? "wss" : "ws"}://$host/1/ws/live/${hub.id}'),
        headers: {
          "User-Agent": GetUserAgent(),
          "OpenShockSession": token?.token
        });

    channel?.stream.listen((data) {
      print(data);
      // Handle ping event
      // check if data is string and if so parse the json
      if (data is String) {
        Map<String, dynamic> json = jsonDecode(data);
        if (json["ResponseType"] == "Ping") {
          // just echo back
          channel?.sink
              .add(jsonEncode({"RequestType": "Pong", "Data": json["Data"]}));
        }
        if (json["ResponseType"] == "TPS") {
          tps = json["Data"]["Client"];
        }
        if (json["ResponseType"] == "LatencyAnnounce") {
          latency.insert(0, json["Data"]["OwnLatency"]);
          // only keep history of 50 latencies
          if (latency.length > 50) {
            latency.removeLast();
          }
          onLatency?.call();
          onLatencyGlobal?.call();
        }
      }
    }, onError: (error) {
      print("Error during websocket connection, disconnecting: $error");
      onError(hub);
    });
  }

  void Function()? onLatency;

  int getLatency() {
    if (latency.isEmpty) return 0;
    return latency[0];
  }

  Future dispose() async {
    await channel?.sink.close();
  }

  void sendControl(Shocker s, ControlType type, int intensity) {
    if (channel == null) return;
    channel?.sink.add(jsonEncode({
      "RequestType": "Frame",
      "Data": {
        "Shocker": s.id,
        "Type": getControl(type),
        "Intensity": intensity
      }
    }));
  }

  void sendControls(List<Control> list) {
    if (channel == null) return;
    channel?.sink.add(jsonEncode({
      "RequestType": "BulkFrame",
      "Data": list
          .map((e) => {
                "Shocker": e.shockerReference!.id,
                "Type": getControl(e.type),
                "Intensity": e.intensity
              })
          .toList()
    }));
  }

  static String getControl(ControlType type) {
    switch (type) {
      case ControlType.shock:
        return "shock";
      case ControlType.vibrate:
        return "vibrate";
      case ControlType.sound:
        return "sound";
      case ControlType.stop:
        return "stop";
      case ControlType.live:
        return "live";
    }
    return "stop";
  }
}
