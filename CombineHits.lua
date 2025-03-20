-- CombineHits addon
local addonName, addon = ...
local CH = CreateFrame("Frame", "CombineHitsFrame")
CH:RegisterEvent("ADDON_LOADED")

-- Default settings
addon.defaults = {
    framePosition = { x = 0, y = 0, point = "CENTER" },
    fontSize = 12,
    maxDisplayed = 4,
    fadeTime = 3,
    frameWidth = 260,
    frameHeight = 150,
    frameAlpha = 0.9,
    frameVisible = true,
    textColor = { r = 1, g = 1, b = 1 },
    critColor = { r = 1, g = 0.5, b = 0 },
    blacklistedSpells = {},
    combineWindow = 2.5,
    leaderboard = {}, -- Store ability records
}

-- Fury Warrior ability info
local ABILITY_DAMAGE_SPELLS = {
    -- Rampage and its damage spell IDs
    [184367] = { -- Rampage cast
        name = "Rampage",
        spellId = 184367,
        damageSpells = {
            [184707] = true,  -- Rampage Hit 1
            [184709] = true,  -- Rampage Hit 2
            [201364] = true,  -- Rampage Hit 3
            [201363] = true,  -- Rampage Hit 4
        }
    },
    -- Raging Blow and its damage spell IDs
    [85288] = { -- Raging Blow cast
        name = "Raging Blow",
        spellId = 85288,
        damageSpells = {
            [85288] = true,   -- Main hand
            [96103] = true,   -- Raging Blow 1
            [85384] = true,   -- Off hand/Raging Blow 2
        }
    },
    -- Execute and its damage spell IDs
    [5308] = { -- Execute cast
        name = "Execute",
        spellId = 5308,
        damageSpells = {
            [280849] = true,  -- Execute 1
            [163558] = true,  -- Execute 2
            [5308] = true,    -- Low health Execute
        }
    },
    -- Bloodthirst
    [23881] = { -- Bloodthirst cast
        name = "Bloodthirst",
        spellId = 23881,
        damageSpells = {
            [23881] = true,   -- Bloodthirst damage
        }
    },
    -- Thunder Clap
    [6343] = { -- Thunder Clap cast
        name = "Thunder Clap",
        spellId = 6343,
        damageSpells = {
            [6343] = true,      -- Thunder Clap primary damage
            [436792] = true,    -- Thunder Clap additional damage
            [435791] = true,    -- Lightning Strike
            [460670] = true,    -- Lightning Strike Ground Current
        }
    },
    -- Thunder Blast
    [435222] = { -- Thunder Blast cast
        name = "Thunder Blast",
        spellId = 435222,
        damageSpells = {
            [435222] = true,    -- Thunder Blast primary damage
            [436793] = true,    -- Thunder Blast additional damage
            [435791] = true,    -- Lightning Strike
            [460670] = true,    -- Lightning Strike Ground Current
        }
    },
    -- Onslaught
    [315720] = { -- Onslaught cast
        name = "Onslaught",
        spellId = 315720,
        damageSpells = {
            [396718] = true,  -- Onslaught damage
        }
    },
    -- Thunderous Roar (special tracking)
    [384318] = { -- Thunderous Roar cast
        name = "Thunderous Roar",
        spellId = 384318,
        isThunderousRoar = true,  -- Flag for special handling
        damageSpells = {
            [384318] = true,  -- Initial hits
            [397364] = true,  -- DoT damage
        }
    },
    -- Ravager (special tracking)
    [228920] = { -- Ravager cast
        name = "Ravager",
        spellId = 228920,
        isRavager = true,  -- Flag for special handling
        damageSpells = {
            [156287] = true,  -- Update to correct damage spell ID
        }
    },
    -- Odyn's Fury (special tracking)
    [385059] = { -- Odyn's Fury cast
        name = "Odyn's Fury",
        spellId = 385059,
        isOdynsFury = true,  -- Flag for special handling
        damageSpells = {
            [385060] = true,  -- Main hand and DoT
            [385061] = true,  -- Off-hand
            [385062] = true,  -- Additional damage
        }
    },
}

-- Whirlwind buff tracking
local WHIRLWIND_BUFF_ID = 85739  -- Whirlwind buff ID
addon.hasWhirlwindBuff = false

