"""
Find all the peaks above a certain threhsold in a waveform
takes as entry a waveform and returns an array with the position of the maximums in the waveform
this information can be used to compute the amplitud of the peaks just evaluating wf[i]
or the integral of peak
...
# Arguments
- signal::Vector: Wavefor to be analyzed
- threshold: optional value given for the user to look for peaks above this value
if threshold is not provided it will compute the rms and look for peaks above twice the rms
...
"""

function findLocalMaxima(signal::Vector, threshold = 0 )
   inds = Int[]
   if threshold != 0
      new_threshold = threshold
   else
      ground_level = mean(signal) 
      #rms  = sqrt(sum(signal[:].^2.) / length(signal[:]))
      new_threshold = ground_level + 15.
   end
   #println(new_threshold," mean ",ground_level) 
   if length(signal)>1
       if signal[1]>signal[2] && signal[1] > new_threshold
           push!(inds,1)
       end
       for i=2:length(signal)-1
           if signal[i-1]<signal[i]>signal[i+1] && signal[i] > new_threshold
               push!(inds,i)
           end
       end
       if signal[end]>signal[end-1] && signal[end] > new_threshold 
           push!(inds,length(signal))
       end
   end
   inds
end


