# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

"""
"""

function triangular_dither(T::Type{<:AbstractFloat}, x::Real, width::Real = one(typeof(x)))
    r = rand(T)
    tr = (r >= 0.5) ? - sqrt(2 - 2*r) + 1 : sqrt(2*r) - 1
    x + tr * width
end

export triangular_dither

"""
"""

function triangular_window(nrise::Integer, ntop::Integer)
    T = Float64
    rise = if nrise > 0
        Vector{T}(linspace(zero(T), one(T), nrise + 2)[2:nrise+1])
    else
        Vector{T}()
    end
    top = fill(one(T), ntop)
    vcat(rise, top, reverse(rise))
end

export triangular_window


window_weights(window_function::Function, n::Integer) =
    normalize(window_function(n), 1)

window_weights(window_function::Function, r::AbstractUnitRange{<:Integer}) =
    window_weights(window_function, length(r))

export window_weights

"""
"""

function fastvecdot(x::AbstractVector, y::AbstractVector)
    eachindex(x) != eachindex(y) && throw(DimensionMismatch("Vector shapes differ"))
    T = promote_type(eltype(x), eltype(y))
    s = zero(T)
    @inbounds @simd for i in eachindex(x)
        s += T(x[i] * y[i])
    end
    s
end

export fastvecdot

"""
"""

function fastsum(x::AbstractVector)
    s = zero(eltype(x))
    @inbounds @simd for i in eachindex(x)
        s += x[i]
    end
    s
end

export fastsum


function wf_range_sum end
export wf_range_sum

"""
"""

function wf_range_sum(waveforms::WFSamples, r::AbstractUnitRange{<:Integer})
    R = Vector{eltype(flatview(waveforms))}(undef, size(waveforms))
    @threads for i in eachindex(waveforms)
        R[i] = fastsum(view(waveforms[i], r))
    end
    R
end

"""
"""

function wf_range_sum(waveforms::WFSamples, r::AbstractUnitRange{<:Integer}, weights::AbstractVector{<:Real})
    R = Vector{eltype(flatview(waveforms))}(undef, size(waveforms))
    @threads for i in eachindex(waveforms)
        R[i] = fastvecdot(view(waveforms[i], r), weights)
    end
    R
end

"""
"""

wf_range_sum_simple(waveforms::WFSamples, r::AbstractUnitRange{<:Integer}, weights::AbstractVector{<:Real}) =
    sum(flatview(waveforms)[r, :] .* weights, 1)[:]


function wf_shift! end
export wf_shift!

"""
"""

function wf_shift!(output::WFSamples, input::WFSamples, x::Union{Real,Vector{<:Real}})
    flatview(output) .= flatview(input) .+ x'
    output
end

"""
"""

function wf_shift_simd!(output::WFSamples, input::WFSamples, x::Real)
    X = flatview(output)
    A = flatview(input)

    size(X) != size(A) && throw(DimensionMismatch("Input and output size differ"))
    eachindex(X) != eachindex(A) && throw(DimensionMismatch("Input and output indices are incompatible"))

    onthreads(threads_all()) do
        @inbounds @simd for i in threadpartition(eachindex(X))
            X[i] = A[i] + x
        end
    end

    output
end
