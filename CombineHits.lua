-- CombineHits addon (Fury Warrior Focused)
local addon = {}
addon.trackedAbilitiesByName = {} -- Keyed by Spell Name
addon.activeSequences = {}        -- Queue/Dictionary keyed by unique abilityID for non-special abilities
addon.nextAbilityID = 1           -- Counter for unique IDs
addon.hasWhirlwindBuff = false
addon.currentSpec = nil -- Tracked to ensure we only run for Fury

-- **Ability Definitions (Fury Only)**
-- We still need *a* representative ID, primarily for the icon.
local ABILITY_INFO = {
    -- Fury
    ["Rampage"]         = { iconId = 490,    isSpecial = true, handler = "HandleRampage", specs = {"Fury"} },
    ["Raging Blow"]     = { iconId = 85288,  isSpecial = true, handler = "HandleRagingBlow", specs = {"Fury"} },
    ["Execute"]         = { iconId = 5308,   isSpecial = true, handler = "HandleExecute", specs = {"Fury"} },
    ["Execute Off-Hand"] = { iconId = 5308,   isSpecial = true, handler = "HandleExecute", specs = {"Fury"} },
    ["Bloodthirst"]     = { iconId = 23881,  isSpecial = false, specs = {"Fury"} },
    ["Thunder Clap"]    = { iconId = 6343,   isSpecial = false, specs = {"Fury"} },
    ["Onslaught"]       = { iconId = 315720, isSpecial = false, specs = {"Fury"} },
    ["Odyn's Fury"]     = { iconId = 385059, isSpecial = true, handler = "HandleOdynsFury", specs = {"Fury"} },
    ["Thunderous Roar"] = { iconId = 384318, isSpecial = true, handler = "HandleThunderousRoar", specs = {"Fury"} },
    ["Slam"]            = { iconId = 1464,   isSpecial = false, specs = {"Fury"} }, -- Shared, kept for Fury filler potential
    ["Bladestorm"]      = { iconId = 227847, isSpecial = true, handler = "HandleBladestorm", specs = {"Fury"} },
    ["Ravager"]         = { iconId = 228920, isSpecial = true, handler = "HandleRavager", specs = {"Fury"} },
    ["Thunder Blast"]   = { iconId = 435222, isSpecial = true, handler = "HandleThunderBlast", specs = {"Fury"} },
    ["Lightning Strike"] = { iconId = 435222, isSpecial = true, handler = "HandleThunderBlast", specs = {"Fury"} },
    ["Lightning Strike Ground Current"] = { iconId = 435222, isSpecial = true, handler = "HandleThunderBlast", specs = {"Fury"} },
}

-- **Special Ability Tables (Fury Context)**
-- These define mechanics via specific known IDs used *inside* the handlers.
local THUNDEROUS_ROAR = {
    NAME = "Thunderous Roar",
    CAST_ID = 384318, DOT_ID = 397364, active = false, targets = {},
    totalDamage = 0, startTime = 0, DURATION = 10, TALENT_DURATION = 12, TALENT_ID = 384969, NODE_ID = 90358, hasCrit = false
}
local RAVAGER = {
    NAME = "Ravager",
    CAST_ID = 228920, DAMAGE_ID = 156287, active = false, totalDamage = 0,
    startTime = 0, DURATION = 11, hasCrit = false, displayTimer = nil
}
local ODYNS_FURY = {
    NAME = "Odyn's Fury",
    CAST_ID = 385059, DAMAGE_IDS = { [385060]=true, [385061]=true, [385062]=true },
    active = false, targets = {}, totalDamage = 0, startTime = 0, DURATION = 5, displayTimer = nil, hasCrit = false
}
local THUNDER_BLAST = {
    NAME = "Thunder Blast",
    BUFF_ID = 435615, CAST_ID = 435222, PRIMARY_DAMAGE_IDS = { [435222]=true, [436793]=true },
    SECONDARY_DAMAGE_IDS = { [435791]=true, [460670]=true }, active = false,
    totalDamage = 0, startTime = 0, DURATION = .8, hasCrit = false, displayTimer = nil, primaryHit = false
}
local BLADESTORM = {
    NAME = "Bladestorm",
    -- Fury-centric IDs
    CAST_ID = 227847, DAMAGE_IDS = { [50622]=true, [95738]=true }, active = false,
    totalDamage = 0, startTime = 0, DURATION = 4, hasCrit = false, displayTimer = nil
}
local EXECUTE = {
    NAME = "Execute",
    CAST_ID = 5308,
    DAMAGE_IDS = { [5308]=true, [163558]=true, [280849]=true }, -- Main hit, off-hand, and actual damage ID
    active = false,
    targets = {},
    totalDamage = 0,
    startTime = 0,
    DURATION = 0.5,
    displayTimer = nil,
    hasCrit = false
}
local RAGING_BLOW = {
    NAME = "Raging Blow",
    CAST_ID = 85288,
    DAMAGE_IDS = { [85288]=true, [96103]=true, [85384]=true }, -- Main hit and both secondary hits
    active = false,
    targets = {},
    totalDamage = 0,
    startTime = 0,
    DURATION = 0.5,
    displayTimer = nil,
    hasCrit = false
}

-- Add Rampage special ability table (after other ability tables like ODYNS_FURY)
local RAMPAGE = {
    NAME = "Rampage",
    CAST_ID = 184367,
    DAMAGE_IDS = { [184707]=true, [184709]=true, [201364]=true, [201363]=true, [85384]=true }, -- All Rampage hit IDs
    active = false,
    targets = {},
    totalDamage = 0,
    startTime = 0,
    DURATION = 0.8,
    displayTimer = nil,
    hasCrit = false
}

