local _, ns = ...
local oUF = ns.oUF

-- sourced from Blizzard_UnitFrame/TargetFrame.lua
local MAX_BOSS_FRAMES = 8 -- blizzard can spawn more than the default 5 apparently

-- sourced from Blizzard_FrameXMLBase/Shared/Constants.lua
local MEMBERS_PER_RAID_GROUP = _G.MEMBERS_PER_RAID_GROUP or 5

local hookedFrames = {}
local hookedNameplates = {}
local isArenaHooked = false
local isBossHooked = false
local isPartyHooked = false

local hiddenParent = CreateFrame('Frame', nil, UIParent)
hiddenParent:SetAllPoints()
hiddenParent:Hide()

-- local function insecureHide(self)
-- 	self:Hide()
-- end

local looseFrames = {}

local watcher = CreateFrame('Frame')
watcher:RegisterEvent('PLAYER_REGEN_ENABLED')
watcher:SetScript('OnEvent', function()
	for frame in next, looseFrames do
		frame:SetParent(hiddenParent)
	end

	table.wipe(looseFrames)
end)

local function resetParent(self, parent)
	if(parent ~= hiddenParent) then
		if(InCombatLockdown() and self:IsProtected()) then
			looseFrames[self] = true
		else
			self:SetParent(hiddenParent)
		end
	end
end

local function handleFrame(baseName, doNotReparent, isNamePlate)
	local frame
	if(type(baseName) == 'string') then
		frame = _G[baseName]
	else
		frame = baseName
	end

	if(frame) then
		frame:UnregisterAllEvents()
		if(isNamePlate) then
			-- TODO: remove this once we can adjust hitrects for nameplates
			frame:SetAlpha(0)
		else
			frame:Hide()
		end

		if(not doNotReparent) then
			frame:SetParent(hiddenParent)

			if(not hookedFrames[frame]) then
				hooksecurefunc(frame, 'SetParent', resetParent)

				hookedFrames[frame] = true
			end
		end

		local health = frame.healthBar or frame.healthbar or frame.HealthBar or (frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar)
		if(health) then
			health:UnregisterAllEvents()
		end

		local power = frame.manabar or frame.ManaBar
		if(power) then
			power:UnregisterAllEvents()
		end

		local altpowerbar = frame.powerBarAlt or frame.PowerBarAlt
		if(altpowerbar) then
			altpowerbar:UnregisterAllEvents()
		end

		local buffFrame = frame.BuffFrame or frame.AurasFrame
		if(buffFrame) then
			buffFrame:UnregisterAllEvents()
		end

		local petFrame = frame.petFrame or frame.PetFrame
		if(petFrame) then
			petFrame:UnregisterAllEvents()
		end

		local totFrame = frame.totFrame
		if(totFrame) then
			totFrame:UnregisterAllEvents()
		end

		local classPowerBar = frame.classPowerBar
		if(classPowerBar) then
			classPowerBar:UnregisterAllEvents()
		end

		local ccRemoverFrame = frame.CcRemoverFrame
		if(ccRemoverFrame) then
			ccRemoverFrame:UnregisterAllEvents()
		end

		local debuffFrame = frame.DebuffFrame
		if(debuffFrame) then
			debuffFrame:UnregisterAllEvents()
		end
	end
end

function oUF:DisableBlizzard(unit)
	if(not unit) then return end

	if(unit == 'player') then
		handleFrame(PlayerFrame)
	elseif(unit == 'pet') then
		handleFrame(PetFrame)
	elseif(unit == 'target') then
		handleFrame(TargetFrame)
	elseif(unit == 'focus') then
		handleFrame(FocusFrame)
	elseif(unit:match('boss%d?$')) then
		if(not isBossHooked) then
			isBossHooked = true

			-- it's needed because the layout manager can bring frames that are
			-- controlled by containers back from the dead when a user chooses
			-- to revert all changes
			-- for now I'll just reparent it, but more might be needed in the
			-- future, watch it
			handleFrame(BossTargetFrameContainer)

			-- do not reparent frames controlled by containers, the vert/horiz
			-- layout code will go insane because it won't be able to calculate
			-- the size properly, 0 or negative sizes in turn will break the
			-- layout manager, fun...
			for i = 1, MAX_BOSS_FRAMES do
				handleFrame('Boss' .. i .. 'TargetFrame', true)
			end
		end
	elseif(unit:match('party%d?$')) then
		-- Party frames are owned by the external party-frame addon (for example
		-- DandersFrames). KullThranUI should not hide or reparent Blizzard party
		-- frames here, and must not touch CompactPartyFrameMember state because
		-- Retail Edit Mode manages those secure fields internally.
	elseif(unit:match('arena%d?$')) then
		-- Arena frames are also CompactUnitFrames managed by Blizzard. Avoid
		-- touching them from KullThranUI so secure CompactUnitFrame state stays
		-- fully native.
	end
end

function oUF:DisableBlizzardNamePlate(frame)
	-- Keep Blizzard nameplates fully native. External nameplate addons should
	-- manage their own replacement visuals without mutating Blizzard's UnitFrame.
	return
end
