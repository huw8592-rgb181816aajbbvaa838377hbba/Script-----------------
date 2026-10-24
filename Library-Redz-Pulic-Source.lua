local cloneref = cloneref or function(o) return o end

local Players = cloneref(game:GetService("Players"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TextService = cloneref(game:GetService("TextService"))
local HttpService = cloneref(game:GetService("HttpService"))
local Lighting = cloneref(game:GetService("Lighting"))

local LocalPlayer = Players.LocalPlayer

local Mouse
pcall(function() Mouse = LocalPlayer:GetMouse() end)

local FS = {
	read = readfile, write = writefile, make = makefolder,
	isfile = isfile, isfolder = isfolder, delfile = delfile,
}

local function GetGuiParent()
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then return hui end
	local ok2, cg = pcall(function() return cloneref(game:GetService("CoreGui")) end)
	if ok2 and cg then return cg end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local C = {
	bg        = Color3.fromRGB(9, 14, 12),
	panelTop  = Color3.fromRGB(22, 33, 28),
	panelBot  = Color3.fromRGB(12, 18, 15),
	inset     = Color3.fromRGB(10, 16, 13),
	card      = Color3.fromRGB(20, 30, 26),
	cardTop   = Color3.fromRGB(24, 36, 30),
	cardHover = Color3.fromRGB(27, 41, 34),
	line      = Color3.fromRGB(44, 62, 54),
	lineSoft  = Color3.fromRGB(31, 44, 38),
	text      = Color3.fromRGB(236, 247, 242),
	dim       = Color3.fromRGB(156, 178, 168),
	faint     = Color3.fromRGB(110, 132, 122),

	acc       = Color3.fromRGB(62, 231, 143),
	accLight  = Color3.fromRGB(158, 255, 208),
	accDim    = Color3.fromRGB(30, 128, 82),
	accSoft   = Color3.fromRGB(22, 58, 44),
	onAcc     = Color3.fromRGB(5, 28, 18),

	danger    = Color3.fromRGB(255, 96, 109),
	white     = Color3.fromRGB(255, 255, 255),
}

local Font = {
	Regular = Enum.Font.Gotham,
	Medium  = Enum.Font.GothamMedium,
	Bold    = Enum.Font.GothamBold,
	Black   = Enum.Font.GothamBlack,
}

local function New(class, props, children)
	local obj = Instance.new(class)
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			elseif k == "Children" then
				children = v
			else
				local ok = pcall(function() obj[k] = v end)
				if not ok then
					warn("[Aurora] không set được thuộc tính '" .. tostring(k) .. "' cho " .. class)
				end
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = obj
		end
	end
	if parent then
		obj.Parent = parent
	end
	return obj
end

local function Tw(obj, time, props, style, dir)
	if not obj or not props then return end
	local t = TweenService:Create(obj, TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function Corner(obj, radius)
	return New("UICorner", {CornerRadius = radius or UDim.new(0, 10), Parent = obj})
end

local function Stroke(obj, color, thickness, transparency)
	return New("UIStroke", {
		Color = color or C.line,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = obj,
	})
end

local function Grad(obj, rotation, c1, c2, transparency)
	local g = New("UIGradient", {
		Rotation = rotation or 90,
		Color = ColorSequence.new(c1, c2 or c1),
		Parent = obj,
	})
	if transparency then
		g.Transparency = transparency
	end
	return g
end

local function Pad(obj, l, t, r, b)
	return New("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0),
		PaddingTop = UDim.new(0, t or 0),
		PaddingRight = UDim.new(0, r or l or 0),
		PaddingBottom = UDim.new(0, b or t or 0),
		Parent = obj,
	})
end

local function List(obj, padding, horizontal, halign, valign)
	return New("UIListLayout", {
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		Parent = obj,
	})
end

local function Scale(obj, value)
	return New("UIScale", {Scale = value or 1, Parent = obj})
end

local function Bar(parent, w, h, rot, color, transparency, pos, anchor, corner)
	local f = New("Frame", {
		Size = UDim2.fromOffset(w, h),
		Rotation = rot or 0,
		BackgroundColor3 = color or C.text,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		Position = pos or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
		Parent = parent,
	})
	Corner(f, UDim.new(1, 0))
	return f
end

local function Dot(parent, size, color, transparency, pos, anchor)
	local d = New("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color or C.acc,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		Position = pos or UDim2.fromScale(0.5, 0.5),
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
		Parent = parent,
	})
	Corner(d, UDim.new(1, 0))
	return d
end

local function IsMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local TooltipGui, TooltipLabel, TooltipStroke
local function InitTooltip(gui)
	if TooltipGui and TooltipGui.Parent then return end
	TooltipGui = New("TextLabel", {
		Name = "AuroraTooltip",
		Visible = false,
		BackgroundColor3 = Color3.fromRGB(16, 24, 20),
		BackgroundTransparency = 0.05,
		Text = "",
		TextSize = 12,
		Font = Font.Regular,
		TextColor3 = C.text,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Size = UDim2.fromOffset(220, 30),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 500,
		Parent = gui,
	})
	Corner(TooltipGui, UDim.new(0, 8))
	TooltipStroke = Stroke(TooltipGui, C.line, 1, 0.2)
	Pad(TooltipGui, 9, 7, 9, 7)
	TooltipLabel = TooltipGui
end

local function ShowTooltip(gui, text)
	InitTooltip(gui)
	TooltipLabel.Text = text
	TooltipLabel.Size = UDim2.fromOffset(220, 0)
	TooltipLabel.Visible = true
	local mouse = UserInputService:GetMouseLocation()
	TooltipLabel.Position = UDim2.fromOffset(mouse.X + 14, mouse.Y + 18)
	TooltipLabel.BackgroundTransparency = 1
	Tw(TooltipLabel, 0.15, {BackgroundTransparency = 0.05})
end

local function HideTooltip()
	if TooltipLabel then
		TooltipLabel.Visible = false
	end
end

local function MakeDraggable(target, handle, onMove)
	local dragging = false
	local startPos, startTargetPos
	local moved = false

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			moved = false
			startPos = input.Position
			startTargetPos = target.Position
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if conn then conn:Disconnect() end
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - startPos
			if math.abs(delta.X) > 3 or math.abs(delta.Y) > 3 then
				moved = true
			end
			target.Position = UDim2.new(
				startTargetPos.X.Scale, startTargetPos.X.Offset + delta.X,
				startTargetPos.Y.Scale, startTargetPos.Y.Offset + delta.Y
			)
			if onMove then onMove() end
		end
	end)

	return function() return moved end
end

local Library = {}
Library.Theme = C
Library.Font = Font
Library.Version = "6.0"
Library.MIN_SCALE = 0.55
Library.MAX_SCALE = 1.35
Library.Accent = C.acc

local currentScale = 1

Library._guis = {}
Library._accentFns = {}
Library._accentSlots = {}

function Library:Accent(obj, prop, kind)
	local slot = {obj = obj, prop = prop, kind = kind or "main"}
	table.insert(self._accentSlots, slot)
	local function resolve()
		if slot.kind == "light" then return C.accLight
		elseif slot.kind == "dim" then return C.accDim
		elseif slot.kind == "soft" then return C.accSoft
		elseif slot.kind == "on" then return C.onAcc
		end
		return C.acc
	end
	pcall(function() obj[prop] = resolve() end)
	return obj
end

function Library:OnAccent(fn)
	table.insert(self._accentFns, fn)
	pcall(fn)
end

function Library:SetAccent(color3)
	assert(typeof(color3) == "Color3", "[Aurora] SetAccent cần Color3")
	C.acc = color3
	C.accLight = color3:Lerp(Color3.new(1, 1, 1), 0.55)
	C.accDim = color3:Lerp(Color3.new(0, 0, 0), 0.55)
	C.accSoft = color3:Lerp(Color3.new(0, 0, 0), 0.78)
	C.onAcc = color3:Lerp(Color3.new(0, 0, 0), 0.85)
	self.Accent = color3
	for _, fn in ipairs(self._accentFns) do pcall(fn) end
	for _, slot in ipairs(self._accentSlots) do
		pcall(function()
			if slot.kind == "light" then slot.obj[slot.prop] = C.accLight
			elseif slot.kind == "dim" then slot.obj[slot.prop] = C.accDim
			elseif slot.kind == "soft" then slot.obj[slot.prop] = C.accSoft
			elseif slot.kind == "on" then slot.obj[slot.prop] = C.onAcc
			else slot.obj[slot.prop] = C.acc end
		end)
	end
end

function Library:Hex(color3)
	return string.format("#%02X%02X%02X",
		math.floor(color3.R * 255 + 0.5),
		math.floor(color3.G * 255 + 0.5),
		math.floor(color3.B * 255 + 0.5))
end

function Library:SetUIScale(value)
	assert(type(value) == "number", "[Aurora] SetUIScale cần number")
	value = math.clamp(value, self.MIN_SCALE, self.MAX_SCALE)
	currentScale = value
	for _, gui in ipairs(Library._guis) do
		local us = gui:FindFirstChild("Scale")
		if us then Tw(us, 0.2, {Scale = value}) end
	end
end

function Library:GetScale() return currentScale end
function Library:GetMaxScale() return self.MAX_SCALE end
function Library:GetMinScale() return self.MIN_SCALE end

local function LoadSettings(folder)
	local path = folder and (folder .. "/Aurora.json") or nil
	local data = {}
	if path and FS.read then
		local ok, raw = pcall(FS.read, path)
		if ok and type(raw) == "string" then
			local ok2, parsed = pcall(function() return HttpService:JSONDecode(raw) end)
			if ok2 and type(parsed) == "table" then data = parsed end
		end
	end
	local function Save()
		if not path or not FS.write then return end
		pcall(function()
			if FS.make and FS.isfolder and not FS.isfolder(folder) then FS.make(folder) end
			FS.write(path, HttpService:JSONEncode(data))
		end)
	end
	return data, Save
end

local CreateShell
local ShellAPI = {}

