#!/usr/bin/env python3
"""Focused control-flow fixtures. Never invoke live package/app/pref/network tools.
Only shell parsing, local disposable Git repositories, fixture file operations,
and explicit mocked commands are permitted here. No lint or live recovery.
"""
import hashlib
import fcntl
import pty
import termios
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
BASH = '/bin/bash'
BOOT = ROOT / 'scripts/installs/bootstrap.sh'
GUIDE = ROOT / 'docs/install/supervised-recovery-plan.md'
ORIGIN = 'https://github.com/teazyou/workspace.git'
q = shlex.quote

class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='recovery-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name).resolve()
        self.home = self.base / 'home'
        self.home.mkdir()
        self.stub = self.base / 'bin'
        self.stub.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), WORKSPACE=str(ROOT),
                        INSTALLS=str(ROOT / 'scripts/installs'), FUNCTIONS=str(ROOT / 'functions'),
                        APP_CONFIGS=str(ROOT / 'configs'), PATH=f'{self.stub}:/usr/bin:/bin:/usr/sbin:/sbin',
                        GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL='/dev/null')
        self.env.pop('BASH_ENV', None)
        self.env.pop('ENV', None)
        # Deny every host-affecting external command used by changed production
        # scripts. Individual cases explicitly supply mocks. Absolute paths are
        # checked below and only /bin/bash may execute a fixture child script.
        for name in ('brew curl sudo dseditgroup xcode-select xcrun softwareupdate '
                     'defaults pgrep codesign plutil spctl xattr ditto open osascript '
                     'launchctl killall sysctl sw_vers df whoami uname').split():
            self.script(self.stub / name, f'echo "UNEXPECTED HOST COMMAND: {name}" >&2\nexit 97\n')

    def script(self, path, body):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('#!/bin/bash\n' + body)
        path.chmod(0o755)

    def shell(self, body, ok=True, env=None):
        r = subprocess.run([BASH, '--noprofile', '--norc', '-c', 'set -e\n' + body],
                           env=env or self.env, text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=20)
        self.assertNotIn('UNEXPECTED HOST COMMAND', r.stdout)
        if ok:
            self.assertEqual(r.returncode, 0, r.stdout)
        else:
            self.assertNotEqual(r.returncode, 0, r.stdout)
            self.assertNotIn('Step1done', r.stdout)
        return r

    def source_boot(self):
        return f'source {q(str(BOOT))}\n'

    def source_brew(self):
        return f'source {q(str(ROOT / "scripts/installs/install_brew.sh"))}\n'

    def test_syntax_only(self):
        files = ['scripts/installs/bootstrap.sh', 'scripts/installs/recovery_checks.sh',
                 'scripts/installs/install_brew.sh', 'scripts/installs/install_claude.sh',
                 'scripts/installs/install_iterm2.sh', 'scripts/installs/setup_symlinks.sh',
                 'scripts/installs/installation.sh', 'functions/brew.sh']
        for name in files:
            subprocess.run([BASH, '-n', str(ROOT/name)], check=True, capture_output=True)
        for name in ('path.zsh', 'nvm.zsh'):
            subprocess.run(['/bin/zsh', '-n', str(ROOT/'zsh/configs'/name)], check=True, capture_output=True)
        subprocess.run(['/bin/zsh', '-n', str(ROOT/'zsh/zshrc.zsh')], check=True, capture_output=True)

    def test_inventory_single_complete(self):
        def inventory(phase):
            r = self.shell(self.source_brew() + f'install_brew_main --phase {phase} --list')
            return r.stdout.splitlines()
        minimal, remaining, all_targets = (inventory(x) for x in ('minimal','remaining','all'))
        self.assertEqual(minimal, [f'cask {x}' for x in ['iterm2','chatgpt','claude','codex','brave-browser']])
        self.assertEqual(len(remaining), 16)
        self.assertEqual(set(minimal + remaining), set(all_targets))
        self.assertEqual(len(all_targets), len(set(all_targets)))
        self.assertEqual(len(all_targets), 21)
        self.shell(self.source_brew() + 'install_brew_main --phase unknown', ok=False)

    def test_package_failures_and_artifacts(self):
        common = self.source_brew() + '''
        brew() {
          case "$*" in
            --prefix) echo /mock-brew ;;
            'list --cask '*|'list --formula -1') return 0 ;;
            *) echo "BAD unexpected brew action: $*"; return 99 ;;
          esac
        }
        cask_artifact() { return 0; }
        '''
        self.shell(common + 'install_brew_main --phase minimal --verify-only')
        self.shell(common + 'cask_artifact() { return 1; }; install_brew_main --phase minimal --verify-only', ok=False)
        # Failed installer despite a helper or receipt previously reporting success.
        self.shell(common + 'caskInstall() { return 1; }; install_brew_main --phase minimal', ok=False)
        self.shell(self.source_brew() + '''
        brew() { case "$*" in 'list --cask '*|'install --cask '*) return 1;; 'install --dry-run '*) return 0;; esac; }
        caskInstall test iterm2
        ''', ok=False)
        self.shell(self.source_brew() + '''
        brew() { case "$*" in 'list --formula -1') return 0;; 'install --formula '*) return 1;; 'install --dry-run '*) return 0;; esac; }
        brewInstall test python
        ''', ok=False)

    def test_no_maintenance_in_normal_phases(self):
        r = self.shell(self.source_brew() + '''
        brew() {
          case "$*" in
            --prefix) echo /mock-brew ;;
            'list --formula -1') printf '%s\n' python nvm sketchybar borders ripgrep mas gh ;;
            'list --cask '*) return 0 ;;
            tap) echo felixkratz/formulae ;;
            *) echo "FORBIDDEN brew $*"; return 99 ;;
          esac
        }
        cask_artifact() { return 0; }; formula_artifact() { return 0; }
        install_brew_main --phase remaining
        test "$HOMEBREW_NO_INSTALL_CLEANUP" = 1
        test "$HOMEBREW_NO_INSTALL_UPGRADE" = 1
        test "$HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK" = 1
        ''')
        self.assertNotIn('FORBIDDEN', r.stdout)

    def prompt(self, content=None):
        workspace = self.base / 'workspace'
        guide = workspace / 'docs/install/supervised-recovery-plan.md'
        guide.parent.mkdir(parents=True, exist_ok=True)
        guide.write_text(content if content is not None else GUIDE.read_text())
        return f'''source {q(str(ROOT/'scripts/installs/recovery_checks.sh'))}
        render_recovery_prompt {q(str(guide))} {q(str(workspace))} {q(ORIGIN)} {'a'*40} /native/claude /brew/codex
        '''

    def test_prompt_complete_neutral_and_draft_rejection(self):
        r = self.shell(self.prompt())
        self.assertIn('Continue recovery in ~/workspace. Step 1 is complete.', r.stdout)
        self.assertIn('Run the existing setup scripts directly in this session; do not delegate to agents.', r.stdout)
        self.assertLess(len(r.stdout.split()), 80)
        self.assertNotIn('{{', r.stdout)
        self.assertIn('docs/install/supervised-recovery-plan.md', r.stdout)
        self.assertNotIn('gpt-', r.stdout)
        for content in (GUIDE.read_text().replace('Status: implemented candidate','Status: proposed'),
                        GUIDE.read_text().replace('<!-- recovery-prompt:end -->',''),
                        GUIDE.read_text().replace('Continue recovery in ~/workspace.', '{{UNKNOWN}}'),
                        re.sub(r'(?s)(<!-- recovery-prompt:start -->).*?(<!-- recovery-prompt:end -->)', r'\1\n\2', GUIDE.read_text())):
            self.shell(self.prompt(content), ok=False)
        self.shell(self.prompt().replace(ORIGIN, 'https://example.invalid/repo.git'), ok=False)
        self.shell(self.prompt().replace('a'*40, 'short-revision'), ok=False)

    def make_repo(self):
        repo = self.base/'checkout'
        repo.mkdir()
        def git(*args):
            return subprocess.check_output(['/usr/bin/git','-C',str(repo),'-c','core.hooksPath=/dev/null',*args],env=self.env,stderr=subprocess.DEVNULL).decode().strip()
        git('init','-q')
        for name in ('AGENTS.md','_index.md','docs/install/supervised-recovery-plan.md','docs/install/bootstrap-flow.md','scripts/installs/install_brew.sh','scripts/installs/install_claude.sh','scripts/installs/recovery_checks.sh'):
            dest=repo/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text('fixture\n')
        (repo/'notes.txt').write_text('user\n')
        git('add','.')
        git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture')
        git('remote','add','origin',ORIGIN)
        rev=git('rev-parse','HEAD')
        code=self.source_boot()+f'WORKSPACE={q(str(repo))}\nREVISION={rev}\nBOOTSTRAP_TEMP={q(str(self.base))}\nvalidate_checkout\n'
        return repo,git,code

    def test_checkout_preserves_unrelated_dirty_and_worktree(self):
        repo,git,code=self.make_repo()
        (repo/'notes.txt').write_text('legitimate staged change\n');git('add','notes.txt')
        (repo/'notes.txt').write_text('legitimate additional unstaged change\n')
        (repo/'personal.txt').write_text('untracked unrelated\n')
        before=git('status','--porcelain')
        self.shell(code)
        self.assertEqual(before,git('status','--porcelain'))
        worktree=self.base/'worktree';git('worktree','add','--detach',str(worktree),'HEAD')
        self.shell(code.replace(str(repo),str(worktree)))

    def test_checkout_rejects_recovery_edits_even_hidden(self):
        repo,git,code=self.make_repo()
        target=repo/'scripts/installs/install_brew.sh'
        target.write_text('changed\n')
        self.shell(code,ok=False)
        git('update-index','--assume-unchanged','scripts/installs/install_brew.sh')
        self.shell(code,ok=False)
        self.assertEqual(target.read_text(),'changed\n')

    def test_checkout_ignores_git_replacement_objects(self):
        repo,git,code=self.make_repo()
        original=git('rev-parse','HEAD')
        target=repo/'scripts/installs/install_brew.sh'
        target.write_text('changed recovery source\n')
        git('add','scripts/installs/install_brew.sh')
        git('-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','replacement')
        replacement=git('rev-parse','HEAD')
        # Disposable fixture only: model a nominal original HEAD whose tree is
        # silently replaced by Git. The source gate must read original objects.
        git('update-ref','HEAD',original)
        git('replace',original,replacement)
        before=git('status','--porcelain')
        self.shell(code,ok=False)
        self.assertEqual(target.read_text(),'changed recovery source\n')
        self.assertEqual(git('replace','-l'),original)
        self.assertEqual(before,git('status','--porcelain'))

    def test_checkout_rejects_origin_revision_shadow_and_redirect(self):
        repo,git,code=self.make_repo()
        self.shell(code.replace('REVISION=', 'REVISION=deadbeef #'),ok=False)
        git('remote','set-url','origin','https://example.invalid/wrong.git');self.shell(code,ok=False)
        git('remote','set-url','origin',ORIGIN)
        (repo/'scripts/installs/shadow.sh').write_text('shadow');self.shell(code,ok=False)
        (repo/'scripts/installs/shadow.sh').unlink()
        original=repo/'scripts/installs/install_brew.sh';original.unlink();original.symlink_to(repo/'_index.md')
        self.shell(code,ok=False)
        alias=self.base/'redirect';alias.symlink_to(repo)
        self.shell(code.replace(str(repo),str(alias)),ok=False)

    def test_clt_finite_timeout_cancel_and_success(self):
        common=self.source_boot()+'''xcode-select() { return 0; }; sleep() { :; }
        clt_ready() { return 1; }
        '''
        r=self.shell(common+'ensure_clt',ok=False)
        self.assertIn('1800',r.stdout)
        self.assertLessEqual(r.stdout.count('Waiting for CLT:'),180)
        self.shell(common+'xcode-select() { return 1; }; ensure_clt',ok=False)
        self.shell(common+'clt_ready() { return 0; }; ensure_clt')

    def test_source_freeze_branch_movement_and_download_failure(self):
        immutable=self.base/'executing.sh';immutable.write_text('original\n')
        common=self.source_boot()+f'''BOOTSTRAP_SOURCE={q(str(immutable))}
        BOOTSTRAP_TEMP={q(str(self.base))}
        REVISION=
        repo_git() {{ printf '%s refs/heads/master\n' {'a'*40}; }}
        download() {{ cp "$BOOTSTRAP_SOURCE" "$2"; }}
        '''
        self.shell(common+'resolve_source')
        self.shell(common+'download() { echo changed > "$2"; }; resolve_source',ok=False)
        self.shell(common+'download() { return 1; }; resolve_source',ok=False)

    def test_platform_rejections(self):
        common=self.source_boot()+'''uname() { case "$1" in -s) echo Darwin;; -m) echo arm64;; esac; }
        sysctl() { echo 0; }; sw_vers() { echo 26.0; }; df() { echo 'disk 0 0 20000000 0 /'; }
        download() { :; }
        '''
        self.shell(common+'platform_preflight; test "$BREW_BIN" = /opt/homebrew/bin/brew')
        self.shell(common+'uname() { echo Linux; }; platform_preflight',ok=False)
        self.shell(common+'sysctl() { echo 1; }; platform_preflight',ok=False)
        self.shell(common+'sw_vers() { echo 14.0; }; platform_preflight',ok=False)
        self.shell(common+'df() { echo "disk 0 0 1 0 /"; }; platform_preflight',ok=False)

    def test_brew_absent_from_path_and_wrong_prefix(self):
        prefix=self.base/'brew';binary=prefix/'bin/brew'
        self.script(binary,f'''case "$1" in
        --prefix) echo {q(str(prefix))};;
        --version) echo fixture-brew;;
        shellenv) echo 'export PATH="{prefix}/bin:$PATH"';;
        list) exit 0;;
        *) exit 98;; esac
        ''')
        self.script(prefix/'bin/git','echo fixture-git\n')
        # command -v must truly find no brew, not the fail-closed default stub.
        (self.stub/'brew').unlink()
        common=self.source_boot()+f'BREW_PREFIX={q(str(prefix))}; BREW_BIN={q(str(binary))}\n'
        self.shell(common+'ensure_brew')
        self.shell(common+'BREW_PREFIX=/wrong; ensure_brew',ok=False)
        self.script(self.stub/'brew','exit 99')
        self.shell(common+'ensure_brew',ok=False)

    def test_app_artifact_signature_and_executable(self):
        app=self.base/'Example.app';(app/'Contents/MacOS').mkdir(parents=True)
        self.script(app/'Contents/MacOS/Example','exit 0')
        (app/'Contents/Info.plist').write_text('fixture')
        common=f'''source {q(str(ROOT/'scripts/installs/recovery_checks.sh'))}
        plutil() {{ case "$*" in *CFBundleIdentifier*) echo example.id;; *CFBundleExecutable*) echo Example;; *) return 0;; esac; }}
        codesign() {{ return 0; }}
        '''
        self.shell(common+f'verify_app {q(str(app))} example.id')
        self.shell(common+f'codesign() {{ return 1; }}; verify_app {q(str(app))} example.id',ok=False)
        (app/'Contents/MacOS/Example').unlink()
        self.shell(common+f'verify_app {q(str(app))} example.id',ok=False)
        self.shell(common+f'verify_app {q(str(self.base/"Missing.app"))} example.id',ok=False)

    def test_cli_only_and_broken_cli(self):
        self.script(self.stub/'brew','test "$*" = "list --cask -1"\n')
        cli=self.home/'.local/bin/claude';self.script(cli,'echo native-fixture\n')
        self.shell(f'/bin/bash {q(str(ROOT/"scripts/installs/install_claude.sh"))} --cli-only')
        self.script(cli,'exit 5\n')
        self.shell(f'/bin/bash {q(str(ROOT/"scripts/installs/install_claude.sh"))} --cli-only',ok=False)
        cli.unlink()
        self.script(self.stub/'curl','exit 22\n')
        self.shell(f'/bin/bash {q(str(ROOT/"scripts/installs/install_claude.sh"))} --cli-only',ok=False)
        self.assertFalse(cli.exists())
        self.script(self.stub/'brew','echo claude-code\n')
        self.shell(f'/bin/bash {q(str(ROOT/"scripts/installs/install_claude.sh"))} --cli-only',ok=False)

    def test_iterm_running_no_writes_and_stopped_two_keys(self):
        log=self.base/'defaults.log'
        self.script(self.stub/'defaults',f'''case "$1" in read) exit 1;; write) echo "$*" >> {q(str(log))};; esac
        ''')
        self.script(self.stub/'pgrep','exit 0\n')
        cmd=f'/bin/bash {q(str(ROOT/"scripts/installs/install_iterm2.sh"))}'
        self.shell(cmd,ok=False);self.assertFalse(log.exists())
        self.script(self.stub/'pgrep','exit 2\n');self.shell(cmd,ok=False);self.assertFalse(log.exists())
        self.script(self.stub/'pgrep','exit 1\n');self.shell(cmd)
        lines=log.read_text().splitlines();self.assertEqual(len(lines),2)
        self.assertIn('PrefsCustomFolder',lines[0]);self.assertIn('LoadPrefsFromCustomFolder',lines[1])
        self.assertNotIn('Save',log.read_text())

    def test_desktop_fallback_requires_confirmed_process_absence(self):
        # Rewrite only the app destination into this fixture; the real app is
        # never queried, copied, started or replaced. All external mutations
        # retain deny-by-default stubs.
        candidate=self.base/'install_claude.sh'
        shutil.copyfile(ROOT/'scripts/installs/helper_prompt.sh',self.base/'helper_prompt.sh')
        candidate.write_text((ROOT/'scripts/installs/install_claude.sh').read_text().replace('/Applications/',str(self.base/'Applications')+'/'))
        cmd=f'/bin/bash {q(str(candidate))} --desktop-fallback'
        for status in (0,2):
            self.script(self.stub/'pgrep',f'exit {status}\n')
            result=self.shell(cmd,ok=False)
            self.assertIn('Claude',result.stdout)
            self.assertFalse((self.base/'Applications').exists())

    def test_five_links_and_unique_backups_rerun(self):
        # Real file operations target the isolated HOME only; all link sources are
        # read-only repo files, and no source activation/app commands occur.
        (self.home/'.zshrc').write_text('original shell')
        (self.home/'.aerospace.toml').symlink_to('/old-config')
        cmd=f'/bin/bash {q(str(ROOT/"scripts/installs/setup_symlinks.sh"))}'
        self.shell(cmd)
        links={'.zshrc':'zsh/zshrc.zsh','.aerospace.toml':'configs/aerospace/aerospace.toml',
               '.config/borders':'configs/borders','.config/sketchybar':'configs/sketchybar',
               'Library/Application Support/Code/User/settings.json':'configs/vscode/settings.json'}
        for target,source in links.items(): self.assertEqual(os.readlink(self.home/target),str(ROOT/source))
        backup=list(self.home.glob('.zshrc.bak.*/original'));self.assertEqual(len(backup),1)
        self.assertEqual(backup[0].read_text(),'original shell')
        wrong=list(self.home.glob('.aerospace.toml.bak.*'));self.assertEqual(os.readlink(wrong[0]/'original'),'/old-config')
        self.shell(cmd);self.assertEqual(len(list(self.home.glob('.zshrc.bak.*'))),1)

    def test_loaders_in_fresh_zsh_without_startup_side_effects(self):
        prefix=self.base/'brew'
        self.script(prefix/'bin/brew',f'''echo 'export HOMEBREW_PREFIX="{prefix}"; export PATH="{prefix}/bin:$PATH"'
        ''')
        nvm=prefix/'opt/nvm/nvm.sh';nvm.parent.mkdir(parents=True);nvm.write_text('export NVM_FIXTURE_LOADED=1\n')
        self.script(self.stub/'uname','echo arm64')
        path=self.base/'path.zsh';path.write_text((ROOT/'zsh/configs/path.zsh').read_text().replace('/opt/homebrew/bin/brew',str(prefix/'bin/brew')))
        r=subprocess.run(['/bin/zsh','-f','-c',f'source {q(str(path))}; source {q(str(ROOT/"zsh/configs/nvm.zsh"))}; test "$NVM_FIXTURE_LOADED" = 1; test "$path[1]" = "$HOME/.local/bin"'],env=self.env,capture_output=True,text=True)
        self.assertEqual(r.returncode,0,r.stderr)

    def test_handoff_boundary_no_full_install_and_failed_cli_no_success(self):
        # Actual minimum_handoff + renderer, but child installers are explicit
        # fixture scripts, and validation is separately covered by Git fixtures.
        workspace=self.home/'workspace';inst=workspace/'scripts/installs';inst.mkdir(parents=True)
        guide=workspace/'docs/install/supervised-recovery-plan.md';guide.parent.mkdir(parents=True);guide.write_text(GUIDE.read_text())
        shutil.copyfile(ROOT/'scripts/installs/recovery_checks.sh',inst/'recovery_checks.sh')
        log=self.base/'stages.log'
        for name in ('install_brew.sh','install_claude.sh'):
            self.script(inst/name,f'echo "{name} $*" >> {q(str(log))}\n')
        self.script(inst/'installation.sh','echo FULL_INSTALL_FORBIDDEN; exit 99')
        self.script(self.home/'.local/bin/claude','echo fixture-claude')
        prefix=self.base/'brew';self.script(prefix/'bin/codex','echo fixture-codex')
        common=self.source_boot()+f'''WORKSPACE={q(str(workspace))}; BREW_PREFIX={q(str(prefix))}; REVISION={'a'*40}
        validate_checkout() {{ return 0; }}
        minimum_handoff
        '''
        r=self.shell(common)
        self.assertEqual(r.stdout.count('Step1done'),1)
        self.assertEqual(r.stdout.count('----- BEGIN RECOVERY PROMPT -----'),1)
        context, prompt = r.stdout.split('----- BEGIN RECOVERY PROMPT -----')
        prompt = prompt.split('----- END RECOVERY PROMPT -----')[0].strip()
        for value in (str(workspace), str(guide), ORIGIN, 'a'*40, str(self.home/'.local/bin/claude'), str(prefix/'bin/codex')):
            self.assertIn(value, context)
            self.assertNotIn(value, prompt)
        self.assertEqual(prompt, GUIDE.read_text().split('<!-- recovery-prompt:start -->\n```text\n')[1].split('\n```\n<!-- recovery-prompt:end -->')[0])
        self.assertNotIn('FULL_INSTALL_FORBIDDEN',r.stdout)
        self.assertEqual(log.read_text().splitlines(),['install_brew.sh --phase minimal','install_claude.sh --cli-only','install_brew.sh --phase minimal --verify-only'])
        self.script(prefix/'bin/codex','exit 1');self.shell(common,ok=False)
        self.assertFalse((self.home/'.zshrc').exists())

    def test_pipe_without_tty_fails_closed(self):
        r=subprocess.run([BASH],input=BOOT.read_text(),env=self.env,text=True,capture_output=True,start_new_session=True,timeout=20)
        self.assertNotEqual(r.returncode,0)
        self.assertIn('No controlling terminal',r.stderr)
        self.assertNotIn('Step1done',r.stdout)
        self.assertNotIn('UNEXPECTED HOST COMMAND',r.stderr)

    def tty_shell(self, body, ok=True):
        master, slave = pty.openpty()
        def controlling_terminal():
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)
        try:
            r = subprocess.run([BASH, '--noprofile', '--norc', '-c', 'set -e\n'+body],
                               stdin=slave, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               env=self.env, text=True, timeout=20, preexec_fn=controlling_terminal)
        finally:
            os.close(master); os.close(slave)
        self.assertNotIn('UNEXPECTED HOST COMMAND',r.stdout)
        if ok: self.assertEqual(r.returncode,0,r.stdout)
        else:
            self.assertNotEqual(r.returncode,0,r.stdout)
            self.assertNotIn('Step1done',r.stdout)
        return r

    def test_tty_download_failure_and_interrupt_cleanup(self):
        self.tty_shell(self.source_boot()+'BOOTSTRAP_SOURCE=; download() { return 22; }; bootstrap_main',ok=False)
        marker=self.base/'temporary-path'
        body=self.source_boot()+f'''platform_preflight() {{ echo "$BOOTSTRAP_TEMP" > {q(str(marker))}; }}
        ensure_clt() {{ kill -INT "$$"; }}
        bootstrap_main
        '''
        r=self.tty_shell(body,ok=False)
        self.assertEqual(r.returncode,130)
        self.assertFalse(Path(marker.read_text().strip()).exists())

    def test_main_stage_failure_stops_and_rerun_order(self):
        stages=['platform_preflight','ensure_clt','ensure_brew','resolve_source','prepare_checkout','minimum_handoff']
        for failure in stages:
            body=self.source_boot()
            for stage in stages:
                body+=f'{stage}() {{ echo {stage}; return {1 if stage==failure else 0}; }}\n'
            r=self.tty_shell(body+'bootstrap_main',ok=False)
            self.assertEqual([x for x in r.stdout.splitlines() if x in stages],stages[:stages.index(failure)+1])
        body=self.source_boot()+''.join(f'{stage}() {{ echo {stage}; }}\n' for stage in stages)
        r=self.tty_shell(body+'bootstrap_main')
        self.assertEqual(r.stdout.splitlines(),stages)

    def test_document_links_and_runtime_boundaries(self):
        for name in ('docs/install/bootstrap-flow.md','docs/install/supervised-recovery-plan.md'):
            path=ROOT/name
            for link in re.findall(r'\]\(([^)]+)\)',path.read_text()):
                if '://' not in link and not link.startswith('#'):
                    self.assertTrue((path.parent/link.split('#')[0]).exists(),(name,link))
        source=BOOT.read_text()
        self.assertNotRegex(source,r'(?:exec|bash)\s+[^\n]*installation\.sh')
        self.assertNotIn('install-rosetta',source)
        self.assertNotIn('setup_symlinks.sh',source)
        # New code cannot hide absolute invocations of host operations from mocks.
        for name in ('bootstrap.sh','install_brew.sh','recovery_checks.sh','install_claude.sh','install_iterm2.sh'):
            body=(ROOT/'scripts/installs'/name).read_text()
            self.assertNotRegex(body,r'(?:^|\s)/(?:usr/bin|usr/sbin|bin)/(?:brew|curl|sudo|defaults|pgrep|codesign|plutil|open|osascript|launchctl|xattr|spctl)\b')
        install=(ROOT/'scripts/installs/installation.sh').read_text()
        self.assertLess(install.index('bash "$INSTALLS/install_node.sh"'),install.index('bash "$INSTALLS/setup_symlinks.sh"'))

if __name__ == '__main__':
    unittest.main(verbosity=2)
