import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'bluetooth.dart';
import 'widgets.dart';

const List<String> PIXTYPE = [ 'RGB', 'WWA' ];

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _mutex = true;
  TextEditingController _name_ctrl = TextEditingController();
  late int _timeout;
  late int _light;
  int _light_cur = 0;
  late int _speed;
  late List<bool> _channel;
  late List<TextEditingController> _pixlen_ctrl;
  late List<int> _pixtype;
  StreamSubscription<List<int>>? _light_sub;

  void didChangeDependencies() async {
    final String name = Platform.isIOS ? ble_device.name
      : String.fromCharCodes(await Characteristic.device_name.read());

    setState(() {
      _mutex = false;
      _name_ctrl.text = name;
      _timeout = board_timeout();
      _light = board_light();
      _speed = board_speed();
      _channel = [
        board_channel(0),
        board_channel(1),
        board_channel(2),
        board_channel(3),
      ];
      _pixlen_ctrl = [
        TextEditingController(text: board_pixlen(2).toString()),
        TextEditingController(text: board_pixlen(3).toString()),
      ];
      _pixtype = [
        board_pixtype(2),
        board_pixtype(3),
      ];
    });

    _light_sub = Characteristic.light_cur.value.listen((List<int> value) {
      if(value.isNotEmpty) {
        setState(() => _light_cur = (value[0] | value[1] << 8));
      }
    });
    Characteristic.light_cur.setNotifyValue(true);
  }

  @override
  void dispose() {
    _light_sub?.cancel();
    final CharacteristicProperties props = Characteristic.light_cur.properties;
    if(props.notify || props.indicate) {
      Characteristic.light_cur.setNotifyValue(false);
    }
    super.dispose();
  }

  void _on_rename(String value) {
    if(value.isNotEmpty) Characteristic.device_name.write(value.codeUnits);
  }

  void _on_timeout(int value) {
    setState(() => _timeout = value);
  }

  void _on_timeout_end(int value) {
    board_timeout(value);
    Characteristic.control.write(ble_control);
  }

  void _on_ambient_light(int value) {
    setState(() => _light = value);
  }

  void _on_ambient_light_end(int value) {
    board_light(value);
    Characteristic.control.write(ble_control);
  }

  void _on_speed(int value) {
    setState(() => _speed = value);
  }

  void _on_speed_end(int value) {
    board_speed(value.toInt());
    Characteristic.control.write(ble_control);
  }

  void _on_channel(int chan, bool value) {
    setState(() => _channel[chan] = value);
    board_channel(chan, value);
    Characteristic.control.write(ble_control);
  }

  void _on_pixlen(int chan, String value) {
    board_pixlen(chan, int.parse(value));
    Characteristic.strip.write(ble_strip);
  }

  void _on_pixtype(int chan, String value) {
    setState(() => _pixtype[chan-2] = board_pixtype(chan, PIXTYPE.indexOf(value)));
    if(_pixtype[chan-2] == 1 && board_hue(chan) < 120) board_hue(chan, 120);
    Characteristic.strip.write(ble_strip);
  }

  void _goto_scheduler() {
    Navigator.pushNamed(context, '/scheduler');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ble_device.name)),
      body: _mutex ? loader('Loading settings ...') : _build_body(),
    );
  }

  Widget _build_body() {
    return SingleChildScrollView(child: Column(children: [
      _build_rename(),
      _build_timeout(),
      _build_light(),
      _build_speed(),
      _build_scheduler(),
      _build_chan_mono(0),
      _build_chan_mono(1),
      _build_chan_color(2),
      _build_chan_color(3),
    ]));
  }

  Widget _build_rename() {
    return card_unified(
      child: Column(children: [
        Row(
          children: [
            Text('Rename'),
            Text(
              'Need device reconnect',
              style: TextStyle(color: Theme.of(context).textTheme.caption!.color),
            ),
          ],
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        ),
        SizedBox(height: 6),
        text_field_adaptive(
          controller: _name_ctrl,
          max_length: 40,
          on_submitted: _on_rename,
        ),
      ]),
      transarent: true,
    );
  }

  Widget _build_timeout() {
    return card_unified(child: Column(children: [
      Row(
        children: [
          Text('Turn off the light after'),
          Text(
            '${_timeout ~/ 12}:${(_timeout % 12 * 5).toString().padLeft(2, '0')} min',
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      SizedBox(height: 6),
      Slider.adaptive(
        value: _timeout.toDouble(), min: 6, max: 120, divisions: 19,
        onChanged: (double value) => _on_timeout(value.toInt()),
        onChangeEnd:(double value) =>  _on_timeout_end(value.toInt()),
      ),
    ]));
  }

  Widget _build_light() {
    return card_unified(child: Column(children: [
      Row(
        children: [
          Text('Turn on the light when it\'s darker than'),
          Text(
            '${_light * 5} lx',
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      SizedBox(height: 6),
      Slider.adaptive(
        value: _light.toDouble(), min: 2, max: 50, divisions: 24,
        onChanged: (double value) => _on_ambient_light(value.toInt()),
        onChangeEnd: (double value) => _on_ambient_light_end(value.toInt()),
      ),
      SizedBox(height: 6),
      Row(
        children: [
          Text(
            'Current ambient light intensity',
            style: TextStyle(color: Theme.of(context).textTheme.caption!.color),
          ),
          Text(
            '${_light_cur} lx',
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
    ]));
  }

  Widget _build_speed() {
    return card_unified(child: Column(children: [
      Row(
        children: [
          Text('Transition speed of the light'),
          Text(
            _speed.toString(),
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      SizedBox(height: 6),
      Slider.adaptive(
        value: _speed.toDouble(), min: 1, max: 20, divisions: 20,
        onChanged: (double value) => _on_speed(value.toInt()),
        onChangeEnd: (double value) => _on_speed_end(value.toInt()),
      ),
    ]));
  }

  Widget _build_scheduler() {
    return card_unified_nopad(child: ListTileTheme(
      child: ListTile(
        leading: Padding(
          child: icon_adaptive(Icons.schedule, CupertinoIcons.clock),
          padding: EdgeInsets.only(top: 14, left: 8),
        ),
        title: Text('Scheduler'),
        subtitle: Text('Schedule a change of mode, brightness, hue, saturation or temperature.'),
        trailing: Padding(
          child: icon_adaptive(Icons.chevron_right, CupertinoIcons.right_chevron),
          padding: EdgeInsets.only(top: 14),
        ),
        isThreeLine: true,
        contentPadding: EdgeInsets.only(top: 4, left: 16, right: 16),
        onTap: _goto_scheduler,
      ),
      iconColor: Theme.of(context).iconTheme.color,
    ));
  }

  Widget _build_chan_mono(int chan) {
    return card_unified_nopad(child: CheckboxListTile(
      title: Text('Channel ${chan+1}'),
      subtitle: Text('Enable or disable ${chan % 2 == 0 ? 'first' : 'second'} mono channel.'),
      value: _channel[chan],
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      onChanged: (bool? value) => _on_channel(chan, value!),
    ));
  }

  Widget _build_chan_color(int chan) {
    return card_unified(
      child: Column(children: [
        CheckboxListTile(
          title: Text('Channel ${chan+1}'),
          subtitle: Text('Enable or disable ${chan % 2 == 0 ? 'first' : 'second'} color channel.'),
          value: _channel[chan],
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          onChanged: (bool? value) => _on_channel(chan, value!),
        ),
        Padding(
          child: Column(children: [
            Align(
              child: Text(
                'Number of pixels',
                style: Theme.of(context).textTheme.caption,
              ),
              alignment: Alignment.centerLeft,
            ),
            SizedBox(height: _channel[chan] ? 0 : (Platform.isIOS ? 6 : 7)),
            Row(children: [
              Expanded(child: text_field_adaptive(
                controller: _pixlen_ctrl[chan-2],
                enabled: _channel[chan],
                numpad: true,
                on_submitted: (String value) => _on_pixlen(chan, value),
              )),
              SizedBox(width: 12),
              DropdownButton(
                value: PIXTYPE[_pixtype[chan-2]],
                items: PIXTYPE.map((String value) {
                  return DropdownMenuItem(child: Text(value), value: value);
                }).toList(),
                underline: Container(),
                onChanged: _channel[chan]
                  ? (String? value) => _on_pixtype(chan, value!) : null,
              ),
            ]),
            SizedBox(height: _channel[chan] ? 0 : 6),
          ]),
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
      ]),
      top: 0, bottom: 16, left: 0, right: 0,
    );
  }
}