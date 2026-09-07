#!/usr/bin/env bash
# Back up the internal SQLite database.
#
# Uses `VACUUM INTO` rather than copying the file. A live SQLite database in
# WAL mode is two files plus an in-flight write-ahead log, and `cp` of the
# main file alone produces a backup that restores to a torn state -- usually
# without complaining. VACUUM INTO asks SQLite itself for a consistent,
# already-compacted snapshot while the app keeps serving.
set -euo pipefail

SERVICE=codeknight
DB=/data/codeknight.db
DEST=${BACKUP_DIR:-/srv/backups/codeknight}
KEEP=${KEEP_DAYS:-14}
STAMP=$(date -u +%Y%m%dT%H%M%SZ)

mkdir -p "$DEST"

# node:sqlite ships with the runtime image, so the backup needs no extra tool.
docker compose exec -T "$SERVICE" node -e "
  const { DatabaseSync } = require('node:sqlite');
  const db = new DatabaseSync('$DB');
  db.exec(\"vacuum into '/tmp/backup.db'\");
" >/dev/null

docker compose cp "$SERVICE:/tmp/backup.db" "$DEST/codeknight-$STAMP.db"
docker compose exec -T "$SERVICE" rm -f /tmp/backup.db

gzip -f "$DEST/codeknight-$STAMP.db"

# Prune old snapshots. -mtime is days, so KEEP is in days.
find "$DEST" -name 'codeknight-*.db.gz' -mtime "+$KEEP" -delete

echo "backup: $DEST/codeknight-$STAMP.db.gz"