-- **Initialize Saved Variables**
function addon:Init()
    CombineHitsDB = CombineHitsDB or {}
    for k, v in pairs(self.defaults) do
        if CombineHitsDB[k] == nil then CombineHitsDB[k] = v end
    end
    if not CombineHitsDB.framePosition then CombineHitsDB.framePosition = {} end
    if not CombineHitsDB.framePosition.point then CombineHitsDB.framePosition.point = self.defaults.framePosition.point end
    if CombineHitsDB.framePosition.x == nil then CombineHitsDB.framePosition.x = self.defaults.framePosition.x end
    if CombineHitsDB.framePosition.y == nil then CombineHitsDB.framePosition.y = self.defaults.framePosition.y end
    if not CombineHitsDB.textColor then CombineHitsDB.textColor = self.defaults.textColor end
    if not CombineHitsDB.critColor then CombineHitsDB.critColor = self.defaults.critColor end
    if not CombineHitsDB.blacklistedSpells then CombineHitsDB.blacklistedSpells = self.defaults.blacklistedSpells end
    -- Removed leaderboard init
    if CombineHitsDB.isLocked == nil then CombineHitsDB.isLocked = self.defaults.isLocked end
    if CombineHitsDB.frameVisible == nil then CombineHitsDB.frameVisible = self.defaults.frameVisible end
    if CombineHitsDB.debugMode == nil then CombineHitsDB.debugMode = self.defaults.debugMode end
    if CombineHitsDB.combineWindow == nil then CombineHitsDB.combineWindow = self.defaults.combineWindow end
end

addon.defaults = {
    framePosition = { x = 0, y = 0, point = "CENTER" },
    maxDisplayed = 4,
    fadeTime = 3,
    frameWidth = 150,
    frameHeight = 80,
    frameAlpha = 0.9,
    frameVisible = true,
    textColor = { r = 1, g = 1, b = 1 },
    critColor = { r = 1, g = 0.5, b = 0 },
    blacklistedSpells = {},
    combineWindow = 0.5,
    -- Removed leaderboard default
    isLocked = false,
    debugMode = false
}

-- **Initialize Abilities**
function addon:InitializeAbilities()
    self.trackedAbilitiesByName = {} -- Clear previous data
    local missingIcons = {}
    local _, class = UnitClass("player")

    -- Only populate tracked abilities if the player is a Warrior (spec check happens later)
    if class ~= "WARRIOR" then
        self:DebugPrint("Player is not a Warrior. Skipping ability initialization.")
        return
    end

    for name, info in pairs(ABILITY_INFO) do
        -- We only care about Fury abilities defined in ABILITY_INFO now
        local iconSpellId = info.iconId
        local spellInfo = C_Spell.GetSpellInfo(iconSpellId)

        if spellInfo and spellInfo.iconID then
            self.trackedAbilitiesByName[name] = {
                name = name,
                iconSpellId = iconSpellId,
                isSpecial = info.isSpecial,
                handler = info.handler,
                specs = info.specs -- Keep specs info for potential future use, but logic only uses Fury
            }
            self:DebugPrint("Initialized Fury Ability:", name, "(Icon ID:", iconSpellId, ", Special:", tostring(info.isSpecial), ")")
        else
            -- Fallback: Try getting info from name directly
            spellInfo = C_Spell.GetSpellInfo(name)
            if spellInfo and spellInfo.spellID and spellInfo.iconID then
                 self.trackedAbilitiesByName[name] = {
                    name = name,
                    iconSpellId = spellInfo.spellID,
                    isSpecial = info.isSpecial,
                    handler = info.handler,
                    specs = info.specs
                 }
                 self:DebugPrint("Initialized Fury Ability (Fallback ID):", name, "(Icon ID:", spellInfo.spellID, ", Special:", tostring(info.isSpecial), ")")
            else
                 table.insert(missingIcons, name .. " (Tried ID: " .. tostring(iconSpellId) .. ")")
                  self.trackedAbilitiesByName[name] = {
                    name = name,
                    iconSpellId = nil, -- No valid icon ID found
                    isSpecial = info.isSpecial,
                    handler = info.handler,
                    specs = info.specs
                 }
            end
        end
    end

    if #missingIcons > 0 then
        print("|cxFFFF8000CombineHits Warning:|r Could not find valid spell/icon info for:", table.concat(missingIcons, ", "))
    end
end


-- Generate Unique ID
function addon:GenerateAbilityID()
    local id = addon.nextAbilityID
    addon.nextAbilityID = addon.nextAbilityID + 1
    return id
end

