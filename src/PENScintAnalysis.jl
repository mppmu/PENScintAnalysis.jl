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
using LegendHDF5IO
using LegendHDF5IO: readdata, writedata
using ParallelProcessingTools
using Plots
using RecipesBase
using SIS3316Digitizers
using StatsBase
using StructArrays
using UnsafeArrays

include("util/util.jl")
include("struck/read_raw_data.jl")
include("struck/take_struck_data.jl")
include("hdf5/hdf5tools.jl")
include("util/pmt_dsp.jl")
include("util/stat_functions.jl")
include("util/dataproc.jl")
include("util/plot.jl")
include("algorithms/findLocalMaxima.jl")
include("algorithms/getBaseline.jl")
include("algorithms/peakIntegral.jl")
include("algorithms/wfIntegral.jl")

export getUserInput, readh5, read_data_from_struck, read_raw_data, struck_to_h5, findLocalMaxima, getBaseline, peakIntegral, wfIntegral

end # module

#=
file = "/remote/ceph/group/gedet/data/pen/2019/2019-01-25_dc441dd3_lm_6_pmt_calibration_measurements/raw_data/SiPM_laser_max/sipm_56_intern-20190304T093145Z-raw.dat"
raw = read_raw_data([file],10)
precalibrate_data(raw)
=#
