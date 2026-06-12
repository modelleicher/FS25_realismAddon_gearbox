-- by modelleicher 

-- this is an extension of realismAddon_gearbox_spec but with everything specific to the CVT calculations in it 
-- first edition,   - classic harvester CVT in combination with gears and clutch
--                  - 1. gen fendt vario transmission simulation 


-- TO DO / NOTES:
-- Fendt Vario simulation works as intended but since its a cvt put onto manual gearbox there are some non-issues that need fixing 
--  such as its still possible to shift into gear-neutral but vario range 1/2 doesn't have neutral. Maybe we can lock that in the future
--  especially since the CVT has its on neutral which doesn't change range position and thus the second neutral is confusing maybe 
-- Classic CVT is currently only in combination with Clutch. But it also should have a neutral position. That is currently limited to the Vario due to inputs
--  might want/need more features for the basic cvt such as neutral button or neutral position on the joystick
--  as well as cvt control via gas pedal instead of joystick
--  optional cvt control via gas pedal that also controls engine rpm, like loader maybe?

realismAddon_gearbox_spec_cvt = {} 

function realismAddon_gearbox_spec_cvt.prerequisitesPresent(specializations)
    return true
end

function realismAddon_gearbox_spec_cvt.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", realismAddon_gearbox_spec_cvt)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", realismAddon_gearbox_spec_cvt)
 	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", realismAddon_gearbox_spec_cvt)
 	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", realismAddon_gearbox_spec_cvt)      
end

function realismAddon_gearbox_spec_cvt.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "processVarioInputs", realismAddon_gearbox_spec_cvt.processVarioInputs)
  	SpecializationUtil.registerFunction(vehicleType, "processCVTControlInputs", realismAddon_gearbox_spec_cvt.processCVTControlInputs)  
end


function realismAddon_gearbox_spec_cvt:onLoad(savegame)

    local spec = self.spec_realismAddon_gearbox

	-- get config key and default key 
	local key, _ = ConfigurationUtil.getXMLConfigurationKey(self.xmlFile,  self.configurations.motor, "vehicle.motorized.motorConfigurations.motorConfiguration", "vehicle.motorized", "motor")
	local defaultKey = "vehicle.motorized.motorConfigurations.motorConfiguration(0)"

    -- since we don't use the predefined xml Schemas we need to use the handle of the XML file
    local xml = self.xmlFile.handle    


 	-- cvt 
    local cvtKey = ".transmission.realismAddon_gearbox.cvt"

	local hasCVT = getXMLValueFallback(xml, key, defaultKey, cvtKey, nil, true)
	if hasCVT then
		spec.cvt = {}

		spec.cvt.minPercentage = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#minPercentage", "float", nil, 0.01)
		spec.cvt.maxPercentage = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#maxPercentage", "float", nil, 1)

		spec.cvt.manualControl = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#manualControl", "bool", nil, true)
        spec.cvt.controlSpeed = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#manualControl", "float", nil, 2)

        spec.cvt.canChangeDirection = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#cvtCanChangeDirection", "bool", nil, false)
        spec.cvt.direction = 1 

		spec.cvt.cvtPercent = 0

        spec.cvt.neutral = false   
        spec.cvt.hasNeutral = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#hasNeutral", "bool", nil, false)

        -- gen1 vario 
        spec.cvt.isVario = getXMLValueFallback(xml, key, defaultKey, cvtKey.."#isVario", "bool", nil, false)
        if spec.cvt.isVario then
            spec.cvt.neutral = true
            spec.cvt.hasNeutral = true
            spec.cvt.controlSpeed = 1
            spec.cvt.canChangeDirection = true
            spec.cvt.pressureValvePercentage = 1    -- pressure valve releases hydraulic pressture similar to fluidClutch limits torque -> this is clutch percentage
            spec.cvt.pressureValveClosingSpeed = 0.01
            spec.cvt.pressureValveOpeningSpeed = 0.1
            spec.cvt.fluidClutchEmulation = true    -- later years first gen varios (display) can toggle this off
            spec.cvt.cruiseControlSpeedKph = 0
            spec.cvt.cruiseControlActive = false
            spec.cvt.cruiseControlPreselect = false
        end

	    spec.synchCVTDirtyFlag = self:getNextDirtyFlag()	

	end   
