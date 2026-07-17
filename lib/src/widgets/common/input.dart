import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:covaone_sdk/src/common/textstyles.dart';

// ignore: non_constant_identifier_names
Widget AppInput({
  String? Function(String?)? validator,
  bool canEdit = true,
  List<TextInputFormatter>? formatter,
  AutovalidateMode? validationMode,
  required TextEditingController controller,
  TextInputType? keyboard,
  bool isSecure = false,
  bool show = true,
  TextAlign alignText = TextAlign.start,
  required String placeHolder,
  Widget? icon,
  bool hasMax = false,
  bool focused = false,
  Color? fillColor,
  String? headerLabel,
  // LoginProvider authProvider,
  // Function? whenDone,
  Widget? surfIcon,
  TextInputAction? keyboardAction,
  bool specialText = false,
  TextCapitalization textCapitalization = TextCapitalization.none
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        (headerLabel != null) ? Row(
          children: [
            Flexible(
              child: Text(
                headerLabel,
                style: kBodyText.copyWith(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14),
              ),
            ),
          ],
        ) : Container(),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: TextFormField(
            validator: validator,
            inputFormatters: formatter,
            keyboardType: keyboard,
            textAlign: alignText,
            autofocus: focused,
            enabled: canEdit,
            textInputAction: keyboardAction,
            readOnly: !canEdit,
            textCapitalization: textCapitalization,
            obscureText: !isSecure ? false : true,
            controller: controller,
            style: kBodyText.copyWith(fontSize: 18.5, fontWeight: specialText ? FontWeight.w900 : FontWeight.w600,).copyWith(fontSize: specialText ? 28 : null),
            autovalidateMode: validationMode ?? AutovalidateMode.onUserInteraction,
            // onEditingComplete: whenDone,
            decoration: InputDecoration(
              filled: true,
              fillColor: fillColor ?? Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                // borderSide: const BorderSide(color: kInputBorderColor, width: 0.9),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                // borderSide: const BorderSide(color: kInputBorderColor, width: 0.9),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF01346B), width: 0.9),
              ),
              hintText: placeHolder,
              prefixIcon: icon,
              hintStyle: kBodyText.copyWith(fontSize: 18.5, fontWeight: /* specialText ? FontWeight.w900 : */ FontWeight.w600, color: Color(0xFF656565)).copyWith(fontSize: specialText ? 18 : null),
              contentPadding: const EdgeInsets.fromLTRB(17, 18, 15, 18),
            ),
            maxLines: hasMax ? 5 : 1,
            // minLines: 4,
          ),
        ),
      ],
    ),
  );
}