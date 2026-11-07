OUTLINE = OUTLINE or {}

local HighlightSystem = OUTLINE

local FlatHighlightMaterial = Material("models/debug/debugwhite")

HighlightSystem.State = HighlightSystem.State or {}
HighlightSystem.Rules = HighlightSystem.Rules or {}

HighlightSystem.OrderedRules = HighlightSystem.OrderedRules or {}
HighlightSystem.OrderedRulePriorities = HighlightSystem.OrderedRulePriorities or {}
HighlightSystem.KnownPriorities = HighlightSystem.KnownPriorities or {}

HighlightSystem.PriorityBuckets = HighlightSystem.PriorityBuckets or {}
HighlightSystem.PriorityBucketSizes = HighlightSystem.PriorityBucketSizes or {}
HighlightSystem.ActivePriorities = HighlightSystem.ActivePriorities or {}
HighlightSystem.DynamicPriorities = HighlightSystem.DynamicPriorities or {}
HighlightSystem.DynamicPrioritySet = HighlightSystem.DynamicPrioritySet or {}

HighlightSystem.NormalizedEntryPool = HighlightSystem.NormalizedEntryPool or {}
HighlightSystem.NormalizedEntryPoolSize = 0

HighlightSystem.RuleRegistrationSerial = HighlightSystem.RuleRegistrationSerial or 0

HighlightSystem.WinningRawEntriesByKey = HighlightSystem.WinningRawEntriesByKey or {}
HighlightSystem.WinningRulesByKey = HighlightSystem.WinningRulesByKey or {}
HighlightSystem.WinningDistanceSquaredByKey = HighlightSystem.WinningDistanceSquaredByKey or {}
HighlightSystem.WinningPrioritiesByKey = HighlightSystem.WinningPrioritiesByKey or {}
HighlightSystem.WinningRuleOrdersByKey = HighlightSystem.WinningRuleOrdersByKey or {}
HighlightSystem.WinningCandidateOrdersByKey = HighlightSystem.WinningCandidateOrdersByKey or {}
HighlightSystem.ActiveWinningKeys = HighlightSystem.ActiveWinningKeys or {}

OUTLINE_MODE_BOTH = 0
OUTLINE_MODE_VISIBLE = 1
OUTLINE_MODE_CHEAP = 2

OUTLINE_QUALITY_DEFAULT = 0
OUTLINE_QUALITY_AUTO = 1
OUTLINE_QUALITY_LOW = 2

local higlight_quality = GetConVar("fh_highlight_quality") or CreateClientConVar("fh_highlight_quality", "0", true, false, "Highlight Quality: 0 - default, 1 - automatic, 2 - low.", 0, 2)
local FPSMaximumConVar = GetConVar("fps_max")

HighlightSystem.QualityState = HighlightSystem.QualityState or {}

local InitQuality = HighlightSystem.QualityState

InitQuality.mode = OUTLINE_QUALITY_DEFAULT
InitQuality.previous_mode = -1
InitQuality.initialized = false
InitQuality.smoothed_fps = 60
InitQuality.target_fps = 60
InitQuality.auto_low = false
InitQuality.below_since = 0
InitQuality.recovered_since = 0
InitQuality.next_change_time = 0
InitQuality.active_object_count = math.max(0, tonumber(InitQuality.active_object_count) or 0)
InitQuality.active_rule_counts = istable(InitQuality.active_rule_counts) and InitQuality.active_rule_counts or {}
InitQuality.active_rule_objects = istable(InitQuality.active_rule_objects) and InitQuality.active_rule_objects or {}
InitQuality.baseline_rule_counts = istable(InitQuality.baseline_rule_counts) and InitQuality.baseline_rule_counts or {}
InitQuality.baseline_rule_objects = istable(InitQuality.baseline_rule_objects) and InitQuality.baseline_rule_objects or {}
InitQuality.baseline_rule_objects_valid = InitQuality.baseline_rule_objects_valid == true
InitQuality.auto_low_culprit_rules = istable(InitQuality.auto_low_culprit_rules) and InitQuality.auto_low_culprit_rules or {}
InitQuality.auto_low_culprit_objects = istable(InitQuality.auto_low_culprit_objects) and InitQuality.auto_low_culprit_objects or {}
InitQuality.auto_low_culprit_rule_counts = istable(InitQuality.auto_low_culprit_rule_counts) and InitQuality.auto_low_culprit_rule_counts or {}

local AUTO_LOW_MIN_RULE_CONTRIBUTION_FRACTION = 0.1

local scrw = ScrW()
local scrh = ScrH()

local function ClearSequentialTable(sequence)
	for sequenceIndex = #sequence, 1, -1 do
		sequence[sequenceIndex] = nil
	end
end

local function ClearAssociativeTable(dataTable)
	for tableKey in pairs(dataTable) do
		dataTable[tableKey] = nil
	end
end

local function ClearRuleObjectSets(ruleObjectSets)
	for _, objectSet in pairs(ruleObjectSets) do
		if istable(objectSet) then
			ClearAssociativeTable(objectSet)
		end
	end
end

local function GetOrCreateRuleObjectSet(ruleObjectSets, ruleIdentifier)
	local objectSet = ruleObjectSets[ruleIdentifier]

	if not objectSet then
		objectSet = {}
		ruleObjectSets[ruleIdentifier] = objectSet
	end

	return objectSet
end

local function CountObjectSet(objectSet)
	if not istable(objectSet) then
		return 0
	end

	local objectCount = 0

	for _ in pairs(objectSet) do
		objectCount = objectCount + 1
	end

	return objectCount
end

local function CopyRuleObjectSets(sourceSets, destinationSets)
	ClearRuleObjectSets(destinationSets)

	for ruleIdentifier, sourceObjectSet in pairs(sourceSets) do
		if not istable(sourceObjectSet) then
			continue
		end

		local destinationObjectSet = GetOrCreateRuleObjectSet(destinationSets, ruleIdentifier)

		for objectKey, highlightedEntity in pairs(sourceObjectSet) do
			destinationObjectSet[objectKey] = highlightedEntity
		end
	end
end

local function RebuildRuleCountsFromObjects(ruleObjectSets, ruleCounts)
	ClearAssociativeTable(ruleCounts)

	for ruleIdentifier, objectSet in pairs(ruleObjectSets) do
		local objectCount = CountObjectSet(objectSet)

		if objectCount > 0 then
			ruleCounts[ruleIdentifier] = objectCount
		end
	end
end

local function ResetAutoLowRuleLoadState(qualityState)
	ClearAssociativeTable(qualityState.auto_low_culprit_rules)
	ClearRuleObjectSets(qualityState.auto_low_culprit_objects)
	ClearAssociativeTable(qualityState.auto_low_culprit_rule_counts)
end

local function ResetAutoQualityRuleTracking(qualityState)
	ResetAutoLowRuleLoadState(qualityState)
	ClearRuleObjectSets(qualityState.baseline_rule_objects)
	ClearAssociativeTable(qualityState.baseline_rule_counts)
	qualityState.baseline_rule_objects_valid = false
end

local function UpdateHealthyRuleObjectBaseline(qualityState)
	CopyRuleObjectSets(qualityState.active_rule_objects, qualityState.baseline_rule_objects)
	RebuildRuleCountsFromObjects(qualityState.baseline_rule_objects, qualityState.baseline_rule_counts)
	qualityState.baseline_rule_objects_valid = true
end

local function CaptureAutoLowCulpritObjects(qualityState)
	ResetAutoLowRuleLoadState(qualityState)

	if not qualityState.baseline_rule_objects_valid then
		return false
	end

	local activeRuleObjects = qualityState.active_rule_objects
	local baselineRuleObjects = qualityState.baseline_rule_objects
	local newObjectCountsByRule = {}
	local totalNewObjectCount = 0

	for ruleIdentifier, activeObjectSet in pairs(activeRuleObjects) do
		local baselineObjectSet = baselineRuleObjects[ruleIdentifier]
		local newObjectCount = 0

		for objectKey in pairs(activeObjectSet) do
			if baselineObjectSet and baselineObjectSet[objectKey] ~= nil then
				continue
			end

			newObjectCount = newObjectCount + 1
		end

		if newObjectCount <= 0 then
			continue
	end

		newObjectCountsByRule[ruleIdentifier] = newObjectCount
		totalNewObjectCount = totalNewObjectCount + newObjectCount
	end

    if totalNewObjectCount <= 0 then
        return false
    end

	local minimumRuleContribution = math.max(1, math.floor(totalNewObjectCount * AUTO_LOW_MIN_RULE_CONTRIBUTION_FRACTION + 0.5))
	local capturedObjectCount = 0

	for ruleIdentifier, newObjectCount in pairs(newObjectCountsByRule) do
		if newObjectCount < minimumRuleContribution then
			continue
		end

		local activeObjectSet = activeRuleObjects[ruleIdentifier]
		local baselineObjectSet = baselineRuleObjects[ruleIdentifier]
		local culpritObjectSet = GetOrCreateRuleObjectSet(qualityState.auto_low_culprit_objects, ruleIdentifier)

		qualityState.auto_low_culprit_rules[ruleIdentifier] = true

		for objectKey, highlightedEntity in pairs(activeObjectSet) do
			if baselineObjectSet and baselineObjectSet[objectKey] ~= nil then
				continue
			end

			culpritObjectSet[objectKey] = highlightedEntity
			capturedObjectCount = capturedObjectCount + 1
		end
	end

	RebuildRuleCountsFromObjects(qualityState.auto_low_culprit_objects, qualityState.auto_low_culprit_rule_counts)

	return capturedObjectCount > 0
end

local function IsAutoLowCulpritObjectActive(qualityState, ruleIdentifier, objectKey, highlightedEntity)
	local rule = HighlightSystem.Rules[ruleIdentifier]
	local qualityConfiguration = rule and rule.quality or nil
	local objectActiveCallback = qualityConfiguration and qualityConfiguration.is_object_active or nil

	if objectActiveCallback then
		return objectActiveCallback(highlightedEntity, rule, objectKey) == true
	end

	local activeObjectSet = qualityState.active_rule_objects[ruleIdentifier]

	return activeObjectSet and activeObjectSet[objectKey] ~= nil or false
end

local function UpdateAutoLowCulpritObjects(qualityState)
	local activeRuleObjects = qualityState.active_rule_objects
	local baselineRuleObjects = qualityState.baseline_rule_objects
	local culpritRules = qualityState.auto_low_culprit_rules
	local culpritRuleObjects = qualityState.auto_low_culprit_objects
	local culpritRuleCounts = qualityState.auto_low_culprit_rule_counts

	ClearAssociativeTable(culpritRuleCounts)

	local remainingObjectCount = 0

	for ruleIdentifier in pairs(culpritRules) do
		local activeObjectSet = activeRuleObjects[ruleIdentifier]
		local baselineObjectSet = baselineRuleObjects[ruleIdentifier]
		local culpritObjectSet = GetOrCreateRuleObjectSet(culpritRuleObjects, ruleIdentifier)

		if activeObjectSet then
			for objectKey, highlightedEntity in pairs(activeObjectSet) do
				if baselineObjectSet and baselineObjectSet[objectKey] ~= nil then
					continue
				end

				culpritObjectSet[objectKey] = highlightedEntity
			end
		end

		local remainingRuleObjectCount = 0

		for objectKey, highlightedEntity in pairs(culpritObjectSet) do
			if IsAutoLowCulpritObjectActive(qualityState, ruleIdentifier, objectKey, highlightedEntity) then
				remainingRuleObjectCount = remainingRuleObjectCount + 1
				remainingObjectCount = remainingObjectCount + 1
			else
				culpritObjectSet[objectKey] = nil
			end
		end

		if remainingRuleObjectCount > 0 then
			culpritRuleCounts[ruleIdentifier] = remainingRuleObjectCount
		end
	end

	return remainingObjectCount
end

