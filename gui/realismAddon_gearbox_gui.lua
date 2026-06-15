-- by modelleicher 
-- GUI for realismAddon Gearbox
-- works in conjunction with realismAddon_gearbox_gui.xml 


realismAddon_gearbox_gui = {}


local realismAddon_gearbox_gui_mt = Class(realismAddon_gearbox_gui, YesNoDialog)


-- create GUI 
function realismAddon_gearbox_gui:new(target, customMt)
	return YesNoDialog:new(nil, realismAddon_gearbox_gui_mt)
end

-- load and setup all relevant variables post loading the GUI
function realismAddon_gearbox_gui.postNew(self, vehicle)
    self.vehicle = vehicle

    -- ok button (save and close the GUI)
    self.yesButton.onClickCallback = realismAddon_gearbox_gui.yesButton_callback

    -- keyboard Clutch Toggle
    self.ragb_keyboardClutch_autoOpen.onClickCallback = realismAddon_gearbox_gui.ragb_keyboardClutch_autoOpen_callback
    self.ragb_keyboardClutch_autoOpen:setIsChecked(self.vehicle.spec_realismAddon_gearbox.keyboardClutch_enableAutoOpen, true)

    self.ragb_keyboardClutch_autoMovement.onClickCallback = realismAddon_gearbox_gui.ragb_keyboardClutch_autoMovement_callback
    self.ragb_keyboardClutch_autoMovement:setIsChecked(self.vehicle.spec_realismAddon_gearbox.keyboardClutch_enableAutoMovement, true)

end

-- Callback for the OK Button, save settings and close the GUI 
function realismAddon_gearbox_gui:yesButton_callback(state, table)
    -- if we hit ok we need to save the settings again 
    --realismAddon_gearbox_settings:saveGlobalSettings(true)
    self:close()
end

-- Keyboard Clutch Toggle 
function realismAddon_gearbox_gui:ragb_keyboardClutch_autoOpen_callback(state, table, test)
    if state == 1 then    -- state 1 = off, state 2 = on 
        self.vehicle:keyboardClutch_enableAutoOpen_set(false)       
    else
        self.vehicle:keyboardClutch_enableAutoOpen_set(true)  
    end
end

function realismAddon_gearbox_gui:ragb_keyboardClutch_autoMovement_callback(state, table, test)
    if state == 1 then                 -- target, value, isPlayerSpecific, force
        self.vehicle:keyboardClutch_enableAutoMovement_set(false)       
    else
        self.vehicle:keyboardClutch_enableAutoMovement_set(true)  
    end
end



