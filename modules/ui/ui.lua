local Cron = require("modules/externals/Cron")
local config = require("modules/config/config")

local UI = {
    reactToHorn = nil,
    currentPedestrianUIElements = {},
    currentVehicleUIElements = {},
    pedestrianUIElements = {},
    vehicleUIElements = {},
    isUpdatingProbs = false,
    isUpdatingTimeouts = false,
}

function UI:InitializeDynamicElements()
    self.pedestrianUIElements = {
        simple = {
            {
                type = "selector",
                label = "Reaction Type",
                description = "What type of the reaction should the NPCs have when you honk the horn",
                options = self.reactToHorn.pedestrianReactTypesNames,
                current = self.reactToHorn.settings.pedestrianReactTypeSelectorValue,
                default = self.reactToHorn.defaultSettings.pedestrianReactTypeSelectorValue,
                callback = function(value)
                    local selectedReaction = self.reactToHorn.pedestrianReactTypesNames[value]
                    self.reactToHorn.settings.pedestrianReactTypeValue = self.reactToHorn.pedestrianReactTypes
                        [selectedReaction]
                    self.reactToHorn.settings.pedestrianReactTypeSelectorValue = value
                    self:SaveSettings()
                end
            },
            {
                type = "selector",
                label = "Reaction Timeout",
                description =
                "After the pedestrian reacts to your horn it will wait this long before it can react again. (Seconds)",
                options = self.reactToHorn.reactTimeoutNames,
                current = self.reactToHorn.settings.pedestrianTimeoutSelectorValue,
                default = self.reactToHorn.defaultSettings.pedestrianTimeoutSelectorValue,
                callback = function(value)
                    self.reactToHorn.settings.pedestrianTimeoutSelectorValue = value
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Reaction Probability (%)",
                description = "The probability for the NPC reaction to happen",
                min = self.reactToHorn.minProbability,
                max = self.reactToHorn.maxProbability,
                step = self.reactToHorn.probabilityStep,
                current = self.reactToHorn.settings.pedestrianReactProbability,
                default = self.reactToHorn.defaultSettings.pedestrianReactProbability,
                callback = function(value)
                    self.reactToHorn.settings.pedestrianReactProbability = value
                    self:SaveSettings()
                end
            }
        },
        complex = {
            {
                type = "slider",
                label = "Min Reaction Timeout (s)",
                description =
                "The minimum value that the pedestrian might wait before the next verbal reaction. The timeout value is randomly generated between the minimum and maximum. Set both to 0 for no timeout",
                min = self.reactToHorn.complexDefines.pedestrian.minPedestrianTimeoutMin,
                max = self.reactToHorn.complexDefines.pedestrian.maxPedestrianTimeoutMin,
                step = 1,
                current = self.reactToHorn.settings.complex.pedestrian.pedestrianReactTimeoutMin,
                default = self.reactToHorn.defaultSettings.complex.pedestrian.pedestrianReactTimeoutMin,
                callback = function(value)
                    self.reactToHorn.settings.complex.pedestrian.pedestrianReactTimeoutMin = value
                    self:HandlePedestrianMinMaxTimeout()
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Max Reaction Timeout (s)",
                description =
                "The maximum value that the pedestrian might wait before the next verbal reaction. The timeout value is randomly generated between the minimum and maximum. Set both to 0 for no timeout",
                min = self.reactToHorn.complexDefines.pedestrian.minPedestrianTimeoutMax,
                max = self.reactToHorn.complexDefines.pedestrian.maxPedestrianTimeoutMax,
                step = 1,
                current = self.reactToHorn.settings.complex.pedestrian.pedestrianReactTimeoutMax,
                default = self.reactToHorn.defaultSettings.complex.pedestrian.pedestrianReactTimeoutMax,
                callback = function(value)
                    self.reactToHorn.settings.complex.pedestrian.pedestrianReactTimeoutMax = value
                    self:HandlePedestrianMinMaxTimeout()
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Walk Away Probability (%)",
                description =
                "The probability for the walk away reaction to happen. The total value of all 3 probabilities cannot exceed 100",
                min = 0,
                max = self.reactToHorn.complexDefines.pedestrian.maxWalkAwayProb,
                step = 1,
                current = self.reactToHorn.settings.complex.pedestrian.walkAwayProbability,
                default = self.reactToHorn.defaultSettings.complex.pedestrian.walkAwayProbability,
                callback = function(value)
                    self.reactToHorn.settings.complex.pedestrian.walkAwayProbability = value
                    self:CalculatePedestrianReactProb("walkAway")
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Run Probability (%)",
                description =
                "The probability for the run reaction to happen. The total value of all 3 probabilities cannot exceed 100",
                min = 0,
                max = self.reactToHorn.complexDefines.pedestrian.maxRunProb,
                step = 1,
                current = self.reactToHorn.settings.complex.pedestrian.runProbability,
                default = self.reactToHorn.defaultSettings.complex.pedestrian.runProbability,
                callback = function(value)
                    self.reactToHorn.settings.complex.pedestrian.runProbability = value
                    self:CalculatePedestrianReactProb("run")
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Verbal Probability (%)",
                description =
                "The probability for the verbal reaction to happen. The total value of all 3 probabilities cannot exceed 100",
                min = 0,
                max = self.reactToHorn.complexDefines.pedestrian.maxVerbalProb,
                step = 1,
                current = self.reactToHorn.settings.complex.pedestrian.verbalProbability,
                default = self.reactToHorn.defaultSettings.complex.pedestrian.verbalProbability,
                callback = function(value)
                    self.reactToHorn.settings.complex.pedestrian.verbalProbability = value
                    self:CalculatePedestrianReactProb("verbal")
                    self:SaveSettings()
                end
            }
        }
    }
    self.vehicleUIElements = {
        simple = {
            {
                type = "selector",
                label = "Reaction Type",
                description = "What type of the reaction should the Vehicle NPCs have when you honk the horn",
                options = self.reactToHorn.vehicleReactTypesNames,
                current = self.reactToHorn.settings.vehiclesReactTypeSelectorValue,
                default = self.reactToHorn.defaultSettings.vehiclesReactTypeSelectorValue,
                callback = function(value)
                    self.reactToHorn.settings.vehiclesReactTypeSelectorValue = value
                    self:SaveSettings()
                end
            },
            {
                type = "selector",
                label = "Reaction Timeout",
                description =
                "After the vehicle reacts to your horn it will wait this long before it can react again. (Seconds)",
                options = self.reactToHorn.reactTimeoutNames,
                current = self.reactToHorn.settings.vehicleTimoutSelectorValue,
                default = self.reactToHorn.defaultSettings.vehicleTimoutSelectorValue,
                callback = function(value)
                    self.reactToHorn.settings.vehicleTimoutSelectorValue = value
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Reaction Probability (%)",
                description = "The probability for the vehicle reaction to happen",
                min = self.reactToHorn.minProbability,
                max = self.reactToHorn.maxProbability,
                step = self.reactToHorn.probabilityStep,
                current = self.reactToHorn.settings.vehiclesReactProbability,
                default = self.reactToHorn.defaultSettings.vehiclesReactProbability50,
                callback = function(value)
                    self.reactToHorn.settings.vehiclesReactProbability = value
                    self:SaveSettings()
                end
            }
        },
        complex = {
            {
                type = "slider",
                label = "Min Reaction Timeout (s)",
                description =
                "The minimum value that the vehicle might wait before the next reaction. The timeout value is randomly generated between the minimum and maximum. Set both to 0 for no timeout",
                min = self.reactToHorn.complexDefines.vehicle.minVehicleTimeoutMin,
                max = self.reactToHorn.complexDefines.vehicle.maxVehicleTimeoutMin,
                step = 1,
                current = self.reactToHorn.settings.complex.vehicle.vehicleReactTimeoutMin,
                default = self.reactToHorn.defaultSettings.complex.vehicle.vehicleReactTimeoutMin,
                callback = function(value)
                    self.reactToHorn.settings.complex.vehicle.vehicleReactTimeoutMin = value
                    self:HandleVehicleMinMaxTimeout()
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Max Reaction Timeout (s)",
                description =
                "The maximum value that the vehicle might wait before the next reaction. The timeout value is randomly generated between the minimum and maximum. Set both to 0 for no timeout",
                min = self.reactToHorn.complexDefines.vehicle.minVehicleTimeoutMax,
                max = self.reactToHorn.complexDefines.vehicle.maxVehicleTimeoutMax,
                step = 1,
                current = self.reactToHorn.settings.complex.vehicle.vehicleReactTimeoutMax,
                default = self.reactToHorn.defaultSettings.complex.vehicle.vehicleReactTimeoutMax,
                callback = function(value)
                    self.reactToHorn.settings.complex.vehicle.vehicleReactTimeoutMax = value
                    self:HandleVehicleMinMaxTimeout()
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Honk Back Probability (%)",
                description =
                "The probability for the honk back reaction to happen. The total value of all 3 probabilities cannot exceed 100",
                min = 0,
                max = self.reactToHorn.complexDefines.vehicle.maxHonkBackProb,
                step = 1,
                current = self.reactToHorn.settings.complex.vehicle.honkBackProbability,
                default = self.reactToHorn.defaultSettings.complex.vehicle.honkBackProbability,
                callback = function(value)
                    self.reactToHorn.settings.complex.vehicle.honkBackProbability = value
                    self:CalculateVehicleReactProb("honkBack")
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Panic Probability (%)",
                description =
                "The probability for the panic reaction to happen. The total value of all 3 probabilities cannot exceed 100",
                min = 0,
                max = self.reactToHorn.complexDefines.vehicle.maxPanicProb,
                step = 1,
                current = self.reactToHorn.settings.complex.vehicle.panicProbability,
                default = self.reactToHorn.defaultSettings.complex.vehicle.panicProbability,
                callback = function(value)
                    self.reactToHorn.settings.complex.vehicle.panicProbability = value
                    self:CalculateVehicleReactProb("panic")
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Verbal Probability (%)",
                description =
                "The probability for the verbal reaction to happen. The total value of all 3 probabilities cannot exceed 100",
                min = 0,
                max = self.reactToHorn.complexDefines.vehicle.maxVerbalProb,
                step = 1,
                current = self.reactToHorn.settings.complex.vehicle.verbalProbability,
                default = self.reactToHorn.defaultSettings.complex.vehicle.verbalProbability,
                callback = function(value)
                    self.reactToHorn.settings.complex.vehicle.verbalProbability = value
                    self:CalculateVehicleReactProb("verbal")
                    self:SaveSettings()
                end
            }
        }
    }
