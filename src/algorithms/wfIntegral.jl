"""
function to compute the integral of a waveform, probably can be replace by sum julia function but some cuts are planned to be included...
...
# Arguments
- signal::Vector: Wavefor to be analyzed
...
"""



function wfIntegral(signal::Vector)
    integral = 0.0; 
    nSamples = size(signal)[1]
    for i = 1 : nSamples
        integral += signal[i]*1.0
    end
    integral
end


