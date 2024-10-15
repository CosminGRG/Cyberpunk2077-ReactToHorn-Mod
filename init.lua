local config = require("modules/config/config")
local Cron = require("modules/externals/Cron")
local ui = require("modules/ui/ui")

local ReactToHorn = {
    settings = {
    },
    defaultSettings = {
        isEnabled = true,
        isFunEnabled = false,
        pedestrianReactRadius = 10.0,
        vehicleReactRadius = 20.0,
        pedestrianDodgeOnPavement = true,
        pedestrianReactToHonk = true,
        vehiclesReactToHonk = true,
        policeVehiclesReactToHonk = false,
        pedestrianReactIntensity = 1,
        pedestrianReactTypeValue = 50,
        pedestrianReactTypeSelectorValue = 1,
        vehiclesReactTypeSelectorValue = 1,
        pedestrianReactProbability = 70,
        vehiclesReactProbability = 70,
        funRadius = 20.0,
        popTiresOnHonk = false,
        bounceOnHonk = false,
        killNPCsOnHonk = false,
        explodeNPCOnHonk = false,
        explodeVehicleOnHonk = false,
        pedestrianReactMode = 1,
        vehicleReactMode = 1,
        currentPedestrianPreset = "simple",
        currentvehiclePreset = "simple",
        vehicleTimoutSelectorValue = 2,
        pedestrianTimeoutSelectorValue = 1,
        complex = {
            pedestrian = {
                pedestrianReactTimeoutMin = 3,
                pedestrianReactTimeoutMix = 10,
                walkAwayProbability = 20,
                runProbability = 20,
                verbalProbability = 20,
            },
            vehicle = {
                vehicleReactTimeoutMin = 3,
                vehicleReactTimeoutMax = 10,
                panicProbability = 20,
                honkBackProbability = 30,
                verbalProbability = 40,
            }
        }
    },

    pedestrianReactModeNames = { "Simple", "Complex" },
    pedestrianReactIntensityNames = { "Normal", "High", "Very High" },
    pedestrianReactTypesNames = { "Random", "Walk Away", "Run", "Verbal" },
    pedestrianReactTypes = {
        ["Random"] = 1,
        ["Walk Away"] = 50,
        ["Run"] = 54,
    },
    vehicleReactTypesNames = { "Random", "Panic", "Honk Back", "Verbal" },
    vehicleReactTimeoutNames = { "No Timeout", "3-10 seconds", "5-13 seconds", "7-16 seconds", "9-19 seconds" },

    delay = false,
    delayTime = 1,
    minPedestrianReactRadius = 1.0,
    maxPedestrianReactRadius = 30.0,
    minVehicleReactRadius = 1.0,
    maxVehicleReactRadius = 40.0,
    minFunRadius = 1.0,
    maxFunRadius = 50.0,
    radiusStep = 1.0,
    minProbability = 0,
    maxProbability = 100,
    probabilityStep = 1,

    complexDefines = {
        pedestrian = {
            maxWalkAwayProb = 100,
            maxRunProb = 100,
            maxVerbalProb = 100
        },
        vehicle = {
            minVehicleTimeoutMin = 0,
            maxVehicleTimeoutMin = 100,
            minVehicleTimeoutMax = 0,
            maxVehicleTimeoutMax = 100,
            maxPanicProb = 100,
            maxHonkBackProb = 100,
            maxVerbalProb = 100
        }
    },

    reactedVehicles = {},
    reactedPedestrians = {},
    isAlreadyTriggeringReaction = false,

    distanceChecks = {
        { maxSpeed = 20.0,      normal = 10.0, high = 15.0, veryHigh = 30.0 },
        { maxSpeed = 35.0,      normal = 20.0, high = 23.0, veryHigh = 30.0 },
        { maxSpeed = math.huge, normal = 30.0, high = 30.0, veryHigh = 30.0 }
    },
    timeoutRanges = {
        ["No Timeout"] = { 0, 0 },
        ["3-10 seconds"] = { 3, 10 },
        ["5-13 seconds"] = { 5, 13 },
        ["7-16 seconds"] = { 7, 16 },
        ["9-19 seconds"] = { 9, 19 },
    }
}

