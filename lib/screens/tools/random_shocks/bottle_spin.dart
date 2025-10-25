import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/screens/shockers/grouped/grouped_shocker_selector.dart';
import 'package:shock_alarm_app/components/page_padding.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:shock_alarm_app/screens/tones/tone_item.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';

import '../../../services/openshock.dart';

class BottleSpinScreen extends StatefulWidget {
  ControlsContainer controlsContainer;
  ControlType Function() getRandomControlType;
  BottleSpinScreen({Key? key, required this.controlsContainer, required this.getRandomControlType})
      : super(key: key);
  @override
  _BottleSpinScreenState createState() => _BottleSpinScreenState();
}

class _BottleSpinScreenState extends State<BottleSpinScreen> {
  int getRandomIntensity(ControlType type) {
    return AlarmListManager.getInstance().settings.useSeperateSliders &&
            type == ControlType.vibrate
        ? widget.controlsContainer.getRandomVibrateIntensity()
        : widget.controlsContainer.getRandomIntensity();
  }

  @override
  void initState() {
    super.initState();
    doSpin();
  }

  bool showBottleFlipButtons = false;
  List<double> directions = [];

  void doSpin() async {
    if (AlarmListManager.getInstance().getSelectedShockers().isEmpty) {
      ErrorDialog.show("No shockers selected",
          "Please select at least one shocker to spin the bottle.");
      return;
    }
    if (!spinDone) {
      return;
    }
    spinText = "";
    spinDone = false;
    showBottleFlipButtons = false;
    randomlySelectedShocker = Random()
        .nextInt(AlarmListManager.getInstance().getSelectedShockers().length);
    angle %= 2 * pi;
    int spins = Random().nextInt(5) + 6;
    double shockerIndexFraction =
        randomlySelectedShocker /
            AlarmListManager.getInstance().getSelectedShockers().length;
    double spinAngle = -angle + 2*pi * spins * deltaAngle.sign + 2*pi * shockerIndexFraction;

    //now spin it over time
    double spinDuration = 2000 + Random().nextDouble() * 200;
    double startTime = DateTime.now().millisecondsSinceEpoch.toDouble();
    double endTime = startTime + spinDuration;

    double startAngle = angle;
    double progress = 0;

    // now animate it
    while (progress < 1) {
      progress =
          (DateTime.now().millisecondsSinceEpoch.toDouble() - startTime) /
              (spinDuration);
      if (!mounted) return;
      setState(() {
        angle = startAngle + spinAngle * sin(progress * pi / 2);
      });
      await Future.delayed(Duration(milliseconds: 10));
    }
    ControlType type = widget.getRandomControlType!(); // get the random control type
    int intensity = getRandomIntensity(type);
    int duration =
        widget.controlsContainer.getRandomDuration(); // get the random duration
    Shocker s = AlarmListManager.getInstance()
        .getSelectedShockers()
        .elementAt(randomlySelectedShocker);
    String prefix =
        "${type.name} @ $intensity for ${(duration / 1000).toStringAsFixed(1)} sec (${s.hubReference?.name}.${s.name})";
    if (!mounted) return;
    setState(() {
      angle = startAngle + spinAngle;
      spinText = prefix;
      spinDone = true;
      showBottleFlipButtons = true;
    });
    AlarmListManager.getInstance().sendControls([
      s.getLimitedControls(
          type, intensity, duration)
    ]);
  }

  int randomlySelectedShocker = 0;
  bool spinDone = true;
  String spinText = "";

  double angle = 0;
  double deltaAngle = 1;
  bool requireSubtractionOfPi = false;

  DateTime lastCheck = DateTime.now();

  GlobalKey containerKey = GlobalKey();

  bool isCounterclockwise(double angleA, double angleB) {
    double delta = angleB - angleA;
    if (delta < 0) {
      delta += 2 * pi;
    }
    return delta > pi;
  }

