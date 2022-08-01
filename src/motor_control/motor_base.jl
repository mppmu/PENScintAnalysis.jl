import Base: getindex, setindex!

abstract type  Absolute end
abstract type  Brake end
abstract type  ControlPosition end
abstract type  Info end
abstract type  Edges end
abstract type  Engine end
abstract type  Feedback end
abstract type  Hard end
abstract type  Home end
abstract type  Kind end
abstract type  Loft end
abstract type  Move end
abstract type  NameFRAM end
abstract type  NameStage end
abstract type  Position end
abstract type  Protection end
abstract type  Power end
abstract type  PID end
abstract type  Relative end
abstract type  Settings end
abstract type  SetZero end
abstract type  Soft end
abstract type  State end
abstract type  Status end
abstract type  Stop end


export Device

"""
    Device
Abstract super-class for devices.
"""
abstract type  Device end

const PrimType = Union{Bool, Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128, Float16, Float32, Float64}

function _value_to_tuple(x::T) where T
    types = Tuple(T.types)
    Tuple([getfield(x, i) for i in eachindex(types)])
end

_value_to_tuple(x::PrimType) = (x,)

function ximc_crc16(data::AbstractVector{UInt8})
    crc = UInt16(0xffff)
    for byte in data
        crc = xor(crc,byte);
        for bitno in 0:7
            a = crc;
            carry_flag = a & UInt16(0x0001);
            crc = crc >>> 1;
            if (carry_flag == 1)
                crc = UInt16(xor(crc, 0xa001))
            end
        end
    end
    crc::UInt16
end

@assert ximc_crc16(UInt8.([75, 29, 243])) == 49992


ximcio_to_jl(x) = ltoh(x)
jl_to_ximcio(x) = htol(x)


mutable struct XIMCString{N}
    bytes::NTuple{N, UInt8}
end

Base.read(io::IO, ::Type{XIMCString{N}}) where N = XIMCString((read(io, N)...))
Base.write(io::IO, ::Type{XIMCString{N}}) where N = write(io, x.bytes...)

ximcio_to_jl(x::XIMCString) = x
jl_to_ximcio(x::XIMCString) = x

Base.convert(::Type{String}, x::XIMCString) = String([x.bytes...])
Base.convert(::Type{XIMCString}, x::String) = XIMCString((String(x).data...))

XIMCString(x::String) = convert(XIMCString, x)
String(x::XIMCString) = convert(String, x)

Base.show(io::IO, x::XIMCString) = print(io,"XIMCString(\"$(String(x))\")")


mutable struct XIMCReserved{N}
    bytes::NTuple{N, UInt8}
end

Base.read(io::IO, ::Type{XIMCReserved{N}}) where N = XIMCReserved( Tuple(read(io, N)) )
Base.write(io::IO, x::XIMCReserved) = write(io, x.bytes...)

Base.show(io::IO, x::XIMCReserved) = print(io,"XIMCReserved(...)")



function _ximc_send_cmd(io::IO, cmd_code::String, data::Vector{UInt8} = UInt8[])
    @assert(length(cmd_code) == 4)
    if length(data) > 0
        crc = ximc_crc16(data)
        write(io, cmd_code, data, jl_to_ximcio(crc))
        # info("checksum = $crc")
    else
        write(io, cmd_code)
    end
end

function _ximc_send_cmd(io::IO, cmd_code::String, x)
    data_buf = IOBuffer()
    println(map(jl_to_ximcio, _value_to_tuple(x))...)
    write(data_buf, map(jl_to_ximcio, _value_to_tuple(x))...)
    data = take!(data_buf)
    _ximc_send_cmd(io, cmd_code, data)
end


