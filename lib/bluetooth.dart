import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_ble_lib/flutter_ble_lib.dart';

ScanResult ble_device;
Uint8List ble_control;
Uint8List ble_strip;
Uint8List ble_cronbuf;
List<Map<String,dynamic>> board_crontab;
final int board_crontab_size = 10;

String uuid([int xx=0]) {
  if(xx < 256) {
    String XX = xx.toRadixString(16).padLeft(2, '0');
    return '201634${XX}-F704-4E77-9ACC-07B7ADE2D0FE';
  } else {
    String XXXX = xx.toRadixString(16).padLeft(4, '0');
    return '0000${XXXX}-0000-1000-8000-00805F9B34FB';
  }
}

Future<Uint8List> ble_read(BuildContext context, int chr_id) async {
  try {
    CharacteristicWithValue data =
      await ble_device.peripheral.readCharacteristic(uuid(), uuid(chr_id));
    switch(chr_id) {
      case 0x01: ble_control = data.value; break;
      case 0x02: ble_strip = data.value; break;
      case 0x04: ble_cronbuf = data.value; break;
    }
    return data.value;
  } on BleError {
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }
}

void ble_write(BuildContext context, int chr_id, [Uint8List value0]) async {
  try {
    Uint8List value = value0;
    if(value == null) {
      switch(chr_id) {
        case 0x01: value = ble_control; break;
        case 0x02: value = ble_strip; break;
        case 0x04: value = ble_cronbuf; break;
      }
    }
    if(value != null) {
      await ble_device.peripheral.writeCharacteristic(uuid(), uuid(chr_id), value, true);
    }
  } on BleError {
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }
}

Future<String> ble_read_name(BuildContext context) async {
  if(Platform.isIOS) {
    return ble_device.peripheral.name;
  } else {
    try {
      CharacteristicWithValue data =
        await ble_device.peripheral.readCharacteristic(uuid(0x1800), uuid(0x2a00));
      return String.fromCharCodes(data.value);
    } on BleError {
      Navigator.popUntil(context, ModalRoute.withName('/'));
    }
  }
}

void ble_write_name(BuildContext context, String value) async {
  try {
    await ble_device.peripheral.writeCharacteristic(
      uuid(0x1800), uuid(0x2a00), Uint8List.fromList(value.codeUnits), true);
  } on BleError {
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }
}

StreamSubscription<CharacteristicWithValue> ble_monitor(int chr_id, ValueSetter<Uint8List> callback) {
  return ble_device.peripheral.monitorCharacteristic(uuid(), uuid(chr_id))
    .listen((CharacteristicWithValue data) => callback(data.value));
}

bool board_channel(int chan, [bool value]) {
  if(value != null) {
    if(value) ble_control[0] ^= 0x10 << chan;
    else ble_control[0] &= ~(0x10 << chan);
    return value;
  }
  return ble_control[0] & (0x10 << chan) != 0;
}

int board_mode([int value]) {
  if(value != null) {
    ble_control[0] = (ble_control[0] & 0xf0) + value;
  }
  return ble_control[0] & 0x0f;
}

int board_brightness(int chan, [int value]) {
  if(chan < 2) {
    if(value != null) {
      return ble_control[chan+1] = value;
    }
    return ble_control[chan+1];
  } else {
    if(value != null) {
      return ble_strip[5 + (chan-2) * 6] = value;
    }
    return ble_strip[5 + (chan-2) * 6];
  }
}

int board_hue(int chan, [int value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) {
    ble_strip[2 + offset] = value & 0xff;
    ble_strip[3 + offset] = value >> 8;
    return value;
  }
  return (ble_strip[2 + offset] | ble_strip[3 + offset] << 8);
}

int board_saturation(int chan, [int value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) {
    return ble_strip[4 + offset] = value;
  }
  return ble_strip[4 + offset];
}

int board_timeout([int value]) {
  if(value != null) {
    return ble_control[3] = value;
  }
  return ble_control[3];
}

int board_light([int value]) {
  if(value != null) {
    return ble_control[4] = value;
  }
  return ble_control[4];
}

int board_speed([int value]) {
  if(value != null) {
    return ble_control[5] = value;
  }
  return ble_control[5];
}

int board_pixlen(int chan, [int value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) {
    ble_strip[0 + offset] = value & 0xff;
    ble_strip[1 + offset] = value >> 8;
  }
  return (ble_strip[0 + offset] | ble_strip[1 + offset] << 8);
}

int board_pixtype(int chan, [int value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) {
    ble_strip[4 + offset] = value == 0 ? 100 : 250;
  }
  return ble_strip[4 + offset] <= 100 ? 0 : 1;
}

void board_cronbuf_to_crontab() {
  board_crontab = [];
  for(int i=0; i<board_crontab_size; i++) {
    int offset = i * 4;
    if(ble_cronbuf[0 + offset] != 0) {
      board_crontab.add({
        'enabled': ble_cronbuf[0 + offset] >> 7,
        'dow': ble_cronbuf[0 + offset] & 0x7f,
        'hh': ble_cronbuf[1 + offset] >> 3,
        'mm': (ble_cronbuf[1 + offset] & 0x07) << 3 | ble_cronbuf[2 + offset] >> 5,
        'routine': (ble_cronbuf[2 + offset] & 0x18) >> 3,
        'chan': (ble_cronbuf[2 + offset] & 0x06) >> 1,
        'value': (ble_cronbuf[2 + offset] & 0x01) << 8 | ble_cronbuf[3 + offset],
      });
    }
  }
}

void board_crontab_to_cronbuf() {
  ble_cronbuf.fillRange(0, 40, 0);
  for(int i=0; i<board_crontab.length; i++) {
    int offset = i * 4;
    Map<String,dynamic> job = board_crontab[i];
    ble_cronbuf[0 + offset] = job['enabled'] << 7 | job['dow'];
    ble_cronbuf[1 + offset] = job['hh'] << 3 | job['mm'] >> 3;
    ble_cronbuf[2 + offset] = job['mm'] << 5 | job['routine'] << 3 | job['chan'] << 1 | job['value'] >> 8;
    ble_cronbuf[3 + offset] = job['value'] & 0xff;
  }
}
