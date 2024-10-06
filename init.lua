local config = require("modules/config/config")
local Cron = require("modules/externals/Cron")

local ReactToHorn = {
    settings = {
    },
    defaultSettings = {
        isEnabled = true,
        pedestrianReactRadius = 10.0,
        vehicleReactRadius = 30.0,
        pedestrianDodgeOnPavement = true,
        pedestrianReactToHonk = true,
        vehiclesReactToHonk = true,
        pedestrianReactIntensity = 1,
        pedestrianReactTypeValue = 50,
        pedestrianReactTypeSelectorValue = 1,
        vehiclesReactTypeSelectorValue = 1,
        pedestrianReactProbability = 70,
        vehiclesReactProbability = 70,
        popTiresOnHonk = false,
        bounceOnHonk = false,
        killNPCsOnHonk = false,
        explodeNPCOnHonk = false,
        explodeVehicleOnHonk = false
    },

    pedestrianReactIntensityNames = { "Normal", "High", "Very High" },
    pedestrianReactTypesNames = { "Random", "Walk Away", "Run" },
    pedestrianReactTypes = {
        ["Random"] = 1,
        ["Walk Away"] = 50,
        ["Run"] = 54,
    },
    vehicleReactTypesNames = { "Random", "Panic", "Honk Back" },

    delay = false,
    delayTime = 1,
    minPedestrianReactRadius = 1.0,
    maxPedestrianReactRadius = 30.0,
    minVehicleReactRadius = 1.0,
    maxVehicleReactRadius = 50.0,
    radiusStep = 1.0,
    minProbability = 0,
    maxProbability = 100,
    probabilityStep = 1,

    isAlreadyTriggeringReaction = false,

    distanceChecks = {
        { maxSpeed = 20.0,      normal = 10.0, high = 15.0, veryHigh = 30.0 },
        { maxSpeed = 35.0,      normal = 20.0, high = 23.0, veryHigh = 30.0 },
        { maxSpeed = math.huge, normal = 30.0, high = 30.0, veryHigh = 30.0 }
    }
}
local explosion = nil

function ReactToHorn:new()
    registerForEvent("onInit", function()
        self:InitializeSettings()
        self:ObserveHornEvent()
        self:ObserveReactionEvent()

        math.randomseed(os.time() + os.clock())
        Cron.Every(60, function() self:ReseedRandomGenerator() end, self)

        print("[ReactToHorn] React To Horn - v1.1.0 initialized")
    end)

    registerForEvent("onUpdate", function(deltaTime)
        Cron.Update(deltaTime)
    end)

    return self
end

function ReactToHorn:InitializeSettings()
    config.tryCreateConfig("config.json", self.defaultSettings)
    self.settings = config.loadFile("config.json")

    local nativeSettings = GetMod("nativeSettings")
    if not nativeSettings then
        print("[React To Horn] Error: Missing Native Settings")
        return
    end

    self:SetupMenu(nativeSettings)
end

function ReactToHorn:ObserveHornEvent()
    Observe("VehicleComponent", "ToggleVehicleHorn", function(this, state, isPolice)
        if not state or not self.settings.isEnabled then return end

        local player = Game.GetPlayer()
        local vehicle = Game.GetMountedVehicle(player)

        if (self.settings.vehiclesReactToHonk or self.settings.popTiresOnHonk or
                self.settings.bounceOnHonk or self.settings.killNPCsOnHonk or
                self.settings.explodeNPCOnHonk or self.settings.explodeVehicleOnHonk) and vehicle then
            self:HandleHonkingReaction(player)
        end
    end)
end

function ReactToHorn:ObserveReactionEvent()
    Observe("ReactionManagerComponent", "HandleCrowdReaction", function(this, stimEvent)
        if stimEvent.stimType ~= gamedataStimType.VehicleHorn or not self.settings.isEnabled then return end

        local player = Game.GetPlayer()
        local vehicle = Game.GetMountedVehicle(player)

        if self.settings.pedestrianDodgeOnPavement and vehicle and vehicle:IsOnPavement() then
            self:HandlePavementDodgeReaction(this, player, vehicle)
        end

        if self.isAlreadyTriggeringReaction then
            return
        else
            self.isAlreadyTriggeringReaction = true

            if self.settings.pedestrianReactToHonk and vehicle and not vehicle:IsOnPavement() then
                self:BroadcastPedestrianReaction(player)
            end

            ---@diagnostic disable-next-line: missing-parameter
            Cron.After(1, function()
                self.isAlreadyTriggeringReaction = false
            end)
        end
    end)
