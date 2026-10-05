-- Each service owns its database. CREATE DATABASE must run outside a transaction.
-- The official Postgres image creates POSTGRES_USER before this script runs.
SELECT format('CREATE DATABASE %I OWNER %I', name, current_user)
FROM (VALUES
  ('taladelivery_identity'),
  ('taladelivery_merchant'),
  ('taladelivery_catalog'),
  ('taladelivery_order'),
  ('taladelivery_dispatch'),
  ('taladelivery_payment'),
  ('taladelivery_notification')
) AS databases(name)
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = name)
\gexec
