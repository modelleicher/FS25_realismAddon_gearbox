-- by modelleicher ( Farming Agency )

-- this script contains all overwritten basegame functions and related helper functions


-- gearbox adjustments - notes 

-- remove all automatic braking - done 
-- add auto acceleration below min rpm - done 
-- brake and acc pedal still works fine - done 
-- figure out why rpm is above minRpm now - done 
-- wheel rpm -> diff rpm -> clutch rpm -> motor rpm realignment - done 
-- load add-in when neutral or clutch - done
-- check clutch engagement how/where what - done
-- add clutch-feel from RMT, make clutch slippable - done 
-- hand throttle add in - done
-- added fps axis shifting, analog axis for gear selection - done 
-- check and override pto rpm stuff - done 
-- stop running away when motor off - done 

-- smaller fixes 
-- currentGearRatio set to 0 if in neutral, remove jerking when clutch is released in neutral - done 
-- added smoothing of acceleration value to stabilize rpm and load and lastAcceleratorPedal				 
-- updateGear function seems to be the only one where clutch ratio has influence on gear ratio #M1 - yep, that solved it 

-- things to add and consider	
-- 		work out a way to calculate and interpolate between forward-reverse when vehicle is moving and clutch is pressed to stop vehicle from sudden stop when starting to engage clutch and vehicle rolls in opposite speed 

-- wrong RPM calculation between clutchValue 0.8 and 0.9 -- made clutch completely disengaged at 0.8 solves this.. don't have any other way atm since thats a engine function that returns the wrong value and I don't know which values influence that if any 


--  manualClutchValue = 0 -> clutch closed, 1 -> clutch open 
-- 	inverted = 1 -> clutch closed 0 -> open
-- notes end 

realismAddon_gearbox_overrides = {}

-- "globals"
-- some values are needed multiple times across different functions and might be subject to change/adjustment, put them here at the top
local MAX_ACCELERATION_LOAD = 0.8
local CLUTCH_FULLY_DISENGAGED = 0.2
local CLUTCH_FULLY_DISENGAGED_INV = 1 - CLUTCH_FULLY_DISENGAGED
local CLUTCH_CLOSED_RANGE = 0.10
local CLUTCH_CLOSED_RANGE_INV = 1 - CLUTCH_CLOSED_RANGE
local CLUTCH_LOWER_TORQUE_LIMIT_PERCENT = 0.01 -- lower limit, don't reduce torque to 0 as that causes issues
local FLUID_CLUTCH_IDLE_CLOSING_PERCENTAGE = 0.21

-- function to check and return if vehicle and settings are manual 
function realismAddon_gearbox_overrides.checkIsManual(motor)
	-- since powershift transmissions are automatically set to SHIFT_MODE_MANUAL checking which gearShiftMode is set is really difficult 
	-- vehicles are either manual or manualClutch depending on the gearbox
	-- so if manual + motor.gearChangeTime == 0 is powershift but that does not exclude the manual (without clutch) setting in the menu
	-- if I get the g_gameSettings value directly I can see what is actually set 
	-- the issue with all that is in Multiplayer, where this is different for each user 
	-- therefor we overwrite setGearShiftMode to stop the game from switching to MANUAL (without clutch) in case of powershift 
	-- now that we preserve the user setting we can use that for our automatic keyboard clutch 

	local isManualTransmission = motor.backwardGears ~= nil or motor.forwardGears ~= nil	

	local localSettingManual = motor.gearShiftMode == VehicleMotor.SHIFT_MODE_MANUAL
	local localSettingManualClutch = motor.gearShiftMode == VehicleMotor.SHIFT_MODE_MANUAL_CLUTCH
	local localSettingAutomatic = motor.gearShiftMode == VehicleMotor.SHIFT_MODE_AUTOMATIC

	local globalSetting = g_gameSettings:getValue(GameSettings.SETTING.GEAR_SHIFT_MODE)

	--print("manual: "..tostring(manual).." manualClutch: "..tostring(manualClutch).." automatic: "..tostring(automatic))

	local isManualShiftMode = motor.gearShiftMode == VehicleMotor.SHIFT_MODE_MANUAL_CLUTCH 

	if isManualTransmission and localSettingManualClutch then
		return true, nil
	elseif isManualTransmission and localSettingManual then
		return true, true
	else
		return false, nil
	end

end

-- completely overwrite VehicleMotor.setGearShiftMode, basegame sets mode to manual instead of manual_clutch if powershift transmission
-- we want to keep the setting no matter what type of transmission 
function realismAddon_gearbox_overrides.setGearShiftMode(self, superFunc, gearShiftMode)
	self.gearShiftMode = gearShiftMode
end
VehicleMotor.setGearShiftMode = Utils.overwrittenFunction(VehicleMotor.setGearShiftMode, realismAddon_gearbox_overrides.setGearShiftMode)


-- completely overwrite VehicleMotor.getLastModulatedMotorRpm to remove the RPM-lowering effect on load-changes. This seems to be done on purpose by Giants for whatever reason. 
-- I don't think we need anything in that function so just return unmodified lastMotorRpm (to try, maybe return lastRealMotorRpm instead even) 
-- this is active no matter what as soon as this script is active while other functions only activate when MANUAL + CLUTCH setting is active 
function realismAddon_gearbox_overrides.newGetLastModulatedMotorRpm(self, superFunc)
    return self.lastMotorRpm