local function GetAutoLowCulpritObjectCount(qualityState)
    local remainingObjectCount = 0

    for _, objectCount in pairs(qualityState.auto_low_culprit_rule_counts) do
        remainingObjectCount = remainingObjectCount + objectCount
    end

    return remainingObjectCount
end

local function IsAutoLowRuleRecoveryBlocked(qualityState)
    return UpdateAutoLowCulpritObjects(qualityState) > 0
end

local function SmoothStep01(value)
    value = math.Clamp(value, 0, 1)
    return value * value * (3 - 2 * value)
end

local function GetLegacyLayerSettings(outlineMode)
    if outlineMode == OUTLINE_MODE_VISIBLE then
        return true, false, true, false
    end

    if outlineMode == OUTLINE_MODE_CHEAP then
        return false, false, true, true
    end

    return true, true, true, true
end

local QualityBooleanSettingNames = {
    "outline_visible",
    "outline_occluded",
    "fill_visible",
    "fill_occluded"
}

local QualityColorSettingNames = {
    "outline_visible_color",
    "outline_occluded_color",
    "fill_visible_color",
    "fill_occluded_color"
}

local QualityNonNegativeSettingNames = {
    "outline_visible_width",
    "outline_occluded_width",
    "outline_visible_min_dist",
    "outline_visible_max_dist",
    "outline_occluded_min_dist",
    "outline_occluded_max_dist",
    "fill_visible_min_dist",
    "fill_visible_max_dist",
    "fill_occluded_min_dist",
    "fill_occluded_max_dist"
}

local QualityAmountSettingNames = {
    "fill_visible_amount",
    "fill_occluded_amount"
}

local function GetAutomaticQualityTargetFPS()
    if not FPSMaximumConVar then
        FPSMaximumConVar = GetConVar("fps_max")
    end

    local maximumFPS = FPSMaximumConVar and FPSMaximumConVar:GetFloat() or 0

    if maximumFPS <= 0 then
        return 60
    end

    return math.Clamp(maximumFPS, 30, 120)
end

local function UpdateHighlightQualityState()
    local qualityState = HighlightSystem.QualityState
    local qualityMode = math.Clamp(higlight_quality:GetInt(), OUTLINE_QUALITY_DEFAULT, OUTLINE_QUALITY_LOW)

    qualityState.mode = qualityMode

    if qualityMode ~= qualityState.previous_mode then
        qualityState.previous_mode = qualityMode
        qualityState.initialized = false
        qualityState.auto_low = false
        qualityState.below_since = 0
        qualityState.recovered_since = 0
        qualityState.next_change_time = 0

        ResetAutoQualityRuleTracking(qualityState)
    end

    if qualityMode ~= OUTLINE_QUALITY_AUTO then
        qualityState.auto_low = false
        qualityState.below_since = 0
        qualityState.recovered_since = 0

        ResetAutoQualityRuleTracking(qualityState)

        return qualityState
    end

    local gameUIVisible = gui.IsGameUIVisible and gui.IsGameUIVisible() or false
    local consoleVisible = gui.IsConsoleVisible and gui.IsConsoleVisible() or false
    local applicationFocused = not system.HasFocus or system.HasFocus()

    if gameUIVisible or consoleVisible or not applicationFocused then
        qualityState.below_since = 0
        qualityState.recovered_since = 0
        return qualityState
    end

    local frameTime = RealFrameTime()

    if frameTime <= 0 then
        return qualityState
    end

    local currentFPS = math.Clamp(1 / math.max(frameTime, 0.001), 1, 500)

    qualityState.target_fps = GetAutomaticQualityTargetFPS()

    local enterLowFPS = math.max(30, qualityState.target_fps * 0.78)
    local recoverFPS = math.max(36, qualityState.target_fps * 0.90)

    if not qualityState.initialized then
        qualityState.initialized = true
        qualityState.smoothed_fps = currentFPS
        qualityState.auto_low = false
        qualityState.below_since = 0
        qualityState.recovered_since = 0

        ResetAutoLowRuleLoadState(qualityState)

        if currentFPS >= recoverFPS then
            UpdateHealthyRuleObjectBaseline(qualityState)
        end

        return qualityState
    end

    local smoothingAmount = math.Clamp(frameTime * 3, 0.015, 0.12)

    qualityState.smoothed_fps = Lerp(smoothingAmount, qualityState.smoothed_fps, currentFPS)

    local currentTime = SysTime()

    if qualityState.auto_low then
        qualityState.below_since = 0

        if IsAutoLowRuleRecoveryBlocked(qualityState) then
            qualityState.recovered_since = 0
            return qualityState
        end

        if qualityState.smoothed_fps >= recoverFPS then
            if qualityState.recovered_since == 0 then
                qualityState.recovered_since = currentTime
            elseif currentTime >= qualityState.next_change_time and currentTime - qualityState.recovered_since >= 2.5 then
                qualityState.auto_low = false
                qualityState.recovered_since = 0
                qualityState.next_change_time = currentTime + 2

                ResetAutoLowRuleLoadState(qualityState)
                UpdateHealthyRuleObjectBaseline(qualityState)
            end
        else
            qualityState.recovered_since = 0
        end

		return qualityState
	end

	qualityState.recovered_since = 0

	local healthyForBaseline = qualityState.below_since == 0 and currentFPS >= recoverFPS and qualityState.smoothed_fps >= recoverFPS

	if healthyForBaseline then
		UpdateHealthyRuleObjectBaseline(qualityState)
	end

	if qualityState.smoothed_fps <= enterLowFPS then
		if qualityState.below_since == 0 then
			qualityState.below_since = currentTime
		elseif currentTime >= qualityState.next_change_time and currentTime - qualityState.below_since >= 1.25 then
			qualityState.auto_low = true
			qualityState.below_since = 0
			qualityState.recovered_since = 0
			qualityState.next_change_time = currentTime + 3

			CaptureAutoLowCulpritObjects(qualityState)
		end
	else
		qualityState.below_since = 0
	end

	return qualityState
end

local function NormalizeQualityProfile(profileData, defaultBuiltInState)
	if profileData == nil or profileData == false then
		return nil
	end
	
	if profileData == true then
		return { builtin = defaultBuiltInState }
	end
	
	if isfunction(profileData) then
		return {
			builtin = defaultBuiltInState,
			apply = profileData
		}
	end
	
	if not istable(profileData) or profileData.enabled == false then
		return nil
	end
	
	local builtInState = defaultBuiltInState
	
	if profileData.builtin ~= nil then
		builtInState = profileData.builtin == true
	elseif profileData.library ~= nil then
		builtInState = profileData.library == true
	end
	
	if profileData.replace == true or profileData.override == true then
		builtInState = false
	end
	
	local settings = istable(profileData.settings) and profileData.settings or profileData
	
	return {
		builtin = builtInState,
		settings = settings,
		apply = isfunction(profileData.apply) and profileData.apply or nil,
		render_max_dist = tonumber(profileData.render_max_dist or settings.render_max_dist),
		low_render_max_dist = tonumber(profileData.low_render_max_dist or settings.low_render_max_dist)
	}
end

local function NormalizeQualityConfiguration(qualityData)
	if qualityData == true then
		qualityData = {
			auto = true,
			low = true
		}
	end

	if not istable(qualityData) then return nil end

	local alwaysApply = qualityData.always_apply

	if not isfunction(alwaysApply) then
		alwaysApply = qualityData.apply_always
	end

	if not isfunction(alwaysApply) then
		alwaysApply = nil
	end

	local isObjectActive = qualityData.is_object_active

	if not isfunction(isObjectActive) then
		isObjectActive = qualityData.object_is_active
	end

	if not isfunction(isObjectActive) then
		isObjectActive = qualityData.is_entity_active
	end

	if not isfunction(isObjectActive) then
		isObjectActive = nil
	end

	local qualityConfiguration = {
		default = NormalizeQualityProfile(qualityData.default, false),
		auto = NormalizeQualityProfile(qualityData.auto, true),
		low = NormalizeQualityProfile(qualityData.low, true),
		always_apply = alwaysApply,
		is_object_active = isObjectActive
	}

	if not qualityConfiguration.default and not qualityConfiguration.auto and not qualityConfiguration.low and not qualityConfiguration.always_apply and not qualityConfiguration.is_object_active then
		return nil
	end

	return qualityConfiguration
end

local function ResolveRuleQuality(rule, globalQualityState, localPlayer, viewOrigin)
	local qualityConfiguration = rule.quality
	
	if not qualityConfiguration then
		return nil, nil
	end
	
	local qualityContext = rule.quality_context
	
	if not qualityContext then
		qualityContext = {}
		rule.quality_context = qualityContext
	end
	
	qualityContext.local_player = localPlayer
	qualityContext.view_origin = viewOrigin
	
	local selectedProfile = qualityConfiguration.default
	local selectedProfileName = "default"
	
	if globalQualityState.mode == OUTLINE_QUALITY_AUTO and qualityConfiguration.auto then
		selectedProfile = qualityConfiguration.auto
		selectedProfileName = "auto"
	elseif globalQualityState.mode == OUTLINE_QUALITY_LOW and qualityConfiguration.low then
		selectedProfile = qualityConfiguration.low
		selectedProfileName = "low"
	end
	
	local automaticProfile = selectedProfileName == "auto"
	local forcedLowProfile = selectedProfileName == "low" and globalQualityState.mode == OUTLINE_QUALITY_LOW
	local automaticLowProfile = automaticProfile and globalQualityState.auto_low
	local effectiveLowProfile = forcedLowProfile or automaticLowProfile
	
	qualityContext.mode = globalQualityState.mode
	qualityContext.profile = selectedProfileName
	qualityContext.default = selectedProfileName == "default"
	qualityContext.auto = automaticProfile
	qualityContext.low = effectiveLowProfile
	qualityContext.auto_low = automaticLowProfile
	qualityContext.forced_low = forcedLowProfile
	qualityContext.fps = globalQualityState.smoothed_fps
	qualityContext.target_fps = globalQualityState.target_fps
	qualityContext.builtin = selectedProfile and selectedProfile.builtin == true or false
	
	local maximumRenderDistance = rule.render_max_dist
	
	if selectedProfile then
		if effectiveLowProfile and selectedProfile.low_render_max_dist then
			maximumRenderDistance = selectedProfile.low_render_max_dist
		elseif selectedProfile.render_max_dist then
			maximumRenderDistance = selectedProfile.render_max_dist
		end
	end
	
	maximumRenderDistance = tonumber(maximumRenderDistance) or 9000
	
	qualityContext.render_max_dist = maximumRenderDistance
	qualityContext.render_max_dist_sqr = maximumRenderDistance > 0 and maximumRenderDistance * maximumRenderDistance or math.huge
	
	return qualityContext, selectedProfile
end