CreateShell = function(Lib, config)
	config = config or {}

	local TitleText = config[1] or config.Name or config.Title or "Aurora Hub"
	local SubText = config[2] or config.SubName or config.SubTitle or "UI Library v6"
	local Folder = config[3] or config.ScriptFolder or config.FolderName

	local Settings, SaveSettings = LoadSettings(Folder)

	local TOPBAR_H = 56
	local SIDEBAR_W = 184
	local DEF_W, DEF_H = 680, 520
	local MIN_W, MIN_H = 580, 400
	local MAX_W, MAX_H = 1000, 660

	local StartW = DEF_W
	local StartH = DEF_H
	if type(Settings.W) == "number" and type(Settings.H) == "number" then
		StartW = math.clamp(Settings.W, MIN_W, MAX_W)
		StartH = math.clamp(Settings.H, MIN_H, MAX_H)
	end

	local ctx = {
		Library = Lib,
		Tabs = {},
		SearchIndex = {},
		Connections = {},
		CurrentTab = nil,
		OpenDropdown = nil,
		SearchQuery = "",
		Folder = Folder,
	}

	function ctx:Conn(signal, fn)
		local c = signal:Connect(fn)
		table.insert(self.Connections, c)
		return c
	end

	local function ComputeScale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		return math.clamp(math.min(vp.X / 840, vp.Y / 640), Lib.MIN_SCALE, 1.12)
	end

	local Gui = New("ScreenGui", {
		Name = "RedzAurora",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	})

	local parents = { GetGuiParent(), LocalPlayer:FindFirstChild("PlayerGui") }
	for _, parent in ipairs(parents) do
		if parent and not Gui.Parent then
			pcall(function() Gui.Parent = parent end)
		end
	end
	if not Gui.Parent then
		pcall(function() Gui.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end)
	end
	ctx.Gui = Gui
	table.insert(Lib._guis, Gui)

	currentScale = ComputeScale()
	local UIScale = New("UIScale", {Name = "Scale", Scale = currentScale, Parent = Gui})
	ctx.UIScale = UIScale

	local Root = New("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0, 0),
		Size = UDim2.fromOffset(StartW, StartH),
		BackgroundColor3 = C.panelBot,
		ClipsDescendants = true,
		Active = true,
		Parent = Gui,
	})
	Corner(Root, UDim.new(0, 16))
	Stroke(Root, C.line, 1, 0.15)
	Grad(Root, 90, C.panelTop, C.panelBot)
	ctx.Root = Root

	local Glow = Stroke(Root, C.acc, 5, 0.94)
	Lib:Accent(Glow, "Color")

	local Sheen = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = Root,
	})
	Grad(Sheen, 118, C.white, C.accLight, NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.995),
		NumberSequenceKeypoint.new(0.42, 0.965),
		NumberSequenceKeypoint.new(0.60, 0.990),
		NumberSequenceKeypoint.new(1.00, 1.000),
	}))

	local RimLight = New("Frame", {
		Name = "RimLight",
		Size = UDim2.new(1, -28, 0, 1),
		Position = UDim2.new(0, 14, 0, 0),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = Root,
	})
	Grad(RimLight, 0, C.accLight, C.white, NumberSequence.new({
		NumberSequenceKeypoint.new(0.00, 0.85),
		NumberSequenceKeypoint.new(0.28, 0.55),
		NumberSequenceKeypoint.new(0.60, 0.80),
		NumberSequenceKeypoint.new(1.00, 0.95),
	}))

	local function CenterRoot()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local sc = currentScale
		local w = Root.Size.X.Offset
		local h = Root.Size.Y.Offset
		Root.Position = UDim2.fromOffset(
			math.max(0, (vp.X / sc - w) / 2),
			math.max(0, (vp.Y / sc - h) / 2)
		)
	end
	CenterRoot()
	ctx.CenterRoot = CenterRoot

	local Top = New("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, TOPBAR_H),
		BackgroundTransparency = 1,
		Parent = Root,
	})
	ctx.TopBar = Top

	local Logo = New("Frame", {
		Name = "Logo",
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.new(0, 16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.acc,
		Parent = Top,
	})
	Corner(Logo, UDim.new(0, 10))
	local LogoGrad = Grad(Logo, 135, C.accLight, C.accDim)
	Lib:OnAccent(function() LogoGrad.Color = ColorSequence.new(C.accLight, C.accDim) end)
	Lib:Accent(Stroke(Logo, C.accLight, 1, 0.55), "Color", "light")

	local LogoText = New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = string.upper(string.sub(TitleText, 1, 1)),
		Font = Font.Black,
		TextSize = 16,
		TextColor3 = C.onAcc,
		Parent = Logo,
	})
	Lib:Accent(LogoText, "TextColor3", "on")

	local LogoGlow = New("Frame", {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.acc,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = Logo,
	})
	Corner(LogoGlow, UDim.new(1, 0))
	Lib:Accent(LogoGlow, "BackgroundColor3")
	local glowTween = TweenService:Create(LogoGlow, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.97})
	glowTween:Play()
	table.insert(ctx.Connections, {Disconnect = function() glowTween:Cancel() end})

	local Title = New("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -386, 0, 20),
		Position = UDim2.new(0, 60, 0, 10),
		BackgroundTransparency = 1,
		Text = TitleText,
		TextColor3 = C.text,
		Font = Font.Bold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = Top,
	})

	local SubTitle = New("TextLabel", {
		Name = "SubTitle",
		Size = UDim2.new(1, -386, 0, 14),
		Position = UDim2.new(0, 60, 0, 30),
		BackgroundTransparency = 1,
		Text = SubText,
		TextColor3 = C.dim,
		Font = Font.Regular,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = Top,
	})

	ctx.TitleLabel = Title
	ctx.SubTitleLabel = SubTitle

	local MinBtn = New("TextButton", {
		Name = "Minimize",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -48, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = C.card,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = Top,
	})
	Corner(MinBtn, UDim.new(0, 9))
	local minBarH = Bar(MinBtn, 10, 2, 0, C.dim)
	local minBarV = Bar(MinBtn, 2, 10, 0, C.dim)
	minBarV.Visible = false

	local CloseBtn = New("TextButton", {
		Name = "Close",
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = C.danger,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = Top,
	})
	Corner(CloseBtn, UDim.new(0, 9))
	local closeA = Bar(CloseBtn, 1.8, 10, 45, C.dim)
	local closeB = Bar(CloseBtn, 1.8, 10, -45, C.dim)

	local function HoverBtn(btn)
		local down = false
		ctx:Conn(btn.MouseEnter, function()
			Tw(btn, 0.18, {BackgroundTransparency = 0.86, BackgroundColor3 = (btn == CloseBtn) and C.danger or C.cardHover})
			for _, b in ipairs(btn:GetChildren()) do
				if b:IsA("Frame") then Tw(b, 0.18, {BackgroundColor3 = C.text}) end
			end
		end)
		ctx:Conn(btn.MouseLeave, function()
			Tw(btn, 0.18, {BackgroundTransparency = 1})
			for _, b in ipairs(btn:GetChildren()) do
				if b:IsA("Frame") then Tw(b, 0.18, {BackgroundColor3 = (btn == CloseBtn) and C.dim or C.dim}) end
			end
		end)
	end
	HoverBtn(MinBtn)
	HoverBtn(CloseBtn)

	local SearchWrap = New("Frame", {
		Name = "Search",
		Size = UDim2.fromOffset(232, 34),
		Position = UDim2.new(1, -84, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = C.card,
		BackgroundTransparency = 0.15,
		Parent = Top,
	})
	Corner(SearchWrap, UDim.new(0, 17))
	local SearchStroke = Stroke(SearchWrap, C.lineSoft, 1, 0.35)
	ctx.SearchWrap = SearchWrap

	local Mag = New("Frame", {
		Size = UDim2.fromOffset(9, 9),
		Position = UDim2.new(0, 16, 0.5, -1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = SearchWrap,
	})
	local magStroke = Stroke(Mag, C.dim, 1.5, 0)
	Corner(Mag, UDim.new(1, 0))
	local magHandle = Bar(SearchWrap, 5, 1.6, 45, C.dim, 0, UDim2.new(0, 24.5, 0.5, 5.5), Vector2.new(0.5, 0.5))

	local SearchBox = New("TextBox", {
		Name = "SearchBox",
		Size = UDim2.new(1, -62, 1, 0),
		Position = UDim2.new(0, 30, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		PlaceholderText = "Tìm chức năng...",
		PlaceholderColor3 = C.faint,
		TextColor3 = C.text,
		Font = Font.Medium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		ClearTextOnFocus = false,
		Parent = SearchWrap,
	})
	ctx.SearchBox = SearchBox

	local ClearBtn = New("TextButton", {
		Name = "Clear",
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = C.line,
		BackgroundTransparency = 0.35,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = SearchWrap,
	})
	Corner(ClearBtn, UDim.new(1, 0))
	Bar(ClearBtn, 1.4, 6, 45, C.text, 0.15)
	Bar(ClearBtn, 1.4, 6, -45, C.text, 0.15)

	local function SetSearchFocus(focused)
		local targetColor = focused and C.acc or C.lineSoft
		local targetBg = focused and C.cardHover or C.card
		Tw(SearchStroke, 0.2, {Color = targetColor, Transparency = focused and 0.35 or 0.35})
		Tw(SearchWrap, 0.2, {BackgroundColor3 = targetBg, BackgroundTransparency = focused and 0.02 or 0.15})
		Tw(magStroke, 0.2, {Color = focused and C.acc or C.dim})
		Tw(magHandle, 0.2, {BackgroundColor3 = focused and C.acc or C.dim})
		if not focused then HideTooltip() end
	end

	SearchBox.Focused:Connect(function() SetSearchFocus(true) end)
	SearchBox.FocusLost:Connect(function() SetSearchFocus(false) end)
	SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local has = #SearchBox.Text > 0
		if ClearBtn.Visible ~= has then
			ClearBtn.Visible = true
			ClearBtn.Size = UDim2.fromOffset(0, 0)
			Tw(ClearBtn, 0.18, {Size = UDim2.fromOffset(has and 16 or 0, has and 16 or 0)}, Enum.EasingStyle.Back)
			task.delay(0.18, function()
				if not has then ClearBtn.Visible = false end
			end)
		end
	end)
	ClearBtn.Activated:Connect(function()
		SearchBox:CaptureFocus()
		SearchBox.Text = ""
	end)
	SearchBox.MouseEnter:Connect(function()
		if not SearchBox:IsFocused() then
			Tw(SearchStroke, 0.18, {Color = C.line})
		end
	end)
	SearchBox.MouseLeave:Connect(function()
		if not SearchBox:IsFocused() then
			Tw(SearchStroke, 0.18, {Color = C.lineSoft})
		end
	end)

	local Side = New("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, SIDEBAR_W, 1, -TOPBAR_H),
		Position = UDim2.new(0, 0, 0, TOPBAR_H),
		BackgroundTransparency = 1,
		Parent = Root,
	})
	ctx.Sidebar = Side

	local SideLine = New("Frame", {
		Size = UDim2.new(0, 1, 1, -24),
		Position = UDim2.new(0, SIDEBAR_W, 0, 12),
		BackgroundColor3 = C.lineSoft,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = Root,
	})
	Grad(SideLine, 90, C.lineSoft, C.lineSoft, NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 1),
		NumberSequenceKeypoint.new(0.15, 0.4),
		NumberSequenceKeypoint.new(0.85, 0.4),
		NumberSequenceKeypoint.new(1.0, 1),
	}))

	local TabScroll = New("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 1, -52),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = C.accDim,
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Parent = Side,
	})
	Pad(TabScroll, 12, 10, 10, 10)
	List(TabScroll, 6)
	ctx.TabScroll = TabScroll

	local Status = New("Frame", {
		Name = "Status",
		Size = UDim2.new(1, -24, 0, 36),
		Position = UDim2.new(0, 12, 1, -12),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = C.card,
		BackgroundTransparency = 0.35,
		Parent = Side,
	})
	Corner(Status, UDim.new(0, 10))
	Stroke(Status, C.lineSoft, 1, 0.5)
	local statusDotGlow = Dot(Status, 14, C.acc, 0.75, UDim2.new(0, 17, 0.5, 0))
	local statusDot = Dot(Status, 6, C.acc, 0, UDim2.new(0, 17, 0.5, 0))
	Lib:Accent(statusDot, "BackgroundColor3")
	Lib:Accent(statusDotGlow, "BackgroundColor3")
	local dotPulse = TweenService:Create(statusDotGlow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.95})
	dotPulse:Play()
	table.insert(ctx.Connections, {Disconnect = function() dotPulse:Cancel() end})

	local statusText = New("TextLabel", {
		Size = UDim2.new(1, -34, 1, 0),
		Position = UDim2.new(0, 30, 0, 0),
		BackgroundTransparency = 1,
		Text = "Aurora v" .. Lib.Version,
		TextColor3 = C.dim,
		Font = Font.Medium,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = Status,
	})
	ctx.StatusText = statusText

	local Content = New("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -(SIDEBAR_W + 28), 1, -(TOPBAR_H + 20)),
		Position = UDim2.new(0, SIDEBAR_W + 14, 0, TOPBAR_H + 6),
		BackgroundColor3 = C.inset,
		ClipsDescendants = true,
		Parent = Root,
	})
	Corner(Content, UDim.new(0, 14))
	Stroke(Content, C.lineSoft, 1, 0.45)
	ctx.Content = Content

	local insetSheen = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = Content,
	})
	Grad(insetSheen, 90, C.white, C.accLight, NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.995),
		NumberSequenceKeypoint.new(1.0, 1),
	}))

	local Empty = New("Frame", {
		Name = "EmptyState",
		Size = UDim2.fromOffset(300, 120),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = Content,
	})
	local emptyCircle = New("Frame", {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.card,
		Parent = Empty,
	})
	Corner(emptyCircle, UDim.new(1, 0))
	Stroke(emptyCircle, C.lineSoft, 1, 0.3)
	local em = New("Frame", {Size = UDim2.fromOffset(13, 13), Position = UDim2.fromScale(0.5, 0.46), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = emptyCircle})
	Corner(em, UDim.new(1, 0))
	Stroke(em, C.faint, 1.8, 0)
	Bar(emptyCircle, 7, 2, 45, C.faint, 0, UDim2.new(0.5, 8, 0.5, 8), Vector2.new(0.5, 0.5))

	local emptyTitle = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 0, 58),
		BackgroundTransparency = 1,
		Text = "Không tìm thấy chức năng",
		TextColor3 = C.text,
		Font = Font.Bold,
		TextSize = 14,
		Parent = Empty,
	})
	local emptySub = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.new(0, 0, 0, 80),
		BackgroundTransparency = 1,
		Text = "Thử từ khóa khác nhé",
		TextColor3 = C.dim,
		Font = Font.Regular,
		TextSize = 12,
		TextWrapped = true,
		Parent = Empty,
	})
	ctx.Empty = Empty
	ctx.EmptyScale = Scale(Empty, 1)

	local Resizer = New("TextButton", {
		Name = "Resizer",
		Size = UDim2.fromOffset(22, 22),
		Position = UDim2.new(1, -6, 1, -6),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = Root,
	})
	local rz1 = Bar(Resizer, 5, 1.6, 45, C.faint, 0.35, UDim2.new(1, -6, 1, -6), Vector2.new(1, 1))
	local rz2 = Bar(Resizer, 9, 1.6, 45, C.faint, 0.35, UDim2.new(1, -6, 1, -6), Vector2.new(1, 1))
	local rz3 = Bar(Resizer, 13, 1.6, 45, C.faint, 0.35, UDim2.new(1, -6, 1, -6), Vector2.new(1, 1))

	rz1.Position = UDim2.new(1, -7, 1, -11)
	rz2.Position = UDim2.new(1, -5, 1, -5)
	rz3.Position = UDim2.new(1, -14, 1, -14)

	Resizer.MouseEnter:Connect(function()
		for _, b in ipairs({rz1, rz2, rz3}) do Tw(b, 0.15, {BackgroundColor3 = C.acc, BackgroundTransparency = 0}) end
	end)
	Resizer.MouseLeave:Connect(function()
		for _, b in ipairs({rz1, rz2, rz3}) do Tw(b, 0.15, {BackgroundColor3 = C.faint, BackgroundTransparency = 0.35}) end
	end)

	local resizing = false
	local rStart, rSize
	Resizer.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			rStart = input.Position
			rSize = Root.Size
		end
	end)
	ctx:Conn(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if resizing then
				resizing = false
				Settings.W = Root.Size.X.Offset
				Settings.H = Root.Size.Y.Offset
				SaveSettings()
			end
		end
	end)
	ctx:Conn(UserInputService.InputChanged, function(input)
		if not resizing then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			local d = input.Position - rStart
			Root.Size = UDim2.fromOffset(
				math.clamp(rSize.X.Offset + d.X / currentScale, MIN_W, MAX_W),
				math.clamp(rSize.Y.Offset + d.Y / currentScale, MIN_H, MAX_H)
			)
		end
	end)

	local OrbGlow = New("Frame", {
		Name = "OrbGlow",
		Size = UDim2.fromOffset(76, 76),
		Position = UDim2.new(1, -96, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.acc,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 199,
		Parent = Gui,
	})
	Corner(OrbGlow, UDim.new(1, 0))
	Lib:Accent(OrbGlow, "BackgroundColor3")

	local Orb = New("Frame", {
		Name = "Orb",
		Size = UDim2.fromOffset(54, 54),
		Position = UDim2.new(1, -96, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.acc,
		BackgroundTransparency = 0.06,
		Visible = false,
		ZIndex = 200,
		Parent = Gui,
	})
	Corner(Orb, UDim.new(1, 0))
	local orbGrad = Grad(Orb, 135, C.accLight, C.accDim)
	Lib:OnAccent(function() orbGrad.Color = ColorSequence.new(C.accLight, C.accDim) end)
	Lib:Accent(Stroke(Orb, C.accLight, 1.5, 0.45), "Color", "light")

	local orbLines = {}
	for i = 1, 3 do
		local w = (i == 2) and 15 or 19
		local b = Bar(Orb, w, 2.2, 0, C.onAcc, 0, UDim2.new(0.5, 0, 0.5, (i - 2) * 6), Vector2.new(0.5, 0.5))
		Lib:Accent(b, "BackgroundColor3", "on")
		table.insert(orbLines, b)
	end

	local OrbHit = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 201,
		Parent = Orb,
	})
	ctx.Orb = Orb
	ctx.OrbGlow = OrbGlow
	ctx.OrbLines = orbLines

	local orbPulse = TweenService:Create(OrbGlow, TweenInfo.new(1.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.96})
	orbPulse:Play()
	table.insert(ctx.Connections, {Disconnect = function() orbPulse:Cancel() end})

	local orbWasDragged = MakeDraggable(Orb, OrbHit)

	local Window = {
		Name = TitleText,
		SubName = SubText,
		Tabs = ctx.Tabs,
		Flags = {},
		Minimized = false,
		SelectedTab = 1,
		Type = "Window",
	}
	ctx.Window = Window

	function ctx:RelayoutTabs()
		local count = #self.Tabs
		local height, iconSize, textSize, gap
		if count <= 8 then
			height, iconSize, textSize, gap = 40, 24, 12, 6
		elseif count <= 12 then
			height, iconSize, textSize, gap = 36, 22, 11.5, 5
		else
			height, iconSize, textSize, gap = 32, 20, 11, 4
		end
		local layout = self.TabScroll:FindFirstChildOfClass("UIListLayout")
		if layout then layout.Padding = UDim.new(0, gap) end
		for _, tab in ipairs(self.Tabs) do
			local btn = tab.Button
			if btn then
				Tw(btn, 0.18, {Size = UDim2.new(1, 0, 0, height)})
				if tab.IconBox then
					tab.IconBox.Size = UDim2.fromOffset(iconSize, iconSize)
					tab.IconBox.Position = UDim2.new(0, 9, 0.5, 0)
				end
				if tab.Label then
					tab.Label.TextSize = textSize
					tab.Label.Position = UDim2.new(0, iconSize + 17, 0, 0)
					tab.Label.Size = UDim2.new(1, -(iconSize + 22), 1, 0)
				end
				if tab.IconImage then
					tab.IconImage.Size = UDim2.fromOffset(iconSize - 9, iconSize - 9)
				end
				if tab.IconLetter then
					tab.IconLetter.TextSize = math.max(10, textSize - 1)
				end
				tab.TabHeight = height
			end
		end
	end

	Window.Elements = {
		ContainerHolder = Content,
		TabsContainer = TabScroll,
		TopBar = Top,
		MainFrame = Root,
		SearchBox = SearchBox,
	}

	function Window:GetElements()
		return self.Elements
	end

	function Window:SetTitle(text)
		Title.Text = text
		self.Name = text
		self.Title = text
		LogoText.Text = string.upper(string.sub(tostring(text), 1, 1))
	end

	function Window:SetSubTitle(text)
		SubTitle.Text = text
		self.SubName = text
		self.SubTitle = text
	end

	local blurEffect
	function Window:SetBlur(enabled, size)
		if enabled then
			if not blurEffect or not blurEffect.Parent then
				blurEffect = New("BlurEffect", {Name = "AuroraBlur", Size = 0, Parent = Lighting})
			end
			Tw(blurEffect, 0.35, {Size = size or 14})
		elseif blurEffect then
			local effect = blurEffect
			blurEffect = nil
			Tw(effect, 0.3, {Size = 0})
			task.delay(0.35, function() effect:Destroy() end)
		end
	end

	function Window:GetTitle() return Title.Text end
	function Window:GetSubTitle() return SubTitle.Text end

	local savedSize = Root.Size
	local animating = false

	local function SetOrbVisible(state)
		Orb.Visible = state
		OrbGlow.Visible = state
		if state then
			Orb.BackgroundTransparency = 1
			Tw(Orb, 0.28, {BackgroundTransparency = 0.06})
		end
	end
	ctx.SetOrbVisible = SetOrbVisible
	ctx.RefreshOrb = function()
		local visible = Window.Minimized or ctx.OrbAlways == true or IsMobile()
		SetOrbVisible(visible)
	end

	local restoreIcon = function(minimized)
		minBarV.Visible = minimized
		if minimized then
			Tw(minBarH, 0.2, {Rotation = 0})
			minBarV.Rotation = 0
			minBarV.Size = UDim2.fromOffset(2, 0)
			Tw(minBarV, 0.25, {Size = UDim2.fromOffset(2, 10)}, Enum.EasingStyle.Back)
		else
			minBarV.Size = UDim2.fromOffset(2, 0)
		end
	end

	function Window:Minimize()
		if animating then return end
		animating = true
		self.Minimized = not self.Minimized

		if self.Minimized then
			savedSize = Root.Size
			local w = Root.Size.X.Offset
			Tw(Root, 0.32, {Size = UDim2.fromOffset(w, TOPBAR_H)}, Enum.EasingStyle.Quint)
			Tw(Resizer, 0.15, {BackgroundTransparency = 1})
			task.delay(0.16, function()
				Side.Visible = false
				Content.Visible = false
				Resizer.Visible = false
			end)
			task.delay(0.3, function()
				animating = false
				ctx.RefreshOrb()
			end)
		else
			Side.Visible = true
			Content.Visible = true
			Resizer.Visible = true
			Tw(Root, 0.34, {Size = savedSize}, Enum.EasingStyle.Quint)
			ctx.RefreshOrb()
			task.delay(0.34, function() animating = false end)
		end
		restoreIcon(self.Minimized)
	end

	OrbHit.Activated:Connect(function()
		if orbWasDragged and orbWasDragged() then return end
		Window:Minimize()
	end)

	local DragArea = New("Frame", {
		Name = "DragArea",
		Size = UDim2.new(1, -350, 0, TOPBAR_H),
		BackgroundTransparency = 1,
		Active = true,
		Parent = Top,
	})
	local dragWasMoved = MakeDraggable(Root, DragArea)
	local userMoved = false
	ctx:Conn(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragWasMoved and dragWasMoved() then userMoved = true end
		end
	end)
	ctx.UserMoved = function() return userMoved end

	function Window:Destroy()
		for _, c in ipairs(self._extraConnections or {}) do
			pcall(function() c:Disconnect() end)
		end
		for _, c in ipairs(ctx.Connections) do
			pcall(function() c:Disconnect() end)
		end
		pcall(function()
			glowTween:Cancel()
			orbPulse:Cancel()
			dotPulse:Cancel()
		end)
		if blurEffect then
			pcall(function() blurEffect:Destroy() end)
		end
		Gui:Destroy()
		local index = table.find(Lib._guis, Gui)
		if index then table.remove(Lib._guis, index) end
	end

	local ConfirmDialog
	function Window:Close()
		if ConfirmDialog and not ConfirmDialog.Closed then return end
		ConfirmDialog = ctx:Dialog({
			Title = "Đóng giao diện?",
			Content = "Bạn có chắc muốn đóng UI không?",
			Options = {
				{ Title = "Đóng", Callback = function() Window:Destroy() end },
				{ Title = "Hủy" },
			},
		})
		ConfirmDialog.OnClose = function() ConfirmDialog = nil end
	end

	CloseBtn.Activated:Connect(function() Window:Close() end)
	MinBtn.Activated:Connect(function() Window:Minimize() end)

	Root.Size = UDim2.fromOffset(StartW * 0.94, StartH * 0.94)
	CenterRoot()
	local openScale = Scale(Root, 0.94)
	Tw(Root, 0.42, {Size = UDim2.fromOffset(StartW, StartH)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Tw(openScale, 0.42, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	task.delay(0.44, function()
		if not ctx.UserMoved() then CenterRoot() end
	end)
	Root.BackgroundTransparency = 1
	Tw(Root, 0.3, {BackgroundTransparency = 0})

	if config.Blur ~= false then
		Window:SetBlur(true, config.BlurSize or 12)
	end

	ctx.SelectTab = function(_, tab, instant)
		return ShellAPI.SelectTab(ctx, tab, instant)
	end

	return ctx
end

local VI_GROUPS = {
	{ "a", "àáảãạăằắẳẵặâầấẩẫậ" },
	{ "e", "èéẻẽẹêềếểễệ" },
	{ "i", "ìíỉĩị" },
	{ "o", "òóỏõọôồốổỗộơờớởỡợ" },
	{ "u", "ùúủũụưừứửữự" },
	{ "y", "ỳýỷỹỵ" },
	{ "d", "đ" },
}
local VI_MAP = {}
for _, group in ipairs(VI_GROUPS) do
	for _, code in utf8.codes(group[2]) do
		VI_MAP[code] = group[1]
	end
end

local function Norm(str)
	str = tostring(str):lower()
	local out = {}
	for _, code in utf8.codes(str) do
		local mapped = VI_MAP[code]
		if mapped then
			table.insert(out, mapped)
		else
			table.insert(out, utf8.char(code))
		end
	end
	return (table.concat(out):gsub("[%s%p%c]", ""))
end

local function EscapeRich(str)
	return (str:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function ApplyHighlight(label, rawText, query)
	if query == "" then
		label.RichText = false
		label.Text = rawText
		return
	end
	local lower = rawText:lower()
	local s, e = string.find(lower, query, 1, true)
	if not s then
		label.RichText = false
		label.Text = rawText
		return
	end
	label.RichText = true
	label.Text = EscapeRich(string.sub(rawText, 1, s - 1))
		.. '<font color="' .. Library:Hex(C.acc) .. '">' .. EscapeRich(string.sub(rawText, s, e)) .. "</font>"
		.. EscapeRich(string.sub(rawText, e + 1))
end

local function RegisterEntry(ctx, entry)
	entry.SearchText = Norm(entry.Title) .. " " .. Norm(entry.Desc or "")
	entry.KindText = Norm(entry.Kind or "")
	table.insert(ctx.SearchIndex, entry)
	if not entry.IsSection and entry.Tab and entry.Tab.BumpCount then
		entry.Tab:BumpCount()
	end
	return entry
end

local function ShowEntry(entry, state, animate)
	local frame = entry.Frame
	if not frame then return end
	if state then
		if not frame.Visible then
			frame.Visible = true
			if animate and entry.Scale then
				entry.Scale.Scale = 0.96
				Tw(entry.Scale, 0.24, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			end
		end
	else
		frame.Visible = false
	end
end

local function ApplySearch(ctx, rawQuery)
	local query = tostring(rawQuery or "")
	local clean = Norm(query)
	ctx.SearchQuery = query

	local index = ctx.SearchIndex

	if clean == "" then
		for _, entry in ipairs(index) do
			ShowEntry(entry, true, false)
			if entry.Label then ApplyHighlight(entry.Label, entry.LabelText, "") end
		end
		for _, tab in ipairs(ctx.Tabs) do tab:SetVisibleAnimated(true) end
		ctx.Empty.Visible = false
		return
	end

	local hits = {}
	local sectionHits = {}
	local tabHits = {}
	local tabNameHit = {}
	local lastSectionOfTab = {}

	for _, tab in ipairs(ctx.Tabs) do
		if string.find(Norm(tab.Name), clean, 1, true) or string.find(Norm(tab.Description or ""), clean, 1, true) then
			tabNameHit[tab] = true
			tabHits[tab] = true
		end
	end

	for _, entry in ipairs(index) do
		if entry.IsSection then
			lastSectionOfTab[entry.Tab] = entry
			if string.find(entry.SearchText, clean, 1, true) then
				hits[entry] = true
				sectionHits[entry] = true
				tabHits[entry.Tab] = true
			end
		else
			local section = lastSectionOfTab[entry.Tab]
			entry.Section = section
			local matched = string.find(entry.SearchText, clean, 1, true) ~= nil
				or string.find(entry.KindText, clean, 1, true) ~= nil
			if matched then
				hits[entry] = true
				tabHits[entry.Tab] = true
				if section then sectionHits[section] = true end
			end
		end
	end

	local total = 0
	for _, entry in ipairs(index) do
		if not entry.IsSection and (hits[entry] or tabNameHit[entry.Tab]) then
			total = total + 1
		end
	end

	for _, entry in ipairs(index) do
		local visible
		if entry.IsSection then
			visible = sectionHits[entry] == true or tabNameHit[entry.Tab] == true
		else
			visible = hits[entry] == true or tabNameHit[entry.Tab] == true
		end
		ShowEntry(entry, visible, true)
		if entry.Label then
			ApplyHighlight(entry.Label, entry.LabelText, hits[entry] and query or "")
		end
	end

	if total > 0 then
		for _, tab in ipairs(ctx.Tabs) do
			tab:SetVisibleAnimated(tabHits[tab] == true)
		end
	else
		for _, tab in ipairs(ctx.Tabs) do
			tab:SetVisibleAnimated(true)
		end
	end

	local current = ctx.CurrentTab
	if current and not tabHits[current] then
		for _, tab in ipairs(ctx.Tabs) do
			if tabHits[tab] then
				ctx:SelectTab(tab)
				break
			end
		end
	end

	if total == 0 then
		if not ctx.Empty.Visible then
			ctx.Empty.Visible = true
			ctx.EmptyScale.Scale = 0.9
			Tw(ctx.EmptyScale, 0.28, {Scale = 1}, Enum.EasingStyle.Back)
		end
	else
		ctx.Empty.Visible = false
	end
end

local function NewCard(tab, cfg)
	cfg = cfg or {}
	local height = cfg.Height or 56
	local rightW = cfg.RightWidth or 0

	local card = New(cfg.Button and "TextButton" or "Frame", {
		Name = cfg.Name or "Option",
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = cfg.BgColor or C.card,
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Active = true,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = tab.NextOrder(),
		Parent = tab.Scroll,
	})
	Corner(card, UDim.new(0, 11))
	local cardStroke = Stroke(card, C.lineSoft, 1, 0.35)
	local cardGrad = Grad(card, 90, C.cardTop, C.card, NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.0),
		NumberSequenceKeypoint.new(1.0, 0.55),
	}))

	local accentBar = New("Frame", {
		Size = UDim2.new(0, 3, 0, 0),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.acc,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(accentBar, UDim.new(1, 0))
	Library:Accent(accentBar, "BackgroundColor3")

	local title = New("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		Text = cfg.Title or "",
		TextColor3 = C.text,
		Font = Font.Medium,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 16, 0, cfg.TitleY or (cfg.Desc and 9 or (height - 20) / 2)),
		Size = UDim2.new(1, -(16 + rightW + (rightW > 0 and 26 or 16)), 0, 20),
		Parent = card,
	})

	local desc
	if cfg.Desc and #tostring(cfg.Desc) > 0 then
		desc = New("TextLabel", {
			Name = "Desc",
			BackgroundTransparency = 1,
			Text = cfg.Desc,
			TextColor3 = C.dim,
			Font = Font.Regular,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.new(0, 16, 0, 29),
			Size = UDim2.new(1, -(16 + rightW + (rightW > 0 and 26 or 16)), 0, 14),
			Parent = card,
		})
		desc.MouseEnter:Connect(function()
			if not desc.TextFits and TooltipGui then
				ShowTooltip(tab.Gui, desc.Text)
			end
		end)
		desc.MouseLeave:Connect(HideTooltip)
	end

	local uiscale = Scale(card, 1)

	local hovering = false
	local function setHover(state)
		hovering = state
		Tw(card, 0.18, {
			BackgroundColor3 = state and C.cardHover or (cfg.BgColor or C.card),
			BackgroundTransparency = card.BackgroundTransparency,
		})
		Tw(cardStroke, 0.18, {
			Color = state and C.line or C.lineSoft,
			Transparency = state and 0.2 or 0.35,
		})
		Tw(accentBar, 0.2, {Size = UDim2.new(0, 3, 0, state and (height - 24) or 0)})
		Tw(uiscale, 0.2, {Scale = state and 1.006 or 1})
	end

	if not cfg.Button then
		card.MouseEnter:Connect(function() setHover(true) end)
		card.MouseLeave:Connect(function() setHover(false) end)
	else
		card.MouseEnter:Connect(function() setHover(true) end)
		card.MouseLeave:Connect(function() setHover(false) end)
	end

	local function press()
		Tw(uiscale, 0.08, {Scale = 0.988}, Enum.EasingStyle.Quad)
	end
	local function release()
		Tw(uiscale, 0.22, {Scale = hovering and 1.006 or 1}, Enum.EasingStyle.Back)
	end
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			press()
		end
	end)
	card.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end)

	local api = {
		Frame = card,
		Title = title,
		Desc = desc,
		Scale = uiscale,
		Stroke = cardStroke,
		Gradient = cardGrad,
		AccentBar = accentBar,
	}

	function api:SetTitle(text)
		title.Text = text
		self.TitleText = text
	end

	function api:SetTitleColor(color)
		Tw(title, 0.2, {TextColor3 = color})
	end

	table.insert(tab.Cards, api)
	return api
