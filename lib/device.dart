import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'bluetooth.dart';
import 'widgets.dart';

enum Mode { off, on, sleep, auto }

class Device extends StatefulWidget {
  const Device({Key? key}) : super(key: key);

  @override
  DeviceState createState() => DeviceState();
}

class DeviceState extends State<Device> {
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
  void initState() {
    initAsync();
    super.initState();
  }

  void initAsync() async {
    await _refresh();

    final unix_time = ByteData(8);
    unix_time.setInt64(0, DateTime.now().millisecondsSinceEpoch ~/ 1000, Endian.little);
    characteristic_write(Characteristic.unix_time, unix_time.buffer.asUint8List());

    final String timezone = await FlutterNativeTimezone.getLocalTimezone();
    final Map tzdata = jsonDecode(await rootBundle.loadString('assets/tzdata.json'));
    if(tzdata.containsKey(timezone)) {
      characteristic_write(Characteristic.timezone, tzdata[timezone].codeUnits);
    }
  }

  Future<void> _refresh() async {
    setState(() => _mutex = true);

    ble_control = await ble.readCharacteristic(Characteristic.control);
    ble_strip = await ble.readCharacteristic(Characteristic.strip);

    setState(() {
      _mutex = false;
      _mode = Mode.values[board_mode()];
      _mode_radio = _modes_radio.contains(_mode) ? Mode.on : Mode.auto;

      switch(board_idv) {
        case 'SMA1':
          for(int chan=0; chan<4; chan++) {
            if(board_channel(chan)) {
              _channel = chan;
              break;
            }
          }
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
          break;

        case 'SMA2':
        case 'SMA3':
          _channel = 2;
          _brightness = [ 0, 0, board_brightness(2) ];
          _hue = [ board_hue(2) ];
          _saturation = [ board_saturation(2) ];
          break;
      }
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
          icon: const Icon(Icons.settings),
          onPressed: _goto_settings,
        )],
      ),
      body: _mutex ? const Loader('Loading settings ...', null) : _build_body(),
    );
  }

  Widget _build_body() {
    List<Widget> children = [
      _build_switch(),
      _build_radio(),
    ];

    if(board_idv == 'SMA1') children.add(_build_channels());

    switch(_channel) {
      case 0: children.add(_build_chan_mono(0)); break;
      case 1: children.add(_build_chan_mono(1)); break;
      case 2: children.add(_build_chan_color(2)); break;
      case 3: children.add(_build_chan_color(3)); break;
    }

    return LayoutBuilder(builder: (context, constraint) {
      return SingleChildScrollView(child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraint.maxHeight),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: children,
        ),
      ));
    });
  }

  Widget _build_switch() {
    return Column(children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Enable / Disable'),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 32),
        child: Transform.scale(
          scale: 2.0,
          child: Switch(
            value: _modes_switch.contains(_mode),
            onChanged: _on_mode_switch,
          ),
        ),
      ),
    ]);
  }

  Widget _build_radio() {
    String descr = '';
    switch(_mode) {
      case Mode.on:
      case Mode.off:
        descr = 'Allows you to manually turn the light on or off.';
        break;

      case Mode.auto:
        descr = 'Uses sensors to turn the light on or off automatically.';
        break;

      case Mode.sleep:
        descr = 'Will switch to automatic mode in sunlight.';
        break;
    }

    return CardUnified(
      child: Column(children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Choose operating mode'),
        ),
        Container(
          width: 160,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(children: [
            RadioListTile(
              title: const Text('Auto'),
              value: Mode.auto,
              groupValue: _mode_radio,
              onChanged: _on_mode_radio,
            ),
            RadioListTile(
              title: const Text('Manual'),
              value: Mode.on,
              groupValue: _mode_radio,
              onChanged: _on_mode_radio,
            ),
          ]),
        ),
        const Divider(height: 0),
        Container(
          height: 40,
          padding: const EdgeInsets.only(top: 6),
          child: Text(descr, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(height: 1.2)),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: _channel == chan
                ? Theme.of(context).secondaryHeaderColor
                : Theme.of(context).cardColor,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: () => _on_channel(chan),
          child: Text('Channel ${chan+1}', style: TextStyle(color: _channel == chan
              ? Theme.of(context).toggleableActiveColor
              : Theme.of(context).unselectedWidgetColor,
          )),
        ));
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: width > 380 ? 8 : (width - 200) / 2,
        vertical: 8,
      ),
      child: Wrap(alignment: WrapAlignment.center, spacing: 8, children: buttons),
    );
  }

  Widget _build_chan_mono(int chan) {
    return CardUnified(child: Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(ROUTINE[1]),
          Text('${_brightness[chan]} %', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
      const SizedBox(height: 6),
      Slider(
        value: _brightness[chan].toDouble(), min: 10, max: 100, divisions: 90,
        onChanged: (double value) => _on_brightness(chan, value.round()),
        onChangeEnd: (double value) => _on_brightness_end(chan, value.round()),
      ),
    ]));
  }

  Widget _build_chan_color(int chan) {
    return board_pixtype(chan) == 0 ? _build_chan_rgb(chan) : _build_chan_wwa(chan);
  }

  Widget _build_chan_rgb(int chan) {
    return CardUnified(
      transparent: true,
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(ROUTINE[1]),
            Text('${_brightness[chan]} %', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 6),
        Slider(
          value: _brightness[chan].toDouble(), min: 10, max: 100, divisions: 90,
          onChanged: (double value) => _on_brightness(chan, value.round()),
          onChangeEnd: (double value) => _on_brightness_end(chan, value.round()),
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(ROUTINE[2]),
            Text('${_hue[chan-2]} \u00B0', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: _hue[chan-2].toDouble(), min: 0, max: 360, divisions: 180,
          onChanged: (double value) => _on_hue(chan, value.round()),
          onChangeEnd: (double value) => _on_hue_end(chan, value.round()),
        ),
        const XGradient.hue(),
        const SizedBox(height: 6),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(ROUTINE[3]),
            Text('${_saturation[chan-2]} %', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: _saturation[chan-2].toDouble(), min: 0, max: 100, divisions: 100,
          onChanged: (value) => _on_saturation(chan, value.round()),
          onChangeEnd: (value) => _on_saturation_end(chan, value.round()),
        ),
        XGradient.saturation(_hue[chan-2]),
        const SizedBox(height: 12),
      ]),
    );
  }

  Widget _build_chan_wwa(int chan) {
    return CardUnified(
      transparent: true,
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(ROUTINE[1]),
            Text('${_brightness[chan]} %', style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 6),
        Slider(
          value: _brightness[chan].toDouble(), min: 10, max: 100, divisions: 90,
          onChanged: (double value) => _on_brightness(chan, value.round()),
          onChangeEnd: (double value) => _on_brightness_end(chan, value.round()),
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(ROUTINE[4]),
            Text('${XGradient.hue_to_temp(_hue[chan-2])} K',
                style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
        Slider(
          value: _hue[chan-2].toDouble(), min: 120, max: 360, divisions: 120,
          onChanged: (double value) => _on_hue(chan, value.round()),
          onChangeEnd: (double value) => _on_hue_end(chan, value.round()),
        ),
        const XGradient.temperature(),
        const SizedBox(height: 12),
      ]),
    );
  }
}
