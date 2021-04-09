# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

"""
        read_data_from_struck(filename:String)

Reads one (or array of) Struck (*.dat) file(s) and returns a Named Table. Keys: samples, chid, evt_t, energy
...
# Argument
- `filename::String`: Path to *.dat file as a string. Or array of path to *.dat files as strings.
- `filter_faulty_events::Bool`: Filters events where not all PMTs were recorded.
- `coincidence_inderval::Float64`: Coincidence interval for the filter.
...
"""
function read_data_from_struck(filename::String; filter_faulty_events=false, coincidence_interval = 4e-9)
    
    if split(filename, ".")[end] != "dat"
            println("Wrong fileformat!")
            return []
    end
    evt_t   = Float64[]
    samples = Array{Int32,1}[]
    chid    = Int32[]
    energy  = []
        
    input = open(CompressedFile(filename))
    reader = eachchunk(input, SIS3316Digitizers.UnsortedEvents)

    sorted = 0
    nchunks = 0
    
    for unsorted in reader
        nchunks += 1
        sorted = sortevents(unsorted)
        #return sorted
        for evt in eachindex(sorted)
            channels = collect(keys(sorted[evt]))
            for ch in channels
                push!(evt_t, time(sorted[evt][ch]))
                push!(samples, sorted[evt][ch].samples)
                push!(chid, sorted[evt][ch].chid + 1)
                push!(energy, sorted[evt][ch].energy)
            end
        end
        empty!(sorted)
    end
    close(input)
    if filter_faulty_events
        t = Float64[]
        s = Array{Int32,1}[]
        c = Int32[]
        chnum = length(unique(chid))
        i = 1
        while i <= length(evt_t)
            if i + chnum <= length(evt_t)
                coincident = findall(x->x in [evt_t[i]-coincidence_interval, evt_t[i], evt_t[i]+coincidence_interval], evt_t[i:i+chnum-1])
                if length(coincident) == chnum
                    append!(t, evt_t[i:i+chnum-1])
                    append!(s, samples[i:i+chnum-1])
                    append!(c, chid[i:i+chnum-1])
                end
                i += coincident[end]
            else
                break 
            end
        end
        return Table(evt_t = t, samples = VectorOfArrays(s), chid = c)
    else
        return Table(evt_t = evt_t, samples = VectorOfArrays(samples), chid = chid)
    end
end

function read_data_from_struck(filenames; filter_faulty_events=false, coincidence_interval = 4e-9)
    if split(filenames[1], ".")[end] != "dat"
            println("Wrong fileformat!")
            return []
    end
    evt_t   = Float64[]
    samples = Array{Int32,1}[]
    chid    = Int32[]
    energy  = []
    
    for filename in filenames
        input = open(CompressedFile(filename))
        reader = eachchunk(input, SIS3316Digitizers.UnsortedEvents) 

        sorted = 0
        nchunks = 0

        for unsorted in reader
            nchunks += 1
            sorted = sortevents(unsorted)
            #return sorted
            for evt in eachindex(sorted)
                channels = collect(keys(sorted[evt]))
                for ch in channels
                    push!(evt_t, time(sorted[evt][ch]))
                    push!(samples, sorted[evt][ch].samples)
                    push!(chid, sorted[evt][ch].chid + 1)
                    push!(energy, sorted[evt][ch].energy)
                end
            end
            empty!(sorted)
        end
        close(input)
    end
    if filter_faulty_events
        t = Float64[]
        s = Array{Int32,1}[]
        c = Int32[]
        chnum = length(unique(chid))
        i = 1
        while i <= length(evt_t)
            if i + chnum <= length(evt_t)
                coincident = findall(x->x in [evt_t[i]-coincidence_interval, evt_t[i], evt_t[i]+coincidence_interval], evt_t[i:i+chnum-1])
                if length(coincident) == chnum
                    append!(t, evt_t[i:i+chnum-1])
                    append!(s, samples[i:i+chnum-1])
                    append!(c, chid[i:i+chnum-1])
                end
                i += coincident[end]
            else
                break 
            end
        end
        return Table(evt_t = t, samples = VectorOfArrays(s), chid = c)
    else
        return Table(evt_t = evt_t, samples = VectorOfArrays(samples), chid = chid)
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
