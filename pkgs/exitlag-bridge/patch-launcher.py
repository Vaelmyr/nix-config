"""Keep the launcher visible after a client exit and tolerate transient probes."""
import os
from pathlib import Path

path = Path(os.environ["EXITLAG_PACKAGE_ROOT"]) / "installers/linux/app.py"
source = path.read_text()
replacements = {
    "from bridge_setup.core import Setup, default_state, find_client":
        "from bridge_setup.core import Setup, default_state, find_client, console_output",
    "        self.checking = False\n":
        "        self.checking = False\n        self.client_missing = 0\n",
    "                    self.window.destroy()\n                    return":
        "                    self.message.set('ExitLag closed. Routing stopped. Click Launch ExitLag to retry.')\n"
        "                    self.window.deiconify()",
    "                        if result.returncode == 0 and b'exitlag.exe' not in result.stdout.lower():\n"
    "                            self.events.put(('client_closed',))":
        "                        output = console_output(result.stdout).lower()\n"
        "                        if result.returncode == 0 and output.strip():\n"
        "                            self.client_missing = self.client_missing + 1 if b'exitlag.exe' not in output else 0\n"
        "                            if self.client_missing >= 3:\n"
        "                                print('ExitLag absent from three consecutive process checks; stopping routing.', file=sys.stderr, flush=True)\n"
        "                                self.events.put(('client_closed',))",
    "        self.started = time.time()":
        "        self.client_missing = 0\n        self.started = time.time()",
}
for old, new in replacements.items():
    if source.count(old) != 1:
        raise ValueError(f"Unexpected launcher source around {old!r}")
    source = source.replace(old, new)
path.write_text(source)