local function ApplyQualitySettings(highlightEntry, settings)
	if not istable(settings) then
		return
	end
	
	local outlineMode = tonumber(settings.mode)
	
	if outlineMode ~= nil then
		local outlineVisible, outlineOccluded, fillVisible, fillOccluded = GetLegacyLayerSettings(outlineMode)
	
		highlightEntry.mode = outlineMode
		highlightEntry.outline_visible = outlineVisible
		highlightEntry.outline_occluded = outlineOccluded
		highlightEntry.fill_visible = fillVisible
		highlightEntry.fill_occluded = fillOccluded
	end
	
	if settings.outline_color ~= nil then
		highlightEntry.outline_color = settings.outline_color
		highlightEntry.outline_visible_color = settings.outline_color
		highlightEntry.outline_occluded_color = settings.outline_color
	end
	
	if settings.fill_color ~= nil then
		highlightEntry.fill_color = settings.fill_color
		highlightEntry.fill_visible_color = settings.fill_color
		highlightEntry.fill_occluded_color = settings.fill_color
	end
	
	local commonOutlineWidth = tonumber(settings.outline_width)
	
	if commonOutlineWidth ~= nil then
		commonOutlineWidth = math.max(0, commonOutlineWidth)
		highlightEntry.outline_visible_width = commonOutlineWidth
		highlightEntry.outline_occluded_width = commonOutlineWidth
	end
	
	local commonOutlineMinimumDistance = tonumber(settings.outline_min_dist)
	
	if commonOutlineMinimumDistance ~= nil then
		commonOutlineMinimumDistance = math.max(0, commonOutlineMinimumDistance)
		highlightEntry.outline_visible_min_dist = commonOutlineMinimumDistance
		highlightEntry.outline_occluded_min_dist = commonOutlineMinimumDistance
	end
	
	local commonOutlineMaximumDistance = tonumber(settings.outline_max_dist)
	
	if commonOutlineMaximumDistance ~= nil then
		commonOutlineMaximumDistance = math.max(0, commonOutlineMaximumDistance)
		highlightEntry.outline_visible_max_dist = commonOutlineMaximumDistance
		highlightEntry.outline_occluded_max_dist = commonOutlineMaximumDistance
	end
	
	local commonFillMinimumDistance = tonumber(settings.fill_min_dist)
	
	if commonFillMinimumDistance ~= nil then
		commonFillMinimumDistance = math.max(0, commonFillMinimumDistance)
		highlightEntry.fill_visible_min_dist = commonFillMinimumDistance
		highlightEntry.fill_occluded_min_dist = commonFillMinimumDistance
	end
	
	local commonFillMaximumDistance = tonumber(settings.fill_max_dist)
	
	if commonFillMaximumDistance ~= nil then
		commonFillMaximumDistance = math.max(0, commonFillMaximumDistance)
		highlightEntry.fill_visible_max_dist = commonFillMaximumDistance
		highlightEntry.fill_occluded_max_dist = commonFillMaximumDistance
	end
	
	if settings.fill_amount ~= nil then
		if settings.fill_amount == false then
			highlightEntry.fill_visible_amount = nil
			highlightEntry.fill_occluded_amount = nil
		else
			local commonFillAmount = tonumber(settings.fill_amount)
	
			if commonFillAmount ~= nil then
				commonFillAmount = math.Clamp(commonFillAmount, 0, 1)
				highlightEntry.fill_visible_amount = commonFillAmount
				highlightEntry.fill_occluded_amount = commonFillAmount
			end
		end
	end
	
	for settingIndex = 1, #QualityBooleanSettingNames do
		local settingName = QualityBooleanSettingNames[settingIndex]
		local settingValue = settings[settingName]
	
		if settingValue ~= nil then
			highlightEntry[settingName] = settingValue == true
		end
	end
	
	for settingIndex = 1, #QualityColorSettingNames do
		local settingName = QualityColorSettingNames[settingIndex]
		local settingValue = settings[settingName]
	
		if settingValue ~= nil then
			highlightEntry[settingName] = settingValue
		end
	end
	
	for settingIndex = 1, #QualityNonNegativeSettingNames do
		local settingName = QualityNonNegativeSettingNames[settingIndex]
		local settingValue = tonumber(settings[settingName])
	
		if settingValue ~= nil then
			highlightEntry[settingName] = math.max(0, settingValue)
		end
	end
	
	for settingIndex = 1, #QualityAmountSettingNames do
		local settingName = QualityAmountSettingNames[settingIndex]
		local settingValue = settings[settingName]
	
		if settingValue == false then
			highlightEntry[settingName] = nil
		elseif settingValue ~= nil then
			local numericValue = tonumber(settingValue)
	
			if numericValue ~= nil then
				highlightEntry[settingName] = math.Clamp(numericValue, 0, 1)
			end
		end
	end
end

local function ApplyBuiltInLowQuality(highlightEntry)
	local visibleOutlineEnabled = highlightEntry.outline_visible and (tonumber(highlightEntry.outline_visible_width) or 0) > 0
	local occludedOutlineEnabled = highlightEntry.outline_occluded and (tonumber(highlightEntry.outline_occluded_width) or 0) > 0
	
	if not visibleOutlineEnabled and not occludedOutlineEnabled then
		return
	end
	
	if visibleOutlineEnabled then
		local replacementColor = highlightEntry.outline_visible_color or highlightEntry.outline_color or color_white
	
		highlightEntry.outline_visible = false
		highlightEntry.fill_visible = true
		highlightEntry.fill_visible_color = replacementColor
		highlightEntry.fill_visible_amount = 1
		highlightEntry.fill_visible_min_dist = 0
		highlightEntry.fill_visible_max_dist = 0
	end
	
	if occludedOutlineEnabled then
		local replacementColor = highlightEntry.outline_occluded_color or highlightEntry.outline_color or color_white
	
		highlightEntry.outline_occluded = false
		highlightEntry.fill_occluded = true
		highlightEntry.fill_occluded_color = replacementColor
		highlightEntry.fill_occluded_amount = 1
		highlightEntry.fill_occluded_min_dist = 0
		highlightEntry.fill_occluded_max_dist = 0
	end
end

local function ApplyRuleQuality(rule, rawEntry, highlightEntry, qualityContext, qualityProfile)
	if not qualityContext then
		return highlightEntry
	end
	
	if qualityProfile then
		if qualityContext.low and qualityProfile.builtin then
			ApplyBuiltInLowQuality(highlightEntry)
		end
	
		if qualityProfile.settings then
			ApplyQualitySettings(highlightEntry, qualityProfile.settings)
		end
	
		if qualityProfile.apply then
			local callbackResult = qualityProfile.apply(highlightEntry, qualityContext, rule, rawEntry)
	
			if callbackResult == false then
				return nil
			end
	
			if istable(callbackResult) then
				ApplyQualitySettings(highlightEntry, callbackResult)
			end
		end
	end
	
	local qualityConfiguration = rule.quality
	local alwaysApply = qualityConfiguration and qualityConfiguration.always_apply or nil
	
	if alwaysApply then
		local callbackResult = alwaysApply(highlightEntry, qualityContext, rule, rawEntry)
	
		if callbackResult == false then
			return nil
		end
	
		if istable(callbackResult) then
			ApplyQualitySettings(highlightEntry, callbackResult)
		end
	end
	
	return highlightEntry
end

function HighlightSystem.GetQualityState(ruleIdentifier)
	if ruleIdentifier == nil then
		return HighlightSystem.QualityState
	end
	
	local rule = HighlightSystem.Rules[ruleIdentifier]
	
	if not rule then
		return nil
	end
	
	return rule.quality_context
end

