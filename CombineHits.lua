-- CombineHits addon (Warrior Focused)
local addon = {}
addon.trackedAbilitiesByName = {} -- Keyed by Spell Name
addon.activeSequences = {}        -- Queue/Dictionary keyed by unique abilityID for non-special abilities
addon.nextAbilityID = 1           -- Counter for unique IDs
addon.hasWhirlwindBuff = false -- Still relevant for Fury
addon.currentSpec = nil -- Tracked for spec-specific logic

-- **Ability Definitions (Warrior)**
-- We still need *a* representative ID, primarily for the icon.
local ABILITY_INFO = {
    -- Fury
    ["Rampage"]         = { iconId = 490,    isSpecial = true, handler = "HandleRampage", specs = {"Fury"} },
    ["Raging Blow"]     = { iconId = 85288,  isSpecial = true, handler = "HandleRagingBlow", specs = {"Fury"} },
    ["Execute Off-Hand"] = { iconId = 5308,   isSpecial = true, handler = "HandleExecute", specs = {"Fury"} }, -- Use Fury Execute handler
    ["Bloodthirst"]     = { iconId = 23881,  isSpecial = false, specs = {"Fury"} },
    ["Onslaught"]       = { iconId = 315720, isSpecial = false, specs = {"Fury"} },
    ["Odyn's Fury"]     = { iconId = 385059, isSpecial = true, handler = "HandleOdynsFury", specs = {"Fury"} },
    ["Thunder Blast"]   = { iconId = 435222, isSpecial = true, handler = "HandleThunderBlast", specs = {"Fury"} },
    ["Lightning Strike"] = { iconId = 435222, isSpecial = true, handler = "HandleThunderBlast", specs = {"Fury"} }, -- Part of Thunder Blast
    ["Lightning Strike Ground Current"] = { iconId = 435222, isSpecial = true, handler = "HandleThunderBlast", specs = {"Fury"} }, -- Part of Thunder Blast
    -- Arms
    ["Mortal Strike"]   = { iconId = 12294,  isSpecial = false, specs = {"Arms"} },
    ["Overpower"]       = { iconId = 7384,   isSpecial = false, specs = {"Arms"} },
    ["Cleave"]          = { iconId = 845,    isSpecial = true, handler = "HandleCleave", specs = {"Arms"} },
    -- Protection
    ["Shield Slam"]     = { iconId = 23922,  isSpecial = false, specs = {"Protection"} },
    ["Revenge"]         = { iconId = 6572,   isSpecial = true, handler = "HandleRevenge", specs = {"Protection"} },
    ["Shield Charge"]   = { iconId = 385954, isSpecial = true, handler = "HandleShieldCharge", specs = {"Protection"} },
    -- Shared / Spec-Dependent Handlers
    ["Execute"]         = { iconId = 5308,   isSpecial = true, handler = "HandleExecute", specs = {"Fury", "Arms", "Protection"} }, -- Added Protection
    ["Thunder Clap"]    = { iconId = 6343,   isSpecial = false, specs = {"Fury", "Arms", "Protection"} },
    ["Demolish"]        = { iconId = 436358, isSpecial = true, handler = "HandleDemolish", specs = {"Arms", "Protection"} }, -- Shared handler (verify IDs)
    ["Bladestorm"]      = { iconId = 227847, isSpecial = true, handler = "HandleBladestorm", specs = {"Fury", "Arms"} }, -- Handler might need spec logic if IDs differ
    ["Ravager"]         = { iconId = 228920, isSpecial = true, handler = "HandleRavager", specs = {"Fury", "Arms", "Protection"} }, -- Handler checks spec
    ["Thunderous Roar"] = { iconId = 384318, isSpecial = true, handler = "HandleThunderousRoar", specs = {"Fury", "Arms", "Protection"} },
    -- Generic
    ["Slam"]            = { iconId = 1464,   isSpecial = false, specs = {"Fury", "Arms"} },
}

-- ==================================
-- **Special Ability Data Tables**
-- ==================================

-- Fury Specific
local RAMPAGE_DATA = {
    NAME = "Rampage", CAST_ID = 184367, DAMAGE_IDS = { [184707]=true, [184709]=true, [201364]=true, [201363]=true, [85384]=true },
    active = false, totalDamage = 0, startTime = 0, DURATION = 0.8, displayTimer = nil, hasCrit = false
}
local RAGING_BLOW_DATA = {
    NAME = "Raging Blow", CAST_ID = 85288, DAMAGE_IDS = { [85288]=true, [96103]=true, [85384]=true },
    active = false, totalDamage = 0, startTime = 0, DURATION = 0.5, displayTimer = nil, hasCrit = false
}
local ODYNS_FURY_DATA = {
    NAME = "Odyn's Fury", CAST_ID = 385059, DAMAGE_IDS = { [385060]=true, [385061]=true, [385062]=true },
    active = false, totalDamage = 0, startTime = 0, DURATION = 5, displayTimer = nil, hasCrit = false
}
local THUNDER_BLAST_DATA = {
    NAME = "Thunder Blast", CAST_ID = 435222, PRIMARY_DAMAGE_IDS = { [435222]=true, [436793]=true },
    SECONDARY_DAMAGE_IDS = { [435791]=true, [460670]=true }, active = false,
    totalDamage = 0, startTime = 0, DURATION = 1.0, displayTimer = nil, hasCrit = false
}

