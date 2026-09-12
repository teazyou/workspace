# Codex global permissions

`configs/codex/permissions.toml` is the managed source for the global permission defaults: no command approval prompts and unrestricted filesystem/network access.

Activation: merge these two keys into the top level of `~/.codex/config.toml`, before any table header, replacing existing values for those keys. Preserve all other settings. This is a configuration fragment, not a symlink or a replacement for the complete live config; plugin and app settings remain in the live file. Back up the live file before changing it. The defaults were applied on 2026-09-12.

Start a new CLI session and restart the desktop app to load the defaults. Existing tasks can retain their permission settings. Explicit session/project overrides and administrator requirements can take precedence; macOS permissions and connector authorization are separate.

Reference: [official configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference).
