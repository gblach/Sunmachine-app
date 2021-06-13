import 'dart:async';
import 'dart:io';
import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:location/location.dart';
import 'bluetooth.dart';
import 'device.dart';
import 'settings.dart';
import 'scheduler.dart';
import 'scheduler_new.dart';
import 'widgets.dart';

enum ConnStage { connecting, discovering }

class ResultTime {
  ScanResult result;
  DateTime time;
  ResultTime(this.result, this.time);
}

void main() => runApp(App());

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunmachine',
      home: Main(),
      routes: {
        '/device': (BuildContext context) => Device(),
        '/settings': (BuildContext context) => Settings(),
        '/scheduler': (BuildContext context) => Scheduler(),
        '/scheduler/new': (BuildContext context) => SchedulerNew(),
      },
      theme: app_theme(),
    );
  }
}

class Main extends StatefulWidget {
  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> with WidgetsBindingObserver {
  static const platform = const MethodChannel('pl.blach.sunmachine/native');
  List<ResultTime> _results = [];
  ConnStage? _conn_stage;
  StreamSubscription<ScanResult>? _scan_sub;
  Timer? _cleanup_timer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(ModalRoute.of(context)!.isCurrent) {
      switch(state) {
        case AppLifecycleState.paused: _stop_scan(); break;
        case AppLifecycleState.resumed: _start_scan(); break;
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
      }
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance!.addObserver(this);
    _start_scan();
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    _stop_scan();
    super.dispose();
  }

  Future<void> _start_scan() async {
    if(Platform.isAndroid) {
      if(! await FlutterBlue.instance.isOn) {
        await platform.invokeMethod('btenable');
        while(! await FlutterBlue.instance.isOn);
      }

      AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      if(androidInfo.version.sdkInt >= 23) {
        Location location = Location();
        while(await location.hasPermission() != PermissionStatus.granted) {
          await location.requestPermission();
        }
        if(! await location.serviceEnabled()) {
          await location.requestService();
        }
      }

      _cleanup_timer = Timer.periodic(Duration(seconds: 1), _cleanup);
    }

    final Guid uuid = Guid('20163400-F704-4E77-9ACC-07B7ADE2D0FE');
    _scan_sub = FlutterBlue.instance.scan(withServices: [uuid], allowDuplicates: true)
      .listen((ScanResult result) {
      final ResultTime result_time = ResultTime(result, DateTime.now());
      int index = _results.indexWhere((ResultTime _result_time) =>
        _result_time.result.device.id == result_time.result.device.id);
      setState(() {
        if(index < 0) _results.add(result_time);
        else _results[index] = result_time;
      });
    });
  }

  void _cleanup(Timer timer) {
    DateTime limit = DateTime.now().subtract(Duration(seconds: 5));
    for(int i=_results.length-1; i>=0; i--) {
      if(_results[i].time.isBefore(limit)) setState(() => _results.removeAt(i));
    }
  }

  Future<void> _stop_scan() async {
    _scan_sub?.cancel();
    _cleanup_timer?.cancel();
    await FlutterBlue.instance.stopScan();
    setState(() => _results.clear());
  }

  Future<void> _restart_scan() async {
    if(Platform.isAndroid) {
      setState(() => _results.clear());
    } else {
      await _stop_scan();
      _start_scan();
    }
  }

  Future<void> _goto_device(int index) async {
    late StreamSubscription<BluetoothDeviceState> _conn_sub;
    ble_device = _results[index].result.device;
    _stop_scan();

    setState(() => _conn_stage = ConnStage.connecting);
    await ble_device.connect(autoConnect: false);
    _conn_sub = ble_device.state.listen((BluetoothDeviceState state) {
      if(state == BluetoothDeviceState.disconnected) {
        Navigator.popUntil(context, ModalRoute.withName('/'));
      }
    });

    setState(() => _conn_stage = ConnStage.discovering);
    map_characteristics(await ble_device.discoverServices());
    await ble_device.requestMtu(251);

    Future.delayed(Duration(milliseconds: 500), () =>
      Navigator.pushNamed(context, '/device').whenComplete(() async {
        _conn_sub.cancel();
        await ble_device.disconnect();
        setState(() => _conn_stage = null);
        _start_scan();
      })
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sunmachine'),
        actions: [IconButton(
          icon: icon_adaptive(Icons.refresh, CupertinoIcons.refresh),
          onPressed: _conn_stage == null ? _restart_scan : null,
        )],
      ),
      body: _build_body(),
    );
  }

  Widget _build_body() {
    switch(_conn_stage) {
      case ConnStage.connecting:
        return loader('Connecting ...', 'Wait while connecting');

      case ConnStage.discovering:
        return loader('Connecting ...', 'Wait while discovering services');

      case null:
        return _results.isEmpty ? _build_intro() : _build_list();
    }
  }

  Widget _build_intro() {
    return Column(
      children: [
        Padding(
          child: Image.asset('intro.png', fit: BoxFit.contain),
          padding: EdgeInsets.symmetric(horizontal: 20),
        ),
        Text(
          'No light sources found',
          style: TextStyle(color: Theme.of(context).accentColor, fontSize: 18),
        ),
        Text(
          'Wait while looking for light sources.\nThis should take a few seconds.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5),
        ),
      ],
      mainAxisAlignment: MainAxisAlignment.spaceAround,
    );
  }

  Widget _build_list() {
    double top = (MediaQuery.of(context).size.height - MediaQuery.of(context).size.width) / 3;

    return RefreshIndicator(
      child: Stack(children: [
        Center(child: Padding(
          child: Image.asset('intro-opa.png', fit: BoxFit.contain),
          padding: EdgeInsets.only(top: top, left: 20, right: 20),
        )),
        Column(children: [
          Container(
            child: Align(
              child: Text(
                'Light sources',
                style: TextStyle(color: Theme.of(context).textTheme.caption!.color),
              ),
              alignment: Alignment.centerLeft,
            ),
            color: Theme.of(context).cardTheme.color,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          Expanded(child: ListView.separated(
            itemCount: _results.length,
            itemBuilder: _build_list_item,
            separatorBuilder: (BuildContext context, int index) => Divider(height: 0),
          )),
        ]),
      ]),
      onRefresh: _restart_scan,
    );
  }

  Widget _build_list_item(BuildContext context, int index) {
    return Card(
      child: ListTileTheme(
         child: ListTile(
          leading: icon_adaptive(Icons.lightbulb_outline, CupertinoIcons.lightbulb),
          title: Text(_results[index].result.device.name),
          trailing: icon_adaptive(Icons.chevron_right, CupertinoIcons.chevron_right),
          contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          onTap: () => _goto_device(index),
        ),
        iconColor: Theme.of(context).iconTheme.color,
      ),
      margin: EdgeInsets.all(0),
      shape: RoundedRectangleBorder(),
    );
  }
}