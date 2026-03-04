# 🚀 Project #1: UART with FIFO Verification System

[cite_start]본 프로젝트는 하드웨어 설계 및 검증 역량을 증명하기 위한 첫 번째 프로젝트로, **UART(Universal Asynchronous Receiver/Transmitter)** 통신 모듈과 **FIFO(First-In-First-Out)** 버퍼를 통합 설계하고 **SystemVerilog 기반의 계층적 검증 환경**을 구축하여 동작을 완벽히 검증하였습니다. [cite: 1, 2, 3]

---

## 📌 1. Project Overview
* [cite_start]**목표**: 비동기 직렬 통신과 데이터 버퍼링 시스템의 안정적인 설계 및 검증 [cite: 31, 32, 421]
* **주요 기능**:
    * [cite_start]**UART RX**: 16배 오버샘플링을 통한 시작 비트 검출 및 8비트 데이터 복원 [cite: 31, 32, 47, 49, 51]
    * [cite_start]**UART TX**: 병렬 데이터를 LSB First 방식으로 직렬 변환하여 전송 [cite: 992, 1011, 1265]
    * [cite_start]**FIFO Buffer**: `register_file`과 `control_unit`을 이용한 데이터 흐름 제어 및 Full/Empty 상태 관리 [cite: 421, 427, 432, 433, 455, 456]

---

## 🏗️ 2. System Architecture


### **모듈 구성**
* [cite_start]**Uart_top**: `Uart_rx`, `Rx_fifo`, `Uart_total_tx`를 포함하는 최상위 모듈 [cite: 4]
* [cite_start]**Uart_rx**: 직렬 신호를 샘플링하여 8비트 병렬 데이터로 변환 [cite: 6, 32, 49, 51]
* [cite_start]**Uart_tx**: 데이터를 1비트씩 분할하여 직렬 출력 [cite: 19, 1011, 1265]
* [cite_start]**FIFO (Rx/Tx)**: 포인터(`wptr`, `rptr`) 제어를 통해 데이터의 입력과 출력을 관리 [cite: 7, 20, 457, 459, 460, 462]

---

## 🛠️ 3. Layered Verification Environment
[cite_start]SystemVerilog의 객체 지향 프로그래밍(OOP) 개념을 도입하여 체계적인 검증 환경을 구축했습니다. [cite: 60, 469, 1012]

### **Verification Components**
* [cite_start]**Transaction**: 데이터와 제어 신호를 추상화한 클래스 [cite: 68, 474, 1030]
* [cite_start]**Generator**: 랜덤 데이터를 생성하여 Mailbox를 통해 전달 (Push 80%, Pop 20% 확률 지정 등) [cite: 73, 478, 1014, 1048, 1049]
* [cite_start]**Driver**: 인터페이스를 통해 DUT에 신호를 인가하며, FIFO 상태를 실시간 확인 [cite: 75, 479, 1014]
* [cite_start]**Monitor**: DUT의 입출력을 관찰하고 수신 데이터를 역복원 [cite: 84, 483, 1014]
* [cite_start]**Scoreboard**: Queue를 사용하여 원본 데이터와 복원된 데이터를 비교 후 Pass/Fail 판정 [cite: 87, 485, 1014]

---

## 🔍 4. Troubleshooting & Solution

### **Issue: Race Condition in Simulation**
* [cite_start]**현상**: Driver와 Monitor가 동일한 `posedge clk`에서 작동하여 데이터 샘플링 시 레이스 컨디션 발생 [cite: 1292]
* [cite_start]**해결**: Driver 동작 시 **1ns의 지연(Delay)**을 추가하여 시뮬레이션의 안정성 확보 [cite: 1294]

### **Issue: Monitor Sampling Timing**
* [cite_start]**현상**: `rx_done` 신호가 뜨기 전 데이터를 모니터링하여 부정확한 값 수집 [cite: 268]
* [cite_start]**해결**: `rx_done` 신호가 감지된 후 **1클럭 지연**하여 데이터를 샘플링하도록 모직 수정 [cite: 183, 312]

---

## 📊 5. Simulation Results
* [cite_start]**UART RX**: Total 10 tries, **100% Pass** [cite: 304, 305, 415, 417]
* [cite_start]**UART TX**: Total 9 tries, **100% Pass** [cite: 1327, 1329]
* [cite_start]**FIFO**: Push/Pop 시퀀스 및 Full/Empty 상태 변화 시 데이터 무결성 확인 [cite: 630, 631, 771, 840, 912, 914]

---

[cite_start]**Project Designer**: Jiwon Yun (윤지원) [cite: 2]
