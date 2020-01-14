"""
        take_struck_data(settings::NamedTuple)

Creates an individual `pmt_daq.scala` file and takes data which are converted to a HDF5 file afterwards.
...
# Arguments
- `settings::NamedTuple`: NamedTuple containing all settings. See Example.

# Example settings
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
...
"""
function take_struck_data(settings::NamedTuple)
    if !isdir(settings.data_dir)
        mkpath(settings.data_dir, mode = 0o777)
    end
    if !isdir(settings.conv_data_dir)
        mkpath(settings.conv_data_dir, mode = 0o777)
    end
    current_dir = pwd()
    cd(settings.data_dir)
    timestamp = create_struck_daq_file(settings)

    
    i = 1
    while i <= settings.number_of_measurements
        #chmod("./", 0o777)
        run(`./pmt_daq_dont_move.scala`);    
        i += 1
    end
    #rm("pmt_daq_"*timestamp*".scala")
    cd(current_dir)
    glob_str = settings.data_dir*"*"*settings.output_basename*"*.dat"
    convert_dset_to_h5(glob_str, 
        settings.output_basename, 
        conv_data_dir = settings.conv_data_dir,
        delete        = settings.delete_dat)
    #chmod("./", 0o777)
end