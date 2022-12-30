import 'dart:async';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
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
      theme: app_theme(Brightness.light),
      darkTheme: app_theme(Brightness.dark),
    );
  }
}

class Main extends StatefulWidget {
  const Main({Key? key}) : super(key: key);

  @override
  MainState createState() => MainState();
}

class MainState extends State<Main> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    ble = FlutterReactiveBle();
    ble.statusStream.listen((BleStatus status) {
      switch(status) {
        case BleStatus.unauthorized: _ask_for_permissions(); break;
        case BleStatus.poweredOff: _bluetooth_enable(); break;
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
    WidgetsBinding.instance.removeObserver(this);
    _stop_scan();
    super.dispose();
  }

  Future<void> _ask_for_permissions() async {
    if(Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      if(23 <= androidInfo.version.sdkInt && androidInfo.version.sdkInt <= 30) {
        if(await Permission.locationWhenInUse.isDenied) {
          await Permission.locationWhenInUse.request();
        }
      } else if(31 <= androidInfo.version.sdkInt) {
        if(await Permission.bluetoothScan.isDenied || await Permission.bluetoothConnect.isDenied) {
          await [ Permission.bluetoothScan, Permission.bluetoothConnect ].request();
        }
      }
    }
  }

  void _bluetooth_enable() async {
    await AppSettings.openBluetoothSettings();
  }

  Future<void> _location_enable() async {
    await AppSettings.openLocationSettings();
  }

  void _start_scan() async {
    bool require_location_services = true;
    if(Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      require_location_services =
          23 <= androidInfo.version.sdkInt && androidInfo.version.sdkInt <= 30;
      _cleanup_timer = Timer.periodic(const Duration(seconds: 1), _cleanup);
    }
    _scan_sub = ble.scanForDevices(withServices: [service_uuid],
        requireLocationServicesEnabled: require_location_services)
        .listen(_on_device_found, onError: print);
  }

  void _on_device_found(DiscoveredDevice device) {
    final DeviceTime device_time = DeviceTime(device, DateTime.now());
    int index = _devices.indexWhere((DeviceTime device_time_idx) =>
      device_time.device.id == device_time_idx.device.id);
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

    if(!mounted) return;
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
          icon: const Icon(Icons.refresh),
          onPressed: _conn_stage == null ? _restart_scan : null,
        )],
      ),
      body: _build_body(),
    );
  }

  Widget _build_body() {
    switch(_conn_stage) {
      case ConnStage.connecting:
        return const Loader('Connecting ...', 'Wait while connecting');

      case ConnStage.discovering:
        return const Loader('Connecting ...', 'Wait while discovering services');

      case null:
        return _devices.isEmpty ? _build_intro() : _build_list();
    }
  }

  Widget _build_intro() {
    final bool is_light = Theme.of(context).brightness == Brightness.light;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Image.asset(is_light ? 'intro.png' : 'intro-dark.png', fit: BoxFit.contain),
        ),
        Text('No light sources found',
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                color: Theme.of(context).colorScheme.primary)),
        const Text(
          'Wait while looking for light sources.\nThis should take a few seconds.',
          textAlign: TextAlign.center,
          style: TextStyle(height: 1.5),
        ),
      ],
    );
  }

  Widget _build_list() {
    final Size size = MediaQuery.of(context).size;
    final double top = (size.height - size.width) / 3;

    return RefreshIndicator(
      onRefresh: _restart_scan,
      child: Stack(children: [
        Center(child: Padding(
          padding: EdgeInsets.only(top: top, left: 20, right: 20),
          child: Image.asset('intro-opa.png', fit: BoxFit.contain),
        )),
        Column(children: [
          Container(
            color: Theme.of(context).colorScheme.background,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Light sources',
                  style: TextStyle(color: Theme.of(context).colorScheme.onBackground)),
            ),
          ),
          Expanded(child: ListView.separated(
            itemCount: _devices.length,
            itemBuilder: _build_list_item,
            separatorBuilder: (BuildContext context, int index) => const Divider(height: 0),
          )),
        ]),
      ]),
    );
  }

  Widget _build_list_item(BuildContext context, int index) {
    return Card(
      margin: const EdgeInsets.all(0),
      shape: const RoundedRectangleBorder(),
      child: ListTileTheme(
         child: ListTile(
          leading: const Icon(Icons.lightbulb_outline),
          title: Text(_devices[index].device.name),
          trailing: const Icon(Icons.chevron_right),
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          onTap: () => _goto_device(index),
        ),
      ),
    );
  }
}