-- Arms Specific
local CLEAVE_DATA = {
    NAME = "Cleave", CAST_ID = 845, DAMAGE_IDS = { [845]=true, [458459]=true },
    active = false, totalDamage = 0, startTime = 0, DURATION = 0.5, displayTimer = nil, hasCrit = false
}

-- Protection Specific
local REVENGE_DATA = {
    NAME = "Revenge", CAST_ID = 6572, DAMAGE_IDS = { [6572]=true, [1215174]=true },
    active = false, totalDamage = 0, startTime = 0, DURATION = 0.5, displayTimer = nil, hasCrit = false
}
local SHIELD_CHARGE_DATA = {
    NAME = "Shield Charge", CAST_ID = 385954, DAMAGE_IDS = { [385954]=true }, -- Multiple hits share the same ID
    active = false, totalDamage = 0, startTime = 0, DURATION = 1.0, displayTimer = nil, hasCrit = false
}

-- Shared / Spec-Dependent Data
local THUNDEROUS_ROAR_DATA = {
    NAME = "Thunderous Roar", CAST_ID = 384318, DOT_ID = 397364, active = false,
    totalDamage = 0, startTime = 0, DURATION = 10, TALENT_DURATION = 12, TALENT_ID = 384969, hasCrit = false
}
local BLADESTORM_DATA = { -- Using Fury IDs as base, needs verification for Arms
    NAME = "Bladestorm", CAST_ID = 227847, DAMAGE_IDS = { [50622]=true, [95738]=true },
    active = false, totalDamage = 0, startTime = 0, DURATION = 4, displayTimer = nil, hasCrit = false
}
local DEMOLISH_DATA = { -- Shared between Arms and Prot
    NAME = "Demolish", CAST_ID = 436358, DAMAGE_IDS = { [440884]=true, [440886]=true, [440888]=true },
    active = false, totalDamage = 0, startTime = 0, DURATION = 1.5, displayTimer = nil, hasCrit = false
}
-- Execute Data (Split by Spec)
local EXECUTE_FURY_DATA = {
    NAME = "Execute", CAST_ID = 5308, DAMAGE_IDS = { [5308]=true, [163558]=true, [280849]=true },
    active = false, totalDamage = 0, startTime = 0, DURATION = 0.5, displayTimer = nil, hasCrit = false
}
local EXECUTE_ARMS_DATA = {
    NAME = "Execute", CAST_ID = 163201, DAMAGE_IDS = { [260798]=true },
    active = false, totalDamage = 0, startTime = 0, DURATION = 0.5, displayTimer = nil, hasCrit = false
}
local EXECUTE_PROT_DATA = {
    NAME = "Execute", CAST_ID = 163201, DAMAGE_IDS = { [260798]=true },
    active = false, totalDamage = 0, startTime = 0, DURATION = 0.5, displayTimer = nil, hasCrit = false
}
-- Ravager Data (Split by Spec)
local RAVAGER_FURY_DATA = {
    NAME = "Ravager", CAST_ID = 228920, DAMAGE_ID = 156287,
    active = false, totalDamage = 0, startTime = 0, DURATION = 11, displayTimer = nil, hasCrit = false
}
local RAVAGER_ARMS_DATA = {
    NAME = "Ravager", CAST_ID = 334934, DAMAGE_ID = 156287, -- Arms uses Prot Cast ID now
    active = false, totalDamage = 0, startTime = 0, DURATION = 11, displayTimer = nil, hasCrit = false
}
local RAVAGER_PROT_DATA = {
    NAME = "Ravager", CAST_ID = 334934, DAMAGE_ID = 156287,
    active = false, totalDamage = 0, startTime = 0, DURATION = 11, displayTimer = nil, hasCrit = false
}


-- **Initialize Saved Variables** (Unchanged)
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
    if CombineHitsDB.isLocked == nil then CombineHitsDB.isLocked = self.defaults.isLocked end
    if CombineHitsDB.frameVisible == nil then CombineHitsDB.frameVisible = self.defaults.frameVisible end
    if CombineHitsDB.debugMode == nil then CombineHitsDB.debugMode = self.defaults.debugMode end
    if CombineHitsDB.combineWindow == nil then CombineHitsDB.combineWindow = self.defaults.combineWindow end
end

-- **Defaults** (Unchanged)
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
    isLocked = false,
    debugMode = false
}

