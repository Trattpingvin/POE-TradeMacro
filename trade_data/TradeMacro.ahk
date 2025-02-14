﻿;TradeMacro Add-on to POE-ItemInfo
; IGN: Eruyome

PriceCheck:
	IfWinActive, Path of Exile ahk_class POEWindowClass 
	{
		Global TradeOpts, Item
		Item := {}
		SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event
		Send ^{sc02E}
		Sleep 250
		TradeFunc_Main()
		SuspendPOEItemScript = 0 ; Allow Item info to handle clipboard change event
	}
return

AdvancedPriceCheck:
	IfWinActive, Path of Exile ahk_class POEWindowClass 
	{
		Global TradeOpts, Item
		Item := {}
		SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event
		Send ^{sc02E}
		Sleep 250
		TradeFunc_Main(false, true)
		SuspendPOEItemScript = 0 ; Allow Item info to handle clipboard change event
	}
return

ShowItemAge:
	IfWinActive, Path of Exile ahk_class POEWindowClass 
	{
		Global TradeOpts, Item
		If (!TradeOpts.AccountName) {
			ShowTooltip("No Account Name specified in settings menu.")
			return
		}
		Item := {}
		SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event
		Send ^{sc02E}
		Sleep 250
		TradeFunc_Main(false, false, false, true)
		SuspendPOEItemScript = 0 ; Allow Item info to handle clipboard change event
	}
return

OpenWiki:
	IfWinActive, Path of Exile ahk_class POEWindowClass 
	{
		Global TradeOpts, Item
		Item := {}
		SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event
		Send ^{sc02E}
		Sleep 250
		TradeFunc_DoParseClipboard()

		If (!Item.Name and TradeOpts.OpenUrlsOnEmptyItem) {
			TradeFunc_OpenUrlInBrowser("http://pathofexile.gamepedia.com/")
			return
		}
		
		If (Item.IsUnique or Item.IsGem or Item.IsDivinationCard or Item.IsCurrency) {
			UrlAffix := Item.Name
		} Else If (Item.IsFlask or Item.IsMap) {
			UrlAffix := Item.SubType
		} Else If (RegExMatch(Item.Name, "i)Sacrifice At") or RegExMatch(Item.Name, "i)Fragment of") or RegExMatch(Item.Name, "i)Mortal ") or RegExMatch(Item.Name, "i)Offering to ") or RegExMatch(Item.Name, "i)'s Key")) {
			UrlAffix := Item.Name
		} Else {
			UrlAffix := Item.BaseType
		}
		
		If (StrLen(UrlAffix) > 0) {			
			UrlAffix := StrReplace(UrlAffix," ","_")
			WikiUrl := "http://pathofexile.gamepedia.com/" UrlAffix		
			TradeFunc_OpenUrlInBrowser(WikiUrl)	
		}
		
		SuspendPOEItemScript = 0 ; Allow Item info to handle clipboard change event
	}
return

CustomInputSearch:
	IfWinActive, Path of Exile ahk_class POEWindowClass 
	{
		ScreenOffsetY := A_ScreenHeight / 2 - 50
		ScreenOffsetX := A_ScreenWidth / 2 - 125
		
		InputBox,ItemName,Price Check,Item Name,,250,100,%ScreenOffsetX%,%ScreenOffsetY%,,30,
		If ItemName {
			RequestParams := new RequestParams_()
			LeagueName := TradeGlobals.Get("LeagueName")
			RequestParams.name   := ItemName
			RequestParams.league := LeagueName
			Item.Name := ItemName
			
			ShowToolTip("Running search...")
			
			Payload := RequestParams.ToPayload()
			Html := TradeFunc_DoPostRequest(Payload)
			ParsedData := TradeFunc_ParseHtml(Html, Payload)
			SetClipboardContents(ParsedData)
			
			ShowToolTip("")
			ShowToolTip(ParsedData, true)
		}
	}
return

OpenSearchOnPoeTrade:
	Global TradeOpts, Item
	Item := {}
	SuspendPOEItemScript = 1 ; This allows us to handle the clipboard change event
	Send ^{sc02E}
	Sleep 250
	
	TradeFunc_DoParseClipboard()
	If (!Item.Name and TradeOpts.OpenUrlsOnEmptyItem) {
		TradeFunc_OpenUrlInBrowser("http://poe.trade/")
		return
	}
	
	TradeFunc_Main(true)
	SuspendPOEItemScript = 0 ; Allow Item info to handle clipboard change event
return

; Prepare Reqeust Parametes and send Post Request
; openSearchInBrowser : set to true to open the search on poe.trade instead of showing the tooltip
; isAdvancedPriceCheck : set to true If the GUI to select mods should be openend
; isAdvancedPriceCheckRedirect : set to true If the search is triggered from the GUI
; isItemAgeRequest : set to true to check own listed items age
TradeFunc_Main(openSearchInBrowser = false, isAdvancedPriceCheck = false, isAdvancedPriceCheckRedirect = false, isItemAgeRequest = false)
{	
	LeagueName := TradeGlobals.Get("LeagueName")
	Global Item, ItemData, TradeOpts, mapList, uniqueMapList, Opts
		
	TradeFunc_DoParseClipboard()
	iLvl     := Item.Level
	
	; cancel search If Item is empty
	If (!Item.name) {
		If (TradeOpts.OpenUrlsOnEmptyItem) {
			TradeFunc_OpenUrlInBrowser("https://poe.trade")
		}
		return
	}
	
	If (Opts.ShowMaxSockets != 1) {
		TradeFunc_SetItemSockets()
	}
	
	Stats := {}
	Stats.Quality := Item.Quality
	DamageDetails := Item.DamageDetails
	Name := Item.Name

	Item.UsedInSearch := {}
	Item.UsedInSearch.iLvl := {}
	
	RequestParams := new RequestParams_()
	RequestParams.league := LeagueName
	RequestParams.buyout := "1"
	
	; ignore item name in certain cases
	If (!Item.IsJewel and Item.RarityLevel > 1 and Item.RarityLevel < 4 and !Item.IsFlask or (Item.IsJewel and isAdvancedPriceCheckRedirect)) {
		IgnoreName := true
	}
	If (Item.RarityLevel > 0 and Item.RarityLevel < 4 and (Item.IsWeapon or Item.IsArmour or Item.IsRing or Item.IsBelt or Item.IsAmulet)) {
		IgnoreName := true
	}
	
	; check If the item implicit mod is an enchantment or corrupted. retrieve this mods data.
	Enchantment := false
	Corruption  := false

	If (Item.hasImplicit) {
		Enchantment := TradeFunc_GetEnchantment(Item, Item.SubType)
		Corruption  := Item.IsCorrupted ? TradeFunc_GetCorruption(Item) : false
	}	

	If (Item.IsWeapon or Item.IsArmour and not Item.IsUnique) {
		Stats.Defense := TradeFunc_ParseItemDefenseStats(ItemData.Stats, Item)
		Stats.Offense := TradeFunc_ParseItemOffenseStats(DamageDetails, Item)	
	}
	
	If (Item.IsWeapon or Item.IsArmour or (Item.IsFlask and Item.RarityLevel > 1) or Item.IsJewel or (Item.IsMap and Item.RarityLevel > 1) of Item.IsBelt or Item.IsRing or Item.IsAmulet) 
	{
		hasAdvancedSearch := true
	}

	If (!Item.IsUnique) {		
		preparedItem  := TradeFunc_PrepareNonUniqueItemMods(ItemData.Affixes, Item.Implicit, Item.RarityLevel, Enchantment, Corruption, Item.IsMap)
		Stats.Defense := TradeFunc_ParseItemDefenseStats(ItemData.Stats, preparedItem)
		Stats.Offense := TradeFunc_ParseItemOffenseStats(DamageDetails, preparedItem)	
		
		If (isAdvancedPriceCheck and hasAdvancedSearch) {
			If (Enchantment) {
				TradeFunc_AdvancedPriceCheckGui(preparedItem, Stats, ItemData.Sockets, ItemData.Links, "", Enchantment)
			}
			Else If (Corruption) {
				TradeFunc_AdvancedPriceCheckGui(preparedItem, Stats, ItemData.Sockets, ItemData.Links, "", Corruption)
			} 
			Else {
				TradeFunc_AdvancedPriceCheckGui(preparedItem, Stats, ItemData.Sockets, ItemData.Links)
			}				
			return
		}	
		Else If (isAdvancedPriceCheck and not hasAdvancedSearch) {
			ShowToolTip("Advanced search not available for this item.")
			return
		}
	}
	
	If (Item.IsUnique) {		
		; returns mods with their ranges of the searched item If it is unique and has variable mods
		uniqueWithVariableMods :=
		uniqueWithVariableMods := TradeFunc_FindUniqueItemIfItHasVariableRolls(Name)
		
		; Return If the advanced search was used but the checked item doesn't have variable mods
		if(!uniqueWithVariableMods and isAdvancedPriceCheck and not Enchantment and not Corruption) {
			ShowToolTip("Advanced search not available for this item (no variable mods)`nor item is new and the necessary data is not yet available/updated.")
			return
		}
		
		UniqueStats := TradeFunc_GetUniqueStats(Name)
		If (uniqueWithVariableMods) {
			Gui, SelectModsGui:Destroy
			
			preparedItem :=
			preparedItem := TradeFunc_GetItemsPoeTradeUniqueMods(uniqueWithVariableMods)	
			Stats.Defense := TradeFunc_ParseItemDefenseStats(ItemData.Stats, preparedItem)
			Stats.Offense := TradeFunc_ParseItemOffenseStats(DamageDetails, preparedItem)	
			
			; open TradeFunc_AdvancedPriceCheckGui to select mods and their min/max values
			If (isAdvancedPriceCheck) {
				UniqueStats := TradeFunc_GetUniqueStats(Name)
				If (Enchantment) {
					TradeFunc_AdvancedPriceCheckGui(preparedItem, Stats, ItemData.Sockets, ItemData.Links, UniqueStats, Enchantment)
				}
				Else If (Corruption) {
					TradeFunc_AdvancedPriceCheckGui(preparedItem, Stats, ItemData.Sockets, ItemData.Links, UniqueStats, Corruption)
				} 
				Else {
					TradeFunc_AdvancedPriceCheckGui(preparedItem, Stats, ItemData.Sockets, ItemData.Links, UniqueStats)
				}				
				return
			}
		}
		Else {
			RequestParams.name   := Trim(StrReplace(Name, "Superior", ""))		
			Item.UsedInSearch.FullName := true
		}	
		
		; only find items that can have the same amount of sockets
		If (Item.MaxSockets = 6) {
			RequestParams.ilevel_min  := 50
			Item.UsedInSearch.iLvl.min:= 50
		} 
		Else If (Item.MaxSockets = 5) {
			RequestParams.ilevel_min := 35
			RequestParams.ilevel_max := 49
			Item.UsedInSearch.iLvl.min := 35
			Item.UsedInSearch.iLvl.max := 49
		} 
		Else If (Item.MaxSockets = 5) {
			RequestParams.ilevel_min := 35
			Item.UsedInSearch.iLvl.min := 35
		}
		; is (no 1-hand or shield or unset ring or helmet or glove or boots) but is weapon or armor
		Else If ((not Item.IsFourSocket and not Item.IsThreeSocket and not Item.IsSingleSocket) and (Item.IsWeapon or Item.IsArmour) and Item.Level < 35) {		
			RequestParams.ilevel_max := 34
			Item.UsedInSearch.iLvl.max := 34
		}	

		; set links to max for corrupted items with 3/4 max sockets if the own item is fully linked
		If (Item.IsCorrupted and TradeOpts.ForceMaxLinks) {
			If (Item.MaxSockets = 4 and ItemData.Links = 4) {
				RequestParams.link_min := 4
			}
			Else If (Item.MaxSockets = 3 and ItemData.Links = 3) {
				RequestParams.link_min := 3
			}
		}
	}
	
	; ignore mod rolls unless the TradeFunc_AdvancedPriceCheckGui is used to search
	AdvancedPriceCheckItem := TradeGlobals.Get("AdvancedPriceCheckItem")
	If (isAdvancedPriceCheckRedirect) {
		; submitting the AdvancedPriceCheck Gui sets TradeOpts.Set("AdvancedPriceCheckItem") with the edited item (selected mods and their min/max values)
		s := TradeGlobals.Get("AdvancedPriceCheckItem")
		Loop % s.mods.Length() {
			If (s.mods[A_Index].selected > 0) {
				modParam := new _ParamMod()
				modParam.mod_name := s.mods[A_Index].param
				modParam.mod_min := s.mods[A_Index].min
				modParam.mod_max := s.mods[A_Index].max
				RequestParams.modGroup.AddMod(modParam)
			}	
		}
		Loop % s.stats.Length() {
			If (s.stats[A_Index].selected > 0) {
				; defense
				If (InStr(s.stats[A_Index].Param, "Armour")) {
					RequestParams.armour_min  := (s.stats[A_Index].min > 0) ? s.stats[A_Index].min : ""
					RequestParams.armour_max  := (s.stats[A_Index].max > 0) ? s.stats[A_Index].max : ""
				} 
				Else If (InStr(s.stats[A_Index].Param, "Evasion")) {
					RequestParams.evasion_min := (s.stats[A_Index].min > 0) ? s.stats[A_Index].min : ""
					RequestParams.evasion_max := (s.stats[A_Index].max > 0) ? s.stats[A_Index].max : ""
				}
				Else If (InStr(s.stats[A_Index].Param, "Energy")) {
					RequestParams.shield_min  := (s.stats[A_Index].min > 0) ? s.stats[A_Index].min : ""
					RequestParams.shield_max  := (s.stats[A_Index].max > 0) ? s.stats[A_Index].max : ""
				}
				Else If (InStr(s.stats[A_Index].Param, "Block")) {
					RequestParams.block_min  := (s.stats[A_Index].min > 0)  ? s.stats[A_Index].min : ""
					RequestParams.block_max  := (s.stats[A_Index].max > 0)  ? s.stats[A_Index].max : ""
				}
				
				; offense
				Else If (InStr(s.stats[A_Index].Param, "Physical")) {
					RequestParams.pdps_min  := (s.stats[A_Index].min > 0)  ? s.stats[A_Index].min : ""
					RequestParams.pdps_max  := (s.stats[A_Index].max > 0)  ? s.stats[A_Index].max : ""
				}
				Else If (InStr(s.stats[A_Index].Param, "Elemental")) {
					RequestParams.edps_min  := (s.stats[A_Index].min > 0)  ? s.stats[A_Index].min : ""
					RequestParams.edps_max  := (s.stats[A_Index].max > 0)  ? s.stats[A_Index].max : ""
				}						
			}	
		}
		
		; handle item sockets
		If (s.UseSockets) {
			RequestParams.sockets_min := ItemData.Sockets
			Item.UsedInSearch.Sockets := ItemData.Sockets
		}	
		; handle item links

		If (s.UseLinks) {
			RequestParams.link_min := ItemData.Links
			Item.UsedInSearch.Links := ItemData.Links
		}					
		
		If (s.UsedInSearch) {
			Item.UsedInSearch.Enchantment := s.UsedInSearch.Enchantment
			Item.UsedInSearch.CorruptedMod:= s.UsedInSearch.Corruption
		}
		
		If (s.useIlvl) {			
			RequestParams.ilvl_min := s.minIlvl
			Item.UsedInSearch.iLvl.min := true
		}
		
		If (s.useBase) {
			RequestParams.xbase := Item.TypeName
			Item.UsedInSearch.ItemBase := Item.TypeName
		}
	}
	
	; prepend the item.subtype to match the options used on poe.trade
	If (RegExMatch(Item.SubType, "i)Mace|Axe|Sword")) {
		If (Item.IsThreeSocket) {
			Item.xtype := "One Hand " . Item.SubType
		}
		Else {
			Item.xtype := "Two Hand " . Item.SubType
		}
	}
	
	; Fix Body Armour subtype
	If (RegExMatch(Item.SubType, "i)BodyArmour")) {
		Item.xtype := "Body Armour"
	}
	
	; remove "Superior" from item name to exclude it from name search
	If (!IgnoreName) {
		RequestParams.name   := Trim(StrReplace(Name, "Superior", ""))		
		Item.UsedInSearch.FullName := true
	} Else If (!Item.isUnique and AdvancedPriceCheckItem.mods.length() <= 0) {
		isCraftingBase         := TradeFunc_CheckIfItemIsCraftingBase(Item.TypeName)
		hasHighestCraftingILvl := TradeFunc_CheckIfItemHasHighestCraftingLevel(Item.SubType, iLvl)
		; xtype = Item.SubType (Helmet)
		; xbase = Item.TypeName (Eternal Burgonet)

		;If desired crafting base and not isAdvancedPriceCheckRedirect		
		If (isCraftingBase and not Enchantment and not Corruption and not isAdvancedPriceCheckRedirect) {		
			RequestParams.xbase := Item.TypeName
			Item.UsedInSearch.ItemBase := Item.TypeName
			; If highest item level needed for crafting
			If (hasHighestCraftingILvl) {
				RequestParams.ilvl_min := hasHighestCraftingILvl
				Item.UsedInSearch.iLvl.min := hasHighestCraftingILvl
			}			
		} Else If (Enchantment and not isAdvancedPriceCheckRedirect) {
			modParam := new _ParamMod()
			modParam.mod_name := Enchantment.param
			modParam.mod_min  := Enchantment.min
			modParam.mod_max  := Enchantment.max
			RequestParams.modGroup.AddMod(modParam)	
			Item.UsedInSearch.Enchantment := true
		} Else If (Corruption and not isAdvancedPriceCheckRedirect) {			
			modParam := new _ParamMod()
			modParam.mod_name := Corruption.param
			modParam.mod_min  := (Corruption.min) ? Corruption.min : ""
			RequestParams.modGroup.AddMod(modParam)	
			Item.UsedInSearch.CorruptedMod := true
		} Else {
			RequestParams.xtype := (Item.xtype) ? Item.xtype : Item.SubType
			Item.UsedInSearch.Type := (Item.xtype) ? Item.GripType . " " . Item.SubType : Item.SubType
		}		
	} Else {
		RequestParams.xtype := (Item.xtype) ? Item.xtype : Item.SubType
		Item.UsedInSearch.Type := (Item.xtype) ? Item.GripType . " " . Item.SubType : Item.SubType
	}			
	
	; don't overwrite advancedItemPriceChecks decision to inlucde/exclude sockets/links
	If (not isAdvancedPriceCheckRedirect) {
		; handle item sockets
		; maybe don't use this for unique-items as default
		If (ItemData.Sockets >= 5 and not Item.IsUnique) {
			RequestParams.sockets_min := ItemData.Sockets
			Item.UsedInSearch.Sockets := ItemData.Sockets
		}	
		If (ItemData.Sockets >= 6) {
			RequestParams.sockets_min := ItemData.Sockets
			Item.UsedInSearch.Sockets := ItemData.Sockets
		}
		; handle item links
		If (ItemData.Links >= 5) {
			RequestParams.link_min := ItemData.Links
			Item.UsedInSearch.Links := ItemData.Links
		}
	}	
	
	; handle corruption
	If (Item.IsCorrupted and TradeOpts.CorruptedOverride and not Item.IsDivinationCard) {
		If (TradeOpts.Corrupted = "Either") {
			RequestParams.corrupted := "x"
			Item.UsedInSearch.Corruption := "Either"
		}
		Else If (TradeOpts.Corrupted = "Yes") {
			RequestParams.corrupted := "1"
			Item.UsedInSearch.Corruption := "Yes"
		}
		Else If (TradeOpts.Corrupted = "No") {
			RequestParams.corrupted := "0"
			Item.UsedInSearch.Corruption := "No"
		}	
	}
	Else If (Item.IsCorrupted and not Item.IsDivinationCard) {
		RequestParams.corrupted := "1"
		Item.UsedInSearch.Corruption := "Yes"
	}
	Else {
		RequestParams.corrupted := "0"
		Item.UsedInSearch.Corruption := "No"
	}
	
	If (Item.IsMap) {	
		; add Item.subtype to make sure to only find maps
		RequestParams.xbase := Item.SubType
		RequestParams.xtype := ""
		If (!Item.IsUnique) {
			RequestParams.name := ""	
		}		
		
		; Ivory Temple fix, not sure why it's not recognized and If there are more cases like it
		If (InStr(Name, "Ivory Temple")){
			RequestParams.xbase  := "Ivory Temple Map"
		}
	}
	
	; handle gems
	If (Item.IsGem) {
		RequestParams.xtype := Item.BaseType
		If (TradeOpts.GemQualityRange > 0) {
			RequestParams.q_min := Item.Quality - TradeOpts.GemQualityRange
			RequestParams.q_max := Item.Quality + TradeOpts.GemQualityRange
		}
		Else {
			RequestParams.q_min := Item.Quality
		}
		; match exact gem level If enhance, empower or enlighten
		If (InStr(Name, "Empower") or InStr(Name, "Enlighten") or InStr(Name, "Enhance")) {
			RequestParams.level_min := Item.Level
			RequestParams.level_max := Item.Level
		}
		Else If (TradeOpts.GemLevelRange > 0 and Item.Level >= TradeOpts.GemLevel) {
			RequestParams.level_min := Item.Level - TradeOpts.GemLevelRange
			RequestParams.level_max := Item.Level + TradeOpts.GemLevelRange
		}
		Else If (Item.Level >= TradeOpts.GemLevel) {
			RequestParams.level_min := Item.Level
		}
	}
	
	; handle divination cards and jewels
	If (Item.IsDivinationCard or Item.IsJewel) {
		RequestParams.xtype := Item.BaseType
		If (Item.IsJewel and Item.IsUnique) {
			RequestParams.xbase := Item.SubType
		}
	}
	
	; show item age
	If (isItemAgeRequest) {
		RequestParams.name        := Item.Name
		RequestParams.buyout      := ""
		RequestParams.seller      := TradeOpts.AccountName
		RequestParams.q_min       := Item.Quality
		RequestParams.q_max       := Item.Quality
		RequestParams.rarity      := Item.Rarity
		RequestParams.link_min    := ItemData.Links ? ItemData.Links : ""
		RequestParams.link_max    := ItemData.Links ? ItemData.Links : ""
		RequestParams.sockets_min := ItemData.Sockets ? ItemData.Sockets : ""
		RequestParams.sockets_max := ItemData.Sockets ? ItemData.Sockets : ""
		RequestParams.identified  := (!Item.IsUnidentified) ? "1" : "0"
		RequestParams.corrupted   := (Item.IsCorrupted) ? "1" : "0"
		RequestParams.enchanted   := (Enchantment) ? "1" : "0"		
		; change values a bit to accommodate for rounding differences
		RequestParams.armour_min  := Stats.Defense.TotalArmour.Value - 2
		RequestParams.armour_max  := Stats.Defense.TotalArmour.Value + 2
		RequestParams.evasion_min := Stats.Defense.TotalEvasion.Value - 2
		RequestParams.evasion_max := Stats.Defense.TotalEvasion.Value + 2
		RequestParams.shield_min  := Stats.Defense.TotalEnergyShield.Value - 2
		RequestParams.shield_max  := Stats.Defense.TotalEnergyShield.Value + 2
		
		If (Item.IsGem) {
			RequestParams.level_min := Item.Level
			RequestParams.level_max := Item.Level
		}
		Else If (Item.Level and not Item.IsDivinationCard and not Item.IsCurrency) {
			RequestParams.ilvl_min := Item.Level
			RequestParams.ilvl_max := Item.Level
		}		
	}
	
	If (openSearchInBrowser) {
		If (!TradeOpts.BuyoutOnly) {
			RequestParams.buyout := ""
		} 	
	}
	If (TradeOpts.Debug) {
		;console.log(RequestParams)
		;console.show()
	}
	Payload := RequestParams.ToPayload()
	
	ShowToolTip("Running search...")
	
	If (Item.IsCurrency and !Item.IsEssence) {
		If (!TradeOpts.AlternativeCurrencySearch) {
			Html := TradeFunc_DoCurrencyRequest(Item.Name, openSearchInBrowser)	
		}
		Else {
			; Update currency data if last update is older than 30min
			last := TradeGlobals.Get("LastAltCurrencyUpdate")
			now  := A_NowUTC
			diff := now - last
			If (diff > 1800) {
				GoSub, ReadPoeNinjaCurrencyData
			}
		}
	}
	Else {
		Html := TradeFunc_DoPostRequest(Payload, openSearchInBrowser)	
	}
	
	If (openSearchInBrowser) {
		; redirect was prevented to get the url and open the search on poe.trade instead
		If (Item.isCurrency and !Item.IsEssence) {
			IDs := TradeGlobals.Get("CurrencyIDs")
			Have:= TradeOpts.CurrencySearchHave
			ParsedUrl1 := "http://currency.poe.trade/search?league=" . LeagueName . "&online=x&want=" . IDs[Name] . "&have=" . IDs[Have]
		}
		Else {
			RegExMatch(Html, "i)href=""(https?:\/\/.*?)""", ParsedUrl)
		}		
		TradeFunc_OpenUrlInBrowser(ParsedUrl1)
	}
	Else If (Item.isCurrency and !Item.IsEssence) {
		; Default currency search
		If (!TradeOpts.AlternativeCurrencySearch) {
			ParsedData := TradeFunc_ParseCurrencyHtml(Html, Payload)
		}
		; Alternative currency search (poeninja)
		Else {
			ParsedData := TradeFunc_ParseAlternativeCurrencySearch(Item.Name, Payload)
		}
		
		;SetClipboardContents(ParsedData)
		ShowToolTip("")
		ShowToolTip(ParsedData)
	}
	Else {
		; Check item age
		If (isItemAgeRequest) {
			Item.UsedInSearch.SearchType := "Item Age Search"
		}
		Else If (isAdvancedPriceCheckRedirect) {
			Item.UsedInSearch.SearchType := "Advanced" 
		}
		Else {
			Item.UsedInSearch.SearchType := "Default" 
		}
		ParsedData := TradeFunc_ParseHtml(Html, Payload, iLvl, Enchantment, isItemAgeRequest)
		
		;SetClipboardContents(ParsedData)
		ShowToolTip("")
		ShowToolTip(ParsedData)
	}    
	
	; reset Item and ItemData after search
	Item := {}
	ItemData := {}
}

