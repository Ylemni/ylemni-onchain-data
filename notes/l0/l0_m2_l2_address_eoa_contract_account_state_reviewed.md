# L0-M2-L2 — Ethereum Address, EOA, Contract & Account State

**대상 네트워크:** Ethereum Mainnet  
**분석 기준일:** 2026-10-09 UTC (`2026-10-09 00:00:00` 이상 ~ `2026-10-10 00:00:00` 미만)  
**데이터 출처:** Google Cloud Blockchain Analytics / BigQuery  
**재현용 SQL:** [`sql/l0/l0_m2_l2_address_eoa_contract_account_state.sql`](../../sql/l0/l0_m2_l2_address_eoa_contract_account_state.sql)

> **문서 목적:** Ethereum의 Account 구조와 상태 전이 원리를 설명하고, Ethereum Mainnet USDC Contract를 사례로 실제 온체인 데이터의 지표 정의·분석 결과·해석 한계를 기록한다. 개념 설명의 가상 예시와 BigQuery에서 확인된 관찰값을 구분한다.

## 1. Analysis Question & Scope

Ethereum은 Transaction을 기록하는 동시에 각 Account의 상태를 유지한다. 그러나 **Address**, Transaction의 최초 목적지(`to_address`), Account의 **ETH Balance**, Smart Contract 내부의 **Token Balance**, Contract의 **Nonce**는 각각 다른 대상을 나타낸다.

이 문서는 다음 두 질문에 답한다.

1. **데이터 모델:** Ethereum에서 Address·Account·Wallet·Private Key는 어떻게 다르고, EOA와 Smart Contract Account의 상태는 어떻게 유지·변경되는가?
2. **실제 분석:** 2026-10-09 UTC에 USDC Contract를 최초 목적지로 지정한 Top-level Transaction은 몇 건이며, 그 Contract의 관찰된 `nonce`를 일별 USDC 활동량 KPI로 사용할 수 있는가?

이번 실제 집계는 **특정 Contract를 목적지로 지정한 Top-level Transaction**과 **데이터 제공자가 저장한 Account State 관찰값**을 측정한다. 이는 USDC의 모든 Token Transfer, 성공한 전송, 고유 사용자 수, 전체 내부 EVM 실행을 직접 측정하는 지표가 아니다.

---

## 2. Address, Account, Wallet & Cryptographic Keys

### 2.1 서로 다른 네 가지 객체

| 개념            | 정확한 의미                                                                                   | 혼동하면 안 되는 것                                         |
| --------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| **Address**     | Ethereum Account를 식별하는 20바이트 값. 통상 `0x`와 40자리 16진수로 표기                     | Address 자체는 사람의 신원이나 Account 유형을 나타내지 않음 |
| **Account**     | Address로 식별되며 Ethereum State에서 잔액·Nonce·코드/저장 정보와 연결되는 대상               | Account는 Wallet 애플리케이션이 아님                        |
| **Wallet**      | 계정 조회, Transaction 작성, 서명 관리 및 네트워크 접근을 돕는 소프트웨어·하드웨어·인터페이스 | ETH가 Wallet UI 내부에 물리적으로 보관되는 것은 아님        |
| **Private Key** | 일반적인 EOA 모델에서 암호학적 서명을 생성하는 비밀 정보                                      | 공개 Address와 구별하며 절대 노출해서는 안 됨               |
| **Public Key**  | Private Key로부터 수학적으로 도출되는 공개키                                                  | Public Key와 Ethereum Address는 같은 값이 아님              |
| **Seed Phrase** | 일반적인 HD Wallet에서 여러 키를 파생·복원할 수 있게 하는 복구 정보                           | 단일 Private Key의 다른 이름이 아님                         |

전통적인 EOA의 주소 도출 관계는 개념적으로 다음과 같이 나타낼 수 있다.

```text
Private Key ──파생──> Public Key ──주소 도출──> Ethereum Address
      │
      └── Transaction 승인에 필요한 서명 생성
```

**Address를 알고 있다는 사실만으로 그 Address에서 Transaction을 승인할 수는 없다.** EOA를 제어하려면 적절한 서명 권한이 필요하다.

### 2.2 Wallet, Account, Address가 1:1로 대응하지 않는 이유

