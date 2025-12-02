import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shock_alarm_app/components/haptic_switch.dart';
import 'package:shock_alarm_app/components/padded_card.dart';
import 'package:shock_alarm_app/components/constrained_container.dart';
import 'package:shock_alarm_app/components/predefined_spacing.dart';
import 'package:shock_alarm_app/components/shock_disclamer.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/info_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/main.dart';
import 'package:shock_alarm_app/screens/settings/confirm_shock_dialog.dart';
import 'package:shock_alarm_app/screens/settings/login_popup.dart';
import 'package:shock_alarm_app/screens/tones/tones.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/alarm_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'token_item.dart';
import '../../stores/alarm_store.dart';
import '../tools/tools.dart';

class SettingsScreen extends StatefulWidget {
  final AlarmListManager manager;

  const SettingsScreen({Key? key, required this.manager}) : super(key: key);

  static Future<bool> AddShareLink(String displayName, String server, String code) async {
    if(displayName.isEmpty) {
      ErrorDialog.show("Error", "Please enter a display name for the share link");
      return false;
    }
    LoadingDialog.show("Adding share link");
    Token t = Token(DateTime.now().millisecondsSinceEpoch, code, server: server, type: TokenType.sharelink);
    t.userId = displayName;
    TokenGetResponseType validity = await OpenShockClient().setInfoOfToken(t);
    if(validity != TokenGetResponseType.success) {
      Navigator.of(navigatorKey.currentContext!).pop();
      ErrorDialog.show("Error", "Invalid code or server: $validity");
      return false;
    }
    AlarmListManager.getInstance().saveToken(t);
    Navigator.of(navigatorKey.currentContext!).pop();
    return true;
  }

  static void extractLink(String value, TextEditingController serverController, TextEditingController codeController) {
    if(value.endsWith("/")) {
        value = value.substring(0, value.length - 1);
      }
      // add "api." before link
      String newLink = "${value.split("://").first}://api.${value.split("://").last}";
      // remove everything after the third /
      newLink = newLink.split("/").sublist(0, 3).join("/");
      String code = value.split("/").last;
      serverController.text = newLink;
      codeController.text = code;
  }

