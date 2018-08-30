import uvm_pkg::*;
`include "uvm_macros.svh"
`include "dut.v"


//interface
interface my_interface(input clk, input rst);
	logic mode;
	
	logic [7:0] input_a;
	logic [7:0] input_b;
	
	logic [7:0] output_;
	
	//clocking cb(posedge clk)
	
	//endclocking;
	
endinterface;

class my_seq_item extends uvm_sequence_item;

	rand bit mode;
	rand bit [7:0] input_a;
	rand bit [7:0] input_b;
	
	bit [7:0] output_;
	
	//constraint or not
	constraint c1 {input_a < 120; 
				   input_a > 110;
				   input_b < 50;
                   input_b > 17;};
	
	`uvm_object_utils_begin(my_seq_item)
  		`uvm_field_int(mode, UVM_ALL_ON)
		`uvm_field_int(input_a, UVM_ALL_ON)
		`uvm_field_int(input_b, UVM_ALL_ON)
		`uvm_field_int(output_, UVM_ALL_ON)
	`uvm_object_utils_end
	
	function new(string name = "my_seq_item");
		super.new(name);
	endfunction:new

	
endclass: my_seq_item

//sqr
class my_sequencer extends uvm_sequencer#(my_seq_item);

	`uvm_component_utils(my_sequencer)

	//constructor
	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

endclass: my_sequencer

//my_sq
class my_sequence extends uvm_sequence#(my_seq_item);

	`uvm_object_utils(my_sequence)
	
	function new(string name = "my_sequence");
		super.new(name);
	endfunction: new
	
	`uvm_declare_p_sequencer(my_sequencer)
	
	virtual task body();
		repeat(3) begin //same as `uvm_do() function
			req = my_seq_item::type_id::create("req");
			
			//wait for driver giving unlock
			wait_for_grant();
			
			//randomly generate the transaction
			req.randomize();
			
			//send request to the driver
			send_request(req);
			
			//wait for driver finished
			wait_for_item_done();
				
		end	
	endtask: body

endclass: my_sequence

//monitor 
class my_monitor extends uvm_monitor;
	
	//virtual interface
	virtual my_interface my_if;
	
	//send transaction to the scoreboard
	uvm_analysis_port#(my_seq_item) item_collected_port;
	
	//holf transacation currently
	//collect_address_phase and data_phase
	my_seq_item trans_collected;
	
	`uvm_component_utils(my_monitor)
	
	function new(string name, uvm_component parent);
		super.new(name, parent);
		item_collected_port = new("item_collected_port", this);
		trans_collected = new();
	endfunction: new
	
	//build_phase
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
      if(!uvm_config_db#(virtual my_interface)::get(this, "", "my_if", my_if))
			`uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".my_if"});
	endfunction: build_phase
	
	//run phase: convert signal level activity to transaction level
	//interface signal assigns to transaction class fields
	
	virtual task run_phase(uvm_phase phase);
		forever begin
			@(posedge my_if.clk);
				trans_collected.input_a = my_if.input_a;
				trans_collected.input_b = my_if.input_b;
				trans_collected.mode = my_if.mode;
			@(posedge my_if.clk);
				trans_collected.output_ = my_if.output_;
		end
		item_collected_port.write(trans_collected);
	endtask: run_phase
	
endclass: my_monitor

//driver
class my_driver extends uvm_driver#(my_seq_item);
	
	virtual my_interface my_if;
	`uvm_component_utils(my_driver)
	
	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction: new
	
	
	function void build_phase(uvm_phase phase);
	  super.build_phase(phase);
		
      if(!uvm_config_db#(virtual my_interface)::get(this, "", "my_if", my_if))
          `uvm_fatal("NO_VIF", {"virtual interface must be set for: ", get_full_name(), ".my_if"}); 
	endfunction: build_phase
	
	//run phase
  virtual task run_phase(uvm_phase phase);
		forever begin
			//get next item from sequencer
			seq_item_port.get_next_item(req);
			//run the drive function to drive
			drive();
			//tell the sequencer drive finish
			seq_item_port.item_done();
		end
	endtask: run_phase
	
	virtual task drive();
		//drive the vif
		my_if.input_a <= 8'b00000000;
		my_if.input_b <= 8'b00000000;
		my_if.mode <= 1'b1;
		
		@(posedge my_if.clk)
			my_if.input_a <= req.input_a;
			my_if.input_b <= req.input_b;
			my_if.mode <= req.mode;
      	$display("my_if: a: %0d, b: %0d, mode: %0d", my_if.input_a, my_if.input_b, my_if.mode);
      	$display("req: a: %0d, b: %0d, mode: %0d", req.input_a, req.input_b, req.mode);
		
	endtask: drive
	
endclass: my_driver
//https://sistenix.com/basic_uvm.html

