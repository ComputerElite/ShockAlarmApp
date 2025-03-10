import 'dart:io';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import '../main.dart';

enum TokenType {
  openshock,
  alarmserver
}

class Token {
  Token(this.id, this.token, {this.server = "https://api.openshock.app", this.name="", this.isSession = false, this.userId = "", this.invalidSession = false});

  int id;

  TokenType tokenType = TokenType.openshock;
  String token;
  String server;
  bool isSession = false;
  String name = "";
  String userId = ""; // may also be token id for alarmserver

  bool invalidSession = false;

  static Token fromJson(token) {
    Token t = Token(token["id"], token["token"], server: token["server"], name: token["name"] ?? "", isSession: token["isSession"] ?? false, userId: token["userId"] ?? "", invalidSession: token["invalidSession"] ?? false);
    if(token["tokenType"] != null)
      t.tokenType = token["tokenType"] == -1 ? TokenType.openshock : TokenType.values[token["tokenType"]];
    return t;
  }

  Map<String, dynamic> toJson() {
    return {"id": id, "token": token, "server": server, "name": name, "isSession": isSession, "userId": userId, "invalidSession": invalidSession, "tokenType": tokenType.index};
  }
}

class AlarmToneComponent {
  int intensity = 25;
  int duration = 1000;
  ControlType? type = ControlType.vibrate;
  int time = 0;
  
  AlarmToneComponent({this.intensity = 25, this.duration = 1000, this.type = ControlType.vibrate, this.time = 0});

  Map<String, dynamic> toJson() {
    return {
      "intensity": intensity,
      "duration": duration,
      "type": type?.index ?? -1,
      "time": time
    };
  }

  static AlarmToneComponent fromJson(component) {
    return AlarmToneComponent(
      intensity: component["intensity"],
      duration: component["duration"],
      type: component["type"] == -1 ? null : ControlType.values[component["type"]],
      time: component["time"]
    );
  }
}

class AlarmTone {
  int id;
  String? serverId;
  String name = "";
  List<AlarmToneComponent> components = [];

  AlarmTone({required this.id, required this.name});

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "serverId": serverId,
      "name": name,
      "components": components.map((e) => e.toJson()).toList()
    };
  }

  static AlarmTone fromJson(tone) {
    AlarmTone t = AlarmTone(id: tone["id"], name: tone["name"]);
    if(tone["serverId"] != null)
      t.serverId = tone["serverId"];
    if(tone["components"] != null)
      t.components = (tone["components"] as List).map((e) => AlarmToneComponent.fromJson(e)).toList();
    return t;
  }
}

class AlarmShocker {
  String shockerId = "";
  int? toneId;
  String? serverToneId;
  int intensity = 25;
  int duration = 1000;
  ControlType? type = ControlType.vibrate;
  Shocker? shockerReference;

  bool enabled = false;
  
  Map<String, dynamic> toJson() {
    return {
      "shockerId": shockerId, 
      "toneId": toneId,
      "intensity": intensity,
      "duration": duration,
      "type": type?.index ?? -1,
      "enabled": enabled
    };
  }

  static AlarmShocker fromJson(shocker) {
    return AlarmShocker()
      ..shockerId = shocker["shockerId"]
      ..toneId = shocker["toneId"]
      ..intensity = shocker["intensity"]
      ..duration = shocker["duration"]
      ..type = shocker["type"] == -1 ? null : ControlType.values[shocker["type"]]
      ..enabled = shocker["enabled"];
  }
  
  static AlarmShocker fromAlarmServerShocker(shocker) {
    AlarmShocker s = AlarmShocker()
      ..shockerId = shocker["ShockerId"]
      ..intensity = shocker["Intensity"]
      ..duration = shocker["Duration"]
      ..type = ControlType.values[shocker["ControlType"]]
      ..enabled = shocker["Enabled"];
    if(shocker["ToneId"] != null) {
      s.serverToneId = shocker["ToneId"];
    }
    // we need to match the server id with the tone id
    for(AlarmTone tone in AlarmListManager.getInstance().alarmTones) {
      if(tone.serverId == s.serverToneId) {
        s.toneId = tone.id;
        break;
      }
    }
    return s;
  }
  