-- Create Main Frame, Update Frame Appearance, Create Display Frames, Get Font
function addon:CreateMainFrame()
    local frame = CreateFrame("Frame", "CombineHitsMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(CombineHitsDB.frameWidth, CombineHitsDB.frameHeight)
    frame:SetPoint(CombineHitsDB.framePosition.point, UIParent, CombineHitsDB.framePosition.point, CombineHitsDB.framePosition.x, CombineHitsDB.framePosition.y)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(not CombineHitsDB.isLocked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        CombineHitsDB.framePosition.point = point
        CombineHitsDB.framePosition.x = x
        CombineHitsDB.framePosition.y = y
        addon:DebugPrint("Frame position saved:", point, x, y)
    end)
    local lockButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    lockButton:SetSize(32, 32)
    lockButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    lockButton:SetNormalTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
    lockButton:SetPushedTexture("Interface\\Buttons\\LockButton-Unlocked-Down")
    lockButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    lockButton:SetScript("OnClick", function()
        CombineHitsDB.isLocked = not CombineHitsDB.isLocked
        addon:UpdateFrameAppearance(frame)
        print("CombineHits frame " .. (CombineHitsDB.isLocked and "locked" or "unlocked"))
    end)
    frame.lockButton = lockButton
    addon:UpdateFrameAppearance(frame)
    return frame
end

function addon:UpdateFrameAppearance(frame)
    if CombineHitsDB.isLocked then
        frame:SetBackdrop(nil)
        frame.lockButton:Hide()
        frame:EnableMouse(false)
    else
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background", tile = true, tileSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0, 0, 0, CombineHitsDB.frameAlpha)
        frame.lockButton:Show()
        frame:EnableMouse(true)
    end
end

function addon:CreateDisplayFrames()
    addon.displayFrames = {}
    for i = 1, CombineHitsDB.maxDisplayed do
        local frame = CreateFrame("Frame", "CombineHitsDisplayFrame"..i, addon.mainFrame)
        frame:SetSize(CombineHitsDB.frameWidth - 20, 30)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", frame, "LEFT", 5, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local text = frame:CreateFontString(nil, "OVERLAY")
        text:SetFont(addon:GetFont(), 18, "OUTLINE")
        text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        text:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
        text:SetJustifyH("LEFT")
        text:SetTextColor(CombineHitsDB.textColor.r, CombineHitsDB.textColor.g, CombineHitsDB.textColor.b)
        if i == 1 then
            frame:SetPoint("BOTTOMLEFT", addon.mainFrame, "BOTTOMLEFT", 10, 10)
        else
            frame:SetPoint("BOTTOMLEFT", addon.displayFrames[i-1], "TOPLEFT", 0, 5)
        end
        frame:SetAlpha(0)
        frame.icon = icon
        frame.text = text
        frame.active = false
        frame.fadeStart = 0
        frame.fadeTimer = nil
        frame.currentSequence = nil
        table.insert(addon.displayFrames, frame)
    end
end

function addon:GetFont()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM:IsValid("font", "Expressway") then
        return LSM:Fetch("font", "Expressway")
    end
    return "Fonts\\FRIZQT__.TTF"
end


-- **Combat Log Event Handler (REVISED ROUTING + FURY CHECK)**
function addon:OnCombatLogEvent(...)
    -- *** ADDED: Exit immediately if not Fury spec ***
    if self.currentSpec ~= "Fury" then return end

    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical = CombatLogGetCurrentEventInfo()
    local now = GetTime()

    if sourceGUID ~= UnitGUID("player") then return end

    -- Primary Lookup by Spell Name (Only contains Fury abilities now)
    local abilityInfo = self.trackedAbilitiesByName[spellName]

    if abilityInfo then
        -- Route to Special Handler if applicable
        if abilityInfo.isSpecial and abilityInfo.handler then
            self[abilityInfo.handler](self, eventType, destGUID, spellId, amount, critical)
             if eventType ~= "SPELL_CAST_SUCCESS" then
                 return -- Special handler managed this non-cast event.
             end
        end

        -- Handle Non-Special Abilities OR Casts (Queue System)
        if eventType == "SPELL_CAST_SUCCESS" then
            if not abilityInfo.isSpecial then
                local abilityID = addon:GenerateAbilityID()
                addon.activeSequences[abilityID] = {
                    abilityID = abilityID,
                    name = abilityInfo.name,
                    iconSpellId = abilityInfo.iconSpellId,
                    damage = 0,
                    hasCrit = false,
                    startTime = now,
                    resolved = false,
                    whirlwindActive = addon.hasWhirlwindBuff
                }
                addon:DebugPrint(string.format(
                    "[%d] Cast Start (Non-Special): %s",
                    abilityID, abilityInfo.name
                ))
                C_Timer.After(CombineHitsDB.combineWindow, function()
                    addon:ResolveAbility(abilityID)
                end)
            end
        elseif eventType == "SPELL_DAMAGE" then
            local bestMatchID = nil
            local latestStartTime = 0
            for id, sequence in pairs(addon.activeSequences) do
                if not sequence.resolved and sequence.name == spellName and (now - sequence.startTime) <= (CombineHitsDB.combineWindow + 0.2) then
                    if sequence.startTime > latestStartTime then
                        latestStartTime = sequence.startTime
                        bestMatchID = id
                    end
                end
            end

            if bestMatchID then
                local sequence = addon.activeSequences[bestMatchID]
                local oldDamage = sequence.damage
                sequence.damage = sequence.damage + (amount or 0)
                sequence.hasCrit = sequence.hasCrit or critical
                addon:DebugPrint(string.format(
                    "[%d] Damage Update: %s (+%d = %d, Crit: %s)",
                    bestMatchID, sequence.name, amount or 0, sequence.damage, tostring(critical)
                ))
            end
        end
    end
end


-- **Resolve Ability**
function addon:ResolveAbility(abilityID)
    local sequence = addon.activeSequences[abilityID]
    if sequence and not sequence.resolved then
        sequence.resolved = true
        addon:DebugPrint(string.format("[%d] Resolve Triggered: %s (Damage: %d)", abilityID, sequence.name, sequence.damage))
        if sequence.damage > 0 then
            addon:DisplayHit(sequence)
        end
        addon.activeSequences[abilityID] = nil
    end
end

-- **Unit Aura Event Handler (FURY CHECK)**
function addon:OnUnitAura(unit)
    -- *** ADDED: Check unit and spec ***
    if unit ~= "player" or self.currentSpec ~= "Fury" then return end

    -- Check specifically for Whirlwind buff for Fury
    addon.hasWhirlwindBuff = AuraUtil.FindAuraByName("Whirlwind", "player", "HELPFUL") ~= nil
    -- Can add other Fury-specific aura checks here if needed
end

-- **Display Hit (Uses iconSpellId, No Leaderboard)**
function addon:DisplayHit(sequence)
    if not sequence or sequence.damage <= 0 then
        addon:DebugPrint("DisplayHit skipped: Invalid sequence or zero damage.")
        return
    end

    -- Use sequence.name for debug, sequence.iconSpellId for icon
    addon:DebugPrint(string.format(
        "Displaying Hit: %s (IconID: %s, Damage: %d, Crit: %s)",
        sequence.name, tostring(sequence.iconSpellId or "N/A"), sequence.damage, tostring(sequence.hasCrit)
    ))

    -- Shift existing frames
    for i = #addon.displayFrames, 2, -1 do
        local currentFrame = addon.displayFrames[i]
        local prevFrame = addon.displayFrames[i-1]
        if prevFrame.active then
            currentFrame.currentSequence = prevFrame.currentSequence
            currentFrame.icon:SetTexture(prevFrame.icon:GetTexture())
            currentFrame.text:SetText(prevFrame.text:GetText())
            currentFrame.text:SetTextColor(prevFrame.text:GetTextColor())
            currentFrame.active = true
            currentFrame.fadeStart = prevFrame.fadeStart
            if currentFrame.fadeTimer then currentFrame.fadeTimer:Cancel() end
            local elapsed = GetTime() - currentFrame.fadeStart
            local remainingFadeDelay = math.max(0, CombineHitsDB.fadeTime - elapsed)
            if remainingFadeDelay > 0 then
                 currentFrame.fadeTimer = C_Timer.NewTimer(remainingFadeDelay, function() addon:FadeOut(currentFrame) end)
                 currentFrame:SetAlpha(prevFrame:GetAlpha())
            else
                 local fadeOutDuration = 0.3
                 local alreadyFadedAmount = math.min(1, (elapsed - CombineHitsDB.fadeTime) / fadeOutDuration)
                 local remainingFadeOutTime = fadeOutDuration * (1 - alreadyFadedAmount)
                 if remainingFadeOutTime > 0 then
                     UIFrameFadeOut(currentFrame, remainingFadeOutTime, currentFrame:GetAlpha(), 0)
                     currentFrame.fadeTimer = C_Timer.NewTimer(remainingFadeOutTime, function() addon:ClearFrame(currentFrame) end)
                 else
                     addon:ClearFrame(currentFrame)
                 end
            end
        else
            addon:ClearFrame(currentFrame)
        end
    end

    -- Update the first frame
    local targetFrame = addon.displayFrames[1]
    if targetFrame.fadeTimer then targetFrame.fadeTimer:Cancel() end
    targetFrame:SetAlpha(0)
    targetFrame.currentSequence = sequence
    targetFrame.active = true
    targetFrame.fadeStart = GetTime()

    -- Set Icon using iconSpellId
    local iconTexture = 134400 -- Default Icon (Question Mark)
    if sequence.iconSpellId then
        local spellInfo = C_Spell.GetSpellInfo(sequence.iconSpellId)
        if spellInfo and spellInfo.iconID then
            iconTexture = spellInfo.iconID
        end
    end
    targetFrame.icon:SetTexture(iconTexture)
    targetFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Set Text and Color
    local text = addon:FormatNumber(sequence.damage)
    targetFrame.text:SetText(text)
    if sequence.hasCrit then
        targetFrame.text:SetTextColor(CombineHitsDB.critColor.r, CombineHitsDB.critColor.g, CombineHitsDB.critColor.b)
    else
        targetFrame.text:SetTextColor(CombineHitsDB.textColor.r, CombineHitsDB.textColor.g, CombineHitsDB.textColor.b)
    end

    UIFrameFadeIn(targetFrame, 0.3, 0, 1)
    targetFrame.fadeTimer = C_Timer.NewTimer(CombineHitsDB.fadeTime, function()
        addon:FadeOut(targetFrame)
    end)

    -- *** REMOVED Leaderboard Call ***
    -- self:UpdateLeaderboardRecord(sequence)
end


-- **REMOVED UpdateLeaderboardRecord function**

-- Fade Out Frame, Clear Frame Data, Format Number
function addon:FadeOut(frame)
    if not frame or not frame.active then return end
    UIFrameFadeOut(frame, 0.3, frame:GetAlpha(), 0)
    if frame.fadeTimer then frame.fadeTimer:Cancel() end
    frame.fadeTimer = C_Timer.NewTimer(0.3, function() addon:ClearFrame(frame) end)
end

function addon:ClearFrame(frame)
     if not frame then return end
     frame.active = false
     frame.text:SetText("")
     frame.icon:SetTexture(nil)
     frame.currentSequence = nil
     frame.fadeStart = 0
     frame:SetAlpha(0)
     if frame.fadeTimer then frame.fadeTimer:Cancel(); frame.fadeTimer = nil; end
end

function addon:FormatNumber(number)
    if number >= 1000000 then return string.format("%.1fM", number / 1000000)
    elseif number >= 1000 then return string.format("%.0fK", math.floor(number / 1000))
    else return tostring(number) end
end

-- Slash Commands (Leaderboard commands removed)
SLASH_COMBINEHITS1 = "/ch"; SLASH_COMBINEHITS2 = "/combinehits"
SlashCmdList["COMBINEHITS"] = function(msg)
    local args = {}
    for arg in msg:gmatch("%S+") do table.insert(args, arg:lower()) end
    local cmd = args[1]
    if cmd == "lock" then
        CombineHitsDB.isLocked = not CombineHitsDB.isLocked
        addon:UpdateFrameAppearance(addon.mainFrame)
        print("CombineHits frame " .. (CombineHitsDB.isLocked and "locked" or "unlocked"))
    elseif cmd == "reset" then
        CombineHitsDB.framePosition.point = addon.defaults.framePosition.point
        CombineHitsDB.framePosition.x = addon.defaults.framePosition.x
        CombineHitsDB.framePosition.y = addon.defaults.framePosition.y
        addon.mainFrame:ClearAllPoints()
        addon.mainFrame:SetPoint(CombineHitsDB.framePosition.point, UIParent, CombineHitsDB.framePosition.point, CombineHitsDB.framePosition.x, CombineHitsDB.framePosition.y)
        print("CombineHits frame position reset")
    -- Removed "lb" command
    elseif cmd == "debug" then
        CombineHitsDB.debugMode = not CombineHitsDB.debugMode
        print("CombineHits debug mode " .. (CombineHitsDB.debugMode and "enabled" or "disabled"))
        if CombineHitsDB.debugMode and addon.currentSpec ~= "Fury" then
             print("|cxFFFF8000Warning:|r Debug mode is enabled, but you are not currently in Fury spec. Debug messages will only show when Fury is active.")
        end
    elseif cmd == "setwindow" then
        local value = tonumber(args[2])
        if value and value > 0.1 and value < 5 then
            CombineHitsDB.combineWindow = value
            print(string.format("CombineHits combine window set to: %.2f seconds", value))
        else
            print("Usage: /ch setwindow <seconds> (e.g., /ch setwindow 0.75)")
            print(string.format("Current value: %.2f seconds", CombineHitsDB.combineWindow))
        end
    -- Removed "clearrecords" command
    else
        print("CombineHits commands:")
        print("  /ch lock - Toggle frame lock")
        print("  /ch reset - Reset frame position")
        print("  /ch debug - Toggle debug mode")
        print(string.format("  /ch setwindow <sec> - Set combine window (Current: %.2fs)", CombineHitsDB.combineWindow))
        -- Removed leaderboard and clearrecords help text
    end
end

-- **REMOVED CreateLeaderboardFrame function**
-- **REMOVED UpdateLeaderboard function**
-- **REMOVED Leaderboard StaticPopup definition**

-- **Initialize UI (Leaderboard creation removed)**
function addon:InitializeUI()
    addon.mainFrame = addon:CreateMainFrame()
    addon:CreateDisplayFrames()
    -- addon:CreateLeaderboardFrame() -- Removed
    if CombineHitsDB.frameVisible then addon.mainFrame:Show() else addon.mainFrame:Hide() end
    addon:UpdateFrameAppearance(addon.mainFrame)
end

-- **Register Events**
function addon:RegisterEvents()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("PLAYER_TALENT_UPDATE")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_LOGOUT")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then addon:OnCombatLogEvent(...)
        elseif event == "UNIT_AURA" then addon:OnUnitAura(...)
        elseif event == "PLAYER_TALENT_UPDATE" then
            -- Update things that might change with talents, even if spec doesn't change
            addon:UpdateCurrentSpec() -- Ensure spec is current
            if addon.currentSpec == "Fury" then
                addon:UpdateThunderousRoarDuration()
                addon:InitializeAbilities() -- Re-check available abilities based on talents
            end
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            local oldSpec = addon.currentSpec
            addon:UpdateCurrentSpec() -- Get the new spec
             if oldSpec ~= addon.currentSpec then -- Only cleanup/reinit if spec actually changed
                addon:CleanupAbilities() -- Clear old data
                addon:InitializeAbilities() -- Re-init based on new spec (will only populate if Warrior)
                addon:UpdateThunderousRoarDuration() -- Update based on new spec/talents
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
             addon:UpdateCurrentSpec() -- Update spec on login/reload
             addon:CleanupAbilities() -- Clean up any state from before reload
             addon:InitializeAbilities() -- Initialize based on current spec
             addon:UpdateThunderousRoarDuration()
        elseif event == "PLAYER_LOGOUT" then
            addon:CleanupAbilities() -- Clean up on logout
        end
    end)
