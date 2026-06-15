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
 	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", realismAddon_gearbox_spec_clutch)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", realismAddon_gearbox_spec_clutch)   
end

function realismAddon_gearbox_spec_clutch.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "keyboardClutch_enableAutoOpen_set", realismAddon_gearbox_spec_clutch.keyboardClutch_enableAutoOpen_set)
 	SpecializationUtil.registerFunction(vehicleType, "keyboardClutch_enableAutoMovement_set", realismAddon_gearbox_spec_clutch.keyboardClutch_enableAutoMovement_set)      
end

function realismAddon_gearbox_spec_clutch:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_realismAddon_gearbox

    setXMLBool(xmlFile.handle, key.."#enableAutoMovement", spec.keyboardClutch_enableAutoMovement)
    setXMLBool(xmlFile.handle, key.."#enableAutoOpen", spec.keyboardClutch_enableAutoOpen)

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
    -- keyboard Clutch

     -- for now, always enable auto movement by default 
    spec.keyboardClutch_enableAutoMovement = getXMLValueFallbackSavegame(savegame, ".FS25_realismAddon_gearbox.realismAddon_gearbox_spec_clutch#enableAutoMovement", "bool", true)
    spec.keyboardClutch_enableAutoOpen = getXMLValueFallbackSavegame(savegame, ".FS25_realismAddon_gearbox.realismAddon_gearbox_spec_clutch#enableAutoOpen", "bool", false)

    spec.keyboardClutch = {}
    spec.keyboardClutch.openTime = 100
    spec.keyboardClutch.closingTime = 1000

    spec.keyboardClutch.clutchPercent = 1

    spec.keyboardClutch.lastManualClutchPedalRaw = 0
    spec.keyboardClutch.buttonClutchOverride = 0

    spec.keyboardClutch.state = 2

    spec.keyboardClutch.lastRpm = motor.minRpm
    spec.keyboardClutch.moving = false



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

function realismAddon_gearbox_spec_clutch:onReadStream(streamId, connection)
    local spec = self.spec_realismAddon_gearbox
    local keyboardClutch_enableAutoMovement = streamReadBool(streamId)
    local keyboardClutch_enableAutoOpen = streamReadBool(streamId)
    self:keyboardClutch_enableAutoMovement_set(keyboardClutch_enableAutoMovement, true)
    self:keyboardClutch_enableAutoOpen_set(keyboardClutch_enableAutoOpen, true)
end
function realismAddon_gearbox_spec_clutch:onWriteStream(streamId, connection)
    local spec = self.spec_realismAddon_gearbox
    streamWriteBool(streamId, spec.keyboardClutch_enableAutoMovement)
    streamWriteBool(streamId, spec.keyboardClutch_enableAutoOpen)
end


function realismAddon_gearbox_spec_clutch:keyboardClutch_enableAutoOpen_set(state, noEventSend)
    --print("keyboardClutch_enableAutoOpen_set: "..tostring(state))
    if state ~= self.spec_realismAddon_gearbox.keyboardClutch_enableAutoOpen then
        event_keyboardClutch_autoOpen.sendEvent(self, state, noEventSend)    
        self.spec_realismAddon_gearbox.keyboardClutch_enableAutoOpen = state      
    end
end
function realismAddon_gearbox_spec_clutch:keyboardClutch_enableAutoMovement_set(state, noEventSend)
    --print("keyboardClutch_enableAutoMovement_set: "..tostring(state))   
    if state ~= self.spec_realismAddon_gearbox.keyboardClutch_enableAutoMovement then
        event_keyboardClutch_autoMovement.sendEvent(self, state, noEventSend)   
        self.spec_realismAddon_gearbox.keyboardClutch_enableAutoMovement = state      
    end
end

