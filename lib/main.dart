import 'dart:async';
import 'dart:io';
import 'package:device_info/device_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';
import 'package:location/location.dart';
import 'bluetooth.dart';
import 'device.dart';
import 'settings.dart';
import 'scheduler.dart';
import 'scheduler_new.dart';
import 'widgets.dart';

enum Connection { connecting, discovering }

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
  BleManager _bleManager = BleManager();
  List<ResultTime> _results = [];
  Connection _connection = null;
  StreamSubscription<PeripheralConnectionState> _conn_sub;
  Timer _cleanup_timer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(ModalRoute.of(context).isCurrent) {
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
    WidgetsBinding.instance.addObserver(this);
    initStateAsync();
    super.initState();
  }

  void initStateAsync() async {
    await _bleManager.createClient();
    _start_scan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop_scan();
    _bleManager.destroyClient();
    super.dispose();
  }

  Future<void> _start_scan() async {
    if(Platform.isAndroid) {
      if(await _bleManager.bluetoothState() == BluetoothState.POWERED_OFF) {
        await _bleManager.enableRadio();
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

    _bleManager.startPeripheralScan(scanMode: ScanMode.balanced, uuids: [uuid()])
      .listen((ScanResult result0) {
        ResultTime result1 = ResultTime(result0, DateTime.now());
        int index = _results.indexWhere((ResultTime result2) =>
          result1.result.peripheral.identifier == result2.result.peripheral.identifier);
        if(index < 0) setState(() => _results.add(result1));
        else _results[index] = result1;
      });
  }

  void _cleanup(Timer timer) {
    DateTime limit = DateTime.now().subtract(Duration(seconds: 5));
    for(int i=_results.length-1; i>=0; i--) {
      if(_results[i].time.isBefore(limit)) setState(() => _results.removeAt(i));
    }
  }

  Future<void> _stop_scan() async {
    _cleanup_timer?.cancel();
    await _bleManager.stopPeripheralScan();
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
    ble_device = _results[index].result;
    _stop_scan();

    try {
      setState(() => _connection = Connection.connecting);
      await ble_device.peripheral.connect(requestMtu: 160, timeout: Duration(seconds: 15));
      _conn_sub = ble_device.peripheral.observeConnectionState(completeOnDisconnect: true)
        .listen((PeripheralConnectionState state) {
          if(state == PeripheralConnectionState.disconnected) {
            Navigator.popUntil(context, ModalRoute.withName('/'));
          }
        });

      setState(() => _connection = Connection.discovering);
      await ble_device.peripheral.discoverAllServicesAndCharacteristics();

      Navigator.pushNamed(context, '/device').whenComplete(() async {
        _conn_sub?.cancel();
        if(await ble_device.peripheral.isConnected()) {
          await ble_device.peripheral.disconnectOrCancelConnection();
          ble_device = null;
        }
        setState(() => _connection = null);
        _start_scan();
      });
    } on BleError {
      _conn_sub?.cancel();
      ble_device = null;
      setState(() => _connection = null);
      _start_scan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sunmachine'),
        actions: [IconButton(
          icon: icon_adaptive(Icons.refresh, CupertinoIcons.refresh),
          onPressed: _connection == null ? _restart_scan : null,
        )],
      ),
      body: _build_body(),
    );
  }

  Widget _build_body() {
    if(_connection != null) {
      switch(_connection) {
        case Connection.connecting: return loader('Connecting ...', 'Wait while connecting');
        case Connection.discovering: return loader('Connecting ...', 'Wait while discovering services');
      }
    }
    if(_results.length == 0) return _build_intro();
    return _build_list();
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
          style: TextStyle(color: Theme.of(context).accentColor, fontSize: 18)
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
                style: TextStyle(color: Theme.of(context).textTheme.caption.color),
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
          title: Text(_results[index].result.peripheral.name),
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