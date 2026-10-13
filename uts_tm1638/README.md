# oss-cad-suite-tcl-template by ABJ
A template project to synthesys, place & route and generate bitstream.
The environment is set for running on Windows and ICESugar FPGA board.

# pre-requisites
Edit file setenv.bat following your local drive

# how to run
1. Setup environment for OSS CAD Suite <br />
**$ setenv.bat**

2. Create project, synthesis, place & route and generate bitsteram <br />
	option 1: <br />
	**$ make syn** <br />
	**$ make pnr** <br />
  **$ make bit** <br />
	
	option 2: <br />
	**$ make all** <br />

3. Load bitstream to FPGA board <br />
**$ make flash**

4. Clean build directory including project files <br />
**$ make clean**

5. To run simulation <br />

	option 1: <br />
	**$ make compile** <br />
	**$ make vvp** <br />
  **$ make gtk** <br />
	
	option 2: <br />
	**$ make sim** <br />