local FURY_ABILITIES = {
    -- Rampage
    [184707] = { name = "Rampage", hits = 4, isRampage = true },
    [184709] = { name = "Rampage", hits = 4, isRampage = true },
    [201364] = { name = "Rampage", hits = 4, isRampage = true },
    [201363] = { name = "Rampage", hits = 4, isRampage = true },
    
    -- Raging Blow
    [85288] = { name = "Raging Blow", hits = 2, isRagingBlow = true },
    [96103] = { name = "Raging Blow", hits = 2, isRagingBlow = true },
    [85384] = { name = "Raging Blow", hits = 2, isRagingBlow = true },
    
    -- Execute
    [280849] = { name = "Execute", hits = 2, isExecute = true },  -- Execute 1
    [163558] = { name = "Execute", hits = 2, isExecute = true },  -- Execute 2
    [5308] = { name = "Execute", hits = 2, isExecute = true },    -- Low health Execute
    
    -- Single hit abilities
    [23881] = { name = "Bloodthirst", hits = 1 },
    [396718] = { name = "Onslaught", hits = 1 },  -- Update damage spell ID
}

-- Track active ability hits
addon.activeSequence = nil  -- Current active sequence being tracked

-- Add to the top with other constants
local THUNDEROUS_ROAR = {
    CAST_ID = 384318,
    DOT_ID = 397364,
    name = "Thunderous Roar",
    active = false,
    targets = {},
    totalDamage = 0,
}

-- Add near the top with other constants
local RAVAGER = {
    CAST_ID = 228920,
    DAMAGE_ID = 156287,  -- Add damage spell ID
    name = "Ravager",
    active = false,
    totalDamage = 0,
    startTime = 0,
    DURATION = 11,  -- Duration in seconds to track damage
}

-- Add near the top with other constants
local ODYNS_FURY = {
    CAST_ID = 385059,
    DAMAGE_IDS = {
        [385060] = true,  -- Main hand damage and DoT
        [385061] = true,  -- Off-hand damage
        [385062] = true,  -- Additional damage
    },
    name = "Odyn's Fury",
    active = false,
    targets = {},
    totalDamage = 0,
    startTime = 0,
    DURATION = 5,  -- Failsafe duration in seconds
}

-- Initialize saved variables
function CH:Init()
    -- Initialize or load saved variables
    CombineHitsDB = CombineHitsDB or {}
    
    for k, v in pairs(addon.defaults) do
        if CombineHitsDB[k] == nil then
            CombineHitsDB[k] = v
        end
    end
    
    -- Ensure point exists in framePosition
    if not CombineHitsDB.framePosition.point then
        CombineHitsDB.framePosition.point = "CENTER"
    end
    
    -- Register for PLAYER_LOGIN to initialize UI
    CH:RegisterEvent("PLAYER_LOGIN")
end

-- Initialize UI after game is fully loaded
function CH:InitializeUI()
    CH:CreateMainFrame()
    CH:CreateLeaderboardFrame()
    CH:CreateDisplayFrames()
    CH:UpdateFrameSizes()
    CH:RegisterEvents()
end

-- Create the main frame to display hits
function CH:CreateMainFrame()
    local f = CreateFrame("Frame", "CombineHitsMainFrame", UIParent, "BackdropTemplate")
    addon.mainFrame = f
    
    -- Set size
    f:SetSize(CombineHitsDB.frameWidth, CombineHitsDB.frameHeight)
    
    -- Set frame strata
    f:SetFrameStrata("MEDIUM")
    
    -- Set initial position
    f:ClearAllPoints()
    f:SetPoint(CombineHitsDB.framePosition.point, UIParent, CombineHitsDB.framePosition.point, 
               CombineHitsDB.framePosition.x, CombineHitsDB.framePosition.y)
    
    -- Set backdrop
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0, 0, 0, CombineHitsDB.frameAlpha)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    
    -- Make frame movable
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    
    -- Simple movement handlers
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        
        -- Get frame position directly
        local point, _, _, xOfs, yOfs = self:GetPoint(1)
        
        -- Save position and anchor point
        CombineHitsDB.framePosition.point = point
        CombineHitsDB.framePosition.x = xOfs
        CombineHitsDB.framePosition.y = yOfs
    end)
    
    -- Show/hide based on saved setting
    if CombineHitsDB.frameVisible then
        f:Show()
    else
        f:Hide()
    end
    
    return f
