"""
    plot_pulse_hist(waveforms::WFSamples, ybins::StepRange)

Overlay of waveforms, 2D histogram of pulse waveform, color representing frequency.
"""
function plot_pulse_hist(waveforms::WFSamples, ybins::StepRange)
    plot(
        pulse_hist(waveforms, ybins),
        color = :viridis,
        title = "Signal Shapes",
        label = "Signal Overlay (All Signals)",
        xlabel = "Sample [4ns]",
        ylabel = "Counts"
    )
end

export plot_pulse_hist


@userplot PlotPulseHist

@recipe function f(p::PlotPulseHist; ybins = 1:1:0)
    waveforms = p.args[1]

    ybinning = if isempty(ybins)
        samples = flatview(waveforms)
        linspace(minimum(samples), maximum(samples), 256)
    else
        ybins
    end

    @series begin
        n = length(eachindex(waveforms))
        h = pulse_hist(waveforms, ybinning)
        x := h.edges[1]
        y := h.edges[2]
        z := Surface(h.weights)
        seriestype --> :bins2d
        title --> "Signal Overlay ($n waveforms)"
        xlabel --> "Time"
        ylabel --> "Amplitude"
        ()
    end
end

# export plot_pulse_hist2

"""
    plot_wfanalysis(wfanalysis::DataFrame)

Plot histograms of `wfanlysis.peak_integral`, `wfanlysis.peak_integral_short`
distribution of pre / post pulse baselines and PSD parameters.
"""
function plot_wfanalysis(wfanalysis::DataFrame)
    E_max = maximum(reduced_maximum.([
        wfanalysis.peak_integral,
        wfanalysis.peak_integral_short
    ]))

    plot(
        begin
            plot(
                pulse_hist(wfanalysis.waveform, -20:1:100),
                color = :viridis,
                title = "Signal Shapes",
                label = "Signal Overlay (All Signals)",
                xlabel = "Sample [4ns]",
                ylabel = "Counts"
            )
            #=
            plot!(
                mean(parent(wfanalysis[:waveform]), 2)[:],
                color = :red, linewidth = 2,
                label = "Averaged Signal Shape",
                xlabel = "Sample [4ns]",
                ylabel = "Counts"
            )
            =#
        end,
        begin
            stephist(
                wfanalysis.peak_integral,
                bins = linspace(0, E_max, 500),
                yscale = :log10,
                title = "Peak Integral",
                label = "Long window",
                xlabel = "ADC value",
                ylabel = "Counts"
            )
            stephist!(
                wfanalysis.peak_integral_short,
                bins = linspace(0, E_max, 500),
                yscale = :log10,
                label = "Short window",
                xlabel = "ADC value",
                ylabel = "Counts"
            )
        end,
        begin
            stephist(
                wfanalysis.postbl_level, yscale = :log10,
                bins = -6:0.1:6,
                title = "Post-Pulse Baseline Level",
                label = "",
                # label = "Post-Pulse",
                xlabel = "Integral",
                ylabel = "Counts"
            )
            #=
            stephist!(
                wfanalysis[:prebl_level], yscale = :log10,
                bins = -6:0.1:6,
                label = "Pre-Pulse",
                xlabel = "ADC value",
                ylabel = "Counts"
            )
            =#
        end,
        plot(
            fit(
                Histogram,
                (wfanalysis.peak_integral, wfanalysis.psa_speed),
                (linspace(0, E_max, 200), linspace(-0.2, 1.5, 200)), closed = :left
            ),
            color = :viridis,
            title = "PSA vs. Peak Integral",
            xlabel = "Peak integral (long)",
            ylabel = "PSA short/long integral"
        )
    )
end

export plot_wfanalysis

"""
"""
function plot_wfanalysis(pred::Function, wfanalysis::DataFrame, pred_cols::Symbol...)
    idxs = entrysel(pred, wfanalysis, pred_cols...)
    plot_wfanalysis(wfanalysis[idxs, :])
end

export plot_wfanalysis

"""
    time_norm_hist(wfanalysis::DataFrame, col::Symbol, bins::AbstractVector)

Rate normalized histogram of selected col of wfanalysis.
"""
function time_norm_hist(wfanalysis::DataFrame, col::Symbol, bins::AbstractVector)
    X = wfanalysis[col]
    timestamp = wfanalysis.timestamp
    rate = inv(maximum(timestamp) - minimum(timestamp))
    h = fit(Histogram{Float64}, X, bins, closed = :left)
    normalize!(h, mode = :density)
    h.weights .*= rate
    h
end

export time_norm_hist
