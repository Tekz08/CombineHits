-- CombineHits addon
local addon = {}
addon.activeSequences = {}
addon.hasWhirlwindBuff = false

-- **Ability Definitions**
local ABILITY_INFO = {
    ["Rampage"] = { isSpecial = false },
    ["Raging Blow"] = { isSpecial = false },
    ["Execute"] = { isSpecial = false },
    ["Bloodthirst"] = { isSpecial = false },
    ["Thunder Clap"] = { isSpecial = false },
    ["Thunder Blast"] = { isSpecial = true, handler = "HandleThunderBlast" },
    ["Onslaught"] = { isSpecial = false },
    ["Thunderous Roar"] = { isSpecial = true, handler = "HandleThunderousRoar" },
    ["Ravager"] = { isSpecial = true, handler = "HandleRavager" },
    ["Odyn's Fury"] = { isSpecial = true, handler = "HandleOdynsFury" },
}

-- **Special Ability Tables**
local THUNDEROUS_ROAR = {
    CAST_ID = 384318,
    DOT_ID = 397364,
    name = "Thunderous Roar",
    active = false,
    targets = {},
    totalDamage = 0,
    startTime = 0,
}

local RAVAGER = {
    CAST_ID = 228920,
    DAMAGE_ID = 156287,
    name = "Ravager",
    active = false,
    totalDamage = 0,
    startTime = 0,
    DURATION = 11,
    hasCrit = false,
}

local ODYNS_FURY = {
    CAST_ID = 385059,
    DAMAGE_IDS = {
        [385060] = true,  -- Main hand
        [385061] = true,  -- Off hand
        [385062] = true,  -- Additional strikes
    },
    name = "Odyn's Fury",
    active = false,
    targets = {},
    totalDamage = 0,
    startTime = 0,
    DURATION = 5,
    displayTimer = nil,
}

local THUNDER_BLAST = {
    BUFF_ID = 435615,  -- Thunder Blast buff
    CAST_ID = 435222,  -- Main Thunder Blast
    PRIMARY_DAMAGE_IDS = {
        [435222] = true,  -- Thunder Blast
        [436793] = true,  -- Thunder Blast (additional)
    },
    SECONDARY_DAMAGE_IDS = {
        [435791] = true,  -- Lightning Strike
        [460670] = true,  -- Lightning Strike Ground Current
    },
    name = "Thunder Blast",
    active = false,
    totalDamage = 0,
    startTime = 0,
    DURATION = 1.5,
    hasCrit = false,
    displayTimer = nil,
    primaryHit = false, -- Track if we've seen a primary Thunder Blast hit
}

-- **Initialize Saved Variables**
function addon:Init()
    CombineHitsDB = CombineHitsDB or {}
    for k, v in pairs(self.defaults) do
        if CombineHitsDB[k] == nil then
            CombineHitsDB[k] = v
        end
    end
    if not CombineHitsDB.framePosition.point then
        CombineHitsDB.framePosition.point = "CENTER"
    end
    if CombineHitsDB.isLocked == nil then
        CombineHitsDB.isLocked = false
    end
    if CombineHitsDB.frameVisible == nil then
        CombineHitsDB.frameVisible = true
    end
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
    combineWindow = 2.5,
    leaderboard = {},
    isLocked = false
}

-- **Initialize Abilities**
function addon:InitializeAbilities()
    addon.trackedAbilities = {}
    for name, info in pairs(ABILITY_INFO) do
        local spellInfo = C_Spell.GetSpellInfo(name)
        if spellInfo then
            addon.trackedAbilities[spellInfo.spellID] = {
                name = name,
                isSpecial = info.isSpecial,
                handler = info.handler
            }
        end
    end
end

-- **Create Main Frame**
function addon:CreateMainFrame()
    local frame = CreateFrame("Frame", "CombineHitsMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(CombineHitsDB.frameWidth, CombineHitsDB.frameHeight)
    frame:SetPoint(CombineHitsDB.framePosition.point, UIParent, CombineHitsDB.framePosition.point, CombineHitsDB.framePosition.x, CombineHitsDB.framePosition.y)
    frame:SetFrameStrata("MEDIUM")
    frame:SetMovable(true)
    frame:EnableMouse(not CombineHitsDB.isLocked)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, _, x, y = frame:GetPoint()
        CombineHitsDB.framePosition.point = point
        CombineHitsDB.framePosition.x = x
        CombineHitsDB.framePosition.y = y
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
    end)
    frame.lockButton = lockButton
    addon:UpdateFrameAppearance(frame)
    return frame