end

function realismAddon_gearbox_spec_cvt:processCVTControlInputs(direction)
    --print("processCVTControlInputs: "..tostring(direction))  
    local spec = self.spec_realismAddon_gearbox   
    if spec.cvt ~= nil and not spec.cvt.neutral then
        local cvtPercent = spec.cvt.cvtPercent
        if direction == "up" and spec.cvt.direction == 1 or direction == "down" and spec.cvt.direction == -1 then
            spec.cvt.cvtPercent = math.min(1, spec.cvt.cvtPercent + 0.006*spec.cvt.controlSpeed)   
        elseif direction == "down" and spec.cvt.direction == 1 or direction == "up" and spec.cvt.direction == -1 then
            spec.cvt.cvtPercent = math.max(0, spec.cvt.cvtPercent - 0.006*spec.cvt.controlSpeed)
        end

        if cvtPercent > 0 and spec.cvt.cvtPercent == 0 and spec.cvt.canChangeDirection then
            spec.cvt.direction = spec.cvt.direction * -1
        end

        if spec.cvt.cvtPercent ~= cvtPercent then
            --print("cvtPercent: "..tostring(spec.cvt.cvtPercent))
            self:raiseDirtyFlags(spec.synchCVTDirtyFlag)	        
        end
    end
end

local varioInputType = {}
varioInputType.FORWARD = 1
varioInputType.BACKWARD = 2
varioInputType.TOGGLE = 3
varioInputType.CRUISE = 4
varioInputType.NEUTRAL = 5

function realismAddon_gearbox_spec_cvt:processVarioInputs(type, noEventSend)
    setGroupSecondEvent.sendEvent(self, type, noEventSend)
    local spec = self.spec_realismAddon_gearbox

    if spec.cvt ~= nil and spec.cvt.isVario then
        if type == varioInputType.FORWARD then
 	        spec.cvt.direction = 1
	        spec.cvt.neutral = false	 
            spec.cvt.cruiseControlActive = false            
            --print("F")        
        elseif type == varioInputType.BACKWARD then
   	        spec.cvt.direction = -1
	        spec.cvt.neutral = false	
            spec.cvt.cruiseControlActive = false            
            --print("R")         
        elseif type == varioInputType.TOGGLE then
            --print("T")
            if spec.cvt.direction == 1 then
                spec.cvt.direction = -1
            else
                spec.cvt.direction = 1
            end
            spec.cvt.cruiseControlActive = false              
        elseif type == varioInputType.CRUISE then
            --print("C")
            spec.cvt.cruiseControlActive = not spec.cvt.cruiseControlActive
            if not spec.cvt.cruiseControlPreselect and spec.cvt.cruiseControlActive then
                spec.cvt.cruiseControlSpeedKph = self:getLastSpeed()
                spec.cvt.cruiseControlPercent = spec.cvt.cvtPercent
            end
            -- cruise control to do 
        elseif type == varioInputType.NEUTRAL then
            --print("N")
            spec.cvt.neutral = true
            spec.cvt.cvtPercent = 0
            spec.cvt.cruiseControlActive = false  
        end
    end
end




