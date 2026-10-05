-- TalaDelivery platform databases (mounted into postgres:16 init scripts).
-- Each NestJS service owns exactly one database; no cross-service joins.

DO $$ BEGIN
  CREATE ROLE tala WITH LOGIN PASSWORD 'tala_dev_password';
  EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE DATABASE taladelivery_identity OWNER tala;
  EXCEPTION WHEN duplicate_database THEN NULL;
END $$;

DO $$ BEGIN
  CREATE DATABASE taladelivery_merchant OWNER tala;
  EXCEPTION WHEN duplicate_database THEN NULL;
END $$;

DO $$ BEGIN
  CREATE DATABASE taladelivery_catalog OWNER tala;
  EXCEPTION WHEN duplicate_database THEN NULL;
END $$;

DO $$ BEGIN
  CREATE DATABASE taladelivery_order OWNER tala;
  EXCEPTION WHEN duplicate_database THEN NULL;
END $$;

DO $$ BEGIN
  CREATE DATABASE taladelivery_dispatch OWNER tala;
  EXCEPTION WHEN duplicate_database THEN NULL;
END $$;

DO $$ BEGIN
  CREATE DATABASE taladelivery_payment OWNER tala;
  EXCEPTION WHEN duplicate_database THEN NULL;
END $$;

DO $$ BEGIN
  CREATE DATABASE taladelivery_notification OWNER tala;
  EXCEPTION WHEN duplicate_database THEN NULL;
END $$;