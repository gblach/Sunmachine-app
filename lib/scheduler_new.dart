import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'bluetooth.dart';
import 'dow_picker.dart';
import 'widgets.dart';

class SchedulerNew extends StatefulWidget {
  const SchedulerNew({Key? key}) : super(key: key);

  @override
  _SchedulerNewState createState() => _SchedulerNewState();
}

class _SchedulerNewState extends State<SchedulerNew> {
  bool _is_valid = false;
  final List<bool> _dow_ctrl = DowPicker.init();
  TimeOfDay? _time;
  int? _routine;
  int? _chan;
  int? _value;

  void _on_dow() {
    dow_picker_adaptive(context,
      'Select days of the week', DowPicker(ctrl: _dow_ctrl), _validate);
  }

  void _on_time() {
    TimeOfDay? time = _time ?? TimeOfDay.now();
    time_picker_adaptive(context, time, (TimeOfDay time) {
      _time = time;
      _validate();
    });
  }

  List<Map<String,dynamic>> _channels() {
    List<Map<String,dynamic>> channels = [];
    for(int chan=0; chan<4; chan++) {
      switch(_routine) {
        case 1:
          if(board_channel(chan))
            channels.add({ 'label': 'Channel #${chan+1}', 'value': chan });
          break;

        case 2:
        case 3:
          if(board_channel(chan) && board_pixtype(chan) == 0)
            channels.add({ 'label': 'Channel #${chan+1}', 'value': chan });
          break;

        case 4:
          if(board_channel(chan) && board_pixtype(chan) == 1)
            channels.add({ 'label': 'Channel #${chan+1}', 'value': chan });
          break;
      }
    }

    if(_routine == 0 || channels.isEmpty) _chan = null;
    else if(channels.length == 1) _chan = channels[0]['value'];
    else if(_chan != null) {
      switch(_routine) {
        case 2:
        case 3:
          if(board_pixtype(_chan!) != 0) _chan = null;
          break;

        case 4:
          if(board_pixtype(_chan!) != 1) _chan = null;
          break;
      }
    }

    return channels;
  }

  void _value_default() {
    switch(_routine) {
      case 0: _value = null; break;
      case 1: _value = _chan != null ? board_brightness(_chan!) : 10; break;
      case 2: _value = _chan != null ? board_hue(_chan!) : 0; break;
      case 3: _value = _chan != null ? board_saturation(_chan!) : 0; break;
      case 4: _value = _chan != null ? board_hue(_chan!) : 120; break;
    }
  }

  void _on_routine() {
    List<Map<String,dynamic>> routines = [
      { 'label': ROUTINE[0], 'value': 0 },
    ];
    switch(board_idv) {
      case 'SMA1':
        if(board_channel(0) || board_channel(1) || board_channel(2) || board_channel(3)) {
          routines.add({ 'label': ROUTINE[1], 'value': 1 });
        }
        if(board_channel(2) && board_pixtype(2) == 0 || board_channel(3) && board_pixtype(3) == 0) {
          routines.add({ 'label': ROUTINE[2], 'value': 2 });
          routines.add({ 'label': ROUTINE[3], 'value': 3 });
        }
        if(board_channel(2) && board_pixtype(2) == 1 || board_channel(3) && board_pixtype(3) == 1) {
          routines.add({ 'label': ROUTINE[4], 'value': 4 });
        }
        break;

      case 'SMA2':
        routines.add({ 'label': ROUTINE[1], 'value': 1 });
        if(board_pixtype(2) == 0) {
          routines.add({ 'label': ROUTINE[2], 'value': 2 });
          routines.add({ 'label': ROUTINE[3], 'value': 3 });
        } else {
          routines.add({ 'label': ROUTINE[4], 'value': 4 });
        }
        break;
    }

    bottom_sheet_adaptive(context, routines, (dynamic value) {
      _routine = value;
      if(board_idv == 'SMA1') {
        _channels();
      } else {
        _chan = 2;
      }
      _value_default();
      _validate();
    });
  }