end

-- Create display frames for showing damage
function CH:CreateDisplayFrames()
    addon.displayFrames = {}
    local prevFrame = nil
    local spacing = 1
    
    for i = 1, CombineHitsDB.maxDisplayed do
        local frame = CreateFrame("Frame", "CombineHitsDisplay"..i, addon.mainFrame)
        local frameHeight = (CombineHitsDB.frameHeight - 20) / CombineHitsDB.maxDisplayed
        frame:SetSize(CombineHitsDB.frameWidth - 20, frameHeight)
        
        -- Create ability name text
        local abilityText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        abilityText:SetPoint("LEFT", frame, "LEFT", 5, 0)
        abilityText:SetFont("Fonts\\FRIZQT__.TTF", CombineHitsDB.fontSize, "OUTLINE")
        abilityText:SetJustifyH("LEFT")
        abilityText:SetWidth(110)
        frame.abilityText = abilityText
        
        -- Create damage text
        local damageText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        damageText:SetPoint("LEFT", abilityText, "RIGHT", 10, 0)
        damageText:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
        damageText:SetFont("Fonts\\FRIZQT__.TTF", CombineHitsDB.fontSize, "OUTLINE")
        damageText:SetJustifyH("RIGHT")
        frame.damageText = damageText
        
        -- Position frame relative to main frame
        frame:ClearAllPoints()
        local yOffset = -5 - ((i-1) * (frameHeight + spacing))
        frame:SetPoint("TOPLEFT", addon.mainFrame, "TOPLEFT", 10, yOffset)
        
        -- Hide initially
        frame.abilityText:Hide()
        frame.damageText:Hide()
        
        prevFrame = frame
        table.insert(addon.displayFrames, frame)
    end
end

-- Event handling
function CH:RegisterEvents()
    CH:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    CH:RegisterEvent("UNIT_AURA")
end

-- Display a hit in the frame
function CH:DisplayHit(sequence)
    -- Check if this is a new record
    if sequence.damage > 0 then
        local currentRecord = CombineHitsDB.leaderboard[sequence.name]
        if not currentRecord or sequence.damage > currentRecord.damage then
            CombineHitsDB.leaderboard[sequence.name] = {
                damage = sequence.damage,
                timestamp = time(),
                zone = GetZoneText(),
                subZone = GetSubZoneText(),
            }
        end
    end

    -- Format damage number with commas
    local formattedDamage = CH:FormatNumber(sequence.damage)
    
    -- Shift existing hits down
    for i = #addon.displayFrames, 2, -1 do
        local prevFrame = addon.displayFrames[i-1]
        local currentFrame = addon.displayFrames[i]
        
        if prevFrame.damageText:GetText() and prevFrame.damageText:GetText() ~= "" then
            -- Copy text and colors from previous frame
            local prevColor = { prevFrame.damageText:GetTextColor() }
            local prevAlpha = prevFrame.damageText:GetAlpha()
            
            if prevAlpha > 0 then
                currentFrame.abilityText:SetText(prevFrame.abilityText:GetText())
                currentFrame.damageText:SetText(prevFrame.damageText:GetText())
                currentFrame.abilityText:Show()
                currentFrame.damageText:Show()
                currentFrame.damageText:SetTextColor(unpack(prevColor))
                currentFrame.abilityText:SetTextColor(unpack(prevColor))
                currentFrame.damageText:SetAlpha(prevAlpha)
                currentFrame.abilityText:SetAlpha(prevAlpha)
                
                -- Continue fading if in progress
                if prevAlpha < 1 then
                    CH:FadeOut(currentFrame)
                end
            end
        else
            -- Clear empty frame
            currentFrame.abilityText:SetText("")
            currentFrame.damageText:SetText("")
            currentFrame.abilityText:Hide()
            currentFrame.damageText:Hide()
        end
    end
    
    -- Display new hit at the top
    local topFrame = addon.displayFrames[1]
    topFrame.abilityText:SetText(sequence.name)
    topFrame.damageText:SetText(formattedDamage)
    topFrame.abilityText:Show()
    topFrame.damageText:Show()
    topFrame.damageText:SetAlpha(1)
    topFrame.abilityText:SetAlpha(1)
    
    -- Set text color based on crit
    local color = sequence.hasCrit and CombineHitsDB.critColor or CombineHitsDB.textColor
    topFrame.abilityText:SetTextColor(color.r, color.g, color.b)
    topFrame.damageText:SetTextColor(color.r, color.g, color.b)
    
    -- Start fade for all visible texts
    for i = 1, #addon.displayFrames do
        if addon.displayFrames[i].damageText:GetText() and addon.displayFrames[i].damageText:GetText() ~= "" then
            CH:FadeOut(addon.displayFrames[i])
        end
    end
