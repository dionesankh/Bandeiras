# Supabase SQL Test Scripts

These files are intentionally kept outside `supabase/migrations`.

- `10_tests_seed.sql` inserts development-only sample data.
- `11_validation_tests.sql` performs destructive validation setup with deletes.
- `12_final_audit_checks.sql` is an operational audit script, not persistent schema.

Run these only against disposable/local databases or after manually reviewing each statement.
They must not be applied by `supabase db push` as production migrations.
