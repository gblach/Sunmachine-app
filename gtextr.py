#!/usr/bin/env python3

import glob, re

re_singular = re.compile('gettext\([\'\"](.+)[\'\"][\,\)]')
re_plural = re.compile('ngettext\([\'\"](.+)[\'\"][\,\)]')
extracted = set()

print('''
msgid ""
msgstr ""
"Project-Id-Version: gtextr.py\\n"
"POT-Creation-Date: 2021-08-29 13:00+0000\\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/plain; charset=utf-8\\n"
"Content-Transfer-Encoding: 8bit\\n"
''')

for file in glob.glob('lib/**/*.dart', recursive=True):
    with open(file, 'r') as f:
        i = 0
        for line in f.readlines():
            i += 1
            p = re_plural.search(line)
            if p and p.group(1) not in extracted:
                print('#: %s:%d' % (file, i))
                print('msgid "%s"' % p.group(1))
                print('msgid_plural "%s"' % p.group(1))
                print('msgstr[0] ""\n')
                print('msgstr[1] ""\n')
                extracted.add(p.group(1))
            else:
                s = re_singular.search(line)
                if s and s.group(1) not in extracted:
                    print('#: %s:%d' % (file, i))
                    print('msgid "%s"' % s.group(1))
                    print('msgstr ""\n')
                    extracted.add(s.group(1))
