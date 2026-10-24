local pcall, type, tostring, tonumber, unpack = pcall, type, tostring, tonumber, unpack or table.unpack
local rawget, rawset, setmetatable = rawget, rawset, setmetatable
local string, table, math, task, coroutine, debug, os = string, table, math, task, coroutine, debug, os
local game, Instance, Vector3, CFrame, UDim2, Color3 = game, Instance, Vector3, CFrame, UDim2, Color3
local getgenv = getgenv or function() return _G end
local cloneref = cloneref or function(o) return o end
local clonefunction = clonefunction or function(f) return f end
local newcclosure = newcclosure or function(f) return f end
local setreadonly = setreadonly or (make_writeable and function(t, val) if val then make_readonly(t) else make_writeable(t) end end) or function() end
local _DIO_RawHttpGet = game.HttpGet
pcall(function()
    if rawget then
        local f = rawget(game, "HttpGet")
        if type(f) == "function" then _DIO_RawHttpGet = f end
    end
end)
local _DIO_RawHttpPost = game.HttpPost
pcall(function()
    if rawget then
        local f = rawget(game, "HttpPost")
        if type(f) == "function" then _DIO_RawHttpPost = f end
    end
end)
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local CoreGui           = game:GetService("CoreGui")
local plr               = Players.LocalPlayer
local PASTEFY_PRIMARY_URL  = "https://pastefy.app/uKMDJHtO/raw"
local PASTEFY_FALLBACK_URL = "https://pastefy.app/lt56aSF4/raw"
local _DIO_KeyConfig = {
    Key        = nil,
    Linkgetkey = "https://link4sub.com/notes/eRcc",
    Loaded     = false,
}
local SAVE_FOLDER = "DIOHub_V3"
local KEY_FILE = SAVE_FOLDER .. "/DIO-SCRIPT-KeyCache.json"

local _DIO_KeyDiag   = ""
local _DIO_ApiOnline = false
local _DIO_ApiKeys   = {}
local _DIO_ApiLink   = ""
local _DIO_ApiRaw    = ""

local _DIO_OfflineKeys = {

}

local function _DIO_CleanJSON(str)
    if type(str) ~= "string" then return "" end
    str = str:gsub("\239\187\191", "")
    str = str:gsub("\226\128\139", "")
    str = str:gsub("\226\128\140", "")
    str = str:gsub("\226\128\141", "")
    str = str:gsub("%-%-[^\r\n]*", "")
    str = str:gsub(",%s*}", "}")
    str = str:gsub(",%s*]", "]")
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    return str
end

local function _DIO_NormKey(s)
    if type(s) ~= "string" then return "" end
    local t = s
    t = t:gsub("\239\187\191", "")
    t = t:gsub("\226\128\139", "")
    t = t:gsub("\226\128\140", "")
    t = t:gsub("\226\128\141", "")
    t = t:gsub("\194\160", " ")
    t = t:gsub("[\r\n\t]", " ")
    t = t:gsub("^%s+", "")
    t = t:gsub("%s+$", "")
    t = t:gsub("%s+", " ")
    return t
end

local function _DIO_KeyEq(a, b)
    local x, y = _DIO_NormKey(a), _DIO_NormKey(b)
    if #x == 0 or #y == 0 then return false end
    return x:lower() == y:lower()
end

local function _DIO_Bust(url)
    if type(url) ~= "string" or #url == 0 then return url end
    local sep = url:find("?", 1, true) and "&" or "?"
    return url .. sep .. "t=" .. tostring(os.time()) .. "&r=" .. tostring(math.random(100000, 999999))
end

local function _DIO_HttpGet(url)
    local out = nil
    pcall(function()
        local raw = _DIO_RawHttpGet(game, url, true)
        if type(raw) == "string" and #raw > 0 then out = raw end
    end)
    if type(out) == "string" and #out > 0 then return out end
    pcall(function()
        local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
        if type(reqFn) == "function" then
            local res = reqFn({ Url = url, Method = "GET" })
            local body = nil
            if type(res) == "table" then body = res.Body or res.body end
            if type(body) == "string" and #body > 0 then out = body end
        end
    end)
    if type(out) == "string" and #out > 0 then return out end
    pcall(function()
        if type(game.HttpGetAsync) == "function" then
            local raw = game:HttpGetAsync(url)
            if type(raw) == "string" and #raw > 0 then out = raw end
        end
    end)
    if type(out) == "string" and #out > 0 then return out end
    return nil
end

local function _DIO_TryPastefy(url, tag)
    local raw = _DIO_HttpGet(_DIO_Bust(url))
    if type(raw) ~= "string" or #raw == 0 then
        _DIO_KeyDiag = tag .. ": HTTP that bai / khong tra text (404? mang? executor chan? Cloudflare?)"
        return nil
    end
    _DIO_ApiRaw = raw
    local okJ, dec = pcall(function() return HttpService:JSONDecode(_DIO_CleanJSON(raw)) end)
    if (not okJ) or type(dec) ~= "table" then
        _DIO_KeyDiag = tag .. ": JSON khong hop le -> " .. tostring(dec):sub(1, 60) .. " | raw: " .. tostring(raw):sub(1, 60)
        return nil
    end
    return dec
end

local function _DIO_KeyListFrom(data)
    local out = {}
    local function push(v)
        if type(v) == "string" then
            local t = _DIO_NormKey(v)
            if #t > 0 then table.insert(out, t) end
        elseif type(v) == "table" then
            for _, e in ipairs(v) do push(e) end
        end
    end
    if type(data) == "table" then
        push(data.Key); push(data.Keys); push(data.keys); push(data.key); push(data.key_list)
    end
    return out
end

local function _DIO_ResolvePendingFromPastefy()
    local data = _DIO_TryPastefy(PASTEFY_PRIMARY_URL, "primary")
    if type(data) ~= "table" then
        data = _DIO_TryPastefy(PASTEFY_FALLBACK_URL, "fallback")
    end
    if type(data) ~= "table" then
        _DIO_ApiOnline = false
        warn("[DIO KEY] Khong doc duoc du lieu Api (ca link chinh va link du phong). " .. _DIO_KeyDiag)
        return nil
    end
    _DIO_ApiOnline = true
    _DIO_ApiKeys   = _DIO_KeyListFrom(data)
    if data.Linkgetkey and #tostring(data.Linkgetkey) > 12 then
        _DIO_ApiLink = tostring(data.Linkgetkey)
        _DIO_KeyConfig.Linkgetkey = _DIO_ApiLink
    end
    _DIO_KeyConfig.Loaded = true
    return data
end

local function _DIO_ResolveLinkgetkey(force)
    if (not force) and _DIO_KeyConfig.Loaded then
        return _DIO_KeyConfig.Linkgetkey or ""
    end
    local data = _DIO_ResolvePendingFromPastefy()
    if data then
        local link = tostring(data.Linkgetkey or "")
        if #link > 12 then
            _DIO_KeyConfig.Linkgetkey = link
        end
        _DIO_KeyConfig.Loaded = true
    end
    return _DIO_KeyConfig.Linkgetkey or ""
end

local _DIO_EnvGet = getgenv
local function _DIO_GetEnvString(name)
    local v = nil
    pcall(function()
        if _DIO_EnvGet then v = _DIO_EnvGet()[name] end
        if v == nil or v == "" then v = _G[name] end
    end)
    if type(v) == "string" then
        return _DIO_NormKey(v)
    end
    return ""
end
local _DIO_PendingKey = ""
local _DIO_SessionKey = nil
local function _DIO_SetKey(k)
    _DIO_SessionKey = _DIO_NormKey(tostring(k or ""))
    local ok = pcall(function()
        getgenv().Key = _DIO_SessionKey
    end)
    if not ok then _G.Key = _DIO_SessionKey end
end
local function _DIO_KeyLabel()
    if type(_DIO_SessionKey) == "string" and #_DIO_SessionKey > 0 then
        return _DIO_SessionKey
    end
    return "(chua co - hay bam Check Key)"
end

local function _DIO_ReadKeyCache()
    if not (isfile and readfile) then return nil end
    local ok, data = pcall(function()
        if not isfile(KEY_FILE) then return nil end
        return HttpService:JSONDecode(readfile(KEY_FILE))
    end)
    if ok and type(data) == "table" then return data end
    return nil
end
local function _DIO_ClearKeyCache(reason)
    pcall(function()
        if delfile and isfile and isfile(KEY_FILE) then delfile(KEY_FILE) end
    end)
    _DIO_PendingKey = ""
    if reason then warn("[DIO KEY] Xoa cache key cu: " .. tostring(reason)) end
end

local function _DIO_InvalidateStaleCache()
    if not _DIO_ApiOnline then return end
    local function inApi(k)
        if type(k) ~= "string" or #k == 0 then return false end
        for _, official in ipairs(_DIO_ApiKeys) do
            if _DIO_KeyEq(k, official) then return true end
        end
        return false
    end
    local data = _DIO_ReadKeyCache()
    if data and type(data.key) == "string" and not inApi(data.key) then
        _DIO_ClearKeyCache("key trong cache khong con nam trong danh sach Api")
    end
    pcall(function()
        local gk = getgenv().Key
        if type(gk) == "string" and #gk > 0 and not inApi(gk) then
            getgenv().Key = ""
            _DIO_SessionKey = nil
            warn("[DIO KEY] getgenv().Key cu (" .. tostring(gk):sub(1, 40) .. ") khong con hop le -> da xoa.")
        end
    end)
end

local function _SEC_VerifyKey(inputKey)
    if type(inputKey) ~= "string" then return false end
    local key = _DIO_NormKey(inputKey)
    if #key == 0 then return false end
    if type(_DIO_SessionKey) == "string" and #_DIO_SessionKey > 0 and _DIO_KeyEq(key, _DIO_SessionKey) then
        return true
    end
    local data = _DIO_ResolvePendingFromPastefy()
    if type(data) == "table" then

        local list = _DIO_KeyListFrom(data)
        if #list == 0 then
            warn("[DIO KEY] Pastefy tra ve JSON hop le nhung thieu truong 'Key' hop le.")
            return false
        end
        for _, official in ipairs(list) do
            if _DIO_KeyEq(key, official) then
                _DIO_SetKey(official)
                print("[DIO KEY] Key hop le (khop voi Api).")
                return true
            end
        end

        warn("[DIO KEY] Lan doc dau khong thay key nay -> doc lai Api (chong cache)...")
        local data2 = _DIO_ResolvePendingFromPastefy()
        if type(data2) == "table" then
            for _, official in ipairs(_DIO_KeyListFrom(data2)) do
                if _DIO_KeyEq(key, official) then
                    _DIO_SetKey(official)
                    print("[DIO KEY] Key hop le (khop voi Api sau khi doc lai).")
                    return true
                end
            end
        end

        _DIO_InvalidateStaleCache()
        warn("[DIO KEY] Key vua nhap KHONG nam trong danh sach key cua Api hien tai.")
        return false
    end

    if #_DIO_PendingKey > 0 and _DIO_KeyEq(key, _DIO_PendingKey) then
        _DIO_SetKey(_DIO_PendingKey)
        warn("[DIO KEY] OFFLINE: cho qua bang key cau hinh/cache cua may nay.")
        return true
    end

    for _, k in ipairs(_DIO_OfflineKeys) do
        if _DIO_KeyEq(key, k) then
            _DIO_SetKey(_DIO_NormKey(k))
            warn("[DIO KEY] OFFLINE: cho qua bang danh sach key du phong trong script.")
            return true
        end
    end
    warn("[DIO KEY] Offline va key khong khop cache. Chi tiet: " .. _DIO_KeyDiag)
    return false
end

_DIO_PendingKey = _DIO_GetEnvString("Key")
local function _DIO_AddCachedPendingKey()
    if #_DIO_PendingKey > 0 then return end
    if not (isfile and readfile) then return end
    pcall(function()
        if not isfile(KEY_FILE) then return end
        local data = HttpService:JSONDecode(readfile(KEY_FILE))
        if type(data) == "table" and type(data.key) == "string" then
            if data.time and (os.time() - tonumber(data.time) > 36000) then return end
            local k = _DIO_NormKey(data.key)
            if #k > 0 then
                _DIO_PendingKey = k
                local ok = pcall(function()
                    if getgenv().Key == nil or getgenv().Key == "" then getgenv().Key = k end
                end)
                if not ok and (_G.Key == nil or _G.Key == "") then _G.Key = k end
            end
        end
    end)
end
local function _DIO_AutoValidateConfiguredKey()
    if #_DIO_PendingKey == 0 then return false end
    warn("[DIO KEY] Dang doi chieu key cau hinh san voi server (mat 1-3 giay)...")
    if _SEC_VerifyKey(_DIO_PendingKey) then
        print("[DIO KEY] Key cau hinh san HOP LE -> tu dong vao hub, bo qua cua so nhap key.")
        return true
    end
    warn("[DIO KEY] Key cau hinh san KHONG khop voi key cua he thong -> se hien cua so nhap key. " .. _DIO_KeyDiag)
    return false
end

local function _DIO_KeyStatusText()
    local st = _DIO_ApiOnline and "ONLINE (doc duoc Api)" or "OFFLINE / LOI DOC API"
    local keys = (#_DIO_ApiKeys > 0) and table.concat(_DIO_ApiKeys, " | ") or "(chua doc duoc)"
    local cache = "(khong co)"
    local data = _DIO_ReadKeyCache()
    if data and data.key then
        local age = data.time and math.floor((os.time() - tonumber(data.time)) / 60) or -1
        cache = tostring(data.key) .. (age >= 0 and (" - " .. tostring(age) .. " phut truoc") or "")
    end
    local out = "Trang thai Api: " .. st .. "\n"
        .. "Key hop le tren Api: " .. keys .. "\n"
        .. "Key trong cache may nay: " .. cache .. "\n"
        .. "getgenv().Key: " .. tostring(getgenv().Key or "")
    if _DIO_KeyDiag ~= "" then out = out .. "\nGhi chu loi: " .. _DIO_KeyDiag end
    return out
end

pcall(function()
    local _cloneref = cloneref or function(o) return o end
    HttpService       = _cloneref(game:GetService("HttpService"))
    ReplicatedStorage = _cloneref(game:GetService("ReplicatedStorage"))
    Players           = _cloneref(game:GetService("Players"))
    CoreGui           = _cloneref(game:GetService("CoreGui"))
    RunService        = _cloneref(game:GetService("RunService"))
    plr               = Players.LocalPlayer
end)
if plr == nil then plr = Players.LocalPlayer end
pcall(function()
    if clonefunction and game.HttpGet then _DIO_RawHttpGet = clonefunction(game.HttpGet) end
    if clonefunction and game.HttpPost then _DIO_RawHttpPost = clonefunction(game.HttpPost) end
end)
local _SPY_TARGETS = {
    ["simplespy"] = true,
    ["simplespyv2"] = true,
    ["simplespyv3"] = true,
    ["hydrox"] = true,
    ["hydrox-hub"] = true,
    ["turtlespy"] = true,
    ["darkdex"] = true,
    ["dex"] = true,
    ["dex++"] = true,
    ["explorer"] = true,
    ["remotespy"] = true,
    ["spygui"] = true,
    ["httplogger"] = true,
    ["httpspy"] = true,
    ["spy"] = true,
    ["rbxspy"] = true,
    ["synapsespy"] = true,
}
local function _SEC_CheckAndNeutralizeSpy(child)
    if not child or type(child) ~= "userdata" then return end
    pcall(function()
        local name = tostring(child.Name):lower()
        for spyName, _ in pairs(_SPY_TARGETS) do
            if name:find(spyName, 1, true) then
                child:Destroy()
                warn("[DIO SECURITY] Anti-Spy Neutralized tool: " .. tostring(child.Name))
                return
            end
        end
    end)
end
pcall(function()
    local gethui = gethui or function() return CoreGui end
    local containers = {CoreGui, plr and plr:FindFirstChild("PlayerGui"), gethui()}
    for _, container in ipairs(containers) do
        if container then
            for _, child in ipairs(container:GetChildren()) do
                _SEC_CheckAndNeutralizeSpy(child)
            end
            container.ChildAdded:Connect(_SEC_CheckAndNeutralizeSpy)
        end
    end
end)
pcall(function()
    local dummyScript = Instance.new("LocalScript")
    dummyScript.Name = "DIO_Hub_Protected"
    script = dummyScript
end)
pcall(function()
    if table.freeze then
        table.freeze(_SPY_TARGETS)
    end
end)
getgenv().Team = getgenv().Team or "Pirates"
getgenv().SaveSettings = (getgenv().SaveSettings == nil) and true or getgenv().SaveSettings
getgenv().Key = getgenv().Key or ""
if getgenv().AutoExecutor == nil then getgenv().AutoExecutor = false end
if getgenv().HideUi == nil then getgenv().HideUi = false end
local function AutoSelectTeam()
    local ok, err = pcall(function()
        local __remotesF = ReplicatedStorage:WaitForChild("Remotes", 60)
        local comm = __remotesF and __remotesF:WaitForChild("CommF_", 60)
        if not comm then return end
        local team = tostring(getgenv().Team or "Pirates")
        if team ~= "Pirates" and team ~= "Marines" then team = "Pirates" end
        if plr.Team == nil or tostring(plr.Team) ~= team then
            comm:InvokeServer("SetTeam2", team)
        end
    end)
    if not ok then
        warn("[DIO] Auto Team failed: "..tostring(err))
    end
end
repeat task.wait() until game:IsLoaded()
pcall(function()
    local mainGui = plr:FindFirstChild("PlayerGui") and plr.PlayerGui:FindFirstChild("Main")
    local loading = mainGui and mainGui:FindFirstChild("Loading")
    if loading then
        local __loadCap = 0
        repeat task.wait() __loadCap += 1 until (not loading.Visible) or __loadCap >= 90
    end
end)
AutoSelectTeam()
do
    local __waitN = 0
    while __waitN < 20 do
        if plr and plr:FindFirstChild("Data") and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then break end
        task.wait(1)
        __waitN += 1
    end
end
local function ensureFolder()
    pcall(function()
        if makefolder and (not isfolder or not isfolder(SAVE_FOLDER)) then
            makefolder(SAVE_FOLDER)
        end
    end)
end
local function saveKeyCache()
    ensureFolder()
    pcall(function()
        if writefile then
            local data = {
                key = _DIO_KeyLabel(),
                time = os.time(),
                hwid = (gethwid and gethwid() or game:GetService("RbxAnalyticsService"):GetClientId() or "unknown")
            }
            writefile(KEY_FILE, HttpService:JSONEncode(data))
        end
    end)
end
local function isKeyCacheValid()
    if not (isfile and readfile) then return false end
    if not isfile(KEY_FILE) then return false end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(KEY_FILE))
    end)
    if not ok or type(data) ~= "table" then return false end
    if type(data.key) ~= "string" or #_DIO_NormKey(data.key) == 0 then return false end
    if not data.time then return false end
    if os.time() - tonumber(data.time) > 36000 then
        pcall(function() if delfile then delfile(KEY_FILE) end end)
        return false
    end
    local curHwid = nil
    pcall(function()
        curHwid = (gethwid and gethwid()) or game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if data.hwid and curHwid and tostring(data.hwid) ~= "unknown" and tostring(data.hwid) ~= tostring(curHwid) then
        pcall(function() if delfile then delfile(KEY_FILE) end end)
        return false
    end
    return true
end
local function isKeyValid()
    _DIO_AddCachedPendingKey()
    if _DIO_AutoValidateConfiguredKey() then
        saveKeyCache()
        return true
    end

    if _DIO_ApiOnline then
        _DIO_InvalidateStaleCache()
        warn("[DIO KEY] Api doc duoc nhung key cua may nay khong con hop le -> hien cua so nhap key.")
        return false
    end
    if isKeyCacheValid() then
        warn("[DIO KEY] OFFLINE (khong goi duoc Api) -> tam cho qua bang cache con han 10h.")
        return true
    end
    return false
end

local function _DIO_ResetKeyCache()
    _DIO_ClearKeyCache("nguoi dung bam Reset cache")
    pcall(function() getgenv().Key = "" end)
    pcall(function() _G.Key = "" end)
    _DIO_SessionKey = nil
    _DIO_PendingKey = ""
    _DIO_KeyConfig.Loaded = false
    _DIO_ApiOnline = false
    _DIO_ApiKeys = {}
end

local function StartDioHub()
local tick = tick
local __SVC_RS   = game:GetService("ReplicatedStorage")
local __SVC_PLR  = game:GetService("Players")
local __SVC_WS   = game:GetService("Workspace")
local __SVC_TP   = game:GetService("TeleportService")
local __SVC_HTTP = game:GetService("HttpService")
local __SVC_CS   = game:GetService("CollectionService")
local __SVC_RUN  = game:GetService("RunService")
local __SVC_TWN  = game:GetService("TweenService")
local __SVC_VU   = game:GetService("VirtualUser")
local __SVC_VIM  = game:GetService("VirtualInputManager")
local __SVC_STAT = game:GetService("Stats")
local __SVC_LIGHT= game:GetService("Lighting")
local RunService = __SVC_RUN
local Stats = __SVC_STAT
__DIO_BOOT = function() end
pcall(function()
    local fpsGui = Instance.new("ScreenGui", game.CoreGui)
    fpsGui.Name = "FPS_Display_80"
    local fpsLabel = Instance.new("TextLabel", fpsGui)
    fpsLabel.Position = UDim2.new(0, 10, 0, 10)
    fpsLabel.Size = UDim2.new(0, 200, 0, 15)
    fpsLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    fpsLabel.BackgroundTransparency = 0.4
    fpsLabel.TextColor3 = Color3.new(1, 1, 1)
    fpsLabel.Font = Enum.Font.GothamBold
    fpsLabel.TextSize = 14
    fpsLabel.Text = "FPS: ... | Ping: ... | TIME: 0h 00m 00s"
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    local bootLabel = Instance.new("TextLabel", fpsGui)
    bootLabel.Name = "DIO_BootStatus"
    bootLabel.Position = UDim2.new(0, 10, 0, 24)
    bootLabel.Size = UDim2.new(0, 260, 0, 12)
    bootLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bootLabel.BackgroundTransparency = 0.4
    bootLabel.TextColor3 = Color3.new(1, 1, 1)
    bootLabel.Font = Enum.Font.GothamBold
    bootLabel.TextSize = 14
    bootLabel.TextXAlignment = Enum.TextXAlignment.Left
    bootLabel.Text = "DIO BOOT: ..."
    __DIO_BOOT = function(s)
        pcall(function()
            local __msg = tostring(s)
            if string.find(__msg, "READY NOW", 1, true) or string.find(__msg, "100%", 1, true) then
                __DIO_BOOT = function() end
                if bootLabel then bootLabel:Destroy() end
                return
            end
            bootLabel.Text = "DIO BOOT: " .. __msg
        end)
    end
    __DIO_BOOT("Load Hub 21%")
    local lastTime = tick()
    local frames = 0
    local __joinSecs = 0
    RunService.RenderStepped:Connect(function()
        frames += 1
        if tick() - lastTime >= 1 then
            local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            __joinSecs += 1
            local __h = math.floor(__joinSecs / 3600)
            local __m = math.floor((__joinSecs % 3600) / 60)
            local __sec = __joinSecs % 60
            fpsLabel.Text = "FPS: " .. frames .. " | Ping: " .. ping
                .. " | TIME: " .. string.format("%dh %02dm %02ds", __h, __m, __sec)
            frames = 0
            lastTime = tick()
        end
    end)
end)
do
  ply = game.Players
  plr = ply.LocalPlayer
  if not plr.Character then plr.CharacterAdded:Wait() end
  Root = plr.Character:WaitForChild("HumanoidRootPart", 30)
  do
      local __hrpTries = 0
      while not Root and __hrpTries < 30 do
          task.wait(2)
          __hrpTries += 1
          if plr.Character then Root = plr.Character:FindFirstChild("HumanoidRootPart") end
      end
  end
  replicated = __SVC_RS
  local __data = plr:WaitForChild("Data", 30)
  local __lvl = __data and __data:FindFirstChild("Level")
  TeleportService = __SVC_TP
  TW = __SVC_TWN
  Lighting = __SVC_LIGHT
  Enemies = workspace:WaitForChild("Enemies", 30)
  vim1 = __SVC_VIM
  Stats = __SVC_STAT
  local __en = plr.Character:FindFirstChild("Energy")
  Energy = __en and __en.Value or 0
  BossList = {}
  MaterialList = {}
  NPCList = {}
  shouldTween = false
  SoulGuitar = false
  KenTest = true
  __DIO_TTDebug = false
  _G.HealthFarmMastery = _G.HealthFarmMastery or 30
Sec = 0.25
  Num_self = 25
end
__DIO_BootT0 = tick()
__DIO_BootN = 0
__DIO_ThreadPhase = setmetatable({}, {__mode = "k"})
local __DIO_BaseWait = task.wait
__DIO_WakeT   = 0
__DIO_WakeGap = 0.15
__DIO_Wake = function(force)
    local __n = tick()
    if force ~= true and (__n - (__DIO_WakeT or 0)) < (__DIO_WakeGap or 0.15) then return false end
    __DIO_WakeT = __n
    return true
end
__DIO_TweenActivateImmediate = function()
    local __nowA = tick()
    if __nowA - (__DIO_LastActT or 0) < 0.5 then return end
    __DIO_LastActT = __nowA
    __DIO_TweenBlockT = 0
    __DIO_TweenBlockDur = 0.5
    shouldTween = true
    if type(__DIO_Move) == "function" then pcall(__DIO_Move) end
    pcall(function() __DIO_Wake(true) end)
end
__DIO_wait = function(t)
    t = t or 0.03
    local __co = coroutine.running()
    local __ph = 0
    if __co then
        __ph = __DIO_ThreadPhase[__co]
        if __ph == nil then
            __ph = math.random() * math.min(t * 0.15, 0.15)
            __DIO_ThreadPhase[__co] = __ph
            if tick() - __DIO_BootT0 < 10 and __DIO_BootN < 200 then
                __DIO_BootN = __DIO_BootN + 1
                __DIO_BaseWait(math.min(__DIO_BootN * 0.08, 4))
            end
        end
    end
    local __total = t + __ph
    if __total < 0.12 then return __DIO_BaseWait(__total) end
    local __t0 = tick()
    local __w0 = __DIO_WakeT
    local __step = 0.05
    while true do
        local __left = __total - (tick() - __t0)
        if __left <= 0 then break end
        __DIO_BaseWait(__left > __step and __step or __left)
        if __DIO_WakeT ~= __w0 then break end
        if __step < 0.15 then __step = math.min(__step * 1.6, 0.15) end
    end
    local __el = tick() - __t0
    if not (__el > 0) then __el = 0.001 end
    return __el
end
spawn = function(f)
    if tick() - __DIO_BootT0 < 10 and __DIO_BootN < 200 then
        __DIO_BootN = __DIO_BootN + 1
        return task.delay(math.min(__DIO_BootN * 0.08, 4), f)
    end
    return task.spawn(f)
end
__DIO_SafeLoopN = 0
__DIO_SafeLoop = function(fn, tag)
    __DIO_SafeLoopN = (__DIO_SafeLoopN or 0) + 1
    local __idSL = __DIO_SafeLoopN
    return spawn(function()
        while true do
            local __okSL, __errSL = pcall(fn)
            if not __okSL then
                pcall(function()
                    warn(("[DIO] SafeLoop #%d(%s) error -> auto restart: %s"):format(__idSL, tostring(tag or "?"), tostring(__errSL)))
                end)
            end
            __DIO_wait(0.5)
        end
    end)
end
__DIO_FlagWant    = {}
__DIO_FlagSup     = {}
__DIO_OwnerAlive  = {}
__DIO_UIFlagOwner = {}
__DIO_UIFlagOn    = {}
__DIO_UIState     = {}
__DIO_UISetOn = function(name, key, on)
    if type(name) ~= "string" then return end
    if not __DIO_UIFlagOwner[name] then __DIO_UIFlagOwner[name] = {} end
    __DIO_UIFlagOwner[name][key] = true
    if not __DIO_UIFlagOn[name] then __DIO_UIFlagOn[name] = {} end
    __DIO_UIFlagOn[name][key] = (on == true)
    if type(__DIO_FeatMark2) == "function" then pcall(__DIO_FeatMark2, name, on) end
end
__DIO_FarmFlagNames = {
    "StartFarm", "SailBoat_Hydra", "WardenBoss", "AutoFactory", "HighestMirage", "HCM", "PGB", "Leviathan1", "UPGDrago",
    "Complete_Trials", "TpDrago_Prehis", "BuyDrago", "BuyMelee_BuyBlackLeg", "BuyMelee_BuyElectro", "BuyMelee_BuyFishmanKarate", "BuyMelee_BuyDragonClaw",
    "BuyMelee_BuySuperhuman", "BuyMelee_BuyDeathStep", "BuyMelee_BuySharkmanKarate", "BuyMelee_BuyElectricClaw",
    "BuyMelee_BuyDragonTalon", "BuyMelee_BuyGodhuman", "BuyMelee_BuySanguineArt", "AutoFireFlowers",
    "DT_Uzoth", "AutoBerry", "Prefully", "Prehis_Find", "Prehis_Skills", "Prehis_DB", "Prehis_DE", "FarmBlazeEM",
    "Dojoo", "CollectPresent", "AutoPhoenixF", "AutoFarmChest", "AutoHytHallow", "LongsWord",
    "BlackSpikey", "AutoHolyTorch", "TrainDrago", "AutoSaber", "FarmMastery_Dev", "CitizenQuest", "AutoEctoplasm", "KeysRen",
    "Auto_Rainbow_Haki", "obsFarm", "AutoBigmom", "Doughv2", "AuraBoss", "Raiding", "AutoRaid", "AutoMultiRaid", "AutoJoinDungeon", "AutoAttackDungeon", "AutoPickCardDungeon", "AutoBuyChipAttackLaw", "Auto_Cavender", "TpPly",
    "Bartilo_Quest", "Level", "FarmEliteHunt", "AutoZou", "AutoFarm_Bone", "AutoMaterial", "CraftVM", "FrozenTP",
    "ShotHL", "TPDoor", "AcientOne", "AutoFarmNear", "AutoRaidCastle", "DarkBladev3", "AutoFarmRaid", "Auto_Cake_Prince",
    "Addealer", "TPNpc", "TwinHook", "FindMirage", "FrozenDimension", "FarmChestM", "Shark", "TerrorShark",
    "Piranha", "MobCrew", "SeaBeast1", "FishBoat", "AutoPole", "AutoPoleV2", "Auto_SuperHuman", "AutoDeathStep",
    "Auto_SharkMan_Karate", "Auto_Electric_Claw", "AutoDragonTalon", "Auto_Def_DarkCoat", "Auto_God_Human", "Auto_Tushita", "AutoMatSoul", "AutoKenVTWO",
    "AutoSerpentBow", "AutoFMon", "Auto_Soul_Guitar", "TPGEAR", "AutoSaw", "AutoTridentW2", "AutoEvoRace", "AutoGetQuestBounty",
    "MarinesCoat", "TravelDres", "Defeating", "DummyMan", "Auto_Yama", "Auto_SwanGG", "SwanCoat", "AutoEcBoss",
    "Auto_Mink", "Auto_Human", "Auto_Skypiea", "Auto_Fish", "CDK_TS", "CDK_YM", "CDK", "AutoFarmGodChalice",
    "AutoFistDarkness", "AutoMiror", "Teleport", "AutoKilo", "AutoGetUsoap", "Praying", "TryLucky", "AutoColShad",
    "AutoUnHaki", "Auto_DonAcces", "AutoRipIngay", "DragoV3", "DragoV1", "SailBoats", "FarmGodChalice", "IceBossRen",
    "Lvthan", "beasthunter", "DangerLV", "Relic123", "tweenKitsune", "Collect_Ember", "AutofindKitIs", "Snaguine",
    "TwFruits", "tweenKitShrine", "Tp_LgS", "Tp_MasterA", "tweenShrine", "FarmMastery_G", "FarmMastery_S", "FarmBoss",
    "AutoFarmAllBoss", "AutoFishSlap", "TweenBoatOwner", "FarmTyrant", "FarmPhaBinh", "AutoSpawnCP", "AutoBerryH", "AutoChestBP",
    "FarmEliteHop", "AutoAttackDoughKing", "AutoSummonDoughKing", "AutoHopDoughKing", "StartEvent",
    "AutoMysticIsland", "AutoPlayerHunter", "SafeMode", "AutoKillMob", "AutoStartPrehistoric", "AutoFarmIsland", "AutoFarmCandy",
    "AutoTP_Gift", "AutoTPGift", "AutoTPAndCollect", "MasterAutoLevel", "MasterAutoCandy", "FarmEliteH", "Safemode", "Greybeard", "ResetPH", "NextIs", "senth", "senth2",
}
__DIO_TWEEN_LEASE  = 30
__DIO_MOVE_GRACE   = 12
__DIO_SOFT_DROP    = 1.5
__DIO_MoveT        = 0
__DIO_DropPendT    = 0
__DIO_FeatOnN      = 0
__DIO_FeatMark     = {}
__DIO_UIOn         = {}
__DIO_UIOnN        = 0
__DIO_Move = function()
    __DIO_MoveT    = tick()
    __DIO_DropPendT = 0
end
__DIO_MoveFresh = function()
    return (tick() - (__DIO_MoveT or 0)) <= (__DIO_MOVE_GRACE or 12)
end
__DIO_UISetState = function(key, on)
    if key == nil then return end
    key = tostring(key)
    local was = (__DIO_UIOn[key] == true)
    if on == true then
        if not was then
            __DIO_UIOn[key] = true
            __DIO_UIOnN = (__DIO_UIOnN or 0) + 1
        end
    elseif was then
        __DIO_UIOn[key] = nil
        __DIO_UIOnN = math.max(0, (__DIO_UIOnN or 1) - 1)
    end
end
__DIO_FeatMark2 = function(name, on)
    if type(name) ~= "string" then return end
    local isFeat = false
    pcall(function()
        isFeat = (type(__DIO_IsFarmFlag) == "function" and __DIO_IsFarmFlag(name))
            or (type(__DIO_SharedFlags) == "table" and __DIO_SharedFlags[name] == true)
    end)
    if not isFeat then return end
    if not __DIO_FeatMark then __DIO_FeatMark = {} end
    local was = (__DIO_FeatMark[name] == true)
    if on == true then
        if not was then
            __DIO_FeatMark[name] = true
            __DIO_FeatOnN = (__DIO_FeatOnN or 0) + 1
        end
    elseif was then
        __DIO_FeatMark[name] = nil
        __DIO_FeatOnN = math.max(0, (__DIO_FeatOnN or 1) - 1)
    end
end
__DIO_LastActT   = 0
__DIO_FlyBusyT    = 0
__DIO_GENV = nil
__DIO_Genv = function()
    if __DIO_GENV ~= nil then return __DIO_GENV end
    pcall(function()
        local g = getgenv()
        if type(g) == "table" and g ~= _G then __DIO_GENV = g end
    end)
    return __DIO_GENV
end
__DIO_FlagGet = function(name)
    local v = rawget(_G, name)
    if v == nil then
        local g = __DIO_Genv()
        if g then v = rawget(g, name) end
    end
    return v
end
__DIO_FlagSet = function(name, val)
    local __prev = rawget(_G, name)
    pcall(rawset, _G, name, val)
    local g = __DIO_Genv()
    if g and rawget(g, name) ~= nil then pcall(rawset, g, name, val) end
    if val == true and __prev ~= true and type(__DIO_Wake) == "function" then pcall(__DIO_Wake, true) end
end
__DIO_QuestGone = function()
    local __okQ, __gone = pcall(function()

        if type(__DIO_3nn_GetTrackedQuestText) == "function" then
            return (__DIO_3nn_GetTrackedQuestText() or "") == ""
        end
        local __pg = plr and plr:FindFirstChild("PlayerGui")
        local __main = __pg and __pg:FindFirstChild("Main")
        local __q = __main and __main:FindFirstChild("Quest")
        return __q == nil or __q.Visible == false
    end)
    return __okQ and __gone or false
end
__DIO_IslandCache = nil
__DIO_IslandCacheT = 0
__DIO_GetSelectedIslandModel = function()
    local name = _G.SelectIsland
    if type(name) ~= "string" or name == "" then return nil end
    if __DIO_IslandCache ~= nil and tick() - __DIO_IslandCacheT < 5 then return __DIO_IslandCache end
    local model = nil
    local map = __SVC_WS and __SVC_WS:FindFirstChild("Map")
    if map then
        model = map:FindFirstChild(name)
        if not model then
            local lname = name:lower()
            for _, v in ipairs(map:GetChildren()) do
                if v:IsA("Model") and v.Name:lower():find(lname, 1, true) then model = v break end
            end
        end
    end
    if not model then model = workspace:FindFirstChild(name) end
    __DIO_IslandCache = model
    __DIO_IslandCacheT = tick()
    return model
end
BerryArray = getgenv().BerryArray or nil
do
    local __okIRS, __resIRS = pcall(function()
        local __mod = __SVC_RS:FindFirstChild("Modules")
        local __ir = __mod and __mod:FindFirstChild("ItemReplicationService")
        return __ir and require(__ir)
    end)
    if __okIRS and type(__resIRS) == "table" then ItemReplicationService = __resIRS end
end
KEYS = KEYS or { QUANTITY = 999999 }
__DIO_FlagApply = function(name)
    local w, s = __DIO_FlagWant[name], __DIO_FlagSup[name]
    local anyW, anyS = false, false
    if w then for _ in pairs(w) do anyW = true break end end
    if s then for _ in pairs(s) do anyS = true break end end
    local v = (anyW and not anyS) or false
    __DIO_FlagSet(name, v)
    return v
end
__DIO_SetFlag = function(name, owner, on, suppress)
    if type(name) ~= "string" then return nil end
    owner = tostring(owner or "anon")
    local bag = suppress and __DIO_FlagSup or __DIO_FlagWant
    if not bag[name] then bag[name] = {} end
    if on then
        bag[name][owner] = true
        if __DIO_OwnerAlive[owner] == nil and __DIO_FlagGet(owner) ~= nil then
            __DIO_OwnerAlive[owner] = owner
        end
    else
        bag[name][owner] = nil
    end
    return __DIO_FlagApply(name)
end
__DIO_SharedFlags = {
    StartFarm = true, Level = true, AutoFarm_Bone = true, Auto_Cake_Prince = true,
    FarmTyrant = true, AutoFarmNear = true,
    Prehis_Find = true, Prehis_Skills = true, Prehis_DB = true, Prehis_DE = true,
    SailBoats = true, FishBoat = true, SeaBeast1 = true, Shark = true,
    TerrorShark = true, Piranha = true, MobCrew = true, FarmEliteHunt = true,
    DangerSc = true, Raiding = true, FarmEliteH = true, AutoFarmChest = true,
    AutoChestBP = true, Auto_Awakener = true, SelectChip = true,
}
__DIO_UIWant = function(name, key, on)
    if not __DIO_SharedFlags[name] then return end
    __DIO_SetFlag(name, "UI:" .. tostring(key), on and true or false)
end
__DIO_HasNonUIFlagOwner = function(name)
    local owners = __DIO_FlagWant[name]
    if not owners then return false end
    for owner in pairs(owners) do
        if type(owner) ~= "string" or owner:sub(1, 3) ~= "UI:" then
            return true
        end
    end
    return false
end
__DIO_ValWant = {}
__DIO_BorrowValue = function(owner, name, value)
    if type(name) ~= "string" then return end
    owner = tostring(owner or "anon")
    local bag = __DIO_ValWant[name]
    if not bag then bag = {} __DIO_ValWant[name] = bag end
    if bag[owner] == nil then bag[owner] = { r = __DIO_FlagGet(name) } end
    bag[owner].v = value
    __DIO_FlagSet(name, value)
    if __DIO_OwnerAlive[owner] == nil and __DIO_FlagGet(owner) ~= nil then
        __DIO_OwnerAlive[owner] = owner
    end
end
__DIO_ReleaseValue = function(owner, name)
    local bag = __DIO_ValWant[name]
    if not bag or bag[owner] == nil then return end
    local restore = bag[owner].r
    bag[owner] = nil
    local remaining = nil
    for o, e in pairs(bag) do remaining = e.v break end
    if remaining ~= nil then
        __DIO_FlagSet(name, remaining)
    else
        __DIO_FlagSet(name, restore)
    end
end
function __DIO_BorrowFlag(owner, name)
    if type(name) == "table" then
        for i = 1, #name do __DIO_SetFlag(name[i], owner, true) end
        return
    end
    __DIO_SetFlag(name, owner, true)
end
function __DIO_ReleaseFlag(owner, name)
    if type(name) == "table" then
        for i = 1, #name do __DIO_SetFlag(name[i], owner, false) end
        return
    end
    __DIO_SetFlag(name, owner, false)
end
function __DIO_ReleaseAll(owner)
    owner = tostring(owner or "anon")
    for name, bag in pairs(__DIO_FlagWant) do
        if bag[owner] then bag[owner] = nil __DIO_FlagApply(name) end
    end
    for name, bag in pairs(__DIO_FlagSup) do
        if bag[owner] then bag[owner] = nil __DIO_FlagApply(name) end
    end
    for name, bag in pairs(__DIO_ValWant) do
        if bag[owner] then __DIO_ReleaseValue(owner, name) end
    end
    __DIO_OwnerAlive[owner] = nil
end
__DIO_AnyFarmFlag = function()
    local ok, r = pcall(function()
        return (type(__DIO_FarmFlagsOn) == "function") and __DIO_FarmFlagsOn() or false
    end)
    if ok and r then return true end
    local ok2, any2 = pcall(function()
        local _, a = __DIO_FarmFlagOnSet()
        return a
    end)
    return (ok2 and any2) and true or false
end
__DIO_AnyFeatureOn = function()
    if __DIO_FlyBusy == true then return true end
    if _G.StartFarm == true then return true end
    local ok, r = pcall(__DIO_AnyFarmFlag)
    if ok and r then return true end
    if (__DIO_FeatOnN or 0) > 0 then
        local anyReal = false
        if type(__DIO_FeatMark) == "table" then
            for k, v in pairs(__DIO_FeatMark) do
                if v == true and __DIO_FlagGet(k) == true and __DIO_FlagCounts(k) then
                    anyReal = true
                    break
                end
            end
        end
        if not anyReal then
            __DIO_FeatOnN = 0
            __DIO_FeatMark = {}
        else
            return true
        end
    end
    return false
end

__DIO_TweenBlockT     = 0
__DIO_TweenBlockDur   = 0.5
__DIO_FlagPrev        = __DIO_FlagPrev or {}
__DIO_FlagOnT         = __DIO_FlagOnT or {}
__DIO_FlagOffT        = __DIO_FlagOffT or {}
__DIO_DodgeT0         = __DIO_DodgeT0 or 0
__DIO_DODGE_MAX       = __DIO_DODGE_MAX or 8
__DIO_ExtraFarmFlags  = __DIO_ExtraFarmFlags or { "AutoMaterial", "StartFarm", "NextIs", "senth", "senth2" }
__DIO_FarmFlagList    = nil
__DIO_FarmFlagAll = function()
    if __DIO_FarmFlagList ~= nil then return __DIO_FarmFlagList end
    local t, seen = {}, {}
    for i = 1, #(__DIO_FarmFlagNames or {}) do
        local n = __DIO_FarmFlagNames[i]
        if type(n) == "string" and not seen[n] then seen[n] = true t[#t + 1] = n end
    end
    for i = 1, #(__DIO_ExtraFarmFlags or {}) do
        local n = __DIO_ExtraFarmFlags[i]
        if type(n) == "string" and not seen[n] then seen[n] = true t[#t + 1] = n end
    end
    __DIO_FarmFlagList = t
    return t
end
__DIO_IsFarmFlag = function(name)
    if type(name) ~= "string" then return false end
    for _, n in ipairs(__DIO_FarmFlagAll()) do if n == name then return true end end
    return false
end
__DIO_SeaEventFlagCheck = {
    Shark = "CheckShark", TerrorShark = "CheckTerrorShark", Piranha = "CheckPiranha",
    MobCrew = "CheckFishCrew", HCM = "CheckHauntedCrew", SeaBeast1 = "CheckSeaBeast",
    FishBoat = "CheckEnemiesBoat", PGB = "CheckPirateGrandBrigade", Leviathan1 = "CheckLeviathan",
}
-- FIX Select Sea Event: truoc day dung rawget(_G, "CheckShark") -> trong executor cac ham
-- global cua script KHONG nam trong _G (nam trong env cua script) -> luon tra ve "mob con song"
-- -> chon bat ki sea event nao cung tao highlight + shouldTween = true trong trang thai cho.
-- Gio goi TRUC TIEP ham check (closure resolve global luc goi), co cache 0.3s cho nhe.
__DIO_SeaCheckFns = {
    Shark      = function() return type(CheckShark) == "function" and CheckShark() end,
    TerrorShark= function() return type(CheckTerrorShark) == "function" and CheckTerrorShark() end,
    Piranha    = function() return type(CheckPiranha) == "function" and CheckPiranha() end,
    MobCrew    = function() return type(CheckFishCrew) == "function" and CheckFishCrew() end,
    HCM        = function() return type(CheckHauntedCrew) == "function" and CheckHauntedCrew() end,
    SeaBeast1  = function() return type(CheckSeaBeast) == "function" and CheckSeaBeast() end,
    FishBoat   = function() return type(CheckEnemiesBoat) == "function" and CheckEnemiesBoat() end,
    PGB        = function() return type(CheckPirateGrandBrigade) == "function" and CheckPirateGrandBrigade() end,
    Leviathan1 = function() return type(CheckLeviathan) == "function" and CheckLeviathan() end,
}
__DIO_SeaAliveCache = {}
__DIO_SeaMobAlive = function(flag)
    local __fn = __DIO_SeaCheckFns[flag]
    if not __fn then return true end
    local __c = __DIO_SeaAliveCache[flag]
    local __now = tick()
    if __c and (__now - __c.t) < 0.3 then return __c.v end
    local __ok, __res = pcall(__fn)
    local __v = (__ok and __res == true) and true or false
    -- dang danh mob sea event (trong 3s) thi van coi la "song" de tween khong bi ngat giua chung
    if not __v and type(__DIO_SeaCombat) == "function" and __DIO_SeaCombatName == flag and __DIO_SeaCombat() then __v = true end
    __DIO_SeaAliveCache[flag] = { t = __now, v = __v }
    return __v
end
-- flag sea-event chi "dang bat" (tinh cho tween/highlight) khi mob tuong ung THAT SU co trong map
__DIO_FlagCounts = function(name)
    if __DIO_SeaEventFlagCheck[name] then return __DIO_SeaMobAlive(name) end
    return true
end
__DIO_FarmFlagOnSet = function()
    local out, any = {}, false
    for _, n in ipairs(__DIO_FarmFlagAll()) do
        if __DIO_FlagGet(n) == true and __DIO_FlagCounts(n) then out[n] = true any = true end
    end
    -- FIX Sea Event: loc TUNG flag sea-event (khong chi khi "chi co sea flag"):
    -- _G.Shark/_G.TerrorShark/... chi duoc tinh khi mob tuong ung THAT SU co trong map.
    -- -> chon sea event trong dropdown KHONG con tao highlight/shouldTween o trang thai cho,
    -- -> tat 1 toggle khac thi tween KHONG bi "gan" sang sea event nua.
    if __DIO_BuyFlying == true then out["__DIO_BuyFlying"] = true any = true end
    return out, any
end

__DIO_TweenBlock = function(dur)
    __DIO_TweenBlockT = tick()
    __DIO_TweenBlockDur = tonumber(dur) or 0.5
end
__DIO_TweenClearBlock = function()
    __DIO_TweenBlockT = 0
    __DIO_TweenBlockDur = 0.5
end
__DIO_TweenBlocked = function()
    local bt = __DIO_TweenBlockT or 0
    if bt <= 0 then return false end
    if (tick() - bt) < (__DIO_TweenBlockDur or 0.5) then return true end
    __DIO_TweenBlockT = 0
    return false
end
__DIO_DodgeStale = function()
    if __DIO_Dodging ~= true then return false end
    if (tick() - (__DIO_DodgeT0 or 0)) > (__DIO_DODGE_MAX or 8) then
        __DIO_Dodging = false
        return true
    end
    return false
end
__DIO_TweenAllowed = function()
    if __DIO_TweenBlocked() then return false end
    if __DIO_Dodging == true then __DIO_DodgeStale() end
    if __DIO_Dodging == true then return false end
    return true
end
__DIO_TweenValid = function()
    if __DIO_TweenBlocked() then return false end
    if __DIO_FlyBusy ~= true and type(__DIO_OffQuarantine) == "function" and __DIO_OffQuarantine() then return false end
    if __DIO_Dodging == true then __DIO_DodgeStale() if __DIO_Dodging == true then return false end end
    if __DIO_FlyBusy == true then return true end
    if __DIO_TweenTarget ~= nil and type(__DIO_MoveFresh) == "function" and __DIO_MoveFresh() then return true end
    if type(__DIO_AnyFeatureOn) == "function" and __DIO_AnyFeatureOn() then return true end
    local eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
    return eng and eng.Active and not eng.Active.dead or false
end
__DIO_TweenSync = function()
    local eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
    local moving = eng and eng.Active and not eng.Active.dead
    shouldTween = (moving or __DIO_TweenValid()) and true or false
    if shouldTween == false and type(__DIO_HlOff) == "function" then pcall(__DIO_HlOff) end
    return shouldTween
end
__DIO_TweenSet = function(cf)
    if cf == nil then return end
    local ok = pcall(function() return cf.Position end)
    if not ok then return end
    __DIO_TweenTarget = cf
    __DIO_LastTpT = tick()
    shouldTween = true
    if type(__DIO_Move) == "function" then __DIO_Move() end
end
__DIO_TweenDropHard = function(reason)
    __DIO_TweenTarget = nil
    __DIO_DropPendT = 0
    pcall(function() if __DIO_LastTween and __DIO_LastTween.Cancel then __DIO_LastTween:Cancel() end end)
    __DIO_LastTween = nil
    pcall(function()
        local eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
        if eng and eng.CancelAll then eng.CancelAll() end
    end)
    shouldTween = false
end
__DIO_TweenDrop = function(reason)
    if type(__DIO_AnyFeatureOn) == "function" and __DIO_AnyFeatureOn() then
        __DIO_DropPendT = tick()
        tostring(reason or "soft")
        return
    end
    __DIO_TweenDropHard(reason)
end
__DIO_TweenDropPending = function()
    if (__DIO_DropPendT or 0) > 0 and (tick() - __DIO_DropPendT) >= (__DIO_SOFT_DROP or 1.5) then
        __DIO_DropPendT = 0
        local any = type(__DIO_AnyFeatureOn) == "function" and __DIO_AnyFeatureOn() or false
        if not any then __DIO_TweenDropHard("soft-expired") end
    end
    return __DIO_DropPendT
end
__DIO_TweenKill = function(keepHighlight, force)
    if force ~= true and type(__DIO_AnyFeatureOn) == "function" and __DIO_AnyFeatureOn() then
        return __DIO_TweenSync()
    end
    __DIO_TweenTarget = nil
    __DIO_LastTpT, __DIO_MoveT = 0, 0
    __DIO_CurTarget = nil
    __DIO_DropPendT = 0
    shouldTween = false
    pcall(function() if __DIO_LastTween and __DIO_LastTween.Cancel then __DIO_LastTween:Cancel() end end)
    __DIO_LastTween = nil
    pcall(function()
        local eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
        if eng and eng.CancelAll then eng.CancelAll() end
    end)
    pcall(function()
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local bc = hrp and hrp:FindFirstChild("BodyClip")
        if bc then bc:Destroy() end
    end)
    if keepHighlight ~= true then pcall(function() if type(__DIO_HlOff) == "function" then __DIO_HlOff() end end) end
end

__DIO_OwnerIsFlag = function(owner)
    if type(owner) ~= "string" then return false end
    if owner:sub(1, 3) == "UI:" or owner:sub(1, 3) == "UI/" then return false end
    if owner:find(":", 1, true) then return false end
    local v = __DIO_FlagGet(owner)
    if type(v) == "boolean" then return true end
    return (__DIO_OwnerAlive and __DIO_OwnerAlive[owner] ~= nil) or false
end
__DIO_ReapOwners = function()
    local dead = {}
    local function scan(bagAll)
        for name, bag in pairs(bagAll or {}) do
            for owner in pairs(bag) do
                if type(owner) == "string" then
                    if owner:sub(1, 3) == "UI:" then
                        local key = owner:sub(4)
                        if key:sub(1, 3) == "UI/" and type(__DIO_UIState) == "table" and __DIO_UIState[key] == false then
                            dead[#dead + 1] = { name = name, owner = owner }
                        end
                    elseif __DIO_OwnerIsFlag(owner) and __DIO_FlagGet(owner) ~= true then
                        dead[#dead + 1] = { owner = owner, all = true }
                    end
                end
            end
        end
    end
    scan(__DIO_FlagWant)
    scan(__DIO_FlagSup)
    for name, bag in pairs(__DIO_ValWant or {}) do
        for owner in pairs(bag) do
            if __DIO_OwnerIsFlag(owner) and __DIO_FlagGet(owner) ~= true then
                dead[#dead + 1] = { owner = owner, all = true }
            end
        end
    end
    local done = {}
    for _, d in ipairs(dead) do
        if d.all then
            if not done[d.owner] then
                done[d.owner] = true
                pcall(__DIO_ReleaseAll, d.owner)
            end
        else
            pcall(__DIO_SetFlag, d.name, d.owner, false)
        end
    end
    return #dead
end
__DIO_OffEdgeT = 0
__DIO_PrevAnyOn = false
__DIO_OffQuarantine = function()
    if (__DIO_OffEdgeT or 0) <= 0 then return false end
    if (tick() - __DIO_OffEdgeT) > 6 then return false end
    local any = type(__DIO_AnyFeatureOn) == "function" and __DIO_AnyFeatureOn() or false
    return not any
end
__DIO_MarkOffEdge = function()
    __DIO_OffEdgeT = tick()
    __DIO_FlyCancelT = tick()
end
__DIO_EdgeWatch = function()
    local any = type(__DIO_AnyFeatureOn) == "function" and __DIO_AnyFeatureOn() or false
    if any then
        __DIO_PrevAnyOn = true
        return
    end
    if __DIO_PrevAnyOn == true then
        __DIO_PrevAnyOn = false
        __DIO_MarkOffEdge()
    end
    if __DIO_FlyBusy == true then return end
    local sinceOff = tick() - (__DIO_OffEdgeT or 0)
    local eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
    local anyMover = false
    if eng and eng.Movers then
        for _, m in pairs(eng.Movers) do if m and not m.dead then anyMover = true break end end
    end
    local hl = false
    pcall(function() hl = plr.Character and plr.Character:FindFirstChild("highlight") ~= nil end)
    if not (anyMover or shouldTween == true or __DIO_TweenTarget ~= nil or hl) then return end
    if sinceOff >= 1.5 and sinceOff <= 7 then
        pcall(__DIO_TweenKill, false, true)
        return
    end
    if (tick() - (__DIO_LastTpT or 0)) > 20 then
        pcall(__DIO_TweenKill, false, true)
    end
end
__DIO_RealFarmOn = function()
    local ok, any = pcall(function()
        local _, a = __DIO_FarmFlagOnSet()
        return a
    end)
    return (ok and any) and true or false
end

__DIO_FeatToggle = function(flag, on)
    on = (on == true)
    pcall(__DIO_FlagSet, flag, on)
    pcall(rawset, _G, flag, on)
    if on then
        __DIO_OffEdgeT = 0
        __DIO_PrevAnyOn = true
        pcall(__DIO_TweenClearBlock)
        shouldTween = true
        if type(__DIO_Move) == "function" then pcall(__DIO_Move) end
        pcall(function() if type(__DIO_HlOn) == "function" then __DIO_HlOn() end end)
        pcall(function() __DIO_Wake(true) end)
    else
        pcall(__DIO_ReleaseAll, flag)
        pcall(__DIO_ReapOwners)
        if not __DIO_RealFarmOn() then
            __DIO_FlyCancelT = tick()
            pcall(__DIO_MarkOffEdge)
            __DIO_CurTarget = nil
            pcall(__DIO_TweenKill, false, true)
        else
            -- FIX "tat di van tween": mover dang chay thuong thuoc ve toggle VUA TAT.
            -- Neu feature con lai khong ra lenh _tp moi trong 12s -> huy tween + highlight thua,
            -- khong TweenSync giu chung song mai mai nua.
            if __DIO_FlyBusy ~= true and type(__DIO_MoveFresh) == "function" and not __DIO_MoveFresh() then
                pcall(__DIO_TweenKill, false, true)
            else
                pcall(__DIO_TweenSync)
            end
        end
    end
end
__DIO_Watchdog = function()
    pcall(__DIO_ReapOwners)
    pcall(__DIO_EdgeWatch)
    pcall(__DIO_DodgeStale)
    pcall(__DIO_TweenDropPending)
    if __DIO_FlyBusy == true and __DIO_FlyBusyT ~= nil and (tick() - __DIO_FlyBusyT) > 360 then __DIO_FlyBusy = false end
    pcall(__DIO_TweenSync)
    pcall(function()
        if __DIO_FlyBusy == true then return end
        if type(__DIO_AnyFeatureOn) == "function" and __DIO_AnyFeatureOn()
           and (type(__DIO_MoveFresh) == "function" and __DIO_MoveFresh()) then
            __DIO_StuckN = 0 __DIO_StuckD = nil return
        end
        if type(__DIO_MoveFresh) == "function" and __DIO_MoveFresh() then
            __DIO_StuckN = 0 __DIO_StuckD = nil return
        end
        local eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
        local m = eng and eng.Active
        if m and not m.dead then
            local __d = nil
            pcall(function()
                local __p = m.part
                if __p and __p.Parent and m.goal then __d = (m.goal.Position - __p.Position).Magnitude end
            end)
            if __d then
                if __DIO_StuckD ~= nil and __d >= (__DIO_StuckD - 1) then
                    __DIO_StuckN = (__DIO_StuckN or 0) + 1
                else
                    __DIO_StuckN = 0
                end
                __DIO_StuckD = __d
            end
            if (__DIO_StuckN or 0) >= 8 then
                __DIO_StuckN = 0 __DIO_StuckD = nil
                pcall(function() if eng and eng.CancelAll then eng.CancelAll() end end)
                if type(__DIO_TweenKill) == "function" then pcall(__DIO_TweenKill, false, true) end
                return
            end
        else
            __DIO_StuckN = 0 __DIO_StuckD = nil
            if shouldTween == true and (tick() - (__DIO_LastTpT or 0)) > (__DIO_TWEEN_LEASE or 30) then
                if type(__DIO_TweenKill) == "function" then pcall(__DIO_TweenKill, false, true) end
            end
        end
    end)
end
__DIO_SafeLoop(function()
    while __DIO_wait(0.5) do pcall(__DIO_Watchdog) end
end, "BananaHardTweenWatchdog")
-- FIX: __DIO_UserIntent cu da bo vi no giu highlight/shouldTween theo flag "bat" chu khong theo hoat dong that;
-- logic intent moi nam truc tiep trong vong highlight ben duoi (FlyBusy / mover / _tp moi).
__DIO_HlSync = function(wantOn)
    if wantOn then
        local ch = plr.Character
        if ch and tick() - (__DIO_LastHlDecor or 0) >= 0.25 then
            __DIO_LastHlDecor = tick()
            pcall(function() if type(__DIO_HlOn) == "function" then __DIO_HlOn() end end)
        end
    else
        pcall(function() if type(__DIO_HlOff) == "function" then __DIO_HlOff() end end)
    end
end
if getgenv().DIO_ToggleNotify == nil then getgenv().DIO_ToggleNotify = false end
local SaveFolderName = "DIOHub_V3"
local SaveFileName = SaveFolderName .. "/Settings.json"
pcall(function()
    if makefolder and (not isfolder or not isfolder(SaveFolderName)) then
        makefolder(SaveFolderName)
    end
end)
_G.SaveData = _G.SaveData or {}
_G.DIO_AutoSave = (getgenv().SaveSettings ~= false)
_G.DIO_AutoRestore = (_G.DIO_AutoSave ~= false) and (getgenv().AutoRestoreToggles ~= false)

if getgenv().DIO_ResetStaleFlags ~= false then
    pcall(function()
        local __gSt = nil
        pcall(function() if type(getgenv) == "function" and getgenv() ~= _G then __gSt = getgenv() end end)
        for _, __nm in ipairs({ "AcientOne", "Addealer", "AuraBoss", "AutoAttackDoughKing", "AutoBerry", "AutoBerryH", "AutoBigmom", "AutoChestBP", "AutoChipBeli", "AutoChipFruit", "AutoColShad", "AutoDeathStep", "AutoDoughKing", "AutoDragonTalon", "AutoEcBoss", "AutoEctoplasm", "AutoEvoRace", "AutoFMon", "AutoFactory", "AutoFarmAllBoss", "AutoFarmCandy", "AutoFarmChest", "AutoFarmDungeon", "AutoFarmGodChalice", "AutoFarmIsland", "AutoFarmNear", "AutoFarmRaid", "AutoFarm_Bone", "AutoFireFlowers", "AutoFishSlap", "AutoFistDarkness", "AutoGetQuestBounty", "AutoGetUsoap", "AutoHolyTorch", "AutoHop_Dough", "AutoHytHallow", "AutoKenVTWO", "AutoKillMob", "AutoKilo", "AutoLawKak", "AutoMatSoul", "AutoMaterial", "AutoMiror", "AutoMysticIsland", "AutoPhoenixF", "AutoPlayerHunter", "AutoPole", "AutoPoleV2", "AutoRaidCastle", "AutoRipIngay", "AutoSaber", "AutoSaw", "AutoSerpentBow", "AutoSpawnCP", "AutoStartPrehistoric", "AutoTPAndCollect", "AutoTPGift", "AutoTP_Gift", "AutoTridentW2", "AutoUnHaki", "AutoZou", "Auto_Cake_Prince", "Auto_Cavender", "Auto_Def_DarkCoat", "Auto_DonAcces", "Auto_Electric_Claw", "Auto_Fish", "Auto_God_Human", "Auto_Human", "Auto_Mink", "Auto_Rainbow_Haki", "Auto_SharkMan_Karate", "Auto_Skypiea", "Auto_Soul_Guitar", "Auto_StartRaid", "Auto_SuperHuman", "Auto_SwanGG", "Auto_Tushita", "Auto_Yama", "AutofindKitIs", "Bartilo_Quest", "BlackSpikey", "BuyDrago", "BuyMelee_BuyBlackLeg", "BuyMelee_BuyDragonClaw", "BuyMelee_BuyElectro", "BuyMelee_BuyFishmanKarate", "CDK", "CDK_TS", "CDK_YM", "CitizenQuest", "CollectPresent", "Collect_Ember", "Complete_Trials", "CraftVM", "DT_Uzoth", "DangerLV", "DarkBladev3", "Defeating", "Dojoo", "Doughv2", "DragoV1", "DragoV3", "DummyMan", "FarmBlazeEM", "FarmBoss", "FarmChestM", "FarmEliteH", "FarmEliteHop", "FarmEliteHunt", "FarmGodChalice", "FarmMastery_Dev", "FarmMastery_G", "FarmMastery_S", "FarmPhaBinh", "FarmTyrant", "FindMirage", "FishBoat", "FrozenDimension", "FrozenTP", "Greybeard", "HCM", "HighestMirage", "IceBossRen", "KeysRen", "Level", "Leviathan1", "LongsWord", "Lvthan", "MarinesCoat", "MasterAutoCandy", "MasterAutoLevel", "MobCrew", "PGB", "Piranha", "Praying", "Prefully", "Prehis_DB", "Prehis_DE", "Prehis_Find", "Prehis_Skills", "Raiding", "Relic123", "ResetPH", "SafeMode", "Safemode", "SailBoat_Hydra", "SailBoats", "SeaBeast1", "Shark", "ShotHL", "Snaguine", "StartEvent", "StartFarm", "SwanCoat", "TPDoor", "TPFloor1", "TPFloor2", "TPFloor3", "TPFloor4", "TPGEAR", "TPNpc", "Teleport", "TerrorShark", "TpDrago_Prehis", "TpLab", "TpPly", "Tp_LgS", "Tp_MasterA", "TrainDrago", "TravelDres", "TryLucky", "TwFruits", "TweenBoatOwner", "TwinHook", "UPGDrago", "WardenBoss", "beasthunter", "obsFarm", "tweenKitShrine", "tweenKitsune", "tweenShrine" }) do
            if rawget(_G, __nm) == true then rawset(_G, __nm, false) end
            if __gSt and rawget(__gSt, __nm) == true then rawset(__gSt, __nm, false) end
        end
    end)
end
SaveSettings = function()
    if _G.DIO_AutoSave == false then return false end
    if not writefile then return false end
    local ok = pcall(function()
        writefile(SaveFileName, __SVC_HTTP:JSONEncode(_G.SaveData))
    end)
    return ok
end
LoadSettings = function()
    if _G.DIO_AutoSave == false then return false end
    if not (isfile and isfile(SaveFileName)) then return false end
    local ok, data = pcall(function()
        return __SVC_HTTP:JSONDecode(readfile(SaveFileName))
    end)
    if ok and type(data) == "table" then
        _G.SaveData = data
        return true
    end
    return false
end
GetSetting = function(name, default)
    if _G.DIO_AutoSave == false then return default end
    local v = _G.SaveData[name]
    if v == nil then return default end
    return v
end
SetSetting = function(name, value)
    if _G.DIO_AutoSave == false then return end
    _G.SaveData[name] = value
    pcall(SaveSettings)
end
if _G.DIO_AutoSave ~= false then
    LoadSettings()
end
repeat
    __DIO_wait()
until game:IsLoaded()
local main = plr.PlayerGui:WaitForChild("Main", 10)
local loading = main and main:WaitForChild("Loading", 10)
if loading then
    local __loadCap2 = 0
    repeat
        __DIO_wait()
        __loadCap2 += 1
    until (not loading.Visible) or __loadCap2 >= 90
end
World1 = game.PlaceId == 2753915549 or game.PlaceId == 85211729168715
World2 = game.PlaceId == 4442272183 or game.PlaceId == 79091703265657
World3 = game.PlaceId == 7449423635 or game.PlaceId == 100117331123089
if World1 then
    BossList = {
        "The Gorilla King",
        "Bobby",
        "The Saw",
        "Yeti",
        "Mob Leader",
        "Vice Admiral",
        "Saber Expert",
        "Warden",
        "Chief Warden",
        "Swan",
        "Magma Admiral",
        "Fishman Lord",
        "Wysper",
        "Thunder God",
        "Cyborg",
        "Ice Admiral",
        "Greybeard"
    }
elseif World2 then
    BossList = {
        "Diamond",
        "Jeremy",
        "Orbitus",
        "Don Swan",
        "Smoke Admiral",
        "Awakened Ice Admiral",
        "Tide Keeper",
        "Darkbeard",
        "Cursed Captain",
        "Order"
    }
elseif World3 then
    BossList = {
        "Stone",
        "Hydra Leader",
        "Kilo Admiral",
        "Captain Elephant",
        "Beautiful Pirate",
        "Cake Queen",
        "Dough King",
        "Longma",
        "Soul Reaper",
        "rip_indra True Form",
        "Tyrant of the Skies"
    }
end
if World1 then
    MaterialList = {
        "Leather + Scrap Metal",
        "Angel Wings",
        "Magma Ore",
        "Fish Tail"
    }
elseif World2 then
    MaterialList = {
        "Leather + Scrap Metal",
        "Radioactive Material",
        "Ectoplasm",
        "Mystic Droplet",
        "Magma Ore",
        "Vampire Fang"
    }
elseif World3 then
    MaterialList = {
        "Scrap Metal",
        "Demonic Wisp",
        "Conjured Cocoa",
        "Dragon Scale",
        "Gunpowder",
        "Fish Tail",
        "Mini Tusk"
    }
end
local RenMon = {
    "Snow Lurker",
    "Arctic Warrior",
    "Hidden Key",
    "Awakened Ice Admiral"
}
local Past = {
    "Part",
    "SpawnLocation",
    "Terrain",
    "WedgePart",
    "MeshPart"
}
local BartMon = {
    "Swan Pirate",
    "Jeremy"
}
local Human_v3_Mob = {
    "Fajita",
    "Jeremy",
    "Diamond"
}
local mastery1 = {
    "Cookie Crafter"
}
local mastery2 = {
    "Reborn Skeleton"
}
local PosMsList = {
    ["Pirate Millionaire"] = CFrame.new(-712.8272705078125, 98.5770492553711, 5711.9541015625),
    ["Pistol Billionaire"] = CFrame.new(-723.4331665039062, 147.42906188964844, 5931.9931640625),
    ["Dragon Crew Warrior"] = CFrame.new(7021.50439453125, 55.76270294189453, -730.1290893554688),
    ["Dragon Crew Archer"] = CFrame.new(6625, 378, 244),
    ["Female Islander"] = CFrame.new(4692.7939453125, 797.9766845703125, 858.8480224609375),
    ["Venomous Assailant"] = CFrame.new(4902, 670, 39),
    ["Marine Commodore"] = CFrame.new(2401, 123, -7589),
    ["Marine Rear Admiral"] = CFrame.new(3588, 229, -7085),
    ["Fishman Raider"] = CFrame.new(-10941, 332, -8760),
    ["Fishman Captain"] = CFrame.new(-11035, 332, -9087),
    ["Forest Pirate"] = CFrame.new(-13446, 413, -7760),
    ["Mythological Pirate"] = CFrame.new(-13510, 584, -6987),
    ["Jungle Pirate"] = CFrame.new(-11778, 426, -10592),
    ["Musketeer Pirate"] = CFrame.new(-13282, 496, -9565),
    ["Reborn Skeleton"] = CFrame.new(-8764, 142, 5963),
    ["Living Zombie"] = CFrame.new(-10227, 421, 6161),
    ["Demonic Soul"] = CFrame.new(-9579, 6, 6194),
    ["Posessed Mummy"] = CFrame.new(-9579, 6, 6194),
    ["Peanut Scout"] = CFrame.new(-1993, 187, -10103),
    ["Peanut President"] = CFrame.new(-2215, 159, -10474),
    ["Ice Cream Chef"] = CFrame.new(-877, 118, -11032),
    ["Ice Cream Commander"] = CFrame.new(-877, 118, -11032),
    ["Cookie Crafter"] = CFrame.new(-2021, 38, -12028),
    ["Cake Guard"] = CFrame.new(-2024, 38, -12026),
    ["Baking Staff"] = CFrame.new(-1932, 38, -12848),
    ["Head Baker"] = CFrame.new(-1932, 38, -12848),
    ["Cocoa Warrior"] = CFrame.new(95, 73, -12309),
    ["Chocolate Bar Battler"] = CFrame.new(647, 42, -12401),
    ["Sweet Thief"] = CFrame.new(116, 36, -12478),
    ["Candy Rebel"] = CFrame.new(47, 61, -12889),
    ["Ghost"] = CFrame.new(5251, 5, 1111)
}
pcall(function()
    if not hookfunction then return end
    local rs = __SVC_RS
    local eff = rs:FindFirstChild("Effect")
    local cont = eff and eff:FindFirstChild("Container")
    local death = cont and cont:FindFirstChild("Death")
    if death and death:IsA("ModuleScript") then
        local ok, mod = pcall(require, death)
        if ok and type(mod) == "function" then
            hookfunction(mod, function() end)
        end
    end
end)
pcall(function()
    if not hookfunction then return end
    local rs = __SVC_RS
    local gm = rs:FindFirstChild("GuideModule")
    if gm and gm:IsA("ModuleScript") then
        local ok, mod = pcall(require, gm)
        if ok and type(mod) == "table" and type(mod.ChangeDisplayedNPC) == "function" then
            hookfunction(mod.ChangeDisplayedNPC, function() end)
        end
    end
end)
Marines = function()
      replicated.Remotes.CommF_:InvokeServer("SetTeam2","Marines")
end
Pirates = function()
      replicated.Remotes.CommF_:InvokeServer("SetTeam2","Pirates")
end
__DIO_BOOT("Load Hub 36%")
local Remotes = {}
pcall(function()
    local __mods = replicated:WaitForChild("Modules", 10)
    local __net = __mods and __mods:WaitForChild("Net", 10)
    if __net then
        Remotes.RFJobsRemoteFunction = __net:FindFirstChild("RF/JobsRemoteFunction") or __net:WaitForChild("RF/JobsRemoteFunction", 5)
        Remotes.RFCraft = __net:FindFirstChild("RF/Craft") or __net:WaitForChild("RF/Craft", 5)
    end
end)
if Remotes.RFCraft == nil then warn("[DIO] Modules/Net/RF structure not found - fishing/craft features disabled") end
EquipWeapon = function(text)
  if not text then return end
  if plr.Character and plr.Character:FindFirstChild(text) then return end
  if plr.Backpack:FindFirstChild(text) then
	if plr.Character and plr.Character:FindFirstChild("Humanoid") then plr.Character.Humanoid:EquipTool(plr.Backpack:FindFirstChild(text)) end
  end
end
weaponSc = function(weapon)
  for __in, v in pairs(plr.Backpack:GetChildren()) do
    if v:IsA("Tool") then
      if v.ToolTip == weapon then EquipWeapon(v.Name) end
    end
  end
end
__DIO_MasteryKind = function()
  if _G.FarmMastery_Dev == true then return "Blox Fruit" end
  if _G.FarmMastery_G  == true then return "Gun" end
  if _G.FarmMastery_S  == true then return "Sword" end
  return nil
end
__DIO_EquipMasterySword = function()
  local nm = SwordName
  if type(nm) == "string" and nm ~= "" then
    local ok, have = pcall(function()
      local bp = plr.Backpack and plr.Backpack:FindFirstChild(nm)
      local ch = plr.Character and plr.Character:FindFirstChild(nm)
      return (bp ~= nil) or (ch ~= nil)
    end)
    if ok and have then
      pcall(EquipWeapon, nm)
      return
    end
  end
  pcall(weaponSc, "Sword")
end
__DIO_MasteryPct = function()
  local v = tonumber(_G.HealthFarmMastery)
  if not v then return 30 end
  if v < 1 then v = 1 elseif v > 100 then v = 100 end
  return v
end
__DIO_MobPct = function(model)
  if not model or type(model.FindFirstChild) ~= "function" then return nil end
  local hum = model:FindFirstChild("Humanoid")
  if not hum then return nil end
  local mx = hum.MaxHealth or 0
  if mx <= 0 then return 0 end
  return ((hum.Health or 0) / mx) * 100
end
__DIO_UseMasteryNow = function(model)
  local kind
  pcall(function() kind = __DIO_MasteryKind() end)
  if not kind then return false, nil end
  local pct = __DIO_MobPct(model)
  if pct == nil then return true, kind end
  return (pct <= __DIO_MasteryPct()), kind
end
__DIO_EquipFarmWeapon = function(model)
  if _G.AutoAttackDungeon or _G.AutoRaid or _G.AutoMultiRaid or _G.AutoBuyChipAttackLaw then
    local w = _G.SelectWeaponRaid or "Melee"
    if _G.AutoAttackDungeon then w = _G.SelectWeaponDungeon or "Melee" end
    local nm = nil
    pcall(function() nm = (type(__RAID_ToolName) == "function") and __RAID_ToolName(w) or nil end)
    pcall(EquipWeapon, nm or _G.SelectWeapon)
    return
  end
  local use, kind = __DIO_UseMasteryNow(model)
  if not kind then
    pcall(EquipWeapon, _G.SelectWeapon)
    return
  end
  if not use then
    pcall(EquipWeapon, _G.SelectWeapon)
    return
  end
  if kind == "Sword" then
    __DIO_EquipMasterySword()
  else
    pcall(weaponSc, kind)
  end
end
__DIO_SelfHrp = function()
    local c = plr.Character
    if not c then return nil, nil end
    return c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end
__DIO_MobAliveRoot = function(model)
    if model == nil then return nil end
    local ok, r = pcall(function()
        if typeof(model) ~= "Instance" or model.Parent == nil then return nil end
        local root = model:FindFirstChild("HumanoidRootPart")
        local hum  = model:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then return nil end
        return root
    end)
    if ok then return r end
    return nil
end
__DIO_HitRange = function(base)
    local fd = tonumber(_G.FarmDistance) or 20
    return math.max(tonumber(base) or 60, fd + 25)
end
__DIO_CanUseSkillOn = function(model, base)
    local h, hum = __DIO_SelfHrp()
    if not h or not hum or hum.Health <= 0 then return false end
    local r = __DIO_MobAliveRoot(model)
    if not r then return false end
    local ok, d = pcall(function() return (r.Position - h.Position).Magnitude end)
    if not ok or d == nil then return false end
    return d <= __DIO_HitRange(base)
end
__DIO_M1Click = function()
  pcall(function()
    vim1:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    __DIO_wait(0.05)
    vim1:SendMouseButtonEvent(0, 0, 0, false, game, 1)
  end)
end
__DIO_Dodging   = __DIO_Dodging or false
_G.ModeFarm     = _G.ModeFarm or "Normal"
_G.FarmDistance = _G.FarmDistance or 20
_G.OrbitSpeed   = _G.OrbitSpeed or 170
_G.OrbitHeight  = _G.OrbitHeight or 12
__DIO_OrbitA   = 0
__DIO_CurTarget = nil
__DIO_TargetT  = 0
__DIO_FarmPos = function(model, h, zOff, yawDeg)
    local mdl, modelCF
    if typeof(model) == "CFrame" then
        modelCF = model
    else
        mdl = model
        local root = mdl and mdl:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        modelCF = root.CFrame
    end
    local mode = _G.ModeFarm
    if mode == "Obrit" then
        if mdl then
            __DIO_CurTarget = mdl
            __DIO_TargetT = tick()
        end
        return nil
    end
    if mode == "Dodge" then

        if mdl then
            __DIO_CurTarget = mdl
            __DIO_TargetT = tick()
        end
    end

    local h2 = math.min(tonumber(h) or 20, math.clamp(tonumber(_G.FarmDistance) or (tonumber(h) or 20), 3, 100), 25)
    return modelCF * CFrame.new(0, h2, zOff or 0) * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
end
task.spawn(function()
    local lastT = tick()
    while true do
        local now = tick()
        local dt = now - lastT
        lastT = now
        local mode = _G.ModeFarm
        if (mode ~= "Obrit" and mode ~= "Dodge") or __DIO_Dodging then
            lastT = tick()
            __DIO_wait(0.2)
        else
            pcall(function()
                if type(__DIO_TweenBlocked) == "function" and __DIO_TweenBlocked() then
                    __DIO_CurTarget = nil
                    return
                end
                local mdl = __DIO_CurTarget
                if not mdl or not mdl.Parent or (now - __DIO_TargetT) > 1.5 then
                    __DIO_CurTarget = nil
                    return
                end
                local hum = mdl:FindFirstChild("Humanoid")
                local mroot = mdl:FindFirstChild("HumanoidRootPart")
                if not mroot or (hum and hum.Health <= 0) then
                    __DIO_CurTarget = nil
                    return
                end
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local mcf = mroot.CFrame
                local dist = (mcf.Position - hrp.Position).Magnitude
                if dist > 250 then
                    _tp(mcf * CFrame.new(0, 20, 0))
                    return
                end
                local goal
                if mode == "Obrit" then
                    local r = math.max(tonumber(_G.FarmDistance) or 20, 8)
                    local spd = math.max(tonumber(_G.OrbitSpeed) or 170, 1)
                    __DIO_OrbitA = (__DIO_OrbitA + (spd / r) * dt) % (math.pi * 2)
                    local hgt = tonumber(_G.OrbitHeight) or 12
                    local px = mcf.Position + Vector3.new(
                        math.cos(__DIO_OrbitA) * r, hgt, math.sin(__DIO_OrbitA) * r)
                    goal = CFrame.new(px, mcf.Position)
                else
                    local d = math.max(tonumber(_G.FarmDistance) or 20, 3)
                    goal = mcf * CFrame.new(0, 0, d)
                    goal = CFrame.new(goal.Position, mcf.Position)
                end
                hrp.CFrame = goal
                if __DIO_Block and __DIO_Block.Parent == workspace then
                    __DIO_Block.CFrame = goal
                end
            end)
            __DIO_wait()
        end
    end
end)
local Attack = {}
	Attack.__index = Attack
	Attack.Alive = function(model)
		if not model then
			return
		end
		local Humanoid = model:FindFirstChild("Humanoid")
		return Humanoid and Humanoid.Health > 0
	end
	Attack.Pos = function(model, dist)
		return (Root.Position - model.Position).Magnitude <= dist
	end
	Attack.Kill = function(model, Succes)
		if model and Succes then
			local __root = model:FindFirstChild("HumanoidRootPart")
			if not __root then return end
			local __humM = model:FindFirstChildOfClass("Humanoid")
			if not __humM or __humM.Health <= 0 then return end
			if not model:GetAttribute("Locked") then
				model:SetAttribute("Locked", __root.CFrame)
			end
			local __lk = model:GetAttribute("Locked")
			pcall(BringEnemy, model)
			pcall(__DIO_3nn_SizePart, model)
			__DIO_EquipFarmWeapon(model)
			local Equipped = nil
			pcall(function()
				local __chK = game.Players.LocalPlayer.Character
				Equipped = __chK and __chK:FindFirstChildOfClass("Tool")
			end)
			local ToolTip = Equipped and Equipped.ToolTip
			if ToolTip == "Blox Fruit" then
				_tp(__DIO_FarmPos(model, 10, 0, 90))
			else
				_tp(__DIO_FarmPos(model, 30, 0, 180))
			end
		pcall(__DIO_3nn_M1, model)
			if RandomCFrame then
				__DIO_wait(.5)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 30, 25))
				__DIO_wait(.5)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(25, 30, 0))
				__DIO_wait(.5)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(-25, 30 , 0))
				__DIO_wait(.5)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 30, 25))
				__DIO_wait(.5)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(-25, 30, 0))
			end
		end
	end
	Attack.Kill2 = function(model, Succes)
		if model and Succes then
			local __root = model:FindFirstChild("HumanoidRootPart")
			if not __root then return end
			local __humM = model:FindFirstChildOfClass("Humanoid")
			if not __humM or __humM.Health <= 0 then return end
			if not model:GetAttribute("Locked") then
				model:SetAttribute("Locked", __root.CFrame)
			end
			local __lk = model:GetAttribute("Locked")
			pcall(BringEnemy, model)
			pcall(__DIO_3nn_SizePart, model)
			__DIO_EquipFarmWeapon(model)
			local Equipped = nil
			pcall(function()
				local __chK2 = game.Players.LocalPlayer.Character
				Equipped = __chK2 and __chK2:FindFirstChildOfClass("Tool")
			end)
			local ToolTip = Equipped and Equipped.ToolTip
			if ToolTip == "Blox Fruit" then
				_tp(__DIO_FarmPos(model, 10, 0, 90))
			else
				_tp(__DIO_FarmPos(model, 30, 8, 180))
			end
		pcall(__DIO_3nn_M1, model)
			if RandomCFrame then
				__DIO_wait(0.1)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 30, 25))
				__DIO_wait(0.1)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(25, 30, 0))
				__DIO_wait(0.1)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(-25, 30 , 0))
				__DIO_wait(0.1)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 30, 25))
				__DIO_wait(0.1)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(-25, 30, 0))
			end
		end
	end
	Attack.KillSea = function(model, Succes)
		if model and Succes then
			local __root = model:FindFirstChild("HumanoidRootPart")
			if not __root then return end
			local __humM = model:FindFirstChildOfClass("Humanoid")
			if not __humM or __humM.Health <= 0 then return end
			if not model:GetAttribute("Locked") then
				model:SetAttribute("Locked", __root.CFrame)
			end
			local __lk = model:GetAttribute("Locked")
			pcall(BringEnemy, model)
			pcall(__DIO_3nn_SizePart, model)
			__DIO_EquipFarmWeapon(model)
			local Equipped = nil
			pcall(function()
				local __chK3 = game.Players.LocalPlayer.Character
				Equipped = __chK3 and __chK3:FindFirstChildOfClass("Tool")
			end)
			local ToolTip = Equipped and Equipped.ToolTip
			if ToolTip == "Blox Fruit" then
				__DIO_DodgeBypass = true
				pcall(function() _tp(__DIO_FarmPos(model, 10, 0, 90)) end)
				__DIO_DodgeBypass = nil
			elseif Equipped and Equipped.Name == "Dragonstorm" and type(__RAID_SpamGun) == "function" then

				_tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 60, 0))
				pcall(__RAID_SpamGun, model.HumanoidRootPart)
			else

				__DIO_DodgeBypass = true
				pcall(function() _tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 60, 0)) end)
				__DIO_DodgeBypass = nil
			end

			pcall(__DIO_3nn_M1, model, 80)

			if ToolTip == "Gun" and type(__DIO_SeaSkillAtk) == "function" then
				pcall(__DIO_SeaSkillAtk)
			end
		end
	end
	Attack.Sword = function(model, Succes)
		if model and Succes then
			local __root = model:FindFirstChild("HumanoidRootPart")
			if not __root then return end
			local __humM = model:FindFirstChildOfClass("Humanoid")
			if not __humM or __humM.Health <= 0 then return end
			if not model:GetAttribute("Locked") then
				model:SetAttribute("Locked", __root.CFrame)
			end
			local __lk = model:GetAttribute("Locked")
			pcall(BringEnemy, model)
			pcall(__DIO_3nn_SizePart, model)
			__DIO_EquipFarmWeapon(model)
			if RandomCFrame then
				__DIO_wait(0.1)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 30, 25))
				__DIO_wait(0.1)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(25, 30, 0))
				__DIO_wait(0.1)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(-25, 30 , 0))
				__DIO_wait(0.1)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(0, 30, 25))
				__DIO_wait(0.1)
				_tp(model.HumanoidRootPart.CFrame * CFrame.new(-25, 30, 0))
			end
		pcall(__DIO_3nn_M1, model)
		end
	end
	Attack.Mas = function(model, Succes)
		if model and Succes then
			local root = model:FindFirstChild("HumanoidRootPart")
			local hum  = model:FindFirstChild("Humanoid")
			if not root or not hum then return end
			if not model:GetAttribute("Locked") then
				model:SetAttribute("Locked", root.CFrame)
			end
			local __lk = model:GetAttribute("Locked")
			pcall(BringEnemy, model)
			pcall(__DIO_3nn_SizePart, model)
			if __DIO_UseMasteryNow(model) then
				weaponSc("Blox Fruit")
				_tp(root.CFrame * CFrame.new(0, 20, 0))
				if not __DIO_CanUseSkillOn(model, 60) then return end
				Useskills("Blox Fruit", "Z")
				Useskills("Blox Fruit", "X")
				Useskills("Blox Fruit", "C")
				Useskills("Blox Fruit", "V")
				Useskills("Blox Fruit", "F")
			else
				pcall(EquipWeapon, _G.SelectWeapon)
				_tp(root.CFrame * CFrame.new(0, 30, 0))
				if not __DIO_CanUseSkillOn(model, 45) then return end
				__DIO_M1Click()
			end
		end
	end
	Attack.Masgun = function(model, Succes)
		if model and Succes then
			local root = model:FindFirstChild("HumanoidRootPart")
			local hum  = model:FindFirstChild("Humanoid")
			if not root or not hum then return end
			if not model:GetAttribute("Locked") then
				model:SetAttribute("Locked", root.CFrame)
			end
			local __lk = model:GetAttribute("Locked")
			pcall(BringEnemy, model)
			pcall(__DIO_3nn_SizePart, model)
			if __DIO_UseMasteryNow(model) then
				weaponSc("Gun")
				_tp(root.CFrame * CFrame.new(0, 35, 8))
				if not __DIO_CanUseSkillOn(model, 100) then return end
				Useskills("Gun", "Z")
				Useskills("Gun", "X")
			else
				pcall(EquipWeapon, _G.SelectWeapon)
				_tp(root.CFrame * CFrame.new(0, 30, 0))
				if not __DIO_CanUseSkillOn(model, 45) then return end
				__DIO_M1Click()
			end
		end
	end
statsSetings = function(Num, value)
  if Num == "Melee" then
    if plr.Data.Points.Value ~= 0 then
      replicated.Remotes.CommF_:InvokeServer("AddPoint","Melee",value)
    end
  elseif Num == "Defense" then
    if plr.Data.Points.Value ~= 0 then
      replicated.Remotes.CommF_:InvokeServer("AddPoint","Defense",value)
    end
  elseif Num == "Sword" then
    if plr.Data.Points.Value ~= 0 then
      replicated.Remotes.CommF_:InvokeServer("AddPoint","Sword",value)
    end
  elseif Num == "Gun" then
    if plr.Data.Points.Value ~= 0 then
      replicated.Remotes.CommF_:InvokeServer("AddPoint","Gun",value)
    end
  elseif Num == "Devil" then
    if plr.Data.Points.Value ~= 0 then
      replicated.Remotes.CommF_:InvokeServer("AddPoint","Demon Fruit",value)
    end
  end
end
_G.BringRange = _G.BringRange or 180
_G.MaxBringMobs = _G.MaxBringMobs or 4
_G.AuraDistance = _G.AuraDistance or 300
IsRaidMob = function(mob)
    if not mob then return false end
    local ok, result = pcall(function()
        if mob:GetAttribute("Raid") == true or mob:GetAttribute("IsRaidBoss") == true or mob:GetAttribute("RaidBoss") == true then
            return true
        end
        local gui = plr and plr:FindFirstChild("PlayerGui")
        local main = gui and gui:FindFirstChild("Main")
        local topHud = main and main:FindFirstChild("TopHUDList")
        local raidTimer = topHud and topHud:FindFirstChild("RaidTimer")
        if raidTimer and raidTimer.Visible == true then
            return true
        end
        return false
    end)
    if ok then return result end
    return false
end

__DIO_3nn_TableMobSpawn = __DIO_3nn_TableMobSpawn or {}
task.spawn(function()
    pcall(function()
        if typeof(getnilinstances) == "function" then
            for _, __sp in pairs(getnilinstances()) do
                if __sp:IsA("Part") and __sp:GetAttribute("DisplayName")
                    and string.find(__sp:GetAttribute("DisplayName"), "Lv.") then
                    table.insert(__DIO_3nn_TableMobSpawn, __sp)
                end
            end
        end
    end)
    pcall(function()
        for _, __sp in pairs(game:GetService("Workspace")._WorldOrigin.EnemySpawns:GetChildren()) do
            if __sp:IsA("Part") and __sp:GetAttribute("DisplayName")
                and string.find(__sp:GetAttribute("DisplayName"), "Lv.") then
                table.insert(__DIO_3nn_TableMobSpawn, __sp)
            end
        end
    end)
end)
__DIO_3nn_StripLevel = function(name)
    name = tostring(name or "")
    return (name:gsub(" %p?Lv%.? %d+%p?", ""))
end
__DIO_3nn_DeleteIgnoredMob = function()
    local __en = workspace:FindFirstChild("Enemies")
    if not __en then return end
    for _, __m in pairs(__en:GetChildren()) do
        if __m:IsA("Model") and __m:FindFirstChild("Ignored") then
            pcall(function() __m.Ignored:Destroy() end)
        end
    end
end
__DIO_3nn_SizePart = function(mob)
    if not mob or not mob.Parent or not mob:FindFirstChild("HumanoidRootPart") then return end
    local __ch = plr.Character
    local __hrp = __ch and __ch:FindFirstChild("HumanoidRootPart")
    if not __hrp then return end
    if (__hrp.Position - mob.HumanoidRootPart.Position).Magnitude <= 50 then
        for _, __p in pairs(mob:GetDescendants()) do
            if (__p:IsA("Part") or __p:IsA("MeshPart")) and __p.CanCollide then
                __p.CanCollide = false
            end
        end
    end
end
__DIO_3nn_DetectPartMobBring = function(mobName)
    local __stripped = __DIO_3nn_StripLevel(mobName)
    local __hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not __hrp then return nil end
    local __best, __bestD = nil, math.huge
    local function __scan(list)
        for _, __sp in pairs(list) do
            if __sp and __sp.Parent and __sp:IsA("Part") then
                local __nm = __sp.Name
                if string.find(__nm, "Lv.") then __nm = __DIO_3nn_StripLevel(__nm) end
                if __nm == mobName or __nm == __stripped then
                    local __d = (__hrp.Position - __sp.Position).Magnitude
                    if __d < __bestD then __bestD = __d __best = __sp end
                end
            end
        end
    end
    __scan(__DIO_3nn_TableMobSpawn)
    local __wo = workspace:FindFirstChild("_WorldOrigin")
    local __es = __wo and __wo:FindFirstChild("EnemySpawns")
    if __es then __scan(__es:GetChildren()) end
    return __best
end
__DIO_3nn_GetCenter = function(mobName)
    local __stripped = __DIO_3nn_StripLevel(mobName)
    local __wo = workspace:FindFirstChild("_WorldOrigin")
    local __es = __wo and __wo:FindFirstChild("EnemySpawns")
    if not __es then return nil end
    local __sum, __n = nil, 0
    for _, __sp in pairs(__es:GetChildren()) do
        if __sp:IsA("Part") then
            local __nm = __sp.Name
            if string.find(__nm, "Lv.") then __nm = __DIO_3nn_StripLevel(__nm) end
            if __nm == mobName or __nm == __stripped then
                __sum = (__sum or Vector3.new(0, 0, 0)) + __sp.Position
                __n = __n + 1
            end
        end
    end
    if not __sum or __n == 0 then return nil end
    return CFrame.new(__sum / __n)
end
__DIO_3nn_IsNetOwner = function(part)
    if not part then return false end
    local __chars = workspace:FindFirstChild("Characters")
    if not __chars then return true end
    for _, __c in pairs(__chars:GetChildren()) do
        if __c.Name ~= plr.Name and __c:FindFirstChild("HumanoidRootPart") then
            if (__c.HumanoidRootPart.Position - part.Position).Magnitude <= 300 then
                return false
            end
        end
    end
    return true
end
__DIO_3nn_BringTarget = nil
__DIO_3nn_BringAnchor = nil
__DIO_3nn_BringDeb = false
BringEnemy = function(Mon)
    if not BringEnemyFarm then return end
    if not Mon or not Mon.Parent or not Mon:FindFirstChild("HumanoidRootPart") then return end
    if type(IsRaidMob) == "function" and IsRaidMob(Mon) then return end
    if _G.AutoAttackDungeon then return end
    do
        local __map = workspace:FindFirstChild("Map")
        local __dun = __map and __map:FindFirstChild("Dungeon")
        if __dun and Mon and Mon:IsDescendantOf(__dun) then return end
    end
    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(plr, "SimulationRadius", math.huge)
        end
    end)
    if __DIO_3nn_BringTarget ~= Mon then
        __DIO_3nn_BringTarget = Mon
        local __spawnPart = __DIO_3nn_DetectPartMobBring(Mon.Name)
        __DIO_3nn_BringAnchor = (__spawnPart and __spawnPart.CFrame) or Mon.HumanoidRootPart.CFrame
        local __cyb = false
        pcall(function()
            __cyb = (plr.Data.Race.Value == "Cyborg")
                and (plr.Character:FindFirstChild("RaceTransformed"))
                and plr.Character.RaceTransformed.Value
        end)
        if __cyb then
            __DIO_3nn_BringAnchor = __DIO_3nn_GetCenter(Mon.Name) or __DIO_3nn_BringAnchor
        end
        if not __DIO_3nn_BringAnchor then return end
        __DIO_3nn_DeleteIgnoredMob()
    end
    if __DIO_3nn_BringDeb then
        task.delay(0.1, function() __DIO_3nn_BringDeb = false end)
        return
    end
    local __set = {}
    if not Mon:FindFirstChild("Ignored") then
        table.insert(__set, Mon)
    end
    local __count = math.clamp(math.floor(tonumber(_G.MaxBringMobs) or 2), 2, 20)
    local __radius = (__count > 2) and 350 or 200
    if tonumber(_G.BringRange) and tonumber(_G.BringRange) > 0 then
        __radius = math.clamp(tonumber(_G.BringRange), 50, 1000)
    end
    local __isCyb = false
    pcall(function()
        __isCyb = (plr.Data.Race.Value == "Cyborg")
            and (plr.Character:FindFirstChild("RaceTransformed"))
            and plr.Character.RaceTransformed.Value
    end)
    if __isCyb then __radius, __count = 300, 6 end
    local __en = workspace:FindFirstChild("Enemies")
    if __en then
        for _, __mob in pairs(__en:GetChildren()) do
            if __mob ~= Mon and __mob.Name == Mon.Name and not __mob:FindFirstChild("Ignored") then
                local __hum = __mob:FindFirstChildOfClass("Humanoid")
                local __root = __mob:FindFirstChild("HumanoidRootPart")
                local __raid = (type(IsRaidMob) == "function") and IsRaidMob(__mob)
                if __hum and __root and __hum.Health > 0 and not __raid and __DIO_3nn_IsNetOwner(__root) then
                    if (__root.Position - __DIO_3nn_BringAnchor.Position).Magnitude <= __radius
                        and #__set < __count then
                        table.insert(__set, __mob)
                    end
                end
            end
        end
    end
    local __hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not __hrp then return end
    if __DIO_3nn_BringAnchor
        and (__hrp.Position - Mon.HumanoidRootPart.Position).Magnitude <= 50
        and __DIO_3nn_IsNetOwner(__hrp)
        and #__set >= 2 then
        for _, __mob in pairs(__set) do
            __DIO_3nn_SizePart(__mob)
            local __mr = __mob:FindFirstChild("HumanoidRootPart")
            if __mr then
                if not __DIO_3nn_IsNetOwner(__mr) then
                    __mr.CFrame = __mob:GetPivot()
                    if not __mob:FindFirstChild("Ignored") then
                        local __ig = Instance.new("IntValue")
                        __ig.Name = "Ignored"
                        __ig.Parent = __mob
                    end
                    task.wait(0.3)
                else
                    __mr.CFrame = __DIO_3nn_BringAnchor * CFrame.new(0, math.random(0, 2), math.random(0, 2))
                    task.spawn(function()
                        local __m = __mob
                        local __h = __m:FindFirstChildOfClass("Humanoid")
                        if not __h then return end
                        local __hp = __h.Health
                        task.wait(2.2)
                        if __m.Parent and __m:FindFirstChildOfClass("Humanoid")
                            and __m:FindFirstChild("HumanoidRootPart") then
                            if __m.Humanoid.Health == __hp and not __m:FindFirstChild("Ignored") then
                                __m.HumanoidRootPart.CFrame = __m:GetPivot()
                                local __ig = Instance.new("IntValue")
                                __ig.Name = "Ignored"
                                __ig.Parent = __m
                                task.wait(0.3)
                            end
                        end
                    end)
                end
            end
            __DIO_3nn_BringDeb = true
        end
    end
end
Useskills = function(weapon, skill)
  if weapon == "Melee" then
    weaponSc("Melee")
    if skill == "Z" then
      vim1:SendKeyEvent(true, "Z", false, game);
      vim1:SendKeyEvent(false, "Z", false, game);
    elseif skill == "X" then
      vim1:SendKeyEvent(true, "X", false, game);
      vim1:SendKeyEvent(false, "X", false, game);
    elseif skill == "C" then
      vim1:SendKeyEvent(true, "C", false, game);
      vim1:SendKeyEvent(false, "C", false, game);
    end
  elseif weapon == "Sword" then
    weaponSc("Sword")
    if skill == "Z" then
      vim1:SendKeyEvent(true, "Z", false, game);
      vim1:SendKeyEvent(false, "Z", false, game);
    elseif skill == "X" then
      vim1:SendKeyEvent(true, "X", false, game);
      vim1:SendKeyEvent(false, "X", false, game);
    end
  elseif weapon == "Blox Fruit" then
    weaponSc("Blox Fruit")
    if skill == "Z" then
      vim1:SendKeyEvent(true, "Z", false, game);
      vim1:SendKeyEvent(false, "Z", false, game);
    elseif skill == "X" then
      vim1:SendKeyEvent(true, "X", false, game);
      vim1:SendKeyEvent(false, "X", false, game);
    elseif skill == "C" then
      vim1:SendKeyEvent(true, "C", false, game);
      vim1:SendKeyEvent(false, "C", false, game);
    elseif skill == "V" then
      vim1:SendKeyEvent(true, "V", false, game);
      vim1:SendKeyEvent(false, "V", false, game);
    elseif skill == "F" then
      vim1:SendKeyEvent(true, "F", false, game);
      vim1:SendKeyEvent(false, "F", false, game);
    end
  elseif weapon == "Gun" then
    weaponSc("Gun")
    if skill == "Z" then
      vim1:SendKeyEvent(true, "Z", false, game);
      vim1:SendKeyEvent(false, "Z", false, game);
    elseif skill == "X" then
      vim1:SendKeyEvent(true, "X", false, game);
      vim1:SendKeyEvent(false, "X", false, game);
    end
  end
  if weapon == "nil" and skill == "Y" then
    vim1:SendKeyEvent(true, "Y", false, game);
    vim1:SendKeyEvent(false, "Y", false, game);
  end
end
__DIO_BOOT("Load Hub 55%")
local __DIO_hookOk = pcall(function()
local gg = getrawmetatable(game)
local old = gg.__namecall
setreadonly(gg, false)
gg.__namecall = newcclosure(function(...)
  local method = getnamecallmethod()
  local args = {...}
    if tostring(method) == "FireServer" then
      if tostring(args[1]) == "RemoteEvent" then
        if tostring(args[2]) ~= "true" and tostring(args[2]) ~= "false" then
          if (_G.FarmMastery_G and not SoulGuitar) or (_G.FarmMastery_Dev) or (_G.FarmBlazeEM) or (_G.Prehis_Skills) or (_G.SeaBeast1 or _G.FishBoat or _G.PGB or _G.Leviathan1 or _G.Complete_Trials) or (_G.AimMethod and ABmethod == "Aim Player") or (_G.AimMethod and ABmethod == "Nearest Aim") or (_G.DIO_SkillAim == true) then
            args[2] = MousePos
            return old(unpack(args))
          end
        end
      end
    end
  return old(...)
end)
end)
GetConnectionEnemies = function(a)
  for i,v in pairs(replicated:GetChildren()) do
    if v:IsA("Model") and  ((typeof(a) == "table" and table.find(a, v.Name)) or v.Name == a) and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
      return v
    end
  end
  local __enemiesFolder = game.Workspace:FindFirstChild("Enemies")
  for i,v in next,__enemiesFolder and __enemiesFolder:GetChildren() or {} do
    if v:IsA("Model") and ((typeof(a) == "table" and table.find(a, v.Name)) or v.Name == a)  and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
      return v
    end
  end
end
LowCpu = function()
  local decalsyeeted = true
  local g = game
  local w = g.Workspace
  local l = g.Lighting
  local t = w.Terrain
  t.WaterWaveSize = 0
  t.WaterWaveSpeed = 0
  t.WaterReflectance = 0
  t.WaterTransparency = 0
  l.GlobalShadows = false
  l.FogEnd = 9e9
  l.Brightness = 0
  settings().Rendering.QualityLevel = "Level01"
  for i, v in pairs(g:GetDescendants()) do
    if v:IsA("Part") or v:IsA("Union") or v:IsA("CornerWedgePart") or v:IsA("TrussPart") then
      v.Material = "Plastic"
      v.Reflectance = 0
    elseif v:IsA("Decal") or v:IsA("Texture") and decalsyeeted then
      v.Transparency = 1
    elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
      v.Lifetime = NumberRange.new(0)
    elseif v:IsA("Explosion") then
      v.BlastPressure = 1
      v.BlastRadius = 1
    elseif v:IsA("Fire") or v:IsA("SpotLight") or v:IsA("Smoke") or v:IsA("Sparkles") then
      v.Enabled = false
    elseif v:IsA("MeshPart") then
      v.Material = "Plastic"
      v.Reflectance = 0
      pcall(function() v.TextureID = "rbxassetid://10385902758728957" end)
    end
  end
  for i, e in pairs(l:GetChildren()) do
    if e:IsA("BlurEffect") or e:IsA("SunRaysEffect") or e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect") or e:IsA("DepthOfFieldEffect") then
      e.Enabled = false
    end
  end
end
CheckF = function()
  if GetBP("Dragon-Dragon") or GetBP("Gas-Gas") or GetBP("Yeti-Yeti") or GetBP("Kitsune-Kitsune") or GetBP("T-Rex-T-Rex") then return true end
end
CheckBoat = function()
  local __boatsV5 = workspace:FindFirstChild("Boats")
  if not __boatsV5 then return false end
  for i, v in pairs(__boatsV5:GetChildren()) do
    local __okB, __ownB = pcall(function() return v.Owner.Value end)
    if __okB and tostring(__ownB) == tostring(plr.Name) then
      return v
end;
  end;
  return false
end;
__DIO_EnFolder = function()
    return workspace:FindFirstChild("Enemies")
end
__DIO_SeaBeastFolder = function()
    return workspace:FindFirstChild("SeaBeasts")
end
__DIO_WaterY = function()
    local __m = __SVC_WS:FindFirstChild("Map")
    local __w = __m and __m:FindFirstChild("WaterBase-Plane")
    if __w then return __w.Position.Y end
    return 31
end
CheckEnemiesBoat = function()
  local __en = __DIO_EnFolder()
  if not __en then return false end
  for _,v in pairs(__en:GetChildren()) do
    local __hp = v:FindFirstChild("Health")
    if (v.Name == "FishBoat") and __hp and __hp.Value > 0 then
      return true
end;
  end;
  return false
end;
CheckPirateGrandBrigade = function()
  local __en = __DIO_EnFolder()
  if not __en then return false end
  for _,v in pairs(__en:GetChildren()) do
    local __hp = v:FindFirstChild("Health")
    if (v.Name == "PirateGrandBrigade" or v.Name == "PirateBrigade") and __hp and __hp.Value > 0 then
      return true
    end
  end
  return false
end
CheckShark = function()
  local __en = __DIO_EnFolder()
  if not __en then return false end
  for _,v in pairs(__en:GetChildren()) do
    if v.Name == "Shark" and Attack.Alive(v) then
      return true
end;
  end;
  return false
end;
CheckTerrorShark = function()
  local __en = __DIO_EnFolder()
  if not __en then return false end
  for _,v in pairs(__en:GetChildren()) do
    if v.Name == "Terrorshark" and Attack.Alive(v) then
      return true
end;
  end;
  return false
end;
CheckPiranha = function()
  local __en = __DIO_EnFolder()
  if not __en then return false end
  for _,v in pairs(__en:GetChildren()) do
    if v.Name == "Piranha" and Attack.Alive(v) then
      return true
end;
  end;
  return false
end;
CheckFishCrew = function()
  local __en = __DIO_EnFolder()
  if not __en then return false end
  for _,v in pairs(__en:GetChildren()) do
    if v.Name == "Fish Crew Member" and Attack.Alive(v) then
      return true
end;
  end;
  return false
end;
CheckHauntedCrew = function()
  local __en = __DIO_EnFolder()
  if not __en then return false end
  for _,v in pairs(__en:GetChildren()) do
    if (v.Name == "Haunted Crew Member") and Attack.Alive(v) then
      return true
end;
  end;
  return false
end;
CheckSeaBeast = function()
  local __sb = __DIO_SeaBeastFolder()
  if __sb and __sb:FindFirstChild("SeaBeast1") then
    return true
end;
  return false
end;
CheckLeviathan = function()
  local __sb = __DIO_SeaBeastFolder()
  if __sb and __sb:FindFirstChild("Leviathan") then
    return true
end;
  return false
end;
local __DIO_SeaScanT = 0
local __DIO_SeaScanR = { fish = false, pgb = false, terror = false, shark = false, crew = false, piranha = false }
local function __DIO_SeaScan()
    if tick() - __DIO_SeaScanT < 0.5 then return __DIO_SeaScanR end
    __DIO_SeaScanT = tick()
    local r = { fish = false, pgb = false, terror = false, shark = false, crew = false, piranha = false }
    local en = workspace:FindFirstChild("Enemies")
    if en then
        for _, v in ipairs(en:GetChildren()) do
            local n = v.Name
            if n == "FishBoat" then
                local hh = v:FindFirstChild("Health")
                if hh and hh.Value > 0 then r.fish = true end
            elseif n == "PirateBrigade" or n == "PirateGrandBrigade" then
                local hh = v:FindFirstChild("Health")
                if hh and hh.Value > 0 then r.pgb = true end
            elseif n == "Terrorshark" then
                if Attack.Alive(v) then r.terror = true end
            elseif n == "Shark" then
                if Attack.Alive(v) then r.shark = true end
            elseif n == "Piranha" then
                if Attack.Alive(v) then r.piranha = true end
            elseif n == "Fish Crew Member" or n == "Haunted Crew Member" then
                if Attack.Alive(v) then r.crew = true end
            end
            if r.fish and r.pgb and r.terror and r.shark and r.crew and r.piranha then break end
        end
    end
    __DIO_SeaScanR = r
    return r
end

__DIO_Dodging = __DIO_Dodging or false
_G.AutoDodgeTerrorshark = (_G.AutoDodgeTerrorshark == true)
_G.AutoDodgeSeabeast = (_G.AutoDodgeSeabeast == true)
__DIO_BananaTerrorDodge = false
__DIO_BananaSeaDodge = 0
__DIO_BananaSeaBusy = false

__DIO_TerrorDodgeOn = function()

    return (_G.AutoDodgeTerrorshark == true) and (__DIO_BananaTerrorDodge == true)
        and ((_G.TerrorShark == true) or (_G.SailBoats == true))
end
__DIO_SeaDodgeOff = function()
    __DIO_BananaSeaDodge = 0
    __DIO_BananaSeaBusy = false
end
__DIO_TerrorDodgeOff = function()
    __DIO_BananaTerrorDodge = false
end
__DIO_SeaDodgeY = function()
    if _G.AutoDodgeSeabeast ~= true then return 0 end
    return tonumber(__DIO_BananaSeaDodge) or 0
end
__DIO_BANANA_SEA_ANIMS = {
    ["rbxassetid://8708221792"] = true,
    ["rbxassetid://8708222556"] = true,
}
__DIO_BananaTerror = function()
    local en = workspace:FindFirstChild("Enemies")
    local m = en and en:FindFirstChild("Terrorshark")
    if m and m:FindFirstChild("HumanoidRootPart") then
        local h = m:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then return m end
    end
    return nil
end
__DIO_BananaSeaBeast = function()
    local sb = workspace:FindFirstChild("SeaBeasts")
    local m = sb and sb:FindFirstChild("SeaBeast1")
    if m and m:FindFirstChild("HumanoidRootPart") then
        local hp = m:FindFirstChild("Health")
        if hp and hp.Value > 0 then return m end
    end
    return nil
end
task.spawn(function()
    local wo = workspace:WaitForChild("_WorldOrigin", 30)
    if not wo then return end
    wo.ChildAdded:Connect(function(part)
        if _G.AutoDodgeTerrorshark ~= true then return end
        if __DIO_BananaTerrorDodge then return end
        if not (_G.TerrorShark or _G.SailBoats) then return end
        if not (part and part:IsA("Part")) then return end
        if part.Name ~= "SharkSplash" and part.Name ~= "ChargeUp" then return end
        local t = __DIO_BananaTerror()
        if not t then return end
        local ok, near = pcall(function()
            return (t.HumanoidRootPart.Position - part.Position).Magnitude < 20
        end)
        if not ok or not near then return end
        __DIO_BananaTerrorDodge = true
        task.spawn(function()
            local p0 = part
            local t0 = tick()
            repeat task.wait(0.2) until not p0 or not p0.Parent or tick() - t0 > 14
            if tick() - t0 < 1 then task.wait(2.5) end
            __DIO_BananaTerrorDodge = false
        end)
    end)
end)
__DIO_BananaSeaConn = nil
__DIO_BananaSeaCur = nil
__DIO_SafeLoop(function()
    while __DIO_wait(0.15) do
        pcall(function()
            local on = (_G.AutoDodgeSeabeast == true) and (_G.SeaBeast1 or _G.SailBoats)
            local m = (on and __DIO_BananaSeaBeast()) or nil
            if m ~= __DIO_BananaSeaCur then
                if __DIO_BananaSeaConn then
                    pcall(function() __DIO_BananaSeaConn:Disconnect() end)
                    __DIO_BananaSeaConn = nil
                end
                __DIO_BananaSeaCur = m
                if m then
                    local hum = m:FindFirstChildOfClass("Humanoid")
                    if hum then
                        __DIO_BananaSeaConn = hum.AnimationPlayed:Connect(function(tr)
                            if _G.AutoDodgeSeabeast ~= true then return end
                            if __DIO_BananaSeaBusy or __DIO_BananaSeaDodge ~= 0 then return end
                            local id = tostring(tr.Animation.AnimationId)
                            if not __DIO_BANANA_SEA_ANIMS[id] then return end
                            __DIO_BananaSeaBusy = true
                            task.spawn(function()
                                __DIO_BananaSeaDodge = 0
                                if id == "rbxassetid://8708222556" then task.wait(0.7) else task.wait(1.9) end
                                local t0 = tick()
                                __DIO_BananaSeaDodge = 600
                                repeat task.wait() until not tr.IsPlaying or tick() - t0 >= 10
                                __DIO_BananaSeaDodge = 0
                                __DIO_BananaSeaBusy = false
                            end)
                        end)
                    end
                end
            end
            if not m and __DIO_BananaSeaDodge ~= 0 then __DIO_BananaSeaDodge = 0 end
        end)
    end
end, "L1347")
__DIO_BananaSeaBeamTell = function()
    local ok, hit = pcall(function()
        local wo = workspace:FindFirstChild("_WorldOrigin")
        if not wo then return false end
        for _, v in ipairs(wo:GetChildren()) do
            if v:IsA("Part") then
                local bc = v.BrickColor
                if bc == BrickColor.new("Toothpaste")
                    or bc == BrickColor.new("Institutional white")
                    or v.Name:find("LightBullet") then
                    return true
                end
            end
        end
        return false
    end)
    return ok and hit or false
end
__DIO_SafeLoop(function()
    while __DIO_wait(0.15) do
        if _G.AutoDodgeSeabeast == true and (_G.SeaBeast1 or _G.SailBoats)
            and not __DIO_BananaSeaBusy and __DIO_BananaSeaDodge == 0
            and __DIO_BananaSeaBeast() then
            if __DIO_BananaSeaBeamTell() then
                __DIO_BananaSeaBusy = true
                task.spawn(function()

                    task.wait(0.05)
                    if _G.AutoDodgeSeabeast ~= true then __DIO_BananaSeaBusy = false return end
                    local t0 = tick()
                    __DIO_BananaSeaDodge = 600
                    repeat task.wait(0.2) until not __DIO_BananaSeaBeamTell() or tick() - t0 >= 10
                    __DIO_BananaSeaDodge = 0
                    __DIO_BananaSeaBusy = false
                end)
            end
        end
    end
end, "L1347B")

__DIO_SnapTo = function(cf)
    if not cf then return end
    local ch = plr.Character
    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    if hum.Sit then return end
    local ok = pcall(function()
        __DIO_TweenTarget = nil
        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = cf
        hrp.CanCollide = false
    end)
    if not ok then return end
    if type(__DIO_TweenSet) == "function" then pcall(__DIO_TweenSet, cf) end
end
__DIO_SafeLoop(function()
    while __DIO_wait(0.05) do
        if _G.AutoDodgeSeabeast == true and ((__DIO_BananaSeaDodge or 0) ~= 0) then
            local m = __DIO_BananaSeaBeast()
            local root = m and m:FindFirstChild("HumanoidRootPart")
            if root then
                local p = root.Position
                __DIO_SnapTo(CFrame.new(p.X, __DIO_WaterY() + 200 + __DIO_BananaSeaDodge, p.Z))
            end
        end
    end
end, "L1347C")
UpdStFruit = function()
  for z,x in next, plr.Backpack:GetChildren() do
  StoreFruit = x:FindFirstChild("EatRemote", true)
    if StoreFruit then
      local __fname = StoreFruit.Parent:GetAttribute("OriginalName")
      replicated.Remotes.CommF_:InvokeServer("StoreFruit", __fname,
      plr.Backpack:FindFirstChild(x.Name))
      pcall(function()
        if _G.WebhookStoreFruit and not plr.Backpack:FindFirstChild(x.Name) then
          __DIO_WH_Send("Store Fruit", __fname, true)
        end
      end)
    end
  end
end
collectFruits = function(Succes)
  if Succes then
    local Character = plr.Character
    for _,v1 in pairs(workspace:GetChildren()) do
    if string.find(v1.Name, "Fruit") then v1.Handle.CFrame = Character.HumanoidRootPart.CFrame end
    end
  end
end
Getmoon = function()
  if World1 then
    return Lighting.FantasySky.MoonTextureId
  elseif World2 then
    return Lighting.FantasySky.MoonTextureId
  elseif World3 then
    return Lighting.Sky.MoonTextureId
  end
end
DropFruits = function()
  for _,v3 in next, plr.Backpack:GetChildren() do
    if string.find(v3.Name, "Fruit") then
      EquipWeapon(v3.Name) __DIO_wait(.1)
      if plr.PlayerGui.Main.Dialogue.Visible == true then plr.PlayerGui.Main.Dialogue.Visible = false end EquipWeapon(v3.Name) plr.Character:FindFirstChild(v3.Name).EatRemote:InvokeServer("Drop")
    end
  end
  for a,b2 in pairs(plr.Character:GetChildren()) do
    if string.find(b2.Name, "Fruit") then EquipWeapon(b2.Name) __DIO_wait(.1)
    if plr.PlayerGui.Main.Dialogue.Visible == true then plr.PlayerGui.Main.Dialogue.Visible = false end EquipWeapon(b2.Name) plr.Character:FindFirstChild(b2.Name).EatRemote:InvokeServer("Drop")
    end
  end
end
GetBP = function(v)
  return plr.Backpack:FindFirstChild(v) or plr.Character:FindFirstChild(v)
end
__InvCache = { data = nil, t = 0 }
GetInventoryCached = function()
  if __InvCache.data and (tick() - __InvCache.t) < 2 then
    return __InvCache.data
  end
  local ok, inv = pcall(function()
    return replicated.Remotes.CommF_:InvokeServer("getInventory")
  end)
  if ok and type(inv) == "table" then
    __InvCache.data = inv
    __InvCache.t = tick()
    return inv
  end
  return {}
end
GetIn = function(Name)
  for _ ,v1 in pairs(GetInventoryCached()) do
    if type(v1) == "table" then
      if v1.Name == Name or plr.Character:FindFirstChild(Name) or plr.Backpack:FindFirstChild(Name) then
        return true
	 end
    end
  end
  return false
end
GetM = function(Name)
  for _,tab in pairs(GetInventoryCached()) do
    if type(tab) == "table" then
	  if tab.Type == "Material" then
	    if tab.Name == Name then
		  return tab.Count
	    end
	  end
    end
  end
return 0
end
GetWP = function(nametool)
  for _,v4 in pairs(GetInventoryCached()) do
    if type(v4) == "table" then
      if v4.Type == "Sword" then
        if v4.Name == nametool or plr.Character:FindFirstChild(nametool) or plr.Backpack:FindFirstChild(nametool) then
	     return true
	     end
	   end
      end
    end
  return false
end
getInfinity_Ability = function(Method, Var)
  if not Root then return end
  if Method == "Soru" and Var then
    for _,gc in next, getgc() do
      if plr.Character and plr.Character:FindFirstChild("Soru") then
        if ((typeof(gc) == "function") and (getfenv(gc).script == plr.Character.Soru)) then
          for _, v in next, getupvalues(gc) do
            if (typeof(v) == "table") then
              repeat __DIO_wait(Sec) v.LastUse = 0 until not _G.InfSoru or not (plr.Character and plr.Character:FindFirstChild("Humanoid")) or (plr.Character.Humanoid.Health <= 0)
            end
          end
        end
      end
    end
  elseif Method == "Energy" then
    pcall(function() if __DIO_EnergyConn then __DIO_EnergyConn:Disconnect() __DIO_EnergyConn = nil end end)
    if not Var then return end
    __DIO_EnergyConn = plr.Character.Energy.Changed:connect(function()
      if infEnergy then plr.Character.Energy.Value = Energy end
    end)
  elseif Method == "Observation" and Var then
    local VisionRadius = plr.VisionRadius
    VisionRadius.Value = math.huge
  end
end
Hop = function()
  pcall(function()
    for count = math.random(1, math.random(40, 75)), 100 do
      local remote = replicated.__ServerBrowser:InvokeServer(count)
	  for __jobId, v in next, remote do
	  if tonumber(v['Count']) < 12 then TeleportService:TeleportToPlaceInstance(game.PlaceId, __jobId) end
	  end
    end
  end)
end
local block = Instance.new("Part", workspace)
block.Size = Vector3.new(1, 1, 1)
block.Name = "Rip_Indra"
block.Anchored = true
block.CanCollide = false
block.CanTouch = false
block.Transparency = 1
__DIO_Block = block

task.spawn(function()
    local a = game.Players.LocalPlayer
    repeat task.wait() until a.Character and a.Character.PrimaryPart
    while task.wait(0.12) do
        pcall(function()
            local ch = a.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local root = ch and (ch:FindFirstChild("HumanoidRootPart") or ch.PrimaryPart)
            local eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
            local moving = false
            if eng then
                moving = (eng.Active and not eng.Active.dead) or false
                if not moving and eng.Movers then
                    for _, m in pairs(eng.Movers) do
                        if m and not m.dead then moving = true break end
                    end
                end
            end
            local onFarm = (moving or shouldTween == true or __DIO_TweenTarget ~= nil) and true or false
            if block and block.Parent ~= workspace then block.Parent = workspace end
            if block and root then block.CFrame = root.CFrame end
            if onFarm and ch and not (hum and hum.Sit) and eng and eng.SetNoClip then
                eng.SetNoClip(ch, true)
            elseif (not onFarm) and ch and eng and eng.SetNoClip then
                eng.SetNoClip(ch, false)
            end
        end)
    end
end)
local ReplicatedStorage = __SVC_RS
__DIO_BOOT("Load Hub 60%")
local CommF = nil
pcall(function()
    local __rm = ReplicatedStorage:WaitForChild("Remotes", 10)
    CommF = __rm and __rm:WaitForChild("CommF_", 10) or nil
end)
if CommF == nil then
    warn("[DIO] Remotes/CommF_ not found (game structure changed?) - related features disabled")
    CommF = setmetatable({}, {__index = function()
        return function() warn("[DIO] CommF_ missing, call ignored") return nil end
    end})
end
local TweenService = __SVC_TWN
local RunService = __SVC_RUN
local Players = __SVC_PLR
local LocalPlayer = Players.LocalPlayer
sea1 = (game.PlaceId == 2753915549 or game.PlaceId == 85211729168715)
sea2 = (game.PlaceId == 4442272183 or game.PlaceId == 79091703265657)
sea3 = (game.PlaceId == 7449423635 or game.PlaceId == 100117331123089)
local Settings = {
    ["Tween Speed"] = 350,
    ["Up Y"] = false,
    ["Up Y When Low Health"] = false,
    ["Same Y"] = false
}
local newdao = CFrame.new(10641.0918, -1953.92981, 9825.07031, -0.652825892, -9.2805891e-08, -0.757508039, -2.73638356e-08, 1, -9.89323823e-08, 0.757508039, -4.38572947e-08, -0.652825892)
local cframenpc = CFrame.new(-16271.126, 25.5847301, 1371.98755, 0.999396622, -5.78875188e-08, -0.0347310975, 5.52972779e-08, 1, -8.7544322e-08, 0.034731105, 8.28877091e-08, 0.999396741)
function checkinventory(v)
    if v then
        for i, vl in pairs(GetInventoryCached()) do
            if vl.Name == v then
                return true
            end
        end
    end
    return false
end
function getdis(a,b)
    b = b or LocalPlayer.Character.HumanoidRootPart.CFrame
    local _a = CFrame.new(a.X, b.Y, a.Z)
    local _b = CFrame.new(b.X,b.Y,b.Z)
    return (_a.Position - _b.Position).Magnitude
end
__DIO_MobNearT = 0
__DIO_MobNearR = false
function __DIO_MobNear(pos)
    if pos == nil then return false end
    if tick() - __DIO_MobNearT < 0.5 then
        return __DIO_MobNearR
    end
    __DIO_MobNearT = tick()
    local near = false
    local en = workspace:FindFirstChild("Enemies")
    if en then
        local r2 = 150 * 150
        local px, pz = pos.X, pos.Z
        for _, e in pairs(en:GetChildren()) do
            local hrp = e:FindFirstChild("HumanoidRootPart")
            local hum = e:FindFirstChild("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local dx = hrp.Position.X - px
                local dz = hrp.Position.Z - pz
                if dx * dx + dz * dz <= r2 then
                    near = true
                    break
                end
            end
        end
    end
    __DIO_MobNearR = near
    return near
end
__DIO_NEAR_SPEED  = 600
__DIO_NEAR_RADIUS = 150

__DIO_GetTweenSpeed = function()
    local v = tonumber(_G.TweenSpeed)
    if v == nil then pcall(function() v = tonumber(getgenv().TweenSpeed) end) end
    if v == nil and type(GetSetting) == "function" then
        v = tonumber(GetSetting("UI/Settings/Speed Tween", 190))
    end
    if v == nil and type(Settings) == "table" then
        v = tonumber(Settings["Speed Tween "]) or tonumber(Settings["Tween Speed"])
    end
    v = tonumber(v) or 190
    return math.clamp(math.floor(v + 0.5), 1, 500)
end
__DIO_GetBoatTweenSpeed = function()
    local v = tonumber(_G.BoatTweenSpeed)
    if v == nil then pcall(function() v = tonumber(getgenv().BoatTweenSpeed) end) end
    if v == nil and type(Settings) == "table" then
        v = tonumber(Settings["Value Speed Tween Boat"])
    end
    if v == nil and type(GetSetting) == "function" then
        v = tonumber(GetSetting("UI/SeaEvent/Boat Speed Tween", 165))
    end
    v = tonumber(v) or 165
    return math.clamp(math.floor(v + 0.5), 1, 300)
end
__DIO_PickTweenSpeed = function(distance, rootPos, hum)
    local __sit = (hum ~= nil) and (hum.Sit == true)
    if __sit then
        return __DIO_GetBoatTweenSpeed()
    end
    local __base = __DIO_GetTweenSpeed()
    if _G.Neartween == true and not __sit then
        if (tonumber(distance) or math.huge) <= __DIO_NEAR_RADIUS
           or __DIO_MobNear(rootPos) then
            return math.max(__base, __DIO_NEAR_SPEED)
        end
    end
    return __base
end
function totopofgreattree()
    if getdis(CFrame.new(28310.0234, 14895.1123, 109.456741)) > 1500 then
        ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(28310.0234, 14895.1123, 109.456741))
        __DIO_wait(0.3)
    end
    local targetCF = CFrame.new(28607.5352, 14896.5449, 106.011726)
    _tp(targetCF)
    repeat
        __DIO_wait()
    until getdis(targetCF) <= 5
    __DIO_wait(0.5)
    for i = 1, 4 do
        ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "TeleportBack")
    end
end
function requestentrance(pos)
    local tb = {}
    local targetPos = pos
    if typeof(pos) == "CFrame" then
        targetPos = pos.Position
    end
    if sea1 then
        tb = {
            ["Underwater City"] = Vector3.new(61165.19140625, 0.18704631924629211, 1897.379150390625),
            ["Pirate Village"] = Vector3.new(-1242.4625244140625, 4.787059783935547, 3901.282958984375),
            ["UnderwaterExit"] = Vector3.new(4050, -1, -1814)
        }
    elseif sea2 then
        tb = {
            ["Swan Mansion"] = Vector3.new(-390, 332, 673),
            ["Swan Room"] = Vector3.new(2285, 15, 905),
            ["Cursed Ship"] = Vector3.new(923, 126, 32852),
            ["Zombie Island"] = Vector3.new(-6509, 83, -133)
        }
    else
        tb = {
            ["Hydra Island"] = Vector3.new(5657.88623046875, 1013.0790405273438, -335.4996337890625),
            ["Mansion"] = Vector3.new(-12462, 375, -7552),
            ["Castle"] = Vector3.new(-5036, 315, -3179),
            ["Greate Tree"] = Vector3.new(3024.1709, 2280.69434, -7325.12793)
        }
        if not checkinventory("Valkyrie Helm") then
            return
        end
    end
    local x, y = nil, math.huge
    for i, v in pairs(tb) do
        local distance = (typeof(v) == "Vector3" and (v - targetPos).Magnitude) or (v.Position - targetPos).Magnitude
        if distance < y then
            y = distance
            x = v
        end
    end
    if x and y and y < getdis(pos) then
        if typeof(x) == "Vector3"
            and x.X == 3024.1709 and x.Y == 2280.69434 and x.Z == -7325.12793
            and ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "Check") >= 2 then
            totopofgreattree()
            __DIO_wait(1)
        elseif y < getdis(pos) then
            local requestPos = typeof(x) == "Vector3" and x or x.Position
            ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", requestPos)
            __DIO_wait(1)
        end
    end
end
__DIO_BoatVehCache = setmetatable({}, { __mode = "k" })
__DIO_BoatOwnerName = function(boat)
    if not boat or not boat.Parent then return nil end
    local ok, own = pcall(function()
        local o = boat:FindFirstChild("Owner")
        return o and o.Value
    end)
    if ok and own ~= nil then return tostring(own) end
    return nil
end
__DIO_IsMyBoat = function(boat)
    if not boat then return false end
    local okP = pcall(function() return boat.Parent end)
    if not okP or boat.Parent == nil then return false end
    local own = __DIO_BoatOwnerName(boat)
    if own == nil or own == "" then return true end
    return own == tostring(plr.Name)
end
__DIO_BoatHasVehicleSeat = function(boat)
    if not boat then return false end
    local c = __DIO_BoatVehCache[boat]
    if c ~= nil then return c end
    local has = false
    local ok = pcall(function()
        if boat:FindFirstChild("VehicleSeat") then has = true return end
        for _, d in ipairs(boat:GetDescendants()) do
            if d:IsA("VehicleSeat") then has = true break end
        end
    end)
    if not ok then has = true end
    __DIO_BoatVehCache[boat] = has
    return has
end
__DIO_CanPivotBoat = function(hum)
    if not hum or not hum.Sit then return false, nil end
    local seat = hum.SeatPart
    if not seat then return false, nil end
    local boat = seat:FindFirstAncestorOfClass("Model")
    if not boat then return false, nil end
    if not __DIO_IsMyBoat(boat) then return false, boat end
    if seat:IsA("VehicleSeat") then return true, boat end
    if not __DIO_BoatHasVehicleSeat(boat) then return true, boat end
    return false, boat
end

do
    local RunService = __SVC_RUN or game:GetService("RunService")
    local Players = __SVC_PLR or game:GetService("Players")
    local LP = plr or Players.LocalPlayer

    pcall(function()
        local old = getgenv().__DIO_TweenEngine3nn
        if old and old.StepConnection then old.StepConnection:Disconnect() end
    end)

    local Engine = {}
    __DIO_TweenEngine = Engine
    getgenv().__DIO_TweenEngine3nn = Engine

    Engine.Movers = setmetatable({}, { __mode = "k" })
    Engine.Active = nil
    Engine.MaxStep = 27
    Engine.Eps = 2.5
    Engine.SnapRange = 7
    Engine.ResyncDev = 150
    Engine.AutoNoClip = true
    Engine.NoClip = false
    Engine.Debug = false

    local collideCache = setmetatable({}, { __mode = "k" })
    local listCache = setmetatable({}, { __mode = "k" })

    local function log(...)
        if Engine.Debug then
            print("[DIO-3nnTween]", ...)
        end
    end

    local function getParts(root, force)
        local list, seen = {}, {}
        if not root then return list end
        local c = listCache[root]
        if force or not c or tick() - c.t >= 0.25 or not c.list then
            c = { t = tick(), list = {} }
            local ok, desc = pcall(function() return root:GetDescendants() end)
            if ok and type(desc) == "table" then
                for _, p in ipairs(desc) do
                    if p:IsA("BasePart") then c.list[#c.list + 1] = p end
                end
            end
            listCache[root] = c
        end
        for _, p in ipairs(c.list or {}) do
            if p and not seen[p] then
                seen[p] = true
                list[#list + 1] = p
            end
        end
        local ok2, kids = pcall(function() return root:GetChildren() end)
        if ok2 and type(kids) == "table" then
            for _, p in ipairs(kids) do
                if p:IsA("BasePart") and not seen[p] then
                    seen[p] = true
                    list[#list + 1] = p
                end
            end
        end
        return list
    end

    function Engine.SetNoClip(root, state, force)
        if not root then return end
        if state then
            for _, p in ipairs(getParts(root, force)) do
                if collideCache[p] == nil then collideCache[p] = p.CanCollide end
                if p.CanCollide then p.CanCollide = false end
            end
        else
            for _, p in ipairs(getParts(root, true)) do
                if collideCache[p] ~= nil then
                    local orig = collideCache[p]
                    collideCache[p] = nil
                    pcall(function() p.CanCollide = orig end)
                end
            end
            listCache[root] = nil
        end
    end

    function Engine.RestoreAllNoClip()
        for p, orig in pairs(collideCache) do
            if p then pcall(function() p.CanCollide = orig end) end
        end
        collideCache = setmetatable({}, { __mode = "k" })
    end

    local function fireCompleted(handle, state)
        if not handle then return end
        handle.PlaybackState = state or handle.PlaybackState
        local callbacks = handle.__callbacks
        if callbacks then
            for _, cb in ipairs(callbacks) do
                if cb and cb.alive ~= false and type(cb.fn) == "function" then
                    task.spawn(cb.fn, handle.PlaybackState)
                end
            end
        end
    end

    local function anyMover(kind)
        for _, m in pairs(Engine.Movers) do
            if m and not m.dead and (kind == nil or m[kind] == true) then return true end
        end
        return false
    end

    local function destroy(m, state, reason)
        if not m or m.dead then return end
        m.dead = true
        if m.part and Engine.Movers[m.part] == m then Engine.Movers[m.part] = nil end
        if Engine.Active == m then Engine.Active = nil end
        if m.key and getgenv()[m.key] == m.handle then getgenv()[m.key] = nil end
        if getgenv().Tween == m.handle then getgenv().Tween = nil end

        if m.player then
            if __DIO_LastTween == m.handle then __DIO_LastTween = nil end
            if state == Enum.PlaybackState.Cancelled then
                __DIO_TweenTarget = nil
            end
        end

        fireCompleted(m.handle, state or Enum.PlaybackState.Cancelled)

        if m.player and not anyMover("player") then
            getgenv().noclip = false
            local c = LP and LP.Character
            if c then pcall(function() Engine.SetNoClip(c, false) end) end
            pcall(function()
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                local bv = hrp and hrp:FindFirstChild("BodyClip")
                if bv then bv:Destroy() end
            end)
        end
        log("stop", reason or "", m.part and m.part.Name)
    end

    Engine.Stop = destroy

    function Engine.CancelAll()
        for _, m in pairs(Engine.Movers) do
            pcall(function() destroy(m, Enum.PlaybackState.Cancelled, "CancelAll") end)
        end
        Engine.Active = nil
        pcall(function() Engine.RestoreAllNoClip() end)
    end

    function Engine.CancelPart(part)
        local m = part and Engine.Movers[part]
        if m then destroy(m, Enum.PlaybackState.Cancelled, "CancelPart") end
    end

    local function newHandle(m, goal, speed, key, part)
        local handle = {
            PlaybackState = Enum.PlaybackState.Playing,
            Target = goal,
            Speed = speed,
            TweenKey = key,
            Part = part,
            __callbacks = {},
        }
        function handle:Play()
            if m.dead then return end
            m.paused = false
            m.lastFeed = tick()
            self.PlaybackState = Enum.PlaybackState.Playing
        end
        function handle:Cancel()
            destroy(m, Enum.PlaybackState.Cancelled, "Cancel")
        end
        function handle:Destroy()
            destroy(m, Enum.PlaybackState.Cancelled, "Destroy")
        end
        handle.Completed = {
            Wait = function()
                while handle.PlaybackState == Enum.PlaybackState.Playing or handle.PlaybackState == Enum.PlaybackState.Paused do
                    task.wait()
                end
                return handle.PlaybackState
            end,
            Connect = function(self, cb)
                if type(self) == "function" and cb == nil then cb = self end
                local item = { fn = cb, alive = true }
                handle.__callbacks[#handle.__callbacks + 1] = item
                return { Disconnect = function() item.alive = false end }
            end,
            Once = function(self, cb)
                if type(self) == "function" and cb == nil then cb = self end
                local conn
                conn = handle.Completed:Connect(function(state)
                    if conn then conn:Disconnect() end
                    if type(cb) == "function" then cb(state) end
                end)
                return conn
            end,
        }
        return handle
    end

    function Engine.Move(part, goal, speed, opts)
        opts = opts or {}
        if not part or typeof(goal) ~= "CFrame" or not part:IsA("BasePart") or not part.Parent then return nil end
        -- FIX Sea Event: dang danh mob sea event (nguoi choi da xuong thuyen danh mob)
        -- -> KHONG cho tween thuyen nua (tween thuyen se ep Sit lai vao ghe -> 2 tween danh nhau).
        if opts.boat and type(__DIO_SeaCombat) == "function" and __DIO_SeaCombat() then return nil end
        local __defaultSpeed = (opts and opts.boat and type(__DIO_GetBoatTweenSpeed) == "function" and __DIO_GetBoatTweenSpeed())
            or (opts and opts.player and type(__DIO_GetTweenSpeed) == "function" and __DIO_GetTweenSpeed())
            or (type(__DIO_GetTweenSpeed) == "function" and __DIO_GetTweenSpeed())
            or 190
        speed = math.max(tonumber(speed) or __defaultSpeed, 1)
        local eps = tonumber(opts.eps) or (opts.boat and 6 or Engine.Eps)

        local cur = Engine.Movers[part]
        if cur and not cur.dead then
            cur.goal, cur.speed, cur.eps = goal, speed, eps
            cur.lastFeed = tick()
            cur.paused = false
            if cur.handle then
                cur.handle.Target = goal
                cur.handle.Speed = speed
                cur.handle.PlaybackState = Enum.PlaybackState.Playing
            end
            if opts.key then
                cur.key = opts.key
                getgenv()[opts.key] = cur.handle
            end
            return cur.handle
        end

        local m = {
            part = part,
            goal = goal,
            speed = speed,
            eps = eps,
            path = part.Position,
            holdDev = tonumber(opts.holdDev) or (opts.boat and 90 or Engine.ResyncDev),
            resyncDev = tonumber(opts.resyncDev) or (opts.boat and 400 or Engine.ResyncDev),
            lastFeed = tick(),
            startedAt = tick(),
            player = opts.player == true,
            boat = opts.boat == true,
            holdPath = not opts.boat,
            key = opts.key,
            paused = false,
            dead = false,
        }
        m.char = m.player and LP.Character or nil
        m.boatModel = m.boat and part:FindFirstAncestorOfClass("Model") or nil
        m.handle = newHandle(m, goal, speed, opts.key, part)

        Engine.Movers[part] = m
        if m.player then
            Engine.Active = m
            getgenv().Tween = m.handle
            getgenv().noclip = true
            __DIO_LastTween = m.handle
            shouldTween = true
        end
        if m.boat then
            if m.boatModel then Engine.SetNoClip(m.boatModel, true, true) end
            if m.key then getgenv()[m.key] = m.handle end
            __DIO_LastTween = m.handle
        end
        log("start", part.Name, speed, opts.boat and "boat" or opts.player and "player" or "part")
        return m.handle
    end

    local function stepMover(part, m, dt)
        if not m or m.dead then return false end
        if not part or not part.Parent then
            destroy(m, Enum.PlaybackState.Cancelled, "part gone")
            return false
        end

        if m.player then
            local c = LP.Character
            if not c or c ~= m.char then
                destroy(m, Enum.PlaybackState.Cancelled, "character changed")
                return false
            end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health <= 0 then
                destroy(m, Enum.PlaybackState.Cancelled, "dead")
                return false
            end
            if hum.SeatPart then
                destroy(m, Enum.PlaybackState.Cancelled, "seated")
                return false
            end
            if type(__DIO_TweenValid) == "function" and not __DIO_TweenValid() then
                destroy(m, Enum.PlaybackState.Cancelled, "invalid")
                return false
            end
            Engine.SetNoClip(c, true)
            getgenv().noclip = true
        elseif m.boat then
            if type(__DIO_SeaCombat) == "function" and __DIO_SeaCombat() then
                -- dang combat sea event: huy tween thuyen, KHONG ep Sit nguoi choi vao ghe nua
                destroy(m, Enum.PlaybackState.Cancelled, "sea combat")
                return false
            end
            if tick() >= (m.nextBoatCheck or 0) then
                m.nextBoatCheck = tick() + 0.25
                if m.boatModel then Engine.SetNoClip(m.boatModel, true) end
                local c = LP.Character
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                if hum and (part:IsA("Seat") or part:IsA("VehicleSeat")) then
                    if hum.SeatPart ~= part then pcall(function() part:Sit(hum) end) end
                end
                if hum and not hum.Sit and m.boatModel then

                    pcall(function() part:Sit(hum) end)
                end
            end
            -- [DIO-FIX] Da GO hack nang Y rieng o day (truoc day co 3 co che cung nang Y:
            -- hack nay + CruiseLiftNow + controller Stepped -> danh nhau gay giat).
            -- Gio Y cua thuyen do CHINH step di chuyen ben duoi xu ly (tach truc XZ/Y),
            -- chi 1 noi duy nhat cham vao CFrame thuyen moi frame.
        end

        if m.paused then return true end

        local goal = m.goal
        local rot = part.CFrame - part.CFrame.Position
        local pos = part.Position
        local dev = (pos - m.path).Magnitude
        if not m.holdPath or dev > m.resyncDev then
            m.path = pos
        elseif dev > 0.05 then
            part.CFrame = CFrame.new(m.path) * rot
            pos = m.path
        end

        local delta = goal.Position - m.path
        local __yLocked = (m.boat == true) and (__DIO_BoatYLockOn == true)
        if __yLocked then delta = Vector3.new(delta.X, 0, delta.Z) end
        local dist = delta.Magnitude
        if dist <= m.eps then
            if m.boat and m.boatModel and m.boatModel.Parent then
                -- FIX jerk: thuyen den dich NGUYEN CUM (rigid), khong giat le seat gay vo weld rung lac
                local __arrD = goal.Position - pos
                if __yLocked then __arrD = Vector3.new(__arrD.X, 0, __arrD.Z) end
                pcall(function() m.boatModel:PivotTo(m.boatModel:GetPivot() + __arrD) end)
            else
                part.CFrame = CFrame.new(goal.Position) * rot
            end
            if not part.Anchored then
                part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
            if m.player then
                pcall(function() if __DIO_Block then __DIO_Block.CFrame = part.CFrame end end)
            end
            if tick() - m.lastFeed > 0.30 then
                destroy(m, Enum.PlaybackState.Completed, "arrived")
                return false
            end
            return true
        end

        dt = math.min(tonumber(dt) or 0.0167, 0.1)
        -- [DIO-FIX] Thuyen: tach truc XZ va Y rieng. Truoc day di thang ve goal cach
        -- 10.000.000 studs -> thanh phan Y trong huong di ~ 0 -> thuyen khong bao gio
        -- leo len Y cua slider bang duong di chinh, phai nho hack keo Y (gay giat 31).
        -- Bay gio moi frame: XZ tien ve goal + Y tien thang ve Y goal (cung toc do thuyen),
        -- nen Y len/xuong muot va dung muc slider, on dinh khong gat gu.
        local newPos
        if m.boat then
            local __spdB = math.min(m.speed * dt, Engine.MaxStep)
            local __dxzB = Vector3.new(delta.X, 0, delta.Z)
            local __dxzMagB = __dxzB.Magnitude
            local __moveXZB = (__dxzMagB > 0.001) and ((__dxzB / __dxzMagB) * math.min(__spdB, __dxzMagB)) or Vector3.new(0, 0, 0)
            local __moveYB = __yLocked and 0 or math.clamp(delta.Y, -__spdB, __spdB)
            newPos = m.path + __moveXZB + Vector3.new(0, __moveYB, 0)
        else
            local step = math.min(m.speed * dt, Engine.MaxStep, dist)
            local dir = delta / dist
            newPos = m.path + dir * step
        end
        local look = goal.LookVector
        if m.boat and m.boatModel and m.boatModel.Parent then
            -- FIX jerk: thuyen di NGUYEN CUM (rigid, khong keo lech seat/hull) + giu huong cu
            -- (truoc day giat seat tung frame + van co Bac -> thuyen gat gu lien tuc khi cruise)
            pcall(function() m.boatModel:PivotTo(m.boatModel:GetPivot() + (newPos - pos)) end)
        elseif look.Magnitude < 0.01 or math.abs(look.Y) > 0.99 then
            part.CFrame = CFrame.new(newPos) * rot
        else
            part.CFrame = CFrame.new(newPos, newPos + look)
        end
        m.path = newPos
        if not part.Anchored then
            part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
        if m.player then
            pcall(function() if __DIO_Block then __DIO_Block.CFrame = part.CFrame end end)
        end
        return true
    end
    Engine.StepMover = stepMover

    Engine.StepConnection = RunService.Stepped:Connect(function(_, dt)
        dt = tonumber(dt) or 0.0167
        if dt <= 0 or dt > 0.5 then dt = 0.0167 end
        local char = LP.Character
        if char then
            local wantNoClip = Engine.NoClip or getgenv().noclip or shouldTween == true
            if wantNoClip then
                Engine.SetNoClip(char, true)
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum and hum.PlatformStand then hum.PlatformStand = false end
            end
        end
        for part, m in pairs(Engine.Movers) do
            stepMover(part, m, dt)
        end
    end)

    __DIO_TweenEngineMove = function(goal, rootPart, character)
        local char = character or (LP and LP.Character)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local hrp = rootPart or (char and char:FindFirstChild("HumanoidRootPart"))
        if not goal or typeof(goal) ~= "CFrame" or not hum or not hrp or hum.Health <= 0 then return nil end

        local dist = (goal.Position - hrp.Position).Magnitude
        local speed = (type(__DIO_PickTweenSpeed) == "function" and __DIO_PickTweenSpeed(dist, hrp.Position, hum))
            or (type(__DIO_GetTweenSpeed) == "function" and __DIO_GetTweenSpeed())
            or math.max(tonumber(_G.TweenSpeed) or 190, 1)

        if hum.Sit and type(__DIO_SeaCombat) == "function" and __DIO_SeaCombat() then
            -- dang combat sea event: roi thuyen truoc, vong _tp sau se tween NGUOI CHOI den mob
            if type(__DIO_SeaLeaveSeat) == "function" then pcall(__DIO_SeaLeaveSeat) end
            return __DIO_NewFakeTween and __DIO_NewFakeTween() or nil
        end
        if hum.Sit then
            local canBoat, boat = true, nil
            if type(__DIO_CanPivotBoat) == "function" then
                canBoat, boat = __DIO_CanPivotBoat(hum)
            end
            if not canBoat then return nil end
            local seat = hum.SeatPart
            if not seat or not seat:IsA("BasePart") then return nil end
            if boat then
                __DIO_BoatCache = boat
                Engine.SetNoClip(boat, true, true)
            end
            local boatSpeed = (type(__DIO_GetBoatTweenSpeed) == "function" and __DIO_GetBoatTweenSpeed()) or math.max(tonumber(_G.BoatTweenSpeed) or tonumber(speed) or 165, 1)
            local rot = goal - goal.Position
            local seatGoal = CFrame.new(goal.Position) * rot
            return Engine.Move(seat, seatGoal, boatSpeed, { boat = true, key = "TweenBoat", eps = 6 })
        end

        if dist <= (tonumber(Engine.SnapRange) or 7) then
            Engine.CancelPart(hrp)
            Engine.SetNoClip(char, true)
            getgenv().noclip = true
            hrp.CFrame = goal
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            pcall(function() if __DIO_Block then __DIO_Block.CFrame = hrp.CFrame end end)
            return __DIO_NewFakeTween and __DIO_NewFakeTween() or nil
        end
        return Engine.Move(hrp, goal, speed, { player = true, key = "Tween", eps = 2.5 })
    end
end

do
    local Players = __SVC_PLR or game:GetService("Players")
    local LP = plr or Players.LocalPlayer
    local RS = __SVC_RS or game:GetService("ReplicatedStorage")
    local CSvc = __SVC_CS or game:GetService("CollectionService")
    local VIM = vim1 or __SVC_VIM or game:GetService("VirtualInputManager")
    local Engine = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn

    getgenv().CharSpeed = getgenv().CharSpeed or { cap = 1000, nextRaise = 0 }
    getgenv().TweenSnapRange = (Engine and Engine.SnapRange) or getgenv().TweenSnapRange or 7

    local function hrp()
        local c = LP and LP.Character
        return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"))
    end

    __DIO_Banana_AddFloatForce = function(part)
        if not part or part:FindFirstChild("FloatForce") then return end
        pcall(function()
            local b = Instance.new("BoolValue")
            b.Name = "FloatForce"
            b.Value = true
            b.Parent = part
        end)
    end

    local __tagUntil = 0
    __DIO_Banana_TeleportTag = function()
        __tagUntil = tick() + 1.5
        pcall(function()
            if LP and not CSvc:HasTag(LP, "Teleporting") then CSvc:AddTag(LP, "Teleporting") end
        end)
    end
    task.spawn(function()
        while task.wait(0.1) do
            if __tagUntil > 0 and tick() >= __tagUntil then
                __tagUntil = 0
                pcall(function() if LP and CSvc:HasTag(LP, "Teleporting") then CSvc:RemoveTag(LP, "Teleporting") end end)
            end
        end
    end)

    local __lodDone = false
    local function loadFakePoint(model)
        if not (model and model.GetPivot) then return end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local p = Instance.new("Part")
        p.Transparency = 1
        p.CanCollide = false
        p.Anchored = true
        p.Size = Vector3.new(0, 0, 0)
        p.CFrame = CFrame.new(model:GetPivot().Position)
        p.Name = "DIO_Banana_LoDPosition"
        pcall(function() CSvc:AddTag(p, "LoDPosition") end)
        p.Parent = cam
        return p
    end
    __DIO_Banana_LoadIslands = function()
        if __lodDone then return end
        __lodDone = true
        task.spawn(function()
            pcall(function()
                for _, v in ipairs(workspace:GetChildren()) do
                    if v:IsA("Model") and v:GetAttribute("LevelOfDetailDiameter") then loadFakePoint(v) end
                end
                local map = workspace:FindFirstChild("Map")
                if map then for _, v in ipairs(map:GetChildren()) do if v:IsA("Model") then loadFakePoint(v) end end end
                local fake = RS:FindFirstChild("FakeIslands")
                if fake then for _, v in ipairs(fake:GetChildren()) do if v:IsA("Model") then loadFakePoint(v) end end end
            end)
        end)
    end
    pcall(__DIO_Banana_LoadIslands)

    local function nearestLocation(pos)
        local wo = workspace:FindFirstChild("_WorldOrigin")
        local locs = wo and wo:FindFirstChild("Locations")
        if not locs then return nil end
        local best, bd
        for _, p in ipairs(locs:GetChildren()) do
            if p:IsA("BasePart") and not p:GetAttribute("IgnoreInTracking") then
                local d = (p.Position - pos).Magnitude
                if not bd or d < bd then best, bd = p, d end
            end
        end
        return best
    end
    local function inArea(pos)
        local x = nearestLocation(pos)
        if not x then return nil end
        local mesh = x:FindFirstChild("Mesh") or x:FindFirstChildWhichIsA("SpecialMesh")
        if mesh then
            if (mesh.Scale.X / 2) >= (x.Position - pos).Magnitude then return x end
            return nil
        end
        return x
    end

    __DIO_Banana_BorrowTempleOfTime = function()
        pcall(function()
            local stash = RS:FindFirstChild("MapStash")
            local map = workspace:FindFirstChild("Map")
            local temple = stash and stash:FindFirstChild("Temple of Time")
            if not temple or not map then return end
            temple:SetAttribute("ClientBorrowed", true)
            temple.Parent = map
            task.delay(30, function()
                pcall(function()
                    local h = hrp()
                    local close = h and (h.Position - Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586)).Magnitude < 1000
                    temple:SetAttribute("ClientBorrowed", nil)
                    if not close and temple.Parent == map then temple.Parent = stash end
                end)
            end)
        end)
    end

    local IslandShortcuts = {
        Sea1 = {
            ["Underwater City"] = Vector3.new(61165.19140625, 0.18704631924629211, 1897.379150390625),
            ["Pirate Village"] = Vector3.new(-1242.4625244140625, 4.787059783935547, 3901.282958984375),
            ["UnderwaterExit"] = Vector3.new(4050, -1, -1814),
        },
        Sea2 = {
            ["Swan Mansion"] = Vector3.new(-390, 332, 673),
            ["Swan Room"] = Vector3.new(2285, 15, 905),
            ["Cursed Ship"] = Vector3.new(923, 126, 32852),
            ["Zombie Island"] = Vector3.new(-6509, 83, -133),
        },
        Sea3 = {
            ["Hydra Island"] = Vector3.new(5657.88623046875, 1013.0790405273438, -335.4996337890625),
            ["Mansion"] = Vector3.new(-12462, 375, -7552),
            ["Castle"] = Vector3.new(-5036, 315, -3179),
            ["Greate Tree"] = Vector3.new(3024.1709, 2280.69434, -7325.12793),
            ["Temple Clock"] = Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586),
        },
    }

    local function portalReady()
        local ok, ready = pcall(function()
            local fruit = LP.Data and LP.Data:FindFirstChild("DevilFruit")
            if not fruit or fruit.Value ~= "Portal-Portal" then return false end
            local skillRoot = LP.PlayerGui.Main.Skills:FindFirstChild(fruit.Value)
            local frame = skillRoot and skillRoot:FindFirstChild("C")
            if not frame or not frame:IsA("Frame") then
                local tool = LP.Character:FindFirstChild("Portal-Portal") or LP.Backpack:FindFirstChild("Portal-Portal")
                if tool then LP.Character:FindFirstChildOfClass("Humanoid"):EquipTool(tool) end
                return false
            end
            local cd = frame:FindFirstChild("Cooldown")
            return frame.Title.TextColor3 == Color3.new(1,1,1)
                and (cd.Size == UDim2.new(0,0,1,-1) or cd.Size == UDim2.new(1,0,1,-1))
        end)
        return ok and ready
    end
    local function portalUse(name)
        local ok, used = pcall(function()
            local tool = LP.Character:FindFirstChild("Portal-Portal") or LP.Backpack:FindFirstChild("Portal-Portal")
            if not tool then return false end
            LP.Character:FindFirstChildOfClass("Humanoid"):EquipTool(tool)
            local gui = LP.PlayerGui.Main:FindFirstChild("Gateway")
            if not gui then return false end
            VIM:SendKeyEvent(true, "C", false, game)
            VIM:SendKeyEvent(false, "C", false, game)
            local untilT = tick() + 3
            repeat task.wait(0.1) until gui.Visible or tick() > untilT
            if not gui.Visible then return false end
            local content = gui:FindFirstChild("MainContent")
            local btn = content and content.ScrollingFrame:FindFirstChild(tostring(name))
            if btn and btn.MouseButton1Click then
                for _, c in pairs(getconnections(btn.MouseButton1Click)) do pcall(function() c.Function() end) end
                return true
            end
            return false
        end)
        return ok and used
    end

    __DIO_Banana_DetectNpcOni = function()
        local h = hrp(); if not h then return nil end
        local best, bd
        for _, parent in ipairs({ workspace:FindFirstChild("NPCs"), RS:FindFirstChild("NPCs") }) do
            if parent then
                for _, npc in ipairs(parent:GetChildren()) do
                    if npc:GetAttribute("NPCLoaded") and npc:GetAttribute("NPCReady")
                       and npc:GetAttribute("DisplayName") == "Celestial Member"
                       and npc:FindFirstChild("HumanoidRootPart") then
                        local d = (h.Position - npc.HumanoidRootPart.Position).Magnitude
                        if not bd or d < bd then best, bd = npc, d end
                    end
                end
            end
        end
        return best, bd
    end

    __DIO_Banana_PreMove = function(goal, rootPart, character)
        if typeof(goal) ~= "CFrame" then return nil end
        local h = rootPart or hrp()
        local c = character or (LP and LP.Character)
        local hu = c and c:FindFirstChildOfClass("Humanoid")
        if not h or not hu or hu.Health <= 0 then return nil end
        __DIO_Banana_AddFloatForce(h)
        __DIO_Banana_TeleportTag()

        if h.Position.Y < -60 and h.Position.Y > -100 then
            h.CFrame = h.CFrame * CFrame.new(0, 20, 0)
        end

        if Settings and Settings["Teleport Y"] then
            local hpRate = hu.Health / math.max(hu.MaxHealth, 1)
            local lim = (tonumber(Settings["% Health Player"]) or 40) / 100
            if hpRate < lim then
                return false, goal * CFrame.new(0, tonumber(Settings["Distance Teleport Y"]) or 800, 0)
            end
        end

        local dist = (goal.Position - h.Position).Magnitude

        local usePortal = (_G.UsePortalTeleport == true) or (Settings and Settings["Use Portal Teleport"] == true)
        if usePortal and dist >= 3000 and portalReady() then
            local mapName = workspace:GetAttribute("MAP")
            local pool = (mapName and IslandShortcuts[mapName]) or (sea1 and IslandShortcuts.Sea1) or (sea2 and IslandShortcuts.Sea2) or (sea3 and IslandShortcuts.Sea3)
            for portalName, portalPos in pairs(pool or {}) do
                if (goal.Position - portalPos).Magnitude <= 3000 then
                    getgenv().noclip = true
                    if portalUse(portalName) then
                        return true
                    end
                end
            end
        end

        if dist >= 3000 and tick() - (__DIO_Banana_LastEntrance or 0) > 0.75 then
            local mapName = workspace:GetAttribute("MAP")
            local pool = (mapName and IslandShortcuts[mapName]) or (sea1 and IslandShortcuts.Sea1) or (sea2 and IslandShortcuts.Sea2) or (sea3 and IslandShortcuts.Sea3)
            local bestName, bestPos, bestD
            if pool then
                for name, pos in pairs(pool) do
                    local d = (goal.Position - pos).Magnitude
                    if d <= 3000 and (not bestD or d < bestD) then bestName, bestPos, bestD = name, pos, d end
                end
            end
            -- FIX: truoc day neu requestEntrance khong dua duoc nguoi choi di (dao chua mo khoa /
            -- dang dung ngay canh shortcut) thi _tp lap vo han requestEntrance ma KHONG bao gio tween
            -- -> toggle (Tushita/Yama/Twin Hooks/...) chi co highlight. Gio: shortcut phai giup lai gan
            -- dich that su, va neu goi 2 lan ma khong di chuyen duoc thi bo shortcut do 60s -> tween thuong.
            __DIO_EntFail = __DIO_EntFail or {}
            if bestPos then
                local __failT = __DIO_EntFail[bestName]
                if __failT and (tick() - __failT) < 60 then bestPos = nil end
            end
            if bestPos and (h.Position - bestPos).Magnitude < 600 then bestPos = nil end
            if bestPos and (dist - bestD) < 1500 then bestPos = nil end
            if bestPos then
                local __last = __DIO_EntLast
                if __last and __last.name == bestName and (tick() - __last.t) < 12 then
                    if (h.Position - __last.pos).Magnitude < 200 then
                        __last.n = (__last.n or 1) + 1
                        if __last.n >= 3 then
                            __DIO_EntFail[bestName] = tick()
                            __DIO_EntLast = nil
                            bestPos = nil
                        end
                    else
                        __DIO_EntLast = nil
                    end
                else
                    __DIO_EntLast = { name = bestName, t = tick(), pos = h.Position, n = 1 }
                end
            end
            if bestPos then
                __DIO_Banana_LastEntrance = tick()
                getgenv().noclip = true
                if bestName == "Temple Clock" then __DIO_Banana_BorrowTempleOfTime() end
                pcall(function() RS.Remotes.CommF_:InvokeServer("requestEntrance", bestPos) end)
                return true
            end
        end

        pcall(function()
            local hereArea = inArea(h.Position)
            local goalArea = inArea(goal.Position)
            local nearGoal = nearestLocation(goal.Position)
            local nearHere = nearestLocation(h.Position)
            if goalArea and goalArea.Name == "Celestial Domain" and (not hereArea or hereArea.Name ~= "Celestial Domain") then
                local npc = __DIO_Banana_DetectNpcOni()
                if npc and npc:FindFirstChild("HumanoidRootPart") then
                    __DIO_TweenTarget = npc.HumanoidRootPart.CFrame * CFrame.new(0, 0, 20)
                    local net = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
                    local rf = net and net:FindFirstChild("RF/CelestialDomainTransportation")
                    if rf and (npc.HumanoidRootPart.Position - h.Position).Magnitude < 300 then
                        rf:InvokeServer("InitiateTeleportToTemple")
                        local okCtl, ctl = pcall(function() return require(RS.Controllers.MapServices.CelestialDomainController) end)
                        if okCtl and ctl and ctl.LoadMap then pcall(function() ctl:LoadMap() end) end
                    end
                end
            elseif nearGoal and (nearGoal.Name == "Celestial Domain (Interior)" or nearGoal.Name == "Celestial Domain <Interior>") then
                local net = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
                local rf = net and net:FindFirstChild("RF/CelestialDomainTransportation")
                if hereArea and hereArea.Name == "Celestial Domain" and rf then rf:InvokeServer("InitiateTeleportToInterior") end
            elseif nearHere and (nearHere.Name == "Celestial Domain (Interior)" or nearHere.Name == "Celestial Domain <Interior>")
                and not (nearGoal and (nearGoal.Name == "Celestial Domain (Interior)" or nearGoal.Name == "Celestial Domain <Interior>")) then
                local net = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("Net")
                local rf = net and net:FindFirstChild("RF/CelestialDomainTransportation")
                if rf then rf:InvokeServer("Leave") end
            end
        end)

        return false, goal
    end

    getgenv().TweenManager = getgenv().TweenManager or {}
    TweenManager = getgenv().TweenManager
    TweenManager.currentTween = TweenManager.currentTween or nil
    TweenManager.currentPart = TweenManager.currentPart or nil
    TweenManager.currentGoal = TweenManager.currentGoal or nil
    TweenManager.TweenRunning = TweenManager.TweenRunning or false
    TweenManager.CancelTweenOnly = function()
        local tw = TweenManager.currentTween or getgenv().Tween or __DIO_LastTween
        if tw and tw.Cancel then pcall(function() tw:Cancel() end) end
        TweenManager.currentTween, TweenManager.currentPart, TweenManager.currentGoal = nil, nil, nil
        TweenManager.TweenRunning = false
        getgenv().Tween = nil
        __DIO_LastTween = nil
    end

    SetNoClip = SetNoClip or function(state)
        local c = LP.Character
        if Engine and c then Engine.SetNoClip(c, state == true, true) end
        getgenv().noclip = state == true
    end

    getgenv().StopAllTween = function()
        if TweenManager and TweenManager.CancelTweenOnly then pcall(TweenManager.CancelTweenOnly) end
        if Engine and Engine.CancelAll then pcall(function() Engine.CancelAll() end) end
        for _, key in ipairs({ "TweenBoat", "TweenBoatBack", "TweenBoatToFrozen", "TweenBoatToKitsune", "Tween" }) do
            local h = getgenv()[key]
            if h and h.Cancel then pcall(function() h:Cancel() end) end
            getgenv()[key] = nil
        end
        __DIO_TweenTarget, __DIO_LastTween = nil, nil
        shouldTween = false
        getgenv().noclip = false
        pcall(function() if type(__DIO_HlOff) == "function" then __DIO_HlOff() end end)
    end

end

__DIO_TweenTarget = nil
__DIO_LastTpT = 0
__DIO_NewFakeTween = function()
    local t = { PlaybackState = Enum.PlaybackState.Playing }
    t.Cancel = function()
        __DIO_TweenTarget = nil
        t.PlaybackState = Enum.PlaybackState.Cancelled
    end
    t.Play = function()
        t.PlaybackState = Enum.PlaybackState.Playing
    end
    t.Completed = {
        Wait = function() return Enum.PlaybackState.Completed end,
        Connect = function() return { Disconnect = function() end } end,
        Once = function() end,
    }
    return t
end
-- [DIO-GRAFT Banana] Teleport Y if low health: mau xuong duoi nguong % thi moi
-- lenh _tp tu cong them Y (ne don), mau hoi tren 80% moi ha (2 nguong chong
-- nhap nhay). Khong ap dung khi dang ngoi thuyen (he Y thuyen quan ly rieng).
-- [LOWHP BEGIN]
__DIO_LowHpYOn = false
__DIO_LowHpYOffset = function(hp, maxHp)
    if not _G.LowHpTpY then
        __DIO_LowHpYOn = false
        return 0
    end
    hp = tonumber(hp) or 0
    maxHp = tonumber(maxHp) or 0
    if maxHp <= 0 then return 0 end
    local __ratioLH = hp / maxHp
    local __pctLH = math.clamp(tonumber(_G.LowHpPct) or 40, 0, 100) / 100
    if __ratioLH < __pctLH then
        __DIO_LowHpYOn = true
    elseif __ratioLH > 0.8 then
        __DIO_LowHpYOn = false
    end
    if __DIO_LowHpYOn then
        return math.clamp(tonumber(_G.LowHpTpYDist) or 800, 0, 10000)
    end
    return 0
end
-- [LOWHP END]

_tp = function(target)
    -- FIX "treo": lenh _tp "tre" tu loop cua toggle VUA TAT (loop dang giua vong) -> bo qua,
    -- khong tao lai tween/highlight/shouldTween sau khi da tat toggle.
    if __DIO_FlyBusy ~= true and type(__DIO_OffQuarantine) == "function" and __DIO_OffQuarantine() then
        return __DIO_NewFakeTween and __DIO_NewFakeTween() or nil
    end
    if __DIO_Dodging == true then
        if type(__DIO_DodgeStale) == "function" then __DIO_DodgeStale() end
        if __DIO_Dodging == true then return end
    end
    if type(__DIO_TweenBlocked) == "function" and __DIO_TweenBlocked() then
        if not __DIO_AnyFeatureOn() then return end
        if type(__DIO_TweenClearBlock) == "function" then __DIO_TweenClearBlock() end
    end
    if type(__DIO_TweenAllowed) == "function" and not __DIO_TweenAllowed() then
        if type(__DIO_TweenClearBlock) == "function" then __DIO_TweenClearBlock() end
    end
    local gg
    if typeof(target) == "Vector3" then
        gg = CFrame.new(target)
    elseif typeof(target) == "CFrame" then
        gg = target
    else
        gg = target and target.CFrame
    end
    if not gg then return end

    if (not __DIO_DodgeBypass) and __DIO_TerrorDodgeOn and __DIO_TerrorDodgeOn() then
        gg = gg + Vector3.new(0, 200, 0)
    end
    local character = plr.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local rootPart = character.HumanoidRootPart
    do
        local __humLH = character:FindFirstChildOfClass("Humanoid")
        if __humLH and not __humLH.Sit and type(__DIO_LowHpYOffset) == "function" then
            local __offLH = __DIO_LowHpYOffset(__humLH.Health, __humLH.MaxHealth)
            if __offLH and __offLH > 0 then gg = gg + Vector3.new(0, __offLH, 0) end
        end
    end
    do
        local __needEnt = false
        pcall(function()
            local __sitTP = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
            if not (__sitTP and __sitTP.Sit)
               and (gg.Position - rootPart.Position).Magnitude > 1500
               and tick() - (__DIO_LastReqEnt or 0) > 2 then
                __DIO_LastReqEnt = tick()
                __needEnt = true
            end
        end)
        if __needEnt then
            pcall(function() requestentrance(target) end)
        end
    end
    pcall(function()
        if not sea3 then return end
        local __chSub = plr.Character
        local hrp = __chSub and __chSub:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local __okD0, __d0 = pcall(getdis, gg.Position, newdao.Position)
        if (not __okD0) or (__d0 == nil) or __d0 >= 2000 then return end
        if math.abs(newdao.Position.Y - hrp.CFrame.Y) <= 1000 then return end
        local __t0Sub, __trySub = tick(), 0
        while __trySub < 16 and (tick() - __t0Sub) < 10 do
            __trySub = __trySub + 1
            __DIO_wait(0.5)
            local __chS2 = plr.Character
            local __hrpS2 = __chS2 and __chS2:FindFirstChild("HumanoidRootPart")
            if not __hrpS2 then break end
            pcall(old_tp, cframenpc)
            local __okN, __dN = pcall(getdis, cframenpc)
            if __okN and __dN ~= nil and __dN < 10 then
                local __netS = ReplicatedStorage:FindFirstChild("Modules")
                __netS = __netS and __netS:FindFirstChild("Net")
                local __rfS = __netS and __netS:FindFirstChild("RF/SubmarineWorkerSpeak")
                if __rfS then
                    pcall(function() __rfS:InvokeServer("AskKilledTikiBoss") end)
                    __DIO_wait(0.5)
                    pcall(function() __rfS:InvokeServer("TravelToSubmergedIsland") end)
                end
            end
            local __okG, __dG = pcall(getdis, gg.Position)
            if __okG and __dG ~= nil and __dG < 2000 then break end
        end
        __DIO_wait(0.6)
        pcall(function()
            local __chS3 = plr.Character
            local __hrpS3 = __chS3 and __chS3:FindFirstChild("HumanoidRootPart")
            local __bc = __hrpS3 and __hrpS3:FindFirstChild("BodyClip")
            if __bc then __bc:Destroy() end
        end)
    end)
    do
        local __pp = gg.Position
        if __pp.X ~= __pp.X or __pp.Y ~= __pp.Y or __pp.Z ~= __pp.Z then return end
    end
    if type(__DIO_Banana_PreMove) == "function" then
        local __okPre, __handled, __newGoal = pcall(__DIO_Banana_PreMove, gg, rootPart, character)
        if __okPre then
            if typeof(__newGoal) == "CFrame" then gg = __newGoal end
            if __handled == true then
                -- FIX: nhanh requestEntrance/portal truoc day return ma KHONG bat shouldTween
                -- -> toggle chi co highlight, khong co shouldTween = true.
                __DIO_TweenTarget = gg
                __DIO_LastTpT = tick()
                shouldTween = true
                if type(__DIO_Move) == "function" then __DIO_Move() end
                local __ft = __DIO_NewFakeTween and __DIO_NewFakeTween() or nil
                __DIO_LastTween = __ft
                return __ft
            end
        end
    end
    __DIO_TweenTarget = gg
    __DIO_LastTpT = tick()
    shouldTween = true
    if type(__DIO_Move) == "function" then __DIO_Move() end
    if type(__DIO_TweenClearBlock) == "function" and __DIO_AnyFeatureOn() then __DIO_TweenClearBlock() end
    local __tw = nil
    pcall(function()
        if type(__DIO_TweenEngineMove) == "function" then
            __tw = __DIO_TweenEngineMove(gg, rootPart, character)
        end
    end)
    if __tw then
        __DIO_LastTween = __tw
        return __tw
    end
    local __ft = __DIO_NewFakeTween()
    __DIO_LastTween = __ft
    return __ft
end

old_tp = function(p)
    pcall(function()
        local __eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
        if __eng and __eng.CancelAll then __eng.CancelAll() end
    end)
    local char = plr.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = p
        __DIO_TweenSet(p)
        if __DIO_Block then __DIO_Block.CFrame = p end
    end
end
topos = function(...) return _tp(...) end
StopTween = function(state)
    if state == false and type(getgenv().StopAllTween) == "function" then
        pcall(getgenv().StopAllTween)
        return
    end
    if state then
        shouldTween = true
        __DIO_TweenBlockT = 0
        __DIO_TweenBlockDur = 0.5
        if type(__DIO_Move) == "function" then pcall(__DIO_Move) end
        if type(__DIO_TweenSync) == "function" then pcall(__DIO_TweenSync) end
        return
    end
    if type(__DIO_TweenKill) == "function" then
        __DIO_TweenKill(false, true)
        return
    end
    shouldTween = false
    __DIO_TweenTarget = nil
    pcall(function()
        if __DIO_LastTween then
            __DIO_LastTween:Cancel()
            __DIO_LastTween = nil
        end
    end)
    pcall(function()
        if type(__DIO_HlOff) == "function" then __DIO_HlOff() end
    end)
end
AutoHaki = function()
    if plr.Character and not plr.Character:FindFirstChild("HasBuso") then
        replicated.Remotes.CommF_:InvokeServer("Buso")
    end
end
TeleportToTarget = function(targetCFrame)
    local __chTT = plr.Character
    local __hrpTT = __chTT and __chTT:FindFirstChild("HumanoidRootPart")
    if not __hrpTT or not targetCFrame then return end
    _tp(targetCFrame)
end
notween = function(p)

    if (not __DIO_DodgeBypass) and typeof(p) == "CFrame" and __DIO_TerrorDodgeOn and __DIO_TerrorDodgeOn() then
        p = p + Vector3.new(0, 200, 0)
    end
    if __DIO_Dodging == true then
        if type(__DIO_DodgeStale) == "function" then __DIO_DodgeStale() end
        if __DIO_Dodging == true then return end
    end
    if type(__DIO_TweenBlocked) == "function" and __DIO_TweenBlocked() then return end
    local c = plr.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h then
        pcall(function()
            local __eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
            if __eng and __eng.CancelPart then __eng.CancelPart(h) end
        end)
        h.CFrame = p
        __DIO_TweenSet(p)
        if __DIO_Block then __DIO_Block.CFrame = p end
    end
end
__DIO_FarmFlagsOn = function()
    -- FIX: uy quyen cho __DIO_FarmFlagOnSet (da loc flag sea-event khi khong co mob that su)
    local __out, __any = __DIO_FarmFlagOnSet()
    if __any then return true end
    return false
end
__DIO_HlOn = function()
    local __ch = plr.Character
    if not __ch then return end
    if __ch:FindFirstChild("highlight") then return end
    pcall(function()
        local Test = Instance.new("Highlight")
        Test.Name = "highlight"
        Test.Enabled = true
        Test.FillColor = Color3.fromRGB(0,255,120)
        Test.OutlineColor = Color3.fromRGB(0,255,120)
        Test.FillTransparency = 0.5
        Test.OutlineTransparency = 0.2
        Test.Parent = __ch
    end)
end
__DIO_HlOff = function()
    local __ch = plr.Character
    local __hl = __ch and __ch:FindFirstChild("highlight")
    if __hl then pcall(function() __hl:Destroy() end) end
end
__DIO_TweenOnIfAnyFlag = function()
    local __on = __DIO_AnyFeatureOn()
    if (not __on) and __DIO_TweenTarget ~= nil and __DIO_MoveFresh() then
        __on = true
    end
    if __on then
        shouldTween = true
        __DIO_TweenBlockT = 0
        __DIO_TweenBlockDur = 0.5
        if type(__DIO_TweenSync) == "function" then pcall(__DIO_TweenSync) end
    end
    return __on
end
__DIO_BoatCache = nil
__DIO_NoClipT = 0
__DIO_NoClipShipNow = function(boat)
    if getgenv().NoClipShip == false then return end
    if tick() - (__DIO_NoClipT or 0) < 0.15 then return end
    __DIO_NoClipT = tick()
    local __b = boat
    if not __b then
        local __ch0 = plr.Character
        local __hum0 = __ch0 and __ch0:FindFirstChildOfClass("Humanoid")
        local __seat0 = __hum0 and __hum0.SeatPart
        __b = (__seat0 and __seat0:FindFirstAncestorOfClass("Model")) or __DIO_BoatCache
    end
    if not __b or not __b.Parent then return end
    __DIO_BoatCache = __b
    pcall(function()
        for _, __p in ipairs(__b:GetDescendants()) do
            if __p:IsA("BasePart") and __p.CanCollide then __p.CanCollide = false end
        end
    end)
    pcall(function()
        local __chN = plr.Character
        if __chN then
            for _, __p in ipairs(__chN:GetDescendants()) do
                if __p:IsA("BasePart") and __p.CanCollide then __p.CanCollide = false end
            end
        end
    end)
end
__DIO_MyBoat = function()
    local __ch = plr.Character
    local __hum = __ch and __ch:FindFirstChildOfClass("Humanoid")
    local __seat = __hum and __hum.SeatPart
    if __seat then
        local __b = __seat:FindFirstAncestorOfClass("Model")
        if __b and __DIO_IsMyBoat(__b) then
            __DIO_BoatCache = __b
            return __b
        end
    end
    local __c = __DIO_BoatCache
    if __c and __c.Parent and __DIO_IsMyBoat(__c) then return __c end
    local __okB, __b2 = pcall(CheckBoat)
    if __okB and __b2 and __DIO_IsMyBoat(__b2) then
        __DIO_BoatCache = __b2
        return __b2
    end
    __DIO_BoatCache = nil
    return nil
end
__DIO_BoatSeatOf = function(boat)
    if not boat then return nil end
    local __s = boat:FindFirstChild("VehicleSeat")
    if __s then return __s end
    for _, __d in ipairs(boat:GetDescendants()) do
        if __d:IsA("VehicleSeat") or __d:IsA("Seat") then return __d end
    end
    return nil
end
__DIO_BoatAssist = function()
    -- FIX Sea Event: dang danh mob sea event -> khong keo nguoi choi ve ghe (tranh 2 tween danh nhau)
    if type(__DIO_SeaCombat) == "function" and __DIO_SeaCombat() then return "busy" end
    local __ch = plr.Character
    local __hum = __ch and __ch:FindFirstChildOfClass("Humanoid")
    local __hrp = __ch and __ch:FindFirstChild("HumanoidRootPart")
    if not __hum or not __hrp or __hum.Health <= 0 then return "busy" end
    if __hum.Sit then
        local __seat = __hum.SeatPart
        local __b = __seat and __seat:FindFirstAncestorOfClass("Model")
        local __canDrive = __DIO_CanPivotBoat(__hum)
        if __canDrive and __b then
            __DIO_BoatCache = __b
            __DIO_NoClipShipNow(__b)
            return "sitting"
        end
        __DIO_TweenDrop()
        if __b and __DIO_IsMyBoat(__b) then
            local __drv = __DIO_BoatSeatOf(__b)
            if __drv and __drv ~= __seat then
                pcall(function() __hum.Sit = false end)
                pcall(function() __DIO_wait(0.15) end)
                if (__hrp.Position - __drv.Position).Magnitude > 20 then
                    pcall(function() __hrp.CFrame = __drv.CFrame * CFrame.new(0, 1, 0) end)
                end
                pcall(function() __drv:Sit(__hum) end)
            end
        else
            pcall(function() __hum.Sit = false end)
            __DIO_BoatCache = nil
        end
        return "busy"
    end
    local __boat = __DIO_MyBoat()
    if not __boat then
        local __now = tick()
        if __now - (__DIO_LastBuyTry or 0) < 4 then return "busy" end
        __DIO_LastBuyTry = __now
        local __buyCF = CFrame.new(-16927.451, 9.086, 433.864)
        if (__buyCF.Position - __hrp.Position).Magnitude <= 12 then
            pcall(function() replicated.Remotes.CommF_:InvokeServer("BuyBoat", (_G.SelectedBoat or "Guardian")) end)
        else
            _tp(__buyCF)
        end
        return "busy"
    end
    local __seat = __DIO_BoatSeatOf(__boat)
    if not __seat then
        if tick() - (__DIO_LastRebuy or 0) > 15 then
            __DIO_LastRebuy = tick()
            pcall(function() replicated.Remotes.CommF_:InvokeServer("BuyBoat", (_G.SelectedBoat or "Guardian")) end)
        end
        return "busy"
    end
    local __sp = __seat.CFrame.Position
    if (__hrp.Position - __sp).Magnitude <= 8 and __hrp.Position.Y >= __sp.Y - 1 then
        __DIO_TweenTarget = nil
        __hrp.AssemblyLinearVelocity = Vector3.new(0, -15, 0)
        return "busy"
    end
    _tp(__seat.CFrame * CFrame.new(0, 1, 0))
    return "goSeat"
end
-- He thong Y thuyen cho 4 Find (Frozen Dimension / Kitsune / Prehistoric / Mirage):
--  * Slider "Fly Boat" (_G.FlyBoatY): Y bay co dinh, CHI ap dung cho 4 Find.
--    Auto Sea Event KHONG dung Fly Boat (luon giu Y 31).
--  * Toggle "Teleport Y boat using a slider" (_G.TeleportYSlider) + slider
--    "Teleport Y boat If have Sea Event (ALL)" (_G.SeaTeleportY): khi dang Find ma
--    co Sea Event (tru Leviathan) thi bay len SeaTeleportY; het Sea Event (sau 5s)
--    nhuong lai cho Fly Boat.
--  * 4 Find khong goi _tp nua: dung __DIO_CruiseGo(src, dich); bo lai __tickDrv (Stepped + Heartbeat)
--    giu Y tuyet doi va dua thuyen XZ ve dich nen khong con 2 noi keo Y danh nhau.
__DIO_FindAnyOn = function()
    if _G.FindMirage or _G.Prehis_Find or _G.AutofindKitIs or _G.FrozenDimension then return true end
    return false
end
__DIO_SeaYSeenT = 0
__DIO_SeaEventPresentY = function()
    -- Sea Event (ALL) cho muc dich nang Y - co chu dich KHONG co Leviathan.
    if type(__DIO_SeaScan) == "function" then
        local __s = __DIO_SeaScan()
        if __s.fish or __s.pgb or __s.terror or __s.shark or __s.crew or __s.piranha then return true end
    else
        -- Du phong (khong dung toi __DIO_SeaScan): quet truc tiep, van tru Leviathan.
        local __fns = { CheckEnemiesBoat, CheckPirateGrandBrigade, CheckTerrorShark, CheckShark, CheckFishCrew, CheckPiranha, CheckHauntedCrew }
        for __i = 1, #__fns do
            local __fn = __fns[__i]
            if type(__fn) == "function" then
                local __okF, __resF = pcall(__fn)
                if __okF and __resF then return true end
            end
        end
    end
    if type(CheckSeaBeast) == "function" then
        local __okS, __resS = pcall(CheckSeaBeast)
        if __okS and __resS then return true end
    end
    return false
end
__DIO_BoatWantY = function()
    if _G.TeleportYSlider then
        if __DIO_SeaEventPresentY() then __DIO_SeaYSeenT = tick() end
        -- Giu Y Sea Event them 5s sau lan thay cuoi (chong nhay len/xuong khi mob
        -- chop tat o ria scan). Qua 5s sach su kien -> tra ve Fly Boat.
        if (tick() - (tonumber(__DIO_SeaYSeenT) or 0)) < 5 then
            return math.clamp(math.floor(tonumber(_G.SeaTeleportY) or 150), 150, 600)
        end
    end
    return math.clamp(math.floor(tonumber(_G.FlyBoatY) or 150), 30, 500)
end
-- Moi Find (mirage / prehis / kitsune / frozen) tu bao "toi dang quet bien" qua
-- __DIO_CruiseFeed(src). Cruise con hieu luc 3s sau lan bao cuoi, nen ghe nhay Sit
-- tam thoi hoac vong lap thoat/vao lai KHONG lam mat khoa Y (nguyen nhan thuyen
-- roi ve Y 31 roi bay len lai). Chi khi thay dao / tat toggle moi goi CruiseStop(src).
__DIO_CruiseFeeds = {}
__DIO_CruiseDest = nil
__DIO_CruiseFeed = function(src)
    __DIO_CruiseFeeds[src or "find"] = tick()
    __DIO_CruiseDest = nil
    return __DIO_BoatWantY()
end
-- Thay cho _tp(dich) o 4 Find: bao "dang quet" + dat dich cho bo lai thuyen (khong qua Tween Engine).
__DIO_CruiseGo = function(src, destCF)
    local __nowG = tick()
    __DIO_CruiseFeeds[src or "find"] = __nowG
    if destCF then __DIO_CruiseDest = { pos = destCF.Position, t = __nowG } end
end
__DIO_CruiseStop = function(src)
    __DIO_CruiseFeeds[src or "find"] = nil
end
__DIO_CruiseActive = function()
    if not __DIO_FindAnyOn() then return false end
    local __nowCA = tick()
    for _, __tCA in pairs(__DIO_CruiseFeeds) do
        if (__nowCA - __tCA) <= 3 then return true end
    end
    return false
end
-- [DIO-GRAFT Banana] Find ping-pong "Will Back When over 10km":
-- thuyen chay ra bien xa dan; khi "danger distance" (module DangerDistance cua
-- game, don vi /10 giong Banana) >= 10000 thi quay dau ve diem neo, vao gan
-- <= 4800 lai chay ra tiep. Nho vay thuyen luon o trong vung bien sau co the
-- spawn dao/su kien, thay vi chay 1 chieu ra vo cuc nhu truoc. Tat toggle
-- "Will Back When over 10km" thi ve hanh vi cu (1 chieu).
-- [FINDPINGPONG BEGIN]
__DIO_FindBack = false
local __DIO_DangerMod = nil
local __DIO_DangerTried = false
__DIO_DangerDist10 = function()
    local __chD = plr.Character
    local __hrpD = __chD and __chD:FindFirstChild("HumanoidRootPart")
    if not __hrpD then return nil end
    if not __DIO_DangerTried then
        __DIO_DangerTried = true
        pcall(function()
            local __dd = __SVC_RS:WaitForChild("DangerDistance", 2)
            if __dd then __DIO_DangerMod = require(__dd) end
        end)
    end
    if __DIO_DangerMod then
        local __okD, __valD = pcall(function()
            local __nearD = __DIO_DangerMod:GetNearestNPC(__hrpD.Position, 2600)
            local __yD = __nearD and __nearD[1]
            if not __yD then return nil end
            return math.floor((__DIO_DangerMod:GetDistance(__yD) - __hrpD.Position).Magnitude / 10)
        end)
        if __okD and __valD then return __valD end
    end
    -- Du phong khi khong co module: khoang cach ngang toi Hydra Island /10
    local __dxD = __hrpD.Position.X - 5657.88623046875
    local __dzD = __hrpD.Position.Z - (-335.4996337890625)
    return math.floor(math.sqrt(__dxD * __dxD + __dzD * __dzD) / 10)
end
__DIO_FindCruiseDest = function(wantY)
    local __yC = tonumber(wantY) or 150
    if not _G.FindBack10km then
        return CFrame.new(-10000000, __yC, 37016.25)
    end
    local __dC = __DIO_DangerDist10()
    if __dC then
        if __dC >= 10000 then
            __DIO_FindBack = true
        elseif __dC <= 4800 then
            __DIO_FindBack = false
        end
    end
    if __DIO_FindBack then
        return CFrame.new(-32975.9921875, __yC, 25963.7109375)
    end
    return CFrame.new(-10000000, __yC, 37016.25)
end
-- [FINDPINGPONG END]
-- Bo lai thuyen cho 4 Find (port co che ban cu: vi tri goc tuyet doi + Y dich tuc thi + ep thuyen
-- ve vi tri goc moi frame + van toc 0). Ghe nhay Sit tam thoi thi van giu thuyen cu trong cua so
-- cruise 3s. __DIO_BoatYLockOn = true khi bo lai dang giu thuyen (Tween Engine khong keo Y nua).
__DIO_BoatYLockOn = false
__DIO_BoatYResolve = function()
    local __chY = plr.Character
    local __humY = __chY and __chY:FindFirstChildOfClass("Humanoid")
    local __seatY = (__humY and __humY.Sit) and __humY.SeatPart or nil
    local __boatY = __seatY and __seatY:FindFirstAncestorOfClass("Model") or nil
    if __boatY and __DIO_IsMyBoat(__boatY) then
        __DIO_BoatCache = __boatY
        return __boatY, __seatY
    end
    local __bcY = __DIO_BoatCache
    if __bcY and __bcY.Parent and __DIO_IsMyBoat(__bcY) then
        local __sY = __DIO_BoatSeatOf(__bcY)
        local __hrpY = __chY and __chY:FindFirstChild("HumanoidRootPart")
        if __sY and __hrpY and (__sY.Position - __hrpY.Position).Magnitude <= 80 then
            return __bcY, __sY
        end
    end
    return nil, nil
end
do
    -- Port co che ban cu: part "block" neo cung giu vi tri GOC TUYET DOI, _tp snap Y cua block
    -- ve Y dich roi tween XZ, vong lap moi frame ep thuyen/nguoi ve block (HRP.CFrame = block.CFrame)
    -- va BodyClip giu van toc 0. O day: __drv la vi tri goc cua ghe; Y = Y dich TUC THI (khong buoc
    -- theo vi tri vat ly hien tai), XZ tien ve dich theo toc do thuyen, moi frame dich ca thuyen
    -- (PivotTo ca model, khong tach seat) ve dung __drv va triet tieu van toc.
    local __drv = nil
    local __targetY, __targetT = nil, 0
    local __speed, __speedT = 165, 0
    local __clipT = 0
    local function __drvOff()
        __DIO_BoatYLockOn = false
        __drv = nil
    end
    local function __tickDrv(__dtD, __advance)
        if not __DIO_CruiseActive() or (type(__DIO_SeaCombat) == "function" and __DIO_SeaCombat()) then
            __drvOff()
            return
        end
        local __boatD, __seatD = __DIO_BoatYResolve()
        if not __boatD or not __seatD then
            __drvOff()
            return
        end
        local __nowD = tick()
        if __targetY == nil or (__nowD - __targetT) >= 0.2 then
            local __okY, __valY = pcall(__DIO_BoatWantY)
            if __okY and tonumber(__valY) then
                __targetY = tonumber(__valY)
            else
                warn("[DIO] BoatWantY loi: " .. tostring(__valY))
            end
            __targetT = __nowD
        end
        if (__nowD - __speedT) >= 0.5 then
            local __okS, __valS = pcall(__DIO_GetBoatTweenSpeed)
            if __okS and tonumber(__valS) then __speed = tonumber(__valS) end
            __speedT = __nowD
        end
        if __targetY == nil then
            __drvOff()
            return
        end
        local __sp = __seatD.Position
        -- lech ngang > 200 (thuyen bi day/teleport/doi thuyen) -> lay lai goc tai thuyen, giong block.CFrame = HRP.CFrame
        if __drv == nil or math.sqrt((__drv.X - __sp.X) ^ 2 + (__drv.Z - __sp.Z) ^ 2) > 200 then
            __drv = __sp
        end
        __drv = Vector3.new(__drv.X, __targetY, __drv.Z)
        if __advance then
            local __dest = __DIO_CruiseDest
            if __dest and (__nowD - __dest.t) <= 3 then
                local __dx = __dest.pos.X - __drv.X
                local __dz = __dest.pos.Z - __drv.Z
                local __dist = math.sqrt(__dx * __dx + __dz * __dz)
                if __dist > 0.5 then
                    local __step = math.min(__speed * math.clamp(tonumber(__dtD) or 0.0167, 0.001, 0.1), __dist)
                    __drv = Vector3.new(__drv.X + __dx / __dist * __step, __drv.Y, __drv.Z + __dz / __dist * __step)
                end
            end
        end
        __DIO_BoatYLockOn = true
        local __delta = __drv - __sp
        if __delta.Magnitude > 0.02 then
            __boatD:PivotTo(__boatD:GetPivot() + __delta)
        end
        local __rootD = __seatD.AssemblyRootPart or __seatD
        __rootD.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        __rootD.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        if (__nowD - __clipT) >= 0.25 then
            __clipT = __nowD
            pcall(__DIO_NoClipShipNow, __boatD)
        end
    end
    local __RSD = game:GetService("RunService")
    local function __guardDrv(__dtG, __advG)
        local __okG, __errG = pcall(__tickDrv, __dtG, __advG)
        if not __okG then
            __drvOff()
            warn("[DIO] Find cruise driver loi: " .. tostring(__errG))
        end
    end
    __RSD.Stepped:Connect(function(_, __dtS) __guardDrv(__dtS, false) end)
    __RSD.Heartbeat:Connect(function(__dtH) __guardDrv(__dtH, true) end)
end

-- [DIO-GRAFT Banana] Auto Repair Ur Ship: doc mau thuyen tren HUD, thuyen chua
-- full mau + dang dung gan thuyen cua minh (khong ngoi ghe, khong combat bien)
-- thi cam Bua Sua Thuyen (_RepairHammer cua Shipwright) go lien tuc. Chua co
-- bua thi xin qua SubclassNetwork (toi da 10s/lan, khong spam remote).
-- [SHIPHP BEGIN]
__DIO_ParseShipHp = function(txt)
    if type(txt) ~= "string" then return nil, nil end
    local __curS, __maxS = txt:match("(%d+)%s*/%s*(%d+)")
    return tonumber(__curS), tonumber(__maxS)
end
-- [SHIPHP END]
__DIO_SafeLoop(function()
    local __hammerTryT = 0
    while __DIO_wait(0.5) do
        if not _G.AutoRepairShip then continue end
        pcall(function()
            if type(__DIO_SeaCombat) == "function" and __DIO_SeaCombat() then return end
            local __chR = plr.Character
            local __humR = __chR and __chR:FindFirstChildOfClass("Humanoid")
            local __hrpR = __chR and __chR:FindFirstChild("HumanoidRootPart")
            if not __humR or not __hrpR or __humR.Health <= 0 or __humR.Sit then return end
            local __boatR = (type(__DIO_MyBoat) == "function" and __DIO_MyBoat()) or nil
            if not __boatR then return end
            local __okP, __pivotR = pcall(function() return __boatR:GetPivot().Position end)
            if not __okP or not __pivotR then return end
            if (__pivotR - __hrpR.Position).Magnitude > 25 then return end
            local __guiR = plr:FindFirstChild("PlayerGui")
            local __mainR = __guiR and __guiR:FindFirstChild("Main")
            local __hudR = __mainR and __mainR:FindFirstChild("BottomHUDList")
            local __barR = __hudR and __hudR:FindFirstChild("ShipHealthBar")
            if not __barR or not __barR.Visible then return end
            local __lblR = __barR:FindFirstChild("TextLabel")
            local __curR, __maxR = __DIO_ParseShipHp(__lblR and __lblR.Text)
            if not __curR or not __maxR or __curR >= __maxR then return end
            local __hammerR = __chR:FindFirstChild("_RepairHammer")
            if not __hammerR then
                local __bpR = plr:FindFirstChild("Backpack")
                local __bpHamR = __bpR and __bpR:FindFirstChild("_RepairHammer")
                if __bpHamR then
                    pcall(function() __humR:EquipTool(__bpHamR) end)
                    return
                end
                if (tick() - __hammerTryT) < 10 then return end
                __hammerTryT = tick()
                pcall(function()
                    __SVC_RS.Remotes.SubclassNetwork.UseSubclass:InvokeServer({ Action = "RequestHammer" })
                end)
                return
            end
            local __upR = __hammerR:FindFirstChild("M1UP")
            if __upR then
                __upR:Destroy()
            elseif not __hammerR:GetAttribute("Repairing") then
                local __downR = __hammerR:FindFirstChild("M1Down")
                if __downR then __downR:FireServer("Default") end
            end
        end)
    end
end, "DIO-RepairShip")

task.spawn(function()
    while task.wait(0.15) do
        pcall(function()
            local eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
            local moving = false
            if eng then
                moving = (eng.Active and not eng.Active.dead) or false
                if not moving and eng.Movers then
                    for _, m in pairs(eng.Movers) do if m and not m.dead then moving = true break end end
                end
            end
            local ch = plr.Character
            local hum = ch and ch:FindFirstChildOfClass("Humanoid")
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if __DIO_Block and __DIO_Block.Parent ~= workspace then __DIO_Block.Parent = workspace end
            if __DIO_Block and hrp then __DIO_Block.CFrame = hrp.CFrame end
            -- FIX highlight: chi giu highlight khi co hoat dong THAT:
            -- (1) dang FlyTo, (2) engine dang co mover chay, hoac (3) feature BAT va DANG ra lenh _tp moi (<= 12s).
            -- Het canh: toggle bat lau nhung ke/tre -> highlight "vo dung" treo mai,
            -- va highlight tao lien tuc khi khong con gi can tween.
            local __hlIntent = false
            if __DIO_FlyBusy == true or moving then
                __hlIntent = true
            elseif (type(__DIO_AnyFeatureOn) == "function" and __DIO_AnyFeatureOn())
               and (type(__DIO_MoveFresh) == "function" and __DIO_MoveFresh()) then
                __hlIntent = true
            end
            local want = __hlIntent and (tick() - (__DIO_BootT0 or 0)) > 5
            if want ~= __DIO_LastHlWant then
                __DIO_LastHlWant = want
                __DIO_HlSync(want)
            elseif want then
                __DIO_HlSync(true)
            end
            if want and ch and not (hum and hum.Sit) and eng and eng.SetNoClip then
                eng.SetNoClip(ch, true)
            else
                local bc = hrp and hrp:FindFirstChild("BodyClip")
                if bc then bc:Destroy() end
            end
        end)
    end
end)
QuestB = function()
				if World1 then
					if _G.FindBoss == "The Gorilla King" then
						bMon = "The Gorilla King"
						Qname = "JungleQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(-1601.6553955078, 36.85213470459, 153.38809204102)
						PosB = CFrame.new(-1088.75977, 8.13463783, -488.559906, -0.707134247, 0, 0.707079291, 0, 1, 0, -0.707079291, 0, -0.707134247)
					elseif _G.FindBoss == "Bobby" then
						bMon = "Bobby"
						Qname = "BuggyQuest1"
						Qdata = 3;
						PosQBoss = CFrame.new(-1140.1761474609, 4.752049446106, 3827.4057617188)
						PosB = CFrame.new(-1087.3760986328, 46.949409484863, 4040.1462402344)
					elseif _G.FindBoss == "The Saw" then
						bMon = "The Saw"
						PosB = CFrame.new(-784.89715576172, 72.427383422852, 1603.5822753906)
					elseif _G.FindBoss == "Yeti" then
						bMon = "Yeti"
						Qname = "SnowQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(1386.8073730469, 87.272789001465, -1298.3576660156)
						PosB = CFrame.new(1218.7956542969, 138.01184082031, -1488.0262451172)
					elseif _G.FindBoss == "Mob Leader" then
						bMon = "Mob Leader"
						PosB = CFrame.new(-2844.7307128906, 7.4180502891541, 5356.6723632813)
					elseif _G.FindBoss == "Vice Admiral" then
						bMon = "Vice Admiral"
						Qname = "MarineQuest2"
						Qdata = 2;
						PosQBoss = CFrame.new(-5036.2465820313, 28.677835464478, 4324.56640625)
						PosB = CFrame.new(-5006.5454101563, 88.032081604004, 4353.162109375)
					elseif _G.FindBoss == "Saber Expert" then
						bMon = "Saber Expert"
						PosB = CFrame.new(-1458.89502, 29.8870335, -50.633564)
					elseif _G.FindBoss == "Warden" then
						bMon = "Warden"
						Qname = "ImpelQuest"
						Qdata = 1;
						PosB = CFrame.new(5278.04932, 2.15167475, 944.101929, 0.220546961, -4.49946401e-06, 0.975376427, -1.95412576e-05, 1, 9.03162072e-06, -0.975376427, -2.10519756e-05, 0.220546961)
						PosQBoss = CFrame.new(5191.86133, 2.84020686, 686.438721, -0.731384635, 0, 0.681965172, 0, 1, 0, -0.681965172, 0, -0.731384635)
					elseif _G.FindBoss == "Chief Warden" then
						bMon = "Chief Warden"
						Qname = "ImpelQuest"
						Qdata = 2;
						PosB = CFrame.new(5206.92578, 0.997753382, 814.976746, 0.342041343, -0.00062915677, 0.939684749, 0.00191645394, 0.999998152, -2.80422337e-05, -0.939682961, 0.00181045406, 0.342041939)
						PosQBoss = CFrame.new(5191.86133, 2.84020686, 686.438721, -0.731384635, 0, 0.681965172, 0, 1, 0, -0.681965172, 0, -0.731384635)
					elseif _G.FindBoss == "Swan" then
						bMon = "Swan"
						Qname = "ImpelQuest"
						Qdata = 3;
						PosB = CFrame.new(5325.09619, 7.03906584, 719.570679, -0.309060812, 0, 0.951042235, 0, 1, 0, -0.951042235, 0, -0.309060812)
						PosQBoss = CFrame.new(5191.86133, 2.84020686, 686.438721, -0.731384635, 0, 0.681965172, 0, 1, 0, -0.681965172, 0, -0.731384635)
					elseif _G.FindBoss == "Magma Admiral" then
						bMon = "Magma Admiral"
						Qname = "MagmaQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(-5314.6220703125, 12.262420654297, 8517.279296875)
						PosB = CFrame.new(-5765.8969726563, 82.92064666748, 8718.3046875)
					elseif _G.FindBoss == "Fishman Lord" then
						bMon = "Fishman Lord"
						Qname = "FishmanQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(61122.65234375, 18.497442245483, 1569.3997802734)
						PosB = CFrame.new(61260.15234375, 30.950881958008, 1193.4329833984)
					elseif _G.FindBoss == "Wysper" then
						bMon = "Wysper"
						Qname = "SkyExp1Quest"
						Qdata = 3;
						PosQBoss = CFrame.new(-7861.947265625, 5545.517578125, -379.85974121094)
						PosB = CFrame.new(-7866.1333007813, 5576.4311523438, -546.74816894531)
					elseif _G.FindBoss == "Thunder God" then
						bMon = "Thunder God"
						Qname = "SkyExp2Quest"
						Qdata = 3;
						PosQBoss = CFrame.new(-7903.3828125, 5635.9897460938, -1410.923828125)
						PosB = CFrame.new(-7994.984375, 5761.025390625, -2088.6479492188)
					elseif _G.FindBoss == "Cyborg" then
						bMon = "Cyborg"
						Qname = "FountainQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(5258.2788085938, 38.526931762695, 4050.044921875)
						PosB = CFrame.new(6094.0249023438, 73.770050048828, 3825.7348632813)
					elseif _G.FindBoss == "Ice Admiral" then
						bMon = "Ice Admiral"
						Qdata = nil;
						PosQBoss = CFrame.new(1266.08948, 26.1757946, -1399.57678, -0.573599219, 0, -0.81913656, 0, 1, 0, 0.81913656, 0, -0.573599219)
						PosB = CFrame.new(1266.08948, 26.1757946, -1399.57678, -0.573599219, 0, -0.81913656, 0, 1, 0, 0.81913656, 0, -0.573599219)
					elseif _G.FindBoss == "Greybeard" then
						bMon = "Greybeard"
						Qdata = nil;
						PosQBoss = CFrame.new(-5081.3452148438, 85.221641540527, 4257.3588867188)
						PosB = CFrame.new(-5081.3452148438, 85.221641540527, 4257.3588867188)
					end
				end;
				if World2 then
					if _G.FindBoss == "Diamond" then
						bMon = "Diamond"
						Qname = "Area1Quest"
						Qdata = 3;
						PosQBoss = CFrame.new(-427.5666809082, 73.313781738281, 1835.4208984375)
						PosB = CFrame.new(-1576.7166748047, 198.59265136719, 13.724286079407)
					elseif _G.FindBoss == "Jeremy" then
						bMon = "Jeremy"
						Qname = "Area2Quest"
						Qdata = 3;
						PosQBoss = CFrame.new(636.79943847656, 73.413787841797, 918.00415039063)
						PosB = CFrame.new(2006.9261474609, 448.95666503906, 853.98284912109)
					elseif _G.FindBoss == "Orbitus" then
						bMon = "Orbitus"
						Qname = "MarineQuest3"
						Qdata = 3;
						PosQBoss = CFrame.new(-2441.986328125, 73.359344482422, -3217.5324707031)
						PosB = CFrame.new(-2172.7399902344, 103.32216644287, -4015.025390625)
					elseif _G.FindBoss == "Don Swan" then
						bMon = "Don Swan"
						PosB = CFrame.new(2286.2004394531, 15.177839279175, 863.8388671875)
					elseif _G.FindBoss == "Smoke Admiral" then
						bMon = "Smoke Admiral"
						Qname = "IceSideQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(-5429.0473632813, 15.977565765381, -5297.9614257813)
						PosB = CFrame.new(-5275.1987304688, 20.757257461548, -5260.6669921875)
					elseif _G.FindBoss == "Awakened Ice Admiral" then
						bMon = "Awakened Ice Admiral"
						Qname = "FrostQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(5668.9780273438, 28.519989013672, -6483.3520507813)
						PosB = CFrame.new(6403.5439453125, 340.29766845703, -6894.5595703125)
					elseif _G.FindBoss == "Tide Keeper" then
						bMon = "Tide Keeper"
						Qname = "ForgottenQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(-3053.9814453125, 237.18954467773, -10145.0390625)
						PosB = CFrame.new(-3795.6423339844, 105.88877105713, -11421.307617188)
					elseif _G.FindBoss == "Darkbeard" then
						bMon = "Darkbeard"
						Qdata = nil;
						PosQBoss = CFrame.new(3677.08203125, 62.751937866211, -3144.8332519531)
						PosB = CFrame.new(3677.08203125, 62.751937866211, -3144.8332519531)
					elseif _G.FindBoss == "Cursed Captain" then
						bMon = "Cursed Captain"
						Qdata = nil;
						PosQBoss = CFrame.new(916.928589, 181.092773, 33422)
						PosB = CFrame.new(916.928589, 181.092773, 33422)
					elseif _G.FindBoss == "Order" then
						bMon = "Order"
						Qdata = nil;
						PosQBoss = CFrame.new(-6217.2021484375, 28.047645568848, -5053.1357421875)
						PosB = CFrame.new(-6217.2021484375, 28.047645568848, -5053.1357421875)
					end
				end;
				if World3 then
					if _G.FindBoss == "Stone" then
						bMon = "Stone"
						Qname = "PiratePortQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(-289.76705932617, 43.819011688232, 5579.9384765625)
						PosB = CFrame.new(-1027.6512451172, 92.404174804688, 6578.8530273438)
					elseif _G.FindBoss == "Hydra Leader" then
						bMon = "Hydra Leader"
						Qname = "VenomCrewQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(5211.021484375, 1004.35778859375, 758.1847534179688)
						PosB = CFrame.new(5821.89794921875, 1019.0950927734375, -73.71923065185547)
					elseif _G.FindBoss == "Kilo Admiral" then
						bMon = "Kilo Admiral"
						Qname = "MarineTreeIsland"
						Qdata = 3;
						PosQBoss = CFrame.new(2179.3010253906, 28.731239318848, -6739.9741210938)
						PosB = CFrame.new(2764.2233886719, 432.46154785156, -7144.4580078125)
					elseif _G.FindBoss == "Captain Elephant" then
						bMon = "Captain Elephant"
						Qname = "DeepForestIsland"
						Qdata = 3;
						PosQBoss = CFrame.new(-13232.682617188, 332.40396118164, -7626.01171875)
						PosB = CFrame.new(-13376.7578125, 433.28689575195, -8071.392578125)
					elseif _G.FindBoss == "Beautiful Pirate" then
						bMon = "Beautiful Pirate"
						Qname = "DeepForestIsland2"
						Qdata = 3;
						PosQBoss = CFrame.new(-12682.096679688, 390.88653564453, -9902.1240234375)
						PosB = CFrame.new(5283.609375, 22.56223487854, -110.78285217285)
					elseif _G.FindBoss == "Cake Queen" then
						bMon = "Cake Queen"
						Qname = "IceCreamIslandQuest"
						Qdata = 3;
						PosQBoss = CFrame.new(-819.376709, 64.9259796, -10967.2832, -0.766061664, 0, 0.642767608, 0, 1, 0, -0.642767608, 0, -0.766061664)
						PosB = CFrame.new(-678.648804, 381.353943, -11114.2012, -0.908641815, 0.00149294338, 0.41757378, 0.00837114919, 0.999857843, 0.0146408929, -0.417492568, 0.0167988986, -0.90852499)
					elseif _G.FindBoss == "Longma" then
						bMon = "Longma"
						Qdata = nil;
						PosQBoss = CFrame.new(-10238.875976563, 389.7912902832, -9549.7939453125)
						PosB = CFrame.new(-10238.875976563, 389.7912902832, -9549.7939453125)
					elseif _G.FindBoss == "Soul Reaper" then
						bMon = "Soul Reaper"
						Qdata = nil;
						PosQBoss = CFrame.new(-9524.7890625, 315.80429077148, 6655.7192382813)
						PosB = CFrame.new(-9524.7890625, 315.80429077148, 6655.7192382813)
					end
				end
			end
			QuestBeta = function()
				QuestB()
				return {
					[0] = _G.FindBoss,
					[1] = bMon,
					[2] = Qdata,
					[3] = Qname,
					[4] = PosB,
					[5] = PosQBoss,
				}
			end
__DIO_BOOT("Load Hub 67%")
local Quests, GuideModule
do
    local rs = __SVC_RS
    local okQ, resQ = pcall(function()
        local m = rs:WaitForChild("Quests", 10)
        return m and require(m)
    end)
    Quests = okQ and resQ or nil
    local okG, resG = pcall(function()
        local m = rs:WaitForChild("GuideModule", 10)
        return m and require(m)
    end)
    GuideModule = okG and resG or nil
    if not Quests or not GuideModule then
        warn("[DIO] Thieu module game (Quests/GuideModule) - co the do Blox Fruits Update 30 doi cau truc. UI van chay, rieng phan Quest tu dong co the khong hoat dong.")
    end
end
local blacklistquest = {
    "MarineQuest",
    "BartiloQuest",
    "CitizenQuest",
    "Trainees"
}
CheckSea = function(b)
    if (game.PlaceId == 2753915549 or game.PlaceId == 85211729168715) and b == 1 then
        return true
    elseif (game.PlaceId == 4442272183 or game.PlaceId == 79091703265657) and b == 2 then
        return true
    elseif (game.PlaceId == 7449423635 or game.PlaceId == 100117331123089) and b == 3 then
        return true
    end
    return false
end
GetQuestPointFromNPC = function(npcName)
    for _, npc in pairs(workspace.NPCs:GetChildren()) do
        if npc.Name == npcName and npc:FindFirstChild("HumanoidRootPart") then
            return npc.HumanoidRootPart.CFrame
        end
    end
    for _, npc in pairs(replicated.NPCs:GetChildren()) do
        if npc.Name == npcName and npc:FindFirstChild("HumanoidRootPart") then
            return npc.HumanoidRootPart.CFrame
        end
    end
    return nil
end
GetQuests = function()
    local lvl = plr.Data.Level.Value
    local LevelReq = 0
    local mmb = {}
    if lvl >= 700 and CheckSea(1) then
        mmb["Mob"] = "Galley Captain"
        mmb["NameQuest"] = "FountainQuest"
        mmb["ID"] = 2
        mmb["LevelReq"] = 700
    elseif lvl >= 1500 and CheckSea(2) then
        mmb["Mob"] = "Water Fighter"
        mmb["NameQuest"] = "ForgottenQuest"
        mmb["ID"] = 2
        mmb["LevelReq"] = 1450
    else
        for r, v in pairs(Quests) do
            for id, v1 in pairs(v) do
                local LvReq = v1.LevelReq
                for nguoi, tinh in pairs(v1.Task) do
                    if lvl >= LvReq and LevelReq <= LvReq and v1.Task[nguoi] > 1 and not table.find(blacklistquest, r) then
                        LevelReq = LvReq
                        mmb["Mob"] = nguoi
                        mmb["NameQuest"] = r
                        mmb["ID"] = id
                        mmb["LevelReq"] = LvReq
                    end
                end
            end
        end
    end
    return mmb
end
GetQuestPoint = function()
    if GuideModule and GuideModule.Data and GuideModule.Data.LastClosestNPC then
        return GetQuestPointFromNPC(GuideModule.Data.LastClosestNPC)
    end
    return nil
end
MaterialMon=function()local a=game.Players.LocalPlayer;local b=a.Character and a.Character:FindFirstChild("HumanoidRootPart")if not b then return end;shouldRequestEntrance=function(c,d)local e=(b.Position-c).Magnitude;if e>=d then replicated.Remotes.CommF_:InvokeServer("requestEntrance",c)end end;if World1 then if SelectMaterial=="Angel Wings"then MMon={"Shanda","Royal Squad","Royal Soldier","Wysper","Thunder God"}MPos=CFrame.new(-4698,845,-1912)local c=Vector3.new(-4607.82275,872.54248,-1667.55688)shouldRequestEntrance(c,10000)elseif SelectMaterial=="Leather + Scrap Metal"then MMon={"Brute","Pirate"}MPos=CFrame.new(-1145,15,4350)elseif SelectMaterial=="Magma Ore"then MMon={"Military Soldier","Military Spy","Magma Admiral"}MPos=CFrame.new(-5815,84,8820)elseif SelectMaterial=="Fish Tail"then MMon={"Fishman Warrior","Fishman Commando","Fishman Lord"}MPos=CFrame.new(61123,19,1569)local c=Vector3.new(61163.8515625,5.342342376708984,1819.7841796875)shouldRequestEntrance(c,17000)end elseif World2 then if SelectMaterial=="Leather + Scrap Metal"then MMon={"Marine Captain"}MPos=CFrame.new(-2010.5059814453125,73.00115966796875,-3326.620849609375)elseif SelectMaterial=="Magma Ore"then MMon={"Magma Ninja","Lava Pirate"}MPos=CFrame.new(-5428,78,-5959)elseif SelectMaterial=="Ectoplasm"then MMon={"Ship Deckhand","Ship Engineer","Ship Steward","Ship Officer"}MPos=CFrame.new(911.35827636719,125.95812988281,33159.5390625)local c=Vector3.new(61163.8515625,5.342342376708984,1819.7841796875)shouldRequestEntrance(c,18000)elseif SelectMaterial=="Mystic Droplet"then MMon={"Water Fighter"}MPos=CFrame.new(-3385,239,-10542)elseif SelectMaterial=="Radioactive Material"then MMon={"Factory Staff"}MPos=CFrame.new(295,73,-56)elseif SelectMaterial=="Vampire Fang"then MMon={"Vampire"}MPos=CFrame.new(-6033,7,-1317)end elseif World3 then if SelectMaterial=="Scrap Metal"then MMon={"Jungle Pirate","Forest Pirate"}MPos=CFrame.new(-11975.78515625,331.7734069824219,-10620.0302734375)elseif SelectMaterial=="Fish Tail"then MMon={"Fishman Raider","Fishman Captain"}MPos=CFrame.new(-10993,332,-8940)elseif SelectMaterial=="Conjured Cocoa"then MMon={"Chocolate Bar Battler","Cocoa Warrior"}MPos=CFrame.new(620.6344604492188,78.93644714355469,-12581.369140625)elseif SelectMaterial=="Dragon Scale"then MMon={"Dragon Crew Archer","Dragon Crew Warrior"}MPos=CFrame.new(6594,383,139)elseif SelectMaterial=="Gunpowder"then MMon={"Pistol Billionaire"}MPos=CFrame.new(-84.8556900024414, 85.62061309814453, 6132.0087890625)elseif SelectMaterial=="Mini Tusk"then MMon={"Mythological Pirate"}MPos=CFrame.new(-13545,470,-6917)elseif SelectMaterial=="Demonic Wisp"then MMon={"Demonic Soul"}MPos=CFrame.new(-9495.6806640625,453.58624267578125,5977.3486328125)end end end
QuestNeta = function()
    local questData = GetQuests()
    return {
        [1] = questData.Mob,
        [2] = questData.ID,
        [3] = questData.NameQuest,
        [4] = questData.LevelReq,
        [5] = questData.Mob,
        [6] = GetQuestPoint()
    }
end
__DIO_BOOT("Load Hub 80%")
local redzlib, __DIO_libErr
for _, __DIO_libURL in ipairs({
    "https://raw.githubusercontent.com/huw8592-rgb181816aajbbvaa838377hbba/Script-----------------/refs/heads/main/Library-Redz-Pulic-Source.lua",
    "https://cdn.jsdelivr.net/gh/DIO482/Script-@main/Library-Redz-Pulic-Source.txt",
}) do
    local __ok, __res = pcall(function()
        return loadstring(game:HttpGet(__DIO_libURL))()
    end)
    if __ok and __res ~= nil then
        redzlib = __res
        break
    end
    __DIO_libErr = "[" .. tostring(__DIO_libURL:match("https?://([^/]+)")) .. "] " .. tostring(__res)
end
if redzlib == nil then
    local __msg = "Khong tai duoc Library! Doi DNS 1.1.1.1 / doi mang roi chay lai.\nChi tiet: " .. tostring(__DIO_libErr)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "DIO Hub - Loi tai Library",
            Text = __msg:sub(1, 250),
            Duration = 12,
        })
    end)
    pcall(function()
        local __pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        local __sg = Instance.new("ScreenGui")
        __sg.Name = "DIO_LibError"
        __sg.ResetOnSpawn = false
        __sg.Parent = __pg
        local __fr = Instance.new("TextButton")
        __fr.Size = UDim2.fromOffset(420, 150)
        __fr.Position = UDim2.new(0.5, -210, 0.4, -75)
        __fr.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        __fr.TextColor3 = Color3.fromRGB(255, 120, 120)
        __fr.TextSize = 14
        __fr.TextWrapped = true
        __fr.Font = Enum.Font.Code
        __fr.Text = "DIO HUB - LIBRARY LOAD FAILED (bam de tat)\n\n" .. __msg
        __fr.Parent = __sg
        __fr.MouseButton1Click:Connect(function()
            __sg:Destroy()
        end)
    end)
    error("[DIO] redzlib load failed: " .. tostring(__DIO_libErr))
end
local Window = redzlib:MakeWindow({
    Title = "DIO Hub ",
    SubTitle = "DIO Loader Script | Blox Fruit",
    SaveFolder = "dio.json"
})
__DIO_TNotify = function(title, content, dur)
    if getgenv().DIO_ToggleNotify ~= true then return end
    pcall(function()
        Window:Notify({ Title = tostring(title), Content = tostring(content), Duration = tonumber(dur) or 3 })
    end)
end
local Minimizer = Window:NewMinimizer({
  KeyCode = Enum.KeyCode.LeftControl
})
Minimizer:CreateMobileMinimizer({
  Image = "rbxassetid://105848560127717",
  BackgroundColor3 = Color3.fromRGB(0, 255, 254)
})
local Tabs = {
    Info = Window:MakeTab({ Title = "Info Discord", Icon = "" }),
    Status = Window:MakeTab({ Title = "Status Server", Icon = "" }),
    Shop = Window:MakeTab({ Title = "Shop", Icon = "" }),
    Travel = Window:MakeTab({ Title = "Local Island", Icon = "" }),
    Settings = Window:MakeTab({ Title = "Setting", Icon = "" }),
    Main = Window:MakeTab({ Title = "Farming", Icon = "" }),
    Quests = Window:MakeTab({ Title = "Other And Item", Icon = "" }),
    SeaEvent = Window:MakeTab({ Title = "Sea Event", Icon = "" }),
    Race = Window:MakeTab({ Title = "Update Race", Icon = "" }),
    Prehistoric = Window:MakeTab({ Title = "Dojo and Draco", Icon = "" }),
    Raids = Window:MakeTab({ Title = "Fruit And Raid", Icon = "" }),
    Esp = Window:MakeTab({ Title = "Stats And Esp", Icon = "" }),
    Fish = Window:MakeTab({ Title = "Fishing", Icon = "" }),
    Combat = Window:MakeTab({ Title = "PvP", Icon = "" }),
    Webhook = Window:MakeTab({ Title = "Webhook Notify", Icon = "" }),
    Misc = Window:MakeTab({ Title = "Misc", Icon = "" })
}

do
    local function __DIO_IsInstance(o)
        if o == nil or type(o) ~= "table" then return false end
        if typeof ~= nil then
            local ok, t = pcall(typeof, o)
            if ok and t == "Instance" then return true end
        end
        return o.IsA ~= nil and o.ClassName ~= nil and type(o.GetChildren) == "function"
    end

    local function __DIO_CallBacks(self, v)
        local list = self.CALLBACKS or self.Callbacks
        if type(list) == "table" then
            for _, fn in ipairs(list) do
                if type(fn) == "function" then pcall(fn, v) end
            end
        end
        if type(self.Callback) == "function" then pcall(self.Callback, v) end
    end

    local function __DIO_TabContainer(tab)
        if type(tab) ~= "table" then return nil end
        local direct = rawget(tab, "Container")
        if __DIO_IsInstance(direct) then return direct end
        local root = rawget(tab, "Parent") or rawget(tab, "WindowFrame") or rawget(tab, "MainFrame")
        if not __DIO_IsInstance(root) then return nil end
        local ok, list = pcall(function() return root:GetDescendants() end)
        if not ok then return nil end
        for _, d in ipairs(list or {}) do
            local okIs, isScroll = pcall(function() return d:IsA("ScrollingFrame") end)
            if okIs and isScroll then return d end
        end
        return nil
    end

    local function __DIO_FallbackRow(tab, kind, cfg)
        cfg = type(cfg) == "table" and cfg or {}
        local self = {
            Kind = kind,
            Title = tostring(cfg.Name or cfg.Title or ""),
            Description = tostring(cfg.Desc or cfg.Description or cfg.Content or ""),
            Value = cfg.Default,
            Callbacks = type(cfg.Callback) == "function" and { cfg.Callback } or nil,
            Dummy = true,
        }
        local holder = __DIO_TabContainer(tab)
        if not __DIO_IsInstance(holder) then
            if warn then warn("[DIO] UI compat: khong tim thay container cua tab -> bo qua element " .. tostring(self.Title)) end
            return self
        end

        local row, titleLabel, valueLabel
        local ok, perr = pcall(function()
            row = Instance.new("Frame")
            row.Name = self.Title ~= "" and self.Title or ("DIO_" .. kind)
            row.Size = UDim2.new(1, 0, 0, 26)
            row.BackgroundTransparency = 0.25
            row.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
            row.Parent = holder

            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 8)
            corner.Parent = row

            titleLabel = Instance.new("TextLabel")
            titleLabel.BackgroundTransparency = 1
            titleLabel.Position = UDim2.new(0, 10, 0, 0)
            titleLabel.Size = UDim2.new(0.42, 0, 1, 0)
            titleLabel.TextXAlignment = Enum.TextXAlignment.Left
            titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
            titleLabel.Font = Enum.Font.GothamMedium
            titleLabel.TextSize = 11
            titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            titleLabel.Text = self.Title
            titleLabel.Parent = row

            valueLabel = Instance.new("TextLabel")
            valueLabel.BackgroundTransparency = 1
            valueLabel.Position = UDim2.new(0.45, 0, 0, 0)
            valueLabel.Size = UDim2.new(0.53, -10, 1, 0)
            valueLabel.TextXAlignment = Enum.TextXAlignment.Right
            valueLabel.TextTruncate = Enum.TextTruncate.AtEnd
            valueLabel.Font = Enum.Font.Gotham
            valueLabel.TextSize = 10
            valueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            valueLabel.Text = self.Description
            valueLabel.Parent = row
        end)
        if not ok or row == nil then
            if warn then warn("[DIO] UI compat: bo qua element " .. tostring(self.Title) .. " (" .. tostring(perr) .. ")") end
            return self
        end

        self.DESTROY_ELEMENT = row
        self.VISIBLE_ELEMENT = row
        self._ROW = row
        self.TITLE_LABEL = titleLabel
        self.DESCRIPTION_LABEL = valueLabel

        local function paint()
            pcall(function()
                if kind == "Toggle" then
                    valueLabel.Text = (self.Value == true) and "ON" or "OFF"
                    valueLabel.TextColor3 = (self.Value == true) and Color3.fromRGB(120, 255, 150) or Color3.fromRGB(255, 120, 120)
                else
                    valueLabel.Text = tostring(self.Value or self.Description or "")
                end
            end)
        end

        if kind == "TextBox" then
            pcall(function()
                valueLabel:Destroy()
                local box = Instance.new("TextBox")
                box.Position = UDim2.new(0.45, 0, 0.5, 0)
                box.AnchorPoint = Vector2.new(0, 0.5)
                box.Size = UDim2.new(0.55, -12, 0, 18)
                box.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
                box.TextColor3 = Color3.fromRGB(255, 255, 255)
                box.Font = Enum.Font.Gotham
                box.TextSize = 11
                box.TextXAlignment = Enum.TextXAlignment.Left
                box.ClearTextOnFocus = false
                box.PlaceholderText = tostring(cfg.Placeholder or cfg.PlaceholderText or "Input")
                box.Text = tostring(self.Value or "")
                box.Parent = row
                local bc = Instance.new("UICorner")
                bc.CornerRadius = UDim.new(0, 4)
                bc.Parent = box
                self.TEXTBOX = box
                local sig = box:GetPropertyChangedSignal("Text")
                if sig and sig.Connect then
                    sig:Connect(function()
                        self.Value = box.Text
                        __DIO_CallBacks(self, box.Text)
                    end)
                end
                self.SetText = function(s2, t) box.Text = tostring(t or "") return s2 end
                self.Set = self.SetText
                self.CaptureFocus = function(s2) pcall(function() box:CaptureFocus() end) return s2 end
            end)
        elseif kind == "Toggle" or kind == "Button" then
            paint()
            pcall(function()
                local btn = Instance.new("TextButton")
                btn.BackgroundTransparency = 1
                btn.Text = ""
                btn.Size = UDim2.fromScale(1, 1)
                btn.AutoButtonColor = false
                btn.Parent = row
                btn.MouseButton1Click:Connect(function()
                    if kind == "Toggle" then
                        self.Value = not (self.Value == true)
                        paint()
                    end
                    __DIO_CallBacks(self, self.Value)
                end)
            end)
            self.SetValue = function(s2, v)
                self.Value = (v == true)
                paint()
                return s2
            end
            self.Set = self.SetValue
        else
            paint()
        end

        self.SetDesc = function(s2, t)
            self.Description = tostring(t or "")
            pcall(function() valueLabel.Text = self.Description end)
            return s2
        end
        self.SetContent = self.SetDesc
        self.Destroy = function() pcall(function() row:Destroy() end) end
        return self
    end

    for __DIO_tname, __DIO_tab in pairs(Tabs) do
        if type(__DIO_tab) == "table" then

            if type(__DIO_tab.AddTextBox) == "function" then
                local __DIO_realTb = __DIO_tab.AddTextBox
                __DIO_tab.AddInput = function(self, a, b)
                    local cfg, flag
                    if type(a) == "table" then
                        cfg = {}
                        for k, v in pairs(a) do cfg[k] = v end
                    else
                        flag = tostring(a or "Input")
                        cfg = {}
                        if type(b) == "table" then
                            for k, v in pairs(b) do cfg[k] = v end
                        end
                    end

                    if cfg.Title ~= nil then
                        cfg.Name = nil
                    else
                        cfg.Name = flag or cfg.Name or "Input"
                    end
                    if type(cfg.Flag) ~= "string" and flag ~= nil then cfg.Flag = flag end

                    cfg.Numeric = nil
                    cfg.Finished = nil
                    cfg.Description = cfg.Description or ""
                    local ok, res = pcall(__DIO_realTb, self, cfg)
                    if ok then return res end
                    warn("[DIO] AddTextBox loi: " .. tostring(res))
                    return __DIO_FallbackRow(self, "TextBox", cfg)
                end
            else
                __DIO_tab.AddInput = function(self, a, b)
                    local cfg = (type(a) == "table") and a or (type(b) == "table") and b or {}
                    if type(a) ~= "table" and type(b) == "table" then
                        local t2 = {}
                        for k, v in pairs(b) do t2[k] = v end
                        t2.Name = tostring(a or "Input")
                        cfg = t2
                    end
                    return __DIO_FallbackRow(self, "TextBox", cfg)
                end
            end

            if type(__DIO_tab.AddParagraph) == "function" then
                local __DIO_realPara = __DIO_tab.AddParagraph
                __DIO_tab.AddParagraph = function(self, a, b)
                    if type(a) == "table" then
                        return __DIO_realPara(self,
                            tostring(a.Title or a.Name or "Info"),
                            tostring(a.Content or a.Description or a.Text or ""))
                    end
                    return __DIO_realPara(self, a, b)
                end
            else
                __DIO_tab.AddParagraph = function(self, a, b)
                    local cfg = (type(a) == "table") and a
                        or { Title = tostring(a or ""), Content = tostring(b or "") }
                    return __DIO_FallbackRow(self, "Paragraph", {
                        Title = cfg.Title or cfg.Name,
                        Name = cfg.Name or cfg.Title,
                        Content = cfg.Content or cfg.Description,
                        Description = cfg.Description or cfg.Content,
                    })
                end
            end

            if type(__DIO_tab.AddSection) ~= "function" then
                __DIO_tab.AddSection = function(self, a)
                    local title = (type(a) == "table") and tostring(a.Title or a.Name or "") or tostring(a or "")
                    if type(self.AddParagraph) == "function" then
                        local ok, res = pcall(self.AddParagraph, self, { Title = title, Content = "" })
                        if ok then return res end
                    end
                    return __DIO_FallbackRow(self, "Paragraph", { Title = title, Content = "" })
                end
            end
        end
    end
end

__DIO_T = setmetatable({
    ["FIX LAG "] = "FIX LAG ",
    ["Select Weapon"] = "Select Weapon",
    ["UI Scale"] = "UI Scale",
    ["Farm"] = "Farm",
    ["Start Farm"] = "Start Farm",
    ["Auto Factory Raid"] = "Auto Factory Raid",
    ["Auto Random Bones"] = "Auto Random Bones",
    ["Auto Pirate Raid"] = "Auto Pirate Raid",
    ["Auto Farm Ectoplasm"] = "Auto Farm Ectoplasm",
    ["Auto Farm Chest"] = "Auto Farm Chest",
    ["Auto Chest Bypass"] = "Auto Chest Bypass",
    ["Stop Items"] = "Stop Items",
    ["Select Mob"] = "Select Mob",
    ["Auto Kill Mob"] = "Auto Kill Mob",
    ["Select Island"] = "Select Island",
    ["Auto Farm All Island"] = "Auto Farm All Island",
    ["Attack Dough King"] = "Attack Dough King",
    ["Summon Dough King"] = "Summon Dough King",
    ["Hop Find Dough King"] = "Hop Find Dough King",
    ["Choose Material"] = "Choose Material",
    ["Auto Farm Materials"] = "Auto Farm Materials",
    ["Select Boss"] = "Select Boss",
    ["Auto Farm Boss"] = "Auto Farm Boss",
    ["Accept Quests"] = "Accept Quests",
    ["Auto Farm All Boss"] = "Auto Farm All Boss",
    ["Health Farm Mastery"] = "Health Farm Mastery",
    ["Auto Mastery Fruits"] = "Auto Mastery Fruits",
    ["Auto Mastery Gun"] = "Auto Mastery Gun",
    ["Auto Mastery All Sword"] = "Auto Mastery All Sword",
    ["Auto Use Skill Melee/Sword If lag Mob or Ghost Mob"] = "Auto Use Skill Melee/Sword If lag Mob or Ghost Mob",
    ["Tween speed 600 if near"] = "Tween speed 600 if near",
    ["Bring Mobs"] = "Bring Mobs",
    ["Up Y When Low Health"] = "Up Y When Low Health",
    ["Mode Farm"] = "Mode Farm",
    ["Orbit Speed"] = "Orbit Speed",
    ["Orbit Height"] = "Orbit Height",
    ["mobs Bring"] = "mobs Bring",
    ["Bring Distance"] = "Bring Distance",
    ["Farm Distance"] = "Farm Distance",
    ["Speed Tween"] = "Speed Tween",
    ["Auto Summon Cake Prince"] = "Auto Summon Cake Prince",
    ["Auto Set Spawn Point"] = "Auto Set Spawn Point",
    ["Auto Turn on Buso"] = "Auto Turn on Buso",
    ["Auto Haki Observation"] = "Auto Haki Observation",
    ["Auto Turn on Race V3"] = "Auto Turn on Race V3",
    ["Auto Turn on Race V4"] = "Auto Turn on Race V4",
    ["Auto Turn on Spin (x,y,z) "] = "Auto Turn on Spin (x,y,z) ",
    ["Safe Mode"] = "Safe Mode",
    ["Anti AFK"] = "Anti AFK",
    ["Auto Anti - Admin Join Server"] = "Auto Anti - Admin Join Server",
    ["No Clip"] = "No Clip",
    ["Stats Value"] = "Stats Value",
    ["Auto Melee"] = "Auto Melee",
    ["Auto Swords"] = "Auto Swords",
    ["Auto Gun"] = "Auto Gun",
    ["Auto Blox Fruit"] = "Auto Blox Fruit",
    ["Auto Defense"] = "Auto Defense",
    ["Select Fishing Rod"] = "Select Fishing Rod",
    ["Select Bait"] = "Select Bait",
    ["Auto Slap Fishing"] = "Auto Slap Fishing",
    ["Auto Buy Bait"] = "Auto Buy Bait",
    ["Auto Fishing"] = "Auto Fishing",
    ["Auto Quest Fishing"] = "Auto Quest Fishing",
    ["Auto Complete Quest"] = "Auto Complete Quest",
    ["Auto Sell Fish"] = "Auto Sell Fish",
    ["Auto Spam Skill Z"] = "Auto Spam Skill Z",
    ["Auto Quest Sea 2"] = "Auto Quest Sea 2",
    ["Auto Quest Sea 3"] = "Auto Quest Sea 3",
    ["Auto Attack Rip Indra"] = "Auto Attack Rip Indra",
    ["Auto Unlocked Haki"] = "Auto Unlocked Haki",
    ["Auto Soul Reaper"] = "Auto Soul Reaper",
    ["Auto Try Luck Gravestone"] = "Auto Try Luck Gravestone",
    ["Auto Pray Gravestone"] = "Auto Pray Gravestone",
    ["Auto Farm Elite"] = "Auto Farm Elite",
    ["Auto Farm Elite + Hop"] = "Auto Farm Elite + Hop",
    ["Auto Get PlayerQuest"] = "Auto Get PlayerQuest",
    ["Auto Kill Player Quest"] = "Auto Kill Player Quest",
    ["Auto Tushita Sword"] = "Auto Tushita Sword",
    ["Auto Yama Sword"] = "Auto Yama Sword",
    ["Auto Skull Guitar"] = "Auto Skull Guitar",
    ["Auto Farm Material Skull Guitar"] = "Auto Farm Material Skull Guitar",
    ["Auto Get CDK [ Last Quest ]"] = "Auto Get CDK [ Last Quest ]",
    ["Auto Yama CDK"] = "Auto Yama CDK",
    ["Auto Tushita CDK"] = "Auto Tushita CDK",
    ["Buy Legendary Sword"] = "Buy Legendary Sword",
    ["Buy True Triple Katana Sword"] = "Buy True Triple Katana Sword",
    ["Tween to Legendary Sword Dealer"] = "Tween to Legendary Sword Dealer",
    ["Auto Pole V1"] = "Auto Pole V1",
    ["Auto Pole V2 [Beta]"] = "Auto Pole V2 [Beta]",
    ["Auto Saw Sword"] = "Auto Saw Sword",
    ["Auto Saber Sword"] = "Auto Saber Sword",
    ["Auto Cybrog"] = "Auto Cybrog",
    ["Auto Usoap's Hat"] = "Auto Usoap's Hat",
    ["Auto Bisento V2"] = "Auto Bisento V2",
    ["Auto Warden Sword"] = "Auto Warden Sword",
    ["Auto Marine Coat"] = "Auto Marine Coat",
    ["Auto Swan Coat"] = "Auto Swan Coat",
    ["Auto Rengoku Sword"] = "Auto Rengoku Sword",
    ["Auto Key Rengoku"] = "Auto Key Rengoku",
    ["Auto Dragon Trident"] = "Auto Dragon Trident",
    ["Auto Long Sword"] = "Auto Long Sword",
    ["Auto Black Spikey"] = "Auto Black Spikey",
    ["Auto Dark Blade V3"] = "Auto Dark Blade V3",
    ["Auto Midnight Blade"] = "Auto Midnight Blade",
    ["Auto Darkbeard"] = "Auto Darkbeard",
    ["Auto Unlocked DonSwan"] = "Auto Unlocked DonSwan",
    ["Auto Swan Glasses"] = "Auto Swan Glasses",
    ["Auto Bigmom"] = "Auto Bigmom",
    ["Auto Canvendish Sword"] = "Auto Canvendish Sword",
    ["Auto Twin Hooks"] = "Auto Twin Hooks",
    ["Auto Serpent Bow"] = "Auto Serpent Bow",
    ["Auto Lei Accessory"] = "Auto Lei Accessory",
    ["Auto Farm Berry"] = "Auto Farm Berry",
    ["Auto Farm Berry + Hop"] = "Auto Farm Berry + Hop",
    ["Auto Teleport Barista Cousin"] = "Auto Teleport Barista Cousin",
    ["Buy Buso Colors"] = "Buy Buso Colors",
    ["Auto Rainbow Colors"] = "Auto Rainbow Colors",
    ["Accept Rainbow Quest Faster"] = "Accept Rainbow Quest Faster",
    ["Auto Farm Observation"] = "Auto Farm Observation",
    ["Auto Observation V2"] = "Auto Observation V2",
    ["Auto Done Bartilo Quest"] = "Auto Done Bartilo Quest",
    ["Auto Done Citizen Quest"] = "Auto Done Citizen Quest",
    ["Auto Training Dummy"] = "Auto Training Dummy",
    ["Buy  BlackLeg"] = "Buy  BlackLeg",
    ["Buy  Electro"] = "Buy  Electro",
    ["Buy  FishmanKarate"] = "Buy  FishmanKarate",
    ["Buy  DragonClaw"] = "Buy  DragonClaw",
    ["Auto Superhuman"] = "Auto Superhuman",
    ["Auto DeathStep"] = "Auto DeathStep",
    ["Auto Sharkman Karate"] = "Auto Sharkman Karate",
    ["Auto ElectricClaw"] = "Auto ElectricClaw",
    ["Auto DragonTalon"] = "Auto DragonTalon",
    ["Auto Godhuman"] = "Auto Godhuman",
    ["Auto SanguineArt"] = "Auto SanguineArt",
    ["Auto Find Mirage Island"] = "Auto Find Mirage Island",
    ["Esp Mirage Island"] = "Esp Mirage Island",
    ["Auto Tween To Mirage Island"] = "Auto Tween To Mirage Island",
    ["Auto Tween To Highest Point"] = "Auto Tween To Highest Point",
    ["Auto Collect Gear"] = "Auto Collect Gear",
    ["Change Transparency can see"] = "Change Transparency can see",
    ["Auto Tween Advanced Fruit Dealer"] = "Auto Tween Advanced Fruit Dealer",
    ["Auto Collect Mirage Chest"] = "Auto Collect Mirage Chest",
    ["Talk With Stone"] = "Talk With Stone",
    ["Auto Look At Moon"] = "Auto Look At Moon",
    ["Look Moon + Auto V3"] = "Look Moon + Auto V3",
    ["Auto Upgrade Mink"] = "Auto Upgrade Mink",
    ["Auto Upgrade Human"] = "Auto Upgrade Human",
    ["Auto Upgrade Angel"] = "Auto Upgrade Angel",
    ["Auto Upgrade FishMan"] = "Auto Upgrade FishMan",
    ["Auto Pull Lever"] = "Auto Pull Lever",
    ["Auto Train V4"] = "Auto Train V4",
    ["Teleport to Temple of Time"] = "Teleport to Temple of Time",
    ["Teleport to Ancient One"] = "Teleport to Ancient One",
    ["Teleport to Ancient Clock"] = "Teleport to Ancient Clock",
    ["Auto Teleport to Race Doors"] = "Auto Teleport to Race Doors",
    ["Auto Complete Trial Race"] = "Auto Complete Trial Race",
    ["Auto Kill Player After Trial"] = "Auto Kill Player After Trial",
    ["Auto Dojo Trainer"] = "Auto Dojo Trainer",
    ["Auto Dragon Hunter"] = "Auto Dragon Hunter",
    ["Tween To Upgrade Draco Trial"] = "Tween To Upgrade Draco Trial",
    ["Auto Draco (V1)"] = "Auto Draco (V1)",
    ["Auto Draco (V2)"] = "Auto Draco (V2)",
    ["Auto Draco (V3)"] = "Auto Draco (V3)",
    ["Auto Relic Draco Trial [Beta]"] = "Auto Relic Draco Trial [Beta]",
    ["Auto Train Draco v4"] = "Auto Train Draco v4",
    ["Tween to Draco Trials"] = "Tween to Draco Trials",
    ["Swap Draco Race"] = "Swap Draco Race",
    ["Upgrade Dragon Talon With Uzoth"] = "Upgrade Dragon Talon With Uzoth",
    ["Craft Dragonheart"] = "Craft Dragonheart",
    ["Craft Dragonstorm"] = "Craft Dragonstorm",
    ["Craft Dino Hood"] = "Craft Dino Hood",
    ["Craft T-Rex Skull"] = "Craft T-Rex Skull",
    ["Craft Volcanic Magnet"] = "Craft Volcanic Magnet",
    ["Auto Find Prehistoric Island"] = "Auto Find Prehistoric Island",
    ["Auto Start Prehistoric Event"] = "Auto Start Prehistoric Event",
    ["Auto Patch Prehistoric Event"] = "Auto Patch Prehistoric Event",
    ["Kill Aura"] = "Kill Aura",
    ["Kill aura Raid and Prehistoric Event"] = "Kill aura Raid and Prehistoric Event",
    ["Auto Collect Dino Bones"] = "Auto Collect Dino Bones",
    ["Auto Collect Dragon Eggs"] = "Auto Collect Dragon Eggs",
    ["Auto Reset When Complete Volcano"] = "Auto Reset When Complete Volcano",
    ["Remove Lighting Effect"] = "Remove Lighting Effect",
    ["Ship Speed Modifier"] = "Ship Speed Modifier",
    ["Ship Speed"] = "Ship Speed",
    ["Auto Press W"] = "Auto Press W",
    ["No Clip Ship"] = "No Clip Ship",
    ["Boat Speed Tween"] = "Boat Speed Tween",
    ["Select Weapon Sea Event"] = "Select Weapon Sea Event",
    ["Select Skill"] = "Select Skill",
    ["Select Boats"] = "Select Boats",
    ["Buy Boats"] = "Buy Boats",
    ["Select Sea Level"] = "Select Sea Level",
    ["Auto Sea Event"] = "Auto Sea Event",
    ["Select Sea Event"] = "Select Sea Event",
    ["Auto Find Kitsune Island"] = "Auto Find Kitsune Island",
    ["Auto Teleport to Shrine Actived"] = "Auto Teleport to Shrine Actived",
    ["Auto Collect Azure Ember"] = "Auto Collect Azure Ember",
    ["Auto Trade Azure Ember"] = "Auto Trade Azure Ember",
    ["Trade Items Azure"] = "Trade Items Azure",
    ["Talk with kitsune statue"] = "Talk with kitsune statue",
    ["Buy Spy"] = "Buy Spy",
    ["Owners Boat Hunter"] = "Owners Boat Hunter",
    ["Tween To Sitting in a boat Owner"] = "Tween To Sitting in a boat Owner",
    ["Friend Hunter Leviathan"] = "Friend Hunter Leviathan",
    ["Fly Boat"] = "Fly Boat",
    ["Teleport Y boat If have Sea Event (ALL)"] = "Teleport Y boat If have Sea Event (ALL)",
    ["Teleport Y boat using a slider"] = "Teleport Y boat using a slider",
    ["Auto Find Frozen Dimension"] = "Auto Find Frozen Dimension",
    ["Auto Teleport Frozen Dimension"] = "Auto Teleport Frozen Dimension",
    ["You Shoot Leviathan Heart"] = "You Shoot Leviathan Heart",
    ["Auto Drive To Hydra Island"] = "Auto Drive To Hydra Island",
    ["Auto Attack Leviathan"] = "Auto Attack Leviathan",
    ["Esp Player"] = "Esp Player",
    ["Esp Chest"] = "Esp Chest",
    ["Esp Fruit"] = "Esp Fruit",
    ["Esp Island"] = "Esp Island",
    ["Esp Legendary Sword"] = "Esp Legendary Sword",
    ["Esp Haki Color"] = "Esp Haki Color",
    ["Esp SeaEvent Island"] = "Esp SeaEvent Island",
    ["Esp Advanced Dealer"] = "Esp Advanced Dealer",
    ["Auto Random Fruit"] = "Auto Random Fruit",
    ["Auto Drop Fruit"] = "Auto Drop Fruit",
    ["Auto Store Fruit"] = "Auto Store Fruit",
    ["Auto Tween to Fruit"] = "Auto Tween to Fruit",
    ["Auto Collect Fruit"] = "Auto Collect Fruit",
    ["Select Fruit Shop"] = "Select Fruit Shop",
    ["Auto Buy Fruit Shop"] = "Auto Buy Fruit Shop",
    ["Select Players"] = "Select Players",
    ["Teleport To Select Players"] = "Teleport To Select Players",
    ["Spectate Select Players"] = "Spectate Select Players",
    ["Select Aim Method"] = "Select Aim Method",
    ["Aimbot Method Skills"] = "Aimbot Method Skills",
    ["Aimbot Camera Closet Players"] = "Aimbot Camera Closet Players",
    ["Auto Enable PvP"] = "Auto Enable PvP",
    ["Auto Safe Mode"] = "Auto Safe Mode",
    ["Attack No Animation"] = "Attack No Animation",
    ["Teleport Y if low health"] = "Teleport Y if low health",
    ["% Health Player"] = "% Health Player",
    ["Distance Teleport Y"] = "Distance Teleport Y",
    ["Will Back When over 10km"] = "Will Back When over 10km",
    ["Auto Repair Ur Ship"] = "Auto Repair Ur Ship",
    ["Enable Fly"] = "Enable Fly",
    ["Speed Fly Mode"] = "Speed Fly Mode",
    ["Dash No Cooldown"] = "Dash No Cooldown",
    ["Instance Mink V3 [ INF ]"] = "Instance Mink V3 [ INF ]",
    ["Instance Energy [ INF ]"] = "Instance Energy [ INF ]",
    ["Instance Soru [ INF ]"] = "Instance Soru [ INF ]",
    ["Instance Observation Range [ INF ]"] = "Instance Observation Range [ INF ]",
    ["Ignore Same Teams"] = "Ignore Same Teams",
    ["Accept Allies"] = "Accept Allies",
    ["Travel East Blue (World 1)"] = "Travel East Blue (World 1)",
    ["Travel Dressrosa (World 2)"] = "Travel Dressrosa (World 2)",
    ["Travel Zou (World 3)"] = "Travel Zou (World 3)",
    ["Select Travelling"] = "Select Travelling",
    ["Auto Travel"] = "Auto Travel",
    ["Select NPCs"] = "Select NPCs",
    ["Auto Tween to NPC"] = "Auto Tween to NPC",
    ["Buy Buso"] = "Buy Buso",
    ["Buy Geppo"] = "Buy Geppo",
    ["Buy Soru"] = "Buy Soru",
    ["Buy Ken"] = "Buy Ken",
    ["Buy Tomoe Ring"] = "Buy Tomoe Ring",
    ["Buy Black Cape"] = "Buy Black Cape",
    ["Buy Swordsman Hat"] = "Buy Swordsman Hat",
    ["Buy Bizarre Rifle"] = "Buy Bizarre Rifle",
    ["Buy Ghoul Mask"] = "Buy Ghoul Mask",
    ["Buy Cutlass"] = "Buy Cutlass",
    ["Buy Katana"] = "Buy Katana",
    ["Buy Iron Mace"] = "Buy Iron Mace",
    ["Buy Duel Katana"] = "Buy Duel Katana",
    ["Buy Triple Katana"] = "Buy Triple Katana",
    ["Buy Pipe"] = "Buy Pipe",
    ["Buy Dual-Headed Blade"] = "Buy Dual-Headed Blade",
    ["Buy Bisento"] = "Buy Bisento",
    ["Buy Soul Cane"] = "Buy Soul Cane",
    ["Buy Slingshot"] = "Buy Slingshot",
    ["Buy Musket"] = "Buy Musket",
    ["Buy Dual Flintlock"] = "Buy Dual Flintlock",
    ["Buy Flintlock"] = "Buy Flintlock",
    ["Buy Refined Flintlock"] = "Buy Refined Flintlock",
    ["Buy Cannon"] = "Buy Cannon",
    ["Buy Kabucha"] = "Buy Kabucha",
    ["Buy Refund Stats"] = "Buy Refund Stats",
    ["Buy Reroll Race"] = "Buy Reroll Race",
    ["Buy Ghoul Race"] = "Buy Ghoul Race",
    ["Buy Cyborg Race (2.5k)"] = "Buy Cyborg Race (2.5k)",
    ["Craft SharkTooth"] = "Craft SharkTooth",
    ["Craft TerrorJaw"] = "Craft TerrorJaw",
    ["Craft SharkAnchor"] = "Craft SharkAnchor",
    ["Craft LeviathanCrown"] = "Craft LeviathanCrown",
    ["Craft LeviathanShield"] = "Craft LeviathanShield",
    ["Craft LeviathanBoat"] = "Craft LeviathanBoat",
    ["Craft LegendaryScroll"] = "Craft LegendaryScroll",
    ["Craft MythicalScroll"] = "Craft MythicalScroll",
    ["Redeem All Codes"] = "Redeem All Codes",
    ["Rejoin Server"] = "Rejoin Server",
    ["Hop Server"] = "Hop Server",
    ["Hop to Lowest Players"] = "Hop to Lowest Players",
    ["Hop to Lowest Pings Server"] = "Hop to Lowest Pings Server",
    ["Input Job Id"] = "Input Job Id",
    ["Teleport [Job ID]"] = "Teleport [Job ID]",
    ["Copy JobID"] = "Copy JobID",
    ["Open Awakenings Expert"] = "Open Awakenings Expert",
    ["Open Title Selection"] = "Open Title Selection",
    ["Disable Chat GUI"] = "Disable Chat GUI",
    ["Disable Leader Board GUI"] = "Disable Leader Board GUI",
    ["Set Pirate Team"] = "Set Pirate Team",
    ["Set Marine Team"] = "Set Marine Team",
    ["Unlock All Portals"] = "Unlock All Portals",
    ["Select Haki States"] = "Select Haki States",
    ["ChangeBusoStage"] = "ChangeBusoStage",
    ["Turn on RTX Mode"] = "Turn on RTX Mode",
    ["Turn on Fast Mode"] = "Turn on Fast Mode",
    ["Turn on Low CPU"] = "Turn on Low CPU",
    ["Turn on increase Boats"] = "Turn on increase Boats",
    ["No Fog"] = "No Fog",
    ["Turn on Full Bright"] = "Turn on Full Bright",
    ["Remove Hit VFX"] = "Remove Hit VFX",
    ["Remove Death & Respawned VFX"] = "Remove Death & Respawned VFX",
    ["Disable Notify"] = "Disable Notify",
    ["Input Url Webhook"] = "Input Url Webhook",
    ["Input Discord Ping (Everyone/ID)"] = "Input Discord Ping (Everyone/ID)",
    ["Ping Everyone/Id Discord"] = "Ping Everyone/Id Discord",
    ["Webhook Store Fruit"] = "Webhook Store Fruit",
    ["Webhook Find Prehistoric Island"] = "Webhook Find Prehistoric Island",
    ["Webhook Find Leviathan"] = "Webhook Find Leviathan",
    ["Webhook Find Mirage"] = "Webhook Find Mirage",
    ["Turn on Walk on Water"] = "Turn on Walk on Water",
    ["Turn on Ice Walk"] = "Turn on Ice Walk",
}, { __index = function(_, k) return k end })
__DIO_BOOT("Load Hub 99%...")
-- FIX: bang TINH toggle -> _G. flag (sinh tu source). Wrapper dung bang nay de biet CHINH XAC
-- toggle nao dieu khien flag nao (ke ca khi flag da true tu truoc -> truoc day khong nhan ra
-- -> tat toggle khong xoa duoc flag / bat toggle khong dang ky owner -> bug "treo").
__DIO_ToggleFlagMap = {
    ["UI/Combat/Accept Allies"] = { "AcceptAlly" },
    ["UI/Combat/Aimbot Camera Closet Players"] = { "AimCam" },
    ["UI/Combat/Aimbot Method Skills"] = { "AimMethod" },
    ["UI/Combat/Auto Enable PvP"] = { "AutoPvP" },
    ["UI/Combat/Auto Safe Mode"] = { "SafeMode" },
    ["UI/Combat/Teleport Y if low health"] = { "LowHpTpY" },
    ["UI/Combat/Dash No Cooldown"] = { "DodgeNoCD" },
    ["UI/Combat/Ignore Same Teams"] = { "NoAimTeam" },
    ["UI/Combat/Instance Observation Range [ INF ]"] = { "InfiniteObRange" },
    ["UI/Combat/Instance Soru [ INF ]"] = { "InfSoru" },
    ["UI/Combat/Teleport To Select Players"] = { "TpPly" },
    ["UI/Esp/Auto Blox Fruit"] = { "Auto_DevilFruit" },
    ["UI/Esp/Auto Defense"] = { "Auto_Defense" },
    ["UI/Esp/Auto Gun"] = { "Auto_Gun" },
    ["UI/Esp/Auto Melee"] = { "Auto_Melee" },
    ["UI/Esp/Auto Swords"] = { "Auto_Sword" },
    ["UI/Fish/Auto Buy Bait"] = { "AutoBuyBait" },
    ["UI/Fish/Auto Complete Quest"] = { "AutoQuestComplete" },
    ["UI/Fish/Auto Fishing"] = { "AutoFishing" },
    ["UI/Fish/Auto Quest Fishing"] = { "AutoFishingQuest" },
    ["UI/Fish/Auto Sell Fish"] = { "AutoSellFish" },
    ["UI/Fish/Auto Slap Fishing"] = { "AutoFishSlap" },
    ["UI/Fish/Auto Spam Skill Z"] = { "AutoSkillZ" },
    ["UI/Main/Accept Quests"] = { "AcceptQuestBoss" },
    ["UI/Main/Attack Dough King"] = { "AutoAttackDoughKing" },
    ["UI/Main/Auto Chest Bypass"] = { "AutoChestBP" },
    ["UI/Main/Auto Factory Raid"] = { "AutoFactory" },
    ["UI/Main/Auto Farm All Boss"] = { "AutoFarmAllBoss" },
    ["UI/Main/Auto Farm All Island"] = { "AutoFarmIsland" },
    ["UI/Main/Auto Farm Boss"] = { "FarmBoss" },
    ["UI/Main/Auto Farm Chest"] = { "AutoFarmChest" },
    ["UI/Main/Auto Farm Ectoplasm"] = { "AutoEctoplasm" },
    ["UI/Main/Auto Farm Materials"] = { "AutoMaterial" },
    ["UI/Main/Auto Kill Mob"] = { "AutoKillMob" },
    ["UI/Main/Auto Mastery All Sword"] = { "FarmMastery_S" },
    ["UI/Main/Auto Mastery Fruits"] = { "FarmMastery_Dev" },
    ["UI/Main/Auto Mastery Gun"] = { "FarmMastery_G" },
    ["UI/Main/Auto Pirate Raid"] = { "AutoRaidCastle" },
    ["UI/Main/Auto Quest |Level|Tyrant|Cake|Bone"] = { "AutoQuest" },
    ["UI/Main/Fast Attack Mob"] = { "FastAttackMob" },
    ["UI/Main/Hop Find Dough King"] = { "AutoHopDoughKing" },
    ["UI/Main/Start Farm"] = { "StartFarm" },
    ["UI/Main/Stop Items"] = { "StopWhenChalice" },
    ["UI/Main/Summon Dough King"] = { "AutoSummonDoughKing" },
    ["UI/Misc/Disable Chat GUI"] = { "Rechat" },
    ["UI/Misc/Remove Hit VFX"] = { "DestroyHit" },
    ["UI/Misc/Turn on RTX Mode"] = { "RTXMode" },
    ["UI/Misc/Unlock All Portals"] = { "PortalUnLock" },
    ["UI/Prehistoric/Auto Collect Dino Bones"] = { "Prehis_DB" },
    ["UI/Prehistoric/Auto Collect Dragon Eggs"] = { "Prehis_DE" },
    ["UI/Prehistoric/Auto Dojo Trainer"] = { "Dojoo" },
    ["UI/Prehistoric/Auto Draco (V1)"] = { "DragoV1" },
    ["UI/Prehistoric/Auto Draco (V2)"] = { "AutoFireFlowers" },
    ["UI/Prehistoric/Auto Draco (V3)"] = { "DragoV3" },
    ["UI/Prehistoric/Auto Dragon Hunter"] = { "FarmBlazeEM" },
    ["UI/Prehistoric/Auto Find Prehistoric Island"] = { "Prehis_Find" },
    ["UI/Prehistoric/Auto Patch Prehistoric Event"] = { "Prehis_Skills" },
    ["UI/Prehistoric/Auto Relic Draco Trial [Beta]"] = { "Relic123" },
    ["UI/Prehistoric/Auto Reset When Complete Volcano"] = { "ResetPH" },
    ["UI/Prehistoric/Auto Start Prehistoric Event"] = { "AutoStartPrehistoric" },
    ["UI/Prehistoric/Auto Train Draco v4"] = { "TrainDrago" },
    ["UI/Prehistoric/Craft Volcanic Magnet"] = { "AutoCraftVolcanic" },
    ["UI/Prehistoric/Swap Draco Race"] = { "BuyDrago" },
    ["UI/Prehistoric/Tween To Upgrade Draco Trial"] = { "UPGDrago" },
    ["UI/Prehistoric/Tween to Draco Trials"] = { "TpDrago_Prehis" },
    ["UI/Prehistoric/Upgrade Dragon Talon With Uzoth"] = { "DT_Uzoth" },
    ["UI/Quests/Accept Rainbow Quest Faster"] = { "GetQFast" },
    ["UI/Quests/Auto Attack Rip Indra"] = { "AutoRipIngay" },
    ["UI/Quests/Auto Bigmom"] = { "AutoBigmom" },
    ["UI/Quests/Auto Bisento V2"] = { "Greybeard" },
    ["UI/Quests/Auto Black Spikey"] = { "BlackSpikey" },
    ["UI/Quests/Auto Canvendish Sword"] = { "Auto_Cavender" },
    ["UI/Quests/Auto Cybrog"] = { "AutoColShad" },
    ["UI/Quests/Auto Dark Blade V3"] = { "DarkBladev3" },
    ["UI/Quests/Auto Darkbeard"] = { "Auto_Def_DarkCoat" },
    ["UI/Quests/Auto Done Bartilo Quest"] = { "Bartilo_Quest" },
    ["UI/Quests/Auto Done Citizen Quest"] = { "CitizenQuest" },
    ["UI/Quests/Auto Dragon Trident"] = { "AutoTridentW2" },
    ["UI/Quests/Auto Farm Berry"] = { "AutoBerry" },
    ["UI/Quests/Auto Farm Berry + Hop"] = { "AutoBerryH" },
    ["UI/Quests/Auto Farm Elite"] = { "FarmEliteHunt" },
    ["UI/Quests/Auto Farm Elite + Hop"] = { "FarmEliteH" },
    ["UI/Quests/Auto Farm Material Skull Guitar"] = { "AutoMatSoul" },
    ["UI/Quests/Auto Farm Observation"] = { "obsFarm" },
    ["UI/Quests/Auto Get CDK [ Last Quest ]"] = { "CDK" },
    ["UI/Quests/Auto Get PlayerQuest"] = { "AutoReceivePlayerQuest" },
    ["UI/Quests/Auto Key Rengoku"] = { "KeysRen" },
    ["UI/Quests/Auto Kill Player Quest"] = { "AutoPlayerHunter" },
    ["UI/Quests/Auto Lei Accessory"] = { "AutoKilo" },
    ["UI/Quests/Auto Long Sword"] = { "LongsWord" },
    ["UI/Quests/Auto Marine Coat"] = { "MarinesCoat" },
    ["UI/Quests/Auto Midnight Blade"] = { "AutoEcBoss" },
    ["UI/Quests/Auto Observation V2"] = { "AutoKenVTWO" },
    ["UI/Quests/Auto Pole V1"] = { "AutoPole" },
    ["UI/Quests/Auto Pole V2 [Beta]"] = { "AutoPoleV2" },
    ["UI/Quests/Auto Pray Gravestone"] = { "Praying" },
    ["UI/Quests/Auto Quest Sea 2"] = { "TravelDres" },
    ["UI/Quests/Auto Quest Sea 3"] = { "AutoZou" },
    ["UI/Quests/Auto Rainbow Colors"] = { "Auto_Rainbow_Haki" },
    ["UI/Quests/Auto Random Bones"] = { "Auto_Random_Bone" },
    ["UI/Quests/Auto Rengoku Sword"] = { "IceBossRen" },
    ["UI/Quests/Auto Saber Sword"] = { "AutoSaber" },
    ["UI/Quests/Auto Saw Sword"] = { "AutoSaw" },
    ["UI/Quests/Auto Serpent Bow"] = { "AutoSerpentBow" },
    ["UI/Quests/Auto Skull Guitar"] = { "Auto_Soul_Guitar" },
    ["UI/Quests/Auto Soul Reaper"] = { "AutoHytHallow" },
    ["UI/Quests/Auto Swan Coat"] = { "SwanCoat" },
    ["UI/Quests/Auto Swan Glasses"] = { "Auto_SwanGG" },
    ["UI/Quests/Auto Teleport Barista Cousin"] = { "Tp_MasterA" },
    ["UI/Quests/Auto Training Dummy"] = { "DummyMan" },
    ["UI/Quests/Auto Try Luck Gravestone"] = { "TryLucky" },
    ["UI/Quests/Auto Tushita CDK"] = { "CDK_TS" },
    ["UI/Quests/Auto Tushita Sword"] = { "Auto_Tushita" },
    ["UI/Quests/Auto Twin Hooks"] = { "TwinHook" },
    ["UI/Quests/Auto Unlocked DonSwan"] = { "Auto_DonAcces" },
    ["UI/Quests/Auto Unlocked Haki"] = { "AutoUnHaki" },
    ["UI/Quests/Auto Usoap's Hat"] = { "AutoGetUsoap" },
    ["UI/Quests/Auto Warden Sword"] = { "WardenBoss" },
    ["UI/Quests/Auto Yama CDK"] = { "CDK_YM" },
    ["UI/Quests/Auto Yama Sword"] = { "Auto_Yama" },
    ["UI/Quests/Tween to Legendary Sword Dealer"] = { "Tp_LgS" },
    ["UI/Race/Auto Collect Gear"] = { "TPGEAR" },
    ["UI/Race/Auto Collect Mirage Chest"] = { "FarmChestM" },
    ["UI/Race/Auto Complete Trial Race"] = { "Complete_Trials" },
    ["UI/Race/Auto Find Mirage Island"] = { "FindMirage" },
    ["UI/Race/Auto Kill Player After Trial"] = { "Defeating" },
    ["UI/Race/Auto Pull Lever"] = { "Lver" },
    ["UI/Race/Auto Teleport to Race Doors"] = { "TPDoor" },
    ["UI/Race/Auto Train V4"] = { "AcientOne" },
    ["UI/Race/Auto Tween Advanced Fruit Dealer"] = { "Addealer" },
    ["UI/Race/Auto Tween To Highest Point"] = { "HighestMirage" },
    ["UI/Race/Auto Tween To Mirage Island"] = { "AutoMysticIsland" },
    ["UI/Race/Auto Upgrade Angel"] = { "Auto_Skypiea" },
    ["UI/Race/Auto Upgrade FishMan"] = { "Auto_Fish" },
    ["UI/Race/Auto Upgrade Human"] = { "Auto_Human" },
    ["UI/Race/Auto Upgrade Mink"] = { "Auto_Mink" },
    ["UI/Race/Change Transparency can see"] = { "can" },
    ["UI/Raids/Account Buy Chip"] = { "AccountBuyChip" },
    ["UI/Raids/Account Pick Slot Raid"] = { "AccountPickSlot" },
    ["UI/Raids/Account Start Dungeon"] = { "AccountStartDungeon" },
    ["UI/Raids/Auto Attack Dungeon"] = { "AutoAttackDungeon" },
    ["UI/Raids/Auto Awake Fruit"] = { "AutoAwakeFruit" },
    ["UI/Raids/Auto Buy Chip and Attack Law"] = { "AutoBuyChipAttackLaw" },
    ["UI/Raids/Auto Buy Fruit Shop"] = { "AutoBuyFruitSniper" },
    ["UI/Raids/Auto Collect Fruit"] = { "InstanceF" },
    ["UI/Raids/Auto Drop Fruit"] = { "DropFruit" },
    ["UI/Raids/Auto Join Dungeon"] = { "AutoJoinDungeon" },
    ["UI/Raids/Auto Multi Raid"] = { "AutoMultiRaid" },
    ["UI/Raids/Auto Pick Card Dungeon"] = { "AutoPickCardDungeon" },
    ["UI/Raids/Auto Raid"] = { "AutoRaid" },
    ["UI/Raids/Auto Random Fruit"] = { "Random_Auto" },
    ["UI/Raids/Auto Store Fruit"] = { "StoreF" },
    ["UI/Raids/Auto Tween to Fruit"] = { "TwFruits" },
    ["UI/Raids/Get Fruit In Inventory Low Beli"] = { "GetFruitLowBeli" },
    ["UI/Raids/Hop Sever Raid"] = { "HopSeverRaid" },
    ["UI/SeaEvent/Auto Attack Leviathan"] = { "Leviathan1" },
    ["UI/SeaEvent/Auto Collect Azure Ember"] = { "Collect_Ember" },
    ["UI/SeaEvent/Auto Dodge Skill Seabeast"] = { "AutoDodgeSeabeast" },
    ["UI/SeaEvent/Auto Dodge Skill Terrorshark"] = { "AutoDodgeTerrorshark" },
    ["UI/SeaEvent/Auto Drive To Hydra Island"] = { "SailBoat_Hydra" },
    ["UI/SeaEvent/Auto Find Frozen Dimension"] = { "FrozenDimension" },
    ["UI/SeaEvent/Auto Find Kitsune Island"] = { "AutofindKitIs" },
    ["UI/SeaEvent/Auto Press W"] = { "AutoPressW" },
    ["UI/SeaEvent/Auto Sea Event"] = { "SailBoats" },
    ["UI/SeaEvent/Auto Teleport Frozen Dimension"] = { "FrozenTP" },
    ["UI/SeaEvent/Auto Teleport to Shrine Actived"] = { "tweenShrine" },
    ["UI/SeaEvent/Auto Trade Azure Ember"] = { "Trade_Ember" },
    ["UI/SeaEvent/No Clip Ship"] = { "NoClipShip" },
    ["UI/SeaEvent/Ship Speed Modifier"] = { "SpeedBoat" },
    ["UI/SeaEvent/Teleport Y boat using a slider"] = { "TeleportYSlider" },
    ["UI/SeaEvent/Auto Repair Ur Ship"] = { "AutoRepairShip" },
    ["UI/SeaEvent/Will Back When over 10km"] = { "FindBack10km" },
    ["UI/SeaEvent/Tween To Sitting in a boat Owner"] = { "TweenBoatOwner" },
    ["UI/SeaEvent/You Shoot Leviathan Heart"] = { "ShotHL" },
    ["UI/Settings/Auto Anti - Admin Join Server"] = { "HopServerAdmin" },
    ["UI/Settings/Attack No Animation"] = { "AttackNoAnim" },
    ["UI/Settings/Auto Haki Observation"] = { "Observation" },
    ["UI/Settings/Auto Set Spawn Point"] = { "Set" },
    ["UI/Settings/Auto Summon Cake Prince"] = { "AutoSpawnCP" },
    ["UI/Settings/Auto Turn on Race V3"] = { "RaceClickAutov3" },
    ["UI/Settings/Auto Turn on Race V4"] = { "RaceClickAutov4" },
    ["UI/Settings/Auto Use Skill Melee/Sword If lag Mob or Ghost Mob"] = { "AutoSkillGhost" },
    ["UI/Settings/Dragon Strom Kill aura"] = { "DragonStromKillAura" },
    ["UI/Settings/Kill aura Raid and Prehistoric Event"] = { "KillAuraFull" },
    ["UI/Settings/No Clip"] = { "NoClip" },
    ["UI/Settings/Safe Mode"] = { "Safemode" },
    ["UI/Settings/Turn on Ice Walk"] = { "WalkWater" },
    ["UI/Settings/Turn on Walk on Water"] = { "WalkWater_Part" },
    ["UI/Settings/Tween speed 600 if near"] = { "Neartween" },
    ["UI/Shop/Auto DeathStep"] = { "AutoDeathStep" },
    ["UI/Shop/Auto DragonTalon"] = { "AutoDragonTalon" },
    ["UI/Shop/Auto ElectricClaw"] = { "Auto_Electric_Claw" },
    ["UI/Shop/Auto Godhuman"] = { "Auto_God_Human" },
    ["UI/Shop/Auto SanguineArt"] = { "Snaguine" },
    ["UI/Shop/Auto Sharkman Karate"] = { "Auto_SharkMan_Karate" },
    ["UI/Shop/Auto Superhuman"] = { "Auto_SuperHuman" },
    ["UI/Shop/Buy  BlackLeg"] = { "BuyMelee_BuyBlackLeg" },
    ["UI/Shop/Buy  DeathStep"] = { "BuyMelee_BuyDeathStep" },
    ["UI/Shop/Buy  DragonClaw"] = { "BuyMelee_BuyDragonClaw" },
    ["UI/Shop/Buy  DragonTalon"] = { "BuyMelee_BuyDragonTalon" },
    ["UI/Shop/Buy  ElectricClaw"] = { "BuyMelee_BuyElectricClaw" },
    ["UI/Shop/Buy  Electro"] = { "BuyMelee_BuyElectro" },
    ["UI/Shop/Buy  FishmanKarate"] = { "BuyMelee_BuyFishmanKarate" },
    ["UI/Shop/Buy  Godhuman"] = { "BuyMelee_BuyGodhuman" },
    ["UI/Shop/Buy  SanguineArt"] = { "BuyMelee_BuySanguineArt" },
    ["UI/Shop/Buy  SharkmanKarate"] = { "BuyMelee_BuySharkmanKarate" },
    ["UI/Shop/Buy  Superhuman"] = { "BuyMelee_BuySuperhuman" },
    ["UI/Travel/Auto Tween Island"] = { "Teleport" },
    ["UI/Travel/Auto Tween to NPC"] = { "TPNpc" },
    ["UI/Webhook/Ping Everyone/Id Discord"] = { "PingDiscord" },
    ["UI/Webhook/Webhook Find Leviathan"] = { "WebhookFindLeviathan" },
    ["UI/Webhook/Webhook Find Mirage"] = { "WebhookFindMirage" },
    ["UI/Webhook/Webhook Find Prehistoric Island"] = { "WebhookFindPrehistoric" },
    ["UI/Webhook/Webhook Store Fruit"] = { "WebhookStoreFruit" },
}
__DIO_MapHasFarm = function(list)
    if type(list) ~= "table" then return false end
    for _, fk in ipairs(list) do
        if __DIO_IsFarmFlag(fk) or (__DIO_SharedFlags and __DIO_SharedFlags[fk]) then return true end
    end
    return false
end
__DIO_MapFarmLive = function(list)
    if type(list) ~= "table" then return false end
    for _, fk in ipairs(list) do
        if (__DIO_IsFarmFlag(fk) or (__DIO_SharedFlags and __DIO_SharedFlags[fk]))
           and __DIO_FlagGet(fk) == true and __DIO_FlagCounts(fk) then
            return true
        end
    end
    return false
end
do
    local function __DIOKey(tabName, name)
        return "UI/" .. tostring(tabName) .. "/" .. tostring(name or "")
    end
    local function __DIO_DeepEq(a, b)
        if a == b then return true end
        if type(a) ~= "table" or type(b) ~= "table" then return false end
        for k, v in pairs(a) do
            if type(v) == "table" then
                if not __DIO_DeepEq(v, b[k]) then return false end
            elseif b[k] ~= v then
                return false
            end
        end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end
    local function __WrapTab(tabName, tab)
        if type(tab) ~= "table" then return end
        local _AddToggle = tab.AddToggle
        if type(_AddToggle) == "function" then
            function tab:AddToggle(Setting)
                local key = __DIOKey(tabName, Setting and (Setting.Name or Setting.Title))
                local saved = GetSetting(key, nil)
                -- FIX cung lop loi voi AddSlider: saved khong phai boolean (vd so do slider trung ten
                -- ghi de) ma gan vao Default se bi lib UI quang loi lam sap boot. Bo qua + tu xoa.
                if saved ~= nil and type(saved) ~= "boolean" then
                    _G.SaveData[key] = nil
                    pcall(SaveSettings)
                    saved = nil
                end
                if _G.DIO_AutoRestore == true and Setting and saved ~= nil then
                    Setting.Default = saved
                end
                if Setting and Setting.Default ~= nil and type(Setting.Default) ~= "boolean" then
                    Setting.Default = (Setting.Default == true)
                end
                local origCb = Setting and Setting.Callback
                local __userTouched = false
                local __ownedFlags = nil
                if Setting and origCb then
                    Setting.Callback = function(Value)
                        __userTouched = true
                        if _G.SaveData[key] ~= Value then
                            SetSetting(key, Value)
                        end
                        __DIO_UIState[key] = (Value == true)
                        pcall(function() __DIO_UISetState(key, Value == true) end)
                        local __map = __DIO_ToggleFlagMap and __DIO_ToggleFlagMap[key] or nil
                        if Value == true then
                            -- chi toggle co tween moi kich hoat tween (vd Fast Attack Mob thi khong)
                            if __map == nil or __DIO_MapHasFarm(__map) then
                                __DIO_TweenActivateImmediate()
                            end
                            local __before = {}
                            pcall(function()
                                for k, v in pairs(_G) do
                                    if type(v) == "boolean" and v == true then __before[k] = true end
                                end
                            end)
                            local __beforeG = {}
                            pcall(function()
                                local g = getgenv()
                                if type(g) == "table" and g ~= _G then
                                    for k, v in pairs(g) do
                                        if type(v) == "boolean" and v == true then __beforeG[k] = true end
                                    end
                                end
                            end)
                            pcall(origCb, true)
                            pcall(function() __DIO_Wake(true) end)
                            __ownedFlags = {}
                            pcall(function()
                                for k, v in pairs(_G) do
                                    if type(v) == "boolean" and v == true and __before[k] == nil
                                       and not __DIO_HasNonUIFlagOwner(k) then
                                        __ownedFlags[k] = true
                                    end
                                end
                            end)
                            pcall(function()
                                local g = getgenv()
                                if type(g) == "table" and g ~= _G then
                                    for k, v in pairs(g) do
                                        if type(v) == "boolean" and v == true and __beforeG[k] == nil
                                       and not __DIO_HasNonUIFlagOwner(k) then
                                            __ownedFlags[k] = true
                                        end
                                    end
                                end
                            end)
                            for __fk in pairs(__ownedFlags or {}) do
                                pcall(__DIO_UISetOn, __fk, key, true)
                                pcall(__DIO_UIWant, __fk, key, true)
                            end
                            -- FIX bug "treo": nho lai flag cua toggle nay.
                            -- Neu flag da true tu TRUOC khi bat toggle (flag cu bi ket),
                            -- __ownedFlags se trong -> lan tat toggle sau KHONG xoa duoc flag
                            -- -> highlight + shouldTween mai mai o trang thai bat.
                            if not __DIO_ToggleFlags then __DIO_ToggleFlags = {} end
                            if not __DIO_ToggleFlags[key] then __DIO_ToggleFlags[key] = {} end
                            for __fk in pairs(__ownedFlags or {}) do
                                __DIO_ToggleFlags[key][__fk] = true
                            end
                            -- FIX "treo": dung bang tinh -> luon gan owner UI cho flag cua toggle nay,
                            -- ke ca khi flag da true tu truoc (truoc day bi bo qua -> flag ket / bi owner khac tat mat).
                            if __map then
                                for _, __fk in ipairs(__map) do
                                    __DIO_ToggleFlags[key][__fk] = true
                                    if __DIO_FlagGet(__fk) == true then
                                        pcall(__DIO_UISetOn, __fk, key, true)
                                        pcall(__DIO_UIWant, __fk, key, true)
                                    end
                                end
                                pcall(__DIO_ReapOwners)
                                if __DIO_MapFarmLive(__map) then
                                    -- du 3 lop: _G. flag + shouldTween = true + highlight NGAY LAP TUC
                                    __DIO_OffEdgeT = 0
                                    __DIO_PrevAnyOn = true
                                    pcall(__DIO_TweenClearBlock)
                                    shouldTween = true
                                    if type(__DIO_Move) == "function" then pcall(__DIO_Move) end
                                    pcall(function() if type(__DIO_HlOn) == "function" then __DIO_HlOn() end end)
                                    pcall(function() __DIO_Wake(true) end)
                                end
                            end
                            local __newFlag = false
                            for __k in pairs(__ownedFlags or {}) do __newFlag = true break end
                            local __onNow = __DIO_TweenOnIfAnyFlag()
                            if __onNow then
                                __DIO_TweenBlockT = 0
                                shouldTween = true
                                pcall(function() __DIO_Wake(true) end)
                            end
                            if not __onNow and not __newFlag and getgenv().DIOAuditToggles == true then
                                warn("[DIO AUDIT] Toggle '" .. tostring(Setting and Setting.Name)
                                    .. "' BAT nhung KHONG tao _G. flag nao -> kiem tra _G. / shouldTween cua toggle nay.")
                            end
                        else
                            pcall(origCb, false)
                            local __clearFlags = {}
                            for k in pairs(__ownedFlags or {}) do __clearFlags[k] = true end
                            for k in pairs((__DIO_ToggleFlags and __DIO_ToggleFlags[key]) or {}) do
                                __clearFlags[k] = true
                            end
                            for _, k in ipairs(__map or {}) do __clearFlags[k] = true end
                            if __ownedFlags or next(__clearFlags) ~= nil then
                                for k in pairs(__clearFlags) do
                                    pcall(function() __DIO_UISetOn(k, key, false) end)
                                    pcall(function() __DIO_UIWant(k, key, false) end)
                                    pcall(function() __DIO_ReleaseAll(k) end)
                                    pcall(function()
                                        if rawget(_G, k) == true then rawset(_G, k, false) end
                                    end)
                                    pcall(function()
                                        local g = getgenv()
                                        if type(g) == "table" and g ~= _G and rawget(g, k) == true then
                                            rawset(g, k, false)
                                        end
                                    end)
                                end
                            end
                            pcall(function()
                                pcall(function() __DIO_UISetState(key, false) end)
                                pcall(__DIO_ReapOwners)
                                -- khong con flag farm nao bat -> huy FlyTo dang bay (Rengoku/Buy...), bat quarantine
                                if not __DIO_RealFarmOn() then
                                    __DIO_FlyCancelT = tick()
                                    if __map == nil or __DIO_MapHasFarm(__map) then pcall(__DIO_MarkOffEdge) end
                                end
                                local __stillOn = (type(__DIO_AnyFeatureOn) == "function") and __DIO_AnyFeatureOn() or false
                                if __stillOn or __DIO_FlyBusy == true then
                                    if type(__DIO_TweenSync) == "function" then pcall(__DIO_TweenSync) end
                                    return
                                end
                                __DIO_TweenTarget = nil
                                __DIO_DropPendT = 0
                                if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
                                pcall(__DIO_TweenBlock, 0.35)
                                if not __DIO_FlyBusy then
                                    if type(__DIO_TweenKill) == "function" then
                                        __DIO_TweenKill(false, true)
                                    else
                                        shouldTween = false
                                        __DIO_TweenTarget = nil
                                        if type(StopTween) == "function" then pcall(StopTween, false) end
                                        local __c = plr.Character
                                        if __c then
                                            local __hl = __c:FindFirstChild('highlight')
                                            if __hl then __hl:Destroy() end
                                        end
                                    end
                                end
                            end)
                        end
                    end
                end
                local ctrl = _AddToggle(self, Setting)
                if _G.DIO_AutoRestore == true and saved ~= nil and origCb then
                    task.delay(3, function()
                        if not __userTouched then
                            pcall(Setting.Callback, saved)
                        end
                    end)
                end
                return ctrl
            end
        end
        local _AddDropdown = tab.AddDropdown
        if type(_AddDropdown) == "function" then
            function tab:AddDropdown(Setting)
                local key = __DIOKey(tabName, Setting and (Setting.Name or Setting.Title))
                local saved = GetSetting(key, nil)
                -- FIX cung lop loi voi AddSlider/AddToggle: Dropdown chi nhan Default dang string/table,
                -- saved sai kieu (boolean/number) thi bo qua + tu xoa khoi SaveData, tranh sap boot.
                if saved ~= nil and type(saved) ~= "string" and type(saved) ~= "table" then
                    _G.SaveData[key] = nil
                    pcall(SaveSettings)
                    saved = nil
                end
                local __savedCb = saved
                if Setting and saved ~= nil then
                    if Setting.MultiSelect and type(saved) == "table" then
                        local __arrD = {}
                        for __kD, __vD in pairs(saved) do
                            if __vD == true and type(__kD) == "string" then table.insert(__arrD, __kD) end
                        end
                        Setting.Default = __arrD
                    else
                        Setting.Default = saved
                    end
                end
                local origCb = Setting and Setting.Callback
                local __userTouched = false
                if Setting and origCb then
                    Setting.Callback = function(Value)
                        __userTouched = true
                        if not __DIO_DeepEq(_G.SaveData[key], Value) then
                            SetSetting(key, Value)
                        end
                        __DIO_TweenBlockT = 0
                        local __beforeD = {}
                        pcall(function()
                            for k, v in pairs(_G) do
                                if type(v) == "boolean" and v == true then __beforeD[k] = true end
                            end
                        end)
                        pcall(origCb, Value)
                        pcall(function() __DIO_Wake(true) end)
                        pcall(function()
                            for k, v in pairs(_G) do
                                if type(v) == "boolean" and v == true and __beforeD[k] == nil then
                                    __DIO_UISetOn(k, key, true)
                                end
                            end
                        end)
                        pcall(function()
                            if type(__DIO_TweenOnIfAnyFlag) == "function" and __DIO_TweenOnIfAnyFlag() then
                                pcall(function() __DIO_Wake(true) end)
                            end
                        end)
                        pcall(function()
                            for __fn, __keys in pairs(__DIO_UIFlagOwner) do
                                if __keys[key] == true and __DIO_FlagGet(__fn) ~= true then
                                    __DIO_UISetOn(__fn, key, false)
                                end
                            end
                        end)
                    end
                end
                local ctrl = _AddDropdown(self, Setting)
                if _G.DIO_AutoRestore == true and saved ~= nil and origCb then
                    task.delay(3, function()
                        if not __userTouched then
                            pcall(origCb, saved)
                        end
                    end)
                end
                return ctrl
            end
        end
        local _AddSlider = tab.AddSlider
        if type(_AddSlider) == "function" then
            function tab:AddSlider(Setting)
                local key = __DIOKey(tabName, Setting and (Setting.Name or Setting.Title))
                local saved = GetSetting(key, nil)
                -- FIX crash "Tab.AddSlider.Default". 'number', or 'nil' expected, got boolean (dong 6249 cu):
                -- key "UI/SeaEvent/Ship Speed" tung bi Toggle trung ten ghi boolean vao cung 1 key,
                -- saved = true/false -> gan thang vao Setting.Default thi lib UI quang loi o _AddSlider
                -- lam sap toan bo script ngay luc boot (DIO BOOT: FAILED). Gio chi chap nhan saved dang
                -- so (hoac chuoi so); sai kieu thi bo qua + xoa khoi SaveData de cac lan boot sau tu het.
                saved = tonumber(saved)
                if saved == nil and _G.SaveData[key] ~= nil then
                    _G.SaveData[key] = nil
                    pcall(SaveSettings)
                end
                if Setting then
                    if saved ~= nil then
                        Setting.Default = saved
                    elseif type(Setting.Default) ~= "number" then
                        Setting.Default = tonumber(Setting.Default) or tonumber(Setting.Min) or 0
                    end
                    if type(Setting.Min) == "number" and Setting.Default < Setting.Min then Setting.Default = Setting.Min end
                    if type(Setting.Max) == "number" and Setting.Default > Setting.Max then Setting.Default = Setting.Max end
                end
                local origCb = Setting and Setting.Callback
                local __userTouched = false
                if Setting and origCb then
                    Setting.Callback = function(Value)
                        Value = tonumber(Value)
                        if Value == nil then return end
                        __userTouched = true
                        if _G.SaveData[key] ~= Value then
                            SetSetting(key, Value)
                        end
                        pcall(origCb, Value)
                    end
                end
                local ctrl = _AddSlider(self, Setting)
                if _G.DIO_AutoRestore == true and saved ~= nil and origCb then
                    task.delay(3, function()
                        if not __userTouched then
                            pcall(origCb, saved)
                        end
                    end)
                end
                return ctrl
            end
        end
        local _AddButton = tab.AddButton
        if type(_AddButton) == "function" then
            function tab:AddButton(Setting)
                local key = __DIOKey(tabName, Setting and (Setting.Name or Setting.Title))
                local origCb = Setting and Setting.Callback
                if Setting and origCb then
                    Setting.Callback = function(...)
                        local __beforeB, __beforeBG = {}, {}
                        pcall(function()
                            for k, v in pairs(_G) do
                                if type(v) == "boolean" and v == true then __beforeB[k] = true end
                            end
                        end)
                        pcall(function()
                            local g = getgenv()
                            if type(g) == "table" and g ~= _G then
                                for k, v in pairs(g) do
                                    if type(v) == "boolean" and v == true then __beforeBG[k] = true end
                                end
                            end
                        end)
                        local __okB, __errB = pcall(origCb, ...)
                        if not __okB then
                            pcall(function() warn("[DIO] Button '" .. tostring(Setting and (Setting.Name or Setting.Title)) .. "' error: " .. tostring(__errB)) end)
                        end
                        pcall(function()
                            for k, v in pairs(_G) do
                                if type(v) == "boolean" and v == true and __beforeB[k] == nil then
                                    if not __DIO_UIFlagOwner[k] then __DIO_UIFlagOwner[k] = {} end
                                    __DIO_UIFlagOwner[k][key] = true
                                end
                            end
                        end)
                        return __okB
                    end
                end
                return _AddButton(self, Setting)
            end
        end
    end
    for tabName, tab in pairs(Tabs) do
        pcall(function()
            __WrapTab(tabName, tab)
        end)
    end
end
Tabs.Info:AddSection("Information")
Tabs.Info:AddDiscordInvite({
	Title = "DIO hub | Community",
	Description = "Have Bot king get script in discord",
	Banner = "rbxassetid://105848560127717",
	Logo = "rbxassetid://105848560127717",
	Invite = "https://discord.gg/MjGt2bTWBS",
	Members = 3774,
	Online = 1006,
})
Tabs.Info:AddDiscordInvite({
	Title = "DIO hub | Youtube",
	Description = "Have Bot king get script in discord",
	Banner = "rbxassetid://105848560127717",
	Logo = "rbxassetid://105848560127717",
	Invite = "https://www.youtube.com/@dio_plzzz",
	Members = 3774,
	Online = 1006,
})
__DIO_BOOT("Load Function")
Tabs.Status:AddSection("Status Server")
local TimeZone = Tabs.Status:AddParagraph("Time Zone", "")
function UpdateOS()
    local date = os.date("*t")
    local hour = (date.hour) % 24
    local ampm = hour < 12 and "AM" or "PM"
    local timezone = string.format("%02i:%02i:%02i %s", ((hour - 1) % 12) + 1, date.min, date.sec, ampm)
    local datetime = string.format("%02d/%02d/%04d", date.day, date.month, date.year)
    local LocalizationService = game:GetService("LocalizationService")
    local Players = __SVC_PLR
    local player = Players.LocalPlayer
    local result, code
    if not getgenv().countryRegionCode then
        result, code = pcall(function()
            return LocalizationService:GetCountryRegionForPlayerAsync(player)
        end)
        if result then
            getgenv().countryRegionCode = code
        else
            getgenv().countryRegionCode = "Unknown"
        end
    else
        code = getgenv().countryRegionCode
    end
    TimeZone:SetDesc(datetime.." - "..timezone.." [ " .. code .. " ]")
end
spawn(function()
    while true do
        pcall(UpdateOS)
        __DIO_wait(5)
    end
end)
local GameTime = Tabs.Status:AddParagraph("Server Time", "")
function UpdateGameTime()
    local GameTimeValue = math.floor(workspace.DistributedGameTime + 0.5)
    local Hour = math.floor(GameTimeValue / (60^2)) % 24
    local Minute = math.floor(GameTimeValue / (60^1)) % 60
    local Second = math.floor(GameTimeValue / (60^0)) % 60
    GameTime:SetDesc(Hour.." Hour (h) "..Minute.." Minute (m) "..Second.." Second (s)")
end
spawn(function()
    while true do
        UpdateGameTime()
        __DIO_wait(2)
    end
end)

local NextFoDSpawn = Tabs.Status:AddParagraph("Next Time Spawn Fist of Darkness or God's Chalice", "")
local function __DIO_GetOldestLocation()
    local oldest, oldestTime = nil, 1 / 0
    local origin = workspace:FindFirstChild("_WorldOrigin")
    local locs = origin and origin:FindFirstChild("Locations")
    if not locs then return nil end
    for _, l in ipairs(locs:GetChildren()) do
        local t = l:GetAttribute("TimeIn")
        if t and t < oldestTime then oldestTime, oldest = t, l end
    end
    return oldest
end
function UpdateNextFoDSpawn()
    local loc = __DIO_GetOldestLocation()
    if not loc then return end
    local elapsed = tick() - 25200 - loc:GetAttribute("TimeIn")
    local cycle = 14400
    local remain = cycle - elapsed % cycle
    local h = math.floor(remain / 3600)
    local mnt = math.floor(remain % 3600 / 60)
    local s = math.floor(remain % 60)
    NextFoDSpawn:SetDesc(string.format("%.0fh %.0fm %.0fs", h, mnt, s))
end
spawn(function()
    while true do
        pcall(UpdateNextFoDSpawn)
        __DIO_wait(2)
    end
end)
Tabs.Status:AddSection("Status Islands")
local MirageCheck = Tabs.Status:AddParagraph("Mirage Island", "Status: ")
local previousMirageStatus = ""
spawn(function()
    pcall(function()
        while true do
            __DIO_wait(3)
            local mirageIslandExists = game.Workspace._WorldOrigin.Locations:FindFirstChild('Mirage Island') ~= nil
            local currentStatus = mirageIslandExists and '✅' or '❌'
            if currentStatus ~= previousMirageStatus then
                MirageCheck:SetDesc('Status: ' .. currentStatus)
                previousMirageStatus = currentStatus
            end
        end
    end)
end)
local KitsuneCheck = Tabs.Status:AddParagraph("Kitsune Island", "Status: ")
local previousKitsuneStatus = ""
__DIO_SafeLoop(function()
    while __DIO_wait(3) do
        local currentStatus = __SVC_WS.Map:FindFirstChild("KitsuneIsland") and '✅' or '❌'
        if currentStatus ~= previousKitsuneStatus then
            KitsuneCheck:SetDesc('Status: ' .. currentStatus)
            previousKitsuneStatus = currentStatus
        end
    end
end, "L3135")
local PrehistoricCheck = Tabs.Status:AddParagraph("Prehistoric Island", "Status: ")
local previousPrehistoricStatus = ""
__DIO_SafeLoop(function()
    while __DIO_wait(3) do
        local currentStatus = game.Workspace._WorldOrigin.Locations:FindFirstChild("Prehistoric Island") and '✅' or '❌'
        if currentStatus ~= previousPrehistoricStatus then
            PrehistoricCheck:SetDesc("Status: " .. currentStatus)
            previousPrehistoricStatus = currentStatus
        end
    end
end, "L3148")
local FrozenCheck = Tabs.Status:AddParagraph("Frozen Dimension", "Status: ")
local previousFrozenStatus = ""
__DIO_SafeLoop(function()
    while __DIO_wait(3) do
        local currentStatus = game.Workspace._WorldOrigin.Locations:FindFirstChild('Frozen Dimension') and '✅' or '❌'
        if currentStatus ~= previousFrozenStatus then
            FrozenCheck:SetDesc('Status: ' .. currentStatus)
            previousFrozenStatus = currentStatus
        end
    end
end, "L3161")
Tabs.Status:AddSection("Status Boss")
local CakePrinceStatus = Tabs.Status:AddParagraph("Cake Prince", "")
__DIO_SafeLoop(function()
    local __prevCP = nil
    while __DIO_wait(1) do
        local cakePrince = __SVC_RS.Remotes.CommF_:InvokeServer("CakePrinceSpawner")
        local killStatus = "Cake Prince: ✅"
        if string.len(cakePrince) >= 86 then
            local killCount = string.sub(cakePrince, 39, 41)
            killStatus = "Killed: " .. killCount
        end
        if killStatus ~= __prevCP then __prevCP = killStatus CakePrinceStatus:SetDesc(killStatus) end
    end
end, "L3174")
local RipIndraCheck = Tabs.Status:AddParagraph("Rip Indra", "Status: ")
local previousRipStatus = ""
__DIO_SafeLoop(function()
    while __DIO_wait(3) do
        local currentStatus = (__SVC_RS:FindFirstChild("rip_indra True Form") or
                               __SVC_WS.Enemies:FindFirstChild("rip_indra")) and '✅' or '❌'
        if currentStatus ~= previousRipStatus then
            RipIndraCheck:SetDesc("Status: " .. currentStatus)
            previousRipStatus = currentStatus
        end
    end
end, "L3190")
local DoughKingCheck = Tabs.Status:AddParagraph("Dough King", "Status: ")
local previousDoughStatus = ""
__DIO_SafeLoop(function()
    while __DIO_wait(3) do
        local currentStatus = (__SVC_RS:FindFirstChild("Dough King") or
                               __SVC_WS.Enemies:FindFirstChild("Dough King")) and '✅' or '❌'
        if currentStatus ~= previousDoughStatus then
            DoughKingCheck:SetDesc("Status: " .. currentStatus)
            previousDoughStatus = currentStatus
        end
    end
end, "L3204")
local TyrantStatus = Tabs.Status:AddParagraph("Tyrant Of The Skies", "")
local __prevTyrant = nil
spawn(function()
    pcall(function()
        while __DIO_wait(1) do
            local __tTxt = workspace.Enemies:FindFirstChild("Tyrant of the Skies") and "✅" or "❌"
            if __tTxt ~= __prevTyrant then __prevTyrant = __tTxt TyrantStatus:SetDesc(__tTxt) end
        end
    end)
end)
local EyeStatus = Tabs.Status:AddParagraph("Check Status Eyes", "")
local FullMoonCheck = Tabs.Status:AddParagraph("Full Moon", "")
local __prevMoon = nil
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        local moonTextureId = __SVC_LIGHT.Sky.MoonTextureId
        local moonStatus = "Moon: 0/5"
        if moonTextureId == "http://www.roblox.com/asset/?id=9709149431" then
            moonStatus = "Moon: 5/5 (Full Moon) ✅"
        elseif moonTextureId == "http://www.roblox.com/asset/?id=9709149052" then
            moonStatus = "Moon: 4/5"
        elseif moonTextureId == "http://www.roblox.com/asset/?id=9709143733" then
            moonStatus = "Moon: 3/5"
        elseif moonTextureId == "http://www.roblox.com/asset/?id=9709150401" then
            moonStatus = "Moon: 2/5"
        elseif moonTextureId == "http://www.roblox.com/asset/?id=9709149680" then
            moonStatus = "Moon: 1/5"
        end
        if moonStatus ~= __prevMoon then __prevMoon = moonStatus FullMoonCheck:SetDesc(moonStatus) end
    end
end, "L3231")
local LegendarySwordCheck = Tabs.Status:AddParagraph("Legendary Sword", "Status: ")
__DIO_SafeLoop(function()
    local __prevSword = nil
    while __DIO_wait(5) do
        local swordStatus = "Not Found"
        local d1 = __SVC_RS.Remotes.CommF_:InvokeServer("LegendarySwordDealer", "1")
        if d1 then
            swordStatus = "Shisui ✅"
        else
            local d2 = __SVC_RS.Remotes.CommF_:InvokeServer("LegendarySwordDealer", "2")
            if d2 then
                swordStatus = "Wando ✅"
            else
                local d3 = __SVC_RS.Remotes.CommF_:InvokeServer("LegendarySwordDealer", "3")
                if d3 then
                    swordStatus = "Saddi ✅"
                end
            end
        end
        if swordStatus ~= __prevSword then __prevSword = swordStatus LegendarySwordCheck:SetDesc(swordStatus) end
    end
end, "L3254")
Tabs.Main:AddDropdown({
    Name = __DIO_T["Select Weapon"],
    Options = {"Melee","Sword","Blox Fruit","Gun"},
    Default = "Melee",
    Callback = function(Value)
    _G.ChooseWP = Value
end})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            if _G.ChooseWP == "Melee" then
                for _,v in pairs(plr.Backpack:GetChildren()) do
                    if v.ToolTip == "Melee" then
                        _G.SelectWeapon = v.Name
                    end
                end
            elseif _G.ChooseWP == "Sword" then
                for _,v in pairs(plr.Backpack:GetChildren()) do
                    if v.ToolTip == "Sword" then
                        _G.SelectWeapon = v.Name
                    end
                end
            elseif _G.ChooseWP == "Gun" then
                for _,v in pairs(plr.Backpack:GetChildren()) do
                    if v.ToolTip == "Gun" then
                        _G.SelectWeapon = v.Name
                    end
                end
            elseif _G.ChooseWP == "Blox Fruit" then
                for _,v in pairs(plr.Backpack:GetChildren()) do
                    if v.ToolTip == "Blox Fruit" then
                        _G.SelectWeapon = v.Name
                    end
                end
            end
        end)
    end
end, "L3284")
Tabs.Main:AddDropdown({
    Name = __DIO_T["UI Scale"],
    Options = {"Small", "Normal", "Big"},
    Default = "Normal",
    Callback = function(Value)
        local scales = {Small = 0.8, Normal = 1.0, Big = 1.2}
        Window:SetUIScale(scales[Value])
    end
})
Tabs.Main:AddSection("Farm")
local __DIO_GhostData = {}
local __DIO_GhostSkip = {}
local function __DIO_GhostClean()
    local __nowGC = tick()
    for mob, __tGC in pairs(__DIO_GhostSkip) do
        -- [DIO-FIX] Bo qua mob ghost toi da 30s roi thu lai (mob lag co the hoi phuc),
        -- khong bo vinh vien nhu truoc. Gia tri luu la moc tick() luc bo qua.
        if not mob.Parent or (mob:FindFirstChild("Humanoid") and mob.Humanoid.Health <= 0)
            or (__nowGC - (tonumber(__tGC) or 0)) > 30 then
            __DIO_GhostSkip[mob] = nil
            __DIO_GhostData[mob] = nil
        end
    end
    for mob in pairs(__DIO_GhostData) do
        if not mob.Parent or (mob:FindFirstChild("Humanoid") and mob.Humanoid.Health <= 0) then
            __DIO_GhostData[mob] = nil
        end
    end
end
local function __DIO_GhostReset()
    __DIO_GhostData = {}
    __DIO_GhostSkip = {}
end
local function __DIO_IsGhost(mob)
    local __tIG = __DIO_GhostSkip[mob]
    if __tIG == nil then return false end
    if (tick() - (tonumber(__tIG) or 0)) > 30 then
        __DIO_GhostSkip[mob] = nil
        return false
    end
    return true
end
-- [DIO-FIX] Ghost/Lag Mob - may trang thai dung yeu cau:
--  * Farm 1 mob, danh mai 8s KHONG mat mau (va phai dang dung gan mob - dang
--    bay toi mob thi khong dem, tranh nhan nham) -> spam skill Melee/Sword
--    vao DUNG mob do trong 5s.
--  * Trong 5s mob mat mau -> coi nhu het lag, farm tiep binh thuong.
--  * Het 5s van khong mat mau -> danh dau ghost (bo qua 30s), tra ve true de
--    cac vong farm thoat ra chon mob khac / chay ra bai spawn (chuyen bai).
--  * Toggle "Auto Use Skill Melee/Sword..." TAT: giu bao ve cu (6s khong mat
--    mau thi bo qua, khong dung skill). Bat toggle khong con spam ngay lap tuc
--    vi bo dem duoc reset luc bat/tat va chi dem tu luc danh mob that.
-- (Da xoa __DIO_FireGhostSkill trung lap - chi con dung __DIO_FireMeleeSwordNow
--  dung ban chat Melee/Sword cua toggle, va xoa __DIO_LastGhostMob thua.)
local __DIO_GHOST_NODMG = 8
local __DIO_GHOST_BURST = 5
local __DIO_GHOST_SKIP_OFF = 6
local __DIO_GHOST_RANGE = 90
local __DIO_GHOST_GAP = 2.5
local function __DIO_GhostCheck(mob)
    if not mob or not mob.Parent then return true end
    local hum = mob:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then
        __DIO_GhostData[mob] = nil
        return false
    end
    local __nowG = tick()
    local curHp = hum.Health
    local d = __DIO_GhostData[mob]
    if not d then
        __DIO_GhostData[mob] = { hp = curHp, t = __nowG, burstT = 0, fireT = 0, seen = __nowG }
        return false
    end
    -- Chi tinh khi dang danh LIEN TUC mob nay: vong farm goi GhostCheck moi vai chuc ms.
    -- Ngat quang > GAP (doi muc tieu, bay di, quay lai mob cu) thi bo du lieu cu va dem lai
    -- tu dau; truoc day moc d.t cu lam skill bi spam ngay khi vua quay lai mob / vua bat toggle.
    if (__nowG - (d.seen or 0)) > __DIO_GHOST_GAP then
        d.hp = curHp
        d.t = __nowG
        d.burstT = 0
        d.fireT = 0
    end
    d.seen = __nowG
    if curHp ~= d.hp then
        -- Mob co bien dong mau (danh trung / hoi mau) -> khong phai ghost, dem lai tu dau.
        d.hp = curHp
        d.t = __nowG
        d.burstT = 0
        d.fireT = 0
        return false
    end
    -- Chi dem thoi gian khi dang dung gan mob (dang danh that). Dang bay toi
    -- mob xa thi treo bo dem, khong nhan nham mob chua danh toi la ghost.
    local __mrG = mob:FindFirstChild("HumanoidRootPart")
    local __chG = plr.Character
    local __hrG = __chG and __chG:FindFirstChild("HumanoidRootPart")
    if not __mrG or not __hrG or (__mrG.Position - __hrG.Position).Magnitude > __DIO_GHOST_RANGE then
        d.t = __nowG
        if d.burstT ~= 0 then d.burstT = __nowG end
        return false
    end
    local __noDmgG = __nowG - d.t
    if not _G.AutoSkillGhost then
        if __noDmgG >= __DIO_GHOST_SKIP_OFF then
            __DIO_GhostSkip[mob] = __nowG
            __DIO_GhostData[mob] = nil
            return true
        end
        return false
    end
    if d.burstT == 0 then
        if __noDmgG < __DIO_GHOST_NODMG then return false end
        d.burstT = __nowG
        d.fireT = 0
    end
    if (__nowG - d.burstT) >= __DIO_GHOST_BURST then
        -- Spam skill 5s van khong mat mau -> ghost that: bo mob, chuyen bai/mob khac.
        __DIO_GhostSkip[mob] = __nowG
        __DIO_GhostData[mob] = nil
        if __DIO_CurTarget == mob then __DIO_CurTarget = nil end
        return true
    end
    if (__nowG - (d.fireT or 0)) >= 0.8 then
        d.fireT = __nowG
        if type(__DIO_FireMeleeSwordNow) == "function" then
            pcall(__DIO_FireMeleeSwordNow, mob)
        end
    end
    return false
end
task.spawn(function()
    while true do
        __DIO_wait(5)
        pcall(__DIO_GhostClean)
    end
end)
local alreadyTeleported = false
local __DIO_LvlTryT     = 0
local __DIO_LvlQTryT    = 0
_G.FarmMode  = _G.FarmMode or "Farm Level"
_G.StartFarm = _G.StartFarm or false
__DIO_OwnFarmFlag = nil
local function __DIO_LvlReset()
    alreadyTeleported = false
    __DIO_LvlTryT     = 0
end
function __DIO_FarmHardStop()
    if __DIO_OwnFarmFlag then
        pcall(__DIO_SetFlag, __DIO_OwnFarmFlag, "StartFarm", false)
        pcall(__DIO_SetFlag, __DIO_OwnFarmFlag, "StartFarm", false, true)
        if rawget(_G, __DIO_OwnFarmFlag) == true then rawset(_G, __DIO_OwnFarmFlag, false) end
        __DIO_OwnFarmFlag = nil
    end
    _G.Level = false
    _G.AutoFarm_Bone = false
    _G.Auto_Cake_Prince = false
    _G.FarmTyrant = false
    _G.AutoFarmNear = false
    __DIO_LvlReset()
    pcall(__DIO_GhostReset)
    __DIO_CakeBoss = nil
end

function __DIO_3nn_GetTrackedQuestText()
    local __ok, __txt = pcall(function()
        local __gui = plr.PlayerGui
        local __tracked = __gui:FindFirstChild("TrackedQuestFrame")
        if __tracked and __tracked:FindFirstChild("Frame") then
            local __header = __tracked.Frame:FindFirstChild("header")
            local __tl = __header and __header:FindFirstChild("textLabel")
            local __tl2 = __tl and __tl:FindFirstChild("textLabel")
            if __tl2 and type(__tl2.Text) == "string" and __tl2.Text ~= "" then
                return __tl2.Text
            end
        end
        local __main = __gui:FindFirstChild("Main") or __gui:FindFirstChild("Main (minimal)")
        local __quest = __main and __main:FindFirstChild("Quest")
        local __cont = __quest and __quest:FindFirstChild("Container")
        local __title = __cont and __cont:FindFirstChild("QuestTitle")
        local __titleText = __title and __title:FindFirstChild("Title")
        if __quest and __quest.Visible and __titleText and type(__titleText.Text) == "string" then
            return __titleText.Text
        end
        return ""
    end)
    return (__ok and __txt) or ""
end
function __DIO_3nn_HasActiveQuestFor(target)
    local __text = __DIO_3nn_GetTrackedQuestText()
    if __text == "" then return false end
    local function __strip(name)
        name = tostring(name or "")
        return (name:gsub(" %p?Lv%.? %d+%p?", ""))
    end
    if typeof(target) == "table" then
        for _, __name in pairs(target) do
            local __n = __strip(__name)
            if __n ~= "" and string.find(__text, __n, 1, true) then return true end
        end
    else
        local __n = __strip(target)
        if __n ~= "" and string.find(__text, __n, 1, true) then return true end
    end
    return false
end
__DIO_3nn_TikiCF = nil
__DIO_3nn_QuestPointFor = function(wantName)
    local __found = nil
    pcall(function()
        if typeof(Quests) ~= "table" or typeof(GuideModule) ~= "table" then return end
        if not (GuideModule.Data and GuideModule.Data.NPCList) then return end
        local __lvMap = {}
        for __qn, __qds in next, Quests, nil do
            if __qn ~= "MarineQuest" then
                for __id, __qd in next, __qds, nil do
                    if __qd and __qd.LevelReq then __lvMap[__qd.LevelReq] = __qn end
                end
            end
        end
        for __npc, __nd in next, GuideModule.Data.NPCList, nil do
            if __nd and __nd.Levels then
                for __id, __lv in next, __nd.Levels, nil do
                    if __lvMap[__lv] == wantName
                        and __npc.Parent and __npc.Parent.Name ~= "Marine Leader" then
                        __found = CFrame.new(__nd.Position)
                        return
                    end
                end
            end
        end
    end)
    return __found
end
__DIO_3nn_TyrantEyesFull = function()
    local __ok, __full = pcall(function()
        local __map = workspace:FindFirstChild("Map")
        local __tiki = __map and __map:FindFirstChild("TikiOutpost", true)
        local __model = __tiki and (__tiki:FindFirstChild("IslandModel", true) or __tiki)
        if not __model then return false end
        local __e1 = __model:FindFirstChild("Eye1", true)
        local __e2 = __model:FindFirstChild("Eye2", true)
        local __e3 = __model:FindFirstChild("Eye3", true)
        local __e4 = __model:FindFirstChild("Eye4", true)
        return __e1 and __e2 and __e3 and __e4
            and __e1.Transparency == 0 and __e2.Transparency == 0
            and __e3.Transparency == 0 and __e4.Transparency == 0
    end)
    return (__ok and __full) or false
end
__DIO_3nn_TyrantTree = function()
    local __ok, __tree = pcall(function()
        local __map = workspace:FindFirstChild("Map")
        local __tiki = __map and __map:FindFirstChild("TikiOutpost")
        local __model = __tiki and __tiki:FindFirstChild("IslandModel")
        local __arena = __model and __model:FindFirstChild("EagleBossArena", true)
        if not __arena then return nil end
        for _, __m in pairs(__arena:GetChildren()) do
            if __m.Name == "Tree" and not __m:GetAttribute("AlreadyDestroyedClient") then
                return __m
            end
        end
        return nil
    end)
    return (__ok and __tree) or nil
end

_G.AutoQuest = (_G.AutoQuest == true)
__DIO_3nn_QT_LastStart = 0
__DIO_3nn_AutoQuest = function(mode)
    if _G.AutoQuest ~= true then return false end
    local C, H, mobs, npcCF
    if mode == "Cake" then
        C, H = 2275, "CakeQuest2"
        mobs = {"Baking Staff", "Head Baker", "Cake Guard", "Cookie Crafter"}
        npcCF = CFrame.new(-1927.92, 37.80, -12842.54)
    elseif mode == "Bone" then
        C, H = 2050, "HauntedQuest2"
        mobs = {"Reborn Skeleton", "Demonic Soul", "Living Zombie", "Posessed Mummy"}
        npcCF = CFrame.new(-9516.99, 172.01, 6078.46)
    elseif mode == "Tyrant" then
        C, H = 2575, "TikiQuest3"
        mobs = {"Isle Champion", "Serpent Hunter", "Skull Slayer", "Sun-kissed Warrior"}
        if not __DIO_3nn_TikiCF then
            __DIO_3nn_TikiCF = __DIO_3nn_QuestPointFor("TikiQuest3")
        end
        npcCF = __DIO_3nn_TikiCF
    else
        return false
    end
    local lvl = (plr.Data and plr.Data.Level and plr.Data.Level.Value) or 0
    if lvl < C then return false end
    if __DIO_3nn_HasActiveQuestFor(mobs) then return false end

    if __DIO_3nn_GetTrackedQuestText() ~= "" then return false end
    if not npcCF then return false end
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return true end
    if (npcCF.Position - hrp.Position).Magnitude <= 8 then
        if hum.Health > 0 and tick() - __DIO_3nn_QT_LastStart > 1.25 then
            __DIO_3nn_QT_LastStart = tick()
            pcall(function()
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StartQuest", H, 2)
            end)
            task.wait(0.5)
        end
    else
        _tp(npcCF * CFrame.new(0, 4, 2))
    end
    return true
end
function __DIO_ApplyFarmMode()
    __DIO_FarmHardStop()
    if not _G.StartFarm then
        StopTween(false)
        return
    end
    local __mode = _G.FarmMode
    if __mode == "Farm Level" then
        __DIO_OwnFarmFlag = "Level"
    elseif __mode == "Farm Bone" then
        __DIO_OwnFarmFlag = "AutoFarm_Bone"
    elseif __mode == "Farm Cake" then
        __DIO_OwnFarmFlag = "Auto_Cake_Prince"
    elseif __mode == "Farm Tyrant" then
        __DIO_OwnFarmFlag = "FarmTyrant"
    elseif __mode == "Farm Nearest" then
        __DIO_OwnFarmFlag = "AutoFarmNear"
    end
    if __DIO_OwnFarmFlag then
        pcall(__DIO_SetFlag, __DIO_OwnFarmFlag, "StartFarm", true)
        _G[__DIO_OwnFarmFlag] = true
    end
    shouldTween = true
end

function __DIO_MasteryMode()
    local m = _G.FarmMode
    if m == "Farm Bone" then return "Bone" end
    if m == "Farm Cake" then return "Cake" end
    if m == "Farm Tyrant" then return "Tyrant" end
    if m == "Farm Nearest" then return "Nearest" end
    return "Level"
end
function __DIO_SyncMasteryIsland()
    SelectIsland = __DIO_MasteryMode()
end
do
    local __farmOpts = {"Farm Level", "Farm Bone", "Farm Cake", "Farm Tyrant", "Farm Nearest"}
    local __savedMode = GetSetting("UI/Main/" .. tostring(__DIO_T["Select Farm"]), nil)
    if type(__savedMode) == "string" and table.find(__farmOpts, __savedMode) then
        _G.FarmMode = __savedMode
    end
end
__DIO_SyncMasteryIsland()
Tabs.Main:AddDropdown({
    Name = __DIO_T["Select Farm"],
    Description = "",
    Options = {"Farm Level", "Farm Bone", "Farm Cake", "Farm Tyrant", "Farm Nearest"},
    Default = _G.FarmMode,
    Callback = function(Value)
        _G.FarmMode = Value
        __DIO_SyncMasteryIsland()
        if _G.StartFarm then
            __DIO_ApplyFarmMode()
        end
    end
})
Tabs.Main:AddToggle({
    Name = __DIO_T["Start Farm"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.StartFarm = Value
        if Value then
            __DIO_ApplyFarmMode()
        else
            _G.StartFarm = false
            __DIO_FarmHardStop()
            StopTween(false)
        end
    end
})

Tabs.Main:AddToggle({
    Name = __DIO_T["Auto Quest |Level|Tyrant|Cake|Bone"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoQuest = (Value == true)
    end
})
-- FIX farm level loop: ham cu kiem tra tam (11520.8, 9829.5) ban kinh 2000,
-- NHUNG tam that cua dao la newdao (10641.09, 9825.07) -> lech ~880 stud, ban kinh lai nho.
-- Cho farm o ria dao bi tinh la "ngoai dao" -> loop farm cu 20s lai keo nguoi choi
-- tween len sea -> bay ve NPC tau ngam o Tiki -> TravelToSubmergedIsland -> tween lai cho farm -> lap lai.
local function IsInSubmergedIsland()
    local char = plr.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local p = hrp.Position
    local islandXZ = Vector3.new(newdao.Position.X, 0, newdao.Position.Z)
    local playerXZ = Vector3.new(p.X, 0, p.Z)
    local dXZ = (playerXZ - islandXZ).Magnitude
    if dXZ < 3500 then return true end
    -- duoi bien sau gan khu vuc dao (dang di chuyen xuong dao) cung coi la "trong dao"
    if p.Y < -500 and dXZ < 6000 then return true end
    return false
end
-- Mob quest hien tai co spawn tren/gan dao ngam khong? Chi di tau ngam khi that su can farm o do,
-- tranh tranh chap voi farm quest binh thuong o dao khac.
local function __DIO_QuestMobOnSubmerged(mobName)
    if type(mobName) ~= "string" or mobName == "" then return false end
    local ok, res = pcall(function()
        local sp = workspace:FindFirstChild("_WorldOrigin")
        sp = sp and sp:FindFirstChild("EnemySpawns")
        if not sp then return false end
        local islandXZ = Vector3.new(newdao.Position.X, 0, newdao.Position.Z)
        for _, s in ipairs(sp:GetChildren()) do
            if s:IsA("BasePart") and string.find(s.Name, mobName, 1, true) then
                local p = Vector3.new(s.CFrame.Position.X, 0, s.CFrame.Position.Z)
                if (p - islandXZ).Magnitude < 4000 then return true end
            end
        end
        return false
    end)
    return (ok and res) or false
end
local function __DIO_NearestMob(enemyName, rootPos)
    local en = workspace:FindFirstChild("Enemies")
    if not en then return nil end
    local best, bestD = nil, math.huge
    for _, mob in ipairs(en:GetChildren()) do
        if mob.Name == enemyName and not __DIO_IsGhost(mob) then
            local hum = mob:FindFirstChild("Humanoid")
            local hroot = mob:FindFirstChild("HumanoidRootPart")
            if hum and hroot and hum.Health > 0 then
                local d = (hroot.Position - rootPos).Magnitude
                if d < bestD then
                    bestD = d
                    best = mob
                end
            end
        end
    end
    return best
end
__DIO_SafeLoop(function()
    while __DIO_wait(Sec) do
        if _G.Level then
            pcall(function()
                local char = plr.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then return end
                local RootF = char.HumanoidRootPart
                local level = plr.Data.Level.Value
                local inSub = IsInSubmergedIsland()
                local questText = ""
                if type(__DIO_3nn_GetTrackedQuestText) == "function" then
                    questText = __DIO_3nn_GetTrackedQuestText() or ""
                end
                local hasQuest = (questText ~= "")
                local questData = QuestNeta()
                -- FIX: chi ep di Submerged Island khi mob quest dung la mob cua dao ngam.
                -- Truoc day: level >= 2600 + IsInSubmergedIsland() sai tam -> dang farm binh thuong
                -- cung bi tween len sea, bay ve NPC tau ngam (Tiki), travel, roi tween ve lai cho farm, cu lap mai.
                if level >= 2600 and not inSub
                   and questData and questData[1]
                   and __DIO_QuestMobOnSubmerged(questData[1]) then
                    if not alreadyTeleported or tick() - __DIO_LvlTryT > 20 then
                        alreadyTeleported = true
                        __DIO_LvlTryT = tick()
                        local npcPos = CFrame.new(-16269.7041, 25.2288494, 1373.65955)
                        local attempts = 0
                        repeat
                            __DIO_wait(Sec)
                            _tp(npcPos)
                            attempts = attempts + 1
                        until not _G.Level
                           or (RootF.Position - npcPos.Position).Magnitude <= 8
                           or attempts > 25
                        if _G.Level then
                            __DIO_wait(1)
                            pcall(function()
                                local sm = __SVC_RS.Modules.Net:FindFirstChild("RF/SubmarineWorkerSpeak")
                                if sm then sm:InvokeServer("TravelToSubmergedIsland") end
                            end)
                            local t0 = tick()
                            repeat
                                __DIO_wait(0.5)
                                if IsInSubmergedIsland() then break end
                            until not _G.Level or tick() - t0 > 15
                        end
                    end
                    return
                end
                if not questData or not questData[1] then
                    __DIO_wait(1)
                    return
                end

                if _G.AutoQuest then
                    if hasQuest and __DIO_3nn_HasActiveQuestFor(questData[1]) then
                        -- dang giu dung quest -> khong can lam gi
                    elseif hasQuest then
                        pcall(function()
                            replicated.Remotes.CommF_:InvokeServer("AbandonQuest")
                        end)
                        __DIO_wait(0.5)
                        return
                    else
                        local PosQ = questData[6]
                        local __qBlock = false
                        if PosQ then
                            local far = (PosQ.Position - RootF.Position).Magnitude
                            if far > 10000 and PosQ.Position.X > 50000 then
                                pcall(function()
                                    replicated.Remotes.CommF_:InvokeServer("requestEntrance",
                                        Vector3.new(61163.8515625, 11.6796875, 1819.7841796875))
                                end)
                            elseif PosQ.Position.Z > 32000 then
                                pcall(function()
                                    replicated.Remotes.CommF_:InvokeServer("requestEntrance",
                                        Vector3.new(923.21252441406, 126.9760055542, 32852.83203125))
                                end)
                            elseif far > 4000 and PosQ.Position.X < -4000
                               and PosQ.Position.Y > 3000 and PosQ.Position.Z < 0 then
                                pcall(function()
                                    replicated.Remotes.CommF_:InvokeServer("requestEntrance",
                                        Vector3.new(-7894.6176757813, 5547.1416015625, -380.29119873047))
                                end)
                            elseif far > 4000 and PosQ.Position.X < -4000
                               and PosQ.Position.Y > 500 and PosQ.Position.Z < 0 then
                                pcall(function()
                                    replicated.Remotes.CommF_:InvokeServer("requestEntrance",
                                        Vector3.new(-4607.82275, 872.54248, -1667.55688))
                                end)
                            end
                            _tp(PosQ)
                            local t0 = tick()
                            while _G.Level and (RootF.Position - PosQ.Position).Magnitude > 8
                               and tick() - t0 < 15 do
                                __DIO_wait(0.25)
                                _tp(PosQ)
                                if type(__DIO_3nn_GetTrackedQuestText) == "function"
                                   and __DIO_3nn_GetTrackedQuestText() ~= "" then
                                    break
                                end
                            end
                            if (RootF.Position - PosQ.Position).Magnitude > 8 then
                                __qBlock = true
                            end
                        end
                        if not __qBlock and tick() - __DIO_LvlQTryT > 2 then
                            __DIO_LvlQTryT = tick()
                            pcall(function()
                                replicated.Remotes.CommF_:InvokeServer("StartQuest", questData[3], questData[2])
                            end)
                            __DIO_wait(1)
                        end
                        return
                    end
                end
                pcall(__DIO_GhostClean)
                local enemyName = questData[1]
                local target = __DIO_NearestMob(enemyName, RootF.Position)
                while target and _G.Level do
                    local switched = false
                    repeat
                        if not _G.Level then break end
                        local curRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if not curRoot then break end
                        if not target.Parent then break end
                        local th = target:FindFirstChild("Humanoid")
                        local tr = target:FindFirstChild("HumanoidRootPart")
                        if not th or not tr then break end
                        if th.Health <= 0 then break end
                        Attack.Kill(target, _G.Level)
                        if __DIO_3nn_GetTrackedQuestText() == "" then break end
                        if __DIO_GhostCheck(target) then switched = true break end
                        __DIO_wait()
                    until not target.Parent
                       or not target:FindFirstChild("Humanoid")
                       or target.Humanoid.Health <= 0

                    if not _G.Level then break end
                    if switched then break end
                    if __DIO_3nn_GetTrackedQuestText() == "" then break end
                    __DIO_wait()
                    target = __DIO_NearestMob(enemyName, RootF.Position)
                end
                if target then return end
                local moved = false
                local sp = workspace:FindFirstChild("_WorldOrigin")
                sp = sp and sp:FindFirstChild("EnemySpawns")
                if sp then
                    for _, s in ipairs(sp:GetChildren()) do
                        if string.find(s.Name, enemyName) then
                            moved = true
                            if (s.CFrame.Position - RootF.Position).Magnitude > 10 then
                                _tp(s.CFrame * CFrame.new(0, 20, 0))
                            end
                            break
                        end
                    end
                end
                if not moved and questData[6]
                   and (questData[6].Position - RootF.Position).Magnitude > 10 then
                    _tp(questData[6] * CFrame.new(0, 10, 0))
                end
            end)
        else
            alreadyTeleported = false
        end
    end
end, "L3585")
__DIO_SafeLoop(function()
  while __DIO_wait() do
    pcall(function()
      if _G.AutoFarmNear then

        local __hrpA = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if __hrpA then
          local __dist = tonumber(_G.AuraDistance) or 300
          local __best, __bestD = nil, __dist
          for _, __m in pairs(workspace.Enemies:GetChildren()) do
            local __h = __m:FindFirstChildOfClass("Humanoid")
            local __r = __m:FindFirstChild("HumanoidRootPart")
            local __ghost = (type(__DIO_IsGhost) == "function") and __DIO_IsGhost(__m)
            if __h and __r and __h.Health > 0 and not __ghost then
              local __d = (__r.Position - __hrpA.Position).Magnitude
              if __d < __bestD then __bestD = __d __best = __m end
            end
          end
          if __best then
            pcall(__DIO_3nn_SizePart, __best)
            repeat Attack.Kill(__best, _G.AutoFarmNear); __DIO_wait() until not _G.AutoFarmNear or not __best.Parent or not __best:FindFirstChildOfClass("Humanoid") or __best:FindFirstChildOfClass("Humanoid").Health <= 0
          end
        end
      end
    end)
  end
end, "L3773")
Tabs.Main:AddToggle({
Name = __DIO_T["Auto Factory Raid"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoFactory = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.AutoFactory then
        local v = GetConnectionEnemies("Core")
        if v then
          repeat __DIO_wait(0.25)
            EquipWeapon(_G.SelectWeapon)
            _tp(CFrame.new(448.46756, 199.356781, -441.389252))
            pcall(__DIO_3nn_M1, v)
          until v.Humanoid.Health <= 0 or _G.AutoFactory == false
        else
          _tp(CFrame.new(448.46756, 199.356781, -441.389252))
        end
      end
    end)
  end
end, "L3795")
Tabs.Main:AddToggle({
Name = __DIO_T["Auto Pirate Raid"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoRaidCastle = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait() do
    if _G.AutoRaidCastle then
      pcall(function()
      local CFrameCastleRaid = CFrame.new(-5496.17432, 313.768921, -2841.53027, 0.924894512, 7.37058015e-09, 0.380223751, 3.5881019e-08, 1, -1.06665446e-07, -0.380223751, 1.12297109e-07, 0.924894512)
        if (CFrame.new(-5539.3115234375, 313.800537109375, -2972.372314453125).Position - Root.Position).Magnitude <= 500 then
          for i,v in pairs(workspace.Enemies:GetChildren()) do
            if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
              if v.Name then
                if (v.HumanoidRootPart.Position - Root.Position).Magnitude <= 2000 then
                  repeat Attack.Kill(v,_G.AutoRaidCastle); __DIO_wait() until not _G.AutoRaidCastle or not v.Parent or v.Humanoid.Health <= 0 or not workspace.Enemies:FindFirstChild(v.Name)
                end
              end
            end
          end
        else
          local Castle_Mob = {"Galley Pirate","Galley Captain","Raider","Mercenary","Vampire","Zombie","Snow Trooper","Winter Warrior","Lab Subordinate","Horned Warrior","Magma Ninja","Lava Pirate","Ship Deckhand","Ship Engineer","Ship Steward","Ship Officer","Arctic Warrior","Snow Lurker","Sea Soldier","Water Fighter"}
          for i = 1,#Castle_Mob do
            if replicated:FindFirstChild(Castle_Mob[i]) then
              for _,v in pairs(replicated:GetChildren()) do
                if table.find(Castle_Mob, v.Name) then _tp(CFrameCastleRaid) end
              end
            end
          end
        end
      end)
    end
  end
end, "L3826")
Tabs.Main:AddToggle({
Name = __DIO_T["Auto Farm Ectoplasm"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoEctoplasm = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.AutoEctoplasm then
        local EctoTable = {"Ship Deckhand","Ship Engineer","Ship Steward","Ship Officer","Arctic Warrior"}
        local v = GetConnectionEnemies(EctoTable)
		if Attack.Alive(v) then
		  repeat Attack.Kill(v, _G.AutoEctoplasm); __DIO_wait() until not _G.AutoEctoplasm or not v.Parent or v.Humanoid.Health <= 0
	    else
	      replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(923.21252441406, 126.9760055542, 32852.83203125))
	    end
      end
    end)
  end
end, "L3863")
Tabs.Main:AddSection("Chest")
Tabs.Main:AddToggle({
Name = __DIO_T["Auto Farm Chest"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoFarmChest = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.AutoFarmChest then
      pcall(function()
        local CollectionService = __SVC_CS
        local Players = __SVC_PLR
        local Player = Players.LocalPlayer
        local Character = Player.Character or Player.CharacterAdded:Wait()
        if not Character then return end
        local Position = Character:GetPivot().Position
        local Chests = CollectionService:GetTagged("_ChestTagged")
        local Distance, Nearest = math.huge, nil
        for i = 1, #Chests do
          local Chest = Chests[i]
          local Magnitude = (Chest:GetPivot().Position - Position).Magnitude
          local __selIsland = __DIO_GetSelectedIslandModel()
          if not __selIsland or Chest:IsDescendantOf(__selIsland) then
            if not Chest:GetAttribute("IsDisabled") and Magnitude < Distance then
              Distance = Magnitude
              Nearest = Chest
            end
          end
        end
      if Nearest then _tp(Nearest:GetPivot()) end
      end)
    end
  end
end, "L3888")
local __DIO_ChestBPBusy = false
local __DIO_ChestBPConn = nil
Tabs.Main:AddToggle({
    Name = __DIO_T["Auto Chest Bypass"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoChestBP = Value
        if Value then
            local LocalPlayer = __SVC_PLR.LocalPlayer
            local UncheckedChests = {}
            local FirstRun = true
            local function getCharacter()
                if not LocalPlayer.Character then
                    LocalPlayer.CharacterAdded:Wait()
                end
                LocalPlayer.Character:WaitForChild("HumanoidRootPart")
                return LocalPlayer.Character
            end
            local function getChestsSorted()
                if FirstRun then
                    FirstRun = false
                    for _, Object in pairs(game:GetDescendants()) do
                        if Object.Name:find("Chest") and Object.ClassName == "Part" then
                            table.insert(UncheckedChests, Object)
                        end
                    end
                end
                local Chests = {}
                for _, Chest in pairs(UncheckedChests) do
                    if Chest:FindFirstChild("TouchInterest") then
                        table.insert(Chests, Chest)
                    end
                end
                local RootPart = getCharacter().LowerTorso
                table.sort(Chests, function(a, b)
                    return (RootPart.Position - a.Position).Magnitude < (RootPart.Position - b.Position).Magnitude
                end)
                return Chests
            end
            local function runChestLoop()
                if __DIO_ChestBPBusy then return end
                __DIO_ChestBPBusy = true
                task.spawn(function()
                    while _G.AutoChestBP and LocalPlayer.Character and LocalPlayer.Character.Parent do
                        pcall(function()
                            local Chests = getChestsSorted()
                            if #Chests > 0 then
                                local __chCB = getCharacter()
                                local RootPart = __chCB and __chCB:FindFirstChild("HumanoidRootPart")
                                if RootPart then
                                    RootPart.CFrame = Chests[1].CFrame
                                    __DIO_TweenSet(Chests[1].CFrame)
                                end
                            end
                        end)
                        __DIO_wait(0.3)
                    end
                    __DIO_ChestBPBusy = false
                end)
            end
            if not __DIO_ChestBPConn then
                __DIO_ChestBPConn = LocalPlayer.CharacterAdded:Connect(function()
                    __DIO_wait(0.5)
                    if _G.AutoChestBP then
                        runChestLoop()
                    end
                end)
            end
            runChestLoop()
        end
    end
})
Tabs.Main:AddToggle({
Name = __DIO_T["Stop Items"],
Description = "",
Default = true,
Callback = function(Value)
    _G.StopWhenChalice = Value
    if not Value then
        __DIO_SetFlag("AutoFarmChest", "StopWhenChalice", false, true)
        __DIO_SetFlag("AutoChestBP",   "StopWhenChalice", false, true)
        __DIO_ReleaseAll("StopWhenChalice")
    end
end})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.StopWhenChalice then
            pcall(function()
                if GetBP("God's Chalice") or GetBP("Sweet Chalice") or GetBP("Fist of Darkness") then
                    __DIO_SetFlag("AutoFarmChest", "StopWhenChalice", true, true)
                    __DIO_SetFlag("AutoChestBP",   "StopWhenChalice", true, true)
                else
                    __DIO_SetFlag("AutoFarmChest", "StopWhenChalice", false, true)
                    __DIO_SetFlag("AutoChestBP",   "StopWhenChalice", false, true)
                end
            end)
        end
    end
end, "L4002")
__DIO_GetInstCF = function(inst)
    if not inst then return nil end
    local __okCF, __cf = pcall(function()
        if inst:IsA("Model") then
            return inst:GetPivot()
        elseif inst:IsA("BasePart") then
            return inst.CFrame
        end
        return nil
    end)
    if __okCF then return __cf end
    return nil
end
__DIO_BerryBushPass = function(Bush)
    if not BerryArray then return true end
    local __okBP, __pass = pcall(function()
        for _, BerryName in pairs(Bush:GetAttributes()) do
            if table.find(BerryArray, BerryName) then return true end
        end
        for _, ch in ipairs(Bush:GetChildren()) do
            if table.find(BerryArray, ch.Name) then return true end
        end
        return false
    end)
    if __okBP then return __pass end
    return false
end
__DIO_BerryBushes = function()
    local list = {}
    local seen = {}
    local function add(inst)
        if inst and not seen[inst] then
            seen[inst] = true
            table.insert(list, inst)
        end
    end
    pcall(function()
        for _, tag in ipairs({"BerryBush", "Berry", "_BerryBush", "Bush"}) do
            for _, inst in ipairs(__SVC_CS:GetTagged(tag)) do
                add(inst)
            end
        end
    end)
    pcall(function()
        for _, obj in ipairs(workspace:GetChildren()) do
            local name = obj.Name:lower()
            if name:find("berry") or name:find("bush") then
                add(obj)
            end
        end
    end)
    pcall(function()
        local map = workspace:FindFirstChild("Map")
        if map then
            for _, obj in ipairs(map:GetChildren()) do
                local name = obj.Name:lower()
                if name:find("berry") or name:find("bush") then
                    add(obj)
                end
            end
        end
    end)
    return list
end
__DIO_FindAllBerryPrompts = function()
    local prompts = {}
    local seen = {}
    local function checkPrompt(pp, fallbackCF)
        if not pp or not pp:IsA("ProximityPrompt") then return end
        if pp.Enabled == false then return end
        if seen[pp] then return end
        seen[pp] = true
        local cf = nil
        local parent = pp.Parent
        if parent then
            if parent:IsA("BasePart") then
                cf = parent.CFrame
            elseif parent:IsA("Model") then
                cf = parent:GetPivot()
            elseif parent.Parent and parent.Parent:IsA("BasePart") then
                cf = parent.Parent.CFrame
            elseif parent.Parent and parent.Parent:IsA("Model") then
                cf = parent.Parent:GetPivot()
            end
        end
        cf = cf or fallbackCF
        if cf then
            table.insert(prompts, { prompt = pp, cf = cf })
        end
    end
    local bushes = __DIO_BerryBushes()
    for _, bush in ipairs(bushes) do
        if bush and __DIO_BerryBushPass(bush) then
            local bushCF = __DIO_GetInstCF(bush)
            local pDirect = bush:FindFirstChildOfClass("ProximityPrompt")
            if pDirect then checkPrompt(pDirect, bushCF) end
            for _, desc in ipairs(bush:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    checkPrompt(desc, bushCF)
                end
            end
        end
    end
    pcall(function()
        for _, pp in ipairs(workspace:GetDescendants()) do
            if pp:IsA("ProximityPrompt") and pp.Enabled ~= false and not seen[pp] then
                local act = (pp.ActionText or ""):lower()
                local obj = (pp.ObjectText or ""):lower()
                local pName = (pp.Name or ""):lower()
                local parentName = pp.Parent and pp.Parent.Name:lower() or ""
                if act:find("berry") or obj:find("berry") or pName:find("berry") or parentName:find("berry") then
                    checkPrompt(pp, nil)
                end
            end
        end
    end)
    return prompts
end
__DIO_FarmBerryStep = function()
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0, false end
    local myPos = hrp.Position
    local prompts = __DIO_FindAllBerryPrompts()
    if #prompts == 0 then
        return 0, false
    end
    local bestEntry, bestDist = nil, math.huge
    for _, entry in ipairs(prompts) do
        local d = (entry.cf.Position - myPos).Magnitude
        if d < bestDist then
            bestDist = d
            bestEntry = entry
        end
    end
    if bestEntry then
        local targetCF = bestEntry.cf * CFrame.new(0, 2, 0)
        _tp(targetCF)
        if bestDist <= 25 then
            pcall(fireproximityprompt, bestEntry.prompt, 0)
            pcall(fireproximityprompt, bestEntry.prompt, 1)
            pcall(fireproximityprompt, bestEntry.prompt, math.huge)
        end
        return #prompts, true
    end
    return #prompts, false
end
__DIO_BerryHopT = 0
__DIO_SafeLoop(function()
    while __DIO_wait(0.3) do
        if _G.AutoBerryH then
            local __okH, __nH, __hasH = pcall(__DIO_FarmBerryStep)
            if __okH and not __hasH then
                if __DIO_BerryHopT == 0 then
                    __DIO_BerryHopT = tick()
                elseif tick() - __DIO_BerryHopT > 5 then
                    __DIO_BerryHopT = 0
                    pcall(function()
                        if Window and Window.Notify then
                            __DIO_TNotify("Auto Farm Berry + Hop", "Het berry trong server -> Hop server khac...", 4)
                        end
                    end)
                    pcall(function()
                        if type(Hop) == "function" then
                            Hop()
                        else
                            local ServerList = {}
                            local Success = pcall(function()
                                ServerList = __SVC_HTTP:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
                            end)
                            if Success and ServerList.data then
                                for _, Server in pairs(ServerList.data) do
                                    if Server.playing < Server.maxPlayers and Server.id ~= game.JobId then
                                        __SVC_TP:TeleportToPlaceInstance(game.PlaceId, Server.id, __SVC_PLR.LocalPlayer)
                                        break
                                    end
                                end
                            end
                        end
                    end)
                end
            else
                __DIO_BerryHopT = 0
            end
        end
    end
end, "BerryHop")
__DIO_DefaultMobName = function()
    if World1 then return "Bandit" end
    if World2 then return "Raider" end
    return "Pirate Millionaire"
end
Tabs.Main:AddSection("Farm Mob")
if World1 then
    Tabs.Main:AddDropdown({
        Name = __DIO_T["Select Mob"],
        Default = "Bandit",
        Options = {
            "Bandit", "Monkey", "Gorilla", "Pirate", "Brute",
            "Desert Bandit", "Desert Officer", "Snow Bandit", "Snowman",
            "Chief Petty Officer", "Sky Bandit", "Dark Master", "Toga Warrior",
            "Gladiator", "Military Soldier", "Military Spy",
            "Fishman Warrior", "Fishman Commando",
            "God's Guard", "Shanda", "Royal Squad", "Royal Soldier",
            "Galley Pirate", "Galley Captain",
        },
        Callback = function(Value)
            getgenv().SelectMob = Value
            pcall(rawset, _G, "SelectMob", Value)
        end
    })
end
if World2 then
    Tabs.Main:AddDropdown({
        Name = __DIO_T["Select Mob"],
        Default = "Raider",
        Options = {
            "Raider", "Mercenary", "Swan Pirate", "Factory Staff",
            "Marine Lieutenant", "Marine Captain", "Zombie", "Vampire",
            "Snow Trooper", "Winter Warrior", "Lab Subordinate",
            "Horned Warrior", "Magma Ninja", "Lava Pirate",
            "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer",
            "Arctic Warrior", "Snow Lurker", "Sea Soldier", "Water Fighter",
        },
        Callback = function(Value)
            getgenv().SelectMob = Value
            pcall(rawset, _G, "SelectMob", Value)
        end
    })
end
if World3 then
    Tabs.Main:AddDropdown({
        Name = __DIO_T["Select Mob"],
        Default = "Pirate Millionaire",
        Options = {
            "Pirate Millionaire", "Dragon Crew Warrior", "Dragon Crew Archer",
            "Female Islander", "Giant Islander", "Marine Commodore",
            "Marine Rear Admiral", "Fishman Raider", "Fishman Captain",
            "Forest Pirate", "Mythological Pirate", "Jungle Pirate",
            "Musketeer Pirate", "Reborn Skeleton", "Living Zombie",
            "Demonic Soul", "Posessed Mummy", "Peanut Scout",
            "Peanut President", "Ice Cream Chef", "Ice Cream Commander",
            "Cookie Crafter", "Cake Guard", "Baking Staff", "Head Baker",
            "Cocoa Warrior", "Chocolate Bar Battler", "Sweet Thief",
            "Candy Rebel", "Candy Pirate", "Snow Demon", "Isle Outlaw",
            "Island Boy", "Sun-kissed Warrior", "Isle Champion",
        },
        Callback = function(Value)
            getgenv().SelectMob = Value
            pcall(rawset, _G, "SelectMob", Value)
        end
    })
end
Tabs.Main:AddToggle({
    Name = __DIO_T["Auto Kill Mob"],
    Default = false,
    Callback = function(Value)
        _G.AutoKillMob = Value
        if Value then
            __DIO_TweenBlockT = 0
        else
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(0.25) do
        if _G.AutoKillMob then
            pcall(function()
                local mobName = getgenv().SelectMob
                if type(mobName) ~= "string" or mobName == "" then mobName = _G.SelectMob end
                if type(mobName) ~= "string" or mobName == "" then
                    mobName = __DIO_DefaultMobName()
                    pcall(function() getgenv().SelectMob = mobName end)
                    pcall(rawset, _G, "SelectMob", mobName)
                end
                if type(mobName) ~= "string" or mobName == "" then return end
                local mob = GetConnectionEnemies(mobName)
                if mob then
                    repeat
                        __DIO_wait(0.1)
                        if not _G.AutoKillMob then break end
                        Attack.Kill(mob, true)
                    until not _G.AutoKillMob or not mob.Parent or mob:FindFirstChild("Humanoid") == nil or mob.Humanoid.Health <= 0
                else
                    local pos = (type(__DIO_MobSpawnPos) == "table") and __DIO_MobSpawnPos[mobName] or nil
                    if not pos and PosMsList then pos = PosMsList[mobName] end
                    if not pos then
                        pcall(function()
                            local __wo = workspace:FindFirstChild("_WorldOrigin")
                            local __sp = __wo and __wo:FindFirstChild("EnemySpawns")
                            if __sp then
                                for _, s in ipairs(__sp:GetChildren()) do
                                    if s.Name == mobName or string.find(s.Name, mobName, 1, true) then
                                        pos = s.CFrame * CFrame.new(0, 20, 0)
                                        break
                                    end
                                end
                            end
                        end)
                    end
                    if pos then
                        _tp(pos)
                        __DIO_wait(0.4)
                    else
                        __DIO_TNotify("Auto Kill Mob", "Khong tim thay toa do dao cua mob: " .. tostring(mobName), 3)
                        __DIO_wait(1)
                    end
                end
            end)
        end
    end
end, "L4212")
Tabs.Main:AddSection("Farm All Island")
local Sea1_Islands = {
    ["Pirates"] = {
        CFrame = CFrame.new(-2709.67944, 24.5206585, 2104.24585, -0.744724929, -3.97967455e-08, -0.667371571, 4.32403588e-08, 1, -1.07884304e-07, 0.667371571, -1.09201515e-07, -0.744724929),
        Mobs = {"Bandit"}
    },
    ["Marine"] = {
        CFrame = CFrame.new(-2709.67944, 24.5206585, 2104.24585, -0.744724929, -3.97967455e-08, -0.667371571, 4.32403588e-08, 1, -1.07884304e-07, 0.667371571, -1.09201515e-07, -0.744724929),
        Mobs = {"Trainee"}
    },
    ["Jungle"] = {
        CFrame = CFrame.new(-1600, 36, 150),
        Mobs = {"Monkey", "Gorilla"}
    },
    ["Pirate Village"] = {
        CFrame = CFrame.new(-1100, 4, 3850),
        Mobs = {"Pirate", "Brute"}
    },
    ["Desert"] = {
        CFrame = CFrame.new(1090, 7, 4370),
        Mobs = {"Desert Bandit", "Desert Officer"}
    },
    ["Frozen Village"] = {
        CFrame = CFrame.new(1200, 28, -1500),
        Mobs = {"Snow Bandit", "Snowman"}
    },
    ["Marine Fortress"] = {
        CFrame = CFrame.new(-4500, 20, 4250),
        Mobs = {"Chief Petty Officer"}
    },
    ["Skylands Lower"] = {
        CFrame = CFrame.new(-5000, 700, -2500),
        Mobs = {"Sky Bandit", "Dark Master"}
    },
    ["Prison"] = {
        CFrame = CFrame.new(4875, 6, 735),
        Mobs = {"Prisoner", "Dangerous Prisoner"}
    },
    ["Colosseum"] = {
        CFrame = CFrame.new(-1500, 60, -290),
        Mobs = {"Toga Warrior", "Gladiator"}
    },
    ["Magma Village"] = {
        CFrame = CFrame.new(-5200, 8, 8400),
        Mobs = {"Military Soldier", "Military Spy"}
    },
    ["Underwater City"] = {
        CFrame = CFrame.new(61160, 5, 1819),
        Mobs = {"Fishman Warrior", "Fishman Commando"}
    },
    ["Skylands Upper"] = {
        CFrame = CFrame.new(-7880, 5545, -380),
        Mobs = {"Shanda", "Royal Squad", "Royal Soldier"}
    }
}
local Sea2_Islands = {
    ["Kingdom of Rose"] = {
        CFrame = CFrame.new(-321, 73, 297),
        Mobs = {
            "Raider",
            "Mercenary",
            "Swan Pirate",
            "Factory Staff"
        }
    },
    ["Green Zone"] = {
        CFrame = CFrame.new(-2447, 73, -3211),
        Mobs = {
            "Marine Lieutenant",
            "Marine Captain"
        }
    },
    ["Graveyard Island"] = {
        CFrame = CFrame.new(-9515, 142, 5536),
        Mobs = {
            "Zombie",
            "Vampire"
        }
    },
    ["Snow Mountain"] = {
        CFrame = CFrame.new(561, 401, -5306),
        Mobs = {
            "Snow Trooper",
            "Winter Warrior"
        }
    },
    ["Hot and Cold (Cold)"] = {
        CFrame = CFrame.new(-6026, 15, -5062),
        Mobs = {
            "Lab Subordinate",
            "Horned Warrior"
        }
    },
    ["Hot and Cold (Hot)"] = {
        CFrame = CFrame.new(-5478, 15, -5240),
        Mobs = {
            "Magma Ninja",
            "Lava Pirate"
        }
    },
    ["Cursed Ship"] = {
        CFrame = CFrame.new(902, 126, 33071),
        Mobs = {
            "Ship Deckhand",
            "Ship Engineer",
            "Ship Steward",
            "Ship Officer"
        }
    },
    ["Ice Castle"] = {
        CFrame = CFrame.new(6137, 294, -6747),
        Mobs = {
            "Arctic Warrior",
            "Snow Lurker"
        }
    },
    ["Forgotten Island"] = {
        CFrame = CFrame.new(-3043, 238, -10191),
        Mobs = {
            "Sea Soldier",
            "Water Fighter"
        }
    }
}
local Sea3_Islands = {
    ["Port Town"] = {
        CFrame = CFrame.new(-290, 44, 5450),
        Mobs = {
            "Pirate Millionaire",
            "Pistol Billionaire"
        }
    },
    ["Hydra Island"] = {
        CFrame = CFrame.new(5228, 604, 345),
        Mobs = {
            "Dragon Crew Warrior",
            "Dragon Crew Archer",
            "Female Islander",
            "Giant Islander",
            "Training Dummy"
        }
    },
    ["Great Tree"] = {
        CFrame = CFrame.new(2682, 1682, -7190),
        Mobs = {
            "Marine Commodore",
            "Marine Rear Admiral"
        }
    },
    ["Floating Turtle"] = {
        CFrame = CFrame.new(-12000, 331, -8500),
        Mobs = {
            "Forest Pirate",
            "Mythological Pirate",
            "Jungle Pirate",
            "Musketeer Pirate",
            "Fishman Raider",
            "Fishman Captain"
        }
    },
    ["Haunted Castle"] = {
        CFrame = CFrame.new(-9515, 142, 5536),
        Mobs = {
            "Reborn Skeleton",
            "Living Zombie",
            "Demonic Soul",
            "Posessed Mummy"
        }
    },
    ["Sea of Treats"] = {
        CFrame = CFrame.new(-1145, 13, -14450),
        Mobs = {
            "Peanut Scout",
            "Peanut President",
            "Ice Cream Commander",
            "Cookie Crafter",
            "Cake Guard",
            "Baking Staff",
            "Head Baker",
            "Cocoa Warrior",
            "Chocolate Bar Battler",
            "Sweet Thief",
            "Candy Rebel"
        }
    },
    ["Tiki Outpost"] = {
        -- FIX: toa do cu Z = -17300 nam giua bien (tween ra sea khi chon dao Tiki).
        -- Tiki Outpost that su o XZ ~(-16270, 1370) (khop cframenpc tau ngam + diem pha binh Tyrant).
        CFrame = CFrame.new(-16200, 90, 1300),
        Mobs = {
            "Isle Outlaw",
            "Island Boy",
            "Sun-kissed Warrior",
            "Isle Champion"
        }
    },
    ["Submerged Island"] = {
        CFrame = CFrame.new(-3200, -10, -10000),
        Mobs = {
            "Reef Bandit",
            "Coral Pirate",
            "Sea Chanter",
            "Ocean Prophet",
            "High Disciple",
            "Grand Devotee"
        }
    }
}
if World1 then
    Tabs.Main:AddDropdown({
        Name = __DIO_T["Select Island"],
        Options = {"Pirates", "Marine", "Jungle", "Pirate Village", "Desert", "Frozen Village", "Marine Fortress", "Skylands Lower", "Prison", "Colosseum", "Magma Village", "Underwater City", "Skylands Upper"},
        Callback = function(Value)
            _G.SelectIsland = Value
        end
    })
end
if World2 then
    Tabs.Main:AddDropdown({
        Name = __DIO_T["Select Island"],
        Options = {"Kingdom of Rose", "Green Zone", "Graveyard Island", "Snow Mountain", "Hot and Cold (Cold)", "Hot and Cold (Hot)", "Cursed Ship", "Ice Castle", "Forgotten Island"},
        Callback = function(Value)
            _G.SelectIsland = Value
        end
    })
end
if World3 then
    Tabs.Main:AddDropdown({
        Name = __DIO_T["Select Island"],
        Options = {"Port Town", "Hydra Island", "Great Tree", "Floating Turtle", "Haunted Castle", "Sea of Treats", "Tiki Outpost", "Submerged Island"},
        Callback = function(Value)
            _G.SelectIsland = Value
        end
    })
end
local IslandData
if World1 then
    IslandData = Sea1_Islands
elseif World2 then
    IslandData = Sea2_Islands
elseif World3 then
    IslandData = Sea3_Islands
end
__DIO_MobSpawnPos = __DIO_MobSpawnPos or {}
do
    local __islandSets = { Sea1_Islands, Sea2_Islands, Sea3_Islands }
    for __s = 1, 3 do
        local __set = __islandSets[__s]
        if type(__set) == "table" then
            for __islandName, __data in pairs(__set) do
                if type(__data) == "table" and __data.CFrame and type(__data.Mobs) == "table" then
                    for __m = 1, #__data.Mobs do
                        local __mn = __data.Mobs[__m]
                        if type(__mn) == "string" and __DIO_MobSpawnPos[__mn] == nil then
                            __DIO_MobSpawnPos[__mn] = __data.CFrame * CFrame.new(0, 20, 0)
                        end
                    end
                end
            end
        end
    end
    for __mn, __cf in pairs(PosMsList or {}) do
        if __DIO_MobSpawnPos[__mn] == nil and typeof(__cf) == "CFrame" then
            __DIO_MobSpawnPos[__mn] = __cf * CFrame.new(0, 20, 0)
        end
    end
end
Tabs.Main:AddToggle({
    Name = __DIO_T["Auto Farm All Island"],
    Default = false,
    Callback = function(Value)
        _G.AutoFarmIsland = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait() do
        if not _G.AutoFarmIsland then continue end
        if not _G.SelectIsland then continue end
        if not IslandData then continue end
        local island = IslandData[_G.SelectIsland]
        if not island then continue end
        local islandPos = island.CFrame
        local mobs = island.Mobs
        local MobMap = {}
        for _, name in ipairs(mobs) do
            MobMap[name] = true
        end
        local found = false
        for _, v in pairs(workspace.Enemies:GetChildren()) do
            if MobMap[v.Name]
            and not __DIO_IsGhost(v)
            and v:FindFirstChild("Humanoid")
            and v:FindFirstChild("HumanoidRootPart")
            and v.Humanoid.Health > 0 then
                found = true
                repeat
                    _tp(v.HumanoidRootPart.CFrame * CFrame.new(0,10,0))
                    Attack.Kill(v, true)
                    if __DIO_GhostCheck(v) then break end
                    __DIO_wait()
                until not _G.AutoFarmIsland
                   or not v.Parent
                   or v.Humanoid.Health <= 0
            end
        end
        if not found then
            _tp(islandPos)
        end
    end
end, "L4526")
local function HopServer()
	local Http = __SVC_HTTP
	local TPS = __SVC_TP
	local Api = "https://games.roblox.com/v1/games/"
	local PlaceID = game.PlaceId
	local foundServer = false
	local Cursor = nil
	local attempts = 0
	repeat
		attempts = attempts + 1
		local success, result = pcall(function()
			return game:HttpGet(Api .. PlaceID .. "/servers/Public?sortOrder=Asc&limit=100" .. (Cursor and ("&cursor=" .. Cursor) or ""))
		end)
		if success and result then
			local data = Http:JSONDecode(result)
			if data and data.data then
				for _, v in pairs(data.data) do
					if v.playing < v.maxPlayers and v.id ~= game.JobId then
						foundServer = true
						TPS:TeleportToPlaceInstance(PlaceID, v.id)
						break
					end
				end
				Cursor = data.nextPageCursor
			end
		end
		if not foundServer then __DIO_wait(0.3) end
	until foundServer or attempts >= 8 or not Cursor
end

__DIO_EliteNames = { Diablo = true, Urban = true, Deandre = true }
__DIO_DetectEliteHunter = function()
    local __ok, __boss = pcall(function()
        local __rs = game:GetService("ReplicatedStorage")
        for _, __v in pairs(__rs:GetChildren()) do
            if __v:IsA("Model") and __DIO_EliteNames[__v.Name] and Attack.Alive(__v) then
                return __v
            end
        end
        local __en = workspace:FindFirstChild("Enemies")
        if __en then
            for _, __v in pairs(__en:GetChildren()) do
                if __v:IsA("Model") and __DIO_EliteNames[__v.Name] and Attack.Alive(__v) then
                    return __v
                end
            end
        end
        return nil
    end)
    if __ok then return __boss end
    return nil
end
__DIO_EliteTakeQuest = function()
    pcall(function() replicated.Remotes.CommF_:InvokeServer("AbandonQuest") end)
    __DIO_wait(0.35)
    local __res = nil
    pcall(function() __res = replicated.Remotes.CommF_:InvokeServer("EliteHunter") end)
    return __res
end
__DIO_EliteFight = function(boss, flag)
    if not boss or not boss.Parent then return end
    pcall(__DIO_3nn_SizePart, boss)
    local __hrp = boss:FindFirstChild("HumanoidRootPart")
    if __hrp then _tp(__hrp.CFrame * CFrame.new(0, 30, 0)) end
    repeat
        __DIO_wait(0.25)
        pcall(__DIO_3nn_SizePart, boss)
        Attack.Kill(boss, flag)
    until not flag or not boss.Parent or not Attack.Alive(boss)
end
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            if _G.FarmEliteH then
                local __boss = __DIO_DetectEliteHunter()
                if __boss then
                    local __q = __DIO_GetCurrentQuest()
                    local __txt = __q.QuestText or ""
                    if (not __q.IsActive) or (not string.find(__txt, __boss.Name, 1, true)) then
                        local __res = __DIO_EliteTakeQuest()
                        if __res == nil or string.find(tostring(__res), "Cooldown")
                           or string.find(tostring(__res), "Wait") then
                            HopServer()
                            return
                        end
                        __DIO_wait(1)
                    else
                        __DIO_EliteFight(__boss, _G.FarmEliteH)
                    end
                else
                    __DIO_wait(5)
                    HopServer()
                end
            end
        end)
    end
end, "L4601")
Tabs.Main:AddSection("Dough king Farm")
TELEPORT_DISTANCE_THRESHOLD = 15
TeleportConditional = function(hrp, targetCFrame, threshold)
    if not hrp or not targetCFrame then return end
    local dist = (targetCFrame.Position - hrp.Position).Magnitude
    if dist > threshold then
        _tp(targetCFrame)
    end
end
local __DIO_CakeQuestCF  = CFrame.new(-1927.92, 37.80, -12842.54)
local __DIO_CakeSpawnCF  = CFrame.new(-2091.91, 70.00, -12142.83)
local __DIO_CakePortalCF = CFrame.new(-2151.82, 149.32, -12404.91)
local __DIO_CAKE_MOBS = {
    ["Cookie Crafter"] = true,
    ["Cake Guard"] = true,
    ["Baking Staff"] = true,
    ["Head Baker"] = true
}
__DIO_CakeBoss = nil
__DIO_SafeLoop(function()
    while __DIO_wait() do
        if _G.Auto_Cake_Prince then
            pcall(function()
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local enemies = workspace:FindFirstChild("Enemies")
                if not enemies then return end

                if __DIO_3nn_AutoQuest("Cake") then return end
                local mapW = workspace:FindFirstChild("Map")
                local mirror = mapW and mapW:FindFirstChild("CakeLoaf")
                mirror = mirror and mirror:FindFirstChild("BigMirror")
                local other = mirror and mirror:FindFirstChild("Other")
                local portalOpen = other and other.Transparency == 0
                local boss = __DIO_CakeBoss
                if not boss or not boss.Parent then
                    boss = enemies:FindFirstChild("Cake Prince") or enemies:FindFirstChild("Dough King")
                    __DIO_CakeBoss = boss
                end
                if not boss and not portalOpen and (hrp.Position - __DIO_CakeSpawnCF.Position).Magnitude > 3000 then
                    _tp(__DIO_CakeSpawnCF)
                    return
                end
                if boss then
                    local hum = boss:FindFirstChild("Humanoid")
                    local broot = boss:FindFirstChild("HumanoidRootPart")
                    if hum and broot and hum.Health > 0 then
                        repeat
                            if not _G.Auto_Cake_Prince then break end
                            local hr2 = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                            if not hr2 then break end
                            local hum2 = boss:FindFirstChild("Humanoid")
                            local bro2 = boss:FindFirstChild("HumanoidRootPart")
                            if not boss.Parent or not hum2 or not bro2 then break end
                            if hum2.Health <= 0 then
                                __DIO_CakeBoss = nil
                                break
                            end
                            Attack.Kill2(boss, true)
                            if __DIO_GhostCheck(boss) then
                                __DIO_CakeBoss = nil
                                break
                            end
                            __DIO_wait()
                        until not _G.Auto_Cake_Prince
                           or not boss.Parent
                           or (boss:FindFirstChild("Humanoid") and boss.Humanoid.Health <= 0)
                    else
                        __DIO_CakeBoss = nil
                    end
                    return
                end
                if portalOpen then
                    if (hrp.Position - __DIO_CakePortalCF.Position).Magnitude < 500 then
                        TeleportConditional(hrp, __DIO_CakePortalCF, TELEPORT_DISTANCE_THRESHOLD)
                    else
                        _tp(__DIO_CakePortalCF)
                    end
                    return
                end
                local bestMob, bestD = nil, math.huge
                for _, mob in ipairs(enemies:GetChildren()) do
                    if __DIO_CAKE_MOBS[mob.Name] and not __DIO_IsGhost(mob) then
                        local hum = mob:FindFirstChild("Humanoid")
                        local mr = mob:FindFirstChild("HumanoidRootPart")
                        if hum and mr and hum.Health > 0 then
                            local d = (mr.Position - hrp.Position).Magnitude
                            if d < bestD then
                                bestD = d
                                bestMob = mob
                            end
                        end
                    end
                end
                if bestMob then
                    repeat
                        if not _G.Auto_Cake_Prince then break end
                        if not bestMob.Parent then break end
                        local bmH = bestMob:FindFirstChild("Humanoid")
                        if not bmH or bmH.Health <= 0 then break end
                        if enemies:FindFirstChild("Cake Prince") or enemies:FindFirstChild("Dough King") then
                            __DIO_CakeBoss = enemies:FindFirstChild("Cake Prince") or enemies:FindFirstChild("Dough King")
                            break
                        end
                        if other and other.Transparency == 0 then break end
                        Attack.Kill2(bestMob, true)
                        if __DIO_GhostCheck(bestMob) then break end
                        __DIO_wait()
                    until not _G.Auto_Cake_Prince or not bestMob.Parent
                       or (bestMob:FindFirstChild("Humanoid") and bestMob.Humanoid.Health <= 0)
                    return
                end

                TeleportConditional(hrp, __DIO_CakeQuestCF * CFrame.new(0, 0, 12), TELEPORT_DISTANCE_THRESHOLD)
            end)
        end
    end
end, "L4689")
__DIO_SafeLoop(function()
    while __DIO_wait(2) do
        if _G.AutoSpawnCP then
            pcall(function()
                local CommF = game.ReplicatedStorage.Remotes.CommF_
                local enemies = workspace.Enemies
                local bigMirror = workspace.Map.CakeLoaf:FindFirstChild("BigMirror")
                if not bigMirror then return end
                if enemies:FindFirstChild("Cake Prince") then return end
                if bigMirror.Other.Transparency == 0 then return end
                CommF:InvokeServer("CakePrinceSpawner", true)
            end)
        end
    end
end, "L4825")
_G.AutoAttackDoughKing = false
_G.AutoSummonDoughKing = false
_G.AutoHopDoughKing = false
local __DK_COCOA_MOBS = { "Cocoa Warrior", "Chocolate Bar Battler" }
local __DK_ELITE = { "Deandre", "Urban", "Diablo" }
local __DK_STAGE = CFrame.new(-1943.6765, 251.5095, -12337.8809)
local __DK_COCOA_CF = CFrame.new(402.7189025878906, 81.06050109863281, -12259.54296875)
__DIO_DKFindBoss = function()
    for _, __root in ipairs({ __SVC_RS, workspace:FindFirstChild("Enemies") }) do
        if __root then
            local b = __root:FindFirstChild("Dough King")
            if b and __DIO_MobAliveRoot(b) then return b end
        end
    end
end
__DIO_DKSmack = function(mob)
    if not mob or not mob.Parent then return end
    pcall(__DIO_3nn_SizePart, mob)
    local __ch = plr.Character
    local __eq = __ch and __ch:FindFirstChildOfClass("Tool")
    local __off = (__eq and __eq.ToolTip == "Blox Fruit") and -7 or 7
    local __mr = mob:FindFirstChild("HumanoidRootPart")
    if __mr then _tp(__mr.CFrame * CFrame.new(__off, 20, 0)) end
    pcall(__DIO_3nn_M1, mob)
end
Tabs.Main:AddToggle({
    Name = __DIO_T["Attack Dough King"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoAttackDoughKing = (Value == true)
        if _G.AutoAttackDoughKing then
            __DIO_TweenBlockT = 0
            pcall(function() __DIO_TweenOnIfAnyFlag() end)
            pcall(function() __DIO_Wake(true) end)
        else
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
Tabs.Main:AddToggle({
    Name = __DIO_T["Summon Dough King"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoSummonDoughKing = (Value == true)
        if Value and not _G.AutoAttackDoughKing then
            print("[DIO] Turn On Attack Dough King Plz")
        end
    end
})
Tabs.Main:AddToggle({
    Name = __DIO_T["Hop Find Dough King"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoHopDoughKing = (Value == true)
        if Value and not _G.AutoAttackDoughKing then
            print("[DIO] Turn On Attack Dough King Plz")
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(0.5) do
        if _G.AutoSummonDoughKing then
            pcall(function()
                if GetBP("Sweet Chalice") and not __DIO_DKFindBoss() then
                    replicated.Remotes.CommF_:InvokeServer("CakePrinceSpawner")
                    __DIO_wait(2)
                end
            end)
        end
    end
end, "L-DKSUM")
__DIO_DKHopT = 0
__DIO_SafeLoop(function()
    while __DIO_wait(0.25) do
        if _G.AutoAttackDoughKing then
            pcall(function()
                local char = plr.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then return end
                local boss = __DIO_DKFindBoss()
                if boss then
                    repeat
                        __DIO_wait()
                        if not _G.AutoAttackDoughKing then break end
                        if not boss.Parent or not __DIO_MobAliveRoot(boss) then break end
                        __DIO_DKSmack(boss)
                    until not _G.AutoAttackDoughKing or not boss.Parent or not __DIO_MobAliveRoot(boss)
                    return
                end
                if _G.AutoHopDoughKing then
                    if tick() - (__DIO_DKHopT or 0) > 5 then
                        __DIO_DKHopT = tick()
                        if not __DIO_DKFindBoss() and _G.AutoHopDoughKing then
                            HopServer()
                        end
                    end
                    return
                end
                if not _G.AutoSummonDoughKing then return end
                if GetBP("Sweet Chalice") then
                    local __hrp = char:FindFirstChild("HumanoidRootPart")
                    if __hrp and (__DK_STAGE.Position - __hrp.Position).Magnitude > 20 then
                        _tp(__DK_STAGE)
                    end
                    return
                end
                if (GetM("Conjured Cocoa") or 0) < 10 then
                    local mob = GetConnectionEnemies(__DK_COCOA_MOBS)
                    if mob then
                        repeat
                            __DIO_wait()
                            if not _G.AutoAttackDoughKing then break end
                            if not mob.Parent or not __DIO_MobAliveRoot(mob) then break end
                            __DIO_DKSmack(mob)
                        until not _G.AutoAttackDoughKing or not mob.Parent or not __DIO_MobAliveRoot(mob)
                    else
                        _tp(__DK_COCOA_CF)
                    end
                    return
                end
                if not GetBP("God's Chalice") then
                    local elite
                    for _, __root in ipairs({ __SVC_RS, workspace:FindFirstChild("Enemies") }) do
                        if __root then
                            for _, __nm in ipairs(__DK_ELITE) do
                                local __e = __root:FindFirstChild(__nm)
                                if __e and __DIO_MobAliveRoot(__e) then elite = __e break end
                            end
                        end
                        if elite then break end
                    end
                    if elite then
                        local __take = false
                        pcall(function()

                            local __txt = __DIO_3nn_GetTrackedQuestText() or ""
                            if __txt == "" or not string.find(__txt, elite.Name, 1, true) then
                                __take = true
                            end
                        end)
                        if __take then
                            replicated.Remotes.CommF_:InvokeServer("AbandonQuest")
                            replicated.Remotes.CommF_:InvokeServer("EliteHunter")
                        else
                            repeat
                                __DIO_wait()
                                if not _G.AutoAttackDoughKing then break end
                                if not elite.Parent or not __DIO_MobAliveRoot(elite) then break end
                                __DIO_DKSmack(elite)
                            until not _G.AutoAttackDoughKing or not elite.Parent or not __DIO_MobAliveRoot(elite)
                        end
                    else
                        __DIO_wait(2)
                    end
                    return
                end
                pcall(function()
                    replicated.Remotes.CommF_:InvokeServer("SweetChaliceNpc")
                end)
                __DIO_wait(1)
            end)
        end
    end
end, "L-DK")

task.spawn(function()
    while true do
        local __okAR, __errAR = pcall(function()
            while __DIO_wait(0.1) do
                if _G.AutoFarm_Bone then
                    pcall(function()
                        local char = plr.Character
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if hum then
                            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                            local __st = hum:GetState()
                            if __st == Enum.HumanoidStateType.Ragdoll
                               or __st == Enum.HumanoidStateType.FallingDown
                               or hum.Sit or hum.PlatformStand then
                                hum.Sit = false
                                hum.PlatformStand = false
                                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                            end
                        end
                    end)
                else
                    pcall(function()
                        local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
                        if hum then
                            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                        end
                    end)
                end
            end
        end)
        if not __okAR then warn("[DIO] AntiRagdoll Bone restarted: " .. tostring(__errAR)) end
        task.wait(0.5)
    end
end)
local __DIO_BoneMobs = {
    ["Reborn Skeleton"] = true,
    ["Living Zombie"] = true,
    ["Demonic Soul"] = true,
    ["Posessed Mummy"] = true
}
local __DIO_BoneNpcCF = CFrame.new(-9516.99, 172.01, 6078.46)
local __DIO_BoneSpawn = CFrame.new(-9495.68, 453.58, 5977.34)
__DIO_SafeLoop(function()
    while __DIO_wait() do
        if _G.AutoFarm_Bone then
            pcall(function()
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                if hrp:FindFirstChild("AntiFall") then hrp.AntiFall:Destroy() end

                if __DIO_3nn_AutoQuest("Bone") then return end
                pcall(__DIO_GhostClean)
                local function GetClosestBoneMob(hrpPos)
                    local en = workspace:FindFirstChild("Enemies")
                    if not en then return nil end
                    local closest, shortest = nil, math.huge
                    for _, mob in ipairs(en:GetChildren()) do
                        if __DIO_BoneMobs[mob.Name] and not __DIO_IsGhost(mob) then
                            local hum = mob:FindFirstChild("Humanoid")
                            local root = mob:FindFirstChild("HumanoidRootPart")
                            if hum and root and hum.Health > 0 then
                                local d = (root.Position - hrpPos).Magnitude
                                if d < shortest then
                                    shortest = d
                                    closest = mob
                                end
                            end
                        end
                    end
                    return closest
                end
                local mob = GetClosestBoneMob(hrp.Position)
                if mob then
                    __DIO_EquipFarmWeapon(mob)
                    repeat
                        if not _G.AutoFarm_Bone then break end
                        if not mob.Parent then break end
                        local th = mob:FindFirstChild("Humanoid")
                        local tr = mob:FindFirstChild("HumanoidRootPart")
                        if not th or not tr or th.Health <= 0 then break end
                        Attack.Kill(mob, _G.AutoFarm_Bone)
                        if __DIO_GhostCheck(mob) then
                            _tp(__DIO_BoneSpawn)
                            break
                        end
                        __DIO_wait()
                    until not _G.AutoFarm_Bone or not mob.Parent
                       or (mob:FindFirstChild("Humanoid") and mob.Humanoid.Health <= 0)
                    return
                end

                if (__DIO_BoneSpawn.Position - hrp.Position).Magnitude > 10 then
                    _tp(__DIO_BoneSpawn)
                end
            end)
        else
            pcall(function()
                local char = plr.Character
                local hrp2 = char and char:FindFirstChild("HumanoidRootPart")
                if hrp2 and hrp2:FindFirstChild("AntiFall") then
                    hrp2.AntiFall:Destroy()
                end
            end)
        end
    end
end, "L5024")
function Check_Eye()
    local mapW = workspace:FindFirstChild("Map")
    local tiki = mapW and mapW:FindFirstChild("TikiOutpost")
    local islandM = tiki and tiki:FindFirstChild("IslandModel")
    if not islandM then return 0, false end
    local e = islandM
    local eyes = {
        e.Eye1,
        e.Eye2,
        e.IslandChunks and e.IslandChunks.E and e.IslandChunks.E.Eye3,
        e.IslandChunks and e.IslandChunks.E and e.IslandChunks.E.Eye4
    }
    local count = 0
    for _, eye in ipairs(eyes) do
        if eye and eye.Transparency ~= 1 then
            count = count + 1
        end
    end
    local isFull = (count == 4)
    return count, isFull
end
local __prevEye = nil
__DIO_SafeLoop(function()
    local alerted = false
    while __DIO_wait(1) do
        local ok, current, full = pcall(Check_Eye)
        if not ok then current, full = 0, false end
        local __eTxt = "Eyes: " .. tostring(current) .. "/4"
        if __eTxt ~= __prevEye then __prevEye = __eTxt EyeStatus:SetDesc(__eTxt) end
        if full and not alerted then
            alerted = true
        elseif not full then
            alerted = false
        end
    end
end, "L5158")

__DIO_FindTyrantBoss = function()
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return nil end
    local boss = enemies:FindFirstChild("Tyrant of the Skies")
    if boss and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health > 0 and boss:FindFirstChild("HumanoidRootPart") then
        return boss
    end
    for _, m in pairs(enemies:GetChildren()) do
        if m and tostring(m.Name):find("Tyrant of the Skies", 1, true)
            and m:FindFirstChild("Humanoid") and m.Humanoid.Health > 0
            and m:FindFirstChild("HumanoidRootPart") then
            return m
        end
    end
    return nil
end
__DIO_KillTyrantBoss = function()
    local boss = __DIO_FindTyrantBoss()
    if not boss then return false end
    repeat
        if not _G.FarmTyrant then break end
        boss = __DIO_FindTyrantBoss()
        if not boss then break end
        local ch = plr.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local bhrp = boss:FindFirstChild("HumanoidRootPart")
        if hrp and bhrp and (hrp.Position - bhrp.Position).Magnitude > 350 then
            _tp(bhrp.CFrame * CFrame.new(0, 45, 20))
        end
        if Attack and Attack.Kill then
            Attack.Kill(boss, _G.FarmTyrant)
        end
        __DIO_wait()
    until not _G.FarmTyrant or not boss or not boss.Parent or not boss:FindFirstChild("Humanoid") or boss.Humanoid.Health <= 0
    return true
end
__DIO_SafeLoop(function()
    while __DIO_wait(Sec) do
        if _G.FarmTyrant then
            pcall(function()
                if not plr.Character then return end
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                if __DIO_KillTyrantBoss and __DIO_KillTyrantBoss() then return end

                if __DIO_3nn_AutoQuest("Tyrant") then return end
                if __DIO_KillTyrantBoss and __DIO_KillTyrantBoss() then return end

                local mobList = {"Serpent Hunter","Skull Slayer","Isle Champion","Sun-kissed Warrior"}
                local __farmedMob = false
                for _, mobName in ipairs(mobList) do
                    if not _G.FarmTyrant then return end
                    for _, mob in pairs(workspace.Enemies:GetChildren()) do
                        if not _G.FarmTyrant then return end
                        if __DIO_FindTyrantBoss and __DIO_FindTyrantBoss() then return end
                        if mob and mob.Name == mobName and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                            __farmedMob = true
                            if (hrp.Position - mob.HumanoidRootPart.Position).Magnitude > 5000 then
                                _tp(mob.HumanoidRootPart.CFrame * CFrame.new(0,30,0))
                                local t0 = tick()
                                repeat __DIO_wait(0.25) hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") until not _G.FarmTyrant or not hrp or (hrp.Position - mob.HumanoidRootPart.Position).Magnitude <= 6 or tick() - t0 > 8
                            end
                            repeat
                                if not _G.FarmTyrant then break end
                                if __DIO_FindTyrantBoss and __DIO_FindTyrantBoss() then return end
                                if Attack and Attack.Kill then
                                    Attack.Kill(mob, _G.FarmTyrant)
                                end
                                __DIO_wait()
                            until not _G.FarmTyrant or not mob.Parent or mob.Humanoid.Health <= 0
                        end
                    end
                end
                if __farmedMob then return end

                if __DIO_3nn_TyrantEyesFull() then
                    local __tree = __DIO_3nn_TyrantTree()
                    if __tree then
                        local __pivot = __tree:GetPivot()
                        if (hrp.Position - __pivot.Position).Magnitude > 12 then
                            _tp(__pivot)
                        else
                            pcall(function()
                                if type(GetBP) == "function" and GetBP("Skull Guitar") then
                                    pcall(EquipWeapon, "Skull Guitar")
                                end
                                for _, __sk in ipairs({"Z", "X", "C", "V", "F"}) do
                                    if not _G.FarmTyrant then break end
                                    vim1:SendKeyEvent(true, __sk, false, game)
                                    __DIO_wait(0.12)
                                    vim1:SendKeyEvent(false, __sk, false, game)
                                    __DIO_wait(0.12)
                                end
                            end)
                        end
                        return
                    end
                end
                if __DIO_PhaBinhSummon then pcall(__DIO_PhaBinhSummon) end
            end)
        end
    end
end, "L5174")
local function sendSkillKey(skillKey)
    local virtualInputManager = __SVC_VIM
    virtualInputManager:SendKeyEvent(true, skillKey, false, game)
    __DIO_wait(0.05)
    virtualInputManager:SendKeyEvent(false, skillKey, false, game)
end
local function equipAndUseSkill(toolType)
    local character = plr.Character
    local backpack = plr.Backpack
    if not (character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0) then return end
    for _, item in pairs(backpack:GetChildren()) do
        if item:IsA("Tool") and item.ToolTip == toolType then
            item.Parent = character
            __DIO_wait(0.12)
            for _, skill in ipairs({"Z", "X", "C", "V", "F"}) do
                if not _G.FarmTyrant then break end
                pcall(function() sendSkillKey(skill) end)
                __DIO_wait(0.12)
            end
            item.Parent = backpack
            break
        end
    end
end
local PhaBinhPoints = {
    CFrame.new(-16332.5263671875, 158.07200622558594, 1440.324951171875),
    CFrame.new(-16288.609375, 158.16700744628906, 1470.3680419921875),
    CFrame.new(-16245.412109375, 158.43699645996094, 1463.365966796875),
    CFrame.new(-16212.46875, 158.16700744628906, 1466.343994140625),
    CFrame.new(-16211.9462890625, 158.07200622558594, 1322.39794921875),
    CFrame.new(-16260.921875, 154.92100524902344, 1323.615966796875),
    CFrame.new(-16297.0595703125, 159.322998046875, 1317.2239990234375),
    CFrame.new(-16335.0966796875, 159.33399963378906, 1324.885986328125),
}
__DIO_PhaBinhSummon = function()
    if not (plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health > 0) then return end
    for _, point in ipairs(PhaBinhPoints) do
        if not _G.FarmTyrant then return end
        local __wsEnemies = workspace:FindFirstChild("Enemies")
        if __wsEnemies and __wsEnemies:FindFirstChild("Tyrant of the Skies") then return end
        _tp(point)
        local arrived = false
        local start = tick()
        while tick() - start < 12 and not arrived and _G.FarmTyrant do
            local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local dist = (hrp.Position - point.Position).Magnitude
            if dist <= 3 then
                arrived = true
                break
            end
            __DIO_wait(0.1)
        end
        if _G.FarmTyrant and arrived then
            equipAndUseSkill("Melee")
            equipAndUseSkill("Sword")
            equipAndUseSkill("Gun")
        end
    end
end
Tabs.Main:AddSection("Farm Material")
Tabs.Main:AddDropdown({
Name = __DIO_T["Choose Material"],
		Description = "",
		Options = MaterialList,
		Callback = function(Value)
			getgenv().SelectMaterial = Value
			SelectMaterial = Value
		end
		})
Toggle = Tabs.Main:AddToggle({
Name = __DIO_T["Auto Farm Materials"],
Description = "",
Default = false,
Callback = function(Value)
    getgenv().AutoMaterial = Value
end})
__DIO_SafeLoop(function()
  local function processEnemy(v, EnemyName)
    if v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
      if v.Name == EnemyName then repeat __DIO_wait(0.25) Attack.Kill(v,getgenv().AutoMaterial) until not getgenv().AutoMaterial or not v.Parent or v.Humanoid.Health <= 0 end
    end
  end
  local function handleEnemySpawns()
    local __woES = __SVC_WS:FindFirstChild("_WorldOrigin")
    local __esES = __woES and __woES:FindFirstChild("EnemySpawns")
    if not __esES then return end
    for _, v in pairs(__esES:GetChildren()) do
      for _, EnemyName in ipairs(MMon or {}) do
        if string.find(v.Name, EnemyName) then
          if (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - v.Position).Magnitude >= 10 then
            _tp(v.CFrame * CFrame.new(0, 10, 0))
          end
        end
      end
    end
  end
  while __DIO_wait(1) do
    if getgenv().AutoMaterial then
      pcall(function()
        if getgenv().SelectMaterial then SelectMaterial = getgenv().SelectMaterial MaterialMon(getgenv().SelectMaterial) _tp(MPos) end
        for _, EnemyName in ipairs(MMon or {}) do
          for _, v in pairs(workspace.Enemies:GetChildren()) do processEnemy(v, EnemyName) end
        end
        handleEnemySpawns()
      end)
    end
  end
end, "L5314")
Tabs.Main:AddSection("Farm Boss")
		Tabs.Main:AddDropdown({
		Name = __DIO_T["Select Boss"],
		Description = "",
		Options = BossList,
		Callback = function(value)
			_G.FindBoss = value
		end
		})
local __DIO_FarmBossThr = false
FarmBoss = Tabs.Main:AddToggle({
    Name = __DIO_T["Auto Farm Boss"],
    Description = "",
    Default = false,
    Callback = function(value)
        _G.FarmBoss = value
        if value and not __DIO_FarmBossThr then
            __DIO_FarmBossThr = true
        __DIO_SafeLoop(function()
            while __DIO_wait(Sec) do
                if _G.FarmBoss then
                    pcall(function()
                        local HasQuest = QuestBeta()[2] ~= nil and QuestBeta()[3] ~= nil
                        local __qB = __DIO_GetCurrentQuest()
                        local QuestTitle = __qB.QuestText or ""
                        if _G.AcceptQuestBoss and HasQuest then
                            if not string.find(QuestTitle, QuestBeta()[0]) then
                                replicated.Remotes.CommF_:InvokeServer("AbandonQuest")
                            end
                            if not __qB.IsActive then
                                _tp(QuestBeta()[5])
                                if (Root.Position - QuestBeta()[5].Position).Magnitude <= 5 then
                                    replicated.Remotes.CommF_:InvokeServer("StartQuest", QuestBeta()[3], QuestBeta()[2])
                                end
                            elseif __qB.IsActive then
                                if workspace.Enemies:FindFirstChild(QuestBeta()[1]) then
                                    for i, v in pairs(workspace.Enemies:GetChildren()) do
                                        if Attack.Alive(v) and v.Name == QuestBeta()[1] then
                                            if string.find(QuestTitle, QuestBeta()[0]) then
                                                repeat
                                                    __DIO_wait(0.25)
                                                    Attack.Kill(v, _G.FarmBoss)
                                                until not _G.FarmBoss or v.Humanoid.Health <= 0 or not v.Parent or __DIO_QuestGone()
                                            else
                                                replicated.Remotes.CommF_:InvokeServer("AbandonQuest")
                                            end
                                        end
                                    end
                                else
                                    _tp(QuestBeta()[4])
                                    if replicated:FindFirstChild(QuestBeta()[1]) then
                                        _tp(replicated:FindFirstChild(QuestBeta()[1]).HumanoidRootPart.CFrame * CFrame.new(0, 30, 0))
                                    end
                                end
                            end
                        else
                            if workspace.Enemies:FindFirstChild(QuestBeta()[1]) then
                                for i, v in pairs(workspace.Enemies:GetChildren()) do
                                    if Attack.Alive(v) and v.Name == QuestBeta()[1] then
                                        repeat
                                            __DIO_wait(0.25)
                                            Attack.Kill(v, _G.FarmBoss)
                                        until not _G.FarmBoss or v.Humanoid.Health <= 0 or not v.Parent
                                    end
                                end
                            else
                                _tp(QuestBeta()[4])
                                if replicated:FindFirstChild(QuestBeta()[1]) then
                                    _tp(replicated:FindFirstChild(QuestBeta()[1]).HumanoidRootPart.CFrame * CFrame.new(0, 30, 0))
                                end
                            end
                        end
                    end)
                end
            end
        end, "L5365")
    end
    end
})
Tabs.Main:AddToggle({
    Name = __DIO_T["Auto Quest Boss"],
    Description = "",
    Default = true,
    Callback = function(Value)
        _G.AcceptQuestBoss = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
Tabs.Main:AddToggle({
   Name = __DIO_T["Auto Farm All Boss"],
    Default = false,
Callback = function(Value)
    _G.AutoFarmAllBoss = Value
end})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoFarmAllBoss then
            pcall(function()
                local player = game.Players.LocalPlayer
                if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return end
                local hrp = player.Character.HumanoidRootPart
                local nearestBoss, nearestDist = nil, math.huge
                for _, boss in pairs(workspace.Enemies:GetChildren()) do
                    if boss:FindFirstChild("HumanoidRootPart") and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health > 0 then
                        if table.find(BossList, boss.Name) then
                            local dist = (hrp.Position - boss.HumanoidRootPart.Position).Magnitude
                            if dist < nearestDist then
                                nearestBoss = boss
                                nearestDist = dist
                            end
                        end
                    end
                end
                if nearestBoss and nearestBoss:FindFirstChild("HumanoidRootPart") then
                    local bossHRP = nearestBoss.HumanoidRootPart
                    local humanoid = nearestBoss.Humanoid
                    repeat
                        __DIO_wait(0.1)
                        if not _G.AutoFarmAllBoss then break end
                        local targetCFrame = bossHRP.CFrame * CFrame.new(0, 5, 0)
                        if (hrp.Position - targetCFrame.Position).Magnitude > 100 then
                            player.Character:PivotTo(targetCFrame)
                        else
                            _tp(targetCFrame)
                        end
                        if Attack and typeof(Attack.Kill) == "function" then
                            Attack.Kill(nearestBoss, true)
                        end
                    until not nearestBoss.Parent or humanoid.Health <= 0 or not _G.AutoFarmAllBoss
                end
            end)
        end
    end
end, "L5451")
__DIO_BOOT("Load Services")
Tabs.Main:AddSection("Farm Mastery")
Tabs.Main:AddSlider({
    Name = __DIO_T["Health Farm Mastery"],
    Description = "",
    Min = 1,
    Max = 100,
    Default = 30,
    Increment = 1,
    Callback = function(Value)
        _G.HealthFarmMastery = Value
    end})
__DIO_MasteryWarnT = {}
function __DIO_MasteryWarn(tag, err)
    local now = tick()
    if now - (__DIO_MasteryWarnT[tag] or 0) < 5 then return end
    __DIO_MasteryWarnT[tag] = now
    warn("[DIO] Mastery " .. tostring(tag) .. " loi: " .. tostring(err))
end
function __DIO_MasteryDelay()
    local d = tonumber(getgenv().MasterySpamDelay)
    if d == nil then d = 2 end
    if d < 0.1 then d = 0.1 end
    return d
end
function __DIO_MasteryPace(flag, mob, base)
    if not mob then return end
    if not __DIO_UseMasteryNow(mob) then return end
    if not __DIO_CanUseSkillOn(mob, base) then return end
    local total = __DIO_MasteryDelay()
    local t0 = tick()
    while tick() - t0 < total do
        if _G[flag] ~= true then return end
        if not mob.Parent or not __DIO_MobAliveRoot(mob) then return end
        __DIO_wait(0.2)
    end
end
function __DIO_MasteryScan(names, maxDist)
    local en = workspace:FindFirstChild("Enemies")
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if not en or not hrp then return nil end
    local best, bestD = nil, maxDist or math.huge
    for _, mob in ipairs(en:GetChildren()) do
        if mob:IsA("Model") and (names == nil or table.find(names, mob.Name)) then
            local hum = mob:FindFirstChildOfClass("Humanoid")
            local root = mob:FindFirstChild("HumanoidRootPart")
            local ghost = false
            if type(__DIO_IsGhost) == "function" then ghost = __DIO_IsGhost(mob) end
            if hum and root and hum.Health > 0 and not ghost then
                local d = (root.Position - hrp.Position).Magnitude
                if d < bestD then
                    bestD = d
                    best = mob
                end
            end
        end
    end
    return best
end
function __DIO_MasterySpawnCF(names)
    local wo = workspace:FindFirstChild("_WorldOrigin")
    local sp = wo and wo:FindFirstChild("EnemySpawns")
    if not sp then return nil end
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    local best, bestD = nil, math.huge
    for _, s in ipairs(sp:GetChildren()) do
        if s:IsA("BasePart") then
            for _, n in ipairs(names) do
                if string.find(s.Name, n, 1, true) then
                    local d = hrp and (s.Position - hrp.Position).Magnitude or 0
                    if d < bestD then
                        bestD = d
                        best = s
                    end
                    break
                end
            end
        end
    end
    if best then return best.CFrame * CFrame.new(0, 20, 0) end
    return nil
end
function __DIO_GetMasteryTarget()
    local mode = __DIO_MasteryMode()
    if mode == "Cake" then
        return GetConnectionEnemies(mastery1), CFrame.new(-1943.676513671875, 251.5095672607422, -12337.880859375)
    elseif mode == "Bone" then
        return GetConnectionEnemies(mastery2), CFrame.new(-9495.6806640625, 453.58624267578125, 5977.3486328125)
    elseif mode == "Nearest" then
        return __DIO_MasteryScan(nil, tonumber(_G.AuraDistance) or 300), nil
    elseif mode == "Tyrant" then
        local names = { "Serpent Hunter", "Skull Slayer", "Isle Champion", "Sun-kissed Warrior" }
        return __DIO_MasteryScan(names), __DIO_MasterySpawnCF(names)
    end
    local ok, qd = pcall(QuestNeta)
    if not ok then
        __DIO_MasteryWarn("Level", qd)
        return nil, nil
    end
    if type(qd) ~= "table" or type(qd[1]) ~= "string" or qd[1] == "" then return nil, nil end
    local names = { qd[1] }
    local fb = __DIO_MasterySpawnCF(names)
    if not fb and typeof(qd[6]) == "CFrame" then fb = qd[6] * CFrame.new(0, 10, 0) end
    return __DIO_MasteryScan(names), fb
end
Tabs.Main:AddToggle({
Name = __DIO_T["Auto Mastery Fruits"],
Description = "",
Default = false,
Callback = function(Value)
  _G.FarmMastery_Dev = Value
end})
spawn(function()
local __NextNotifScan = 0
RunService.RenderStepped:Connect(function() pcall(function()if _G.FarmMastery_Dev or _G.FarmMastery_G or _G.FarmMastery_S then if tick() < __NextNotifScan then return end __NextNotifScan = tick() + 0.2 for a,b in pairs(plr.PlayerGui.Notifications:GetChildren())do if b.Name=="NotificationTemplate"then if string.find(b.Text,"Skill locked!")then b:Destroy()end end end end end)end)
end)
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.FarmMastery_Dev then
      local __ok, __err = pcall(function()
        local v, fb = __DIO_GetMasteryTarget()
        if v then
          repeat __DIO_wait()
            if not v.Parent then break end
            if not __DIO_MobAliveRoot(v) then break end
            __DIO_EquipFarmWeapon(v)
            MousePos = v.HumanoidRootPart.Position
            Attack.Mas(v, _G.FarmMastery_Dev)
            __DIO_MasteryPace("FarmMastery_Dev", v, 60)
          until _G.FarmMastery_Dev == false or v.Humanoid.Health <= 0 or not v.Parent
        elseif fb then
          _tp(fb)
        end
      end)
      if not __ok then __DIO_MasteryWarn("Fruit", __err) end
    end
  end
end, "L5523")
Tabs.Main:AddToggle({
Name = __DIO_T["Auto Mastery Gun"],
Description = "",
Default = false,
Callback = function(Value)
  _G.FarmMastery_G = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.FarmMastery_G then
      local __ok, __err = pcall(function()
        local v, fb = __DIO_GetMasteryTarget()
        if v then
          repeat __DIO_wait(0.1)
            if not v.Parent then break end
            if not __DIO_MobAliveRoot(v) then break end
            MousePos = v.HumanoidRootPart.Position
            Attack.Masgun(v, _G.FarmMastery_G)
            local __tool = plr.Character and plr.Character:FindFirstChildOfClass("Tool")
            local __hr = v:FindFirstChild("HumanoidRootPart")
            if not __DIO_CanUseSkillOn(v, 100) then
              __DIO_wait(0.05)
            elseif not __DIO_UseMasteryNow(v) then
              __DIO_wait(0.05)
            elseif not __tool or (__tool.ToolTip ~= "Gun" and __tool.Name ~= "Skull Guitar") then
              weaponSc("Gun")
              __DIO_wait(0.1)
            elseif __tool.Name == "Skull Guitar" then
              SoulGuitar = true
              local __rem = __tool:FindFirstChild("RemoteEvent")
              if __rem and _G.FarmMastery_G then
                pcall(function() __rem:FireServer("TAP", MousePos) end)
                vim1:SendMouseButtonEvent(0, 0, 0, true, game, 1); __DIO_wait(0.05)
                vim1:SendMouseButtonEvent(0, 0, 0, false, game, 1); __DIO_wait(0.05)
              end
            else
              SoulGuitar = false
              local __mods = replicated:FindFirstChild("Modules")
              local __net  = __mods and __mods:FindFirstChild("Net")
              local __shoot = __net and __net:FindFirstChild("RE/ShootGunEvent")
              if __shoot and __hr and _G.FarmMastery_G then
                pcall(function() __shoot:FireServer(MousePos, { __hr }) end)
                vim1:SendMouseButtonEvent(0, 0, 0, true, game, 1); __DIO_wait(0.05)
                vim1:SendMouseButtonEvent(0, 0, 0, false, game, 1); __DIO_wait(0.05)
              end
            end
            __DIO_MasteryPace("FarmMastery_G", v, 100)
          until _G.FarmMastery_G == false or not v.Parent or (v:FindFirstChild("Humanoid") and v.Humanoid.Health <= 0)
          SoulGuitar = false
        elseif fb then
          _tp(fb)
        end
      end)
      if not __ok then __DIO_MasteryWarn("Gun", __err) end
    end
  end
end, "L5562")
Tabs.Main:AddToggle({
Name = __DIO_T["Auto Mastery All Sword"],
Description = "",
Default = false,
Callback = function(Value)
  _G.FarmMastery_S = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.FarmMastery_S then
      local __ok, __err = pcall(function()
        for _, v in next, GetInventoryCached() do
          if type(v) == "table" and v.Type == "Sword" then
            local __m = tonumber(v.Mastery) or 0
            if __m < 600 then
              SwordName = v.Name
              local vm, fb = __DIO_GetMasteryTarget()
              if GetBP(SwordName) then
                if vm then
                  repeat __DIO_wait(0.25)
                    if not vm.Parent or not __DIO_MobAliveRoot(vm) then break end
                    Attack.Sword(vm, _G.FarmMastery_S)
                  until _G.FarmMastery_S == false or not vm.Parent or (vm:FindFirstChild("Humanoid") and vm.Humanoid.Health <= 0)
                elseif fb then
                  _tp(fb)
                end
              else
                replicated.Remotes.CommF_:InvokeServer("LoadItem", SwordName)
              end
              break
            end
          end
        end
      end)
      if not __ok then __DIO_MasteryWarn("Sword", __err) end
    end
  end
end, "L5655")
Tabs.Settings:AddSection("Settings Farm")

Tabs.Settings:AddToggle({
Name = __DIO_T["Auto Use Skill Melee/Sword If lag Mob or Ghost Mob"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoSkillGhost = (Value == true)
  pcall(__DIO_GhostReset)
end})
_G.AutoSkillGhost = (GetSetting("UI/Settings/Auto Use Skill Melee/Sword If lag Mob or Ghost Mob", false) == true)
__DIO_HasTip = function(tip)
    local ok, r = pcall(function()
        for _, t in ipairs(plr.Backpack:GetChildren()) do
            if t:IsA("Tool") and t.ToolTip == tip then return true end
        end
        local c = plr.Character
        if c then
            for _, t in ipairs(c:GetChildren()) do
                if t:IsA("Tool") and t.ToolTip == tip then return true end
            end
        end
        return false
    end)
    if ok then return r end
    return false
end
__DIO_NoWepWarnT = 0
__DIO_FireMeleeSwordNow = function(mob)
    if not mob or not mob.Parent then return end
    task.spawn(function()
        pcall(function()
            local h = mob:FindFirstChild("Humanoid")
            if not h or h.Health <= 0 then return end
            local mhrp = mob:FindFirstChild("HumanoidRootPart")
            if mhrp then
                MousePos = mhrp.Position + Vector3.new(0, 2, 0)
                _G.DIO_SkillAim = true
                task.spawn(function() __DIO_wait(0.9) _G.DIO_SkillAim = false end)
            end
            local __hasMelee = __DIO_HasTip("Melee")
            local __hasSword = __DIO_HasTip("Sword")
            if not __hasMelee and not __hasSword then
                if tick() - (__DIO_NoWepWarnT or 0) > 60 then
                    __DIO_NoWepWarnT = tick()
                    pcall(function() __DIO_TNotify("Skill Melee/Sword", "Khong tim thay vu khi Melee hoac Sword trong tui - khong co skill de ban.", 5) end)
                end
                return
            end
            if __hasMelee then
                Useskills("Melee", "Z") __DIO_wait(0.15)
                Useskills("Melee", "X") __DIO_wait(0.15)
                Useskills("Melee", "C") __DIO_wait(0.15)
            end
            if __hasSword then
                Useskills("Sword", "Z") __DIO_wait(0.15)
                Useskills("Sword", "X")
            end
        end)
    end)
end
Neartween = Tabs.Settings:AddToggle({
Name = __DIO_T["Tween speed 600 if near"],
Description = "",
Default = true,
Callback = function(Value)
  _G.Neartween = (Value == true)
end})
_G.FastAttackMob = false
Tabs.Settings:AddToggle({
Name = __DIO_T["Fast Attack Mob 2"],
Description = "Can Lag Mob Or Drop fps 2 Loop Fast attack",
Default = false,
Callback = function(Value)
  _G.FastAttackMob = (Value == true)
end})
Tabs.Settings:AddToggle({
Name = __DIO_T["Attack No Animation"],
Description = "",
Default = true, 
Callback = function(Value)
  _G.AttackNoAnim = (Value == true)
end})
_G.AttackNoAnim = (GetSetting("UI/Settings/Attack No Animation", false) == true)
_G.Neartween = (GetSetting("UI/Settings/Tween speed 600 if near", true) == true)
Tabs.Settings:AddToggle({
Name = __DIO_T["Bring Mobs"],
Description = "",
Default = true,
Callback = function(Value)
  BringEnemyFarm = Value
end})
BringEnemyFarm = (GetSetting("UI/Settings/Bring Mobs", true) == true)

local __DSKA_PartsNear = function(model, pos, range)
    local out = {}
    for _, p in pairs(model:GetChildren()) do
        if p:IsA("BasePart") and (p.Position - pos).Magnitude <= range then
            table.insert(out, p)
        end
    end
    return out
end
local __DSKA_MobList = function(includeChars)
    local out = {}
    local en = __SVC_WS:FindFirstChild("Enemies")
    if en then
        for _, m in pairs(en:GetChildren()) do table.insert(out, m) end
    end
    if includeChars then
        local ch = __SVC_WS:FindFirstChild("Characters")
        if ch then
            for _, m in pairs(ch:GetChildren()) do table.insert(out, m) end
        end
    end
    return out
end
local __DSKA_BladeHits = function(excludeChar, origins, range, includeChars)
    local out = {}
    for _, mob in pairs(__DSKA_MobList(includeChars)) do
        if mob:IsDescendantOf(workspace) and mob ~= excludeChar
            and mob:FindFirstChild("HumanoidRootPart") then
            local hrp = mob.HumanoidRootPart
            local r = (__SVC_PLR:GetPlayerFromCharacter(mob) and range / 1.5 or range)
            local pts = { hrp.Position }
            if hrp.Size.Y > 5 then
                table.insert(pts, (hrp.CFrame * CFrame.new(0, -hrp.Size.Y * 1.5 + 3, 0)).Position)
            end
            for _, pt in pairs(pts) do
                if (pt - origins[1].Position).Magnitude < 10 + r + hrp.Size.X / 2 then
                    for _, part in pairs(__DSKA_PartsNear(mob, origins[1].Position, r + hrp.Size.X / 2)) do
                        table.insert(out, part)
                    end
                    break
                end
            end
        end
    end
    return out
end
local __DSKA_Nearest = function(player, range)
    local char = player and player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local CU = require(__SVC_RS.Modules.CombatUtil)
    local bestD, bestRig, bestPart = math.huge, nil, nil
    for _, P in pairs(__DSKA_BladeHits(char, { hrp }, range, true)) do
        local rig = CU:GetRigOfHitPart(P)
        if rig and CU:IsVulnerable(rig) then
            local d = (hrp.Position - P.Position).Magnitude
            if d < bestD then bestD, bestRig, bestPart = d, rig, P end
        end
    end
    if bestRig and bestPart then return { bestRig, bestPart } end
    return nil
end
local __DSKA_Modules = __SVC_RS:WaitForChild("Modules")
local __DSKA_getuv = (debug and debug.getupvalue) or getupvalue
local __DSKA_setupv = (debug and debug.setupvalue) or setupvalue
local __DSKA_getuvs = (debug and debug.getupvalues) or getupvalues
local __DSKA_Spam = function(E)
    if typeof(E) ~= "Instance" or not E:IsA("BasePart") then return end
    local CU = require(__DSKA_Modules.CombatUtil)
    local char = plr.Character
    local gun = char and char:FindFirstChild("Dragonstorm")
    if not gun or CU:IsGunReloading(gun) then return end
    local atk = __DSKA_getuvs(require(__SVC_RS.Controllers.CombatController).Attack)[9]
    local I = __DSKA_getuv(atk, 15)
    local U13 = __DSKA_getuv(atk, 13)
    local o = __DSKA_getuv(atk, 16)
    local V = __DSKA_getuv(atk, 17)
    local N = __DSKA_getuv(atk, 14)
    local y = __DSKA_getuv(atk, 12)
    local P = __DSKA_getuv(atk, 18)
    local Q = y * U13
    local d = ((N * U13 + y * I) % o * o + Q) % V
    N = math.floor(d / o)
    y = d - N * o
    P = P + 1
    __DSKA_setupv(atk, 15, I)
    __DSKA_setupv(atk, 13, U13)
    __DSKA_setupv(atk, 16, o)
    __DSKA_setupv(atk, 17, V)
    __DSKA_setupv(atk, 14, N)
    __DSKA_setupv(atk, 12, y)
    __DSKA_setupv(atk, 18, P)
    __SVC_RS.Remotes.Validator2:FireServer(math.floor(d / V * 16777215), P)
    local shoot = __DSKA_Modules.Net:FindFirstChild("RE/ShootGunEvent")
    if shoot then shoot:FireServer(E.Position, { E }) end
end
_G.DragonStromKillAura = (_G.DragonStromKillAura == true)
Tabs.Settings:AddToggle({
Name = __DIO_T["Dragon Strom Kill aura"],
Description = "",
Default = false,
Callback = function(Value)
  _G.DragonStromKillAura = (Value == true)
end})
__DIO_SafeLoop(function()
    while __DIO_wait() do
        if _G.DragonStromKillAura then
            pcall(function()
                local char = plr.Character
                if not (char and char:FindFirstChild("Dragonstorm")) then return end
                local found = __DSKA_Nearest(plr, 150)
                if found and found[1] and found[1].PrimaryPart then
                    __DSKA_Spam(found[1].PrimaryPart)
                end
            end)
        end
    end
end, "L-DSKA")

do
Tabs.Settings:AddToggle({
    Name = __DIO_T["Kill aura Raid and Prehistoric Event"],
    Description = "",
    Default = false,
    Callback = function(Value)
    _G.KillAuraFull = Value
end})
local Range = 500
local Delay = 2
__DIO_SafeLoop(function()
    while __DIO_wait(Delay) do
        if _G.KillAuraFull then
            pcall(function()
                local plr = game.Players.LocalPlayer
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                sethiddenproperty(plr, "SimulationRadius", math.huge)
                for _, enemy in pairs(workspace.Enemies:GetChildren()) do
                    if enemy:FindFirstChild("Humanoid") and enemy:FindFirstChild("HumanoidRootPart") then
                        local dist = (enemy.HumanoidRootPart.Position - hrp.Position).Magnitude
                        if dist <= Range and enemy.Humanoid.Health > 0 then
                            enemy.Humanoid.Health = 0
                            enemy.HumanoidRootPart.CanCollide = false
                            enemy:BreakJoints()
                        end
                    end
                end
            end)
        end
    end
end, "L10657")
end

Tabs.Settings:AddSection("Tween")
Tabs.Settings:AddButton({
    Name = "Stop Tween",
    Description = "",
    Callback = function()
        pcall(function()
            for __i = 1, #__DIO_FarmFlagNames do
                local __n = __DIO_FarmFlagNames[__i]
                local __hasOwner = (__DIO_FlagWant[__n] ~= nil) or (__DIO_UIFlagOwner[__n] ~= nil)
                if __hasOwner == false and __DIO_FlagGet(__n) == true then
                    __DIO_FlagSet(__n, false)
                end
            end
        end)
        pcall(function() for __o in pairs(__DIO_OwnerAlive) do __DIO_ReleaseAll(__o) end end)
        pcall(__DIO_TweenKill, false, true)
        pcall(__DIO_TweenBlock, 0.6)
    end
})

Tabs.Settings:AddDropdown({
    Name = __DIO_T["Mode Farm"],
    Options = {"Normal", "Obrit", "Dodge"},
    Default = "Normal",
    Callback = function(Value)
        _G.ModeFarm = Value
        __DIO_CurTarget = nil
    end
})
_G.ModeFarm = GetSetting("UI/Settings/Mode Farm", "Normal")
if _G.ModeFarm ~= "Normal" and _G.ModeFarm ~= "Obrit" and _G.ModeFarm ~= "Dodge" then _G.ModeFarm = "Normal" end
Tabs.Settings:AddSlider({
    Name = __DIO_T["Orbit Speed"],
    Min = 20,
    Max = 600,
    Default = 170,
    Increment = 5,
    Callback = function(Value)
        _G.OrbitSpeed = math.clamp(math.floor(Value + 0.5), 20, 600)
    end
})
Tabs.Settings:AddSlider({
    Name = __DIO_T["Orbit Height"],
    Min = 0,
    Max = 60,
    Default = 12,
    Increment = 1,
    Callback = function(Value)
        _G.OrbitHeight = math.clamp(math.floor(Value + 0.5), 0, 60)
    end
})
Tabs.Settings:AddSlider({
    Name = __DIO_T["mobs Bring"],
    Min = 1,
    Max = 20,
    Default = 3,
    Increment = 1,
    Callback = function(Value)
        _G.MaxBringMobs = math.clamp(Value, 1, 20)
    end
})
Tabs.Settings:AddSlider({
    Name = __DIO_T["Bring Distance"],
    Min = 1,
    Max = 1000,
    Default = 300,
    Increment = 1,
    Callback = function(Value)
        _G.BringRange = math.clamp(Value, 1, 1000)
    end
})
Tabs.Settings:AddSlider({
    Name = __DIO_T["Farm Distance"],
    Min = 10,
    Max = 100,
    Default = 15,
    Increment = 1,
    Callback = function(Value)
        _G.FarmDistance = math.clamp(Value, 10, 100)
    end
})
Tabs.Settings:AddSlider({
    Name = __DIO_T["Speed Tween"],
    Min = 1,
    Max = 500,
    Default = 190,
    Increment = 1,
    Callback = function(Value)
        _G.TweenSpeed = math.clamp(math.floor(Value + 0.5), 1, 500)
        pcall(function() getgenv().TweenSpeed = _G.TweenSpeed end)
    end
})
_G.TweenSpeed = math.clamp(math.floor((tonumber(GetSetting("UI/Settings/Speed Tween", 190)) or 190) + 0.5), 1, 500)
pcall(function() getgenv().TweenSpeed = _G.TweenSpeed end)
Tabs.Settings:AddSection("Settings / Configure")
Tabs.Settings:AddToggle({
    Name = __DIO_T["Auto Summon Cake Prince"],
    Description = "",
    Default = false,
    Callback = function(Value)
    _G.AutoSpawnCP = Value
end})
Tabs.Settings:AddToggle({
    Name = __DIO_T["Auto Set Spawn Point"],
    Default = false,
    Callback = function(Value)
        getgenv().Set = Value
        if Value then
            pcall(function()
                __SVC_RS.Remotes.CommF_:InvokeServer("SetSpawnPoint")
            end)
        end
    end
})
Tabs.Settings:AddToggle({
Name = __DIO_T["Auto Turn on Buso"],
Description = "",
Default = true,
Callback = function(Value)
  Boud = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if Boud then
      local _HasBuso = {"HasBuso","Buso"}
  	  if not plr.Character:FindFirstChild(_HasBuso[1]) then replicated.Remotes.CommF_:InvokeServer(_HasBuso[2]) end
      end
    end)
  end
end, "L6036")
Tabs.Settings:AddToggle({
    Name = __DIO_T["Auto Haki Observation"],
    Default = false,
    Callback = function(Value)
        getgenv().Observation = Value
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if getgenv().Observation then
            pcall(function()
                __SVC_RS.Remotes.CommE:FireServer("Ken", true)
            end)
        end
    end
end, "L6053")
Tabs.Settings:AddToggle({
Name = __DIO_T["Auto Turn on Race V3"],
Description = "",
Default = false,
Flag = "AutoTurnonRaceV3",
Callback = function(Value)
  _G.RaceClickAutov3 = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.RaceClickAutov3 then
        repeat
          replicated.Remotes.CommE:FireServer("ActivateAbility")
          __DIO_wait(30)
        until not _G.RaceClickAutov3
      end
    end)
  end
end, "L6070")
Tabs.Settings:AddToggle({
Name = __DIO_T["Auto Turn on Race V4"],
Description = "",
Default = false,
Callback = function(Value)
  _G.RaceClickAutov4 = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.RaceClickAutov4 then
  	    if plr.Character:FindFirstChild("RaceEnergy") then
        if plr.Character:FindFirstChild("RaceEnergy").Value == 1 then Useskills("nil","Y") end
        end
      end
    end)
  end
end, "L6089")
Tabs.Settings:AddToggle({
Name = __DIO_T["Auto Turn on Spin (x,y,z) "],
Description = "",
Default = false,
Callback = function(Value)
  RandomCFrame = Value
end})
Tabs.Settings:AddToggle({
Name = __DIO_T["Safe Mode"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Safemode = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
	  if _G.Safemode then
  	  local Calc_Health = plr.Character.Humanoid.Health / plr.Character.Humanoid.MaxHealth * 100
  	  if Calc_Health < Num_self then shouldTween=true _tp(Root.CFrame * CFrame.new(0,500,0)) end
      end
    end)
  end
end, "L6115")
__DIO_AFKConn = nil
Tabs.Settings:AddToggle({
    Name = __DIO_T["Anti AFK"],
    Default = true,
    Callback = function(Value)
        if Value and not __DIO_AFKConn then
            local vu = __SVC_VU
            __DIO_AFKConn = __SVC_PLR.LocalPlayer.Idled:Connect(function()
                vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                __DIO_wait(1)
                vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            end)
        elseif not Value and __DIO_AFKConn then
            pcall(function()
                __DIO_AFKConn:Disconnect()
                __DIO_AFKConn = nil
            end)
        end
    end
})
Tabs.Settings:AddToggle({
    Name = __DIO_T["Anti Admin Join Server"],
    Description = "",
    Default = true,
    Callback = function(Value)
        getgenv().HopServerAdmin = Value
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            if getgenv().HopServerAdmin then
                for _, v in pairs(game.Players:GetPlayers()) do
                    local blacklist = {
                        "red_game43", "rip_indra", "Axiore", "Polkster", "wenlocktoad",
                        "Daigrock", "toilamvidamme", "oofficialnoobie", "Uzoth", "Azarth",
                        "arlthmetic", "Death_King", "Lunoven", "TheGreateAced", "rip_fud",
                        "drip_mama", "layandikit12", "Hingoi", "Lykha5rkkv"
                    }
                    if table.find(blacklist, v.Name) then
                        Hop()
                    end
                end
            end
        end)
    end
end, "L6156")
Tabs.Settings:AddToggle({
    Name = __DIO_T["No Clip"],
    Default = false,
    Callback = function(Value)
        getgenv().NoClip = Value
    end
})

Tabs.Settings:AddToggle({
Name = __DIO_T["Turn on Walk on Water"],
Description = "",
Default = true,
Callback = function(Value)
  _G.WalkWater_Part = Value
  do
    local __mapW = __SVC_WS:FindFirstChild("Map")
    local __planeW = __mapW and __mapW:FindFirstChild("WaterBase-Plane")
    if __planeW then
      __planeW.Size = _G.WalkWater_Part and Vector3.new(1000, 112, 1000) or Vector3.new(1000, 80, 1000)
    end
  end
end
})
Tabs.Settings:AddToggle({
Name = __DIO_T["Turn on Ice Walk"],
Description = "",
Default = false,
Callback = function(Value)
  _G.WalkWater = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.WalkWater then
      pcall(function()
	   if plr.Character and plr.Character:FindFirstChild("LeftFoot") then
	   local upval0 = replicated.Assets.Models.IceSpikes4:Clone()
        upval0.Parent = workspace
        upval0.Size = Vector3.new(3+math.random(10,12),1.7,3+math.random(10,12))
        upval0.Color = Color3.fromRGB(128,187,219)
        upval0.CFrame = CFrame.new(plr.Character.Head.Position.X,-3.8,plr.Character.Head.Position.Z)*CFrame.Angles((math.random()-0.5)*0.06, math.random()*7,(math.random()-0.5)*0.07)
        local var85={};
        var85.Size=Vector3.new(0,0.3,0)
        local var3=TW:Create(upval0,TweenInfo.new(2,Enum.EasingStyle.Quad,Enum.EasingDirection.In),var85)
        var3.Completed:Once(function()
          pcall(function() upval0:Destroy() end)
        end)
          var3:Play()
	    end
      end)
    end
  end
end, "L14946")
spawn(function()
    while true do
        if getgenv().NoClip then
            pcall(function()
                local char = game.Players.LocalPlayer.Character
                if char then
                    for _, v in ipairs(char:GetDescendants()) do
                        if (v:IsA("BasePart") or v:IsA("Part")) and v.CanCollide then
                            v.CanCollide = false
                        end
                    end
                end
            end)
            __DIO_wait(0.04)
        else
            __DIO_wait(0.1)
        end
    end
end)
Tabs.Esp:AddSection("Stats Upgrade")
Tabs.Esp:AddSlider({
Name = __DIO_T["Stats Value"],
Description = "",
Default = 10,
Min = 0,
Max = 1000,
Rounding = 1,
Callback = function(Value)
  pSats = Value
end})
Tabs.Esp:AddToggle({
Name = __DIO_T["Auto Melee"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Melee = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
    if _G.Auto_Melee then statsSetings("Melee",pSats) end
    end)
  end
end, "L6224")
Tabs.Esp:AddToggle({
Name = __DIO_T["Auto Swords"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Sword = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
    if _G.Auto_Sword then statsSetings("Sword",pSats) end
    end)
  end
end, "L6239")
Tabs.Esp:AddToggle({
Name = __DIO_T["Auto Gun"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Gun = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
    if _G.Auto_Gun then statsSetings("Gun",pSats) end
    end)
  end
end, "L6253")
Tabs.Esp:AddToggle({
Name = __DIO_T["Auto Blox Fruit"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_DevilFruit = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
    if _G.Auto_DevilFruit then statsSetings("Devil",pSats) end
    end)
  end
end, "L6267")
Tabs.Esp:AddToggle({
Name = __DIO_T["Auto Defense"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Defense = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
    if _G.Auto_Defense then statsSetings("Defense",pSats) end
    end)
  end
end, "L6281")
__DIO_BOOT("Load Tabs")
Tabs.Fish:AddSection("Fishing")
Tabs.Fish:AddDropdown({
    Name = __DIO_T["Select Fishing Rod"],
    Description = "",
    Options = {"Fishing Rod", "Gold Rod", "Shark Rod", "Shell Rod", "Treasure Rod"},
    Default = "Fishing Rod",
    Callback = function(Value)
        _G.SelectedRod = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
Tabs.Fish:AddDropdown({
    Name = __DIO_T["Select Bait"],
    Description = "",
    Options = { "Basic Bait", "Kelp Bait", "Good Bait", "Abyssal Bait", "Frozen Bait", "Epic Bait", "Carnivore Bait" },
    Default = "Basic Bait",
    Callback = function(Value)
        _G.SelectedBait = Value
        if _G.AutoBuyBait then
            pcall(function()
                Remotes.RFCraft:InvokeServer("Craft", _G.SelectedBait, {})
            end)
        end
    end
})
if type(RegisterFunction) ~= "function" then
    RegisterFunction = function(name, fn)
        __DIO_FnRegistry = __DIO_FnRegistry or {}
        __DIO_FnRegistry[name] = fn
    end
end
__DIO_SlapStep = function()
    local __sg = plr and plr.PlayerGui and plr.PlayerGui:FindFirstChild("FishSlapMinigame")
    if not __sg then return end
    local Bar = __sg:FindFirstChild("Bar")
    local GreenZone = Bar and Bar:FindFirstChild("GreenZone")
    local Tick = Bar and Bar:FindFirstChild("Tick")
    local SlapButton = __sg:FindFirstChild("SlapButton")
    if not GreenZone or not Tick or not SlapButton then return end
    local GreenAbsPos = GreenZone.AbsolutePosition
    local AbsSize = GreenZone.AbsoluteSize
    local Inset = AbsSize.Y * 0.1
    local GreenTop = GreenAbsPos.Y + Inset
    local GreenBottom = GreenAbsPos.Y + AbsSize.Y - Inset
    local AbsY = Tick.AbsolutePosition.Y + (Tick.AbsoluteSize.Y / 2)
    if AbsY >= GreenTop and AbsY <= GreenBottom then
        if type(firesignal) == "function" then
            pcall(firesignal, SlapButton.Activated)
        end
    end
end
SlapFishing = Tabs.Fish:AddToggle({
Name = __DIO_T["Auto Slap Fishing"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoFishSlap = Value
  pcall(RegisterFunction, "AutoSlap", __DIO_SlapStep, true)
end})
__DIO_SafeLoop(function()
  while __DIO_wait() do
    if _G.AutoFishSlap then
      pcall(__DIO_SlapStep)
    end
  end
end, "SlapFishing")
Tabs.Fish:AddToggle({
    Name = __DIO_T["Auto Buy Bait"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoBuyBait = Value
        if Value then
            pcall(function()
                Remotes.RFCraft:InvokeServer("Craft", _G.SelectedBait, {})
            end)
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(2) do
        if _G.AutoBuyBait and _G.SelectedBait then
            pcall(function()
                Remotes.RFCraft:InvokeServer("Craft", _G.SelectedBait, {})
            end)
        end
    end
end, "L6336")
Tabs.Fish:AddToggle({
    Name = __DIO_T["Auto Fishing"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoFishing = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
local Players = __SVC_PLR
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = __SVC_RS
local FishReplicated = ReplicatedStorage:FindFirstChild("FishReplicated")
    or ReplicatedStorage:WaitForChild("FishReplicated", 5)
local FishingRequest = FishReplicated and FishReplicated:FindFirstChild("FishingRequest")
local __FishCfg
pcall(function()
    local c = FishReplicated and FishReplicated:FindFirstChild("FishingClient")
    c = c and c:FindFirstChild("Config")
    if c then __FishCfg = require(c) end
end)
local GetWaterHeight = nil
pcall(function()
    local u = ReplicatedStorage:FindFirstChild("Util")
    u = u and u:FindFirstChild("GetWaterHeightAtLocation")
    if u then GetWaterHeight = require(u) end
end)
local MaxDistance = (__FishCfg and __FishCfg.Rod and __FishCfg.Rod.MaxLaunchDistance) or 100
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoFishing then
            pcall(function()
                local Char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                local HRP = Char:FindFirstChild("HumanoidRootPart")
                if not HRP then return end
                local Tool = Char:FindFirstChildOfClass("Tool")
                if _G.SelectedRod and (not Tool or Tool.Name ~= _G.SelectedRod) then
                    local backpackTool = LocalPlayer.Backpack:FindFirstChild(_G.SelectedRod)
                    if backpackTool then
                        Char.Humanoid:EquipTool(backpackTool)
                        Tool = backpackTool
                    end
                end
                if Tool and FishingRequest and GetWaterHeight then
                    local waterHeight = GetWaterHeight(HRP.Position)
                    local _, hitPos = workspace:FindPartOnRayWithIgnoreList(
                        Ray.new(Char.Head.Position, HRP.CFrame.LookVector * MaxDistance),
                        {Char, workspace.Characters, workspace.Enemies}
                    )
                    local TargetPos = hitPos and Vector3.new(hitPos.X, math.max(hitPos.Y, waterHeight), hitPos.Z)
                    local State = Tool:GetAttribute("State")
                    local ServerState = Tool:GetAttribute("ServerState")
                    if TargetPos and (State == "ReeledIn" or ServerState == "ReeledIn") then
                        FishingRequest:InvokeServer("StartCasting")
                        __DIO_wait()
                        FishingRequest:InvokeServer("CastLineAtLocation", TargetPos, 100, true)
                    elseif ServerState == "Biting" then
                        FishingRequest:InvokeServer("Catching", true)
                        __DIO_wait(0.1)
                        FishingRequest:InvokeServer("Catch", 1)
                    end
                end
            end)
        end
    end
end, "L6382")
Tabs.Fish:AddToggle({
Name = __DIO_T["Auto Quest Fishing"],
Description = "",
Default = false,
Callback = function(Value)
    _G.AutoFishingQuest = Value
end})
local Players3 = __SVC_PLR
local LocalPlayer3 = Players3.LocalPlayer
local ReplicatedStorage3 = __SVC_RS
local __Net3 = ReplicatedStorage3:FindFirstChild("Modules")
__Net3 = __Net3 and __Net3:FindFirstChild("Net")
local RFJobsRemoteFunction3 = __Net3 and __Net3:FindFirstChild("RF/JobsRemoteFunction")
local function HasQuest3()
    local questGui = LocalPlayer3.PlayerGui:FindFirstChild("Quest") or LocalPlayer3.PlayerGui:FindFirstChild("QuestGui")
    if questGui and questGui:FindFirstChild("Container") and questGui.Container:FindFirstChild("QuestTitle") then
        return true
    end
    return false
end
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoFishingQuest then
            pcall(function()
                if not HasQuest3() then
                    if RFJobsRemoteFunction3 then RFJobsRemoteFunction3:InvokeServer("FishingNPC", "Angler", "AskQuest") end
                end
            end)
        end
    end
end, "L6449")
Tabs.Fish:AddToggle({
    Name = __DIO_T["Auto Complete Quest"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoQuestComplete = Value
        if Value then
            pcall(function()
                Remotes.RFJobsRemoteFunction:InvokeServer("FishingNPC", "FinishQuest")
            end)
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(5) do
        if _G.AutoQuestComplete then
            pcall(function()
                Remotes.RFJobsRemoteFunction:InvokeServer("FishingNPC", "FinishQuest")
            end)
        end
    end
end, "L6476")
Tabs.Fish:AddToggle({
    Name = __DIO_T["Auto Sell Fish"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoSellFish = Value
        if Value then
            pcall(function()
                Remotes.RFJobsRemoteFunction:InvokeServer("FishingNPC", "SellFish")
            end)
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(5) do
        if _G.AutoSellFish then
            pcall(function()
                Remotes.RFJobsRemoteFunction:InvokeServer("FishingNPC", "SellFish")
            end)
        end
    end
end, "L6501")
Tabs.Fish:AddToggle({
Name = __DIO_T["Auto Spam Skill Z"],
Description = "",
Default = false,
Callback = function(Value)
    _G.AutoSkillZ = Value
end})
local ReplicatedStorage4 = __SVC_RS
local __Net4 = ReplicatedStorage4:FindFirstChild("Modules")
__Net4 = __Net4 and __Net4:FindFirstChild("Net")
local RFJobToolAbilities4 = __Net4 and __Net4:FindFirstChild("RF/JobToolAbilities")
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoSkillZ then
            pcall(function()
                if RFJobToolAbilities4 then RFJobToolAbilities4:InvokeServer("Z", true) end
            end)
        end
    end
end, "L6525")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Quest Sea 2"],
Description = "",
Default = false,
Callback = function(Value)
  _G.TravelDres = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.TravelDres then
        if plr.Data.Level.Value >= 700 then
          if workspace.Map.Ice.Door.CanCollide == true and workspace.Map.Ice.Door.Transparency == 0 then
            replicated.Remotes.CommF_:InvokeServer("DressrosaQuestProgress","Detective")
		    EquipWeapon("Key")
		    repeat __DIO_wait(0.25) _tp(CFrame.new(1347.7124, 37.3751602, -1325.6488)) until not _G.TravelDres or (Root.Position - CFrame.new(1347.7124, 37.3751602, -1325.6488)).Magnitude <= 5
	      elseif workspace.Map.Ice.Door.CanCollide == false and workspace.Map.Ice.Door.Transparency == 1 then
            if Enemies:FindFirstChild("Ice Admiral") then
              for _,xz in pairs(Enemies:GetChildren()) do
                if xz.Name == "Ice Admiral" and Attack.Alive(xz) then
              	  repeat __DIO_wait(Sec) Attack.Kill(xz,_G.TravelDres) until _G.TravelDres == false or xz.Humanoid.Health <= 0
                  replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
                end
              end
            else
              _tp(CFrame.new(1347.7124, 37.3751602, -1325.6488))
            end
	      else
		    replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
	      end
        end
      end
    end)
  end
end, "L6542")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Quest Sea 3"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoZou = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.AutoZou then
   	    if plr.Data.Level.Value >= 1500 then
          if replicated.Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 3 then
            if replicated.Remotes.CommF_:InvokeServer("GetUnlockables").FlamingoAccess ~= nil then
              replicated.Remotes.CommF_:InvokeServer("F_","TravelZou")
              if replicated.Remotes.CommF_:InvokeServer("ZQuestProgress", "Check") == 0 then
                local v = GetConnectionEnemies("rip_indra")
                if v then
                  repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoZou) until not _G.AutoZou or not v.Parent or v.Humanoid.Health <= 0
                  Check = 2
                  local __zouT = tick()
                  repeat __DIO_wait(0.25) replicated.Remotes.CommF_:InvokeServer("F_","TravelZou") until not _G.AutoZou or Check == 1 or tick() - __zouT > 8
                else
                  replicated.Remotes.CommF_:InvokeServer("F_","ZQuestProgress","Check") __DIO_wait(.1)
                  replicated.Remotes.CommF_:InvokeServer("F_","ZQuestProgress","Begin")
                end
              elseif replicated.Remotes["CommF_"]:InvokeServer("ZQuestProgress", "Check") == 1 then
                replicated.Remotes.CommF_:InvokeServer("F_","TravelZou")
              else
                local v = GetConnectionEnemies("Don Swan")
                if v then
                  repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoZou)until not _G.AutoZou or not v.Parent or v.Humanoid.Health<=0
                else
                  repeat __DIO_wait(0.25) _tp(CFrame.new(2288.802, 15.1870775, 863.034607)) until not _G.AutoZou or (Root.Position - CFrame.new(2288.802, 15.1870775, 863.034607).Position).Magnitude <= 5
                  if ((Root.Position - CFrame.new(2288.802, 15.1870775, 863.034607).Position).Magnitude <= 5) then notween(CFrame.new(2288.802, 15.1870775, 863.034607)) end
                end
              end
            else
            if replicated.Remotes.CommF_:InvokeServer("GetUnlockables").FlamingoAccess == nil then
              TabelDevilFruitStore = {}
              TabelDevilFruitOpen = {}
              for i,v in pairs(replicated.Remotes["CommF_"]:InvokeServer("getInventoryFruits")) do
                for i1,v1 in pairs(v) do
                  if i1 == "Name" then table.insert(TabelDevilFruitStore,v1)end
                end
              end
              for i,v in next, game.ReplicatedStorage:WaitForChild("Remotes").CommF_:InvokeServer("GetFruits") do
                if v.Price >= 1000000 then table.insert(TabelDevilFruitOpen,v.Name) end
              end
              for i,DevilFruitOpenDoor in pairs(TabelDevilFruitOpen) do
                for i1,DevilFruitStore in pairs(TabelDevilFruitStore) do
                  if DevilFruitOpenDoor == DevilFruitStore and replicated.Remotes.CommF_:InvokeServer("GetUnlockables").FlamingoAccess == nil then
                    if not plr.Backpack:FindFirstChild(DevilFruitStore) then
                      replicated.Remotes.CommF_:InvokeServer("F_","LoadFruit",DevilFruitStore)
                    else
                      replicated.Remotes.CommF_:InvokeServer("F_","TalkTrevor","1")
                      replicated.Remotes.CommF_:InvokeServer("F_","TalkTrevor","2")
                      replicated.Remotes.CommF_:InvokeServer("F_","TalkTrevor","3")
                    end
                  end
                end
              end
                replicated.Remotes.CommF_:InvokeServer("F_","TalkTrevor","1")
                replicated.Remotes.CommF_:InvokeServer("F_","TalkTrevor","2")
                replicated.Remotes.CommF_:InvokeServer("F_","TalkTrevor","3")
              end
            end
          else
            if replicated.Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 0 then
              local __qZ = __DIO_GetCurrentQuest()
              if __qZ.IsActive and string.find(__qZ.QuestText, "Swan Pirates", 1, true) and string.find(__qZ.QuestText, "50", 1, true) then
                local v = GetConnectionEnemies("Swan Pirate")
                if v then
                  pcall(function() repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoZou) until not v.Parent or v.Humanoid.Health <= 0 or _G.AutoZou == false or __DIO_QuestGone() end)
                else
                  _tp(CFrame.new(1057.92761, 137.614319, 1242.08069))
                end
              else
                _tp(CFrame.new(-456.28952, 73.0200958, 299.895966))
              end
            elseif replicated.Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 1 then
              local v = GetConnectionEnemies("Jeremy")
              if v then
                repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoZou) until not v.Parent or v.Humanoid.Health <= 0 or _G.AutoZou == false
              else
                _tp(CFrame.new(2099.88159, 448.931, 648.997375))
              end
            elseif replicated.Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 2 then
              repeat __DIO_wait(0.25) _tp(CFrame.new(-1836, 11, 1714)) until not _G.AutoZou or (Root.Position - CFrame.new(-1836, 11, 1714).Position).Magnitude <= 5
              if ((Root.Position - CFrame.new(-1836, 11, 1714).Position).Magnitude <= 5) then notween(CFrame.new(-1836, 11, 1714))end
              notween(CFrame.new(-1850.49329, 13.1789551, 1750.89685))
              __DIO_wait(.1)
              notween(CFrame.new(-1858.87305, 19.3777466, 1712.01807))
              __DIO_wait(.1)
              notween(CFrame.new(-1803.94324, 16.5789185, 1750.89685))
              __DIO_wait(.1)
              notween(CFrame.new(-1858.55835, 16.8604317, 1724.79541))
              __DIO_wait(.1)
              notween(CFrame.new(-1869.54224, 15.987854, 1681.00659))
              __DIO_wait(.1)
              notween(CFrame.new(-1800.0979, 16.4978027, 1684.52368))
              __DIO_wait(.1)
              notween(CFrame.new(-1819.26343, 14.795166, 1717.90625))
              __DIO_wait(.1)
              notween(CFrame.new(-1813.51843, 14.8604736, 1724.79541))
            end
          end
        end
      end
    end)
  end
end, "L6577")
Tabs.Quests:AddSection("Farm Rip Indra")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Attack Rip Indra"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoRipIngay = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.AutoRipIngay then
        local v = GetConnectionEnemies("rip_indra") or GetConnectionEnemies("rip_indra True Form")
        if v and (not GetWP("Dark Dagger") or not GetIn("Valkyrie")) then
          repeat __DIO_wait(Sec) Attack.Kill(v,_G.AutoRipIngay)until not _G.AutoRipIngay or not v.Parent or v.Humanoid.Health <= 0
        else
          replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-5097.93164, 316.447021, -3142.66602, -0.405007899, -4.31682743e-08, 0.914313197, -1.90943332e-08, 1, 3.8755779e-08, -0.914313197, -1.76180437e-09, -0.405007899))
		  __DIO_wait(.1)
		  _tp(CFrame.new(-5344.822265625, 423.98541259766, -2725.0930175781))
	    end
      end
    end)
  end
end, "L6692")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Unlocked Haki"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoUnHaki = Value
end})
AuraSkin = function(HakiID)
  local args = {[1] = {["StorageName"] = HakiID,["Type"] = "AuraSkin",["Context"] = "Equip"}};
  replicated:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/FruitCustomizerRF"):InvokeServer(unpack(args));
end;
VaildColor = function(Part)
  if Part and Part.BrickColor then return (tostring(Part.BrickColor) == "Lime green") end;
end;
HakiCalculate = function(Part)
  local ID = {["Really red"] = "Pure Red";["Oyster"] = "Snow White";["Hot pink"] = "Winter Sky";};
  if Part and Part.BrickColor then return (ID[tostring(Part.BrickColor)])end;
end;
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.AutoUnHaki then
      pcall(function()
        local Summoner = workspace.Map["Boat Castle"]:FindFirstChild("Summoner");
        if Summoner and Summoner:FindFirstChild("Circle") then
          for i,v in pairs(Summoner:FindFirstChild("Circle"):GetChildren()) do
            if v.Name == "Part" then
            local TogglesPart = v:FindFirstChild("Part");
              if VaildColor(TogglesPart) == false then
                AuraSkin(HakiCalculate(v));
                repeat __DIO_wait(0.25) _tp(v.CFrame) until VaildColor(TogglesPart) == true or not _G.AutoUnHaki;
              end
            end
          end
        end
      end)
    end
  end
end, "L6729")

Tabs.Quests:AddSection("Bone")

Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Random Bones"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Random_Bone = Value
end})
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Soul Reaper"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoHytHallow = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.AutoHytHallow then
      pcall(function()
        local v = GetConnectionEnemies("Soul Reaper")
	    if v then
          repeat __DIO_wait(Sec) Attack.Kill(v,_G.AutoHytHallow) until v.Humanoid.Health <= 0 or _G.AutoHytHallow == false
        else
          if not GetBP("Hallow Essence") then
            repeat __DIO_wait(1)replicated.Remotes.CommF_:InvokeServer("Bones","Buy",1,1)until _G.AutoHytHallow == false or GetBP("Hallow Essence")
          else
            repeat __DIO_wait(.1) _tp(CFrame.new(-8932.322265625, 146.83154296875, 6062.55078125))until _G.AutoHytHallow == false or ((plr.Character.HumanoidRootPart.Position - CFrame.new(-8932.322265625, 146.83154296875, 6062.55078125).Position).Magnitude <= 5)
		    EquipWeapon("Hallow Essence")
          end
        end
      end)
    end
  end
end, "L6757")
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Auto_Random_Bone then
  	    repeat __DIO_wait(0.25) replicated.Remotes.CommF_:InvokeServer("Bones","Buy",1,1) until not _G.Auto_Random_Bone
      end
    end)
  end
end, "L6777")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Try Luck Gravestone"],
Description = "",
Default = false,
Callback = function(Value)
  _G.TryLucky = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.TryLucky then
    pcall(function()
      local __hrpG = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
      if not __hrpG then return end
      local try_bones_luck = CFrame.new(-8761.3154296875, 164.85829162598, 6161.1567382813)
      if ((__hrpG.Position - try_bones_luck.Position).Magnitude > 5) then
        _tp(try_bones_luck)
      else
	   replicated.Remotes.CommF_:InvokeServer("gravestoneEvent",1)
      end
    end)
    end
  end
end, "L6793")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Pray Gravestone"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Praying = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.Praying then
    pcall(function()
      local __hrpG = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
      if not __hrpG then return end
      local try_bones_luck = CFrame.new(-8761.3154296875, 164.85829162598, 6161.1567382813)
      if ((__hrpG.Position - try_bones_luck.Position).Magnitude > 5) then
	   _tp(try_bones_luck)
      else
	   replicated.Remotes.CommF_:InvokeServer("gravestoneEvent",2)
      end
    end)
    end
  end
end, "L6817")
Tabs.Quests:AddSection("Farm Elite Hunter")
local Process = Tabs.Quests:AddParagraph("Elites Process", "")
__EliteProg = ""
__DIO_SafeLoop(function()
    local __prevElite = nil
    while __DIO_wait(2) do
        pcall(function()
            local __r = replicated.Remotes.CommF_:InvokeServer("EliteHunter", "Progress")
            if __r then __EliteProg = tostring(__r) end
            local __v = "Elite Progress : " .. tostring(__EliteProg)
            if __v ~= __prevElite then __prevElite = __v Process:SetDesc(__v) end
        end)
    end
end, "L6838")
local EliteHunter = Tabs.Quests:AddParagraph("Elite Spawn", "Status: ")
__DIO_SafeLoop(function()
    local previousStatus = ""
    while __DIO_wait(2) do
        local currentStatus = (__SVC_RS:FindFirstChild("Diablo") or
                               __SVC_RS:FindFirstChild("Deandre") or
                               __SVC_RS:FindFirstChild("Urban") or
                               __SVC_WS.Enemies:FindFirstChild("Diablo") or
                               __SVC_WS.Enemies:FindFirstChild("Deandre") or
                               __SVC_WS.Enemies:FindFirstChild("Urban")) and '✅' or '❌'
        if currentStatus ~= previousStatus then
            EliteHunter:SetDesc("Status: " .. currentStatus .. " | Killed: " .. tostring(__EliteProg))
            previousStatus = currentStatus
        end
    end
end, "L6851")
EliteQ = Tabs.Quests:AddToggle({
    Name = __DIO_T["Auto Farm Elite"],
    Description = "",
    Default = false,
    Callback = function(Value)
    _G.FarmEliteHunt = (Value == true)

    pcall(__DIO_UIWant, "FarmEliteHunt", "EliteQ", Value == true)
    if Value == true and type(__DIO_Wake) == "function" then pcall(__DIO_Wake, true) end
end})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            if _G.FarmEliteHunt then
                local __boss = __DIO_DetectEliteHunter()
                if __boss then
                    local __q = __DIO_GetCurrentQuest()
                    local __txt = __q.QuestText or ""
                    if (not __q.IsActive) or (not string.find(__txt, __boss.Name, 1, true)) then
                        local __res = __DIO_EliteTakeQuest()
                        if __res == nil or string.find(tostring(__res), "Cooldown") then
                            __DIO_wait(10)
                            return
                        end
                        __DIO_wait(1)
                    else
                        __DIO_EliteFight(__boss, _G.FarmEliteHunt)
                    end
                else

                    __DIO_wait(5)
                end
            end
        end)
    end
end, "L6875")
EliteH = Tabs.Quests:AddToggle({
	Name = __DIO_T["Auto Farm Elite + Hop"],
	Description = "",
	Default = false,
	Callback = function(Value)
	_G.FarmEliteH = (Value == true)

	pcall(__DIO_UIWant, "FarmEliteH", "EliteH", Value == true)
	if Value == true and type(__DIO_Wake) == "function" then pcall(__DIO_Wake, true) end
end})
Tabs.Quests:AddToggle({
    Name = __DIO_T["Auto Get PlayerQuest"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoReceivePlayerQuest = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
Tabs.Quests:AddToggle({
    Name = __DIO_T["Auto Kill Player Quest"],
    Default = false,
    Callback = function(Value)
        _G.AutoPlayerHunter = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
Tabs.Quests:AddSection("Tushita + Yama")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Tushita Sword"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: bat toggle -> du 3 lop _G.Auto_Tushita + shouldTween = true + highlight
  __DIO_FeatToggle("Auto_Tushita", Value)
end})
-- port 1:1 logic GetTushita() cua 3nn
-- port checkTorch(): tim torch chua sang trong Workspace.Map.Turtle.QuestTorches (Torch1..5)
__DIO_TushitaCheckTorch = function()
    local __ok, __res = pcall(function()
        local __map = workspace:FindFirstChild("Map")
        local __turtle = __map and __map:FindFirstChild("Turtle")
        local __qt = __turtle and __turtle:FindFirstChild("QuestTorches")
        if not __qt then return nil end
        local __idx = nil
        for __i = 1, 5 do
            local __t = __qt:FindFirstChild("Torch" .. __i)
            local __pt = __t and __t:FindFirstChild("Particles")
            local __main = __pt and __pt:FindFirstChild("Main")
            if __main and __main.Enabled == false then __idx = tostring(__i) break end
        end
        if not __idx then return nil end
        for _, __s in ipairs(__qt:GetChildren()) do
            if __s:IsA("MeshPart") and string.find(__s.Name, __idx) then
                local __pt = __s:FindFirstChild("Particles")
                local __main = __pt and __pt:FindFirstChild("Main")
                if __main and __main.Enabled == false then return __s end
            end
        end
        return nil
    end)
    if __ok then return __res end
    return nil
end
-- port GetHitBoxTouch(): hitbox Holy Torch (Waterfall.IslandModel.Hitbox), fallback getnilinstances
__DIO_TushitaHitbox = function()
    local __hb = nil
    pcall(function()
        local __map = workspace:FindFirstChild("Map")
        local __wf = __map and __map:FindFirstChild("Waterfall")
        local __im = __wf and __wf:FindFirstChild("IslandModel")
        __hb = __im and __im:FindFirstChild("Hitbox", true) or nil
    end)
    if __hb then return __hb end
    pcall(function()
        if type(getnilinstances) ~= "function" then return end
        local __ref = Vector3.new(5713.53759765625, 38.38311767578125, 255.2017059326172)
        for _, __l in ipairs(getnilinstances()) do
            if __l.Name == "Hitbox" and __l:IsA("BasePart") and (__l.Position - __ref).Magnitude < 1 then
                __hb = __l
                break
            end
        end
    end)
    return __hb
end
__DIO_TushitaProgT, __DIO_TushitaProgV = 0, nil
__DIO_TushitaProgress = function()
    if tick() - (__DIO_TushitaProgT or 0) < 3 and __DIO_TushitaProgV ~= nil then return __DIO_TushitaProgV end
    local __ok, __r = pcall(function() return replicated.Remotes.CommF_:InvokeServer("TushitaProgress") end)
    __DIO_TushitaProgT = tick()
    __DIO_TushitaProgV = (__ok and type(__r) == "table") and __r or {}
    return __DIO_TushitaProgV
end
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Auto_Tushita ~= true then return end
      shouldTween = true
      local __prog = __DIO_TushitaProgress()
      if __prog.OpenedDoor then
        -- cua da mo -> danh Longma
        local v = GetConnectionEnemies("Longma")
        if v then
          repeat __DIO_wait(Sec) Attack.Kill(v, _G.Auto_Tushita)
          until not v or not v.Parent or not v:FindFirstChildOfClass("Humanoid") or v.Humanoid.Health <= 0 or _G.Auto_Tushita ~= true
        elseif tick() - (__DIO_TushitaWaitN or 0) > 15 then
          __DIO_TushitaWaitN = tick()
          pcall(function() __DIO_TNotify("Auto Tushita", "Cho Longma spawn...", 4) end)
        end
      else
        local __hb = __DIO_TushitaHitbox()
        if not __hb then
          if _G.Auto_Tushita == true then _tp(CFrame.new(5677.541015625, 28.533447265625, 357.9483642578125)) end
          return
        end
        if __hb:FindFirstChild("TouchInterest") then
          if not GetBP("Holy Torch") then
            -- chua co Holy Torch -> tween vao hitbox de nhat
            if _G.Auto_Tushita == true then _tp(__hb.CFrame) end
            pcall(function()
              if type(firetouchinterest) == "function" then
                local __hr = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                if __hr and (__hr.Position - __hb.Position).Magnitude < 15 then
                  firetouchinterest(__hr, __hb, 0) firetouchinterest(__hr, __hb, 1)
                end
              end
            end)
          else
            -- co Holy Torch -> cam torch, bat QuestTorches Torch.Particles.Main.Enabled du 5 lan
            EquipWeapon("Holy Torch")
            if __DIO_TushitaCheckTorch() then
              for __i = 1, 5 do
                if _G.Auto_Tushita ~= true then break end
                pcall(function() replicated.Remotes.CommF_:InvokeServer("TushitaProgress", "Torch", __i) end)
              end
              __DIO_wait(2)
              __DIO_TushitaProgT = 0
            end
          end
        else
          if tick() - (__DIO_TushitaWaitN or 0) > 15 then
            __DIO_TushitaWaitN = tick()
            pcall(function() __DIO_TNotify("Auto Tushita", "Rip Indra Dont Spawn", 5) end)
          end
          __DIO_wait(5)
        end
      end
    end)
  end
end, "L6981")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Yama Sword"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: bat toggle -> du 3 lop _G.Auto_Yama + shouldTween = true + highlight
  -- tat -> tra FarmEliteHunt da muon (ReleaseAll trong __DIO_FeatToggle)
  __DIO_FeatToggle("Auto_Yama", Value)
end})
__DIO_YamaProgT, __DIO_YamaProgV = 0, 0
__DIO_YamaEliteProgress = function()
    if tick() - (__DIO_YamaProgT or 0) < 3 then return __DIO_YamaProgV or 0 end
    local __ok, __r = pcall(function() return replicated.Remotes.CommF_:InvokeServer("EliteHunter", "Progress") end)
    __DIO_YamaProgT = tick()
    __DIO_YamaProgV = (__ok and tonumber(__r)) or 0
    return __DIO_YamaProgV
end
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Auto_Yama ~= true then return end
      shouldTween = true
      if __DIO_YamaEliteProgress() < 30 then
        -- GIU NGUYEN logic cu: EliteHunter < 30 -> bat farm elite
        __DIO_BorrowFlag("Auto_Yama", "FarmEliteHunt")
        return
      end
      __DIO_ReleaseFlag("Auto_Yama", "FarmEliteHunt")
      -- port 1:1 phan workspace cua GetYama() (3nn)
      local __map = workspace:FindFirstChild("Map")
      local __wf = __map and __map:FindFirstChild("Waterfall")
      local __sk = __wf and __wf:FindFirstChild("SealedKatana")
      if not __sk then
        if _G.Auto_Yama == true then _tp(CFrame.new(5251.900390625, 17.18115234375, 453.6025390625)) end
        return
      end
      local __piv = nil
      pcall(function() __piv = __sk.WorldPivot end)
      if not __piv or __piv.Position.Magnitude < 1 then
        pcall(function() __piv = __sk:GetPivot() end)
      end
      local __hrpY = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
      if not __piv or not __hrpY then return end
      if (__piv.Position - __hrpY.Position).Magnitude > 50 then
        if _G.Auto_Yama == true then _tp(__piv) end
        return
      end
      local __en = workspace:FindFirstChild("Enemies")
      local __ghost = nil
      if __en and __en:FindFirstChild("Ghost") then
        for _, __g in ipairs(__en:GetChildren()) do
          local __gh = __g.Name == "Ghost" and __g:FindFirstChildOfClass("Humanoid")
          if __gh and __gh.Health > 0 and __g:FindFirstChild("HumanoidRootPart") then __ghost = __g break end
        end
      end
      if __ghost then
        repeat __DIO_wait(0.25) Attack.Kill(__ghost, _G.Auto_Yama)
        until not __ghost.Parent or not __ghost:FindFirstChildOfClass("Humanoid") or __ghost.Humanoid.Health <= 0 or _G.Auto_Yama ~= true
      else
        local __cd = nil
        pcall(function()
          local __hbY = __sk:FindFirstChild("Hitbox")
          __cd = (__hbY and __hbY:FindFirstChild("ClickDetector")) or __sk:FindFirstChildWhichIsA("ClickDetector", true)
        end)
        if __cd and type(fireclickdetector) == "function" then pcall(fireclickdetector, __cd) end
      end
    end)
  end
end, "L7020")
Tabs.Quests:AddSection("Skull Guitars / Misc")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Skull Guitar"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Soul_Guitar = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.Auto_Soul_Guitar then
      pcall(function()
        local v = GetConnectionEnemies("Living Zombie")
        if v then
          v.HumanoidRootPart.CFrame = CFrame.new(-10138.3974609375, 138.6524658203125, 5902.89208984375)
          v.Head.CanCollide = false
          v.Humanoid.Sit = false
          v.HumanoidRootPart.CanCollide = false
          v.Humanoid.JumpPower = 0
          v.Humanoid.WalkSpeed = 0
          if v.Humanoid:FindFirstChild('Animator') then v.Humanoid:FindFirstChild('Animator'):Destroy() end
        end
      end)
    end
  end
end, "L7050")
function getT(num)
    local rotation
    if num == 1 then
        rotation = workspace.Map["Haunted Castle"].Tablet.Segment1.Line.Rotation
    elseif num == 3 then
        rotation = workspace.Map["Haunted Castle"].Tablet.Segment3.Line.Rotation
    elseif num == 4 then
        rotation = workspace.Map["Haunted Castle"].Tablet.Segment4.Line.Rotation
    elseif num == 7 then
        rotation = workspace.Map["Haunted Castle"].Tablet.Segment7.Line.Rotation
    elseif num == 10 then
        rotation = workspace.Map["Haunted Castle"].Tablet.Segment10.Line.Rotation
    end
    if rotation then
        return rotation.Z
    end
end
function getRT(num)
    local Trophy_Q = workspace.Map["Haunted Castle"].Trophies.Quest
    local Trophy_Pos
    for _, v in pairs(Trophy_Q:GetChildren()) do
        if num == 1 and v.Name == "Trophy1" and v:FindFirstChild("Handle") then
            Trophy_Pos = v.Handle.Rotation
        elseif num == 2 and v.Name == "Trophy2" and v:FindFirstChild("Handle") then
            Trophy_Pos = v.Handle.Rotation
        elseif num == 3 and v.Name == "Trophy3" and v:FindFirstChild("Handle") then
            Trophy_Pos = v.Handle.Rotation
        elseif num == 4 and v.Name == "Trophy4" and v:FindFirstChild("Handle") then
            Trophy_Pos = v.Handle.Rotation
        elseif num == 5 and v.Name == "Trophy5" and v:FindFirstChild("Handle") then
            Trophy_Pos = v.Handle.Rotation
        end
        if Trophy_Pos then
            return Trophy_Pos.Z
        end
    end
end
GetFirePlacard = function(Number,Side)
  if tostring(workspace.Map["Haunted Castle"]["Placard"..Number][Side].Indicator.BrickColor) ~= "Pearl" then
    fireclickdetector(workspace.Map["Haunted Castle"]["Placard"..Number][Side].ClickDetector)
  end
end
__DIO_SafeLoop(function()
  repeat __DIO_wait(0.25) until _G.Auto_Soul_Guitar
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Auto_Soul_Guitar then
        if World3 then
          replicated.Remotes.CommF_:InvokeServer("gravestoneEvent", 2)
          replicated.Remotes.CommF_:InvokeServer("gravestoneEvent", 2, true)
          if replicated.Remotes.CommF_:InvokeServer("GuitarPuzzleProgress","Check") == nil then
            _tp(CFrame.new(-8655.0166015625, 141.3166961669922, 6160.0224609375))
            replicated.Remotes.CommF_:InvokeServer("gravestoneEvent", 2)
            replicated.Remotes.CommF_:InvokeServer("gravestoneEvent", 2, true)
           elseif replicated.Remotes.CommF_:InvokeServer("GuitarPuzzleProgress","Check").Swamp == false then
             local v = GetConnectionEnemies("Living Zombie")
             if v then repeat __DIO_wait(Sec) Attack.Kill(v,_G.Auto_Soul_Guitar) until not _G.Auto_Soul_Guitar or v.Humanoid.Health <= 0 or not v.Parent or workspace.Map["Haunted Castle"].SwampWater.Color ~= Color3.fromRGB(117, 0, 0)
             else _tp(CFrame.new(-10170.7275390625, 138.6524658203125, 5934.26513671875))
             end
           elseif replicated.Remotes.CommF_:InvokeServer("GuitarPuzzleProgress","Check").Gravestones == false then
             GetFirePlacard("7","Left")
             GetFirePlacard("6","Left")
             GetFirePlacard("5","Left")
             GetFirePlacard("4","Right")
             GetFirePlacard("3","Left")
             GetFirePlacard("2","Right")
             GetFirePlacard("1","Right")
           elseif replicated.Remotes.CommF_:InvokeServer("GuitarPuzzleProgress","Check").Ghost == false then
             replicated.Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Ghost")
             replicated.Remotes.CommF_:InvokeServer("GuitarPuzzleProgress", "Ghost", true)
           elseif replicated.Remotes.CommF_:InvokeServer("GuitarPuzzleProgress","Check").Trophies == false then
             _tp(CFrame.new(-9532.8232421875, 6.471667766571045, 6078.068359375))
             repeat __DIO_wait(0.25)
               local z1 = getRT(1)
               local _z1 = getT(1)
               if z1 and _z1 then
                 fireclickdetector(workspace.Map["Haunted Castle"].Tablet.Segment1:FindFirstChild("ClickDetector"))
               end
             until z1 == _z1 or not _G.Auto_Soul_Guitar
            repeat __DIO_wait()
              local z2 = getRT(2)
              local _z2 = getT(3)
              if z2 and _z2 then
                fireclickdetector(workspace.Map["Haunted Castle"].Tablet.Segment3:FindFirstChild("ClickDetector"))
              end
            until z2 == _z2 or not _G.Auto_Soul_Guitar
          repeat __DIO_wait()
            local z3 = getRT(3)
            local _z3 = getT(4)
            if z3 and _z3 then
              fireclickdetector(workspace.Map["Haunted Castle"].Tablet.Segment4:FindFirstChild("ClickDetector"))
            end
          until z3 == _z3 or not _G.Auto_Soul_Guitar
          repeat __DIO_wait()
            local z4 = getRT(4)
            local _z4 = getT(7)
            if z4 and _z4 then
              fireclickdetector(workspace.Map["Haunted Castle"].Tablet.Segment7:FindFirstChild("ClickDetector"))
            end
          until z4 == _z4 or not _G.Auto_Soul_Guitar
        repeat __DIO_wait()
          local z5 = getRT(5)
          local _z5 = getT(10)
          if z5 and _z5 then
            fireclickdetector(workspace.Map["Haunted Castle"].Tablet.Segment10:FindFirstChild("ClickDetector"))
          end
        until z5 == _z5 or not _G.Auto_Soul_Guitar
        repeat __DIO_wait()
          fireclickdetector(workspace.Map["Haunted Castle"].Tablet.Segment2:FindFirstChild("ClickDetector"))
          fireclickdetector(workspace.Map["Haunted Castle"].Tablet.Segment5:FindFirstChild("ClickDetector"))
          fireclickdetector(workspace.Map["Haunted Castle"].Tablet.Segment6:FindFirstChild("ClickDetector"))
          fireclickdetector(workspace.Map["Haunted Castle"].Tablet.Segment8:FindFirstChild("ClickDetector"))
          fireclickdetector(workspace.Map["Haunted Castle"].Tablet.Segment9:FindFirstChild("ClickDetector"))
        until workspace.Map["Haunted Castle"].Tablet.Segment2.Line.Rotation.Z == 0 or workspace.Map["Haunted Castle"].Tablet.Segment5.Line.Rotation.Z == 0 or workspace.Map["Haunted Castle"].Tablet.Segment6.Line.Rotation.Z == 0 or workspace.Map["Haunted Castle"].Tablet.Segment8.Line.Rotation.Z == 0 or workspace.Map["Haunted Castle"].Tablet.Segment9.Line.Rotation.Z == 0 or not _G.Auto_Soul_Guitar
          elseif replicated.Remotes.CommF_:InvokeServer("GuitarPuzzleProgress","Check").Pipes == false then
           _tp(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part3.CFrame)
		   fireclickdetector(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part3.ClickDetector)
		   _tp(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part4.CFrame)
		   fireclickdetector(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part4.ClickDetector)
		   fireclickdetector(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part4.ClickDetector)
		   fireclickdetector(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part4.ClickDetector)
		   _tp(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part6.CFrame)
		   fireclickdetector(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part6.ClickDetector)
		   fireclickdetector(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part6.ClickDetector)
		   _tp(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part8.CFrame)
		   fireclickdetector(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part8.ClickDetector)
	   	   _tp(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part10.CFrame)
		   fireclickdetector(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part10.ClickDetector)
	       fireclickdetector(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part10.ClickDetector)
	       fireclickdetector(workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model.Part10.ClickDetector)
          end
        end
      end
    end)
  end
end, "L7111")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Farm Material Skull Guitar"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoMatSoul = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.AutoMatSoul and GetWP("Skull Guitar") == false then
	    if GetM("Bones") >= 500 and GetM("Ectoplasm") >= 250 and GetM("Dark Fragment") >= 1 then
	      replicated.Remotes.CommF_:InvokeServer("soulGuitarBuy",true)
		else
		  if GetM("Ectoplasm") <= 250 then
		    if _G.AutoMatSoul and World2 then
		      local EctoTable = {"Ship Deckhand","Ship Engineer","Ship Steward","Ship Officer","Arctic Warrior"}
		      local xz = GetConnectionEnemies(EctoTable)
              if xz then repeat __DIO_wait(Sec) Attack.Kill(xz, _G.AutoMatSoul)until not _G.AutoMatSoul or not xz.Parent or xz.Humanoid.Health <= 0
			  else replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(923.21252441406, 126.9760055542, 32852.83203125))
			  end
		    else replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
		    end
		  elseif GetM("Dark Fragment") < 1 then
		    if _G.AutoMatSoul and World2 then
		      local black = GetConnectionEnemies("Darkbeard")
		      if black then repeat __DIO_wait(Sec) Attack.Kill(black, _G.AutoMatSoul)until not _G.AutoMatSoul or black.Humanoid.Health <= 0
		      else _tp(CFrame.new(3798.4575195313, 13.826690673828, -3399.806640625))
		      end
		    else replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
			end
		     if not GetConnectionEnemies("Darkbeard") then Hop() end
	         elseif GetM("Bones") <= 500 then
		       if _G.AutoMatSoul and World3 then
			     local BonesTable = {"Reborn Skeleton","Living Zombie","Demonic Soul","Posessed Mummy"}
			     local zx = GetConnectionEnemies(BonesTable)
	             if zx then repeat __DIO_wait(Sec) Attack.Kill(zx, _G.AutoMatSoul)until not _G.AutoMatSoul or zx.Humanoid.Health <= 0 or not zx.Parent
				 else _tp(CFrame.new(-9504.8564453125, 172.14292907714844, 6057.259765625))
			   end
		     else
		       replicated.Remotes.CommF_:InvokeServer("TravelZou")
		     end
		   end
	     end
	   end
    end)
  end
end, "L7228")
Tabs.Quests:AddSection("Cursed Dual Katana")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Get CDK [ Last Quest ]"],
Description = "",
Default = false,
Callback = function(Value)
  _G.CDK = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.CDK then
        replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress","Good")
        replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress","Evil")
        replicated.Remotes.CommF_:InvokeServer("CDKQuest","StartTrial","Boss")
        local v = GetConnectionEnemies("Cursed Skeleton Boss")
        if v then
          repeat __DIO_wait(0.25)
            if plr.Character:FindFirstChild("Yama") or plr.Backpack:FindFirstChild("Yama") then EquipWeapon("Yama")
            elseif plr.Character:FindFirstChild("Tushita") or plr.Backpack:FindFirstChild("Tushita") then EquipWeapon("Tushita")
            end _tp(v.HumanoidRootPart.CFrame * CFrame.new(0,20,0))
          until not _G.CDK or not v.Parent or v.Humanoid.Health <= 0
        else
          _tp(CFrame.new(-12318.193359375, 601.9518432617188, -6538.662109375)) __DIO_wait(.5)
          _tp(workspace.Map.Turtle.Cursed.BossDoor.CFrame)
        end
      end
    end)
  end
end, "L7278")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Yama CDK"],
Description = "",
Default = false,
Callback = function(Value)
  _G.CDK_YM = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.CDK_YM then
        if tostring(replicated.Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor")) ~= "opened" then
          replicated.Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor")
          replicated.Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor", true)
        else
          if replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Finished"] == nil then
            replicated.Remotes.CommF_:InvokeServer("CDKQuest","StartTrial","Evil")
            replicated.Remotes.CommF_:InvokeServer("CDKQuest","StartTrial","Evil")
          elseif replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Finished"] == false then
            if tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == -3 then
              repeat __DIO_wait(Sec)
                if not workspace.Enemies:FindFirstChild("Forest Pirate") then
                  _tp(CFrame.new(-13223.521484375, 428.1938171386719, -7766.06787109375))
                else
                  local v = GetConnectionEnemies("Forest Pirate")
                  if v then _tp(workspace.Enemies:FindFirstChild("Forest Pirate").HumanoidRootPart.CFrame)end
                end
              until tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == 1 or not _G.CDK_YM
            elseif tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == -4 then
              for ix,HitMon in pairs(__SVC_PLR.LocalPlayer.QuestHaze:GetChildren()) do
                for NameMonHaze, CFramePos in pairs(PosMsList) do
                  if string.find(NameMonHaze,HitMon.Name) and HitMon.Value > 0 then
                    if (CFramePos.Position - Root.Position).Magnitude <= 1000 and workspace.Enemies:FindFirstChild(NameMonHaze) then
                      for i,v in pairs(workspace.Enemies:GetChildren()) do
                        if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v:FindFirstChild("Humanoid").Health > 0 and v:FindFirstChild("HazeESP") then
                          repeat __DIO_wait(0.25) Attack.Kill(v, _G.CDK_YM) until not _G.CDK_YM or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == 2 or not v:FindFirstChild("HazeESP") or v.Humanoid.Health <= 0
                        end
                      end
                    else
                      _tp(CFramePos)
                    end
                  end
                end
              end
            elseif tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == -5 then
              if workspace.Map:FindFirstChild("HellDimension") then
                if (Root.Position - workspace.Map.HellDimension.Spawn.Position).Magnitude <= 1000 then
                  for gg,ez in pairs(workspace.Map.HellDimension.Exit:GetChildren()) do
                    if tonumber(gg) == 2 then
                      repeat __DIO_wait(0.25) Root.CFrame = workspace.Map.HellDimension.Exit.CFrame until not _G.CDK_YM or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == 3
                    end
                  end
                  EquipWeapon(_G.SelectWeapon)
                  if tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) ~= 3 then
                  repeat __DIO_wait(0.25)
                    repeat __DIO_wait(0.25)
                      _tp(workspace.Map.HellDimension.Torch1.Particles.CFrame)
                      for i, v in pairs(workspace.Map.HellDimension:GetDescendants()) do
                        if v:IsA("ProximityPrompt") then fireproximityprompt(v) end
                      end
                    until (workspace.Map.HellDimension.Torch1.Particles.Position - Root.Position).Magnitude < 5
                    __DIO_wait(2) _G.T1Yama = true
                  until not _G.CDK_YM or _G.T1Yama or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == 3
                  repeat __DIO_wait(0.25)
                    repeat __DIO_wait(0.25)
                      _tp(workspace.Map.HellDimension.Torch2.Particles.CFrame)
                      for i, v in pairs(workspace.Map.HellDimension:GetDescendants()) do
                        if v:IsA("ProximityPrompt") then fireproximityprompt(v)end
                      end
                    until (workspace.Map.HellDimension.Torch2.Particles.Position - Root.Position).Magnitude < 5
                    __DIO_wait(2) _G.T2Yama = true
                  until _G.T2Yama or _G.CDK_YM == false or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == 3
                    repeat __DIO_wait(0.25)
                      repeat __DIO_wait(0.25)
                        _tp(workspace.Map.HellDimension.Torch3.Particles.CFrame)
                        for i, v in pairs(workspace.Map.HellDimension:GetDescendants()) do
                          if v:IsA("ProximityPrompt") then fireproximityprompt(v)end
                        end
                      until (workspace.Map.HellDimension.Torch3.Particles.Position - Root.Position).Magnitude < 5
                      __DIO_wait(2) _G.T3Yama = true
                    until _G.T3Yama or _G.CDK_YM == false or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == 3
                  end
                  for i,v in pairs(workspace.Enemies:GetChildren()) do
                    if (v:FindFirstChild("HumanoidRootPart").Position - workspace.Map.HellDimension.Spawn.Position).Magnitude <= 300 then
                      if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v:FindFirstChild("Humanoid").Health > 0 then
                        repeat __DIO_wait(Sec) Attack.Kill(v,_G.CDK_YM) until not _G.CDK_YM or v.Humanoid.Health <= 0 or not v.Parent or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == 3
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end)
  end
end, "L7307")
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.CDK_YM then
        if tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == -5 then
          if not workspace.Map:FindFirstChild("HellDimension") or (Root.Position - workspace.Map.HellDimension.Spawn.Position).Magnitude > 1000 then
            local v = GetConnectionEnemies("Soul Reaper")
            if v then repeat __DIO_wait(0.25)_tp(v.HumanoidRootPart.CFrame) until v.Humanoid.Health <= 0 or not _G.CDK_YM or not v.Parent or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == 3 or (workspace.Map:FindFirstChild("HellDimension") and (Root.Position - workspace.Map.HellDimension.Spawn.Position).Magnitude <= 1000)
            elseif plr.Backpack:FindFirstChild("Hallow Essence") or plr.Character:FindFirstChild("Hallow Essence") then
            repeat _tp(CFrame.new(-8932.322265625, 146.83154296875, 6062.55078125)) __DIO_wait(0.25) until (CFrame.new(-8932.322265625, 146.83154296875, 6062.55078125).Position - Root.Position).Magnitude <= 8
            EquipWeapon("Hallow Essence")
            elseif replicated:FindFirstChild("Soul Reaper") and replicated:FindFirstChild("Soul Reaper").Humanoid.Health > 0 then
              _tp(replicated:FindFirstChild("Soul Reaper").HumanoidRootPart.CFrame)
            else
              if replicated.Remotes.CommF_:InvokeServer("Bones","Check") < 50 and not workspace.Enemies:FindFirstChild("Soul Reaper") and not replicated:FindFirstChild("Soul Reaper") and not workspace.Map:FindFirstChild("HellDimension") then
                if workspace.Enemies:FindFirstChild("Reborn Skeleton") or workspace.Enemies:FindFirstChild("Living Zombie") or workspace.Enemies:FindFirstChild("Domenic Soul") or workspace.Enemies:FindFirstChild("Posessed Mummy") then
                  for i,v in pairs(workspace.Enemies:GetChildren()) do
                    if v.Name == "Reborn Skeleton" or v.Name == "Living Zombie" or v.Name == "Demonic Soul" or v.Name == "Posessed Mummy" then
                      if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v:FindFirstChild("Humanoid").Health > 0 then
                        repeat __DIO_wait(Sec) Attack.Kill(v,_G.CDK_YM)until not _G.CDK_YM or v.Humanoid.Health <= 0 or not v.Parent
                      end
                    end
                  end
                else
                  _tp(CFrame.new(-9515.2255859375, 164.0062255859375, 5785.38330078125))
                end
              else
                replicated.Remotes.CommF_:InvokeServer("Bones", "Buy", 1, 1)
              end
            end
          end
        end
      end
    end)
  end
end, "L7401")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Tushita CDK"],
Description = "",
Default = false,
Callback = function(Value)
  _G.CDK_TS = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.CDK_TS then
        if tostring(replicated.Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor")) ~= "opened" then
          __DIO_wait(.7) replicated.Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor")
          __DIO_wait(.3) replicated.Remotes.CommF_:InvokeServer("CDKQuest", "OpenDoor", true)
        else
          if replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Finished"] == nil then
            replicated.Remotes.CommF_:InvokeServer("CDKQuest","StartTrial","Good")
          elseif replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Finished"] == false then
            if tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == -3 then
              repeat __DIO_wait(0.25) _tp(CFrame.new(-4602.5107421875, 16.446542739868164, -2880.998046875)) until (CFrame.new(-4602.5107421875, 16.446542739868164, -2880.998046875).Position - __SVC_PLR.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 3 or not _G.CDK_TS or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == 1
              if (CFrame.new(-4602.5107421875, 16.446542739868164, -2880.998046875).Position - __SVC_PLR.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 10 then
                __DIO_wait(.7) replicated.Remotes.CommF_:InvokeServer("CDKQuest","BoatQuest",workspace.NPCs:FindFirstChild("Luxury Boat Dealer"),"Check")
                __DIO_wait(.5) replicated.Remotes.CommF_:InvokeServer("CDKQuest","BoatQuest",workspace.NPCs:FindFirstChild("Luxury Boat Dealer"))
              end
                __DIO_wait(1) repeat __DIO_wait(0.25) _tp(CFrame.new(4001.185302734375, 10.089399337768555, -2654.86328125)) until (CFrame.new(4001.185302734375, 10.089399337768555, -2654.86328125).Position - __SVC_PLR.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 3 or not _G.CDK_TS or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == 1
                if (CFrame.new(4001.185302734375, 10.089399337768555, -2654.86328125).Position - __SVC_PLR.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 10 then
                __DIO_wait(.7) replicated.Remotes.CommF_:InvokeServer("CDKQuest","BoatQuest",workspace.NPCs:FindFirstChild("Luxury Boat Dealer"),"Check")
                __DIO_wait(.5) replicated.Remotes.CommF_:InvokeServer("CDKQuest","BoatQuest",workspace.NPCs:FindFirstChild("Luxury Boat Dealer"))
                end
                  __DIO_wait(1) repeat __DIO_wait(0.25) _tp(CFrame.new(-9530.763671875, 7.245208740234375, -8375.5087890625)) until (CFrame.new(-9530.763671875, 7.245208740234375, -8375.5087890625).Position - __SVC_PLR.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 3 or not _G.CDK_TS or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == 1
                  if (CFrame.new(-9530.763671875, 7.245208740234375, -8375.5087890625).Position - __SVC_PLR.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude <= 10 then
                    __DIO_wait(.7) replicated.Remotes.CommF_:InvokeServer("CDKQuest","BoatQuest",workspace.NPCs:FindFirstChild("Luxury Boat Dealer"),"Check")
                    __DIO_wait(.5) replicated.Remotes.CommF_:InvokeServer("CDKQuest","BoatQuest",workspace.NPCs:FindFirstChild("Luxury Boat Dealer"))
                  end
                  __DIO_wait(1)
                  elseif tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == -4 then
                    repeat __DIO_wait(0.25)
                      _G.AutoRaidCastle = true
                    until not _G.CDK_TS or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == 2
                      _G.AutoRaidCastle = false
                  elseif tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == -5 then
                    if workspace.Enemies:FindFirstChild("Cake Queen") then
                      for i,v in pairs(workspace.Enemies:GetChildren()) do
                        if v.Name == "Cake Queen" then
                          if v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
                            repeat __DIO_wait(0.25)
                              Attack.Kill(v, _G.CDK_TS)
                            until not _G.CDK_TS or not v.Parent or v.Humanoid.Health <= 0 or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == 3
                          end
                        end
                      end
                     elseif replicated:FindFirstChild("Cake Queen") and replicated:FindFirstChild("Cake Queen").Humanoid.Health > 0 then
                       _tp(replicated:FindFirstChild("Cake Queen").HumanoidRootPart.CFrame * CFrame.new(0,30,0))
                     else
                   if (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - workspace.Map.HeavenlyDimension.Spawn.Position).Magnitude <= 1000 then
                     for i,v in pairs(workspace.Map.HeavenlyDimension.Exit:GetChildren()) do
                       Ex = i
                     end
                     if Ex == 2 then
                       repeat __DIO_wait(0.25)
                         game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.Map.HeavenlyDimension.Exit.CFrame
                         __DIO_TweenSet(workspace.Map.HeavenlyDimension.Exit.CFrame)
                       until not _G.CDK_TS or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == 3
                    end
                   repeat __DIO_wait(0.25)
                     repeat __DIO_wait(0.25)
                       _tp(CFrame.new(-22529.6171875, 5275.77392578125, 3873.5712890625))
                       for i, v in pairs(workspace.Map.HeavenlyDimension:GetDescendants()) do
                         if v:IsA("ProximityPrompt") then fireproximityprompt(v) end
                       end
                     until (CFrame.new(-22529.6171875, 5275.77392578125, 3873.5712890625).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude < 5
                     __DIO_wait(2)
                    _G.DoneT1 = true
                  until not _G.CDK_TS or _G.DoneT1
                  repeat __DIO_wait(0.25)
                    repeat __DIO_wait(0.25)
                      _tp(CFrame.new(-22637.291015625, 5281.365234375, 3749.28857421875))
                       for i, v in pairs(workspace.Map.HeavenlyDimension:GetDescendants()) do
                         if v:IsA("ProximityPrompt") then fireproximityprompt(v) end
                       end
                    until (CFrame.new(-22637.291015625, 5281.365234375, 3749.28857421875).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude < 5
                    __DIO_wait(2) _G.DoneT2 = true
                  until _G.DoneT2 or _G.CDK_TS == false
                  repeat __DIO_wait(0.25)
                    repeat __DIO_wait(0.25)
                      _tp(CFrame.new(-22791.14453125, 5277.16552734375, 3764.570068359375))
                      for i, v in pairs(workspace.Map.HeavenlyDimension:GetDescendants()) do
                        if v:IsA("ProximityPrompt") then fireproximityprompt(v) end
                      end
                    until (CFrame.new(-22791.14453125, 5277.16552734375, 3764.570068359375).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).Magnitude < 5
                    __DIO_wait(2) _G.DoneT3 = true
                  until _G.DoneT3 or _G.CDK_TS == false
                  for i,v in pairs(workspace.Enemies:GetChildren()) do
                    if (v:FindFirstChild("HumanoidRootPart").Position - CFrame.new(-22695.7012, 5270.93652, 3814.42847, 0.11794927, 3.32185834e-08, 0.99301964, -8.73070718e-08, 1, -2.30819008e-08, -0.99301964, -8.3975138e-08, 0.11794927).Position).Magnitude <= 300 then
                      if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v:FindFirstChild("Humanoid").Health > 0 then
                        repeat __DIO_wait(0.25)
                          Attack.Kill(v, _G.CDK_TS)
                        until not _G.CDK_TS or v.Humanoid.Health <= 0 or not v.Parent
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end)
  end
end, "L7445")
Tabs.Quests:AddSection("True Triple Katana Sword")
Tabs.Quests:AddButton({
Name = __DIO_T["Buy Legendary Sword"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("LegendarySwordDealer","1")
  replicated.Remotes.CommF_:InvokeServer("LegendarySwordDealer","2")
  replicated.Remotes.CommF_:InvokeServer("LegendarySwordDealer","3")
end})
Tabs.Quests:AddButton({
Name = __DIO_T["Buy True Triple Katana Sword"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("MysteriousMan","2")
end})
Tabs.Quests:AddToggle({
Name = __DIO_T["Tween to Legendary Sword Dealer"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Tp_LgS = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.Tp_LgS then
	  pcall(function()
	    for _,v in pairs(replicated.NPCs:GetChildren()) do
	      if v.Name == "Legendary Sword Dealer " then _tp(v.HumanoidRootPart.CFrame) end
        end
	  end)
    end
  end
end, "L7579")
Tabs.Quests:AddSection("Dark Blade V3[Beta] Update Soon")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Dark Blade V3"],
Description = "",
Default = false,
Callback = function(Value)
  _G.DarkBladev3 = Value
  if not Value then __DIO_ReleaseAll("DarkBladev3") StopTween(false) end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.DarkBladev3 and World2 then
      if not GetBP("Dark Blade") then replicated.Remotes.CommF_:InvokeServer("LoadItem","Dark Blade") end
        if GetBP("Fist of Darkness") > 1 then
          if not workspace.Enemies:FindFirstChild("Darkbeard") then
            _tp(CFrame.new(3677.08203125, 62.751937866211, -3144.8332519531))
          elseif GetConnectionEnemies("Darkbeard") and GetBP("Fist of Darkness") >= 1 then
            repeat __DIO_wait(0.25) _tp(CFrame.new(-5719.36376953125, 48.50590515136719, -782.9759521484375)) until not _G.DarkBladev3 or (Root.Position - CFrame.new(-5719.36376953125, 48.50590515136719, -782.9759521484375)).Magnitude <= 5
            fireclickdetector(workspace.Map.GraveIsland.Mountain.Rocks.Button.ClickDetector)
          end
        else
          __DIO_BorrowFlag("DarkBladev3","AutoFarmChest")
        end
      else
        __DIO_ReleaseFlag("DarkBladev3","AutoFarmChest")
      end
    end)
  end
end, "L7981")
Tabs.Quests:AddSection("Pole / God Enal's")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Pole V1"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoPole = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.AutoPole then
      pcall(function()
        local v = GetConnectionEnemies("Thunder God")
	    if v then
          repeat __DIO_wait(Sec) Attack.Kill(v, _G.AutoPole) until not _G.AutoPole or not v.Parent or v.Humanoid.Health <= 0
        else
          _tp(CFrame.new(-7994.984375, 5761.025390625, -2088.6479492188))
        end
      end)
    end
  end
end, "L7599")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Pole V2 [Beta]"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoPoleV2 = Value
  if not Value then __DIO_ReleaseAll("AutoPoleV2") StopTween(false) end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.AutoPoleV2 then
	   if not GetBP("Pole (1st Form)") then replicated.Remotes.CommF_:InvokeServer("LoadItem","Pole (1st Form)") end
	   if not GetBP("Pole (2nd Form)") then replicated.Remotes.CommF_:InvokeServer("LoadItem","Pole (2nd Form)") end
	   if GetBP("Pole (1st Form)") and GetBP("Pole (1st Form)").Level.Value <= 179 then __DIO_SetFlag("Level","AutoPoleV2",true) elseif GetBP("Pole (1st Form)") and GetBP("Pole (1st Form)").Level.Value >= 180 then __DIO_SetFlag("Level","AutoPoleV2",false) end
	   if not GetBP("Rumble Fruit") then return end
	   if GetBP("Rumble Fruit").AwakenedMoves:FindFirstChild("Z") and GetBP("Rumble Fruit").AwakenedMoves:FindFirstChild("X") and GetBP("Rumble Fruit").AwakenedMoves:FindFirstChild("C") and GetBP("Rumble Fruit").AwakenedMoves:FindFirstChild("V") and GetBP("Rumble Fruit").AwakenedMoves:FindFirstChild("F") then
	     _G.SelectChip = nil
		 __DIO_ReleaseFlag("AutoPoleV2","Raiding")
		 __DIO_ReleaseFlag("AutoPoleV2","Auto_Awakener")
		if plr.Data.Fragments.Value >= 5000 then
          replicated.Remotes.CommF_:InvokeServer("Thunder God", "Talk") __DIO_wait(Sec)
          replicated.Remotes.CommF_:InvokeServer("Thunder God", "Sure")
        end
        elseif replicated.Remotes.CommF_:InvokeServer("Awakener","Check") == nil or replicated.Remotes.CommF_:InvokeServer("Awakener","Check") == 0 then
          _G.SelectChip = "Rumble"
          local Buying = replicated.Remotes.CommF_:InvokeServer("RaidsNpc","Select",_G.SelectChip)
          if Buying then Buying:Stop() end
          __DIO_BorrowFlag("AutoPoleV2","Raiding")
          __DIO_BorrowFlag("AutoPoleV2","Auto_Awakener")
	    end
      end
    end)
  end
end, "L7620")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Saw Sword"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoSaw = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.AutoSaw then
        local v = GetConnectionEnemies("The Saw")
        if v then repeat __DIO_wait(Sec) Attack.Kill(v, _G.AutoSaw)until _G.AutoSaw == false or v.Humanoid.Health <= 0
        else _tp(CFrame.new(-784.89715576172, 72.427383422852, 1603.5822753906))
        end
      end
    end)
  end
end, "L7654")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Saber Sword"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoSaber = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.AutoSaber and plr.Data.Level.Value >= 200 and not plr.Backpack:FindFirstChild("Saber") and not plr.Character:FindFirstChild("Saber") then
        if workspace.Map.Jungle.Final.Part.Transparency == 0 then
	      if workspace.Map.Jungle.QuestPlates.Door.Transparency == 0 then
		    if (CFrame.new(-1612.55884, 36.9774132, 148.719543, 0.37091279, 3.0717151e-09, -0.928667724, 3.97099491e-08, 1, 1.91679348e-08, 0.928667724, -4.39869794e-08, 0.37091279).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 100 then
		      __DIO_TweenTarget = nil
		      __DIO_wait(0.5)
		      plr.Character.HumanoidRootPart.CFrame = workspace.Map.Jungle.QuestPlates.Plate1.Button.CFrame
		      __DIO_wait(0.5)
		      plr.Character.HumanoidRootPart.CFrame = workspace.Map.Jungle.QuestPlates.Plate2.Button.CFrame
		      __DIO_wait(0.5)
		      plr.Character.HumanoidRootPart.CFrame = workspace.Map.Jungle.QuestPlates.Plate3.Button.CFrame
	    	  __DIO_wait(0.5)
		      plr.Character.HumanoidRootPart.CFrame = workspace.Map.Jungle.QuestPlates.Plate4.Button.CFrame
		      __DIO_wait(0.5)
		      plr.Character.HumanoidRootPart.CFrame = workspace.Map.Jungle.QuestPlates.Plate5.Button.CFrame
		      __DIO_wait(0.5)
		    else
		      _tp(CFrame.new(-1612.55884, 36.9774132, 148.719543, 0.37091279, 3.0717151e-09, -0.928667724, 3.97099491e-08, 1, 1.91679348e-08, 0.928667724, -4.39869794e-08, 0.37091279))
		    end
	      else
		    if workspace.Map.Desert.Burn.Part.Transparency == 0 then
		      if plr.Backpack:FindFirstChild("Torch") or plr.Character:FindFirstChild("Torch") then
		        EquipWeapon("Torch")
		        firetouchinterest(plr.Character.Torch.Handle,workspace.Map.Desert.Burn.Fire,0)
			    firetouchinterest(plr.Character.Torch.Handle,workspace.Map.Desert.Burn.Fire,1)
		   	    _tp(CFrame.new(1114.61475, 5.04679728, 4350.22803, -0.648466587, -1.28799094e-09, 0.761243105, -5.70652914e-10, 1, 1.20584542e-09, -0.761243105, 3.47544882e-10, -0.648466587))
		      else
		        _tp(CFrame.new(-1610.00757, 11.5049858, 164.001587, 0.984807551, -0.167722285, -0.0449818149, 0.17364943, 0.951244235, 0.254912198, 3.42372805e-05))
                replicated.Remotes.CommF_:InvokeServer("ProQuestProgress", "GetCup")
			      __DIO_wait(0.5)
			      EquipWeapon("Cup")
			      __DIO_wait(0.5)
			      replicated.Remotes.CommF_:InvokeServer("ProQuestProgress","FillCup",plr.Character.Cup)
			      __DIO_wait(Sec)
replicated.Remotes.CommF_:InvokeServer("ProQuestProgress","SickMan")
if replicated.Remotes.CommF_:InvokeServer("ProQuestProgress","RichSon") == nil then
			        replicated.Remotes.CommF_:InvokeServer("ProQuestProgress","RichSon")
		          elseif replicated.Remotes.CommF_:InvokeServer("ProQuestProgress","RichSon") == 0 then
			        if workspace.Enemies:FindFirstChild("Mob Leader") or replicated:FindFirstChild("Mob Leader") then
			          _tp(CFrame.new(-2967.59521, -4.91089821, 5328.70703, 0.342208564, -0.0227849055, 0.939347804, 0.0251603816, 0.999569714, 0.0150796166, -0.939287126, 0.0184739735, 0.342634559))
			         for i,v in pairs(workspace.Enemies:GetChildren()) do
				       if v.Name == "Mob Leader" and Attack.Alive(v) then
				       repeat __DIO_wait(Sec) Attack.Kill(v, _G.AutoSaber)until v.Humanoid.Health <= 0 or _G.AutoSaber == false
				       end
				     end
			       end
			     elseif replicated.Remotes.CommF_:InvokeServer("ProQuestProgress","RichSon") == 1 then
			       replicated.Remotes.CommF_:InvokeServer("ProQuestProgress","RichSon")
				   EquipWeapon("Relic")
				  _tp(CFrame.new(-1404.91504, 29.9773273, 3.80598116, 0.876514494, 5.66906877e-09, 0.481375456, 2.53851997e-08, 1, -5.79995607e-08, -0.481375456, 6.30572643e-08, 0.876514494))
				 end
			   end
			 end
		   end
		 else
	     if workspace.Enemies:FindFirstChild("Saber Expert") or replicated:FindFirstChild("Saber Expert") then
	       for _,v in pairs(workspace.Enemies:GetChildren()) do
		     if v.Name == "Saber Expert" and Attack.Alive(v) then
			   repeat __DIO_wait(Sec) Attack.Kill(v, _G.AutoSaber) until v.Humanoid.Health <= 0 or _G.AutoSaber == false
		       if v.Humanoid.Health <= 0 then replicated.Remotes.CommF_:InvokeServer("ProQuestProgress","PlaceRelic") end
		      end
		    end
		  else
		    _tp(CFrame.new(-1401.85046, 29.9773273, 8.81916237, 0.85820812, 8.76083845e-08, 0.513301849, -8.55007443e-08, 1, -2.77243419e-08, -0.513301849, -2.00944328e-08, 0.85820812))
	      end
	    end
      end
    end)
  end
end, "L7674")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Cybrog"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoColShad = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.AutoColShad then
      pcall(function()
        local v = GetConnectionEnemies("Cyborg")
	    if v then repeat __DIO_wait(Sec) Attack.Kill(v, _G.AutoColShad)until _G.AutoColShad == false or not v.Parent or v.Humanoid.Health <= 0
        else _tp(CFrame.new(6094.0249023438, 73.770050048828, 3825.7348632813))
        end
      end)
    end
  end
end, "L7756")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Usoap's Hat"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoGetUsoap = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.AutoGetUsoap then
	   for _, v in pairs(workspace.Characters:GetChildren()) do
          if v.Name ~= plr.Name then
            if v.Humanoid.Health > 0 and v:FindFirstChild("HumanoidRootPart") and v.Parent and (Root.Position - v.HumanoidRootPart.Position).Magnitude <= 230 then
              repeat __DIO_wait(0.25) EquipWeapon(_G.SelectWeapon) _tp(v.HumanoidRootPart.CFrame * CFrame.new(1, 1, 2)) until _G.AutoGetUsoap == false or v.Humanoid.Health <= 0 or not v.Parent or not v:FindFirstChild("HumanoidRootPart") or not v:FindFirstChild("Humanoid")
            end
          end
        end
      end
    end)
  end
end, "L7775")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Bisento V2"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Greybeard = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.Greybeard then
      pcall(function()
        if not GetWP("Bisento") then
          replicated.Remotes.CommF_:InvokeServer("BuyItem","Bisento")
        elseif GetWP("Bisento") then
          replicated.Remotes.CommF_:InvokeServer("LoadItem","Bisento")
          local v = GetConnectionEnemies("Greybeard")
          if v then repeat __DIO_wait(0.25) Attack.Kill(v,_G.Greybeard)until _G.Greybeard == false or not v.Parent or v.Humanoid.Health <= 0
          else _tp(CFrame.new(-5023.38330078125, 28.65203285217285, 4332.3818359375))
          end
        end
      end)
    end
  end
end, "L7797")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Warden Sword"],
Description = "",
Default = false,
Callback = function(Value)
  _G.WardenBoss = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.WardenBoss then
      pcall(function()
        local v = GetConnectionEnemies("Chief Warden")
        if v then repeat __DIO_wait(0.25) Attack.Kill(v,_G.WardenBoss) until _G.WardenBoss == false or not v.Parent or v.Humanoid.Health <= 0
        else _tp(CFrame.new(5206.92578,0.997753382,814.976746,0.342041343,-0.00062915677,0.939684749,0.00191645394,0.999998152,-2.80422337e-05,-0.939682961,0.00181045406,0.342041939))
        end
      end)
    end
  end
end, "L7821")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Marine Coat"],
Description = "",
Default = false,
Callback = function(Value)
  _G.MarinesCoat = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.MarinesCoat then
      pcall(function()
        local v = GetConnectionEnemies("Vice Admiral")
        if v then repeat __DIO_wait(0.25) Attack.Kill(v, _G.MarinesCoat) until _G.MarinesCoat == false or not v.Parent or v.Humanoid.Health <= 0
        else _tp(CFrame.new(-5006.5454101563, 88.032081604004, 4353.162109375))
        end
      end)
    end
  end
end, "L7840")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Swan Coat"],
Description = "",
Default = false,
Callback = function(Value)
  _G.SwanCoat = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.SwanCoat then
      pcall(function()
        local v = GetConnectionEnemies("Swan")
        if v then repeat __DIO_wait(0.25)Attack.Kill(v, _G.SwanCoat)until _G.SwanCoat == false or not v.Parent or v.Humanoid.Health <= 0
        else _tp(CFrame.new(5325.09619, 7.03906584, 719.570679, -0.309060812, 0, 0.951042235, 0, 1, 0, -0.951042235, 0, -0.309060812))
        end
      end)
    end
  end
end, "L7859")
Tabs.Quests:AddSection("Rengoku Sword")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Rengoku Sword"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: tat toggle van con tween/highlight/shouldTween (FlyTo khong co cancel bay toi 300s)
  __DIO_FeatToggle("IceBossRen", Value)
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.IceBossRen then
        local v = GetConnectionEnemies("Awakened Ice Admiral")
        if v then repeat __DIO_wait(Sec) Attack.Kill(v,_G.IceBossRen)until _G.IceBossRen ~= true or not v.Parent or v.Humanoid.Health <= 0
        elseif _G.IceBossRen == true then
          __DIO_FlyTo(CFrame.new(5668.9780273438, 28.519989013672, -6483.3520507813), 10, function() return _G.IceBossRen ~= true end)
        end
      end
    end)
  end
end, "L7880")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Key Rengoku"],
Description = "",
Default = false,
Callback = function(Value)
  __DIO_FeatToggle("KeysRen", Value)
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.KeysRen then
        if plr.Backpack:FindFirstChild(RenMon[3]) or plr.Character:FindFirstChild(RenMon[3]) then
          EquipWeapon(RenMon[3]) __DIO_wait(.1)
          if _G.KeysRen == true then _tp(CFrame.new(6571.1201171875, 299.23028564453, -6967.841796875)) end
        else
          local v = GetConnectionEnemies(RenMon)
          if v then repeat __DIO_wait(Sec) Attack.Kill(v,_G.KeysRen)until plr.Backpack:FindFirstChild(RenMon[3]) or _G.KeysRen ~= true or not v.Parent or v.Humanoid.Health <= 0
          elseif _G.KeysRen == true then _tp(CFrame.new(5439.716796875, 84.420944213867, -6715.1635742188))
          end
        end
      end
    end)
  end
end, "L7900")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Dragon Trident"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoTridentW2 = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.AutoTridentW2 then
        local v = GetConnectionEnemies("Tide Keeper")
        if v then repeat __DIO_wait(Sec) Attack.Kill(v,_G.AutoTridentW2)until _G.AutoTridentW2 == false or not v.Parent or v.Humanoid.Health <= 0
        else _tp(CFrame.new(-3795.6423339844, 105.88877105713, -11421.307617188))
        end
      end
    end)
  end
end, "L7924")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Long Sword"],
Description = "",
Default = false,
Callback = function(Value)
  _G.LongsWord = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.LongsWord then
        local v = GetConnectionEnemies("Diamond")
        if v then repeat __DIO_wait(Sec) Attack.Kill(v,_G.LongsWord)until _G.LongsWord == false or not v.Parent or v.Humanoid.Health <= 0
        else _tp(CFrame.new(-1576.7166748047, 198.59265136719, 13.724286079407))
        end
      end
    end)
  end
end, "L7943")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Black Spikey"],
Description = "",
Default = false,
Callback = function(Value)
  _G.BlackSpikey = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.BlackSpikey then
      pcall(function()
        local v = GetConnectionEnemies("Jeremy")
        if v then repeat __DIO_wait(0.25) Attack.Kill(v, _G.BlackSpikey)until _G.BlackSpikey == false or not v.Parent or v.Humanoid.Health <= 0
        else _tp(CFrame.new(2006.9261474609, 448.95666503906, 853.98284912109))
        end
      end)
    end
  end
end, "L7962")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Midnight Blade"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoEcBoss = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.AutoEcBoss then
	    if GetM("Ectoplasm") >= 99 then
	      replicated.Remotes.CommF_:InvokeServer("Ectoplasm","Buy", 3)
	    elseif GetM("Ectoplasm") <= 99 then
	      local v = GetConnectionEnemies("Cursed Captain")
	      if v then repeat __DIO_wait(0.25)Attack.Kill(v, _G.AutoEcBoss) until not _G.AutoEcBoss or not v.Parent or v.Humanoid.Health <= 0
	      else
	        replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(923.21252441406, 126.9760055542, 32852.83203125)) __DIO_wait(.5)
	        _tp(CFrame.new(916.928589, 181.092773, 33422))
	      end
	    end
      end
    end)
  end
end, "L8007")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Darkbeard"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Def_DarkCoat = Value
  if not Value then __DIO_ReleaseAll("Auto_Def_DarkCoat") StopTween(false) end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.Auto_Def_DarkCoat then
      pcall(function()
        if GetBP("Fist of Darkness") and not workspace.Enemies:FindFirstChild("Darkbeard") then
          _tp(CFrame.new(3677.08203125, 62.751937866211, -3144.8332519531))
        elseif GetConnectionEnemies("Darkbeard") then
          local v = GetConnectionEnemies("Darkbeard")
		  if v then repeat __DIO_wait(0.25)Attack.Kill(v,_G.Auto_Def_DarkCoat)until _G.Auto_Def_DarkCoat == false or not v.Parent or v.Humanoid.Health <= 0 end
        elseif not GetBP("Fist of Darkness") and not GetConnectionEnemies("Darkbeard") then
          repeat __DIO_wait(.1) __DIO_BorrowFlag("Auto_Def_DarkCoat","AutoFarmChest") until not _G.Auto_Def_DarkCoat or GetBP("Fist of Darkness") or GetConnectionEnemies("Darkbeard")
          __DIO_ReleaseFlag("Auto_Def_DarkCoat","AutoFarmChest")
        end
      end)
    end
  end
end, "L8032")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Unlocked DonSwan"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_DonAcces = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.Auto_DonAcces then
      pcall(function()
        if replicated.Remotes.CommF_:InvokeServer("GetUnlockables").FlamingoAccess == nil and plr.Data.Level.Value >= 1500 then
          FruitPrice = {}
	      FruitStore = {}
		  for i,v in next,replicated:WaitForChild("Remotes").CommF_:InvokeServer("GetFruits") do
		    if v.Price >= 1000000 then
		     table.insert(FruitPrice,v.Name)
		    end
		  end
		  for i,v in pairs(replicated.Remotes["CommF_"]:InvokeServer("getInventoryFruits")) do
		    for __fk, x in pairs(v) do
		      if __fk == "Name" then
		        table.insert(FruitStore,x)
		      end
	        end
	          replicated.Remotes.CommF_:InvokeServer("Cousin","Buy")
	          for _,y in pairs(FruitPrice) do
		        for _,z in pairs(FruitStore) do
		          if y == z and replicated.Remotes.CommF_:InvokeServer("GetUnlockables").FlamingoAccess == nil then
		            _G.StoreF = false
			      if not plr.Backpack:FindFirstChild(FruitStore) then
			        replicated.Remotes.CommF_:InvokeServer("LoadFruit",tostring(y))
			      else
			        replicated.Remotes.CommF_:InvokeServer("TalkTrevor","1")
			        replicated.Remotes.CommF_:InvokeServer("TalkTrevor","2")
			        replicated.Remotes.CommF_:InvokeServer("TalkTrevor","3")
			      end
			    end
		      end
		    end
		    if replicated.Remotes.CommF_:InvokeServer("GetUnlockables").FlamingoAccess ~= nil then
		      _G.StoreF = true
		      _G.Auto_DonAcces = false
		    end
	      end
        end
      end)
    end
  end
end, "L8055")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Swan Glasses"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_SwanGG = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.Auto_SwanGG then
      pcall(function()
        local v = GetConnectionEnemies("Don Swan")
        if v then repeat __DIO_wait(0.25) Attack.Kill(v,_G.Auto_SwanGG)until _G.Auto_SwanGG == false or not v.Parent or v.Humanoid.Health <= 0
	    else _tp(CFrame.new(2286.2004394531, 15.177839279175, 863.8388671875))
        end
      end)
    end
  end
end, "L8105")
Tabs.Quests:AddSection("Cavender + Twin Hooks + Bigmom")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Bigmom"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoBigmom = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.AutoBigmom then
      pcall(function()
        local bx = GetConnectionEnemies("Cake Queen")
        if bx then repeat __DIO_wait(Sec) Attack.Kill(bx, _G.AutoBigmom) until not _G.AutoBigmom or not bx.Parent or bx.Humanoid.Health <= 0
        else _tp(CFrame.new(-709.3132934570312, 381.6005859375, -11011.396484375))
        end
      end)
    end
  end
end, "L8126")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Canvendish Sword"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Cavender = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Auto_Cavender then
        local v = GetConnectionEnemies("Beautiful Pirate")
	    if v then repeat __DIO_wait(0.25) Attack.Kill(v,_G.Auto_Cavender)until not _G.Auto_Cavender or v.Humanoid.Health <= 0
	    else _tp(CFrame.new(5283.609375,22.56223487854,-110.78285217285))
	    end
      end
    end)
  end
end, "L8145")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Twin Hooks"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: truoc day toggle nay chi tao highlight, khong co shouldTween; tat thi van tween
  __DIO_FeatToggle("TwinHook", Value)
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.TwinHook then
        local v = GetConnectionEnemies("Captain Elephant")
	    if v then repeat __DIO_wait(0.25)Attack.Kill(v,_G.TwinHook)until not _G.TwinHook or not v.Parent or v.Humanoid.Health <= 0
	    elseif _G.TwinHook == true then
          -- FIX: truoc day requestEntrance Mansion MOI 0.45s -> nguoi choi bi keo ve cua Mansion lien tuc,
          -- tween khong bao gio di duoc (chi thay highlight). Gio chi requestEntrance khi o xa (> 2500)
          -- va toi da 1 lan / 10s; con lai tween binh thuong den cho Captain Elephant.
          local __twCF = CFrame.new(-13376.7578125, 433.28689575195, -8071.392578125)
          local __hTw = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
          if __hTw and (__hTw.Position - __twCF.Position).Magnitude > 2500 and tick() - (__DIO_TwinEntT or 0) > 10 then
            __DIO_TwinEntT = tick()
            pcall(function() replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-12471.169921875, 374.94024658203, -7551.677734375)) end)
            __DIO_wait(.3)
          end
          if _G.TwinHook == true then shouldTween = true _tp(__twCF) end
	    end
      end
    end)
  end
end, "L8164")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Serpent Bow"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoSerpentBow = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
    if _G.AutoSerpentBow then
      local v = GetConnectionEnemies("Hydra Leader")
      if v then	repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoSerpentBow)until not _G.AutoSerpentBow or not v.Parent or v.Humanoid.Health <= 0
	  else _tp(CFrame.new(5821.89794921875, 1019.0950927734375, -73.71923065185547))
      end
    end
    end)
  end
end, "L8185")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Lei Accessory"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoKilo = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.AutoKilo then
      pcall(function()
        local v = GetConnectionEnemies("Kilo Admiral")
        if v then repeat __DIO_wait(Sec) Attack.Kill(v,_G.AutoKilo)until not _G.AutoKilo or not v.Parent or v.Humanoid.Health <= 0
        else _tp(CFrame.new(2764.2233886719, 432.46154785156, -7144.4580078125))
        end
      end)
    end
  end
end, "L8205")
Tabs.Quests:AddSection("Collect Berry")
Berry = Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Farm Berry"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoBerry = Value
  if not Value then
    StopTween(false)
  end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(0.3) do
    if _G.AutoBerry then
      pcall(__DIO_FarmBerryStep)
    end
  end
end, "L8227")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Farm Berry + Hop"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoBerryH = Value
  if not Value then
    StopTween(false)
  end
end})
Tabs.Quests:AddSection("Buso/Aura Colours")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Teleport Barista Cousin"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Tp_MasterA = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.Tp_MasterA then
	  pcall(function()
	    for _,v in pairs(replicated.NPCs:GetChildren()) do
	    if v.Name == "Barista Cousin" then _tp(v.HumanoidRootPart.CFrame) end
        end
	 end)
    end
  end
end, "L8250")
Tabs.Quests:AddButton({
Name = __DIO_T["Buy Buso Colors"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("ColorsDealer","2")
end})
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Rainbow Colors"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Rainbow_Haki = Value
end})
spawn(function()
  while true do
  local __okRB, __errRB = pcall(function()
    while __DIO_wait(Sec) do
      if _G.Auto_Rainbow_Haki then
        local __qH = __DIO_GetCurrentQuest()
        if not __qH.IsActive then
          if _G.GetQFast then
            if __DIO_QuestGone() then replicated.Remotes.CommF_:InvokeServer("HornedMan","Bet") end
          else
            Rainbow1 = CFrame.new(-11892.0703125, 930.57672119141, -8760.1591796875)
            if (plr.Character.HumanoidRootPart.Position - Rainbow1.Position).Magnitude > 5 then
              _tp(Rainbow1)
            elseif (plr.Character.HumanoidRootPart.Position - Rainbow1.Position).Magnitude <= 5 then
              __DIO_wait(1)
              replicated.Remotes.CommF_:InvokeServer("HornedMan","Bet")
            end
          end
          elseif __qH.IsActive and string.find(__qH.QuestText, "Stone", 1, true) then
            local v = GetConnectionEnemies("Stone")
            if v then
              repeat __DIO_wait(0.25) Attack.Kill(v,_G.Auto_Rainbow_Haki) until _G.Auto_Rainbow_Haki == false or v.Humanoid.Health <= 0 or not v.Parent or __DIO_QuestGone()
            else
              _tp(CFrame.new(-1086.11621, 38.8425903, 6768.71436, 0.0231462717, -0.592676699, 0.805107772, 2.03251839e-05, 0.805323839, 0.592835128, -0.999732077, -0.0137055516, 0.0186523199))
            end
          elseif __qH.IsActive and string.find(__qH.QuestText, "Hydra Leader", 1, true) then
            local v = GetConnectionEnemies("Hydra Leader")
            if v then
              repeat __DIO_wait(Sec) Attack.Kill(v,_G.Auto_Rainbow_Haki) until _G.Auto_Rainbow_Haki == false or v.Humanoid.Health <= 0 or not v.Parent or __DIO_QuestGone()
            else
              replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(5643.45263671875, 1013.0858154296875, -340.51025390625))
              local framelong1 = Vector3.new(5643.45263671875, 1013.0858154296875, -340.51025390625)
              local framelong2 = CFrame.new(5821.89794921875, 1019.0950927734375, -73.71923065185547)
              if (plr.Character.HumanoidRootPart.Position - framelong1).Magnitude <= 5 then _tp(framelong2) end
            end
          elseif __qH.IsActive and string.find(__qH.QuestText, "Kilo Admiral", 1, true) then
            local v = GetConnectionEnemies("Kilo Admiral")
            if v then
              repeat __DIO_wait(Sec) Attack.Kill(v,_G.Auto_Rainbow_Haki) until _G.Auto_Rainbow_Haki == false or v.Humanoid.Health <= 0 or not v.Parent or __DIO_QuestGone()
            else
              _tp(CFrame.new(2877.61743, 423.558685, -7207.31006, -0.989591599, -0, -0.143904909, -0, 1.00000012, -0, 0.143904924, 0, -0.989591479))
            end
            elseif __qH.IsActive and string.find(__qH.QuestText, "Captain Elephant", 1, true) then
              local v = GetConnectionEnemies("Captain Elephant")
              if v then
                repeat __DIO_wait(Sec) Attack.Kill(v,_G.Auto_Rainbow_Haki)until _G.Auto_Rainbow_Haki == false or v.Humanoid.Health <= 0 or not v.Parent or __DIO_QuestGone()
              else
              local gamergayror1 = Vector3.new(-12471.169921875, 374.94024658203, -7551.677734375)
              local gamergayror2 = CFrame.new(-13376.7578125, 433.28689575195, -8071.392578125)
              if (plr.Character.HumanoidRootPart.Position - gamergayror1).Magnitude > 5 then
                replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-12471.169921875, 374.94024658203, -7551.677734375))
              elseif (plr.Character.HumanoidRootPart.Position - gamergayror1).Magnitude <= 5 then
                _tp(gamergayror2)
              end
            end
        elseif __qH.IsActive and string.find(__qH.QuestText, "Beautiful Pirate", 1, true) then
          local v = GetConnectionEnemies("Beautiful Pirate")
          if v then
            repeat __DIO_wait(Sec) Attack.Kill(v,_G.Auto_Rainbow_Haki) until _G.Auto_Rainbow_Haki == false or v.Humanoid.Health <= 0 or not v.Parent or __DIO_QuestGone()
          else
            replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(5314.54638671875, 22.562219619750977, -127.06755065917969))
          end
        end
      end
    end
  end)
  if not __okRB then warn("[DIO] Auto_Rainbow_Haki loop died -> restart: " .. tostring(__errRB)) end
  task.wait(0.5)
  end
end)
Tabs.Quests:AddToggle({
Name = __DIO_T["Accept Rainbow Quest Faster"],
Description = "",
Default = false,
Callback = function(Value)
  _G.GetQFast = Value
end})
Tabs.Quests:AddSection("Instinct / Observation")
local KenCheck = Tabs.Quests:AddParagraph("Ken (Observation)", "0 / 5000")
local __kenPrevTxt = ""
local function __DIO_KenShow(val)
    local v = tonumber(val) or 0
    local txt = tostring(v) .. " / 5000"
    if txt == __kenPrevTxt then return end
    __kenPrevTxt = txt
    pcall(function()
        if KenCheck and type(KenCheck.SetText) == "function" then
            KenCheck:SetText(txt)
        elseif KenCheck and type(KenCheck.SetDesc) == "function" then
            KenCheck:SetDesc(txt)
        end
    end)
end
local __DIO_KenRemote = nil
pcall(function()
    local __rmK = __SVC_RS:FindFirstChild("Remotes")
    __DIO_KenRemote = __rmK and __rmK:FindFirstChild("CheckKenStatus")
end)
local function __DIO_KenLocal()
    local okA, aA = pcall(function() return plr:GetAttribute("KenDodgesLeft") end)
    __DIO_KenShow((okA and aA) or 0)
end
local function __DIO_KenFetch()
    if __DIO_KenRemote == nil then
        pcall(function()
            local __rmK = __SVC_RS:FindFirstChild("Remotes")
            __DIO_KenRemote = __rmK and __rmK:FindFirstChild("CheckKenStatus")
        end)
    end
    if __DIO_KenRemote ~= nil then
        local okK, resK = pcall(function() return __DIO_KenRemote:InvokeServer() end)
        if okK and resK ~= nil then
            __DIO_KenShow(resK)
            return
        end
    end
    __DIO_KenLocal()
end
pcall(function()
    plr:GetAttributeChangedSignal("KenDodgesLeft"):Connect(function()
        local okA2, aA2 = pcall(function() return plr:GetAttribute("KenDodgesLeft") end)
        __DIO_KenShow((okA2 and aA2) or 0)
    end)
end)
pcall(__DIO_KenFetch)
__DIO_SafeLoop(function()
    while __DIO_wait(3) do
        pcall(__DIO_KenFetch)
    end
end, "KenCheck")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Farm Observation"],
Description = "",
Default = false,
Callback = function(Value)
  _G.obsFarm = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.obsFarm then
        replicated.Remotes.CommE:FireServer("Ken",true)
        if plr:GetAttribute("KenDodgesLeft") == 0 then
          KenTest = false
        elseif plr:GetAttribute("KenDodgesLeft") > 0 then
          replicated.Remotes.CommE:FireServer("Ken",true)
          KenTest = true
        end
      end
    end)
  end
end, "L8363")
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.obsFarm then
        if World1 then
          if workspace.Enemies:FindFirstChild("Galley Captain") then
            if KenTest then
              repeat __DIO_wait(0.25)
                plr.Character.HumanoidRootPart.CFrame = workspace.Enemies:FindFirstChild("Galley Captain").HumanoidRootPart.CFrame * CFrame.new(3,0,0)
                __DIO_TweenSet(plr.Character.HumanoidRootPart.CFrame)
              until _G.obsFarm == false or KenTest == false
            else
              repeat __DIO_wait(0.25)
                plr.Character.HumanoidRootPart.CFrame = workspace.Enemies:FindFirstChild("Galley Captain").HumanoidRootPart.CFrame * CFrame.new(0,50,0)
                __DIO_TweenSet(plr.Character.HumanoidRootPart.CFrame)
              until _G.obsFarm == false or KenTest
            end
          else
            _tp(CFrame.new(5533.29785, 88.1079102, 4852.3916))
          end
        elseif World2 then
          if workspace.Enemies:FindFirstChild("Lava Pirate") then
            if KenTest then
              repeat __DIO_wait(0.25)
                plr.Character.HumanoidRootPart.CFrame = workspace.Enemies:FindFirstChild("Lava Pirate").HumanoidRootPart.CFrame * CFrame.new(3,0,0)
                __DIO_TweenSet(plr.Character.HumanoidRootPart.CFrame)
              until _G.obsFarm == false or KenTest == false
            else
              repeat __DIO_wait(0.25)
                plr.Character.HumanoidRootPart.CFrame = workspace.Enemies:FindFirstChild("Lava Pirate").HumanoidRootPart.CFrame * CFrame.new(0,50,0)
                __DIO_TweenSet(plr.Character.HumanoidRootPart.CFrame)
              until _G.obsFarm == false or KenTest
            end
          else
            _tp(CFrame.new(-5478.39209, 15.9775667, -5246.9126))
          end
        elseif World3 then
          if workspace.Enemies:FindFirstChild("Venomous Assailant") then
            if KenTest then
              repeat __DIO_wait(0.25)
                _tp(workspace.Enemies:FindFirstChild("Venomous Assailant").HumanoidRootPart.CFrame * CFrame.new(3,0,0))
              until _G.obsFarm == false or KenTest == false
            else
              repeat __DIO_wait(0.25)
                _tp(workspace.Enemies:FindFirstChild("Venomous Assailant").HumanoidRootPart.CFrame * CFrame.new(0,50,0))
              until _G.obsFarm == false or KenTest
            end
          else
            _tp(CFrame.new(4530.3540039063, 656.75695800781, -131.60952758789))
          end
        end
      end
    end)
  end
end, "L8378")
__DIO_GetCurrentQuest = function()
  local __ok, __res = pcall(function()

    local __text = ""
    if type(__DIO_3nn_GetTrackedQuestText) == "function" then
      __text = __DIO_3nn_GetTrackedQuestText() or ""
    end
    if __text == "" then return { IsActive = false } end
    local __req, __mob = __text:match("^Defeat%s+(%d+)%s+(.+)$")
    if not __req then __mob = __text:match("^Defeat%s+(.+)$") end
    return { IsActive = true, QuestText = __text, MobTarget = __mob or __text, Required = tonumber(__req), Done = false }
  end)
  return (__ok and __res) or { IsActive = false }
end
__DIO_ForestQuest50 = function()
  local __q = __DIO_GetCurrentQuest()
  if __q.IsActive and __q.QuestText ~= "" and string.find(__q.QuestText, "Defeat 50 Forest Pirates", 1, true) then
    return { IsActive = true, QuestText = __q.QuestText }
  end
  return { IsActive = false }
end
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Observation V2"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoKenVTWO = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.AutoKenVTWO then
      pcall(function()
      local Kv2Pos1 = CFrame.new(-12444.78515625, 332.40396118164, -7673.1806640625)
      local Kv2Pos3 = CFrame.new(-10920.125, 624.20275878906, -10266.995117188)
      local Kv2Pos4 = CFrame.new(-13277.568359375, 370.34185791016, -7821.1572265625)
      local Kv2Pos5 = CFrame.new(-13493.12890625, 318.89553833008, -8373.7919921875)
	  local __fq = __DIO_ForestQuest50()
	  if __fq.IsActive then
	    local v = GetConnectionEnemies("Forest Pirate")
        if v then
	      repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoKenVTWO) until not _G.AutoKenVTWO or v.Humanoid.Health <= 0 or __DIO_QuestGone()
	    else
	      _tp(Kv2Pos4)
	    end
	  elseif __DIO_GetCurrentQuest().IsActive then
	    local v = GetConnectionEnemies("Captain Elephant")
	    if v then
          repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoKenVTWO) until not _G.AutoKenVTWO or v.Humanoid.Health <= 0 or __DIO_QuestGone()
	    else
	      _tp(Kv2Pos5)
	    end
	  elseif not __DIO_GetCurrentQuest().IsActive then
	    replicated.Remotes.CommF_:InvokeServer("CitizenQuestProgress","Citizen") __DIO_wait(.1)
	    replicated.Remotes.CommF_:InvokeServer("StartQuest","CitizenQuest",1)
	  end
	  if replicated.Remotes.CommF_:InvokeServer("CitizenQuestProgress","Citizen") == 2 then
	    _tp(CFrame.new(-12513.51953125, 340.1137390136719, -9873.048828125))
	  end
	  if not plr.Backpack:FindFirstChild("Fruit Bowl") or not plr.Character:FindFirstChild("Fruit Bowl") then
	  if not GetBP("Fruit Bowl") then
	    if not GetBP("Apple") then
	      replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-12471.169921875, 374.94024658203, -7551.677734375))
	      for i,v in pairs(workspace:GetDescendants()) do
	        if v.Name == "Apple" then
	          v.Handle.CFrame = plr.Character.HumanoidRootPart.CFrame * CFrame.new(0,1,10) __DIO_wait()
		      firetouchinterest(plr.Character.HumanoidRootPart,v.Handle,0) __DIO_wait()
	        end
	      end
	    elseif not GetBP("Banana") then
	      _tp(CFrame.new(2286.0078125,73.13391876220703,-7159.80908203125))
	      for i,v in pairs(workspace:GetDescendants()) do
	        if v.Name == "Banana" then
	          v.Handle.CFrame = plr.Character.HumanoidRootPart.CFrame * CFrame.new(0,1,10) __DIO_wait()
		      firetouchinterest(plr.Character.HumanoidRootPart,v.Handle,0) __DIO_wait()
	        end
	      end
	    elseif not GetBP("Pineapple") then
	      _tp(CFrame.new(-712.8272705078125,98.5770492553711,5711.9541015625))
	      for i,v in pairs(workspace:GetDescendants()) do
	        if v.Name == "Pineapple" then
	          v.Handle.CFrame = plr.Character.HumanoidRootPart.CFrame * CFrame.new(0,1,10) __DIO_wait()
		      firetouchinterest(plr.Character.HumanoidRootPart,v.Handle,0) __DIO_wait()
	        end
	      end
	    end
	  end
	    if plr.Backpack:FindFirstChild("Banana") and plr.Backpack:FindFirstChild("Apple") and plr.Backpack:FindFirstChild("Pineapple") or plr:FindFirstChild("Banana") and plr:FindFirstChild("Apple") and plr:FindFirstChild("Pineapple") then
	      repeat __DIO_wait(0.25) _tp(Kv2Pos1) until not _G.AutoKenVTWO or (plr.Character.HumanoidRootPart.Position - Kv2Pos1.Position).Magnitude <= 5
		  replicated.Remotes.CommF_:InvokeServer("CitizenQuestProgress","Citizen")
	    end
	      if plr.Backpack:FindFirstChild("Fruit Bowl") or plr.Character:FindFirstChild("Fruit Bowl") then
	        if (plr.Character.HumanoidRootPart.Position - Kv2Pos3.Position).Magnitude > 5 then _tp(Kv2Pos3)
		    elseif (plr.Character.HumanoidRootPart.Position - Kv2Pos3.Position).Magnitude <= 5 then
		      replicated.Remotes.CommF_:InvokeServer("KenTalk2","Start") __DIO_wait(.1)
		      replicated.Remotes.CommF_:InvokeServer("KenTalk2","Buy")
	        end
	      end
	    end
      end)
    end
  end
end, "L8465")
Bartilo = Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Done Bartilo Quest"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Bartilo_Quest = Value
  if not Value then
    __DIO_SetFlag("Level","Bartilo_Quest",false,true)
    __DIO_ReleaseAll("Bartilo_Quest")
    StopTween(false)
    __DIO_CurTarget = nil
    if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
  end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.Bartilo_Quest and plr.Data.Level.Value >= 850 then
        if replicated.Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 0 then
          __DIO_SetFlag("Level","Bartilo_Quest",true,true)
          if __DIO_3nn_GetTrackedQuestText() ~= "" then
            local v = GetConnectionEnemies("Swan Pirate")
            if v then
              local x = GetConnectionEnemies(BartMon)
              if x then
                repeat __DIO_wait(Sec)
                  if not string.find(__DIO_GetCurrentQuest().QuestText or "", "Swan Pirate", 1, true)then replicated.Remotes.CommF_:InvokeServer("AbandonQuest")
                  else Attack.Kill(x,_G.Bartilo_Quest)end
                until _G.Bartilo_Quest == false or not x.Parent or x.Humanoid.Health <= 0 or __DIO_3nn_GetTrackedQuestText() == "" or not x:FindFirstChild("HumanoidRootPart")
              end
            else
              _tp(CFrame.new(970.369446, 142.653198, 1217.3667, 0.162079468, -4.85452638e-08, -0.986777723, 1.03357589e-08, 1, -4.74980872e-08, 0.986777723, -2.50063148e-09, 0.162079468))
            end
          else
            repeat __DIO_wait(0.25)
              _tp(CFrame.new(-461.533203, 72.3478546, 300.311096, 0.050853312, -0, -0.998706102, 0, 1, -0, 0.998706102, 0, 0.050853312))
            until (CFrame.new(-461.533203, 72.3478546, 300.311096, 0.050853312, -0, -0.998706102, 0, 1, -0, 0.998706102, 0, 0.050853312).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 20 or _G.Bartilo_Quest == false
            if (CFrame.new(-461.533203, 72.3478546, 300.311096, 0.050853312, -0, -0.998706102, 0, 1, -0, 0.998706102, 0, 0.050853312).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 1 then
              replicated.Remotes.CommF_:InvokeServer("StartQuest", "BartiloQuest",1)
            end
          end
          elseif replicated.Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 1 then
            __DIO_SetFlag("Level","Bartilo_Quest",true,true)
            local je = GetConnectionEnemies("Jeremy")
            if je then
              repeat __DIO_wait(Sec) Attack.Kill(je,_G.Bartilo_Quest) until _G.Bartilo_Quest == false or not je.Parent or je.Humanoid.Health <= 0 or __DIO_3nn_GetTrackedQuestText() == "" or not je:FindFirstChild("HumanoidRootPart")
            else
              _tp(CFrame.new(2158.97412, 449.056244, 705.411682, -0.754199564, -4.17389057e-09, -0.656645238, -4.47752875e-08, 1, 4.50709301e-08, 0.656645238, 6.3393955e-08, -0.754199564))
            end
          elseif replicated.Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 2 then
          repeat __DIO_wait(0.25) _tp(CFrame.new(-1830.83972, 10.5578213, 1680.60229, 0.979988456, -2.02152783e-08, -0.199054286, 2.20792113e-08, 1, 7.1442483e-09, 0.199054286, -1.13962431e-08, 0.979988456))until (CFrame.new(-1830.83972, 10.5578213, 1680.60229, 0.979988456, -2.02152783e-08, -0.199054286, 2.20792113e-08, 1, 7.1442483e-09, 0.199054286, -1.13962431e-08, 0.979988456).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 1 or _G.Bartilo_Quest == false
          __DIO_wait(0.5)
          __DIO_TweenTarget = nil
          plr.Character.HumanoidRootPart.CFrame = workspace.Map.Dressrosa.BartiloPlates.Plate1.CFrame
          __DIO_wait(0.5)
          plr.Character.HumanoidRootPart.CFrame = workspace.Map.Dressrosa.BartiloPlates.Plate2.CFrame
          __DIO_wait(0.5)
          plr.Character.HumanoidRootPart.CFrame = workspace.Map.Dressrosa.BartiloPlates.Plate3.CFrame
          __DIO_wait(0.5)
          plr.Character.HumanoidRootPart.CFrame = workspace.Map.Dressrosa.BartiloPlates.Plate4.CFrame
          __DIO_wait(0.5)
          plr.Character.HumanoidRootPart.CFrame = workspace.Map.Dressrosa.BartiloPlates.Plate5.CFrame
          __DIO_wait(0.5)
          plr.Character.HumanoidRootPart.CFrame = workspace.Map.Dressrosa.BartiloPlates.Plate6.CFrame
          __DIO_wait(0.5)
          plr.Character.HumanoidRootPart.CFrame = workspace.Map.Dressrosa.BartiloPlates.Plate7.CFrame
          __DIO_wait(0.5)
          plr.Character.HumanoidRootPart.CFrame = workspace.Map.Dressrosa.BartiloPlates.Plate8.CFrame
          __DIO_wait(2.5)
        end
      end
    end)
  end
end, "L8548")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Done Citizen Quest"],
Description = "",
Default = false,
Callback = function(Value)
  _G.CitizenQuest = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.CitizenQuest then
        if plr.Data.Level.Value >= 1800 and replicated.Remotes.CommF_:InvokeServer("CitizenQuestProgress").KilledBandits == false then
          local __fqC = __DIO_ForestQuest50()
          if __fqC.IsActive then
            local v = GetConnectionEnemies("Forest Pirate")
            if v then
              repeat __DIO_wait(Sec) Attack.Kill(v,_G.CitizenQuest)until _G.CitizenQuest == false or not v.Parent or v.Humanoid.Health <= 0 or __DIO_QuestGone()
            else
              _tp(CFrame.new(-13206.452148438, 425.89199829102, -7964.5537109375))
            end
          else
            _tp(CFrame.new(-12443.8671875, 332.40396118164, -7675.4892578125))
            if (Vector3.new(-12443.8671875, 332.40396118164, -7675.4892578125) - plr.Character.HumanoidRootPart.Position).Magnitude <= 30 then
              __DIO_wait(1.5) replicated.Remotes.CommF_:InvokeServer("StartQuest","CitizenQuest",1)
            end
          end
        elseif plr.Data.Level.Value >= 1800 and replicated.Remotes.CommF_:InvokeServer("CitizenQuestProgress").KilledBoss == false then
          local v = GetConnectionEnemies("Captain Elephant")
          local __qCE = __DIO_GetCurrentQuest()
          if __qCE.IsActive and string.find(__qCE.QuestText, "Captain Elephant", 1, true) then
            if v then
              repeat __DIO_wait(Sec) Attack.Kill(v,_G.CitizenQuest) until _G.CitizenQuest == false or v.Humanoid.Health <= 0 or not v.Parent or __DIO_QuestGone()
            else
              _tp(CFrame.new(-13374.889648438, 421.27752685547, -8225.208984375))
            end
          else
            _tp(CFrame.new(-12443.8671875, 332.40396118164, -7675.4892578125))
            if (CFrame.new(-12443.8671875, 332.40396118164, -7675.4892578125).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 4 then
              __DIO_wait(1.5)
              replicated.Remotes.CommF_:InvokeServer("CitizenQuestProgress","Citizen")
            end
          end
        elseif plr.Data.Level.Value >= 1800 and replicated.Remotes.CommF_:InvokeServer("CitizenQuestProgress","Citizen") == 2 then
          _tp(CFrame.new(-12512.138671875, 340.39279174805, -9872.8203125))
        end
      end
    end)
  end
end, "L8616")
Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Training Dummy"],
Description = "",
Default = false,
Callback = function(Value)
  _G.DummyMan = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.DummyMan then
      pcall(function()
        if __DIO_QuestGone() then
          local xxx = {[1] = "ArenaTrainer"}
	      replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer(unpack(xxx))
        else
          local v = GetConnectionEnemies("Training Dummy")
          if v then
		    repeat __DIO_wait(0.25) Attack.Kill(v,_G.DummyMan) until not _G.DummyMan or not v.Parent or v.Humanoid.Health <= 0
	      else
	        _tp(CFrame.new(3688.005126953125, 12.746943473815918, 170.20953369140625))
	      end
	    end
      end)
    end
  end
end, "L8665")
__DIO_FlagBorrow = __DIO_FlagBorrow or {}
__DIO_BuyMeleeToggles = {}
Tabs.Shop:AddSection("Fragments shop")
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Refund Stats"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BlackbeardReward","Refund","2")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Reroll Race"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BlackbeardReward","Reroll","2")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Ghoul Race"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("Ectoplasm"," Change", 4)
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Cyborg Race (2.5k)"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("CyborgTrainer"," Buy")
end})
Tabs.Shop:AddSection("Fighting Melee Styles")
__DIO_BuyMeleeToggles.BuyBlackLeg = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  BlackLeg"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuyBlackLeg + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuyBlackLeg", Value)
end})
__DIO_BuyMeleeToggles.BuyElectro = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  Electro"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuyElectro + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuyElectro", Value)
end})
__DIO_BuyMeleeToggles.BuyFishmanKarate = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  FishmanKarate"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuyFishmanKarate + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuyFishmanKarate", Value)
end})
__DIO_BuyMeleeToggles.BuyDragonClaw = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  DragonClaw"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuyDragonClaw + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuyDragonClaw", Value)
end})
__DIO_BuyMeleeToggles.BuySuperhuman = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  Superhuman"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuySuperhuman + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuySuperhuman", Value)
end})
__DIO_BuyMeleeToggles.BuyDeathStep = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  DeathStep"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuyDeathStep + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuyDeathStep", Value)
end})
__DIO_BuyMeleeToggles.BuySharkmanKarate = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  SharkmanKarate"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuySharkmanKarate + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuySharkmanKarate", Value)
end})
__DIO_BuyMeleeToggles.BuyElectricClaw = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  ElectricClaw"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuyElectricClaw + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuyElectricClaw", Value)
end})
__DIO_BuyMeleeToggles.BuyDragonTalon = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  DragonTalon"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuyDragonTalon + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuyDragonTalon", Value)
end})
__DIO_BuyMeleeToggles.BuyGodhuman = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  Godhuman"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuyGodhuman + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuyGodhuman", Value)
end})
__DIO_BuyMeleeToggles.BuySanguineArt = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  SanguineArt"],
Description = "",
Default = false,
Callback = function(Value)
  -- FIX: du 3 lop _G.BuyMelee_BuySanguineArt + shouldTween = true + highlight; tat -> huy tween/highlight
  __DIO_FeatToggle("BuyMelee_BuySanguineArt", Value)
end})
Tabs.Shop:AddToggle({
Name = __DIO_T["Auto Superhuman"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_SuperHuman = Value
  if not Value then __DIO_ReleaseAll("Auto_SuperHuman") end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.Auto_SuperHuman then
      pcall(function()
        local __on = function() return not _G.Auto_SuperHuman end
        if not plr:FindFirstChild("WeaponAssetCache") and tick() - __DIO_BootT0 < 15 then return end
        if GetBP("Superhuman") then return end
        local M_Beli = (plr.Data and plr.Data.Beli and plr.Data.Beli.Value) or 0
        local M_Frag = (plr.Data and plr.Data.Fragments and plr.Data.Fragments.Value) or 0
        if not GetBP("Black Leg") then
          if M_Beli >= 150000 and __DIO_MeleeBuyGo("BuyBlackLeg", __on) then replicated.Remotes.CommF_:InvokeServer("BuyBlackLeg") end
          return
        elseif GetBP("Black Leg").Level.Value < 300 then __DIO_BorrowFlag("Auto_SuperHuman","Level") return
        else __DIO_ReleaseFlag("Auto_SuperHuman","Level") end
        if not GetBP("Electro") then
          if M_Beli >= 500000 and __DIO_MeleeBuyGo("BuyElectro", __on) then replicated.Remotes.CommF_:InvokeServer("BuyElectro") end
          return
        elseif GetBP("Electro").Level.Value < 300 then __DIO_BorrowFlag("Auto_SuperHuman","Level") return
        else __DIO_ReleaseFlag("Auto_SuperHuman","Level") end
        if not GetBP("Fishman Karate") then
          if M_Beli >= 750000 and __DIO_MeleeBuyGo("BuyFishmanKarate", __on) then replicated.Remotes.CommF_:InvokeServer("BuyFishmanKarate") end
          return
        elseif GetBP("Fishman Karate").Level.Value < 300 then __DIO_BorrowFlag("Auto_SuperHuman","Level") return
        else __DIO_ReleaseFlag("Auto_SuperHuman","Level") end
        if not GetBP("Dragon Claw") then
          if M_Frag >= 1500 and __DIO_MeleeBuyGo("BlackbeardReward", __on) then replicated.Remotes.CommF_:InvokeServer("BlackbeardReward","DragonClaw","2") end
          return
        elseif GetBP("Dragon Claw").Level.Value < 300 then __DIO_BorrowFlag("Auto_SuperHuman","Level") return
        else __DIO_ReleaseFlag("Auto_SuperHuman","Level") end
        if __DIO_MeleeBuyGo("BuySuperhuman", __on) then replicated.Remotes.CommF_:InvokeServer("BuySuperhuman") end
      end)
    end
  end
end, "L8787")
Tabs.Shop:AddToggle({
Name = __DIO_T["Auto DeathStep"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoDeathStep = Value
  if not Value then __DIO_ReleaseAll("AutoDeathStep") end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.AutoDeathStep then
      pcall(function()
        local __on = function() return not _G.AutoDeathStep end
        if not plr:FindFirstChild("WeaponAssetCache") and tick() - __DIO_BootT0 < 15 then return end
        if GetBP("Death Step") then return end
        if not GetBP("Black Leg") then
          if __DIO_MeleeBuyGo("BuyBlackLeg", __on) then replicated.Remotes.CommF_:InvokeServer("BuyBlackLeg") end
          return
        end
        if GetBP("Black Leg").Level.Value >= 400 then
          if GetBP("Library Key") then
            if __DIO_MeleeBuyGo("BuyDeathStep", __on) then replicated.Remotes.CommF_:InvokeServer("BuyDeathStep") end
          else
            local v = GetConnectionEnemies("Awakened Ice Admiral")
            if v then
              repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoDeathStep) until not v.Parent or v.Humanoid.Health <= 0 or _G.AutoDeathStep == false or GetBP("Library Key") or GetBP("Death Step")
            else
              __DIO_FlyTo(CFrame.new(5668.9780273438, 28.519989013672, -6483.3520507813), 10, __on)
            end
          end
          __DIO_ReleaseFlag("AutoDeathStep","Level")
          return
        else
          __DIO_BorrowFlag("AutoDeathStep","Level")
          return
        end
      end)
    end
  end
end, "L8830")
Tabs.Shop:AddToggle({
Name = __DIO_T["Auto Sharkman Karate"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_SharkMan_Karate = Value
  if not Value then __DIO_ReleaseAll("Auto_SharkMan_Karate") end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.Auto_SharkMan_Karate then
      pcall(function()
        local __on = function() return not _G.Auto_SharkMan_Karate end
        if not plr:FindFirstChild("WeaponAssetCache") and tick() - __DIO_BootT0 < 15 then return end
        if GetBP("Sharkman Karate") then return end
        if not GetBP("Fishman Karate") then
          if __DIO_MeleeBuyGo("BuyFishmanKarate", __on) then replicated.Remotes.CommF_:InvokeServer("BuyFishmanKarate") end
          return
        end
        if GetBP("Fishman Karate").Level.Value < 400 then
          __DIO_BorrowFlag("Auto_SharkMan_Karate","Level")
          return
        end
        __DIO_ReleaseFlag("Auto_SharkMan_Karate","Level")
        if GetBP("Water Key") then
          if __DIO_MeleeBuyGo("BuySharkmanKarate", __on) then
            replicated.Remotes.CommF_:InvokeServer("BuySharkmanKarate")
          end
        else
          local v = GetConnectionEnemies("Tide Keeper")
          if v then
            repeat __DIO_wait(0.25) Attack.Kill(v,_G.Auto_SharkMan_Karate) until not v.Parent or v.Humanoid.Health <= 0 or _G.Auto_SharkMan_Karate == false or GetBP("Water Key") or GetBP("Sharkman Karate")
          else
            __DIO_FlyTo(CFrame.new(-3053.9814453125, 237.18954467773, -10145.0390625), 10, __on)
          end
        end
      end)
    end
  end
end, "L8872")
Tabs.Shop:AddToggle({
Name = __DIO_T["Auto ElectricClaw"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Electric_Claw = Value
  if not Value then __DIO_ReleaseAll("Auto_Electric_Claw") end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.Auto_Electric_Claw then
      pcall(function()
        local __on = function() return not _G.Auto_Electric_Claw end
        if not plr:FindFirstChild("WeaponAssetCache") and tick() - __DIO_BootT0 < 15 then return end
        if GetBP("Electric Claw") then return end
        if not GetBP("Electro") then
          if __DIO_MeleeBuyGo("BuyElectro", __on) then replicated.Remotes.CommF_:InvokeServer("BuyElectro") end
          return
        end
        if GetBP("Electro").Level.Value >= 400 then
          if replicated.Remotes.CommF_:InvokeServer("BuyElectricClaw", "Start") == nil then __DIO_FlyTo(CFrame.new(-12548, 337, -7481), 10, __on) end
          if __DIO_MeleeBuyGo("BuyElectricClaw", __on) then replicated.Remotes.CommF_:InvokeServer("BuyElectricClaw") end
        else
          __DIO_BorrowFlag("Auto_Electric_Claw","AutoFarm_Bone")
          repeat __DIO_wait(0.25) until not _G.Auto_Electric_Claw or GetBP("Electric Claw") or not plr.Character
          __DIO_ReleaseFlag("Auto_Electric_Claw","AutoFarm_Bone")
        end
      end)
    end
  end
end, "L8913")
Tabs.Shop:AddToggle({
Name = __DIO_T["Auto DragonTalon"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoDragonTalon = Value
  if not Value then __DIO_ReleaseAll("AutoDragonTalon") end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.AutoDragonTalon then
      pcall(function()
        local __on = function() return not _G.AutoDragonTalon end
        if not plr:FindFirstChild("WeaponAssetCache") and tick() - __DIO_BootT0 < 15 then return end
        if GetBP("Dragon Talon") then return end
        if not GetBP("Dragon Claw") then
          if __DIO_MeleeBuyGo("BlackbeardReward", __on) then replicated.Remotes.CommF_:InvokeServer("BlackbeardReward","DragonClaw","2") end
          return
        end
        if GetBP("Dragon Claw").Level.Value >= 400 then
          if __DIO_MeleeBuyGo("BuyDragonTalon", __on) then replicated.Remotes.CommF_:InvokeServer("Bones","Buy",1,1) replicated.Remotes.CommF_:InvokeServer("BuyDragonTalon") end
        else
          __DIO_BorrowFlag("AutoDragonTalon","AutoFarm_Bone")
          repeat __DIO_wait(0.25) until not _G.AutoDragonTalon or GetBP("Dragon Talon") or not plr.Character
          __DIO_ReleaseFlag("AutoDragonTalon","AutoFarm_Bone")
        end
      end)
    end
  end
end, "L8945")
Tabs.Shop:AddToggle({
Name = __DIO_T["Auto Godhuman"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_God_Human = Value
  if not Value then __DIO_ReleaseAll("Auto_God_Human") end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.Auto_God_Human then
        local __on = function() return not _G.Auto_God_Human end
        local __need = replicated.Remotes.CommF_:InvokeServer("BuyGodhuman",true)
        if __need == "Bring me 20 Fish Tails, 20 Magma Ore, 10 Dragon Scales and 10 Mystic Droplets." then
          if GetM("Dragon Scale") == false or GetM("Dragon Scale") < 10 then
            if World3 then
              __DIO_BorrowFlag("Auto_God_Human","Level")
            else
              replicated.Remotes.CommF_:InvokeServer("TravelZou")
            end
          elseif GetM("Fish Tail") == false or GetM("Fish Tail") < 20 then
            if World3 then
              __DIO_BorrowFlag("Auto_God_Human","Level")
            else
              replicated.Remotes.CommF_:InvokeServer("TravelZou")
            end
          elseif GetM("Mystic Droplet") == false or GetM("Mystic Droplet") < 10 then
            if World2 then
              __DIO_BorrowFlag("Auto_God_Human","Level")
            else
              replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
            end
          elseif GetM("Magma Ore") == false or GetM("Magma Ore") < 20 then
            if World2 then
              __DIO_BorrowFlag("Auto_God_Human","Level")
            else
              replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
            end
          end
        elseif __need == 3 then
          return nil
        else
          if __DIO_MeleeBuyGo("BuyGodhuman", __on) then replicated.Remotes.CommF_:InvokeServer("BuyGodhuman") end
        end
      end
    end)
  end
end, "L8975")
Tabs.Shop:AddToggle({
Name = __DIO_T["Auto SanguineArt"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Snaguine = Value
  if not Value then __DIO_ReleaseAll("Snaguine") end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.Snaguine then
      pcall(function()
        if not GetBP("Sanguine Art") then replicated.Remotes.CommF_:InvokeServer("Sanguine Art") end
        if not GetBP("Sanguine Art") then
          if GetM("Leviathan Heart") >= 1 then print("Completed!!")
          else
            __DIO_BorrowValue("Snaguine","DangerSc","Lv Infinite")
            if World3 then __DIO_BorrowFlag("Snaguine","SailBoats") else __DIO_ReleaseFlag("Snaguine","SailBoats") end
          end
          if GetM("Vampire Fang") <= 19 then
            if World2 then
              local n = GetConnectionEnemies("Vampire")
              if n then repeat __DIO_wait(Sec) Attack.Kill(n,_G.Snaguine) until not _G.Snaguine or n.Humanoid.Health <= 0 or not n.Parent
              else _tp(CFrame.new(-6041.29248046875, 6.402710914611816, -1304.63330078125))
              end
            else
              replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
            end
          end
          if GetM("Vampire Fang") >= 20 and GetM("Demonic Wisp") <= 19 then
            if World3 then
              local n = GetConnectionEnemies("Demonic Soul")
              if n then repeat __DIO_wait(Sec) Attack.Kill(n,_G.Snaguine) until not _G.Snaguine or n.Humanoid.Health <= 0 or not n.Parent
              else _tp(CFrame.new(-9495.6806640625, 453.58624267578125, 5977.3486328125))
              end
             else
               replicated.Remotes.CommF_:InvokeServer("TravelZou")
             end
           end
           if GetM("Vampire Fang") >= 20 and GetM("Demonic Wisp") >= 20 and GetM("Dark Fragment") <= 1 then
             if World2 then
               local n = GetConnectionEnemies("Darkbeard")
               if n then repeat __DIO_wait(Sec) Attack.Kill(n,_G.Snaguine) until not _G.Snaguine or n.Humanoid.Health <= 0 or not n.Parent
              else _tp(CFrame.new(3798.4575195313, 13.826690673828, -3399.806640625))
              end
            else replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
            end
          end
        else if __DIO_MeleeBuyGo("BuySanguineArt", function() return not _G.Snaguine end) then replicated.Remotes.CommF_:InvokeServer("BuySanguineArt") end
        end
      end)
    end
  end
end, "L9029")

__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            local moon8 = "http://www.roblox.com/asset/?id=9709150401"
            local moon7 = "http://www.roblox.com/asset/?id=9709150086"
            local moon6 = "http://www.roblox.com/asset/?id=9709149680"
            local moon5 = "http://www.roblox.com/asset/?id=9709149431"
            local moon4 = "http://www.roblox.com/asset/?id=9709149052"
            local moon3 = "http://www.roblox.com/asset/?id=9709143733"
            local moon2 = "http://www.roblox.com/asset/?id=9709139597"
            local moon1 = "http://www.roblox.com/asset/?id=9709135895"
            local moon = Getmoon()
            if moon == moon1 then
                FullMOOn:SetDesc("Moon : 0 / 8")
            elseif moon == moon2 then
                FullMOOn:SetDesc("Moon : 1 / 8")
            elseif moon == moon3 then
                FullMOOn:SetDesc("Moon : 2 / 8")
            elseif moon == moon4 then
                FullMOOn:SetDesc("Moon : 3 / 8 [ Next Night ]")
            elseif moon == moon5 then
                FullMOOn:SetDesc("Moon : 4 / 8 [ Full Moon ]")
            elseif moon == moon6 then
                FullMOOn:SetDesc("Moon : 5 / 8 [ Last Night ]")
            elseif moon == moon7 then
                FullMOOn:SetDesc("Moon : 6 / 8")
            elseif moon == moon8 then
                FullMOOn:SetDesc("Moon : 7 / 8")
            end
        end)
    end
end, "L9079")
-- [DIO-FIX] Da xoa stub trung lap __DIO_FindCruiseY o day: he thong Y thuyen day du
-- duoc dinh nghia SOM ngay sau __DIO_BoatAssist (truoc moi vong Find), khong can stub.
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.FindMirage then
      pcall(function()
        local __wo = workspace:FindFirstChild("_WorldOrigin")
        local __loc = __wo and __wo:FindFirstChild("Locations")
        local __found = __loc and __loc:FindFirstChild("Mirage Island", true)
        -- FIX: Mirage Island that ton tai that nam o workspace.Map.MysticIsland (giong code ESP/chest Mirage).
        -- Truoc day chi check Locations -> Mirage da xuat hien ma thuyen van fly ra bien quet mai.
        local __mapM = workspace:FindFirstChild("Map")
        local __mi = __mapM and __mapM:FindFirstChild("MysticIsland")
        if not __found and __mi then __found = __mi end
        if not __found then
          if __DIO_BoatAssist() ~= "sitting" then return end
          local __dest = CFrame.new(-10000000, 31, 37016.25)
          repeat __DIO_wait(0.25)
            local __chR = plr.Character
            local __humR = __chR and __chR:FindFirstChildOfClass("Humanoid")
            local __hrpR = __chR and __chR:FindFirstChild("HumanoidRootPart")
            if not __humR or not __hrpR or not __humR.Sit then break end
            if not _G.FindMirage then break end
            __DIO_NoClipShipNow()
            -- [DIO-FIX] Mot nguon Y duy nhat cho ca 4 Find (Fly Boat / Sea Event Y)
            local __wantYR = __DIO_CruiseFeed("mirage")
            __dest = __DIO_FindCruiseDest(__wantYR)
            __DIO_CruiseGo("mirage", __dest)
            __found = __loc and __loc:FindFirstChild("Mirage Island", true)
            if not __found and __mapM and __mapM:FindFirstChild("MysticIsland") then
              __found = __mapM:FindFirstChild("MysticIsland")
              __mi = __found
            end
          until not _G.FindMirage or __found or (__dest.Position - __hrpR.Position).Magnitude <= 10 or not __humR.Sit
          if __found or not _G.FindMirage then __DIO_CruiseStop("mirage") end
          -- [DIO-FIX] Chi roi ghe khi DA thay dao. Thoat vong vi ly do khac (tat toggle,
          -- ghe nhay Sit tam thoi...) thi GIU ngoi de vong ngoai tiep tuc cruise on dinh.
          if __found then
            pcall(function()
              local __chE = plr.Character
              local __humE = __chE and __chE:FindFirstChildOfClass("Humanoid")
              if __humE then __humE.Sit = false end
            end)
          end
        else
          -- FIX: lay CFrame dung cho ca BasePart (Locations) lan Model (MysticIsland)
          local __srcM = __mi or __found
          local __cfM = nil
          pcall(function()
            local __ctr = __srcM:FindFirstChild("Center")
            if __ctr and __ctr:IsA("BasePart") then __cfM = __ctr.CFrame return end
            if type(__srcM.GetPivot) == "function" then __cfM = __srcM:GetPivot() return end
            __cfM = __srcM.CFrame
          end)
          if not __cfM then return end
          __DIO_CruiseStop("mirage")
          -- Da thay Mirage: tat cruise Y slider, ve Y 31 (mat nuoc) nhu cu
          local __goalM = CFrame.new(__cfM.Position.X, 31, __cfM.Position.Z)
          -- FIX: da dung tren Mirage roi -> khong _tp lap lai moi giay (giu shouldTween/highlight nong mai)
          local __chM = plr.Character
          local __hrpM = __chM and __chM:FindFirstChild("HumanoidRootPart")
          if not __hrpM or (__goalM.Position - __hrpM.Position).Magnitude > 250 then
            _tp(__goalM)
          end
        end
      end)
    end
  end
end, "L9119")

UpdateIslandMirageESP = function()
    if MirageIslandESP then
        local island = workspace.Map:FindFirstChild("MysticIsland")
        if island then
            local center = island:FindFirstChild("Center") or island:FindFirstChildWhichIsA("BasePart")
            if center then
                local dist = 0
                pcall(function() dist = math.floor((center.Position - plr.Character.HumanoidRootPart.Position).Magnitude) end)
                local esp = workspace:FindFirstChild("__DIO_MirageEsp")
                if not esp then
                    esp = Instance.new("BillboardGui")
                    esp.Name = "__DIO_MirageEsp"
                    esp.Adornee = center
                    esp.Size = UDim2.new(0, 220, 0, 40)
                    esp.StudsOffset = Vector3.new(0, 30, 0)
                    esp.AlwaysOnTop = true
                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.TextColor3 = Color3.fromRGB(0, 255, 255)
                    lbl.TextStrokeTransparency = 0.3
                    lbl.TextSize = 18
                    lbl.Font = Enum.Font.Code
                    lbl.Parent = esp
                    esp.Parent = workspace
                end
                esp.TextLabel.Text = "Mirage Island [" .. dist .. "m]"
            end
        end
    else
        local old = workspace:FindFirstChild("__DIO_MirageEsp")
        if old then old:Destroy() end
    end
end

__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            if _G.AutoMysticIsland then
                for _, location in pairs(__SVC_WS._WorldOrigin.Locations:GetChildren()) do
                    if location.Name == "Mirage Island" then
                        topos(location.CFrame * CFrame.new(0, 333, 0))
                    end
                end
            end
        end)
    end
end, "L9242")

__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.HighestMirage then
      pcall(function()
      if workspace["_WorldOrigin"].Locations:FindFirstChild("Mirage Island",true) then _tp(workspace.Map.MysticIsland.Center.CFrame*CFrame.new(0,400,0))end
      end)
    end
  end
end, "L9262")

__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.TPGEAR then
        local __mi = workspace.Map:FindFirstChild('MysticIsland')
        if __mi then
          for i,v in pairs(__mi:GetChildren()) do
            if v.Name == "Part" then
              if v.ClassName == "MeshPart" then _tp(v.CFrame) end
            end
          end
        end
      end
    end)
  end
end, "L9278")

__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.can then
        local __mi = workspace.Map:FindFirstChild('MysticIsland')
        if __mi then
          for i,v in pairs(__mi:GetChildren()) do
            if v.Name == "Part" then
              if v.ClassName == "MeshPart" then
                v.Transparency = 0
              else
                v.Transparency = 1
              end
            end
          end
        end
      end
    end)
  end
end, "L9302")

__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.Addealer then
	  pcall(function()
	    for _,v in pairs(replicated.NPCs:GetChildren()) do
	    if v.Name == "Advanced Fruit Dealer" then _tp(v.HumanoidRootPart.CFrame) end
        end
	 end)
    end
  end
end, "L9330")

__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.FarmChestM then
      pcall(function()
        if workspace.Map.MysticIsland.Chests:FindFirstChild("DiamondChest") or workspace.Map.MysticIsland.Chests:FindFirstChild("FragChest") then
          local CollectionService = __SVC_CS
          local Players = __SVC_PLR
          local Player = Players.LocalPlayer
          local Character = Player.Character or Player.CharacterAdded:Wait()
          if not Character then return end
          local Position = Character:GetPivot().Position
          local Chests = CollectionService:GetTagged("_ChestTagged")
          local Distance, Nearest = math.huge, nil
          for i = 1, #Chests do
            local Chest = Chests[i]
            local Magnitude = (Chest:GetPivot().Position - Position).Magnitude
            local __selIsland = __DIO_GetSelectedIslandModel()
            if not __selIsland or Chest:IsDescendantOf(__selIsland) then
              if not Chest:GetAttribute("IsDisabled") and Magnitude < Distance then
                Distance = Magnitude
                Nearest = Chest
              end
            end
          end
        if Nearest then _tp(Nearest:GetPivot()) end
        end
      end)
    end
  end
end, "L9348")

__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if LookM then
      pcall(MoveCamtoMoon)
      __DIO_wait(.1)
      replicated.Remotes.CommE:FireServer("ActivateAbility")
    end
  end
end, "L9398")

function MoveCamtoMoon()
    local moonDir = Lighting:GetMoonDirection()
    workspace.CurrentCamera.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position, workspace.CurrentCamera.CFrame.Position + moonDir)
    local __chMM = plr.Character
    local __hrpMM = __chMM and __chMM:FindFirstChild("HumanoidRootPart")
    if __hrpMM then
        __hrpMM.CFrame = CFrame.new(__hrpMM.Position, __hrpMM.Position + moonDir)
    end
end
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if LookMV3 then
            pcall(MoveCamtoMoon)
            replicated.Remotes.CommE:FireServer("ActivateAbility")
            pcall(function()
                local __vim = __SVC_VIM or game:GetService("VirtualInputManager")
                local __uisSvc = game:GetService("UserInputService")
                __vim:SendKeyEvent(true, "T", false, __uisSvc)
            end)
            __DIO_wait(0.5)
            pcall(function()
                local __vim = __SVC_VIM or game:GetService("VirtualInputManager")
                local __uisSvc = game:GetService("UserInputService")
                __vim:SendKeyEvent(false, "T", false, __uisSvc)
            end)
        end
    end
end, "L9423")
Tabs.Race:AddSection("Upgrade Races V2 And V3")
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Upgrade Mink"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Mink = Value
  if not Value then __DIO_ReleaseAll("Auto_Mink") StopTween(false) end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.Auto_Mink then
        if replicated.Remotes.CommF_:InvokeServer("Alchemist","1") ~= 2 then
          if replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 0 then
            replicated.Remotes.CommF_:InvokeServer("Alchemist","2")
          elseif replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 1 then
            if not plr.Backpack:FindFirstChild("Flower 1") and not plr.Character:FindFirstChild("Flower 1") then
              _tp(workspace.Flower1.CFrame)
            elseif not plr.Backpack:FindFirstChild("Flower 2") and not plr.Character:FindFirstChild("Flower 2") then
              _tp(workspace.Flower2.CFrame)
            elseif not plr.Backpack:FindFirstChild("Flower 3") and not plr.Character:FindFirstChild("Flower 3") then
              local v = GetConnectionEnemies("Swan Pirate")
              if v then repeat __DIO_wait(0.25) Attack.Kill(v,_G.Auto_Mink) until GetBP("Flower 3") or not v.Parent or v.Humanoid.Health <= 0 or _G.Auto_Mink == false
              else _tp(CFrame.new(980.0985107421875, 121.331298828125, 1287.2093505859375))end
            end
          elseif replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 2 then
	        replicated.Remotes.CommF_:InvokeServer("Alchemist","3")
	      end
        elseif replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","1") == 0 then
          replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","2")
        elseif replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","1") == 1 then
		  __DIO_BorrowFlag("Auto_Mink","AutoFarmChest")
	    else
	      __DIO_ReleaseFlag("Auto_Mink","AutoFarmChest")
        end
      end
    end)
  end
end, "L9443")
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Upgrade Human"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Human = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Auto_Human then
        if replicated.Remotes.CommF_:InvokeServer("Alchemist","1") ~= -2 then
	     if replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 0 then
		  replicated.Remotes.CommF_:InvokeServer("Alchemist","2")
		elseif replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 1 then
		  if not plr.Backpack:FindFirstChild("Flower 1") and not plr.Character:FindFirstChild("Flower 1") then
		    _tp(workspace.Flower1.CFrame)
		  elseif not plr.Backpack:FindFirstChild("Flower 2") and not plr.Character:FindFirstChild("Flower 2") then
		    _tp(workspace.Flower2.CFrame)
		  elseif not plr.Backpack:FindFirstChild("Flower 3") and not plr.Character:FindFirstChild("Flower 3") then
		    local v = GetConnectionEnemies("Swan Pirate")
            if v then repeat __DIO_wait(0.25) Attack.Kill(v,_G.Auto_Human) until plr.Backpack:FindFirstChild("Flower 3") or not v.Parent or v.Humanoid.Health <= 0 or _G.Auto_Human == false
		    else _tp(CFrame.new(980.0985107421875, 121.331298828125, 1287.2093505859375))end
		  end
		  elseif replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 2 then
		    replicated.Remotes.CommF_:InvokeServer("Alchemist","3")
		  end
		  elseif replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","1") == 0 then
		    replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","2")
		  elseif replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","1") == 1 then
		  local v = GetConnectionEnemies(Human_v3_Mob[1])
          if v then repeat __DIO_wait(0.25)Attack.Kill(v,_G.Auto_Human)until v.Humanoid.Health <= 0 or not v.Parent or not _G.Auto_Human
	      else _tp(CFrame.new(-2172.7399902344, 103.32216644287, -4015.025390625))
		  end
		  local v = GetConnectionEnemies(Human_v3_Mob[2])
          if v then repeat __DIO_wait(0.25)Attack.Kill(v,_G.Auto_Human)until v.Humanoid.Health <= 0 or not v.Parent or not _G.Auto_Human
	      else _tp(CFrame.new(2006.9261474609, 448.95666503906, 853.98284912109))
		  end
		  local v = GetConnectionEnemies(Human_v3_Mob[3])
          if v then repeat __DIO_wait(0.25)Attack.Kill(v,_G.Auto_Human)until v.Humanoid.Health <= 0 or not v.Parent or not _G.Auto_Human
          else _tp(CFrame.new(-1576.7166748047, 198.59265136719, 13.724286079407))
	      end
        end
      end
    end)
  end
end, "L9481")
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Upgrade Angel"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Skypiea = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Auto_Skypiea then
        if replicated.Remotes.CommF_:InvokeServer("Alchemist","1") ~= -2 then
	      if replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 0 then
		    replicated.Remotes.CommF_:InvokeServer("Alchemist","2")
		  elseif replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 1 then
		    if not plr.Backpack:FindFirstChild("Flower 1") and not plr.Character:FindFirstChild("Flower 1") then
		      _tp(workspace.Flower1.CFrame)
		    elseif not plr.Backpack:FindFirstChild("Flower 2") and not plr.Character:FindFirstChild("Flower 2") then
		      _tp(workspace.Flower2.CFrame)
		    elseif not plr.Backpack:FindFirstChild("Flower 3") and not plr.Character:FindFirstChild("Flower 3") then
		      local v = GetConnectionEnemies("Swan Pirate")
		      if v then
			    repeat __DIO_wait(0.25)Attack.Kill(v,_G.Auto_Skypiea)until plr.Backpack:FindFirstChild("Flower 3") or not v.Parent or v.Humanoid.Health <= 0 or _G.Auto_Skypiea == false
		      else
		        _tp(CFrame.new(980.0985107421875, 121.331298828125, 1287.2093505859375))
		      end
		    end
	      elseif replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 2 then
            replicated.Remotes.CommF_:InvokeServer("Alchemist","3")
          end
		  elseif replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","1") == 0 then
	        replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","2")
	    elseif replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","1") == 1 then
	      for i,v in pairs(game.Players:GetChildren()) do
            if v.Name ~= plr.Name and tostring(v.Data.Race.Value) == "Skypiea" then
		      repeat __DIO_wait(0.25) _tp(v.HumanoidRootPart.CFrame * CFrame.new(0,8,0) * CFrame.Angles(math.rad(-45),0,0))until v.Humanoid.Health <= 0 or _G.Auto_Skypiea == false
	        end
	      end
        end
      end
    end)
  end
end, "L9528")
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Upgrade FishMan"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Fish = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Auto_Fish then
        if replicated.Remotes.CommF_:InvokeServer("Alchemist","1") ~= -2 then
	      if replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 0 then
		    replicated.Remotes.CommF_:InvokeServer("Alchemist","2")
		  elseif replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 1 then
	        if not plr.Backpack:FindFirstChild("Flower 1") and not plr.Character:FindFirstChild("Flower 1") then
		      _tp(workspace.Flower1.CFrame)
	        elseif not plr.Backpack:FindFirstChild("Flower 2") and not plr.Character:FindFirstChild("Flower 2") then
	          _tp(workspace.Flower2.CFrame)
	        elseif not plr.Backpack:FindFirstChild("Flower 3") and not plr.Character:FindFirstChild("Flower 3") then
	          local v = GetConnectionEnemies("Swan Pirate")
		      if v then
			    repeat __DIO_wait(0.25)Attack.Kill(v,_G.Auto_Fish)until plr.Backpack:FindFirstChild("Flower 3") or not v.Parent or v.Humanoid.Health <= 0 or _G.Auto_Fish == false
	          else
		       _tp(CFrame.new(980.0985107421875, 121.331298828125, 1287.2093505859375))
	          end
            end
	      elseif replicated.Remotes.CommF_:InvokeServer("Alchemist","1") == 2 then
            replicated.Remotes.CommF_:InvokeServer("Alchemist","3")
          end
        elseif replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","1") == 0 then
	      replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","2")
	    elseif replicated.Remotes.CommF_:InvokeServer("Wenlocktoad","1") == 1 then
          warn("Sea Beast Soon")
        end
      end
    end)
  end
end, "L9571")
Tabs.Race:AddSection("Trials Quest V4")
local CheckTier = Tabs.Race:AddParagraph("Tiers V4 Status", "")
spawn(function()
    local __prevTier = nil
    pcall(function()
        while __DIO_wait(1.2) do
            local __v = "Tiers - V4 : " .. " " .. plr.Data.Race.C.Value
            if __v ~= __prevTier then __prevTier = __v CheckTier:SetDesc(__v) end
        end
    end)
end)
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Pull Lever"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Lver = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.Lver then
      pcall(function()
        for x,c in pairs(workspace.Map["Temple of Time"]:GetDescendants()) do
        if c.Name == "ProximityPrompt" then fireproximityprompt(c,math.huge)end
        end
      end)
    end
  end
end, "L9622")
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Train V4"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AcientOne = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.AcientOne then
        local BonesTable = {"Reborn Skeleton","Living Zombie","Demonic Soul","Posessed Mummy"}
	    for i=1,#BonesTable do
          if plr.Character:FindFirstChild("RaceEnergy").Value == 1 then
            vim1:SendKeyEvent(true, "Y", false, game)
            replicated.Remotes.CommF_:InvokeServer("UpgradeRace","Buy")
            _tp(CFrame.new(-8987.041015625, 215.862060546875, 5886.71044921875))
	      elseif plr.Character:FindFirstChild("RaceTransformed").Value == false then
	        local v = GetConnectionEnemies(BonesTable)
	        if v then repeat __DIO_wait(0.25) Attack.Kill(v, _G.AcientOne) until _G.AcientOne == false or v.Humanoid.Health <= 0 or not v.Parent
		    else _tp(CFrame.new(-9495.6806640625, 453.58624267578125, 5977.3486328125))
		    end
	      end
        end
      end
    end)
  end
end, "L9640")
Tabs.Race:AddButton({
    Name = __DIO_T["Teleport to Temple of Time"],
    Description = "",
    Callback = function()
        local plr = __SVC_PLR.LocalPlayer
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(28286.35546875, 14895.3017578125, 102.62469482421875)
            __DIO_TweenSet(hrp.CFrame)
        end
        local __mapTOT = __SVC_WS:FindFirstChild("Map")
        if __mapTOT and not __mapTOT:FindFirstChild("Temple of Time") and World3 then
            local stash = __SVC_RS:FindFirstChild("MapStash")
            if stash and stash:FindFirstChild("Temple of Time") then
                stash["Temple of Time"].Parent = workspace.Map
            end
        end
    end
})
Tabs.Race:AddButton({
Name = __DIO_T["Teleport to Ancient One"],
Description = "",
Callback = function()
        local plr = __SVC_PLR.LocalPlayer
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(28286.35546875, 14895.3017578125, 102.62469482421875)
            __DIO_TweenSet(hrp.CFrame)
        end
        local __mapTOT = __SVC_WS:FindFirstChild("Map")
        if __mapTOT and not __mapTOT:FindFirstChild("Temple of Time") and World3 then
            local stash = __SVC_RS:FindFirstChild("MapStash")
            if stash and stash:FindFirstChild("Temple of Time") then
                stash["Temple of Time"].Parent = workspace.Map
            end
        end
        __DIO_wait(2)
        _tp(CFrame.new(28981.552734375, 14888.4267578125, - 120.245849609375))
    end
})
Tabs.Race:AddButton({
Name = __DIO_T["Teleport to Ancient Clock"],
Description = "",
Callback = function()
        local plr = __SVC_PLR.LocalPlayer
        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        local pos1 = CFrame.new(28286.35546875, 14895.3017578125, 102.62469482421875)
        local pos2 = CFrame.new(29549, 15069, -88)
        if hrp then
            hrp.CFrame = pos1
            __DIO_TweenSet(hrp.CFrame)
        end
        task.delay(2, function()
            __DIO_FlyTo(pos2, 15)
        end)
        local __mapTOT = workspace:FindFirstChild("Map")
        if __mapTOT and not __mapTOT:FindFirstChild("Temple of Time") and World3 then
            local stash = __SVC_RS:FindFirstChild("MapStash")
            if stash and stash:FindFirstChild("Temple of Time") then
                stash["Temple of Time"].Parent = workspace.Map
            end
        end
    end
})
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Teleport to Race Doors"],
Description = "",
Default = false,
Callback = function(Value)
  _G.TPDoor = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.TPDoor then
	    if tostring(plr.Data.Race.Value) == "Mink" then
          _tp(CFrame.new(29020.66015625, 14889.4267578125, -379.2682800292969))
	    elseif tostring(plr.Data.Race.Value) == "Fishman" then
          _tp(CFrame.new(28224.056640625, 14889.4267578125, -210.5872039794922))
	    elseif tostring(plr.Data.Race.Value) == "Cyborg" then
          _tp(CFrame.new(28492.4140625, 14894.4267578125, -422.1100158691406))
	    elseif tostring(plr.Data.Race.Value) == "Skypiea" then
          _tp(CFrame.new(28967.408203125, 14918.0751953125, 234.31198120117188))
	    elseif tostring(plr.Data.Race.Value) == "Ghoul" then
          _tp(CFrame.new(28672.720703125, 14889.1279296875, 454.5961608886719))
	    elseif tostring(plr.Data.Race.Value) == "Human" then
          _tp(CFrame.new(29237.294921875, 14889.4267578125, -206.94955444335938))
	    end
      end
    end)
  end
end, "L9740")
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Complete Trial Race"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Complete_Trials = Value
end})
GetSeaBeastTrial = function()
  if not workspace.Map:FindFirstChild("FishmanTrial") then return nil end
  if workspace["_WorldOrigin"].Locations:FindFirstChild("Trial of Water") then FishmanTrial = workspace["_WorldOrigin"].Locations:FindFirstChild("Trial of Water") end
  if FishmanTrial then
    for _,v in next, workspace.SeaBeasts:GetChildren() do
      if v:FindFirstChild("HumanoidRootPart") and (v.HumanoidRootPart.Position - FishmanTrial.Position).Magnitude <= 1500 then
      if v.Health.Value > 0 then return v end
      end
    end
  end
end
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Complete_Trials then
        if tostring(plr.Data.Race.Value) == "Mink" then
          notween(workspace.Map.MinkTrial.Ceiling.CFrame * CFrame.new(0,-20,0))
	   end
      end
    end)
  end
end, "L9779")
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Complete_Trials then
	    if tostring(plr.Data.Race.Value) == "Fishman" then
	      if GetSeaBeastTrial() then
            repeat __DIO_wait(Sec)
              _tp(CFrame.new(GetSeaBeastTrial().HumanoidRootPart.Position.X,__SVC_WS.Map["WaterBase-Plane"].Position.Y + 300,GetSeaBeastTrial().HumanoidRootPart.Position.Z))
		      MousePos = GetSeaBeastTrial().HumanoidRootPart.Position
              Useskills("Melee","Z")
	          Useskills("Melee","X")
	          Useskills("Melee","C")
              __DIO_wait(.1)
              Useskills("Sword","Z")
              Useskills("Sword","X")
              __DIO_wait(.1)
              Useskills("Blox Fruit","Z")
              Useskills("Blox Fruit","X")
              Useskills("Blox Fruit","C")
              __DIO_wait(.1)
              Useskills("Gun","Z")
              Useskills("Gun","X")
            until _G.Complete_Trials == false or not GetSeaBeastTrial()
          end
	    end
      end
    end)
  end
end, "L9790")
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Complete_Trials then
        if tostring(plr.Data.Race.Value) == "Cyborg" then
         _tp(workspace.Map.CyborgTrial.Floor.CFrame * CFrame.new(0,500,0))
   	   end
      end
    end)
  end
end, "L9819")
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Complete_Trials then
        if tostring(plr.Data.Race.Value) == "Skypiea" then
          notween(workspace.Map.SkyTrial.Model.FinishPart.CFrame)
  	   end
      end
    end)
  end
end, "L9830")
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.Complete_Trials then
	    if tostring(plr.Data.Race.Value) == "Human" or tostring(plr.Data.Race.Value) == "Ghoul" then
	      local TrialsTables = {"Ancient Vampire","Ancient Zombie"}
	      local v = GetConnectionEnemies(TrialsTables)
          if v then repeat __DIO_wait(0.25) Attack.Kill(v, _G.Complete_Trials)until _G.Complete_Trials == false or not v.Parent or v.Humanoid.Health <= 0 end
        end
      end
    end)
  end
end, "L9841")
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Kill Player After Trial"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Defeating = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Defeating then
	    for _, v in pairs(workspace.Characters:GetChildren()) do
          if v.Name ~= plr.Name then
            if v.Humanoid.Health > 0 and v:FindFirstChild("HumanoidRootPart") and v.Parent and (Root.Position - v.HumanoidRootPart.Position).Magnitude <= 250 then
              repeat __DIO_wait(0.25) EquipWeapon(_G.SelectWeapon) _tp(v.HumanoidRootPart.CFrame * CFrame.new(0,0,15)) sethiddenproperty(plr, "SimulationRadius", math.huge)until _G.Defeating == false or v.Humanoid.Health <= 0 or not v.Parent or not v:FindFirstChild("HumanoidRootPart") or not v:FindFirstChild("Humanoid")
            end
          end
        end
      end
    end)
  end
end, "L9861")
Tabs.Prehistoric:AddSection("Dojo Quest")
Tabs.Prehistoric:AddButton({
    Title = "Teleport To Dragon Dojo",
    Callback = function()
        __SVC_RS.Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(5661.5322265625, 1013.0907592773438, - 334.9649963378906))
        topos(CFrame.new(5814.42724609375, 1208.3267822265625, 884.5785522460938))
    end
})
Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Dojo Trainer"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Dojoo = Value
  if not Value then
    __DIO_ReleaseAll("Dojoo")
    StopTween(false)
    __DIO_CurTarget = nil
    if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
  end
end})
function printBeltName(data) if type(data) == "table" and data.Quest["BeltName"] then return data.Quest["BeltName"] end end
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.Dojoo then
      pcall(function()
        local args = {[1] = {["NPC"] = "Dojo Trainer",["Command"] = "RequestQuest"}}
        local progress = replicated.Modules.Net:FindFirstChild("RF/InteractDragonQuest"):InvokeServer(unpack(args))
        local NameBelt = printBeltName(progress)
        if __DIO_TTDebug == false and not progress and not NameBelt then
          _tp(CFrame.new(5865.0234375, 1208.3154296875, 871.15185546875))
          __DIO_TTDebug = true
        elseif __DIO_TTDebug == true and (CFrame.new(5865.0234375, 1208.3154296875, 871.15185546875).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 50 then
          if NameBelt == "White" then
            local v = GetConnectionEnemies("Skull Slayer")
            if v then repeat __DIO_wait(Sec) Attack.Kill(v, _G.Dojoo) until not progress or not _G.Dojoo or not Attack.Alive(v)
            else _tp(CFrame.new(-16759.58984375, 71.28376770019531, 1595.3399658203125))
            end
          elseif NameBelt == "Yellow" then
            repeat __DIO_wait(0.25)
              __DIO_BorrowFlag("Dojoo", {"SeaBeast1","TerrorShark","Shark","Piranha","MobCrew","FishBoat","SailBoats"})
            until not _G.Dojoo or not progress
            __DIO_ReleaseAll("Dojoo")
          elseif NameBelt == "Green" then
            repeat __DIO_wait()
              __DIO_BorrowFlag("Dojoo", "SailBoats")
            until not _G.Dojoo or not progress
            __DIO_ReleaseAll("Dojoo")
          elseif NameBelt == "Purple" then
            repeat __DIO_wait()
              __DIO_BorrowFlag("Dojoo", "FarmEliteHunt")
            until not _G.Dojoo or not progress
            __DIO_ReleaseAll("Dojoo")
          elseif NameBelt == "Red" then
            repeat __DIO_wait()
              __DIO_BorrowFlag("Dojoo", {"SailBoats","FishBoat"})
            until not _G.Dojoo or not progress
            __DIO_ReleaseAll("Dojoo")
          elseif NameBelt == "Black" then
            repeat __DIO_wait()
              if workspace.Map:FindFirstChild("PrehistoricIsland") or workspace._WorldOrigin.Locations:FindFirstChild("Prehistoric Island") then
                __DIO_SetFlag("Prehis_Find","Dojoo",true)
                if workspace.Map.PrehistoricIsland.Core.ActivationPrompt:FindFirstChild("ProximityPrompt",true) then
                  __DIO_SetFlag("Prehis_Skills","Dojoo",false)
                  __DIO_SetFlag("Prehis_Find","Dojoo",true)
                else
                  __DIO_SetFlag("Prehis_Skills","Dojoo",true)
                  __DIO_SetFlag("Prehis_Find","Dojoo",false)
                end
              else
                __DIO_SetFlag("Prehis_Find","Dojoo",true)
                __DIO_SetFlag("Prehis_Skills","Dojoo",false)
              end
            until not _G.Dojoo or not progress
            __DIO_SetFlag("Prehis_Find","Dojoo",false)
            __DIO_SetFlag("Prehis_Skills","Dojoo",false)
          elseif NameBelt == "Orange" or NameBelt == "Blue" then
            return nil
          end
        end
        if not progress then
          __DIO_TTDebug = false
          local args = {[1] = {["NPC"] = "Dojo Trainer",["Command"] = "ClaimQuest"}}
          replicated.Modules.Net:FindFirstChild("RF/InteractDragonQuest"):InvokeServer(unpack(args))
        end
      end)
    end
  end
end, "L9893")
Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Dragon Hunter"],
Description = "",
Default = false,
Callback = function(Value)
  _G.FarmBlazeEM = Value
end})
checkQuesta=function()local a={[1]={["Context"]="Check"}}local b=nil;pcall(function()local c={[1]={["Context"]="RequestQuest"}}__SVC_RS:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/DragonHunter"):InvokeServer(unpack(c))end)pcall(function()b=__SVC_RS:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/DragonHunter"):InvokeServer(unpack(a))end)local f=false;local g;local h;local i;if b then if b.Text then f=true;local j=b.Text;if string.find(tostring(j),"Defeat")then i=1;g=string.sub(tostring(j),8,9)g=tonumber(g)local k={"Hydra Enforcer","Venomous Assailant"}for l,m in pairs(k)do if string.find(j,m)then h=m;break end end elseif string.find(tostring(j),"Destroy")then g=10;i=2;h=nil end end end;return f,h,g,i end
BackTODoJo=function()for a,b in pairs(__SVC_PLR.LocalPlayer.PlayerGui.Notifications:GetChildren())do if b.Name=="NotificationTemplate"then if string.find(b.Text,"Head back to the Dojo to complete more tasks")then return true end end end;return false end
DragonMobClear=function(a,b,c)if workspace.Enemies:FindFirstChild(b)then for d,e in pairs(workspace.Enemies:GetChildren())do if e.Name==b and Attack.Alive(e)then if a then Attack.Kill(e,a)end end end else _tp(c)end end
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.FarmBlazeEM then
      pcall(function()
        local a,v,_,x = checkQuesta()
        if a == true and not BackTODoJo() then
          if x == 1 then
            if v == "Hydra Enforcer" or v == "Venomous Assailant" then
              repeat __DIO_wait()
                DragonMobClear(true, v, CFrame.new(4620.61572265625, 1002.2954711914062, 399.0868835449219))
              until not _G.FarmBlazeEM or not a or BackTODoJo()
            end
          elseif x == 2 then
            if workspace.Map.Waterfall.IslandModel:FindFirstChild("Meshes/bambootree", true) then
              repeat __DIO_wait(0.25)
                _tp(workspace.Map.Waterfall.IslandModel:FindFirstChild("Meshes/bambootree", true).CFrame * CFrame.new(4,0,0))
                if (workspace.Map.Waterfall.IslandModel:FindFirstChild("Meshes/bambootree", true).Position - Root.Position).Magnitude <= 200 then
                MousePos = workspace.Map.Waterfall.IslandModel:FindFirstChild("Meshes/bambootree", true).Position
                Useskills("Melee","Z")
	            Useskills("Melee","X")
	            Useskills("Melee","C")
                __DIO_wait(.5)
                Useskills("Sword","Z")
                Useskills("Sword","X")
                __DIO_wait(.5)
                Useskills("Blox Fruit","Z")
                Useskills("Blox Fruit","X")
                Useskills("Blox Fruit","C")
                __DIO_wait(.5)
                Useskills("Gun","Z")
                Useskills("Gun","X")
                end
              until not _G.FarmBlazeEM or not a or BackTODoJo()
            end
          end
        else
          _tp(CFrame.new(5813, 1208, 884))
          DragonMobClear(false, nil, nil)
        end
      end)
    end
  end
end, "L9984")
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.FarmBlazeEM then
      pcall(function()
        if workspace.EmberTemplate:FindFirstChild("Part") then
          game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = workspace.EmberTemplate.Part.CFrame
          __DIO_TweenSet(workspace.EmberTemplate.Part.CFrame)
        end
      end)
    end
  end
end, "L10027")
Tabs.Prehistoric:AddSection("Draco Trial")
GetQuestDracoLevel = function()
  local v371 = {[1] = {NPC = "Dragon Wizard",Command = "Upgrade"}};
  return replicated.Modules.Net:FindFirstChild("RF/InteractDragonQuest"):InvokeServer(unpack(v371))
end
Toggle = Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Tween To Upgrade Draco Trial"],
Description = "",
Default = false,
Callback = function(Value)
  _G.UPGDrago = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.UPGDrago then
        if GetQuestDracoLevel() == false then
          return nil
        elseif GetQuestDracoLevel() == true then
          if (CFrame.new(5814.42724609375, 1208.3267822265625, 884.5785522460938).Position - Root.Position).Magnitude >= 300 then
            _tp(CFrame.new(5814.42724609375, 1208.3267822265625, 884.5785522460938));
          else
            _tp(CFrame.new(5814.42724609375, 1208.3267822265625, 884.5785522460938));
            local v371 = {[1] = {NPC = "Dragon Wizard",Command = "Upgrade"}};
            replicated.Modules.Net:FindFirstChild("RF/InteractDragonQuest"):InvokeServer(unpack(v371));
          end
        end
      end
    end)
  end
end, "L10052")
Toggle = Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Draco (V1)"],
Description = "",
Default = false,
Callback = function(Value)
  _G.DragoV1 = Value
  if not Value then __DIO_ReleaseAll("DragoV1") StopTween(false) end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.DragoV1 then
        if GetM("Dragon Egg") <= 0 then
        repeat __DIO_wait()
          __DIO_BorrowFlag("DragoV1", {"Prehis_Find","Prehis_Skills","Prehis_DE"})
        until not _G.DragoV1 or GetM("Dragon Egg") >= 1
          __DIO_ReleaseAll("DragoV1")
        end
      end
    end)
  end
end, "L10078")
Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Draco (V2)"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoFireFlowers = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
    if _G.AutoFireFlowers then
      local FireFlower = workspace:FindFirstChild("FireFlowers")
      local v = GetConnectionEnemies("Forest Pirate")
      if v then repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoFireFlowers) until not _G.AutoFireFlowers or not v.Parent or v.Humanoid.Health <= 0 or FireFlower
      else _tp(CFrame.new(-13206.452148438, 425.89199829102, -7964.5537109375))
      end
      if FireFlower then
        for i, v in pairs(FireFlower:GetChildren()) do
          if (v:IsA("Model") and v.PrimaryPart) then
            local FlowerPos = v.PrimaryPart.Position;
            local playerRoot = game.Players.LocalPlayer.Character.HumanoidRootPart.Position;
            local Magnited = (FlowerPos - playerRoot).Magnitude;
            if (Magnited <= 100) then
              vim1:SendKeyEvent(true, "E", false, game) __DIO_wait(1.5) vim1:SendKeyEvent(false, "E", false, game)
            else
              _tp(CFrame.new(FlowerPos));
            end
          end
        end
      end
    end
    end)
  end
end, "L10103")
Toggle = Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Draco (V3)"],
Description = "",
Default = false,
Callback = function(Value)
  _G.DragoV3 = Value
  if not Value then __DIO_ReleaseAll("DragoV3") StopTween(false) end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.DragoV3 then
        repeat __DIO_wait(0.5)
          __DIO_BorrowValue("DragoV3","DangerSc","Lv Infinite")
          __DIO_BorrowFlag("DragoV3","SailBoats")
          __DIO_BorrowFlag("DragoV3","TerrorShark")
        until not _G.DragoV3
        __DIO_ReleaseAll("DragoV3")
      end
    end)
  end
end, "L10138")
Toggle = Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Relic Draco Trial [Beta]"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Relic123 = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.Relic123 then
      pcall(function()
        if workspace.Map:FindFirstChild("DracoTrial") then
          replicated.Remotes.DracoTrial:InvokeServer()
          __DIO_wait(.5)
          repeat __DIO_wait(0.25) _tp(CFrame.new(-39934.9765625, 10685.359375, 22999.34375)) until not _G.Relic123 or (Root.Position - CFrame.new(-39934.9765625, 10685.359375, 22999.34375)).Magnitude <= 5
          repeat __DIO_wait(0.25) _tp(CFrame.new(-40511.25390625, 9376.4013671875, 23458.37890625)) until not _G.Relic123 or (Root.Position - CFrame.new(-40511.25390625, 9376.4013671875, 23458.37890625)).Magnitude <= 5
          __DIO_wait(2.5)
          repeat __DIO_wait(0.25) _tp(CFrame.new(-39914.65625, 10685.384765625, 23000.177734375)) until not _G.Relic123 or (Root.Position - CFrame.new(-39914.65625, 10685.384765625, 23000.177734375)).Magnitude <= 5
          repeat __DIO_wait(0.25) _tp(CFrame.new(-40045.83203125, 9376.3984375, 22791.287109375)) until not _G.Relic123 or (Root.Position - CFrame.new(-40045.83203125, 9376.3984375, 22791.287109375)).Magnitude <= 5
          __DIO_wait(2.5)
          repeat __DIO_wait(0.25) _tp(CFrame.new(-39908.5, 10685.4052734375, 22990.04296875)) until not _G.Relic123 or (Root.Position - CFrame.new(-39908.5, 10685.4052734375, 22990.04296875)).Magnitude <= 5
          repeat __DIO_wait(0.25) _tp(CFrame.new(-39609.5, 9376.400390625, 23472.94335975)) until not _G.Relic123 or (Root.Position - CFrame.new(-39609.5, 9376.400390625, 23472.94335975)).Magnitude <= 5
        else
          local drago = workspace.Map.PrehistoricIsland:FindFirstChild("TrialTeleport")
          if drago and drago:IsA("Part") then _tp(CFrame.new(drago.Position)) end
        end
      end)
    end
  end
end, "L10161")
Toggle = Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Train Draco v4"],
Description = "",
Default = false,
Callback = function(Value)
  _G.TrainDrago = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.TrainDrago then
        local DragoM = {"Venomous Assailant","Hydra Enforcer"}
	    for i=1,#DragoM do
          if plr.Character:FindFirstChild("RaceEnergy").Value == 1 then
            vim1:SendKeyEvent(true, "Y", false, game)
            replicated.Remotes.CommF_:InvokeServer("UpgradeRace","Buy",2)
            _tp(CFrame.new(4620.61572265625, 1002.2954711914062, 399.0868835449219))
	      elseif plr.Character:FindFirstChild("RaceTransformed").Value == false then
	        local v = GetConnectionEnemies(DragoM)
	        if v then repeat __DIO_wait(0.25) Attack.Kill(v, _G.TrainDrago) until _G.TrainDrago == false or v.Humanoid.Health <= 0 or not v.Parent
		    else _tp(CFrame.new(4620.61572265625, 1002.2954711914062, 399.0868835449219))
		    end
	      end
        end
      end
    end)
  end
end, "L10191")
Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Tween to Draco Trials"],
Description = "",
Default = false,
Callback = function(Value)
  _G.TpDrago_Prehis = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
    if _G.TpDrago_Prehis then
      local __pi = workspace.Map:FindFirstChild("PrehistoricIsland")
      local v748 = __pi and __pi:FindFirstChild("TrialTeleport");
      if (v748 and v748:IsA("Part")) then _tp(CFrame.new(v748.Position)) end
    end
    end)
  end
end, "L10219")
Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Swap Draco Race"],
Description = "",
Default = false,
Callback = function(Value)
  _G.BuyDrago = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.BuyDrago then
      pcall(function()
        if (CFrame.new(5814.42724609375, 1208.3267822265625, 884.5785522460938).Position - Root.Position).Magnitude >= 300 then
          _tp(CFrame.new(5814.42724609375, 1208.3267822265625, 884.5785522460938));
        else
          _tp(CFrame.new(5814.42724609375, 1208.3267822265625, 884.5785522460938));
          local v371 = {[1] = {NPC = "Dragon Wizard",Command = "DragonRace"}};
          replicated.Modules.Net:FindFirstChild("RF/InteractDragonQuest"):InvokeServer(unpack(v371));
        end
      end)
    end
  end
end, "L10238")
Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Upgrade Dragon Talon With Uzoth"],
Description = "",
Default = false,
Callback = function(Value)
  _G.DT_Uzoth = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.DT_Uzoth then
      pcall(function()
        local __hrpU = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if not __hrpU then return end
      local Uz_POS = CFrame.new(5661.89014, 1211.31909, 864.836731, 0.811413169, -1.36805838e-08, -0.584473014, 4.75227395e-08, 1, 4.25682458e-08, 0.584473014, -6.23161966e-08, 0.811413169)
        _tp(Uz_POS)
        if (Uz_POS.Position - __hrpU.Position).Magnitude <= 25 then
          local ohTable1 = {["NPC"] = "Uzoth",["Command"] = "Upgrade"}
          replicated.Modules.Net["RF/InteractDragonQuest"]:InvokeServer(ohTable1)
        end
      end)
    end
  end
end, "L10260")
__DIO_SafeLoop(function()
    while __DIO_wait(Sec) do
        pcall(function()
            if _G.Prehis_Find then
                local char = plr.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then return end
                local Locations = workspace["_WorldOrigin"].Locations
                local prehistoricLoc = Locations:FindFirstChild("Prehistoric Island", true)
                -- FIX: model dao that nam o workspace.Map.PrehistoricIsland (giong code Draco/su kien Prehistoric).
                -- Truoc day chi check Locations -> dao da xuat hien ma thuyen van fly ra bien quet mai.
                if not prehistoricLoc then
                    pcall(function()
                        local __mp = workspace.Map:FindFirstChild("PrehistoricIsland")
                        if __mp then prehistoricLoc = __mp end
                    end)
                end
                if not prehistoricLoc then
                    if __DIO_BoatAssist() ~= "sitting" then return end
                    -- dich cruise do __DIO_FindCruiseDest quyet dinh (ping-pong 10km / 1 chieu)
                    __DIO_NoClipShipNow()
                    -- [DIO-FIX] Mot nguon Y duy nhat cho ca 4 Find (Fly Boat / Sea Event Y)
                    local __wantYP = __DIO_CruiseFeed("prehis")
                    __DIO_CruiseGo("prehis", __DIO_FindCruiseDest(__wantYP))
                else
                    __DIO_CruiseStop("prehis")
                    local stoneHead =
                        prehistoricLoc:FindFirstChild("HeadTeleport", true)
                        or prehistoricLoc:FindFirstChild("Teleport_Head", true)
                        or prehistoricLoc:FindFirstChild("Head", true)
                    if stoneHead then
                        local headCF = stoneHead.CFrame
                        -- FIX theo yeu cau: thuyen giu im Y 31 (mat nuoc), khong bay cao nua
                        local __hpK = headCF.Position - headCF.LookVector * 40
                        local safePos = Vector3.new(__hpK.X, 31, __hpK.Z)
                        if (safePos - hrp.Position).Magnitude > 30 then
                            _tp(CFrame.new(safePos))
                        end
                    else
                        -- FIX: prehistoricLoc co the la Model (Map.PrehistoricIsland) -> lay vi tri qua GetPivot,
                        -- va da dung gan dao roi thi khong _tp lap lai.
                        local islandPos = nil
                        pcall(function()
                            if prehistoricLoc:IsA("Model") then
                                islandPos = prehistoricLoc:GetPivot().Position
                            else
                                islandPos = prehistoricLoc.CFrame.Position
                            end
                        end)
                        if islandPos then
                            local __dPH = islandPos - hrp.Position
                            local dir = (__dPH.Magnitude > 1) and __dPH.Unit or Vector3.new(0, 0, 1)
                            -- FIX theo yeu cau: giu thuyen o Y 31 (mat nuoc), khong +60 nua
                            local __ppK = islandPos - dir * 250
                            local safePos = Vector3.new(__ppK.X, 31, __ppK.Z)
                            if (safePos - hrp.Position).Magnitude > 30 then
                                _tp(CFrame.new(safePos))
                            end
                        end
                    end
                end
            end
        end)
    end
end, "L10385")

__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoStartPrehistoric then
            pcall(function()
                local prehistoricIsland = workspace["_WorldOrigin"].Locations:FindFirstChild("Prehistoric Island", true)
                if prehistoricIsland then
                    if workspace.Map:FindFirstChild("PrehistoricIsland", true) then
                        local promptPart = workspace.Map.PrehistoricIsland.Core:FindFirstChild("ActivationPrompt", true)
                        if promptPart and promptPart:FindFirstChild("ProximityPrompt") then
                            if plr:DistanceFromCharacter(promptPart.CFrame.Position) <= 150 then
                                fireproximityprompt(promptPart.ProximityPrompt, math.huge)
                                vim1:SendKeyEvent(true, "E", false, game)
                                __DIO_wait(1.5)
                                vim1:SendKeyEvent(false, "E", false, game)
                            end
                            _tp(promptPart.CFrame)
                        end
                    end
                end
            end)
        end
    end
end, "L10492") 

__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.Prehis_Skills then
            pcall(function()
                local island = workspace.Map:FindFirstChild("PrehistoricIsland")
                if not island then return end
                for _, obj in pairs(island:GetDescendants()) do
                    if (obj:IsA("BasePart") or obj:IsA("MeshPart"))
                        and obj.Name:lower():find("lava") then
                        obj:Destroy()
                    end
                end
                local core = island:FindFirstChild("Core")
                if core then
                    local lavaModel = core:FindFirstChild("InteriorLava")
                    if lavaModel then lavaModel:Destroy() end
                end
                local trialTeleport = island:FindFirstChild("TrialTeleport")
                for _, v in pairs(island:GetDescendants()) do
                    if v.Name == "TouchInterest"
                    and not (trialTeleport and v:IsDescendantOf(trialTeleport)) then
                        v.Parent:Destroy()
                    end
                end
            end)
        end
    end
end, "L10530")
__DIO_PrehisGolemT = 0
__DIO_PrehisGolemR = false
function __DIO_PrehisHasGolem()
    if tick() - __DIO_PrehisGolemT < 0.3 then return __DIO_PrehisGolemR end
    __DIO_PrehisGolemT = tick()
    local g = GetConnectionEnemies("Lava Golem")
    __DIO_PrehisGolemR = (g ~= nil and g.Parent ~= nil)
    return __DIO_PrehisGolemR
end
__DIO_SafeLoop(function()
    while __DIO_wait(Sec) do
        if _G.Prehis_Skills then
            pcall(function()
                local golem = GetConnectionEnemies("Lava Golem")
                if golem and golem:FindFirstChild("Humanoid") then
                    repeat
                        __DIO_wait(0.1)
                        Attack.Kill(golem, true)
                        golem.Humanoid:ChangeState(15)
                    until not _G.Prehis_Skills
                        or not golem.Parent
                        or golem.Humanoid.Health <= 0
                    __DIO_PrehisGolemT = 0
                    __DIO_PrehisGolemR = false
                end
            end)
        end
    end
end, "L10573")
__DIO_SafeLoop(function()
    while __DIO_wait(Sec) do
        if _G.Prehis_Skills then
            pcall(function()
                if __DIO_PrehisHasGolem() then return end
                local island = workspace.Map:FindFirstChild("PrehistoricIsland")
                if not island then return end
                local core = island:FindFirstChild("Core")
                if not core then return end
                local rocks = core:FindFirstChild("VolcanoRocks")
                if not rocks then return end
                for _, rock in pairs(rocks:GetChildren()) do
                    if __DIO_PrehisHasGolem() then return end
                    local layer = rock:FindFirstChild("VFXLayer")
                    local at0 = layer and layer:FindFirstChild("At0")
                    local glow = at0 and at0:FindFirstChild("Glow")
                    if glow and glow.Enabled then
                        repeat
                            __DIO_wait(0.1)
                            if __DIO_PrehisHasGolem() then break end
                            _tp(layer.CFrame)
                            if plr:DistanceFromCharacter(layer.CFrame.Position) <= 150 then
                                MousePos = layer.CFrame.Position
                                Useskills("Melee","Z") __DIO_wait(.4)
                                if __DIO_PrehisHasGolem() then break end
                                Useskills("Melee","X") __DIO_wait(.4)
                                if __DIO_PrehisHasGolem() then break end
                                Useskills("Melee","C") __DIO_wait(.4)
                                if __DIO_PrehisHasGolem() then break end
                                Useskills("Blox Fruit","Z") __DIO_wait(.4)
                                if __DIO_PrehisHasGolem() then break end
                                Useskills("Blox Fruit","X") __DIO_wait(.4)
                                if __DIO_PrehisHasGolem() then break end
                                Useskills("Blox Fruit","C")
                            end
                        until not _G.Prehis_Skills or not glow.Enabled or __DIO_PrehisHasGolem()
                    end
                end
            end)
        end
    end
end, "L10596")
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Prehis_DB then
        if workspace:FindFirstChild("DinoBone") then
          for i,v in pairs(workspace:GetChildren()) do
            if v.Name == "DinoBone" then _tp(v.CFrame) end
          end
        end
      end
    end)
  end
end, "L10689")
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Prehis_DE then
      if workspace.Map.PrehistoricIsland.Core.SpawnedDragonEggs:FindFirstChild("DragonEgg") then _tp(workspace.Map.PrehistoricIsland.Core.SpawnedDragonEggs:FindFirstChild("DragonEgg").Molten.CFrame) fireproximityprompt(workspace.Map.PrehistoricIsland.Core.SpawnedDragonEggs.DragonEgg.Molten.ProximityPrompt, 30) end
      end
    end)
  end
end, "L10709")
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.ResetPH then
        local v748 = workspace.Map.PrehistoricIsland:FindFirstChild("TrialTeleport");
        if (v748 and v748:FindFirstChild("TouchInterest")) then
          plr.Character.Humanoid.Health = 0
        else
          if workspace:FindFirstChild("DinoBone") then
            for i,v in pairs(workspace:GetChildren()) do
              if v.Name == "DinoBone" then _tp(v.CFrame) end
            end
          end
        end
      end
    end)
  end
end, "L10725")
Tabs.SeaEvent:AddSection("Sea Event / Setting Sail")
local ListSeaBoat={"Guardian","PirateGrandBrigade","MarineGrandBrigade","PirateBrigade","MarineBrigade","PirateSloop","MarineSloop","Beast Hunter"}
local ListSeaZone={"Lv 1","Lv 2","Lv 3","Lv 4","Lv 5","Lv 6","Lv Infinite"}

__DIO_SeaWpOpts   = {"Melee","Sword","Gun","Blox Fruit"}
__DIO_SeaSkillOpts = {"Z","X","C","V","F"}
__DIO_SeaNormList = function(Value, opts, def)
    local __raw = {}
    if type(Value) == "table" then
        for __k, __v in pairs(Value) do
            if __v == true then
                if type(__k) == "string" and table.find(opts, __k) then
                    table.insert(__raw, __k)
                elseif type(__k) == "number" and table.find(opts, Value[__k]) then
                    table.insert(__raw, Value[__k])
                end
            end
        end
    elseif type(Value) == "string" and table.find(opts, Value) then
        table.insert(__raw, Value)
    end
    if #__raw == 0 and def then table.insert(__raw, def) end
    local __out = {}
    for _, __o in ipairs(opts) do
        if table.find(__raw, __o) then table.insert(__out, __o) end
    end
    return __out
end
_G.SeaEventWeaponList = __DIO_SeaNormList(GetSetting("UI/SeaEvent/Select Weapon Sea Event", nil), __DIO_SeaWpOpts, "Melee")
_G.SeaEventSkillList  = __DIO_SeaNormList(GetSetting("UI/SeaEvent/Select Skill", nil), __DIO_SeaSkillOpts, "Z")
Tabs.SeaEvent:AddDropdown({
    Name = __DIO_T["Select Weapon Sea Event"],
    Options = __DIO_SeaWpOpts,
    Default = _G.SeaEventWeaponList,
    MultiSelect = true,
    Callback = function(Value)
        _G.SeaEventWeaponList = __DIO_SeaNormList(Value, __DIO_SeaWpOpts, "Melee")
    end
})
Tabs.SeaEvent:AddDropdown({
    Name = __DIO_T["Select Skill"],
    Options = __DIO_SeaSkillOpts,
    Default = _G.SeaEventSkillList,
    MultiSelect = true,
    Callback = function(Value)
        _G.SeaEventSkillList = __DIO_SeaNormList(Value, __DIO_SeaSkillOpts, "Z")
    end
})
__DIO_SeaSelPrev = {}
__DIO_SeaEntityMap = {
    ["Terror Shark"]        = "TerrorShark",
    ["Piranha"]             = "Piranha",
    ["Shark"]               = "Shark",
    ["Sea Beast"]           = "SeaBeast1",
    ["Fish Boat"]           = "FishBoat",
    ["Fish Crew Member"]    = "MobCrew",
    ["Haunted Crew Member"] = "HCM",
    ["PirateGrandBrigade"]  = "PGB",
}
Tabs.SeaEvent:AddDropdown({
    Name = __DIO_T["Select Sea Event"],
    Options = {"Terror Shark","Piranha","Shark","Sea Beast","Fish Boat","Fish Crew Member","Haunted Crew Member","PirateGrandBrigade"},
    Default = {},
    MultiSelect = true,
    Callback = function(Value)
        local __sel = {}
        if type(Value) == "table" then
            for __k, __v in pairs(Value) do
                if __v == true then
                    if type(__k) == "string" and __DIO_SeaEntityMap[__k] then
                        __sel[__k] = true
                    elseif type(__k) == "number" and __DIO_SeaEntityMap[Value[__k]] then
                        __sel[Value[__k]] = true
                    end
                end
            end
        end
        for __name, __flag in pairs(__DIO_SeaEntityMap) do
            if __sel[__name] then
                __DIO_SetFlag(__flag, "SeaEventDrop:" .. __name, true)
                __DIO_SeaSelPrev[__name] = true
            elseif __DIO_SeaSelPrev[__name] then
                __DIO_SetFlag(__flag, "SeaEventDrop:" .. __name, false)
                __DIO_SeaSelPrev[__name] = nil
                -- FIX: wrapper AddDropdown tu dang ky owner "UI:<tab>/<name>" cho flag nay.
                -- Neu khong xoa owner do, _G.<flag> bi ket true mai mai
                -- -> highlight + shouldTween khong bao gio tat du da bo chon sea event.
                -- owner do wrapper AddDropdown/AddToggle dang ky co 2 dang:
                --   "UI:UI/<tab>/<name>"  (trong __DIO_FlagWant, qua __DIO_UIWant)
                --   "UI/<tab>/<name>"     (trong __DIO_UIFlagOwner, qua __DIO_UISetOn)
                local __isUIOwner = function(__s)
                    if type(__s) ~= "string" then return false end
                    local __p = string.sub(__s, 1, 3)
                    return (__p == "UI:") or (__p == "UI/")
                end
                if type(__DIO_FlagWant) == "table" and type(__DIO_FlagWant[__flag]) == "table" then
                    for __own in pairs(__DIO_FlagWant[__flag]) do
                        if __isUIOwner(__own) then __DIO_FlagWant[__flag][__own] = nil end
                    end
                end
                if type(__DIO_UIFlagOwner) == "table" and type(__DIO_UIFlagOwner[__flag]) == "table" then
                    for __uik in pairs(__DIO_UIFlagOwner[__flag]) do
                        if __isUIOwner(__uik) then pcall(__DIO_UISetOn, __flag, __uik, false) end
                    end
                end
                if type(__DIO_FlagApply) == "function" then pcall(__DIO_FlagApply, __flag) end
                if type(__DIO_AnyFeatureOn) == "function" and not __DIO_AnyFeatureOn()
                   and type(StopTween) == "function" then
                    pcall(StopTween, false)
                end
            end
        end
    end
})
Tabs.SeaEvent:AddDropdown({
Name = __DIO_T["Select Sea Level"],
Options = ListSeaZone,
Default = "Lv 6",
Callback = function(Value)
  _G.DangerSc = Value
end})
Tabs.SeaEvent:AddDropdown({
    Name = __DIO_T["Select Boats"],
	Options = ListSeaBoat,
	Default = "Guardian",
	Callback = function(Value)
        _G.SelectedBoat = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
Tabs.SeaEvent:AddButton({
Name = __DIO_T["Buy Boats"],
Description = "",
Default = true,
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyBoat",(_G.SelectedBoat or "Guardian"))
end})
-- FIX: truoc day Toggle nay cung ten "Ship Speed" voi Slider ngay ben duoi -> trung key luu
-- "UI/SeaEvent/Ship Speed": Toggle luu boolean, Slider doc boolean do lam Default -> crash.
-- Doi Toggle ve dung ten "Ship Speed Modifier" (khop __DIO_ToggleFlagMap["UI/SeaEvent/Ship Speed Modifier"]),
-- Slider giu ten "Ship Speed" (Default = 300). Hai key tach biet -> khong ghi de len nhau nua.
Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Ship Speed Modifier"],
    Default = false,
    Callback = function(Value)
        getgenv().SpeedBoat = Value
    end
})
local __nextSpeedBoat = 0
__SVC_RUN.RenderStepped:Connect(function()
    if getgenv().SpeedBoat then
        if tick() < __nextSpeedBoat then return end
        __nextSpeedBoat = tick() + 0.25
        local plr = __SVC_PLR.LocalPlayer
        if plr.Character and plr.Character:FindFirstChild("Humanoid") then
            if plr.Character.Humanoid.Sit then
                for _, boat in pairs(__SVC_WS.Boats:GetChildren()) do
                    local seat = boat:FindFirstChildWhichIsA("VehicleSeat")
                    if seat then
                        seat.MaxSpeed = SetSpeedBoat
                    end
                end
            end
        end
    end
end)
Tabs.SeaEvent:AddSlider({
    Name = __DIO_T["Ship Speed"],
    Min = 0,
    Max = 1000,
    Increment = 1,
    Default = 300,
    Callback = function(Value)
        SetSpeedBoat = Value
    end
})
Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Auto Press W"],
    Default = false,
    Callback = function(Value)
        getgenv().AutoPressW = Value
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            if getgenv().AutoPressW then
                local __chW = game.Players.LocalPlayer.Character
                local humanoid = __chW and __chW:FindFirstChild("Humanoid")
                if humanoid and humanoid.Sit == true then
                    __SVC_VIM:SendKeyEvent(true, "W", false, game)
                end
            end
        end)
    end
end, "L10797")
if getgenv().NoClipShip == nil then getgenv().NoClipShip = true end
Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["No Clip Ship"],
    Default = true,
    Callback = function(Value)
        getgenv().NoClipShip = Value
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            local __boatsNC = __SVC_WS:FindFirstChild("Boats")
            if not __boatsNC then return end
            local __any = getgenv().NoClipShip
            pcall(__DIO_NoClipShipNow)
            for i, boat in pairs(__boatsNC:GetChildren()) do
                for _, v in pairs(boat:GetDescendants()) do
                    if v:IsA("BasePart") then
                        if __any then
                            if v.CanCollide then v.CanCollide = false end
                        else
                            if not v.CanCollide then v.CanCollide = true end
                        end
                    end
                end
            end
        end)
    end
end, "L10818")
Tabs.SeaEvent:AddSlider({
    Name = __DIO_T["Boat Speed Tween"],
    Min = 1,
    Max = 500,
    Default = 225,
    Increment = 1,
    Callback = function(Value)
        _G.BoatTweenSpeed = math.clamp(math.floor(Value + 0.5), 1, 300)
        pcall(function() getgenv().BoatTweenSpeed = _G.BoatTweenSpeed end)
    end
})
_G.BoatTweenSpeed = math.clamp(math.floor((tonumber(GetSetting("UI/SeaEvent/Boat Speed Tween", 165)) or 165) + 0.5), 1, 300)
pcall(function() getgenv().BoatTweenSpeed = _G.BoatTweenSpeed end)
-- FIX: khoi tao gia tri Fly Boat / Teleport Y tu setting luu truoc -> slider co tac dung ngay,
-- khong bi nil cho den khi chinh tay keo slider nua.
_G.FlyBoatY = math.clamp(math.floor((tonumber(GetSetting("UI/SeaEvent/Fly Boat", 150)) or 150) + 0.5), 30, 500)
_G.SeaTeleportY = math.clamp(math.floor((tonumber(GetSetting("UI/SeaEvent/Teleport Y boat If have Sea Event (ALL)", 150)) or 150) + 0.5), 150, 600)
_G.TeleportYSlider = (GetSetting("UI/SeaEvent/Teleport Y boat using a slider", false) == true)
_G.FindBack10km = (GetSetting("UI/SeaEvent/Will Back When over 10km", true) == true)
_G.AutoRepairShip = (GetSetting("UI/SeaEvent/Auto Repair Ur Ship", false) == true)
_G.SelectedBoat = _G.SelectedBoat or GetSetting("UI/SeaEvent/Select Boats", "Guardian") or "Guardian"
_G.DangerSc = _G.DangerSc or GetSetting("UI/SeaEvent/Select Sea Level", "Lv 6") or "Lv 6"
Tabs.SeaEvent:AddSection("Skill And Boat Sea Event")

Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Dodge Skill Terrorshark"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoDodgeTerrorshark = (Value == true)

  if _G.AutoDodgeTerrorshark ~= true and type(__DIO_TerrorDodgeOff) == "function" then
      __DIO_TerrorDodgeOff()
  end
end})
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Dodge Skill Seabeast"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoDodgeSeabeast = (Value == true)

  if _G.AutoDodgeSeabeast ~= true and type(__DIO_SeaDodgeOff) == "function" then
      __DIO_SeaDodgeOff()
  end
end})
Tabs.SeaEvent:AddSlider({
    Name = __DIO_T["Teleport Y boat If have Sea Event (ALL)"],
    Min = 150,
    Max = 600,
    Default = 150,
    Callback = function(Value)
        _G.SeaTeleportY = math.clamp(math.floor(tonumber(Value) or 150), 150, 600)
    end
})
Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Teleport Y boat using a slider"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.TeleportYSlider = (Value == true)
        __DIO_SeaYSeenT = 0 -- reset moc thay Sea Event: khong dung du lieu cu luc moi bat
    end
})
Tabs.SeaEvent:AddSlider({
    Name = __DIO_T["Fly Boat"],
    Min = 30,
    Max = 500,
    Default = 150,
    Callback = function(Value)
        _G.FlyBoatY = math.clamp(math.floor(tonumber(Value) or 150), 30, 500)
    end
})
Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Will Back When over 10km"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.FindBack10km = (Value == true)
    end
})
Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Auto Repair Ur Ship"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoRepairShip = (Value == true)
    end
})

Tabs.SeaEvent:AddSection("Mystic Island / Full Moon")
local FullMOOn = Tabs.SeaEvent:AddParagraph("FullMoon Status", "")

Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Find Mirage Island"],
Description = "",
Default = false,
Callback = function(Value)
  _G.FindMirage = Value
  -- FIX: truoc day tat Find Mirage khong don tween -> thuyen van bay toi goal cu mai mai
  if not Value then
      StopTween(false)
      __DIO_CurTarget = nil
      if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
      if not __DIO_FindAnyOn() then __DIO_CruiseStop("mirage") end
  end
end})

Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Esp Mirage Island"],
    Description = "",
    Value = false,
    Callback = function(Value)
        MirageIslandESP = Value
        if MirageIslandESP then
            task.spawn(function()
                while MirageIslandESP do
pcall(UpdateIslandMirageESP)
                    __DIO_wait(1)
                end
            end)
        else
            UpdateIslandMirageESP()
        end
    end
})

Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Auto Tween To Mirage Island"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoMysticIsland = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Tween To Highest Point"],
Description = "",
Default = false,
Callback = function(Value)
  _G.HighestMirage = Value
end})

Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Collect Gear"],
Description = "",
Default = false,
Callback = function(Value)
  _G.TPGEAR = Value
end})

Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Change Transparency can see"],
Description = "",
Default = false,
Callback = function(Value)
  _G.can = Value
end})

Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Tween Advanced Fruit Dealer"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Addealer = Value
end})

Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Collect Mirage Chest"],
Description = "",
Default = false,
Callback = function(Value)
  _G.FarmChestM = Value
end})

Tabs.SeaEvent:AddButton({
Name = __DIO_T["Talk With Stone"],
Description = "",
Callback = function()
  replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("RaceV4Progress","Begin")
  replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("RaceV4Progress","Check")
  replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("RaceV4Progress","Teleport")
  replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("RaceV4Progress","Continue")
end})

Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Look At Moon"],
Description = "",
Default = false,
Callback = function(Value)
  LookM = Value
end})

Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Look Moon + Auto V3"],
    Description = "",
    Default = false,
    Callback = function(Value)
        LookMV3 = Value
    end
})
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Sea Event"],
Description = "",
Default = false,
Callback = function(Value)
  _G.SailBoats = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.SailBoats then
      pcall(function()
        -- FIX: dang danh mob sea event -> nho tween lai cho mob loop, tranh 2 tween danh nhau
        if __DIO_SeaCombat() then return end
        -- [DIO-FIX] Co 1 trong 4 Find dang bat -> Auto Sea Event NHUONG toan bo thuyen
        -- (ke ca mua thuyen / ngoi ghe do __DIO_BoatAssist cua Find lo). Day la nguyen
        -- nhan goc cua giat Y 31: truoc day chi chan o nhanh cruise, cac nhanh khac
        -- van chen _tp khac muc tieu vao giua luc Find dang bay.
        if __DIO_FindAnyOn() then return end
        local myBoat = __DIO_MyBoat()
        if not myBoat and not((_G.Shark and CheckShark()) or (_G.TerrorShark and CheckTerrorShark()) or (_G.MobCrew and CheckFishCrew()) or (_G.Piranha and CheckPiranha()))and not((_G.FishBoat and CheckEnemiesBoat()))and not((_G.SeaBeast1 and CheckSeaBeast()))and not(_G.PGB and CheckPirateGrandBrigade())and not(_G.HCM and CheckHauntedCrew())and not(_G.Leviathan1 and CheckLeviathan())then
          local buyBoatCFrame = CFrame.new(-16927.451, 9.086, 433.864)
          TeleportToTarget(buyBoatCFrame)
          local __hrpSE = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
          if __hrpSE and (buyBoatCFrame.Position - __hrpSE.Position).Magnitude <= 10
             and tick() - (__DIO_LastBuyTry or 0) > 4 then
            __DIO_LastBuyTry = tick()
            replicated.Remotes.CommF_:InvokeServer("BuyBoat", (_G.SelectedBoat or "Guardian"))
          end
        elseif myBoat and not((_G.Shark and CheckShark()) or (_G.TerrorShark and CheckTerrorShark()) or (_G.MobCrew and CheckFishCrew()) or (_G.Piranha and CheckPiranha()))and not((_G.FishBoat and CheckEnemiesBoat()))and not((_G.SeaBeast1 and CheckSeaBeast()))and not(_G.PGB and CheckPirateGrandBrigade())and not(_G.HCM and CheckHauntedCrew())and not(_G.Leviathan1 and CheckLeviathan())then
          if plr.Character.Humanoid.Sit == false then
            local __seatV4 = myBoat:FindFirstChild("VehicleSeat")
            if not __seatV4 then
                if tick() - (__DIO_LastRebuy or 0) > 10 then
                    __DIO_LastRebuy = tick()
                    replicated.Remotes.CommF_:InvokeServer("BuyBoat", (_G.SelectedBoat or "Guardian"))
                end
                return
            end
            do
                local __hrpV7 = plr.Character.HumanoidRootPart
                local __spV7 = __seatV4.CFrame.Position
                if (__hrpV7.Position - __spV7).Magnitude <= 8 and __hrpV7.Position.Y >= __spV7.Y - 1 then
                    __DIO_TweenTarget = nil
                    __hrpV7.AssemblyLinearVelocity = Vector3.new(0, -15, 0)
                    return
                end
            end
            local boatSeatCFrame = __seatV4.CFrame * CFrame.new(0, 1, 0)
            _tp(boatSeatCFrame)
          else
            -- [DIO-FIX] Find dang bat thi khong vao cruise Y 31 (phong truong hop Find
            -- duoc bat ngay giua tick nay). Vong cruise ben duoi cung tu thoat khi Find bat.
            if __DIO_FindAnyOn() then return end
            if _G.DangerSc == "Lv 1" then CFrameSelectedZone = CFrame.new(-21998.375, 30.0006084, -682.309143)
            elseif _G.DangerSc == "Lv 2" then CFrameSelectedZone = CFrame.new(-26779.5215, 30.0005474, -822.858032)
            elseif _G.DangerSc == "Lv 3" then CFrameSelectedZone = CFrame.new(-31171.957, 30.0001011, -2256.93774)
            elseif _G.DangerSc == "Lv 4" then CFrameSelectedZone = CFrame.new(-34054.6875, 30.2187767, -2560.12012)
            elseif _G.DangerSc == "Lv 5" then CFrameSelectedZone = CFrame.new(-38887.5547, 30.0004578, -2162.99023)
            elseif _G.DangerSc == "Lv 6" then CFrameSelectedZone = CFrame.new(-44541.7617, 30.0003204, -1244.8584)
            elseif _G.DangerSc == "Lv Infinite" then CFrameSelectedZone = CFrame.new(-10000000, 31, 37016.25)
            end
            CFrameSelectedZone = CFrameSelectedZone or CFrame.new(-44541.7617, 30.0003204, -1244.8584)
            -- [DIO-FIX] Cruise Auto Sea Event giu Y 31 (khong dung Fly Boat/Teleport Y),
            -- nhung THOAT NGAY khi bat Find. Truoc day la repeat...until khong co dieu
            -- kien Find -> _tp Y31 danh nhau 4 lan/giay voi _tp Y slider cua Find
            -- (goal nhay 31 <-> slider lien tuc -> thuyen giat, khong len dung Y).
            -- Dong 'until' cu con goi WaitForChild trong dieu kien + lenh ep Sit=false
            -- dinh cung dong chay trong moi truong hop thoat -> da viet lai sach se:
            -- chi dung day khi THAY MOB, nhuong Find/tat toggle thi giu nguyen ghe.
            local __mobFoundSE = false
            while _G.SailBoats do
              if __DIO_FindAnyOn() then break end
              local __chSE = plr.Character
              local __humSE = __chSE and __chSE:FindFirstChildOfClass("Humanoid")
              if not __humSE or not __humSE.Sit then break end
              local __seaS = __DIO_SeaScan()
              if ((_G.Shark and __seaS.shark) or (_G.TerrorShark and __seaS.terror) or (_G.MobCrew and __seaS.crew) or (_G.Piranha and __seaS.piranha))
                or (_G.SeaBeast1 and CheckSeaBeast()) or (_G.FishBoat and __seaS.fish)
                or (_G.Leviathan1 and CheckLeviathan()) or (_G.HCM and __seaS.crew) or (_G.PGB and __seaS.pgb) then
                __mobFoundSE = true
                break
              end
              _tp(CFrame.new(CFrameSelectedZone.Position.X, 31, CFrameSelectedZone.Position.Z))
              __DIO_wait(0.25)
            end
            if __mobFoundSE then
              pcall(function()
                local __chSE2 = plr.Character
                local __humSE2 = __chSE2 and __chSE2:FindFirstChildOfClass("Humanoid")
                if __humSE2 then __humSE2.Sit = false end
              end)
            end
          end
        end
      end)
    end
  end
end, "L10895")
__DIO_SafeLoop(function()
    local __ccPrev = false
    local __doneBoats = setmetatable({}, {__mode = "k"})
    while __DIO_wait(0.5) do
        pcall(function()
            local __boatsCCV5 = workspace:FindFirstChild("Boats")
            if not __boatsCCV5 or #__boatsCCV5:GetChildren() == 0 then return end
            local __any = _G.SailBoats or _G.Prehis_Find or _G.FindMirage or _G.FrozenDimension or _G.SailBoat_Hydra or _G.AutofindKitIs
            if __any ~= __ccPrev then
                __ccPrev = __any
                __doneBoats = setmetatable({}, {__mode = "k"})
            end
            for a,b in pairs(__boatsCCV5:GetChildren()) do
                if not __doneBoats[b] then
                    for c,d in pairs((__boatsCCV5:FindFirstChild(b.Name) or b):GetDescendants()) do
                        if d:IsA("BasePart") and (__any and d.CanCollide or (not __any and not d.CanCollide)) then
                            d.CanCollide = not __any
                        end
                    end
                    __doneBoats[b] = true
                end
            end
        end)
    end
end, "L10953")
-- [DIO-FIX] Da XOA khoi Y thuyen cu o day (__DIO_FlyBoatY / __DIO_SeaScanAny /
-- __DIO_FindCruiseY ban cu / __DIO_CruiseLiftNow / controller Stepped 240-stud):
--  * __DIO_SeaScanAny cu TINH ca Leviathan la su kien nang Y (sai yeu cau) va quet
--    Enemies 9 lan moi 0.25s. Ban moi dung __DIO_SeaScan co cache + tru Leviathan.
--  * 3 co che cung keo Y (Engine lift + CruiseLiftNow + controller) danh nhau voi
--    vat ly nuoc va voi _tp Y31 cua Auto Sea Event -> giat len/xuong quanh Y 31.
-- He thong moi (1 nguon duy nhat) nam ngay sau __DIO_BoatAssist:
-- __DIO_BoatWantY / __DIO_CruiseFeed / __DIO_CruiseStop + holder du phong,
-- con viec lai Y moi frame do Tween Engine tach truc XZ/Y dam nhan.
__DIO_PlayerNames = function()
    local __out = {}
    for __i, __p in ipairs(__SVC_PLR:GetPlayers()) do
        if __p ~= plr then table.insert(__out, __p.Name) end
    end
    table.sort(__out)
    return __out
end
__DIO_FindBoatOf = function(pname)
    local __boats = workspace:FindFirstChild("Boats")
    if not __boats then return nil end
    for _, __b in ipairs(__boats:GetChildren()) do
        local __okO, __own = pcall(function() return tostring(__b.Owner.Value) end)
        if __okO and __own == tostring(pname) then return __b end
    end
    return nil
end
__DIO_IsDriving = function(pname)
    local __b = __DIO_FindBoatOf(pname)
    if not __b then return false end
    local __p = __SVC_PLR:FindFirstChild(pname)
    if not __p or not __p.Character then return false end
    local __hum = __p.Character:FindFirstChildOfClass("Humanoid")
    local __sp = __hum and __hum.SeatPart
    if __sp and __sp:IsA("VehicleSeat") and __sp:IsDescendantOf(__b) then return true end
    return false
end
__DIO_BoatSeats = function(boat)
    local __t = {}
    for _, __d in ipairs(boat:GetDescendants()) do
        if __d:IsA("Seat") or __d:IsA("VehicleSeat") then table.insert(__t, __d) end
    end
    return __t
end
__DIO_SeatFree = function(seat)
    local __okO, __occ = pcall(function() return seat.Occupant end)
    if not __okO then return false end
    if not __occ then return true end
    local __myCh = plr.Character
    if __myCh and __occ.Parent == __myCh then return true end
    return false
end
__DIO_FriendGateList = function()
    if type(_G.FriendLeviathanList) ~= "table" then return {} end
    return _G.FriendLeviathanList
end
__DIO_OnMyBoatOrNear = function(pname, boat)
    if not boat then return true end
    local __p = __SVC_PLR:FindFirstChild(pname)
    if not __p then return true end
    local __ch = __p.Character
    if not __ch then return false end
    local __hum = __ch:FindFirstChildOfClass("Humanoid")
    if __hum and __hum.SeatPart and __hum.SeatPart:IsDescendantOf(boat) then return true end
    local __hrp = __ch:FindFirstChild("HumanoidRootPart")
    local __okP, __bp = pcall(function() return boat:GetPivot().Position end)
    if __hrp and __okP and (__hrp.Position - __bp).Magnitude <= 5 then return true end
    return false
end
__DIO_AllFriendsAboard = function(myBoat)
    for __i, __name in ipairs(__DIO_FriendGateList()) do
        if not __DIO_OnMyBoatOrNear(__name, myBoat) then return false end
    end
    return true
end
__DIO_SeaPressKey = function(k)
    vim1:SendKeyEvent(true, k, false, game)
    vim1:SendKeyEvent(false, k, false, game)
end
__DIO_SeaSkillOK = {
    ["Melee"]      = {Z = true, X = true, C = true},
    ["Sword"]      = {Z = true, X = true},
    ["Gun"]        = {Z = true, X = true},
    ["Blox Fruit"] = {Z = true, X = true, C = true, V = true, F = true},
}
__DIO_SeaDoSkill = function(w, sk)
    if (__DIO_SeaSkillOK[w] or {})[sk] then
        Useskills(w, sk)
    else
        __DIO_SeaPressKey(sk)
    end
end
__DIO_SeaSkillAtk = function()
    local __wlist = _G.SeaEventWeaponList
    local __slist = _G.SeaEventSkillList
    if __wlist and #__wlist > 0 then
        for _, __w in ipairs(__wlist) do
            weaponSc(__w)
            if __slist and #__slist > 0 then
                for _, __sk in ipairs(__slist) do
                    __DIO_SeaDoSkill(__w, __sk)
                end
            else
                Useskills(__w, "Z")
            end
        end
    elseif CheckF() then
        weaponSc("Blox Fruit") Useskills("Blox Fruit","Z") Useskills("Blox Fruit","X") Useskills("Blox Fruit","C")
    else
        Useskills("Melee","Z") Useskills("Melee","X")
        __DIO_wait(.1) Useskills("Sword","Z") Useskills("Sword","X")
        __DIO_wait(.1) Useskills("Blox Fruit","Z") Useskills("Blox Fruit","X") Useskills("Blox Fruit","C")
        __DIO_wait(.1) Useskills("Gun","Z") Useskills("Gun","X")
    end
end
-- SEA EVENT: chan 2 tween "danh nhau" (FIX lan 2)
-- Bug thuc te: co Sea Beast / Terror Shark -> tween gan thang thuyen den mob, danh 1-2 hit roi
-- tween farm mob nhay khoi thuyen de danh, con tween boat (mover VehicleSeat) thi cu 0.25s
-- lai ep Sit nguoi choi vao ghe -> 2 tween danh nhau lien tuc.
-- Fix theo co che 3nn (AutoSeabeast: y() huy TweenBoat, toTarget khi dang ngoi -> nhay khoi ghe):
--   * Khi co mob sea event: __DIO_SeaCombatBegin() -> huy MOI mover thuyen + roi ghe 1 lan.
--   * Trong luc combat (3s ke tu hit cuoi): Engine.Move(boat) bi tu choi, mover thuyen tu huy,
--     KHONG ep Sit; _tp khi dang ngoi -> roi ghe thay vi tween thuyen.
--   * Moi mob (Shark/Terror/Piranha/Crew/Haunted/SeaBeast/Leviathan/FishBoat/PGB) deu danh
--     bang tween NGUOI CHOI (1 tween duy nhat). Het mob -> Auto Sea Event moi quay ve thuyen.
__DIO_SeaCombatT = 0
__DIO_SeaCombatName = nil
__DIO_SeaCombat = function()
    return (tick() - (__DIO_SeaCombatT or 0)) < 3
end
__DIO_SeaLeaveT = 0
__DIO_SeaLeaveSeat = function()
    local __ch = plr.Character
    local __hum = __ch and __ch:FindFirstChildOfClass("Humanoid")
    local __hrp = __ch and __ch:FindFirstChild("HumanoidRootPart")
    if not __hum or not __hrp then return end
    if not (__hum.Sit or __hum.SeatPart) then return end
    if tick() - (__DIO_SeaLeaveT or 0) < 0.4 then return end
    __DIO_SeaLeaveT = tick()
    pcall(function() __hum.Sit = false end)
    pcall(function() __hum.Jump = true end)
    pcall(function()
        local __sw = __hum.SeatPart and __hum.SeatPart:FindFirstChild("SeatWeld")
        if __sw then __sw:Destroy() end
    end)
    pcall(function() __hrp.CFrame = __hrp.CFrame * CFrame.new(0, 10, 0) end)
end
__DIO_SeaCancelBoatTweens = function()
    local __eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
    if __eng and __eng.Movers and __eng.Stop then
        for __part, __m in pairs(__eng.Movers) do
            if __m and __m.boat and not __m.dead then
                pcall(__eng.Stop, __m, Enum.PlaybackState.Cancelled, "sea combat begin")
            end
        end
    end
    for _, __k in ipairs({ "TweenBoat", "TweenBoatBack" }) do
        local __h = getgenv()[__k]
        if __h and __h.Cancel then pcall(function() __h:Cancel() end) end
        getgenv()[__k] = nil
    end
end
__DIO_SeaCombatBegin = function(flag)
    local __was = __DIO_SeaCombat()
    __DIO_SeaCombatT = tick()
    __DIO_SeaCombatName = flag or __DIO_SeaCombatName
    if not __was then pcall(__DIO_SeaCancelBoatTweens) end
    pcall(__DIO_SeaLeaveSeat)
    shouldTween = true
    if type(__DIO_Move) == "function" then pcall(__DIO_Move) end
end
__DIO_SeaAttackMob = function(mob, flag)
    if not mob or not mob.Parent then return end
    local __rp = mob:FindFirstChild("HumanoidRootPart")
    local __hm = mob:FindFirstChildOfClass("Humanoid")
    if not __rp or not __hm or __hm.Health <= 0 then return end
    local __fname = type(flag) == "string" and flag or nil
    if not __fname then
        local __n = mob.Name
        __fname = (__n == "Terrorshark" and "TerrorShark") or (__n == "Shark" and "Shark") or (__n == "Piranha" and "Piranha")
            or (__n == "Fish Crew Member" and "MobCrew") or (__n == "Haunted Crew Member" and "HCM") or __n
    end
    __DIO_SeaCombatBegin(__fname)
    local __ch = plr.Character
    local __hum = __ch and __ch:FindFirstChildOfClass("Humanoid")
    local __hrp = __ch and __ch:FindFirstChild("HumanoidRootPart")
    if not __hum or not __hrp or __hum.Health <= 0 then return end
    if __hum.Sit or __hum.SeatPart then return end -- vong sau (sau khi roi ghe) moi tween
    if type(Attack) == "table" and type(Attack.KillSea) == "function" then
        pcall(Attack.KillSea, mob, true)
    end
    if (__hrp.Position - __rp.Position).Magnitude <= 350 then
        AitSeaSkill_Custom = __rp.CFrame
        MousePos = AitSeaSkill_Custom.Position
        local __tl = __ch:FindFirstChildOfClass("Tool")
        if not (__tl and __tl.ToolTip == "Gun") then pcall(__DIO_SeaSkillAtk) end
    end
end
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.Shark then local a={"Shark"}if CheckShark()then for b,c in pairs(workspace.Enemies:GetChildren())do if table.find(a,c.Name)then if Attack.Alive(c)then repeat __DIO_wait(Sec) __DIO_SeaAttackMob(c,"Shark")until _G.Shark==false or not c.Parent or c.Humanoid.Health<=0 end end end end end
      if _G.TerrorShark then local a={"Terrorshark"}if CheckTerrorShark()then for b,c in pairs(workspace.Enemies:GetChildren())do if table.find(a,c.Name)then if Attack.Alive(c)then repeat __DIO_wait(0.1) __DIO_SeaAttackMob(c,"TerrorShark")until _G.TerrorShark==false or not c.Parent or c.Humanoid.Health<=0 end end end end end
      if _G.Piranha then local a={"Piranha"}if CheckPiranha()then for b,c in pairs(workspace.Enemies:GetChildren())do if table.find(a,c.Name)then if Attack.Alive(c)then repeat __DIO_wait(Sec) __DIO_SeaAttackMob(c,"Piranha")until _G.Piranha==false or not c.Parent or c.Humanoid.Health<=0 end end end end end
      if _G.MobCrew then local a={"Fish Crew Member"}if CheckFishCrew()then for b,c in pairs(workspace.Enemies:GetChildren())do if table.find(a,c.Name)then if Attack.Alive(c)then repeat __DIO_wait(Sec) __DIO_SeaAttackMob(c,"MobCrew")until _G.MobCrew==false or not c.Parent or c.Humanoid.Health<=0 end end end end end
      if _G.HCM then local a={"Haunted Crew Member"}if CheckHauntedCrew()then for b,c in pairs(workspace.Enemies:GetChildren())do if table.find(a,c.Name)then if Attack.Alive(c)then repeat __DIO_wait(Sec) __DIO_SeaAttackMob(c,"HCM")until _G.HCM==false or not c.Parent or c.Humanoid.Health<=0 end end end end end
      if _G.SeaBeast1 then if workspace:FindFirstChild("SeaBeasts") and workspace.SeaBeasts:FindFirstChild("SeaBeast1")then for a,b in pairs(workspace.SeaBeasts:GetChildren())do if b:FindFirstChild("HumanoidRootPart")and b:FindFirstChild("Health")and b.Health.Value>0 then repeat __DIO_SeaCombatBegin("SeaBeast1") __DIO_wait(0.25)_tp(CFrame.new(b.HumanoidRootPart.Position.X,__DIO_WaterY()+200+((__DIO_SeaDodgeY and __DIO_SeaDodgeY()) or (tonumber(__DIO_BananaSeaDodge) or 0)),b.HumanoidRootPart.Position.Z))if plr:DistanceFromCharacter(b.HumanoidRootPart.CFrame.Position)<=500 then AitSeaSkill_Custom=b.HumanoidRootPart.CFrame;MousePos=AitSeaSkill_Custom.Position;__DIO_SeaSkillAtk() end until _G.SeaBeast1==false or not b:FindFirstChild("HumanoidRootPart")or not b.Parent or b.Health.Value<=0 end end end end
      if _G.Leviathan1 then if workspace:FindFirstChild("SeaBeasts") and workspace.SeaBeasts:FindFirstChild("Leviathan")then for a,b in pairs(workspace.SeaBeasts:GetChildren())do if b:FindFirstChild("HumanoidRootPart")and b:FindFirstChild("Leviathan Segment")and b:FindFirstChild("Health")and b.Health.Value>0 then repeat __DIO_SeaCombatBegin("Leviathan1") __DIO_wait(0.25)_tp(CFrame.new(b.HumanoidRootPart.Position.X,__DIO_WaterY()+200,b.HumanoidRootPart.Position.Z))if plr:DistanceFromCharacter(b.HumanoidRootPart.CFrame.Position)<=500 then MousePos=b:FindFirstChild("Leviathan Segment").Position;__DIO_SeaSkillAtk() end until _G.Leviathan1==false or not b:FindFirstChild("HumanoidRootPart")or not b.Parent or b.Health.Value<=0 end end end end
      if _G.FishBoat then
        if CheckEnemiesBoat() then
            for a,b in pairs(workspace.Enemies:GetChildren()) do
                if b:FindFirstChild("Health") and b.Health.Value > 0 and b:FindFirstChild("VehicleSeat") then
                repeat
                  __DIO_SeaCombatBegin("FishBoat")
                  __DIO_wait(0.25)
                  if b.Name == "FishBoat" then _tp(b.Engine.CFrame * CFrame.new(0,-50,-25)) end
                  if plr:DistanceFromCharacter(b.Engine.CFrame.Position) <= 150 then
                    AitSeaSkill_Custom = b.Engine.CFrame
                    MousePos = AitSeaSkill_Custom.Position
                    __DIO_SeaSkillAtk()
                  end
                until _G.FishBoat == false or not b:FindFirstChild("VehicleSeat") or b.Health.Value <= 0
                end
            end
        end
      end
      if _G.PGB then
        if CheckEnemiesBoat() then
            for a,b in pairs(workspace.Enemies:GetChildren()) do
                if b:FindFirstChild("Health") and b.Health.Value > 0 and b:FindFirstChild("VehicleSeat") then
                repeat
                  __DIO_SeaCombatBegin("PGB")
                  __DIO_wait(0.25)
                  if b.Name == "PirateBrigade" then _tp(b.Engine.CFrame * CFrame.new(0,-30,-10)) elseif b.Name == "PirateGrandBrigade" then _tp(b.Engine.CFrame * CFrame.new(0,-50,-50)) end
                  if plr:DistanceFromCharacter(b.Engine.CFrame.Position) <= 150 then
                    AitSeaSkill_Custom = b.Engine.CFrame
                    MousePos = AitSeaSkill_Custom.Position
                    __DIO_SeaSkillAtk()
                  end
                until _G.PGB == false or not b:FindFirstChild("VehicleSeat") or b.Health.Value <= 0
                end
            end
        end
      end
    end)
  end
end, "L11058")
Tabs.SeaEvent:AddSection("Kitsune Island")
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Find Kitsune Island"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutofindKitIs = Value
  -- FIX: truoc day tat Find Kitsune khong don tween -> thuyen van bay toi goal cu mai mai
  if not Value then
      StopTween(false)
      __DIO_CurTarget = nil
      if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
      if not __DIO_FindAnyOn() then __DIO_CruiseStop("kitsune") end
  end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.AutofindKitIs then
      pcall(function()
        local __wo = workspace:FindFirstChild("_WorldOrigin")
        local __loc = __wo and __wo:FindFirstChild("Locations")
        local __found = __loc and __loc:FindFirstChild("Kitsune Island", true)
        local __foundCF = nil
        if __found then pcall(function() __foundCF = __found.CFrame end) end
        -- FIX: Kitsune Island co the spawn o workspace.Map.KitsuneIsland (giong tab Status dang check).
        -- Truoc day chi tim trong Locations -> Auto Find Kitsune khong bao gio "thay" dao.
        if not __found then
          local __mapK = workspace:FindFirstChild("Map")
          local __mk = __mapK and __mapK:FindFirstChild("KitsuneIsland")
          if __mk then
            __found = __mk
            pcall(function() __foundCF = __mk:GetPivot() end)
            if not __foundCF then
              pcall(function()
                local __pp = __mk.PrimaryPart or __mk:FindFirstChildWhichIsA("BasePart")
                __foundCF = __pp and __pp.CFrame or nil
              end)
            end
          end
        end
        -- FIX: khong fly ra bien quet Kitsune khi Frozen Dimension hoac LeviathanGate da ton tai
        -- (Kitsune khong spawn khi cac event nay dang dien ra -> bay ra bien chi vo ich)
        if not __found then
          local __blockedK = false
          pcall(function()
            if __loc and __loc:FindFirstChild("Frozen Dimension", true) then __blockedK = true return end
            local __mapB = workspace:FindFirstChild("Map")
            if __mapB and __mapB:FindFirstChild("LeviathanGate") then __blockedK = true return end
          end)
          if __blockedK then return end
        end
        if not __found then
          if __DIO_BoatAssist() ~= "sitting" then return end
          local __dest = CFrame.new(-10000000, 31, 37016.25)
          repeat __DIO_wait(0.25)
            local __chR = plr.Character
            local __humR = __chR and __chR:FindFirstChildOfClass("Humanoid")
            local __hrpR = __chR and __chR:FindFirstChild("HumanoidRootPart")
            if not __humR or not __hrpR or not __humR.Sit then break end
            if not _G.AutofindKitIs then break end
            __DIO_NoClipShipNow()
            -- [DIO-FIX] Mot nguon Y duy nhat cho ca 4 Find (Fly Boat / Sea Event Y)
            local __wantYK = __DIO_CruiseFeed("kitsune")
            __dest = __DIO_FindCruiseDest(__wantYK)
            __DIO_CruiseGo("kitsune", __dest)
            __found = __loc and __loc:FindFirstChild("Kitsune Island", true)
            -- FIX: khi dang quet bien ma dao spawn o Map.KitsuneIsland thi nhan luon (dung cho vong ngoai)
            if not __found then
              local __mapR = workspace:FindFirstChild("Map")
              local __mkR = __mapR and __mapR:FindFirstChild("KitsuneIsland")
              if __mkR then
                __found = __mkR
                pcall(function() __foundCF = __mkR:GetPivot() end)
              end
            end
          until not _G.AutofindKitIs or __found or (__dest.Position - __hrpR.Position).Magnitude <= 10 or not __humR.Sit
          if __found or not _G.AutofindKitIs then __DIO_CruiseStop("kitsune") end
          -- [DIO-FIX] Chi roi ghe khi DA thay dao (ly do thoat khac thi giu ngoi, tranh giat ghe)
          if __found then
            pcall(function()
              local __chE = plr.Character
              local __humE = __chE and __chE:FindFirstChildOfClass("Humanoid")
              if __humE then __humE.Sit = false end
            end)
          end
        else
          __DIO_CruiseStop("kitsune")
          -- FIX: da dung tren dao roi thi khong _tp lap lai (tranh giu shouldTween/highlight nong mai)
          if __foundCF then
            local __chK = plr.Character
            local __hrpK = __chK and __chK:FindFirstChild("HumanoidRootPart")
            -- FIX theo yeu cau: thuyen giu im Y 31 (mat nuoc) khi den Kitsune, khong bay len +500 nua
            local __goalK = CFrame.new(__foundCF.Position.X, 31, __foundCF.Position.Z)
            if not __hrpK or (__goalK.Position - __hrpK.Position).Magnitude > 250 then
              _tp(__goalK)
            end
          end
        end
      end)
    end
  end
end, "L11129")
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Teleport to Shrine Actived"],
Description = "",
Default = false,
Callback = function(Value)
  _G.tweenShrine = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.tweenShrine then
      pcall(function()
      local __mapKS = workspace:FindFirstChild("Map")
      local __woKS = workspace:FindFirstChild("_WorldOrigin")
      local __locKS = __woKS and __woKS:FindFirstChild("Locations")
      local __kl = __locKS and __locKS:FindFirstChild("Kitsune Island")
      local kit_is = (__mapKS and __mapKS:FindFirstChild("KitsuneIsland")) or __kl
      if not kit_is then return end
      local shrineActive = kit_is:FindFirstChild("ShrineActive")
        if shrineActive then
          for _, v in next, shrineActive:GetDescendants() do
            if v:IsA("BasePart") and v.Name:find("NeonShrinePart") then
              replicated.Modules.Net:FindFirstChild("RE/TouchKitsuneStatue"):FireServer()
              repeat __DIO_wait(0.25) _tp(v.CFrame * CFrame.new(0,2,0)) until _G.tweenShrine == false or not kit_is
            end
          end
        else
          local __kl2 = kit_is or (__locKS and __locKS:FindFirstChild("Kitsune Island"))
          if __kl2 then _tp(__kl2.CFrame * CFrame.new(0, 500, 0)) end
        end
      end)
    end
  end
end, "L11193")
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Collect Azure Ember"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Collect_Ember = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.Collect_Ember then
      pcall(function()
        local __tpEmber = workspace:FindFirstChild("EmberTemplate")
        local __partEmber = __tpEmber and __tpEmber:FindFirstChild("Part")
        if __partEmber and (workspace:FindFirstChild("AttachedAzureEmber") or __tpEmber) then
          notween(__partEmber.CFrame)
        else
          local __woE2 = workspace:FindFirstChild("_WorldOrigin")
          local __locE2 = __woE2 and __woE2:FindFirstChild("Locations")
          local __kl3 = __locE2 and __locE2:FindFirstChild("Kitsune Island")
          if __kl3 then _tp(__kl3.CFrame * CFrame.new(0, 500, 0)) end
          replicated.Modules.Net["RF/KitsuneStatuePray"]:InvokeServer()
        end
      end)
    end
  end
end, "L11221")
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Trade Azure Ember"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Trade_Ember = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.Trade_Ember then
      pcall(function()
        if workspace["_WorldOrigin"].Locations:FindFirstChild("Kitsune Island",true) then
          replicated.Modules.Net:FindFirstChild("RF/KitsuneStatuePray"):InvokeServer()
        end
      end)
    end
  end
end, "L11243")
Tabs.SeaEvent:AddButton({
Name = __DIO_T["Trade Items Azure"],
Description = "",
Callback = function()
  replicated.Modules.Net:FindFirstChild("RF/KitsuneStatuePray"):InvokeServer()
end})
Tabs.SeaEvent:AddButton({
Name = __DIO_T["Talk with kitsune statue"],
Description = "",
Callback = function()
  replicated.Modules.Net:FindFirstChild("RE/TouchKitsuneStatue"):FireServer()
end})
Tabs.SeaEvent:AddSection("Prehistoric Island")
Tabs.SeaEvent:AddButton({
    Name = __DIO_T["Craft Volcanic Magnet"],
    Callback = function()
        local RF = __SVC_RS.Modules.Net["RF/Craft"]
        RF:InvokeServer(
            "PossibleHardcode",
            "Volcanic Magnet"
        )
    end
})
Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Craft Volcanic Magnet"],
    Default = false,
    Callback = function(Value)
        getgenv().AutoCraftVolcanic = Value
    end
})
Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Auto Find Prehistoric Island"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.Prehis_Find = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
            if not __DIO_FindAnyOn() then __DIO_CruiseStop("prehis") end
        end
    end
})

Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Auto Start Prehistoric Event"],
    Default = false,
    Callback = function(Value)
        _G.AutoStartPrehistoric = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})

Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Auto Patch Prehistoric Event"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.Prehis_Skills = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})

Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Collect Dino Bones"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Prehis_DB = Value
end})

Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Collect Dragon Eggs"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Prehis_DE = Value
end})

Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Reset When Complete Volcano"],
Description = "",
Default = false,
Callback = function(Value)
  _G.ResetPH = Value
end})
Tabs.SeaEvent:AddSection("Frozen Dimension")
local SPYING = Tabs.SeaEvent:AddParagraph("Spy Status", "")
__DIO_SafeLoop(function()
    local __prevSpy = nil
    while __DIO_wait(3) do
        pcall(function()
            if not _G.FrozenDimension then return end
            local spycheck = string.match(tostring(replicated.Remotes.CommF_:InvokeServer("InfoLeviathan", "1")), "%d+")
            if spycheck then
                local __v = "Spy Leviathan : " .. (tonumber(spycheck) == 5 and "Already Done!!" or tostring(spycheck))
                if __v ~= __prevSpy then __prevSpy = __v SPYING:SetDesc(__v) end
            end
        end)
    end
end, "L11272")
Tabs.SeaEvent:AddButton({
    Name = __DIO_T["Buy Spy"],
    Callback = function()
        __SVC_RS.Remotes.CommF_:InvokeServer("InfoLeviathan", "2")
    end
})
__DIO_SelKeyOwner  = "UI/SeaEvent/Owners Boat Hunter"
__DIO_SelKeyFriend = "UI/SeaEvent/Friend Hunter Leviathan"
__DIO_SavedSelList = function(key)
    local __out = {}
    local __saved = GetSetting(key, nil)
    if type(__saved) == "table" then
        for __k, __v in pairs(__saved) do
            if __v == true and type(__k) == "string" then table.insert(__out, __k) end
        end
    elseif type(__saved) == "string" and __saved ~= "" then
        table.insert(__out, __saved)
    end
    table.sort(__out)
    return __out
end
__DIO_SelUpdate = function(Value, gname)
    local __names = __DIO_PlayerNames()
    if #__names == 0 then
        if type(_G[gname]) ~= "table" then _G[gname] = {} end
        pcall(__DIO_TweenDrop)
        return _G[gname]
    end
    _G[gname] = __DIO_SeaNormList(Value, __names)
    pcall(__DIO_TweenDrop)
    return _G[gname]
end
_G.OwnersBoatList = (type(_G.OwnersBoatList) == "table") and _G.OwnersBoatList or __DIO_SavedSelList(__DIO_SelKeyOwner)
_G.FriendLeviathanList = (type(_G.FriendLeviathanList) == "table") and _G.FriendLeviathanList or __DIO_SavedSelList(__DIO_SelKeyFriend)
__DIO_OwnerDrop = Tabs.SeaEvent:AddDropdown({
    Name = __DIO_T["Owners Boat Hunter"],
    Options = __DIO_PlayerNames(),
    Default = _G.OwnersBoatList,
    MultiSelect = true,
    Callback = function(Value)
        __DIO_SelUpdate(Value, "OwnersBoatList")
    end
})
Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Tween To Sitting in a boat Owner"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.TweenBoatOwner = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_FriendDrop = Tabs.SeaEvent:AddDropdown({
    Name = __DIO_T["Friend Hunter Leviathan"],
    Options = __DIO_PlayerNames(),
    Default = _G.FriendLeviathanList,
    MultiSelect = true,
    Callback = function(Value)
        __DIO_SelUpdate(Value, "FriendLeviathanList")
    end
})
__DIO_OwnerSeen, __DIO_FriendSeen = {}, {}
do
    local function __seed(drop, seen)
        local __opts = drop and drop.DROPDOWN_OPTIONS
        if type(__opts) == "table" then
            for __i = 1, #__opts do
                local __o = __opts[__i]
                local __nm = (type(__o) == "table" and __o.Name) or __o
                if type(__nm) == "string" then seen[__nm] = true end
            end
        end
    end
    pcall(__seed, __DIO_OwnerDrop,  __DIO_OwnerSeen)
    pcall(__seed, __DIO_FriendDrop, __DIO_FriendSeen)
end
__DIO_DropHas = function(drop, name)
    if type(drop) ~= "table" then return false end
    local __opts = drop.DROPDOWN_OPTIONS
    if type(__opts) == "table" then
        for __i = 1, #__opts do
            local __o = __opts[__i]
            if type(__o) == "table" and __o.Name == name then return true end
            if __o == name then return true end
        end
    end
    return false
end
__DIO_DropAdd = function(drop, name)
    if type(drop) ~= "table" or type(name) ~= "string" then return false end
    if __DIO_DropHas(drop, name) then return true end
    local __ok = false
    if type(drop.ADD_DROPDOWN_OPTION) == "function" then
        pcall(drop.ADD_DROPDOWN_OPTION, name)
        __ok = __DIO_DropHas(drop, name)
    end
    if not __ok and type(drop.Add) == "function" then
        pcall(drop.Add, drop, name)
        __ok = __DIO_DropHas(drop, name)
    end
    if not __ok and type(drop.ADD_DROPDOWN_OPTION) == "function" then
        pcall(drop.ADD_DROPDOWN_OPTION, { name })
        __ok = __DIO_DropHas(drop, name)
    end
    return __ok
end
__DIO_DropRemove = function(drop, name)
    if type(drop) ~= "table" then return false end
    if type(drop.REMOVE_DROPDOWN_OPTION) == "function" then
        pcall(drop.REMOVE_DROPDOWN_OPTION, name)
    elseif type(drop.Remove) == "function" then
        pcall(drop.Remove, drop, name)
    end
    return not __DIO_DropHas(drop, name)
end
__DIO_SyncPlayerDrop = function(drop, seen)
    if type(drop) ~= "table" then return seen end
    seen = (type(seen) == "table") and seen or {}
    local __names = __DIO_PlayerNames()
    if #__names == 0 then return seen end
    local __now = {}
    for __i = 1, #__names do __now[__names[__i]] = true end
    for __i = 1, #__names do
        local __n = __names[__i]
        if not __DIO_DropHas(drop, __n) then
            __DIO_DropAdd(drop, __n)
        end
    end
    for __n in pairs(seen) do
        if not __now[__n] then
            if __DIO_DropRemove(drop, __n) then __now[__n] = nil end
        end
    end
    local __seen2 = {}
    local __opts = drop.DROPDOWN_OPTIONS
    if type(__opts) == "table" then
        for __i = 1, #__opts do
            local __o = __opts[__i]
            local __nm = (type(__o) == "table" and __o.Name) or __o
            if type(__nm) == "string" then __seen2[__nm] = true end
        end
    else
        __seen2 = __now
    end
    return __seen2
end
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function() __DIO_OwnerSeen  = __DIO_SyncPlayerDrop(__DIO_OwnerDrop,  __DIO_OwnerSeen)  end)
        pcall(function() __DIO_FriendSeen = __DIO_SyncPlayerDrop(__DIO_FriendDrop, __DIO_FriendSeen) end)
    end
end, "SeaPlayerRefresh")
task.delay(6, function()
    pcall(function()
        local __names = __DIO_PlayerNames()
        if #__names == 0 then return end
        for _, __pair in ipairs({ {__DIO_OwnerDrop, "Owner"}, {__DIO_FriendDrop, "Friend"} }) do
            local __drop = __pair[1]
            if type(__drop) == "table" then
                local __cnt = 0
                if type(__drop.DROPDOWN_OPTIONS) == "table" then __cnt = #__drop.DROPDOWN_OPTIONS end
                if __cnt == 0 then
                    warn("[DIO V7] Dropdown " .. __pair[2] .. " trong -> nap lai toan bo player")
                    if type(__drop.CLEAR_DROPDOWN) == "function" then pcall(__drop.CLEAR_DROPDOWN) end
                    for __i = 1, #__names do __DIO_DropAdd(__drop, __names[__i]) end
                end
            end
        end
    end)
end)
task.delay(0.5, function()
    pcall(function() __DIO_OwnerSeen  = __DIO_SyncPlayerDrop(__DIO_OwnerDrop,  __DIO_OwnerSeen)  end)
    pcall(function() __DIO_FriendSeen = __DIO_SyncPlayerDrop(__DIO_FriendDrop, __DIO_FriendSeen) end)
end)
task.delay(3, function()
    pcall(function() __DIO_OwnerSeen  = __DIO_SyncPlayerDrop(__DIO_OwnerDrop,  __DIO_OwnerSeen)  end)
    pcall(function() __DIO_FriendSeen = __DIO_SyncPlayerDrop(__DIO_FriendDrop, __DIO_FriendSeen) end)
end)
__DIO_SafeLoop(function()
    while __DIO_wait(0.5) do
        if _G.TweenBoatOwner then
            pcall(function()
                local __selOwners = type(_G.OwnersBoatList) == "table" and _G.OwnersBoatList or {}
                local __inServer = {}
                for _, __pS in ipairs(__SVC_PLR:GetPlayers()) do __inServer[__pS.Name] = true end
                local __owners = {}
                for __iO, __onO in ipairs(__selOwners) do
                    if type(__onO) == "string" and __inServer[__onO] then __owners[#__owners + 1] = __onO end
                end
                local __myChar = plr.Character
                local __myHrp = __myChar and __myChar:FindFirstChild("HumanoidRootPart")
                local __myHum = __myChar and __myChar:FindFirstChildOfClass("Humanoid")
                if not __myHrp or not __myHum then return end
                if __myHum.Sit and not __DIO_CanPivotBoat(__myHum) then
                    __DIO_TweenDrop()
                    return
                end
                if #__owners == 0 then
                    __DIO_TweenDrop()
                    return
                end
                local __bestBoat, __bestScore = nil, math.huge
                for __i, __on in ipairs(__owners) do
                    local __b = __DIO_FindBoatOf(__on)
                    if __b then
                        local __okP, __bp = pcall(function() return __b:GetPivot().Position end)
                        if __okP and __bp then
                            local __score = (__bp - __myHrp.Position).Magnitude
                            if __DIO_IsDriving(__on) then __score = __score - 10000 end
                            if __score < __bestScore then __bestScore = __score __bestBoat = __b end
                        end
                    end
                end
                if not __bestBoat then
                    __DIO_TweenDrop()
                    return
                end
                local __bestSeat, __bestSeatD = nil, math.huge
                for __j, __st in ipairs(__DIO_BoatSeats(__bestBoat)) do
                    if __DIO_SeatFree(__st) then
                        local __d = (__st.CFrame.Position - __myHrp.Position).Magnitude
                        if __d < __bestSeatD then __bestSeatD = __d __bestSeat = __st end
                    end
                end
                if __bestSeat then
                    _tp(__bestSeat.CFrame * CFrame.new(0, 1, 0))
                    if __bestSeatD <= 8 and __myHum.Sit == false then
                        pcall(function() __bestSeat:Sit(__myHum) end)
                    end
                else
                    local __okP, __bp = pcall(function() return __bestBoat:GetPivot() end)
                    if __okP and __bp then
                        _tp(__bp * CFrame.new(0, 6, 12))
                    end
                end
            end)
        end
    end
end, "TweenBoatOwner")
Tabs.SeaEvent:AddToggle({
    Name = __DIO_T["Auto Find Frozen Dimension"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.FrozenDimension = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
            if not __DIO_FindAnyOn() then __DIO_CruiseStop("frozen") end
        end
    end
})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.FrozenDimension then
      pcall(function()
        local __wo = workspace:FindFirstChild("_WorldOrigin")
        local __loc = __wo and __wo:FindFirstChild("Locations")
        local __found = __loc and __loc:FindFirstChild("Frozen Dimension", true)
        -- FIX: Frozen Dimension / Leviathan con nam o workspace.Map.LeviathanGate (code FrozenTP dung no).
        -- Truoc day chi check Locations -> gate da hien ra ma thuyen van fly cruise mai.
        local __mapF0 = workspace:FindFirstChild("Map")
        local __gate0 = __mapF0 and __mapF0:FindFirstChild("LeviathanGate")
        if not __found and __gate0 then __found = __gate0 end
        if not __found then
          if __DIO_BoatAssist() ~= "sitting" then return end
          local __dest = CFrame.new(-10000000, 31, 37016.25)
          repeat __DIO_wait(0.25)
            local __chR = plr.Character
            local __humR = __chR and __chR:FindFirstChildOfClass("Humanoid")
            local __hrpR = __chR and __chR:FindFirstChild("HumanoidRootPart")
            if not __humR or not __hrpR or not __humR.Sit then break end
            if not _G.FrozenDimension then break end
            __DIO_NoClipShipNow()
            if not __DIO_AllFriendsAboard(__DIO_MyBoat()) then
              __DIO_TweenTarget = nil
              if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
              -- [DIO-FIX] Cho ban len thuyen: dung yen (da huy tween) nhung VAN feed
              -- cruise de holder giu Y slider, khong de thuyen chim xuong Y 31 roi
              -- bay len lai moi lan co nguoi len/xuong ghe (giat Y).
              __DIO_CruiseFeed("frozen")
              continue
            end
            -- [DIO-FIX] Mot nguon Y duy nhat cho ca 4 Find (Fly Boat / Sea Event Y)
            local __wantYF = __DIO_CruiseFeed("frozen")
            __dest = __DIO_FindCruiseDest(__wantYF)
            __DIO_CruiseGo("frozen", __dest)
            __found = __loc and __loc:FindFirstChild("Frozen Dimension", true)
            if not __found and __mapF0 and __mapF0:FindFirstChild("LeviathanGate") then
              __found = __mapF0:FindFirstChild("LeviathanGate")
            end
          until not _G.FrozenDimension or __found or (__dest.Position - __hrpR.Position).Magnitude <= 10 or not __humR.Sit
          if __found or not _G.FrozenDimension then __DIO_CruiseStop("frozen") end
          -- [DIO-FIX] Chi roi ghe khi DA thay Frozen Dimension/gate (ly do khac thi giu ngoi)
          if __found then
            pcall(function()
              local __chE = plr.Character
              local __humE = __chE and __chE:FindFirstChildOfClass("Humanoid")
              if __humE then __humE.Sit = false end
            end)
          end
        else
          __DIO_CruiseStop("frozen")
          local __mapF = workspace:FindFirstChild("Map")
          local __gate = __mapF and __mapF:FindFirstChild("LeviathanGate")
          local __srcF = __gate or __found
          -- lay CFrame dung cho ca BasePart (Locations) lan Model (LeviathanGate)
          local __cfF = nil
          pcall(function()
            local __gc = __srcF:FindFirstChild("Center")
            if __gc and __gc:IsA("BasePart") then __cfF = __gc.CFrame return end
            if type(__srcF.GetPivot) == "function" then __cfF = __srcF:GetPivot() return end
            __cfF = __srcF.CFrame
          end)
          if not __cfF then return end
          -- FIX theo yeu cau: khi da thay Frozen Dimension/LeviathanGate, thuyen giu im Y 31 (mat nuoc),
          -- khong bay len gate+300 nua (truoc day thuyen treo giua troi nhu screenshot).
          local __goalF = CFrame.new(__cfF.Position.X, 31, __cfF.Position.Z)
          -- da dung gan gate roi -> khong tween lap lai
          local __chF = plr.Character
          local __hrpF = __chF and __chF:FindFirstChild("HumanoidRootPart")
          if not __hrpF or (__goalF.Position - __hrpF.Position).Magnitude > 250 then
            _tp(__goalF)
          end
        end
      end)
    end
  end
end, "L11312")
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Teleport Frozen Dimension"],
Description = "",
Default = false,
Callback = function(Value)
  _G.FrozenTP = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.FrozenTP then
      pcall(function()
      if workspace.Map:FindFirstChild("LeviathanGate") then _tp(workspace.Map.LeviathanGate.CFrame) replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("OpenLeviathanGate") end
      end)
    end
  end
end, "L11375")
Tabs.SeaEvent:AddToggle({
 Name = __DIO_T["You Shoot Leviathan Heart"],
 Description = "",
 Default = false,
Callback = function(Value)
   _G.ShotHL = Value
end})
local isRunning = false

__DIO_SafeLoop(function()
    while __DIO_wait(0.5) do
        if _G.ShotHL and not isRunning then
            isRunning = true
            pcall(function()
                local frozen = workspace.Map:FindFirstChild("FrozenHeart")
                if not frozen then __DIO_ShotHLDone = false return end
                local inside = frozen:FindFirstChild("Inside")
                local cube = frozen:FindFirstChild("Cube")
                if not inside or not cube then return end
                if inside:GetAttribute("Harpooned") then
                    if not __DIO_ShotHLDone then
                        __DIO_ShotHLDone = true
                        print("[DIO] Successfully Fire Shoot Heart Leviathan")
                    end
                    __DIO_wait(5)
                    return
                end
                __DIO_ShotHLDone = false
                local boat = getBeastHunter()
                if not boat then return end
                pcall(__DIO_NoClipShipNow, boat)
                local vseat = boat:FindFirstChild("VehicleSeat", true)
                local harpoon = boat:FindFirstChild("Harpoon")
                local hseat = (harpoon and harpoon:FindFirstChild("Seat"))
                    or boat:FindFirstChild("HarpoonSeat", true)
                    or boat:FindFirstChild("Seat", true)
                if not vseat or not hseat then return end
                local char = plr.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hum then return end
                local targetCF = CFrame.new(cube.Position.X, boat.WorldPivot.Y, cube.Position.Z)
                    * CFrame.new(0, 0, 300)
                targetCF = targetCF * CFrame.Angles(0, math.rad(360), 0)
                if (targetCF.Position - vseat.Position).Magnitude > 5 then
                    if hum.SeatPart and hum.SeatPart.Name == "VehicleSeat" then
                        local dist = (targetCF.Position - vseat.Position).Magnitude
                        local tw = nil
                        pcall(function()
                            local __eng = __DIO_TweenEngine or getgenv().__DIO_TweenEngine3nn
                            if __eng and __eng.Move then
                                tw = __eng.Move(vseat, targetCF, 150, { boat = true, key = "TweenBoat", eps = 6 })
                            end
                        end)
                        if not tw then
                            tw = TweenService:Create(vseat,
                                TweenInfo.new(dist / 150, Enum.EasingStyle.Quad),
                                { CFrame = targetCF })
                            tw:Play()
                        end
                        if tw and tw.Completed then tw.Completed:Wait() end
                        __DIO_wait(1)
                        local pp = boat.PrimaryPart
                        if pp then
                            local bp = pp.Position
                            pcall(function()
                                boat:SetPrimaryPartCFrame(CFrame.lookAt(bp,
                                    Vector3.new(inside.Position.X, bp.Y, inside.Position.Z)))
                            end)
                        end
                    else
                        _tp(vseat.CFrame)
                    end
                elseif hum.SeatPart and (hum.SeatPart == hseat
                    or (hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "Harpoon")) then
                    replicated.Remotes.CommF_:InvokeServer("FireHarpoon",
                        0.7853981633974483, 4.4342573293783646E-4,
                        harpoon or hseat or boat, workspace:GetServerTimeNow())
                else
                    _tp(hseat.CFrame)
                end
            end)
            isRunning = false
        end
    end
end, "L11393")
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Drive To Hydra Island"],
Description = "",
Default = false,
Callback = function(Value)
  _G.SailBoat_Hydra = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.SailBoat_Hydra then
      pcall(function()
        if __DIO_BoatAssist() ~= "sitting" then return end
        local __dest = CFrame.new(5433, 35, 290)
        repeat __DIO_wait(0.25)
          local __chH = plr.Character
          local __humH = __chH and __chH:FindFirstChildOfClass("Humanoid")
          local __hrpH = __chH and __chH:FindFirstChild("HumanoidRootPart")
          if not __humH or not __hrpH or not __humH.Sit then break end
          if not _G.SailBoat_Hydra then break end
          __DIO_NoClipShipNow()
          local __seaS = __DIO_SeaScan()
          local __yH = (__seaS.fish or __seaS.pgb or __seaS.terror) and 150 or 35
          _tp(CFrame.new(__dest.Position.X, __yH, __dest.Position.Z))
        until not _G.SailBoat_Hydra or not __humH.Sit or (__dest.Position - __hrpH.Position).Magnitude <= 10
        pcall(function()
          local __chH2 = plr.Character
          local __humH2 = __chH2 and __chH2:FindFirstChildOfClass("Humanoid")
          if __humH2 then __humH2.Sit = false end
        end)
      end)
    end
  end
end, "L11463")
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Auto Attack Leviathan"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Leviathan1 = Value
end})
Tabs.Esp:AddSection("Esp")
function isnil(thing)
    return (thing == nil)
end
local function round(n)
    return math.floor(tonumber(n) + 0.5)
end
Number = math.random(1, 1000000)
local plr = game:GetService('Players').LocalPlayer
local replicated = __SVC_RS
local TeamSelf = plr.Team
EspPly = function()
    for _,v in next, game.Players:GetChildren() do
        pcall(function()
            if not isnil(v.Character) then
                if PlayerEsp then
                    if not isnil(v.Character.Head) and not v.Character.Head:FindFirstChild('NameEsp'..Number) then
                        local bill = Instance.new('BillboardGui',v.Character.Head)
                        bill.Name = 'NameEsp'..Number
                        bill.ExtentsOffset = Vector3.new(0, 1, 0)
                        bill.Size = UDim2.new(1,200,1,30)
                        bill.Adornee = v.Character.Head
                        bill.AlwaysOnTop = true
                        local name = Instance.new('TextLabel',bill)
                        name.Font = Enum.Font.Code
                        name.FontSize = "Size14"
                        name.TextWrapped = true
                        name.Text = (v.Name ..' \n'.. round((plr.Character.Head.Position - v.Character.Head.Position).Magnitude/3) ..' M')
                        name.Size = UDim2.new(1,0,1,0)
                        name.TextYAlignment = 'Top'
                        name.BackgroundTransparency = 1
                        name.TextStrokeTransparency = 0.5
                        if v.Team == TeamSelf then
                            name.TextColor3 = Color3.new(0,0,254)
                        else
                            name.TextColor3 = Color3.new(255,0,0)
                        end
                    else
                        if v.Character.Head:FindFirstChild('NameEsp'..Number) then
                            v.Character.Head['NameEsp'..Number].TextLabel.Text = (v.Name ..' | '.. round((plr.Character.Head.Position - v.Character.Head.Position).Magnitude/3) ..' M\nHealth : ' .. round(v.Character.Humanoid.Health*100/v.Character.Humanoid.MaxHealth) .. '%')
                        end
                    end
                else
                    if v.Character.Head:FindFirstChild('NameEsp'..Number) then
                        v.Character.Head:FindFirstChild('NameEsp'..Number):Destroy()
                    end
                end
            end
        end)
    end
end
LocationEsp = function()
    for _,v in next, workspace["_WorldOrigin"].Locations:GetChildren() do
        pcall(function()
            if IslandESP then
                if (v.Name ~= "Sea") then
                    if not v:FindFirstChild('NameEsp') then
                        local bill = Instance.new('BillboardGui',v)
                        bill.Name = 'NameEsp'
                        bill.ExtentsOffset = Vector3.new(0, 1, 0)
                        bill.Size = UDim2.new(1,200,1,30)
                        bill.Adornee = v
                        bill.AlwaysOnTop = true
                        local name = Instance.new('TextLabel',bill)
                        name.Font = Enum.Font.Code
                        name.FontSize = "Size14"
                        name.TextWrapped = true
                        name.Size = UDim2.new(1,0,1,0)
                        name.TextYAlignment = 'Top'
                        name.BackgroundTransparency = 1
                        name.TextStrokeTransparency = 0.5
                        name.TextColor3 = Color3.fromRGB(98,252,252)
                        name.Text = (v.Name ..'   \n'.. round((plr.Character.Head.Position - v.Position).Magnitude/3) ..' M')
                    else
                        v['NameEsp'].TextLabel.Text = (v.Name ..'   \n'.. round((plr.Character.Head.Position - v.Position).Magnitude/3) ..' M')
                    end
                end
            else
                if v:FindFirstChild('NameEsp') then
                    v:FindFirstChild('NameEsp'):Destroy()
                end
            end
        end)
    end
end
DevEsp = function()
    for i,v in next, workspace:GetChildren() do
        pcall(function()
            if DevilFruitESP then
                if string.find(v.Name, "Fruit") then
                    if not v.Handle:FindFirstChild('NameEsp'..Number) then
                        local bill = Instance.new('BillboardGui',v.Handle)
                        bill.Name = 'NameEsp'..Number
                        bill.ExtentsOffset = Vector3.new(0, 1, 0)
                        bill.Size = UDim2.new(1,200,1,30)
                        bill.Adornee = v.Handle
                        bill.AlwaysOnTop = true
                        local name = Instance.new('TextLabel',bill)
                        name.Font = Enum.Font.Code
                        name.FontSize = "Size14"
                        name.TextWrapped = true
                        name.Size = UDim2.new(1,0,1,0)
                        name.TextYAlignment = 'Top'
                        name.BackgroundTransparency = 1
                        name.TextStrokeTransparency = 0.5
                        name.TextColor3 = Color3.fromRGB(255,255,255)
                        name.Text = (v.Name ..' \n'.. round((plr.Character.Head.Position - v.Handle.Position).Magnitude/3) ..' M')
                    else
                        v.Handle['NameEsp'..Number].TextLabel.Text = ('[' ..v.Name ..']' ..'   \n'.. round((plr.Character.Head.Position - v.Handle.Position).Magnitude/3) ..' M')
                    end
                end
            else
                if v:FindFirstChild('Handle') and v.Handle:FindFirstChild('NameEsp'..Number) then
                    v.Handle:FindFirstChild('NameEsp'..Number):Destroy()
                end
            end
        end)
    end
end
EventIslandEsp = function()
    for i, v in pairs(workspace._WorldOrigin.Locations:GetChildren()) do
        pcall(function()
            if EspEventIsland then
                if (v.Name == "Mirage Island" or v.Name =="Prehistoric Island" or v.Name =="Kitsune Island") then
                    if not v:FindFirstChild("NameEsp") then
                        local bill = Instance.new("BillboardGui", v)
                        bill.Name = "NameEsp"
                        bill.ExtentsOffset = Vector3.new(0, 1, 0)
                        bill.Size = UDim2.new(1, 200, 1, 30)
                        bill.Adornee = v
                        bill.AlwaysOnTop = true
                        local name = Instance.new("TextLabel", bill)
                        name.Font = "Code"
                        name.FontSize = "Size14"
                        name.TextWrapped = true
                        name.Size = UDim2.new(1, 0, 1, 0)
                        name.TextYAlignment = "Top"
                        name.BackgroundTransparency = 1
                        name.TextStrokeTransparency = 0.5
                        name.TextColor3 = Color3.fromRGB(80, 245, 245)
                        name.Text = (v.Name .. "   \n" .. round((plr.Character.Head.Position - v.Position).Magnitude / 3) .. " M")
                    else
                        v.NameEsp.TextLabel.Text = v.Name .. "   \n" .. round((plr.Character.Head.Position - v.Position).Magnitude / 3) .. " M"
                    end
                end
            else
                if v:FindFirstChild("NameEsp") then
                    v:FindFirstChild("NameEsp"):Destroy()
                end
            end
        end)
    end
end
AdvanFruitEsp = function()
    if advanEsp then
        for _,v in pairs(replicated.NPCs:GetChildren()) do
            if v.Name == "Advanced Fruit Dealer" then
                if not workspace:FindFirstChild("Adv") then
                    Adv = Instance.new("Part")
                    Adv.Name = "Adv"
                    Adv.Transparency = 1
                    Adv.Size = Vector3.new(1,1,1)
                    Adv.Anchored = true
                    Adv.CanCollide = false
                    Adv.Parent = workspace
                    Adv.CFrame = v.HumanoidRootPart.CFrame
                elseif workspace:FindFirstChild("Adv") then
                    if not Adv:FindFirstChild("NameEsp") then
                        local bill = Instance.new("BillboardGui", Adv)
                        bill.Name = "NameEsp"
                        bill.ExtentsOffset = Vector3.new(0, 1, 0)
                        bill.Size = UDim2.new(1, 200, 1, 30)
                        bill.Adornee = Adv
                        bill.AlwaysOnTop = true
                        local name = Instance.new("TextLabel", bill)
                        name.Font = "Code"
                        name.FontSize = "Size14"
                        name.TextWrapped = true
                        name.Size = UDim2.new(1, 0, 1, 0)
                        name.TextYAlignment = "Top"
                        name.BackgroundTransparency = 1
                        name.TextStrokeTransparency = 0.5
                        name.TextColor3 = Color3.fromRGB(80, 245, 245)
                        name.Text = (v.Name .."   \n" ..round((plr.Character.Head.Position - v.HumanoidRootPart.Position).Magnitude /3) .." M")
                    else
                        Adv["NameEsp"].TextLabel.Text = (v.Name .."   \n" ..round((plr.Character.Head.Position - v.HumanoidRootPart.Position).Magnitude /3) .." M")
                    end
                end
            end
        end
    else
        if workspace:FindFirstChild("Adv") then
            workspace:FindFirstChild("Adv"):Destroy()
        end
    end
end
HakiClorEsp = function()
    if ColorEsp then
        for _,v in pairs(replicated.NPCs:GetChildren()) do
            if v.Name == "Barista Cousin" then
                if not workspace:FindFirstChild("Gay") then
                    Gay = Instance.new("Part")
                    Gay.Name = "Gay"
                    Gay.Transparency = 1
                    Gay.Size = Vector3.new(1,1,1)
                    Gay.Anchored = true
                    Gay.CanCollide = false
                    Gay.Parent = workspace
                    Gay.CFrame = v.HumanoidRootPart.CFrame
                elseif workspace:FindFirstChild("Gay") then
                    if not Gay:FindFirstChild("NameEsp") then
                        local bill = Instance.new("BillboardGui", Gay)
                        bill.Name = "NameEsp"
                        bill.ExtentsOffset = Vector3.new(0, 1, 0)
                        bill.Size = UDim2.new(1, 200, 1, 30)
                        bill.Adornee = Gay
                        bill.AlwaysOnTop = true
                        local name = Instance.new("TextLabel", bill)
                        name.Font = "Code"
                        name.FontSize = "Size14"
                        name.TextWrapped = true
                        name.Size = UDim2.new(1, 0, 1, 0)
                        name.TextYAlignment = "Top"
                        name.BackgroundTransparency = 1
                        name.TextStrokeTransparency = 0.5
                        name.TextColor3 = Color3.fromRGB(80, 245, 245)
                        name.Text = (v.Name .."   \n" ..round((plr.Character.Head.Position - v.HumanoidRootPart.Position).Magnitude /3) .." M")
                    else
                        Gay["NameEsp"].TextLabel.Text = (v.Name .."   \n" ..round((plr.Character.Head.Position - v.HumanoidRootPart.Position).Magnitude /3) .." M")
                    end
                end
            end
        end
    else
        if workspace:FindFirstChild("Gay") then
            workspace:FindFirstChild("Gay"):Destroy()
        end
    end
end
LegenSword = function()
    if LegenS then
        for _,v in pairs(replicated.NPCs:GetChildren()) do
            if v.Name == "Legendary Sword Dealer" then
                if not workspace:FindFirstChild("Lgd") then
                    Lgd = Instance.new("Part")
                    Lgd.Name = "Lgd"
                    Lgd.Transparency = 1
                    Lgd.Size = Vector3.new(1,1,1)
                    Lgd.Anchored = true
                    Lgd.CanCollide = false
                    Lgd.Parent = workspace
                    Lgd.CFrame = v.HumanoidRootPart.CFrame
                elseif workspace:FindFirstChild("Lgd") then
                    if not Lgd:FindFirstChild("NameEsp") then
                        local bill = Instance.new("BillboardGui", Lgd)
                        bill.Name = "NameEsp"
                        bill.ExtentsOffset = Vector3.new(0, 1, 0)
                        bill.Size = UDim2.new(1, 200, 1, 30)
                        bill.Adornee = Lgd
                        bill.AlwaysOnTop = true
                        local name = Instance.new("TextLabel", bill)
                        name.Font = "Code"
                        name.FontSize = "Size14"
                        name.TextWrapped = true
                        name.Size = UDim2.new(1, 0, 1, 0)
                        name.TextYAlignment = "Top"
                        name.BackgroundTransparency = 1
                        name.TextStrokeTransparency = 0.5
                        name.TextColor3 = Color3.fromRGB(80, 245, 245)
                        name.Text = (v.Name .."   \n" ..round((plr.Character.Head.Position - v.HumanoidRootPart.Position).Magnitude /3) .." M")
                    else
                        Lgd["NameEsp"].TextLabel.Text = (v.Name .."   \n" ..round((plr.Character.Head.Position - v.HumanoidRootPart.Position).Magnitude /3) .." M")
                    end
                end
            end
        end
    else
        if workspace:FindFirstChild("Lgd") then
            workspace:FindFirstChild("Lgd"):Destroy()
        end
    end
end
ChestEsp = function()
    if ChestESP then
        local CollectionService = __SVC_CS
        local Chests = CollectionService:GetTagged("_ChestTagged")
        for _, Chest in ipairs(Chests) do
            pcall(function()
                local chestPos = Chest:GetPivot().Position
                local distanceMagnitude = (chestPos - plr.Character.Head.Position).Magnitude
                local existingEsp = Chest:FindFirstChild("ChestEspAttachment")
                if not existingEsp then
                    local attachment = Instance.new("Attachment")
                    attachment.Name = "ChestEspAttachment"
                    attachment.Parent = Chest
                    attachment.Position = Vector3.new(0, 3, 0)
                    local nameEsp = Instance.new("BillboardGui")
                    nameEsp.Name = "NameEsp"
                    nameEsp.Size = UDim2.new(0, 200, 0, 30)
                    nameEsp.Adornee = attachment
                    nameEsp.ExtentsOffset = Vector3.new(0, 1, 0)
                    nameEsp.AlwaysOnTop = true
                    nameEsp.Parent = attachment
                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Font = Enum.Font.Code
                    nameLabel.TextSize = 14
                    nameLabel.TextWrapped = true
                    nameLabel.Size = UDim2.new(1, 0, 1, 0)
                    nameLabel.TextYAlignment = Enum.TextYAlignment.Top
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.TextStrokeTransparency = 0.5
                    nameLabel.TextColor3 = Color3.fromRGB(80, 245, 245)
                    nameLabel.Parent = nameEsp
                end
                local nameEsp = existingEsp and existingEsp:FindFirstChild("NameEsp")
                if nameEsp then
                    local displayDistance = math.floor(distanceMagnitude / 3)
                    local chestName = Chest.Name:gsub("Label", "")
                    nameEsp.TextLabel.Text = string.format("[%s] %d M", chestName, displayDistance)
                end
            end)
        end
    else
        for _, Chest in ipairs(__SVC_CS:GetTagged("_ChestTagged")) do
            local espAttachment = Chest:FindFirstChild("ChestEspAttachment")
            if espAttachment then
                espAttachment:Destroy()
            end
        end
    end
end
Tabs.Esp:AddToggle({
    Name = __DIO_T["Esp Player"],
    Description = "",
    Default = false,
    Callback = function(Value)
        PlayerEsp = Value
        if not Value then
            for _,v in next, game.Players:GetChildren() do
                pcall(function()
                    if not isnil(v.Character) and not isnil(v.Character.Head) then
                        if v.Character.Head:FindFirstChild('NameEsp'..Number) then
                            v.Character.Head:FindFirstChild('NameEsp'..Number):Destroy()
                        end
                    end
                end)
            end
        else
            task.spawn(function()
                while PlayerEsp do
pcall(EspPly)
                    __DIO_wait(0.4)
                end
            end)
        end
    end
})
Tabs.Esp:AddToggle({
    Name = __DIO_T["Esp Chest"],
    Description = "",
    Default = false,
    Callback = function(Value)
        ChestESP = Value
        if not Value then
            for _, Chest in ipairs(__SVC_CS:GetTagged("_ChestTagged")) do
                local espAttachment = Chest:FindFirstChild("ChestEspAttachment")
                if espAttachment then
                    espAttachment:Destroy()
                end
            end
        else
            task.spawn(function()
                while ChestESP do
pcall(ChestEsp)
                    __DIO_wait(0.4)
                end
            end)
        end
    end
})
Tabs.Esp:AddToggle({
    Name = __DIO_T["Esp Fruit"],
    Description = "",
    Default = false,
    Callback = function(Value)
        DevilFruitESP = Value
        if not Value then
            for i,v in next, workspace:GetChildren() do
                pcall(function()
                    if v:FindFirstChild('Handle') and v.Handle:FindFirstChild('NameEsp'..Number) then
                        v.Handle:FindFirstChild('NameEsp'..Number):Destroy()
                    end
                end)
            end
        else
            task.spawn(function()
                while DevilFruitESP do
pcall(DevEsp)
                    __DIO_wait(0.4)
                end
            end)
        end
    end
})
Tabs.Esp:AddToggle({
    Name = __DIO_T["Esp Island"],
    Description = "",
    Default = false,
    Callback = function(Value)
        IslandESP = Value
        if not Value then
            for _,v in next, workspace["_WorldOrigin"].Locations:GetChildren() do
                pcall(function()
                    if v:FindFirstChild('NameEsp') then
                        v:FindFirstChild('NameEsp'):Destroy()
                    end
                end)
            end
        else
            task.spawn(function()
                while IslandESP do
pcall(LocationEsp)
                    __DIO_wait(0.4)
                end
            end)
        end
    end
})
Tabs.Esp:AddToggle({
    Name = __DIO_T["Esp Legendary Sword"],
    Description = "",
    Default = false,
    Callback = function(Value)
        LegenS = Value
        if not Value then
            if workspace:FindFirstChild("Lgd") then
                workspace:FindFirstChild("Lgd"):Destroy()
            end
        else
            task.spawn(function()
                while LegenS do
pcall(LegenSword)
                    __DIO_wait(0.4)
                end
            end)
        end
    end
})
Tabs.Esp:AddToggle({
    Name = __DIO_T["Esp Haki Color"],
    Description = "",
    Default = false,
    Callback = function(Value)
        ColorEsp = Value
        if not Value then
            if workspace:FindFirstChild("Gay") then
                workspace:FindFirstChild("Gay"):Destroy()
            end
        else
            task.spawn(function()
                while ColorEsp do
pcall(HakiClorEsp)
                    __DIO_wait(0.4)
                end
            end)
        end
    end
})
Tabs.Esp:AddToggle({
    Name = __DIO_T["Esp SeaEvent Island"],
    Description = "",
    Default = false,
    Callback = function(Value)
        EspEventIsland = Value
        if not Value then
            local __woE = workspace:FindFirstChild("_WorldOrigin")
            local __locE = __woE and __woE:FindFirstChild("Locations")
            for i, v in pairs(__locE and __locE:GetChildren() or {}) do
                pcall(function()
                    if v:FindFirstChild("NameEsp") then
                        v:FindFirstChild("NameEsp"):Destroy()
                    end
                end)
            end
        else
            task.spawn(function()
                while EspEventIsland do
pcall(EventIslandEsp)
                    __DIO_wait(0.4)
                end
            end)
        end
    end
})
Tabs.Esp:AddToggle({
    Name = __DIO_T["Esp Advanced Dealer"],
    Description = "",
    Default = false,
    Callback = function(Value)
        advanEsp = Value
        if not Value then
            if workspace:FindFirstChild("Adv") then
                workspace:FindFirstChild("Adv"):Destroy()
            end
        else
            task.spawn(function()
                while advanEsp do
pcall(AdvanFruitEsp)
                    __DIO_wait(0.4)
                end
            end)
        end
    end
})
Tabs.Raids:AddSection("Fruits Function")
local function formatNumber(number)
    local str = tostring(number)
    repeat
        local replaced, count = str:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        str = replaced
    until count == 0
    return str
end
local function getFruitStock()
    local resultStr = "Advance Fruit Stock\n"
    local success, advanceFruits = pcall(function()
        return __SVC_RS.Remotes.CommF_:InvokeServer("GetFruits", true)
    end)
    if not success or not advanceFruits then
        resultStr = resultStr .. "- Error while retrieving data.\n"
    else
        local hasFruit = false
        for _, fruit in pairs(advanceFruits) do
            if fruit.OnSale then
                hasFruit = true
                resultStr = resultStr .. fruit.Name .. " - $" .. formatNumber(fruit.Price) .. "\n"
            end
        end
        if not hasFruit then
            resultStr = resultStr .. "- No fruit.\n"
        end
    end
    resultStr = resultStr .. "\nNormal Fruit Stock\n"
    local success2, normalFruits = pcall(function()
        return __SVC_RS.Remotes.CommF_:InvokeServer("GetFruits")
    end)
    if success2 and normalFruits then
        local hasFruit = false
        for _, fruit in pairs(normalFruits) do
            if fruit.OnSale then
                hasFruit = true
                resultStr = resultStr .. fruit.Name .. " - $" .. formatNumber(fruit.Price) .. "\n"
            end
        end
        if not hasFruit then
            resultStr = resultStr .. "- No fruit.\n"
        end
    else
        resultStr = resultStr .. "- Error while retrieving data.\n"
    end
    return resultStr
end
local stockParagraph = Tabs.Raids:AddParagraph("Stock Fruit", "Loading...")
__DIO_SafeLoop(function()
    while __DIO_wait(60) do
        pcall(function()
            stockParagraph:SetDesc(getFruitStock())
        end)
    end
end, "L12114")
pcall(function()
    stockParagraph:SetDesc(getFruitStock())
end)
Tabs.Raids:AddToggle({
Name = __DIO_T["Auto Random Fruit"],
Description = "Drop FPS If you keep turning on the function",
Default = false,
Callback = function(Value)
  _G.Random_Auto = (Value == true)
end})
__DIO_GACHA_NAME  = "ZiolesGacha"
__DIO_GachaBusy   = false
__DIO_GachaRollOnce = function()

    if __DIO_GachaBusy then return false end
    __DIO_GachaBusy = true
    task.spawn(function()
        pcall(function()
            game:GetService("ReplicatedStorage").Modules.Net["RF/GachaNetworkRF"]:InvokeServer({ Context = "Purchase", BoxName = __DIO_GACHA_NAME })
        end)
        __DIO_wait(1.5)
        __DIO_GachaBusy = false
    end)
    return true
end
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.Random_Auto then __DIO_GachaRollOnce() end
    end)
  end
end, "L12309")
Tabs.Raids:AddToggle({
Name = __DIO_T["Auto Drop Fruit"],
Description = "",
Default = false,
Callback = function(Value)
  _G.DropFruit = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.DropFruit then
      pcall(function() DropFruits() end)
    end
  end
end, "L12323")
Tabs.Raids:AddToggle({
Name = __DIO_T["Auto Store Fruit"],
Description = "",
Default = false,
Callback = function(Value)
  _G.StoreF = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.StoreF then
      pcall(function() UpdStFruit() end)
    end
  end
end, "L12337")
Tabs.Raids:AddToggle({
Name = __DIO_T["Auto Tween to Fruit"],
Description = "",
Default = false,
Callback = function(Value)
  _G.TwFruits = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.TwFruits then
      pcall(function()
        for _,x1 in pairs(workspace:GetChildren()) do
	    if x1:IsA("Model") then local __hF = x1:FindFirstChild("Handle"); if __hF then _tp(__hF.CFrame) end end
	    end
      end)
    end
  end
end, "L12351")
Tabs.Raids:AddToggle({
Name = __DIO_T["Auto Collect Fruit"],
Description = "",
Default = false,
Callback = function(Value)
  _G.InstanceF = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.InstanceF then
      pcall(function() collectFruits(_G.InstanceF) end)
    end
  end
end, "L12369")
Tabs.Raids:AddDropdown({
    Name = __DIO_T["Select Fruit Shop"],
    Options = {
        "Rocket-Rocket", "Spin-Spin", "Blade-Blade", "Spring-Spring",
        "Bomb-Bomb", "Smoke-Smoke", "Spike-Spike", "Flame-Flame",
        "Ice-Ice", "Sand-Sand", "Dark-Dark", "Eagle-Eagle",
        "Diamond-Diamond", "Light-Light", "Rubber-Rubber", "Ghost-Ghost",
        "Magma-Magma", "Quake-Quake", "Buddha-Buddha", "Love-Love",
        "Creation-Creation", "Spider-Spider", "Sound-Sound", "Phoenix-Phoenix",
        "Portal-Portal", "Lightning-Lightning", "Pain-Pain", "Blizzard-Blizzard",
        "Gravity-Gravity", "T-Rex-T-Rex", "Mammoth-Mammoth", "Dough-Dough",
        "Shadow-Shadow", "Venom-Venom", "Gas-Gas", "Control-Control",
        "Spirit-Spirit", "Leopard-Leopard", "Yeti-Yeti", "Kitsune-Kitsune",
        "Dragon-Dragon"
    },
    Callback = function(Value)
        getgenv().SelectFruit = Value
    end
})
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Buy Fruit Shop"],
    Default = false,
    Callback = function(Value)
        getgenv().AutoBuyFruitSniper = Value
    end
})
spawn(function()
    pcall(function()
        while __DIO_wait(1) do
            if getgenv().AutoBuyFruitSniper then
                __SVC_RS.Remotes.CommF_:InvokeServer("GetFruits")
                __SVC_RS.Remotes.CommF_:InvokeServer("PurchaseRawFruit", getgenv().SelectFruit)
            end
        end
    end)
end)

__RAID_Sea2 = (game.PlaceId == 4442272183 or game.PlaceId == 79091703265657)
__RAID_Sea3 = (game.PlaceId == 7449423635 or game.PlaceId == 100117331123089)
__RAID_IsMobAlive = function(K)
    if K and K.Parent and K:FindFirstChild("HumanoidRootPart")
        and K:FindFirstChildWhichIsA("Humanoid") and K.Humanoid.Health > 0 then
        return true
    end
end
__RAID_SizePart = function(E)
    if not E or not E.Parent or not E:FindFirstChild("HumanoidRootPart") then return end
    if plr:DistanceFromCharacter(E.HumanoidRootPart.Position) <= 50 then
        for _, P in next, E:GetDescendants() do
            if (P:IsA("Part") or P:IsA("MeshPart")) and P.CanCollide then P.CanCollide = false end
        end
    end
end
__RAID_DeleteIgnored = function()
    local en = __SVC_WS:FindFirstChild("Enemies")
    if not en then return end
    for _, Q in pairs(en:GetChildren()) do
        if Q:IsA("Model") and Q:FindFirstChild("Ignored") then Q.Ignored:Destroy() end
    end
end
__RAID_IsNetOwner = function(Q)
    local ch = __SVC_WS:FindFirstChild("Characters")
    if ch then
        for _, o in next, ch:GetChildren() do
            if o.Name ~= plr.Name and o:FindFirstChild("HumanoidRootPart")
                and (o.HumanoidRootPart.Position - Q.Position).Magnitude <= 300 then
                return false
            end
        end
    end
    return true
end
__RAID_Equip = function(g)
    local bp = plr:FindFirstChild("Backpack")
    local ch = plr.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if g and bp and bp:FindFirstChild(g) and hum and not hum.Sit then
        hum:EquipTool(bp:FindFirstChild(g))
    end
end
__RAID_ToolName = function(g)
    local function scan(E)
        for _, T in next, E:GetChildren() do
            if T:IsA("Tool") and T.ToolTip == g then return T.Name end
        end
    end
    local bp = plr:FindFirstChild("Backpack")
    return (bp and scan(bp)) or (plr.Character and scan(plr.Character))
end
__RAID_HasItem = function(E)
    local ch = plr.Character
    local bp = plr:FindFirstChild("Backpack")
    if (ch and ch:FindFirstChild(E)) or (bp and bp:FindFirstChild(E)) then return true end
end
__RAID_CheckBoss = function(Q)
    for _, o in next, __SVC_RS:GetChildren() do
        if (type(Q) == "table" and table.find(Q, o.Name) or o.Name == Q) and __RAID_IsMobAlive(o) then return o end
    end
    local en = __SVC_WS:FindFirstChild("Enemies")
    if en then
        for _, o in next, en:GetChildren() do
            if (type(Q) == "table" and table.find(Q, o.Name) or o.Name == Q) and __RAID_IsMobAlive(o) then return o end
        end
    end
end
__RAID_FruitPath = function()
    for _, H in next, __SVC_WS:GetChildren() do
        if (H:IsA("Tool") or H:IsA("Model")) and string.find(H.Name, "Fruit") and H:FindFirstChild("Handle") then
            return H
        end
    end
end
__RAID_FruitOnChar = function()
    local f
    local bp = plr:FindFirstChild("Backpack")
    if bp then for _, V in pairs(bp:GetChildren()) do f = (string.find(V.Name, "Fruit") and V.Name or f) end end
    local ch = plr.Character
    if ch then for _, V in pairs(ch:GetChildren()) do f = (string.find(V.Name, "Fruit") and V.Name or f) end end
    return f
end
__RAID_FruitPrice = {}
pcall(function()
    for _, g in next, __SVC_RS.Remotes.CommF_:InvokeServer("GetFruits", false) do
        if g.Price >= 1000000 then __RAID_FruitPrice[g.Name] = g.Price end
    end
    __RAID_FruitPrice["Dragon (East)-Dragon (East)"] = 15000000
    __RAID_FruitPrice["Dragon (West)-Dragon (West)"] = 15000000
end)
__RAID_InvList = function()
    local C = {}
    local ok, IRS = pcall(function() return require(__SVC_RS:WaitForChild("ItemReplicationService", 10)) end)
    local ok2, IC = pcall(function() return require(__SVC_RS:WaitForChild("ItemConfig", 10)) end)
    if not (ok and ok2 and IRS and IC) then return C end
    local ok3, items = pcall(function() return IRS:GetItems(IRS.KEYS.QUANTITY) end)
    if not (ok3 and type(items) == "table") then return C end
    for _, F in pairs(items) do
        if F.Value and F.Value > 0 then
            local q, c = pcall(function() return IC.match(F.ItemId):unwrap() end)
            if q and c and c.Display then
                local H = c.Display.Category
                local sk = c.Index and c.Index.StorageKey
                local D = (H == "Blox Fruit") and (sk or c.Display.Name or "ItemId_" .. tostring(F.ItemId))
                    or (c.Display.Name or sk or "ItemId_" .. tostring(F.ItemId))
                table.insert(C, { Name = D, Type = H, Count = F.Value })
            end
        end
    end
    return C
end
__RAID_TakeCheapFruit = function()
    for _, F in next, __RAID_InvList() do
        if F.Type == "Blox Fruit" and not __RAID_FruitPrice[F.Name] then return F.Name end
    end
end
__RAID_MobRaid = function()
    local en = __SVC_WS:FindFirstChild("Enemies")
    if not en then return nil end
    for _, b in ipairs(en:GetChildren()) do
        if __RAID_IsMobAlive(b) and plr:DistanceFromCharacter(b.HumanoidRootPart.Position) <= 400 then
            return b
        end
    end
end
__RAID_BringAnchorM, __RAID_BringAnchorCF, __RAID_BringBusy = nil, nil, false
__RAID_BringRaid = function(b)
    if BringEnemyFarm == false then return end
    if b and __RAID_BringAnchorM ~= b then
        __RAID_BringAnchorM = b
        __RAID_BringAnchorCF = b.HumanoidRootPart.CFrame
        __RAID_DeleteIgnored()
    end
    if __RAID_BringBusy then
        delay(0.1, function() __RAID_BringBusy = false end)
        return
    end
    local E = {}
    if not b:FindFirstChild("Ignored") then table.insert(E, b) end
    for _, y in pairs(__SVC_WS.Enemies:GetChildren()) do
        if y ~= b and y.Name == b.Name and not y:FindFirstChild("Ignored")
            and __RAID_IsMobAlive(y) and __RAID_IsNetOwner(y.HumanoidRootPart) then
            if (y.HumanoidRootPart.Position - __RAID_BringAnchorCF.Position).Magnitude <= 200 and #E < 1 then
                table.insert(E, y)
            end
        end
    end
    local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if __RAID_BringAnchorCF and hrp
        and (hrp.Position - b.HumanoidRootPart.Position).Magnitude <= 50
        and __RAID_IsNetOwner(hrp) then
        for _, m in pairs(E) do
            __RAID_SizePart(m)
            m.HumanoidRootPart.CFrame = __RAID_BringAnchorCF * CFrame.new(0, math.random(0, 2), math.random(0, 2))
            task.spawn(function()
                local hp = m.Humanoid.Health
                task.wait(3.5)
                if m.Parent and m.Humanoid.Health == hp and not m:FindFirstChild("Ignored") then
                    m.HumanoidRootPart.CFrame = m.WorldPivot
                    local ig = Instance.new("IntValue") ig.Name = "Ignored" ig.Parent = m
                    task.wait(0.3)
                end
            end)
            __RAID_BringBusy = true
        end
    end
end
__RAID_RaidLoc = function()
    local wo = __SVC_WS:FindFirstChild("_WorldOrigin")
    return wo and wo:FindFirstChild("Locations")
end
__RAID_LastIsland = function()
    local b, E = 0, nil
    local loc = __RAID_RaidLoc()
    if not loc then return nil end
    for _, y in ipairs(loc:GetChildren()) do
        if string.find(y.Name, "Island ") and plr:DistanceFromCharacter(y.Position) < 3000 then
            local n = tonumber((y.Name:gsub("Island ", "")))
            if n and b < n then b, E = n, y end
        end
    end
    return E
end
__RAID_InRaid = function()
    local loc = __RAID_RaidLoc()
    if not loc then return nil end
    for _, b in ipairs(loc:GetChildren()) do
        if string.find(b.Name, "Island ") and plr:DistanceFromCharacter(b.Position) < 3000 then
            return true
        end
    end
end
__RAID_BuyChip, __RAID_WaitGo, __RAID_TickCastle = true, false, 0
__RAID_CancelTween = function()
    StopTween(false)
    __DIO_CurTarget = nil
    if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
end
__RAID_RaidList = {}
pcall(function()
    local s = require(__SVC_RS:WaitForChild("Raids", 10))

    local __seen = {}
    for _, y in next, s do
        if type(y) == "table" then
            for _, b in next, y do
                if type(b) == "string" and not __seen[b] then
                    __seen[b] = true
                    table.insert(__RAID_RaidList, b)
                end
            end
        end
    end
    table.sort(__RAID_RaidList)
end)
if #__RAID_RaidList == 0 then __RAID_RaidList = { "Flame" } end
__RAID_NormMulti = function(Value, opts)
    local raw = {}
    if type(Value) == "table" then
        for k, v in pairs(Value) do
            if v == true then
                if type(k) == "string" and table.find(opts, k) then table.insert(raw, k)
                elseif type(k) == "number" and table.find(opts, Value[k]) then table.insert(raw, Value[k]) end
            end
        end
    elseif type(Value) == "string" and table.find(opts, Value) then
        table.insert(raw, Value)
    end
    local out = {}
    for _, o in ipairs(opts) do if table.find(raw, o) then table.insert(out, o) end end
    return out
end

Tabs.Raids:AddSection("Raids")
_G.SelectWeaponRaid = "Melee"
Tabs.Raids:AddDropdown({
    Name = __DIO_T["Select Weapon Raid"],
    Description = "",
    Options = { "Melee", "Sword", "Blox Fruit", "Gun" },
    Default = "Melee",
    Callback = function(Value)
        _G.SelectWeaponRaid = Value or "Melee"
    end
})
_G.SelectRaid = "Flame"
Tabs.Raids:AddDropdown({
    Name = __DIO_T["Select Raid"],
    Description = "",
    Options = __RAID_RaidList,
    Default = "Flame",
    Callback = function(Value)
        _G.SelectRaid = Value
    end
})
_G.GetFruitLowBeli = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Get Fruit In Inventory Low Beli"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.GetFruitLowBeli = (Value == true)
    end
})
_G.AutoRaid = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Raid"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoRaid = (Value == true)
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait() do
        if _G.AutoRaid or _G.Raiding then
            local _, err = pcall(function()
                local ch0 = plr.Character
                if not ch0 or not ch0:FindFirstChild("HumanoidRootPart") then return end
                local flag = (_G.AutoRaid or _G.Raiding)
                local summon
                if __RAID_Sea2 then
                    local ci = __SVC_WS.Map:FindFirstChild("CircleIsland")
                    local rs = ci and ci:FindFirstChild("RaidSummon2")
                    local btn = rs and rs:FindFirstChild("Button")
                    summon = btn and btn:FindFirstChild("Main")
                elseif __RAID_Sea3 then
                    local bc = __SVC_WS.Map:FindFirstChild("Boat Castle")
                    local rs = bc and bc:FindFirstChild("RaidSummon2")
                    local btn = rs and rs:FindFirstChild("Button")
                    summon = btn and btn:FindFirstChild("Main")
                end
                local hud = plr.PlayerGui:FindFirstChild("Main")
                hud = hud and hud:FindFirstChild("TopHUDList")
                local timer = hud and hud:FindFirstChild("RaidTimer")
                local timerOn = timer and timer.Visible
                if not timerOn and not __RAID_InRaid() then
                    if __RAID_TickCastle and tick() - __RAID_TickCastle < 5 then return end
                    if not summon then
                        _tp(CFrame.new(-5500, 314, -2855))
                        return
                    end
                end
                if __RAID_HasItem("Special Microchip") then
                    if __RAID_WaitGo then
                        __DIO_wait(5)
                        __RAID_WaitGo = false
                    end
                    __RAID_BuyChip = false
                    if summon then
                        local cd = summon:FindFirstChild("ClickDetector")
                        if cd then fireclickdetector(cd) end
                    end
                    __RAID_TickCastle = tick()
                    __RAID_CancelTween()
                    return
                end
                if timerOn and __RAID_InRaid() then
                    __RAID_WaitGo = true
                    __RAID_BuyChip = true
                    local l = __RAID_MobRaid()
                    if l then
                        repeat
                            __DIO_wait()
                            __RAID_Equip(__RAID_ToolName(_G.SelectWeaponRaid or "Melee"))
                            Attack.Kill(l, flag)
                            __RAID_SizePart(l)
                            __RAID_BringRaid(l)
                            if (_G.SelectWeaponRaid or "Melee") == "Blox Fruit" then
                                _tp(l.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
                            else
                                _tp(l.HumanoidRootPart.CFrame * CFrame.new(10, 20, 0))
                            end
                        until not __RAID_IsMobAlive(l) or (not _G.AutoRaid and not _G.Raiding)
                    else
                        local y = __RAID_LastIsland()
                        if y then
                            if y.Name == "Island 2" and (_G.SelectRaid or _G.SelectChip) == "Phoenix" then
                                _tp(y.CFrame * CFrame.new(300, 60, 0))
                            else
                                _tp(y.CFrame * CFrame.new(0, 60, 0))
                            end
                        end
                    end
                    return
                end
                if __RAID_BuyChip and plr.Data.Level.Value >= 1100
                    and not timerOn and not __RAID_HasItem("Special Microchip") and not __RAID_InRaid() then
                    if _G.HopSeverRaid then
                        local fr = __RAID_FruitPath()
                        if fr then
                            if not ((fr.Handle.Position - ch0.HumanoidRootPart.Position).Magnitude <= 5) then
                                _tp(fr.Handle.CFrame)
                            end
                            return
                        elseif not __RAID_FruitOnChar() then
                            Hop()
                            __DIO_wait(5)
                            return
                        end
                    end
                    if not __RAID_FruitOnChar() and __RAID_TakeCheapFruit() and _G.GetFruitLowBeli then
                        __SVC_RS.Remotes.CommF_:InvokeServer("LoadFruit", __RAID_TakeCheapFruit())
                    end
                    __SVC_RS.Remotes.CommF_:InvokeServer("RaidsNpc", "Check")
                    __SVC_RS.Remotes.CommF_:InvokeServer("RaidsNpc", "Select",
                        _G.SelectRaid or _G.SelectChip or "Flame")
                    __DIO_wait(1)
                end
            end)
            if err then print(err) end
        end
    end
end, "L-RAID")
_G.HopSeverRaid = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Hop Sever Raid"],
    Description = "",
    Default = false,
    Callback = function(Value)
        if Value and not _G.AutoRaid then print("[DIO] Turn On Auto Raid Plz") end
        _G.HopSeverRaid = (Value == true)
    end
})
_G.AutoAwakeFruit = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Awake Fruit"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoAwakeFruit = (Value == true)
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoAwakeFruit or _G.Auto_Awakener then
            pcall(function()
                __SVC_RS.Remotes.CommF_:InvokeServer("Awakener", "Check")
                __SVC_RS.Remotes.CommF_:InvokeServer("Awakener", "Awaken")
            end)
        end
    end
end, "L-AWAKE")

Tabs.Raids:AddSection("Multi Raid")
__RAID_MultiNames = {}
for _, p in pairs(__SVC_PLR:GetChildren()) do
    if p.Name ~= plr.Name then table.insert(__RAID_MultiNames, p.Name) end
end
_G.SelectPlayerMultiRaid = {}
Tabs.Raids:AddDropdown({
    Name = __DIO_T["Select Player Multi Raid"],
    Description = "",
    Options = __RAID_MultiNames,
    MultiSelect = true,
    Default = {},
    Callback = function(Value)
        _G.SelectPlayerMultiRaid = __RAID_NormMulti(Value, __RAID_MultiNames)
    end
})
_G.AccountBuyChip = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Account Buy Chip"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AccountBuyChip = (Value == true)
    end
})
_G.AccountPickSlot = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Account Pick Slot Raid"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AccountPickSlot = (Value == true)
    end
})
__RAID_SlotFree = function(slots)
    for _, b in next, slots:GetChildren() do
        if b:IsA("BasePart") and b:FindFirstChild("Hitbox") and b.Color.BrickColor.Name ~= "Lime green" then
            return b
        end
    end
end
__RAID_NearSlot = function(slots)
    for _, b in next, slots:GetChildren() do
        if b:FindFirstChild("Hitbox") then
            if plr:DistanceFromCharacter(b.Hitbox.Position) < 10 then return true end
        end
    end
end
__RAID_MultiReady = function(slots)

    local E = {}
    if _G.SelectPlayerMultiRaid then
        local slotList = {}
        for _, s in next, slots:GetChildren() do
            if s:FindFirstChild("Hitbox") then table.insert(slotList, s) end
        end
        for _, l in ipairs(_G.SelectPlayerMultiRaid) do
            local p = __SVC_PLR:FindFirstChild(l)
            if p then
                local near = false
                for _, s in ipairs(slotList) do
                    if p:DistanceFromCharacter(s.Hitbox.Position) <= 10 then near = true break end
                end
                if not near then table.insert(E, l) end
            end
        end
    end
    if #E == 0 then return true end
end
__RAID_MultiRun = function(b)
    local ch0 = plr.Character
    if not ch0 or not ch0:FindFirstChild("HumanoidRootPart") then return end
    local summon
    if __RAID_Sea2 then
        local ci = __SVC_WS.Map:FindFirstChild("CircleIsland")
        local rs = ci and ci:FindFirstChild("RaidSummon2")
        local btn = rs and rs:FindFirstChild("Button")
        summon = btn and btn:FindFirstChild("Main")
    elseif __RAID_Sea3 then
        local bc = __SVC_WS.Map:FindFirstChild("Boat Castle")
        local rs = bc and bc:FindFirstChild("RaidSummon2")
        local btn = rs and rs:FindFirstChild("Button")
        summon = btn and btn:FindFirstChild("Main")
    end
    local hud = plr.PlayerGui:FindFirstChild("Main")
    hud = hud and hud:FindFirstChild("TopHUDList")
    local timer = hud and hud:FindFirstChild("RaidTimer")
    local timerOn = timer and timer.Visible
    if not timerOn and not __RAID_InRaid() then
        if not summon then
            _tp(CFrame.new(-5500, 314, -2855))
            return
        end
    end
    if _G.AccountPickSlot then
        if summon and not timerOn and not __RAID_InRaid() and not __RAID_NearSlot(summon.Parent.Parent) then
            __DIO_wait(Random.new():NextNumber(0, 2))
            local slot = __RAID_SlotFree(summon.Parent.Parent)
            if slot then _tp(slot.Hitbox.CFrame * CFrame.new(0, -2, 0)) end
        end
    end
    if __RAID_HasItem("Special Microchip") then
        if __RAID_WaitGo then
            __DIO_wait(5)
            __RAID_WaitGo = false
        end
        __RAID_BuyChip = false
        if summon and __RAID_MultiReady(summon.Parent.Parent) and _G.AccountBuyChip then
            local cd = summon:FindFirstChild("ClickDetector")
            if cd then fireclickdetector(cd) end
        end
        __RAID_CancelTween()
        return
    end
    if timerOn and __RAID_InRaid() then
        __RAID_WaitGo = true
        __RAID_BuyChip = true
        local E = __RAID_MobRaid()
        if E then
            repeat
                __DIO_wait()
                __RAID_Equip(__RAID_ToolName(_G.SelectWeaponRaid or "Melee"))
                Attack.Kill(E, _G.AutoMultiRaid)
                if (_G.SelectWeaponRaid or "Melee") == "Blox Fruit" then
                    _tp(E.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
                else
                    _tp(E.HumanoidRootPart.CFrame * CFrame.new(10, 20, 0))
                end
            until not __RAID_IsMobAlive(E) or not _G.AutoMultiRaid
        else
            local E = __RAID_LastIsland()
            if E then
                if E.Name == "Island 2" and (_G.SelectRaid or _G.SelectChip) == "Phoenix" then
                    _tp(E.CFrame * CFrame.new(300, 60, 0))
                else
                    _tp(E.CFrame * CFrame.new(0, 60, 0))
                end
            end
        end
        return
    end
    if _G.AccountBuyChip and __RAID_BuyChip and plr.Data.Level.Value >= 1100
        and not timerOn and not __RAID_HasItem("Special Microchip") and not __RAID_InRaid() then
        if not __RAID_FruitOnChar() and __RAID_TakeCheapFruit() and _G.GetFruitLowBeli then
            __SVC_RS.Remotes.CommF_:InvokeServer("LoadFruit", __RAID_TakeCheapFruit())
        end
        __SVC_RS.Remotes.CommF_:InvokeServer("RaidsNpc", "Check")
        __SVC_RS.Remotes.CommF_:InvokeServer("RaidsNpc", "Select", b or "Flame")
        __DIO_wait(1)
    end
end
_G.AutoMultiRaid = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Multi Raid"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoMultiRaid = (Value == true)
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(0.1) do
        if _G.AutoMultiRaid then
            local _, err = pcall(function()
                __RAID_MultiRun(_G.SelectRaid or _G.SelectChip)
            end)
            if err then print(err) end
        end
    end
end, "L-MRAID")

Tabs.Raids:AddSection("Join Dungeon")
__RAID_JoinNames = {}
for _, p in pairs(__SVC_PLR:GetChildren()) do
    if p.Name ~= plr.Name then table.insert(__RAID_JoinNames, p.Name) end
end
_G.SelectAccountJoin = nil
Tabs.Raids:AddDropdown({
    Name = __DIO_T["Select Account Join"],
    Description = "",
    Options = __RAID_JoinNames,
    Default = "",
    Callback = function(Value)
        _G.SelectAccountJoin = Value
    end
})
_G.MinPlayerJoinDungeon = 2
Tabs.Raids:AddSlider({
    Name = __DIO_T["Min Player Join Dungeon"],
    Min = 0,
    Max = 4,
    Default = 2,
    Increment = 1,
    Callback = function(Value)
        _G.MinPlayerJoinDungeon = tonumber(Value) or 2
    end
})
_G.SelectDifficulty = "Normal"
Tabs.Raids:AddDropdown({
    Name = __DIO_T["Select Difficulty"],
    Description = "",
    Options = { "Normal", "Hard", "Challenge" },
    Default = "Normal",
    Callback = function(Value)
        _G.SelectDifficulty = Value or "Normal"
    end
})
_G.AccountStartDungeon = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Account Start Dungeon"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AccountStartDungeon = (Value == true)
    end
})
__RAID_Pad = function(mine)
    local hub = __SVC_WS.Map:FindFirstChild("Simulation Hub")
    local pads = hub and hub:FindFirstChild("Pads")
    if not pads then return nil end
    for _, P in next, pads:GetChildren() do
        if (mine and P:GetAttribute("Initiator") == plr.UserId)
            or P:GetAttribute("NumPlayersOnPad") == 0 then
            return P
        end
    end
end
_G.AutoJoinDungeon = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Join Dungeon"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoJoinDungeon = (Value == true)
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait() do
        if _G.AutoJoinDungeon then
            local _, err = pcall(function()
                local dro = __SVC_RS:FindFirstChild("DungeonReplicationObjects")
                if dro and dro:FindFirstChildWhichIsA("Folder") then return end
                local menu = plr.PlayerGui:FindFirstChild("DungeonQueueSettingsMenu")
                if _G.AccountStartDungeon then
                    if not menu or not menu.Enabled then
                        local pad = __RAID_Pad()
                        if pad and pad.PrimaryPart then _tp(pad.PrimaryPart.CFrame * CFrame.new(0, 5, 0)) end
                    else
                        local pad = __RAID_Pad(true)
                        if not pad then return end
                        local y = pad:GetAttribute("NumPlayersOnPad") or 0
                        local P = _G.SelectDifficulty or "Normal"
                        if pad:GetAttribute("Difficulty") ~= P then
                            local rsc = pad:FindFirstChild("DungeonSettingsChanged")
                            if rsc then rsc:FireServer("Difficulty", P) end
                        end
                        if y >= (_G.MinPlayerJoinDungeon or 2) then
                            local rsc = pad:FindFirstChild("DungeonSettingsChanged")
                            if rsc then
                                rsc:FireServer("Start")
                                __DIO_wait(2)
                            end
                        end
                    end
                elseif not menu or not menu.Enabled then
                    local acc = __SVC_PLR:FindFirstChild(_G.SelectAccountJoin or "")
                    local ach = acc and acc.Character
                    local ahrp = ach and ach:FindFirstChild("HumanoidRootPart")
                    if ahrp then _tp(ahrp.CFrame) end
                end
            end)
            if err then print(err) end
        end
    end
end, "L-JDUNG")

Tabs.Raids:AddSection("Dungeon")
_G.SelectWeaponDungeon = "Melee"
Tabs.Raids:AddDropdown({
    Name = __DIO_T["Select Weapon Dungeon"],
    Description = "",
    Options = { "Melee", "Sword", "Blox Fruit", "Gun" },
    Default = "Melee",
    Callback = function(Value)
        _G.SelectWeaponDungeon = Value or "Melee"
    end
})
__RAID_getuv = (debug and debug.getupvalue) or getupvalue
__RAID_setupv = (debug and debug.setupvalue) or setupvalue
__RAID_getuvs = (debug and debug.getupvalues) or getupvalues
__RAID_DungInfo = function(b)
    local dro = __SVC_RS:WaitForChild("DungeonReplicationObjects", 5)
    if not dro then return nil end
    return dro:FindFirstChild(b, true)
end
__RAID_CurFloor = function()
    local b = plr:GetAttribute("ExplorerGUID")
    local E = b and __RAID_DungInfo(b)
    if E then return E:GetAttribute("FloorId") end
end
__RAID_HighFloor = function()
    local b = plr:GetAttribute("ExplorerGUID")
    local E = b and __RAID_DungInfo(b)
    if E and E.Parent and E.Parent.Parent then
        return E.Parent.Parent:GetAttribute("CurrentExploredLevel")
    end
end
__RAID_PointIn = function(b, E)
    if not b or not b:IsA("Model") then return false end
    local cf, size = b:GetBoundingBox()
    local p, h = cf:PointToObjectSpace(E), size * 0.5
    return math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z
end
__RAID_MobDung = function()
    local ch = plr.Character
    local E = ch and ch:FindFirstChild("HumanoidRootPart")
    if not E then return nil end
    local b = __RAID_HighFloor()
    if not b then return nil end
    local dg = __SVC_WS.Map:FindFirstChild("Dungeon")
    local l = dg and dg:FindFirstChild(tostring(b))
    if not l then return nil end
    local y, P = math.huge, nil
    local en = __SVC_WS:FindFirstChild("Enemies")
    if not en then return nil end
    for _, H in ipairs(en:GetChildren()) do
        if __RAID_IsMobAlive(H) and H.Name ~= "Blank Buddy" then
            local Y = H:FindFirstChild("HumanoidRootPart")
            if Y and __RAID_PointIn(l, Y.Position) then
                b = (Y.Position - E.Position).Magnitude
                if b < y then y, P = b, H end
            end
        end
    end
    return P
end
__RAID_PropDung = function()
    local ch = plr.Character
    local E = ch and ch:FindFirstChild("HumanoidRootPart")
    if not E then return nil end
    local b = __RAID_HighFloor()
    if not b then return nil end
    local dg = __SVC_WS:FindFirstChild("Dungeon")
    local l = dg and dg:FindFirstChild(tostring(b))
    if not l then return nil end
    local y, P = math.huge, nil
    local en = __SVC_WS:FindFirstChild("Enemies")
    if not en then return nil end
    for _, H in ipairs(en:GetChildren()) do
        if __RAID_IsMobAlive(H) and H.Name == "PropHitboxPlaceholder" then
            local hrp = H:FindFirstChild("HumanoidRootPart")
            if hrp and __RAID_PointIn(l, hrp.Position) then
                local d = (hrp.Position - E.Position).Magnitude
                if d < y then y, P = d, H end
            end
        end
    end
    return P
end
__RAID_CORE_BUFFS = { "Lifesteal", "AllCooldown", "AttackSpeedMultiplier", "FruitTAPCooldown", "Armor", "Sniper", "Overflow", "Gun", "Sword", "Melee", "Fruit", "Defense" }
__RAID_Strip = function(b) return (b:gsub("<.->", "")) end
__RAID_Name2Key, __RAID_CardList = {}, {}
pcall(function()
    local EB = require(__SVC_RS:WaitForChild("DungeonShared", 10):WaitForChild("ExplorerBuffs", 10)).ExplorerBuffs
    for b, E in pairs(EB) do
        if E.DisplayName then __RAID_Name2Key[__RAID_Strip(E.DisplayName)] = b end
    end
    for _, E in ipairs(__RAID_CORE_BUFFS) do
        local b = EB[E]
        if b and b.DisplayName then table.insert(__RAID_CardList, __RAID_Strip(b.DisplayName)) end
    end
end)
if #__RAID_CardList == 0 then
    for _, k in ipairs(__RAID_CORE_BUFFS) do
        __RAID_Name2Key[k] = k
        table.insert(__RAID_CardList, k)
    end
end
__RAID_IsCD = function(b)
    if not b then return false end
    if b:find("Cooldown") then
        if b:find("ZCooldown") or b:find("XCooldown") or b:find("CCooldown") or b:find("VCooldown") then
            return true
        end
    end
    return false
end
_G.SelectCardPriority = {}
Tabs.Raids:AddDropdown({
    Name = __DIO_T["Select Card Priority"],
    Description = "",
    Options = __RAID_CardList,
    MultiSelect = true,
    Default = {},
    Callback = function(Value)
        _G.SelectCardPriority = __RAID_NormMulti(Value, __RAID_CardList)
    end
})
__RAID_PickCard = function()
    local b, E, l, y = _G.SelectCardPriority or {}, {}, math.huge, nil
    for _, Y in pairs(plr.PlayerGui:GetChildren()) do
        local H = Y:FindFirstChild("DisplayName", true)
        local C = Y:FindFirstChild("BuffDescription", true)
        local J = Y:FindFirstChildWhichIsA("TextButton", true)
        if H and C and J and H:IsA("TextLabel") then
            local P = __RAID_Name2Key[__RAID_Strip(H.Text)]
            if P then
                if __RAID_IsCD(P) then continue end
                for idx, nm in ipairs(b) do
                    if __RAID_Name2Key[nm] == P then
                        if idx < l then l, y = idx, J end
                        break
                    end
                end
                table.insert(E, J)
            end
        end
    end
    if y then
        print("AUTO PICK (PRIORITY INDEX):", l)
        for _, c in pairs(getconnections(y.Activated)) do c.Function() end
        return true
    end
    if #E > 0 then
        local pick = E[math.random(1, #E)]
        print("AUTO PICK (RANDOM)")
        for _, c in pairs(getconnections(pick.Activated)) do c.Function() end
        return true
    end
    return false
end
__RAID_ShootM1 = function(E)
    task.spawn(function()
        local ch = plr.Character
        if not ch then return end
        local gunName = __RAID_ToolName("Gun")

        if not gunName or not ch:FindFirstChild(gunName) then return end
        local ok, CU = pcall(function() return require(__SVC_RS.Modules.CombatUtil) end)
        if not ok then return end
        if not CU:IsGunReloading(ch[gunName]) then
            if gunName ~= "Skull Guitar" then
                local atk = __RAID_getuvs(require(__SVC_RS.Controllers.CombatController).Attack)[9]
                local Q = __RAID_getuv(atk, 15)
                local d = __RAID_getuv(atk, 13)
                local I = __RAID_getuv(atk, 16)
                local U = __RAID_getuv(atk, 17)
                local o = __RAID_getuv(atk, 14)
                local V = __RAID_getuv(atk, 12)
                local N = __RAID_getuv(atk, 18)
                local y = V * d
                local P = ((o * d + V * Q) % I * I + y) % U
                o = math.floor(P / I)
                V = P - o * I
                N = N + 1
                __RAID_setupv(atk, 15, Q)
                __RAID_setupv(atk, 13, d)
                __RAID_setupv(atk, 16, I)
                __RAID_setupv(atk, 17, U)
                __RAID_setupv(atk, 14, o)
                __RAID_setupv(atk, 12, V)
                __RAID_setupv(atk, 18, N)
                __SVC_RS.Remotes.Validator2:FireServer(math.floor(P / U * 16777215), N)
                local net = __SVC_RS.Modules.Net:FindFirstChild("RE/ShootGunEvent")
                if gunName == "Cannon" then
                    if net then net:FireServer(E) end
                else
                    if net then net:FireServer(E.HumanoidRootPart.Position, { E.HumanoidRootPart }) end
                end
                local g = ch:FindFirstChild(gunName)
                local cd = g and g:FindFirstChild("Cooldown")
                if cd then task.wait(cd.Value) end
            else
                local sg = ch:FindFirstChild("Skull Guitar")
                if sg and sg:FindFirstChild("RemoteEvent") then
                    sg.RemoteEvent:FireServer("TAP", E.HumanoidRootPart.Position)
                end
                local g = ch:FindFirstChild(gunName)
                local cd = g and g:FindFirstChild("Cooldown")
                if cd then task.wait(cd.Value) end
            end
        end
    end)
end
__RAID_SpamGun = function(E)
    if typeof(E) ~= "Instance" or not E:IsA("BasePart") then return end
    local ok, CU = pcall(function() return require(__SVC_RS.Modules.CombatUtil) end)
    if not ok then return end
    local ch = plr.Character
    local gun = ch and ch:FindFirstChild("Dragonstorm")
    if not gun or CU:IsGunReloading(gun) then return end
    local atk = __RAID_getuvs(require(__SVC_RS.Controllers.CombatController).Attack)[9]
    local I = __RAID_getuv(atk, 15)
    local U13 = __RAID_getuv(atk, 13)
    local o = __RAID_getuv(atk, 16)
    local V = __RAID_getuv(atk, 17)
    local N = __RAID_getuv(atk, 14)
    local y = __RAID_getuv(atk, 12)
    local P = __RAID_getuv(atk, 18)
    local Q = y * U13
    local d = ((N * U13 + y * I) % o * o + Q) % V
    N = math.floor(d / o)
    y = d - N * o
    P = P + 1
    __RAID_setupv(atk, 15, I)
    __RAID_setupv(atk, 13, U13)
    __RAID_setupv(atk, 16, o)
    __RAID_setupv(atk, 17, V)
    __RAID_setupv(atk, 14, N)
    __RAID_setupv(atk, 12, y)
    __RAID_setupv(atk, 18, P)
    __SVC_RS.Remotes.Validator2:FireServer(math.floor(d / V * 16777215), P)
    local shoot = __SVC_RS.Modules.Net:FindFirstChild("RE/ShootGunEvent")
    if shoot then shoot:FireServer(E.Position, { E }) end
end
__RAID_DungNextFloor = false
_G.AutoAttackDungeon = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Attack Dungeon"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoAttackDungeon = (Value == true)
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait() do
        if _G.AutoAttackDungeon then
            local _, err = pcall(function()
                local ch = plr.Character
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then return end
                local E, l = __RAID_CurFloor(), __RAID_HighFloor()
                if not E or not l then return end
                if E ~= l then
                    __RAID_DungNextFloor = true
                    local dg = __SVC_WS.Map:FindFirstChild("Dungeon")
                    local P = dg and dg:FindFirstChild(tostring(l - 1))
                    local et = P and P:FindFirstChild("ExitTeleporter")
                    local rt = et and et:FindFirstChild("Root")
                    if rt and rt:FindFirstChild("TouchInterest") then
                        if plr:DistanceFromCharacter(rt.Position) > 15 then
                            __DIO_wait(1)
                            _tp(rt.CFrame * CFrame.new(0, 5, 0))
                        else
                            __DIO_wait(3)
                        end
                    end
                    return
                end
                if __RAID_DungNextFloor then
                    __RAID_CancelTween()
                    __RAID_DungNextFloor = false
                end
                local mob, prop = __RAID_MobDung(), __RAID_PropDung()
                if not mob or not __RAID_IsMobAlive(mob) then return end
                if prop then
                    repeat
                        __DIO_wait()
                        if not _G.AutoAttackDungeon then break end
                        if not __RAID_IsMobAlive(prop) then break end
                        if not __RAID_CurFloor() or __RAID_CurFloor() ~= __RAID_HighFloor() then break end
                        local w = _G.SelectWeaponDungeon or "Melee"
                        __RAID_Equip(__RAID_ToolName(w))
                        if w == "Gun" then
                            if __RAID_ToolName(w) == "Dragonstorm" then
                                __RAID_SpamGun(prop.HumanoidRootPart)
                            else
                                __RAID_ShootM1(prop)
                            end
                        else
                            Attack.Kill(prop, _G.AutoAttackDungeon)
                        end
                        __RAID_SizePart(prop)
                        if w == "Blox Fruit" then
                            _tp(prop.HumanoidRootPart.CFrame * CFrame.new(-7, 12, 0))
                        else
                            _tp(prop.HumanoidRootPart.CFrame * CFrame.new(10, 20, 0))
                        end
                    until hum.Health <= 0 or not _G.AutoAttackDungeon
                else
                    repeat
                        __DIO_wait()
                        if not _G.AutoAttackDungeon then break end
                        if not __RAID_IsMobAlive(mob) then break end
                        if not __RAID_CurFloor() or __RAID_CurFloor() ~= __RAID_HighFloor() then break end
                        local w = _G.SelectWeaponDungeon or "Melee"
                        __RAID_Equip(__RAID_ToolName(w))
                        if w == "Gun" then
                            if __RAID_ToolName(w) == "Dragonstorm" then
                                __RAID_SpamGun(mob.HumanoidRootPart)
                            else
                                __RAID_ShootM1(mob)
                            end
                        else
                            Attack.Kill(mob, _G.AutoAttackDungeon)
                        end
                        __RAID_SizePart(mob)
                        if w == "Blox Fruit" then
                            _tp(mob.HumanoidRootPart.CFrame * CFrame.new(-7, 12, 0))
                        else
                            _tp(mob.HumanoidRootPart.CFrame * CFrame.new(10, 20, 0))
                        end
                    until hum.Health <= 0 or __RAID_PropDung() or not _G.AutoAttackDungeon
                end
            end)
            if err then warn("[Auto Dungeon Error]:", err) end
        end
    end
end, "L-DUNG")
_G.AutoPickCardDungeon = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Pick Card Dungeon"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoPickCardDungeon = (Value == true)
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait() do
        if _G.AutoPickCardDungeon then
            local _, err = pcall(function()
                __RAID_PickCard()
            end)
            if err then warn("[Auto Pick Card Dungeon Error]:", err) end
        end
    end
end, "L-DCARD")

Tabs.Raids:AddSection("Law Raid")
__RAID_BuyLawChip = function()
    local v = __SVC_RS.Remotes.CommF_:InvokeServer("BlackbeardReward", "Microchip", "2")
    if v == 1 or v == 2 then return true end
    if v == 0 then return false end
end
_G.AutoBuyChipAttackLaw = false
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Buy Chip and Attack Law"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoBuyChipAttackLaw = (Value == true)
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait() do
        if _G.AutoBuyChipAttackLaw then
            pcall(function()
                local ch = plr.Character
                if not ch or not ch:FindFirstChild("HumanoidRootPart") then return end
                local ci = __SVC_WS.Map:FindFirstChild("CircleIsland")
                local rs = ci and ci:FindFirstChild("RaidSummon")
                local btn = rs and rs:FindFirstChild("Button")
                local main = btn and btn:FindFirstChild("Main")
                local cd = main and main:FindFirstChild("ClickDetector")
                if __RAID_HasItem("Core Brain") then
                    if cd then fireclickdetector(cd) end
                    return
                end
                local P = __RAID_CheckBoss("Order")
                if P then
                    repeat
                        __DIO_wait()
                        __RAID_SizePart(P)
                        __RAID_Equip(__RAID_ToolName(_G.SelectWeaponRaid or "Melee"))
                        Attack.Kill(P, _G.AutoBuyChipAttackLaw)
                        if (_G.SelectWeaponRaid or "Melee") == "Blox Fruit" then
                            _tp(P.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
                        else
                            _tp(P.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
                        end
                    until not __RAID_IsMobAlive(P) or not _G.AutoBuyChipAttackLaw
                elseif not __RAID_HasItem("Microchip") and plr.Data.Fragments.Value >= 1000 then
                    __RAID_BuyLawChip()
                    __DIO_wait(2)
                elseif __RAID_HasItem("Microchip") then
                    if cd then fireclickdetector(cd) end
                end
            end)
        end
    end
end, "L-LAW")
__DIO_BOOT("Load Comples")
__DIO_BOOT("Now Booster")
Tabs.Combat:AddSection("PvP and AimBot")
local PlrList = {}
for _, v in pairs(__SVC_PLR:GetChildren()) do
    table.insert(PlrList, v.Name)
end
Tabs.Combat:AddDropdown({
    Name = __DIO_T["Select Players"],
    Description = "",
    Options = PlrList,
    Callback = function(Value)
        _G.PlayersList = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
Tabs.Combat:AddToggle({
    Name = __DIO_T["Teleport To Select Players"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.TpPly = Value
        spawn(function()
            pcall(function()
                while _G.TpPly do
                    __DIO_wait()
                    _tp(__SVC_PLR[_G.PlayersList].Character.HumanoidRootPart.CFrame)
                end
            end)
        end)
    end
})
Tabs.Combat:AddToggle({
    Name = __DIO_T["Spectate Select Players"],
    Description = "",
    Default = false,
    Callback = function(Value)
        SpectatePlys = Value
        spawn(function()
            repeat
                __DIO_wait(0.1)
                local __sp = __SVC_PLR:FindFirstChild(_G.PlayersList)
                if __sp and __sp.Character and __sp.Character:FindFirstChild("Humanoid") then
                    workspace.Camera.CameraSubject = __sp.Character.Humanoid
                end
            until not SpectatePlys
            local __chSP = plr.Character
            local __humSP = __chSP and __chSP:FindFirstChildOfClass("Humanoid")
            if __humSP then workspace.Camera.CameraSubject = __humSP end
        end)
    end
})
Tabs.Combat:AddDropdown({
    Name = __DIO_T["Select Aim Method"],
    Description = "",
    Options = {"Aim Player","Nearest Aim"},
    Callback = function(Value)
        ABmethod = Value
    end
})
Tabs.Combat:AddToggle({
    Name = __DIO_T["Aimbot Method Skills"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AimMethod = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(0.1) do
        pcall(function()
            if _G.AimMethod and ABmethod == "Aim Player" then
                local target = Players:FindFirstChild(getgenv().PlayersList)
                if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
                    if target.Team ~= plr.Team then
                        MousePos = target.Character.HumanoidRootPart.Position
                    end
                end
            end
        end)
    end
end, "L13175")
__DIO_SafeLoop(function()
    while __DIO_wait(0.1) do
        pcall(function()
            if _G.AimMethod and ABmethod == "Nearest Aim" then
                local MaxDistance = math.huge
                for _, v in pairs(Players:GetPlayers()) do
                    if v ~= plr and v.Team ~= plr.Team and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                        local Distance = (v.Character.HumanoidRootPart.Position - plr.Character.HumanoidRootPart.Position).Magnitude
                        if Distance < MaxDistance then
                            MaxDistance = Distance
                            MousePos = v.Character.HumanoidRootPart.Position
                        end
                    end
                end
            end
        end)
    end
end, "L13189")
Tabs.Combat:AddToggle({
    Name = __DIO_T["Aimbot Camera Closet Players"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AimCam = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(Sec) do
        pcall(function()
            if _G.AimCam then
                local camera = workspace.CurrentCamera
                closestplayer = function()
                    local dist = math.huge
                    local target = nil
                    for _, v in next, ply:GetPlayers() do
                        if v ~= plr then
                            if v.Character and v.Character:FindFirstChild("Head") and _G.AimCam and v.Character.Humanoid.Health > 0 then
                                local Mag = (v.Character.Head.Position - plr.Character.Head.Position).Magnitude
                                if Mag < dist then
                                    dist = Mag
                                    target = v
                                end
                            end
                        end
                    end
                    return target
                end
                repeat
                    __DIO_wait()
                    if not _G.AimCam then break end
                    local __aimT = closestplayer()
                    if __aimT and __aimT.Character and __aimT.Character:FindFirstChild("HumanoidRootPart") then
                        camera.CFrame = CFrame.new(camera.CFrame.Position, __aimT.Character.HumanoidRootPart.Position)
                    end
                until not _G.AimCam
            end
        end)
    end
end, "L13222")
Tabs.Combat:AddSection(" PvP function")
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoReceivePlayerQuest then
            pcall(function()
                __SVC_RS.Remotes.CommF_:InvokeServer("PlayerHunter")
            end)
        end
    end
end, "L13259")
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
        if _G.AutoPlayerHunter then
            local __qP = __DIO_GetCurrentQuest()
            if not __qP.IsActive then
                __DIO_wait(0.5)
                __SVC_RS.Remotes.CommF_:InvokeServer("PlayerHunter")
            else
                for _, target in pairs(__SVC_WS.Characters:GetChildren()) do
                    if __qP.QuestText and string.find(__qP.QuestText, target.Name, 1, true) then
                        repeat
                            __DIO_wait(0.25)
                            if AutoHaki then AutoHaki() end
                            if EquipWeapon then EquipWeapon(_G.SelectWeapon) end
                            _tp(target.HumanoidRootPart.CFrame * CFrame.new(1, 7, 3))
                            target.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                            __SVC_VU:CaptureController()
                            __SVC_VU:Button1Down(Vector2.new(1280, 672))
                        until _G.AutoPlayerHunter == false or target.Humanoid.Health <= 0
                        __SVC_RS.Remotes.CommF_:InvokeServer("AbandonQuest")
                    end
                end
            end
        end
        end)
    end
end, "L13269")
Tabs.Combat:AddToggle({
    Name = __DIO_T["Auto Enable PvP"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoPvP = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
        if _G.AutoPvP then
            local playerGui = game.Players.LocalPlayer.PlayerGui
            if playerGui and playerGui:FindFirstChild("Main") and playerGui.Main:FindFirstChild("PvpDisabled") then
                if playerGui.Main.PvpDisabled.Visible then
                    pcall(function()
                        __SVC_RS.Remotes.CommF_:InvokeServer("EnablePvp")
                    end)
                end
            end
        end
        end)
    end
end, "L13320")
Tabs.Combat:AddToggle({
    Name = __DIO_T["Auto Safe Mode"],
    Default = false,
    Callback = function(Value)
        _G.SafeMode = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
        if _G.SafeMode then
            local char = game.Players.LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local targetPos = hrp.CFrame * CFrame.new(0, 1000, 0)
                _tp(targetPos)
            end
        end
        end)
    end
end, "L13351")
Tabs.Combat:AddToggle({
    Name = __DIO_T["Teleport Y if low health"],
    Default = false,
    Callback = function(Value)
        _G.LowHpTpY = (Value == true)
        __DIO_LowHpYOn = false
    end
})
Tabs.Combat:AddSlider({
    Name = __DIO_T["% Health Player"],
    Min = 0,
    Max = 100,
    Default = 40,
    Callback = function(Value)
        _G.LowHpPct = math.clamp(math.floor(tonumber(Value) or 40), 0, 100)
    end
})
Tabs.Combat:AddSlider({
    Name = __DIO_T["Distance Teleport Y"],
    Min = 0,
    Max = 10000,
    Default = 800,
    Callback = function(Value)
        _G.LowHpTpYDist = math.clamp(math.floor(tonumber(Value) or 800), 0, 10000)
    end
})
_G.LowHpTpY = (GetSetting("UI/Combat/Teleport Y if low health", false) == true)
_G.LowHpPct = math.clamp(math.floor((tonumber(GetSetting("UI/Combat/% Health Player", 40)) or 40) + 0.5), 0, 100)
_G.LowHpTpYDist = math.clamp(math.floor((tonumber(GetSetting("UI/Combat/Distance Teleport Y", 800)) or 800) + 0.5), 0, 10000)
Tabs.Combat:AddSection("LocalPlayer Settings")
local Players = __SVC_PLR
local RunService = __SVC_RUN
local player = Players.LocalPlayer
local flying = false
local flySpeed = 50
local flyConnection
local __DIO_FlyDescConn
local ctrl = {f = 0, b = 0, l = 0, r = 0}
local bg, bv
local function setupMobileControls()
    local function updateControlsFromJoystick()
        local character = player.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local moveDirection = humanoid.MoveDirection
        ctrl.f = 0
        ctrl.b = 0
        ctrl.l = 0
        ctrl.r = 0
        if moveDirection.Z < -0.1 then
            ctrl.f = 1
        elseif moveDirection.Z > 0.1 then
            ctrl.b = 1
        end
        if moveDirection.X < -0.1 then
            ctrl.l = 1
        elseif moveDirection.X > 0.1 then
            ctrl.r = 1
        end
    end
    local controlConnection
    controlConnection = RunService.Heartbeat:Connect(function()
        if flying then
            updateControlsFromJoystick()
        else
            if controlConnection then
                controlConnection:Disconnect()
            end
        end
    end)
end
local function toggleFly(value)
    flying = value
    if flying then
        if not player.Character then return end
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        local rootPart
        if player.Character:FindFirstChild("Torso") then
            rootPart = player.Character.Torso
        else
            rootPart = player.Character.UpperTorso
        end
        if not humanoid or not rootPart then return end
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
                part.Massless = true
            end
        end
        if __DIO_FlyDescConn then __DIO_FlyDescConn:Disconnect() __DIO_FlyDescConn = nil end
        __DIO_FlyDescConn = player.Character.DescendantAdded:Connect(function(descendant)
            if flying and descendant:IsA("BasePart") then
                descendant.CanCollide = false
                descendant.Massless = true
            end
        end)
        bg = Instance.new("BodyGyro", rootPart)
        bg.P = 9e4
        bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
        bg.cframe = rootPart.CFrame
        bv = Instance.new("BodyVelocity", rootPart)
        bv.velocity = Vector3.new(0, 0, 0)
        bv.maxForce = Vector3.new(9e9, 9e9, 9e9)
        humanoid.PlatformStand = true
        setupMobileControls()
        flyConnection = RunService.Heartbeat:Connect(function()
            if not flying or not player.Character then
                return
            end
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
            if (ctrl.l + ctrl.r) ~= 0 or (ctrl.f + ctrl.b) ~= 0 then
                bv.velocity = ((workspace.CurrentCamera.CoordinateFrame.lookVector * (ctrl.f + ctrl.b)) +
                              ((workspace.CurrentCamera.CoordinateFrame * CFrame.new(ctrl.l + ctrl.r, (ctrl.f + ctrl.b) * 0.2, 0).p) -
                              workspace.CurrentCamera.CoordinateFrame.p)) * flySpeed
            else
                bv.velocity = Vector3.new(0, 0, 0)
            end
            bg.cframe = workspace.CurrentCamera.CoordinateFrame
        end)
    else
        if flyConnection then
            flyConnection:Disconnect()
            flyConnection = nil
        end
        if __DIO_FlyDescConn then __DIO_FlyDescConn:Disconnect() __DIO_FlyDescConn = nil end
        if player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.PlatformStand = false
            end
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                    part.Massless = false
                end
            end
            if bg then bg:Destroy() end
            if bv then bv:Destroy() end
        end
        ctrl = {f = 0, b = 0, l = 0, r = 0}
    end
end
local function updateFlySpeed(value)
    flySpeed = value
end
player.CharacterAdded:Connect(function(character)
    __DIO_wait(1)
    if flying then
        toggleFly(false)
        __DIO_wait(0.1)
        toggleFly(true)
    end
end)
Tabs.Combat:AddToggle({
    Name = __DIO_T["Enable Fly"],
    Default = false,
    Callback = function(Value)
        toggleFly(Value)
    end
})
Tabs.Combat:AddSlider({
    Name = __DIO_T["Speed Fly Mode"],
    Min = 10,
    Max = 200,
    Default = 50,
    Callback = function(Value)
        updateFlySpeed(Value)
    end
})
__DIO_DashNoCD = function()
    local __ch = game.Players.LocalPlayer.Character
    local dodgeScript = __ch and __ch:WaitForChild("Dodge", 10)
    if not dodgeScript or type(getgc) ~= "function" then return end
    for i, v in next, getgc() do
        if typeof(v) == "function" then
            local __okE, __isDodge = pcall(function() return getfenv(v).script == dodgeScript end)
            if __okE and __isDodge then
                for i2, v2 in next, getupvalues(v) do
                    if tostring(v2) == "0.4" then
                        setupvalue(v, i2, 0)
                    end
                end
            end
        end
    end
end
Tabs.Combat:AddToggle({
    Name = __DIO_T["Dash No Cooldown"],
    Default = false,
    Callback = function(Value)
        getgenv().DodgeNoCD = Value
        -- FIX: truoc day toggle chi set flag, ham NoCooldown khong bao gio duoc goi -> toggle vo tac dung
        if Value then task.spawn(function() pcall(__DIO_DashNoCD) end) end
    end
})
pcall(function()
    game.Players.LocalPlayer.CharacterAdded:Connect(function()
        if getgenv().DodgeNoCD == true then
            task.delay(2, function() pcall(__DIO_DashNoCD) end)
        end
    end)
end)
Tabs.Combat:AddToggle({
    Name = __DIO_T["Instance Mink V3 [ INF ]"],
    Description = "",
    Default = false,
    Callback = function(Value)
        InfAblities = Value
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            local __agilChar = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if InfAblities then
                if __agilChar and not __agilChar:FindFirstChild("Agility") then
                    local agility = replicated.FX["Agility"]:Clone()
                    agility.Name = "Agility"
                    agility.Parent = __agilChar
                end
            elseif __agilChar and __agilChar:FindFirstChild("Agility") then
                __agilChar["Agility"]:Destroy()
            end
        end)
    end
end, "L13583")
Tabs.Combat:AddToggle({
    Name = __DIO_T["Instance Energy [ INF ]"],
    Description = "",
    Default = false,
    Callback = function(Value)
        infEnergy = Value
        if Value then
            getInfinity_Ability("Energy", infEnergy)
        end
    end
})
Tabs.Combat:AddToggle({
    Name = __DIO_T["Instance Soru [ INF ]"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.InfSoru = Value
        if Value then
            getInfinity_Ability("Soru", _G.InfSoru)
        end
    end
})
Tabs.Combat:AddToggle({
    Name = __DIO_T["Instance Observation Range [ INF ]"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.InfiniteObRange = Value
        if Value then
            getInfinity_Ability("Observation", _G.InfiniteObRange)
        end
    end
})
Tabs.Combat:AddToggle({
    Name = __DIO_T["Ignore Same Teams"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.NoAimTeam = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
Tabs.Combat:AddToggle({
    Name = __DIO_T["Accept Allies"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AcceptAlly = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AcceptAlly then
            pcall(function()
                for _, v in pairs(ply:GetChildren()) do
                    if v.Name ~= plr.Name and v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") then
                        replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("AcceptAlly", v.Name)
                    end
                end
            end)
        end
    end
end, "L13664")
Tabs.Travel:AddSection("Worlds")
Tabs.Travel:AddButton({
Name = __DIO_T["Travel East Blue (World 1)"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("TravelMain")
end})
Tabs.Travel:AddButton({
Name = __DIO_T["Travel Dressrosa (World 2)"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
end})
Tabs.Travel:AddButton({
Name = __DIO_T["Travel Zou (World 3)"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("TravelZou")
end})
__DIO_BOOT("travel")
Tabs.Travel:AddSection("Tween - Island")
Location = {}
local __WO = workspace:FindFirstChild("_WorldOrigin")
local __LocFolder = __WO and __WO:FindFirstChild("Locations")
if __LocFolder then
    for i,v in pairs(__LocFolder:GetChildren()) do
        table.insert(Location ,v.Name)
    end
end
Tabs.Travel:AddDropdown({
Name = __DIO_T["Select Islands"],
Description = "",
Options = Location,
Callback = function(Value)
  _G.Island = Value
end})
Tabs.Travel:AddToggle({
Name = __DIO_T["Auto Tween Island"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Teleport = Value
end
})
__DIO_SafeLoop(function()
  while __DIO_wait(0.25) do
    if _G.Teleport then
      pcall(function()
        local __woG = workspace:FindFirstChild("_WorldOrigin")
        local __locG = __woG and __woG:FindFirstChild("Locations")
        if not __locG or not _G.Island then return end
        local __dst = __locG:FindFirstChild(_G.Island)
        if __dst then _tp(__dst.CFrame * CFrame.new(0, 30, 0)) end
      end)
    end
  end
end, "AutoTravelIsland")
Tabs.Travel:AddSection("Tween - NPCs")
local __NPCsFolder = replicated:FindFirstChild("NPCs")
if __NPCsFolder then for _, v in pairs(__NPCsFolder:GetChildren()) do table.insert(NPCList, v.Name) end end
Tabs.Travel:AddDropdown({
Name = __DIO_T["Select NPCs"],
Options = NPCList,
Callback = function(Value)
  NPClist = Value
end})
Tabs.Travel:AddToggle({
Name = __DIO_T["Auto Tween to NPC"],
Description = "",
Default = false,
Callback = function(Value)
  _G.TPNpc = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.TPNpc then
	 pcall(function()
       for __, v in pairs(replicated.NPCs:GetChildren()) do
       if v.Name == NPClist then _tp(v.HumanoidRootPart.CFrame) end
       end
	 end)
    end
  end
end, "L13803")
Tabs.Shop:AddSection("Shop Function")
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Buso"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyHaki","Buso")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Geppo"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyHaki","Geppo")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Soru"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyHaki","Soru")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Ken"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("KenTalk","Buy")
end})
local __DIO_BUY_MELEE_CF = {
    ["BuyBlackLeg"] = {
        sea1 = CFrame.new(-983.617981, 12.449997, 3990.462891, 0.358573, 0.000000, 0.933502, 0.000000, 1.000000, 0.000000, -0.933502, 0.000000, 0.358573),
        sea2 = CFrame.new(-4754.378906, 35.104919, -4850.386719, -0.839514, -0.000000, -0.543339, -0.000000, 1.000000, -0.000000, 0.543339, 0.000000, -0.839514),
        sea3 = CFrame.new(-5044.229492, 371.375519, -3180.169434, 0.933992, -0.000000, 0.357293, -0.000000, 1.000000, 0.000000, -0.357293, -0.000000, 0.933992)
    },
    ["BuyElectro"] = {
        sea1 = CFrame.new(-5384.621582, 13.949928, -2150.930420, -0.380358, -0.000000, -0.924840, -0.000000, 1.000000, -0.000000, 0.924840, 0.000000, -0.380358),
        sea2 = CFrame.new(-4868.625977, 35.104752, -4763.653320, 0.958599, -0.000000, -0.284760, 0.000000, 1.000000, -0.000000, 0.284760, 0.000000, 0.958599),
        sea3 = CFrame.new(-4995.454102, 314.578491, -3206.252197, -0.873257, -0.000000, 0.487260, -0.000000, 1.000000, -0.000000, -0.487260, -0.000000, -0.873257)
    },
    ["BuyFishmanKarate"] = {
        sea1 = CFrame.new(61586.960938, 19.587997, 987.591003, 0.123274, 0.000000, 0.992373, 0.000000, 1.000000, 0.000000, -0.992373, 0.000000, 0.123274),
        sea2 = CFrame.new(-4956.956543, 35.103775, -4669.130859, -0.987738, -0.000000, -0.156122, -0.000000, 1.000000, -0.000000, 0.156122, 0.000000, -0.987738),
        sea3 = CFrame.new(-5023.369141, 371.375519, -3188.240723, 0.933992, 0.000000, 0.357293, -0.000000, 1.000000, -0.000000, -0.357293, 0.000000, 0.933992)
    },
    ["BlackbeardReward"] = {
        sea2 = CFrame.new(699.028992, 185.660995, 654.895020, -0.034849, 0.000315, -0.999393, 0.000555, 1.000000, 0.000296, 0.999392, -0.000544, -0.034849),
        sea3 = CFrame.new(-4980.895020, 371.375519, -3205.794189, 0.925798, 0.000000, 0.378020, -0.000000, 1.000000, -0.000000, -0.378020, 0.000000, 0.925798)
    },
    ["BuySuperhuman"] = {
        sea2 = CFrame.new(1379.682373, 247.490616, -5189.661133, 0.563149, -0.000000, 0.826355, 0.000000, 1.000000, 0.000000, -0.826355, -0.000000, 0.563149),
        sea3 = CFrame.new(-5004.613770, 371.375488, -3195.397949, 0.999814, 0.000000, 0.019286, -0.000000, 1.000000, -0.000000, -0.019286, 0.000000, 0.999814)
    },
    ["BuyDeathStep"] = {
        sea2 = CFrame.new(6356.472168, 296.100006, -6762.770996, -0.544830, -0.000076, 0.838547, -0.000076, 1.000000, 0.000041, -0.838547, -0.000041, -0.544830),
        sea3 = CFrame.new(-4996.452637, 314.578491, -3220.017822, 0.221792, -0.000000, 0.975094, -0.000000, 1.000000, 0.000000, -0.975094, -0.000000, 0.221792)
    },
    ["BuySharkmanKarate"] = {
        sea2 = CFrame.new(-2599.621826, 238.198334, -10315.998047, -0.374604, 0.000000, 0.927185, 0.000000, 1.000000, 0.000000, -0.927185, 0.000000, -0.374604),
        sea3 = CFrame.new(-4972.964844, 314.578491, -3220.524658, 0.996246, -0.000000, -0.086563, 0.000000, 1.000000, -0.000000, 0.086563, 0.000000, 0.996246)
    },
    ["BuyElectricClaw"] = {
        sea3 = CFrame.new(-10368.808594, 331.716705, -10133.301758, -0.561528, 0.000000, 0.827458, 0.000000, 1.000000, -0.000000, -0.827458, 0.000000, -0.561528)
    },
    ["BuyDragonTalon"] = {
        sea3 = CFrame.new(5661.897949, 1210.876953, 863.176025, -0.823952, 0.000000, -0.566660, 0.000000, 1.000000, 0.000000, 0.566660, 0.000000, -0.823952)
    },
    ["BuyGodhuman"] = {
        sea3 = CFrame.new(-13774.325195, 334.685028, -9876.829102, 0.997201, 0.000000, 0.074762, -0.000000, 1.000000, 0.000000, -0.074762, -0.000000, 0.997201)
    },
    ["BuySanguineArt"] = {
        sea3 = CFrame.new(-16515.066406, 22.811996, -188.572998, 0.999392, 0.000000, 0.034869, 0.000000, 1.000000, 0.000000, -0.034869, 0.000000, 0.999392)
    }
}
__DIO_MeleeCF = function(key)
    local entry = __DIO_BUY_MELEE_CF[key]
    if not entry then return nil end
    if sea1 then return entry.sea1 elseif sea2 then return entry.sea2 else return entry.sea3 end
end
-- Ten NPC dung nhu file 3nn (Banana Cat Hub)
__DIO_MeleeNPC = {
    BuyBlackLeg = "Dark Step Teacher",
    BuySuperhuman = "Martial Arts Master",
    BuySharkmanKarate = "Sharkman Teacher",
    DragonClaw = "Sabi",
    BuyDragonTalon = "Uzoth",
    BuyElectro = "Mad Scientist",
    BuyFishmanKarate = "Water Kung-fu Teacher",
    BuyDeathStep = "Phoeyu, the Reformed",
    BuyGodhuman = "Ancient Monk",
    BuyElectricClaw = "Previous Hero",
    BuySanguineArt = "Shafi",
    BlackbeardReward = "Sabi",
}
-- port DetectNpc() cua 3nn: tim NPC theo TEN (khong theo toa do cung)
__DIO_DetectNpc = function(npcName)
    if type(npcName) ~= "string" or npcName == "" then return nil end
    local __okAll, __npc = pcall(function()
        local __hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
        if not __hrp then return nil end
        local __best, __bestD = nil, math.huge
        local __folders = { workspace:FindFirstChild("NPCs"), __SVC_RS and __SVC_RS:FindFirstChild("NPCs") }
        for __i = 1, 2 do
            local __folder = __folders[__i]
            if __folder then
                for _, __l in ipairs(__folder:GetChildren()) do
                    local __okA, __ready = pcall(function()
                        return __l:GetAttribute("NPCLoaded") and __l:GetAttribute("NPCReady")
                    end)
                    if __okA and __ready and __l.Name == npcName and __l:FindFirstChild("HumanoidRootPart") then
                        local __okD, __d = pcall(function()
                            return (__hrp.Position - __l.HumanoidRootPart.Position).Magnitude
                        end)
                        if __okD and __d and __d < __bestD then __best, __bestD = __l, __d end
                    end
                end
            end
        end
        if __best then return __best end
        -- fallback: khong co attribute NPCLoaded/NPCReady van lay gan nhat
        for __i = 1, 2 do
            local __folder = __folders[__i]
            if __folder then
                for _, __l in ipairs(__folder:GetChildren()) do
                    if __l.Name == npcName and __l:FindFirstChild("HumanoidRootPart") then
                        local __okD, __d = pcall(function()
                            return (__hrp.Position - __l.HumanoidRootPart.Position).Magnitude
                        end)
                        if __okD and __d and __d < __bestD then __best, __bestD = __l, __d end
                    end
                end
            end
        end
        if __best then return __best end
        -- 3nn: khong thay trong workspace.NPCs / RS.NPCs (NPC chua stream) -> lay tu NPCManager
        local __okM, __inst = pcall(function()
            if not __DIO_NPCManager then
                __DIO_NPCManager = require(__SVC_RS:WaitForChild("NPCManager", 5))
            end
            local __lst = __DIO_NPCManager.getNPCsByName(npcName)
            return __lst and __lst[1] and __lst[1]._modelState and __lst[1]._modelState._instance
        end)
        if __okM and typeof(__inst) == "Instance" then return __inst end
        return nil
    end)
    if __okAll then return __npc end
    return nil
end
-- FIX "Auto Buy Melee": logic cu tween theo toa do cung -> hay tween sai cho.
-- Gio uu tien tim NPC theo TEN (DetectNpc), neu khong thay moi fallback ve toa do.
__DIO_MeleeBuyGo = function(key, cancelFn)
    local __npcName = __DIO_MeleeNPC[key]
    local __npc = __npcName and __DIO_DetectNpc(__npcName)
    if __npc and __npc:FindFirstChild("HumanoidRootPart") then
        shouldTween = true
        -- 3nn: dung NPC.HRP * (0,4,4) va chi mua khi < 8 stud -> arrive 4 stud
        return __DIO_FlyTo(__npc.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4), 4, cancelFn)
    end
    local __cf = __DIO_MeleeCF(key)
    if not __cf then return false end
    shouldTween = true
    return __DIO_FlyTo(__cf, 15, cancelFn)
end
__DIO_FlyTo = function(targetCF, arriveDist, cancelFn)
    if not targetCF then return false end
    local __c = plr.Character
    local __h = __c and __c:FindFirstChild("HumanoidRootPart")
    if not __h then return false end
    arriveDist = arriveDist or 15

    do
        local __snap = {}
        local __hasSnap = false
        pcall(function()
            local __on = __DIO_FarmFlagOnSet()
            for __k in pairs(__on or {}) do
                if __k ~= "__DIO_BuyFlying" then __snap[__k] = true __hasSnap = true end
            end
        end)
        local __startT = tick()
        local __userCancel = cancelFn
        cancelFn = function()
            if __userCancel and __userCancel() then return true end
            if (__DIO_FlyCancelT or 0) > __startT then return true end
            if __hasSnap then
                for __k in pairs(__snap) do
                    if __DIO_FlagGet(__k) == true then return false end
                end
                return true
            end
            return false
        end
    end
    local __hum = __c:FindFirstChildOfClass("Humanoid")
    if __hum and __hum.Sit then __hum.Sit = false end
    block.CFrame = __h.CFrame
    local __old = shouldTween
    shouldTween = true
    __DIO_FlyBusy = true
    __DIO_FlyBusyT = tick()
    local __t0 = tick()
    local __spd = math.max((type(__DIO_GetTweenSpeed) == "function" and __DIO_GetTweenSpeed()) or tonumber(_G.TweenSpeed) or 190, 1)
    local __timeout = math.min(math.max((targetCF.Position - __h.Position).Magnitude / __spd + 25, 15), 300)
    local __ok = false
    local __okFly, __errFly = pcall(function()
        while tick() - __t0 < __timeout do
            if cancelFn and cancelFn() then break end
            local c2 = plr.Character
            local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
            if not h2 then break end
            if (h2.Position - targetCF.Position).Magnitude <= arriveDist then
                __ok = true
                break
            end
            shouldTween = true
            _tp(targetCF)
            __DIO_wait(0.25)
        end
    end)
    __DIO_FlyBusy = false
    local __anyF = false
    pcall(function() __anyF = (type(__DIO_FarmFlagsOn) == "function") and __DIO_FarmFlagsOn() or false end)
    if __anyF then
        shouldTween = true
    else
        shouldTween = __old
        if __old ~= true then pcall(function() if type(__DIO_TweenKill) == "function" then __DIO_TweenKill(false, true) end end) end
    end
    if not __okFly then warn("[DIO] FlyTo error: " .. tostring(__errFly)) end
    return __ok
end
__DIO_BuyFlying = false
-- FIX "Auto Buy Melee" (port logic Fighting Shop cua 3nn)
-- Logic cu: tinh toa do 1 LAN (NPC chua stream -> fallback toa do cung) + dung cach NPC 8+ stud
-- -> tween sai cho / den noi ma remote mua khong nhan. Bo logic cu, thay bang 3nn:
--   moi vong: npc = DetectNpc(ten)  (workspace.NPCs -> RS.NPCs -> NPCManager)
--             neu cach NPC < 8 stud -> InvokeServer(mua)
--             BackupTween(_tp) den NPC.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4)
__DIO_BuyMeleeNames = {
    BuyBlackLeg = "Dark Step Teacher",
    BuySuperhuman = "Martial Arts Master",
    BuySharkmanKarate = "Sharkman Teacher",
    DragonClaw = "Sabi",
    BuyDragonTalon = "Uzoth",
    BuyElectro = "Mad Scientist",
    BuyFishmanKarate = "Water Kung-fu Teacher",
    BuyDeathStep = "Phoeyu, the Reformed",
    BuyGodhuman = "Ancient Monk",
    BuyElectricClaw = "Previous Hero",
    BuySanguineArt = "Shafi",
}
__DIO_BuyJobs = {
    { flag = "BuyMelee_BuyBlackLeg",       npc = "BuyBlackLeg",       cf = "BuyBlackLeg",       buy = { {"BuyBlackLeg"} } },
    { flag = "BuyMelee_BuyElectro",        npc = "BuyElectro",        cf = "BuyElectro",        buy = { {"BuyElectro"} } },
    { flag = "BuyMelee_BuyFishmanKarate",  npc = "BuyFishmanKarate",  cf = "BuyFishmanKarate",  buy = { {"BuyFishmanKarate"} } },
    { flag = "BuyMelee_BuyDragonClaw",     npc = "DragonClaw",        cf = "BlackbeardReward",  buy = { {"BlackbeardReward","DragonClaw","1"}, {"BlackbeardReward","DragonClaw","2"} } },
    { flag = "BuyMelee_BuySuperhuman",     npc = "BuySuperhuman",     cf = "BuySuperhuman",     buy = { {"BuySuperhuman"} } },
    { flag = "BuyMelee_BuyDeathStep",      npc = "BuyDeathStep",      cf = "BuyDeathStep",      buy = { {"BuyDeathStep"} } },
    { flag = "BuyMelee_BuySharkmanKarate", npc = "BuySharkmanKarate", cf = "BuySharkmanKarate", buy = { {"BuySharkmanKarate"} } },
    { flag = "BuyMelee_BuyElectricClaw",   npc = "BuyElectricClaw",   cf = "BuyElectricClaw",   buy = { {"BuyElectricClaw"} } },
    { flag = "BuyMelee_BuyDragonTalon",    npc = "BuyDragonTalon",    cf = "BuyDragonTalon",    buy = { {"BuyDragonTalon"} } },
    { flag = "BuyMelee_BuyGodhuman",       npc = "BuyGodhuman",       cf = "BuyGodhuman",       buy = { {"BuyGodhuman"} } },
    { flag = "BuyMelee_BuySanguineArt",    npc = "BuySanguineArt",    cf = "BuySanguineArt",    buy = { {"BuySanguineArt"} } },
}
__DIO_BuyLastInv = {}
__DIO_BuyMeleeStep = function(j)
    local __name = __DIO_BuyMeleeNames[j.npc]
    local __npc = __name and __DIO_DetectNpc(__name) or nil
    local __hrpN = __npc and __npc:FindFirstChild("HumanoidRootPart")
    local __ch = plr.Character
    local __hrp = __ch and __ch:FindFirstChild("HumanoidRootPart")
    if not __hrp then return end
    local __goal, __ref
    if __hrpN then
        __ref = __hrpN.Position
        __goal = __hrpN.CFrame * CFrame.new(0, 4, 4)
    else
        -- fallback cuoi cung: toa do teacher (chi khi NPCManager cung khong co)
        local __cf = __DIO_MeleeCF and __DIO_MeleeCF(j.cf)
        if not __cf then
            if tick() - (__DIO_BuyLastInv[j.flag .. "_nf"] or 0) > 10 then
                __DIO_BuyLastInv[j.flag .. "_nf"] = tick()
                pcall(function() __DIO_TNotify("Buy Melee", "Khong tim thay NPC " .. tostring(__name) .. " o sea nay.", 4) end)
            end
            return
        end
        __ref = __cf.Position
        __goal = __cf
    end
    if (__hrp.Position - __ref).Magnitude < 8 then
        if tick() - (__DIO_BuyLastInv[j.flag] or 0) > 1.5 then
            __DIO_BuyLastInv[j.flag] = tick()
            for _, __args in ipairs(j.buy) do
                pcall(function() replicated.Remotes.CommF_:InvokeServer(unpack(__args)) end)
            end
        end
    end
    if __DIO_FlagGet(j.flag) == true then
        shouldTween = true
        _tp(__goal)
    end
end
__DIO_SafeLoop(function()
    while __DIO_wait(0.2) do
        pcall(function()
            for _, j in ipairs(__DIO_BuyJobs) do
                if __DIO_FlagGet(j.flag) == true then
                    __DIO_BuyMeleeStep(j)
                    return -- moi luc chi xu ly 1 teacher (toggle dau tien dang bat)
                end
            end
        end)
    end
end, "L14110")
Tabs.Shop:AddSection("Accessory")
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Tomoe Ring"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Tomoe Ring")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Black Cape"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Black Cape")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Swordsman Hat"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Swordsman Hat")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Bizarre Rifle"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("Ectoplasm","Buy", 1)
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Ghoul Mask"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("Ectoplasm","Buy", 2)
end})
Tabs.Shop:AddSection("Weapon World1")
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Cutlass"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Cutlass")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Katana"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Katana")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Iron Mace"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Iron Mace")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Duel Katana"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Duel Katana")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Triple Katana"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Triple Katana")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Pipe"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Pipe")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Dual-Headed Blade"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Dual-Headed Blade")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Bisento"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Bisento")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Soul Cane"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Soul Cane")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Slingshot"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Slingshot")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Musket"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Musket")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Dual Flintlock"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Dual Flintlock")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Flintlock"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Flintlock")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Refined Flintlock"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Refined Flintlock")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Cannon"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BuyItem","Cannon")
end})
Tabs.Shop:AddButton({
Name = __DIO_T["Buy Kabucha"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BlackbeardReward","Slingshot","2")
end})
Tabs.Shop:AddSection("Volcanic Crafting")
Tabs.Shop:AddButton({
Name = __DIO_T["Craft Dragonheart"],
Description = "",
Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "Dragonheart"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Shop:AddButton({
Name = __DIO_T["Craft Dragonstorm"],
Description = "",
Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "Dragonstorm"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Shop:AddButton({
    Name = __DIO_T["Craft Dino Hood"],
    Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "DinoHood"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Shop:AddButton({
    Name = __DIO_T["Craft T-Rex Skull"],
    Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "TRexSkull"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
__DIO_SafeLoop(function()
    local RF = __SVC_RS.Modules.Net["RF/Craft"]
    while __DIO_wait(1) do
        if getgenv().AutoCraftVolcanic then
            pcall(function()
                RF:InvokeServer(
                    "PossibleHardcode",
                    "Volcanic Magnet"
                )
            end)
            getgenv().AutoCraftVolcanic = false
        end
    end
end, "L10352")

Tabs.Shop:AddSection("Crafting Sea Event")
Tabs.Shop:AddButton({
Name = __DIO_T["Craft SharkTooth"],
Description = "",
Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "SharkTooth"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Shop:AddButton({
Name = __DIO_T["Craft TerrorJaw"],
Description = "",
Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "TerrorJaw"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Shop:AddButton({
Name = __DIO_T["Craft SharkAnchor"],
Description = "",
Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "SharkAnchor"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Shop:AddButton({
Name = __DIO_T["Craft LeviathanCrown"],
Description = "",
Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "LeviathanCrown"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Shop:AddButton({
Name = __DIO_T["Craft LeviathanShield"],
Description = "",
Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "LeviathanShield"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Shop:AddButton({
Name = __DIO_T["Craft LeviathanBoat"],
Description = "",
Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "LeviathanBoat"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Shop:AddButton({
Name = __DIO_T["Craft LegendaryScroll"],
Description = "",
Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "LegendaryScroll"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Shop:AddButton({
Name = __DIO_T["Craft MythicalScroll"],
Description = "",
Callback = function()
        local args = {
            [1] = "CraftItem",
            [2] = "Craft",
            [3] = "MythicalScroll"
        }
        __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
    end
})
Tabs.Misc:AddSection("Server - Function")
Tabs.Misc:AddButton({
    Name = __DIO_T["Redeem All Codes"],
    Description = "",
    Callback = function()
        local codes = {
            "LIGHTNINGABUSE","1LOSTADMIN","ADMINFIGHT","GIFTING_HOURS","NOMOREHACK",
            "BANEXPLOIT","WildDares","BossBuild","GetPranked","EARN_FRUITS",
            "SUB2GAMERROBOT_RESET1","KITT_RESET","Bignews","CHANDLER","Fudd10",
            "fudd10_v2","Sub2UncleKizaru","FIGHT4FRUIT","kittgaming","TRIPLEABUSE",
            "Sub2CaptainMaui","Sub2Fer999","Enyu_is_Pro","Magicbus","JCWK",
            "Starcodeheo","Bluxxy","SUB2GAMERROBOT_EXP1","Sub2NoobMaster123",
            "Sub2Daigrock","Axiore","TantaiGaming","StrawHatMaine","Sub2OfficialNoobie",
            "TheGreatAce","JULYUPDATE_RESET","ADMINHACKED","SEATROLLING","24NOADMIN",
            "ADMIN_TROLL","NEWTROLL","SECRET_ADMIN","staffbattle","NOEXPLOIT",
            "NOOB2ADMIN","CODESLIDE","fruitconcepts","krazydares"
        }
        local ReplicatedStorage = __SVC_RS
        local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
        local RedeemRemote = RemotesFolder:FindFirstChild("Redeem")
        local __commF = RemotesFolder:FindFirstChild("CommF_")
        if not RedeemRemote and not __commF then
            return
        end
        for _, code in ipairs(codes) do
            __DIO_wait(0)
            pcall(function()
                if RedeemRemote and RedeemRemote.InvokeServer then
                    RedeemRemote:InvokeServer(code)
                elseif RedeemRemote then
                    RedeemRemote:FireServer(code)
                elseif __commF then
                    __commF:InvokeServer("Redeem", code)
                end
            end)
        end
    end
})
Tabs.Misc:AddButton({
Name = __DIO_T["Rejoin Server"],
Description = "",
Callback = function()
  __SVC_TP:Teleport(game.PlaceId, game.Players.LocalPlayer)
end})
Tabs.Misc:AddButton({
    Name = __DIO_T["Hop Server"],
    Description = "",
    Callback = function()
        task.spawn(function()
            local HttpService = __SVC_HTTP
            local TeleportService = __SVC_TP
            local PlaceId = game.PlaceId
            local Players = __SVC_PLR
            local success, servers = pcall(function()
                local url = "https://games.roblox.com/v1/games/"..PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
                local response = game:HttpGet(url)
                return HttpService:JSONDecode(response).data
            end)
            if success and servers then
                local targetServer
                for _, s in pairs(servers) do
                    if s.playing < s.maxPlayers then
                        targetServer = s.id
                    end
                end
                if targetServer then
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(PlaceId, targetServer, Players.LocalPlayer)
                    end)
                end
            end
        end)
    end
})
Tabs.Misc:AddButton({
Name = __DIO_T["Hop to Lowest Players"],
Description = "",
Callback = function()
  local Http = __SVC_HTTP
  local TPS = __SVC_TP
  local Api = "https://games.roblox.com/v1/games/"
  local _place = game.PlaceId
  local _servers = Api.._place.."/servers/Public?sortOrder=Asc&limit=100"
   function ListServers(cursor)
     local Raw = game:HttpGet(_servers .. ((cursor and "&cursor="..cursor) or ""))
     return Http:JSONDecode(Raw)
   end
   local Server, Next
   local tries = 0
   repeat
     tries = tries + 1
     local ok, Servers = pcall(ListServers, Next)
     if ok and Servers and Servers.data then
       Server = Servers.data[1]
       Next = Servers.nextPageCursor
     else
       Next = nil
     end
   until Server or tries >= 8 or not Next
   if Server then TPS:TeleportToPlaceInstance(_place,Server.id,plr) end
end})
Tabs.Misc:AddButton({
Name = __DIO_T["Hop to Lowest Pings Server"],
Description = "",
Callback = function()
local HTTPService = __SVC_HTTP
local TeleportService = __SVC_TP
local StatsService = __SVC_STAT
local function fetchServersData(placeId, limit)
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?limit=%d", placeId, limit)
    local success, response = pcall(function()
        return HTTPService:JSONDecode(game:HttpGet(url))
    end)
  if success and response and response.data then
	return response.data
  end
    return nil
  end
  local placeId = game.PlaceId
  local serverLimit = 100
  local servers = fetchServersData(placeId, serverLimit)
  if not servers then return end
  local lowestPingServer = servers[1]
  for _, server in pairs(servers) do
    if server["ping"] and lowestPingServer["ping"] and server["ping"] < lowestPingServer["ping"] and server.maxPlayers > server.playing then
      lowestPingServer = server
    end
  end
  local commonLoadTime = 0.5
  __DIO_wait(commonLoadTime)
  local pingThreshold = 100
  local serverStats = StatsService.Network.ServerStatsItem
  local pingValue = 0
  do
      local __okDP, __dp = pcall(function()
          return serverStats["Data Ping"]:GetValueString():match("(%d+)")
      end)
      if __okDP and __dp then pingValue = tonumber(__dp) or 0 end
  end
  if pingValue >= pingThreshold then
    TeleportService:TeleportToPlaceInstance(placeId, lowestPingServer.id)
  end
end})
local replicated = __SVC_RS
Tabs.Misc:AddTextBox({
    Name = __DIO_T["Input Job Id"],
    Placeholder = "Job ID",
    ClearOnFocus = true,
    Callback = function(Value)
        getgenv().Job = Value
    end
})
Tabs.Misc:AddButton({
    Name = __DIO_T["Teleport [Job ID]"],
    Callback = function()
        if getgenv().Job and getgenv().Job ~= "" then
            __SVC_TP
                :TeleportToPlaceInstance(
                    game.PlaceId,
                    getgenv().Job,
                    game.Players.LocalPlayer
                )
        end
    end
})
Tabs.Misc:AddButton({
Name = __DIO_T["Copy JobID"],
Description = "",
Callback = function()
  pcall(function() setclipboard(tostring(game.JobId)) end)
end})
Tabs.Misc:AddSection("Player Gui / Others")
Tabs.Misc:AddButton({
Name = __DIO_T["Open Awakenings Expert"],
Description = "",
Callback = function()
  local __mainAW = plr.PlayerGui:FindFirstChild("Main")
  local __aw = __mainAW and __mainAW:FindFirstChild("AwakeningToggler")
  if __aw then __aw.Visible = true end
end})
Tabs.Misc:AddButton({
Name = __DIO_T["Open Title Selection"],
Description = "",
Callback = function()
  pcall(function() replicated.Remotes.CommF_:InvokeServer("getTitles",true) end)
  local __mainTS = plr.PlayerGui:FindFirstChild("Main")
  local __titles = __mainTS and __mainTS:FindFirstChild("Titles")
  if __titles then __titles.Visible = true end
end})
Tabs.Misc:AddToggle({
Name = __DIO_T["Disable Chat GUI"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Rechat = Value
  if  _G.Rechat == true then
    local StarterGui = game:GetService('StarterGui')
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
  else
    local StarterGui = game:GetService('StarterGui')
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
  end
end
})
Tabs.Misc:AddToggle({
Name = __DIO_T["Disable Leader Board GUI"],
Description = "",
Default = false,
Callback = function(Value)
  ReLeader = Value
  if ReLeader == true then
    local StarterGui = game:GetService('StarterGui')
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
  elseif ReLeader == false then
    local StarterGui = game:GetService('StarterGui')
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
  end
end
})
Tabs.Misc:AddButton({
Name = __DIO_T["Set Pirate Team"],
Description = "",
Callback = function()
  Pirates()
end})
Tabs.Misc:AddButton({
Name = __DIO_T["Set Marine Team"],
Description = "",
Callback = function()
  Marines()
end})
Tabs.Misc:AddToggle({
Name = __DIO_T["Unlock All Portals"],
Description = "",
Default = false,
Callback = function(Value)
  _G.PortalUnLock = Value
end})
CstlePos_Miti = CFrame.new(-5072.08984375, 314.5412902832, -3151.1098632812)
Man3Pos_Miti = CFrame.new(-12471.169921875, 374.94024658203, -7551.677734375)
HydraPos_Miti = CFrame.new(5748.7587890625, 610.44982910156, -267.81704711914)
HydratoCastle = CFrame.new(-5036.0, 315.0, -3179.0)
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.PortalUnLock then
         if Attack.Pos(CstlePos_Miti,8) then
           replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-12471.169921875, 374.94024658203, -7551.677734375))
         elseif Attack.Pos(Man3Pos_Miti,8) then
           replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-5072.08984375, 314.5412902832, -3151.1098632812))
         elseif Attack.Pos(HydraPos_Miti,8) then
           replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(5748.7587890625, 610.44982910156, -267.81704711914))
         elseif Attack.Pos(HydratoCastle,8) then
           replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-5072.08984375, 314.5412902832, -3151.1098632812))
        end
      end
    end)
  end
end, "L14627")
Tabs.Misc:AddSection("Graphics / Haki Stats")
HakiSt = {"State 0","State 1","State 2","State 3","State 4","State 5"}
Tabs.Misc:AddDropdown({
Name = __DIO_T["Select Haki States"],
Options = HakiSt,
Callback = function(Value)
  _G.SelectStateHaki = Value
end})
if _G.SelectStateHaki == nil then _G.SelectStateHaki = "State 1" end
Tabs.Misc:AddButton({
Name = __DIO_T["ChangeBusoStage"],
Description = "",
Callback = function()
  if _G.SelectStateHaki == "State 0" then
    replicated.Remotes.CommF_:InvokeServer("ChangeBusoStage",0)
  elseif _G.SelectStateHaki == "State 1" then
    replicated.Remotes.CommF_:InvokeServer("ChangeBusoStage",1)
  elseif _G.SelectStateHaki == "State 2" then
    replicated.Remotes.CommF_:InvokeServer("ChangeBusoStage",2)
  elseif _G.SelectStateHaki == "State 3" then
    replicated.Remotes.CommF_:InvokeServer("ChangeBusoStage",3)
  elseif _G.SelectStateHaki == "State 4" then
    replicated.Remotes.CommF_:InvokeServer("ChangeBusoStage",4)
  elseif _G.SelectStateHaki == "State 5" then
    replicated.Remotes.CommF_:InvokeServer("ChangeBusoStage",5)
  end
end})
Tabs.SeaEvent:AddButton({
    Name = __DIO_T["Remove Lighting Effect"],
    Callback = function()
        local __atm = __SVC_LIGHT:FindFirstChild("BaseAtmosphere")
        if __atm then __atm:Destroy() end
    end
})
Tabs.Misc:AddButton({
Name = __DIO_T["Turn on increase Boats"],
Description = "",
Callback = function()
  local __boatsIBV5 = workspace:FindFirstChild("Boats")
  if not __boatsIBV5 then return end
  for _, v in pairs(__boatsIBV5:GetDescendants()) do
    local __ownerV = v:FindFirstChild("Owner")
    local __seatV = v:FindFirstChild("VehicleSeat")
    if table.find(ListSeaBoat, v.Name) and __ownerV and __seatV and tostring(__ownerV.Value) == tostring(plr.Name) then
      __seatV.MaxSpeed = 350
      __seatV.Torque = 0.2
      __seatV.TurnSpeed = 5
      __seatV.HeadsUpDisplay = true
    end
  end
end})

Tabs.Misc:AddSection("Fps Booster")
__DIO_PerfSaved = nil
__DIO_PerfTexSaved = {}
__DIO_PerfPartSaved = {}
__DIO_PerfMatSaved = {}
__DIO_PerfSave = function()
    if __DIO_PerfSaved then return end
    local s = {}
    pcall(function()
        s.Ambient = Lighting.Ambient
        s.Brightness = Lighting.Brightness
        s.ColorShift_Top = Lighting.ColorShift_Top
        s.ColorShift_Bottom = Lighting.ColorShift_Bottom
        s.FogEnd = Lighting.FogEnd
        s.FogStart = Lighting.FogStart
        s.GlobalShadows = Lighting.GlobalShadows
        s.Technology = Lighting.Technology
        s.ClockTime = Lighting.ClockTime
    end)
    pcall(function()
        s.QualityLevel = settings().Rendering.QualityLevel
    end)
    pcall(function()
        local t = workspace.Terrain
        s.WaterWaveSize = t.WaterWaveSize
        s.WaterWaveSpeed = t.WaterWaveSpeed
        s.WaterReflectance = t.WaterReflectance
    end)
    pcall(function()
        s.Effects = {}
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") then
                s.Effects[e] = e.Enabled
            end
        end
    end)
    __DIO_PerfSaved = s
end
pcall(__DIO_PerfSave)
__DIO_PerfSetQuality = function(lvl)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel[lvl] or Enum.QualityLevel.Level10 end)
end
__DIO_PerfEffects = function(off)
    pcall(function()
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("PostEffect") and e.Name ~= "__DIO_RTX_CC" then
                if off then
                    e.Enabled = false
                else
                    pcall(function()
                        local sv = __DIO_PerfSaved and __DIO_PerfSaved.Effects
                        if sv == nil then
                            e.Enabled = true
                        elseif sv[e] ~= nil then
                            e.Enabled = sv[e] and true or false
                            if e:IsA("ColorCorrectionEffect") then
                                local __tc = e.TintColor
                                if __tc and __tc.R >= 0.5 and __tc.G <= 0.35 and __tc.B <= 0.35 then
                                    e.TintColor = Color3.new(1, 1, 1)
                                end
                            end
                        end
                    end)
                end
            end
        end
    end)
end
__DIO_PerfParticles = function()
    pcall(function()
        local scope = workspace.Map or workspace
        for _, d in ipairs(scope:GetDescendants()) do
            if d:IsA("ParticleEmitter") or d:IsA("Trail") then
                if __DIO_PerfPartSaved[d] == nil then
                    __DIO_PerfPartSaved[d] = {e = d.Enabled, lt = d.Lifetime}
                end
                pcall(function() d.Enabled = false end)
            elseif d:IsA("Sparkles") or d:IsA("Smoke") or d:IsA("Fire") then
                if __DIO_PerfPartSaved[d] == nil then
                    __DIO_PerfPartSaved[d] = {e = d.Enabled}
                end
                pcall(function() d.Enabled = false end)
            end
        end
    end)
end
__DIO_PerfMaterials = function()
    pcall(function()
        for _, zx in next, workspace:GetDescendants() do
            if table.find(Past, zx.ClassName) then
                if __DIO_PerfMatSaved[zx] == nil then
                    __DIO_PerfMatSaved[zx] = {m = zx.Material, r = zx.Reflectance}
                end
                pcall(function() zx.Material = "Plastic" zx.Reflectance = 0 end)
            end
        end
    end)
end
__DIO_PerfTextures = function()
    pcall(function()
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("Decal") or d:IsA("Texture") then
                if __DIO_PerfTexSaved[d] == nil then
                    __DIO_PerfTexSaved[d] = d.Transparency
                end
                pcall(function() d.Transparency = 1 end)
            end
        end
    end)
end
__DIO_PerfUndoAssets = function()
    pcall(function()
        for d, v in pairs(__DIO_PerfTexSaved or {}) do
            if typeof(d) == "Instance" and d.Parent then pcall(function() d.Transparency = v end) end
        end
    end)
    pcall(function()
        for d, v in pairs(__DIO_PerfPartSaved or {}) do
            if typeof(d) == "Instance" and d.Parent then
                pcall(function()
                    d.Enabled = v.e
                    if v.lt then pcall(function() d.Lifetime = v.lt end) end
                end)
            end
        end
    end)
    pcall(function()
        for d, v in pairs(__DIO_PerfMatSaved or {}) do
            if typeof(d) == "Instance" and d.Parent then
                pcall(function() d.Material = v.m d.Reflectance = v.r end)
            end
        end
    end)
    __DIO_PerfTexSaved = {}
    __DIO_PerfPartSaved = {}
    __DIO_PerfMatSaved = {}
end
__DIO_ApplyPerf = function(mode)
    __DIO_PerfSave()
    if mode == "OFF" or mode == nil then
        local s = __DIO_PerfSaved
        pcall(function()
            if _G.RTXMode ~= true then
                for _, __cc in ipairs(Lighting:GetChildren()) do
                    if __cc.Name == "__DIO_RTX_CC" then __cc:Destroy() end
                end
                local __rc = plr.Character
                local __rp = __rc and __rc:FindFirstChild("HumanoidRootPart")
                local __pl = __rp and __rp:FindFirstChild("PointLight")
                if __pl and __pl.Color == Color3.fromRGB(217, 145, 57) then __pl:Destroy() end
            end
        end)
        pcall(function() if bright ~= true and s and s.Ambient then Lighting.Ambient = s.Ambient end end)
        pcall(function() if bright ~= true and s and s.ColorShift_Top then Lighting.ColorShift_Top = s.ColorShift_Top end end)
        pcall(function() if bright ~= true and s and s.ColorShift_Bottom then Lighting.ColorShift_Bottom = s.ColorShift_Bottom end end)
        pcall(function() if s and s.Brightness then Lighting.Brightness = s.Brightness end end)
        pcall(function() if s and s.FogEnd then Lighting.FogEnd = s.FogEnd end end)
        pcall(function() if s and s.FogStart then Lighting.FogStart = s.FogStart end end)
        pcall(function() if s and s.GlobalShadows ~= nil then Lighting.GlobalShadows = s.GlobalShadows end end)
        pcall(function() if s and s.ClockTime then Lighting.ClockTime = s.ClockTime end end)
        pcall(function() if s and s.Technology then Lighting.Technology = s.Technology end end)
        pcall(function()
            local t = workspace.Terrain
            if s then
                if s.WaterWaveSize then t.WaterWaveSize = s.WaterWaveSize end
                if s.WaterWaveSpeed then t.WaterWaveSpeed = s.WaterWaveSpeed end
                if s.WaterReflectance then t.WaterReflectance = s.WaterReflectance end
            end
        end)
        pcall(function() if s and s.QualityLevel then settings().Rendering.QualityLevel = s.QualityLevel end end)
        __DIO_PerfEffects(false)
        __DIO_PerfUndoAssets()
        pcall(function() if setfpscap then setfpscap(60) end end)
        return
    end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.FogStart = 0
    end)
    pcall(function()
        local t = workspace.Terrain
        t.WaterWaveSize = 0
        t.WaterWaveSpeed = 0
        t.WaterReflectance = 0
    end)
    __DIO_PerfEffects(true)
    if mode == "Fps 30-40" or mode == "Fps 40-60" or mode == "Delete All (40-45 Fps) " then
        __DIO_PerfSetQuality("Level08")
        task.spawn(__DIO_PerfParticles)
        task.spawn(__DIO_PerfMaterials)
    end
    if mode == "Fps 40-60" or mode == "Delete All (40-45 Fps) " then
        __DIO_PerfSetQuality("Level04")
        pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
        task.spawn(__DIO_PerfTextures)
        pcall(function()
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("ParticleEmitter") then
                    pcall(function() d.Lifetime = NumberRange.new(0) end)
                elseif d:IsA("Explosion") then
                    pcall(function() d.BlastPressure = 1 d.BlastRadius = 1 end)
                end
            end
        end)
    end
    if mode == "Delete All (40-45 Fps) " then
        __DIO_PerfSetQuality("Level01")
        pcall(function() if setfpscap then setfpscap(999) end end)
    end
end
Tabs.Misc:AddDropdown({
    Name = __DIO_T["FIX LAG "],
    Description = "Note that these are fixed parameters that may change",
    Options = {"OFF", "Fps 30-60", "Fps 30-40", "Fps 40-60", "Delete All (40-45 Fps) "},
    Default = "OFF",
    Callback = function(Value)
        __DIO_ApplyPerf(Value)
    end
})
Tabs.Misc:AddToggle({
Name = __DIO_T["Turn on RTX Mode"],
Description = "",
Default = false,
Callback = function(Value)
  _G.RTXMode = Value
  local a = game.Lighting
  local function __DIO_RTXRevert()
    pcall(function()
      a.Ambient = OldAmbient or Color3.new(0, 0, 0)
      a.Brightness = OldBrightness or 1
      a.ColorShift_Top = OldColorShift_Top or Color3.new(0, 0, 0)
      if OldBrightnessc ~= nil then for _, __cc in ipairs(a:GetChildren()) do
          if __cc.Name == "__DIO_RTX_CC" then
            if __cc.Contrast ~= nil and __cc.Brightness ~= nil then
              __cc.Contrast = OldContrastc; __cc.Brightness = OldBrightnessc
              __cc.TintColor = OldTintColorc
            end
          end
        end end
      a.FogEnd = 2500
      if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
        local __pl = plr.Character.HumanoidRootPart:FindFirstChild("PointLight")
        if __pl then __pl:Destroy() end
      end
      for _, __cc in ipairs(a:GetChildren()) do
        if __cc.Name == "__DIO_RTX_CC" then __cc:Destroy() end
      end
    end)
  end
  if not _G.RTXMode then
    __DIO_RTXRevert()
    return
  end
  for _, __oldcc in ipairs(a:GetChildren()) do
    if __oldcc.Name == "__DIO_RTX_CC" then __oldcc:Destroy() end
  end
  local c = Instance.new("ColorCorrectionEffect", a)
  local e = Instance.new("ColorCorrectionEffect", a)
  c.Name = "__DIO_RTX_CC"; e.Name = "__DIO_RTX_CC"
  OldAmbient = a.Ambient
  OldBrightness = a.Brightness
  OldColorShift_Top = a.ColorShift_Top
  OldBrightnessc = c.Brightness
  OldContrastc = c.Contrast
  OldTintColorc = c.TintColor
  task.spawn(function()
    while _G.RTXMode do
      __DIO_wait(1)
      pcall(function()
        a.Ambient = Color3.fromRGB(33, 33, 33)
        a.Brightness = 0.3
        c.Brightness = 0.176
        c.Contrast = 0.39
        c.TintColor = Color3.fromRGB(217, 145, 57)
        a.FogEnd = 999
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and not plr.Character.HumanoidRootPart:FindFirstChild("PointLight") then
          local a2 = Instance.new("PointLight")
          a2.Parent = plr.Character.HumanoidRootPart
          a2.Range = 15
          a2.Color = Color3.fromRGB(217, 145, 57)
        end
      end)
    end
    __DIO_RTXRevert()
  end)
end
})
Tabs.Misc:AddButton({
Name = __DIO_T["Turn on Fast Mode"],
Description = "",
Callback = function()
  for _,zx in next, workspace:GetDescendants() do
  if table.find(Past, zx.ClassName) then  zx.Material = "Plastic" end
  end
end})
Tabs.Misc:AddButton({
Name = __DIO_T["Turn on Low CPU"],
Description = "",
Callback = function()
  LowCpu()
end})
Tabs.Misc:AddButton({
Name = __DIO_T["No Fog"],
Description = "",
Callback = function()
  if Lighting:FindFirstChild("LightingLayers") then Lighting.LightingLayers:Destroy() end
  if Lighting:FindFirstChild("SeaTerrorCC") then Lighting.SeaTerrorCC:Destroy() end
  if Lighting:FindFirstChild("FantasySky") then Lighting.FantasySky:Destroy() end
end})
Tabs.Misc:AddToggle({
Name = __DIO_T["Turn on Full Bright"],
Description = "",
Default = true,
Callback = function(Value)
  bright = Value
  if Value == true then
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
    Lighting.ColorShift_Top = Color3.new(1, 1, 1)
  else
    Lighting.Ambient = Color3.new(0, 0, 0)
    Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
    Lighting.ColorShift_Top = Color3.new(0, 0, 0)
  end
end
})
Tabs.Misc:AddToggle({
    Name = __DIO_T["Remove Hit VFX"],
    Description = "Removes slash and sword visual effects for better visibility",
    Default = false,
    Callback = function(Value)
        _G.DestroyHit = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
local HitEffects = {"SlashHit", "CurvedRing", "SwordSlash", "SlashTail"}
__DIO_SafeLoop(function()
    while __DIO_wait(Sec) do
        if _G.DestroyHit then
            pcall(function()
                do
                    local __woHV = workspace:FindFirstChild("_WorldOrigin")
                    if __woHV then
                        for _, v in pairs(__woHV:GetChildren()) do
                            if table.find(HitEffects, v.Name) then
                                v:Destroy()
                            end
                        end
                    end
                end
            end)
        end
    end
end, "L14837")
Tabs.Misc:AddToggle({
Name = __DIO_T["Remove Death & Respawned VFX"],
Description = "",
Default = true,
Callback = function(Value)
  RDeath = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if RDeath then
	  if replicated.Effect.Container:FindFirstChild("Death") then replicated.Effect.Container.Death:Destroy() end
      if replicated.Effect.Container:FindFirstChild("Respawn") then replicated.Effect.Container.Respawn:Destroy() end
	  end
    end)
  end
end, "L14857")
Tabs.Misc:AddToggle({
Name = __DIO_T["Disable Notify"],
Description = "",
Default = false,
Callback = function(Value)
  RemoveDamage = Value
end})
local __DIO_NotifyPrev = nil
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      local __dc = replicated.Assets and replicated.Assets.GUI and replicated.Assets.GUI.DamageCounter
      local __nt = plr.PlayerGui and plr.PlayerGui:FindFirstChild("Notifications")
      if RemoveDamage then
        if __dc and __dc.Enabled ~= false then __dc.Enabled = false end
        if __nt and __nt.Enabled ~= false then __nt.Enabled = false end
        __DIO_NotifyPrev = false
      else
        local __needRestore = (__DIO_NotifyPrev == nil) or (__DIO_NotifyPrev == false)
        if __needRestore then
          if __dc and __dc.Enabled ~= true then __dc.Enabled = true end
          if __nt and __nt.Enabled ~= true then __nt.Enabled = true end
        end
        __DIO_NotifyPrev = true
      end
    end)
  end
end, "L14876")

pcall(function()
    local u = game:GetService("ReplicatedStorage"):FindFirstChild("Util")
    u = u and u:FindFirstChild("CameraShaker")
    if u then
        CameraShakerR = require(u)
        if CameraShakerR and CameraShakerR.Stop then CameraShakerR:Stop() end
    end
end)

__DIO_3nn_M1N = 1
-- [DIO-GRAFT Banana] Da xoa __FA_GetTargets + remote cache cu: M1 moi dung
-- CombatUtil (loc rig/vulnerable) thay cho viec ban RegisterHit mu theo khoang cach.

__DIO_3nn_FruitM1 = function(target)
    local char = plr.Character
    local hrp = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
    if not hrp or not target or not target.Parent then return false end
    local tgtPos = (target.PrimaryPart and target.PrimaryPart.Position)
        or (target:FindFirstChild("HumanoidRootPart") and target.HumanoidRootPart.Position)
    if not tgtPos then return false end
    local fruitName
    pcall(function()
        for _, cont in ipairs({ plr.Backpack, char }) do
            for _, t in ipairs(cont:GetChildren()) do
                if t:IsA("Tool") and t.ToolTip == "Blox Fruit" then fruitName = t.Name break end
            end
            if fruitName then break end
        end
    end)
    local tool = fruitName and char:FindFirstChild(fruitName)
    if not tool then return false end
    local leftRemote = tool:FindFirstChild("LeftClickRemote")
    local remoteFn = tool:FindFirstChild("RemoteFunction")
    local remoteEv = tool:FindFirstChild("RemoteEvent")
    if not leftRemote and remoteFn then
        if remoteEv then pcall(function() remoteEv:FireServer(tgtPos) end) end
        pcall(function() remoteFn:InvokeServer("TAP") end)
        return true
    end
    if leftRemote and fruitName == "Mammoth-Mammoth" then
        pcall(function() leftRemote:FireServer(tgtPos) end)
        return true
    end
    if leftRemote then
        __DIO_3nn_M1N = (__DIO_3nn_M1N % 5) + 1
        pcall(function() leftRemote:FireServer((tgtPos - hrp.Position).Unit, __DIO_3nn_M1N) end)
        return true
    end
    return false
end

-- [DIO-GRAFT Banana] Combat M1 chuan CombatUtil (port AttackAOE/attackMelee):
-- lay hit part bang getBladeHits cua game (__DSKA_BladeHits da port san), loc rig
-- bang CombatUtil:GetRigOfHitPart + IsVulnerable, danh dung combo/animation cua
-- vu khi (RegisterAttack theo Length/SpeedMult). Toggle "Attack No Animation"
-- thi ban RegisterAttack(0) khong play anim. Ban cu ban FireServer(0) mu moi
-- frame -> hit bi server reject hang loat, ton remote/FPS va de gay lag mob.
-- [M1CORE BEGIN]
local __DIO_M1CU_Cache = nil
__DIO_M1CU = function()
    if __DIO_M1CU_Cache then return __DIO_M1CU_Cache end
    local __okCU, __cu = pcall(function() return require(__SVC_RS.Modules.CombatUtil) end)
    if __okCU and type(__cu) == "table" then
        __DIO_M1CU_Cache = __cu
        return __cu
    end
    return nil
end
local __DIO_M1AtkEv, __DIO_M1HitEv
__DIO_M1Remotes = function()
    if __DIO_M1AtkEv and __DIO_M1AtkEv.Parent and __DIO_M1HitEv and __DIO_M1HitEv.Parent then
        return __DIO_M1AtkEv, __DIO_M1HitEv
    end
    local __modM1 = __SVC_RS:FindFirstChild("Modules")
    local __netM1 = __modM1 and __modM1:FindFirstChild("Net")
    if not __netM1 then return nil, nil end
    __DIO_M1AtkEv = __netM1:FindFirstChild("RE/RegisterAttack")
    __DIO_M1HitEv = __netM1:FindFirstChild("RE/RegisterHit")
    return __DIO_M1AtkEv, __DIO_M1HitEv
end
local __DIO_M1HitPartNames = {
    RightUpperArm = true, RightLowerArm = true, RightHand = true,
    RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
    LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
    LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
    UpperTorso = true, LowerTorso = true, Head = true,
}
__DIO_M1BusyUntil = 0
__DIO_M1Combo = 0
__DIO_M1LastCall = 0
__DIO_M1AOE = function(range, includeChars)
    local CU = __DIO_M1CU()
    if not CU then return nil end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hrp then return nil end
    if type(__DSKA_BladeHits) ~= "function" then return nil end
    local out, seen = {}, {}
    local parts = __DSKA_BladeHits(char, { hrp }, tonumber(range) or 65, includeChars == true)
    for _, P in ipairs(parts) do
        local __okR, rig = pcall(function() return CU:GetRigOfHitPart(P) end)
        if __okR and rig and not seen[rig] and __DIO_M1HitPartNames[P.Name] then
            local __okV, vul = pcall(function() return CU:IsVulnerable(rig) end)
            if __okV and vul then
                local __sumRig = rig:FindFirstChild("Summoner")
                local __sumMe = char:FindFirstChild("Summoner")
                local __mePlr = __SVC_PLR:GetPlayerFromCharacter(char)
                if rig ~= char
                    and (not __sumMe or not __sumMe.Value or rig ~= __sumMe.Value.Character)
                    and (not __mePlr or not __sumRig or __sumRig.Value ~= __mePlr) then
                    table.insert(out, { rig, P })
                    seen[rig] = true
                end
            end
        end
    end
    if #out > 0 then return out end
    return nil
end
__DIO_M1AppendTarget = function(hits, target, range)
    -- Muc tieu chi dinh nam ngoai Enemies (SeaBeast/Leviathan o SeaBeasts) thi
    -- getBladeHits khong thay -> chen tay de giu hanh vi danh boss bien nhu cu.
    if not target or not target.Parent then return hits end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local tr = target:FindFirstChild("HumanoidRootPart")
    if not hrp or not tr then return hits end
    if hits then
        for _, h in ipairs(hits) do
            if h[1] == target then return hits end
        end
    end
    local __rA = (tonumber(range) or 65) + tr.Size.X * 0.5
    if (tr.Position - hrp.Position).Magnitude > 10 + __rA + tr.Size.X * 0.5 then return hits end
    local __partA = nil
    if type(__DSKA_PartsNear) == "function" then
        local __psA = __DSKA_PartsNear(target, hrp.Position, __rA)
        for _, __pA in ipairs(__psA) do
            if __DIO_M1HitPartNames[__pA.Name] then __partA = __pA break end
        end
        if not __partA then __partA = __psA[1] end
    end
    hits = hits or {}
    table.insert(hits, 1, { target, __partA or tr })
    return hits
end
__DIO_M1Attack = function(range, target)
    local char = plr.Character
    if not char then return end
    local stun = char:FindFirstChild("Stun")
    if stun and stun.Value ~= 0 then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    local atkEv, hitEv = __DIO_M1Remotes()
    if not atkEv or not hitEv then return end
    local hits = __DIO_M1AOE(range, false)
    hits = __DIO_M1AppendTarget(hits, target, range)
    if not hits or #hits == 0 then return end
    local CU = __DIO_M1CU()
    if _G.AttackNoAnim or not CU then
        atkEv:FireServer(0)
        hitEv:FireServer(hits[1][2], hits)
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local __okA, animCache = pcall(function() return CU:GetMovesetAnimCache(hum) end)
    if not __okA or not animCache then return end
    local __okW, wName = pcall(function() return CU:GetWeaponName(tool) end)
    if not __okW or not wName then return end
    local __okD, wData = pcall(function() return CU:GetWeaponData(wName) end)
    if not __okD or not wData or not wData.Moveset or not wData.Moveset.Basic then return end
    local __okC, canAtk = pcall(function() return CU:CanAttack(char, wData.WeaponType) end)
    if not __okC or not canAtk then return end
    __DIO_M1Combo = __DIO_M1Combo + 1
    if __DIO_M1Combo > #wData.Moveset.Basic then __DIO_M1Combo = 1 end
    local __okP, pureName = pcall(function() return CU:GetPureWeaponName(wName) end)
    if not __okP or not pureName then return end
    local track = animCache[pureName .. "-basic" .. __DIO_M1Combo]
    if not track then return end
    local spdMult = 1
    pcall(function() spdMult = tonumber(track:GetAttribute("SpeedMult")) or 1 end)
    if spdMult <= 0 then spdMult = 1 end
    local durAtk = (tonumber(track.Length) or 0.3) / spdMult
    atkEv:FireServer(durAtk)
    hitEv:FireServer(hits[1][2], hits)
    pcall(function() track:Play(0.100000001, 1, 1 * spdMult) end)
    __DIO_M1BusyUntil = tick() + durAtk
end
-- [M1CORE END]

__DIO_3nn_M1 = function(target, range)
    -- [DIO-GRAFT Banana] M1 moi: CombatUtil pipeline (xem khoi M1CORE o tren).
    -- Giu nguyen chu ky (target, range) nen toan bo noi goi cu khong phai sua.
    local __nowM1 = tick()
    if _G.AttackNoAnim then
        if (__nowM1 - (__DIO_M1LastCall or 0)) < 0.05 then return end
    elseif __nowM1 < (__DIO_M1BusyUntil or 0) then
        return
    end
    local char = plr.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 or hum.Sit then return end
    if target then
        local th = target:FindFirstChildOfClass("Humanoid")
        if th and th.Health <= 0 then return end
        local tr = target:FindFirstChild("HumanoidRootPart")
        if tr then
            local __dXZ = Vector3.new(hrp.Position.X - tr.Position.X, 0, hrp.Position.Z - tr.Position.Z).Magnitude
            if __dXZ > (__DIO_HitRange and __DIO_HitRange(70) or 70) then return end
        end
    end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool and tool.ToolTip == "Blox Fruit" and target then
        if __DIO_3nn_FruitM1(target) then
            __DIO_M1LastCall = __nowM1
            return
        end
    end
    __DIO_M1LastCall = __nowM1
    __DIO_M1Attack(tonumber(range) or 65, target)
end

-- "Fast Attack Mob" (Banana CombatUtil)
-- Toggle "Fast Attack Mob" (Default = false): BAT thi vong Heartbeat danh AOE
-- quanh nguoi bang CHINH pipeline M1 moi (loc rig/vulnerable, nhip anim that
-- hoac No Animation tuy toggle). Ban cu ban RegisterHit mu moi frame voi
-- Rate 2e-15 (spam remote, de drop FPS/lag mob) -> da xoa __DIO_FA_Remotes /
-- __DIO_FA_GetTargets, chi con 1 duong danh duy nhat __DIO_3nn_M1.
__DIO_FastAttack = {
    Enabled = true,
    Range = 75,
}
pcall(function() if __DIO_FA_Conn then __DIO_FA_Conn:Disconnect() end end)
__DIO_FA_Conn = __SVC_RUN.Heartbeat:Connect(function()
    if _G.FastAttackMob ~= true then return end
    if not __DIO_FastAttack.Enabled then return end
    pcall(__DIO_3nn_M1, nil, __DIO_FastAttack.Range)
end)

getBeastHunter = function()
    local character = plr.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return nil end
    local hrp = character.HumanoidRootPart
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and string.find(obj.Name, "Beast Hunter") then
            local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if root then
                if (root.Position - hrp.Position).Magnitude <= 1000 then
                    return obj
                end
            end
        end
    end
    return nil
end
Window:Notify({
  Title = "DIO hub",
  Content = "DIO Hub Load....",
  Image = "rbxassetid://105848560127717",
  Duration = 5
})
Window:Notify({
   Title = "Join Discord For new Update Hub",
   Content = "link in Tab Info",
   Image = "rbxassetid://105848560127717",
   Duration = 7
})
Tabs.Webhook:AddSection("Webhook")
_G.WebhookUrl = GetSetting("UI/Webhook/Input Url Webhook", "") or ""
_G.WebhookPing = GetSetting("UI/Webhook/Input Discord Ping", "") or ""
_G.PingDiscord = false
_G.WebhookStoreFruit = false
_G.WebhookFindPrehistoric = false
_G.WebhookFindLeviathan = false
_G.WebhookFindMirage = false
__DIO_WH_Brand = {
    Username = "DIO Hub",
    AvatarURL = "https://images-ext-1.discordapp.net/external/9LSZu__Uvs7I0N8MWag-JmwF2iT-pHCHSe2UdixGEXQ/%3Fsize%3D4096/https/cdn.discordapp.com/avatars/1262364141968949308/a_0c5fb64e2cbb35d029d73b44576c6a60.gif",
    BannerURL = "https://cdn.discordapp.com/attachments/1017024488665264218/1262729537578471504/banner_server.jpg",
    Title = "Banana Hub Notification",
    FooterText = "DIO Hub",
    Color = 16776960,
}
__DIO_WH_SafeStr = function(s)
    local ok, v = pcall(function() return tostring(s) end)
    return (ok and v) or "nil"
end
__DIO_WH_PingTag = function()
    if _G.PingDiscord ~= true then return "" end
    local g = _G.WebhookPing
    if g and tonumber(g) then return "<@" .. g .. ">" end
    return "@everyone"
end
__DIO_WH_Req = (syn and syn.request) or request or http_request or (fluxus and fluxus.request) or nil
__DIO_WH_Warned = false
__DIO_WH_Send = function(event, detail, isFruit)
    local url = _G.WebhookUrl
    if not url or url == "" then return end
    local fields
    if isFruit then
        fields = {
            { name = "Stored Fruit", value = "```" .. __DIO_WH_SafeStr(detail) .. "```", inline = false },
            { name = "Username", value = "||" .. __DIO_WH_SafeStr(plr and plr.Name or "Unknown") .. "||", inline = true },
            { name = "Time", value = os.date("%Y-%m-%d %H:%M:%S"), inline = true },
            { name = "PlaceId", value = "`" .. __DIO_WH_SafeStr(game.PlaceId) .. "`", inline = true },
        }
    else
        fields = {
            { name = "Event", value = "`" .. __DIO_WH_SafeStr(event) .. "`", inline = true },
            { name = "Detail", value = "`" .. __DIO_WH_SafeStr(detail) .. "`", inline = true },
            { name = "Username", value = "||" .. __DIO_WH_SafeStr(plr and plr.Name or "Unknown") .. "||", inline = true },
            { name = "PlaceId", value = "`" .. __DIO_WH_SafeStr(game.PlaceId) .. "`", inline = true },
            { name = "JobId", value = "`" .. __DIO_WH_SafeStr(game.JobId) .. "`", inline = true },
        }
    end
    local payload = {
        content = __DIO_WH_PingTag(),
        username = __DIO_WH_Brand.Username,
        avatar_url = __DIO_WH_Brand.AvatarURL,
        embeds = {
            {
                title = __DIO_WH_Brand.Title,
                description = "**Main Status**\nUsername : ||" .. __DIO_WH_SafeStr(plr and plr.Name or "Unknown") .. "||",
                color = __DIO_WH_Brand.Color,
                footer = { text = __DIO_WH_Brand.FooterText },
                fields = fields,
                thumbnail = { url = __DIO_WH_Brand.BannerURL },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            },
        },
    }
    pcall(function()
        if __DIO_WH_Req then
            __DIO_WH_Req({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = __SVC_HTTP:JSONEncode(payload),
            })
        elseif not __DIO_WH_Warned then
            __DIO_WH_Warned = true
            warn("[DIO] Webhook: no request function (need syn.request/request/http_request)")
        end
    end)
end
Tabs.Webhook:AddTextBox({
    Title = __DIO_T["Input Url Webhook"],
    Default = _G.WebhookUrl,
    Placeholder = "https://discord.com/api/webhooks/...",
    Callback = function(Value)
        _G.WebhookUrl = Value or ""
        SetSetting("UI/Webhook/Input Url Webhook", _G.WebhookUrl)
    end
})
Tabs.Webhook:AddTextBox({
    Title = __DIO_T["Input Discord Ping (Everyone/ID)"],
    Default = _G.WebhookPing,
    Placeholder = "Discord user ID (empty = @everyone)",
    Callback = function(Value)
        _G.WebhookPing = Value or ""
        SetSetting("UI/Webhook/Input Discord Ping", _G.WebhookPing)
    end
})
Tabs.Webhook:AddToggle({
    Name = __DIO_T["Ping Everyone/Id Discord"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.PingDiscord = (Value == true)
    end
})
Tabs.Webhook:AddToggle({
    Name = __DIO_T["Webhook Store Fruit"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.WebhookStoreFruit = (Value == true)
    end
})
Tabs.Webhook:AddToggle({
    Name = __DIO_T["Webhook Find Prehistoric Island"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.WebhookFindPrehistoric = (Value == true)
    end
})
Tabs.Webhook:AddToggle({
    Name = __DIO_T["Webhook Find Leviathan"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.WebhookFindLeviathan = (Value == true)
    end
})
Tabs.Webhook:AddToggle({
    Name = __DIO_T["Webhook Find Mirage"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.WebhookFindMirage = (Value == true)
    end
})
__DIO_WH_ArmM, __DIO_WH_ArmV, __DIO_WH_ArmL = true, true, true
__DIO_SafeLoop(function()
    while __DIO_wait(0.5) do
        if _G.WebhookFindMirage or _G.WebhookFindPrehistoric or _G.WebhookFindLeviathan then
            pcall(function()
                local map = workspace:FindFirstChild("Map")
                if _G.WebhookFindMirage then
                    local present = map and map:FindFirstChild("MysticIsland")
                    if not present then
                        __DIO_WH_ArmM = true
                    elseif __DIO_WH_ArmM then
                        __DIO_WH_ArmM = false
                        __DIO_WH_Send("Mirage", "Spawned", false)
                    end
                end
                if _G.WebhookFindPrehistoric then
                    local present = map and map:FindFirstChild("PrehistoricIsland")
                    if not present then
                        __DIO_WH_ArmV = true
                    elseif __DIO_WH_ArmV then
                        __DIO_WH_ArmV = false
                        __DIO_WH_Send("Prehistoric Island", "Spawned", false)
                    end
                end
                if _G.WebhookFindLeviathan then
                    local wo = workspace:FindFirstChild("_WorldOrigin")
                    local loc = wo and wo:FindFirstChild("Locations")
                    local present = loc and loc:FindFirstChild("Frozen Dimension")
                    if not present then
                        __DIO_WH_ArmL = true
                    elseif __DIO_WH_ArmL then
                        __DIO_WH_ArmL = false
                        __DIO_WH_Send("Frozen Dimension", "Spawned", false)
                    end
                end
            end)
        end
    end
end, "L-WH")

pcall(__DIO_QueueAutoExec)
if getgenv().HideUi == true then
    pcall(function() Window:Minimize() end)
end
__DIO_BOOT("DIO HUB READY NOW")
end
__DIO_AutoExecQueued = false
__DIO_QueueAutoExec = function()
    if getgenv().AutoExecutor ~= true then return end
    local __url = getgenv().DIO_SelfUrl
        or "https://raw.githubusercontent.com/huw8592-rgb181816aajbbvaa838377hbba/Script-----------------/refs/heads/main/DIO_Hub.lua"
    local __delay = math.max(0, math.floor(tonumber(getgenv().AutoExecutorDelay) or 30))
    local __esc = function(v)
        local s = tostring(v or ""):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\r", ""):gsub("\n", "")
        return s
    end
    local __lines = {
        "repeat task.wait() until game:IsLoaded()",
        "task.wait(" .. tostring(__delay) .. ")",
        'getgenv().Team = "' .. __esc(getgenv().Team or "Pirates") .. '"',
        "getgenv().SaveSettings = " .. tostring(_G.DIO_AutoSave ~= false),
        'getgenv().Key = "' .. __esc(getgenv().Key) .. '"',
        "getgenv().AutoExecutor = true",
        "getgenv().HideUi = " .. tostring(getgenv().HideUi == true),
    }
    if getgenv().AutoRestoreToggles ~= nil then
        table.insert(__lines, "getgenv().AutoRestoreToggles = " .. tostring(getgenv().AutoRestoreToggles == true))
    end
    if getgenv().AutoExecutorDelay ~= nil then
        table.insert(__lines, "getgenv().AutoExecutorDelay = " .. tostring(__delay))
    end
    if getgenv().MasterySpamDelay ~= nil then
        table.insert(__lines, "getgenv().MasterySpamDelay = " .. tostring(tonumber(getgenv().MasterySpamDelay) or 2))
    end
    if getgenv().DIO_SelfUrl ~= nil then
        table.insert(__lines, 'getgenv().DIO_SelfUrl = "' .. __esc(__url) .. '"')
    end
    table.insert(__lines, 'local __ok, __err = pcall(function() loadstring(game:HttpGet("' .. __esc(__url) .. '"))() end)')
    table.insert(__lines, 'if not __ok then warn("[DIO] AutoExecutor load failed: " .. tostring(__err)) end')
    local __code = table.concat(__lines, "\n")
    local __ok, __err = pcall(function()
        local __q = nil
        if type(queue_on_teleport) == "function" then
            __q = queue_on_teleport
        elseif syn and type(syn.queue_on_teleport) == "function" then
            __q = syn.queue_on_teleport
        end
        if not __q then error("executor khong co queue_on_teleport") end
        __q(__code)
    end)
    if __ok then
        __DIO_AutoExecQueued = true
    else
        warn("[DIO] AutoExecutor ON nhung khong queue duoc: " .. tostring(__err))
    end
end
if getgenv().AutoExecutor == true then
    local __okHook, __errHook = pcall(function()
        local __lp = game:GetService("Players").LocalPlayer
        local __old = getgenv().__DIO_OnTeleportConn
        if __old then pcall(function() __old:Disconnect() end) end
        getgenv().__DIO_OnTeleportConn = __lp.OnTeleport:Connect(function(state)
            if state ~= Enum.TeleportState.Started then return end
            if getgenv().AutoExecutor == true and not __DIO_AutoExecQueued then
                __DIO_QueueAutoExec()
            end
            __DIO_AutoExecQueued = false
        end)
    end)
    if not __okHook then
        warn("[DIO] AutoExecutor khong gan duoc OnTeleport: " .. tostring(__errHook))
    end
end
local function __DIO_SafeStart(where)
    local ok, err = pcall(StartDioHub)
    if not ok then
        pcall(function() __DIO_BOOT("FAILED (" .. tostring(where) .. "): " .. tostring(err)) end)
        warn("[DIO] StartDioHub failed at " .. tostring(where) .. ": " .. tostring(err))
        pcall(function()
            local __pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
            local sg = Instance.new("ScreenGui")
            sg.Name = "DIO_FatalError"
            sg.ResetOnSpawn = false
            sg.Parent = __pg
            local fr = Instance.new("TextButton")
            fr.Size = UDim2.fromOffset(480, 180)
            fr.Position = UDim2.new(0.5, -240, 0.4, -90)
            fr.BackgroundColor3 = Color3.fromRGB(30, 15, 15)
            fr.TextColor3 = Color3.fromRGB(255, 120, 120)
            fr.TextSize = 14
            fr.TextWrapped = true
            fr.Font = Enum.Font.Code
            fr.Text = "DIO HUB - LOI KHI KHOI DONG (bam de tat)\n[" .. tostring(where) .. "]\n\n" .. tostring(err)
            fr.Parent = sg
            fr.MouseButton1Click:Connect(function() sg:Destroy() end)
        end)
    end
    return ok, err
end

local function __DIO_GuiHolders()
    local list = {}
    pcall(function()
        local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(list, pg) end
    end)
    pcall(function() if gethui then local h = gethui() if h then table.insert(list, h) end end end)
    pcall(function() table.insert(list, game:GetService("CoreGui")) end)
    return list
end

local function __DIO_SnapGuis()
    local set = {}
    for _, holder in ipairs(__DIO_GuiHolders()) do
        pcall(function()
            for _, c in ipairs(holder:GetChildren()) do set[c] = true end
        end)
    end
    return set
end

local function __DIO_KeyUIDestroy(snap, win)

    pcall(function()
        local g = getgenv().__DIO_MiniKeyUI
        if g then g:Destroy() end
    end)
    pcall(function() getgenv().__DIO_MiniKeyUI = nil end)

    pcall(function()
        if win and type(win.Destroy) == "function" then win:Destroy() end
    end)

    local F = nil
    pcall(function() F = getgenv().Fluent end)
    pcall(function()
        if F and type(F.Destroy) == "function" then F:Destroy() end
    end)
    pcall(function()
        if F and F.GUI then F.GUI:Destroy() end
    end)
    pcall(function() getgenv().Fluent = nil end)

    if type(snap) == "table" then
        for _, holder in ipairs(__DIO_GuiHolders()) do
            pcall(function()
                for _, c in ipairs(holder:GetChildren()) do
                    if not snap[c] then
                        local cn = c.ClassName
                        if cn == "ScreenGui" then
                            c:Destroy()
                        end
                    end
                end
            end)
        end
    end
end

local function __DIO_KeyMiniUI()
    if getgenv().__DIO_MiniKeyUI and getgenv().__DIO_MiniKeyUI.Parent then
        return getgenv().__DIO_MiniKeyUI
    end
    local plr = game:GetService("Players").LocalPlayer
    local pg = plr:FindFirstChild("PlayerGui") or plr:WaitForChild("PlayerGui", 10)
    if not pg then return nil end

    local function mk(cls, props, parent)
        local o = Instance.new(cls)
        for k, v in pairs(props or {}) do pcall(function() o[k] = v end) end
        o.Parent = parent
        return o
    end
    local function corner(o, r)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 6)
        c.Parent = o
        return c
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "DIOKeyUI"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999999
    sg.Parent = pg
    getgenv().__DIO_MiniKeyUI = sg

    local fr = mk("Frame", {
        Name = "Main",
        Size = UDim2.fromOffset(400, 176),
        Position = UDim2.new(0.5, -200, 0.5, -88),
        BackgroundColor3 = Color3.fromRGB(22, 22, 26),
        BorderSizePixel = 0,
        Active = true,
    }, sg)
    corner(fr, 10)
    mk("UIStroke", { Color = Color3.fromRGB(60, 60, 70), Transparency = 0.3 }, fr)

    mk("TextLabel", {
        Text = "DIO HUB - GET KEY",
        Size = UDim2.new(1, -20, 0, 20),
        Position = UDim2.fromOffset(10, 8),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, fr)

    local status = "?"
    pcall(function() status = tostring(_DIO_KeyStatusText()) end)
    status = tostring(status):gsub("\n", "  "):sub(1, 140)
    mk("TextLabel", {
        Text = status,
        Size = UDim2.new(1, -20, 0, 30),
        Position = UDim2.fromOffset(10, 28),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(170, 170, 180),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, fr)

    local box = mk("TextBox", {
        Text = "",
        PlaceholderText = "Dan key vao day...",
        ClearTextOnFocus = false,
        Size = UDim2.new(1, -20, 0, 28),
        Position = UDim2.fromOffset(10, 62),
        BackgroundColor3 = Color3.fromRGB(14, 14, 18),
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.Code,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, fr)
    corner(box, 6)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, box)

    local note = mk("TextLabel", {
        Text = "",
        Size = UDim2.new(1, -20, 0, 16),
        Position = UDim2.fromOffset(10, 94),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 190, 120),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, fr)

    local function startWith(key, from)
        if not _SEC_VerifyKey(tostring(key or "")) then
            note.Text = "Key khong hop le. Thu lai hoac bam 'Tu Clipboard'."
            return false
        end
        _DIO_SetKey(key)
        saveKeyCache()
        note.Text = "Key hop le! Dang tai hub..."
        task.spawn(function()
            task.wait(0.5)
            __DIO_KeyUIDestroy(getgenv().__DIO_KeyGuiBefore, nil)
            pcall(function() sg:Destroy() end)
            task.wait(0.2)
            __DIO_SafeStart("mini-key-" .. tostring(from or "ui"))
        end)
        return true
    end

    local function btn(text, x, w, cb, color)
        local b = mk("TextButton", {
            Text = text,
            Size = UDim2.fromOffset(w, 26),
            Position = UDim2.fromOffset(x, 116),
            BackgroundColor3 = color or Color3.fromRGB(45, 45, 55),
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Enum.Font.GothamSemibold,
            TextSize = 11,
            AutoButtonColor = true,
            BorderSizePixel = 0,
        }, fr)
        corner(b, 6)
        b.MouseButton1Click:Connect(function() pcall(cb) end)
        return b
    end

    btn("Check Key", 10, 108, function() startWith(box.Text, "mini-manual") end, Color3.fromRGB(40, 90, 60))
    btn("Tu Clipboard", 124, 108, function()
        local clip
        pcall(function()
            if type(getclipboard) == "function" then clip = getclipboard() end
        end)
        if type(clip) ~= "string" or #clip == 0 then
            note.Text = "Executor khong co getclipboard - dan tay vao o tren."
            return
        end
        for line in tostring(clip):gmatch("[^\r\n]+") do
            local t = line:match("^%s*(.-)%s*$")
            if t and #t >= 6 and _SEC_VerifyKey(t) then
                startWith(t, "mini-clip")
                return
            end
        end
        note.Text = "Clipboard khong co key hop le."
    end)
    btn("Xoa cache", 238, 94, function()
        _DIO_ResetKeyCache()
        note.Text = "Da xoa cache key. Nhap key moi roi Check Key."
    end, Color3.fromRGB(90, 60, 40))
    btn("Tat UI", 338, 52, function() sg:Destroy() end, Color3.fromRGB(90, 40, 40))

    warn("[DIO KEY] Dang dung UI nhap key toi gian (Fluent khong dung duoc).")
    return sg
end

if isKeyValid() then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "DIO Hub",
            Text = "Key valid! Loading hub...",
            Duration = 3
        })
    end)
    __DIO_SafeStart("main-entry")
else
    local Fluent

    pcall(function() getgenv().__DIO_KeyGuiBefore = __DIO_SnapGuis() end)
    local okFluent, errFluent = pcall(function()
        Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
    end)
    if not okFluent or not Fluent then
        warn("[DIO] Fluent load loi (" .. tostring(errFluent) .. ") -> UI nhap key toi gian")
        __DIO_KeyMiniUI()
        return
    end

    local __DIO_KeyEntry = ""
    local __KEY_Log = {}

    local Window, TabKey, TabInfo, TabDiag, KeyInput
    local function KeyEl(tab, method, idx, cfg)
        local fn = tab and tab[method]
        if type(fn) ~= "function" then
            table.insert(__KEY_Log, method .. ":missing")
            return nil
        end
        local ok1, res1 = pcall(fn, tab, idx, cfg)
        if ok1 and res1 ~= nil then
            table.insert(__KEY_Log, method .. ":ok2")
            return res1
        end
        local ok2, res2 = pcall(fn, tab, cfg)
        if ok2 and res2 ~= nil then
            table.insert(__KEY_Log, method .. ":ok1")
            return res2
        end
        table.insert(__KEY_Log, method .. ":FAIL")
        warn(("[DIO KEY] %s loi: %s | %s"):format(method, tostring(res1), tostring(res2)))
        return nil
    end

    local function KeyClipboard()
        local clip
        pcall(function()
            if type(getclipboard) == "function" then clip = getclipboard() end
        end)
        if type(clip) ~= "string" or #clip == 0 then return nil end
        for line in tostring(clip):gmatch("[^\r\n]+") do
            local t = line:match("^%s*(.-)%s*$")
            if t and #t >= 6 and _SEC_VerifyKey(t) then return t end
        end
        return nil
    end

    local __KEY_Started = false
    local function KeyAccept(key, from)
        if __KEY_Started then return true end
        key = tostring(key or "")
        if #key == 0 or not _SEC_VerifyKey(key) then return false end
        __KEY_Started = true
        _DIO_SetKey(key)
        saveKeyCache()
        pcall(function()
            Fluent:Notify({ Title = "Success", Content = "Key hop le! Dang tai hub...", Duration = 3 })
        end)
        task.spawn(function()
            task.wait(0.5)

            __DIO_KeyUIDestroy(getgenv().__DIO_KeyGuiBefore, Window)
            task.wait(0.2)
            __DIO_SafeStart("key-" .. tostring(from or "ui"))
        end)
        return true
    end

    local __okBuild, __errBuild = pcall(function()
        local vp = Vector2.new(1280, 720)
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam and cam.ViewportSize then vp = cam.ViewportSize end
        end)
        Window = Fluent:CreateWindow({
            Title = "DIO Hub - Key",
            SubTitle = "By DIO",
            TabWidth = 130,
            Size = UDim2.fromOffset(
                math.clamp(math.floor(vp.X) - 60, 300, 520),
                math.clamp(math.floor(vp.Y) - 120, 240, 460)
            ),
            Acrylic = false,
            Theme = "Dark",
            MinimizeKey = Enum.KeyCode.RightControl
        })

        TabKey = Window:AddTab({ Title = "Get Key", Icon = "key" })
        TabInfo = Window:AddTab({ Title = "Discord", Icon = "message-circle" })
        TabDiag = Window:AddTab({ Title = "Chan doan", Icon = "activity" })

        KeyEl(TabKey, "AddParagraph", nil, {
            Title = "Key System",
            Content = "Key dung 10 tieng / thiet bi.\n"
                .. "1) Bam '1. Get Key Link' de lay key (tu dong copy).\n"
                .. "2) Dan key vao o ben duoi -> bam '3. Check Key'.\n"
                .. "Hoac bam 'Dan tu Clipboard + Check' neu key dang o clipboard."
        })

        local link = "https://link4sub.com/notes/eRcc"
        pcall(function()
            local l = _DIO_ResolveLinkgetkey(false)
            if type(l) == "string" and #l > 12 then link = l end
        end)
        KeyEl(TabKey, "AddButton", "GetKeyLink", {
            Title = "1. Get Key Link (copy)",
            Description = link,
            Callback = function()
                local l = link
                pcall(function()
                    local r = _DIO_ResolveLinkgetkey(true)
                    if type(r) == "string" and #r > 12 then l = r end
                end)
                pcall(function() setclipboard(l) end)
                pcall(function()
                    Fluent:Notify({ Title = "Da copy link key", Content = l, Duration = 5 })
                end)
            end
        })

        KeyInput = KeyEl(TabKey, "AddInput", "DIOKeyInput", {
            Title = "2. Enter Key",
            Description = "Dan key vao day",
            Default = "",
            Placeholder = "Paste your key here...",
            Numeric = false,
            Finished = false,
            Callback = function(Value)
                __DIO_KeyEntry = tostring(Value or "")
            end
        })

        KeyEl(TabKey, "AddButton", "CheckKey", {
            Title = "3. Check Key",
            Description = "Kiem tra key vua nhap",
            Callback = function()
                local entered = (KeyInput and KeyInput.Value) or __DIO_KeyEntry
                if KeyAccept(entered, "manual") then return end
                pcall(function()
                    Fluent:Notify({
                        Title = "Key khong hop le",
                        Content = "Thu 'Dan tu Clipboard + Check', hoac xem tab Chan doan.",
                        Duration = 5
                    })
                end)
                warn("[DIO KEY] Key nhap tay khong khop.")
            end
        })

        KeyEl(TabKey, "AddButton", "CheckClip", {
            Title = "Dan tu Clipboard + Check",
            Description = "Lay key trong clipboard roi kiem tra (khong can dan tay)",
            Callback = function()
                local k = KeyClipboard()
                if k and KeyAccept(k, "clipboard") then return end
                pcall(function()
                    Fluent:Notify({
                        Title = "Clipboard khong co key hop le",
                        Content = "Copy key truoc roi bam lai.",
                        Duration = 5
                    })
                end)
            end
        })

        KeyEl(TabKey, "AddButton", "UseEnv", {
            Title = "Dung getgenv().Key",
            Description = "Kiem tra key trong getgenv().Key",
            Callback = function()
                if KeyAccept(tostring(getgenv().Key or ""), "getgenv") then return end
                pcall(function()
                    Fluent:Notify({
                        Title = "getgenv().Key khong hop le",
                        Content = "Nhap key thu cong.",
                        Duration = 5
                    })
                end)
            end
        })

        KeyEl(TabInfo, "AddParagraph", nil, {
            Title = "Join the Community",
            Content = "Discord: updates, support. Key dung 10 tieng / thiet bi."
        })
        KeyEl(TabInfo, "AddButton", "CopyDiscord", {
            Title = "Copy Discord Link",
            Description = "https://discord.gg/NZm9MXzmzn",
            Callback = function()
                pcall(function() setclipboard("https://discord.gg/NZm9MXzmzn") end)
                pcall(function()
                    Fluent:Notify({ Title = "Copied!", Content = "Da copy link Discord.", Duration = 5 })
                end)
            end
        })

        local status = "(khong doc duoc trang thai key)"
        pcall(function() status = tostring(_DIO_KeyStatusText()) end)
        local label = "?"
        pcall(function() label = tostring(_DIO_KeyLabel()) end)
        KeyEl(TabDiag, "AddParagraph", nil, {
            Title = "Chan doan Key",
            Content = "Key cua ban: " .. label .. "\n" .. status
        })
        KeyEl(TabDiag, "AddButton", "ResetCache", {
            Title = "Xoa cache Key (Reset)",
            Description = "Xoa KeyCache.json + getgenv().Key de nhap lai key moi",
            Callback = function()
                _DIO_ResetKeyCache()
                pcall(function()
                    Fluent:Notify({
                        Title = "Da xoa cache key",
                        Content = "Nhap key moi roi bam Check Key.",
                        Duration = 5
                    })
                end)
            end
        })
        KeyEl(TabDiag, "AddButton", "TestApi", {
            Title = "Test Api (xem log F9)",
            Description = "In ra console: Api tra ve gi, cache dang luu gi",
            Callback = function()
                _DIO_ResolvePendingFromPastefy()
                print("[DIO KEY][TEST] Online=" .. tostring(_DIO_ApiOnline)
                    .. " | Keys=" .. table.concat(_DIO_ApiKeys, " | ")
                    .. " | Pending=" .. tostring(_DIO_PendingKey))
                print("[DIO KEY][TEST] Raw=" .. tostring(_DIO_ApiRaw):sub(1, 300))
                pcall(function()
                    Fluent:Notify({
                        Title = "Test Api xong",
                        Content = _DIO_ApiOnline
                            and "Api doc duoc - xem console (F9)"
                            or "KHONG doc duoc Api - xem console (F9)",
                        Duration = 6
                    })
                end)
            end
        })
    end)

    if not __okBuild then
        warn("[DIO KEY] Dung UI Fluent loi: " .. tostring(__errBuild) .. " -> UI nhap key toi gian")
        pcall(function() if Window then Window:Destroy() end end)
        __DIO_KeyMiniUI()
        return
    end

    pcall(function() Window:SelectTab(1) end)
    warn("[DIO KEY] Fluent elements: " .. table.concat(__KEY_Log, ", "))
    if KeyInput == nil then
        warn("[DIO KEY] Khong tao duoc o nhap key cua Fluent -> dung them UI toi gian cho chac.")
        __DIO_KeyMiniUI()
    end
    pcall(function()
        Fluent:Notify({
            Title = "DIO Hub",
            Content = "Nhap key (hoac bam 'Dan tu Clipboard + Check')",
            Duration = 6
        })
    end)

    task.spawn(function()
        task.wait(0.6)
        if __KEY_Started then return end
        local envKey = tostring(getgenv().Key or "")
        if #envKey > 5 and KeyAccept(envKey, "getgenv-auto") then return end
        local k = KeyClipboard()
        if k then KeyAccept(k, "clipboard-auto") end
    end)
end