end

-- Check for Whirlwind buff
function CH:CheckWhirlwindBuff(unit)
    if unit ~= "player" then return end
    
    local name, _, _, _, _, _, _, _, _, spellId = AuraUtil.FindAuraByName("Whirlwind", "player", "HELPFUL")
    addon.hasWhirlwindBuff = (spellId == WHIRLWIND_BUFF_ID)
end

-- Base structure for new hit sequence
function CH:CreateNewHitSequence(abilityInfo, now)
    return {
        name = abilityInfo.name,
        icon = abilityInfo.icon,
        damage = 0,
        hasCrit = false,
        startTime = now,
        lastHitTime = now,
        whirlwindActive = addon.hasWhirlwindBuff,
        validSpellIds = abilityInfo.damageSpells  -- Store valid spell IDs for this sequence
    }
end

-- Add new function for Thunderous Roar tracking
function CH:HandleThunderousRoar(eventType, destGUID, spellId, amount, critical)
    if eventType == "SPELL_CAST_SUCCESS" and spellId == THUNDEROUS_ROAR.CAST_ID then
        -- Reset tracking for new cast
        THUNDEROUS_ROAR.active = true
        THUNDEROUS_ROAR.targets = {}
        THUNDEROUS_ROAR.totalDamage = 0
        
    elseif THUNDEROUS_ROAR.active then
        if eventType == "SPELL_AURA_APPLIED" and spellId == THUNDEROUS_ROAR.DOT_ID then
            -- Track new target
            THUNDEROUS_ROAR.targets[destGUID] = true
            
        elseif eventType == "SPELL_DAMAGE" and spellId == THUNDEROUS_ROAR.CAST_ID then
            -- Add initial hit damage
            THUNDEROUS_ROAR.totalDamage = THUNDEROUS_ROAR.totalDamage + (amount or 0)
            
        elseif eventType == "SPELL_PERIODIC_DAMAGE" and spellId == THUNDEROUS_ROAR.DOT_ID then
            -- Add DoT damage
            THUNDEROUS_ROAR.totalDamage = THUNDEROUS_ROAR.totalDamage + (amount or 0)
            
        elseif eventType == "SPELL_AURA_REMOVED" and spellId == THUNDEROUS_ROAR.DOT_ID then
            -- Remove target from tracking
            THUNDEROUS_ROAR.targets[destGUID] = nil
            
            -- Check if this was the last target
            local remainingTargets = 0
            for _ in pairs(THUNDEROUS_ROAR.targets) do
                remainingTargets = remainingTargets + 1
            end
            
            if remainingTargets == 0 and THUNDEROUS_ROAR.totalDamage > 0 then
                -- All targets finished, display total damage
                local sequence = {
                    name = THUNDEROUS_ROAR.name,
                    damage = THUNDEROUS_ROAR.totalDamage,
                    hasCrit = true,  -- Always show as crit color due to multiple hits
                }
                CH:DisplayHit(sequence)
                
                -- Reset tracking
                THUNDEROUS_ROAR.active = false
                THUNDEROUS_ROAR.totalDamage = 0
            end
        end
    end
end