end

-- **Update Frame Appearance**
function addon:UpdateFrameAppearance(frame)
    if CombineHitsDB.isLocked then
        frame:SetBackdrop(nil)
        frame.lockButton:Hide()
        frame:EnableMouse(false)
    else
        frame:SetBackdrop({
            bgFile = "Interface/Tooltips/UI-Tooltip-Background",
            tile = true,
            tileSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        frame:SetBackdropColor(0, 0, 0, CombineHitsDB.frameAlpha)
        frame.lockButton:Show()
        frame:EnableMouse(true)
    end
end

-- **Create Display Frames**
function addon:CreateDisplayFrames()
    addon.displayFrames = {}
    for i = 1, CombineHitsDB.maxDisplayed do
        local frame = CreateFrame("Frame", nil, addon.mainFrame)
        frame:SetSize(CombineHitsDB.frameWidth - 20, 30)
        local icon = frame:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20 * 1.5, 20 * 1.5)
        icon:SetPoint("LEFT", frame, "LEFT", 5, 0)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local text = frame:CreateFontString(nil, "OVERLAY")
        text:SetFont(addon:GetFont(), 20, "OUTLINE")
        text:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        text:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
        text:SetJustifyH("LEFT")
        text:SetTextColor(CombineHitsDB.textColor.r, CombineHitsDB.textColor.g, CombineHitsDB.textColor.b)
        frame:SetPoint("BOTTOMLEFT", addon.mainFrame, "BOTTOMLEFT", 0, (i-1) * 30)
        frame:SetAlpha(0)
        frame.icon = icon
        frame.text = text
        frame.active = false
        frame.fadeStart = 0
        frame.fadeTimer = nil
        table.insert(addon.displayFrames, frame)
    end
end

-- **Get Font Helper**
function addon:GetFont()
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and LSM:IsValid("font", "Expressway") then
        return LSM:Fetch("font", "Expressway")
    end
    return "Fonts\\FRIZQT__.TTF"
end

-- **Combat Log Event Handler**
function addon:OnCombatLogEvent(...)
    local timestamp, eventType, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical = CombatLogGetCurrentEventInfo()
    local now = GetTime()
    if sourceGUID ~= UnitGUID("player") then return end

    -- Handle Ravager events first
    if spellId == RAVAGER.CAST_ID or spellId == RAVAGER.DAMAGE_ID then
        if eventType == "SPELL_CAST_SUCCESS" then
            self:HandleRavager(eventType, spellId, amount, critical)
            return
        elseif eventType == "SPELL_DAMAGE" then
            self:HandleRavager(eventType, spellId, amount, critical)
            return
        end
    end
    
    -- Rest of the combat log handling...

    if eventType == "SPELL_CAST_SUCCESS" then
        local ability = addon.trackedAbilities[spellId]
        if ability then
            if ability.isSpecial then
                addon[ability.handler](addon, eventType, destGUID, spellId, amount, critical)
            end
            if not ability.isSpecial then
                local sequenceKey = ability.name .. "_" .. now
                addon.activeSequences[sequenceKey] = {
                    name = ability.name,
                    spellId = spellId,
                    damage = 0,
                    hasCrit = false,
                    startTime = now,
                    lastHitTime = now,
                    whirlwindActive = addon.hasWhirlwindBuff
                }
                C_Timer.After(2, function()
                    local sequence = addon.activeSequences[sequenceKey]
                    if sequence and sequence.damage > 0 then
                        addon:DisplayHit(sequence)
                        addon.activeSequences[sequenceKey] = nil
                    end
                end)
            end
        end
    elseif eventType == "SPELL_DAMAGE" then
        for key, sequence in pairs(addon.activeSequences) do
            if spellName == sequence.name and (now - sequence.startTime) <= 2 then
                sequence.damage = sequence.damage + (amount or 0)
                sequence.hasCrit = sequence.hasCrit or critical
                sequence.lastHitTime = now
            end
        end
        if spellId == THUNDEROUS_ROAR.CAST_ID then
            addon:HandleThunderousRoar(eventType, destGUID, spellId, amount, critical)
        end
        if ODYNS_FURY.DAMAGE_IDS[spellId] then
            addon:HandleOdynsFury(eventType, destGUID, spellId, amount, critical)
        end
        if spellId == THUNDER_BLAST.BUFF_ID or THUNDER_BLAST.PRIMARY_DAMAGE_IDS[spellId] then
            self:HandleThunderBlast(eventType, destGUID, spellId, amount, critical)
            return -- Add return to prevent further processing
        end
    elseif eventType == "SPELL_PERIODIC_DAMAGE" then
        if spellId == THUNDEROUS_ROAR.DOT_ID then
            addon:HandleThunderousRoar(eventType, destGUID, spellId, amount, critical)
        end
    elseif eventType == "SPELL_AURA_APPLIED" or eventType == "SPELL_AURA_REMOVED" then
        if spellId == THUNDEROUS_ROAR.DOT_ID then
            addon:HandleThunderousRoar(eventType, destGUID, spellId, amount, critical)
        end
        if ODYNS_FURY.DAMAGE_IDS[spellId] then
            addon:HandleOdynsFury(eventType, destGUID, spellId, amount, critical)
        end
    end
end

-- **Unit Aura Event Handler**
function addon:OnUnitAura(unit)
    if unit == "player" then
        addon.hasWhirlwindBuff = AuraUtil.FindAuraByName("Whirlwind", "player", "HELPFUL") ~= nil
    end
end

-- **Display Hit**
function addon:DisplayHit(sequence)
    for i = #addon.displayFrames, 2, -1 do
        local currentFrame = addon.displayFrames[i]
        local prevFrame = addon.displayFrames[i-1]
        if prevFrame.active then
            currentFrame.icon:SetTexture(prevFrame.icon:GetTexture())
            currentFrame.text:SetText(prevFrame.text:GetText())
            currentFrame.text:SetTextColor(prevFrame.text:GetTextColor())
            currentFrame.active = true
            currentFrame.fadeStart = prevFrame.fadeStart
            if currentFrame.fadeTimer then
                currentFrame.fadeTimer:Cancel()
            end
            local remainingTime = math.max(0, 2 - (GetTime() - prevFrame.fadeStart))
            currentFrame.fadeTimer = C_Timer.NewTimer(remainingTime, function()
                addon:FadeOut(currentFrame)
            end)
            currentFrame:SetAlpha(prevFrame:GetAlpha())
        else
            addon:FadeOut(currentFrame)
        end
    end
    local targetFrame = addon.displayFrames[1]
    if targetFrame.fadeTimer then
        targetFrame.fadeTimer:Cancel()
    end
    targetFrame:SetAlpha(0)
    
    local spellInfo = C_Spell.GetSpellInfo(sequence.spellId)
    
    if spellInfo and spellInfo.iconID then
        targetFrame.icon:SetTexture(spellInfo.iconID)
    else
        targetFrame.icon:SetTexture(134400)
    end
    
    targetFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local text = addon:FormatNumber(sequence.damage)
    targetFrame.text:SetText(text)
    
    if sequence.hasCrit then
        targetFrame.text:SetTextColor(CombineHitsDB.critColor.r, CombineHitsDB.critColor.g, CombineHitsDB.critColor.b)
    else
        targetFrame.text:SetTextColor(CombineHitsDB.textColor.r, CombineHitsDB.textColor.g, CombineHitsDB.textColor.b)
    end
    
    targetFrame.active = true
    targetFrame.fadeStart = GetTime()
    UIFrameFadeIn(targetFrame, 0.3, 0, 1)
    targetFrame.fadeTimer = C_Timer.NewTimer(2, function()
        addon:FadeOut(targetFrame)
    end)

    -- Save to leaderboard if it's a new record
    if sequence.damage > 0 then
        local currentRecord = CombineHitsDB.leaderboard[sequence.name]
        if not currentRecord or sequence.damage > currentRecord.damage then
            local zone = GetRealZoneText()
            local subZone = GetSubZoneText()
            local targetName = UnitName("target") or "Unknown Target"
            
            CombineHitsDB.leaderboard[sequence.name] = {
                damage = sequence.damage,
                timestamp = time(),
                zone = zone,
                subZone = subZone,
                target = targetName
            }
            print(string.format("New record for %s: %s! (Target: %s)", 
                sequence.name, 
                addon:FormatNumber(sequence.damage),
                targetName
            ))
        end
    end
end

-- **Fade Out Frame**
function addon:FadeOut(frame)
    if not frame.active then return end
    frame.active = false
    UIFrameFadeOut(frame, 0.3, frame:GetAlpha(), 0)
    C_Timer.After(0.3, function()
        frame.text:SetText("")
        frame.icon:SetTexture(nil)
        frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end)
    if frame.fadeTimer then
        frame.fadeTimer:Cancel()
        frame.fadeTimer = nil
    end
end

-- **Format Number**
function addon:FormatNumber(number)
    if number >= 1000000 then
        return string.format("%.1fM", number / 1000000)
    elseif number >= 1000 then
        return string.format("%dK", math.floor(number / 1000))
    else
        return tostring(number)
    end
end

-- **Slash Commands**
SLASH_COMBINEHITS1 = "/ch"
SLASH_COMBINEHITS2 = "/combinehits"
SlashCmdList["COMBINEHITS"] = function(msg)
    local cmd = msg:trim():lower()
    if cmd == "lock" then
        CombineHitsDB.isLocked = not CombineHitsDB.isLocked
        addon:UpdateFrameAppearance(addon.mainFrame)
        print("Frame " .. (CombineHitsDB.isLocked and "locked" or "unlocked"))
    elseif cmd == "reset" then
        CombineHitsDB.framePosition.point = "CENTER"
        CombineHitsDB.framePosition.x = 0
        CombineHitsDB.framePosition.y = 0
        addon.mainFrame:ClearAllPoints()
        addon.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        print("Frame position reset to center")
    elseif cmd == "lb" then
        if addon.leaderboardFrame:IsShown() then
            addon.leaderboardFrame:Hide()
        else
            addon:UpdateLeaderboard()
            addon.leaderboardFrame:Show()
        end
    else
        print("CombineHits commands:")
        print("  /ch lock - Toggle frame lock")
        print("  /ch reset - Reset position")
        print("  /ch lb - Toggle leaderboard")
    end
end

-- **Create Leaderboard Frame**
function addon:CreateLeaderboardFrame()
    local f = CreateFrame("Frame", "CombineHitsLeaderboard", UIParent, "BasicFrameTemplateWithInset")
    addon.leaderboardFrame = f
    f:SetSize(600, 480)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    f.TitleText:SetText("Big Hits Leaderboard")
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    content:SetSize(584, 452)
    f.content = content
    local clearButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearButton:SetSize(100, 25)
    clearButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    clearButton:SetText("Clear Records")
    clearButton:SetScript("OnClick", function()
        StaticPopup_Show("COMBINEHITS_CLEAR_LEADERBOARD")
    end)
    StaticPopupDialogs["COMBINEHITS_CLEAR_LEADERBOARD"] = {
        text = "Are you sure you want to clear all leaderboard records?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            CombineHitsDB.leaderboard = {}
            print("CombineHits: Leaderboard has been cleared.")
            addon:UpdateLeaderboard()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    f:Hide()
    return f
end

-- **Update Leaderboard**
function addon:UpdateLeaderboard()
    local frame = addon.leaderboardFrame
    local content = frame.content
    
    -- Clear existing entries
    for _, child in pairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Convert records to sorted array
    local sortedRecords = {}
    for ability, record in pairs(CombineHitsDB.leaderboard) do
        table.insert(sortedRecords, {name = ability, data = record})
    end
    
    -- Sort records
    table.sort(sortedRecords, function(a, b) return a.name < b.name end)

    local columnWidth = (content:GetWidth() - 40) / 2
    local yOffset = 0
    for i = 1, #sortedRecords, 2 do
        -- Left Entry
        local leftEntry = CreateFrame("Frame", nil, content)
        leftEntry:SetSize(columnWidth, 85)  -- Increased height to accommodate new line
        leftEntry:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset - 30)
        
        -- Header (Ability name and damage)
        local leftHeader = leftEntry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        leftHeader:SetFont(addon:GetFont(), 14, "OUTLINE")
        leftHeader:SetPoint("TOPLEFT", leftEntry, "TOPLEFT", 0, 0)
        leftHeader:SetWidth(columnWidth)
        leftHeader:SetJustifyH("LEFT")
        leftHeader:SetText(string.format("%s: |cffFFD700%s|r", sortedRecords[i].name, addon:FormatNumber(sortedRecords[i].data.damage)))
        
        -- Location
        local leftLocation = leftEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leftLocation:SetFont(addon:GetFont(), 12, "OUTLINE")
        leftLocation:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 20, -5)
        leftLocation:SetWidth(columnWidth - 20)
        leftLocation:SetJustifyH("LEFT")
        local leftLocationText = sortedRecords[i].data.zone
        if sortedRecords[i].data.subZone and sortedRecords[i].data.subZone ~= "" then
            leftLocationText = leftLocationText .. " - " .. sortedRecords[i].data.subZone
        end
        leftLocation:SetText("|cffAAAAAA" .. leftLocationText .. "|r")
        
        -- Target (new)
        local leftTarget = leftEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leftTarget:SetFont(addon:GetFont(), 12, "OUTLINE")
        leftTarget:SetPoint("TOPLEFT", leftLocation, "BOTTOMLEFT", 0, -5)
        leftTarget:SetWidth(columnWidth - 20)
        leftTarget:SetJustifyH("LEFT")
        if sortedRecords[i].data.target then
            leftTarget:SetText("|cffFFFFFFTarget: " .. sortedRecords[i].data.target .. "|r")
        end
        
        -- Time
        local leftTime = leftEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leftTime:SetFont(addon:GetFont(), 12, "OUTLINE")
        leftTime:SetPoint("TOPLEFT", leftTarget, "BOTTOMLEFT", 0, -5)
        leftTime:SetWidth(columnWidth - 20)
        leftTime:SetJustifyH("LEFT")
        local leftTimeString = date("%m/%d/%Y %I:%M %p", sortedRecords[i].data.timestamp)
        leftTime:SetText("|cffAAAAAA" .. leftTimeString .. "|r")

        -- Right Entry
        if sortedRecords[i + 1] then
            local rightEntry = CreateFrame("Frame", nil, content)
            rightEntry:SetSize(columnWidth, 85)  -- Increased height to accommodate new line
            rightEntry:SetPoint("TOPLEFT", content, "TOPLEFT", columnWidth + 30, -yOffset - 30)
            
            -- Header
            local rightHeader = rightEntry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            rightHeader:SetFont(addon:GetFont(), 14, "OUTLINE")
            rightHeader:SetPoint("TOPLEFT", rightEntry, "TOPLEFT", 0, 0)
            rightHeader:SetWidth(columnWidth)
            rightHeader:SetJustifyH("LEFT")
            rightHeader:SetText(string.format("%s: |cffFFD700%s|r", sortedRecords[i + 1].name, addon:FormatNumber(sortedRecords[i + 1].data.damage)))
            
            -- Location
            local rightLocation = rightEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            rightLocation:SetFont(addon:GetFont(), 12, "OUTLINE")
            rightLocation:SetPoint("TOPLEFT", rightHeader, "BOTTOMLEFT", 20, -5)
            rightLocation:SetWidth(columnWidth - 20)
            rightLocation:SetJustifyH("LEFT")
            local rightLocationText = sortedRecords[i + 1].data.zone
            if sortedRecords[i + 1].data.subZone and sortedRecords[i + 1].data.subZone ~= "" then
                rightLocationText = rightLocationText .. " - " .. sortedRecords[i + 1].data.subZone
            end
            rightLocation:SetText("|cffAAAAAA" .. rightLocationText .. "|r")
            
            -- Target (new)
            local rightTarget = rightEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            rightTarget:SetFont(addon:GetFont(), 12, "OUTLINE")
            rightTarget:SetPoint("TOPLEFT", rightLocation, "BOTTOMLEFT", 0, -5)
            rightTarget:SetWidth(columnWidth - 20)
            rightTarget:SetJustifyH("LEFT")
            if sortedRecords[i + 1].data.target then
                rightTarget:SetText("|cffFFFFFFTarget: " .. sortedRecords[i + 1].data.target .. "|r")
            end
            
            -- Time
            local rightTime = rightEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            rightTime:SetFont(addon:GetFont(), 12, "OUTLINE")
            rightTime:SetPoint("TOPLEFT", rightTarget, "BOTTOMLEFT", 0, -5)
            rightTime:SetWidth(columnWidth - 20)
            rightTime:SetJustifyH("LEFT")
            local rightTimeString = date("%m/%d/%Y %I:%M %p", sortedRecords[i + 1].data.timestamp)
            rightTime:SetText("|cffAAAAAA" .. rightTimeString .. "|r")
        end
        yOffset = yOffset + 85  -- Increased offset to match new height
    end
