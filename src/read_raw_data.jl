# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

function read_raw_data(filenames::AbstractArray{<:AbstractString}, nevents = typemax(Int))
    channel = Vector{Int}()
    bufferno = Vector{Int}()
    timestamp = Vector{Float64}()
    wfmatrix = ElasticArray{Int}(undef, 1, 0)
    evtno = 0

    for filename in filenames
        evtno > nevents && break
        open(CompressedFile(filename)) do input
            tmpevtdata = Vector{UInt8}()

            nbuffers = 0
            while !eof(input)
                evtno > nevents && break
                buffer = read(input, SIS3316Digitizers.FileBuffer, tmpevtdata)
                nbuffers += 1
                bufno = buffer.info.bufferno

                for evt in buffer.events
                    evtno += 1
                    evtno > nevents && break
                    if length(wfmatrix) == 0
                        wfmatrix = ElasticArray{Int}(undef, length(evt.samples), 0)
                    end
                    push!(channel, evt.chid)
                    push!(bufferno, bufno)
                    push!(timestamp,time(evt))
                    append!(wfmatrix, evt.samples)
                end
                # info("Read buffer $bufno, channel $chno with $(length(buffer.events)) events")
            end
            # info("Read $nbuffers buffers * channels")
        end
    end

    waveforms = nestedview(wfmatrix)

    DataFrame(
        channel = channel,
        bufferno = bufferno,
        timestamp = timestamp,
        waveform = waveforms
    )
end

export read_raw_data
