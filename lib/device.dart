import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'bluetooth.dart';
import 'widgets.dart';

enum Mode { off, on, sleep, auto }

class Device extends StatefulWidget {
  @override
  _DeviceState createState() => _DeviceState();
}

class _DeviceState extends State<Device> {
  final List<Mode> _modes_switch = [Mode.on, Mode.auto];
  final List<Mode> _modes_radio = [Mode.off, Mode.on];

  bool _mutex = true;
  late int _channel;
  late Mode _mode;
  late Mode _mode_radio;
  late List<int> _brightness;
  late List<int> _hue;
  late List<int> _saturation;

  @override
  void didChangeDependencies() async {
    await _refresh();

    final unix_time = ByteData(8);
    unix_time.setInt64(0, DateTime.now().millisecondsSinceEpoch ~/ 1000, Endian.little);
    characteristic_write(Characteristic.unix_time, unix_time.buffer.asUint8List());

    final String timezone = await FlutterNativeTimezone.getLocalTimezone();
    final Map tzdata = jsonDecode(await rootBundle.loadString('assets/tzdata.json'));
    if(tzdata.containsKey(timezone)) {
      characteristic_write(Characteristic.timezone, tzdata[timezone].codeUnits);
    }

    super.didChangeDependencies();
  }

  Future<void> _refresh() async {
    setState(() => _mutex = true);

    ble_control = await ble.readCharacteristic(Characteristic.control);
    ble_strip = await ble.readCharacteristic(Characteristic.strip);

    setState(() {
      _mutex = false;

      for(int chan=0; chan<4; chan++) {
        if(board_channel(chan)) {
          _channel = chan;
          break;
        }
      }

      _mode = Mode.values[board_mode()];
      _mode_radio = _modes_radio.contains(_mode) ? Mode.on : Mode.auto;
      _brightness = [
        board_brightness(0),
        board_brightness(1),
        board_brightness(2),
        board_brightness(3),
      ];
      _hue = [
        board_hue(2),
        board_hue(3),
      ];
      _saturation = [
        board_saturation(2),
        board_saturation(3),
      ];
    });
  }

  void _on_mode_switch(bool value) {
    setState(() {
      switch(_mode) {
        case Mode.off:
        case Mode.on:
          _mode = value ? Mode.on : Mode.off;
          _mode_radio = Mode.on;
          break;

        case Mode.sleep:
        case Mode.auto:
          _mode = value ? Mode.auto : Mode.sleep;
          _mode_radio = Mode.auto;
          break;
      }
    });
    board_mode(_mode.index);
    characteristic_write(Characteristic.control);
  }

  Future<void> _on_mode_radio(Mode? value) async {
    setState(() => _mode = _mode_radio = value!);
    board_mode(_mode.index);
    characteristic_write(Characteristic.control);
  }

  void _on_channel(int chan) {
    setState(() => _channel = chan);
  }

  void _on_brightness(int chan, int value) {
    setState(() => _brightness[chan] = value);
  }

  void _on_brightness_end(int chan, int value) {
    board_brightness(chan, value);
    if(chan < 2) characteristic_write(Characteristic.control);
    else characteristic_write(Characteristic.strip);
  }

  void _on_hue(int chan, int value) {
    setState(() => _hue[chan-2] = value);
  }

  void _on_hue_end(int chan, int value) {
    board_hue(chan, value);
    characteristic_write(Characteristic.strip);
  }

  void _on_saturation(int chan, int value) {
    setState(() => _saturation[chan-2] = value);
  }

  void _on_saturation_end(int chan, int value) {
    board_saturation(chan, value);
    characteristic_write(Characteristic.strip);
  }