end

-- **Initialize UI**
function addon:InitializeUI()
    addon.mainFrame = addon:CreateMainFrame()
    addon:CreateDisplayFrames()
    addon:CreateLeaderboardFrame()
    if CombineHitsDB.frameVisible then
        addon.mainFrame:Show()
    else
        addon.mainFrame:Hide()
    end
    addon:UpdateFrameAppearance(addon.mainFrame)
end

-- **Register Events**
function addon:RegisterEvents()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    frame:RegisterEvent("UNIT_AURA")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "COMBAT_LOG_EVENT_UNFILTERED" then
            addon:OnCombatLogEvent(...)
        elseif event == "UNIT_AURA" then
            addon:OnUnitAura(...)
        end
    end)
end

-- **Special Ability Handlers**
function addon:HandleThunderousRoar(eventType, destGUID, spellId, amount, critical)
    if eventType == "SPELL_CAST_SUCCESS" and spellId == THUNDEROUS_ROAR.CAST_ID then
        THUNDEROUS_ROAR.active = true
        THUNDEROUS_ROAR.targets = {}
        THUNDEROUS_ROAR.totalDamage = 0
        THUNDEROUS_ROAR.startTime = GetTime()
        
        C_Timer.After(10, function()
            if THUNDEROUS_ROAR.active and THUNDEROUS_ROAR.totalDamage > 0 then
                local sequence = {
                    name = THUNDEROUS_ROAR.name,
                    spellId = THUNDEROUS_ROAR.CAST_ID,
                    damage = THUNDEROUS_ROAR.totalDamage,
                    hasCrit = true,
                }
                addon:DisplayHit(sequence)
                THUNDEROUS_ROAR.active = false
                THUNDEROUS_ROAR.totalDamage = 0
                THUNDEROUS_ROAR.targets = {}
            end
        end)
    elseif THUNDEROUS_ROAR.active then
        if eventType == "SPELL_DAMAGE" and spellId == THUNDEROUS_ROAR.CAST_ID then
            THUNDEROUS_ROAR.totalDamage = THUNDEROUS_ROAR.totalDamage + (amount or 0)
        elseif eventType == "SPELL_PERIODIC_DAMAGE" and spellId == THUNDEROUS_ROAR.DOT_ID then
            THUNDEROUS_ROAR.totalDamage = THUNDEROUS_ROAR.totalDamage + (amount or 0)
        end
    end