function realismAddon_gearbox_spec_clutch:onUpdate(dt)

	if self:getIsActive() then
	
		local spec = self.spec_realismAddon_gearbox	
        local motor = self.spec_motorized.motor       

		-- check if transmission is manual 
		if realismAddon_gearbox_overrides.checkIsManual(motor) then

            -- Keyboard Clutch Calculations 
            if spec.keyboardClutch ~= nil and (spec.keyboardClutch_enableAutoOpen == true or spec.keyboardClutch_enableAutoMovement == true) then 
                --spec.keyboardClutch.enabled = true

				local motor = self.spec_motorized.motor
				local rpm = motor.lastRealMotorRpm
                local clutch = spec.keyboardClutch
          

                --local nonClampedMotorRpm = motor:getNonClampedMotorRpm() 
                --local lastMotorRpm = motor:getLastMotorRpm()               

                -- get actual accelerator input
                local accAxis = self:getAxisForward()



                if spec.keyboardClutch_enableAutoOpen then
                    -- if we hit brake and rpm is below min+100 then open clutch
                    if accAxis < 0 and rpm <= (motor.minRpm + 100) then 
                        clutch.state = 1
                    end
                    -- only close clutch if we hit accelerator and clutch is not manually held open via buttion 
                    if accAxis > 0 and clutch.buttonClutchOverride == 0 then
                        clutch.state = 2
                    end
                end

                -- third option for keyboard clutch, release clutch slowly if it was pressed using the keyboard 
                -- check if we used Pedal or Keyboard to press clutch 
                -- we use the raw inputValue from the clutch (overwritten onManualClutchChanged function) to see if the value changed from 0 directly to 1
                if spec.keyboardClutch_enableAutoMovement then
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
                end


                --print(clutch.state)     
                -- state == 1 -> open, state == 2 -> closed
                --print("clutchPercent: "..tostring(clutch.clutchPercent))
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
                         --print("accInput: "..tostring(accInput).." clutch.lastRpm: "..tostring(clutch.lastRpm).." currentRpm: "..tostring(currentRpm).." manualClutchValueRaw: "..tostring(motor.manualClutchValueRaw))                     
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


-- ######################
-- Event for keyboardClutch Automatic opening
-------------------------

event_keyboardClutch_autoOpen = {}
local event_keyboardClutch_autoOpen_mt = Class(event_keyboardClutch_autoOpen, Event)

InitEventClass(event_keyboardClutch_autoOpen, "event_keyboardClutch_autoOpen")

function event_keyboardClutch_autoOpen.emptyNew()
	return Event.new(event_keyboardClutch_autoOpen_mt)
end

function event_keyboardClutch_autoOpen.new(object, wantedState)
	local self = event_keyboardClutch_autoOpen.emptyNew()
	self.object = object
	self.wantedState = wantedState

	return self
end

function event_keyboardClutch_autoOpen:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.wantedState = streamReadBool(streamId)

	self:run(connection)
end

function event_keyboardClutch_autoOpen:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.wantedState)
end

function event_keyboardClutch_autoOpen:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:keyboardClutch_enableAutoOpen_set(self.wantedState, true)
	end
end

function event_keyboardClutch_autoOpen.sendEvent(object, wantedState, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(event_keyboardClutch_autoOpen.new(object, wantedState), nil, nil, object)			
		else
			g_client:getServerConnection():sendEvent(event_keyboardClutch_autoOpen.new(object, wantedState))
		end
	end
end



-- ######################
-- Event for keyboardClutch Automatic moving
-------------------------

event_keyboardClutch_autoMovement = {}
local event_keyboardClutch_autoMovement_mt = Class(event_keyboardClutch_autoMovement, Event)

InitEventClass(event_keyboardClutch_autoMovement, "event_keyboardClutch_autoMovement")

function event_keyboardClutch_autoMovement.emptyNew()
	return Event.new(event_keyboardClutch_autoMovement_mt)
end

function event_keyboardClutch_autoMovement.new(object, wantedState)
	local self = event_keyboardClutch_autoMovement.emptyNew()
	self.object = object
	self.wantedState = wantedState

	return self
end

function event_keyboardClutch_autoMovement:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.wantedState = streamReadBool(streamId)

	self:run(connection)
end

function event_keyboardClutch_autoMovement:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.wantedState)
end

function event_keyboardClutch_autoMovement:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end
	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:keyboardClutch_enableAutoMovement_set(self.wantedState, true)
	end
end

function event_keyboardClutch_autoMovement.sendEvent(object, wantedState, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(event_keyboardClutch_autoMovement.new(object, wantedState), nil, nil, object)			
		else
			g_client:getServerConnection():sendEvent(event_keyboardClutch_autoMovement.new(object, wantedState))
		end
	end
end
