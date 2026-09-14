#!/usr/bin/env python3
import copy, hashlib, json, sys
from pathlib import Path
import xml.etree.ElementTree as ET

A = "{http://schemas.android.com/apk/res/android}"
OLD, NEW = "com.haegin.playtogether", "com.mnhutx.playtogether"
path, report = Path(sys.argv[1]), Path(sys.argv[2])
ET.register_namespace("android", A[1:-1])
tree = ET.parse(path)
root = tree.getroot()
oldpkg = root.get("package")
if oldpkg != OLD:
    raise SystemExit(f"Unexpected package {oldpkg}")
app = root.find("application")

def absolute(name):
    if not name:
        return name
    if name.startswith("."):
        return OLD + name
    if "." not in name:
        return OLD + "." + name
    return name

def unique_authority(value):
    # Authorities may contain a semicolon-separated list. Every authority owned by
    # this APK must be unique even when a third-party SDK used a fixed literal.
    out = []
    for authority in value.split(";"):
        authority = authority.strip()
        if not authority:
            continue
        if OLD in authority:
            changed = authority.replace(OLD, NEW)
        elif authority.startswith(NEW):
            changed = authority
        else:
            changed = authority + ".mnhutx"
        out.append(changed)
    return ";".join(out)

components = ["activity", "activity-alias", "service", "receiver", "provider"]
for tag in components:
    for node in app.findall(tag):
        node.set(A + "name", absolute(node.get(A + "name")))
        if tag == "activity-alias" and node.get(A + "targetActivity"):
            node.set(A + "targetActivity", absolute(node.get(A + "targetActivity")))
if app.get(A + "name"):
    app.set(A + "name", absolute(app.get(A + "name")))
original_application = app.get(A + "name") or "android.app.Application"
original_app_component_factory = absolute(app.get(A + "appComponentFactory")) or ""

launcher = None
moved = []
for tag in ("activity", "activity-alias"):
    for node in list(app.findall(tag)):
        for filt in list(node.findall("intent-filter")):
            actions = {x.get(A + "name") for x in filt.findall("action")}
            cats = {x.get(A + "name") for x in filt.findall("category")}
            entry = ("android.intent.action.MAIN" in actions and
                     "android.intent.category.LAUNCHER" in cats)
            browser = "android.intent.category.BROWSABLE" in cats
            if entry and launcher is None:
                launcher = node.get(A + "targetActivity") or node.get(A + "name")
            if entry or browser:
                moved.append(copy.deepcopy(filt))
                node.remove(filt)
        node.set(A + "exported", "false")
if not launcher:
    raise SystemExit("No original MAIN/LAUNCHER activity found")

gate = ET.Element("activity", {
    A + "name": NEW + ".gate.KeyGateActivity",
    A + "exported": "true",
    A + "launchMode": "singleTask",
    A + "excludeFromRecents": "false",
    A + "process": ":mnhut_keygate",
    A + "theme": "@android:style/Theme.Material.Light.NoActionBar",
})
seen = set()
for filt in moved:
    key = ET.tostring(filt)
    if key not in seen:
        gate.append(filt)
        seen.add(key)
app.insert(0, gate)

root.set("package", NEW)
app.set(A + "label", "Play Together MNHUT")
app.set(A + "appComponentFactory", NEW + ".gate.GateAppComponentFactory")
changed = []

# A cloned package cannot retain sharedUserId because Android ties that UID to
# the original signing certificate.
if root.get(A + "sharedUserId"):
    changed.append(["manifest", "sharedUserId", root.get(A + "sharedUserId"), None])
    del root.attrib[A + "sharedUserId"]

# Rename every authority owned by this APK, including fixed third-party SDK
# literals that do not contain the original package name.
for provider in app.findall("provider"):
    value = provider.get(A + "authorities")
    if value:
        new_value = unique_authority(value)
        if new_value != value:
            provider.set(A + "authorities", new_value)
            changed.append(["provider", "authorities", value, new_value])

# Rename every custom permission/group declared by this APK and all exact
# references to it. System permissions in uses-permission remain untouched.
declared = {}
for tag in ("permission", "permission-group", "permission-tree"):
    for node in root.findall(tag):
        value = node.get(A + "name")
        if not value:
            continue
        if OLD in value:
            new_value = value.replace(OLD, NEW)
        elif value.startswith(NEW):
            new_value = value
        else:
            digest = hashlib.sha256(value.encode()).hexdigest()[:12]
            new_value = NEW + ".permission." + digest
        declared[value] = new_value
        if new_value != value:
            node.set(A + "name", new_value)
            changed.append([tag, "name", value, new_value])

self_attrs = {
    "permission", "readPermission", "writePermission", "permissionGroup",
    "taskAffinity", "process", "scheme", "accountType", "targetPackage",
}
for node in root.iter():
    for key, value in list(node.attrib.items()):
        local = key.rsplit("}", 1)[-1]
        new_value = value
        if local in ("permission", "readPermission", "writePermission", "permissionGroup"):
            new_value = declared.get(value, value.replace(OLD, NEW))
        elif local in self_attrs and OLD in value:
            new_value = value.replace(OLD, NEW)
        if new_value != value:
            node.set(key, new_value)
            changed.append([node.tag, local, value, new_value])

tree.write(path, encoding="utf-8", xml_declaration=True)
report.write_text(json.dumps({
    "old_package": OLD,
    "new_package": NEW,
    "original_game_activity": launcher,
    "original_application": original_application,
    "original_app_component_factory": original_app_component_factory,
    "gate_app_component_factory": NEW + ".gate.GateAppComponentFactory",
    "gate_activity": NEW + ".gate.KeyGateActivity",
    "moved_intent_filters": len(moved),
    "declared_permission_map": declared,
    "identifier_changes": changed,
}, indent=2))
print(launcher)