-- **Initialize Abilities** (Unchanged)
function addon:InitializeAbilities()
    self.trackedAbilitiesByName = {} -- Clear previous data
    local missingIcons = {}
    local _, class = UnitClass("player")

    if class ~= "WARRIOR" then
        self:DebugPrint("Player is not a Warrior. Skipping ability initialization.")
        return
    end

    for name, info in pairs(ABILITY_INFO) do
        local currentSpec = self.currentSpec
        local abilitySpecs = info.specs or {}
        local specMatch = false
        for _, specName in ipairs(abilitySpecs) do
            if specName == currentSpec then
                specMatch = true
                break
            end
        end

        -- Only initialize if the ability is for the current spec OR has no spec restriction (generic)
        if specMatch or #abilitySpecs == 0 then
            local iconSpellId = info.iconId
            local spellInfo = C_Spell.GetSpellInfo(iconSpellId)

            if spellInfo and spellInfo.iconID then
                self.trackedAbilitiesByName[name] = {
                    name = name, iconSpellId = iconSpellId,
                    isSpecial = info.isSpecial, handler = info.handler, specs = info.specs
                }
                self:DebugPrint("Initialized Ability:", name, "(Icon ID:", iconSpellId, ", Special:", tostring(info.isSpecial), ", Specs:", table.concat(info.specs, "/"), ")")
            else
                spellInfo = C_Spell.GetSpellInfo(name)
                if spellInfo and spellInfo.spellID and spellInfo.iconID then
                    self.trackedAbilitiesByName[name] = {
                        name = name, iconSpellId = spellInfo.spellID,
                        isSpecial = info.isSpecial, handler = info.handler, specs = info.specs
                    }
                    self:DebugPrint("Initialized Ability (Fallback ID):", name, "(Icon ID:", spellInfo.spellID, ", Special:", tostring(info.isSpecial), ", Specs:", table.concat(info.specs, "/"), ")")
                else
                    table.insert(missingIcons, name .. " (Tried ID: " .. tostring(iconSpellId) .. ")")
                    self.trackedAbilitiesByName[name] = {
                        name = name, iconSpellId = nil,
                        isSpecial = info.isSpecial, handler = info.handler, specs = info.specs
                    }
                end
            end
        end
    end

    if #missingIcons > 0 then
        self:DebugPrint("|cxFFFF8000Warning:|r Could not find valid spell/icon info for:", table.concat(missingIcons, ", "))
    end
end


-- **Generate Unique ID** (Unchanged)
function addon:GenerateAbilityID()
    local id = addon.nextAbilityID
    addon.nextAbilityID = addon.nextAbilityID + 1
    return id
end

-- **UI Functions** (Unchanged)
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
        frame:SetSize(CombineHitsDB.frameWidth - 20, 32) -- Increased height slightly for bigger icon
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32) -- Kept the 32x32 size change
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

-- **Combat Log Event Handler** (Unchanged)
function addon:OnCombatLogEvent(...)
    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical = CombatLogGetCurrentEventInfo()
    local now = GetTime()
    if sourceGUID ~= UnitGUID("player") then return end
    local abilityInfo = self.trackedAbilitiesByName[spellName]
    if abilityInfo then
        if abilityInfo.isSpecial and abilityInfo.handler and self[abilityInfo.handler] then
            self[abilityInfo.handler](self, eventType, destGUID, spellId, amount, critical)
             if eventType ~= "SPELL_CAST_SUCCESS" then
                 return
             end
        elseif not abilityInfo.isSpecial then
             if eventType == "SPELL_CAST_SUCCESS" then
                local abilityID = addon:GenerateAbilityID()
                addon.activeSequences[abilityID] = {
                    abilityID = abilityID, name = abilityInfo.name, iconSpellId = abilityInfo.iconSpellId,
                    damage = 0, hasCrit = false, startTime = now, resolved = false,
                    whirlwindActive = (self.currentSpec == "Fury" and addon.hasWhirlwindBuff)
                }
                addon:DebugPrint(string.format("[%d] Cast Start (Non-Special): %s", abilityID, abilityInfo.name))
                C_Timer.After(CombineHitsDB.combineWindow, function() addon:ResolveAbility(abilityID) end)
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
                     sequence.damage = sequence.damage + (amount or 0)
                     sequence.hasCrit = sequence.hasCrit or critical
                     addon:DebugPrint(string.format("[%d] Damage Update: %s (+%d = %d, Crit: %s)", bestMatchID, sequence.name, amount or 0, sequence.damage, tostring(critical)))
                 end
             end
        end
    end
end

-- **Resolve Ability** (Unchanged)
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

-- **Unit Aura Event Handler** (Unchanged)
function addon:OnUnitAura(unit)
    if unit ~= "player" then return end
    if self.currentSpec == "Fury" then
        addon.hasWhirlwindBuff = AuraUtil.FindAuraByName("Whirlwind", "player", "HELPFUL") ~= nil
    else
        addon.hasWhirlwindBuff = false
    end
end