local function FormatQualityRuleCounts(ruleCounts)
	if not istable(ruleCounts) or table.IsEmpty(ruleCounts) then
		return "none"
	end
	
	local formattedCounts = {}
	
	for ruleIdentifier, objectCount in pairs(ruleCounts) do
		formattedCounts[#formattedCounts + 1] = tostring(ruleIdentifier) .. "=" .. tostring(objectCount)
	end
	
	table.sort(formattedCounts)
	
	return table.concat(formattedCounts, ", ")
end

local function FormatAutoLowCulpritRules(qualityState)
	local culpritRules = qualityState.auto_low_culprit_rules
	
	if not istable(culpritRules) or table.IsEmpty(culpritRules) then
		return "none"
	end
	
	local baselineRuleCounts = qualityState.baseline_rule_counts
	local culpritRuleCounts = qualityState.auto_low_culprit_rule_counts
	local formattedCulprits = {}
	
	for ruleIdentifier in pairs(culpritRules) do
		local baselineCount = baselineRuleCounts[ruleIdentifier] or 0
		local remainingCount = culpritRuleCounts[ruleIdentifier] or 0
	
		formattedCulprits[#formattedCulprits + 1] = tostring(ruleIdentifier) .. "{base=" .. tostring(baselineCount) .. ",remaining=" .. tostring(remainingCount) .. "}"
	end
	
	table.sort(formattedCulprits)
	
	return table.concat(formattedCulprits, ", ")
end

concommand.Add("fh_highlight_quality_status", function()
	local qualityState = HighlightSystem.QualityState
	
	print(
		"[Проверка качества просвета]",
		"mode=" .. tostring(qualityState.mode),
		"fps=" .. string.format("%.1f", qualityState.smoothed_fps or 0),
		"target=" .. string.format("%.1f", qualityState.target_fps or 0),
		"auto_low=" .. tostring(qualityState.auto_low == true),
		"objects=" .. tostring(qualityState.active_object_count or 0)
	)
	
	print("[Активные правила]", FormatQualityRuleCounts(qualityState.active_rule_counts))
	print("[Здоровая база]", FormatQualityRuleCounts(qualityState.baseline_rule_counts))
	print("[Причины auto-low]", FormatAutoLowCulpritRules(qualityState), "remaining_objects=" .. tostring(GetAutoLowCulpritObjectCount(qualityState)))
end)

local function ReadBooleanSetting(settings, settingName, fallbackValue)
	if not istable(settings) then
		return fallbackValue
	end
	
	if settings[settingName] == nil then
		return fallbackValue
	end
	
	return settings[settingName] == true
end

local function ReadNumberSetting(settings, settingName, fallbackValue)
	if not istable(settings) then
		return fallbackValue
	end

	local numericValue = tonumber(settings[settingName])

	if numericValue == nil then
		return fallbackValue
	end

	return numericValue
end

local function GetHighlightViewOrigin(localPlayer)
	local viewEntity = localPlayer:GetViewEntity()

	if IsValid(viewEntity) then
		if viewEntity:IsPlayer() then
			return viewEntity:EyePos()
		end
	
		return viewEntity:GetPos()
	end

	return localPlayer:EyePos()
end

local function GetEntityDistanceSquaredFromView(viewOrigin, highlightedEntity)
	local nearestEntityPoint = highlightedEntity:NearestPoint(viewOrigin)
	return nearestEntityPoint:DistToSqr(viewOrigin)
end

local function IsEntityInsideHighlightViewport(viewOrigin, highlightedEntity, screenWidth, screenHeight)
	if highlightedEntity:IsDormant() then
		return false
	end

	local worldCenter

	if highlightedEntity.WorldSpaceCenter then
		worldCenter = highlightedEntity:WorldSpaceCenter()
	else
		worldCenter = highlightedEntity:LocalToWorld(highlightedEntity:OBBCenter())
	end

	local boundingRadius = math.max(8, tonumber(highlightedEntity:BoundingRadius()) or 8)
	local centerDistanceSquared = worldCenter:DistToSqr(viewOrigin)

	local nearCameraDistance = boundingRadius * 1.5

	if centerDistanceSquared <= nearCameraDistance * nearCameraDistance then
		return true
	end

	local screenPosition = worldCenter:ToScreen()

	if not screenPosition.visible then
		return false
	end

	local projectedDiameter = render.ComputePixelDiameterOfSphere(worldCenter, boundingRadius)
	local projectedRadius = math.max(24, (tonumber(projectedDiameter) or 0) * 0.5)

	return screenPosition.x >= -projectedRadius
		and screenPosition.x <= screenWidth + projectedRadius
		and screenPosition.y >= -projectedRadius
		and screenPosition.y <= screenHeight + projectedRadius
end

local function GetHighlightConflictKey(highlightedEntity)
	if highlightedEntity:IsPlayer() then
		return highlightedEntity
	end

	if highlightedEntity:GetClass() == "pill_costume" and highlightedEntity.GetPillUser then
		local pillUser = highlightedEntity:GetPillUser()
	
		if IsValid(pillUser) then
			return pillUser
		end
	end

	return highlightedEntity
end

local function ClearWinningEntryState()
	local activeWinningKeys = HighlightSystem.ActiveWinningKeys
	local winningRawEntriesByKey = HighlightSystem.WinningRawEntriesByKey
	local winningRulesByKey = HighlightSystem.WinningRulesByKey
	local winningDistanceSquaredByKey = HighlightSystem.WinningDistanceSquaredByKey
	local winningPrioritiesByKey = HighlightSystem.WinningPrioritiesByKey
	local winningRuleOrdersByKey = HighlightSystem.WinningRuleOrdersByKey
	local winningCandidateOrdersByKey = HighlightSystem.WinningCandidateOrdersByKey

	for keyIndex = #activeWinningKeys, 1, -1 do
		local conflictKey = activeWinningKeys[keyIndex]
	
		winningRawEntriesByKey[conflictKey] = nil
		winningRulesByKey[conflictKey] = nil
		winningDistanceSquaredByKey[conflictKey] = nil
		winningPrioritiesByKey[conflictKey] = nil
		winningRuleOrdersByKey[conflictKey] = nil
		winningCandidateOrdersByKey[conflictKey] = nil
		activeWinningKeys[keyIndex] = nil
	end
end

local EmptyHighlightEntrySettings = {}

local function ResolveLayerSetting(entrySettings, entryLayerSettingName, entryCommonSettingName, entryAliasSettingName, rule, ruleLayerSettingName, ruleCommonSettingName, fallbackValue)
	local settingValue = entrySettings[entryLayerSettingName]
	
	if settingValue ~= nil then
		return settingValue
	end
	
	settingValue = entrySettings[entryCommonSettingName]
	
	if settingValue ~= nil then
		return settingValue
	end
	
	if entryAliasSettingName ~= nil then
		settingValue = entrySettings[entryAliasSettingName]
	
		if settingValue ~= nil then
			return settingValue
		end
	end
	
	settingValue = rule[ruleLayerSettingName]
	
	if settingValue ~= nil then
		return settingValue
	end
	
	settingValue = rule[ruleCommonSettingName]
	
	if settingValue ~= nil then
		return settingValue
	end
	
	return fallbackValue
end

local function ResolveLayerNumberSetting(entrySettings, entryLayerSettingName, entryCommonSettingName, rule, ruleLayerSettingName, ruleCommonSettingName, fallbackValue)
	local numericValue = tonumber(entrySettings[entryLayerSettingName])
	
	if numericValue ~= nil then
		return numericValue
	end
	
	numericValue = tonumber(entrySettings[entryCommonSettingName])
	
	if numericValue ~= nil then
		return numericValue
	end
	
	numericValue = tonumber(rule[ruleLayerSettingName])
	
	if numericValue ~= nil then
		return numericValue
	end
	
	numericValue = tonumber(rule[ruleCommonSettingName])
	
	if numericValue ~= nil then
		return numericValue
	end
	
	return fallbackValue
end

function HighlightSystem.NormalizeEntry(rule, rawEntry, normalizedEntry)
	local entrySettings = istable(rawEntry) and rawEntry or EmptyHighlightEntrySettings
	local highlightedEntity = istable(rawEntry) and rawEntry.ent or rawEntry
	
	if not IsValid(highlightedEntity) then
		return nil
	end
	
	normalizedEntry = normalizedEntry or {}
	
	local outlineMode = tonumber(entrySettings.mode)
	
	if outlineMode == nil then
		outlineMode = tonumber(rule.mode) or OUTLINE_MODE_BOTH
	end
	
	local legacyOutlineVisible, legacyOutlineOccluded, legacyFillVisible, legacyFillOccluded = GetLegacyLayerSettings(outlineMode)
	
	local ruleOutlineVisible = rule.outline_visible
	local ruleOutlineOccluded = rule.outline_occluded
	local ruleFillVisible = rule.fill_visible
	local ruleFillOccluded = rule.fill_occluded
	
	if ruleOutlineVisible == nil then
		ruleOutlineVisible = legacyOutlineVisible
	end
	
	if ruleOutlineOccluded == nil then
		ruleOutlineOccluded = legacyOutlineOccluded
	end
	
	if ruleFillVisible == nil then
		ruleFillVisible = legacyFillVisible
	end
	
	if ruleFillOccluded == nil then
		ruleFillOccluded = legacyFillOccluded
	end
	
	if entrySettings.mode ~= nil then
		ruleOutlineVisible = legacyOutlineVisible
		ruleOutlineOccluded = legacyOutlineOccluded
		ruleFillVisible = legacyFillVisible
		ruleFillOccluded = legacyFillOccluded
	end
	
	local outlineColor = entrySettings.outline_color
	
	if outlineColor == nil then
		outlineColor = entrySettings.color
	end
	
	if outlineColor == nil then
		outlineColor = rule.outline_color
	end
	
	if outlineColor == nil then
		outlineColor = color_white
	end
	
	local visibleOutlineColor = ResolveLayerSetting(entrySettings, "outline_visible_color", "outline_color", "color", rule, "outline_visible_color", "outline_color", outlineColor)
	local occludedOutlineColor = ResolveLayerSetting(entrySettings, "outline_occluded_color", "outline_color", "color", rule, "outline_occluded_color", "outline_color", outlineColor)
	
	local fillColor = entrySettings.fill_color
	
	if fillColor == nil then
		fillColor = entrySettings.color
	end
	
	if fillColor == nil then
		fillColor = rule.fill_color
	end
	
	if fillColor == nil then
		fillColor = outlineColor
	end
	
	local visibleFillColor = ResolveLayerSetting(entrySettings, "fill_visible_color", "fill_color", "color", rule, "fill_visible_color", "fill_color", fillColor)
	local occludedFillColor = ResolveLayerSetting(entrySettings, "fill_occluded_color", "fill_color", "color", rule, "fill_occluded_color", "fill_color", fillColor)
	
	local visibleOutlineWidth = math.max(0, ResolveLayerNumberSetting(entrySettings, "outline_visible_width", "outline_width", rule, "outline_visible_width", "outline_width", 0) or 0)
	local occludedOutlineWidth = math.max(0, ResolveLayerNumberSetting(entrySettings, "outline_occluded_width", "outline_width", rule, "outline_occluded_width", "outline_width", 0) or 0)
	
	local visibleOutlineMinDistance = math.max(0, ResolveLayerNumberSetting(entrySettings, "outline_visible_min_dist", "outline_min_dist", rule, "outline_visible_min_dist", "outline_min_dist", 0) or 0)
	local visibleOutlineMaxDistance = math.max(0, ResolveLayerNumberSetting(entrySettings, "outline_visible_max_dist", "outline_max_dist", rule, "outline_visible_max_dist", "outline_max_dist", 0) or 0)
	
	local occludedOutlineMinDistance = math.max(0, ResolveLayerNumberSetting(entrySettings, "outline_occluded_min_dist", "outline_min_dist", rule, "outline_occluded_min_dist", "outline_min_dist", 0) or 0)
	local occludedOutlineMaxDistance = math.max(0, ResolveLayerNumberSetting(entrySettings, "outline_occluded_max_dist", "outline_max_dist", rule, "outline_occluded_max_dist", "outline_max_dist", 0) or 0)
	
	local visibleFillMinDistance = math.max(0, ResolveLayerNumberSetting(entrySettings, "fill_visible_min_dist", "fill_min_dist", rule, "fill_visible_min_dist", "fill_min_dist", 0) or 0)
	local visibleFillMaxDistance = math.max(0, ResolveLayerNumberSetting(entrySettings, "fill_visible_max_dist", "fill_max_dist", rule, "fill_visible_max_dist", "fill_max_dist", 0) or 0)
	
	local occludedFillMinDistance = math.max(0, ResolveLayerNumberSetting(entrySettings, "fill_occluded_min_dist", "fill_min_dist", rule, "fill_occluded_min_dist", "fill_min_dist", 0) or 0)
	local occludedFillMaxDistance = math.max(0, ResolveLayerNumberSetting(entrySettings, "fill_occluded_max_dist", "fill_max_dist", rule, "fill_occluded_max_dist", "fill_max_dist", 0) or 0)
	
	local visibleFillAmount = ResolveLayerNumberSetting(entrySettings, "fill_visible_amount", "fill_amount", rule, "fill_visible_amount", "fill_amount", nil)
	local occludedFillAmount = ResolveLayerNumberSetting(entrySettings, "fill_occluded_amount", "fill_amount", rule, "fill_occluded_amount", "fill_amount", nil)
	
	if visibleFillAmount ~= nil then
		visibleFillAmount = math.Clamp(visibleFillAmount, 0, 1)
	end
	
	if occludedFillAmount ~= nil then
		occludedFillAmount = math.Clamp(occludedFillAmount, 0, 1)
	end
	
	normalizedEntry.ent = highlightedEntity
	normalizedEntry.rule = rule
	normalizedEntry.priority = tonumber(entrySettings.priority) or tonumber(rule.priority) or 0
	normalizedEntry.mode = outlineMode
	
	normalizedEntry.outline_color = outlineColor
	normalizedEntry.outline_visible_color = visibleOutlineColor
	normalizedEntry.outline_occluded_color = occludedOutlineColor
	
	normalizedEntry.fill_color = fillColor
	normalizedEntry.fill_visible_color = visibleFillColor
	normalizedEntry.fill_occluded_color = occludedFillColor
	
	normalizedEntry.outline_visible = ReadBooleanSetting(entrySettings, "outline_visible", ruleOutlineVisible)
	normalizedEntry.outline_occluded = ReadBooleanSetting(entrySettings, "outline_occluded", ruleOutlineOccluded)
	normalizedEntry.fill_visible = ReadBooleanSetting(entrySettings, "fill_visible", ruleFillVisible)
	normalizedEntry.fill_occluded = ReadBooleanSetting(entrySettings, "fill_occluded", ruleFillOccluded)
	
	normalizedEntry.outline_visible_width = visibleOutlineWidth
	normalizedEntry.outline_occluded_width = occludedOutlineWidth
	
	normalizedEntry.outline_visible_min_dist = visibleOutlineMinDistance
	normalizedEntry.outline_visible_max_dist = visibleOutlineMaxDistance
	normalizedEntry.outline_occluded_min_dist = occludedOutlineMinDistance
	normalizedEntry.outline_occluded_max_dist = occludedOutlineMaxDistance
	
	normalizedEntry.fill_visible_min_dist = visibleFillMinDistance
	normalizedEntry.fill_visible_max_dist = visibleFillMaxDistance
	normalizedEntry.fill_occluded_min_dist = occludedFillMinDistance
	normalizedEntry.fill_occluded_max_dist = occludedFillMaxDistance
	
	normalizedEntry.fill_visible_amount = visibleFillAmount
	normalizedEntry.fill_occluded_amount = occludedFillAmount
	
	normalizedEntry.distance = 0
	normalizedEntry.distance_squared = 0
	normalizedEntry.__fh_outline_normalized = true
	normalizedEntry.__fh_outline_rule = rule
	
	return normalizedEntry
end

local function NormalizeEntry(...)
	return HighlightSystem.NormalizeEntry(...)
end

local function IsPreparedHighlightEntry(rule, highlightEntry)
	if not istable(highlightEntry) or not IsValid(highlightEntry.ent) then
		return false
	end
	
	if highlightEntry.__fh_outline_normalized == true then
		return highlightEntry.__fh_outline_rule == rule or highlightEntry.rule == rule
	end
	
	if highlightEntry.rule ~= rule then
		return false
	end
	
	return highlightEntry.outline_visible ~= nil
		and highlightEntry.outline_occluded ~= nil
		and highlightEntry.fill_visible ~= nil
		and highlightEntry.fill_occluded ~= nil
		and highlightEntry.outline_visible_width ~= nil
		and highlightEntry.outline_occluded_width ~= nil
end

local function RebuildRuleCaches()
	local orderedRules = HighlightSystem.OrderedRules
	local orderedPriorities = HighlightSystem.OrderedRulePriorities
	
	ClearSequentialTable(orderedRules)
	ClearSequentialTable(orderedPriorities)
	
	for priority in pairs(HighlightSystem.KnownPriorities) do
		HighlightSystem.KnownPriorities[priority] = nil
	end
	
	for _, rule in pairs(HighlightSystem.Rules) do
		rule.priority = tonumber(rule.priority) or 0
	
		local registrationOrder = tonumber(rule.registration_order)
	
		if registrationOrder == nil then
			HighlightSystem.RuleRegistrationSerial = HighlightSystem.RuleRegistrationSerial + 1
			registrationOrder = HighlightSystem.RuleRegistrationSerial
		elseif registrationOrder > HighlightSystem.RuleRegistrationSerial then
			HighlightSystem.RuleRegistrationSerial = registrationOrder
		end
	
		rule.registration_order = registrationOrder
	
		local maximumRenderDistance = tonumber(rule.render_max_dist) or 9000
	
		rule.render_max_dist = maximumRenderDistance
		rule.render_max_dist_sqr = maximumRenderDistance > 0 and maximumRenderDistance * maximumRenderDistance or math.huge
	
		orderedRules[#orderedRules + 1] = rule
	end
	
	table.sort(orderedRules, function(firstRule, secondRule)
		if firstRule.priority ~= secondRule.priority then
			return firstRule.priority < secondRule.priority
		end
	
		if firstRule.registration_order ~= secondRule.registration_order then
			return firstRule.registration_order < secondRule.registration_order
		end
	
		return tostring(firstRule.id) < tostring(secondRule.id)
	end)
	
	local previousPriority
	
	for ruleIndex = 1, #orderedRules do
		local priority = orderedRules[ruleIndex].priority
	
		if priority ~= previousPriority then
			orderedPriorities[#orderedPriorities + 1] = priority
			HighlightSystem.KnownPriorities[priority] = true
			previousPriority = priority
		end
	end
end

function HighlightSystem.RegisterRule(ruleIdentifier, ruleData)
	HighlightSystem.RuleRegistrationSerial = HighlightSystem.RuleRegistrationSerial + 1
	
	local registrationOrder = HighlightSystem.RuleRegistrationSerial
	local outlineMode = tonumber(ruleData.mode) or OUTLINE_MODE_BOTH
	local maximumRenderDistance = tonumber(ruleData.render_max_dist) or 9000
	local maximumRenderDistanceSquared = maximumRenderDistance > 0 and maximumRenderDistance * maximumRenderDistance or math.huge
	local legacyOutlineVisible, legacyOutlineOccluded, legacyFillVisible, legacyFillOccluded = GetLegacyLayerSettings(outlineMode)
	
	local outlineWidth = math.max(0, tonumber(ruleData.outline_width) or 0)
	local outlineMinimumDistance = math.max(0, tonumber(ruleData.outline_min_dist) or 0)
	local outlineMaximumDistance = math.max(0, tonumber(ruleData.outline_max_dist) or 0)
	
	local fillMinimumDistance = math.max(0, tonumber(ruleData.fill_min_dist) or 0)
	local fillMaximumDistance = math.max(0, tonumber(ruleData.fill_max_dist) or 0)
	
	local commonFillAmount = tonumber(ruleData.fill_amount)
	
	if commonFillAmount ~= nil then
		commonFillAmount = math.Clamp(commonFillAmount, 0, 1)
	end
	
	local visibleFillAmount = tonumber(ruleData.fill_visible_amount)
	
	if visibleFillAmount == nil then
		visibleFillAmount = commonFillAmount
	end
	
	if visibleFillAmount ~= nil then
		visibleFillAmount = math.Clamp(visibleFillAmount, 0, 1)
	end
	
	local occludedFillAmount = tonumber(ruleData.fill_occluded_amount)
	
	if occludedFillAmount == nil then
		occludedFillAmount = commonFillAmount
	end
	
	if occludedFillAmount ~= nil then
		occludedFillAmount = math.Clamp(occludedFillAmount, 0, 1)
	end
	
	local qualityConfiguration = NormalizeQualityConfiguration(ruleData.quality)
	
	HighlightSystem.Rules[ruleIdentifier] = {
		id = ruleIdentifier,
		priority = tonumber(ruleData.priority) or 0,
		registration_order = registrationOrder,
		mode = outlineMode,
	
		render_max_dist = maximumRenderDistance,
		render_max_dist_sqr = maximumRenderDistanceSquared,
	
		outline_color = ruleData.outline_color or color_white,
		outline_visible_color = ruleData.outline_visible_color or ruleData.outline_color or color_white,
		outline_occluded_color = ruleData.outline_occluded_color or ruleData.outline_color or color_white,
	
		fill_color = ruleData.fill_color or ruleData.outline_color or color_white,
		fill_visible_color = ruleData.fill_visible_color or ruleData.fill_color or ruleData.outline_color or color_white,
		fill_occluded_color = ruleData.fill_occluded_color or ruleData.fill_color or ruleData.outline_color or color_white,
	
		outline_width = outlineWidth,
		outline_min_dist = outlineMinimumDistance,
		outline_max_dist = outlineMaximumDistance,
	
		fill_min_dist = fillMinimumDistance,
		fill_max_dist = fillMaximumDistance,
	
		outline_visible = ReadBooleanSetting(ruleData, "outline_visible", legacyOutlineVisible),
		outline_occluded = ReadBooleanSetting(ruleData, "outline_occluded", legacyOutlineOccluded),
		fill_visible = ReadBooleanSetting(ruleData, "fill_visible", legacyFillVisible),
		fill_occluded = ReadBooleanSetting(ruleData, "fill_occluded", legacyFillOccluded),
	
		outline_visible_width = math.max(0, tonumber(ruleData.outline_visible_width) or outlineWidth),
		outline_occluded_width = math.max(0, tonumber(ruleData.outline_occluded_width) or outlineWidth),
	
		outline_visible_min_dist = math.max(0, tonumber(ruleData.outline_visible_min_dist) or outlineMinimumDistance),
		outline_visible_max_dist = math.max(0, tonumber(ruleData.outline_visible_max_dist) or outlineMaximumDistance),
		outline_occluded_min_dist = math.max(0, tonumber(ruleData.outline_occluded_min_dist) or outlineMinimumDistance),
		outline_occluded_max_dist = math.max(0, tonumber(ruleData.outline_occluded_max_dist) or outlineMaximumDistance),
	
		fill_visible_min_dist = math.max(0, tonumber(ruleData.fill_visible_min_dist) or fillMinimumDistance),
		fill_visible_max_dist = math.max(0, tonumber(ruleData.fill_visible_max_dist) or fillMaximumDistance),
		fill_occluded_min_dist = math.max(0, tonumber(ruleData.fill_occluded_min_dist) or fillMinimumDistance),
		fill_occluded_max_dist = math.max(0, tonumber(ruleData.fill_occluded_max_dist) or fillMaximumDistance),
	
		fill_amount = commonFillAmount,
		fill_visible_amount = visibleFillAmount,
		fill_occluded_amount = occludedFillAmount,
	
		quality = qualityConfiguration,
		quality_context = qualityConfiguration and {} or nil,
		collect = ruleData.collect
	}
	
	RebuildRuleCaches()
end

function HighlightSystem.ClearRule(rule)
	HighlightSystem.Rules[rule] = nil
	RebuildRuleCaches()
end

local function ResetTransientCollectionState()
	ClearWinningEntryState()

	for priority, priorityBucket in pairs(HighlightSystem.PriorityBuckets) do
		ClearSequentialTable(priorityBucket)
		HighlightSystem.PriorityBucketSizes[priority] = 0
	end

	ClearSequentialTable(HighlightSystem.ActivePriorities)
	ClearSequentialTable(HighlightSystem.DynamicPriorities)

	for priority in pairs(HighlightSystem.DynamicPrioritySet) do
		HighlightSystem.DynamicPrioritySet[priority] = nil
	end

	for entryIndex = 1, #HighlightSystem.NormalizedEntryPool do
		local highlightEntry = HighlightSystem.NormalizedEntryPool[entryIndex]
	
		if highlightEntry then
			highlightEntry.ent = nil
			highlightEntry.rule = nil
			highlightEntry.__fh_outline_rule = nil
		end
	end

	HighlightSystem.NormalizedEntryPoolSize = 0
end

function HighlightSystem.ClearRules()
	HighlightSystem.Rules = {}
	HighlightSystem.RuleRegistrationSerial = 0

	ResetTransientCollectionState()
	RebuildRuleCaches()
end

local OutlineRenderer = HighlightSystem.Outline or {}

HighlightSystem.Outline = OutlineRenderer

OutlineRenderer.ListSize = 0
OutlineRenderer.RenderEnt = NULL

OutlineRenderer.ThicknessBuckets = OutlineRenderer.ThicknessBuckets or {}
OutlineRenderer.ActiveThicknesses = OutlineRenderer.ActiveThicknesses or {}

OutlineRenderer.StoreTexture = OutlineRenderer.StoreTexture or render.GetScreenEffectTexture(0)
OutlineRenderer.DrawTexture = OutlineRenderer.DrawTexture or render.GetScreenEffectTexture(1)
OutlineRenderer.CopyMat = OutlineRenderer.CopyMat or Material("pp/copy")

OutlineRenderer.OutlineMat = OutlineRenderer.OutlineMat or CreateMaterial("fh_highlight_outline_mat", "UnlitGeneric", {
    ["$basetexture"] = render.GetScreenEffectTexture(1):GetName(),
    ["$ignorez"] = 1,
    ["$translucent"] = 1
})

local STENCIL_OUTLINE_MASK = 0x3F
local STENCIL_PRIORITY_BODY_MASK = 0x40
local STENCIL_HIGHLIGHT_MASK = 0x7F
local STENCIL_VIEWMODEL_MASK = 0x80
local STENCIL_FULL_MASK = 0xFF
local STENCIL_FILL_MASK = STENCIL_OUTLINE_MASK
local STENCIL_FILL_AND_VIEWMODEL_MASK = STENCIL_FILL_MASK + STENCIL_VIEWMODEL_MASK

local nextFillStencilReference = 1

local OUTLINE_VISIBILITY_CODES = {
	["both"] = 0,
	["visible"] = 1,
	["occluded"] = 2
}

local function ClampColorByte(value)
	return math.Clamp(math.floor(tonumber(value) or 255), 0, 255)
end

local function BuildOutlineStyleKey(outlineColor, visibilityType)
	local red = ClampColorByte(outlineColor.r)
	local green = ClampColorByte(outlineColor.g)
	local blue = ClampColorByte(outlineColor.b)
	local alpha = ClampColorByte(outlineColor.a)

	local packedColor =
		red
		+ green * 256
		+ blue * 65536
		+ alpha * 16777216

	local visibilityCode = OUTLINE_VISIBILITY_CODES[visibilityType] or 0

	return packedColor + visibilityCode * 4294967296
end

local function GetOrCreateOutlineThicknessBucket(outlineThickness)
	local thicknessBucket = OutlineRenderer.ThicknessBuckets[outlineThickness]

	if not thicknessBucket then
		thicknessBucket = {
			thickness = outlineThickness,
			style_groups = {},
			style_group_lookup = {},
			style_group_count = 0,
			active = false
		}

		OutlineRenderer.ThicknessBuckets[outlineThickness] = thicknessBucket
	end

	if not thicknessBucket.active then
		thicknessBucket.active = true
		OutlineRenderer.ActiveThicknesses[#OutlineRenderer.ActiveThicknesses + 1] = outlineThickness
	end

	return thicknessBucket
end

local function GetOrCreateOutlineStyleGroup(thicknessBucket, outlineColor, visibilityType)
	local styleKey = BuildOutlineStyleKey(outlineColor, visibilityType)
	local styleGroupIndex = thicknessBucket.style_group_lookup[styleKey]

	if styleGroupIndex then
		return thicknessBucket.style_groups[styleGroupIndex]
	end

	styleGroupIndex = thicknessBucket.style_group_count + 1

	local styleGroup = thicknessBucket.style_groups[styleGroupIndex]

	if not styleGroup then
		styleGroup = {
			entities = {}
		}

		thicknessBucket.style_groups[styleGroupIndex] = styleGroup
	end

	styleGroup.key = styleKey
	styleGroup.color = outlineColor
	styleGroup.visibility = visibilityType
	styleGroup.entity_count = 0

	thicknessBucket.style_group_lookup[styleKey] = styleGroupIndex
	thicknessBucket.style_group_count = styleGroupIndex

	return styleGroup
end

local function ClearStencilBits(stencilWriteMask)
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(stencilWriteMask)
	render.SetStencilTestMask(stencilWriteMask)
	render.SetStencilReferenceValue(0)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilFailOperation(STENCIL_REPLACE)
	render.SetStencilZFailOperation(STENCIL_REPLACE)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.PerformFullScreenStencilOperation()
	render.SetStencilEnable(false)
end

local function EnableViewModelStencilCapture()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(STENCIL_VIEWMODEL_MASK)
	render.SetStencilTestMask(STENCIL_VIEWMODEL_MASK)
	render.SetStencilReferenceValue(STENCIL_VIEWMODEL_MASK)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_REPLACE)
	render.SetStencilPassOperation(STENCIL_REPLACE)
end

local function DisableViewModelStencilCapture()
	render.SetStencilEnable(false)
	render.SetStencilWriteMask(STENCIL_FULL_MASK)
	render.SetStencilTestMask(STENCIL_FULL_MASK)
end

local function EnableViewModelExclusion()
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(0)
	render.SetStencilTestMask(STENCIL_VIEWMODEL_MASK)
	render.SetStencilReferenceValue(0)
	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetStencilPassOperation(STENCIL_KEEP)
end

hook.Add("PreDrawViewModels", "FH_Highlight_BeginViewModelMask", function()
	ClearStencilBits(STENCIL_VIEWMODEL_MASK)
	EnableViewModelStencilCapture()
end)

hook.Add("PreDrawViewModel", "FH_Highlight_CaptureViewModel", function()
	EnableViewModelStencilCapture()
end)

hook.Add("PreDrawPlayerHands", "FH_Highlight_CapturePlayerHands", function()
	EnableViewModelStencilCapture()
end)

hook.Add("PreDrawEffects", "FH_Highlight_EndViewModelMask", function()
	DisableViewModelStencilCapture()
end)

--hook.Remove("PreDrawViewModels", "FH_Highlight_BeginViewModelMask")
--hook.Remove("PreDrawViewModel", "FH_Highlight_CaptureViewModel")
--hook.Remove("PreDrawPlayerHands", "FH_Highlight_CapturePlayerHands")
--hook.Remove("PreDrawEffects", "FH_Highlight_EndViewModelMask")

local function ResetRenderState()
	cam.IgnoreZ(false)

	render.SetStencilEnable(false)
	render.SetStencilWriteMask(STENCIL_FULL_MASK)
	render.SetStencilTestMask(STENCIL_FULL_MASK)
	render.SetStencilReferenceValue(0)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetStencilPassOperation(STENCIL_KEEP)

	render.SuppressEngineLighting(false)
	render.OverrideColorWriteEnable(false, false)
	render.OverrideDepthEnable(false, false)

	if render.OverrideAlphaWriteEnable then
		render.OverrideAlphaWriteEnable(false, false)
	end

	render.MaterialOverride(nil)
	render.SetColorModulation(1, 1, 1)
	render.SetBlend(1)

	OutlineRenderer.RenderEnt = NULL
end

local function ResetOutlineQueue()
	local activeThicknesses = OutlineRenderer.ActiveThicknesses
	local thicknessBuckets = OutlineRenderer.ThicknessBuckets

	for activeIndex = #activeThicknesses, 1, -1 do
		local outlineThickness = activeThicknesses[activeIndex]
		local thicknessBucket = thicknessBuckets[outlineThickness]

		if thicknessBucket then
			for styleGroupIndex = 1, thicknessBucket.style_group_count do
				local styleGroup = thicknessBucket.style_groups[styleGroupIndex]

				if styleGroup then
					for entityIndex = styleGroup.entity_count, 1, -1 do
						styleGroup.entities[entityIndex] = nil
					end

					if styleGroup.key ~= nil then
						thicknessBucket.style_group_lookup[styleGroup.key] = nil
					end

					styleGroup.key = nil
					styleGroup.color = nil
					styleGroup.visibility = nil
					styleGroup.entity_count = 0
				end
			end

			thicknessBucket.style_group_count = 0
			thicknessBucket.active = false
		end

		activeThicknesses[activeIndex] = nil
	end

	OutlineRenderer.ListSize = 0
end

local function AddOutlinePass(highlightedEntity, outlineColor, outlineThickness, visibilityType)
	if OutlineRenderer.ListSize >= 255 then
		return
	end

	if not IsValid(highlightedEntity) then
		return
	end

	if not outlineColor or (outlineColor.a or 255) <= 0 then
		return
	end

	outlineThickness = math.max(0, math.floor((tonumber(outlineThickness) or 0) + 0.5))

	if outlineThickness <= 0 then
		return
	end

	local thicknessBucket = GetOrCreateOutlineThicknessBucket(outlineThickness)
	local styleGroup = GetOrCreateOutlineStyleGroup(thicknessBucket, outlineColor, visibilityType)

	local entityIndex = styleGroup.entity_count + 1

	styleGroup.entities[entityIndex] = highlightedEntity
	styleGroup.entity_count = entityIndex

	OutlineRenderer.ListSize = OutlineRenderer.ListSize + 1
end

local function GetOutlineThicknessForDistance(highlightEntry, distance, visibilityType)
	local maximumThickness
	local minimumDistance
	local maximumDistance
	
	if visibilityType == "visible" then
		maximumThickness = highlightEntry.outline_visible_width
		minimumDistance = highlightEntry.outline_visible_min_dist
		maximumDistance = highlightEntry.outline_visible_max_dist
	else
		maximumThickness = highlightEntry.outline_occluded_width
		minimumDistance = highlightEntry.outline_occluded_min_dist
		maximumDistance = highlightEntry.outline_occluded_max_dist
	end
	
	maximumThickness = math.max(0, tonumber(maximumThickness) or 0)
	minimumDistance = math.max(0, tonumber(minimumDistance) or 0)
	maximumDistance = math.max(0, tonumber(maximumDistance) or 0)
	
	if maximumThickness <= 0 then
		return 0
	end
	
	local roundedMaximumThickness = math.max(0, math.floor(maximumThickness + 0.5))
	
	if distance <= minimumDistance or maximumDistance <= minimumDistance then
		return roundedMaximumThickness
	end
	
	if distance >= maximumDistance then
		return 0
	end
	
	local distanceFraction = (distance - minimumDistance) / (maximumDistance - minimumDistance)
	local currentThickness = maximumThickness * (1 - distanceFraction)
	
	return math.max(0, math.floor(currentThickness + 0.5))
end

local function AddOutlineEntries(entries)
	for entryIndex = 1, #entries do
		local highlightEntry = entries[entryIndex]
		local highlightedEntity = highlightEntry.ent
	
		if not IsValid(highlightedEntity) then
			continue
		end
	
		local visibleOutlineEnabled = highlightEntry.outline_visible and not highlightEntry.suppress_visible_outline
		local occludedOutlineEnabled = highlightEntry.outline_occluded and not highlightEntry.suppress_occluded_outline
	
		if not visibleOutlineEnabled and not occludedOutlineEnabled then
			continue
		end
	
		local distance = highlightEntry.distance or 0
		local visibleThickness = visibleOutlineEnabled and GetOutlineThicknessForDistance(highlightEntry, distance, "visible") or 0
		local occludedThickness = occludedOutlineEnabled and GetOutlineThicknessForDistance(highlightEntry, distance, "occluded") or 0
	
		if visibleOutlineEnabled and occludedOutlineEnabled and visibleThickness > 0 and visibleThickness == occludedThickness and highlightEntry.outline_visible_color == highlightEntry.outline_occluded_color then
			AddOutlinePass(highlightedEntity, highlightEntry.outline_visible_color, visibleThickness, "both")
			continue
		end
	
		if visibleThickness > 0 then
			AddOutlinePass(highlightedEntity, highlightEntry.outline_visible_color or color_white, visibleThickness, "visible")
		end
	
		if occludedThickness > 0 then
			AddOutlinePass(highlightedEntity, highlightEntry.outline_occluded_color or color_white, occludedThickness, "occluded")
		end
	end
end

local function DrawOutlineEntity(highlightedEntity)
	if not IsValid(highlightedEntity) then
		return
	end

	OutlineRenderer.RenderEnt = highlightedEntity
	highlightedEntity:DrawModel()
	OutlineRenderer.RenderEnt = NULL
end

local function DrawOutlineStyleGroup(styleGroup)
	local entities = styleGroup.entities

	for entityIndex = 1, styleGroup.entity_count do
		local highlightedEntity = entities[entityIndex]

		if IsValid(highlightedEntity) then
			DrawOutlineEntity(highlightedEntity)
		end
	end
end

local function BuildPriorityOutlineOcclusionMask(entries)
	ClearStencilBits(STENCIL_PRIORITY_BODY_MASK)

	if not entries or #entries == 0 then
		return
	end

	render.SetStencilEnable(true)
	render.SetStencilWriteMask(STENCIL_PRIORITY_BODY_MASK)
	render.SetStencilTestMask(STENCIL_PRIORITY_BODY_MASK)
	render.SetStencilReferenceValue(STENCIL_PRIORITY_BODY_MASK)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_REPLACE)
	render.SetStencilPassOperation(STENCIL_REPLACE)

	render.OverrideColorWriteEnable(true, false)
	render.OverrideDepthEnable(true, false)

	if render.OverrideAlphaWriteEnable then
		render.OverrideAlphaWriteEnable(true, false)
	end

	render.SuppressEngineLighting(true)
	render.MaterialOverride(FlatHighlightMaterial)
	render.SetBlend(1)

	cam.Start3D()
		cam.IgnoreZ(true)
	
		for entryIndex = 1, #entries do
			local highlightedEntity = entries[entryIndex].ent
	
			if IsValid(highlightedEntity) then
				DrawOutlineEntity(highlightedEntity)
			end
		end
	
		cam.IgnoreZ(false)
	cam.End3D()

	render.OverrideColorWriteEnable(false, false)
	render.OverrideDepthEnable(false, false)

	if render.OverrideAlphaWriteEnable then
		render.OverrideAlphaWriteEnable(false, false)
	end

	render.MaterialOverride(nil)
	render.SuppressEngineLighting(false)
	render.SetBlend(1)

	render.SetStencilEnable(false)
	render.SetStencilWriteMask(STENCIL_FULL_MASK)
	render.SetStencilTestMask(STENCIL_FULL_MASK)
end

local function BuildOutlineStencilMask(styleGroup)
	local visibilityType = styleGroup.visibility

	ClearStencilBits(STENCIL_OUTLINE_MASK)

	render.SetStencilEnable(true)
	render.SetStencilWriteMask(STENCIL_OUTLINE_MASK)
	render.SetStencilTestMask(STENCIL_OUTLINE_MASK)

	render.OverrideColorWriteEnable(true, false)
	render.OverrideDepthEnable(true, false)

	if render.OverrideAlphaWriteEnable then
		render.OverrideAlphaWriteEnable(true, false)
	end

	render.SuppressEngineLighting(true)
	render.SetBlend(1)

	cam.Start3D()
		cam.IgnoreZ(false)

		if visibilityType == "occluded" then
			render.SetStencilReferenceValue(1)
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_REPLACE)
			render.SetStencilPassOperation(STENCIL_KEEP)

			DrawOutlineStyleGroup(styleGroup)

			render.SetStencilReferenceValue(2)
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)
			render.SetStencilPassOperation(STENCIL_REPLACE)

			DrawOutlineStyleGroup(styleGroup)
		elseif visibilityType == "visible" then
			render.SetStencilReferenceValue(1)
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)
			render.SetStencilPassOperation(STENCIL_REPLACE)

			DrawOutlineStyleGroup(styleGroup)
		else
			render.SetStencilReferenceValue(1)
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_REPLACE)
			render.SetStencilPassOperation(STENCIL_REPLACE)

			DrawOutlineStyleGroup(styleGroup)
		end

		cam.IgnoreZ(false)
	cam.End3D()

	render.OverrideColorWriteEnable(false, false)
	render.OverrideDepthEnable(false, false)

	if render.OverrideAlphaWriteEnable then
		render.OverrideAlphaWriteEnable(false, false)
	end

	render.SuppressEngineLighting(false)
	render.SetBlend(1)

	render.SetStencilWriteMask(STENCIL_FULL_MASK)
	render.SetStencilTestMask(STENCIL_FULL_MASK)

	return 1
