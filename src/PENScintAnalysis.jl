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
using Dates
using DSP
using ElasticArrays
using Glob
using HDF5
using LinearAlgebra
using LegendHDF5IO
using LegendHDF5IO: readdata, writedata
using ParallelProcessingTools
using ProgressMeter
using Plots
using Query
using RecipesBase
using SIS3316Digitizers
using StatsBase
using StructArrays
using Suppressor
using TypedTables
using UnsafeArrays

include("util/util.jl")
include("struck/read_raw_data.jl")
include("struck/take_struck_data.jl")
include("struck/create_struck_daq_file.jl")
include("hdf5/hdf5tools.jl")
include("pmt_dsp.jl")
include("6pmt_util/events.jl")
include("util/stat_functions.jl")
include("util/dataproc.jl")
include("util/plot.jl")
include("algorithms/findLocalMaxima.jl")
include("algorithms/getBaseline.jl")
include("algorithms/peakIntegral.jl")
include("algorithms/wfIntegral.jl")


# Struck related
export create_struck_daq_file, read_data_from_struck, read_raw_data, struck_to_h5, take_struck_data

# HDF5 related
export get_h5_info_old, getUserInput, readh5, read_old_h5_structure, writeh5

# Luis functions
export findLocalMaxima, getBaseline, peakIntegral, wfIntegral

# 6-PMT setup related functions
export sort_by_events

end # module

#=
file = "/remote/ceph/group/gedet/data/pen/2019/2019-01-25_dc441dd3_lm_6_pmt_calibration_measurements/raw_data/SiPM_laser_max/sipm_56_intern-20190304T093145Z-raw.dat"
raw = read_raw_data([file],10)
precalibrate_data(raw)
=#