  @override
  Widget build(BuildContext context) {
    List<Shocker> shockers =
        AlarmListManager.getInstance().getSelectedShockers().toList();

    ThemeData t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Bottle spin'),
      ),
      body: PagePadding(
          child: ConstrainedContainer(
              child: Flex(
        direction: Axis.vertical,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 10,
        children: <Widget>[
          Flexible(
            flex: 1,
            child: Column(
              children: [
                Text(
                  spinText,
                  style: t.textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          Flexible(
              flex: 5,
              child: LayoutBuilder(builder: (context, constraints) {
                double size = constraints.maxWidth;
                if (constraints.maxHeight < constraints.maxWidth) {
                  size = constraints.maxHeight;
                }

                return Container(
                  width: size,
                  height: size,
                  constraints: BoxConstraints(
                    maxWidth: size,
                    maxHeight: size,
                  ),
                  decoration: BoxDecoration(
                    color: t.colorScheme.onSecondary,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Expanded(
                            child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateZ(angle),
                          child: GestureDetector(
                              onPanStart: (details) {
                                if (!spinDone) {
                                  return;
                                }
                                directions.clear();
                                lastCheck = DateTime.now();
                                RenderBox containerKeySize = containerKey
                                    .currentContext!
                                    .findRenderObject() as RenderBox;
                                double innerAngle = atan2(
                                    details.localPosition.dx -
                                        containerKeySize.size.width / 2,
                                    details.localPosition.dy -
                                        containerKeySize.size.height / 2);

                                requireSubtractionOfPi = innerAngle < 0;
                              },
                              onPanUpdate: (details) {
                                if (!spinDone) {
                                  return;
                                }
                                RenderBox containerKeySize = containerKey
                                    .currentContext!
                                    .findRenderObject() as RenderBox;
                                Offset globalCenter =
                                    containerKeySize.localToGlobal(Offset(
                                        containerKeySize.size.width / 2,
                                        containerKeySize.size.height / 2));
                                double deltaX =
                                    details.globalPosition.dx - globalCenter.dx;
                                double deltaY =
                                    details.globalPosition.dy - globalCenter.dy;
                                double a = atan2(deltaY, deltaX);
                                if (requireSubtractionOfPi) { 
                                  a = a - pi;
                                }
                                deltaAngle = isCounterclockwise(a, angle) ? 1 : -1;
                                directions.add(deltaAngle);
                                if (directions.length > 20) {
                                  directions.removeAt(0);
                                }
                                setState(() {
                                  angle = a;
                                });
                              },
                              onPanEnd: (details) {
                                //get most used direction
                                double sum = 0;
                                for (double d in directions) {
                                  sum += d;
                                }
                                deltaAngle = sum;
                                doSpin();
                              },
                              behavior: HitTestBehavior.translucent,
                              child: Row(
                                  key: containerKey,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "BOTTLE", // spin it
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: size / 10,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_right,
                                      size: size / 7,
                                    )
                                  ])),
                        )),
                      ),
                      ...shockers.map((shocker) => Positioned(
                            left: size / 2 +
                                cos(2 *
                                        pi /
                                        shockers.length *
                                        shockers.indexOf(shocker)) *
                                    (size / 2 - 50),
                            top: size / 2 +
                                sin(2 *
                                        pi /
                                        shockers.length *
                                        shockers.indexOf(shocker)) *
                                    (size / 2 - 50),
                            child: FractionalTranslation(
                                translation: Offset(-0.5, -0.5),
                                child: Chip(
                                  label: Text(shocker.name),
                                  backgroundColor: shockers.indexOf(shocker) ==
                                              randomlySelectedShocker &&
                                          spinDone
                                      ? t.colorScheme
                                          .onPrimary // ToDo: change this color
                                      : null,
                                )),
                          )),
                    ],
                  ),
                );
              })),
          Flexible(
              child: SizedBox(
                  height: 30,
                  child: showBottleFlipButtons
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 10,
                          children: [
                            IconButton(
                                onPressed: () {
                                  doSpin();
                                },
                                icon: Icon(Icons.refresh))
                          ],
                        )
                      : SizedBox.fromSize(
                          size: Size(0, 0),
                        )))
        ],
      ))),
    );
  }
}