end

-- **Cleanup Abilities**
function addon:CleanupAbilities()
    addon:DebugPrint("Running CleanupAbilities...")
    local count = 0
    for id, sequence in pairs(addon.activeSequences) do
        if sequence and not sequence.resolved then
            addon:DebugPrint(string.format("Force resolving leftover sequence [%d]: %s", id, sequence.name))
            addon:ResolveAbility(id) -- This will call DisplayHit if needed
            count = count + 1
        end
         -- Ensure sequence is removed even if ResolveAbility didn't find it (shouldn't happen)
         addon.activeSequences[id] = nil
    end

    -- Reset special ability states
    THUNDEROUS_ROAR.active = false; THUNDEROUS_ROAR.totalDamage = 0; THUNDEROUS_ROAR.targets = {}
    RAVAGER.active = false; RAVAGER.totalDamage = 0; if RAVAGER.displayTimer then RAVAGER.displayTimer:Cancel(); RAVAGER.displayTimer = nil; end
    ODYNS_FURY.active = false; ODYNS_FURY.totalDamage = 0; ODYNS_FURY.targets = {}; if ODYNS_FURY.displayTimer then ODYNS_FURY.displayTimer:Cancel(); ODYNS_FURY.displayTimer = nil; end
    BLADESTORM.active = false; BLADESTORM.totalDamage = 0; if BLADESTORM.displayTimer then BLADESTORM.displayTimer:Cancel(); BLADESTORM.displayTimer = nil; end
    THUNDER_BLAST.active = false; THUNDER_BLAST.totalDamage = 0; THUNDER_BLAST.primaryHit = false; if THUNDER_BLAST.displayTimer then THUNDER_BLAST.displayTimer:Cancel(); THUNDER_BLAST.displayTimer = nil; end
    EXECUTE.active = false; EXECUTE.totalDamage = 0; EXECUTE.targets = {}; if EXECUTE.displayTimer then EXECUTE.displayTimer:Cancel(); EXECUTE.displayTimer = nil; end
    RAGING_BLOW.active = false; RAGING_BLOW.totalDamage = 0; RAGING_BLOW.targets = {}; if RAGING_BLOW.displayTimer then RAGING_BLOW.displayTimer:Cancel(); RAGING_BLOW.displayTimer = nil; end
    RAMPAGE.active = false; RAMPAGE.totalDamage = 0; RAMPAGE.targets = {}; if RAMPAGE.displayTimer then RAMPAGE.displayTimer:Cancel(); RAMPAGE.displayTimer = nil; end

    if count > 0 then addon:DebugPrint("Cleanup finished, resolved", count, "leftover sequences.")
    else addon:DebugPrint("Cleanup finished, no leftover sequences found.") end
    addon.nextAbilityID = 1 -- Reset unique ID counter
