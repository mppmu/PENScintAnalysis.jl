# This file is a part of PENScintAnalysis.jl, licensed under the MIT License (MIT).

function precalibrate_data(
    raw_data::DataFrame;
    prebl_range::UnitRange{Int} = 1:64,
    postbl_range::UnitRange{Int} = 385:512
)
    timestamp = raw_data[:timestamp] .- first(raw_data[:timestamp])

    int_waveforms = raw_data[:waveforms]
    waveforms = av(triangular_dither.(Float32, parent(int_waveforms)))

    orig_prebl_level = wf_range_sum(waveforms, prebl_range, window_weights(hamming, prebl_range))
    orig_postbl_level = wf_range_sum(waveforms, postbl_range, window_weights(hamming, postbl_range))

    # info("Mean original pre-pulse baseline level: $(mean(orig_prebl_level))")
    # info("Mean original post-pulse baseline level: $(mean(orig_postbl_level))")

    # wf_shift!(waveforms, waveforms, - (orig_prebl_level .+ orig_postbl_level) ./ 2)
    wf_shift!(waveforms, waveforms, - orig_prebl_level)

    DataFrame(
        channel = raw_data[:channel],
        bufferno = raw_data[:bufferno],
        timestamp = timestamp,
        waveforms = waveforms
    )
end

export precalibrate_data


function analyse_waveforms(
    precal_data::DataFrame;
    prebl_range::UnitRange{Int} = 1:64,
    postbl_range::UnitRange{Int} = 385:512,
    peak_range::UnitRange{Int} = 245:(245 + 40),
    peak_range_short::UnitRange{Int} = 252:(252 + 5),
    noise_range::UnitRange{Int} = 180:(180+60)
)
    # info("Mean event rate: $(1 / mean(diff(precal_data[:timestamp]))) events/s")

    waveforms = precal_data[:waveforms]

    T = eltype(parent(waveforms))

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
        channel = precal_data[:channel],
        bufferno = precal_data[:bufferno],
        timestamp = precal_data[:timestamp],
        waveforms = waveforms,
        prebl_level = prebl_level,
        postbl_level = postbl_level,
        peak_integral = peak_integral,
        peak_integral_short = peak_integral_short,
        psa_speed = psa_speed,
        psa_noise = psa_noise,
    )
end

export analyse_waveforms
