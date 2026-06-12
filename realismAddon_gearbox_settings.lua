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
realismAddon_gearbox_settings_global.targetToIndex = {}
realismAddon_gearbox_settings_global.indexToTarget = {}


addModEventListener(realismAddon_gearbox_settings_global)

function realismAddon_gearbox_settings_global.loadMap(name)

    if g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.savegameDirectory ~= nil then
        local filename = g_currentMission.missionInfo.savegameDirectory.."/realismAddon_gearbox_settings.xml"
        local key = "settings"

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

                local count = 0
                for _ in pairs(realismAddon_gearbox_settings_global.settings) do
                    count = count +1 
                end                
                realismAddon_gearbox_settings_global.targetToIndex[target] = count     
                realismAddon_gearbox_settings_global.indexToTarget[count] = target 

                i = i+1
            end
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
    realismAddon_gearbox_settings.globalSettingsSaved = false

end

-- set defaults or get value, this is used in load() to set the values initially
-- first we call globalSettingsSet but without force, it only creates a new table entry if it doesn't already exist 
-- then we call globalSettingsGet to get the values, they either already exist or we just created them
function realismAddon_gearbox_settings:globalSettingsGetSet(target, defaultValue, defaultIsPlayerSpecific)
    self:globalSettingsSet(target, defaultValue, defaultIsPlayerSpecific)
    local value, isPlayerSpecific = self:globalSettingsGet(target, nil, defaultValue, defaultIsPlayerSpecific)
    return value, isPlayerSpecific
end

-- set global settings in table
-- this is used to set a specific setting using target, optionally force update 
-- it also creates the setting variable if it doesn't exist yet 
-- we also need to track if a setting has been changed when this function is called and set it dirty 
function realismAddon_gearbox_settings:globalSettingsSet(target, value, isPlayerSpecific, force, targetIndex, noEventSend)
    print("globalSettingsSet")

    local globalSettings = realismAddon_gearbox_settings_global.settings
    -- there is basically 3 ways this function is called. Either in setup of a function, then force is nil but the table will also be nil
    -- or we call from a user input function like the GUI then force is true so the value will be forced to update 

    print(target)
    print(value)
    print(isPlayerSpecific)
    print(force)
    print(targetIndex)
    print(noEventSend)
    print("-- --")

    -- or we call it from an event, in this case we need to convert the targetIndex to the target first
    if targetIndex ~= nil then
        print("targetIndex call")
        target = realismAddon_gearbox_settings_global.indexToTarget[targetIndex]
        print(target)
    end

    -- if the setting is nil, create it 
    if globalSettings[target] == nil then
        globalSettings[target] = {value = value, isPlayerSpecific = isPlayerSpecific, target = target, valueType = type(value)}       
        local count = 0
        for _ in pairs(globalSettings) do
            count = count +1 
        end
        realismAddon_gearbox_settings_global.targetToIndex[target] = count    
        realismAddon_gearbox_settings_global.indexToTarget[count] = target 
    end    

    -- if force we called it to update, check if value changed
    if force and globalSettings[target].value ~= value then 
        --if not globalSettings[target].isPlayerSpecific then -- only synch non playerSpecific settings 
            realismAddon_gearbox_onGlobalSettingsChangedEvent.sendEvent(self, value, type(value), realismAddon_gearbox_settings_global.targetToIndex[target], noEventSend)
        --end      
        -- also backsolve the target and set the value there 
        self:backsolveTargetSet(target, value)
        -- and finally update the table aswell 
        globalSettings[target].value = value
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


-- 
function realismAddon_gearbox_settings:saveToXMLFile(xmlFile, key, usedModNames)
    if not realismAddon_gearbox_settings.globalSettingsSaved then
	    realismAddon_gearbox_settings:saveGlobalSettings()
    end
    print("SAVE TO XML FILE, this is called once per vehicle but only the first should save")
end


