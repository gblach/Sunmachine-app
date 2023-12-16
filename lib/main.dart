import 'dart:async';
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth.dart';
import 'device.dart';
import 'settings.dart';
import 'scheduler.dart';
import 'scheduler_new.dart';
import 'widgets.dart';

enum ConnStage { disconnected, connecting, discovering }

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

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
  const Main({super.key});

  @override
  MainState createState() => MainState();
}

class MainState extends State<Main> with WidgetsBindingObserver {
  List<ScanResult> _results = [];
  ConnStage _conn_stage = ConnStage.disconnected;
  StreamSubscription<List<ScanResult>>? _scan_sub;
  StreamSubscription<BluetoothConnectionState>? _conn_sub;
  bool _needs_location_service = false;
  bool _needs_new_bluetooth_perms = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if(ModalRoute.of(context)!.isCurrent) {
      switch(state) {
        case AppLifecycleState.paused: _stop_scan(); break;
        case AppLifecycleState.resumed: _start_scan(); break;
        case AppLifecycleState.inactive:
        case AppLifecycleState.detached:
        case AppLifecycleState.hidden:
      }
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      switch(state) {
        case BluetoothAdapterState.unauthorized: _bluetooth_authorize(); break;
        case BluetoothAdapterState.off: _bluetooth_enable(); break;
        case BluetoothAdapterState.on: _start_scan(); break;
        case BluetoothAdapterState.turningOff:
        case BluetoothAdapterState.turningOn:
        case BluetoothAdapterState.unavailable:
        case BluetoothAdapterState.unknown:
      }
    });

    initAsync();
    super.initState();
  }

  void initAsync() async {
    if(Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await DeviceInfoPlugin().androidInfo;
      _needs_location_service =
          23 <= androidInfo.version.sdkInt && androidInfo.version.sdkInt <= 30;
      _needs_new_bluetooth_perms = 31 <= androidInfo.version.sdkInt;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop_scan();
    super.dispose();
  }

  void _bluetooth_authorize() async {
    if(_needs_location_service) {
      Permission.locationWhenInUse.request();
    } else if(_needs_new_bluetooth_perms) {
      [ Permission.bluetoothScan, Permission.bluetoothConnect ].request();
    }
  }

  void _bluetooth_enable() {
    if(Platform.isAndroid) {
      FlutterBluePlus.turnOn();
    } else {
      ServicePopup(context, "bluetooth", () =>
          AppSettings.openAppSettings(type: AppSettingsType.bluetooth));
    }
  }

  void _location_enable() async {
    if(await Permission.locationWhenInUse.serviceStatus == ServiceStatus.disabled && mounted) {
      ServicePopup(context, "location", () =>
          AppSettings.openAppSettings(type: AppSettingsType.location));
    }
  }

  void _start_scan() {
    if(_needs_location_service) _location_enable();

    _scan_sub = FlutterBluePlus.onScanResults.listen((results) =>
        setState(() => _results = results), onError: print);

    FlutterBluePlus.startScan(
        withServices: [service_uuid],
        removeIfGone: const Duration(seconds: 3),
        continuousUpdates: true,
        androidScanMode: AndroidScanMode.balanced,
    );
  }

  Future<void> _stop_scan() async {
    await FlutterBluePlus.stopScan();
    await _scan_sub?.cancel();
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

  void _goto_device(BluetoothDevice device) {
    _stop_scan();

    _conn_sub = device.connectionState.listen((BluetoothConnectionState state) async {
      switch(state) {
        case BluetoothConnectionState.connected: _on_connected(device); break;
        case BluetoothConnectionState.disconnected: _on_disconnected(); break;
        case BluetoothConnectionState.connecting:
        case BluetoothConnectionState.disconnecting:
      }
    });

    setState(() => _conn_stage = ConnStage.connecting);
    device.connect();
  }

  Future<void> _on_connected(BluetoothDevice device) async {
    setState(() => _conn_stage = ConnStage.discovering);
    board_device = device;

    List<BluetoothService> services = await device.discoverServices();
    map_characteristics(services);
    final idv = await chr_idv.read();
    board_idv = String.fromCharCodes(idv).replaceAll('\u0000', '');

    if(!mounted) return;
    Navigator.pushNamed(context, '/device').whenComplete(() async {
      if(device.isConnected) await device.disconnect();
      await _conn_sub?.cancel();
      setState(() => _conn_stage = ConnStage.disconnected);
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
          onPressed: _conn_stage == ConnStage.disconnected ? _restart_scan : null,
        )],
      ),
      body: _build_body(),
    );
  }

  Widget _build_body() {
    switch(_conn_stage) {
      case ConnStage.disconnected:
        return _results.isEmpty ? _build_intro() : _build_list();

      case ConnStage.connecting:
        return const Loader('Connecting ...', 'Wait while connecting');

      case ConnStage.discovering:
        return const Loader('Connecting ...', 'Wait while discovering services');
    }
  }

  Widget _build_intro() {
    final bool is_light = Theme.of(context).brightness == Brightness.light;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Image.asset(is_light ? 'assets/intro.png' : 'assets/intro-dark.png',
              fit: BoxFit.contain),
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
          child: Image.asset('assets/intro-opa.png', fit: BoxFit.contain),
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
            itemCount: _results.length,
            itemBuilder: _build_list_item,
            separatorBuilder: (BuildContext context, int index) => const Divider(height: 0),
          )),
        ]),
      ]),
    );
  }

  Widget _build_list_item(BuildContext context, int index) {
    final result = _results[index];

    return Card(
      margin: const EdgeInsets.all(0),
      shape: const RoundedRectangleBorder(),
      child: ListTileTheme(
        child: ListTile(
          leading: const Icon(Icons.lightbulb_outline),
          title: Text(result.device.platformName),
          trailing: const Icon(Icons.chevron_right),
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          onTap: () => _goto_device(result.device),
        ),
      ),
    );
  }
}
