#!/usr/bin/env python3
import json, os, sys, time, threading
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler

SCENARIO = json.load(open(os.environ["SCENARIO"]))
LOG = open(os.environ["MOCK_LOG"], "a")
lock = threading.Lock()
counter = [0]

def sse(events):
    out = []
    for ev in events:
        out.append(f"event: {ev['type']}\ndata: {json.dumps(ev)}\n\n")
    return "".join(out).encode()

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *a): pass
    def do_GET(self):
        LOG.write(f"{time.time():.3f} GET {self.path}\n"); LOG.flush()
        body = json.dumps({"models": []}).encode()
        self.send_response(200); self.send_header("content-type","application/json")
        self.send_header("content-length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def do_POST(self):
        n = int(self.headers.get("content-length", 0))
        raw = self.rfile.read(n)
        try:
            req = json.loads(raw)
        except Exception:
            req = {}
        items = req.get("input", [])
        outputs = sum(1 for i in items if isinstance(i, dict) and i.get("type") in ("function_call_output", "custom_tool_call_output"))
        with lock:
            counter[0] += 1; rid = f"resp_{counter[0]}"
        # pick step by number of completed tool-call rounds
        rounds = SCENARIO["steps"]
        idx, acc = 0, 0
        while idx < len(rounds) and "calls" in rounds[idx] and acc + len(rounds[idx]["calls"]) <= outputs:
            acc += len(rounds[idx]["calls"]); idx += 1
        step = rounds[min(idx, len(rounds) - 1)]
        for i in items:
            if isinstance(i, dict) and i.get("type") in ("function_call_output", "custom_tool_call_output"):
                LOG.write(f"OUTPUT {i.get('call_id')} {json.dumps(i.get('output'))[:400]}\n")
        LOG.write(f"{time.time():.3f} POST {self.path} bytes={n} outputs={outputs} step={idx}\n"); LOG.flush()
        evs = [{"type": "response.created", "response": {"id": rid}}]
        if "calls" in step:
            for k, c in enumerate(step["calls"]):
                cid = f"call_{rid}_{k}"
                if c.get("kind") == "apply_patch":
                    evs.append({"type": "response.output_item.done", "item": {"type": "custom_tool_call", "name": "apply_patch", "input": c["patch"], "call_id": cid}})
                else:
                    args = {"cmd": c["cmd"]}; args.update(c.get("extra", {}))
                    evs.append({"type": "response.output_item.done", "item": {"type": "function_call", "call_id": cid, "name": c.get("name", "exec_command"), "arguments": json.dumps(args)}})
        else:
            text = step.get("message", "done")
            for chunk in [text[i:i+step.get("chunk", 64)] for i in range(0, len(text), step.get("chunk", 64))]:
                evs.append({"type": "response.output_text.delta", "delta": chunk})
            evs.append({"type": "response.output_item.done", "item": {"type": "message", "role": "assistant", "id": f"msg_{rid}", "content": [{"type": "output_text", "text": text}]}})
        evs.append({"type": "response.completed", "response": {"id": rid, "usage": {"input_tokens": 10, "input_tokens_details": None, "output_tokens": 10, "output_tokens_details": None, "total_tokens": 20}}})
        body = sse(evs)
        self.send_response(200); self.send_header("content-type", "text/event-stream")
        self.send_header("content-length", str(len(body))); self.end_headers(); self.wfile.write(body)

server = ThreadingHTTPServer(("127.0.0.1", 0), H)
with open(os.environ["MOCK_PORT_FILE"], "w") as f:
    f.write(str(server.server_address[1]))
server.serve_forever()
