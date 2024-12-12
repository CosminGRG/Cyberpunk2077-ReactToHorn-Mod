local config = require("modules/config/config")
local Cron = require("modules/externals/Cron")
local ui = require("modules/ui/ui")

local ReactToHorn = {
    settings = {
    },
    defaultSettings = {
        isEnabled = true,
        isFunEnabled = false,
        isHavingFun = false,
        pedestrianReactRadius = 10.0,
        vehicleReactRadius = 20.0,
        pedestrianDodgeOnPavement = true,
        pedestriansReactToHonk = true,
        crowdReaction = true,
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
        pedestrianTimeoutSelectorValue = 2,
        complex = {
            pedestrian = {
                pedestrianReactTimeoutMin = 3,
                pedestrianReactTimeoutMax = 10,
                walkAwayProbability = 30,
                runProbability = 20,
                verbalProbability = 40,
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

    reactConfigNames = { "Simple", "Complex" },
    reactTimeoutNames = { "No Timeout", "3-10 seconds", "5-13 seconds", "7-16 seconds", "9-19 seconds" },

    pedestrianReactIntensityNames = { "Normal", "High", "Very High" },
    pedestrianReactTypesNames = { "Random", "Walk Away", "Run", "Verbal" },
    pedestrianReactTypes = {
        ["Random"] = 1,
        ["Walk Away"] = 50,
        ["Run"] = 54,
    },
    vehicleReactTypesNames = { "Random", "Panic", "Honk Back", "Verbal" },

    delay = false,
    delayTime = 1,
    minPedestrianReactRadius = 1.0,
    maxPedestrianReactRadius = 40.0,
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
            minPedestrianTimeoutMin = 0,
            maxPedestrianTimeoutMin = 100,
            minPedestrianTimeoutMax = 0,
            maxPedestrianTimeoutMax = 100,
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
    isTriggeringReaction = false,

    distanceChecks = {
        { maxSpeed = 20.0,      normal = 10.0, high = 15.0, veryHigh = 25.0 },
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

        print("[ReactToHorn] React To Horn - v1.2.0 initialized")
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

        if (self.settings.vehiclesReactToHonk or
                self.settings.pedestriansReactToHonk or
                self.settings.isFunEnabled) and vehicle then
            self:HandleHonkingReaction(player, vehicle)
        end
    end)
end

function ReactToHorn:ObserveReactionEvent()
    Override("ReactionManagerComponent", "SpreadFear", function(this, phase, wrappedMethod)
        if self.isTriggeringReaction then
            return
        end

        wrappedMethod(phase)
    end)

    Observe("ReactionManagerComponent", "HandleCrowdReaction", function(this, stimEvent)
        if stimEvent.stimType ~= gamedataStimType.VehicleHorn or not self.settings.isEnabled then return end

        local player = Game.GetPlayer()
        local vehicle = Game.GetMountedVehicle(player)

        if self.settings.pedestrianDodgeOnPavement and vehicle and vehicle:IsOnPavement() then
            self:HandlePavementDodgeReaction(this, player, vehicle)
        end
    end)
end

function ReactToHorn:HandleHonkingReaction(player, vehicle)
    if self.settings.isFunEnabled then
        local funEntities = self:GetEntitiesAroundPlayer(player, self.settings.funRadius)

        if not self.isHavingFun then
            self.isHavingFun = true
            for _, entity in ipairs(funEntities) do
                local entityToProcess = entity:GetComponent():GetEntity()
                if self:IsEntityNPC(entityToProcess) then
                    self:HandleNPCFun(entityToProcess, player)
                elseif self:IsEntityVehicle(entityToProcess) and entityToProcess:IsVehicle() then
                    self:HandleVehicleFun(entityToProcess, player)
                end
            end

            ---@diagnostic disable-next-line: missing-parameter
            Cron.After(2, function()
                self.isHavingFun = false
            end)
        end
    end
    if self.settings.pedestriansReactToHonk and not vehicle:IsOnPavement() then
        local pedestrianEntities = self:GetEntitiesAroundPlayer(player, self.settings.pedestrianReactRadius)

        if self.settings.crowdReaction then
            self:HandleCrowd(player, pedestrianEntities)
        else
            self.isTriggeringReaction = true
            for _, entity in ipairs(pedestrianEntities) do
                local entityToProcess = entity:GetComponent():GetEntity()

                if self:IsEntityNPC(entityToProcess) then
                    self:HandleNPCEntity(entityToProcess, player)
                end
            end
            ---@diagnostic disable-next-line: missing-parameter
            Cron.After(2, function()
                self.isTriggeringReaction = false
            end)
        end
    end
    if self.settings.vehiclesReactToHonk then
        local vehicleEntities = self:GetEntitiesAroundPlayer(player, self.settings.vehicleReactRadius)

        for _, entity in ipairs(vehicleEntities) do
            local entityToProcess = entity:GetComponent():GetEntity()

            if self:IsEntityVehicle(entityToProcess) and entityToProcess:IsVehicle() then
                self:HandleVehicleEntity(entityToProcess, player)
            end
        end
    end
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

            this:TriggerReactionBehaviorForCrowd(stimEvent.sourceObject, gamedataOutput.DodgeToSide, false,
                stimEvent.sourcePosition)
        end
    end
end

function ReactToHorn:HandleCrowd(player, pedestrianEntities)
    if self.settings.pedestrianReactMode == 1 then
        self:SimpleCrowdReaction(player, pedestrianEntities)
    elseif self.settings.pedestrianReactMode == 2 then
        self:ComplexCrowdReaction(player, pedestrianEntities)
    end
end

function ReactToHorn:HandleNPCEntity(npc, player)
    if npc:IsDead() or npc:IsQuest() or npc:IsPlayerCompanion() or npc:IsVendor() then return end

    self:PedestrianReaction(npc, player)
end

function ReactToHorn:HandleVehicleEntity(vehicle, player)
    if vehicle:IsPlayerVehicle() or vehicle:IsPlayerDriver() or vehicle:IsQuest() then return end
    local vehicleComp = vehicle:GetVehicleComponent()

    if not self.settings.policeVehiclesReactToHonk and (vehicleComp:HasPreventionPassenger() or vehicle:IsPrevention()) then return end
    if not vehicleComp.HasActiveDriverMounted(vehicle:GetEntityID()) or vehicle:IsVehicleParked() then return end

    self:VehicleReaction(vehicle, player)
end

function ReactToHorn:HandleVehicleFun(vehicle, player)
    if vehicle:IsPlayerVehicle() or vehicle:IsPlayerDriver() or vehicle:IsQuest() then return end

    if self.settings.popTiresOnHonk then
        if not self.settings.explodeVehicleOnHonk or not self.settings.bounceOnHonk then
            self:PopVehicleTire(vehicle, player)
        end
    end
    if self.settings.bounceOnHonk then
        if not self.settings.explodeVehicleOnHonk then
            self:BounceVehicle(vehicle, player)
        end
    end
    if self.settings.explodeVehicleOnHonk then
        self:ExplodeVehicle(vehicle, player)
    end
end

function ReactToHorn:HandleNPCFun(npc, player)
    if npc:IsDead() or npc:IsQuest() or npc:IsPlayerCompanion() or npc:IsVendor() then return end

    if self.settings.killNPCsOnHonk then
        if not self.settings.explodeNPCOnHonk then
            self:BroadcastTerror(player, self.settings.funRadius)
            self:KillNPC(npc, player)
        end
    end
    if self.settings.explodeNPCOnHonk then
        self:BroadcastTerror(player, self.settings.funRadius)
        self:ExplodeNPC(npc, player)
    end
end

function ReactToHorn:VehicleReaction(vehicle, player)
    local vehicleID = vehicle:GetEntityID():GetHash()
    local timeoutPeriod = self:GetRandomTimeout("vehicle")
    local currentTime = self:GetCurrentTime()

    if self:IsVehicleInCooldown(vehicleID, currentTime) then
        return
    end

    self.reactedVehicles[vehicleID] = {
        time = currentTime,
        timeout = timeoutPeriod
    }

    local vehicleComp = vehicle:GetVehicleComponent()
    if self.settings.vehicleReactMode == 1 then
        self:SimpleVehicleReaction(vehicle, vehicleComp, player)
    elseif self.settings.vehicleReactMode == 2 then
        self:ComplexVehicleReaction(vehicle, vehicleComp, player)
    end
end

function ReactToHorn:PedestrianReaction(npc, player)
    local npcID = npc:GetEntityID():GetHash()
    local timeoutPeriod = self:GetRandomTimeout("npc")
    local currentTime = self:GetCurrentTime()

    if self:IsNPCInCooldown(npcID, currentTime) then
        return
    end

    self.reactedPedestrians[npcID] = {
        time = currentTime,
        timeout = timeoutPeriod
    }

    if self.settings.pedestrianReactMode == 1 then
        self:SimpleNPCReaction(npc, player)
    elseif self.settings.pedestrianReactMode == 2 then
        self:ComplexNPCReaction(npc, player)
    end
end

function ReactToHorn:GetCurrentTime()
    return os.clock()
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

function ReactToHorn:GetEntitiesAroundPlayer(player, radius)
    local targetingSystem = Game.GetTargetingSystem()
    local searchQuery = Game["TSQ_ALL;"]()
    searchQuery.ignoreInstigator = true
    searchQuery.maxDistance = math.floor(radius + 12) --fuck
    searchQuery.testedSet = TargetingSet.Visible
    local success, parts = targetingSystem:GetTargetParts(player, searchQuery)
    return parts
end

function ReactToHorn:GetRandomTimeout(entityType)
    if entityType == "vehicle" then
        if self.settings.vehicleReactMode == 1 then
            local timeoutSelection = self.settings.vehicleTimoutSelectorValue

            local range = self.timeoutRanges[self.reactTimeoutNames[timeoutSelection]]
            if range then
                return math.random(range[1], range[2])
            else
                return 5
            end
        elseif self.settings.vehicleReactMode == 2 then
            local rangeMin = self.settings.complex.vehicle.vehicleReactTimeoutMin
            local rangeMax = self.settings.complex.vehicle.vehicleReactTimeoutMax

            return math.random(rangeMin, rangeMax)
        end
    elseif entityType == "npc" then
        if self.settings.pedestrianReactMode == 1 then
            local timeoutSelection = self.settings.pedestrianTimeoutSelectorValue

            local range = self.timeoutRanges[self.reactTimeoutNames[timeoutSelection]]
            if range then
                return math.random(range[1], range[2])
            else
                return 5
            end
        elseif self.settings.pedestrianReactMode == 2 then
            local rangeMin = self.settings.complex.pedestrian.pedestrianReactTimeoutMin
            local rangeMax = self.settings.complex.pedestrian.pedestrianReactTimeoutMax

            return math.random(rangeMin, rangeMax)
        end
    end
end

function ReactToHorn:CleanUpExpiredEntries(currentTime, entityType)
    local currentTime = self:GetCurrentTime()

    if entityType == "vehicle" then
        for vehicleID, vehData in pairs(self.reactedVehicles) do
            if currentTime >= (vehData.time + vehData.timeout) then
                self.reactedVehicles[vehicleID] = nil
            end
        end
    elseif entityType == "npc" then
        for npcID, npcData in pairs(self.reactedPedestrians) do
            if currentTime >= (npcData.time + npcData.timeout) then
                self.reactedPedestrians[npcID] = nil
            end
        end
    end
end

function ReactToHorn:IsNPCInCooldown(npcID, currentTime)
    self:CleanUpExpiredEntries(currentTime, "npc")

    if self.reactedPedestrians[npcID] == nil then
        return false
    end

    local npcData = self.reactedPedestrians[npcID]

    return currentTime < (npcData.time + npcData.timeout)
end

local function GetRandomVerbal()
    local randomChoice = math.random(1, 3)
    local verbal = ""
    if randomChoice == 1 then
        verbal = "stlh_curious_grunt"
    elseif randomChoice == 2 then
        verbal = "greeting"
    else
        verbal = "vehicle_bump"
    end
    return verbal
end

function ReactToHorn:SimpleCrowdReaction(player, pedestrianEntities)
    local investigateData = senseStimInvestigateData.new()
    investigateData.skipReactionDelay = true
    investigateData.skipInitialAnimation = true
    investigateData.illegalAction = false
    local stimRadius = self.settings.pedestrianReactRadius

    local pedestrianReaction = self.settings.pedestrianReactTypeSelectorValue
    local pedestrianReactProbability = self.settings.pedestrianReactProbability / 100

    if math.random() <= pedestrianReactProbability then
        if pedestrianReaction == 1 then
            local randomChoice = math.random(1, 3)
            if randomChoice == 1 then
                StimBroadcasterComponent.BroadcastStim(player, gamedataStimType.SilentAlarm, stimRadius,
                    investigateData,
                    true)
            elseif randomChoice == 2 then
                StimBroadcasterComponent.BroadcastStim(player, gamedataStimType.Terror, stimRadius,
                    investigateData,
                    true)
            else
                self:CrowdVoiceOver(pedestrianEntities)
            end
        elseif pedestrianReaction == 2 or pedestrianReaction == 3 then
            StimBroadcasterComponent.BroadcastStim(player, self.settings.pedestrianReactTypeValue, stimRadius,
                investigateData,
                true)
        elseif pedestrianReaction == 4 then
            self:CrowdVoiceOver(pedestrianEntities)
        end
    end
end

function ReactToHorn:ComplexCrowdReaction(player, pedestrianEntities)
    local npcWalkAwayProbability = self.settings.complex.pedestrian.walkAwayProbability / 100
    local npcRunProbability = self.settings.complex.pedestrian.runProbability / 100
    local npcVerbalProbability = self.settings.complex.pedestrian.verbalProbability / 100

    local investigateData = senseStimInvestigateData.new()
    investigateData.skipReactionDelay = true
    investigateData.skipInitialAnimation = true
    investigateData.illegalAction = false
    local stimRadius = self.settings.pedestrianReactRadius

    local randomValue = math.random()
    if randomValue <= npcWalkAwayProbability then
        StimBroadcasterComponent.BroadcastStim(player, gamedataStimType.SilentAlarm, stimRadius,
            investigateData,
            true)
    elseif randomValue <= npcWalkAwayProbability + npcRunProbability then
        StimBroadcasterComponent.BroadcastStim(player, gamedataStimType.Terror, stimRadius,
            investigateData,
            true)
    elseif randomValue <= npcWalkAwayProbability + npcRunProbability + npcVerbalProbability then
        self:CrowdVoiceOver(pedestrianEntities)
    else
        --print("Nothing happened")
    end
end

function ReactToHorn:SimpleNPCReaction(npc, player)
    local pedestrianReaction = self.settings.pedestrianReactTypeSelectorValue
    local pedestrianReactProbability = self.settings.pedestrianReactProbability / 100

    if math.random() <= pedestrianReactProbability then
        if pedestrianReaction == 1 then
            local randomChoice = math.random(1, 3)
            if randomChoice == 1 then
                StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.SilentAlarm, npc)
            elseif randomChoice == 2 then
                StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.Terror, npc)
            else
                local verbal = GetRandomVerbal()
                npc.PlayVoiceOver(npc, verbal,
                    "Scripts:ReactToHorn", true);
            end
        elseif pedestrianReaction == 2 then
            StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.SilentAlarm, npc)
        elseif pedestrianReaction == 3 then
            StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.Terror, npc)
        elseif pedestrianReaction == 4 then
            local verbal = GetRandomVerbal()
            npc.PlayVoiceOver(npc, verbal,
                "Scripts:ReactToHorn", false);
        end
    else
        --print("Nothing happened")
    end