-- save global settings from table 
-- this function saves the global settings table into the XML File.
-- this function is called when the game is saved and when the settings are changed (menu ok button is pressed)
-- NOTE: I think I want to move the settings XML to the savegame and save it there - done, better this way
function realismAddon_gearbox_settings:saveGlobalSettings(playerChange)

    realismAddon_gearbox_settings.globalSettingsSaved = true    

    local directory = g_currentMission.missionInfo.savegameDirectory
    print(directory)

    print("saveGlobalSettings, this should only happen once")
    --local filename = realismAddon_gearbox_settings_global.modSettingsDir.."settings.xml"
    local filename = directory .. "/realismAddon_gearbox_settings.xml"

	local key = "settings"
    local settings = realismAddon_gearbox_settings_global.settings

    -- in regards to multiplayer 
    -- each time we save the global settings we need to synch it to all other players 
    -- BUT playerSpecific settings are NOT synchronized and only saved locally

    -- load xml File
	local xmlFile = XMLFile.loadIfExists("settingsXML", filename, key)    
    
    if xmlFile == nil then
        xmlFile = XMLFile.create("settingsXML", filename, key)  
    end

    if xmlFile ~= nil then
  
        local i = 0
        for k, v in pairs(settings) do
       
            print("SAVE VALUE: "..tostring(settings[k].value))
            xmlFile:setString(key..".setting("..i..")#value", tostring(settings[k].value))
            xmlFile:setString(key..".setting("..i..")#valueType", settings[k].valueType)    
            xmlFile:setBool(key..".setting("..i..")#isPlayerSpecific", settings[k].isPlayerSpecific)             
            xmlFile:setString(key..".setting("..i..")#target", k)

            i = i+1
        end
        
        xmlFile:save()
        xmlFile:delete()

    end
end


function realismAddon_gearbox_settings:onUpdate(dt)


end



realismAddon_gearbox_onGlobalSettingsChangedEvent = {}
local realismAddon_gearbox_onGlobalSettingsChangedEvent_mt = Class(realismAddon_gearbox_onGlobalSettingsChangedEvent, Event)

InitEventClass(realismAddon_gearbox_onGlobalSettingsChangedEvent, "realismAddon_gearbox_onGlobalSettingsChangedEvent")

function realismAddon_gearbox_onGlobalSettingsChangedEvent.emptyNew()
	return Event.new(realismAddon_gearbox_onGlobalSettingsChangedEvent_mt)
end

function realismAddon_gearbox_onGlobalSettingsChangedEvent.new(object, value, valueType, targetIndex)
	local self = realismAddon_gearbox_onGlobalSettingsChangedEvent.emptyNew()
	self.object = object
	self.value = value 
    self.valueType = valueType
    self.targetIndex = targetIndex

    print("value: "..tostring(value).." valueType: "..tostring(valueType).." targetIndex: "..tostring(targetIndex))

	return self
end

function realismAddon_gearbox_onGlobalSettingsChangedEvent:readStream(streamId, connection)
    print("ON READ STREAM")
	self.object = NetworkUtil.readNodeObject(streamId)
    if self.valueType == "number" then
        self.value = streamReadIntN(streamId, 11) * 0.01
    elseif self.valueType == "boolean" then
	    self.value = streamReadBool(streamId) 
    elseif self.valueType == "string" then
        self.value = streamReadString(streamId)
    end
    self.targetIndex = streamReadUInt8(streamId)
	self:run(connection)
end

function realismAddon_gearbox_onGlobalSettingsChangedEvent:writeStream(streamId, connection)
    print("ON WRITE STREAM")
	NetworkUtil.writeNodeObject(streamId, self.object)
    if self.valueType == "number" then
        streamWriteIntN(streamId, math.floor(self.value * 100), 11)
    elseif self.valueType == "boolean" then
	    streamWriteBool(streamId, self.value)
    elseif self.valueType == "string" then
        streamWriteString(streamId, self.value)
    end
    streamWriteUInt8(streamId, self.targetIndex)
end

function realismAddon_gearbox_onGlobalSettingsChangedEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
        self.object:globalSettingsSet(nil, self.value, nil, true, self.targetIndex, true)
	end
end

function realismAddon_gearbox_onGlobalSettingsChangedEvent.sendEvent(object, value, valueType, targetIndex, noEventSend)
    print("send EVENT")
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(realismAddon_gearbox_onGlobalSettingsChangedEvent.new(object, value, valueType, targetIndex), nil, nil, object)			
		else
			g_client:getServerConnection():sendEvent(realismAddon_gearbox_onGlobalSettingsChangedEvent.new(object, value, valueType, targetIndex))
		end
	end
end



