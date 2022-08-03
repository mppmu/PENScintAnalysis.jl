function _construct_request(i, command, item, c = "*", v = "", u = "")
    return JSON.json(
    Dict(
    "i"=>i,
    "t" => "request",
    "c" => [
    Dict("c"=> command,
        "p" => Dict( #parameters
            "p"=> Dict(
                "l"=> "0",  # line (0)
    			"a"=> "*",   #address (every device in line 0)
    			"c"=> c
                ),
            "i" => item,
            "v" => v,
            "u" => u
        )
    )
    ],
    "r" => "websocket")
    )
end


function _issue_command(ip, login_payload, command::String, item::String, channel::String = "*", value::String = "", unit::String = "")
    results = []
    HTTP.WebSockets.open(ip) do ws
           write(ws, login_payload)
           d = JSON.parse(String(readavailable(ws)))
           session_id = d["i"]
           #@show session_id
           write(ws, _construct_request(session_id, command, item, channel, value, unit))
           d = JSON.parse(String(readavailable(ws)))
           push!(results, d)
           sleep(1)
    end
   results
end

"""
        get_measured_HV(ip, login_payload)
Get measured voltage for channels 1 to 8. This may ary from the set value.
"""

function get_measured_HV(ip, login_payload)
    results = []
    HTTP.WebSockets.open(ip) do ws
               write(ws, login_payload)
               d = JSON.parse(String(readavailable(ws)))
               session_id = d["i"]
               #@show session_id
               write(ws, _construct_request(session_id, "getItem", "Status.voltageMeasure"))
               d = JSON.parse(String(readavailable(ws)))
               push!(results, d)
           end;
    d = results[1]
    return parse(Float64,d[1]["c"][1]["d"]["v"]), 
        parse(Float64,d[1]["c"][2]["d"]["v"]),
        parse(Float64,d[1]["c"][3]["d"]["v"]),
        parse(Float64,d[1]["c"][4]["d"]["v"]),
        parse(Float64,d[1]["c"][5]["d"]["v"]),
        parse(Float64,d[1]["c"][6]["d"]["v"]),
        parse(Float64,d[1]["c"][7]["d"]["v"]),
        parse(Float64,d[1]["c"][8]["d"]["v"])
end
export get_measured_HV

"""
        get_set_HV(ip = ip, login_payload)
Get set voltage for channels 1 to 8. This may vary from the measured value.
"""

function get_set_HV(ip, login_payload)
    results = []
    HTTP.WebSockets.open(ip) do ws
               write(ws, login_payload)
               d = JSON.parse(String(readavailable(ws)))
               session_id = d["i"]
               #@show session_id
               write(ws, _construct_request(session_id, "getItem", "Control.voltageSet"))
               d = JSON.parse(String(readavailable(ws)))
               push!(results, d)
           end;
    d = results[1]
    return parse(Float64,d[1]["c"][1]["d"]["v"]), 
        parse(Float64,d[1]["c"][2]["d"]["v"]), 
        parse(Float64,d[1]["c"][3]["d"]["v"]), 
        parse(Float64,d[1]["c"][4]["d"]["v"]), 
        parse(Float64,d[1]["c"][5]["d"]["v"]), 
        parse(Float64,d[1]["c"][6]["d"]["v"]), 
        parse(Float64,d[1]["c"][7]["d"]["v"]), 
        parse(Float64,d[1]["c"][8]["d"]["v"])
end
export get_set_HV

"""
        set_HV(ip::String, c::Int, v::Real, login_payload)
Set voltage for one channel.
...
# Arguments
- `ip::String`: IP string of the HV device, e.g. "ws://123.123.123.123:8080" 
- `c::Int`: Channel number
- `v::Real`: HV level
...
"""

function set_HV(ip::String, c::Int, v::Real, login_payload)
    results = []
    HTTP.WebSockets.open(ip) do ws
               write(ws, login_payload)
               d = JSON.parse(String(readavailable(ws)))
               session_id = d["i"]
               #@show session_id
               write(ws, _construct_request(session_id, "setItem", "Control.voltageSet", "$c", "$v", "V"))
               d = JSON.parse(String(readavailable(ws)))
               push!(results, d)
           end;
    d = results[1][1]
    return d["trigger"]