end


-- ==================================
-- **Special Ability Handlers (Fury Context)**
-- ==================================
-- These are only called if the player is Fury spec due to the check in OnCombatLogEvent.

function addon:HandleThunderousRoar(eventType, destGUID, spellId, amount, critical)
    local now = GetTime()
    if eventType == "SPELL_CAST_SUCCESS" and spellId == THUNDEROUS_ROAR.CAST_ID then
        if THUNDEROUS_ROAR.active then self:ResolveSpecialAbility(THUNDEROUS_ROAR, THUNDEROUS_ROAR.NAME) end
        addon:DebugPrint("Thunderous Roar Start (Handler)")
        THUNDEROUS_ROAR.active = true; THUNDEROUS_ROAR.targets = {}; THUNDEROUS_ROAR.totalDamage = (amount or 0);
        THUNDEROUS_ROAR.startTime = now; THUNDEROUS_ROAR.hasCrit = critical or false;
        C_Timer.After(THUNDEROUS_ROAR.DURATION + 0.1, function() self:ResolveSpecialAbility(THUNDEROUS_ROAR, THUNDEROUS_ROAR.NAME) end)

    elseif THUNDEROUS_ROAR.active and (now - THUNDEROUS_ROAR.startTime) <= (THUNDEROUS_ROAR.DURATION + 0.5) then
        if (eventType == "SPELL_DAMAGE" and spellId == THUNDEROUS_ROAR.CAST_ID) or (eventType == "SPELL_PERIODIC_DAMAGE" and spellId == THUNDEROUS_ROAR.DOT_ID) then
            local oldDamage = THUNDEROUS_ROAR.totalDamage; THUNDEROUS_ROAR.totalDamage = THUNDEROUS_ROAR.totalDamage + (amount or 0);
            THUNDEROUS_ROAR.hasCrit = THUNDEROUS_ROAR.hasCrit or critical;
            addon:DebugPrint(string.format("TR Hit: Type %s, Spell %d, +%d = %d, Crit: %s", eventType, spellId, amount or 0, THUNDEROUS_ROAR.totalDamage, tostring(critical)))
        end
    end
