import 'dart:io';

import 'package:cloudflare_turnstile/cloudflare_turnstile.dart';
import 'package:flutter/material.dart';
import 'package:shock_alarm_app/dialogs/error_dialog.dart';
import 'package:shock_alarm_app/dialogs/loading_dialog.dart';
import 'package:shock_alarm_app/services/alarm_list_manager.dart';
import 'package:shock_alarm_app/services/openshock.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPopup extends StatefulWidget {
    TextEditingController serverController = TextEditingController();
    TextEditingController usernameController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    String? turnstileToken;
    OpenShockBackendInformationData? backendInfo;
    bool useTurnstile = true;
    
      @override
      State<StatefulWidget> createState() => _LoginPopupState();
}

class _LoginPopupState extends State<LoginPopup> {
  bool useTurnstile = false;

  @override
  void initState() {
    widget.serverController.text = "https://api.openshock.app";
    if(AlarmListManager.getInstance().settings.forceLoginV1) widget.useTurnstile = false;
    super.initState();
    reloadBackendData();
  }

  void reloadBackendData() {
    setState(() {
      widget.turnstileToken = null;
      useTurnstile = false;
    });
    OpenShockClient().getOpenShockInstanceInfo(widget.serverController.text).then((res) {
      setState(() {
        if(res.value != null) {
          widget.backendInfo = res.value!;
          useTurnstile = widget.backendInfo!.turnstileSiteKey != null && widget.useTurnstile;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog.adaptive(
            title: Text("Log in to OpenShock"),
            content: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  TextField(
                    decoration: InputDecoration(labelText: "Server"),
                    controller: widget.serverController,
                    onEditingComplete: reloadBackendData,
                  ),
                  AutofillGroup(
                      child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(labelText: "Email"),
                        controller: widget.usernameController,
                        autofillHints: [AutofillHints.email],
                      ),
                      TextField(
                        decoration: InputDecoration(labelText: "Password"),
                        obscureText: true,
                        obscuringCharacter: "*",
                        controller: widget.passwordController,
                        autofillHints: [AutofillHints.password],
                      ),
                      if(widget.backendInfo != null && useTurnstile) CloudflareTurnstile(
                        siteKey: widget.backendInfo!.turnstileSiteKey!, //Change with your site key
                        baseUrl: widget.backendInfo!.frontendUrl,
                        onTokenReceived: (token) {
                          widget.turnstileToken = token;
                        },
                        onTokenExpired: reloadBackendData,
                      ),
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
                  launchUrl(
                      Uri.parse("https://openshock.app/#/account/signup"));
                },
              ),
              TextButton(
                  onPressed: () async {
                    if(widget.turnstileToken == null && useTurnstile) {
                      ErrorDialog.show("Challenge not done", "Make sure to validate via cloudflare turnstile");
                      return;
                    }
                    LoadingDialog.show("Logging in");
                    bool worked = await AlarmListManager.getInstance().login(
                        widget.serverController.text,
                        widget.usernameController.text,
                        widget.passwordController.text,
                        widget.turnstileToken);
                    if (worked) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      AlarmListManager.getInstance().reloadAllMethod!();
                    } else {
                      Navigator.of(context).pop();
                      ErrorDialog.show(
                          "Login failed", "Check server, email and password");
                    }
                  },
                  child: Text("Login"))
            ],
          );
  }
}