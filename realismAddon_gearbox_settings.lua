-- the plan
-- global settings 
-- XML is in modSettings, loaded in realismAddon_gearbox_settings_global so it is only loaded once and not for each vehicle 
-- xml Values are then stored in realismAddon_gearbox_settings_global.settings table 
-- format is realismAddon_gearbox_settings_global.settings.TARGET_KEY.value 

-- in terms of saving, we need to hook into basegame save function to save the XML.
-- this would not be neccessary as there are no changes to the XML, but since we add all the settings during loading the different specializations we can't save
-- a full table of settings right away. This only matters for the first time the settings are created. But since values might change with updates to the script
-- we just keep saving them each time.
-- in addition we also need to save the settings when settings are actually changed 

-- each setting can be player specific. 
-- so each time we onEnter a vehicle we need to check if there are playerSpecific settings and update them (multiplayer only)

-- also, since we can change settings in the menu we need to update the changed values 
-- so we need to backsolve the settings from their target 

-- also each time settings are changed we need to send an event out to keep everything in synch
-- playerspecific settings are kept local and only send event when vehicle is entered 

-- ##################### 
-- workflow
            -- this is called in "load()" when setting up everything. It sets the default values if they don't exist and get the global values if they already exist 
--      self:globalSettingsGetSet("spec_realismAddon_gearbox.keyboardClutch.enabled", false, true)

            -- this is called to simply get the value and isPlayerSpecific for a given target 
--      self.vehicle:globalSettingsGet("spec_realismAddon_gearbox.keyboardClutch.enabled")

            -- this is called by the GUI button, it sets the value with force (this also sets it dirty and triggers the target backsolve )
--      self.vehicle:globalSettingsSet("spec_realismAddon_gearbox.keyboardClutch.enabled", false, nil, true)   
 -- #####################



-- Global Settings for RealismAddon Gearbox 
-- we use a modEventListener to load the settings in loadMap
-- this way the global settings are independent of specializations and thus only load once 
-- otherwise the XML would be loaded each time a vehicle is loaded or kept in memory for the entire duration of the game
realismAddon_gearbox_settings_global = {}

realismAddon_gearbox_settings_global.modSettingsDir = g_currentModSettingsDirectory

-- table containing all global realismAddon Gearbox Settings
realismAddon_gearbox_settings_global.settings = {}

addModEventListener(realismAddon_gearbox_settings_global)

function realismAddon_gearbox_settings_global.loadMap(name)

    print("LOAD MAP NAME SAVED")

    local filename = realismAddon_gearbox_settings_global.modSettingsDir.."settings.xml"
	local key = "settings"

 	-- create the folder if it doesn't exist
	createFolder(realismAddon_gearbox_settings_global.modSettingsDir)

    -- load xml File
	local xmlFile = XMLFile.loadIfExists("settingsXML", filename, key)   

    -- if the XML exists, load settings from it, else create it 
    if xmlFile ~= nil then
        
        local i = 0
        while true do
            local setting = {}
            local target = xmlFile:getString(key..".setting("..i..")#target")            

            if target == nil or target == "" then
                break
            end
            setting.target = target
            setting.valueType = xmlFile:getString(key..".setting("..i..")#valueType")   
            if setting.valueType == "number" then
                setting.value = xmlFile:getFloat(key..".setting("..i..")#value")
            elseif setting.valueType == "string" then
                setting.value = xmlFile:getString(key..".setting("..i..")#value")
            elseif setting.valueType == "boolean" then
                setting.value = xmlFile:getBool(key..".setting("..i..")#value")
            end
            
            setting.isPlayerSpecific = xmlFile:getBool(key..".setting("..i..")#isPlayerSpecific")

            print("LOAD: target: "..tostring(target).." value: "..tostring(setting.value).." isPlayerSpecific: "..tostring(setting.isPlayerSpecific))

            realismAddon_gearbox_settings_global.settings[target] = setting
            i = i+1
        end
		
		xmlFile:delete()
	else
		local xmlFile = XMLFile.create("settingsXML", filename, key)

		if xmlFile ~= nil then 		
			xmlFile:save()
			xmlFile:delete()
		end
	end
end



realismAddon_gearbox_settings = {} 



function realismAddon_gearbox_settings.prerequisitesPresent(specializations)
    return true
end

function realismAddon_gearbox_settings.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", realismAddon_gearbox_settings)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", realismAddon_gearbox_settings)
end

function realismAddon_gearbox_settings.registerFunctions(vehicleType)
    print("REGISTER FUNC")
	SpecializationUtil.registerFunction(vehicleType, "globalSettingsGetSet", realismAddon_gearbox_settings.globalSettingsGetSet)
	SpecializationUtil.registerFunction(vehicleType, "globalSettingsSet", realismAddon_gearbox_settings.globalSettingsSet)
 	SpecializationUtil.registerFunction(vehicleType, "globalSettingsGet", realismAddon_gearbox_settings.globalSettingsGet)   
 	SpecializationUtil.registerFunction(vehicleType, "backsolveTargetSet", realismAddon_gearbox_settings.backsolveTargetSet)          
