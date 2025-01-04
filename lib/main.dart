import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/home.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'services/alarm_list_manager.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

Future requestPermissions() async{
  final status = await Permission.scheduleExactAlarm.status;
  print('Schedule exact alarm permission: $status.');
  if (status.isDenied) {
    print('Requesting schedule exact alarm permission...');
    final res = await Permission.scheduleExactAlarm.request();
    print('Schedule exact alarm permission ${res.isGranted ? '' : 'not'} granted.');
  }
}

void initNotification() async {
  return;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
  // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('launcher_icon');
  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings();
  final LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(
          defaultActionName: 'Open notification');
  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);
}

void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
    final String? payload = notificationResponse.payload;
    if (notificationResponse.payload != null) {
      debugPrint('notification payload: $payload');
    }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initNotification();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
    AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  //flutterLocalNotificationsPlugin.show(0, "Test","Test", NotificationDetails(android: AndroidNotificationDetails("alarms", "Alarms")));
  await AndroidAlarmManager.initialize();
  await requestPermissions();

  runApp(MyApp(null));
}

@pragma('vm:entry-point')
void alarmCallback(int id) async {

  AlarmListManager manager = AlarmListManager();
  initNotification(); 
  await manager.loadAllFromStorage();
  manager.getAlarms().forEach((element) {
    print("Checking alarm");
    if(element.active && id ==element.id) {
      element.trigger(manager, true);
    }
  });
  print("Woah");
}

class MyApp extends StatelessWidget {
  int? alarmId;
  MyApp(this.alarmId);


  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {

    AlarmListManager manager = AlarmListManager();
    manager.loadAllFromStorage();
    return DynamicColorBuilder(builder: (lightColorScheme, darkColorScheme) {
      return MaterialApp(
        title: 'ShockAlarm',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: lightColorScheme,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: darkColorScheme,
        ),
        themeMode: ThemeMode.system,
        home: ScreenSelector(manager: manager)
      );
    });
  }
}