end

function UI:HandlePedestrianMinMaxTimeout()
    if self.isUpdatingTimeouts then
        return
    end

    local min = self.reactToHorn.settings.complex.pedestrian.pedestrianReactTimeoutMin
    local max = self.reactToHorn.settings.complex.pedestrian.pedestrianReactTimeoutMax
    if min > max then
        if max == 0 then
            min = 0
        else
            min = max - 1
        end
        self.reactToHorn.settings.complex.pedestrian.pedestrianReactTimeoutMin = min

        self:InitializeDynamicElements()
        self:SaveSettings()

        self.isUpdatingTimeouts = true

        local nativeSettings = GetMod("nativeSettings")
        ---@diagnostic disable-next-line: missing-parameter
        Cron.After(2, function()
            self.isUpdatingTimeouts = false
            self:updatePedestrianUIBasedOnPreset(nativeSettings)
        end)
    end
end

function UI:HandleVehicleMinMaxTimeout()
    if self.isUpdatingTimeouts then
        return
    end

    local min = self.reactToHorn.settings.complex.vehicle.vehicleReactTimeoutMin
    local max = self.reactToHorn.settings.complex.vehicle.vehicleReactTimeoutMax
    if min > max then
        if max == 0 then
            min = 0
        else
            min = max - 1
        end
        self.reactToHorn.settings.complex.vehicle.vehicleReactTimeoutMin = min

        self:InitializeDynamicElements()
        self:SaveSettings()

        self.isUpdatingTimeouts = true

        local nativeSettings = GetMod("nativeSettings")
        ---@diagnostic disable-next-line: missing-parameter
        Cron.After(2, function()
            self.isUpdatingTimeouts = false
            self:updateVehicleUIBasedOnPreset(nativeSettings)
        end)
    end
