import 'dart:io';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'bluetooth.dart';
import 'widgets.dart';

class Scheduler extends StatefulWidget {
  const Scheduler({Key? key}) : super(key: key);

  @override
  _SchedulerState createState() => _SchedulerState();
}

class _SchedulerState extends State<Scheduler> {
  bool _mutex = true;

  @override
  void initState() async {
    initAsync();
    super.initState();
  }

  void initAsync() async {
    ble_cronbuf = await ble.readCharacteristic(Characteristic.cronbuf);
    board_cronbuf_to_crontab();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _mutex = false;

      for(int i=0; i<board_crontab.length; i++) {
        Map<String,dynamic> job = board_crontab[i];
        job['_key'] = 'job-#$i';

        switch(job['routine']) {
          case 0:
            job['_title_1'] = ROUTINE[job['routine']];
            job['_title_2'] = MODE[job['value']];
            break;

          case 1:
          case 3:
            job['_title_1'] = ROUTINE[job['routine']];
            job['_title_2'] = '${job['value']} %';
            break;

          case 2:
            switch(board_pixtype(job['chan'])) {
              case 0:
                job['_title_1'] = ROUTINE[job['routine']];
                job['_title_2'] = '${job['value']} \u00B0';
                break;

              case 1:
                job['_title_1'] = ROUTINE[4];
                job['_title_2'] = '${hue_to_temp(job['value'])} K';
                break;

              default:
                job['_title_1'] = job['_title_2'] = '';
            }
            break;

          default:
            job['_title_1'] = job['_title_2'] = '';
        }

        if(board_idv == 'SMA1' && job['routine'] > 0) {
          job['_title_1'] += ' #${job['chan']+1}';
        }

        int days = 0;
        String dow = '';
        for(int j=0; j<7; j++) {
          days += job['dow'] & pow(2, j) != 0 ? 1 : 0;
        }
        for(int j=0; j<7; j++) {
          if(job['dow'] & pow(2, j) != 0) {
            if(dow.isNotEmpty) dow += ', ';
            dow += days <= 3 ? DOW_LONG[j] : DOW_SHORT[j];
          }
        }
        job['_subtitle'] = '${job['hh']}:${job['mm'].toString().padLeft(2, '0')}\n$dow';
      }
    });
  }

  void _on_state(String key, bool state) async {
    final int index = board_crontab.indexWhere((dynamic job) => job['_key'] == key);
    setState(() => board_crontab[index]['enabled'] = state ? 1 : 0);
    board_crontab_to_cronbuf();
    characteristic_write(Characteristic.cronbuf);
  }

  void _on_delete(String key) async {
    final int index = board_crontab.indexWhere((dynamic job) => job['_key'] == key);
    setState(() => board_crontab.removeAt(index));
    board_crontab_to_cronbuf();
    characteristic_write(Characteristic.cronbuf);
  }

  void _goto_scheduler_new() {
    Navigator.pushNamed(context, '/scheduler/new').whenComplete(_refresh);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(ble_device.name),
        actions: [IconButton(
          icon: icon_adaptive(Icons.add, CupertinoIcons.add),
          onPressed: _mutex || board_crontab.length >= board_crontab_size
            ? null : _goto_scheduler_new,
        )],
      ),
      body: _mutex ? loader('Loading schedules ...') : _build_body(),
    );
  }

  Widget _build_body() {
    if(board_crontab.isEmpty) return _build_new();
    return _build_list();
  }

  Widget _build_new() {
    return Column(
      children: [
        Padding(
          child: Image.asset('intro.png', fit: BoxFit.contain),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        Text(
          'No scheduled tasks found',
          style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 18)
        ),
        const Padding(
          child: Text(
            'You can schedule a change of operating mode, brightness, hue, saturation and/or temperature.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5),
          ),
          padding: EdgeInsets.symmetric(horizontal: 20),
        ),
        big_button_adaptive(context,
          'Create a new task', Icons.add, _goto_scheduler_new),
      ],
      mainAxisAlignment: MainAxisAlignment.spaceAround,
    );
  }

  Widget _build_list() {
    double top = (MediaQuery.of(context).size.height - MediaQuery.of(context).size.width) / 3;

    return Stack(children: [
      Center(child: Padding(
        child: Image.asset('intro-opa.png', fit: BoxFit.contain),
        padding: EdgeInsets.only(top: top, left: 20, right: 20),
      )),
      ListView.builder(
        itemCount: board_crontab.length,
        itemBuilder: build_list_item,
      ),
    ]);
  }

  Widget build_list_item(BuildContext context, int index) {
    Map<String,dynamic> job = board_crontab[index];

    return Dismissible(
      key: Key(job['_key']),
      child: card_unified_nopad(child: ListTile(
        leading: Switch.adaptive(
          value: job['enabled'] != 0,
          activeColor: Theme.of(context).colorScheme.secondary,
          onChanged: (bool state) => _on_state(job['_key'], state),
        ),
        title: RichText(
          text: TextSpan(
            text: job['_title_1'],
            style: Theme.of(context).textTheme.subtitle1,
            children: <TextSpan>[
              TextSpan(
                text: Platform.isIOS ? '  \u2192  ' : '  \u279E  ',
                style: const TextStyle(color: Colors.grey)),
              TextSpan(text: job['_title_2']),
            ],
          ),
        ),
        subtitle: Text(job['_subtitle'], textAlign: TextAlign.end),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 12, left: 8, right: 16),
      )),
      direction: DismissDirection.endToStart,
      onDismissed: (DismissDirection direction) => _on_delete(job['_key']),
    );
  }
}
