using Dates

"""
        take_struck_data(settings::NamedTuple)

Creates an individual `pmt_daq.scala` file and takes data which are converted to a HDF5 file afterwards.
If callback is a function, it will be executed with the data of each taken measurement
stop_taking is a function that will be called before any iteration. If it returns true, all remaining data_taking will be skipped. Note that data processing may still take place.
...
# Arguments
- `settings::NamedTuple`: NamedTuple containing all settings. See Example.

# Example settings
- `settings = (fadc = "gelab-fadc08",` 
`output_basename = "test-measurement",`
`data_dir = "./data/",`
`conv_data_dir = "./conv_data/",`
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
`coincidence_interval = 4e-9,`
`skip_post_processing = false`
`) `
...
"""
function take_struck_data(settings::NamedTuple; calibration_data::Bool=false, callback=false, stop_taking = ()->false)
    @info("Updated: 2023-02-23")
    !isdir(settings.data_dir) ? mkpath(settings.data_dir, mode = 0o775) : "Path exists"
    
    !isdir(settings.conv_data_dir) ? mkpath(settings.conv_data_dir, mode = 0o775) : "Path exists"

    if !calibration_data
        if typeof(settings.trigger_pmt) != Int64 || typeof(settings.trigger_threshold) != Int64
            error("The settings for 'trigger_pmt' and 'trigger_threshold' should not be an array for non-calibration measurements.")
            return 
        end
    #else
     #   settings.filter_faulty_events = false
    end
    
    # Get current working directory and normalized paths of data+conv_data dirs
    original_dir = pwd()
    data_dir = normpath(original_dir, settings.data_dir)
    conv_data_dir = normpath(original_dir, settings.conv_data_dir)

    cd(data_dir)
    create_struck_daq_file(settings, calibration_measurement=calibration_data)
    
    t_check = stat("pmt_daq_dont_move.scala").mtime
    #p = ProgressMeter.Progress(settings.number_of_measurements, 1, "Measurement ongoing...", 50)
    chmod(pwd(), 0o775, recursive=true)
    
    new_files = []
    i = 1

    while i <= settings.number_of_measurements && !stop_taking()
        # Total tries: 3
        n_try = 0
        while n_try <= 2
            @info "Chunk " * string(i) * " - Receiving (Try " * string(n_try + 1) * "/3)"

            # Maximum time we expect the script to run: 1.5*measurement_time; after that, throw exception
            t_start = now()
            process = run(`./pmt_daq_dont_move.scala`, wait=false)
            while (now() - t_start).value < 1.5*1000*settings.measurement_time
                if process_exited(process)
                    break
                end
                sleep(0.5)
            end

            # If process finised within time, no retries neccessary
            if process_running(process)
                @warn "Process timeout. " * ((n_try <= 2) ? "Trying again" : "Stopping. See below error message")
                kill(process)
                
                n_try += 1
            else
                break
            end
        end

        # n_try = 4 => previous 3 tries failed
        if n_try == 3
            rm("pmt_daq_dont_move.scala")
            cd(original_dir)

            @error "Process timed out"
            throw(ErrorException("Measurement failed. Make sure the fadc is running, you're running the code within the legend(-base) container on glab-pc01 and correct permissions are set on the directory. If you can ping the struck and think everything is set up correctly, do a test using struck-test-gui. Execute that on a Linux host with Desktop functionality connecting via ssh -X gelab@gelab-pc.. and check connection as well as Test in the sub-menu. This helps to spin up a Struck if a restart alone did not help"))            
        end

        # Update list of new files after each measurement for callback usage
        files = Glob.glob(joinpath(settings.output_basename * "*.dat"))

        # Assumption: Only one file will be added per execution. Otherwise we'd have to sort files by file_change_time and get all items with file_change_time > t_check
        j = 1
        new_file = ""
        while j <= length(files)
            file_change_time = stat(files[j]).mtime
            if file_change_time - t_check > 0
                new_file = files[j]
                push!(new_files, new_file)
                @info "Chunk " * string(i) * " - Received (" * new_file * ")"
                t_check = file_change_time
                break
            end
            j += 1
        end

        if callback != false
            @info "Received chunk " * new_file
            data = read_data_from_struck(new_file, filter_faulty_events=settings.filter_faulty_events, coincidence_interval = settings.coincidence_interval)
            callback(data)
        end

        i = i + 1
    end

    #chmod(pwd(), 0o775, recursive=true)
    rm("pmt_daq_dont_move.scala")
    
    if !settings.skip_post_processing
        @info "Doing analysis"
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
                    @info "Found file " * string(h5size)
                    push!(compress, i)
                    i += 1
                end
            end
            push!(h5files, compress)
        end

        print(h5files)

        @info "Conversion"

        print(new_files)

        i = 1
        p = ProgressMeter.Progress(length(h5files), 1, "Converting "*string(length(new_files))*" files to "*string(length(h5files))*" HDF5...", 50)
        while i <= length(h5files)
            data = read_data_from_struck(new_files[h5files[i]], filter_faulty_events=settings.filter_faulty_events, coincidence_interval = settings.coincidence_interval)
            if calibration_data
                writeh5(joinpath(conv_data_dir, "calibration-data_" * split(basename(new_files[h5files[i][1]]), ".dat")[1] * ".h5"), data)
            else
                writeh5(joinpath(conv_data_dir, split(basename(new_files[h5files[i][1]]), ".dat")[1] * ".h5"), data)
            end
            
            ProgressMeter.next!(p)
            i += 1
        end
    end

    if settings.delete_dat
        i = 1
        while i <= length(new_files)
             rm(new_files[i])
             i += 1
        end
    end
    
    cd(original_dir)
end
export take_struck_data
