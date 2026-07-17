import 'package:flutter/material.dart';
import 'package:covaone_sdk/src/common/textstyles.dart';

Widget AppButton(
        {GlobalKey<FormState>? formKey,
        double height = 57,
        Color? backgroundColor,
        Color? textColor,
        required String text,
        required Function? cta,
        double radius = 4.0}) =>
    Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: height,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            // primary: (backgroundColor == null) ? Colors.blue : backgroundColor,
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 1),
            textStyle:
                kBodyText.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              // side: BorderSide(color: kPrimaryColor, width: hasBorder ? 1 : 0),
            ),
          ),
          onPressed: (cta == null)
              ? null
              : () {
                  // if(preCta != null) preCta();
                  if (formKey != null) {
                    if (formKey.currentState!.validate()) {
                      cta();
                    }
                  } else {
                    cta();
                  }
                },
          // onPressed: () => widget.identityVerify.callKey(),
          child: Text(
            text,
            style: kBodyText.copyWith(color: textColor),
          ),
        ),
      ),
    );
