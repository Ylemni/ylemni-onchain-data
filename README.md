# Ethereum On-chain Data Analysis

Ethereum Mainnet 온체인 데이터를 **SQL과 BigQuery**로 탐색하고, 분석 결과의 정의·검증·해석 한계를 기록하는 프로젝트입니다. 주요 주제는 Block, Transaction, Address, Account State이며, 학습한 데이터 모델을 실제 공개 데이터 분석에 적용합니다.

## 프로젝트 목표

- Ethereum의 Block·Transaction·Account 데이터 구조를 이해하고 분석 질문에 맞는 지표 정의
- BigQuery/GoogleSQL로 결과를 재현하고 데이터의 Grain·시간 범위·Coverage 확인
- 포함된 Transaction과 실행 성공, Account State, Token 활동을 구분하여 과도한 결론 방지
- SQL 코드와 한국어 분석 노트를 함께 제공하여 분석 과정과 결과를 투명하게 기록

## 저장소 구조

```text
.
├── README.md
├── sql/
│   └── l0/
│       ├── l0_m0_l1_first_contact.sql
│       ├── l0_m1_l1_ethereum_daily_transactions.sql
│       ├── l0_m1_l2_null_case_transaction_destinations.sql
│       ├── l0_m2_l1_blocks_transactions_foundations.sql
│       └── l0_m2_l2_address_eoa_contract_account_state.sql
└── notes/
    └── l0/
        ├── l0_m0_l1_bigquery_first_contact.md
        ├── l0_m1_l1_ethereum_daily_transactions.md
        ├── l0_m1_l2_null_case_transaction_destinations.md
        ├── l0_m2_l1_blocks_transactions_foundations.md
        └── l0_m2_l2_address_eoa_contract_account_state.md
```

## 분석 목록

| 주제 | 핵심 질문 | 분석 노트 | SQL |
|---|---|---|---|
| BigQuery First Contact | 공개 Ethereum 데이터를 어떻게 안전하게 조회하는가? | [노트](notes/l0/l0_m0_l1_bigquery_first_contact.md) | [SQL](sql/l0/l0_m0_l1_first_contact.sql) |
| Ethereum Daily Transactions | 완료된 UTC 날짜별 Transaction 수는 어떻게 달라지는가? | [노트](notes/l0/l0_m1_l1_ethereum_daily_transactions.md) | [SQL](sql/l0/l0_m1_l1_ethereum_daily_transactions.sql) |
| NULL, CASE & Destinations | Transaction 목적지와 Contract Creation을 어떻게 분류하는가? | [노트](notes/l0/l0_m1_l2_null_case_transaction_destinations.md) | [SQL](sql/l0/l0_m1_l2_null_case_transaction_destinations.sql) |
| Blocks & Transactions | Block과 Top-level Transaction의 관계를 어떻게 확인하고 검증하는가? | [노트](notes/l0/l0_m2_l1_blocks_transactions_foundations.md) | [SQL](sql/l0/l0_m2_l1_blocks_transactions_foundations.sql) |
| Address & Account State | USDC Contract의 목적지 Transaction과 Account Nonce는 무엇을 측정하는가? | [노트](notes/l0/l0_m2_l2_address_eoa_contract_account_state.md) | [SQL](sql/l0/l0_m2_l2_address_eoa_contract_account_state.sql) |

## 주요 분석 사례 — Ethereum Mainnet USDC

**조회 기간:** 2026-10-09 UTC (하루), `2026-10-09 00:00:00` 이상 `2026-10-10 00:00:00` 미만.

**대상 Contract Address:** `0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48`

- Contract를 최초 목적지로 지정한 Top-level Transaction: **169,723건**
- 같은 기간에 관찰된 Account Nonce: **최소 1 / 최대 1**
- 관찰된 Account State Block Number 범위: **26,151,123~26,158,300**

이 수치는 공개 Blockchain Analytics에서 관찰된 데이터 기준입니다. **Top-level 목적지 Transaction 수는 성공한 USDC Token Transfer 수와 동일하지 않으며, Contract Nonce는 일반 함수 호출 횟수나 일별 사용자 활동량을 의미하지 않습니다.** 자세한 방법과 한계는 [관련 분석 노트](notes/l0/l0_m2_l2_address_eoa_contract_account_state.md)를 참고하세요.

## 재현 환경 및 유의사항

- **SQL:** GoogleSQL (Google BigQuery)
- **체인:** Ethereum Mainnet
- **데이터 출처:** [Google Cloud Blockchain Analytics](https://docs.cloud.google.com/blockchain-analytics/docs/schema)
- **사용한 데이터셋 예시:** `bigquery-public-data.goog_blockchain_ethereum_mainnet_us`
- **실행 팁:** Query별 주석과 필터 범위를 먼저 확인하고, BigQuery 예상 처리 바이트와 사용량 한도를 점검하세요. `LIMIT`은 반환 행을 제한하지만 읽기 비용을 자동으로 보장하지 않습니다.
- **해석의 한계:** 데이터 제공자의 갱신 시점, Account State Coverage, Query Grain에 따라 숫자의 의미가 달라질 수 있습니다. 기록한 결과는 해당 분석 시점에서 관찰된 값이며 재실행 시 변경될 수 있습니다.

## 참고 문서

- [Ethereum 개발자 문서](https://ethereum.org/en/developers/docs/)
- [Google Cloud Blockchain Analytics 스키마](https://docs.cloud.google.com/blockchain-analytics/docs/schema)
- [Google Cloud Blockchain Analytics 알려진 제한 사항](https://docs.cloud.google.com/blockchain-analytics/docs/known-issues)

---

분석 노트는 한국어로 작성하며, SQL 및 데이터 필드명은 영어 표기를 사용합니다.