function realismAddon_gearbox_spec_cvt:onUpdate(dt)

	if self:getIsActive() then
	
		local spec = self.spec_realismAddon_gearbox	
        local motor = self.spec_motorized.motor       
        
        --print("isManual: "..tostring(realismAddon_gearbox_overrides.checkIsManual(motor)))

        --print("forwardGears: "..tostring(motor.forwardGears ~= nil))
        --print("backwardGears: "..tostring(motor.backwardGears ~= nil))       

        local isManualTransmission = motor.backwardGears ~= nil or motor.forwardGears ~= nil
        --print(isManualTransmission)

        local gearShiftMode = motor.gearShiftMode == VehicleMotor.SHIFT_MODE_MANUAL_CLUTCH
        --print(gearShiftMode)

		-- check if transmission is manual 
		if realismAddon_gearbox_overrides.checkIsManual(motor) then
            if spec.cvt ~= nil then


                -- gen1 vario logic
                if spec.cvt.isVario then
                    --print("isVario")

                    -- pressure valve percentage calculation 
                    local motor = self.spec_motorized.motor
                    local rpm = motor.lastRealMotorRpm

                    local pressureValvePercentage = 1
                    
                    --13% (75 Bar out of 550) (10% clutch deadzone + 13% ->23%)
                    local minOpenPercentage = 0.23

                    -- fluid clutch emulation
                    -- vario fluidClutch emulation is opening a valve below 1400 rpm to simulate the behaviour of older Turbomatik fluid clutches 
                    -- reduced rpm to 1300 instead of 1400 since FS is "slow" and "soft" and visual rpm isn't completely in synch with physics
                    -- you accidentally go below the threshold too easy with 1400 -- this might be a TO DO - fix rpm physics synch again, is off in fs25
                    if spec.cvt.fluidClutchEmulation then
                        if rpm < 1300 then
                            -- calculate range via minRpm and currentRpm	
                            local range = 1300 - motor.minRpm
                            -- get the linear closing percentage 
                            local linearPercentage = (math.max(rpm, motor.minRpm + 1) - motor.minRpm) / range

                            pressureValvePercentage = math.min(pressureValvePercentage, math.max(linearPercentage, minOpenPercentage))
                            --print("fluid open: "..tostring(rpm).. " " .. tostring(linearPercentage))
                        else
                            pressureValvePercentage = math.min(pressureValvePercentage, 1)
                        end
                    end

                    -- get actual accelerator input
                    local accAxis = self:getAxisForward()    
                    
                    -- brake will open valve but only to minOpenPercentage like fluitClutch
                    if accAxis < 0 then
                        pressureValvePercentage = math.min(pressureValvePercentage, math.max(1 - math.abs(accAxis), minOpenPercentage))
                    end

                    -- clutch pedal emulation, clutch will fully open the valve 
                    if motor.manualClutchValueRaw ~= nil then
                        pressureValvePercentage = math.min(pressureValvePercentage, 1 - motor.manualClutchValueRaw)
                    end

                    -- if we are in neutral pressure is also completely open
                    if spec.cvt.neutral then
                        pressureValvePercentage = 0
                    end

                    -- not 100% realistic but since really high ratios are bad to compute we open the valve if we are at minRatio, don't let minRatio go down to 0
                    -- IRL this is also an issue if the transmission ratio is too high the transmission can have too much internal resistance and stop the vehicle 
                    -- thus on modern cvt transmissions there is usually some sort of failsave for that, not sure on old gen1 vario though
                    -- NOTE: Removed since Joystick can change direction fluently and pressureValve opening on 0 position is in the way of smooth fwd - bwd transition
                    --       seems to work fine as is.
                    --if spec.cvt.cvtPercent <= spec.cvt.minPercentage then
                    --    pressureValvePercentage = 0
                    --end
                    
                    if pressureValvePercentage > spec.cvt.pressureValvePercentage then
                        spec.cvt.pressureValvePercentage = math.min(spec.cvt.pressureValvePercentage + spec.cvt.pressureValveClosingSpeed, pressureValvePercentage)
                    elseif pressureValvePercentage < spec.cvt.pressureValvePercentage then
                        spec.cvt.pressureValvePercentage = pressureValvePercentage
                    end


                    -- TO DO: clutch moving calculation for using keyboard - maybe? anybody using full manual gen1 vario control with keyboard? 
                    --spec.cvt.pressureValvePercentage = pressureValvePercentage

                    -- TO DO: slow transition of ratio on direction toggle input 
                    -- 

                    -- cruise control 
                    if spec.cvt.cruiseControlActive then
                        --print("cruise control active")
                        -- all the methods to deactivate cruise control 
                        -- brake pedal pressed 
                        if accAxis < - 0.1 then
                            --print("brake deaktivate")
                            spec.cvt.cruiseControlActive = false
                        end

                        -- clutch pedal pressed 
                        if motor.manualClutchValueRaw ~= nil and motor.manualClutchValueRaw > 0.1 then
                           --print("clutch deactivate")
                           spec.cvt.cruiseControlActive = false
                        end

                        -- rpm below 1300 
                        if rpm < 1300 then
                            --print("rpm deactivate")
                            spec.cvt.cruiseControlActive = false
                        end

                        -- also neutral or joystick action but we set that in processVarioInputs

                        -- now the actual calculation
                        -- cruise control changes the transmission ratio so speed stays the same no matter what rpm does 
                        -- so we need to know not the cvt percent but actual speed when cruise control was activated
                        local wantedSpeed = spec.cvt.cruiseControlSpeedKph
                        local currentSpeed = self:getLastSpeed()

                        -- very basic caclulation, lots of overshoot, not great. Needs rework TO DO
                        -- also needs including of saved speed values 

                        local tolerance = 2

                        if currentSpeed < wantedSpeed - tolerance then
                            --print("up")
                            spec.cvt.cvtPercent = math.min(1, spec.cvt.cvtPercent + 0.006*spec.cvt.controlSpeed)   
                        elseif currentSpeed > wantedSpeed + tolerance then
                            --print("down")
                            spec.cvt.cvtPercent = math.max(0, spec.cvt.cvtPercent - 0.006*spec.cvt.controlSpeed)                              
                        end
                 

                        --print("cvtPercent: "..tostring(spec.cvt.cvtPercent))

                    end

                end
            end

        end
    end
