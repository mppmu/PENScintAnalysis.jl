# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

"""
    precalibrate_data(raw_data::DataFrame; <keyword arguments>)

Remove offset for timestamp and waveforms of input data.

Shifts timestamps by value of first timestamp, such that the first event starts at 0.
Calculates the mean value of the baseline then subtracts from ADC counts.

# Arguements
- `prebl_range::UnitRange{Int} = 1:32`: Range for the pre-trigger baseline.
- `postbl_range::UnitRange{Int} = 300:350`: Range for the post-trigger baseline.
"""
function precalibrate_data(
    raw_data::DataFrame;
    prebl_range::UnitRange{Int} = 1:32,
    postbl_range::UnitRange{Int} = 300:350
)
    timestamp = raw_data.timestamp .- first(raw_data.timestamp)

    int_waveforms = raw_data.waveform
    waveforms = av(triangular_dither.(Float32, flatview(int_waveforms)))

    orig_prebl_level = wf_range_sum(waveforms, prebl_range, window_weights(hamming, prebl_range))
    orig_postbl_level = wf_range_sum(waveforms, postbl_range, window_weights(hamming, postbl_range))

    # info("Mean original pre-pulse baseline level: $(mean(orig_prebl_level))")
    # info("Mean original post-pulse baseline level: $(mean(orig_postbl_level))")

    # wf_shift!(waveforms, waveforms, - (orig_prebl_level .+ orig_postbl_level) ./ 2)
    wf_shift!(waveforms, waveforms, - orig_prebl_level)

    DataFrame(
        channel = raw_data.channel,
        bufferno = raw_data.bufferno,
        timestamp = timestamp,
        waveform = waveforms
    )
end

export precalibrate_data

"""
    analyse_waveforms(precal_data::DataFrame; <keyword arguments>)

Compute integrals and related values for input waveforms.

# Arguements
- `prebl_range::UnitRange{Int} = 1:32`: Range for the pre-trigger baseline.
- `postbl_range::UnitRange{Int} = 300:350`: Range for the post-trigger baseline.
- `peak_range::UnitRange{Int} = 245:(245 + 40)`: Integral range for the peak.
- `peak_range_short::UnitRange{Int} = 251:(251 + 11)`: Integral range for the peak, shorter than `peak_range`.
- `noise_range::UnitRange{Int} = 180:(180+60)`: Range for expected noise.
"""
function analyse_waveforms(
    precal_data::DataFrame;
    prebl_range::UnitRange{Int} = 1:32,
    postbl_range::UnitRange{Int} = 300:350,
    peak_range::UnitRange{Int} = 245:(245 + 40),
    peak_range_short::UnitRange{Int} = 251:(251 + 11),
    noise_range::UnitRange{Int} = 180:(180+60)
)
    # info("Mean event rate: $(1 / mean(diff(precal_data[:timestamp]))) events/s")

    waveforms = precal_data.waveform

    T = eltype(flatview(waveforms))

    prebl_level = wf_range_sum(waveforms, prebl_range, window_weights(hamming, prebl_range))
    postbl_level = wf_range_sum(waveforms, postbl_range, window_weights(hamming, postbl_range))

    # info("Mean pre-pulse baseline level: $(mean(prebl_level))")
    # info("Mean post-pulse baseline level: $(mean(postbl_level))")

    peak_integral = wf_range_sum(waveforms, peak_range)
    peak_integral_short = wf_range_sum(waveforms, peak_range_short)
    noise_integral = - wf_range_sum(waveforms, noise_range)

    psa_speed = peak_integral_short ./ peak_integral
    psa_noise = noise_integral ./ peak_integral

    DataFrame(
        channel = precal_data.channel,
        bufferno = precal_data.bufferno,
        timestamp = precal_data.timestamp,
        waveform = waveforms,
        prebl_level = prebl_level,
        postbl_level = postbl_level,
        peak_integral = peak_integral,
        peak_integral_short = peak_integral_short,
        psa_speed = psa_speed,
        psa_noise = psa_noise,
    )
end

export analyse_waveforms
