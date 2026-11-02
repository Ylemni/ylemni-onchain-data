# L0-M2-L1 — Ethereum Blocks & Transactions Foundations

## 0. Analysis Question & Learning Objectives

**이 Lesson의 근본 질문:** 여러 Node가 참여하는 Ethereum은 왜 Transaction을 Block 단위로 묶어 순서를 정하고 Block을 서로 연결하는가? 분석가는 실제 `blocks` 및 `transactions` 데이터를 어떻게 읽고, 집계 결과를 어디까지 신뢰·해석할 수 있는가?

**실습 질문:** 2026-10-03~2026-10-09 UTC 동안 Ethereum Mainnet의 일별 Block 수와 포함된 top-level Transaction 수는 어떻게 달라졌으며, 그 집계의 중복·NULL·수록 범위는 어떤 근거로 확인할 수 있는가?

학습의 목표는 Block을 많이 세는 것이 아니다. **온체인 기록의 생성 과정과 데이터셋의 행(row)을 연결하여, 내가 만든 수치가 무엇을 뜻하는지 설명하는 것**이다.

---

## 1. S1 — Why Blocks? 공유 기록, 순서, 연결

### 1.1 왜 여러 Node에 공통된 거래 순서가 필요한가?

Ethereum에는 하나의 중앙 데이터베이스만 있는 것이 아니라, 네트워크 곳곳에서 각자 정보를 주고받고 규칙을 확인하는 Node가 존재한다. 서로 다른 Node는 같은 Transaction을 다른 시점·순서로 받을 수 있다. 그러나 Account 상태를 계산하려면 **서로 합의된 실행 순서**를 따라야 한다. Block은 Transaction들을 **정해진 순서로 담아 공유하는 기록 단위**다.

**가상 예시(수수료 제외):** Alice 5 ETH, Bob 0 ETH, Carol 0 ETH에서 시작한다.

| 순서 | 요청                | 처리 후 Alice | Bob | Carol |
| ---- | ------------------- | ------------: | --: | ----: |
| 초기 | —                   |             5 |   0 |     0 |
| T1   | Alice → Bob 2 ETH   |             3 |   2 |     0 |
| T2   | Bob → Carol 1 ETH   |             3 |   1 |     1 |
| T3   | Alice → Carol 1 ETH |             2 |   1 |     2 |

Bob의 전송을 Alice의 전송보다 먼저 실행한다고 가정하면 당시 Bob의 잔액은 0 ETH이므로 결과가 달라질 수 있다. **Transaction 목록만 존재하는 것과 그 실행 순서가 합의된 것은 다르다.** 이 예시는 순서의 중요성을 설명하기 위한 단순화이며, 실제 Ethereum에는 nonce, gas, 유효성 규칙이 추가로 적용된다.

### 1.2 Block과 Transaction의 포함 관계

- **Transaction:** 네트워크에 제출하는 서명된 작업 요청. Block에 포함되면 실행되지만 실행 성공은 별도 문제.
- **Block:** 여러 Transaction을 _순서 있게_ 포함할 수 있는 기록 단위. **0개 이상의 Transaction**이 들어갈 수 있다.
- **Blockchain:** 각 Block이 이전 Block의 Hash를 참조하며 연결된 기록 구조.

```
[Block #300] ──(자식이 부모 Hash를 참조)──> [Block #301]
  T1, T2, T3                                   T4, T5
```

위 가상 데이터의 Source Grain을 생각해 보면 `blocks`에는 Block row 2개, `transactions`에는 Transaction row 5개다. **Block : Transaction = 1 : 0..N**인 포함 관계이며, Transaction 수와 Block 수는 애초에 서로 다른 지표다.

### 1.3 Hash·Parent Hash가 연결되는 방식

```
Block #300: block_hash = H300
Block #301: block_hash = H301, parent_hash = H300
Block #302: block_hash = H302, parent_hash = H301
```

- `block_number`: 실행 Block의 **높이(height)**. 영구적으로 전 세계에서 유일한 Block ID와 같은 뜻은 아니다. 분기 시 동일 높이에 다른 Block이 나타날 수 있다.
- `block_hash`: 해당 Block **자체**의 암호학적 식별자. 암호화된 원문이나 복호화 가능한 문자열이 아니다.
- `parent_hash`: **현재 Block에 기록된 부모 Block의 `block_hash`**. 단순히 번호가 하나 작아서 연결된 것이 아니라 Hash 참조로 관계를 확인한다.

`parent_hash`가 있다는 사실만으로 부모 Block이 이미 **Finalized**되었다고 결론 내릴 수 없다. 연결과 최종성은 별개의 개념이다.

