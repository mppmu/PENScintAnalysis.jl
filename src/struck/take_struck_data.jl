using Dates

"""
        PMT_MEASUREMENT_STATES

Enumerations of states when using take_pmt_data and take_struck_data
"""
@enum PMT_MEASUREMENT_STATES begin
    STATE_IDLE = 0
    STATE_HV_RAMP_UP = 1
    STATE_HV_RAMP_DOWN = 2
    STATE_PART_STARTED = 3
    STATE_PART_FAILED = 4
    STATE_PART_DONE = 5
    STATE_DONE = 6
    STATE_FAILED = 7
end
export PMT_MEASUREMENT_STATES

"""
        measurement_state

Representation of a new measurement state with status information and the received data for MEAS_PART_DONE and MEAS_DONE states
...
# Properties
- status (code), see PMT_MEASUREMENT_STATES
- message, a string
- data, nothing or a TypedTables.Table
"""
mutable struct measurement_state
    status::Int64
    message::String
    data::TypedTables.Table
    opt # optional data, potentially undefined
    
    function measurement_state(status::Int64, message::String)
        ms = new()
        ms.status = status
        ms.message = message
        
        ms
    end
end
export measurement_state

# Modify measurement_state.data to return nothing when data is left undefined after initialization
function Base.getproperty(ms::measurement_state, s::Symbol)
    if s == :data
        if isdefined(ms, :data)
            return ms.data
        else
            return nothing
        end
    else
        error("unknown property $s")
    end
end


