import 'package:flutter/material.dart';

import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';

class LogScreen extends StatefulWidget {
  AlarmListManager manager;
  Shocker shocker;
  
  LogScreen({Key? key, required this.manager, required this.shocker}) : super(key: key);

  @override
  State<StatefulWidget> createState() => LogScreenState(manager, shocker);
}

class LogScreenState extends State<LogScreen> {
  AlarmListManager manager;
  Shocker shocker;
  List<ShockerLog> logs = [];
  bool initialLoading = false;

  LogScreenState(this.manager, this.shocker);

  @override
  void initState() {
    super.initState();
    initialLoading = true;
    loadLogs();
  }

  Future<void> loadLogs() async {
    final newLogs = await manager.getShockerLogs(shocker);
    setState(() {
      logs = newLogs;
      initialLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Logs for ${shocker.name}'),
      ),
      body: initialLoading ? Center(child: CircularProgressIndicator()) :
        RefreshIndicator(child: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          final log = logs[index];
          return ShockerLogEntry(log: log);
        },
      ),onRefresh: () async{
        return loadLogs();
      })
      
    );
  }
}

class ShockerLogEntry extends StatelessWidget {
  final ShockerLog log;

  const ShockerLogEntry({Key? key, required this.log}) : super(key: key);

  String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day;
    final timeString = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    final dateString = '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';

    return isToday ? timeString : '$dateString $timeString';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          spacing: 10,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              spacing: 10,
              children: [
                OpenShockClient.getIconForControlType(log.type),
                Text(log.getName()),
              ],
            ),
            Text(formatDateTime(log.createdOn.toLocal())),
        ],)
      ]
    );
  }
}