end

function ReactToHorn:HandlePavementDodgeReaction(this, player, vehicle)
    local actualSpeed = self:GetActualVehicleSpeedMPH(player, vehicle)
    if actualSpeed > 0 then
        local distanceCheck = self:GetDistanceCheck(actualSpeed)
        if this:IsTargetClose(player, distanceCheck) then
            local stimEvent = senseStimuliEvent.new()
            stimEvent.stimType = gamedataStimType.VehicleHorn
            stimEvent.sourceObject = player
            stimEvent.sourcePosition = player:GetWorldPosition()
            stimEvent.radius = 2 --self.settings.pedestrianReactRadius --Seems to work only for certain types of stimuli

            --this:TriggerReactionBehaviorForCrows(stimEvent, gamedataOutput.DodgeToSide, true, true)
            this:TriggerReactionBehaviorForCrowd(stimEvent.sourceObject, gamedataOutput.DodgeToSide, false,
                stimEvent.sourcePosition)
        end
    end
end

function ReactToHorn:BroadcastPedestrianReaction(player)
    local investigateData = senseStimInvestigateData.new()
    investigateData.skipReactionDelay = true
    investigateData.skipInitialAnimation = true
    investigateData.illegalAction = false
    local stimRadius = self.settings.pedestrianReactRadius

    local vehiclesReactionProbability = self.settings.vehiclesReactProbability / 100
    if math.random() <= vehiclesReactionProbability then
        if self.settings.pedestrianReactTypeValue == 1 then
            if math.random() < 0.5 then
                StimBroadcasterComponent.BroadcastStim(player, gamedataStimType.Terror, stimRadius,
                    investigateData,
                    true)
            else
                StimBroadcasterComponent.BroadcastStim(player, gamedataStimType.SilentAlarm, stimRadius,
                    investigateData,
                    true)
            end
        else
            StimBroadcasterComponent.BroadcastStim(player, self.settings.pedestrianReactTypeValue, stimRadius,
                investigateData,
                true)
        end
    end
end

function ReactToHorn:BoradcastTerror(player)
    local investigateData = senseStimInvestigateData.new()
    investigateData.skipReactionDelay = true
    investigateData.skipInitialAnimation = true
    investigateData.illegalAction = false
    local stimRadius = self.settings.pedestrianReactRadius

    StimBroadcasterComponent.BroadcastStim(player, gamedataStimType.Terror, stimRadius,
        investigateData,
        true)
end

function ReactToHorn:HandleHonkingReaction(player)
    local entities = self:GetEntitiesAroundPlayer(player)
    for _, entity in ipairs(entities) do
        local entityToProcess = entity:GetComponent():GetEntity()
        self:ProcessEntityByType(entityToProcess, player)
    end
end

function ReactToHorn:GetEntitiesAroundPlayer(player)
    local targetingSystem = Game.GetTargetingSystem()
    local parts = {}
    local searchQuery = Game["TSQ_ALL;"]()
    searchQuery.maxDistance = math.floor(self.settings.vehicleReactRadius)
    searchQuery.testedSet = TargetingSet.Visible
    local success, parts = targetingSystem:GetTargetParts(player, searchQuery)
    return parts
end

function ReactToHorn:ProcessEntityByType(entity, player)
    if self:IsEntityVehicle(entity) and entity:IsVehicle() then
        self:HandleVehicleEntity(entity, player)
    end
    if self:IsEntityNPC(entity) then
        self:HandleNPCEntity(entity, player)
    end
end

function ReactToHorn:HandleVehicleEntity(entity, player)
    if entity:IsPlayerVehicle() or entity:IsPlayerDriver() then return end

    if self.settings.vehiclesReactToHonk then
        self:VehicleReaction(entity, player)
    end
    if self.settings.popTiresOnHonk then
        if not self.settings.explodeVehicleOnHonk then
            self:PopRandomTire(entity, player)
        end
    end
    if self.settings.bounceOnHonk then
        if not self.settings.explodeVehicleOnHonk then
            self:Bounce(entity)
        end
    end
    if self.settings.explodeVehicleOnHonk then
        self:ExplodeVehiclesInVicinity(entity, player)
    end
