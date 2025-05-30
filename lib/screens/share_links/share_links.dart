import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/dialogs/delete_dialog.dart';
import 'package:shock_alarm_app/components/qr_card.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/screens/screen_selector.dart';
import 'package:shock_alarm_app/screens/settings/settings_screen.dart';
import 'package:shock_alarm_app/screens/share_links/share_link_edit/share_link_edit.dart';
import 'package:shock_alarm_app/screens/shares/shares.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:shock_alarm_app/stores/alarm_store.dart';

import '../../components/constrained_container.dart';
import '../../components/desktop_mobile_refresh_indicator.dart';

class ShareLinkCreationDialog extends StatefulWidget {
  String shareLinkName = "";
  DateTime? expiresOn = DateTime.now().add(Duration(days: 1));

  @override
  State<StatefulWidget> createState() => ShareLinkCreationDialogState();
}

class ShareLinkCreationDialogState extends State<ShareLinkCreationDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
      title: Text("Create Share Link"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: InputDecoration(
              labelText: "Name",
            ),
            onChanged: (value) {
              widget.shareLinkName = value;
            },
          ),
          PredefinedSpacing(),
          Text("Expires: ${widget.expiresOn.toString().split(".").first}",
              style: TextStyle(fontSize: 20)),
          TextButton(
              onPressed: () async {
                widget.expiresOn = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 365)),
                    initialDate: widget.expiresOn);
                if (widget.expiresOn == null) return;
                TimeOfDay? time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(widget.expiresOn!));
                setState(() {
                  widget.expiresOn = DateTime(
                      widget.expiresOn!.year,
                      widget.expiresOn!.month,
                      widget.expiresOn!.day,
                      time!.hour,
                      time.minute);
                });
              },
              child: Text("Change expiry")),
        ],
      ),
      actions: <Widget>[
        TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text("Cancel")),
        TextButton(
            onPressed: () async {
              if (widget.shareLinkName.isEmpty) {
                ErrorDialog.show("Name is empty", "Please enter a name for the share link");
                return;
              }
              Token? token = await AlarmListManager.getInstance().getSpecificUserToken();
              LoadingDialog.show("Creating Share Link");
              PairCode error = await AlarmListManager.getInstance()
                  .createShareLink(widget.shareLinkName, widget.expiresOn!, token);
              if (error.error != null) {
                Navigator.of(context).pop();
                ErrorDialog.show("Error creating share link", error.error!);
                return;
              }
              Navigator.of(context).pop();
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) => ShareLinkEditScreen(
                      shareLink: OpenShockShareLink.fromId(
                          error.code!,
                          widget.shareLinkName,
                          token))));
              AlarmListManager.getInstance().reloadShareLinksMethod!();
            },
            child: Text("Create")),
      ],
    );
  }
}

class ShareLinksScreen extends StatefulWidget {
  const ShareLinksScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ShareLinksScreenState();

  static getFloatingActionButton(
      AlarmListManager manager, BuildContext context, Function reloadState) {
    return FloatingActionButton(
        onPressed: () {
          if(!AlarmListManager.supportsWs()) {
            if (!manager.hasValidAccount()) {
              ErrorDialog.show("Not logged in",
                  "Login to OpenShock to create a Share Link. To do this visit the settings page.");
              return;
            }
            showDialog(context: context, builder: (builder) => ShareLinkCreationDialog());
          }
          showDialog(
            context: context,
            builder: (context) => AlertDialog.adaptive(
              title: Text("Add Share Link"),
              content: Text("What do you want to do?"),
              actions: <Widget>[
                TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await SettingsScreen.showShareLinkPopup();
                      InfoDialog.show("Share Link Info",
                          "Share links you add to ShockAlarm are shown in the settings tab. From there you can see which ones you added and remove them if you don't need them anymore.\n\nThe shockers from the share link are shown in the devices tab.");
                    },
                    child: Text("Add existing share link")),
                TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      if (!manager.hasValidAccount()) {
                        ErrorDialog.show("Not logged in",
                            "Login to OpenShock to create a Share Link. To do this visit the settings page.");
                        return;
                      }
                      showDialog(
                          context: context,
                          builder: (context) => ShareLinkCreationDialog());
                    },
                    child: Text("Create new share link")),
                TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text("Cancel")),
              ],
            ),
          );
        },
        child: Icon(Icons.add));
  }
}

