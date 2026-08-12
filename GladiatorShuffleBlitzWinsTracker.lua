local GWTVersion, seasonActive, currentGladAchievementId, currentLegendAchievementId, currentBlitzAchievementId
local GWT_Button, SWT_Button, BWT_Button

local function normalizeBool(value, default)
	if value == true or value == "true" then
		return true
	end
	if value == false or value == "false" then
		return false
	end
	return default
end

local function initializeSavedVariables()
	GWT_HideButton = normalizeBool(GWT_HideButton, false)
	SWT_HideButton = normalizeBool(SWT_HideButton, false)
	BWT_HideButton = normalizeBool(BWT_HideButton, false)
	GWT_LoginIntro = normalizeBool(GWT_LoginIntro, true)
end

StaticPopupDialogs["GSBT_ALERT_POPUP"] = StaticPopupDialogs["GSBT_ALERT_POPUP"] or {
	text = "%s",
	button1 = OKAY,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
	OnShow = function(self)
		local popupText = _G[self:GetName() .. "Text"]
		if popupText and GameFontHighlightLarge then
			local font, size, flags = GameFontHighlightLarge:GetFont()
			popupText:SetFont(font, size, flags)
		end
	end,
}

local function showAlertMessage(text)
	if not text then
		return
	end

	StaticPopup_Show("GSBT_ALERT_POPUP", text)
end

local function showNoActiveSeasonAlert()
	showAlertMessage("|cffffff00No active PVP season found.|r")
end

local function showIDMissingForSeasonAlert()
	showAlertMessage("|cffffff00Achievement missing for current season - please update addon.|r")
end

local function showAlreadyCompletedAlert()
	showAlertMessage("|cFF00FF00This character has already completed the achievement.|r")
end

local function shouldShowGladButton()
	return not GWT_HideButton
end

local function shouldShowShuffleButton()
	return not SWT_HideButton
end

local function shouldShowBlitzButton()
	return not BWT_HideButton
end

local function updateButtonsVisibility()
	local function setButtonVisibility(button, show)
		if not button then
			return
		end

		if show then
			button:Show()
		else
			button:Hide()
		end
	end

	setButtonVisibility(GWT_Button, shouldShowGladButton())
	setButtonVisibility(SWT_Button, shouldShowShuffleButton())
	setButtonVisibility(BWT_Button, shouldShowBlitzButton())
end

local function setCharGladSavedVariable(state)
	if state == "hide" then
		GWT_HideButton = true
	elseif state == "show" then
		GWT_HideButton = false
	elseif state == "reset" then
		GWT_HideButton = false
	end

	if GWT_Button then
		updateButtonsVisibility()
	end
end

local function setCharShuffleSavedVariable(state)
	if state == "hide" then
		SWT_HideButton = true
	elseif state == "show" then
		SWT_HideButton = false
	elseif state == "reset" then
		SWT_HideButton = false
	end

	if SWT_Button then
		updateButtonsVisibility()
	end
end

local function setCharBlitzSavedVariable(state)
	if state == "hide" then
		BWT_HideButton = true
	elseif state == "show" then
		BWT_HideButton = false
	elseif state == "reset" then
		BWT_HideButton = false
	end

	if BWT_Button then
		updateButtonsVisibility()
	end
end

local function setAccountSavedVariable(state)
	if state == "hide" then
		GWT_LoginIntro = false
	elseif state == "show" then
		GWT_LoginIntro = true
	end
end

local function setGWTVersion()
	local version = C_AddOns.GetAddOnMetadata("GladiatorShuffleBlitzWinsTracker", "Version")
	GWTVersion = version
end

local function getAchievementID(achievementType, season)
	local achievementTable = AchievementIDs[achievementType]
	local achievementEntry = achievementTable and achievementTable[season]

	if type(achievementEntry) == "table" then
		return achievementEntry.id or 0
	end

	return achievementEntry or 0
