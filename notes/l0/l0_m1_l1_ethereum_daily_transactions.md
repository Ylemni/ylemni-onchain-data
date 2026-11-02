# L0-M1-L1 — Ethereum Daily Transactions

## Analysis Question

최근 완료된 7일 동안 Ethereum의 일별 transaction 수는 어떻게 달랐는가?

## Data

Table:

`bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.transactions`

내가 이해한 table grain:

`transactions` table의 한 row는 하나의 Ethereum transaction을 나타낸다고 이해했다.

한 row에 `transaction_hash`, `transaction_index`, `from_address`, `to_address`, `block_timestamp` 등 특정 transaction 하나에 대한 속성들이 함께 저장되어 있기 때문이다.

따라서 현재 분석에서는 다음과 같은 grain을 전제로 한다.

`1 row ≈ 1 transaction`

## Metric Definition

### Daily transaction count

내가 정의한 metric:

Daily transaction count는 완료된 각 UTC 날짜별로 `transactions` table의 row 수를 센 값이다.

현재 `1 row ≈ 1 transaction`이라는 table grain을 전제로 하기 때문에, 날짜별 `COUNT(*)`를 해당 날짜의 transaction count로 해석한다.

사용한 기준:

- `DATE(block_timestamp)`로 UTC 날짜 생성
- 오늘은 제외
- 최근 완료된 7일 사용
- 날짜별 `COUNT(*)`

## SQL Concepts

### SELECT

결과에서 보고 싶은 column 또는 계산 결과를 선택한다.

예를 들어:

- `DATE(block_timestamp)`
- `COUNT(*)`

등을 결과에 포함시킬 수 있다.

### FROM

Query가 데이터를 읽어올 source table을 지정한다.

### WHERE

분석 대상이 될 row를 조건에 따라 필터링한다.

이번 분석에서는 `block_timestamp`를 기준으로 최근 완료된 7일에 해당하는 transaction row만 선택했다.

### GROUP BY

같은 기준값을 가진 row들을 하나의 그룹으로 묶어 각 그룹별 aggregate 계산을 가능하게 한다.

이번에는 같은 `day`를 가진 transaction row들을 묶어 날짜별 transaction count를 계산했다.

### COUNT(\*)

현재 계산 대상이 된 row의 총 개수를 센다.

이번 분석에서는 `transactions` table의 grain을 `1 row ≈ 1 transaction`으로 해석하므로, 각 날짜 그룹의 `COUNT(*)`를 일별 transaction count로 사용했다.

### ORDER BY

Query 결과 row를 특정 column 또는 계산값을 기준으로 정렬한다.

- `ASC`: 오름차순
- `DESC`: 내림차순

이번 분석에서는 날짜순 정렬과 transaction count가 많은 순서의 정렬에 사용했다.

## Time Range

이번 분석에서는 다음 형태의 기간을 사용했다.

`(7 days ago, today)`

즉:

- 시작 날짜는 포함
- 오늘 날짜는 제외

하는 방식이다.

내가 오늘을 제외한 이유:

오늘은 아직 끝나지 않은 partial day이기 때문이다.

예를 들어 현재 시간이 오후라면 오늘의 transaction count는 하루 24시간 전체가 아니라 현재 시각까지의 transaction만 포함한다.

이를 완료된 이전 날짜들과 그대로 비교하면, 실제 network activity가 감소하지 않았는데도 오늘의 transaction count가 낮게 보이는 잘못된 해석이 발생할 수 있다.

## Validation

### 1. Expected number of days

Expected:

7 days

Actual:

7 days

분석 기간을 최근 완료된 7일로 정의했으므로 결과에서도 7개의 서로 다른 날짜가 나오는지 확인했다.

### 2. Daily sum vs total count

검증 방법:

같은 기간의 transaction 수를 서로 다른 두 계산 방식으로 구해 비교했다.

방법 A:

날짜별로 `GROUP BY`한 뒤 각각의 `transaction_count`를 계산하고, 7개 날짜의 transaction count를 모두 합산한다.

방법 B:

동일한 기간 조건을 사용하되 날짜별 `GROUP BY`를 하지 않고 전체 row를 한 번에 `COUNT(*)`한다.

두 계산 결과가 같다면, 날짜별 집계 과정이나 기간 조건에 문제가 없는지 확인하는 하나의 validation 근거로 사용할 수 있다.

관찰:

Query를 실행한 당시, 일별 `transaction_count`의 합과 같은 기간 전체 `COUNT(*)`가 일치했다.

