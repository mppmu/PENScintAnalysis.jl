# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

__precompile__(true)

module PENScintAnalysis

using Base.Threads

using Compat
using Compat.Markdown
using Compat: axes

using ArraysOfArrays
using CompressedStreams
using DataFrames
using DSP
using ElasticArrays
using MultiThreadingTools
using Plots
using SIS3316
using StatsBase
using UnsafeArrays

include("util.jl")
include("read_raw_data.jl")
include("pmt_dsp.jl")
include("stat_functions.jl")
include("dataproc.jl")
include("plot.jl")

end # module
