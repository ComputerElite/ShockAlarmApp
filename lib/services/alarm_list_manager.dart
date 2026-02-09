import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/screens/shockers/live/live_controls.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/services/limits.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shock_alarm_app/services/openshockws.dart';
import 'package:shock_alarm_app/services/settings.dart';

import '../stores/alarm_store.dart';
import 'dart:convert';

import 'alarm_manager.dart';

class AlarmListManager {
  final List<Alarm> _alarms = [];
  final List<Shocker> shockers = [];
  final List<Token> _tokens = [];
  final List<Token> _alarmServerTokens = [];
  final List<Hub> hubs = [];
  final List<String> onlineHubs = [];
  final List<AlarmTone> alarmTones = [];
  final List<LivePattern> livePatterns = [];
  List<OpenShockShareLink>? shareLinks;

  List<OpenShockShareInvite>? invites;
  final Map<String, bool> enabledHubs = {};
  Settings settings = Settings();
  Map<int, OpenShockWS?> ws = {};
  static AlarmListManager? instance;
  AlarmTone? selectedTone;
  OpenShockUserShares? userShares;

  Map<String?, List<ShockerLog>> shockerLog = {};

  ControlsContainer controls = ControlsContainer();

  AlarmListManager() {
    setAlarmImplementation();
  }

  void setAlarmImplementation() {
    if (isAndroid() && !settings.useAlarmServer) {
      alarmManager = AndroidShockAlarmManager();
    } else {
      alarmManager = AlarmServerShockAlarmManager();
    }
  }

  Function? reloadAllMethod;

  Function? pageSelectorReloadMethod;

  BuildContext? context;

  List<String> selectedShockers = [];

  bool delayVibrationEnabled = false;

  static AlarmListManager getInstance() {
    return instance!;
  }

  Future loadAllFromStorage() async {
    instance = this;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String alarms = prefs.getString("alarms") ?? "[]";
    String tokens = prefs.getString("tokens") ?? "[]";
    String alarmServerTokens = prefs.getString("alarmServerTokens") ?? "[]";
    String shockers = prefs.getString("shockers") ?? "[]";
    String hubs = prefs.getString("hubs") ?? "[]";
    String settings = prefs.getString("settings") ?? "{}";
    String alarmTones = prefs.getString("alarmTones") ?? "[]";
    String shareLinks = prefs.getString("shareLinks") ?? "[]";
    String livePatternsString = prefs.getString("livePatterns") ?? "[]";
    String invitesString = prefs.getString("invites") ?? "[]";
    List<dynamic> alarmsList = jsonDecode(alarms);
    List<dynamic> tokensList = jsonDecode(tokens);
    List<dynamic> alarmServerTokensList = jsonDecode(alarmServerTokens);
    List<dynamic> shockersList = jsonDecode(shockers);
    List<dynamic> hubsList = jsonDecode(hubs);
    List<dynamic> alarmTonesList = jsonDecode(alarmTones);
    List<dynamic> shareLinksList = jsonDecode(shareLinks);
    List<dynamic> livePatternsList = jsonDecode(livePatternsString);
    List<dynamic> invitesList = jsonDecode(invitesString);
    this.settings = Settings.fromJson(jsonDecode(settings));
    if (!supportsWs()) this.settings.useHttpShocking = true;
    for (var alarm in alarmsList) {
      _alarms.add(Alarm.fromJson(alarm));
    }
    for (var token in tokensList) {
      _tokens.add(Token.fromJson(token));
    }
    for (var token in alarmServerTokensList) {
      _alarmServerTokens.add(Token.fromJson(token));
    }
    for (var hub in hubsList) {
      this.hubs.add(Hub.fromJson(hub));
    }
    for (var pattern in livePatternsList) {
      livePatterns.add(LivePattern.fromJson(pattern));
    }
    for (var shocker in shockersList) {
      Shocker s = Shocker.fromJson(shocker);
      for (var hub in this.hubs) {
        if (s.hubId == hub.id) {
          s.hubReference = hub;
          hub.apiTokenId = s.apiTokenId;
        }
      }
      this.shockers.add(s);
    }
    for (var alarmTone in alarmTonesList) {
      this.alarmTones.add(AlarmTone.fromJson(alarmTone));
    }
    this.shareLinks = [];
    for (var shareLink in shareLinksList) {
      OpenShockShareLink link = OpenShockShareLink.fromJson(shareLink);
      link.tokenReference = getToken(link.tokenId ?? 0);
      this.shareLinks!.add(link);
    }
    this.invites = [];
    for (var invite in invitesList) {
      OpenShockShareInvite inviteEntry = OpenShockShareInvite.fromJson(invite);
      inviteEntry.tokenReference = getToken(inviteEntry.tokenId);
      this.invites!.add(inviteEntry);
    }
    updateHubList();
    rebuildAlarmShockers();
    if (reloadAllMethod != null) {
      reloadAllMethod!();
    }
    setAlarmImplementation();
  }

