#!/usr/bin/env python3
"""
Warehouse CLI — query/save warehouse data from opencode.
Usage:
  warehouse-query tickets --q "domain.co.za" [--user agent1]
  warehouse-query servers [--ip 1.2.3.4]
  warehouse-query search "domain.co.za" [--user agent1]
  warehouse-query save-ticket --ref 123456 --domain x.co.za --desc "..." --user agent1
  warehouse-query save-conv --session abc123 --msg "..." --resp "..." --user agent1
  warehouse-query register-user --id agent1 --name "Alice" --team "L1 Support"
  warehouse-query my-convs [--user agent1] [--limit 20]
  warehouse-query my-tickets [--user agent1] [--limit 20]
  warehouse-query counts
"""
import argparse, json, os, sys, re
from datetime import datetime
from pymongo import MongoClient, DESCENDING

MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB  = os.environ.get("MONGO_DB", "support_ai")
USER_ID   = os.environ.get("USER_ID", os.environ.get("USER", "unknown"))

# Fallback: try loading from .env if no URI override
if MONGO_URI == "mongodb://localhost:27017" and os.path.exists("/root/1grid-support-agent/.env"):
    try:
        with open("/root/1grid-support-agent/.env") as f:
            for line in f:
                line = line.strip()
                if line.startswith("MONGO_URI="):
                    MONGO_URI = line.split("=", 1)[1].strip().strip('"').strip("'")
                elif line.startswith("MONGO_DB="):
                    MONGO_DB = line.split("=", 1)[1].strip().strip('"').strip("'")
    except Exception:
        pass

client = MongoClient(MONGO_URI)
db = client[MONGO_DB]


def _serialize(doc):
    if doc is None: return None
    if "_id" in doc: doc["_id"] = str(doc["_id"])
    return doc


def cmd_tickets(args):
    q = args.query or ""
    limit = args.limit or 20
    user_filter = {"user_id": args.user} if args.user else {}
    if q:
        pat = re.compile(re.escape(q), re.IGNORECASE)
        cursor = db.tickets.find({**user_filter, "$or": [
            {"domain": pat}, {"ticket_ref": pat}, {"description": pat},
            {"ticket_id": pat}, {"server_ip": pat}
        ]}).sort("created_at", DESCENDING).limit(limit)
    else:
        cursor = db.tickets.find(user_filter).sort("created_at", DESCENDING).limit(limit)
    docs = [_serialize(d) for d in cursor]
    print(json.dumps(docs, indent=2, default=str))


def cmd_servers(args):
    q = {}
    if args.ip: q["ip"] = re.compile(re.escape(args.ip), re.IGNORECASE)
    if args.hostname: q["hostname"] = re.compile(re.escape(args.hostname), re.IGNORECASE)
    docs = [_serialize(d) for d in db.servers.find(q)]
    print(json.dumps(docs, indent=2, default=str))


def cmd_search(args):
    q = args.query or ""
    limit = args.limit or 10
    user_filter = {"user_id": args.user} if args.user else {}
    pat = re.compile(re.escape(q), re.IGNORECASE)
    results = {
        "tickets": [_serialize(d) for d in db.tickets.find(
            {**user_filter, "$or": [{"domain": pat}, {"ticket_ref": pat}, {"description": pat}]}
        ).sort("created_at", DESCENDING).limit(limit)],
        "conversations": [_serialize(d) for d in db.agent_conversations.find(
            {**user_filter, "$or": [
                {"user_message": pat}, {"assistant_response": pat},
                {"domain": pat}, {"ticket_refs": pat}
            ]}
        ).sort("timestamp", DESCENDING).limit(limit)],
        "kb": [_serialize(d) for d in db.kb_articles.find(
            {"$or": [{"title": pat}, {"content": pat}, {"category": pat}, {"tags": pat}]}
        ).limit(limit)],
    }
    print(json.dumps(results, indent=2, default=str))


def cmd_save_ticket(args):
    doc = {
        "ticket_ref": args.ref,
        "domain": args.domain,
        "description": args.desc or "",
        "user_id": args.user or USER_ID,
        "server_ip": args.ip or "",
        "ptr": args.ptr or "",
        "category": args.category or "",
        "outcome": args.outcome or "",
        "created_at": datetime.utcnow().isoformat(),
    }
    result = db.tickets.insert_one(doc)
    print(json.dumps({"status": "saved", "id": str(result.inserted_id)}, default=str))


