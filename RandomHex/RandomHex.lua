local rhexList
local hex_addon = ...

--------------------------------------------------------------------
-- Produced Marco Name [in player's macros]
--------------------------------------------------------------------

local HexMacroName = "Hex"
local hexMacroSrc = "\n/click rhexButton 1\n/click rhexButton LeftButton 1"

local debugHex = false

--------------------------------------------------------------------
-- Hex & Hex Variants List
--------------------------------------------------------------------

-- {spellId, name, faction} -- faction is set only on the two that are
-- locked to one side, and it's the data rather than a name comparison so
-- the count and the colouring can both read it (see IsHexVariantImpossible)
local rhexVariants = {
--- Default Hex  --
	{51514, "Frog"},
--- Collectable Hex Variants --
	{211015, "Cockroach"},
	{210873, "Compy"},
	{309328, "Living Honey"},
	{269352, "Skeletal Hatchling"},
	{211004, "Spider"},
	{277784, "Wicker Mongrel", "Alliance"},
	{277778, "Zandalari Tendonripper", "Horde"},
	}

--------------------------------------------------------------------
-- A variant locked to the other faction can never be collected on this
-- character, so it doesn't belong in the total you're working towards --
-- "7" is reachable, "8" never is, whichever side you're on.
--------------------------------------------------------------------
function IsHexVariantImpossible(index)
	local faction = rhexVariants[index][3]
	if not faction then return false end
	local playerFaction = UnitFactionGroup("player")
	-- Neutral (a pandaren who hasn't chosen) can still end up either side,
	-- so nothing is ruled out yet --
	if not playerFaction or playerFaction == "Neutral" then return false end
	return faction ~= playerFaction
end

--------------------------------------------------------------------
-- Used to check incoming spellIds, hex cast?
--------------------------------------------------------------------
function IsHexVariantSpellId(spellId)
	for k in pairs(rhexVariants) do
		-- Is spellId one of the hex variants? --
		if spellId == rhexVariants[k][1] then
			return true
		end
	end
	
	return false
end

--------------------------------------------------------------------
-- UI in Options panel
--------------------------------------------------------------------

local rhexOptionsPanel = CreateFrame("Frame")
rhexOptionsPanel.name = "Random Hex [/hex]"
rhexOptionsPanel.OnCommit = function() rhexOptionsOkay(); end
rhexOptionsPanel.OnDefault = function() end
rhexOptionsPanel.OnRefresh = function() end
local rhexCategory = Settings.RegisterCanvasLayoutCategory(rhexOptionsPanel, "Random Hex [/hex]")
Settings.RegisterAddOnCategory(rhexCategory)

-- Vertical rhythm for the header block. The description sits HEADER_GAP
-- under the title, and the list sits the same distance under the
-- description -- expressed as one constant so the two spacings can't drift
-- apart if the header ever moves.
local HEADER_Y = -10
local HEADER_GAP = -30
local DESC_Y = HEADER_Y + HEADER_GAP
local LIST_Y = DESC_Y + HEADER_GAP

-- Title --
local rhexTitle = CreateFrame("Frame",nil, rhexOptionsPanel)
rhexTitle:SetPoint("TOPLEFT", 10, HEADER_Y)
rhexTitle:SetWidth(SettingsPanel.Container:GetWidth()-35)
rhexTitle:SetHeight(1)
rhexTitle.text = rhexTitle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rhexTitle.text:SetPoint("TOPLEFT", rhexTitle, 0, 0)
rhexTitle.text:SetText("Random Hex")
rhexTitle.text:SetFont("Fonts\\FRIZQT__.TTF", 18)

-- Thanks --
rhexOptionsPanel.Thanks = rhexOptionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rhexOptionsPanel.Thanks:SetPoint("BOTTOMRIGHT",-20,20)
rhexOptionsPanel.Thanks:SetText("For all my kindred Shaman who collect the Hex Variants.\n zecmo - Runetotem")
rhexOptionsPanel.Thanks:SetFont("Fonts\\FRIZQT__.TTF", 9)
rhexOptionsPanel.Thanks:SetJustifyH("RIGHT")

-- Description
local rhexDesc = CreateFrame("Frame", nil, rhexOptionsPanel)
rhexDesc:SetPoint("TOPLEFT", 20, DESC_Y)
rhexDesc:SetWidth(SettingsPanel.Container:GetWidth()-35)
rhexDesc:SetHeight(1)
rhexDesc.text = rhexDesc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rhexDesc.text:SetPoint("TOPLEFT", rhexDesc, 0, 0)
rhexDesc.text:SetText("Toggle which hex variants are active in the \"Hex\" macro\'s rotation.")
rhexDesc.text:SetFont("Fonts\\FRIZQT__.TTF", 14)

--------------------------------------------------------------------
-- Collection progress [how many variants this character actually knows,
-- styled after Blizzard's own collection bars: a green fill with the
-- count centred on it. Filled in by ColorizeHexVariantText]
--------------------------------------------------------------------
local rhexProgressBar = CreateFrame("StatusBar", nil, rhexOptionsPanel)
rhexProgressBar:SetSize(200, 10)
-- Anchored to the title frame rather than the panel, so it rides the header
-- wherever that moves. The title frame is a 1px line with its 18pt text
-- hanging below it, so the bar drops ~11px to sit level with that text --
rhexProgressBar:SetPoint("RIGHT", rhexTitle, "RIGHT", -5, -4)
rhexProgressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
rhexProgressBar:SetStatusBarColor(0.13, 0.63, 0.11)
rhexProgressBar:SetMinMaxValues(0, #rhexVariants)
rhexProgressBar:SetValue(0)
local rhexProgressBg = rhexProgressBar:CreateTexture(nil, "BACKGROUND")
rhexProgressBg:SetAllPoints()
rhexProgressBg:SetColorTexture(0, 0, 0, 0.7)
-- Soft tooltip-edge border rather than the raw rectangle --
local rhexProgressBorder = CreateFrame("Frame", nil, rhexProgressBar, "BackdropTemplate")
rhexProgressBorder:SetPoint("TOPLEFT", -5, 5)
rhexProgressBorder:SetPoint("BOTTOMRIGHT", 5, -5)
rhexProgressBorder:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14})
rhexProgressBorder:SetBackdropBorderColor(1, 1, 1, 0.85)
local rhexProgressText = rhexProgressBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
rhexProgressText:SetPoint("CENTER")

-- Scroll Frame [sits the same distance below the description as the
-- description sits below the title -- see LIST_Y]
local rhexOptionsScroll = CreateFrame("ScrollFrame", nil, rhexOptionsPanel, "UIPanelScrollFrameTemplate")
rhexOptionsScroll:SetPoint("TOPLEFT", 5, LIST_Y)
rhexOptionsScroll:SetPoint("BOTTOMRIGHT", -10, 60)

-- No visible scrollbar: two columns of eight variants fit without one, and
-- an empty track down the side is just clutter. The scroll frame itself
-- stays, so the wheel still works if the list ever outgrows the panel --
-- hence overriding Show, since the template re-shows the bar whenever the
-- scroll range changes.
if rhexOptionsScroll.ScrollBar then
	rhexOptionsScroll.ScrollBar:Hide()
	rhexOptionsScroll.ScrollBar.Show = function() end
end

-- Divider
local rhexDivider = rhexOptionsScroll:CreateLine()
rhexDivider:SetStartPoint("BOTTOMLEFT", 20, -10)
rhexDivider:SetEndPoint("BOTTOMRIGHT", 0, -10)
rhexDivider:SetColorTexture(0.25,0.25,0.25,1)
rhexDivider:SetThickness(1.2)

-- Scroll Frame child
local rhexScrollChild = CreateFrame("Frame")
rhexOptionsScroll:SetScrollChild(rhexScrollChild)
-- Wider now that no scrollbar is eating the right-hand strip --
rhexScrollChild:SetWidth(SettingsPanel.Container:GetWidth()-20)
rhexScrollChild:SetHeight(1)

--------------------------------------------------------------------
-- One card per hex variant -- icon in a quickslot ring, name beside it,
-- the whole cell framed. Same look as the Random Lure and Random Toys
-- grids, and the same idea behind it: the selected state is carried by a
-- gold border round the cell rather than a tick box, so nothing is drawn
-- over the icon.
--
-- These stay CheckButtons with .ID and .Text, because the rest of the file
-- (rhexOptionsOkay, the saved-variable sync, Select/Deselect all) drives
-- them through exactly that interface.
--------------------------------------------------------------------
local COLS = 2
local GRID_WIDTH = rhexScrollChild:GetWidth()
local COL_OFFSET = math.floor(GRID_WIDTH / COLS)
local ROW_WIDTH, ROW_HEIGHT, ROW_STEP, ICON_SIZE = COL_OFFSET - 20, 42, 44, 28
local DEFAULT_BORDER_COLOR = {0.3, 0.3, 0.3, 1}
local SELECTED_BORDER_COLOR = {1, 0.82, 0, 1}

local function UpdateHexCellSelection(f)
	local selected = f:GetChecked() and true or false
	local color = selected and SELECTED_BORDER_COLOR or DEFAULT_BORDER_COLOR
	f.borderTop:SetColorTexture(unpack(color))
	f.borderBottom:SetColorTexture(unpack(color))
	f.borderLeft:SetColorTexture(unpack(color))
	f.borderRight:SetColorTexture(unpack(color))
	f.cellBg:SetColorTexture(1, 1, 1, selected and 0.14 or 0.06)
end

local function CreateHexVariantCell(parent, spellId, index)
	local f = CreateFrame("CheckButton", nil, parent)
	f.ID = spellId
	f:SetSize(ROW_WIDTH, ROW_HEIGHT)
	-- Filled left to right, then down --
	local col = (index - 1) % COLS
	local row = math.floor((index - 1) / COLS)
	f:SetPoint("TOPLEFT", 15 + col * COL_OFFSET, -(row * ROW_STEP))

	f.cellBg = f:CreateTexture(nil, "BACKGROUND", nil, -2)
	f.cellBg:SetAllPoints(f)
	f.cellBg:SetColorTexture(1, 1, 1, 0.06)

	for _, spec in ipairs({
		{key = "borderTop",    p1 = "TOPLEFT",    p2 = "TOPRIGHT",    dim = "SetHeight"},
		{key = "borderBottom", p1 = "BOTTOMLEFT", p2 = "BOTTOMRIGHT", dim = "SetHeight"},
		{key = "borderLeft",   p1 = "TOPLEFT",    p2 = "BOTTOMLEFT",  dim = "SetWidth"},
		{key = "borderRight",  p1 = "TOPRIGHT",   p2 = "BOTTOMRIGHT", dim = "SetWidth"},
	}) do
		local tex = f:CreateTexture(nil, "BORDER")
		tex:SetColorTexture(unpack(DEFAULT_BORDER_COLOR))
		tex:SetPoint(spec.p1, 0, 0)
		tex:SetPoint(spec.p2, 0, 0)
		tex[spec.dim](tex, 1)
		f[spec.key] = tex
	end

	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(ICON_SIZE, ICON_SIZE)
	f.icon:SetPoint("LEFT", 3, 0)

	-- Quickslot ring round the icon, dimmed so it doesn't outshine it --
	local bg = f:CreateTexture(nil, "BACKGROUND", nil, -1)
	bg:SetTexture("Interface/Buttons/UI-EmptySlot-Disabled")
	bg:SetPoint("CENTER", f.icon, "CENTER")
	bg:SetSize(1.5 * ICON_SIZE, 1.5 * ICON_SIZE)
	bg:SetVertexColor(0.5, 0.5, 0.5)
	local edge = f:CreateTexture(nil, "OVERLAY", nil, -1)
	edge:SetTexture("Interface/Buttons/UI-Quickslot2")
	edge:SetSize(1.625 * ICON_SIZE, 1.625 * ICON_SIZE)
	edge:SetPoint("CENTER", f.icon, "CENTER", 0.25, -0.25)
	edge:SetVertexColor(0.5, 0.5, 0.5)
	local mask = f:CreateMaskTexture()
	mask:SetTexture("Interface/FrameGeneral/UIFrameIconMask")
	mask:SetAllPoints(f.icon)
	f.icon:AddMaskTexture(mask)

	f:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square")
	f:GetHighlightTexture():SetBlendMode("ADD")
	f:GetHighlightTexture():SetAllPoints(f.icon)

	-- Named .Text so the existing colorize/sync code keeps working --
	f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.Text:SetPoint("LEFT", ICON_SIZE + 12, 0)
	f.Text:SetPoint("RIGHT", -2, 0)
	f.Text:SetJustifyH("LEFT")
	f.Text:SetFont("Fonts\\FRIZQT__.TTF", 13)

	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetSpellByID(self.ID)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT[self:GetChecked() and "IG_MAINMENU_OPTION_CHECKBOX_ON"
			or "IG_MAINMENU_OPTION_CHECKBOX_OFF"])
		UpdateHexCellSelection(self)
	end)

	return f
