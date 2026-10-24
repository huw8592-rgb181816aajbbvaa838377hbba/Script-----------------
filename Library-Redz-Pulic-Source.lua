--[[
    DIO UI Library v3 (Redz V5 API compatible)
    Giu nguyen API cua Redz: MakeWindow / MakeTab / AddSection / AddToggle / AddButton /
    AddTextBox / AddSlider / AddDropdown / AddParagraph / AddDiscordInvite / Notify / Dialog /
    NewMinimizer / CreateMobileMinimizer / Flags / Themes.
    Thay toan bo giao dien: moi toggle/dropdown/slider la mot the rieng, co animation,
    chu to hon, vung bam lon hon cho mobile, nen dac de de doc.
]]

local cloneref = cloneref or function(instance)
    return instance
end

local Services = setmetatable({}, {
    __index = function(self, name)
        local service = cloneref(game:GetService(name))
        rawset(self, name, service)
        return service
    end,
})

local UserInputService = Services.UserInputService
local TweenService = Services.TweenService
local HttpService = Services.HttpService

local GUI_NAME = "redz-library-v5"
local LOG_PREFIX = "[DIO UI] "
local TOPBAR_HEIGHT = 56
local ROW_HEIGHT = 56
local SEARCH_WIDTH = 210
local DESIGN_SIZE = Vector2.new(640, 400)
local MIN_SIZE = Vector2.new(500, 300)
local MAX_SIZE = Vector2.new(1000, 620)
local MIN_SCALE = 0.6
local MAX_SCALE = 1.6
local DEFAULT_PLACEHOLDER = "Input"

local ICON = {
    Error = "rbxassetid://10709752996",
    Button = "rbxassetid://10709791437",
    Close = "rbxassetid://10747384394",
    TextBox = "rbxassetid://15637081879",
    Search = "rbxassetid://10734943674",
    DropdownOpen = "rbxassetid://10709791523",
    DropdownClose = "rbxassetid://10709790948",
    Minimizer = "rbxassetid://10734896206",
}

local FONT = {
    Regular = Enum.Font.BuilderSans,
    Medium = Enum.Font.BuilderSansMedium,
    Bold = Enum.Font.BuilderSansBold,
    ExtraBold = Enum.Font.BuilderSansExtraBold,
}

local function warnf(message)
    warn(LOG_PREFIX .. tostring(message))
end

local function normalize(text)
    return (string.gsub(string.lower(tostring(text)), "[%s%p%c]", ""))
end

local function isAssetId(value)
    return type(value) == "string" and string.sub(value, 1, 13) == "rbxassetid://"
end

local FS = {
    readfile = readfile,
    writefile = writefile,
    makefolder = makefolder,
    isfolder = isfolder,
    delfile = delfile or deletefile,
}

local function writeFile(path, content)
    if not FS.writefile then
        return false
    end

    local folder = string.match(path, "^(.*)/[^/]*$")
    if folder and folder ~= "" and FS.makefolder and FS.isfolder then
        local okCheck, exists = pcall(FS.isfolder, folder)
        if not okCheck then
            warnf("isfolder failed (" .. folder .. "): " .. tostring(exists))
        elseif not exists then
            local okMake, makeError = pcall(FS.makefolder, folder)
            if not okMake then
                warnf("makefolder failed (" .. folder .. "): " .. tostring(makeError))
            end
        end
    end

    local ok, writeError = pcall(FS.writefile, path, content)
    if not ok then
        warnf("writefile failed (" .. path .. "): " .. tostring(writeError))
    end
    return ok
end

local function makeStore(folder, fileName, clearable)
    local path = folder and (folder .. "/" .. fileName) or nil
    local data = {}

    if path and FS.readfile then
        local okRead, raw = pcall(FS.readfile, path)
        if okRead and type(raw) == "string" and raw ~= "" then
            local okDecode, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
            if okDecode and type(decoded) == "table" then
                data = decoded
            else
                warnf("could not parse " .. path .. ", starting with an empty store")
            end
        end
    end

    local saving = false
    local function flush()
        saving = false
        if not path then
            return
        end
        local okEncode, encoded = pcall(HttpService.JSONEncode, HttpService, data)
        if okEncode then
            writeFile(path, encoded)
        else
            warnf("could not encode " .. path .. ": " .. tostring(encoded))
        end
    end

    local meta = {
        __index = data,
        __newindex = function(_, key, value)
            rawset(data, key, value)
            if path and not saving then
                saving = true
                task.delay(0.5, flush)
            end
        end,
    }

    if clearable then
        meta.__call = function()
            table.clear(data)
            if path and FS.delfile then
                local okDelete, deleteError = pcall(FS.delfile, path)
                if not okDelete then
                    warnf("delfile failed (" .. path .. "): " .. tostring(deleteError))
                end
            end
        end
    end

    return setmetatable({}, meta)
end

local function makeTheme(name, accent)
    local hue = accent:ToHSV()
    local theme = {
        Name = name,
        Window = Color3.fromHSV(hue, 0.30, 0.075),
        Sidebar = Color3.fromHSV(hue, 0.28, 0.09),
        Content = Color3.fromHSV(hue, 0.26, 0.105),
        Card = Color3.fromHSV(hue, 0.24, 0.155),
        CardHover = Color3.fromHSV(hue, 0.24, 0.195),
        CardPress = Color3.fromHSV(hue, 0.26, 0.235),
        Field = Color3.fromHSV(hue, 0.30, 0.095),
        Stroke = Color3.fromHSV(hue, 0.22, 0.28),
        Track = Color3.fromHSV(hue, 0.16, 0.30),
        Primary = accent,
        OnPrimary = Color3.fromHSV(hue, 0.70, 0.10),
        Text = Color3.fromHSV(hue, 0.04, 0.98),
        TextDim = Color3.fromHSV(hue, 0.14, 0.78),
        Knob = Color3.fromHSV(hue, 0.04, 0.97),
        KnobOff = Color3.fromHSV(hue, 0.12, 0.72),
        Danger = Color3.fromRGB(240, 92, 92),
        Scrim = Color3.fromRGB(0, 0, 0),
    }
    return table.freeze(theme)
end

local Themes = {
    Darker = makeTheme("Darker", Color3.fromRGB(46, 213, 115)),
    Ocean = makeTheme("Ocean", Color3.fromRGB(56, 152, 255)),
    Violet = makeTheme("Violet", Color3.fromRGB(150, 104, 255)),
    Sunset = makeTheme("Sunset", Color3.fromRGB(255, 142, 64)),
    Rose = makeTheme("Rose", Color3.fromRGB(255, 92, 134)),
}

local Lib = {
    Information = {
        Version = "v3.0.0",
        GitHubOwner = "tlredz",
    },
    Default = {
        Theme = "Darker",
        UISize = UDim2.fromOffset(DESIGN_SIZE.X, DESIGN_SIZE.Y),
        SidebarWidth = 160,
    },
    Themes = Themes,
    CurrentTheme = Themes.Darker,
    Connections = {},
    Options = {},
    Tabs = {},
}
Lib.Info = Lib.Information
Lib.Save = Lib.Default

local State = {
    Tabs = Lib.Tabs,
    SearchIndex = {},
    Scales = {},
    BaseScale = 1,
    UserScale = 1,
    NotifyIcon = nil,
}

local Registry = {}
local Listeners = {}
local pruneThreshold = 600

local function isAlive(instance)
    local current = instance
    while current do
        if current == State.Gui then
            return true
        end
        current = current.Parent
    end
    return false
end

local function pruneDead()
    for index = #Registry, 1, -1 do
        if not isAlive(Registry[index][1]) then
            table.remove(Registry, index)
        end
    end
    for index = #Listeners, 1, -1 do
        if not isAlive(Listeners[index][1]) then
            table.remove(Listeners, index)
        end
    end
end

local function maybePrune()
    if #Registry + #Listeners > pruneThreshold then
        pruneDead()
        pruneThreshold = math.max(600, (#Registry + #Listeners) * 2)
    end
end

local function register(instance, property, key)
    maybePrune()
    Registry[#Registry + 1] = { instance, property, key }
    instance[property] = Lib.CurrentTheme[key]
end

local function onTheme(instance, callback)
    maybePrune()
    Listeners[#Listeners + 1] = { instance, callback }
    callback(Lib.CurrentTheme)
end

local function applyTheme(theme)
    pruneDead()

    for index = 1, #Registry do
        local entry = Registry[index]
        entry[1][entry[2]] = theme[entry[3]]
    end

    for index = 1, #Listeners do
        local entry = Listeners[index]
        local ok, listenerError = pcall(entry[2], theme)
        if not ok then
            warnf("theme listener failed: " .. tostring(listenerError))
        end
    end
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Lib.Connections, connection)
    return connection
end

local function tween(instance, goal, duration, style, direction)
    local info = TweenInfo.new(duration or 0.2, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
    local created = TweenService:Create(instance, info, goal)
    created:Play()
    return created
end

local function new(className, props, children)
    local instance = Instance.new(className)
    local parent

    if props then
        for key, value in pairs(props) do
            if key == "Parent" then
                parent = value
            else
                instance[key] = value
            end
        end
    end

    if children then
        for _, child in ipairs(children) do
            child.Parent = instance
        end
    end

    if parent then
        instance.Parent = parent
    end

    return instance
end

local function corner(parent, radius)
    return new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function stroke(parent, key, thickness, transparency)
    local created = new("UIStroke", {
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
    register(created, "Color", key)
    return created
end

local function pad(parent, left, right, top, bottom)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, left),
        PaddingRight = UDim.new(0, right),
        PaddingTop = UDim.new(0, top),
        PaddingBottom = UDim.new(0, bottom),
        Parent = parent,
    })
end

local function vlist(parent, spacing)
    return new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, spacing or 0),
        Parent = parent,
    })
end

local function makeLabel(props, colorKey)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Font = FONT.Medium
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = ""

    local parent
    for key, value in pairs(props) do
        if key == "Parent" then
            parent = value
        else
            label[key] = value
        end
    end

    label.Parent = parent
    register(label, "TextColor3", colorKey or "Text")
    return label
end

local function makeButton(props)
    local button = Instance.new("TextButton")
    button.AutoButtonColor = false
    button.BackgroundTransparency = 1
    button.BorderSizePixel = 0
    button.Text = ""
    button.Font = FONT.Medium
    button.TextSize = 16

    local parent
    for key, value in pairs(props) do
        if key == "Parent" then
            parent = value
        else
            button[key] = value
        end
    end

    button.Parent = parent
    return button
end

local function makeIcon(props, colorKey)
    local image = Instance.new("ImageLabel")
    image.BackgroundTransparency = 1
    image.BorderSizePixel = 0

    local parent
    for key, value in pairs(props) do
        if key == "Parent" then
            parent = value
        else
            image[key] = value
        end
    end

    image.Parent = parent
    if colorKey then
        register(image, "ImageColor3", colorKey)
    end
    return image
end

local function stripEmoji(text)
    if type(text) ~= "string" then
        return text
    end

    local out = table.create(#text)
    for _, codepoint in utf8.codes(text) do
        local drop = (codepoint >= 0x2100 and codepoint <= 0x2BFF)
            or codepoint >= 0x1F000
            or codepoint == 0xFE0F
            or codepoint == 0x200D
        if not drop then
            table.insert(out, utf8.char(codepoint))
        end
    end
    return table.concat(out)
end

local function normalizeCallbacks(callback)
    if callback == nil then
        return {}
    end

    local kind = type(callback)
    if kind ~= "function" and kind ~= "table" then
        error("Failed to get Callback: 'function', or 'table' expected, got " .. typeof(callback), 3)
    end

    if kind == "table" then
        local target, key = callback[1], callback[2]
        return {
            function(value)
                target[key] = value
            end,
        }
    end

    return { callback }
end

local function fireCallbacks(list, ...)
    for index = 1, #list do
        local callback = list[index]
        task.spawn(function(...)
            local ok, callbackError = xpcall(callback, debug.traceback, ...)
            if not ok then
                warnf("callback error: " .. tostring(callbackError))
            end
        end, ...)
    end
end

local ActiveDrag

local function startDrag(input, onMove, onEnd)
    if ActiveDrag then
        return nil
    end

    local drag = {
        Input = input,
        OnMove = onMove,
        Origin = input.Position,
    }
    ActiveDrag = drag

    local changed
    changed = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            changed:Disconnect()
            if ActiveDrag == drag then
                ActiveDrag = nil
            end
            if onEnd then
                local ok, endError = pcall(onEnd)
                if not ok then
                    warnf("drag end handler failed: " .. tostring(endError))
                end
            end
        end
    end)

    return drag
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local function installDragListener()
    connect(UserInputService.InputChanged, function(input)
        local drag = ActiveDrag
        if not drag then
            return
        end

        local isMouseDrag = drag.Input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement

        if isMouseDrag or input == drag.Input then
            local ok, moveError = pcall(drag.OnMove, input.Position, drag.Origin)
            if not ok then
                warnf("drag handler failed: " .. tostring(moveError))
            end
        end
    end)