end
export set_HV

function ramp_up(ip::String, c::Int, login_payload)
    results = []
    HTTP.WebSockets.open(ip) do ws
           write(ws, login_payload)
           d = JSON.parse(String(readavailable(ws)))
           session_id = d["i"]
           #@show session_id
           write(ws, _construct_request(session_id, "setItem", "Control.on", "$c", "1", ""))
           d = JSON.parse(String(readavailable(ws)))
           push!(results, d)
    end;
    d = results[1][1]
    return d["trigger"]
end
export ramp_up


function ramp_down(ip::String, c::Int, login_payload)
    results = []
    HTTP.WebSockets.open(ip) do ws
           write(ws, login_payload)
           d = JSON.parse(String(readavailable(ws)))
           session_id = d["i"]
           #@show session_id
           write(ws, _construct_request(session_id, "setItem", "Control.on", "$c", "0", ""))
           d = JSON.parse(String(readavailable(ws)))
           push!(results, d)
    end;
    d = results[1][1]
    return d["trigger"]
end
export ramp_down


function get_rampspeedUp(ip, login_payload)
    results = _issue_command(ip, login_payload, "getItem", "Control.voltageRampspeedUp")
    d = results[1]
    return parse(Float64,d[1]["c"][1]["d"]["v"]), 
        parse(Float64,d[1]["c"][2]["d"]["v"]), 
        parse(Float64,d[1]["c"][3]["d"]["v"]), 
        parse(Float64,d[1]["c"][4]["d"]["v"]), 
        parse(Float64,d[1]["c"][5]["d"]["v"]), 
        parse(Float64,d[1]["c"][6]["d"]["v"]), 
        parse(Float64,d[1]["c"][7]["d"]["v"]), 
        parse(Float64,d[1]["c"][8]["d"]["v"])
end
export get_rampspeedUp


function set_rampspeedUp(ip, channel, value, login_payload)
    results = _issue_command(ip, login_payload, "setItem", "Control.voltageRampspeedUp", "$channel", "$value", "V/s")
    d = results[1][1]
    return d["trigger"]
end
export set_rampspeedUp


function get_rampspeedDown(ip, login_payload)
    results = _issue_command(ip, login_payload, "getItem", "Control.voltageRampspeedDown")
    d = results[1]
    return parse(Float64,d[1]["c"][1]["d"]["v"]), 
        parse(Float64,d[1]["c"][2]["d"]["v"]), 
        parse(Float64,d[1]["c"][3]["d"]["v"]), 
        parse(Float64,d[1]["c"][4]["d"]["v"]), 
        parse(Float64,d[1]["c"][5]["d"]["v"]), 
        parse(Float64,d[1]["c"][6]["d"]["v"]), 
        parse(Float64,d[1]["c"][7]["d"]["v"]), 
        parse(Float64,d[1]["c"][8]["d"]["v"])
end
export get_rampspeedDown


function set_rampspeedDown(ip, channel, value, login_payload)
    results = _issue_command(ip, login_payload, "setItem", "Control.voltageRampspeedDown", "$channel", "$value", "V/s")
    d = results[1][1]
    return d["trigger"]
end
export set_rampspeedDown


function voltage_goto(ip::String, channel::Int, value::Real, login_payload)
    results = []
    HTTP.WebSockets.open(ip) do ws
           write(ws, login_payload)
           d = JSON.parse(String(readavailable(ws)))
           session_id = d["i"]
           #@show session_id
           write(ws, _construct_request(session_id, "setItem", "Control.voltageSet", "$channel", "$value", "V"))
           d = JSON.parse(String(readavailable(ws)))
           push!(results, d)
           sleep(1)
           @info "Channel $channel: set Voltage: $value V\nstarting ramp ..."
           write(ws, _construct_request(session_id, "setItem", "Control.on", "$channel", "1", ""))
           d = JSON.parse(String(readavailable(ws)))
           push!(results, d)
    end;
    #d = results[2][1]
    #println(results)
    #return d["trigger"]
end
export voltage_goto