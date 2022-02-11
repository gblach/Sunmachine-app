import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const List<String> ROUTINE = [ 'Mode', 'Brightness', 'Hue', 'Saturation', 'Temperature' ];
const List<String> MODE = [ 'Off', 'On', 'Sleep', 'Auto' ];
const List<String> DOW_LONG = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
];
const List<String> DOW_SHORT = [ 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' ];

ThemeData app_theme(Brightness brightness) {
  final bool is_light = brightness == Brightness.light;

  final scheme = ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: const Color(0xff2962ff),
  ).copyWith(
    primary: is_light ? const Color(0xff2962ff) : null,
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    useMaterial3: true,
    toggleableActiveColor: scheme.primary,
    dividerColor: is_light ? Colors.grey[400] : null,
    scaffoldBackgroundColor: is_light ? Colors.grey[200] : null,
    iconTheme: const IconThemeData(color: Colors.grey),
    inputDecorationTheme: const InputDecorationTheme(isDense: true),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Colors.grey,
      selectionHandleColor: scheme.primaryContainer,
    ),
  );
}

Widget loader(String title, [String? subtitle]) {
  return Center(child: Card(
    child: Padding(
      child: ListTile(
        leading: Platform.isIOS
          ? const CupertinoActivityIndicator(radius: 20)
          : const CircularProgressIndicator(),
        title: Text(title),
        subtitle: Text(subtitle ?? 'Wait a while'),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
    margin: const EdgeInsets.only(bottom: 80),
    shape: const RoundedRectangleBorder(),
  ));
}

Widget card_unified({
  required Widget child,
  double top=12,
  double bottom=12,
  double left=16,
  double right=16,
  bool transparent=false,
}) {
  final Padding inner_card = Padding(
    child: child,
    padding: EdgeInsets.only(top: top, bottom: bottom, left: left, right: right),
  );

  if(! transparent) {
    return Card(
      child: inner_card,
      margin: const EdgeInsets.all(8),
    );
  } else {
    return Card(
      child: inner_card,
      color: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.all(8),
    );
  }
}

Widget card_unified_nopad({required Widget child, bool transparent=false}) {
  return card_unified(child: child, top: 0, bottom: 0, left: 0, right: 0, transparent: transparent);
}

Widget icon_adaptive(IconData material_icon, IconData cupertino_icon, {Color? color}) {
  return Icon(Platform.isIOS ? cupertino_icon : material_icon, color: color);
}

Widget text_field_adaptive({
  required BuildContext context,
  required TextEditingController controller,
  int? max_length,
  int max_lines=1,
  bool enabled=true,
  bool autofocus=false,
  bool obscure_text=false,
  bool numpad=false,
  required ValueChanged<String> on_submitted,
}) {
  if(Platform.isIOS) {
    final bool is_dark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoTextField(
      controller: controller,
      maxLength: max_length,
      maxLines: max_lines,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscure_text,
      keyboardType: numpad ? TextInputType.number : null,
      style: is_dark ? const TextStyle(color: Colors.white) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onSubmitted: on_submitted,
    );
  } else {
    return TextField(
      controller: controller,
      maxLength: max_length,
      maxLines: max_lines,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscure_text,
      keyboardType: numpad ? TextInputType.number : null,
      onSubmitted: on_submitted,
    );
  }
}

void time_picker_adaptive(BuildContext context, TimeOfDay initial, ValueChanged<TimeOfDay> on_changed) async {
  if(Platform.isIOS) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          child: CupertinoTimerPicker(
            initialTimerDuration: Duration(hours: initial.hour, minutes: initial.minute),
            mode: CupertinoTimerPickerMode.hm,
            onTimerDurationChanged: (Duration timer) {
              on_changed(TimeOfDay(hour: timer.inHours, minute: timer.inMinutes % 60));
            },
          ),
          height: MediaQuery.of(context).copyWith().size.height / 3,
        );
      }
    );
    on_changed(initial);
  } else {
    TimeOfDay? time = await showTimePicker(context: context, initialTime: initial);
    if(time != null) on_changed(time);
  }
}

Widget big_button_adaptive(BuildContext context, String label, IconData icon, ValueGetter? on_tap) {
  if(Platform.isIOS) {
    return CupertinoButton(
      child: Text(label),
      minSize: 48,
      onPressed: on_tap,
    );
  } else {
    return Padding(
      child: ElevatedButton.icon(
        label: Text(label),
        icon: Icon(icon),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: on_tap,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

void bottom_sheet_adaptive(BuildContext context, List<Map> values, ValueSetter on_tap) {
  if(Platform.isIOS) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          actions: List.generate(values.length, (int index) {
            return CupertinoActionSheetAction(
              child: values[index]['label'] is String
                ? Text(values[index]['label'])
                : values[index]['label'],
              onPressed: () {
                Navigator.pop(context);
                on_tap(values[index]['value']);
              },
            );
          }),
          cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        );
      }
    );
  } else {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return ListView.builder(
          itemCount: values.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: values[index]['label'] is String
                ? Text(values[index]['label'])
                : values[index]['label'],
              onTap: () {
                Navigator.pop(context);
                on_tap(values[index]['value']);
              },
            );
          },
        );
      }
    );
  }
}

Widget _gradient(List<Color> colors) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors),
      borderRadius: const BorderRadius.all(Radius.circular(4)),
    ),
    height: 8,
    margin: const EdgeInsets.symmetric(horizontal: 24),
  );
}

Widget gradient_hue() {
  return _gradient([
    const HSVColor.fromAHSV(1, 0, 1, 1).toColor(),
    const HSVColor.fromAHSV(1, 60, 1, 1).toColor(),
    const HSVColor.fromAHSV(1, 120, 1, 1).toColor(),
    const HSVColor.fromAHSV(1, 180, 1, 1).toColor(),
    const HSVColor.fromAHSV(1, 240, 1, 1).toColor(),
    const HSVColor.fromAHSV(1, 300, 1, 1).toColor(),
    const HSVColor.fromAHSV(1, 360, 1, 1).toColor(),
  ]);
}

Widget gradient_saturation(int hue) {
  return _gradient([
    HSVColor.fromAHSV(1, hue.toDouble(), 0.0, 1).toColor(),
    HSVColor.fromAHSV(1, hue.toDouble(), 0.1, 1).toColor(),
    HSVColor.fromAHSV(1, hue.toDouble(), 1.0, 1).toColor(),
  ]);
}

Widget gradient_temperature() {
  return _gradient([
    const HSVColor.fromAHSV(1, 210, 0.3, 1).toColor(),
    const HSVColor.fromAHSV(1, 0, 0.0, 0.98).toColor(),
    const HSVColor.fromAHSV(1, 60, 0.3, 1).toColor(),
    const HSVColor.fromAHSV(1, 55, 0.7, 1).toColor(),
    const HSVColor.fromAHSV(1, 30, 1, 1).toColor(),
  ]);
}

int hue_to_temp(int hue) {
  double temp = (hue - 240).toDouble();
  if(temp < 0) temp *= -25;
  else temp /= -0.12;
  temp += 3000;
  return temp.round();
}