하나의 Wallet 애플리케이션에서 여러 Account를 관리할 수 있고, 한 사람이 여러 Address를 사용할 수 있다. 반대로 거래소 등에서는 하나의 운영 Address를 통해 여러 고객의 자산 흐름을 처리할 수 있다.

예를 들어 두 Transaction의 `from_address`가 다르다는 사실만으로 실제 사용자가 두 명이라고 단정할 수는 없다. **`COUNT(DISTINCT address)`는 Address 수이지 사람 수가 아니다.** 이러한 분류에는 추가적인 Entity Attribution 방법과 가정이 필요하다.

Node도 구분해야 한다. Node는 Ethereum 데이터를 전파·검증하는 네트워크 참여 시스템이고, Address는 계정을 식별하는 값이다. Address를 소유한다고 반드시 Node를 직접 운영하는 것은 아니다.

---

## 3. EOA와 Smart Contract Account

### 3.1 제어 방식과 실행 시작점

| 비교 기준                         | 전통적인 EOA                         | Smart Contract Account                       |
| --------------------------------- | ------------------------------------ | -------------------------------------------- |
| Ethereum Address                  | 존재                                 | 존재                                         |
| Native ETH 보유                   | 가능                                 | 가능                                         |
| 기본 제어 방식                    | Private Key를 이용한 서명            | 배포된 실행 코드의 규칙                      |
| 일반 Top-level Transaction 시작   | 서명하여 제출 가능                   | 전통적인 EOA처럼 직접 서명하여 시작하지 않음 |
| Transaction 목적지가 될 수 있는가 | 가능                                 | 가능                                         |
| 다른 Contract와의 상호작용        | Contract를 목적지로 Transaction 제출 | 코드 실행 중 다른 Contract 호출 가능         |

Contract는 시간이 되면 스스로 실행되는 상시 구동 프로그램이 아니다. 일반적으로 Transaction이나 다른 Contract의 호출을 통해 실행 경로가 Contract 코드에 도달해야 동작한다. 외부 자동화 프로그램이 정해진 시점에 호출 Transaction을 제출할 수는 있지만, **외부 호출의 발생**과 **Contract 코드의 규칙에 따른 실행**은 구별해야 한다.

또한 EIP-7702와 같은 위임 기능이 존재하므로, 현대 Ethereum에서 `코드 관련 정보가 있음 = 전통적인 Contract Account`처럼 지나치게 단순한 분류를 항상 적용할 수는 없다. 뒤의 `accounts.is_contract`는 **데이터 제공자의 분류 기준에 따른 필드**로 해석한다.

### 3.2 Top-level Contract Creation과 내부 Contract 생성

새 Contract가 만들어지는 대표적인 경로는 두 가지다.

**직접 생성 시도:**

```text
EOA ──Top-level Transaction, to_address = NULL──> Contract 생성 시도
```

**Factory Contract를 통한 내부 생성:**

```text
EOA ──Top-level Transaction, to_address = Factory 주소──> Factory Contract
                                                       └── CREATE/CREATE2 ──> 새 Contract
```

두 번째 경로에서는 최초 `to_address`가 `NULL`이 아니어도 내부 실행 중 새 Contract를 생성할 수 있다. 따라서 **`to_address IS NULL`인 Top-level Transaction 수는 Ethereum에서 생성된 전체 Contract 수와 같지 않다.** 또한 생성 시도가 Block에 포함되었다고 성공적인 배포가 보장되는 것도 아니다.

---

## 4. Account State — Balance, Nonce, Code, Storage

### 4.1 State와 Transaction History

**Transaction History**는 어떤 실행 요청이 Block에 포함되었는지를 설명한다. **Account State**는 특정 실행 시점에 Account가 어떤 상태인지 나타낸다. Transaction을 순서대로 실행하면 다음 상태가 결정되는 과정을 **State Transition(상태 전이)**이라고 한다.

```text
Block N 처리 후 State
       │
       ├── Transaction T1 실행
       ├── Transaction T2 실행
       ▼
Block N+1 처리 후 State
```

같은 Address의 ETH Balance도 Block N 처리 후와 Block N+1 처리 후에 다를 수 있다. 따라서 Account 상태를 비교할 때는 **어느 Block 처리 후의 상태인지**가 중요하다.