  Token? getTokenByToken(String? token) {
    for (Token t in _tokens) {
      if (t.token == token) return t;
    }
    return null;
  }

  void saveShareLinks() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("shareLinks", jsonEncode(shareLinks));
  }

  void updateHubList() {
    for (var hub in hubs) {
      enabledHubs.putIfAbsent(hub.id, () => true);
    }
    for (var hub in enabledHubs.keys.toList()) {
      if (hubs.indexWhere((element) => element.id == hub) == -1) {
        enabledHubs.remove(hub);
      }
    }
  }

  void saveSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("settings", jsonEncode(settings));
    reloadAllMethod?.call();
  }

  AlarmManager? alarmManager;

  void rescheduleAlarms() async {
    await alarmManager?.scheduleAlarms(_alarms);
  }

  int getNewAlarmId() {
    int id = 0;
    bool foundNew = false;
    while (!foundNew) {
      foundNew = true;
      for (var alarm in getAlarms()) {
        if (alarm.id == id) {
          id++;
          foundNew = false;
          break;
        }
      }
    }
    return id;
  }

  int getNewToneId() {
    int id = 0;
    bool foundNew = false;
    while (!foundNew) {
      foundNew = true;
      for (var tone in alarmTones) {
        if (tone.id == id) {
          id++;
          foundNew = false;
          break;
        }
      }
    }
    return id;
  }

  saveAlarm(Alarm alarm, {bool updateServer = true}) async {
    final index = _alarms.indexWhere((findAlarm) => alarm.id == findAlarm.id);
    if (index == -1) {
      print('Adding new alarm');
      _alarms.add(alarm);
    } else {
      _alarms[index] = alarm;
    }
    if (updateServer) alarmManager?.saveAlarm(alarm);
    rebuildAlarmShockers();
    rescheduleAlarms();
    saveAlarms();
  }

  Future<bool> updateShockerStore() async {
    List<Shocker> shockers = [];
    List<Hub> hubs = [];
    List<Token> tokensCopy = this._tokens.toList(); // create a copy
    bool tokenExpired = false;
    bool serverUnreachable = false;
    for (var token in tokensCopy) {
      OpenShockClient client = OpenShockClient();
      TokenGetResponseType t = await client.setInfoOfToken(token);
      if (t == TokenGetResponseType.tokenExpired) {
        tokenExpired = true;
        token.invalidSession = true;
        // if another session of the same account exists remove that one
        for (var otherToken in tokensCopy) {
          if (otherToken.userId == token.userId) {
            _tokens.remove(token);
            tokenExpired = false;
          }
        }
        continue;
      }
      if (t == TokenGetResponseType.serverUnreachable) {
        // only show the message once per token
        if (!token.serverUnreachable) serverUnreachable = true;
        token.serverUnreachable = true;
        continue;
      }

      DeviceContainer devices = await client.GetShockersForToken(token);
      // add shockers without duplicates
      for (var hub in devices.hubs) {
        if (hubs.indexWhere((element) => element.id == hub.id) == -1) {
          hubs.add(hub);
        }
      }
      for (var shocker in devices.shockers) {
        shocker.hubReference = hubs.firstWhere(
            (element) => element.id == shocker.hubId,
            orElse: () => Hub()); // if this breaks stuff it ain't my fault uwu
        if (shockers.indexWhere((element) => element.id == shocker.id) == -1) {
          shockers.add(shocker);
        } else {
          Shocker existingShocker =
              shockers.firstWhere((element) => element.id == shocker.id);
          if (existingShocker.paused && !shocker.paused ||
              existingShocker.intensityLimit < shocker.intensityLimit ||
              !existingShocker.isOwn && shocker.isOwn ||
              existingShocker.durationLimit < shocker.durationLimit &&
                  existingShocker.intensityLimit < shocker.intensityLimit) {
            // Prefer new shocker if it's not paused, has a higher intensity limit, has a higher duration (but not lower intensity).
            shockers.removeWhere((element) => element.id == shocker.id);
            shockers.add(shocker);
          }
        }
      }
    }
    List<String> newSelected = [];
    for (var shocker in shockers) {
      if (selectedShockers.contains(shocker.id)) {
        newSelected.add(shocker.id);
      }
    }
    selectedShockers = newSelected;
    this.shockers.clear();
    this.shockers.addAll(shockers);
    this.hubs.clear();
    this.hubs.addAll(hubs);
    saveShockers();
    saveTokens();
    updateHubList();
    rebuildAlarmShockers();
    updateShareLinks();
    updateInvites(incomingOnly: true);
    if (reloadAllMethod != null) reloadAllMethod!();
    if (tokenExpired) {
      showSessionExpired();
    }
    if (serverUnreachable) {
      showServerUnreachable();
    }
    if (!supportsWs()) updateHubStatusViaHttp();
    return !tokenExpired;
  }

  Map<String, LiveControlWS> liveControlGatewayConnections = {};

  Future disconnectFromLiveControlGateway(Hub hub) async {
    // close connection if still open and remove from map
    if (liveControlGatewayConnections.containsKey(hub.id)) {
      await liveControlGatewayConnections[hub.id]?.dispose();
      liveControlGatewayConnections.remove(hub.id);
    }
  }

  Future disconnectAllFromLiveControlGateway() async {
    // close connection if still open and remove from map
    for (var key in liveControlGatewayConnections.keys.toList()) {
      disconnectFromLiveControlGateway(Hub()..id = key);
    }
  }

  Future<ErrorContainer<bool>> connectToLiveControlGateway(Hub hub) async {
    if (liveControlGatewayConnections.containsKey(hub.id)) {
      return ErrorContainer(true, null);
    }
    OpenShockLCGResponse? lcg = await OpenShockClient().getLCGInfo(hub);
    if (lcg == null) {
      return ErrorContainer(
          false, "Couldn't fetch live control gateway information for hub");
    }
    if (lcg.gateway == null) {
      return ErrorContainer(
          false, "Couldn't find live control gateway for hub");
    }
    LiveControlWS ws = LiveControlWS(lcg?.gateway, hub, (hub) {
      disconnectFromLiveControlGateway(hub);
    }, getToken(hub.apiTokenId));
    liveControlGatewayConnections[hub.id] = ws;

    return ErrorContainer(true, null);
  }

  void showServerUnreachable() {
    showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog.adaptive(
              title: Text("At least one OpenShock server is unreachable"),
              content: Text(
                  "At least one OpenShock server is unreachable. Please check your internet connection and the server address in the settings page for following servers: ${_tokens.where((x) => x.serverUnreachable).map((x) => x.server).join(", ")}"),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Ok"))
              ],
            ));
  }

  void showSessionExpired() {
    showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog.adaptive(
              title: Text("Session expired"),
              content: Text(
                  "Your session has expired. To continue using the app log in again in the settings page."),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Ok"))
              ],
            ));
  }

  Future saveToken(Token token) async {
    final index = _tokens.indexWhere((findToken) => token.id == findToken.id);
    if (index == -1) {
      _tokens.add(token);
    } else {
      _tokens[index] = token;
    }
    await saveTokens();
    await updateShockerStore();
    //await _storage.writeList(_tokens.tokens);
  }

  Future saveAlarmServerToken(Token token) async {
    final index =
        _alarmServerTokens.indexWhere((findToken) => token.id == findToken.id);
    if (index == -1) {
      _alarmServerTokens.add(token);
    } else {
      _alarmServerTokens[index] = token;
    }
    await saveAlarmServerTokens();
    //await _storage.writeList(_tokens.tokens);
  }

  void deleteAlarm(Alarm alarm) {
    _alarms.removeWhere((findAlarm) => alarm.id == findAlarm.id);
    alarmManager?.deleteAlarm(alarm);
    saveAlarms();
  }

  void rebuildAlarmShockers() {
    for (var alarm in _alarms) {
      // remove shockers which don't exist
      alarm.shockers.removeWhere((element) =>
          shockers.indexWhere((shocker) => shocker.id == element.shockerId) ==
          -1);
      for (var shocker in shockers) {
        // check if shocker is already present in alarm
        if (alarm.shockers
                .indexWhere((element) => element.shockerId == shocker.id) ==
            -1) {
          alarm.shockers.add(AlarmShocker()..shockerId = shocker.id);
        }

        // Set reference to shocker
        for (var alarmShocker in alarm.shockers) {
          if (alarmShocker.shockerId == shocker.id) {
            alarmShocker.shockerReference = shocker;
          }
        }
      }
    }
  }

  List<Alarm> getAlarms() {
    return _alarms;
  }

  List<Token> getTokens() {
    return _tokens;
  }

  List<Token> getAlarmServerTokens() {
    return _alarmServerTokens;
  }

  void saveShockers() async {
    updateHubList();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("shockers", jsonEncode(shockers));
    prefs.setString("hubs", jsonEncode(hubs));
  }

  void saveAlarms() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("alarms", jsonEncode(_alarms));
  }

  Future saveTokens() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("tokens", jsonEncode(_tokens));
  }

  Future saveAlarmServerTokens() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("alarmServerTokens", jsonEncode(_alarmServerTokens));
  }

  Future saveAlarmTones() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("alarmTones", jsonEncode(alarmTones));
  }

  Future<String?> deleteToken(Token token) async {
    String? error;
    if (token.type == TokenType.session) {
      // Invalidate session
      error = await OpenShockClient().logout(token);
      if (error != null) return error;
    }
    _tokens.removeWhere((findToken) => token.id == findToken.id);
    await saveTokens();
    return error;
  }

  Future deleteAlarmServerToken(Token token) async {
    _alarmServerTokens.removeWhere((findToken) => token.id == findToken.id);
    await saveAlarmServerTokens();
  }

  Token? getToken(int id) {
    for (Token token in _tokens) {
      if (token.id == id) {
        return token;
      }
    }
    return null;
  }

  Future<String?> sendShock(ControlType type, Shocker shocker,
      int currentIntensity, int currentDuration,
      {String? customName, bool useWs = true}) async {
    Control control = Control();
    control.intensity = currentIntensity;
    control.duration = currentDuration;
    control.type = type;
    control.id = shocker.id;
    control.exclusive = true;
    Token? t = getToken(shocker.apiTokenId);
    if (t == null) {
      return "Token not found";
    }
    print(
        "Sending ${type} to ${shocker.name} with intensity $currentIntensity and duration $currentDuration");
    OpenShockClient client = OpenShockClient();
    return await client.sendControls(t, [control], this,
            customName: customName, useWs: !settings.useHttpShocking && useWs)
        ? null
        : "Failed to send shock, is your token still valid?";
  }

  Future<bool> login(String serverAddress, String email, String password,
      String? turnstileToken) async {
    Token? session = await OpenShockClient()
        .loginV2(serverAddress, email, password, turnstileToken);
    await session?.addBackendData();
    if (session != null) {
      await saveToken(session);
    }
    return session != null;
  }

  Future<ErrorContainer<Token>> alarmServerLogin(String serverAddress,
      String username, String password, bool register) async {
    ErrorContainer<Token> session = await AlarmServerClient()
        .loginOrRegister(serverAddress, username, password, register);
    if (session.value != null) {
      await saveAlarmServerToken(session.value!);
    }
    return session;
  }

  Future<String?> editShocker(Shocker shocker, OpenShockShocker edit) {
    return OpenShockClient().editShocker(shocker, edit, this);
  }

  Future<String?> renameHub(Hub hub, String text) {
    return OpenShockClient().renameHub(hub, text, this);
  }

  Future<List<ShockerLog>> getShockerLogs(Shocker shocker,
      {int limit = 100}) async {
    print("getting logs");
    List<ShockerLog> logs =
        await OpenShockClient().getShockerLogs(shocker, this, 0, limit);
    print("got logs");
    shockerLog.putIfAbsent(shocker.id, () => []);
    for (ShockerLog l in logs) {
      // only add logs which are not already in the list
      if (shockerLog.containsKey(shocker.id) &&
          shockerLog[shocker.id]!.indexWhere((element) =>
                  element.id == l.id ||
                  (element.createdOn == l.createdOn &&
                      element.type == l.type)) ==
              -1) {
        shockerLog[shocker.id]?.add(l);
      }
    }
    return shockerLog[shocker.id] ?? [];
  }

  Future<List<OpenShockShare>> getShockerShares(Shocker shocker) {
    return OpenShockClient().getShockerShares(shocker, this);
  }

  Future<List<OpenShockShareCode>> getShockerShareCodes(Shocker shocker) {
    return OpenShockClient().getShockerShareCodes(shocker, this);
  }

  Future<String?> deleteShareCode(OpenShockShareCode shareCode) {
    return OpenShockClient().deleteShareCode(shareCode, this);
  }

  Token? getAnyUserToken(bool shareLinksAllowed) {
    for (var token in getTokens()) {
      if (token.invalidSession) continue;
      if (token.type == TokenType.sharelink && !shareLinksAllowed) continue;
      if (token.name.isNotEmpty) {
        return token;
      }
    }
    return null;
  }

  Future<Token?> getSpecificUserToken() async {
    // gets a specific token. Asks the user to choose if multiple are present
    List<Token> validTokens = [];
    for (var token in getTokens()) {
      if (token.invalidSession) continue;
      if (token.type == TokenType.sharelink) continue;
      if (token.name.isNotEmpty) {
        validTokens.add(token);
      }
    }
    if (validTokens.isEmpty) return null;
    if (validTokens.length == 1) return validTokens.first;
    Token? selectedToken;
    // we gotta show a pop up
    ThemeData t = Theme.of(navigatorKey.currentContext!);
    await showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog.adaptive(
              title: Text("Select Account"),
              content: Column(
                spacing: 10,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Select which account you want to use to continue"),
                  ...validTokens.map((token) => GestureDetector(
                        onTap: () {
                          selectedToken = token;
                          Navigator.of(context).pop();
                        },
                        child: PaddedCard(
                            child: Column(
                          children: [
                            Text(
                              token.name,
                              style: t.textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              token.server
                                  .replaceAll("http://", "")
                                  .replaceAll("https://", ""),
                              style: t.textTheme.labelSmall,
                            ),
                          ],
                        )),
                      ))
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel"))
              ],
            ));
    return selectedToken;
  }

  bool hasValidAccount() {
    return getAnyUserToken(false) != null;
  }

  bool hasAccountWithShockers() {
    return getAnyUserToken(true) != null;
  }

  Future<String?> redeemShareCodeOrInvite(String code) async {
    String? inviteRes = await OpenShockClient().acceptInvite(code);
    if (inviteRes != null) {
      inviteRes = await OpenShockClient().redeemShareCode(code, this);
      if (inviteRes != null)
        return "Couldn't claim code as invite nor share code. Did you copy it correctly?";
    }
    return inviteRes;
  }

  Future<List<OpenShockDevice>> getDevices() async {
    List<OpenShockDevice> devices = [];
    for (var token in getTokens()) {
      devices.addAll(await OpenShockClient().getDevices(token));
    }
    return devices;
  }

  Future<String?> addShocker(
      String name, int rfId, String shockerType, OpenShockDevice? device) {
    return OpenShockClient().addShocker(name, rfId, shockerType, device, this);
  }

  Future<String?> deleteShocker(Shocker shocker) {
    return OpenShockClient().deleteShocker(shocker, this);
  }

  Future<String?> deleteShare(OpenShockShare share) {
    return OpenShockClient().deleteShare(share, this);
  }

  Hub? getHub(String? hubId) {
    for (var hub in hubs) {
      if (hub.id == hubId) {
        return hub;
      }
    }
    return null;
  }

  Future<String?> deleteHub(Hub hub) {
    return OpenShockClient().deleteHub(hub, this);
  }

  Future<PairCode> getPairCode(String hubId) {
    return getPairCodeViaHub(getHub(hubId)!);
  }

  Future<PairCode> getPairCodeViaHub(Hub hub) {
    return OpenShockClient().getPairCode(hub, this);
  }

  Future<CreatedHub> addHub(String name) {
    return OpenShockClient().addHub(name, this);
  }

  Function? reloadShockerLogs;

  Function()? reloadShareLinksMethod;

  Function()? onRefresh;
  Function(OTAInstallProgress)? onOtaInstallProgress;
  Function()? otaInstallSucceeded;

  static bool supportsWs() {
    return !kIsWeb || true;
  }

  Future updateHubStatusViaHttp() async {
    for (var hub in hubs) {
      OpenShockClient().getLCGInfo(hub).then((OpenShockLCGResponse? res) {
        hub.online = res?.online ?? false;

        if (hub.online && !onlineHubs.contains(hub.id)) {
          onlineHubs.add(hub.id);
        } else {
          onlineHubs.remove(hub.id);
        }
        reloadAllMethod!();
      });
    }
  }

  Future startWS(Token t, {bool stopExisting = true}) async {
    if (ws[t.id] != null) {
      if (!stopExisting) return;
      await ws[t.id]!.stopConnection();
    }

    ws[t.id] = OpenShockWS(t);
    await ws[t.id]!.startConnection();
    ws[t.id]?.addMessageHandler("DeviceStatus", (List<dynamic>? list) {
      if (list == null) return;
      deviceStatusHandler(list);
    });
    ws[t.id]?.addMessageHandler("Log", (List<dynamic>? list) {
      if (list == null) return;
      OpenShockUser user = OpenShockUser.fromJson(list[0]);
      for (Map<String, dynamic> shocker in list[1]) {
        WSShockerLog wslog = WSShockerLog.fromJson(shocker);
        ShockerLog log = ShockerLog.fromWs(wslog, user);
        log.shockerReference =
            shockers.firstWhere((element) => element.id == wslog.shocker?.id);
        shockerLog.putIfAbsent(log.shockerReference?.id, () => []).add(log);
      }
      if (reloadShockerLogs != null) {
        reloadShockerLogs!();
      }
    });
    ws[t.id]?.addMessageHandler("OtaInstallProgress", (List<dynamic>? list) {
      OTAInstallProgress progress = OTAInstallProgress();
      progress.hubId = list![0];
      progress.id = AlarmToneComponent.cast<int>(list[1]) ?? 0;
      progress.step = AlarmToneComponent.cast<int>(list[2]) ?? 0;
      progress.progress = AlarmToneComponent.cast<double>(list[3]) ?? 0.0;
      if (onOtaInstallProgress != null) {
        onOtaInstallProgress!(progress);
      }
    });
    ws[t.id]?.addMessageHandler("OtaInstallSucceeded", (List<dynamic>? list) {
      if (otaInstallSucceeded != null) {
        otaInstallSucceeded!();
      }
    });
    ws[t.id]?.addMessageHandler("DeviceUpdate", (List<dynamic>? list) {
      if (list == null) return;
      if (list.length < 1) return;
      String deviceId = list[0];
      if (queuedUpdate) return;
      queuedUpdate = true;
      Future.delayed(Duration(milliseconds: 500), () {
        queuedUpdate = false;
        updateShockerStore();
      });
    });
  }

  bool queuedUpdate = false;

  Function(OpenShockDevice device)? onDeviceStatusUpdated;

  List<String> liveActiveForShockers = [];

  void deviceStatusHandler(List<dynamic> args) {
    for (var arg in args[0]) {
      OpenShockDevice d = OpenShockDevice.fromJson(arg);
      for (Hub h in hubs) {
        if (h.id == d.device) {
          h.online = d.online;
          h.firmwareVersion = d.firmwareVersion;
        }
      }
      onDeviceStatusUpdated?.call(d);
      if (d.online && !onlineHubs.contains(d.device)) {
        onlineHubs.add(d.device);
      } else {
        onlineHubs.remove(d.device);
      }
    }
    reloadAllMethod!();
  }

  Future<String?> sendControls(List<Control> controls,
      {String? customName, bool useWs = true}) async {
    Map<int, List<Control>> controlsByToken = {};
    Map<int, List<Control>> stopControlsByToken = {};
    for (var control in controls) {
      // put stop controls into seperate list
      (control.type == ControlType.stop ? stopControlsByToken : controlsByToken)
          .putIfAbsent(control.apiTokenId, () => [])
          .add(control);
    }
    OpenShockClient client = OpenShockClient();
    bool stopControlFailed = false;
    // first do stop controls
    for (var token in getTokens()) {
      if (!stopControlsByToken.containsKey(token.id)) continue;
      for (Control stopControl in stopControlsByToken[token.id]!) {
        if (!await client.sendControls(token, [stopControl], this,
            customName: customName,
            useWs: !settings.useHttpShocking && useWs)) {
          stopControlFailed =
              true; // make sure we also try to send the other stops
        }
      }
    }
    if (stopControlFailed) return "Failed to send stop to at least 1 shocker";
    // then the other ones
    for (var token in getTokens()) {
      if (!controlsByToken.containsKey(token.id)) continue;
      if (!await client.sendControls(token, controlsByToken[token.id]!, this,
          customName: customName, useWs: !settings.useHttpShocking && useWs)) {
        return "Failed to send shock to at least 1 shocker, is your token still valid?";
      }
    }
    return null;
  }

  Future<String?> sendLiveControls(List<Control> controls) async {
    Map<String?, List<Control>> controlsByHub = {};
    for (var control in controls) {
      if (control.type == ControlType.sound && control.intensity <= 0)
        continue; // don't send sound as it seems to always play
      controlsByHub
          .putIfAbsent(control.shockerReference?.hubId, () => [])
          .add(control);
    }
    for (String? key in controlsByHub.keys) {
      if (!liveControlGatewayConnections.containsKey(key)) {
        return "Not connected to live control gateway for ${getHub(key)?.name ?? key ?? "unspecified hub  "}";
      }
      liveControlGatewayConnections[key]?.sendControls(controlsByHub[key]!);
    }
    return null;
  }

  Future<dynamic> startAllWS() async {
    for (var token in getTokens()) {
      await startWS(token, stopExisting: false);
    }
  }

  Future saveTone(AlarmTone tone, {bool updateServer = true}) async {
    // sort components by time
    tone.components.sort((a, b) => a.time.compareTo(b.time));
    final index = alarmTones.indexWhere((findTone) => tone.id == findTone.id);
    if (index == -1) {
      alarmTones.add(tone);
    } else {
      alarmTones[index] = tone;
    }
    if (updateServer) alarmManager?.saveTone(tone);
    saveAlarmTones();
  }

  void saveLivePatterns() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("livePatterns",
        jsonEncode(livePatterns.map((e) => e.toJson()).toList()));
  }

  void saveLivePattern(LivePattern pattern) {
    final index =
        livePatterns.indexWhere((findPattern) => pattern.id == findPattern.id);
    if (index == -1) {
      livePatterns.add(pattern);
    } else {
      livePatterns[index] = pattern;
    }
    saveLivePatterns();
  }

  void deleteTone(AlarmTone tone) {
    alarmTones.removeWhere((findTone) => tone.id == findTone.id);
    alarmManager?.deleteTone(tone);
    saveAlarmTones();
  }

  AlarmTone? getTone(int? id) {
    if (id == null) return null;
    for (var tone in alarmTones) {
      if (tone.id == id) {
        return tone;
      }
    }
    return null;
  }

  Future<TokenGetResponseType> loginToken(
      String serverAddress, String token) async {
    Token tokentoken = Token(DateTime.now().millisecondsSinceEpoch, token,
        server: serverAddress, type: TokenType.token);
    OpenShockClient client = OpenShockClient();
    TokenGetResponseType worked = await client.setInfoOfToken(tokentoken);
    if (worked == TokenGetResponseType.success) {
      saveToken(tokentoken);
    }
    return worked;
  }

  Future updateShareLinks() async {
    List<OpenShockShareLink> links = [];
    OpenShockClient client = OpenShockClient();
    for (Token token in getTokens()) {
      links.addAll(await client.getShareLinks(token));
    }
    shareLinks = links;
    saveShareLinks();
  }

  Future<String?> deleteShareLink(OpenShockShareLink shareLink) async {
    OpenShockClient client = OpenShockClient();
    return client.deleteShareLink(shareLink);
  }

  Future<OpenShockShareLink?> getShareLink(OpenShockShareLink shareLink) async {
    OpenShockClient client = OpenShockClient();
    return client.getShareLink(shareLink.tokenReference!, shareLink.id);
  }

  Future<String?> addShockerToShareLink(
      Shocker? selectedShocker, OpenShockShareLink openShockShareLink) {
    OpenShockClient client = OpenShockClient();
    return client.addShockerToShareLink(selectedShocker!, openShockShareLink);
  }

  Future<PairCode> createShareLink(
      String shareLinkName, DateTime dateTime, Token? token) async {
    OpenShockClient client = OpenShockClient();
    if (token == null) return PairCode("No token found", null);
    return client.createShareLink(token, shareLinkName, dateTime);
  }

  void savePageIndex(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt("page", index);
  }

  Future<int> getPageIndex() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt("page") ?? -1;
  }

  Shocker getSelectedShockerLimits() {
    Shocker limitedShocker = Shocker();
    limitedShocker.durationLimit = 300;
    limitedShocker.intensityLimit = 0;
    limitedShocker.shockAllowed = false;
    limitedShocker.soundAllowed = false;
    limitedShocker.vibrateAllowed = false;
    for (Shocker s in shockers.where((x) {
      return selectedShockers.contains(x.id);
    })) {
      if (s.durationLimit > limitedShocker.durationLimit) {
        limitedShocker.durationLimit = s.durationLimit;
      }
      if (s.intensityLimit > limitedShocker.intensityLimit) {
        limitedShocker.intensityLimit = s.intensityLimit;
      }
      if (s.shockAllowed) {
        limitedShocker.shockAllowed = true;
      }
      if (s.soundAllowed) {
        limitedShocker.soundAllowed = true;
      }
      if (s.vibrateAllowed) {
        limitedShocker.vibrateAllowed = true;
      }
    }
    // make sure to limit to recommended duration if choosen so
    if (!settings.increaseMaxDuration)
      limitedShocker.durationLimit = min(
          limitedShocker.durationLimit, OpenShockLimits.maxRecommendedDuration);
    if (settings.getEnforceHardLimitInsteadOfShock()) {
      limitedShocker.intensityLimit =
          min(limitedShocker.intensityLimit, settings.confirmShockMinIntensity);
      limitedShocker.durationLimit =
          min(limitedShocker.durationLimit, settings.confirmShockMinDuration);
    }
    if (settings.lerpIntensity) limitedShocker.intensityLimit = 100;

    return limitedShocker;
  }

  Iterable<Shocker> getSelectedShockers() {
    return shockers.where((x) {
      return selectedShockers.contains(x.id);
    });
  }

  Future<String?> setCaptivePortal(Hub hub, bool enable) async {
    Token? token = getToken(hub.apiTokenId);
    return await OpenShockClient().setCaptivePortal(hub, enable, token);
  }

  bool anyAlarmOn() {
    for (var alarm in _alarms) {
      if (alarm.active) {
        return true;
      }
    }
    return false;
  }

  Token? getAlarmServerUserToken() {
    for (var token in _alarmServerTokens) {
      if (token.invalidSession) continue;
      if (token.name.isNotEmpty) {
        return token;
      }
    }
    return null;
  }

  void dialogError(String title, String body) {
    showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog.adaptive(
              title: Text(title),
              content: Text(body),
              actions: [
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Ok"))
              ],
            ));
  }

  Future addAlarmServerAlarms() async {
    ErrorContainer<List<AlarmTone>> tones =
        await alarmManager?.getAlarmTones() ?? ErrorContainer([], null);
    if (tones.error != null) {
      dialogError("Failed to get alarm tones", tones.error!);
      return;
    }
    for (var tone in tones.value!) {
      if (tone.id == -1) {
        tone.id = getNewToneId();
      }
      await saveTone(tone);
    }

    ErrorContainer<List<Alarm>> alarms =
        await alarmManager?.getAlarms() ?? ErrorContainer([], null);
    if (alarms.error != null) {
      dialogError("Failed to get alarms", tones.error!);
      return;
    }
    for (var alarm in alarms.value!) {
      if (alarm.id == -1) {
        alarm.id = getNewAlarmId();
      }
      await saveAlarm(alarm);
    }
  }

  // {"arguments":["5ff90a57-711a-45f8-8952-6eb2f961a251","1.4.0"],"invocationId":"1","target":"OtaInstall","type":1}

  Future startHubUpdate(Hub hub, String version) async {
    await startAllWS();
    await ws[getToken(hub.apiTokenId)?.id]
        ?.connection
        ?.invoke('OtaInstall', args: [hub.id, version]);
  }

  bool areSelectedShockersConnected() {
    for (var shocker in getSelectedShockers()) {
      if (!liveControlGatewayConnections.keys.contains(shocker.hubId)) {
        return false;
      }
    }
    return true;
  }

  Future<ErrorContainer<bool>>
      connectToLiveControlGatewayOfSelectedShockers() async {
    for (var shocker in getSelectedShockers()) {
      if (!liveControlGatewayConnections.keys.contains(shocker.hubId)) {
        ErrorContainer<bool> error =
            await connectToLiveControlGateway(getHub(shocker.hubId)!);
        if (error.error != null) return error;
      }
    }
    return ErrorContainer(true, null);
  }

  int getNewLivePatternId() {
    int id = 0;
    bool foundNew = false;
    while (!foundNew) {
      foundNew = true;
      for (var pattern in livePatterns) {
        if (pattern.id == id) {
          id++;
          foundNew = false;
          break;
        }
      }
    }
    return id;
  }

  void removePattern(pattern) {
    livePatterns.remove(pattern);
    saveLivePatterns();
  }

  Future updateInvites({bool incomingOnly = false}) async {
    List<OpenShockShareInvite> invites = [];
    OpenShockClient client = OpenShockClient();
    for (Token token in getTokens()) {
      invites
          .addAll(await client.getInvites(token, incomingOnly: incomingOnly));
    }
    if (incomingOnly)
      invites.addAll(this.invites?.where((x) => x.outgoing) ?? []);
    this.invites = invites;
    if (incomingOnly && reloadAllMethod != null) {
      reloadAllMethod!();
    }
    saveInvites();
  }

  void saveInvites() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("invites", jsonEncode(invites));
  }

  Future<String?> deleteInvite(OpenShockShareInvite invite) async {
    OpenShockClient client = OpenShockClient();
    String? error = await client.deleteInvite(invite);
    if (error == null) {
      invites?.remove(invite);
      saveInvites();
    }
    return error;
  }

  Future<bool> updateUserShares() async {
    OpenShockUserShares shares = OpenShockUserShares();
    OpenShockClient client = OpenShockClient();
    // Duct tape fix for loading shares before shockers are present
    try {
      for (Token token in getTokens()) {
        ErrorContainer<OpenShockUserShares> s = await client.getShares(token);
        if (s.value == null) continue;
        shares.incoming.addAll(s.value!.incoming);
        shares.outgoing.addAll(s.value!.outgoing);
      }
      userShares = shares;
      return true;
    } catch (e) {
      return false;
    }
  }
}
