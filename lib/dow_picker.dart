import 'package:flutter/material.dart';
import 'widgets.dart';

class DowPicker extends StatefulWidget {
  final String title;
  final List<bool> ctrl;
  final ValueGetter on_tap;

  const DowPicker(this.title, this.ctrl, this.on_tap, {super.key});

  static init() => [true, true, true, true, true, true, true];

  @override
  DowPickerState createState() => DowPickerState();
}

class DowPickerState extends State<DowPicker> {
  Widget _tile(int index, String title) {
    return CheckboxListTile(
      title: Text(title),
      controlAffinity: ListTileControlAffinity.leading,
      value: widget.ctrl[index],
      onChanged: (state) => setState(() => widget.ctrl[index] = state!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tile(0, DOW_LONG[0]),
          _tile(1, DOW_LONG[1]),
          _tile(2, DOW_LONG[2]),
          _tile(3, DOW_LONG[3]),
          _tile(4, DOW_LONG[4]),
          _tile(5, DOW_LONG[5]),
          _tile(6, DOW_LONG[6]),
        ],
      ),
      actions: [TextButton(
        child: const Text('OK'),
        onPressed: () {
          Navigator.pop(context);
          widget.on_tap();
        },
      )],
    );
  }
}