; parse items defense stats
TradeFunc_ParseItemDefenseStats(stats, mods){
	Global ItemData
	iStats := {}
	debugOutput := ""
	
	RegExMatch(stats, "i)chance to block ?:.*?(\d+)", Block)
	RegExMatch(stats, "i)armour ?:.*?(\d+)"         , Armour)
	RegExMatch(stats, "i)energy shield ?:.*?(\d+)"  , EnergyShield)
	RegExMatch(stats, "i)evasion rating ?:.*?(\d+)" , Evasion)
	RegExMatch(stats, "i)quality ?:.*?(\d+)"        , Quality)
	
	RegExMatch(ItemData.Affixes, "i)(\d+).*maximum.*?Energy Shield"  , affixFlatES)
	RegExMatch(ItemData.Affixes, "i)(\d+).*maximum.*?Armour"         , affixFlatAR) 
	RegExMatch(ItemData.Affixes, "i)(\d+).*maximum.*?Evasion"        , affixFlatEV)
	RegExMatch(ItemData.Affixes, "i)(\d+).*increased.*?Energy Shield", affixPercentES)
	RegExMatch(ItemData.Affixes, "i)(\d+).*increased.*?Evasion"      , affixPercentEV)
	RegExMatch(ItemData.Affixes, "i)(\d+).*increased.*?Armour"       , affixPercentAR)
	
	; calculate items base defense stats
	baseES := TradeFunc_CalculateBase(EnergyShield1, affixPercentES1, Quality1, affixFlatES1)
	baseAR := TradeFunc_CalculateBase(Armour1      , affixPercentAR1, Quality1, affixFlatAR1)
	baseEV := TradeFunc_CalculateBase(Evasion1     , affixPercentEV1, Quality1, affixFlatEV1)
	
	; calculate items Q20 total defense stats
	Armour       := TradeFunc_CalculateQ20(baseAR, affixFlatAR1, affixPercentAR1)
	EnergyShield := TradeFunc_CalculateQ20(baseES, affixFlatES1, affixPercentES1)
	Evasion      := TradeFunc_CalculateQ20(baseEV, affixFlatEV1, affixPercentEV1)
	
	; calculate items Q20 defense stat min/max values
	Affixes := StrSplit(ItemData.Affixes, "`n")
	
	For key, mod in mods.mods {
		For i, affix in Affixes {
			affix := RegExReplace(affix, "i)(\d+.?\d+?)", "#")
			affix := RegExReplace(affix, "i)# %", "#%")
			affix := Trim(RegExReplace(affix, "\s", " "))
			name :=  Trim(mod.name)		
			
			If ( affix = name ){
				; ignore mods like " ... per X dexterity"
				If (RegExMatch(affix, "i) per ")) {
					continue
				}
				If (RegExMatch(affix, "i)#.*to maximum.*?Energy Shield"  , affixFlatES)) {
					If (not mod.isVariable) {
						min_affixFlatES    := mod.values[1] 
						max_affixFlatES    := mod.values[1]
					}
					Else {
						min_affixFlatES    := mod.ranges[1][1] 
						max_affixFlatES    := mod.ranges[1][2] 
					}
					debugOutput .= affix "`nmax es : " min_affixFlatES " - " max_affixFlatES "`n`n"
				}
				If (RegExMatch(affix, "i)#.*to maximum.*?Armour"         , affixFlatAR)) {
					If (not mod.isVariable) {
						min_affixFlatAR    := mod.values[1]
						max_affixFlatAR    := mod.values[1]
					}
					Else {
						min_affixFlatAR    := mod.ranges[1][1]
						max_affixFlatAR    := mod.ranges[1][2]
					}
					debugOutput .= affix "`nmax ar : " min_affixFlatAR " - " max_affixFlatAR "`n`n"
				}
				If (RegExMatch(affix, "i)#.*to maximum.*?Evasion"        , affixFlatEV)) {
					If (not mod.isVariable) {
						min_affixFlatEV    := mod.values[1]
						max_affixFlatEV    := mod.values[1]
					}
					Else {
						min_affixFlatEV    := mod.ranges[1][1]
						max_affixFlatEV    := mod.ranges[1][2]
					}
					debugOutput .= affix "`nmax ev : " min_affixFlatEV " - " max_affixFlatEV "`n`n"
				}
				If (RegExMatch(affix, "i)#.*increased.*?Energy Shield"   , affixPercentES)) {
					If (not mod.isVariable) {
						min_affixPercentES := mod.values[1]
						max_affixPercentES := mod.values[1]
					}
					Else {
						min_affixPercentES := mod.ranges[1][1]
						max_affixPercentES := mod.ranges[1][2]
					}
					debugOutput .= affix "`ninc es : " min_affixPercentES " - " max_affixPercentES "`n`n"
				}
				If (RegExMatch(affix, "i)#.*increased.*?Evasion"         , affixPercentEV)) {
					If (not mod.isVariable) {
						min_affixPercentEV := mod.values[1]
						max_affixPercentEV := mod.values[1]
					}
					Else {
						min_affixPercentEV := mod.ranges[1][1]
						max_affixPercentEV := mod.ranges[1][2]
					}
					debugOutput .= affix "`ninc ev : " min_affixPercentEV " - " max_affixPercentEV "`n`n"
				}
				If (RegExMatch(affix, "i)#.*increased.*?Armour"          , affixPercentAR)) {
					If (not mod.isVariable) {
						min_affixPercentAR := mod.values[1]
						max_affixPercentAR := mod.values[1]
					}
					Else {
						min_affixPercentAR := mod.ranges[1][1]
						max_affixPercentAR := mod.ranges[1][2]
					}
					debugOutput .= affix "`ninc ar : " min_affixPercentAR " - " max_affixPercentAR "`n`n"
				}
			}
		}
	}
	
	min_Armour       := Round(TradeFunc_CalculateQ20(baseAR, min_affixFlatAR, min_affixPercentAR))
	max_Armour       := Round(TradeFunc_CalculateQ20(baseAR, max_affixFlatAR, max_affixPercentAR))
	min_EnergyShield := Round(TradeFunc_CalculateQ20(baseES, min_affixFlatES, min_affixPercentES))
	max_EnergyShield := Round(TradeFunc_CalculateQ20(baseES, max_affixFlatES, max_affixPercentES))
	min_Evasion      := Round(TradeFunc_CalculateQ20(baseEV, min_affixFlatEV, min_affixPercentEV))
	max_Evasion      := Round(TradeFunc_CalculateQ20(baseEV, max_affixFlatEV, max_affixPercentEV))
	
	iStats.TotalBlock			:= {}
	iStats.TotalBlock.Value 		:= Block1
	iStats.TotalBlock.Name  		:= "Block Chance"
	iStats.TotalArmour			:= {}
	iStats.TotalArmour.Value		:= Armour
	iStats.TotalArmour.Name		:= "Armour"
	iStats.TotalArmour.Base		:= baseAR
	iStats.TotalArmour.min  		:= min_Armour
	iStats.TotalArmour.max  		:= max_Armour
	iStats.TotalEnergyShield		:= {}
	iStats.TotalEnergyShield.Value:= EnergyShield
	iStats.TotalEnergyShield.Name	:= "Energy Shield"
	iStats.TotalEnergyShield.Base	:= baseES
	iStats.TotalEnergyShield.min 	:= min_EnergyShield
	iStats.TotalEnergyShield.max	:= max_EnergyShield
	iStats.TotalEvasion			:= {}
	iStats.TotalEvasion.Value	:= Evasion
	iStats.TotalEvasion.Name		:= "Evasion Rating"
	iStats.TotalEvasion.Base		:= baseEV
	iStats.TotalEvasion.min		:= min_Evasion
	iStats.TotalEvasion.max		:= max_Evasion
	iStats.Quality				:= Quality1	
	
	If (TradeOpts.Debug) {
		;console.log(output)
	}
	
	Return iStats
}

