"""Focused restore fixtures; never invokes live preference/input writes."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
CONFIG = ROOT / 'configs/macos/preferences.json'
HELPER = ROOT / 'scripts/installs/apply_macos.swift'
config = json.loads(CONFIG.read_text())
assert config['dock_apps'][3] == {'path': '/Applications/ChatGPT.app', 'bundle_id': 'com.openai.codex'}
assert config['input_sources'] == {'enabled': ['com.apple.keylayout.ABC'], 'selected': 'com.apple.keylayout.ABC'}

def save(path, value):
    path.write_bytes(plistlib.dumps(value))

def read(path):
    return plistlib.loads(path.read_bytes())

def run_fixture(directory, extra=(), conf=CONFIG):
    return subprocess.run(['xcrun', 'swift', str(HELPER), str(conf), '--fixture', str(directory), *extra], check=True, capture_output=True, text=True).stdout

with tempfile.TemporaryDirectory(prefix='workspace-macos-test-') as temporary:
    base = Path(temporary)
    case = base / 'existing'
    case.mkdir()
    # Fake availability never creates applications or directories in the live HOME.
    for item in config['dock_apps']:
        (case / ('files' + item['path'])).mkdir(parents=True)
    (case / ('files' + str(Path.home() / 'Downloads'))).mkdir(parents=True)
    extra = {'tile-type': 'file-tile', 'tile-data': {'file-data': {'_CFURLString': 'file:///Applications/Extra.app'}, 'file-label': 'Extra', 'bookmark': b'fixture-only'}}
    save(case / 'com.apple.dock.plist', {'unrelated': 7, 'tilesize': 36, 'persistent-apps': [extra]})
    save(case / 'com.apple.finder.plist', {'unrelated': 'keep', 'ShowStatusBar': False})
    save(case / 'com.apple.symbolichotkeys.plist', {'unrelated': 'keep', 'AppleSymbolicHotKeys': {'999': {'enabled': True}, '79': {'enabled': False, 'value': {'type': 'standard', 'parameters': [1, 2, 3]}}, '164': {'fixture': 'preserve'}}})
    # Existing destination sources are retained even when absent from the portable list.
    existing_sources = ['fixture.other', 'com.apple.inputmethod.VietnameseIM.VietnameseSimpleTelex']
    save(case / 'fixture-input.plist', {'state': {'enabled': existing_sources, 'selected': 'fixture.other'}})
    # Exercise menu merge even though the real capture correctly has no overrides.
    custom = dict(config, menu_shortcuts={'fixture.app': {'Example': '@e'}})
    conf = base / 'custom.json'
    conf.write_text(json.dumps(custom))
    save(case / 'fixture.app.plist', {'NSUserKeyEquivalents': {'Other': '@o'}, 'unrelated': 3})
    before = {p.name: p.read_bytes() for p in case.glob('*.plist')}
    assert 'WOULD SET' in run_fixture(case, ['--dry-run'], conf)
    assert before == {p.name: p.read_bytes() for p in case.glob('*.plist')}
    assert not (case / 'backups').exists()
    first = run_fixture(case, conf=conf)
    assert 'Applied' in first
    dock = read(case / 'com.apple.dock.plist')
    assert dock['tilesize'] == 52 and dock['unrelated'] == 7
    assert [t['tile-data']['bundle-identifier'] for t in dock['persistent-apps'][:-1]] == [a['bundle_id'] for a in config['dock_apps']]
    assert dock['persistent-apps'][-1] == extra
    assert dock['persistent-others'][0]['tile-data']['arrangement'] == 2
    finder = read(case / 'com.apple.finder.plist')
    assert finder['FXPreferredViewStyle'] == 'Nlsv' and finder['NewWindowTarget'] == 'PfAF' and finder['unrelated'] == 'keep'
    keys = read(case / 'com.apple.symbolichotkeys.plist')['AppleSymbolicHotKeys']
    assert keys['999'] == {'enabled': True} and keys['164'] == {'fixture': 'preserve'}
    assert keys['79']['value']['parameters'] == [1, 2, 3] and keys['79']['enabled']
    assert read(case / 'fixture.app.plist')['NSUserKeyEquivalents'] == {'Example': '@e', 'Other': '@o'}
    state = read(case / 'fixture-input.plist')['state']
    assert state['enabled'] == [*existing_sources, *config['input_sources']['enabled']]
    assert state['selected'] == config['input_sources']['selected']
    backups = list((case / 'backups').glob('*/*.plist'))
    assert backups and all(p.stat().st_mode & 0o777 == 0o600 for p in backups)
    assert all(p.parent.stat().st_mode & 0o777 == 0o700 for p in backups)
    before = {p.name: p.read_bytes() for p in case.glob('*.plist')}
    assert 'Applied 0 preference changes' in run_fixture(case, conf=conf)
    assert before == {p.name: p.read_bytes() for p in case.glob('*.plist')}
    assert backups == list((case / 'backups').glob('*/*.plist'))
    absent = base / 'missing'
    absent.mkdir()
    out = run_fixture(absent)
    assert out.count('Missing Dock app:') == 6 and 'Missing Dock folder:' in out
    assert 'persistent-apps' not in read(absent / 'com.apple.dock.plist')
    assert 'Applied 0 preference changes' in run_fixture(absent)
    # Run only the standalone macOS shell wrapper with every mutable OS tool mocked.
    fake_home = base / 'home'
    fake_home.mkdir()
    mocks = base / 'bin'
    mocks.mkdir()
    log = base / 'calls'
    for name in ['defaults', 'xcrun', 'killall']:
        mock = mocks / name
        mock.write_text('#!/bin/bash\nprintf "%s\\n" "$0 $*" >> "$MACOS_TEST_LOG"\n')
        mock.chmod(0o700)
    env = dict(os.environ, HOME=str(fake_home), WORKSPACE=str(ROOT), APP_CONFIGS=str(ROOT / 'configs'), PATH=str(mocks) + ':' + os.environ['PATH'], MACOS_TEST_LOG=str(log))
    env.pop('INSTALLS', None)
    subprocess.run(['bash', str(ROOT / 'scripts/installs/setup_macos.sh')], check=True, env=env, capture_output=True)
    calls = log.read_text()
    assert calls.count('xcrun swift') == 1
    for expected in ['KeyRepeat -int 2', 'InitialKeyRepeat -int 15', 'ApplePressAndHoldEnabled -bool false', 'screencapture type -string png', 'AppleInterfaceStyle -string Dark', 'DSDontWriteNetworkStores -bool true', 'DSDontWriteUSBStores -bool true', 'killall Finder', 'killall Dock']:
        assert expected in calls, expected
    assert 'tilesize -int 36' not in calls and (fake_home / 'Pictures/Screenshots').is_dir()
print('PASS: dry run, typed merge, managed Dock order/unrelated retention, missing targets, simulated input sources, private backups, rerun idempotency, mocked existing shell behavior.')