end

local OptionBuilders = {}

local function MakeTab(ctx, config)
	config = config or {}
	local name = config[1] or config.Name or config.Title or "Tab"
	local icon = config.Icon or config.Image or config[2]
	local description = config.Description or config.Desc

	local tab = {
		Name = name,
		Icon = icon,
		Description = description,
		Index = #ctx.Tabs + 1,
		Gui = ctx.Gui,
		Selected = false,
		Cards = {},
		Items = {},
		Order = 0,
		Visible = true,
		Type = "Tab",
	}

	local orderCounter = 0
	function tab.NextOrder()
		orderCounter = orderCounter + 1
		tab.Order = orderCounter
		return orderCounter
	end

	local btn = New("TextButton", {
		Name = "TabButton",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = C.cardHover,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = tab.Index,
		Parent = ctx.TabScroll,
	})
	Corner(btn, UDim.new(0, 10))
	local btnStroke = Stroke(btn, C.line, 1, 1)
	local btnScale = Scale(btn, 1)
	tab.Button = btn
	tab.ButtonStroke = btnStroke
	tab.ButtonScale = btnScale

	local indicator = New("Frame", {
		Size = UDim2.new(0, 3, 0, 0),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.acc,
		BorderSizePixel = 0,
		Parent = btn,
	})
	Corner(indicator, UDim.new(1, 0))
	Library:Accent(indicator, "BackgroundColor3")
	tab.Indicator = indicator

	local iconBox = New("Frame", {
		Name = "IconBox",
		Size = UDim2.fromOffset(24, 24),
		Position = UDim2.new(0, 9, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.lineSoft,
		BackgroundTransparency = 0.5,
		Parent = btn,
	})
	Corner(iconBox, UDim.new(0, 7))
	tab.IconBox = iconBox

	local hasIcon = type(icon) == "string" and string.sub(icon, 1, 13) == "rbxassetid://"
	if hasIcon then
		local img = New("ImageLabel", {
			Size = UDim2.fromOffset(15, 15),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = icon,
			ImageColor3 = C.dim,
			Parent = iconBox,
		})
		tab.IconImage = img
	else
		local letter = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = string.upper(string.sub(tostring(name), 1, 1)),
			Font = Font.Bold,
			TextSize = 12,
			TextColor3 = C.dim,
			Parent = iconBox,
		})
		tab.IconLetter = letter
	end

	local label = New("TextLabel", {
		Size = UDim2.new(1, -46, 1, 0),
		Position = UDim2.new(0, 41, 0, 0),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = C.dim,
		Font = Font.Medium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = btn,
	})
	tab.Label = label

	local container
	local isCanvas = pcall(function()
		container = New("CanvasGroup", {
			Name = "TabContent",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Visible = false,
			GroupTransparency = 1,
		})
	end)
	if not isCanvas or not container then
		container = New("Frame", {
			Name = "TabContent",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Visible = false,
		})
	end
	container.Parent = ctx.Content
	tab.Container = container
	tab.IsCanvas = isCanvas and container ~= nil and container.ClassName == "CanvasGroup"

	local header = New("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 1,
		Parent = container,
	})
	local headerBg = New("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = C.card,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Parent = header,
	})
	local headerBgGrad = Grad(headerBg, 90, C.cardTop, C.card, NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.55),
		NumberSequenceKeypoint.new(1.0, 0.95),
	}))

	local headerTitle = New("TextLabel", {
		Size = UDim2.new(1, -140, 0, 20),
		Position = UDim2.new(0, 18, 0, 11),
		BackgroundTransparency = 1,
		Text = name,
		TextColor3 = C.text,
		Font = Font.Bold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	local headerDesc = New("TextLabel", {
		Size = UDim2.new(1, -140, 0, 14),
		Position = UDim2.new(0, 18, 0, 32),
		BackgroundTransparency = 1,
		Text = description or "",
		TextColor3 = C.dim,
		Font = Font.Regular,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = header,
	})
	local countBadge = New("Frame", {
		Size = UDim2.fromOffset(0, 22),
		Position = UDim2.new(1, -16, 0, 15),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = C.card,
		BackgroundTransparency = 0.25,
		Parent = header,
	})
	Corner(countBadge, UDim.new(1, 0))
	Stroke(countBadge, C.lineSoft, 1, 0.4)
	Pad(countBadge, 11, 0, 11, 0)
	local countText = New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = C.dim,
		Font = Font.Medium,
		TextSize = 10,
		Parent = countBadge,
	})
	tab.CountBadge = countBadge
	tab.CountText = countText

	local headerLine = New("Frame", {
		Size = UDim2.new(1, -36, 0, 1),
		Position = UDim2.new(0, 18, 1, -1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = C.lineSoft,
		BorderSizePixel = 0,
		Parent = header,
	})
	Grad(headerLine, 0, C.acc, C.lineSoft, NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.25),
		NumberSequenceKeypoint.new(0.35, 0.75),
		NumberSequenceKeypoint.new(1.0, 1.0),
	}))
	Library:Accent(headerLine, "BackgroundColor3")

	local scroll = New("ScrollingFrame", {
		Name = "Elements",
		Size = UDim2.new(1, 0, 1, -54),
		Position = UDim2.new(0, 0, 0, 54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.accSoft,
		ScrollBarImageTransparency = 0.25,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollingEnabled = true,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Parent = container,
	})
	Pad(scroll, 14, 12, 10, 18)
	List(scroll, 8)
	tab.Scroll = scroll

	tab.HeaderTitle = headerTitle
	tab.HeaderDesc = headerDesc

	local function styleIdle()
		Tw(btn, 0.2, {BackgroundTransparency = 1})
		Tw(btnStroke, 0.2, {Transparency = 1, Color = C.line})
		Tw(label, 0.2, {TextColor3 = C.dim})
		Tw(iconBox, 0.2, {BackgroundTransparency = 0.5, BackgroundColor3 = C.lineSoft})
		Tw(indicator, 0.25, {Size = UDim2.new(0, 3, 0, 0)}, Enum.EasingStyle.Quint)
		Tw(btnScale, 0.2, {Scale = 1})
		if tab.IconImage then Tw(tab.IconImage, 0.2, {ImageColor3 = C.dim}) end
		if tab.IconLetter then Tw(tab.IconLetter, 0.2, {TextColor3 = C.dim}) end
	end

	local function styleSelected()
		Tw(btn, 0.22, {BackgroundTransparency = 0})
		Tw(btnStroke, 0.22, {Transparency = 0.55, Color = C.acc})
		Tw(label, 0.22, {TextColor3 = C.text})
		Tw(iconBox, 0.22, {BackgroundTransparency = 0.05, BackgroundColor3 = C.accSoft})
		Tw(indicator, 0.3, {Size = UDim2.new(0, 3, 0, 18)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Tw(btnScale, 0.25, {Scale = 1.015}, Enum.EasingStyle.Back)
		if tab.IconImage then Tw(tab.IconImage, 0.22, {ImageColor3 = C.accLight}) end
		if tab.IconLetter then Tw(tab.IconLetter, 0.22, {TextColor3 = C.accLight}) end

		btn.BackgroundColor3 = C.cardHover
	end

	ctx:Conn(btn.MouseEnter, function()
		if not tab.Selected then
			Tw(btn, 0.18, {BackgroundTransparency = 0.62, BackgroundColor3 = C.card})
			Tw(label, 0.18, {TextColor3 = C.text})
			if tab.IconImage then Tw(tab.IconImage, 0.18, {ImageColor3 = C.text}) end
			if tab.IconLetter then Tw(tab.IconLetter, 0.18, {TextColor3 = C.text}) end
			Tw(btnScale, 0.18, {Scale = 1.008})
		end
	end)
	ctx:Conn(btn.MouseLeave, function()
		if not tab.Selected then styleIdle() end
	end)
	ctx:Conn(btn.Activated, function()
		tab:Select()
	end)

	function tab:SetVisibleAnimated(state, instant)
		if self.BlockVisible then state = true end
		if self.Visible == state and instant ~= true then return end
		self.Visible = state
		if state then
			btn.Visible = true
			local h = self.TabHeight or 40
			Tw(btn, instant and 0 or 0.2, {Size = UDim2.new(1, 0, 0, h)}, Enum.EasingStyle.Quint)
			if instant then btn.Size = UDim2.new(1, 0, 0, h) end
		else
			Tw(btn, instant and 0 or 0.18, {Size = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Quint)
			if instant then
				btn.Size = UDim2.new(1, 0, 0, 0)
				btn.Visible = false
			else
				task.delay(0.18, function()
					if not self.Visible then btn.Visible = false end
				end)
			end
		end
	end

	function tab:Select()
		ctx:SelectTab(self)
	end

	tab.AddSection = function(_, cfg) return OptionBuilders.Section(ctx, tab, cfg) end
	tab.AddToggle = function(_, cfg) return OptionBuilders.Toggle(ctx, tab, cfg) end
	tab.AddSlider = function(_, cfg) return OptionBuilders.Slider(ctx, tab, cfg) end
	tab.AddDropdown = function(_, cfg) return OptionBuilders.Dropdown(ctx, tab, cfg) end
	tab.AddButton = function(_, cfg) return OptionBuilders.Button(ctx, tab, cfg) end
	tab.AddInput = function(_, cfg) return OptionBuilders.Input(ctx, tab, cfg) end
	tab.AddTextBox = tab.AddInput
	tab.AddKeybind = function(_, cfg) return OptionBuilders.Keybind(ctx, tab, cfg) end
	tab.AddParagraph = function(_, cfg, content) return OptionBuilders.Paragraph(ctx, tab, cfg, content) end

	function tab:BumpCount()
		self.Count = (self.Count or 0) + 1
		self:SetCount(self.Count)
	end

	function tab:SetCount(n)
		self.Count = n
		countText.Text = tostring(n) .. " mục"
		Tw(countBadge, 0.2, {Size = UDim2.fromOffset(math.max(52, 34 + #countText.Text * 5.4), 22)})
	end

	function tab:SetHeader(titleText, descText)
		if titleText then headerTitle.Text = titleText end
		if descText then headerDesc.Text = descText end
	end

	table.insert(ctx.Tabs, tab)
	tab.Title = name
	tab:SetVisibleAnimated(true, true)
	ctx:RelayoutTabs()

	if #ctx.Tabs == 1 then
		task.defer(function()
			ctx:SelectTab(tab, true)
		end)
	end

	return tab
end

function ShellAPI.SelectTab(ctx, tab, instant)
	if not tab or ctx.CurrentTab == tab then
		if tab then tab.Selected = true end
		return
	end

	local prev = ctx.CurrentTab
	ctx.CurrentTab = tab
	ctx.Window.SelectedTab = tab.Index

	if prev then
		prev.Selected = false

		Tw(prev.Button, 0.2, {BackgroundTransparency = 1})
		Tw(prev.ButtonStroke or prev.Button:FindFirstChildOfClass("UIStroke"), 0.2, {Transparency = 1})
		Tw(prev.Label, 0.2, {TextColor3 = C.dim})
		Tw(prev.IconBox, 0.2, {BackgroundTransparency = 0.5, BackgroundColor3 = C.lineSoft})
		Tw(prev.Indicator, 0.22, {Size = UDim2.new(0, 3, 0, 0)})
		Tw(prev.ButtonScale, 0.2, {Scale = 1})
		if prev.IconImage then Tw(prev.IconImage, 0.2, {ImageColor3 = C.dim}) end
		if prev.IconLetter then Tw(prev.IconLetter, 0.2, {TextColor3 = C.dim}) end

		if prev.IsCanvas then
			local tween = Tw(prev.Container, instant and 0 or 0.1, {GroupTransparency = 1})
			if tween then
				tween.Completed:Connect(function()
					prev.Container.Visible = false
				end)
			else
				prev.Container.Visible = false
			end
		else
			prev.Container.Visible = false
		end
	end

	tab.Selected = true
	Tw(tab.Button, 0.22, {BackgroundTransparency = 0, BackgroundColor3 = C.cardHover})
	Tw(tab.ButtonStroke or tab.Button:FindFirstChildOfClass("UIStroke"), 0.22, {Transparency = 0.55, Color = C.acc})
	Tw(tab.Label, 0.22, {TextColor3 = C.text})
	Tw(tab.IconBox, 0.22, {BackgroundTransparency = 0.05, BackgroundColor3 = C.accSoft})
	Tw(tab.Indicator, 0.3, {Size = UDim2.new(0, 3, 0, 18)}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	Tw(tab.ButtonScale, 0.25, {Scale = 1.015}, Enum.EasingStyle.Back)
	if tab.IconImage then Tw(tab.IconImage, 0.22, {ImageColor3 = C.accLight}) end
	if tab.IconLetter then Tw(tab.IconLetter, 0.22, {TextColor3 = C.accLight}) end

	tab.Container.Visible = true
	if tab.IsCanvas then
		tab.Container.GroupTransparency = instant and 0 or 1
		Tw(tab.Container, instant and 0 or 0.22, {GroupTransparency = 0})
	end

	pcall(function()
		local sf = ctx.TabScroll
		local btn = tab.Button
		if not btn.Visible then return end
		local rel = (btn.AbsolutePosition.Y - sf.AbsolutePosition.Y) + sf.CanvasPosition.Y
		local top = sf.CanvasPosition.Y
		local view = sf.AbsoluteSize.Y
		local h = btn.AbsoluteSize.Y
		if h <= 0 then h = 40 end
		if rel < top + 6 then
			sf.CanvasPosition = Vector2.new(0, math.max(0, rel - 6))
		elseif rel + h > top + view - 6 then
			sf.CanvasPosition = Vector2.new(0, math.max(0, rel + h - view + 6))
		end
	end)

	if not instant then
		for index, card in ipairs(tab.Cards) do
			if index <= 10 then
				card.Scale.Scale = 0.97
				task.delay((index - 1) * 0.012, function()
					Tw(card.Scale, 0.26, {Scale = 1}, Enum.EasingStyle.Back)
				end)
			end
		end
		tab.Scroll.CanvasPosition = Vector2.new(0, 0)
	end
end

OptionBuilders.Section = function(ctx, tab, cfg)
	if type(cfg) ~= "table" then cfg = { Title = cfg } end
	local title = cfg[1] or cfg.Name or cfg.Title or "MỤC"

	local holder = New("Frame", {
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1,
		Parent = tab.Scroll,
		LayoutOrder = tab.NextOrder(),
	})
	local holderScale = Scale(holder, 1)

	local dot = Dot(holder, 5, C.acc, 0, UDim2.new(0, 9, 0.5, 0))
	Library:Accent(dot, "BackgroundColor3")
	local dotGlow = Dot(holder, 13, C.acc, 0.82, UDim2.new(0, 9, 0.5, 0))
	dotGlow.ZIndex = 0
	dot.ZIndex = 1
	Library:Accent(dotGlow, "BackgroundColor3")

	local text = string.upper(title)
	local label = New("TextLabel", {
		Size = UDim2.new(0, 0, 0, 14),
		AutomaticSize = Enum.AutomaticSize.X,
		Position = UDim2.new(0, 21, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = C.dim,
		Font = Font.Bold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local textWidth = TextService:GetTextSize(text, 11, Font.Bold, Vector2.new(2000, 40)).X
	local lineX = 21 + textWidth + 10
	local line = New("Frame", {
		Size = UDim2.new(1, -(lineX + 2), 0, 1),
		Position = UDim2.new(0, lineX, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.line,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Grad(line, 0, C.lineSoft, C.lineSoft, NumberSequence.new({
		NumberSequenceKeypoint.new(0.0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.9),
		NumberSequenceKeypoint.new(1.0, 1.0),
	}))

	local section = {
		Title = title,
		Frame = holder,
		Holder = holder,
		Type = "Section",
	}

	function section:SetTitle(newTitle)
		title = newTitle
		text = string.upper(newTitle)
		label.Text = text
		local w = TextService:GetTextSize(text, 11, Font.Bold, Vector2.new(2000, 40)).X
		local x = 21 + w + 10
		line.Position = UDim2.new(0, x, 0.5, 0)
		line.Size = UDim2.new(1, -(x + 2), 0, 1)
		if self.Entry then self.Entry.Title = newTitle end
	end

	local entry = RegisterEntry(ctx, {
		Tab = tab,
		Frame = holder,
		Title = title,
		Kind = "section",
		IsSection = true,
		Scale = holderScale,
	})
	section.Entry = entry

	return section
end

OptionBuilders.Toggle = function(ctx, tab, cfg)
	cfg = cfg or {}
	local title = cfg[1] or cfg.Name or cfg.Title or "Toggle"
	local desc = cfg.Desc or cfg.Description
	local default = cfg[2]
	if cfg.Default ~= nil then default = cfg.Default end
	if default == nil then default = false end
	local callback = cfg[3] or cfg.Callback
	local flag = cfg[4] or cfg.Flag

	local card = NewCard(tab, {
		Title = title,
		Desc = desc,
		Height = desc and 58 or 48,
		RightWidth = 52,
	})

	local switch = New("Frame", {
		Name = "Switch",
		Size = UDim2.fromOffset(44, 24),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = C.lineSoft,
		Parent = card.Frame,
	})
	Corner(switch, UDim.new(1, 0))
	local switchStroke = Stroke(switch, C.line, 1, 0.4)

	local knob = New("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(0, 3, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.dim,
		Parent = switch,
	})
	Corner(knob, UDim.new(1, 0))
	local knobGlow = New("Frame", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.acc,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = knob,
	})
	Corner(knobGlow, UDim.new(1, 0))
	Library:Accent(knobGlow, "BackgroundColor3")

	local hit = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = switch,
	})

	local option = {
		Value = false,
		Title = title,
		Flag = flag,
		Type = "Toggle",
		Card = card,
	}
	local callbacks = {}
	ctx.OptionObjects = ctx.OptionObjects or {}
	if flag then ctx.OptionObjects[flag] = option end

	local function fire(value)
		if callback then
			task.spawn(function()
				local ok, err = pcall(callback, value)
				if not ok then warn("[Aurora] Toggle callback lỗi: " .. tostring(err)) end
			end)
		end
		for _, fn in ipairs(callbacks) do
			task.spawn(function()
				local ok, err = pcall(fn, value)
				if not ok then warn("[Aurora] Toggle callback lỗi: " .. tostring(err)) end
			end)
		end
	end

	local function radiusPulse()
		local ring = New("Frame", {
			Size = UDim2.fromOffset(18, 18),
			Position = knob.Position,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Parent = switch,
		})
		Corner(ring, UDim.new(1, 0))
		local ringStroke = Stroke(ring, C.acc, 2, 0.1)
		Library:Accent(ringStroke, "Color")
		Tw(ring, 0.5, {Size = UDim2.fromOffset(52, 52)}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Tw(ringStroke, 0.5, {Transparency = 1})
		task.delay(0.55, function() ring:Destroy() end)
	end

	local function paint(value)
		Tw(switch, 0.22, {BackgroundColor3 = value and C.acc or C.lineSoft})
		Tw(switchStroke, 0.22, {
			Color = value and C.accLight or C.line,
			Transparency = value and 0.5 or 0.4,
		})
		Tw(knob, 0.28, {
			Position = UDim2.new(0, value and 23 or 3, 0.5, 0),
			BackgroundColor3 = value and C.onAcc or C.dim,
		}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Tw(knobGlow, 0.25, {BackgroundTransparency = value and 0.55 or 1})
		Tw(card.AccentBar, 0.25, {Size = UDim2.new(0, 3, 0, value and 22 or 0)})
	end

	function option:Set(value, silent)
		value = value and true or false
		local changed = self.Value ~= value
		self.Value = value
		paint(value)
		if self.Flag then ctx.Window.Flags[self.Flag] = value end
		if changed and not silent then fire(value) end
		return self
	end

	option.SetValue = option.Set

	function option:Toggle()
		self:Set(not self.Value)
	end

	function option:AddCallback(fn)
		table.insert(callbacks, fn)
		return self
	end
	option.NewCallback = option.AddCallback
	option.SetCallback = option.AddCallback

	local debounce = -1e9
	local function hitToggle()
		if tick() - debounce < 0.15 then return end
		debounce = tick()
		option:Toggle()
	end
	hit.Activated:Connect(hitToggle)
	card.Frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			hitToggle()
		end
	end)

	option:Set(default == true, true)

	RegisterEntry(ctx, {
		Tab = tab,
		Frame = card.Frame,
		Title = title,
		Desc = desc,
		Kind = "toggle",
		Label = card.Title,
		LabelText = title,
		Scale = card.Scale,
	})

	return option
end

OptionBuilders.Slider = function(ctx, tab, cfg)
	cfg = cfg or {}
	local title = cfg[1] or cfg.Name or cfg.Title or "Slider"
	local desc = cfg.Desc or cfg.Description
	local min = cfg[2] or cfg.Min or 0
	local max = cfg[3] or cfg.Max or 100
	local step = cfg[4] or cfg.Increment or 1
	local default = cfg[5]
	if default == nil then default = cfg.Default end
	if default == nil then default = min end
	local callback = cfg[6] or cfg.Callback
	local flag = cfg[7] or cfg.Flag
	local suffix = cfg.Suffix or cfg.ValueName or ""

	if type(min) ~= "number" then min = 0 end
	if type(max) ~= "number" then max = 100 end
	if type(step) ~= "number" or step <= 0 then step = 1 end
	if max <= min then max = min + 1 end

	local cardH = desc and 78 or 68
	local card = NewCard(tab, {
		Title = title,
		Desc = desc,
		Height = cardH,
		RightWidth = 0,
		TitleY = desc and 9 or 10,
	})

	card.Title.Size = UDim2.new(1, -110, 0, 20)

	local badge = New("Frame", {
		Size = UDim2.fromOffset(72, 22),
		Position = UDim2.new(1, -16, 0, desc and 8 or 9),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = C.accSoft,
		BackgroundTransparency = 0.15,
		Parent = card.Frame,
	})
	Corner(badge, UDim.new(0, 8))
	local badgeStroke = Stroke(badge, C.acc, 1, 0.55)
	Library:Accent(badgeStroke, "Color")
	local badgeText = New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = C.accLight,
		Font = Font.Bold,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = badge,
	})
	Library:Accent(badgeText, "TextColor3", "light")

	local trackY = desc and 46 or 40
	local trackArea = New("TextButton", {
		Size = UDim2.new(1, -32, 0, 18),
		Position = UDim2.new(0, 16, 0, trackY),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = card.Frame,
	})
	local track = New("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.inset,
		Parent = trackArea,
	})
	Corner(track, UDim.new(1, 0))
	Stroke(track, C.lineSoft, 1, 0.2)

	local fill = New("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = C.acc,
		Parent = track,
	})
	Corner(fill, UDim.new(1, 0))
	local fillGrad = Grad(fill, 0, C.accDim, C.acc)
	Library:OnAccent(function() fillGrad.Color = ColorSequence.new(C.accDim, C.acc) end)

	local thumb = New("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.white,
		Parent = track,
	})
	Corner(thumb, UDim.new(1, 0))
	local thumbStroke = Stroke(thumb, C.acc, 2, 0)
	Library:Accent(thumbStroke, "Color")
	local thumbGlow = New("Frame", {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.acc,
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		ZIndex = 0,
		Parent = thumb,
	})
	Corner(thumbGlow, UDim.new(1, 0))
	Library:Accent(thumbGlow, "BackgroundColor3")

	local option = {
		Value = default,
		Min = min,
		Max = max,
		Title = title,
		Flag = flag,
		Type = "Slider",
		Card = card,
	}
	local callbacks = {}
	ctx.OptionObjects = ctx.OptionObjects or {}
	if flag then ctx.OptionObjects[flag] = option end

	local function fire(value)
		if callback then
			task.spawn(function()
				local ok, err = pcall(callback, value)
				if not ok then warn("[Aurora] Slider callback lỗi: " .. tostring(err)) end
			end)
		end
		for _, fn in ipairs(callbacks) do
			task.spawn(function()
				local ok, err = pcall(fn, value)
				if not ok then warn("[Aurora] Slider callback lỗi: " .. tostring(err)) end
			end)
		end
	end

	local function format(value)
		local text
		if step >= 1 then
			text = tostring(math.floor(value * 100 + 0.5) / 100)
		else
			text = string.format("%.2f", value)
		end
		if suffix ~= "" then
			return text .. suffix
		end
		return text
	end

	local function paint(value, animate)
		local alpha = (value - min) / (max - min)
		if animate then
			Tw(fill, 0.14, {Size = UDim2.new(alpha, 0, 1, 0)})
			Tw(thumb, 0.14, {Position = UDim2.new(alpha, 0, 0.5, 0)})
		else
			fill.Size = UDim2.new(alpha, 0, 1, 0)
			thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
		end
		badgeText.Text = format(value)
	end

	function option:Set(value, silent)
		value = tonumber(value) or min
		value = math.clamp(value, min, max)
		value = math.floor((value - min) / step + 0.5) * step + min
		value = math.clamp(value, min, max)
		local changed = math.abs(self.Value - value) > 1e-6
		self.Value = value
		paint(value, true)
		if self.Flag then ctx.Window.Flags[self.Flag] = value end
		if changed and not silent then fire(value) end
		return self
	end
	option.SetValue = option.Set

	function option:AddCallback(fn)
		table.insert(callbacks, fn)
		return self
	end
	option.NewCallback = option.AddCallback

	local dragging = false
	local function setFromX(x)
		local abs = trackArea.AbsolutePosition.X
		local w = trackArea.AbsoluteSize.X
		if w <= 0 then return end
		local alpha = math.clamp((x - abs) / w, 0, 1)
		option:Set(min + (max - min) * alpha)
	end

	trackArea.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			Tw(thumb, 0.15, {Size = UDim2.fromOffset(18, 18)}, Enum.EasingStyle.Back)
			Tw(thumbGlow, 0.15, {BackgroundTransparency = 0.55})
			setFromX(input.Position.X)
		end
	end)

	ctx:Conn(UserInputService.InputChanged, function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			setFromX(input.Position.X)
		end
	end)

	ctx:Conn(UserInputService.InputEnded, function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			Tw(thumb, 0.2, {Size = UDim2.fromOffset(14, 14)}, Enum.EasingStyle.Back)
			Tw(thumbGlow, 0.2, {BackgroundTransparency = 0.75})
		end
	end)

	option:Set(default, true)

	RegisterEntry(ctx, {
		Tab = tab,
		Frame = card.Frame,
		Title = title,
		Desc = desc,
		Kind = "slider",
		Label = card.Title,
		LabelText = title,
		Scale = card.Scale,
	})

	return option
end

OptionBuilders.Dropdown = function(ctx, tab, cfg)
	cfg = cfg or {}
	local title = cfg[1] or cfg.Name or cfg.Title or "Dropdown"
	local desc = cfg.Desc or cfg.Description
	local rawOptions = cfg[2] or cfg.Options or {}
	local default = cfg[3]
	if default == nil then default = cfg.Default end
	local callback = cfg[4] or cfg.Callback
	local multi = cfg.MultiSelect == true
	local flag = cfg[5] or cfg.Flag

	local entries = {}
	local function rebuildEntries(source)
		entries = {}
		if type(source) ~= "table" then return end
		if #source > 0 then
			for _, item in ipairs(source) do
				if type(item) == "table" then
					table.insert(entries, { value = item.Value or item.Name or item.Title, text = item.Name or item.Title or tostring(item.Value) })
				else
					table.insert(entries, { value = item, text = tostring(item) })
				end
			end
		else
			for key, value in pairs(source) do
				table.insert(entries, { value = key, text = tostring(key) })
			end
			table.sort(entries, function(a, b) return tostring(a.text) < tostring(b.text) end)
		end
	end
	rebuildEntries(rawOptions)

	local baseH = desc and 58 or 48
	local card = NewCard(tab, {
		Title = title,
		Desc = desc,
		Height = baseH,
		RightWidth = 158,
	})

	local pill = New("Frame", {
		Name = "Pill",
		Size = UDim2.fromOffset(150, 30),
		Position = UDim2.new(1, -16, 0, baseH / 2),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = C.inset,
		Parent = card.Frame,
	})
	Corner(pill, UDim.new(0, 9))
	local pillStroke = Stroke(pill, C.lineSoft, 1, 0.2)

	local valueText = New("TextLabel", {
		Size = UDim2.new(1, -42, 1, 0),
		Position = UDim2.new(0, 11, 0, 0),
		BackgroundTransparency = 1,
		Text = "...",
		TextColor3 = C.text,
		Font = Font.Medium,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = pill,
	})

	local chevA = Bar(pill, 7, 1.7, 45, C.dim, 0, UDim2.new(1, -17, 0.5, -2.5), Vector2.new(0.5, 0.5))
	local chevB = Bar(pill, 7, 1.7, -45, C.dim, 0, UDim2.new(1, -22, 0.5, -2.5), Vector2.new(0.5, 0.5))

	chevA.Position = UDim2.new(1, -20, 0.5, -2.2)
	chevB.Position = UDim2.new(1, -14, 0.5, -2.2)

	local pillHit = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = pill,
	})

	local panel = New("Frame", {
		Name = "Panel",
		Size = UDim2.new(1, -28, 0, 0),
		Position = UDim2.new(0, 14, 0, baseH),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = card.Frame,
	})
	local panelBg = New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.inset,
		Parent = panel,
	})
	Corner(panelBg, UDim.new(0, 10))
	Stroke(panelBg, C.lineSoft, 1, 0.15)

	local listFrame = New("ScrollingFrame", {
		Size = UDim2.new(1, -8, 1, -8),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.acc,
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = panelBg,
	})
	List(listFrame, 2)

	local option = {
		Value = multi and {} or nil,
		Title = title,
		Flag = flag,
		Type = "Dropdown",
		MultiSelect = multi,
		Options = {},
		Card = card,
		Opened = false,
	}
	local callbacks = {}
	ctx.OptionObjects = ctx.OptionObjects or {}
	if flag then ctx.OptionObjects[flag] = option end

	for _, entry in ipairs(entries) do
		option.Options[entry.value] = true
	end

	local function fire(value)
		if callback then
			task.spawn(function()
				local ok, err = pcall(callback, value)
				if not ok then warn("[Aurora] Dropdown callback lỗi: " .. tostring(err)) end
			end)
		end
		for _, fn in ipairs(callbacks) do
			task.spawn(function()
				local ok, err = pcall(fn, value)
				if not ok then warn("[Aurora] Dropdown callback lỗi: " .. tostring(err)) end
			end)
		end
	end

	local function selectedList()
		if multi then
			local out = {}
			for _, entry in ipairs(entries) do
				if option.Value[entry.value] then table.insert(out, tostring(entry.text)) end
			end
			return out
		end
		return nil
	end

	local function displayText()
		if multi then
			local list = selectedList()
			if #list == 0 then return "Chọn..." end
			if #list == 1 then return list[1] end
			return list[1] .. " +" .. (#list - 1)
		end
		if option.Value == nil then return "Chọn..." end
		return tostring(option.Value)
	end

	local function paint()
		valueText.Text = displayText()
		local active = multi and next(option.Value) ~= nil or (not multi and option.Value ~= nil)
		Tw(valueText, 0.2, {TextColor3 = active and C.text or C.dim})
		Tw(pillStroke, 0.2, {Color = active and C.acc or C.lineSoft, Transparency = active and 0.6 or 0.2})
	end

	local function rowVisible(entry)
		return entry.enabled ~= false
	end

	local closeSelf
	closeSelf = function()
		if not option.Opened then return end
		option.Opened = false
		if ctx.OpenDropdown == closeSelf then ctx.OpenDropdown = nil end
		Tw(card.Frame, 0.22, {Size = UDim2.new(1, 0, 0, baseH)}, Enum.EasingStyle.Quint)
		Tw(panel, 0.22, {Size = UDim2.new(1, -28, 0, 0)}, Enum.EasingStyle.Quint)
		Tw(chevA, 0.22, {Rotation = 45})
		Tw(chevB, 0.22, {Rotation = -45})
		Tw(pill, 0.2, {BackgroundColor3 = C.inset})
	end

	local function buildRows()
		for _, child in ipairs(listFrame:GetChildren()) do
			if child:IsA("GuiObject") then child:Destroy() end
		end

		local index = 0
		for _, entry in ipairs(entries) do
			if rowVisible(entry) then
				index = index + 1
				local isSelected
				if multi then
					isSelected = option.Value[entry.value] == true
				else
					isSelected = option.Value == entry.value
				end

				local row = New("TextButton", {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundColor3 = isSelected and C.accSoft or C.card,
					BackgroundTransparency = isSelected and 0.1 or 1,
					AutoButtonColor = false,
					Text = "",
					LayoutOrder = index,
					Parent = listFrame,
				})
				Corner(row, UDim.new(0, 8))

				local rowLabelX = multi and 32 or 12
				local rowLabel = New("TextLabel", {
					Size = UDim2.new(1, -(rowLabelX + 26), 1, 0),
					Position = UDim2.new(0, rowLabelX, 0, 0),
					BackgroundTransparency = 1,
					Text = tostring(entry.text),
					TextColor3 = isSelected and C.accLight or C.text,
					Font = Font.Medium,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					Parent = row,
				})

				if multi then
					local checkBg = New("Frame", {
						Size = UDim2.fromOffset(14, 14),
						Position = UDim2.new(0, 11, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundColor3 = isSelected and C.acc or C.lineSoft,
						Parent = row,
					})
					Corner(checkBg, UDim.new(0, 4))
					if isSelected then
						Bar(checkBg, 6, 1.6, 45, C.onAcc, 0, UDim2.new(0.5, -2, 0.5, 0), Vector2.new(0.5, 0.5))
						Bar(checkBg, 3, 1.6, -45, C.onAcc, 0, UDim2.new(0.5, -4.5, 0.5, 2), Vector2.new(0.5, 0.5))
					end
				elseif isSelected then
					local tick = New("Frame", {
						Size = UDim2.fromOffset(14, 14),
						Position = UDim2.new(1, -12, 0.5, 0),
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundTransparency = 1,
						Parent = row,
					})
					Bar(tick, 8, 1.7, 45, C.acc, 0, UDim2.new(0.5, -2, 0.5, 0), Vector2.new(0.5, 0.5))
					Bar(tick, 4, 1.7, -45, C.acc, 0, UDim2.new(0.5, -5, 0.5, 3), Vector2.new(0.5, 0.5))
				end

				row.MouseEnter:Connect(function()
					if not isSelected then
						Tw(row, 0.14, {BackgroundTransparency = 0.35, BackgroundColor3 = C.cardHover})
						Tw(rowLabel, 0.14, {TextColor3 = C.text})
						Tw(rowLabel, 0.14, {Position = UDim2.new(0, rowLabelX + 3, 0, 0)})
					end
				end)
				row.MouseLeave:Connect(function()
					if not isSelected then
						Tw(row, 0.14, {BackgroundTransparency = 1})
						Tw(rowLabel, 0.14, {Position = UDim2.new(0, rowLabelX, 0, 0)})
					end
				end)

				row.Activated:Connect(function()
					option._lock = tick()
					if multi then
						if option.Value[entry.value] then
							option.Value[entry.value] = nil
						else
							option.Value[entry.value] = true
						end
						paint()
						buildRows()
						if flag then ctx.Window.Flags[flag] = option.Value end
						fire(option.Value)
					else
						option.Value = entry.value
						paint()
						if flag then ctx.Window.Flags[flag] = option.Value end
						fire(option.Value)
						closeSelf()
					end
				end)
			end
		end
	end

	local function open()
		if option.Opened then return end
		if ctx.OpenDropdown and ctx.OpenDropdown ~= closeSelf then
			pcall(ctx.OpenDropdown)
		end
		option.Opened = true
		ctx.OpenDropdown = closeSelf

		buildRows()
		local count = 0
		for _, entry in ipairs(entries) do
			if rowVisible(entry) then count = count + 1 end
		end
		local rows = math.max(1, math.min(count, 5))
		local panelH = rows * 30 + (rows - 1) * 2 + 8

		Tw(card.Frame, 0.26, {Size = UDim2.new(1, 0, 0, baseH + panelH + 8)}, Enum.EasingStyle.Quint)
		Tw(panel, 0.26, {Size = UDim2.new(1, -28, 0, panelH)}, Enum.EasingStyle.Quint)
		Tw(chevA, 0.25, {Rotation = -45})
		Tw(chevB, 0.25, {Rotation = 45})
		Tw(pill, 0.2, {BackgroundColor3 = C.cardHover})
		Tw(pillStroke, 0.2, {Color = C.acc, Transparency = 0.45})

		local i = 0
		for _, row in ipairs(listFrame:GetChildren()) do
			if row:IsA("GuiObject") then
				i = i + 1
				row.BackgroundTransparency = 1
				local target = row.BackgroundTransparency
				row.BackgroundTransparency = 1
				task.delay(i * 0.02, function()
					if option.Opened and row.Parent then
						Tw(row, 0.18, {BackgroundTransparency = target})
					end
				end)
			end
		end
	end

	pillHit.Activated:Connect(function()
		if tick() - (option._lock or -1e9) < 0.12 then return end
		option._lock = tick()
		if option.Opened then closeSelf() else open() end
	end)
	card.Frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if tick() - (option._lock or -1e9) < 0.12 then return end
			option._lock = tick()
			if option.Opened then closeSelf() else open() end
		end
	end)

	ctx:Conn(UserInputService.InputBegan, function(input)
		if not option.Opened then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local mouse = UserInputService:GetMouseLocation()
		local function inside(gui)
			local pos = gui.AbsolutePosition
			local size = gui.AbsoluteSize
			return mouse.X >= pos.X and mouse.X <= pos.X + size.X and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y
		end
		if not inside(pill) and not inside(panel) and not inside(card.Frame) then
			closeSelf()
		end
	end)

	function option:Set(value, silent)
		if multi then
			local newValue = {}
			if type(value) == "table" then
				for _, v in ipairs(value) do newValue[v] = true end
			elseif type(value) == "string" then
				newValue[value] = true
			end
			self.Value = newValue
		else
			self.Value = value
		end
		paint()
		if self.Opened then buildRows() end
		if flag then ctx.Window.Flags[flag] = self.Value end
		if not silent then fire(self.Value) end
		return self
	end
	option.SetValue = option.Set

	function option:Refresh(newOptions)
		rebuildEntries(newOptions)
		self.Options = {}
		for _, entry in ipairs(entries) do
			self.Options[entry.value] = true
		end
		if multi then
			for key in pairs(self.Value) do
				if not self.Options[key] then self.Value[key] = nil end
			end
		end
		paint()
		if self.Opened then buildRows() end
		return self
	end
	option.RefreshOptions = function(self, list) return option:Refresh(list) end

	function option:Open() open() end
	function option:Close() closeSelf() end

	function option:AddCallback(fn)
		table.insert(callbacks, fn)
		return self
	end
	option.NewCallback = option.AddCallback

	if default ~= nil then
		option:Set(default, true)
	else
		if multi then
			option.Value = {}
		else
			option.Value = nil
		end
		paint()
	end

	RegisterEntry(ctx, {
		Tab = tab,
		Frame = card.Frame,
		Title = title,
		Desc = desc,
		Kind = "dropdown",
		Label = card.Title,
		LabelText = title,
		Scale = card.Scale,
	})

	return option
end

OptionBuilders.Button = function(ctx, tab, cfg)
	cfg = cfg or {}
	local title = cfg[1] or cfg.Name or cfg.Title or "Button"
	local desc = cfg.Desc or cfg.Description
	local callback = cfg[2] or cfg.Callback
	local cooldown = cfg.Debounce or cfg.Cooldown
	local lastClick = -1e9

	local card = NewCard(tab, {
		Title = title,
		Desc = desc,
		Height = desc and 56 or 46,
		RightWidth = 30,
		Button = true,
	})

	local arrowA = Bar(card.Frame, 7, 1.7, 45, C.faint, 0, UDim2.new(1, -22, 0.5, -2), Vector2.new(0.5, 0.5))
	local arrowB = Bar(card.Frame, 7, 1.7, -45, C.faint, 0, UDim2.new(1, -22, 0.5, 2), Vector2.new(0.5, 0.5))

	local lastPos
	card.Frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			lastPos = input.Position
		end
	end)

	card.Frame.MouseEnter:Connect(function()
		for _, b in ipairs({arrowA, arrowB}) do
			Tw(b, 0.16, {BackgroundColor3 = C.acc})
		end
		Tw(card.Title, 0.16, {TextColor3 = C.accLight})
		Tw(arrowA, 0.16, {Position = UDim2.new(1, -19, 0.5, -2)})
		Tw(arrowB, 0.16, {Position = UDim2.new(1, -19, 0.5, 2)})
	end)
	card.Frame.MouseLeave:Connect(function()
		for _, b in ipairs({arrowA, arrowB}) do
			Tw(b, 0.16, {BackgroundColor3 = C.faint})
		end
		Tw(card.Title, 0.16, {TextColor3 = C.text})
		Tw(arrowA, 0.16, {Position = UDim2.new(1, -22, 0.5, -2)})
		Tw(arrowB, 0.16, {Position = UDim2.new(1, -22, 0.5, 2)})
	end)

	local option = { Title = title, Type = "Button", Card = card }
	local callbacks = {}

	local function fire()
		if callback then
			task.spawn(function()
				local ok, err = pcall(callback)
				if not ok then warn("[Aurora] Button callback lỗi: " .. tostring(err)) end
			end)
		end
		for _, fn in ipairs(callbacks) do
			task.spawn(function()
				local ok, err = pcall(fn)
				if not ok then warn("[Aurora] Button callback lỗi: " .. tostring(err)) end
			end)
		end
	end

	function option:Click()
		fire()
	end
	function option:AddCallback(fn)
		table.insert(callbacks, fn)
		return self
	end
	option.NewCallback = option.AddCallback

	card.Frame.Activated:Connect(function()
		if type(cooldown) == "number" and tick() - lastClick < cooldown then return end
		lastClick = tick()

		local pos = lastPos
		local abs = card.Frame.AbsolutePosition
		local relX = pos and math.clamp(pos.X - abs.X, 0, card.Frame.AbsoluteSize.X) or card.Frame.AbsoluteSize.X / 2
		local relY = pos and math.clamp(pos.Y - abs.Y, 0, card.Frame.AbsoluteSize.Y) or card.Frame.AbsoluteSize.Y / 2
		local ripple = New("Frame", {
			Size = UDim2.fromOffset(12, 12),
			Position = UDim2.fromOffset(relX, relY),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = C.acc,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			Parent = card.Frame,
		})
		Corner(ripple, UDim.new(1, 0))
		Tw(ripple, 0.55, {Size = UDim2.fromOffset(320, 320), BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.6, function() ripple:Destroy() end)
		fire()
	end)

	RegisterEntry(ctx, {
		Tab = tab,
		Frame = card.Frame,
		Title = title,
		Desc = desc,
		Kind = "button",
		Label = card.Title,
		LabelText = title,
		Scale = card.Scale,
	})

	return option
end

OptionBuilders.Input = function(ctx, tab, cfg)
	cfg = cfg or {}
	local title = cfg[1] or cfg.Name or cfg.Title or "Input"
	local desc = cfg.Desc or cfg.Description
	local default = cfg[2]
	if default == nil then default = cfg.Default end
	if default == nil then default = "" end
	local callback = cfg[3] or cfg.Callback
	local flag = cfg[4] or cfg.Flag
	local placeholder = cfg.Placeholder or "Nhập nội dung..."

	local cardH = desc and 94 or 84
	local card = NewCard(tab, {
		Title = title,
		Desc = desc,
		Height = cardH,
		RightWidth = 0,
		TitleY = 10,
	})
	card.Title.Size = UDim2.new(1, -32, 0, 18)

	local inputY = desc and 48 or 38
	local box = New("Frame", {
		Size = UDim2.new(1, -32, 0, 32),
		Position = UDim2.new(0, 16, 0, inputY),
		BackgroundColor3 = C.inset,
		Parent = card.Frame,
	})
	Corner(box, UDim.new(0, 9))
	local boxStroke = Stroke(box, C.lineSoft, 1, 0.1)

	local textBox = New("TextBox", {
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Text = tostring(default),
		PlaceholderText = placeholder,
		PlaceholderColor3 = C.faint,
		TextColor3 = C.text,
		Font = Font.Medium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = box,
	})

	local option = {
		Value = tostring(default),
		Title = title,
		Flag = flag,
		Type = "Input",
		Card = card,
	}
	local callbacks = {}
	ctx.OptionObjects = ctx.OptionObjects or {}
	if flag then ctx.OptionObjects[flag] = option end

	local function fire(value)
		if callback then
			task.spawn(function()
				local ok, err = pcall(callback, value)
				if not ok then warn("[Aurora] Input callback lỗi: " .. tostring(err)) end
			end)
		end
		for _, fn in ipairs(callbacks) do
			task.spawn(function()
				local ok, err = pcall(fn, value)
				if not ok then warn("[Aurora] Input callback lỗi: " .. tostring(err)) end
			end)
		end
	end

	textBox.Focused:Connect(function()
		Tw(boxStroke, 0.18, {Color = C.acc, Transparency = 0.2})
		Tw(box, 0.18, {BackgroundColor3 = C.cardHover})
		Tw(card.Frame, 0.18, {BackgroundColor3 = C.cardHover})
	end)
	textBox.FocusLost:Connect(function(enterPressed)
		Tw(boxStroke, 0.18, {Color = C.lineSoft, Transparency = 0.1})
		Tw(box, 0.18, {BackgroundColor3 = C.inset})
		Tw(card.Frame, 0.18, {BackgroundColor3 = C.card})
		local value = textBox.Text
		option.Value = value
		if flag then ctx.Window.Flags[flag] = value end
		if enterPressed then fire(value) end
	end)

	function option:Set(value, silent)
		value = tostring(value or "")
		self.Value = value
		textBox.Text = value
		if flag then ctx.Window.Flags[flag] = value end
		if not silent then fire(value) end
		return self
	end
	option.SetValue = option.Set
	option.SetText = option.Set

	function option:AddCallback(fn)
		table.insert(callbacks, fn)
		return self
	end
	option.NewCallback = option.AddCallback

	function option:GetText() return textBox.Text end

	if flag then ctx.Window.Flags[flag] = option.Value end

	RegisterEntry(ctx, {
		Tab = tab,
		Frame = card.Frame,
		Title = title,
		Desc = desc,
		Kind = "input",
		Label = card.Title,
		LabelText = title,
		Scale = card.Scale,
	})

	return option
end

local function KeyName(key)
	if key == nil or key == Enum.KeyCode.Unknown then return "Chưa gán" end
	local name = tostring(key)
	name = name:gsub("Enum.KeyCode.", ""):gsub("Enum.UserInputType.", "")
	name = name:gsub("MouseButton1", "Chuột trái"):gsub("MouseButton2", "Chuột phải"):gsub("MouseButton3", "Chuột giữa")
	return name
end

OptionBuilders.Keybind = function(ctx, tab, cfg)
	cfg = cfg or {}
	local title = cfg[1] or cfg.Name or cfg.Title or "Keybind"
	local desc = cfg.Desc or cfg.Description
	local default = cfg[2]
	if default == nil then default = cfg.Default end
	local callback = cfg[3] or cfg.Callback
	local flag = cfg[4] or cfg.Flag

	local card = NewCard(tab, {
		Title = title,
		Desc = desc,
		Height = desc and 58 or 48,
		RightWidth = 132,
	})

	local pill = New("Frame", {
		Size = UDim2.fromOffset(124, 30),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = C.inset,
		Parent = card.Frame,
	})
	Corner(pill, UDim.new(0, 9))
	local pillStroke = Stroke(pill, C.lineSoft, 1, 0.2)

	local keyText = New("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = KeyName(default),
		TextColor3 = C.text,
		Font = Font.Medium,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = pill,
	})

	local pillHit = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = pill,
	})

	local option = {
		Value = default,
		Title = title,
		Flag = flag,
		Type = "Keybind",
		Listening = false,
		Card = card,
	}
	local callbacks = {}
	ctx.OptionObjects = ctx.OptionObjects or {}
	if flag then ctx.OptionObjects[flag] = option end

	local function fire(value)
		if callback then
			task.spawn(function()
				local ok, err = pcall(callback, value)
				if not ok then warn("[Aurora] Keybind callback lỗi: " .. tostring(err)) end
			end)
		end
		for _, fn in ipairs(callbacks) do
			task.spawn(function()
				local ok, err = pcall(fn, value)
				if not ok then warn("[Aurora] Keybind callback lỗi: " .. tostring(err)) end
			end)
		end
	end

	local function paint()
		keyText.Text = option.Listening and "Nhấn phím..." or KeyName(option.Value)
		Tw(pillStroke, 0.2, {
			Color = option.Listening and C.acc or C.lineSoft,
			Transparency = option.Listening and 0.2 or 0.2,
		})
		Tw(pill, 0.2, {BackgroundColor3 = option.Listening and C.accSoft or C.inset})
		Tw(keyText, 0.2, {TextColor3 = option.Listening and C.accLight or C.text})
	end

	local function stopListening()
		if not option.Listening then return end
		option.Listening = false
		paint()
	end

	local function startListening()
		if option.Listening then return end
		option.Listening = true
		paint()
	end

	function option:Set(value, silent)
		self.Value = value
		if flag then ctx.Window.Flags[flag] = value end
		keyText.Text = KeyName(value)
		paint()
		if not silent then fire(value) end
		return self
	end
	option.SetValue = option.Set

	function option:AddCallback(fn)
		table.insert(callbacks, fn)
		return self
	end
	option.NewCallback = option.AddCallback

	pillHit.Activated:Connect(function()
		if option.Listening then
			stopListening()
		else
			startListening()
		end
	end)

	ctx:Conn(UserInputService.InputBegan, function(input, processed)
		if option.Listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				if input.KeyCode == Enum.KeyCode.Escape then
					option:Set(Enum.KeyCode.Unknown)
					stopListening()
				else
					option:Set(input.KeyCode)
					stopListening()
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
				option:Set(input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseButton1 or Enum.UserInputType.MouseButton2)
				stopListening()
			end
			return
		end
		if processed then return end
		if UserInputService:GetFocusedTextBox() then return end
		local value = option.Value
		if value ~= nil and value ~= Enum.KeyCode.Unknown then
			if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
				if input.KeyCode == value then fire(value) end
			elseif typeof(value) == "EnumItem" and value.EnumType == Enum.UserInputType then
				if input.UserInputType == value then fire(value) end
			end
		end
	end)

	if flag then ctx.Window.Flags[flag] = option.Value end

	RegisterEntry(ctx, {
		Tab = tab,
		Frame = card.Frame,
		Title = title,
		Desc = desc,
		Kind = "keybind",
		Label = card.Title,
		LabelText = title,
		Scale = card.Scale,
	})

	return option