### 4.2 프로토콜 필드와 개념적 구성 요소

Account를 이해할 때는 **Balance, Nonce, Code, Storage**라는 네 개념을 사용한다. 다만 프로토콜의 Account 상태에 직접 표현되는 네 필드는 엄밀하게 `nonce`, `balance`, `storageRoot`, `codeHash`다. Code 전체와 Storage의 모든 Key·Value가 이 두 Hash 필드 자체에 담겨 있는 것은 아니다.

| 개념                      | 의미                                                       | 해석 시 주의사항                                        |
| ------------------------- | ---------------------------------------------------------- | ------------------------------------------------------- |
| `balance`                 | Account의 Native ETH 잔액. 기본 단위는 `wei`               | ERC-20 Token 잔액을 합산한 값이 아님                    |
| `nonce`                   | Account 유형에 따라 다른 의미를 갖는 순서·생성 관련 카운터 | 일반 함수 호출 횟수 또는 성공 송금 횟수가 아님          |
| `code` / `codeHash`       | EVM 실행 코드 및 그 코드와 연결된 Hash                     | 실행 규칙 자체와 현재 Storage 값을 구별                 |
| `storage` / `storageRoot` | Contract가 유지하는 영속 상태와 이를 검증하는 Root Hash    | `storageRoot`는 Storage 전체를 읽을 수 있는 목록이 아님 |

ETH와 wei의 관계는 다음과 같다.

\[
1\;\mathrm{ETH} = 10^{18}\;\mathrm{wei}
\]

### 4.3 ETH Balance와 Token Balance

일반적인 ERC-20 Token의 잔액은 Ethereum Account의 Native ETH `balance` 필드에 직접 저장되는 것이 아니다. Token Contract가 자신의 규칙과 상태를 통해 각 Address의 Token Balance를 관리한다.

```text
Alice EOA의 프로토콜 balance: 3 ETH

USDC Token Contract의 관리 대상:
  Alice 주소 → 100 USDC
  Bob 주소   →  50 USDC
```

이 예시에서 ETH 3개와 USDC 100개는 서로 다른 자산·상태의 단위다. 또한 Vault Contract의 실제 ETH Balance와 Vault Storage에 기록된 사용자별 예치액은 서로 다른 성질의 정보이므로 **별도 자산인 것처럼 중복 합산해서는 안 된다.**

### 4.4 EOA Nonce와 Contract Nonce의 차이

일반적인 EOA의 Nonce는 해당 Sender가 제출하는 Transaction의 순서와 중복 실행 방지에 관련된다. Contract 실행이 `revert`되더라도 해당 Transaction이 유효한 Block에 포함·처리되었다면 Sender EOA의 Nonce는 증가한다. 반대로 ETH를 **받기만 한 계정**의 Nonce는 수신했다는 이유로 증가하지 않는다.

전통적인 Contract Account의 프로토콜 Nonce는 **그 Contract가 수행하는 Contract 생성 작업**과 연결된다. 다른 사용자가 Contract의 일반 함수를 성공적으로 호출하거나 Contract가 ETH를 받았다는 이유만으로 증가하지 않는다.

**가상 예시:** Factory F의 Nonce가 3이고, 함수가 10번 성공적으로 호출되었지만 그 과정에서 새 Contract 생성이 없었다면 F의 Nonce는 여전히 3이다. 반면 F가 `CREATE` 또는 `CREATE2` 작업을 수행한다면 생성에 관한 프로토콜 규칙이 Nonce에 영향을 준다. 실패한 생성 시도나 실행 전체의 Revert까지 고려하면 **Nonce 차이 = 성공한 Contract 배포 수**라고도 단정할 수 없다.

Contract가 자체적으로 `callCount`라는 Storage 변수를 정의하여 호출 횟수를 기록할 수 있지만, 이는 애플리케이션 내부 카운터이며 **프로토콜 Account Nonce와 다르다.**

### 4.5 Code와 Storage의 관계

```text
Counter Contract C1

Code: incrementCounter()를 호출하면 counter에 1을 더함
Storage (실행 전): counter = 7
Storage (성공적으로 실행 후): counter = 8
Code (실행 후): 기존과 동일
```