"""
        take_struck_data(settings::NamedTuple)

Creates an individual `pmt_daq.scala` file and takes data which are converted to a HDF5 file afterwards.
If callback is a function, it will be executed with the data of each taken measurement
stop_taking is a function that will be called beforeF any iteration. If it returns true, all remaining data_taking will be skipped. Note that data processing may still take place.
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
`coincidence_interval = 4e-9,`
`skip_post_processing = false`
`) `
...
"""
function take_struck_data(settings::NamedTuple; calibration_data::Bool=false, callback=false, stop_taking = ()->false, mode_debug=false)
    @info("Updated: 2023-03-27")
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
    
    t_start = stat("pmt_daq_dont_move.scala").mtime
    #p = ProgressMeter.Progress(settings.number_of_measurements, 1, "Measurement ongoing...", 50)
    chmod(pwd(), 0o775, recursive=true)
    
    new_files = String[]
    i = 1

    # Following strings allow us to identify different states of the measurement proccess, e.g. timeouts (script does not finish, Struck not responding) and faulty .dat files (originating from UDP network errors)
    # example error: 
    struck_init_err_string = "Futures timed out after [5000 milliseconds]" 
    
    # example error: 16:44:04.0607 [DEBUG] [daqcore-akka.actor.default-dispatcher-20] d.d.SIS3316$SIS3316Impl: Trying again to read 0x00001f48 bytes of event data from bank 1, channel 4, starting at 0x00000000, try no 2
    struck_net_err_string = "try no 2" # does this actually help?

    struck_connected_string = "Successfully connected to"

    # Status flags that reflect the erros we can identify
    struck_init_err_detected = false
    struck_net_err_detected = false
    struck_timeout_detected = false

    # Status flag to check if we could reach the Struck
    struck_reached = false

    max_tries = 10

    while i <= settings.number_of_measurements && !stop_taking()
        # Total tries: max_tries
        n_try = 1
        filename = ""

        while n_try <= max_tries && filename == "" && !stop_taking()
            struck_reached = false

            @info "Measurement " * string(i) * "/" * string(settings.number_of_measurements) * " - Receiving (Try " * string(n_try) * "/10)"

            if callback isa Function
                ms = measurement_state(STATE_PART_STARTED, "Started data-taking")
                ms.opt = (struck_reached, i, n_try, settings.number_of_measurements, max_tries)
                callback(ms)
            end

            # Maximum time we expect the script to run: 1.5*measurement_time; after that, throw exception
            t_start = now(UTC)
            
            p_stdout = IOBuffer()

            cmd = pipeline(`./pmt_daq_dont_move.scala`; stdout=p_stdout)
            process = run(cmd, wait=false)

            # Check if the process finishes/errors during timeout interval
            while (now(UTC) - t_start).value < 1.5*1000*settings.measurement_time
                p_out = String(take!(p_stdout))

                # With debugging on, show process output
                if mode_debug
                    @info "Process output"
                    @info p_out
                end

                struck_init_err_detected = occursin(struck_init_err_string, p_out)
                struck_net_err_detected = occursin(struck_net_err_string, p_out)

                if occursin(struck_connected_string, p_out)
                    @info "Connected to ADC"
                    struck_reached = true
                end
		
                if process_exited(process) || struck_init_err_detected || struck_net_err_detected
                    err_string = ""
                    
                    if struck_init_err_detected
                        err_string = "Error A1: Timeout after 5000ms"
                    elseif struck_net_err_detected
                        err_string = "Error A2: Network recover error"
                    end

                    @warn err_string

                    if callback isa Function
                        ms = measurement_state(STATE_PART_FAILED, err_string)
                        ms.opt = (struck_reached, i, n_try, settings.number_of_measurements, max_tries)
                        callback(ms)
                    end
                    
                    break
                end
                sleep(1)
            end

            sleep(3)

            # Get potentially created files
            files = Glob.glob(joinpath(settings.output_basename * "*.dat"))

            struck_timeout_detected = process_running(process)

            # If process finished within time, no retries neccessary
            if struck_timeout_detected
                if !struck_init_err_detected && !struck_net_err_detected
                    err_string = "Error A5: Timeout (other, unspecified)"
                    @warn err_string * ". Struck data taking process running longer than allowed. Use mode_debug=true to identify the cause"

                    if callback isa Function
                        ms = measurement_state(STATE_PART_FAILED, err_string)
                        ms.opt = (struck_reached, i, n_try, settings.number_of_measurements, max_tries)
                        callback(ms)
                    end
                end
                @warn "Killing still running measurement. " * ((n_try <= max_tries) ? "Trying again" : "Stopping")

                # maybe instead just a sleep(1)?
                while process_running(process)
                    kill(process)
                    sleep(1)
                end

                # Delete files which might have been created in the mean-time
                j = 1
                while j <= length(files)
                    file_change_time = unix2datetime(stat(files[j]).mtime)
                    if (file_change_time - t_start).value > 0
                        @info "Deleting corrupted file " * string(files[j])
                        rm(files[j])
                    end
                    j += 1
                end
                
                n_try += 1

                # Wait some more time before next try
                sleep(10)
            else
                # Make sure the created file is not corrupted

                # Get filename; assume only one created file
                j = 1
                while j <= length(files)
                    file_change_time = unix2datetime(stat(files[j]).mtime)
                    #@info "Iter " *string(j) * " - Item" * string(files[j])
                    #@info "F_m<" * string(file_change_time) * "> t_S<" * string(t_start) * "> delta<"*string((file_change_time - t_start).value) * ">"
                    if (file_change_time - t_start).value > 0
                        filename = files[j]
                        break
                    end
                    j += 1
                end

                # Check if there was a file created, and check if it is corrupted
                if filename != ""
                    if stat(filename).size == 0
                        err_string = "Error A4: Empty files written"
                        @warn err_string
                        
                        rm(filename)
                        n_try += 1
                        filename = ""

                        if callback isa Function
                            ms = measurement_state(STATE_PART_FAILED, err_string)
                            ms.opt = (struck_reached, i, n_try, settings.number_of_measurements, max_tries)
                            callback(ms)
                        end
                    else
                        input = open(CompressedStreams.CompressedFile(filename))
                        try
                            SIS3316Digitizers.read_data(input)
                            close(input)
                        catch e
                            err_string = "Error A3: .dat-files not readable"
                            @warn err_string

                            close(input)
                            rm(filename)

                            n_try += 1
                            filename = ""

                            if callback isa Function
                                ms = measurement_state(STATE_PART_FAILED, err_string)
                                ms.opt = (struck_reached, i, n_try, settings.number_of_measurements, max_tries)
                                callback(ms)
                            end
                        end
                    end
                else
                    @error "Expected file not created by measurement. Aborting."
                    n_try = 11
                end
            end
        end

        # n_try = 11 => previous 10 tries failed
        if n_try == max_tries+1
            rm("pmt_daq_dont_move.scala")
            cd(original_dir)

            err_string = "Trivial error: Struck not running"
            if struck_reached
                err_string = "Error B1: Persistent timeouts"
            end

            @error err_string

            if callback isa Function
                ms = measurement_state(STATE_PART_FAILED, err_string)
                ms.opt = (struck_reached, i, n_try, settings.number_of_measurements, max_tries)
                callback(ms)
            end

            throw(ErrorException(err_string * ". Measurement failed. Make sure the fadc is running, you're running the code within the legend(-base) container on gelab-pcXX and correct permissions are set on the directory. If you can ping the struck and think everything is set up correctly, do a test using sis3316-test-gui. Execute that on a Linux host with Desktop functionality connecting to gelab-pcXX via ssh -X gelab@gelab-pcXX and check connection + execute test in the sub-menu. This helps to spin up a Struck if a restart alone did not help"))            
        end

        # Assumption: Only one file will be added per execution. Otherwise we'd have to sort files by file_change_time and get all items with file_change_time > t_check
        @info "Measurement " * string(i) * "/" * string(settings.number_of_measurements) * " - Saved (" * filename * ")"
        push!(new_files, filename)

        if callback isa Function
            data = read_data_from_struck(filename, filter_faulty_events=settings.filter_faulty_events, coincidence_interval = settings.coincidence_interval)
            
            ms = measurement_state(STATE_PART_DONE, "Part received")
            ms.data = data
            ms.opt = (struck_reached, i, n_try, settings.number_of_measurements, max_tries)
            callback(ms)
        end

        i = i + 1
    end

    #chmod(pwd(), 0o775, recursive=true)
    rm("pmt_daq_dont_move.scala")
    
    if !settings.skip_post_processing
        @info "Doing post-processing"
        written_files = struck_to_h5(new_files, settings; conv_data_dir=conv_data_dir, calibration_data=calibration_data)

        if callback isa Function
            ms = measurement_state(STATE_DONE, "Finished data-taking")
            ms.data = written_files
            callback(ms)
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