  void _on_chan() {
    List<Map<String,dynamic>> channels = _channels();

    if(channels.length > 1) {
      bottom_sheet_adaptive(context, channels, (dynamic value) {
        _chan = value;
        _value_default();
        _validate();
      });
    }
  }

  void _on_mode() {
    final List<Map<String,dynamic>> modes = List.generate(MODE.length, (int index) {
      final int value = MODE.length - index - 1;
      return { 'label': MODE[value], 'value': value };
    });

    bottom_sheet_adaptive(context, modes, (dynamic value) {
      _value = value;
      _validate();
    });
  }

  void _on_value(double value) {
    setState(() => _value = value.round());
  }

  void _validate() {
    int valid = -4;

    for(int i=0; i<_dow_ctrl.length; i++) {
      if(_dow_ctrl[i]) {
        valid++;
        break;
      }
    }
    if(_time != null) valid++;

    switch(_routine) {
      case 0:
        valid++;
        if(_value != null && 0 <= _value! && _value! <= 3) valid++;
        break;

      case 1:
        if(_chan != null && 0 <= _chan! && _chan! <= 3) valid++;
        if(_value != null && 0 <= _value! && _value! <= 100) valid++;
        break;

      case 2:
        if(_chan != null && 2 <= _chan! && _chan! <= 3) valid++;
        if(_value != null && 0 <= _value! && _value! <= 360) valid++;
        break;

      case 3:
        if(_chan != null && 2 <= _chan! && _chan! <= 3) valid++;
        if(_value != null && 0 <= _value! && _value! <= 100) valid++;
        break;

      case 4:
        if(_chan != null && 2 <= _chan! && _chan! <= 3) valid++;
        if(_value != null && 120 <= _value! && _value! <= 360) valid++;
        break;
    }

    setState(() => _is_valid = valid == 0);
  }


