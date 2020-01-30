function sort_by_events(data_table)
    ch_num = length(unique(data_table.chid))
    events = []
    i = 1
    while i <= length(data_table)
        if i+ch_num-1 <= length(data_table)
            push!(events, data_table[i:i+ch_num-1])        
        end
        i += ch_num
    end
    return events
end
