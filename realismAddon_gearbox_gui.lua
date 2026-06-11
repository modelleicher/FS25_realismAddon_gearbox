-- by modelleicher ( Farming Agency )
-- Inputs for realismAddon_gearbox 

realismAddon_gearbox_inputs = {}

function realismAddon_gearbox_inputs.prerequisitesPresent(specializations)
    return true
end


local modDirectory = g_currentModDirectory 
local modName = g_currentModName


-- ACTUAL SPEC 

function realismAddon_gearbox_inputs.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", realismAddon_gearbox_inputs)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", realismAddon_gearbox_inputs)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", realismAddon_gearbox_inputs)

end



-- LOAD
function realismAddon_gearbox_inputs:onLoad(savegame)

	
	self.addRealismAddonActionEvent = realismAddon_gearbox_inputs.addRealismAddonActionEvent

	self.spec_realismAddon_gearbox_gui = {}
	local spec = self.spec_realismAddon_gearbox_gui
	

 	g_overlayManager:addTextureConfigFile(modDirectory.."realismAddon_gearbox_guiConfigFile", "ragb_guiConfig")   
	




end




function realismAddon_gearbox_inputs:onUpdate(dt)


end


