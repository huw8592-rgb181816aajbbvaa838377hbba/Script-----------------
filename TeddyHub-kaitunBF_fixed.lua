if getgenv().Loaded then
	return
end

if getgenv().Debugging then
	print("Debug Is On")
end

settings().Physics.AreOwnersShown = false

do
	local tbl = { ItemConfig = nil, ItemReplication = nil, InventoryController = nil }

	local function fn()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")

		if not tbl.ItemConfig then
			pcall(function()
				local itemConfig = ReplicatedStorage:FindFirstChild("ItemConfig")

				if itemConfig and itemConfig:IsA("ModuleScript") then
					tbl.ItemConfig = require(itemConfig)
				end
			end)
		end

		if not tbl.ItemReplication then
			pcall(function()
				local util = ReplicatedStorage:FindFirstChild("Util")
				local itemReplication = util and util:FindFirstChild("ItemReplication") or ReplicatedStorage:FindFirstChild("ItemReplication")

				if itemReplication and itemReplication:IsA("ModuleScript") then
					tbl.ItemReplication = require(itemReplication)
				end
			end)
		end

		if not tbl.InventoryController then
			pcall(function()
				local controllers = ReplicatedStorage:FindFirstChild("Controllers")
				local ui = controllers and controllers:FindFirstChild("UI")
				controllers = ui and ui:FindFirstChild("Inventory") or ReplicatedStorage:FindFirstChild("InventoryController") or controllers and controllers:FindFirstChild("Inventory")

				if controllers and controllers:IsA("ModuleScript") then
					tbl.InventoryController = rawget(_G, "IC") or require(controllers)
				end
			end)
		end

		return tbl
	end

	local function fn2(arg, arg2)
		local itemReplication = fn().ItemReplication

		if itemReplication then
			for _, v in ipairs({ "Quantity", "Count", "Amount", "Stack" }) do
				if itemReplication[v] and typeof(itemReplication[v].readClient) == "function" then
					local ok, result = pcall(function()
						return itemReplication[v].readClient(arg, arg2)
					end)

					if ok and typeof(result) == "number" and result > 0 then
						return result
					end
				end
			end
		end

		return 1
	end

	local function fn3(arg, arg2)
		local itemReplication = fn().ItemReplication

		if itemReplication and itemReplication.Mastery and typeof(itemReplication.Mastery.readClient) == "function" then
			local ok, result = pcall(function()
				return itemReplication.Mastery.readClient(arg, arg2)
			end)

			if ok then
				return result
			end
		end

		return nil
	end

	checkItem = function(arg)
		local v = fn()
		local inventoryController = v.InventoryController
		local itemConfig = v.ItemConfig
		if not inventoryController or not itemConfig then
			return false, 0, nil
		end

		if typeof(inventoryController.GetIfInitialized) == "function" and not inventoryController:GetIfInitialized() then
			pcall(function()
				if typeof(inventoryController.Initialize) == "function" then
					inventoryController:Initialize()
				end
			end)
		end

		local ok, result = pcall(function()
			if typeof(inventoryController.GetTiles) == "function" then
				return inventoryController:GetTiles()
			end
		end)

		if not ok or type(result) ~= "table" then
			return false, 0, nil
		end
		local v2 = string.lower(tostring(arg))
		local v3 = string.gsub(v2, "%s+", "")

		for _, v4 in ipairs(result) do
			local v5 = nil

			pcall(function()
				v5 = itemConfig.match(v4.ItemId):asNullable()
			end)

			local storageKey = v5 and v5.Index and v5.Index.StorageKey
			local displayName = v5 and (v5.DisplayName or v5.Name)
			local str = storageKey or displayName or tostring(v4.ItemId)
			local v6 = string.lower(tostring(str))
			local v7 = string.gsub(v6, "%s+", "")
			local v8 = storageKey and string.lower(tostring(storageKey))
			local v9 = displayName and string.lower(tostring(displayName))

			if storageKey == arg or displayName == arg or str == arg or v6 == v2 or v7 == v3 or v8 and v8 == v2 or v9 and v9 == v2 or tostring(v4.ItemId) == arg then
				local v10 = fn2(v4.ItemId, v4.NetworkedUID)
				local v11

				if v10 <= 1 and (v4.Count or v4.Amount) then
					local num = tonumber(v4.Count or v4.Amount)

					if num and num > v10 then
						v11 = num
					else
						v11 = v10
					end
				else
					v11 = v10
				end

				return true, v11, (fn3(v4.ItemId, v4.NetworkedUID))
			end
		end

		return false, 0, nil
	end
end

checkItemQuantity = function(arg)
	if not arg or arg == "" then
		return false, "", 0
	end
	local v, v2 = checkItem(arg)
	if v and v2 and v2 > 0 then
		return true, arg, v2
	end
	return false, arg, 0
end

hasItem = function(arg)
	local v, v2, v3 = checkItemQuantity(arg)
	return v and v3 > 0
end

getItemQuantity = function(arg)
	local v, v2, v3 = checkItemQuantity(arg)
	return v3 or 0
end

getgenv().IgnoreUi = getgenv().IgnoreUi or false
getgenv().OneClickUi = true
ListSettingableOneClick = {}
LockedFruits = { "Kitsune-Kitsune", "Dough-Dough", "Dragon-Dragon", "Leopard-Leopard" }

if not getgenv().OneClickSetting then
	getgenv().FpsBoost1 = false
	getgenv().WhiteScreen = false
	getgenv().OneClickUi = true

	getgenv().OneClickSetting = {
		Enable = true,
		UnlimitGetQuest = true,
		TripleQuest = true,
		AutoAddStats = true,
		RedeemCode = true,
		Sea2KeyHop = true,
		FruitEat = { { "", "", "" }, {} },
		EatFruitFromStorage = false,
		SnipeFruit = true,
		SnipeFruitMirage = true,
		HopIfFoundNearExploiter = true,
		HopHakiColor = false,
		HopTushita = false,
		HopValkyriehelm = false,
		HopMirrorFractal = false,
		FarmPole = false,
		FarmItems = false,
		DisableSoulGuitar = false,
		DisableRaceEvolve = false,
		DisableCDK = false,
		Mastery = false,
		SwanFruitHop = false,
	}

	getgenv().OneClickFarms = {}
end

print("Wait For Blox Fruit UI")

while true do
	task.wait()
	if not (game:IsLoaded() and game:GetService("Players") and game:GetService("Players").LocalPlayer and game.ReplicatedStorage and game.Players.LocalPlayer:FindFirstChild("PlayerGui")) then
		continue
	end
	break
end

game:GetService("StarterGui")
local fn

do
	local tbl = {}
	ExternalSetting = { "Team", "SlowLoadUi", "FixCrash", "FixCrash2", "ForceUseSilentAim", "AutoLoad" }
	local n = 0

	while game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("LoadingScreen") and n < 30 do
		task.wait(1)
		n += 1
	end

	if n >= 30 then
		game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", game.JobId)
	end

	require(game:GetService("ReplicatedStorage").Reparent).Unparent = function()
	end

	if game:GetService("ReplicatedStorage").MapStash:FindFirstChild("Temple of Time") then
		local map = workspace.Map
		game:GetService("ReplicatedStorage").MapStash:FindFirstChild("Temple of Time").Parent = map
	end

	fn = function(...)
		local v = table.pack(...)

		if string.find(identifyexecutor(), "Wave") then
			local value = select(3, ...)

			if value == 0 then
				value = false
			elseif value == 1 then
				value = true
			end

			local tbl2 = { n = select("#", table.unpack(v, 1, v.n)), [3] = value, table.unpack(v, 1, v.n) }
			firetouchinterest(table.unpack(tbl2, 1, tbl2.n))
		else
			firetouchinterest(table.unpack({ ... }))
		end
	end

	TableEncodeSetting = function(arg)
		local str = "{"

		for k, v in pairs(arg) do
			local str2

			if type(v) == "boolean" then
				str2 = tostring(v)
			elseif type(v) == "string" then
				str2 = string.format("%q", v)
			else
				str2 = ""

				if type(v) == "number" then
					str2 = tostring(v)
				end
			end

			str ..= string.format("[%q]=%s,", k, str2)
		end

		return str .. "}"
	end

	for _, v in pairs(ExternalSetting) do
		print(v, getgenv()[v])
		tbl[v] = getgenv()[v]
	end

	Decode = function(arg)
		return loadstring("return " .. arg)()
	end

	StringSaveSetting = TableEncodeSetting(tbl)
end

print(StringSaveSetting)

do
	local ok, result = pcall(function()
		Decode(StringSaveSetting)
	end)

	if result then
		print(result)
	end
end

getgenv().Loaded = true
isfluxus = string.find(identifyexecutor(), "Fluxus") or string.find(identifyexecutor(), "ScriptWare")
local flag
flag = true

do
	local setThreadIdentity = syn and syn.set_thread_identity or set_thread_identity or setidentity or setthreadidentity or function()
	end

	if syn then
	end

	local v = isfluxus
	getgenv().fluxus = v
	fluxus = isfluxus

	SupportRetard = function()
		if not fluxus then
			setThreadIdentity(8)
		end
	end
end

SupportRetard()
virtualUser = game:GetService("VirtualUser")

if getgenv().Team ~= "Pirates" and getgenv().Team ~= "Marines" then
	getgenv().Team = "Pirates"
end

spawn(function()
	task.wait(5)
	SupportRetard()

	pcall(function()
		local effect = game:GetService("ReplicatedStorage"):FindFirstChild("Effect")
		effect = effect and effect:FindFirstChild("Container")
		effect = effect and effect:FindFirstChild("Death")

		if effect then
			local module = require(effect)

			if hookfunction then
				hookfunction(module, function()
				end)
			end
		end
	end)
end)

pcall(function()
	workspace._WorldOrigin["Foam;"]:Destroy()
	workspace._WorldOrigin.WaterSplashes:Destroy()
end)

local fn2

fn2 = function(arg)
	if arg and arg.Parent and arg:FindFirstChild("HumanoidRootPart") and arg:FindFirstChild("Humanoid") then
		if arg:FindFirstChild("Humanoid").Health and arg:FindFirstChild("Humanoid").Health > 0 then
			return true
		end
	end

	return false
end

ConvertPing = function(arg)
	local str = arg.Text:gsub(" ms", "")
	return tonumber(str)
end

GetPingTextPath = function()
	for _, child in ipairs(game.CoreGui.RobloxGui.PerformanceStats:GetChildren()) do
		if child:FindFirstChild("StatsMiniTextPanelClass") and child.StatsMiniTextPanelClass.TitleLabel.Text == "Ping" then
			return child.StatsMiniTextPanelClass.ValueLabel
		end
	end
end

GetPing = function()
	if not game.CoreGui.RobloxGui:FindFirstChild("PerformanceStats") then
		UserSettings().GameSettings.PerformanceStatsVisible = true
		return
	end
	local v = GetPingTextPath()
	return ConvertPing(v)
end

task.spawn(function()
	SupportRetard()

	local tbl = {
		Enum.ConnectionError.DisconnectErrors.Value,
		Enum.ConnectionError.PlacelaunchOtherError.Value,
		17,
		279,
		266,
		267,
		722,
		272,
		529,
		277,
		769,
	}

	while task.wait(1) do
		local value = game:GetService("GuiService"):GetErrorCode().Value

		for _, v in pairs(tbl) do
			if value == v then
				game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", game.JobId)
			end
		end

		if LastPing == game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue() and LastPing ~= 0 then
			SamePingCount = (SamePingCount or 0) + 1
		else
			SamePingCount = 0
		end

		if SamePingCount >= 60 then
			SamePingCount = 0
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, game.Players.LocalPlayer)
			task.wait(10)
		end

		LastPing = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
	end
end)

if not secure_call then
	secure_call = loadstring(game:HttpGet("https://raw.githubusercontent.com/hoannhatz/backup/refs/heads/main/secure_call.lua", true))()
end

while not game.Players.LocalPlayer.Team and task.wait(1) do
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("SetTeam", getgenv().Team)
end

repeat
	wait()
until game.Players.LocalPlayer.PlayerGui:FindFirstChild("Main")

local tbl = {
	HakiPad = {
		CFrame.new(-5414.41357, 309.865753, -2212.45776, 0.374604106, 0, -0.92718488, 0, 1, 0, 0.92718488, 0, 0.374604106),
		200,
	},
	Law = {
		CFrame.new(-5536.31396484375, 328.98834228515625, -5935.50244140625, 0.374604106, 0, -0.92718488, 0, 1, 0, 0.92718488, 0, 0.374604106),
		500,
	},
}

RenderFunc = function(arg)
	for i = 1, 25 do
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")
	end

	local tbl2 = { { { cf = tbl[arg][1], distance = tbl[arg][2], showTime = 90 } } }
	game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RequestStreamAroundAsync"):FireServer(unpack(tbl2))
	game.ReplicatedStorage.Remotes:WaitForChild("RequestStreamAroundAsync").OnClientEvent:Wait()

	for i = 1, 25 do
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer("getInventory")
	end
end

if Sea2 then
	RenderFunc("Law")
end

print("Choosed Team")
local Players, VirtualUser, VirtualInputManager, RunService, Lighting, localPlayer, n, currentPlaceKey

do
	local v = getsynasset or getcustomasset
	local request_ = http_request or request or HttpPost or (syn and syn.request)
	Players = game:GetService("Players")
	VirtualUser = game:GetService("VirtualUser")
	VirtualInputManager = game:GetService("VirtualInputManager")
	game:GetService("ReplicatedStorage")
	game:GetService("UserInputService")
	game:GetService("CoreGui")
	local HttpService = game:GetService("HttpService")
	RunService = game:getService("RunService")
	Lighting = game:getService("Lighting")
	localPlayer = Players.LocalPlayer
	n = 2800
	local placeId = game.PlaceId
	local attribute = workspace:GetAttribute("MAP")

	if attribute == "Sea1" or placeId == 85211729168715 or placeId == 2753915549 then
		Sea1 = true
		MaxLevelSea = 675
	elseif attribute == "Sea2" or placeId == 79091703265657 or placeId == 4442272183 then
		Sea2 = true
		MaxLevelSea = 1450
	elseif attribute == "Sea3" or placeId == 100117331123089 or placeId == 7449423635 then
		Sea3 = true
		MaxLevelSea = 2800
	else
		game.Players.LocalPlayer:Kick(string.format("Unsupported game | %s", tostring(game.PlaceId)))

		while task.wait() do
		end
	end

	local tbl2 = {
		["2753915549"] = "2753915549",
		["4442272183"] = "4442272183",
		["79091703265657"] = "4442272183",
		["7449423635"] = "7449423635",
		["100117331123089"] = "7449423635",
	}

	currentPlaceKey = nil

	if Sea1 then
		currentPlaceKey = "2753915549"
	elseif Sea2 then
		currentPlaceKey = "4442272183"
	elseif Sea3 then
		currentPlaceKey = "7449423635"
	end

	getgenv().CurrentPlaceKey = currentPlaceKey
	currentPlaceKey = currentPlaceKey or tbl2[tostring(game.PlaceId)]

	local setting = {
		Level = { Enable = false },
		OneClick = { Enable = false },
		Katakuri = { Enable = false },
		Bone = { Enable = false },
		AcceptQuest_Bone_Katakuri = { Enable = true },
		Elite = { Enable = false },
		["Tyrant Skies"] = { Enable = false },
		SubFarming = {},
		["Pirate Raid"] = { Enable = false },
		["Kill Aura"] = { Enable = false, DistanceFromAnchor = 4000, AnchorTPBack = true },
		Factory = { Enable = false },
		Mastery = { Enable = false, ["Fruit/Gun"] = false, ["Sword/Low"] = false, Sword = false },
		SelectWeapon = "Blox Fruit",
		LocalPlayer = {
			Speed = 90,
			SpeedHack = false,
			AutoBuso = true,
			AutoEnableObservation = false,
			WaterWalker = true,
			AutoUseV4 = false,
		},
		FastAttack = {
			Enable = true,
			TimeFastAttack = 80,
			TimeToAttack = 3,
			FastAttackIfBoss = false,
			OnPlayer = true,
			OnMob = true,
			OldFastAttack = false,
		},
		Tween = { Pause = false, TimeNeedPause = 2, TimePause = 0.2, Speed = 150 },
		Pvp = { AutoShootGun = false, Method = "Nearest" },
		ESP = { Player = false, Chest = false, Boss = false, Island = false, Fruit = false },
		SeaEvents = {
			ShipSpeedModifier = false,
			ShipSpeed = 300,
			SpinDistance = 200,
			DistanceNearSeaBeast = 300,
			DistanceNearMob = 300,
			AutoEscapeRoughSea = true,
		},
		Shop = { AutoBuyBribe = false, AutoRandomFruit = false, AutoRandomBone = false },
		SkillsSet2 = { ["Blox Fruit"] = true, Gun = true, Sword = true, Melee = true },
		SkillsSettingRemake = {
			["Blox Fruit"] = { "Z", "X", "C", "V", "F" },
			Gun = { "Z", "X" },
			Sword = { "Z", "X" },
			Melee = { "Z", "X", "C" },
		},
		UseDragonStorm = false,
		FruitSkillsHold = {},
		BringMob = { Enable = true, Radius = 200 },
		Fruit = { AutoStore = false, FruitsToSnipe = {} },
		GetFruit = { Enable = false },
		["Rip Indra"] = { Enable = false },
		["Black Beard"] = { Enable = false },
		["Dough King"] = { Enable = false },
		["Cake Prince"] = { Enable = false },
		["Full Dough King"] = { Enable = false },
		FullyRaceV4_Entrance = { Enable = false },
		Material = { Enable = false, Select = "" },
		Misc = { __RemoveNotification = false, __RemoveDMGCounter = false },
		Raid = { Select = "", Enable = false, NoDelay = true },
		Bartilo = { Enable = false },
		["Race Evolve"] = { Enable = false },
		["Haki Pad"] = { Enable = false },
		["Collect Chest"] = { Enable = false, InstaTP = false },
		["Open Pad"] = { Enable = false },
		["Spawn Black Beard"] = { Enable = false },
		["Spawn Rip Indra"] = { Enable = false },
		["Mirage Snipe Fruit"] = { Enable = false },
		["Soul Guitar"] = { Enable = false },
		["Material Soul Guitar"] = { Enable = false },
		["Black Beard Hop"] = { Enable = false },
		["Tushita Hop__1"] = { Enable = false },
		["Soul Reaper"] = { Enable = false },
		["Spawn Soul Reaper"] = { Enable = false },
		Tushita = { Enable = false },
		["Hybrid Fruit Hop"] = { Enable = false },
		["Raid Fruit Hop"] = { Enable = false },
		["Fully Cyborg"] = { Enable = false },
		["Fully Ghoul"] = { Enable = false },
		Law = { Enable = false },
		CDK = { Enable = false },
		["Level Observation"] = { Enable = false },
		["Rainbow Haki"] = { Enable = false },
		__SaberHop = { Enable = false },
		["Citizen Quest"] = { Enable = false },
		__PoleHop = { Enable = false },
		["Evolve Observation"] = { Enable = false },
		SwordSwitcher = { Enable = false },
		GunSwitcher = { Enable = false },
		["Get Ghoul"] = { Enable = false },
		["Unlock Electric Claw"] = { Enable = false },
		["Elite Hop"] = { Enable = false },
		["Rip Indra Hop"] = { Enable = false },
		YoruV3 = { Enable = false, Upgrade = false, SelectedPlayer = nil },
		BossSniper = { Enable = false, SelectedBoss = {} },
		SafeMode_GetGoodItem = { Enable = true },
		__KatakuriHop = { Enable = false },
		BlackSmith = { Enable = false, WeaponType = false },
	}

	getgenv().SettingManager = {}

	if not SettingManager then
		SettingManager = getgenv().SettingManager
	end

	SettingManager.SetTheme = function(arg, image)
		if image then
			UIThemeCustom.ImageTransparency = 0
			UIThemeCustom.Image = image
		end
	end

	SettingManager.SetAvatar = function(arg, arg2, arg3)
		pcall(function()
			local str = tostring(arg3)
			local str2 = arg.CurrentFolder .. "/Cache/Avt.png"

			if not isfile(str2) then
				writefile(str2, request_({
					Url = "https://cdn.discordapp.com/avatars/" .. str .. "/" .. arg2 .. ".png",
					Method = "GET",
					Headers = { ["Content-Type"] = "application/json" },
				}).Body)

				repeat
					wait()
				until isfile(str2)
			end

			if isfile(str2) then
				UserIcon.Image = v(str2)
			end
		end)
	end

	SettingManager.SetFolder = function(arg, currentFolder)
		if not isfolder(currentFolder) then
			makefolder(currentFolder)
		end

		arg.CurrentFolder = currentFolder
		arg.Theme = arg.CurrentFolder .. "/Theme"
		arg.Cache = arg.CurrentFolder .. "/Cache"
		arg.AutoSave = arg.CurrentFolder .. "/Main"
		arg.Config = arg.CurrentFolder .. "/ConfigMain"
		arg.Global = arg.CurrentFolder .. "/Global"
		arg.AutoLoad = arg.AutoSave .. "/" .. game.Players.LocalPlayer.Name .. ".txt"
		arg.GlobalTheme = arg.Global .. "/GlobalTheme.txt"
		arg.GlobalTrans = arg.Global .. "/GlobalTrans.txt"
		arg.AutoData = arg.Config .. "/" .. game.Players.LocalPlayer.Name .. ".json"
		arg.SameAcc = arg.CurrentFolder .. "/SameAcc"
		arg.AutoConfig = arg.AutoData

		if not isfolder(arg.Theme) then
			makefolder(arg.Theme)
		end

		if not isfolder(arg.SameAcc) then
			makefolder(arg.SameAcc)
		end

		if not isfolder(arg.Cache) then
			makefolder(arg.Cache)
		end

		if not isfolder(arg.AutoSave) then
			makefolder(arg.AutoSave)
		end

		if not isfolder(arg.Config) then
			makefolder(arg.Config)
		end
	end

	SettingManager.SetGlobalTrans = function(arg, arg2, arg3)
		if arg2 then
			writefile(arg.GlobalTrans, HttpService:JSONEncode(arg3))
			return
		end
		return isfile(arg.GlobalTrans) and HttpService:JSONDecode(readfile(arg.GlobalTrans))
	end

	SettingManager.SetGlobalTheme = function(arg, arg2, arg3)
		if arg2 then
			writefile(arg.GlobalTheme, HttpService:JSONEncode(arg3))
			return
		end
		return isfile(arg.GlobalTheme) and HttpService:JSONDecode(readfile(arg.GlobalTheme))
	end

	SettingManager.SetSameInstance = function(arg)
		if isfolder(arg.SameAcc) then
			if isfile(arg.SameAcc .. "/Account.json") then
				local data = HttpService:JSONDecode(readfile(arg.SameAcc .. "/Account.json"))

				if not table.find(data, localPlayer.Name) then
					table.insert(data, localPlayer.Name)
					writefile(arg.SameAcc .. "/Account.json", HttpService:JSONEncode(data))
				end

				for _, player in pairs(Players:GetPlayers()) do
					if player == localPlayer then
						continue
					end

					if table.find(data, player.Name) then
						print("Checked Same: " .. player.Name)
						return true
					end
				end
			else
				writefile(arg.SameAcc .. "/Account.json", HttpService:JSONEncode({ localPlayer.Name }))
			end
		end
	end

	SettingManager.LoadAutoConfig = function(arg)
		if not isfile(arg.AutoLoad) then
			writefile(arg.AutoLoad, arg.Config .. "/" .. game.Players.LocalPlayer.Name .. ".json")
		else
			local v2 = readfile(arg.AutoLoad)

			if isfile(v2) then
				arg.AutoConfig = v2
				print("Auto load")
				local data = nil

				pcall(function()
					data = HttpService:JSONDecode(readfile(arg.AutoConfig))
				end)

				return data
			end
		end
	end

	SettingManager.SetAutoConfig = function(arg, arg2)
		writefile(arg.AutoLoad, arg2)
	end

	SettingManager.New = function(arg, arg2)
		writefile(arg.Config .. "/" .. arg2, HttpService:JSONEncode({}))
	end

	SettingManager.Save = function(arg, arg2, arg3)
		if arg2 and arg3 then
			return (pcall(function()
				writefile(arg2, HttpService:JSONEncode(arg3))
			end))
		end
		writefile(arg.AutoData, getgenv().Setting and HttpService:JSONEncode({ Setting = getgenv().Setting }) or HttpService:JSONEncode({}))
	end

	SettingManager.Load = function(arg, arg2)
		if isfile(arg.Config .. "/" .. arg2) then
			return HttpService:JSONDecode(readfile(arg.AutoSave .. "/" .. arg2))
		end
	end

	SettingManager.ListFile = function(arg, arg2)
		return listfiles(arg.CurrentFolder .. ({ Theme = "/Theme", Config = "/ConfigMain" })[arg2])
	end

	SettingManager:SetFolder("Oneclick")

	if not getgenv().Setting then
		getgenv().Setting = {}
	end

	local v2 = SettingManager:LoadAutoConfig()

	if v2 and v2.Setting then
		for k, v3 in pairs(v2.Setting) do
			getgenv().Setting[k] = v3
		end

		for k, v3 in pairs(setting) do
			if not getgenv().Setting[k] then
				print("Missing: " .. k, v3)
				getgenv().Setting[k] = v3
				print(getgenv().Setting[k])
			end
		end

		local tween_ = getgenv().Setting.Tween

		if tween_ then
			tween_ = not getgenv().Setting.Tween.Speed or getgenv().Setting.Tween.Speed == 195 or getgenv().Setting.Tween.Speed == 250 or getgenv().Setting.Tween.Speed == 300
		end

		if tween_ then
			getgenv().Setting.Tween.Speed = 150
		end

		print("Loaded")
	else
		print("Dell load")
		getgenv().Setting = setting
		SettingManager:Save()
	end
end

do
	local v = pairs
	local oneClickSetting = getgenv().OneClickSetting or {}

	for k, v2 in v(oneClickSetting) do
		getgenv().Setting.OneClick[k] = v2
	end
end

SupportRetard()
print("Get Exteral Data")
PriorityQueue = loadstring(game:HttpGet("https://raw.githubusercontent.com/hoannhatz/backup/refs/heads/main/PriorityQueue.lua", true))()
print("Getting Game Data")
local tbl2

tbl2 = {
	MetaData = {},
	Places = {
		["2753915549"] = {
			["Pirate Start Island"] = CFrame.new(781.37255859375, 5.7767753601074, 1437.2399902344),
			["Marine Start Island"] = CFrame.new(-2606.2143554688, 6.7695031166077, 2043.04553222667),
			["Middle Town"] = CFrame.new(-655.824158, 7.88708115, 1436.67908),
			Jungle = CFrame.new(-1334.1259765625, 11.852984428406, 502.03717041016),
			["Shank's Room"] = CFrame.new(-1455.4440917969, 29.851997375488, -37.440139770508),
			["Pirate Village"] = CFrame.new(-1187.3435058594, 4.7515587806702, 3809.2456054688),
			Desert = CFrame.new(1094.14587, 6.47350502, 4192.88721),
			["Frozen Village"] = CFrame.new(1112.4229736328, 7.3036189079285, -1159.3383789062),
			["Marine Fortress"] = CFrame.new(-4817.0161132812, 20.651899337769, 4368.0639648438),
			["Mob Leader Place"] = CFrame.new(-2839.7548828125, 7.3262448310852, 5319.9428710938),
			Prison = CFrame.new(4874.8125, 5.6519904136658, 735.57012939453),
			Colosseum = CFrame.new(-1423.5014648438, 7.2882599830627, -2798.2961425781),
			Skylands = CFrame.new(-4970.21875, 717.707275, -2622.35449),
			SkyArea1 = CFrame.new(-4166.60986328125, 1092.744873046875, -347.16226196289062, 1, 5.1830135738839545e-09, -1.6339706009668026e-13, -5.1830135738839545e-09, 1, -3.6744087772433431e-09, 1.6337800524349883e-13, 3.6744087772433431e-09, 1),
			SkyArea2 = CFrame.new(-6023.57666015625, 5469.4384765625, 2203.308349609375, 1, -8.4390421761781909e-08, -2.6110152705698759e-15, 8.4390421761781909e-08, 1, 5.9774379224109e-08, -2.4333695916410733e-15, -5.9774379224109e-08, 1),
			["Sky Secret Temple"] = CFrame.new(-7390.0791015625, 5743.578125, 338.90826416015625, -0.572482109, 0, -0.819917202, 0, 1, 0, 0.819917202, 0, -0.572482109),
			["Magma Village"] = CFrame.new(-5231.75879, 8.61593437, 8467.87695),
			["Magma Cave"] = CFrame.new(-60966.09765625, 6838.58349609375, 9060.8896484375),
			["Sewer System"] = CFrame.new(-251.89410400390625, -568.750244140625, -121.50762939453125),
			["Fish Entrance Island"] = CFrame.new(3868.501953125, 5.5923495292663574, -1917.993408203125),
			["UnderWater City Gate"] = CFrame.new(3853.0385742188, 5.3731479644775, -1919.4447021484),
			["UnderWater City"] = CFrame.new(61092.36328125, 18.471633911133, 1711.1674804688),
			["Fountain City"] = CFrame.new(5053.0297851562, 1.5012743473053, 4054.8439941406),
		},
		["4442272183"] = {
			["First Spot"] = CFrame.new(-11.845784187317, 29.276727676392, 2768.9770507812),
			Cafe = CFrame.new(-384.03524780273, 73.020072937012, 353.2282409668),
			["Swan Mansion"] = CFrame.new(-390.096313, 331.886475, 673.464966),
			["Swan Room"] = CFrame.new(2302.19019, 15.1778421, 663.811035),
			Factory = CFrame.new(430.42569, 210.019623, -432.504791),
			Colosseum = CFrame.new(-1836.58191, 44.5890656, 1360.30652),
			["Dark Arena"] = CFrame.new(3781.985107421875, 14.850649833679199, -3498.081298828125),
			["Green bit"] = CFrame.new(-2304.93359375, 72.966117858887, -2782.6965332031),
			["Graveyard Island"] = CFrame.new(-5377.3295898438, 8.9691047668457, -708.45489501953),
			["Snow Mountain"] = CFrame.new(554.47235107422, 401.42199707031, -5364.732421875),
			["Hot And Cold Island"] = CFrame.new(-5944.7875976562, 15.951756477356, -5114.8725585938),
			["Cursed Ship Gate"] = CFrame.new(-6509.4169921875, 83.187019348145, -137.39677429199801),
			["Cursed Ship"] = CFrame.new(902.059143, 124.752518, 33071.8125),
			["Ice Castle"] = CFrame.new(5662.44140625, 28.191165924072, -5982.9755859375),
			["Forgotten Island"] = CFrame.new(-3043.31543, 238.881271, -10191.5791),
			["Usoap Island"] = CFrame.new(4778.2431640625, 8.2086620330811, 2871.4936523438),
			["Minisky Island"] = CFrame.new(-260.358917, 49325.7031, -35259.3008),
			["Indra Island"] = CFrame.new(-27007.9363, 9.033, 466.6544),
		},
		["7449423635"] = {
			["Port Town"] = CFrame.new(-447.46743774414, 6.7299399375916, 5306.3686523438),
			["Hydra Island"] = CFrame.new(5335.88623046875, 1004.7794799804688, 241.50193786621094),
			["Secret Temple"] = CFrame.new(5231.6831054688, 7.3780846595764, 1102.6005859375),
			["Great Tree"] = CFrame.new(2253.0600585938, 24.144220352173, -6405.6694335938),
			["Castle on the sea"] = CFrame.new(-5026.3584, 323.515503, -2996.28442),
			["Pineapple Town"] = CFrame.new(-11363.5166, 362.381439, -10327.9727),
			Mansion = CFrame.new(-12553.0595703125, 337.38748168945312, -7471.96142578125),
			["Floating Turtle"] = CFrame.new(-12001.6152, 1707.39319, -8789.03711),
			["Beautiful Pirate Gate"] = CFrame.new(-11990.901367188, 331.80770874023, -8845.5888671875),
			["Beautiful Pirate Domain"] = CFrame.new(5310.80957, 160.446838, 129.390533),
			["Friendly Arena"] = CFrame.new(5220.28955, 72.8193436, -1500.86304),
			["Haunted Castle"] = CFrame.new(-9530.61035, 200.860657, 5763.13477),
			["Soul Reaper Raid Room"] = CFrame.new(-9522.0957, 315.89975, 6751.88818),
			["Peanut Island"] = CFrame.new(-2087.0561523438, 11.722011566162, -10002.080078125),
			["Ice Cream Island"] = CFrame.new(-851.74633789062, 65.819496154785, -10932.150390625),
			["Sea Of Treats"] = CFrame.new(-1907.1773681640625, 9.5656547546386719, -11539.8251953125),
		},
	},
}

do
	local tripleQuest = {}
	local tbl3 = {}

	tbl3[0] = {
		Quest = game.Players.LocalPlayer.Team and game.Players.LocalPlayer.Team.Name == "Marines" and "MarineQuest" or "BanditQuest1",
		QuestCFrame = game.Players.LocalPlayer.Team and game.Players.LocalPlayer.Team.Name == "Marines" and CFrame.new(-2655.284, 30.567, 2113.724) or CFrame.new(1051.798, 11.016, 1557.743),
		{
			Requirement = 0,
			Mob = game.Players.LocalPlayer.Team and game.Players.LocalPlayer.Team.Name == "Marines" and "Trainee [Lv. 5]" or "Bandit [Lv. 5]",
			QuestCheck = game.Players.LocalPlayer.Team and game.Players.LocalPlayer.Team.Name == "Marines" and "Trainee" or "Bandit",
		},
	}

	tbl3[10] = {
		Quest = "JungleQuest",
		QuestCFrame = CFrame.new(-1679.763, 48.74, 175.64),
		{ Requirement = 10, Mob = "Monkey [Lv. 14]", QuestCheck = "Monkey" },
		{ Requirement = 15, Mob = "Gorilla [Lv. 20]", QuestCheck = "Gorilla" },
		{
			Requirement = 20,
			Boss = "The Gorilla King [Lv. 25] [Boss]",
			QuestCheck = "The Gorilla King",
			Quest = "JungleQuest",
			QuestCFrame = CFrame.new(-1679.763, 48.74, 175.64),
		},
	}

	tbl3[30] = {
		Quest = "BuggyQuest1",
		QuestCFrame = CFrame.new(-1151.586, 13.615, 3863.125),
		{ Requirement = 30, Mob = "Pirate [Lv. 35]", QuestCheck = "Pirate" },
		{ Requirement = 40, Mob = "Brute [Lv. 45]", QuestCheck = "Brute" },
		{
			Requirement = 55,
			Boss = "Bobby [Lv. 55] [Boss]",
			QuestCheck = "Bobby",
			Quest = "BuggyQuest1",
			QuestCFrame = CFrame.new(-1151.586, 13.615, 3863.125),
		},
	}

	tbl3[60] = {
		Quest = "DesertQuest",
		QuestCFrame = CFrame.new(931.378, 4.684, 4198.213),
		{ Requirement = 60, Mob = "Desert Bandit [Lv. 60]", QuestCheck = "Desert Bandit" },
		{ Requirement = 75, Mob = "Desert Officer [Lv. 75]", QuestCheck = "Desert Officer" },
	}

	tbl3[90] = {
		Quest = "SnowQuest",
		QuestCFrame = CFrame.new(1400.564, 77.391, -1311.285),
		{ Requirement = 90, Mob = "Snow Bandit [Lv. 90]", QuestCheck = "Snow Bandit" },
		{ Requirement = 100, Mob = "Snowman [Lv. 100]", QuestCheck = "Snowman" },
		{
			Requirement = 105,
			Boss = "Yeti [Lv. 110] [Boss]",
			QuestCheck = "Yeti",
			Quest = "SnowQuest",
			QuestCFrame = CFrame.new(1400.564, 77.391, -1311.285),
		},
	}

	tbl3[120] = {
		Quest = "MarineQuest2",
		QuestCFrame = CFrame.new(-4699.331, 4.741, 4227.639),
		{
			Requirement = 120,
			Mob = "Chief Petty Officer [Lv. 120]",
			QuestCheck = "Chief Petty Officer",
		},
		[3] = {
			Requirement = 130,
			Boss = "Vice Admiral [Lv. 130] [Boss]",
			QuestCheck = "Vice Admiral",
			Quest = "MarineQuest2",
			QuestCFrame = CFrame.new(-4699.331, 4.741, 4227.639),
			Index = 2,
		},
	}

	tbl3[150] = {
		Quest = "SkyQuest",
		QuestCFrame = CFrame.new(-4750.18, 966.067, -748.241),
		{ Requirement = 150, Mob = "Sky Bandit [Lv. 150]", QuestCheck = "Sky Bandit" },
		{ Requirement = 175, Mob = "Dark Master [Lv. 175]", QuestCheck = "Dark Master" },
	}

	tbl3[190] = {
		Quest = "PrisonerQuest",
		QuestCFrame = CFrame.new(5208.339, 15.872, 736.586),
		{ Requirement = 190, Mob = "Prisoner [Lv. 190]", QuestCheck = "Prisoner" },
		{
			Requirement = 210,
			Mob = "Dangerous Prisoner [Lv. 210]",
			QuestCheck = "Dangerous Prisoner",
		},
	}

	tbl3[225] = {
		Quest = "ImpelQuest",
		QuestCFrame = CFrame.new(5320.666, 18.886, 856.281),
		{ Requirement = 225, Mob = "Ruthless Prisoner [Lv. 225]", QuestCheck = "Ruthless Prisoner" },
		[3] = {
			Requirement = 230,
			Boss = "Warden [Lv. 220]",
			QuestCheck = "Warden",
			Quest = "ImpelQuest",
			QuestCFrame = CFrame.new(5320.666, 18.886, 856.281),
			Index = 2,
		},
	}

	tbl3[250] = {
		Quest = "ColosseumQuest",
		QuestCFrame = CFrame.new(-1342.255, 11.151, -2928.581),
		{ Requirement = 250, Mob = "Toga Warrior [Lv. 250]", QuestCheck = "Toga Warrior" },
		{ Requirement = 275, Mob = "Gladiator [Lv. 275]", QuestCheck = "Gladiator" },
	}

	tbl3[300] = {
		Quest = "MagmaQuest",
		QuestCFrame = CFrame.new(-5308.867, 17.035, 8482.698),
		{ Requirement = 300, Mob = "Military Soldier [Lv. 300]", QuestCheck = "Military Soldier" },
		{ Requirement = 325, Mob = "Military Spy [Lv. 325]", QuestCheck = "Military Spy" },
		{
			Requirement = 350,
			Boss = "Magma Admiral [Lv. 350] [Boss]",
			QuestCheck = "Magma Admiral",
			Quest = "MagmaQuest",
			QuestCFrame = CFrame.new(-5308.867, 17.035, 8482.698),
		},
	}

	tbl3[375] = {
		Quest = "FishmanQuest",
		QuestCFrame = CFrame.new(61406.195, 24.519, 1626.816),
		{ Requirement = 375, Mob = "Fishman Warrior [Lv. 375]", QuestCheck = "Fishman Warrior" },
		{ Requirement = 400, Mob = "Fishman Commando [Lv. 400]", QuestCheck = "Fishman Commando" },
		{
			Requirement = 425,
			Boss = "Fishman Lord [Lv. 425] [Boss]",
			QuestCheck = "Fishman Lord",
			Quest = "FishmanQuest",
			QuestCFrame = CFrame.new(61406.195, 24.519, 1626.816),
		},
	}

	tbl3[400] = {
		Quest = "FishmanQuest",
		QuestCFrame = CFrame.new(61406.195, 24.519, 1626.816),
		{ Requirement = 375, Mob = "Fishman Warrior [Lv. 375]", QuestCheck = "Fishman Warrior" },
		{ Requirement = 400, Mob = "Fishman Commando [Lv. 400]", QuestCheck = "Fishman Commando" },
		{
			Requirement = 425,
			Boss = "Fishman Lord [Lv. 425] [Boss]",
			QuestCheck = "Fishman Lord",
			Quest = "FishmanQuest",
			QuestCFrame = CFrame.new(61406.195, 24.519, 1626.816),
		},
	}

	tbl3[450] = {
		Quest = "SkyExp1Quest",
		QuestCFrame = CFrame.new(-4882.894, 926.177, -1031.055),
		{ Requirement = 450, Mob = "God's Guard [Lv. 450]", QuestCheck = "God's Guard" },
		{ Requirement = 475, Mob = "Shanda [Lv. 475]", QuestCheck = "Shanda" },
		{
			Requirement = 500,
			Boss = "Wysper [Lv. 500] [Boss]",
			QuestCheck = "Wysper",
			Quest = "SkyExp1Quest",
			QuestCFrame = CFrame.new(-4882.894, 926.177, -1031.055),
		},
	}

	tbl3[475] = {
		Quest = "SkyExp1Quest",
		QuestCFrame = CFrame.new(-4882.894, 926.177, -1031.055),
		{ Requirement = 450, Mob = "God's Guard [Lv. 450]", QuestCheck = "God's Guard" },
		{ Requirement = 475, Mob = "Shanda [Lv. 475]", QuestCheck = "Shanda" },
		{
			Requirement = 500,
			Boss = "Wysper [Lv. 500] [Boss]",
			QuestCheck = "Wysper",
			Quest = "SkyExp1Quest",
			QuestCFrame = CFrame.new(-4882.894, 926.177, -1031.055),
		},
	}

	tbl3[525] = {
		Quest = "SkyExp2Quest",
		QuestCFrame = CFrame.new(-7033.101, 5590.574, 1353.107),
		{ Requirement = 525, Mob = "Royal Squad [Lv. 525]", QuestCheck = "Royal Squad" },
		{ Requirement = 550, Mob = "Royal Soldier [Lv. 550]", QuestCheck = "Royal Soldier" },
		{
			Requirement = 575,
			Boss = "Thunder God [Lv. 575] [Boss]",
			QuestCheck = "Thunder God",
			Quest = "SkyExp2Quest",
			QuestCFrame = CFrame.new(-7033.101, 5590.574, 1353.107),
		},
	}

	tbl3[550] = {
		Quest = "SkyExp2Quest",
		QuestCFrame = CFrame.new(-7033.101, 5590.574, 1353.107),
		{ Requirement = 525, Mob = "Royal Squad [Lv. 525]", QuestCheck = "Royal Squad" },
		{ Requirement = 550, Mob = "Royal Soldier [Lv. 550]", QuestCheck = "Royal Soldier" },
		{
			Requirement = 575,
			Boss = "Thunder God [Lv. 575] [Boss]",
			QuestCheck = "Thunder God",
			Quest = "SkyExp2Quest",
			QuestCFrame = CFrame.new(-7033.101, 5590.574, 1353.107),
		},
	}

	tbl3[625] = {
		Quest = "FountainQuest",
		QuestCFrame = CFrame.new(5263.488, 74.908, 4087.616),
		{ Requirement = 625, Mob = "Galley Pirate [Lv. 625]", QuestCheck = "Galley Pirate" },
		{ Requirement = 650, Mob = "Galley Captain [Lv. 650]", QuestCheck = "Galley Captain" },
		{
			Requirement = 675,
			Boss = "Cyborg [Lv. 675] [Boss]",
			QuestCheck = "Cyborg",
			Quest = "FountainQuest",
			QuestCFrame = CFrame.new(5263.488, 74.908, 4087.616),
		},
	}

	tbl3[650] = {
		Quest = "FountainQuest",
		QuestCFrame = CFrame.new(5263.488, 74.908, 4087.616),
		{ Requirement = 625, Mob = "Galley Pirate [Lv. 625]", QuestCheck = "Galley Pirate" },
		{ Requirement = 650, Mob = "Galley Captain [Lv. 650]", QuestCheck = "Galley Captain" },
		{
			Requirement = 675,
			Boss = "Cyborg [Lv. 675] [Boss]",
			QuestCheck = "Cyborg",
			Quest = "FountainQuest",
			QuestCFrame = CFrame.new(5263.488, 74.908, 4087.616),
		},
	}

	tripleQuest["2753915549"] = tbl3

	tripleQuest["4442272183"] = {
		[700] = {
			Quest = "Area1Quest",
			QuestCFrame = CFrame.new(-424.080078, 73.0055847, 1836.91589),
			{ Requirement = 700, Mob = "Raider [Lv. 700]", QuestCheck = "Raider" },
			{ Requirement = 725, Mob = "Mercenary [Lv. 725]", QuestCheck = "Mercenary" },
			{
				Requirement = 750,
				Boss = "Diamond [Lv. 750] [Boss]",
				QuestCheck = "Diamond",
				Quest = "Area1Quest",
				QuestCFrame = CFrame.new(-424.080078, 73.0055847, 1836.91589),
			},
		},
		[775] = {
			Quest = "Area2Quest",
			QuestCFrame = CFrame.new(934.597229, 73.3029785, 1250.96814),
			{ Requirement = 775, Mob = "Swan Pirate [Lv. 775]", QuestCheck = "Swan Pirate" },
			{ Requirement = 800, Mob = "Factory Staff [Lv. 800]", QuestCheck = "Factory Staff" },
			{
				Requirement = 850,
				Boss = "Jeremy [Lv. 850] [Boss]",
				QuestCheck = "Jeremy",
				Quest = "Area2Quest",
				QuestCFrame = CFrame.new(934.597229, 73.3029785, 1250.96814),
			},
		},
		[875] = {
			Quest = "MarineQuest3",
			QuestCFrame = CFrame.new(-2442.65015, 73.0511475, -3219.11523),
			{
				Requirement = 875,
				Mob = "Marine Lieutenant [Lv. 875]",
				QuestCheck = "Marine Lieutenant",
			},
			{ Requirement = 900, Mob = "Marine Captain [Lv. 900]", QuestCheck = "Marine Captain" },
			{
				Requirement = 925,
				Boss = "Orbitus [Lv. 925] [Boss]",
				QuestCheck = "Orbitus",
				Quest = "MarineQuest3",
				QuestCFrame = CFrame.new(-2442.65015, 73.0511475, -3219.11523),
			},
		},
		[950] = {
			Quest = "ZombieQuest",
			QuestCFrame = CFrame.new(-5492.79395, 48.5151672, -793.710571),
			{ Requirement = 950, Mob = "Zombie [Lv. 950]", QuestCheck = "Zombie" },
			{ Requirement = 975, Mob = "Vampire [Lv. 975]", QuestCheck = "Vampire" },
		},
		[1000] = {
			Quest = "SnowMountainQuest",
			QuestCFrame = CFrame.new(604.964966, 401.457062, -5371.69287),
			{ Requirement = 1000, Mob = "Snow Trooper [Lv. 1000]", QuestCheck = "Snow Trooper" },
			{ Requirement = 1050, Mob = "Winter Warrior [Lv. 1050]", QuestCheck = "Winter Warrior" },
		},
		[1100] = {
			Quest = "IceSideQuest",
			QuestCFrame = CFrame.new(-6060.10693, 15.9868021, -4904.7876),
			{
				Requirement = 1100,
				Mob = "Lab Subordinate [Lv. 1100]",
				QuestCheck = "Lab Subordinate",
			},
			{ Requirement = 1125, Mob = "Horned Warrior [Lv. 1125]", QuestCheck = "Horned Warrior" },
			{
				Requirement = 1150,
				Boss = "Smoke Admiral [Lv. 1150] [Boss]",
				QuestCheck = "Smoke Admiral",
				Quest = "IceSideQuest",
				QuestCFrame = CFrame.new(-6060.10693, 15.9868021, -4904.7876),
			},
		},
		[1175] = {
			Quest = "FireSideQuest",
			QuestCFrame = CFrame.new(-5431.09473, 15.9868021, -5296.53223),
			{ Requirement = 1175, Mob = "Magma Ninja [Lv. 1175]", QuestCheck = "Magma Ninja" },
			{ Requirement = 1200, Mob = "Lava Pirate [Lv. 1200]", QuestCheck = "Lava Pirate" },
			{
				Requirement = 1150,
				Boss = "Smoke Admiral [Lv. 1150] [Boss]",
				QuestCheck = "Smoke Admiral",
				Quest = "IceSideQuest",
				QuestCFrame = CFrame.new(-6060.10693, 15.9868021, -4904.7876),
			},
		},
		[1250] = {
			Quest = "ShipQuest1",
			QuestCFrame = CFrame.new(1037.80127, 125.092171, 32911.6016),
			{ Requirement = 1250, Mob = "Ship Deckhand [Lv. 1250]", QuestCheck = "Ship Deckhand" },
			{ Requirement = 1275, Mob = "Ship Engineer [Lv. 1275]", QuestCheck = "Ship Engineer" },
		},
		[1300] = {
			Quest = "ShipQuest2",
			QuestCFrame = CFrame.new(968.80957, 125.092171, 33244.125),
			{ Requirement = 1300, Mob = "Ship Steward [Lv. 1300]", QuestCheck = "Ship Steward" },
			{ Requirement = 1325, Mob = "Ship Officer [Lv. 1325]", QuestCheck = "Ship Officer" },
		},
		[1350] = {
			Quest = "FrostQuest",
			QuestCFrame = CFrame.new(5669.43506, 28.2117786, -6482.60107),
			{ Requirement = 1350, Mob = "Arctic Warrior [Lv. 1350]", QuestCheck = "Arctic Warrior" },
			{ Requirement = 1375, Mob = "Snow Lurker [Lv. 1375]", QuestCheck = "Snow Lurker" },
			{
				Requirement = 1400,
				Boss = "Awakened Ice Admiral [Lv. 1400] [Boss]",
				QuestCheck = "Awakened Ice Admiral",
				Quest = "FrostQuest",
				QuestCFrame = CFrame.new(5669.43506, 28.2117786, -6482.60107),
			},
		},
		[1425] = {
			Quest = "ForgottenQuest",
			QuestCFrame = CFrame.new(-3053.89648, 236.881363, -10148.2324),
			{ Requirement = 1425, Mob = "Sea Soldier [Lv. 1425]", QuestCheck = "Sea Soldier" },
			{ Requirement = 1450, Mob = "Water Fighter [Lv. 1450]", QuestCheck = "Water Fighter" },
			{
				Requirement = 1475,
				Boss = "Tide Keeper [Lv. 1475] [Boss]",
				QuestCheck = "Tide Keeper",
				Quest = "ForgottenQuest",
				QuestCFrame = CFrame.new(-3053.89648, 236.881363, -10148.2324),
			},
		},
	}

	tripleQuest["7449423635"] = {
		[1500] = {
			Quest = "PiratePortQuest",
			QuestCFrame = CFrame.new(-292.57437133789062, 43.793220520019531, 5583.04052734375),
			{
				Requirement = 1500,
				Mob = "Pirate Millionaire [Lv. 1500]",
				QuestCheck = "Pirate Millionaire",
			},
			{
				Requirement = 1525,
				Mob = "Pistol Billionaire [Lv. 1525]",
				QuestCheck = "Pistol Billionaire",
			},
			{
				Requirement = 1550,
				Boss = "Stone [Lv. 1550] [Boss]",
				QuestCheck = "Stone",
				Quest = "PiratePortQuest",
				QuestCFrame = CFrame.new(-292.57437133789062, 43.793220520019531, 5583.04052734375),
			},
		},
		[1575] = {
			Quest = "DragonCrewQuest",
			QuestCFrame = CFrame.new(5833.5776367188, 51.575191497803, -1102.7550048828),
			{
				Requirement = 1575,
				Mob = "Dragon Crew Warrior [Lv. 1575]",
				QuestCheck = "Dragon Crew Warrior",
			},
			{
				Requirement = 1600,
				Mob = "Dragon Crew Archer [Lv. 1600]",
				QuestCheck = "Dragon Crew Archer",
			},
		},
		[1625] = {
			Quest = "VenomCrewQuest",
			QuestCFrame = CFrame.new(5216.09521484375, 1004.1062622070312, 758.38958740234375),
			{ Requirement = 1625, Mob = "Hydra Enforcer [Lv. 1625]", QuestCheck = "Hydra Enforcer" },
			{
				Requirement = 1650,
				Mob = "Venomous Assailant [Lv. 1650]",
				QuestCheck = "Venomous Assailant",
			},
			{
				Requirement = 1675,
				Boss = "Island Empress [Lv. 1675] [Boss]",
				QuestCheck = "Island Empress",
				Quest = "VenomCrewQuest",
				QuestCFrame = CFrame.new(5216.09521484375, 1004.1062622070312, 758.38958740234375),
			},
		},
		[1700] = {
			Quest = "MarineTreeIsland",
			QuestCFrame = CFrame.new(2179.2548828125, 28.701448440552, -6739.7299804688),
			{
				Requirement = 1700,
				Mob = "Marine Commodore [Lv. 1700]",
				QuestCheck = "Marine Commodore",
			},
			{
				Requirement = 1725,
				Mob = "Marine Rear Admiral [Lv. 1725]",
				QuestCheck = "Marine Rear Admiral",
			},
			{
				Requirement = 1750,
				Boss = "Kilo Admiral [Lv. 1750] [Boss]",
				QuestCheck = "Kilo Admiral",
				Quest = "MarineTreeIsland",
				QuestCFrame = CFrame.new(2179.2548828125, 28.701448440552, -6739.7299804688),
			},
		},
		[1775] = {
			Quest = "DeepForestIsland3",
			QuestCFrame = CFrame.new(-10580.998046875, 331.75863647461, -8758.193359375),
			{ Requirement = 1775, Mob = "Fishman Raider [Lv. 1775]", QuestCheck = "Fishman Raider" },
			{
				Requirement = 1800,
				Mob = "Fishman Captain [Lv. 1800]",
				QuestCheck = "Fishman Captain",
			},
		},
		[1825] = {
			Quest = "DeepForestIsland",
			QuestCFrame = CFrame.new(-13231.467773438, 332.37414550781, -7626.6860351563),
			{ Requirement = 1825, Mob = "Forest Pirate [Lv. 1825]", QuestCheck = "Forest Pirate" },
			{
				Requirement = 1850,
				Mob = "Mythological Pirate [Lv. 1850]",
				QuestCheck = "Mythological Pirate",
			},
			{
				Requirement = 1875,
				Boss = "Captain Elephant [Lv. 1875] [Boss]",
				QuestCheck = "Captain Elephant",
				Quest = "DeepForestIsland",
				QuestCFrame = CFrame.new(-13231.467773438, 332.37414550781, -7626.6860351563),
			},
		},
		[1900] = {
			Quest = "DeepForestIsland2",
			QuestCFrame = CFrame.new(-12683.189453125, 390.85668945313, -9902.15625),
			{ Requirement = 1900, Mob = "Jungle Pirate [Lv. 1900]", QuestCheck = "Jungle Pirate" },
			{
				Requirement = 1925,
				Mob = "Musketeer Pirate [Lv. 1925]",
				QuestCheck = "Musketeer Pirate",
			},
			{
				Requirement = 1950,
				Boss = "Beautiful Pirate [Lv. 1950] [Boss]",
				QuestCheck = "Beautiful Pirate",
				Quest = "DeepForestIsland2",
				QuestCFrame = CFrame.new(-12683.189453125, 390.85668945313, -9902.15625),
			},
		},
		[1975] = {
			Quest = "HauntedQuest1",
			QuestCFrame = CFrame.new(-9490.2793, 142.104858, 5565.8501),
			{
				Requirement = 1975,
				Mob = "Reborn Skeleton [Lv. 1975]",
				QuestCheck = "Reborn Skeleton",
			},
			{ Requirement = 2000, Mob = "Living Zombie [Lv. 2000]", QuestCheck = "Living Zombie" },
		},
		[2025] = {
			Quest = "HauntedQuest2",
			QuestCFrame = CFrame.new(-9506.95313, 172.104858, 6074.63086),
			{ Requirement = 2025, Mob = "Demonic Soul [Lv. 2025]", QuestCheck = "Demonic Soul" },
			{ Requirement = 2050, Mob = "Posessed Mummy [Lv. 2050]", QuestCheck = "Posessed Mummy" },
		},
		[2075] = {
			Quest = "NutsIslandQuest",
			QuestCFrame = CFrame.new(-2104.3908691406, 38.104167938232, -10194.21875),
			{ Requirement = 2075, Mob = "Peanut Scout [Lv. 2075]", QuestCheck = "Peanut Scout" },
			{
				Requirement = 2100,
				Mob = "Peanut President [Lv. 2100]",
				QuestCheck = "Peanut President",
			},
		},
		[2125] = {
			Quest = "IceCreamIslandQuest",
			QuestCFrame = CFrame.new(-820.64825439453, 65.819526672363, -10965.795898438),
			{ Requirement = 2125, Mob = "Ice Cream Chef [Lv. 2125]", QuestCheck = "Ice Cream Chef" },
			{
				Requirement = 2150,
				Mob = "Ice Cream Commander [Lv. 2150]",
				QuestCheck = "Ice Cream Commander",
			},
			{
				Requirement = 2175,
				Boss = "Cake Queen [Lv. 2175] [Boss]",
				QuestCheck = "Cake Queen",
				Quest = "IceCreamIslandQuest",
				QuestCFrame = CFrame.new(-820.64825439453, 65.819526672363, -10965.79589843),
			},
		},
		[2200] = {
			Quest = "CakeQuest1",
			QuestCFrame = CFrame.new(-2021.32007, 37.7982254, -12028.7295),
			{ Requirement = 2200, Mob = "Cookie Crafter [Lv. 2200]", QuestCheck = "Cookie Crafter" },
			{ Requirement = 2225, Mob = "Cake Guard [Lv. 2225]", QuestCheck = "Cake Guard" },
			{
				Requirement = 2175,
				Boss = "Cake Queen [Lv. 2175] [Boss]",
				QuestCheck = "Cake Queen",
				Quest = "IceCreamIslandQuest",
				QuestCFrame = CFrame.new(-820.64825439453, 65.819526672363, -10965.79589843),
			},
		},
		[2250] = {
			Quest = "CakeQuest2",
			QuestCFrame = CFrame.new(-1927.91602, 37.7981339, -12842.5391),
			{ Requirement = 2250, Mob = "Baking Staff [Lv. 2250]", QuestCheck = "Baking Staff" },
			{ Requirement = 2275, Mob = "Head Baker [Lv. 2275]", QuestCheck = "Head Baker" },
			{
				Requirement = 2175,
				Boss = "Cake Queen [Lv. 2175] [Boss]",
				QuestCheck = "Cake Queen",
				Quest = "IceCreamIslandQuest",
				QuestCFrame = CFrame.new(-820.64825439453, 65.819526672363, -10965.79589843),
			},
		},
		[2300] = {
			Quest = "ChocQuest1",
			QuestCFrame = CFrame.new(231.23222351074219, 24.734273910522461, -12195.1396484375),
			{ Requirement = 2300, Mob = "Cocoa Warrior [Lv. 2300]", QuestCheck = "Cocoa Warrior" },
			{
				Requirement = 2325,
				Mob = "Chocolate Bar Battler [Lv. 2325]",
				QuestCheck = "Chocolate Bar Battler",
			},
			{
				Requirement = 2175,
				Boss = "Cake Queen [Lv. 2175] [Boss]",
				QuestCheck = "Cake Queen",
				Quest = "IceCreamIslandQuest",
				QuestCFrame = CFrame.new(-820.64825439453, 65.819526672363, -10965.79589843),
			},
		},
		[2350] = {
			Quest = "ChocQuest2",
			QuestCFrame = CFrame.new(148.080322265625, 24.793830871582031, -12775.1650390625),
			{ Requirement = 2350, Mob = "Sweet Thief [Lv. 2350]", QuestCheck = "Sweet Thief" },
			{ Requirement = 2375, Mob = "Candy Rebel [Lv. 2375]", QuestCheck = "Candy Rebel" },
			{
				Requirement = 2175,
				Boss = "Cake Queen [Lv. 2175] [Boss]",
				QuestCheck = "Cake Queen",
				Quest = "IceCreamIslandQuest",
				QuestCFrame = CFrame.new(-820.64825439453, 65.819526672363, -10965.79589843),
			},
		},
		[2400] = {
			Quest = "CandyQuest1",
			QuestCFrame = CFrame.new(-1147.919677734375, 16.107261657714844, -14444.125),
			{ Requirement = 2400, Mob = "Candy Pirate [Lv. 2400]", QuestCheck = "Candy Pirate" },
			{ Requirement = 2425, Mob = "Snow Demon [Lv. 2425]", QuestCheck = "Snow Demon" },
		},
		[2450] = {
			Quest = "TikiQuest1",
			QuestCFrame = CFrame.new(-16548.8164, 55.6059914, -172.8125, 0.213092566, 0, -0.977032006, 0, 1, 0, 0.977032006, 0, 0.213092566),
			{ Requirement = 2450, Mob = "Isle Outlaw [Lv. 2450]", QuestCheck = "Isle Outlaw" },
			{ Requirement = 2475, Mob = "Island Boy [Lv. 2475]", QuestCheck = "Island Boy" },
		},
		[2500] = {
			Quest = "TikiQuest2",
			QuestCFrame = CFrame.new(-16541.0215, 54.770813, 1051.46118, 0.0410757065, 0, -0.999156058, 0, 1, 0, 0.999156058, 0, 0.0410757065),
			{
				Requirement = 2500,
				Mob = "Sun-kissed Warrior [Lv. 2500]",
				QuestCheck = "Sun-kissed Warrior",
			},
			{ Requirement = 2525, Mob = "Isle Champion [Lv. 2525]", QuestCheck = "Isle Champion" },
		},
		[2550] = {
			Quest = "TikiQuest3",
			QuestCFrame = CFrame.new(-16665.1914, 104.596008, 1579.69397, -0.0822139978, 0, 0.996614754, 0, 1, 0, -0.996614754, 0, -0.0822139978),
			{ Requirement = 2550, Mob = "Serpent Hunter [Lv. 2550]", QuestCheck = "Serpent Hunter" },
			{ Requirement = 2575, Mob = "Skull Slayer [Lv. 2575]", QuestCheck = "Skull Slayer" },
		},
		[2600] = {
			Quest = "SubmergedQuest1",
			QuestCFrame = CFrame.new(10778.6904296875, -2087.720458984375, 9261.7314453125),
			{ Requirement = 2600, Mob = "Reef Bandit [Lv. 2600]", QuestCheck = "Reef Bandit" },
			{ Requirement = 2625, Mob = "Coral Pirate [Lv. 2625]", QuestCheck = "Coral Pirate" },
		},
		[2650] = {
			Quest = "SubmergedQuest2",
			QuestCFrame = CFrame.new(10884.7021484375, -2086.197021484375, 10031.9970703125),
			{ Requirement = 2650, Mob = "Sea Chanter [Lv. 2650]", QuestCheck = "Sea Chanter" },
			{ Requirement = 2675, Mob = "Ocean Prophet [Lv. 2675]", QuestCheck = "Ocean Prophet" },
		},
		[2675] = {
			Quest = "SubmergedQuest3",
			QuestCFrame = CFrame.new(9639.4833984375, -1992.4415283203125, 9617.130859375),
			{ Requirement = 2675, Mob = "High Disciple [Lv. 2675]", QuestCheck = "High Disciple" },
			{ Requirement = 2700, Mob = "Grand Devotee [Lv. 2700]", QuestCheck = "Grand Devotee" },
		},
	}

	tbl2.TripleQuest = tripleQuest
end

tbl2.MapPos = {
	["2753915549"] = {
		[0] = { NameIS = "Default", Pos = CFrame.new(977.038269, 16.5166149, 1420.94336) },
		[10] = { NameIS = "Jungle", Pos = CFrame.new(-1332.1394, 11.8529119, 492.35907) },
		[30] = { NameIS = "Pirate", Pos = CFrame.new(-1186.37769, 4.75154591, 3810.49243) },
		[60] = { NameIS = "Desert", Pos = CFrame.new(917.85199, 3.37914562, 4114.66895) },
		[90] = { NameIS = "Ice", Pos = CFrame.new(1107.42444, 7.3035593, -1164.79614) },
		[120] = { NameIS = "MarineBase", Pos = CFrame.new(-4922.20264, 41.2520523, 4424.44434) },
		[150] = { NameIS = "Sky", Pos = CFrame.new(-4916.79346, 717.671265, -2637.03589) },
		[190] = {
			NameIS = "Prison",
			Pos = CFrame.new(4853.1650390625, 5.6526179313659668, 746.67352294921875),
		},
		[250] = { NameIS = "Colosseum", Pos = CFrame.new(-1393.48926, 7.28934002, -2842.57324) },
		[300] = { NameIS = "Magma", Pos = CFrame.new(-5226.26416, 8.59022045, 8472.14844) },
		[375] = { NameIS = "Sky", Pos = CFrame.new(-4916.79346, 717.671265, -2637.03589) },
		[450] = { NameIS = "Sky2", Pos = CFrame.new(-7873.7959, 5545.49316, -335.85321) },
		[625] = { NameIS = "Fountain", Pos = CFrame.new(5187.77197, 38.5011406, 4141.60791) },
	},
	["4442272183"] = {
		[700] = { NameIS = "Default", Pos = CFrame.new(-32.1582031, 29.2783928, 2766.5874) },
		[775] = { NameIS = "DressTown", Pos = CFrame.new(-389.968658, 72.9961472, 1148.09241) },
		[875] = { NameIS = "Greenb", Pos = CFrame.new(-2220.05884, 72.967804, -2709.98462) },
		[950] = { NameIS = "Graveyard", Pos = CFrame.new(-5386.68799, 8.97076797, -713.903381) },
		[1000] = { NameIS = "Snowy", Pos = CFrame.new(394.089142, 401.423676, -5313.98486) },
		[1100] = { NameIS = "CircleIslandIce", Pos = CFrame.new(-5852.72803, 18.316433, -5030.0752) },
		[1250] = { NameIS = "Ship", Pos = CFrame.new(864.63134765625, 125.05711364746094, 32858.4609375) },
		[1350] = { NameIS = "IceCastle", Pos = CFrame.new(5573.96826, 28.1925011, -6111.41455) },
		[1425] = { NameIS = "ForgottenIsland", Pos = CFrame.new(-3066.82715, 236.847992, -10159.6846) },
	},
	["7449423635"] = {
		[1500] = {
			NameIS = "Default",
			Pos = CFrame.new(-346.92642211914062, 29.412704467773438, 5377.86376953125),
		},
		[1575] = { NameIS = "Hydra3", Pos = CFrame.new(4727.12988, 51.453064, -1401.72839) },
		[1625] = { NameIS = "Hydra1", Pos = CFrame.new(5264.06396, 602.526245, 353.749878) },
		[1700] = { NameIS = "GreatTree", Pos = CFrame.new(2260.66162, 25.852705, -6416.6084) },
		[1775] = { NameIS = "BigMansion", Pos = CFrame.new(-12550.4844, 337.168365, -7425.26855) },
		[1900] = { NameIS = "PineappleTown", Pos = CFrame.new(-11374.4658, 331.723297, -10390.6523) },
		[1975] = { NameIS = "HauntedCastle", Pos = CFrame.new(-9540.20898, 142.104858, 5537.26318) },
		[2075] = { NameIS = "Peanut", Pos = CFrame.new(-2074.8999023438, 38.104068756104, -10210.8320312) },
		[2150] = {
			NameIS = "IceCream",
			Pos = CFrame.new(-910.46862792969, 58.945728302002, -10889.098632812),
		},
		[2225] = {
			NameIS = "Loaf",
			Pos = CFrame.new(-1895.603271484375, 37.798137664794922, -11885.45703125),
		},
		[2300] = {
			NameIS = "Chocolate",
			Pos = CFrame.new(501.06365966796875, 24.734277725219727, -12431.494140625),
		},
		[2400] = {
			NameIS = "CandyCane",
			Pos = CFrame.new(-1060.913818359375, 16.107261657714844, -14178.02734375),
		},
		[2450] = { NameIS = "Tiki", Pos = CFrame.new(-16256.5566, 9.06057358, 430.995422) },
		[2600] = { NameIS = "Submerged", Pos = CFrame.new(10884, -2086, 10031) },
	},
}

tbl2.SpawnPosition = {}

tbl2.Items = {
	Abilities = {
		{ Name = "Geppo", Args = { "BuyHaki", "Geppo" }, Price = { Beli = 10000 } },
		{ Name = "Buso", Args = { "BuyHaki", "Buso" }, Price = { Beli = 25000 } },
		{ Name = "Soru", Args = { "BuyHaki", "Soru" }, Price = { Beli = 100000 } },
		{ Name = "Ken", Args = { "KenTalk", "Buy" }, Price = { Beli = 150000 } },
	},
	["Fighting Styles"] = {
		{ Name = "Dark Step", Args = { "BuyBlackLeg" }, Price = { Beli = 150000 } },
		{ Name = "Eletro", Args = { "BuyElectro" }, Price = { Beli = 500000 } },
		{ Name = "Water Kung Fu", Args = { "BuyFishmanKarate" }, Price = { Beli = 750000 } },
		{
			Name = "Dragon Breath",
			Args = { "BlackbeardReward", "DragonClaw", "2" },
			Price = { Fragment = 1500 },
		},
		{ Name = "Superhuman", Args = { "BuySuperhuman" }, Price = { Beli = 3000000 } },
		{
			Name = "Death Step",
			Args = { "BuyDeathStep" },
			Price = { Beli = 2500000, Fragment = 5000 },
		},
		{
			Name = "Sharkman Karate",
			Args = { "BuySharkmanKarate" },
			Price = { Beli = 2500000, Fragment = 5000 },
		},
		{
			Name = "Eletric Claw",
			Args = { "BuyElectricClaw" },
			Price = { Beli = 3000000, Fragment = 5000 },
		},
		{
			Name = "Dragon Talon",
			Args = { "BuyDragonTalon" },
			Price = { Beli = 3000000, Fragment = 5000 },
		},
		{
			Name = "God Human",
			Args = { "BuyGodhuman" },
			Price = { Beli = 5000000, Fragment = 5000 },
		},
		{
			Name = "Saguine Art",
			Args = { "BuySanguineArt" },
			Price = { Beli = 500000, Fragment = 5000 },
		},
	},
	Sword = {
		{ Name = "Katana", Args = { "BuyItem", "Katana" }, Price = { Beli = 1000 } },
		{ Name = "Cutlass", Args = { "BuyItem", "Cutlass" }, Price = { Beli = 1000 } },
		{ Name = "Dual Katana", Args = { "BuyItem", "Dual Katana" }, Price = { Beli = 12000 } },
		{ Name = "Iron Mace", Args = { "BuyItem", "Iron Mace" }, Price = { Beli = 25000 } },
		{ Name = "Triple Katana", Args = { "BuyItem", "Triple Katana" }, Price = { Beli = 60000 } },
		{ Name = "Pipe", Args = { "BuyItem", "Pipe" }, Price = { Beli = 100000 } },
		{
			Name = "Dual-Headed Blade",
			Args = { "BuyItem", "Dual-Headed Blade" },
			Price = { Beli = 400000 },
		},
		{ Name = "Bisento", Args = { "BuyItem", "Bisento" }, Price = { Beli = 1000000 } },
		{ Name = "Soul Cane", Args = { "BuyItem", "Soul Cane" }, Price = { Beli = 750000 } },
		{ Name = "Midnight Blade", Args = { "Ectoplasm", "Buy", 3 }, Price = { Ectoplasm = 100 } },
		{ Name = "True Triple Katana", Args = { "MysteriousMan", 2 }, Price = {} },
	},
	Gun = {
		{ Name = "Slingshot", Args = { "BuyItem", "Slingshot" }, Price = { Beli = 5000 } },
		{ Name = "Musket", Args = { "BuyItem", "Musket" }, Price = { Beli = 8000 } },
		{ Name = "Flintlock", Args = { "BuyItem", "Flintlock" }, Price = { Beli = 10500 } },
		{
			Name = "Refined Slingshot",
			Args = { "BuyItem", "Refined Slingshot" },
			Price = { Beli = 65000 },
		},
		{ Name = "Cannon", Args = { "BuyItem", "Cannon" }, Price = { Beli = 100000 } },
		{
			Name = "Kabucha",
			Args = { "BlackbeardReward", "Slingshot", "2" },
			Price = { Fragment = 1500 },
		},
		{ Name = "Bizarre Rifle", Args = { "Ectoplasm", "Buy", 1 }, Price = { Ectoplasm = 25 } },
	},
	Accessories = {
		{ Name = "Black Cape", Args = { "BuyItem", "Black Cape" }, Price = { Beli = 50000 } },
		{ Name = "Swordsman Hat", Args = { "BuyItem", "Swordsman Hat" }, Price = { Beli = 150000 } },
		{ Name = "Tomoe Ring", Args = { "BuyItem", "Tomoe Ring" }, Price = { Beli = 500000 } },
		{ Name = "Ghoul Mask", Args = { "Ectoplasm", "Buy", 2 }, Price = { Ectoplasm = 50 } },
	},
}

tbl2.Items = {
	{
		Abilities = {
			{ Name = "Geppo", Args = { "BuyHaki", "Geppo" }, Price = { Beli = 10000 } },
			{ Name = "Buso", Args = { "BuyHaki", "Buso" }, Price = { Beli = 25000 } },
			{ Name = "Soru", Args = { "BuyHaki", "Soru" }, Price = { Beli = 100000 } },
			{ Name = "Ken", Args = { "KenTalk", "Buy" }, Price = { Beli = 150000 } },
		},
	},
	{
		["Fighting Styles"] = {
			{ Name = "Dark Step", Args = { "BuyBlackLeg" }, Price = { Beli = 150000 } },
			{ Name = "Eletro", Args = { "BuyElectro" }, Price = { Beli = 500000 } },
			{ Name = "Water Kung Fu", Args = { "BuyFishmanKarate" }, Price = { Beli = 750000 } },
			{
				Name = "Dragon Breath",
				Args = { "BlackbeardReward", "DragonClaw", "2" },
				Price = { Fragment = 1500 },
			},
			{ Name = "Superhuman", Args = { "BuySuperhuman" }, Price = { Beli = 3000000 } },
			{
				Name = "Death Step",
				Args = { "BuyDeathStep" },
				Price = { Beli = 2500000, Fragment = 5000 },
			},
			{
				Name = "Sharkman Karate",
				Args = { "BuySharkmanKarate" },
				Price = { Beli = 2500000, Fragment = 5000 },
			},
			{
				Name = "Eletric Claw",
				Args = { "BuyElectricClaw" },
				Price = { Beli = 3000000, Fragment = 5000 },
			},
			{
				Name = "Dragon Talon",
				Args = { "BuyDragonTalon" },
				Price = { Beli = 3000000, Fragment = 5000 },
			},
			{
				Name = "God Human",
				Args = { "BuyGodhuman" },
				Price = { Beli = 5000000, Fragment = 5000 },
			},
			{
				Name = "Saguine Art",
				Args = { "BuySanguineArt" },
				Price = { Beli = 500000, Fragment = 5000 },
			},
		},
	},
	{
		Sword = {
			{ Name = "Katana", Args = { "BuyItem", "Katana" }, Price = { Beli = 1000 } },
			{ Name = "Cutlass", Args = { "BuyItem", "Cutlass" }, Price = { Beli = 1000 } },
			{ Name = "Dual Katana", Args = { "BuyItem", "Dual Katana" }, Price = { Beli = 12000 } },
			{ Name = "Iron Mace", Args = { "BuyItem", "Iron Mace" }, Price = { Beli = 25000 } },
			{
				Name = "Triple Katana",
				Args = { "BuyItem", "Triple Katana" },
				Price = { Beli = 60000 },
			},
			{ Name = "Pipe", Args = { "BuyItem", "Pipe" }, Price = { Beli = 100000 } },
			{
				Name = "Dual-Headed Blade",
				Args = { "BuyItem", "Dual-Headed Blade" },
				Price = { Beli = 400000 },
			},
			{ Name = "Bisento", Args = { "BuyItem", "Bisento" }, Price = { Beli = 1000000 } },
			{ Name = "Soul Cane", Args = { "BuyItem", "Soul Cane" }, Price = { Beli = 750000 } },
			{
				Name = "Midnight Blade",
				Args = { "Ectoplasm", "Buy", 3 },
				Price = { Ectoplasm = 100 },
			},
			{ Name = "True Triple Katana", Args = { "MysteriousMan", 2 }, Price = {} },
		},
	},
	{
		Gun = {
			{ Name = "Slingshot", Args = { "BuyItem", "Slingshot" }, Price = { Beli = 5000 } },
			{ Name = "Musket", Args = { "BuyItem", "Musket" }, Price = { Beli = 8000 } },
			{ Name = "Flintlock", Args = { "BuyItem", "Flintlock" }, Price = { Beli = 10500 } },
			{
				Name = "Refined Slingshot",
				Args = { "BuyItem", "Refined Slingshot" },
				Price = { Beli = 65000 },
			},
			{ Name = "Cannon", Args = { "BuyItem", "Cannon" }, Price = { Beli = 100000 } },
			{
				Name = "Kabucha",
				Args = { "BlackbeardReward", "Slingshot", "2" },
				Price = { Fragment = 1500 },
			},
			{ Name = "Bizarre Rifle", Args = { "Ectoplasm", "Buy", 1 }, Price = { Ectoplasm = 25 } },
		},
	},
	{
		Accessories = {
			{ Name = "Black Cape", Args = { "BuyItem", "Black Cape" }, Price = { Beli = 50000 } },
			{
				Name = "Swordsman Hat",
				Args = { "BuyItem", "Swordsman Hat" },
				Price = { Beli = 150000 },
			},
			{ Name = "Tomoe Ring", Args = { "BuyItem", "Tomoe Ring" }, Price = { Beli = 500000 } },
			{ Name = "Ghoul Mask", Args = { "Ectoplasm", "Buy", 2 }, Price = { Ectoplasm = 50 } },
		},
	},
}

tbl2.Material = {}

do
	local materialFarm = {}
	local cframe = CFrame.new

	local checkMob = {
		["Magma Ore"] = {
			IsMob = function(arg)
				if Sea1 then
					if string.match(arg.Name, "Military Soldier") or string.match(arg.Name, "Military Spy") then
						return true
					end
				elseif Sea2 then
					if string.match(arg.Name, "Magma Ninja") or string.match(arg.Name, "Lava Pirate") then
						return true
					end
				end

				return false
			end,
			Pos = {
				CFrame.new(-5458.927734375, 22.050642013549805, -5419.67724609375),
				cframe(-5377.33251953125, 18.274900436401367, -5125.76416015625),
			},
		},
		Ectoplasm = {
			IsMob = function(arg)
				if string.match(arg.Name, "Ship Deckhand") or string.match(arg.Name, "Ship Engineer") or string.match(arg.Name, "Ship Steward") or string.match(arg.Name, "Ship Officer") then
					return true
				end
				return false
			end,
			Pos = CFrame.new(923.2125244140625, 126.97600555419922, 32852.83203125),
		},
		["Demonic Wisp"] = {
			IsMob = function(arg)
				if (string.match(arg.Name, "Reborn Skeleton") or string.match(arg.Name, "Living Zombie") or string.match(arg.Name, "Demonic Soul") or string.match(arg.Name, "Posessed Mummy")) and arg:FindFirstChild("HumanoidRootPart") and (arg:FindFirstChild("HumanoidRootPart").Position - Vector3.new(-8736.577, 143.10483, 6034.9375)).magnitude < 3500 then
					return true
				end
				return false
			end,
			Pos = CFrame.new(-9501.3447265625, 172.13984680175781, 6036.0341796875),
		},
		Bones = {
			IsMob = function(arg)
				if (string.match(arg.Name, "Reborn Skeleton") or string.match(arg.Name, "Living Zombie") or string.match(arg.Name, "Demonic Soul") or string.match(arg.Name, "Posessed Mummy")) and arg:FindFirstChild("HumanoidRootPart") and (arg:FindFirstChild("HumanoidRootPart").Position - Vector3.new(-8736.577, 143.10483, 6034.9375)).magnitude < 3500 then
					return true
				end
				return false
			end,
			Pos = CFrame.new(-9501.3447265625, 172.13984680175781, 6036.0341796875),
		},
	}

	local tbl3 = { IsMob = function(arg)
		if string.match(arg.Name, "Dragon Crew Archer") or string.match(arg.Name, "Dragon Crew Warrior") then
			return true
		end
		return false
	end }

	local pos = {}
	local cframe2 = CFrame.new(6562.64111328125, 148.20350646972656, -712.18548583984375)
	local cframe3 = CFrame.new(6525.68896484375, 378.20541381835938, 16.124660491943359)
	local cframe4 = CFrame.new
	pos[1] = cframe2
	pos[2] = cframe3

	do
		local values = table.pack(cframe4(4143.9814453125, 51.481880187988281, -1238.462890625))
		table.move(values, 1, values.n, 3, pos)
	end

	tbl3.Pos = pos
	checkMob["Dragon Scale"] = tbl3
	local cframe5 = CFrame.new

	checkMob["Angel Wings"] = {
		IsMob = function(arg)
			if string.match(arg.Name, "Shanda") or string.match(arg.Name, "Royal Squad") or string.match(arg.Name, "Royal Soldier") then
				return true
			end
			return false
		end,
		Pos = {
			CFrame.new(-7640.81103515625, 5545.49169921875, -535.966064453125),
			cframe5(-7760.857421875, 5634.2216796875, -1555.6251220703125),
		},
	}

	checkMob["Mystic Droplet"] = {
		IsMob = function(arg)
			if string.match(arg.Name, "Sea Soldier") or string.match(arg.Name, "Water Fighter") then
				return true
			end
			return false
		end,
		Pos = CFrame.new(-3246.47509765625, 298.66448974609375, -10551.6650390625),
	}

	checkMob["Fish Tail"] = {
		IsMob = function(arg)
			if Sea3 then
				if string.match(arg.Name, "Fishman Raider") or string.match(arg.Name, "Fishman Captain") then
					return true
				end
			end

			return false
		end,
		Pos = CFrame.new(-10918.5673828125, 331.76263427734375, -8698.3408203125),
	}

	local cframe6 = CFrame.new

	checkMob["Radioactive Material"] = {
		IsMob = function(arg)
			if Sea2 then
				if string.match(arg.Name, "Factory Staff") then
					return true
				end
			end

			return false
		end,
		Pos = {
			CFrame.new(-16.391239166259766, 148.9493408203125, -182.66398620605469),
			cframe6(542.0455322265625, 72.959762573242188, 22.46308708190918),
		},
	}

	checkMob["Vampire Fang"] = {
		IsMob = function(arg)
			if Sea2 then
				if string.match(arg.Name, "Vampire") then
					return true
				end
			end

			return false
		end,
		Pos = CFrame.new(-6022.30810546875, 6.4027113914489746, -1302.591552734375),
	}

	checkMob["Conjured Cocoa"] = {
		IsMob = function(arg)
			if Sea3 then
				if string.match(arg.Name, "Sweet Thief") or string.match(arg.Name, "Candy Rebel") or string.match(arg.Name, "Chocolate Bar Battler") or string.match(arg.Name, "Cocoa Warrior") then
					return true
				end
			end

			return false
		end,
		Pos = CFrame.new(233.32058715820312, 74.747642517089844, -12498.2861328125),
	}

	checkMob["Mini Tusk"] = {
		IsMob = function(arg)
			if Sea3 then
				if string.match(arg.Name, "Forest Pirate") or string.match(arg.Name, "Mythological Pirate") then
					return true
				end
			end

			return false
		end,
		Pos = CFrame.new(-13527.8076171875, 523.63446044921875, -7424.10693359375),
	}

	local tbl4 = { IsMob = function(arg)
		if Sea3 then
			if string.match(arg.Name, "Pirate Millionaire") or string.match(arg.Name, "Pistol Billionaire") then
				return true
			end
		end

		return false
	end }

	local pos2 = {}
	local cframe7 = CFrame.new(-315.9371337890625, 73.870437622070312, 5939.98193359375)
	local cframe8 = CFrame.new(-289.22113037109375, 43.854217529296875, 5574.4697265625)
	local cframe9 = CFrame.new(-636.85888671875, 57.015052795410156, 5626.41748046875)
	local cframe10 = CFrame.new
	pos2[1] = cframe7
	pos2[2] = cframe8
	pos2[3] = cframe9

	do
		local values = table.pack(cframe10(-807.3641357421875, 84.812889099121094, 5991.45166015625))
		table.move(values, 1, values.n, 4, pos2)
	end

	tbl4.Pos = pos2
	checkMob["Scrap Metal"] = tbl4
	local cframe11 = CFrame.new

	checkMob.Leather = {
		IsMob = function(arg)
			if Sea3 then
				if string.match(arg.Name, "Pirate Millionaire") or string.match(arg.Name, "Pistol Billionaire") then
					return true
				end
			end

			return false
		end,
		Pos = {
			CFrame.new(-315.9371337890625, 73.870437622070312, 5939.98193359375),
			cframe11(-289.22113037109375, 43.854217529296875, 5574.4697265625),
		},
	}

	materialFarm.CheckMob = checkMob

	materialFarm.CheckBoss = {
		"Meteorite",
		Meteorite = { IsBoss = function()
			if Sea2 then
				if game.Workspace.Enemies:FindFirstChild("Orbitus") or game.Workspace.Enemies:FindFirstChild("Fajita") then
					return game.Workspace.Enemies:FindFirstChild("Orbitus") or game.Workspace.Enemies:FindFirstChild("Fajita")
				end
			end

			return false
		end },
	}

	tbl2.MaterialFarm = materialFarm
end

tbl2.MaterialName = {
	"Mystic Droplet",
	"Magma Ore",
	"Fish Tail",
	"Vampire Fang",
	"Dragon Scale",
	"Radioactive Material",
	"Conjured Cocoa",
	"Ectoplasm",
	"Mini Tusk",
	"Demonic Wisp",
	"Meteorite",
	"Angel Wings",
	"Scrap Metal",
	"Leather",
}

tbl2.MaterialSeaChecker = {
	Leather = "7449423635",
	["Scrap Metal"] = "7449423635",
	["Mystic Droplet"] = "4442272183",
	["Magma Ore"] = "4442272183",
	Ectoplasm = "4442272183",
	Bones = "7449423635",
	["Demonic Wisp"] = "7449423635",
	["Fish Tail"] = "7449423635",
	["Dragon Scale"] = "7449423635",
	["Radioactive Material"] = "4442272183",
	["Mini Tusk"] = "7449423635",
	["Vampire Fang"] = "4442272183",
	Meteorite = "4442272183",
	["Conjured Cocoa"] = "7449423635",
	["Angel Wings"] = "2753915549",
}

local lib
lib = nil

do
	local lib2 = nil
	local n2 = 0

	task.spawn(function()
		lib = loadstring(game:HttpGet("https://raw.githubusercontent.com/hoannhatz/backup/refs/heads/main/Fluent_fixed.lua"))()
		getgenv().Fluent = lib
		n2 += 1
	end)

	local function fn3()
		while true do
			wait()
			if not (getgenv().LoadUi and getgenv().IslandCaller and getgenv().SettingManager and getgenv().Fluent) then
				continue
			end
			break
		end

		local fluent = getgenv().Fluent
		local options = fluent.Options
		local islandCaller = IslandCaller or getgenv().IslandCaller
		local settingManager = getgenv().SettingManager

		if not getgenv().Window then
			local createWindow = fluent.CreateWindow

			getgenv().Window = createWindow(fluent, {
				Title = "One Click",
				SubTitle = "@_teddyhub [discord.gg/YYeRQnhQH5]",
				TabWidth = 160,
				Size = UDim2.fromOffset(480, 360),
				Acrylic = false,
				Theme = "Dark",
				MinimizeKey = Enum.KeyCode.LeftControl,
			})
		end

		local window = getgenv().Window
		local tbl3 = { "Status", "Setting", "Game-Server", "One Click", "One Click Debugger" }
		local tbl4 = {}
		ElementsCollection = {}

		for _, v in pairs(tbl3) do
			ElementsCollection[v] = {}
		end

		local tbl5 = {
			Status = {
				{ Mode = "Label", Title = "Client Time" },
				{ Mode = "Label", Title = "Farming Status" },
				{ Mode = "Label", Title = "Weapon Status [One Click]" },
				{ Mode = "Label", Title = "Dimension Kill" },
				{ Mode = "Label", Title = "Server Haki Color" },
				{ Mode = "Label", Title = "Elite Status" },
				{ Mode = "Label", Title = "Mirage Status" },
				{ Mode = "Label", Title = "FullMoon Status" },
				{ Mode = "Label", Title = "Eyes" },
			},
		}

		local setting = {}
		local tbl6 = { Mode = "Label", Title = "Tween Section" }

		local function fn4()
			local tbl7 = { 150, 180, 195, 220, 250, 275, 300, 325, 350 }

			if not table.find(tbl7, getgenv().Setting.Tween.Speed) or getgenv().Setting.Tween.Speed == 195 or getgenv().Setting.Tween.Speed == 250 or getgenv().Setting.Tween.Speed == 300 then
				getgenv().Setting.Tween.Speed = 150
			end

			return table.find(tbl7, getgenv().Setting.Tween.Speed) or 1
		end

		local tbl7 = {
			Mode = "Dropdown",
			Title = "Tween Speed",
			Args = { "Tween", "Speed" },
			Table = { 150, 180, 195, 220, 250, 275, 300, 325, 350 },
			Default = fn4(),
			OnChange = function(arg)
				getgenv().Setting.Tween.Speed = tonumber(arg)
				settingManager:Save()
			end,
		}

		local tbl8 = {
			Mode = "Toggle",
			Title = "Tween Pause",
			Description = "Prevent Security Kick",
			Args = { "Tween", "Pause" },
			OnChange = function(pause)
				getgenv().Setting.Tween.Pause = pause
				settingManager:Save()
			end,
		}

		local tbl9 = { Mode = "Label", Title = "Bring Mob Section" }

		local tbl10 = {
			Mode = "Toggle",
			Title = "Bring Mob",
			Description = "Not Recommended May Error But Works If in PS",
			Args = { "BringMob", "Enable" },
			OnChange = function(enable)
				getgenv().Setting.BringMob.Enable = enable
				settingManager:Save()
			end,
		}

		local tbl11 = {
			Mode = "Slider",
			Title = "Bring Mob Radius",
			Args = { "BringMob", "Radius" },
			Default = getgenv().Setting.BringMob.Radius or 200,
			Min = 200,
			Max = 500,
			OnChange = function(radius)
				getgenv().Setting.BringMob.Radius = radius
				settingManager:Save()
			end,
		}

		local function fn5()
			local tbl12 = {}

			for _, v in pairs({ "X", "Y", "Z" }) do
				table.insert(tbl12, {
					Mode = "Slider",
					Title = "Position " .. v,
					Args = { "Mastery", v },
					Default = getgenv().Setting.Mastery[v] or v == "Y" and 30 or 0,
					Min = 0,
					Max = 60,
					OnChange = function(arg)
						getgenv().Setting.Mastery[v] = arg
						settingManager:Save()
					end,
				})
			end

			return tbl12
		end

		local function fn6()
			local tbl12 = {}

			for k in pairs(getgenv().Setting.SkillsSet2) do
				if type(k) == "string" then
					table.insert(tbl12, k)
				end
			end

			return tbl12
		end

		local tbl12 = {
			Mode = "Dropdown",
			Title = "Weapon For Sea Events",
			Multi = true,
			Table = { "Melee", "Blox Fruit", "Sword", "Gun" },
			Default = fn6(),
			OnChange = function(arg)
				local skillsSet2 = {}

				for k, v in pairs(arg) do
					if type(k) == "string" then
						skillsSet2[k] = v
					end
				end

				getgenv().Setting.SkillsSet2 = skillsSet2
				settingManager:Save()
			end,
		}

		local tbl13 = {
			Mode = "Dropdown",
			Title = "Skills For fruit",
			Multi = true,
			Table = { "Z", "X", "C", "V", "F" },
			Default = getgenv().Setting.SkillsSettingRemake["Blox Fruit"],
			OnChange = function(arg)
				local tbl13 = {}

				for k in pairs(arg) do
					if type(k) == "string" then
						table.insert(tbl13, k)
					end
				end

				getgenv().Setting.SkillsSettingRemake["Blox Fruit"] = tbl13
				settingManager:Save()
			end,
		}

		local function fn7()
			local tbl14 = {}

			for _, v in pairs({ "Z", "X", "C", "V", "F" }) do
				local function fn8()
					local tbl15 = { 0, 0.25, 0.5, 1, 2, 3 }
					local n3

					if not table.find(tbl15, getgenv().Setting.FruitSkillsHold[v]) then
						getgenv().Setting.FruitSkillsHold[v] = 0
						n3 = 1
					else
						n3 = table.find(tbl15, getgenv().Setting.FruitSkillsHold[v])
					end

					return n3
				end

				table.insert(tbl14, {
					Mode = "Dropdown",
					Title = "Hold Time " .. v,
					Args = { "FruitSkillsHold", v },
					Table = { 0, 0.25, 0.5, 1, 2, 3 },
					Default = fn8(),
					OnChange = function(arg)
						local v2 = v
						getgenv().Setting.FruitSkillsHold[v2] = tonumber(arg)
						settingManager:Save()
					end,
				})
			end

			return tbl14
		end

		setting[1] = tbl6
		setting[2] = tbl7
		setting[3] = tbl8
		setting[4] = tbl9
		setting[5] = tbl10
		setting[6] = tbl11
		setting[7] = { Mode = "Label", Title = "Fast Attack Section" }

		setting[8] = {
			Mode = "Toggle",
			Title = "Fast Attack",
			Args = { "FastAttack", "Enable" },
			OnChange = function(enable)
				getgenv().Setting.FastAttack.Enable = enable
				settingManager:Save()
			end,
		}

		setting[9] = {
			Mode = "Toggle",
			Title = "On Player",
			Description = "Fast Attack On Player",
			Args = { "FastAttack", "OnPlayer" },
			OnChange = function(onPlayer)
				getgenv().Setting.FastAttack.OnPlayer = onPlayer
				settingManager:Save()
			end,
		}

		setting[10] = {
			Mode = "Toggle",
			Title = "On Mob",
			Description = "Fast Attack On Mob",
			Args = { "FastAttack", "OnMob" },
			OnChange = function(onMob)
				getgenv().Setting.FastAttack.OnMob = onMob
				settingManager:Save()
			end,
		}

		setting[11] = { Mode = "Label", Title = "Mastery Position" }
		setting[12] = fn5
		setting[13] = tbl12
		setting[14] = { Mode = "Label", Title = "Fruit Skills Setting" }

		setting[15] = {
			Mode = "Toggle",
			Title = "Use Dragonstorm",
			Description = "",
			Args = { "UseDragonStorm" },
			OnChange = function(useDragonStorm)
				getgenv().Setting.UseDragonStorm = useDragonStorm
				settingManager:Save()
			end,
		}

		setting[16] = tbl13
		setting[17] = fn7
		tbl5.Setting = setting

		tbl5["Game-Server"] = {
			{
				Mode = "Button",
				Title = "Copy Job Id",
				Callback = function()
					setclipboard(tostring(game.JobId))
				end,
			},
			{
				Mode = "Button",
				Title = "Clear Server Code",
				Callback = function()
					local ok, result = pcall(function()
						ElementsCollection["Game-Server"]["Server Code [Premium]"]:SetValue("")
					end)

					if result then
						print(result)
					end
				end,
			},
			{
				Mode = "TextBox",
				Title = "Job Id",
				Callback = function(arg)
					pcall(function()
						if arg ~= "" then
							game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", arg)
						end
					end)
				end,
			},
			{
				Mode = "Button",
				Title = "Clear Job Id",
				Callback = function()
					local ok, result = pcall(function()
						ElementsCollection["Game-Server"]["Job Id"]:SetValue("")
					end)

					if result then
						print(result)
					end
				end,
			},
			{
				Mode = "Toggle",
				Title = "No Fog",
				Description = "For Better Vision",
				Args = { "Misc", "__NoFog" },
				OnChange = function(noFog)
					getgenv().Setting.Misc.__NoFog = noFog
					settingManager:Save()
				end,
			},
			{
				Mode = "Toggle",
				Title = "Remove Effect (Fluxus Only)",
				Description = "Disable And Rejoin To Get The Effect Back If You Want Effects",
				Args = { "Misc", "__RemoveEffects" },
				OnChange = function(removeEffects)
					getgenv().Setting.Misc.__RemoveEffects = removeEffects
					settingManager:Save()
				end,
			},
			{
				Mode = "Toggle",
				Title = "Disable 3D Render",
				Args = { "Misc", "DisableRender3D" },
				OnChange = function(disableRender3D)
					getgenv().Setting.Misc.DisableRender3D = disableRender3D
					settingManager:Save()
				end,
			},
			{
				Mode = "Toggle",
				Title = "Disable Notifications",
				Args = { "Misc", "__RemoveNotification" },
				OnChange = function(removeNotification)
					getgenv().Setting.Misc.__RemoveNotification = removeNotification
					settingManager:Save()
				end,
			},
			{
				Mode = "Toggle",
				Title = "Disable DMG Counter",
				Args = { "Misc", "__RemoveDMGCounter" },
				OnChange = function(removeDMGCounter)
					getgenv().Setting.Misc.__RemoveDMGCounter = removeDMGCounter
					settingManager:Save()
				end,
			},
			{
				Mode = "Button",
				Title = "Server Hop",
				Callback = function()
					islandCaller("TrueServerHop")
				end,
			},
			{
				Mode = "Button",
				Title = "Low Player Server Hop",
				Callback = function()
					islandCaller("TrueServerHop", 1, 3)
				end,
			},
			{
				Mode = "Button",
				Title = "Rejoin",
				Callback = function()
					game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", game.JobId)
				end,
			},
		}

		tbl5["One Click"] = {
			{
				Mode = "Toggle",
				Title = "Start One Click",
				Description = "Do Not Farm Levels Too Fast Or Enjoy Getting Reseted",
				Args = { "OneClick", "Enable" },
				OnChange = function(enable)
					getgenv().Setting.OneClick.Enable = enable
					settingManager:Save()
				end,
			},
			{
				Mode = "Toggle",
				Title = "Remove limit 1 Minute Get Quest",
				Description = "Turn This On = Farm Faster But May Get Reseted",
				Args = { "OneClick", "UnlimitGetQuest" },
				OnChange = function(unlimitGetQuest)
					getgenv().Setting.OneClick.UnlimitGetQuest = unlimitGetQuest
					settingManager:Save()
				end,
			},
			{
				Mode = "Toggle",
				Title = "Triple Quests",
				Description = "Only use this if you only farm for a while or get reseted",
				Args = { "OneClick", "TripleQuest" },
				OnChange = function(tripleQuest)
					getgenv().Setting.OneClick.TripleQuest = tripleQuest
					settingManager:Save()
				end,
			},
			{
				Mode = "Toggle",
				Title = "Auto Add Stats",
				Description = "Melee -> Health, The Last One You Chose",
				Args = { "OneClick", "AutoAddStats" },
				OnChange = function(autoAddStats)
					getgenv().Setting.OneClick.AutoAddStats = autoAddStats
					settingManager:Save()
				end,
			},
			{
				Mode = "Toggle",
				Title = "Disable Melees Switcher",
				Description = "Melees Switcher Is For God Human, Turn Off If You Only Want To Farm A Melee",
				Args = { "OneClick", "DisableMeleeSwitcher" },
				OnChange = function(disableMeleeSwitcher)
					getgenv().Setting.OneClick.DisableMeleeSwitcher = disableMeleeSwitcher
					settingManager:Save()
				end,
			},
			{
				Mode = "Toggle",
				Title = "Farms All Melee 600 Mastery",
				Description = "Melee -> Health, The Last One You Chose",
				Args = { "OneClick", "Melee600Mastery" },
				OnChange = function(melee600Mastery)
					getgenv().Setting.OneClick.Melee600Mastery = melee600Mastery
					settingManager:Save()
				end,
			},
			{
				Mode = "Toggle",
				Title = "Hop For Library Key / Water Key",
				Description = "",
				Args = { "OneClick", "Sea2KeyHop" },
				OnChange = function(sea2KeyHop)
					getgenv().Setting.OneClick.Sea2KeyHop = sea2KeyHop
					settingManager:Save()
				end,
			},
			{
				Mode = "Button",
				Title = "Redeem All Codes",
				Callback = function()
					islandCaller("RedeemAllCode")
				end,
			},
		}

		tbl5["One Click Debugger"] = {
			{ Mode = "Label", Title = "God Human Progress" },
			{ Mode = "Label", Title = "Raid" },
			{ Mode = "Label", Title = "Spawn Rip Indra" },
			{ Mode = "Label", Title = "Unlock Sea 2" },
			{ Mode = "Label", Title = "Unlock Sea 3" },
			{ Mode = "Label", Title = "Travel Sea 3" },
		}

		print("Building Ui")

		local function fn8(arg, arg2, arg3, arg4)
			if arg3.Mode == "Toggle" then
				local setting2 = getgenv().Setting
				local args = arg3.Args

				for i = 1, #args - 1 do
					setting2 = setting2[args[i]]
				end

				local tbl14 = { Title = arg3.Title, Default = setting2[args[#args]] }

				if arg3.Description then
					tbl14.Description = arg3.Description
				end

				ElementsCollection[arg4][arg3.Title] = arg:AddToggle(arg3.Title, tbl14)

				ElementsCollection[arg4][arg3.Title]:OnChanged(function()
					setting2[args[#args]] = options[arg3.Title].Value

					if not arg3.NoSave then
						settingManager:Save()
					end
				end)
			elseif arg3.Mode == "Label" then
				local tbl14 = { Title = arg3.Title }

				if arg3.Content then
					tbl14.Content = arg3.Content
				end

				ElementsCollection[arg4][arg3.Title] = arg:AddParagraph(tbl14)
			elseif arg3.Mode == "Button" then
				local tbl14 = { Title = arg3.Title, Callback = arg3.Callback }

				if arg3.Description then
					tbl14.Description = arg3.Description
				end

				ElementsCollection[arg4][arg3.Title] = arg:AddButton(tbl14)
			elseif arg3.Mode == "Slider" then
				local tbl14 = { Title = arg3.Title }

				if arg3.Description then
					tbl14.Description = arg3.Description
				end

				if arg3.Default then
					tbl14.Default = arg3.Default
				end

				tbl14.Min = arg3.Min
				tbl14.Max = arg3.Max
				tbl14.Rounding = 1
				ElementsCollection[arg4][arg3.Title] = arg:AddSlider(arg3.Title, tbl14)

				ElementsCollection[arg4][arg3.Title]:OnChanged(function(arg5)
					arg3.OnChange(tonumber(arg5))
				end)
			elseif arg3.Mode == "Dropdown" then
				local tbl14 = { Title = arg3.Title }

				if arg3.Description then
					tbl14.Description = arg3.Description
				end

				if arg3.Multi then
					tbl14.Multi = arg3.Multi
				end

				if arg3.Default then
					tbl14.Default = arg3.Default
				end

				tbl14.Values = arg3.Table
				ElementsCollection[arg4][arg3.Title] = arg:AddDropdown(arg3.Title, tbl14)
				ElementsCollection[arg4][arg3.Title]:OnChanged(arg3.OnChange)
			elseif arg3.Mode == "TextBox" then
				ElementsCollection[arg4][arg3.Title] = arg:AddInput(arg3.Title, { Title = arg3.Title, Callback = arg3.Callback, Finished = arg3.Finished })
			end
		end

		for _, v in pairs(tbl3) do
			tbl4[v] = window:AddTab({ Title = v, Icon = "" })
			local v2 = tbl4[v]

			for k, v3 in pairs(tbl5[v]) do
				if type(v3) == "function" then
					for k2, v4 in pairs(v3()) do
						fn8(v2, k2, v4, v)
					end
				else
					fn8(v2, k, v3, v)
				end

				if getgenv().SlowLoadUi then
					task.wait()
				end
			end
		end

		return Title, SubTitle, ElementsCollection
	end

	task.spawn(function()
		lib2 = loadstring(game:HttpGet("https://raw.githubusercontent.com/hoannhatz/backup/refs/heads/main/secure_call.lua", true))()
		n2 += 1
	end)

	repeat
		task.wait(0.1)
	until n2 >= 2

	print("Getting Ui")

	spawn(function()
		SupportRetard()
		if getgenv().IgnoreUi then
			FinishLoadUi = true
			return
		end
		print("Loadin Ui")
		if getgenv().IgnoreUi then
			FinishLoadUi = true
			return
		end

		local ok, result = pcall(function()
			local v, v2, v3 = fn3()
			FinishLoadUi = true
			ElementsCollection = v3
			FinishLoadUi = true
		end)

		if result then
			print("UI Error")
			print(result)
			print(debug.traceback())
		end
	end)
end

print("UI Attempt Loaded")
local enemies
enemies = game:GetService("Workspace").Enemies
local cframe = CFrame.new

RaceEntrances = {
	Cyborg = CFrame.new(28492.52734375, 14895.9755859375, -422.60586547851562),
	Human = {
		CFrame.new(29019.9609375, 14891.1474609375, -389.439697265625),
		cframe(29237.48828125, 14891.052734375, -204.71849060058594),
	},
	Mink = CFrame.new(29020.9492, 14890.6328, -380.407867, -0.0712743625, 8.85832776e-08, -0.997456729, -3.87927805e-08, 1, 9.15811214e-08, 0.997456729, 4.52215083e-08, -0.0712743625),
	Fishman = CFrame.new(28224.0938, 14891.2402, -212.507004, 0.0963651389, -3.22392211e-08, 0.995346069, 3.76359344e-09, 1, 3.20255857e-08, -0.995346069, 6.59927724e-10, 0.0963651389),
	Ghoul = CFrame.new(28673.8555, 14890.334, 454.733765, -0.999887466, -3.48198981e-09, 0.0150030479, -3.48583518e-09, 1, -2.30164096e-10, -0.0150030479, -2.82436352e-10, -0.999887466),
	Skypiea = CFrame.new(28967.8086, 14919.2803, 234.668045, -0.00638482161, 3.80502279e-08, -0.999979615, 6.83823131e-08, 1, 3.76143845e-08, 0.999979615, -6.8140757e-08, -0.00638482161),
}

PlacesPosition = {
	SpawnRipIndra = CFrame.new(-5564.91406, 313.950531, -2666.69287, -0.892237544, -1.03326805e-08, -0.451566368, 1.39742387e-08, 1, -5.04931776e-08, 0.451566368, -5.13622034e-08, -0.892237544),
	CenterCastle = Vector3.new(-5581.2354, 313.76556, -3064.095),
	DefaultSeaPosition = Vector3.new(0, -10010, 0),
}

LastClick = tick()
AllFruitKeys = { "Z", "X", "C", "V", "F" }
Weapon600Mas = {}

GatesInfo = {
	Castle = { CanInstaTP = true, Pos = Vector3.new(-5069.1216, 314.5155, -3000.4673) },
	Hydra = {
		CanInstaTP = true,
		Hitbox = function()
			local boatCastle = game:GetService("Workspace").Map:FindFirstChild("Boat Castle")

			if boatCastle then
				local mapTeleportB = boatCastle:FindFirstChild("MapTeleportB")
				if mapTeleportB then
					return mapTeleportB:FindFirstChild("Hitbox")
				end
			end

			return nil
		end,
		Pos = Vector3.new(5657.0947, 1013.0795, -340.00446),
	},
	Mansion = { CanInstaTP = true, Pos = Vector3.new(-12547.14, 337.16827, -7471.882) },
}

ListNpc = {}
NPCInstances = {}
BlacklistNpcName = { "Boat Dealer", "Quest Giver", "Dealer", "Set Home Point" }

for _, child in pairs(workspace.NPCs:GetChildren()) do
	IsBlacklist = false

	for _, v in pairs(BlacklistNpcName) do
		if string.find(child.Name, v) then
			IsBlacklist = true
			break
		end
	end

	local defaultSeaPosition = PlacesPosition.DefaultSeaPosition

	if (child:GetAttribute("FloorPos") - defaultSeaPosition).magnitude < 100 then
		IsBlacklist = true
	end

	if not IsBlacklist then
		table.insert(ListNpc, child.Name)
		NPCInstances[child.Name] = child
	end
end

for _, child in pairs(game:GetService("ReplicatedStorage").NPCs:GetChildren()) do
	IsBlacklist = false

	for _, v in pairs(BlacklistNpcName) do
		if string.find(child.Name, v) then
			IsBlacklist = true
			break
		end
	end

	local defaultSeaPosition = PlacesPosition.DefaultSeaPosition

	if (child:GetAttribute("FloorPos") - defaultSeaPosition).magnitude < 100 then
		IsBlacklist = true
	end

	if not IsBlacklist then
		table.insert(ListNpc, child.Name)
		NPCInstances[child.Name] = child
	end
end

UIInfo = {
	InCombat = localPlayer.PlayerGui.Main.BottomHUDList.InCombat,
	InCombatBottom = localPlayer.PlayerGui.Main.BottomHUDList.InCombatBottom,
}

SkillsV3Name = {
	Mink = "Agility",
	Skypiea = "Heavenly Blood",
	Ghoul = "Heightened Senses",
	Fishman = "Water Body",
	Cyborg = "Energy Core",
	Human = "Last Resort",
}

BossQuest = {
	["2753915549"] = {
		["The Gorilla King"] = {
			Quest = "JungleQuest",
			Require = 25,
			LvQuest = 3,
			Pos = CFrame.new(-1604.12012, 36.8521118, 154.23732),
		},
		Chef = {
			Quest = "BuggyQuest1",
			Require = 55,
			LvQuest = 3,
			Pos = CFrame.new(-1139.59717, 4.75205183, 3825.16211),
		},
		Bobby = {
			Quest = "BuggyQuest1",
			Require = 55,
			LvQuest = 3,
			Pos = CFrame.new(-1139.59717, 4.75205183, 3825.16211),
		},
		Yeti = {
			Quest = "SnowQuest",
			LvQuest = 3,
			Require = 110,
			Pos = CFrame.new(1384.90247, 87.3078308, -1296.6825),
		},
		["Vice Admiral"] = {
			Quest = "MarineQuest2",
			LvQuest = 2,
			Require = 130,
			Pos = CFrame.new(-5035.42285, 28.6520386, 4324.50293),
		},
		Warden = {
			Quest = "ImpelQuest",
			LvQuest = 1,
			Require = 220,
			Pos = CFrame.new(5189.8603515625, 3.5371694564819336, 689.46923828125),
		},
		["Chief Warden"] = {
			Quest = "ImpelQuest",
			LvQuest = 2,
			Require = 230,
			Pos = CFrame.new(5189.8603515625, 3.5371694564819336, 689.46923828125),
		},
		Swan = {
			Quest = "ImpelQuest",
			LvQuest = 3,
			Require = 230,
			Pos = CFrame.new(5189.8603515625, 3.5371694564819336, 689.46923828125),
		},
		["Magma Admiral"] = {
			Quest = "MagmaQuest",
			LvQuest = 3,
			Require = 350,
			Pos = CFrame.new(-5317.07666, 12.2721891, 8517.41699),
		},
		["Fishman Lord"] = {
			Quest = "FishmanQuest",
			LvQuest = 3,
			Require = 425,
			Pos = CFrame.new(61123.0859, 18.5066795, 1570.18018),
		},
		Wysper = {
			Quest = "SkyExp1Quest",
			LvQuest = 3,
			Require = 500,
			Pos = CFrame.new(-7862.94629, 5545.52832, -379.833954),
		},
		["Thunder God"] = {
			Quest = "SkyExp2Quest",
			LvQuest = 3,
			Require = 575,
			Pos = CFrame.new(-7902.78613, 5635.99902, -1411.98706),
		},
		Cyborg = {
			Quest = "FountainQuest",
			LvQuest = 3,
			Require = 675,
			Pos = CFrame.new(-5253.54834, 38.5361786, 4050.45166),
		},
	},
	["4442272183"] = {
		Diamond = {
			Quest = "Area1Quest",
			LvQuest = 3,
			Require = 750,
			Pos = CFrame.new(-424.080078, 73.0055847, 1836.91589),
		},
		Jeremy = {
			Quest = "Area2Quest",
			LvQuest = 3,
			Require = 850,
			Pos = CFrame.new(632.698608, 73.1055908, 918.666321),
		},
		Orbitus = {
			Quest = "MarineQuest3",
			LvQuest = 3,
			Require = 925,
			Pos = CFrame.new(-2442.65015, 73.0511475, -3219.11523),
		},
		Fajita = {
			Quest = "MarineQuest3",
			LvQuest = 3,
			Require = 925,
			Pos = CFrame.new(-2442.65015, 73.0511475, -3219.11523),
		},
		["Smoke Admiral"] = {
			Quest = "IceSideQuest",
			LvQuest = 3,
			Require = 1150,
			Pos = CFrame.new(-6059.96191, 15.9868021, -4904.7373),
		},
		["Awakened Ice Admiral"] = {
			Quest = "FrostQuest",
			LvQuest = 3,
			Require = 1400,
			Pos = CFrame.new(5669.33203, 28.2118053, -6481.55908),
		},
		["Tide Keeper"] = {
			Quest = "ForgottenQuest",
			LvQuest = 3,
			Require = 1475,
			Pos = CFrame.new(-3053.89648, 236.881363, -10148.2324),
		},
	},
	["7449423635"] = {
		Stone = {
			Quest = "PiratePortQuest",
			LvQuest = 3,
			Require = 1550,
			Pos = CFrame.new(-288.003815, 43.7675667, 5573.12012),
		},
		["Island Empress"] = {
			Quest = "AmazonQuest2",
			LvQuest = 3,
			Require = 1675,
			Pos = CFrame.new(5444.14355, 601.603821, 751.306763),
		},
		["Kilo Admiral"] = {
			Quest = "MarineTreeIsland",
			LvQuest = 3,
			Require = 1750,
			Pos = CFrame.new(2223.3645, 28.7049141, -6719.18408),
		},
		["Captain Elephant"] = {
			Quest = "DeepForestIsland",
			LvQuest = 3,
			Require = 1875,
			Pos = CFrame.new(-13231.1602, 333.744446, -7624.40723),
		},
		["Cake Queen"] = {
			Quest = "IceCreamIslandQuest",
			LvQuest = 3,
			Require = 1875,
			Pos = CFrame.new(-821.71612548828, 65.819519042969, -10965.169921875),
		},
	},
}

AllBoss = {
	["2753915549"] = {
		"Saber Expert",
		"The Saw",
		"Chef",
		"Bobby",
		"The Gorilla King",
		"Yeti",
		"Vice Admiral",
		"Warden",
		"Chief Warden",
		"Swan",
		"Magma Admiral",
		"Fishman Lord",
		"Wysper",
		"Thunder God",
		"Cyborg",
	},
	["4442272183"] = {
		"Diamond",
		"Jeremy",
		"Orbitus",
		"Fajita",
		"Smoke Admiral",
		"Awakened Ice Admiral",
		"Tide Keeper",
		"Don Swan",
		"Cursed Captain",
	},
	["7449423635"] = {
		"Stone",
		"Island Empress",
		"Kilo Admiral",
		"Captain Elephant",
		"Cake Queen",
		"Beautiful Pirate",
		"Soul Reaper",
		"rip_indra True Form",
		"Cake Prince",
		"Dough King",
	},
}

local v = AllBoss
getgenv().AllBoss = v

AutoBlackSmithv1 = {
	["Dark Blade"] = { ["Magma Ore"] = 10, ["Dragon Scale"] = 15, ["Dark Fragment"] = 1 },
	["Cursed Dual Katana"] = { ["Scrap Metal"] = 60, ["Mini Tusk"] = 10, ["Demonic Wisp"] = 10 },
	["Hallow Scythe"] = { ["Scrap Metal"] = 25, Bones = 800, ["Demonic Wisp"] = 8 },
	["True Triple Katana"] = { Leather = 50, ["Mystic Droplet"] = 20, ["Dragon Scale"] = 5 },
	["Spikey Trident"] = { ["Scrap Metal"] = 25, ["Conjured Cocoa"] = 8, ["Mystic Droplet"] = 5 },
	Koko = { ["Scrap Metal"] = 15, ["Vampire Fang"] = 10 },
	Tushita = { Leather = 6, ["Mini Tusk"] = 20 },
	["Pole (2nd Form)"] = { ["Scrap Metal"] = 12, ["Mystic Droplet"] = 10, ["Fish Tail"] = 15 },
	Saddi = { Leather = 10, ["Mystic Droplet"] = 8 },
	Saber = { ["Scrap Metal"] = 10, ["Radioactive Material"] = 5, ["Magma Ore"] = 10 },
	Yama = { Leather = 6, ["Mini Tusk"] = 20 },
	["Midnight Blade"] = { ["Scrap Metal"] = 15, Ectoplasm = 40 },
	["Buddy Sword"] = { Leather = 25, ["Conjured Cocoa"] = 8, ["Mystic Droplet"] = 5 },
	Shisui = { Leather = 10, ["Mystic Droplet"] = 8 },
	Bisento = { ["Scrap Metal"] = 15, ["Angel Wings"] = 12, ["Magma Ore"] = 10 },
	["Pole (1st Form)"] = { ["Scrap Metal"] = 20, ["Angel Wings"] = 10, ["Radioactive Material"] = 10 },
	Canvander = { Leather = 20, ["Dragon Scale"] = 6 },
	["Dark Dagger"] = { ["Scrap Metal"] = 10, ["Dragon Scale"] = 8, ["Dark Fragment"] = 1 },
	Rengoku = { ["Vampire Fang"] = 8, ["Scrap Metal"] = 15, ["Magma Ore"] = 20 },
	Wando = { Leather = 10, ["Mystic Droplet"] = 8 },
	Longsword = { ["Scrap Metal"] = 10, ["Radioactive Material"] = 10 },
	Pipe = { ["Scrap Metal"] = 10, ["Fish Tail"] = 12 },
	["Dragon Trident"] = { Leather = 10, ["Dragon Scale"] = 10 },
	Jitte = { ["Scrap Metal"] = 15, ["Vampire Fang"] = 10 },
	["Dual-Headed Blade"] = { ["Scrap Metal"] = 10, ["Fish Tail"] = 12 },
	["Gravity Cane"] = { ["Scrap Metal"] = 10, Meteorite = 3 },
	["Soul Cane"] = { Leather = 20, ["Radioactive Material"] = 5 },
	["Iron Mace"] = { Leather = 10, ["Angel Wings"] = 10 },
	["Shark Saw"] = { Leather = 12 },
	["Twin Hooks"] = { Leather = 20, ["Mini Tusk"] = 8, ["Fish Tail"] = 10 },
	["Triple Katana"] = { Leather = 15, ["Scrap Metal"] = 15 },
	["Skull Guitar"] = { ["Magma Ore"] = 10, ["Dragon Scale"] = 15, ["Dark Fragment"] = 1 },
	Kabucha = { Leather = 50, ["Dragon Scale"] = 15, ["Vampire Fang"] = 3 },
	["Serpent Bow"] = { Meteorite = 1, ["Scrap Metal"] = 10, ["Vampire Fang"] = 10 },
	Bazooka = { ["Magma Ore"] = 10, ["Dragon Scale"] = 15, ["Dark Fragment"] = 1 },
	Cannon = { Leather = 5, ["Fish Tail"] = 5, ["Magma Ore"] = 5 },
	["Refined Musket"] = { ["Scrap Metal"] = 10, ["Fish Tail"] = 10 },
	["Refined Slingshot"] = { ["Scrap Metal"] = 10, ["Angel Wings"] = 10 },
	["Bizarre Rifle"] = { Leather = 20, ["Angel Wings"] = 10, ["Magma Ore"] = 5 },
	Musket = { Leather = 5, ["Fish Tail"] = 5 },
	Flintlock = { Leather = 5, ["Magma Ore"] = 5 },
	["Acidum Rifle"] = { Leather = 10, ["Vampire Fang"] = 8 },
}

local cframe2
cframe2 = CFrame.new(0, 0, 15)

spawn(function()
	while true do
		cframe2 = CFrame.new(0, 0, 15)
		task.wait(0.5)
		cframe2 = CFrame.new(10, 0, 10)
		task.wait(0.5)
		cframe2 = CFrame.new(10, 0, -10)
		task.wait(0.5)
		cframe2 = CFrame.new(-15, 0, 0)
		task.wait(0.5)
		cframe2 = CFrame.new(-10, 0, -10)
		task.wait(0.5)
		cframe2 = CFrame.new(0, 0, -15)
		task.wait(0.5)
		cframe2 = CFrame.new(-10, 0, 10)
		task.wait(0.5)
	end
end)

local tbl3

tbl3 = {
	"GAMERROBOT_YT",
	"FUDD10",
	"fudd10_v2",
	"BIGNEWS",
	"THEGREATACE",
	"SUB2NOOBMASTER123",
	"Sub2Daigrock",
	"Axiore",
	"TantaiGaming",
	"STRAWHATMAINE",
	"Sub2OfficialNoobie",
	"UPD16",
	"SUB2GAMERROBOT_EXP1",
	"3BVISITS",
	"Enyu_is_Pro",
	"Sub2Fer999",
	"Bluxxy",
	"JCWK",
	"Magicbus",
	"Starcodeheo",
	"kittgaming",
	"ADMINGIVEAWAY",
	"GAMER_ROBOT_1M",
	"Sub2CaptainMaui",
	"15B_BESTBROTHERS",
	"DEVSCOOKING",
	"krazydares",
	"Sub2CaptainMaui",
	"DEVSCOOKING",
	"KITT_RESET",
	"Sub2UncleKizaru",
	"SUB2GAMERROBOT_RESET1",
	"NOMOREHACK",
	"BANEXPLOIT",
	"GIFTING_HOURS",
}

do
	local tbl4 = { "18", "19", "20", "21", "22", "23", "24", "00", "01", "02", "03", "04" }

	IsNight = function()
		return table.find(tbl4, tostring(game:GetService("Lighting").TimeOfDay:split(":")[1]))
	end

	local tbl5 = { [4] = "Near Full Moon" }

	local function fn3()
		local attribute = game:GetService("Lighting"):GetAttribute("MoonPhase")
		local num = tonumber(string.sub(tostring(attribute), #tostring(attribute)))
		if tbl5[num] then
			return tbl5[num]
		end

		if attribute % 5 == 0 then
			return "Full Moon OMG"
		end
		return num
	end

	TimeRemain = function()
		if IsNight() then
			local v2 = table.find(tbl4, tostring(game:GetService("Lighting").TimeOfDay:split(":")[1]))
			if not v2 then
				return 0
			end
			local n2

			if v2 >= 6 then
				n2 = 10 - v2 + 1
			else
				n2 = 10 - v2
			end

			return n2
		end
	end
end

spawn(function()
	while task.wait(1.5) do
		local v2 = pairs
		local ReplicatedStorage = game:GetService("ReplicatedStorage")

		for _, child in v2(ReplicatedStorage:GetChildren()) do
			if fn2(child) and child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
				child.Parent = enemies
			end
		end

		for _, child in pairs(game:GetService("Workspace").Boats:GetChildren()) do
			if fn2(child) and child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
				child.Parent = enemies
			end
		end
	end
end)

local fn3

fn3 = function()
	local players = Players:GetPlayers()
	table.remove(players, table.find(players, localPlayer))
	return players
end

local strGetPlayers

strGetPlayers = function()
	local tbl4 = {}

	for _, player in pairs(Players:GetPlayers()) do
		if player ~= localPlayer then
			table.insert(tbl4, player.Name)
		end
	end

	return tbl4
end

local fn4

fn4 = function(arg)
	return arg:FindFirstChild("HumanoidRootPart")
end

local fn5

fn5 = function(arg)
	if arg and arg.Parent and fn4(arg) and arg:FindFirstChild("Humanoid") then
		if arg:FindFirstChild("Humanoid").Health and arg:FindFirstChild("Humanoid").Health > 0 then
			return true
		end
	end

	return false
end

getgenv().Alive = function()
	if localPlayer.Character then
		if fn4(localPlayer.Character) and localPlayer.Character:FindFirstChild("Humanoid") then
			if localPlayer.Character:FindFirstChild("Humanoid").Health > 0 then
				return true
			end
		end
	end

	return false
end

Alive = getgenv().Alive
_G.Alive = getgenv().Alive
local fn6

fn6 = function(arg)
	if fn4(localPlayer.Character) then
		if arg then
			if not fn4(localPlayer.Character):FindFirstChild("VelocityBody") then
				local bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.Parent = fn4(localPlayer.Character)
				bodyVelocity.Name = "VelocityBody"
				bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
				bodyVelocity.Velocity = Vector3.zero
			end
		elseif fn4(localPlayer.Character):FindFirstChild("VelocityBody") then
			fn4(localPlayer.Character).VelocityBody:Destroy()
		end
	end
end

local tbl4 = {}

CreateSteppedLoop = function(arg, arg2)
	if arg2 then
		if tbl4[arg2] then
			return tbl4[arg2]
		end
	end

	local connection = RunService.Stepped:Connect(arg)

	if arg2 then
		tbl4[arg2] = connection
	end

	return connection
end

DisconnectLoop = function(arg)
	if arg then
		if type(arg) == "string" then
			if tbl4[arg] then
				tbl4[arg]:Disconnect()
			end
		elseif typeof(arg) == "RBXScriptConnection" then
			if table.find(tbl4, arg) then
				table.remove(tbl4, table.find(tbl4, arg))
			end

			arg:Disconnect()
		else
			print("DisconnectLoop", "Can't Disconnect", typeof(arg))
		end
	end
end

local fn7
fn7 = function()
	if localPlayer.Character ~= nil then
		for _, part in pairs(localPlayer.Character:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide == true then
				part.CanCollide = false
			end
		end
	end
end
local fn8

fn8 = function(arg)
	if not arg then
		return nil
	end
	local kind = typeof(arg)
	if kind == "Vector3" or type(arg) == "vector" then
		return arg
	end

	if kind == "CFrame" then
		return arg.Position
	end

	if kind == "Instance" then
		if arg:IsA("BasePart") then
			return arg.Position
		end

		if arg:IsA("Model") then
			local humanoidRootPart = arg:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
				return humanoidRootPart.Position
			end

			if arg.PrimaryPart then
				return arg.PrimaryPart.Position
			end
			local head = arg:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				return head.Position
			end

			local ok, result = pcall(function()
				return arg:GetPivot().Position
			end)

			if ok and result then
				return result
			end
		elseif arg:IsA("Player") then
			local character = arg.Character

			if character then
				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
					return humanoidRootPart.Position
				end

				if character.PrimaryPart then
					return character.PrimaryPart.Position
				end
			end
		end
	end

	return nil
end

local fn9, fn10, improvedTeleport, fn11

do
	local function fn12(arg)
		local flag2 = true

		if arg == arg then
			if arg ~= math.huge then
				flag2 = arg == -math.huge
			end
		end

		return flag2
	end

	ConvertStringToVector3 = function(arg)
		local match, v2, v3 = arg:match("([-0-9.]+),%s([-0-9.]+),%s([-0-9.]+)")
		local vector = Vector3.new
		local num = tonumber(match)
		local v4 = tonumber
		return vector(num, tonumber(v2), v4(v3))
	end

	fn9 = function(arg, arg2)
		local v2 = fn8(arg)
		local v3 = fn8(arg2)
		if v2 and v3 then
			return (v2 - v3).magnitude
		end
		return 9999999
	end

	fn10 = function(arg)
		if not Sea3 then
			return false
		end
		local v2 = fn8(arg or localPlayer.Character)
		if not v2 then
			return false
		end
		return (v2 - Vector3.new(11424.47, -2154.98, 9732.01)).magnitude < 2000
	end

	improvedTeleport = function(arg)
		local localPlayer2 = game:GetService("Players").LocalPlayer
		local humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return
		end

		if typeof(arg) ~= "Vector3" then
			if typeof(arg) == "CFrame" then
				arg = arg.Position
			elseif typeof(arg) == "Instance" and arg:IsA("BasePart") then
				arg = arg.Position
			else
				if not (arg and arg.Position) then
					return
				end
				arg = arg.Position
			end
		end

		local n2 = getgenv().Setting and getgenv().Setting.Tween and tonumber(getgenv().Setting.Tween.Speed) or 150

		if not n2 or n2 <= 0 then
			n2 = 150
		end

		local position = humanoidRootPart.Position
		local magnitude = (position - arg).magnitude
		if magnitude <= 1 then
			humanoidRootPart.CFrame = CFrame.new(arg)
			return
		end
		local n3 = arg - position
		local now = tick()
		local n4 = magnitude / n2
		local heartbeat = game:GetService("RunService").Heartbeat

		repeat
			heartbeat:Wait()
			if not humanoidRootPart or not humanoidRootPart.Parent or not localPlayer2.Character or not localPlayer2.Character:FindFirstChild("HumanoidRootPart") then
				return
			end
			humanoidRootPart.CFrame = CFrame.new(position + n3 * math.min((tick() - now) / n4, 1))
		until (humanoidRootPart.Position - arg).magnitude <= n2 / 2 or tick() - now > n4 + 3

		if humanoidRootPart and humanoidRootPart.Parent then
			humanoidRootPart.CFrame = CFrame.new(arg)
		end
	end

	getgenv().ImprovedTeleport = improvedTeleport

	fn11 = function(arg)
		if not Sea3 then
			return false
		end

		if not fn10() then
			return false
		end

		arg = arg or function()
			return true
		end

		local cframe3 = CFrame.new(-16269, 25, 1375)
		StatusFarming = "Exiting Submerged Island..."
		local character = localPlayer and localPlayer.Character and fn4(localPlayer.Character)
		if not character then
			return false
		end

		if (character.Position - Vector3.new(11424.47, -2154.98, 9732.01)).magnitude > 15 then
			StatusFarming = "Tweening to Submarine NPC..."

			if DoTween2 then
				DoTween2(CFrame.new(Vector3.new(11424.47, -2154.98, 9732.01)), arg)
			elseif DoTween then
				DoTween(CFrame.new(Vector3.new(11424.47, -2154.98, 9732.01)))
			end

			task.wait(0.2)
			local character2 = localPlayer and localPlayer.Character and fn4(localPlayer.Character)
			if not character2 then
				return false
			end
			character = character2
		end

		if (character.Position - Vector3.new(11424.47, -2154.98, 9732.01)).magnitude <= 15 then
			StatusFarming = "Interacting with Submarine Worker..."

			pcall(function()
				local net = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net")

				if net:FindFirstChild("RF/SubmarineTransportation") then
					net["RF/SubmarineTransportation"]:InvokeServer("InitiateTeleport", "Tiki Outpost")
				end

				if net:FindFirstChild("RF/SubmarineWorkerSpeak") then
					net["RF/SubmarineWorkerSpeak"]:InvokeServer("AskKilledTikiBoss")
					task.wait(0.3)
					net["RF/SubmarineWorkerSpeak"]:InvokeServer("TravelToSubmergedIsland")
				end
			end)

			local now = tick()

			while true do
				task.wait(0.2)
				if not (not fn10() or tick() - now > 5) then
					continue
				end
				break
			end
		end

		if fn10() then
			StatusFarming = "Exiting Submerged (Fallback TP)..."

			if improvedTeleport then
				improvedTeleport(cframe3.Position + Vector3.new(0, 50, 0))
			elseif localPlayer and localPlayer.Character and fn4(localPlayer.Character) then
				fn4(localPlayer.Character).CFrame = cframe3 + Vector3.new(0, 50, 0)
			end

			task.wait(1)
		end

		return not fn10()
	end

	NewPos = function(arg, arg2)
		if Alive() and fn5(arg) then
			if arg2 == nil then
				arg2 = Vector3.zero
			end

			local y = arg2.Y
			local n2 = fn4(arg).Position.Y + y
			return CFrame.new(fn4(arg).Position.X, n2, fn4(arg).Position.Z) * CFrame.new(arg2.X, 0, arg2.Z)
		end
	end

	local function fn13()
		if tween then
			tween:Cancel()
			tween = nil
		end

		DisconnectLoop("NoClipTween")
	end

	StopTween = function()
		CancelingTween = true
		TweeningV2 = false
		fn13()
		local tweenInfo = TweenInfo.new(0, Enum.EasingStyle.Linear)
		game:service("TweenService"):Create(fn4(localPlayer.Character), tweenInfo, { CFrame = fn4(localPlayer.Character).CFrame }):Play()
		fn13()
		fn6(false)
		CancelingTween = false
	end

	DoTween = function(arg, arg2)
		while not Alive() do
			task.wait(1)
		end

		if arg ~= nil then
			local position = arg.Position
			local magnitude = (fn4(localPlayer.Character).Position - position).magnitude
			NewSpeed = getgenv().Setting and getgenv().Setting.Tween and tonumber(getgenv().Setting.Tween.Speed) or 150
			if fn12(arg.Position.X) then
				return
			end

			if arg.Position.Y < 0.3 then
				arg = CFrame.new(arg.Position.X, 1, arg.Position.Z)
			end

			RealSpeed = NewSpeed
			local position2 = arg.Position
			local tweenInfo = TweenInfo.new((fn4(localPlayer.Character).Position - position2).magnitude / RealSpeed, Enum.EasingStyle.Linear)

			if tween then
				tween:Cancel()
				tween = nil
			end

			tween = game:service("TweenService"):Create(fn4(localPlayer.Character), tweenInfo, { CFrame = arg })

			if CancelingTween then
				if tween then
					tween:Cancel()
					tween = nil
				end

				CancelingTween = false
				return
			end

			if Alive() then
				tween:Play()
				fn6(true)
				Tweening = true

				if Noclipping then
					if Clip then
						Noclipping:Disconnect()
						Noclipping = nil
					end
				elseif not Clip then
					Noclipping = RunService.Stepped:Connect(fn7)
				end

				localPlayer.Character:WaitForChild("Humanoid").Died:Connect(function()
					Tweening = false

					if tween then
						tween:Cancel()
					end
				end)

				if not arg2 then
					tween.Completed:wait()
				end

				tween.Completed:Connect(function()
					tween = nil
					fn6(false)
				end)

				if Noclipping then
					Noclipping:Disconnect()
					Noclipping = nil
				end

				Tweening = false
				fn6(false)
			else
				fn6(false)
				tween:Cancel()
				tween = nil

				if Noclipping then
					Noclipping:Disconnect()
					Noclipping = nil
				end

				Tweening = false
			end
		end
	end
end

do
	local RunService2 = game:GetService("RunService")
	local localPlayer2 = game:GetService("Players").LocalPlayer
	local n2 = getgenv().Setting and getgenv().Setting.Tween and tonumber(getgenv().Setting.Tween.Speed) or 150
	local heartbeat = RunService2.Heartbeat

	DoTween2 = function(arg, arg2, arg3, arg4)
		if arg == nil then
			return
		end

		if TweeningV2 then
			TweeningV2 = false
			task.wait()
		end

		while not Alive() do
			if arg2 and not arg2() then
				return
			end
			task.wait(1)
		end

		local ok, result = pcall(function()
			local tbl5 = arg4 or {}
			local noTweenPause = tbl5.NoTweenPause
			local speed = tbl5.Speed
			local disableInstaTP = tbl5.DisableInstaTP
			local forceTweenPause = tbl5.ForceTweenPause
			local ignoreSafeY = tbl5.IgnoreSafeY
			local isBasePart = typeof(arg) == "Instance" and arg:IsA("BasePart")
			local v2 = nil

			if isBasePart then
				v2 = arg
				arg = arg.Position
			end

			if typeof(arg) == "CFrame" then
				arg = arg.p
			end

			local fn12 = arg2 or function()
				return true
			end

			if Sea3 and (Vector3.new(11256, -2138, 9888) - arg).magnitude < 2000 then
				ignoreSafeY = true
			end

			if arg.Y < 1.5 and not ignoreSafeY then
				arg = Vector3.new(arg.X, 2, arg.Z)
			end

			fn6(true)
			n2 = speed or getgenv().Setting and getgenv().Setting.Tween and tonumber(getgenv().Setting.Tween.Speed) or 150
			local v3 = CreateSteppedLoop(fn7, "NoClipTween")

			if not disableInstaTP then
				if Sea1 then
					local flag2 = arg.X > 55000 or (arg - Vector3.new(61163.85, 11.6796875, 1819.7842)).magnitude < 4000
					local position = fn4(localPlayer.Character) and fn4(localPlayer.Character).Position
					local flag3

					if position then
						flag3 = position.X > 55000 or (position - Vector3.new(61163.85, 11.6796875, 1819.7842)).magnitude < 3000
					else
						flag3 = position
					end

					if not flag3 and flag2 then
						local n3 = 0

						while true do
							task.wait(0.15)
							n3 += 1

							pcall(function()
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(61163.85, 11.6796875, 1819.7842))
							end)

							local v4 = fn4(localPlayer.Character)

							if v4 then
								v4.AssemblyLinearVelocity = Vector3.zero
								v4.CFrame = CFrame.new(Vector3.new(61163.85, 11.6796875, 1819.7842) + Vector3.new(0, 1.5, 0))
							end

							if not (not Alive() or fn4(localPlayer.Character) and (fn4(localPlayer.Character).Position - Vector3.new(61163.85, 11.6796875, 1819.7842)).magnitude < 2000 or n3 >= 3) then
								continue
							end
							break
						end
					end

					if arg.Y >= 4000 and (fn4(localPlayer.Character).Position - Vector3.new(-6023.5767, 5469.7197, 2203.3083)).magnitude > 3000 and (arg - Vector3.new(-6023.5767, 5469.7197, 2203.3083)).magnitude < 3500 then
						local n3 = 0

						while true do
							task.wait(0.2)
							n3 += 1

							pcall(function()
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(-6023.5767, 5469.7197, 2203.3083))
							end)

							local v4 = fn4(localPlayer.Character)

							if v4 then
								v4.AssemblyLinearVelocity = Vector3.zero
								v4.CFrame = CFrame.new(Vector3.new(-6023.5767, 5469.7197, 2203.3083))
							end

							if not (not Alive() or (fn4(localPlayer.Character).Position - Vector3.new(-6023.5767, 5469.7197, 2203.3083)).magnitude < 3000 or n3 >= 3) then
								continue
							end
							break
						end
					end

					if arg.Y >= 200 and arg.Y < 4000 and (fn4(localPlayer.Character).Position - Vector3.new(-4166.61, 1093.698, -347.16226)).magnitude > 3000 and (arg - Vector3.new(-4166.61, 1093.698, -347.16226)).magnitude < 3000 then
						local n3 = 0

						while true do
							task.wait(0.2)
							n3 += 1

							pcall(function()
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(-4166.61, 1093.698, -347.16226))
							end)

							local v4 = fn4(localPlayer.Character)

							if v4 then
								v4.AssemblyLinearVelocity = Vector3.zero
								v4.CFrame = CFrame.new(Vector3.new(-4166.61, 1093.698, -347.16226))
							end

							if not (not Alive() or (fn4(localPlayer.Character).Position - Vector3.new(-4166.61, 1093.698, -347.16226)).magnitude < 3000 or n3 >= 3) then
								continue
							end
							break
						end
					end

					if flag3 and not flag2 then
						local n3 = 0

						while true do
							task.wait(0.15)
							n3 += 1

							pcall(function()
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(3864.6885, 6.7369504, -1926.2141))
							end)

							local v4 = fn4(localPlayer.Character)

							if v4 then
								v4.AssemblyLinearVelocity = Vector3.zero
								v4.CFrame = CFrame.new(Vector3.new(3864.6885, 6.7369504, -1926.2141) + Vector3.new(0, 15, 0))
							end

							if not (not Alive() or fn4(localPlayer.Character) and (fn4(localPlayer.Character).Position - Vector3.new(3864.6885, 6.7369504, -1926.2141)).magnitude < 2000 or n3 >= 3) then
								continue
							end
							break
						end
					end
				end

				if Sea2 then
					if (fn4(localPlayer.Character).Position - Vector3.new(923.2125, 126.976006, 32852.832)).magnitude > 3000 and (arg - Vector3.new(923.2125, 126.976006, 32852.832)).magnitude < 1000 then
						local n3 = 0

						while true do
							task.wait(0.2)
							n3 += 1

							pcall(function()
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(923.2125, 126.976006, 32852.832))
							end)

							if not ((fn4(localPlayer.Character).Position - Vector3.new(923.2125, 126.976006, 32852.832)).magnitude < 2000 or n3 >= 3) then
								continue
							end
							break
						end
					end

					if (fn4(localPlayer.Character).Position - Vector3.new(923.2125, 126.976006, 32852.832)).magnitude < 3000 and (arg - Vector3.new(923.2125, 126.976006, 32852.832)).magnitude > 3000 then
						local n3 = 0

						while true do
							task.wait(0.2)
							n3 += 1

							pcall(function()
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(-6508.558, 89.034996, -132.83954))
							end)

							if not ((fn4(localPlayer.Character).Position - Vector3.new(923.2125, 126.976006, 32852.832)).magnitude > 2000 or n3 >= 3) then
								continue
							end
							break
						end
					end
				end

				if Sea3 then
					local position = typeof(arg) == "CFrame" and arg.Position or arg
					local v4 = fn10(localPlayer.Character)
					local v5 = fn10(position)

					if v4 and not v5 and fn9(position, Vector3.new(11256, -2138, 9888)) > 2500 then
						StatusFarming = "Auto-Exit Submerged (Target Outside)"

						if fn11(fn12) then
							task.wait(0.5)
						end
					end

					if not v4 and v5 then
						if (fn4(localPlayer.Character).Position - Vector3.new(-16274.825, 25.220568, 1375.0765)).magnitude > 12 then
							DoTween2(CFrame.new(Vector3.new(-16274.825, 25.220568, 1375.0765)), fn12, arg3, tbl5)
						end

						if (fn4(localPlayer.Character).Position - Vector3.new(-16274.825, 25.220568, 1375.0765)).magnitude <= 15 then
							pcall(function()
								local net = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net")
								net["RF/SubmarineWorkerSpeak"]:InvokeServer("AskKilledTikiBoss")
								net["RF/SubmarineWorkerSpeak"]:InvokeServer("TravelToSubmergedIsland")
							end)

							local now = tick()

							while true do
								task.wait(0.2)
								if not (fn10() or tick() - now > 5) then
									continue
								end
								break
							end

							if not fn10() then
								improvedTeleport(Vector3.new(11256, -2138, 9888) + Vector3.new(0, 50, 0))
								task.wait(0.5)
							end
						end
					end

					if (fn4(localPlayer.Character).Position - Vector3.new(-1864.41, 4532.9707, -14661.355)).magnitude > 1500 then
					end

					if (fn4(localPlayer.Character).Position - Vector3.new(28286.355, 14896.508, 102.624695)).magnitude <= 4000 and (arg - Vector3.new(28286.355, 14896.508, 102.624695)).magnitude >= 4000 then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ "requestEntrance", Vector3.new(-5069.1216, 314.5155, -3000.4673) }))
						task.wait(0.2)
					end
				end
			end

			local v4 = arg3
			local humanoidRootPart

			if arg3 then
				humanoidRootPart = v4
			else
				humanoidRootPart = localPlayer2.Character and localPlayer2.Character:FindFirstChild("HumanoidRootPart")
			end

			if not humanoidRootPart then
				return
			end
			local now = tick()
			local position = humanoidRootPart.Position
			local n3 = arg - position
			local now2 = tick()
			local n4 = (position - arg).magnitude / n2
			TweeningV2 = true
			local n5 = 0
			local exitTo2 = nil
			local exitTo, flag2, n6

			while true do
				local v5 = Alive() and fn12()
				exitTo = nil

				while true do
					local flag3 = v5 and heartbeat:Wait() and (humanoidRootPart.Position - arg).magnitude > 1 and TweeningV2
					flag2 = false

					if flag3 then
						if not arg3 then
							localPlayer.Character.Humanoid.Sit = false
						end

						n6 = math.min((tick() - now2) / n4, 1)
						humanoidRootPart.CFrame = CFrame.new(position + n3 * n6)

						pcall(function()
							humanoidRootPart.Velocity = Vector3.zero
						end)

						if forceTweenPause or not noTweenPause and getgenv().Setting and getgenv().Setting.Tween and getgenv().Setting.Tween.Pause then
							if tick() - now > 3 then
								task.wait(0.1)
								now = tick()
								n5 += 1

								if n5 >= 5 then
									exitTo = 3
									break
								elseif n6 >= 1 then
									exitTo = 4
									break
								else
									v5 = Alive() and fn12()
									continue
								end
							elseif n6 >= 1 then
								exitTo = 2
								break
							else
								v5 = Alive() and fn12()
								continue
							end
						else
							exitTo = 1
							break
						end
					end

					break
				end

				if exitTo == 1 then
					if n6 >= 1 then
						exitTo2 = 1
						break
					else
						continue
					end
				end

				break
			end

			if exitTo2 ~= 1 then
				if exitTo ~= 2 then
					if exitTo == 3 then
						flag2 = true
					elseif exitTo == 4 then
					end
				end
			end

			local flag3 = Alive() and (humanoidRootPart.Position - arg).magnitude <= 2
			local flag4 = false

			if flag3 then
				humanoidRootPart.CFrame = CFrame.new(arg)
				flag4 = true
			end

			DisconnectLoop(v3)
			TweeningV2 = false
			if flag2 then
				task.wait(0.15)
				return DoTween2(v2 or arg, fn12, arg3, tbl5)
			end

			if not flag4 then
				if not Alive() then
					fn6(false)
				end
			end
		end)

		if result then
			print("Tween Error", result)
		end
	end
end

local fn12

fn12 = function(arg, arg2)
	if Alive() and fn5(arg) then
		DoTween2(NewPos(arg, arg2))
		fn6(true)
	end
end

TeleportToUnderwater = function(arg)
	if not Sea1 or not Alive() then
		return false
	end
	local v2 = fn4(localPlayer.Character)
	if not v2 then
		return false
	end
	local vector = arg and Vector3.new(61163.85, 11.6796875, 1819.7842) or Vector3.new(3864.6885, 6.7369504, -1926.2141)
	local n2 = 0

	while true do
		n2 += 1

		pcall(function()
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", vector)
		end)

		v2.AssemblyLinearVelocity = Vector3.zero
		v2.CFrame = CFrame.new(vector + Vector3.new(0, arg and 1.5 or 15, 0))
		task.wait(0.15)
		if not (not Alive() or fn4(localPlayer.Character) and (fn4(localPlayer.Character).Position - vector).magnitude < 2000 or n2 >= 4) then
			continue
		end
		break
	end

	return true
end

FixTP = function(arg)
	if arg and Alive() then
		if Sea1 then
			local flag2 = arg == "Fishman Warrior" or arg == "Fishman Commando" or arg == "Fishman Lord" or string.find(arg, "Fishman")
			local v2 = fn4(localPlayer.Character)
			if not v2 then
				return
			end
			local flag3

			if flag2 then
				flag3 = v2.Position.X < 55000 or (v2.Position - Vector3.new(61163.85, 11.6796875, 1819.7842)).magnitude >= 3000
			else
				flag3 = flag2
			end

			if flag3 then
				TeleportToUnderwater(true)
			end

			if not flag2 and (v2.Position.X > 55000 or (v2.Position - Vector3.new(61163.85, 11.6796875, 1819.7842)).magnitude < 3000) then
				TeleportToUnderwater(false)
			end
		end
	end
end

ServerHop = function(arg, arg2, arg3)
	local HttpService = game:GetService("HttpService")
	local localPlayer2 = game.Players.LocalPlayer
	local TeleportService_ = game:GetService("TeleportService")
	if not arg3 and CalledServerHop then
		return
	end
	CalledServerHop = true

	if not pcall(function()
		for _, v2 in pairs(HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")).data) do
			if v2.maxPlayers > v2.playing then
				TeleportService_:TeleportToPlaceInstance(game.PlaceId, v2.id, localPlayer2)
			end
		end
	end) then
		ServerHop(arg, arg2, true)
	end
end

ServerHop = function(arg, arg2, arg3)
	SupportRetard()
	if not arg3 and CalledServerHop then
		return
	end
	print("Hopping")
	CalledServerHop = true
	local tbl5 = {}
	local tbl6 = { (math.random(1, 120)) }
	local response = game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer(unpack(tbl6))

	if response then
		for k, v2 in pairs(response) do
			for k2, v3 in pairs(v2) do
				if k2 == "Count" and v3 <= 11 and (arg and v3 >= arg or not arg) and (arg2 and v3 <= arg2 or not arg2) then
					table.insert(tbl5, k)
				end
			end
		end

		local jobId = game.JobId
		DangServerHop = true
		local tbl7 = {}

		pcall(function()
			local v2 = game

			for _, v3 in ipairs(game:GetService("HttpService"):JSONDecode(v2:HttpGetAsync("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100")).data) do
				table.insert(tbl7, { v3.id, v3.maxPlayers, v3.playing, v3.ping })
			end
		end)

		for _, v2 in pairs(tbl7) do
			if v2[3] and v2[3] < 12 and (arg2 and v2[3] <= arg2 or not arg2) and (arg and v2[3] >= arg or not arg) then
				table.insert(tbl5, v2[1])
			end
		end

		local n2 = 0

		if #tbl5 > 0 then
			while task.wait(1) and #tbl5 > 0 and game.JobId == jobId do
				n2 += 1
				local n3 = math.random(1, #tbl5)
				game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", tostring(tbl5[n3]))
				table.remove(tbl5, n3)
			end
		end

		ServerHop(arg, arg2, true)
	else
		ServerHop(arg, arg2, true)
	end
end

TrueServerHop = function(...)
	local tbl5 = { ... }
	if CalledServerHop then
		return
	end
	ServerHop(table.unpack(tbl5))
	local now = tick()

	while task.wait() and tick() - now < 30 do
	end
end

GetCurrentTool = function(arg, arg2)
	for _, child in pairs(localPlayer.Backpack:GetChildren()) do
		if child:IsA("Tool") and child.ToolTip == arg then
			child:FindFirstChild("Level")
			arg2 = arg2 and child.Name or child
			return arg2
		end
	end

	for _, child in pairs(localPlayer.Character:GetChildren()) do
		if child:IsA("Tool") and child.ToolTip == arg then
			child:FindFirstChild("Level")
			arg2 = arg2 and child.Name
			child = arg2 or child
			return child
		end
	end

	return false
end

local env
env = _G or getfenv()
env.ScriptStorage = env.ScriptStorage or {}

do
	local scriptStorage = env.ScriptStorage
	scriptStorage.Backpack = scriptStorage.Backpack or {}
	scriptStorage.Melees = scriptStorage.Melees or {}
	scriptStorage.SwordMastery = scriptStorage.SwordMastery or {}
	scriptStorage.CurrentMeleeData = scriptStorage.CurrentMeleeData or { Name = "", Mastery = 0 }
	scriptStorage.Connections = scriptStorage.Connections or { MeleeConns = {}, ToolLevelConns = {} }

	local function fn13()
		if rawget(env, "Remotes") and type(env.Remotes) == "table" and env.Remotes.CommF_ then
			return env.Remotes.CommF_
		end
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")

		if remotes then
			local commF = remotes:FindFirstChild("CommF_")
			if commF and commF:IsA("RemoteFunction") then
				return commF
			end
		end

		local commF = ReplicatedStorage:FindFirstChild("CommF_")
		if commF and commF:IsA("RemoteFunction") then
			return commF
		end
		return nil
	end

	MeleeToolAliases = {
		Combat = { "Combat" },
		["Black Leg"] = { "Black Leg", "BlackLeg" },
		Electro = { "Electro" },
		["Fishman Karate"] = { "Fishman Karate", "FishmanKarate", "Water Kung Fu", "WaterKungFu" },
		["Dragon Claw"] = { "Dragon Claw", "DragonClaw", "Dragon Breath", "DragonBreath" },
		Superhuman = { "Superhuman" },
		["Death Step"] = { "Death Step", "DeathStep" },
		["Sharkman Karate"] = { "Sharkman Karate", "SharkmanKarate", "Water Kung Fu V2", "WaterKungFuV2" },
		["Electric Claw"] = { "Electric Claw", "ElectricClaw", "Electro V2", "ElectroV2" },
		["Dragon Talon"] = { "Dragon Talon", "DragonTalon", "Dragon Breath V2", "DragonBreathV2" },
		Godhuman = { "Godhuman", "God Human", "GodHuman" },
		SanguineArt = { "SanguineArt", "Sanguine Art", "Sanguine" },
	}

	MeleesTable = {
		"Black Leg",
		"Electro",
		"Fishman Karate",
		"Dragon Claw",
		"Superhuman",
		"Death Step",
		"Sharkman Karate",
		"Electric Claw",
		"Dragon Talon",
		"Godhuman",
		"SanguineArt",
	}

	MeleesId = {
		"BuyBlackLeg",
		"BuyElectro",
		"BuyFishmanKarate",
		"BlackbeardReward",
		"BuySuperhuman",
		"BuyDeathStep",
		"BuySharkmanKarate",
		"BuyElectricClaw",
		"BuyDragonTalon",
		"BuyGodhuman",
		"BuySanguineArt",
	}

	local tbl5 = {}

	for i, v2 in ipairs(MeleesTable) do
		local v3 = MeleesId[i]

		if v3 then
			tbl5[v2] = v3
			tbl5[string.lower(v2)] = v3
			tbl5[string.gsub(string.lower(v2), "%s+", "")] = v3
			local v4 = MeleeToolAliases[v2]

			if v4 then
				for _, v5 in ipairs(v4) do
					tbl5[v5] = v3
					tbl5[string.lower(v5)] = v3
					tbl5[string.gsub(string.lower(v5), "%s+", "")] = v3
				end
			end
		end
	end

	local tbl6 = { ItemConfig = nil, ItemReplication = nil, InventoryController = nil }

	local function fn14()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")

		if not tbl6.ItemConfig then
			pcall(function()
				local itemConfig = ReplicatedStorage:FindFirstChild("ItemConfig")

				if itemConfig and itemConfig:IsA("ModuleScript") then
					tbl6.ItemConfig = require(itemConfig)
				end
			end)
		end

		if not tbl6.ItemReplication then
			pcall(function()
				local util = ReplicatedStorage:FindFirstChild("Util")
				util = util and util:FindFirstChild("ItemReplication") or ReplicatedStorage:FindFirstChild("ItemReplication")

				if util and util:IsA("ModuleScript") then
					tbl6.ItemReplication = require(util)
				end
			end)
		end

		if not tbl6.InventoryController then
			pcall(function()
				local controllers = ReplicatedStorage:FindFirstChild("Controllers")
				controllers = controllers and controllers:FindFirstChild("UI")
				controllers = controllers and controllers:FindFirstChild("Inventory") or ReplicatedStorage:FindFirstChild("InventoryController") or ReplicatedStorage:FindFirstChild("Controllers") and ReplicatedStorage.Controllers:FindFirstChild("Inventory")

				if controllers and controllers:IsA("ModuleScript") then
					tbl6.InventoryController = rawget(env, "IC") or require(controllers)
				end
			end)
		end

		return tbl6
	end

	local function fn15(arg, arg2)
		local itemReplication = fn14().ItemReplication

		if itemReplication and arg and arg2 then
			local n2 = 1

			for _, v2 in ipairs({ "Quantity", "Amount", "Stack", "Count" }) do
				if itemReplication[v2] and typeof(itemReplication[v2].readClient) == "function" then
					local ok, result = pcall(function()
						return itemReplication[v2].readClient(arg, arg2)
					end)

					if ok and typeof(result) == "number" and result > n2 then
						n2 = result
					end
				end
			end

			return n2
		end

		return 1
	end

	local function fn16(arg, arg2)
		local itemReplication = fn14().ItemReplication

		if itemReplication and itemReplication.Mastery and typeof(itemReplication.Mastery.readClient) == "function" and arg and arg2 then
			local ok, result = pcall(function()
				return itemReplication.Mastery.readClient(arg, arg2)
			end)

			if ok and typeof(result) == "number" then
				return result
			end
		end

		return nil
	end

	ResolveInventoryItemConfig = function(arg)
		if not arg then
			return nil
		end
		local itemConfig = fn14().ItemConfig
		if not itemConfig then
			return nil
		end

		local ok, result = pcall(function()
			return itemConfig.match(arg)
		end)

		if not ok or result == nil then
			return nil
		end
		local flag2 = type(result) == "table"

		if flag2 then
			flag2 = result.Name or result.Index or result.Display or result.Moveset
		end

		if flag2 then
			return result
		end

		if type(result) == "table" and type(result.asNullable) == "function" then
			local ok2, result2 = pcall(function()
				return result:asNullable()
			end)

			if ok2 and result2 then
				return result2
			end
		end

		if type(result) == "table" and type(result.unwrap) == "function" then
			local ok2, result2 = pcall(function()
				if type(result.isOk) == "function" then
					if result:isOk() then
						return result:unwrap()
					end
					return
				end

				return result:unwrap()
			end)

			if ok2 and result2 then
				return result2
			end
		end

		return nil
	end

	MergeInventoryEntry = function(arg, arg2, arg3)
		if type(arg) ~= "table" or type(arg2) ~= "string" or arg2 == "" or type(arg3) ~= "table" then
			return nil
		end
		local v2 = string.lower(arg2)
		local tbl7 = arg[arg2] or arg[v2]

		if type(tbl7) ~= "table" then
			tbl7 = { Name = arg2 }
		end

		for k, v3 in pairs(arg3) do
			if v3 ~= nil then
				if k == "Count" or k == "Amount" or k == "Quantity" then
					local count = math.max(tonumber(tbl7.Count) or tonumber(tbl7.Amount) or 0, tonumber(v3) or 0)
					tbl7.Count = count
					tbl7.Amount = count
					tbl7.Quantity = count
				elseif k ~= "Name" or not tbl7.Name then
					tbl7[k] = v3
				end
			end
		end

		tbl7.Name = tbl7.Name or arg2
		arg[arg2] = tbl7
		arg[v2] = tbl7
		return tbl7
	end

	ReadItemFromInventoryController = function(arg, arg2)
		local backpack = arg2 or scriptStorage.Backpack
		local inventoryController = fn14().InventoryController
		local n2 = 0
		local flag2 = false

		if inventoryController then
			local ok, result = pcall(function()
				return inventoryController:GetIfInitialized()
			end)

			if ok and result then
				local ok2, result2 = pcall(function()
					return inventoryController:GetTiles()
				end)

				if ok2 and type(result2) == "table" then
					local v2 = arg and string.lower(arg)
					local v3 = v2 and string.gsub(v2, "%s+", "")

					for _, v4 in ipairs(result2) do
						if type(v4) == "table" and v4.ItemId then
							local v5 = ResolveInventoryItemConfig(v4.ItemId)
							local storageKey = v5 and v5.Index and v5.Index.StorageKey
							local title = v5 and v5.Display and (v5.Display.Title or v5.Display.Name) or v5 and v5.DisplayName or v5 and v5.Name
							storageKey = storageKey or title or tostring(v4.ItemId)
							local flag3 = arg == nil

							if arg and storageKey then
								local v6 = string.lower(tostring(storageKey))
								local v7 = string.gsub(v6, "%s+", "")
								local v8 = title and string.lower(tostring(title))
								local v9 = v8 and string.gsub(v8, "%s+", "")
								local v10 = string.lower(tostring(v4.ItemId))
								flag3 = v6 == v2 or v7 == v3 or v8 and (v8 == v2 or v9 == v3) or v10 == v2
							end

							if flag3 then
								local n3 = 1

								if v4.NetworkedUID then
									n3 = fn15(v4.ItemId, v4.NetworkedUID)
								end

								if type(v4.Data) == "table" then
									local num = tonumber(v4.Data.Amount or v4.Data.Quantity or v4.Data.Count)

									if num and num > n3 then
										n3 = num
									end
								end

								local num = tonumber(v4.Amount or v4.Quantity or v4.Count)

								if num and num > n3 then
									n3 = num
								end

								if type(v4.GetAmount) == "function" then
									pcall(function()
										local num2 = tonumber(v4:GetAmount())

										if num2 and num2 > n3 then
											n3 = num2
										end
									end)
								end

								local n4 = tonumber(n3) or 1

								if n4 > 0 then
									n2 += n4

									if type(backpack) == "table" then
										MergeInventoryEntry(backpack, storageKey, {
											Name = storageKey,
											DisplayName = title or storageKey,
											ItemId = v4.ItemId,
											Count = n4,
											Amount = n4,
											Quantity = n4,
											Mastery = fn16(v4.ItemId, v4.NetworkedUID) or 0,
											Type = v5 and v5.Type or nil,
											Value = v5 and v5.Quality and tonumber(v5.Quality.MoneyPrice) or nil,
										})
									end
								end
							end
						end
					end

					flag2 = true
				end
			end
		end

		return n2, flag2
	end

	RefreshInventory = function()
		local backpack = {}
		local v2, v3 = ReadItemFromInventoryController(nil, backpack)
		local v4 = fn13()
		local flag2 = false

		if v4 then
			local ok, result = pcall(function()
				return v4:InvokeServer("getInventory")
			end)

			if ok and type(result) == "table" then
				for _, v5 in pairs(result) do
					if type(v5) == "table" then
						local itemId = v5.ItemId and ResolveInventoryItemConfig(v5.ItemId) or nil
						local storageKey = itemId and itemId.Index and itemId.Index.StorageKey or v5.Name or itemId and itemId.Name

						if type(storageKey) == "string" and storageKey ~= "" then
							local n2 = tonumber(v5.Count or v5.Amount or v5.Quantity) or 1
							local v6 = tonumber
							local mastery = v5.Mastery
							local mastery2

							if mastery then
								mastery2 = mastery
							else
								mastery2 = v5.Data and v5.Data.Mastery
							end

							mastery2 = mastery2 or 0
							local n3 = v6(mastery2) or 0
							local title = itemId and itemId.Display and (itemId.Display.Title or itemId.Display.Name) or itemId and itemId.Name or v5.DisplayName or v5.Name or storageKey
							local num = tonumber(v5.Price or v5.TradePrice)

							if not num or num <= 0 then
								num = itemId and itemId.Quality and tonumber(itemId.Quality.MoneyPrice) or nil
							end

							if not num or num <= 0 then
								num = tonumber(v5.Value)
							end

							local v7 = MergeInventoryEntry(backpack, storageKey, {
								Name = storageKey,
								DisplayName = title,
								ItemId = v5.ItemId,
								Count = n2,
								Amount = n2,
								Quantity = n2,
								Type = v5.Type or itemId and itemId.Type,
								Value = num,
								Mastery = n3,
								MasteryRequirements = v5.MasteryRequirements or {},
							})

							if v7 and type(v5.Name) == "string" and v5.Name ~= "" and v5.Name ~= storageKey then
								backpack[v5.Name] = v7
								backpack[string.lower(v5.Name)] = v7
							end
						end
					end
				end

				flag2 = true
			end
		end

		if v3 or flag2 then
			scriptStorage.Backpack = backpack
		end

		return v3 or flag2
	end

	CheckSpecialMicrochip = function()
		local localPlayer2 = game:GetService("Players").LocalPlayer
		local character = localPlayer2 and localPlayer2.Character
		localPlayer2 = localPlayer2 and localPlayer2:FindFirstChild("Backpack")
		local tbl7 = { ["special microchip"] = true, specialmicrochip = true, microchip = true }

		if character then
			for _, child in ipairs(character:GetChildren()) do
				if child:IsA("Tool") then
					local v2 = string.gsub(string.lower(child.Name), "%s+", "")
					if tbl7[string.lower(child.Name)] or tbl7[v2] then
						return true
					end
				end
			end
		end

		if localPlayer2 then
			for _, child in ipairs(localPlayer2:GetChildren()) do
				if child:IsA("Tool") then
					local v2 = string.gsub(string.lower(child.Name), "%s+", "")
					if tbl7[string.lower(child.Name)] or tbl7[v2] then
						return true
					end
				end
			end
		end

		local tools = scriptStorage.Tools

		if type(tools) == "table" then
			if tools["Special Microchip"] or tools["special microchip"] or tools.Microchip then
				return true
			end
		end

		local backpack = scriptStorage.Backpack

		if type(backpack) == "table" then
			if backpack["Special Microchip"] or backpack["special microchip"] or backpack.Microchip then
				return true
			end
		end

		return false
	end

	HasMeleeTool = function(arg)
		if type(arg) ~= "string" or arg == "" then
			return false
		end
		local localPlayer2 = game:GetService("Players").LocalPlayer
		local character = localPlayer2 and localPlayer2.Character
		localPlayer2 = localPlayer2 and localPlayer2:FindFirstChild("Backpack")
		local tbl7 = MeleeToolAliases[arg] or { arg }
		local tbl8 = {}

		for _, v2 in ipairs(tbl7) do
			tbl8[string.lower(v2)] = true
			tbl8[string.gsub(string.lower(v2), "%s+", "")] = true
		end

		for _, v2 in ipairs(tbl7) do
			if character and character:FindFirstChild(v2) or localPlayer2 and localPlayer2:FindFirstChild(v2) then
				return true
			end
		end

		if character then
			for _, child in ipairs(character:GetChildren()) do
				local isTool = child:IsA("Tool")

				if isTool then
					isTool = child.ToolTip == "Melee" or child:FindFirstChild("Melee") or child:FindFirstChild("Combat")
				end

				if isTool then
					local v2 = string.lower(child.Name)
					local v3 = string.gsub(v2, "%s+", "")
					if tbl8[v2] or tbl8[v3] then
						return true
					end
				end
			end
		end

		if localPlayer2 then
			for _, child in ipairs(localPlayer2:GetChildren()) do
				local isTool = child:IsA("Tool")

				if isTool then
					isTool = child.ToolTip == "Melee" or child:FindFirstChild("Melee") or child:FindFirstChild("Combat")
				end

				if isTool then
					local v2 = string.lower(child.Name)
					local v3 = string.gsub(v2, "%s+", "")
					if tbl8[v2] or tbl8[v3] then
						return true
					end
				end
			end
		end

		return false
	end

	GetMeleeIdByName = function(arg)
		if type(arg) ~= "string" or arg == "" then
			return nil
		end
		return tbl5[arg] or tbl5[string.lower(arg)] or tbl5[string.gsub(string.lower(arg), "%s+", "")]
	end

	local tbl7 = { LastUpdate = 0, Tiles = nil, UpdateInterval = 2 }

	checkMeleeMastery = function(arg)
		if type(arg) ~= "string" or arg == "" then
			return false, "", 0
		end
		local tbl8 = MeleeToolAliases[arg] or { arg }
		local tbl9 = {}

		for _, v2 in ipairs(tbl8) do
			tbl9[string.lower(v2)] = true
			tbl9[string.gsub(string.lower(v2), "%s+", "")] = true
		end

		local v2 = fn14()
		local inventoryController = v2.InventoryController
		local itemReplication = v2.ItemReplication

		local invHave = false
		if inventoryController and v2.ItemConfig and itemReplication then
			local invOk, invFound, invName, invMastery = pcall(function()
				local now = os.clock()

				if not tbl7.Tiles or now - tbl7.LastUpdate > tbl7.UpdateInterval then
					if inventoryController:GetIfInitialized() then
						tbl7.Tiles = inventoryController:GetTiles()
						tbl7.LastUpdate = now
					end
				end

				if type(tbl7.Tiles) == "table" then
					for _, tile in ipairs(tbl7.Tiles) do
						if type(tile) == "table" and tile.ItemId then
							local v3 = ResolveInventoryItemConfig(tile.ItemId)

							if (v3 and v3.Moveset and v3.Moveset.Type == "FightingStyle" or v3 and v3.Type == "Melee" or v3 and v3.Category == "Melee") and v3.Index and v3.Index.StorageKey then
								local v4 = string.lower(v3.Index.StorageKey)
								local v5 = string.gsub(v4, "%s+", "")

								if tbl9[v4] or tbl9[v5] then
									local networkedUID = itemReplication.Mastery and type(itemReplication.Mastery.readClient) == "function" and tile.NetworkedUID
									local n2 = 0

									if networkedUID then
										n2 = itemReplication.Mastery.readClient(tile.ItemId, tile.NetworkedUID) or 0
									end

									return true, arg, tonumber(n2) or 0
								end
							end
						end
					end
				end
			end)
			if invOk then
				invHave = invFound == true
				if invHave and (tonumber(invMastery) or 0) > 0 then
					return true, invName, invMastery
				end
			elseif getgenv().Debugging then
				warn("[checkMeleeMastery] inventory lookup failed:", invFound)
			end
		end

		local localPlayer2 = game:GetService("Players").LocalPlayer
		local character = localPlayer2 and localPlayer2.Character
		local backpack = localPlayer2 and localPlayer2:FindFirstChild("Backpack")
		local flag2 = false
		local n2 = 0

		local function fn17(arg2)
			if not arg2 then
				return
			end

			for _, child in ipairs(arg2:GetChildren()) do
				if child:IsA("Tool") then
					local v3 = string.lower(child.Name)
					local v4 = string.gsub(v3, "%s+", "")

					if tbl9[v3] or tbl9[v4] then
						flag2 = true
						local level = child:FindFirstChild("Level")

						if level and (level:IsA("IntValue") or level:IsA("NumberValue") or level:IsA("ValueBase")) then
							local n3 = tonumber(level.Value) or 0

							if n2 < n3 then
								n2 = n3
							end
						end
					end
				end
			end
		end

		fn17(character)
		fn17(backpack)
		localPlayer2 = localPlayer2 and localPlayer2:FindFirstChild("PlayerGui")
		localPlayer2 = localPlayer2 and localPlayer2:FindFirstChild("Main")
		local skills = localPlayer2 and localPlayer2:FindFirstChild("Skills")

		if skills then
			for _, v3 in ipairs(tbl8) do
				local v4 = skills:FindFirstChild(v3)

				if v4 then
					for _, descendant in ipairs(v4:GetDescendants()) do
						if descendant:IsA("TextLabel") and descendant.Visible and string.find(descendant.Text, "Mastery") then
							local num = tonumber(string.match(descendant.Text, "(%d+)%s*/%s*%d+") or string.match(descendant.Text, "%d+"))

							if num and num > n2 then
								n2 = num
								flag2 = true
							end
						end
					end
				end
			end
		end

		local melees = scriptStorage.Melees

		if type(melees) == "table" then
			for _, v3 in ipairs(tbl8) do
				local num = tonumber(melees[v3] or melees[string.lower(v3)])

				if num and num > n2 then
					n2 = num
					flag2 = true
				end
			end
		end

		local value = rawget(env, "Storage")

		if type(value) == "table" and type(value.Get) == "function" then
			if tbl9.godhuman and value:Get("Unlocked_Godhuman") then
				flag2 = true
			end
		end

		if flag2 or invHave or n2 > 0 then
			return true, arg, n2
		end
		return false, arg, 0
	end

	CheckCurrentMeleeProgress = function()
		local value = rawget(env, "MeleePrices")
		if type(value) ~= "table" then
			return nil
		end

		for _, v2 in ipairs(MeleesTable) do
			if v2 == "SanguineArt" then
				break
			end
			local v3 = value[v2]

			if type(v3) == "table" and v3.NextLevelRequirement then
				local v4, v5, v6 = checkMeleeMastery(v2)
				if v4 and v6 < v3.NextLevelRequirement then
					return { v2, v6, v3.NextLevelRequirement }
				end
			end
		end

		return nil
	end

	howtotrickfightmelee = function(arg)
		if not (arg and typeof(arg) == "Instance" and arg:IsA("Tool")) then
			return
		end
		local name = arg.Name
		local level = arg:FindFirstChild("Level")

		if level and (level:IsA("IntValue") or level:IsA("NumberValue") or level:IsA("ValueBase")) then
			local n2 = tonumber(level.Value) or 0
			scriptStorage.SwordMastery = scriptStorage.SwordMastery or {}
			scriptStorage.SwordMastery[name] = n2
			scriptStorage.Connections.ToolLevelConns = scriptStorage.Connections.ToolLevelConns or {}
			local v2 = scriptStorage.Connections.ToolLevelConns[name]

			if v2 and typeof(v2) == "RBXScriptConnection" and v2.Connected then
				v2:Disconnect()
			end

			local connection = level.Changed:Connect(function(arg2)
				local n3 = tonumber(arg2) or 0
				scriptStorage.SwordMastery[name] = n3
				local forceToUseSword = scriptStorage.ForceToUseSword

				if type(forceToUseSword) == "table" and forceToUseSword[1] == name then
					forceToUseSword[2] = n3

					if n3 >= 350 then
						scriptStorage.ForceToUseSword = nil
					end
				end
			end)

			scriptStorage.Connections.ToolLevelConns[name] = connection
			local connection2 = nil

			connection2 = arg.AncestryChanged:Connect(function(child, parent)
				if not parent then
					if connection and connection.Connected then
						connection:Disconnect()
					end

					if connection2 and connection2.Connected then
						connection2:Disconnect()
					end

					scriptStorage.Connections.ToolLevelConns[name] = nil
				end
			end)
		end

		if arg.ToolTip == "Melee" or arg:FindFirstChild("Melee") or arg:FindFirstChild("Combat") then
			scriptStorage.Connections.MeleeConns = scriptStorage.Connections.MeleeConns or {}
			local v2 = name
			local v3 = scriptStorage.Connections.MeleeConns[v2]

			if v3 and typeof(v3) == "RBXScriptConnection" and v3.Connected then
				v3:Disconnect()
			end

			local isIntValue

			if level then
				isIntValue = level:IsA("IntValue") or level:IsA("NumberValue") or level:IsA("ValueBase")
			else
				isIntValue = level
			end

			if isIntValue then
				local connection = level.Changed:Connect(function(arg2)
					local mastery = tonumber(arg2) or 0
					scriptStorage.Melees[v2] = mastery
					scriptStorage.CurrentMeleeData.Name = v2
					scriptStorage.CurrentMeleeData.Mastery = mastery

					if type(refreshmelee) == "function" then
						refreshmelee()
					end
				end)

				scriptStorage.Connections.MeleeConns[v2] = connection
				local mastery = tonumber(level.Value) or 0
				scriptStorage.CurrentMeleeData.Name = v2
				scriptStorage.CurrentMeleeData.Mastery = mastery
				scriptStorage.Melees[v2] = mastery

				if type(refreshmelee) == "function" then
					refreshmelee()
				end

				local connection2 = nil

				connection2 = arg.AncestryChanged:Connect(function(child, parent)
					if not parent then
						if connection and connection.Connected then
							connection:Disconnect()
						end

						if connection2 and connection2.Connected then
							connection2:Disconnect()
						end

						scriptStorage.Connections.MeleeConns[v2] = nil
					end
				end)
			else
				scriptStorage.CurrentMeleeData.Name = v2
				local v4, v5, v6 = checkMeleeMastery(v2)
				scriptStorage.CurrentMeleeData.Mastery = v6
				scriptStorage.Melees[v2] = v6

				if type(refreshmelee) == "function" then
					refreshmelee()
				end
			end
		end
	end

	refreshmelee = function(arg)
		local str = ""
		local melees = scriptStorage.Melees

		if type(melees) == "table" then
			for k, melee in pairs(melees) do
				str ..= tostring(k) .. ": " .. tostring(melee) .. " "
			end
		end

		if str == "" then
			str = "[0]"
		end

		if arg then
			return str
		end

		if scriptStorage.Interface and type(SetText) == "function" then
			pcall(function()
				SetText("Melees", str)
			end)
		elseif type(rawget(env, "SetText")) == "function" then
			pcall(function()
				env.SetText("Melees", str)
			end)
		end

		return str
	end
end

env.ResolveInventoryItemConfig = ResolveInventoryItemConfig
env.MergeInventoryEntry = MergeInventoryEntry
env.ReadItemFromInventoryController = ReadItemFromInventoryController
env.RefreshInventory = RefreshInventory
env.checkItemQuantity = checkItemQuantity
env.CheckSpecialMicrochip = CheckSpecialMicrochip
env.HasMeleeTool = HasMeleeTool
env.GetMeleeIdByName = GetMeleeIdByName
env.checkMeleeMastery = checkMeleeMastery
env.CheckCurrentMeleeProgress = CheckCurrentMeleeProgress
env.howtotrickfightmelee = howtotrickfightmelee
env.refreshmelee = refreshmelee
env.MeleeToolAliases = MeleeToolAliases
env.MeleesTable = MeleesTable
env.MeleesId = MeleesId

CheckItem = function(arg)
	if type(arg) ~= "string" or arg == "" then
		return false
	end
	local localPlayer2 = game:GetService("Players").LocalPlayer
	local character = localPlayer2 and localPlayer2.Character
	localPlayer2 = localPlayer2 and localPlayer2:FindFirstChild("Backpack")
	if character and character:FindFirstChild(arg) or localPlayer2 and localPlayer2:FindFirstChild(arg) then
		return true
	end

	if arg == "Special Microchip" or arg == "special microchip" then
		return CheckSpecialMicrochip()
	end

	if HasMeleeTool(arg) then
		return true
	end
	local v2, v3, v4 = checkItemQuantity(arg)
	if v2 and v4 > 0 then
		return true
	end
	return false
end

Equip = function(arg)
	local ok, result = pcall(function()
		local v2 = localPlayer.Backpack:FindFirstChild(arg)
		if localPlayer.Character:FindFirstChild("Humanoid") and v2 then
			localPlayer.Character:FindFirstChild("Humanoid"):EquipTool(v2)
			return true
		end

		if localPlayer.Character:FindFirstChild(arg) then
			return true
		end
	end)
	if not ok and getgenv().Debugging then
		warn("[Equip] failed:", result)
	end
	return ok and result == true
end

ClickOnPart = function(arg)
	local VirtualInputManager2 = game:GetService("VirtualInputManager")
	local currentCamera = workspace.CurrentCamera
	local v2 = currentCamera:WorldToViewportPoint(arg.Position)
	local x = v2.X
	local y = v2.Y
	currentCamera.CFrame = CFrame.new(currentCamera.CFrame.Position, arg.Position)
	VirtualInputManager2:SendMouseButtonEvent(x, y, 0, true, game, 0)
	task.wait(0.5)
	VirtualInputManager2:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

getgenv().LocalPlayerInv = {}
getgenv().GetServerData = {}

task.spawn(function()
	while task.wait(1) do
		pcall(function()
			local commF = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") and game:GetService("ReplicatedStorage").Remotes:FindFirstChild("CommF_") or game:GetService("ReplicatedStorage"):FindFirstChild("CommF_")
			if not commF then
				return
			end
			local response = commF:InvokeServer("getInventory")
			local tbl5 = {}

			pcall(function()
				tbl5 = require(game.ReplicatedStorage.Controllers.SkinController).GetInventory()
			end)

			local tbl6 = { "Gun", "Wear", "Sword" }
			local tbl7 = { "Blox Fruit", "Gun", "Wear", "Sword", "Material" }

			if response and type(response) == "table" then
				local localPlayerInv = { All = response, Weapons = {} }

				for _, v2 in pairs(response) do
					if type(v2) == "table" and v2.Type then
						if not localPlayerInv[v2.Type] then
							localPlayerInv[v2.Type] = {}
						end

						if table.find(tbl6, v2.Type) then
							table.insert(localPlayerInv.Weapons, v2)
						end

						table.insert(localPlayerInv[v2.Type], v2)
					end
				end

				if type(tbl5) == "table" then
					for _, v2 in pairs(tbl5) do
						if type(v2) == "table" and v2.Type then
							if not localPlayerInv[v2.Type] then
								localPlayerInv[v2.Type] = {}
							end

							if tonumber(v2.Count) and tonumber(v2.Count) > 0 then
								table.insert(localPlayerInv[v2.Type], v2)
							end
						end
					end
				end

				for _, v2 in pairs(tbl7) do
					if not localPlayerInv[v2] then
						localPlayerInv[v2] = {}
					end
				end

				getgenv().LocalPlayerInv = localPlayerInv
			end

			if Sea2 or Sea3 then
				pcall(function()
					getgenv().GetServerData.ColorDealer = commF:InvokeServer("ColorsDealer", "1")
				end)
			end
		end)
	end
end)

local lib2 = loadstring(game:HttpGet("https://pastefy.app/XY37yNsQ/raw"))()

MainRejoin = function()
	spawn(function()
		task.wait(60)
		game:Shutdown()
	end)

	game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", game.JobId)
end

MainTravel = function(arg, arg2, arg3)
	local ok, result = pcall(function()
		return lib2:CreateScreen({ Duration = arg, Reason = arg2 })
	end)

	if not ok then
		print("[DEBUG] CreateScreen failed: " .. tostring(result) .. ", traveling directly")

		while true do
			Travel(arg3)
			task.wait(5)
		end
	else
		if result ~= "Success" then
			task.wait(15)
			return
		end

		while true do
			Travel(arg3)
			task.wait(5)
		end
	end
end

MainServerHop = function(arg, arg2, ...)
	local tbl5 = { ... }

	local ok, result = pcall(function()
		return lib2:CreateScreen({ Duration = arg, Reason = arg2 })
	end)

	if not ok or result == "Success" then
		TrueServerHop(table.unpack(tbl5))
	else
		task.wait(15)
	end
end

GetWeaponSmith = function(arg, retries)
	local tbl5 = { ["0"] = {}, ["1"] = {}, ["2"] = {}, ["3"] = {}, ["4"] = {} }
	local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("getInventoryWeapons")

	if response then
		for _, v2 in pairs(response) do
			if v2.Type == arg and not DataSave.BlackSmith[v2.Name] then
				if tbl5[tostring(v2.Rarity)] then
					local name = v2.Name
					table.insert(tbl5[tostring(v2.Rarity)], name)
				else
					print("Errored At ", v2.Rarity)
				end
			end
		end

		for i = 4, 1, -1 do
			local list = tbl5[tostring(i)]
			if list and list[1] ~= nil then
				return list[1]
			end
		end

		return
	end

	retries = (retries or 0) + 1
	if retries > 5 then
		return nil
	end
	task.wait(1)
	return GetWeaponSmith(arg, retries)
end

local fn13

do
	local places = {}

	for k in pairs(tbl2.Places[currentPlaceKey]) do
		table.insert(places, k)
	end

	SwitchWeaponSmith = function(arg)
		local v2 = GetWeaponSmith(arg)

		if v2 then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", v2)
		end
	end

	fn13 = function(arg)
		for _, child in pairs(game:GetService("ReplicatedStorage").NPCs:GetChildren()) do
			if child.Name == arg then
				return child
			end
		end

		for _, child in pairs(workspace.NPCs:GetChildren()) do
			if child.Name == arg then
				return child
			end
		end
	end

	MirageFunctions = {
		GetFruitDealerNPC = function()
			return fn13("Advanced Fruit Dealer")
		end,
		GetMirageIsland = function()
			return game:GetService("Workspace").Map:FindFirstChild("MysticIsland")
		end,
		LookAtMoon = function()
			pcall(function()
				local cframe3 = CFrame.new
				local lighting = game.Lighting
				game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart").CFrame = cframe3(game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart").Position, game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart").Position + lighting:GetMoonDirection())
			end)

			workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, game:GetService("Lighting"):GetMoonDirection() + workspace.CurrentCamera.CFrame.Position)
		end,
	}

	MirageFunctions.GetGear = function()
		if not MirageFunctions.GetMirageIsland() then
			return
		end
		CheckN = true
		local v2 = pairs
		local v3 = MirageFunctions.GetMirageIsland()

		for _, child in v2(v3:GetChildren()) do
			if child:IsA("MeshPart") and child.Name == "Part" and child.Transparency ~= 1 then
				return child
			end
		end

		CheckN = false
	end

	MirageFunctions.TweenGear = function()
		local v2 = MirageFunctions.GetGear()

		if v2 then
			CheckN = true

			pcall(function()
				DoTween2(v2.CFrame, function()
					return v2 and v2.Parent
				end)
			end)

			CheckN = false
		end
	end

	MirageFunctions.IsRendered = function()
		if not MirageFunctions.GetMirageIsland() then
			return
		end

		if #MirageFunctions.GetMirageIsland().npcspawn:GetChildren() == 0 then
			return
		end
		return true
	end

	MirageFunctions.GetHighestPlace = function()
		if not MirageFunctions.GetMirageIsland() then
			return
		end

		if not MirageFunctions.IsRendered() then
			return
		end
		local tbl5 = { "BiggTree" }
		local v2 = ipairs
		local v3 = MirageFunctions.GetMirageIsland()
		local n2 = 0
		local v4 = nil

		for _, descendant in v2(v3:GetDescendants()) do
			if descendant.ClassName == "Model" and not table.find(tbl5, descendant.Name) then
				local y = descendant.WorldPivot.Y

				if y > n2 then
					n2 = y
					v4 = descendant
				end
			end
		end

		return v4
	end

	MirageFunctions.TweenFruitDealer = function()
		local v2 = MirageFunctions.GetFruitDealerNPC()

		if v2 then
			pcall(function()
				DoTween2(v2.Head, function()
					return v2 and v2.Head
				end)
			end)
		end
	end

	MirageFunctions.TweenHighestPlace = function()
		if not MirageFunctions.IsRendered() then
			DoTween2(MirageFunctions.GetMirageIsland().WorldPivot.Position)
			task.wait(2)
		end

		local v2 = MirageFunctions.GetHighestPlace()

		if v2 then
			DoTween2(v2.WorldPivot + Vector3.new(0, 210, 0))
		end
	end

	ObservationManager = {}

	ObservationManager.IsActive = function()
		if getrenv()._G then
			if getrenv()._G.OM and getrenv()._G.OM.active then
				return getrenv()._G.OM.active
			end
			return false
		end

		for _, child in pairs(game:GetService("Players").LocalPlayer.PlayerGui:GetChildren()) do
			if child.Name == "ScreenGui" then
				if child:FindFirstChild("ImageLabel") and child:FindFirstChild("ImageLabel").BackgroundColor3 == Color3.fromRGB(255, 0, 0) then
					return true
				end
			end
		end

		return false
	end

	ObservationManager.SetActive = function(arg)
		if getrenv()._G then
			if getrenv()._G.OM then
				getrenv()._G.OM:setActive(arg)
				game:GetService("ReplicatedStorage").Remotes.CommE:FireServer("Ken", arg)
			end
		elseif ObservationManager.IsActive() ~= arg then
			VirtualUser:CaptureController()
			VirtualUser:SetKeyDown("0x65")
			wait()
			VirtualUser:SetKeyUp("0x65")
		end
	end

	RaceV4Manager = {
		TPCurrentEntrance = function()
			local v2 = RaceEntrances[localPlayer.Data.Race.Value]

			if (fn4(localPlayer.Character).Position - Vector3.new(28286.355, 14896.508, 102.624695)).magnitude >= 4000 then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(28286.355, 14896.508, 102.624695))
				task.wait(0.5)
			end

			if type(v2) == "table" then
				for _, v3 in pairs(v2) do
					fn4(localPlayer.Character).CFrame = v3
					task.wait(2)
				end
			else
				fn4(localPlayer.Character).CFrame = v2
			end
		end,
		TPAcientClock = function()
			if Alive() then
				if (fn4(localPlayer.Character).Position - Vector3.new(28286.355, 14896.508, 102.624695)).magnitude > 4000 then
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(28286.355, 14896.508, 102.624695))
				end

				task.wait()
				DoTween2(CFrame.new(29551.474609375, 15068.7197265625, -84.865547180175781))
			end
		end,
		TPTempleOfTime = function()
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(28286.355, 14896.508, 102.624695))
		end,
	}

	ShipController = {
		GetSitBoat = function()
		end,
		GetBoat = function()
			for _, child in pairs(game:GetService("Workspace").Boats:GetChildren()) do
				if child:FindFirstChild("Owner") and child.Owner.Value == game.Players.LocalPlayer and child:FindFirstChild("VehicleSeat") then
					return child
				end
			end

			return false
		end,
	}

	ShipController.TPCurrentShip = function()
		if ShipController.GetBoat() then
			local cFrame = localPlayer.Character.HumanoidRootPart.CFrame
			ShipController.GetBoat().VehicleSeat.CFrame = cFrame
		end
	end

	ShipController.IsValid = function(arg)
		if arg and arg.Parent and arg.VehicleSeat then
			return true
		end
	end

	SeaManager = {}
	ItemsUiController = {}

	ItemsUiController.YoruV2 = function()
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("RobotTalk")
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("IndraTalk")

		for i = 1, 3 do
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoveLetter", i)
		end

		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("RobotTalk")
	end

	SkillsController = { Weapon = {}, Skills = {} }
	RequirementGuitar = { Ectoplasm = 250, Bones = 500, ["1"] = false, ["2"] = false }

	RequirementGod = {
		["Mystic Droplet"] = 10,
		["Magma Ore"] = 20,
		["Fish Tail"] = 20,
		["Dragon Scale"] = 10,
		["1"] = false,
		["2"] = false,
		["3"] = false,
		["4"] = false,
	}

	ChestCount = 0
	AllSeaEvents = { "TerrorShark", "Ship", "Piranha", "SeaBeast", "Shark" }
	SeaEventsController = {}
	FruitTable = {}
	FruitPrice = {}

	CloneTable = function(arg)
		local tbl5 = {}

		for i = 1, #arg do
			tbl5[i] = arg[i]
		end

		return tbl5
	end

	Travel = function(arg)
		if arg == "Sea1" or arg == "2753915549" then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelMain")
		end

		if arg == "Sea2" or arg == "4442272183" then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelDressrosa")
		end

		if arg == "Sea3" or arg == "7449423635" then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelZou")
		end
	end

	FruitRemote = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetFruits")
	StoreFruitTable = CloneTable(FruitRemote)

	for _, v2 in pairs(StoreFruitTable) do
		FruitPrice[v2.Name] = v2.Price
	end

	for _, v2 in pairs(StoreFruitTable) do
		for k, v3 in pairs(v2) do
			if k == "Name" then
				table.insert(FruitTable, v3)
			end
		end
	end

	IslandHub = {}
	IslandHub.TPCurrentEntrance = RaceV4Manager.TPCurrentEntrance
	IslandHub.TPAcientClock = RaceV4Manager.TPAcientClock
	IslandHub.__StrGetPlayers = strGetPlayers
	IslandHub.TPCurrentShip = ShipController.TPCurrentShip
	IslandHub.YoruV2 = ItemsUiController.YoruV2
	IslandHub.StopTween = StopTween
	IslandHub.Travel = Travel

	IslandHub.TweenSelectedPlace = function()
		if getgenv().IslandVariable and getgenv().IslandVariable.SelectedPlace then
			DoTween2(tbl2.Places[currentPlaceKey][getgenv().IslandVariable.SelectedPlace])
		end
	end

	IslandHub.TweenSelectedNPC = function()
		if getgenv().IslandVariable and getgenv().IslandVariable.SelectedNPC then
			DoTween2(fn4(NPCInstances[getgenv().IslandVariable.SelectedNPC]).CFrame)
		end
	end

	IslandHub.TrueServerHop = TrueServerHop

	IslandHub.RedeemAllCode = function()
		for _, v2 in pairs(tbl3) do
			game:GetService("ReplicatedStorage").Remotes.Redeem:InvokeServer(v2)
		end
	end

	IslandHub.RemoveEnemiesStun = function()
		if fluxus then
			for _, v2 in pairs(getconnections(game.ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("BodyMover").OnClientEvent)) do
				v2:Disconnect()
			end
		end
	end

	IslandHub.NightAtmosphere = function()
		game:GetService("Lighting").LightingLayers.Night.Intensity.Value = game:GetService("Lighting").LightingLayers.Night.Intensity.Value == 0 and 1 or 0
	end

	IslandHub.DarkAtmosphere = function()
		game:GetService("Lighting").LightingLayers.DarkFog.Intensity.Value = game:GetService("Lighting").LightingLayers.DarkFog.Intensity.Value == 0 and 1 or 0
	end

	IslandHub.TPTempleOfTime = RaceV4Manager.TPTempleOfTime
	IslandHub.TweenGear = MirageFunctions.TweenGear
	IslandHub.TweenFruitDealer = MirageFunctions.TweenFruitDealer
	IslandHub.TweenHighestPlace = MirageFunctions.TweenHighestPlace
	getgenv().IslandCaller = {}
	getgenv().IslandVariable = {}
	local materialName = tbl2.MaterialName
	getgenv().IslandVariable.MaterialName = materialName
	local v2 = GatePos
	getgenv().IslandVariable.GatePos = v2
	local v3 = AutoChip
	getgenv().IslandVariable.AutoChip = v3
	local items = tbl2.Items
	getgenv().IslandVariable.Items = items
	getgenv().IslandVariable.__Places = places
end

local v2 = ListNpc
getgenv().IslandVariable.__NPCs = v2

setmetatable(IslandCaller, {
	__call = function(arg, arg2, ...)
		local v3 = IslandHub[arg2]
		if type(v3) == "function" then
			return v3(...)
		end
	end,
	__index = function()
	end,
	__newindex = function()
	end,
	__metatable = "Dit Me May",
	__pairs = function()
	end,
	__ipairs = function()
	end,
})

Click = function()
	pcall(function()
		if Alive() then
			local VirtualUser2 = game:GetService("VirtualUser")
			VirtualUser2:CaptureController()
			VirtualUser2:ClickButton1(Vector2.new(851, 158), game:GetService("Workspace").Camera.CFrame)
		end
	end)
end

Press = function(arg, arg2)
	if not Pressing then
		local tool = localPlayer.Character:FindFirstChildOfClass("Tool")

		if tool then
			local name = tool.Name
			task.wait()

			if (function()
				if not tool.ToolTip then
					return
				end

				if name == "Summon Sea Beast" or tool.ToolTip == "Wear" then
					return
				end

				if not (localPlayer.PlayerGui.Main and localPlayer.PlayerGui.Main.Skills) then
					return
				end

				if not (localPlayer.PlayerGui.Main.Skills[name] and localPlayer.PlayerGui.Main.Skills[name]:FindFirstChild(arg)) then
					return
				end
				return true
			end)() then
				if NotCooldown(arg, name) then
					Pressing = true
					VirtualInputManager:SendKeyEvent(true, arg, false, game)

					if not (arg2 == nil or typeof(arg2) ~= "number" or arg2 == 0) then
						task.wait(arg2)
					end

					VirtualInputManager:SendKeyEvent(false, arg, false, game)
					Pressing = false
				end
			end
		end
	end
end

do
	local module = nil

	local function fn14()
		if module and module.Data and module.Data.QuestData then
			return module
		end

		pcall(function()
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			ReplicatedStorage = ReplicatedStorage and ReplicatedStorage:FindFirstChild("GuideModule")
			local guideData = ReplicatedStorage and ReplicatedStorage:FindFirstChild("GuideData")

			if guideData then
				module = require(guideData)
			end
		end)

		return module
	end

	local function cleanStr(arg)
		if not arg then
			return ""
		end
		local v3 = string.gsub(tostring(arg), "[%p%c%s]", "")
		return string.lower(v3)
	end

	local function normalizeMobName(arg)
		if not arg then
			return ""
		end
		local v3 = cleanStr(arg)
		local str

		if string.sub(v3, 1, 6) == "defeat" then
			str = string.sub(v3, 7)
		else
			str = v3
		end

		local v4 = string.gsub(str, "^%d+", "")
		local str2

		if string.sub(v4, 1, 3) ~= "the" then
			str2 = v4
		else
			str2 = string.sub(v4, 4)
		end

		return (string.gsub(str2, "^military", "mil"))
	end

	local function mobNameMatches(arg, arg2)
		if not arg or not arg2 or arg == "" or arg2 == "" then
			return false
		end
		local v3 = normalizeMobName(arg)
		local v4 = normalizeMobName(arg2)
		if v3 == "" or v4 == "" then
			return false
		end

		if v3 == v4 then
			return true
		end
		local v5 = string.gsub(v3, "s$", "")
		local v6 = string.gsub(v4, "s$", "")
		if v5 ~= "" and v5 == v6 then
			return true
		end

		if (v3 == "bobby" or v3 == "chef" or v5 == "bobby" or v5 == "chef") and (v4 == "bobby" or v4 == "chef" or v6 == "bobby" or v6 == "chef") then
			return true
		end

		if (v3 == "fajita" or v3 == "orbitus" or v5 == "fajita" or v5 == "orbitus") and (v4 == "fajita" or v4 == "orbitus" or v6 == "fajita" or v6 == "orbitus") then
			return true
		end

		if (v3 == "milsoldier" or v3 == "militarysoldier") and (v4 == "milsoldier" or v4 == "militarysoldier") then
			return true
		end

		if (v3 == "milspy" or v3 == "militaryspy") and (v4 == "milspy" or v4 == "militaryspy") then
			return true
		end
		return false
	end

	GetActiveQuestData = function()
		local v3 = fn14()

		if v3 and v3.Data and v3.Data.QuestData then
			local questData = v3.Data.QuestData
			local internalQuestName = questData.InternalQuestName or ""
			return true, questData.Info and (questData.Info.CustomTitle or questData.Info.Name) or internalQuestName, questData.Info and questData.Info.Name or "", internalQuestName, questData
		end

		local playerGui = localPlayer and localPlayer:FindFirstChild("PlayerGui")

		if playerGui then
			local trackedQuestFrame = playerGui:FindFirstChild("TrackedQuestFrame")

			if trackedQuestFrame and trackedQuestFrame.Enabled and trackedQuestFrame:FindFirstChild("Frame") and trackedQuestFrame.Frame.Visible then
				local description = trackedQuestFrame.Frame:FindFirstChild("description", true)
				description = description and description.Text or ""
				local textLabel = trackedQuestFrame.Frame:FindFirstChild("textLabel", true)
				return true, textLabel and textLabel.Text or description, description, "", nil
			end

			local quest = playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("Quest")

			if quest and quest.Visible then
				local title = quest:FindFirstChild("Container") and quest.Container:FindFirstChild("QuestTitle") and quest.Container.QuestTitle:FindFirstChild("Title")
				local text = title and title.Text or ""
				return true, text, text, "", nil
			end
		end

		return false, "", "", "", nil
	end

	HasActiveQuest = function(arg)
		local v3, v4, v5, v6 = GetActiveQuestData()
		if not v3 then
			return false
		end

		if not arg or arg == "" then
			return true
		end

		if v5 ~= "" and mobNameMatches(v5, arg) then
			return true
		end

		if v4 ~= "" and mobNameMatches(v4, arg) then
			return true
		end

		if v6 ~= "" and mobNameMatches(v6, arg) then
			return true
		end
		return false
	end

	FindQuest = function(arg, arg2)
		if not arg2 or arg2 == "" then
			return false
		end

		if arg and type(arg) == "string" and arg ~= "" then
			if mobNameMatches(arg, arg2) then
				return true
			end
		end

		local v3, v4, v5, v6 = GetActiveQuestData()

		if v3 then
			if v5 ~= "" and mobNameMatches(v5, arg2) then
				return true
			end

			if v4 ~= "" and mobNameMatches(v4, arg2) then
				return true
			end

			if v6 ~= "" and mobNameMatches(v6, arg2) then
				return true
			end
		end

		return false
	end

	if getgenv then
		getgenv().CleanStr = cleanStr
		getgenv().NormalizeMobName = normalizeMobName
		getgenv().MobNameMatches = mobNameMatches
		local v3 = GetActiveQuestData
		getgenv().GetActiveQuestData = v3
		local v4 = HasActiveQuest
		getgenv().HasActiveQuest = v4
		local v5 = FindQuest
		getgenv().FindQuest = v5
	end

	env.CleanStr = cleanStr
	env.NormalizeMobName = normalizeMobName
	env.MobNameMatches = mobNameMatches
end

env.GetActiveQuestData = GetActiveQuestData
env.HasActiveQuest = HasActiveQuest
env.FindQuest = FindQuest

task.spawn(function()
	pcall(function()
		local playerGui = localPlayer:WaitForChild("PlayerGui", 15)
		playerGui = playerGui and playerGui:WaitForChild("Main", 15)
		local quest = playerGui and playerGui:WaitForChild("Quest", 15)
		if not quest then
			return
		end
		local title = quest:FindFirstChild("Container") and quest.Container:FindFirstChild("QuestTitle") and quest.Container.QuestTitle:FindFirstChild("Title")

		local function fn14(arg, arg2)
			pcall(function()
				if arg then
					quest.Visible = true

					if title and arg2 and arg2 ~= "" then
						title.Text = "DEFEAT " .. string.upper(tostring(arg2))
					end
				else
					quest.Visible = false
				end
			end)
		end

		local v3, v4, v5 = GetActiveQuestData()
		fn14(v3, v5)

		pcall(function()
			local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
			remotes = remotes and remotes:FindFirstChild("QuestUpdate")

			if remotes and remotes.OnClientEvent then
				remotes.OnClientEvent:Connect(function(arg)
					if arg and type(arg) == "table" then
						fn14(true, arg.Info and arg.Info.Name or arg.InternalQuestName or "Quest")
					else
						fn14(false, "")
					end
				end)
			end
		end)

		while task.wait(0.3) do
			local v6, v7, v8 = GetActiveQuestData()

			if v6 then
				if not quest.Visible then
					fn14(true, v8)
				end
			elseif quest.Visible then
				fn14(false, "")
			end
		end
	end)
end)

IsInSafeZone = function(arg)
	for _, child in pairs(game:GetService("Workspace")._WorldOrigin.SafeZones:GetChildren()) do
		if child:IsA("Part") then
			if fn9(child, arg) <= 400 and arg.Humanoid.Health >= arg.Humanoid.MaxHealth * 80 / 100 then
				return true
			end
		end
	end
end

MakeSeaEventSkill = function()
	SkillsController.Weapon = {}

	for _, v3 in pairs({ "Melee", "Blox Fruit", "Gun", "Sword" }) do
		if getgenv().Setting.SkillsSet2[v3] then
			if not table.find(SkillsController.Weapon, v3) then
				table.insert(SkillsController.Weapon, v3)
			end
		elseif table.find(SkillsController.Weapon, v3) then
			table.remove(SkillsController.Weapon, table.find(SkillsController.Weapon, v3))
		end
	end

	SkillsController.Skills = getgenv().Setting.SkillsSettingRemake["Blox Fruit"]
end

MakeMasterySkill = function()
	SkillsController.Weapon = {}
	table.insert(SkillsController.Weapon, getgenv().Setting.Mastery["Fruit/Gun"] and "Gun" or "Blox Fruit")
	SkillsController.Skills = getgenv().Setting.SkillsSettingRemake["Blox Fruit"]
end

VoidSkillController = function()
	SkillsController.Skills = {}
	SkillsController.Weapon = {}
	SkillsController.Condition = nil
	SkillsController.Idle = nil
end

AutoChip = {
	["Flame-Flame"] = "Flame",
	["Ice-Ice"] = "Ice",
	["Sand-Sand"] = "Sand",
	["Quake-Quake"] = "Quake",
	["Light-Light"] = "Light",
	["Dark-Dark"] = "Dark",
	["String-String"] = "String",
	["Rumble-Rumble"] = "Rumble",
	["Magma-Magma"] = "Magma",
	["Human-Human: Buddha"] = "Human: Buddha",
	["Bird-Bird: Phoenix"] = "Bird: Phoenix",
	["Dough-Dough"] = "Dough",
}

CanAwakenDough = function()
	local response, v3 = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack({ "RaidsNpc", "Check" }))
	return v3.Dough
end

CanAwaken = function()
	if GetLevel() < n then
		return false, "Not Enough Level 2"
	end

	if AutoChip[localPlayer.Data.DevilFruit.Value] then
		if localPlayer.Data.DevilFruit.Value == "Dough-Dough" and (not CanAwakenDough() or not Sea3) then
			return false
		end
		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("getAwakenedAbilities")

		if response and type(response) == "table" then
			for _, v3 in pairs(response) do
				if not v3.Awakened and localPlayer.Data.Fragments.Value >= v3.Cost then
					return true
				end
			end
		end
	end
end

Raid = {}

FruitFunc = {
	IgnoreStoreFruit = nil,
	HaveFruitInv = function()
		local tbl5 = {}

		if localPlayer and localPlayer.Character then
			for _, child in pairs(localPlayer.Character:GetChildren()) do
				if string.find(child.Name, "Fruit") then
					table.insert(tbl5, child)
				end
			end
		end

		if localPlayer and localPlayer:FindFirstChild("Backpack") then
			for _, child in pairs(localPlayer.Backpack:GetChildren()) do
				if string.find(child.Name, "Fruit") then
					table.insert(tbl5, child)
				end
			end
		end

		return tbl5
	end,
	HaveFruitMap = function()
		local tbl5 = {}

		for _, child in pairs(game.Workspace:GetChildren()) do
			if string.find(child.Name, "Fruit") and child.Name ~= "Fruit" then
				table.insert(tbl5, child)
			end
		end

		return tbl5
	end,
	CheckHasFruit = function()
		for _, child in pairs(game.Workspace:GetChildren()) do
			if string.find(child.Name, "Fruit") then
				return true
			end

			if child:IsA("Tool") then
				return true
			end
		end

		return false
	end,
	GetFruitBelow1M = function()
		local ok, result = pcall(function()
			return game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("getTradeInventory")
		end)

		if ok and type(result) == "table" and type(result.Items) == "table" then
			local n2 = 1000000
			local v3 = nil

			for _, item in ipairs(result.Items) do
				if type(item) == "table" and item.ItemId ~= nil then
					local flag2 = type(ResolveInventoryItemConfig) == "function" and ResolveInventoryItemConfig(item.ItemId) or nil

					if flag2 then
						local storageKey = flag2.Index and flag2.Index.StorageKey
						local title = flag2.Display and (flag2.Display.Title or flag2.Display.Name) or flag2.Name or storageKey

						if string.find(string.lower(tostring(title)), "fruit") or flag2.Name and string.find(string.lower(tostring(flag2.Name)), "fruit") or type(storageKey) == "string" and string.match(storageKey, "^([^-]+)%-(.+)$") then
							local n3 = tonumber(item.Count or item.Amount or item.Quantity) or 1
							local num = tonumber(item.Price or item.TradePrice)

							if not num or num <= 0 then
								num = flag2.Quality and tonumber(flag2.Quality.MoneyPrice) or nil
							end

							if n3 > 0 and num and num > 0 and num < n2 then
								if storageKey then
									n2 = num
									v3 = storageKey
								else
									n2 = num
									v3 = title
								end
							end
						end
					end
				end
			end

			if v3 then
				return v3
			end
		end

		local bloxFruit = getgenv().LocalPlayerInv and getgenv().LocalPlayerInv["Blox Fruit"]
		local v3 = nil

		if bloxFruit then
			local n2 = 999999999
			local name = nil

			for _, v4 in pairs(bloxFruit) do
				if v4.Value < 1000000 and v4.Value < n2 and v4.Count > 0 then
					n2 = v4.Value
					name = v4.Name
				end
			end

			v3 = name
		end

		return v3
	end,
	GetFruitAbove1M = function()
		local ok, result = pcall(function()
			return game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("getTradeInventory")
		end)

		if ok and type(result) == "table" and type(result.Items) == "table" then
			local n2 = 999999999
			local v3 = nil

			for _, item in ipairs(result.Items) do
				if type(item) == "table" and item.ItemId ~= nil then
					local flag2 = type(ResolveInventoryItemConfig) == "function" and ResolveInventoryItemConfig(item.ItemId) or nil

					if flag2 then
						local storageKey = flag2.Index and flag2.Index.StorageKey
						local display = flag2.Display
						local title

						if display then
							title = flag2.Display.Title or flag2.Display.Name
						else
							title = display
						end

						local name = title or flag2.Name or storageKey
						local name2 = string.find(string.lower(tostring(name)), "fruit") or flag2.Name and string.find(string.lower(tostring(flag2.Name)), "fruit")
						local flag3

						if name2 then
							flag3 = name2
						else
							flag3 = type(storageKey) == "string" and string.match(storageKey, "^([^-]+)%-(.+)$")
						end

						if flag3 then
							local n3 = tonumber(item.Count or item.Amount or item.Quantity) or 1
							local num = tonumber(item.Price or item.TradePrice)

							if not num or num <= 0 then
								num = flag2.Quality and tonumber(flag2.Quality.MoneyPrice) or nil
							end

							if n3 > 0 and num and num >= 1000000 and num <= 3000000 and num < n2 then
								if storageKey then
									n2 = num
									v3 = storageKey
								else
									n2 = num
									v3 = name
								end
							end
						end
					end
				end
			end

			if v3 then
				return v3
			end
		end

		local bloxFruit = getgenv().LocalPlayerInv and getgenv().LocalPlayerInv["Blox Fruit"]
		local name = nil

		if bloxFruit then
			local n2 = 999999999
			name = nil

			for _, v3 in pairs(bloxFruit) do
				if v3.Value >= 1000000 and v3.Value < n2 and v3.Value <= 3000000 and v3.Count > 0 then
					n2 = v3.Value
					name = v3.Name
				end
			end
		end

		return name
	end,
	ReloadFruit = function(ignoreStoreFruit)
		if not ignoreStoreFruit or ignoreStoreFruit == "" then
			return nil
		end
		local tbl5 = {}

		local function fn14(arg)
			if arg then
				for _, child in ipairs(arg:GetChildren()) do
					if child:IsA("Tool") then
						tbl5[child] = true
					end
				end
			end
		end

		fn14(localPlayer.Character)
		fn14(localPlayer:FindFirstChild("Backpack"))
		FruitFunc.IgnoreStoreFruit = ignoreStoreFruit

		local ok, result = pcall(function()
			return game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadFruit", ignoreStoreFruit)
		end)

		print("[FruitFunc.ReloadFruit] LoadFruit:", ignoreStoreFruit, ok, tostring(result))
		local n2 = os.clock() + 4
		local v3

		while true do
			task.wait(0.1)

			local function fn15(arg)
				if not arg then
					return nil
				end

				for _, child in ipairs(arg:GetChildren()) do
					if child:IsA("Tool") and not tbl5[child] then
						if child:GetAttribute("OriginalName") == ignoreStoreFruit or child.Name == ignoreStoreFruit or string.find(child.Name, ignoreStoreFruit) then
							return child
						end
					end
				end

				return nil
			end

			v3 = fn15(localPlayer.Character) or fn15(localPlayer:FindFirstChild("Backpack"))
			if not (v3 or os.clock() >= n2) then
				continue
			end
			break
		end

		if v3 then
			if v3.Parent == localPlayer:FindFirstChild("Backpack") and localPlayer.Character then
				local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")

				if humanoid then
					pcall(function()
						humanoid:EquipTool(v3)
					end)

					task.wait(0.2)
				end
			end

			return v3
		end

		return nil
	end,
	CanStoreFruit = function(arg)
		if not arg or not arg:IsA("Tool") then
			return false
		end

		if not string.find(arg.Name, "Fruit") and not string.find(tostring(arg), "Fruit") then
			return false
		end
		local attribute = arg:GetAttribute("OriginalName") or arg:FindFirstChild("OriginalName") and arg.OriginalName.Value or arg.Name
		if FruitFunc.IgnoreStoreFruit and (attribute == FruitFunc.IgnoreStoreFruit or arg.Name == FruitFunc.IgnoreStoreFruit) then
			return false
		end
		local n2 = localPlayer and localPlayer:FindFirstChild("Data") and localPlayer.Data:FindFirstChild("FruitCap") and localPlayer.Data.FruitCap.Value or 1

		local function fn14(arg2)
			if not arg2 or type(arg2) ~= "string" then
				return ""
			end
			return (string.gsub(string.gsub(string.gsub(string.lower(arg2), "%s*fruit%s*", ""), "%-", ""), "%s+", ""))
		end

		local v3 = fn14(attribute)
		local v4 = fn14(arg.Name)
		local bloxFruit = getgenv().LocalPlayerInv and getgenv().LocalPlayerInv["Blox Fruit"]

		if bloxFruit and type(bloxFruit) == "table" and #bloxFruit > 0 then
			for _, v5 in pairs(bloxFruit) do
				if type(v5) == "table" and v5.Name then
					local v6 = fn14(v5.Name)
					local flag2 = v6 == v3 or v6 == v4
					local flag3

					if flag2 then
						flag3 = flag2
					else
						flag3 = v3 ~= "" and string.find(v6, v3)
					end

					flag3 = flag3 or v6 ~= "" and string.find(v3, v6)

					if flag3 then
						if n2 <= (tonumber(v5.Count) or 1) then
							return false
						end
					end
				end
			end
		end

		local ok, result = pcall(function()
			return game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("getTradeInventory")
		end)

		if ok and type(result) == "table" and type(result.Items) == "table" then
			for _, item in ipairs(result.Items) do
				if type(item) == "table" and item.ItemId ~= nil then
					local flag2 = type(ResolveInventoryItemConfig) == "function" and ResolveInventoryItemConfig(item.ItemId) or nil

					if flag2 then
						local storageKey = flag2.Index and flag2.Index.StorageKey
						local title = flag2.Display and (flag2.Display.Title or flag2.Display.Name) or flag2.Name or storageKey
						local v5 = fn14(storageKey)
						local v6 = fn14(title)

						if v5 == v3 or v5 == v4 or v6 == v3 or v6 == v4 then
							if n2 <= (tonumber(item.Count or item.Amount or item.Quantity) or 1) then
								return false
							end
							continue
						end
					end
				end
			end
		end

		return true
	end,
	StoreFruit = function(arg)
		if not arg or not arg:IsA("Tool") then
			return
		end

		if not string.find(arg.Name, "Fruit") and not string.find(tostring(arg), "Fruit") then
			return
		end

		if not FruitFunc.CanStoreFruit(arg) then
			return
		end

		task.spawn(function()
			local attribute = arg:GetAttribute("OriginalName")
			local value

			if attribute then
				value = attribute
			else
				value = arg:FindFirstChild("OriginalName") and arg.OriginalName.Value
			end

			local name = value or arg.Name
			if FruitFunc.IgnoreStoreFruit and (name == FruitFunc.IgnoreStoreFruit or arg.Name == FruitFunc.IgnoreStoreFruit) then
				return
			end

			if arg.Parent == localPlayer.Backpack and localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
				pcall(function()
					localPlayer.Character.Humanoid:EquipTool(arg)
					task.wait(0.2)
				end)
			end

			pcall(function()
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StoreFruit", name, arg)
			end)
		end)
	end,
	AutoStoreAll = function()
		local v3 = FruitFunc.HaveFruitInv()

		if v3 and #v3 > 0 then
			for _, v4 in pairs(v3) do
				if v4 and v4:IsA("Tool") and string.find(v4.Name, "Fruit") then
					if FruitFunc.CanStoreFruit(v4) then
						FruitFunc.StoreFruit(v4)
						task.wait(0.25)
					end
				end
			end
		end
	end,
	IsValidFruit = function(arg)
		local tbl5 = {}
		arg = arg or FruitFunc.HaveFruitInv()

		for _, v3 in pairs(arg) do
			if v3 and v3:IsA("Tool") and FruitFunc.CanStoreFruit(v3) then
				table.insert(tbl5, {
					v3:GetAttribute("OriginalName") or v3:FindFirstChild("OriginalName") and v3.OriginalName.Value or v3.Name,
					v3,
				})
			end
		end

		return tbl5
	end,
}

task.spawn(function()
	local function fn14(arg)
		if not arg then
			return
		end

		arg.ChildAdded:Connect(function(child)
			if getgenv().Setting and getgenv().Setting.Fruit and (getgenv().Setting.Fruit.AutoStore or getgenv().Setting.OneClick and getgenv().Setting.OneClick.Enable) then
				if child and child:IsA("Tool") and string.find(child.Name, "Fruit") then
					task.wait(0.1)

					if FruitFunc.CanStoreFruit(child) then
						FruitFunc.StoreFruit(child)
					end
				end
			end
		end)
	end

	if localPlayer and localPlayer:FindFirstChild("Backpack") then
		fn14(localPlayer.Backpack)
	end

	if localPlayer and localPlayer.Character then
		fn14(localPlayer.Character)
	end

	if localPlayer then
		localPlayer.CharacterAdded:Connect(function(character)
			fn14(character)
			local backpack = localPlayer:WaitForChild("Backpack", 5)

			if backpack then
				fn14(backpack)
			end
		end)
	end
end)

SwanDoor = {
	Check = function()
		if DataSave.Unlocked.SwanDoor then
			return true
		end
		local swanDoor = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TalkTrevor", "2") == 0

		if swanDoor then
			DataSave.Unlocked.SwanDoor = swanDoor
		end

		return swanDoor
	end,
	GetFruit = function()
		return FruitFunc.GetFruitAbove1M()
	end,
}

getgenv().LiteFpsBoost = function()
	(function(...) end)()
end

local fn14

fn14 = function()
	local tbl5 = {}

	for _, v3 in pairs(game:GetService("CollectionService"):GetTagged("_ChestTagged")) do
		if not v3:GetAttribute("IsDisabled") then
			if v3:GetAttribute("LastCollect") and tick() - v3:GetAttribute("LastCollect") <= 120 then
				print("Last Collect Excluded")
			else
				table.insert(tbl5, v3)
			end
		end
	end

	return tbl5
end

pcall(function()
	SupportRetard()
	CamMod = require(game:GetService("ReplicatedStorage").Util.CameraShaker)
	CamMod:Stop()
end)

LastGetQuest = 0

SafeGetQuest = function(arg, arg2, arg3, arg4, arg5)
	if arg5 and HasActiveQuest(arg5) then
		return true
	end

	if not Alive() then
		return false
	end

	if HasActiveQuest() and arg5 and not HasActiveQuest(arg5) then
		CancelQuest()
		task.wait(0.2)
	end

	local position = arg.Position

	if (fn4(localPlayer.Character).Position - position).magnitude <= 30 then
		local flag2 = not LastGetQuest

		if not flag2 then
			local v3 = LastGetQuest
			flag2 = tick() - v3 >= 0.5
		end

		if flag2 then
			LastGetQuest = tick()

			pcall(function()
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest", arg2, arg3)
			end)

			task.wait(0.3)

			if arg5 then
				if HasActiveQuest(arg5) then
					fn6(false)
					return true
				end
			elseif HasActiveQuest() then
				fn6(false)
				return true
			end
		end
	end

	return false
end

GetMaterial = function(arg)
	if not arg or arg == "" then
		return 0
	end

	local ok, result, result2 = pcall(function()
		return checkItem(arg)
	end)

	if ok and result and result2 and result2 > 0 then
		return result2
	end
	local all = getgenv().LocalPlayerInv and getgenv().LocalPlayerInv.All

	if type(all) == "table" then
		local v3 = string.lower(tostring(arg))
		local v4 = string.gsub(v3, "%s+", "")

		for _, v5 in pairs(all) do
			if type(v5) == "table" and type(v5.Name) == "string" then
				local v6 = string.lower(v5.Name)
				local v7 = string.gsub(v6, "%s+", "")
				if v5.Name == arg or v6 == v3 or v7 == v4 then
					return tonumber(v5.Count) or tonumber(v5.Amount) or tonumber(v5.Quantity) or 1
				end
			end
		end
	end

	return 0
end

CheckGodhumanMaterialStatus = function()
	local ok, result = pcall(function()
		return game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyGodhuman", true)
	end)

	if not ok then
		return { code = nil, ready = false, owned = false, message = "Error calling remote" }
	end

	if result == 0 then
		return {
			code = 0,
			ready = true,
			owned = false,
			message = "Materials fully gathered – Requires 5M Beli + 5k Fragments.",
		}
	end

	if result == 1 then
		return { code = 1, ready = true, owned = true, message = " Already own Godhuman" }
	end
	return { code = result, ready = false, owned = false, message = "INSUFFICIENT TOP-UP: " .. tostring(result) }
end

CheckFlower = function()
	for _, child in pairs(localPlayer.Backpack:GetChildren()) do
		if string.find(child.Name, "Flower") then
			return true
		end
	end

	local tool = localPlayer.Character:FindFirstChildOfClass("Tool")

	if tool then
		if string.find(tool.Name, "Flower") then
			return true
		end
	end

	return false
end

CanUseGate = function()
	return game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ "GetUnlockables" })).DefeatedIndraTrueForm
end

GetNearestEntrance = function(arg)
	local v3 = nil

	if Sea3 then
		local huge = math.huge
		local v4 = nil

		for k, v5 in pairs(GatesInfo) do
			if (v5.Pos - arg).magnitude < huge then
				huge = (v5.Pos - arg).magnitude
				v4 = k
			end
		end

		v3 = v4
	end

	return v3, GatesInfo[v3]
end

TPToEntrance = function(arg)
	GateInfo = GatesInfo[arg]
	if not CanUseGate() then
		return
	end

	if not GateInfo.CanInstaTP and (GateInfo.Hitbox() == nil or GateInfo.Hitbox().Parent == nil) then
		return
	end
	local n2 = 0

	while true do
		wait()
		n2 += 1

		if Alive() then
			StatusFarming = "Attemping To TP Gate " .. arg
			local tweenInfo = TweenInfo.new(0, Enum.EasingStyle.Linear)
			local tween_ = game:service("TweenService"):Create(fn4(localPlayer.Character), tweenInfo, { CFrame = fn4(localPlayer.Character).CFrame })
			tween_:Play()
			tween_:Cancel()

			if GateInfo.CanInstaTP then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", GateInfo.Pos)
			else
				localPlayer.Character.HumanoidRootPart.CFrame = GateInfo.Hitbox().CFrame
				fn(fn4(localPlayer.Character), GateInfo.Hitbox(), 0)
				task.wait()
				fn(fn4(localPlayer.Character), GateInfo.Hitbox(), 1)
				task.wait(0.5)
			end
		end

		local pos = GateInfo.Pos
		if not ((fn4(localPlayer.Character).Position - pos).magnitude < 300 or n2 >= 5) then
			continue
		end
		break
	end
end

TpNearestEntrance = function(arg)
	if CanUseGate() then
		local v3, v4 = GetNearestEntrance(arg)
		Name = v3
		Info = v4
		TPToEntrance(Name)
	end
end

GetNearSpawn = function(arg)
	while not Alive() do
		task.wait()
	end

	local flag2 = #FruitFunc.HaveFruitInv() > 0 and not getgenv().Setting.OneClick.Enable or CheckItem("Hallow Essence") or CheckItem("Fist of Darkness") or CheckItem("God's Chalice") or CheckItem("Sweet Chalice") or Sea3 and CheckItem("Red Key") and not CanAwakenDough() or (Sea3 or Sea2) and CheckItem("Special Microchip") or Sea2 and CheckFlower()

	if not flag2 then
		flag2 = (Sea3 or Sea2) and CheckItem("Microchip")
	end

	if flag2 then
		return
	end
	Nearest = math.huge
	TPPos = CFrame.new(arg)

	if fn4(localPlayer.Character) then
		if (fn4(localPlayer.Character).Position - arg).magnitude < 1000 then
			return nil
		end
	end

	if Sea3 and fn10(arg) then
		return nil
	end

	if Sea3 and fn10(localPlayer.Character) and not fn10(arg) then
		return nil
	end

	if CanUseGate() then
		local v3, v4 = GetNearestEntrance(arg)

		if v4 and v4.Pos then
			if (v4.Pos - arg).magnitude < 2000 and (v4.Pos - arg).magnitude < (fn4(localPlayer.Character).Position - arg).magnitude then
				TPToEntrance(v3)
				return nil
			end
		end
	end

	return arg
end

BypassTpLocation = {}
PlayerSpawnsLot = {}

for _, child in pairs(workspace._WorldOrigin.PlayerSpawns:GetChildren()) do
	for _, child2 in pairs(child:GetChildren()) do
		table.insert(PlayerSpawnsLot, { child2.Name, child2:GetModelCFrame().p })
	end

	child.ChildAdded:Connect(function(child2)
		table.insert(PlayerSpawnsLot, { child2.Name, child2:GetModelCFrame().p })
	end)
end

for _, child in pairs(workspace._WorldOrigin.Locations:GetChildren()) do
	BypassTpLocation[child.Name] = BypassTpLocation[child.Name] or {}

	for _, v3 in pairs(PlayerSpawnsLot) do
		if (v3[2] - child.Position).Magnitude <= child.Size.X * child.Mesh.Scale.X / 2 then
			table.insert(BypassTpLocation[child.Name], v3)
		end
	end
end

workspace._WorldOrigin.Locations.ChildAdded:Connect(function(child)
	task.wait(3)
	BypassTpLocation[child.Name] = BypassTpLocation[child.Name] or {}

	for _, v3 in pairs(PlayerSpawnsLot) do
		if (v3[2] - child.Position).Magnitude <= child.Size.X * child.Mesh.Scale.X / 2 then
			table.insert(BypassTpLocation[child.Name], v3)
		end
	end
end)

GetTPLocation = function(arg)
	local tbl5 = { distance = math.huge, priority = math.huge }
	local v3 = next
	local children, v4 = workspace._WorldOrigin.Locations:GetChildren()
	local huge = math.huge
	local v5 = nil

	for _, v6 in v3, children, v4 do
		local mesh = v6:FindFirstChild("Mesh")

		if mesh then
			if (arg - v6.Position).Magnitude <= mesh.Scale.X * v6.Size.X / 2 and BypassTpLocation[v6.Name] then
				for _, v7 in pairs(BypassTpLocation[v6.Name]) do
					local v8 = v7[1]
					local magnitude = (arg - v7[2]).Magnitude

					if magnitude < huge then
						huge = magnitude
						v5 = v8
					end
				end
			end
		end
	end

	local v6 = next
	local children2, v7 = workspace._WorldOrigin.EnemyRegions:GetChildren()

	for _, v8 in v6, children2, v7 do
		local mesh = v8:FindFirstChild("Mesh")

		if mesh then
			local magnitude = (arg - v8.Position).Magnitude

			if magnitude <= mesh.Scale.X * v8.Size.X / 2 and magnitude < tbl5.distance then
				tbl5 = { distance = magnitude, priority = math.huge, region = v8 }
			end
		end
	end

	return v5
end

SSS = function(arg, arg2)
	if not arg then
		return
	end

	if not (getgenv().Setting and getgenv().Setting.BypassTP and getgenv().Setting.BypassTP.Enable) then
		return
	end
	local tbl5 = {}
	local v3 = next
	local children, v4 = workspace._WorldOrigin.Locations:GetChildren()

	for _, v5 in v3, children, v4 do
		if BypassTpLocation[v5.Name] then
			for _, v6 in pairs(BypassTpLocation[v5.Name]) do
				if not table.find(tbl5, v6[1]) then
					table.insert(tbl5, v6[2])
				end
			end
		end
	end

	if #tbl5 == 0 then
		return
	end

	if #tbl5 > 1 then
		table.sort(tbl5, function(arg3, arg4)
			return fn9(arg3, arg) < fn9(arg4, arg)
		end)
	end

	local localPlayer2 = game:GetService("Players").LocalPlayer
	local character = localPlayer2.Character
	if not character or not character:FindFirstChild("LastSpawnPoint") then
		return
	end
	character.LastSpawnPoint.Disabled = true
	task.wait()

	for _, v5 in pairs(tbl5) do
		local v6 = fn9(v5, arg)
		local v7 = fn9(v5, character)

		if v6 + 500 < fn9(arg, character) and v7 >= 1000 then
			if arg2 and not arg2() then
				character.LastSpawnPoint.Disabled = false
				return
			end
			local v8 = GetTPLocation(v5)
			game.ReplicatedStorage.Remotes.CommF_:InvokeServer("SetLastSpawnPoint", v8)

			if localPlayer2.Data.LastSpawnPoint.Value == v8 then
				if character:FindFirstChild("Humanoid") then
					character.Humanoid.Health = 0
				end

				while not Alive() do
					if arg2 and not arg2() then
						character.LastSpawnPoint.Disabled = false
						return
					end
					task.wait()
				end

				return SSS(arg, arg2)
			end
		end
	end

	character.LastSpawnPoint.Disabled = false
end

TPKatakuriGate = function(arg)
	if fn4(localPlayer.Character) then
		local v3 = fn9(localPlayer.Character, arg)

		if fn9(localPlayer.Character, Vector3.new(-2144.967, 70.37716, -12399.752)) + 500 < v3 then
			DoTween2(CFrame.new(-2144.967041015625, 70.377159118652344, -12399.751953125), function()
				return fn5(arg)
			end)

			task.wait(3)
		end
	end
end

local getNearMob
getNearMob = nil

CheckEnemySpawn = function(arg)
	if not arg or arg == "" then
		return false
	end

	if enemies then
		local v3 = enemies:FindFirstChild(arg)
		if v3 and fn5(v3) then
			return true
		end

		for _, child in ipairs(enemies:GetChildren()) do
			if MobNameMatches(child.Name, arg) and fn5(child) then
				return true
			end
		end
	end

	if getNearMob then
		local v3 = getNearMob(arg)
		if fn5(v3) then
			return true
		end
	end

	local characters = workspace:FindFirstChild("Characters")

	if characters then
		local v3 = characters:FindFirstChild(arg)
		if v3 and fn5(v3) then
			return true
		end

		for _, child in ipairs(characters:GetChildren()) do
			if MobNameMatches(child.Name, arg) and fn5(child) then
				return true
			end
		end
	end

	return false
end

GetMainEnemy = function(arg)
	if not arg or arg == "" then
		return nil
	end

	if enemies then
		local v3 = enemies:FindFirstChild(arg)
		if v3 and fn5(v3) then
			return v3
		end

		for _, child in ipairs(enemies:GetChildren()) do
			if MobNameMatches(child.Name, arg) and fn5(child) then
				return child
			end
		end
	end

	if getNearMob then
		local v3 = getNearMob(arg)
		if fn5(v3) then
			return v3
		end
	end

	local function fn15()
		return not CheckEnemySpawn(arg)
	end

	local worldOrigin = game:GetService("Workspace"):FindFirstChild("_WorldOrigin") or game:GetService("Workspace"):FindFirstChild("WorldOrigin")
	worldOrigin = worldOrigin and worldOrigin:FindFirstChild("EnemySpawns")

	if worldOrigin then
		for _, child in pairs(worldOrigin:GetChildren()) do
			local match = child.Name:match("^(.-)%s*%[") or child.Name

			if child.Name == arg or MobNameMatches(match, arg) then
				SSS(GetNearSpawn(child.Position), fn15)
				DoTween2(child.CFrame + Vector3.new(0, 30, 20))
				fn6(true)
				break
			end
		end
	end

	local v3 = enemies
	local v4

	if enemies then
		v4 = enemies:FindFirstChild(arg)
	else
		v4 = v3
	end

	if not v4 and getNearMob then
		v4 = getNearMob(arg)
	end

	if not v4 and enemies then
		pcall(function()
			v4 = enemies:WaitForChild(arg, 2)
		end)
	end

	if not Alive() then
		fn6(false)
	end

	return v4
end

NotInCoolDownSize = UDim2.new(0, 0, 1, -1)

NotCooldown = function(arg, arg2)
	return localPlayer.PlayerGui.Main.Skills[arg2][arg].Cooldown.Size == NotInCoolDownSize
end

IsSkillsNotCooldown = function(arg, arg2)
	if type(arg) == "table" then
		local flag2 = false

		for _, v3 in pairs(arg) do
			flag2 = NotCooldown(v3, arg2)
			if not flag2 then
				continue
			end
			break
		end

		return flag2
	end

	return NotCooldown(arg, arg2)
end

CancelQuest = function()
	local n2 = 0

	while (HasActiveQuest() or localPlayer and localPlayer:FindFirstChild("PlayerGui") and localPlayer.PlayerGui:FindFirstChild("Main") and localPlayer.PlayerGui.Main:FindFirstChild("Quest") and localPlayer.PlayerGui.Main.Quest.Visible) and n2 < 5 do
		n2 += 1

		pcall(function()
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AbandonQuest")
		end)

		task.wait(0.2)
	end

	pcall(function()
		if localPlayer and localPlayer:FindFirstChild("PlayerGui") and localPlayer.PlayerGui:FindFirstChild("Main") and localPlayer.PlayerGui.Main:FindFirstChild("Quest") then
			localPlayer.PlayerGui.Main.Quest.Visible = false
		end
	end)
end

IsPlayerValid = function(arg)
	local n2 = 180

	if localPlayer.Data.Level.Value < 75 then
		n2 = 80
	end

	local character = arg.Character
	if fn5(character) and math.abs(arg.Data.Level.Value - localPlayer.Data.Level.Value) < n2 and arg.Data.Level.Value > 20 and (character.HumanoidRootPart.Position - fn4(localPlayer.Character).Position).magnitude < 10000 and not string.find(arg.Data.DevilFruit.Value, "Buddha") then
		return true
	end
	return false
end

ResizeBoss = function(arg, arg2)
	if arg and fn4(arg) then
		fn4(arg).Transparency = 1

		if arg2 then
			fn4(arg).CanCollide = false
		end

		fn4(arg).Size = Vector3.new(90, 90, 90)
	end
end

LegitName = function(arg)
	return not string.find(arg, "Boss") and not string.find(arg, "Friend") and not string.find(arg, "friend")
end

GetCloseRangeAttack = function()
	if getgenv().Setting.Mastery.Sword and not getgenv().Setting.Mastery["Sword/Low"] then
		return "Sword"
	end
	return "Melee"
end

getgenv().getcallingfunction = function(arg)
	return debug.getinfo(arg + 1).func
end

local fn15, fn16, fn17, fn18

do
	local function fn19(arg)
		local attribute = arg:GetAttribute("EscapeKey")
		local flag2

		if attribute then
			flag2 = not (getgenv and getgenv().DoingEscapeQuest)
		else
			flag2 = attribute
		end

		if flag2 then
			return false
		end

		if arg:FindFirstChild("CharacterReady") then
			return true
		end
	end

	pcall(function()
		setfflag("HumanoidParallelRemoveNoPhysics", "False")
		setfflag("HumanoidParallelRemoveNoPhysicsNoSimulate2", "False")
	end)

	OldSize = {}
	OrginalPosition = {}
	ConMob = {}
	LastBringMob = tick()
	BringMobCheck = {}
	networkownerswitch = {}

	if not isnetworkowner or string.find(identifyexecutor(), "Cryptic") then
		FakeOwnerNetWork = true

		isnetworkowner = function(arg)
			if not networkownerswitch[arg] then
				networkownerswitch[arg] = tick()
			end

			local ok, result = pcall(function()
				return gethiddenproperty(arg, "NetworkOwnershipRule")
			end)

			if ok and result == Enum.NetworkOwnership.Manual then
				sethiddenproperty(arg, "NetworkOwnershipRule", Enum.NetworkOwnership.Automatic)
				networkownerswitch[arg] = tick() + 4
			end

			return networkownerswitch[arg] <= tick() and not arg:IsGrounded() and arg.AssemblyRootPart.ReceiveAge == 0
		end
	end

	fn15 = function(arg, arg2, arg3, arg4)
		local v3 = LastBringMob
		if tick() - v3 <= 0 then
			return
		end
		LastBringMob = tick()

		for _, child in pairs(enemies:GetChildren()) do
			if fn5(child) and not Tweening and Alive() and LegitName(child.Humanoid.DisplayName) and fn19(child) then
				if arg == "Specific" and child.Name == arg2 or arg == "Near" then
					if arg == "Near" and fn5(arg2) and not BringMobCheck[arg2] then
						BringMobCheck[arg2] = tick()
						BringCFrame = fn4(arg2).CFrame
						BringPos = fn4(arg2).Position
					end

					if not OrginalPosition[child] then
						OrginalPosition[child] = fn4(child).Position
					end

					local n2 = arg4 or FakeOwnerNetWork and 250 or 350

					pcall(function()
						if BringCFrame ~= nil and BringPos ~= nil and getgenv().Setting.BringMob.Enable then
							if fn9(child, localPlayer.Character) <= n2 and (BringPos - fn4(child).Position).magnitude <= n2 and (BringPos - OrginalPosition[child]).magnitude <= n2 and isnetworkowner(fn4(child)) then
								if not getgenv()._SimRadiusSet then
									pcall(function()
										if setscriptable then
											setscriptable(game.Players.LocalPlayer, "SimulationRadius", true)
										end
									end)

									pcall(function()
										if sethiddenproperty then
											sethiddenproperty(game.Players.LocalPlayer, "SimulationRadius", 9999999)
										end
									end)

									getgenv()._SimRadiusSet = true
								end

								child.Humanoid.WalkSpeed = 0

								if not ConMob[child] then
									ConMob[child] = true
									local v4 = next
									local descendants, v5 = child:GetDescendants()

									for _, v6 in v4, descendants, v5 do
										if (v6:IsA("Part") or v6:IsA("MeshPart")) and not string.find(child.Name, "Leg") and v6.CanCollide then
											v6.CanCollide = false
										end
									end

									if child.Humanoid:FindFirstChild("Animator") then
										child.Humanoid.Animator:Destroy()
									end
								end

								local v4 = BringCFrame
								fn4(child).CFrame = v4
								local v5 = BringPos
								fn4(child).Position = v5
							end
						end
					end)
				end
			end
		end
	end

	GetBoat = function()
		for _, child in pairs(game:GetService("Workspace").Boats:GetChildren()) do
			if child:FindFirstChild("Owner") and child.Owner.Value == game.Players.LocalPlayer and child:FindFirstChild("VehicleSeat") then
				return child
			end
		end

		return false
	end

	DataSave = {
		Inventory = {
			Saber = false,
			Pole = false,
			Wando = false,
			Shisui = false,
			Saddi = false,
			Rengoku = false,
			Yama = false,
			Tushita = false,
			Dagger = false,
			["Soul Guitar"] = false,
		},
		BlackSmith = {},
		FullMas = {},
		FullSkill = {},
		LockedMas = { Tushita = false, Yama = false },
		TimerOneClick = 0,
		TTK = { Shisui = false, Wando = false, Saddi = false },
		Melee = {
			["Black Leg"] = { Have = false, Mas300 = false, Mas400 = false },
			Electro = { Have = false, Mas300 = false, Mas400 = false },
			["Fishman Karate"] = { Have = false, Mas300 = false, Mas400 = false },
			DragonClaw = { Have = false, Mas300 = false, Mas400 = false },
			Superhuman = { Have = false, Mas400 = false, Mas600 = false },
			["Sharkman Karate"] = { Have = false, Mas400 = false, Mas600 = false },
			["Death Step"] = { Have = false, Mas400 = false, Mas600 = false },
			["Electric Claw"] = { Have = false, Mas400 = false, Mas600 = false },
			["Dragon Talon"] = { Have = false, Mas400 = false, Mas600 = false },
			["God Human"] = { Have = false, Mas400 = false, Mas600 = false },
		},
		Unlocked = {
			Sleigh = false,
			Electricclaw = false,
			Dragontalon = false,
			Sharkman = false,
			Deathstep = false,
			SoulGuitar = false,
			SwanDoor = false,
		},
		Sea2Done = false,
		BartiloQuest = false,
		CitizenQuest = false,
		RainbowHaki = false,
	}

	GetLevel = function()
		return localPlayer.Data.Level.Value
	end

	ProgressChecker = {}

	for _, v3 in pairs({ "Saber", "Sea2", "Sea3", "Bartilo", "RaceV2", "SoulGuitar", "Citizen Quest" }) do
		ProgressChecker[v3] = {}
	end

	SecondSeaProgress = function()
		if ProgressChecker.Sea2.KilledIceBoss then
			return
		end

		pcall(function()
			local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("DressrosaQuestProgress")

			if response and typeof(response) == "table" then
				for k, v3 in pairs(response) do
					if typeof(v3) ~= "table" then
						ProgressChecker.Sea2[k] = v3
					end
				end
			end
		end)

		local door = workspace.Map:FindFirstChild("Ice") and workspace.Map.Ice:FindFirstChild("Door")

		if door then
			door = not door.CanCollide or door.Transparency == 1
		end

		if door then
			ProgressChecker.Sea2.UsedKey = true
		end
	end

	CitizenQuest = function()
		if ProgressChecker["Citizen Quest"].Hat then
			return
		end
		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CitizenQuestProgress", "Citizen")

		if response then
			if response == 1 then
				ProgressChecker["Citizen Quest"].Bandit = true
			end

			if response == 2 then
				ProgressChecker["Citizen Quest"].Bandit = true
				ProgressChecker["Citizen Quest"].ElephantBoss = true
			end

			if response == 3 then
				ProgressChecker["Citizen Quest"].Hat = true
				ProgressChecker["Citizen Quest"].Bandit = true
				ProgressChecker["Citizen Quest"].ElephantBoss = true
			end
		end
	end

	RaceV2Progress = function()
		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Alchemist", "1")

		if response == 0 then
			ProgressChecker.RaceV2.DoneRace = false
		elseif response == 1 then
			ProgressChecker.RaceV2.StartRace = true
		elseif response ~= nil then
			ProgressChecker.RaceV2.DoneRace = true
		end
	end

	RaceV3Progress = function()
		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Alchemist", "1")

		if response == 0 then
			ProgressChecker.RaceV2.DoneRace = false
		elseif response == 1 then
			ProgressChecker.RaceV2.StartRace = true
		elseif response ~= nil then
			ProgressChecker.RaceV2.DoneRace = true
		end
	end

	GuitarProgress = function()
		if GetLevel() < 2300 then
			return false
		end
		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Check")

		if response then
			for k, v3 in pairs(response) do
				ProgressChecker.SoulGuitar[k] = v3
			end

			if response.Trophies then
				DataSave.Unlocked.SoulGuitar = true
			end
		end
	end

	fn16 = function()
		local tbl5 = { "CDKQuest", "Progress", "Good" }
		local response = nil

		pcall(function()
			response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(tbl5))
		end)

		if type(response) == "table" then
			return response
		end
		return { Good = 0, Evil = 0 }
	end

	IsRaceV3 = function()
		return CheckItem(SkillsV3Name[localPlayer.Data.Race.Value])
	end

	BartiloProgress = function()
		if ProgressChecker.Bartilo.DidPlates or DataSave.BartiloQuest then
			return
		end
		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress")

		if response then
			for k, v3 in pairs(response) do
				ProgressChecker.Bartilo[k] = v3
			end
		end

		if ProgressChecker.Bartilo.DidPlates then
			DataSave.BartiloQuest = true
		end
	end

	CheckBartilo = function()
		if DataSave.BartiloQuest then
			return true
		end

		if CheckInvItem("Warrior Helmet") then
			DataSave.BartiloQuest = true
			return true
		end
		return false
	end

	ThirdSeaProgress = function()
		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ZQuestProgress", "Check")

		if response == 0 then
			ProgressChecker.Sea3.Doflamingo = true
		end

		if response == 1 then
			ProgressChecker.Sea3.Doflamingo = true
			ProgressChecker.Sea3.FakeRipIndra = true
		end
	end

	SaberProgress = function()
		if ProgressChecker.Saber.KilledShanks then
			return
		end
		CheckSaber = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ "ProQuestProgress" }))

		if CheckSaber then
			for k, v3 in pairs(CheckSaber) do
				if typeof(v3) == "table" then
					Plates = 0

					for _, v4 in pairs(v3) do
						if v4 == true then
							Plates = Plates + 1
						end
					end
				end

				ProgressChecker.Saber[k] = v3
			end

			return false
		end
	end

	UseRaceV4 = function()
		if game.Players.LocalPlayer.Character:FindFirstChild("RaceEnergy") and game.Players.LocalPlayer.Character.RaceEnergy.Value >= 1 and not game.Players.LocalPlayer.Character.RaceTransformed.Value then
			local awakening = game:GetService("Players").LocalPlayer.Backpack:FindFirstChild("Awakening") or localPlayer.Character:FindFirstChild("Awakening")

			if awakening then
				awakening.RemoteFunction:InvokeServer(true)
			end
		end
	end

	AbilityCondition = {
		Mink = function()
			return true
		end,
		Skypiea = function(arg)
			local fn20 = arg or function()
				return true
			end

			if Alive() and localPlayer.Character.Humanoid.Health <= localPlayer.Character.Humanoid.MaxHealth * 80 / 100 and fn20() then
				return true
			end
		end,
		Ghoul = function(arg)
			local fn20 = arg or function()
				return true
			end

			if Alive() and fn20() then
				return true
			end
		end,
		Fishman = function(arg)
			local fn20 = arg or function()
				return true
			end

			if Alive() and localPlayer.Character.Humanoid.Health <= localPlayer.Character.Humanoid.MaxHealth * 80 / 100 and fn20() then
				return true
			end
		end,
		Cyborg = function(arg)
			local fn20 = arg or function()
				return true
			end

			if Alive() and fn20() then
				return true
			end
		end,
		Human = function(arg)
			local fn20 = arg or function()
				return true
			end

			if Alive() and fn20() and localPlayer.Character.Humanoid.Health <= localPlayer.Character.Humanoid.MaxHealth * 70 / 100 then
				return true
			end
		end,
	}

	LastAbilityUse = tick()

	SmartAbilityUse = function(arg)
		local flag2 = AbilityCondition[localPlayer.Data.Race.Value] and AbilityCondition[localPlayer.Data.Race.Value]() or arg

		if flag2 then
			local v3 = LastAbilityUse
			flag2 = tick() - v3 > 0.5
		end

		if flag2 then
			game:GetService("ReplicatedStorage").Remotes.CommE:FireServer("ActivateAbility")
		end
	end

	CheckInvItem = function(arg)
		if not DataSave.Inventory[arg] then
			if Alive() then
				if localPlayer.Backpack:FindFirstChild(arg) or localPlayer.Character:FindFirstChild(arg) then
					DataSave.Inventory[arg] = true
					return true
				end
				CheckA = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("getInventoryWeapons")

				if CheckA then
					for _, v3 in pairs(CheckA) do
						for _, v4 in pairs(v3) do
							if string.find(v4, arg) or v4 == arg then
								DataSave.Inventory[arg] = true
								return true
							end
						end
					end
				end

				return false
			end

			print("Recursive Check Inv Item")

			repeat
				wait()
			until Alive()

			wait(1)
			return CheckInvItem(arg)
		end

		return true
	end

	GetSettingHopExploiter = function()
		if CheckItem("Hallow Essence") or CheckItem("Fist of Darkness") or CheckItem("God's Chalice") or CheckItem("Sweet Chalice") or Sea3 and CheckItem("Red Key") and not CanAwakenDough() or (Sea3 or Sea2) and CheckItem("Special Microchip") or Sea2 and CheckFlower() then
			return
		end
		return getgenv().OneClickSetting and getgenv().OneClickSetting.HopIfFoundNearExploiter and WorkingFarm:empty()
	end

	HopNearExploiter = function()
		if getgenv().IsExploiting then
			for k, v3 in getgenv().IsExploiting, nil, nil do
				Char = workspace.Characters:FindFirstChild(k)
				v3 = Char and Char:FindFirstChild("HumanoidRootPart") and v3

				if v3 then
					if fn9(localPlayer.Character, Char) < 500 then
						MainServerHop(5, "Exploiter Found Nearby", 1, 5)
					end
				end
			end
		end
	end

	GetMaxMastery = function(arg)
		if arg then
			local n2 = 0

			if arg:FindFirstChild("Data") then
				local Data = require(arg.Data)

				for _, v3 in pairs(AllFruitKeys) do
					if Data.Lvl[v3] then
						n2 = math.max(n2, Data.Lvl[v3])
					end
				end
			end

			return n2
		end

		return 0
	end

	GetMaxMasteryWeapon = function(arg)
		if arg and arg:FindFirstChild("Data") then
			return require(arg.Data).Lvl.X
		end
		return 0
	end

	GetCurrentWeaponSwitcher = function(arg, arg2)
		if Weapon600Mas[arg2] then
			return
		end
		PrioritySword = { ["0"] = {}, ["1"] = {}, ["2"] = {}, ["3"] = {}, ["4"] = {} }
		CheckA = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("getInventoryWeapons")

		if CheckA then
			for _, v3 in pairs(CheckA) do
				local flag2 = v3.Type == arg2
				local flag3

				if flag2 then
					flag3 = not (arg and DataSave.FullMas[v3.Name] or not arg and DataSave.FullSkill[v3.Name])
				else
					flag3 = flag2
				end

				if flag3 then
					if PrioritySword[tostring(v3.Rarity)] then
						local name = v3.Name
						table.insert(PrioritySword[tostring(v3.Rarity)], name)
					else
						print("Errored At ", v3.Rarity)
					end
				end
			end

			for i = 4, 1, -1 do
				local list = PrioritySword[tostring(i)]
				if list and list[1] ~= nil then
					return list[1]
				end
			end
		end
	end

	LastCheckGear = tick()
	print("Intilizing UI")
	getgenv().Premium = true
	CheckPremium = true
	getgenv().LoadUi = true

	while true do
		wait()
		if not (getgenv().LoadUi and getgenv().IslandCaller and getgenv().SettingManager) then
			continue
		end
		break
	end

	print("Adding Char Connection")

	localPlayer.CharacterAdded:Connect(function()
		DoneBeGod = false
	end)

	TeleportService = game:GetService("TeleportService")

	TeleportService.TeleportInitFailed:Connect(function()
	end)

	SupportRetard()
	Animation = Instance.new("Animation")

	getHits = function(arg, arg2)
		local tbl5 = {}
		local children = workspace.Enemies:GetChildren()
		local children2 = workspace.Characters:GetChildren()

		for i = 1, #children do
			local v3 = children[i]

			if getgenv().Setting.FastAttack.OnMob then
				local humanoid = v3:FindFirstChildOfClass("Humanoid")

				if humanoid and humanoid.RootPart and humanoid.Health > 0 and (not v3:GetAttribute("EscapeKey") or getgenv and getgenv().DoingEscapeQuest) and game.Players.LocalPlayer:DistanceFromCharacter(humanoid.RootPart.Position) < arg then
					table.insert(tbl5, arg2 and v3[arg2] or humanoid.RootPart)
				end
			end
		end

		for i = 1, #children2 do
			local v3 = children2[i]

			if getgenv().Setting.FastAttack.OnPlayer then
				if v3 ~= game.Players.LocalPlayer.Character then
					local humanoid = v3:FindFirstChildOfClass("Humanoid")

					if humanoid and humanoid.RootPart and humanoid.Health > 0 and game.Players.LocalPlayer:DistanceFromCharacter(humanoid.RootPart.Position) < arg then
						table.insert(tbl5, arg2 and v3[arg2] or humanoid.RootPart)
					end
				end
			end
		end

		return tbl5
	end

	Delay = 0
	LastHash = tick()
	print("Attack No CD")

	AttackNoCD = function()
	end

	fn17 = function()
		local n2 = 9999999
		local v3 = nil

		for _, v4 in pairs(fn3()) do
			if v4 ~= localPlayer then
				if Alive() and fn5(v4.Character) then
					if fn9(v4.Character, localPlayer.Character) <= n2 then
						n2 = fn9(v4.Character, localPlayer.Character)
						v3 = v4
					end
				end
			end
		end

		return v3
	end

	print("Setting Gun Method")

	BypassShootGun = function()
		local ok, result = pcall(function()
			local controllers = game:GetService("ReplicatedStorage"):FindFirstChild("Controllers")
			local combatController = controllers and controllers:FindFirstChild("CombatController")
			if combatController then
				return require(combatController)
			end
		end)

		if not ok or not result or not result.Attack then
			return
		end
		local v3 = debug.getupvalues(result.Attack)
		v3 = v3 and v3[9]
		if not v3 then
			return
		end
		local n2 = debug.getupvalue(v3, 14)
		local v4 = debug.getupvalue(v3, 16)
		local n3 = debug.getupvalue(v3, 12)
		local v5 = debug.getupvalue(v3, 18)
		if not n2 or not v4 or not n3 or not v5 then
			return
		end
		local n4 = n3 * 798405
		local n5 = (n2 * 798405 + n3 * 727595) % v4

		calcccc = function()
			n5 = (n5 * v4 + n4) % 1099511627776
			n2 = math.floor(n5 / v4)
			n3 = n5 - n2 * v4
		end

		calcccc()
		debug.setupvalue(v3, 14, n2)
		debug.setupvalue(v3, 16, v4)
		debug.setupvalue(v3, 12, n3)
		debug.setupvalue(v3, 18, v5)
		game.ReplicatedStorage.Remotes.Validator2:FireServer(math.floor(n5 / 1099511627776 * 16777215), v5)
	end

	ShootGun = function(arg, arg2)
		local isModel = typeof(arg) == "Instance" and arg:IsA("Model") and Players:FindFirstChild(arg.Name)
		local head = nil
		local flag2 = nil
		local v3 = nil

		for _, child in pairs(localPlayer.Character:GetChildren()) do
			if child:IsA("Tool") then
				if child.ToolTip == "Gun" then
					v3 = child
				end
			end
		end

		if v3 then
			local v4 = fn8(arg)

			if typeof(arg) == "Instance" and arg:IsA("Model") then
				head = arg.Head
				arg:FindFirstChild("HumanoidRootPart")
			end

			if isModel then
				flag2 = arg and arg:FindFirstChild("HumanoidRootPart") and arg:FindFirstChild("Humanoid") and arg:FindFirstChild("Humanoid").Health > 0
			end

			local ok, result = pcall(function()
				if Alive() then
					if isModel and flag2 or not isModel then
						if v3.Name == "Skull Guitar" then
							v3.RemoteEvent:FireServer(unpack({ "TAP", v4 }))
						else
							BypassShootGun()
							local tbl5 = { v4 }

							if v3.Name ~= "Bazooka" and v3.Name ~= "Cannon" then
								tbl5[2] = arg2 and { head } or getHits(100, "Head")
							end

							game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/ShootGunEvent"):FireServer(unpack(tbl5))
						end
					end
				end
			end)

			if result then
				print("Shoot Gun Err:", result)
			end
		end
	end

	StartAttack = tick()
	print("Adjusting Animation")
	print("Last Fast attack")
	local Players2 = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local RunService2 = game:GetService("RunService")
	local localPlayer2 = Players2.LocalPlayer
	local enemies2 = Workspace:WaitForChild("Enemies")
	local characters = Workspace:WaitForChild("Characters")
	local net = ReplicatedStorage.Modules.Net
	local reRegisterAttack = net["RE/RegisterAttack"]
	local reRegisterHit = net["RE/RegisterHit"]
	local v3 = nil
	local attribute = nil

	for _, v4 in next, { ReplicatedStorage.Util, ReplicatedStorage.Common, ReplicatedStorage.Remotes, ReplicatedStorage.Assets, ReplicatedStorage.FX }, nil do
		local v5 = next
		local children, v6 = v4:GetChildren()

		for _, v7 in v5, children, v6 do
			if v7:IsA("RemoteEvent") and v7:GetAttribute("Id") then
				v3 = v7
				attribute = v7:GetAttribute("Id")
			end
		end

		v4.ChildAdded:Connect(function(child)
			if child:IsA("RemoteEvent") and child:GetAttribute("Id") then
				v3 = child
				attribute = child:GetAttribute("Id")
			end
		end)
	end

	local tbl5

	tbl5 = {
		Rate = 0.1,
		GetMob = function(arg, arg2, arg3)
			local position = arg2:GetPivot().Position
			local tbl6 = {}
			local v4 = next
			local children, v5 = arg3:GetChildren()

			for _, v6 in v4, children, v5 do
				local humanoid = v6:FindFirstChild("Humanoid")
				local humanoidRootPart = v6:FindFirstChild("HumanoidRootPart")

				if humanoid and humanoidRootPart and humanoid.Health > 0 and (humanoidRootPart.Position - position).Magnitude <= 60 and (not v6:GetAttribute("EscapeKey") or getgenv and getgenv().DoingEscapeQuest) then
					tbl6[#tbl6 + 1] = v6
				end
			end

			return tbl6
		end,
		Collect = function(arg, arg2)
			local tbl6 = {}
			local mob = arg:GetMob(arg2, enemies2)
			local mob2 = arg:GetMob(arg2, characters)

			for i = 1, #mob do
				tbl6[#tbl6 + 1] = mob[i]
			end

			for i = 1, #mob2 do
				tbl6[#tbl6 + 1] = mob2[i]
			end

			return tbl6
		end,
		Fast = function(arg)
			local character = localPlayer2.Character
			if not character then
				return
			end
			local v4 = arg:Collect(character)
			if #v4 < 1 then
				return
			end
			local tbl6 = {}

			for i = 1, #v4 do
				local head = v4[i]:FindFirstChild("Head") or v4[i].PrimaryPart

				if head then
					tbl6[#tbl6 + 1] = { v4[i], head }
				end
			end

			if #tbl6 < 1 then
				return
			end
			reRegisterAttack:FireServer(tbl5.Rate)
			reRegisterHit:FireServer(tbl6[1][2], tbl6)
		end,
	}

	local function fn20()
		local character = localPlayer2.Character
		if not character then
			return
		end
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return
		end
		local tbl6 = {}

		local function fn21(arg)
			local v4 = next
			local children, v5 = arg:GetChildren()

			for _, v6 in v4, children, v5 do
				local humanoid = v6:FindFirstChild("Humanoid")
				local humanoidRootPart2 = v6:FindFirstChild("HumanoidRootPart")

				if humanoid and humanoidRootPart2 and humanoid.Health > 0 and v6 ~= character and (humanoidRootPart2.Position - humanoidRootPart.Position).Magnitude <= 60 and (not v6:GetAttribute("EscapeKey") or getgenv and getgenv().DoingEscapeQuest) then
					local v7 = next
					local children2, v8 = v6:GetChildren()

					for _, v9 in v7, children2, v8 do
						if v9:IsA("BasePart") then
							tbl6[#tbl6 + 1] = { v6, v9 }
						end
					end
				end
			end
		end

		fn21(enemies2)
		fn21(characters)
		if #tbl6 < 1 then
			return
		end
		local response = net.seed:InvokeServer()
		reRegisterAttack:FireServer()
		local head = tbl6[1][1]:FindFirstChild("Head")
		if not head then
			return
		end
		reRegisterHit:FireServer(head, tbl6, {})

		if v3 then
			local n2 = math.floor(Workspace:GetServerTimeNow() / 10 % 10) + 1

			v3:FireServer(("RE/RegisterHit"):gsub(".", function(arg)
				return string.char(bit32.bxor(arg:byte(), n2))
			end), bit32.bxor(attribute + 909090, response * 2), head, tbl6)
		end
	end

	pcall(function()
		require(ReplicatedStorage.Util.CameraShaker):Stop()
	end)

	task.spawn(function()
		while task.wait(tbl5.Rate) do
			pcall(function()
				tbl5:Fast()
			end)
		end
	end)

	RunService2.Heartbeat:Connect(function()
		pcall(fn20)
	end)

	task.spawn(function()
		while task.wait() do
			local character = localPlayer2.Character

			if character then
				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

				if humanoidRootPart then
					local str = tostring(localPlayer2.UserId):sub(2, 4) .. tostring(coroutine.running()):sub(11, 15)
					local v4 = next
					local children, v5 = enemies2:GetChildren()
					local flag2 = false

					for _, v6 in v4, children, v5 do
						local humanoidRootPart2 = v6:FindFirstChild("HumanoidRootPart")
						local humanoid = v6:FindFirstChild("Humanoid")

						if humanoidRootPart2 and humanoid and humanoid.Health > 0 and (humanoidRootPart2.Position - humanoidRootPart.Position).Magnitude <= 60 and (not v6:GetAttribute("EscapeKey") or getgenv and getgenv().DoingEscapeQuest) then
							if not flag2 then
								reRegisterAttack:FireServer()
								flag2 = true
							end

							reRegisterHit:FireServer(humanoidRootPart2, { { v6, humanoidRootPart2 } }, nil, nil, str)
						end
					end
				end
			end
		end
	end)

	print("SKill Controller")

	task.spawn(function()
		while task.wait(0.1) do
			if not Debounce and SkillsController.Condition and SkillsController.Condition() then
				Debounce = true

				local ok, result = pcall(function()
					for _, v4 in pairs(SkillsController.Weapon) do
						if SkillsController.Condition and SkillsController.Condition() then
							local v5 = GetCurrentTool(v4)

							if v5 then
								if Alive() then
									WeaponData = require(v5.Data)

									if v4 == "Blox Fruit" then
										pcall(Equip, GetCurrentTool("Blox Fruit", true))

										for _, skill in pairs(SkillsController.Skills) do
											if localPlayer.Character:FindFirstChild(v5.Name):FindFirstChild("Level") then
												if WeaponData.Lvl[skill] <= localPlayer.Character:FindFirstChild(v5.Name).Level.Value then
													local condition = SkillsController.Condition and SkillsController.Condition()

													if condition then
														condition = not (SkillsController.Idle and SkillsController.Idle())
													end

													if condition then
														Press(skill, getgenv().Setting.FruitSkillsHold[skill] or 0)
														task.wait(0.3)
													end
												end
											end
										end
									else
										local name = GetCurrentTool(v4) and GetCurrentTool(v4).Name

										if name then
											Equip(name)

											for _, v6 in pairs({ "Z", "X", "C" }) do
												if localPlayer.Character:FindFirstChild(v5.Name):FindFirstChild("Level") then
													if v4 ~= "Melee" and v6 == "C" then
														continue
													elseif SkillsController.Condition and SkillsController.Condition() then
														if WeaponData.Lvl[v6] <= localPlayer.Character:FindFirstChild(v5.Name).Level.Value then
															if not (SkillsController.Idle and SkillsController.Idle()) then
																Press(v6)
																task.wait(0.2)
															end
														end

														continue
													end
												else
													continue
												end

												break
											end
										end
									end
								end
							end

							if SkillsController.Idle and SkillsController.Idle() then
								while SkillsController.Idle and SkillsController.Idle() and SkillsController.Condition and SkillsController.Condition() do
									task.wait(0.1)
								end
							end

							continue
						end

						break
					end
				end)

				if result then
					print("Skill Controller: ", result)
				end

				task.wait()
				Debounce = false
			end
		end
	end)

	print("Load SilentAim")

	if getgenv().OneClickSetting and getgenv().OneClickSetting.Mastery or not getgenv().OneClickSetting then
		loadstring([[                if string.find(identifyexecutor(),"macsploit") then
                    return 
                end
                local gt = getrawmetatable(game)
                local namecall = gt.__namecall
                setreadonly(gt, false)
                gt.__namecall = newcclosure(function(self, ...)

                    local method = getnamecallmethod()
                    local args = {...}
                    if method == "FireServer" then 
                        if tostring(self) == "RemoteEvent" then 
                            if tostring(args[1]) ~= "true" and tostring(args[1]) ~= "false" and not getgenv().Setting.Pvp.DisableSilentAim then
                                local HookPosition = (getgenv().SilentAimPos and getgenv().PosToHook) or (getgenv().Setting.Pvp.SilentAimNear and getgenv().HitPosition)
                                if HookPosition then
                                    if  #args == 1 and typeof(args[1]) == "Vector3" then
                                        args[1] = HookPosition
                                    end
                                    if #args == 1 and typeof(args[1]) == "CFrame" then
                                        args[1] = CFrame.new(HookPosition)
                                    end
                                end 
                            end
                        end

                    end
                    if method == "InvokeServer" then 
                        
                        if self.Parent ~= nil and tostring(self.Parent) == "Humanoid" then 
                        
                            if tostring(args[2]) ~= "true" and tostring(args[2]) ~= "false" and type(args[2]) == "vector" and not getgenv().Setting.Pvp.DisableSilentAim then
                            --  print(tostring(self),self.Parent,self.Parent.Parent)
                            --  print(tostring(getcallingscript()))
                                local HookPosition = (getgenv().SilentAimPos and getgenv().PosToHook) or (getgenv().Setting.Pvp.SilentAimNear and getgenv().HitPosition)
                                if HookPosition then
                                    --print("hooked 2")
                                    if  typeof(args[2]) == "Vector3" then
                                        args[2] = HookPosition
                                    end
                                    if typeof(args[2]) == "CFrame" then
                                        args[2] = CFrame.new(HookPosition)
                                    end
                                end
                            end
                        end
                    end
                    if method == "GetServerTimeNow" then
                        local callingscript = getcallingscript().Name
                        local func = getgenv().getcallingfunction(3)
                        if  callingscript == "Skyjump" then
                            
                            if debug.getinfo(func).name  == "jumped" then
                                getgenv().SkyFunc = func
                            end
                        else
                            if debug.getinfo(func).name  == "handleAction" then
                                if callingscript == "Dodge" then
                                    getgenv().DodgeFunc = func
                                end
                                if callingscript == "Soru" then 
                                    getgenv().SoruFunc = func
                                end
                            end
                        end
                    end

                    return namecall(self, unpack(args))
                end)
            ]])()
	end

	spawn(function()
		print("Loaded LP Modifier")

		while task.wait(0.1) do
			if getgenv().Setting.LocalPlayer.SoruNoCD then
				if getgenv().SoruFunc then
					local soruFunc = getgenv().SoruFunc

					for k, v4 in pairs(debug.getconstants(soruFunc)) do
						if type(v4) == "number" and v4 > 0.03 and v4 < 0.04 then
							debug.setconstant(soruFunc, k, 0)
						end
					end

					if #debug.getconstants(soruFunc) > 50 and #debug.getupvalues(soruFunc) > 8 then
						for _, v4 in pairs(debug.getupvalues(soruFunc)) do
							if type(v4) == "table" then
								if v4.LastUse and v4.LastAfter then
									v4.LastAfter = 0
									v4.LastUse = 0
								end
							end
						end
					end
				end
			end

			if getgenv().Setting.LocalPlayer.DashNoCD then
				if getgenv().DodgeFunc then
					local dodgeFunc = getgenv().DodgeFunc
					setupvalue(dodgeFunc, 6, 0)

					if getgenv().Setting.LocalPlayer.DoDashRange and getgenv().Setting.LocalPlayer.DashRange then
						setupvalue(dodgeFunc, 10, getgenv().Setting.LocalPlayer.DashRange)
					end
				end
			end

			if getgenv().Setting.LocalPlayer.InfGeppo and getgenv().SkyFunc then
				local skyFunc = getgenv().SkyFunc
				local v4 = next
				local v5, v6 = getupvalues(skyFunc)

				for k in v4, v5, v6 do
					if tostring(k) == "9" then
						setupvalue(skyFunc, k, 0)
					end
				end
			end
		end
	end)

	if not getgenv().Setting.OneClick.Enable then
		loadstring([[  
                if string.find(identifyexecutor(),"macsploit") then
                    return 
                end
                print("loading [0x02]")
                local lp = game.Players.LocalPlayer
                local gt2 = getrawmetatable(lp)
                local newIndex = gt2.__newindex
                setreadonly(gt2, false)
                gt2.__newindex = newcclosure(function(self, Index, Value)
                    if getgenv().Setting.LocalPlayer.SpeedHack and tostring(Index) == "WalkSpeed" and tostring(self) == "Humanoid"  then
                        Value = getgenv().Setting.LocalPlayer.Speed or 100
                    end
                    return newIndex(self, Index, Value)
                end)
            ]])()
	end

	print("Load Queue")

	fn18 = function(arg, arg2, arg3)
		if arg3 then
			for _, v4 in pairs(arg) do
				if LegitName(v4.Name) and fn5(v4) and string.find(v4.Name, arg3) and (not v4:GetAttribute("EscapeKey") or getgenv and getgenv().DoingEscapeQuest) then
					return v4
				end
			end
		end

		local function fn21(arg4)
			if arg2 == "Level30" then
				return string.find(arg4, "Sky")
			end

			if arg2 == "Level60" then
				return not table.find(AllBoss[currentPlaceKey], arg4) and not string.find(arg4, "Royal Soldier")
			end
			return true
		end

		local v4, v5, v6 = pairs(arg)
		local n2 = 99999
		local v7 = nil

		for _, v8 in v4, v5, v6 do
			local v9 = LegitName(v8.Name) and fn5(v8) and fn21(v8.Name) and fn19(v8)
			local doingEscapeQuest

			if v9 then
				local flag2 = not v8:GetAttribute("EscapeKey")

				if flag2 then
					doingEscapeQuest = flag2
				else
					doingEscapeQuest = getgenv and getgenv().DoingEscapeQuest
				end
			else
				doingEscapeQuest = v9
			end

			if doingEscapeQuest then
				local v10 = fn9(v8, localPlayer.Character)

				if v10 < n2 then
					n2 = v10
					v7 = v8
				end
			end
		end

		return v7
	end
end

getNearMob = function(arg, arg2)
	local handlers = {
		Katakuri = function(arg3)
			if string.match(arg3.Name, "Baking Staff") or string.match(arg3.Name, "Head Baker") or string.match(arg3.Name, "Cake Guard") or string.match(arg3.Name, "Cookie Crafter") then
				return true
			end
		end,
		Bone = function(arg3)
			if string.match(arg3.Name, "Reborn Skeleton") or string.match(arg3.Name, "Living Zombie") or string.match(arg3.Name, "Demonic Soul") or string.match(arg3.Name, "Posessed Mummy") then
				return true
			end
		end,
		Elite = function(arg3)
			if string.find(arg3.Name, "Diablo") or string.find(arg3.Name, "Deandre") or string.find(arg3.Name, "Urban") then
				return true
			end
		end,
		["Pirate Raid"] = function(arg3)
			local flag2 = fn5(arg3) and Alive()

			if flag2 then
				local centerCastle = PlacesPosition.CenterCastle
				flag2 = (fn4(arg3).Position - centerCastle).magnitude <= 1000
			end

			if flag2 and arg3.Name ~= "rip_indra True Form" then
				return true
			end
		end,
		Material = function(arg3)
			if Alive() and fn5(arg3) and tbl2.MaterialFarm.CheckMob[arg2].IsMob(arg3) then
				local flag2 = true

				if arg2 ~= "Dragon Scale" then
					if type(tbl2.MaterialFarm.CheckMob[arg2].Pos) ~= "table" then
						if (tbl2.MaterialFarm.CheckMob[arg2].Pos.Position - fn4(arg3).Position).magnitude >= 2500 then
							flag2 = false
						end
					else
						for _, v3 in pairs(tbl2.MaterialFarm.CheckMob[arg2].Pos) do
							if (v3.Position - fn4(arg3).Position).magnitude >= 3000 then
								flag2 = false
							end
						end
					end
				end

				return flag2
			end
		end,
		Factory = function(arg3)
			if arg3.Name == "Core" then
				return true
			end
		end,
	}

	local tbl5 = {}

	for _, child in pairs(enemies:GetChildren()) do
		if not child:GetAttribute("EscapeKey") or getgenv and getgenv().DoingEscapeQuest then
			if type(arg) == "string" and handlers[arg] then
				if handlers[arg](child) then
					table.insert(tbl5, child)
				end
			elseif type(arg) == "function" then
				if arg(child) and LegitName(child.Name) then
					table.insert(tbl5, child)
				end
			elseif child.Name == arg or type(arg) == "string" and MobNameMatches(child.Name, arg) or not arg then
				table.insert(tbl5, child)
			end
		end
	end

	return fn18(tbl5, nil, arg2 == "Pirate Raid" and "Tanky")
end

if getgenv then
	getgenv().GetNearMob = getNearMob
end

env.GetNearMob = getNearMob

do
	local lastMobPosition = {}

	if getgenv then
		getgenv().LastMobPosition = lastMobPosition
	end

	env.LastMobPosition = lastMobPosition

	local tbl5 = {
		Bandit = CFrame.new(1137.2, 12.7, 1594.2),
		Trainee = CFrame.new(-2722.6, 31.8, 2090),
		Monkey = CFrame.new(-1592.6, 27.7, 137.2),
		Gorilla = CFrame.new(-1313.4, 18.2, -548.4),
		["The Gorilla King"] = CFrame.new(-1193.9, 10.7, -549.8),
		Pirate = CFrame.new(-1140.6, 22.4, 3975.8),
		Brute = CFrame.new(-1203.8, 28.4, 4369.7),
		Bobby = CFrame.new(-1120.5, 54.7, 4121.2),
		Chef = CFrame.new(-1120.5, 54.7, 4121.2),
		["Desert Bandit"] = CFrame.new(923.7, 7.6, 4514),
		["Desert Officer"] = CFrame.new(1572.9, 14.4, 4159),
		["Snow Bandit"] = CFrame.new(1418, 76.7, -1437),
		Snowman = CFrame.new(1197, 96.1, -1603),
		Yeti = CFrame.new(1185, 106, -1518),
		["Chief Petty Officer"] = CFrame.new(-4809.4, 12.6, 4302.2),
		["Vice Admiral"] = CFrame.new(-5010.8, 15.1, 4383.7),
		Greybeard = CFrame.new(-4953.1, 13.9, 4159.8),
		["Sky Bandit"] = CFrame.new(-5091.6, 280.7, -1019.2),
		["Dark Master"] = CFrame.new(-5292.5, 504.9, -350.8),
		Prisoner = CFrame.new(5271.6, 7.1, 467.9),
		["Dangerous Prisoner"] = CFrame.new(5278.3, 16.1, 875.1),
		["Ruthless Prisoner"] = CFrame.new(5330, 25, 777),
		Warden = CFrame.new(5623.2, 1.4, 733.8),
		["Chief Warden"] = CFrame.new(5230, 10, 750),
		Swan = CFrame.new(5230, 10, 750),
		["Toga Warrior"] = CFrame.new(-1745.1, 10.2, -2705),
		Gladiator = CFrame.new(-1175.4, 11.6, -3213.7),
		["Military Soldier"] = CFrame.new(-5409.1, 17.1, 8499.2),
		["Military Spy"] = CFrame.new(-5841.6, 76.9, 8772.9),
		["Magma General"] = CFrame.new(-5625.7, 55.4, 8623),
		["Magma Admiral"] = CFrame.new(-5625.7, 55.4, 8623),
		["Fishman Warrior"] = CFrame.new(60792.9, 24.2, 1361.5),
		["Fishman Commando"] = CFrame.new(61928.2, 24.6, 1331.1),
		["Fishman Lord"] = CFrame.new(61352.9, 67.2, 1029.1),
		["God's Guard"] = CFrame.new(-4240.6, 1088.9, -403.7),
		Shanda = CFrame.new(-5975.6, 5469.5, 1800),
		["Royal Squad"] = CFrame.new(-6798.3, 5551.9, 1213.8),
		["Royal Soldier"] = CFrame.new(-7064.4, 5541.1, 939.4),
		["Sky Warlord"] = CFrame.new(-6271.6, 5472.8, 1887.8),
		Wysper = CFrame.new(-6271.6, 5472.8, 1887.8),
		["Lightning God"] = CFrame.new(-7125.4, 5596.1, 111.5),
		["Thunder God"] = CFrame.new(-7125.4, 5596.1, 111.5),
		["Galley Pirate"] = CFrame.new(5571.6, 78.4, 4009.8),
		["Galley Captain"] = CFrame.new(5409.5, 77.7, 4687),
		Cyborg = CFrame.new(6252.4, 9.3, 4941.4),
		["Saber Expert"] = CFrame.new(-1527.2, 34.1, -33.2),
		["The Saw"] = CFrame.new(-690, 15, 1580),
		["Mob Boss"] = CFrame.new(-2880.7, 6.7, 5430.9),
		Raider = CFrame.new(-628, 52, 2043),
		Mercenary = CFrame.new(-853, 52, 1756),
		Diamond = CFrame.new(-1583, 198, -12),
		["Swan Pirate"] = CFrame.new(882, 121, 1216),
		["Factory Staff"] = CFrame.new(295, 73, -56),
		Jeremy = CFrame.new(2316, 449, 787),
		["Marine Lieutenant"] = CFrame.new(-2726, 73, -2982),
		["Marine Captain"] = CFrame.new(-1980, 73, -3326),
		Orbitus = CFrame.new(-2116, 73, -3173),
		Fajita = CFrame.new(-2116, 73, -3173),
		Zombie = CFrame.new(-5654, 8, -737),
		Vampire = CFrame.new(-6022, 6, -1303),
		["Snow Trooper"] = CFrame.new(530, 402, -5347),
		["Winter Warrior"] = CFrame.new(1178, 430, -5189),
		["Awakened Ice Admiral"] = CFrame.new(5662, 28, -5983),
		["Lab Subordinate"] = CFrame.new(-5829, 16, -4445),
		["Horned Warrior"] = CFrame.new(-6390, 16, -5811),
		["Smoke Admiral"] = CFrame.new(-5078, 24, -5352),
		["Magma Ninja"] = CFrame.new(-5459, 22, -5420),
		["Lava Pirate"] = CFrame.new(-5377, 18, -5126),
		["Ship Deckhand"] = CFrame.new(1198, 126, 32988),
		["Ship Engineer"] = CFrame.new(917, 44, 32785),
		["Ship Steward"] = CFrame.new(916, 130, 33418),
		["Ship Officer"] = CFrame.new(917, 181, 33355),
		["Cursed Captain"] = CFrame.new(902, 125, 33072),
		["Arctic Warrior"] = CFrame.new(6038, 28, -6231),
		["Snow Lurker"] = CFrame.new(5561, 42, -6812),
		["Sea Soldier"] = CFrame.new(-3022, 16, -9797),
		["Water Fighter"] = CFrame.new(-3385, 239, -10542),
		["Tide Keeper"] = CFrame.new(-3800, 77, -11475),
		["Don Swan"] = CFrame.new(2284, 15, 804),
		["Pirate Millionaire"] = CFrame.new(-373, 75, 5550),
		["Pistol Billionaire"] = CFrame.new(-469, 74, 5904),
		Stone = CFrame.new(-1049, 40, 6791),
		["Dragon Crew Warrior"] = CFrame.new(6526, 378, 16),
		["Dragon Crew Archer"] = CFrame.new(6563, 148, -712),
		["Island Empress"] = CFrame.new(5700, 602, 199),
		["Female Islander"] = CFrame.new(4692, 745, 800),
		["Giant Islander"] = CFrame.new(4800, 600, -200),
		["Kilo Admiral"] = CFrame.new(2889, 74, -7233),
		["Captain Elephant"] = CFrame.new(-13393, 319, -8423),
		["Beautiful Pirate"] = CFrame.new(5311, 160, 129),
		["Marine Commodore"] = CFrame.new(-4800, 330, -2700),
		["Marine Rear Admiral"] = CFrame.new(-5026, 324, -2996),
		["Fishman Raider"] = CFrame.new(-10919, 332, -8698),
		["Fishman Captain"] = CFrame.new(-10993, 332, -8940),
		["Forest Pirate"] = CFrame.new(-13274, 332, -7926),
		["Mythological Pirate"] = CFrame.new(-13545, 470, -6917),
		["Jungle Pirate"] = CFrame.new(-12107, 332, -10665),
		["Musketeer Pirate"] = CFrame.new(-13290, 397, -9763),
		["Reborn Skeleton"] = CFrame.new(-8737, 143, 6035),
		["Living Zombie"] = CFrame.new(-10150, 140, 5930),
		["Demonic Soul"] = CFrame.new(-9501, 172, 6036),
		["Posessed Mummy"] = CFrame.new(-9500, 6, 6100),
		["Soul Reaper"] = CFrame.new(-9522, 316, 6752),
		["Peanut Scout"] = CFrame.new(-2124, 38, -10194),
		["Peanut President"] = CFrame.new(-2124, 38, -10194),
		["Ice Cream Chef"] = CFrame.new(-641, 65, -10719),
		["Ice Cream Commander"] = CFrame.new(-852, 66, -10932),
		["Cookie Crafter"] = CFrame.new(-2365, 38, -12099),
		["Cake Guard"] = CFrame.new(-1591, 38, -12297),
		["Baking Staff"] = CFrame.new(-1907, 38, -12866),
		["Head Baker"] = CFrame.new(-1926, 38, -12850),
		["Cocoa Warrior"] = CFrame.new(233, 75, -12498),
		["Chocolate Bar Battler"] = CFrame.new(233, 75, -12498),
		["Sweet Thief"] = CFrame.new(71, 77, -12632),
		["Candy Rebel"] = CFrame.new(134, 77, -12795),
		["Candy Pirate"] = CFrame.new(-1345, 16, -14360),
		["Snow Demon"] = CFrame.new(-1345, 16, -14360),
		["Cake Prince"] = CFrame.new(-2103, 70, -12165),
		["Dough King"] = CFrame.new(-2103, 70, -12165),
		Rip_indra = CFrame.new(-5333, 316, -2673),
		["Isle Outlaw"] = CFrame.new(-16168, 9, 438),
		["Island Boy"] = CFrame.new(-16450, 9, 748),
		["Sun-kissed Warrior"] = CFrame.new(-16350, 9, 1000),
		["Isle Champion"] = CFrame.new(-16529, 108, 749),
	}

	GetMobSpawnCFrame = function(arg)
		if not arg or arg == "" then
			return nil
		end
		local match = arg:match("^(.-)%s*%[") or arg
		local match2 = match:match("^%s*(.-)%s*$") or match
		local worldOrigin = workspace:FindFirstChild("_WorldOrigin") or workspace:FindFirstChild("WorldOrigin")
		local enemySpawns = worldOrigin and worldOrigin:FindFirstChild("EnemySpawns")

		if enemySpawns then
			local tbl6 = {}

			for _, child in ipairs(enemySpawns:GetChildren()) do
				if child:IsA("BasePart") then
					local match3 = child.Name:match("^(.-)%s*%[") or child.Name
					local match4 = match3:match("^%s*(.-)%s*$") or match3

					if child.Name == arg or match4 == match2 or MobNameMatches and (MobNameMatches(match4, match2) or MobNameMatches(child.Name, arg)) then
						table.insert(tbl6, child)
					end
				end
			end

			if #tbl6 > 0 then
				if #tbl6 == 1 then
					return tbl6[1].CFrame
				end
				local n2 = 0
				local n3 = 0
				local n4 = 0

				for _, v3 in ipairs(tbl6) do
					n2 += v3.Position.X
					n3 += v3.Position.Y
					n4 += v3.Position.Z
				end

				local n5 = #tbl6
				return CFrame.new(n2 / n5, n3 / n5, n4 / n5)
			end
		end

		if worldOrigin then
			for _, child in ipairs(worldOrigin:GetChildren()) do
				if child:IsA("BasePart") then
					local str = child.Name:lower()

					if str:find("respawn") or str:find("marker") then
						local match3 = child.Name:match("^(.-)%s*Respawn%s*Marker") or child.Name:match("^(.-)%s*Marker") or child.Name
						local match4 = match3:match("^%s*(.-)%s*$") or match3
						if MobNameMatches and MobNameMatches(match4, match2) or str:find(match2:lower(), 1, true) then
							return child.CFrame
						end
					end
				end
			end
		end

		for k, v3 in pairs(tbl5) do
			if MobNameMatches and MobNameMatches(k, match2) or k:lower() == match2:lower() then
				return v3
			end
		end

		local v3 = getNearMob and getNearMob(arg)

		if v3 and fn5 and fn5(v3) and v3:FindFirstChild("HumanoidRootPart") then
			local cFrame = v3.HumanoidRootPart.CFrame
			lastMobPosition[match2] = cFrame
			lastMobPosition[arg] = cFrame
			return cFrame
		end

		if lastMobPosition[match2] then
			return lastMobPosition[match2]
		end

		if lastMobPosition[arg] then
			return lastMobPosition[arg]
		end

		for k, v4 in pairs(lastMobPosition) do
			if MobNameMatches and MobNameMatches(k, match2) then
				return v4
			end
		end

		return nil
	end

	GetEnemySpawns = function(arg)
		if not arg or arg == "" then
			return {}
		end
		local match = arg:match("^(.-)%s*%[") or arg
		local match2 = match:match("^%s*(.-)%s*$") or match
		local worldOrigin = workspace:FindFirstChild("_WorldOrigin") or workspace:FindFirstChild("WorldOrigin")
		local enemySpawns = worldOrigin and worldOrigin:FindFirstChild("EnemySpawns")
		local tbl6 = {}

		if enemySpawns then
			for _, child in ipairs(enemySpawns:GetChildren()) do
				if child:IsA("BasePart") then
					local match3 = child.Name:match("^(.-)%s*%[") or child.Name
					local match4 = match3:match("^%s*(.-)%s*$") or match3

					if child.Name == arg or match4 == match2 or MobNameMatches and (MobNameMatches(match4, match2) or MobNameMatches(child.Name, arg)) or string.find(string.lower(child.Name), string.lower(match2), 1, true) or string.find(string.lower(match2), string.lower(match4), 1, true) then
						table.insert(tbl6, child.CFrame)
					end
				end
			end
		end

		if #tbl6 == 0 and worldOrigin then
			for _, child in ipairs(worldOrigin:GetChildren()) do
				if child:IsA("BasePart") then
					local str = child.Name:lower()

					if str:find("respawn") or str:find("marker") then
						local match3 = child.Name:match("^(.-)%s*Respawn%s*Marker") or child.Name:match("^(.-)%s*Marker") or child.Name
						match3 = match3:match("^%s*(.-)%s*$") or match3

						if MobNameMatches and MobNameMatches(match3, match2) or str:find(match2:lower(), 1, true) then
							table.insert(tbl6, child.CFrame)
						end
					end
				end
			end
		end

		if #tbl6 == 0 and tbl5 then
			for k, v3 in pairs(tbl5) do
				if MobNameMatches and MobNameMatches(k, match2) or string.find(string.lower(k), string.lower(match2), 1, true) then
					table.insert(tbl6, v3)
				end
			end
		end

		if #tbl6 == 0 and lastMobPosition then
			local v3 = lastMobPosition[match2] or lastMobPosition[arg]

			if v3 then
				table.insert(tbl6, v3)
			end
		end

		return tbl6
	end

	local tbl6 = {}

	TweenToMobSpawn = function(arg, arg2, arg3)
		arg2 = arg2 or 25
		if not arg or not Alive() then
			return
		end
		local v3 = GetEnemySpawns(arg)
		local v4

		if #v3 > 0 then
			local n2 = tbl6[arg] or 1

			if n2 > #v3 then
				n2 = 1
			end

			v4 = v3[n2]
			tbl6[arg] = n2 % #v3 + 1
		else
			v4 = GetMobSpawnCFrame(arg)

			if not v4 then
				v4 = lastMobPosition

				if lastMobPosition then
					v4 = lastMobPosition[arg]

					if not v4 then
						v4 = lastMobPosition[arg:match("^(.-)%s*%[") or arg]
					end
				end
			end
		end

		if v4 and Alive() then
			fn6(true)
			StatusFarming = "Tween To Mob Spawn [" .. tostring(arg) .. "]"

			DoTween2(v4 + Vector3.new(0, arg2, 0), function()
				if arg3 and not arg3() then
					return false
				end
				local v5 = getNearMob and getNearMob(arg)
				return not (v5 and fn5(v5))
			end)
		else
			if Alive() then
				fn6(true)
			else
				fn6(false)
			end

			task.wait(0.3)
		end
	end

	if getgenv then
		local v3 = GetMobSpawnCFrame
		getgenv().GetMobSpawnCFrame = v3
		local v4 = GetEnemySpawns
		getgenv().GetEnemySpawns = v4
		local v5 = TweenToMobSpawn
		getgenv().TweenToMobSpawn = v5
		getgenv().LastMobPosition = lastMobPosition
		local v6 = TeleportToUnderwater
		getgenv().TeleportToUnderwater = v6
		local v7 = FixTP
		getgenv().FixTP = v7
	end

	env.GetMobSpawnCFrame = GetMobSpawnCFrame
	env.GetEnemySpawns = GetEnemySpawns
	env.TweenToMobSpawn = TweenToMobSpawn
	env.LastMobPosition = lastMobPosition
end

env.TeleportToUnderwater = TeleportToUnderwater
env.FixTP = FixTP
local fn19, fn20

do
	local now = nil
	local now2 = tick()
	local now3 = tick()

	local function fn21(arg)
		if not (arg and Vector3.new) then
		end

		return CFrame.new(getgenv().Setting.Mastery.X or 0, getgenv().Setting.Mastery.Y or 30, getgenv().Setting.Mastery.Z or 0)
	end

	fn19 = function()
		return false
	end

	fn20 = function(arg, arg2, arg3, arg4, arg5, arg6, arg7)
		local fn22 = arg3 or function()
			return true
		end

		local function fn23()
			return fn22() and fn5(arg)
		end

		arg7 = arg7 or {}
		local ignoreEquip = arg7.IgnoreEquip
		local forceNotMastery = arg7.ForceNotMastery
		local farmMastery = arg7.FarmMastery
		local spin = arg7.Spin

		local ok, result = pcall(function()
			if fn5(arg) and Alive() and fn22() then
				local v3 = fn4(arg)

				if v3 and arg and arg.Name and LastMobPosition then
					local match = arg.Name:match("^(.-)%s*%[") or arg.Name
					LastMobPosition[match:match("^%s*(.-)%s*$") or match] = v3.CFrame
					LastMobPosition[arg.Name] = v3.CFrame
				end

				local humanoid = arg:FindFirstChild("Humanoid")

				if not fluxus then
					pcall(function()
					end)
				end

				Mastery = getgenv().Setting.Mastery.Enable or farmMastery
				SwordMastery = getgenv().Setting.Mastery["Sword/Low"] or SelectedWeaponAlternative
				arg2 = (arg2 or SelectedWeaponAlternative or farmMastery) and not forceNotMastery
				local n2 = Mastery and getgenv().Setting.Mastery.Health and getgenv().Setting.Mastery.Health / 100 or 0.5

				if humanoid and humanoid.Health <= humanoid.MaxHealth * n2 and arg2 and (SwordMastery or Mastery) then
					if Mastery then
						if getgenv().Setting.Mastery.Camera then
							localPlayer.CameraMaxZoomDistance = 0
							local currentCamera = workspace.CurrentCamera
							currentCamera.CFrame = CFrame.new(currentCamera.CFrame.Position, v3.Position)
						elseif localPlayer.CameraMaxZoomDistance <= 1 then
							localPlayer.CameraMaxZoomDistance = 200
							localPlayer.CameraMinZoomDistance = 100
							localPlayer.CameraMinZoomDistance = 0
						end

						local str

						if getgenv().Setting.UseDragonStorm then
							str = "Gun"
						elseif getgenv().Setting.OneClick.Enable then
							str = "Blox Fruit"
						else
							str = "Melee"
						end

						local position = v3.Position
						getgenv().PosToHook = position
						getgenv().SilentAimPos = true

						if getgenv().Setting.UseDragonStorm then
							if not localPlayer.Character:FindFirstChild("Dragonstorm") then
								pcall(Equip, "Dragonstorm")
								task.wait(0.1)
							end
						else
							pcall(Equip, GetCurrentTool(str, true))
						end

						local bloxFruit = str == "Gun" and { "Z", "X" } or str == "Melee" and { "Z", "X", "C" } or str == "Sword" and { "Z", "X" } or getgenv().Setting.SkillsSettingRemake["Blox Fruit"]
						local v4 = GetCurrentTool(str, true)

						if str == "Gun" then
							DoTween2(NewPos(arg, fn21(true)), fn23)
							local n3 = getgenv().Setting.UseDragonStorm and 0.2 or 0.5

							if tick() - now3 > n3 then
								now3 = tick()

								if getgenv().Setting.UseDragonStorm then
									BypassShootGun()
									local tbl5 = { v3.Position, { v3 } }
									game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RE/ShootGunEvent"):FireServer(unpack(tbl5))
								else
									ShootGun(v3.Parent, true)
								end
							end
						else
							local v5 = localPlayer.Character:FindFirstChild(v4)

							if v5 then
								if v5:FindFirstChild("Data") and v5:FindFirstChild("Level") then
									WeaponData = require(v5.Data)

									if WeaponData then
										local tbl5 = {}

										for _, v6 in pairs(bloxFruit) do
											if WeaponData.Lvl[v6] <= v5.Level.Value then
												table.insert(tbl5, v6)
											end
										end

										bloxFruit = tbl5
									end
								end
							end

							if IsSkillsNotCooldown(bloxFruit, v4) then
								now = nil

								if not now2 then
									now2 = tick()
								end

								if not arg4 then
									DoTween2(NewPos(arg, fn21(true)), fn23, nil, arg6)
								end
							elseif not arg4 then
								if not now then
									now = tick()
									now2 = nil
								elseif tick() - now <= 0.5 then
									DoTween2(NewPos(arg, fn21(true)), fn23, nil, arg6)
								else
									DoTween2(NewPos(arg, Vector3.new(0, 200, 0)), fn22)
								end
							end
						end
					else
						pcall(Equip, GetCurrentTool("Sword", true))

						if not arg4 then
							DoTween2(NewPos(arg, Vector3.new(0, 30, 0)), fn23, nil, arg6)
						end
					end

					fn6(true)

					if not arg5 then
						fn15("Near", arg, true)
					end
				else
					if not ignoreEquip then
						Equip(GetCurrentTool(GetCloseRangeAttack(), true))
					end

					if not arg4 then
						local flag2 = spin

						if spin then
							local position = v3.Position
							flag2 = (fn4(localPlayer.Character).Position - position).magnitude <= 200
						end

						if flag2 then
							local cframe3 = CFrame.new
							local n3 = v3.Position.Y + 30
							local z = v3.Position.Z
							fn4(localPlayer.Character).CFrame = cframe3(v3.Position.X + math.sin(math.rad(spin + 360)) * 30, n3, z + math.cos(math.rad(spin + 360)) * 30)
						else
							DoTween2(NewPos(arg, Vector3.new(0, 40, 0)) * cframe2, fn23, nil, arg6)
						end
					end

					fn6(true)

					if not arg5 then
						fn15("Near", arg)
					end
				end
			end
		end)

		if result then
			print(result)
		end
	end
end

FlagFirstExec = false
local v3, tbl5, tbl6, tbl7, tbl8, fn21

do
	local handlers = {
		Human = function(arg)
			local tbl9 = { "Jeremy", "Diamond", "Orbitus" }
			FlagBoss = true

			for _, v4 in pairs(tbl9) do
				local fajita = enemies:FindFirstChild(v4) or v4 == "Orbitus" and enemies:FindFirstChild("Fajita")

				if not (fajita and fn5(fajita)) then
					print(v4)
					FlagBoss = false
				end
			end

			if not FlagFirstExec then
				if FlagBoss then
					FlagFirstExec = true
				elseif getgenv().Setting["Race Evolve"].Hop or arg then
					print("Sv Hop")
					MainServerHop(5, "Finding Enough Bosses For Human [Race Evolve Hop]")
				end
			end

			for _, v4 in pairs(tbl9) do
				local v5 = enemies:FindFirstChild(v4)

				if fn5(v5) then
					SSS(GetNearSpawn(fn4(v5).Position))

					while fn5(v5) and task.wait(0.1) do
						fn20(v5)
					end
				end
			end
		end,
		Skypiea = function(arg)
			for _, v4 in pairs(fn3()) do
				if v4 ~= localPlayer then
					if v4 and v4.Character then
						local team = v4.Team

						if team then
							team = not (v4.Team.Name == "Pirates" or v4.Team.Name == "Marines")
						end

						if not (team or not v4.Team) then
							if v4.Data.Race.Value == "Skypiea" then
								local character = v4.Character
								print("Found")

								if fn5(character) and not IsInSafeZone(character) then
									print("Is Alive")
									local flag2 = false

									if not racvai then
										racvai = game:GetService("ReplicatedStorage").Remotes.CommE.OnClientEvent:Connect(function(arg2, ...)
											local v5 = table.pack(...)

											if arg2 == "Notify" then
												if string.find(..., "Cannot attack players in a Safe Zone") then
													racvai:Disconnect()
													racvai = nil
													flag2 = true
												end

												if string.find(v5[1], "Player died recently") then
													racvai:Disconnect()
													racvai = nil
													flag2 = true
												end
											end
										end)
									end

									local now = tick()
									SSS(GetNearSpawn(fn4(character).Position))
									print("Attacking")
									local enable = getgenv().Setting.FastAttack.Enable

									local function fn22()
										return fn5(character) and not flag2 and tick() - now < 90
									end

									while fn22() and task.wait(0.1) do
										if localPlayer.PlayerGui.Main.PvpDisabled.Visible == true then
											if not damopvp then
												damopvp = true
												game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EnablePvp")
												wait(6)
												damopvp = false
											end
										end

										pcall(Equip, GetCurrentTool("Melee", true))
										fn6(true)
										DoTween2(fn4(character), fn22, nil, { ForceTweenPause = true })
										fn6(true)
									end

									if racvai then
										racvai:Disconnect()
										racvai = nil
									end
								end
							end
						end
					end
				end
			end

			if game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Wenlocktoad", "1") == 2 then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Wenlocktoad", "3")
			elseif getgenv().Setting["Race Evolve"].Hop or arg then
				MainServerHop(5, "Find Player For Angel Race [Race Angel Hop]", 8)
			end
		end,
		Ghoul = function()
			for _, v4 in pairs(fn3()) do
				if v4 ~= localPlayer then
					if v4 and v4.Character then
						local team = v4.Team

						if team then
							team = not (v4.Team.Name == "Pirates" or v4.Team.Name == "Marines")
						end

						if not (team or not v4.Team) then
							local character = v4.Character
							print("Found")

							if fn5(character) then
								print("Is Alive")
								local flag2 = false

								if not racvai then
									racvai = game:GetService("ReplicatedStorage").Remotes.CommE.OnClientEvent:Connect(function(arg, ...)
										local v5 = table.pack(...)

										if arg == "Notify" then
											if string.find(..., "Cannot attack players in a Safe Zone") then
												racvai:Disconnect()
												racvai = nil
												flag2 = true
											end

											if string.find(v5[1], "Player died recently") then
												racvai:Disconnect()
												racvai = nil
												flag2 = true
											end
										end
									end)
								end

								local now = tick()
								SSS(GetNearSpawn(fn4(character).Position))
								print("Attacking")

								local function fn22()
									return fn5(character) and not flag2 and tick() - now < 90
								end

								while fn22() and task.wait(0.1) do
									if localPlayer.PlayerGui.Main.PvpDisabled.Visible == true then
										if not damopvp then
											damopvp = true
											game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EnablePvp")
											wait(6)
											damopvp = false
										end
									end

									pcall(Equip, GetCurrentTool("Melee", true))
									DoTween2(fn4(character), fn22, nil, { ForceTweenPause = true })
								end

								if racvai then
									racvai:Disconnect()
									racvai = nil
								end
							end
						end
					end
				end
			end

			if game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Wenlocktoad", "1") == 2 then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Wenlocktoad", "3")
			end
		end,
		Mink = function()
			local v4 = fn14()
			ChestCount = 0

			while ChestCount < 30 and task.wait(0.2) do
				if #v4 == 0 then
					v4 = fn14()
				else
					local huge = math.huge
					local v5 = nil

					for _, v6 in pairs(v4) do
						if v6 then
							local magnitude = (v6.Position - fn4(localPlayer.Character).Position).magnitude

							if magnitude < huge then
								huge = magnitude
								v5 = v6
							end
						end
					end

					if not v5 then
						task.wait(0.1)
					else
						local now = nil

						while true do
							if v5 and v5.Parent and #v5:GetChildren() > 1 and task.wait() then
								if fn9(v5, localPlayer.Character) <= 10 and not now then
									now = tick()
								end

								if now and tick() - now >= 2 then
									v5:SetAttribute("LastCollect", tick())
									break
								else
									localPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
									DoTween2(v5.CFrame)
									continue
								end
							end

							break
						end

						if v5 and table.find(v4, v5) then
							table.remove(v4, table.find(v4, v5))
						end

						ChestCount = ChestCount + 1
					end
				end
			end
		end,
		Fishman = function(arg)
			local tbl9 = { "StartSeaEvents", "SeaBeast", "Ship" }

			for _, v4 in pairs(tbl9) do
				SeaEventsController[v4] = arg and "OneClick" or "Race Evolve"
			end

			print("Starting Race Evolve Shark")

			while not IsRaceV3() and game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Wenlocktoad", "1") == 1 do
				task.wait(1)
			end

			print("End Race Evolve Shark")

			for _, v4 in pairs(tbl9) do
				SeaEventsController[v4] = nil
			end
		end,
		Cyborg = function()
			if #FruitFunc.HaveFruitInv() == 0 then
				local v4 = FruitFunc.GetFruitBelow1M()

				if v4 then
					FruitFunc.ReloadFruit(v4)
				end

				task.wait(0.5)
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Wenlocktoad", "3")
				FruitFunc.IgnoreStoreFruit = nil
			else
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Wenlocktoad", "3")
			end
		end,
	}

	HaveHaki = {}
	HakiColors = { ["Snow White"] = "Oyster", ["Winter Sky"] = "Hot pink", ["Pure Red"] = "Really red" }
	HakiFunc = {}

	HakiFunc.GetColor = function()
		return getgenv().LocalPlayerInv and getgenv().LocalPlayerInv.AuraSkin or {}
	end

	HakiFunc.CanOpenPad = function()
		if Sea3 then
			local boatCastle = game:GetService("Workspace").Map:FindFirstChild("Boat Castle")
			if not boatCastle then
				return false
			end
			local summoner = boatCastle:FindFirstChild("Summoner")
			if not summoner then
				return false
			end
			local circle = summoner:FindFirstChild("Circle")
			if not circle then
				return false
			end
			local tbl9 = {}
			if #circle:GetChildren() < 4 then
				return false
			end

			for _, child in pairs(circle:GetChildren()) do
				if child:FindFirstChild("TouchInterest") and tostring(child:FindFirstChild("Part").BrickColor) == "Lime green" then
					tbl9[tostring(child.BrickColor)] = true
				end
			end

			local n2 = 0

			for _, v4 in pairs(HakiColors) do
				if tbl9[v4] then
					n2 += 1
				end
			end

			if HaveHaki["Snow White"] and HaveHaki["Winter Sky"] and HaveHaki["Pure Red"] then
				return { true, n2 == 3 }
			end

			for _, v4 in pairs(HakiFunc.GetColor()) do
				HaveHaki[v4.DisplayName] = true
			end

			local n3 = 0
			local n4 = 0

			for k, v4 in pairs(HakiColors) do
				if tbl9[v4] then
					n3 += 1
				end

				if tbl9[v4] or HaveHaki[k] then
					n4 += 1
				end
			end

			return { n4 == 3, n3 == 3 }
		end
	end

	HaveAllHaki = function()
		for _, v4 in pairs(getgenv().LocalPlayerInv.AuraSkin) do
			HaveHaki[v4.DisplayName] = true
		end

		return HaveHaki["Snow White"] and HaveHaki["Winter Sky"] and HaveHaki["Pure Red"]
	end

	OpenPad = function()
		print("Called ")

		if Sea3 then
			if HakiFunc.CanOpenPad() and HakiFunc.CanOpenPad()[1] and not HakiFunc.CanOpenPad()[2] then
				print("In Called Open Pad")
				local n2 = 0

				while n2 < 5 and HakiFunc.CanOpenPad() and not HakiFunc.CanOpenPad()[2] and task.wait(0.1) do
					n2 += 1

					local ok, result = pcall(function()
						local boatCastle = game:GetService("Workspace").Map:FindFirstChild("Boat Castle")
						if not boatCastle then
							return
						end
						local summoner = boatCastle:FindFirstChild("Summoner")
						if not summoner then
							return
						end
						local circle = summoner:FindFirstChild("Circle")
						if not circle then
							return
						end

						for _, child in pairs(circle:GetChildren()) do
							if child:FindFirstChild("TouchInterest") and tostring(child:FindFirstChild("Part").BrickColor) ~= "Lime green" then
								local v4 = nil

								for k, v5 in pairs(HakiColors) do
									if v5 == tostring(child.BrickColor) then
										v4 = k
									end
								end

								game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/FruitCustomizerRF"):InvokeServer(unpack({ { StorageName = v4, Type = "AuraSkin", Context = "Equip" } }))
								TpNearestEntrance(child.Position)
								DoTween2(child.CFrame + Vector3.new(0, 2, 0))
								task.wait(0.5)
							end
						end
					end)

					if result then
						print("Errored Open pad", result)
					end
				end
			end
		end
	end

	WorkingFarm = PriorityQueue.thieunangquatroi()
	v3 = PriorityQueue.thieunangquatroi()

	isMinuteZero = function(arg)
		if string.find(arg, ":") then
			local str = string.sub(arg, string.find(arg, ":") + 1, string.find(arg, ":", string.find(arg, ":") + 1) - 1)
			return str == "00" or str == "01"
		end
		return true
	end

	CanGetFlower = function()
		return game.Workspace:FindFirstChild("Flower1").Transparency ~= 1 and not CheckItem("Flower 1") or not CheckItem("Flower 2") or not CheckItem("Flower 3")
	end

	V3Requirement = function()
	end

	GetMirageSnipeFruit = function()
		local flag2 = Sea3 and MirageFunctions.GetMirageIsland() and getgenv().Setting.Fruit.EnableSnipeFruit and #getgenv().Setting.Fruit.FruitsToSnipe > 0

		if flag2 then
			local value = localPlayer.Data.DevilFruit.Value
			flag2 = not table.find(getgenv().Setting.Fruit.FruitsToSnipe, value)
		end

		if flag2 and getgenv().Setting["Mirage Snipe Fruit"].Enable then
			local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetFruits", true)

			if response then
				for _, v4 in pairs(response) do
					local onSale = v4.OnSale

					if onSale then
						local name = v4.Name
						onSale = table.find(getgenv().Setting.Fruit.FruitsToSnipe, name)
					end

					if onSale then
						return v4.Name
					end
				end
			end
		end
	end

	Sea2KeyHop = function()
		if getgenv().Setting.OneClick.Sea2KeyHop and Sea2 and GetLevel() >= 1500 then
			if WorkingFarm:empty() then
				if not DataSave.Unlocked.Deathstep and not CheckEnemySpawn("Awakened Ice Admiral") or not DataSave.Unlocked.Sharkman and not CheckEnemySpawn("Tide Keeper") then
					return true
				end
			end
		end
	end

	X2Exp = function()
		return (getrenv()._G and getrenv()._G.ServerData and getrenv()._G.ServerData.ExpBoost ~= 0 or string.find(game:GetService("Players").LocalPlayer.PlayerGui.Main.Level.Exp.Text, "2x")) and GetLevel() ~= n
	end

	tbl5 = {
		Hell = function()
			return game:GetService("Workspace").Map:FindFirstChild("HellDimension") and game:GetService("Workspace").Map:FindFirstChild("HellDimension"):FindFirstChild("ActivePlayers") and game:GetService("Workspace").Map:FindFirstChild("HellDimension"):FindFirstChild("ActivePlayers"):FindFirstChild("Value") and localPlayer.Name == tostring(game:GetService("Workspace").Map:FindFirstChild("HellDimension"):FindFirstChild("ActivePlayers"):FindFirstChild("Value").Value)
		end,
		Heaven = function()
			return game:GetService("Workspace").Map:FindFirstChild("HeavenlyDimension") and game:GetService("Workspace").Map:FindFirstChild("HeavenlyDimension"):FindFirstChild("ActivePlayers") and game:GetService("Workspace").Map:FindFirstChild("HeavenlyDimension"):FindFirstChild("ActivePlayers"):FindFirstChild("Value") and localPlayer.Name == tostring(game:GetService("Workspace").Map:FindFirstChild("HeavenlyDimension"):FindFirstChild("ActivePlayers"):FindFirstChild("Value").Value)
		end,
	}

	tbl6 = {
		LastUse = tick(),
		Good = function()
			local lastUse = tbl6.LastUse

			if tick() - lastUse >= 1 then
				tbl6.LastUse = tick()
				game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack({ "CDKQuest", "OpenDoor" }))
				game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CDKQuest", "StartTrial", "Good")
			end
		end,
		Evil = function()
			local lastUse = tbl6.LastUse

			if tick() - lastUse >= 1 then
				tbl6.LastUse = tick()
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CDKQuest", "Progress", "Evil")
				task.wait(1)
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CDKQuest", "StartTrial", "Evil")
			end
		end,
		GetMob = function()
			local huge = math.huge
			local v4 = nil

			for _, child in pairs(enemies:GetChildren()) do
				if fn4(child) and child:FindFirstChild("Humanoid") and child:FindFirstChild("Humanoid").Health > 0 then
					if (fn4(child).Position - fn4(localPlayer.Character).Position).magnitude <= 3000 then
						if (fn4(child).Position - fn4(localPlayer.Character).Position).magnitude < huge then
							huge = (fn4(child).Position - fn4(localPlayer.Character).Position).magnitude
							v4 = child
						end
					end
				end
			end

			return v4
		end,
		GetHaze = function()
			local huge = math.huge
			local v4 = nil

			for _, child in pairs(enemies:GetChildren()) do
				if Alive() and fn5(child) and child.Parent == enemies and child:FindFirstChild("HazeESP") then
					if (fn4(child).Position - fn4(localPlayer.Character).Position).magnitude < huge then
						huge = (fn4(child).Position - fn4(localPlayer.Character).Position).magnitude
						v4 = child
					end
				end
			end

			for _, v5 in pairs(getnilinstances()) do
				if Alive() and fn5(v5) and v5:FindFirstChild("HazeESP") then
					if (fn4(v5).Position - fn4(localPlayer.Character).Position).magnitude < huge then
						huge = (fn4(v5).Position - fn4(localPlayer.Character).Position).magnitude
						v4 = v5
					end
				end
			end

			return v4
		end,
	}

	local function fn22()
		if Sea3 then
			DoTween2(CFrame.new(-5026.3584, 323.515503, -2996.28442))
		elseif Sea2 then
			DoTween2(CFrame.new(-384.03524780273, 73.020072937012, 353.2282409668))
		end
	end

	local function fn23(arg)
		if FruitFunc and FruitFunc.ReloadFruit then
			return FruitFunc.ReloadFruit(arg)
		end
		return game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadFruit", arg)
	end

	local function fn24(arg)
		if arg:FindFirstChild("RootPart") then
			return arg:FindFirstChild("RootPart")
		end

		if arg:FindFirstChild("Handle") then
			return arg:FindFirstChild("Handle")
		end
	end

	local function fn25()
		local v4 = pairs
		local Workspace = game:GetService("Workspace")
		local n2 = 999999
		local v5 = nil

		for _, child in v4(Workspace:GetChildren()) do
			if child:IsA("Tool") or string.find(child.Name, "Fruit") then
				if Alive() and child.Parent and child.Parent == game:GetService("Workspace") then
					if string.find(child.Name, "Fruit") then
						if not child:FindFirstChild("Fruit") then
							continue
						end
						child = child.Fruit
					end

					if fn24(child) then
						local character = localPlayer.Character
						local v6 = fn9(fn24(child), character)

						if v6 <= n2 then
							n2 = v6
							v5 = child
						end
					end
				end
			end
		end

		return v5
	end

	local function fn26(arg)
		pcall(function()
			fn23(arg)
			task.wait()
			local v4 = nil

			for _, child in pairs(localPlayer.Backpack:GetChildren()) do
				if child:GetAttribute("OriginalName") == arg then
					v4 = child
				end
			end

			for _, child in pairs(localPlayer.Character:GetChildren()) do
				if child:GetAttribute("OriginalName") == arg then
					v4 = child
				end
			end

			v4.Parent = game.Players.LocalPlayer.Character
			v4.EatRemote:InvokeServer()
		end)
	end

	local function fn27()
		local fruitEat = getgenv().OneClickSetting and getgenv().OneClickSetting.FruitEat or {}
		if #fruitEat == 0 then
			return false
		end
		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetFruits", false)
		local response2 = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetFruits", true)
		local tbl9 = {}

		for k in pairs(fruitEat) do
			table.insert(tbl9, k)
		end

		table.sort(tbl9, function(arg, arg2)
			return arg > arg2
		end)

		local flag2 = nil

		for _, v4 in pairs(tbl9) do
			for _, v5 in pairs(fruitEat[v4]) do
				if localPlayer.Data.DevilFruit.Value == v5 then
					flag2 = true
				end

				if not flag2 then
					continue
				end
				break
			end

			if flag2 then
				break
			end

			for _, v5 in pairs(fruitEat[v4]) do
				for _, v6 in pairs(response) do
					if v6.Name == v5 and v6.OnSale then
						if v6.Price <= localPlayer.Data.Beli.Value then
							return v5, "Normal"
						end
					end
				end
			end

			for _, v5 in pairs(fruitEat[v4]) do
				for _, v6 in pairs(response2) do
					if v6.Name == v5 and v6.OnSale then
						if v6.Price <= localPlayer.Data.Beli.Value then
							return v5, "Mirage"
						end
					end
				end
			end
		end

		return false
	end

	local function fn28()
		local fruitEat = getgenv().OneClickSetting and getgenv().OneClickSetting.FruitEat or {}
		if #fruitEat == 0 then
			return false
		end
		local bloxFruit = getgenv().LocalPlayerInv and getgenv().LocalPlayerInv["Blox Fruit"] or {}
		if not bloxFruit or type(bloxFruit) ~= "table" then
			return false
		end
		local tbl9 = {}

		for k in pairs(fruitEat) do
			table.insert(tbl9, k)
		end

		table.sort(tbl9, function(arg, arg2)
			return arg > arg2
		end)

		local flag2 = nil

		for _, v4 in pairs(tbl9) do
			for _, v5 in pairs(fruitEat[v4]) do
				if localPlayer.Data.DevilFruit.Value == v5 then
					flag2 = true
				end

				if not flag2 then
					continue
				end
				break
			end

			if flag2 then
				break
			end

			for _, v5 in pairs(fruitEat[v4]) do
				for _, v6 in pairs(bloxFruit) do
					if v6.Name == v5 then
						return v5
					end
				end
			end
		end

		return false
	end

	local tbl9 = {
		["Pilot Helmet"] = "Stone",
		["Serpent Bow"] = "Island Empress",
		Lei = "Kilo Admiral",
		["Twin Hook"] = "Captain Elephant",
		Canvander = "Beautiful Pirate",
		["Buddy Sword"] = "Cake Queen",
	}

	tbl7 = {}
	tbl8 = { "Stone", "Island Empress", "Kilo Admiral", "Captain Elephant", "Cake Queen" }

	local function fn29(arg)
		for k, v4 in pairs(tbl9) do
			if v4 == arg then
				print("State Items Boss: ", arg, CheckInvItem(k))
				tbl7[arg] = CheckInvItem(k)
			end
		end

		return tbl7[arg]
	end

	game:GetService("TextService")
	local TweenService = game:GetService("TweenService")
	local getaBiThieuNang = game:GetService("CoreGui"):FindFirstChild("Geta Bi Thieu Nang")
	local screenGui = Instance.new("ScreenGui")

	if getaBiThieuNang then
		getaBiThieuNang:Destroy()
	end

	Tween = function(arg, arg2, arg3, arg4, arg5)
		return TweenService:Create(arg, TweenInfo.new(arg2, arg3, arg4), arg5)
	end

	screenGui.Name = "Geta Bi Thieu Nang"
	screenGui.Parent = game:GetService("CoreGui")
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local frame = Instance.new("Frame")
	local uiListLayout = Instance.new("UIListLayout")
	frame.Name = "NotificationContainer_1"
	frame.Parent = screenGui
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 1
	frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	frame.BorderSizePixel = 0
	frame.Position = UDim2.new(1, 0, 0, 0)
	frame.Size = UDim2.new(0, 0, 0.970000029, 0)
	uiListLayout.Parent = frame
	uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	uiListLayout.Padding = UDim.new(0, 30)

	Notify = function(arg)
		local tbl10

		if type(arg) ~= "string" then
			tbl10 = arg
		else
			tbl10 = { Text = arg }
		end

		if type(tbl10) ~= "table" then
			return
		end
		local title = tbl10.Title or "Notification"
		local text = tbl10.Text or tbl10.Content or ""
		local subContent = tbl10.SubContent or nil
		local n2 = tonumber(tbl10.Delay or tbl10.Duration) or 5
		local fluent = getgenv().Fluent or lib

		if fluent and typeof(fluent.Notify) == "function" then
			pcall(function()
				fluent:Notify({ Title = title, Content = text, SubContent = subContent, Duration = n2 })
			end)
		else
			pcall(function()
				game:GetService("StarterGui"):SetCore("SendNotification", { Title = title, Text = tostring(text), Duration = n2 })
			end)
		end
	end

	local tbl10 = {}

	local tbl11 = {
		"Rip Indra",
		"Black Beard",
		"Saber Puzzle",
		"Sea 2",
		"Saber",
		"Elite",
		"Factory",
		"Pirate Raid",
		"Dough King",
		"Cake Prince",
		"GetFruit",
		"Doflamingo",
		"Sea 3",
		"Red Key",
		"Minimum Fragment",
		"Awaken Fruit",
		"Travel Sea3",
		"Library Key",
		"Water Key",
		"FullyRaceV4_Entrance",
		"Spawn Black Beard",
		"Mirage Snipe Fruit",
		"Soul Guitar",
		"Sea 2 Key Hop",
		"Soul Reaper",
		"Spawn Soul Reaper",
		"Unlock Electric Claw",
		"Bartilo",
		"God Human Material",
		"Tushita",
		"Tushita Hop",
		"CDK",
		"Pole",
		"Dough King Force",
		"Trade Sweet Chalice Force",
		"Material Soul Guitar",
		"Items Farm Force",
		"EatFruit",
		"SnipeFruitOneClick",
		"Swan Door Hop",
		"Mirror Fractal Hop",
		"Valkyrie Helm Hop",
		"Open Pad",
		"Spawn Rip Indra",
		"Yama",
	}

	local handlers2

	handlers2 = {
		["Race Evolve"] = function()
			local flag2 = Sea2 and CheckBartilo() and GetLevel() >= 850

			if flag2 then
				flag2 = not localPlayer.Data.Race:FindFirstChild("Evolved") and localPlayer.Data.Beli.Value >= 500000 and CanGetFlower()

				if not flag2 then
					flag2 = ProgressChecker.Sea3.Doflamingo and localPlayer.Data.Race:FindFirstChild("Evolved") and localPlayer.Data.Beli.Value >= 2000000 and not IsRaceV3() and handlers[localPlayer.Data.Race.Value]
				end
			end

			return flag2
		end,
		Yama = function()
			if Sea3 then
				if not CheckInvItem("Yama") then
					local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EliteHunter", "Progress")
					if response and response >= 30 then
						return true
					end
				end
			end
		end,
		["Get Ghoul"] = function()
			return not Sea2 or fn5(enemies:FindFirstChild("Cursed Captain")) or CheckItem("Hellfire Torch") or GetMaterial("Ectoplasm") < 100
		end,
		["Valkyrie Helm Hop"] = function()
			if GetLevel() < n then
				return
			end

			if Sea3 and not CheckItem("God's Chalice") and not CheckInvItem("Valkyrie Helm") and HaveAllHaki() and GetMaterial("Mirror Fractal") >= 1 then
				return true
			end
		end,
		["Mirror Fractal Hop"] = function()
			if GetLevel() < n then
				return
			end

			if Sea3 and not CheckItem("God's Chalice") and not CheckItem("Sweet Chalice") and GetMaterial("Mirror Fractal") == 0 and GetMaterial("Conjured Cocoa") >= 10 then
				return true
			end
		end,
		SnipeFruitOneClick = function()
			local v4, v5 = fn27()
			if v5 == "Normal" then
				return v4
			end

			if v5 == "Mirage" and Sea3 and MirageFunctions.GetMirageIsland() then
				return v4
			end
		end,
		["Tushita Hop"] = function()
			if Sea3 then
				if GetLevel() < 2000 then
					return
				end
				local turtle = game:GetService("Workspace").Map:FindFirstChild("Turtle")
				if not turtle or not turtle:FindFirstChild("TushitaGate") then
					return
				end

				if HaveAllHaki() then
					return true
				end
			end
		end,
		["Awaken Fruit"] = function()
			if Sea1 then
				return false, "Cant Raid In Sea 1"
			end

			if GetLevel() < 1100 then
				return false, "Not Enough Level"
			end

			if GetLevel() < n then
				return false, "Not Enough Level 2"
			end

			if X2Exp() then
				return false, "Not Gonna Waste X2 EXP LOL"
			end

			if CanAwaken() then
				if getgenv().Setting.OneClick.Enable and localPlayer.Data.DevilFruit.Value == "Dough-Dough" then
					return false
				end

				if CheckItem("Special Microchip") or GetValidFruitRaid() or GetRealFruitStore() then
					return true, "Activated"
				end
			end
		end,
		["Items Farm Force"] = function()
			if X2Exp() then
				return
			end

			if not DataSave.Unlocked.GodHuman then
				return
			end

			for _, v4 in pairs(tbl8) do
				if CheckEnemySpawn(v4) then
					if not tbl7[v4] then
						if not fn29(v4) then
							return true
						end
					end
				end
			end
		end,
		["Mirage Snipe Fruit"] = function()
			local flag2 = true

			if flag then
				flag2 = GetMirageSnipeFruit()
			end

			return flag2
		end,
		["Material Soul Guitar"] = function()
			if not FirstTimeCheckSoulGuitar then
				print("Checked First Time Soul Guitar")
				GuitarProgress()
				FirstTimeCheckSoulGuitar = true
			end

			if getgenv().Setting.OneClick.Enable then
				if Sea3 then
					if not DataSave.Unlocked.GodHuman and DataSave.Melee["Dragon Talon"].Mas400 then
						if not RequirementGod["3"] or not RequirementGod["4"] then
							return false
						end
					end
				end
			end

			local flag2 = DataSave.Unlocked.SoulGuitar and not CheckInvItem("Skull Guitar")

			if flag2 then
				flag2 = not RequirementGuitar["1"] or not RequirementGuitar["2"] or GetMaterial("Dark Fragment") == 0
			end

			return flag2
		end,
		["Trade Sweet Chalice Force"] = function()
			if Sea3 and CheckItem("God's Chalice") then
				local v4 = HakiFunc.CanOpenPad()
				local turtle = game:GetService("Workspace").Map:FindFirstChild("Turtle")
				if GetLevel() >= 2000 and turtle and turtle:FindFirstChild("TushitaGate") and v4[1] then
					return false
				end
				local tbl12 = { Coca = GetMaterial("Conjured Cocoa"), Mirror = GetMaterial("Mirror Fractal") }
				if (tbl12.Mirror <= 0 or not CanAwakenDough()) and tbl12.Coca >= 10 then
					return true
				end
			end

			return false
		end,
		EatFruit = function()
			return fn28()
		end,
		["Soul Guitar"] = function()
			return Sea3 and game:GetService("Lighting"):GetAttribute("MoonPhase") and game:GetService("Lighting"):GetAttribute("MoonPhase") == 5 and IsNight() and GetLevel() >= 2300 and not DataSave.Unlocked.SoulGuitar
		end,
		["Open Pad"] = function()
			if not Sea3 then
				return false
			end
			local v4 = HakiFunc.CanOpenPad()
			if type(v4) ~= "table" then
				return false
			end
			return v4[1] and not v4[2]
		end,
		Bartilo = function()
			if not FirstTimeCheckBartilo then
				CheckBartilo()
				FirstTimeCheckBartilo = true
			end

			local flag2 = Sea2 and GetLevel() >= 850 and not DataSave.BartiloQuest

			if flag2 then
				flag2 = not (not ProgressChecker.Bartilo.KilledSpring and ProgressChecker.Bartilo.KilledBandits and not enemies:FindFirstChild("Jeremy"))
			end

			return flag2
		end,
		FullyRaceV4_Entrance = function()
			if Sea3 and IsRaceV3() then
				local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("RaceV4Progress", "Check")
				if response >= 1 and response < 4 then
					return true
				end

				if response == 4 and MirageFunctions.GetMirageIsland() and GetMaterial("Mirror Fractal") >= 1 and CheckInvItem("Valkyrie Helm") and not game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CheckTempleDoor") then
					return true
				end
			end

			return false
		end,
		["Rip Indra"] = function()
			if Sea3 then
				for _, child in pairs(enemies:GetChildren()) do
					if child.Name == "rip_indra True Form" and fn5(child) then
						local turtle = game:GetService("Workspace").Map:FindFirstChild("Turtle")
						if GetLevel() >= 2000 and getgenv().Setting.OneClick.Enable and turtle and turtle:FindFirstChild("TushitaGate") then
							return false
						end
						return true
					end
				end
			end

			return false
		end,
		["Red Key"] = function()
			if Sea3 and CheckItem("Red Key") and not CanAwakenDough() then
				return true
			end
		end,
		["Cake Prince"] = function()
			if Sea3 then
				for _, child in pairs(enemies:GetChildren()) do
					if child.Name == "Cake Prince" and fn5(child) then
						return true
					end
				end
			end

			return false
		end,
		["Dough King"] = function()
			if Sea3 then
				for _, child in pairs(enemies:GetChildren()) do
					if child.Name == "Dough King" and fn5(child) then
						return true
					end
				end
			end

			return false
		end,
		["Spawn Rip Indra"] = function()
			if not Sea3 then
				return false, "Not In Sea 3"
			end

			if not CheckItem("God's Chalice") then
				return false, "Doesnt Have God Chalice"
			end

			if not HakiFunc.CanOpenPad() then
				return false, "Unexpected error orrured, report to the dev"
			end

			if not HakiFunc.CanOpenPad()[2] then
				return false, "Didnt Open All Haki Pad"
			end

			if not game:GetService("Workspace").Map.Turtle:FindFirstChild("TushitaGate") then
				local tbl12 = { Coca = GetMaterial("Conjured Cocoa"), Mirror = GetMaterial("Mirror Fractal") }
				if (tbl12.Mirror <= 0 or not CanAwakenDough()) and tbl12.Coca >= 10 then
					return false, "Need For Chocolate Cup"
				end
			end

			return true, "Activated"
		end,
		["Dough King Force"] = function()
			return Sea3 and CheckItem("Sweet Chalice")
		end,
		["Spawn Black Beard"] = function()
			return Sea2 and CheckItem("Fist of Darkness")
		end,
		["Spawn Soul Reaper"] = function()
			if not Sea3 then
				return false
			end

			if fn5(enemies:FindFirstChild("Soul Reaper")) then
				return false
			end

			if CheckItem("Hallow Essence") then
				return getgenv().Setting.OneClick.Enable and fn16().Evil >= -1 or not getgenv().Setting.OneClick.Enable
			end

			if getgenv().Setting["Spawn Soul Reaper"] and getgenv().Setting["Spawn Soul Reaper"].Enable then
				return true
			end
			return false
		end,
		["Soul Reaper"] = function()
			local v4 = fn16()
			return Sea3 and fn5(enemies:FindFirstChild("Soul Reaper")) and v4.Evil ~= -5 and v4.Evil ~= -4
		end,
		["Black Beard"] = function()
			if Sea2 then
				for _, child in pairs(enemies:GetChildren()) do
					if child.Name == "Darkbeard" and fn5(child) then
						return true
					end
				end
			end

			return false
		end,
		["Saber Puzzle"] = function()
			if Sea1 and localPlayer.Data.Level.Value >= 200 and not CheckInvItem("Saber") then
				if ProgressChecker.Saber.UsedRelic == nil then
					SaberProgress()
				end

				if not ProgressChecker.Saber.UsedRelic then
					return true
				end
			end

			return false
		end,
		["Unlock Electric Claw"] = function()
			return GetLevel() >= 2000 and not DataSave.Unlocked.Electricclaw
		end,
		["God Human Material"] = function()
			if DataSave.Unlocked.GodHuman then
				return false
			end

			if not (DataSave.Melee["Dragon Talon"] and DataSave.Melee["Dragon Talon"].Mas400) then
				return false
			end

			for i = 1, 4 do
				if not RequirementGod[tostring(i)] then
					return true
				end
			end

			return false
		end,
		Saber = function()
			if Sea1 and GetLevel() >= 200 and not CheckInvItem("Saber") then
				if ProgressChecker.Saber.UsedRelic == nil then
					SaberProgress()
				end

				if ProgressChecker.Saber.UsedRelic and not ProgressChecker.Saber.KilledShanks and CheckEnemySpawn("Saber Expert") then
					return true
				end
			end

			return false
		end,
		["Minimum Fragment"] = function()
			if Sea1 then
				return false, "Cant Raid In Sea 1"
			end

			if GetLevel() < 1300 then
				return false, "Not Enough Level"
			end

			if X2Exp() then
				return false, "Not Gonna Waste X2 EXP LOL"
			end

			if GetLevel() < 2000 then
				MinFragment = 2000
			end

			MinFragment = 5000
			if MinFragment and localPlayer.Data.Fragments.Value >= MinFragment then
				return false, "Over 10k Fragments"
			end

			if #FruitFunc.HaveFruitInv() > 0 then
				task.wait(1)
			end

			if CheckItem("Special Microchip") or #FruitFunc.HaveFruitInv() > 0 or FruitFunc.GetFruitBelow1M() then
				return true, "Activated"
			end
			return false, "Doesnt Have Fruit"
		end,
		Tushita = function()
			if Sea3 then
				if GetLevel() < 2000 then
					return
				end

				if game:GetService("Workspace").Map.Turtle:FindFirstChild("TushitaGate") then
					return fn5(enemies:FindFirstChild("rip_indra True Form"))
				end
				return fn5(enemies:FindFirstChild("Longma")) and not CheckInvItem("Tushita")
			end
		end,
		["Travel Sea3"] = function(arg)
			local mas400 = DataSave.Melee["Dragon Talon"].Mas400

			if mas400 then
				mas400 = not (DataSave.Unlocked.GodHuman or RequirementGod["1"] and RequirementGod["2"])
			end

			if not Sea2 then
				return false, "Not In Sea 2"
			end

			if not ProgressChecker.Sea3.FakeRipIndra then
				return false, "Not Killed Rip Indra"
			end

			if not DataSave.Unlocked.Deathstep then
				return false, "Not Unlocked Death Step"
			end

			if not DataSave.Unlocked.Sharkman then
				return false, "Not Unlocked Death Step"
			end

			if mas400 then
				return false, "Farming God Human Material"
			end
			local flag2 = DataSave.Unlocked.SoulGuitar and not CheckInvItem("Skull Guitar") and (not RequirementGuitar["1"] or GetMaterial("Dark Fragment") == 0)

			if flag2 then
				flag2 = not (getgenv().OneClickSetting and getgenv().OneClickSetting.DisableSoulGuitar)
			end

			if flag2 then
				return false, "Farming Skull Guitar Material"
			end

			if arg ~= "Status" then
				task.wait(10)
			end

			local str = ""

			local function fn30(arg2)
				str ..= arg2 .. " "
			end

			if DataSave.Melee["Dragon Talon"].Mas400 then
				fn30("[1]")
			end

			if DataSave.Unlocked.GodHuman then
				fn30("[2]")
			end

			if RequirementGod["1"] and RequirementGod["2"] then
				fn30("[3]")
			end

			if str == "" then
				str = "Traveling To Sea 3"
			end

			return true, "Activated", str
		end,
		Elite = function()
			return getNearMob("Elite")
		end,
		Factory = function()
			if Sea2 then
				return getNearMob("Core")
			end
		end,
		["Pirate Raid"] = function()
			if Sea3 then
				return getNearMob("Pirate Raid")
			end
			return false
		end,
		["Sea 2"] = function()
			if not Sea1 then
				return false, "Not Sea 1"
			end

			if localPlayer.Data.Level.Value < 700 then
				return false, "Not Enough Level"
			end

			if not CheckInvItem("Saber") then
				return false, "Doesnt Have Saber"
			end
			return true, "Activated"
		end,
		Greybeard = function()
			return false
		end,
		Pole = function()
			return GetLevel() >= 400 and fn5(enemies:FindFirstChild("Thunder God")) and not CheckInvItem("Pole (1st Form)")
		end,
		Doflamingo = function()
			if localPlayer.Data.Level.Value >= 1000 and Sea2 and SwanDoor.Check() and enemies:FindFirstChild("Don Swan") and not CheckInvItem("Swan Glasses") then
				return true
			end
			return false
		end,
		["Swan Door Hop"] = function()
			return Sea2 and localPlayer.Data.Level.Value >= 1500 and not SwanDoor.Check() and not SwanDoor.GetFruit() and getgenv().Setting.OneClick.SwanFruitHop
		end,
		["Sea 3"] = function()
			ThirdSeaProgress()
			if not Sea2 then
				return false, "Not In Sea 2"
			end

			if localPlayer.Data.Level.Value < 1500 then
				return false, "Not Enough Level"
			end

			if not DataSave.Unlocked.SwanDoor and not ProgressChecker.Sea3.Doflamingo then
				return false, "Not Unlocked Doflamingo Door"
			end

			if not ProgressChecker.Sea3.Doflamingo then
				return false, "Not Killed Flamingo"
			end

			if ProgressChecker.Sea3.FakeRipIndra then
				return false, "Already Killed Rip Indra"
			end
			return true
		end,
		BossSniper = function()
			for _, v4 in pairs(getgenv().Setting.BossSniper.SelectedBoss) do
				if fn5(game:GetService("Workspace").Enemies:FindFirstChild(v4)) then
					return true
				end
			end
		end,
		GetFruit = function()
			return fn25()
		end,
		["Library Key"] = function()
			if Sea2 and not DataSave.Unlocked.Deathstep and CheckEnemySpawn("Awakened Ice Admiral") and GetLevel() >= 850 then
				return true
			end
			return false
		end,
		["Water Key"] = function()
			if Sea2 and not DataSave.Unlocked.Sharkman and CheckEnemySpawn("Tide Keeper") and GetLevel() >= 850 then
				return true
			end
		end,
		["Sea 2 Key Hop"] = function()
			return Sea2KeyHop()
		end,
		CDK = function()
			if GetLevel() <= 2200 then
				return
			end

			if Sea3 and CheckInvItem("Tushita") and CheckInvItem("Yama") and not CheckInvItem("Cursed Dual Katana") then
				local v4 = fn16()
				if v4.Good == 4 and (v4.Evil == 3 or v4.Evil == 4) then
					return true
				end

				if not (v4.Good <= 3 and v4.Good ~= -2 and v4.Good ~= 4) then
					tbl6.Evil()
					return v4.Evil == -3 or v4.Evil == -4 or v4.Evil == -5 and game:GetService("Workspace").Enemies:FindFirstChild("Soul Reaper") or CheckItem("Hallow Essence") or tbl5.Hell()
				end
				tbl6.Good()
				if v4.Good == -3 then
					return true
				end

				if v4.Good == -4 and handlers2["Pirate Raid"]() then
					return true
				end

				if v4.Good == -5 then
					return true
				end
			end
		end,
	}

	local tbl12 = {
		["Sea 2"] = 3,
		Tushita = 1,
		["Rip Indra"] = 2,
		["Black Beard"] = 2,
		["Saber Puzzle"] = 2,
		Saber = 4,
		Elite = 3,
		["Pirate Raid"] = 3,
		Factory = 3,
		["Dough King"] = 2,
		["Tushita Hop"] = 9,
		["Swan Door Hop"] = 9,
		["Sea 2 Key Hop"] = 10,
		EatFruit = 9,
		Yama = 9,
		["Dough King Force"] = 3,
		["Cake Prince"] = 4,
		GetFruit = 4,
		["Sea 3"] = 4,
		Doflamingo = 3,
		["Mirror Fractal Hop"] = 9,
		["Valkyrie Helm Hop"] = 9,
		["Open Pad"] = 4,
		["Red Key"] = 3,
		["Minimum Fragment"] = 6,
		["Awaken Fruit"] = 6,
		["God Human Material"] = 6,
		FullyRaceV4_Entrance = 2,
		["Travel Sea3"] = 5,
		["Library Key"] = 4,
		["Water Key"] = 4,
		Bartilo = 5,
		["Trade Sweet Chalice Force"] = 3,
		["Race Evolve"] = 5,
		["Spawn Black Beard"] = 3,
		["Spawn Rip Indra"] = 5,
		SnipeFruitOneClick = 5,
		["Mirage Snipe Fruit"] = 3,
		["Soul Guitar"] = 3,
		["Material Soul Guitar"] = 7,
		["God Human"] = 4,
		["Spawn Soul Reaper"] = 4,
		["Soul Reaper"] = 4,
		Greybeard = 1,
		CDK = 1,
		["Get Ghoul"] = 6,
		["Unlock Electric Claw"] = 3,
		Pole = 5,
		BossSniper = 3,
		["Items Farm Force"] = 7,
	}

	local function fn30()
		if Sea3 then
			local turtle = game:GetService("Workspace").Map:FindFirstChild("Turtle")
			if turtle and not turtle:FindFirstChild("TushitaGate") and fn16().Evil == -5 then
				return "Bone", nil, nil
			end

			if getgenv().OneClickSetting and GetLevel() >= 2000 and getgenv().OneClickSetting.HopHakiColor then
				if not X2Exp() and getgenv().GetServerData.ColorDealer ~= 1 then
					if not HaveAllHaki() then
						if localPlayer.Data.Fragments.Value >= 7500 then
							local colorDealer = getgenv().GetServerData.ColorDealer

							if colorDealer then
								if OnlyLegendaryHaki and table.find({ "Snow White", "Pure Red", "Winter Sky" }, colorDealer) then
									game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ColorsDealer", "2")
								end
							end

							TrueServerHop(1, 6)
						end
					end
				end
			end

			if not X2Exp() then
				if not DataSave.Unlocked.Dragontalon then
					if CheckRandomBone() then
						return "Bone", function()
							return not DataSave.Unlocked.Dragontalon and not X2Exp()
						end
					end
				end
			end
		end

		if GetLevel() < 2000 then
			return "Level", nil, nil
		end

		if Sea3 and not X2Exp() then
			if not CanAwakenDough() then
				if GetMaterial("Conjured Cocoa") < 10 then
					local flag2 = nil

					local thread = task.spawn(function()
						while task.wait(1) do
							flag2 = GetMaterial("Conjured Cocoa") >= 10
						end
					end)

					return "Material", function()
						if flag2 then
							if thread then
								task.cancel(thread)
							end
						end

						return not flag2
					end, { Material = "Conjured Cocoa" }
				end
			end
		end

		if GetLevel() < n then
			return "Level", nil, nil
		end
		local v4 = GetCurrentTool("Blox Fruit")

		if v4 and v4:FindFirstChild("Level") and (getgenv().OneClickSetting and getgenv().OneClickSetting.Mastery or not getgenv().OneClickSetting) then
			local value = v4.Level.Value

			if GetMaxMastery(v4) > value then
				return "Katakuri", function()
					local level = v4.Parent ~= nil and v4 and v4:FindFirstChild("Level")

					if level then
						local value2 = v4.Level.Value
						level = GetMaxMastery(v4) > value2
					end

					return level
				end, { Mastery = true, FarmMastery = true }
			end
		end

		return "Katakuri", nil, nil
	end

	GetValidFruitRaid = function()
		local n2 = 1000000
		local n3 = 0

		if AutoChip[localPlayer.Data.DevilFruit.Value] == "Dough" then
			n2 = 10000000
			n3 = 1000000
		end

		for _, v4 in pairs(FruitFunc.HaveFruitInv()) do
			if FruitPrice[v4:GetAttributes().OriginalName] >= n3 and FruitPrice[v4:GetAttributes().OriginalName] < n2 then
				return true
			end
		end
	end

	GetRealFruitStore = function()
		if Sea3 and not CanAwakenDough() then
			return false
		end

		if AutoChip[localPlayer.Data.DevilFruit.Value] == "Dough" then
			return FruitFunc.GetFruitAbove1M()
		end
		return FruitFunc.GetFruitBelow1M()
	end

	local function fn31()
		return (HasActiveQuest() or localPlayer.PlayerGui.Main.Quest.Visible) and (not WorkingFarm or WorkingFarm:empty())
	end

	local handlers3

	handlers3 = {
		["Saber Puzzle"] = function()
			while Sea1 and GetLevel() >= 200 and not ProgressChecker.Saber.UsedRelic and not CheckInvItem("Saber") and task.wait(0.1) do
				StatusFarming = "Doing Saber Puzzle [Starting]"
				SaberProgress()
				if DataSave.Inventory.Saber or CheckInvItem("Saber") then
					StatusFarming = "Doing Saber Puzzle [Finished]"
					return
				end

				if Plates ~= 5 then
					StatusFarming = "Doing Saber Puzzle [Start Plates]"
					local connection = RunService.Stepped:Connect(fn7)

					while true do
						task.wait(0.2)
						SaberProgress()
						local questPlates = game:GetService("Workspace").Map.Jungle:FindFirstChild("QuestPlates")

						if questPlates then
							for i = 1, 5 do
								local button = questPlates:FindFirstChild("Plate" .. tostring(i))
								button = button and button:FindFirstChild("Button")

								if button then
									fn6(true)
									DoTween2(button.CFrame)
									pcall(firetouchinterest, fn4(localPlayer.Character), button, 0)
									task.wait(0.2)
									pcall(firetouchinterest, fn4(localPlayer.Character), button, 1)
								end

								task.wait(0.3)
							end
						end

						if Plates ~= 5 then
							continue
						end
						break
					end

					if connection then
						connection:Disconnect()
					end

					StatusFarming = "Doing Saber Puzzle [End Plates]"
				end

				SaberProgress()
				task.wait(0.2)

				if Plates == 5 and not ProgressChecker.Saber.UsedTorch then
					StatusFarming = "Doing Saber Puzzle [Start Torch]"

					if not CheckItem("Torch") then
						local torch = game:GetService("Workspace").Map.Jungle:FindFirstChild("Torch")
						DoTween2(torch and torch.CFrame or CFrame.new(-1679.2634, 20.4901, 170.7659))

						if torch and fn4(localPlayer.Character) then
							pcall(firetouchinterest, fn4(localPlayer.Character), torch, 0)
							task.wait(0.1)
							pcall(firetouchinterest, fn4(localPlayer.Character), torch, 1)
						end

						task.wait(0.5)
					end

					if CheckItem("Torch") then
						Equip("Torch")
						task.wait(0.2)
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "DestroyTorch")
						task.wait(0.3)
						SaberProgress()

						if not ProgressChecker.Saber.UsedTorch then
							DoTween2(CFrame.new(1121.07, 4, 4389.22))
							task.wait(0.5)
							Equip("Torch")
							task.wait(0.2)
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "DestroyTorch")
							task.wait(0.5)
						end
					end

					StatusFarming = "Doing Saber Puzzle [End Torch]"
				end

				SaberProgress()
				task.wait(0.2)

				if not ProgressChecker.Saber.UsedCup and ProgressChecker.Saber.UsedTorch then
					StatusFarming = "Doing Saber Puzzle [Start Cup]"

					if not CheckItem("Cup") then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "GetCup")
						task.wait(0.3)
					end

					if not CheckItem("Cup") then
						DoTween2(CFrame.new(1109.47, 4, 4402.89))
						task.wait(0.5)
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "GetCup")
						task.wait(0.5)
					end

					if CheckItem("Cup") then
						Equip("Cup")
						task.wait(0.2)
						local cup = localPlayer.Character:FindFirstChild("Cup") or localPlayer.Backpack:FindFirstChild("Cup")
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "FillCup", cup)
						task.wait(0.3)
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "SickMan")
						task.wait(0.3)
						SaberProgress()

						if not ProgressChecker.Saber.UsedCup then
							DoTween2(CFrame.new(1398, -152, -1520))
							task.wait(0.5)
							Equip("Cup")
							task.wait(0.2)
							local cup2 = localPlayer.Character:FindFirstChild("Cup") or localPlayer.Backpack:FindFirstChild("Cup")
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "FillCup", cup2)
							task.wait(0.5)
							DoTween2(CFrame.new(1503.4, 77.35, -1297.55))
							task.wait(0.5)
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "SickMan")
							task.wait(0.5)
						end
					end

					StatusFarming = "Doing Saber Puzzle [End Cup]"
				end

				SaberProgress()
				task.wait(0.2)

				if not ProgressChecker.Saber.TalkedSon and ProgressChecker.Saber.UsedCup and ProgressChecker.Saber.UsedTorch then
					StatusFarming = "Doing Saber Puzzle [Start Talk]"
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")
					task.wait(0.3)
					SaberProgress()

					if not ProgressChecker.Saber.TalkedSon then
						DoTween2(CFrame.new(-939.34, 26.03, 4114.77))
						task.wait(0.5)
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")
						task.wait(0.5)
					end

					StatusFarming = "Doing Saber Puzzle [End Talk]"
				end

				SaberProgress()
				task.wait(0.2)

				if ProgressChecker.Saber.TalkedSon and not ProgressChecker.Saber.KilledMob and ProgressChecker.Saber.UsedTorch and ProgressChecker.Saber.UsedCup then
					StatusFarming = "Doing Saber Puzzle [Start Mob Leader]"
					local cframe3 = CFrame.new(-2880.716, 10, 5430.853)
					local mobLeader = game.Workspace.Enemies:FindFirstChild("Mob Leader") or getNearMob("Mob Leader")

					if not fn5(mobLeader) then
						fn6(true)

						DoTween2(cframe3 + Vector3.new(0, 25, 0), function()
							return not fn5(game.Workspace.Enemies:FindFirstChild("Mob Leader") or getNearMob("Mob Leader"))
						end)

						mobLeader = game.Workspace.Enemies:FindFirstChild("Mob Leader") or getNearMob("Mob Leader")
					end

					if fn5(mobLeader) then
						while Alive() and fn5(mobLeader) and task.wait(0.2) do
							fn20(mobLeader, nil, function()
								return Alive() and fn5(mobLeader)
							end)
						end
					end

					StatusFarming = "Doing Saber Puzzle [End Mob Leader]"
				end

				SaberProgress()
				task.wait(0.2)

				if not ProgressChecker.Saber.UsedRelic and ProgressChecker.Saber.UsedTorch and ProgressChecker.Saber.UsedCup and ProgressChecker.Saber.KilledMob then
					StatusFarming = "Doing Saber Puzzle [Start Relic]"

					if not CheckItem("Relic") then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")
						task.wait(0.3)

						if not CheckItem("Relic") then
							DoTween2(CFrame.new(-939.34, 26.03, 4114.77))
							task.wait(0.5)
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")
							task.wait(0.5)
						end
					end

					if CheckItem("Relic") then
						DoTween2(CFrame.new(-1405.31445, 29.8519974, 4.34172916))
						task.wait(0.5)
						Equip("Relic")
						task.wait(0.2)

						pcall(function()
							local final = game:GetService("Workspace").Map.Jungle:FindFirstChild("Final")
							final = final and final:FindFirstChild("Invis")

							if final then
								final.CanCollide = false
								final.Size = Vector3.new(20, 20, 20)
							end
						end)

						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress", "PlaceRelic")
						task.wait(0.5)
					end

					StatusFarming = "Doing Saber Puzzle [End Relic]"
				end

				SaberProgress()
			end
		end,
		Yama = function()
			while not CheckInvItem("Yama") do
				StatusFarming = "Getting Yama"
				DoTween2(CFrame.new(5252.9560546875, 16.707324981689453, 462.70941162109375))
				fireclickdetector(game:GetService("Workspace").Map.Waterfall.SealedKatana.Hitbox.ClickDetector)
				task.wait(0.5)
			end
		end,
		Bartilo = function()
			while handlers2.Bartilo() and task.wait(0.1) do
				StatusFarming = "Doing Bartilo Quest"
				BartiloProgress()

				if not ProgressChecker.Bartilo.KilledBandits and not ProgressChecker.Bartilo.KilledSpring then
					while not ProgressChecker.Bartilo.KilledBandits and handlers2.Bartilo() and task.wait(0.1) do
						if not Alive() then
							fn6(false)

							while not Alive() do
								task.wait(1)
							end

							task.wait(1.5)

							if getgenv().Setting.AutoBuso and getgenv().Setting.AutoBuso.Enable then
								pcall(function()
									if localPlayer.Character and not localPlayer.Character:FindFirstChild("HasBuso") then
										game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
									end
								end)
							end
						else
							if not (HasActiveQuest("Swan Pirate") or HasActiveQuest("Citizen") or HasActiveQuest("Bartilo") or HasActiveQuest("BartiloQuest")) then
								StatusFarming = "[Bartilo] Getting Quest"
								DoTween2(CFrame.new(-461.533203, 72.3478546, 300.311096))
								task.wait(0.2)

								pcall(function()
									game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest", "BartiloQuest", 1)
								end)

								task.wait(0.3)
							end

							StatusFarming = "[Bartilo] Farming Swan Pirates (50 Kills)"
							local swanPirate = getNearMob("Swan Pirate")

							if fn5(swanPirate) then
								SSS(GetNearSpawn(fn4(swanPirate).Position))

								while Alive() and fn5(swanPirate) and not ProgressChecker.Bartilo.KilledBandits and task.wait(0.1) do
									fn20(swanPirate)
								end

								BartiloProgress()
							else
								SSS(GetNearSpawn(Vector3.new(964.2918, 73.08502, 1278.3036)))
								fn6(true)

								DoTween2(CFrame.new(Vector3.new(964.2918, 73.08502, 1278.3036) + Vector3.new(0, 25, 0)), function()
									return not fn5(getNearMob("Swan Pirate")) and not ProgressChecker.Bartilo.KilledBandits
								end)

								task.wait(0.2)
							end
						end
					end
				end

				BartiloProgress()

				if not ProgressChecker.Bartilo.KilledSpring and ProgressChecker.Bartilo.KilledBandits then
					StatusFarming = "[Bartilo] Finding Jeremy"
					DoTween2(CFrame.new(-461.533203, 72.3478546, 300.311096))
					task.wait(0.2)

					pcall(function()
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest", "BartiloQuest", 1)
					end)

					task.wait(0.3)

					if Alive() then
						local jeremy = game.Workspace.Enemies:FindFirstChild("Jeremy") or getNearMob("Jeremy")

						if fn5(jeremy) then
							StatusFarming = "[Bartilo] Killing Jeremy"
							SSS(GetNearSpawn(fn4(jeremy).Position))

							while Alive() and fn5(jeremy) and task.wait(0.1) do
								fn20(jeremy)
							end
						end
					else
						while not Alive() do
							task.wait(1)
						end
					end

					BartiloProgress()
					local killedBandits = not ProgressChecker.Bartilo.KilledSpring and ProgressChecker.Bartilo.KilledBandits

					if killedBandits then
						killedBandits = not (game.Workspace.Enemies:FindFirstChild("Jeremy") or getNearMob("Jeremy"))
					end

					if killedBandits then
						MainServerHop(5, "Finding Jeremy [Bartilo Quest]")
					end
				end

				BartiloProgress()

				if not ProgressChecker.Bartilo.DidPlates and ProgressChecker.Bartilo.KilledSpring and ProgressChecker.Bartilo.KilledBandits then
					StatusFarming = "[Bartilo] Solving Colosseum Plates"
					DoTween2(CFrame.new(-1837.6804199219, 11.032466888428, 1667.9600830078))

					for i = 1, 8 do
						local str = "Plate" .. tostring(i)
						local map = game:GetService("Workspace"):FindFirstChild("Map")
						map = map and map:FindFirstChild("Dressrosa")
						map = map and map:FindFirstChild("BartiloPlates")
						map = map and map:FindFirstChild(str)

						if map and fn4(localPlayer.Character) then
							local cFrame = map.CFrame
							fn4(localPlayer.Character).CFrame = cFrame
							task.wait(0.2)
						end
					end
				end

				BartiloProgress()
			end
		end,
		Saber = function()
			StatusFarming = "Killing Shank"

			while Sea1 and GetLevel() >= 200 and not CheckInvItem("Saber") and ProgressChecker.Saber.UsedRelic and not ProgressChecker.Saber.KilledShanks and task.wait(0.2) and CheckEnemySpawn("Saber Expert") do
				local saberExpert = enemies:FindFirstChild("Saber Expert") or getNearMob("Saber Expert")

				if not fn5(saberExpert) then
					local cframe3 = CFrame.new(-1405.31445, 29.8519974, 4.34172916)
					SSS(GetNearSpawn(cframe3.Position))
					DoTween2(cframe3 + Vector3.new(0, 10, 0))
					task.wait(0.5)
					saberExpert = enemies:FindFirstChild("Saber Expert") or getNearMob("Saber Expert")
				end

				if saberExpert and fn5(saberExpert) then
					local v4 = CreateSteppedLoop(fn7, "NoClipSaber")

					while Alive() and fn5(saberExpert) and task.wait(0.1) do
						StatusFarming = "Killing Shank"

						fn20(saberExpert, nil, function()
							return Alive() and fn5(saberExpert)
						end)
					end

					DisconnectLoop(v4)
				end

				SaberProgress()
			end
		end,
		["Sea 2"] = function()
			local cframe3 = CFrame.new(4852.28955, 5.65145, 718.5307)
			local cframe4 = CFrame.new(1212.38342, 21.3974915, -1429.6394)

			while Sea1 and task.wait(0.1) do
				SecondSeaProgress()
				local door = workspace.Map:FindFirstChild("Ice") and workspace.Map.Ice:FindFirstChild("Door")

				if door and (not door.CanCollide or door.Transparency == 1) then
					ProgressChecker.Sea2.UsedKey = true
				end

				if not ProgressChecker.Sea2.UsedKey and not CheckItem("Key") then
					StatusFarming = "Getting Key from Detective"

					pcall(function()
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
					end)

					task.wait(0.5)
					SecondSeaProgress()

					if not CheckItem("Key") and not ProgressChecker.Sea2.UsedKey then
						StatusFarming = "Going to Detective [Prison]"
						DoTween2(cframe3)
						local position = cframe3.Position

						if (fn4(localPlayer.Character).Position - position).Magnitude < 50 then
							pcall(function()
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
							end)

							task.wait(0.5)
							SecondSeaProgress()
						end
					end
				end

				if not ProgressChecker.Sea2.UsedKey and CheckItem("Key") and Alive() then
					StatusFarming = "Using Key on Ice Door"
					Equip("Key")
					local cFrame = door and door.CFrame or CFrame.new(1288.73328, 35.8959961, -1361.06274)
					DoTween2(cFrame)
					local character = localPlayer.Character
					local key = character and character:FindFirstChild("Key")
					key = key and key:FindFirstChild("Handle")

					if door then
						if firetouchinterest and key then
							firetouchinterest(key, door, 0)
							task.wait(0.1)
							firetouchinterest(key, door, 1)
						end

						local position = cFrame.Position

						if (fn4(character).Position - position).Magnitude < 20 then
							pcall(function()
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "UseKey")
							end)
						end
					end

					task.wait(0.5)
					SecondSeaProgress()

					if door and (not door.CanCollide or door.Transparency == 1) then
						ProgressChecker.Sea2.UsedKey = true
					end
				end

				if not ProgressChecker.Sea2.KilledIceBoss and (ProgressChecker.Sea2.UsedKey or door and not door.CanCollide) then
					local iceAdmiral = enemies:FindFirstChild("Ice Admiral") or getNearMob("Ice Admiral")

					if not iceAdmiral or not fn5(iceAdmiral) then
						StatusFarming = "Moving to Ice Admiral Room"
						DoTween2(cframe4)
						task.wait(0.5)
						iceAdmiral = enemies:FindFirstChild("Ice Admiral") or getNearMob("Ice Admiral")
					end

					if iceAdmiral and fn5(iceAdmiral) then
						local v4 = CreateSteppedLoop(fn7, "NoClipIceAdmiral")

						while Alive() and fn5(iceAdmiral) and task.wait(0.1) do
							StatusFarming = "Killing Ice Admiral"

							fn20(iceAdmiral, nil, function()
								return Alive() and fn5(iceAdmiral)
							end)
						end

						DisconnectLoop(v4)
						task.wait(0.5)
						SecondSeaProgress()
					else
						StatusFarming = "Waiting for Ice Admiral..."
						task.wait(2)
						SecondSeaProgress()
						local flag2 = not ProgressChecker.Sea2.KilledIceBoss

						if flag2 then
							flag2 = not (enemies:FindFirstChild("Ice Admiral") or getNearMob("Ice Admiral"))
						end

						if flag2 then
							MainServerHop(5, "Hop Find Ice Admiral")
						end
					end
				end

				if ProgressChecker.Sea2.KilledIceBoss then
					StatusFarming = "Ice Admiral Defeated! Teleporting to Sea 2 via Remote..."

					pcall(function()
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Detective")
					end)

					task.wait(0.2)
					MainTravel(3, "Finished Sea 1", "Sea2")
				end

				SecondSeaProgress()
			end
		end,
		SubmergedFarming = function(arg)
			local value = localPlayer.Data.Level.Value
			local n2 = 0

			for k in pairs(tbl2.TripleQuest[arg]) do
				if k >= n2 and k <= value and k ~= nil then
					n2 = k
				end
			end

			if not tbl2.TripleQuest[arg][n2] then
				return
			end
			local v4 = tbl2.TripleQuest[arg][n2]
			local questCFrame = v4.QuestCFrame
			local quest = v4.Quest
			local requirement = v4[2] and v4[2].Requirement or math.huge
			local n3 = 1

			if requirement <= value then
				n3 = 2
			end

			local questCheck = v4[n3].QuestCheck
			StatusFarming = "Submerged Farming [Lv. " .. value .. "]"

			while getgenv().Setting.OneClick.Enable and Alive() and localPlayer.Data.Level.Value <= 2800 and (not WorkingFarm or WorkingFarm:empty()) do
				if not fn10(localPlayer.Character) then
					StatusFarming = "Traveling to Submerged Island"

					if (fn4(localPlayer.Character).Position - Vector3.new(-16274.825, 25.220568, 1375.0765)).magnitude > 12 then
						DoTween2(CFrame.new(Vector3.new(-16274.825, 25.220568, 1375.0765)))
					end

					if (fn4(localPlayer.Character).Position - Vector3.new(-16274.825, 25.220568, 1375.0765)).magnitude <= 15 then
						pcall(function()
							local net = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net")
							net["RF/SubmarineWorkerSpeak"]:InvokeServer("AskKilledTikiBoss")
							net["RF/SubmarineWorkerSpeak"]:InvokeServer("TravelToSubmergedIsland")
						end)

						local now = tick()

						while true do
							task.wait(0.2)
							if not (fn10(localPlayer.Character) or tick() - now > 5) then
								continue
							end
							break
						end
					end

					if not fn10(localPlayer.Character) then
						if improvedTeleport then
							improvedTeleport(Vector3.new(11256, -2138, 9888) + Vector3.new(0, 50, 0))
						end

						task.wait(1)
					end
				end

				if not fn10(localPlayer.Character) then
					task.wait(0.5)
				else
					if not localPlayer.PlayerGui.Main.Quest.Visible or not FindQuest(localPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, questCheck) then
						if localPlayer.PlayerGui.Main.Quest.Visible then
							CancelQuest()
							task.wait(0.3)
						end

						StatusFarming = "Getting Quest [" .. questCheck .. "]"
						local position = questCFrame.Position

						if (fn4(localPlayer.Character).Position - position).magnitude > 10 then
							DoTween2(questCFrame)
						end

						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest", quest, n3)
						task.wait(0.5)
					end

					if localPlayer.PlayerGui.Main.Quest.Visible then
						local v5 = getNearMob(questCheck)

						if fn5(v5) and (fn4(v5).Position - Vector3.new(11256, -2138, 9888)).magnitude < 2500 then
							StatusFarming = "Farming [" .. questCheck .. "]"
							FixTP(v5.Name)

							while Alive() and fn5(v5) and localPlayer.PlayerGui.Main.Quest.Visible and (fn4(v5).Position - Vector3.new(11256, -2138, 9888)).magnitude < 2500 and (not WorkingFarm or WorkingFarm:empty()) and task.wait(0.2) do
								FixTP(v5.Name)
								fn20(v5, nil, fn31)
							end
						else
							StatusFarming = "Finding Mob [" .. questCheck .. "]"
							FixTP(questCheck)

							TweenToMobSpawn(questCheck, 25, function()
								return not fn5(getNearMob(questCheck)) and localPlayer.PlayerGui.Main.Quest.Visible and fn31()
							end)

							task.wait(0.2)
						end
					end

					local value2 = localPlayer.Data.Level.Value
					local n4 = 0

					for k in pairs(tbl2.TripleQuest[arg]) do
						if k >= n4 and k <= value2 and k ~= nil then
							n4 = k
						end
					end

					if n4 ~= n2 then
						local v5 = tbl2.TripleQuest[arg][n4]
						questCFrame = v5.QuestCFrame
						quest = v5.Quest

						if (v5[2] and v5[2].Requirement or math.huge) <= value2 then
							n3 = 2
						else
							n3 = 1
						end

						questCheck = v5[n3].QuestCheck
						n2 = n4
					end

					task.wait(0.1)
				end
			end
		end,
		IdleFarming = function(arg, arg2, arg3)
			local tbl13 = arg3 or {}

			local fn32 = arg2 or function()
				return true
			end

			if arg == "Level" then
				if not Increment then
					Increment = 1
				end

				local value = localPlayer.Data.Level.Value
				local n2 = 150

				if n2 <= value then
					local n3 = 0

					for k in pairs(tbl2.TripleQuest[currentPlaceKey]) do
						if k >= n3 and k <= value and k ~= nil then
							n3 = k
						end
					end

					if n3 == 0 then
						local huge = math.huge

						for k in pairs(tbl2.TripleQuest[currentPlaceKey]) do
							if type(k) == "number" and k < huge then
								huge = k
							end
						end

						if huge ~= math.huge then
							n3 = huge
						end
					end

					if Sea3 and value >= 2600 and tbl2.TripleQuest[currentPlaceKey][2600] then
						handlers3.SubmergedFarming(currentPlaceKey)
						return
					end

					if tbl2.TripleQuest[currentPlaceKey][n3] ~= nil then
						local v4 = nil

						for i = 3, 5 do
							if tbl2.TripleQuest[currentPlaceKey][n3][i] then
								if value >= tbl2.TripleQuest[currentPlaceKey][n3][i].Requirement and CheckEnemySpawn(tbl2.TripleQuest[currentPlaceKey][n3][i].QuestCheck) then
									v4 = tbl2.TripleQuest[currentPlaceKey][n3][i]
								end
							end
						end

						if v4 then
							StatusFarming = "Farming Boss (Triple Quest Method)"

							if not HasActiveQuest(v4.QuestCheck) then
								CancelQuest()
								FixTP(v4.QuestCheck)

								if not HasActiveQuest(v4.QuestCheck) then
									SSS(GetNearSpawn(v4.QuestCFrame.Position))
									DoTween2(v4.QuestCFrame)
									game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest", v4.Quest, v4.Index or 3)
									task.wait(0.3)
								end
							end

							local v5 = GetMainEnemy(v4.QuestCheck)

							if fn5(v5) then
								SSS(GetNearSpawn(fn4(v5).Position))
								FixTP(v5.Name)

								while Alive() and fn5(v5) and task.wait(0.2) do
									if Alive() and fn5(v5) then
										pcall(function()
											FixTP(v5.Name)
											pcall(Equip, GetCurrentTool("Melee", true))
											ResizeBoss(v5, true)
											fn12(v5, Vector3.new(0, 20, 20))
										end)
									end
								end
							end
						else
							if GetSettingHopExploiter() then
								HopNearExploiter()
							end

							local v5 = tbl2.TripleQuest[currentPlaceKey][n3]
							local flag2 = v5 and v5[2]

							if flag2 then
								flag2 = value >= (v5[2].Requirement or math.huge)
							end

							local n4 = 1

							if flag2 then
								n4 = 2
							end

							local questCheck = v5[n4].QuestCheck

							if HasActiveQuest() and not HasActiveQuest(questCheck) then
								CancelQuest()
								task.wait(0.2)
							end

							local v6 = questCheck

							if not HasActiveQuest(questCheck) then
								StatusFarming = "Getting Quest [" .. tostring(v6) .. "]"
								FixTP(questCheck)

								while not SafeGetQuest(v5.QuestCFrame, v5.Quest, n4, nil, questCheck) and task.wait(0.1) do
									StatusFarming = "Getting Quest [" .. tostring(v6) .. "]"
									FixTP(questCheck)
									SSS(GetNearSpawn(v5.QuestCFrame.Position))
									DoTween2(v5.QuestCFrame)
								end
							end

							StatusFarming = "Farming Lv [" .. v6 .. "]"
							local now = tick()

							local function fn33()
								return Alive() and getgenv().Setting.OneClick.Enable and WorkingFarm:empty() and HasActiveQuest(v6) and fn32()
							end

							while true do
								if task.wait(0.1) and HasActiveQuest(v6) and getgenv().Setting.OneClick.Enable and WorkingFarm:empty() then
									if not Alive() then
										fn6(false)

										while not Alive() do
											task.wait(1)
										end

										task.wait(1.5)

										if getgenv().Setting.AutoBuso and getgenv().Setting.AutoBuso.Enable then
											pcall(function()
												if localPlayer.Character and not localPlayer.Character:FindFirstChild("HasBuso") then
													game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
												end
											end)
										end

										if HasActiveQuest(v6) then
											continue
										end
									else
										if tick() - now >= 5 then
											if not Alive() then
												fn6(false)
											end

											now = tick()
										end

										local v7 = getNearMob(v6)

										if fn5(v7) then
											local v8 = fn4(v7)

											if v8 and LastMobPosition then
												LastMobPosition[v6] = v8.CFrame
												local match = v7.Name:match("^(.-)%s*%[") or v7.Name
												LastMobPosition[match:match("^%s*(.-)%s*$") or match] = v8.CFrame
											end

											FixTP(v7.Name)

											while true do
												if Alive() and fn5(v7) and fn33() and task.wait(0.2) then
													fn20(v7, nil, fn33)
													if not fn19(v7, fn33) then
														continue
													end
												end

												break
											end
										else
											pcall(Equip, GetCurrentTool("Melee", true))
											FixTP(v6)

											TweenToMobSpawn(v6, 25, function()
												return HasActiveQuest(v6) and fn33()
											end)

											task.wait(0.2)
										end

										continue
									end
								end

								break
							end

							local value2 = localPlayer.Data.Level.Value

							for k in pairs(tbl2.TripleQuest[currentPlaceKey]) do
								if k >= n3 and k <= value2 then
									n3 = k
								end
							end
						end
					else
						print("Error: Farming Highest " .. n3)
					end
				else
					local str, cframe3

					if value <= 30 then
						str = "Sky Bandit"
						cframe3 = CFrame.new(-5014.0341796875, 280.72146606445312, -972.079345703125)
					else
						str = "God's Guard"
						cframe3 = CFrame.new(-4227.2509765625, 1088, -567.60888671875)
					end

					StatusFarming = "Jump Lv Farming [" .. str .. "]"

					if Alive() then
						local function fn33()
							return Alive() and getgenv().Setting.OneClick.Enable and localPlayer.Data.Level.Value < n2
						end

						local v4 = getNearMob(str)
						local flag2 = v4 and fn5(v4)

						if flag2 then
							local position = cframe3.Position
							flag2 = (fn4(v4).Position - position).magnitude < 2500
						end

						if flag2 then
							FixTP(v4.Name)
							local position = fn4(v4).Position

							if (fn4(localPlayer.Character).Position - position).magnitude > 50 then
								DoTween2(CFrame.new(position) * CFrame.new(0, 40, 0), fn33)
							end

							while true do
								if Alive() and fn5(v4) and fn33() and task.wait(0.2) then
									fn20(v4, nil, fn33)
									if not fn19(v4, fn33) then
										continue
									end
								end

								break
							end
						else
							local v5 = GetMobSpawnCFrame(str) or cframe3
							fn6(true)

							DoTween2(v5 + Vector3.new(0, 25, 0), function()
								return fn33() and not fn5(getNearMob(str))
							end)

							task.wait(0.2)
						end
					end
				end
			else
				local function fn33()
					return fn32() and WorkingFarmEmpty()
				end

				if tbl13.Mastery then
					handlers3[arg]("OneClick", fn33, true, nil, tbl13)
				elseif arg == "Material" then
					handlers3[arg](tbl13.Material, "OneClick", fn33)
				else
					handlers3[arg]("OneClick", fn33)
				end
			end
		end,
		["Race Evolve"] = function(arg)
			Type = "Race Evolve"
			StatusFarming = "Ready To Evolve Race"

			if not localPlayer.Data.Race:FindFirstChild("Evolved") then
				if ProgressChecker.RaceV2.DoneRace == nil then
					RaceV2Progress()
				end

				if not ProgressChecker.RaceV2.DoneRace then
					RaceV2Progress()

					if not StartRace then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ "Alchemist", "2" }))
					end

					if not CheckItem("Flower 2") then
						local n2 = 0

						while true do
							if not CheckItem("Flower 2") and task.wait(0.1) then
								StatusFarming = "Getting Flower 2"
								DoTween2(game.Workspace:FindFirstChild("Flower2").CFrame)
								n2 += 1
								task.wait(2)
								if not (n2 >= 5) then
									continue
								end
							end

							break
						end

						if n2 >= 5 and not CheckItem("Flower 2") then
							MainServerHop(5, "Error Flower 2 [Race Evolve]")
						end
					end

					if not CheckItem("Flower 1") and game.Workspace:FindFirstChild("Flower1").Transparency ~= 1 then
						local n2 = 0

						while true do
							if not CheckItem("Flower 1") and game.Workspace:FindFirstChild("Flower1").Transparency ~= 1 and task.wait(0.1) then
								StatusFarming = "Getting Flower 1"
								DoTween2(game.Workspace:FindFirstChild("Flower1").CFrame)
								n2 += 1
								task.wait(2)
								if not (n2 >= 5) then
									continue
								end
							end

							break
						end

						if n2 >= 5 and not CheckItem("Flower 1") then
							MainServerHop(5, "Error Flower 1 [Race Evolve]")
						end
					end

					if not CheckItem("Flower 3") then
						local function fn32()
							local flag2 = not CheckItem("Flower 3")

							if flag2 then
								flag2 = not (not CheckItem("Flower 1") and game.Workspace:FindFirstChild("Flower1").Transparency ~= 1)
							end

							return flag2
						end

						while fn32() and task.wait(0.1) do
							handlers3.Material("Ectoplasm", arg or Type, fn32)
						end
					end

					if CheckItem("Flower 3") and CheckItem("Flower 2") and CheckItem("Flower 1") then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ "Alchemist", "3" }))
					end
				end
			else
				while handlers2["Race Evolve"]() and task.wait(0.1) do
					local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Wenlocktoad", "1")

					if response == 0 then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Wenlocktoad", "2")
					end

					if response == 1 and handlers[localPlayer.Data.Race.Value] then
						print("Calling")
						handlers[localPlayer.Data.Race.Value](arg == "OneClick")
					end

					if response == 2 then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Wenlocktoad", "3")
					end
				end
			end
		end,
		Doflamingo = function()
			local donSwan = game.Workspace.Enemies:FindFirstChild("Don Swan")

			if fn5(donSwan) and SwanDoor.Check() then
				SSS(GetNearSpawn(fn4(donSwan).Position))

				while fn5(donSwan) and task.wait(0.1) do
					StatusFarming = "Farming Doflamingo"
					fn20(donSwan, nil)
				end
			end
		end,
		["Red Key"] = function()
			while Alive() and CheckItem("Red Key") and not CanAwakenDough() and wait(0.5) do
				pcall(function()
					Equip("Red Key")

					pcall(function()
						workspace.Map.CakeLoaf.RedDoor.Part.Size = Vector3.new(20, 20, 20)
					end)

					pcall(function()
						workspace.Map.CakeLoaf.RedDoor.Size = Vector3.new(20, 20, 20)
					end)

					DoTween2(CFrame.new(-2681.85522, 64.5855331, -12851.9971, 0.0693147331, -8.22019004e-08, 0.997594833, -4.90588299e-08, 1, 8.58087859e-08, -0.997594833, -5.48886518e-08, 0.0693147331))
				end)
			end
		end,
		["Sea 3"] = function()
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ "ZQuestProgress", "Begin" }))
			wait(3)
			ThirdSeaProgress()
			local ripIndra = game.Workspace.Enemies:FindFirstChild("rip_indra")

			if fn5(ripIndra) and not ProgressChecker.Sea3.FakeRipIndra then
				StatusFarming = "Attacking Rip Indra"

				local thread = task.spawn(function()
					while task.wait(1) do
						ThirdSeaProgress()
					end
				end)

				local function fn32()
					return fn9(ripIndra, localPlayer.Character) <= 1000 and not ProgressChecker.Sea3.FakeRipIndra
				end

				while fn5(ripIndra) and Alive() and task.wait(0.1) and fn32() do
					fn20(ripIndra, nil, fn32)
				end

				if thread then
					task.cancel(thread)
				end
			end

			ThirdSeaProgress()
		end,
		["Awaken Fruit"] = function()
			if getgenv().Setting.OneClick.Enable and WorkingFarmEmpty() then
				handlers3.Raid("OneClick")
			end
		end,
		["Minimum Fragment"] = function()
			while MinFragment and localPlayer.Data.Fragments.Value < MinFragment and (FruitFunc.GetFruitBelow1M() or #FruitFunc.HaveFruitInv() >= 1) and task.wait() and getgenv().Setting.OneClick.Enable and WorkingFarmEmpty() do
				handlers3.Raid("OneClick")
			end
		end,
		["Spawn Rip Indra"] = function()
			if HakiFunc.CanOpenPad() and HakiFunc.CanOpenPad()[2] then
				StatusFarming = "Spawning Rip Indra [Equip]"
				Equip("God's Chalice")
				StatusFarming = "Spawning Rip Indra [TP]"
				pcall(TpNearestEntrance, PlacesPosition.CenterCastle)
				task.wait(0.2)
				DoTween2(PlacesPosition.SpawnRipIndra)
				StatusFarming = "Spawning Rip Indra [Fire]"
				local boatCastle = game:GetService("Workspace").Map:FindFirstChild("Boat Castle")

				if boatCastle then
					local summoner = boatCastle:FindFirstChild("Summoner")

					if summoner then
						local detection = summoner:FindFirstChild("Detection")

						if detection then
							fn(fn4(localPlayer.Character), detection, 0)
							task.wait()
							fn(fn4(localPlayer.Character), detection, 1)
						end
					end
				end

				task.wait(4)
			end
		end,
		["Spawn Black Beard"] = function()
			local darkbeard = game:GetService("Workspace").Enemies:FindFirstChild("Darkbeard")
			if fn5(darkbeard) then
				return
			end

			if CheckItem("Fist of Darkness") then
				StatusFarming = "Spawning Black Beard"

				if localPlayer.Character and localPlayer.Character:FindFirstChild("Humanoid") then
					localPlayer.Character.Humanoid.Sit = false
				end

				local cframe3 = CFrame.new(3777.22266, 13.319315, -3496.96118, 0.19671461, -0.00182435918, 0.980459094, -5.4860313e-05, 0.999998271, 0.00187172298, -0.980460763, -0.000421983568, 0.196714163)
				SSS(GetNearSpawn(Vector3.new(3777.2227, 13.319315, -3496.9612)))

				while Alive() and (fn4(localPlayer.Character).Position - Vector3.new(3777.2227, 13.319315, -3496.9612)).magnitude >= 10 and task.wait(0.1) do
					pcall(function()
						DoTween2(cframe3)
					end)
				end

				if Alive() then
					fn4(localPlayer.Character).CFrame = cframe3
				end

				Equip("Fist of Darkness")
				task.wait(0.8)

				pcall(function()
					local detection = nil

					pcall(function()
						detection = game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection
					end)

					if not detection then
						local darkbeardArena = workspace.Map:FindFirstChild("DarkbeardArena")

						if darkbeardArena and darkbeardArena:FindFirstChild("Summoner") then
							detection = darkbeardArena.Summoner:FindFirstChild("Detection")
						end
					end

					if detection then
						pcall(function()
							fn(fn4(localPlayer.Character), detection, 0)
							task.wait(0.1)
							fn(fn4(localPlayer.Character), detection, 1)
						end)

						task.wait(0.2)

						if localPlayer.Character and localPlayer.Character:FindFirstChild("Fist of Darkness") and localPlayer.Character["Fist of Darkness"]:FindFirstChild("Handle") then
							pcall(function()
								fn(localPlayer.Character["Fist of Darkness"].Handle, detection, 0)
								task.wait(0.1)
								fn(localPlayer.Character["Fist of Darkness"].Handle, detection, 1)
							end)
						end
					end
				end)

				local n2 = 0

				while n2 < 10 and not fn5(game:GetService("Workspace").Enemies:FindFirstChild("Darkbeard")) and Alive() do
					StatusFarming = "Waiting for Darkbeard animation..."
					task.wait(0.5)
					n2 += 0.5
				end
			end
		end,
		["Black Beard"] = function(arg, arg2)
			local str = "Black Beard"

			local fn32 = arg2 or function()
				return true
			end

			local function fn33()
				if not arg then
					if getgenv().Setting[str].Enable then
						return true
					end
				elseif getgenv().Setting[arg].Enable and fn32() then
					return true
				end

				return false
			end

			local darkbeard = game.Workspace.Enemies:FindFirstChild("Darkbeard")

			if fn5(darkbeard) then
				while fn5(darkbeard) and task.wait(0.1) and fn33() do
					StatusFarming = "Attacking Black Beard"
					fn20(darkbeard, nil)
				end
			end

			fn6(false)
		end,
		YoruV3 = function(arg, arg2)
			local str = "YoruV3"

			arg2 = arg2 or function()
				return true
			end

			local function fn32()
				if not arg then
					if getgenv().Setting[str].Enable then
						return true
					end
				elseif getgenv().Setting[arg].Enable and arg2() then
					return true
				end

				return false
			end

			local tbl13 = { "StartSeaEvents", "SeaBeast", "Ship" }

			for _, v4 in pairs(tbl13) do
				SeaEventsController[v4] = "Race Evolve"
			end

			while arg2() and not CheckItem("Fist of Darkness") do
				task.wait(1)
			end

			for _, v4 in pairs(tbl13) do
				SeaEventsController[v4] = nil
			end

			if CheckItem("Fist of Darkness") and arg2() then
				DoTween2(CFrame.new(-384.03524780273, 73.020072937012, 353.2282409668))
			end

			while CheckItem("Fist of Darkness") and arg2() and task.wait(0.1) do
				if getgenv().Setting.YoruV3.Upgrade then
					local v4 = game.Players:FindFirstChild(getgenv().Setting.YoruV3.SelectedPlayer)

					if v4 then
						local flag2 = false

						for _, child in pairs(v4.Backpack:GetChildren()) do
							if child.Name == "Fist of Darkness" then
								flag2 = true
							end
						end

						for _, child in pairs(v4.Character:GetChildren()) do
							if child.Name == "Fist of Darkness" then
								flag2 = true
							end
						end

						if flag2 then
							DoTween2(CFrame.new(-5725.2001953125, 48.480113983154297, -771.59503173828125))
						end

						if game.Workspace.Enemies:FindFirstChild("Darkbeard") then
							fireclickdetector(game:GetService("Workspace").Map.GraveIsland.Mountain.Rocks.Button.ClickDetector)
						end
					end
				else
					local v4 = game.Players:FindFirstChild(getgenv().Setting.YoruV3.SelectedPlayer)

					if v4 then
						local flag2 = false

						for _, child in pairs(v4.Backpack:GetChildren()) do
							if child.Name == "Fist of Darkness" then
								flag2 = true
							end
						end

						for _, child in pairs(v4.Character:GetChildren()) do
							if child.Name == "Fist of Darkness" then
								flag2 = true
							end
						end

						if flag2 and fn9(v4.Character, Vector3.new(-5725.2, 48.480114, -771.59503)) <= 100 then
							handlers3["Spawn Black Beard"](arg or "YoruV3", fn32)
						end
					end
				end
			end
		end,
		Tushita = function(arg, arg2)
			local str = "Tushita"

			arg2 = arg2 or function()
				return true
			end

			local function fn32()
				if not arg then
					if getgenv().Setting[str].Enable then
						return true
					end
				elseif getgenv().Setting[arg].Enable and arg2() then
					return true
				end

				return false
			end

			local function fn33()
				return fn5(game.Workspace.Enemies:FindFirstChild("rip_indra True Form")) and fn32()
			end

			if game:GetService("Workspace").Map.Turtle:FindFirstChild("TushitaGate") then
				if fn33() then
					StatusFarming = "Doing Tushita Quest"

					repeat
						wait()
						StatusFarming = "Doing Tushita Quest [Wait Alive]"
					until Alive()

					for i = 1, 10 do
						pcall(function()
							localPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(5712.98681640625, 18.041336059570312, 253.65997314453125)
						end)

						task.wait()
					end

					while true do
						wait()
						StatusFarming = "Doing Tushita Quest [Tweening To Door]"

						pcall(function()
							SSS(GetNearSpawn(Vector3.new(5712.987, 18.041336, 253.65997)))
							DoTween2(Vector3.new(5712.987, 18.041336, 253.65997))
						end)

						if not (CheckItem("Holy Torch") or not fn33()) then
							continue
						end
						break
					end

					if CheckItem("Holy Torch") then
						while true do
							wait()
							StatusFarming = "Doing Tushita Quest [Equipping]"

							pcall(function()
								Equip("Holy Torch")
							end)

							if not (localPlayer.Character and localPlayer.Character:FindFirstChild("Holy Torch") and CheckItem("Holy Torch")) then
								continue
							end
							break
						end

						while true do
							wait()
							StatusFarming = "Doing Tushita Quest [Doing Quest Torhces]"

							for k, v4 in game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("TushitaProgress").Torches, nil, nil do
								if not v4 then
									task.spawn(function()
										game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("TushitaProgress", "Torch", k)
									end)
								end
							end

							if not (not game:GetService("Workspace").Map.Turtle:FindFirstChild("TushitaGate") or not CheckItem("Holy Torch") or not fn33()) then
								continue
							end
							break
						end

						game:GetService("Workspace").Map.Turtle:FindFirstChild("TushitaGate"):Destroy()
					end
				end
			elseif not CheckInvItem("Tushita") then
				local longma = game.Workspace.Enemies:FindFirstChild("Longma")

				if fn5(longma) then
					StatusFarming = "Killing Longma"
					SSS(GetNearSpawn(fn4(longma).Position))

					while fn5(longma) and task.wait(0.1) and fn32() do
						fn20(longma, nil)
					end

					task.wait(2)
				end
			end
		end,
		["Tushita Hop__1"] = function(arg, arg2)
			local str = "Tushita Hop__1"

			arg2 = arg2 or function()
				return true
			end

			local function fn32()
				if not arg then
					if getgenv().Setting[str].Enable then
						return true
					end
				elseif getgenv().Setting[arg].Enable and arg2() then
					return true
				end

				return false
			end

			if not Sea3 then
				Travel("Sea3")
			end

			if game:GetService("Workspace").Map.Turtle:FindFirstChild("TushitaGate") then
				local function fn33()
					return not fn5(game.Workspace.Enemies:FindFirstChild("rip_indra True Form")) and fn32()
				end

				handlers3.Elite(arg or "Tushita Hop__1")
				handlers3["Collect Chest"](arg or "Tushita Hop__1", fn33, true)

				if CheckItem("God's Chalice") then
					handlers3["Open Pad"](arg or "Tushita Hop__1", fn33)
					handlers3["Spawn Rip Indra"](arg or "Tushita Hop__1", fn33)
					task.wait(1)
				end
			end

			local tushita = handlers3.Tushita
			arg = arg or "Tushita Hop__1"
			tushita(arg, fn32)
			task.wait(0.5)

			if not game:GetService("Workspace").Map.Turtle:FindFirstChild("TushitaGate") and not fn5(game.Workspace.Enemies:FindFirstChild("Longma")) then
				MainServerHop(5, "Find New Server [Tushita Hop 1]")
			end
		end,
		["Black Beard Hop"] = function(arg, arg2)
			local str = "Black Beard Hop"

			local fn32 = arg2 or function()
				return true
			end

			local function fn33()
				if not arg then
					if getgenv().Setting[str].Enable then
						return true
					end
				elseif getgenv().Setting[arg].Enable and fn32() then
					return true
				end

				return false
			end

			if not Sea2 then
				Travel("Sea2")
			end

			local function fn34()
				return not fn5(game.Workspace.Enemies:FindFirstChild("Darkbeard")) and fn33()
			end

			handlers3["Collect Chest"](arg or "Black Beard Hop", fn34, true)

			if CheckItem("Fist of Darkness") then
				handlers3["Spawn Black Beard"](arg or "Black Beard Hop", fn33)
				task.wait(1)
			end

			handlers3["Black Beard"](arg or "Black Beard Hop", fn33)

			if fn34() then
				MainServerHop(5, "Find New Server [Black Beard Hop]")
			end
		end,
		["Rip Indra"] = function(arg, arg2)
			local str = "Rip Indra"
			StatusFarming = "Killing Rip Indra"

			local fn32 = arg2 or function()
				return true
			end

			local function fn33()
				if not arg then
					if getgenv().Setting[str].Enable then
						return true
					end
				elseif getgenv().Setting[arg].Enable and fn32() then
					return true
				end

				return false
			end

			local ripIndraTrueForm = game.Workspace.Enemies:FindFirstChild("rip_indra True Form")

			if fn5(ripIndraTrueForm) then
				pcall(TpNearestEntrance, PlacesPosition.CenterCastle)

				while fn5(ripIndraTrueForm) and task.wait(0.1) and fn33() do
					fn20(ripIndraTrueForm, nil)
				end
			end
		end,
		["Rip Indra Hop"] = function(arg, arg2)
			local str = "Rip Indra Hop"

			local fn32 = arg2 or function()
				return true
			end

			local function fn33()
				if not arg then
					if getgenv().Setting[str].Enable then
						return true
					end
				elseif getgenv().Setting[arg].Enable and fn32() then
					return true
				end

				return false
			end

			if not Sea3 then
				Travel("Sea3")
			end

			local function fn34()
				return not fn5(game.Workspace.Enemies:FindFirstChild("rip_indra True Form")) and fn33()
			end

			handlers3.Elite(arg or "Rip Indra Hop")
			local collectChest = handlers3["Collect Chest"]
			local str2 = "Rip Indra Hop"
			collectChest(arg or str2, fn34, true)
			handlers3.Elite(arg or "Rip Indra Hop")

			if CheckItem("God's Chalice") then
				handlers3["Open Pad"](arg or str2, fn33)
				handlers3["Spawn Rip Indra"](arg or str2, fn33)
				task.wait(1)
			end

			local ripIndra = handlers3["Rip Indra"]
			arg = arg or "Rip Indra Hop"
			ripIndra(arg, fn33)

			if fn34() then
				MainServerHop(5, "Find New Server [Rip Indra Hop]")
			end
		end,
		["Tushita Hop"] = function()
			handlers3["Tushita Hop__1"]("OneClick")
		end,
		GetFruit = function(arg, arg2)
			local str = "GetFruit"
			print("Condition:", arg)

			local fn32 = arg2 or function()
				return true
			end

			local function fn33()
				if not arg then
					if getgenv().Setting[str].Enable then
						return true
					end
				elseif getgenv().Setting[arg].Enable and fn32() then
					return true
				end

				return false
			end

			local ok, result = pcall(function()
				local tbl13 = {}

				while task.wait(0.1) and fn33() and fn25() do
					local v4 = fn25()

					if v4 then
						StatusFarming = "Getting Fruit"
						Notify({ Text = "Getting Fruit", Type2 = nil, Delay = 5 })

						local function fn34()
							if not (fn33() and v4 and v4.Parent ~= nil) then
								return false
							end
							local flag2 = v4.Parent == game:GetService("Workspace") or v4.Parent.Parent and v4.Parent.Parent == game:GetService("Workspace")
							local character = localPlayer.Character and v4:IsDescendantOf(localPlayer.Character)
							local backpack = localPlayer:FindFirstChild("Backpack") and v4:IsDescendantOf(localPlayer.Backpack)

							if flag2 then
								flag2 = not (character or backpack)
							end

							return flag2
						end

						if not tbl13[v4] then
							tbl13[v4] = 0
						end

						local v5 = fn24(v4)

						if fn34() and v5 then
							if tbl13[v4] then
								tbl13[v4] = tbl13[v4] + 1
							end

							if not (Sea3 and (fn10(v5.Position) or fn10(localPlayer.Character))) then
								SSS(GetNearSpawn(v5.Position))
							end

							DoTween2(v5.CFrame, fn34, nil, { IgnoreSafeY = true })
							task.wait(2)
							StopTween()
							fn6(false)

							if tbl13[v4] >= 5 then
								v4:Destroy()
							end
						end
					end
				end
			end)

			pcall(function()
				if FruitFunc and FruitFunc.AutoStoreAll then
					FruitFunc.AutoStoreAll()
				end
			end)

			if getgenv().Setting and getgenv().Setting.OneClick and getgenv().Setting.OneClick.Enable then
				StatusFarming = "Checking Next Farm..."
			else
				StatusFarming = "Idle"
			end

			print("End Getting Fruit")

			if result then
				print(result)
			end
		end,
	}

	local tbl13 = {}
	local tbl14 = {}

	for _, child in pairs(workspace._WorldOrigin.PlayerSpawns.Pirates:GetChildren()) do
		tbl13[child.Name] = child:GetChildren()[1]
		tbl14[child.Name] = 0
	end

	handlers3["Collect Chest"] = function(...) end

	handlers3["Pirate Raid"] = function(arg, arg2)
		local str = "Pirate Raid"
		local pirateRaid = getNearMob("Pirate Raid")

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if fn33() then
			if fn5(pirateRaid) then
				StatusFarming = "Farming Pirate Raid [Intilizing]"

				local function fn34()
					if not getNearMob("Pirate Raid") then
						local now = tick()

						while not getNearMob("Pirate Raid") and tick() - now < 4 and fn33() do
							task.wait(0.1)
						end
					end
				end

				while fn33() and task.wait(0.1) and getNearMob("Pirate Raid") do
					StatusFarming = "Farming Pirate Raid[Found Mob]"
					SSS(GetNearSpawn(Vector3.new(-5418.519, 312.8032, -2828.0085)))

					while fn33() and task.wait(0.1) and fn5(pirateRaid) do
						StatusFarming = "Farming Pirate Raid[Attack Mob]"
						fn20(pirateRaid, nil)
					end

					fn34()
					pirateRaid = getNearMob("Pirate Raid")
				end
			end
		end

		fn6(false)
	end

	handlers3["Raid Fruit Hop"] = function(arg, arg2)
		local str = "Raid Fruit Hop"

		local fn32 = arg2 or function()
			return true
		end

		if (function()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end)() then
			handlers3["Pirate Raid"](arg or "Raid Fruit Hop", fn32)
			handlers3.GetFruit(arg or "Raid Fruit Hop", fn32)
			handlers3["Pirate Raid"](arg or "Raid Fruit Hop", fn32)
			task.wait(5)

			while #FruitFunc.HaveFruitInv() >= 1 do
				task.wait(1)
				handlers3.Raid(arg or "Raid Fruit Hop", fn32)
			end

			handlers3.GetFruit(arg or "Raid Fruit Hop", fn32)
			local pirateRaid = handlers3["Pirate Raid"]
			arg = arg or "Raid Fruit Hop"
			pirateRaid(arg, fn32)
			MainServerHop(5, "Find New Server [Raid Fruit Hop]")
		end
	end

	handlers3["Swan Door Hop"] = function(arg, arg2)
		local str = "Swan Door Hop"

		local fn32 = arg2 or function()
			return true
		end

		if (function()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end)() then
			handlers3.Factory(arg or "Swan Door Hop", fn32)
			handlers3.GetFruit(arg or "Swan Door Hop", fn32)
			local factory = handlers3.Factory
			arg = arg or "Swan Door Hop"
			factory(arg, fn32)
			MainServerHop(5, "Find New Server [Swan Fruit Hop]")
		end
	end

	handlers3["Hybrid Fruit Hop"] = function(arg, arg2)
		local str = "Hybrid Fruit Hop"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if fn33() then
			if Sea3 then
				handlers3["Pirate Raid"](arg or "Hybrid Fruit Hop", fn32)
			elseif Sea2 then
				handlers3.Factory(arg or "Hybrid Fruit Hop", fn32)
			end

			handlers3.GetFruit(arg or "Hybrid Fruit Hop", fn32)

			if Sea3 then
				local pirateRaid = handlers3["Pirate Raid"]
				arg = arg or "Hybrid Fruit Hop"
				pirateRaid(arg, fn32)
			elseif Sea2 then
				local factory = handlers3.Factory
				arg = arg or "Hybrid Fruit Hop"
				factory(arg, fn32)
			end

			task.wait(5)

			if fn33() then
				MainServerHop(5, "Find New Server [Hydrid Fruit Hop]")
			end
		end
	end

	handlers3["Water Key"] = function(arg, arg2)
		local str = "Water Key"

		local fn32 = arg2 or function()
			return not DataSave.Unlocked.Sharkman
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return not DataSave.Unlocked.Sharkman
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return not DataSave.Unlocked.Sharkman
			end

			return false
		end

		local v4 = GetMainEnemy("Tide Keeper")

		if fn5(v4) then
			SSS(GetNearSpawn(fn4(v4).Position))

			while fn5(v4) and task.wait(0.1) and fn33() do
				StatusFarming = "Farming Water Key"
				fn20(v4, nil, fn33)
			end
		end

		task.wait(1)

		while CheckItem("Water Key") and not DataSave.Unlocked.Sharkman and task.wait(0.1) do
			StatusFarming = "Using Water Key"
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuySharkmanKarate", true)
		end
	end

	handlers3["Library Key"] = function(arg, arg2)
		local str = "Library Key"

		local fn32 = arg2 or function()
			return not DataSave.Unlocked.Deathstep
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return not DataSave.Unlocked.Deathstep
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return not DataSave.Unlocked.Deathstep
			end

			return false
		end

		local v4 = GetMainEnemy("Awakened Ice Admiral")

		local ok, result = pcall(function()
			if fn5(v4) then
				SSS(GetNearSpawn(fn4(v4).Position))

				while fn5(v4) and task.wait(0.1) and fn33() do
					StatusFarming = "Farming Library Key"
					fn20(v4, nil, fn33)
				end
			end
		end)

		if result then
			print(result)
		end

		task.wait(1)

		while CheckItem("Library Key") and not DataSave.Unlocked.Deathstep and task.wait(0.1) do
			StatusFarming = "Using Library Key"
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("OpenLibrary")
		end
	end

	handlers3.Elite = function(arg, arg2)
		local str = "Elite"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if Sea3 and fn10() and fn33() then
			StatusFarming = "Exiting Submerged (Elite Priority)"

			if fn11(fn33) then
				task.wait(1)
			end
		end

		if fn33() then
			local Elite = getNearMob("Elite")

			if fn5(Elite) then
				StatusFarming = "Farming Elite [Start]"
				TPToEntrance("Castle")
				DoTween2(CFrame.new(-5418.51904, 312.803192, -2828.00854), fn33)
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EliteHunter")

				if fn33() and fn5(Elite) then
					SSS(GetNearSpawn(fn4(Elite).Position))

					while fn33() and task.wait(0.1) and fn5(Elite) do
						fn20(Elite, nil, fn33)
					end
				end

				StatusFarming = "Farming Elite [End]"
			end
		end

		fn6(false)
	end

	handlers3["Elite Hop"] = function(arg, arg2)
		local str = "Elite Hop"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if Sea3 and fn10() and fn33() then
			StatusFarming = "Exiting Submerged (Elite Hop)"

			if fn11(fn33) then
				task.wait(1)
			end
		end

		if fn33() then
			handlers3.Elite(arg or "Elite Hop")
		end

		task.wait(2)

		if CheckItem("God's Chalice") then
			if getgenv().Setting.SafeMode_GetGoodItem.Enable then
				fn22()
			end

			local setting = getgenv().Setting
			arg = arg or "Elite Hop"
			setting[arg].Enable = false
		else
			TrueServerHop()
		end

		fn6(false)
	end

	local tbl15 = {}
	local cframe3 = CFrame.new(-16332.526367188, 158.07200622559, 1440.3249511719)
	local cframe4 = CFrame.new(-16288.609375, 158.16700744629, 1470.3680419922)
	local cframe5 = CFrame.new(-16245.412109375, 158.43699645996, 1463.3659667969)
	local cframe6 = CFrame.new(-16212.46875, 158.16700744629, 1466.3439941406)
	local cframe7 = CFrame.new(-16211.946289062, 158.07200622559, 1322.3979492188)
	local cframe8 = CFrame.new(-16260.921875, 154.92100524902, 1323.6159667969)
	local cframe9 = CFrame.new(-16297.059570312, 159.32299804688, 1317.2239990234)
	local cframe10 = CFrame.new
	tbl15[1] = cframe3
	tbl15[2] = cframe4
	tbl15[3] = cframe5
	tbl15[4] = cframe6
	tbl15[5] = cframe7
	tbl15[6] = cframe8
	tbl15[7] = cframe9

	do
		local values = table.pack(cframe10(-16335.096679688, 159.33399963379, 1324.8859863281))
		table.move(values, 1, values.n, 8, tbl15)
	end

	handlers3["Tyrant Skies"] = function(arg, arg2)
		local str = "Tyrant Skies"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if not fn33() then
			return
		end

		if not Sea3 then
			return
		end
		local humanoidRootPart = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart then
			return
		end

		local function fn34()
			local tikiOutpost = game:GetService("Workspace").Map:FindFirstChild("TikiOutpost")
			local n2 = 0

			if tikiOutpost then
				local islandModel = tikiOutpost:FindFirstChild("IslandModel")

				if islandModel then
					local tbl16 = {}
					local eye1 = islandModel:FindFirstChild("Eye1")
					local eye2 = islandModel:FindFirstChild("Eye2")
					local eye3 = islandModel:FindFirstChild("IslandChunks") and islandModel.IslandChunks:FindFirstChild("E") and islandModel.IslandChunks.E:FindFirstChild("Eye3")
					local eye4 = islandModel:FindFirstChild("IslandChunks") and islandModel.IslandChunks:FindFirstChild("E") and islandModel.IslandChunks.E:FindFirstChild("Eye4")
					tbl16[1] = eye1
					tbl16[2] = eye2
					tbl16[3] = eye3
					tbl16[4] = eye4

					for _, v4 in ipairs(tbl16) do
						v4 = v4 and v4.Transparency ~= 1

						if v4 then
							n2 += 1
						end
					end
				end
			end

			return n2
		end

		local tbl16 = { "Serpent Hunter", "Skull Slayer", "Isle Champion", "Sun-kissed Warrior" }

		local function fn35()
			local tbl17 = {}

			for _, v4 in ipairs(tbl16) do
				for _, child in ipairs(enemies:GetChildren()) do
					if child.Name == v4 and fn5(child) then
						table.insert(tbl17, child)
					end
				end
			end

			return tbl17
		end

		if fn34() < 4 then
			local v4 = fn35()

			if #v4 == 0 then
				StatusFarming = "Waiting Mobs - Eyes: " .. fn34() .. "/4"

				if (humanoidRootPart.Position - Vector3.new(-16268.287, 152.616, 1390.773)).Magnitude > 100 then
					StatusFarming = "Going To Tyrant of the Skies Area"
					DoTween2(CFrame.new(Vector3.new(-16268.287, 152.616, 1390.773)), fn33)
				end

				return
			end

			for _, v5 in ipairs(v4) do
				if fn33() then
					if not fn5(v5) then
						continue
					else
						StatusFarming = "Killing " .. v5.Name .. " [Eyes: " .. fn34() .. "/4]"
						SSS(GetNearSpawn(fn4(v5).Position), fn33)

						while fn33() and task.wait(0.1) and fn5(v5) do
							fn20(v5, nil, fn33)
						end

						if not (fn34() >= 4) then
							continue
						end
					end
				end

				break
			end

			if fn34() < 4 then
				return
			end
		end

		if not fn33() then
			fn6(false)
			return
		end
		StatusFarming = "Eyes Ready! Summoning Tyrant of the Skies..."
		local flag2 = false
		local flag3

		while fn33() and not flag2 do
			for _, v4 in ipairs(tbl15) do
				if fn33() then
					if fn5(enemies:FindFirstChild("Tyrant of the Skies")) then
						flag2 = true
						break
					else
						local v5 = fn4(localPlayer.Character)

						if v5 then
							v5.CFrame = v4
						end

						local now = tick()

						while true do
							local flag4 = tick() - now < 12 and fn33() and true
							flag3 = false

							if flag4 then
								local v6 = fn4(localPlayer.Character)

								if v6 then
									if (v6.Position - v4.Position).Magnitude <= 3 then
										flag3 = true
										break
									else
										v6.CFrame = v4
										task.wait(0.1)
										continue
									end
								end
							end

							break
						end

						flag3 = fn33() and flag3

						if flag3 then
							for _, v6 in ipairs({ "Melee", "Sword", "Gun" }) do
								if fn33() then
									if fn5(enemies:FindFirstChild("Tyrant of the Skies")) then
										flag2 = true
										break
									else
										local v7 = GetCurrentTool(v6)

										if v7 then
											Equip(v7.Name)
											task.wait(0.1)
											local tbl17 = v6 == "Melee" and { "Z", "X", "C" } or { "Z", "X" }

											for _, v8 in ipairs(tbl17) do
												if fn33() then
													if fn5(enemies:FindFirstChild("Tyrant of the Skies")) then
														flag2 = true
														break
													else
														Press(v8)
														task.wait(0.3)
														continue
													end
												end

												break
											end
										end

										if not flag2 then
											continue
										end
									end
								end

								break
							end
						end

						task.wait(0.1)
						continue
					end
				end

				break
			end

			if fn5(enemies:FindFirstChild("Tyrant of the Skies")) then
				flag2 = true
			end
		end

		VoidSkillController()

		if flag2 then
			local tyrantOfTheSkies = enemies:FindFirstChild("Tyrant of the Skies")

			if fn5(tyrantOfTheSkies) then
				StatusFarming = "Farming Tyrant of the Skies"
				SSS(GetNearSpawn(fn4(tyrantOfTheSkies).Position), fn33)

				while fn33() and task.wait(0.1) and fn5(tyrantOfTheSkies) do
					fn20(tyrantOfTheSkies, nil, fn33)
				end

				StatusFarming = "Tyrant of the Skies Killed"
			end
		end

		fn6(false)
	end

	handlers3.EatFruit = function()
		local v4 = fn28()

		if v4 then
			fn26(v4)
		end
	end

	handlers3.SnipeFruitOneClick = function()
		local v4, v5 = fn27()

		if v5 == "Mirage" then
			if not flag then
				return
			end
			StatusFarming = "Buying Fruit In Mirage"

			if MirageFunctions.GetMirageIsland() then
				MirageFunctions.TweenFruitDealer()

				if v4 then
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("PurchaseRawFruit", v4, true)
				end
			end
		end

		if v5 == "Normal" then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("PurchaseRawFruit", v4)
		end
	end

	handlers3["Cake Prince"] = function(arg, arg2)
		local str = "Cake Prince"

		local fn32 = arg2 or function()
			return true
		end

		local cakePrince = game.Workspace.Enemies:FindFirstChild("Cake Prince")

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if Sea3 and fn10() and fn33() then
			StatusFarming = "Exiting Submerged (Cake Prince Priority)"

			if fn11(fn33) then
				task.wait(1)
			end
		end

		if fn5(cakePrince) then
			fn4(localPlayer.Character).Size = Vector3.new(2, 1, 2)
			local v4 = CreateSteppedLoop(fn7, "NoClipKatakuri")
			StatusFarming = "Start Killing Katakuri"
			local n2 = 0

			while fn5(cakePrince) and task.wait(0.1) and fn33() do
				TPKatakuriGate(cakePrince)
				StatusFarming = "Farming Katakuri"
				n2 += 18
				fn20(cakePrince, nil, nil, nil, nil, nil, { ForceNotMastery = true, Spin = n2 })
			end

			StatusFarming = "Killed Katakuri"
			DisconnectLoop(v4)
			fn4(localPlayer.Character).Size = Vector3.new(2, 2, 1)
		end

		fn6(false)
	end

	handlers3["Dough King"] = function(arg, arg2)
		local doughKing = game.Workspace.Enemies:FindFirstChild("Dough King")
		local str = "Dough King"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if Sea3 and fn10() and fn33() then
			StatusFarming = "Exiting Submerged (Dough King Priority)"

			if fn11(fn33) then
				task.wait(1)
			end
		end

		if fn5(doughKing) then
			fn4(localPlayer.Character).Size = Vector3.new(2, 1, 2)
			local n2 = 0

			while fn5(doughKing) and task.wait(0.1) and fn33() do
				TPKatakuriGate(doughKing)
				StatusFarming = "Farming Katakuri"
				n2 += 18
				fn20(doughKing, nil, nil, nil, nil, nil, { ForceNotMastery = true, Spin = n2 })
			end

			fn4(localPlayer.Character).Size = Vector3.new(2, 2, 1)
		end

		fn6(false)
	end

	handlers3["Trade Sweet Chalice Force"] = function()
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("SweetChaliceNpc")
	end

	handlers3["Dough King Force"] = function(arg)
		StatusFarming = "Seting Things Up For Dough King"

		local function fn32()
			local ok, result = pcall(function()
				return game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CakePrinceSpawner", true)
			end)

			return ok and result or "0"
		end

		local cakePrince = game.Workspace.Enemies:FindFirstChild("Cake Prince") or game.Workspace.Enemies:FindFirstChild("Dough King")

		if fn5(cakePrince) then
			handlers3[cakePrince.Name](arg or "Dough King Force")
		end

		task.wait(1)
		local v4 = string.gsub(fn32(), "%D", "")

		local thread = task.spawn(function()
			while task.wait(0.5) do
				v4 = string.gsub(fn32(), "%D", "")
			end
		end)

		local function fn33()
			return tonumber(v4) and CheckItem("Sweet Chalice")
		end

		handlers3.Katakuri(arg or "Dough King Force", fn33)

		if not tonumber(v4) or tonumber(v4) < 1 then
			game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("CakePrinceSpawner")
		end

		local cakePrince2 = game.Workspace.Enemies:FindFirstChild("Cake Prince") or game.Workspace.Enemies:FindFirstChild("Dough King")

		if fn5(cakePrince2) then
			handlers3[cakePrince2.Name](arg or "Dough King Force")
		end

		task.cancel(thread)
	end

	handlers3.Katakuri = function(arg, arg2, arg3, arg4, arg5)
		local str = "Katakuri"
		local Katakuri = getNearMob("Katakuri")
		local tbl16 = arg5 or {}

		local function fn32()
			local ok, result = pcall(function()
				return game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CakePrinceSpawner", true)
			end)

			return ok and result or "0"
		end

		local fn33 = arg2 or function()
			return true
		end

		local function fn34()
			if not arg then
				if getgenv().Setting[str].Enable then
					return fn33()
				end
			elseif getgenv().Setting[arg].Enable and fn33() then
				return true
			end

			return false
		end

		if Sea3 and fn10() and fn34() then
			StatusFarming = "Exiting Submerged (Katakuri Priority)"

			if fn11(fn34) then
				task.wait(1)
			end
		end

		local mastery = tbl16.Mastery or getgenv().Setting.Mastery.Enable

		if arg3 then
			MakeMasterySkill()

			SkillsController.Condition = function()
				if (tbl16.Mastery or getgenv().Setting.Mastery.Enable) and fn5(Katakuri) then
					local humanoid = Katakuri:FindFirstChild("Humanoid")

					if humanoid then
						humanoid = humanoid.Health <= humanoid.MaxHealth * (getgenv().Setting.Mastery.Health and getgenv().Setting.Mastery.Health / 100 or 0.5)
					end

					return humanoid and (tbl16.Mastery or getgenv().Setting.Mastery.Enable)
				end

				return false, Katakuri
			end
		end

		local now = tick()

		while fn34() and task.wait(0.1) do
			if not Alive() then
				fn6(false)

				while not Alive() do
					task.wait(1)
				end

				task.wait(1.5)

				if getgenv().Setting.AutoBuso and getgenv().Setting.AutoBuso.Enable then
					pcall(function()
						if localPlayer.Character and not localPlayer.Character:FindFirstChild("HasBuso") then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
						end
					end)
				end
			else
				if mastery then
					getgenv().MasteringWeapon = true
				end

				if GetSettingHopExploiter() then
					HopNearExploiter()
				end

				local cakePrince = game.Workspace.Enemies:FindFirstChild("Cake Prince") or game.Workspace.Enemies:FindFirstChild("Dough King")
				local n2 = tonumber(string.match(fn32(), "%d+")) or 0

				if fn5(cakePrince) then
					handlers3[cakePrince.Name](arg or "Katakuri")
				elseif n2 <= 0 then
					StatusFarming = "Reached exact 500 kills! Summoning Boss..."
					fn6(false)

					if Alive() and CheckItem("Sweet Chalice") then
						Equip("Sweet Chalice")
						task.wait(0.2)
					end

					game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("CakePrinceSpawner")
					task.wait(1.5)
				else
					if tick() - now >= 5 then
						if not TweeningV2 then
							fn6(false)
						end

						now = tick()
					end

					if getgenv().Setting.AcceptQuest_Bone_Katakuri.Enable and localPlayer.Data.Level.Value >= 2275 and (not localPlayer.PlayerGui.Main.Quest.Visible or not string.find(localPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, "Head Baker")) then
						local cframe11 = CFrame.new(-1927.91602, 37.7981339, -12842.5391)

						if Alive() then
							StatusFarming = "[Katakuri] Getting Quest"
							SSS(GetNearSpawn(cframe11.Position), fn34)

							while getgenv().Setting.AcceptQuest_Bone_Katakuri.Enable and not SafeGetQuest(cframe11, "CakeQuest2", 2, true) and fn34() and task.wait(0.5) do
								DoTween2(cframe11, fn34)
							end

							fn6(false)
						end
					end

					if fn5(Katakuri) then
						SSS(GetNearSpawn(Vector3.new(-2138.7468, 69.98305, -12322.691)), fn34)

						local ok, result = pcall(function()
							while true do
								if Alive() and fn5(Katakuri) and task.wait(0.1) and fn34() then
									local n3 = tonumber(string.match(fn32(), "%d+")) or 0

									if not (n3 <= 0) then
										local flag2

										if n3 <= 10 then
											StatusFarming = "Precise Farming! (" .. n3 .. " left) - BringMob LOCKED"
											flag2 = true
										else
											StatusFarming = "Farming Dimension Mob (" .. n3 .. " left)"
											flag2 = false
										end

										fn20(Katakuri, arg3, nil, nil, flag2, arg4, tbl16)

										if not arg3 then
											if not fn19(Katakuri, fn34) then
												continue
											end
										else
											continue
										end
									end
								end

								break
							end

							StatusFarming = "Done Attack Dimension Mob"
						end)

						if result then
							print("Error Farming Dimension ", result)
						end
					else
						fn6(false)
					end

					if arg3 then
						getgenv().PosToHook = nil
						getgenv().SilentAimPos = false
					end

					Katakuri = getNearMob("Katakuri")

					if not fn5(Katakuri) then
						StatusFarming = "[Katakuri] TP To Middle"
						SSS(GetNearSpawn(Vector3.new(-2138.7468, 69.98305, -12322.691)), fn34)
						DoTween2(CFrame.new(-2138.746826171875, 69.983047485351562, -12322.69140625), fn34)
					end
				end
			end
		end

		if arg3 then
			getgenv().MasteringWeapon = false
			VoidSkillController()
		end

		if localPlayer.CameraMaxZoomDistance <= 1 then
			localPlayer.CameraMaxZoomDistance = 200
			localPlayer.CameraMinZoomDistance = 100
			localPlayer.CameraMinZoomDistance = 0
		end

		fn6(false)
	end

	handlers3["Kill Aura"] = function(arg, arg2, arg3)
		local str = "Kill Aura"

		local fn32 = arg3 or function()
			return true
		end

		local function fn33()
			if not arg2 then
				if getgenv().Setting[str].Enable and CasualFarmEmpty() then
					return fn32()
				end
			elseif getgenv().Setting[arg2].Enable and fn32() then
				return true
			end

			return false
		end

		if Sea3 and fn10() and fn33() then
			StatusFarming = "Exiting Submerged (Kill Aura)"

			if fn11(fn33) then
				task.wait(1)
			end
		end

		local v4 = fn18(enemies:GetChildren())

		while not Alive() and task.wait(0.1) do
		end

		if not getgenv().Setting["Kill Aura"].AnchorPosition then
			getgenv().Setting["Kill Aura"].AnchorPosition = tostring(game.Players.LocalPlayer.Character.HumanoidRootPart.Position)
		end

		while fn33() and task.wait(0.1) do
			local v5 = ConvertStringToVector3(getgenv().Setting["Kill Aura"].AnchorPosition)
			local distanceFromAnchor = getgenv().Setting["Kill Aura"].DistanceFromAnchor

			local function fn34()
				if not getgenv().Setting["Kill Aura"].AnchorTPBack or getgenv().Setting["Kill Aura"].AnchorTPBack and fn5(v4) and fn9(v4, v5) <= distanceFromAnchor then
					return true
				end
				return false
			end

			while not Alive() and task.wait(0.1) do
			end

			if getgenv().Setting["Kill Aura"].AnchorTPBack and fn9(localPlayer.Character, v5) > distanceFromAnchor then
				DoTween2(CFrame.new(v5))
			end

			while true do
				if fn5(v4) and fn34() and task.wait(0.1) and fn33() then
					StatusFarming = "Kill Aura Mob"
					fn20(v4, nil, fn34)
					if not fn19(v4, fn33, fn34) then
						continue
					end
				end

				break
			end

			v4 = fn18(enemies:GetChildren())

			if not fn34() then
				for _, child in pairs(game:GetService("Workspace")._WorldOrigin.EnemySpawns:GetChildren()) do
					if not fn34() then
						if fn9(child, v5) <= distanceFromAnchor then
							DoTween2(child.CFrame)
							task.wait()
							v4 = fn18(enemies:GetChildren())
						end

						continue
					end

					break
				end
			end
		end

		fn6(false)
	end

	handlers3.Material = function(farmingMaterial, arg, arg2)
		local str = "Material"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable and CasualFarmEmpty() then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if Sea3 and fn10() and fn33() then
			StatusFarming = "Exiting Submerged (Material Farm)"

			if fn11(fn33) then
				task.wait(1)
			end
		end

		farmingMaterial = farmingMaterial or getgenv().Setting.Material.Select
		if not farmingMaterial then
			return
		end

		while fn33() and task.wait(0.3) do
			if not Alive() then
				fn6(false)

				while not Alive() do
					task.wait(1)
				end

				task.wait(1.5)

				if getgenv().Setting.AutoBuso and getgenv().Setting.AutoBuso.Enable then
					pcall(function()
						if localPlayer.Character and not localPlayer.Character:FindFirstChild("HasBuso") then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
						end
					end)
				end

				continue
			end

			StatusFarming = "Farming Material: " .. farmingMaterial

			if table.find(tbl2.MaterialFarm.CheckBoss, farmingMaterial) then
				if Alive() then
					MyMaterialMob = tbl2.MaterialFarm.CheckBoss[farmingMaterial].IsBoss()

					if currentPlaceKey ~= tbl2.MaterialSeaChecker[farmingMaterial] then
						MainTravel(5, "Farm Material Sea 2", "Sea2")
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelDressrosa")
					end

					while fn33() and task.wait(0.1) and fn5(MyMaterialMob) and Alive() do
						fn20(MyMaterialMob, nil)
					end
				end

				continue
			end

			if currentPlaceKey ~= tbl2.MaterialSeaChecker[farmingMaterial] then
				return Travel(tbl2.MaterialSeaChecker[farmingMaterial])
			end

			if Alive() then
				MyMaterialMob = getNearMob("Material", farmingMaterial)

				if fn5(MyMaterialMob) then
					while fn33() and task.wait(0.1) and fn5(MyMaterialMob) and Alive() do
						fn20(MyMaterialMob, nil)
					end
				else
					local pos = tbl2.MaterialFarm.CheckMob[farmingMaterial].Pos
					DoTween2(typeof(pos) == "table" and pos[math.random(1, #pos)] or pos)
				end
			end
		end

		fn6(false)
	end

	handlers3["Mirror Fractal Hop"] = function(arg, arg2)
		local str = "Mirror Fractal Hop"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		local function fn34()
			return not CheckItem("God's Chalice") and not CheckItem("Sweet Chalice") and fn33() and not fn5(game.Workspace.Enemies:FindFirstChild("Dough King"))
		end

		if not CheckItem("God's Chalice") and not CheckItem("Sweet Chalice") then
			handlers3.Elite(arg or "Mirror Fractal Hop")
			handlers3["Collect Chest"](arg or "Mirror Fractal Hop", fn34)
			local elite = handlers3.Elite
			arg = arg or "Mirror Fractal Hop"
			elite(arg)
		end

		task.wait(1)

		if not CheckItem("God's Chalice") and not CheckItem("Sweet Chalice") and fn34() and not fn5(game.Workspace.Enemies:FindFirstChild("Dough King")) then
			MainServerHop(5, "Find New Server [Mirror Fractal Hop]", 1, 5)
		end
	end

	handlers3["Valkyrie Helm Hop"] = function(arg)
		handlers3["Rip Indra Hop"](arg or "Valkyrie Helm Hop")
	end

	handlers3["Mirage Snipe Fruit"] = function()
		if not flag then
			return
		end
		StatusFarming = "Buying Fruit In Mirage"

		if MirageFunctions.GetMirageIsland() then
			MirageFunctions.TweenFruitDealer()
			__SnipeFruit = GetMirageSnipeFruit()

			if __SnipeFruit then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("PurchaseRawFruit", __SnipeFruit, true)
			end
		end
	end

	handlers3.CDK = function(arg, arg2)
		local str = "CDK"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		print("Called")

		if Sea3 and not CheckInvItem("Cursed Dual Katana") then
			local v4 = fn16()
			print(v4)

			if v4.Good == 4 and (v4.Evil == 3 or v4.Evil == 4) then
				while not CheckInvItem("Cursed Dual Katana") and task.wait() do
					StatusFarming = "Doing CDK Quest"
					local cursedSkeletonBoss = game:GetService("Workspace").Enemies:FindFirstChild("Cursed Skeleton Boss")

					if not fn5(cursedSkeletonBoss) then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CDKQuest", "StartTrial", "Boss")
						task.wait(1)
						DoTween2(CFrame.new(-12341.874, 603.320435, -6550.25439, -0.0560340174, 0.391986638, 0.918262839, 0.0466610044, 0.919731021, -0.389766037, -0.997337937, 0.021006912, -0.0698267147))

						for _, child in pairs(game:GetService("Workspace").Map.Turtle.Cursed:GetChildren()) do
							if child:FindFirstChild("ProximityPrompt") then
								DoTween2(CFrame.new(-12396.498046875, 603.3455810546875, -6502.42529296875))
								task.wait()
								Click()
								fireproximityprompt(child:FindFirstChild("ProximityPrompt"))
								task.wait(0.5)
							end
						end
					end

					local cursedSkeletonBoss2 = game:GetService("Workspace").Enemies:FindFirstChild("Cursed Skeleton Boss")
					local flag2 = false

					local thread = task.spawn(function()
						while task.wait(1) do
							flag2 = CheckInvItem("Cursed Dual Katana")
						end
					end)

					while fn5(cursedSkeletonBoss2) and task.wait(0.1) and not CheckInvItem("Cursed Dual Katana") and not flag2 do
						pcall(function()
							local yama = localPlayer.Character:FindFirstChild("Yama") or localPlayer.Character:FindFirstChild("Tushita") or localPlayer.Backpack:FindFirstChild("Tushita") or localPlayer.Backpack:FindFirstChild("Yama")

							if yama then
								Equip(yama.Name)
							else
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", "Tushita")
							end

							fn20(cursedSkeletonBoss2, nil, nil, nil, nil, nil, { IgnoreEquip = true })
						end)
					end

					if thread then
						task.cancel(thread)
					end
				end
			elseif v4.Good <= 3 and v4.Good ~= -2 and v4.Good ~= 4 then
				tbl6.Good()

				if v4.Good == -3 then
					while fn16().Good == -3 and task.wait(0.1) do
						StatusFarming = "Doing Good Scroll Quest 1"

						VipBoatSeller = {
							Vector3.new(-369.507, 6.7299514, 5190.749),
							Vector3.new(-9530.968, 7.219417, -8375.256),
							Vector3.new(-6126.1343, 16.507906, -2251.773),
							Vector3.new(3234.8335, 9.432059, 1602.1821),
							Vector3.new(-9549.828, 21.104864, 4685.521),
							Vector3.new(-963.31287, 7.767618, -10813.18),
							Vector3.new(-1933.9084, 8.048837, -11475.199),
							Vector3.new(-1933.9084, 8.048837, -11475.199),
							Vector3.new(2222.733, 5.336241, -6261.203),
						}

						for _, v5 in pairs(VipBoatSeller) do
							if fn16().Good == -3 then
								while Alive() and (fn4(localPlayer.Character).Position - v5).magnitude > 10 and task.wait(0.2) do
									DoTween2(CFrame.new(v5))
								end

								local npCs = workspace.NPCs
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CDKQuest", "BoatQuest", npCs:FindFirstChild("Luxury Boat Dealer"))
								continue
							end

							break
						end
					end
				elseif v4.Good == -4 then
					local pirateRaid = handlers3["Pirate Raid"]
					arg = arg or "CDK"
					pirateRaid(arg)
				elseif v4.Good == -5 then
					StatusFarming = "Doing Good Scroll Quest 3"
					StopTween()

					if not tbl5.Heaven() then
						local v5 = GetMainEnemy("Cake Queen")

						if fn5(v5) then
							StatusFarming = "Doing Good Scroll Quest 3"
							SSS(GetNearSpawn(fn4(v5).Position))
							pcall(Equip, GetCurrentTool("Melee", true))

							while fn5(v5) and task.wait(0.1) do
								fn20(v5)
							end

							local now = tick()

							while true do
								wait()
								if not (tbl5.Heaven() or tick() - now > 5) then
									continue
								end
								break
							end

							while tbl5.Heaven() and task.wait() do
								pcall(function()
									if tbl5.Heaven() then
										StopTween()

										if (fn4(localPlayer.Character).Position - game:GetService("Workspace").Map.HeavenlyDimension:FindFirstChild("Exit").Position).magnitude > 2000 then
											wait(5)
										end

										local exit = game:GetService("Workspace").Map.HeavenlyDimension:FindFirstChild("Exit")

										if exit then
											exit = #game:GetService("Workspace").Map.HeavenlyDimension:FindFirstChild("Exit"):GetChildren() >= 2
										end

										if exit then
											DoTween2(game:GetService("Workspace").Map.HeavenlyDimension:FindFirstChild("Exit").CFrame)
										else
											local v6 = tbl6.GetMob()

											if fn5(v6) then
												while fn5(v6) and Alive() and task.wait(0.1) do
													fn20(v6)
												end
											elseif tbl5.Heaven() then
												for _, child in pairs(game:GetService("Workspace").Map.HeavenlyDimension:GetChildren()) do
													if string.find(child.Name, "Torch") and child:FindFirstChild("Particles") and child:FindFirstChild("Particles"):FindFirstChild("Main") and not child:FindFirstChild("Particles"):FindFirstChild("Main").Enabled then
														if not tbl6.GetMob() then
															DoTween2(child.CFrame)
															Click()
															task.wait(0.5)
															fireproximityprompt(child:FindFirstChild("ProximityPrompt"), 2, true)
															task.wait(2)
															fireproximityprompt(child:FindFirstChild("ProximityPrompt"), 2, true)
															task.wait(2)
															pcall(Equip, GetCurrentTool("Melee", true))
															continue
														end
													else
														continue
													end

													break
												end
											end

											if game:GetService("Workspace").Map:FindFirstChild("HeavenlyDimension") then
												pcall(DoTween2, game:GetService("Workspace").Map.HeavenlyDimension:FindFirstChild("Exit").CFrame)
											end
										end
									end
								end)
							end
						else
							MainServerHop(5, "Find Cake Boss [Auto CDK]")
						end
					end

					if tbl5.Heaven() and (fn4(localPlayer.Character).Position - game:GetService("Workspace").Map.HeavenlyDimension:FindFirstChild("Exit").Position).magnitude > 2000 then
						wait(5)
					end

					while tbl5.Heaven() and task.wait() do
						pcall(function()
							if game:GetService("Workspace").Map:FindFirstChild("HeavenlyDimension") then
								StopTween()

								if (fn4(localPlayer.Character).Position - game:GetService("Workspace").Map.HeavenlyDimension:FindFirstChild("Exit").Position).magnitude > 2000 then
									wait(5)
								end

								if game:GetService("Workspace").Map.HeavenlyDimension:FindFirstChild("Exit") and #game:GetService("Workspace").Map.HeavenlyDimension.Exit:GetChildren() >= 2 then
									DoTween2(game:GetService("Workspace").Map.HeavenlyDimension:FindFirstChild("Exit").CFrame)
								else
									local v5 = tbl6.GetMob()

									if fn5(v5) then
										while fn5() and Alive() and task.wait(0.1) do
											fn20(v5)
										end
									elseif game:GetService("Workspace").Map:FindFirstChild("HeavenlyDimension") then
										for _, child in pairs(game:GetService("Workspace").Map.HeavenlyDimension:GetChildren()) do
											if string.find(child.Name, "Torch") and child:FindFirstChild("Particles") and child:FindFirstChild("Particles"):FindFirstChild("Main") and not child:FindFirstChild("Particles"):FindFirstChild("Main").Enabled then
												if not tbl6.GetMob() then
													DoTween2(child.CFrame)
													Click()
													task.wait(0.5)
													fireproximityprompt(child:FindFirstChild("ProximityPrompt"), 2, true)
													task.wait(2)
													fireproximityprompt(child:FindFirstChild("ProximityPrompt"), 2, true)
													task.wait(2)
													pcall(Equip, GetCurrentTool("Melee", true))
													continue
												end
											else
												continue
											end

											break
										end
									end

									pcall(DoTween2, game:GetService("Workspace").Map.HeavenlyDimension:FindFirstChild("Exit").CFrame)
								end
							end
						end)
					end
				end
			else
				tbl6.Evil()

				while fn16().Evil == -3 or fn16().Evil == -4 do
					if fn16().Evil == -3 then
						StatusFarming = "Doing Evill Scroll Quest 1"
						SSS(GetNearSpawn(Vector3.new(-2138.7468, 69.98305, -12322.691)))
						DoTween2(CFrame.new(-2138.746826171875, 69.983047485351562, -12322.69140625))

						while fn16().Evil == -3 and task.wait(1) do
							local v5 = fn18(enemies:GetChildren())

							if fn5(v5) then
								if Alive() then
									localPlayer.Character.Humanoid:UnequipTools()
									fn12(v5, Vector3.new(0, 0, -3))
								end
							else
								SSS(GetNearSpawn(Vector3.new(-2138.7468, 69.98305, -12322.691)))
								DoTween2(CFrame.new(-2138.746826171875, 69.983047485351562, -12322.69140625))
							end
						end
					end

					while fn16().Evil == -4 and task.wait(1) do
						repeat
							wait()
						until localPlayer.QuestHaze

						if Alive() then
							for _, child in pairs(localPlayer.QuestHaze:GetChildren()) do
								if child.Value ~= 0 then
									print("Selected " .. child.Name, child.Value)

									while not (child.Value == 0 or child.Value == "0") and fn16().Evil == -4 and task.wait(0.2) do
										local v5 = getNearMob(child.Name)
										print("Can CDK " .. child.Name, child.Value == 0 or child.Value == "0")

										if fn5(v5) then
											print("dang Kill Haze Mob " .. v5.Name)
											SSS(GetNearSpawn(fn4(v5).Position))

											while fn5(v5) and task.wait(0.1) do
												fn20(v5, nil, nil, nil, true)
											end
										else
											print("Finding Enemy Spawns: ", child.Name)

											if not fn5(getNearMob(child.Name)) and child.Value ~= 0 and child.Value ~= "0" then
												local v6 = GetMobSpawnCFrame(child.Name)

												if v6 then
													SSS(GetNearSpawn(v6.Position))
													print("Dang Tween Toi Point")
													fn6(true)

													DoTween2(v6 + Vector3.new(0, 25, 0), function()
														return not fn5(getNearMob(child.Name))
													end)
												end
											end
										end
									end
								end
							end
						end
					end
				end

				if fn16().Evil == -5 then
					local function fn34()
						return fn33() and (fn5(game:GetService("Workspace").Enemies:FindFirstChild("Soul Reaper")) or CheckItem("Hallow Essence") or tbl5.Hell()) and (arg and WorkingFarmEmpty() or not arg)
					end

					if not fn34() then
						local bone = handlers3.Bone
						arg = arg or "CDK"
						bone(arg, fn34)
					end

					while (fn5(game:GetService("Workspace").Enemies:FindFirstChild("Soul Reaper")) or CheckItem("Hallow Essence") or tbl5.Hell()) and fn16().Evil == -5 and task.wait() do
						StatusFarming = "Doing Evil Scroll Quest 3"

						pcall(function()
							if Alive() then
								if tbl5.Hell() then
									StopTween()

									if not game:GetService("Workspace").Map.HellDimension:FindFirstChild("Exit") then
										wait(3)
									end

									if (fn4(localPlayer.Character).Position - game:GetService("Workspace").Map.HellDimension:FindFirstChild("Exit").Position).magnitude > 2000 then
										wait(5)
									end

									pcall(Equip, GetCurrentTool("Melee", true))
									local exit = game:GetService("Workspace").Map.HellDimension and game:GetService("Workspace").Map.HellDimension:FindFirstChild("Exit")

									if exit then
										exit = #game:GetService("Workspace").Map.HellDimension:FindFirstChild("Exit"):GetChildren() >= 2
									end

									if exit and fn16().Evil == -5 then
										DoTween2(game:GetService("Workspace").Map.HellDimension:FindFirstChild("Exit").CFrame)
										wait(3)
									else
										local v5 = tbl6.GetMob()

										if fn5(v5) then
											while fn5(v5) and Alive() and task.wait(0.1) do
												fn20(v5)
											end
										elseif game:GetService("Workspace").Map:FindFirstChild("HellDimension") then
											for _, child in pairs(game:GetService("Workspace").Map.HellDimension:GetChildren()) do
												if string.find(child.Name, "Torch") and child:FindFirstChild("Particles") and child:FindFirstChild("Particles"):FindFirstChild("Main") and not child:FindFirstChild("Particles"):FindFirstChild("Main").Enabled then
													if not tbl6.GetMob() then
														DoTween2(child.CFrame)
														Click()
														task.wait(0.5)
														fireproximityprompt(child:FindFirstChild("ProximityPrompt"), 2, true)
														task.wait(2)
														fireproximityprompt(child:FindFirstChild("ProximityPrompt"), 2, true)
														task.wait(2)
														pcall(Equip, GetCurrentTool("Melee", true))
														continue
													end
												else
													continue
												end

												break
											end

											if game:GetService("Workspace").Map:FindFirstChild("HellDimension") then
												pcall(DoTween2, game:GetService("Workspace").Map.HellDimension.Exit.CFrame)
											end
										end
									end
								else
									local soulReaper = game:GetService("Workspace").Enemies:FindFirstChild("Soul Reaper")

									if fn5(soulReaper) and not game:GetService("Workspace").Map:FindFirstChild("HellDimension") then
										while true do
											wait()

											if Alive() and not game:GetService("Workspace").Map:FindFirstChild("HellDimension") then
												fn6(true)
												localPlayer.Character.Humanoid:UnequipTools()
												fn12(soulReaper, Vector3.new(0, 0, -3))
											end

											if not (not fn5(soulReaper) or not Alive() or fn16().Evil ~= -5 or game:GetService("Workspace").Map:FindFirstChild("HellDimension")) then
												continue
											end
											break
										end

										local lancuoi = tick()
										while true do
											wait()
											local flag2 = tbl5.Hell()

											if not flag2 then
												local v5 = lancuoi
												flag2 = tick() - v5 > 5
											end

											if not flag2 then
												continue
											end
											break
										end

										while tbl5.Hell() and task.wait() and fn16().Evil == -5 do
											if game:GetService("Workspace").Map:FindFirstChild("HellDimension") then
												StopTween()

												if (fn4(localPlayer.Character).Position - game:GetService("Workspace").Map.HellDimension:FindFirstChild("Exit").Position).magnitude > 2000 then
													wait(5)
												end

												local exit = game:GetService("Workspace").Map.HellDimension:FindFirstChild("Exit")

												if exit then
													exit = #game:GetService("Workspace").Map.HellDimension:FindFirstChild("Exit"):GetChildren() >= 2
												end

												if exit and fn16().Evil == -5 then
													DoTween2(game:GetService("Workspace").Map.HellDimension:FindFirstChild("Exit").CFrame)
												else
													local v5 = tbl6.GetMob()

													if fn5(v5) then
														while fn5(v5) and Alive() and task.wait(0.1) do
															fn20(v5)
														end
													elseif game:GetService("Workspace").Map:FindFirstChild("HellDimension") then
														for _, child in pairs(game:GetService("Workspace").Map.HellDimension:GetChildren()) do
															if string.find(child.Name, "Torch") and child:FindFirstChild("Particles") and child:FindFirstChild("Particles"):FindFirstChild("Main") and not child:FindFirstChild("Particles"):FindFirstChild("Main").Enabled then
																if not tbl6.GetMob() then
																	DoTween2(child.CFrame)
																	Click()
																	task.wait(0.5)
																	fireproximityprompt(child:FindFirstChild("ProximityPrompt"), 2, true)
																	task.wait(2)
																	fireproximityprompt(child:FindFirstChild("ProximityPrompt"), 2, true)
																	task.wait(2)
																	pcall(Equip, GetCurrentTool("Melee", true))
																	continue
																end
															else
																continue
															end

															break
														end

														if game:GetService("Workspace").Map:FindFirstChild("HellDimension") then
															pcall(DoTween2, game:GetService("Workspace").Map.HellDimension.Exit.CFrame)
														end
													end
												end
											end
										end
									elseif CheckItem("Hallow Essence") then
										local boatCastle = game:GetService("Workspace").Map:FindFirstChild("Boat Castle") or game:GetService("Workspace").Map:FindFirstChild("Haunted Castle") or workspace:FindFirstChild("Boat Castle", true)

										if boatCastle then
											boatCastle = boatCastle:FindFirstChild("Summoner") or boatCastle:FindFirstChild("Summoner", true)
										end

										if boatCastle then
											boatCastle = boatCastle:FindFirstChild("Detection") or boatCastle:FindFirstChild("Part")
										end

										local cFrame = boatCastle and boatCastle.CFrame or CFrame.new(-8932.322265625, 146.83154296875, 6062.55078125)

										while true do
											wait()
											DoTween2(cFrame)
											if not ((cFrame.Position - fn4(localPlayer.Character).Position).Magnitude <= 8 or game:GetService("Workspace").Map:FindFirstChild("HellDimension")) then
												continue
											end
											break
										end

										Equip("Hallow Essence")
										task.wait(0.3)

										if boatCastle then
											fn(fn4(localPlayer.Character), boatCastle, 0)
											task.wait(0.1)
											fn(fn4(localPlayer.Character), boatCastle, 1)

											if localPlayer.Character:FindFirstChild("Hallow Essence") and localPlayer.Character["Hallow Essence"]:FindFirstChild("Handle") then
												fn(localPlayer.Character["Hallow Essence"].Handle, boatCastle, 0)
												task.wait(0.1)
												fn(localPlayer.Character["Hallow Essence"].Handle, boatCastle, 1)
											end
										end

										wait(3)
									end
								end
							else
								repeat
									wait()
								until Alive()
							end
						end)
					end
				end
			end
		end
	end

	handlers3["Open Pad"] = function()
		OpenPad()
	end

	handlers3["Full Dough King"] = function(arg)
		getNearMob("Full Dough King")

		if CheckItem("Sweet Chalice") or game:GetService("Workspace").Enemies:FindFirstChild("Dough King") or game:GetService("Workspace").Enemies:FindFirstChild("Cake Prince") then
			local katakuri = handlers3.Katakuri
			arg = arg or "Full Dough King"
			katakuri(arg)
		else
			local v4 = GetMaterial("Conjured Cocoa")

			if v4 < 10 then
				local material = handlers3.Material
				arg = arg or "Full Dough King"
				material("Conjured Cocoa", arg)
			elseif getNearMob("Elite") then
				local elite = handlers3.Elite
				arg = arg or "Full Dough King"
				elite(arg)
			elseif not CheckItem("Sweet Chalice") and CheckItem("God's Chalice") and v4 >= 10 then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("SweetChaliceNpc")
			else
				local function fn32()
					return not CheckItem("God's Chalice")
				end

				handlers3.Katakuri(arg or "Full Dough King", fn32)
			end
		end

		fn6(false)
	end

	handlers3.Factory = function(arg, arg2)
		local core = game.Workspace.Enemies:FindFirstChild("Core")
		local str = "Factory"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if fn5(core) then
			SSS(GetNearSpawn(fn4(core).Position))

			while fn5(core) and task.wait(0.1) and fn33() do
				StatusFarming = "Farming Factory"
				fn20(core, nil, nil)
			end

			task.wait(2)
		end

		fn6(false)
	end

	handlers3["Sea 2 Key Hop"] = function()
		MainServerHop(5, "Find New Server [Sea 2 Key Hop]")
	end

	handlers3["Material Soul Guitar"] = function(arg, arg2)
		local str = "Material Soul Guitar"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if DataSave.Unlocked.SoulGuitar and not CheckInvItem("Skull Guitar") then
			if not RequirementGuitar["1"] or not RequirementGuitar["2"] then
				StatusFarming = "Farming Skull Guitar Material"
				print("In Skull Guitar Material")

				if Sea2 or RequirementGuitar["1"] or GetMaterial("Ectoplasm") >= 250 then
					if RequirementGuitar["1"] or GetMaterial("Ectoplasm") >= 250 then
						RequirementGuitar["1"] = true

						if RequirementGuitar["2"] or GetMaterial("Bones") >= 500 then
							RequirementGuitar["2"] = true
						elseif Sea3 then
							MaterialToFarm = "Bones"
						else
							Travel("Sea3")
						end
					else
						MaterialToFarm = "Ectoplasm"
					end
				else
					MainTravel(5, "Farm Material Soul Guitar Sea 2", "Sea2")
				end

				while true do
					wait()
					if not (MaterialToFarm and RequirementGuitar[MaterialToFarm] or RequirementGuitar["1"] and RequirementGuitar["2"] or CheckInvItem("Skull Guitar")) then
						continue
					end
					break
				end

				print(MaterialToFarm)

				local function fn34()
					local flag2 = MaterialToFarm

					if flag2 then
						local v4 = RequirementGuitar[MaterialToFarm]
						flag2 = GetMaterial(MaterialToFarm) < v4
					end

					return flag2 and fn33()
				end

				print("Start Farming Skull Guitar Material")

				if RequirementGuitar[MaterialToFarm] then
					handlers3.Material(MaterialToFarm, arg or "Material Soul Guitar", fn34)
				end
			end

			if RequirementGuitar["1"] and RequirementGuitar["2"] and GetMaterial("Dark Fragment") == 0 then
				StatusFarming = "Farming Dark Fragment Hop"
				print("Skull Guitar Dark Fragment Hop")
				local blackBeardHop = handlers3["Black Beard Hop"]
				arg = arg or "Material Soul Guitar"
				blackBeardHop(arg)
			end

			if RequirementGuitar["1"] and RequirementGuitar["2"] and GetMaterial("Dark Fragment") >= 1 then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("soulGuitarBuy")
			end
		end

		fn6(false)
	end

	handlers3["Citizen Quest"] = function(arg, arg2)
		local str = "Citizen Quest"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		CitizenQuest()

		if ProgressChecker["Citizen Quest"].Hat then
			if not arg then
				getgenv().Setting["Citizen Quest"].Enable = false
			end

			return
		end

		if localPlayer.Data.Level.Value >= 1800 then
			if fn33() then
				if not ProgressChecker["Citizen Quest"].Bandit then
					if not game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible or not string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, "Forest Pirate") then
						Statusfarming = "Citizen Quest: Getting Quest"

						while not SafeGetQuest(CFrame.new(-12445.064453125, 332.37817382812, -7672.3803710938), "CitizenQuest", 1, true) and fn33() and task.wait(0.1) do
							DoTween2(CFrame.new(-12445.064453125, 332.37817382812, -7672.3803710938))
						end
					elseif Alive() then
						local forestPirate = getNearMob("Forest Pirate")

						if fn5(forestPirate) then
							Statusfarming = "Citizen Quest: Bandit"
							SSS(GetNearSpawn(fn4(forestPirate).Position))

							while fn5(forestPirate) and task.wait(0.1) and fn33() do
								fn20(forestPirate)
							end
						else
							SSS(GetNearSpawn(Vector3.new(-13353.897, 331.9582, -7789.153)))
							DoTween2(CFrame.new(-13353.8974609375, 331.95819091796875, -7789.15283203125))
						end
					end
				end

				CitizenQuest()

				if ProgressChecker["Citizen Quest"].Bandit and not ProgressChecker["Citizen Quest"].ElephantBoss then
					local captainElephant = game.Workspace.Enemies:FindFirstChild("Captain Elephant")

					if fn5(captainElephant) then
						Statusfarming = "Citizen Quest: Elephant"
						SSS(GetNearSpawn(fn4(captainElephant).Position))

						while fn5(captainElephant) and fn33() and task.wait(0.1) do
							fn20(captainElephant)
						end
					elseif getgenv().Setting["Citizen Quest"].Hop then
						MainServerHop(5, "Find Saber Mob [Citizen Quest Hop]")
					end
				end

				CitizenQuest()

				if ProgressChecker["Citizen Quest"].ElephantBoss and not ProgressChecker["Citizen Quest"].Hat then
					Statusfarming = "Citizen Quest: Getting Hat"
					DoTween2(CFrame.new(-12513.0078125, 336.3670654296875, -9871.84765625))
				end
			end
		end

		fn6(false)
	end

	handlers3["Soul Guitar"] = function(arg, arg2)
		local str = "Soul Guitar"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if CheckInvItem("Skull Guitar") then
			DataSave.Unlocked.SoulGuitar = true
			return
		end

		while Sea3 and game:GetService("Lighting"):GetAttribute("MoonPhase") and game:GetService("Lighting"):GetAttribute("MoonPhase") == 5 and IsNight() and GetLevel() >= 2300 and not DataSave.Unlocked.SoulGuitar and fn33() do
			repeat
				wait()
			until Alive()

			SSS(GetNearSpawn(Vector3.new(-8652.076, 141.2846, 6169.191)))
			DoTween2(CFrame.new(-8652.076171875, 141.28460693359375, 6169.19091796875))
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("gravestoneEvent", 2)
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("gravestoneEvent", 2, true)

			if Alive() then
				localPlayer.Character.Humanoid:UnequipTools()
			end

			local function fn34()
				local n2 = 0

				for _, child in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
					if child.Name == "Living Zombie" then
						n2 += 1
					end
				end

				return n2
			end

			GuitarProgress()
			local soulGuitar = ProgressChecker.SoulGuitar

			if soulGuitar then
				if soulGuitar.Swamp then
					if soulGuitar.Gravestones then
						if soulGuitar.Ghost then
							if soulGuitar.Pipes then
								if soulGuitar.Trophies then
									DataSave.Unlocked.SoulGuitar = true
								else
									game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Trophies")
								end
							else
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Pipes")
							end
						else
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Ghost")
						end
					else
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Gravestones")
					end
				else
					local tbl16 = {}
					local cframe11 = CFrame.new(-8736.5771484375, 143.10482788085938, 6034.9375)
					local cframe12 = CFrame.new(-9563.5947265625, 5.9761347770690918, 6219.35546875)
					local cframe13 = CFrame.new
					tbl16[1] = cframe11
					tbl16[2] = cframe12

					do
						local values = table.pack(cframe13(-10139.5380859375, 139.62667846679688, 5954.1865234375))
						table.move(values, 1, values.n, 3, tbl16)
					end

					if game:GetService("Workspace").Enemies:FindFirstChild("Living Zombie") then
						if Alive() then
							localPlayer.Character.Humanoid:UnequipTools()
						end

						while task.wait(1) and not soulGuitar.Swamp and game:GetService("Workspace").Enemies:FindFirstChild("Living Zombie") and fn33() do
							GuitarProgress()

							if Alive() and not soulGuitar.Swamp then
								if fn34() >= 6 then
									if (fn4(localPlayer.Character).Position - Vector3.new(tbl16[3])).magnitude < 50 then
										fn6(true)
										local v4 = tbl16[3]
										fn4(localPlayer.Character).CFrame = v4 * CFrame.new(0, 20, 0)
									else
										DoTween2(tbl16[3] * CFrame.new(0, 20, 0))
										fn6(true)
									end

									BringCFrame = tbl16[3]
									BringPos = tbl16[3].Position
									fn15("Specific", "Living Zombie", nil, 500)
									task.wait(0.5)
									pcall(Equip, GetCurrentTool("Melee", true))
								else
									DoTween2(tbl16[3] * CFrame.new(0, 100, 0))
								end

								wait(0.5)
							end
						end

						if not soulGuitar.Swamp then
							localPlayer.Character.Humanoid:UnequipTools()
							DoTween2(tbl16[3] * CFrame.new(0, 100, 0))
						end
					else
						localPlayer.Character.Humanoid:UnequipTools()
						DoTween2(tbl16[3] * CFrame.new(0, 100, 0))
					end
				end
			end
		end
	end

	handlers3.FullyRaceV4_Entrance = function(arg, arg2)
		local str = "FullyRaceV4_Entrance"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("RaceV4Progress", "Check")

		local handlers4 = {
			function()
				StatusFarming = "Begin Race V4 Progrees"
				game.ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "Begin")
			end,
			function()
				StatusFarming = "Tweening To Big Tree"
				DoTween2(CFrame.new(3034.69921875, 2281.371826171875, -7323.568359375))
				wait(0.5)

				for i = 1, 5 do
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ "RaceV4Progress", "Teleport" }))
					wait()
				end
			end,
			function()
				StatusFarming = "Continue Race V4"
				game.ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "Continue")
			end,
		}

		print("Calling")

		if response >= 1 and response < 4 then
			for i = response, 3 do
				handlers4[i]()
				task.wait()
			end

			task.wait(0.5)
			response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("RaceV4Progress", "Check")
			task.wait(1)
		end

		if response == 4 and MirageFunctions.GetMirageIsland() and GetMaterial("Mirror Fractal") >= 1 and CheckInvItem("Valkyrie Helm") and not game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CheckTempleDoor") then
			StatusFarming = "Getting Highest Mirage Place"

			if MirageFunctions.GetMirageIsland() then
				spawn(function()
				end)

				if not MirageFunctions.IsRendered() then
					DoTween2(MirageFunctions.GetMirageIsland().WorldPivot.Position)
				end

				while fn33() and task.wait(0.5) and MirageFunctions.GetMirageIsland() and not game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CheckTempleDoor") do
					if MirageFunctions.GetGear() then
						StatusFarming = "Tweening To Gear"
						MirageFunctions.TweenGear()
						task.wait(0.5)
					else
						local v4 = MirageFunctions.GetHighestPlace()

						if v4 and fn9(v4.WorldPivot.Position + Vector3.new(0, 210, 0), localPlayer.Character) >= 20 then
							StatusFarming = "Tweening To Highest Mirage Place"
							MirageFunctions.TweenHighestPlace()
						else
							if fn33() and MirageFunctions.GetMirageIsland() then
								StatusFarming = "Looking At Moon + Using Skills"
								MirageFunctions.LookAtMoon()
								task.wait()
								game:service("VirtualInputManager"):SendKeyEvent(true, "T", false, game)
								task.wait()
								game:service("VirtualInputManager"):SendKeyEvent(false, "T", false, game)
								task.wait()
							end

							localPlayer.CameraMaxZoomDistance = 200
							localPlayer.CameraMinZoomDistance = 100
							localPlayer.CameraMinZoomDistance = 0
						end
					end
				end
			end
		else
			print("vai ca lon ?")
		end
	end

	handlers3.Law = function(arg, arg2)
		local str = "Law"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		while fn33() and not CheckItem("Core Brain") and task.wait(0.1) do
			local ok, result = pcall(function()
				if not game.Workspace.Enemies:FindFirstChild("Order") then
					print("In not  Law")

					if not localPlayer.Character:FindFirstChild("Microchip") then
						SSS(GetNearSpawn(Vector3.new(-5570.0527, 332.41364, -5965.91)))

						repeat
							wait()
						until Alive()
					else
						DoTween2(CFrame.new(-5570.052734375, 332.41363525391, -5965.91015625))
					end

					if localPlayer.Backpack:FindFirstChild("Microchip") or localPlayer.Character:FindFirstChild("Microchip") then
						fireclickdetector(game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector, 1)
						task.wait(3)
					elseif not localPlayer.Backpack:FindFirstChild("Microchip") or not localPlayer.Character:FindFirstChild("Microchip") then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ "BlackbeardReward", "Microchip", "2" }))
					end
				else
					print("Found Law")
					local order = game:GetService("Workspace").Enemies:WaitForChild("Order")

					local tbl16 = {
						"rbxassetid://4868943717",
						"rbxassetid://4827018132",
						"rbxassetid://4827008125",
						"rbxassetid://4826993463",
					}

					local connection = nil

					if order:FindFirstChild("Humanoid") then
						if order:FindFirstChild("Humanoid"):FindFirstChild("Animator") then
							connection = order.Humanoid.Animator.AnimationPlayed:Connect(function(arg3)
								if table.find(tbl16, arg3.Animation.AnimationId) then
									if table.find(tbl16, arg3.Animation.AnimationId) == 1 then
										task.wait(0.5)
										spinninglaw = true
										task.wait(0.5)
										spinninglaw = false
									else
										DodgingLaw = true
										task.wait(0.5)

										if DodgingLaw then
											task.wait(0.5)
											DodgingLaw = false
										end
									end
								end
							end)
						else
							connection = order:FindFirstChild("Humanoid").ChildAdded:Connect(function(child)
								if child.Name == "Animator" then
									child.AnimationPlayed:Connect(function(arg3)
										if table.find(tbl16, arg3.Animation.AnimationId) then
											if table.find(tbl16, arg3.Animation.AnimationId) == 1 then
												task.wait(0.5)
												spinninglaw = true
												task.wait(0.5)
												spinninglaw = false
											else
												DodgingLaw = true
												task.wait(0.5)

												if DodgingLaw then
													task.wait(0.5)
													DodgingLaw = false
												end
											end
										end
									end)
								end
							end)
						end
					end

					local n2 = 0

					while fn33() and task.wait(0.1) and fn5(order) do
						fn20(order, nil, nil)

						while fn33() and DodgingLaw and fn5(order) and task.wait(0.1) do
							if spinninglaw then
								n2 += 18
								DoTween2(CFrame.new(fn4(order).Position.X + math.sin(math.rad(n2 + 360)) * 40, fn4(order).Position.Y + 100, fn4(order).Position.Z + math.cos(math.rad(n2 + 360)) * 40))
							elseif DodgingLaw then
								fn12(order, Vector3.new(0, 100, 0))
							else
								fn12(order, Vector3.new(0, 40, 40))
							end
						end
					end

					if connection then
						connection:Disconnect()
					end

					fn6(false)
					task.wait(1)
				end
			end)

			if result then
				print(result)
			end
		end
	end

	handlers3.Greybeard = function()
		local Greybeard = GetMainEnemy("Greybeard")

		if fn5(Greybeard) then
			SSS(GetNearSpawn(fn4(Greybeard).Position))

			while fn5(Greybeard) do
				fn20(Greybeard, nil)
			end

			fn6(false)
		end
	end

	handlers3.Pole = function()
		local thunderGod = game.Workspace.Enemies:FindFirstChild("Thunder God")

		if fn5(thunderGod) then
			SSS(GetNearSpawn(fn4(thunderGod).Position))

			while fn5(thunderGod) do
				fn20(thunderGod, nil)
			end

			fn6(false)
		end
	end

	handlers3["Fully Cyborg"] = function(arg, arg2)
		local str = "Fully Cyborg"

		local fn32 = arg2 or function()
			return true
		end

		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CyborgTrainer", "Check")

		if response == true or response == 2 then
			if not arg then
				return
			end
		end

		if not Sea2 then
			Travel("Sea2")
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return not FoundCyborg
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return not FoundCyborg
			end

			return false
		end

		if not cyborgcheck then
			cyborgcheck = game:GetService("ReplicatedStorage").Remotes.CommE.OnClientEvent:Connect(function(arg3, arg4)
				if arg3 == "Notify" then
					if string.find(arg4, "supply") then
						print("Triggered")
						UnlockedRaidLaw = true
					end
				end
			end)
		end

		local connection = RunService.Stepped:Connect(function()
			local response2 = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CyborgTrainer", "Check")

			if response2 == true or response2 == 2 then
				FoundCyborg = true
			end

			task.wait(1)
		end)

		while fn33() and task.wait(0.1) do
			local response2 = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CyborgTrainer", "Check")

			if response2 == true or response2 == 2 then
				if cyborgcheck then
					cyborgcheck:Disconnect()
					cyborgcheck = nil
				end

				return
			end

			task.wait()
			fireclickdetector(game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector, 1)
			task.wait(1)

			if CheckItem("Core Brain") and UnlockedRaidLaw then
				Equip("Core Brain")
				fireclickdetector(game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
			elseif UnlockedRaidLaw then
				local function fn34()
					return not CheckItem("Core Brain") and fn33()
				end

				handlers3.Law(arg or "Fully Cyborg", fn34)
			elseif CheckItem("Fist of Darkness") and not UnlockedRaidLaw then
				Click()
				Equip("Fist of Darkness")
				fireclickdetector(game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector, 1)
			elseif not UnlockedRaidLaw then
				fireclickdetector(game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector, 1)
				task.wait(1)

				if not UnlockedRaidLaw then
					local function fn34()
						return not UnlockedRaidLaw and fn33()
					end

					handlers3["Collect Chest"](arg or "Fully Cyborg", fn34, true)
				end
			end
		end

		if connection then
			connection:Disconnect()
		end
	end

	handlers3["Spawn Soul Reaper"] = function(arg, arg2)
		if not Sea3 then
			return
		end

		if fn5(game.Workspace.Enemies:FindFirstChild("Soul Reaper")) then
			return
		end
		local str = "Spawn Soul Reaper"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str] and getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg] and getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return CheckItem("Hallow Essence")
		end

		if CheckItem("Hallow Essence") then
			repeat
				wait()
			until Alive()

			StatusFarming = "Spawning Soul Reaper"
			local cframe11 = CFrame.new(-8932.322265625, 146.83154296875, 6062.55078125)
			local boatCastle = game:GetService("Workspace").Map:FindFirstChild("Boat Castle") or game:GetService("Workspace").Map:FindFirstChild("Haunted Castle") or workspace:FindFirstChild("Boat Castle", true)

			if boatCastle then
				boatCastle = boatCastle:FindFirstChild("Summoner") or boatCastle:FindFirstChild("Summoner", true)
			end

			if boatCastle then
				boatCastle = boatCastle:FindFirstChild("Detection") or boatCastle:FindFirstChild("Part")
			end

			if boatCastle then
				cframe11 = boatCastle.CFrame
			end

			while Alive() and CheckItem("Hallow Essence") and not fn5(game.Workspace.Enemies:FindFirstChild("Soul Reaper")) and (cframe11.Position - fn4(localPlayer.Character).Position).Magnitude > 8 and task.wait(0.1) do
				DoTween2(cframe11)
			end

			if Alive() and CheckItem("Hallow Essence") and not fn5(game.Workspace.Enemies:FindFirstChild("Soul Reaper")) then
				Equip("Hallow Essence")
				task.wait(0.3)

				if boatCastle then
					fn(fn4(localPlayer.Character), boatCastle, 0)
					task.wait(0.1)
					fn(fn4(localPlayer.Character), boatCastle, 1)

					if localPlayer.Character:FindFirstChild("Hallow Essence") and localPlayer.Character["Hallow Essence"]:FindFirstChild("Handle") then
						fn(localPlayer.Character["Hallow Essence"].Handle, boatCastle, 0)
						task.wait(0.1)
						fn(localPlayer.Character["Hallow Essence"].Handle, boatCastle, 1)
					end
				else
					fn4(localPlayer.Character).CFrame = cframe11
				end

				task.wait(2)
			end

			return
		end

		if fn33() and not CheckItem("Hallow Essence") and not fn5(game.Workspace.Enemies:FindFirstChild("Soul Reaper")) then
			local Bones = GetMaterial("Bones")

			if Bones >= 50 and (not CanRandomBone or CanRandomBone()) then
				StatusFarming = "Rolling Bones for Hallow Essence (" .. tostring(Bones) .. " Bones)"

				pcall(function()
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Bones", "Buy", 1, 1)
				end)

				task.wait(1)
				if CheckItem("Hallow Essence") then
					return
				end
			end

			if not CheckItem("Hallow Essence") and not fn5(game.Workspace.Enemies:FindFirstChild("Soul Reaper")) and fn33() then
				StatusFarming = "Farming Bones for Soul Reaper (" .. tostring(GetMaterial("Bones")) .. "/50)"

				local function fn34()
					return fn33() and not CheckItem("Hallow Essence") and not fn5(game.Workspace.Enemies:FindFirstChild("Soul Reaper")) and GetMaterial("Bones") < 50
				end

				if handlers3.Material then
					local material = handlers3.Material
					arg = arg or "Spawn Soul Reaper"
					material("Bones", arg, fn34)
				elseif handlers3.Bone then
					local bone = handlers3.Bone
					arg = arg or "Spawn Soul Reaper"
					bone(arg, fn34)
				end
			end
		end
	end

	handlers3["Soul Reaper"] = function(arg, arg2)
		local str = "Soul Reaper"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str] and getgenv().Setting[str].Enable or getgenv().Setting["Spawn Soul Reaper"] and getgenv().Setting["Spawn Soul Reaper"].Enable or getgenv().Setting.OneClick and getgenv().Setting.OneClick.Enable then
					return true
				end
			elseif getgenv().Setting[arg] and getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		local soulReaper = game.Workspace.Enemies:FindFirstChild("Soul Reaper")

		if fn5(soulReaper) then
			while fn5(soulReaper) and task.wait(0.1) and fn33() do
				fn20(soulReaper, nil, fn33)
			end
		end
	end

	handlers3["Travel Sea3"] = function()
		local v4, v5, v6 = handlers2["Travel Sea3"]()

		if v4 then
			MainTravel(10, "Sea3" .. v6 or "None", "Sea3")
		end
	end

	handlers3.Raid = function(arg, arg2)
		if localPlayer.Data.Level.Value >= 1100 then
			local str = "Raid"
			StatusFarming = "Auto Raid Is Turned On"
			local cFrame = nil
			local flag2 = false
			local flag3 = false

			local function fn32()
				local function fn33()
					local tbl16 = { "Island 1", "Island 2", "Island 3", "Island 4", "Island 5" }
					local v4 = nil

					for k, v5 in pairs(tbl16) do
						for _, child in pairs(game:GetService("Workspace")._WorldOrigin.Locations:GetChildren()) do
							if child.Name == v5 then
								local v6 = fn4(localPlayer.Character)

								if (v6.Position - child.Position).Magnitude < 2500 then
									if v4 then
										if (v6.Position - child.Position).Magnitude < (v6.Position - v4.Position).Magnitude then
											if child.Name ~= v4 then
												if k == 1 then
													flag2 = true
												else
													flag2 = false
												end

												flag3 = true
												v4 = child
											end
										end
									else
										flag3 = true

										if k == 1 then
											flag2 = true
											v4 = child
										else
											flag2 = false
											v4 = child
										end
									end
								end
							end
						end
					end

					if v4 then
						local position = v4.Position

						if (fn4(localPlayer.Character).Position - position).Magnitude < 3000 then
							if v4.Name == tbl16[1] then
								wait(1)
							end

							wait(0.1)
							cFrame = v4.CFrame
							v4.Name = v4.Name .. "Pass"
						end
					end
				end

				fn33()

				if Alive() and localPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
					if not getgenv().Setting.Raid.NoDelay and flag3 and not flag2 then
						flag3 = false
						task.wait(20)
					end

					if cFrame then
						DoTween2(cFrame * CFrame.new(0, 60, 0))
						fn6(true)
					end
				end
			end

			local fn33 = arg2 or function()
				return true
			end

			local enable = getgenv().Setting.OneClick.Enable and CanAwaken() and AutoChip[localPlayer.Data.DevilFruit.Value]

			local function fn34()
				if not arg then
					if getgenv().Setting[str].Enable then
						return true
					end
				elseif getgenv().Setting[arg].Enable and fn33() then
					return true
				end

				return false
			end

			if fn34() then
				local enable2 = getgenv().Setting.OneClick.Enable or getgenv().Setting.Raid.GetFruitUnder1M

				if #FruitFunc.HaveFruitInv() == 0 and (enable2 or arg == "OneClick") and FruitFunc.GetFruitBelow1M() then
					local v4 = FruitFunc.GetFruitBelow1M()
					print("Getting Fruit", v4)
					StatusFarming = "Getting Fruit For Raid " .. tostring(v4)
					FruitFunc.ReloadFruit(v4)
					task.wait(0.5)
				end

				if getgenv().Setting.Raid.Awaken or getgenv().Setting.OneClick.Enable then
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Awakener", "Awaken")
				end

				if #FruitFunc.HaveFruitInv() >= 1 and not CheckItem("Special Microchip") then
					print("Buy Chip")
					wait()

					local tbl16 = {
						"RaidsNpc",
						"Select",
						enable or getgenv().Setting.Raid.Select == "" and "Ice" or getgenv().Setting.Raid.Select or "Ice",
					}

					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(tbl16))
					task.wait(1)
				end

				FruitFunc.IgnoreStoreFruit = nil

				if CheckItem("Special Microchip") then
					pcall(function()
						localPlayer.Character.Humanoid:UnequipTools()
					end)

					print("Click")
					local main = nil
					local ok

					if Sea3 then
						TPToEntrance("Castle")
						DoTween2(CFrame.new(-5034.16309, 314.9664, -2948.1499))
						task.wait(3)
						local boatCastle = game:GetService("Workspace").Map:FindFirstChild("Boat Castle")

						ok = pcall(function()
							if boatCastle then
								local raidSummon2 = boatCastle:FindFirstChild("RaidSummon2")

								if raidSummon2 then
									local button = raidSummon2:FindFirstChild("Button")

									if button then
										main = button:FindFirstChild("Main")

										if main then
											fireclickdetector(main.ClickDetector)
										end
									end
								end
							end
						end)
					else
						ok = nil

						if Sea2 then
							DoTween2(CFrame.new(-6438.73535, 250.645355, -4501.50684))
							task.wait(3)

							ok = pcall(function()
								main = game:GetService("Workspace").Map.CircleIsland.RaidSummon2.Button.Main
								fireclickdetector(game:GetService("Workspace").Map.CircleIsland.RaidSummon2.Button.Main.ClickDetector)
							end)
						end
					end

					if ok or localPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
						print("Clicked")

						if fn34() then
							wait(5.5)
						end

						local now = tick()
						StatusFarming = "Wait Raid Timer"
						print("Wait Timer")

						while true do
							local flag4 = fn34()

							if flag4 then
								flag4 = not (tick() - now > 15 or localPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible)
							end

							if flag4 and task.wait(0.1) then
								continue
							end
							break
						end

						task.wait(0.5)
						LastPositionI = nil
						print("TP")

						while fn34() and localPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible and task.wait(0.1) do
							StatusFarming = "Farm Raid"
							pcall(Equip, GetCurrentTool("Melee", true))
							local v4 = nil

							for _, child in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
								if fn5(child) and Alive() then
									if fn9(child, localPlayer.Character) <= 2000 then
										fn9(child, localPlayer.Character)
										v4 = child
									end
								end
							end

							if not v4 then
								local ok2, result = pcall(fn32)

								if result then
									print(result)
								end
							else
								while Alive() and fn5(v4) and fn9(v4, localPlayer.Character) <= 2000 and task.wait() do
									pcall(function()
										pcall(Equip, GetCurrentTool("Melee", true))
										fn20(v4, nil, nil, nil, true)
									end)
								end
							end
						end

						if getgenv().Setting.Raid.Awaken or getgenv().Setting.OneClick.Enable and CanAwaken() then
							task.wait(3)
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Awakener", "Awaken")
						end

						task.wait(10)
						print("Finished Raid")
					end
				end
			end
		end
	end

	handlers3["Rainbow Haki"] = function(arg, arg2, arg3)
		local str = "Rainbow Haki"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("HornedMan")

		if response then
			if string.find(response, "1") then
				if not arg then
					getgenv().Setting[str].Enable = false
				end

				return Notify({ Text = "You Already Have Rainbow Haki", Type2 = nil, Delay = 5 })
			end

			startrainbowquest = function()
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("HornedMan", "Bet")
			end

			for _, v4 in pairs({ "Stone", "Island Empress", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate" }) do
				if string.find(response, v4) then
					startrainbowquest()
					local v5 = game:GetService("Workspace").Enemies:FindFirstChild(v4)

					if fn5(v5) then
						while task.wait(0.2) and fn5(v5) and fn33() do
							fn20(v5)
						end
					elseif getgenv().Setting["Rainbow Haki"].Enable and getgenv().Setting["Rainbow Haki"].Hop or fn33() and arg3 then
						MainServerHop(5, "Find New Server [Rainbow Haki Hop]")
					end

					fn6(false)
				end
			end
		end
	end

	handlers3["God Human Material"] = function(arg, arg2)
		local str = "God Human Material"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		local exitTo2 = nil
		local exitTo, farmingGodHumanMaterial

		while true do
			local flag2 = fn33() and not DataSave.Unlocked.GodHuman
			exitTo = nil
			local fn34, material, str2

			while flag2 do
				if RequirementGod["1"] and RequirementGod["2"] and RequirementGod["3"] and RequirementGod["4"] then
					exitTo = 1
					break
				else
					StatusFarming = "Farming God Human Material"
					print("[GodHuman] Starting material check cycle")
					farmingGodHumanMaterial = nil

					if Sea2 or (RequirementGod["1"] or GetMaterial("Magma Ore") >= 20) and (RequirementGod["2"] or GetMaterial("Mystic Droplet") >= 10) then
						if not RequirementGod["1"] then
							local v4 = GetMaterial("Magma Ore")

							if v4 >= 20 then
								RequirementGod["1"] = true
								print("[GodHuman] Magma Ore completed: " .. v4 .. "/20")
							else
								farmingGodHumanMaterial = "Magma Ore"
								print("[GodHuman] Need Magma Ore: " .. v4 .. "/20")
							end
						end

						if not farmingGodHumanMaterial and not RequirementGod["2"] then
							local v4 = GetMaterial("Mystic Droplet")

							if v4 >= 10 then
								RequirementGod["2"] = true
								print("[GodHuman] Mystic Droplet completed: " .. v4 .. "/10")
							else
								farmingGodHumanMaterial = "Mystic Droplet"
								print("[GodHuman] Need Mystic Droplet: " .. v4 .. "/10")
							end
						end

						if not farmingGodHumanMaterial and Sea3 then
							if not RequirementGod["3"] then
								local v4 = GetMaterial("Fish Tail")

								if v4 >= 20 then
									RequirementGod["3"] = true
									print("[GodHuman] Fish Tail completed: " .. v4 .. "/20")
								else
									farmingGodHumanMaterial = "Fish Tail"
									print("[GodHuman] Need Fish Tail: " .. v4 .. "/20")
								end
							end

							if not farmingGodHumanMaterial and not RequirementGod["4"] then
								local v4 = GetMaterial("Dragon Scale")

								if v4 >= 10 then
									RequirementGod["4"] = true
									print("[GodHuman] Dragon Scale completed: " .. v4 .. "/10")

									if farmingGodHumanMaterial then
										StatusFarming = "Farming God Human Material: " .. farmingGodHumanMaterial
										print("[GodHuman] Starting farm: " .. farmingGodHumanMaterial)

										fn34 = function()
											local flag3 = farmingGodHumanMaterial

											if farmingGodHumanMaterial then
												local v5 = RequirementGod[farmingGodHumanMaterial]
												flag3 = GetMaterial(farmingGodHumanMaterial) < v5
											end

											return flag3 and fn33()
										end

										material = handlers3.Material
										str2 = "God Human Material"
										str2 = arg or str2
										material(farmingGodHumanMaterial, str2, fn34)
										task.wait(1)

										if not fn33() then
											exitTo = 12
											break
										else
											flag2 = fn33() and not DataSave.Unlocked.GodHuman
										end
									else
										exitTo = 11
										break
									end
								else
									farmingGodHumanMaterial = "Dragon Scale"
									print("[GodHuman] Need Dragon Scale: " .. v4 .. "/10")

									if farmingGodHumanMaterial then
										StatusFarming = "Farming God Human Material: " .. farmingGodHumanMaterial
										print("[GodHuman] Starting farm: " .. farmingGodHumanMaterial)

										fn34 = function()
											local flag3 = farmingGodHumanMaterial

											if farmingGodHumanMaterial then
												local v5 = RequirementGod[farmingGodHumanMaterial]
												flag3 = GetMaterial(farmingGodHumanMaterial) < v5
											end

											return flag3 and fn33()
										end

										material = handlers3.Material
										str2 = "God Human Material"
										str2 = arg or str2
										material(farmingGodHumanMaterial, str2, fn34)
										task.wait(1)

										if not fn33() then
											exitTo = 10
											break
										else
											flag2 = fn33() and not DataSave.Unlocked.GodHuman
										end
									else
										exitTo = 9
										break
									end
								end
							elseif farmingGodHumanMaterial then
								StatusFarming = "Farming God Human Material: " .. farmingGodHumanMaterial
								print("[GodHuman] Starting farm: " .. farmingGodHumanMaterial)

								fn34 = function()
									local flag3 = farmingGodHumanMaterial

									if farmingGodHumanMaterial then
										local v4 = RequirementGod[farmingGodHumanMaterial]
										flag3 = GetMaterial(farmingGodHumanMaterial) < v4
									end

									return flag3 and fn33()
								end

								material = handlers3.Material
								str2 = "God Human Material"
								str2 = arg or str2
								material(farmingGodHumanMaterial, str2, fn34)
								task.wait(1)

								if not fn33() then
									exitTo = 8
									break
								else
									flag2 = fn33() and not DataSave.Unlocked.GodHuman
								end
							else
								exitTo = 7
								break
							end
						elseif not farmingGodHumanMaterial and not Sea3 then
							if not RequirementGod["3"] or not RequirementGod["4"] then
								exitTo = 4
								break
							elseif farmingGodHumanMaterial then
								StatusFarming = "Farming God Human Material: " .. farmingGodHumanMaterial
								print("[GodHuman] Starting farm: " .. farmingGodHumanMaterial)

								fn34 = function()
									local flag3 = farmingGodHumanMaterial

									if farmingGodHumanMaterial then
										local v4 = RequirementGod[farmingGodHumanMaterial]
										flag3 = GetMaterial(farmingGodHumanMaterial) < v4
									end

									return flag3 and fn33()
								end

								material = handlers3.Material
								str2 = "God Human Material"
								str2 = arg or str2
								material(farmingGodHumanMaterial, str2, fn34)
								task.wait(1)

								if not fn33() then
									exitTo = 6
									break
								else
									flag2 = fn33() and not DataSave.Unlocked.GodHuman
								end
							else
								exitTo = 5
								break
							end
						else
							exitTo = 3
							break
						end
					else
						exitTo = 2
						break
					end
				end
			end

			if exitTo == 1 then
				exitTo2 = 1
				break
			elseif exitTo == 2 then
				print("[GodHuman] Traveling to Sea 2 for Magma Ore/Mystic Droplet")
				MainTravel(10, "Traveling Sea 2 To Farm Material [God Human Material]", "Sea2")
				task.wait(2)
				continue
			elseif exitTo == 3 then
				if farmingGodHumanMaterial then
					StatusFarming = "Farming God Human Material: " .. farmingGodHumanMaterial
					print("[GodHuman] Starting farm: " .. farmingGodHumanMaterial)

					fn34 = function()
						local flag3 = farmingGodHumanMaterial

						if farmingGodHumanMaterial then
							local v4 = RequirementGod[farmingGodHumanMaterial]
							flag3 = GetMaterial(farmingGodHumanMaterial) < v4
						end

						return flag3 and fn33()
					end

					material = handlers3.Material
					str2 = "God Human Material"
					str2 = arg or str2
					material(farmingGodHumanMaterial, str2, fn34)
					task.wait(1)

					if not fn33() then
						exitTo2 = 3
						break
					else
						continue
					end
				else
					exitTo2 = 2
					break
				end
			elseif exitTo == 4 then
				print("[GodHuman] Traveling to Sea 3 for Fish Tail/Dragon Scale")
				MainTravel(10, "Traveling Sea 3 To Farm Material [God Human Material]", "Sea3")
				task.wait(2)
				continue
			end

			break
		end

		if exitTo2 == 1 then
			print("[GodHuman] All materials collected!")
			StatusFarming = "God Human Material: All Collected"
		elseif exitTo2 == 2 then
			print("[GodHuman] No material to farm but requirements not met - breaking")
		elseif exitTo2 == 3 then
			print("[GodHuman] Farm disabled, exiting")
		elseif exitTo == 5 then
			print("[GodHuman] No material to farm but requirements not met - breaking")
		elseif exitTo == 6 then
			print("[GodHuman] Farm disabled, exiting")
		elseif exitTo == 7 then
			print("[GodHuman] No material to farm but requirements not met - breaking")
		elseif exitTo == 8 then
			print("[GodHuman] Farm disabled, exiting")
		elseif exitTo == 9 then
			print("[GodHuman] No material to farm but requirements not met - breaking")
		elseif exitTo == 10 then
			print("[GodHuman] Farm disabled, exiting")
		elseif exitTo == 11 then
			print("[GodHuman] No material to farm but requirements not met - breaking")
		elseif exitTo == 12 then
			print("[GodHuman] Farm disabled, exiting")
		end

		if RequirementGod["1"] and RequirementGod["2"] and RequirementGod["3"] and RequirementGod["4"] then
			print("[GodHuman] All materials collected! Starting purchase checks...")
			StatusFarming = "God Human: Checking Requirements"
			task.wait(1)
			print("[GodHuman] Step 1: Checking prerequisite melee mastery...")
			local flag2, v4

			if _CheckAllGodHumanMastery then
				flag2, v4 = _CheckAllGodHumanMastery()
			else
				flag2 = true
				v4 = nil

				for _, v5 in pairs({ "Superhuman", "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon" }) do
					local v6, v7, v8 = checkMeleeMastery(v5)

					if not v6 or not v8 or v8 < 400 then
						flag2 = false
						v4 = v5
						break
					else
						v4 = nil
					end
				end
			end

			if not flag2 then
				print("[GodHuman]  Missing mastery: " .. tostring(v4) .. " < 400")
				StatusFarming = "Need " .. tostring(v4) .. " >= 400 Mastery"

				if DataSave.Unlocked.GodHuman then
					print("[GodHuman] Already unlocked!")
				end

				return
			end

			print("[GodHuman] Step 2: Checking server status...")
			local v5 = CheckGodhumanMaterialStatus()

			if v5.owned then
				DataSave.Unlocked.GodHuman = true
				DataSave.Melee["God Human"].Have = true

				if _MeleeSaveToDisk then
					_MeleeSaveToDisk()
				end

				StatusFarming = "God Human: Already Owned"
				return
			end

			if not v5.ready then
				print("[GodHuman]  Server not ready: " .. v5.message)
				StatusFarming = "God Human: " .. v5.message
				return
			end

			print("[GodHuman]  Server ready (code: " .. tostring(v5.code) .. ")")
			print("[GodHuman] Step 3: Checking beli and fragments...")
			local n2 = localPlayer.Data.Beli.Value or 0
			local n3 = localPlayer.Data.Fragments.Value or 0
			print("[GodHuman] Current beli: " .. n2 .. " / 5,000,000")
			print("[GodHuman] Current fragments: " .. n3 .. " / 5,000")

			if n2 < 5000000 then
				print("[GodHuman]  Need more beli: " .. n2 .. "/5,000,000")
				StatusFarming = "God Human: Need " .. 5000000 - n2 .. " More Beli"
				return
			end

			if n3 < 5000 then
				print("[GodHuman]  Need more fragments: " .. n3 .. "/5,000")
				StatusFarming = "God Human: Need " .. 5000 - n3 .. " More Fragments"
				return
			end

			print("[GodHuman]  Beli and fragments sufficient")
			print("[GodHuman] Step 4: Traveling to Ancient Monk NPC and purchasing...")
			StatusFarming = "God Human: Purchasing from NPC"

			if _TravelAndBuyMelee then
				_TravelAndBuyMelee("Godhuman")
			else
				print("[GodHuman]  _TravelAndBuyMelee not available, attempting direct purchase...")

				pcall(function()
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyGodhuman", true)
					task.wait(0.3)
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyGodhuman")
				end)
			end

			task.wait(2)
			print("[GodHuman] Step 5: Verifying purchase...")
			local v6 = CheckGodhumanMaterialStatus()

			if v6.owned then
				print("[GodHuman]  Purchase successful!")
				DataSave.Unlocked.GodHuman = true
				DataSave.Melee["God Human"].Have = true
				DataSave.Melee["God Human"].Mas400 = true

				if _MeleeSaveToDisk then
					_MeleeSaveToDisk()
				end

				StatusFarming = "God Human: Purchased Successfully "
			else
				print("[GodHuman]  Purchase verification failed, status: " .. v6.message)
				StatusFarming = "God Human: " .. v6.message
			end
		end

		if DataSave.Unlocked.GodHuman then
			print("[GodHuman] Already unlocked!")
		end
	end

	handlers3["Items Farm Force"] = function()
		for _, v4 in pairs(tbl8) do
			if not tbl7[v4] then
				StatusFarming = "Farming Items From Boss [" .. tostring(v4) .. "]"
				local v5 = GetMainEnemy(v4)

				if fn5(v5) then
					SSS(GetNearSpawn(fn4(v5).Position))

					while fn5(v5) do
						fn20(v5, nil)
						task.wait()
					end

					fn6(false)
				end
			end
		end
	end

	handlers3["Level Observation"] = function(arg, arg2, arg3)
		local str = "Level Observation"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if not game:GetService("CollectionService"):HasTag(localPlayer.Character, "Ken") then
			Notify({ Text = "You Dont Have Ken Haki", Type2 = nil, Delay = 5 })

			if not arg then
				getgenv().Setting[str].Enable = false
			end

			return
		end

		local response = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("KenTalk", "Status")

		if response then
			local v4 = string.gsub(response, "%D", "")
			Notify({ Text = "Current Haki Level: " .. tostring(v4), Type2 = nil, Delay = 5 })

			if tonumber(v4) >= 5000 then
				Notify({ Text = "Maxed Ken Haki", Type2 = nil, Delay = 5 })

				if not arg then
					getgenv().Setting[str].Enable = false
				end

				return
			end
		end

		if Alive() and localPlayer:FindFirstChild("VisionRadius") then
			local cframe11, str2

			if Sea1 then
				cframe11 = CFrame.new(5533.29785, 88.1079102, 4852.3916)
				str2 = "Galley Captain"
			elseif Sea2 then
				cframe11 = CFrame.new(5587.1064453125, 57.5491943359375, -6607.7607421875)
				str2 = "Snow Lurker"
			else
				cframe11 = nil
				str2 = nil

				if Sea3 then
					cframe11 = CFrame.new(2451.812255859375, 27.035882949829102, -6489.86767578125)
					str2 = "Marine Commodore"
				end
			end

			if not ObservationManager.IsActive() then
				VirtualUser:CaptureController()
				VirtualUser:SetKeyDown("0x65")
				wait()
				VirtualUser:SetKeyUp("0x65")
			end

			if str2 ~= nil and cframe11 ~= nil then
				localPlayer.Character.Humanoid:UnequipTools()

				if not game.Workspace.Enemies:FindFirstChild(str2) then
					SSS(GetNearSpawn(cframe11.Position))
					DoTween2(cframe11)
				end

				if game.Workspace.Enemies:FindFirstChild(str2) then
					SSS(GetNearSpawn(cframe11.Position))

					while task.wait(0.1) and not ObservationManager.IsActive() and fn33() do
						fn6(true)
						local enemies2 = game.Workspace.Enemies

						if (fn4(localPlayer.Character).Position - enemies2:FindFirstChild(str2).HumanoidRootPart.Position).magnitude < 300 then
							fn4(localPlayer.Character).CFrame = game.Workspace.Enemies:FindFirstChild(str2).HumanoidRootPart.CFrame * CFrame.new(30, 30, 30)
						else
							DoTween2(game.Workspace.Enemies:FindFirstChild(str2).HumanoidRootPart.CFrame * CFrame.new(30, 30, 30))
						end

						if not ObservationManager.IsActive() then
							VirtualUser:CaptureController()
							VirtualUser:SetKeyDown("0x65")
							task.wait(1)
							VirtualUser:SetKeyUp("0x65")
						end
					end

					fn6(false)

					if ObservationManager.IsActive() then
						DoTween2(game.Workspace.Enemies:FindFirstChild(str2).HumanoidRootPart.CFrame * CFrame.new(3, 0, 0))

						while ObservationManager.IsActive() and fn33() and task.wait(0.1) do
							local enemies2 = game.Workspace.Enemies

							if (fn4(localPlayer.Character).Position - enemies2:FindFirstChild(str2).HumanoidRootPart.Position).magnitude < 300 then
								fn4(localPlayer.Character).CFrame = game.Workspace.Enemies:FindFirstChild(str2).HumanoidRootPart.CFrame * CFrame.new(3, 0, 0)
							else
								DoTween2(game.Workspace.Enemies:FindFirstChild(str2).HumanoidRootPart.CFrame * CFrame.new(3, 0, 0))
							end
						end

						task.wait(0.1)

						if getgenv().Setting["Level Observation"].Enable and getgenv().Setting["Level Observation"].Hop or fn33() and arg3 then
							MainServerHop(5, "Find New Server [Level Observation Hop]")
						end
					end
				end
			end

			return
		end
	end

	handlers3.BlackSmith = function(arg, arg2)
		local str = "BlackSmith"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if not getgenv().Setting.BlackSmith.WeaponType then
			TypeSmith = "Sword"
		else
			TypeSmith = "Gun"
		end

		local v4 = GetCurrentTool(TypeSmith, true)

		if v4 then
			for k, v5 in pairs(AutoBlackSmithv1[GetCurrentTool(TypeSmith, true)]) do
				if fn33() and v4 == GetCurrentTool(TypeSmith, true) and GetCurrentTool(TypeSmith).Upgrades.Value == 0 then
					if GetMaterial(k) < v5 then
						if currentPlaceKey == tbl2.MaterialSeaChecker[k] then
							local function fn34()
								return fn33() and GetMaterial(k) < v5 and v4 == GetCurrentTool(TypeSmith, true) and GetCurrentTool(TypeSmith).Upgrades.Value == 0
							end

							handlers3.Material(k, arg or "BlackSmith", fn34)
						elseif tbl2.MaterialSeaChecker[k] == "7449423635" then
							Travel("Sea3")
						elseif tbl2.MaterialSeaChecker[k] ~= "2753915549" then
							MainTravel(5, "Blacksmith Material Sea 2", "Sea2")
						else
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelMain")
						end
					end
				end
			end

			if fn33() then
				if not DataSave.BlackSmith[GetCurrentTool(TypeSmith, true)] then
					if GetCurrentTool(TypeSmith).Upgrades.Value == 0 then
						local flag2 = true

						for k, v5 in pairs(AutoBlackSmithv1[GetCurrentTool(TypeSmith, true)]) do
							if GetMaterial(k) < v5 then
								flag2 = false
								break
							end
						end

						if flag2 then
							if Sea3 then
								DoTween2(CFrame.new(-354.525390625, 43.790943145751953, 5545.2412109375), fn33)
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("UpgradeItem", "Upgrade", GetCurrentTool(TypeSmith))
							else
								Travel("Sea3")
							end
						end
					else
						DataSave.BlackSmith[GetCurrentTool(TypeSmith, true)] = true

						if fn33() then
							SwitchWeaponSmith(TypeSmith)
						end
					end
				end
			end
		end
	end

	handlers3["Evolve Observation"] = function()
		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CitizenQuestProgress", "Citizen")
		local response2 = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("KenTalk", "Status")

		if localPlayer.Data.Level.Value >= 1800 then
			if response2 and response then
				if tonumber(response2) and response2 < 5000 then
					getgenv().Setting["Evolve Observation"].Enable = false
					return
				end

				if response ~= 3 then
					getgenv().Setting["Evolve Observation"].Enable = false
					return
				end
				local response3 = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("KenTalk2", "Start")
				if response3 and response3 == 0 then
					getgenv().Setting["Evolve Observation"].Enable = false
					return
				end
				local flag2 = nil
				local flag3 = nil
				local flag4 = nil

				CheckFruitObservationv2 = function()
					local flag5 = false

					if Alive() then
						if localPlayer.Character:FindFirstChild("Apple") or localPlayer.Backpack:FindFirstChild("Apple") then
							flag2 = true
						else
							if not game:GetService("Workspace").AppleSpawner:FindFirstChild("Apple") then
								flag5 = true
							end

							flag2 = false
						end

						if localPlayer.Character:FindFirstChild("Banana") or localPlayer.Backpack:FindFirstChild("Banana") then
							flag3 = true
						else
							if not game:GetService("Workspace").BananaSpawner:FindFirstChild("Banana") then
								flag5 = true
							end

							flag3 = false
						end

						if localPlayer.Character:FindFirstChild("Pineapple") or localPlayer.Backpack:FindFirstChild("Pineapple") then
							flag4 = true
						else
							if not game:GetService("Workspace").PineappleSpawner:FindFirstChild("Pineapple") then
								flag5 = true
							end

							flag4 = false
						end
					end

					return flag5
				end

				if CheckFruitObservationv2() and getgenv().Setting["Evolve Observation"].Hop then
					MainServerHop(5, "Find New Server [Evolve Observation Hop]")
				end

				pcall(function()
					if not CheckItem("Fruit Bowl") then
						if not flag2 and not DoingTweenObservationV2 then
							local apple = game:GetService("Workspace").AppleSpawner:FindFirstChild("Apple")
							DoingTweenObservationV2 = true

							if apple then
								DoTween2(apple.Handle.CFrame)
							end

							DoingTweenObservationV2 = false
						end

						if not flag3 and not DoingTweenObservationV2 then
							local banana = game:GetService("Workspace").BananaSpawner:FindFirstChild("Banana")
							DoingTweenObservationV2 = true

							if banana then
								DoTween2(banana.Handle.CFrame)
							end

							DoingTweenObservationV2 = false
						end

						if not flag4 and not DoingTweenObservationV2 then
							local pineapple = game:GetService("Workspace").PineappleSpawner:FindFirstChild("Pineapple")
							DoingTweenObservationV2 = true

							if pineapple then
								DoTween2(pineapple.Handle.CFrame)
							end

							DoingTweenObservationV2 = false
						end

						if flag4 and flag2 and flag3 then
							DoTween2(CFrame.new(-12445.064453125, 332.37817382812, -7672.3803710938))
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ "CitizenQuestProgress", "Citizen" }))
						end
					else
						DoTween2(CFrame.new(-10922.568359375, 624.17694091796875, -10265.767578125))
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("KenTalk2", "Buy")
					end
				end)
			end

			return
		end

		getgenv().Setting["Evolve Observation"].Enable = false
	end

	handlers3.__KatakuriHop = function(arg, arg2)
		local str = "__KatakuriHop"

		local function fn32()
			local ok, result = pcall(function()
				return game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CakePrinceSpawner", true)
			end)

			return ok and result or "0"
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and arg2() then
				return true
			end

			return false
		end

		local cakePrince = game.Workspace.Enemies:FindFirstChild("Cake Prince") or game.Workspace.Enemies:FindFirstChild("Dough King")

		if fn5(cakePrince) then
			local v4 = handlers3[cakePrince.Name]
			arg = arg or "__KatakuriHop"
			v4(arg)
		else
			local v4 = string.gsub(fn32(), "%D", "")

			local thread = task.spawn(function()
				while task.wait(0.5) do
					v4 = string.gsub(fn32(), "%D", "")
				end
			end)

			local function fn34()
				return tonumber(v4) and math.abs(tonumber(v4) - 500) >= 300
			end

			handlers3.Katakuri(arg or "__KatakuriHop", fn34)

			if not tonumber(v4) or tonumber(v4) < 1 then
				game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("CakePrinceSpawner")
			end

			local cakePrince2 = game.Workspace.Enemies:FindFirstChild("Cake Prince") or game.Workspace.Enemies:FindFirstChild("Dough King")

			if fn5(cakePrince2) then
				local v5 = handlers3[cakePrince2.Name]
				arg = arg or "__KatakuriHop"
				v5(arg)
			end

			task.cancel(thread)
		end

		if fn33() then
			MainServerHop(5, "Find New Server [Katakuri Hop]")
		end
	end

	handlers3.BossSniper = function()
		local flag2 = false

		for _, v4 in pairs(getgenv().Setting.BossSniper.SelectedBoss) do
			local v5 = game.Workspace.Enemies:FindFirstChild(v4)

			if fn5(v5) then
				if BossQuest[currentPlaceKey][v4] and localPlayer.Data.Level.Value >= BossQuest[currentPlaceKey][v4].Require then
					local pos = BossQuest[currentPlaceKey][v4].Pos

					while not SafeGetQuest(pos, BossQuest[currentPlaceKey][v4].Quest, BossQuest[currentPlaceKey][v4].LvQuest, true) and task.wait() do
						SSS(GetNearSpawn(BossQuest[currentPlaceKey][v4].Pos.Position))
						DoTween2(BossQuest[currentPlaceKey][v4].Pos)
					end
				end

				while true do
					local v6 = fn5(v5) and task.wait(0.1)
					flag2 = true
					if v6 then
						fn20(v5)
						continue
					end
					break
				end
			end

			fn6(false)
		end

		if not flag2 and getgenv().Setting.BossSniper.Hop then
			MainServerHop(5, "Find New Server [Boss Sniper Hop]")
		end
	end

	handlers3.__PoleHop = function()
		if not Sea1 then
			Travel("Sea1")
		else
			handlers3.Pole()
			MainServerHop(5, "Find New Server [Pole Hop]")
		end
	end

	handlers3.__SaberHop = function(arg)
		if DataSave.Inventory.Saber then
			getgenv().Setting.__SaberHop.Enable = false
			return
		end

		if CheckInvItem("Saber") then
			getgenv().Setting.__SaberHop.Enable = false
			return
		end

		if not Sea1 then
			Travel("Sea1")
		end

		if Sea1 and localPlayer.Data.Level.Value >= 200 and not CheckInvItem("Saber") and not ProgressChecker.Saber.UsedRelic then
			handlers3["Saber Puzzle"](arg or "__SaberHop")
		end

		if Sea1 and GetLevel() >= 200 and not ProgressChecker.Saber.KilledShanks and not CheckInvItem("Saber") and ProgressChecker.Saber.UsedRelic then
			if GetMainEnemy("Saber Expert") then
				handlers3.Saber(arg or "__SaberHop")
			else
				MainServerHop(5, "Find Saber Mob [Saber Hop]")
			end
		end
	end

	handlers3["Get Ghoul"] = function(arg, arg2)
		local str = "Get Ghoul"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if DataSave.Unlocked.Ghoul then
			getgenv().Setting["Get Ghoul"].Enable = false
			return
		end

		if localPlayer.Data.Race.Value == "Ghoul" or game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Ectoplasm", "BuyCheck", 4) == 1 then
			getgenv().Setting["Get Ghoul"].Enable = false
			return
		end

		if not Sea2 then
			print("OK")
			Travel("Sea2")
		end

		if Sea2 and localPlayer.Data.Level.Value then
			pcall(function()
				local cursedCaptain = game.Workspace.Enemies:FindFirstChild("Cursed Captain")

				if fn5(cursedCaptain) then
					while fn5(cursedCaptain) and fn33() and task.wait(0.1) do
						fn20(cursedCaptain)
					end

					task.wait(3)
				end

				if GetMaterial("Ectoplasm") < 100 then
					local flag2 = false

					CheckEctoplasm = RunService.Stepped:Connect(function()
						if GetMaterial("Ectoplasm") >= 100 then
							flag2 = true
						end
					end)

					local function fn34()
						return not flag2 and not fn5(game.Workspace.Enemies:FindFirstChild("Cursed Captain")) and (not force and CasualFarmEmpty() or fn33())
					end

					handlers3.Material("Ectoplasm", arg or "Get Ghoul", fn34)

					if CheckEctoplasm then
						CheckEctoplasm:Disconnect()
						CheckEctoplasm = nil
					end
				end

				if CheckItem("Hellfire Torch") then
					game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Ectoplasm", "Buy", 4)
				end
			end)
		end
	end

	handlers3["Unlock Electric Claw"] = function()
		local response = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyElectricClaw", true)

		if response then
			response = response == 1 or response == 0 or response == 3 or response == 2
		end

		if response then
			DataSave.Unlocked.Electricclaw = true
			return
		end

		while Sea3 and GetLevel() >= 2000 and not DataSave.Unlocked.Electricclaw and wait() do
			TPToEntrance("Mansion")
			DoTween2(CFrame.new(-12547.1396484375, 337.16827392578125, -7471.8818359375))
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyElectricClaw", "Start")
			StatusFarming = "Getting Electric Claw"
		end
	end

	handlers3["Fully Ghoul"] = function(arg, arg2)
		local str = "Fully Ghoul"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if DataSave.Unlocked.Ghoul then
			getgenv().Setting["Fully Ghoul"].Enable = false
			return
		end

		if localPlayer.Data.Race.Value == "Ghoul" or game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Ectoplasm", "BuyCheck", 4) == 1 then
			getgenv().Setting["Fully Ghoul"].Enable = false
			return
		end

		if not Sea2 then
			print("OK")
			Travel("Sea2")
		end

		if Sea2 and localPlayer.Data.Level.Value then
			pcall(function()
				while fn33() and task.wait(0.1) do
					local cursedCaptain = game.Workspace.Enemies:FindFirstChild("Cursed Captain")

					if fn5(cursedCaptain) then
						while fn5(cursedCaptain) and fn33() and task.wait(0.1) do
							fn20(cursedCaptain)
						end

						fn6(false)
						task.wait(3)
					end

					if GetMaterial("Ectoplasm") < 100 then
						local flag2 = false

						CheckEctoplasm = RunService.Stepped:Connect(function()
							if GetMaterial("Ectoplasm") >= 100 then
								flag2 = true
							end
						end)

						local function fn34()
							return not flag2
						end

						handlers3.Material("Ectoplasm", arg or "Fully Ghoul", fn34)

						if CheckEctoplasm then
							CheckEctoplasm:Disconnect()
							CheckEctoplasm = nil
						end

						fn6(false)
					elseif not CheckItem("Hellfire Torch") then
						local cursedCaptain2 = game.Workspace.Enemies:FindFirstChild("Cursed Captain")

						if not fn5(cursedCaptain2) then
							MainServerHop(5, "Finding Cursed Captain [Fully Ghoul]", 1, 3)
						end
					else
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Ectoplasm", "Buy", 4)
					end
				end
			end)
		end
	end

	handlers3.Level = function(arg, arg2)
		local str = "Level"

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable and CasualFarmEmpty() then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		local value = localPlayer.Data.Level.Value

		if Sea3 and fn10() and fn33() and value < 2600 then
			StatusFarming = "Exiting Submerged (Level Farm)"

			if fn11(fn33) then
				task.wait(1)
			end
		end

		if not Increment then
			Increment = 1
		end

		local n2 = 150

		if n2 <= value then
			local n3 = 0

			for k in pairs(tbl2.TripleQuest[currentPlaceKey]) do
				if k >= n3 and k <= value and k ~= nil then
					n3 = k
				end
			end

			if tbl2.TripleQuest[currentPlaceKey][n3] ~= nil then
				local v4 = nil

				for i = 3, 5 do
					if tbl2.TripleQuest[currentPlaceKey][n3][i] then
						if value >= tbl2.TripleQuest[currentPlaceKey][n3][i].Requirement and CheckEnemySpawn(tbl2.TripleQuest[currentPlaceKey][n3][i].QuestCheck) then
							v4 = tbl2.TripleQuest[currentPlaceKey][n3][i]
							break
						else
							v4 = nil
						end
					else
						v4 = nil
					end
				end

				if v4 then
					StatusFarming = "Farming Boss (Triple Quest Method)"

					if not HasActiveQuest(v4.QuestCheck) then
						CancelQuest()
						FixTP(v4.QuestCheck)

						if not HasActiveQuest(v4.QuestCheck) then
							SSS(GetNearSpawn(v4.QuestCFrame.Position), fn33)
							DoTween2(v4.QuestCFrame, fn33)
							if not fn33() then
								return
							end
							local index = v4.Index or 3
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest", v4.Quest, index)
							task.wait(0.3)
						end
					end

					local v5 = GetMainEnemy(v4.QuestCheck)

					if fn5(v5) then
						SSS(GetNearSpawn(fn4(v5).Position), fn33)
						FixTP(v5.Name)

						while Alive() and fn5(v5) and fn33() and task.wait(0.2) do
							if Alive() and fn5(v5) then
								pcall(function()
									FixTP(v5.Name)
									pcall(Equip, GetCurrentTool("Melee", true))
									ResizeBoss(v5, true)
									fn12(v5, Vector3.new(0, 20, 20))
								end)
							end
						end
					end
				else
					if GetSettingHopExploiter() then
						HopNearExploiter()
					end

					local v5 = tbl2.TripleQuest[currentPlaceKey][n3]
					local flag2 = v5 and v5[2]

					if flag2 then
						flag2 = value >= (v5[2].Requirement or math.huge)
					end

					local n4 = 1

					if flag2 then
						n4 = 2
					end

					local questCheck = v5[n4].QuestCheck

					if HasActiveQuest() and not HasActiveQuest(questCheck) then
						CancelQuest()
						task.wait(0.2)
					end

					if not HasActiveQuest(questCheck) then
						FixTP(questCheck)

						while not SafeGetQuest(v5.QuestCFrame, v5.Quest, n4, nil, questCheck) and fn33() and task.wait(0.1) do
							FixTP(questCheck)
							SSS(GetNearSpawn(v5.QuestCFrame.Position), fn33)
							DoTween2(v5.QuestCFrame, fn33)
						end

						if not fn33() then
							return
						end
					end

					local v6 = questCheck
					StatusFarming = "Farming Lv [" .. v6 .. "]"
					local now = tick()

					local function fn34()
						return fn33() and HasActiveQuest(v6)
					end

					local exitTo = nil

					while true do
						if task.wait(0.1) and HasActiveQuest(v6) and fn33() then
							if not Alive() then
								fn6(false)

								while not Alive() do
									task.wait(1)
								end

								task.wait(1.5)

								if getgenv().Setting.AutoBuso and getgenv().Setting.AutoBuso.Enable then
									pcall(function()
										if localPlayer.Character and not localPlayer.Character:FindFirstChild("HasBuso") then
											game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
										end
									end)
								end

								if not HasActiveQuest(v6) then
									exitTo = 1
									break
								else
									continue
								end
							else
								if tick() - now >= 5 then
									if not Alive() then
										fn6(false)
									end

									now = tick()
								end

								local v7 = getNearMob(v6)

								if fn5(v7) then
									local v8 = fn4(v7)

									if v8 and LastMobPosition then
										LastMobPosition[v6] = v8.CFrame
										local match = v7.Name:match("^(.-)%s*%[") or v7.Name
										LastMobPosition[match:match("^%s*(.-)%s*$") or match] = v8.CFrame
									end

									FixTP(v7.Name)

									while true do
										if Alive() and fn5(v7) and fn33() and fn34() and task.wait(0.2) then
											fn20(v7, nil, fn34)
											if not fn19(v7, fn34) then
												continue
											end
										end

										break
									end

									continue
								elseif fn33() then
									FixTP(v6)

									TweenToMobSpawn(v6, 25, function()
										return fn33() and HasActiveQuest(v6) and fn34()
									end)

									task.wait(0.2)
									continue
								end
							end
						else
							exitTo = 1
							break
						end

						break
					end

					if exitTo ~= 1 then
						return
					end
					local value2 = localPlayer.Data.Level.Value

					for k in pairs(tbl2.TripleQuest[currentPlaceKey]) do
						if k >= n3 and k <= value2 then
							n3 = k
						end
					end
				end
			else
				print("Error: Farming Highest " .. n3)
			end
		else
			local str2, cframe11

			if value <= 30 then
				str2 = "Sky Bandit"
				cframe11 = CFrame.new(-5014.0341796875, 280.72146606445312, -972.079345703125)
			else
				str2 = "God's Guard"
				cframe11 = CFrame.new(-4227.2509765625, 1088, -567.60888671875)
			end

			StatusFarming = "Jump Lv Farming [" .. str2 .. "]"

			if Alive() then
				local function fn34()
					return Alive() and fn33() and localPlayer.Data.Level.Value < n2
				end

				local v4 = getNearMob(str2)
				local flag2 = v4 and fn5(v4)

				if flag2 then
					local position = cframe11.Position
					flag2 = (fn4(v4).Position - position).magnitude < 2500
				end

				if flag2 then
					FixTP(v4.Name)
					local position = fn4(v4).Position

					if (fn4(localPlayer.Character).Position - position).magnitude > 50 then
						DoTween2(CFrame.new(position) * CFrame.new(0, 40, 0), fn34)
					end

					while true do
						if Alive() and fn5(v4) and fn34() and task.wait(0.2) then
							fn20(v4, nil, fn34)
							if not fn19(v4, fn34) then
								continue
							end
						end

						break
					end
				else
					local v5 = GetMobSpawnCFrame(str2) or cframe11
					fn6(true)

					DoTween2(v5 + Vector3.new(0, 25, 0), function()
						return fn34() and not fn5(getNearMob(str2))
					end)

					task.wait(0.2)
				end
			end
		end
	end

	handlers3.Bone = function(arg, arg2, arg3)
		local str = "Bone"
		local Bone = getNearMob("Bone")
		local vector = Vector3.new(-9501.345, 172.13985, 6036.034)

		local fn32 = arg2 or function()
			return true
		end

		local function fn33()
			if not arg then
				if getgenv().Setting[str].Enable then
					return true
				end
			elseif getgenv().Setting[arg].Enable and fn32() then
				return true
			end

			return false
		end

		if Sea3 and fn10() and fn33() then
			StatusFarming = "Exiting Submerged (Bone Priority)"

			if fn11(fn33) then
				task.wait(1)
			end
		end

		local now = tick()
		local cframe11 = CFrame.new(-9506.95313, 172.104858, 6074.63086)
		StatusFarming = "Ready To Farm Bone"
		local enable = getgenv().Setting.Mastery.Enable

		if arg3 then
			MakeMasterySkill()

			SkillsController.Condition = function()
				if enable and fn5(Bone) then
					local humanoid = Bone:FindFirstChild("Humanoid")

					if humanoid then
						humanoid = humanoid.Health <= humanoid.MaxHealth * (getgenv().Setting.Mastery.Health and getgenv().Setting.Mastery.Health / 100 or 0.5)
					end

					return humanoid and enable
				end

				return false
			end
		end

		local function fn34()
			local flag2 = fn5(Bone) and fn9(Bone, Vector3.new(-9501.345, 172.13985, 6036.034)) <= 2000

			if flag2 then
				local y = vector.Y
				flag2 = math.abs(fn4(Bone).Position.Y - y) <= 200
			end

			return flag2
		end

		while true do
			if fn33() and task.wait(0.1) then
				if not Alive() then
					fn6(false)

					while not Alive() do
						task.wait(1)
					end

					task.wait(1.5)

					if getgenv().Setting.AutoBuso and getgenv().Setting.AutoBuso.Enable then
						pcall(function()
							if localPlayer.Character and not localPlayer.Character:FindFirstChild("HasBuso") then
								game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
							end
						end)
					end

					continue
				else
					if enable then
						getgenv().MasteringWeapon = true
					end

					StatusFarming = "Farming Bone"
					SSS(GetNearSpawn(cframe11.Position))

					if getgenv().Setting.AcceptQuest_Bone_Katakuri.Enable and localPlayer.Data.Level.Value >= 2050 and (localPlayer.PlayerGui.Main.Quest.Visible == false or not string.find(localPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, "Posessed Mummy")) then
						if Alive() then
							while getgenv().Setting.AcceptQuest_Bone_Katakuri.Enable and not SafeGetQuest(cframe11, "HauntedQuest2", 2, true) and task.wait(0.5) do
								DoTween2(cframe11)
							end

							fn6(false)
						end
					end

					if GetSettingHopExploiter() then
						HopNearExploiter()
					end

					if tick() - now >= 5 then
						if not TweeningV2 then
							fn6(false)
						end

						now = tick()
					end

					if fn5(Bone) and Alive() then
						fn20(Bone, arg3, fn34)

						if not arg3 then
							if fn19(Bone, fn33) then
								fn6(false)
								break
							else
								continue
							end
						else
							continue
						end
					else
						fn6(false)
						Bone = getNearMob("Bone")

						if not fn5(Bone) then
							SSS(GetNearSpawn(Vector3.new(-9501.345, 172.13985, 6036.034)))
							DoTween2(CFrame.new(Vector3.new(-9501.345, 172.13985, 6036.034)))
							fn6(false)
						end

						continue
					end
				end
			end

			break
		end

		if arg3 then
			getgenv().MasteringWeapon = false
			VoidSkillController()
		end

		if localPlayer.CameraMaxZoomDistance <= 1 then
			localPlayer.CameraMaxZoomDistance = 200
			localPlayer.CameraMinZoomDistance = 100
			localPlayer.CameraMinZoomDistance = 0
		end

		fn6(false)
	end

	fn21 = function()
		while task.wait(0.7) do
			for _, v4 in pairs(tbl11) do
				if getgenv().OneClickSetting then
					if v4 == "Pole" and not getgenv().OneClickSetting.FarmPole then
						continue
					end

					if v4 == "Items Farm Force" and not getgenv().OneClickSetting.FarmItems then
						continue
					end

					if v4 == "Tushita Hop" and not getgenv().OneClickSetting.HopTushita then
						continue
					end

					if (v4 == "Soul Guitar" or v4 == "Material Soul Guitar") and getgenv().OneClickSetting.DisableSoulGuitar then
						continue
					end

					if v4 == "CDK" and getgenv().OneClickSetting.DisableCDK then
						continue
					end

					if v4 == "Race Evolve" and getgenv().OneClickSetting.DisableRaceEvolve then
						continue
					end
				end

				if handlers2[v4] then
					if not tbl10[v4] then
						local ok, result = pcall(function()
							return handlers2[v4]()
						end)

						if ok and result then
							print("Added state: ", v4)
							tbl10[v4] = true
							WorkingFarm:put(v4, tbl12[v4])
						end
					end
				end
			end
		end
	end
end

task.spawn(function()
	while task.wait(1) do
		if not DataSave.Unlocked.SoulGuitar and localPlayer.Data.Level.Value >= 2300 and not Sea1 then
			if not DataSave.Unlocked.SoulGuitar then
				GuitarProgress()
			end
		end
	end
end)

do
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HttpService = game:GetService("HttpService")
	local str = "Oneclick/MeleeData" .. "/" .. localPlayer.Name .. ".json"
	local v4 = nil
	local v5 = nil
	local v6 = nil

	local ok, result = pcall(function()
		return require(game:GetService("ReplicatedStorage").Controllers.UI.Inventory)
	end)

	local ok2, result2 = pcall(function()
		return require(game:GetService("ReplicatedStorage").ItemConfig)
	end)

	local ok3, result3 = pcall(function()
		return require(game:GetService("ReplicatedStorage").Util.ItemReplication)
	end)

	if ok then
		v4 = result
	end

	if ok2 then
		v5 = result2
	end

	if ok3 then
		v6 = result3
	end

	local function fn22(arg)
		if not v4 or not v5 or not v6 then
			return false, arg, nil
		end

		local ok4, result4 = pcall(function()
			return v4:GetIfInitialized()
		end)

		if not ok4 or not result4 then
			return false, arg, nil
		end

		local ok5, result5 = pcall(function()
			return v4:GetTiles()
		end)

		if not ok5 or not result5 then
			return false, arg, nil
		end

		for _, v7 in ipairs(result5) do
			local ok6, result6 = pcall(function()
				return v5.match(v7.ItemId):asNullable()
			end)

			if ok6 and result6 and result6.Moveset and result6.Moveset.Type == "FightingStyle" and result6.Index and result6.Index.StorageKey == arg then
				local ok7, result7 = pcall(function()
					return v6.Mastery.readClient(v7.ItemId, v7.NetworkedUID)
				end)

				return true, arg, ok7 and result7 or nil
			end
		end

		return false, arg, nil
	end

	local tbl9 = {
		["Black Leg"] = { "Black Leg", "Dark Step" },
		Electro = { "Electro" },
		["Fishman Karate"] = { "Fishman Karate", "Water Kung Fu" },
		["Dragon Claw"] = { "Dragon Claw", "Dragon Breath", "DragonClaw" },
		Superhuman = { "Superhuman" },
		["Death Step"] = { "Death Step" },
		["Sharkman Karate"] = { "Sharkman Karate" },
		["Electric Claw"] = { "Electric Claw" },
		["Dragon Talon"] = { "Dragon Talon", "Dragon Talon" },
		["Dragon Talon"] = { "Dragon Talon", "Dragon Talon" },
		Godhuman = { "Godhuman", "God Human" },
		["God Human"] = { "Godhuman", "God Human" },
		SanguineArt = { "SanguineArt", "Sanguine Art" },
		["Sanguine Art"] = { "SanguineArt", "Sanguine Art" },
	}

	local function fn23(arg)
		local v7, v8, v9 = fn22(arg)
		if v7 then
			return v7, v8, v9
		end
		local v10 = tbl9[arg]

		if v10 then
			for _, v11 in ipairs(v10) do
				local v12, v13, v14 = fn22(v11)
				if v12 then
					return v12, v11, v14
				end
			end
		end

		return false, arg, nil
	end

	local tbl10 = {
		BlackLeg = {
			Sea1 = Vector3.new(-985.919, 13.782, 3989.196),
			Sea2 = Vector3.new(-4754.082, 35.072, -4846.347),
			Sea3 = Vector3.new(-5046.673, 371.554, -3181.369),
		},
		Electro = {
			Sea1 = Vector3.new(-5386.988, 13.553, -2146.912),
			Sea2 = Vector3.new(-4867.061, 35.072, -4764.177),
			Sea3 = Vector3.new(-4992.725, 314.546, -3197.635),
		},
		FishmanKarate = {
			Sea1 = Vector3.new(61580.652, 18.901, 985.204),
			Sea2 = Vector3.new(-4957.67, 35.071, -4665.6),
			Sea3 = Vector3.new(-5023.662, 371.343, -3192.383),
		},
		DragonClaw = {
			Sea2 = Vector3.new(-4983.763, 371.343, -3207.528),
			Sea3 = Vector3.new(-4983.763, 371.343, -3207.528),
		},
		Superhuman = {
			Sea2 = Vector3.new(1378.382, 247.458, -5191.358),
			Sea3 = Vector3.new(-5004.467, 371.343, -3196.912),
		},
		DeathStep = {
			Sea2 = Vector3.new(6356.018, 297.667, -6761.593),
			Sea3 = Vector3.new(-4995.035, 314.546, -3222.354),
		},
		SharkmanKarate = {
			Sea2 = Vector3.new(-2600.607, 238.877, -10314.496),
			Sea3 = Vector3.new(-4972.77, 314.546, -3219.336),
		},
		ElectricClaw = { Sea3 = Vector3.new(-10371.693, 331.684, -10127.267) },
		DragonTalon = { Sea3 = Vector3.new(5663.318, 1211.308, 865.413) },
		Godhuman = { Sea3 = Vector3.new(-13775.168, 334.652, -9882.374) },
	}

	local function fn24()
		if rawget(env, "Sea1") or Sea1 or game.PlaceId == 2753915549 or game.PlaceId == 85211729168715 then
			return "Sea1"
		end

		if rawget(env, "Sea2") or Sea2 or game.PlaceId == 4442272183 or game.PlaceId == 79091703265657 then
			return "Sea2"
		end

		if rawget(env, "Sea3") or Sea3 or game.PlaceId == 7449423635 or game.PlaceId == 100117331123089 then
			return "Sea3"
		end
		return "Sea3"
	end

	local function fn25(arg, arg2)
		if arg2 and type(fn13) == "function" then
			local v7 = fn13(arg2)

			if v7 and type(fn8) == "function" then
				local v8 = fn8(v7)
				if v8 then
					return v8
				end
			end
		end

		if arg2 and workspace:FindFirstChild("NPCs") then
			local v7 = workspace.NPCs:FindFirstChild(arg2)
			if v7 and v7:FindFirstChild("HumanoidRootPart") then
				return v7.HumanoidRootPart.Position
			end
		end

		local v7 = fn24()
		local v8 = string.gsub(tostring(arg), "%s+", "")
		local v9 = tbl10[v8] or tbl10[arg]
		local v10

		if not v9 then
			for k, v11 in pairs(tbl10) do
				if string.lower(k) == string.lower(v8) or string.lower(k) == string.lower(arg) then
					v9 = v11
					break
				end
			end

			v10 = v9
		else
			v10 = v9
		end

		if type(v10) == "table" then
			local v11 = v10[v7]
			if v11 then
				return v11
			end
			return nil
		end

		return nil
	end

	local tbl11 = {
		["Black Leg"] = { NPC = "Dark Step Teacher", Remote = "BuyBlackLeg", ToolName = "Black Leg" },
		Electro = { NPC = "Mad Scientist", Remote = "BuyElectro", ToolName = "Electro" },
		["Fishman Karate"] = { NPC = "Water Kung Fu Teacher", Remote = "BuyFishmanKarate", ToolName = "Fishman Karate" },
		["Dragon Claw"] = { NPC = "Sabi", Remote = "BlackbeardReward", ToolName = "Dragon Claw" },
		Superhuman = { NPC = "Martial Arts Master", Remote = "BuySuperhuman", ToolName = "Superhuman" },
		["Death Step"] = { NPC = "Phoeyu, the Reformed", Remote = "BuyDeathStep", ToolName = "Death Step" },
		["Sharkman Karate"] = { NPC = "Sharkman Teacher", Remote = "BuySharkmanKarate", ToolName = "Sharkman Karate" },
		["Electric Claw"] = { NPC = "Previous Hero", Remote = "BuyElectricClaw", ToolName = "Electric Claw" },
		["Dragon Talon"] = { NPC = "Uzoth", Remote = "BuyDragonTalon", ToolName = "Dragon Talon" },
		["Dragon Talon"] = { NPC = "Uzoth", Remote = "BuyDragonTalon", ToolName = "Dragon Talon" },
		Godhuman = { NPC = "Ancient Monk", Remote = "BuyGodhuman", ToolName = "Godhuman" },
		["God Human"] = { NPC = "Ancient Monk", Remote = "BuyGodhuman", ToolName = "Godhuman" },
		SanguineArt = { NPC = "Shafi", Remote = "BuySanguineArt", ToolName = "SanguineArt" },
		["Sanguine Art"] = { NPC = "Shafi", Remote = "BuySanguineArt", ToolName = "SanguineArt" },
	}

	local tbl12 = {
		["Black Leg"] = { MinLevel = 1, MinBeli = 150000 },
		Electro = { MinLevel = 1, MinBeli = 500000 },
		["Fishman Karate"] = { MinLevel = 1, MinBeli = 750000 },
		["Dragon Claw"] = { MinLevel = 700, MinBeli = 0, MinFragments = 1500 },
		Superhuman = { MinLevel = 1100, MinBeli = 3000000 },
		["Death Step"] = { MinLevel = 700, MinBeli = 2500000, MinFragments = 5000, NeedUnlock = "Deathstep" },
		["Sharkman Karate"] = { MinLevel = 700, MinBeli = 2500000, MinFragments = 5000, NeedUnlock = "Sharkman" },
		["Electric Claw"] = { MinLevel = 2000, MinBeli = 3000000, MinFragments = 5000, NeedUnlock = "Electricclaw" },
		["Dragon Talon"] = { MinLevel = 1500, MinBeli = 3000000, MinFragments = 5000, NeedUnlock = "Dragontalon" },
		["God Human"] = { MinLevel = 1500, MinBeli = 5000000, MinFragments = 5000 },
	}

	local tbl13 = { "Superhuman", "Death Step", "Sharkman Karate", "Electric Claw", "Dragon Talon" }
	getgenv().MeleeNPCBusy = false

	local function fn26()
		pcall(function()
			if not isfolder("Oneclick/MeleeData") then
				makefolder("Oneclick/MeleeData")
			end

			writefile(str, HttpService:JSONEncode({ Melee = DataSave.Melee, Unlocked = DataSave.Unlocked }))
		end)
	end

	local function fn27()
		pcall(function()
			if isfile(str) then
				local ok4, result4 = pcall(function()
					return HttpService:JSONDecode(readfile(str))
				end)

				if not ok4 or not result4 then
					return
				end

				if result4.Melee then
					for k, v7 in pairs(result4.Melee) do
						if DataSave.Melee[k] then
							for k2, v8 in pairs(v7) do
								DataSave.Melee[k][k2] = v8
							end
						end
					end
				end

				if result4.Unlocked then
					for k, v7 in pairs(result4.Unlocked) do
						DataSave.Unlocked[k] = v7
					end
				end

				print("[MeleeV2] Dados carregados do disco.")
			end
		end)
	end

	local function fn28(arg)
		if not arg or arg == "" then
			return nil
		end
		local character = localPlayer.Character
		local backpack = localPlayer:FindFirstChild("Backpack")
		if character and character:FindFirstChild(arg) then
			return character:FindFirstChild(arg)
		end

		if backpack and backpack:FindFirstChild(arg) then
			return backpack:FindFirstChild(arg)
		end
		local tbl14 = type(MeleeToolAliases) == "table" and MeleeToolAliases[arg] or { arg }

		for _, v7 in ipairs(tbl14) do
			if character and character:FindFirstChild(v7) then
				return character:FindFirstChild(v7)
			end

			if backpack and backpack:FindFirstChild(v7) then
				return backpack:FindFirstChild(v7)
			end
		end

		return nil
	end

	local function fn29(arg)
		if not arg or arg == "" then
			return nil
		end
		local v7, v8, v9 = fn23(arg)
		if v7 and v9 then
			return v9
		end
		local v10 = fn28(arg)
		if v10 and v10:FindFirstChild("Level") then
			return tonumber(v10.Level.Value) or 0
		end
		return nil
	end

	_CanAffordStyle = function(arg)
		local v7 = tbl12[arg]
		if not v7 then
			return true
		end

		if localPlayer.Data.Level.Value < v7.MinLevel then
			return false
		end

		if localPlayer.Data.Beli.Value < v7.MinBeli then
			return false
		end

		if v7.MinFragments and localPlayer.Data.Fragments.Value < v7.MinFragments then
			return false
		end

		if v7.NeedUnlock and not DataSave.Unlocked[v7.NeedUnlock] then
			return false
		end
		return true
	end

	local function fn30(arg)
		if not arg or arg == "" then
			return false
		end
		local character = localPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local backpack = localPlayer:FindFirstChild("Backpack")
		if not (character and humanoid) then
			return false
		end
		local v7 = character:FindFirstChild(arg)
		if v7 and v7:IsA("Tool") then
			return true
		end
		local tbl14 = type(MeleeToolAliases) == "table" and MeleeToolAliases[arg] or { arg }

		for _, v8 in ipairs(tbl14) do
			local v9 = character:FindFirstChild(v8)
			if v9 and v9:IsA("Tool") then
				return true
			end
		end

		if backpack then
			local v8 = backpack:FindFirstChild(arg)

			if not v8 then
				for _, v9 in ipairs(tbl14) do
					v8 = backpack:FindFirstChild(v9)
					if not v8 then
						continue
					end
					break
				end
			end

			if v8 and v8:IsA("Tool") then
				pcall(function()
					humanoid:EquipTool(v8)
				end)

				task.wait(0.3)
				local v9 = character:FindFirstChild(v8.Name)
				if v9 and v9:IsA("Tool") then
					return true
				end
			end
		end

		return false
	end

	local function fn31(arg)
		local v7 = tbl11[arg]
		if not v7 then
			return false
		end
		getgenv().MeleeNPCBusy = true
		local toolName = v7.ToolName or arg
		local flag2 = false

		local ok4, result4 = pcall(function()
			for i = 1, 10 do
				if fn30(toolName) then
					flag2 = true
					break
				else
					StatusFarming2 = "Buying Melee [" .. tostring(arg) .. "] (Time " .. i .. ")"
					local v8 = fn25(arg, v7.NPC)

					if not v8 then
						task.wait(0.8)
					else
						local cframe3 = CFrame.new(v8 + Vector3.new(0, 2, 3))
						local humanoidRootPart = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")

						if (humanoidRootPart and (humanoidRootPart.Position - v8).Magnitude or 999) >= 15 then
							DoTween2(cframe3, function()
								local humanoidRootPart2 = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
								if not humanoidRootPart2 then
									return false
								end
								return (humanoidRootPart2.Position - v8).Magnitude >= 15
							end, nil, { NoTweenPause = true, Speed = 150 })
						end

						local humanoidRootPart2 = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")

						if (humanoidRootPart2 and (humanoidRootPart2.Position - v8).Magnitude or 999) < 15 then
							for i2 = 1, 3 do
								pcall(function()
									if arg == "Dragon Claw" or v7.Remote == "BlackbeardReward" then
										ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "2")
									elseif arg == "Godhuman" or arg == "God Human" then
										ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyGodhuman", true)
										task.wait(0.25)
										ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyGodhuman")
									elseif arg == "Dragon Talon" or arg == "Dragon Talon" then
										ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyDragonTalon", true)
										task.wait(0.25)
										ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyDragonTalon")
									elseif type(v7.Remote) == "string" then
										ReplicatedStorage.Remotes.CommF_:InvokeServer(v7.Remote)
									end
								end)

								task.wait(0.4)

								if fn30(toolName) then
									flag2 = true
									break
								elseif fn23(arg) then
									task.wait(0.3)
									fn30(toolName)
									flag2 = true
									break
								end
							end
						end

						if flag2 then
							DataSave.Melee[arg] = DataSave.Melee[arg] or {}
							DataSave.Melee[arg].Have = true

							if DataSave.Melee[toolName] then
								DataSave.Melee[toolName].Have = true
							end

							local v9, v10, v11 = fn23(arg)

							if v9 and v11 and v11 >= 400 then
								DataSave.Melee[arg].Mas400 = true

								if DataSave.Melee[toolName] then
									DataSave.Melee[toolName].Mas400 = true
								end
							end

							fn26()
							break
						else
							task.wait(0.5)
						end
					end
				end
			end
		end)

		if not ok4 and result4 then
			warn("[_TravelAndBuyMelee Error]:", result4)
		end

		getgenv().MeleeNPCBusy = false
		return flag2
	end

	local function fn32()
		for _, v7 in pairs({
			{ remote = "BuyBlackLeg", key = "Black Leg" },
			{ remote = "BuyElectro", key = "Electro" },
			{ remote = "BuyFishmanKarate", key = "Fishman Karate" },
			{ remote = "BuySuperhuman", key = "Superhuman" },
			{ remote = "BuyDeathStep", key = "Death Step" },
			{ remote = "BuySharkmanKarate", key = "Sharkman Karate" },
			{ remote = "BuyElectricClaw", key = "Electric Claw" },
			{ remote = "BuyDragonTalon", key = "Dragon Talon" },
			{ remote = "BuyGodhuman", key = "God Human" },
		}) do
			local ok4, result4 = pcall(function()
				return ReplicatedStorage.Remotes.CommF_:InvokeServer(v7.remote, true)
			end)

			if ok4 and result4 == 1 then
				if DataSave.Melee[v7.key] then
					DataSave.Melee[v7.key].Have = true
				end

				if v7.key == "God Human" then
					DataSave.Unlocked.GodHuman = true
				end
			end

			task.wait(0.2)
		end

		local ok4, result4 = pcall(function()
			return ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "1")
		end)

		if ok4 and result4 == 1 then
			DataSave.Melee.DragonClaw.Have = true
		end

		for _, v7 in pairs({
			"Black Leg",
			"Electro",
			"Fishman Karate",
			"Dragon Claw",
			"Superhuman",
			"Death Step",
			"Sharkman Karate",
			"Electric Claw",
			"Dragon Talon",
			"Dragon Talon",
			"Godhuman",
			"God Human",
			"SanguineArt",
		}) do
			if not DataSave.Melee[v7] then
				DataSave.Melee[v7] = { Have = false, Mas400 = false, Mas600 = false }
			end

			local v8, v9, v10 = fn23(v7)

			if v8 then
				DataSave.Melee[v7].Have = true

				if v10 and v10 >= 400 then
					DataSave.Melee[v7].Mas400 = true
				end
			end
		end

		fn26()
		print("[MeleeV2] Detect styles done (with checkdatamelee sync).")
	end

	local tbl14 = { "Black Leg", "Electro", "Fishman Karate", "Dragon Claw" }

	local function fn33()
		for _, v7 in pairs(tbl14) do
			local mas400 = DataSave.Melee[v7] and DataSave.Melee[v7].Mas400

			if v7 == "Dragon Claw" and not mas400 then
				mas400 = DataSave.Melee.DragonClaw and DataSave.Melee.DragonClaw.Mas400
			end

			if not mas400 then
				local v8, v9, v10 = fn23(v7)

				if v8 and v10 and v10 >= 400 then
					DataSave.Melee[v7] = DataSave.Melee[v7] or {}
					DataSave.Melee[v7].Have = true
					DataSave.Melee[v7].Mas400 = true

					if v7 == "Dragon Claw" and DataSave.Melee.DragonClaw then
						DataSave.Melee.DragonClaw.Have = true
						DataSave.Melee.DragonClaw.Mas400 = true
					end

					mas400 = true
				end
			end

			if not mas400 then
				return false, v7
			end
		end

		return true, nil
	end

	local function fn34()
		for _, v7 in pairs(tbl13) do
			local mas400 = DataSave.Melee[v7] and DataSave.Melee[v7].Mas400

			if not mas400 then
				local v8, v9, v10 = fn23(v7)

				if v8 and v10 and v10 >= 400 then
					DataSave.Melee[v7] = DataSave.Melee[v7] or {}
					DataSave.Melee[v7].Have = true
					DataSave.Melee[v7].Mas400 = true
					mas400 = true
				end
			end

			if not mas400 then
				return false, v7
			end
		end

		return true, nil
	end

	spawn(function()
		task.wait(4)
		fn27()
		fn32()

		while true do
			task.wait(1)
			local value = localPlayer.Data.Level.Value

			if getgenv().Setting.OneClick.Enable and DataSave.Melee.Electro.Have then
				for _, ability in pairs(tbl2.Items[1].Abilities) do
					if ability.Price.Beli <= localPlayer.Data.Beli.Value then
						pcall(function()
							if not game:GetService("CollectionService"):HasTag(localPlayer.Character, ability.Name) then
								if not (ability.Name == "Ken" and value >= 300 and CheckInvItem("Saber")) then
								end

								ReplicatedStorage.Remotes.CommF_:InvokeServer(unpack(ability.Args))
							end
						end)
					end
				end
			end

			if value >= 1100 then
				if not DataSave.Melee.DragonClaw.Have then
					local ok4, result4 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "1")
					end)

					if ok4 and result4 == 1 then
						DataSave.Melee.DragonClaw.Have = true
						fn26()
					end
				end

				if not DataSave.Melee.Superhuman.Have then
					local ok4, result4 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("BuySuperhuman", true)
					end)

					if ok4 and result4 == 1 then
						DataSave.Melee.Superhuman.Have = true
						fn26()
					end
				end

				if not DataSave.Melee["Sharkman Karate"].Have then
					local ok4, result4 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("BuySharkmanKarate", true)
					end)

					if ok4 and result4 == 1 then
						DataSave.Melee["Sharkman Karate"].Have = true
						fn26()
					end
				end

				if not DataSave.Melee["Death Step"].Have then
					local ok4, result4 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyDeathStep", true)
					end)

					if ok4 and result4 == 1 then
						DataSave.Melee["Death Step"].Have = true
						fn26()
					end
				end
			end

			if value >= 1500 then
				if not DataSave.Unlocked.Electricclaw then
					local ok4, result4 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyElectricClaw", true)
					end)

					ok4 = ok4 and result4
					local flag2

					if ok4 then
						flag2 = result4 == 1 or result4 == 0 or result4 == 2 or result4 == 3
					else
						flag2 = ok4
					end

					if flag2 then
						DataSave.Unlocked.Electricclaw = true
						fn26()
					end
				end

				if not DataSave.Melee["Electric Claw"].Have then
					local ok4, result4 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyElectricClaw", true)
					end)

					if ok4 and result4 == 1 then
						DataSave.Melee["Electric Claw"].Have = true
						fn26()
					end
				end

				if not DataSave.Unlocked.Dragontalon then
					local ok4, result4 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyDragonTalon", true)
					end)

					if ok4 and result4 and result4 ~= "Set your heart ablaze." then
						DataSave.Unlocked.Dragontalon = true
						fn26()
					end
				end

				if not DataSave.Melee["Dragon Talon"].Have then
					local ok4, result4 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyDragonTalon", true)
					end)

					if ok4 and result4 == 1 then
						DataSave.Melee["Dragon Talon"].Have = true
						fn26()
					end
				end

				if not DataSave.Unlocked.GodHuman then
					if CheckGodhumanMaterialStatus().owned then
						DataSave.Unlocked.GodHuman = true
						DataSave.Melee["God Human"].Have = true
						fn26()
					end
				end
			end

			if value >= 700 then
				if not DataSave.Unlocked.Deathstep then
					local ok4, result4 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("OpenLibrary")
					end)

					if ok4 and result4 == true or DataSave.Melee["Death Step"].Have then
						DataSave.Unlocked.Deathstep = true
					end

					local ok5, result5 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyDeathStep", true)
					end)

					if ok5 and result5 and (result5 == 1 or result5 == 2) then
						DataSave.Unlocked.Deathstep = true
						fn26()
					end

					if CheckItem("Library Key") then
						pcall(function()
							ReplicatedStorage.Remotes.CommF_:InvokeServer("OpenLibrary")
						end)
					end
				end

				if not DataSave.Unlocked.Sharkman then
					local ok4, result4 = pcall(function()
						return ReplicatedStorage.Remotes.CommF_:InvokeServer("BuySharkmanKarate", true)
					end)

					ok4 = ok4 and result4

					if ok4 then
						ok4 = result4 == 0 or result4 == 1 or result4 == 2 or result4 == 3
					end

					if ok4 then
						DataSave.Unlocked.Sharkman = true
						fn26()
					end

					if CheckItem("Water Key") then
						pcall(function()
							ReplicatedStorage.Remotes.CommF_:InvokeServer("BuySharkmanKarate", true)
						end)
					end
				end
			end

			if DataSave.Unlocked.SoulGuitar and not CheckInvItem("Skull Guitar") then
				if RequirementGuitar["1"] and RequirementGuitar["2"] and GetMaterial("Dark Fragment") >= 1 then
					pcall(function()
						ReplicatedStorage.Remotes.CommF_:InvokeServer("soulGuitarBuy")
					end)
				end
			end

			if DataSave.TTK.Shisui and DataSave.TTK.Wando and DataSave.TTK.Saddi and localPlayer.Data.Beli.Value >= 2000000 then
				pcall(function()
					ReplicatedStorage.Remotes.CommF_:InvokeServer("MysteriousMan", "2")
				end)
			end

			if Sea2 then
				if CheckItem("Hidden Key") and not CheckInvItem("Rengoku") then
					pcall(function()
						ReplicatedStorage.Remotes.CommF_:InvokeServer("OpenRengoku")
					end)
				end
			end
		end
	end)

	spawn(function()
		task.wait(7)
		fn27()

		while task.wait(0.2) do
			if not getgenv().Setting.OneClick.Enable then
				StatusFarming2 = nil
			elseif getgenv().Setting.OneClick.DisableMeleeSwitcher then
				StatusFarming2 = nil
			elseif getgenv().MeleeNPCBusy then
				task.wait(1)
			elseif not WorkingFarm:empty() then
				StatusFarming2 = nil
				task.wait(2)
			else
				local Godhuman, v7, v8 = fn23("Godhuman")

				if not Godhuman then
					local v9
					Godhuman, v9, v8 = fn23("God Human")
				end

				if not Godhuman then
					if fn28("Godhuman") or fn28("God Human") then
						Godhuman = true
					end
				end

				if not Godhuman then
					DataSave.Unlocked.GodHuman = false

					if DataSave.Melee["God Human"] then
						DataSave.Melee["God Human"].Have = false
						DataSave.Melee["God Human"].Mas400 = false
					end

					if DataSave.Melee.Godhuman then
						DataSave.Melee.Godhuman.Have = false
						DataSave.Melee.Godhuman.Mas400 = false
					end
				else
					DataSave.Unlocked.GodHuman = true
					DataSave.Melee["God Human"] = DataSave.Melee["God Human"] or {}
					DataSave.Melee["God Human"].Have = true

					if v8 and v8 >= 400 then
						DataSave.Melee["God Human"].Mas400 = true
					end
				end

				if Godhuman and DataSave.Melee["God Human"] and DataSave.Melee["God Human"].Mas400 then
					StatusFarming2 = "Finished"
				else
					local value = localPlayer.Data.Level.Value

					local function fn35(arg, arg2)
						local v9 = tbl11[arg]
						if not v9 then
							return
						end
						local toolName = v9.ToolName or arg
						local have, v10, v11 = fn23(arg)

						if not have and toolName ~= arg then
							local v12
							have, v12, v11 = fn23(toolName)
						end

						if not have then
							local have2 = DataSave.Melee[arg] and DataSave.Melee[arg].Have

							if have2 then
								have = have2
							else
								have = DataSave.Melee[toolName] and DataSave.Melee[toolName].Have
							end
						end

						if have then
							if not fn30(toolName) then
								pcall(function()
									Equip(toolName)
								end)
							end

							if not v11 then
								local v12, v13, v14 = fn23(arg)

								if not v14 and toolName ~= arg then
									local v15, v16
									v15, v16, v11 = fn23(toolName)
								else
									v11 = v14
								end
							end

							v11 = v11 or fn29(toolName)

							if v11 then
								StatusFarming2 = arg2 .. " [Mas:" .. math.floor(v11) .. "/400]"
							else
								StatusFarming2 = arg2
							end

							if v11 and v11 >= 400 then
								DataSave.Melee[arg] = DataSave.Melee[arg] or {}
								DataSave.Melee[arg].Have = true
								DataSave.Melee[arg].Mas400 = true

								if DataSave.Melee[toolName] then
									DataSave.Melee[toolName].Have = true
									DataSave.Melee[toolName].Mas400 = true
								end

								if arg == "Dragon Claw" and DataSave.Melee.DragonClaw then
									DataSave.Melee.DragonClaw.Have = true
									DataSave.Melee.DragonClaw.Mas400 = true
								end

								fn26()
							end

							return
						end

						if not have then
							if not _CanAffordStyle(arg) then
								local v12 = tbl12[arg]

								if v12 then
									local tbl15 = {}

									if localPlayer.Data.Beli.Value < (v12.MinBeli or 0) then
										table.insert(tbl15, math.floor(v12.MinBeli - localPlayer.Data.Beli.Value) .. " Beli")
									end

									if v12.MinFragments and localPlayer.Data.Fragments.Value < v12.MinFragments then
										table.insert(tbl15, math.floor(v12.MinFragments - localPlayer.Data.Fragments.Value) .. " Fragments")
									end

									if localPlayer.Data.Level.Value < (v12.MinLevel or 1) then
										table.insert(tbl15, "Level " .. v12.MinLevel)
									end

									if v12.NeedUnlock and not DataSave.Unlocked[v12.NeedUnlock] then
										table.insert(tbl15, "unlock " .. arg)
									end

									StatusFarming2 = "Don't Have" .. arg .. ": " .. table.concat(tbl15, ", ")
								end

								return
							end

							if not fn31(arg) then
								return
							end

							if not fn23(arg) and toolName ~= arg then
								fn23(toolName)
							end
						end
					end

					if not (DataSave.Melee["Black Leg"] and DataSave.Melee["Black Leg"].Mas400) or DataSave.Melee["Black Leg"] and not DataSave.Melee["Black Leg"].Have and _CanAffordStyle("Black Leg") then
						fn35("Black Leg", "Farm Black Leg To Mas 400")
					elseif not (DataSave.Melee.Electro and DataSave.Melee.Electro.Mas400) then
						fn35("Electro", "Farm Electro To Mas 400")
					elseif not (DataSave.Melee["Fishman Karate"] and DataSave.Melee["Fishman Karate"].Mas400) then
						fn35("Fishman Karate", "Farm Fishman Karate To Mas 400")
					elseif value >= 1100 then
						if not (DataSave.Melee["Dragon Claw"] and DataSave.Melee["Dragon Claw"].Mas400 or DataSave.Melee.DragonClaw and DataSave.Melee.DragonClaw.Mas400) then
							fn35("Dragon Claw", "Farm Dragon Claw To Mas 400")
						elseif not (DataSave.Melee.Superhuman and DataSave.Melee.Superhuman.Mas400) then
							local v9, v10 = fn33()

							if not v9 and v10 then
								StatusFarming2 = "Need" .. tostring(v10) .. " >= 400 Mas for buy Superhuman"
								fn35(v10, "Farm " .. tostring(v10) .. " To Mas 400 (Superhuman Req)")
							else
								fn35("Superhuman", "Farm Superhuman To Mas 400")
							end
						elseif not (DataSave.Melee["Death Step"] and DataSave.Melee["Death Step"].Mas400) then
							fn35("Death Step", "Farm Death Step To Mas 400")
						elseif not (DataSave.Melee["Sharkman Karate"] and DataSave.Melee["Sharkman Karate"].Mas400) then
							fn35("Sharkman Karate", "Farm Sharkman Karate To Mas 400")
						elseif not (DataSave.Melee["Electric Claw"] and DataSave.Melee["Electric Claw"].Mas400) then
							fn35("Electric Claw", "Farm Electric Claw To Mas 400")
						elseif not (DataSave.Melee["Dragon Talon"] and DataSave.Melee["Dragon Talon"].Mas400 or DataSave.Melee["Dragon Talon"] and DataSave.Melee["Dragon Talon"].Mas400) then
							fn35("Dragon Talon", "Farm Dragon Talon To Mas 400")
						elseif not Godhuman then
							if fn34() then
								local v9 = CheckGodhumanMaterialStatus()

								if v9.owned then
									DataSave.Unlocked.GodHuman = true
									DataSave.Melee["God Human"] = DataSave.Melee["God Human"] or {}
									DataSave.Melee["God Human"].Have = true
									fn26()
									fn35("Godhuman", "Farm Godhuman To Mas 400")
								elseif v9.ready or localPlayer.Data.Beli.Value >= 5000000 and localPlayer.Data.Fragments.Value >= 5000 then
									StatusFarming2 = "God Human: Buying from Ancient Monk..."

									if fn31("Godhuman") then
										DataSave.Unlocked.GodHuman = true
										DataSave.Melee["God Human"] = DataSave.Melee["God Human"] or {}
										DataSave.Melee["God Human"].Have = true
										fn26()
										fn35("Godhuman", "Farm Godhuman To Mas 400")
									end
								else
									StatusFarming2 = "God Human: " .. tostring(v9.message)
								end
							else
								StatusFarming2 = "Verificando maestria para God Human"

								for _, v9 in pairs(tbl13) do
									if not (DataSave.Melee[v9] and DataSave.Melee[v9].Mas400) then
										fn35(v9, "Farm " .. v9 .. " To Mas 400 (God Human)")
										break
									end
								end
							end
						elseif not (DataSave.Melee["God Human"] and DataSave.Melee["God Human"].Mas400) then
							fn35("Godhuman", "Farm Godhuman To Mas 400")
						else
							StatusFarming2 = "Finished"
						end
					else
						StatusFarming2 = nil
					end
				end
			end
		end
	end)
end

u1 = 0

game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DisableKen").OnClientEvent:Connect(function()
	u1 = tick() + 5
	ObservationManager.SetActive(false)
end)

if Sea2 or Sea3 then
	local tbl9 = { "WaterBeam", "Angry", "BiteAttack", "SubMerge" }

	game.Workspace.SeaBeasts.ChildAdded:Connect(function(child)
		wait(2)

		if string.find(child.Name, "SeaBeast") and fn4(child) and child:FindFirstChild("Health") and child:FindFirstChild("Health").Value ~= nil and child:FindFirstChild("Health").Value > 0 then
			print("add r")

			child.Humanoid.Animator.AnimationPlayed:Connect(function(arg)
				spawn(function()
					for _, child2 in pairs(child.Anims:GetChildren()) do
						if child:FindFirstChild("Health") and child:FindFirstChild("Health").Value ~= nil and child:FindFirstChild("Health").Value > 0 and arg.Animation.AnimationId == child2.AnimationId and table.find(tbl9, child2.Name) and (fn4(child).Position - fn4(localPlayer.Character).Position).magnitude < 500 and getgenv().Setting.SeaEvents.SeaBeast then
							pcall(function()
								fn4(localPlayer.Character).Size = Vector3.new(2, 1, 2)
							end)

							if child2.Name == "WaterBeam" then
								wait(arg.Length * 5 / 10)
								NeNe = true
								wait(arg.Length * 5 / 10)
							else
								NeNe = true
								wait(arg.Length * 7 / 10)
							end

							wait()
							NeNe = false

							pcall(function()
								fn4(localPlayer.Character).Size = Vector3.new(2, 2, 1)
							end)
						end
					end
				end)
			end)
		end
	end)
end

CasualFarmEmpty = function()
	return v3:empty()
end

WorkingFarmEmpty = function()
	return WorkingFarm:empty()
end

AddPoint = function(arg, arg2)
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AddPoint", arg, arg2)
end

TimeBone_ToSecond = function(arg)
	local match, v4 = arg:match("(%d+):(%d+)")
	return tonumber(match) * 3600 + tonumber(v4) * 60
end

do
	local now = nil
	local v4 = nil

	CheckRandomBone = function()
		if now and v4 and tick() - now <= v4 then
			return false
		end
		local response, v5, v6, v7 = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Bones", "Check")

		if v6 <= 0 then
			now = tick()
			v4 = TimeBone_ToSecond(v7)
			return false
		end

		return true
	end
end

RandomBoneCondition = function()
	local flag2 = getgenv().Setting.CDK and getgenv().Setting.CDK.Enable and fn16().Evil == 5

	if not flag2 then
		flag2 = getgenv().Setting["Spawn Soul Reaper"] and getgenv().Setting["Spawn Soul Reaper"].Enable and not CheckItem("Hallow Essence") and not fn5(enemies:FindFirstChild("Soul Reaper"))
	end

	return flag2 or getgenv().Setting.OneClick.Enable
end

spawn(function()while task.wait(1)do if getgenv().Setting.OneClick.AutoAddStats then local C,M= n ,workspace:GetAttribute("MAP");if M=="Sea1"then placesea=1;elseif M=="Sea2"then placesea=2;elseif M=="Sea3"then placesea=3;else return;end;StatsData={Level= localPlayer .Data.Level.Value,Points= localPlayer .Data.Points.Value,Melee= localPlayer .Data.Stats.Melee.Level.Value,Defense= localPlayer .Data.Stats.Defense.Level.Value,Sword= localPlayer .Data.Stats.Sword.Level.Value,Fruit= localPlayer .Data.Stats["Demon Fruit"].Level.Value,Gun= localPlayer .Data.Stats.Gun.Level.Value};function CalcPoint(M)pcall(function()if M then if StatsData.Points>=C-StatsData.Melee then AddPoint("Melee",C-StatsData.Melee);else AddPoint("Melee",StatsData.Points);end;elseif StatsData.Defense<DefPoint then if StatsData.Points>=DefPoint-StatsData.Defense then AddPoint("Defense",DefPoint-StatsData.Defense);else AddPoint("Defense",StatsData.Points);end;elseif StatsData.Defense>=DefPoint then if StatsData.Melee<C then if StatsData.Points>=C-StatsData.Melee then AddPoint("Melee",C-StatsData.Melee);else AddPoint("Melee",StatsData.Points);end;elseif StatsData.Melee>=C then if StatsData.Defense<C then if StatsData.Points>=C-StatsData.Defense then AddPoint("Defense",C-StatsData.Defense);else AddPoint("Defense",StatsData.Points);end;elseif StatsData.Sword<SwordPoint then if StatsData.Points>=SwordPoint-StatsData.Sword then AddPoint("Sword",SwordPoint-StatsData.Sword);else AddPoint("Sword",StatsData.Points);end;elseif StatsData.Defense>=C then if StatsData.Fruit<DFPoint then if StatsData.Points>=DFPoint-StatsData.Fruit then AddPoint("Demon Fruit",DFPoint-StatsData.Fruit);else AddPoint("Demon Fruit",StatsData.Points);end;end;end;end;end;end);end;if StatsData.Points>0 then if StatsData.Level<55 then CalcPoint(true);elseif StatsData.Level>=55 and StatsData.Level<300 then DefPoint=15;MeleePoint= n ;CalcPoint();elseif StatsData.Level>=300 and StatsData.Level<400 then DefPoint=100;MeleePoint= n ;CalcPoint();elseif StatsData.Level>=400 then DefPoint=100;MeleePoint= n ;SwordPoint=600;DFPoint=1950;CalcPoint();end;end;end;if getgenv().Setting.Fruit.EnableSnipeFruit and#getgenv().Setting.Fruit.FruitsToSnipe>0 and not table.find(getgenv().Setting.Fruit.FruitsToSnipe, localPlayer .Data.DevilFruit.Value)then local C=game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetFruits",false);if C then for M,M in pairs(C)do if M.OnSale and(table.find(getgenv().Setting.Fruit.FruitsToSnipe,M.Name))then game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("PurchaseRawFruit",M.Name);end;end;end;end;if Sea3 then if getgenv().Setting.Shop.AutoRandomBone or(RandomBoneCondition())then game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Bones","Buy",1,1);end;end;if(Sea2 or Sea3)and(getgenv().Setting.Shop.HakiColor or getgenv().Setting.OneClick.Enable)then local C=getgenv().GetServerData.ColorDealer;if C then local M=getgenv().Setting.OneClick.Enable or getgenv().Setting.Shop.LegendaryHakiColor;if M and(table.find({"Snow White","Pure Red","Winter Sky"},C))or not M then game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ColorsDealer","2");end;end;end;if Sea2 and getgenv().Setting.Shop.AutoLegendarySword then game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LegendarySwordDealer","2");end;if getgenv().Setting.Shop.AutoRandomFruit or getgenv().Setting.OneClick.Enable then pcall(function()game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack({"Cousin","DLCBoxData"}));task.wait(0.1);local C= localPlayer and( localPlayer :FindFirstChild("PlayerGui"))or(game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui"));if C then local M=C:FindFirstChild("SpinnerWindow");if M and(M:FindFirstChild("AboveSpinner"))and(M.AboveSpinner:FindFirstChild("Navigation"))and(M.AboveSpinner.Navigation:FindFirstChild("CloseButton"))then local C=M.AboveSpinner.Navigation.CloseButton;if typeof(firesignal)=="function"and C.Activated then firesignal(C.Activated);end;M.Visible=false;end;end;end);end;task.spawn(function()pcall(function()local C= localPlayer and( localPlayer :WaitForChild("PlayerGui",10))or(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui",10));if C then C.ChildAdded:Connect(function(C)if C.Name=="SpinnerWindow"then task.wait(0.1);pcall(function()if C:FindFirstChild("AboveSpinner")and(C.AboveSpinner:FindFirstChild("Navigation"))and(C.AboveSpinner.Navigation:FindFirstChild("CloseButton"))then local M=C.AboveSpinner.Navigation.CloseButton;if typeof(firesignal)=="function"and M.Activated then firesignal(M.Activated);end;C.Visible=false;end;end);end;end);end;end);end);if getgenv().OneClickSetting and getgenv().OneClickSetting.RollRace and getgenv().OneClickSetting.RollRace.Enable then if not table.find(getgenv().OneClickSetting.RollRace.Races, localPlayer .Data.Race.Value)then if  localPlayer .Data.Fragments.Value>=3000 then game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward","Reroll","2");end;end;end;if getgenv().Setting.Shop["Candy X2 EXP"]then game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack({[1]="Candies",[2]="Buy",[3]=1,[4]=1}));end;if getgenv().Setting.Shop["Candy 500 Fragments"]then game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({[1]="Candies",[2]="Buy",[3]=2,[4]=2}));end;if getgenv().Setting.Fruit.AutoStore or getgenv().Setting.OneClick.Enable then pcall(function()FruitFunc.AutoStoreAll();end);end;pcall(function()game.ReplicatedStorage.Assets.GUI.DamageCounter.Enabled=not getgenv().Setting.Misc.__RemoveDMGCounter;game.Players.LocalPlayer.PlayerGui.Notifications.Enabled=not getgenv().Setting.Misc.__RemoveNotification;if getgenv().Setting.Misc.DisableRender3D then if not RenderIsOff then game:GetService("RunService"):Set3dRenderingEnabled(false);RenderIsOff=true;end;elseif RenderIsOff then game:GetService("RunService"):Set3dRenderingEnabled(true);RenderIsOff=false;end;if getgenv().Setting.Misc.__RemoveEffects and not RemovedEffect then RemovedEffect=true;if isfluxus then for C,C in pairs(getconnections(game.ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("FX").OnClientEvent))do C:Disconnect();end;end;end;end);if getgenv().Setting.Misc.__NoFog then  Lighting .FogEnd=100000;for C,C in pairs( Lighting :GetDescendants())do if C:IsA("Atmosphere")then C:Destroy();end;end;end;if getgenv().Setting.AutoTradeSweetChalice then if CheckItem("God's Chalice")then game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("SweetChaliceNpc");end;end;if getgenv().Setting.OneClick.Enable and Sea2 and  localPlayer .Data.Level.Value>=1100 and not SwanDoor.Check()and(SwanDoor.GetFruit())then local w={[1]="LoadFruit",[2]=SwanDoor.GetFruit()};game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(w));game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({[1]="TalkTrevor",[2]="3"}));end;end;end)
spawn(function(...) end)

task.spawn(function()
	while task.wait(0.2) do
		if getgenv().Setting.GunSwitcher.Enable then
			local maxMastery = getgenv().Setting.GunSwitcher.MaxMastery
			local gun = GetCurrentWeaponSwitcher(maxMastery, "Gun")

			for i = 1, 5 do
				gun = Weapon600Mas.Gun or gun
				local flag2 = gun and CheckInvItem(gun)

				if flag2 then
					flag2 = not (maxMastery and DataSave.FullMas[gun] or not maxMastery and DataSave.FullSkill[gun])
				end

				if flag2 then
					local v4 = localPlayer.Backpack:FindFirstChild(gun) or localPlayer.Character:FindFirstChild(gun)

					if not v4 then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", gun)
					end

					if v4 and v4:FindFirstChild("Level") then
						SelectedWeaponAlternative = gun
						MasteryCheck = maxMastery and 600 or GetMaxMasteryWeapon(v4)
						StatusFarming2 = "Farm " .. gun .. " To Mas " .. tostring(MasteryCheck)

						if v4.Level.Value <= MasteryCheck - 1 then
							Weapon600Mas.Gun = gun
						else
							print("Gun Already Maxed")
							Weapon600Mas.Gun = nil
							StatusFarming2 = "None"

							if maxMastery then
								DataSave.FullMas[gun] = true
							else
								DataSave.FullSkill[gun] = true
							end

							SelectedWeaponAlternative = nil
						end
					end
				end
			end
		end

		if getgenv().Setting.SwordSwitcher.Enable then
			local maxMastery = getgenv().Setting.SwordSwitcher.MaxMastery
			local sword = GetCurrentWeaponSwitcher(maxMastery, "Sword")

			for i = 1, 5 do
				sword = Weapon600Mas.Sword or sword
				local flag2 = sword and CheckInvItem(sword)

				if flag2 then
					flag2 = not (maxMastery and DataSave.FullMas[sword] or not maxMastery and DataSave.FullSkill[sword])
				end

				if flag2 then
					local v4 = localPlayer.Backpack:FindFirstChild(sword) or localPlayer.Character:FindFirstChild(sword)

					if not v4 then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", sword)
					end

					if v4 and v4:FindFirstChild("Level") then
						SelectedWeaponAlternative = sword
						MasteryCheck = maxMastery and 600 or GetMaxMasteryWeapon(v4)
						StatusFarming2 = "Farm " .. sword .. " To Mas " .. tostring(MasteryCheck)

						if v4.Level.Value <= MasteryCheck - 1 then
							Weapon600Mas.Sword = sword
						else
							print("Sword Already Maxed")
							Weapon600Mas.Sword = nil
							StatusFarming2 = "None"

							if maxMastery then
								DataSave.FullMas[sword] = true
							else
								DataSave.FullSkill[sword] = true
							end

							SelectedWeaponAlternative = nil
						end
					end
				end
			end
		end
	end
end)

spawn(function()
	while task.wait(1) do
		if getgenv().Setting.OneClick.Enable and workspace.DistributedGameTime >= 1200 and StatusFarming == "Farming Lv (Triple Quest Method)" then
			task.wait(0.3)
			local tbl9 = { 5, "Find New Server [One Click]" }

			if Sea3 then
				if math.random(1, 2) == 1 then
					table.insert(tbl9, 1)
					table.insert(tbl9, 4)
				end
			end

			MainServerHop(unpack(tbl9))
		end
	end
end)

spawn(function()
	while task.wait(0.3) do
		if SelectedPlayer and getgenv().Setting.TweenToPlayer and Players:FindFirstChild(SelectedPlayer) then
			if not (getgenv().Setting.OneClick.Enable or getgenv().MeleeNPCBusy) then
				local character = Players:FindFirstChild(SelectedPlayer).Character

				local function fn22()
					return fn5(character) and getgenv().Setting.TweenToPlayer and not getgenv().Setting.OneClick.Enable and not getgenv().MeleeNPCBusy
				end

				if fn5(character) then
					DoTween2(fn4(character).CFrame, fn22, nil, { ForceTweenPause = true })
				end
			end
		end
	end
end)

spawn(function()
	local n2 = 1
	local now = tick()

	local tbl9 = {
		Kabucha = 95,
		["Serpent Bow"] = 125,
		["Bizarre Rifle"] = 395,
		["Acidum Rifle"] = 300,
		Dragonstorm = 400,
	}

	while task.wait() do
		if getgenv().Setting.Pvp.SilentAimSelected and SelectedPlayer and Players:FindFirstChild(SelectedPlayer) then
			local character = Players:FindFirstChild(SelectedPlayer).Character

			if fn5(character) and Alive() then
				local position = character.HumanoidRootPart.Position
				getgenv().HitPosition = position
			end
		elseif getgenv().Setting.Pvp.SilentAimNear then
			local v4 = fn17()

			if v4 and fn5(v4.Character) and Alive() then
				local position = v4.Character.HumanoidRootPart.Position
				getgenv().HitPosition = position
			end
		else
			getgenv().HitPosition = nil
		end

		if getgenv().Setting.Pvp.AutoShootGun then
			local v4 = fn17()

			if v4 and fn5(v4.Character) and Alive() then
				local function fn22()
					local v5 = nil

					for _, child in pairs(localPlayer.Character:GetChildren()) do
						if child:IsA("Tool") then
							if child.ToolTip == "Gun" then
								v5 = child
							end
						end
					end

					if v5 then
						if v5.Name == "Dragonstorm" then
							n2 = 0.2
						else
							n2 = 1
						end

						if tbl9[v5.Name] then
							if getgenv().Setting.Pvp.GunDistanceCheck then
								local v6 = tbl9[v5.Name]
								if fn9(v4.Character, localPlayer.Character) < v6 then
									return true
								end
								return false
							end

							return true
						end

						return true
					end

					return false
				end

				if fn22() and tick() - now > n2 then
					now = tick()

					if n2 == 0 then
						ShootGun(v4.Character)
					end
				end
			end
		end
	end
end)

do
	local function fn22(arg)
		return arg.Parent and arg:FindFirstChild("Health") and arg:FindFirstChild("Health").Value ~= nil and arg:FindFirstChild("Health").Value > 0
	end

	local function fn23(arg)
		return fn4(arg) and string.find(arg.Name, "SeaBeast")
	end

	local function fn24(arg)
		if arg.Name == "PirateBrigade" or arg.Name == "PirateBasic" or arg.Name == "FishBoat" or arg.Name == "PirateGrandBrigade" then
			if arg.Parent and arg:FindFirstChild("Engine") then
				return true
			end
		end
	end

	local function fn25(arg)
		local v4 = getgenv().Setting.SeaEvents[arg]
		local enable

		if v4 then
			enable = v4
		else
			local v5 = SeaEventsController[arg]

			if v5 then
				local v6 = SeaEventsController[arg]
				enable = getgenv().Setting[v6].Enable
			else
				enable = v5
			end
		end

		return enable
	end

	local tbl9 = {
		SeaBeast = function()
			if not fn25("SeaBeast") then
				return
			end

			if not Alive() then
				return
			end
			local huge = math.huge
			local v4 = nil

			for _, child in pairs(game.Workspace.SeaBeasts:GetChildren()) do
				if Alive() and fn22(child) and fn23(child) and fn9(child, localPlayer.Character) <= 1500 then
					if (fn4(child).Position - fn4(localPlayer.Character).Position).magnitude < huge then
						huge = (fn4(child).Position - fn4(localPlayer.Character).Position).magnitude
						v4 = child
					end
				end
			end

			return v4
		end,
		Ship = function(arg, arg2)
			if not fn25("Ship") then
				return
			end

			if not Alive() then
				return
			end

			for _, child in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
				if fn24(child) then
					if fn22(child) then
						if fn9(child.Engine, localPlayer.Character) <= (arg2 or 3000) then
							return child
						end
					end
				end
			end
		end,
		TerrorShark = function(arg)
			if not fn25("TerrorShark") and not arg then
				return
			end

			if not Alive() then
				return
			end

			for _, child in pairs(enemies:GetChildren()) do
				if child.Name ~= "Terrorshark" then
					continue
				end

				if fn5(child) and fn9(child, localPlayer.Character) <= 1000 then
					return child
				end
			end
		end,
		Piranha = function()
			if not fn25("Piranha") then
				return
			end

			if not Alive() then
				return
			end

			for _, child in pairs(enemies:GetChildren()) do
				if fn5(child) and child.Name == "Piranha" and fn9(child, localPlayer.Character) <= 1000 then
					return child
				end
			end
		end,
		Shark = function()
			if not fn25("Shark") then
				return
			end

			if not Alive() then
				return
			end

			for _, child in pairs(enemies:GetChildren()) do
				local v4 = Alive() and fn5(child)
				local flag2

				if v4 then
					flag2 = child.Name == "Shark" or child.Name == "Fish Crew Member"
				else
					flag2 = v4
				end

				flag2 = flag2 and fn9(child, localPlayer.Character) <= 400
				if flag2 then
					return child
				end
			end
		end,
	}

	local tbl10 = {
		TerrorShark = function(arg)
			local fn26 = arg or function()
				return fn25("TerrorShark")
			end

			local v4 = tbl9.TerrorShark()

			if fn5(v4) then
				local function fn27(arg2)
					if arg2 and arg2.Parent then
						if fn4(arg2) and arg2:FindFirstChild("Humanoid") then
							if arg2:FindFirstChild("Humanoid").Health and arg2:FindFirstChild("Humanoid").Health > 0 then
								return true
							end
						end
					end

					return false
				end

				local connection = game:GetService("Workspace")._WorldOrigin.ChildAdded:Connect(function(child)
					if Alive() then
						if (child.Name == "SharkSplash" or child.name == "SpinSplash") and fn9(child.Position, localPlayer.Character) < 350 then
							NeLv1 = tick()
						end

						if child.Name == "ChargeUp" and fn9(child.Position, localPlayer.Character) < 350 then
							NeLv2 = tick()
						end
					end
				end)

				while fn27(v4) and task.wait(0.2) and fn26() do
					pcall(function()
						localPlayer.Character.Humanoid.Sit = false

						if Alive() and fn26() and getgenv().Setting.SeaEvents.SafeMode and localPlayer.Character.Humanoid.Health <= 3000 then
							while fn27(v4) and fn26() and getgenv().Setting.SeaEvents.SafeMode and task.wait(0.1) and Alive() and localPlayer.Character.Humanoid.Health <= 6000 do
								fn12(v4, Vector3.new(0, 300, 20))
							end
						end

						if NeLv1 then
							while true do
								local flag2 = Alive() and fn27(v4) and fn26()

								if flag2 then
									local v5 = NeLv1
									flag2 = tick() - v5 < 0.6
								end

								if flag2 and task.wait(0.1) then
									fn12(v4, Vector3.new(0, 300, 20))
									continue
								end
								break
							end

							NeLv1 = nil
						end

						if NeLv2 then
							while true do
								local v5 = Alive() and fn27(v4) and fn26()
								local flag2

								if v5 then
									local v6 = NeLv2
									flag2 = tick() - v6 < 1.1
								else
									flag2 = v5
								end

								flag2 = flag2 and task.wait(0.1)
								if flag2 then
									fn12(v4, Vector3.new(0, 300, 20))
									continue
								end
								break
							end

							NeLv2 = nil
						end

						fn6(true)
						DoTween2(v4.HumanoidRootPart.CFrame * CFrame.new(0, getgenv().Setting.SeaEvents.TerrorSharkY or 50, 0))
						fn6(true)
					end)

					pcall(Equip, GetCurrentTool("Melee", true))
				end

				if connection then
					connection:Disconnect()
				end

				fn6(false)
			end
		end,
		SeaBeast = function()
			local v4 = tbl9.SeaBeast()
			SeaBeastSpawned = false
			getgenv().SilentAimPos = false

			if v4 then
				if getgenv().Setting.SeaEvents.IgnoreSeaBeast and Alive() then
					local position = fn4(localPlayer.Character).Position
					localPlayer.Character.Humanoid.Sit = false

					while task.wait(0.1) and v4 and v4.Parent and Alive() and getgenv().Setting.SeaEvents.IgnoreSeaBeast and fn25("SeaBeast") do
						fn4(localPlayer.Character).CFrame = CFrame.new(position.X, position.Y + 1000, position.Z)
					end

					fn4(localPlayer.Character).CFrame = CFrame.new(position)
				else
					print("Farming Sea")
					getgenv().SilentAimPos = true
					SeaBeastSpawned = true
					local n2 = 0
					local n3 = 150
					MakeSeaEventSkill()

					SkillsController.Condition = function()
						return Alive() and v4 and v4.Parent and v4:FindFirstChild("Health") and v4:FindFirstChild("Health").Value ~= nil and v4:FindFirstChild("HumanoidRootPart") and fn4(v4).Position.Y >= -179 and fn25("SeaBeast")
					end

					SkillsController.Idle = function()
						return NeNe
					end

					while true do
						task.wait(0.1)

						if Alive() and v4.Parent and v4 and v4:FindFirstChild("HumanoidRootPart") and v4:FindFirstChild("Health") and v4:FindFirstChild("Health").Value ~= nil and v4:FindFirstChild("Health").Value > 0 and (fn25("SeaBeast") or Bypass) then
							spawn(function()
								localPlayer.Character.Humanoid.Sit = false
								local worldPosition = v4.RootPart.body["body.010"].WorldPosition
								getgenv().PosToHook = worldPosition

								if fn4(v4).Position.Y < -179 then
									fn6(true)
								else
									n2 += 18

									if not NeNe then
										DoTween(fn4(v4).CFrame * CFrame.new(0, 400, -100))
									else
										DoTween2(CFrame.new(fn4(v4).Position.X + math.sin(math.rad(n2 + 360)) * n3, fn4(v4).Position.Y + 800, fn4(v4).Position.Z + math.cos(math.rad(n2 + 360)) * n3) * CFrame.new(0, 0, -40))
									end

									fn6(true)
								end
							end)

							spawn(function()
								if not daxaiskillsea then
									daxaiskillsea = true
									game:GetService("ReplicatedStorage").Remotes.CommE:FireServer("ActivateAbility")
									wait(5)
									daxaiskillsea = false
								end
							end)
						end

						if not (not v4.Parent or not v4 or not v4:FindFirstChild("HumanoidRootPart") or not v4:FindFirstChild("Health") or v4:FindFirstChild("Health").Value == nil or v4:FindFirstChild("Health").Value <= 0 or not Alive() or not fn25("SeaBeast")) then
							continue
						end
						break
					end

					VoidSkillController()
					SeaBeastSpawned = false
					getgenv().SilentAimPos = false
				end
			end
		end,
		Ship = function()
			getgenv().SilentAimPos = false
			FarmingShip = false

			if tbl9.Ship() and getgenv().Setting.SeaEvents.IgnoreShip then
				if Alive() and localPlayer.Character.Humanoid.SeatPart then
					local position = localPlayer.Character.Humanoid.SeatPart.Position

					while Alive() and tbl9.Ship() and task.wait(0.1) and getgenv().Setting.SeaEvents.IgnoreShip and fn25("Ship") do
						localPlayer.Character.Humanoid.Sit = false

						pcall(function()
							localPlayer.Character.Humanoid.SeatPart.CFrame = CFrame.new(-16256.5566, 9.06057358, 430.995422)
						end)
					end

					pcall(function()
						localPlayer.Character.Humanoid.SeatPart.CFrame = CFrame.new(position)
					end)
				end
			else
				local function fn26(arg)
					if arg and arg.Parent then
						if arg:FindFirstChild("Engine") and arg:FindFirstChild("Humanoid") and arg:FindFirstChild("Health") and arg:FindFirstChild("Health").Value ~= nil and arg:FindFirstChild("Health").Value > 0 then
							return true
						end
					end

					return false
				end

				local v4 = tbl9.Ship()

				while task.wait(0.1) and Alive() and fn26(v4) and fn9(v4.Engine, localPlayer.Character) <= 3000 do
					MakeSeaEventSkill()

					SkillsController.Condition = function()
						return Alive() and fn26(v4) and fn9(v4.Engine, localPlayer.Character) <= 3000
					end

					local ok, ship = pcall(function()
						localPlayer.Character.Humanoid.Sit = false
						getgenv().SilentAimPos = true
						FarmingShip = true
						local position = v4.Engine.Position
						getgenv().PosToHook = position

						local function fn27()
							return fn26(v4)
						end

						DoTween2(CFrame.new(v4.Engine.Position + Vector3.new(0, 15, 0)), fn27)
						fn6(true)
					end)

					if ship then
						print("Ship: " .. ship)
					end
				end

				VoidSkillController()
				getgenv().SilentAimPos = false
				getgenv().PosToHook = nil
				FarmingShip = false
			end
		end,
		Piranha = function(arg)
			local fn26 = arg or function()
				return fn25("Piranha")
			end

			local v4 = tbl9.Piranha()

			while task.wait(0.2) and fn5(v4) and Alive() and fn26() do
				localPlayer.Character.Humanoid.Sit = false
				fn6(true)

				local ok, piranha = pcall(function()
					DoTween(v4.HumanoidRootPart.CFrame * CFrame.new(0, 40, 0), true)
					pcall(Equip, GetCurrentTool("Melee", true))
				end)

				fn6(true)

				if piranha then
					print("Piranha: " .. piranha)
				end
			end

			fn6(false)
		end,
		Shark = function()
			local fn26 = Condition or function()
				return fn25("Shark")
			end

			local v4 = tbl9.Shark()

			while task.wait(0.2) and fn5(v4) and fn26() and Alive() do
				localPlayer.Character.Humanoid.Sit = false
				fn6(true)

				local ok, result = pcall(function()
					DoTween(v4.HumanoidRootPart.CFrame * CFrame.new(0, 40, 0), true)
					pcall(Equip, GetCurrentTool("Melee", true))
				end)

				fn6(true)

				if result then
					print(result)
				end
			end

			fn6(false)
		end,
	}
end

GetBoat = function()
	for _, child in pairs(game:GetService("Workspace").Boats:GetChildren()) do
		if child:FindFirstChild("Owner") and child.Owner.Value == game.Players.LocalPlayer and child:FindFirstChild("VehicleSeat") then
			return child
		end
	end

	return false
end

if not getgenv().AddedM1Checker then
	getgenv().StopM1Up = true

	pcall(function()
		local controllers = game:GetService("ReplicatedStorage"):FindFirstChild("Controllers")
		controllers = controllers and controllers:FindFirstChild("UI")
		local repairShip = controllers and controllers:FindFirstChild("RepairShip")

		if repairShip and repairShip:IsA("ModuleScript") then
			local module = require(repairShip)

			if module and module.M1Up then
				local m1Up = module.M1Up

				module.M1Up = function(...)
					if getgenv().StopM1Up or getgenv().Setting and getgenv().Setting.SubClass and getgenv().Setting.SubClass.Enable then
						return
					end
					return m1Up(...)
				end
			end
		end
	end)
end

if getgenv().WhiteScreen then
	pcall(function()
		SupportRetard()
		game:GetService("RunService"):Set3dRenderingEnabled(false)
	end)
end

if getgenv().Setting.OneClick.Enable then
	Notify({ Text = "Intilizing One Click Functions", Type2 = nil, Delay = 10 })
	print("Start Intilizing One Click Functions")

	repeat
		wait(0.1)
	until FinishLoadUi

	local now = tick()

	while true do
		wait(0.1)
		StatusFarming = "Intilizing One Click Functions"
		if not (CheckDone and CheckDone >= 8 or tick() - now >= 10) then
			continue
		end
		break
	end

	task.spawn(function()
		if getgenv().Setting.OneClick.RedeemCode then
			StatusFarming = "Attemping To Redeem All Codes"
			IslandCaller("RedeemAllCode")
		end
	end)

	StatusFarming = "Finished Intilizing One Click Functions"
	Notify({ Text = "Finished Intilizing One Click Functions", Type2 = nil, Delay = 5 })

	if getgenv().SetFpsCap and type(getgenv().FpsCap) == "number" then
		pcall(function()
			if setfpscap then
				setfpscap(getgenv().FpsCap)
			end

			setfflag("TaskSchedulerTargetFps", tostring(getgenv().FpsCap))
		end)
	end
end

spawn(function()
	fn21()
end)

getgenv().ExploitTime = {}
getgenv().IsExploiting = {}
getgenv().NearTime = {}

SusExploit = function(arg)
	repeat
		wait()
	until arg.Character

	if not arg or arg.Name == game.Players.LocalPlayer.Character.Name then
		return
	end
	local humanoid = arg.Character and arg.Character:WaitForChild("Humanoid")
	local flag2

	if humanoid then
		local freefall = Enum.HumanoidStateType.Freefall
		flag2 = humanoid:GetState() == freefall
	else
		flag2 = humanoid
	end

	if flag2 then
		if not ExploitTime[arg.Name] then
			ExploitTime[arg.Name] = tick()

			while true do
				task.wait()
				local freefall = Enum.HumanoidStateType.Freefall
				local flag3 = humanoid:GetState() ~= freefall

				if not flag3 then
					local v4 = ExploitTime[arg.Name]
					flag3 = tick() - v4 >= 20
				end

				if not flag3 then
					continue
				end
				break
			end

			local v4 = ExploitTime[arg.Name]

			if tick() - v4 >= 20 then
				local name = arg.Name
				getgenv().IsExploiting[name] = true
			end
		end
	elseif ExploitTime[arg.Name] then
		local v4 = ExploitTime[arg.Name]

		if tick() - v4 > 20 then
			local name = arg.Name
			getgenv().IsExploiting[name] = true
		end
	end

	humanoid.StateChanged:Connect(function()
		local freefall = Enum.HumanoidStateType.Freefall

		if humanoid:GetState() == freefall then
			if not ExploitTime[arg.Name] then
				ExploitTime[arg.Name] = tick()
			end
		elseif ExploitTime[arg.Name] then
			local v4 = ExploitTime[arg.Name]

			if tick() - v4 > 20 then
				local name = arg.Name
				getgenv().IsExploiting[name] = true
				ExploitTime[arg.Name] = nil
			else
				ExploitTime[arg.Name] = tick()
			end
		end
	end)
end

for _, v4 in game.Players:GetChildren() do
	task.spawn(SusExploit, v4)
end

task.spawn(function()
	while task.wait(1) do
		if getgenv().Setting.OneClick.Enable then
			pcall(function()
				localPlayer.Character.Humanoid.Sit = false
			end)

			if WorkingFarm:empty() then
				for _, v4 in game.Players:GetChildren() do
					if v4 ~= localPlayer then
						if v4.Character and fn5(v4.Character) and Alive() then
							if fn9(v4.Character, localPlayer.Character) < 600 then
								if not getgenv().NearTime[v4] then
									getgenv().NearTime[v4] = tick()
								end

								if tick() - getgenv().NearTime[v4] > 15 then
									local name = v4.Name
									getgenv().IsExploiting[name] = true
								end
							else
								getgenv().NearTime[v4] = tick()
							end
						end
					end
				end
			end
		end
	end
end)

game.Players.ChildAdded:Connect(SusExploit)

task.spawn(function()
	local n2 = 0
	local CollectionService = game:GetService("CollectionService")

	while task.wait(0.5) do
		pcall(function()
			local character = localPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")

			if character and humanoid and humanoid.Health > 0 then
				local hasBuso = character:FindFirstChild("HasBuso")
				local v4

				if hasBuso then
					v4 = hasBuso
				else
					local v5 = CollectionService

					if CollectionService then
						v4 = CollectionService:HasTag(character, "HasBuso")
					else
						v4 = v5
					end
				end

				if not v4 and tick() - n2 >= 1.5 then
					n2 = tick()
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
				end
			end
		end)
	end
end)

localPlayer.CharacterAdded:Connect(function(character)
	task.wait(1)

	pcall(function()
		local CollectionService = game:GetService("CollectionService")

		if not (character:FindFirstChild("HasBuso") or CollectionService and CollectionService:HasTag(character, "HasBuso")) then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
		end
	end)
end)

spawn(function(...) end)

task.spawn(function()
	while true do
		task.wait(1)
		if not (game:IsLoaded() and game:GetService("ReplicatedStorage"):FindFirstChild("Modules")) then
			continue
		end
		break
	end

	local rfGachaNetworkRF = game:GetService("ReplicatedStorage").Modules.Net:WaitForChild("RF/GachaNetworkRF", 10)
	if not rfGachaNetworkRF then
		return
	end

	while task.wait(60) do
		pcall(function()
			rfGachaNetworkRF:InvokeServer({ Context = "Purchase", BoxName = "MagnetEventGacha26" })
		end)
	end
end)