function ReactToHorn:new()
    registerForEvent("onInit", function()
        self:InitializeSettings()
        self:ObserveHornEvent()
        self:ObserveReactionEvent()

        local nativeSettings = GetMod("nativeSettings")
        if not nativeSettings then
            print("[React To Horn] Error: Missing Native Settings UI. Search and intall this mod from Nexus")
            return
        end

        if ui and ui.onInit then
            ui.onInit(ReactToHorn)
        else
            print("[ReactToHorn] Error: Missing UI or its onInit method. Make sure the mod is installed correctly")
            return
        end

        ui:SetupMenu(nativeSettings)

        math.randomseed(os.time() + os.clock())
        Cron.Every(60, function() self:ReseedRandomGenerator() end, self)

        print("[ReactToHorn] React To Horn - v1.1.1 initialized")
    end)

    registerForEvent("onUpdate", function(deltaTime)
        Cron.Update(deltaTime)
    end)

    return self
end

function ReactToHorn:InitializeSettings()
    config.tryCreateConfig("config.json", self.defaultSettings)
    self.settings = config.loadFile("config.json")
end

function ReactToHorn:ObserveHornEvent()
    Observe("VehicleComponent", "ToggleVehicleHorn", function(this, state, isPolice)
        if not state or not self.settings.isEnabled then return end

        local honkingVehicle = this:GetVehicle()
        local isPlayerDriver = honkingVehicle:IsPlayerDriver()
        if not isPlayerDriver then return end

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
            Cron.After(0.5, function()
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

function ReactToHorn:BroadcastTerror(player, radius)
    local investigateData = senseStimInvestigateData.new()
    investigateData.skipReactionDelay = true
    investigateData.skipInitialAnimation = true
    investigateData.illegalAction = false
    local stimRadius = radius

    StimBroadcasterComponent.BroadcastStim(player, gamedataStimType.Terror, stimRadius,
        investigateData,
        true)
end

function ReactToHorn:HandleHonkingReaction(player)
    --Extremely lazy way, needs refactoring badly
    if self.settings.isFunEnabled then
        local funEntities = self:GetEntitiesAroundPlayer(player, self.settings.funRadius)

        for _, entity in ipairs(funEntities) do
            local entityToProcess = entity:GetComponent():GetEntity()
            self:ProcessEntityByType(entityToProcess, player, "fun")
        end
    end

    local immersionEntities = self:GetEntitiesAroundPlayer(player, self.settings.vehicleReactRadius)

    for _, entity in ipairs(immersionEntities) do
        local entityToProcess = entity:GetComponent():GetEntity()

        self:ProcessEntityByType(entityToProcess, player, "immersion")
    end
end

function ReactToHorn:GetEntitiesAroundPlayer(player, radius)
    local targetingSystem = Game.GetTargetingSystem()
    local searchQuery = Game["TSQ_ALL;"]()
    searchQuery.ignoreInstigator = true
    searchQuery.maxDistance = math.floor(radius + 10) --fuck
    searchQuery.testedSet = TargetingSet.Visible
    local success, parts = targetingSystem:GetTargetParts(player, searchQuery)
    return parts
end

function ReactToHorn:ProcessEntityByType(entity, player, context)
    if self:IsEntityVehicle(entity) and entity:IsVehicle() then
        self:HandleVehicleEntity(entity, player, context)
    elseif self:IsEntityNPC(entity) then
        print("entity", entity)
        self:HandleNPCEntity(entity, player, context)
    end
end

function ReactToHorn:HandleVehicleEntity(entity, player, context)
    if entity:IsPlayerVehicle() or entity:IsPlayerDriver() or entity:IsQuest() then return end
    local vehicleComp = entity:GetVehicleComponent()

    if context == "immersion" then
        if self.settings.vehiclesReactToHonk then
            if not self.settings.policeVehiclesReactToHonk and (vehicleComp:HasPreventionPassenger() or entity:IsPrevention()) then return end
            if not vehicleComp.HasActiveDriverMounted(entity:GetEntityID()) or entity:IsVehicleParked() then return end

            self:VehicleReaction(entity, player)
        end
    elseif context == "fun" then
        if self.settings.popTiresOnHonk then
            if not self.settings.explodeVehicleOnHonk or not self.settings.bounceOnHonk then
                self:PopRandomTire(entity, player)
            end
        end
        if self.settings.bounceOnHonk then
            if not self.settings.explodeVehicleOnHonk then
                self:Bounce(entity, player)
            end
        end
        if self.settings.explodeVehicleOnHonk then
            self:ExplodeVehiclesInVicinity(entity, player)
        end
    end
end

function ReactToHorn:HandleNPCEntity(entity, player, context)
    if entity:IsDead() or entity:IsQuest() or entity:IsPlayerCompanion() or entity:IsVendor() then return end

    if context == "immersion" then
        self:PedestrianReaction(entity, player)
    elseif context == "fun" then
        if self.settings.killNPCsOnHonk then
            if not self.settings.explodeNPCOnHonk then
                self:BroadcastTerror(player, self.settings.funRadius)
                self:KillNPCsInVicinity(entity, player)
            end
        end
        if self.settings.explodeNPCOnHonk then
            self:BroadcastTerror(player, self.settings.funRadius)
            self:ExplodeNPCsInVicinity(entity, player)
        end
    end
end

function ReactToHorn:PedestrianReaction(npc, player)
    print("npc", npc)
    StimBroadcasterComponent.SendDrirectStimuliToTarget(npc, gamedataStimType.Terror, npc)
end

function ReactToHorn:KillNPCsInVicinity(npc, player)
    local randomDelay = 0.2 + math.random() * (2.5 - 0.2)

    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(randomDelay, function()
        npc:Kill(nil, false, false)
    end)
end

function ReactToHorn:ExplodeNPCsInVicinity(npc, player)
    local randomDelay = 0.2 + math.random() * (2.5 - 0.2)

    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(randomDelay, function()
        local duration = 1.0
        local explosion = "Attacks.OzobGrenade" --Attacks.RocketEffect
        self:SpawnExplosion(npc, player, explosion, duration)
        npc:Kill(nil, false, false)
    end)
end

local function GetCurrentTime()
    return os.clock()
end

local function CleanUpExpiredEntries(currentTime)
    local currentTime = GetCurrentTime()

    for vehicleID, vehData in pairs(ReactToHorn.reactedVehicles) do
        if currentTime >= (vehData.time + vehData.timeout) then
            print("Removing vehicle from reactedVehicles: VehicleID: ", vehicleID)
            ReactToHorn.reactedVehicles[vehicleID] = nil
        end
    end
end

local function IsVehicleInCooldown(vehicleID, currentTime)
    CleanUpExpiredEntries(currentTime)

    if ReactToHorn.reactedVehicles[vehicleID] == nil then
        print("Vehicle is not in cooldown")
        return false
    end

    local vehData = ReactToHorn.reactedVehicles[vehicleID]

    print("currentTime < (vehData.time + vehData.timeout)", currentTime < (vehData.time + vehData.timeout))
    return currentTime < (vehData.time + vehData.timeout)
end

local function GetRandomTimeout()
    if ReactToHorn.settings.vehicleReactMode == 1 then
        local timeoutSelection = ReactToHorn.settings.vehicleTimoutSelectorValue

        local range = ReactToHorn.timeoutRanges[ReactToHorn.vehicleReactTimeoutNames[timeoutSelection]]
        if range then
            return math.random(range[1], range[2])
        else
            return 5
        end
    elseif ReactToHorn.settings.vehicleReactMode == 2 then
        local rangeMin = ReactToHorn.settings.complex.vehicle.vehicleReactTimeoutMin
        local rangeMax = ReactToHorn.settings.complex.vehicle.vehicleReactTimeoutMax
        print("rangeMin", rangeMin)
        print("rangeMax", rangeMax)
        return math.random(rangeMin, rangeMax)
    end
end

function ReactToHorn:VehicleReaction(vehicle, player)
    local vehicleID = vehicle:GetEntityID():GetHash()
    local timeoutPeriod = GetRandomTimeout()
    local currentTime = GetCurrentTime()

    print("timeoutPeriod", timeoutPeriod)

    if IsVehicleInCooldown(vehicleID, currentTime) then
        print("Vehicle is in cooldown")
        return
    end

    self.reactedVehicles[vehicleID] = {
        time = currentTime,
        timeout = timeoutPeriod
    }

    local vehicleComp = vehicle:GetVehicleComponent()
    if self.settings.vehicleReactMode == 1 then
        self:SimpleModeReaction(vehicle, vehicleComp, player)
    elseif self.settings.vehicleReactMode == 2 then
        self:ComplexModeReation(vehicle, vehicleComp, player)
    end
end

function ReactToHorn:ComplexModeReation(vehicle, vehicleComp, player)
    local vehicleHonkBackProbability = self.settings.complex.vehicle.honkBackProbability / 100
    print("vehicleHonkBackProbability", vehicleHonkBackProbability)
    local vehiclePanicProbability = self.settings.complex.vehicle.panicProbability / 100
    print("vehiclePanicProbability", vehiclePanicProbability)
    local vehicleVerbalProbability = self.settings.complex.vehicle.verbalProbability / 100
    print("vehicleVerbalProbability", vehicleVerbalProbability)

    local randomValue = math.random()
    if randomValue <= vehicleHonkBackProbability then
        print("ToggleHorn")
        local randomDelay = math.random() * (2.0 - 0.5) + 0.5
        vehicleComp:PlayDelayedHonk(1.0, randomDelay)
        --vehicle:ToggleHorn(true)
    elseif randomValue <= vehicleHonkBackProbability + vehiclePanicProbability then
        print("TriggerDrivingPanicBehavior")
        vehicle:TriggerDrivingPanicBehavior(player:GetWorldPosition())
    elseif randomValue <= vehicleHonkBackProbability + vehiclePanicProbability + vehicleVerbalProbability then
        print("PlayVoiceOver")
        local randomChoice = math.random(1, 3)
        local verbal = ""
        if randomChoice == 1 then
            verbal = "stlh_curious_grunt"
        elseif randomChoice == 2 then
            verbal = "greeting"
        else
            verbal = "vehicle_bump"
        end
        vehicle.PlayVoiceOver(vehicleComp.GetDriverMounted(vehicle:GetEntityID()), verbal,
            "Scripts:ReactToHorn", true);
    else
        print("Nothing happened")
    end
end

function ReactToHorn:SimpleModeReaction(vehicle, vehicleComp, player)
    local vehiclesReaction = self.settings.vehiclesReactTypeSelectorValue
    local vehiclesReactionProbability = self.settings.vehiclesReactProbability / 100

    --"hit_reaction_light"
    --"pedestrian_hit"
    --"danger"
    --"fear_run"
    --"fear_beg"
    --"stlh_curious_grunt"
    --"greeting"
    --"vehicle_bump"
    if math.random() <= vehiclesReactionProbability then
        if vehiclesReaction == 1 then
            local randomChoice = math.random(1, 3)
            if randomChoice == 1 then
                vehicle:ToggleHorn(true)
            elseif randomChoice == 2 then
                vehicle:TriggerDrivingPanicBehavior(player:GetWorldPosition())
            else
                vehicle.PlayVoiceOver(vehicleComp.GetDriverMounted(vehicle:GetEntityID()), "greeting",
                    "Scripts:ReactToHorn", true);
            end
        elseif vehiclesReaction == 2 then
            vehicle:TriggerDrivingPanicBehavior(player:GetWorldPosition())
        elseif vehiclesReaction == 3 then
            local randomDelay = math.random() * (2.0 - 0.5) + 0.5
            vehicleComp:PlayDelayedHonk(1.0, randomDelay)
        elseif vehiclesReaction == 4 then
            local randomChoice = math.random(1, 3)
            local verbal = ""
            if randomChoice == 1 then
                verbal = "stlh_curious_grunt"
            elseif randomChoice == 2 then
                verbal = "greeting"
            else
                verbal = "vehicle_bump"
            end
            vehicle.PlayVoiceOver(vehicleComp.GetDriverMounted(vehicle:GetEntityID()), verbal,
                "Scripts:ReactToHorn", true);
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

function ReactToHorn:Bounce(vehicle, player)
    local vehicleComp = vehicle:GetVehicleComponent()
    local vehicleCompPS = vehicleComp:GetPS()
    local hasExploded = vehicleCompPS:GetHasExploded()
    if hasExploded then return end
    vehicle:SetHasExploded()
end

function ReactToHorn:ExplodeVehiclesInVicinity(vehicle, player)
    local vehicleComp = vehicle:GetVehicleComponent()
    local vehicleCompPS = vehicleComp:GetPS()
    local hasExploded = vehicleCompPS:GetHasExploded()
    if hasExploded then return end

    local randomDelay = 0.2 + math.random() * (2.5 - 0.2)

    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(randomDelay, function()
        local duration = 1.0
        local explosion = "Attacks.Explosion"
        self:SpawnExplosion(vehicle, player, explosion, duration)
        self:SpawnExplosion(vehicle, player, explosion, duration)
        self:SpawnExplosion(vehicle, player, explosion, duration)
        --vehicleComp:ExplodeVehicle(nil) just becasue this damages player car a ton
    end)
end

function ReactToHorn:IsEntityVehicle(entity)
    return entity:ToString() == "vehicleCarBaseObject"
end

function ReactToHorn:IsEntityNPC(entity)
    return entity:ToString() == "NPCPuppet"
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

registerInput("test", "Reaction Test", function(keypress)
    if not keypress then
        return
    end

    local player = Game.GetPlayer()
    ReactToHorn:HandleHonkingReaction(player)
    --[[ print("Verbal Probability: ", ReactToHorn.settings.complex.vehicle.verbalProbability)
    print("Panic Probability: ", ReactToHorn.settings.complex.vehicle.panicProbability)
    print("HonkBack Probability: ", ReactToHorn.settings.complex.vehicle.honkBackProbability) ]]
end)

return ReactToHorn:new()