end

function UI:CalculatePedestrianReactProb(changedType)
    local maxProb = 100

    local verbalProb = self.reactToHorn.settings.complex.pedestrian.verbalProbability
    local walkAwayProb = self.reactToHorn.settings.complex.pedestrian.walkAwayProbability
    local runProb = self.reactToHorn.settings.complex.pedestrian.runProbability

    local modifiedProb = self.reactToHorn.settings.complex.pedestrian[changedType .. "Probability"]

    local totalProb = verbalProb + walkAwayProb + runProb

    if totalProb > maxProb then
        local remainder = maxProb - modifiedProb

        local probabilities = {
            verbal = verbalProb,
            walkAway = walkAwayProb,
            run = runProb
        }

        probabilities[changedType] = nil

        local remainingProb = 0
        for _, prob in pairs(probabilities) do
            remainingProb = remainingProb + prob
        end

        if remainingProb > 0 then
            for key, prob in pairs(probabilities) do
                local newProb = (prob / remainingProb) * remainder
                self.reactToHorn.settings.complex.pedestrian[key .. "Probability"] = math.floor(newProb)
            end
        end
    end

    self:InitializeDynamicElements()
    self:SaveSettings()

    if self.isUpdatingProbs then
        return
    end

    self.isUpdatingProbs = true

    local nativeSettings = GetMod("nativeSettings")
    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(2, function()
        self.isUpdatingProbs = false
        self:updatePedestrianUIBasedOnPreset(nativeSettings)
    end)