  Map<String, dynamic>? toAlarmServerShocker(String apiTokenId) {
    return {
      "ShockerId": shockerId,
      "Intensity": intensity,
      "Duration": duration,
      "ApiTokenId": apiTokenId,
      "ControlType": type?.index ?? -1,
      "Enabled": enabled,
      "ToneId": serverToneId
    };
  }
}

class Alarm {
  int id;
  String? serverId;
  String name;
  int hour;
  int minute;
  bool monday;
  bool tuesday;
  bool wednesday;
  bool thursday;
  bool friday;
  bool saturday;
  bool sunday;
  bool active;
  bool repeatAlarmsTone = true;
  List<AlarmShocker> shockers = [];

  Alarm(
      {required this.id,
      required this.name,
      this.hour = 13,
      this.minute = 42,
      this.monday = false,
      this.tuesday = false,
      this.wednesday = false,
      this.thursday = false,
      this.friday = false,
      this.saturday = false,
      this.sunday = false,
      this.serverId = "",
      required this.active});

  List<bool> get days {
    return [monday, tuesday, wednesday, thursday, friday, saturday, sunday];
  }

  void trigger(AlarmListManager manager, bool disableIfApplicable) async {
    // ToDo: show notification
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool("alarm$id.active", true);

    FlutterLocalNotificationsPlugin().show(id, name,"Your alarm is firing", NotificationDetails(android: AndroidNotificationDetails("alarms", "Alarms", enableVibration: true, priority: Priority.high, importance: Importance.max, actions: [
      AndroidNotificationAction("stop", "Stop alarm", showsUserInterface: true)
    ])), payload: id.toString());
    DateTime startedAt = DateTime.now();
    var maxDuration = 0;
    bool shouldContinue = true;
    while(shouldContinue) {
      Map<int, List<Control>> controlTimes = {0: []};
      for (var shocker in shockers) {
        if (!shocker.enabled) continue;
        if(shocker.toneId != null) {
          var tone = manager.getTone(shocker.toneId!);
          if(tone != null) {
            for (var component in tone.components) {
              int executionTime = component.time + component.duration;
              if (executionTime > maxDuration) {
                maxDuration = executionTime;
              }
              if(!controlTimes.containsKey(component.time)) {
                controlTimes[component.time] = [];
              }
              Control control = Control();
              control.type = component.type!;
              control.intensity = component.intensity;
              control.duration = component.duration;
              control.id = shocker.shockerId;
              control.apiTokenId = shocker.shockerReference!.apiTokenId;
              controlTimes[component.time]!.add(control);
            }
          }
        } else {
          if (shocker.duration > maxDuration) {
            maxDuration = shocker.duration;
          }
          Control control = Control();
          control.type = shocker.type!;
          control.intensity = shocker.intensity;
          control.duration = shocker.duration;
          control.id = shocker.shockerId;
          control.apiTokenId = shocker.shockerReference!.apiTokenId;
          controlTimes[0]!.add(control);
          // If a shocker is paused the backend will return an error. So we don't need to check if it's paused. Especially as the saved state may not reflect the real paused state.
        }
      }

      int timeTillNow = 0;
      int timeDiff = 0;
      for (var time in controlTimes.keys) {
        timeDiff = time - timeTillNow;
        print(time);
        print(timeDiff);
        if(timeDiff > 0) await Future.delayed(Duration(milliseconds: timeDiff));
        timeTillNow = time;


        print("checking alarm$id.active");
        await prefs.reload();
        shouldContinue = prefs.getBool("alarm$id.active") ?? false;
        if(!shouldContinue) break;
        try {
          await manager.sendControls(controlTimes[time]??[], customName: name, useWs: false);
        } catch (e) {
          print("Error while sending controls: $e");
        }
      }


      // Wait until all shockers have finished
      int waitTime =maxDuration - timeTillNow + manager.settings.alarmToneRepeatDelayMs;
      print("Waiting for $waitTime");
      await Future.delayed(Duration(milliseconds: waitTime));
      print("is $shouldContinue");
      int secondsSinceAlarmStart = DateTime.now().difference(startedAt).inSeconds;
      if(secondsSinceAlarmStart >= manager.settings.maxAlarmLengthSeconds || !repeatAlarmsTone) shouldContinue = false;
    }
    onAlarmStopped(manager);

    if (disableIfApplicable) {
      if(!shouldSchedulePerWeekday()) {
        active = false;
        manager.saveAlarm(this);
      } else {
        schedule(manager);
      }
    }

  }

