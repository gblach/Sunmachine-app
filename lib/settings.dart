import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'bluetooth.dart';
import 'widgets.dart';

const List<String> PIXTYPE = [ 'RGB', 'WWA' ];

class Settings extends StatefulWidget {
  const Settings({Key? key}) : super(key: key);

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _mutex = true;
  final TextEditingController _name_ctrl = TextEditingController();
  late int _timeout;
  late int _light;
  int _light_cur = 0;
  late int _speed;
  late List<bool> _channel;
  late List<TextEditingController> _pixlen_ctrl;
  late List<int> _pixtype;
  StreamSubscription<List<int>>? _light_sub;

  @override
  void initState() {
    initAsync();
    super.initState();
  }

  void initAsync() async {
    final String name = Platform.isIOS ? ble_device.name
      : String.fromCharCodes(await ble.readCharacteristic(Characteristic.device_name));

    setState(() {
      _mutex = false;
      _name_ctrl.text = name;
      _timeout = board_timeout();
      _light = board_light();
      _speed = board_speed();

      switch(board_idv) {
        case 'SMA1':
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
          break;

        case 'SMA2':
          _channel = [ false, false, true ];
          _pixlen_ctrl = [ TextEditingController(text: board_pixlen(2).toString()) ];
          _pixtype = [ board_pixtype(2) ];
          break;
      }
    });

    _light_sub = ble.subscribeToCharacteristic(Characteristic.light_cur).listen((List<int> value) {
      if(value.isNotEmpty) setState(() => _light_cur = (value[0] | value[1] << 8));
    }, onError: print);
  }

  @override
  void dispose() {
    _light_sub?.cancel();
    super.dispose();
  }

  void _on_rename(String value) {
    if(value.isNotEmpty) characteristic_write(Characteristic.device_name, value.codeUnits);
  }

  void _on_timeout(int value) {
    setState(() => _timeout = value);
  }

  void _on_timeout_end(int value) {
    board_timeout(value);
    characteristic_write(Characteristic.control);
  }

  void _on_ambient_light(int value) {
    setState(() => _light = value);
  }

  void _on_ambient_light_end(int value) {
    board_light(value);
    characteristic_write(Characteristic.control);
  }

  void _on_speed(int value) {
    setState(() => _speed = value);
  }

  void _on_speed_end(int value) {
    board_speed(value.toInt());
    characteristic_write(Characteristic.control);
  }

  void _on_channel(int chan, bool value) {
    setState(() => _channel[chan] = value);
    board_channel(chan, value);
    characteristic_write(Characteristic.control);
  }

  void _on_pixlen(int chan, String value) {
    board_pixlen(chan, int.parse(value));
    characteristic_write(Characteristic.strip);
  }

  void _on_pixtype(int chan, String value) {
    setState(() => _pixtype[chan-2] = board_pixtype(chan, PIXTYPE.indexOf(value)));
    if(_pixtype[chan-2] == 1 && board_hue(chan) < 120) board_hue(chan, 120);
    characteristic_write(Characteristic.strip);
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
    List<Widget> children = [
      _build_rename(),
      _build_timeout(),
      _build_light(),
      _build_speed(),
      _build_scheduler(),
    ];

    switch(board_idv) {
      case 'SMA1':
        children.addAll([
          _build_chan_mono(0),
          _build_chan_mono(1),
          _build_chan_color(2),
          _build_chan_color(3),
        ]);
        break;

      case 'SMA2':
        children.add(_build_chan_color(2, false));
        break;
    }

    return SingleChildScrollView(child: Column(children: children));
  }

  Widget _build_rename() {
    return card_unified(
      child: Column(children: [
        Row(
          children: [
            const Text('Rename'),
            Text(
              'Need device restart',
              style: TextStyle(color: Theme.of(context).textTheme.caption!.color),
            ),
          ],
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        ),
        const SizedBox(height: 6),
        text_field_adaptive(
          controller: _name_ctrl,
          max_length: 40,
          on_submitted: _on_rename,
        ),
      ]),
      transparent: true,
    );
  }

  Widget _build_timeout() {
    return card_unified(child: Column(children: [
      Row(
        children: [
          const Text('Turn off the light after'),
          Text(
            '${_timeout ~/ 12}:${(_timeout % 12 * 5).toString().padLeft(2, '0')} min',
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      const SizedBox(height: 6),
      Slider.adaptive(
        value: _timeout.toDouble(), min: 6, max: 120, divisions: 19,
        onChanged: (double value) => _on_timeout(value.round()),
        onChangeEnd:(double value) =>  _on_timeout_end(value.round()),
      ),
    ]));
  }

  Widget _build_light() {
    return card_unified(child: Column(children: [
      Row(
        children: [
          const Text('Turn on the light when it\'s darker than'),
          Text(
            '${_light * 5} lx',
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      const SizedBox(height: 6),
      Slider.adaptive(
        value: _light.toDouble(), min: 1, max: 20, divisions: 20,
        onChanged: (double value) => _on_ambient_light(value.round()),
        onChangeEnd: (double value) => _on_ambient_light_end(value.round()),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Text(
            'Current ambient light intensity',
            style: TextStyle(color: Theme.of(context).textTheme.caption!.color),
          ),
          Text(
            '$_light_cur lx',
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
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
          const Text('Transition speed of the light'),
          Text(
            _speed.toString(),
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          ),
        ],
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
      ),
      const SizedBox(height: 6),
      Slider.adaptive(
        value: _speed.toDouble(), min: 1, max: 20, divisions: 20,
        onChanged: (double value) => _on_speed(value.round()),
        onChangeEnd: (double value) => _on_speed_end(value.round()),
      ),
    ]));
  }

  Widget _build_scheduler() {
    return card_unified_nopad(child: ListTileTheme(
      child: ListTile(
        leading: Padding(
          child: icon_adaptive(Icons.schedule, CupertinoIcons.clock),
          padding: const EdgeInsets.only(top: 14, left: 8),
        ),
        title: const Text('Scheduler'),
        subtitle: const Text('Schedule a change of mode, brightness, hue, saturation or temperature.'),
        trailing: Padding(
          child: icon_adaptive(Icons.chevron_right, CupertinoIcons.right_chevron),
          padding: const EdgeInsets.only(top: 14),
        ),
        isThreeLine: true,
        contentPadding: const EdgeInsets.only(top: 4, left: 16, right: 16),
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
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      onChanged: (bool? value) => _on_channel(chan, value!),
    ));
  }

  Widget _build_chan_color(int chan, [bool onoff=true]) {
    return card_unified(
      child: Column(children: [
        onoff ? CheckboxListTile(
          title: Text('Channel ${chan+1}'),
          subtitle: Text('Enable or disable ${chan % 2 == 0 ? 'first' : 'second'} color channel.'),
          value: _channel[chan],
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          onChanged: (bool? value) => _on_channel(chan, value!),
        ) : const SizedBox(height: 12),
        Padding(
          child: Column(children: [
            Align(
              child: Text(
                'Number of pixels',
                style: onoff
                  ? Theme.of(context).textTheme.caption
                  : Theme.of(context).textTheme.bodyText2,
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
              const SizedBox(width: 12),
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ]),
      top: 0, bottom: 16, left: 0, right: 0,
    );
  }
}