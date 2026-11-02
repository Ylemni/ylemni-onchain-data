-- L0-M0-L1
-- BigQuery First Contact
-- ylemni

-- 1. Check BigQuery environment
SELECT
    CURRENT_DATE() AS today_utc,
    CURRENT_TIMESTAMP() AS now_utc;


-- 2. Query a general public dataset
SELECT
    name,
    gender,
    SUM(number) AS total
FROM
    `bigquery-public-data.usa_names.usa_1970_2013`
GROUP BY
    name,
    gender
ORDER BY
    total DESC
LIMIT
    10;


-- 3. Query Ethereum Mainnet blocks
SELECT
    MIN(block_number) AS first_block,
    MAX(block_number) AS newest_block,
    COUNT(1) AS total_blocks
FROM
    `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.blocks`;


-- 4. Cost experiment: one column
SELECT
    block_number
FROM
    `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.blocks`;
LIMIT
    10;


-- 5. Cost experimnet: time filter
SELECT
    block_number
FROM
    `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.blocks`;
WHERE
    block_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
LIMIT
    10;