TradeFunc_CalculateBase(total, affixPercent, qualityPercent, affixFlat){
	SetFormat, FloatFast, 5.2
	If (total) {
		affixPercent  := (affixPercent) ? (affixPercent / 100) : 0
		affixFlat     := (affixFlat) ? affixFlat : 0
		qualityPercent:= (qualityPercent) ? (qualityPercent / 100) : 0
		base := Round((total / (1 + affixPercent + qualityPercent)) - affixFlat)
		Return base
	}
	return
}
TradeFunc_CalculateQ20(base, affixFlat, affixPercent){
	SetFormat, FloatFast, 5.2
	If (base) {
		affixPercent  := (affixPercent) ? (affixPercent / 100) : 0
		affixFlat     := (affixFlat) ? affixFlat : 0
		total := (base + affixFlat) * (1 + affixPercent + (20 / 100))
		Return total
	}
	return
}

; parse items dmg stats
TradeFunc_ParseItemOffenseStats(Stats, mods){
	Global ItemData
	iStats := {}
	debugOutput :=
	
	RegExMatch(ItemData.Stats, "i)Physical Damage ?:.*?(\d+)-(\d+)", match)
	physicalDamageLow := match1
	physicalDamageHi  := match2
	RegExMatch(ItemData.Stats, "i)Attacks per Second ?: ?(\d+.?\d+)", match)
	AttacksPerSecond := match1
	RegExMatch(ItemData.Affixes, "i)(\d+).*increased.*?Physical Damage", match)
	affixPercentPhys := match1
	RegExMatch(ItemData.Affixes, "i)Adds\D+(\d+)\D+(\d+).*Physical Damage", match)
	affixFlatPhysLow := match1
	affixFlatPhysHi  := match2
	
	Affixes := StrSplit(ItemData.Affixes, "`n")
	For key, mod in mods.mods {
		For i, affix in Affixes {
			If (RegExMatch(affix, "i)(\d+.?\d+?).*increased Attack Speed", match)) {
				affixAttackSpeed := match1
			}
			
			If (RegExMatch(affix, "Adds.*Lightning Damage")) {
				affix := RegExReplace(affix, "i)to (\d+)", "to #")
				affix := RegExReplace(affix, "i)to (\d+.*?\d+?)", "to #")
			} 
			Else {
				affix := RegExReplace(affix, "i)(\d+ to \d+)", "#")
				affix := RegExReplace(affix, "i)(\d+.*?\d+?)", "#")
			}						
			affix := RegExReplace(affix, "i)# %", "#%")
			affix := Trim(RegExReplace(affix, "\s", " "))
			name :=  Trim(mod.name)	
			
			If ( affix = name ){
				match :=
				; ignore mods like " ... per X dexterity" and "damage to spells"
				If (RegExMatch(affix, "i) per | to spells")) {
					continue
				}
				If (RegExMatch(affix, "i)Adds.*#.*(Physical|Fire|Cold|Chaos) Damage", dmgType)) {
					If (not mod.isVariable) {
						min_affixFlat%dmgType1%Low    := mod.values[1] 
						min_affixFlat%dmgType1%Hi     := mod.values[2] 
						max_affixFlat%dmgType1%Low    := mod.values[1] 
						max_affixFlat%dmgType1%Hi     := mod.values[2] 						
					}
					Else {
						min_affixFlat%dmgType1%Low    := mod.ranges[1][1] 
						min_affixFlat%dmgType1%Hi     := mod.ranges[1][2] 
						max_affixFlat%dmgType1%Low    := mod.ranges[2][1] 
						max_affixFlat%dmgType1%Hi     := mod.ranges[2][2] 						
					}		
					debugOutput .= affix "`nflat " dmgType1 " : " min_affixFlat%dmgType1%Low " - " min_affixFlat%dmgType1%Hi " to " max_affixFlat%dmgType1%Low " - " max_affixFlat%dmgType1%Hi "`n`n"					
				}
				If (RegExMatch(affix, "i)Adds.*(\d+) to #.*(Lightning) Damage", match)) {
					If (not mod.isVariable) {
						min_affixFlat%match2%Low    := match1 
						min_affixFlat%match2%Hi     := mod.values[1] 
						max_affixFlat%match2%Low    := match1
						max_affixFlat%match2%Hi     := mod.values[1] 
					}
					Else {
						min_affixFlat%match2%Low    := match1 
						min_affixFlat%match2%Hi     := mod.ranges[1][1] 
						max_affixFlat%match2%Low    := match1
						max_affixFlat%match2%Hi     := mod.ranges[1][2] 
					}					
					debugOutput .= affix "`nflat " match2 " : " min_affixFlat%match2%Low " - " min_affixFlat%match2%Hi " to " max_affixFlat%match2%Low " - " max_affixFlat%match2%Hi "`n`n"
				}
				If (RegExMatch(affix, "i)#.*increased Physical Damage")) {
					If (not mod.isVariable) {
						min_affixPercentPhys    := mod.values[1] 
						max_affixPercentPhys    := mod.values[1] 
					}
					Else {
						min_affixPercentPhys    := mod.ranges[1][1] 
						max_affixPercentPhys    := mod.ranges[1][2] 
					}
					debugOutput .= affix "`ninc Phys : " min_affixPercentPhys " - " max_affixPercentPhys "`n`n"
				}
				If (RegExMatch(affix, "i)#.*increased Attack Speed")) {
					If (not mod.isVariable) {
						min_affixPercentAPS     := mod.values[1] / 100
						max_affixPercentAPS     := mod.values[1] / 100
					}
					Else {
						min_affixPercentAPS     := mod.ranges[1][1] / 100
						max_affixPercentAPS     := mod.ranges[1][2] / 100
					}
					debugOutput .= affix "`ninc attack speed : " min_affixPercentAPS " - " max_affixPercentAPS "`n`n"
				}
			}
		}
	}
	
	SetFormat, FloatFast, 5.2	
	baseAPS      := (!affixAttackSpeed) ? AttacksPerSecond : AttacksPerSecond / (1 + (affixAttackSpeed / 100))
	basePhysLow  := TradeFunc_CalculateBase(physicalDamageLow, affixPercentPhys, Stats.Quality, affixFlatPhysLow)
	basePhysHi   := TradeFunc_CalculateBase(physicalDamageHi , affixPercentPhys, Stats.Quality, affixFlatPhysHi)
	
	minPhysLow   := Round(TradeFunc_CalculateQ20(basePhysLow, min_affixFlatPhysicalLow, min_affixPercentPhys))
	minPhysHi    := Round(TradeFunc_CalculateQ20(basePhysHi , min_affixFlatPhysicalHi , min_affixPercentPhys))
	maxPhysLow   := Round(TradeFunc_CalculateQ20(basePhysLow, max_affixFlatPhysicalLow, max_affixPercentPhys))
	maxPhysHi    := Round(TradeFunc_CalculateQ20(basePhysHi , max_affixFlatPhysicalHi , max_affixPercentPhys))
	min_affixPercentAPS := (min_affixPercentAPS) ? min_affixPercentAPS : 0
	max_affixPercentAPS := (max_affixPercentAPS) ? max_affixPercentAPS : 0
	minAPS       := baseAPS * (1 + min_affixPercentAPS)
	maxAPS       := baseAPS * (1 + max_affixPercentAPS)
	
	iStats.PhysDps        := {}
	iStats.PhysDps.Name   := "Physical Dps (Q20)"
	iStats.PhysDps.Value  := (Stats.Q20Dps > 0) ? (Stats.Q20Dps - Stats.EleDps - Stats.ChaosDps) : Stats.PhysDps 
	iStats.PhysDps.Min    := ((minPhysLow + minPhysHi) / 2) * minAPS
	iStats.PhysDps.Max    := ((maxPhysLow + maxPhysHi) / 2) * maxAPS
	iStats.EleDps         := {}
	iStats.EleDps.Name    := "Elemental Dps"
	iStats.EleDps.Value   := Stats.EleDps
	iStats.EleDps.Min     := ((min_affixFlatFireLow + min_affixFlatFireHi + min_affixFlatColdLow + min_affixFlatColdHi + min_affixFlatLightningLow + min_affixFlatLightningHi) / 2) * minAPS
	iStats.EleDps.Max     := ((max_affixFlatFireLow + max_affixFlatFireHi + max_affixFlatColdLow + max_affixFlatColdHi + max_affixFlatLightningLow + max_affixFlatLightningHi) / 2) * maxAPS
	
	debugOutput .= "Phys DPS: " iStats.PhysDps.Value "`n" "Phys Min: " iStats.PhysDps.Min "`n" "Phys Max: " iStats.PhysDps.Max "`n" "EleDps: " iStats.EleDps.Value "`n" "Ele Min: " iStats.EleDps.Min "`n" "Ele Max: "  iStats.EleDps.Max
	
	If (TradeOpts.Debug) {
		;console.log(debugOutput)
	}
	
	Return iStats
}

TradeFunc_GetUniqueStats(name){
	items := TradeGlobals.Get("VariableUniqueData")
	For i, uitem in items {
		If (name = uitem.name) {
			Return uitem.stats
		}
	}
}

; copied from PoE-ItemInfo because there it'll only be called If the option "ShowMaxSockets" is enabled
TradeFunc_SetItemSockets() {
	Global Item
	
	If (Item.IsWeapon or Item.IsArmour)
	{
		If (Item.Level >= 50)
		{
			Item.MaxSockets := 6
		}
		Else If (Item.Level >= 35)
		{
			Item.MaxSockets := 5
		}
		Else If (Item.Level >= 25)
		{
			Item.MaxSockets := 4
		}
		Else If (Item.Level >= 1)
		{
			Item.MaxSockets := 3
		}
		Else
		{
			Item.MaxSockets := 2
		}
		
		If(Item.IsFourSocket and Item.MaxSockets > 4)
		{
			Item.MaxSockets := 4
		}
		Else If(Item.IsThreeSocket and Item.MaxSockets > 3)
		{
			Item.MaxSockets := 3
		}
		Else If(Item.IsSingleSocket)
		{
			Item.MaxSockets := 1
		}
	}
}

TradeFunc_CheckIfItemIsCraftingBase(type){
	bases := TradeGlobals.Get("CraftingData")
	For i, base in bases {
		If (type = base) {
			Return true
		}
	}
	Return false
}

TradeFunc_CheckIfItemHasHighestCraftingLevel(subtype, iLvl){
	If (RegExMatch(subtype, "i)Helmet|Gloves|Boots|Body Armour|Shield|Quiver")) {
		Return (iLvl >= 84) ? 84 : false
	}
	Else If (RegExMatch(subtype, "i)Weapon")) {
		Return (iLvl >= 83) ? 83 : false
	}	
	Else If (RegExMatch(subtype, "i)Belt|Amulet|Ring")) {
		Return (iLvl >= 83) ? 83 : false
	}
	Return false
}

TradeFunc_DoParseClipboard()
{
	CBContents := GetClipboardContents()
	CBContents := PreProcessContents(CBContents)
	
	Globals.Set("ItemText", CBContents)
	Globals.Set("TierRelativeToItemLevelOverride", Opts.TierRelativeToItemLevel)
	
	ParsedData := ParseItemData(CBContents)
}

TradeFunc_DoPostRequest(payload, openSearchInBrowser = false)
{	
	ComObjError(0)
	Encoding := "utf-8"
    ;Reference in making POST requests - http://stackoverflow.com/questions/158633/how-can-i-send-an-http-post-request-to-a-server-from-excel-using-vba
	HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	If (openSearchInBrowser) {
		HttpObj.Option(6) := False
	}    
	HttpObj.Open("POST","http://poe.trade/search")
	HttpObj.SetRequestHeader("Host","poe.trade")
	HttpObj.SetRequestHeader("Connection","keep-alive")
	HttpObj.SetRequestHeader("Content-Length",StrLen(payload))
	HttpObj.SetRequestHeader("Cache-Control","max-age=0")
	HttpObj.SetRequestHeader("Origin","http://poe.trade")
	HttpObj.SetRequestHeader("Upgrade-Insecure-Requests","1")
	HttpObj.SetRequestHeader("User-Agent","Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.116 Safari/537.36")
	HttpObj.SetRequestHeader("Content-type","application/x-www-form-urlencoded")
	HttpObj.SetRequestHeader("Accept","text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8")
	HttpObj.SetRequestHeader("Referer","http://poe.trade/")
    ;HttpObj.SetRequestHeader("Accept-Encoding","gzip;q=0,deflate;q=0") ; disables compression
    ;HttpObj.SetRequestHeader("Accept-Encoding","gzip, deflate")
    ;HttpObj.SetRequestHeader("Accept-Language","en-US,en;q=0.8")	
	HttpObj.Send(payload)
	HttpObj.WaitForResponse()
	html := HttpObj.ResponseText
	
	If Encoding {
		oADO          := ComObjCreate("adodb.stream")
		oADO.Type     := 1
		oADO.Mode     := 3
		oADO.Open()
		oADO.Write( HttpObj.ResponseBody )
		oADO.Position := 0
		oADO.Type     := 2
		oADO.Charset  := Encoding
		html := oADO.ReadText() 
		oADO.Close()
	}
	
	If A_LastError
		MsgBox % A_LastError	
	
	Return, html
}

; Get currency.poe.trade html
; Either at script start to parse the currency IDs or when searching to get currency listings
TradeFunc_DoCurrencyRequest(currencyName = "", openSearchInBrowser = false, init = false){
	ComObjError(0)
	Encoding := "utf-8"
	HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	If (openSearchInBrowser) {
		HttpObj.Option(6) := False ;
	} 
	
	If (init) {
		Url := "http://currency.poe.trade/"
	}
	Else {
		LeagueName := TradeGlobals.Get("LeagueName")
		IDs := TradeGlobals.Get("CurrencyIDs")
		Have:= TradeOpts.CurrencySearchHave
		Url := "http://currency.poe.trade/search?league=" . LeagueName . "&online=x&want=" . IDs[currencyName] . "&have=" . IDs[Have]
	}
	
	HttpObj.Open("GET",Url)
	HttpObj.Send()
	HttpObj.WaitForResponse()
	html := HttpObj.ResponseText
	
	If Encoding {
		oADO          := ComObjCreate("adodb.stream")
		oADO.Type     := 1
		oADO.Mode     := 3
		oADO.Open()
		oADO.Write( HttpObj.ResponseBody )
		oADO.Position := 0
		oADO.Type     := 2
		oADO.Charset  := Encoding
		html := oADO.ReadText()
		oADO.Close()
	}
	
	If A_LastError
		MsgBox % A_LastError	
	
	If (init) {
		TradeFunc_ParseCurrencyIDs(html)
		Return
	}
	
	Return, html
}

; Open given Url with default Browser
TradeFunc_OpenUrlInBrowser(Url){
	Global TradeOpts
	
	openWith := 
	If (TradeFunc_CheckBrowserPath(TradeOpts.BrowserPath, false)) {
		openWith := TradeOpts.BrowserPath
		Run, %openWith% -new-tab "%Url%"
	}		
	Else If (TradeOpts.OpenWithDefaultWin10Fix) {
		openWith := AssociatedProgram("html") 
		Run, %openWith% -new-tab "%Url%"
	}
	Else {		
		Run %Url%
	}
}