  void _on_save() {
    if(_is_valid) {
      int dow = 0;
      for(int i=0; i<_dow_ctrl.length; i++) {
        dow ^= _dow_ctrl[i] ? pow(2, i).toInt() : 0;
      }

      board_crontab.add({
        'enabled': 1,
        'dow': dow,
        'hh': _time!.hour,
        'mm': _time!.minute,
        'routine': _routine! < 4 ? _routine : 2,
        'chan': (board_idv == 'SMA1' && _routine! > 0) ? _chan : 0,
        'value': _value,
      });
      board_crontab_to_cronbuf();
      characteristic_write(Characteristic.cronbuf);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ble_device.name),
        actions: [IconButton(
          icon: icon_adaptive(Icons.check, CupertinoIcons.checkmark_alt),
          onPressed: _is_valid ? _on_save : null,
        )],
      ),
      body: _build_body(),
    );
  }

  Widget _build_body() {
    List<Widget> children = [
      _build_dow(),
      _build_time(),
      _build_routine(),
    ];

    if(board_idv == 'SMA1') children.add(_build_chan());
    children.add(_build_value());

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints viewportConstraints) {
        return SingleChildScrollView(child: ConstrainedBox(
          child: Column(
            children: [
              Column(children: children),
              Padding(
                child: big_button_adaptive(context,
                  'Save', Icons.check, _is_valid ? _on_save : null),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ],
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
          ),
          constraints: BoxConstraints(minHeight: viewportConstraints.maxHeight),
        ));
      }
    );
  }

  Widget _build_dow() {
    String dow = '';
    int days = 0;
    for(int i=0; i<_dow_ctrl.length; i++) days += _dow_ctrl[i] ? 1 : 0;
    for(int i=0; i<_dow_ctrl.length; i++) {
      if(_dow_ctrl[i]) {
        if(dow.isNotEmpty) dow += ', ';
        dow += days <= 3 ? DOW_LONG[i] : DOW_SHORT[i];
      }
    }

    return card_unified_nopad(child: ListTile(
      title: Text(dow),
      subtitle: const Text('days of week'),
      onTap: _on_dow,
    ));
  }

  Widget _build_time() {
    return card_unified_nopad(child: ListTile(
      title: Text(_time != null
        ? '${_time!.hour}:${_time!.minute.toString().padLeft(2, '0')}'
        : ''),
      subtitle: const Text('time'),
      onTap: _on_time,
    ));
  }

  Widget _build_routine() {
    return card_unified_nopad(child: ListTile(
      title: Text(_routine != null ? ROUTINE[_routine!] : ''),
      subtitle: const Text('routine'),
      onTap: _on_routine,
    ));
  }

  Widget _build_chan() {
    if(_routine == null || _routine == 0) return const SizedBox();

    return card_unified_nopad(child: ListTile(
      title: Text(_chan != null ? 'Channel #${_chan!+1}' : ''),
      subtitle: const Text('channel'),
      onTap: _on_chan,
    ));
  }

  Widget _build_value() {
    switch(_routine) {
      case 0: return _build_mode();
      case 1: return _build_brightness();
      case 2: return _build_hue();
      case 3: return _build_saturation();
      case 4: return _build_temperature();
      default: return const SizedBox();
    }
  }

  Widget _build_mode() {
    return card_unified_nopad(child: ListTile(
      title: Text(_value != null ? MODE[_value!.toInt()] : ''),
      subtitle: const Text('mode'),
      onTap: _on_mode,
    ));
  }

  Widget _build_brightness() {
    return card_unified(
      child: Column(children: [
        Slider.adaptive(
          value: _value!.toDouble(), min: 10, max: 100, divisions: 90,
          onChanged: _on_value,
          onChangeEnd: (double value) => _validate(),
        ),
        Row(
          children: [
            Text(
              ROUTINE[1].toLowerCase(),
              style: TextStyle(color: Theme.of(context).textTheme.caption!.color)
            ),
            Text(
              '$_value %',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)
            ),
          ],
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        )
      ]),
      top: 6,
    );
  }

  Widget _build_hue() {
    return card_unified(
      child: Column(children: [
        Slider.adaptive(
          value: _value!.toDouble(), min: 0, max: 360, divisions: 180,
          onChanged: _on_value, onChangeEnd: (double value) => _validate(),
        ),
        gradient_hue(),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              ROUTINE[2].toLowerCase(),
              style: TextStyle(color: Theme.of(context).textTheme.caption!.color)
            ),
            Text(
              '$_value \u00B0',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)
            ),
          ],
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        )
      ]),
      top: 6,
    );
  }

  Widget _build_saturation() {
    return card_unified(
      child: Column(children: [
        Slider.adaptive(
          value: _value!.toDouble(), min: 0, max: 100, divisions: 100,
          onChanged: _on_value, onChangeEnd: (double value) => _validate(),
        ),
        gradient_saturation(_chan != null ? board_hue(_chan!) : 224),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              ROUTINE[3].toLowerCase(),
              style: TextStyle(color: Theme.of(context).textTheme.caption!.color)
            ),
            Text(
              '$_value %',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)
            ),
          ],
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        )
      ]),
      top: 6,
    );
  }

  Widget _build_temperature() {
    return card_unified(
      child: Column(children: [
        Slider.adaptive(
          value: _value!.toDouble(), min: 120, max: 360, divisions: 120,
          onChanged: _on_value, onChangeEnd: (double value) => _validate(),
        ),
        gradient_temperature(),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              ROUTINE[4].toLowerCase(),
              style: TextStyle(color: Theme.of(context).textTheme.caption!.color)
            ),
            Text(
              '${hue_to_temp(_value!)} K',
              style: TextStyle(color: Theme.of(context).colorScheme.primary)
            ),
          ],
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
        ),
      ]),
      top: 6,
    );
  }
}