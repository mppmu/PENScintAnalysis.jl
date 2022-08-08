"""
        PENBBScan2D(settings<:Dict, start<:Vector, step<:Vector, ends<:Vector, measurement_name::String, motor)

Function to perform an automate scan in 2D (x,y axis). You'll have to connect to your motor before starting this function.
It will return a dictionary of the missed positions, if there are any.
...
# Arguments
- `settings<:Dict`: Dictionary containing all settings. Will be translated into NamedTuple for compatibility
- `start<:Vector`: Vector of start position e.g. [x_start,y_start] = [0.0,0.5]
- `step<:Vector`: Vector of step size e.g. [x_step,y_step] = [1.0,1.0]
- `ends<:Vector`: Vector of end position e.g. [x_end,y_end] = [90.0,90.0]
- `measurement_name<:String`: Name of the measurement
- `motor`: IO connection to the motorized stage
- `notebook::Bool=false`: Set to true if you take data using a Juypter notebook

...
"""
function PENBBScan2D(settings, start::Vector{Float64}, step::Vector{Float64}, ends::Vector{Float64}, measurement_name, motor; notebook::Bool=false)
    
    # Timestamp for moved data
    timestamp = string(Dates.now())
    
    missed_positions = Dict()
    missed_positions["x"] = []
    missed_positions["y"] = []

    cur_dir = pwd()
    if start[1] < 0.0 || start[2] < 0.0 || ends[1] > 100.0 || ends[2] > 100.0
        @info("Error: value out of range: you have to use values in the range x[0.,100.], y[0.,100.]")
    else
        for i in collect(start[1]:step[1]:ends[1])
            XMoveMM(i,motor)
            current_x_pos = ""
            ProgressMeter.@showprogress "Performing y scan for x=$i " for j in collect(start[2]:step[2]:ends[2])
                #@info(string("Points skipped: ", length(missed_positions["x"])))
                @info("position: ",i,j)
                YMoveMM(j,motor)
                pos_x = PosX(motor)
                pos_y = PosY(motor)


                # lpad only works with integers
                if 10 <= pos_x < 100
                    pos_x = string("0", pos_x)
                elseif pos_x < 10
                    pos_x = string("00", pos_x)
                else
                    pos_x = string(pos_x)
                end
                current_x_pos = pos_x
                if 10 <= pos_y < 100
                    pos_y = string("0", pos_y)
                elseif pos_y < 10
                    pos_y = string("00", pos_y)
                else
                    pos_y = string(pos_y)
                end
                

                #
                ## Sorting the output files in directories
                name_file = string("2D_PEN_Scan_Holder_",measurement_name,"_x_",pos_x,"_y_",pos_y,"_of_",settings["measurement_time"],"_seconds")
                output_dir = settings["conv_data_dir"] * string("/", measurement_name, "/x_",pos_x)
                
                #
                ## This conversion is just for compatibility
                settings_nt = (fadc = settings["fadc"],
                    output_basename = name_file,
                    data_dir = settings["data_dir"],
                    conv_data_dir = output_dir,
                    measurement_time = settings["measurement_time"],
                    number_of_measurements = 1, # please use this function in a loop
                    channels = settings["channels"],
                    trigger_threshold = settings["trigger_threshold"],
                    trigger_pmt = settings["trigger_pmt"],
                    peakTime = settings["peakTime"],
                    gapTime = settings["gapTime"], 
                    nPreTrig = settings["nPreTrig"],
                    nSamples = settings["nSamples"],
                    saveEnergy = settings["saveEnergy"],
                    delete_dat = settings["delete_dat"],
                    h5_filesize_limit = settings["h5_filesize_limit"],
                    filter_faulty_events = settings["filter_faulty_events"],
                    coincidence_interval = settings["coincidence_interval"]
                );
                # println(name_file)
                
                # Measure until the data-taking succeeds
                done::Bool = false 
                retry_num = [0]

                while !done
                
                    ## Create asynchronous task for data taking
                    t = @async try take_struck_data(settings_nt, calibration_data=settings["calibration_data"])
                        catch e 
                        println("stopped on $e") 
                    end
                    
                    # Create timeout check
                    ts = 1
                    prog = ProgressMeter.Progress(3*settings["measurement_time"], "Time till skip:")
                    while istaskdone(t) == false && ts <= 3 * settings["measurement_time"]
                        # This loop will break when task t is compleded
                        # or when the time is over
                        sleep(1)
                        ts += 1
                        ProgressMeter.next!(prog)
                    end
                    
                    # After the loop has ended, this extra check will interrupt the data taking if needed
                    # For this, it throws and error to task t and kills all java processes (if scala process freezes)
                    if (istaskdone(t) == false || ts < settings["measurement_time"]) && retry_num[1] <= 3
                        @async Base.throwto(t, EOFError())
                        kill_all_java_processes(3 * settings["measurement_time"])
                        retry_num[1] += 1
                        if retry_num[1] > 3
                            push!(missed_positions["x"], i)
                            push!(missed_positions["y"], j)
                            open("missing_log_" * measurement_name * ".json",  "w") do f
                                JSON.print(f, missed_positions, 4)
                            end
                            done = true
                        end
                    else # Data taking was successful
                        done = true 
                    end
                    
                    cd(cur_dir)
                    sleep(2)
                    
                    # Clear output
                    notebook ? IJulia.clear_output(true) : Base.run(`clear`)
                    
                end     
            end
            #
            ## Move x scan to ceph
            if settings["move_to_ceph"]
                @info("Moving data to ceph. Please wait")
                from_dir = joinpath(settings["conv_data_dir"], measurement_name * "/x_" * current_x_pos)
                @info("Data will be moved from: " * from_dir)
                to_dir   = joinpath(settings["dir_on_ceph"], measurement_name * "-" * timestamp * "/x_" * current_x_pos)
                @info("Data will be moved to: " * to_dir)
                !isdir(to_dir) ? mkpath(to_dir, mode= 0o775) : "dir exists"
                mv(from_dir, to_dir, force=true)    
                rm(settings["conv_data_dir"], recursive=true)
                try run(`chmod 775 -R $to_dir`) catch; end    
            end
        end
        @info("PEN BB 2D scan completed, see you soon!")
    end
    #@info("Missed positions are listed here:")
    return missed_positions
