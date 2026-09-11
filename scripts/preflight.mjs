#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const DEFAULT_TIMEOUT = 4000;

function defaultRunner(command, args = [], options = {}) {
  const result = spawnSync(command, args, {
    shell: false,
    encoding: 'utf8',
    timeout: options.timeout ?? DEFAULT_TIMEOUT,
    windowsHide: true,
  });
  return {
    status: result.error?.code === 'ETIMEDOUT' ? 'timeout' : result.status === 0 ? 'ok' : 'error',
    stdout: result.stdout ?? '', stderr: result.stderr ?? '', error: result.error?.message,
  };
}

const defaultExists = (file) => fs.existsSync(file);
const output = (r) => `${r?.stdout ?? ''}\n${r?.stderr ?? ''}`.trim();
const version = (r, re) => { const m = output(r).match(re); return m?.[1] ?? null; };
function probe(id, label, runner, command, args, re) {
  const r = runner(command, args, { timeout: DEFAULT_TIMEOUT });
  if (r.status === 'timeout') return { id, label, status: 'blocked', detail: 'probe timed out' };
  if (r.status !== 'ok') return { id, label, status: 'missing', detail: r.error || 'executable unavailable' };
  const v = re && version(r, re);
  if (!v) return { id, label, status: 'unverified', detail: 'command present; version not parsed' };
  return { id, label, status: 'ready', detail: `${v} (command present; configuration not verified)`, version: v };
}
function exact27(check, field) {
  if (check.status === 'missing' || check.status === 'blocked') return check;
  if (!check.version || !/^27(?:\.|$)/.test(check.version)) return { ...check, status: 'blocked', detail: `${field} must be version 27; found ${check.version ?? 'unknown'}` };
  return check;
}