-- **Display Hit** (Unchanged)
function addon:DisplayHit(sequence)
    if not sequence or sequence.damage <= 0 then
        addon:DebugPrint("DisplayHit skipped: Invalid sequence or zero damage.")
        return
    end
    addon:DebugPrint(string.format(
        "Displaying Hit: %s (IconID: %s, Damage: %d, Crit: %s)",
        sequence.name, tostring(sequence.iconSpellId or "N/A"), sequence.damage, tostring(sequence.hasCrit)
    ))
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
    local targetFrame = addon.displayFrames[1]
    if targetFrame.fadeTimer then targetFrame.fadeTimer:Cancel() end
    targetFrame:SetAlpha(0)
    targetFrame.currentSequence = sequence
    targetFrame.active = true
    targetFrame.fadeStart = GetTime()
    local iconTexture = 134400
    if sequence.iconSpellId then
        local spellInfo = C_Spell.GetSpellInfo(sequence.iconSpellId)
        if spellInfo and spellInfo.iconID then iconTexture = spellInfo.iconID end
    end
    targetFrame.icon:SetTexture(iconTexture)
    targetFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local text = addon:FormatNumber(sequence.damage)
    targetFrame.text:SetText(text)
    if sequence.hasCrit then
        targetFrame.text:SetTextColor(CombineHitsDB.critColor.r, CombineHitsDB.critColor.g, CombineHitsDB.critColor.b)
    else
        targetFrame.text:SetTextColor(CombineHitsDB.textColor.r, CombineHitsDB.textColor.g, CombineHitsDB.textColor.b)
    end
    UIFrameFadeIn(targetFrame, 0.3, 0, 1)
    targetFrame.fadeTimer = C_Timer.NewTimer(CombineHitsDB.fadeTime, function() addon:FadeOut(targetFrame) end)
end

-- **Utility Functions** (Unchanged)
function addon:FadeOut(frame) if not frame or not frame.active then return end UIFrameFadeOut(frame, 0.3, frame:GetAlpha(), 0) if frame.fadeTimer then frame.fadeTimer:Cancel() end frame.fadeTimer = C_Timer.NewTimer(0.3, function() addon:ClearFrame(frame) end) end
function addon:ClearFrame(frame) if not frame then return end frame.active = false frame.text:SetText("") frame.icon:SetTexture(nil) frame.currentSequence = nil frame.fadeStart = 0 frame:SetAlpha(0) if frame.fadeTimer then frame.fadeTimer:Cancel(); frame.fadeTimer = nil; end end
function addon:FormatNumber(number) if number >= 1000000 then return string.format("%.1fM", number / 1000000) elseif number >= 1000 then return string.format("%.0fK", math.floor(number / 1000)) else return tostring(number) end end

-- **Slash Commands** (Unchanged)
SLASH_COMBINEHITS1 = "/ch"; SLASH_COMBINEHITS2 = "/combinehits"
SlashCmdList["COMBINEHITS"] = function(msg) local args = {} for arg in msg:gmatch("%S+") do table.insert(args, arg:lower()) end local cmd = args[1] if cmd == "lock" then CombineHitsDB.isLocked = not CombineHitsDB.isLocked addon:UpdateFrameAppearance(addon.mainFrame) print("CombineHits frame " .. (CombineHitsDB.isLocked and "locked" or "unlocked")) elseif cmd == "reset" then CombineHitsDB.framePosition.point = addon.defaults.framePosition.point CombineHitsDB.framePosition.x = addon.defaults.framePosition.x CombineHitsDB.framePosition.y = addon.defaults.framePosition.y addon.mainFrame:ClearAllPoints() addon.mainFrame:SetPoint(CombineHitsDB.framePosition.point, UIParent, CombineHitsDB.framePosition.point, CombineHitsDB.framePosition.x, CombineHitsDB.framePosition.y) print("CombineHits frame position reset") elseif cmd == "debug" then CombineHitsDB.debugMode = not CombineHitsDB.debugMode print("CombineHits debug mode " .. (CombineHitsDB.debugMode and "enabled" or "disabled")) elseif cmd == "setwindow" then local value = tonumber(args[2]) if value and value > 0.1 and value < 5 then CombineHitsDB.combineWindow = value print(string.format("CombineHits combine window set to: %.2f seconds", value)) else print("Usage: /ch setwindow <seconds> (e.g., /ch setwindow 0.5)") print(string.format("Current value: %.2f seconds", CombineHitsDB.combineWindow)) end else print("CombineHits commands:") print("  /ch lock - Toggle frame lock") print("  /ch reset - Reset frame position") print("  /ch debug - Toggle debug mode") print(string.format("  /ch setwindow <sec> - Set combine window (Current: %.2fs)", CombineHitsDB.combineWindow)) end end

-- **Initialize UI** (Unchanged)
function addon:InitializeUI() addon.mainFrame = addon:CreateMainFrame() addon:CreateDisplayFrames() if CombineHitsDB.frameVisible then addon.mainFrame:Show() else addon.mainFrame:Hide() end addon:UpdateFrameAppearance(addon.mainFrame) end