-- Add new function for Ravager tracking
function CH:HandleRavager(eventType, spellId, amount, critical)
    local now = GetTime()
    
    if eventType == "SPELL_CAST_SUCCESS" and spellId == RAVAGER.CAST_ID then
        -- Start new Ravager tracking
        RAVAGER.active = true
        RAVAGER.totalDamage = 0
        RAVAGER.startTime = now
        
        -- Set timer to display total after duration
        C_Timer.After(RAVAGER.DURATION, function()
            if RAVAGER.active and RAVAGER.totalDamage > 0 then
                -- Display total damage
                local sequence = {
                    name = RAVAGER.name,
                    damage = RAVAGER.totalDamage,
                    hasCrit = true,  -- Always show as crit color due to multiple hits
                }
                CH:DisplayHit(sequence)
                
                -- Reset tracking
                RAVAGER.active = false
                RAVAGER.totalDamage = 0
            end
        end)
        
    elseif RAVAGER.active and eventType == "SPELL_DAMAGE" and spellId == RAVAGER.DAMAGE_ID then
        -- Add damage if within duration window
        if (now - RAVAGER.startTime) <= RAVAGER.DURATION then
            RAVAGER.totalDamage = RAVAGER.totalDamage + (amount or 0)
        end
    end
end

-- Add new function for Odyn's Fury tracking
function CH:HandleOdynsFury(eventType, destGUID, spellId, amount, critical)
    local now = GetTime()
    
    if eventType == "SPELL_CAST_SUCCESS" and spellId == ODYNS_FURY.CAST_ID then
        -- Start new Odyn's Fury tracking
        ODYNS_FURY.active = true
        ODYNS_FURY.targets = {}
        ODYNS_FURY.totalDamage = 0
        ODYNS_FURY.startTime = now
        
        -- Set failsafe timer
        C_Timer.After(ODYNS_FURY.DURATION, function()
            if ODYNS_FURY.active then
                -- Display total damage if we haven't already
                local sequence = {
                    name = ODYNS_FURY.name,
                    damage = ODYNS_FURY.totalDamage,
                    hasCrit = true,  -- Always show as crit color due to multiple hits
                }
                CH:DisplayHit(sequence)
                
                -- Reset tracking
                ODYNS_FURY.active = false
                ODYNS_FURY.totalDamage = 0
                ODYNS_FURY.targets = {}
            end
        end)
        
    elseif ODYNS_FURY.active then
        -- Check if we've exceeded the failsafe duration
        if (now - ODYNS_FURY.startTime) > ODYNS_FURY.DURATION then
            ODYNS_FURY.active = false
            return
        end
        
        if eventType == "SPELL_DAMAGE" and ODYNS_FURY.DAMAGE_IDS[spellId] then
            -- Add direct damage
            ODYNS_FURY.totalDamage = ODYNS_FURY.totalDamage + (amount or 0)
            
        elseif eventType == "SPELL_PERIODIC_DAMAGE" and ODYNS_FURY.DAMAGE_IDS[spellId] then
            -- Add DoT damage
            ODYNS_FURY.totalDamage = ODYNS_FURY.totalDamage + (amount or 0)
            
        elseif eventType == "SPELL_AURA_APPLIED" and ODYNS_FURY.DAMAGE_IDS[spellId] then
            -- Track new target
            ODYNS_FURY.targets[destGUID] = true
            
        elseif eventType == "SPELL_AURA_REMOVED" and ODYNS_FURY.DAMAGE_IDS[spellId] then
            -- Remove target from tracking
            ODYNS_FURY.targets[destGUID] = nil
            
            -- Check if this was the last target
            local remainingTargets = 0
            for _ in pairs(ODYNS_FURY.targets) do
                remainingTargets = remainingTargets + 1
            end
            
            if remainingTargets == 0 and ODYNS_FURY.active then
                -- All targets finished, display total damage
                local sequence = {
                    name = ODYNS_FURY.name,
                    damage = ODYNS_FURY.totalDamage,
                    hasCrit = true,  -- Always show as crit color due to multiple hits
                }
                CH:DisplayHit(sequence)
                
                -- Reset tracking
                ODYNS_FURY.active = false
                ODYNS_FURY.totalDamage = 0
            end
        end
    end
end

