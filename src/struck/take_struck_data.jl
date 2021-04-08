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
`trigger_threshold = 55,`
`trigger_pmt = 5,`
`peakTime = 2,`
`gapTime = 2, `
`nPreTrig = 192,`
`nSamples = 256,`
`saveEnergy = true,`
`delete_dat = true,`
`h5_filesize_limit = 200,`
`filter_faulty_events = true,`
`coincidence_interval = 4e-9`
`) `
...
"""
function take_struck_data(settings::NamedTuple; calibration_data::Bool=false)
    @info("Updated: 2021-03-30 15:12")
    !isdir(settings.data_dir) ? mkpath(settings.data_dir, mode = 0o777) : "Path exists"
    
    !isdir(settings.conv_data_dir) ? mkpath(settings.conv_data_dir, mode = 0o777) : "Path exists"

    if !calibration_data
        if typeof(settings.trigger_pmt) != Int64 || typeof(settings.trigger_threshold) != Int64
            error("The settings for 'trigger_pmt' and 'trigger_threshold' should not be an array for non-calibration measurements.")
            return 
        end
    #else
     #   settings.filter_faulty_events = false
    end
    
    current_dir = pwd()
    cd(settings.data_dir)
    create_struck_daq_file(settings, calibration_measurement=calibration_data)
    
    t_start = stat("pmt_daq_dont_move.scala").mtime
    p = Progress(settings.number_of_measurements, 1, "Measurement ongoing...", 50)
    chmod(pwd(), 0o777, recursive=true)
    i = 1
    
    while i <= settings.number_of_measurements
        #chmod("./", 0o777)
        @suppress run(`./pmt_daq_dont_move.scala`);
        next!(p)
        i += 1
    end
    #chmod(pwd(), 0o777, recursive=true)
    rm("pmt_daq_dont_move.scala")
    cd(current_dir)
    files = glob(joinpath(settings.data_dir, settings.output_basename * "*.dat"))
    new_files = []
    i = 1
    while i <= length(files)
        if stat(files[i]).mtime - t_start > 0
            push!(new_files, files[i])
        end
        i += 1
    end
    
    limit   = settings.h5_filesize_limit
    h5size  = 0
    h5files = []
    i = 1
    while i <= length(new_files)
        compress = [i]
        h5size   = stat(new_files[i]).size/1024^2
         i += 1
        if i <= length(new_files)
            while h5size <= limit && i <= length(new_files)
                h5size += stat(new_files[i]).size/1024^2
                push!(compress, i)
                i += 1
            end
        end
        push!(h5files, compress)
    end
    i = 1
    p = Progress(length(h5files), 1, "Converting "*string(length(new_files))*" files to "*string(length(h5files))*" HDF5...", 50)
    while i <= length(h5files)
        data = read_data_from_struck(new_files[h5files[i]], filter_faulty_events=settings.filter_faulty_events, coincidence_interval = settings.coincidence_interval)
        if calibration_data
            writeh5(joinpath(settings.conv_data_dir, "calibration-data_" * split(basename(new_files[h5files[i][1]]), ".dat")[1] * ".h5"), data)
        else
            writeh5(joinpath(settings.conv_data_dir, split(basename(new_files[h5files[i][1]]), ".dat")[1] * ".h5"), data)
        end
        
        next!(p)
        i += 1
    end
    if settings.delete_dat
        i = 1
        while i <= length(new_files)
             rm(new_files[i])
             i += 1
        end
    end
    
    # cd(current_dir)
end