//agent
class my_agent extends uvm_agent;
	
	my_driver driver;
	my_sequencer sequencer;
	my_monitor monitor;	
	
	`uvm_component_utils(my_agent)
	
	//constructor
	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction: new
	
	function void build_phase(uvm_phase phase);
      super.build_phase(phase);
		
		monitor = my_monitor::type_id::create("my_monitor", this);
		if(get_is_active() == UVM_ACTIVE) begin
			driver = my_driver::type_id::create("driver", this);
          sequencer = my_sequencer::type_id::create("sequencer", this);
		end
	endfunction: build_phase
	
	//connect driver and sequencer port
	function void connect_phase(uvm_phase phase);
		if(get_is_active() == UVM_ACTIVE)
			driver.seq_item_port.connect(sequencer.seq_item_export);
	endfunction: connect_phase
	
endclass: my_agent

//scb
class my_scoreboard extends uvm_scoreboard;
	//store the 
	my_seq_item pkt_qu[$];
	
	//scorboard
	//ref model
	
	//port to get data pkt from monitor
	uvm_analysis_imp#(my_seq_item, my_scoreboard) item_collected_export;
	
	`uvm_component_utils(my_scoreboard)

	//new -- constructor
  function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction: new
	
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		item_collected_export = new("item_collected_export", this);
		//initialize the ref model
	endfunction: build_phase
	
	//write back, obtain the pkt and push them into queue
	virtual function write(my_seq_item pkt);
		pkt.print();
		pkt_qu.push_back(pkt);
	endfunction: write
	
	virtual task run_phase(uvm_phase phase);
		my_seq_item my_pkt;
		
		forever begin
			wait(pkt_qu.size() > 0);
			my_pkt = pkt_qu.pop_front();
			
			//
			////compare the ref model here
			//
			my_pkt.print();
		end
	endtask: run_phase
	
endclass: my_scoreboard

//env class
class my_env extends uvm_env;
	
	//agent, scb instance
	my_agent my_agt;
	my_scoreboard my_scb;
  
    `uvm_component_utils(my_env)
	
	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction: new
	
	//build, phase, create component
	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		
		my_agt = my_agent::type_id::create("my_agt", this);
		my_scb = my_scoreboard::type_id::create("my_scb", this);
	endfunction: build_phase
	
	function void connect_phase(uvm_phase phase);
		my_agt.monitor.item_collected_port.connect(my_scb.item_collected_export);
	endfunction: connect_phase

endclass: my_env

class my_test extends uvm_test;

    `uvm_component_utils(my_test)

    //---------------------------------------
    // env instance 
    //--------------------------------------- 
    my_env env;

    //---------------------------------------
    // constructor
    //---------------------------------------
    function new(string name = "my_test",uvm_component parent=null);
      super.new(name,parent);
    endfunction : new

    //---------------------------------------
    // build_phase
    //---------------------------------------
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      // Create the env
      env = my_env::type_id::create("env", this);
    endfunction : build_phase

    virtual function void end_of_elaboration();
      //print's the topology
      print();
    endfunction

    //---------------------------------------
    // end_of_elobaration phase
    //---------------------------------------   
 function void report_phase(uvm_phase phase);
   uvm_report_server svr;
   super.report_phase(phase);
   
   svr = uvm_report_server::get_server();
   if(svr.get_severity_count(UVM_FATAL)+svr.get_severity_count(UVM_ERROR)>0) begin
     `uvm_info(get_type_name(), "---------------------------------------", UVM_NONE)
     `uvm_info(get_type_name(), "----            TEST FAIL          ----", UVM_NONE)
     `uvm_info(get_type_name(), "---------------------------------------", UVM_NONE)
    end
    else begin
     `uvm_info(get_type_name(), "---------------------------------------", UVM_NONE)
     `uvm_info(get_type_name(), "----           TEST PASS           ----", UVM_NONE)
     `uvm_info(get_type_name(), "---------------------------------------", UVM_NONE)
    end
  endfunction 

endclass : my_test

//top
module top();

    bit clk;
    bit reset;


    always #5 clk = ~clk;

    initial begin
      reset = 1;
      #5 reset =0;
    end


    //interface instance
    my_interface my_if(clk, reset);

    //DUT instance
    dut DUT (
      .clk(my_if.clk),
      .rst(my_if.rst),
      .mode(my_if.mode),
      .input_a(my_if.input_a),
      .input_b(my_if.input_b),
      .output_(my_if.output_)
    );

    initial begin 
      uvm_config_db#(virtual my_interface)::set(uvm_root::get(),"*","my_if",my_if);
      //enable wave dump
      //$dumpfile("dump.vcd"); 
      //$dumpvars;
    end

    initial begin 
      run_test("my_test");
      #1000 $stop;
    end
  
endmodule