end

OptionBuilders.Paragraph = function(ctx, tab, cfg, contentArg)
	local title, content
	if type(cfg) == "table" then
		title = cfg[1] or cfg.Name or cfg.Title or "Ghi chú"
		content = cfg.Content or cfg.Desc or cfg.Description or ""
	else
		title = tostring(cfg or "Ghi chú")
		content = tostring(contentArg or "")
	end

	local card = New("Frame", {
		Name = "Paragraph",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.card,
		BackgroundTransparency = 0.35,
		Parent = tab.Scroll,
		LayoutOrder = tab.NextOrder(),
	})
	Corner(card, UDim.new(0, 11))
	Stroke(card, C.lineSoft, 1, 0.55)
	Pad(card, 16, 13, 16, 13)
	List(card, 6)

	local titleLabel = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = C.text,
		Font = Font.Bold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = card,
	})

	local contentLabel = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = content,
		TextColor3 = C.dim,
		Font = Font.Regular,
		TextSize = 12,
		LineHeight = 1.15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = card,
	})

	local cardScale = Scale(card, 1)

	local option = { Title = title, Type = "Paragraph", Frame = card }

	function option:SetTitle(text)
		titleLabel.Text = text
		self.Title = text
	end
	function option:SetContent(text)
		contentLabel.Text = text
	end
	option.SetDesc = option.SetContent
	option.SetDescription = option.SetContent

	RegisterEntry(ctx, {
		Tab = tab,
		Frame = card,
		Title = title,
		Kind = "paragraph",
		Scale = cardScale,
	})

	return option
