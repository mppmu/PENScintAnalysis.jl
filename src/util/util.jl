# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

log10orNaN(x) = (x <= 0) ? typeof(x)(NaN) : log10(x)
export log10orNaN


const WFSamples = AbstractVectorOfSimilarVectors{<:Real}
export WFSamples


av(A::AbstractMatrix) = VectorOfSimilarVectors(A)
export av

"""
"""
function entrysel(predicate::Function, ds::DataFrame, colname::Symbol...)
    columns = map(c -> ds[c], colname)
    f(xs) = predicate(xs...)
    find(f, zip(columns...))
end

export entrysel
