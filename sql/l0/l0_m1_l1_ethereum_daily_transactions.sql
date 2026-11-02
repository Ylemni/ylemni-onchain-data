-- L0-M1-L1
-- Ethereum Daily Transactions
--
-- Goal:
-- Build and validate a daily Ethereum transaction count metric.
--
-- Table:
-- bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions


-- 1. Inspect recent transactions
-- Purpose:
-- Read only needed columns and restrict the time range.

SELECT
  block_timestamp,
  transaction_hash,
  from_address,
  to_address
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  block_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
LIMIT 20;


-- 2. Daily transaction count
-- Definition:
-- Completed 7 UTC days, excluding today.

SELECT
  DATE(block_timestamp) AS day,
  COUNT(*) AS transaction_count
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  DATE(block_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND DATE(block_timestamp) < CURRENT_DATE()
GROUP BY
  day
ORDER BY
  day ASC;


-- 3. Validation: total rows in the same period

SELECT
  COUNT(*) AS total_transactions
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  DATE(block_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND DATE(block_timestamp) < CURRENT_DATE();


-- 4. Validation: row count vs unique transaction hash

SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT transaction_hash) AS unique_transactions
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  DATE(block_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND DATE(block_timestamp) < CURRENT_DATE();


-- 5. Solo Challenge:
-- Rank the completed 7 days by transaction count.

SELECT
  DATE(block_timestamp) AS day,
  COUNT(*) AS transaction_count
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  DATE(block_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND DATE(block_timestamp) < CURRENT_DATE()
GROUP BY
  day
ORDER BY
  transaction_count DESC;

-- Note:
-- CURRENT_DATE() makes this query dynamic.
-- Re-running it on another day changes the 7-day analysis window.