end


function realismAddon_gearbox_spec_cvt:onWriteUpdateStream(streamId, connection, dirtyMask)
	local spec = self.spec_realismAddon_gearbox

	if connection:getIsServer() and realismAddon_gearbox_overrides.checkIsManual(self.spec_motorized.motor) and spec.cvt ~= nil then 
		if streamWriteBool(streamId, bitAND(dirtyMask, spec.synchCVTDirtyFlag) ~= 0) then
			streamWriteUIntN(streamId, spec.cvt.cvtPercent * 100, 7)
		end			
	end
	
end

function realismAddon_gearbox_spec_cvt:onReadUpdateStream(streamId, timestamp, connection)
	local spec = self.spec_realismAddon_gearbox
	
	if not connection:getIsServer() and realismAddon_gearbox_overrides.checkIsManual(self.spec_motorized.motor) and spec.cvt ~= nil then 
		if streamReadBool(streamId) then
			spec.cvt.cvtPercent = streamReadUIntN(streamId, 7) / 100
		end			
	end
	
end




setVarioJoystickProcessEvent = {}
local setVarioJoystickProcessEvent_mt = Class(setVarioJoystickProcessEvent, Event)

InitEventClass(setVarioJoystickProcessEvent, "setVarioJoystickProcessEvent")

function setVarioJoystickProcessEvent.emptyNew()
	return Event.new(setVarioJoystickProcessEvent_mt)
end

function setVarioJoystickProcessEvent.new(object, type)
	local self = setVarioJoystickProcessEvent.emptyNew()
	self.object = object
	self.type = type

	return self
end

function setVarioJoystickProcessEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.type = streamReadUIntN(streamId, 3)

	self:run(connection)
end

function setVarioJoystickProcessEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUIntN(streamId, self.type, 3)
end

function setVarioJoystickProcessEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:processVarioInputs(self.type, true)
	end
end

function setVarioJoystickProcessEvent.sendEvent(object, type, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(setGroupSecondEvent.new(object, type), nil, nil, object)			
		else
			g_client:getServerConnection():sendEvent(setGroupSecondEvent.new(object, type))
		end
	end
end