-- **Register Events** (Unchanged)
function addon:RegisterEvents() local frame = CreateFrame("Frame") frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") frame:RegisterEvent("UNIT_AURA") frame:RegisterEvent("PLAYER_TALENT_UPDATE") frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED") frame:RegisterEvent("PLAYER_ENTERING_WORLD") frame:RegisterEvent("PLAYER_LOGOUT") frame:SetScript("OnEvent", function(self, event, ...) if event == "COMBAT_LOG_EVENT_UNFILTERED" then addon:OnCombatLogEvent(...) elseif event == "UNIT_AURA" then addon:OnUnitAura(...) elseif event == "PLAYER_TALENT_UPDATE" then addon:UpdateCurrentSpec() addon:InitializeAbilities() addon:UpdateThunderousRoarDuration() elseif event == "PLAYER_SPECIALIZATION_CHANGED" then local oldSpec = addon.currentSpec addon:UpdateCurrentSpec() if oldSpec ~= addon.currentSpec then addon:CleanupAbilities() addon:InitializeAbilities() addon:UpdateThunderousRoarDuration() end elseif event == "PLAYER_ENTERING_WORLD" then addon:UpdateCurrentSpec() addon:CleanupAbilities() addon:InitializeAbilities() addon:UpdateThunderousRoarDuration() elseif event == "PLAYER_LOGOUT" then addon:CleanupAbilities() end end) end

-- **Cleanup Abilities** (Added resets for Protection tables)
function addon:CleanupAbilities()
    addon:DebugPrint("Running CleanupAbilities...")
    local count = 0
    for id, sequence in pairs(addon.activeSequences) do
        if sequence and not sequence.resolved then
            addon:DebugPrint(string.format("Force resolving leftover sequence [%d]: %s", id, sequence.name))
            addon:ResolveAbility(id)
            count = count + 1
        end
         addon.activeSequences[id] = nil
    end

    -- Reset special ability states for ALL potential tables
    local tablesToReset = {
        THUNDEROUS_ROAR_DATA, ODYNS_FURY_DATA, BLADESTORM_DATA, DEMOLISH_DATA,
        -- Fury
        RAMPAGE_DATA, RAGING_BLOW_DATA, THUNDER_BLAST_DATA, EXECUTE_FURY_DATA, RAVAGER_FURY_DATA,
        -- Arms
        CLEAVE_DATA, EXECUTE_ARMS_DATA, RAVAGER_ARMS_DATA,
        -- Protection
        REVENGE_DATA, SHIELD_CHARGE_DATA, RAVAGER_PROT_DATA, EXECUTE_PROT_DATA
    }
    for _, tbl in ipairs(tablesToReset) do
        if tbl then
            tbl.active = false; tbl.totalDamage = 0; tbl.hasCrit = false;
            if tbl.targets then tbl.targets = {} end
            if tbl.primaryHit then tbl.primaryHit = false end
            if tbl.displayTimer then tbl.displayTimer:Cancel(); tbl.displayTimer = nil; end
        end
    end

    if count > 0 then addon:DebugPrint("Cleanup finished, resolved", count, "leftover sequences.")
    else addon:DebugPrint("Cleanup finished, no leftover sequences found.") end
    addon.nextAbilityID = 1
end


-- ==================================
-- **Special Ability Handlers**
-- ==================================

-- **Helper to Resolve Special Abilities** (Unchanged)
function addon:ResolveSpecialAbility(dataTable, abilityName) if dataTable.active then local abilityInfo = self.trackedAbilitiesByName[abilityName] local iconSpellIdToUse = abilityInfo and abilityInfo.iconSpellId addon:DebugPrint(string.format("%s Resolve Triggered (Damage: %d)", abilityName, dataTable.totalDamage)) if dataTable.totalDamage > 0 then local sequence = { name = abilityName, iconSpellId = iconSpellIdToUse, damage = dataTable.totalDamage, hasCrit = dataTable.hasCrit, startTime = dataTable.startTime } addon:DisplayHit(sequence) end dataTable.active = false; dataTable.totalDamage = 0; dataTable.hasCrit = false; if dataTable.targets then dataTable.targets = {} end if dataTable.primaryHit then dataTable.primaryHit = false end if dataTable.displayTimer then dataTable.displayTimer:Cancel(); dataTable.displayTimer = nil; end end end