end

function addon:HandleRavager(eventType, spellId, amount, critical)
    local now = GetTime()
    
    if eventType == "SPELL_CAST_SUCCESS" and spellId == RAVAGER.CAST_ID then
        RAVAGER.active = true
        RAVAGER.totalDamage = 0
        RAVAGER.startTime = now
        RAVAGER.hasCrit = false
        RAVAGER.displayTimer = C_Timer.NewTimer(RAVAGER.DURATION + 0.5, function()
            if RAVAGER.active and RAVAGER.totalDamage > 0 then
                local sequence = {
                    name = RAVAGER.name,
                    spellId = RAVAGER.CAST_ID,
                    damage = RAVAGER.totalDamage,
                    hasCrit = RAVAGER.hasCrit,
                }
                
                addon:DisplayHit(sequence)
            else
                RAVAGER.active = false
                RAVAGER.totalDamage = 0
                RAVAGER.hasCrit = false
                RAVAGER.displayTimer = nil
            end
        end)
        
    elseif eventType == "SPELL_DAMAGE" and spellId == RAVAGER.DAMAGE_ID then
        if RAVAGER.active and (now - RAVAGER.startTime) <= (RAVAGER.DURATION + 0.5) then
            local newTotal = RAVAGER.totalDamage + (amount or 0)
            RAVAGER.totalDamage = newTotal
            RAVAGER.hasCrit = RAVAGER.hasCrit or critical
        end
    end
