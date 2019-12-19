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