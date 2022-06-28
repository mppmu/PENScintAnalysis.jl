# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).
include("dataproc.jl")
include("plot.jl")
include("stat_functions.jl")

log10orNaN(x) = (x <= 0) ? typeof(x)(NaN) : log10(x)
export log10orNaN


# const WFSamples = AbstractVectorOfSimilarVectors{<:Real}
# export WFSamples


av(A::AbstractMatrix) = VectorOfSimilarVectors(A)
export av

# function entrysel(predicate::Function, ds::DataFrame, colname::Symbol...)
function entrysel(predicate, ds, colname)
    columns = map(c -> ds[c], colname)
    f(xs) = predicate(xs...)
    find(f, zip(columns...))
end
export entrysel

# This functions kills all java processes that have been running longer than a given time "min_time_s"
function kill_all_java_processes(min_time_s::Real = 0)
    @info "Kill all java processes" * (min_time_s == 0 ? "" : "running longer than $(min_time_s) seconds")
    out = Pipe()
    try
        run(pipeline(`pgrep java`, stdout = out)) # results in an error if no java processes are running
    catch
        @info "No java processes running"
    end
    close(out.in)
    for pid in filter!(x -> x != "", split(String(read(out)), "\n"))
        time = Pipe()
        try run(pipeline(`ps -p $(pid) -o etime`, stdout = time)) catch ; end
        close(time.in)
        elapsed_time = replace(split(String(read(time))," ")[end], "\n" => "")
        if length(elapsed_time) > 5 || Time(elapsed_time, "MM:SS") - Time("0") > Second(min_time_s)
            run(`kill $(pid)`)
            @info("  Process id $(pid) killed (running for $(elapsed_time)$(length(elapsed_time) == 5 ? " minutes" : ""))")
        end
    end
end
# export kill_all_java_processes