; Parse currency.poe.trade to get all available currencies and their IDs
TradeFunc_ParseCurrencyIDs(html){
	RegExMatch(html, "is)id=""currency-want"">(.*?)input", match)	
	Currencies := {}
	
	Loop {
		Div          := TradeUtils.StrX( match1, "<div data-tooltip",  N, 0, "<img" , 1,4, N )
		CurrencyName := TradeUtils.StrX( Div,  "title=""",             1, 7, """"   , 1,1, T )
		CurrencyID   := TradeUtils.StrX( Div,  "data-id=""",           1, 9, """"   , 1,1    )			
		CurrencyName := StrReplace(CurrencyName, "&#39;", "'")
		
		If (!CurrencyName) {			
			TradeGlobals.Set("CurrencyIDs", Currencies)
			break
		}
		
		Currencies[CurrencyName] := CurrencyID  
		TradeGlobals.Set("CurrencyIDs", Currencies)
	}
}

; Parse currency.poe.trade to display tooltip with first X listings
TradeFunc_ParseCurrencyHtml(html, payload){
	Global Item, ItemData, TradeOpts
	LeagueName := TradeGlobals.Get("LeagueName")
	
	Title := Item.Name
	Title .= " (" LeagueName ")"
	Title .= "`n------------------------------ `n"	
	NoOfItemsToShow := TradeOpts.ShowItemResults
	
	Title .= StrPad("IGN" ,10) 	
	Title .= StrPad("| Ratio",20)	
	Title .= "| " . StrPad("Buy  ",20, "Left")	
	Title .= StrPad("Pay",18)	
	Title .= StrPad("| Stock",8)	
	Title .= "`n"
	
	Title .= StrPad("----------" ,10) 	
	Title .= StrPad("--------------------",20)	
	Title .= StrPad("--------------------",20)	
	Title .= StrPad("--------------------",18)		
	Title .= StrPad("--------",8)		
	Title .= "`n"
	
	While A_Index < NoOfItemsToShow {
		Offer       := TradeUtils.StrX( html,   "data-username=""",     N, 0, "Contact Seller"   , 1,1, N )
		SellCurrency:= TradeUtils.StrX( Offer,  "data-sellcurrency=""", 1,19, """"        , 1,1, T )
		SellValue   := TradeUtils.StrX( Offer,  "data-sellvalue=""",    1,16, """"        , 1,1, T )
		BuyValue    := TradeUtils.StrX( Offer,  "data-buyvalue=""",     1,15, """"        , 1,1, T )
		BuyCurrency := TradeUtils.StrX( Offer,  "data-buycurrency=""",  1,18, """"        , 1,1, T )
		AccountName := TradeUtils.StrX( Offer,  "data-ign=""",          1,10, """"        , 1,1    )
		
		RatioBuying := BuyValue / SellValue
		RatioSelling  := SellValue / BuyValue
		
		Pos   := RegExMatch(Offer, "si)displayoffer-bottom(.*)", StockMatch)
		Loop, Parse, StockMatch, `n, `r 
		{
			RegExMatch(TradeUtils.CleanUp(A_LoopField), "i)Stock:? ?(\d+) ", StockMatch)
			If (StockMatch) {
				Stock := StockMatch1
			}
		}

		Pos := RegExMatch(Offer, "si)displayoffer-primary(.*)<.*displayoffer-centered", Display)
		P := ""
		DisplayNames := []
		Loop {
			Column := TradeUtils.StrX( Display1, "column", P, 0, "</div", 1,1, P )
			RegExMatch(Column, ">(.*)<", Column)
			Column := RegExReplace(Column1, "\t|\r|\n", "")
			If (StrLen(Column) < 1) {
				Break
			}
			DisplayNames.Push(Column)
		}	
		
		subAcc := TradeFunc_TrimNames(AccountName, 10, true)
		Title .= StrPad(subAcc,10) 
		Title .= StrPad("| " . "1 <-- " . TradeUtils.ZeroTrim(RatioBuying)            ,20)
		Title .= StrPad("| " . StrPad(DisplayNames[1] . " " . StrPad(TradeUtils.ZeroTrim(SellValue), 4, "left"), 17, "left") ,20)
		Title .= StrPad("<= " . StrPad(TradeUtils.ZeroTrim(BuyValue), 4) . " " . DisplayNames[3] ,20)		
		Title .= StrPad("| " . Stock,8) 
		Title .= "`n"		
	}
	
	Return, Title
}

TradeFunc_ParseAlternativeCurrencySearch(name, payload) {
	Global Item, ItemData, TradeOpts
	LeagueName := TradeGlobals.Get("LeagueName")
	shortName := Trim(RegExReplace(name,  "Orb|of",  ""))	
	
	Title := StrPad(Item.Name " (" LeagueName ")", 30)
	Title .= StrPad("data provided by poe.ninja", 38, "left")
	Title .= "`n--------------------------------------------------------------------`n"
	
	Title .= StrPad("" ,10) 	
	Title .= StrPad("|| Buy (" shortName ")" ,28)
	Title .= StrPad("|| Sell (" shortName ")",28)
	Title .= "`n"
	Title .= StrPad("==========||==========================||============================",40)
	Title .= "`n"

	Title .= StrPad("Days ago" ,10) 	
	Title .= StrPad("|| Pay (Chaos)",20)
	Title .= StrPad("|  Get",8)
	
	Title .= StrPad("|| Pay",9)
	Title .= StrPad("|  Get (Chaos)",20)
	
	Title .= "`n"
	Title .= StrPad("----------||------------------|-------||-------|--------------------",40)
	Title .= "`n"
	
	currencyData := 
	For key, val in CurrencyHistoryData {
		If (val.currencyTypeName = name) {
			currencyData := val
			break
		}
	}
	
	buyPay := currencyData.receive.percentile10
	buyGet := buyPay < 1 ? 1 / buyPay : 1
	buyPay := buyPay > 1 ? Round(buyPay, 2) : 1
	
	sellPay := currencyData.pay.percentile10
	sellGet := sellPay < 1 ? 1 / sellPay : 1
	sellPay := sellPay > 1 ? Round(sellPay, 2) : 1
		
	Title .= StrPad("Currently",  10)
	Title .= StrPad("|| " buyPay, 20)
	Title .= StrPad("| "  buyGet, 8)
	
	Title .= StrPad("|| " sellPay, 9)
	Title .= "|"
	Title .= StrPad(sellGet, 19, "left")
	
	length := currencyData.payCurrencyGraphData.Length()
	i := 0
	Loop % currencyData.payCurrencyGraphData.Length() {
		date := currencyData.receiveCurrencyGraphData[length - i].daysAgo
		date := date ? date : "Last day" 
		
		buyPay := currencyData.receiveCurrencyGraphData[length - i].value
		buyGet := buyPay < 1 ? 1 / buyPay : 1
		buyPay := buyPay > 1 ? Round(buyPay, 2) : 1
		
		sellPay := currencyData.payCurrencyGraphData[length - i].value
		sellGet := sellPay < 1 ? 1 / sellPay : 1
		sellPay := sellPay > 1 ? Round(sellPay, 2) : 1
		
		Title .= "`n"
		Title .= StrPad(date, 10)
		Title .= StrPad("|| " buyPay, 20) 
		Title .= StrPad("| "  buyGet, 8)
		
		Title .= StrPad("|| " sellPay, 9)
		Title .= "|"
		Title .= StrPad(sellGet, 19, "left")
		
		If (A_Index > 10) {
			break
		}
		i++
	}
	Return Title
}

; Calculate average and median price of X listings
TradeFunc_GetMeanMedianPrice(html, payload){
	itemCount := 1
	prices := []
	average := 0
	Title := ""
	
	; loop over the first 99 results If possible, otherwise over as many as are available
	accounts := []
	NoOfItemsToCount := 99
	NoOfItemsSkipped := 0
	While A_Index <= NoOfItemsToCount {
		TBody         := TradeUtils.StrX( html,   "<tbody id=""item-container-" . %A_Index%,  N, 0, "</tbody>" , 1,23, N )
		AccountName   := TradeUtils.StrX( TBody,  "data-seller=""",                           1,13, """"       , 1,1,  T )
		ChaosValue    := TradeUtils.StrX( TBody,  "data-name=""price_in_chaos""",             T, 0, "currency" , 1,1,  T )
		Currency      := TradeUtils.StrX( TBody,  "currency-",                                T, 0, ">"        , 1,1, T  )
		CurrencyV     := TradeUtils.StrX( TBody, ">",                                         T, 0, "<"        , 1,1, T  )
		
		; skip multiple results from the same account		
		If (TradeOpts.RemoveMultipleListingsFromSameAccount) {
			If (TradeUtils.IsInArray(AccountName, accounts)) {
				NoOfItemsToShow := NoOfItemsToShow + 1
				NoOfItemsSkipped := NoOfItemsSkipped + 1
				continue
			} Else {
				accounts.Push(AccountName)
			}
		}		
		
		If (StrLen(ChaosValue) <= 0) {
			Continue
		}  Else { 
			itemCount++
		}
		
		; replace "
		StringReplace, Currency, Currency, ", , All
		StringReplace, Currency, Currency, currency-, , All
		CurrencyName := TradeUtils.Cleanup(Currency)
		
		StringReplace, CurrencyV, CurrencyV, >, , All
		StringReplace, CurrencyV, CurrencyV, �, , All
		CurrencyValue := TradeUtils.Cleanup(CurrencyV)
		
		; add chaos-equivalents (chaos prices) together and count results
		RegExMatch(ChaosValue, "i)data-value=""-?(\d+.?\d+?)""", priceChaos)
		If (StrLen(priceChaos1) > 0 or StrLen(CurrencyValue) > 0) {
			SetFormat, float, 6.2
			chaosEquivalent := 0
			
			; if priceChaos is too big there's a chance that poe.trades chaos equiv is wrong
			If (priceChaos1 > 2000) {
				For key, val in ChaosEquivalents {
					haystack := RegExReplace(key, "i)'", "")
					If (InStr(haystack, CurrencyName)) {
						chaosEquivalent := val * CurrencyValue
					}
				}	
			}
			Else {
				chaosEquivalent := priceChaos1
			}
			
			StringReplace, FloatNumber, chaosEquivalent, ., `,, 1
			average += chaosEquivalent
			prices[itemCount-1] := chaosEquivalent
		}
	}
	
	; calculate average and median prices
	If (prices.MaxIndex() > 0) {
		; average
		average := average / (itemCount - 1)
		
		; median
		If (prices.MaxIndex()&1) {
			; results count is odd
			index1 := Floor(prices.MaxIndex()/2)
			index2 := Ceil(prices.MaxIndex()/2)
			median := (prices[index1] + prices[index2]) / 2
			If (median > 2) {
				median := Round(median, 2)
			}
		}
		Else {
			; results count is even
			index := Floor(prices.MaxIndex()/2)
			median := prices[index]		
			If (median > 2) {
				median := Round(median, 2)
			}
		} 
		
		length := (StrLen(average) > StrLen(median)) ? StrLen(average) : StrLen(median)
		Title .= "Average price in chaos: " StrPad(average, length, "left") " (" prices.MaxIndex() " results"
		Title .= (NoOfItemsSkipped > 0) ? ", " NoOfItemsSkipped " removed by Account Filter" : ""		
		Title .= ") `n"
		
		Title .= "Median  price in chaos: " StrPad(median, length, "left") " (" prices.MaxIndex() " results"
		Title .= (NoOfItemsSkipped > 0) ? ", " NoOfItemsSkipped " removed by Account Filter" : ""		
		Title .= ") `n`n"
	}  
	Return Title
}

; Parse poe.trade html to display the search result tooltip with X listings
TradeFunc_ParseHtml(html, payload, iLvl = "", ench = "", isItemAgeRequest = false)
{	
	Global Item, ItemData, TradeOpts
	LeagueName := TradeGlobals.Get("LeagueName")
	
	; Target HTML Looks like the ff:
    ;<tbody id="item-container-97" class="item" data-seller="Jobo" data-sellerid="458008" data-buyout="15 chaos" data-ign="Lolipop_Slave" data-league="Essence" data-name="Tabula Rasa Simple Robe" data-tab="This is a buff" data-x="10" data-y="9"> <tr class="first-line">
	
	If (not Item.IsGem and not Item.IsDivinationCard and not Item.IsJewel and not Item.IsCurrency and not Item.IsMap) {
		showItemLevel := true
	}
	
	Name := (Item.IsRare and not Item.IsMap) ? Item.Name " " Item.TypeName : Item.Name
	Title := Trim(StrReplace(Name, "Superior", ""))
	
	If (Item.IsMap && !Item.isUnique) {
		; map fix (wrong Item.name on magic/rare maps)
		Title := 
		newName := Trim(StrReplace(Item.Name, "Superior", ""))
		; prevent duplicate name on white and magic maps
		If (newName != Item.SubType) {
			s := Trim(RegExReplace(Item.Name, "Superior", "")) 
			s := Trim(StrReplace(s, Item.SubType, "")) 
			Title .= "(" RegExReplace(s, " +", " ") ") "
		}
		Title .= Trim(StrReplace(Item.SubType, "Superior", ""))
	}
	
	; add corrupted tag
	If (Item.IsCorrupted) {
		Title .= " [Corrupted] "
	}
	
	; add gem quality and level
	If (Item.IsGem) {
		Title := Item.Name ", Q" Item.Quality "%"
		If (Item.Level >= 16) {
			Title := Item.Name ", " Item.Level "`/" Item.Quality "%"
		}
	}
	; add item sockets and links
	If (ItemData.Sockets >= 5) {
		Title := Name " " ItemData.Sockets "s" ItemData.Links "l"
	}
	If (showItemLevel) {
		Title .= ", iLvl: " iLvl
	}
	
	Title .= ", (" LeagueName ")"
	Title .= "`n------------------------------ `n"	
	
	; add notes what parameters where used in the search
	ShowFullNameNote := false 
	If (not Item.IsUnique and not Item.IsGem and not Item.IsDivinationCard) {
		ShowFullNameNote := true
	}
	
	If (Item.UsedInSearch) {
		If (isItemAgeRequest) {
			Title .= Item.UsedInSearch.SearchType
		}		
		Else {
			Title .= "Used in " . Item.UsedInSearch.SearchType . " Search: "
			Title .= (Item.UsedInSearch.Enchantment)  ? "Enchantment " : "" 	
			Title .= (Item.UsedInSearch.CorruptedMod) ? "Corr. Implicit " : "" 	
			Title .= (Item.UsedInSearch.Sockets)      ? "| " . Item.UsedInSearch.Sockets . "S " : ""
			Title .= (Item.UsedInSearch.Links)        ? "| " . Item.UsedInSearch.Links   . "L " : ""
			If (Item.UsedInSearch.iLvl.min and Item.UsedInSearch.iLvl.max) {
				Title .= "| iLvl (" . Item.UsedInSearch.iLvl.min . "-" . Item.UsedInSearch.iLvl.max . ")"
			}
			Else {
				Title .= (Item.UsedInSearch.iLvl.min) ? "| iLvl (>=" . Item.UsedInSearch.iLvl.min . ") " : ""
				Title .= (Item.UsedInSearch.iLvl.max) ? "| iLvl (<=" . Item.UsedInSearch.iLvl.max . ") " : ""
			}		
			Title .= (Item.UsedInSearch.FullName and ShowFullNameNote) ? "| Full Name " : ""
			Title .= (Item.UsedInSearch.Corruption and not Item.IsMapFragment and not Item.IsDivinationCard and not Item.IsCurrency)   ? "| Corrupted (" . Item.UsedInSearch.Corruption . ") " : ""
			Title .= (Item.UsedInSearch.Type)     ? "| Type (" . Item.UsedInSearch.Type . ") " : ""
			Title .= (Item.UsedInSearch.ItemBase and ShowFullNameNote) ? "| Base (" . Item.UsedInSearch.ItemBase . ") " : ""
			
			Title .= (Item.UsedInSearch.SearchType = "Default") ? "`n" . "!! Mod rolls are being ignored !!" : ""
		}
		Title .= "`n------------------------------ `n"	
	}
	
	; add average and median prices to title	
	If (not isItemAgeRequest) {
		Title .= TradeFunc_GetMeanMedianPrice(html, payload)
	} Else {
		Title .= "`n"
	}	
	
	NoOfItemsToShow := TradeOpts.ShowItemResults
	; add table headers to tooltip
	Title .= TradeFunc_ShowAcc(StrPad("Account",10), "|") 
	Title .= StrPad("IGN",20) 	
	Title .= StrPad(StrPad("| Price ", 19, "right") . "|",20,"left")	
	
	If (Item.IsGem) {
		; add gem headers
		Title .= StrPad("Q. |",6,"left")
		Title .= StrPad("Lvl |",6,"left")
	}
	If (showItemLevel) {
		; add ilvl
		Title .= StrPad("iLvl |",7,"left")
	}
	Title .= StrPad("   Age",8)	
	Title .= "`n"
	
	; add table head underline
	Title .= TradeFunc_ShowAcc(StrPad("----------",10), "-") 
	Title .= StrPad("--------------------",20) 
	Title .= StrPad("--------------------",19,"left")
	If (Item.IsGem) {
		Title .= StrPad("------",6,"left")
		Title .= StrPad("------",6,"left")
	}	
	If (showItemLevel) {
		Title .= StrPad("-------",8,"left")
	}
	Title .= StrPad("----------",8,"left")	
	Title .= "`n"
	
	; add search results to tooltip in table format
	accounts := []
	itemsListed := 0
	While A_Index < NoOfItemsToShow {
		TBody       := TradeUtils.StrX( html,   "<tbody id=""item-container-" . %A_Index%,  N,0,  "</tbody>", 1,23, N )
		AccountName := TradeUtils.StrX( TBody,  "data-seller=""",                           1,13, """"  ,     1,1,  T )
		Buyout      := TradeUtils.StrX( TBody,  "data-buyout=""",                           T,13, """"  ,     1,1,  T )
		IGN         := TradeUtils.StrX( TBody,  "data-ign=""",                              T,10, """"  ,     1,1     )
		
		if(not AccountName){
			continue
		}
		Else {
			itemsListed++
		}
		
		; skip multiple results from the same account
		If (TradeOpts.RemoveMultipleListingsFromSameAccount and not isItemAgeRequest) {
			If (TradeUtils.IsInArray(AccountName, accounts)) {
				NoOfItemsToShow := NoOfItemsToShow + 1
				continue
			} Else {
				accounts.Push(AccountName)
			}
		}		
		
		; get item age
		Pos := RegExMatch(TBody, "i)class=""found-time-ago"">(.*?)<", Age)
		
		If (showItemLevel) {
			; get item level
			Pos := RegExMatch(TBody, "i)data-name=""ilvl"">.*: ?(\d+?)<", iLvl, Pos)
		}		
		If (Item.IsGem) {
			; get gem quality and level
			Pos := RegExMatch(TBody, "i)data-name=""q"".*?data-value=""(.*?)""", Q, Pos)
			Pos := RegExMatch(TBody, "i)data-name=""level"".*?data-value=""(.*?)""", LVL, Pos)
		}		
		
		; trim account and ign
		subAcc := TradeFunc_TrimNames(AccountName, 10, true)
		subIGN := TradeFunc_TrimNames(IGN, 20, true) 
		
		Title .= TradeFunc_ShowAcc(StrPad(subAcc,10), "|") 
		Title .= StrPad(subIGN,20) 
		
		RegExMatch(Buyout, "i)([-.0-9]+) (.*)", BuyoutText)
		RegExMatch(BuyoutText1, "i)(\d+)(.\d+)?", BuyoutPrice)
		BuyoutPrice    := (BuyoutPrice2) ? StrPad(BuyoutPrice1 BuyoutPrice2, (3 - StrLen(BuyoutPrice1), "left")) : StrPad(StrPad(BuyoutPrice1, 2 + StrLen(BuyoutPrice1), "right"), 3 - StrLen(BuyoutPrice1), "left")
		BuyoutCurrency := BuyoutText2
		BuyoutText := StrPad(BuyoutPrice, 5, "left") . " " BuyoutCurrency
		Title .= StrPad("| " . BuyoutText . "",19,"right")
		
		If (Item.IsGem) {
			; add gem info
			If (Q1 > 0) {
				Title .= StrPad("| " . StrPad(Q1,2,"left") . "% ",6,"right")
			} Else {
				Title .= StrPad("|  -  ",6,"right")
			}
			Title .= StrPad("| " . StrPad(LVL1,3,"left") . " " ,6,"right")
		}
		If (showItemLevel) {
			; add item level
			Title .= StrPad("| " . StrPad(iLvl1,3,"left") . "  |" ,8,"right")
		}	
		Else {
			Title .= "|"
		}
		; add item age
		Title .= StrPad(TradeFunc_FormatItemAge(Age1),10)
		Title .= "`n"		
	}	
	Title .= (itemsListed > 0) ? "" : "`nNo item found.`n"
	
	Return, Title
}

