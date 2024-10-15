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
                label = "Complex Slider 1",
                description = "First slider for complex mode",
                min = 0,
                max = 100,
                step = 1,
                current = 1,
                default = 30,
                callback = function(value)
                    print("Complex slider 3 value: ", value)
                    -- Add any logic here for handling changes to this slider
                end
            },
            {
                type = "slider",
                label = "Complex Slider 2",
                description = "Second slider for complex mode",
                min = 0,
                max = 100,
                step = 1,
                current = 1,
                default = 60,
                callback = function(value)
                    print("Complex slider 3 value: ", value)
                    -- Add any logic here for handling changes to this slider
                end
            },
            {
                type = "slider",
                label = "Complex Slider 3",
                description = "Third slider for complex mode",
                min = 0,
                max = 100,
                step = 1,
                current = 1,
                default = 90,
                callback = function(value)
                    print("Complex slider 3 value: ", value)
                    -- Add any logic here for handling changes to this slider
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
                options = self.reactToHorn.vehicleReactTimeoutNames,
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
                    self:HandleMinMaxTimeout()
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
                    self:HandleMinMaxTimeout()
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Honk Back Probability (%)",
                description = "The probability for the honk back reaction to happen",
                min = 0,
                max = self.reactToHorn.complexDefines.vehicle.maxHonkBackProb,
                step = 1,
                current = self.reactToHorn.settings.complex.vehicle.honkBackProbability,
                default = self.reactToHorn.defaultSettings.complex.vehicle.honkBackProbability,
                callback = function(value)
                    self.reactToHorn.settings.complex.vehicle.honkBackProbability = value
                    self:CalculateRemainingPercentage("honkBack")
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Panic Probability (%)",
                description = "The probability for the panic reaction to happen",
                min = 0,
                max = self.reactToHorn.complexDefines.vehicle.maxPanicProb,
                step = 1,
                current = self.reactToHorn.settings.complex.vehicle.panicProbability,
                default = self.reactToHorn.defaultSettings.complex.vehicle.panicProbability,
                callback = function(value)
                    self.reactToHorn.settings.complex.vehicle.panicProbability = value
                    self:CalculateRemainingPercentage("panic")
                    self:SaveSettings()
                end
            },
            {
                type = "slider",
                label = "Verbal Probability (%)",
                description = "The probability for the verbal reaction to happen",
                min = 0,
                max = self.reactToHorn.complexDefines.vehicle.maxVerbalProb,
                step = 1,
                current = self.reactToHorn.settings.complex.vehicle.verbalProbability,
                default = self.reactToHorn.defaultSettings.complex.vehicle.verbalProbability,
                callback = function(value)
                    self.reactToHorn.settings.complex.vehicle.verbalProbability = value
                    self:CalculateRemainingPercentage("verbal")
                    self:SaveSettings()
                end
            }
        }
    }
end

function UI:HandleMinMaxTimeout()
    if self.isUpdatingTimeouts then
        print("Already updating. Returning.")
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
            print("Updated")
            self.isUpdatingTimeouts = false
            self:updateVehicleUIBasedOnPreset(nativeSettings)
        end)
    end
end