end

local function getGuiParent()
    if gethui then
        local ok, result = pcall(gethui)
        if ok and result then
            return result
        end
        warnf("gethui failed, falling back to CoreGui: " .. tostring(result))
    end
    return Services.CoreGui
end

local function getViewport()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1280, 720)
end

local function applyScale()
    local scale = State.BaseScale * State.UserScale
    for index = #State.Scales, 1, -1 do
        local uiScale = State.Scales[index]
        if uiScale.Parent == nil then
            table.remove(State.Scales, index)
        else
            uiScale.Scale = scale
        end
    end
end

local function newScale(parent)
    local uiScale = new("UIScale", { Name = "Scale", Scale = State.BaseScale * State.UserScale, Parent = parent })
    table.insert(State.Scales, uiScale)
    return uiScale
end

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Element = {}
Element.__index = Element
local function refreshEntry(entry)
    if entry.Frame and entry.Frame.Parent then
        entry.Frame.Visible = (not entry.UserHidden) and (not entry.SearchHidden)
    end
end

local function registerSearch(tab, frame, title, kind, description)
    local entry = {
        Title = normalize(title),
        Description = normalize(description or ""),
        Kind = kind,
        Tab = tab,
        Frame = frame,
        IsSection = kind == "section",
    }
    table.insert(State.SearchIndex, entry)
    return entry
end

local function removeSearchEntries(predicate)
    for index = #State.SearchIndex, 1, -1 do
        if predicate(State.SearchIndex[index]) then
            table.remove(State.SearchIndex, index)
        end
    end
end

local function refreshTabButton(tab)
    if tab._button and tab._button.Parent then
        tab._button.Visible = (not tab._userHidden) and (not tab._searchHidden)
    end
end

local function styleTab(tab, selected, instant)
    local theme = Lib.CurrentTheme
    local textColor = selected and theme.OnPrimary or theme.TextDim
    local background = selected and 0 or 1

    if instant then
        tab._button.BackgroundTransparency = background
        tab._text.TextColor3 = textColor
        if tab._icon then
            tab._icon.ImageColor3 = textColor
        end
        return
    end

    tween(tab._button, { BackgroundTransparency = background }, 0.22)
    tween(tab._text, { TextColor3 = textColor }, 0.22)
    if tab._icon then
        tween(tab._icon, { ImageColor3 = textColor }, 0.22)
    end
end

function Window:MakeTab(config)
    if type(config) ~= "table" then
        error("\"Window.MakeTab[Configs]\". 'table' expected, got " .. typeof(config), 2)
    end

    local title = config[1] or config.Name or config.Title
    local icon = config[2] or config.Icon or config.Image

    assert(type(title) == "string", "\"Tab.Title\" 'string' expected, got " .. typeof(title))
    assert(icon == nil or type(icon) == "string", "\"Tab.Icon\" 'string' expected, got " .. typeof(icon))

    local tab = setmetatable({
        Selected = self.SelectedTab == #State.Tabs + 1,
        Icon = Lib:GetIconByName(icon),
        Title = title,
        Parent = self,
        IS_A_TAB = true,
    }, Tab)

    local hasIcon = type(tab.Icon) == "string" and isAssetId(tab.Icon)

    local button = makeButton({
        Name = "TabButton",
        Size = UDim2.new(1, 0, 0, 46),
        LayoutOrder = #State.Tabs + 1,
        Parent = State.Sidebar,
    })
    register(button, "BackgroundColor3", "Primary")
    corner(button, 12)

    local iconLabel
    if hasIcon then
        iconLabel = makeIcon({
            Name = "Icon",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 0),
            Size = UDim2.fromOffset(22, 22),
            Image = tab.Icon,
            Parent = button,
        })
    end

    local textLabel = makeLabel({
        Name = "Label",
        Position = UDim2.fromOffset(hasIcon and 46 or 16, 0),
        Size = UDim2.new(1, -((hasIcon and 46 or 16) + 8), 1, 0),
        Text = stripEmoji(title),
        TextSize = 16,
        Font = FONT.Bold,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = button,
    }, "TextDim")

    local container = new("ScrollingFrame", {
        Name = "Container",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageTransparency = 0.25,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Visible = false,
        Parent = State.Content,
    })
    register(container, "ScrollBarImageColor3", "Primary")
    pad(container, 12, 14, 12, 16)
    vlist(container, 8)

    tab._button = button
    tab._text = textLabel
    tab._icon = iconLabel
    tab._container = container

    onTheme(button, function()
        styleTab(tab, tab.Selected, true)
    end)

    button.MouseEnter:Connect(function()
        if not tab.Selected then
            tween(button, { BackgroundTransparency = 0.86 }, 0.15)
        end
    end)
    button.MouseLeave:Connect(function()
        if not tab.Selected then
            tween(button, { BackgroundTransparency = 1 }, 0.15)
        end
    end)
    button.Activated:Connect(function()
        tab:Select()
    end)

    table.insert(State.Tabs, tab)

    if tab.Selected then
        tab.Selected = false
        tab:Select()
    end

    return tab
end

function Tab:GetNoSelfCall(name)
    assert(type(name) == "string", "\"Tab.GetNoSelfCall\". 'string' expected, got " .. typeof(name))
    local method = self[name]
    assert(type(method) == "function", "\"Tab.GetNoSelfCall\". '" .. tostring(method) .. "' is not a 'function'-" .. name)

    return function(...)
        return method(self, ...)
    end
end

function Tab:Select()
    if State.Selected == self or self.IS_DESTROYED then
        return
    end

    local previous = State.Selected
    if previous and not previous.IS_DESTROYED then
        previous.Selected = false
        previous._container.Visible = false
        styleTab(previous, false, false)
    end

    State.Selected = self
    self.Selected = true
    self.Parent.SelectedTabs = { self }

    local container = self._container
    container.Position = UDim2.fromOffset(0, 16)
    container.Visible = true
    tween(container, { Position = UDim2.fromOffset(0, 0) }, 0.3)
    styleTab(self, true, false)
end

function Tab:SetVisible(visible)
    assert(type(visible) == "boolean", "\"Tab.SetVisible[param 1]\". 'boolean' extected, got " .. typeof(visible))
    self._userHidden = not visible
    refreshTabButton(self)

    if not visible and State.Selected == self then
        for _, other in ipairs(State.Tabs) do
            if other ~= self and not other._userHidden then
                other:Select()
                break
            end
        end
    end
end