; Trim names/string and add dots at the end If they are longer than specified length
TradeFunc_TrimNames(name, length, addDots) {
	s := SubStr(name, 1 , length)
	If (StrLen(name) > length + 3 && addDots) {
		StringTrimRight, s, s, 3
		s .= "..."
	}
	Return s
}

; Add sellers accountname to string If that option is selected
TradeFunc_ShowAcc(s, addString) {
	If (TradeOpts.ShowAccountName = 1) {
		s .= addString
		Return s	
	}	
}

; format item age to be shorter
TradeFunc_FormatItemAge(age) {
	age := RegExReplace(age, "^a", "1")
	RegExMatch(age, "\d+", value)
	RegExMatch(age, "i)month|week|yesterday|hour|minute|second|day", unit)
	
	If (unit = "month") {
		unit := " mo"
	} Else If (unit = "week") {
		unit := " week"
	} Else If (unit = "day") {
		unit := " day"
	} Else If (unit = "yesterday") {
		unit := " day"
		value := "1"
	} Else If (unit = "hour") {
		unit := " h"
	} Else If (unit = "minute") {
		unit := " min"
	} Else If (unit = "second") {
		unit := " sec"
	} 		
	
	s := " " StrPad(value, 3, left) unit
	
	Return s
}

class RequestParams_ {
	league		:= ""
	xtype		:= ""
	xbase		:= ""
	name			:= ""
	dmg_min 		:= ""
	dmg_max 		:= ""
	aps_min 		:= ""
	aps_max 		:= ""
	crit_min 		:= ""
	crit_max 		:= ""
	dps_min 		:= ""
	dps_max		:= ""
	edps_min		:= ""
	edps_max		:= ""
	pdps_min 		:= ""
	pdps_max 		:= ""
	armour_min	:= ""
	armour_max	:= ""
	evasion_min	:= ""
	evasion_max 	:= ""
	shield_min 	:= ""
	shield_max 	:= ""
	block_min		:= ""
	block_max 	:= ""
	sockets_min 	:= ""
	sockets_max 	:= ""
	link_min 		:= ""
	link_max 		:= ""
	sockets_r 	:= ""
	sockets_g 	:= ""
	sockets_b 	:= ""
	sockets_w 	:= ""
	linked_r 		:= ""
	linked_g 		:= ""
	linked_b 		:= ""
	linked_w 		:= ""
	rlevel_min 	:= ""
	rlevel_max 	:= ""
	rstr_min 		:= ""
	rstr_max 		:= ""
	rdex_min 		:= ""
	rdex_max 		:= ""
	rint_min 		:= ""
	rint_max 		:= ""
	; For future development, change this to array to provide multi mod groups
	modGroup 	:= new _ParamModGroup()
	q_min 		:= ""
	q_max 		:= ""
	level_min 	:= ""
	level_max 	:= ""
	ilvl_min 		:= ""
	ilvl_max		:= ""
	rarity 		:= ""
	seller 		:= ""
	xthread 		:= ""
	identified 	:= ""
	corrupted		:= "0"
	online 		:= (TradeOpts.OnlineOnly == 0) ? "" : "x"
	buyout 		:= ""
	altart 		:= ""
	capquality 	:= "x"
	buyout_min 	:= ""
	buyout_max 	:= ""
	buyout_currency:= ""
	crafted		:= ""
	enchanted 	:= ""
	
	ToPayload() 
	{
		modGroupStr := this.modGroup.ToPayload()
		
		p := "league=" this.league "&type=" this.xtype "&base=" this.xbase "&name=" this.name "&dmg_min=" this.dmg_min "&dmg_max=" this.dmg_max "&aps_min=" this.aps_min "&aps_max=" this.aps_max "&crit_min=" this.crit_min "&crit_max=" this.crit_max "&dps_min=" this.dps_min "&dps_max=" this.dps_max "&edps_min=" this.edps_min "&edps_max=" this.edps_max "&pdps_min=" this.pdps_min "&pdps_max=" this.pdps_max "&armour_min=" this.armour_min "&armour_max=" this.armour_max "&evasion_min=" this.evasion_min "&evasion_max=" this.evasion_max "&shield_min=" this.shield_min "&shield_max=" this.shield_max "&block_min=" this.block_min "&block_max=" this.block_max "&sockets_min=" this.sockets_min "&sockets_max=" this.sockets_max "&link_min=" this.link_min "&link_max=" this.link_max "&sockets_r=" this.sockets_r "&sockets_g=" this.sockets_g "&sockets_b=" this.sockets_b "&sockets_w=" this.sockets_w "&linked_r=" this.linked_r "&linked_g=" this.linked_g "&linked_b=" this.linked_b "&linked_w=" this.linked_w "&rlevel_min=" this.rlevel_min "&rlevel_max=" this.rlevel_max "&rstr_min=" this.rstr_min "&rstr_max=" this.rstr_max "&rdex_min=" this.rdex_min "&rdex_max=" this.rdex_max "&rint_min=" this.rint_min "&rint_max=" this.rint_max modGroupStr "&q_min=" this.q_min "&q_max=" this.q_max "&level_min=" this.level_min "&level_max=" this.level_max "&ilvl_min=" this.ilvl_min "&ilvl_max=" this.ilvl_max "&rarity=" this.rarity "&seller=" this.seller "&thread=" this.xthread "&identified=" this.identified "&corrupted=" this.corrupted "&online=" this.online "&has_buyout=" this.buyout "&altart=" this.altart "&capquality=" this.capquality "&buyout_min=" this.buyout_min "&buyout_max=" this.buyout_max "&buyout_currency=" this.buyout_currency "&crafted=" this.crafted "&enchanted=" this.enchanted
		Return p
	}
}

class _ParamModGroup {
	ModArray := []
	group_type := "And"
	group_min := ""
	group_max := ""
	group_count := 1
	
	ToPayload() 
	{
		p := ""
		
		If (this.ModArray.Length() = 0) {
			this.AddMod(new _ParamMod())
		}
		this.group_count := this.ModArray.Length()
		Loop % this.ModArray.Length()
			p .= this.ModArray[A_Index].ToPayload()
		p .= "&group_type=" this.group_type "&group_min=" this.group_min "&group_max=" this.group_max "&group_count=" this.group_count
		Return p
	}
	AddMod(paraModObj) {
		this.ModArray.Push(paraModObj)
	}
}

class _ParamMod {
	mod_name := ""
	mod_min := ""
	mod_max := ""
	ToPayload() 
	{
		; for some reason '+' is not encoded properly, this affects mods like '+#% to all Elemental Resistances'
		this.mod_name := StrReplace(this.mod_name, "+", "%2B")
		p := "&mod_name=" this.mod_name "&mod_min=" this.mod_min "&mod_max=" this.mod_max
		Return p
	}
}

; Return unique item with its variable mods and mod ranges If it has any
TradeFunc_FindUniqueItemIfItHasVariableRolls(name)
{
	data := TradeGlobals.Get("VariableUniqueData")
	For index, uitem in data {		
		If (uitem.name = name) {
			Loop % uitem.mods.Length() {
				If (uitem.mods[A_Index].isVariable) {
					uitem.IsUnique := true
					Return uitem
				}
			}			
		}
	}  
	Return 0
}

; Return items mods and ranges
TradeFunc_PrepareNonUniqueItemMods(Affixes, Implicit, Rarity, Enchantment = false, Corruption = false, isMap = false) {
	Affixes := StrSplit(Affixes, "`n")
	mods := []
	i := 0
	
	If (Implicit and not Enchantment and not Corruption) {
		temp := TradeFunc_NonUniqueModStringToObject(Implicit, true)
		For key, val in temp {
			mods.push(val)
			i++
		}		
	}	

	For key, val in Affixes {
		If (!val or RegExMatch(val, "i)---")) {
			continue
		}
		If (i >= 1 and (Enchantment or Corruption)) {
			continue
		}
		If (i <= 1 and Implicit and Rarity = 1) {
			continue
		}

		temp := TradeFunc_NonUniqueModStringToObject(val, false)
		;combine mods if they have the same name and add their values
		For tempkey, tempmod in temp {			
			found := false

			For key, mod in mods {	
				If (tempmod.name = mod.name) {
					Index := 1
					Loop % mod.values.MaxIndex() {
						mod.values[Index] := mod.values[Index] + tempmod.values[Index]
						Index++
					}
					
					tempStr  := RegExReplace(mod.name_orig, "i)([.0-9]+)", "#")
					
					Pos		:= 1
					tempArr	:= []
					While Pos := RegExMatch(tempmod.name_orig, "i)([.0-9]+)", value, Pos + (StrLen(value) ? StrLen(value) : 0)) {		
						tempArr.push(value)
					}
					
					Pos		:= 1
					Index	:= 1
					While Pos := RegExMatch(mod.name_orig, "i)([.0-9]+)", value, Pos + (StrLen(value) ? StrLen(value) : 0)) {		
						tempStr := StrReplace(tempStr, "#", value + tempArr[Index],, 1)
						Index++			
					}
					mod.name_orig := tempStr	
					found := true
				}				
			} 
			If (tempmod.name and !found) {
				mods.push(tempmod)
			}
		}
	}

	; adding the values (value array) fails in the above loop, so far I have no idea why,
	; as a workaround we take the values from the mod description (where it works and use them)
	For key, mod in mods {
		mod.values := []
		Pos		:= 1
		Index	:= 1
		While Pos := RegExMatch(mod.name_orig, "i)([.0-9]+)", value, Pos + (StrLen(value) ? StrLen(value) : 0)) {		
			mod.values.push(value)		
			Index++			
		}
	}
	
	mods := TradeFunc_CreatePseudoMods(mods)
	
	tempItem		:= {}
	tempItem.mods	:= []
	tempItem.mods	:= mods
	temp			:= TradeFunc_GetItemsPoeTradeMods(tempItem, isMap)
	tempItem.mods	:= temp.mods
	tempItem.IsUnique := false
	
	Return tempItem
}

TradeFunc_NonUniqueModStringToObject(string, isImplicit) {
	StringReplace, val, string, `r,, All
	StringReplace, val, val, `n,, All
	values 	:= []
	
	; Collect all numeric values in the mod-string
	Pos		:= 0
	While Pos := RegExMatch(val, "i)([.0-9]+)", value, Pos + (StrLen(value) ? StrLen(value) : 1)) {
		values.push(value)
	}

	; Collect all resists/attributes that are combined in one mod
	Matches	:= []
	Pos		:= 0
	While Pos := RegExMatch(val, "i) ?(Dexterity) ?| ?(Intelligence) ?| ?(Strength) ?", match, Pos + (StrLen(match) ? StrLen(match) : 1)) {
		Matches.push(Trim(match))
	}
	
	type := ""
	; Matching "x% fire and cold resistance" etc is easier this way.
	If (RegExMatch(val, "i)Resistance")) {
		type := "Resistance"
		If (RegExMatch(val, "i)fire")) {
			Matches.push("Fire")
		}
		If (RegExMatch(val, "i)cold")) {
			Matches.push("Cold")
		}
		If (RegExMatch(val, "i)lightning")) {
			Matches.push("Lightning")
		}
	}
	
	; Vanguard Belt implicit for example (flat AR + EV)
	If (RegExMatch(val, "i)([.0-9]+) to (Armour|Evasion Rating|Energy Shield) and (Armour|Evasion Rating|Energy Shield)")) {
		type := "Defense"
		If (RegExMatch(val, "i)Armour")) {
			Matches.push("Armour")
		}
		If (RegExMatch(val, "i)Evasion Rating")) {
			Matches.push("Evasion Rating")
		}
		If (RegExMatch(val, "i)Energy Shield")) {
			Matches.push("Energy Shield")
		}
	}	
	
	; Create single mod from every collected resist/attribute
	Loop % Matches.Length() {
		RegExMatch(val, "i)(Resistance)", match)
		Matches[A_Index] := match1 ? "+#% to " . Matches[A_Index] . " " . match1 : "+# to " . Matches[A_Index]	
	}
	
	; Handle "all attributes"/"all resist"
	If (RegExMatch(val, "i)all attributes|all elemental (Resistances)", match)) {
		resist := match1 ? true : false
		Matches[1] := resist ? "+#% to Fire Resistance"      : "+# to Strength"
		Matches[2] := resist ? "+#% to Lightning Resistance" : "+# to Intelligence"
		Matches[3] := resist ? "+#% to Cold Resistance"      : "+# to Dexterity"		
	}
	; Use original mod-string if no combination is found
	Matches[1] := Matches.Length() > 0 ? Matches[1] : val

	; 
	arr := []
	Loop % (Matches.Length() ? Matches.Length() : 1) {
		temp := {}
		temp.name_orig := Matches[A_Index]
		Loop {
			temp.name_orig := RegExReplace(temp.name_orig, "#", values[A_Index], Count, 1)
			If (!Count) {
				break
			}
		}

		temp.values 	:= values
		s			:= RegExReplace(Matches[A_Index], "i)([.0-9]+)", "#")
		temp.name 	:= RegExReplace(s, "i)# ?to ? #", "#", isRange)	
		temp.isVariable:= false
		temp.type		:= (isImplicit and Matches.Length() <= 1) ? "implicit" : "explicit"	
		arr.push(temp)		
	}	
	
	Return arr
}

