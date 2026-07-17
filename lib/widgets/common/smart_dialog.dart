import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class Smart {
  static Future<void> dialog(BuildContext context, {GlobalKey? key, required Widget widget}) {
    return (Platform.isIOS) ?
    showCupertinoModalBottomSheet(
      context: context,
      bounce: false,
      isDismissible: true,
      enableDrag: true,
      duration: const Duration(microseconds: 500),
      topRadius: const Radius.circular(20),
      builder: (context) => widget,
    ) :
    showMaterialModalBottomSheet(
      context: context,
      isDismissible: true,
      bounce: false,
      enableDrag: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      duration: const Duration(microseconds: 500),
      builder: (context) => widget,
    );
  }

  static Future<void> loading(
      BuildContext context,
      {GlobalKey? key, String? label, Duration? duration,}) async {
    return showDialog<void>(
      context: context,
      // for testing, for now this will be true, should be changed to false later
      barrierDismissible: true,
      builder: (BuildContext context) {
        if(duration != null) {
          Future.delayed(duration, () => Navigator.of(context, rootNavigator: true).pop());
        }
        return WillPopScope(
          // for testing, for now this will be true, should be changed to false later
          onWillPop: () async => true,
          child: SimpleDialog(
            key: key ?? const Key('0'),
            elevation: 0.0,
            backgroundColor: Colors.transparent,
            children: <Widget>[
              (Platform.isIOS)
                  ? Center(
                child: Theme(
                  data: ThemeData(
                    cupertinoOverrideTheme:
                    const CupertinoThemeData(brightness: Brightness.dark),
                  ),
                  child: const CupertinoActivityIndicator(
                    radius: 18,
                    animating: true,
                  ),
                ),
              )
                  : const Center(
                child: CircularProgressIndicator(
                  // backgroundColor: kPrimaryColor,
                  strokeWidth: 3.5,
                ),
              ),
              Visibility(
                visible: (label != null),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Text(label ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w200),),
                    )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }


  static Future<void> showBottomDialogs(BuildContext context, {Widget? widget}) {
    return (Platform.isIOS) ?
    showCupertinoModalBottomSheet(
      context: context,
      bounce: true,
      // enableDrag: true,
      duration: Duration(microseconds: 500),
      topRadius: Radius.circular(20),
      builder: (context) => widget!,
    ) :
    showMaterialModalBottomSheet(
      context: context,
      bounce: true,
      // enableDrag: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      duration: Duration(microseconds: 500),
      builder: (context) => widget!,
    );
  }
}