Code는 **무엇을 할 수 있는지에 관한 규칙**, Storage는 **그 규칙에 따라 유지되는 현재 값**이다. Storage 값이 변경되었다고 코드 자체가 바뀌거나 Contract Nonce가 자동으로 증가하는 것은 아니다.

---

## 5. Transaction과 Account State Transition

Top-level Transaction은 최초 `from_address`, `to_address`, `value`, `input` 등을 제시한다. 하지만 실제 EVM 실행은 다른 Contract 호출, 내부 ETH 이동, Storage 변경, Token Balance 변경으로 이어질 수 있다. 다음 사례는 **가상의 상태 전이**이며 수수료를 제외하고 별도 언급이 없으면 실행 성공을 가정한다.

### 5.1 일반 ETH 송금

초기 Alice는 8 ETH/Nonce 5, Bob은 1 ETH/Nonce 2를 가진다. Alice가 Bob에게 2 ETH를 전송하면:

| Account | 이전 ETH Balance | 이후 ETH Balance | 이전 Nonce | 이후 Nonce |
| ------- | ---------------: | ---------------: | ---------: | ---------: |
| Alice   |                8 |                6 |          5 |          6 |
| Bob     |                1 |                3 |          2 |          2 |

Sender Alice의 Nonce는 증가하지만, Bob의 Nonce는 ETH를 수신했다는 이유만으로 증가하지 않는다.

### 5.2 Vault 예치 — 실제 잔액과 내부 기록

Vault C1의 ETH Balance는 10 ETH, Storage에 기록된 Alice 예치액은 0 ETH라고 가정한다. Alice가 `deposit()`을 호출하며 2 ETH를 보내고 Contract가 그 예치를 기록한다면:

```text
Alice ETH Balance                6 → 4
Vault C1 Native ETH Balance    10 → 12
Vault Storage recordedDeposit[Alice] 0 → 2
Alice EOA Nonce                  6 → 7
```

Vault의 ETH Balance는 실제 Native ETH 잔액이고, `recordedDeposit[Alice]`는 Contract가 관리하는 예치 기록이다. 두 숫자는 동일한 자산을 두 번 세기 위한 값이 아니다.

### 5.3 내부 ETH 이동 — 최초 목적지와 최종 수령자

```text
Top-level Transaction:
  from_address = Alice
  to_address   = Vault C1
  value        = 0 ETH
  input        = payToBob()

Contract 내부 실행(성공 가정):
  C1 → Bob, 1 ETH 전송
```

최초 Transaction의 `to_address`는 **C1**이지만 실제 ETH 수령자는 **Bob**이다. 따라서 `value = 0 ETH`만으로 실행 전체에서 ETH 이동이 없었다고 결론 내릴 수 없다. 이러한 내부 실행 경로를 조사할 때는 **Execution Trace** 등의 추가 데이터가 필요할 수 있다.

### 5.4 ERC-20 Token 전송

Alice가 Token Contract의 `transfer(Bob, 10)` 함수를 호출하며 `value = 0 ETH`인 Transaction을 제출할 수 있다. 일반적인 ERC-20 동작을 가정하면:

```text
Top-level to_address = Token Contract
Top-level value      = 0 ETH

Token Contract가 관리하는 잔액:
  Alice: 50 → 40 Token
  Bob:    5 → 15 Token
```

Token 수량은 Token Contract의 로직과 상태를 통해 변경된다. Alice의 기본 ETH `balance`에서 **10 ETH가 차감되었다는 뜻이 아니다.** 정확한 Token Transfer의 횟수·수량 분석에는 Transfer Event, Token별 단위/Decimals와 추가 실행 데이터가 필요하다.

### 5.5 Revert, 포함 여부, Finality

Transaction이 Block에 포함되었더라도 Contract 실행은 `revert`될 수 있다. 이때 되돌려진 실행의 Storage 변경은 일반적으로 정규 실행 결과에 남지 않지만, Sender의 Nonce는 소비되고 Gas 비용이 발생할 수 있다.

- **Included:** Block에 Transaction이 기록·처리되었는가?
- **Successful:** 실행이 성공했는가?
- **Finalized:** 관련 Block이 합의상 최종성을 확보했는가?