end

local function RenderOutlineQueue(priorityEntries)
	if OutlineRenderer.ListSize == 0 then
		return
	end

	local activeThicknesses = OutlineRenderer.ActiveThicknesses

	if #activeThicknesses == 0 then
		ResetOutlineQueue()
		return
	end

	BuildPriorityOutlineOcclusionMask(priorityEntries)

	if #activeThicknesses > 1 then
		table.sort(activeThicknesses)
	end

	local activeRenderTarget = render.GetRenderTarget()

	for activeThicknessIndex = 1, #activeThicknesses do
		local outlineThickness = activeThicknesses[activeThicknessIndex]
		local thicknessBucket = OutlineRenderer.ThicknessBuckets[outlineThickness]

		if not thicknessBucket or thicknessBucket.style_group_count <= 0 then
			continue
		end

		render.CopyRenderTargetToTexture(OutlineRenderer.StoreTexture)

		render.Clear(0, 0, 0, 0, false, false)

		for styleGroupIndex = 1, thicknessBucket.style_group_count do
			local styleGroup = thicknessBucket.style_groups[styleGroupIndex]

			if not styleGroup or styleGroup.entity_count <= 0 then
				continue
			end

			local stencilReference = BuildOutlineStencilMask(styleGroup)

			render.SetStencilEnable(true)
			render.SetStencilWriteMask(0)
			render.SetStencilTestMask(STENCIL_OUTLINE_MASK)
			render.SetStencilReferenceValue(stencilReference)
			render.SetStencilCompareFunction(STENCIL_EQUAL)
			render.SetStencilFailOperation(STENCIL_KEEP)
			render.SetStencilZFailOperation(STENCIL_KEEP)
			render.SetStencilPassOperation(STENCIL_KEEP)

			local outlineColor = styleGroup.color or color_white

			render.ClearBuffersObeyStencil(
				outlineColor.r,
				outlineColor.g,
				outlineColor.b,
				outlineColor.a or 255,
				false
			)

			render.SetStencilEnable(false)
		end

		render.CopyRenderTargetToTexture(OutlineRenderer.DrawTexture)
		render.SetRenderTarget(activeRenderTarget)

		OutlineRenderer.CopyMat:SetTexture("$basetexture", OutlineRenderer.StoreTexture)

		render.SetMaterial(OutlineRenderer.CopyMat)
		render.SetBlend(1)
		render.DrawScreenQuad()

		render.SetStencilEnable(true)
		render.SetStencilWriteMask(0)
		render.SetStencilTestMask(STENCIL_FULL_MASK)
		render.SetStencilReferenceValue(0)
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.SetStencilPassOperation(STENCIL_KEEP)

		OutlineRenderer.OutlineMat:SetTexture("$basetexture", OutlineRenderer.DrawTexture)

		render.SetMaterial(OutlineRenderer.OutlineMat)
		render.SetBlend(1)

		render.DrawScreenQuadEx(-outlineThickness, 0, scrw, scrh)
		render.DrawScreenQuadEx(outlineThickness, 0, scrw, scrh)
		render.DrawScreenQuadEx(0, -outlineThickness, scrw, scrh)
		render.DrawScreenQuadEx(0, outlineThickness, scrw, scrh)

		ResetRenderState()
	end

	render.SetRenderTarget(activeRenderTarget)

	ResetRenderState()
	ResetOutlineQueue()
