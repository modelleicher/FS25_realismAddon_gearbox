-- by modelleicher ( Farming Agency )
-- Inputs for realismAddon_gearbox 

realismAddon_gearbox_inputs = {}

function realismAddon_gearbox_inputs.prerequisitesPresent(specializations)
    return true
end

-- Action Event Adding 
-- custom function for adding actionEvents since there might be a lot 
function realismAddon_gearbox_inputs.onRegisterActionEvents(self, isActiveForInput, isActiveForInputIgnoreSelection)
	

	if self.isClient then
		local spec = self.spec_realismAddon_gearbox_inputs
		
		if (isActiveForInputIgnoreSelection or isActiveForInput) and spec.allManualActive then
		
			-- hand throttle 
			self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_HANDTHROTTLE_UP", "HANDTHROTTLE_INPUT")
			self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_HANDTHROTTLE_DOWN", "HANDTHROTTLE_INPUT")
			self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_HANDTHROTTLE_AXIS", "HANDTHROTTLE_INPUT")
			
			-- gear shift via axis 
			self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_GEARSHIFT_AXIS", "RAGB_GEARSHIFT_AXIS")	

			-- second group set
			self:addRealismAddonActionEvent("BUTTON_SINGLE_ACTION", "RAGB_GROUPSECOND_UP", "GROUPSECOND_INPUT")			
			self:addRealismAddonActionEvent("BUTTON_SINGLE_ACTION", "RAGB_GROUPSECOND_DOWN", "GROUPSECOND_INPUT")	
			
			-- handbrake
			self:addRealismAddonActionEvent("BUTTON_SINGLE_ACTION", "RAGB_HANDBRAKE", "HANDBRAKE_INPUT")			

			-- group 5 - 8 individual shifting since Giants only allows 1-4
			self:addRealismAddonActionEvent("BUTTON_SINGLE_ACTION", "RAGB_SHIFT_GROUP_5", "GROUP58_MANUAL_INPUT")	
			self:addRealismAddonActionEvent("BUTTON_SINGLE_ACTION", "RAGB_SHIFT_GROUP_6", "GROUP58_MANUAL_INPUT")	
			self:addRealismAddonActionEvent("BUTTON_SINGLE_ACTION", "RAGB_SHIFT_GROUP_7", "GROUP58_MANUAL_INPUT")	
			self:addRealismAddonActionEvent("BUTTON_SINGLE_ACTION", "RAGB_SHIFT_GROUP_8", "GROUP58_MANUAL_INPUT")	

			-- cvt control
			self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_CVT_UP", "CVT_UP")
			self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_CVT_DOWN", "CVT_DOWN")
			--self:addRealismAddonActionEvent("PRESSED_OR_AXIS", "RAGB_CVT_AXIS", "CVT_INPUT")			
		
		end

	end
end

function realismAddon_gearbox_inputs:addRealismAddonActionEvent(type, inputAction, func, showHud)
	local spec = self.spec_realismAddon_gearbox_inputs
	
	spec.actionEvents = {}
	self:clearActionEventsTable(spec.actionEvents) 
	


	local _, actionEventId = nil
	if type == "BUTTON_SINGLE_ACTION" then
		_ , actionEventId = self:addActionEvent(spec.actionEvents, InputAction[inputAction], self, realismAddon_gearbox_inputs[func], false, true, false, true)
	elseif type == "BUTTON_DOUBLE_ACTION" then
		_ , actionEventId = self:addActionEvent(spec.actionEvents, InputAction[inputAction], self, realismAddon_gearbox_inputs[func], true, true, false, true)	
	elseif type == "PRESSED_OR_AXIS" then
		_ , actionEventId = self:addActionEvent(spec.actionEvents, InputAction[inputAction], self, realismAddon_gearbox_inputs[func], false, false, true, true)
	end
	if not showHud then
		g_inputBinding:setActionEventTextVisibility(actionEventId, false)
	end
