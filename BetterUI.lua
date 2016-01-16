local wm = GetWindowManager()
local em = GetEventManager()
local _

if BUI == nil then BUI = {} end

BUI.name = "BetterUI"
BUI.version = "0.1"

local LAM = LibStub:GetLibrary("LibAddonMenu-2.0")

BUI.settings = {}
BUI.inventory = {}

BUI.defaults = {
	showUnitPrice=true,
	showMMPrice=true
}

function BUI.SetupOptionsMenu()

	local panelData = {
		type = "panel",
		name = BUI.name,
		displayName = "Better gamepad interface Settings",
		author = "prasoc",
		version = BUI.version,
		slashCommand = "/bui",	--(optional) will register a keybind to open to this panel
		registerForRefresh = true,	--boolean (optional) (will refresh all options controls when a setting is changed and when the panel is shown)
		registerForDefaults = false,	--boolean (optional) (will set all options controls back to default values)
	}

	local optionsTable = {
		[1] = {
			type = "header",
			name = "General Settings",
			width = "full",	--or "half" (optional)
		},
		[2] = {
			type = "description",
			--title = "My Title",	--(optional)
			title = nil,	--(optional)
			text = "Toggle main addon functions here",
			width = "full",	--or "half" (optional)
		},
		[3] = {
			type = "checkbox",
			name = "Unit Price in Guild Store",
			tooltip = "Displays a price per unit in guild store listings",
			getFunc = function() return BUI.settings.showUnitPrice end,
			setFunc = function(value) BUI.settings.showUnitPrice = value end,
			width = "full",	--or "half" (optional)
		},
		[4] = {
			type = "checkbox",
			name = "MasterMerchant Price in Guild Store",
			tooltip = "Displays the MM percentage in guild store listings",
			getFunc = function() return BUI.settings.showMMPrice end,
			setFunc = function(value) BUI.settings.showMMPrice = value end,
			width = "full",	--or "half" (optional)
		},
	}
	LAM:RegisterAddonPanel("NewUI", panelData)
	LAM:RegisterOptionControls("NewUI", optionsTable)
end

local function PostHook(control, method, postHookFunction, overwriteOriginal)
	if control == nil then return end

	local originalMethod = control[method]
	control[method] = function(self, ...)
		if(overwriteOriginal == false) then originalMethod(self, ...) end
		postHookFunction(self, ...)
	end
end


local function SetupGStoreListing(control, data, selected, selectedDuringRebuild, enabled, activated)
    ZO_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
    local notEnoughMoney = data.purchasePrice > GetCarriedCurrencyAmount(CURT_MONEY)
    ZO_CurrencyControl_SetSimpleCurrency(control.price, CURT_MONEY, data.purchasePrice, ZO_GAMEPAD_CURRENCY_OPTIONS, CURRENCY_SHOW_ALL, notEnoughMoney)
    local sellerControl = control:GetNamedChild("SellerName")
    local unitPriceControl = control:GetNamedChild("UnitPrice")
    local buyingAdviceControl = control:GetNamedChild("BuyingAdvice")
    local sellerName, dealString, margin

    if(BUI.MMIntegration) then
    	sellerName, dealString, margin = zo_strsplit(';', data.sellerName)
    else
    	sellerName = data.sellerName
   	end

    if(BUI.settings.showMMPrice) then
	    dealValue = tonumber(dealString)

	    local r, g, b = GetInterfaceColor(INTERFACE_COLOR_TYPE_ITEM_QUALITY_COLORS, dealValue)
        if dealValue == 0 then r = 0.98; g = 0.01; b = 0.01; end

        buyingAdviceControl:SetHidden(false)
        buyingAdviceControl:SetColor(r, g, b, 1)
        buyingAdviceControl:SetText(margin..'%')

   		sellerControl:SetText(ZO_FormatUserFacingDisplayName(sellerName))
	else
		buyingAdviceControl:SetHidden(true)
   		sellerControl:SetText(ZO_FormatUserFacingDisplayName(sellerName))
	end

    if(BUI.settings.showUnitPrice) then
	   	if(data.stackCount ~= 1) then 
	    	unitPriceControl:SetHidden(false)
	    	unitPriceControl:SetText(zo_strformat("@<<1>>|t16:16:EsoUI/Art/currency/currency_gold.dds|t",data.purchasePrice/data.stackCount))
	    else 
	    	unitPriceControl:SetHidden(true)
	    end
    else
    	unitPriceControl:SetHidden(true)
    end

    local timeRemainingControl = control:GetNamedChild("TimeLeft")
    if data.isGuildSpecificItem then
        timeRemainingControl:SetHidden(true)
    else
        timeRemainingControl:SetHidden(false)
        timeRemainingControl:SetText(zo_strformat(SI_TRADING_HOUSE_BROWSE_ITEM_REMAINING_TIME, ZO_FormatTime(data.timeRemaining, TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT_DESCRIPTIVE, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING)))
    end
end

local mystyle = { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1, }

local function AddInfo_Gamepad(tooltip, itemLink)
	if itemLink then

		local tipLine, avePrice, graphInfo = MasterMerchant:itemPriceTip(itemLink, false, clickable)

		tooltip:AddLine(zo_strformat("<<1>>",tipLine), mystyle, tooltip:GetStyle("bodySection"))
	end
end