---

## 2. S2 — Transaction: 작성, 서명, 전파, 포함, 실행

### 2.1 Transaction이 On-chain에 들어가기 전

```
작업 지시 작성 → 암호학적 서명 → Node에 제출·네트워크 전파
                              ↓
                     Block 후보로 선택될 수 있음
                              ↓
                     유효한 Block에 포함·실행
                              ↓
                     합의를 거쳐 나중에 Finality 확보
```

이 순서도는 개념적 흐름이다. Node의 검증은 수신 과정과 Block 검증 과정 등 여러 지점에서 일어나며, 모든 Transaction이 반드시 포함되는 것은 아니다.

- **Network에 전파됨:** Node들이 Transaction을 수신하고 메모리 풀(mempool)에 대기시킬 수 있음. **아직 On-chain이라고 할 수 없다.** 중앙에서 모든 Node가 공유하는 단일 mempool이 있는 것은 아니다.
- **On-chain에 포함됨:** 현재 유효하게 관찰되는 체인의 Block에 Transaction이 기록·실행됨. **실행 성공과는 다르다.**
- **Finalized됨:** 해당 Block이 합의 규칙상 훨씬 강한 확정성을 얻음. 최신 Head의 일부라는 뜻과 다르다.

### 2.2 Address, Wallet, Signature — 이 Lesson에서 필요한 수준

- `address`: Ethereum Account를 가리키는 식별 주소. 주소를 안다고 곧바로 사람 한 명의 정체를 아는 것은 아니다.
- `private key`: 서명을 만드는 데 필요한 비밀 정보. 직접 노출하지 않는다.
- `wallet`: 작성과 서명 요청·전파를 돕는 도구. 개인키가 항상 Wallet 앱 안에 직접 저장되는 것은 아니다.
- `from_address`: top-level Transaction의 발신자 주소.
- `to_address`: 목적지 주소. Contract 생성 Transaction에서는 일반적으로 `NULL`.
- `value`: Native ETH 전송 지정값. `value = 0`이어도 Contract 기능을 실행할 수 있다.
- `input`/`data`: Contract 호출 인자 또는 Contract 생성용 바이트코드 등 입력 데이터.
- `transaction_hash`: 개별 서명된 Transaction을 식별하는 Hash.
- `nonce`, Gas 관련 값: 순서/재전송 제어 및 자원·수수료 조건과 관련. 상세 계산은 이 Lesson의 범위 밖.

**가상 예시:**

| Tx  | `to_address` | `value` | 입력 데이터      | 해석                                        |
| --- | ------------ | ------: | ---------------- | ------------------------------------------- |
| T1  | Bob 주소     |   1 ETH | 없음             | ETH 전송 요청(목적지가 EOA라고 단정 불가)   |
| T2  | Contract C   |   0 ETH | 기능 호출 데이터 | ETH value 없이도 Contract 호출 가능         |
| T3  | `NULL`       |   0 ETH | 생성용 데이터    | Contract 생성 _시도_, 성공 여부는 별도 확인 |

`to_address IS NOT NULL`은 기존 목적지가 있다는 뜻이지 **EOA인지 Contract인지 확정하는 판별식이 아니다.** `to_address IS NULL`인 생성 시도가 Block에 포함되었다고 Contract 생성이 반드시 성공한 것도 아니다. 실행 결과 판단에는 Receipt/Status 등 별도의 정보가 필요하다.

### 2.3 Transaction Hash와 Block Hash

Block 하나에 서로 다른 Transaction 3개가 포함되어 있다면 이들은 동일한 `block_number`와 Block 식별자를 공유할 수 있지만, `transaction_hash`는 각 Transaction을 구별한다.

**Source Grain = Transaction일 때** `COUNT(*)`는 row 수, `COUNT(DISTINCT transaction_hash)`는 서로 다른 Transaction Hash 수, `COUNT(DISTINCT block_number)`는 해당 결과에서 Transaction이 관찰된 Block 높이 수를 센다. 이는 전체 Block 수와 항상 같지 않다.

---

## 3. S3 — Block Anatomy: 필드와 그 의미

Ethereum의 현재 구조에서 합의 계층의 Beacon Block은 실행 관련 데이터를 포함한다. 분석가가 BigQuery `blocks`에서 주로 관찰하는 것은 **실행 Block에 관한 구조화된 정보**다. **프로토콜의 내부 구조와 제공자가 만든 분석 테이블은 동일한 물건이 아니다.**

