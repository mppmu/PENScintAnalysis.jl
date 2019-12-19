# PENScintAnalysis.jl
[WIP] PEN Scintillation Project Signal Analysis


# UPDATE
PENAnalysisTools and PENScintAnalysis have now been merged, also including functions from Luis fork.

# Take data with struck

Use this function, it will create a local *.scala file and execute it.

`take_struck_data(settings::NamedTuple)`

Creates an individual `pmt_daq.scala` file and takes data which are converted to a HDF5 file afterwards.
...
### Arguments
- `settings::NamedTuple`: NamedTuple containing all settings.

### Example settings
- `settings = (fadc = "gelab-fadc08",` 
`output_basename = "test-measurement",`
`data_dir = "../data/",`
`conv_data_dir = "../conv_data/",`
`measurement_time = 20,`
`number_of_measurements = 5,`
`channels = [1,2,3,4,5,6],`
`trigger_threshold = [55],`
`trigger_pmt = [5,6],`
`peakTime = 2,`
`gapTime = 2, `
`nPreTrig = 192,`
`nSamples = 256,`
`saveEnergy = true,`
`delete_dat = true`
`) `

# Read data from struck

There are now two ways to read data from *.dat files: 
- `read_raw_data(filename::String; nevents::Int=typemax(Int))` will return a DataFrame
- `read_data_from_struck(filename::String; just_evt_t=false)` will return a TypedTable

Both take as argument `filename::String` or an array of filenames. In case of an array, it will return one DataFrame/TypedTable containing all data.

# Store data

The TypedTable can be stored directly to an HDF5 file and read in using:

- `writeh5(filename::String, typed_table)`
- `readh5(filename::String)`

Please note: When storing e.g. an array of pulses use: `VectorOfArrays(YOUR_ARRAY_OF_PULSES)` 

You can also convert directly from *.dat to *.h5 using:

- `struck_to_h5(filename::String; conv_data_dir="../conv_data/")`

Again, you can also put an array of filenames in here. But think about the filesize!

