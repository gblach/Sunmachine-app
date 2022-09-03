#!/usr/bin/env python3

import os, glob, re, json, shutil

os.system('wget https://data.iana.org/time-zones/tzdb-latest.tar.lz')
os.system('bsdtar xvf tzdb-latest.tar.lz')

dirname = glob.glob('tzdb-20*')[0]
os.system("make -C %s install DESTDIR=../tzdb-root" % dirname)

tzdata = { '_tzdb': dirname[5:] }

for file in glob.glob('tzdb-root/usr/share/zoneinfo/**', recursive=True):
    if os.path.isfile(file):    
        with open(file, 'rb') as f:
            zone = f.readlines()
            if zone[0][:5] == b'TZif2':
                tzdata[file[29:]] = zone[-1].decode().strip()

regexp = re.compile(r'\<[\+\-]?[0-9]+\>')
for name, zone in tzdata.items():
    zone = regexp.sub('AAA', zone, 1)
    zone = regexp.sub('BBB', zone, 1)
    tzdata[name] = zone

with open('tzdata.json', 'w') as f:
    json.dump(tzdata, f, indent='\t', sort_keys=True)
    f.write('\n')

for file in glob.glob('tzdb-*'):
    if os.path.isfile(file): os.remove(file)
    elif os.path.isdir(file): shutil.rmtree(file)