function UI:CalculateRemainingPercentage(changedType)
    local maxProb = 100

    -- Get current probabilities
    local verbalProb = self.reactToHorn.settings.complex.vehicle.verbalProbability
    local panicProb = self.reactToHorn.settings.complex.vehicle.panicProbability
    local honkBackProb = self.reactToHorn.settings.complex.vehicle.honkBackProbability

    -- Get the slider that has been modified
    local modifiedProb = self.reactToHorn.settings.complex.vehicle[changedType .. "Probability"]

    -- Calculate the total probability after modification
    local totalProb = verbalProb + panicProb + honkBackProb

    print("Is Updating Probabilities.")
    -- Only redistribute if the total exceeds 100%
    if totalProb > maxProb then
        print("Total probabilities exceed 100")
        -- Calculate the remaining percentage (maxProb - modified probability)
        local remainder = maxProb - modifiedProb

        -- List other probabilities that need to be adjusted
        local probabilities = {
            verbal = verbalProb,
            panic = panicProb,
            honkBack = honkBackProb
        }

        -- Remove the modified one from the adjustment list
        probabilities[changedType] = nil

        -- Get the total of remaining (non-modified) probabilities
        local remainingProb = 0
        for _, prob in pairs(probabilities) do
            remainingProb = remainingProb + prob
        end

        -- Adjust the remaining probabilities proportionally if remainingProb > 0
        if remainingProb > 0 then
            for key, prob in pairs(probabilities) do
                local newProb = (prob / remainingProb) * remainder
                -- Round the new probability
                self.reactToHorn.settings.complex.vehicle[key .. "Probability"] = math.floor(newProb)
            end
        end
    end

    self:InitializeDynamicElements()
    print("Adjusted Verbal Probability: ", self.reactToHorn.settings.complex.vehicle.verbalProbability)
    print("Adjusted Panic Probability: ", self.reactToHorn.settings.complex.vehicle.panicProbability)
    print("Adjusted HonkBack Probability: ", self.reactToHorn.settings.complex.vehicle.honkBackProbability)
    self:SaveSettings()

    if self.isUpdatingProbs then
        print("Already updating. Returning.")
        return
    end

    self.isUpdatingProbs = true

    local nativeSettings = GetMod("nativeSettings")
    ---@diagnostic disable-next-line: missing-parameter
    Cron.After(2, function()
        print("Updated")
        self.isUpdatingProbs = false
        --nativeSettings.refresh()
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
            self.reactToHorn.settings.pedestrianReactToHonk,
            self.reactToHorn.defaultSettings.pedestrianReactToHonk,
            function(state)
                self.reactToHorn.settings.pedestrianReactToHonk = state
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
            self.reactToHorn.pedestrianReactModeNames, self.reactToHorn.settings.pedestrianReactMode,
            self.reactToHorn.defaultSettings.pedestrianReactMode,
            function(value)
                if value == 1 then
                    print("preset simple")
                    self.reactToHorn.settings.currentPedestrianPreset = "simple"
                else
                    print("preset complex")
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
            self.reactToHorn.pedestrianReactModeNames, self.reactToHorn.settings.vehicleReactMode,
            self.reactToHorn.defaultSettings.vehicleReactMode,
            function(value)
                if value == 1 then
                    print("vehicle preset simple")
                    self.reactToHorn.settings.currentvehiclePreset = "simple"
                else
                    print("vehicle preset complex")
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
    print("PLM")
    -- Remove previous dynamically inserted UI elements
    for _, elementID in ipairs(self.currentPedestrianUIElements) do
        nativeSettings.removeOption(elementID)
    end
    self.currentPedestrianUIElements = {}

    -- Get the elements for the current preset
    local selectedElements = self.pedestrianUIElements[self.reactToHorn.settings.currentPedestrianPreset]

    -- Add elements dynamically
    for _, element in ipairs(selectedElements) do
        if element.type == "selector" then
            -- Add selector with callback from pedestrianUIElements table
            local selectorID = nativeSettings.addSelectorString(
                "/react_to_horn/pedestrian_react_settings",
                element.label,
                element.description,
                element.options,
                element.current,
                element.default,
                element.callback -- Use the callback from the pedestrianUIElements table
            )
            table.insert(self.currentPedestrianUIElements, selectorID)
        elseif element.type == "slider" then
            -- Add slider with callback from pedestrianUIElements table
            local sliderID = nativeSettings.addRangeInt(
                "/react_to_horn/pedestrian_react_settings",
                element.label,
                element.description,
                element.min,
                element.max,
                element.step,
                element.current,
                element.default,
                element.callback -- Use the callback from the pedestrianUIElements table
            )
            table.insert(self.currentPedestrianUIElements, sliderID)
        end
    end
end

function UI:updateVehicleUIBasedOnPreset(nativeSettings)
    -- Remove previous dynamically inserted UI elements
    for _, elementID in ipairs(self.currentVehicleUIElements) do
        nativeSettings.removeOption(elementID)
    end
    self.currentVehicleUIElements = {}

    -- Get the elements for the current preset
    local selectedElements = self.vehicleUIElements[self.reactToHorn.settings.currentvehiclePreset]

    -- Add elements dynamically
    for _, element in ipairs(selectedElements) do
        if element.type == "selector" then
            -- Add selector with callback from pedestrianUIElements table
            local selectorID = nativeSettings.addSelectorString(
                "/react_to_horn/vehicle_react_settings",
                element.label,
                element.description,
                element.options,
                element.current,
                element.default,
                element.callback -- Use the callback from the pedestrianUIElements table
            )
            table.insert(self.currentVehicleUIElements, selectorID)
        elseif element.type == "slider" then
            -- Add slider with callback from pedestrianUIElements table
            local sliderID = nativeSettings.addRangeInt(
                "/react_to_horn/vehicle_react_settings",
                element.label,
                element.description,
                element.min,
                element.max,
                element.step,
                element.current,
                element.default,
                element.callback -- Use the callback from the pedestrianUIElements table
            )
            table.insert(self.currentVehicleUIElements, sliderID)
        end
    end
    print("Update function ran")
end

function UI:SaveSettings()
    config.saveFile("config.json", UI.reactToHorn.settings)
end

return UI
