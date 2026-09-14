#!/usr/bin/env python3
import hashlib, json, sys, zipfile
apk,out=sys.argv[1:]; rows=[]
with zipfile.ZipFile(apk) as z:
    for i in z.infolist():
        if i.is_dir(): continue
        if i.filename.startswith(("assets/","lib/")) or (i.filename.startswith("classes") and i.filename.endswith(".dex")):
            h=hashlib.sha256()
            with z.open(i) as f:
                for block in iter(lambda:f.read(4*1024*1024),b""): h.update(block)
            rows.append({"name":i.filename,"size":i.file_size,"sha256":h.hexdigest()})
json.dump(rows,open(out,"w"),indent=2)
