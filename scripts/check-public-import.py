"""Check Git's index before committing/pushing. Reports locations, never values.

This small guard supplements review and a dedicated secret scanner. It is not
proof that arbitrary files, encodings, binaries or history contain no secrets.
"""
from pathlib import PurePosixPath
import re
import subprocess
import sys


def git(*args):
    return subprocess.check_output(['git', *args])


bad_dirs = {'.git', '.tools', '.tmp', 'runtime', 'artifacts', 'upstream',
            'memory-vault', 'node_modules', '.venv', 'venv', '__pycache__',
            'xcuserdata', 'deriveddata', '.build', '.vs', '.vscode', '.idea'}
bad_suffixes = {'.pem', '.key', '.p12', '.pfx', '.cer', '.crt', '.mobileprovision',
                '.provisionprofile', '.jks', '.keystore', '.snk', '.log', '.dmp',
                '.exe', '.dll', '.pdb', '.ipa', '.zip', '.pyc'}
bad_names = {'id_rsa', 'id_ed25519', '.npmrc', '.pypirc', 'appsettings.local.json'}
patterns = {
    'private key marker': rb'-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----',
    'GitHub token': rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b',
    'provider token': rb'\bsk-(?:ant-)?[A-Za-z0-9_-]{25,}',
    'AWS access ID': rb'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b',
    'credential URL': rb'https?://[^\s/@:]+:[^\s/@]+@',
    'personal absolute path': rb'(?i)(?:[A-Z]:[\\/]+Users[\\/]+[A-Za-z0-9_.-]+|/Users/[A-Za-z0-9_.-]+|/home/[A-Za-z0-9_.-]+)',
}


def main():
    failures = []
    entries = git('ls-files', '--stage', '-z').split(b'\0')
    count = 0
    for entry in entries:
        if not entry:
            continue
        meta, raw_path = entry.split(b'\t', 1)
        mode, oid, stage = meta.split()
        path = raw_path.decode('utf-8', 'strict')
        p = PurePosixPath(path)
        count += 1
        lower_parts = {v.lower() for v in p.parts}
        name = p.name.lower()
        if mode not in {b'100644', b'100755'} or stage != b'0':
            failures.append((path, 'non-regular or unmerged index entry'))
            continue
        forbidden = (lower_parts & bad_dirs or p.suffix.lower() in bad_suffixes or
                     name in bad_names or name.startswith('.host-test-') or
                     (name.startswith('.env') and name != '.env.example') or
                     path.startswith('Documentation/Source/') or
                     (p.parts[0] in {'host', 'protocol', 'tests'} and lower_parts & {'bin', 'obj'}))
        if forbidden:
            failures.append((path, 'excluded publication path'))
        size = int(git('cat-file', '-s', oid.decode()))
        if size > 2_000_000:
            failures.append((path, 'large file requires separate review'))
            continue
        data = git('cat-file', 'blob', oid.decode())
        if b'\0' in data:
            failures.append((path, 'binary requires separate review'))
            continue
        try:
            data.decode('utf-8-sig')
        except UnicodeDecodeError:
            failures.append((path, 'non-UTF8 content requires review'))
            continue
        for label, pattern in patterns.items():
            for match in re.finditer(pattern, data):
                line = data.count(b'\n', 0, match.start()) + 1
                failures.append((f'{path}:{line}', label))
    for path, reason in failures:
        print(f'{path}: {reason}')
    print(f'Checked {count} indexed files; {len(failures)} publication guard findings.')
    return bool(failures)


if __name__ == '__main__':
    sys.exit(main())