end
-- END 
-- 

-- INPUT CALLBACKS
-- 

-- hand throttle.. not an ideal way of doing it, performancewise..  I think.
function realismAddon_gearbox_inputs:HANDTHROTTLE_INPUT(actionName, inputValue)	


	local spec = self.spec_realismAddon_gearbox_inputs
	spec.handThrottleDown = false
	spec.handThrottleUp = false	
	if actionName == "RAGB_HANDTHROTTLE_AXIS" then
	
		
		-- round to 1% resolution should be fine enough (to not spam multiplayer synch)
		inputValue = math.floor(inputValue * 100) / 100
		if spec.handThrottlePercent ~= inputValue then
			self:raiseDirtyFlags(spec.synchHandThrottleDirtyFlag)
			spec.handThrottlePercent = inputValue
		end
	elseif actionName == "RAGB_HANDTHROTTLE_UP" and inputValue > 0.5 then
		spec.handThrottleUp = true 
	elseif actionName == "RAGB_HANDTHROTTLE_DOWN" and inputValue > 0.5 then
		spec.handThrottleDown = true			
	end
end

-- shifting axis for fps transmissions
function realismAddon_gearbox_inputs:RAGB_GEARSHIFT_AXIS(actionName, inputValue)


	local input = self.spec_realismAddon_gearbox_inputs
	local motor = self.spec_motorized.motor
	local gears = motor.currentGears
	
	-- calculate wanted gear as rounded value of all gears * inputValue 
	local wantedGear = math.floor(#gears * inputValue)
	
	-- only call the event if inputAxis moved enough to be a new gear (motor.gear is the current gear index in FS22)
	if input.gearAxisPosition ~= wantedGear then
		if wantedGear ~= motor.gear then 
			MotorGearShiftEvent.sendToServer(self, MotorGearShiftEvent.TYPE_SELECT_GEAR, wantedGear)
		end
		input.gearAxisPosition = wantedGear
	end
	
end

-- second group set 
function realismAddon_gearbox_inputs:GROUPSECOND_INPUT(actionName, inputValue)

	local spec_ragb = self.spec_realismAddon_gearbox
	
	if spec_ragb.groupsSecondSet ~= nil then	
	
		local wantedGroup = spec_ragb.groupsSecondSet.currentGroup
		if actionName == "RAGB_GROUPSECOND_UP" then
			wantedGroup = math.min(spec_ragb.groupsSecondSet.currentGroup + 1, #spec_ragb.groupsSecondSet.groups)
		elseif actionName == "RAGB_GROUPSECOND_DOWN" then
			wantedGroup = math.max(spec_ragb.groupsSecondSet.currentGroup - 1, 1)
		end
		
		if wantedGroup ~= spec_ragb.groupsSecondSet.currentGroup then
			self:processSecondGroupSetInputs(wantedGroup)
		end
	end

end

-- handbrake
function realismAddon_gearbox_inputs:HANDBRAKE_INPUT(actionName, inputValue)

	local spec_ragb = self.spec_realismAddon_gearbox
	
	if spec_ragb.handbrakeStateME ~= nil then	
		self:processHandbrakeInput(not spec_ragb.handbrakeStateME)
	end
end
-- END


-- group 5 to 8 manual shifting 
function realismAddon_gearbox_inputs:GROUP58_MANUAL_INPUT(actionName, inputValue)
	
	local wantedGearGroupIndex = 5
	if actionName == "RAGB_SHIFT_GROUP_6" then
		wantedGearGroupIndex = 6
	elseif actionName == "RAGB_SHIFT_GROUP_7" then
		wantedGearGroupIndex = 7
	elseif actionName == "RAGB_SHIFT_GROUP_8" then
		wantedGearGroupIndex = 8
	end

	local motor = self.spec_motorized.motor
	if motor.gearGroups[wantedGearGroupIndex] ~= nil then
		MotorGearShiftEvent.sendToServer(self, MotorGearShiftEvent.TYPE_SELECT_GROUP, inputValue == 1 and wantedGearGroupIndex or 0)
	end
end

function realismAddon_gearbox_inputs:CVT_INPUT(actionName, inputValue)	

	print(tostring(actionName).." - "..tostring(inputValue))


	local spec = self.spec_realismAddon_gearbox_inputs
	spec.cvtDown = false
	spec.cvtUp = false	
	if actionName == "RAGB_CVT_AXIS" then
	
		-- round to 1% resolution should be fine enough (to not spam multiplayer synch)
		inputValue = math.floor(inputValue * 100) / 100
		if spec.cvtPercent ~= inputValue then
			self:raiseDirtyFlags(spec.synchCVTDirtyFlag)
			spec.cvtPercent = inputValue
		end
	end
	if actionName == "RAGB_CVT_UP" and inputValue > 0.5 then
		spec.cvtUp = true 
	end
	if actionName == "RAGB_CVT_DOWN" and inputValue > 0.5 then
		spec.cvtDown = true			
	end

	--print("CVT INPUT PERCENT: "..tostring(spec.cvtPercent))
end

function realismAddon_gearbox_inputs:CVT_UP(actionName, inputValue)	
	local spec = self.spec_realismAddon_gearbox_inputs	
	spec.cvtUp = false	



	if inputValue > 0.5 then 
		spec.cvtUp = true 
			--print("UP")
	end
end

function realismAddon_gearbox_inputs:CVT_DOWN(actionName, inputValue)	
	local spec = self.spec_realismAddon_gearbox_inputs

	spec.cvtDown = false
	if inputValue > 0.5 then 
		spec.cvtDown = true 
			--print("DOWN")
	end	
end

-- ACTUAL SPEC 

function realismAddon_gearbox_inputs.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", realismAddon_gearbox_inputs)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", realismAddon_gearbox_inputs)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", realismAddon_gearbox_inputs)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", realismAddon_gearbox_inputs)
	
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", realismAddon_gearbox_inputs)
	