-- Modify the COMBAT_LOG_EVENT_UNFILTERED function
function CH:COMBAT_LOG_EVENT_UNFILTERED(...)
    local timestamp, eventType, _, sourceGUID, _, _, _, destGUID, destName, _, _, spellId, spellName, _, amount, _, _, _, _, _, critical = ...
    
    -- Only process player's events
    if sourceGUID ~= UnitGUID("player") then return end
    
    local now = GetTime()
    
    -- Handle Thunderous Roar separately
    if spellId == THUNDEROUS_ROAR.CAST_ID or spellId == THUNDEROUS_ROAR.DOT_ID then
        CH:HandleThunderousRoar(eventType, destGUID, spellId, amount, critical)
        return
    end
    
    -- Handle Ravager separately
    if spellId == RAVAGER.CAST_ID or spellId == RAVAGER.DAMAGE_ID then
        CH:HandleRavager(eventType, spellId, amount, critical)
        return
    end
    
    -- Handle Odyn's Fury separately
    if spellId == ODYNS_FURY.CAST_ID or ODYNS_FURY.DAMAGE_IDS[spellId] then
        CH:HandleOdynsFury(eventType, destGUID, spellId, amount, critical)
        return
    end
    
    -- Track Whirlwind buff
    if eventType == "SPELL_AURA_APPLIED" and spellId == WHIRLWIND_BUFF_ID then
        addon.hasWhirlwindBuff = true
    elseif eventType == "SPELL_AURA_REMOVED" and spellId == WHIRLWIND_BUFF_ID then
        addon.hasWhirlwindBuff = false
    end
    
    -- Handle ability casts to start new sequences
    if eventType == "SPELL_CAST_SUCCESS" then
        local abilityInfo = ABILITY_DAMAGE_SPELLS[spellId]
        if abilityInfo then
            -- If we have an active sequence, complete it
            if addon.activeSequence and addon.activeSequence.damage > 0 then
                CH:DisplayHit(addon.activeSequence)
            end
            
            -- Start new sequence
            addon.activeSequence = CH:CreateNewHitSequence(abilityInfo, now)
            
            -- Set a timer to complete this sequence if it's still active
            C_Timer.After(2, function()
                if addon.activeSequence and addon.activeSequence.startTime == now then
                    if addon.activeSequence.damage > 0 then
                        CH:DisplayHit(addon.activeSequence)
                    end
                    addon.activeSequence = nil
                end
            end)
        end
    end
    
    -- Handle damage events
    if eventType == "SPELL_DAMAGE" and addon.activeSequence then
        -- Only process damage if the spell ID is valid for the current sequence
        if addon.activeSequence.validSpellIds[spellId] then
            local damage = amount or 0
            if damage > 0 and (now - addon.activeSequence.startTime) <= 2 then
                addon.activeSequence.damage = addon.activeSequence.damage + damage
                addon.activeSequence.hasCrit = addon.activeSequence.hasCrit or critical
                addon.activeSequence.lastHitTime = now
            end
        end
    end
end

-- Main event handler
CH:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        CH:Init()
    elseif event == "PLAYER_LOGIN" then
        CH:InitializeUI()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        CH:COMBAT_LOG_EVENT_UNFILTERED(CombatLogGetCurrentEventInfo())
    elseif event == "UNIT_AURA" then
        CH:CheckWhirlwindBuff(...)
    end
end)

-- Fade out a frame's text
function CH:FadeOut(frame)
    if frame.damageText.fadeInfo then
        UIFrameFadeRemoveFrame(frame.damageText)
        UIFrameFadeRemoveFrame(frame.abilityText)
    end
    
    UIFrameFadeOut(frame.damageText, CombineHitsDB.fadeTime, frame.damageText:GetAlpha(), 0)
    UIFrameFadeOut(frame.abilityText, CombineHitsDB.fadeTime, frame.abilityText:GetAlpha(), 0)
    
    C_Timer.After(CombineHitsDB.fadeTime, function()
        if frame.damageText:GetAlpha() == 0 then
            frame.damageText:SetText("")
            frame.abilityText:SetText("")
            frame.damageText:Hide()
            frame.abilityText:Hide()
        end
    end)
end

-- Toggle frame visibility
function CH:ToggleFrame()
    if CombineHitsDB.frameVisible then
        addon.mainFrame:Hide()
        CombineHitsDB.frameVisible = false
    else
        addon.mainFrame:Show()
        CombineHitsDB.frameVisible = true
    end
