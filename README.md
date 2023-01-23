# PENScintAnalysis.jl
[WIP] PEN Scintillation Project Signal Analysis & Data Taking 

## Update
* `PENAnalysisTools.jl` and `PENAnalysisToolsLuis.jl` have been merged to `PENScintAnalysis.jl`.
* `PENScintAnalysis.jl` and `PENBBControl.jl` have been merged. [06/2022]
* **Dark box control:** so far, the XIMC motorised stages, HV control and Struck data taking are part of the package.
* **Data analysis**: handling Struck raw data, converting to LEGEND HDF5 (read & write) 

## Table of contents
- [PENScintAnalysis.jl](#penscintanalysisjl)
  - [Update](#update)
  - [Table of contents](#table-of-contents)
  - [Required packages](#required-packages)
  - [Read data from Struck ADC](#read-data-from-struck-adc)
  - [Read "old formatted" HDF5 files](#read-old-formatted-hdf5-files)
    - [Arguments](#arguments)
    - [Example](#example)
  - [Store Struck data as HDF5](#store-struck-data-as-hdf5)
  - [Take data with the Struck ADC](#take-data-with-the-struck-adc)
    - [Arguments](#arguments-1)
    - [Example settings](#example-settings)
  - [XIMC motorised stages](#ximc-motorised-stages)
    - [Example:](#example-1)
  - [HV control](#hv-control)
  - [BB scans](#bb-scans)
    - [Arguments](#arguments-2)


## Required packages
A few packages required for `PENScintAnalysis.jl` are not registered. These can be found here:

- `https://github.com/oschulz/StruckVMEDevices.jl#SIS3316Digitizers`
- `https://github.com/oschulz/CompressedStreams.jl`

For LEGEND software, add the LEGEND Julia registry: `https://github.com/legend-exp/LegendJuliaRegistry`

Then add `LegendHDF5IO` and `LegendDataTypes`.

## Read data from Struck ADC
There are two ways to read `*.dat* files now:

- `read_data_from_struck(filename::String; just_evt_t=false)` returns `TypedTable`
- `read_raw_data(filename::String; nevents::Int=typemax(Int))` returns `DataFrame`

Both accept a single string as input or an array of strings for the file paths. In case you use the array, the function returns one TypedTable/DataFrame consisting of all data!

## Read "old formatted" HDF5 files
`read_old_h5_structure(filename::String; nevents::Int=typemax(Int), nsubfiles::Int=typemax(Int), subfiles=[])`

Reads the outdated dataformat. Outdated means **non-LegendHDF5IO compatible**. You can see what is in one of those files by using `get_h5_info_old(filename::String)`.

### Arguments
- `filename::String`: Path to *.h5 file with old formatting as a string.
- `nevents::Int`: Number of events to read in. Default: all events.
- `nsubfiles::Int`: Number of subfiles to read in. Default: all.
- `subfiles`: Array of indices of subfiles to read in. Default: empty = all.
  
### Example

```julia
filename  = "path/to/h5/file.h5"
file_info = get_h5_info_old(filename)

for i in eachindex(file_info["names"])
    data = read_old_h5_structure(filename, subfiles=[i])
    # Do analysis separate for each subfile to avoid OutOfMemory() issues
end
```


## Store Struck data as HDF5

You can directly convert `*.dat` files to `*.h5` by using:
 
 - `struck_to_h5(filename::String; conv_data_dir="../conv_data/")`
 
Or you read in the data as before and store it using `writeh5(filename::String, tt)` where `tt` is your output from `read_data_from_struck()`.

**Please note that you can't store an array of vectors/arrays in HDF5! You have to convert that array with `VectorOfArrays(ARRAY)` first.**




## Take data with the Struck ADC

Use:
- `take_struck_data(settings::NamedTuple)`

Creates an individual `pmt_daq.scala` file and takes data which are converted to a HDF5 file afterwards.

### Arguments
- `settings::NamedTuple`: NamedTuple containing all settings. See Example.

### Example settings

```julia
settings = (
    fadc = "gelab-fadc08", # Your Struck device
    output_basename = "test-measurement",
    data_dir = "../data/", # where you want to store the raw data (*.dat)
    conv_data_dir = "../conv_data/", # where you want to store the converted data (*.h5)
    measurement_time = 20,
    number_of_measurements = 5, # rather take more measurements instead of creating huge files
    channels = [1,2,3,4,5,6],
    trigger_threshold = [55], # in ADC 
    trigger_pmt = [5,6],
    peakTime = 2,
    gapTime = 2, 
    nPreTrig = 192,
    nSamples = 256,
    saveEnergy = true, # actually not implemented
    delete_dat = true # delete the raw data file after converting
) 
```


## XIMC motorised stages 

To start the connection to the motors, use `motor = mymotor()`. It will automatically save the settings needed for the motors. They will be initialized when starting the connection, but can always be intialized by calling `Initialize(motor)`. This overwrites the settings which might have changed after a power outage.

To calibrate the motors, i.e. to set the 0 to the end of the motor stage at the bottom left of the setup, the functions `CalibrateX` and `CalibrateY` are used.
For example, `CalibrateX(motor)` calibrates the X-motor. If both motors should be calibrated, call `Calibrate(motor)`.

To move the motors, the commands `XMoveMM` and `YMoveMM` are used. These functions take as arguments the position in mm and the motor.
For example `XMoveMM(15,motor)` moves the X-motor to 15mm. This function blocks the program until the final destination is reached.
To avoid the block, call the function with the keyword argument `XMoveMM(15,motor,block_till_arrival = false)`.

To get the position of the motors, call `PosX(motor)` and `PosY(motor)`. They are given in units of mm. To print it to the terminal, `Pos(motor)` can be used. Note that the value at 0 has a negative sign, as the motor stage coordinates are inverted during the conversion to mm.

### Example:
```julia
# Initialize
motor = mymotor()
Calibrate(motor)

# Get current position
pos_x = PosX(motor)
pos_y = PosY(motor)
@info(pos_x, pos_y)

# Move stage to x = 42, y = 24 in units of mm
XMoveMM(42.0,motor)
YMoveMM(24.0,motor)
```
When changing the connection of the motors to the serial hub (or using a different serial hub), please use:
```julia
device = "gelab-serialXX"
ports = [2001, 2011]
motor = mymotor(device, ports)
```

## HV control
The HV supply for the PMTs can be controlled as follows:

Define the login details to establish the connection:
```julia
login_payload = JSON.json(Dict("i"=>"", "t" => "login", "c"=> Dict("l"=>"USERNAME", "p"=>"PASSWORD", "t" => ""), "r" => "websocket"))
ip = "ws://xxx.xxx.xxx.xxx:8080"
```
Basic controls
```julia
# Get all measured voltages
get_measured_HV(ip)
# Get all set voltages (to compare set and measured)
get_set_HV(ip)
# Set voltage (value) to one channel
voltage_goto(ip, channel::Int, value::Real)
# e.g. set channel 2 to -975 V
voltage_goto(ip, 2, -975)

```




## BB scans
To start a scan with the stage you have available 3 options:
`PENBBScan2D(x_start, y_start, step_x, step_y, x_ends, y_ends, HolderName::String, time_per_point)`.

This function can used to perform an automate scan in 2D (x,y axis)
This function requires as input the starting point (x_start,y_start), and the end point (x_ends,y_ends) as well 
as the step sizes in both axis(step_x,step_y). All values are in mm. The range specified muss be in the interval `x in [0.0,100.0]`, `y in [0.0,100.0]`
In addition you can specify the name of the holder or sample and time of data taking for each position
PENBBScan2D(x_start, y_start, step_x, step_y, x_ends, y_ends, HolderName::String, time_per_point).

Example: `PENBBScan2D(0.0,0.0,20.0,20.0,40.0,40.0,"small",2)` will do a scan in the rectangle x: 0.0->40 mm; y: 0.0 -> 40 mm with steps of 20. mm in each direction


### Arguments
- `x_start`: intial point in x
- `y_start`: intial point in y
- `step_x`: step size in x
- `step_y`: step size in y
- `x_ends`: final point in x
- `y_ends`: final point in y
- `HolderName::String`: name of the holder of piece you are scanning 
- `time_per_point`: time of data taking in each point.

The next funtions will do a 1D scan.
```julia
PENBBScan1DY(x_start, y_start, step_y, y_ends, HolderName::String, time_per_point)
PENBBScan1DX(y_start, x_start, step_x, x_ends, HolderName::String, time_per_point)
```