end
VehicleMotor.getLastModulatedMotorRpm = Utils.overwrittenFunction(VehicleMotor.getLastModulatedMotorRpm, realismAddon_gearbox_overrides.newGetLastModulatedMotorRpm)

-- overwrite VehicleMotor.getGearToDisplay (this is for the hud)
-- show "P" instead of gear when handbrake is used and active on incab displays 
function realismAddon_gearbox_overrides.getGearToDisplay(self, superFunc, val, val2, val3, val4, val5)

	local value = superFunc(self, val, val2, val3, val4, val5)
	if realismAddon_gearbox_overrides.checkIsManual(self) then
		local spec = self.vehicle.spec_realismAddon_gearbox
		
		if spec.handbrakeUseME and spec.handbrakeStateME then
			value = "P"
		end
	end
	return value
end

VehicleMotor.getGearToDisplay = Utils.overwrittenFunction(VehicleMotor.getGearToDisplay, realismAddon_gearbox_overrides.getGearToDisplay)

-- overwrite Motorized.getGearInfoToDisplay (this is for the Dashboards)
-- show "P" instead of gear when handbrake is used and active on lower right vehicle HUD
function realismAddon_gearbox_overrides.getGearInfoToDisplay(self, superFunc, val)

	local val1, val2, val3, val4, val5, val6, val7, val8, val9, val10 = superFunc(self, val)
	local spec_ragb = self.spec_realismAddon_gearbox
	if spec_ragb.handbrakeUseME and	spec_ragb.handbrakeStateME then
		val1 = "P"
	end

	return val1, val2, val3, val4, val5, val6, val7, val8, val9, val10
end
Motorized.getGearInfoToDisplay = Utils.overwrittenFunction(Motorized.getGearInfoToDisplay, realismAddon_gearbox_overrides.getGearInfoToDisplay)

function realismAddon_gearbox_overrides.getIsInNeutral(self, superFunc)
	if realismAddon_gearbox_overrides.checkIsManual(self) then
		local isNeutral = superFunc(self) 
		if self.vehicle.spec_realismAddon_gearbox.cvt ~= nil and self.vehicle.spec_realismAddon_gearbox.cvt.hasNeutral then
			if self.vehicle.spec_realismAddon_gearbox.cvt.neutral then
				isNeutral = true
			end
		end
		return isNeutral
	else
		return superFunc(self)
	end
end
VehicleMotor.getIsInNeutral = Utils.overwrittenFunction(VehicleMotor.getIsInNeutral, realismAddon_gearbox_overrides.getIsInNeutral)


-- overwrite VehicleMotor.getGearRatioMultiplier
-- gear ratio multiplier calculation, secondGroup and CVT are injected here
function realismAddon_gearbox_overrides.getGearRatioMultiplier(self, superFunc)
	if realismAddon_gearbox_overrides.checkIsManual(self) then

		local vehicle = self.vehicle
		local spec = vehicle.spec_realismAddon_gearbox
		-- get original multiplier
		local multiplier = superFunc(self)

		-- add realismAddon_gearbox multipliers 
		if spec ~= nil then 

			-- second Group Set 
			if spec.groupsSecondSet ~= nil and spec.groupsSecondSet.currentGroup ~= nil then
				multiplier = multiplier / spec.groupsSecondSet.groups[spec.groupsSecondSet.currentGroup].ratio
			end

			-- manual CVT
			if spec.cvt ~= nil then 
				local cvtInput = 1
				local direction = 1				
				if spec.cvt.manualControl then 
					
					if spec.cvt.direction ~= nil then
						direction = spec.cvt.direction
					end
					cvtInput = spec.cvt.cvtPercent 
				elseif spec.cvt.accControl then 
					-- -- TO DO
				end
				local cvtRatio = ((spec.cvt.maxPercentage - spec.cvt.minPercentage) * spec.cvt.cvtPercent) + spec.cvt.minPercentage
		
				--print("cvtRatio: "..tostring(cvtRatio).." direction: "..tostring(direction))

				multiplier = multiplier / cvtRatio * direction
			end	
		end

		return multiplier
	else
		return superFunc(self)
	end	
end
VehicleMotor.getGearRatioMultiplier = Utils.overwrittenFunction(VehicleMotor.getGearRatioMultiplier, realismAddon_gearbox_overrides.getGearRatioMultiplier)

-- Overwrite original VehicleMotor.getClutchPedal function to directly change motor.manualClutchValue
-- alternative, overwrite getIsGearChangeAllowed() and getIsGearGroupChangeAllowed() but there's still some residual code from basegame that might use manualClutchValue
-- so for overwriting the actual clutch value this seems safest
-- in this function we now set the motor.manualClutchValue to our value
-- this function is used to synch the clutch-pedal so mp synch keeps working
-- call this function now every time manualClutchValue is needed and subject to change because it only checks and updates if this function is called
function realismAddon_gearbox_overrides.getClutchPedal(self, superFunc)
	
	
	local spec = self.vehicle.spec_realismAddon_gearbox
	if realismAddon_gearbox_overrides.checkIsManual(self) and spec ~= nil then
		
		--print("manualClutchValue1: "..tostring(self.manualClutchValue))

		local override = 0

		-- fluidClutch
		if spec.fluidClutch ~= nil then 
			override = math.max(override, 1-math.max(spec.fluidClutch.clutchPercent, FLUID_CLUTCH_IDLE_CLOSING_PERCENTAGE * spec.fluidClutch.idleBiasFx))
		end

		if spec.keyboardClutch.enabled then 
			override = math.max(override, 1-spec.keyboardClutch.clutchPercent)
		end

		if spec.cvt ~= nil and spec.cvt.isVario then
			override = math.max(override, 1-spec.cvt.pressureValvePercentage)
		end

		-- take the max value between original, spec.override or local override
		self.manualClutchValue = math.max(self.manualClutchValue, spec.clutchValueOverride, override)

		--print("manualClutchValue2: "..tostring(self.manualClutchValue))

		return self.manualClutchValue
	else
		return superFunc(self)
	end

