import 'package:http/http.dart' as http;
import '../stores/alarm_store.dart';
import 'dart:convert';

class OpenShockClient {
  Future<List<Shocker>> GetShockersForToken(Token t) async {
    print("Doing get request ig");
  var response = await GetRequest(t, "/1/shockers/own");
  List<Shocker> shockers = [];

  if (response.statusCode == 200) {
    OpenShockDevicesData deviceData = OpenShockDevicesData.fromJson(jsonDecode(response.body));
    for (var element in deviceData.data!) {
      for (var shocker in element.shockers) {
        Shocker s = Shocker.fromOpenShockShocker(shocker);
        s.hub = element.name;
        s.apiTokenId = t.id;
        shockers.add(s);
      }
    }
  }

  response = await GetRequest(t, "/1/shockers/shared");
  if (response.statusCode == 200) {
    OpenShockContainerData deviceData = OpenShockContainerData.fromJson(jsonDecode(response.body));
    for (var element in deviceData.data!) {
      for(var device in element.devices) {
        for (var shocker in device.shockers) {
          Shocker s = Shocker.fromOpenShockShocker(shocker);
          s.hub = device.name;
          s.apiTokenId = t.id;
          shockers.add(s);
        }
      }
    }
  }

  return shockers;
}


  Future<http.Response> GetRequest(Token t, String path) {
    var url = Uri.parse(t.server + path);
    return http.get(url, headers: {
      "OpenShockToken": t.token
    });
  }

  Future<http.Response> PostRequest(Token t, String path, String body) {
    var url = Uri.parse(t.server + path);
    return http.post(url, headers: {
      "OpenShockToken": t.token,
      "Content-Type": "application/json"
    }, body: body);
  }

  Future sendControls(Token t, List<Control> list, {String customName = "ShockAlarm"}) async {

    String body = jsonEncode({
      "shocks": list.map((e) => e.toJson()).toList(),
      "customName": customName
    });
    var response = await PostRequest(t, "/2/shockers/control", body);
  }

  Future<String> getNameForToken(Token t) async {
    var request = GetRequest(t, "/1/users/self");
    var response = await request;
    String name = "Unknown";
    if(response.statusCode == 200) {
      var data = jsonDecode(response.body);
      name = data["data"]["name"];
    }
    request = GetRequest(t, "/1/tokens/self");
    response = await request;
    String tokenName = "";
    if(response.statusCode == 200) {
      var data = jsonDecode(response.body);
      tokenName = data["name"];
    }
    return "$name ($tokenName)";
  }
}

enum ControlType {
  stop,
  shock,
  vibrate,
  sound 
}

class Control {
  String id = "";
  bool exclusive = true;
  int duration = 0;
  int intensity = 0;
  ControlType type = ControlType.stop;

  toJson() {
    String type = "";
    switch(this.type) {
      case ControlType.stop:
        type = "Stop";
        break;
      case ControlType.shock:
        type = "Shock";
        break;
      case ControlType.vibrate:
        type = "Vibrate";
        break;
      case ControlType.sound:
        type = "Sound";
        break;
    } 
    return {
      "id": id,
      "exclusive": exclusive,
      "duration": duration,
      "intensity": intensity,
      "type": type
    };
  }
}

class Shocker {
  Shocker() {}
  
  String id = "";
  String name = "";
  String hub = "";
  int apiTokenId = 0;
  bool paused = false;
  bool shockAllowed = true;
  bool vibrateAllowed = true;
  bool soundAllowed = true;
  int durationLimit = 30000;
  int intensityLimit = 100;

  Shocker.fromOpenShockShocker(OpenShockShocker shocker) {
    id = shocker.id;
    name = shocker.name;
    paused = shocker.isPaused;
    if(shocker.permissions != null) {
      shockAllowed = shocker.permissions!.shock;
      vibrateAllowed = shocker.permissions!.vibrate;
      soundAllowed = shocker.permissions!.sound;
    }
    if(shocker.limits != null) {
      durationLimit = shocker.limits!.duration;
      intensityLimit = shocker.limits!.intensity;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "hub": hub,
      "apiTokenId": apiTokenId,
      "paused": paused,
      "shockAllowed": shockAllowed,
      "vibrateAllowed": vibrateAllowed,
      "soundAllowed": soundAllowed,
      "durationLimit": durationLimit,
      "intensityLimit": intensityLimit
    };
  }

  static Shocker fromJson(shocker) {
    Shocker s = Shocker();
    s.id = shocker["id"];
    s.name = shocker["name"];
    if(shocker["hub"] != null)
      s.hub = shocker["hub"];
    s.apiTokenId = shocker["apiTokenId"];
    s.paused = shocker["paused"];
    s.shockAllowed = shocker["shockAllowed"];
    s.vibrateAllowed = shocker["vibrateAllowed"];
    s.soundAllowed = shocker["soundAllowed"];
    s.durationLimit = shocker["durationLimit"];
    s.intensityLimit = shocker["intensityLimit"];
    return s;
  }
}


class OpenShockDevicesData
{
    List<OpenShockDevice>? data;

    OpenShockDevicesData.fromJson(Map<String, dynamic> json)
    {
        if (json['data'] != null)
        {
            data = [];
            json['data'].forEach((v) {
                data!.add(OpenShockDevice.fromJson(v));
            });
        }
    }
}

class OpenShockContainerData
{
    List<OpenShockDevicesContainer>? data;

    OpenShockContainerData.fromJson(Map<String, dynamic> json)
    {
        if (json['data'] != null)
        {
            data = [];
            json['data'].forEach((v) {
                data!.add(OpenShockDevicesContainer.fromJson(v));
            });
        }
    }
}

class OpenShockDevicesContainer
{
    List<OpenShockDevice> devices = [];

    OpenShockDevicesContainer.fromJson(Map<String, dynamic> json)
    {
        if (json['devices'] != null)
        {
            json['devices'].forEach((v) {
                devices.add(OpenShockDevice.fromJson(v));
            });
        }
    }
}

class OpenShockDevice
{
    String name = "";
    String id = "";
    List<OpenShockShocker> shockers = [];

    OpenShockDevice.fromJson(Map<String, dynamic> json)
    {
      name = json['name'];
      id = json['id'];
      if (json['shockers'] != null)
      {
        json['shockers'].forEach((v) {
            shockers.add(OpenShockShocker.fromJson(v));
        });
      }
    }
}

class OpenShockShocker
{
    String name = "";
    String id = "";
    bool isPaused = false;
    bool? isDisabled = false;
    OpenShockShockerLimits? limits;
    OpenShockShockerPermissions? permissions;

    OpenShockShocker.fromJson(Map<String, dynamic> json)
    {
        name = json['name'];
        id = json['id'];
        isPaused = json['isPaused'];
        isDisabled = json['isDisabled'];
        if (json['limits'] != null)
        {
            limits = OpenShockShockerLimits();
            limits!.intensity = json['limits']['intensity'];
            limits!.duration = json['limits']['duration'];
        }
        if (json['permissions'] != null)
        {
            permissions = OpenShockShockerPermissions();
            permissions!.shock = json['permissions']['shock'];
            permissions!.vibrate = json['permissions']['vibrate'];
            permissions!.sound = json['permissions']['sound'];
        }
    }
}

class OpenShockShockerLimits
{
    int intensity = 100;
    int duration = 30000;
}

class OpenShockShockerPermissions
{
    bool shock = true;
    bool vibrate = true;
    bool sound = true;
}