세 상태는 동일하지 않다. `transactions`의 Top-level row 수만으로 성공 Transaction 수를 계산해서는 안 된다.

---

## 6. BigQuery 데이터 모델과 Coverage

### 6.1 데이터 소스와 Grain

분석에는 Ethereum Mainnet 공개 데이터셋 `bigquery-public-data.goog_blockchain_ethereum_mainnet_us`를 사용한다. 주소 기반 조회에는 해당 필드를 중심으로 구성된 View를 활용한다.

| 데이터 소스                  | 분석 목적                                   | 관찰되는 Row의 의미                                           |
| ---------------------------- | ------------------------------------------- | ------------------------------------------------------------- |
| `accounts`                   | Address별 Account 분류·코드 관련 정보       | 특정 Address의 계정 정보                                      |
| `transactions_by_to_address` | 특정 Address를 목적지로 한 Transaction 검색 | 포함된 Top-level Transaction 기록                             |
| `accounts_state_by_address`  | Address별 Account State 조회                | 특정 Block 높이에서 기록된 Account State 관찰값               |
| `traces`                     | 내부 EVM 실행 경로 분석                     | 내부 호출·실행 동작의 기록. 별도 Top-level Transaction이 아님 |
| `token_transfers`            | Token 이동 분석                             | 데이터셋의 추출 규칙에 따라 식별한 Token Transfer             |

`accounts.is_contract`는 제공자가 정의한 Boolean 분류 필드다. Ethereum Address는 해당 데이터셋에서 소문자로 정규화해 비교한다.

**Source Grain과 Output Grain도 구분해야 한다.** 예를 들어 Transaction-level 데이터에 `COUNT(*)`를 적용하면 집계 결과 한 행이 나오지만, 이것이 원본의 Transaction Grain을 사용자 Grain으로 바꾼다는 뜻은 아니다.

### 6.2 Snapshot, Coverage, Freshness

Ethereum 프로토콜상 특정 Block 처리 후 전체 State가 존재한다는 사실은 BigQuery에 모든 `Address × Block` 조합의 완전한 Snapshot이 저장되어 있음을 보장하지 않는다.

Google의 알려진 제한 사항에 따르면 `accounts_state`는 주로 **Top-level Transaction의 `from`/`to`로 관찰된 Account**를 대상으로 상태를 기록하며, 내부 Contract 실행으로 인한 모든 Account State 변경을 완전하게 계산하지 않는다. Contract Storage 전체나 Storage Proof를 제공하는 완전한 역사 상태 데이터도 아니다.

```text
Top-level: Alice → Vault C1
내부 실행: Vault C1 → Bob, 1 ETH
```

이 경우 Bob은 최초 Transaction의 `from`이나 `to`가 아니다. 따라서 해당 Account State 데이터만 사용해 모든 내부 ETH 이동의 상태 변화를 복원할 수 있다고 가정해서는 안 된다.

| 구분             | 질문                                                    |
| ---------------- | ------------------------------------------------------- |
| **Grain**        | 한 Row가 정확히 무엇을 나타내는가?                      |
| **Coverage**     | 실제 체인 현상 중 어떤 대상과 사건을 수록하는가?        |
| **Freshness**    | 최신 Block 중 어디까지 데이터가 반영되었는가?           |
| **Completeness** | 정의한 대상 범위의 필요한 기록이 빠짐없이 포함되었는가? |
| **Accuracy**     | 기록값이 정의 및 출처에 비추어 정확한가?                |

**0 ETH**, **NULL**, **해당 Row 자체가 없음**도 서로 다르다. Row가 없다는 이유만으로 그 Block에서 Balance가 0이거나 Account가 존재하지 않았다고 단정할 수 없다.

### 6.3 상태 관찰값의 범위와 해석

`MIN(nonce)`와 `MAX(nonce)`는 **필터된 관찰 기록에서의 Nonce 범위**를 나타낸다. 그 차이는 전체 Contract 생성 이력이나 성공한 배포 횟수와 자동으로 같아지지 않는다.

마찬가지로:

```sql
MAX(block_number) - MIN(block_number)
```

는 **관찰된 Block 높이 사이의 차이**를 나타낸다. 이 식은 최소·최대 Block Number 각각을 출력하지 않으며, Transaction 수나 관찰 행 수를 계산하는 식도 아니다.

