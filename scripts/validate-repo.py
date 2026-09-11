from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
required = [
    "README.md",
    "AGENTS.md",
    "CLAUDE.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "docs/ARCHITECTURE.md",
    "docs/DEVELOPMENT.md",
    "docs/ROADMAP.md",
]
missing = [p for p in required if not (ROOT / p).exists()]
if missing:
    print("Missing required collaboration files:")
    for p in missing:
        print(f" - {p}")
    sys.exit(1)

# Cheap guard against common accidental secret files.
for forbidden in [".env", "id_rsa", "id_ed25519"]:
    matches = list(ROOT.rglob(forbidden))
    matches = [p for p in matches if ".git" not in p.parts]
    if matches:
        print(f"Forbidden secret-like file present: {matches[0].relative_to(ROOT)}")
        sys.exit(1)

print("Repository collaboration baseline looks healthy.")
