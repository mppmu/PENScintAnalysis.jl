# PENScintAnalysis.jl
[WIP] PEN Scintillation Project Signal Analysis
## Update
`PENAnalysisTools.jl` and `PENAnalysisToolsLuis.jl` have been merged to `PENScintAnalysis.jl`

## Read data from Struck ADC
There are two ways to read `*.dat* files now:

- `read_data_from_struck(filename::String; filter_faulty_events=false, coincidence_interval = 4e-9)` returns `TypedTable`
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


## Store data as HDF5

You can directly convert `*.dat` files to `*.h5` by using:
 
 - `struck_to_h5(filename::String; conv_data_dir="../conv_data/")`
 
Or you read in the data as before and store it using `writeh5(filename::String, typed_table)` where `typed_table` is your output from `read_data_from_struck()`.

**Please note that you can't store an array of vectors/arrays in HDF5! You have to convert that array with `VectorOfArrays(ARRAY)` first.**

### Example

```julia
filename  = "path/to/h5/file.h5"
file_info = get_h5_info_old(filename)
i     = 1
i_max = length(file_info["names"])

while i <= i_max
    data = read_old_h5_structure(filename, subfiles=[i])
    # Do analysis separate for each subfile to avoid OutOfMemory() issues
    i += 1
end
```



## Take data with the Struck ADC

Use:
- `take_struck_data(settings::NamedTuple)`

Creates an individual `pmt_daq.scala` file and takes data which are converted to a HDF5 file afterwards.

### Arguments
- `settings::NamedTuple`: NamedTuple containing all settings. See Example.

### Example settings

```julia
settings = (fadc = "gelab-fadc08",
output_basename = "test-measurement",
data_dir = "../data/",
conv_data_dir = "../conv_data/",
measurement_time = 20,
number_of_measurements = 5,
channels = [1,2,3,4,5,6],
trigger_threshold = [55],
trigger_pmt = [5,6],
peakTime = 2,
gapTime = 2, 
nPreTrig = 192,
nSamples = 256,
saveEnergy = true,
delete_dat = true,
h5_filesize_limit = 200,
filter_faulty_events = true,
coincidence_interval = 4e-9
) 
```