end

function ReactToHorn:ComplexNPCReaction(npc, player)
    local npcWalkAwayProbability = self.settings.complex.pedestrian.walkAwayProbability / 100
    local npcRunProbability = self.settings.complex.pedestrian.runProbability / 100
    local npcVerbalProbability = self.settings.complex.pedestrian.verbalProbability / 100

    local randomValue = math.random()
    if randomValue <= npcWalkAwayProbability then
        StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.SilentAlarm, npc)
    elseif randomValue <= npcWalkAwayProbability + npcRunProbability then
        StimBroadcasterComponent.SendStimDirectly(player, gamedataStimType.Terror, npc)
    elseif randomValue <= npcWalkAwayProbability + npcRunProbability + npcVerbalProbability then
        local verbal = GetRandomVerbal()
        npc.PlayVoiceOver(npc, verbal,
            "Scripts:ReactToHorn", false);
    else
        --print("Nothing happened")
    end
end

function ReactToHorn:CrowdVoiceOver(pedestrianEntities)
    for _, entity in ipairs(pedestrianEntities) do
        local npc = entity:GetComponent():GetEntity()

        if self:IsEntityNPC(npc) then
            local verbal = GetRandomVerbal()
            npc.PlayVoiceOver(npc, verbal,
                "Scripts:ReactToHorn", false);
        end
    end
