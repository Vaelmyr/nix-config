"""Use the immutable Nix runtime as the source for upstream's private copy."""
import os
from pathlib import Path
import sys

path = Path(os.environ["EXITLAG_PACKAGE_ROOT"]) / "installers/bridge_setup/core.py"
source = path.read_text()
start = source.index("            cache = self.state.relative('cache')")
end = source.index("            private_json(marker,", start)
source = source[:start] + f"""            shutil.copytree({sys.argv[1]!r}, runtime, symlinks=False)
            runtime.chmod(0o700)
            for item in runtime.rglob('*'):
                item.chmod(item.stat().st_mode | 0o200)
""" + source[end:]
path.write_text(source)
source = path.read_text().replace(
    "        shutil.copy2(self.payloads / 'wbemprox.dll', target)",
    "        target.chmod(target.stat().st_mode | 0o200)\n"
    "        shutil.copy2(self.payloads / 'wbemprox.dll', target)",
)
path.write_text(source)