end

function ReactToHorn:HandleNPCEntity(entity, player)
    if entity:IsDead() or entity:IsCharacterChildren() or entity:IsQuest() then return end

    if self.settings.killNPCsOnHonk then
        if not self.settings.explodeNPCOnHonk then
            self:BoradcastTerror(player)
            self:KillNPCsInVicinity(entity, player)
        end
    end
    if self.settings.explodeNPCOnHonk then
        self:BoradcastTerror(player)
        self:ExplodeNPCsInVicinity(entity, player)
    end
end

function ReactToHorn:KillNPCsInVicinity(npc, player)
    local randomDelay = 0.2 + math.random() * (2.5 - 0.2)

    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(randomDelay, function()
        npc:Kill(player, false, false)
    end)
end

function ReactToHorn:ExplodeNPCsInVicinity(npc, player)
    local randomDelay = 0.2 + math.random() * (2.5 - 0.2)

    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(randomDelay, function()
        local duration = 1.0
        local explosion = "Attacks.RocketEffect"
        self:SpawnExplosion(npc, player, explosion, duration)
        npc:Kill(nil, true, false)
    end)
end

function ReactToHorn:VehicleReaction(vehicle, player)
    local vehiclesReaction = self.settings.vehiclesReactTypeSelectorValue
    local vehiclesReactionProbability = self.settings.vehiclesReactProbability / 100

    if math.random() <= vehiclesReactionProbability then
        if vehiclesReaction == 1 then
            if math.random() < 0.5 then
                vehicle:ToggleHorn(true)
            else
                --if vehicle:CanStartPanicDriving() then
                vehicle:TriggerDrivingPanicBehavior(player:GetWorldPosition())
                --end
            end
        elseif vehiclesReaction == 2 then
            --if vehicle:CanStartPanicDriving() then
            vehicle:TriggerDrivingPanicBehavior(player:GetWorldPosition())
            --end
        elseif vehiclesReaction == 3 then
            vehicle:ToggleHorn(true)
        end
    end
end

function ReactToHorn:PopRandomTire(vehicle, player)
    local randomTire = math.random(1, 4)
    local randomDelay = 0.5 + math.random() * (2 - 0.5)

    vehicle:TriggerDrivingPanicBehavior(player:GetWorldPosition())

    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(randomDelay, function()
        vehicle:ToggleBrokenTire(randomTire, true)
    end)
end

function ReactToHorn:Bounce(vehicle)
    vehicle:SetHasExploded()
end

function ReactToHorn:ExplodeVehiclesInVicinity(vehicle, player)
    local randomDelay = 0.2 + math.random() * (2.5 - 0.2)

    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(randomDelay, function()
        local duration = 1.0
        local explosion = "Attacks.Explosion"
        self:SpawnExplosion(vehicle, player, explosion, duration)
        self:SpawnExplosion(vehicle, player, explosion, duration)
        self:SpawnExplosion(vehicle, player, explosion, duration)
    end)
end

function ReactToHorn:ExtractClassNameFromEntity(entity)
    local className = tostring(entity:GetClassName())
    return string.match(className, "%-%-%[%[%s*(.-)%s*%-%-%]%]")
end

function ReactToHorn:IsEntityVehicle(entity)
    local entityClassName = self:ExtractClassNameFromEntity(entity)

    return entityClassName == "vehicleCarBaseObject"
end

function ReactToHorn:IsEntityNPC(entity)
    local entityClassName = self:ExtractClassNameFromEntity(entity)

    return entityClassName == "NPCPuppet"
end

function ReactToHorn:GetDistanceCheck(actualSpeed)
    local intensityFactor = self.settings.pedestrianReactIntensity

    for _, check in ipairs(self.distanceChecks) do
        if actualSpeed <= check.maxSpeed then
            if intensityFactor == 1 then
                return check.normal
            elseif intensityFactor == 2 then
                return check.high
            elseif intensityFactor == 3 then
                return check.veryHigh
            end
        end
    end
end

function ReactToHorn:SpawnExplosion(entity, player, explosion, duration)
    local pos = entity:GetWorldPosition()
    local att = GetSingleton("gameAttack_GameEffect")
    if att and pos and explosion then
        att:SpawnExplosionAttack(TweakDB:GetRecord(explosion), nil, player, Game.GetPlayer(), pos, duration) --TDB attack record, weapon object, instigator object, source object (you may want to change this. This might be the explosion source and may kill you), vector4 pos, duration
    end