end

function UI:CalculateVehicleReactProb(changedType)
    local maxProb = 100

    local verbalProb = self.reactToHorn.settings.complex.vehicle.verbalProbability
    local panicProb = self.reactToHorn.settings.complex.vehicle.panicProbability
    local honkBackProb = self.reactToHorn.settings.complex.vehicle.honkBackProbability

    local modifiedProb = self.reactToHorn.settings.complex.vehicle[changedType .. "Probability"]

    local totalProb = verbalProb + panicProb + honkBackProb

    if totalProb > maxProb then
        local remainder = maxProb - modifiedProb

        local probabilities = {
            verbal = verbalProb,
            panic = panicProb,
            honkBack = honkBackProb
        }

        probabilities[changedType] = nil

        local remainingProb = 0
        for _, prob in pairs(probabilities) do
            remainingProb = remainingProb + prob
        end

        if remainingProb > 0 then
            for key, prob in pairs(probabilities) do
                local newProb = (prob / remainingProb) * remainder
                self.reactToHorn.settings.complex.vehicle[key .. "Probability"] = math.floor(newProb)
            end
        end
    end

    self:InitializeDynamicElements()
    self:SaveSettings()

    if self.isUpdatingProbs then
        return
    end

    self.isUpdatingProbs = true

    local nativeSettings = GetMod("nativeSettings")
    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(2, function()
        self.isUpdatingProbs = false
        self:updateVehicleUIBasedOnPreset(nativeSettings)
    end)
end

function UI.onInit(ReactToHorn)
    UI.reactToHorn = ReactToHorn
    UI:InitializeDynamicElements()
end

