#!/bin/bash
# scripts/installs/install_database.sh
#
# Purpose:
#   Brings MySQL and PostgreSQL up to a usable state on a fresh install.
#
#   - Starts both as brew services so they auto-start at login.
#   - Runs `mysql_secure_installation` interactively (you set the root
#     password yourself — no credentials live in this public repo).
#   - Creates a default postgres database matching your Unix username so
#     `psql` works without arguments.
#
# Idempotent: starting an already-running brew service is a no-op, and
# `createdb` is wrapped to ignore "already exists".

set -e

# shellcheck source=/dev/null
source "$INSTALLS/helper_prompt.sh"

# --- MySQL --------------------------------------------------------------
log_step "MySQL"
if brew services list | awk '{print $1, $2}' | grep -E '^mysql started' &>/dev/null; then
    log_ok "MySQL already running"
else
    log_wait "Starting MySQL service ..."
    brew services start mysql
    # Give the daemon a moment to come up before mysql_secure_installation.
    sleep 3
    log_ok "MySQL started"
fi

# mysql_secure_installation is interactive (root password, remove anon
# users, etc.). The README intentionally has you type the password — no
# credentials in this public repo.
log_wait "Next: mysql_secure_installation (interactive — sets root password, removes anon users, etc.)"
log_wait "Press ENTER below to launch it here in this terminal."
prompt_continue "Press ENTER to run mysql_secure_installation now (do NOT open a new terminal)."
mysql_secure_installation || log_err "mysql_secure_installation exited non-zero (carry on if it was just 'no changes needed')"

# --- PostgreSQL ---------------------------------------------------------
# The brew service is named "postgresql@N". We detect which version is
# installed (whichever the brew script picked at install time).
log_step "PostgreSQL"
PG_SERVICE=$(brew services list | awk '{print $1}' | grep -E '^postgresql(@[0-9]+)?$' | head -1)

if [[ -z "$PG_SERVICE" ]]; then
    log_err "No postgresql brew service found — was install_brew.sh run?"
    exit 1
fi

if brew services list | awk '{print $1, $2}' | grep -E "^${PG_SERVICE} started" &>/dev/null; then
    log_ok "$PG_SERVICE already running"
else
    log_wait "Starting $PG_SERVICE ..."
    brew services start "$PG_SERVICE"
    sleep 3
    log_ok "$PG_SERVICE started"
fi

# Default database that matches your username — psql/pg tools use this
# implicitly, so `psql` (no args) just works.
DB_USER=$(whoami)
log_wait "Ensuring default database '$DB_USER' exists ..."
if createdb "$DB_USER" 2>/dev/null; then
    log_ok "Database '$DB_USER' created"
else
    log_ok "Database '$DB_USER' already exists (or createdb fell through)"
fi

log_ok "Databases ready"
