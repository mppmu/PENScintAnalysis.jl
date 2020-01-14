# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

"""
        read_data_from_struck(filename:String; just_evt_t=false)

Reads one (or array of) Struck (*.dat) file(s) and returns a Named Table. Keys: samples, chid, evt_t, energy
...
# Arguments
- `filename::String`: Path to *.dat file as a string. Or array of path to *.dat files as strings.
- `just_evt_t::Boolean=false`: If this is set to `true` the function will only return the timestamps.
...
"""
function read_data_from_struck(filename::String; just_evt_t=false)

    input = open(CompressedFile(filename))
    reader = eachchunk(input, SIS3316Digitizers.UnsortedEvents)
    if just_evt_t
        df = DataFrame(
          evt_t   = Float64[]
        )
    else
        df = DataFrame(
            evt_t   = Float64[],
            samples = Array{Int32,1}[],
            chid    = Int32[],
            energy  = []
        )
    end

    sorted = 0
    nchunks = 0
    
    for unsorted in reader
        nchunks += 1
        sorted = sortevents(unsorted)
        #return sorted
        for evt in eachindex(sorted)
            ch = collect(keys(sorted[evt]))[1]
            if just_evt_t
                push!(df, time(sorted[evt][ch]))
            else
                push!(df, (time(sorted[evt][ch]), sorted[evt][ch].samples, sorted[evt][ch].chid, sorted[evt][ch].energy))
            end

        end
        empty!(sorted)
    end
    close(input)
    if just_evt_t
        return (evt_t = df.evt_t)
    else
        return (evt_t = df.evt_t, samples = VectorOfArrays(df.samples), chid = df.chid)#, energy = df.energy)
    end
end

function read_data_from_struck(filenames; just_evt_t=false)
    if just_evt_t
        df_all = DataFrame(
          evt_t   = Float64[]
        )
    else
        df_all = DataFrame(
            evt_t   = Float64[],
            samples = Array{Int32,1}[],
            chid    = Int32[],
            energy  = []
        )
    end
    for filename in filenames
        input = open(CompressedFile(filename))
        reader = eachchunk(input, SIS3316Digitizers.UnsortedEvents)
        if just_evt_t
            df = DataFrame(
              evt_t   = Float64[]
            )
        else
            df = DataFrame(
                evt_t   = Float64[],
                samples = Array{Int32,1}[],
                chid    = Int32[],
                energy  = []
            )
        end
        
        sorted = 0
        nchunks = 0

        for unsorted in reader
            nchunks += 1
            sorted = sortevents(unsorted)
            #return sorted
            for evt in eachindex(sorted)
                ch = collect(keys(sorted[evt]))[1]
                if just_evt_t
                    push!(df, time(sorted[evt][ch]))
                else
                    push!(df, (time(sorted[evt][ch]), sorted[evt][ch].samples, sorted[evt][ch].chid, sorted[evt][ch].energy))
                end

            end
            empty!(sorted)
        end
        close(input)
        append!(df_all, df)
    end
    if just_evt_t
        return (evt_t = df_all.evt_t)
    else
        return (evt_t = df_all.evt_t, samples = VectorOfArrays(df_all.samples), chid = df_all.chid)#, energy = df.energy)
    end
end


"""
        read_raw_data(filename:String; nevents::Int=typemax(Int))

Reads one Struck (*.dat) file and returns a DataFrame. Keys: channel, timestamp, waveform, energy
...
# Arguments
- `filename::String`: Path to *.dat file as a string.
- `filenames`: Array of paths to *.dat files as a string. Here, the data from the files will be put into one DataFrame.
- `nevents::Int`: Number of events to read in. Default: all events.
...
"""
function read_raw_data(filename::String; nevents::Int=typemax(Int))

    input = open(CompressedFile(filename))
    reader = eachchunk(input, SIS3316Digitizers.UnsortedEvents)
    df = DataFrame(
        evt_t   = Float64[],
        samples = Array{Int32,1}[],
        chid    = Int32[],
        energy  = []
    )

    sorted  = 0
    nchunks = 0
    evts    = 0
    stop_reading = false
    for unsorted in reader
        nchunks += 1
        sorted = sortevents(unsorted)
        for evt in eachindex(sorted)
            ch = collect(keys(sorted[evt]))[1]
            push!(df, (time(sorted[evt][ch]), sorted[evt][ch].samples, sorted[evt][ch].chid, sorted[evt][ch].energy))
            evts += 1
            if evts == nevents
                stop_reading = true
                break
            end
        end
        empty!(sorted)
        if stop_reading 
            break
        end
    end
    close(input)
    return DataFrame(channel = df.chid, timestamp = df.evt_t, waveform = df.samples, energy = df.energy)
end

function read_raw_data(filenames; nevents=typemax(Int))
    df_all = DataFrame(
            evt_t   = Float64[],
            samples = Array{Int32,1}[],
            chid    = Int32[],
            energy  = [])
    
    for filename in filenames
        input = open(CompressedFile(filename))
        reader = eachchunk(input, SIS3316Digitizers.UnsortedEvents)
        df = DataFrame(
            evt_t   = Float64[],
            samples = Array{Int32,1}[],
            chid    = Int32[],
            energy  = []
        )

        sorted  = 0
        nchunks = 0
        evts    = 0
        stop_reading = false
        for unsorted in reader
            nchunks += 1
            sorted = sortevents(unsorted)
            for evt in eachindex(sorted)
                ch = collect(keys(sorted[evt]))[1]
                push!(df, (time(sorted[evt][ch]), sorted[evt][ch].samples, sorted[evt][ch].chid, sorted[evt][ch].energy))
                evts += 1
                if evts == nevents
                    stop_reading = true
                    break
                end
            end
            empty!(sorted)
            if stop_reading 
                break
            end
        end
        close(input)
        append!(df_all, df)
    end
        return DataFrame(channel = df_all.chid, timestamp = df_all.evt_t, waveform = df_all.samples, energy = df_all.energy)
end