function _ximc_read_resp(io::IO, cmd_code::String, n_data_bytes::Integer)
    @assert(length(cmd_code) == 4)
    @assert(n_data_bytes >= 0)

    with_data = n_data_bytes > 0

    nbytes_total = n_data_bytes + 4 + (with_data ? 2 : 0)
    # info("Reading $nbytes_total bytes")
    resp = read(io, nbytes_total)
    @assert(length(resp) == nbytes_total)
    buf = IOBuffer(resp)
    # info("_ximc_read_resp: resp = $resp")
    recv_cmd_bytes = read(buf, 4)
    recv_cmd = String(recv_cmd_bytes)
    # info("_ximc_read_resp: recv_cmd = $recv_cmd")
    (recv_cmd != cmd_code) && error("Received $recv_cmd, expected $cmd_code")
    if with_data
        data = read(buf, n_data_bytes)
        crc = ximcio_to_jl(read(buf, UInt16))
        # info("_ximc_read_resp: data = $data")
        crc_expected = ximc_crc16(data)
        (crc != crc_expected) && error("Checksum error, got 0x$(hex(crc)), expected 0x$(hex(crc_expected))")
        data::Vector{UInt8}
    else
        UInt8[]
    end
end

function _ximc_read_resp(io::IO, cmd_code::String, ::Type{T}) ::T where T
    types = T.types
    # println(types)
    n_data_bytes = sum(map(sizeof, types))
    data = _ximc_read_resp(io::IO, cmd_code::String, n_data_bytes)
    data_buf = IOBuffer(data)
    # println(map(U -> ximcio_to_jl(read(data_buf, U)), types)...)
    # println("rrg")
    T(map(U -> ximcio_to_jl(read(data_buf, U)), types)...)
end



export XIMCMotor

mutable struct XIMCMotor <: Device
    io
    # io::Lockable{IO}
end

XIMCMotor(hostname::AbstractString, port::Integer) =
    XIMCMotor(connect(hostname, port))

# XIMCMotor(hostname::AbstractString, port::Integer) =
#     XIMCMotor(Lockable{IO}(connect(hostname, port)))
#

function ximc_cmd(motor::XIMCMotor, cmd_code::String)
    _ximc_send_cmd(motor.io, cmd_code)
    _ximc_read_resp(motor.io, cmd_code, 0)
    nothing
end
# ximc_cmd(motor::XIMCMotor, cmd_code::String) = map(motor.io) do io
#     _ximc_send_cmd(io, cmd_code)
#     _ximc_read_resp(io, cmd_code, 0)
#     nothing
# end

function ximc_cmd(motor::XIMCMotor, cmd_code::String, x)
    _ximc_send_cmd(motor.io, cmd_code, x)
    _ximc_read_resp(motor.io, cmd_code, 0)
nothing
end

# ximc_cmd(motor::XIMCMotor, cmd_code::String, x) = map(motor.io) do io
#     _ximc_send_cmd(io, cmd_code, x)
#     _ximc_read_resp(io, cmd_code, 0)
#     nothing
# end

# ximc_qry(motor::XIMCMotor, cmd_code::String, ::Type{T}) where T = map(motor.io) do io
#     _ximc_send_cmd(io, cmd_code)
#     _ximc_read_resp(io, cmd_code, T)
# end

function ximc_qry(motor::XIMCMotor, cmd_code::String, ::Type{T}) where T
    _ximc_send_cmd(motor.io, cmd_code)
    _ximc_read_resp(motor.io, cmd_code, T)
end

export XIMCDeviceInformation

mutable struct XIMCDeviceInformation
    manufacturer::XIMCString{4}
    manufacturer_id::XIMCString{2}
    product_description::XIMCString{8}
    hw_version_major::UInt8
    hw_version_minor::UInt8
    hw_release::UInt16
    reserved::XIMCReserved{12}
end

getindex(motor::XIMCMotor, ::Info) = ximc_qry(motor, "geti", XIMCDeviceInformation)

export XIMCDeviceStatus

