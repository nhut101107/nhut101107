#!/usr/bin/env python3
import json,sys,xml.etree.ElementTree as E
A='{http://schemas.android.com/apk/res/android}'
game,gate_dex=sys.argv[1:]; gate='com.mnhutx.playtogether.gate.KeyGateActivity'
old={x['name']:x for x in json.load(open('work/logs/original-inventory.json'))}
new={x['name']:x for x in json.load(open('work/logs/final-inventory.json'))}
for name,row in old.items():
    assert name in new, 'missing '+name
    assert row['sha256']==new[name]['sha256'], 'modified original payload '+name
assert 'classes'+gate_dex+'.dex' in new, 'gate DEX missing'
r=E.parse('work/decoded/AndroidManifest.xml').getroot(); app=r.find('application')
for tag in ('activity','activity-alias'):
    for n in app.findall(tag):
        name=n.get(A+'name')
        for f in n.findall('intent-filter'):
            cats={x.get(A+'name') for x in f.findall('category')}
            if {'android.intent.category.LAUNCHER','android.intent.category.BROWSABLE'} & cats:
                assert name==gate, 'external entry bypasses gate: '+str(name)
        if name!=gate: assert n.get(A+'exported')=='false', 'exported UI: '+str(name)
games=[n for n in app.findall('activity') if n.get(A+'name')==game]
assert games and games[0].get(A+'exported')=='false'
for n in r.findall('permission')+r.findall('permission-group')+r.findall('permission-tree'):
    assert not n.get(A+'name','').startswith('com.haegin.playtogether')
for n in app.findall('provider'):
    assert 'com.haegin.playtogether' not in n.get(A+'authorities','')
