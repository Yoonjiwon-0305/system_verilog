# 🚀 Project #1: UART with FIFO Verification System

본 프로젝트는 하드웨어 설계 및 검증 역량을 증명하기 위한 첫 번째 프로젝트로, UART 통신 모듈과 FIFO 버퍼를 통합 설계하고 SystemVerilog 기반의 계층적 검증 환경을 구축하여 동작을 완벽히 검증하였습니다.

---

## 📌 1. Project Overview
* **목표**: 비동기 직렬 통신과 데이터 버퍼링 시스템의 안정적인 설계 및 검증
* **주요 기능**:
    * **UART RX**: 16배 오버샘플링을 통한 시작 비트 검출 및 8비트 데이터 복원
    * **UART TX**: 병렬 데이터를 LSB First 방식으로 직렬 변환하여 전송
    * **FIFO Buffer**: register_file과 control_unit을 이용한 데이터 흐름 제어 및 상태 관리

---

## 🏗️ 2. System Architecture
[Image of UART with FIFO Block Diagram]

### **모듈 구성**
* **Uart_top**: Uart_rx, Rx_fifo, Uart_total_tx를 포함하는 최상위 모듈
* **Uart_rx**: 직렬 신호를 샘플링하여 8비트 병렬 데이터로 변환
* **Uart_tx**: 데이터를 1비트씩 분할하여 직렬 출력
* **FIFO (Rx/Tx)**: 포인터(wptr, rptr) 제어를 통해 데이터의 입력과 출력을 관리

---

## 🛠️ 3. Layered Verification Environment
SystemVerilog의 객체 지향 프로그래밍(OOP) 개념을 도입하여 체계적인 검증 환경을 구축했습니다.

### **Verification Components**
* **Transaction**: 데이터와 제어 신호를 추상화한 클래스
* **Generator**: 랜덤 데이터를 생성하여 Mailbox를 통해 전달
* **Driver**: 인터페이스를 통해 DUT에 신호를 인가하며, FIFO 상태를 실시간 확인
* **Monitor**: DUT의 입출력을 관찰하고 수신 데이터를 역복원
* **Scoreboard**: Queue를 사용하여 원본 데이터와 복원된 데이터를 비교 후 Pass/Fail 판정

---

## 🔍 4. Troubleshooting & Solution

### **Issue: Race Condition in Simulation**
* **현상**: Driver와 Monitor가 동일한 posedge clk에서 작동하여 데이터 샘플링 시 레이스 컨디션 발생
* **해결**: Driver 동작 시 1ns의 지연(Delay)을 추가하여 시뮬레이션의 안정성 확보

### **Issue: Monitor Sampling Timing**
* **현상**: rx_done 신호와 데이터 모니터링 시점의 불일치로 신호 누락 발생
* **해결**: rx_done 신호가 감지된 후 1클럭 지연(또는 특정 타이밍 지연)하여 데이터를 샘플링하도록 로직 수정

---

## 📊 5. Simulation Results
* **UART RX**: Total 10 tries, 100% Pass
* **UART TX**: Total 9 tries, 100% Pass
* **FIFO**: Push/Pop 시퀀스 및 Full/Empty 상태 변화 시 데이터 무결성 확인

---

**Project Designer**: Jiwon Yoon (윤지원)
