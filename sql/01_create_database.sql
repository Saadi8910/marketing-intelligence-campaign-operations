-- =====================================================================
-- 01_create_database.sql
-- Project : Marketing Intelligence & Campaign Operations (portfolio)
-- Purpose : Create the project database.
-- Target  : MySQL 8.0+
-- Run     : mysql -u <user> -p < sql/01_create_database.sql
-- =====================================================================
-- utf8mb4 is used so that any text (e.g. country names) loads without
-- encoding loss. The source CSV is UTF-8 with a byte-order mark (BOM).
-- =====================================================================

CREATE DATABASE IF NOT EXISTS marketing_intelligence
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE marketing_intelligence;

-- Layering convention used throughout the project:
--   raw_*   : data exactly as delivered (all text, no business rules)
--   stg_*   : typed, standardised, flagged data (one row per source row)
--   dim_* / fact_* views : analytical layer consumed by Power BI
--   vw_dq_* : data-quality reporting
--   monitoring_* / vw_monitoring_* : objects used by the n8n workflow
SELECT 'Database marketing_intelligence ready' AS status;
