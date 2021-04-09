# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

"""
            struck_to_h5(filename::String; conv_data_dir="../conv_data/")

Read *.dat struck data file and stores it as HDF5 (LegendHDF5IO formatting). Array of filenames is also accepted.
...
# Arguments
- `filename::String`: Path to *.dat file.
- `nevents::Int`: Number of events to read in. Default: all events.
...
"""
function struck_to_h5(filename::String; conv_data_dir="../conv_data/")
    if !isfile(filename)
        return "File does not exist: "*filename
    end
    if length(split(basename(filename), ".dat")) >= 2
        real_filename = split(basename(filename), ".dat")[1]
    else 
        return "Wrong file format: "*filename
    end
    
    if isfile(conv_data_dir*real_filename*".h5")
        ans = getUserInput(String, "File exists. Do you want to overwrite? Y/n");
        if ans == "Y" || ans == "yes" || ans == "y" || ans == ""
            rm(conv_data_dir*real_filename*".h5");
        else 
            return "Please enter a different filename then."
        end
    end
    if !isdir(conv_data_dir)
        mkdir(conv_data_dir)
    end
    dset = read_data_from_struck(filename)
    
    HDF5.h5open(conv_data_dir*real_filename*".h5", "w") do h5f
        LegendHDF5IO.writedata( h5f, "data", dset)
    end
end

function struck_to_h5(filenames; conv_data_dir="../conv_data/")
    for filename in filenames
        if !isfile(filename)
            return "File does not exist: "*filename
        end
    
        if length(split(basename(filename), ".dat")) >= 2
            real_filename = split(basename(filename), ".dat")[1]
        else 
            return "Wrong file format: "*filename
        end
    end
    if length(split(basename(filenames[1]), ".dat")) >= 2
        real_filename = split(basename(filenames[1]), ".dat")[1]
    end
    if isfile(conv_data_dir*real_filename*".h5")
        ans = getUserInput(String, "File exists. Do you want to overwrite? Y/n");
        if ans == "Y" || ans == "yes" || ans == "y" || ans == ""
            rm(conv_data_dir*real_filename*".h5");
        else 
            return "Please enter a different filename then."
        end
    end

    if !isdir(conv_data_dir)
        mkdir(conv_data_dir)
    end
    
    dset = read_data_from_struck(filenames)
    
    HDF5.h5open(conv_data_dir*real_filename*".h5", "w") do h5f
        LegendHDF5IO.writedata( h5f, "data", dset)#Table(chid=dset.chid, evt_t=dset.evt_t, samples=VectorOfArrays(dset.samples)))
    end
end



function readh5(filename::String)
    HDF5.h5open(filename, "r") do h5f
        LegendHDF5IO.readdata( h5f, "data")
    end
end

function writeh5(filename::String, typed_table)
    HDF5.h5open(filename, "w") do h5f
        LegendHDF5IO.writedata( h5f, "data", typed_table)
    end
end



function getUserInput(T=String,msg="")
    print("$msg ")
    if T == String
        return readline()
    else
        try
            return parse(T,readline())
        catch
            println("Sorry, I could not interpret your answer. Please try again")
            getUserInput(T,msg)
        end
    end
end


"""
            get_h5_info_old(filename::String)

Gives information about a file in the outdated dataformat. Outdated means non-LegendHDF5IO compatible.
Retruns `names` of the subfiles, the number of pulses `nevents` and the `substructure` of these files.
...
# Arguments
- `filename::String`: Path to *.h5 file with old formatting as a string.

...
"""
function get_h5_info_old(filename::String)
    h5open(filename) do h5f
        info = Dict()
        info["names"]        = names(h5f)
        info["nevents"]      = []
        info["substructure"] = names(h5f[ info["names"][1] ])
        for i in info["names"]
            substruct = names(h5f[ i ])
            push!(info["nevents"], length(read( h5f[ i ][ substruct[1] ] )))
        end
        return info
    end
end



"""
            read_old_h5_structure(filename::String; nevents=typemax(Int), nsubfiles=typemax(Int), subfiles=[], chids=[])

Reads the outdated dataformat. Outdated means non-LegendHDF5IO compatible.
...
# Arguments
- `filename::String`: Path to *.h5 file with old formatting as a string.
- `nevents::Int`: Number of events to read in. Default: all events.
- `nsubfiles::Int`: Number of subfiles to read in. Default: all.
- `subfiles`: Array of indices of subfiles to read in. Default: empty = all.
- `chids`: Array of channels you want to read. Default: empty = all. Starts at 0.

...
"""
function read_old_h5_structure(filename::String; nevents=typemax(Int), nsubfiles=typemax(Int), subfiles=[], chids=[])
    h5open(filename, "r") do h5f
        tt = Table(
            chid = Int32[],
            timestamp = Float64[],
            samples   = VectorOfArrays(Array{Int32,1}[]),
            ) 
        n1 = 0
        n2 = 0
        nbreak  = false
        entries = names(h5f)
        if nsubfiles >= length(entries)
            p_max = length(entries)
        else
            p_max = nsubfiles
        end
        if length(subfiles) < p_max
            p_max = length(subfiles)
        end
        if length(subfiles) == 0
            subfiles = 1:1:length(entries)
        end
        
        p = Progress(p_max, dt=0.5,
                 barglyphs=BarGlyphs('|','█', ['▁' ,'▂' ,'▃' ,'▄' ,'▅' ,'▆', '▇'],' ','|',),
                 barlen=10)
        for entry in entries[subfiles]
            temp   = read(h5f[entry])
            pulses = Array{Int32,1}[]
            i = 1
            while i <= length(temp["chid"])
                push!(pulses, temp["samples"][i, :])
                i += 1
                n1 += 1
                if n1 == nevents
                    nbreak = true
                    break
                end
            end

            append!(tt, Table(chid=temp["chid"][1:length(pulses)], timestamp=temp["timestamps"][1:length(pulses)], samples=VectorOfArrays(pulses)))
            next!(p)
            n2 += 1
            if nbreak || n2 == nsubfiles
                break
            end
        end
        if chids == []
            chids = unique(tt.chid)
        end
        
        tt_ch = Dict()
        for ch in chids
            tt_ch[string(ch)] = tt |> @select(:chid, :timestamp, :samples) |> @filter(_.chid == ch) |> Table;
        end
        return tt_ch
    end
end