end

-- Update frame sizes and layout
function CH:UpdateFrameSizes()
    -- Update main frame size
    addon.mainFrame:SetSize(CombineHitsDB.frameWidth, CombineHitsDB.frameHeight)
    
    -- Update each display frame
    local spacing = 1
    for i, frame in ipairs(addon.displayFrames) do
        local frameHeight = (CombineHitsDB.frameHeight - 20) / CombineHitsDB.maxDisplayed
        frame:SetSize(CombineHitsDB.frameWidth - 20, frameHeight)
        
        -- Update text positions
        frame.abilityText:SetWidth(110)
        frame.damageText:ClearAllPoints()
        frame.damageText:SetPoint("LEFT", frame.abilityText, "RIGHT", 10, 0)
        frame.damageText:SetPoint("RIGHT", frame, "RIGHT", -5, 0)
        
        -- Position frame relative to main frame
        frame:ClearAllPoints()
        local yOffset = -5 - ((i-1) * (frameHeight + spacing))
        frame:SetPoint("TOPLEFT", addon.mainFrame, "TOPLEFT", 10, yOffset)
    end
end

-- Slash command handling
SLASH_COMBINEHITS1 = "/ch"
SLASH_COMBINEHITS2 = "/combinehits"
SlashCmdList["COMBINEHITS"] = function(msg)
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    
    if cmd == "reset" then
        -- Reset to center of screen
        CombineHitsDB.framePosition.point = "CENTER"
        CombineHitsDB.framePosition.x = 0
        CombineHitsDB.framePosition.y = 0
        CombineHitsDB.frameWidth = addon.defaults.frameWidth
        CombineHitsDB.frameHeight = addon.defaults.frameHeight
        
        -- Update frame
        addon.mainFrame:ClearAllPoints()
        addon.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        CH:UpdateFrameSizes()
    elseif cmd == "show" or cmd == "" then
        CH:ToggleFrame()
    elseif cmd == "lb" then
        if addon.leaderboardFrame:IsShown() then
            addon.leaderboardFrame:Hide()
        else
            CH:UpdateLeaderboard()
            addon.leaderboardFrame:Show()
        end
    else
        print("CombineHits commands:")
        print("  /ch - Toggle frame visibility")
        print("  /ch reset - Reset position and size to center")
        print("  /ch lb - Toggle leaderboard")
    end
end

