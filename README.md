# single-shot-timer
single_shot_timer using system verilog
Overiew
The single_shot_timer module generates a single, configurable-width pulse when triggered.
It features selectable pulse durations and provides status signals indicating when the timer is
active and when it completes. The module uses ready/valid handshakes for both launch
(input) and completion (output), for robust communication in ready-valid interface systems,
preventing pulse loss or overlap.