class ShareLinksScreenState extends State<ShareLinksScreen> {
  bool initialLoading = false;

  Future loadShares() async {
    await AlarmListManager.getInstance().updateShareLinks();
    setState(() {
      initialLoading = false;
    });
  }

  @override
  void initState() {
    AlarmListManager.getInstance().reloadShareLinksMethod = loadShares;
    if (AlarmListManager.getInstance().shareLinks == null) {
      initialLoading = true;
      loadShares();
    }
    AlarmListManager.getInstance().reloadAllMethod = () {
      setState(() {});
    };
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    List<Widget> shareEntries = [];
    if (AlarmListManager.getInstance().shareLinks != null) {
      for (OpenShockShareLink shareLink
          in AlarmListManager.getInstance().shareLinks!) {
        shareEntries
            .add(ShareLinkItem(shareLink: shareLink, reloadMethod: loadShares));
      }
    }
    if (shareEntries.isEmpty) {
      shareEntries.add(Center(
          child: Text(AlarmListManager.getInstance().hasValidAccount() ? "No share links created yet" : "You're not logged in",
              style: t.textTheme.headlineSmall)));
    }
    shareEntries.insert(
        0,
        IconButton(
            onPressed: () {
              InfoDialog.show("What are share links?",
                  "Share links are a way to share your shockers with people who do not have an OpenShock account and don't want to create one (or for giving a group access to your shockers). Share links have limits just like normal shares. However people can just use any name they want to access the share link. Their actions will also be shown in the shockers log.");
            },
            icon: Icon(Icons.info)));
    return initialLoading
            ? Center(child: CircularProgressIndicator())
            : DesktopMobileRefreshIndicator(
                onRefresh: loadShares,
                child: ConstrainedContainer(child: ListView(children: shareEntries),));
  }
}

class ShareLinkItem extends StatelessWidget {
  final OpenShockShareLink shareLink;
  final Function reloadMethod;

  const ShareLinkItem(
      {Key? key, required this.shareLink, required this.reloadMethod})
      : super(key: key);

  void showQr(bool shockAlarm, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog.adaptive(
          title: Text('QR Code for ${shareLink.name}'),
          content: QrCard(data: shockAlarm ? shareLink.getShockAlarmLink() : shareLink.getLink()),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('Close'))
          ],
        );
      });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData t = Theme.of(context);
    return PaddedCard(
        child: Row(
      children: [
        Expanded(child: Text(shareLink.name)),
        Row(
          children: [
            IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) {
                        return DeleteDialog(
                            onDelete: () async {
                              LoadingDialog.show("Deleting ${shareLink.name}");
                              String? error =
                                  await AlarmListManager.getInstance()
                                      .deleteShareLink(shareLink);
                              Navigator.of(context).pop();
                              if (error != null) {
                                ErrorDialog.show("Error deleting share link", error);
                                return;
                              }
                              Navigator.of(context).pop();
                              reloadMethod();
                            },
                            title: "Delete ${shareLink.name}",
                            body:
                                "Are you sure you want to delete ${shareLink.name}?");
                      });
                }),
            IconButton(
                onPressed: () {
                  showDialog(context: context, builder: (context) => AlertDialog.adaptive(
                        title: Text('Share Link QR Code'),
                        content: Column(
                          spacing: 10,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton(onPressed: () {
                              showQr(true, context);
                            }, child: Text("For ShockAlarm users")),
                            FilledButton(onPressed: () {
                              showQr(false, context);
                            }, child: Text("Generic OpenShock Link"))
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Close'))
                        ],
                      ));
                  
                },
                icon: Icon(Icons.qr_code)),
            IconButton(
                icon: Icon(Icons.share),
                onPressed: () {
                  Share.share("Control my OpenShock shockers without registration: " + shareLink.getLink());
                }),
            IconButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) {
                    return ShareLinkEditScreen(shareLink: shareLink);
                  }));
                },
                icon: Icon(Icons.edit))
          ],
        )
      ],
    ));
  }
}
