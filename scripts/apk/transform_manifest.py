#!/usr/bin/env python3
import copy, json, sys
from pathlib import Path
import xml.etree.ElementTree as ET

A = "{http://schemas.android.com/apk/res/android}"
OLD, NEW = "com.haegin.playtogether", "com.mnhutx.playtogether"
path, report = Path(sys.argv[1]), Path(sys.argv[2])
ET.register_namespace("android", A[1:-1])
tree = ET.parse(path); root = tree.getroot(); oldpkg = root.get("package")
if oldpkg != OLD: raise SystemExit(f"Unexpected package {oldpkg}")
app = root.find("application")

def absolute(name):
    if not name: return name
    if name.startswith("."): return OLD + name
    if "." not in name: return OLD + "." + name
    return name

components = ["activity", "activity-alias", "service", "receiver", "provider"]
for tag in components:
    for node in app.findall(tag):
        node.set(A+"name", absolute(node.get(A+"name")))
        if tag == "activity-alias" and node.get(A+"targetActivity"):
            node.set(A+"targetActivity", absolute(node.get(A+"targetActivity")))
if app.get(A+"name"): app.set(A+"name", absolute(app.get(A+"name")))

launcher = None; moved=[]
for tag in ("activity", "activity-alias"):
    for node in list(app.findall(tag)):
        for filt in list(node.findall("intent-filter")):
            actions={x.get(A+"name") for x in filt.findall("action")}
            cats={x.get(A+"name") for x in filt.findall("category")}
            entry = ("android.intent.action.MAIN" in actions and
                     "android.intent.category.LAUNCHER" in cats)
            browser = "android.intent.category.BROWSABLE" in cats
            if entry and launcher is None:
                launcher = node.get(A+"targetActivity") or node.get(A+"name")
            if entry or browser:
                moved.append(copy.deepcopy(filt)); node.remove(filt)
        # No UI activity can remain externally callable around the gate.
        node.set(A+"exported", "false")
if not launcher: raise SystemExit("No original MAIN/LAUNCHER activity found")

gate = ET.Element("activity", {A+"name": NEW+".gate.KeyGateActivity",
    A+"exported":"true", A+"launchMode":"singleTask", A+"excludeFromRecents":"false"})
seen=set()
for filt in moved:
    key=ET.tostring(filt)
    if key not in seen: gate.append(filt); seen.add(key)
app.insert(0, gate)

# Change only package-manager/runtime self-identifiers, never Java class names.
root.set("package", NEW); app.set(A+"label", "Play Together MNHUT")
changed=[]
self_attrs={"authorities","permission","readPermission","writePermission",
            "permissionGroup","taskAffinity","process","scheme","accountType"}
for node in root.iter():
    for key,val in list(node.attrib.items()):
        local=key.rsplit("}",1)[-1]
        if local in self_attrs and OLD in val:
            node.set(key,val.replace(OLD,NEW)); changed.append([node.tag,local,val,node.get(key)])
for tag in ("permission","permission-group","permission-tree"):
    for node in root.findall(tag):
        val=node.get(A+"name","")
        if OLD in val:
            node.set(A+"name",val.replace(OLD,NEW)); changed.append([tag,"name",val,node.get(A+"name")])

tree.write(path, encoding="utf-8", xml_declaration=True)
report.write_text(json.dumps({"old_package":OLD,"new_package":NEW,
  "original_game_activity":launcher,"gate_activity":NEW+".gate.KeyGateActivity",
  "moved_intent_filters":len(moved),"identifier_changes":changed},indent=2))
print(launcher)
