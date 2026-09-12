# Mac reinstallation

Purpose: restore the managed environment from `~/workspace`. Scripts and saved configuration define the contents; this file defines the process.

## Main paths

- `AGENTS.md`, `_index.md`: workspace rules, source map, domain guides.
- `scripts/installs/bootstrap.sh`: minimum preparation; authentication handoff.
- `scripts/installs/installation.sh`: main installer; runs the setup sequence under AI supervision or manually.
- `scripts/`: executable setup and system operations.
- `configs/`, `zsh/`: saved configuration and shell sources.
- `functions/`: shared script helpers.
- `docs/`: process and domain context.

## Sequence

1. **User — start.** Finish macOS installation; connect internet; open Terminal; run:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/teazyou/workspace/master/scripts/installs/bootstrap.sh | bash
   ```

2. **Bootstrap — minimum readiness.** Check prerequisites; install required foundations; obtain and validate one published revision at `~/workspace`; install minimum tools; verify readiness. Print `Step1done`, authentication/launch instructions, revision context, and a short prompt. Exit. Remaining installation waits.

3. **User — handoff.** Choose either installed local AI CLI/provider; authenticate; open the workspace; paste the printed prompt. One provider sufficient; no model requirement. Session must have local file and command access.

4. **AI + scripts — remaining setup.** Work directly in the main session; no delegation. Read workspace rules, index, relevant sources and domain guides. Retain bootstrap context; reconcile existing changes. Start with `bash ~/workspace/scripts/installs/installation.sh`; it initializes the environment and runs the setup scripts in dependency order. Observe output; on failure, repair and rerun the affected step, then continue unfinished steps using the same environment. Scripts install dependencies and apply/link saved configuration. Follow script notices and domain guides for additional manual setup. Verify actual outcomes and required reloads after each step.

5. **User — required interactions.** Handle credentials, account sign-in, permissions and approvals. Agree timing for actions that interrupt the active session; save progress before interruption. Keep secrets outside repository and AI context.

6. **AI — closeout.** Report verified results, blockers, deferred work and pending human checks. Script exit alone does not establish full restoration.

## Failure / resume

AI: diagnose failure; repair the managed script; rerun the affected step; verify. Preserve existing work and backups. Continue independent steps when blocked. Resume unfinished phase 2 directly; bootstrap may reject its legitimate source changes. Configuration activation follows scripts/domain rules; system-interface edits are not automatically saved into this repository.