end

local function GetFillAmountForDistance(highlightEntry, distance, visibilityType)
	local forcedFillAmount
	local minimumDistance
	local maximumDistance

	if visibilityType == "visible" then
		forcedFillAmount = highlightEntry.fill_visible_amount
		minimumDistance = highlightEntry.fill_visible_min_dist
		maximumDistance = highlightEntry.fill_visible_max_dist
	else
		forcedFillAmount = highlightEntry.fill_occluded_amount
		minimumDistance = highlightEntry.fill_occluded_min_dist
		maximumDistance = highlightEntry.fill_occluded_max_dist
	end

	if forcedFillAmount ~= nil then
		return math.Clamp(forcedFillAmount, 0, 1)
	end

	if highlightEntry.mode == OUTLINE_MODE_CHEAP then
		return 1
	end

	minimumDistance = math.max(0, tonumber(minimumDistance) or 0)
	maximumDistance = math.max(0, tonumber(maximumDistance) or 0)

	if maximumDistance <= minimumDistance or distance <= minimumDistance then
		return 0
	end

	if distance >= maximumDistance then
		return 1
	end

	local distanceFraction = (distance - minimumDistance) / (maximumDistance - minimumDistance)

	return SmoothStep01(distanceFraction)
end

local function DrawFillEntity(highlightedEntity)
	if not IsValid(highlightedEntity) then
		return
	end

	OutlineRenderer.RenderEnt = highlightedEntity
	highlightedEntity:DrawModel()
	OutlineRenderer.RenderEnt = NULL