mutable struct XIMCDeviceStatus
    move_state::UInt8
    move_command_state::UInt8
    power_state::UInt8
    encoder_state::UInt8
    winding_state::UInt8
    current_position::Int32
    u_current_position::Int16
    encoder_position::Int64
    current_speed::Int32
    u_current_speed::Int16
    engine_current::Int16
    supply_voltage::Int16
    usb_current::Int16
    usb_voltage::Int16
    current_temperature::Int16
    flags::UInt32
    gpio_flags::UInt32
    cmd_buf_free_space::UInt8
    reserved::XIMCReserved{4}
end

getindex(motor::XIMCMotor, ::Type{Status}) = ximc_qry(motor, "gets", XIMCDeviceStatus)


export XIMCPosition

mutable struct XIMCPosition
    pos::Int32
    u_pos::Int16
    enc_pos::Int64
    pos_flags::Int8
    reserved::XIMCReserved{5}
end

getindex(motor::XIMCMotor, ::Type{Position}) = ximc_qry(motor, "gpos", XIMCPosition)
setindex!(motor::XIMCMotor, x::XIMCPosition, ::Type{Position}) = ximc_cmd(motor, "spos", x)


const BORDER_IS_ENCODER = 0x1
const BORDER_STOP_LEFT = 0x2
const BORDER_STOP_RIGHT = 0x4
const BORDERS_SWAP_MISSET_DETECTION = 0x8

const ENDER_SWAP = 0x1
const ENDER_SW1_ACTIVE_LOW = 0x2
const ENDER_SW2_ACTIVE_LOW = 0x4

export XIMCEdgesSettings

mutable struct XIMCEdgesSettings
    border_flags::UInt8
    ender_flags::UInt8
    left_border::Int32
    uleft_border::Int16
    right_border::Int32
    uright_border::Int16
    reserved::XIMCReserved{6}
end

getindex(motor::XIMCMotor, ::Type{Edges}, ::Type{Settings}) = ximc_qry(motor, "geds", XIMCEdgesSettings)
setindex!(motor::XIMCMotor, x::XIMCEdgesSettings, ::Type{Edges}, ::Type{Settings}) = ximc_cmd(motor, "seds", x)


const HOME_DIR_FIRST = 0x01
const HOME_DIR_SECOND = 0x02
const HOME_MV_SEC_EN = 0x04
const HOME_HALF_MV = 0x08
const HOME_STOP_FIRST_BITS = 0x30
const HOME_STOP_FIRST_REV = 0x10
const HOME_STOP_FIRST_SYN = 0x20
const HOME_STOP_FIRST_LIM = 0x30
const HOME_STOP_SECOND_BITS = 0xC0
const HOME_STOP_SECOND_REV = 0x40
const HOME_STOP_SECOND_SYN = 0x80
const HOME_STOP_SECOND_LIM = 0xC0

export XIMCHomeSettings

mutable struct XIMCHomeSettings
    fast_home_spd::UInt32
    ufast_home_spd::UInt8
    slow_home_spd::UInt32
    uslow_home_spd::UInt8
    home_delta::Int32
    uhome_delta::Int16
    home_flags::UInt16
    reserved::XIMCReserved{9}
end

getindex(motor::XIMCMotor, ::Type{Home}, ::Type{Settings}) = ximc_qry(motor, "ghom", XIMCHomeSettings)
setindex!(motor::XIMCMotor, x::XIMCHomeSettings, ::Type{Home}, ::Type{Settings}) = ximc_cmd(motor, "shom", x)



const FEEDBACK_ENCODER = 0x1
const FEEDBACK_ENCODERHALL = 0x3
const FEEDBACK_EMF = 0x4
const FEEDBACK_NONE = 0x5

const FEEDBACK_ENC_REVERSE = 0x1
const FEEDBACK_HALL_REVERSE = 0x2

export XIMCFeedbackSettings
mutable struct XIMCFeedbackSettings
    ips::UInt16
    feedback_type::UInt8
    feedback_flags::UInt8
    hall_spr::UInt16
    hall_shift::Int8
    reserved::XIMCReserved{5}
end

