`timescale 1ns/1ns
module tb;

  // match the DUT's width
  localparam int width = 9;

  // DUT signals 
  logic clk, rst_n, fire_valid;
  logic [1:0] mode;
  logic  pulse_out_dut, busy_dut, done_dut, fire_ready_dut;
  logic [width-1:0]  timer_dut;

  //  Reference model signals 
  typedef enum logic { IDLE, EXECUTE } state_t;

  state_t  ref_state, ref_next_state;
  logic [width-1:0]  ref_counter, ref_pulse_duration;
  logic  ref_pulse_out, ref_busy, ref_done, ref_fire_ready;
  logic [width-1:0]  ref_timer;

  
  // DUT instantiation
  single_shot_timer  dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .fire_valid (fire_valid),
    .mode       (mode),
    .pulse_out  (pulse_out_dut),
    .busy       (busy_dut),
    .done       (done_dut),
    .fire_ready (fire_ready_dut),
    .timer      (timer_dut)
  );

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);
  end

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n      = 0;
    fire_valid = 0;
    ref_reset();                
    #20 rst_n = 1;
  end

  
  // Fire_valid generator
  initial begin
    fire_valid = 0;
   // @(posedge rst_n);
     wait(rst_n);

    fire_valid = 1;

    forever begin
      @(posedge clk);
      if (fire_ready_dut) begin
        fire_valid <= 0;         // drop for exactly one cycle
        @(posedge clk);
        fire_valid <= 1;
      end
    end
  end

  
  
  
  
  
  
  // Mode generator
  initial begin
 // @(posedge rst_n);
    wait(rst_n);

  mode = 2'b00;  // << fixed mode (always the same)
  $display("T=%0t: Selected fixed mode %0b", $time, mode);

  forever begin
    @(posedge done_dut);   // wait for exact cycle done is asserted
    #40;                   // gap before next fire
    // no new mode assignment, it stays 2'b00
  end
end
    
    
    
    
    
    
  // Reference model
  function automatic void ref_reset();
    ref_state        = IDLE;
    ref_next_state   = IDLE;
    ref_counter      = '0;
    ref_pulse_duration = '0;
    ref_busy         = 1'b0;
    ref_fire_ready   = 1'b1;
    ref_pulse_out    = 1'b0;
    ref_done         = 1'b0;
    ref_timer        = '0;
  endfunction

  function automatic logic [width-1:0] ref_duration(input logic [1:0] m);
    case (m)
      2'b00: return 32;
      2'b01: return 64;
      2'b10: return 128;
      2'b11: return 256;
      default: return 32;
    endcase
  endfunction

  function automatic void ref_run(
    input  logic clk_i,
    input  logic rstn_i,
    input  logic fire_valid_i,
    input  logic [1:0] mode_i
  );
    // defaults for the current cycle
    ref_fire_ready = (ref_state == IDLE);
    ref_busy = (ref_state == EXECUTE);
    ref_pulse_out  = (ref_state == EXECUTE);
    ref_done = (ref_state == EXECUTE && ref_counter == 0);
    ref_timer  = ref_counter;
    ref_next_state = ref_state;
    
    
    
    if (!rstn_i) begin
        ref_reset();
        return;
    end

    unique case (ref_state)
      IDLE: begin
        if (fire_valid_i && ref_fire_ready) begin
          ref_next_state  = EXECUTE;
          ref_pulse_duration = ref_duration(mode_i);
          ref_counter  = ref_pulse_duration ;
          $display("REF: Trigger @%0t mode=%b duration=%0d", $time, mode_i, ref_pulse_duration);
        end
      end

      EXECUTE: begin
        if (ref_counter > 0) begin
          ref_counter = ref_counter-1;
        end

        // EXACT cycle the counter reaches 0:
        if (ref_counter == 0) begin
          ref_done       = 1'b1;     // pulse 'done' this cycle
          ref_busy       = 1'b0;
          ref_pulse_out  = 1'b0;
          ref_fire_ready = 1'b1;
          ref_next_state = IDLE;
        end
      end
    endcase

    
  // ref_timer = ref_counter ;

    // update state for next cycle
    ref_state = ref_next_state;
  endfunction


  
  initial begin
 // @(posedge rst_n);
    wait(rst_n);
    $display("Starting test...");

    for (int i = 0; i < 33; i++) begin
     @(posedge clk);
      ref_run(clk, rst_n, fire_valid, mode);
     // @(posedge clk);

      // optional trace
      $display("cycle %0d | DUT  busy=%0b done=%0b ready=%0b pulse=%0b timer=%0d  ||  REF busy=%0b done=%0b ready=%0b pulse=%0b timer=%0d",
               i,  busy_dut, done_dut, fire_ready_dut, pulse_out_dut, timer_dut,
                       ref_busy, ref_done, ref_fire_ready, ref_pulse_out, ref_timer);

      if (!ref_check(pulse_out_dut, busy_dut, done_dut, fire_ready_dut, timer_dut)) begin
        $error("Mismatch detected at T=%0t", $time);
      end
    end

    $display("Test completed.");
    repeat (10) @(posedge clk); 
    $finish;
  end

  // checker function
  function automatic bit ref_check(
    input logic             pulse_out_i,
    input logic             busy_i,
    input logic             done_i,
    input logic             fire_ready_i,
    input logic [width-1:0] timer_i
  );
    bit ok = 1;

    if (busy_i       !== ref_busy      )
      begin $display("BUSY  mismatch: DUT=%0b REF=%0b @%0t", busy_i,       ref_busy,       $time);
        ok = 0; end
    
    if (pulse_out_i  !== ref_pulse_out )
      begin $display("PULSE mismatch: DUT=%0b REF=%0b @%0t", pulse_out_i,  ref_pulse_out,  $time);
        ok = 0; end
    if (done_i       !== ref_done      )
      begin $display("DONE  mismatch: DUT=%0b REF=%0b @%0t", done_i,       ref_done,       $time); 
        ok = 0; end
    if (fire_ready_i !== ref_fire_ready) 
      begin $display("READY mismatch: DUT=%0b REF=%0b @%0t", fire_ready_i, ref_fire_ready, $time);
        ok = 0; end
    if (timer_i      !== ref_timer     )
      begin $display("TIMER mismatch: DUT=%0d REF=%0d @%0t", timer_i,      ref_timer,      $time); 
        ok = 0; end

    return ok;
  endfunction

  
  
endmodule
