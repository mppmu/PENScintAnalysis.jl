# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

"""
        read_data_from_struck(filename:String)

Reads one (or array of) Struck (*.dat) file(s) and returns a Named Table. Keys: samples, chid, evt_t, energy
...
# Argument
- `filename::String`: Path to *.dat file as a string. Or array of path to *.dat files as strings.
...
"""
function read_data_from_struck(filename::String)

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
            ch = collect(keys(sorted[evt]))[1]
            push!(evt_t, time(sorted[evt][ch]))
            push!(samples, sorted[evt][ch].samples)
            push!(chid, sorted[evt][ch].chid + 1)
            push!(energy, sorted[evt][ch].energy)
        end
        empty!(sorted)
    end
    close(input)
    return Table(evt_t = evt_t, samples = VectorOfArrays(samples), chid = chid)#, energy = energy)
end


function read_data_from_struck(filenames)

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
                ch = collect(keys(sorted[evt]))[1]
                push!(evt_t, time(sorted[evt][ch]))
                push!(samples, sorted[evt][ch].samples)
                push!(chid, sorted[evt][ch].chid + 1)
                push!(energy, sorted[evt][ch].energy)
            end
            empty!(sorted)
        end
        close(input)
    end
    return Table(evt_t = evt_t, samples = VectorOfArrays(samples), chid = chid)#, energy = energy)
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
