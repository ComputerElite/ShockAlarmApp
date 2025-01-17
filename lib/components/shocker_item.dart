import 'dart:math';

import 'package:flutter/material.dart';
import '../screens/logs.dart';
import '../screens/shares.dart';
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

class ShockerItemState extends State<ShockerItem> with TickerProviderStateMixin {
  final Shocker shocker;
  final AlarmListManager manager;
  final Function onRebuild;
  bool expanded = false;
  bool delayVibrationEnabled = false;

  DateTime actionDoneTime = DateTime.now();
  DateTime delayDoneTime = DateTime.now();
  double delayDuration = 0;
  AnimationController? progressCircularController;
  AnimationController? delayVibrationController;
  bool loadingPause = false;


  int currentIntensity = 25;
  int currentDuration = 1000;
  RangeValues rangeValues = RangeValues(0, 0);

  @override
  void initState() {
    super.initState();
    currentIntensity = min(shocker.intensityLimit, currentIntensity);
    currentDuration = min(shocker.durationLimit, currentDuration);
  }

  @override
  void dispose() {
    progressCircularController?.dispose();
    super.dispose();
  }

  void realAction(ControlType type) {
    if(type != ControlType.stop)
      setState(() {
        actionDoneTime = DateTime.now().add(Duration(milliseconds: currentDuration));
        progressCircularController = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: currentDuration),
        )..addListener(() {
          setState(() {
            if(progressCircularController!.status == AnimationStatus.completed) {
              progressCircularController!.stop();
              progressCircularController = null;
            }
          });
        });
        progressCircularController!.forward();
      });
    manager.sendShock(type, shocker, currentIntensity, currentDuration).then((errorMessage) {
      if(errorMessage == null) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMessage),
        duration: Duration(seconds: 3),
      ));
    });
  }

  void action(ControlType type) {
    if(type == ControlType.stop) {
      delayVibrationController?.stop();
      progressCircularController?.stop();
      setState(() {
        delayVibrationController = null;
        progressCircularController = null;
      });
      realAction(type);
      return;
    }
    // Get random delay based on range
    if(delayVibrationEnabled) {
      // ToDo: make this duration adjustable
      manager.sendShock(ControlType.vibrate, shocker, currentIntensity, 500).then((errorMessage) {
        if(errorMessage == null) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(errorMessage),
          duration: Duration(seconds: 3),
        ));
      });
    }
    delayDuration = rangeValues.start + Random().nextDouble() * (rangeValues.end - rangeValues.start);
    if(delayDuration == 0) {
      realAction(type);
      return;
    }
    delayDoneTime = DateTime.now().add(Duration(milliseconds: (delayDuration * 1000).toInt()));
    delayVibrationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (delayDuration * 1000).toInt()),
    )..addListener(() {
      setState(() {
        if(delayVibrationController!.status == AnimationStatus.completed) {
          delayVibrationController!.stop();
          delayVibrationController = null;
          realAction(type);
        }
      });
    });
    delayVibrationController!.forward();
  }

  void startRenameShocker() {
    TextEditingController controller = TextEditingController();
    controller.text = shocker.name;
    showDialog(context: context, builder: (context) => AlertDialog(
      title: Text("Rename shocker"),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: "Name"
        ),
      ),
      actions: [
        TextButton(onPressed: () {
          Navigator.of(context).pop();
        }, child: Text("Cancel")),
        TextButton(onPressed: () async {
          showDialog(context: context, builder: (context) => LoadingDialog(title: "Renaming shocker"));
          String? errorMessage = await manager.renameShocker(shocker, controller.text);
          Navigator.of(context).pop();
          if(errorMessage != null) {
            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Failed to rename shocker"), content: Text(errorMessage), actions: [TextButton(onPressed: () {
              Navigator.of(context).pop();
            }, child: Text("Ok"))],));
            return;
          }
          Navigator.of(context).pop();
          onRebuild();
        
        }, child: Text("Rename"))
      ],
    ));
  }

  void setPauseState(bool pause) async {
    setState(() {
      loadingPause = true;
    });
    String? error = await OpenShockClient().setPauseStateOfShocker(shocker, manager, pause);
    setState(() {
      loadingPause = false;
    });
    if(error != null) {
      showDialog(context: context, builder: (context) => AlertDialog(title: Text("Failed to pause shocker"), content: Text(error), actions: [TextButton(onPressed: () {
        Navigator.of(context).pop();
      }, child: Text("Ok"))],));
      return;
    }
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
      child: GestureDetector(
        onTap: () => {
          setState(() {
            if(shocker.paused) return;
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
                            Expanded(child: 
                              Text(
                              shocker.name,
                                style: t.textTheme.headlineSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                            ),
                      
                      Row(
                        spacing: 5,
                        children: [
                          if(shocker.isOwn)
                            PopupMenuButton(iconColor: t.colorScheme.onSurfaceVariant, itemBuilder: (context) {
                              return [
                                PopupMenuItem(value: "rename", child: Row(
                                  spacing: 10,
                                  children: [
                                  Icon(Icons.edit, color: t.colorScheme.onSurfaceVariant,),
                                  Text("Rename")
                                ],)),
                                PopupMenuItem(value: "logs", child: Row(
                                  spacing: 10,
                                  children: [
                                    Icon(Icons.list, color: t.colorScheme.onSurfaceVariant,),
                                  Text("Logs")
                                ],)),
                                PopupMenuItem(value: "shares", child: Row(
                                  spacing: 10,
                                  children: [
                                    Icon(Icons.share, color: t.colorScheme.onSurfaceVariant,),
                                  Text("Shares")
                                ],)),
                                PopupMenuItem(value: "delete", child: Row(
                                  spacing: 10,
                                  children: [
                                    Icon(Icons.delete, color: t.colorScheme.onSurfaceVariant,),
                                  Text("Delete")
                                ],))
                            ];
                        }, onSelected: (String value) {
                          if(value == "rename") {
                            startRenameShocker();
                          }
                          if(value == "logs") {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => LogScreen(shocker: shocker, manager: manager)));
                          }
                          if(value == "shares") {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => SharesScreen(shocker: shocker, manager: manager)));
                          }
                          if(value == "delete") {
                            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Delete shocker"), content: Text("Are you sure you want to delete the shocker ${shocker.name}?\n\n(You can add it again later)"), actions: [
                              TextButton(onPressed: () {
                                Navigator.of(context).pop();
                              }, child: Text("Cancel")),
                              TextButton(onPressed: () async {
                                String? errorMessage = await manager.deleteShocker(shocker);
                                if(errorMessage != null) {
                                  showDialog(context: context, builder: (context) => AlertDialog(title: Text("Failed to delete shocker"), content: Text(errorMessage), actions: [TextButton(onPressed: () {
                                    Navigator.of(context).pop();
                                  }, child: Text("Ok"))],));
                                  return;
                                }
                                Navigator.of(context).pop();
                                onRebuild();
                              }, child: Text("Delete"))
                            ],));
                          }
                        },),
                        if(!shocker.isOwn) PopupMenuButton(iconColor: t.colorScheme.onSurfaceVariant, itemBuilder: (context) {
                              return [
                                PopupMenuItem(value: "unlink", child: Row(
                                  spacing: 10,
                                  children: [
                                  Icon(Icons.delete, color: t.colorScheme.onSurfaceVariant,),
                                  Text("Unlink")
                                ],)),
                            ];
                        }, onSelected: (String value) {
                          if(value == "unlink") {
                            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Unlink shocker"), content: Text("Are you sure you want to unlink the shocker ${shocker.name} from your account? After that you cannot control the shocker anymore unless you redeem another share code."), actions: [
                              TextButton(onPressed: () {
                                Navigator.of(context).pop();
                              }, child: Text("Cancel")),
                              TextButton(onPressed: () async {
                                showDialog(context: context, builder: (context) {
                                  return LoadingDialog(title: "Unlinking shocker");
                                });
                                String? errorMessage;
                                Token? token = manager.getToken(shocker.apiTokenId);
                                if(token == null) errorMessage = "Token not found";
                                else {
                                  OpenShockShare share = OpenShockShare()
                                                        ..sharedWith = (OpenShockUser()..id = token.userId)
                                                        ..shockerReference = shocker;
                                  errorMessage = await manager.deleteShare(share);
                                }
                                if(errorMessage != null) {
                                  Navigator.of(context).pop();
                                  showDialog(context: context, builder: (context) => AlertDialog(title: Text("Failed to delete share"), content: Text(errorMessage ?? "Unknown error"), actions: [TextButton(onPressed: () {
                                    Navigator.of(context).pop();
                                  }, child: Text("Ok"))],));
                                  return;
                                }
                                await manager.updateShockerStore();
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                                onRebuild();
                              }, child: Text("Unlink"))
                            ],));
                          }
                        },),
                        if(loadingPause)
                          CircularProgressIndicator(),
                        if(shocker.isOwn && shocker.paused && !loadingPause)
                          IconButton(onPressed: () {
                            setPauseState(false);
                          }, icon: Icon(Icons.play_arrow)),
                        if(shocker.isOwn && !shocker.paused && !loadingPause)
                          IconButton(onPressed: () {
                            expanded = false;
                            setPauseState(true);
                          }, icon: Icon(Icons.pause)),

                        if (shocker.paused && !shocker.isOwn)
                        GestureDetector( child: Chip(
                            label: Text("paused"),
                            backgroundColor: t.colorScheme.errorContainer,
                            side: BorderSide.none,
                            avatar: Icon(Icons.info, color: t.colorScheme.error,)
                          ),
                          onTap: () {
                            showDialog(context: context, builder: (context) => AlertDialog(title: Text("Shocker is paused"), content: Text(shocker.isOwn ?
                            "This shocker was pause by you. While it's paused you cannot control it. You can unpause it by pressing the play button." 
                            : "This shocker was paused by the owner. While it's paused you cannot control it. You can ask the owner to unpause it."),
                            actions: [TextButton(onPressed: () {
                              Navigator.of(context).pop();
                            }, child: Text("Ok"))],));
                          },),
                        if (!shocker.paused)
                          IconButton(onPressed: () {setState(() {
                            expanded = !expanded;
                          });}, icon: Icon(expanded ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded)),
                      ],)
                    ],
                  ),
                  if (expanded) Column(
                    children: [
                      IntensityDurationSelector(duration: currentDuration, intensity: currentIntensity, maxDuration: shocker.durationLimit, maxIntensity: shocker.intensityLimit, onSet: (intensity, duration) {
                        setState(() {
                          currentDuration = duration;
                          currentIntensity = intensity;
                        });
                      }),
                      // Delay options
                      if(manager.settings.showRandomDelay)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          spacing: 5,
                          children: [
                            Switch(value: delayVibrationEnabled, onChanged: (bool value) {
                              setState(() {
                                delayVibrationEnabled = value;
                              });
                            },),
                            Expanded(child: manager.settings.useRangeSliderForRandomDelay ? RangeSlider(
                              values: rangeValues,
                              max: 10,
                              min: 0,
                              divisions: 10 * 3,
                              labels: RangeLabels(
                                "${(rangeValues.start * 10).round() / 10} s",
                                "${(rangeValues.end * 10).round() / 10} s",
                              ),
                              onChanged: (RangeValues values) {
                              setState(() {
                                rangeValues = values;
                              });
                            }) : 
                            Row(children: [
                              Text("${(rangeValues.start * 10).round() / 10} s"),
                              Expanded(child: 
                                Slider(value: rangeValues.start, min: 0, max: 10, onChanged: (double value) {
                                  setState(() {
                                    rangeValues = RangeValues(value, rangeValues.end);
                                  });
                                }),
                              )
                              
                            ],)
                          ),
                          
                          GestureDetector(child: Icon(Icons.info,),
                            onTap: () {
                              showDialog(context: context, builder: (context) => AlertDialog(title: Text("Delay options"), content: Text("Here you can add a random delay when pressing a button by selecting a range. If you enable the switch before the slider you can send a vibration before the actual action happens."),
                              actions: [
                                TextButton(onPressed: () {
                                  Navigator.of(context).pop();
                              }, child: Text("Ok"))]
                              ,));
                            },),
                        ],),
                      
                      if(progressCircularController == null && delayVibrationController == null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            if(shocker.soundAllowed)
                              IconButton(
                                icon: OpenShockClient.getIconForControlType(ControlType.sound),
                                onPressed: () {action(ControlType.sound);},
                              ),
                            if(shocker.vibrateAllowed)
                              IconButton(
                                icon: OpenShockClient.getIconForControlType(ControlType.vibrate),
                                onPressed: () {action(ControlType.vibrate);},
                              ),
                            if(shocker.shockAllowed)
                              IconButton(
                                icon: OpenShockClient.getIconForControlType(ControlType.shock),
                                onPressed: () {action(ControlType.shock);},
                              ),
                          ],
                        ),
                      if(delayVibrationController != null)
                      Row(spacing: 10, mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Text("Delaying action... ${(delayDoneTime.difference(DateTime.now()).inMilliseconds / 100).round() / 10} s"),
                        CircularProgressIndicator(
                            value: delayVibrationController == null ? 0 : (delayDoneTime.difference(DateTime.now()).inMilliseconds / (delayDuration*1000))
                          ),
                      ],),
                      if(progressCircularController != null)
                        Row(
                          spacing: 10,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Executing... ${(actionDoneTime.difference(DateTime.now()).inMilliseconds / 100).round() / 10} s"),
                            CircularProgressIndicator(
                              value: progressCircularController == null ? 0 : 1 - (actionDoneTime.difference(DateTime.now()).inMilliseconds / currentDuration),
                            )
                          ]
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
    );
  }
}