end

local rhexCheckButtons = {}
for i = 1, #rhexVariants do
	rhexCheckButtons[i] = CreateHexVariantCell(rhexScrollChild, rhexVariants[i][1], i)
end
rhexScrollChild:SetHeight(math.max(1, math.ceil(#rhexVariants / COLS) * ROW_STEP))

-- Select All button --
local rhexSelectAll = CreateFrame("Button", nil, rhexOptionsPanel, "UIPanelButtonTemplate")
rhexSelectAll:SetPoint("BOTTOMLEFT", 20, 15)
rhexSelectAll:SetSize(100,25)
rhexSelectAll:SetText("Select all")
rhexSelectAll:SetScript("OnClick", function(self)
	for i = 1, #rhexVariants do
		-- Skips the other faction's variant, which is locked off --
		if rhexCheckButtons[i]:IsEnabled() then
			rhexCheckButtons[i]:SetChecked(true)
			UpdateHexCellSelection(rhexCheckButtons[i])
		end
	end
end)

-- Deselect All button --
local rhexDeselectAll = CreateFrame("Button", nil, rhexOptionsPanel, "UIPanelButtonTemplate")
rhexDeselectAll:SetPoint("BOTTOMLEFT", 135, 15)
rhexDeselectAll:SetSize(100,25)
rhexDeselectAll:SetText("Deselect all")
rhexDeselectAll:SetScript("OnClick", function(self)
	for i = 1, #rhexVariants do
		rhexCheckButtons[i]:SetChecked(false)
		UpdateHexCellSelection(rhexCheckButtons[i])
	end
end)

--------------------------------------------------------------------
-- Init/Awake AddonLoaded Msg Handling & Loading
--------------------------------------------------------------------
local rhexListener = CreateFrame("Frame")
rhexListener:RegisterEvent("ADDON_LOADED")
rhexListener:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and arg1 == hex_addon then
		-- Settings beyond the per-variant checkboxes. Empty by default, so
		-- anything unset reads as "on" (see PushCombatHexOrder) --
		rhexSettings = rhexSettings or {}

		if rhexOptions == nil then
			-- Adds all hex variant IDs to savedvariables as enabled
			rhexOptions = {}
			for i=1, #rhexVariants do
				rhexOptions[i] = {rhexVariants[i][1], true}
			end
		else
			-- Deletes hex variant IDs that no longer exist in rhexVariants list
			for i,v in pairs(rhexOptions) do
				local chk = 0
				for l = 1, #rhexVariants do
					if v[1] == rhexVariants[l][1] then
						chk = 1
					end
				end
				if chk == 0 then 
					rhexOptions[i] = nil
				end
			end

			-- Adds any missing hex variant IDs to savedvariables as enabled
			for i,v in pairs(rhexVariants) do
				local chk = 0
				for l = 1, #rhexOptions do
					if v[1] == rhexOptions[l][1] then
						chk = 1
					end
				end
				if chk == 0 then
					table.insert(rhexOptions, {v[1], true})
				end
			end
		end
		
		-- Loop through options and set checkbox state
		for i,v in pairs(rhexOptions) do
			for l = 1, #rhexOptions do
				if rhexCheckButtons[l].ID == v[1] and v[2] == true then
					rhexCheckButtons[l]:SetChecked(true)
				end
			end
		end

		-- The cells carry their selected state in the border, not a tick
		-- box, so the restored state has to be painted on --
		for i = 1, #rhexCheckButtons do
			UpdateHexCellSelection(rhexCheckButtons[i])
		end
		ColorizeHexVariantText()

		self:UnregisterEvent("ADDON_LOADED")
	end
end)

--------------------------------------------------------------------
-- Assigned methods to the UI Panel's Confirm/Okay & Cancel [which Option UI updates where all changes are live with confirm, I'm not sure if the Cancel ever gets called. Perhaps in other use cases.
--------------------------------------------------------------------

function rhexOptionsOkay()
	-- Class Check!
	local classFilename, classId = UnitClassBase("player")
	if classFilename ~= "SHAMAN" then
		return
	end

	for i = 1, #rhexOptions do
		for _,v in pairs(rhexOptions) do
			if rhexCheckButtons[i].ID == v[1] then
				v[2] = rhexCheckButtons[i]:GetChecked()
			end
		end
	end

	RefreshRandomHexPool()
	SelectRandomHexVariant()
end

--------------------------------------------------------------------
-- Create an invisible button for our macro to click.
--  Button creation, named [rhexButton]
--------------------------------------------------------------------
-- SecureHandlerBaseTemplate as well, so the button can host its own
-- restricted environment and roll the variant during combat -- see the
-- snippet below --
local rhexBtn = CreateFrame("Button", "rhexButton", nil,  "SecureActionButtonTemplate,SecureHandlerBaseTemplate")

-- WoW client events we want to know about --
rhexBtn:RegisterEvent("PLAYER_ENTERING_WORLD")
rhexBtn:RegisterEvent("UNIT_SPELLCAST_START")
rhexBtn:RegisterEvent("UNIT_SPELLCAST_STOP")
rhexBtn:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
rhexBtn:RegisterEvent("PLAYER_LEAVE_COMBAT")
rhexBtn:RegisterEvent("PLAYER_REGEN_ENABLED")
rhexBtn:RegisterForClicks("LeftButtonDown", "LeftButtonUp" )
rhexBtn:SetAttribute("type","spell")

--------------------------------------------------------------------
-- Rolling a new variant DURING combat.
--
-- Lua can't touch the button's "spell" attribute in a lockdown, so the
-- variant used to be frozen for the whole fight -- and since Hex is a
-- combat spell, that meant every cast in a fight was the same critter. The
-- old post-combat path rolled once the fight ended, which is the one moment
-- you're not casting it.
--
-- Code running INSIDE the restricted environment has no such limit, so the
-- roll moves there for the duration of a fight. Out of combat nothing
-- changes: Lua still owns the rotation, because it can rewrite the macro
-- and the sandbox cannot.
--
-- The snippet walks a plain comma-separated order that Lua shuffles and
-- pushes in beforehand (see PushCombatHexOrder), so nothing clever has to
-- happen in there.
--
-- Known limit: EditMacro is unavailable in combat, so the macro's icon and
-- tooltip keep naming the variant from before the fight. Which critter it
-- says is wrong; that it's Hex, and its cooldown, stay right -- the
-- variants share both.
--------------------------------------------------------------------

-- Blizzard's Wrapped_Click only runs the post-body when the pre-body hands
-- back a message, so that is this one's whole job. Returning nil first
-- leaves the button name alone -- returning false there would swallow the
-- click entirely.
local RHEX_COMBAT_PRE = [[ return nil, "rhex" ]]

-- Runs AFTER the click has cast, so it sets up the NEXT press rather than
-- hijacking this one. Only on "LeftButton": the macro clicks this button
-- twice (see hexMacroSrc) and the other arrives as "1", so keying on the
-- name gives exactly one advance per press.
local RHEX_COMBAT_POST = [[
	if button ~= "LeftButton" then return end
	if self:GetAttribute("rhexCombatOff") then return end
	local combat = self:GetAttribute("state-rhexcombat")
	if combat ~= 1 and combat ~= "1" then return end
	local order = self:GetAttribute("rhexOrder")
	if not order or order == "" then return end
	local count = select("#", strsplit(",", order))
	if count < 1 then return end
	local pos = (tonumber(self:GetAttribute("rhexPos")) or 0) + 1
	if pos > count then pos = 1 end
	self:SetAttribute("rhexPos", pos)
	local id = tonumber((select(pos, strsplit(",", order))))
	if id then self:SetAttribute("spell", id) end
]]

if SecureHandlerWrapScript and RegisterStateDriver then
	-- The restricted environment can't call InCombatLockdown, so a state
	-- driver tells it when it's allowed to take over --
	RegisterStateDriver(rhexBtn, "rhexcombat", "[combat] 1; 0")
	SecureHandlerWrapScript(rhexBtn, "OnClick", rhexBtn, RHEX_COMBAT_PRE, RHEX_COMBAT_POST)
end

local hexWasCast = false
local hexCastId = 000000
-- Pass in an anonymous function which handles the events --
rhexBtn:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
	-- Capture any Hex Variant cast start --
	if event == "UNIT_SPELLCAST_START" and arg1 == "player" then
		if IsHexVariantSpellId(arg3) then
			hexCastId = arg3
		end
	end

	-- Combat just ended. The snippet has been rolling the button on its own,
	-- so whatever it landed on is the truth now -- adopt it before anything
	-- else gets a say, then hand the button a fresh order for next time --
	if event == "PLAYER_REGEN_ENABLED" then
		if AdoptCombatHex() then
			-- The rotation already moved on during the fight; letting the
			-- old post-combat path roll again would just burn a variant --
			hexWasCast = false
		end
		PushCombatHexOrder()
	end

	if not InCombatLockdown() then
		-- Out of Combat --
		if event == "PLAYER_ENTERING_WORLD" then
			RefreshRandomHexPool()
			SelectRandomHexVariant()
			-- Unregister from event --
			rhexBtn:UnregisterEvent("PLAYER_ENTERING_WORLD")
		end

		if  event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_STOP" then
			if arg1 == "player" and IsHexVariantSpellId(arg3) and hexCastId == arg3 then
				hexCastId = 000000
				SelectRandomHexVariant()
			end
		end
	else
		-- In Combat --
		if event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" then
			if IsHexVariantSpellId(arg3) then				
				hexWasCast = true

				if debugHex then
					print("== Hex used during combat") end
			end
		end
	end

	-- Always do whenever player leaves combat, regardless of lockdown
	if event == "PLAYER_LEAVE_COMBAT" then
		if debugHex then
			print("== Player Leaves Combat...") end

		if hexWasCast then
			WaitThenSetRandomHex()

			if debugHex then
				print("=== And Hex was cast!!") end
		end		
	end
end)

--------------------------------------------------------------------
-- Convenient to have a method to call that executes after timer completes
--------------------------------------------------------------------
function WaitThenSetRandomHex()
	local timeOut = 1
	C_Timer.After(timeOut, function()
		local ticker
		ticker = C_Timer.NewTicker(1, function()
			if InCombatLockdown() then
				WaitThenSetRandomHex()
			else
				-- Now call hex selection --
				if hexWasCast then
					if debugHex then
						print("==== Hex updated on post combat") end

					hexWasCast = false
					SelectRandomHexVariant()
				end
			end

			-- Always cancel the ticker
  			ticker:Cancel()
	    end)
	end)
end

--------------------------------------------------------------------
-- Generate the list of valid Hex Variants
--------------------------------------------------------------------
function RefreshRandomHexPool()
	-- Re-initialize
	rhexList = {}

	for i=1, #rhexOptions do
		if rhexOptions[i][2] == true then
			if IsSpellKnownOrOverridesKnown(rhexOptions[i][1]) then
				table.insert(rhexList,rhexOptions[i][1])
			end
		end
	end

	if debugHex then
		print("==== Refreshing Pool: " .. #rhexList) end

	ColorizeHexVariantText()
end

--------------------------------------------------------------------
-- Paints every cell: its icon, and whether this character has collected
-- the variant. Uncollected ones are desaturated and dimmed rather than
-- printed in red -- the same way an uncollected toy reads in Random Toys
-- and Random Lure, and it survives being read at a glance far better
-- than a colour code. Also keeps the collection bar honest.
--------------------------------------------------------------------
function ColorizeHexVariantText()
	local known, collectable = 0, 0

	for k in pairs(rhexVariants) do
		local spellId, variantName = rhexVariants[k][1], rhexVariants[k][2]
		local cell = rhexCheckButtons[k]

		-- Faction-locked variants say so, so a greyed-out entry explains
		-- itself rather than looking like something you simply missed --
		local faction = rhexVariants[k][3]
		local factionSuffix = faction and (" [" .. faction .. "]") or ""

		local spellInfo = C_Spell.GetSpellInfo(spellId)
		if spellInfo and spellInfo["originalIconID"] then
			cell.icon:SetTexture(spellInfo["originalIconID"])
		end

		local impossible = IsHexVariantImpossible(k)
		local isKnown = IsSpellKnownOrOverridesKnown(spellId) and true or false
		if isKnown then known = known + 1 end
		if not impossible then collectable = collectable + 1 end

		cell.icon:SetDesaturated(not isKnown)
		cell.Text:SetText(variantName .. factionSuffix)
		if impossible then
			-- Wrong faction: not merely uncollected, but unreachable --
			cell.Text:SetTextColor(1, 0.25, 0.25)
		elseif isKnown then
			cell.Text:SetTextColor(1, 1, 1)
		else
			cell.Text:SetTextColor(0.5, 0.5, 0.5)
		end

		-- A variant you can never cast isn't a choice, so it stops being one:
		-- the cell is locked and forced off rather than left tickable into a
		-- rotation it could never contribute to. The tooltip still works --
		-- a disabled button keeps its hover -- so the reason stays readable --
		if impossible then
			if cell:GetChecked() then cell:SetChecked(false) end
			cell:Disable()
		else
			cell:Enable()
		end
		UpdateHexCellSelection(cell)

		if debugHex then
			print("=== " .. variantName .. (impossible and " : Wrong faction"
				or (isKnown and " : Usable!" or " : NOT Usable!!"))) end
	end

	-- Counted against what this character could actually collect, so the
	-- other faction's variant isn't held permanently against you --
	rhexProgressBar:SetMinMaxValues(0, math.max(collectable, 1))
	rhexProgressBar:SetValue(known)
	if known >= collectable then
		-- All collected reads as a single number in the uncommon green, the
		-- way Blizzard's own collection bars do --
		rhexProgressText:SetText(tostring(collectable))
		rhexProgressText:SetTextColor(0.12, 1.0, 0.0)
	else
		rhexProgressText:SetText(known .. " / " .. collectable)
		rhexProgressText:SetTextColor(1, 1, 1)
	end
end

--------------------------------------------------------------------
-- Set random Hex Variant from a diminishing pool 
--------------------------------------------------------------------
function SelectRandomHexVariant()
	if debugHex then
		print("== remainingInPool_OnEnter: " .. #rhexList) end

	-- Make sure the poolList is not empty 
	if #rhexList == 0 then
		RefreshRandomHexPool()
	end

	-- Still no valid entries?
	if #rhexList == 0 then
		-- Default Hex --
		rhexBtn:SetAttribute("spell", 51514)
		UpdateRandomHexMacro("Hex(Frog)","237579")
		return
	end

	-- Get random index --
	local rnd = GetRandomHexVariantIndex(#rhexList)
	local randomHexIndexSpellId = rhexList[rnd]

	-- Get Spell Info with many return values --
	local spellInfo = C_Spell.GetSpellInfo(randomHexIndexSpellId)

	-- Update button --
	rhexBtn:SetAttribute("spell", spellInfo["spellID"])

	-- Build name and update macro --
	local hexVariantName = HexNameFromSpellId(randomHexIndexSpellId)
	local hexCompoundName = spellInfo["name"] .. "(" .. hexVariantName .. ")"
	UpdateRandomHexMacro(hexCompoundName, spellInfo["originalIconID"])

	if debugHex then
		print("=== Selected: " .. hexVariantName) end

	-- Once the hex variant data is loaded, remove the variant id from the pool --
	table.remove(rhexList, rnd)

	-- Hand the button a fresh order to walk if a fight starts --
	PushCombatHexOrder()
end

function HexNameFromSpellId(spellId)
	for i=1, #rhexVariants do
		if rhexVariants[i][1] == spellId then
			return rhexVariants[i][2]
		end
	end

	return ""
end

--------------------------------------------------------------------
-- Gets random index without allowing the same hex variant twice in a row
--   which could happen on pool refresh
--------------------------------------------------------------------
local prevHexId = -1
function GetRandomHexVariantIndex(size)
	if size > 1 then
		local rando = math.random(1,size)
		if rhexList[rando] == prevHexId then
			if rando == 1 then
				rando = size
			else
				rando = rando - 1
			end
		end

		prevHexId = rhexList[rando]
		return rando
	end

	if size == 1 then
		prevHexId = rhexList[1]
		return 1
	end

	return 0		
end

--------------------------------------------------------------------
-- Hands the button the order it walks while combat is on.
--
-- Deliberately the FULL set of enabled, known variants rather than what's
-- left of the current pass: Hex gets cast a lot in one fight, and being
-- stuck with the two variants that happened to remain would show far less
-- variety than the pool actually holds. Shuffled here, so the sandbox
-- never has to make a judgement call, and the variant already loaded is
-- left out so the first roll of a fight can't repeat it.
--
-- Out of combat only -- SetAttribute is exactly what a lockdown forbids.
--------------------------------------------------------------------
function PushCombatHexOrder()
	if InCombatLockdown() then return end

	-- The snippet reads this rather than being unwrapped, so "/hex combat"
	-- can switch in-combat rolling off without touching a secure handler --
	rhexBtn:SetAttribute("rhexCombatOff", rhexSettings and rhexSettings.combatRotation == false or nil)

	local current = tonumber(rhexBtn:GetAttribute("spell"))
	local order = {}
	for i = 1, #rhexOptions do
		local id = rhexOptions[i][1]
		if rhexOptions[i][2] == true and IsSpellKnownOrOverridesKnown(id) and id ~= current then
			table.insert(order, id)
		end
	end

	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end

	rhexBtn:SetAttribute("rhexOrder", table.concat(order, ","))
	rhexBtn:SetAttribute("rhexPos", 0)

	if debugHex then
		print("==== Combat order pushed: " .. #order) end
end

--------------------------------------------------------------------
-- Combat is over: catch Lua up with whatever the snippet rolled to while
-- it couldn't. This is the moment the macro's icon stops naming a variant
-- you stopped casting several hexes ago. Returns true if it adopted
-- something, so the caller knows the rotation already moved on.
--------------------------------------------------------------------
function AdoptCombatHex()
	if InCombatLockdown() then return false end

	local landed = tonumber(rhexBtn:GetAttribute("spell"))
	-- prevHexId is what Lua last chose, so anything else means the snippet
	-- moved it during the fight --
	if not landed or landed == prevHexId then return false end

	local spellInfo = C_Spell.GetSpellInfo(landed)
	if not spellInfo then return false end

	UpdateRandomHexMacro(spellInfo["name"] .. "(" .. HexNameFromSpellId(landed) .. ")",
		spellInfo["originalIconID"])

	-- It's been cast, so take it out of the remaining pass rather than
	-- letting it come round again straight away --
	for i = 1, #rhexList do
		if rhexList[i] == landed then
			table.remove(rhexList, i)
			break
		end
	end
	prevHexId = landed

	if debugHex then
		print("==== Adopted from combat: " .. HexNameFromSpellId(landed)) end

	return true
end

--------------------------------------------------------------------
-- Update/Create the global macro
--------------------------------------------------------------------
function UpdateRandomHexMacro(name,icon)
	if not InCombatLockdown() then
		local macroIndex = GetMacroIndexByName(HexMacroName)
		if macroIndex > 0 then
			EditMacro(macroIndex, HexMacroName, icon, "#showtooltip " .. name .. hexMacroSrc)
		else
			CreateMacro(HexMacroName, icon, "#showtooltip " .. name .. hexMacroSrc, nil)
		end
	end
end

--------------------------------------------------------------------
-- Create slash commands
--------------------------------------------------------------------
SLASH_RandomHex1 = "/hex"
function SlashCmdList.RandomHex(msg, editbox)
	-- "/hex combat" turns in-combat rolling on/off. It's the one part that
	-- runs inside WoW's restricted environment, where a fault would be
	-- silent, so a switch that doesn't need a reload is worth having --
	local arg = (msg or ""):lower():match("^%s*(%S*)")
	if arg == "combat" then
		rhexSettings = rhexSettings or {}
		rhexSettings.combatRotation = (rhexSettings.combatRotation == false)
		PushCombatHexOrder()
		print("|cff58C6FARandom Hex|r: rolling a new variant during combat is " ..
			(rhexSettings.combatRotation
				and "|cff40ff40on|r -- the macro icon still can't update until the fight ends."
				or "|cffff4040off|r -- a fight stays on whichever variant was loaded when it started."))
		return
	end

	Settings.OpenToCategory(rhexCategory:GetID())
end
