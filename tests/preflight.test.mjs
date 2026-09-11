import assert from 'node:assert/strict';
import test from 'node:test';
import { runPreflight } from '../scripts/preflight.mjs';

function fakeRunner(map) { return (cmd, args) => map[`${cmd} ${args.join(' ')}`] ?? { status: 'error', stderr: 'missing' }; }
const ok = (stdout) => ({ status: 'ok', stdout });
const all = { 'node --version': ok('v24.1.0'), 'git --version': ok('git version 2.45.0'), 'git --exec-path': ok('/git/libexec'), 'python3 --version': ok('Python 3.12.0'), 'uv --version': ok('uv 0.8.0'), 'claude --version': ok('claude 1.2.3') };
const exists = new Set(['/git/libexec/git-remote-https', '/agent', '/agent/fullstack-agent', '/agent/start.sh', '/agent/backtalk/pyproject.toml', '/agent/ai-visualizer/server.py', '/agent/CLAUDE.md']);
const fsExists = (p) => exists.has(p);

test('reports missing executables and does not throw', () => {
  const r = runPreflight({ platform: 'win32', runner: fakeRunner({ 'node --version': ok('v24.0.0') }), exists: () => false });
  assert.equal(r.checks.find((c) => c.id === 'git').status, 'missing');
  assert.equal(r.checks.find((c) => c.id === 'xcode').status, 'unverified');
});
test('does not probe Xcode on Windows', () => {
  const seen = []; const runner = (c, a) => { seen.push(c); return fakeRunner(all)(c, a); };
  runPreflight({ platform: 'win32', runner, exists: fsExists, agentRoot: '/agent' });
  assert.ok(!seen.includes('xcodebuild') && !seen.includes('xcrun'));
});
test('blocks unsupported Xcode and SDK versions and gates stable Xcode', () => {
  const map = { ...all, 'xcodebuild -version': ok('Xcode 16.4'), 'xcrun --sdk iphoneos --show-sdk-version': ok('18.5'), 'swift --version': ok('Swift version 6.0') };
  const r = runPreflight({ platform: 'darwin', runner: fakeRunner(map), exists: fsExists, agentRoot: '/agent' });
  assert.equal(r.checks.find((c) => c.id === 'xcode').status, 'blocked');
  assert.equal(r.checks.find((c) => c.id === 'iphoneos-sdk').status, 'blocked');
});
test('requires Python 3.11 through 3.12', () => {
  const r = runPreflight({ platform: 'win32', runner: fakeRunner({ ...all, 'python3 --version': ok('Python 3.10.9') }), exists: fsExists, agentRoot: '/agent' });
  assert.equal(r.checks.find((c) => c.id === 'python3').status, 'blocked');
});
test('unparsed versions are unverified and relevant start script is nested', () => {
  const r = runPreflight({ platform: 'win32', runner: fakeRunner({ ...all, 'uv --version': ok('uv') }), exists: (p) => p === '/agent' || p.endsWith('fullstack-agent\\start.bat'), agentRoot: '/agent' });
  assert.equal(r.checks.find((c) => c.id === 'uv').status, 'unverified');
  assert.equal(r.checks.find((c) => c.id === 'start-script').status, 'ready');
});
test('marks timed out probes blocked', () => {
  const r = runPreflight({ platform: 'win32', runner: fakeRunner({ ...all, 'uv --version': { status: 'timeout' } }), exists: fsExists, agentRoot: '/agent' });
  assert.equal(r.checks.find((c) => c.id === 'uv').status, 'blocked');
});
test('reports nonexistent agent root', () => {
  const r = runPreflight({ platform: 'win32', runner: fakeRunner(all), exists: () => false, agentRoot: '/missing' });
  assert.equal(r.checks.find((c) => c.id === 'agent-root').status, 'missing');
});
