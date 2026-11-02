-- ============================================================================
-- Ethereum Accounts, EOA, Contract & Account State
-- Case study: Ethereum Mainnet USDC contract | 2026-10-09 UTC
-- Dialect: GoogleSQL / BigQuery
-- Source: Google Cloud Blockchain Analytics public dataset
-- ============================================================================
--
-- Research questions:
--   1. Is the target address classified as a contract by this provider?
--   2. How many INCLUDED top-level transactions had this contract as
--      their initial destination on the specified UTC day?
--   3. What nonce values and block heights were OBSERVED for the account?
--   4. Is protocol contract nonce an appropriate USDC usage metric?
--
-- Dataset:
--   bigquery-public-data.goog_blockchain_ethereum_mainnet_us
-- Address (USDC Ethereum mainnet, lowercase dataset representation):
--   0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48
-- UTC window: [2026-10-09 00:00:00, 2026-10-10 00:00:00)
--
-- Read BigQuery estimated bytes before running. LIMIT limits returned
-- rows, but does not guarantee a corresponding reduction in scanned data.
--
-- Reference documentation:
-- https://docs.cloud.google.com/blockchain-analytics/docs/schema
-- https://docs.cloud.google.com/blockchain-analytics/docs/known-issues
-- https://ethereum.org/en/developers/docs/accounts/
-- ============================================================================

-- Query 01 | Provider's account-type classification
-- Expected from recorded execution: is_contract = TRUE.
-- This does not establish contract security or individual ownership.
SELECT
  address,
  is_contract,
  code_hash
FROM
  `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.accounts`
WHERE
  address = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
LIMIT 5;

-- Query 02 | Sample the account-state observations (optional)
-- Grain: an observed state record at a block height, subject to source
-- coverage. The output is NOT every account x block snapshot.
-- No sample-query result is claimed in the accompanying research note.
SELECT
  address,
  block_number,
  block_timestamp,
  nonce
FROM
  `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.accounts_state_by_address`
WHERE
  address = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
  AND block_timestamp >= TIMESTAMP('2026-10-09 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00')
ORDER BY
  block_number ASC
LIMIT 10;

-- Query 03 | Main metric A: included top-level destination transactions
-- Recorded BigQuery result: 169723.
-- NOT equivalent to USDC token transfers, successful transactions,
-- internal calls, individual users, or transfers of native ETH.
SELECT
  COUNT(*) AS top_level_destination_transactions
FROM
  `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.transactions_by_to_address`
WHERE
  to_address = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
  AND block_timestamp >= TIMESTAMP('2026-10-09 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00');

-- Query 04 | Main metric B: observed nonce AND observed block range
-- Recorded nonce result from earlier query:
--   min_observed_nonce = 1
--   max_observed_nonce = 1
--   observed_nonce_range = 0
--   min_observed_block_number = 26151123
--   max_observed_block_number = 26158300
--   observed_block_span = 7177
--
-- The block-span calculation alone (MAX(block_number)-MIN(block_number))
-- does NOT supply the two actual boundary heights. Both are selected.
-- The nonce range is not the count of successful contract deployments.
SELECT
  MIN(nonce) AS min_observed_nonce,
  MAX(nonce) AS max_observed_nonce,
  MAX(nonce) - MIN(nonce) AS observed_nonce_range,
  MIN(block_number) AS min_observed_block_number,
  MAX(block_number) AS max_observed_block_number,
  MAX(block_number) - MIN(block_number) AS observed_block_span
FROM
  `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.accounts_state_by_address`
WHERE
  address = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
  AND block_timestamp >= TIMESTAMP('2026-10-09 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00');

-- Query 05 | Optional observation-density diagnostic
-- Intended to compare recorded state rows and distinct observed block
-- heights. These metrics are NOT counts of changes, calls, or transfers.
-- No observed values are claimed for this optional query.
SELECT
  COUNT(*) AS observed_state_rows,
  COUNT(DISTINCT block_number) AS distinct_observed_block_heights
FROM
  `bigquery-public-data.goog_blockchain_ethereum_mainnet_us.accounts_state_by_address`
WHERE
  address = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
  AND block_timestamp >= TIMESTAMP('2026-10-09 00:00:00+00')
  AND block_timestamp < TIMESTAMP('2026-10-10 00:00:00+00');

-- ============================================================================
-- INTERPRETATION
-- ============================================================================
-- Observed (2026-10-09 UTC):
--   * USDC address classified is_contract = TRUE.
--   * Top-level transactions initially targeting USDC: 169723.
--   * Recorded contract nonce minimum = 1, maximum = 1, range = 0.
--   * Observed block heights: min = 26151123, max = 26158300.
--   * Observed block span = 7177; not a count of observed blocks.
--
-- Decision: contract account nonce is not a meaningful KPI for daily USDC
-- transaction usage. It tracks contract-creation-related account behavior,
-- not ordinary function calls or ERC-20 token transfers.
--
-- For USDC transfer activity, investigate token_transfers and token
-- semantics; to distinguish execution success, investigate receipts;
-- to examine internal contract-mediated operations, use traces.
--
-- Account-state coverage is incomplete for internal state mutations;
-- do not equate missing records with zero activity or a zero balance.
-- ============================================================================