end

function realismAddon_gearbox_inputs.registerFunctions(vehicleType)
	
end

-- LOAD
function realismAddon_gearbox_inputs:onLoad(savegame)

	
	self.addRealismAddonActionEvent = realismAddon_gearbox_inputs.addRealismAddonActionEvent

	self.spec_realismAddon_gearbox_inputs = {}
	local spec = self.spec_realismAddon_gearbox_inputs
	
	-- this value contains an up to date value if we are in manual mode 
	spec.allManualActive = false
	
	-- check if transmission is manual 
	local allManualActive = realismAddon_gearbox_overrides.checkIsManual(self.spec_motorized.motor)
	if allManualActive ~= spec.allManualActive then
		spec.allManualActive = allManualActive
	end		
	
	-- hand throttle values
	spec.handThrottlePercent = 0
	spec.handThrottleDown = false
	spec.handThrottleUp = false
	
	spec.synchHandThrottleDirtyFlag = self:getNextDirtyFlag()	
	
	-- gear shift axis values 
	spec.gearAxisPosition = 0	

	-- manual cvt control 
	spec.cvtPercent = 1
	spec.cvtDown = false
	spec.cvtUp = false
	
	spec.synchCVTDirtyFlag = self:getNextDirtyFlag()	

end



-- UPDATE
function realismAddon_gearbox_inputs:onUpdate(dt)

	if self:getIsActive() then
	
		local spec = self.spec_realismAddon_gearbox_inputs	
	
		-- check if transmission is manual 
		local allManualActive = realismAddon_gearbox_overrides.checkIsManual(self.spec_motorized.motor)
		if allManualActive ~= spec.allManualActive then
			spec.allManualActive = allManualActive
		end
		
		
		if spec.allManualActive then			
			-- calculating hand throttle 
			if spec.handThrottleDown then
				spec.handThrottlePercent = math.max(0, spec.handThrottlePercent - 0.001*dt)
				self:raiseDirtyFlags(spec.synchHandThrottleDirtyFlag)
			elseif spec.handThrottleUp then
				spec.handThrottlePercent = math.min(1, spec.handThrottlePercent + 0.001*dt)
				self:raiseDirtyFlags(spec.synchHandThrottleDirtyFlag)				
			end

			-- calculating CVT 
			if spec.cvtDown then
				spec.cvtPercent = math.max(0, spec.cvtPercent - 0.001*dt)
				self:raiseDirtyFlags(spec.synchCVTDirtyFlag)
			elseif spec.cvtUp then
				spec.cvtPercent = math.min(1, spec.cvtPercent + 0.001*dt)
				self:raiseDirtyFlags(spec.synchCVTDirtyFlag)			
			end			

		end
			
	end
	