| 개념/필드                     | 의미                                               | 주의할 점                                      |
| ----------------------------- | -------------------------------------------------- | ---------------------------------------------- |
| `block_number`                | 실행 Block 높이                                    | Slot 번호와 다름; 동일 높이의 일시적 분기 가능 |
| `block_hash`                  | 해당 Block의 Hash                                  | Parent Hash와 다른 역할                        |
| `parent_hash`                 | 부모 Block의 Hash                                  | 이전 Block 참조 ≠ 최종성 확보                  |
| `timestamp`/`block_timestamp` | Block에 부여된 시간                                | Tx 작성·서명·최초 전파 시각이 아님             |
| Transaction 목록              | Block에 포함된 실행 요청들의 순서 있는 목록        | 포함 ≠ 실행 성공; 0개 가능                     |
| `gas_limit`                   | Block에 허용된 Gas 총량 한도                       | ETH 금액이 아님                                |
| `gas_used`                    | Block의 실제 Gas 소비량                            | Transaction 개수나 수수료 금액이 아님          |
| `transactions_root`           | Transaction 목록 검증에 쓰는 root                  | Transaction 원문 목록을 그대로 읽는 값이 아님  |
| `receipts_root`               | Receipt 구조 검증에 쓰는 root                      | Receipt/Status 세부 해석은 후속 Lesson         |
| `state_root`                  | Block 실행 이후 Ethereum 전체 상태의 암호학적 root | Account balance 목록 자체가 아님               |

### 3.1 Timestamp의 해석 경계

**가상 예시:** Block #1200에 T1, T2가 들어 있고 Block Timestamp가 12:00:00 UTC라면 두 Transaction 모두 해당 Block의 시각에 귀속될 수 있다. 그렇지만 **T1과 T2가 모두 정확히 12:00:00에 서명되었다는 의미는 아니다.**

BigQuery `transactions.block_timestamp` 역시 **그 Transaction이 포함된 Block의 시각**이다. Transaction이 작성되거나 네트워크에 최초 전파된 시간을 확인하려면 별도의 관측 자료가 필요하다.

### 3.2 Gas의 예시

**가상 Block:** T1이 21,000 Gas, T2가 63,000 Gas를 사용했다면 Block의 `gas_used`는 84,000 Gas다. Transaction은 2건이지 84,000건이 아니다. Gas를 ETH 수수료로 해석하려면 가스 가격 등 추가 값과 규칙이 필요하다.

### 3.3 State Root는 왜 중요한가?

Node들이 같은 Transaction을 같은 합의된 순서와 Ethereum 규칙에 따라 실행한다면 일관된 상태 결과를 얻어야 한다. `state_root`는 그 실행 결과 상태를 암호학적으로 검증하는 데 사용된다. **Root 값만 복호화해 모든 계정의 잔액을 표 형태로 꺼낼 수 있는 것은 아니다.** Trie의 구현·암호학적 증명 구성은 이 Lesson에서 학습하지 않는다.

---

## 4. S4 — 누가 12초마다 Block을 만들고, 왜 Reorg가 가능한가?

### 4.1 Node와 Validator

**Node**는 Ethereum의 클라이언트 소프트웨어를 실행하여 네트워크와 데이터를 주고받고 규칙을 검증하는 시스템이다. 그 운영자는 사람이나 조직일 수 있다. **Validator**는 ETH 지분을 예치하고 PoS 합의에서 제안·투표 임무를 수행하는 역할이다. Node라고 모두 Validator인 것은 아니다. 사람은 시스템을 설정·운영하고, 12초 단위 작업은 소프트웨어가 자동 수행한다.

일반적인 실행 클라이언트는 Transaction 실행과 상태 검증을, 합의 클라이언트는 Chain Head 및 합의 규칙 처리를, Validator 클라이언트는 제안·투표 등의 임무를 담당한다. 이를 서로 다른 세 Blockchain으로 이해하면 안 된다.

### 4.2 Proof of Stake, Slot, Epoch

- **PoS:** 합의 참여자의 지분과 프로토콜 규칙을 활용해 체인을 운영하는 체계. Validator가 제안했다고 해서 잘못된 Block이 자동으로 승인되지는 않는다.
- **Slot:** 12초 길이의 **Block 제안 기회**. 매 Slot에 반드시 Block이 들어서지는 않는다.
- **Epoch:** 32 Slot = 384초(6분 24초). Epoch에 반드시 Block이 32개 생성된다는 뜻은 아니다.
- **Proposer:** 특정 Slot에 새 Block을 제안하도록 선정되는 Validator. 한 Slot의 지정 제안자는 한 명이지만, 네트워크 지연·충돌하는 제안 등의 이유로 서로 다른 체인 분기가 관찰될 수 있다.
- **Attestation:** Validator의 합의 관련 투표. **Fork Choice:** 현재 어느 체인을 선택할지 판단하는 규칙. 상세 내부 알고리즘은 이 Lesson의 범위 밖.

