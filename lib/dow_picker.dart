import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'widgets.dart';

class DowPicker extends StatefulWidget {
  final List<bool> ctrl;

  const DowPicker({
    Key? key,
    required this.ctrl,
  }) : super(key: key);

  static init() => [false, false, false, false, false, false, false];

  @override
  _DowPickerState createState() => _DowPickerState();
}

class _DowPickerState extends State<DowPicker> {
  late List<bool> ctrl;

  @override
  void initState() {
    ctrl = widget.ctrl;
    super.initState();
  }

  Widget tile(int index, String title) {
    return CheckboxListTile(
      title: Text(title),
      controlAffinity: ListTileControlAffinity.leading,
      value: ctrl[index],
      onChanged: (state) => setState(() => ctrl[index] = state!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        tile(0, DOW_LONG[0]),
        tile(1, DOW_LONG[1]),
        tile(2, DOW_LONG[2]),
        tile(3, DOW_LONG[3]),
        tile(4, DOW_LONG[4]),
        tile(5, DOW_LONG[5]),
        tile(6, DOW_LONG[6]),
      ],
      mainAxisSize: MainAxisSize.min,
    );
  }
}

void dow_picker_adaptive(BuildContext context, String title, DowPicker dow_picker, ValueGetter on_tap) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      if(Platform.isIOS) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Card(
            child: dow_picker,
            color: Colors.transparent,
            elevation: 0,
          ),
          actions: [CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              on_tap();
            },
          )],
        );
      } else {
        return AlertDialog(
          title: Text(title.toUpperCase(), style: Theme.of(context).textTheme.overline),
          content: dow_picker,
          actions: [TextButton(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              on_tap();
            },
          )],
        );
      }
    }
  );
}
