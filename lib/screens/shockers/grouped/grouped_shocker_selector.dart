import 'package:flutter/material.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/screens/shockers/shocker_item.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:sticky_headers/sticky_headers.dart';

import '../../../services/openshock.dart';
import '../../../components/constrained_container.dart';
import '../hub_item.dart';

class GroupedShockerSelector extends StatefulWidget {
  Function onChanged;
  bool onlyLive = false;
  GroupedShockerSelector({Key? key, required this.onChanged, this.onlyLive = false}) : super(key: key);

  @override
  GroupedShockerSelectorState createState() => GroupedShockerSelectorState();
}

class GroupedShockerSelectorState extends State<GroupedShockerSelector> {
  static ScrollController _scrollController = ScrollController();

  void onRebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<Shocker> filteredShockers =
        AlarmListManager.getInstance().shockers.where((x) {
          return !widget.onlyLive || x.liveAllowed;
        }).toList();
    Map<Hub?, List<Shocker>> groupedShockers = {};
    for (Shocker shocker in filteredShockers) {
      if (!groupedShockers.containsKey(shocker.hubReference)) {
        groupedShockers[shocker.hubReference] = [];
      }
      groupedShockers[shocker.hubReference]!.add(shocker);
    }
    // now add all missing hubs
    for (Hub hub in AlarmListManager.getInstance().hubs) {
      if (!AlarmListManager.getInstance().settings.disableHubFiltering &&
          AlarmListManager.getInstance().enabledHubs[hub.id] == false) {
        continue;
      }
      if (!groupedShockers.containsKey(hub)) {
        groupedShockers[hub] = [];
      }
    }
    List<Widget> children = [
      for (MapEntry<Hub?, List<Shocker>> hubContainer
          in groupedShockers.entries)
        StickyHeader(
          header: HubItem(
            hub: hubContainer.key ?? Hub(),
            manager: AlarmListManager.getInstance(),
            onRebuild: onRebuild,
            key: ValueKey(hubContainer.key
                ?.getIdentifier(AlarmListManager.getInstance())),
          ),
          content: PaddedCard(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Expanded(
                      child: Wrap(
                    spacing: 5,
                    children: hubContainer.value.isEmpty
                        ? [Text("No shockers${widget.onlyLive ? " with live control permission" : ""}")]
                        : [
                            for (Shocker s in hubContainer.value)
                              ShockerChip(
                                shocker: s,
                                manager: AlarmListManager.getInstance(),
                                onSelected: (bool b) {
                                  setState(() {
                                    if (b) {
                                      AlarmListManager.getInstance()
                                          .selectedShockers
                                          .add(s.id);
                                    } else {
                                      AlarmListManager.getInstance()
                                          .selectedShockers
                                          .remove(s.id);
                                    }
                                  });
                                  widget.onChanged();
                                },
                                key: ValueKey(s.getIdentifier()),
                              )
                          ],
                  ))
                ])
          ),
        )
    ];
    return Flexible(
        child: ConstrainedContainer(
      child: groupedShockers.isEmpty
          ? Text(
              AlarmListManager.getInstance().hasAccountWithShockers()
                  ? "No shockers assosciated with account. Create them!"
                  : "You're not logged in",
              style: t.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            )
          : ListView.builder(
              itemBuilder: (context, index) {
                return children[index];
              },
              itemCount: children.length,
            ),
    ));
  }
}

class ShockerChip extends StatefulWidget {
  final AlarmListManager manager;
  final Shocker shocker;
  final Function(bool) onSelected;
  const ShockerChip(
      {Key? key,
      required this.shocker,
      required this.manager,
      required this.onSelected})
      : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      ShockerChipState(manager, shocker, onSelected);
}

class ShockerChipState extends State<ShockerChip> {
  final AlarmListManager manager;
  final Shocker shocker;
  final Function(bool) onSelected;
  ShockerChipState(this.manager, this.shocker, this.onSelected);
  ThemeData? t;
  @override
  Widget build(BuildContext context) {
    t = Theme.of(context);
    return GestureDetector(
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 5,
              children: [
                Text(shocker.name + (shocker.paused ? " (paused)" : "")),
              ],
            ),
            onSelected: onSelected,
            selected: manager.selectedShockers.contains(shocker.id),
            backgroundColor:
                shocker.paused ? t!.colorScheme.errorContainer : null,
            selectedColor:
                shocker.paused ? t!.colorScheme.errorContainer : null,
          ),
          if (shocker.paused)
            GestureDetector(
              child: Icon(
                Icons.info,
                color: t!.colorScheme.error,
              ),
              onTap: () {
                InfoDialog.show(
                    "Shocker is paused",
                    shocker.isOwn
                        ? "This shocker was pause by you. While it's paused you cannot control it. You can unpause it by selecting the shocker and pressing unpause selected."
                        : "This shocker was paused by the owner. While it's paused you cannot control it. You can ask the owner to unpause it.");
              },
            )
        ],
      ),
    );
  }

  void onLongPress() {
    List<ShockerAction> shockerActions = shocker.isOwn
        ? ShockerItem.ownShockerActions
        : ShockerItem.foreignShockerActions;
    List<Widget> actions = [];
    for (ShockerAction a in shockerActions) {
      actions.add(GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
          a.onClick(manager, shocker, context, manager.reloadAllMethod!);
        },
        child: Row(
          children: [
            a.icon,
            Text(
              a.name,
              style: t!.textTheme.titleLarge,
            )
          ],
          spacing: 5,
          mainAxisSize: MainAxisSize.min,
        ),
      ));
    }
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog.adaptive(
            title: Text(shocker.name),
            content: Column(
              spacing: 20,
              children: actions,
              mainAxisSize: MainAxisSize.min,
            ),
            actions: [
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Close"))
            ],
          );
        });
  }
}