**가상 예시:**

| Slot | 결과       | 정규 체인의 실행 Block Number |
| ---: | ---------- | ----------------------------: |
|  100 | Block 생성 |                           500 |
|  101 | 비어 있음  |                             — |
|  102 | Block 생성 |                           501 |

Slot 번호와 Block Number는 다른 축이다. 따라서 빈 Slot이 있다고 해서 실행 Block Number가 500에서 502로 건너뛰어야 하는 것은 아니다. Block #501은 Block #500의 Hash를 부모로 참조할 수 있다.

### 4.3 Block 제안 → 검증 → 체인 선택 → Finality

1. **제안:** 선정된 Validator가 현재 자신이 선택한 부모 Block 위에 Transaction과 실행 정보를 담은 Block을 구성·전파한다.
2. **검증:** 수신 Node가 부모 연결, 서명·프로토콜 규칙, Transaction 재실행 결과, State Root 등의 일관성을 확인한다.
3. **체인 선택:** Validator 투표와 Fork Choice에 따라 현재 따를 체인을 결정한다. 서로 다른 Node의 판단은 일시적으로 다를 수 있다.
4. **최종성 확보:** 이후 합의가 쌓여 매우 강한 확정성을 얻는다. 정상 조건의 Finality는 대략 15분 안팎이지만 매 Block의 절대적 보장 시간은 아니다.

**정확히 구별할 세 가지:**

| 개념                          | 물어보는 내용                               |
| ----------------------------- | ------------------------------------------- |
| Transaction Inclusion         | 현재 체인의 Block에 기록되었는가?           |
| Transaction Execution Success | 요청한 작업이 정상적으로 실행되었는가?      |
| Block Finality                | 해당 Block이 강한 합의 최종성을 확보했는가? |

Contract 호출이 `revert`되어 **Transaction이 실패**해도 그 실패가 프로토콜에 따라 올바르게 처리되었다면 **Block은 유효**할 수 있다. 반면 제안된 `state_root`가 올바른 재실행 결과와 불일치한다면 **Block 검증 실패**다. 이로부터 특정 Transaction이 반드시 잘못 작성되었다고 단정하지는 않는다.

### 4.4 Reorg: 기록만 사라지는 것이 아니라 정규 체인 상태가 달라진다

**Reorganization(Reorg)**은 이전에 정규 체인으로 보였던 Block이 다른 분기의 Block으로 교체되는 현상이다. 동일 `block_number`에 다른 Hash의 Block이 들어설 수 있다.

```
기존 선택:  #700(H700) → #701-X(HX, T 포함) → #702-X
새 선택:    #700(H700) → #701-Y(HY, T 없음) → #702-Y
```

부모 참조로 연결되어 있으므로, 분기점 이후의 자식 Block들도 새 분기의 기록으로 대체될 수 있다. 그러나 모든 Reorg가 깊거나 항상 수십 Block을 바꾸는 것은 아니다.

**가상 잔액 예시(수수료 및 다른 거래 제외):** Alice 3 ETH, Bob 0 ETH에서 Alice→Bob 1 ETH(T)가 기존 Block X에 포함·성공했다면 기존 체인에서 Alice 2, Bob 1이다. 그러나 X가 Reorg로 제외되고 **새 정규 체인에는 T도 다른 잔액 변경도 없다면**, 현재 정규 체인의 잔액은 Alice 3, Bob 0이다.

즉 *“송금은 끝났고 기록만 지워졌다”*가 아니다. **정규 체인에서 인정되는 상태 변화 자체가 달라진다.** T는 나중에 다른 Block에 재포함될 수도 있지만 그 사실은 별도로 확인해야 한다. Reorg와 Transaction의 `status = failed`도 동일하지 않다.

### 4.5 Finality와 데이터 제공자 지연은 다른 문제

Explorer에 최신 Block이 표시되어도 Finalized되었다는 뜻은 아니다. 또한 네트워크에서 Finality를 확보한 Block이 분석 제공자의 BigQuery 테이블에 즉시 등장한다는 보장도 없다. 따라서 **Protocol Finality**, **Provider Freshness**, **Data Coverage**를 따로 확인해야 한다.

### 4.6 실무적 경계: Node 운영과 분석 업무

