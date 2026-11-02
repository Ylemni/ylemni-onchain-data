-- L0-M1-L2 — NULL, CASE & Ethereum Transaction Destinations
-- BigQuery / GoogleSQL
-- Source: bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions
-- Note: CURRENT_DATE() makes the 7-day window move when this file is rerun.

-- Query 1. Inspect completed-7-day transactions whose to_address is NULL.
SELECT
  block_timestamp,
  transaction_hash,
  from_address,
  to_address
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  DATE(block_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND DATE(block_timestamp) < CURRENT_DATE()
  AND to_address IS NULL
LIMIT 20;

-- Query 2. Compare all rows with rows whose to_address is non-NULL.
SELECT
  COUNT(*) AS total_rows,
  COUNT(to_address) AS non_null_to_address,
  COUNT(*) - COUNT(to_address) AS null_to_address_by_difference
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  DATE(block_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND DATE(block_timestamp) < CURRENT_DATE();

-- Query 3. Keep transaction-level grain and classify each row with CASE.
SELECT
  block_timestamp,
  transaction_hash,
  to_address,
  CASE
    WHEN to_address IS NULL THEN 'contract_creation'
    ELSE 'existing_destination'
  END AS destination_type
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  DATE(block_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND DATE(block_timestamp) < CURRENT_DATE()
LIMIT 20;

-- Query 4. Aggregate the 7-day period by destination_type.
-- Output grain: 1 row per destination_type.
SELECT
  CASE
    WHEN to_address IS NULL THEN 'contract_creation'
    ELSE 'existing_destination'
  END AS destination_type,
  COUNT(*) AS transaction_count
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  DATE(block_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND DATE(block_timestamp) < CURRENT_DATE()
GROUP BY
  destination_type
ORDER BY
  destination_type;

-- Query 5. Main analysis: daily transaction count by destination_type.
-- Output grain: 1 row per day × destination_type.
SELECT
  DATE(block_timestamp) AS day,
  CASE
    WHEN to_address IS NULL THEN 'contract_creation'
    ELSE 'existing_destination'
  END AS destination_type,
  COUNT(*) AS transaction_count
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  DATE(block_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND DATE(block_timestamp) < CURRENT_DATE()
GROUP BY
  day,
  destination_type
ORDER BY
  day,
  transaction_count DESC;

-- Query 6. Validation: count contract-creation rows through a different path.
-- Compare this with the contract_creation row from Query 4.
SELECT
  COUNT(*) AS contract_creation_direct
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  DATE(block_timestamp) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
  AND DATE(block_timestamp) < CURRENT_DATE()
  AND to_address IS NULL;
