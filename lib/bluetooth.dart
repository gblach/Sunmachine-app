import 'package:flutter_blue/flutter_blue.dart';

class Characteristic {
  Characteristic._();
  static late BluetoothCharacteristic device_name;
  static late BluetoothCharacteristic idv;
  static late BluetoothCharacteristic control;
  static late BluetoothCharacteristic strip;
  static late BluetoothCharacteristic light_cur;
  static late BluetoothCharacteristic cronbuf;
  static late BluetoothCharacteristic unix_time;
  static late BluetoothCharacteristic timezone;
}

late BluetoothDevice ble_device;
late List<int> ble_control;
late List<int> ble_strip;
late List<int> ble_cronbuf;
late List<Map<String,dynamic>> board_crontab;
final int board_crontab_size = 10;

void map_characteristics(List<BluetoothService> services) {
  for(final BluetoothService s in services) {
    for(final BluetoothCharacteristic c in s.characteristics) {
      switch(c.uuid.toString().toLowerCase()) {
        case '00002a00-0000-1000-8000-00805f9b34fb':
          Characteristic.device_name = c;
          break;
        case '20163401-f704-4e77-9acc-07b7ade2d0fe':
          Characteristic.idv = c;
          break;
        case '20163402-f704-4e77-9acc-07b7ade2d0fe':
          Characteristic.control = c;
          break;
        case '20163403-f704-4e77-9acc-07b7ade2d0fe':
          Characteristic.strip = c;
          break;
        case '20163404-f704-4e77-9acc-07b7ade2d0fe':
          Characteristic.light_cur = c;
          break;
        case '20163405-f704-4e77-9acc-07b7ade2d0fe':
          Characteristic.cronbuf = c;
          break;
        case '20163406-f704-4e77-9acc-07b7ade2d0fe':
          Characteristic.unix_time = c;
          break;
        case '20163407-f704-4e77-9acc-07b7ade2d0fe':
          Characteristic.timezone = c;
          break;
      }
    }
  }
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
  if(value != null) {
    return ble_control[3] = value;
  }
  return ble_control[3];
}

int board_light([int? value]) {
  if(value != null) {
    return ble_control[4] = value;
  }
  return ble_control[4];
}

int board_speed([int? value]) {
  if(value != null) {
    return ble_control[5] = value;
  }
  return ble_control[5];
}

int board_pixlen(int chan, [int? value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) {
    ble_strip[0 + offset] = value & 0xff;
    ble_strip[1 + offset] = value >> 8;
  }
  return (ble_strip[0 + offset] | ble_strip[1 + offset] << 8);
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
