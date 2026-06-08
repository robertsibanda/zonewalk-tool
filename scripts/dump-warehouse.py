#!/usr/bin/env python3
"""Warehouse dump — exports ALL MongoDB collections to JSON files in warehouse/.
   Sanitizes: Robert Sibanda → 1-grid Agent, Robert → 1-grid Agent."""
import json, os, re
from pymongo import MongoClient
from datetime import datetime

MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB  = os.environ.get("MONGO_DB", "support_ai")
OUT_DIR   = os.path.join(os.path.dirname(__file__), "warehouse")
os.makedirs(OUT_DIR, exist_ok=True)

client = MongoClient(MONGO_URI)
db = client[MONGO_DB]

SENSITIVE_FIELDS = ("password", "secret", "api_key", "token", "auth")

def sanitize(obj):
    if isinstance(obj, dict):
        return {k: sanitize(v) for k, v in obj.items()
                if k.lower() not in SENSITIVE_FIELDS}
    if isinstance(obj, list):
        return [sanitize(v) for v in obj]
    if isinstance(obj, str):
        obj = re.sub(r'\bRobert Sibanda\b', '1-grid Agent', obj)
        obj = re.sub(r'\bRobert\b(?!\s*Sibanda)', '1-grid Agent', obj)
        return obj
    if isinstance(obj, datetime):
        return obj.isoformat()
    return obj

for col_name in db.list_collection_names():
    count = db[col_name].count_documents({})
    if count == 0:
        print(f"  SKIP  {col_name}: empty")
        continue
    # rename robert_ prefix
    safe = re.sub(r'^robert_', 'agent_', col_name)
    docs = []
    for d in db[col_name].find():
        d["_id"] = str(d["_id"])
        docs.append(sanitize(d))
    path = os.path.join(OUT_DIR, f"{safe}.json")
    with open(path, "w") as f:
        json.dump(docs, f, indent=2, default=str)
    print(f"  {col_name:30s} → {safe:30s} ({len(docs)} docs)")

print(f"\nDone. {sum(1 for f in os.listdir(OUT_DIR) if f.endswith('.json'))} files in {OUT_DIR}/")
