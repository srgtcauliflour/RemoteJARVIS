"""Exercise the installed visualizer's real loopback HTTP handlers, then stop."""
import importlib.util
import json
from pathlib import Path
import threading
from urllib.request import urlopen

root = Path(__file__).resolve().parents[1]
source = root / "runtime/agent/ai-visualizer/server.py"
spec = importlib.util.spec_from_file_location("remotejarvis_visualizer_probe", source)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
server = module.ThreadingHTTPServer(("127.0.0.1", 0), module.Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    endpoint = f"http://127.0.0.1:{server.server_port}"
    with urlopen(endpoint + "/state", timeout=5) as response:
        state = json.load(response)
    with urlopen(endpoint + "/config", timeout=5) as response:
        config = json.load(response)
    with urlopen(endpoint + "/", timeout=5) as response:
        assert response.status == 200 and b"html" in response.read().lower()
    assert state["state"] in {"idle", "listening", "thinking", "speaking"}
    assert config["name"] == "RemoteJARVIS", "Visualizer configuration not applied"
    assert Path(module.BUS).resolve() == (root / "runtime/state/backtalk").resolve()
    print(json.dumps({"visualizer_http": "passed", "binding": "loopback only", "state": state["state"], "agent_connection": "not tested", "server_stopped_after_probe": True}))
finally:
    server.shutdown()
    server.server_close()
    thread.join(timeout=5)