end
VehicleMotor.getClutchPedal = Utils.overwrittenFunction(VehicleMotor.getClutchPedal, realismAddon_gearbox_overrides.getClutchPedal)

-- hook into onManualClutchChanged to create a raw value since we change manualClutchValue 
function realismAddon_gearbox_overrides.onManualClutchChanged(self, superFunc, clutchValue)
	self.manualClutchValueRaw = clutchValue
	self.manualClutchValue = clutchValue
end
VehicleMotor.onManualClutchChanged = Utils.overwrittenFunction(VehicleMotor.onManualClutchChanged, realismAddon_gearbox_overrides.onManualClutchChanged)


-- new clutch calculation, more aligned with how clutches IRL work
-- still not entirely realistic but given the constraints of FS physics this is closer than the old calculation
-- actually limiting torque transmitted depending on clutch value instead of changing ratio
-- the change of ratio is a side-effect of the limited torque a partially opened clutch can transmit IRL, not the main cause why/how a clutch works
-- if we limit the torque from the engine we can achieve a similar effect without influencing ratio at all
-- unfortunately we can't limit torque on/at the clutch since FS physics does not have a working clutch so limiting what the engine can provide is the next best thing
-- V 0.9.3.1 change - moved from getTorqueCurveValue to getTorqueAndSpeedValues to fix visual bug in Debug Menu for torque curve showing
function realismAddon_gearbox_overrides.getTorqueAndSpeedValues(self, superFunc)

	if realismAddon_gearbox_overrides.checkIsManual(self) then
		local speeds = {}
		local torques = {}

		local clutchPercent = 1 - self:getClutchPedal()	

		for _, torque in ipairs(self:getTorqueCurve().keyframes) do
			table.insert(speeds, torque.time * 3.141592653589793 / 30)

			local torque = self:getTorqueCurveValue(torque.time)

			-- if clutch is closed less than 95% calculate torque depending on clutch position, the last 5% are clutch fully closed
			if clutchPercent < CLUTCH_CLOSED_RANGE_INV then 
				torque = math.max(torque * clutchPercent, CLUTCH_LOWER_TORQUE_LIMIT_PERCENT) -- limit to 10% of torque lower
			end		

			table.insert(torques, torque)
		end		

		return torques, speeds
	else
		return superFunc(self)
	end

end
VehicleMotor.getTorqueAndSpeedValues = Utils.overwrittenFunction(VehicleMotor.getTorqueAndSpeedValues, realismAddon_gearbox_overrides.getTorqueAndSpeedValues)


-- OPEN TO DO
function realismAddon_gearbox_overrides.getConsumedPtoTorque(self, superFunc, expected, ignoreTurnOnPeak)

	local returnValue1, returnValue2 = superFunc(self, expected, ignoreTurnOnPeak)

	if self:getIsActiveForInput(true) then
		local spec = self.spec_powerConsumer
		local rpm = spec.ptoRpm


		--renderText(0.1, 0.5, 0.03, "rpm: "..tostring(rpm))
	    --renderText(0.1, 0.55, 0.03, "powerKN: "..tostring(powerKN))
	end 

	return returnValue1, returnValue2
end
PowerConsumer.getConsumedPtoTorque = Utils.overwrittenFunction(PowerConsumer.getConsumedPtoTorque, realismAddon_gearbox_overrides.getConsumedPtoTorque)
--


-- overwrite VehicleMotor.getRequiredMotorRpmRange
-- make sure pto implements don't raise RPM when turned on
function realismAddon_gearbox_overrides.getRequiredMotorRpmRange(self, superFunc)
	if realismAddon_gearbox_overrides.checkIsManual(self) then
		return self.minRpm, self.maxRpm
	else
		return superFunc(self)
	end
end
VehicleMotor.getRequiredMotorRpmRange = Utils.overwrittenFunction(VehicleMotor.getRequiredMotorRpmRange, realismAddon_gearbox_overrides.getRequiredMotorRpmRange)