end

function addon:HandleRavager(eventType, destGUID, spellId, amount, critical)
    local now = GetTime()
    if eventType == "SPELL_CAST_SUCCESS" and spellId == RAVAGER.CAST_ID then
        if RAVAGER.active then self:ResolveSpecialAbility(RAVAGER, RAVAGER.NAME) end
        addon:DebugPrint("Ravager Start (Handler)")
        RAVAGER.active = true; RAVAGER.totalDamage = 0; RAVAGER.startTime = now; RAVAGER.hasCrit = false;
        if RAVAGER.displayTimer then RAVAGER.displayTimer:Cancel() end
        RAVAGER.displayTimer = C_Timer.NewTimer(RAVAGER.DURATION + 0.5, function()
            self:ResolveSpecialAbility(RAVAGER, RAVAGER.NAME)
        end)

    elseif RAVAGER.active and eventType == "SPELL_DAMAGE" and spellId == RAVAGER.DAMAGE_ID then
        if (now - RAVAGER.startTime) <= (RAVAGER.DURATION + 0.5) then
            local oldDamage = RAVAGER.totalDamage
            RAVAGER.totalDamage = RAVAGER.totalDamage + (amount or 0)
            RAVAGER.hasCrit = RAVAGER.hasCrit or critical
            addon:DebugPrint(string.format("Ravager Hit: Spell %d, +%d = %d, Crit: %s",
                spellId, amount or 0, RAVAGER.totalDamage, tostring(critical)))
        end
    end
end

