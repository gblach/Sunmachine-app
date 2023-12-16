import 'package:flutter_blue_plus/flutter_blue_plus.dart';

Guid service_uuid = Guid('20163400-f704-4e77-9acc-07b7ade2d0fe');

late BluetoothDevice board_device;
late String board_idv;
late List<int> board_control;
late List<int> board_strip;
late List<int> board_cronbuf;
late List<Map<String,dynamic>> board_crontab;
const int board_crontab_size = 10;

late BluetoothCharacteristic chr_device_name;
late BluetoothCharacteristic chr_idv;
late BluetoothCharacteristic chr_control;
late BluetoothCharacteristic chr_strip;
late BluetoothCharacteristic chr_light_cur;
late BluetoothCharacteristic chr_cronbuf;
late BluetoothCharacteristic chr_unix_time;
late BluetoothCharacteristic chr_timezone;

void map_characteristics(List<BluetoothService> services) {
  for(final BluetoothService srv in services) {
    for(final BluetoothCharacteristic chr in srv.characteristics) {
      switch(chr.uuid.str) {
        case '2a00': chr_device_name = chr; break;
        case '20163401-f704-4e77-9acc-07b7ade2d0fe': chr_idv = chr; break;
        case '20163402-f704-4e77-9acc-07b7ade2d0fe': chr_control = chr; break;
        case '20163403-f704-4e77-9acc-07b7ade2d0fe': chr_strip = chr; break;
        case '20163404-f704-4e77-9acc-07b7ade2d0fe': chr_light_cur = chr; break;
        case '20163405-f704-4e77-9acc-07b7ade2d0fe': chr_cronbuf = chr; break;
        case '20163406-f704-4e77-9acc-07b7ade2d0fe': chr_unix_time = chr; break;
        case '20163407-f704-4e77-9acc-07b7ade2d0fe': chr_timezone = chr; break;
      }
    }
  }
}

bool board_channel(int chan, [bool? value]) {
  if(value != null) {
    if(value) board_control[0] ^= 0x10 << chan;
    else board_control[0] &= ~(0x10 << chan);
    return value;
  }
  return board_control[0] & (0x10 << chan) != 0;
}

int board_mode([int? value]) {
  if(value != null) board_control[0] = (board_control[0] & 0xf0) + value;
  return board_control[0] & 0x0f;
}

int board_brightness(int chan, [int? value]) {
  if(chan < 2) {
    if(value != null) return board_control[chan+1] = value;
    return board_control[chan+1];
  } else {
    if(value != null) return board_strip[5 + (chan-2) * 6] = value;
    return board_strip[5 + (chan-2) * 6];
  }
}

int board_hue(int chan, [int? value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) {
    board_strip[2 + offset] = value & 0xff;
    board_strip[3 + offset] = value >> 8;
    return value;
  }
  return (board_strip[2 + offset] | board_strip[3 + offset] << 8);
}

int board_saturation(int chan, [int? value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) return board_strip[4 + offset] = value;
  return board_strip[4 + offset];
}

int board_timeout([int? value]) {
  final int idx = board_control.length - 3;
  if(value != null) return board_control[idx] = value;
  return board_control[idx];
}

int board_light([int? value]) {
  final int idx = board_control.length - 2;
  if(value != null) return board_control[idx] = value;
  return board_control[idx];
}

int board_speed([int? value]) {
  final int idx = board_control.length - 1;
  if(value != null) return board_control[idx] = value;
  return board_control[idx];
}

int board_pixlen(int chan, [int? value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) {
    board_strip[0 + offset] = value & 0xff;
    board_strip[1 + offset] = value >> 8;
  }
  return board_strip[0 + offset] | board_strip[1 + offset] << 8;
}

int board_pixtype(int chan, [int? value]) {
  if(chan < 2) return -1;
  int offset = (chan - 2) * 6;
  if(value != null) board_strip[4 + offset] = value == 0 ? 100 : 250;
  return board_strip[4 + offset] <= 100 ? 0 : 1;
}

void board_cronbuf_to_crontab() {
  board_crontab = [];
  for(int i=0; i<board_crontab_size; i++) {
    int offset = i * 4;
    if(board_cronbuf[0 + offset] != 0) {
      board_crontab.add({
        'enabled': board_cronbuf[0 + offset] >> 7,
        'dow': board_cronbuf[0 + offset] & 0x7f,
        'hh': board_cronbuf[1 + offset] >> 3,
        'mm': (board_cronbuf[1 + offset] & 0x07) << 3 | board_cronbuf[2 + offset] >> 5,
        'routine': (board_cronbuf[2 + offset] & 0x18) >> 3,
        'chan': (board_cronbuf[2 + offset] & 0x06) >> 1,
        'value': (board_cronbuf[2 + offset] & 0x01) << 8 | board_cronbuf[3 + offset],
      });
    }
  }
}

void board_crontab_to_cronbuf() {
  board_cronbuf.fillRange(0, board_crontab_size * 4, 0);
  for(int i=0; i<board_crontab.length; i++) {
    int offset = i * 4;
    Map<String,dynamic> job = board_crontab[i];
    board_cronbuf[0 + offset] = job['enabled'] << 7 | job['dow'];
    board_cronbuf[1 + offset] = job['hh'] << 3 | job['mm'] >> 3;
    board_cronbuf[2 + offset] =
        job['mm'] << 5 | job['routine'] << 3 | job['chan'] << 1 | job['value'] >> 8;
    board_cronbuf[3 + offset] = job['value'] & 0xff;
  }
}