Node는 ETH 보상이 없더라도 직접 검증·RPC 사용·서비스 독립성 등의 이유로 운영한다. Validator는 지분을 예치하고 합의에 참여하며 보상·운영 비용·페널티 위험이 있다. 온체인 분석가의 기본 역량은 이러한 시스템을 개발하거나 매 Slot을 수작업으로 운영하는 것이 아니라, **데이터의 기록·확정·수록 시점을 정확하게 해석하는 능력**이다.

---

## 5. S5 — Etherscan × BigQuery: 같은 Block 비교

### 5.1 프로토콜, Explorer, 분석 테이블을 구분하기

```
Ethereum Network에서 기록·검증되는 Block/Tx
       ├── Explorer(Etherscan): 사람이 읽기 쉬운 표현
       └── Google Blockchain Analytics: SQL로 분석할 수 있는 테이블
                                         ↓
                                   우리의 Metric/해석
```

Etherscan과 BigQuery는 **Ethereum 자체가 아니라 Ethereum 정보를 제공하는 별도 서비스**다. 제공 시간과 수록 범위, 표기 방식이 다를 수 있다.

**BigQuery 데이터셋:** `bigquery-public-data.blockchain_analytics_ethereum_mainnet_us`

| 테이블         | 기대 Source Grain                              | 검증에 사용할 식별자                                                |
| -------------- | ---------------------------------------------- | ------------------------------------------------------------------- |
| `blocks`       | 1 row ≈ 1 실행 Block                           | `block_number` (해당 필터 기간), 관련 Block Hash는 실제 Schema 확인 |
| `transactions` | 1 row ≈ 1 Block에 포함된 top-level Transaction | `transaction_hash`, `block_number`                                  |

실제 column 명과 타입은 BigQuery Schema 탭에서 확인해야 한다. Protocol 필드와 제공 테이블의 이름이 언제나 동일하다고 추정하지 않는다.

### 5.2 한 Block 실제 Cross-check: 학습자 관찰 결과

- Block Number / Etherscan Height: **26,158,300**
- Block Timestamp: **2026-10-09 23:59:59 UTC**
- BigQuery `transactions`의 해당 Block row 수: **165**
- Etherscan의 일반 Transactions: **165**
- Etherscan이 별도로 표시한 Contract Internal Transactions: **75**

참고 링크: https://etherscan.io/txs?block=26158300 와 https://etherscan.io/txsInternal?block=26158300

**핵심 해석:** 두 출처의 **top-level Transaction 개수 165건**이 일치한다. 하지만 Etherscan의 Internal Transactions 75건을 더해 240건의 _일반_ Transaction이라고 보고하면 grain을 섞은 오류다. 내부 실행 기록과 최상위 Transaction은 다른 범주다.

`block_timestamp`는 Block의 시간이지 165개 Transaction의 서명/전파 시각 각각을 의미하지 않는다. 한 Block의 수치 일치는 다른 Block 및 데이터셋 전체의 완전성을 자동으로 보증하지 않는다.

### 5.3 비용과 재현성

- 날짜 조건은 UTC 반열린 구간을 사용한다: `>= 2026-10-09 00:00:00+00` 및 `< 2026-10-10 00:00:00+00`.
- `LIMIT 5`나 `LIMIT 3`은 결과 row 수 제한이지 스캔 용량을 자동 보장하는 수단은 아니다.
- 테이블 파티션과 예상 처리 바이트를 확인한다. `SELECT *` 대신 필요한 column만 선택한다.
- 과거 7일의 고정 날짜를 기록해 재현성을 높이되, 오래된 날짜라고 데이터 누락 가능성이 0이 되는 것은 아니다.

---

## 6. S6 — Metric Definition, Validation, 근거의 범위

### 6.1 Source Grain과 Output Grain

- **Source Grain:** 원본 테이블에서 1 row가 의미하는 분석 단위. 여기서는 Block/Transaction 단위.
- **Output Grain:** `GROUP BY` 이후 결과에서 1 row가 의미하는 분석 단위. S7에서는 **UTC 날짜 하나**.
- **Metric:** 무엇을 세는지, 어떤 필터·기간·단위·제외 기준을 사용하는지를 명시한 숫자.
- **Validation:** Metric이 정의에 맞게 계산됐는지 확인하는 절차. 두 값이 같다는 사실만으로 모든 종류의 정확성을 증명하지는 않는다.

**가상 예시:**

| row | transaction_hash |
| --: | ---------------- |
|   1 | T001             |
|   2 | T002             |
|   3 | T002             |
|   4 | `NULL`           |

