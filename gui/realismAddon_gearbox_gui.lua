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
    self.ragb_keyboardClutch_toggle.onClickCallback = realismAddon_gearbox_gui.keyboardClutchToggle_callback
    self.ragb_keyboardClutch_toggle:setIsChecked(self.vehicle:globalSettingsGet("spec_realismAddon_gearbox.keyboardClutch.enabled", true), true)   -- setIsChecked = true -> slider to the right 


end

-- Callback for the OK Button, save settings and close the GUI 
function realismAddon_gearbox_gui:yesButton_callback(state, table)
    -- if we hit ok we need to save the settings again 
    realismAddon_gearbox_settings:saveGlobalSettings()
    self:close()
end

-- Keyboard Clutch Toggle 
function realismAddon_gearbox_gui:keyboardClutchToggle_callback(state, table, test)
    print("keyboardClutchToggle_callback CALLBACK"..tostring(state))
    if state == 1 then                 -- target, value, isPlayerSpecific, force
        self.vehicle:globalSettingsSet("spec_realismAddon_gearbox.keyboardClutch.enabled", false, nil, true)       
    else
        self.vehicle:globalSettingsSet("spec_realismAddon_gearbox.keyboardClutch.enabled", true, nil, true)  
    end
end






function realismAddon_gearbox_gui:testCallback(state, table, test)

    print("TEST CALLBACK")
    print(tostring(state))
    print(tostring(table))  
        for k, v in pairs(table) do
        print(" - "..tostring(k).." - "..tostring(v))
    end   
    print(tostring(test))     
    print("*************")   
end