TradeFunc_CreatePseudoMods(mods) {
	tempMods := []
	resist := 0
	eleResist := 0
	life := 0
	attributes := 0

	eleDmg_Percent := 0
	eleDmg_AttacksFlatLow := 0
	eleDmg_AttacksFlatHi := 0
	eleDmg_AttacksPercent := 0
	eleDmg_SpellsPercent := 0
	eleDmg_SpellsFlatLow := 0
	eleDmg_SpellsFlatHi := 0
	
	spellDmg_Percent := 0	
	weaponEleDmg_Percent := 0
	
	fireDmg_Percent := 0
	fireDmg_AttacksPercent := 0
	fireDmg_SpellsPercent := 0
	fireDmg_AttacksFlatLow := 0
	fireDmg_SpellsFlatLow := 0
	fireDmg_AttacksFlatHi := 0
	fireDmg_SpellsFlatHi := 0
	
	coldDmg_Percent := 0
	coldDmg_AttacksPercent := 0
	coldDmg_SpellsPercent := 0
	coldDmg_AttacksFlatLow := 0
	coldDmg_AttacksFlatHi := 0
	coldDmg_SpellsFlatLow := 0
	coldDmg_SpellsFlatHi := 0
	
	lightningDmg_Percent := 0
	lightningDmg_AttacksPercent := 0
	lightningDmg_SpellsPercent := 0
	lightningDmg_AttacksFlatLow := 0
	lightningDmg_AttacksFlatHi := 0
	lightningDmg_SpellsFlatLow := 0
	lightningDmg_SpellsFlatHi := 0
	
	hasChaosRes := false

	For key, val in mods {
		If (RegExMatch(val.name, "i)maximum life$")) {
			life := life + val.values[1]
		}
		If (RegExMatch(val.name, "i)to intelligence$|to dexterity$|to (strength)$", match)) {
			attributes := attributes + val.values[1]
			If (match1 = "strength") {
				life := life + (Floor(val.values[1] / 2))
			}
		}
		If (RegExMatch(val.name, "i)to cold resistance|to fire resistance|to lightning resistance")) {
			resist := resist + val.values[1]
			eleResist := eleResist + val.values[1]
		}
		If (RegExMatch(val.name, "i)to Chaos Resistance")) {
			hasChaos := true
			resist := resist + val.values[1]
		}
		
		If (RegExMatch(val.name, "i)increased (cold) damage$", element)) {
			%element1%Dmg_Percent := %element1%Dmg_Percent + val.values[1]
			eleDmg_Percent := eleDmg_Percent + val.values[1]
		}
		If (RegExMatch(val.name, "i)increased (fire) damage$", element)) {
			%element1%Dmg_Percent := %element1%Dmg_Percent + val.values[1]
			eleDmg_Percent := eleDmg_Percent + val.values[1]
		}
		If (RegExMatch(val.name, "i)increased (lightning) damage$", element)) {
			%element1%Dmg_Percent := %element1%Dmg_Percent + val.values[1]
			eleDmg_Percent := eleDmg_Percent + val.values[1]
		}
		If (RegExMatch(val.name, "i)increased elemental damage$", element)) {
			eleDmg_Percent := eleDmg_Percent + val.values[1]
		}
		If (RegExMatch(val.name, "i)(cold) damage to (attacks|spells)$", element)) {
			%element1%Dmg_%element2%FlatLow := %element1%Dmg_%element2%FlatLow + val.values[1]
			%element1%Dmg_%element2%FlatHi  := %element1%Dmg_%element2%FlatHi + val.values[2]
			eleDmg_%element2%FlatLow := eleDmg_%element2%FlatLow + val.values[1]			
			eleDmg_%element2%FlatHi  := eleDmg_%element2%FlatHi  + val.values[2]
		}
		If (RegExMatch(val.name, "i)(fire) damage to (attacks|spells)$", element)) {
			%element1%Dmg_%element2%FlatLow := %element1%Dmg_%element2%FlatLow + val.values[1]
			%element1%Dmg_%element2%FlatHi  := %element1%Dmg_%element2%FlatHi + val.values[2]
			eleDmg_%element2%FlatLow := eleDmg_%element2%FlatLow + val.values[1]			
			eleDmg_%element2%FlatHi  := eleDmg_%element2%FlatHi  + val.values[2]
		}
		If (RegExMatch(val.name, "i)(lightning) damage to (attacks|spells)$", element)) {			
			%element1%Dmg_%element2%FlatLow := %element1%Dmg_%element2%FlatLow + val.values[1]
			%element1%Dmg_%element2%FlatHi  := %element1%Dmg_%element2%FlatHi + val.values[2]
			eleDmg_%element2%FlatLow := eleDmg_%element2%FlatLow + val.values[1]			
			eleDmg_%element2%FlatHi  := eleDmg_%element2%FlatHi  + val.values[2]
		}
		If (RegExMatch(val.name, "i)elemental damage with weapons")) {
			weaponEleDmg_Percent := weaponEleDmg_Percent + val.values[1]
		}
		If (RegExMatch(val.name, "i)spell", element)) {
			spellDmg_Percent := spellDmg_Percent + val.values[1]
		}
	}
	
	If (eleDmg_Percent > 0) {
		If (weaponEleDmg_Percent) {
			eleDmg_AttacksPercent 	   := eleDmg_Percent ? eleDmg_AttacksPercent + weaponEleDmg_Percent : 0
			fireDmg_AttacksPercent 	   := fireDmg_Percent ? fireDmg_AttacksPercent + weaponEleDmg_Percent : 0
			coldDmg_AttacksPercent	   := coldDmg_Percent ? coldDmg_AttacksPercent + weaponEleDmg_Percent : 0
			lightningDmg_AttacksPercent := lightningDmg_Percent ? lightningDmg_AttacksPercent + weaponEleDmg_Percent : 0
		}
		If (spellDmg_Percent) {
			fireDmg_SpellsPercent 	   := fireDmg_Percent ? fireDmg_SpellsPercent + spellDmg_Percent : 0
			coldDmg_SpellsPercent	   := coldDmg_Percent ? coldDmg_SpellsPercent + spellDmg_Percent : 0
			lightningDmg_SpellsPercent  := lightningDmg_Percent ? lightningDmg_SpellsPercent + spellDmg_Percent : 0
		}
	}

	If (life > 0) {
		temp := {}
		temp.values := [life]
		temp.name_orig := "+" . life . " to maximum Life"
		temp.name 	:= "+# to maximum Life"
		tempMods.push(temp)
	}
	If (resist > 0) {
		temp := {}
		temp.values := [resist]
		temp.name_orig := "+" . resist . "% total Resistance"
		temp.name 	:= "+#% total Resistance"		
		tempMods.push(temp)
	}
	If (eleResist > 0) {
		temp := {}
		temp.values := [eleResist]
		temp.name_orig := "+" . eleResist . "% total Elemental Resistance"
		temp.name 	:= "+#% total Elemental Resistance"		
		tempMods.push(temp)
	}
	
	Loop, 3 {
		elements := ["Fire", "Cold", "Lightning"]
		element  := elements[A_Index]
		
		Loop,  3 {
			types := ["", "Attacks",  "Spells"]
			type  := types[A_Index]
			
			If (%element%Dmg_%type%Percent > 0) {
				modSuffix := 				
				If (type = "") {
					modSuffix := " Damage"
				}
				If (type = "Attacks") {
					modSuffix := " Damage with Weapons"
					%element%Dmg_Percent := %element%Dmg_Percent + weaponEleDmg_Percent
					eleDmg_Percent := eleDmg_Percent + weaponEleDmg_Percent
				}
				If (type = "Spells") {
					modSuffix := " Spell Damage"
					%element%Dmg_Percent := %element%Dmg_Percent + spellDmg_Percent
					eleDmg_Percent := eleDmg_Percent + spellDmg_Percent
				}				
				temp := {}
				temp.values := [%element%Dmg_Percent]
				temp.name_orig := %element%Dmg_Percent "% increased " element . modSuffix
				temp.name 	:= "#% increased " element . modSuffix	
				tempMods.push(temp)
				
				If(!TradeFunc_CheckIfTempModExists("Elemental" . modSuffix, tempMods) and type != "Spells") {		
					temp := {}
					temp.values := [eleDmg_Percent]
					temp.name_orig := eleDmg_Percent "% increased Elemental" . modSuffix
					temp.name 	:= "#% increased Elemental" . modSuffix
					tempMods.push(temp)	
				}
			}
		}
		Loop,  2 {
			types := ["Attacks",  "Spells"]
			type  := types[A_Index]

			If (%element%Dmg_%type%FlatLow > 0) {
				modSuffix := (type = "Attacks") ? " to Attacks" : " to Spells"
				temp := {}
				temp.values := [(%element%Dmg_%type%FlatLow + %element%Dmg_%type%FlatHi) /2]
				temp.name_orig := "Adds " %element%Dmg_%type%FlatLow " to " %element%Dmg_%type%FlatHi " " element " Damage" modSuffix
				temp.name 	:= "Adds # " element " Damage" modSuffix	
				tempMods.push(temp)
				
				If(!TradeFunc_CheckIfTempModExists("Elemental Damage" modSuffix, tempMods)) {		
					temp := {}
					temp.values := [(eleDmg_%type%FlatLow + eleDmg_%type%FlatHi) / 2]
					temp.name_orig := "Adds " eleDmg_%type%FlatLow " to " eleDmg_%type%FlatHi " Elemental Damage" modSuffix	
					temp.name 	:= "Adds # Elemental Damage" modSuffix			
					tempMods.push(temp)	
				}			
			}
		}			
	}

	For tkey, tval in tempMods {
		higher := true
		; Don't show pseudo mods if their value is not higher than the normal mods value
		For key, mod in mods {
			name := tval.name = mod.name
			eleDmg := RegExMatch(tval.name, "i)increased Elemental Damage$") and RegExMatch(mod.name, "i)increased (Fire|Cold|Lightning) Damage")
			totalRes := RegExMatch(tval.name, "i)total Resistance$") and RegExMatch(mod.name, "i)Chaos Resistance$")
			
			If (name or eleDmg or totalRes) {
				If (mod.values[2]) {
					mv := (mod.values[1] + mod.values[2]) / 2
					tv := (tval.values[1] + tval.values[2]) / 2
					If (tv <= mv) {
						higher := false
					}
				}
				Else {
					If (tval.values[1] <= mod.values[1]) {
						higher := false
					}
				}
			}
		}

		hasTotalRes := RegExMatch(tval.name, "i)total Resistance$")
		If (hasTotalRes and not hasChaos) {
			continue
		}
		Else If (higher) {
			tval.isVariable:= false
			tval.type := "pseudo"
			mods.push(tval)	
		}		
	} 

	return mods
}

TradeFunc_CheckIfTempModExists(needle, mods) {
	For key, val in mods {
		If (RegExMatch(val.name, "i)" needle "")) {
			Return true
		}
	}
	Return false
}

; Add poetrades mod names to the items mods to use as POST parameter
TradeFunc_GetItemsPoeTradeMods(_item, isMap = false) {
	mods := TradeGlobals.Get("ModsData")

	; use this to control search order (which group is more important)
	For k, imod in _item.mods {
		; check total and then implicits first If mod is implicit, otherwise check later
		If (_item.mods[k].type == "implicit" and not isMap) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["[total] mods"], _item.mods[k])			
			If (StrLen(_item.mods[k]["param"]) < 1 and not isMap) {
				_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["implicit"], _item.mods[k])
			}
		}
		If (StrLen(_item.mods[k]["param"]) < 1 and not isMap) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["[total] mods"], _item.mods[k])
		}		
		If (StrLen(_item.mods[k]["param"]) < 1 and not isMap) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["[pseudo] mods"], _item.mods[k])
		}
		If (StrLen(_item.mods[k]["param"]) < 1 and not isMap) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["explicit"], _item.mods[k])
		}
		If (StrLen(_item.mods[k]["param"]) < 1 and not isMap) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["implicit"], _item.mods[k])
		}
		If (StrLen(_item.mods[k]["param"]) < 1 and not isMap) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["unique explicit"], _item.mods[k])
		}
		If (StrLen(_item.mods[k]["param"]) < 1 and not isMap) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["crafted"], _item.mods[k])
		}
		If (StrLen(_item.mods[k]["param"]) < 1 and not isMap) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["enchantments"], _item.mods[k])
		}
		If (StrLen(_item.mods[k]["param"]) < 1) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["map mods"], _item.mods[k])
		}
		If (StrLen(_item.mods[k]["param"]) < 1 and not isMap) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["prophecies"], _item.mods[k])
		}
	}
	
	Return _item
}

; Add poe.trades mod names to the items mods to use as POST parameter
TradeFunc_GetItemsPoeTradeUniqueMods(_item) {	
	mods := TradeGlobals.Get("ModsData")
	
	For k, imod in _item.mods {	
		_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["unique explicit"], _item.mods[k])
		If (StrLen(_item.mods[k]["param"]) < 1) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["explicit"], _item.mods[k])
		}
		If (StrLen(_item.mods[k]["param"]) < 1) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["[total] mods"], _item.mods[k])
		}
		If (StrLen(_item.mods[k]["param"]) < 1) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["[pseudo] mods"], _item.mods[k])
		}
		If (StrLen(_item.mods[k]["param"]) < 1) {
			_item.mods[k]["param"] := TradeFunc_FindInModGroup(mods["map mods"], _item.mods[k])
		}
	}
	
	Return _item
}

; find mod in modgroup and Return its name
TradeFunc_FindInModGroup(modgroup, needle) {	
	matches := []
	editedNeedle := ""

	For j, mod in modgroup {
		s  := Trim(RegExReplace(mod, "i)\(pseudo\)|\(total\)|\(crafted\)|\(implicit\)|\(explicit\)|\(enchant\)|\(prophecy\)", ""))
		s  := RegExReplace(s, "# ?to ? #", "#")
		s  := TradeUtils.CleanUp(s)		
		ss := TradeUtils.CleanUp(ss)
		ss := Trim(needle.name)
		;matches "1 to" in for example "adds 1 to (20-40) lightning damage"
		ss := RegExReplace(ss, "\d+ ?to ?#", "#")		
		ss := RegExReplace(ss, "Monsters' skills Chain # additional times", "Monsters' skills Chain 2 additional times")
		editedNeedle := ss
		
		; push matches to array to find multiple matches (case sensitive variations)
		If (s = ss) {
			temp := {}
			temp.s := s
			temp.mod := mod
			matches.push(temp)
		}
	}
	
	If (matches.Length()) {
		If (matches.Length() = 1) {
			Return matches[1].mod
		}
		Else {
			Loop % matches.Length() 
			{
				; use == instead of = to search case sensitive, there is at least on case where this matters (Life regenerated per second)
				If (matches[A_Index].s == editedNeedle) {				
					Return matches[A_Index].mod
				}
			}
		}
	}
	
	Return ""
}

TradeFunc_GetCorruption(_item) {
	mods     := TradeGlobals.Get("ModsData")	
	corrMods := TradeGlobals.Get("CorruptedModsData")
	RegExMatch(_item.Implicit, "i)([-.0-9]+)", value)
	If (RegExMatch(imp, "i)Limited to:")) {
		;return false
	}
	imp      := RegExReplace(_item.Implicit, "i)([-.0-9]+)", "#")
	
	corrMod  := {}
	For i, corr in corrMods {	
		If (imp = corr) {
			For j, mod in mods["implicit"] {					
				match := Trim(RegExReplace(mod, "i)\(implicit\)", ""))					
				If (match = corr) {
					corrMod.param := mod
					corrMod.name  := _item.implicit
				}
			}
		}
	}	
	
	valueCount := 0
	Loop {
		If (!value%A_Index%) {
			break
		}	
		valueCount++
	}
	If (StrLen(corrMod.param)) {
		If (valueCount = 1) {
			corrMod.min := value1
		}
		Return corrMod
	}
	Else {
		Return false
	}
}

TradeFunc_GetEnchantment(_item, type) {
	mods     := TradeGlobals.Get("ModsData")	
	enchants := TradeGlobals.Get("EnchantmentData")	
	
	group := 
	If (type = "Boots") {
		group := enchants.boots
	} 
	Else If (type = "Gloves") {
		group := enchants.gloves
	} 
	Else If (type = "Helmet") {
		group := enchants.helmet
	} 

	RegExMatch(_item.implicit, "i)([.0-9]+)(%? to ([.0-9]+))?", values)
	imp      := RegExReplace(_item.implicit, "i)([.0-9]+)", "#")

	enchantment := {}	
	If (group.length()) {	
		For i, enchant in group {
			If (TradeUtils.CleanUp(imp) = enchant) {
				For j, mod in mods["enchantments"] {
					match := Trim(RegExReplace(mod, "i)\(enchant\)", ""))					
					If (match = enchant) {
						enchantment.param := mod
						enchantment.name  := _item.implicit
					}
				}
			}
		}
	}	

	valueCount := 0
	Loop {
		If (!values%A_Index%) {
			break
		}	
		valueCount++
	}
	
	If (StrLen(enchantment.param)) {
		If (valueCount = 1) {
			enchantment.min := values1
			enchantment.max := values1
		}
		Else If (valueCount = 3) {
			enchantment.min := values1
			enchantment.max := values3
		}
		Return enchantment
	}
	Else {
		Return 0
	}
}

