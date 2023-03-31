"""
        take_pmt_data(hv_settings::Dict, adc_settings::NamedTuple)

Ramps up HV for PMTs using voltage_goto and attempts data-taking via take_struck_data.
...
# Arguments
- `hv_settings::Dict`: NamedTuple containing HV settings. See example.
- `adc_settings::NamedTuple`: NamedTuple containing ADC(as of 2023: SIS3316/Struck) settings. See take_struck_data for more info.
- `callback::Function`: Optional function; will be executed whenever the measurement state changes, i.e. a new chunk of data is received, HV is ramping up etc. See PMT_MEASUREMENT_STATES in take_struck_data for reference
- `stop_taking::Function`: Optional function; checked at the beginning of the acquisition of any chunk; if it returns true, remaining measurements are cancelled

# Example settings
- `hv_settings = Dict(`
`"ip" => "ws://HV_CONTROL_ADDRESS:HV_CONTROL_PORT"`,
`"login_payload" => JSON.json(Dict("i"=>"", "t" => "login", "c"=> Dict("l"=>"USERNAME", "p"=>"PASSWORD", "t" => ""), "r" => "websocket")),`
`"ramp_up_HV" => true, # change to false if the HV is already on`
`"ramp_down_HV" => true, # change to false if the HV should stay powered on after the measurement`
`"channels" => Dict(`
`"4" => -940,`
`)`
`)`
...
"""
function take_pmt_data(hv_settings::Dict, adc_settings::NamedTuple; callback = (ms::measurement_state)->false, stop_taking = ()->false )
    # Print out HV before measurement
    PENScintAnalysis.get_measured_HV(hv_settings["ip"], hv_settings["login_payload"])

    # Ramp HV for all channels, if desired
    if hv_settings["ramp_up_HV"]
        pbars = Dict()
        @info "Ramping up PMT HV"

        if callback isa Function
            ms = measurement_state(STATE_HV_RAMP_UP, "Ramping up voltages of channels " * join(collect(keys(hv_settings["channels"])), ", "))
            ms.opt = hv_settings["channels"]
            callback(ms)
        end

        for (k,v) in hv_settings["channels"]
            cid = parse(Int64, k)
            PENScintAnalysis.voltage_goto(hv_settings["ip"], cid, v, hv_settings["login_payload"])
            pbars[cid] = ProgressThresh(v, "Ramping voltage of channel " * string(cid) * ":")
        end

        const_voltage_reached = false
        while !const_voltage_reached
            voltages = PENScintAnalysis.get_measured_HV(hv_settings["ip"], hv_settings["login_payload"])
            n_reached = 0

            for (k, target_voltage) in hv_settings["channels"]
                cid = parse(Int64, k)
                measured_voltage = voltages[cid + 1]
                
                ProgressMeter.update!(pbars[cid], round(measured_voltage))
                if abs(abs(measured_voltage) - abs(target_voltage)) < 1
                    n_reached += 1
                end
            end

            if n_reached == length(hv_settings["channels"])
                const_voltage_reached = true
            end

            sleep(1)
        end
    end

    # Again, print voltages for confirmation everything is correct
    @info PENScintAnalysis.get_measured_HV(hv_settings["ip"], hv_settings["login_payload"])

    # Do the measurement. Wrap everything in a try-catch-block, so at least the voltage will be reset to 0 if anything goes wrong
    written_files = []
    try
        # Set measurement parameters
        # Moved to data_taking_rev2_settings.jl
        include("data_taking_rev2_settings.jl")

        @info "Start taking data"
        written_files = PENScintAnalysis.take_struck_data(adc_settings; callback=callback, stop_taking=stop_taking)
        @info "Stop taking data"
    catch e
        @error "Measurement failed. Make sure the fadc is running, you're running the code within the legend(-base) container on glab-pc01 and correct permissions are set on the directory. If you can ping the struck and think everything is set up correctly, do a test using struck-test-gui. Execute that on a Linux host with Desktop functionality connecting via ssh -X gelab@gelab-pc.. and check connection as well as Test in the sub-menu. This helps to spin up a Struck if a restart alone did not help "
        print(e.msg)
    end

    if hv_settings["ramp_down_HV"]
        @info "Ramping down PMT voltages to 0V"

        if callback isa Function
            ms = measurement_state(STATE_HV_RAMP_DOWN, "Ramping down voltages of channels " * join(collect(keys(hv_settings["channels"])), ", "))
            ms.opt = collect(keys(hv_settings["channels"]))
            callback(ms)
        end

        pbars = Dict()
        for (k,v) in hv_settings["channels"]
            cid = parse(Int64, k)
            PENScintAnalysis.voltage_goto(hv_settings["ip"], cid, 0, hv_settings["login_payload"])
            pbars[cid] = ProgressThresh(0, "Ramping down voltage of channel " * string(cid) * ":")
        end

        const_voltage_reached = false
        while !const_voltage_reached
            voltages = PENScintAnalysis.get_measured_HV(hv_settings["ip"], hv_settings["login_payload"])
            n_reached = 0

            for (k, target_voltage) in hv_settings["channels"]
                cid = parse(Int64, k)
                measured_voltage = abs(voltages[cid + 1])
                
                ProgressMeter.update!(pbars[cid], round(measured_voltage))
                if measured_voltage < 1
                    n_reached += 1
                end
            end

            if n_reached == length(hv_settings["channels"])
                const_voltage_reached = true
            end

            sleep(1)
        end
    end

    #Print to confirm voltage is zero 
    @info PENScintAnalysis.get_measured_HV(hv_settings["ip"], hv_settings["login_payload"])

    @info "Finished"

    if !hv_settings["ramp_down_HV"]
        @warn WARNING: HV STILL HIGH!!!
    end

    if callback isa Function
        ms = measurement_state(STATE_IDLE, "Ready for data-taking")
        callback(ms)
    end

    written_files
end
export take_pmt_data