class IntensityDurationSelector extends StatefulWidget {
  final int duration;
  final int intensity;
  int maxDuration;
  int maxIntensity;
  bool showIntensity = true;
  ControlType type = ControlType.shock;
  final Function(int, int) onSet;

  IntensityDurationSelector({Key? key, this.showIntensity = true, this.type = ControlType.shock, required this.duration, required this.intensity, required this.onSet, required this.maxDuration, required this.maxIntensity}) : super(key: key);

  @override
  State<StatefulWidget> createState() => IntensityDurationSelectorState(duration, intensity, onSet, this.maxDuration, this.maxIntensity, this.showIntensity, this.type);
}

class IntensityDurationSelectorState extends State<IntensityDurationSelector> {
  int maxDuration;
  int maxIntensity;
  int duration;
  int intensity;
  bool showIntensity;
  ControlType type = ControlType.shock;
  Function(int, int) onSet;


  IntensityDurationSelectorState(this.duration, this.intensity, this.onSet, this.maxDuration, this.maxIntensity, this.showIntensity, this.type);

  double cubicToLinear(double value) {
    return pow(value, 6/3).toDouble();
  }

  double linearToCubic(double value) {
    return pow(value,  3/6).toDouble();
  }

  double reverseMapDuration(double value) {
    if(maxDuration <= 300) return 0;
    return linearToCubic((value - 300) / (maxDuration - 300));
  }

  int mapDuration(double value) {
    return 300 + (cubicToLinear(value) * (maxDuration - 300) / 100).toInt() * 100;
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return Column(
      children: [
        if(showIntensity)
          Row(mainAxisAlignment: MainAxisAlignment.center, spacing: 10,children: [
            OpenShockClient.getIconForControlType(type),
            Text("Intensity: $intensity", style: t.textTheme.headlineSmall,),
          ],),
        if(showIntensity)
          Slider(value: intensity.toDouble(), max: maxIntensity.toDouble(), onChanged: (double value) {
            setState(() {
              intensity = value.toInt();
              onSet(intensity, duration);
            });
          }),
        Row(
          mainAxisAlignment: MainAxisAlignment.center, spacing: 10,
          children: [
            Icon(Icons.timer),
            Text("Duration: ${duration / 1000.0}", style: t.textTheme.headlineSmall,),
          ],),
        Slider(value: reverseMapDuration(duration.toDouble()), max: 1, onChanged: (double value) {
          setState(() {
            duration = mapDuration(value);
            onSet(showIntensity ? intensity : 1, duration);
          });
        }),
      ],
    );
  }

}