TradeFunc_GetModValueGivenPoeTradeMod(itemModifiers, poeTradeMod) {	
	If (StrLen(poeTradeMod) < 1) {
		ErrorMsg := "Mod not found on poe.trade!"
		Return ErrorMsg
	}
	Loop, Parse, itemModifiers, `n, `r
	{
		If StrLen(A_LoopField) = 0
		{
			Continue ; Not interested in blank lines
		}
		CurrValue := ""
		CurrValues := []
		CurrValue := GetActualValue(A_LoopField)
		
		If (CurrValue ~= "\d+") {
			; handle value range
			RegExMatch(CurrValue, "(\d+) ?(-|to) ?(\d+)", values)	
			If (values3) {
				CurrValues.Push(values1)
				CurrValues.Push(values3)
				CurrValue := values1 " to " values3
				ModStr := StrReplace(A_LoopField, CurrValue, "# to #")		
			}
			; handle single value
			Else {
				CurrValues.Push(CurrValue)
				ModStr := StrReplace(A_LoopField, CurrValue, "#")		
			}			
			
			ModStr := StrReplace(ModStr, "+")
			; replace multi spaces with a single one
			ModStr := RegExReplace(ModStr, " +", " ")			
			;MsgBox % "Loop: " A_LoopField "`nCurr: " CurrValue "`nModStr: " ModStr "`ntradeMod: " poeTradeMod
			
			IfInString, poeTradeMod, % ModStr
			{
				Return CurrValues
			}
		}
	}
}

TradeFunc_GetNonUniqueModValueGivenPoeTradeMod(itemModifiers, poeTradeMod) {
	If (StrLen(poeTradeMod) < 1) {
		ErrorMsg := "Mod not found on poe.trade!"
		Return ErrorMsg
	}
	CurrValue := ""
	CurrValues := []
	CurrValue := GetActualValue(itemModifiers.name_orig)
	If (CurrValue ~= "\d+") {
		
		; handle value range
		RegExMatch(CurrValue, "(\d+) ?(-|to) ?(\d+)", values)	
		
		If (values3) {
			CurrValues.Push(values1)
			CurrValues.Push(values3)
			CurrValue := values1 " to " values3
			ModStr := StrReplace(itemModifiers.name_orig, CurrValue, "#")	
		}
		; handle single value
		Else {
			CurrValues.Push(CurrValue)
			ModStr := StrReplace(itemModifiers.name_orig, CurrValue, "#")		
		}
		
		ModStr := StrReplace(ModStr, "+")
		; replace multi spaces with a single one
		ModStr := RegExReplace(ModStr, " +", " ")
		poeTradeMod := RegExReplace(poeTradeMod, "# ?to ? #", "#")

		IfInString, poeTradeMod, % ModStr
		{			
			Return CurrValues
		}
	}
}