end

function ReactToHorn:KillNPC(npc, player)
    local randomDelay = 0.2 + math.random() * (2.5 - 0.2)

    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(randomDelay, function()
        npc:Kill(nil, false, false)
    end)
end

function ReactToHorn:ExplodeNPC(npc, player)
    local randomDelay = 0.2 + math.random() * (2.5 - 0.2)

    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(randomDelay, function()
        local duration = 1.0
        local explosion = "Attacks.OzobGrenade" --Attacks.RocketEffect
        self:SpawnExplosion(npc, player, explosion, duration)
        npc:Kill(nil, false, false)
    end)
end

function ReactToHorn:IsVehicleInCooldown(vehicleID, currentTime)
    self:CleanUpExpiredEntries(currentTime, "vehicle")

    if self.reactedVehicles[vehicleID] == nil then
        return false
    end

    local vehData = self.reactedVehicles[vehicleID]

    return currentTime < (vehData.time + vehData.timeout)
end

function ReactToHorn:ComplexVehicleReaction(vehicle, vehicleComp, player)
    local vehicleHonkBackProbability = self.settings.complex.vehicle.honkBackProbability / 100
    local vehiclePanicProbability = self.settings.complex.vehicle.panicProbability / 100
    local vehicleVerbalProbability = self.settings.complex.vehicle.verbalProbability / 100

    local randomValue = math.random()
    if randomValue <= vehicleHonkBackProbability then
        local randomDelay = math.random() * (2.0 - 0.5) + 0.5
        vehicleComp:PlayDelayedHonk(1.0, randomDelay)
    elseif randomValue <= vehicleHonkBackProbability + vehiclePanicProbability then
        vehicle:TriggerDrivingPanicBehavior(player:GetWorldPosition())
    elseif randomValue <= vehicleHonkBackProbability + vehiclePanicProbability + vehicleVerbalProbability then
        local verbal = GetRandomVerbal()
        vehicle.PlayVoiceOver(vehicleComp.GetDriverMounted(vehicle:GetEntityID()), verbal,
            "Scripts:ReactToHorn", true);
    else
        --print("Nothing happened")
    end