function UI:SetupMenu(nativeSettings)
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
            "Enable or Disable the React To Horn mod", self.reactToHorn.settings.isEnabled,
            self.reactToHorn.defaultSettings.isEnabled,
            function(state)
                self.reactToHorn.settings.isEnabled = state
                self:SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/pedestrian_dodge_settings", "Pedestrians Dodge On Honk",
            "When you're on the pavement and honk your horn, pedestrians will dodge. The distance at which pedestrians react increases with your speed and with the intensity setting below - the faster you drive, the greater the effect",
            self.reactToHorn.settings.pedestrianDodgeOnPavement,
            self.reactToHorn.defaultSettings.pedestrianDodgeOnPavement,
            function(state)
                self.reactToHorn.settings.pedestrianDodgeOnPavement = state
                self:SaveSettings()
            end)

        nativeSettings.addSelectorString("/react_to_horn/pedestrian_dodge_settings", "Dodge Reaction Intensity",
            "Adjust the intensity of pedestrian reactions to your horn. Higher settings make them dodge from farther away, even when you drive slow",
            self.reactToHorn.pedestrianReactIntensityNames, self.reactToHorn.settings.pedestrianReactIntensity,
            self.reactToHorn.defaultSettings.pedestrianReactIntensity,
            function(value)
                self.reactToHorn.settings.pedestrianReactIntensity = value
                self:SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/pedestrian_react_settings", "Pedestrians React To Horn",
            "When you're NOT on the pavement and honk your horn, pedestrians will react. You can choose the reaction type using the setting below",
            self.reactToHorn.settings.pedestriansReactToHonk,
            self.reactToHorn.defaultSettings.pedestriansReactToHonk,
            function(state)
                self.reactToHorn.settings.pedestriansReactToHonk = state
                self:SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/pedestrian_react_settings", "Crowd Reaction",
            "Chance for the whole crowd to react or for individual NPCs",
            self.reactToHorn.settings.crowdReaction,
            self.reactToHorn.defaultSettings.crowdReaction,
            function(state)
                self.reactToHorn.settings.crowdReaction = state
                self:SaveSettings()
            end)

        nativeSettings.addRangeFloat("/react_to_horn/pedestrian_react_settings", "Reaction Radius",
            "Adjust the radius within which NPCs react to your vehicle's horn", self.reactToHorn
            .minPedestrianReactRadius,
            self.reactToHorn.maxPedestrianReactRadius,
            self.reactToHorn.radiusStep, "%.2f", self.reactToHorn.settings.pedestrianReactRadius,
            self.reactToHorn.defaultSettings.pedestrianReactRadius,
            function(value)
                self.reactToHorn.settings.pedestrianReactRadius = value
                self:SaveSettings()
            end)

        nativeSettings.addSelectorString("/react_to_horn/pedestrian_react_settings", "Config Mode",
            "Control over each type of reaction or simplified",
            self.reactToHorn.reactConfigNames, self.reactToHorn.settings.pedestrianReactMode,
            self.reactToHorn.defaultSettings.pedestrianReactMode,
            function(value)
                if value == 1 then
                    self.reactToHorn.settings.currentPedestrianPreset = "simple"
                else
                    self.reactToHorn.settings.currentPedestrianPreset = "complex"
                end
                self.reactToHorn.settings.pedestrianReactMode = value
                self:SaveSettings()
                self:updatePedestrianUIBasedOnPreset(nativeSettings)
            end)

        self:updatePedestrianUIBasedOnPreset(nativeSettings)

        --[[ nativeSettings.addSelectorString("/react_to_horn/pedestrian_react_settings", "Reaction Type",
            "What type of the reaction should the NPCs have when you honk the horn",
            self.reactToHorn.pedestrianReactTypesNames, self.reactToHorn.settings.pedestrianReactTypeSelectorValue,
            self.reactToHorn.defaultSettings.pedestrianReactTypeSelectorValue,
            function(value)
                local selectedReaction = self.reactToHorn.pedestrianReactTypesNames[value]
                self.reactToHorn.settings.pedestrianReactTypeValue = self.reactToHorn.pedestrianReactTypes
                    [selectedReaction]
                self.reactToHorn.settings.pedestrianReactTypeSelectorValue = value
                self:SaveSettings()
            end)

        nativeSettings.addRangeInt("/react_to_horn/pedestrian_react_settings", "Reaction Probability (%)",
            "The probability for the NPC reaction to happen",
            self.reactToHorn.minProbability, self.reactToHorn.maxProbability, self.reactToHorn.probabilityStep,
            self.reactToHorn.settings.pedestrianReactProbability,
            self.reactToHorn.defaultSettings.pedestrianReactProbability, function(value)
                self.reactToHorn.settings.pedestrianReactProbability = value
                self:SaveSettings()
            end) ]]

        nativeSettings.addSwitch("/react_to_horn/vehicle_react_settings", "Vehicles React To Horn",
            "Enable or Disable vehicles reacting to honk", self.reactToHorn.settings.vehiclesReactToHonk,
            self.reactToHorn.defaultSettings.vehiclesReactToHonk,
            function(state)
                self.reactToHorn.settings.vehiclesReactToHonk = state
                self:SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/vehicle_react_settings", "Police Vehicles React To Horn",
            "Enable or Disable police vehicles reacting to honk", self.reactToHorn.settings.policeVehiclesReactToHonk,
            self.reactToHorn.defaultSettings.policeVehiclesReactToHonk,
            function(state)
                self.reactToHorn.settings.policeVehiclesReactToHonk = state
                self:SaveSettings()
            end)

        nativeSettings.addRangeFloat("/react_to_horn/vehicle_react_settings", "Reaction Radius",
            "Adjust the radius within which vehicle NPCs react to your vehicle's horn",
            self.reactToHorn.minVehicleReactRadius,
            self.reactToHorn.maxVehicleReactRadius,
            self.reactToHorn.radiusStep, "%.2f", self.reactToHorn.settings.vehicleReactRadius,
            self.reactToHorn.defaultSettings.vehicleReactRadius,
            function(value)
                self.reactToHorn.settings.vehicleReactRadius = value
                self:SaveSettings()
            end)

        nativeSettings.addSelectorString("/react_to_horn/vehicle_react_settings", "Config Mode",
            "Control over each type of reaction or simplified",
            self.reactToHorn.reactConfigNames, self.reactToHorn.settings.vehicleReactMode,
            self.reactToHorn.defaultSettings.vehicleReactMode,
            function(value)
                if value == 1 then
                    self.reactToHorn.settings.currentvehiclePreset = "simple"
                else
                    self.reactToHorn.settings.currentvehiclePreset = "complex"
                end
                self.reactToHorn.settings.vehicleReactMode = value
                self:SaveSettings()
                self:updateVehicleUIBasedOnPreset(nativeSettings)
            end)

        self:updateVehicleUIBasedOnPreset(nativeSettings)

        --[[ nativeSettings.addSelectorString("/react_to_horn/vehicle_react_settings", "Reaction Type",
            "What type of the reaction should the Vehicle NPCs have when you honk the horn",
            self.reactToHorn.vehicleReactTypesNames, self.reactToHorn.settings.vehiclesReactTypeSelectorValue,
            self.reactToHorn.defaultSettings.vehiclesReactTypeSelectorValue,
            function(value)
                self.reactToHorn.settings.vehiclesReactTypeSelectorValue = value
                SaveSettings()
            end)


        nativeSettings.addRangeInt("/react_to_horn/vehicle_react_settings", "Reaction Probability (%)",
            "The probability for the vehicle reaction to happen",
            self.reactToHorn.minProbability, self.reactToHorn.maxProbability, self.reactToHorn.probabilityStep,
            self.reactToHorn.settings.vehiclesReactProbability,
            self.reactToHorn.defaultSettings.vehiclesReactProbability, function(value)
                self.reactToHorn.settings.vehiclesReactProbability = value
                SaveSettings()
            end) ]]

        nativeSettings.addSwitch("/react_to_horn/fun", "Fun Enabled",
            "Enable or Disable the fun features", self.reactToHorn.settings.isFunEnabled,
            self.reactToHorn.defaultSettings.isFunEnabled,
            function(state)
                self.reactToHorn.settings.isFunEnabled = state
                self:SaveSettings()
            end)

        nativeSettings.addRangeFloat("/react_to_horn/fun", "Fun Radius",
            "Adjust the radius within which vehicles and NPCs are having fun", self.reactToHorn.minFunRadius,
            self.reactToHorn.maxFunRadius,
            self.reactToHorn.radiusStep, "%.2f", self.reactToHorn.settings.funRadius,
            self.reactToHorn.defaultSettings.funRadius,
            function(value)
                self.reactToHorn.settings.funRadius = value
                self:SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/fun", "Pop Tires on Honk (might crash game)",
            "As the name says. This might crash your game if you spam it!!!",
            self.reactToHorn.settings.popTiresOnHonk,
            self.reactToHorn.defaultSettings.popTiresOnHonk,
            function(state)
                self.reactToHorn.settings.popTiresOnHonk = state
                self:SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/fun", "Vehicles Bounce on Honk",
            "As the name says",
            self.reactToHorn.settings.bounceOnHonk,
            self.reactToHorn.defaultSettings.bounceOnHonk,
            function(state)
                self.reactToHorn.settings.bounceOnHonk = state
                self:SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/fun", "NPCs Die on Honk",
            "As the name says",
            self.reactToHorn.settings.killNPCsOnHonk,
            self.reactToHorn.defaultSettings.killNPCsOnHonk,
            function(state)
                self.reactToHorn.settings.killNPCsOnHonk = state
                self:SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/fun", "NPCs Explode on Honk",
            "As the name says",
            self.reactToHorn.settings.explodeNPCOnHonk,
            self.reactToHorn.defaultSettings.explodeNPCOnHonk,
            function(state)
                self.reactToHorn.settings.explodeNPCOnHonk = state
                self:SaveSettings()
            end)

        nativeSettings.addSwitch("/react_to_horn/fun", "Vehicles Explode on Honk",
            "As the name says",
            self.reactToHorn.settings.explodeVehicleOnHonk,
            self.reactToHorn.defaultSettings.explodeVehicleOnHonk,
            function(state)
                self.reactToHorn.settings.explodeVehicleOnHonk = state
                self:SaveSettings()
            end)
    end