; Open Gui window to show the items variable mods, select the ones that should be used in the search and se their min/max values
TradeFunc_AdvancedPriceCheckGui(advItem, Stats, Sockets, Links, UniqueStats = "", ChangedImplicit = ""){	
	;https://autohotkey.com/board/topic/9715-positioning-of-controls-a-cheat-sheet/
	Global 
	
	;prevent advanced gui in certain cases 
	If (not advItem.mods.Length() and not ChangedImplicit) {
		ShowTooltip("Advanced search not available for this item.")
		return
	}

	TradeFunc_ResetGUI()
	ValueRange := advItem.IsUnique ? TradeOpts.AdvancedSearchModValueRange : TradeOpts.AdvancedSearchModValueRange / 2
	
	Gui, SelectModsGui:Destroy    
	Gui, SelectModsGui:Add, Text, x10 y12, Percentage to pre-calculate min/max values: 
	Gui, SelectModsGui:Add, Text, x+5 yp+0 cGreen, % ValueRange "`%" (lowered for non-unique items)
	Gui, SelectModsGui:Add, Text, x10 y+8, This calculation considers the (unique) item's mods difference between their min and max value as 100`%.			
	
	ValueRange := ValueRange / 100 	
	
	; calculate length of first column
	modLengthMax := 0
	modGroupBox := 0
	Loop % advItem.mods.Length() {
		If (!advItem.mods[A_Index].isVariable and advItem.IsUnique) {
			continue
		}
		tempValue := StrLen(advItem.mods[A_Index].name)
		if(modLengthMax < tempValue ) {
			modLengthMax := tempValue
			modGroupBox := modLengthMax * 6
		}
	}
	If (!advItem.mods.Length() and ChangedImplicit) {
		modGroupBox := StrLen(ChangedImplicit.name) * 6
	}		
	modGroupBox := modGroupBox + 10
	modCount := advItem.mods.Length()
	
	; calculate row count and mod box height
	statCount := 0
	For i, stat in Stats.Defense {
		statCount := (stat.value) ? statCount + 1 : statCount
	}
	For i, stat in Stats.Offense {
		statCount := (stat.value) ? statCount + 1 : statCount
	}
	statCount := (ChangedImplicit) ? statCount + 1 : statCount
	
	boxRows := modCount * 3 + statCount * 3
	
	Gui, SelectModsGui:Add, Text, x14 y+10 w%modGroupBox%, Mods
	Gui, SelectModsGui:Add, Text, x+10 yp+0 w90, min
	Gui, SelectModsGui:Add, Text, x+10 yp+0 w45, current
	Gui, SelectModsGui:Add, Text, x+10 yp+0 w90, max
	Gui, SelectModsGui:Add, Text, x+10 yp+0 w30, Select
	
	line :=
	Loop, 500 {
		line := line . "-"
	}
	Gui, SelectModsGui:Add, Text, x0 w700 yp+13, %line% 	
	
	;add defense stats
	j := 1
	
	For i, stat in Stats.Defense {
		If (stat.value) {			
			xPosMin := modGroupBox + 25
			yPosFirst := ( j = 1 ) ? 20 : 25		
			
			If (!stat.min or !stat.max or (stat.min = stat.max) and advItem.IsUnique) {
				continue
			}
			
			If (stat.Name != "Block Chance") {
				stat.value   := Round(stat.value) 
				statValueQ20 := Round(stat.value)
			}
			
			; calculate values to prefill min/max fields		
			; assume the difference between the theoretical max and min value as 100%
			If (advItem.IsUnique) {
				statValueMin := Round(statValueQ20 - ((stat.max - stat.min) * valueRange))
				statValueMax := Round(statValueQ20 + ((stat.max - stat.min) * valueRange))
			}
			Else {
				statValueMin := Round(statValueQ20 - (statValueQ20 * valueRange))
				statValueMax := Round(statValueQ20 + (statValueQ20 * valueRange))	
			}			
			
			; prevent calculated values being smaller than the lowest possible min value or being higher than the highest max values
			If (advItem.IsUnique) {
				statValueMin := Floor((statValueMin < stat.min) ? stat.min : statValueMin)
				statValueMax := Floor((statValueMax > stat.max) ? stat.max : statValueMax)
			}
			
			If (not TradeOpts.PrefillMinValue) {
				statValueMin := 
			}
			If (not TradeOpts.PrefillMaxValue) {
				statValueMax := 
			}
			
			minLabelFirst  := advItem.isUnique ? "(" Floor(statValueMin) : ""
			minLabelSecond := advItem.isUnique ? ")" : ""
			maxLabelFirst  := advItem.isUnique ? "(" Floor(statValueMax) : ""
			maxLabelSecond := advItem.isUnique ? ")" : ""
			
			Gui, SelectModsGui:Add, Text, x15 yp+%yPosFirst%							, % "(Total Q20) " stat.name
			Gui, SelectModsGui:Add, Edit, x%xPosMin% yp-3 w40 vTradeAdvancedStatMin%j% r1	, % statValueMin
			Gui, SelectModsGui:Add, Text, x+5  yp+3       w45 cGreen					, % minLabelFirst minLabelSecond
			Gui, SelectModsGui:Add, Text, x+10 yp+0       w45 r1						, % Floor(statValueQ20)
			Gui, SelectModsGui:Add, Edit, x+10 yp-3       w40 vTradeAdvancedStatMax%j% r1	, % statValueMax
			Gui, SelectModsGui:Add, Text, x+5  yp+3       w45 cGreen					, % maxLabelFirst maxLabelSecond
			Gui, SelectModsGui:Add, CheckBox, x+10 yp+1       vTradeAdvancedStatSelected%j%
			
			TradeAdvancedStatParam%j% := stat.name			
			j++
		}
	}	
	
	If (j > 1) {
		Gui, SelectModsGui:Add, Text, x0 w700 yp+18 cc9cacd, %line% 
	}	
	
	k := 1
	;add dmg stats
	For i, stat in Stats.Offense {
		If (stat.value) {			
			xPosMin := modGroupBox + 25
			yPosFirst := ( j = 1 ) ? 20 : 25			
			
			If (!stat.min or !stat.max or (stat.min == stat.max) and advItem.IsUnique) {
				continue
			}
			
			; calculate values to prefill min/max fields		
			; assume the difference between the theoretical max and min value as 100%
			If (advItem.IsUnique) {
				statValueMin := Round(stat.value - ((stat.max - stat.min) * valueRange))
				statValueMax := Round(stat.value + ((stat.max - stat.min) * valueRange))			
			}
			Else {
				statValueMin := Round(stat.value - (stat.value * valueRange))
				statValueMax := Round(stat.value + (stat.value * valueRange))			
			}
			
			; prevent calculated values being smaller than the lowest possible min value or being higher than the highest max values
			If (advItem.IsUnique) {
				statValueMin := Floor((statValueMin < stat.min) ? stat.min : statValueMin)
				statValueMax := Floor((statValueMax > stat.max) ? stat.max : statValueMax)
			}
			
			If (not TradeOpts.PrefillMinValue) {
				statValueMin := 
			}
			If (not TradeOpts.PrefillMaxValue) {
				statValueMax := 
			}
			
			minLabelFirst  := advItem.isUnique ? "(" Floor(stat.min) : ""
			minLabelSecond := advItem.isUnique ? ")" : ""
			maxLabelFirst  := advItem.isUnique ? "(" Floor(stat.max) : ""
			maxLabelSecond := advItem.isUnique ? ")" : ""
			
			Gui, SelectModsGui:Add, Text, x15 yp+%yPosFirst%						  , % stat.name
			Gui, SelectModsGui:Add, Edit, x%xPosMin% yp-3 w40 vTradeAdvancedStatMin%j% r1, % statValueMin
			Gui, SelectModsGui:Add, Text, x+5  yp+3       w45 cGreen				  , % minLabelFirst minLabelSecond
			Gui, SelectModsGui:Add, Text, x+10 yp+0       w45 r1					  , % Floor(stat.value)
			Gui, SelectModsGui:Add, Edit, x+10 yp-3       w40 vTradeAdvancedStatMax%j% r1, % statValueMax
			Gui, SelectModsGui:Add, Text, x+5  yp+3       w45 cGreen				  , % maxLabelFirst maxLabelSecond
			Gui, SelectModsGui:Add, CheckBox, x+10 yp+1       vTradeAdvancedStatSelected%j%
			
			TradeAdvancedStatParam%j% := stat.name			
			j++
			TradeAdvancedStatsCount := j
			k++
		}
	}
	
	If (k > 1) {
		Gui, SelectModsGui:Add, Text, x0 w700 yp+18 cc9cacd, %line% 
	}	
	
	e := 0
	; Enchantment or Corrupted Implicit
	If (ChangedImplicit) {
		e := 1
		xPosMin := modGroupBox + 25	
		yPosFirst := ( j > 1 ) ? 20 : 30
		
		modValueMin := ChangedImplicit.min
		modValueMax := ChangedImplicit.max
		displayName := ChangedImplicit.name
		
		xPosMin := xPosMin + 40 + 5 + 45 + 10 + 45 + 10 +40 + 5 + 45 + 10 ; edit/text field widths and offsets
		Gui, SelectModsGui:Add, Text, x15 yp+%yPosFirst%  , % displayName
		Gui, SelectModsGui:Add, CheckBox, x%xPosMin% yp+1 vTradeAdvancedSelected%e%
		
		TradeAdvancedModMin%e% 		:= ChangedImplicit.min
		TradeAdvancedModMax%e% 		:= ChangedImplicit.max
		TradeAdvancedParam%e%  		:= ChangedImplicit.param
		TradeAdvancedIsImplicit%e%  := true
	}
	
	If (ChangedImplicit) {
		Gui, SelectModsGui:Add, Text, x0 w700 yp+18 cc9cacd, %line% 
	}	
	
	;add mods	
	l := 1
	p := 1
	ModNotFound := false
	Loop % advItem.mods.Length() {
		If (!advItem.mods[A_Index].isVariable and advItem.IsUnique) {
			continue
		}
		xPosMin := modGroupBox + 25			
		
		; matches "1 to #" in for example "adds 1 to # lightning damage"
		If (RegExMatch(advItem.mods[A_Index].name, "i)Adds (\d+(.\d+)?) to #.*Damage", match)) {
			displayName := RegExReplace(advItem.mods[A_Index].name, "\d+(.\d+)? to #", "#")
			staticValue := match1
		}
		Else {
			displayName := advItem.mods[A_Index].name			
			staticValue := 	
		}
		
		If (advItem.mods[A_Index].ranges.Length() > 1) {
			theoreticalMinValue := advItem.mods[A_Index].ranges[1][1]
			theoreticalMaxValue := advItem.mods[A_Index].ranges[2][2]
		}
		Else {
			; use staticValue to create 2 ranges; for example (1 to 50) to (1 to 70) instead of having only 1 to (50 to 70)  
			If (staticValue) {
				theoreticalMinValue := staticValue
				theoreticalMaxValue := advItem.mods[A_Index].ranges[1][2]
			}
			Else {
				theoreticalMinValue := advItem.mods[A_Index].ranges[1][1] ? advItem.mods[A_Index].ranges[1][1] : 0
				theoreticalMaxValue := advItem.mods[A_Index].ranges[1][2] ? advItem.mods[A_Index].ranges[1][2] : 0
			}
		}

		SetFormat, FloatFast, 5.2
		ErrorMsg := 
		If (advItem.IsUnique) {
			modValues := TradeFunc_GetModValueGivenPoeTradeMod(ItemData.Affixes, advItem.mods[A_Index].param)	
		}
		Else {
			modValues := TradeFunc_GetNonUniqueModValueGivenPoeTradeMod(advItem.mods[A_Index], advItem.mods[A_Index].param)	
		}
		If (modValues.Length() > 1) {
			modValue := (modValues[1] + modValues[2]) / 2			
		}
		Else {
			If (StrLen(modValues) > 10) {
				; error msg
				ErrorMsg := modValues
				ModNotFound := true
			}
			modValue := modValues[1]			
		}	
		
		; calculate values to prefill min/max fields		
		; assume the difference between the theoretical max and min value as 100%
		If (advItem.mods[A_Index].ranges[1]) {
			modValueMin := modValue - ((theoreticalMaxValue - theoreticalMinValue) * valueRange)
			modValueMax := modValue + ((theoreticalMaxValue - theoreticalMinValue) * valueRange)	
		}
		Else {
			modValueMin := modValue - (modValue * valueRange)
			modValueMax := modValue + (modValue * valueRange)
		}		
		; floor values only If greater than 2, in case of leech/regen mods
		modValueMin := (modValueMin > 2) ? Floor(modValueMin) : modValueMin
		modValueMax := (modValueMax > 2) ? Floor(modValueMax) : modValueMax
		
		; prevent calculated values being smaller than the lowest possible min value or being higher than the highest max values
		If (advItem.mods[A_Index].ranges[1]) {
			modValueMin := TradeUtils.ZeroTrim((modValueMin < theoreticalMinValue and not staticValue) ? theoreticalMinValue : modValueMin)
			modValueMax := TradeUtils.ZeroTrim((modValueMax > theoreticalMaxValue) ? theoreticalMaxValue : modValueMax)
		}
		
		; create Labels to show unique items min/max rolls		
		If (advItem.mods[A_Index].ranges[2][1]) {
			minLabelFirst := "(" TradeUtils.ZeroTrim((advItem.mods[A_Index].ranges[1][1] + advItem.mods[A_Index].ranges[1][2]) / 2) ")"
			maxLabelFirst := "(" TradeUtils.ZeroTrim((advItem.mods[A_Index].ranges[2][1] + advItem.mods[A_Index].ranges[2][2]) / 2) ")"
		}
		Else If (staticValue) {
			minLabelFirst := "(" TradeUtils.ZeroTrim((staticValue + advItem.mods[A_Index].ranges[1][1]) / 2) ")"
			maxLabelFirst := "(" TradeUtils.ZeroTrim((staticValue + advItem.mods[A_Index].ranges[1][2]) / 2) ")"
		}
		Else {
			minLabelFirst := "(" TradeUtils.ZeroTrim(advItem.mods[A_Index].ranges[1][1]) ")"
			maxLabelFirst := "(" TradeUtils.ZeroTrim(advItem.mods[A_Index].ranges[1][2]) ")"
		}
		
		If (not TradeOpts.PrefillMinValue or ErrorMsg) {
			modValueMin := 
		}
		If (not TradeOpts.PrefillMaxValue or ErrorMsg) {
			modValueMax := 
		}
		
		yPosFirst := ( l > 1 ) ? 25 : 20
		; increment index If the item has an enchantment
		index := A_Index + e
		
		isPseudo := advItem.mods[A_Index].type = "pseudo" ? true : false		
		If (isPseudo) {
			If (p = 1) {
				;add line if first pseudo mod
				Gui, SelectModsGui:Add, Text, x0 w700 y+5 cc9cacd, %line%
				yPosFirst := 20
			}						
			p++
			;change color if pseudo mod
			color := "cGray"
		}	
		
		state := modValue ? 0 : 1	
		
		Gui, SelectModsGui:Add, Text, x15 yp+%yPosFirst%  %color%									, % isPseudo ? "(pseudo) " . displayName : displayName
		Gui, SelectModsGui:Add, Edit, x%xPosMin% yp-3 w40 vTradeAdvancedModMin%index% r1 Disabled%state% 	, % modValueMin
		Gui, SelectModsGui:Add, Text, x+5  yp+3       w45 cGreen                  		 				, % (advItem.mods[A_Index].ranges[1]) ? minLabelFirst : ""
		Gui, SelectModsGui:Add, Text, x+10 yp+0       w45 r1     		                         		, % TradeUtils.ZeroTrim(modValue)
		Gui, SelectModsGui:Add, Edit, x+10 yp-3       w40 vTradeAdvancedModMax%index% r1 Disabled%state% 	, % modValueMax
		Gui, SelectModsGui:Add, Text, x+5  yp+3       w45 cGreen 			                       		, % (advItem.mods[A_Index].ranges[1]) ? maxLabelFirst : ""
		checkEnabled := ErrorMsg ? 0 : 1
		If (checkEnabled) {
			Gui, SelectModsGui:Add, CheckBox, x+10 yp+1       vTradeAdvancedSelected%index%	
		}
		Else {
			GUI, SelectModsGui:Add, Picture, x+10 yp+1 hwndErrorPic 0x0100, %A_ScriptDir%\trade_data\error.png
		}	
		
		color := "cBlack"
		
		TradeAdvancedParam%index% := advItem.mods[A_Index].param
		l++
		TradeAdvancedModsCount := l
	}
	
	m := 1	
	;If (Sockets >= 5 or Links >= 5) {
	If (true) {
		If (advItem.mods.Length()) {
			Gui, SelectModsGui:Add, Text, x0 w700 y+5 cc9cacd, %line% 	
		}		
				
		If (Sockets >= 5) {
			m++
			text := "Sockets: " . Trim(Sockets)
			Gui, SelectModsGui:Add, CheckBox, x15 y+10 vTradeAdvancedUseSockets     , % text
		}
		If (Links >= 5) {
			offset := (m > 1 ) ? "+15" : "15"
			m++
			text := "Links:  " . Trim(Links)
			Gui, SelectModsGui:Add, CheckBox, x%offset% yp+0 vTradeAdvancedUseLinks Checked, % text
		}
		
		offsetX := (m = 1)  ? "15" : "+15"
		offsetY := (m = 1) ? "20" : "+0"
		Gui, SelectModsGui:Add, CheckBox, x%offsetX% yp%offsetY% vTradeAdvancedSelectedILvl , % "Item Level (min)"
		Gui, SelectModsGui:Add, Edit    , x+5 yp-3 w30 vTradeAdvancedMinILvl , % ""
		Gui, SelectModsGui:Add, CheckBox, x+15 yp+3 vTradeAdvancedSelectedItemBase , % "Include Item Base"		
	}
	
	Item.UsedInSearch.SearchType := "Advanced"
	; closes this window and starts the search
	offset := (m > 1) ? "+20" : "+10"
	Gui, SelectModsGui:Add, Button, x10 y%offset% gAdvancedPriceCheckSearch, &Search
	
	; open search on poe.trade instead
	Gui, SelectModsGui:Add, Button, x+10 yp+0 gAdvancedOpenSearchOnPoeTrade, Op&en on poe.trade
	Gui, SelectModsGui:Add, Text, x+20 yp+5 cGray, (Pro-Tip: Use Alt + S/E to submit a button)
	
	If (ModNotFound) {
		Gui, SelectModsGui:Add, Picture, x10 y+12, %A_ScriptDir%\trade_data\error.png
		Gui, SelectModsGui:Add, Text, x+10 yp+2 cRed,One or more mods couldn't be found on poe.trade
	}
	Gui, SelectModsGui:Add, Text, x10 y+10 cGreen, Please support poe.trade by visiting without adblocker
	Gui, SelectModsGui:Add, Link, x+5 yp+0 cBlue, <a href="https://poe.trade">visit</a>    		

	windowWidth := modGroupBox + 40 + 5 + 45 + 10 + 45 + 10 +40 + 5 + 45 + 10 + 65
	windowWidth := (windowWidth > 420) ? windowWidth : 420
	Gui, SelectModsGui:Show, w%windowWidth% , Select Mods to include in Search
}

AdvancedPriceCheckSearch:	
	TradeFunc_HandleGuiSubmit()
	TradeFunc_Main(false, false, true)
return

AdvancedOpenSearchOnPoeTrade:	
	TradeFunc_HandleGuiSubmit()
	TradeFunc_Main(true, false, true)
return

TradeFunc_ResetGUI(){
	Global 
	Loop {
		If (TradeAdvancedModMin%A_Index%) {
			TradeAdvancedParam%A_Index%	:=
			TradeAdvancedSelected%A_Index%:=
			TradeAdvancedModMin%A_Index%	:=
			TradeAdvancedModMax%A_Index%	:=
		}
		Else If (A_Index >= 20){
			TradeAdvancedStatCount :=
			break
		}
	}
	
	Loop {
		If (TradeAdvancedStatMin%A_Index%) {
			TradeAdvancedStatParam%A_Index%	:=
			TradeAdvancedStatSelected%A_Index%	:=
			TradeAdvancedStatMin%A_Index%		:=
			TradeAdvancedStatMax%A_Index%		:=
		}
		Else If (A_Index >= 20){
			TradeAdvancedModCount := 
			break
		}
	}

	TradeAdvancedUseSockets		:=
	TradeAdvancedUseLinks		:=
	TradeAdvancedSelectedILvl	:=
	TradeAdvancedMinILvl		:=
	TradeAdvancedSelectedItemBase	:=
}

TradeFunc_HandleGuiSubmit(){
	Global 

	Gui, SelectModsGui:Submit
	newItem := {mods:[], stats:[], UsedInSearch : {}}
	mods  := []	
	stats := []	
	
	Loop {
		mod := {param:"",selected:"",min:"",max:""}
		If (TradeAdvancedSelected%A_Index%) {
			mod.param    := TradeAdvancedParam%A_Index%
			mod.selected := TradeAdvancedSelected%A_Index%
			mod.min      := TradeAdvancedModMin%A_Index%
			mod.max      := TradeAdvancedModMax%A_Index%
			; has Enchantment
			If (RegExMatch(TradeAdvancedParam%A_Index%, "i)enchant") and mod.selected) {
				newItem.UsedInSearch.Enchantment := true
			}
			; has Corrupted Implicit
			Else If (TradeAdvancedIsImplicit%A_Index% and mod.selected) {
				newItem.UsedInSearch.CorruptedMod := true
			}
			
			mods.Push(mod)
		}
		Else If (A_Index >= 20) {
			break
		}
	}
	
	Loop {
		stat := {param:"",selected:"",min:"",max:""}
		If (TradeAdvancedStatMin%A_Index%) {
			stat.param    := TradeAdvancedStatParam%A_Index%
			stat.selected := TradeAdvancedStatSelected%A_Index%
			stat.min      := TradeAdvancedStatMin%A_Index%
			stat.max      := TradeAdvancedStatMax%A_Index%
			
			stats.Push(stat)
		}
		Else If (A_Index >= 20) {
			break
		}
	}
	
	newItem.mods       	:= mods
	newItem.stats      	:= stats
	newItem.useSockets	:= TradeAdvancedUseSockets
	newItem.useLinks	:= TradeAdvancedUseLinks
	newItem.useIlvl	:= TradeAdvancedSelectedILvl
	newItem.minIlvl	:= TradeAdvancedMinILvl
	newItem.useBase	:= TradeAdvancedSelectedItemBase

	TradeGlobals.Set("AdvancedPriceCheckItem", newItem)	
	Gui, SelectModsGui:Destroy
}

class TradeUtils {
	; also see https://github.com/ahkscript/awesome-AutoHotkey
	; and https://autohotkey.com/boards/viewtopic.php?f=6&t=53
	IsArray(obj) {
		Return !!obj.MaxIndex()
	}
	
	; Trim trailing zeros from numbers
	ZeroTrim(number) { 
		RegExMatch(number, "(\d+)\.?(.+)?", match)
		If (StrLen(match2) < 1) {
			Return number
		} Else {
			trail := RegExReplace(match2, "0+$", "")
			number := (StrLen(trail) > 0) ? match1 "." trail : match1
			Return number
		}
	}
	
	IsInArray(el, array) {
		For i, element in array {
			If (el = "") {
				Return false
			}
			If (element = el) {
				Return true
			}
		}
		Return false
	}
	
	CleanUp(in) {
		StringReplace, in, in, `n,, All
		StringReplace, in, in, `r,, All
		Return Trim(in)
	}
	
	; ------------------------------------------------------------------------------------------------------------------ ;
	; TradeUtils.StrX Function for parsing html, see simple example usage at https://gist.github.com/thirdy/9cac93ec7fd947971721c7bdde079f94
	; ------------------------------------------------------------------------------------------------------------------ ;
	
	; Cleanup TradeUtils.StrX Function and Google Example from https://autohotkey.com/board/topic/47368-TradeUtils.StrX-auto-parser-for-xml-html
	; By SKAN
	
	;1 ) H = HayStack. The "Source Text"
	;2 ) BS = BeginStr. Pass a String that will result at the left extreme of Resultant String
	;3 ) BO = BeginOffset. 
	; Number of Characters to omit from the left extreme of "Source Text" while searching for BeginStr
	; Pass a 0 to search in reverse ( from right-to-left ) in "Source Text"
	; If you intend to call TradeUtils.StrX() from a Loop, pass the same variable used as 8th Parameter, which will simplify the parsing process.
	;4 ) BT = BeginTrim. 
	; Number of characters to trim on the left extreme of Resultant String
	; Pass the String length of BeginStr If you want to omit it from Resultant String
	; Pass a Negative value If you want to expand the left extreme of Resultant String
	;5 ) ES = EndStr. Pass a String that will result at the right extreme of Resultant String
	;6 ) EO = EndOffset. 
	; Can be only True or False. 
	; If False, EndStr will be searched from the end of Source Text. 
	; If True, search will be conducted from the search result offset of BeginStr or from offset 1 whichever is applicable.
	;7 ) ET = EndTrim. 
	; Number of characters to trim on the right extreme of Resultant String
	; Pass the String length of EndStr If you want to omit it from Resultant String
	; Pass a Negative value If you want to expand the right extreme of Resultant String
	;8 ) NextOffset : A name of ByRef Variable that will be updated by TradeUtils.StrX() with the current offset, You may pass the same variable as Parameter 3, to simplify data parsing in a loop
	
	StrX(H,  BS="",BO=0,BT=1,   ES="",EO=0,ET=1,  ByRef N="" ) 
	{ 
		Return SubStr(H,P:=(((Z:=StrLen(ES))+(X:=StrLen(H))+StrLen(BS)-Z-X)?((T:=InStr(H,BS,0,((BO
            <0)?(1):(BO))))?(T+BT):(X+1)):(1)),(N:=P+((Z)?((T:=InStr(H,ES,0,((EO)?(P+1):(0))))?(T-P+Z
		+(0-ET)):(X+P)):(X)))-P)
	}
	; v1.0-196c 21-Nov-2009 www.autohotkey.com/forum/topic51354.html
	; | by Skan | 19-Nov-2009
	
	UriEncode(Uri, Enc = "UTF-8")
	{
		TradeUtils.StrPutVar(Uri, Var, Enc)
		f := A_FormatInteger
		SetFormat, IntegerFast, H
		Loop
		{
			Code := NumGet(Var, A_Index - 1, "UChar")
			If (!Code)
				Break
			If (Code >= 0x30 && Code <= 0x39 ; 0-9
				|| Code >= 0x41 && Code <= 0x5A ; A-Z
				|| Code >= 0x61 && Code <= 0x7A) ; a-z
				Res .= Chr(Code)
			Else
				Res .= "%" . SubStr(Code + 0x100, -1)
		}
		SetFormat, IntegerFast, %f%
		Return, Res
	}

	UriDecode(Uri, Enc = "UTF-8")
	{
		Pos := 1
		Loop
		{
			Pos := RegExMatch(Uri, "i)(?:%[\da-f]{2})+", Code, Pos++)
			If (Pos = 0)
				Break
			VarSetCapacity(Var, StrLen(Code) // 3, 0)
			StringTrimLeft, Code, Code, 1
			Loop, Parse, Code, `%
				NumPut("0x" . A_LoopField, Var, A_Index - 1, "UChar")
			StringReplace, Uri, Uri, `%%Code%, % StrGet(&Var, Enc), All
		}
		Return, Uri
	}

	StrPutVar(Str, ByRef Var, Enc = "")
	{
		Len := StrPut(Str, Enc) * (Enc = "UTF-16" || Enc = "CP1200" ? 2 : 1)
		VarSetCapacity(Var, Len, 0)
		Return, StrPut(Str, &Var, Enc)
	}
}

OverwriteSettingsWidthTimer:
	o := Globals.Get("SettingsUIWidth")

	If (o) {
		Globals.Set("SettingsUIWidth", 1085)
		SetTimer, OverwriteSettingsWidthTimer, Off
	}	
Return

OverwriteSettingsNameTimer:
	o := Globals.Get("SettingsUITitle")

	If (o) {
		RelVer := TradeGlobals.Get("ReleaseVersion")
		Menu, Tray, Tip, Path of Exile TradeMacro %RelVer%
		OldMenuTrayName := Globals.Get("SettingsUITitle")
		NewMenuTrayName := TradeGlobals.Get("SettingsUITitle")
		Menu, Tray, UseErrorLevel
		Menu, Tray, Rename, % OldMenuTrayName, % NewMenuTrayName
		If (ErrorLevel = 0) {		
			Menu, Tray, Icon, %A_ScriptDir%\trade_data\poe-trade-bl.ico		
			SetTimer, OverwriteSettingsNameTimer, Off
		}
		Menu, Tray, UseErrorLevel, off		
	}	
Return

TradeSettingsUI_BtnOK:
	Global TradeOpts
	Gui, Submit
	SavedTradeSettings := true
	Sleep, 50
	WriteTradeConfig()
	UpdateTradeSettingsUI()
Return

TradeSettingsUI_BtnCancel:
	Gui, Cancel
Return

TradeSettingsUI_BtnDefaults:
	Gui, Cancel
	RemoveTradeConfig()
	Sleep, 75
	CopyDefaultTradeConfig()
	Sleep, 75
	ReadTradeConfig()
	Sleep, 75
	UpdateTradeSettingsUI()
	ShowSettingsUI()
Return

TradeSettingsUI_ChkCorruptedOverride:
	GuiControlGet, IsChecked,, CorruptedOverride
	If (Not IsChecked) {
		GuiControl, Disable, Corrupted
	}
	Else	{
		GuiControl, Enable, Corrupted
	}
Return

ReadPoeNinjaCurrencyData:
	league := TradeUtils.UriEncode(TradeGlobals.Get("LeagueName"))
	url := "http://poe.ninja/api/Data/GetCurrencyOverview?league=" . league	
	UrlDownloadToFile, %url% , %A_ScriptDir%\temp\currencyData.json
	FileRead, JSONFile, %A_ScriptDir%/temp/currencyData.json
	parsedJSON 	:= JSON.Load(JSONFile)	
	global CurrencyHistoryData := parsedJSON.lines
	
	TradeGlobals.Set("LastAltCurrencyUpdate", A_NowUTC)
	
	global ChaosEquivalents := {}
	For key, val in CurrencyHistoryData {
		ChaosEquivalents[val.currencyTypeName] := val.chaosEquivalent		
	}
	ChaosEquivalents["Chaos Orb"] := 1
Return