end

function ReactToHorn:SimpleVehicleReaction(vehicle, vehicleComp, player)
    local vehiclesReaction = self.settings.vehiclesReactTypeSelectorValue
    local vehiclesReactionProbability = self.settings.vehiclesReactProbability / 100

    if math.random() <= vehiclesReactionProbability then
        if vehiclesReaction == 1 then
            local randomChoice = math.random(1, 3)
            if randomChoice == 1 then
                local randomDelay = math.random() * (2.0 - 0.5) + 0.5
                vehicleComp:PlayDelayedHonk(1.0, randomDelay)
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
            local verbal = GetRandomVerbal()
            vehicle.PlayVoiceOver(vehicleComp.GetDriverMounted(vehicle:GetEntityID()), verbal,
                "Scripts:ReactToHorn", true);
        end
    end
end

function ReactToHorn:PopVehicleTire(vehicle, player)
    local randomTire = math.random(1, 4)
    local randomDelay = 0.5 + math.random() * (2 - 0.5)

    vehicle:TriggerDrivingPanicBehavior(player:GetWorldPosition())

    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(randomDelay, function()
        vehicle:ToggleBrokenTire(randomTire, true)
    end)
end

function ReactToHorn:BounceVehicle(vehicle, player)
    local vehicleComp = vehicle:GetVehicleComponent()
    local vehicleCompPS = vehicleComp:GetPS()
    local hasExploded = vehicleCompPS:GetHasExploded()
    if hasExploded then return end
    vehicle:SetHasExploded()
end

function ReactToHorn:ExplodeVehicle(vehicle, player)
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

return ReactToHorn:new()