end

function addon:HandleOdynsFury(eventType, destGUID, spellId, amount, critical)
    if eventType == "SPELL_CAST_SUCCESS" and spellId == ODYNS_FURY.CAST_ID then
        ODYNS_FURY.active = true
        ODYNS_FURY.targets = {}
        ODYNS_FURY.totalDamage = 0
        ODYNS_FURY.startTime = GetTime()
        
        -- Set up display timer
        if ODYNS_FURY.displayTimer then
            ODYNS_FURY.displayTimer:Cancel()
        end
        
        ODYNS_FURY.displayTimer = C_Timer.NewTimer(ODYNS_FURY.DURATION, function()
            if ODYNS_FURY.active and ODYNS_FURY.totalDamage > 0 then
                local sequence = {
                    name = ODYNS_FURY.name,
                    spellId = ODYNS_FURY.CAST_ID,
                    damage = ODYNS_FURY.totalDamage,
                    hasCrit = true,
                }
                self:DisplayHit(sequence)
                
                -- Reset state
                ODYNS_FURY.active = false
                ODYNS_FURY.totalDamage = 0
                ODYNS_FURY.targets = {}
                ODYNS_FURY.displayTimer = nil
            end
        end)
        
    elseif ODYNS_FURY.active then
        if (now - ODYNS_FURY.startTime) > ODYNS_FURY.DURATION then
            return
        end
        
        -- Handle all damage events
        if (eventType == "SPELL_DAMAGE" or eventType == "SPELL_PERIODIC_DAMAGE") and 
           (ODYNS_FURY.DAMAGE_IDS[spellId] or spellId == ODYNS_FURY.CAST_ID) then
            local newTotal = ODYNS_FURY.totalDamage + (amount or 0)
            ODYNS_FURY.totalDamage = newTotal
            
        elseif eventType == "SPELL_AURA_APPLIED" and ODYNS_FURY.DAMAGE_IDS[spellId] then
            ODYNS_FURY.targets[destGUID] = true
            
        elseif eventType == "SPELL_AURA_REMOVED" and ODYNS_FURY.DAMAGE_IDS[spellId] then
            ODYNS_FURY.targets[destGUID] = nil
        end
    end