getindex(motor::XIMCMotor, ::Type{Feedback}, ::Type{Settings}) = ximc_qry(motor, "gfbs", XIMCFeedbackSettings)
setindex!(motor::XIMCMotor, x::XIMCFeedbackSettings, ::Type{Feedback}, ::Type{Settings}) = ximc_cmd(motor, "sfbs", x)


export XIMCMoveSettings

mutable struct XIMCMoveSettings
    speed::UInt32
    u_speed::UInt8
    accel::UInt16
    decel::UInt16
    antiplay_speed::UInt32
    u_aptiplay_speed::UInt8
    reserved::XIMCReserved{10}
end

#=  03.04. modified integer sizes and types
type XIMCMoveSettings
    speed::UInt8                   +6
    u_speed::UInt8
    accel::Int32                   -4
    decel::Int16
    antiplay_speed::Int32
    u_aptiplay_speed::Int16        -2
    reserved::XIMCReserved{10}
end
=#

getindex(motor::XIMCMotor, ::Type{Move}, ::Type{Settings}) = ximc_qry(motor, "gmov", XIMCMoveSettings)
setindex!(motor::XIMCMotor, x::XIMCMoveSettings, ::Type{Move}, ::Type{Settings}) = ximc_cmd(motor, "smov", x)


const ENGINE_TYPE_NONE      = 0x00 # A value that shouldn't be used.
const ENGINE_TYPE_DC        = 0x01 # DC motor.
const ENGINE_TYPE_2DC       = 0x02 # 2 DC motors.
const ENGINE_TYPE_STEP      = 0x03 # Step motor.
const ENGINE_TYPE_TEST      = 0x04 # Duty cycle are fixed. Used only manufacturer.
const ENGINE_TYPE_BRUSHLESS = 0x05 # Brushless motor.

export XIMCEngineKind

mutable struct XIMCEngineKind
    engine_type::UInt8
    driver_type::UInt8
    reserved::XIMCReserved{6}
end

getindex(motor::XIMCMotor, ::Type{Engine}, ::Type{Kind}) = ximc_qry(motor, "gent", XIMCEngineKind)
#Remove comment to implement "sent"# setindex!(motor::XIMCMotor, x::XIMCEngineKind, ::Type{Engine}, ::Type{Kind}) = ximc_cmd(motor, "sent", x)

# Enginge Flags
const ENGINE_REVERSE        = 0x01 # Reverse positive direction of engine shaft rotation
const ENGINE_MAX_SPEED      = 0x04 # If set, maximum achievable speed with current settings is used as nominal speed
const ENGINE_ANTIPLAY       = 0x08 # Activate play compensation procedure
const ENGINE_ACCEL_ON       = 0x10 # Activate smooth acceleration-deceleration for movements
const ENGINE_LIMIT_VOLT     = 0x20 # Only for DC motor
const ENGINE_LIMIT_CURR     = 0x40 # Only for DC motor
const ENGINE_LIMIT_RPM      = 0x80 # Enable motor speed limit

#Microstep Modes - step size is 1/"FRAC_X" - ranges from full step mode to 1/256 step mode
const MICROSTEP_MODE_FULL       = 0x01
const MICROSTEP_MODE_FRAC_2     = 0x02
const MICROSTEP_MODE_FRAC_4     = 0x03
const MICROSTEP_MODE_FRAC_8     = 0x04
const MICROSTEP_MODE_FRAC_16    = 0x05
const MICROSTEP_MODE_FRAC_32    = 0x06
const MICROSTEP_MODE_FRAC_64    = 0x07
const MICROSTEP_MODE_FRAC_128   = 0x08
const MICROSTEP_MODE_FRAC_256   = 0x09

export XIMCEngineSettings

mutable struct XIMCEngineSettings
    nom_voltage::UInt16
    nom_current::UInt16
    nom_speed::UInt32
    u_nom_speed::UInt8
    engine_flags::UInt16
    antiplay::Int16
    microstep_mode::UInt8
    steps_per_rev::UInt16
    reserved::XIMCReserved{12}
end