end

local function GetNotifHolder(ctx)
	if ctx.NotifyHolder and ctx.NotifyHolder.Parent then return ctx.NotifyHolder end
	local holder = New("Frame", {
		Name = "Notifications",
		Size = UDim2.new(0, 336, 0.7, 0),
		Position = UDim2.new(1, -18, 1, -18),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 120,
		Parent = ctx.Gui,
	})
	List(holder, 10, false, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom)
	holder.ClipsDescendants = false
	ctx.NotifyHolder = holder
	return holder
end

local function Notify(ctx, cfg, contentArg)
	if type(cfg) ~= "table" then
		cfg = { Title = cfg, Content = contentArg }
	end
	local title = cfg[1] or cfg.Title or cfg.Name
	local content = cfg[2] or cfg.Content or cfg.Description
	local icon = cfg[3] or cfg.Icon or cfg.Image or ctx.NotifyDefaultIcon
	local duration = cfg[4] or cfg.Time or cfg.Duration or cfg.Countdown or 5
	if cfg.NOTIFICATION_GROUP then
		title = title or cfg.Title
		content = content or cfg.Content
		icon = icon or cfg.Icon
		duration = cfg[4] or cfg.Duration or duration
	end
	title = title or "Thông báo"
	content = content or ""
	if type(duration) ~= "number" then duration = 5 end

	local holder = GetNotifHolder(ctx)

	local container
	local isCanvas = false
	local okCanvas = pcall(function()
		container = New("CanvasGroup", {
			Name = "Notification",
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = C.card,
			ClipsDescendants = true,
			GroupTransparency = 1,
			Parent = holder,
		})
	end)
	if okCanvas and container then isCanvas = true end
	if not okCanvas or not container then
		container = New("Frame", {
			Name = "Notification",
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = C.card,
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Parent = holder,
		})
	end
	Corner(container, UDim.new(0, 12))
	local stroke = Stroke(container, C.line, 1, 0.35)

	local accentBar = New("Frame", {
		Size = UDim2.new(0, 3, 1, -20),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.acc,
		BorderSizePixel = 0,
		Parent = container,
	})
	Corner(accentBar, UDim.new(1, 0))
	Library:Accent(accentBar, "BackgroundColor3")

	local iconBox = New("Frame", {
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(0, 16, 0, 14),
		BackgroundColor3 = C.accSoft,
		Parent = container,
	})
	Corner(iconBox, UDim.new(0, 10))
	Library:Accent(iconBox, "BackgroundColor3", "soft")

	if type(icon) == "string" and string.sub(icon, 1, 13) == "rbxassetid://" then
		New("ImageLabel", {
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = icon,
			ImageColor3 = C.accLight,
			Parent = iconBox,
		})
	else
		local letter = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = string.upper(string.sub(title, 1, 1)),
			TextColor3 = C.accLight,
			Font = Font.Black,
			TextSize = 15,
			Parent = iconBox,
		})
		Library:Accent(letter, "TextColor3", "light")
	end

	local titleLabel = New("TextLabel", {
		Size = UDim2.new(1, -76, 0, 18),
		Position = UDim2.new(0, 60, 0, 13),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = C.text,
		Font = Font.Bold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = container,
	})
	local contentLabel = New("TextLabel", {
		Size = UDim2.new(1, -76, 0, 30),
		Position = UDim2.new(0, 60, 0, 32),
		BackgroundTransparency = 1,
		Text = content,
		TextColor3 = C.dim,
		Font = Font.Regular,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Parent = container,
	})

	local progress = New("Frame", {
		Size = UDim2.new(1, -32, 0, 2),
		Position = UDim2.new(0, 16, 1, -8),
		BackgroundColor3 = C.acc,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = container,
	})
	Corner(progress, UDim.new(1, 0))
	Library:Accent(progress, "BackgroundColor3")

	local hit = New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = container,
	})

	local closed = false
	local progressTween = TweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 2)})
	progressTween:Play()

	task.defer(function()
		Tw(container, 0.34, {Size = UDim2.new(1, 0, 0, 70)}, Enum.EasingStyle.Quint)
		if isCanvas then
			Tw(container, 0.3, {GroupTransparency = 0})
		else
			Tw(container, 0.3, {BackgroundTransparency = 0})
		end
	end)

	local pause = false

	local function close()
		if closed then return end
		closed = true
		progressTween:Cancel()
		Tw(container, 0.26, {Size = UDim2.new(1, 0, 0, 0)}, Enum.EasingStyle.Quint)
		if isCanvas then
			Tw(container, 0.22, {GroupTransparency = 1})
		end
		task.delay(0.3, function()
			container:Destroy()
		end)
	end

	hit.MouseEnter:Connect(function()
		pause = true
		progressTween:Pause()
		Tw(container, 0.18, {BackgroundColor3 = C.cardHover})
	end)
	hit.MouseLeave:Connect(function()
		pause = false
		progressTween:Play()
		Tw(container, 0.18, {BackgroundColor3 = C.card})
	end)
	hit.Activated:Connect(close)

	task.spawn(function()
		local remain = duration
		while remain > 0 and not closed do
			local dt = task.wait(0.1)
			if not pause then remain = remain - dt end
		end
		close()
	end)

	local notification = {
		Frame = container,
		Title = titleLabel,
		Content = contentLabel,
		Close = close,
		Type = "Notification",
	}

	return notification