local function TooltipHook_Gamepad(tooltipControl, method, linkFunc)
	local origMethod = tooltipControl[method]

	tooltipControl[method] = function(self, ...)
		origMethod(self, ...)
		AddInfo_Gamepad(self, linkFunc(...))
	end
end

-- This helper function is just there in case the position of the item-link will change
local function ReturnItemLink(itemLink)
	return itemLink
end

function BUI.HookBagTips()
	TooltipHook_Gamepad(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP), "LayoutItem", ReturnItemLink)
	TooltipHook_Gamepad(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP), "LayoutItem", ReturnItemLink)
	TooltipHook_Gamepad(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_MOVABLE_TOOLTIP), "LayoutItem", ReturnItemLink)
end

function BUI.SetupMMIntegration() 
  	if MasterMerchant.LibAddonInit == nil then 
  		BUI.MMIntegration = false
  		return 
  	end
  	MasterMerchant.initBuyingAdvice = function(self, ...) end
  	MasterMerchant.initSellingAdvice = function(self, ...) end
  	MasterMerchant.AddBuyingAdvice = function(rowControl, result) end
  	MasterMerchant.AddSellingAdvice = function(rowControl, result)	end

  	BUI.HookBagTips()

  	BUI.MMIntegration = true
end

function BUI.SetupCustomGuildResults()

	-- overwrite old results scrolllist data type and replace:
	GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:GetList().dataTypes["ZO_TradingHouse_ItemListRow_Gamepad"]=nil
	GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:GetList().dataTypes["NewUI_ItemListRow_Gamepad"] = {
            pool = ZO_ControlPool:New("NewUI_ItemListRow_Gamepad", GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS:GetList().scrollControl, "NewUI_ItemListRow_Gamepad"),
            setupFunction = SetupGStoreListing,
            parametricFunction = ZO_GamepadMenuEntryTemplateParametricListFunction,
            equalityFunction = function(l,r) return l == r end,
            hasHeader = false,
        }

     PostHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "UpdateRightTooltip", function(self, selectedData)
     	--d("[BUI] Changed guild store selection, and hooked into the update!")
     	end, false)

     PostHook(UNIT_FRAMES.staticFrames.reticleover,"RefreshControls", function(self) 
     	if(self.hidden) then
	        self.dirty = true
	    else
	        if(self.hasTarget) then
	            if self.nameLabel then
	                local name
	                if IsInGamepadPreferredMode() and IsUnitPlayer(self.unitTag) then
	                    name = zo_strformat("|cff6600<<1>>|r<<2>>",ZO_FormatUserFacingDisplayName(GetUnitName(self.unitTag)),GetUnitDisplayName(self.unitTag))
	                else
	                    name = GetUnitName(self.unitTag)
	                end
	                self.nameLabel:SetText(name)
	            end
	            self:UpdateUnitReaction()
	            self:UpdateLevel()
	            self:UpdateCaption()
	            local health, maxHealth = GetUnitPower(self.unitTag, POWERTYPE_HEALTH)
	            self.healthBar:Update(POWERTYPE_HEALTH, health, maxHealth, FORCE_INIT)
	            for i = 1, NUM_POWER_POOLS do
	                local powerType, cur, max = GetUnitPowerInfo(self.unitTag, i)
	                self:UpdatePowerBar(i, powerType, cur, max, FORCE_INIT)
	            end
	            self:UpdateStatus(IsUnitDead(self.unitTag), IsUnitOnline(self.unitTag))
	            self:UpdateRank()
	            self:UpdateDifficulty()
	            self:DoAlphaUpdate(IsUnitInGroupSupportRange(self.unitTag), IsUnitOnline(self.unitTag), IsUnitGroupLeader(unitTag))
	        end
    	end
     end, true)

    -- overwrite old results add entry function to use the new scrolllist datatype:
	PostHook(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, "AddEntryToList", function(self, itemData) 
		self.footer.pageNumberLabel:SetHidden(false)
        self.footer.pageNumberLabel:SetText(zo_strformat("<<1>>", self.currentPage + 1)) -- Pages start at 0, offset by 1 for expected display number
        if(itemData) then
	        local entry = ZO_GamepadEntryData:New(itemData.name, itemData.iconFile)
	        entry:InitializeTradingHouseVisualData(itemData)
	        self:GetList():AddEntry("NewUI_ItemListRow_Gamepad", 
	                                entry, 
	                                SCROLL_LIST_HEADER_OFFSET_VALUE, 
	                                SCROLL_LIST_HEADER_OFFSET_VALUE, 
	                                SCROLL_LIST_SELECTED_OFFSET_VALUE, 
	                                SCROLL_LIST_SELECTED_OFFSET_VALUE)
    	end
	end, true)
end


function BUI.Initialize(event, addon)
    -- filter for just BUI addon event
	if addon ~= BUI.name then return end

	-- load our saved variables
	BUI.settings = ZO_SavedVars:New("BetterUISavedVars", 1, nil, BUI.defaults)
	em:UnregisterForEvent("BetterUIInitialize", EVENT_ADD_ON_LOADED)

	if(IsInGamepadPreferredMode()) then
		BUI.SetupCustomGuildResults()
		BUI.SetupMMIntegration()

	else
		d("[BUI] Not Loaded: gamepad mode disabled.")
	end

	BUI.SetupOptionsMenu()
end

-- register our event handler function to be called to do initialization
em:RegisterForEvent(BUI.name, EVENT_ADD_ON_LOADED, function(...) BUI.Initialize(...) end)