def cmd_save_conv(args):
    doc = {
        "session_id": args.session,
        "type": "chat_exchange",
        "user_id": args.user or USER_ID,
        "user_message": args.msg,
        "assistant_response": args.resp,
        "domain": args.domain or "",
        "ticket_refs": [t.strip() for t in args.tickets.split(",")] if args.tickets else [],
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    result = db.agent_conversations.insert_one(doc)
    print(json.dumps({"status": "saved", "id": str(result.inserted_id)}, default=str))


def cmd_register_user(args):
    existing = db.users.find_one({"user_id": args.id})
    if existing:
        db.users.update_one({"user_id": args.id}, {"$set": {
            "name": args.name, "email": args.email, "team": args.team,
            "last_seen": datetime.utcnow().isoformat()
        }})
        print(json.dumps({"status": "updated", "user_id": args.id}))
    else:
        db.users.insert_one({
            "user_id": args.id, "name": args.name or "",
            "email": args.email or "", "team": args.team or "",
            "created_at": datetime.utcnow().isoformat(),
            "last_seen": datetime.utcnow().isoformat()
        })
        print(json.dumps({"status": "created", "user_id": args.id}))


def cmd_my_convs(args):
    uid = args.user or USER_ID
    limit = args.limit or 20
    docs = [_serialize(d) for d in
            db.agent_conversations.find({"user_id": uid})
            .sort("timestamp", DESCENDING).limit(limit)]
    print(json.dumps(docs, indent=2, default=str))


def cmd_my_tickets(args):
    uid = args.user or USER_ID
    limit = args.limit or 20
    docs = [_serialize(d) for d in
            db.tickets.find({"user_id": uid})
            .sort("created_at", DESCENDING).limit(limit)]
    print(json.dumps(docs, indent=2, default=str))


def cmd_counts(args):
    counts = {c: db[c].count_documents({}) for c in
              db.list_collection_names() if not c.startswith("system.")}
    print(json.dumps(counts, indent=2))


def main():
    p = argparse.ArgumentParser(description="Warehouse CLI for 1-grid Agent")
    sub = p.add_subparsers(dest="command")

    p_tickets = sub.add_parser("tickets")
    p_tickets.add_argument("--q", dest="query", default="")
    p_tickets.add_argument("--user", default="")
    p_tickets.add_argument("--limit", type=int, default=20)

    p_servers = sub.add_parser("servers")
    p_servers.add_argument("--ip", default="")
    p_servers.add_argument("--hostname", default="")

    p_search = sub.add_parser("search")
    p_search.add_argument("query", default="")
    p_search.add_argument("--user", default="")
    p_search.add_argument("--limit", type=int, default=10)

    p_st = sub.add_parser("save-ticket")
    p_st.add_argument("--ref", required=True)
    p_st.add_argument("--domain", default="")
    p_st.add_argument("--desc", default="")
    p_st.add_argument("--ip", default="")
    p_st.add_argument("--ptr", default="")
    p_st.add_argument("--category", default="")
    p_st.add_argument("--outcome", default="")
    p_st.add_argument("--user", default="")

    p_sc = sub.add_parser("save-conv")
    p_sc.add_argument("--session", required=True)
    p_sc.add_argument("--msg", required=True)
    p_sc.add_argument("--resp", required=True)
    p_sc.add_argument("--domain", default="")
    p_sc.add_argument("--tickets", default="")
    p_sc.add_argument("--user", default="")

    p_ru = sub.add_parser("register-user")
    p_ru.add_argument("--id", required=True)
    p_ru.add_argument("--name", default="")
    p_ru.add_argument("--email", default="")
    p_ru.add_argument("--team", default="")

    p_mc = sub.add_parser("my-convs")
    p_mc.add_argument("--user", default="")
    p_mc.add_argument("--limit", type=int, default=20)

    p_mt = sub.add_parser("my-tickets")
    p_mt.add_argument("--user", default="")
    p_mt.add_argument("--limit", type=int, default=20)

    p_ct = sub.add_parser("counts")

    args = p.parse_args()
    if not args.command:
        p.print_help()
        return

    handlers = {
        "tickets": cmd_tickets,
        "servers": cmd_servers,
        "search": cmd_search,
        "save-ticket": cmd_save_ticket,
        "save-conv": cmd_save_conv,
        "register-user": cmd_register_user,
        "my-convs": cmd_my_convs,
        "my-tickets": cmd_my_tickets,
        "counts": cmd_counts,
    }
    handlers[args.command](args)


if __name__ == "__main__":
    main()
