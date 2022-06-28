export mymotor
function mymotor()::Array{XIMCMotor,1}
	m = [
           XIMCMotor("gelab-serial03", 2001),
           XIMCMotor("gelab-serial03", 2011)
       ]
	Initialize(m)
	return m
end

function _Initialize(motor::XIMCMotor)
	fbs1 = motor[Feedback, Settings]
	sleep(1)
	fbs1.feedback_flags = 0x01
	motor[Feedback, Settings] = fbs1
	sleep(1)
	# @assert fbs1 == motor[1][Feedback, Settings]

	hms1 = motor[Home, Settings]
	sleep(1)
	hms1.fast_home_spd = 1000
	hms1.home_delta = 0	 	 #was 50 before
	hms1.home_flags = 0x0173 #was 0x0071 before
	motor[Home, Settings] = hms1
	# @assert motor[1][Home, Settings] == hms1

	sleep(1)
	mvs1 = motor[Move, Settings]
	sleep(1)
	mvs1.speed = 500  #was 25 before
	mvs1.accel = 500  #was 25 before
	mvs1.decel = 500  #was 25 before
	mvs1.antiplay_speed = 500 # was 5 before
	motor[Move, Settings] = mvs1
	# @assert mvs1 == motor[1][Move, Settings]

	sleep(1)
	ens1 = motor[Engine, Settings]
	sleep(1)
	ens1.engine_flags = 0x91 #was 0x99 before
	motor[Engine, Settings] = ens1
	# @assert ens1 == motor[1][Engine, Settings]

	pws1 = motor[Power, Settings]
	pws1.power_off_delay = 2
	motor[Power, Settings] = pws1
	# @assert pws1 == motor[1][Power, Settings]
end

export Initialize
function Initialize(motor::Array{XIMCMotor,1})
	_Initialize(motor[1])
	_Initialize(motor[2])
    @info "Motors succefully initialized!"
end



#Calibration functions

function _Calibrate(motor::XIMCMotor)
	motor[Move, Absolute] = :home
	#block until it arrives "home"
	currentpos = _Pos(motor)
	sleep(2)
	while abs(_Pos(motor) - currentpos) > 0.001
		currentpos = _Pos(motor)
		sleep(2)
	end
	pos = motor[Position]
	sleep(1)
	pos.pos = 0
	pos.enc_pos = 0
	motor[Position] = pos
end

export Calibrate
function Calibrate(motor::Array{XIMCMotor,1})
    CalibrateX(motor)
    CalibrateY(motor)
end

export CalibrateX
function CalibrateX(motor::Array{XIMCMotor,1})
    @info "Calibrating X motor stage"
    _Calibrate(motor[1])
end

export CalibrateY
function CalibrateY(motor::Array{XIMCMotor,1})
    @info "Calibrating Y motor stage"
    _Calibrate(motor[2])
end


#Movement functions

function _MoveMM(pos, motor::XIMCMotor; block_till_arrival = true)
	if 0 <= pos <= 100
	    motor[Move, Absolute] = round(pos * -400)
	    if block_till_arrival == true
	        i_cnt = 0
	        while abs(_Pos(motor) - pos) > 0.1
	            if i_cnt%30 == 0
	                motor[Move, Absolute] = round(pos * -400)
	            end
	            sleep(1)
	            i_cnt +=1
	        end
	        motor[Move, Absolute] = round(pos * -400)
	        sleep(1)
	        @info("arrived at $(round(_Pos(motor),digits = 2))mm")
	    end
	else
		@info "Position $(pos)mm is not supported. Please enter a value between 0 and 100"
	end

end

export XMoveMM
function XMoveMM(pos, motor::Array{XIMCMotor,1}; block_till_arrival = true)
    @info("Moving X-motor to $(pos)mm\n")
	_MoveMM(pos, motor[1], block_till_arrival = block_till_arrival)
end

export YMoveMM
function YMoveMM(pos, motor::Array{XIMCMotor,1}; block_till_arrival = true)
    @info("Moving Y-motor to $(pos)mm\n")
    _MoveMM(pos, motor[2], block_till_arrival = block_till_arrival)
end


#Position functions

function _Pos(motor::XIMCMotor)::Float64
	if motor[Position].pos == 0 return 0.0 end
    return motor[Position].pos/(-400.)
end

export PosX
function PosX(motor::Array{XIMCMotor,1})
	_Pos(motor[1])
end

export PosY
function PosY(motor::Array{XIMCMotor,1})
	_Pos(motor[2])
end

export Pos
function Pos(motor::Array{XIMCMotor,1})
	println("X: \t$(PosX(motor)) mm")
	println("Y: \t$(PosY(motor)) mm")
end