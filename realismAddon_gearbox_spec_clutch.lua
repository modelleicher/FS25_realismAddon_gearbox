-- by modelleicher 

-- this is an extension of realismAddon_gearbox_spec but with everything specific to the clutch 
-- features so far, fluidClutch and keyboard clutch (automatic opening of clutch at braking, automatic slow closing of clutch when using keyboard)




realismAddon_gearbox_spec_clutch = {} 


local KEYBOARD_CLUTCH_MOVING_SPEED = 0.001
local KEYBOARD_CLUTCH_MINIMUM_ENGAGEMENT = 0.1


function realismAddon_gearbox_spec_clutch.prerequisitesPresent(specializations)
    return true
end


function realismAddon_gearbox_spec_clutch.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", realismAddon_gearbox_spec_clutch)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", realismAddon_gearbox_spec_clutch)
end

function realismAddon_gearbox_spec_clutch.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "startClutchMovementOpen", realismAddon_gearbox_spec_clutch.startClutchMovementOpen)
 	SpecializationUtil.registerFunction(vehicleType, "startClutchMovementClose", realismAddon_gearbox_spec_clutch.startClutchMovementClose)   
   	SpecializationUtil.registerFunction(vehicleType, "calculateClutchMovement", realismAddon_gearbox_spec_clutch.calculateClutchMovement)     
end

function realismAddon_gearbox_spec_clutch:onLoad(savegame)

    local spec = self.spec_realismAddon_gearbox
    local motor = self.spec_motorized.motor  

	-- get config key and default key 
	local key, _ = ConfigurationUtil.getXMLConfigurationKey(self.xmlFile,  self.configurations.motor, "vehicle.motorized.motorConfigurations.motorConfiguration", "vehicle.motorized", "motor")
	local defaultKey = "vehicle.motorized.motorConfigurations.motorConfiguration(0)"

    -- since we don't use the predefined xml Schemas we need to use the handle of the XML file
    local xml = self.xmlFile.handle    
    

    -- universal auto clutch for playing without analog clutch pedal
    -- this is to open the clutch when brake is applied and rpm is below certain value, close again when accelerator is applied
    spec.keyboardClutch = {}
    spec.keyboardClutch.openTime = 100
    spec.keyboardClutch.closingTime = 1000

    spec.keyboardClutch.clutchPercent = 0

    spec.keyboardClutch.lastManualClutchPedalRaw = 0
    spec.keyboardClutch.buttonClutchOverride = 0

    spec.keyboardClutch.state = 1

    spec.keyboardClutch.lastRpm = motor.minRpm
    spec.keyboardClutch.moving = false
    spec.keyboardClutch.enabled = self:globalSettingsGetSet("spec_realismAddon_gearbox.keyboardClutch.enabled", false, true)

   
    -- fluid clutch
    local fluidClutchKey = ".transmission.realismAddon_gearbox.fluidClutch"	
	local hasFluidClutch = getXMLValueFallback(xml, key, defaultKey, fluidClutchKey, nil, true)
	if hasFluidClutch then
		spec.fluidClutch = {}

		spec.fluidClutch.stallRpm = getXMLValueFallback(xml, key, defaultKey, fluidClutchKey.."#stallRpm", "float", nil, 1350)
		spec.fluidClutch.idleBiasFx = getXMLValueFallback(xml, key, defaultKey, fluidClutchKey.."#idleBiasFx", "float", nil, 1)
		spec.fluidClutch.clutchPercent = 1
	end


    -- auto clutch 
    -- clutch opens when brake pedal is pressed and rpm is below certain rpm spec 
    local autoClutchKey = ".transmission.realismAddon_gearbox.autoClutch"	
	local hasAutoClutch = getXMLValueFallback(xml, key, defaultKey, autoClutchKey, nil, true)
    if spec.hasAutoClutch then 
        spec.autoClutch = {}

        spec.autoClutch.openRpm = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#openRpm", "float", nil, motor.minRpm)                 -- below this rpm clutch will open (other conditions apply)
        spec.autoClutch.openOnlyOnBraking = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#openOnlyOnBraking", "bool", nil, true)      -- if this is set to true, clutch only auto opens when brake is applied (other conditions apply)
        spec.autoClutch.openAlwaysOnBraking = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#openAlwaysOnBraking", "bool", nil, false) -- if this is set true clutch will open as soon as brake is applied independent of other conditions
        spec.autoClutch.toggle = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#toggle", "bool", nil, true)                            -- if this is set to true auto clutch can be toggled via button

        spec.autoClutch.openTime = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#openTime", "float", nil, 500)                         -- time it takes to open the clutch in ms
        spec.autoClutch.closingTimeMin = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#closingTimeMin", "float", nil, 500)             -- min time it takes to close clutch
        spec.autoClutch.closingTimeMax = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#closingTimeMax", "float", nil, 2000)            -- max time it can take to close the clutch in ms
    
        spec.autoClutch.clutchPercent = 1
    end 




    -- autoClutch and keyboardClutch use the same timer mechanism 
    spec.akClutch = {}
    spec.akClutch.currentTime = -1
    spec.akClutch.movingDirection = 0  -- 1=closing, -1=opening, 0=no movement
    spec.akClutch.maxTime = 0