export function runPreflight({ platform = process.platform, env = process.env, agentRoot, runner = defaultRunner, exists = defaultExists } = {}) {
  const checks = [];
  checks.push(probe('node', 'Node.js', runner, process.execPath, ['--version'], /^v?(\d+(?:\.\d+){0,2})/m));
  const git = probe('git', 'git', runner, 'git', ['--version'], /git version\s+([^\s]+)/i);
  checks.push(git);
  if (git.status === 'ready') {
    const helper = runner('git', ['--exec-path'], { timeout: DEFAULT_TIMEOUT });
    if (helper.status !== 'ok') checks.push({ id: 'git-remote-https', label: 'git HTTPS helper', status: helper.status === 'timeout' ? 'blocked' : 'missing', detail: 'could not determine git exec path' });
    else {
      const dir = output(helper).split(/\r?\n/)[0];
      const found = ['git-remote-https.exe', 'git-remote-https'].some((name) => exists(path.join(dir, name)));
      checks.push({ id: 'git-remote-https', label: 'git HTTPS helper', status: found ? 'ready' : 'missing', detail: found ? 'helper present' : `helper absent under ${dir}` });
    }
  } else checks.push({ id: 'git-remote-https', label: 'git HTTPS helper', status: 'missing', detail: 'git unavailable' });

  let py = probe('python3', 'Python 3', runner, 'python3', ['--version'], /Python\s+(\d+(?:\.\d+){0,2})/i);
  if (py.status !== 'ready') py = probe('python', 'Python 3', runner, 'python', ['--version'], /Python\s+(\d+(?:\.\d+){0,2})/i);
  if (py.status === 'ready') {
    const parts = py.version.split('.').map(Number);
    const supported = parts[0] === 3 && parts[1] >= 11 && parts[1] < 13;
    if (!supported) py = { ...py, status: 'blocked', detail: `Python >=3.11 and <3.13 required; found ${py.version}` };
  }
  checks.push(py);
  checks.push(probe('uv', 'uv', runner, 'uv', ['--version'], /uv\s+([^\s]+)/i));
  checks.push(probe('claude', 'Claude CLI', runner, 'claude', ['--version'], /(?:claude[^\d]*)?(\d+(?:\.\d+){1,2})/i));

  if (platform === 'darwin') {
    const xcode = probe('xcode', 'Xcode', runner, 'xcodebuild', ['-version'], /Xcode\s+(\d+(?:\.\d+){0,2})/i);
    const sdk = probe('iphoneos-sdk', 'iPhoneOS SDK', runner, 'xcrun', ['--sdk', 'iphoneos', '--show-sdk-version'], /^(\d+(?:\.\d+){0,2})/m);
    const exactXcode = exact27(xcode, 'Xcode');
    checks.push(exactXcode.status === 'ready' ? { ...exactXcode, status: 'unverified', detail: `${exactXcode.version} is major version 27; stable release/build ID must be verified in the platform manifest` } : exactXcode, exact27(sdk, 'iPhoneOS SDK'));
    checks.push(probe('swift', 'Swift', runner, 'swift', ['--version'], /Swift version\s+([^\s]+)/i));
  } else {
    checks.push({ id: 'xcode', label: 'Xcode', status: 'unverified', detail: 'Xcode probes run only on Darwin' });
    checks.push({ id: 'iphoneos-sdk', label: 'iPhoneOS SDK', status: 'unverified', detail: 'SDK probes run only on Darwin' });
    checks.push({ id: 'swift', label: 'Swift', status: 'unverified', detail: 'Swift probe run only on Darwin' });
  }

  const root = agentRoot || env.REMOTEJARVIS_AGENT_ROOT;
  if (!root) checks.push({ id: 'agent-root', label: 'fullstack-agent root', status: 'unverified', detail: 'no --agent-root or REMOTEJARVIS_AGENT_ROOT supplied' });
  else if (!exists(root)) checks.push({ id: 'agent-root', label: 'fullstack-agent root', status: 'missing', detail: root });
  else {
    checks.push({ id: 'agent-root', label: 'fullstack-agent root', status: 'ready', detail: root });
    const startRel = platform === 'win32' ? path.join('fullstack-agent', 'start.bat') : path.join('fullstack-agent', 'start.sh');
    for (const [id, rel] of [['fullstack-agent', 'fullstack-agent'], ['start-script', startRel], ['backtalk-pyproject', path.join('backtalk', 'pyproject.toml')], ['visualizer-server', path.join('ai-visualizer', 'server.py')], ['claude-md', 'CLAUDE.md']]) {
      const present = exists(path.join(root, rel));
      checks.push({ id, label: rel, status: present ? 'ready' : 'missing', detail: present ? 'present' : 'not found' });
    }
  }
  const iosChecks = checks.filter((c) => ['xcode', 'iphoneos-sdk', 'swift'].includes(c.id));
  const hostChecks = checks.filter((c) => !['xcode', 'iphoneos-sdk', 'swift'].includes(c.id));
  return { platform, checks, hostReady: hostChecks.every((c) => c.status === 'ready' || c.status === 'unverified'), iosReady: iosChecks.every((c) => c.status === 'ready'), ok: checks.every((c) => c.status === 'ready') };
}

function main(argv) {
  const json = argv.includes('--json');
  const strict = argv.includes('--strict');
  const allowed = new Set(['--json', '--strict', '--agent-root']);
  const unknown = argv.find((arg, n) => !allowed.has(arg) && !(n > 0 && argv[n - 1] === '--agent-root'));
  if (unknown) { console.error(`Unknown option: ${unknown}`); process.exitCode = 2; return; }
  const i = argv.indexOf('--agent-root');
  if (i >= 0 && (!argv[i + 1] || argv[i + 1].startsWith('--'))) { console.error('--agent-root requires a path'); process.exitCode = 2; return; }
  const agentRoot = i >= 0 ? argv[i + 1] : undefined;
  const result = runPreflight({ agentRoot });
  if (json) console.log(JSON.stringify(result, null, 2));
  else result.checks.forEach((c) => console.log(`[${c.status.toUpperCase()}] ${c.label}: ${c.detail}`));
  if (strict && !result.ok) process.exitCode = 1;
}
if (process.argv[1] === fileURLToPath(import.meta.url)) main(process.argv.slice(2));
