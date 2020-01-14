"""
...
function to compute the integral of the peaks in a wf
add all the bins +/- 10 around the peak  
 Arguments
- signal::Vector: Wavefor to be analyzed
- peakPosition: position of the peak you want to compute its integral
...
"""


function peakIntegral(signal::Vector, peakPosition = 1)
    integral = 0
    #make sure the peak is completed asking to be at least 12 samples after the beggining or before the end
    if  12 < peakPosition < length(signal)-12
        for i = peakPosition-11 : peakPosition+11
            integral += signal[i]
        end
    end
    integral
end


