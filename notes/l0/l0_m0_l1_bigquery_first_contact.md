# L0-M0-L1 — BigQuery First Contact

## 오늘의 질문

Q: BigQuery에서 Ethereum 데이터를 조회한다는 것은 무엇인가?
A: Google Blockchain Analytics가 수집 및 색인하여 BigQuery에서 제공하는 Ethereum 데이터에 Query를 실행하고, 필요한 분석 결과를 받는 과정이다.

## 배운 것

### Google Cloud Project

- Google Cloud에서 작업을 묶는 관리 단위.
- 권한, API, 비용 같은 것들이 Project를 중심으로 관리된다.

### Dataset

- 여러 Table을 모아 놓는 논리적인 공간.
- 관련 목적에 따라 하나의 dataset 아래 묶일 수 있으며, Dataset 자체가 '한 장의 표'는 아니다.

### Table

- row와 column 형태의 실제 분석 데이터가 있는 곳.
- Table에서 구조를 파악하고 필요한 정보를 찾아야 하는 능력이 중요.

### Query Job

- SQL을 실행하면 BigQuery가 수행하는 하나의 계산 작업.
- Query문을 실행하면 화면에 결과가 마법처럼 나타나는 것이 아니라 BigQuery 관점에서는 하나의 Job이 실행된다.

```
SQL
 ↓
Query Job
 ↓
데이터 읽기 + 계산
 ↓
Result
```

- 나중에 처리한 bytes, 실행 정보 등을 확인하는 이유도 바로 이 Query Job이 실제 계산 작업이기 때문.

### Table Grain

- 데이터에서 한 행(row)이 어떤 단위를 대표하는가라는 뜻.

```
transactions table
1 row = 1 transaction

blocks table
1 row = 1 block

daily_token_metrics table
1 row = 1 token × 1 day
-- 한 entity만이 아니라 복합 단위일 수도 있다.
```

> 이 테이블에서 한 줄은 현실 세계의 무엇 하나를 나타내는가?

## BigQuery Table 이름

project.dataset.table

현재 확인한 Ethereum blocks table:
bigquery-public-data.blockchain_analytics_ethereum_mainnet_us.blocks

## 내 Project를 만들어야 하는 이유

- Public Dataset을 조회할 때도 내 Query Job이 실행될 Project가 필요하다.

```
[내 Project]
heowl-onchain-lab

       │
       │ Query Job 실행
       ▼

[Google의 Project]
bigquery-public-data
       │
       ▼
Ethereum Dataset
       │
       ▼
blocks table
```

## 첫 Ethereum Query 결과

first_block: 0
newest_block: 25937359
total_blocks: 25937360

## Query / 비용 실험

SELECT \* + LIMIT 10 예상 처리량:
43.3 GB

block_number + LIMIT 10 실제 processed:
75.67 MB

최근 7일 block_timestamp filter 실제 processed:
831.59 KB

최근 7일 query의 bytes billed:
10 MB

## Partition / Clustering

Partition field:
block_timestamp

Partition granularity:
MONTH

Clustered by:
block_timestamp

내가 이해한 partition pruning:
[자기 말로 작성]

## Ethereum Schema에서 직접 본 column

### parent_hash

- 이전 블록인 부모 블록의 해시값.

```
Block N-1
block_hash = ABC123
       │
       │ 다음 block이 부모를 가리킴
       ▼
Block N
parent_hash = ABC123
```

- 그 관계를 이용해 block 간 연결성을 검증하는 분석을 할 수도 있다.

### size

- 해당 블록의 byte 크기
- block들의 크기를 시간에 따라 비교할 수 있다.
- size ≠ gas_used

### state_root

- Block N의 state_root는 Block N 실행 후의 상태를 나타낸다.
- Block N이 과거 block이라면 그 값도 과거 시점의 state root이다.
    > - 그 block의 변경사항을 적용한 뒤의 global state에 대한 root hash
    > - 이 block 안의 transaction들을 모두 적용한 뒤의 상태

## 아직 모르는 것

- trie
- root

## 오늘의 한 문장

BigQuery는 대규모 데이터를 내 PC가 아니라 Google Cloud 쪽에서 저장 및 처리하고, 사용자가 SQL Query를 통해 필요한 결과를 얻을 수 있게 하는 분석용 데이터웨어하우스다.