function Tab:Destroy()
    assert(type(self) == "table" and self.IS_A_TAB, "\"Tab.Destroy\". " .. tostring(self) .. " is not a tab")
    if self.IS_DESTROYED then
        return
    end

    local index = table.find(State.Tabs, self)
    assert(index, "\"Tab.Destroy\". failed to destroy '" .. tostring(self.Title) .. "'")

    table.remove(State.Tabs, index)
    removeSearchEntries(function(entry)
        return entry.Tab == self
    end)

    local wasSelected = State.Selected == self
    self.IS_DESTROYED = true
    self._button:Destroy()
    self._container:Destroy()

    if wasSelected then
        State.Selected = nil
        local fallback = State.Tabs[math.min(index, #State.Tabs)]
        if fallback then
            fallback:Select()
        end
    end
end

function Window:SelectTab(target)
    local tab = type(target) == "number" and State.Tabs[target] or nil
    if type(target) == "table" and target.IS_A_TAB then
        tab = target
    end

    if tab then
        tab:Select()
        return
    end

    assert(type(target) == "number", "\"Window.SelectTab\" number or tab expected, got " .. typeof(target))
    assert(target > 0, "\"Window.SelectTab\" the number must be greater than 0, value: " .. tostring(target))
    assert(target == math.floor(target), "\"Winow.SelectTab\" floor number expected, got " .. tostring(target))

    self.SelectedTab = target
end

function Window:GetTabByTitle(title)
    assert(type(title) == "string", "\"Window.GetTabByTitle[param 1]\". 'string' expected, got " .. typeof(title))
    for _, tab in ipairs(State.Tabs) do
        if tab.Title == title then
            return tab
        end
    end
    return nil
end

Window.GetTabByName = Window.GetTabByTitle

function Window:PerformSearch(query)
    query = normalize(type(query) == "string" and query or "")

    if query == "" then
        for _, entry in ipairs(State.SearchIndex) do
            if entry.SearchHidden then
                entry.SearchHidden = false
                refreshEntry(entry)
            end
        end
        for _, tab in ipairs(State.Tabs) do
            tab._searchHidden = false
            refreshTabButton(tab)
        end
        State.NoResults.Visible = false
        return
    end

    local tabMatch = {}
    local sectionShown = {}
    local itemShown = {}
    local currentSection = {}
    local currentSectionMatched = {}

    for _, entry in ipairs(State.SearchIndex) do
        if entry.IsSection then
            currentSection[entry.Tab] = entry
            local matched = string.find(entry.Title, query, 1, true) ~= nil
            currentSectionMatched[entry.Tab] = matched
            if matched then
                sectionShown[entry] = true
                tabMatch[entry.Tab] = true
            end
        else
            local matched = currentSectionMatched[entry.Tab] == true
                or string.find(entry.Title, query, 1, true) ~= nil
                or string.find(entry.Description, query, 1, true) ~= nil
                or string.find(entry.Kind, query, 1, true) ~= nil

            if matched then
                itemShown[entry] = true
                tabMatch[entry.Tab] = true
                local section = currentSection[entry.Tab]
                if section then
                    sectionShown[section] = true
                end
            end
        end
    end

    for _, entry in ipairs(State.SearchIndex) do
        local shown = entry.IsSection and sectionShown[entry] == true or itemShown[entry] == true
        entry.SearchHidden = not shown
        refreshEntry(entry)
    end

    local firstMatch
    for _, tab in ipairs(State.Tabs) do
        tab._searchHidden = tabMatch[tab] ~= true
        refreshTabButton(tab)
        if tabMatch[tab] and not firstMatch then
            firstMatch = tab
        end
    end

    State.NoResults.Visible = firstMatch == nil

    local selected = State.Selected
    if firstMatch and (not selected or not tabMatch[selected]) then
        firstMatch:Select()
    end
end

function Window:GetTitle()
    return State.TitleLabel.Text
end

function Window:GetSubTitle()
    return State.SubTitleLabel.Text
end

function Window:SetTitle(title)
    assert(type(title) == "string", "\"Window.SetTitle\". 'string' expected, got " .. typeof(title))
    assert(#title > 0, "\"Window.SetTitle\". the new 'Title' is too short.")
    State.TitleLabel.Text = title
end

function Window:SetSubTitle(subTitle)
    assert(type(subTitle) == "string", "\"Window.SetSubTitle\". 'string' expected, got " .. typeof(subTitle))
    assert(#subTitle > 0, "\"Window.SetSubTitle\". the new 'SubTitle' is too short.")
    State.SubTitleLabel.Text = subTitle
end

function Window:DeleteFlags()
    return State.Flags()
end

function Window:SetFlag(name, value)
    assert(type(name) == "string", "\"Window.SetFlag[param 1]\". 'string' expected, got " .. typeof(name))
    local kind = type(value)
    if kind ~= "number" and kind ~= "string" and kind ~= "nil" and kind ~= "boolean" and kind ~= "table" then
        error("\"Window.SetFlag[param 2]\". 'number', 'string', 'nil', 'boolean', 'table' expected, got " .. typeof(value), 2)
    end
    State.Flags[name] = value
end

function Window:GetFlag(name)
    return State.Flags[name]
end

function Window:ReadFile(name)
    assert(type(name) == "string", "\"Window.ReadFile[param 1]\". 'string' expected, got " .. typeof(name))
    if not FS.readfile then
        return nil
    end

    local ok, content = pcall(FS.readfile, tostring(self.ScriptFolder) .. "/" .. name)
    if ok then
        return content
    end
    return nil
end

function Window:WriteFile(name, content)
    assert(type(name) == "string", "\"Window.WriteFile[param 1]\". 'string' expected, got " .. typeof(name))
    if content ~= nil and type(content) ~= "string" then
        error("\"Window.WriteFile[param 2]\". 'string', or 'nil' expected, got " .. typeof(content), 2)
    end

    local path = tostring(self.ScriptFolder) .. "/" .. name
    if content == nil then
        if FS.delfile then
            local ok, deleteError = pcall(FS.delfile, path)
            if not ok then
                warnf("delfile failed (" .. path .. "): " .. tostring(deleteError))
            end
            return ok
        end
        return false
    end

    return writeFile(path, content)
end

function Window:SetNotifyDefaultIcon(icon)
    assert(type(icon) == "string", "\"Window.SetNotifyDefaultIcon[param 1]\". 'string' expected, got " .. typeof(icon))
    State.NotifyIcon = icon
end

Window.SetDefaultNotifyIcon = Window.SetNotifyDefaultIcon

function Window:GetElements()
    return State.Elements
end

function Window:SetUIScale(multiplier)
    return Lib:SetUIScale(multiplier)
end

function Window:Minimize()
    local main = State.Main
    if not main or not main.Parent then
        return
    end

    State.ToggleToken = (State.ToggleToken or 0) + 1
    local token = State.ToggleToken
    local target = State.BaseScale * State.UserScale
    local scale = State.MainScale

    if main.Visible then
        tween(scale, { Scale = target * 0.9 }, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.16, function()
            if State.ToggleToken == token and main.Parent then
                main.Visible = false
                scale.Scale = target
            end
        end)
    else
        scale.Scale = target * 0.9
        main.Visible = true
        tween(scale, { Scale = target }, 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    end
end

function Window:MinimizeButton()
    if os.clock() < (State.CollapseLock or 0) then
        return false
    end
    State.CollapseLock = os.clock() + 0.4

    local main = State.Main
    local scale = State.BaseScale * State.UserScale
    local size = main.Size
    local bar = State.MinimizeBar

    if self.Minimized then
        local full = State.ExpandedSize or DESIGN_SIZE
        local shift = (full.Y - TOPBAR_HEIGHT) * scale / 2
        tween(main, {
            Size = UDim2.fromOffset(full.X, full.Y),
            Position = UDim2.fromOffset(main.Position.X.Offset, main.Position.Y.Offset + shift),
        }, 0.3)
        tween(bar, { Size = UDim2.fromOffset(16, 3), BackgroundTransparency = 0 }, 0.2)
        State.Grip.Visible = true
    else
        State.ExpandedSize = Vector2.new(size.X.Offset, size.Y.Offset)
        local shift = (size.Y.Offset - TOPBAR_HEIGHT) * scale / 2
        tween(main, {
            Size = UDim2.fromOffset(size.X.Offset, TOPBAR_HEIGHT),
            Position = UDim2.fromOffset(main.Position.X.Offset, main.Position.Y.Offset - shift),
        }, 0.3)
        tween(bar, { Size = UDim2.fromOffset(14, 12), BackgroundTransparency = 0.4 }, 0.2)
        State.Grip.Visible = false
    end

    self.Minimized = not self.Minimized
    return true
end

local function clampWindow()
    local main = State.Main
    if not main or not main.Parent then
        return
    end

    local viewport = getViewport()
    local scale = State.BaseScale * State.UserScale
    local halfWidth = main.Size.X.Offset * scale / 2
    local halfHeight = main.Size.Y.Offset * scale / 2
    local keep = 120

    local cx = math.clamp(main.Position.X.Offset, keep - halfWidth, viewport.X + halfWidth - keep)
    local cy = math.clamp(main.Position.Y.Offset, halfHeight, math.max(halfHeight, viewport.Y - 64 + halfHeight))
    main.Position = UDim2.fromOffset(cx, cy)
end

local function computeBaseScale()
    local viewport = getViewport()
    local fit = math.min(viewport.X * 0.94 / DESIGN_SIZE.X, viewport.Y * 0.9 / DESIGN_SIZE.Y)
    return math.clamp(fit, 0.5, 1.3)
end

local function loadIcons(folder)
    if folder and FS.readfile then
        local okRead, source = pcall(FS.readfile, folder .. "/Icons.lua")
        if okRead and type(source) == "string" and source ~= "" then
            local okLoad, result = pcall(function()
                return loadstring(source)()
            end)
            if okLoad and type(result) == "table" then
                return result
            end
            warnf("cached Icons.lua is invalid, downloading it again")
        end
    end

    local url = "https://raw.githubusercontent.com/" .. Lib.Information.GitHubOwner .. "/Library/refs/heads/main/redz-V5-remake/Utils/Icons.lua"
    local okGet, source = pcall(function()
        return game:HttpGet(url)
    end)

    if okGet and type(source) == "string" then
        local okLoad, result = pcall(function()
            return loadstring(source)()
        end)
        if okLoad and type(result) == "table" then
            if folder then
                writeFile(folder .. "/Icons.lua", source)
            end
            return result
        end
        warnf("downloaded Icons.lua could not be loaded: " .. tostring(result))
    else
        warnf("could not download the icon list: " .. tostring(source))
    end

    return {}
end

function Lib:MakeWindow(config)
    if self.LOADED_UI_LIBRARY then
        return error("you can create only 1 Window", 2)
    end

    if type(config) ~= "table" then
        error("\"Library.MakeWindow[Configs]\". 'table' expected, got " .. typeof(config), 2)
    end

    local info = {
        Title = config[1] or config.Name or config.Title,
        SubTitle = config[2] or config.SubName or config.SubTitle or "",
        ScriptFolder = config[3] or config.ScriptFolder or config.FolderName,
    }

    assert(type(info.Title) == "string", "\"Window.Title\". 'string' expected, got " .. typeof(info.Title))
    assert(type(info.SubTitle) == "string", "\"Window.SubTitle\". 'string' expected, got " .. typeof(info.SubTitle))

    if info.ScriptFolder ~= nil and type(info.ScriptFolder) ~= "string" then
        return error("\"Window.ScriptFolder\". 'string', or nil expected, got " .. typeof(info.ScriptFolder), 2)
    end
    if info.ScriptFolder ~= nil and string.find(info.ScriptFolder, "/") then
        return error("\"Window.ScriptFolder\" is not valid, unexpected char \"/\"", 2)
    end

    installDragListener()

    local settings = makeStore(info.ScriptFolder, "LibrarySettings.json")
    local flags = makeStore(info.ScriptFolder, "ScriptFlags.json", true)

    self.WindowSettings = settings
    self.Flags = flags
    State.Settings = settings
    State.Flags = flags
    self.Icons = loadIcons(info.ScriptFolder)

    local guiParent = getGuiParent()
    local uid = math.random()
    local gui = guiParent:FindFirstChild(GUI_NAME)
    if gui then
        gui:SetAttribute("UID", uid)
        gui:ClearAllChildren()
    else
        gui = new("ScreenGui", {
            Name = GUI_NAME,
            IgnoreGuiInset = true,
            ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            Parent = guiParent,
        })
        gui:SetAttribute("UID", uid)
    end
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self.SCREENGUI_UID = uid
    State.Gui = gui

    if type(settings.SelectedTheme) == "string" and self:IsValidTheme(settings.SelectedTheme) then
        self:SetTheme(settings.SelectedTheme)
    else
        self:SetTheme(self.Default.Theme)
    end

    self.LOADED_UI_LIBRARY = true

    local viewport = getViewport()
    State.BaseScale = computeBaseScale()
    local scale = State.BaseScale * State.UserScale

    local size = Vector2.new(DESIGN_SIZE.X, DESIGN_SIZE.Y)
    if type(settings.UISize) == "table" then
        local savedWidth, savedHeight = settings.UISize[1], settings.UISize[2]
        if type(savedWidth) == "number" and type(savedHeight) == "number" then
            size = Vector2.new(math.clamp(savedWidth, MIN_SIZE.X, MAX_SIZE.X), math.clamp(savedHeight, MIN_SIZE.Y, MAX_SIZE.Y))
        end
    end
    size = Vector2.new(
        math.max(MIN_SIZE.X, math.min(size.X, viewport.X * 0.97 / scale)),
        math.max(MIN_SIZE.Y, math.min(size.Y, viewport.Y * 0.95 / scale))
    )

    local sidebarWidth = self.Default.SidebarWidth
    if type(settings.SidebarWidth) == "number" then
        sidebarWidth = math.clamp(settings.SidebarWidth, 120, 220)
    end

    local main = new("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(viewport.X / 2, viewport.Y / 2),
        Size = UDim2.fromOffset(size.X, size.Y),
        Active = true,
        ClipsDescendants = true,
        Parent = gui,
    })
    register(main, "BackgroundColor3", "Window")
    corner(main, 18)
    stroke(main, "Primary", 1.5, 0.55)

    State.Main = main
    State.MainScale = newScale(main)

    local topBar = new("Frame", {
        Name = "TopBar",
        Size = UDim2.new(1, 0, 0, TOPBAR_HEIGHT),
        BackgroundTransparency = 1,
        Active = true,
        Parent = main,
    })

    local divider = new("Frame", {
        Name = "Divider",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 1),
        Parent = topBar,
    })
    register(divider, "BackgroundColor3", "Stroke")

    local titleHolder = new("Frame", {
        Name = "TitleHolder",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(20, 0),
        Size = UDim2.new(1, -(20 + SEARCH_WIDTH + 12 + 88 + 8), 1, 0),
        Parent = topBar,
    })

    State.TitleLabel = makeLabel({
        Name = "Title",
        Position = UDim2.fromOffset(0, 8),
        Size = UDim2.new(1, 0, 0, 25),
        Text = info.Title,
        TextSize = 21,
        Font = FONT.ExtraBold,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = titleHolder,
    }, "Text")

    State.SubTitleLabel = makeLabel({
        Name = "SubTitle",
        Position = UDim2.fromOffset(0, 33),
        Size = UDim2.new(1, 0, 0, 16),
        Text = info.SubTitle,
        TextSize = 13,
        Font = FONT.Regular,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = titleHolder,
    }, "TextDim")

    local closeButton = makeButton({
        Name = "Close",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(40, 40),
        Parent = topBar,
    })
    register(closeButton, "BackgroundColor3", "Danger")
    corner(closeButton, 12)
    makeIcon({
        Name = "Icon",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(20, 20),
        Image = ICON.Close,
        Parent = closeButton,
    }, "Text")

    local minimizeButton = makeButton({
        Name = "Minimize",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -54, 0.5, 0),
        Size = UDim2.fromOffset(40, 40),
        Parent = topBar,
    })
    register(minimizeButton, "BackgroundColor3", "CardHover")
    corner(minimizeButton, 12)

    local minimizeBar = new("Frame", {
        Name = "Bar",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(16, 3),
        Parent = minimizeButton,
    })
    register(minimizeBar, "BackgroundColor3", "Text")
    corner(minimizeBar, 3)
    State.MinimizeBar = minimizeBar

    closeButton.MouseEnter:Connect(function()
        tween(closeButton, { BackgroundTransparency = 0.55 }, 0.15)
    end)
    closeButton.MouseLeave:Connect(function()
        tween(closeButton, { BackgroundTransparency = 1 }, 0.15)
    end)
    minimizeButton.MouseEnter:Connect(function()
        tween(minimizeButton, { BackgroundTransparency = 0 }, 0.15)
    end)
    minimizeButton.MouseLeave:Connect(function()
        tween(minimizeButton, { BackgroundTransparency = 1 }, 0.15)
    end)

    local searchBox = new("Frame", {
        Name = "SearchContainer",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -(10 + 40 + 4 + 40 + 10), 0.5, 0),
        Size = UDim2.fromOffset(SEARCH_WIDTH, 38),
        Parent = topBar,
    })
    register(searchBox, "BackgroundColor3", "Field")
    corner(searchBox, 12)
    local searchStroke = stroke(searchBox, "Stroke", 1.5, 0.2)

    local searchInput = new("TextBox", {
        Name = "SearchBar",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -44, 1, 0),
        PlaceholderText = "Search Section And Function",
        Text = "",
        TextSize = 15,
        Font = FONT.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ClearTextOnFocus = false,
        Parent = searchBox,
    })
    register(searchInput, "TextColor3", "Text")
    register(searchInput, "PlaceholderColor3", "TextDim")

    makeIcon({
        Name = "SearchIcon",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        Image = ICON.Search,
        Parent = searchBox,
    }, "TextDim")

    searchInput.Focused:Connect(function()
        searchStroke.Color = Lib.CurrentTheme.Primary
    end)
    searchInput.FocusLost:Connect(function()
        searchStroke.Color = Lib.CurrentTheme.Stroke
    end)
    searchInput:GetPropertyChangedSignal("Text"):Connect(function()
        State.WindowObject:PerformSearch(searchInput.Text)
    end)

    local sidebar = new("ScrollingFrame", {
        Name = "TabsScroll",
        Position = UDim2.fromOffset(10, TOPBAR_HEIGHT + 8),
        Size = UDim2.new(0, sidebarWidth, 1, -(TOPBAR_HEIGHT + 8 + 22)),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 0.3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Parent = main,
    })
    register(sidebar, "ScrollBarImageColor3", "Primary")
    pad(sidebar, 0, 4, 0, 4)
    vlist(sidebar, 6)

    local content = new("Frame", {
        Name = "Containers",
        Position = UDim2.fromOffset(10 + sidebarWidth + 8, TOPBAR_HEIGHT + 8),
        Size = UDim2.new(1, -(10 + sidebarWidth + 8 + 10), 1, -(TOPBAR_HEIGHT + 8 + 22)),
        ClipsDescendants = true,
        Parent = main,
    })
    register(content, "BackgroundColor3", "Content")
    corner(content, 14)
    stroke(content, "Stroke", 1, 0.45)

    State.NoResults = makeLabel({
        Name = "NoResults",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -40, 0, 30),
        Text = "No results found",
        TextSize = 17,
        TextXAlignment = Enum.TextXAlignment.Center,
        Visible = false,
        ZIndex = 3,
        Parent = content,
    }, "TextDim")

    State.Sidebar = sidebar
    State.Content = content
    State.Elements = table.freeze({
        ContainerHolder = content,
        TabsContainer = sidebar,
        Components = main,
        MainFrame = main,
    })

    local grip = new("Frame", {
        Name = "ControlWindowSize",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -2, 1, -2),
        Size = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 6,
        Parent = main,
    })
    for _, dot in ipairs({ { 18, 18 }, { 10, 18 }, { 18, 10 } }) do
        local gripDot = new("Frame", {
            Position = UDim2.fromOffset(dot[1], dot[2]),
            Size = UDim2.fromOffset(4, 4),
            BackgroundTransparency = 0.35,
            ZIndex = 6,
            Parent = grip,
        })
        register(gripDot, "BackgroundColor3", "TextDim")
        corner(gripDot, 2)
    end
    State.Grip = grip

    local window = setmetatable(info, { __index = Window })
    window.SelectedTab = 1
    window.SelectedTabs = {}
    window.Minimized = false
    window.SUBTITLE_LABEL = State.SubTitleLabel
    window.TITLE_LABEL = State.TitleLabel
    State.WindowObject = window

    topBar.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        local startX, startY = main.Position.X.Offset, main.Position.Y.Offset
        startDrag(input, function(position, origin)
            main.Position = UDim2.fromOffset(startX + (position.X - origin.X), startY + (position.Y - origin.Y))
        end, clampWindow)
    end)

    grip.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end
        local current = State.BaseScale * State.UserScale
        local startSize = Vector2.new(main.Size.X.Offset, main.Size.Y.Offset)
        local startX, startY = main.Position.X.Offset, main.Position.Y.Offset
        local limit = getViewport()
        local maxWidth = math.min(MAX_SIZE.X, limit.X * 0.98 / current)
        local maxHeight = math.min(MAX_SIZE.Y, limit.Y * 0.98 / current)

        startDrag(input, function(position, origin)
            local width = math.clamp(startSize.X + (position.X - origin.X) / current, MIN_SIZE.X, math.max(MIN_SIZE.X, maxWidth))
            local height = math.clamp(startSize.Y + (position.Y - origin.Y) / current, MIN_SIZE.Y, math.max(MIN_SIZE.Y, maxHeight))
            main.Size = UDim2.fromOffset(width, height)
            main.Position = UDim2.fromOffset(
                startX + (width - startSize.X) * current / 2,
                startY + (height - startSize.Y) * current / 2
            )
        end, function()
            settings.UISize = { main.Size.X.Offset, main.Size.Y.Offset }
            clampWindow()
        end)
    end)

    minimizeButton.Activated:Connect(function()
        window:MinimizeButton()
    end)

    closeButton.Activated:Connect(function()
        window:Dialog({
            Title = "Close Window?",
            Content = "You Want Close UI?",
            Options = {
                {
                    Title = "YES",
                    Callback = function()
                        Lib:Destroy()
                    end,
                },
                { Title = "NO" },
            },
        })
    end)

    main.Destroying:Connect(function()
        Lib:Destroy()
    end)

    connect(gui:GetAttributeChangedSignal("UID"), function()
        if gui:GetAttribute("UID") ~= self.SCREENGUI_UID then
            Lib:Destroy()
        end
    end)

    local camera = workspace.CurrentCamera
    if camera then
        connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
            State.BaseScale = computeBaseScale()
            applyScale()
            clampWindow()
        end)
    end

    return window