function addon:HandleOdynsFury(eventType, destGUID, spellId, amount, critical)
    local now = GetTime()
    if eventType == "SPELL_CAST_SUCCESS" and spellId == ODYNS_FURY.CAST_ID then
        if ODYNS_FURY.active then self:ResolveSpecialAbility(ODYNS_FURY, ODYNS_FURY.NAME) end
        addon:DebugPrint("Odyn's Fury Start (Handler)")
        ODYNS_FURY.active = true; ODYNS_FURY.targets = {}; ODYNS_FURY.totalDamage = 0;
        ODYNS_FURY.startTime = now; ODYNS_FURY.hasCrit = false;
        if ODYNS_FURY.displayTimer then ODYNS_FURY.displayTimer:Cancel() end
        ODYNS_FURY.displayTimer = C_Timer.NewTimer(ODYNS_FURY.DURATION + 0.1, function() self:ResolveSpecialAbility(ODYNS_FURY, ODYNS_FURY.NAME) end)

    elseif ODYNS_FURY.active and (now - ODYNS_FURY.startTime) <= (ODYNS_FURY.DURATION + 0.5) then
        if (eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE") and (ODYNS_FURY.DAMAGE_IDS[spellId] or spellId == ODYNS_FURY.CAST_ID) then
            local oldDamage = ODYNS_FURY.totalDamage; ODYNS_FURY.totalDamage = ODYNS_FURY.totalDamage + (amount or 0);
            ODYNS_FURY.hasCrit = ODYNS_FURY.hasCrit or critical;
            addon:DebugPrint(string.format("OF Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, ODYNS_FURY.totalDamage, tostring(critical)))
        end
    end
end

function addon:HandleThunderBlast(eventType, destGUID, spellId, amount, critical)
    local now = GetTime()
    if eventType == "SPELL_DAMAGE" and THUNDER_BLAST.PRIMARY_DAMAGE_IDS[spellId] and not THUNDER_BLAST.active then
        addon:DebugPrint("Thunder Blast Start (Handler)")
        THUNDER_BLAST.active = true; THUNDER_BLAST.totalDamage = 0; THUNDER_BLAST.startTime = now;
        THUNDER_BLAST.hasCrit = false; THUNDER_BLAST.primaryHit = true;
        THUNDER_BLAST.totalDamage = THUNDER_BLAST.totalDamage + (amount or 0); THUNDER_BLAST.hasCrit = THUNDER_BLAST.hasCrit or critical;
        addon:DebugPrint(string.format("TB First Hit: +%d = %d, Crit: %s", amount or 0, THUNDER_BLAST.totalDamage, tostring(critical)))
        if THUNDER_BLAST.displayTimer then THUNDER_BLAST.displayTimer:Cancel() end
        THUNDER_BLAST.displayTimer = C_Timer.NewTimer(THUNDER_BLAST.DURATION, function() self:ResolveSpecialAbility(THUNDER_BLAST, THUNDER_BLAST.NAME) end)

    elseif THUNDER_BLAST.active and THUNDER_BLAST.primaryHit then
         if eventType == "SPELL_DAMAGE" and (THUNDER_BLAST.PRIMARY_DAMAGE_IDS[spellId] or THUNDER_BLAST.SECONDARY_DAMAGE_IDS[spellId]) then
             if (now - THUNDER_BLAST.startTime) <= THUNDER_BLAST.DURATION then
                 local oldDamage = THUNDER_BLAST.totalDamage; THUNDER_BLAST.totalDamage = THUNDER_BLAST.totalDamage + (amount or 0);
                 THUNDER_BLAST.hasCrit = THUNDER_BLAST.hasCrit or critical;
                 addon:DebugPrint(string.format("TB Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, THUNDER_BLAST.totalDamage, tostring(critical)))
             end
         end
    end
end

function addon:HandleBladestorm(eventType, destGUID, spellId, amount, critical)
    local now = GetTime()
     -- Only check Fury Bladestorm cast ID
     local isKnownCastId = (spellId == BLADESTORM.CAST_ID)

    if eventType == "SPELL_CAST_SUCCESS" and isKnownCastId then
        if BLADESTORM.active then self:ResolveSpecialAbility(BLADESTORM, BLADESTORM.NAME) end
        addon:DebugPrint("Bladestorm Start (Handler - ID: "..spellId..")")
        BLADESTORM.active = true; BLADESTORM.totalDamage = 0; BLADESTORM.startTime = now; BLADESTORM.hasCrit = false;
        if BLADESTORM.displayTimer then BLADESTORM.displayTimer:Cancel() end
        local duration = BLADESTORM.DURATION
        BLADESTORM.displayTimer = C_Timer.NewTimer(duration + 0.1, function() self:ResolveSpecialAbility(BLADESTORM, BLADESTORM.NAME) end)

    elseif BLADESTORM.active then
        -- Check against known Fury damage IDs
        local isKnownDamageId = BLADESTORM.DAMAGE_IDS[spellId]
         if eventType == "SPELL_DAMAGE" and isKnownDamageId then
            if (now - BLADESTORM.startTime) <= (BLADESTORM.DURATION + 0.5) then
                local oldDamage = BLADESTORM.totalDamage; BLADESTORM.totalDamage = BLADESTORM.totalDamage + (amount or 0);
                BLADESTORM.hasCrit = BLADESTORM.hasCrit or critical;
                addon:DebugPrint(string.format("BS Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, BLADESTORM.totalDamage, tostring(critical)))
            end
        end
    end
end

function addon:HandleExecute(eventType, destGUID, spellId, amount, critical)
    local now = GetTime()
    if eventType == "SPELL_CAST_SUCCESS" and spellId == EXECUTE.CAST_ID then
        if EXECUTE.active then self:ResolveSpecialAbility(EXECUTE, EXECUTE.NAME) end
        addon:DebugPrint("Execute Start (Handler)")
        EXECUTE.active = true; EXECUTE.targets = {}; EXECUTE.totalDamage = 0;
        EXECUTE.startTime = now; EXECUTE.hasCrit = false;
        if EXECUTE.displayTimer then EXECUTE.displayTimer:Cancel() end
        EXECUTE.displayTimer = C_Timer.NewTimer(EXECUTE.DURATION, function()
            self:ResolveSpecialAbility(EXECUTE, EXECUTE.NAME)
        end)

    elseif EXECUTE.active and (now - EXECUTE.startTime) <= EXECUTE.DURATION then
        if eventType == "SPELL_DAMAGE" and (EXECUTE.DAMAGE_IDS[spellId]) then
            local oldDamage = EXECUTE.totalDamage
            EXECUTE.totalDamage = EXECUTE.totalDamage + (amount or 0)
            EXECUTE.hasCrit = EXECUTE.hasCrit or critical
            addon:DebugPrint(string.format("Execute Hit: Spell %d, +%d = %d, Crit: %s",
                spellId, amount or 0, EXECUTE.totalDamage, tostring(critical)))
        end
    end
end

function addon:HandleRagingBlow(eventType, destGUID, spellId, amount, critical)
    local now = GetTime()
    if eventType == "SPELL_CAST_SUCCESS" and spellId == RAGING_BLOW.CAST_ID then
        if RAGING_BLOW.active then self:ResolveSpecialAbility(RAGING_BLOW, RAGING_BLOW.NAME) end
        addon:DebugPrint("Raging Blow Start (Handler)")
        RAGING_BLOW.active = true; RAGING_BLOW.targets = {}; RAGING_BLOW.totalDamage = 0;
        RAGING_BLOW.startTime = now; RAGING_BLOW.hasCrit = false;
        if RAGING_BLOW.displayTimer then RAGING_BLOW.displayTimer:Cancel() end
        RAGING_BLOW.displayTimer = C_Timer.NewTimer(RAGING_BLOW.DURATION, function()
            self:ResolveSpecialAbility(RAGING_BLOW, RAGING_BLOW.NAME)
        end)

    elseif RAGING_BLOW.active and (now - RAGING_BLOW.startTime) <= RAGING_BLOW.DURATION then
        if eventType == "SPELL_DAMAGE" and RAGING_BLOW.DAMAGE_IDS[spellId] then
            local oldDamage = RAGING_BLOW.totalDamage
            RAGING_BLOW.totalDamage = RAGING_BLOW.totalDamage + (amount or 0)
            RAGING_BLOW.hasCrit = RAGING_BLOW.hasCrit or critical
            addon:DebugPrint(string.format("Raging Blow Hit: Spell %d, +%d = %d, Crit: %s",
                spellId, amount or 0, RAGING_BLOW.totalDamage, tostring(critical)))
        end
    end
end

-- **Helper to Resolve Special Abilities**
function addon:ResolveSpecialAbility(abilityTable, abilityName)
    if abilityTable.active then
        local abilityInfo = self.trackedAbilitiesByName[abilityName] -- Get info using name
        local iconSpellIdToUse = abilityInfo and abilityInfo.iconSpellId -- Use icon ID from init

        addon:DebugPrint(string.format("%s Resolve Triggered (Damage: %d)", abilityName, abilityTable.totalDamage))
        if abilityTable.totalDamage > 0 then
            local sequence = {
                name = abilityName,
                iconSpellId = iconSpellIdToUse,
                damage = abilityTable.totalDamage,
                hasCrit = abilityTable.hasCrit,
                startTime = abilityTable.startTime
            }
            addon:DisplayHit(sequence)
        end
        -- Reset state
        abilityTable.active = false; abilityTable.totalDamage = 0; abilityTable.hasCrit = false;
        abilityTable.primaryHit = false; -- Reset for Thunder Blast
        if abilityTable.targets then abilityTable.targets = {} end
        if abilityTable.displayTimer then abilityTable.displayTimer:Cancel(); abilityTable.displayTimer = nil; end
    end
end


-- Helper Table Length (Unused currently, kept for potential future utility)
function addon:TableLength(T) local count = 0; if T then for _ in pairs(T) do count = count + 1 end end; return count end

-- **On Addon Load**
local function OnLoad()
    addon:Init()
    addon:UpdateCurrentSpec() -- Determine spec first
    addon:InitializeAbilities() -- Initialize based on spec/class
    addon:InitializeUI()
    addon:RegisterEvents()
    addon:UpdateThunderousRoarDuration() -- Check talent on load
    print("CombineHits Addon Loaded (Fury Warrior Focused).")
    if CombineHitsDB.debugMode then print("CombineHits Debug Mode is ON.") end
     if addon.currentSpec ~= "Fury" then
        print("|cxFFFF8000CombineHits:|r Not currently Fury spec. Addon is idle.")
    end
end

-- **Load Frame Handler**
local loadFrame = CreateFrame("Frame"); loadFrame:RegisterEvent("ADDON_LOADED"); loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "CombineHits" then
        OnLoad()
        self:UnregisterEvent(event) -- Only run OnLoad once per session via ADDON_LOADED
    elseif event == "PLAYER_LOGIN" then
         -- This ensures spec is updated correctly after potential changes while logged out
         addon:UpdateCurrentSpec()
         -- Re-initialize abilities and UI states relevant to the current spec on login
         addon:InitializeAbilities()
         addon:UpdateThunderousRoarDuration()
         if addon.currentSpec ~= "Fury" then
            print("|cxFFFF8000CombineHits:|r Not currently Fury spec. Addon is idle.")
         end
    end
end)

-- **Debug Print Function (FURY CHECK ADDED)**
function addon:DebugPrint(...)
    -- Only print if debug mode is ON *and* player is Fury spec
    if CombineHitsDB.debugMode and self.currentSpec == "Fury" then
        print("|cFF00FF00[CH Debug]|r", ...)
    end
end

-- **Update Thunderous Roar Duration**
function addon:UpdateThunderousRoarDuration()
    -- Only needs to run meaningful checks if Fury
    if self.currentSpec ~= "Fury" then return end

    local hasTalent = IsSpellKnown(THUNDEROUS_ROAR.TALENT_ID);
    if hasTalent then
        THUNDEROUS_ROAR.DURATION = THUNDEROUS_ROAR.TALENT_DURATION;
        addon:DebugPrint("Talent 'Thunderous Words' found. Roar duration set to", THUNDEROUS_ROAR.DURATION.."s")
    else
        THUNDEROUS_ROAR.DURATION = 10;
        addon:DebugPrint("Talent 'Thunderous Words' not found. Roar duration set to", THUNDEROUS_ROAR.DURATION.."s")
    end
end

-- **Update Current Spec**
function addon:UpdateCurrentSpec()
    local specIndex = GetSpecialization()
    local oldSpec = self.currentSpec
    local newSpec = "Unknown"
    local _, className, classID = UnitClass("player")

    if className == "WARRIOR" and specIndex then
        local specID, specName = GetSpecializationInfo(specIndex)
        if specID == 71 then newSpec = "Arms"
        elseif specID == 72 then newSpec = "Fury"
        elseif specID == 73 then newSpec = "Protection"
        end
    elseif className ~= "WARRIOR" then
         newSpec = "NotWarrior" -- Differentiate from unknown Warrior spec
    end

    self.currentSpec = newSpec

    if oldSpec ~= self.currentSpec then
        -- Print spec change regardless of debug mode, but don't use DebugPrint itself here
        if CombineHitsDB.debugMode then -- Only print detailed change if debug is on
             print(string.format("|cFF00FF00[CH Debug]|r Spec changed from '%s' to '%s'", tostring(oldSpec), self.currentSpec))
        end
        -- Add message if becoming non-Fury
        if self.currentSpec ~= "Fury" and oldSpec == "Fury" then
             print("|cxFFFF8000CombineHits:|r Switched from Fury spec. Addon is now idle.")
        elseif self.currentSpec == "Fury" and oldSpec ~= "Fury" then
             print("|cFF00FF00CombineHits:|r Switched to Fury spec. Addon is now active.")
        end
    end
end

-- Add Rampage handler (after other handlers like HandleOdynsFury)
function addon:HandleRampage(eventType, destGUID, spellId, amount, critical)
    local now = GetTime()
    if eventType == "SPELL_CAST_SUCCESS" and spellId == RAMPAGE.CAST_ID then
        if RAMPAGE.active then self:ResolveSpecialAbility(RAMPAGE, RAMPAGE.NAME) end
        addon:DebugPrint("Rampage Start (Handler)")
        RAMPAGE.active = true; RAMPAGE.targets = {}; RAMPAGE.totalDamage = 0;
        RAMPAGE.startTime = now; RAMPAGE.hasCrit = false;
        if RAMPAGE.displayTimer then RAMPAGE.displayTimer:Cancel() end
        RAMPAGE.displayTimer = C_Timer.NewTimer(RAMPAGE.DURATION + 0.1, function() 
            self:ResolveSpecialAbility(RAMPAGE, RAMPAGE.NAME) 
        end)

    elseif RAMPAGE.active and (now - RAMPAGE.startTime) <= RAMPAGE.DURATION then
        if eventType == "SPELL_DAMAGE" and RAMPAGE.DAMAGE_IDS[spellId] then
            local oldDamage = RAMPAGE.totalDamage
            RAMPAGE.totalDamage = RAMPAGE.totalDamage + (amount or 0)
            RAMPAGE.hasCrit = RAMPAGE.hasCrit or critical
            addon:DebugPrint(string.format("Rampage Hit: Spell %d, +%d = %d, Crit: %s",
                spellId, amount or 0, RAMPAGE.totalDamage, tostring(critical)))
        end
    end
end