-- Fury Handlers (Unchanged)
function addon:HandleRampage(eventType, destGUID, spellId, amount, critical) local data = RAMPAGE_DATA local now = GetTime() if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then if data.active then self:ResolveSpecialAbility(data, data.NAME) end addon:DebugPrint("Rampage Start (Handler)") data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false; if data.displayTimer then data.displayTimer:Cancel() end data.displayTimer = C_Timer.NewTimer(data.DURATION + 0.1, function() self:ResolveSpecialAbility(data, data.NAME) end) elseif data.active and (now - data.startTime) <= data.DURATION then if eventType == "SPELL_DAMAGE" and data.DAMAGE_IDS[spellId] then data.totalDamage = data.totalDamage + (amount or 0) data.hasCrit = data.hasCrit or critical addon:DebugPrint(string.format("Rampage Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical))) end end end
function addon:HandleRagingBlow(eventType, destGUID, spellId, amount, critical) local data = RAGING_BLOW_DATA local now = GetTime() if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then if data.active then self:ResolveSpecialAbility(data, data.NAME) end addon:DebugPrint("Raging Blow Start (Handler)") data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false; if data.displayTimer then data.displayTimer:Cancel() end data.displayTimer = C_Timer.NewTimer(data.DURATION, function() self:ResolveSpecialAbility(data, data.NAME) end) elseif data.active and (now - data.startTime) <= data.DURATION then if eventType == "SPELL_DAMAGE" and data.DAMAGE_IDS[spellId] then data.totalDamage = data.totalDamage + (amount or 0) data.hasCrit = data.hasCrit or critical addon:DebugPrint(string.format("Raging Blow Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical))) end end end
function addon:HandleOdynsFury(eventType, destGUID, spellId, amount, critical) local data = ODYNS_FURY_DATA local now = GetTime() if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then if data.active then self:ResolveSpecialAbility(data, data.NAME) end addon:DebugPrint("Odyn's Fury Start (Handler)") data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false; if data.displayTimer then data.displayTimer:Cancel() end data.displayTimer = C_Timer.NewTimer(data.DURATION + 0.1, function() self:ResolveSpecialAbility(data, data.NAME) end) elseif data.active and (now - data.startTime) <= (data.DURATION + 0.5) then if (eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE") and (data.DAMAGE_IDS[spellId] or spellId == data.CAST_ID) then data.totalDamage = data.totalDamage + (amount or 0) data.hasCrit = data.hasCrit or critical addon:DebugPrint(string.format("OF Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical))) end end end
function addon:HandleThunderBlast(eventType, destGUID, spellId, amount, critical) local data = THUNDER_BLAST_DATA local now = GetTime() if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then if data.active then self:ResolveSpecialAbility(data, data.NAME) end addon:DebugPrint("Thunder Blast Start (Handler)") data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false; if data.displayTimer then data.displayTimer:Cancel() end data.displayTimer = C_Timer.NewTimer(data.DURATION, function() self:ResolveSpecialAbility(data, data.NAME) end) elseif data.active and (now - data.startTime) <= data.DURATION then if eventType == "SPELL_DAMAGE" and (data.PRIMARY_DAMAGE_IDS[spellId] or data.SECONDARY_DAMAGE_IDS[spellId]) then data.totalDamage = data.totalDamage + (amount or 0) data.hasCrit = data.hasCrit or critical addon:DebugPrint(string.format("TB Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical))) end end end

-- Arms Handlers (Unchanged)
function addon:HandleCleave(eventType, destGUID, spellId, amount, critical) local data = CLEAVE_DATA local now = GetTime() if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then if data.active then self:ResolveSpecialAbility(data, data.NAME) end addon:DebugPrint("Cleave Start (Handler)") data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false; if data.displayTimer then data.displayTimer:Cancel() end data.displayTimer = C_Timer.NewTimer(data.DURATION, function() self:ResolveSpecialAbility(data, data.NAME) end) elseif data.active and (now - data.startTime) <= data.DURATION then if eventType == "SPELL_DAMAGE" and data.DAMAGE_IDS[spellId] then data.totalDamage = data.totalDamage + (amount or 0) data.hasCrit = data.hasCrit or critical addon:DebugPrint(string.format("Cleave Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical))) end end end

-- Protection Handlers (New)
function addon:HandleRevenge(eventType, destGUID, spellId, amount, critical)
    local data = REVENGE_DATA
    local now = GetTime()
    if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then
        if data.active then self:ResolveSpecialAbility(data, data.NAME) end
        addon:DebugPrint("Revenge Start (Handler)")
        data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false;
        if data.displayTimer then data.displayTimer:Cancel() end
        data.displayTimer = C_Timer.NewTimer(data.DURATION + 0.1, function() self:ResolveSpecialAbility(data, data.NAME) end) -- Slightly longer timer to catch bonus hits
    elseif data.active and (now - data.startTime) <= data.DURATION then
        if eventType == "SPELL_DAMAGE" and data.DAMAGE_IDS[spellId] then
            data.totalDamage = data.totalDamage + (amount or 0)
            data.hasCrit = data.hasCrit or critical
            addon:DebugPrint(string.format("Revenge Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical)))
        end
    end
end

function addon:HandleShieldCharge(eventType, destGUID, spellId, amount, critical)
    local data = SHIELD_CHARGE_DATA
    local now = GetTime()
    if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then
        if data.active then self:ResolveSpecialAbility(data, data.NAME) end
        addon:DebugPrint("Shield Charge Start (Handler)")
        data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false;
        if data.displayTimer then data.displayTimer:Cancel() end
        data.displayTimer = C_Timer.NewTimer(data.DURATION, function() self:ResolveSpecialAbility(data, data.NAME) end)
    elseif data.active and (now - data.startTime) <= data.DURATION then
        if eventType == "SPELL_DAMAGE" and data.DAMAGE_IDS[spellId] then -- All hits use same ID
            data.totalDamage = data.totalDamage + (amount or 0)
            data.hasCrit = data.hasCrit or critical
            addon:DebugPrint(string.format("Shield Charge Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical)))
        end
    end
end

-- Shared Handlers (Modified/Verified for Spec Data)
function addon:HandleDemolish(eventType, destGUID, spellId, amount, critical)
    local data = DEMOLISH_DATA -- Shared data table
    local now = GetTime()
    if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then
        if data.active then self:ResolveSpecialAbility(data, data.NAME) end
        addon:DebugPrint("Demolish Start (Handler - "..self.currentSpec..")")
        data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false;
        if data.displayTimer then data.displayTimer:Cancel() end
        data.displayTimer = C_Timer.NewTimer(data.DURATION + 0.1, function() self:ResolveSpecialAbility(data, data.NAME) end)
    elseif data.active and (now - data.startTime) <= data.DURATION then
        if eventType == "SPELL_DAMAGE" and data.DAMAGE_IDS[spellId] then
            data.totalDamage = data.totalDamage + (amount or 0)
            data.hasCrit = data.hasCrit or critical
            addon:DebugPrint(string.format("Demolish Hit ("..self.currentSpec.."): Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical)))
        end
    end
end
function addon:HandleBladestorm(eventType, destGUID, spellId, amount, critical) local data = BLADESTORM_DATA local now = GetTime() local isKnownCastId = (spellId == data.CAST_ID or spellId == 46924) if eventType == "SPELL_CAST_SUCCESS" and isKnownCastId then if data.active then self:ResolveSpecialAbility(data, data.NAME) end addon:DebugPrint("Bladestorm Start (Handler - ID: "..spellId..")") data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false; if data.displayTimer then data.displayTimer:Cancel() end local duration = data.DURATION data.displayTimer = C_Timer.NewTimer(duration + 0.1, function() self:ResolveSpecialAbility(data, data.NAME) end) elseif data.active then local isKnownDamageId = data.DAMAGE_IDS[spellId] or (spellId == 152277) if eventType == "SPELL_DAMAGE" and isKnownDamageId then if (now - data.startTime) <= (data.DURATION + 0.5) then data.totalDamage = data.totalDamage + (amount or 0) data.hasCrit = data.hasCrit or critical addon:DebugPrint(string.format("BS Hit: Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical))) end end end end
function addon:HandleExecute(eventType, destGUID, spellId, amount, critical)
    local data
    if self.currentSpec == "Fury" then
        data = EXECUTE_FURY_DATA
    elseif self.currentSpec == "Arms" then
        data = EXECUTE_ARMS_DATA
    elseif self.currentSpec == "Protection" then
        data = EXECUTE_PROT_DATA
    else
        return -- Should not happen if called correctly, but safe check
    end

    local now = GetTime()
    if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then
        if data.active then self:ResolveSpecialAbility(data, data.NAME) end
        addon:DebugPrint("Execute Start (Handler - "..self.currentSpec..")")
        data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false;
        if data.displayTimer then data.displayTimer:Cancel() end
        data.displayTimer = C_Timer.NewTimer(data.DURATION, function() self:ResolveSpecialAbility(data, data.NAME) end)

    elseif data.active and (now - data.startTime) <= data.DURATION then
        if eventType == "SPELL_DAMAGE" and data.DAMAGE_IDS[spellId] then
            data.totalDamage = data.totalDamage + (amount or 0)
            data.hasCrit = data.hasCrit or critical
            addon:DebugPrint(string.format("Execute Hit ("..self.currentSpec.."): Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical)))
        end
    end
end
function addon:HandleRavager(eventType, destGUID, spellId, amount, critical)
     local data
     if self.currentSpec == "Fury" then
         data = RAVAGER_FURY_DATA
     elseif self.currentSpec == "Arms" then
         data = RAVAGER_ARMS_DATA -- Arms uses Prot Cast ID now
     elseif self.currentSpec == "Protection" then
         data = RAVAGER_PROT_DATA
     else
         return
     end

     local now = GetTime()
     if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then
         if data.active then self:ResolveSpecialAbility(data, data.NAME) end
         addon:DebugPrint("Ravager Start (Handler - "..self.currentSpec..")")
         data.active = true; data.totalDamage = 0; data.startTime = now; data.hasCrit = false;
         if data.displayTimer then data.displayTimer:Cancel() end
         -- Using Prot duration logic as base, confirm if Arms differs
         data.displayTimer = C_Timer.NewTimer(data.DURATION + 0.5, function() self:ResolveSpecialAbility(data, data.NAME) end)

     elseif data.active and eventType == "SPELL_DAMAGE" and spellId == data.DAMAGE_ID then -- Damage ID is shared
         if (now - data.startTime) <= (data.DURATION + 0.5) then
             data.totalDamage = data.totalDamage + (amount or 0)
             data.hasCrit = data.hasCrit or critical
             addon:DebugPrint(string.format("Ravager Hit ("..self.currentSpec.."): Spell %d, +%d = %d, Crit: %s", spellId, amount or 0, data.totalDamage, tostring(critical)))
         end
     end
end
function addon:HandleThunderousRoar(eventType, destGUID, spellId, amount, critical) local data = THUNDEROUS_ROAR_DATA local now = GetTime() if eventType == "SPELL_CAST_SUCCESS" and spellId == data.CAST_ID then if data.active then self:ResolveSpecialAbility(data, data.NAME) end addon:DebugPrint("Thunderous Roar Start (Handler)") data.active = true; data.totalDamage = (amount or 0); data.startTime = now; data.hasCrit = critical or false; C_Timer.After(data.DURATION + 0.1, function() self:ResolveSpecialAbility(data, data.NAME) end) elseif data.active and (now - data.startTime) <= (data.DURATION + 0.5) then if (eventType == "SPELL_DAMAGE" and spellId == data.CAST_ID) or (eventType == "SPELL_PERIODIC_DAMAGE" and spellId == data.DOT_ID) then data.totalDamage = data.totalDamage + (amount or 0) data.hasCrit = data.hasCrit or critical addon:DebugPrint(string.format("TR Hit: Type %s, Spell %d, +%d = %d, Crit: %s", eventType, spellId, amount or 0, data.totalDamage, tostring(critical))) end end end

-- Helper Table Length (Unchanged)
function addon:TableLength(T) local count = 0; if T then for _ in pairs(T) do count = count + 1 end end; return count end

-- **On Addon Load** (Message updated)
local function OnLoad()
    addon:Init()
    addon:UpdateCurrentSpec()
    addon:InitializeAbilities()
    addon:InitializeUI()
    addon:RegisterEvents()
    addon:UpdateThunderousRoarDuration()
    if CombineHitsDB.debugMode then print("CombineHits Debug Mode is ON.") end
end

-- **Load Frame Handler** (Unchanged)
local loadFrame = CreateFrame("Frame"); loadFrame:RegisterEvent("ADDON_LOADED"); loadFrame:RegisterEvent("PLAYER_LOGIN") loadFrame:SetScript("OnEvent", function(self, event, addonName) if event == "ADDON_LOADED" and addonName == "CombineHits" then OnLoad() self:UnregisterEvent(event) elseif event == "PLAYER_LOGIN" then addon:UpdateCurrentSpec() addon:InitializeAbilities() addon:UpdateThunderousRoarDuration() end end)

-- **Debug Print Function** (Unchanged)
function addon:DebugPrint(...) if CombineHitsDB.debugMode then print("|cFF00FF00[CH Debug]|r", ...) end end

-- **Print Function** (Unchanged)
function addon:Print(...) print(...) end

-- **Update Thunderous Roar Duration** (Unchanged)
function addon:UpdateThunderousRoarDuration() local hasTalent = IsSpellKnown(THUNDEROUS_ROAR_DATA.TALENT_ID); if hasTalent then THUNDEROUS_ROAR_DATA.DURATION = THUNDEROUS_ROAR_DATA.TALENT_DURATION; addon:DebugPrint("Talent 'Thunderous Words' found. Roar duration set to", THUNDEROUS_ROAR_DATA.DURATION.."s") else THUNDEROUS_ROAR_DATA.DURATION = 10; addon:DebugPrint("Talent 'Thunderous Words' not found. Roar duration set to", THUNDEROUS_ROAR_DATA.DURATION.."s") end end

-- **Update Current Spec** (Added Protection ID and updated messages)
function addon:UpdateCurrentSpec()
    local specIndex = GetSpecialization()
    local oldSpec = self.currentSpec
    local newSpec = "Unknown"
    local _, className, classID = UnitClass("player")

    if className == "WARRIOR" and specIndex then
        local specID, specName = GetSpecializationInfo(specIndex)
        if specID == 71 then newSpec = "Arms"
        elseif specID == 72 then newSpec = "Fury"
        elseif specID == 73 then newSpec = "Protection" -- Added Protection
        end
    elseif className ~= "WARRIOR" then
         newSpec = "NotWarrior"
    end

    self.currentSpec = newSpec

    if oldSpec ~= self.currentSpec then
        self:DebugPrint(string.format("Spec changed from '%s' to '%s'", tostring(oldSpec), self.currentSpec))
        -- Update messages for supported/unsupported specs
        local isSupported = (self.currentSpec == "Fury" or self.currentSpec == "Arms" or self.currentSpec == "Protection")
        local wasSupported = (oldSpec == "Fury" or oldSpec == "Arms" or oldSpec == "Protection")

        if not isSupported and wasSupported then
             -- print("|cxFFFF8000CombineHits:|r Switched to an unsupported spec ("..self.currentSpec.."). Addon is now idle.")
        elseif isSupported and not wasSupported then
             -- print("|cFF00FF00CombineHits:|r Switched to a supported spec ("..self.currentSpec.."). Addon is now active.")
        elseif isSupported and wasSupported and oldSpec then -- Message for switching between supported specs
             -- print("|cFF00FF00CombineHits:|r Switched spec to "..self.currentSpec..".")
        end
    end
end