end
local function parseConfig(kind, config)
    if type(config) ~= "table" then
        error("\"Tab.Add" .. kind .. "[Configs]\". 'table' expected, got " .. typeof(config), 3)
    end

    local title = config[1] or config.Name or config.Title
    local description = config.Desc or config.Description

    assert(type(title) == "string", "\"Tab.Add" .. kind .. ".Title\". 'string' expected, got " .. typeof(title))
    if description ~= nil and type(description) ~= "string" then
        error("\"Tab.Add" .. kind .. ".Description\". 'string', or 'nil' expected, got " .. typeof(description), 3)
    end

    return title, description or ""
end

local function parseFlag(kind, flag)
    if flag ~= nil and type(flag) ~= "string" then
        error("\"Tab.Add" .. kind .. ".Flag\". 'nil', or 'string' expected, got " .. typeof(flag), 3)
    end
    return flag
end

local function truncateText(text, maxChars)
    local length = utf8.len(text)
    if length and length > maxChars then
        return string.sub(text, 1, utf8.offset(text, maxChars - 2) - 1) .. "..."
    end
    return text
end

local function createCard(tab, title, description, rightWidth)
    local card = new("Frame", {
        Name = "Option",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = tab._container,
    })
    register(card, "BackgroundColor3", "Card")
    corner(card, 14)
    local cardStroke = stroke(card, "Stroke", 1, 0.2)
    vlist(card, 0)

    local header = makeButton({
        Name = "Header",
        Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
        Parent = card,
    })

    local left = new("Frame", {
        Name = "Left",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -(rightWidth + 16 + 14 + 12), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = header,
    })
    local leftPadding = pad(left, 0, 0, 17, 17)
    vlist(left, 3)

    local titleLabel = makeLabel({
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = title,
        TextSize = 17,
        Font = FONT.Bold,
        TextWrapped = true,
        LayoutOrder = 1,
        Parent = left,
    }, "Text")

    local descLabel = makeLabel({
        Name = "Description",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = description,
        TextSize = 14,
        Font = FONT.Regular,
        TextWrapped = true,
        RichText = true,
        LayoutOrder = 2,
        Visible = description ~= "",
        Parent = left,
    }, "TextDim")

    local function refreshDescription()
        local has = descLabel.Text ~= ""
        descLabel.Visible = has
        local vertical = has and 12 or 17
        leftPadding.PaddingTop = UDim.new(0, vertical)
        leftPadding.PaddingBottom = UDim.new(0, vertical)
    end
    refreshDescription()
    descLabel:GetPropertyChangedSignal("Text"):Connect(refreshDescription)

    local hovering = false
    local function setBackground(key)
        tween(card, { BackgroundColor3 = Lib.CurrentTheme[key] }, 0.15)
    end

    header.MouseEnter:Connect(function()
        hovering = true
        setBackground("CardHover")
    end)
    header.MouseLeave:Connect(function()
        hovering = false
        setBackground("Card")
    end)
    header.InputBegan:Connect(function(input)
        if isPress(input) then
            setBackground("CardPress")
        end
    end)
    header.InputEnded:Connect(function(input)
        if isPress(input) then
            if input.UserInputType == Enum.UserInputType.Touch then
                hovering = false
            end
            setBackground(hovering and "CardHover" or "Card")
        end
    end)

    return {
        Card = card,
        Header = header,
        Stroke = cardStroke,
        Title = titleLabel,
        Description = descLabel,
    }
end

local function baseFields(tab, parts, title, description, kind, callbacks)
    return {
        CALLBACKS = callbacks,
        DESTROY_ELEMENT = parts.Card,
        VISIBLE_ELEMENT = parts.Card,
        TITLE_LABEL = parts.Title,
        DESCRIPTION_LABEL = parts.Description,
        Title = title,
        Description = description,
        Parent = tab,
        Kind = kind,
    }
end

function Element:SetTitle(title)
    assert(type(title) == "string", "\"Option.SetTitle\". 'string' expected, got " .. typeof(title))
    assert(self.TITLE_LABEL, "\"Option.SetTitle\". cannot change this option name " .. tostring(self.Kind) .. ":" .. tostring(self.Title))

    self.TITLE_LABEL.Text = title
    self.Title = title
    if self._entry then
        self._entry.Title = normalize(title)
    end
    return self
end

function Element:SetDescription(description)
    assert(description == nil or type(description) == "string", "\"Option.SetDescription\". 'string', or 'nil' expected, got " .. typeof(description))
    assert(self.DESCRIPTION_LABEL, "\"Option.SetDescription\". cannot change this option description " .. tostring(self.Kind) .. ":" .. tostring(self.Title))

    self.DESCRIPTION_LABEL.Text = description or ""
    self.Description = description
    if self._entry then
        self._entry.Description = normalize(description or "")
    end
    return self
end

function Element:SetVisible(visible)
    assert(typeof(self.VISIBLE_ELEMENT) == "Instance", "\"Option.SetVisible\". cannot change this option visibility " .. tostring(self.Kind) .. ":" .. tostring(self.Title))
    assert(type(visible) == "boolean", "\"Option.SetVisible\". 'boolean' expected, got " .. typeof(visible))

    if self._entry then
        self._entry.UserHidden = not visible
        refreshEntry(self._entry)
    else
        self.VISIBLE_ELEMENT.Visible = visible
    end
end

function Element:Destroy()
    assert(typeof(self.DESTROY_ELEMENT) == "Instance", "\"Option.Destroy\". cannot destroy this option " .. tostring(self.Kind) .. ":" .. tostring(self.Title))

    local target = self.DESTROY_ELEMENT
    removeSearchEntries(function(entry)
        return entry.Frame == target
    end)

    target:Destroy()
    setmetatable(self, nil)
    self.Destroyed = true
end

function Element:AddCallback(callback)
    assert(self.CALLBACKS, "\"Option.AddCallback\". cannot add callback to this option.")
    assert(type(callback) == "function", "\"Option.AddCallback[param 1]\". 'function' expected, got " .. typeof(callback))

    table.insert(self.CALLBACKS, callback)
    return self
end

Element.NewCallback = Element.AddCallback
Element.SetContent = Element.SetDescription
Element.SetDesc = Element.SetDescription

local function subclass()
    local class = setmetatable({}, { __index = Element })
    class.__index = class
    return class
end

local ToggleClass = subclass()
local SliderClass = subclass()
local DropdownClass = subclass()
local TextBoxClass = subclass()

function Tab:AddSection(title)
    assert(title == nil or type(title) == "string", "\"Tab.AddSection[param 1]\". 'string', or 'nil' expected, got " .. typeof(title))
    title = title or ""

    local frame = new("Frame", {
        Name = "Section",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
        Parent = self._container,
    })

    local accent = new("Frame", {
        Name = "Accent",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 2, 1, -5),
        Size = UDim2.fromOffset(4, 20),
        Parent = frame,
    })
    register(accent, "BackgroundColor3", "Primary")
    corner(accent, 2)

    local label = makeLabel({
        Name = "Title",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, -4),
        Size = UDim2.new(1, -20, 0, 22),
        Text = title,
        TextSize = 18,
        Font = FONT.ExtraBold,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = frame,
    }, "Primary")

    local object = setmetatable({
        Title = title,
        DESTROY_ELEMENT = frame,
        VISIBLE_ELEMENT = frame,
        TITLE_LABEL = label,
        Kind = "Section",
        Parent = self,
    }, Element)
    object._entry = registerSearch(self, frame, title, "section")

    return object
end

function Tab:AddParagraph(title, description)
    assert(type(title) == "string", "\"Tab.AddParagraph[param 1]\". 'string' expected, got " .. typeof(title))
    if description ~= nil and type(description) ~= "string" then
        error("\"Tab.AddParagraph[param 2]\". 'string', or 'nil' expected, got " .. typeof(description), 2)
    end

    local parts = createCard(self, title, description or "", 0)
    local object = setmetatable(baseFields(self, parts, title, description, "Paragraph", nil), Element)
    object._entry = registerSearch(self, parts.Card, title, "paragraph", description)
    return object
end

function Tab:AddToggle(config)
    local title, description = parseConfig("Toggle", config)
    local flag = parseFlag("Toggle", config[4] or config.Flag)

    local default = config[2]
    if default == nil then
        default = config.Default
    end
    if default == nil then
        default = false
    end
    if type(default) ~= "boolean" then
        error("\"Tab.AddToggle.Default\". 'boolean' expected, got " .. typeof(default), 2)
    end

    local callbacks = normalizeCallbacks(config[3] or config.Callback)

    if flag and type(State.Flags[flag]) == "number" then
        default = State.Flags[flag] == 0
    end

    local parts = createCard(self, title, description, 54)
    local header = parts.Header

    local track = new("Frame", {
        Name = "Track",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(54, 30),
        Parent = header,
    })
    corner(track, 15)

    local knob = new("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        Parent = track,
    })
    corner(knob, 12)

    local object = setmetatable(baseFields(self, parts, title, description, "Toggle", callbacks), ToggleClass)
    object._entry = registerSearch(self, parts.Card, title, "toggle", description)

    local function render(value, animate)
        local theme = Lib.CurrentTheme
        local trackColor = value and theme.Primary or theme.Track
        local knobColor = value and theme.Knob or theme.KnobOff
        local knobPosition = UDim2.new(0, value and 27 or 3, 0.5, 0)
        local strokeColor = value and theme.Primary or theme.Stroke
        local strokeTransparency = value and 0.45 or 0.2

        if animate then
            tween(track, { BackgroundColor3 = trackColor }, 0.22)
            tween(knob, { Position = knobPosition, BackgroundColor3 = knobColor }, 0.22, Enum.EasingStyle.Back)
            tween(parts.Stroke, { Color = strokeColor, Transparency = strokeTransparency }, 0.22)
        else
            track.BackgroundColor3 = trackColor
            knob.BackgroundColor3 = knobColor
            knob.Position = knobPosition
            parts.Stroke.Color = strokeColor
            parts.Stroke.Transparency = strokeTransparency
        end
    end

    onTheme(track, function()
        render(object.Value == true, false)
    end)

    object.WHEN_VALUE_CHANGED = function(value)
        if flag then
            State.Flags[flag] = value and 0 or 1
        end
        fireCallbacks(callbacks, value)
        render(value, self.Selected == true)
    end

    local lastActivated = 0
    header.Activated:Connect(function()
        if os.clock() - lastActivated >= 0.18 then
            lastActivated = os.clock()
            object:SetValue(not object.Value)
        end
    end)

    object:SetValue(default)
    return object