주의:

두 Query가 동일한 잘못된 조건이나 가정을 공유한다면 두 결과가 같아도 둘 다 틀릴 수 있다.

따라서 이 검증만으로 분석의 정확성을 완전히 증명하는 것은 아니다.

### 3. Row count vs unique transaction hash

검증 방법:

`COUNT(*)`로 전체 transaction row 수를 계산하고, `COUNT(DISTINCT transaction_hash)`로 서로 다른 `transaction_hash` 값의 개수를 계산했다.

두 값을 비교하여 현재 분석 기간에서 동일한 `transaction_hash`를 가진 중복 row가 관찰되는지 확인했다.

관찰한 실행 결과:

- total_rows: 12,953,582
- unique_transactions: 12,953,582

해석:

검사한 해당 7일 범위에서는 전체 row 수와 고유 `transaction_hash` 수가 같았다.

따라서 이 기간의 dataset에서는 중복된 `transaction_hash` row를 관찰하지 않았으며, `1 row ≈ 1 unique transaction` 이라는 table grain 가설과 데이터가 일치했다.

하지만 이 결과만으로 Ethereum 전체 기간 또는 모든 dataset에서 transaction 중복이 절대 존재하지 않는다고 단정할 수는 없다.

## Solo Challenge

실행 시점 기준 최근 완료된 7일을 `transaction_count`가 높은 순으로 정렬했다.

### Highest

- day: 2026-09-11
- transaction_count: 2,097,342

### Lowest

- day: 2026-09-13
- transaction_count: 1,476,230

### Difference

621,112

## Interpretation

이번 결과를 보고 말할 수 있는 것:

관찰한 최근 완료된 7일 동안 Ethereum의 일별 transaction count는 날짜마다 달랐다.

해당 실행 결과에서는 2026-09-11의 transaction count가 가장 높았고, 2026-09-13의 transaction count가 가장 낮았다.
두 날짜의 transaction count 차이는 621,112였다.

이번 결과만 보고 말하면 안 되는 것:

transaction count가 가장 높은 날짜가 Ethereum 사용자가 가장 많았던 날짜라고 단정할 수 없다.

이번 metric은 transaction의 수를 측정한 것이지 사용자 수를 직접 측정한 것이 아니기 때문이다.

## Important Limitation

`transaction_count != user_count`

이유:

한 명의 사용자가 여러 account/address를 소유할 수 있고, 하나의 account/address에서도 여러 transaction을 발생시킬 수 있다.

따라서 다음은 서로 다른 분석 단위이다.

`transaction != address/account != user/entity`

transaction count의 증가는 network activity의 한 측면을 보여주지만, 그 자체로 사용자 수 증가를 의미하지는 않는다.

## Reproducibility Note

이 SQL은 `CURRENT_DATE()`를 사용하므로 다른 날짜에 다시 실행하면 분석 대상 최근 7일도 이동한다.

따라서 위에 기록한 숫자들은 특정 실행 시점의 관찰값이다.

같은 SQL을 미래에 다시 실행하면 SQL의 분석 논리는 동일하더라도 결과 숫자는 달라질 수 있다.

## New Question

이번 Lesson을 하면서 생긴 다음 질문:

집계된 `transaction_count`의 MAX / MIN을
SQL 안에서 다시 계산하려면 어떻게 해야 하는가?

현재 이해:

처음에는 `MAX(*)` 또는 `MAX(COUNT(*))` 같은 형태를 생각했지만 이 방식으로는 원하는 계산을 할 수 없었다.

`COUNT(*) AS transaction_count`는 날짜별 `GROUP BY`를 수행한 뒤 만들어지는 집계 결과이므로, 그 집계 결과에 다시 `MAX()` 또는 `MIN()`을 적용하려면
계산 결과를 하나의 새로운 query layer로 만든 뒤 바깥쪽에서 다시 집계해야 한다.

따라서 이후 배우게 될 Subquery 또는 CTE와 연결되는 문제라고 이해하고 있다.

## One Sentence

Ethereum `transactions` table의 grain과 분석 기간을 먼저 정의하고, `DATE`, `GROUP BY`, `COUNT`를 이용해 일별 transaction metric을 만든 뒤,
서로 다른 계산 방식과 `transaction_hash` uniqueness를 이용해 결과를 검증하고 그 metric으로 말할 수 있는 범위와 말할 수 없는 범위를 구분하는 방법을 배웠다.