end

local function GetFillAlpha(fillColor, fillAmount)
	local colorAlpha = fillColor.a or 255
	local normalizedAmount = math.Clamp(fillAmount, 0, 1)

	return math.Clamp(math.floor(colorAlpha * normalizedAmount + 0.5), 0, 255)
end

local function IsFillFullyOpaque(fillColor, fillAmount)
	return fillAmount >= 1 and (fillColor.a or 255) >= 255
end

local function BeginFillStencilBatch()
	ClearStencilBits(STENCIL_FILL_MASK)
	nextFillStencilReference = 1
end

local function AcquireFillStencilReference()
	if nextFillStencilReference > STENCIL_FILL_MASK then
		ClearStencilBits(STENCIL_FILL_MASK)
		nextFillStencilReference = 1
	end

	local stencilReference = nextFillStencilReference
	nextFillStencilReference = nextFillStencilReference + 1

	return stencilReference
end

local function BeginFillMask(stencilReference)
	render.SetStencilEnable(true)
	render.SetStencilWriteMask(STENCIL_FILL_MASK)
	render.SetStencilTestMask(STENCIL_FILL_MASK)

	render.SetStencilReferenceValue(stencilReference)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetStencilPassOperation(STENCIL_REPLACE)

	render.OverrideColorWriteEnable(true, false)
	render.OverrideDepthEnable(true, false)

	if render.OverrideAlphaWriteEnable then
		render.OverrideAlphaWriteEnable(true, false)
	end

	render.SuppressEngineLighting(true)
	render.MaterialOverride(FlatHighlightMaterial)

	render.SetColorModulation(1, 1, 1)
	render.SetBlend(1)
end

local function FinishFillMask()
	cam.IgnoreZ(false)

	render.OverrideColorWriteEnable(false, false)
	render.OverrideDepthEnable(false, false)

	if render.OverrideAlphaWriteEnable then
		render.OverrideAlphaWriteEnable(false, false)
	end

	render.MaterialOverride(nil)
	render.SuppressEngineLighting(false)

	render.SetColorModulation(1, 1, 1)
	render.SetBlend(1)
end

local function DrawFillColorFromStencil(stencilReference, fillColor, fillAmount)
	if fillAmount <= 0 then return end

	local fillAlpha = GetFillAlpha(fillColor, fillAmount)
	if fillAlpha <= 0 then return end

	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)

	cam.Start2D()
		render.SetStencilEnable(true)
		render.SetStencilWriteMask(0)
		render.SetStencilTestMask(STENCIL_FILL_AND_VIEWMODEL_MASK)
		render.SetStencilReferenceValue(stencilReference)
		render.SetStencilCompareFunction(STENCIL_EQUAL)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.SetStencilPassOperation(STENCIL_KEEP)

		surface.SetAlphaMultiplier(1)
		surface.SetDrawColor(fillColor.r, fillColor.g, fillColor.b, fillAlpha)
		surface.DrawRect(0, 0, scrw, scrh)

		render.SetStencilEnable(false)
	cam.End2D()

	surface.SetAlphaMultiplier(1)
	surface.SetDrawColor(255, 255, 255, 255)

	render.SetStencilWriteMask(STENCIL_FULL_MASK)
	render.SetStencilTestMask(STENCIL_FULL_MASK)
	render.SetStencilReferenceValue(0)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetStencilPassOperation(STENCIL_KEEP)
end

local function DrawVisibleFill(highlightedEntity, fillColor, fillAmount)
	local stencilReference = AcquireFillStencilReference()

	BeginFillMask(stencilReference)

	cam.Start3D()
		cam.IgnoreZ(false)
		DrawFillEntity(highlightedEntity)
	cam.End3D()

	FinishFillMask()
	DrawFillColorFromStencil(stencilReference, fillColor, fillAmount)
end

local function DrawCompleteFill(highlightedEntity, fillColor, fillAmount)
	local stencilReference = AcquireFillStencilReference()

	BeginFillMask(stencilReference)

	cam.Start3D()
		cam.IgnoreZ(true)
		DrawFillEntity(highlightedEntity)
	cam.End3D()

	FinishFillMask()
	DrawFillColorFromStencil(stencilReference, fillColor, fillAmount)
end

local function DrawOccludedFill(highlightedEntity, fillColor, fillAmount)
	local stencilReference = AcquireFillStencilReference()

	BeginFillMask(stencilReference)

	cam.Start3D()
		cam.IgnoreZ(true)
		DrawFillEntity(highlightedEntity)
		cam.IgnoreZ(false)
		render.SetStencilReferenceValue(0)
		render.SetStencilCompareFunction(STENCIL_ALWAYS)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilZFailOperation(STENCIL_KEEP)
		render.SetStencilPassOperation(STENCIL_REPLACE)
		DrawFillEntity(highlightedEntity)
	cam.End3D()

	FinishFillMask()
	DrawFillColorFromStencil(stencilReference, fillColor, fillAmount)
end

local function DrawFillEntries(entries)
	if not entries or #entries == 0 then
		return
	end

	BeginFillStencilBatch()

	for entryIndex = 1, #entries do
		local highlightEntry = entries[entryIndex]

		highlightEntry.suppress_visible_outline = false
		highlightEntry.suppress_occluded_outline = false

		local highlightedEntity = highlightEntry.ent

		if not IsValid(highlightedEntity) then
			continue
		end

		local distance = highlightEntry.distance or 0

		local visibleFillAmount = highlightEntry.fill_visible
			and GetFillAmountForDistance(highlightEntry, distance, "visible")
			or 0

		local occludedFillAmount = highlightEntry.fill_occluded
			and GetFillAmountForDistance(highlightEntry, distance, "occluded")
			or 0

		if highlightEntry.fill_visible
			and highlightEntry.fill_occluded
			and visibleFillAmount > 0
			and math.abs(visibleFillAmount - occludedFillAmount) <= 0.001
			and highlightEntry.fill_visible_color == highlightEntry.fill_occluded_color then

			local completeFillColor = highlightEntry.fill_visible_color or color_white

			if IsFillFullyOpaque(completeFillColor, visibleFillAmount) then
				highlightEntry.suppress_visible_outline = true
				highlightEntry.suppress_occluded_outline = true
			end

			DrawCompleteFill(highlightedEntity, completeFillColor, visibleFillAmount)
			continue
		end

		if visibleFillAmount > 0 then
			local visibleFillColor = highlightEntry.fill_visible_color or color_white

			if IsFillFullyOpaque(visibleFillColor, visibleFillAmount) then
				highlightEntry.suppress_visible_outline = true
			end

			DrawVisibleFill(highlightedEntity, visibleFillColor, visibleFillAmount)
		end

		if occludedFillAmount > 0 then
			local occludedFillColor = highlightEntry.fill_occluded_color or color_white
			DrawOccludedFill(highlightedEntity, occludedFillColor, occludedFillAmount)
		end
	end

	ResetRenderState()
