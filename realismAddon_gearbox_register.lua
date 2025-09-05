-- by modelleicher ( Farming Agency )
-- register realismAddon_gearbox specializations and insert to vehicles 


-- realismAddon_gearbox_spec contains everything that needs to be in a spec (e.g. everything that is not an overwritten function)
g_specializationManager:addSpecialization("realismAddon_gearbox_spec", "realismAddon_gearbox_spec", g_currentModDirectory.."realismAddon_gearbox_spec.lua")
-- realismAddon_gearbox_inputs contains only Inputs and Functions that are called via the Input Callback
g_specializationManager:addSpecialization("realismAddon_gearbox_inputs", "realismAddon_gearbox_inputs", g_currentModDirectory.."realismAddon_gearbox_inputs.lua")
-- everything else is in realismAddon_gearbox_overrides



realismAddon_gearbox_register = {}

realismAddon_gearbox_register.done = false

function realismAddon_gearbox_register:register(name)

	if not realismAddon_gearbox_register.done then
    
		for _, vehicle in pairs(g_vehicleTypeManager:getTypes()) do
			
			local motorized = false;
			local realismAddon_gearbox_inputs = false;
			local realismAddon_gearbox_spec = false;
						
			for _, spec in pairs(vehicle.specializationNames) do
			
				if spec == "motorized" then -- check for motorized, only insert into motorized
					motorized = true;
				end
				if spec == "realismAddon_gearbox_inputs" then -- don't insert if already inserted
					realismAddon_gearbox_inputs = true;
				end
				if spec == "realismAddon_gearbox_spec" then -- don't insert if already inserted
					realismAddon_gearbox_spec = true;
				end

				
			end    
			if motorized then
				if not realismAddon_gearbox_spec then
					g_vehicleTypeManager:addSpecialization(vehicle.name, "FS25_realismAddon_gearbox.realismAddon_gearbox_spec")
				end				
				if not realismAddon_gearbox_inputs then				
					g_vehicleTypeManager:addSpecialization(vehicle.name, "FS25_realismAddon_gearbox.realismAddon_gearbox_inputs")
				end
			end
		end
		
		realismAddon_gearbox_register.done = true
	end
end

TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, realismAddon_gearbox_register.register)