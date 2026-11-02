# L0-M1-L2 — NULL, CASE & Ethereum Transaction Destinations

## Analysis Question

최근 완료된 7 UTC 날짜 동안 Ethereum transaction의 destination을 어떻게 분류할 수 있으며, contract-creation transaction은 날짜별로 어떻게 변했는가?

## 1. NULL Mental Model

`NULL`은 별도의 datatype이 아니라 해당 field/expression에 값이 없음을 나타내는 특별한 상태다.

- `0`은 숫자 값 0이다.
- `""`은 길이가 0인 STRING 값이다.
- `NULL`은 일반적인 값 하나가 아니다.
- NULL 여부는 `= NULL`이 아니라 `IS NULL` / `IS NOT NULL`로 검사한다.

이번 Ethereum `transactions` table에서 확인한 schema:

- `from_address`: `STRING / REQUIRED`
- `to_address`: `STRING / NULLABLE`

## 2. COUNT(*) vs COUNT(column)

`transactions` table의 source grain은 `1 row ≈ 1 transaction`으로 해석한다.

- `COUNT(*)`: WHERE 조건을 통과한 모든 transaction row를 센다.
- `COUNT(to_address)`: 그중 `to_address`가 NULL이 아닌 row만 센다.

따라서 같은 filter 범위에서는:

`COUNT(*) - COUNT(to_address) = to_address IS NULL인 row 수`

가 되어야 한다.

중요한 점은 `COUNT(to_address)`를 사용한다고 source grain이 바뀌는 것이 아니라는 것이다. 같은 transaction-level source에서 non-NULL subset을 세는 metric이 달라질 뿐이다.

## 3. WHERE vs CASE

- `WHERE`: 조건에 맞지 않는 row를 결과에서 제외한다.
- `CASE`: row를 유지한 채 조건에 따라 새로운 category 값을 만든다.

이번 Lesson에서는:

- `to_address IS NULL` → `contract_creation`
- 그 외 → `existing_destination`

으로 분류했다.

`CASE`만 사용하면 transaction-level output grain은 그대로 유지된다.

## 4. Source Grain vs Output Grain

- Source grain: 원본 table에서 1 row가 무엇을 의미하는가.
- Output grain: 현재 Query 결과에서 1 row가 무엇을 의미하는가.

원본 `transactions` table:
`1 row ≈ 1 transaction`

`CASE`만 추가:
`1 row ≈ 1 transaction`

`GROUP BY destination_type`:
`1 row ≈ 1 destination_type`

`GROUP BY day, destination_type`:
`1 row ≈ 1 day × 1 destination_type`

즉 `GROUP BY`가 여러 source rows를 묶으면서 output grain을 바꿀 수 있지만, 원본 table의 source grain 자체가 변하는 것은 아니다.

## 5. Ethereum Meaning of to_address

이번 Lesson에서는 top-level Ethereum transaction에서:

- `to_address IS NULL` → contract-creation transaction
- `to_address IS NOT NULL` → 기존 destination address가 있는 transaction

으로 해석했다.

하지만 `to_address IS NOT NULL`이라는 사실만으로 destination이 EOA인지 smart contract인지 구분할 수 없다. 이를 위해서는 destination address의 contract 여부와 같은 추가 정보가 필요하다.

또한 contract-creation transaction이 block에 포함되었다는 사실만으로 실제 contract deployment가 성공했다고 단정할 수 없다. 성공 여부는 이후 receipt/status와 같은 결과 데이터를 이용해 확인해야 한다.

## 6. Main Analysis

실행 시점의 최근 완료된 7 UTC 날짜를 `day × destination_type` grain으로 집계했다.

관찰된 기간:

- 2026-09-30 ~ 2026-10-06

`contract_creation` 기준:

- Max: 2026-09-30 — 1,974
- Min: 2026-10-02 — 1,300
- 7-day total observed in the validation run: 11,868

이 값들은 `CURRENT_DATE()`에 의존하므로 실행 날짜가 바뀌면 분석 window와 결과도 달라질 수 있다.

## 7. Validation

### Validation A — Category Reconciliation

같은 기간에서 `contract_creation + existing_destination`의 합과 전체 `COUNT(*)`를 비교했다.

관찰 결과:

- category 합: 12,747,983
- 전체 `COUNT(*)`: 12,747,983
- 일치: Yes

이 비교는 CASE로 만든 두 category가 같은 기간의 전체 transaction rows를 논리적으로 빠짐없이 분할하는지 확인하는 데 도움이 된다.

### Validation B — Same Metric, Different Path

`contract_creation`을 두 경로로 계산했다.

1. `CASE`로 category를 만든 뒤 `GROUP BY` + `COUNT(*)`
2. `WHERE to_address IS NULL`로 직접 filter한 뒤 `COUNT(*)`

관찰 결과:

- CASE/grouped count: 11,868
- direct NULL count: 11,868
- 일치: Yes

같은 metric을 서로 다른 계산 경로로 만들어 같은 결과가 나오는지 확인했다. 다만 일치는 신뢰를 높이는 증거이지 분석이 100% 옳다는 증명은 아니다.

## 8. Interpretation Boundary

현재 metric으로 말할 수 있는 것:

- 정의한 최근 완료 7일 window에서 `to_address IS NULL`인 contract-creation transaction rows의 수와 날짜별 변화를 관찰할 수 있다.

현재 metric만으로 말할 수 없는 것:

- 모든 contract-creation transaction이 성공적으로 contract를 배포했는지.
- transaction 수의 변화가 개발자 수의 증가/감소를 의미하는지.
- 특정 이벤트가 변화의 원인인지.

한 개발자나 자동화된 주체가 여러 contract-creation transactions를 만들 수 있기 때문에 `contract_creation count ≠ developer count`다.

## 9. 이번 Lesson에서 내가 실제로 할 수 있게 된 것

NULL이 포함된 raw transaction data에서 값의 존재 여부를 안전하게 구분하고, 같은 table에서도 어떤 expression을 COUNT하느냐에 따라 metric의 의미가 달라진다는 것을 설명할 수 있게 되었다. `CASE`로 transaction rows를 분석용 category로 분류하고, `GROUP BY`를 이용해 원하는 output grain의 metric을 만들 수 있다. 또한 같은 metric을 서로 다른 계산 경로로 검증하고, contract-creation transaction 수를 실제 성공한 contract 수나 개발자 수로 과도하게 해석하지 않는 경계를 세울 수 있게 되었다.
