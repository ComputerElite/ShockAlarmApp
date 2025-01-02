import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../stores/alarm_store.dart';
import '../services/alarm_list_manager.dart';
import '../services/openshock.dart';

class ShockerItem extends StatefulWidget {
  final Shocker shocker;
  final AlarmListManager manager;
  final Function onRebuild;

  const ShockerItem({Key? key, required this.shocker, required this.manager, required this.onRebuild})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => ShockerItemState(shocker, manager, onRebuild);
}

class ShockerItemState extends State<ShockerItem> {
  final Shocker shocker;
  final AlarmListManager manager;
  final Function onRebuild;
  bool expanded = false;

  int currentIntensity = 25;
  int currentDuration = 1000;

  void action(ControlType type) {
    manager.sendShock(type, shocker, currentIntensity, currentDuration);
  }

  double cubicToLinear(double value) {
    return pow(value, 6/3).toDouble();
  }

  double linearToCubic(double value) {
    return pow(value,  3/6).toDouble();
  }

  double reverseMapDuration(double value) {

    return linearToCubic((value - 300) / shocker.durationLimit);
  }

  int mapDuration(double value) {
    return 300 + (cubicToLinear(value) * (shocker.durationLimit - 300) / 100).toInt() * 100;
  }
  
  ShockerItemState(this.shocker, this.manager, this.onRebuild);
  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return GestureDetector(
      /*
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  EditAlarm(alarm: this.alarm, manager: manager))),
                  */
      child: Observer(
        builder: (context) => GestureDetector(
          onTap: () => {
            setState(() {
              expanded = !expanded;
            })
          },
          child:
            Card(
              color: t.colorScheme.onInverseSurface,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          spacing: 10,
                          children: <Widget>[
                            Text(
                              shocker.name,
                              style: TextStyle(fontSize: 24),
                            ),
                             Chip(label: Text(shocker.hub)),
                          ],
                          
                        ),
                        Column(children: [
                          IconButton(onPressed: () {setState(() {
                            expanded = !expanded;
                          });}, icon: Icon(expanded ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded))
                        ],)
                      ],
                    ),
                    if (expanded) Column(
                      children: [
                        Row(children: [
                          Icon(Icons.sports_hockey),
                          Text("Intensity: " + currentIntensity.toString(), style: TextStyle(fontSize: 24),),
                        ], mainAxisAlignment: MainAxisAlignment.center,),
                        Slider(value: currentIntensity.toDouble(), max: shocker.intensityLimit.toDouble(), onChanged: (double value) {
                          setState(() {
                            currentIntensity = value.toInt();
                          });
                        }),
                        Row(
                          children: [
                            Icon(Icons.timer),
                            Text("Duration: " + (currentDuration / 1000.0).toString(), style: TextStyle(fontSize: 24),),
                          ], mainAxisAlignment: MainAxisAlignment.center),
                        Slider(value: reverseMapDuration(currentDuration.toDouble()), max: 1, onChanged: (double value) {
                          setState(() {
                            currentDuration = mapDuration(value);
                          });
                        }),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            if(shocker.shockAllowed)
                              IconButton(
                                icon: Icon(Icons.sports_hockey),
                                onPressed: () {action(ControlType.shock);},
                              ),
                            if(shocker.vibrateAllowed)
                              IconButton(
                                icon: Icon(Icons.vibration),
                                onPressed: () {action(ControlType.vibrate);},
                              ),
                            if(shocker.soundAllowed)
                              IconButton(
                                icon: Icon(Icons.volume_down),
                                onPressed: () {action(ControlType.sound);},
                              ),
                          ],
                        ),
                        SizedBox.fromSize(size: Size.fromHeight(50),child: 
                        IconButton(onPressed: () {action(ControlType.stop);}, icon: Icon(Icons.stop),)
                        ,)
                        
                      ],
                    ),
                  ],
                )
              ),
            ),
          ),
      ),
    );
  }
}