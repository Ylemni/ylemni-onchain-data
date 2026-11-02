-- ================================================================
-- L0-M2-L1 — Ethereum Blocks & Transactions Foundations
-- GoogleSQL / Google Blockchain Analytics / Ethereum Mainnet
-- ================================================================
-- Purpose
--   1) S5: Validate one observed Block against Etherscan;
--   2) S6: Check row/identifier uniqueness and metric boundaries;
--   3) S7: Independently aggregate and compare 7 completed UTC days.
--
-- Protocol mental model (S1–S4; NOT derived from these queries):
--   transaction signing/broadcast != block inclusion != execution success
--   != finality; block_timestamp != transaction signing/broadcast time.
--   blocks and transactions have different source grains.
--   Slot counts, validator failures, reorgs and finalized status are NOT
--   established by simply counting these BigQuery tables.
--
-- Source grain expectations:
--   blocks: one row per observed execution block.
--   transactions: one row per observed included top-level transaction.
-- Output grain for daily queries: one row per UTC day.
--
-- Data provenance: Numerical results in the companion Markdown are from
-- the student's reported executions on 2026-10-20; NOT independently rerun.
-- BigQuery Sandbox: check estimated bytes processed BEFORE executing.
-- LIMIT restricts returned rows but does NOT guarantee lower scan cost.
-- Google Blockchain Analytics table coverage/freshness may differ from the
-- Ethereum network; compare fields and metadata before broad conclusions.
--
-- Submission clean-up: student's pasted SQL used undefined aliases
--   blocks_by_day, transaction_by_day in GROUP BY/ORDER BY.
--   Corrected to declared SELECT alias "day" below.
-- ================================================================

-- Query 01. S5 | Observe one execution Block in BigQuery.
-- A reproducible block + UTC-day filter. Expected: one matching block row.
SELECT
  block_number,
  block_timestamp
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.blocks`
WHERE
  block_number = 26158300
  AND block_timestamp >= TIMESTAMP('2026-10-09 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00')
LIMIT 1;
-- Student observation: Block 26158300, 2026-10-09 23:59:59 UTC.
-- Etherscan height: 26158300.

-- Query 02. S5 | Count top-level transactions in the same Block.
SELECT
  COUNT(*) AS transaction_count
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  block_number = 26158300
  AND block_timestamp >= TIMESTAMP('2026-10-09 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00');
-- Student observation: 165 included transaction rows.
-- Etherscan ordinary Transactions 165; internal transactions 75 separately.
-- Never add 75 to 165 and call the result top-level transaction count.

-- Query 03. S5 | Inspect transaction identifiers: same block, distinct tx.
-- ORDER BY transaction_hash is only display order, NOT on-chain tx order.
SELECT
  transaction_hash,
  block_number,
  block_timestamp
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  block_number = 26158300
  AND block_timestamp >= TIMESTAMP('2026-10-09 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00')
ORDER BY
  transaction_hash
LIMIT 5;

-- Query 04. S6 | Null/duplicate identifier diagnostic in one Block.
-- COUNT(*) >= COUNT(non-null hash) >= COUNT(DISTINCT hash).
SELECT
  COUNT(*) AS total_rows,
  COUNT(transaction_hash) AS nonnull_hash_rows,
  COUNT(DISTINCT transaction_hash) AS distinct_hashes
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  block_number = 26158300
  AND block_timestamp >= TIMESTAMP('2026-10-09 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00');
-- Student observation: 165 / 165 / 165 => no hash NULL/duplicates
-- in this filtered subset; does NOT prove chain-wide completeness.

-- Query 05. S6 | Blocks on one day: row count versus block-number count.
SELECT
  COUNT(*) AS block_rows,
  COUNT(DISTINCT block_number) AS distinct_block_numbers
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.blocks`
WHERE
  block_timestamp >= TIMESTAMP('2026-10-09 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00');
-- Student observation: 7178 / 7178.
-- Checks block_number uniqueness in this interval; NOT block_hash.

-- Query 06. S6 | Transactions on one day, and transaction-bearing blocks.
SELECT
  COUNT(*) AS transaction_rows,
  COUNT(DISTINCT transaction_hash) AS distinct_transactions,
  COUNT(DISTINCT block_number) AS blocks_with_transactions
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  block_timestamp >= TIMESTAMP('2026-10-09 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00');
-- Student observation: 1801067 / 1801067 / 7178.
-- blocks_with_transactions != necessarily all blocks table rows.

-- Query 07. S7 Task A | Seven daily block metrics.
-- Source grain = observed execution block; output grain = UTC day.
SELECT
  DATE(block_timestamp) AS day,
  COUNT(*) AS block_rows,
  COUNT(DISTINCT block_number) AS distinct_blocks
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.blocks`
WHERE
  block_timestamp >= TIMESTAMP('2026-10-03 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00')
GROUP BY
  day
ORDER BY
  day ASC;
-- Student observations are recorded in the companion Markdown.

-- Query 08. S7 Task B | Seven daily transaction metrics.
-- Source grain = observed included top-level transaction.
-- Output grain = UTC day, NOT UTC day x block.
SELECT
  DATE(block_timestamp) AS day,
  COUNT(*) AS transaction_rows,
  COUNT(DISTINCT transaction_hash) AS distinct_transactions,
  COUNT(DISTINCT block_number) AS blocks_with_transactions
FROM
  `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`
WHERE
  block_timestamp >= TIMESTAMP('2026-10-03 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00')
GROUP BY
  day
ORDER BY
  day ASC;
-- 2026-10-05: blocks table 7175 vs transaction-bearing blocks 7174.
-- 2026-10-06: blocks table 7168 vs transaction-bearing blocks 7167.
-- Comparing cardinalities alone does NOT prove that exact block-number
-- sets match. Investigate actual members in a future relational SQL lesson.
-- No additional JOIN/CTE/subquery has been introduced in this lesson.

-- Interpretation reminder:
--   COUNT(*) = COUNT(DISTINCT identifier) means no NULL/duplicate
--   identifiers in the filtered rows; it does not prove source completeness.
--   Daily block count is not an exact count of missed slots or validators.
--   Included transaction count is not users, success count, ETH value,
--   ERC-20 transfer logs, or mempool broadcast count.