-- Create the leaderboard frame
function CH:CreateLeaderboardFrame()
    local f = CreateFrame("Frame", "CombineHitsLeaderboard", UIParent, "BasicFrameTemplateWithInset")
    addon.leaderboardFrame = f
    
    -- Increase width for two columns
    f:SetSize(600, 480)  -- Doubled width from 300 to 600
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("HIGH")
    
    f.TitleText:SetText("Big Hits Leaderboard")
    
    -- Create the content frame with explicit size
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
    content:SetSize(584, 452)  -- Adjusted for wider frame (600 - 16 for borders)
    f.content = content
    
    -- Create clear button
    local clearButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearButton:SetSize(100, 25)
    clearButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    clearButton:SetText("Clear Records")
    clearButton:SetScript("OnClick", function()
        StaticPopup_Show("COMBINEHITS_CLEAR_LEADERBOARD")
    end)
    
    -- Create confirmation dialog
    StaticPopupDialogs["COMBINEHITS_CLEAR_LEADERBOARD"] = {
        text = "Are you sure you want to clear all leaderboard records?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            CombineHitsDB.leaderboard = {}
            print("CombineHits: Leaderboard has been cleared.")
            CH:UpdateLeaderboard()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    
    f:Hide()
    return f
end

-- Update leaderboard display
function CH:UpdateLeaderboard()
    local frame = addon.leaderboardFrame
    local content = frame.content
    
    -- Clear existing entries
    for _, child in pairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end
    
    -- Sort abilities alphabetically
    local sortedRecords = {}
    for ability, record in pairs(CombineHitsDB.leaderboard) do
        table.insert(sortedRecords, {name = ability, data = record})
    end
    table.sort(sortedRecords, function(a, b) return a.name < b.name end)
    
    -- Calculate content widths for two columns (account for padding)
    local columnWidth = (content:GetWidth() - 40) / 2  -- 40px for padding between and on sides
    local yOffset = 0
    
    -- Create entries in two columns
    for i = 1, #sortedRecords, 2 do
        -- Create container for this row
        local leftEntry = CreateFrame("Frame", nil, content)
        leftEntry:SetSize(columnWidth, 65)
        leftEntry:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -yOffset - 30)
        
        -- Left column
        -- Ability name and damage
        local leftHeader = leftEntry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        leftHeader:SetPoint("TOPLEFT", leftEntry, "TOPLEFT", 0, 0)
        leftHeader:SetWidth(columnWidth)
        leftHeader:SetJustifyH("LEFT")
        leftHeader:SetText(string.format("%s: |cffFFD700%s|r", 
            sortedRecords[i].name, 
            CH:FormatNumber(sortedRecords[i].data.damage)))
        
        -- Location
        local leftLocation = leftEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leftLocation:SetPoint("TOPLEFT", leftHeader, "BOTTOMLEFT", 20, -5)
        leftLocation:SetWidth(columnWidth - 20)
        leftLocation:SetJustifyH("LEFT")
        local leftLocationText = sortedRecords[i].data.zone
        if sortedRecords[i].data.subZone and sortedRecords[i].data.subZone ~= "" then
            leftLocationText = leftLocationText .. " - " .. sortedRecords[i].data.subZone
        end
        leftLocation:SetText("|cffAAAAAA" .. leftLocationText .. "|r")
        
        -- Time
        local leftTimeString = date("%m/%d/%Y %I:%M %p", sortedRecords[i].data.timestamp)
        local leftTime = leftEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        leftTime:SetPoint("TOPLEFT", leftLocation, "BOTTOMLEFT", 0, -5)
        leftTime:SetWidth(columnWidth - 20)
        leftTime:SetJustifyH("LEFT")
        leftTime:SetText("|cffAAAAAA" .. leftTimeString .. "|r")
        
        -- Right column if we have an entry
        if sortedRecords[i + 1] then
            local rightEntry = CreateFrame("Frame", nil, content)
            rightEntry:SetSize(columnWidth, 65)
            rightEntry:SetPoint("TOPLEFT", content, "TOPLEFT", columnWidth + 30, -yOffset - 30)
            
            -- Ability name and damage
            local rightHeader = rightEntry:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            rightHeader:SetPoint("TOPLEFT", rightEntry, "TOPLEFT", 0, 0)
            rightHeader:SetWidth(columnWidth)
            rightHeader:SetJustifyH("LEFT")
            rightHeader:SetText(string.format("%s: |cffFFD700%s|r", 
                sortedRecords[i + 1].name, 
                CH:FormatNumber(sortedRecords[i + 1].data.damage)))
            
            -- Location
            local rightLocation = rightEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            rightLocation:SetPoint("TOPLEFT", rightHeader, "BOTTOMLEFT", 20, -5)
            rightLocation:SetWidth(columnWidth - 20)
            rightLocation:SetJustifyH("LEFT")
            local rightLocationText = sortedRecords[i + 1].data.zone
            if sortedRecords[i + 1].data.subZone and sortedRecords[i + 1].data.subZone ~= "" then
                rightLocationText = rightLocationText .. " - " .. sortedRecords[i + 1].data.subZone
            end
            rightLocation:SetText("|cffAAAAAA" .. rightLocationText .. "|r")
            
            -- Time
            local rightTimeString = date("%m/%d/%Y %I:%M %p", sortedRecords[i + 1].data.timestamp)
            local rightTime = rightEntry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            rightTime:SetPoint("TOPLEFT", rightLocation, "BOTTOMLEFT", 0, -5)
            rightTime:SetWidth(columnWidth - 20)
            rightTime:SetJustifyH("LEFT")
            rightTime:SetText("|cffAAAAAA" .. rightTimeString .. "|r")
        end
        
        yOffset = yOffset + 65 -- Height of entry plus spacing
    end
end

-- Format number with commas
function CH:FormatNumber(number)
    return tostring(number):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