end

-- NON OF THIS IS IN USE RIGHT NOW 
-- get the current gear ratio based on average wheel speed and motor rpm, this is used for auto clutch calculations
function realismAddon_gearbox_spec_clutch:getCurrentGearRatioBasedOnWheelSpeedAndRPM()

    local motor = self.spec_motorized.motor     
	
    -- get average of all wheels
	local wheelSpeed = 0
	local numWheels = 0
	for _, wheel in pairs(self.spec_wheels.wheels) do
		local rpm = getWheelShapeAxleSpeed(wheel.node, wheel.physics.wheelShape)*30/math.pi
		wheelSpeed = wheelSpeed + (rpm * wheel.physics.radius)
		numWheels = numWheels + 1
	end	
	wheelSpeed = wheelSpeed / numWheels

    -- get ratio by dividing engine rpm / wheel rpm, cap and -2000/2000 
    return math.min(math.max(math.max(1, motor.lastMotorRpm) / (wheelSpeed + 0.00001), -2000), 2000)
end

function realismAddon_gearbox_spec_clutch:startClutchMovementOpen(openTime, clutch)

    --print("startClutchMovementOpen")
    
    local spec = self.spec_realismAddon_gearbox

    if not clutch.moving and clutch.clutchPercent > 0 then 
        spec.akClutch.currentTime = closingTime
        spec.akClutch.maxTime = closingTime 
        spec.akClutch.movingDirection = -1
        clutch.moving = true 
    elseif clutch.moving and clutch.clutchPercent > 0 then 
        -- get the current clutch position
        local clutchTime = spec.akClutch.currentTime / spec.akClutch.maxTime
        -- calculate new opening time from that 
        spec.akClutch.currentTime = closingTime * clutchTime
        spec.akClutch.maxTime = closingTime 
        spec.akClutch.movingDirection = -1
        clutch.moving = true
    end   

end

function realismAddon_gearbox_spec_clutch:startClutchMovementClose(closingTime, clutch)

    --print("startClutchMovementClose")

    local spec = self.spec_realismAddon_gearbox

    if not clutch.moving and clutch.clutchPercent < 1 then 
        spec.akClutch.currentTime = closingTime
        spec.akClutch.maxTime = closingTime 
        spec.akClutch.movingDirection = 1
        clutch.moving = true 
    elseif clutch.moving and clutch.clutchPercent < 1 then 
        -- get the current clutch position
        local clutchTime = spec.akClutch.currentTime / spec.akClutch.maxTime
        -- calculate new opening time from that 
        spec.akClutch.currentTime = closingTime * clutchTime
        spec.akClutch.maxTime = closingTime 
        spec.akClutch.movingDirection = 1
        clutch.moving = true
    end