end

function ToggleClass:SetValue(value)
    assert(type(value) == "boolean", "\"Toggle.SetValue\". 'boolean' expected, got " .. typeof(value))

    if self.Value ~= value then
        self.Value = value
        self.WHEN_VALUE_CHANGED(value)
    end
end

ToggleClass.Set = ToggleClass.SetValue

function Tab:AddButton(config)
    local title, description = parseConfig("Button", config)
    local callbacks = normalizeCallbacks(config[2] or config.Callback)
    local debounce = config.Debounce or config.Cooldown

    local parts = createCard(self, title, description, 30)
    local header = parts.Header

    local icon = makeIcon({
        Name = "Icon",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -18, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
        Image = ICON.Button,
        Parent = header,
    }, "Primary")

    local blockedUntil = 0
    header.Activated:Connect(function()
        if debounce ~= nil and os.clock() < blockedUntil then
            return
        end
        if debounce ~= nil then
            blockedUntil = os.clock() + debounce
        end

        parts.Stroke.Color = Lib.CurrentTheme.Primary
        parts.Stroke.Transparency = 0
        tween(parts.Stroke, { Transparency = 0.2 }, 0.35)
        icon.Size = UDim2.fromOffset(18, 18)
        tween(icon, { Size = UDim2.fromOffset(24, 24) }, 0.3, Enum.EasingStyle.Back)
        task.delay(0.35, function()
            if parts.Stroke.Parent then
                parts.Stroke.Color = Lib.CurrentTheme.Stroke
            end
        end)

        fireCallbacks(callbacks)
    end)

    local object = setmetatable(baseFields(self, parts, title, description, "Button", callbacks), Element)
    object._entry = registerSearch(self, parts.Card, title, "button", description)
    return object
end

function Tab:AddTextBox(config)
    local title, description = parseConfig("TextBox", config)
    local flag = parseFlag("TextBox", config[4] or config.Flag)

    local default = config[2] or config.Default
    local callbacks = normalizeCallbacks(config[3] or config.Callback)
    local placeholder = config.Placeholder or config.PlaceholderText
    local clearOnFocus = config.ClearOnFocus
    if clearOnFocus == nil then
        clearOnFocus = config.ClearTextOnFocus
    end

    if default ~= nil and type(default) ~= "string" then
        error("\"Tab.AddTextBox.Default\". 'string', or 'nil' expected, got " .. typeof(default), 2)
    end
    if flag and type(State.Flags[flag]) == "string" then
        default = State.Flags[flag]
    end

    local parts = createCard(self, title, description, 180)
    local header = parts.Header

    local field = new("Frame", {
        Name = "Field",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(180, 40),
        Parent = header,
    })
    register(field, "BackgroundColor3", "Field")
    corner(field, 10)
    local fieldStroke = stroke(field, "Stroke", 1.5, 0.2)

    local input = new("TextBox", {
        Name = "Input",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Text = "",
        PlaceholderText = placeholder or DEFAULT_PLACEHOLDER,
        TextSize = 16,
        Font = FONT.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Active = true,
        Parent = field,
    })
    register(input, "TextColor3", "Text")
    register(input, "PlaceholderColor3", "TextDim")

    if default ~= nil then
        input.Text = default
    end
    if clearOnFocus ~= nil then
        input.ClearTextOnFocus = clearOnFocus
    end

    local object = setmetatable(baseFields(self, parts, title, description, "TextBox", callbacks), TextBoxClass)
    object.TEXTBOX = input
    object.BUTTON = parts.Card
    object._entry = registerSearch(self, parts.Card, title, "textbox", description)

    if flag then
        input:GetPropertyChangedSignal("Text"):Connect(function()
            State.Flags[flag] = input.Text
        end)
    end

    input.Focused:Connect(function()
        tween(fieldStroke, { Color = Lib.CurrentTheme.Primary, Transparency = 0 }, 0.15)
    end)

    input.FocusLost:Connect(function()
        tween(fieldStroke, { Color = Lib.CurrentTheme.Stroke, Transparency = 0.2 }, 0.15)

        local filter = object.TEXTBOX_TEXT_FILTER
        if filter then
            local ok, filtered = pcall(filter, input.Text)
            if ok then
                if type(filtered) == "string" then
                    input.Text = filtered
                end
            else
                warnf("TextBox text filter failed: " .. tostring(filtered))
            end
        end

        fireCallbacks(callbacks, input.Text)
    end)

    header.Activated:Connect(function()
        input:CaptureFocus()
    end)

    return object
end

function TextBoxClass:SetText(text)
    assert(type(text) == "string", "\"TextBox.SetText\". 'string' expected, got " .. typeof(text))
    self.TEXTBOX.Text = text
    return self
end

function TextBoxClass:SetPlaceholder(text)
    assert(type(text) == "string", "\"TextBox.SetPlaceholder\". 'string' expected, got " .. typeof(text))
    self.TEXTBOX.PlaceholderText = text
    return self
end

function TextBoxClass:CaptureFocus()
    self.TEXTBOX:CaptureFocus()
    return self
end

function TextBoxClass:Clear()
    self.TEXTBOX.Text = ""
    return self
end

function TextBoxClass:SetTextFilter(filter)
    if filter ~= nil then
        assert(type(filter) == "function", "\"TextBox.SetTextFilter[param 1]\". 'function', or 'nil' expected, got " .. typeof(filter))
    end
    self.TEXTBOX_TEXT_FILTER = filter
    return self
end

TextBoxClass.Set = TextBoxClass.SetText

function Tab:AddSlider(config)
    local title, description = parseConfig("Slider", config)
    local flag = parseFlag("Slider", config[7] or config.Flag)

    local minimum = config[2] or config.Min
    local maximum = config[3] or config.Max
    local increment = config[4] or config.Increment
    local default = config[5] or config.Default
    local callbacks = normalizeCallbacks(config[6] or config.Callback)

    if increment ~= nil and type(increment) ~= "number" then
        error("\"Tab.AddSlider.Increment\". 'number', or 'nil' expected, got " .. typeof(increment), 2)
    end
    if default ~= nil and type(default) ~= "number" then
        error("\"Tab.AddSlider.Default\". 'number', or 'nil' expected, got " .. typeof(default), 2)
    end
    assert(type(minimum) == "number", "\"Tab.AddSlider.Min\", 'number' expected, got " .. typeof(minimum))
    assert(type(maximum) == "number", "\"Tab.AddSlider.Max\", 'number' expected, got " .. typeof(maximum))

    if default == nil then
        default = minimum
    end
    if increment == nil or increment <= 0 then
        increment = 1
    end
    if flag and type(State.Flags[flag]) == "number" then
        default = State.Flags[flag]
    end

    local parts = createCard(self, title, description, 84)
    local header = parts.Header
    local card = parts.Card

    local valueField = new("Frame", {
        Name = "ValueField",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(84, 36),
        Parent = header,
    })
    register(valueField, "BackgroundColor3", "Field")
    corner(valueField, 10)
    local valueStroke = stroke(valueField, "Stroke", 1.5, 0.2)

    local valueInput = new("TextBox", {
        Name = "Value",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextSize = 17,
        Font = FONT.Bold,
        TextXAlignment = Enum.TextXAlignment.Center,
        ClearTextOnFocus = true,
        Active = true,
        Parent = valueField,
    })
    register(valueInput, "TextColor3", "Primary")

    local extra = new("Frame", {
        Name = "Extra",
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = card,
    })

    local hit = makeButton({
        Name = "Hit",
        Size = UDim2.fromScale(1, 1),
        Parent = extra,
    })

    local rail = new("Frame", {
        Name = "Rail",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 20, 0.5, -4),
        Size = UDim2.new(1, -40, 0, 8),
        Parent = hit,
    })
    register(rail, "BackgroundColor3", "Track")
    corner(rail, 4)

    local fill = new("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(0, 1),
        Parent = rail,
    })
    register(fill, "BackgroundColor3", "Primary")
    corner(fill, 4)

    local knob = new("Frame", {
        Name = "Knob",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(24, 24),
        ZIndex = 2,
        Parent = rail,
    })
    register(knob, "BackgroundColor3", "Knob")
    corner(knob, 12)
    stroke(knob, "Primary", 2.5, 0)

    local object = setmetatable(baseFields(self, parts, title, description, "Slider", callbacks), SliderClass)
    object.Min = minimum
    object.Max = maximum
    object.Increment = increment
    object._entry = registerSearch(self, card, title, "slider", description)

    local function ratioOf(value)
        if maximum == minimum then
            return 0
        end
        return math.clamp((value - minimum) / (maximum - minimum), 0, 1)
    end

    local function snap(value)
        local snapped = math.round(value / increment) * increment
        snapped = math.floor(snapped * 1000000 + 0.5) / 1000000
        return math.clamp(snapped, minimum, maximum)
    end

    local function show(value, animate)
        local ratio = ratioOf(value)
        valueInput.Text = tostring(math.floor(value * 1000) / 1000)
        if animate then
            tween(fill, { Size = UDim2.fromScale(ratio, 1) }, 0.25)
            tween(knob, { Position = UDim2.fromScale(ratio, 0.5) }, 0.25)
        else
            fill.Size = UDim2.fromScale(ratio, 1)
            knob.Position = UDim2.fromScale(ratio, 0.5)
        end
    end

    local function commit(value, animate)
        if value == object.Value then
            return
        end

        object.Value = value
        if flag then
            State.Flags[flag] = value
        end
        task.defer(fireCallbacks, callbacks, value)
        show(value, animate and self.Selected == true)
    end

    object.WHEN_VALUE_CHANGED = function(value)
        commit(snap(value), true)
    end

    valueInput.Focused:Connect(function()
        tween(valueStroke, { Color = Lib.CurrentTheme.Primary, Transparency = 0 }, 0.15)
    end)

    valueInput.FocusLost:Connect(function()
        tween(valueStroke, { Color = Lib.CurrentTheme.Stroke, Transparency = 0.2 }, 0.15)
        local typed = tonumber(valueInput.Text)
        if typed then
            object:SetValue(typed)
        end
        show(object.Value or minimum, false)
    end)

    hit.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end

        local scroller = self._container
        scroller.ScrollingEnabled = false

        local function update(positionX)
            local width = rail.AbsoluteSize.X
            if width <= 0 then
                return
            end
            local ratio = math.clamp((positionX - rail.AbsolutePosition.X) / width, 0, 1)
            commit(snap(minimum + ratio * (maximum - minimum)), false)
        end

        tween(knob, { Size = UDim2.fromOffset(30, 30) }, 0.12)
        update(input.Position.X)

        local drag = startDrag(input, function(position)
            update(position.X)
        end, function()
            scroller.ScrollingEnabled = true
            tween(knob, { Size = UDim2.fromOffset(24, 24) }, 0.15)
        end)

        if not drag then
            scroller.ScrollingEnabled = true
            tween(knob, { Size = UDim2.fromOffset(24, 24) }, 0.15)
        end
    end)

    commit(snap(default), false)
    return object
end

function SliderClass:SetValue(value)
    assert(type(value) == "number", "\"Slider.SetValue\". 'number' expected, got " .. typeof(value))

    if self.Value ~= value then
        self.WHEN_VALUE_CHANGED(value)
    end
end

SliderClass.Set = SliderClass.SetValue