end

local function setCurrentPVPSeasonAchievementIds()
	local currentPVPSeason = GetCurrentArenaSeason()

	seasonActive = currentPVPSeason ~= 0

	currentGladAchievementId = getAchievementID("Gladiator", currentPVPSeason)
	currentLegendAchievementId = getAchievementID("ShuffleLegend", currentPVPSeason)
	currentBlitzAchievementId = getAchievementID("BlitzStrategist", currentPVPSeason)
end

local function toggleAchievementTracking(achievementId)
	local id, _, _, completed, _, _, _, _, _, _, _, _, wasEarnedByMe = GetAchievementInfo(achievementId)
	if completed and wasEarnedByMe then
		showAlreadyCompletedAlert()
	else
		C_ContentTracking.ToggleTracking(2, achievementId, 2)
	end
end

local function createButton(name, parentFrame, achievementId)
	local button = CreateFrame("Button", name, parentFrame, "UIPanelButtonTemplate")
	button:SetSize(25, 25)
	button:SetText(">")
	button:SetPoint("RIGHT", 10, 0)

	button:SetScript("OnClick", function()
		if not seasonActive then
			showNoActiveSeasonAlert()
		elseif achievementId == 0 then
			showIDMissingForSeasonAlert()
		else
			toggleAchievementTracking(achievementId)
		end
	end)

	return button
end

local function canCreateButtons()
	return ConquestFrame and ConquestFrame.Arena3v3 and ConquestFrame.RatedSoloShuffle and ConquestFrame.RatedBGBlitz
end

local ACHIEVEMENT_TABLE_COLUMNS = {
	{ key = "season", label = "", width = 0.34 },
	{ key = "Gladiator", label = "Gladiator", width = 0.2 },
	{ key = "ShuffleLegend", label = "Shuffle Legend", width = 0.23 },
	{ key = "BlitzStrategist", label = "Blitz Strategist", width = 0.23 },
}

local OPTIONS_TEXT_COLOR = NORMAL_FONT_COLOR_CODE or "|cffffd200"

local function getSortedAchievementSeasons()
	local seasons, seenSeasons = {}, {}

	for _, achievementType in ipairs({ "Gladiator", "ShuffleLegend", "BlitzStrategist" }) do
		local achievementsBySeason = AchievementIDs[achievementType]

		if achievementsBySeason then
			for season in pairs(achievementsBySeason) do
				if type(season) == "number" and not seenSeasons[season] then
					table.insert(seasons, season)
					seenSeasons[season] = true
				end
			end
		end
	end

	table.sort(seasons, function(a, b)
		return a > b
	end)

	return seasons
end

local function getAchievementExpansionInfo(season)
	local expansionName
	local expansionStartSeason

	if not AchievementIDs.ExpansionStartSeasons then
		return "Unknown Expansion", season
	end

	for startSeason, seasonInfo in pairs(AchievementIDs.ExpansionStartSeasons) do
		if startSeason <= season and (not expansionStartSeason or startSeason > expansionStartSeason) then
			expansionStartSeason = startSeason
			expansionName = seasonInfo.expansion
		end
	end

	return expansionName or "Unknown Expansion", expansionStartSeason or season
end

local function formatAchievementSeason(season)
	local expansionName, expansionStartSeason = getAchievementExpansionInfo(season)
	local expansionSeason = season - expansionStartSeason + 1

	return OPTIONS_TEXT_COLOR .. expansionName .. "|r |cffffffffS" .. expansionSeason .. "|r"
end

local function formatAchievementID(achievementId)
	if not achievementId or achievementId == 0 then
		return "|cff777777-|r"
	end

	return "|cffffffff" .. achievementId .. "|r"
end