- `COUNT(*) = 4`: 모든 row
- `COUNT(transaction_hash) = 3`: NULL 아닌 Hash row
- `COUNT(DISTINCT transaction_hash) = 2`: 서로 다른 NULL 아닌 Hash

언제나 `COUNT(DISTINCT hash) <= COUNT(hash) <= COUNT(*)`다. 이 세 값이 모두 같다면 해당 필터 범위의 Hash에는 **NULL도 중복도 없다**. 심지어 `COUNT(*) = COUNT(DISTINCT hash)`가 성립하면 위 부등식상 가운데 `COUNT(hash)`도 같으므로 NULL/중복 없음이 따라온다. 단, 원천에 빠진 row가 있는지 여부는 이 식으로 알 수 없다.

### 6.2 실제 단일 Block 검증

Block 26,158,300에 대해 학습자가 관찰한 결과:

| 지표                                                  | 결과 |
| ----------------------------------------------------- | ---: |
| `COUNT(*) AS total_rows`                              |  165 |
| `COUNT(transaction_hash) AS nonnull_hash_rows`        |  165 |
| `COUNT(DISTINCT transaction_hash) AS distinct_hashes` |  165 |

**확인:** 대상 Block의 관찰된 Transaction Hash에 NULL과 중복이 없다. **미확인:** 전체 체인 데이터가 누락 없이 수집되었는가, 모든 필드가 정확한가, 다른 날짜에도 동일한가.

### 6.3 Blocks 테이블과 Transaction-bearing Blocks 비교

**가상 예시:** Blocks 테이블에 Block 100·101·102가 있고, Transactions 테이블에는 Block 100·102에 속한 Transaction만 있다.

`COUNT(*) FROM blocks = 3`이며 `COUNT(DISTINCT block_number) FROM transactions = 2`다. Block 101에는 Transaction이 0개이므로 차이가 난다. 이 차이는 정상적인 데이터 관계에서도 가능하다.

반대로 두 테이블의 서로 다른 Block Number *개수*가 같다고 해서 두 테이블에 존재하는 Block Number의 **집합까지 같다는 뜻은 아니다**. 예를 들어 `{100, 101, 102}`와 `{100, 101, 105}`는 원소 개수가 같지만 구성원이 다르다. 차이의 원인을 정확히 구별하려면 이후 집합/테이블 결합 방식으로 실제 Block Number를 대조해야 한다.

### 6.4 실무의 검증은 위험에 따라 선택한다

현재 `COUNT`, 고유 Hash, 다른 데이터 소스 비교는 **입문용 분석 기초 훈련**에 해당한다. 실무에서 이미 품질이 관리되는 모든 테이블에 같은 검증을 매번 처음부터 반복할 필요는 없다. 새로운 소스 도입, JOIN·집계 변경, 금융 지표, 갑작스러운 이상치 등 **오류 위험과 결과의 중요성**에 맞춰 검증 범위를 정하고 자동화할 것은 자동화한다.

---

## 7. S7 — 독립 분석: 2026-10-03~09 UTC 7일

### 7.1 Query 정의

**질문:** 각 UTC 날짜에 관찰된 Block과 top-level Transaction 수는 얼마인가? 어떤 날짜가 최대·최소인가? 집계한 식별자의 중복/NULL은 관찰되었는가? 두 지표가 표현하는 행동은 무엇인가?

| Query              | Source Grain     | Output Grain | Metric                                                                         |
| ------------------ | ---------------- | ------------ | ------------------------------------------------------------------------------ |
| Daily Blocks       | Block            | UTC day      | `COUNT(*)`, `COUNT(DISTINCT block_number)`                                     |
| Daily Transactions | 포함 Transaction | UTC day      | `COUNT(*)`, `COUNT(DISTINCT transaction_hash)`, `COUNT(DISTINCT block_number)` |

**고정된 기간(반열린 구간):** `2026-10-03 00:00:00+00 <= block_timestamp < 2026-10-10 00:00:00+00`. `DATE(block_timestamp)`로 UTC 날짜별 그룹화했다. JOIN/CTE/Window 없이 `SELECT`, `WHERE`, `GROUP BY`, `ORDER BY`, `COUNT`, `DISTINCT`만 사용했다.

### 7.2 학습자 제출 실측 결과

