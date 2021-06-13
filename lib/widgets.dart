import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const List<String> ROUTINE = [ 'Mode', 'Brightness', 'Hue', 'Saturation', 'Temperature' ];
const List<String> MODE = [ 'Off', 'On', 'Sleep', 'Auto' ];
const List<String> DOW_LONG = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturnday'
];
const List<String> DOW_SHORT = [ 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' ];

ThemeData app_theme() {
  return ThemeData(
    brightness: Brightness.light,
    primarySwatch: MaterialColor(0xff2962ff, {
      50: Color(0xff8aa9ff),
      100: Color(0xff7fa1ff),
      200: Color(0xff6991ff),
      300: Color(0xff5481ff),
      400: Color(0xff3e72ff),
      500: Color(0xff2962ff),
      600: Color(0xff2558e6),
      700: Color(0xff214ecc),
      800: Color(0xff1d45b3),
      900: Color(0xff193b99),
    }),
    primaryColor: Color(0xff2962ff),
    accentColor: Color(0xff2962ff),
    dividerColor: Colors.grey[400],
    toggleableActiveColor: Color(0xff2962ff),
    unselectedWidgetColor: Colors.grey[600],
    scaffoldBackgroundColor: Colors.grey[200],
    textTheme: TextTheme(
      bodyText2: TextStyle(color: Colors.grey[800]),
      subtitle1: TextStyle(color: Colors.grey[800]),
      caption: TextStyle(color: Colors.grey[600]),
      overline: TextStyle(color: Colors.grey[400]),
      button: TextStyle(color: Colors.white),
    ),
    iconTheme: IconThemeData(color: Colors.grey),
    cardTheme: CardTheme(color: Colors.white),
    cursorColor: Color(0xff2962ff),
    hintColor: Colors.grey[600],
    textSelectionColor: Color(0xff2962ff),
    textSelectionHandleColor: Color(0xff2962ff),
    inputDecorationTheme: InputDecorationTheme(isDense: true),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(primary: Color(0xff2962ff)),
    ),
    buttonBarTheme: ButtonBarThemeData(
      buttonTextTheme: ButtonTextTheme.accent,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Color(0xff2962ff),
      inactiveTrackColor: Colors.grey[350],
      thumbColor: Color(0xff2962ff),
    ),
    dialogTheme: DialogTheme(
      titleTextStyle: TextStyle(
        fontSize: 16,
        color: Colors.grey[850],
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: Colors.white,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white,
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: Brightness.light,
    ),
  );
}

Widget loader(String title, [String? subtitle]) {
  return Center(child: Card(
    child: Padding(
      child: ListTile(
        leading: Platform.isIOS
          ? CupertinoActivityIndicator(radius: 20)
          : CircularProgressIndicator(),
        title: Text(title),
        subtitle: Text(subtitle ?? 'Wait a while'),
      ),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    ),
    margin: EdgeInsets.only(bottom: 80),
    shape: RoundedRectangleBorder(),
  ));
}

Widget card_unified({
  required Widget child,
  double top=12,
  double bottom=12,
  double left=16,
  double right=16,
  bool transarent=false,
}) {
  final Padding inner_card = Padding(
    child: child,
    padding: EdgeInsets.only(top: top, bottom: bottom, left: left, right: right),
  );

  if(! transarent) {
    return Card(
      child: inner_card,
      margin: EdgeInsets.all(8),
    );
  } else {
    return Card(
      child: inner_card,
      color: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.all(8),
    );
  }
}

Widget card_unified_nopad({required Widget child, bool transarent=false}) {
  return card_unified(child: child, top: 0, bottom: 0, left: 0, right: 0, transarent: transarent);
}

Widget icon_adaptive(IconData material_icon, IconData cupertino_icon, {Color? color}) {
  return Icon(Platform.isIOS ? cupertino_icon : material_icon, color: color);
}

Widget text_field_adaptive({
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
    return CupertinoTextField(
      controller: controller,
      maxLength: max_length,
      maxLines: max_lines,
      enabled: enabled,
      autofocus: autofocus,
      obscureText: obscure_text,
      keyboardType: numpad ? TextInputType.number : null,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        return Container(
          child: CupertinoTimerPicker(
            initialTimerDuration: initial != null
              ? Duration(hours: initial.hour, minutes: initial.minute)
              : Duration.zero,
            mode: CupertinoTimerPickerMode.hm,
            onTimerDurationChanged: (Duration timer) {
              if(on_changed != null) on_changed(TimeOfDay(hour: timer.inHours, minute: timer.inMinutes % 60));
            },
            backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
          ),
          height: MediaQuery.of(context).copyWith().size.height / 3,
        );
      }
    );
    if(on_changed != null) on_changed(initial);
  } else {
    TimeOfDay? time = await showTimePicker(context: context, initialTime: initial);
    if(on_changed != null && time != null) on_changed(time);
  }
}

Widget big_button_adaptive(BuildContext context, String label, IconData icon, ValueGetter? on_tap) {
  if(Platform.isIOS) {
    return CupertinoButton(
      child: Text(label),
      color: Theme.of(context).accentColor,
      disabledColor: Theme.of(context).disabledColor,
      minSize: 48,
      onPressed: on_tap,
    );
  } else {
    return Padding(
      child: ElevatedButton.icon(
        label: Text(label),
        icon: Icon(icon),
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 56),
          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: on_tap,
      ),
      padding: EdgeInsets.symmetric(horizontal: 8),
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
            child: Text('Cancel'),
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
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
    height: 8,
    margin: EdgeInsets.symmetric(horizontal: 24),
  );
}

Widget gradient_hue() {
  return _gradient([
    HSVColor.fromAHSV(1, 0, 1, 1).toColor(),
    HSVColor.fromAHSV(1, 60, 1, 1).toColor(),
    HSVColor.fromAHSV(1, 120, 1, 1).toColor(),
    HSVColor.fromAHSV(1, 180, 1, 1).toColor(),
    HSVColor.fromAHSV(1, 240, 1, 1).toColor(),
    HSVColor.fromAHSV(1, 300, 1, 1).toColor(),
    HSVColor.fromAHSV(1, 360, 1, 1).toColor(),
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
    HSVColor.fromAHSV(1, 210, 0.3, 1).toColor(),
    HSVColor.fromAHSV(1, 0, 0.0, 0.98).toColor(),
    HSVColor.fromAHSV(1, 60, 0.3, 1).toColor(),
    HSVColor.fromAHSV(1, 55, 0.7, 1).toColor(),
    HSVColor.fromAHSV(1, 30, 1, 1).toColor(),
  ]);
}

int hue_to_temp(int hue) {
  double temp = (hue - 240).toDouble();
  if(temp < 0) temp *= -25;
  else temp /= -0.12;
  temp += 3000;
  return temp.round();
}
