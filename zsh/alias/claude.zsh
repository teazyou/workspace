# `sopaios [args]` = `claude [args]` with the SOPAIOS plugin loaded from disk
# (--plugin-dir), so each session picks up the current working copy instead of
# a cached install. Same script backs the VS Code extension's
# `claudeCode.claudeProcessWrapper` setting. Lives at scripts/claude/sopaios.sh.
alias sopaios="$SCRIPTS/claude/sopaios.sh"

# `caveman-compress [--opus|--sonnet|--haiku] [--low|--medium|--high|--xhigh|--max] [--<seconds>] <file>`
# = compress <file> in place via a background interactive claude session (no -p)
# running the /caveman-compress slash command; prints the session's <result>
# summary. Lives at scripts/claude/caveman_compress.sh.
alias caveman-compress="$SCRIPTS/claude/caveman_compress.sh"
