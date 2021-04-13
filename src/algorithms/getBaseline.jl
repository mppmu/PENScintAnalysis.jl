"""
...
function to compute the baseline of a given wf, it takes a wf and compute the average of the values in the wf
removing +/- 5 samples around the peaks to avoid bias
 Arguments
- signal::Vector: Waveform to be analyzed
- threshold: Threshold for peaks. Default = 15.0
...
"""

function getBaseline(signal::Vector; threshold = 15.0)
    Baseline = copy(signal)
    peaks_threshold = mean(Baseline) + threshold # only peaks with amplitudes threshold units larger than the average
    peak_pos = findLocalMaxima(Baseline,peaks_threshold)
    #peak_pos = findall(x -> x > peaks_threshold, signal)
    index_to_delete = []
    for i in peak_pos
        if length(index_to_delete) > 0 && index_to_delete[end] > i-6 #security check for two close peaks
            continue
        end
        if i < 10
            append!(index_to_delete,collect(1:i+5))
        elseif 10 < i < length(signal)-10
            append!(index_to_delete,collect(i-5:i+5))
        else
            append!(index_to_delete,collect(i:length(signal)))
        end
    end
    deleteat!(Baseline,index_to_delete)
    baseline = mean(Baseline)
end


