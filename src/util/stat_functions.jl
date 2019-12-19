# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

"""
"""
function reduced_maximum(A::Array{<:Real})
    T = eltype(A)
    sorted_A = sort(A)
    a = length(A) > 1000 ? T(sorted_A[length(A)-5]) : T(sorted_A[end])
    b = T(percentile(A, 100 * (1 - 1E-5)))
    min(a, b)
end

export reduced_maximum

"""
"""
function pulse_hist(waveforms::WFSamples, yedge::StepRange)
    samples = flatview(waveforms)

    xedge = axes(samples, 1)
    ph = Histogram((xedge, yedge), Float64, :left)
    @inbounds for evtno in axes(samples, 2)
        for i in axes(samples, 1)
            push!(ph, (i, samples[i, evtno]))
        end
    end
    ph.weights .= log10orNaN.(ph.weights)
    ph
end

export pulse_hist