end

function realismAddon_gearbox_spec_clutch:calculateClutchMovement(dt, clutch)

    

    local spec = self.spec_realismAddon_gearbox
    local motor = self.spec_motorized.motor 

    -- countdown timer is adjustad faster/slower depending on wether rpm is where its supposed to be
    local accInput = 0
    if self.getAxisForward ~= nil then
        accInput = math.max(0, self:getAxisForward())
    end
    -- take hand throttle into account 
    if self.spec_realismAddon_gearbox_inputs ~= nil then	
        accInput = math.max(accInput, self.spec_realismAddon_gearbox_inputs.handThrottlePercent)
    end
    local dtFactor = 1
    if accInput >= 0 then
        local wantedRpm = (motor.maxRpm - motor.minRpm) * accInput + motor.minRpm
	    local currentRpm = motor.lastRealMotorRpm

        dtFactor = math.min(currentRpm, wantedRpm) / math.max(currentRpm, wantedRpm)

    end

    --print("dtFactor: "..tostring(dtFactor))

    -- if the clutch is currently moving, count down timer, closing with dtFactor, opening without 
    if spec.akClutch.movingDirection == 1 then
        spec.akClutch.currentTime = math.max(spec.akClutch.currentTime - (dt * dtFactor), 0)
        if spec.akClutch.currentTime == 0 then 
            spec.akClutch.movingDirection = 0
            clutch.moving = false
        end
    elseif spec.akClutch.movingDirection == -1 or spec.akClutch.movingDirection == 1 then
        spec.akClutch.currentTime = math.max(spec.akClutch.currentTime - dt, 0)
        if spec.akClutch.currentTime == 0 then 
            spec.akClutch.movingDirection = 0
            clutch.moving = false
        end
    end

    -- set clutchPercent to current percent to whatever clutch called this function
    clutch.clutchPercent = 1 - (spec.akClutch.currentTime / spec.akClutch.maxTime)
    --print(clutch.clutchPercent)
end

-- END

