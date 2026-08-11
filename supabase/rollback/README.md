# Rollback Options For Migration 25

Do not apply migration 25 until both backup files exist, have nonzero size, and
the `supabase db dump` commands have completed without error:

- `backups/pre_25_schema.sql`
- `backups/pre_25_data.sql`

Rollback options:

- `25_remote_history_alignment_security_rollback.sql`
  Restores the previously audited remote state as closely as possible, including
  removing profile RPCs that were absent before migration 25 and restoring the
  old `submit_ranked_result` expiration behavior.

- `25_remote_history_alignment_security_frontend_compatible_rollback.sql`
  Restores the broader previous grants/policies but keeps the RPCs used by the
  current frontend and keeps the fixed `submit_ranked_result` expiration flow.

Neither rollback file should be executed unless migration 25 has already been
applied and the chosen rollback mode has been explicitly approved.