end

function realismAddon_gearbox_settings:onLoad(savegame)

    print("ONLOAD ####")

end

-- set defaults or get value, this is used in load() to set the values initially
function realismAddon_gearbox_settings:globalSettingsGetSet(target, defaultValue, defaultIsPlayerSpecific)
    print("globalSettingsGetSet GETSET")
    print("input: "..tostring(defaultValue))

    self:globalSettingsSet(target, defaultValue, defaultIsPlayerSpecific)
    local value, isPlayerSpecific = self:globalSettingsGet(target, nil, defaultValue, defaultIsPlayerSpecific)
    print("output: "..tostring(value))    
    return value, isPlayerSpecific
end

-- set global settings in table
-- this is used to set a specific setting using target, optionally force update 
-- it also creates the setting variable if it doesn't exist yet 
-- we also need to track if a setting has been changed when this function is called and set it dirty 
function realismAddon_gearbox_settings:globalSettingsSet(target, value, isPlayerSpecific, force)
    print("globalSettingsSet")

    local globalSettings = realismAddon_gearbox_settings_global.settings
    if globalSettings[target] == nil or force then
        -- if changing the value is forced we need to check if the value actually changes and set it dirty, since we don't want to update/synch if the tables are created 
        if force and globalSettings[target].value ~= value then 
            self.globalSettingsDirty = true
            -- also backsolve the target and set the value there 
            self:backsolveTargetSet(target, value)
        end

        if isPlayerSpecific == nil then -- we only want to set isPlayerSpecific initially so it is nil on all calls outside of load, so use the existing value 
           isPlayerSpecific = globalSettings[target].isPlayerSpecific
        end

        globalSettings[target] = {value = value, isPlayerSpecific = isPlayerSpecific, target = target, valueType = type(value)}
    end
end

-- backsolve to the actual value using the target path and set the actual value 
-- this is how the global settings "go back" to the actual variables 
function realismAddon_gearbox_settings:backsolveTargetSet(target, value)

    print("backsolve value: "..tostring(value))
    -- we always start from self so we can use all specs 
    local targetValuePath = self
    local strings = string.split(target, ".") -- split the string at .
    for i = 1, #strings do 
        if strings[i] == strings[#strings] then -- if the key matches the endKey (default "value") then set the value 
            targetValuePath[strings[i]] = value
        else -- else keep going
            targetValuePath = targetValuePath[strings[i]]
        end
    end
    print("backsolveTargetSet "..tostring(target).." value: "..tostring(value))
end

-- get global settings from table 
-- this is used to get a specific setting from the table, it can also transmit a defaultValue through the funciton
function realismAddon_gearbox_settings:globalSettingsGet(target, singleReturn, defaultValue, defaultIsPlayerSpecific)
    print("globalSettingsGet")

    local globalSettings = realismAddon_gearbox_settings_global.settings
    if globalSettings[target] ~= nil then
        local value = false -- globalSettings[target].value
        print("VALUET"..tostring(globalSettings[target].value))
        local isPlayerSpecific = globalSettings[target].isPlayerSpecific
        print("VALUE GET: "..tostring(value))
        if singleReturn then
            return value
        end
        return value, isPlayerSpecific
    end
    
    if singleReturn then
        return defaultValue
    end
    return defaultValue, defaultIsPlayerSpecific
end

-- save global settings from table 
-- this function saves the global settings table into the XML File.
-- this function is called when the game is saved and when the settings are changed (menu ok button is pressed)
function realismAddon_gearbox_settings:saveGlobalSettings()
    print("saveGlobalSettings")
    local filename = realismAddon_gearbox_settings_global.modSettingsDir.."settings.xml"
	local key = "settings"
    local settings = realismAddon_gearbox_settings_global.settings

    -- load xml File
	local xmlFile = XMLFile.loadIfExists("settingsXML", filename, key)    
    
    if xmlFile ~= nil then
        
        local i = 0
        for k, v in pairs(settings) do

            print("SAVE VALUE: "..tostring(settings[k].value))
            xmlFile:setString(key..".setting("..i..")#value", tostring(settings[k].value))
            xmlFile:setString(key..".setting("..i..")#target", k)
            xmlFile:setString(key..".setting("..i..")#valueType", settings[k].valueType)
            xmlFile:setBool(key..".setting("..i..")#isPlayerSpecific", settings[k].isPlayerSpecific)

            i = i+1
        end
        
        xmlFile:save()
        xmlFile:delete()
    end
end

-- hook into basegame save settings function to save our settings when game is saved too
function realismAddon_gearbox_settings.gameSettings_saveToXMLFile(self, xmlFile)
    realismAddon_gearbox_settings:saveGlobalSettings()
end
GameSettings.saveToXMLFile = Utils.appendedFunction(realismAddon_gearbox_settings.saveToXMLFile, realismAddon_gearbox_settings.gameSettings_saveToXMLFile)


function realismAddon_gearbox_settings:onUpdate(dt)


end