| UTC Day    | Block rows | Distinct block numbers | Transaction rows | Distinct transaction hashes | Blocks with transactions |      Tx / Block (일별 단순 평균) |
| ---------- | ---------: | ---------------------: | ---------------: | --------------------------: | -----------------------: | -------------------------------: |
| 2026-10-03 |      7,179 |                  7,179 |        1,562,292 |                   1,562,292 |                    7,179 |                            217.6 |
| 2026-10-04 |      7,179 |                  7,179 |        1,526,358 |                   1,526,358 |                    7,179 |                            212.6 |
| 2026-10-05 |      7,175 |                  7,175 |        1,774,270 |                   1,774,270 |                    7,174 |                            247.3 |
| 2026-10-06 |      7,168 |                  7,168 |        1,957,602 |                   1,957,602 |                    7,167 |                            273.1 |
| 2026-10-07 |      7,173 |                  7,173 |        1,963,594 |                   1,963,594 |                    7,173 |                            273.7 |
| 2026-10-08 |      7,167 |                  7,167 |        1,837,570 |                   1,837,570 |                    7,167 |                            256.4 |
| 2026-10-09 |      7,178 |                  7,178 |        1,801,067 |                   1,801,067 |                    7,178 |                            250.9 |
| **합계**   | **50,219** |                      — |   **12,422,753** |                           — |                        — | **247.4 (전체 Tx / 전체 Block)** |

**참고:** 합계 row의 *247.4*는 7개의 일별 평균을 단순히 합하거나 단순 평균 낸 수치가 아니라 **전체 Transaction 12,422,753 ÷ 전체 Block 50,219**로 구한 기간 전체의 Block당 평균이다. 각 개별 Block에 247.4건이 있었다는 뜻이 아니다.

### 7.3 Finding과 해석

1. **Block 최고:** 10/3과 10/4에 각각 7,179건(공동 최고). **최저:** 10/8에 7,167건.
2. **포함 Transaction 최고:** 10/7에 1,963,594건. **최저:** 10/4에 1,526,358건.
3. Block 수와 Transaction 수의 최고 날짜는 **다르다**. 따라서 Block 개수가 많았다는 사실만으로 해당 날짜의 Transaction 수가 더 많았다고 결론 내릴 수 없다. Block마다 포함되는 Transaction 수가 다를 수 있다.
4. 날짜별 `block_rows = distinct_blocks`, `transaction_rows = distinct_transactions`가 모두 일치했다. 해당 필터 범위의 **`block_number` 및 `transaction_hash`**에 NULL과 중복이 관찰되지 않았다는 뜻이다. 이 결과로 **Block Hash**의 NULL·중복 여부까지 검사한 것은 아니다.
5. 10/5에는 7,175 Block rows 대 7,174 Transaction-bearing Block numbers, 10/6에는 7,168 대 7,167로 각각 **한 개 차이**가 있다. Transaction이 없는 Block이라는 가설이 가능하지만, 서로 다른 테이블의 Block Number **집합**을 대조하기 전에는 원인을 확정하지 않는다.
6. 12초 Slot을 기준으로 하루 약 7,200개 제안 기회가 있지만 이 데이터에서 관찰된 Block rows는 일별 7,167~7,179개다. 단순 차이는 21~33개이나, 이를 **정확한 Missed Slot 수 또는 Validator 실패 횟수**로 단정할 수 없다. 합의 계층의 Slot 기록과 데이터 제공 범위 등을 추가 확인해야 한다.

### 7.4 무엇을 주장할 수 있고, 무엇은 주장할 수 없는가?

| 주장                                                                       | 판단 / 이유                                                        |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| “정의한 7일간 해당 BigQuery 데이터셋에서 Block row 50,219개가 조회되었다.” | **가능** — 기간·출처·지표가 명확하다.                              |
| “10/7에 포함 Transaction row 수가 관찰 기간 중 가장 많았다.”               | **가능** — 날짜별 비교가 뒷받침한다.                               |
| “그날 Ethereum의 실제 이용자가 가장 많았다.”                               | **불가** — Transaction 수 ≠ 사람/사용자 수.                        |
| “모든 Block에 최소 1 Transaction이 프로토콜상 반드시 있어야 한다.”         | **불가** — 0개인 Block 가능.                                       |
| “10/5에 무조건 빈 Block이 정확히 하나 있었다.”                             | **미확정** — 실제 Block Number 집합 비교와 coverage 확인 필요.     |
| “모든 Validator가 하루에 21~33번 실패했다.”                                | **불가** — Slot 수와 Block row 수만으로 그런 결론이 나오지 않는다. |
| “Block이 포함됐으니 Transaction 실행은 모두 성공했다.”                     | **불가** — Receipt/Status 별도.                                    |
| “최신 Block을 Explorer에서 보면 반드시 BigQuery에도 즉시 있다.”            | **불가** — Finality와 색인 지연이 별도.                            |

### 7.5 재현 가능성 및 후속 검증 계획