end

local function BuildPriorityBuckets(localPlayer, viewOrigin, globalQualityState)
	local priorityBuckets = HighlightSystem.PriorityBuckets
	local priorityBucketSizes = HighlightSystem.PriorityBucketSizes

	local activeRenderTarget = render.GetRenderTarget()
	local shouldCullOutsideViewport = activeRenderTarget == nil

	local activePriorities = HighlightSystem.ActivePriorities
	local dynamicPriorities = HighlightSystem.DynamicPriorities
	local dynamicPrioritySet = HighlightSystem.DynamicPrioritySet
	local activeHighlightObjectCount = 0
	local activeRuleCounts = globalQualityState.active_rule_counts
	local activeRuleObjects = globalQualityState.active_rule_objects

	ClearAssociativeTable(activeRuleCounts)
	ClearRuleObjectSets(activeRuleObjects)

	for activeIndex = #activePriorities, 1, -1 do
		local priority = activePriorities[activeIndex]
		local priorityBucket = priorityBuckets[priority]
		local previousBucketSize = priorityBucketSizes[priority] or 0
	
		if priorityBucket then
			for entryIndex = previousBucketSize, 1, -1 do
				priorityBucket[entryIndex] = nil
			end
		end
	
		priorityBucketSizes[priority] = 0
		activePriorities[activeIndex] = nil
	end

	for dynamicIndex = #dynamicPriorities, 1, -1 do
		local priority = dynamicPriorities[dynamicIndex]
	
		dynamicPrioritySet[priority] = nil
		dynamicPriorities[dynamicIndex] = nil
	end

	ClearWinningEntryState()

	HighlightSystem.NormalizedEntryPoolSize = 0

	local orderedRules = HighlightSystem.OrderedRules
	local normalizedEntryPool = HighlightSystem.NormalizedEntryPool

	local winningRawEntriesByKey = HighlightSystem.WinningRawEntriesByKey
	local winningRulesByKey = HighlightSystem.WinningRulesByKey
	local winningDistanceSquaredByKey = HighlightSystem.WinningDistanceSquaredByKey
	local winningPrioritiesByKey = HighlightSystem.WinningPrioritiesByKey
	local winningRuleOrdersByKey = HighlightSystem.WinningRuleOrdersByKey
	local winningCandidateOrdersByKey = HighlightSystem.WinningCandidateOrdersByKey
	local activeWinningKeys = HighlightSystem.ActiveWinningKeys
	
	local candidateOrder = 0
	
	for ruleIndex = 1, #orderedRules do
		local rule = orderedRules[ruleIndex]
	
		if not isfunction(rule.collect) then
			continue
		end
	
		local qualityContext
	
		if rule.quality then
			qualityContext = ResolveRuleQuality(rule, globalQualityState, localPlayer, viewOrigin)
		end
	
		local collectedEntries = rule.collect(localPlayer, rule, viewOrigin, qualityContext)
	
		if not collectedEntries or #collectedEntries == 0 then
			continue
		end
	
		local maximumRenderDistanceSquared = qualityContext and qualityContext.render_max_dist_sqr or rule.render_max_dist_sqr or math.huge
		local baseMaximumRenderDistanceSquared = rule.render_max_dist_sqr or math.huge
		local ruleRegistrationOrder = tonumber(rule.registration_order) or 0
	
		local trackedRuleIdentifier
		local trackedRuleObjectSet
	
		if rule.quality and rule.quality.auto then
			trackedRuleIdentifier = rule.id or tostring(rule)
			trackedRuleObjectSet = GetOrCreateRuleObjectSet(activeRuleObjects, trackedRuleIdentifier)
		end
	
		for rawEntryIndex = 1, #collectedEntries do
			local rawEntry = collectedEntries[rawEntryIndex]
			local rawEntity = istable(rawEntry) and rawEntry.ent or rawEntry
	
			if not IsValid(rawEntity) then
				continue
			end
	
			local conflictKey = GetHighlightConflictKey(rawEntity)
			local distanceSquared = GetEntityDistanceSquaredFromView(viewOrigin, rawEntity)
	
			if trackedRuleObjectSet and distanceSquared <= baseMaximumRenderDistanceSquared and trackedRuleObjectSet[conflictKey] == nil then
				trackedRuleObjectSet[conflictKey] = rawEntity
				activeRuleCounts[trackedRuleIdentifier] = (activeRuleCounts[trackedRuleIdentifier] or 0) + 1
			end
	
			if distanceSquared > maximumRenderDistanceSquared then
				continue
			end

			if shouldCullOutsideViewport and not IsEntityInsideHighlightViewport(viewOrigin, rawEntity, scrw, scrh) then
				continue
			end

			candidateOrder = candidateOrder + 1
	
			local candidatePriority = istable(rawEntry) and tonumber(rawEntry.priority) or nil
	
			if candidatePriority == nil then
				candidatePriority = tonumber(rule.priority) or 0
			end
	
			local currentWinningRawEntry = winningRawEntriesByKey[conflictKey]
			local shouldReplaceWinner = currentWinningRawEntry == nil
	
			if not shouldReplaceWinner then
				local currentWinningPriority = winningPrioritiesByKey[conflictKey] or 0
				local currentWinningRuleOrder = winningRuleOrdersByKey[conflictKey] or 0
				local currentWinningCandidateOrder = winningCandidateOrdersByKey[conflictKey] or 0
	
				if candidatePriority > currentWinningPriority then
					shouldReplaceWinner = true
				elseif candidatePriority == currentWinningPriority then
					if ruleRegistrationOrder > currentWinningRuleOrder then
						shouldReplaceWinner = true
					elseif ruleRegistrationOrder == currentWinningRuleOrder and candidateOrder > currentWinningCandidateOrder then
						shouldReplaceWinner = true
					end
				end
			end
	
			if not shouldReplaceWinner then
				continue
			end
	
			if currentWinningRawEntry == nil then
				activeWinningKeys[#activeWinningKeys + 1] = conflictKey
			end
	
			winningRawEntriesByKey[conflictKey] = rawEntry
			winningRulesByKey[conflictKey] = rule
			winningDistanceSquaredByKey[conflictKey] = distanceSquared
			winningPrioritiesByKey[conflictKey] = candidatePriority
			winningRuleOrdersByKey[conflictKey] = ruleRegistrationOrder
			winningCandidateOrdersByKey[conflictKey] = candidateOrder
		end
	end
	
	for winningKeyIndex = 1, #activeWinningKeys do
		local conflictKey = activeWinningKeys[winningKeyIndex]
		local rawEntry = winningRawEntriesByKey[conflictKey]
		local rule = winningRulesByKey[conflictKey]
		local distanceSquared = winningDistanceSquaredByKey[conflictKey]
		local priority = winningPrioritiesByKey[conflictKey]
	
		if not rawEntry or not rule or distanceSquared == nil or priority == nil then
			continue
		end
	
		local qualityContext
		local qualityProfile
	
		if rule.quality then
			qualityContext, qualityProfile = ResolveRuleQuality(rule, globalQualityState, localPlayer, viewOrigin)
		end
	
		local highlightEntry
	
		if not rule.quality and IsPreparedHighlightEntry(rule, rawEntry) then
			highlightEntry = rawEntry
		else
			local normalizedPoolIndex = HighlightSystem.NormalizedEntryPoolSize + 1
	
			highlightEntry = normalizedEntryPool[normalizedPoolIndex]
	
			if not highlightEntry then
				highlightEntry = {}
				normalizedEntryPool[normalizedPoolIndex] = highlightEntry
			end
	
			highlightEntry = NormalizeEntry(rule, rawEntry, highlightEntry)
	
			if not highlightEntry then
				continue
			end
	
			HighlightSystem.NormalizedEntryPoolSize = normalizedPoolIndex
		end
	
		highlightEntry.priority = priority
		highlightEntry.distance_squared = distanceSquared
		highlightEntry.distance = math.sqrt(distanceSquared)
	
		if qualityContext then
			highlightEntry = ApplyRuleQuality(rule, rawEntry, highlightEntry, qualityContext, qualityProfile)
	
			if not highlightEntry then
				continue
			end
		end
	
		highlightEntry.priority = priority
		activeHighlightObjectCount = activeHighlightObjectCount + 1
	
		local priorityBucket = priorityBuckets[priority]
	
		if not priorityBucket then
			priorityBucket = {}
			priorityBuckets[priority] = priorityBucket
		end
	
		local priorityBucketSize = (priorityBucketSizes[priority] or 0) + 1
	
		priorityBucket[priorityBucketSize] = highlightEntry
		priorityBucketSizes[priority] = priorityBucketSize
	
		if not HighlightSystem.KnownPriorities[priority] and not dynamicPrioritySet[priority] then
			dynamicPrioritySet[priority] = true
			dynamicPriorities[#dynamicPriorities + 1] = priority
		end
	end
	
	if #dynamicPriorities > 1 then
		table.sort(dynamicPriorities)
	end
	
	local knownPriorities = HighlightSystem.OrderedRulePriorities
	local knownPriorityIndex = 1
	local dynamicPriorityIndex = 1
	local activePriorityCount = 0
	
	while true do
		while knownPriorityIndex <= #knownPriorities do
			local knownPriority = knownPriorities[knownPriorityIndex]
	
			if (priorityBucketSizes[knownPriority] or 0) > 0 then
				break
			end
	
			knownPriorityIndex = knownPriorityIndex + 1
		end
	
		while dynamicPriorityIndex <= #dynamicPriorities do
			local dynamicPriority = dynamicPriorities[dynamicPriorityIndex]
	
			if (priorityBucketSizes[dynamicPriority] or 0) > 0 then
				break
			end
	
			dynamicPriorityIndex = dynamicPriorityIndex + 1
		end
	
		local knownPriority = knownPriorities[knownPriorityIndex]
		local dynamicPriority = dynamicPriorities[dynamicPriorityIndex]

		if knownPriority == nil and dynamicPriority == nil then
			break
		end

		activePriorityCount = activePriorityCount + 1

		if dynamicPriority == nil or (knownPriority ~= nil and knownPriority < dynamicPriority) then
			activePriorities[activePriorityCount] = knownPriority
			knownPriorityIndex = knownPriorityIndex + 1
		else
			activePriorities[activePriorityCount] = dynamicPriority
			dynamicPriorityIndex = dynamicPriorityIndex + 1
		end
	end

	globalQualityState.active_object_count = activeHighlightObjectCount

	return activePriorities, priorityBuckets
end

ResetTransientCollectionState()
RebuildRuleCaches()

local cachedLocalPlayer

hook.Add("PostDrawEffects", "HighlightDraw", function()
	if not IsValid(cachedLocalPlayer) then
		cachedLocalPlayer = LocalPlayer()
	end

	if not IsValid(cachedLocalPlayer) then
		return
	end
	
	local activeRenderTarget = render.GetRenderTarget()
	
	if not activeRenderTarget then
		scrw = ScrW()
		scrh = ScrH()
	end

	ResetRenderState()
	hook.Run("FH_PreHighlightRender", cachedLocalPlayer, activeRenderTarget)
	ResetRenderState()

	local globalQualityState = UpdateHighlightQualityState()
	local viewOrigin = GetHighlightViewOrigin(cachedLocalPlayer)
	local orderedPriorities, entriesByPriority = BuildPriorityBuckets(cachedLocalPlayer, viewOrigin, globalQualityState)

	for priorityIndex = 1, #orderedPriorities do
		local priority = orderedPriorities[priorityIndex]
		local priorityEntries = entriesByPriority[priority]

		if priorityEntries and #priorityEntries > 0 then
			DrawFillEntries(priorityEntries)
			AddOutlineEntries(priorityEntries)
			RenderOutlineQueue(priorityEntries)
		end
	end

	ClearStencilBits(STENCIL_HIGHLIGHT_MASK)
	ResetRenderState()
end)

OUTLINE = HighlightSystem