end

local function round(n)
    return math.floor(n + 0.5)
end

function ReactToHorn:GetActualVehicleSpeedMPH(player, vehicle)
    local speedValue = math.abs(vehicle:GetCurrentSpeed())
    local multiplier = GameInstance.GetStatsDataSystem():GetValueFromCurve("vehicle_ui", speedValue,
        "speed_to_multiplier")
    local floatspeed = speedValue * multiplier
    local speed = round(speedValue * multiplier)

    return speed
end

function ReactToHorn:ReseedRandomGenerator()
    math.randomseed(os.time() + os.clock())
end

local function SaveSettings()
    config.saveFile("config.json", ReactToHorn.settings)
end

function ReactToHorn:SetupMenu(nativeSettings)
    if not nativeSettings.pathExists("/react_to_horn") then
        nativeSettings.addTab("/react_to_horn", "React To Horn")
        nativeSettings.addSubcategory("/react_to_horn/general", "React To Horn")
        nativeSettings.addSubcategory("/react_to_horn/pedestrian_dodge_settings",
            "Pedestrians Dodge on Honk Settings - When on pavement")
        nativeSettings.addSubcategory("/react_to_horn/pedestrian_react_settings",
            "Pedestrians React to Honk Settings")
        nativeSettings.addSubcategory("/react_to_horn/vehicle_react_settings",
            "Vehicles React to Honk Settings")
        nativeSettings.addSubcategory("/react_to_horn/fun",
            "Fun")

        nativeSettings.addSwitch("/react_to_horn/general", "React To Horn",
            "Enable or Disable the React To Horn mod", self.settings.isEnabled, self.defaultSettings.isEnabled,
            function(state)
                self.settings.isEnabled = state
                SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/pedestrian_dodge_settings", "Pedestrians Dodge On Honk",
            "When you're on the pavement and honk your horn, pedestrians will dodge. The distance at which pedestrians react increases with your speed and with the intensity setting below - the faster you drive, the greater the effect",
            self.settings.pedestrianDodgeOnPavement,
            self.defaultSettings.pedestrianDodgeOnPavement,
            function(state)
                self.settings.pedestrianDodgeOnPavement = state
                SaveSettings()
            end)

        nativeSettings.addSelectorString("/react_to_horn/pedestrian_dodge_settings", "Dodge Reaction Intensity",
            "Adjust the intensity of pedestrian reactions to your horn. Higher settings make them dodge from farther away, even when you drive slow",
            self.pedestrianReactIntensityNames, self.settings.pedestrianReactIntensity,
            self.defaultSettings.pedestrianReactIntensity,
            function(value)
                self.settings.pedestrianReactIntensity = value
                SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/pedestrian_react_settings", "Pedestrians React To Horn",
            "When you're NOT on the pavement and honk your horn, pedestrians will react. You can choose the reaction type using the setting below",
            self.settings.pedestrianReactToHonk,
            self.defaultSettings.pedestrianReactToHonk,
            function(state)
                self.settings.pedestrianReactToHonk = state
                SaveSettings()
            end)

        nativeSettings.addSelectorString("/react_to_horn/pedestrian_react_settings", "Reaction Type",
            "What type of the reaction should the NPCs have when you honk the horn",
            self.pedestrianReactTypesNames, self.settings.pedestrianReactTypeSelectorValue,
            self.defaultSettings.pedestrianReactTypeSelectorValue,
            function(value)
                local selectedReaction = self.pedestrianReactTypesNames[value]
                self.settings.pedestrianReactTypeValue = self.pedestrianReactTypes[selectedReaction]
                self.settings.pedestrianReactTypeSelectorValue = value
                SaveSettings()
            end)

        nativeSettings.addRangeFloat("/react_to_horn/pedestrian_react_settings", "Reaction Radius",
            "Adjust the radius within which NPCs react to your vehicle's horn", self.minPedestrianReactRadius,
            self.maxPedestrianReactRadius,
            self.radiusStep, "%.2f", self.settings.pedestrianReactRadius, self.defaultSettings.pedestrianReactRadius,
            function(value)
                self.settings.pedestrianReactRadius = value
                SaveSettings()
            end)

        nativeSettings.addRangeInt("/react_to_horn/pedestrian_react_settings", "Reaction Probability (%)",
            "The probability for the NPC reaction to happen",
            self.minProbability, self.maxProbability, self.probabilityStep,
            self.settings.pedestrianReactProbability,
            self.defaultSettings.pedestrianReactProbability, function(value)
                self.settings.pedestrianReactProbability = value
                SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/vehicle_react_settings", "Vehicles React To Horn",
            "Enable or Disable vehicles reacting to honk", self.settings.vehiclesReactToHonk,
            self.defaultSettings.vehiclesReactToHonk,
            function(state)
                self.settings.vehiclesReactToHonk = state
                SaveSettings()
            end)

        nativeSettings.addSelectorString("/react_to_horn/vehicle_react_settings", "Reaction Type",
            "What type of the reaction should the Vehicle NPCs have when you honk the horn",
            self.vehicleReactTypesNames, self.settings.vehiclesReactTypeSelectorValue,
            self.defaultSettings.vehiclesReactTypeSelectorValue,
            function(value)
                self.settings.vehiclesReactTypeSelectorValue = value
                SaveSettings()
            end)

        nativeSettings.addRangeFloat("/react_to_horn/vehicle_react_settings", "Reaction Radius",
            "Adjust the radius within which vehicle NPCs react to your vehicle's horn", self.minVehicleReactRadius,
            self.maxVehicleReactRadius,
            self.radiusStep, "%.2f", self.settings.vehicleReactRadius, self.defaultSettings.vehicleReactRadius,
            function(value)
                self.settings.vehicleReactRadius = value
                SaveSettings()
            end)

        nativeSettings.addRangeInt("/react_to_horn/vehicle_react_settings", "Reaction Probability (%)",
            "The probability for the vehicle reaction to happen",
            self.minProbability, self.maxProbability, self.probabilityStep,
            self.settings.vehiclesReactProbability,
            self.defaultSettings.vehiclesReactProbability, function(value)
                self.settings.vehiclesReactProbability = value
                SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/fun", "Pop Tires on Honk (might crash game)",
            "As the name says. This might crash your game if you spam it!!!",
            self.settings.popTiresOnHonk,
            self.defaultSettings.popTiresOnHonk,
            function(state)
                self.settings.popTiresOnHonk = state
                SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/fun", "Vehicles Bounce on Honk",
            "As the name says",
            self.settings.bounceOnHonk,
            self.defaultSettings.bounceOnHonk,
            function(state)
                self.settings.bounceOnHonk = state
                SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/fun", "NPCs Die on Honk",
            "As the name says",
            self.settings.killNPCsOnHonk,
            self.defaultSettings.killNPCsOnHonk,
            function(state)
                self.settings.killNPCsOnHonk = state
                SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/fun", "NPCs Explode on Honk",
            "As the name says",
            self.settings.explodeNPCOnHonk,
            self.defaultSettings.explodeNPCOnHonk,
            function(state)
                self.settings.explodeNPCOnHonk = state
                SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/fun", "Vehicles Explode on Honk",
            "As the name says",
            self.settings.explodeVehicleOnHonk,
            self.defaultSettings.explodeVehicleOnHonk,
            function(state)
                self.settings.explodeVehicleOnHonk = state
                SaveSettings()
            end)
    end
end

-- Keybinds
registerInput("getEntities", "Test Get Entities", function(keypress)
    if not keypress then
        return
    end

    local player = Game.GetPlayer()
    ReactToHorn:HandleHonkingReaction(player)
end)

registerInput("SpawnExplosion", "Spawn Explosion At Player Target Position", function(keypress)
    if not keypress then
        return
    end


    local player = Game.GetPlayer()
    local vehicle = Game.GetMountedVehicle(player)

    ReactToHorn:HandleHonkingReaction(player)

    --[[ local pos = Game.GetTargetingSystem():GetLookAtPosition(Game.GetPlayer(), true, false)
    local att = GetSingleton("gameAttack_GameEffect")
    if att and pos and explosion then
        att:SpawnExplosionAttack(TweakDB:GetRecord(explosion), nil, Game.GetPlayer(), Game.GetPlayer(), pos, 3.0) --TDB attack record, weapon object, instigator object, source object (you may want to change this. This might be the explosion source and may kill you), vector4 pos, duration
    end ]]
end)

return ReactToHorn:new()