---

## 7. Case Study — USDC Contract의 Transaction 활동과 Nonce

### 7.1 대상, 시간, 지표 정의

**Contract:** Ethereum Mainnet USDC  
**Address:** `0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48`  
**시간 범위:** `2026-10-09 00:00:00 UTC ≤ block_timestamp < 2026-10-10 00:00:00 UTC`

| 지표                           | 정의                                                                                        |
| ------------------------------ | ------------------------------------------------------------------------------------------- |
| **목적지 Transaction 수**      | 지정 기간에 `to_address`가 USDC Contract인 포함된 Top-level Transaction row의 `COUNT(*)`    |
| **관찰된 Nonce 최솟값·최댓값** | 같은 기간에 저장된 USDC Account State 기록의 `MIN(nonce)`, `MAX(nonce)`                     |
| **관찰된 Nonce 범위**          | `MAX(nonce) - MIN(nonce)`; 검증된 Contract 생성 횟수가 아님                                 |
| **관찰된 Block 높이 범위**     | 상태 기록의 `MIN(block_number)` 및 `MAX(block_number)` 각각. 선택적으로 두 값의 차이를 계산 |

분석 SQL은 동반 파일에 있으며, `accounts` 분류 조회, 상태 표본 조회, 목적지 Transaction 집계, Nonce/Block 범위, 상태 관찰 빈도 확인 Query로 구성되어 있다.

### 7.2 실제 관찰 결과

다음 수치는 2026-10-09 UTC 범위에 대해 BigQuery에서 확인한 조회 결과를 기록한 것이다. 관찰된 Block Number의 최솟값과 최댓값도 동일한 기간의 실제 조회 결과로 확인되었다. 추후 데이터셋 갱신으로 재실행 결과가 달라질 수 있다.

| 관찰 항목                                        |          값 | 근거 범위                       |
| ------------------------------------------------ | ----------: | ------------------------------- |
| `accounts.is_contract`                           |      `TRUE` | 데이터 제공자의 Contract 분류   |
| USDC를 최초 목적지로 한 Top-level Transaction 수 | **169,723** | 2026-10-09 UTC 포함 Transaction |
| 관찰된 USDC Contract Nonce 최솟값                |       **1** | 해당 날짜 Account State 관찰값  |
| 관찰된 USDC Contract Nonce 최댓값                |       **1** | 해당 날짜 Account State 관찰값  |
| 관찰된 Nonce 범위                                |       **0** | `MAX(nonce) - MIN(nonce)`       |
| 관찰된 최소 Block Number                         |    26151123 | 해당 날짜 Block Number 관찰값   |
| 관찰된 최대 Block Number                         |    26158300 | 해당 날짜 Block Number 관찰값   |

**169,723건**은 USDC가 정확히 169,723회 성공적으로 전송되었다는 뜻이 아니다. 해당 값에는 실행 성공·실패의 구분이 없으며, `Transfer` Event 수나 사용자 수, Token 전송량을 직접 나타내지 않는다. Contract를 향한 모든 내부 호출도 포함하는 지표가 아니다.

### 7.3 KPI 채택 여부

**결론: USDC Contract의 프로토콜 `nonce`를 일별 USDC 사용량 KPI로 채택하지 않는다.**

이유는 수치상의 우연한 불일치가 아니라 **측정 대상 자체가 다르기 때문**이다. 전통적인 Contract Account의 Nonce는 그 Contract가 수행한 Contract 생성 작업과 관련되지만, 일반적인 USDC 함수 호출이나 Token Transfer는 별개의 활동이다.

실제 관찰에서도 하루 동안 USDC를 최초 목적지로 지정한 Top-level Transaction이 **169,723건**이었지만, 같은 날짜에 관찰된 Contract Nonce는 **1~1**이었다. 이는 두 지표가 같은 현상을 측정하지 않는다는 구조적 판단과 일치한다.

그러나 **관찰된 Nonce가 일정하다 = 해당 Contract가 모든 시점에서 새 Contract를 생성하지 않았다**고 증명된 것은 아니다. 관찰 시점과 데이터 수록 범위를 벗어난 사건까지 단정할 수 없기 때문이다.