end

-- READ AND WRITE UPDATE 


function realismAddon_gearbox_inputs:onWriteUpdateStream(streamId, connection, dirtyMask)
	local spec = self.spec_realismAddon_gearbox_inputs

	if connection:getIsServer() and spec.allManualActive then 
		-- hand throttle
		if streamWriteBool(streamId, bitAND(dirtyMask, spec.synchHandThrottleDirtyFlag) ~= 0) then
			streamWriteUIntN(streamId, spec.handThrottlePercent * 100, 7)
		end		

		-- cvt 
		if streamWriteBool(streamId, bitAND(dirtyMask, spec.synchCVTDirtyFlag) ~= 0) then
			streamWriteUIntN(streamId, spec.cvtPercent * 100, 7)
		end			
	end
	
end

function realismAddon_gearbox_inputs:onReadUpdateStream(streamId, timestamp, connection)
	local spec = self.spec_realismAddon_gearbox_inputs
	
	if not connection:getIsServer() and spec.allManualActive then 
		-- hand throttle
		if streamReadBool(streamId) then
			spec.handThrottlePercent = streamReadUIntN(streamId, 7) / 100
		end		

		-- cvt 
		if streamReadBool(streamId) then
			spec.cvtPercent = streamReadUIntN(streamId, 7) / 100
		end			
	end
	
end



-- Bug-Fix for Giants - Default only 7 gear Inputs synchronized in MP but 8 inputs in game 
function realismAddon_gearbox_inputs.MotorGearShiftEvent_readStream(self, superFunc, streamId, connection)

	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self.shiftType = streamReadUIntN(streamId, 4)

	if self.shiftType == MotorGearShiftEvent.TYPE_SELECT_GEAR or self.shiftType == MotorGearShiftEvent.TYPE_SELECT_GROUP then
		self.shiftValue = streamReadUIntN(streamId, 5)  -- changed bits from 3 (gear 1-7) to 5 (up to 31 gears possible)
	end

	self:run(connection)
end
MotorGearShiftEvent.readStream = Utils.overwrittenFunction(MotorGearShiftEvent.readStream, realismAddon_gearbox_inputs.MotorGearShiftEvent_readStream)


function realismAddon_gearbox_inputs.MotorGearShiftEvent_writeStream(self, superFunc, streamId, connection)

	NetworkUtil.writeNodeObject(streamId, self.vehicle)
	streamWriteUIntN(streamId, self.shiftType, 4)

	if self.shiftType == MotorGearShiftEvent.TYPE_SELECT_GEAR or self.shiftType == MotorGearShiftEvent.TYPE_SELECT_GROUP then
		streamWriteUIntN(streamId, self.shiftValue, 5)  -- changed bits from 3 (gear 1-7) to 5 (up to 31 gears possible)
	end
end
MotorGearShiftEvent.writeStream = Utils.overwrittenFunction(MotorGearShiftEvent.writeStream, realismAddon_gearbox_inputs.MotorGearShiftEvent_writeStream)