  void _goto_settings() {
    Navigator.pushNamed(context, '/settings').whenComplete(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ble_device.name),
        actions: [IconButton(
          icon: icon_adaptive(Icons.settings, CupertinoIcons.settings),
          onPressed: _goto_settings,
        )],
      ),
      body: _mutex ? loader('Loading settings ...') : _build_body(),
    );
  }

  Widget _build_body() {
    List<Widget> children = [
      _build_switch(),
      _build_radio(),
      _build_channels(),
    ];

    switch(_channel) {
      case 0: children.add(_build_chan_mono(0)); break;
      case 1: children.add(_build_chan_mono(1)); break;
      case 2: children.add(_build_chan_color(2)); break;
      case 3: children.add(_build_chan_color(3)); break;
    }

    return SingleChildScrollView(child: Column(
      children: children,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
    ));
  }

  Widget _build_switch() {
    return Column(children: [
      Padding(
        child: Align(
          child: Text('Enable / Disable'),
          alignment: Alignment.centerLeft,
        ),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
      Padding(
        child: Transform.scale(
          child: Switch.adaptive(
            value: _modes_switch.contains(_mode),
            activeColor: Theme.of(context).accentColor,
            onChanged: _on_mode_switch,
          ),
          scale: Platform.isIOS ? 1.5 : 2.5,
        ),
        padding: EdgeInsets.only(top: 16, bottom: 32),
      ),
    ]);
  }

  Widget _build_radio() {
    String descr = '';
    switch(_mode) {
      case Mode.on:
      case Mode.off:
        descr = 'Allows you to\u00A0manually turn the light on\u00A0or\u00A0off.';
        break;

      case Mode.auto:
        descr = 'Uses sensors to\u00A0turn the\u00A0light on\u00A0or\u00A0off automatically.';
        break;

      case Mode.sleep:
        descr = 'Will switch to\u00A0automatic mode in\u00A0sunlight.';
        break;
    }

    return card_unified(
      child: Column(children: [
        Align(
          child: Text('Choose operating mode'),
          alignment: Alignment.centerLeft,
        ),
        Container(
          child: Column(children: [
            RadioListTile(
              title: Text('Auto'),
              value: Mode.auto,
              groupValue: _mode_radio,
              onChanged: _on_mode_radio,
            ),
            RadioListTile(
              title: Text('Manual'),
              value: Mode.on,
              groupValue: _mode_radio,
              onChanged: _on_mode_radio,
            ),
          ]),
          width: 160,
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
        Divider(height: 0),
        Container(
          child: Text(descr, textAlign: TextAlign.center, style: TextStyle(
            color: Theme.of(context).textTheme.caption!.color,
            height: 1.2,
          )),
          height: 40,
          padding: EdgeInsets.only(top: 6),
        ),
      ]),
    );
  }

  Widget _build_channels() {
    final double width = MediaQuery.of(context).size.width;
    List<Widget> buttons = [];

    for(int chan=0; chan<4; chan++) {
      if(board_channel(chan)) {
        buttons.add(ElevatedButton(
          child: Text('Channel ${chan+1}'),
          style: ElevatedButton.styleFrom(
            primary: _channel == chan
              ? Theme.of(context).toggleableActiveColor
              : Theme.of(context).unselectedWidgetColor,
            padding: EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: () => _on_channel(chan),
        ));
      }
    }

    return Padding(
      child: Wrap(
        children: buttons,
        alignment: WrapAlignment.center,
        spacing: 8,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: width > 380 ? 8 : (width - 200) / 2,
        vertical: 8,
      ),
    );
  }

  Widget _build_chan_mono(int chan) {
    return card_unified(child: Column(children: [
      Row(
        children: [
          Text(ROUTINE[1]),
          Text(
            '${_brightness[chan]} %',
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      SizedBox(height: 6),
      Slider.adaptive(
        value: _brightness[chan].toDouble(), min: 10, max: 100, divisions: 90,
        onChanged: (double value) => _on_brightness(chan, value.toInt()),
        onChangeEnd: (double value) => _on_brightness_end(chan, value.toInt()),
      ),
    ]));
  }

  Widget _build_chan_color(int chan) {
    return board_pixtype(chan) == 0 ? _build_chan_rgb(chan) : _build_chan_wwa(chan);
  }

  Widget _build_chan_rgb(int chan) {
    return card_unified(child: Column(children: [
      Row(
        children: [
          Text(ROUTINE[1]),
          Text(
            '${_brightness[chan]} %',
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      SizedBox(height: 6),
      Slider.adaptive(
        value: _brightness[chan].toDouble(), min: 10, max: 100, divisions: 90,
        onChanged: (double value) => _on_brightness(chan, value.toInt()),
        onChangeEnd: (double value) => _on_brightness_end(chan, value.toInt()),
      ),
      Divider(height: 24),
      Row(
        children: [
          Text(ROUTINE[2]),
          Text(
            '${_hue[chan-2]} \u00B0',
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      Slider.adaptive(
        value: _hue[chan-2].toDouble(), min: 0, max: 360, divisions: 180,
        onChanged: (double value) => _on_hue(chan, value.toInt()),
        onChangeEnd: (double value) => _on_hue_end(chan, value.toInt()),
      ),
      gradient_hue(),
      SizedBox(height: 6),
      Divider(height: 24),
      Row(
        children: [
          Text(ROUTINE[3]),
          Text(
            '${_saturation[chan-2]} %',
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      Slider.adaptive(
        value: _saturation[chan-2].toDouble(), min: 0, max: 100, divisions: 100,
        onChanged: (value) => _on_saturation(chan, value.toInt()),
        onChangeEnd: (value) => _on_saturation_end(chan, value.toInt()),
      ),
      gradient_saturation(_hue[chan-2]),
      SizedBox(height: 12),
    ]));
  }

  Widget _build_chan_wwa(int chan) {
    return card_unified(child: Column(children: [
      Row(
        children: [
          Text(ROUTINE[1]),
          Text(
            '${_brightness[chan]} %',
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      SizedBox(height: 6),
      Slider.adaptive(
        value: _brightness[chan].toDouble(), min: 10, max: 100, divisions: 90,
        onChanged: (double value) => _on_brightness(chan, value.toInt()),
        onChangeEnd: (double value) => _on_brightness_end(chan, value.toInt()),
      ),
      Divider(height: 24),
      Row(
        children: [
          Text(ROUTINE[4]),
          Text(
            '${hue_to_temp(_hue[chan-2])} K',
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      Slider.adaptive(
        value: _hue[chan-2].toDouble(), min: 120, max: 360, divisions: 120,
        onChanged: (double value) => _on_hue(chan, value.toInt()),
        onChangeEnd: (double value) => _on_hue_end(chan, value.toInt()),
      ),
      gradient_temperature(),
      SizedBox(height: 12),
    ]));
  }
}