  void onAlarmStopped(AlarmListManager manager, {bool needStop = true}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("alarm$id.active", false);
    if(needStop) {
      for (var shocker in shockers) {
        if (shocker.enabled) {
          // Stop all shockers
          manager.sendShock(ControlType.stop, shocker.shockerReference!, shocker.intensity, shocker.duration, customName: name, useWs: false);
        }
      }
    }

    FlutterLocalNotificationsPlugin().show(id, name,"Alarm stopped", NotificationDetails(android: AndroidNotificationDetails("alarms", "Alarms", enableVibration: true, priority: Priority.high, importance: Importance.max)), payload: id.toString());

  }

  // Good enough for debugging for now
  @override
  toString() {
    return "active: $active, name: $name, hour: $hour, minute: $minute, days: $days";
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "hour": hour,
      "minute": minute,
      "monday": monday,
      "tuesday": tuesday,
      "wednesday": wednesday,
      "thursday": thursday,
      "friday": friday,
      "saturday": saturday,
      "sunday": sunday,
      "active": active,
      "serverId": serverId,
      "shockers": shockers.map((e) => e.toJson()).toList(),
      "repeatAlarmsTone": repeatAlarmsTone
    };
  }

  static Alarm fromJson(alarm) {
    Alarm a = Alarm(
      id: alarm["id"],
      name: alarm["name"],
      hour: alarm["hour"],
      minute: alarm["minute"],
      monday: alarm["monday"],
      tuesday: alarm["tuesday"],
      wednesday: alarm["wednesday"],
      thursday: alarm["thursday"],
      friday: alarm["friday"],
      saturday: alarm["saturday"],
      sunday: alarm["sunday"],
      active: alarm["active"]);
    if(alarm["shockers"] != null)
      a.shockers = (alarm["shockers"] as List).map((e) => AlarmShocker.fromJson(e)).toList();
    if(alarm["repeatAlarmsTone"] != null)
      a.repeatAlarmsTone = alarm["repeatAlarmsTone"];
    if(alarm["serverId"] != null)
      a.serverId = alarm["serverId"];
    return a;
  }

  bool shouldSchedulePerWeekday() {
    return days.any((element) {
      return element == true;
    });
  }


  DateTime nextWeekday(int weekday, alarmHour, alarmMinute) {
    var checkedDay = DateTime.now();

    if (checkedDay.weekday == weekday) {
      final todayAlarm = DateTime(checkedDay.year, checkedDay.month,
          checkedDay.day, alarmHour, alarmMinute);

      if (checkedDay.isBefore(todayAlarm)) {
        return todayAlarm;
      }
      return todayAlarm.add(Duration(days: 7));
    }

    while (checkedDay.weekday != weekday) {
      checkedDay = checkedDay.add(Duration(days: 1));
    }

    return DateTime(checkedDay.year, checkedDay.month, checkedDay.day,
        alarmHour, alarmMinute);
  }


  schedule(AlarmListManager manager) async {
    DateTime now = DateTime.now();
    if (!shouldSchedulePerWeekday()) {
      DateTime nextOccurrance = DateTime(now.year, now.month, now.day, hour, minute);
      // Schedule for next occurrance 
      if (nextOccurrance.isBefore(now)) {
        nextOccurrance = nextOccurrance.add(Duration(days: 1));
      }

      if(!isAndroid()) {
        ScaffoldMessenger.of(manager.context!).showSnackBar(SnackBar(content: Text("Alarms are only supported on Android atm")));
        return;
      }
      try {
        ScaffoldMessenger.of(manager.context!).showSnackBar(SnackBar(content: Text("Scheduled alarm for ${nextOccurrance.toString()}")));
      } catch (e) {
        print("Error: $e");
      }
      AndroidAlarmManager.oneShotAt(nextOccurrance, id * 7, alarmCallback, exact: true, wakeup: true);
    } else {
      // Schedule for every weekday
      for (int i = 0; i < 7; i++) {
        if (days[i]) {
          if(!isAndroid()) {
            ScaffoldMessenger.of(manager.context!).showSnackBar(SnackBar(content: Text("Alarms are only supported on Android atm")));
            return;
          }
          DateTime nextOccurrance = nextWeekday(i + 1, hour, minute); // +1 as monday is 1 while in my code it's 0

          if(!isAndroid()) {
            ScaffoldMessenger.of(manager.context!).showSnackBar(SnackBar(content: Text("Alarms are only supported on Android atm")));
            return;
          }
          try {
            ScaffoldMessenger.of(manager.context!).showSnackBar(SnackBar(content: Text("Scheduled alarm for ${nextOccurrance.toString()}")));
          } catch (e) {
            print("Error: $e");
          }
          AndroidAlarmManager.oneShotAt(nextOccurrance, id * 7 + i, alarmCallback, exact: true, wakeup: true);
        }
      }
    }
  }

  static Alarm fromAlarmServerAlarm(Map<String, dynamic> a) {
    String cron = a["Cron"];
    List<String> cronParts = cron.split(' ');
    Alarm alarm = Alarm(active: a["Enabled"], serverId: a["Id"], name: a["Name"], id: -1);
    for(Alarm existing in AlarmListManager.getInstance().getAlarms()) {
      if(existing.serverId == alarm.serverId) {
        alarm.id = existing.id;
        break;
      }
    }
    print(alarm.id);
    // If an alarm isn't found the AlarmListManager will give it an id.

    int seconds = 0;
    int minutes = 0;
    int hours = 0;
    try {
      // We assume that the time is in the current timezone cause that's what the user would normall expect.
      // If they're hopping timezones that's either a feature or a bug. Depending on what they need
      seconds = int.parse(cronParts[0]);
      minutes = int.parse(cronParts[1]);
      hours = int.parse(cronParts[2]);
      alarm.minute = minutes;
      alarm.hour = hours;
      for(String day in cronParts[5].split(",")) {
        switch(day) {
          case "1":
            alarm.monday = true;
            break;
          case "2":
            alarm.tuesday = true;
            break;
          case "3":
            alarm.wednesday = true;
            break;
          case "4":
            alarm.thursday = true;
            break;
          case "5":
            alarm.friday = true;
            break;
          case "6":
            alarm.saturday = true;
            break;
          case "0":
            alarm.sunday = true;
            break;
        }
      }
    } catch (e) {
      print("Error parsing cron");
      print(e);
    }
    // Now we need to parse the shockers
    List<dynamic> shockers = a["Shockers"];
    for(var shocker in shockers) {
      alarm.shockers.add(AlarmShocker.fromAlarmServerShocker(shocker));
    }

    return alarm;
  }

  Map<String, dynamic>? toAlarmServerAlarm(String apiTokenId) {
    if(id == -1) {
      return null;
    }
    String cron = "0 $minute $hour ? * ";
    List<String> days = [];
    if(monday) days.add("1");
    if(tuesday) days.add("2");
    if(wednesday) days.add("3");
    if(thursday) days.add("4");
    if(friday) days.add("5");
    if(saturday) days.add("6");
    if(sunday) days.add("0");
    cron += days.isEmpty ? "*" : days.join(",");
    return {
      "Id": serverId,
      "Name": name,
      "Enabled": active,
      "ApiTokenId": apiTokenId,
      "TimeZone": DateTime.now().timeZoneName,
      "Cron": cron,
      "Shockers": shockers.map((e) => e.toAlarmServerShocker(apiTokenId)).toList()
    };
  }

  String getId() {
    return id.toString();
  }
}