getindex(motor::XIMCMotor, ::Type{Engine}, ::Type{Settings}) = ximc_qry(motor, "geng", XIMCEngineSettings)
setindex!(motor::XIMCMotor, x::XIMCEngineSettings, ::Type{Engine}, ::Type{Settings}) = ximc_cmd(motor, "seng", x)


(motor::XIMCMotor)(::Type{Stop}) = motor(Stop, Soft)
(motor::XIMCMotor)(::Type{Stop}, ::Type{Hard}) = ximc_cmd(motor, "stop")
(motor::XIMCMotor)(::Type{Stop}, ::Type{Soft}) = ximc_cmd(motor, "sstp")

(motor::XIMCMotor)(::Type{Loft}) = ximc_cmd(motor, "loft")  #Execute play compensation movement


#PowerFlags
const POWER_REDUCT_ENABLED  = 0x01
const POWER_OFF_ENABLED     = 0x02 # Power off after PowerOffDelay
const POWER_SMOOTH_CURRENT  = 0x04 # Smooth current ramp up/down during current_set_time

export XIMCPowerSettings

mutable struct XIMCPowerSettings
    hold_current::UInt8
    curr_reduct_delay::UInt16
    power_off_delay::UInt16
    current_set_time::UInt16
    power_flags::UInt8
    reserved::XIMCReserved{6}
end

getindex(motor::XIMCMotor, ::Type{Power}, ::Type{Settings}) = ximc_qry(motor, "gpwr", XIMCPowerSettings)
setindex!(motor::XIMCMotor, x::XIMCPowerSettings, ::Type{Power}, ::Type{Settings}) = ximc_cmd(motor, "spwr", x)


setindex!(motor::XIMCMotor, x::Bool, ::Type{Power}, ::Type{State}) =
    !x && ximc_cmd(motor, "pwof")

#Protection - Critical Parameter flags - enable conditions to enter ALARM state
const ALARM_ON_DRIVER_OVERHEATING   = 0x01
const LOW_UPWR_PROTECTION           = 0x02
const H_BRIDGE_ALERT                = 0x04
const ALARM_ON_BORDERS_SWAP_MISSET  = 0x08
const ALARM_FLAGS_STICKING          = 0x10 # If set, only STOP command can turn alarms to 0
const USB_BREAK_RECONNECT           = 0x20

export XIMCProtectionSettings

mutable struct XIMCProtectionSettings
    low_volt_pwr_off::UInt16
    critical_curr_pwr::UInt16
    critical_volt_pwr::UInt16
    critical_temp::UInt16
    critical_curr_usb::UInt16
    critical_volt_usb::UInt16
    minimum_volt_usb::UInt16
    flags::UInt8
    reserved::XIMCReserved{7}
end

getindex(motor::XIMCMotor, ::Type{Protection}, ::Type{Settings}) = ximc_qry(motor, "gsec", XIMCProtectionSettings)
setindex!(motor::XIMCMotor, x::XIMCProtectionSettings, ::Type{Protection}, ::Type{Settings}) = ximc_cmd(motor, "ssec", x)


export XIMCPIDSettings

mutable struct XIMCPIDSettings
    kp_u::UInt16
    ki_u::UInt16
    kd_u::UInt16
    reserved::XIMCReserved{36}
end

getindex(motor::XIMCMotor, ::Type{PID}, ::Type{Settings}) = ximc_qry(motor, "gpid", XIMCPIDSettings)
#Remove comment to implement "spid"# setindex!(motor::XIMCMotor, x::XIMCPIDSettings, ::Type{PID}, ::Type{Settings}) = ximc_cmd(motor, "spid", x)


#Brake flags
const BRAKE_ENABLED     = 0x01
const BRAKE_ENG_PWROFF  = 0x02   # Brake turns off power on step motor

export XIMCBrakeSettings

