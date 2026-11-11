# Synthesizable Full-Duplex 8N1 UART Controller Core

A robust, fully parametric Universal Asynchronous Receiver-Transmitter (UART) digital core written in synthesizable IEEE 1364-2001 Verilog. Designed for FPGA targets, this core implements a standard 8N1 serial protocol with $16\times$ oversampling tick-alignment and integrated dual parametric circular FIFOs for non-blocking hardware serial communication.

---

## Key Features

- **Standard 8N1 Frame Protocol**: 1 start bit, 8 data bits, 1 stop bit, no parity bit.
- **$16\times$ Oversampling Receiver**: Implements midpoint sampling on tick counts to minimize bit error rates across noisy transmission lines.
- **Parametric Hardware Architecture**:
  - `DBIT`: Data word length (default `8` bits).
  - `SB_TICK`: Stop bit tick count (`16` ticks for 1 stop bit).
  - `DVSR`: Baud rate divisor calculation parameter ($N = \frac{f_{\text{clk}}}{16 \times \text{Baud}}$).
  - `FIFO_W`: Buffer depth parameter ($2^B$ total storage slots).
- **Dual Circular FIFOs**: Separate parametric RX and TX buffers utilizing circular pointer math to prevent system logic stalling during burst serial transfers.

---

## Hardware System Architecture

```text
                  +-------------------------------------------------------------+
                  |                         uart.v                              |
                  |                                                             |
   rx ------------+--> [uart_rx] ---> (rx_done_tick) ---> [fifo_rx] ---> r_data |
                  |         ^                                 |                 |
                  |         | (s_tick)                        +---> rx_empty    |
                  |    [baud_gen]                                               |
                  |         | (s_tick)                        +---> tx_full     |
                  |         v                                 |                 |
   tx <-----------+--- [uart_tx] <--- (tx_start) <------- [fifo_tx] <--- w_data |
                  +-------------------------------------------------------------+