end

function addon:HandleThunderBlast(eventType, destGUID, spellId, amount, critical)
    -- Activate only on primary Thunder Blast damage
    if eventType == "SPELL_DAMAGE" and THUNDER_BLAST.PRIMARY_DAMAGE_IDS[spellId] and not THUNDER_BLAST.active then
        THUNDER_BLAST.active = true
        THUNDER_BLAST.totalDamage = 0
        THUNDER_BLAST.startTime = GetTime()
        THUNDER_BLAST.hasCrit = false
        THUNDER_BLAST.primaryHit = true
        
        -- Set up display timer
        if THUNDER_BLAST.displayTimer then
            THUNDER_BLAST.displayTimer:Cancel()
        end
        
        THUNDER_BLAST.displayTimer = C_Timer.NewTimer(THUNDER_BLAST.DURATION, function()
            if THUNDER_BLAST.totalDamage > 0 and THUNDER_BLAST.primaryHit then
                local sequence = {
                    name = THUNDER_BLAST.name,
                    spellId = THUNDER_BLAST.CAST_ID,
                    damage = THUNDER_BLAST.totalDamage,
                    hasCrit = THUNDER_BLAST.hasCrit,
                }
                self:DisplayHit(sequence)
            end
            
            -- Reset state
            THUNDER_BLAST.active = false
            THUNDER_BLAST.totalDamage = 0
            THUNDER_BLAST.hasCrit = false
            THUNDER_BLAST.primaryHit = false
            THUNDER_BLAST.displayTimer = nil
        end)
    end
    
    -- Track damage only if we're active and have seen a primary hit
    if THUNDER_BLAST.active and THUNDER_BLAST.primaryHit then
        if eventType == "SPELL_DAMAGE" and 
           (THUNDER_BLAST.PRIMARY_DAMAGE_IDS[spellId] or THUNDER_BLAST.SECONDARY_DAMAGE_IDS[spellId]) then
            local newTotal = THUNDER_BLAST.totalDamage + (amount or 0)
            THUNDER_BLAST.totalDamage = newTotal
            THUNDER_BLAST.hasCrit = THUNDER_BLAST.hasCrit or critical
        end
    end
end

-- **On Addon Load**
local function OnLoad()
    addon:Init()
    addon:InitializeAbilities()
    addon:InitializeUI()
    addon:RegisterEvents()
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:RegisterEvent("PLAYER_LOGIN")
loadFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == "CombineHits" then
        OnLoad()
    elseif event == "PLAYER_LOGIN" then
        -- Additional login logic if needed
    end
end)