function realismAddon_gearbox_spec_clutch:onUpdate(dt)

	if self:getIsActive() then
	
		local spec = self.spec_realismAddon_gearbox	
        local motor = self.spec_motorized.motor       

        local manual, clutch = realismAddon_gearbox_overrides.checkIsManual(motor)
	
		-- check if transmission is manual 
		if manual then

            -- Keyboard Clutch Calculations 
            if clutch then 
                spec.keyboardClutch.enabled = true

				local motor = self.spec_motorized.motor
				local rpm = motor.lastRealMotorRpm
                local clutch = spec.keyboardClutch

                --print(clutch.state)               

                --local nonClampedMotorRpm = motor:getNonClampedMotorRpm() 
                --local lastMotorRpm = motor:getLastMotorRpm()               

                -- get actual accelerator input
                local accAxis = self:getAxisForward()

                -- if we hit brake and rpm is below min+100 then open clutch
                if accAxis < 0 and rpm <= (motor.minRpm + 100) then 
                    clutch.state = 1
                end
                -- only close clutch if we hit accelerator and clutch is not manually held open via buttion 
                if accAxis > 0 and clutch.buttonClutchOverride == 0 then
                    clutch.state = 2
                end

                -- third option for keyboard clutch, release clutch slowly if it was pressed using the keyboard 
                -- check if we used Pedal or Keyboard to press clutch 
                -- we use the raw inputValue from the clutch (overwritten onManualClutchChanged function) to see if the value changed from 0 directly to 1
                if motor.manualClutchValueRaw ~= nil then
                    -- if the clutchValue changed from 0 directly to 1 it was opened using the button, set buttonClutchOverride, keeps clutch open even if button is let go
                    if clutch.lastManualClutchPedalRaw == 0 and motor.manualClutchValueRaw == 1 then
                        clutch.buttonClutchOverride = 1
                        clutch.state = 1
                        --print("opened via button")
                    end
                    -- if the value is back to 0 and we opened the clutch via button - we set the clutch state to 2, closing the clutch slowly. We can also reset the buttonClutchOverride now
                    if clutch.buttonClutchOverride == 1 and motor.manualClutchValueRaw == 0 then
                        --print("closed via button")
                        clutch.state = 2
                        clutch.buttonClutchOverride = 0
                    end
                    clutch.lastManualClutchPedalRaw = motor.manualClutchValueRaw
                end


                -- state == 1 -> open, state == 2 -> closed
                --print(clutch.clutchPercent) 
                if clutch.state == 1 then
                    if clutch.clutchPercent > 0 then -- opening clutch if clutch isn't already open 
                        clutch.clutchPercent = math.max(clutch.clutchPercent - (dt * (1 / clutch.openTime)), 0)
                    end                
                elseif clutch.state == 2 then 
                    if clutch.clutchPercent < 1 then -- closing clutch if clutch isn't already closing 
                        local accInput = 0
                        if self.getAxisForward ~= nil then
                            accInput = math.max(0, accAxis)
                        end
                        -- take hand throttle into account 
                        if self.spec_realismAddon_gearbox_inputs ~= nil then	
                            accInput = math.max(accInput, self.spec_realismAddon_gearbox_inputs.handThrottlePercent)
                        end

                        local currentRpm = math.floor(motor:getLastMotorRpm())                       
                        
                        -- this works well if the accelerator is pressed 
                        -- limit clutch closing until rpm isn't lowering anymore
                        if accInput > 0 then
                            if clutch.lastRpm > currentRpm then 
                                -- rpm is falling, open clutch again
                                clutch.clutchPercent = math.max(clutch.clutchPercent - (KEYBOARD_CLUTCH_MOVING_SPEED * dt), KEYBOARD_CLUTCH_MINIMUM_ENGAGEMENT)    
                            else
                                -- else close clutch
                                clutch.clutchPercent = math.min(clutch.clutchPercent + (KEYBOARD_CLUTCH_MOVING_SPEED * dt), 1)
                            end
                        end

                        -- if accelerator is 0, e.g. idle or no more rpm raising, the caclulation needs to be different
                        -- I still want to make sure the engine isn't stalled, but since the rpm isn't really raising we need to have
                        -- a different falling threshold
                        if accInput == 0 then 
                            if clutch.lastRpm <= currentRpm then 
                                -- rpm is not falling, close clutch
                                clutch.clutchPercent = math.min(clutch.clutchPercent + (KEYBOARD_CLUTCH_MOVING_SPEED * dt), 1)    
                            else
                                -- else open clutch
                                clutch.clutchPercent = math.max(clutch.clutchPercent - (KEYBOARD_CLUTCH_MOVING_SPEED * dt), KEYBOARD_CLUTCH_MINIMUM_ENGAGEMENT)   
                            end
                        end
                        --print("clutch.lastRpm: "..tostring(clutch.lastRpm).." currentRpm: "..tostring(currentRpm))

                        -- update clutch.lastRpm with currentRpm
                        clutch.lastRpm = currentRpm

                    end
                end
            else
                spec.keyboardClutch.enabled = false
            end

			
			if spec.fluidClutch ~= nil then 
				-- get current RPM 
				local motor = self.spec_motorized.motor
				local rpm = motor.lastRealMotorRpm
				if rpm < spec.fluidClutch.stallRpm then
					-- calculate range via minRpm and currentRpm	
					local range = spec.fluidClutch.stallRpm - motor.minRpm
					-- get the linear closing percentage 
					local linearPercentage = (math.max(rpm, motor.minRpm + 1) - motor.minRpm) / range

					spec.fluidClutch.clutchPercent = linearPercentage
					--print("fluid open: "..tostring(rpm).. " " .. tostring(linearPercentage))
				else
					spec.fluidClutch.clutchPercent = 1
				end
			end

		end	
	end	
end


