__precompile__(true)

module PENScintAnalysis

using Base.Threads

using Compat
using Compat.Markdown
using Compat: axes

using ArraysOfArrays
using BitOperations
using CompressedStreams
using DataFrames
using DSP
using ElasticArrays
using LinearAlgebra
using ParallelProcessingTools
using Plots
using RecipesBase
using SIS3316Digitizers
using StatsBase
using UnsafeArrays

include("util.jl")
include("read_raw_data.jl")
include("pmt_dsp.jl")
include("stat_functions.jl")
include("dataproc.jl")
include("plot.jl")

end # module

#=
file = "/remote/ceph/group/gedet/data/pen/2019/2019-01-25_dc441dd3_lm_6_pmt_calibration_measurements/raw_data/SiPM_laser_max/sipm_56_intern-20190304T093145Z-raw.dat"
raw = read_raw_data([file],10)
precalibrate_data(raw)
=#
