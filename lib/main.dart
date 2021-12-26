import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:location/location.dart';
import 'bluetooth.dart';
import 'device.dart';
import 'settings.dart';
import 'scheduler.dart';
import 'scheduler_new.dart';
import 'widgets.dart';

enum ConnStage { connecting, discovering }

class DeviceTime {
  DiscoveredDevice device;
  DateTime time;
  DeviceTime(this.device, this.time);
}

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunmachine',
      home: const Main(),
      routes: {
        '/device': (BuildContext context) => const Device(),
        '/settings': (BuildContext context) => const Settings(),
        '/scheduler': (BuildContext context) => const Scheduler(),
        '/scheduler/new': (BuildContext context) => const SchedulerNew(),
      },
      theme: app_theme(),
    );
  }
}

class Main extends StatefulWidget {
  const Main({Key? key}) : super(key: key);

  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> with WidgetsBindingObserver {
  static const platform = MethodChannel('pl.blach.sunmachine/native');
  final List<DeviceTime> _devices = [];
  ConnStage? _conn_stage;
  StreamSubscription<DiscoveredDevice>? _scan_sub;
  late StreamSubscription<void> _conn_sub;
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
    ble = FlutterReactiveBle();
    ble.statusStream.listen((BleStatus status) {
      switch(status) {
        case BleStatus.poweredOff: _bluetooth_enable(); break;
        case BleStatus.unauthorized: _location_permission(); break;
        case BleStatus.locationServicesDisabled: _location_enable(); break;
        case BleStatus.ready: _start_scan(); break;
        case BleStatus.unsupported:
        case BleStatus.unknown:
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    _stop_scan();
    super.dispose();
  }

  void _bluetooth_enable() {
    if(Platform.isAndroid) {
      platform.invokeMethod('btenable');
    }
  }

  Future<void> _location_permission() async {
    if(Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      if(23 <= androidInfo.version.sdkInt! && androidInfo.version.sdkInt! <= 30) {
        Location location = Location();
        while(await location.hasPermission() != PermissionStatus.granted) {
          await location.requestPermission();
        }
      }
    }
  }

  Future<void> _location_enable() async {
    if(Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      if(23 <= androidInfo.version.sdkInt! && androidInfo.version.sdkInt! <= 30) {
        Location location = Location();
        if(! await location.serviceEnabled()) {
          await location.requestService();
        }
      }
    }
  }

  void _start_scan() {
    if(Platform.isAndroid) {
      _cleanup_timer = Timer.periodic(const Duration(seconds: 1), _cleanup);
    }

    _scan_sub = ble.scanForDevices(withServices: [service_uuid])
      .listen(_on_device_found, onError: print);
  }

  void _on_device_found(DiscoveredDevice device) {
    final DeviceTime device_time = DeviceTime(device, DateTime.now());
    int index = _devices.indexWhere((DeviceTime _device_time) =>
      _device_time.device.id == device_time.device.id);
    setState(() {
      if(index < 0) _devices.add(device_time);
      else _devices[index] = device_time;
    });
  }

  void _cleanup(Timer timer) {
    DateTime limit = DateTime.now().subtract(const Duration(seconds: 5));
    for(int i=_devices.length-1; i>=0; i--) {
      if(_devices[i].time.isBefore(limit)) setState(() => _devices.removeAt(i));
    }
  }

  Future<void> _stop_scan() async {
    await _scan_sub?.cancel();
    _cleanup_timer?.cancel();
    setState(() => _devices.clear());
  }

  Future<void> _restart_scan() async {
    if(Platform.isAndroid) {
      setState(() => _devices.clear());
    } else {
      await _stop_scan();
      _start_scan();
    }
  }

  Future<void> _goto_device(int index) async {
    ble_device = _devices[index].device;
    _stop_scan();

    setState(() => _conn_stage = ConnStage.connecting);
    _conn_sub = ble.connectToDevice(
      id: ble_device.id,
      connectionTimeout: const Duration(seconds: 2),
    ).listen((ConnectionStateUpdate state) async {
      switch(state.connectionState) {
        case DeviceConnectionState.connected: _on_connected(); break;
        case DeviceConnectionState.disconnected: _on_disconnected(); break;
        case DeviceConnectionState.connecting:
        case DeviceConnectionState.disconnecting:
      }
    }, onError: print);
  }

  Future<void> _on_connected() async {
    setState(() => _conn_stage = ConnStage.discovering);
    await ble.requestMtu(deviceId: ble_device.id, mtu: 251);
    map_characteristics(await ble.discoverServices(ble_device.id));
    final idv = await ble.readCharacteristic(Characteristic.idv);
    board_idv = String.fromCharCodes(idv).replaceAll('\u0000', '');

    Navigator.pushNamed(context, '/device').whenComplete(() async {
      await _conn_sub.cancel();
      setState(() => _conn_stage = null);
      _start_scan();
    });
  }

  void _on_disconnected() {
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sunmachine'),
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
        return _devices.isEmpty ? _build_intro() : _build_list();
    }
  }

  Widget _build_intro() {
    return Column(
      children: [
        Padding(
          child: Image.asset('intro.png', fit: BoxFit.contain),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        Text(
          'No light sources found',
          style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 18),
        ),
        const Text(
          'Wait while looking for light sources.\nThis should take a few seconds.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5),
        ),
      ],
      mainAxisAlignment: MainAxisAlignment.spaceAround,
    );
  }

  Widget _build_list() {
    Size size = MediaQuery.of(context).size;
    double top = (size.height - size.width) / 3;

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
                style: TextStyle(color: Colors.grey[100]),
              ),
              alignment: Alignment.centerLeft,
            ),
            color: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
          Expanded(child: ListView.separated(
            itemCount: _devices.length,
            itemBuilder: _build_list_item,
            separatorBuilder: (BuildContext context, int index) => const Divider(height: 0),
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
          title: Text(_devices[index].device.name),
          trailing: icon_adaptive(Icons.chevron_right, CupertinoIcons.chevron_right),
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          onTap: () => _goto_device(index),
        ),
        iconColor: Theme.of(context).iconTheme.color,
      ),
      margin: const EdgeInsets.all(0),
      shape: const RoundedRectangleBorder(),
    );
  }
}