function Tab:AddDropdown(config)
    local title, description = parseConfig("Dropdown", config)
    local flag = parseFlag("Dropdown", config[5] or config.Flag)

    local initialOptions = config[2] or config.Options
    local default = config[3] or config.Default
    local callbacks = normalizeCallbacks(config[4] or config.Callback)
    local multi = config.MultiSelect == true

    if default ~= nil and type(default) ~= "table" and type(default) ~= "string" then
        error("\"Tab.AddDropdown.Default\". 'string', 'table', or 'nil' expected, got " .. typeof(default), 2)
    end
    if initialOptions ~= nil and type(initialOptions) ~= "table" then
        error("\"Tab.AddDropdown.Options\". 'table', or 'nil' expected, got " .. typeof(initialOptions), 2)
    end
    if config.MultiSelect ~= nil and type(config.MultiSelect) ~= "boolean" then
        error("\"Tab.AddDropdown.MultiSelect\". 'boolean', or 'nil' expected, got " .. typeof(config.MultiSelect), 2)
    end
    if flag and type(State.Flags[flag]) == (multi and "table" or "string") then
        default = State.Flags[flag]
    end

    local parts = createCard(self, title, description, 170)
    local header = parts.Header
    local card = parts.Card

    local pill = new("Frame", {
        Name = "Pill",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(170, 40),
        Parent = header,
    })
    register(pill, "BackgroundColor3", "Field")
    corner(pill, 10)
    local pillStroke = stroke(pill, "Stroke", 1.5, 0.2)

    local valueLabel = makeLabel({
        Name = "Value",
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -42, 1, 0),
        Text = "...",
        TextSize = 16,
        Font = FONT.Bold,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = pill,
    }, "Text")

    local chevron = makeIcon({
        Name = "Chevron",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(20, 20),
        Image = ICON.DropdownOpen,
        Parent = pill,
    }, "TextDim")

    local listFrame = new("Frame", {
        Name = "List",
        Size = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Visible = false,
        LayoutOrder = 2,
        Parent = card,
    })

    local listDivider = new("Frame", {
        Name = "Divider",
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -28, 0, 1),
        Parent = listFrame,
    })
    register(listDivider, "BackgroundColor3", "Stroke")

    local inner = new("Frame", {
        Name = "Inner",
        Position = UDim2.fromOffset(0, 1),
        Size = UDim2.new(1, 0, 1, -1),
        BackgroundTransparency = 1,
        Parent = listFrame,
    })
    pad(inner, 12, 12, 10, 12)
    vlist(inner, 8)

    local filterBox = new("Frame", {
        Name = "Filter",
        Size = UDim2.new(1, 0, 0, 38),
        Visible = false,
        LayoutOrder = 1,
        Parent = inner,
    })
    register(filterBox, "BackgroundColor3", "Field")
    corner(filterBox, 10)
    stroke(filterBox, "Stroke", 1, 0.3)

    local filterInput = new("TextBox", {
        Name = "Input",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        Text = "",
        PlaceholderText = "Filter...",
        TextSize = 15,
        Font = FONT.Medium,
        TextXAlignment = Enum.TextXAlignment.Left,
        ClearTextOnFocus = false,
        Active = true,
        Parent = filterBox,
    })
    register(filterInput, "TextColor3", "Text")
    register(filterInput, "PlaceholderColor3", "TextDim")

    local scrollFrame = new("ScrollingFrame", {
        Name = "Options",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 0.25,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        LayoutOrder = 2,
        Parent = inner,
    })
    register(scrollFrame, "ScrollBarImageColor3", "Primary")
    pad(scrollFrame, 0, 6, 0, 0)
    vlist(scrollFrame, 4)

    local options = {}
    local byName = {}
    local multiMap = {}
    local pending = {}
    local selectedName
    local opened = false
    local scheduled = false
    local initializing = true

    local object = setmetatable(baseFields(self, parts, title, description, "Dropdown", callbacks), DropdownClass)
    object.DROPDOWN_OPTIONS = options
    object.Opened = false
    object._entry = registerSearch(self, card, title, "dropdown", description)

    local function listHeight()
        local rows = math.max(1, math.min(#options, 5))
        local scrollHeight = rows * 44 - 4
        scrollFrame.Size = UDim2.new(1, 0, 0, scrollHeight)
        filterBox.Visible = #options >= 8
        return 1 + 10 + (filterBox.Visible and 46 or 0) + scrollHeight + 12
    end

    local function setOpen(open)
        if open == opened then
            return
        end

        opened = open
        object.Opened = open
        chevron.Image = open and ICON.DropdownClose or ICON.DropdownOpen

        if open then
            listFrame.Visible = true
            tween(listFrame, { Size = UDim2.new(1, 0, 0, listHeight()) }, 0.3)
            tween(pillStroke, { Color = Lib.CurrentTheme.Primary, Transparency = 0 }, 0.2)
            tween(chevron, { ImageColor3 = Lib.CurrentTheme.Primary }, 0.2)
        else
            tween(listFrame, { Size = UDim2.new(1, 0, 0, 0) }, 0.22)
            tween(pillStroke, { Color = Lib.CurrentTheme.Stroke, Transparency = 0.2 }, 0.2)
            tween(chevron, { ImageColor3 = Lib.CurrentTheme.TextDim }, 0.2)
            task.delay(0.24, function()
                if not opened and listFrame.Parent then
                    listFrame.Visible = false
                end
            end)
        end
    end

    local function styleOption(option, animate)
        if not option.Instance then
            return
        end

        local theme = Lib.CurrentTheme
        local selected = option.Selected
        local rowTransparency = selected and 0.8 or 1
        local textColor = selected and theme.Primary or theme.Text

        local indicatorGoal = {}
        if multi then
            indicatorGoal.BackgroundColor3 = selected and theme.Primary or theme.Field
        end
        local strokeColor = selected and theme.Primary or theme.TextDim
        local dotSize = (not multi and selected) and UDim2.fromOffset(10, 10) or UDim2.fromOffset(0, 0)

        if animate then
            tween(option.Instance, { BackgroundTransparency = rowTransparency }, 0.18)
            tween(option.Label, { TextColor3 = textColor }, 0.18)
            tween(option.IndicatorStroke, { Color = strokeColor }, 0.18)
            tween(option.Dot, { Size = dotSize }, 0.18, Enum.EasingStyle.Back)
            if multi then
                tween(option.Indicator, indicatorGoal, 0.18)
            end
        else
            option.Instance.BackgroundTransparency = rowTransparency
            option.Label.TextColor3 = textColor
            option.IndicatorStroke.Color = strokeColor
            option.Dot.Size = dotSize
            if multi then
                option.Indicator.BackgroundColor3 = indicatorGoal.BackgroundColor3
            end
        end
    end

    local function selectedList()
        local list = {}
        if multi then
            for _, option in ipairs(options) do
                if multiMap[option.Name] then
                    table.insert(list, option.Name)
                end
            end
        end
        return list
    end

    local function refreshDisplay()
        local text
        if multi then
            text = table.concat(selectedList(), ", ")
        else
            text = selectedName or ""
        end
        text = truncateText(text, 100)
        valueLabel.Text = text ~= "" and text or "..."
    end

    local function commit()
        scheduled = false

        local value
        if multi then
            value = selectedList()
        else
            value = selectedName
        end

        object.Value = value
        refreshDisplay()

        if flag then
            State.Flags[flag] = value
        end

        fireCallbacks(callbacks, multi and multiMap or value)
    end

    local function scheduleCommit()
        if initializing or scheduled then
            return
        end
        scheduled = true
        task.delay(0.1, commit)
    end

    local function onOptionClicked(option)
        if multi then
            local value = not option.Selected
            option.Selected = value
            multiMap[option.Name] = value
            pending[option.Name] = nil
            styleOption(option, true)
        else
            if selectedName == option.Name then
                setOpen(false)
                return
            end

            local previous = byName[selectedName]
            if previous then
                previous.Selected = false
                styleOption(previous, true)
            end

            selectedName = option.Name
            option.Selected = true
            styleOption(option, true)
            setOpen(false)
        end

        scheduleCommit()
    end

    local function buildOption(option)
        local button = makeButton({
            Name = "Option",
            Size = UDim2.new(1, 0, 0, 40),
            LayoutOrder = #options,
            Parent = scrollFrame,
        })
        register(button, "BackgroundColor3", "Primary")
        corner(button, 10)

        local indicator = new("Frame", {
            Name = "Indicator",
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 12, 0.5, 0),
            Size = UDim2.fromOffset(22, 22),
            BackgroundTransparency = multi and 0 or 1,
            Parent = button,
        })
        corner(indicator, multi and 6 or 11)
        if multi then
            register(indicator, "BackgroundColor3", "Field")
        end
        local indicatorStroke = stroke(indicator, "TextDim", 2, 0)

        local dot = new("Frame", {
            Name = "Dot",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(0, 0),
            Parent = indicator,
        })
        register(dot, "BackgroundColor3", "Primary")
        corner(dot, 5)

        local label = makeLabel({
            Name = "Label",
            Position = UDim2.fromOffset(44, 0),
            Size = UDim2.new(1, -54, 1, 0),
            Text = option.DisplayName,
            TextSize = 16,
            Font = FONT.Medium,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = button,
        }, "Text")

        option.Instance = button
        option.Indicator = indicator
        option.IndicatorStroke = indicatorStroke
        option.Dot = dot
        option.Label = label

        button.Activated:Connect(function()
            onOptionClicked(option)
        end)

        onTheme(button, function()
            styleOption(option, false)
        end)
    end

    local function lookup(value, index)
        if index and type(value) == "boolean" then
            return value == true and options[index] or nil
        end
        if type(value) == "number" then
            return options[value]
        end
        return byName[tostring(value)]
    end

    local function markSelected(option)
        option.Selected = true
        if multi then
            multiMap[option.Name] = true
        else
            selectedName = option.Name
        end
    end

    local function isSelectedName(name)
        if multi then
            return (multiMap[name] or pending[name]) == true
        end
        return selectedName == name
    end

    local function addOption(value)
        if type(value) == "table" then
            for _, nested in ipairs(value) do
                addOption(nested)
            end
            return
        end

        local name = tostring(value)
        if byName[name] then
            return
        end

        local option = { Name = name, DisplayName = name, Selected = false }
        byName[name] = option
        table.insert(options, option)

        if multi and multiMap[name] == nil then
            multiMap[name] = false
        end

        buildOption(option)

        if isSelectedName(name) then
            markSelected(option)
            pending[name] = nil
        end
        styleOption(option, false)

        if opened then
            listFrame.Size = UDim2.new(1, 0, 0, listHeight())
        else
            listHeight()
        end
        scheduleCommit()
    end

    local function removeOption(value)
        local name = tostring(value)
        local option = byName[name]
        if not option then
            return
        end

        local index = table.find(options, option)
        if index then
            table.remove(options, index)
        end
        byName[name] = nil

        if multi then
            multiMap[name] = nil
        elseif selectedName == name then
            selectedName = nil
        end

        if option.Instance then
            option.Instance:Destroy()
        end
        if opened then
            listFrame.Size = UDim2.new(1, 0, 0, listHeight())
        else
            listHeight()
        end
        scheduleCommit()
    end

    local function clearOptions()
        for index = #options, 1, -1 do
            local option = options[index]
            if option.Instance then
                option.Instance:Destroy()
            end
            byName[option.Name] = nil
            options[index] = nil
        end
        if opened then
            listFrame.Size = UDim2.new(1, 0, 0, listHeight())
        else
            listHeight()
        end
    end

    local function setSelection(spec)
        local wanted = {}
        if type(spec) == "table" then
            if #spec > 0 then
                for index, value in ipairs(spec) do
                    if type(value) == "boolean" then
                        if value and options[index] then
                            wanted[options[index].Name] = true
                        end
                    else
                        wanted[tostring(value)] = true
                    end
                end
            else
                for name, enabled in pairs(spec) do
                    if enabled == true then
                        wanted[tostring(name)] = true
                    end
                end
            end
        elseif spec ~= nil then
            wanted[tostring(spec)] = true
        end

        local singleTaken = false
        for _, option in ipairs(options) do
            local enabled = wanted[option.Name] == true
            if not multi then
                enabled = enabled and not singleTaken
                if enabled then
                    singleTaken = true
                end
            end
            option.Selected = enabled
            if multi then
                multiMap[option.Name] = enabled
            elseif enabled then
                selectedName = option.Name
            end
            styleOption(option, true)
        end

        if not multi and not singleTaken then
            selectedName = nil
        end

        scheduleCommit()
    end

    object.ADD_DROPDOWN_OPTION = addOption
    object.REMOVE_DROPDOWN_OPTION = removeOption
    object.CLEAR_DROPDOWN = clearOptions
    object.SET_ENABLED_OPTIONS = setSelection

    header.Activated:Connect(function()
        setOpen(not opened)
    end)

    filterInput:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(filterInput.Text)
        for _, option in ipairs(options) do
            if option.Instance then
                option.Instance.Visible = query == "" or string.find(string.lower(option.Name), query, 1, true) ~= nil
            end
        end
    end)

    onTheme(pill, function()
        pillStroke.Color = opened and Lib.CurrentTheme.Primary or Lib.CurrentTheme.Stroke
        chevron.ImageColor3 = opened and Lib.CurrentTheme.Primary or Lib.CurrentTheme.TextDim
    end)

    if initialOptions then
        for _, value in ipairs(initialOptions) do
            addOption(value)
        end
    end

    if type(default) == "table" then
        for index = 1, (multi and #default or 1) do
            local value = default[index]
            local option = lookup(value, index)
            if option then
                markSelected(option)
            elseif multi and type(value) == "string" then
                pending[value] = true
            end
        end
    elseif type(default) == "string" then
        local option = lookup(default)
        if option then
            markSelected(option)
        end
    end

    for _, option in ipairs(options) do
        styleOption(option, false)
    end

    initializing = false
    refreshDisplay()
    object.Value = multi and selectedList() or selectedName
    task.defer(fireCallbacks, callbacks, multi and multiMap or (selectedName or ""))

    return object
end

function DropdownClass:SetEnabled(spec)
    assert(type(spec) == "table", "\"Dropdown.SetEnabled[param 1]\". 'table' expected, got " .. typeof(spec))
    self.SET_ENABLED_OPTIONS(spec)
end

function DropdownClass:SetValue(spec)
    self.SET_ENABLED_OPTIONS(spec)
end

DropdownClass.Set = DropdownClass.SetValue

function DropdownClass:Clear()
    self.CLEAR_DROPDOWN()
end

function DropdownClass:NewOptions(...)
    self:Clear()
    self:Add(...)
end

function DropdownClass:GetOptionsCount()
    return #self.DROPDOWN_OPTIONS
end

function DropdownClass:Remove(...)
    local names = { ... }
    assert(#names > 0, "'Dropdown.Remove' requires one or more options.")

    for _, name in ipairs(names) do
        self.REMOVE_DROPDOWN_OPTION(name)
    end
end

function DropdownClass:Add(...)
    local values = { ... }
    assert(#values > 0, "'Dropdown.Add' requires one or more options.")

    for _, value in ipairs(values) do
        self.ADD_DROPDOWN_OPTION(value)
    end
end
local DialogClass = {}
DialogClass.__index = DialogClass

local function layoutDialogOptions(dialog)
    local count = #dialog._buttons
    for _, button in ipairs(dialog._buttons) do
        button.Size = UDim2.new(1 / count, -(10 * (count - 1) / count), 1, 0)
    end
end

function DialogClass:NewOption(config)
    local name = config[1] or config.Name or config.Title
    local callbacks = normalizeCallbacks(config[2] or config.Callback)
    assert(type(name) == "string", "\"Dialog.NewOption.Name\". 'string' expected, got " .. typeof(name))

    table.insert(callbacks, function()
        self:Close()
    end)

    local style = config.Style
    if style == nil and #self._buttons == 0 then
        style = "Primary"
    end

    local button = makeButton({
        Name = "Option",
        Text = name,
        TextSize = 17,
        Font = FONT.Bold,
        BackgroundTransparency = 0,
        LayoutOrder = #self._buttons + 1,
        Parent = self._row,
    })
    corner(button, 12)

    if style == "Primary" then
        register(button, "BackgroundColor3", "Primary")
        register(button, "TextColor3", "OnPrimary")
    elseif style == "Danger" then
        register(button, "BackgroundColor3", "Danger")
        register(button, "TextColor3", "Text")
    else
        register(button, "BackgroundColor3", "CardHover")
        register(button, "TextColor3", "Text")
    end

    button.MouseEnter:Connect(function()
        tween(button, { BackgroundTransparency = 0.15 }, 0.12)
    end)
    button.MouseLeave:Connect(function()
        tween(button, { BackgroundTransparency = 0 }, 0.12)
    end)
    button.Activated:Connect(function()
        fireCallbacks(callbacks)
    end)

    table.insert(self._buttons, button)
    layoutDialogOptions(self)
end

function DialogClass:Close(instant)
    if self.Closed or self.Closing or State.Dialog ~= self then
        return nil
    end

    self.Closing = true

    local function finish()
        self.Closed = true
        self.Closing = false
        if State.Dialog == self then
            State.Dialog = nil
        end
        if self._layer.Parent then
            self._layer:Destroy()
        end
    end

    if instant then
        finish()
        return nil
    end

    tween(self._layer, { BackgroundTransparency = 1 }, 0.15)
    tween(self._cardScale, { Scale = 0.92 }, 0.15)
    task.delay(0.16, finish)
    return nil
end

function Window:Dialog(config)
    if type(config) ~= "table" then
        error("\"Window.Dialog[Configs]\". 'table' expected, got " .. typeof(config), 2)
    end

    if self.Minimized then
        while not self:MinimizeButton() do
            task.wait()
        end
    end

    if State.Dialog then
        State.Dialog:Close(true)
    end

    local title = config.Title or config.Name
    local content = config.Content or config.Description
    local options = config.Options

    assert(type(title) == "string", "\"Window.Dialog.Title\". 'string' expected, got " .. typeof(title))
    assert(type(content) == "string", "\"Window.Dialog.Content\". 'string' expected, got " .. typeof(content))
    assert(type(options) == "table", "\"Window.Dialog.Options\". 'table' expected, got " .. typeof(options))
    assert(#options > 0, "\"Window.Dialog.Options\". requires one or more options.")

    local layer = new("Frame", {
        Name = "Dialog",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Active = true,
        ZIndex = 20,
        Parent = State.Main,
    })
    register(layer, "BackgroundColor3", "Scrim")
    tween(layer, { BackgroundTransparency = 0.4 }, 0.2)

    local width = math.min(380, State.Main.Size.X.Offset - 40)
    local card = new("Frame", {
        Name = "Card",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(width, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = layer,
    })
    register(card, "BackgroundColor3", "Card")
    corner(card, 16)
    stroke(card, "Primary", 1.5, 0.4)
    pad(card, 22, 22, 20, 20)
    vlist(card, 12)

    local cardScale = new("UIScale", { Scale = 0.9, Parent = card })
    tween(cardScale, { Scale = 1 }, 0.25, Enum.EasingStyle.Back)

    local titleLabel = makeLabel({
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = title,
        TextSize = 21,
        Font = FONT.ExtraBold,
        TextWrapped = true,
        LayoutOrder = 1,
        Parent = card,
    }, "Text")

    local contentLabel = makeLabel({
        Name = "Description",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = content,
        TextSize = 16,
        Font = FONT.Regular,
        TextWrapped = true,
        RichText = true,
        LayoutOrder = 2,
        Parent = card,
    }, "TextDim")

    local row = new("Frame", {
        Name = "Options",
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundTransparency = 1,
        LayoutOrder = 3,
        Parent = card,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = row,
    })

    local dialog = setmetatable({
        TITLE_LABEL = titleLabel,
        DESCRIPTION_LABEL = contentLabel,
        Content = content,
        Title = title,
        Closed = false,
        Closing = false,
        Kind = "Dialog",
        _layer = layer,
        _card = card,
        _cardScale = cardScale,
        _row = row,
        _buttons = {},
    }, DialogClass)

    State.Dialog = dialog

    for _, optionConfig in ipairs(options) do
        dialog:NewOption(optionConfig)
    end

    return dialog
end

local function getNotifyHolder()
    if State.NotifyHolder and State.NotifyHolder.Parent then
        return State.NotifyHolder
    end

    local holder = new("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 66),
        Size = UDim2.new(0, 330, 1, -90),
        BackgroundTransparency = 1,
        Parent = State.Gui,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 10),
        Parent = holder,
    })
    newScale(holder)

    State.NotifyHolder = holder
    return holder
end

function Window:Notify(config)
    if type(config) ~= "table" then
        config = {}
    end

    local title = config[1] or config.Name or config.Title
    local content = config[2] or config.Content
    local icon = config[3] or config.Icon or config.Image
    local duration = config[4] or config.Duration or config.Countdown or config.Time

    if self.NOTIFICATION_GROUP then
        if duration == nil then
            duration = self.Duration
        end
        if content == nil then
            content = self.Content
        end
        if title == nil then
            title = self.Title
        end
        if icon == nil then
            icon = self.Icon
        end
    end

    assert(type(title) == "string", "\"Window.Notify.Title\". 'string' expected, got " .. typeof(title))
    assert(type(content) == "string", "\"Window.Notify.Content\". 'string' expected, got " .. typeof(content))
    assert(icon == nil or type(icon) == "string", "\"Window.Notify.Icon\". 'nil' or 'string' expected, got " .. typeof(icon))

    if duration ~= nil and type(duration) ~= "number" then
        error("\"Window.Notify.Time\". 'number', or 'nil' expected, got " .. typeof(duration), 2)
    elseif duration == nil then
        duration = 5
    end

    local resolvedIcon = Lib:GetIconByName(icon or State.NotifyIcon)
    local hasIcon = type(resolvedIcon) == "string" and isAssetId(resolvedIcon)

    local holder = getNotifyHolder()

    local wrapper = new("Frame", {
        Name = "Notification",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = holder,
    })

    local card = makeButton({
        Name = "Card",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(1.3, 0, 0, 0),
        BackgroundTransparency = 0,
        Parent = wrapper,
    })
    register(card, "BackgroundColor3", "Card")
    corner(card, 14)
    stroke(card, "Primary", 1.5, 0.35)

    local accent = new("Frame", {
        Name = "Accent",
        Position = UDim2.fromOffset(0, 12),
        Size = UDim2.new(0, 4, 1, -24),
        Parent = card,
    })
    register(accent, "BackgroundColor3", "Primary")
    corner(accent, 2)

    if hasIcon then
        makeIcon({
            Name = "Icon",
            Position = UDim2.fromOffset(18, 14),
            Size = UDim2.fromOffset(28, 28),
            Image = resolvedIcon,
            Parent = card,
        })
    end

    local leftOffset = hasIcon and 56 or 20
    local body = new("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(leftOffset, 0),
        Size = UDim2.new(1, -(leftOffset + 14), 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = card,
    })
    pad(body, 0, 0, 13, 22)
    vlist(body, 3)

    makeLabel({
        Name = "Title",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = title,
        TextSize = 18,
        Font = FONT.Bold,
        TextWrapped = true,
        LayoutOrder = 1,
        Parent = body,
    }, "Text")

    makeLabel({
        Name = "Content",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = content,
        TextSize = 15,
        Font = FONT.Regular,
        TextWrapped = true,
        RichText = true,
        LayoutOrder = 2,
        Parent = body,
    }, "TextDim")

    local rail = new("Frame", {
        Name = "Timer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 16, 1, -9),
        Size = UDim2.new(1, -32, 0, 3),
        Parent = card,
    })
    register(rail, "BackgroundColor3", "Track")
    corner(rail, 2)

    local fill = new("Frame", {
        Name = "Fill",
        Size = UDim2.fromScale(1, 1),
        Parent = rail,
    })
    register(fill, "BackgroundColor3", "Primary")
    corner(fill, 2)

    local notification = { Closed = false, Kind = "Notification" }

    function notification:Close()
        if self.Closed then
            return
        end
        self.Closed = true

        tween(card, { Position = UDim2.new(1.3, 0, 0, 0) }, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
        task.delay(0.36, function()
            if wrapper.Parent then
                wrapper:Destroy()
            end
        end)
    end

    notification.Destroy = notification.Close

    card.Activated:Connect(function()
        notification:Close()
    end)

    tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.4, Enum.EasingStyle.Back)
    tween(fill, { Size = UDim2.fromScale(0, 1) }, duration, Enum.EasingStyle.Linear)
    task.delay(duration, function()
        notification:Close()
    end)

    return notification
end

Window.Notificafion = Window.Notify

function Window:NewNotifyGroup(config)
    local title = config[1] or config.Name or config.Title
    local content = config[2] or config.Content
    local icon = config[3] or config.Icon or config.Image
    local duration = config[4] or config.Duration or config.Countdown or config.Time

    if title ~= nil and type(title) ~= "string" then
        error("\"Window.NewNotifyGroup.Title\". 'string', or 'nil' expected, got " .. typeof(title), 2)
    end
    if content ~= nil and type(content) ~= "string" then
        error("\"Window.NewNotifyGroup.Content\". 'string', or 'nil' expected, got " .. typeof(content), 2)
    end
    if icon ~= nil and type(icon) ~= "string" then
        error("\"Window.NewNotifyGroup.Icon\". 'string', or 'nil' expected, got " .. typeof(icon), 2)
    end
    if duration ~= nil and type(duration) ~= "number" then
        error("\"Window.NewNotifyGroup.Time\". 'number', or 'nil' expected, got " .. typeof(duration), 2)
    end

    return {
        NOTIFICATION_GROUP = true,
        Notify = Window.Notify,
        Duration = duration,
        Content = content,
        Title = title,
        Icon = icon,
    }
end

Window.NewNotificationGroup = Window.NewNotifyGroup

local Minimizer = {}
Minimizer.__index = Minimizer

local function isKeyCode(value)
    return typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode
end

function Window:NewMinimizer(config)
    local keyCode = type(config) == "table" and (config[1] or config.KeyCode) or config

    if not isKeyCode(keyCode) then
        error("\"Window.NewMinimizer.KeyCode\". 'KeyCode' expected, got " .. typeof(keyCode), 2)
    end

    local minimizer = setmetatable({ KeyCode = keyCode }, Minimizer)

    connect(UserInputService.InputBegan, function(input)
        if input.KeyCode == minimizer.KeyCode and UserInputService:GetFocusedTextBox() == nil then
            State.WindowObject:Minimize()
        end
    end)

    return minimizer
end

function Minimizer:SetKeyCode(keyCode)
    assert(isKeyCode(keyCode), "\"Minimizer.SetKeyCode[param 1]\". 'KeyCode' expected, got " .. typeof(keyCode))
    self.KeyCode = keyCode
end

function Minimizer:CreateMobileMinimizer(props)
    props = props or {}

    local viewport = getViewport()
    local button = Instance.new("ImageButton")
    button.Name = "MobileMinimizer"
    button.AutoButtonColor = false
    button.AnchorPoint = Vector2.new(0.5, 0.5)
    button.Position = UDim2.fromOffset(viewport.X * 0.12, viewport.Y * 0.3)
    button.Size = UDim2.fromOffset(60, 60)
    button.BackgroundTransparency = 0.12
    button.BorderSizePixel = 0
    button.Image = ICON.Minimizer
    button.ScaleType = Enum.ScaleType.Fit
    button.ZIndex = 5
    button.Parent = State.Gui
    register(button, "BackgroundColor3", "Primary")
    register(button, "ImageColor3", "OnPrimary")

    local buttonCorner = corner(button, 30)
    pad(button, 14, 14, 14, 14)
    local buttonStroke = new("UIStroke", {
        Thickness = 2.5,
        Transparency = 0.1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = button,
    })
    register(buttonStroke, "Color", "Text")

    for key, value in pairs(props) do
        if key == "Corner" then
            buttonCorner.CornerRadius = value
        elseif key == "Stroke" and type(value) == "table" then
            for strokeKey, strokeValue in pairs(value) do
                local ok, strokeError = pcall(function()
                    buttonStroke[strokeKey] = strokeValue
                end)
                if not ok then
                    warnf("MobileMinimizer stroke property '" .. tostring(strokeKey) .. "' failed: " .. tostring(strokeError))
                end
            end
        else
            local ok, propertyError = pcall(function()
                button[key] = value
            end)
            if not ok then
                warnf("MobileMinimizer property '" .. tostring(key) .. "' failed: " .. tostring(propertyError))
            end
        end
    end

    newScale(button)
    State.MobileButton = button

    button.InputBegan:Connect(function(input)
        if not isPress(input) then
            return
        end

        local startX, startY = button.Position.X.Offset, button.Position.Y.Offset
        local moved = false

        tween(button, { BackgroundTransparency = 0.3 }, 0.1)

        startDrag(input, function(position, origin)
            local dx, dy = position.X - origin.X, position.Y - origin.Y
            if not moved and (dx * dx + dy * dy) > 100 then
                moved = true
            end
            if moved then
                button.Position = UDim2.fromOffset(startX + dx, startY + dy)
            end
        end, function()
            tween(button, { BackgroundTransparency = 0.12 }, 0.15)

            local screen = getViewport()
            button.Position = UDim2.fromOffset(
                math.clamp(button.Position.X.Offset, 30, screen.X - 30),
                math.clamp(button.Position.Y.Offset, 30, screen.Y - 30)
            )

            if not moved then
                State.WindowObject:Minimize()
            end
        end)
    end)

    return button
end

function Tab:AddDiscordInvite(config)
    local title, description = parseConfig("DiscordInvite", config)
    local icon = config.Icon or config.Image or config.Logo
    local banner = config.Banner or config.BannerColor
    local online = config.Online or config.MembersOnline
    local members = config.Members or config.TotalMembers
    local invite = config.Invite or config.Link

    assert(type(invite) == "string", "\"Tab.AddDiscordInvite.Invite\". 'string' expected, got " .. typeof(invite))
    if banner ~= nil and typeof(banner) ~= "Color3" and type(banner) ~= "string" then
        error("\"Tab.AddDiscordInvite.Banner\". 'nil', 'Color3', or 'string' expected, got " .. typeof(banner), 2)
    end
    if online ~= nil and type(online) ~= "number" then
        error("\"Tab.AddDiscordInvite.Online\". 'number' expected, got " .. typeof(online), 2)
    end
    if members ~= nil and type(members) ~= "number" then
        error("\"Tab.AddDiscordInvite.Members\". 'nil', or 'number' expected, got " .. typeof(members), 2)
    end

    local card = new("Frame", {
        Name = "Option",
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Parent = self._container,
    })
    register(card, "BackgroundColor3", "Card")
    corner(card, 14)
    stroke(card, "Stroke", 1, 0.2)
    vlist(card, 0)

    local bannerHolder = new("Frame", {
        Name = "BannerHolder",
        Size = UDim2.new(1, 0, 0, 72),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Parent = card,
    })

    local bannerFrame = new("Frame", {
        Name = "Banner",
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(1, -20, 0, 58),
        Parent = bannerHolder,
    })
    corner(bannerFrame, 10)

    if typeof(banner) == "Color3" then
        bannerFrame.BackgroundColor3 = banner
    else
        register(bannerFrame, "BackgroundColor3", "Primary")
        bannerFrame.BackgroundTransparency = 0.45
        if isAssetId(banner) then
            local image = makeIcon({
                Size = UDim2.fromScale(1, 1),
                Image = banner,
                ScaleType = Enum.ScaleType.Crop,
                Parent = bannerFrame,
            })
            corner(image, 10)
        end
    end

    local row = new("Frame", {
        Name = "Info",
        Size = UDim2.new(1, 0, 0, 80),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = card,
    })

    local iconHolder = new("Frame", {
        Name = "IconHolder",
        Position = UDim2.fromOffset(16, 8),
        Size = UDim2.fromOffset(56, 56),
        Parent = row,
    })
    register(iconHolder, "BackgroundColor3", "Field")
    corner(iconHolder, 28)
    stroke(iconHolder, "Primary", 2, 0.2)

    if isAssetId(icon) then
        local image = makeIcon({
            Size = UDim2.fromScale(1, 1),
            Image = icon,
            Parent = iconHolder,
        })
        corner(image, 28)
    else
        makeLabel({
            Size = UDim2.fromScale(1, 1),
            Text = string.upper(string.sub(title, 1, 1)),
            TextSize = 24,
            Font = FONT.ExtraBold,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = iconHolder,
        }, "Primary")
    end

    local titleLabel = makeLabel({
        Name = "Title",
        Position = UDim2.fromOffset(84, 8),
        Size = UDim2.new(1, -84 - 130, 0, 24),
        Text = title,
        TextSize = 19,
        Font = FONT.Bold,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    }, "Text")

    local stats = {}
    if online then
        table.insert(stats, tostring(online) .. " Online")
    end
    if members then
        table.insert(stats, tostring(members) .. " Members")
    end
    local statsText = #stats > 0 and table.concat(stats, "   |   ") or description

    local statsLabel = makeLabel({
        Name = "Description",
        Position = UDim2.fromOffset(84, 36),
        Size = UDim2.new(1, -84 - 130, 0, 20),
        Text = statsText,
        TextSize = 15,
        Font = FONT.Regular,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Parent = row,
    }, "TextDim")

    local join = makeButton({
        Name = "Join",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(110, 44),
        Text = "Join",
        TextSize = 18,
        Font = FONT.Bold,
        BackgroundTransparency = 0,
        Parent = row,
    })
    register(join, "BackgroundColor3", "Primary")
    register(join, "TextColor3", "OnPrimary")
    corner(join, 12)

    join.MouseEnter:Connect(function()
        tween(join, { BackgroundTransparency = 0.15 }, 0.12)
    end)
    join.MouseLeave:Connect(function()
        tween(join, { BackgroundTransparency = 0 }, 0.12)
    end)

    join.Activated:Connect(function()
        local copy = setclipboard or toclipboard
        local copied = false
        if copy then
            local ok, copyError = pcall(copy, invite)
            copied = ok
            if not ok then
                warnf("could not copy the invite: " .. tostring(copyError))
            end
        end

        local send = request or http_request or (syn and syn.request)
        local code = string.match(invite, "([%w%-_]+)/?$")
        if send and code then
            local ok, sendError = pcall(function()
                send({
                    Url = "http://127.0.0.1:6463/rpc?v=1",
                    Method = "POST",
                    Headers = {
                        ["Content-Type"] = "application/json",
                        Origin = "https://discord.com",
                    },
                    Body = HttpService:JSONEncode({
                        cmd = "INVITE_BROWSER",
                        args = { code = code },
                        nonce = HttpService:GenerateGUID(false),
                    }),
                })
            end)
            if not ok then
                warnf("Discord RPC join failed: " .. tostring(sendError))
            end
        end

        local okNotify, notifyError = pcall(function()
            State.WindowObject:Notify({
                Title = title,
                Content = copied and "Invite link copied to clipboard." or invite,
                Duration = 4,
            })
        end)
        if not okNotify then
            warnf("could not show the invite notification: " .. tostring(notifyError))
        end
    end)

    local object = setmetatable({
        DESTROY_ELEMENT = card,
        VISIBLE_ELEMENT = card,
        TITLE_LABEL = titleLabel,
        DESCRIPTION_LABEL = statsLabel,
        Title = title,
        Description = description,
        Parent = self,
        Kind = "DiscordInvite",
    }, Element)
    object._entry = registerSearch(self, card, title, "discordinvite", description)

    return object
end

function Lib:GetIconByName(name)
    if name == nil then
        return nil
    end
    assert(type(name) == "string", "\"Library.GetIconByName\". 'string' expected, got " .. typeof(name))

    if isAssetId(name) or #name == 0 then
        return name
    end

    local icons = self.Icons
    if type(icons) ~= "table" then
        return nil
    end

    local key = string.lower(name)
    if icons[key] then
        return "rbxassetid://" .. tostring(icons[key])
    end

    for iconName, iconId in pairs(icons) do
        if string.find(iconName, key, 1, true) then
            return "rbxassetid://" .. tostring(iconId)
        end
    end

    return nil
end

function Lib:IsValidTheme(name)
    assert(type(name) == "string", "\"Library.IsValidTheme\". string extected, got " .. typeof(name))
    return self.Themes[name] ~= nil
end

function Lib:GetThemes()
    local names = {}
    for name in pairs(self.Themes) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

function Lib:GetTheme(name)
    assert(name == nil or type(name) == "string", "\"Library.GetTheme\". 'string' expected, got " .. typeof(name))

    if name == nil then
        return self.CurrentTheme
    end

    local theme = self.Themes[name]
    assert(theme ~= nil, "\"Library.GetTheme\". theme not found: " .. name)
    return theme
end

function Lib:SetTheme(name)
    assert(type(name) == "string", "\"Library.SetTheme\". string extected, got " .. typeof(name))
    local theme = self.Themes[name]
    assert(theme, "\"Library.SetTheme\". theme not found: " .. name)

    self.CurrentTheme = theme
    if self.WindowSettings then
        self.WindowSettings.SelectedTheme = theme.Name
    end

    applyTheme(theme)
end

function Lib:SetUIScale(multiplier)
    assert(type(multiplier) == "number", "\"Library.SetUIScale\". 'number' expected, got " .. typeof(multiplier))
    assert(
        multiplier >= MIN_SCALE and multiplier <= MAX_SCALE,
        "\"Library.SetUIScale\". Min Scale: " .. MIN_SCALE .. ", Max Scale: " .. MAX_SCALE
    )

    State.UserScale = multiplier
    applyScale()
end

function Lib:GetMaxScale()
    return MAX_SCALE
end

function Lib:GetMinScale()
    return MIN_SCALE
end

function Lib:GetCurrentTheme()
    if not self.LOADED_UI_LIBRARY then
        return error("failed to get current theme: UI is not loaded", 2)
    end
    return self.CurrentTheme
end

function Lib:Destroy()
    if not self.LOADED_UI_LIBRARY then
        return
    end
    self.LOADED_UI_LIBRARY = false

    for _, connection in ipairs(self.Connections) do
        connection:Disconnect()
    end
    table.clear(self.Connections)

    local gui = State.Gui
    local ownsGui = gui and gui.Parent and gui:GetAttribute("UID") == self.SCREENGUI_UID

    if State.Main and State.Main.Parent then
        local ok, destroyError = pcall(State.Main.Destroy, State.Main)
        if not ok then
            warnf("could not destroy the window: " .. tostring(destroyError))
        end
    end

    if ownsGui then
        local ok, destroyError = pcall(gui.Destroy, gui)
        if not ok then
            warnf("could not destroy the ScreenGui: " .. tostring(destroyError))
        end
    end

    table.clear(State.Tabs)
    table.clear(State.SearchIndex)
    table.clear(State.Scales)
    table.clear(Registry)
    table.clear(Listeners)

    State.Selected = nil
    State.Dialog = nil
    State.Main = nil
    State.MainScale = nil
    State.NotifyHolder = nil
    State.MobileButton = nil
    State.Gui = nil
    ActiveDrag = nil
end

Lib.Window = Window
Lib.Tab = Tab

return Lib
