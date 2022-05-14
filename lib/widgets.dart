import 'package:flutter/material.dart';

const List<String> ROUTINE = [ 'Mode', 'Brightness', 'Hue', 'Saturation', 'Temperature' ];
const List<String> MODE = [ 'Off', 'On', 'Sleep', 'Auto' ];
const List<String> DOW_LONG = [
  'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
];
const List<String> DOW_SHORT = [ 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' ];

enum GradientType { hue, saturation, temperature }

ThemeData app_theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    brightness: brightness,
    seedColor: const Color(0xff2962ff),
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    useMaterial3: true,
    toggleableActiveColor: scheme.primary,
    scaffoldBackgroundColor: scheme.background,
  );
}

class Loader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const Loader(this.title, this.subtitle, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(child: Card(
      margin: const EdgeInsets.only(bottom: 80),
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: ListTile(
          leading: const CircularProgressIndicator(),
          title: Text(title),
          subtitle: Text(subtitle ?? 'Wait a while'),
        ),
      ),
    ));
  }
}

class CardUnified extends StatelessWidget {
  final Widget child;
  final double top;
  final double bottom;
  final double left;
  final double right;
  final bool transparent;

  const CardUnified({required this.child,
    this.top=12, this.bottom=12, this.left=16, this.right=16,
    this.transparent=false, Key? key}) : super(key: key);

  const CardUnified.nopad({required this.child, this.transparent=false, Key? key})
      : top=0, bottom=0, left=0, right=0, super(key: key);

  @override
  Widget build(BuildContext context) {
    final Padding inner_card = Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom, left: left, right: right),
      child: child,
    );

    if(! transparent) {
      return Card(
        margin: const EdgeInsets.all(8),
        child: inner_card,
      );
    } else {
      return Card(
        color: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.all(8),
        child: inner_card,
      );
    }
  }
}

class XTextField extends StatelessWidget {
  final TextEditingController controller;
  final int? max_length;
  final int max_lines;
  final bool enabled;
  final bool autofocus;
  final bool obscure_text;
  final bool numpad;
  final ValueChanged<String> on_submitted;

  const XTextField({required this.controller, this.max_length, this.max_lines=1,
    this.enabled=true, this.autofocus=false, this.obscure_text=false,
    this.numpad=false, required this.on_submitted, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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

class BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final ValueGetter? on_tap;

  const BigButton(this.label, this.icon, this.on_tap, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ElevatedButton.icon(
        label: Text(label),
        icon: Icon(icon),
        style: ElevatedButton.styleFrom(
          primary: Theme.of(context).colorScheme.surfaceTint,
          onPrimary: Theme.of(context).colorScheme.onInverseSurface,
          textStyle: Theme.of(context).textTheme.titleMedium,
          minimumSize: const Size(double.infinity, 48),
        ),
        onPressed: on_tap,
      ),
    );
  }
}

class XBottomSheet extends StatelessWidget {
  final List<Map> values;
  final ValueSetter on_tap;

  const XBottomSheet(this.values, this.on_tap, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
}

class XGradient extends StatelessWidget {
  final GradientType type;
  final int hue;

  const XGradient.hue({Key? key}) : type=GradientType.hue, hue=0, super(key: key);
  const XGradient.saturation(this.hue, {Key? key}) : type=GradientType.saturation, super(key: key);
  const XGradient.temperature({Key? key}) : type=GradientType.temperature, hue=0, super(key: key);

  static int hue_to_temp(int hue) {
    double temp = (hue - 240).toDouble();
    if(temp < 0) temp *= -25;
    else temp /= -0.12;
    temp += 3000;
    return temp.round();
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

  @override
  Widget build(BuildContext context) {
    switch(type) {
      case GradientType.hue:
        return _gradient([
          const HSVColor.fromAHSV(1, 0, 1, 1).toColor(),
          const HSVColor.fromAHSV(1, 60, 1, 1).toColor(),
          const HSVColor.fromAHSV(1, 120, 1, 1).toColor(),
          const HSVColor.fromAHSV(1, 180, 1, 1).toColor(),
          const HSVColor.fromAHSV(1, 240, 1, 1).toColor(),
          const HSVColor.fromAHSV(1, 300, 1, 1).toColor(),
          const HSVColor.fromAHSV(1, 360, 1, 1).toColor(),
        ]);

      case GradientType.saturation:
        return _gradient([
          HSVColor.fromAHSV(1, hue.toDouble(), 0.0, 1).toColor(),
          HSVColor.fromAHSV(1, hue.toDouble(), 0.1, 1).toColor(),
          HSVColor.fromAHSV(1, hue.toDouble(), 1.0, 1).toColor(),
        ]);

      case GradientType.temperature:
        return _gradient([
          const HSVColor.fromAHSV(1, 210, 0.3, 1).toColor(),
          const HSVColor.fromAHSV(1, 0, 0.0, 0.98).toColor(),
          const HSVColor.fromAHSV(1, 60, 0.3, 1).toColor(),
          const HSVColor.fromAHSV(1, 55, 0.7, 1).toColor(),
          const HSVColor.fromAHSV(1, 30, 1, 1).toColor(),
        ]);
    }
  }
}