end

local function Dialog(ctx, cfg)
	cfg = cfg or {}
	local title = cfg.Title or cfg.Name or "Thông báo"
	local content = cfg.Content or cfg.Description or ""
	local options = cfg.Options or { { Title = "OK" } }

	local scrim = New("Frame", {
		Name = "Dialog",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 150,
		Parent = ctx.Gui,
	})

	local card = New("Frame", {
		Size = UDim2.fromOffset(372, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.card,
		ZIndex = 151,
		Parent = scrim,
	})
	Corner(card, UDim.new(0, 16))
	Stroke(card, C.line, 1, 0.2)
	Grad(card, 90, C.cardTop, C.card)
	Pad(card, 20, 18, 20, 18)
	List(card, 8)

	local topAccent = New("Frame", {
		Size = UDim2.new(1, -40, 0, 2),
		BackgroundColor3 = C.acc,
		BorderSizePixel = 0,
		Parent = card,
	})
	Corner(topAccent, UDim.new(1, 0))
	Library:Accent(topAccent, "BackgroundColor3")

	local titleLabel = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = C.text,
		Font = Font.Bold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = card,
	})

	local contentLabel = New("TextLabel", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Text = content,
		TextColor3 = C.dim,
		Font = Font.Regular,
		TextSize = 12,
		LineHeight = 1.2,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Parent = card,
	})

	local row = New("Frame", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		Parent = card,
	})
	List(row, 8, true, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)

	local cardScale = Scale(card, 0.92)
	Tw(scrim, 0.2, {BackgroundTransparency = 0.35})
	Tw(cardScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local dialog = { Frame = card, Scrim = scrim, Type = "Dialog" }

	local function close()
		if dialog.Closed then return end
		local onClose = dialog.OnClose
		Tw(scrim, 0.18, {BackgroundTransparency = 1})
		Tw(cardScale, 0.16, {Scale = 0.94})
		task.delay(0.2, function()
			scrim:Destroy()
		end)
		dialog.Closed = true
		if type(onClose) == "function" then
			task.spawn(function() pcall(onClose, dialog) end)
		end
	end
	dialog.Close = close
	dialog.Dismiss = close

	function dialog:SetTitle(text)
		titleLabel.Text = text
	end
	function dialog:SetContent(text)
		contentLabel.Text = text
	end

	function dialog:NewOption(optionCfg, isFirst)
		local label = optionCfg[1] or optionCfg.Title or optionCfg.Name or "OK"
		local callback = optionCfg[2] or optionCfg.Callback
		local primary = optionCfg.Primary
		if primary == nil then
			primary = isFirst == true
		end

		local button = New("TextButton", {
			Size = UDim2.new(0, 0, 0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = primary and C.acc or C.cardHover,
			BackgroundTransparency = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = row,
		})
		Corner(button, UDim.new(0, 9))
		if primary then
			Library:Accent(button, "BackgroundColor3")
		end
		Pad(button, 18, 0, 18, 0)

		local buttonLabel = New("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = tostring(label),
			TextColor3 = primary and C.onAcc or C.text,
			Font = Font.Bold,
			TextSize = 12,
			Parent = button,
		})
		if primary then
			Library:Accent(buttonLabel, "TextColor3", "on")
		end
		button.AutomaticSize = Enum.AutomaticSize.X

		button.MouseEnter:Connect(function()
			Tw(button, 0.15, {BackgroundTransparency = primary and 0.12 or 0.15})
		end)
		button.MouseLeave:Connect(function()
			Tw(button, 0.15, {BackgroundTransparency = 0})
		end)
		button.Activated:Connect(function()
			if callback then
				task.spawn(function()
					local ok, err = pcall(callback, dialog)
					if not ok then warn("[Aurora] Dialog callback lỗi: " .. tostring(err)) end
				end)
			end
			close()
		end)

		return button
	end

	local first = true
	for _, optionCfg in ipairs(options) do
		if type(optionCfg) ~= "table" then optionCfg = { Title = tostring(optionCfg) } end
		dialog:NewOption(optionCfg, first)
		first = false
	end

	return dialog
end

local Minimizer = {}
Minimizer.__index = Minimizer

local function NewMinimizer(ctx, cfg)
	local key
	if type(cfg) == "table" then
		key = cfg[1] or cfg.KeyCode
	else
		key = cfg
	end
	if key == nil then key = Enum.KeyCode.RightControl end

	local self = setmetatable({
		KeyCode = key,
		Window = ctx.Window,
		_ctx = ctx,
	}, Minimizer)

	ctx:Conn(UserInputService.InputBegan, function(input, processed)
		if processed then return end
		if UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode == self.KeyCode then
			ctx.Window:Minimize()
		end
	end)

	return self
end

function Minimizer:SetKeyCode(key)
	assert(typeof(key) == "EnumItem", "[Aurora] SetKeyCode cần Enum.KeyCode")
	self.KeyCode = key
end

function Minimizer:CreateMobileMinimizer(cfg)
	cfg = cfg or {}
	local ctx = self._ctx

	ctx.OrbAlways = cfg.AlwaysVisible ~= false

	if type(cfg.Image) == "string" and #cfg.Image > 0 then
		if not ctx.OrbImage then
			ctx.OrbImage = New("ImageLabel", {
				Size = UDim2.new(1, -20, 1, -20),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = cfg.Image,
				ImageColor3 = C.onAcc,
				Parent = ctx.Orb,
			})
			Library:Accent(ctx.OrbImage, "ImageColor3", "on")
			for _, line in ipairs(ctx.OrbLines or {}) do
				line.Visible = false
			end
		else
			ctx.OrbImage.Image = cfg.Image
		end
	end

	if typeof(cfg.BackgroundColor3) == "Color3" then
		Tw(ctx.Orb, 0.2, {BackgroundColor3 = cfg.BackgroundColor3})
		ctx.OrbGlow.BackgroundColor3 = cfg.BackgroundColor3
	end

	if typeof(cfg.Size) == "UDim2" then
		ctx.Orb.Size = cfg.Size
	elseif typeof(cfg.Size) == "Vector2" then
		ctx.Orb.Size = UDim2.fromOffset(cfg.Size.X, cfg.Size.Y)
	end

	if typeof(cfg.Position) == "UDim2" then
		ctx.Orb.Position = cfg.Position
		ctx.OrbGlow.Position = cfg.Position
	elseif typeof(cfg.Position) == "Vector2" then
		ctx.Orb.Position = UDim2.fromScale(cfg.Position.X, cfg.Position.Y)
		ctx.OrbGlow.Position = ctx.Orb.Position
	end

	if typeof(cfg.Corner) == "UDim" then
		local corner = ctx.Orb:FindFirstChildOfClass("UICorner")
		if corner then corner.CornerRadius = cfg.Corner end
	end

	if cfg.Transparency ~= nil then
		ctx.Orb.BackgroundTransparency = cfg.Transparency
	end

	ctx.RefreshOrb()

	return {
		Frame = ctx.Orb,
		Glow = ctx.OrbGlow,
		SetVisible = function(state)
			ctx.OrbAlways = state
			ctx.RefreshOrb()
		end,
	}
end

function Minimizer:Destroy()
	local ctx = self._ctx
	if ctx.Orb then
		ctx.Orb.Visible = false
		ctx.OrbGlow.Visible = false
	end
end

function Library:MakeWindow(config)
	local ctx = CreateShell(self, config)
	local Window = ctx.Window

	function Window:MakeTab(tabConfig)
		return MakeTab(ctx, tabConfig)
	end
	Window.AddTab = Window.MakeTab
	Window.CreateTab = Window.MakeTab

	function Window:SelectTab(target, instant)
		if type(target) == "number" then
			local tab = ctx.Tabs[target]
			if tab then ctx:SelectTab(tab, instant) end
		elseif type(target) == "table" and target.Type == "Tab" then
			ctx:SelectTab(target, instant)
		end
	end

	function Window:GetCurrentTab()
		return ctx.CurrentTab
	end

	function Window:GetTabByTitle(name)
		for _, tab in ipairs(ctx.Tabs) do
			if tab.Name == name then return tab end
		end
	end
	Window.GetTabByName = Window.GetTabByTitle

	function Window:Notify(cfg, content)
		return Notify(ctx, cfg, content)
	end
	Window.Notification = Window.Notify

	function Window:SetNotifyDefaultIcon(icon)
		ctx.NotifyDefaultIcon = icon
	end
	Window.SetDefaultNotifyIcon = Window.SetNotifyDefaultIcon

	function Window:NewNotifyGroup(cfg)
		local group = {}
		for key, value in pairs(cfg or {}) do group[key] = value end
		group.NOTIFICATION_GROUP = true
		group.Notify = function(_, ownCfg, content)
			if type(ownCfg) ~= "table" then ownCfg = { Title = ownCfg, Content = content } end
			local merged = {}
			for key, value in pairs(group) do merged[key] = value end
			for key, value in pairs(ownCfg or {}) do merged[key] = value end
			return Notify(ctx, merged)
		end
		return group
	end
	Window.NewNotificationGroup = Window.NewNotifyGroup

	function Window:Dialog(cfg)
		return Dialog(ctx, cfg)
	end

	function Window:NewMinimizer(cfg)
		return NewMinimizer(ctx, cfg)
	end

	function Window:PerformSearch(query)
		ctx.SearchBox.Text = query
		ApplySearch(ctx, query)
	end

	function Window:SetFlag(name, value)
		self.Flags[name] = value
	end

	function Window:GetFlag(name)
		return self.Flags[name]
	end

	function Window:DeleteFlags()
		table.clear(self.Flags)
	end

	function Window:GetConfig()
		local data = {}
		for flag, value in pairs(self.Flags) do
			if typeof(value) == "EnumItem" then
				data[flag] = tostring(value)
			else
				data[flag] = value
			end
		end
		return data
	end

	function Window:SaveConfig(name)
		name = name or "config"
		if not ctx.Folder or not FS.write then return false end
		local path = ctx.Folder .. "/" .. name .. ".json"
		local ok = pcall(function()
			if FS.make and FS.isfolder and not FS.isfolder(ctx.Folder) then FS.make(ctx.Folder) end
			FS.write(path, HttpService:JSONEncode(self:GetConfig()))
		end)
		return ok
	end

	function Window:LoadConfig(name)
		name = name or "config"
		if not ctx.Folder or not FS.read then return false end
		local path = ctx.Folder .. "/" .. name .. ".json"
		local ok, raw = pcall(FS.read, path)
		if not ok or type(raw) ~= "string" then return false end
		local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
		if not ok2 or type(data) ~= "table" then return false end
		for flag, value in pairs(data) do
			local option = ctx.OptionObjects and ctx.OptionObjects[flag]
			if option and option.Set then
				if type(value) == "string" and string.sub(value, 1, 14) == "Enum.KeyCode." then
					local keyName = string.gsub(value, "Enum.KeyCode.", "")
					value = Enum.KeyCode[keyName] or Enum.KeyCode.Unknown
				end
				pcall(function() option:Set(value, true) end)
			end
		end
		return true
	end

	function Window:ReadFile(fileName)
		if not ctx.Folder or not FS.read then return nil end
		local ok, data = pcall(FS.read, ctx.Folder .. "/" .. fileName)
		if ok then return data end
		return nil
	end

	function Window:WriteFile(fileName, content)
		if not ctx.Folder or not FS.write then return false end
		local ok = pcall(function()
			if FS.make and FS.isfolder and not FS.isfolder(ctx.Folder) then FS.make(ctx.Folder) end
			FS.write(ctx.Folder .. "/" .. fileName, content)
		end)
		return ok
	end

	Window.ScriptFolder = ctx.Folder
	Window.SelectedTab = 1
	Window.Title = ctx.TitleLabel and ctx.TitleLabel.Text or nil
	Window.SubTitle = ctx.SubTitleLabel and ctx.SubTitleLabel.Text or nil

	ctx.Dialog = function(_, dialogCfg)
		return Dialog(ctx, dialogCfg)
	end

	ctx:Conn(ctx.SearchBox:GetPropertyChangedSignal("Text"), function()
		ApplySearch(ctx, ctx.SearchBox.Text)
	end)

	task.defer(function()
		ctx.RefreshOrb()
	end)

	return Window
end

function Library:Destroy()
	for _, gui in ipairs(Library._guis) do
		pcall(function() gui:Destroy() end)
	end
	table.clear(Library._guis)
end

function Library:GetWindows()
	return Library._guis
end

return Library