### 7.4 분석 질문에 맞는 대안 지표

| 분석 목표                                                    | 검토할 데이터 또는 지표                                                  |
| ------------------------------------------------------------ | ------------------------------------------------------------------------ |
| USDC Address를 최초 목적지로 지정한 Top-level Transaction 수 | `transactions_by_to_address` 집계                                        |
| 성공적으로 실행된 Top-level Transaction 수                   | Transaction 실행 결과 및 Receipt/Status                                  |
| USDC Token Transfer의 건수·금액                              | USDC에 해당하는 `token_transfers`, `Transfer` Event, Token 단위/Decimals |
| Contract 내부 호출·ETH 이동                                  | Execution Trace 및 관련 실행 데이터                                      |
| 서로 다른 경제적 사용자 수                                   | 명시적인 Entity Attribution 방법과 가정                                  |

한 지표가 모든 질문에 답하지는 않는다. **'USDC Contract 호출'**, **'성공한 Transaction'**, **'USDC Token Transfer'**, **'실제 사용자'** 는 서로 다른 Metric Definition이 필요하다.

### 7.5 분석의 한계와 재현성

- **기간:** 2026-10-09 UTC의 하루 관찰값으로 장기 추세를 일반화하지 않는다.
- **Coverage:** Account State의 관찰 규칙은 모든 내부 상태 변화의 연속적인 완전 기록이 아니다.
- **실행 결과:** 목적지 Transaction 집계만으로 Revert 여부나 성공 건수를 확인하지 못한다.
- **Token 의미:** Top-level 목적지 Transaction 수는 ERC-20 Transfer Event 수 및 금액과 다르다.
- **관찰된 Block 범위:** 해당 기간 Account State에 기록된 최소 Block Number는 **26,151,123**, 최대는 **26,158,300**이며, 두 값의 차이는 **7,177**이다. 이는 관찰된 Block 높이의 범위이지 연속된 모든 Block에서 Account State가 기록되었다는 뜻은 아니다.
- **재현 조건:** 동반 SQL의 Address 및 날짜 필터를 사용하고, Schema와 예상 처리 바이트를 확인한 뒤 조회한다. 데이터셋의 추후 갱신으로 재실행 값이 변할 수 있다.

---

## 8. Conclusion

Ethereum Account를 분석할 때는 **주소와 사람의 관계**, **EOA와 Contract Account의 제어 방식**, **최초 Transaction 요청과 내부 EVM 실행**, **Native ETH Balance와 Token Contract의 상태**, **프로토콜의 전체 State와 분석 제공자의 관찰 Snapshot**을 구분해야 한다.

USDC 사례에서는 2026-10-09 UTC에 Contract를 최초 목적지로 지정한 Top-level Transaction **169,723건**과 Contract의 관찰된 Nonce **1~1**을 확인했다. 이것은 일별 Contract 사용량 KPI로서 **프로토콜 Nonce가 부적합하다**는 판단을 뒷받침한다. 반면 두 지표만으로 성공적인 USDC Token 전송의 전체 건수나 금액을 계산할 수는 없다.

**핵심 원칙:** 데이터에서 계산할 수 있다는 이유만으로 그 수치가 분석 질문에 적합한 지표가 되는 것은 아니다. 지표의 정의, 실행 의미, 관찰 시점과 수록 범위를 함께 확인해야 한다.

## References

1. [Ethereum.org — Ethereum Accounts](https://ethereum.org/en/developers/docs/accounts/) — EOA/Contract Account, Account State 구성 및 Nonce.
2. [Google Cloud — Blockchain Analytics Schema](https://docs.cloud.google.com/blockchain-analytics/docs/schema) — Ethereum 공개 데이터와 주소 중심 View, 테이블 구조.
3. [Google Cloud — Blockchain Analytics Known Issues](https://docs.cloud.google.com/blockchain-analytics/docs/known-issues) — Account State Coverage, Snapshot 및 최신성 제약.
4. [Google Cloud — Ethereum Example Queries](https://docs.cloud.google.com/blockchain-analytics/docs/example-ethereum) — Ethereum 데이터 분석 Query 참고.
5. [Etherscan — Ethereum Mainnet USDC Contract](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) — Contract Address 탐색 참고.
