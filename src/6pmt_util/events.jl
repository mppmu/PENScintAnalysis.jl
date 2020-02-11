function sort_by_events(data_table; coincidence_interval=4e-9)
    events = []
    chnum = length(unique(data_table.chid))
    i = 1
    while i <= size(data_table,1)
        if i + chnum <= size(data_table,1)
            coincident = findall(x->x in [data_table.evt_t[i]-coincidence_interval, data_table.evt_t[i], data_table.evt_t[i]+coincidence_interval], data_table.evt_t[i:i+chnum-1])
            if length(coincident) == chnum
                push!(events, data_table[i:i+chnum-1])
            end
            i += coincident[end]
        else
            break 
        end
    end  
    
    return events
end
