__precompile__(true)

module PENScintAnalysis

import Base.Threads

import Compat
import Compat.Markdown
import Compat: axes

import ArraysOfArrays
import BitOperations
import CompressedStreams
import DataFrames
import Dates
import DSP
import ElasticArrays
import Glob
import HDF5
import HTTP
import IJulia
import JSON
import LinearAlgebra
import LegendDataTypes
import LegendHDF5IO
import LegendHDF5IO: readdata, writedata
import ParallelProcessingTools
import ProgressMeter
import Query
import RecipesBase
import Sockets
import SIS3316Digitizers
import StatsBase
import StructArrays
import Suppressor
import TypedTables
import UnsafeArrays
import PENBBControl

include("util/util.jl")
include("struck/read_raw_data.jl")
include("struck/take_struck_data.jl")
include("struck/create_struck_daq_file.jl")
include("hdf5/hdf5tools.jl")
include("pmt_dsp.jl")
include("6pmt_util/events.jl")
include("6pmt_util/PENBBScan2D.jl")
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
export sort_by_events, PENBBScan2D

end # module