실제 사용 SQL은 옆의 `sql/l0/l0_m2_l1_blocks_transactions_foundations.sql`에 있다. 제출 텍스트에서 `GROUP BY blocks_by_day` 및 `GROUP BY transaction_by_day`로 사용된 정의되지 않은 별칭을 실제 SELECT 별칭인 **`day`**로 교정했다. 이는 코드 표기 교정이며, 위의 관찰값을 새로 실행해 확인했다는 의미는 아니다.

향후 같은 숫자의 신뢰도를 더 높이려면: (a) 각 날짜에 대해 두 테이블의 실제 Block Number 집합을 비교하고, (b) 차이 나는 특정 Block의 Transaction 존재 여부를 조사하며, (c) 필요 시 공식 Schema 및 Known Issues를 점검하고, (d) 최신 기간에는 Finality·Freshness를 별도로 확인한다. 이는 학습 난이도에 맞춰 후속 SQL 관계 학습에서 진행한다.

---

## 8. Interpretation Boundaries & Principles to Reuse

- **Block ≠ Transaction ≠ 사람/사용자 ≠ ERC-20 Transfer Event.** 분석 대상을 먼저 정의한다.
- **Block 포함 ≠ 실행 성공 ≠ Finality.** 세 상태를 별도로 표현한다.
- **Network에 전파 ≠ On-chain 포함.** 일반 On-chain Transaction Table에는 포함되지 않은 전파 요청의 전체 집계가 없다.
- **Block Timestamp ≠ Transaction 서명/최초 전파 Timestamp.** 시간 컬럼의 출처를 확인한다.
- **`block_number` ≠ `block_hash` ≠ `parent_hash`.** 높이, 특정 Block 식별, 부모 참조는 다른 기능이다.
- **`state_root` ≠ 계정 잔액 리스트.** 상태의 검증용 root이며 직접적인 계정별 조회 데이터가 아니다.
- **Transaction 실패 ≠ Block 무효 ≠ Reorg.** 분석 결과가 바뀌는 원인부터 구분한다.
- **두 집계가 같음 ≠ 집합이 같음 ≠ 데이터 완전성 입증.** 어떤 성질을 검증했는지 좁게 기록한다.
- **Finality ≠ Provider Freshness/Coverage.** 체인의 상태와 데이터 제공자의 수록 상황을 별도로 다룬다.
- **검증의 깊이는 위험과 목적에 비례해야 한다.** 학습 때는 기초를 반복하지만 실무에서는 새 소스·고위험 지표·변환 로직의 위험에 맞춰 선별한다.

## 9. 이번 Lesson에서 내가 할 수 있게 된 것

분산된 Node들이 같은 Transaction을 일관된 순서로 처리해야 하는 이유를 설명하고, Block이 거래 요청의 모음인 동시에 이전 Block Hash를 참조하는 체인의 구성 단위임을 이해한다. 작성·서명·전파·포함·실행 성공·최종성의 차이를 구별할 수 있고, Node/Validator/Slot/Epoch/Reorg가 실제 관찰된 Transaction과 상태를 해석할 때 왜 중요한지 말할 수 있다. Ethereum 프로토콜과 Explorer/BigQuery 같은 데이터 제공자의 표현을 구별하며, `blocks`와 `transactions`의 Source Grain과 일별 집계 Output Grain을 구별한다. 실제 Block 26,158,300을 두 출처에서 교차 확인했고, SQL로 7일간 Block 및 포함 Transaction 활동을 독립 집계했으며, 식별자 고유성 점검과 분석의 해석 경계를 문서화했다. 이 능력은 앞으로 Account State, Gas/Receipt, JOIN 및 ERC-20 Event 분석의 기반이 된다.

## 10. 참고 자료

- Ethereum 개발자 문서 — Blocks: https://ethereum.org/developers/docs/blocks/
- Ethereum 개발자 문서 — Transactions: https://ethereum.org/developers/docs/transactions/
- Ethereum 개발자 문서 — Proof of Stake: https://ethereum.org/developers/docs/consensus-mechanisms/pos/
- Google Blockchain Analytics: https://cloud.google.com/blockchain-analytics/docs
- Etherscan Block Transaction Explorer: https://etherscan.io/txs?block=26158300

공식 문서는 개념 및 데이터셋 정의를 확인하는 참고자료다. 이 문서에 기록된 *실측 숫자*의 근거는 학습자가 제출한 BigQuery 출력과 Etherscan 관찰이며, 참고 링크가 곧 모든 수치에 대한 독립 재검증을 의미하지는 않는다.