end
export PENBBScan2D


"""
        PENBBGridScan2D(settings<:Dict, start<:Vector, step<:Vector, ends<:Vector, measurement_name::String, time_per_point::Int64, motor)

Function to perform an automate scan in 2D (x,y axis). You'll have to connect to your motor before starting this function.
It will return a dictionary of the missed positions, if there are any.
...
# Arguments
- `settings<:Dict`: Dictionary containing all settings. Will be translated into NamedTuple for compatibility
- `start<:Vector`: Vector of start position e.g. [x_start,y_start] = [0.0,0.5]
- `step<:Vector`: Vector of step size e.g. [x_step,y_step] = [1.0,1.0]
- `ends<:Vector`: Vector of end position e.g. [x_end,y_end] = [90.0,90.0]
- `motor`: IO connection to the motorized stage
- `notebook::Bool=false`: Set to true if you take data using a Juypter notebook

...
"""
function PENBBGridScan2D(settings, grid_filename, measurement_name, motor; notebook=false)
    
    # Timestamp for moved data
    timestamp = string(Dates.now())
    
    grid = JSON.parsefile(grid_filename)
    cur_dir = pwd()

    scan_x_rng = sort(parse.(Float64, keys(grid)))
    for i in scan_x_rng
        grid = JSON.parsefile(grid_filename)
        scan_y_rng = []
        for (k,v) in grid[string(i)]
            if v == "to be done"
                push!(scan_y_rng, parse(Float64, k))
            end
        end
        scan_y_rng = sort(scan_y_rng)
        if length(scan_y_rng) > 0
            
            grid = JSON.parsefile(grid_filename)
            XMoveMM(i,motor)
            current_x_pos = ""

            ProgressMeter.@showprogress "Performing y scan for x=$i " for j in scan_y_rng
                @info("position: ",i,j)

                YMoveMM(j,motor)
                pos_x = PosX(motor)
                pos_y = PosY(motor)

                # lpad only works with integers
                if 10 <= pos_x < 100
                    pos_x = string("0", pos_x)
                elseif pos_x < 10
                    pos_x = string("00", pos_x)
                else
                    pos_x = string(pos_x)
                end
                current_x_pos = pos_x
                if 10 <= pos_y < 100
                    pos_y = string("0", pos_y)
                elseif pos_y < 10
                    pos_y = string("00", pos_y)
                else
                    pos_y = string(pos_y)
                end
                

                #
                ## Sorting the output files in directories
                name_file = string("2D_PEN_Scan_Holder_",measurement_name,"_x_",pos_x,"_y_",pos_y,"_of_",settings["measurement_time"],"_seconds")
                output_dir = settings["conv_data_dir"] * string("/", measurement_name, "/x_",pos_x)
                
                #
                ## This conversion is just for compatibility
                settings_nt = (fadc = settings["fadc"],
                    output_basename = name_file,
                    data_dir = settings["data_dir"],
                    conv_data_dir = output_dir,
                    measurement_time = settings["measurement_time"],
                    number_of_measurements = 1, # please use this function in a loop
                    channels = settings["channels"],
                    trigger_threshold = settings["trigger_threshold"],
                    trigger_pmt = settings["trigger_pmt"],
                    peakTime = settings["peakTime"],
                    gapTime = settings["gapTime"], 
                    nPreTrig = settings["nPreTrig"],
                    nSamples = settings["nSamples"],
                    saveEnergy = settings["saveEnergy"],
                    delete_dat = settings["delete_dat"],
                    h5_filesize_limit = settings["h5_filesize_limit"],
                    filter_faulty_events = settings["filter_faulty_events"],
                    coincidence_interval = settings["coincidence_interval"]
                );
                
                # Measure until the data-taking succeeds
                done::Bool = false 
                retry_num = [0]

                while !done
                
                    ## Create asynchronous task for data taking
                    t = @async try take_struck_data(settings_nt, calibration_data=settings["calibration_data"])
                        catch e 
                        println("stopped on $e") 
                    end
                    
                    # Create timeout check
                    ts::Int64 = 1
                    temp_file_created::Bool = false
                    temp_file_completed::Bool = false
                    waiting_time::Int64 = 3 * settings["measurement_time"]
                    prog = ProgressMeter.Progress(3*settings["measurement_time"], "Time till skip:")
                    while istaskdone(t) == false && ts <= waiting_time
                        # This loop will break when task t is compleded
                        # or when the time is over
                        ProgressMeter.next!(prog)

                        tmp_files = Glob.glob("*.tmp")                        
                        if length(tmp_files) > 0 && !temp_file_created
                            @info("Temp file created: " * basename(tmp_files[end]))
                            @info("Measurement ongoing")
                            temp_file_created = true
                        elseif temp_file_created && !temp_file_completed
                            @info("Data taking is done! Conversion to *.h5 will start now")
                            @info("The waiting time will be increased to cover the conversion to *.h5")
                            temp_file_completed = true
                            waiting_time = 6 * settings["measurement_time"]
                        end                        
                        sleep(2)
                        ts += 2                        
                    end
                    

                    # After the loop has ended, this extra check will interrupt the data taking if needed
                    # For this, it throws and error to task t and kills all java processes (if scala process freezes)
                    if (istaskdone(t) == false || ts < settings["measurement_time"]) && retry_num[1] <= 3
                        @async Base.throwto(t, EOFError())
                        kill_all_java_processes(3 * settings["measurement_time"])
                        retry_num[1] += 1
                        if retry_num[1] > 3
                            done = true
                        end
                    else # Data taking was successful
                        grid[string(i)][string(j)] = "done"
                        open(grid_filename, "w") do f
                            JSON.print(f, grid, 4)
                        end
                        done = true 
                    end
                    
                    cd(cur_dir)
                    sleep(2)
                    
                    # Clear output
                    notebook ? IJulia.clear_output(true) : Base.run(`clear`)
                    
                end
            end
        
            #
            ## Move x scan to ceph
            if settings["move_to_ceph"]
                @info("Moving data to ceph. Please wait")
                from_dir = joinpath(settings["conv_data_dir"], measurement_name * "/x_" * current_x_pos)
                @info("Data will be moved from: " * from_dir)
                to_dir   = joinpath(settings["dir_on_ceph"], measurement_name * "-" * timestamp * "/x_" * current_x_pos)
                @info("Data will be moved to: " * to_dir)
                !isdir(to_dir) ? mkpath(to_dir, mode= 0o775) : "dir exists"
                mv(from_dir, to_dir, force=true)    
                rm(settings["conv_data_dir"], recursive=true)
                try run(`chmod 775 -R $to_dir`) catch; end    
            end
        end
    end
    @info("PEN BB 2D scan completed, see you soon!")
end
export PENBBGridScan2D