mutable struct XIMCBrakeSettings
    t1::UInt16              #time[ms] between motor pwr on and brake off
    t2::UInt16              #time[ms] between brake off and move ready
    t3::UInt16              #time[ms] between motor stop and brake on
    t4::UInt16              #time[ms] between brake on and motor pwr off
    brake_flags::UInt8
    reserved::XIMCReserved{10}
end

getindex(motor::XIMCMotor, ::Type{Brake}, ::Type{Settings}) = ximc_qry(motor, "gbrk", XIMCBrakeSettings)
setindex!(motor::XIMCMotor, x::XIMCBrakeSettings, ::Type{Brake}, ::Type{Settings}) = ximc_cmd(motor, "sbrk", x)


#Control Position Flags
const CTP_ENABLED           = 0x01
const CTP_BASE              = 0x02
const CTP_ALARM_ON_ERROR    = 0x04
const REV_SENS_INV          = 0x08
const CTP_ERROR_CORRECTION  = 0x10

export XIMCControlPositionSettings

struct XIMCControlPositionSettings
    ctp_min_error::UInt8
    ctp_flags::UInt8
    reserved::XIMCReserved{10}
end

getindex(motor::XIMCMotor, ::Type{ControlPosition}, ::Type{Settings}) = ximc_qry(motor, "gctp", XIMCControlPositionSettings)
setindex!(motor::XIMCMotor, x::XIMCControlPositionSettings, ::Type{ControlPosition}, ::Type{Settings}) = ximc_cmd(motor, "sctp", x)


#CtrlFlags
const EEPROM_PRECEDENCE = 0x01

export XIMCNameFRAMSettings

struct XIMCNameFRAMSettings
    controller_name::XIMCString{16}
    ctrl_flags::UInt8
    reserved::XIMCReserved{7}
end

getindex(motor::XIMCMotor, ::Type{NameFRAM}, ::Type{Settings}) = ximc_qry(motor, "gnmf", XIMCNameFRAMSettings)
setindex!(motor::XIMCMotor, x::XIMCNameFRAMSettings, ::Type{NameFRAM}, ::Type{Settings}) = ximc_cmd(motor, "snmf", x)


export XIMCNameStageSettings

struct XIMCNameStageSettings
    positioner_name::XIMCString{16}
    reservred::XIMCReserved{8}
end

getindex(motor::XIMCMotor, ::Type{NameStage}, ::Type{Settings}) = ximc_qry(motor, "gnme", XIMCNameStageSettings)
setindex!(motor::XIMCMotor, x::XIMCNameStageSettings, ::Type{NameStage}, ::Type{Settings}) = ximc_cmd(motor, "snme", x)


getindex(motor::XIMCMotor, ::Type{Position}, ::Type{SetZero}) =
    ximc_cmd(motor, "zero")

#(motor::XIMCMotor)(::Type{Position}, ::Type{SetZero}) =
#    ximc_cmd(motor, "zero")


struct XIMCCommandMove
    position::Int32
    u_position::Int16
    reserved::XIMCReserved{6}
end

XIMCCommandMove(p, u_p = 0) = XIMCCommandMove(p, u_p, XIMCReserved(Tuple(zeros(UInt8, 6))))


setindex!(motor::XIMCMotor, x::Real, ::Type{Move}, ::Type{Absolute}) =
    ximc_cmd(motor, "move", XIMCCommandMove(x))


setindex!(motor::XIMCMotor, x::Symbol, ::Type{Move}, ::Type{Absolute}) = begin
    if x == :home
        ximc_cmd(motor, "home")
    else
        error("Invalid target position $x")
    end
end


struct XIMCCommandMovr
    delta_position::Int32
    u_delta_position::Int16
    reserved::XIMCReserved{6}
end

XIMCCommandMovr(p, u_p = 0) = XIMCCommandMovr(p, u_p, XIMCReserved(Tuple(zeros(UInt8, 6))))


setindex!(motor::XIMCMotor, x::Real, ::Type{Move}, ::Type{Relative}) =
    ximc_cmd(motor, "movr", XIMCCommandMovr(x))