-- overwrite VehicleMotor.update
function realismAddon_gearbox_overrides.update(self, superFunc, dt)

	-- do our custom stuff only if we are in SHIFT_MODE_MANUAL_CLUTCH and in a vehicle with manual transmission
	if realismAddon_gearbox_overrides.checkIsManual(self) then	
		
		local vehicle = self.vehicle

		-- ME Addition --
		-- take additional clutch value overrides into account 
		local manualClutchValue = self:getClutchPedal()
		local clutchPercent = 1 - manualClutchValue
		--
		
		-- base stuff 
		if next(vehicle.spec_motorized.differentials) ~= nil and vehicle.spec_motorized.motorizedNode ~= nil then
			local lastMotorRotSpeed = self.motorRotSpeed
			local lastDiffRotSpeed = self.differentialRotSpeed
			self.motorRotSpeed, self.differentialRotSpeed, self.gearRatio = getMotorRotationSpeed(vehicle.spec_motorized.motorizedNode)
			
			-- if clutch is disengaged more than 80% getMotorRotationSpeed will return wrong values for the motor rot speed, it will always return max rpm not sure why 
			if g_physicsDtNonInterpolated > 0 and not getIsSleeping(vehicle.rootNode) then
				self.lastMotorAvailableTorque, self.lastMotorAppliedTorque, self.lastMotorExternalTorque = getMotorTorque(vehicle.spec_motorized.motorizedNode)
			end

			-- ME Addition --
			-- if clutch is open applied torque is 0 -- 
			if clutchPercent <= CLUTCH_FULLY_DISENGAGED then
				self.lastMotorAppliedTorque = 0
			end
			-- removed lastMotorAvailableTorque influenced by clutch because it already is physics-side 

			local clutchPercent = 1 - self:getClutchPedal()

			--self.lastMotorAvailableTorque = self.lastMotorAvailableTorque * clutchPercent

			-- -- 
			print("lastMotorAvailableTorque: "..tostring(self.lastMotorAvailableTorque))


			local motorRotAcceleration = ((self.motorRotSpeed - lastMotorRotSpeed)+0.00001) / ((g_physicsDtNonInterpolated * 0.001)+0.00001) 	-- FS25 Fix add 0.00001 to avoid division by 0 error 
			self.motorRotAcceleration = motorRotAcceleration
			self.motorRotAccelerationSmoothed = 0.8 * self.motorRotAccelerationSmoothed + 0.2 * motorRotAcceleration
			
			local diffRotAcc = 0
			self.differentialRotAcceleration = 0
			if self.differentialRotSpeed ~= 0 and lastDiffRotSpeed ~= 0 then
				local diffRotAcc = ((self.differentialRotSpeed - lastDiffRotSpeed)+0.00001) / ((g_physicsDtNonInterpolated * 0.001)+0.00001) 	-- FS25 Fix add 0.00001 to avoid division by 0 error 
				self.differentialRotAcceleration = diffRotAcc
			end
			
			self.differentialRotAccelerationSmoothed = 0.95 * self.differentialRotAccelerationSmoothed + 0.05 * diffRotAcc	
		
			self.motorExternalTorque = self.lastMotorExternalTorque
			self.motorAppliedTorque = self.lastMotorAppliedTorque
			self.motorAvailableTorque = self.lastMotorAvailableTorque
			
			self.motorAppliedTorque = self.motorAppliedTorque - self.motorExternalTorque	
			self.motorExternalTorque = math.min(self.motorExternalTorque * self.externalTorqueVirtualMultiplicator, self.motorAvailableTorque - self.motorAppliedTorque)			
			self.motorAppliedTorque = self.motorAppliedTorque + self.motorExternalTorque
			
			self.requiredMotorPower = math.huge
			
		else
			local _, gearRatio = self:getMinMaxGearRatio()
			self.differentialRotSpeed = WheelsUtil.computeDifferentialRotSpeedNonMotor(vehicle)
			self.motorRotSpeed = math.max(math.abs(self.differentialRotSpeed * gearRatio), 0)
			self.gearRatio = gearRatio
		end
		
		local clampedMotorRpm = math.max(self.motorRotSpeed*30/math.pi, self.minRpm)
		

		-- lastMotorRpm is smoothed
		-- lastRealMotorRpm is not smoothed 
		

		-- modelleicher 
		-- if clutch is pressed, motor RPM is not dependent on wheel speed anymore.. Instead, calculate motor RPM based on accelerator pedal input 
		if manualClutchValue > CLUTCH_CLOSED_RANGE or self:getIsInNeutral() then		
			
			if self:getIsInNeutral() then
				clutchPercent = 0
			end
			
			local accInput = 0
			if vehicle.getAxisForward ~= nil then
				accInput = math.max(0, vehicle:getAxisForward())
			end
			
			-- take hand throttle into account 
			if vehicle.spec_realismAddon_gearbox_inputs ~= nil then	
				accInput = math.max(accInput, vehicle.spec_realismAddon_gearbox_inputs.handThrottlePercent)
			end
			
			local wantedRpm = (self.maxRpm - self.minRpm) * accInput + self.minRpm
			local currentRpm = self.lastRealMotorRpm
			if currentRpm < wantedRpm then
				currentRpm = math.min(currentRpm + 2 * dt, wantedRpm)  -- to do, do proper engine rpm increase calculation ß
			elseif currentRpm > wantedRpm then
				currentRpm = math.max(currentRpm - 1 * dt, wantedRpm)
			end	

			-- non-linear rpm clutch influence -- non-linearity could be changed for different engine reaction to clutch closing but ^3 seems pretty good
			clampedMotorRpm = clampedMotorRpm * (clutchPercent^3) + (currentRpm * (1-(clutchPercent^3)))

		else
		
			-- get clutch RPM shut off motor if RPM gets too low , disable "auto clutch" of FS
			local clutchRpm = math.abs(self:getClutchRotSpeed() *  9.5493)
			
			-- set rpm to clutch rpm if clutch rpm is smaller than min rpm (this doesn't work on Multiplayer)
			if clutchRpm < self.minRpm and clutchRpm > 0 then -- only if not 0 cause Multiplayer 
				clampedMotorRpm = (self.lastRealMotorRpm * 0.7) + (clutchRpm * 0.3)
			end		
			
			-- this doesn't work like that in FS22, so disable for now. Set clampedMotorRpm to minRpm if vehicle is stopped anyways ß
			if clutchRpm <= 0 and vehicle.isServer then -- check if we're server 
				vehicle:stopMotor()
				clampedMotorRpm = self.minRpm
			end
			
			-- same as above 
			if clampedMotorRpm <= 0 then
				vehicle:stopMotor()
				clampedMotorRpm = self.minRpm
				self.lastRealMotorRpm = self.minRpm
			end

			-- clamp so no negative value 
			clampedMotorRpm = math.max(clampedMotorRpm, 0)	
		end
		
		-- finally set the new RPM values
		if vehicle.isServer then	

			-- setLastRpm does have some smoothing included 	
			-- we do some smoothing before anyways because otherwise it will false-register fast rpm changes and inject load 
			-- TO DO :check if we deactivate the smoothing on dedicated servers because due to synching its all slower anyways and already reacts slower than we want 
			if self.clampedMotorRpm == nil then
				self.clampedMotorRpm = clampedMotorRpm
			end
			self.clampedMotorRpm = self.clampedMotorRpm * 0.6 + clampedMotorRpm * 0.4
			
			-- set last rpm 
			self:setLastRpm(self.clampedMotorRpm)

			self.lastPtoRpm = self.clampedMotorRpm			
		
			-- for the equalizedMotorRpm we want heavy smoothing still, though not sure what equalizedMotorRpm is used for in Fs22 I don't think much, maybe in multiplayer  
			self.equalizedMotorRpm = (self.equalizedMotorRpm * 0.9) + ( 0.1 * clampedMotorRpm)
		end		
	
		
		if vehicle.isServer then
		
			-- load calculation by Giants, this doesn't look bad at all 
			
			-- raw and buffer 

			-- ME Addition --
			-- if clutch is open applied torque is 0 -- 
			local lastMotorAppliedTorque = self:getMotorAppliedTorque()
			local lastMotorAvailableTorque = math.max(self:getMotorAvailableTorque(), 0.0001)	
			
			local rawLoadPercentage = lastMotorAppliedTorque / lastMotorAvailableTorque

			--			
			--print("rawLoadPercentage: "..tostring(rawLoadPercentage))
			--print("getMotorAppliedTorque: "..tostring(lastMotorAppliedTorque))
			--print("getMotorAvailableTorque: "..tostring(lastMotorAvailableTorque))

			self.rawLoadPercentageBuffer = self.rawLoadPercentageBuffer + rawLoadPercentage
			self.rawLoadPercentageBufferIndex = self.rawLoadPercentageBufferIndex + 1

			local buffersize = 10
			if self.rawLoadPercentage >= 0.5 then
				buffersize = 2
			end
			
			if self.rawLoadPercentageBufferIndex >= buffersize then
				self.rawLoadPercentage = self.rawLoadPercentageBuffer / buffersize
				self.rawLoadPercentageBuffer = 0
				self.rawLoadPercentageBufferIndex = 0
			end
			
			-- downhill / push 
			if self.rawLoadPercentage < 0.01 and self.lastAcceleratorPedal < 0.2 and (not self.backwardGears and not self.forwardGears or self.gear ~= 0 or self.targetGear == 0) then
				self.rawLoadPercentage = -1
			else
				-- min idle load 
				local idleLoadPct = 0.05
				self.rawLoadPercentage = (self.rawLoadPercentage - idleLoadPct) / (1 - idleLoadPct)
			end
			
			-- modelleicher
			-- add in load percentage if engine is accelerating in neutral or with clutch pressed 
			local currentRpm = self.lastRealMotorRpm
			local mAxisForward = 0
			if vehicle.getAxisForward ~= nil then
				mAxisForward = math.max(0, vehicle:getAxisForward())
			end			
			
			-- TO DO change this maybe? so 0.1 instead of 0.6 halfway closed clutch
			-- if clutch is pressed or neutral, load percentage is calculated using wanted and actual RPM 
			if clutchPercent < 0.6 or self:getIsInNeutral() then
				local loadNeutral
				if (currentRpm / self.maxRpm) < mAxisForward then
					loadNeutral = 1
				else
					loadNeutral = 0
				end
				self.rawLoadPercentage = math.max(self.rawLoadPercentage, loadNeutral)
			end	
			
			-- modelleicher end 
			
			-- Giants add in acceleration percentage, I think this is something that would've improved load calc in RMT 
			local accelerationPercentage = math.min(self.vehicle.lastSpeedAcceleration * 1000 * 1000 * self.vehicle.movingDirection / self.accelerationLimit, 1)

			if accelerationPercentage < 0.95 and self.lastAcceleratorPedal > 0.2 then
				self.accelerationLimitLoadScale = 1
				self.accelerationLimitLoadScaleTimer = self.accelerationLimitLoadScaleDelay
			elseif self.accelerationLimitLoadScaleTimer > 0 then
				self.accelerationLimitLoadScaleTimer = self.accelerationLimitLoadScaleTimer - dt
				local alpha = math.max(self.accelerationLimitLoadScaleTimer / self.accelerationLimitLoadScaleDelay, 0)
				self.accelerationLimitLoadScale = math.sin((1 - alpha) * 3.14) * 0.85
			end

			if accelerationPercentage > 0 then
				self.rawLoadPercentage = math.max(self.rawLoadPercentage, accelerationPercentage * self.accelerationLimitLoadScale)
			end
			

			self.constantAccelerationCharge = 1 - math.min(math.abs(self.vehicle.lastSpeedAcceleration) * 1000 * 1000 / self.accelerationLimit, 1)

			if (self.backwardGears or self.forwardGears) and self:getUseAutomaticGearShifting() then
				if self.constantRpmCharge > 0.99 then
					if self.maxRpm - clampedMotorRpm < 50 then
						self.gearChangeTimeAutoReductionTimer = math.min(self.gearChangeTimeAutoReductionTimer + dt, self.gearChangeTimeAutoReductionTime)
						self.gearChangeTime = self.gearChangeTimeOrig * (1 - self.gearChangeTimeAutoReductionTimer / self.gearChangeTimeAutoReductionTime)
					else
						self.gearChangeTimeAutoReductionTimer = 0
						self.gearChangeTime = self.gearChangeTimeOrig
					end
				else
					self.gearChangeTimeAutoReductionTimer = 0
					self.gearChangeTime = self.gearChangeTimeOrig
				end
			end

			if self.rawLoadPercentage > 0 then
				self.rawLoadPercentage = self.rawLoadPercentage * MAX_ACCELERATION_LOAD + self.rawLoadPercentage * (1 - MAX_ACCELERATION_LOAD) * self.constantAccelerationCharge
			end		
			
		end

		self:updateSmoothLoadPercentage(dt, self.rawLoadPercentage)	
		

		-- BLOW OF VALVE - DOES NOT WORK - TO DO
		if vehicle:getIsMotorStarted() then
		
			-- turbo calculation for blow-off and turbo sound 		ß
			local accInput = 0
			if vehicle.getAxisForward ~= nil then
				accInput = math.max(0, vehicle:getAxisForward())
			end
			if vehicle.spec_realismAddon_gearbox_inputs ~= nil then	
				accInput = math.max(accInput, vehicle.spec_realismAddon_gearbox_inputs.handThrottlePercent)
			end
			
			local wantedRpm = (self.maxRpm - self.minRpm) * accInput + self.minRpm
			local currentRpm = self.lastRealMotorRpm
			
			local differenceUnsigned =  math.min(wantedRpm, currentRpm) / math.max(wantedRpm, currentRpm)

			local sign = -1
			if (wantedRpm - 50) > currentRpm then
				sign = 1
			end
			
			if self.boostPressureME == nil then
				self.boostPressureME = 0
			end
			
			local boostPressureChangeSpeed = 0.03
			
			if sign == 1 then
				self.boostPressureME = math.min(self.boostPressureME + (boostPressureChangeSpeed * differenceUnsigned * (self.minRpm / self.maxRpm)), 1)
			else
				self.boostPressureME = math.max(self.boostPressureME - (boostPressureChangeSpeed * differenceUnsigned * (self.minRpm / self.maxRpm)), 0)		
			end
		
		else
			self.boostPressureME = 0
			self.blowOffValveStateME = 0
		end		
		
			
		if accInput == 0 or self:getIsInNeutral() or manualClutchValue > 0.8 or self.minGearRatio == 0 and self.autoGearChangeTime > 0 then
			self.blowOffValveStateME = self.boostPressureME
		else
			self.blowOffValveStateME = 0
		end		
		--
		-- 	
				
		-- fix for automatic gearbox 	
		if self.forwardGears or self.backwardGears then
			self:updateStartGearValues(dt)
		end
		
		
		-- lastSmoothedClutchPedal is used for the clutch animation 
		if self.lastSmoothedClutchPedal ~= nil then
			local clutchPedal = self:getClutchPedal()
			self.lastSmoothedClutchPedal = self.lastSmoothedClutchPedal * 0.9 + clutchPedal * 0.1
		end
		

	else
		return superFunc(self, dt)
	end
	
end



function realismAddon_gearbox_overrides.updateWheelsPhysics(self, superFunc, dt, currentSpeed, acceleration, doHandbrake, stopAndGoBraking)
	

	-- do our custom stuff only if we are in SHIFT_MODE_MANUAL_CLUTCH and in a vehicle with manual transmission
	if realismAddon_gearbox_overrides.checkIsManual(self.spec_motorized.motor) then		
	
		local motor = self.spec_motorized.motor
		local spec =self.spec_realismAddon_gearbox
	
		-- back up acceleration variable before we do any changes to it, we need this later for braking 
		local accBackup = acceleration
		
		-- acc and brake pedal init 
		local acceleratorPedal = 0
		local brakePedal = 0	
		
		-- take additional clutch value overrides into account 
		local manualClutchValue = motor:getClutchPedal() 
		local clutchPercent = 1 - manualClutchValue
		
		
		--
		local handThrottlePercent = 0
		if self.spec_realismAddon_gearbox_inputs ~= nil then	
			handThrottlePercent = self.spec_realismAddon_gearbox_inputs.handThrottlePercent
		end		
		--
		
		local newWantedAcceleration = 0
		-- use acceleration as rpm setting 
		if acceleration >= 0 then -- we are not braking 
		
			-- if hand throttle is more than acceleration, use hand throttle value 
			acceleration = math.max(acceleration, handThrottlePercent)
			
			-- calculate the currently wanted RPM depending on acceleration (e.g. pedal position)
			local wantedRpm = (motor.maxRpm - motor.minRpm) * acceleration + motor.minRpm
			
			-- if our wantedRPM is higher than the currentRPM, increase acceleration, if its lower, decrease acceleration
			if wantedRpm > motor.lastRealMotorRpm then
				newWantedAcceleration = 1
			else
				newWantedAcceleration = 0
			end
		end

		acceleration = newWantedAcceleration
		
		-- if engine rpm falls below minRpm acceleration is 1
		if acceleration >= 0 and motor.lastRealMotorRpm <= (motor.minRpm +2) then
			acceleration = 1
		end	
		
		-- if clutch is disengaged, acceleration is 0
		if manualClutchValue > CLUTCH_FULLY_DISENGAGED_INV then
			acceleration = 0
		end

		-- if motor is off, no acceleration 
		if not self:getIsMotorStarted() then
			acceleration = 0
		end
		
		-- if we are in neutral, acceleration is 0
		local accelerationNoNeutral = acceleration  -- automatic transmission fix 
		if motor:getIsInNeutral() then
			acceleration = 0
		end		

		-- smoothing acceleration (V 0.5.1.0 addition)
		if motor.lastAccelerationME == nil then
			motor.lastAccelerationME = acceleration
		end
		motor.lastAccelerationME = motor.lastAccelerationME * 0.9 + acceleration * 0.1


		-- limit acceleration when clutch starts to engage
		--local CLUTCH_ENGAGE_FACTOR = 2
		--acceleration = math.min(acceleration, acceleration * math.min(clutchPercent*CLUTCH_ENGAGE_FACTOR, 1))
		
		-- set accelerationPedal desired value 
		if acceleration > 0 then
			acceleratorPedal = acceleration
		end

		-- set brake pedal desired value  
		if accBackup < 0 then
			brakePedal = math.abs(accBackup)
		end 		
		
		-- hand brake basegame
		if doHandbrake then
			brakePedal = 1
		end

		-- handbrake RAGB (only use then Enhanced Vehicle is not active)
		if self.spec_realismAddon_gearbox.handbrakeStateME ~= nil and self.vData == nil  then
			if self.spec_realismAddon_gearbox.handbrakeStateME then
				brakePedal = 1
				doHandbrake = true
			end
		end
		
		-- Enhanced Vehicle Handbrake if Enhanced Vehicle is active 
		if self.vData ~= nil then
			if self.vData.is[13] then
				brakePedal = 1
				doHandbrake = true
			end
			self.spec_realismAddon_gearbox.handbrakeUseME = false
		end
		
																
		-- fix for automatic gear shifting in the new valtra tractors 
		-- motor:updateGear does not auto shift in reverse when accelerationPedal is bigger than brakePedal 
		
		if not motor:getUseAutomaticGearShifting() and not motor:getUseAutomaticGroupShifting() then
			acceleratorPedal, brakePedal = motor:updateGear(acceleratorPedal, brakePedal, dt)
		else
			-- auto acc pedal including direction 
			local acceleratorPedalAuto = accelerationNoNeutral * motor.currentDirection -- automatic transmission fix . acc no neutral 
			local brakePedalAuto = brakePedal
			-- if acc pedal is below 0, acc is 0 and brake is absolute of acc 
			if acceleratorPedalAuto < 0 then
				acceleratorPedalAuto = 0
				brakePedalAuto = math.abs(acceleratorPedal)				
			end
			-- call updateGear with modified acc and brake pedals 
			local acceleratorPedalA, brakePedalA = motor:updateGear(acceleratorPedalAuto, brakePedalAuto, dt)	
			
			-- open clutch on fully automatic transmissions when stopping (so either gears and groups automatic or gears automatic and no groups exist)
			if motor:getUseAutomaticGearShifting() and (motor:getUseAutomaticGroupShifting() and motor.numGearGroups ~= nil or motor.numGearGroups == nil) then

				if self:getLastSpeed() < 3 and accBackup <= 0 then 
					spec.clutchValueOverride = 1
				else
					spec.clutchValueOverride = 0
				end		
				
			end
			
			-- "fix" the return values to work with the rest of realismAddon_gearbox_overrides
			if acceleratorPedalAuto < 0 then
				acceleratorPedal = brakePedalA
				brakePedalA = brakePedal
			end
		end
		
		-- ##### OLD CODE NO LONGER IN USE ####
		-- #M1  -- in updateGear the current clutch ratio influences the current gear ratio 
				-- also it seems to be only called here, so instead of overwriting the entire function I can just do a new ratio calculation here 		
		
		-- better clutch feel, new ratio calc -- TO DO -- change this as no longer needed in that way
		-- realismAddon_gearbox_overrides.calculateClutchRatio(self, motor, accBackup, handThrottlePercent)
		-- ####################################

		-- Since the Clutch change from Ratio to Torque the clutch calculation is no longer needed 
		-- this is whats left of it, not sure if it is still required to set the min and max ratio again but it works
		local wantedGearRatio = 0
		if motor.currentGears[motor.gear] ~= nil then
			wantedGearRatio = motor.currentGears[motor.gear].ratio * motor:getGearRatioMultiplier()
		end		

		self.spec_motorized:updateMotorProperties()	

		motor.maxGearRatio = wantedGearRatio
		motor.minGearRatio = wantedGearRatio
		
		-- smoothing for lastAcceleratorPedal since the acceleratorPedal is on/off with my calculation, even with smoothing the load-changes are too fast (V 0.5.1.0 addition)
		if motor.lastAcceleratorPedalME == nil then
			motor.lastAcceleratorPedalME = motor.lastAcceleratorPedal  
		end
		motor.lastAcceleratorPedalME = motor.lastAcceleratorPedalME * 0.9 + acceleratorPedal * 0.1
		
		motor.lastAcceleratorPedal = motor.lastAcceleratorPedalME												  
							

		SpecializationUtil.raiseEvent(self, "onVehiclePhysicsUpdate", acceleratorPedal, brakePedal, automaticBrake, currentSpeed)


		--acceleratorPedal, brakePedal = WheelsUtil.getSmoothedAcceleratorAndBrakePedals(self, acceleratorPedal, brakePedal, dt)		
		
		-- basegame stuff 
		if next(self.spec_motorized.differentials) ~= nil and self.spec_motorized.motorizedNode ~= nil then
		
			local absAcceleratorPedal = math.abs(acceleratorPedal)
			local minGearRatio, maxGearRatio = motor:getMinMaxGearRatio()
			
			local maxSpeed = nil
			if maxGearRatio >= 0 then
				maxSpeed = motor:getMaximumForwardSpeed()
			else
				maxSpeed = motor:getMaximumBackwardSpeed()
			end
			
			maxSpeed = math.min(maxSpeed, motor:getSpeedLimit() / 3.6)
			local maxAcceleration = motor:getAccelerationLimit()
			local maxMotorRotAcceleration = motor:getMotorRotationAccelerationLimit()
			local minMotorRpm, maxMotorRpm = motor:getRequiredMotorRpmRange()
			local neededPtoTorque, ptoTorqueVirtualMultiplicator = PowerConsumer.getTotalConsumedPtoTorque(self)
			neededPtoTorque = neededPtoTorque / motor:getPtoMotorRpmRatio()
			local neutralActive = minGearRatio == 0 and maxGearRatio == 0 or manualClutchValue > CLUTCH_FULLY_DISENGAGED_INV
			motor:setExternalTorqueVirtualMultiplicator(ptoTorqueVirtualMultiplicator)


			if not neutralActive then 
				self:controlVehicle(absAcceleratorPedal, maxSpeed, maxAcceleration, minMotorRpm * math.pi / 30, maxMotorRpm * math.pi / 30, maxMotorRotAcceleration, minGearRatio, maxGearRatio, motor:getMaxClutchTorque(), neededPtoTorque)
			else
				self:controlVehicle(0, 0, 0, 0, math.huge, 0, 0, 0, 0, 0)

				brakePedal = math.max(brakePedal, 0.03)
			end
		end

		self:brake(brakePedal)		
		
		
	else
		superFunc(self, dt, currentSpeed, acceleration, doHandbrake, stopAndGoBraking)
	end
end

-- MoreRealistic Function Replacement (call overwrittenFunction much later for VehicleMotor.update and WheelsUtil.updateWheelsPhysics since we want to overwrite MR functions if exist)
function realismAddon_gearbox_overrides.loadMap(self, superFunc, a, b, c, d, e)

		--print("### LoadMap ###")

		VehicleMotor.update = Utils.overwrittenFunction(VehicleMotor.update, realismAddon_gearbox_overrides.update)

		WheelsUtil.updateWheelsPhysics = Utils.overwrittenFunction(WheelsUtil.updateWheelsPhysics, realismAddon_gearbox_overrides.updateWheelsPhysics)

		superFunc(self, a, b, c, d, e)
end 
BaseMission.loadMap = Utils.overwrittenFunction(BaseMission.loadMap, realismAddon_gearbox_overrides.loadMap)


-- allowing to edit XML Files while loading to fix basegame Transmissions
local modDirectory = g_currentModDirectory 
local modName = g_currentModName


function realismAddon_gearbox_overrides.load(self, superFunc, vehicleData, a, b, c, d, e)
	
	-- call superFunc first actually because vehicleData is only complete afterwards
	superFunc(self, vehicleData, a, b, c, d, e)
	
	-- set up the XML files 
	local vehicleXML = self.xmlFile
	local xmlFile = loadXMLFile("xmlEdits", modDirectory.."xmlEdits.xml")
	
	-- get modName (so this also works with Mods or DLC's)
	local modName, baseDirectory = Utils.getModNameAndBaseDirectory(vehicleData.storeItem.xmlFilename)
	local name = string.split(vehicleData.storeItem.xmlFilename, "FarmingSimulator2025/")
	
	local i = 0
	while true do
		
		-- get the name from our XML and check if it matches 
		local nameToEdit = getXMLString(xmlFile, "xmlEdits.editFile("..i..")#xmlFilename")
		if nameToEdit == nil or nameToEdit == "" then
			break
		end
						
		if nameToEdit == name[2] or nameToEdit == vehicleData.storeItem.xmlFilename then
				
			-- if it matches run through all XML paths and change the values 
			local x = 0
			while true do
			
				local path = getXMLString(xmlFile, "xmlEdits.editFile("..i..").attributes.attribute("..x..")#path")
				local value = getXMLString(xmlFile, "xmlEdits.editFile("..i..").attributes.attribute("..x..")#value")
				
				if path == nil or path == "" then
					break
				end
								
				setXMLString(self.xmlFile.handle, path, value)
				
				x = x + 1
			end
		
		end
		
		i = i + 1
	end
	
end
Vehicle.load = Utils.overwrittenFunction(Vehicle.load, realismAddon_gearbox_overrides.load)