end

function UI:updatePedestrianUIBasedOnPreset(nativeSettings)
    for _, elementID in ipairs(self.currentPedestrianUIElements) do
        nativeSettings.removeOption(elementID)
    end
    self.currentPedestrianUIElements = {}

    local selectedElements = self.pedestrianUIElements[self.reactToHorn.settings.currentPedestrianPreset]

    for _, element in ipairs(selectedElements) do
        if element.type == "selector" then
            local selectorID = nativeSettings.addSelectorString(
                "/react_to_horn/pedestrian_react_settings",
                element.label,
                element.description,
                element.options,
                element.current,
                element.default,
                element.callback
            )
            table.insert(self.currentPedestrianUIElements, selectorID)
        elseif element.type == "slider" then
            local sliderID = nativeSettings.addRangeInt(
                "/react_to_horn/pedestrian_react_settings",
                element.label,
                element.description,
                element.min,
                element.max,
                element.step,
                element.current,
                element.default,
                element.callback
            )
            table.insert(self.currentPedestrianUIElements, sliderID)
        end
    end
end

function UI:updateVehicleUIBasedOnPreset(nativeSettings)
    for _, elementID in ipairs(self.currentVehicleUIElements) do
        nativeSettings.removeOption(elementID)
    end
    self.currentVehicleUIElements = {}

    local selectedElements = self.vehicleUIElements[self.reactToHorn.settings.currentvehiclePreset]

    for _, element in ipairs(selectedElements) do
        if element.type == "selector" then
            local selectorID = nativeSettings.addSelectorString(
                "/react_to_horn/vehicle_react_settings",
                element.label,
                element.description,
                element.options,
                element.current,
                element.default,
                element.callback
            )
            table.insert(self.currentVehicleUIElements, selectorID)
        elseif element.type == "slider" then
            local sliderID = nativeSettings.addRangeInt(
                "/react_to_horn/vehicle_react_settings",
                element.label,
                element.description,
                element.min,
                element.max,
                element.step,
                element.current,
                element.default,
                element.callback
            )
            table.insert(self.currentVehicleUIElements, sliderID)
        end
    end
end

function UI:SaveSettings()
    config.saveFile("config.json", UI.reactToHorn.settings)
end

return UI
