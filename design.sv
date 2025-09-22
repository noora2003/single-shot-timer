typedef enum {
  IDLE,
  EXECUTE  
} state_t;

parameter width = 9;

module single_shot_timer (
  input logic clk, rst_n, fire_valid,
  input logic [1:0] mode, 
  output logic pulse_out, busy, done, fire_ready,
  output logic [width-1:0] timer
);
  
  logic [width-1:0] pulse_duration,counter;
  
  state_t state, nxt_state;
  
  // Selects the duration of the output pulse 
  always_comb begin
    case (mode)
      2'b00 : pulse_duration = 32;
      2'b01 : pulse_duration = 64;
      2'b10 : pulse_duration = 128;
      2'b11 : pulse_duration = 256;    
      default: pulse_duration = 32;
    endcase
  end
  
  
 // assign counter_done = (counter == '0);
  assign fire_ready = (state == IDLE);
  assign timer = counter;
  

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= '0;
      done <= 1'b0;
      busy <= 1'b0;
      pulse_out <= 1'b0;
      
    end else begin
      state <= nxt_state;

      if (state == IDLE && nxt_state == EXECUTE) begin
        counter <= pulse_duration;
      end else if (state == EXECUTE && counter !==0) begin
        counter <= counter - 1'b1;
      end else if (state == EXECUTE && counter == 0) begin
        counter <= 0; // Keep at 0 when done
      end

      busy <= (nxt_state == EXECUTE);
      pulse_out <= (nxt_state == EXECUTE);
    //  done <= (counter == 1) && (state == EXECUTE);
      done <= (state == EXECUTE && counter == 0 && nxt_state == IDLE);
    
      
    end
  end
  
 

  // Next state logic
  always_comb begin
    nxt_state = state;
    
    case (state)
      IDLE: begin
        if (fire_valid && fire_ready) begin
          nxt_state = EXECUTE;
        end
      end
      
      EXECUTE: begin
        if (counter == 0) begin
          nxt_state = IDLE;
        end
      end
      
      default: nxt_state = IDLE;
    endcase
  end
  
endmodule
