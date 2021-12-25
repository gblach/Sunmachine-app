import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

Uuid service_uuid = Uuid.parse('20163400-f704-4e77-9acc-07b7ade2d0fe');

class Characteristic {
  Characteristic._();
  static late QualifiedCharacteristic device_name;
  static late QualifiedCharacteristic idv;
  static late QualifiedCharacteristic control;
  static late QualifiedCharacteristic strip;
  static late QualifiedCharacteristic light_cur;
  static late QualifiedCharacteristic cronbuf;
  static late QualifiedCharacteristic unix_time;
  static late QualifiedCharacteristic timezone;
}

late FlutterReactiveBle ble;
late DiscoveredDevice ble_device;
late String board_idv;
late List<int> ble_control;
late List<int> ble_strip;
late List<int> ble_cronbuf;
late List<Map<String,dynamic>> board_crontab;
const int board_crontab_size = 10;

void map_characteristics(List<DiscoveredService> services) {
  for(final DiscoveredService s in services) {
    for(final Uuid c in s.characteristicIds) {
      QualifiedCharacteristic qc = QualifiedCharacteristic(
        deviceId: ble_device.id, serviceId: s.serviceId, characteristicId: c);
      switch(c.toString()) {
        case '00002a00-0000-1000-8000-00805f9b34fb': Characteristic.device_name = qc; break;
        case '20163401-f704-4e77-9acc-07b7ade2d0fe': Characteristic.idv = qc; break;
        case '20163402-f704-4e77-9acc-07b7ade2d0fe': Characteristic.control = qc; break;
        case '20163403-f704-4e77-9acc-07b7ade2d0fe': Characteristic.strip = qc; break;
        case '20163404-f704-4e77-9acc-07b7ade2d0fe': Characteristic.light_cur = qc; break;
        case '20163405-f704-4e77-9acc-07b7ade2d0fe': Characteristic.cronbuf = qc; break;
        case '20163406-f704-4e77-9acc-07b7ade2d0fe': Characteristic.unix_time = qc; break;
        case '20163407-f704-4e77-9acc-07b7ade2d0fe': Characteristic.timezone = qc; break;
      }
    }
  }
}

void characteristic_write(QualifiedCharacteristic qc, [List<int>? value0]) {
  late List<int> value;
  if(value0 != null) value = value0;
  else if(qc == Characteristic.control) value = ble_control;
  else if(qc == Characteristic.strip) value = ble_strip;
  else if(qc == Characteristic.cronbuf) value = ble_cronbuf;
  ble.writeCharacteristicWithResponse(qc, value: value);
}

bool board_channel(int chan, [bool? value]) {
  if(value != null) {
    if(value) ble_control[0] ^= 0x10 << chan;
    else ble_control[0] &= ~(0x10 << chan);
    return value;
  }
  return ble_control[0] & (0x10 << chan) != 0;
}

int board_mode([int? value]) {
  if(value != null) {
    ble_control[0] = (ble_control[0] & 0xf0) + value;
  }
  return ble_control[0] & 0x0f;
}

int board_brightness(int chan, [int? value]) {
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

int board_hue(int chan, [int? value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) {
    ble_strip[2 + offset] = value & 0xff;
    ble_strip[3 + offset] = value >> 8;
    return value;
  }
  return (ble_strip[2 + offset] | ble_strip[3 + offset] << 8);
}

int board_saturation(int chan, [int? value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) {
    return ble_strip[4 + offset] = value;
  }
  return ble_strip[4 + offset];
}

int board_timeout([int? value]) {
  final int idx = ble_control.length - 3;
  if(value != null) {
    return ble_control[idx] = value;
  }
  return ble_control[idx];
}

int board_light([int? value]) {
  final int idx = ble_control.length - 2;
  if(value != null) {
    return ble_control[idx] = value;
  }
  return ble_control[idx];
}

int board_speed([int? value]) {
  final int idx = ble_control.length - 1;
  if(value != null) {
    return ble_control[idx] = value;
  }
  return ble_control[idx];
}

int board_pixlen(int chan, [int? value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) {
    ble_strip[0 + offset] = value & 0xff;
    ble_strip[1 + offset] = value >> 8;
  }
  return ble_strip[0 + offset] | ble_strip[1 + offset] << 8;
}

int board_pixtype(int chan, [int? value]) {
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
  ble_cronbuf.fillRange(0, board_crontab_size * 4, 0);
  for(int i=0; i<board_crontab.length; i++) {
    int offset = i * 4;
    Map<String,dynamic> job = board_crontab[i];
    ble_cronbuf[0 + offset] = job['enabled'] << 7 | job['dow'];
    ble_cronbuf[1 + offset] = job['hh'] << 3 | job['mm'] >> 3;
    ble_cronbuf[2 + offset] = job['mm'] << 5 | job['routine'] << 3 | job['chan'] << 1 | job['value'] >> 8;
    ble_cronbuf[3 + offset] = job['value'] & 0xff;
  }
}