  static Future showShareLinkPopup() async {
    TextEditingController codeController = TextEditingController();
    TextEditingController serverController = TextEditingController();
    TextEditingController linkController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    String clipboardText = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? "";
    if (clipboardText.startsWith("https://") || clipboardText.startsWith("http://")) {
      linkController.text = clipboardText;
      extractLink(clipboardText, serverController, codeController);
    }
    return showDialog(
        context: navigatorKey.currentContext!,
        builder: (BuildContext context) {
          return AlertDialog.adaptive(
            title: Text("Add share link"),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  TextField(
                    decoration: InputDecoration(labelText: "Link"),
                    controller: linkController,
                    onChanged: (value) {
                      extractLink(value, serverController, codeController);
                    },
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: "Api url"),
                    controller: serverController,
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: "Code"),
                    controller: codeController,
                  ),
                  TextField(
                    decoration: InputDecoration(labelText: "Your name"),
                    controller: nameController,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () async {
                    if(await SettingsScreen.AddShareLink(nameController.text, serverController.text, codeController.text)) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text("Add"))
            ],
          );
        });
  }

  @override
  State<StatefulWidget> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void rebuild() {
    setState(() {});
  }

  Future doAlarmServerLogin(
      String server, String username, String password, bool register) async {
    LoadingDialog.show(register ? "Registering" : "Logging in");
    ErrorContainer<Token> worked = await widget.manager
        .alarmServerLogin(server, username, password, register);

    AlarmListManager.getInstance().reloadAllMethod = () {
      setState(() {});
    };
    if (worked.error == null) {
      Navigator.of(context).pop();
      Navigator.of(context).pop();
      AlarmListManager.getInstance().reloadAllMethod!();
    } else {
      Navigator.of(context).pop();
      ErrorDialog.show("Login failed", worked.error!);
      return;
    }

    ErrorContainer<Token> populatedToken =
        await AlarmServerClient().populateTokenForAccount(worked.value);
    if (populatedToken.error != null || populatedToken.value == null) {
      ErrorDialog.show("Login failed", populatedToken.error!);
      return;
    }
    if (populatedToken.value?.userId != "") {
      // We already have a token, just save it
      AlarmListManager.getInstance()
          .saveAlarmServerToken(populatedToken.value!);
      AlarmListManager.getInstance().reloadAllMethod!();
      AlarmListManager.getInstance().pageSelectorReloadMethod!();
      showDialog(
          context: context,
          builder: (context) => AlertDialog.adaptive(
                title: Text("Success"),
                content: Text(
                    "You are now logged in to the AlarmServer (ShockAlarmWeb). An OpenShock token has already been found on your AlarmServer account. It has therefor been choosen.\n\nIf you wish to choose another token, visit the AlarmServer website, delete all tokens and add only the one you want."),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text("Ok"))
                ],
              ));
      return;
    }
    Token? OpenShockToken =
        await AlarmListManager.getInstance().getSpecificUserToken();
    if (OpenShockToken == null) {
      ErrorDialog.show("Login failed",
          "No OpenShock token found. Please log in to OpenShock first.");
      AlarmListManager.getInstance()
          .deleteAlarmServerToken(populatedToken.value!);
      return;
    }
    if (OpenShockToken.type == TokenType.session) {
      // Ask whether to create a new token
      showDialog(
          context: context,
          builder: (context) => AlertDialog.adaptive(
                title: Text("No token found"),
                content: Text(
                    "You are logged in to OpenShock, but no token was found on your AlarmServer account. Do you want to create a new OpenShock api token for your AlarmServer account? By default the api token will be valid forever. If you do not want to create a token, you can add one manually on the AlarmServer website and then log in here."),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        AlarmListManager.getInstance()
                            .deleteAlarmServerToken(populatedToken.value!);
                      },
                      child: Text("No")),
                  TextButton(
                      onPressed: () async {
                        LoadingDialog.show("Adding token to account");
                        ErrorContainer<String> apiToken =
                            await OpenShockClient().createApiToken(
                                OpenShockToken,
                                OpenShockApiToken(
                                    "ShockAlarm-AlarmServer-${Uri.parse(server).host}",
                                    ["shockers.use"],
                                    null));

                        if (apiToken.error != null) {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                          ErrorDialog.show(
                              "Failed to create api token, you have been logged out of the AlarmServer",
                              apiToken.error!);
                          AlarmListManager.getInstance()
                              .deleteAlarmServerToken(populatedToken.value!);
                          return;
                        }
                        ErrorContainer<Token> t = await AlarmServerClient()
                            .addOpenShockTokenToAccount(
                                worked.value,
                                Token(DateTime.now().microsecondsSinceEpoch,
                                    apiToken.value!,
                                    server: OpenShockToken.server));
                        Navigator.of(context).pop();
                        if (t.error != null) {
                          Navigator.of(context).pop();
                          ErrorDialog.show(
                              "Failed to add token, you have been logged out of the AlarmServer",
                              t.error!);
                          AlarmListManager.getInstance()
                              .deleteAlarmServerToken(populatedToken.value!);
                          return;
                        }
                        AlarmListManager.getInstance()
                            .saveAlarmServerToken(t.value!);
                        Navigator.of(context).pop();
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog.adaptive(
                                  title: Text("Success"),
                                  content: Text(
                                      "Token added to account. You can now create alarms."),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          AlarmListManager.getInstance()
                                              .reloadAllMethod!();
                                          AlarmListManager.getInstance()
                                              .pageSelectorReloadMethod!();
                                        },
                                        child: Text("Ok"))
                                  ],
                                ));
                      },
                      child: Text("Yes")),
                ],
              ));
    } else {
      // Ask whether to use the token
      showDialog(
          context: context,
          builder: (context) => AlertDialog.adaptive(
                title: Text("Use OpenShock token?"),
                content: Text(
                    "You are logged in to OpenShock. Do you want to use the token found on your OpenShock account to log in to the AlarmServer (ShockAlarmWeb)?\n\nIf you choose no, your account will be removed from ShockAlarm. Add a token on the AlarmServer website manually and then log in again.\n\nIf you choose yes, your token will be transmitted to the AlarmServer and will be stored on your account there. It will then be able to trigger the alarms."),
                actions: [
                  TextButton(
                      onPressed: () async {
                        LoadingDialog.show("Adding token to account");
                        ErrorContainer<Token> t = await AlarmServerClient()
                            .addOpenShockTokenToAccount(
                                worked.value, OpenShockToken);
                        Navigator.of(context).pop();
                        if (t.error != null) {
                          ErrorDialog.show("Failed to add token", t.error!);
                          AlarmListManager.getInstance()
                              .deleteAlarmServerToken(populatedToken.value!);
                          return;
                        }
                        AlarmListManager.getInstance()
                            .saveAlarmServerToken(t.value!);
                        Navigator.of(context).pop();
                        showDialog(
                            context: context,
                            builder: (context) => AlertDialog.adaptive(
                                  title: Text("Success"),
                                  content: Text(
                                      "Token added to account. You can now create alarms."),
                                  actions: [
                                    TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          AlarmListManager.getInstance()
                                              .reloadAllMethod!();

                                          AlarmListManager.getInstance()
                                              .pageSelectorReloadMethod!();
                                        },
                                        child: Text("Ok"))
                                  ],
                                ));
                      },
                      child: Text("Yes")),
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        AlarmListManager.getInstance()
                            .deleteAlarmServerToken(populatedToken.value!);
                      },
                      child: Text("No"))
                ],
              ));
    }
  }

  @override
  void initState() {
    widget.manager.reloadAllMethod = rebuild;
    super.initState();
  }

  Future showAlarmServerTokenLoginPopup() async {
    TextEditingController serverController = TextEditingController();
    TextEditingController usernameController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    serverController.text = "https://dev1.rui2015.me";
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog.adaptive(
            title: Text("Login to ShockAlarmWeb"),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  TextField(
                    decoration: InputDecoration(labelText: "Server"),
                    controller: serverController,
                  ),
                  AutofillGroup(
                      child: Column(
                    children: [
                      TextField(
                          decoration: InputDecoration(labelText: "Username"),
                          autofillHints: [AutofillHints.username],
                          controller: usernameController),
                      TextField(
                          decoration: InputDecoration(labelText: "Password"),
                          autofillHints: [AutofillHints.password],
                          obscureText: true,
                          obscuringCharacter: "*",
                          controller: passwordController)
                    ],
                  ))
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel")),
              TextButton(
                child: Text("Register"),
                onPressed: () {
                  doAlarmServerLogin(serverController.text,
                      usernameController.text, passwordController.text, true);
                },
              ),
              TextButton(
                  onPressed: () async {
                    doAlarmServerLogin(
                        serverController.text,
                        usernameController.text,
                        passwordController.text,
                        false);
                  },
                  child: Text("Login"))
            ],
          );
        });
  }

  Future showTokenLoginPopupRedirect() async {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog.adaptive(
            title: Text("Log in to OpenShock"),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  FilledButton(
                    child: Text("Log in via openshock.app"),
                    onPressed: () => {
                      launchUrl(Uri.parse(
                          "https://openshock.app/t/?name=ShockAlarm&redirect_uri=${Uri.encodeComponent(Uri.base.toString())}${Uri.encodeComponent("?server=https://api.openshock.app&token=%")}&permissions=${availableApiTokenPermissions.join(",")}"))
                    },
                  ),
                  PredefinedSpacing(),
                  Text(
                      "Not working or want to choose another server? Try manual login below.",
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel")),
              TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    showTokenLoginPopup();
                  },
                  child: Text("Manual login"))
            ],
          );
        });
  }

  Future showTokenLoginPopup() async {
    TextEditingController serverController = TextEditingController();
    TextEditingController tokenController = TextEditingController();
    serverController.text = "https://api.openshock.app";
    GestureRecognizer recognizer = TapGestureRecognizer()
      ..onTap = () {
        launchUrl(Uri.parse("https://next.openshock.app/settings/api-tokens"));
      };
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog.adaptive(
            title: Text("Log in to OpenShock"),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  DefaultTextStyle(
                      style: Theme.of(context).textTheme.bodyMedium!,
                      child: SelectableText.rich(TextSpan(children: [
                        TextSpan(
                            text:
                                "As you are using a browser, you must use a token to sign in. To get one visit "),
                        TextSpan(
                            text:
                                "https://next.openshock.app/settings/api-tokens",
                            recognizer: recognizer,
                            style: TextStyle(
                                color: Theme.of(context).hintColor,
                                decoration: TextDecoration.underline),
                            mouseCursor: SystemMouseCursors.click),
                        TextSpan(
                            text:
                                " and generate a token with all permissions. Then paste it here.")
                      ]))),
                  TextField(
                    decoration: InputDecoration(labelText: "Server"),
                    controller: serverController,
                  ),
                  AutofillGroup(
                      child: Column(
                    children: [
                      TextField(
                          decoration: InputDecoration(labelText: "Token"),
                          obscureText: true,
                          obscuringCharacter: "*",
                          controller: tokenController)
                    ],
                  )),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel")),
              TextButton(
                child: Text("Register"),
                onPressed: () {
                  launchUrl(
                      Uri.parse("https://openshock.app/#/account/signup"));
                },
              ),
              TextButton(
                  onPressed: () async {
                    LoadingDialog.show("Logging in");
                    TokenGetResponseType worked = await widget.manager
                        .loginToken(
                            serverController.text, tokenController.text);
                    if (worked == TokenGetResponseType.success) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      AlarmListManager.getInstance().reloadAllMethod!();
                    } else if (worked ==
                        TokenGetResponseType.serverUnreachable) {
                      Navigator.of(context).pop();
                      ErrorDialog.show("Login failed",
                          "The server could not be reached or another networking error occurred. Check the server url and your internet connectin!");
                    } else {
                      Navigator.of(context).pop();
                      ErrorDialog.show(
                          "Login failed", "Check server, email and password");
                    }
                  },
                  child: Text("Login"))
            ],
          );
        });
  }

  Future showLoginPopup() async {
    String? turnstileToken;
    return showDialog(
        context: context,
        builder: (context) =>LoginPopup());
  }

  

  @override
  Widget build(BuildContext context) {
    AlarmListManager.getInstance().reloadAllMethod = () {
      navigatorKey.currentState?.setState(() {
        // ignore: invalid_use_of_protected_member
      });
    };
    ThemeData t = Theme.of(context);
    return ConstrainedContainer(
        child: ListView(
      children: <Widget>[
        Column(
          children: [
            Text(
              'Settings',
              style: t.textTheme.headlineMedium,
            ),
            for (var token in widget.manager.getTokens())
              TokenItem(
                  token: token,
                  manager: widget.manager,
                  onRebuild: rebuild,
                  key: ValueKey(token.id)),
            if (widget.manager.getTokens().isEmpty)
              PaddedCard(
                child: Text(
                    "You are not logged in to OpenShock, log in to access your devices",
                    style: t.textTheme.headlineSmall),
              ),
          ],
        ),

        if (AlarmListManager.getInstance().settings.useAlarmServer) ...[
          Column(
            children: [
              for (var token in widget.manager.getAlarmServerTokens())
                TokenItem(
                    token: token,
                    manager: widget.manager,
                    onRebuild: rebuild,
                    key: ValueKey(token.id)),
              if (widget.manager.getAlarmServerTokens().isEmpty)
                PaddedCard(
                  child: Text(
                      "You are not logged into an AlarmServer. Log in to one to schedule alarms on Web and Linux and when your phone is off.",
                      textAlign: TextAlign.center,
                      style: t.textTheme.bodyLarge),
                ),
            ],
          ),
        ],
        PredefinedSpacing(),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          children: [
            if (widget.manager
                    .getTokens()
                    .where((x) => !x.invalidSession && x.type != TokenType.sharelink)
                    .isEmpty ||
                widget.manager.settings.allowMultiServerLogin)
              FilledButton(
                onPressed: () async {
                  await showDialog(
                      context: context,
                      builder: (context) => ShockDisclaimer());
                  AlarmListManager.getInstance().reloadAllMethod = () {
                    setState(() {});
                  };
                  if (kIsWeb) {
                    showTokenLoginPopupRedirect();
                  } else {
                    showLoginPopup();
                  }
                },
                child: Text("Log in to OpenShock",
                    style:
                        TextStyle(fontSize: t.textTheme.titleMedium!.fontSize)),
              ),
              if(AlarmListManager.supportsWs()) FilledButton(
                onPressed: () async {
                  await showDialog(
                      context: context,
                      builder: (context) => ShockDisclaimer());
                  AlarmListManager.getInstance().reloadAllMethod = () {
                    setState(() {});
                  };
                  SettingsScreen.showShareLinkPopup();
                },
                child: Text("Add share link",
                    style:
                        TextStyle(fontSize: t.textTheme.titleMedium!.fontSize)),
              ),
            if (widget.manager.getAlarmServerTokens().isEmpty &&
                widget.manager.settings.useAlarmServer)
              FilledButton(
                onPressed: () async {
                  showAlarmServerTokenLoginPopup();
                },
                child: Text("Log in to AlarmServer",
                    style:
                        TextStyle(fontSize: t.textTheme.titleMedium!.fontSize)),
              ),
          ],
        ),

        PredefinedSpacing(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Theme"),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 0, label: Icon(Icons.devices)),
                ButtonSegment(value: 1, label: Icon(Icons.sunny)),
                ButtonSegment(value: 2, label: Icon(Icons.nightlight)), 
              ],
              selected: {
                switch (
                    context.findAncestorStateOfType<MyAppState>()?.themeMode) {
                  null => throw UnimplementedError(), // should never be null ig
                  ThemeMode.system => 0,
                  ThemeMode.light => 1,
                  ThemeMode.dark => 2,
                }
              },
              onSelectionChanged: (Set<int> newSelection) {
                if (newSelection.isNotEmpty) {
                  switch (newSelection.first) {
                    case 0:
                      context
                          .findAncestorStateOfType<MyAppState>()
                          ?.setThemeMode(ThemeMode.system);
                      break;
                    case 1:
                      context
                          .findAncestorStateOfType<MyAppState>()
                          ?.setThemeMode(ThemeMode.light);
                      break;
                    case 2:
                      context
                          .findAncestorStateOfType<MyAppState>()
                          ?.setThemeMode(ThemeMode.dark);
                      break;
                  }
                  setState(() {});
                }
              },
            )
          ],
        ),
        // Actual options
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Show option for random delay"),
            HapticSwitch(
                value: widget.manager.settings.showRandomDelay,
                key: ValueKey("showRandomDelay"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.showRandomDelay = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Use grouped shocker controlling"),
            HapticSwitch(
                value: widget.manager.settings.useGroupedShockerSelection,
                key: ValueKey("useGroupedShockerSelection"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.useGroupedShockerSelection = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Use range slider for random delay"),
            HapticSwitch(
                value: widget.manager.settings.useRangeSliderForRandomDelay,
                key: ValueKey("useRangeSliderForRandomDelay"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.useRangeSliderForRandomDelay =
                        value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Use range slider for intensity"),
            HapticSwitch(
                value: widget.manager.settings.useRangeSliderForIntensity,
                key: ValueKey("useRangeSliderForIntensity"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.useRangeSliderForIntensity = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Use range slider for duration"),
            HapticSwitch(
                value: widget.manager.settings.useRangeSliderForDuration,
                key: ValueKey("useRangeSliderForDuration"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.useRangeSliderForDuration = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("Confirm/Limit Shock"),
                IconButton(onPressed: () {
                  showDialog(context: context, builder: (context) => ConfirmShockDialog());
                }, icon: Icon(Icons.edit)),
                IconButton(
                    onPressed: () {
                      InfoDialog.show("Confirm Shock",
                          "When you press the shock button you will have to confirm the action in a dialog before the shock gets sent. You can change under which condition the confirm dialog appears.");
                    },
                    icon: Icon(Icons.info))
              ],
            ),
            HapticSwitch(
                value: widget.manager.settings.confirmShock,
                key: ValueKey("confirmShock"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.confirmShock = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Allow choosing tones for controls"),
            HapticSwitch(
                value: widget.manager.settings.allowTonesForControls,
                key: ValueKey("allowTonesForControls"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.allowTonesForControls = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Seperate slider for vibrate and shock intensity"),
            HapticSwitch(
                value: widget.manager.settings.useSeperateSliders,
                key: ValueKey("useSeperateSliders"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.useSeperateSliders = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("Lerp intensity"),
                IconButton(
                    onPressed: () {
                      InfoDialog.show("What is this?",
                          "Lerping the intensity means you'll always be prompted to choose the intensity from 0 - 100, no matter the limit on the shocker. It'll then be mapped based on the actual limit of each shocker.\n\nExample: Limit of 50, input of 100 -> 50% intensity\nLimit of 50, input of 50 -> 25% intensity");
                    },
                    icon: Icon(Icons.info))
              ],
            ),
            HapticSwitch(
                value: widget.manager.settings.lerpIntensity,
                key: ValueKey("lerpIntensity"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.lerpIntensity = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Send logs for live control (workaround)"),
            HapticSwitch(
                value: widget.manager.settings.liveControlsLogWorkaround,
                key: ValueKey("liveControlsLogWorkaround"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.liveControlsLogWorkaround = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("Allow login to multiple servers"),
                IconButton(
                    onPressed: () {
                      InfoDialog.show("Why?",
                          "OpenShock can be self hosted meaning multiple instances are available. You can use ShockAlarm to interact with all instances you want at once to easily control your friends shockers. Even if they are on a different instance from yours.");
                    },
                    icon: Icon(Icons.info))
              ],
            ),
            HapticSwitch(
                value: widget.manager.settings.allowMultiServerLogin,
                key: ValueKey("allowMultiServerLogin"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.allowMultiServerLogin = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("Use AlarmServer for alarms"),
                IconButton(
                    onPressed: () {
                      InfoDialog.show("What is a Alarm Server?",
                          "An Alarm Server is an Open Source server which allows for scheduling of alarms. These alarms can be edited via this app but are then stored on the server. Your alarms will be tied to a user account of your choice which you will have to create.\n\nIn order for the Alarm Server to be able to send alarms (control your shockers) it also needs access to your OpenShock account. This is done via Api Tokens. You can therefore revoke access to your OpenShock account by simply deleting the Api token at any time.\n\n\nThis feature was added so ShockAlarm users can also create alarms which will be triggered even when their device is off. On Android this feature is not needed as alarms work on device as long as you use the app.");
                    },
                    icon: Icon(Icons.info))
              ],
            ),
            HapticSwitch(
                value: widget.manager.settings.useAlarmServer,
                key: ValueKey("useAlarmServer"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.useAlarmServer = value;
                    widget.manager.saveSettings();
                    widget.manager.setAlarmImplementation();
                    widget.manager.pageSelectorReloadMethod!();
                  });
                })
          ],
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("Increase maximum duration"),
                IconButton(
                    onPressed: () {
                      InfoDialog.show("What?",
                          "OpenShock has a maximum duration of 65536ms (65.536 seconds) per action. This is the maximum duration you can set as limit or do actions for a shocker. If you enable this option, you will be able to set the maximum duration to 65536ms instead of the recommended 30000ms (30 seconds). It is disabled by default as it makes fiddling with the sliders harder");
                    },
                    icon: Icon(Icons.info))
              ],
            ),
            HapticSwitch(
                value: widget.manager.settings.increaseMaxDuration,
                key: ValueKey("increaseMaxDuration"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.increaseMaxDuration = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Enable ui haptic feedback"),
            HapticSwitch(
                value: widget.manager.settings.enableUiVibrations,
                key: ValueKey("enableUiVibrations"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.enableUiVibrations = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Show hub firmware version"),
            HapticSwitch(
                value: widget.manager.settings.showFirmwareVersion,
                key: ValueKey("showFirmwareVersion"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.showFirmwareVersion = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Disable hub filtering"),
            HapticSwitch(
                value: widget.manager.settings.disableHubFiltering,
                key: ValueKey("disableHubFiltering"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.disableHubFiltering = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text("Login without cloudflare"),
                IconButton(
                    onPressed: () {
                      InfoDialog.show("What does this mean?",
                          "ShockAlarm uses the V2 login api of OpenShock by default which requires cloudflare turnstile to be embedded for bot detection. By activating this you can switch back to the V1 login api which does not require this but may not be available on all OpenShock instances.");
                    },
                    icon: Icon(Icons.info))
              ],
            ),
            HapticSwitch(
                value: widget.manager.settings.forceLoginV1,
                key: ValueKey("forceLoginV1"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.forceLoginV1 = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Use http instead of ws for shocking"),
            HapticSwitch(
                value: widget.manager.settings.useHttpShocking,
                key: ValueKey("useHttpShocking"),
                onChanged: (value) {
                  setState(() {
                    widget.manager.settings.useHttpShocking = value;
                    widget.manager.saveSettings();
                  });
                })
          ],
        ),
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10,
            children: [
              FilledButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => ToolsScreen()));
                  },
                  child: Text("More tools")),
              if (widget.manager.settings.allowTonesForControls)
                FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) =>
                              AlarmToneScreen(widget.manager)));
                    },
                    child: Text("Edit Tones"))
            ]),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) => AlertDialog.adaptive(
                              title: Text("About"),
                              content: Text(
                                  "This app is made by ComputerElite. It is fully open source and can be found on GitHub. If you have any issues, report them there. Thank you so much for using my app! See safety rules in the safety section for more information."),
                              actions: [
                                TextButton(
                                    onPressed: () {
                                      launchUrl(Uri.parse(issues_url));
                                    },
                                    child: Text("Report issue")),
                                TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    child: Text("Ok"))
                              ]));
                },
                child: Text("About")),
            TextButton(
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (context) => ShockDisclaimer());
                },
                child: Text("Safety")),
          ],
        )
      ],
    ));
  }
}
