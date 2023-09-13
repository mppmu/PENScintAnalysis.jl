__precompile__(true)

module PENScintAnalysis

import ArraysOfArrays
import Base.Threads
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
import LegendDataTypes
import LegendHDF5IO
import LegendHDF5IO: readdata, writedata
import LinearAlgebra
import ParallelProcessingTools
import Plots
import ProgressMeter
import Query
import RecipesBase
import SIS3316Digitizers
import Sockets
import StatsBase
import StructArrays
import Suppressor
import TypedTables
import UnsafeArrays
# import PENBBControl will be replaced


include("6pmt_util/pmt_tools.jl")
include("algorithms/algorithms.jl")
include("hdf5/hdf5_tools.jl")
include("HV_control/HV_tools.jl")
include("motor_control/motor_tools.jl")
include("struck/struck_tools.jl")
include("util/util.jl")
include("take_pmt_data.jl")

end