local function createAchievementTableCell(parent, text, width, height, template, justifyH, achievementId)
	local cell = CreateFrame("Frame", nil, parent)
	cell:SetSize(width, height)

	local label = cell:CreateFontString(nil, "ARTWORK", template or "GameFontHighlightSmall")
	label:SetJustifyH(justifyH or "CENTER")
	label:SetJustifyV("MIDDLE")
	label:SetText(text)

	if achievementId and achievementId ~= 0 then
		local button = CreateFrame("Button", nil, cell, "UIPanelButtonTemplate")
		button:SetSize(20, 20)
		button:SetText(">")
		button:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
		button:SetScript("OnClick", function()
			toggleAchievementTracking(achievementId)
		end)

		label:SetPoint("LEFT", cell, "LEFT", 4, 0)
		label:SetPoint("RIGHT", button, "LEFT", -4, 0)
	else
		label:SetPoint("LEFT", cell, "LEFT", 4, 0)
		label:SetPoint("RIGHT", cell, "RIGHT", -4, 0)
	end

	label:SetPoint("TOP", cell, "TOP", 0, 0)
	label:SetPoint("BOTTOM", cell, "BOTTOM", 0, 0)

	return cell
end

local function createAchievementIDsTable(parent, anchor)
	local currentSeason = GetCurrentArenaSeason and GetCurrentArenaSeason() or 0
	local rowHeight = 26
	local contentBottomPadding = 10

	local sectionTitle = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	sectionTitle:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", -22, -28)
	sectionTitle:SetText("|cffffff00Achievement IDs|r")

	local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	section:SetPoint("TOPLEFT", sectionTitle, "BOTTOMLEFT", 2, -10)
	section:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	section:SetBackdropColor(0.035, 0.035, 0.045, 0.92)
	section:SetBackdropBorderColor(0.45, 0.36, 0.14, 0.95)

	local function resizeSectionBounds()
		local parentRight = parent:GetRight()
		local parentBottom = parent:GetBottom()
		local sectionLeft = section:GetLeft()
		local sectionTop = section:GetTop()

		if parentRight and sectionLeft then
			section:SetWidth(math.max(380, parentRight - sectionLeft - 24))
		else
			section:SetWidth(650)
		end

		if parentBottom and sectionTop then
			section:SetHeight(math.max(140, sectionTop - parentBottom - 42))
		else
			section:SetHeight(270)
		end
	end

	local header = CreateFrame("Frame", nil, section)
	header:SetHeight(rowHeight)
	header:SetPoint("TOPLEFT", section, "TOPLEFT", 16, -14)

	local resizeTargets = {}
	local previousCell
	for _, column in ipairs(ACHIEVEMENT_TABLE_COLUMNS) do
		local cell = createAchievementTableCell(header, "|cff33ff99" .. column.label .. "|r", 1, rowHeight, "GameFontNormalSmall", column.key == "season" and "LEFT" or nil)
		if previousCell then
			cell:SetPoint("LEFT", previousCell, "RIGHT", 0, 0)
		else
			cell:SetPoint("LEFT", header, "LEFT", 0, 0)
		end
		table.insert(resizeTargets, { cell = cell, column = column })
		previousCell = cell
	end

	local scrollFrame = CreateFrame("ScrollFrame", nil, section, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
	scrollFrame:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", -42, 8)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(1, 1)
	scrollFrame:SetScrollChild(content)

	local seasons = getSortedAchievementSeasons()
	local rows = {}
	local previousRow

	for index, season in ipairs(seasons) do
		local row = CreateFrame("Frame", nil, content)
		row:SetHeight(rowHeight)
		if previousRow then
			row:SetPoint("TOPLEFT", previousRow, "BOTTOMLEFT", 0, 0)
		else
			row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
		end

		local rowBg = row:CreateTexture(nil, "BACKGROUND")
		rowBg:SetAllPoints()
		if season == currentSeason then
			rowBg:SetColorTexture(0.09, 0.27, 0.14, 0.85)
		elseif index % 2 == 0 then
			rowBg:SetColorTexture(0.075, 0.077, 0.087, 0.86)
		else
			rowBg:SetColorTexture(0.035, 0.037, 0.045, 0.88)
		end

		local rowAchievementIds = {
			Gladiator = getAchievementID("Gladiator", season),
			ShuffleLegend = getAchievementID("ShuffleLegend", season),
			BlitzStrategist = getAchievementID("BlitzStrategist", season),
		}

		local rowValues = {
			season = formatAchievementSeason(season),
			Gladiator = formatAchievementID(rowAchievementIds.Gladiator),
			ShuffleLegend = formatAchievementID(rowAchievementIds.ShuffleLegend),
			BlitzStrategist = formatAchievementID(rowAchievementIds.BlitzStrategist),
		}

		previousCell = nil
		for _, column in ipairs(ACHIEVEMENT_TABLE_COLUMNS) do
			local cell = createAchievementTableCell(row, rowValues[column.key], 1, rowHeight, "GameFontHighlightSmall", column.key == "season" and "LEFT" or nil, rowAchievementIds[column.key])
			if previousCell then
				cell:SetPoint("LEFT", previousCell, "RIGHT", 0, 0)
			else
				cell:SetPoint("LEFT", row, "LEFT", 0, 0)
			end
			table.insert(resizeTargets, { cell = cell, column = column })
			previousCell = cell
		end

		table.insert(rows, row)
		previousRow = row
	end

	content:SetHeight(math.max(1, #seasons * rowHeight + contentBottomPadding))

	local function resizeAchievementTable()
		local tableWidth = math.max(360, section:GetWidth() - 58)
		header:SetWidth(tableWidth)
		content:SetWidth(tableWidth)

		for _, row in ipairs(rows) do
			row:SetWidth(tableWidth)
		end

		for _, target in ipairs(resizeTargets) do
			target.cell:SetWidth(math.floor(tableWidth * target.column.width))
		end
	end

	section:HookScript("OnSizeChanged", resizeAchievementTable)
	section:HookScript("OnShow", resizeSectionBounds)
	parent:HookScript("OnSizeChanged", resizeSectionBounds)
	resizeSectionBounds()
	resizeAchievementTable()
end

local function createButtons()
	if not canCreateButtons() then
		return false
	end

	GWT_Button = createButton("GWTButton", ConquestFrame.Arena3v3, currentGladAchievementId)
	SWT_Button = createButton("SWTButton", ConquestFrame.RatedSoloShuffle, currentLegendAchievementId)
	BWT_Button = createButton("BWTButton", ConquestFrame.RatedBGBlitz, currentBlitzAchievementId)

	return true
end

local function createOptionsPanel()
	local frame = CreateFrame("Frame", "GWTOptionsPanel", UIParent)
	frame.name = "Gladiator, Shuffle & Blitz Wins Tracker"

	local function newCheckbox(label, onClick)
		local check = CreateFrame("CheckButton", "GWTCheck" .. label, frame, "InterfaceOptionsCheckButtonTemplate")
		check:SetScript("OnClick", function(self)
			local tick = self:GetChecked()
			onClick(self, tick and true or false)
		end)
		check.label = _G[check:GetName() .. "Text"]
		check.label:SetText(label)
		return check
	end

	local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Gladiator, Shuffle & Blitz Wins Tracker")

	local charTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	charTitle:SetText("|cffffff00Character Settings|r")
	charTitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -2, -16)

	local hideGladCheckbox = newCheckbox("Hide |cff33ff993v3|r button on this character", function(_, value)
		if value then
			setCharGladSavedVariable("hide")
		else
			setCharGladSavedVariable("show")
		end
	end)
	hideGladCheckbox:SetChecked(GWT_HideButton == true)
	hideGladCheckbox:SetPoint("TOPLEFT", charTitle, "BOTTOMLEFT", 20, -16)

	local hideShuffleCheckbox = newCheckbox("Hide |cff33ff99Shuffle|r button on this character", function(_, value)
		if value then
			setCharShuffleSavedVariable("hide")
		else
			setCharShuffleSavedVariable("show")
		end
	end)
	hideShuffleCheckbox:SetChecked(SWT_HideButton == true)
	hideShuffleCheckbox:SetPoint("TOPLEFT", hideGladCheckbox, "BOTTOMLEFT", 0, -8)

	local hideBlitzCheckbox = newCheckbox("Hide |cff33ff99Blitz|r button on this character", function(_, value)
		if value then
			setCharBlitzSavedVariable("hide")
		else
			setCharBlitzSavedVariable("show")
		end
	end)
	hideBlitzCheckbox:SetChecked(BWT_HideButton == true)
	hideBlitzCheckbox:SetPoint("TOPLEFT", hideShuffleCheckbox, "BOTTOMLEFT", 0, -8)

	local resetButton = CreateFrame("Button", "GTWResetButton", frame, "UIPanelButtonTemplate")
	resetButton:SetText("Reset")
	resetButton:SetWidth(90)
	resetButton:SetHeight(30)
	resetButton:SetPoint("TOPLEFT", hideBlitzCheckbox, "BOTTOMLEFT", -20, -15)
	resetButton:SetScript("OnClick", function()
		setCharGladSavedVariable("reset")
		setCharShuffleSavedVariable("reset")
		setCharBlitzSavedVariable("reset")

		hideGladCheckbox:SetChecked(GWT_HideButton == true)
		hideShuffleCheckbox:SetChecked(SWT_HideButton == true)
		hideBlitzCheckbox:SetChecked(BWT_HideButton == true)
	end)

	local accountSettingsTitle = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	accountSettingsTitle:SetText("|cffffff00Account Settings|r")
	accountSettingsTitle:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", -2, -16)

	local hideIntroCheckbox = newCheckbox("Disable login message", function(_, value)
		if value then
			setAccountSavedVariable("hide")
		else
			setAccountSavedVariable("show")
		end
	end)
	hideIntroCheckbox:SetChecked(not GWT_LoginIntro)
	hideIntroCheckbox:SetPoint("TOPLEFT", accountSettingsTitle, "TOPLEFT", 20, -25)

	createAchievementIDsTable(frame, hideIntroCheckbox)

	local versionText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	versionText:SetText("|cffffff00Version:|r |cffffffff" .. (GWTVersion or "Unknown") .. "|r")
	versionText:SetJustifyH("RIGHT")
	versionText:SetSize(600, 40)
	versionText:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -5)

	local authorText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	authorText:SetText("|cffffff00Author:|r |cffffffffDezopri|r")
	authorText:SetJustifyH("RIGHT")
	authorText:SetSize(600, 40)
	authorText:SetPoint("TOPLEFT", versionText, "TOPLEFT", 0, -20)

	return frame
end

local function registerOptionsPanel()
	local optionsPanel = createOptionsPanel()

	local category, layout = Settings.RegisterCanvasLayoutCategory(optionsPanel, "Gladiator, Shuffle & Blitz Wins Tracker")
	Settings.RegisterAddOnCategory(category)

	SLASH_GSBT1 = "/gsbt"
	SlashCmdList["GSBT"] = function()
		Settings.OpenToCategory(category.ID)
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == "GladiatorShuffleBlitzWinsTracker" then
		initializeSavedVariables()
		setGWTVersion()
		registerOptionsPanel()
	end

	if event == "ADDON_LOADED" and arg1 == "Blizzard_PVPUI" then
		if createButtons() then
			updateButtonsVisibility()
		end
	end

	if event == "PLAYER_LOGIN" then
		setCurrentPVPSeasonAchievementIds()

		if GWT_LoginIntro then
			print("|cff33ff99Gladiator, Shuffle & Blitz Wins Tracker|r - use |cffFF4500 /gsbt |r to open options")
		end
	end
end)
