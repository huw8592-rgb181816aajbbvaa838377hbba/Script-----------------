local pcall, xpcall, type, tostring, tonumber, select, unpack = pcall, xpcall, type, tostring, tonumber, select, unpack or table.unpack
local rawget, rawset, rawequal, getmetatable, setmetatable = rawget, rawset, rawequal, getmetatable, setmetatable
local string, table, math, task, coroutine, debug, os = string, table, math, task, coroutine, debug, os
local game, Instance, Vector3, CFrame, UDim2, Color3 = game, Instance, Vector3, CFrame, UDim2, Color3
local getgenv = getgenv or function() return _G end
local cloneref = cloneref or function(o) return o end
local clonefunction = clonefunction or function(f) return f end
local newcclosure = newcclosure or function(f) return f end
local checkcaller = checkcaller or function() return true end
local isexecutorclosure = isexecutorclosure or checkcaller or function() return false end
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
local KEY_FILE = SAVE_FOLDER .. "/KeyCache.json"

-- [KEY-FIX] Trang thai goi Api: de biet dang ONLINE hay OFFLINE ma xu ly cho dung
local _DIO_KeyDiag   = ""     -- [KEY-4] chan doan loi doc Api
local _DIO_ApiOnline = false  -- lan goi Api gan nhat co doc duoc khong
local _DIO_ApiKeys   = {}     -- danh sach key hop le lay tu Api (da chuan hoa)
local _DIO_ApiLink   = ""     -- Linkgetkey lay tu Api
local _DIO_ApiRaw    = ""     -- noi dung tho Api tra ve (debug)
-- [KEY-FIX] (tuy chon) Key dung khi may KHONG goi duoc Api. De trong = offline thi khong cho qua.
local _DIO_OfflineKeys = {
    -- "DIOHUB", -- <-- bo comment va dien key cua ban vao day neu may ban khong goi duoc Api
}

local function _DIO_CleanJSON(str)
    if type(str) ~= "string" then return "" end
    str = str:gsub("\239\187\191", "")       -- BOM UTF-8 dau file
    str = str:gsub("\226\128\139", "")       -- zero width space
    str = str:gsub("\226\128\140", "")       -- zero width non-joiner
    str = str:gsub("\226\128\141", "")       -- zero width joiner
    str = str:gsub("%-%-[^\r\n]*", "")       -- comment kieu Lua
    str = str:gsub(",%s*}", "}")             -- bo dau phay thua cuoi object
    str = str:gsub(",%s*]", "]")             -- bo dau phay thua cuoi array
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    return str
end

-- [KEY-FIX] Chuan hoa key: bo ky tu vo hinh, \r \n \t, gop khoang trang
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

-- [KEY-FIX] So sanh key KHONG phan biet hoa/thuong (ban cu so sanh tung byte -> 'diohub' bi tu choi)
local function _DIO_KeyEq(a, b)
    local x, y = _DIO_NormKey(a), _DIO_NormKey(b)
    if #x == 0 or #y == 0 then return false end
    return x:lower() == y:lower()
end

-- [KEY-FIX] Them tham so chong cache: pastefy / executor co the cache URL /raw
local function _DIO_Bust(url)
    if type(url) ~= "string" or #url == 0 then return url end
    local sep = url:find("?", 1, true) and "&" or "?"
    return url .. sep .. "t=" .. tostring(os.time()) .. "&r=" .. tostring(math.random(100000, 999999))
end

-- [KEY-FIX] Lay du lieu Api bang nhieu cach: game:HttpGet -> request/http_request -> HttpGetAsync
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

-- [KEY-FIX] Key co the la: "Key" (string), "Keys"/"keys" (mang), "key", "key_list" -> gom het lai
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

-- ===== [KEY-FIX] Cache file key =====
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
-- [KEY-FIX] Api la nguon chan ly: key trong cache / getgenv() ma khong con tren Api thi phai bi xoa
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
        -- [KEY-2] ONLINE: Pastefy la nguon chan ly DUY NHAT -> doi key o pastefy co hieu luc ngay,
        -- key cu (cache / getgenv) KHONG the tu vao.
        local list = _DIO_KeyListFrom(data)
        if #list == 0 then
            warn("[DIO KEY] Pastefy tra ve JSON hop le nhung thieu truong 'Key' hop le.")
            return false
        end
        for _, official in ipairs(list) do
            if _DIO_KeyEq(key, official) then
                _DIO_SetKey(official) -- luu dung chinh ta cua Api
                print("[DIO KEY] Key hop le (khop voi Api).")
                return true
            end
        end
        -- [KEY-FIX] Chua thay key -> doc lai Api 1 lan voi URL moi (chong ban cache cu cua
        -- executor / pastefy / Cloudflare lam script van doc phai key cu)
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
        -- [KEY-FIX] key nay khong con dung voi Api -> don cache / getgenv() cu di
        _DIO_InvalidateStaleCache()
        warn("[DIO KEY] Key vua nhap KHONG nam trong danh sach key cua Api hien tai.")
        return false
    end
    -- OFFLINE (khong toi duoc Api): chap nhan key cau hinh / cache de khong khoa nguoi dung
    if #_DIO_PendingKey > 0 and _DIO_KeyEq(key, _DIO_PendingKey) then
        _DIO_SetKey(_DIO_PendingKey)
        warn("[DIO KEY] OFFLINE: cho qua bang key cau hinh/cache cua may nay.")
        return true
    end
    -- [KEY-FIX] OFFLINE: danh sach key du phong khai bao trong script (neu co)
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
            if data.time and (os.time() - tonumber(data.time) > 36000) then return end -- [KEY-1]
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
-- [KEY-FIX] Text chan doan de hien thi ngay trong cua so nhap key
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
pcall(function()
    local mt = getrawmetatable and getrawmetatable(game)
    if mt then
        setreadonly(mt, false)
        local oldNamecall = mt.__namecall
        if oldNamecall and isexecutorclosure and isexecutorclosure(oldNamecall) then
        end
    end
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
    -- [KEY-FIX] Neu doc duoc Api ma key cua may nay khong con hop le -> DON cache cu,
    -- khong cho key cu "song" them 10 tieng nua (truoc day isKeyCacheValid() van cho vao).
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
-- [KEY-FIX] Cho UI goi: xoa cache + key cu de nhap lai key moi
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
  Lv = __lvl and __lvl.Value or 0
  TeleportService = __SVC_TP
  TW = __SVC_TWN
  Lighting = __SVC_LIGHT
  Enemies = workspace:WaitForChild("Enemies", 30)
  vim1 = __SVC_VIM
  vim2 = __SVC_VU
  TeamSelf = plr.Team
  RunSer = __SVC_RUN
  Stats = __SVC_STAT
  local __en = plr.Character:FindFirstChild("Energy")
  Energy = __en and __en.Value or 0
  BringConnections = {}
  BossList = {}
  MaterialList = {}
  NPCList = {}
  shouldTween = false
  SoulGuitar = false
  KenTest = true
  debug = false
  Brazier1 = false
  Brazier2 = false
  Brazier3 = false
  _G.HealthFarmMastery = _G.HealthFarmMastery or 30
Sec = 0.25
  ClickState = 0
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
    if __nowA - (__DIO_LastActT or 0) < 0.5 then return end -- [HL4]
    __DIO_LastActT = __nowA
    __DIO_TweenBlockT = 0
    __DIO_TweenBlockDur = 0.5
    __DIO_FalseSince = nil
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
    "Complete_Trials", "TpDrago_Prehis", "BuyDrago", "BuyMelee_BuyBlackLeg", "BuyMelee_BuyElectro", "BuyMelee_BuyFishmanKarate", "BuyMelee_BuyDragonClaw", "AutoFireFlowers",
    "DT_Uzoth", "AutoBerry", "Prefully", "Prehis_Find", "Prehis_Skills", "Prehis_DB", "Prehis_DE", "FarmBlazeEM",
    "Dojoo", "CollectPresent", "AutoLawKak", "TpLab", "AutoPhoenixF", "AutoFarmChest", "AutoHytHallow", "LongsWord",
    "BlackSpikey", "AutoHolyTorch", "TrainDrago", "AutoSaber", "FarmMastery_Dev", "CitizenQuest", "AutoEctoplasm", "KeysRen",
    "Auto_Rainbow_Haki", "obsFarm", "AutoBigmom", "Doughv2", "AuraBoss", "Raiding", "Auto_Cavender", "TpPly",
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
    "FarmEliteHop", "AutoHop_Dough", "AutoDoughKing", "AutoAttackDoughKing", "AutoChipFruit", "AutoChipBeli", "Auto_StartRaid", "StartEvent",
    "AutoMysticIsland", "AutoPlayerHunter", "SafeMode", "AutoKillMob", "AutoStartPrehistoric", "AutoFarmIsland", "AutoFarmDungeon", "AutoFarmCandy",
    "AutoTP_Gift", "AutoTPGift", "AutoTPAndCollect", "MasterAutoLevel", "MasterAutoCandy", "TPFloor1", "TPFloor2", "TPFloor3",
    "TPFloor4", "FarmEliteH", "Safemode", "Greybeard", "ResetPH", "NextIs", "senth", "senth2",
}
__DIO_TWEEN_LEASE  = 30         
__DIO_MOVE_GRACE   = 12         
__DIO_KEEP_APPROACH = 90        
__DIO_SOFT_DROP    = 1.5        
__DIO_TweenArmedT  = 0
__DIO_MoveT        = 0
__DIO_Parked       = false
__DIO_ParkT        = 0
__DIO_DropPendT    = 0
__DIO_DropPendReason = nil
__DIO_FeatOnN      = 0
__DIO_FeatMark     = {}
__DIO_UIOn         = {}
__DIO_UIOnN        = 0
__DIO_Move = function()
    __DIO_MoveT    = tick()
    __DIO_Parked   = false
    __DIO_DropPendT = 0
    __DIO_DropPendReason = nil
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
__DIO_TweenKillT  = 0
__DIO_LastActT   = 0
__DIO_TweenAllowT = 0
__DIO_TweenArmedT = 0
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
                if v == true and __DIO_FlagGet(k) == true then
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
__DIO_TweenAllowed = function()
    if __DIO_Dodging == true and type(__DIO_DodgeStale) == "function" then __DIO_DodgeStale() end
    if __DIO_Dodging == true then return false end
    if __DIO_FlyBusy == true then return true end
    if __DIO_AnyFeatureOn() then return true end
    return __DIO_MoveFresh()
end
__DIO_TweenArmedFlags = nil
__DIO_TweenBlockT     = 0
__DIO_TweenBlockDur   = 0.5
__DIO_FlagPrev        = {}
__DIO_FlagOnT         = {}
__DIO_FlagOffT        = {}
__DIO_DodgeT0         = 0
__DIO_DODGE_MAX       = 8
__DIO_ExtraFarmFlags  = { "AutoMaterial", "StartFarm", "NextIs", "senth", "senth2" }
__DIO_FarmFlagList    = nil
__DIO_FarmFlagAll = function()
    if __DIO_FarmFlagList ~= nil then return __DIO_FarmFlagList end
    local t, seen = {}, {}
    for i = 1, #__DIO_FarmFlagNames do
        local n = __DIO_FarmFlagNames[i]
        if type(n) == "string" and not seen[n] then seen[n] = true t[#t + 1] = n end
    end
    for i = 1, #__DIO_ExtraFarmFlags do
        local n = __DIO_ExtraFarmFlags[i]
        if not seen[n] then seen[n] = true t[#t + 1] = n end
    end
    __DIO_FarmFlagList = t
    return t
end
__DIO_IsFarmFlag = function(name)
    if type(name) ~= "string" then return false end
    local list = __DIO_FarmFlagAll()
    for i = 1, #list do if list[i] == name then return true end end
    return false
end
__DIO_FarmFlagOnSet = function()
    local out, any = {}, false
    local list = __DIO_FarmFlagAll()
    for i = 1, #list do
        local n = list[i]
        if __DIO_FlagGet(n) == true then out[n] = true any = true end
    end
    if __DIO_BuyFlying == true then out["__DIO_BuyFlying"] = true any = true end
    return out, any
end
__DIO_FlagPoll = function()
    local on, any = __DIO_FarmFlagOnSet()
    local prev, now = __DIO_FlagPrev, tick()
    local list = __DIO_FarmFlagAll()
    for i = 1, #list do
        local n = list[i]
        local v = (on[n] == true)
        local pv = prev[n]
        if pv ~= nil and pv ~= v then
            if v then __DIO_FlagOnT[n] = now __DIO_FlagOffT[n] = nil
            else __DIO_FlagOffT[n] = now __DIO_FlagOnT[n] = nil end
        end
        prev[n] = v
    end
    return on, any
end
__DIO_TweenBlock = function(dur)
    __DIO_TweenBlockT   = tick()
    __DIO_TweenBlockDur = tonumber(dur) or 0.5
end
__DIO_TweenClearBlock = function()
    __DIO_TweenBlockT   = 0
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
__DIO_Approaching = function()
    local tp = __DIO_TweenTarget
    if tp == nil then return false end
    local __ok, __far = pcall(function()
        local ch = plr.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        return (tp.Position - hrp.Position).Magnitude > 6
    end)
    return (__ok and __far) and true or false
end
__DIO_TweenValid = function()
    if __DIO_TweenTarget == nil then return false end
    if __DIO_TweenBlocked() then return false end
    if __DIO_Dodging == true then
        __DIO_DodgeStale()
        if __DIO_Dodging == true then return false end
    end
    if __DIO_FlyBusy == true then return true end
    local featOn = __DIO_AnyFeatureOn()
    if not featOn then return false end
    if __DIO_MoveFresh() then return true end
    if __DIO_Approaching() and (tick() - (__DIO_MoveT or 0)) < (__DIO_KEEP_APPROACH or 90) then
        return true
    end
    return true
end
__DIO_TweenSync = function()
    local on = false
    if __DIO_FlyBusy == true then
        on = true
    elseif __DIO_AnyFeatureOn() then
        if __DIO_TweenTarget ~= nil and __DIO_TweenValid() then
            on = true
        elseif __DIO_MoveFresh() then
            on = true
        else
            on = true
        end
    end
    shouldTween = on and true or false
    if on == false and type(__DIO_HlOff) == "function" then pcall(__DIO_HlOff) end -- [HL3]
    return on
end
__DIO_TweenDropHard = function(reason)
    __DIO_TweenTarget      = nil
    __DIO_TweenArmedFlags  = nil
    __DIO_LastDist         = nil
    __DIO_LastHRPPos       = nil
    __DIO_Parked           = false
    __DIO_DropPendT        = 0
    __DIO_DropPendReason   = nil
    pcall(function()
        if __DIO_LastTween then __DIO_LastTween:Cancel() end
        __DIO_LastTween = nil
    end)
end
__DIO_TweenDrop = function(reason)
    local __busy = __DIO_AnyFeatureOn() or __DIO_FlyBusy == true
    if __busy then
        __DIO_DropPendT = tick()
        __DIO_DropPendReason = tostring(reason or "soft")
        return
    end
    __DIO_TweenDropHard(reason)
end
__DIO_TweenDropPending = function()
    if (__DIO_DropPendT or 0) > 0 and (tick() - __DIO_DropPendT) >= (__DIO_SOFT_DROP or 1.5) then
        local __why = __DIO_DropPendReason or "soft"
        __DIO_DropPendT = 0
        __DIO_DropPendReason = nil
        if not __DIO_AnyFeatureOn() then
            __DIO_TweenDropHard("soft-expired:" .. tostring(__why))
        end
    end
    return __DIO_DropPendT
end
__DIO_TweenSet = function(cf)
    if cf == nil then return end
    local ok = pcall(function() return cf.Position end)
    if not ok then return end
    __DIO_TweenTarget      = cf
    __DIO_LastTweenTarget  = cf
    __DIO_LastTpT          = tick()
    __DIO_TweenArmedT      = tick()
    __DIO_TweenArmedFlags  = nil
    shouldTween = true
    if type(__DIO_Move) == "function" then __DIO_Move() end
end
__DIO_TweenKill = function(keepHighlight, force)
    if force ~= true and __DIO_AnyFeatureOn() then
        if type(__DIO_TweenSync) == "function" then pcall(__DIO_TweenSync) end
        return
    end
    __DIO_TweenKillT       = tick()
    __DIO_TweenAllowT      = 0
    __DIO_TweenArmedT      = 0
    __DIO_TweenArmedFlags  = nil
    __DIO_TweenTarget      = nil
    __DIO_LastTweenTarget  = nil
    __DIO_LastTpT          = 0
    __DIO_MoveT            = 0
    __DIO_Parked           = false
    __DIO_FalseSince       = nil
    __DIO_CurTarget        = nil
    __DIO_LastDist         = nil
    __DIO_LastHRPPos       = nil
    __DIO_DropPendT        = 0
    shouldTween = false
    pcall(function()
        if __DIO_LastTween then __DIO_LastTween:Cancel() end
        __DIO_LastTween = nil
    end)
    pcall(function()
        local char = plr.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bc = hrp:FindFirstChild("BodyClip")
            if bc then bc:Destroy() end
        end
    end)
    if keepHighlight ~= true then
        pcall(function() if type(__DIO_HlOff) == "function" then __DIO_HlOff() end end)
    end
end
__DIO_WatchdogReport = {}
__DIO_Watchdog = function()
    pcall(__DIO_FlagPoll)
    pcall(__DIO_DodgeStale)
    pcall(__DIO_TweenDropPending)
    if __DIO_FlyBusy == true and __DIO_FlyBusyT ~= nil and (tick() - __DIO_FlyBusyT) > 360 then
        __DIO_FlyBusy = false
    end
    if __DIO_TweenTarget ~= nil and not __DIO_TweenValid() then
        __DIO_TweenDropHard("invalid")
    end
    if __DIO_TweenTarget ~= nil and not __DIO_MoveFresh() and __DIO_FlyBusy ~= true
       and not __DIO_AnyFeatureOn() and (tick() - (__DIO_MoveT or 0)) > 90 then
        __DIO_TweenDropHard("idle")
    end
    pcall(__DIO_TweenSync)
end
__DIO_SafeLoop(function()
    while __DIO_wait(0.4) do
        pcall(__DIO_Watchdog)
    end
end, "V10Watchdog")
__DIO_UserIntent = function() -- [HL2v2] chi UI that cua phien nay moi duoc tinh
    return (__DIO_UIOnN or 0) > 0 or (__DIO_FeatOnN or 0) > 0
end
__DIO_HlSync = function(wantOn)
    if wantOn then
        local __ch = plr.Character
        if __ch and tick() - (__DIO_LastHlDecor or 0) >= 0.25 then
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
_G.DIO_AutoRestore = (getgenv().AutoRestoreToggles == true) -- [HL1] mac dinh KHONG tu bat lai toggle da luu
-- [HL5] xoa co _G/getgenv TRUE am tu phien cu (executor giu moi truong cu) -> het "chua bat gi ma tu chay/sang highlight"
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
Marines = function()
      replicated.Remotes.CommF_:InvokeServer("SetTeam2","Marines")
end
Pirates = function()
      replicated.Remotes.CommF_:InvokeServer("SetTeam2","Pirates")
end
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
local DungeonTables = {
    "Flame",
    "Ice",
    "Quake",
    "Light",
    "Dark",
    "String",
    "Rumble",
    "Magma",
    "Human: Buddha",
    "Sand",
    "Bird: Phoenix",
    "Dough"
}
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
    if mode == "Obrit" or mode == "Dodge" then
        if mdl then
            __DIO_CurTarget = mdl
            __DIO_TargetT = tick()
        end
        return nil
    end
    local h2 = tonumber(_G.FarmDistance) or h
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
	Attack.Dist = function(model, dist)
		local __rp = model and model:FindFirstChild("HumanoidRootPart")
		if not __rp then return false end
		return (Root.Position - __rp.Position).Magnitude <= dist
	end
	Attack.DistH = function(model, dist)
		local __rp = model and model:FindFirstChild("HumanoidRootPart")
		if not __rp then return false end
		return (Root.Position - __rp.Position).Magnitude > dist
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
			PosMon = __lk and __lk.Position or __root.Position
			pcall(BringEnemy, model)
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
			PosMon = __lk and __lk.Position or __root.Position
			pcall(BringEnemy, model)
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
			PosMon = __lk and __lk.Position or __root.Position
			pcall(BringEnemy, model)
			__DIO_EquipFarmWeapon(model)
			local Equipped = nil
			pcall(function()
				local __chK3 = game.Players.LocalPlayer.Character
				Equipped = __chK3 and __chK3:FindFirstChildOfClass("Tool")
			end)
			local ToolTip = Equipped and Equipped.ToolTip
			if ToolTip == "Blox Fruit" then
				_tp(__DIO_FarmPos(model, 10, 0, 90))
			else
				notween(model.HumanoidRootPart.CFrame * CFrame.new(0, 50, 8))
				__DIO_wait(.85)
				notween(model.HumanoidRootPart.CFrame * CFrame.new(0, 400, 0))
				__DIO_wait(1)
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
			PosMon = __lk and __lk.Position or __root.Position
			pcall(BringEnemy, model)
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
			PosMon = __lk and __lk.Position or root.Position
			pcall(BringEnemy, model)
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
			PosMon = __lk and __lk.Position or root.Position
			pcall(BringEnemy, model)
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
local TweenService = __SVC_TWN
local TweenInfoBring = TweenInfo.new(0.45, Enum.EasingStyle.Linear)
_G.BringRange = _G.BringRange or 180
_G.MaxBringMobs = _G.MaxBringMobs or 4
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
-- ================= MOB HOLD: giu mob dung im, danh khong bi vang =================
-- [FIX-COMPILE] Boc khoi nay trong do...end: Luau gioi han 200 local/scope, main chunk
-- cua script da gan cham gioi han -> them local o day se gay loi "Out of local registers"
-- (script dieu ngay luc compile => UI khong len). do...end giai phong register sau khi ket thuc.
do
-- Loi cu: BringEnemy chi tween mob 1 lan (0.45s) roi "tha" => khong giu vi tri.
--         Luc danh, knockback day velocity vao HumanoidRootPart => mob bi vang di,
--         ma bring lai chi chay toi da 2.5s/lan nen mob bay mat.
-- Moi:  mob duoc GIU lien tuc moi frame (neo CFrame vao anchor canh player +
--       triet velocity = huy knockback). Chi tha khi: mob chet / tat Bring Mobs /
--       farm dung (6s khong duoc cham) / mob qua xa / la mob Raid.
local __DIO_BringRS = game:GetService("RunService")
local __DIO_HeldMobs = {}            -- [HumanoidRootPart] = data (mob dang duoc giu)
local __DIO_HoldTouchDist = 80       -- BringEnemy "cham" giu cac mob trong khoang cach nay (tu player)
local __DIO_HoldReleaseT  = 6        -- qua nhieu giay khong duoc cham (farm dung) => tha mob
local __DIO_HoldMaxDist   = 600      -- mob cach player qua xa => tha
local __DIO_HoldGolden    = math.rad(137.508)  -- goc vang: chia vi tri deu, khong de mob trung nhau
local __DIO_HoldRadius    = 4        -- ban kinh vong tron quanh player de xep mob

local function __DIO_CountHeld()
    local n = 0
    for _ in pairs(__DIO_HeldMobs) do n += 1 end
    return n
end

local function __DIO_ReleaseHeld(root, data)
    if root then
        pcall(function()
            root:SetAttribute("Tweening", nil)
            if root.Parent then
                root.CanCollide = true
                local hum = data and data.hum
                if hum and hum.Parent then
                    hum.WalkSpeed = (data and data.ws) or 16
                    hum.JumpPower = (data and data.jp) or 30
                end
            end
        end)
    end
    __DIO_HeldMobs[root] = nil
end

__DIO_ClearHeldMobs = function()
    for root, data in pairs(__DIO_HeldMobs) do
        __DIO_ReleaseHeld(root, data)
    end
end

local function __DIO_ZeroVel(root)
    local okV = pcall(function()
        root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end)
    if not okV then
        pcall(function()
            root.Velocity = Vector3.new(0, 0, 0)
            root.RotVelocity = Vector3.new(0, 0, 0)
        end)
    end
end

-- Loop giu mob: moi frame neo mob vao anchor + huy knockback cua don danh
task.spawn(function()
    local __raidT = 0
    while true do
        __DIO_BringRS.Heartbeat:Wait()
        local okL = pcall(function()
            local nowT = tick()
            if not _B then
                if next(__DIO_HeldMobs) then __DIO_ClearHeldMobs() end
                return
            end
            local plrB = game.Players.LocalPlayer
            local charB = plrB and plrB.Character
            local hrpB = charB and charB:FindFirstChild("HumanoidRootPart")
            if not hrpB then return end
            local __doRaid = (nowT - __raidT) > 0.5
            if __doRaid then __raidT = nowT end
            for root, data in pairs(__DIO_HeldMobs) do
                local okM = pcall(function()
                    local hum = data.hum
                    if not root.Parent or not hum or not hum.Parent or hum.Health <= 0
                        or (nowT - (data.lastTouch or 0)) > __DIO_HoldReleaseT
                        or (root.Position - hrpB.Position).Magnitude > __DIO_HoldMaxDist then
                        __DIO_ReleaseHeld(root, data)
                        return
                    end
                    if __doRaid and type(IsRaidMob) == "function" and IsRaidMob(data.model) then
                        __DIO_ReleaseHeld(root, data)
                        return
                    end
                    -- Giu mob dung im tai cho
                    hum.WalkSpeed = 0
                    hum.JumpPower = 0
                    root.CanCollide = false
                    __DIO_ZeroVel(root)  -- huy knockback => danh bao nhieu cung khong vang
                    -- Failsafe: Tweening keo dai bat thuong (>2s) => bo de loop neo duoc
                    if root:GetAttribute("Tweening") and (nowT - (data.tweenT or 0)) > 2 then
                        root:SetAttribute("Tweening", nil)
                    end
                    -- Neo mob vao anchor (chi sau khi tween bring ket thuc)
                    if not root:GetAttribute("Tweening") then
                        root.CFrame = data.anchor
                    end
                end)
                if not okM then
                    __DIO_HeldMobs[root] = nil
                end
            end
        end)
        if not okL then task.wait(0.5) end
    end
end)

BringEnemy = function(Mon)
    if not _B then return end
    local plr = game.Players.LocalPlayer
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local enFolder = workspace:FindFirstChild("Enemies")
    if not enFolder then return end

    -- "Cham" cac mob dang giu de chung khong bi tha khi farm con dang chay
    -- (chay TRUOC check cooldown de luc nao cung giu duoc mob)
    local nowT = tick()
    for root, data in pairs(__DIO_HeldMobs) do
        if root.Parent and data.hum and data.hum.Parent and data.hum.Health > 0
            and (root.Position - hrp.Position).Magnitude <= __DIO_HoldTouchDist then
            data.lastTouch = nowT
        end
    end

    if nowT - (__DIO_LastBring or 0) < 1.0 then return end
    __DIO_LastBring = nowT

    if not Mon or not Mon:FindFirstChild("HumanoidRootPart") then
        Mon = nil
    end
    if not Mon then
        local closestDist = math.huge
        for _, enemy in ipairs(enFolder:GetChildren()) do
            local hum = enemy:FindFirstChildOfClass("Humanoid")
            local root = enemy:FindFirstChild("HumanoidRootPart")
            if hum and root and hum.Health > 0 then
                local dist = (root.Position - hrp.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    Mon = enemy
                end
            end
        end
        if not Mon then return end
    end

    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(plr, "SimulationRadius", math.huge)
        end
    end)

    local targetPos = Mon.HumanoidRootPart.Position
    local baseP = hrp.Position
    local enemies = enFolder:GetChildren()
    for _, mob in ipairs(enemies) do
        local hum = mob:FindFirstChild("Humanoid")
        local root = mob:FindFirstChild("HumanoidRootPart")
        if hum and root and hum.Health > 0 then
            local dist = (root.Position - targetPos).Magnitude
            if dist <= _G.BringRange then
                local held = __DIO_HeldMobs[root]
                if held then
                    held.lastTouch = nowT  -- dang giu roi, chi can cham de giu tiep
                elseif __DIO_CountHeld() < _G.MaxBringMobs and not root:GetAttribute("Tweening") then
                    local isRaid = false
                    if type(IsRaidMob) == "function" then
                        isRaid = IsRaidMob(mob)
                    end
                    if not isRaid then
                        -- Anchor: xep quanh player, dung o do cao cua cum mob
                        -- (neo 1 lan luc bring => player bay len farm khong keo mob bay theo)
                        local ang = __DIO_HoldGolden * (__DIO_CountHeld() + 1)
                        local anchorCF = CFrame.new(
                            baseP.X + math.cos(ang) * __DIO_HoldRadius,
                            targetPos.Y,
                            baseP.Z + math.sin(ang) * __DIO_HoldRadius
                        )
                        __DIO_HeldMobs[root] = {
                            model = mob,
                            root = root,
                            hum = hum,
                            ws = hum.WalkSpeed,
                            jp = hum.JumpPower,
                            anchor = anchorCF,
                            tweenT = nowT,
                            lastTouch = nowT,
                        }
                        root:SetAttribute("Tweening", true)
                        root.CanCollide = false
                        hum.WalkSpeed = 0
                        hum.JumpPower = 0
                        local tween = TweenService:Create(root, TweenInfoBring, { CFrame = anchorCF })
                        tween:Play()
                        tween.Completed:Once(function()
                            if root and root.Parent then
                                root:SetAttribute("Tweening", nil)
                            end
                        end)
                    end
                end
            end
        end
    end
end
end -- [FIX-COMPILE] ket thuc khoi do...end cua MOB HOLD
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
      v.TextureID = 10385902758728957
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
    if (v.Name == "Fish Crew Member" or v.Name == "Haunted Crew Member") and Attack.Alive(v) then
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
__DIO_WO = nil
function __DIO_GetWorldOrigin()
    if __DIO_WO and __DIO_WO.Parent then return __DIO_WO end
    __DIO_WO = workspace:FindFirstChild("_WorldOrigin")
    return __DIO_WO
end
function __DIO_DodgeSeabeast()
    local WorldOrigin = __DIO_GetWorldOrigin()
    if not WorldOrigin then return false end
    for _, v in ipairs(WorldOrigin:GetChildren()) do
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
end
function __DIO_TerrorDodge()
    local WorldOrigin = __DIO_GetWorldOrigin()
    if not WorldOrigin then return false end
    for _, v in ipairs(WorldOrigin:GetChildren()) do
        local name = v.Name:lower()
        if name:find("sharkslam") or name:find("spin") or name:find("chargemodel") then
            return true
        end
    end
    return false
end
__DIO_Dodging = __DIO_Dodging or false
_G.DodgeSeaBeast = true
function __DIO_DoDodge(height)
    height = height or 200
    if __DIO_Dodging == true then return end
    local char = plr.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    __DIO_Dodging = true
    __DIO_DodgeT0 = tick()
    pcall(function()
        if __DIO_LastTween then __DIO_LastTween:Cancel() __DIO_LastTween = nil end
    end)
    local baseY = hrp.Position.Y + height
    local t0 = tick()
    pcall(function()
        repeat
            local c = plr.Character
            local h = c and c:FindFirstChild("HumanoidRootPart")
            if not h then break end
            h.CFrame = CFrame.new(h.Position.X, baseY, h.Position.Z)
            __DIO_wait()
        until (not __DIO_DodgeSeabeast() and not __DIO_TerrorDodge()) or (tick() - t0) > (__DIO_DODGE_MAX or 8) - 2
    end)
    pcall(function() __DIO_wait(0.35) end)
    __DIO_Dodging = false
    __DIO_DodgeT0 = 0
end
__DIO_SafeLoop(function()
    while __DIO_wait(0.1) do
        if not _G.DodgeSeaBeast or __DIO_Dodging
           or not (_G.SeaBeast1 or _G.TerrorShark or _G.Leviathan1 or _G.Shark or _G.Piranha) then
        else
            local __has = false
            local __sb = workspace:FindFirstChild("SeaBeasts")
            if __sb and #__sb:GetChildren() > 0 then __has = true end
            if not __has then
                local __en = workspace:FindFirstChild("Enemies")
                if __en then
                    for ___, __e in pairs(__en:GetChildren()) do
                        local __n = __e.Name
                        if __n == "Terrorshark" or __n == "FishBoat" or __n == "PirateBrigade" or __n == "PirateGrandBrigade" then
                            __has = true
                            break
                        end
                    end
                end
            end
            if __has then
                pcall(function()
                    if __DIO_DodgeSeabeast() or __DIO_TerrorDodge() then
                        __DIO_DoDodge(tonumber(_G.DodgeHeight) or 200)
                    end
                end)
            end
        end
    end
end, "L1347")
UpdStFruit = function()
  for z,x in next, plr.Backpack:GetChildren() do
  StoreFruit = x:FindFirstChild("EatRemote", true)
    if StoreFruit then
      replicated.Remotes.CommF_:InvokeServer("StoreFruit",StoreFruit.Parent:GetAttribute("OriginalName"),
      plr.Backpack:FindFirstChild(x.Name))
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
	  for _, v in next, remote do
	  if tonumber(v['Count']) < 12 then TeleportService:TeleportToPlaceInstance(game.PlaceId, _) end
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
    while true do
        local __okW, __errW = pcall(function()
            local __prevOF = nil
            while __DIO_wait(0.05) do
                local v = (block and block.Parent == workspace and shouldTween) and true or false
                if v ~= __prevOF then __prevOF = v getgenv().OnFarm = v end
            end
        end)
        if not __okW then warn("[DIO] OnFarm watcher died -> restart: " .. tostring(__errW)) end
        task.wait(0.5)
    end
end)
local __DIO_BlockNoClipLast = 0
task.spawn(function()
    local a = game.Players.LocalPlayer
    repeat __DIO_wait() until a.Character and a.Character.PrimaryPart
    block.CFrame = a.Character.PrimaryPart.CFrame
    local __restored = false
    local step = function()
        if getgenv().OnFarm then
            __restored = false
            if block and block.Parent == workspace then
                local b = a.Character and a.Character.PrimaryPart
                if b then
                    block.CFrame = b.CFrame
                end
            end
            local __sitNow = a.Character and a.Character:FindFirstChildOfClass("Humanoid")
            __sitNow = __sitNow and __sitNow.Sit
            local c = a.Character
            if c and not __sitNow and tick() - __DIO_BlockNoClipLast >= 0.1 then
                __DIO_BlockNoClipLast = tick()
                for _, e in ipairs(c:GetChildren()) do
                    if e:IsA("BasePart") and e.CanCollide then e.CanCollide = false end
                end
            end
        elseif not __restored then
            __restored = true
            local c = a.Character
            if c then
                local __h2 = c:FindFirstChildOfClass("Humanoid")
                if not (__h2 and __h2.Sit) then
                    for _, e in ipairs(c:GetChildren()) do
                        if e:IsA("BasePart") and not e.CanCollide then e.CanCollide = true end
                    end
                end
            end
        end
    end
    while true do
        local __okP, __errP = pcall(function()
            while true do
                pcall(step)
                if getgenv().OnFarm then __DIO_wait() else __DIO_wait(0.2) end
            end
        end)
        if not __okP then warn("[DIO] Block pull loop died -> restart: " .. tostring(__errP)) end
        task.wait(0.5)
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
__DIO_PickTweenSpeed = function(distance, rootPos, hum)
    local __sit = (hum ~= nil) and (hum.Sit == true)
    if __sit and _G.BoatTweenSpeed then
        return math.max(tonumber(_G.BoatTweenSpeed) or 300, 1)
    end
    local __base = math.max(tonumber(_G.TweenSpeed) or 300, 1)
    if _G.Neartween == true and not __sit then
        if (tonumber(distance) or math.huge) <= __DIO_NEAR_RADIUS
           or __DIO_MobNear(rootPos) then
            return __DIO_NEAR_SPEED
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
        pcall(function ()
            if _G.TweenCache then
                _G.TweenCache:Cancel()
            end
        end)
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
__DIO_TweenTarget = nil
__DIO_LastTpT = 0
__DIO_LastDist = nil
__DIO_LastHRPPos = nil
__DIO_LastChar = nil
__DIO_WasTweenActive = false
__DIO_FalseSince = nil
__DIO_NewFakeTween = function()
    local t = { PlaybackState = Enum.PlaybackState.Playing }
    t.Cancel = function()
        __DIO_TweenTarget = nil
        __DIO_LastDist = nil
        __DIO_LastHRPPos = nil
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
_tp = function(target)
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
    local character = plr.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local rootPart = character.HumanoidRootPart
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
    __DIO_TweenTarget = gg
    __DIO_LastTweenTarget = gg
    __DIO_LastTpT = tick()
    __DIO_TweenArmedT = tick()
    __DIO_LastTweenT = tick()
__DIO_TweenArmedFlags = nil       
    shouldTween = true
    __DIO_FalseSince = nil
    if type(__DIO_Move) == "function" then __DIO_Move() end
    if type(__DIO_TweenClearBlock) == "function" and __DIO_AnyFeatureOn() then __DIO_TweenClearBlock() end
    local __ft = __DIO_NewFakeTween()
    __DIO_LastTween = __ft
    return __ft
end
if not __DIO_SmoothCtl then
    __DIO_SmoothCtl = true
    task.spawn(function()
        __SVC_RUN.Heartbeat:Connect(function(dt)
            pcall(function()
                if __DIO_Dodging then
                    __DIO_LastDist = nil __DIO_LastHRPPos = nil
                    return
                end
                if not __DIO_TweenValid() then
                    if __DIO_WasTweenActive then
                        __DIO_WasTweenActive = false
                        local rc = plr.Character
                        local rh = rc and rc:FindFirstChildOfClass("Humanoid")
                        if rh and rh.Health > 0 and not rh.Sit then
                            rh:ChangeState(Enum.HumanoidStateType.GettingUp)
                        end
                    end
                    __DIO_TweenTarget = nil
                    __DIO_TweenArmedFlags = nil
                    __DIO_TweenArmedT = 0
                    __DIO_FalseSince = nil
                    __DIO_Parked = false
                    __DIO_LastDist = nil __DIO_LastHRPPos = nil
                    if type(__DIO_TweenSync) == "function" then pcall(__DIO_TweenSync) end
                    return
                end
                __DIO_FalseSince = nil
                local target = __DIO_TweenTarget
                if not target then
                    __DIO_LastDist = nil __DIO_LastHRPPos = nil
                    return
                end
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then return end
                if __DIO_LastChar ~= char then
                    if __DIO_LastChar ~= nil then
                        __DIO_TweenTarget = nil
                        __DIO_LastDist = nil __DIO_LastHRPPos = nil
                        __DIO_LastChar = char
                        return
                    end
                    __DIO_LastChar = char
                end
                local sitting = hum.Sit
                if sitting then
                    local __canBoat, __boatS = true, nil
                    if type(__DIO_CanPivotBoat) == "function" then
                        __canBoat, __boatS = __DIO_CanPivotBoat(hum)
                    end
                    if not __canBoat then
                        __DIO_TweenTarget = nil
                        __DIO_TweenArmedFlags = nil
                        __DIO_TweenArmedT = 0
                        __DIO_LastDist = nil __DIO_LastHRPPos = nil
                        pcall(function()
                            local __bvS = hrp:FindFirstChild("BodyClip")
                            if __bvS then __bvS:Destroy() end
                        end)
                        return
                    end
                    if __boatS then __DIO_BoatCache = __boatS end
                end
                local cur = hrp.Position
                local want = target.Position
                if cur.X ~= cur.X or cur.Y ~= cur.Y or cur.Z ~= cur.Z then return end
                do
                    if want.X ~= want.X or want.Y ~= want.Y or want.Z ~= want.Z then
                        __DIO_TweenTarget = nil
                        return
                    end
                end
                local delta = want - cur
                local dist = delta.Magnitude
                if __DIO_Parked and not __DIO_MoveFresh() then
                    __DIO_LastDist = dist
                    __DIO_LastHRPPos = cur
                    return
                end
                if __DIO_Parked and dist > 25 and __DIO_MoveFresh() then
                    __DIO_Parked = false
                end
                local __fm = _G.ModeFarm
                if __fm == "Obrit" or __fm == "Dodge" then
                    if dist <= 250 or (tick() - (__DIO_LastTpT or 0)) > 1.5 then
                        __DIO_LastDist = dist __DIO_LastHRPPos = cur
                        return
                    end
                end
                if __DIO_LastHRPPos then
                    local jump
                    if sitting then
                        jump = Vector3.new(cur.X - __DIO_LastHRPPos.X, 0, cur.Z - __DIO_LastHRPPos.Z).Magnitude
                    else
                        jump = (cur - __DIO_LastHRPPos).Magnitude
                    end
                    if jump > 80 then
                        __DIO_LastHRPPos = cur
                        __DIO_LastDist = dist
                        if not __DIO_MoveFresh() and not __DIO_AnyFeatureOn()
                           and __DIO_FlyBusy ~= true then
                            __DIO_Parked = false
                            __DIO_TweenTarget = nil
                            return
                        end
                    end
                end
                __DIO_WasTweenActive = true
                local speed = __DIO_PickTweenSpeed(dist, cur, hum)
                local arriveR = sitting and 4 or 2.5
                local rot = target - target.Position
                local __planeDist = sitting and Vector3.new(want.X - cur.X, 0, want.Z - cur.Z).Magnitude or dist
                if __planeDist <= arriveR then
                    local __shift = want - cur
                    if sitting then
                        local seat0 = hum.SeatPart
                        if seat0 then
                            local boat0 = seat0:FindFirstAncestorOfClass("Model")
                            if boat0 then
                                if getgenv().NoClipShip ~= false then
                                    for _, __bp in ipairs(boat0:GetDescendants()) do
                                        if __bp:IsA("BasePart") and __bp.CanCollide then __bp.CanCollide = false end
                                    end
                                end
                                local bcf0 = boat0:GetPivot()
                                boat0:PivotTo(CFrame.new(bcf0.Position + __shift) * (bcf0 - bcf0.Position))
                            end
                        end
                        local __bvA = hrp:FindFirstChild("BodyClip")
                        if not __bvA then
                            __bvA = Instance.new("BodyVelocity")
                            __bvA.Name = "BodyClip"
                            __bvA.MaxForce = Vector3.new(100000, 100000, 100000)
                            __bvA.Velocity = Vector3.new(0, 0, 0)
                            __bvA.Parent = hrp
                        end
                    end
                    hrp.CFrame = CFrame.new(want) * (hrp.CFrame - hrp.CFrame.Position)
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    if block then block.CFrame = hrp.CFrame end
                    __DIO_Parked = true
                    __DIO_ParkT  = tick()
                    __DIO_LastDist = 0 __DIO_LastHRPPos = want
                    return
                end
                dt = math.min(dt or 0.016, 0.1)
                local newPos
                if sitting then
                    local xz = Vector3.new(want.X - cur.X, 0, want.Z - cur.Z)
                    local xzDist = xz.Magnitude
                    local step = math.min(xzDist, math.max(speed, 1) * dt)
                    if xzDist > 0.05 then
                        local dirxz = xz / xzDist
                        newPos = Vector3.new(cur.X + dirxz.X * step, want.Y, cur.Z + dirxz.Z * step)
                    else
                        newPos = Vector3.new(cur.X, want.Y, cur.Z)
                    end
                    local __bv = hrp:FindFirstChild("BodyClip")
                    if not __bv then
                        __bv = Instance.new("BodyVelocity")
                        __bv.Name = "BodyClip"
                        __bv.MaxForce = Vector3.new(100000, 100000, 100000)
                        __bv.Velocity = Vector3.new(0, 0, 0)
                        __bv.Parent = hrp
                    end
                    local seat = hum.SeatPart
                    if seat then
                        local boat = seat:FindFirstAncestorOfClass("Model")
                        if boat then
                            if getgenv().NoClipShip ~= false then
                                for _, __bp in ipairs(boat:GetDescendants()) do
                                    if __bp:IsA("BasePart") and __bp.CanCollide then __bp.CanCollide = false end
                                end
                            end
                            local bcf = boat:GetPivot()
                            boat:PivotTo(CFrame.new(bcf.Position + (newPos - cur)) * (bcf - bcf.Position))
                        end
                    end
                    hrp.CFrame = CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position)
                else
                    local step = math.min(dist, math.max(speed, 1) * dt)
                    local dir = delta / dist
                    newPos = cur + dir * step
                    local __curRot = hrp.CFrame - hrp.CFrame.Position
                    local __rk = math.min(1, (dt or 0.016) * 6)
                    local __blend = __curRot:Lerp(rot, __rk)
                    hrp.CFrame = CFrame.new(newPos) * (__blend - __blend.Position)
                end
                if not sitting then
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    hrp.CanCollide = false
                else
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
                if block then block.CFrame = hrp.CFrame end
                __DIO_LastDist = sitting and Vector3.new(want.X - newPos.X, 0, want.Z - newPos.Z).Magnitude or (want - newPos).Magnitude
                __DIO_LastHRPPos = newPos
            end)
        end)
    end)
end
old_tp = function(p)
    local char = plr.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = p
        __DIO_TweenSet(p)
        if __DIO_Block then __DIO_Block.CFrame = p end
    end
end
topos = function(...) return _tp(...) end
StopTween = function(state)
    if state then
        shouldTween = true
        __DIO_TweenBlockT = 0
        __DIO_TweenBlockDur = 0.5
        __DIO_FalseSince = nil
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
    __DIO_LastDist = nil
    __DIO_LastHRPPos = nil
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
    if (targetCFrame.Position - __hrpTT.Position).Magnitude > 1000 then _tp(targetCFrame) else _tp(targetCFrame) end
end
notween = function(p)
    if __DIO_Dodging == true then
        if type(__DIO_DodgeStale) == "function" then __DIO_DodgeStale() end
        if __DIO_Dodging == true then return end
    end
    if type(__DIO_TweenBlocked) == "function" and __DIO_TweenBlocked() then return end
    local c = plr.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h then
        h.CFrame = p
        __DIO_TweenSet(p)
        if __DIO_Block then __DIO_Block.CFrame = p end
    end
end
__DIO_FarmFlagsOn = function()
    return (_G.StartFarm or _G.SailBoat_Hydra or _G.WardenBoss or _G.AutoFactory or _G.HighestMirage or _G.HCM or _G.PGB or _G.Leviathan1 or _G.UPGDrago or _G.Complete_Trials or _G.TpDrago_Prehis or _G.BuyDrago or __DIO_BuyFlying or _G.BuyMelee_BuyBlackLeg or _G.BuyMelee_BuyElectro or _G.BuyMelee_BuyFishmanKarate or _G.BuyMelee_BuyDragonClaw or _G.AutoFireFlowers or _G.DT_Uzoth or _G.AutoBerry or _G.Prefully or _G.Prehis_Find or _G.Prehis_Skills or _G.Prehis_DB or _G.Prehis_DE or _G.FarmBlazeEM or _G.Dojoo or _G.CollectPresent or _G.AutoLawKak or _G.TpLab or _G.AutoPhoenixF or _G.AutoFarmChest or _G.AutoHytHallow or _G.LongsWord or _G.BlackSpikey or _G.AutoHolyTorch or _G.TrainDrago  or _G.AutoSaber or _G.FarmMastery_Dev or _G.CitizenQuest or _G.AutoEctoplasm or _G.KeysRen or _G.Auto_Rainbow_Haki or _G.obsFarm or _G.AutoBigmom or _G.Doughv2 or _G.AuraBoss or _G.Raiding or _G.Auto_Cavender or _G.TpPly or _G.Bartilo_Quest or _G.Level or _G.FarmEliteHunt or _G.AutoZou or _G.AutoFarm_Bone or getgenv().AutoMaterial or _G.CraftVM or _G.FrozenTP or _G.ShotHL or _G.TPDoor or _G.AcientOne or _G.AutoFarmNear or _G.AutoRaidCastle or _G.DarkBladev3 or _G.AutoFarmRaid or _G.Auto_Cake_Prince or _G.Addealer or _G.TPNpc or _G.TwinHook or _G.FindMirage or _G.FrozenDimension or _G.FarmChestM or _G.Shark or _G.TerrorShark or _G.Piranha or _G.MobCrew or _G.SeaBeast1 or _G.FishBoat or _G.AutoPole or _G.AutoPoleV2 or _G.Auto_SuperHuman or _G.AutoDeathStep or _G.Auto_SharkMan_Karate or _G.Auto_Electric_Claw or _G.AutoDragonTalon or _G.Auto_Def_DarkCoat or _G.Auto_God_Human or _G.Auto_Tushita or _G.AutoMatSoul or _G.AutoKenVTWO or _G.AutoSerpentBow or _G.AutoFMon or _G.Auto_Soul_Guitar or _G.TPGEAR or _G.AutoSaw or _G.AutoTridentW2 or _G.AutoEvoRace or _G.AutoGetQuestBounty or _G.MarinesCoat or _G.TravelDres or _G.Defeating or _G.DummyMan or _G.Auto_Yama or _G.Auto_SwanGG or _G.SwanCoat or _G.AutoEcBoss or _G.Auto_Mink or _G.Auto_Human or _G.Auto_Skypiea or _G.Auto_Fish or _G.CDK_TS or _G.CDK_YM or _G.CDK or _G.AutoFarmGodChalice or _G.AutoFistDarkness or _G.AutoMiror or _G.Teleport or _G.AutoKilo or _G.AutoGetUsoap or _G.Praying or _G.TryLucky or _G.AutoColShad or _G.AutoUnHaki or _G.Auto_DonAcces or _G.AutoRipIngay or _G.DragoV3 or _G.DragoV1 or _G.SailBoats or _G.NextIs or _G.FarmGodChalice or _G.IceBossRen or _G.senth or _G.senth2 or _G.Lvthan or _G.beasthunter or _G.DangerLV or _G.Relic123 or _G.tweenKitsune or _G.Collect_Ember or _G.AutofindKitIs or _G.Snaguine or _G.TwFruits or _G.tweenKitShrine or _G.Tp_LgS or _G.Tp_MasterA or _G.tweenShrine or _G.FarmMastery_G or _G.FarmMastery_S or _G.FarmBoss or _G.AutoFarmAllBoss or _G.AutoFishSlap or _G.TweenBoatOwner or _G.FarmTyrant or _G.FarmPhaBinh or _G.AutoSpawnCP or _G.AutoBerryH or _G.AutoChestBP or _G.FarmEliteHop or _G.AutoHop_Dough or _G.AutoDoughKing or _G.AutoAttackDoughKing or _G.AutoChipFruit or _G.AutoChipBeli or _G.Auto_StartRaid or _G.StartEvent or _G.AutoMysticIsland or _G.AutoPlayerHunter or _G.SafeMode or _G.AutoKillMob or _G.AutoStartPrehistoric or _G.AutoUnHaki or _G.AutoFarmIsland or _G.AutoFarmDungeon or _G.AutoFarmCandy or _G.AutoTP_Gift or _G.AutoTPGift or _G.AutoTPAndCollect or _G.MasterAutoLevel or _G.MasterAutoCandy or _G.TPFloor1 or _G.TPFloor2 or _G.TPFloor3 or _G.TPFloor4 or _G.FarmEliteH or _G.Safemode or _G.Greybeard or _G.ResetPH) and true or false
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
        __DIO_LastDist = nil __DIO_LastHRPPos = nil
        __hrp.AssemblyLinearVelocity = Vector3.new(0, -15, 0)
        return "busy"
    end
    _tp(__seat.CFrame * CFrame.new(0, 1, 0))
    return "goSeat"
end
spawn(function()
  while true do
    local __okST, __errST = pcall(function()
      while __DIO_wait(0.1) do
    pcall(function()
      if __DIO_Block and __DIO_Block.Parent ~= workspace then
          pcall(function() __DIO_Block.Parent = workspace end)
      end
      local __validST = __DIO_TweenValid()
      local __anyF    = __DIO_AnyFeatureOn() or __DIO_FlyBusy == true
      local __curT    = (__DIO_CurTarget ~= nil and __anyF)
      if __DIO_TweenTarget ~= nil and not __validST then
          if not __anyF and not __curT then
              __DIO_TweenDropHard("decor-invalid")
          end
      end
      pcall(__DIO_TweenSync)
      local __hlWant = (__DIO_UserIntent() or __DIO_FlyBusy == true) and (tick() - (__DIO_BootT0 or 0)) > 5 -- [HL2v2]
      __DIO_HlSync(__hlWant)
      if __hlWant then
        local __stompHum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
        if __stompHum and __stompHum.Sit then
            return
        end
        local __chST = plr.Character
        local __hrpST = __chST and __chST:FindFirstChild("HumanoidRootPart")
        if __hrpST and __hrpST:FindFirstChild("BodyClip") then __hrpST:FindFirstChild("BodyClip"):Destroy() end
        if tick() - (__DIO_LastNoclipDecor or 0) < 0.25 then return end
        __DIO_LastNoclipDecor = tick()
        if __chST then for _, no in pairs(__chST:GetDescendants()) do if no:IsA("BasePart") and no.CanCollide then no.CanCollide = false end end end
      else
        __DIO_FalseSince = nil
        pcall(function()
            local __chOFF = plr.Character
            local __hrpOFF = __chOFF and __chOFF:FindFirstChild("HumanoidRootPart")
            if __hrpOFF and __hrpOFF:FindFirstChild("BodyClip") then __hrpOFF:FindFirstChild("BodyClip"):Destroy() end
        end)
      end
    end)
      end
    end)
task.wait(0.5) 
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
MaterialMon=function()local a=game.Players.LocalPlayer;local b=a.Character and a.Character:FindFirstChild("HumanoidRootPart")if not b then return end;shouldRequestEntrance=function(c,d)local e=(b.Position-c).Magnitude;if e>=d then replicated.Remotes.CommF_:InvokeServer("requestEntrance",c)end end;if World1 then if SelectMaterial=="Angel Wings"then MMon={"Shanda","Royal Squad","Royal Soldier","Wysper","Thunder God"}MPos=CFrame.new(-4698,845,-1912)SP="Default"local c=Vector3.new(-4607.82275,872.54248,-1667.55688)shouldRequestEntrance(c,10000)elseif SelectMaterial=="Leather + Scrap Metal"then MMon={"Brute","Pirate"}MPos=CFrame.new(-1145,15,4350)SP="Default"elseif SelectMaterial=="Magma Ore"then MMon={"Military Soldier","Military Spy","Magma Admiral"}MPos=CFrame.new(-5815,84,8820)SP="Default"elseif SelectMaterial=="Fish Tail"then MMon={"Fishman Warrior","Fishman Commando","Fishman Lord"}MPos=CFrame.new(61123,19,1569)SP="Default"local c=Vector3.new(61163.8515625,5.342342376708984,1819.7841796875)shouldRequestEntrance(c,17000)end elseif World2 then if SelectMaterial=="Leather + Scrap Metal"then MMon={"Marine Captain"}MPos=CFrame.new(-2010.5059814453125,73.00115966796875,-3326.620849609375)SP="Default"elseif SelectMaterial=="Magma Ore"then MMon={"Magma Ninja","Lava Pirate"}MPos=CFrame.new(-5428,78,-5959)SP="Default"elseif SelectMaterial=="Ectoplasm"then MMon={"Ship Deckhand","Ship Engineer","Ship Steward","Ship Officer"}MPos=CFrame.new(911.35827636719,125.95812988281,33159.5390625)SP="Default"local c=Vector3.new(61163.8515625,5.342342376708984,1819.7841796875)shouldRequestEntrance(c,18000)elseif SelectMaterial=="Mystic Droplet"then MMon={"Water Fighter"}MPos=CFrame.new(-3385,239,-10542)SP="Default"elseif SelectMaterial=="Radioactive Material"then MMon={"Factory Staff"}MPos=CFrame.new(295,73,-56)SP="Default"elseif SelectMaterial=="Vampire Fang"then MMon={"Vampire"}MPos=CFrame.new(-6033,7,-1317)SP="Default"end elseif World3 then if SelectMaterial=="Scrap Metal"then MMon={"Jungle Pirate","Forest Pirate"}MPos=CFrame.new(-11975.78515625,331.7734069824219,-10620.0302734375)SP="Default"elseif SelectMaterial=="Fish Tail"then MMon={"Fishman Raider","Fishman Captain"}MPos=CFrame.new(-10993,332,-8940)SP="Default"elseif SelectMaterial=="Conjured Cocoa"then MMon={"Chocolate Bar Battler","Cocoa Warrior"}MPos=CFrame.new(620.6344604492188,78.93644714355469,-12581.369140625)SP="Default"elseif SelectMaterial=="Dragon Scale"then MMon={"Dragon Crew Archer","Dragon Crew Warrior"}MPos=CFrame.new(6594,383,139)SP="Default"elseif SelectMaterial=="Gunpowder"then MMon={"Pistol Billionaire"}MPos=CFrame.new(-84.8556900024414, 85.62061309814453, 6132.0087890625)SP="Default"elseif SelectMaterial=="Mini Tusk"then MMon={"Mythological Pirate"}MPos=CFrame.new(-13545,470,-6917)SP="Default"elseif SelectMaterial=="Demonic Wisp"then MMon={"Demonic Soul"}MPos=CFrame.new(-9495.6806640625,453.58624267578125,5977.3486328125)SP="Default"end end end
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
-- [EMBED-LIB] redzlib duoc nhung THANG vao file => UI khong can tai library tu GitHub nua.
-- (Fix loi "UI khong len" khi mang/ISP chan raw.githubusercontent.com hoac jsdelivr)
do
    local __okEmb, __resEmb = pcall(function()
        return (function()
-- ===== BEGIN EMBEDDED REDZ LIBRARY V5 =====
--[[
    REDZ LIBRARY V5 — Reskin UI (giống DIO Loader)
    Chỉ sửa phần UI + Search: nền phẳng, tab nằm ngang dưới header,
    viền/nhấn màu xanh lá, ô search nằm trong thanh tab.
    Toggle / Slider / Dropdown / Keybind và toàn bộ logic chức năng giữ nguyên 100%.
]]

local a=cloneref or(function(...)return...end)

local b=delfolder or deletefolder
local c=delfile or deletefile
local d=makefolder
local e=writefile
local f=readfile

local g=setmetatable({},{
__index=function(g,h)
rawset(g,h,a(game:GetService(h)))
return rawget(g,h)
end
})

local h=g.MarketplaceService
local i=g.UserInputService
local j=g.TweenService
local k=g.HttpService
local l=g.RunService
local m=g.Players

local n=l.Heartbeat

local o=m.LocalPlayer
local p=o:GetMouse()

local q=(gethui or function()return g.CoreGui end)()

local r={
Darker={
Colors={
Background=ColorSequence.new{
ColorSequenceKeypoint.new(0.00,Color3.fromRGB(17,18,17)),
ColorSequenceKeypoint.new(0.50,Color3.fromRGB(17,18,17)),
ColorSequenceKeypoint.new(1.00,Color3.fromRGB(17,18,17))
},
Primary=Color3.fromRGB(80,200,90),
OnPrimary=Color3.fromRGB(35,110,50),
ScrollBar=Color3.fromRGB(30,130,55),
Stroke=Color3.fromRGB(45,45,45),

Error=Color3.fromRGB(255,102,102),
Icons=Color3.fromRGB(232,233,235),

JoinButton=Color3.fromRGB(37,128,69),
Link=Color3.fromRGB(40,150,255),

Dialog={
Background=Color3.fromRGB(28,28,28)
},
Buttons={
Holding=Color3.fromRGB(34,34,34),
Default=Color3.fromRGB(28,28,30)
},
Border={
Holding=Color3.fromRGB(60,60,60),
Default=Color3.fromRGB(38,38,38),
Green=Color3.fromRGB(80,200,90),
GreenDim=Color3.fromRGB(35,110,50),
},
Text={
Default=Color3.fromRGB(255,255,255),
Dark=Color3.fromRGB(200,200,200),
Darker=Color3.fromRGB(175,175,175),
},
Slider={
SliderBar=Color3.fromRGB(30,130,55),
SliderNumber=Color3.fromRGB(232,233,235),
},
Dropdown={
Holder=Color3.fromRGB(30,30,30),
}
},
Glass={
-- ===== Bảng màu LIQUID GLASS XANH LÁ =====
Base=Color3.fromRGB(9,44,31),
Deep=Color3.fromRGB(5,28,20),
Tint=Color3.fromRGB(18,92,60),
Bright=Color3.fromRGB(52,226,126),
Neon=Color3.fromRGB(126,255,182),
Edge=Color3.fromRGB(206,255,228),
White=Color3.fromRGB(255,255,255),
Text=Color3.fromRGB(238,255,246),
TextDim=Color3.fromRGB(178,238,206),
Card=Color3.fromRGB(16,78,52),
CardHover=Color3.fromRGB(26,116,76),
Tab=Color3.fromRGB(56,224,126),
Scrim=Color3.fromRGB(4,26,18),
-- Nền kính (Window / Dialog / Notification)
Window=ColorSequence.new{
ColorSequenceKeypoint.new(0.00,Color3.fromRGB(28,132,86)),
ColorSequenceKeypoint.new(0.32,Color3.fromRGB(12,68,46)),
ColorSequenceKeypoint.new(0.66,Color3.fromRGB(7,40,29)),
ColorSequenceKeypoint.new(1.00,Color3.fromRGB(20,110,72))
},
Panel=ColorSequence.new{
ColorSequenceKeypoint.new(0.00,Color3.fromRGB(24,116,76)),
ColorSequenceKeypoint.new(0.55,Color3.fromRGB(9,52,36)),
ColorSequenceKeypoint.new(1.00,Color3.fromRGB(14,84,56))
},
-- Lớp bóng (sheen) + vệt sáng
Sheen=ColorSequence.new{
ColorSequenceKeypoint.new(0.00,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(0.50,Color3.fromRGB(214,255,232)),
ColorSequenceKeypoint.new(1.00,Color3.fromRGB(180,255,214))
},
SheenTransparency=NumberSequence.new{
NumberSequenceKeypoint.new(0.00,0.930),
NumberSequenceKeypoint.new(0.26,0.965),
NumberSequenceKeypoint.new(0.42,0.855),
NumberSequenceKeypoint.new(0.58,0.930),
NumberSequenceKeypoint.new(0.78,0.975),
NumberSequenceKeypoint.new(1.00,0.940)
},
-- Bóng cho card (option)
CardSheen=ColorSequence.new{
ColorSequenceKeypoint.new(0.00,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(1.00,Color3.fromRGB(198,255,222))
},
CardSheenTransparency=NumberSequence.new{
NumberSequenceKeypoint.new(0.00,0.900),
NumberSequenceKeypoint.new(0.55,0.955),
NumberSequenceKeypoint.new(1.00,0.995)
},
-- Bóng cho tab
TabSheen=ColorSequence.new{
ColorSequenceKeypoint.new(0.00,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(0.45,Color3.fromRGB(206,255,228)),
ColorSequenceKeypoint.new(1.00,Color3.fromRGB(150,244,196))
},
-- Vạch sáng (gạch chân tab, đường kẻ phân cách)
LineGradient=ColorSequence.new{
ColorSequenceKeypoint.new(0.00,Color3.fromRGB(150,255,200)),
ColorSequenceKeypoint.new(0.50,Color3.fromRGB(250,255,252)),
ColorSequenceKeypoint.new(1.00,Color3.fromRGB(150,255,200))
},
LineTransparency=NumberSequence.new{
NumberSequenceKeypoint.new(0.00,0.550),
NumberSequenceKeypoint.new(0.50,0.050),
NumberSequenceKeypoint.new(1.00,0.550)
}
},
Icons={
Error="rbxassetid://10709752996",
Button="rbxassetid://10709791437",
Close="rbxassetid://10747384394",
TextBox="rbxassetid://15637081879",
Search="rbxassetid://10734943674",
Keybind="rbxassetid://10734982144",
Dropdown={
Open="rbxassetid://10709791523",
Close="rbxassetid://10709790948"
}
},
Font={
Normal=Enum.Font.BuilderSans,
Medium=Enum.Font.BuilderSansMedium,
Bold=Enum.Font.BuilderSansBold,
ExtraBold=Enum.Font.BuilderSansExtraBold,
SliderValue=Enum.Font.FredokaOne
},
BackgroundTransparency=0.03
}
}

for s,t in r do
t.Name=s
table.freeze(t)
end

local s={
Information={
Version="v2.0.1",
GitHubOwner="tlredz"
},
Default={
Theme="Darker",
UISize=UDim2.fromOffset(550,380),
SidebarWidth=160
},

Themes=r,

Connections={},
Options={},
Tabs={}
} 

s.Info=s.Information
s.Save=s.Default

local t=workspace.CurrentCamera.ViewportSize local u=function(

u, v, w)
table.insert(s.Connections,u[w or"Connect"](u,v))end


local v={}
v.__index=v local w=function(

w, x)
for y in x:gmatch"[^%.]+"do
w=w[y]
end

return w end local x=function(


x, y, z, A)
if not A then
A=s.CurrentTheme
end

x[y]=w(A,if type(z)=="function"then z()else z)end local y=function(


y, z, A)
for B,C in A do
x(z,B,C,y)
end end local z=function(


z, A)
if d then
local B=z:split"/"
B[#B]=nil

local C=table.concat(B,"/")

if C~=""and(isfolder==nil or not isfolder(C))then
d(C)
end
end

e(z,A)end


local A=false

local B={
MAX_SCALE=1.6,
MIN_SCALE=0.6,

TEXTBOX={
PLACEHOLDER_TEXT="Input"
}
}

function v:add(C,D)
self.Descendants[D]=C

if self.IS_RENDERING then
y(s.CurrentTheme,C,D)
end
end

function v:update()
if self.IS_RENDERING and not self.UPDATED_OBJECTS then
local C=s.CurrentTheme
self.UPDATED_OBJECTS=true

for D,E in self.Descendants do
local F=typeof(E)
if F=="table"then E:update()continue end

y(C,E,D)
end
end
end

function v:destroy()
local C=self.Parent and table.find(self.Parent.Descendants,  self) 

if C then
table.remove(self.Parent.Descendants,C)
end

table.clear(self.Descendants)
setmetatable(self,nil)
end

function v:changeRendering(C)
if self.IS_RENDERING~=C then
self.IS_RENDERING=C
self.UPDATED_OBJECTS=false
end
end

function v:new()
local C=setmetatable({
IS_RENDERING=true,
UPDATED_OBJECTS=false,
Descendants={},
Parent=self.Descendants~=nil and self or nil
},v)

if self.Descendants then
table.insert(self.Descendants,C)
end

return C
end

local C=v:new()

local D,E={}do
local F={}

local G={}do
G.ElementsTable={
Corner=function(H)
return E("UICorner",{
CornerRadius=H or UDim.new(0,8)
})
end,
Stroke=function(H,I)
return E("UIStroke",{
Color=H or Color3.fromRGB(60,60,60),
Thickness=I or 1
})
end,
Image=function(H)
return E("ImageLabel",{
Image=H or"",
BackgroundTransparency=1,
Size=UDim2.fromScale(1,1)
})
end,
Button=function()
return E("TextButton",{
Text="",
Size=UDim2.fromScale(1,1),
AutoButtonColor=false
})
end,
Padding=function(H,I,J,K)
return E("UIPadding",{
PaddingLeft=H or UDim.new(0,10),
PaddingRight=I or UDim.new(0,10),
PaddingTop=J or UDim.new(0,10),
PaddingBottom=K or UDim.new(0,10)
})
end,
ListLayout=function(H)
return E("UIListLayout",{
Padding=H or UDim.new(0,5)
})
end,
Text=function(H)
return E("TextLabel",{
BackgroundTransparency=1,
Text=H or""
})
end,
Gradient=function(H)
return E("UIGradient",{
Color=H
})
end
}

function G:Create(H,I,...)
local J=self.ElementsTable[I]

if J then
local K=J(...)
K.Parent=H
return K
end
end
end

local H={}

function H:Childs(I)
for J=1,#I do
I[J].Parent=self
end
end

function H:Elements(I)
for J,K in pairs(I)do
if type(K)=="table"then
D.SetProperties(G:Create(self,J),K)
else
G:Create(self,J,K)
end
end
end

function H:ThemeTag(I)
local J=I.OBJECTS
I.OBJECTS=nil
return(J or C):add(self,I)
end

function D:SetProperties(I)
for J,K in pairs(I)do
if H[J]then
H[J](self,K)
else
self[J]=K
end
end
end

function D:SetValues(...)
local I=self

for J,K in{...}do
local L=typeof(K)

if L=="table"then
D.SetProperties(I,K)
else
I[if L=="string"then"Name"else"Parent"]=K
end
end

return I
end

local I

function D:Draggable(J,K,L)
local M,N,O,P
local Q=K or 0.28
local R=0
local S local T=function(

T)
local U=T.Position-N
local V
R=tick()

if L then
V=L(
O.X.Scale,O.X.Offset+U.X/J.Scale,
O.Y.Scale,O.Y.Offset+U.Y/J.Scale
)
else
V=UDim2.new(
O.X.Scale,O.X.Offset+U.X/J.Scale,
O.Y.Scale,O.Y.Offset+U.Y/J.Scale
)
end
self.Position=self.Position:Lerp(V,Q)end local U=function()



while I==self do
if(tick()-R)>=1 then
S()
break
end
task.wait()
end end


local V={
[Enum.UserInputType.MouseButton1]=true,
[Enum.UserInputType.Touch]=true
}

local W={
[Enum.UserInputType.MouseMovement]=true,
[Enum.UserInputType.Touch]=true
}

u(self.InputBegan,function(X)
if A==false and I==nil and V[X.UserInputType]then
N=X.Position
O=self.Position
I=self
R=tick()
A=true

local Y;

function S()
A=false
I=nil
Y:Disconnect()
end

task.spawn(U)

Y=X.Changed:Connect(function()
if X.UserInputState==Enum.UserInputState.End then
S()
end
end)
end
end)

u(i.InputChanged,function(X)
if I==self and W[X.UserInputType]then
T(X)
end
end)
end

function D:CreateNewTemplate(J)
return D.CloneObject(F[self],J)
end

function D.new(J,...)
return D.SetValues(Instance.new(J),...)
end

E=D.new
end local F=function(

F)
if F==nil then
return{}
end

if type(F)~="function"and type(F)~="table"then
error(`Failed to get Callback: 'function', or 'table' expected, got {typeof(F)}`,2)
end

if type(F)~="function"then
local G=F[1]
local H=F[2]

F=function(I)
G[H]=I
end
end

return table.pack(F)end local G=function(


G, ...)
for H=1,#G do
task.spawn(G[H],...)
end end


local H="redz-library-v5"
local I=q:FindFirstChild(H)

if not I then
I=E("ScreenGui",H,q,{
IgnoreGuiInset=true
})
end local J=function(

J, K, L, M, ...)
local N=TweenInfo.new(M,Enum.EasingStyle.Quint,...)

return j:Create(J,N,{
[K]=L
})end local K=function(


K)
local L={}
for M=1,#K do
rawset(L,K[M],true)
end
return L end


local L=K(string.split"\n\t,_:;()[]#&=!. \"'*^<>$")local M=function(

M)
return string.gsub(M:lower(),".",function(N)
return L[N]and""or N
end)end local N=function(


N)
local O,P,Q=tostring(N),"",0

for R=#O,1,-1 do
P=O:sub(R,R)..P
Q+=1

if R>1 and Q%3==0 then
P=","..P
end
end

return P end local O=function(


O)
local P="rbxassetid://"
return O:sub(1,#P)==P end local P=function(


P)
return(t.Y/450)*P end local Q=function(


Q)
local R=math.floor(Q/60)
local S=math.floor(Q/60/60)
Q=math.floor((Q-(R*60))*10)/10
R=R-(S*60)

if S>0 then
return`{S}h {R}m {math.floor(Q)}s`
elseif R>0 then
return`{R}m {math.floor(Q)}s`
else
return tostring(Q)
end end


local R={}do
local S={}
local SearchIndex = {}
local tabHiddenState = {}
local T={}
local U={}
local V={}

local W
local X
local Y
local Z
local _
local aa
local ab
local ac
local ad
local ae

local af=""

local ag={SelectedTab=1,Minimized=false}
ag.__index=ag

local ah={}
ah.__index=ah

local ai={}
ai.__index=ai

local aj={}
aj.__index=aj

local ak={}do local al=function()

local al={}
al.__index=function(am,an)
return al[an]or rawget(ai,an)
end

return al end


local am=al()
ak.TextBox=am

local an=al()
ak.Toggle=an

local ao=al()
ak.Slider=ao

local ap=al()
ak.Dropdown=ap

local aq=al()
ak.Keybind=aq

local ar=al()
ak.Dialog=ar local as=function()


Z.Closed=true
Z.Closing=false
setmetatable(Z,nil)

Z=nil
aa.Parent=nil end local at=function()



if Z~=nil then
Z:Close()
end end


function ar:NewOption(au)
local av=au[1]or au.Name or au.Title
local aw=F(au[2]or au.Callback)

table.insert(aw,at)

assert(type(av)=="string",`"Dialog.NewOption.Name". 'string' expected, got {typeof(av)}`)

local ax=E("TextButton",{
AutoButtonColor=false,
Size=UDim2.fromScale(0.2,1),
BackgroundTransparency=1,
TextSize=10,
Text=av,
Elements={
Corner=UDim.new(1,0)
},
ThemeTag={
BackgroundColor3="Colors.Buttons.Default",
TextColor3="Colors.Text.Dark",
Font="Font.Normal"
}
})

local ay=J(ax,"BackgroundTransparency",0,0.3)
local az=J(ax,"BackgroundTransparency",1,0.3)

u(ax.MouseLeave,function()az:Play()end)
u(ax.MouseEnter,function()ay:Play()end)
u(ax.Activated,function()G(aw)end)

ax.Parent=aa.Template.Options
end

function ar:Close(au)
if self.Closed or self.Closing or Z~=self then
return nil
end

self.Closing=true

local av=J(self.TEMPLATE,"Size",self.NEW_SIZE,0.1)
av:Play()

if au then
av.Completed:Wait()
as()
else
u(av.Completed,as)
end
end

function ar.new(au,av)
return setmetatable({
TITLE_LABEL=av,
DESCRIPTION_LABEL=au,
Content=au.Text,
Title=av.Text,

Closed=false,
Closing=false,
Kind="Dialog"
},ar)
end

function ap:SetEnabled(au)
assert(type(au)=="table",`"Dropdown.SetEnabled[param 1]". 'table' expected, got {typeof(au)}`)

self.SET_ENABLED_OPTIONS(au)
end

function ap:Clear()
self.CLEAR_DROPDOWN()
end

function ap:NewOptions(...)
self:Clear()
self:Add(...)
end

function ap:GetOptionsCount()
return#self.DROPDOWN_OPTIONS
end

function ap:Remove(...)
local au={...}
assert(#au>0,"'Dropdown.Remove' requires one or more options.")

for av,aw in au do
self.REMOVE_DROPDOWN_OPTION(aw)
end
end

function ap:Add(...)
local au={...}
assert(#au>0,"'Dropdown.Add' requires one or more options.")

for av,aw in au do
self.ADD_DROPDOWN_OPTION(aw)
end
end

function ap.new(au,av,aw,ax,ay)
return setmetatable({
CALLBACKS=ay,

DESTROY_ELEMENT=av,
VISIBLE_ELEMENT=av,

TITLE_LABEL=aw,
DESCRIPTION_LABEL=ax,
Description=ax.Text,
Title=aw.Text,

Parent=au,
Kind="Dropdown"
},ap)
end

function ao:SetValue(au)
assert(type(au)=="number",`"Slider.SetValue". 'number' expected, got {typeof(au)}`)

if self.Value~=au then
self.WHEN_VALUE_CHANGED(au)
end
end

function ao.new(au,av,aw,ax,ay)
return setmetatable({
CALLBACKS=ay,

DESTROY_ELEMENT=av,
VISIBLE_ELEMENT=av,

TITLE_LABEL=aw,
DESCRIPTION_LABEL=ax,
Description=ax.Text,
Title=aw.Text,

Parent=au,
Kind="Slider"
},ao)
end

function an:SetValue(au)
assert(type(au)=="boolean",`"Toggle.SetValue". 'boolean' expected, got {typeof(au)}`)

if self.Value~=au then
self.Value=au
self.WHEN_VALUE_CHANGED(au)
end
end

function an.new(au,av,aw,ax,ay,az)
return setmetatable({
CALLBACKS=az,
WHEN_VALUE_CHANGED=ay,

DESTROY_ELEMENT=av,
VISIBLE_ELEMENT=av,

TITLE_LABEL=aw,
DESCRIPTION_LABEL=ax,
Description=ax.Text,
Title=aw.Text,

Parent=au,
Kind="Toggle"
},an)
end

function am:SetText(au)
assert(type(au)=="string",`"TextBox.SetText". 'string' expected, got {typeof(au)}`)

self.TEXTBOX.Text=au
return self
end

function am:SetPlaceholder(au)
assert(type(au)=="string",`"TextBox.SetPlaceholder". 'string' expected, got {typeof(au)}`)

self.TEXTBOX.PlaceholderText=au
return self
end

function am:CaptureFocus()
self.TEXTBOX:CaptureFocus()
return self
end

function am:Clear()
self.TEXTBOX.Text=""
return self
end

function am:SetTextFilter(au)
if au~=nil then
assert(type(au)=="function",`"TextBox.SetTextFilter[param 1]". 'function', or 'nil' expected, got {typeof(au)}`)
end

self.TEXTBOX_TEXT_FILTER=au
return self
end

function am.new(au,av,aw,ax,ay,az)
return setmetatable({
Title=av.Text,
Description=aw.Text,
DESCRIPTION_LABEL=aw,
TITLE_LABEL=av,

CALLBACKS=az,
DESTROY_ELEMENT=ax,
VISIBLE_ELEMENT=ax,

TEXTBOX=ay,
BUTTON=ax,

Parent=au,
Kind="TextBox"
},am)
end

am.Set=am.SetText
an.Set=an.SetValue
ao.Set=ao.SetValue
end
-- Loại emoji/ký hiệu khỏi CHỮ HIỂN THỊ của tab (trình execute mobile hay render
-- emoji thành glyph đơn sắc đè lên chữ). .Title gốc vẫn giữ nguyên cho API/search.
local function aCleanTitle(t)
if type(t)~="string" then return t end
local out=table.create(#t)
for p,c in utf8.codes(t) do
local drop=(c>=0x2100 and c<=0x2BFF)or(c>=0x1F000)or(c==0xFE0F)or(c==0x200D)or(c>=0x200 and c<0x400)
if not drop then
table.insert(out,utf8.char(c))
end
end
return table.concat(out)
end local al=function(

al, am, an)
-- Nút tab kiểu sidebar dọc: bề ngang full, chữ canh trái, icon nằm trước chữ
local ao=E("TextButton","Button",an,{
Size=UDim2.new(1,0,0,26),
AutoButtonColor=false,
Text=aCleanTitle(am.Title),
TextSize=11,
TextXAlignment=Enum.TextXAlignment.Left,
TextYAlignment=Enum.TextYAlignment.Center,
TextTruncate=Enum.TextTruncate.AtEnd,
TextTransparency=0,
TextStrokeColor3=Color3.fromRGB(3,32,20),
TextStrokeTransparency=0.75,
BackgroundTransparency=1,
Elements={
Corner=UDim.new(0,7),
Padding={
PaddingLeft=UDim.new(0,12),
PaddingRight=UDim.new(0,8)
},
Gradient={
Rotation=90,
ThemeTag={Color="Glass.TabSheen"}
}
},
ThemeTag={
BackgroundColor3="Glass.Tab",
TextColor3="Glass.Text",
Font="Font.Medium"
}
})

-- Vạch neon dọc bên trái tab đang chọn
local ap=E("Frame","Indicator",ao,{
Position=UDim2.new(0,0,0.5),
AnchorPoint=Vector2.new(0,0.5),
Size=UDim2.new(0,2.5,0.62,0),
BackgroundTransparency=1,
Elements={
Corner=UDim.new(1,0),
Gradient={
Rotation=90,
ThemeTag={Color="Glass.LineGradient",Transparency="Glass.LineTransparency"}
}
},
ThemeTag={
BackgroundColor3="Glass.White"
}
})

local aq=E("ScrollingFrame","Container",{
Size=UDim2.new(1,0,1,0),
Position=UDim2.new(0,0,1),
AnchorPoint=Vector2.new(0,1),
ScrollBarThickness=1.5,
BackgroundTransparency=1,
ScrollBarImageTransparency=0.35,
AutomaticCanvasSize=Enum.AutomaticSize.Y,
ScrollingDirection=Enum.ScrollingDirection.Y,
BorderSizePixel=0,
CanvasSize=UDim2.new(),
ThemeTag={
ScrollBarImageColor3="Glass.Neon"
},
Elements={
Padding={
PaddingLeft=UDim.new(0,10),
PaddingRight=UDim.new(0,10),
PaddingTop=UDim.new(0,10),
PaddingBottom=UDim.new(0,10)
},
ListLayout={
Padding=UDim.new(0,5)
}
}
})

local ar=E("ImageLabel","Icon",ao,{
Position=UDim2.new(0,8,0.5),
Size=UDim2.new(0,14,0,14),
AnchorPoint=Vector2.new(0,0.5),
BackgroundTransparency=1,
ImageTransparency=0.3,
Image=am.Icon or""
})local as=function()


local as=string.sub(ar.Image,1,13)=="rbxassetid://"
ar.Visible=as
-- tự chữa: icon LUÔN ở ô trái 8px, chữ LUÔN canh trái sau icon -> không thể đè lên nhau
ar.Position=UDim2.new(0,8,0.5)
ar.AnchorPoint=Vector2.new(0,0.5)
ar.Size=UDim2.new(0,14,0,14)
ao.TextXAlignment=Enum.TextXAlignment.Left
ao.TextTruncate=Enum.TextTruncate.AtEnd
ao.UIPadding.PaddingLeft=UDim.new(0,as and 30 or 12)end


u(ar:GetPropertyChangedSignal"Image",as)
as()

return ao,aq,ap,ar end local am=function(


am, an, ao, ap)
local aq=E("TextLabel",{
TextXAlignment=Enum.TextXAlignment.Left,
TextTruncate=Enum.TextTruncate.AtEnd,
AutomaticSize=Enum.AutomaticSize.Y,
Size=UDim2.new(1,-20),
Position=UDim2.fromScale(0,0.5),
AnchorPoint=Vector2.new(0,0.5),
BackgroundTransparency=1,
TextSize=11,
ThemeTag={
OBJECTS=C,
TextColor3="Colors.Text.Default",
Font="Font.Medium"
}
})

local ar=V[am]
local as=T[am].Container

local at=E("TextLabel",{
TextXAlignment=Enum.TextXAlignment.Left,
AutomaticSize=Enum.AutomaticSize.Y,
Size=UDim2.new(1,-20),
Position=UDim2.new(0,12,0,15),
BackgroundTransparency=1,
TextWrapped=true,
TextSize=8,
RichText=true,
ThemeTag={
OBJECTS=ar,
TextColor3="Colors.Text.Dark",
Font="Font.Normal"
}
})

local au={
OBJECTS=ar,
BackgroundColor3="Glass.Card"
}

local av=E("TextButton","Option",{
AutomaticSize=Enum.AutomaticSize.Y,
Size=UDim2.new(1,0,0,25),
AutoButtonColor=false,
Text="",
BackgroundTransparency=0.25,
ThemeTag=au,
Elements={
Corner=UDim.new(0,8),
Stroke={
ThemeTag={Color="Glass.Edge"},
Thickness=1,
Transparency=0.86
},
Gradient={
Rotation=115,
ThemeTag={Color="Glass.CardSheen",Transparency="Glass.CardSheenTransparency"}
}
},
Childs={
E("Frame","Holder",{
AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,
Size=ap,
Elements={
ListLayout={
SortOrder=Enum.SortOrder.LayoutOrder,
VerticalAlignment=Enum.VerticalAlignment.Center,
Padding=UDim.new(0,2)
},
Padding={
PaddingBottom=UDim.new(0,5),
PaddingTop=UDim.new(0,5)
}
},
Childs={aq,at}
})
}
})

local aw=av.Holder local ax=function(

ax, ay)
if ay then
if _ then
local az=w(s.CurrentTheme,"Glass.Card")
_.Theme.BackgroundColor3="Glass.Card"
J(_.Button,"BackgroundColor3",az,0.2):Play()
end

_={
Button=av,
Theme=au
}
end

au.BackgroundColor3=ax
J(av,"BackgroundColor3",w(s.CurrentTheme,ax),0.2):Play()end


u(av.MouseLeave,function()ax("Glass.Card",false)end)
u(av.MouseEnter,function()ax("Glass.CardHover",true)end)

u(at:GetPropertyChangedSignal"Text",function()
local ay=#at.Text>0

if at.Visible~=ay then
local az=ay and 0 or 0.5
at.Visible=ay
aw.Position=UDim2.fromScale(0,az)
aw.AnchorPoint=Vector2.new(0,az)
end
end)

aq.Text=an
at.Text=ao or""

av.Parent=as

return av,aq,at end local an=function(


an, ao)
if type(ao)~="table"then
error(`"Tab.Add{an}[Configs]". 'table' expected, got {typeof(ao)}`,2)
end

local ap=ao[1]or ao.Name or ao.Title
local aq=ao.Desc or ao.Description

assert(type(ap)=="string",`"Tab.Add{an}.Title". 'string' expected, got {typeof(ap)}`)

if aq~=nil and type(aq)~="string"then
error(`"Tab.Add{an}.Description". 'string', or 'nil' expected, got {typeof(aq)}`,2)
end

return ap,aq or""end local ao=function(


ao, ap)
if ap~=nil and type(ap)~="string"then
error(`"Tab.Add{ao}.Flag". 'nil', or 'string' expected, got {typeof(ap)}`)
end

return ap end local ap=function()



local ap=160

local aq={
Corner=UDim.new(0,6),
Stroke={
ThemeTag={
Color="Colors.Stroke"
}
},
Gradient={
Rotation=45,
ThemeTag={
Color="Colors.Background"
}
}
}

local ar=E("TextButton","OutBox",{
Size=UDim2.fromScale(1,1),
BackgroundTransparency=1,
Active=true,
Text=""
})

local as=E("Frame","Dropdown",ar,{
Size=UDim2.fromOffset(ap,100),
Position=UDim2.fromOffset(50,50),
Elements=aq,
Active=true,
ThemeTag={
BackgroundTransparency="BackgroundTransparency"
}
})

local at=E("TextButton","Search",as,{
Position=UDim2.new(1,5,0,5),
Size=UDim2.new(0,25,0,25),
AutomaticSize=Enum.AutomaticSize.X,
Active=true,
Elements=aq,
Text="",
ThemeTag={
BackgroundTransparency="BackgroundTransparency"
},
Childs={
E("UIPadding",{
PaddingLeft=UDim.new(0,5),
PaddingRight=UDim.new(0,5),
PaddingBottom=UDim.new(0,5),
PaddingTop=UDim.new(0,5)
}),
E("UIListLayout",{
Padding=UDim.new(0,5),
FillDirection=Enum.FillDirection.Horizontal
}),
E("TextBox","SearchBox",{
Size=UDim2.fromScale(0,1),
Position=UDim2.fromScale(0.5,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
Visible=false,
PlaceholderText="Search Section And Function",
ClearTextOnFocus=false,
Text="",
Elements={
Corner=UDim.new(0,6)
},
ThemeTag={
BackgroundColor3="Colors.Stroke",
TextColor3="Colors.Text.Default",
Font="Font.ExtraBold"
}
}),
E("ImageLabel","SearchIcon",{
Size=UDim2.fromScale(1,1),
SizeConstraint=Enum.SizeConstraint.RelativeYY,
Position=UDim2.fromScale(0.5,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
BackgroundTransparency=1,
ThemeTag={
BackgroundColor3="Colors.Stroke",
ImageColor3="Colors.Icons",
Image="Icons.Search"
}
})
}
})

local au=E("ScrollingFrame",as,{
Size=UDim2.new(1,-6,1,-6),
Position=UDim2.fromScale(0.5,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
ScrollBarThickness=3,
BackgroundTransparency=1,
BorderSizePixel=0,
CanvasSize=UDim2.new(),
ScrollingDirection=Enum.ScrollingDirection.Y,
AutomaticCanvasSize=Enum.AutomaticSize.Y,
Active=true,
ThemeTag={
OBJECTS=C,
ScrollBarImageColor3="Colors.ScrollBar"
},
Elements={
Padding={
PaddingLeft=UDim.new(0,8),
PaddingRight=UDim.new(0,8),
PaddingTop=UDim.new(0,5),
PaddingBottom=UDim.new(0,5)
},
ListLayout={
Padding=UDim.new(0,4)
}
}
})

local av=at.SearchIcon
local aw=at.SearchBox

local ax=130

local ay=J(as,"Size",UDim2.fromOffset(ap,0),0.2)
local az=J(aw,"Size",UDim2.new(0,ax-30,1,0),0.3)
local aA=J(aw,"Size",UDim2.new(0,0,1,0),0.2)

local aB={}
local aC=false
local aD=false
local aE
local aF
local aG
local aH
local aI

local aJ=0

local aK=25
local aL=(aK*12)+10
local aM=5 local aN=function(

aN)
local aO=I.AbsoluteSize.Y/ad.Scale
return math.min((aK*math.max(aN,0.5))+10,aL,aO/1.75)end local aO=function()



local aO=as.AbsolutePosition
local aP=as.AbsoluteSize

local aQ=Vector2.new(p.X,p.Y)

local aR=aQ.X>=aO.X and aQ.X<=(aO.X+aP.X)
local aS=aQ.Y>=aO.Y and aQ.Y<=(aO.Y+aP.Y)

return aR and aS end local aP=function(


aP, aQ)
local aR=aI.AbsolutePosition
local aS=aI.AbsoluteSize
local aT=I.AbsoluteSize
local aU=ad.Scale
local aV=aN(aP)

local aW=aT.X/aU
local aX=aT.Y/aU
local aY=aR.X/aU
local aZ=aR.Y/aU
local a_=aS.X/aU
local a0=aS.Y/aU

local a1=aZ+(a0/2)
local a2=a1-(aV/2)

local a3=aM
local a4=aX-aV-aM

local a5=math.clamp(a2,a3,a4)

local a6=Vector2.new(0,0)

if a5>(aX*0.7)then
a6=Vector2.new(0,1)
a5=math.min(a1+(aV/2),aX-aM)
end

local a7=math.clamp(
aY,
aM,
aW-as.Size.X.Offset-(aM*2)-(at.AbsoluteSize.X/aU)
)

return Vector2.new(a7,a5),a6 end local aQ=function(...)



local aQ,aR=aP(...)

as.AnchorPoint=aR
as.Position=UDim2.fromOffset(aQ.X,aQ.Y)end local aR=function()



if not aD then return end

aD=false

aw.Text=""
aA:Play()
aA.Completed:Wait()
aw.Visible=false end local aS=function()



if aD then return end

aD=true

aw.Visible=true
az:Play()

aw:CaptureFocus()

local aS=as.AbsoluteSize
local aT=I.AbsoluteSize
local aU=ad.Scale
local aV=as.AnchorPoint

local aW=ax*aU

local aX=as.AbsolutePosition.X

local aY=aX+aS.X+5+aW

if aY>aT.X-(aM*aU)then
local aZ=(aT.X-aS.X-aW-5-(aM*aU))/aU

aZ=math.max(aZ,aM)

J(as,"Position",UDim2.fromOffset(aZ,as.Position.Y.Offset),0.3):Play()
end end local aT=function(


aT)
if not aC then
aE=aT
ar.Parent=Y
return true
end end local aU=function()



if aC then return end

if aE then
aE()
aE=nil
end

task.spawn(aR)
aC=true
ay:Play()
ay.Completed:Wait()
ar.Parent=nil
aC=false end local aV=function()



if aw:IsFocused()then
aJ=tick()
return nil
end

if(tick()-aJ)>=0.3 and not aO()then
aU()
end end local aW=function()



for aW,aX in aB do
aW.Parent=nil
aB[aW]=nil
end end local aX=function(


aX, aY)
aX.Selected=aY

if aX.Instance then
local aZ=aX.Instance
local a_=aZ.TextLabel
local a0=aZ.Frame

local a1=aY and 0 or(aH and 0.8 or 1)
local a2=aY and 0 or 0.4
local a3=UDim2.fromOffset(4,aY and 14 or 4)

if aZ.Parent then
J(a0,"BackgroundTransparency",a1,0.35):Play()
J(a_,"TextTransparency",a2,0.35):Play()
J(a0,"Size",a3,0.35):Play()
else
a_.TextTransparency=a2
a0.BackgroundTransparency=a1
a0.Size=a3
end
end end local aY=function(


aY)
if aw.Visible==false or not aY then
local aZ=aG and#aG or 0
as.Size=UDim2.fromOffset(ap,aN(aZ))
return nil
end

if aY then
local aZ=aY.Instance
local a_=M(aw.Text)
aZ.Visible=#a_==0 or aY.SearchText:find(a_)~=nil

if aZ.Visible~=false then
SEARCH_RESULT_COUNT = (SEARCH_RESULT_COUNT or 0) + 1
as.Size=UDim2.fromOffset(ap,aN(SEARCH_RESULT_COUNT))
end
end end local aZ=function(


aZ, a_, a0, a1)
local a2=true

if a_=="+"or a_=="-"then
a2=aZ.Selected==(a_=="+")
a0=a0:sub(2,-1)
end

return a2 and a1:find(a0,1,true)~=nil end local a_=function(


a_, a0)
local a1=E("TextButton",{
Size=UDim2.new(1,0,0,21),
AutoButtonColor=false,
Text="",
Elements={
Corner=UDim.new(0,4)
},
ThemeTag={
BackgroundColor3="Colors.Buttons.Default"
},
Childs={
E("Frame",{
Position=UDim2.new(0,1,0.5),
Size=UDim2.new(0,4,0,4),
BackgroundTransparency=1,
AnchorPoint=Vector2.new(0,0.5),
Elements={
Corner=UDim.new(0.5,0)
},
ThemeTag={
BackgroundColor3="Colors.Primary"
}
}),
E("TextLabel",{
Size=UDim2.fromScale(1,1),
Position=UDim2.fromOffset(10,0),
TextXAlignment=Enum.TextXAlignment.Left,
BackgroundTransparency=1,
TextTransparency=0.4,
Text=a_.DisplayName,
TextSize=9,
ThemeTag={
Font="Font.Bold",
TextColor3="Colors.Text.Default"
}
})
}
})

local a2=0

u(a1.Activated,function()
if(tick()-a2)<0 then return end

if ar.Parent and not aC then
a2=tick()+0.2
aF(a_)
end
end)

a_.SearchText=M(a_.DisplayName)
a_.Instance=a1

if a0 then
local a3=aw.Text

if#a3>0 then
local a4=string.sub(a3,1,1)
local a5=M(aw.Text)
a1.Visible=aZ(a_,a4,a5,a_.SearchText)
end

a1.Parent=au
aY(a_)
end

aX(a_,a_.Selected)end local a0=function(


a0)
aW()
aG=a0

for a1=1,#a0 do
local a2=a0[a1]
local a3=a2.Instance

if a3==nil then
a_(a2)
a3=a2.Instance
end

a3.Parent=au
aB[a3]=true
end

aQ(#a0)
J(as,"Size",UDim2.fromOffset(ap,aN(#a0)),0.3):Play()end local a1=function()



local a1=aw.Text
local a2=string.sub(a1,1,1)
local a3=M(a1)
local a4=#a3==0
local a5=0

for a6=1,#aG do
local a7=aG[a6]
local a8=a4 or aZ(a7,a2,a3,a7.SearchText)
a7.Instance.Visible=a8

if a8 then
a5+=1
end
end

SEARCH_RESULT_COUNT=a5
as.Size=UDim2.fromOffset(ap,aN(a5))end


u(ab:GetPropertyChangedSignal"Visible",aV)
u(ab:GetPropertyChangedSignal"Size",aV)
u(ar.MouseButton1Down,aV)
u(ar.Activated,aV)

u(at.Activated,aS)
u(aw:GetPropertyChangedSignal"Text",a1)

return table.freeze{
CreateOptionTemplate=a_,
SetOptionValue=aX,
CloseDropdown=aU,
OpenDropdown=aT,
SetOptions=a0,
Clear=aW,
SetOnClicked=function(...)
aF=...
end,
SetMultiSelect=function(...)
aH=...
end,
SetHolder=function(...)
aI=...
end
}end


local aq

local ar={"W","A","S","D","Tab","Slash","Backspace","Escape","Unknown"}
local as={"MouseButton1","MouseButton2","MouseButton3"}

local at=K({"number","string","nil","boolean","table"},true)local au=function(

au)
if aq==nil then
aq=K(Enum.KeyCode:GetEnumItems())
end

return typeof(au)=="EnumItem"and aq[au]end


function ah:GetNoSelfCall(av)
assert(type(av)=="string",`"Tab.GetNoSelfCall". 'string' expected, got {typeof(av)}`)
local aw=self[av]
assert(type(aw)=="function",`"Tab.GetNoSelfCall". '{aw}' is not a 'function'-{av}`)

return function(...)
return aw(self,...)
end
end

function ah:AddSection(av)
    assert(av==nil or type(av)=="string",`"Tab.AddSection[param 1]". 'string', or 'nil' expected, got {typeof(av)}`)
    av=av or""

    local aw=V[self]

    local ax=E("Frame","Option",T[self].Container,{
        Size=UDim2.new(1,0,0,26),
        BackgroundTransparency=1
    })

    local ay=E("TextLabel",ax,{
        TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,
        Size=UDim2.new(1,-25,1,-4),
        Position=UDim2.new(0,5,0,0),
        BackgroundTransparency=1,
        TextSize=12,
        Text=av,
        ThemeTag={
            OBJECTS=aw,
            TextColor3="Glass.Text",
            Font="Font.ExtraBold"
        }
    })

    -- Đường kẻ phân cách xanh dưới section header
    E("Frame","SectionSep",ax,{
        Size=UDim2.new(1,-10,0,1),
        Position=UDim2.new(0,5,1,-1),
        AnchorPoint=Vector2.new(0,1),
        BorderSizePixel=0,
        BackgroundTransparency=0.35,
        Elements={
            Gradient={
                Rotation=0,
                ThemeTag={Color="Glass.LineGradient",Transparency="Glass.LineTransparency"}
            }
        },
        ThemeTag={
            OBJECTS=aw,
            BackgroundColor3="Glass.White"
        }
    })

    local obj = setmetatable({
        Title=av,
        DESTROY_ELEMENT=ax,
        VISIBLE_ELEMENT=ax,
        TITLE_LABEL=ay,
        Kind="Section",
        Parent=self
    },ai)

    table.insert(SearchIndex, {
        Title = av:lower():gsub("[%s%p%c]",""), 
        Kind = "section", 
        Tab = self, 
        Frame = ax, 
        IsSection = true
    }) 

    return obj
end

function ah:AddToggle(av)
local aw,ax=an("Toggle",av)
local ay=ao("Toggle",av[4]or av.Flag)

local az=av[2]or av.Default or false
local aA=F(av[3]or av.Callback)

if type(az)~="boolean"then
error(`"Tab.AddToggle.Default". 'boolean' expected, got {typeof(az)}`,2)
end

if ay~=nil and type(ae[ay])=="number"then
az=ae[ay]==0
end

local aB=V[self]
local aC,aD,aE=am(self,aw,ax,UDim2.new(1,-38,0,0))

local aF=E("Frame",aC,{
Size=UDim2.new(0,35,0,18),
Position=UDim2.new(1,-10,0.5),
AnchorPoint=Vector2.new(1,0.5),
Elements={
Corner=UDim.new(0.5,0)
},
ThemeTag={
OBJECTS=aB,
BackgroundColor3="Colors.Stroke"
}
})

local aG=E("Frame",aF,{
BackgroundTransparency=1,
Size=UDim2.new(0.8,0,0.8,0),
Position=UDim2.new(0.5,0,0.5,0),
AnchorPoint=Vector2.new(0.5,0.5)
})

local aH={
OBJECTS=aB,
BackgroundColor3="Colors.OnPrimary"
}

local aI=E("Frame",aG,{
Size=UDim2.new(0,12,0,12),
Position=UDim2.new(0,0,0.5),
AnchorPoint=Vector2.new(0,0.5),
Elements={
Corner=UDim.new(0.5,0)
},
ThemeTag=aH
})

local aJ=tick()
local aK=0.2
local aL={}local aM=function(

aM)
aL={}
for aN=1,#aM do
aM[aN]:Play()
aL[aN]=aM[aN]
end end local aN=function()



for aN=#aL,1,-1 do
local aO=aL[aN]
if aO.PlaybackState==Enum.PlaybackState.Playing then
aO:Cancel()
end
aL[aN]=nil
end end local aO=function(


aO)
if ay~=nil then ae[ay]=aO and 0 or 1 end
G(aA,aO)

local aP=UDim2.new(aO and 1 or 0,0,0.5,0)
local aQ=Vector2.new(aO and 1 or 0,0.5)
local aR=aO and"Colors.Primary"or"Colors.OnPrimary"
local aS=w(s.CurrentTheme,aR)

aH.BackgroundColor3=aR

if self.Selected and(tick()-aJ)>=aK then
aM{
J(aI,"Position",aP,0.25),
J(aI,"AnchorPoint",aQ,0.25),
J(aI,"BackgroundColor3",aS,0.25)
}
else
aN()
aI.Position=aP
aI.AnchorPoint=aQ
aI.BackgroundColor3=aS
end

aJ=tick()end


local aP=ak.Toggle.new(self,aC,aD,aE,aO,aA)
table.insert(SearchIndex,{Title=aw:lower():gsub("[%s%p%c]",""),Kind="toggle",Tab=self,Frame=aC})
aP:SetValue(az)

local aQ=0

u(aC.Activated,function()
if(tick()-aQ)>=aK then
aQ=tick()
aP:SetValue(not aP.Value)
end
end)

return aP
end

function ah:AddButton(av)
local aw,ax=an("Button",av)
local ay=F(av[2]or av.Callback)
local az=av.Debounce or av.Cooldown

local aA=V[self]
local aB,aC,aD=am(self,aw,ax,UDim2.new(1,-20,0,0))

local aE=E("ImageLabel",aB,{
Size=UDim2.new(0,14,0,14),
Position=UDim2.new(1,-10,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
ThemeTag={
OBJECTS=aA,
Image="Icons.Button"
}
})

local aF=0

u(aB.Activated,function()
if az~=nil and(tick()-aF)<0 then return end

if az~=nil then
aF=tick()+az
end

G(ay)
end)

table.insert(SearchIndex,{Title=aw:lower():gsub("[%s%p%c]",""),Kind="button",Tab=self,Frame=aB})
return setmetatable({
CALLBACKS=ay,
DESTROY_ELEMENT=aB,
VISIBLE_ELEMENT=aB,
TITLE_LABEL=aC,
DESCRIPTION_LABEL=aD,

Title=aw,
Description=ax,

Parent=self,
Kind="Button"
},ai)
end

function ah:AddTextBox(av)
local aw,ax=an("TextBox",av)
local ay=ao("TextBox",av[4]or av.Flag)

local az=av[2]or av.Default
local aA=F(av[3]or av.Callback)

local aB=av.Placeholder or av.PlaceholderText
local aC=av.ClearOnFocus or av.ClearTextOnFocus

if az~=nil and type(az)~="string"then
error(`"Tab.AddTextBox.Default". 'string', or 'nil' expected, got {typeof(az)}`,2)
end

if ay and type(ae[ay])=="string"then
az=ae[ay]
end

local aD=V[self]
local aE,aF,aG=am(self,aw,ax,UDim2.new(1,-150,0,0))

local aH=E("Frame",aE,{
Size=UDim2.new(0,150,0,18),
Position=UDim2.new(1,-10,0.5),
AnchorPoint=Vector2.new(1,0.5),
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.Stroke"
},
Elements={
Corner=UDim.new(0,4)
}
})

local aI=E("TextBox",aH,{
Size=UDim2.new(0.85,0,0.85,0),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
BackgroundTransparency=1,
TextScaled=true,
Active=true,
Text="",
PlaceholderText=B.TEXTBOX.PLACEHOLDER_TEXT,
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Text.Default",
Font="Font.Bold"
}
})

local aJ={
OBJECTS=aD,
Image="Icons.TextBox",
ImageColor3="Colors.Icons"
}

local aK=E("ImageLabel",aH,{
Size=UDim2.new(0,12,0,12),
Position=UDim2.new(0,-5,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
ThemeTag=aJ
})

if az~=nil then
aI.Text=az
end

if aC~=nil then
aI.ClearTextOnFocus=aC
end

if aB~=nil then
aI.PlaceholderText=aB
end

local aL=ak.TextBox.new(self,aF,aG,aE,aI,aA)
table.insert(SearchIndex,{Title=aw:lower():gsub("[%s%p%c]",""),Kind="textbox",Tab=self,Frame=aE})
local aM=function(

aM)
aJ.ImageColor3=aM
J(aK,"ImageColor3",w(s.CurrentTheme,aM),0.5):Play()end


if ay~=nil then
u(aI:GetPropertyChangedSignal"Text",function()
ae[ay]=aI.Text
end)
end

u(aI.Focused,function()
aM"Colors.Primary"
end)

u(aI.FocusLost,function()
aM"Colors.Icons"
local aN=aL.TEXTBOX_TEXT_FILTER

if aN then
local aO=aN(aI.Text)
if type(aO)=="string"then
aI.Text=aO
end
end

G(aA,aI.Text)
end)

u(aE.Activated,function()
aI:CaptureFocus()
end)

return aL
end

function ah:AddSlider(av)
local aw,ax=an("Slider",av)
local ay=ao("Slider",av[7]or av.Flag)

local az=av[2]or av.Min
local aA=av[3]or av.Max
local aB=av[4]or av.Increment
local aC=av[5]or av.Default
local aD=F(av[6]or av.Callback)

if aB~=nil and type(aB)~="number"then
error(`"Tab.AddSlider.Increment". 'number', or 'nil' expected, got {typeof(aB)}`,2)
end

if aC~=nil and type(aC)~="number"then
error(`"Tab.AddSlider.Default". 'number', or 'nil' expected, got {typeof(aC)}`,2)
end

assert(type(az)=="number",`"Tab.AddSlider.Min", 'number' expected, got {typeof(az)}`)
assert(type(aA)=="number",`"Tab.AddSlider.Max", 'number' expected, got {typeof(aA)}`)

local aE=V[self]
local aF=T[self].Container

local aG,aH,aI=am(self,aw,ax,UDim2.new(0.55,0,0,0))

if aC==nil then
aC=az
end

if aB==nil then
aB=1
end

if ay~=nil and type(ae[ay])=="number"then
aC=ae[ay]
end

local aJ=E("TextButton",aG,{
Size=UDim2.new(0.45,0,1,0),
Position=UDim2.new(1,0,0,0),
AnchorPoint=Vector2.new(1,0),
AutoButtonColor=false,
BackgroundTransparency=1,
Text=""
})

local aK=E("Frame",aJ,{
Size=UDim2.new(1,-20,0,6),
Position=UDim2.fromScale(0.5,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
ThemeTag={
OBJECTS=aE,
BackgroundColor3="Colors.Stroke"
},
Elements={
Corner=UDim.new(0.5,0)
}
})

local aL=E("Frame",aK,{
Size=UDim2.fromScale(0,1),
BorderSizePixel=0,
ThemeTag={
OBJECTS=aE,
BackgroundColor3="Colors.Primary"
},
Elements={
Corner=UDim.new(0.5,0)
}
})

local aM=E("Frame",aK,{
Size=UDim2.new(0,6,0,12),
BackgroundColor3=Color3.fromRGB(220,220,220),
Position=UDim2.fromScale(0,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
BackgroundTransparency=0.2,
Elements={
Corner=UDim.new(0,6)
}
})

local aN=E("TextLabel",aJ,{
Size=UDim2.new(0,50,0,14),
AnchorPoint=Vector2.new(1,0.5),
Position=UDim2.new(0,-1,0.5,0),
BackgroundTransparency=1,
TextSize=12,
TextXAlignment=Enum.TextXAlignment.Right,
ThemeTag={
OBJECTS=aE,
TextColor3="Colors.Text.Default",
Font="Font.SliderValue"
}
})

local aO=E("UIScale",aN)

local aP=ak.Slider.new(self,aG,aH,aI,aD)
table.insert(SearchIndex,{Title=aw:lower():gsub("[%s%p%c]",""),Kind="slider",Tab=self,Frame=aG})

aP.Min=az
aP.Max=aA
aP.Increment=aB local aQ=function(

aQ)
return(aQ-az)/(aA-az)end local aR=function(


aR)
return(aR*(aA-az))+az end local aS=function(


aS)
return math.round(aS/aB)*aB end local aT=function(


aT, aU)
if aT==aP.Value then return end

if ay~=nil then
ae[ay]=aT
end

task.defer(G,aD,aT)
aP.Value=aT

local aV=UDim2.fromScale(aU,0.5)
local aW=UDim2.fromScale(aU,1)

aN.Text=tostring(math.floor(aT*1000)/1000)

if self.Selected then
J(aM,"Position",aV,0.3):Play()
J(aL,"Size",aW,0.3):Play()
else
aM.Position=aV
aL.Size=aW
end end local aU=function(


aU)
local aV=math.clamp(aS(aU),az,aA)
aT(aV,aQ(aV))end


aP.WHEN_VALUE_CHANGED=aU local aV=function(

aV, aW)
local aX=(p.X-aV.X)/aW.X
local aY=math.clamp(aX,0,1)
local aZ=aR(aY)
local a_=aS(aZ)
local a0=math.clamp(a_,az,aA)
aT(a0,aQ(a0))end


local aW=Random.new()
aU(aC)

u(aJ.MouseButton1Down,function()
if A~=false then return end

J(aM,"BackgroundTransparency",0,0.3):Play()
aF.ScrollingEnabled=false
A=true

local aX=aK.AbsolutePosition
local aY=aK.AbsoluteSize

while i:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)do
aV(aX,aY)
task.wait()
end

A=false
J(aM,"BackgroundTransparency",0.2,0.3):Play()
aF.ScrollingEnabled=true
end)

u(aN:GetPropertyChangedSignal"Text",function()
if not self.Selected then return end

aO.Scale=0.3
J(aO,"Scale",1.2,0.1):Play()

local aX=J(aN,"Rotation",aW:NextNumber(-7.5,7.5),0.15)
aX:Play()
aX.Completed:Wait()

J(aO,"Scale",1,0.2):Play()
J(aN,"Rotation",0,0.1):Play()
end)

return aP
end

function ah:AddDiscordInvite(av)
local aw,ax=an("DiscordInvite",av)
local ay=av.Icon or av.Image or av.Logo
local az=av.Banner or av.BannerColor
local aA=av.Online or av.MembersOnline
local aB=av.Members or av.TotalMembers
local aC=av.Invite or av.Link

assert(type(aC)=="string",`"Tab.AddDiscordInvite.Invite". 'string' expected, got {typeof(aC)}`)

if az~=nil and typeof(az)~="Color3"and type(az)~="string"then
error(`"Tab.AddDiscordInvite.Banner". 'nil', 'Color3', or 'string' expected, got {typeof(az)}`,2)
end

if aA~=nil and type(aA)~="number"then
error(`"Tab.AddDiscordInvite.Online". 'number' expected, got {typeof(aA)}`,2)
end

if aB~=nil and type(aB)~="number"then
error(`"Tab.AddDiscordInvite.Members". 'nil', or 'number' expected, got {typeof(aB)}`,2)
end

if I.ZIndexBehavior~=Enum.ZIndexBehavior.Sibling then
I.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
end

local aD=V[self]
local aE=T[self].Container

local aF=E("Frame","Option",aE,{
BackgroundTransparency=1,
Size=UDim2.new(1,0,0,148)
})

local aG=E("CanvasGroup",aF,{
Size=UDim2.new(0,178,1,-15),
Position=UDim2.new(0,5,1,0),
AnchorPoint=Vector2.new(0,1),
ClipsDescendants=true,
Elements={
Corner=UDim.new(0,9),
Stroke={
ThemeTag={
Color="Colors.Border.Default"
}
}
},
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.Buttons.Default"
}
})

local aH=E("ImageLabel",aG,{
BackgroundColor3=Color3.new(1,1,1),
Size=UDim2.fromScale(1,0.28),
BackgroundTransparency=1
})

local aI=E("TextLabel",aF,{
Position=UDim2.fromOffset(5,0),
Size=UDim2.new(1,0,0,15),
TextColor3=Color3.fromRGB(40,150,255),
TextXAlignment=Enum.TextXAlignment.Left,
BackgroundTransparency=1,
TextSize=9,
Text=aC,
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Link",
Font="Font.Medium"
}
})

local aJ=E("ImageLabel",aG,{
Size=UDim2.fromOffset(33,33),
Position=UDim2.new(0,10,0.28,0),
AnchorPoint=Vector2.new(0,0.5),
Image=ay,
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.Buttons.Default"
},
Elements={
Corner=UDim.new(0,8),
Stroke={
Thickness=2.2,
ApplyStrokeMode=Enum.ApplyStrokeMode.Border,
ThemeTag={
OBJECTS=aD,
Color="Colors.Buttons.Default"
}
}
}
})

local aK=E("TextLabel",aG,{
Size=UDim2.new(1,-10,0,10),
Position=UDim2.new(0,10,0.44,0),
TextXAlignment=Enum.TextXAlignment.Left,
BackgroundTransparency=1,
TextSize=11,
Text=aw,
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Text.Default",
Font="Font.Bold"
}
})

local aL

if aA or aB then
aL=E("Frame",aG,{
Size=UDim2.new(1,-10,0,9),
Position=UDim2.new(0,0,0.52,0),
BackgroundTransparency=1,
Elements={
Padding={
PaddingLeft=UDim.new(0,7),
PaddingRight=UDim.new(0,10)
},
ListLayout={
HorizontalAlignment=Enum.HorizontalAlignment.Left,
VerticalAlignment=Enum.VerticalAlignment.Center,
FillDirection=Enum.FillDirection.Horizontal,
Padding=UDim.new(0,4),
}
}
})local aM=function(

aM, aN)
return E("Frame",aL,{
Size=UDim2.fromScale(0,1),
AutomaticSize=Enum.AutomaticSize.X,
BackgroundTransparency=1,
Childs={
E("Frame",{
Size=UDim2.fromOffset(3,3),
Position=UDim2.new(0,5,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
BackgroundColor3=aM,
Elements={
Corner=UDim.new(1,0)
}
}),
E("TextLabel",{
Size=UDim2.new(0,0,1,0),
Position=UDim2.new(0,12,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
AutomaticSize=Enum.AutomaticSize.X,
BackgroundTransparency=1,
TextSize=7,
Text=aN,
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Text.Darker",
Font="Font.Normal"
}
})
}
})end


if aA~=nil then
aM(Color3.fromRGB(67,181,129),N(aA).." Online")
end
if aB~=nil then
aM(Color3.fromRGB(86,101,105),N(aB).." Members")
end
end

local aM=E("TextLabel",aG,{
Size=UDim2.new(1,-50,0,8),
Position=UDim2.new(0,10,aL and 0.6 or 0.56,0),
TextXAlignment=Enum.TextXAlignment.Left,
AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,
TextSize=8,
Text=ax or"",
TextWrapped=true,
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Text.Darker",
Font="Font.Medium"
}
})

local aN=E("Frame",aG,{
Size=UDim2.new(1,0,0.28,0),
Position=UDim2.fromScale(0,1),
AnchorPoint=Vector2.new(0,1),
BorderSizePixel=0,
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.Buttons.Default"
}
})

if#aM.Text>0 then
aN.Size=UDim2.new(1,0,0.42,0)

E("UIGradient",aN,{
Rotation=-90,
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0.00,0.00),
NumberSequenceKeypoint.new(0.60,0.00),
NumberSequenceKeypoint.new(1.00,1.00)
}
})
end

local aO=E("TextButton",aN,{
Position=UDim2.new(0.5,0,1,-9),
Size=UDim2.new(1,-18,0,18),
AnchorPoint=Vector2.new(0.5,1),
Text="Go to Server",
Elements={
Corner=UDim.new(0.5,0)
},
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.JoinButton",
TextColor3="Colors.Text.Default",
Font="Font.Bold"
}
})

local aP=0

u(aO.Activated,function()
if(tick()-aP)<0 then return end

aP=tick()+5
local aQ=aO.Text
aO.Text="Copied to your Clipboard!"
if setclipboard then 
pcall(setclipboard, aC)
end
task.wait(4)
aO.Text=aQ
end)

if type(az)=="string"then
aH.ScaleType=Enum.ScaleType.Crop
aH.Image=az
elseif typeof(az)=="Color3"then
aH.BackgroundTransparency=0
E("UIGradient",aH,{
Rotation=-15,
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0,az),
ColorSequenceKeypoint.new(1,az:Lerp(Color3.new(1,1,1),0.2))
}
})
end

return setmetatable({
DESTROY_ELEMENT=aF,
VISIBLE_ELEMENT=aF,

Title=aw,
Description=ax,
DESCRIPTION_LABEL=aM,
TITLE_LABEL=aK,

Kind="DiscordInvite",
Parent=self
},ai)
end

function ah:AddParagraph(av,aw)
assert(type(av)=="string",`"Tab.AddParagraph[param 1]". 'string' expected, got {typeof(av)}`)

if aw~=nil and type(aw)~="string"then
error(`"Tab.AddParagraph[param 2]". 'string', or 'nil' expected, got {typeof(aw)}`,2)
end

local ax=V[self]
local ay,az,aA=am(self,av,aw,UDim2.new(1,0,0,0))

return setmetatable({
DESTROY_ELEMENT=ay,
VISIBLE_ELEMENT=ay,
TITLE_LABEL=az,
DESCRIPTION_LABEL=aA,

Title=av,
Description=aw,

Parent=self,
Kind="Paragraph"
},ai)
end

function ah:AddDropdown(av)
local aw,ax=an("Dropdown",av)
local ay=ao("Dropdown",av[5]or av.Flag)

local az=av[2]or av.Options
local aA=av[3]or av.Default
local aB=F(av[4]or av.Callback)
local aC=av.MultiSelect

if aA~=nil and type(aA)~="table"and type(aA)~="string"then
error(`"Tab.AddDropdown.Default". 'string', 'table', or 'nil' expected, got {typeof(aA)}`,2)
end

if az~=nil and type(az)~="table"then
error(`"Tab.AddDropdown.Options". 'table', or 'nil' expected, got {typeof(az)}`,2)
end

if aC~=nil and type(aC)~="boolean"then
error(`"Tab.AddDropdown.MultiSelect". 'boolean', or 'nil' expected, got {typeof(aC)}`,2)
end

if ay and type(ae[ay])==(aC and"table"or"string")then
aA=ae[ay]
end

local aD=V[self]
local aE,aF,aG=am(self,aw,ax,UDim2.new(1,-150,0,0))

local aH=E("Frame",aE,{
Size=UDim2.new(0,150,0,18),
Position=UDim2.new(1,-10,0.5),
AnchorPoint=Vector2.new(1,0.5),
Elements={
Corner=UDim.new(0,4)
},
ThemeTag={
OBJECTS=aD,
BackgroundColor3="Colors.Stroke"
}
})

local aI=E("TextLabel",aH,{
Size=UDim2.new(0.85,0,0.85,0),
AnchorPoint=Vector2.new(0.5,0.5),
Position=UDim2.new(0.5,0,0.5,0),
BackgroundTransparency=1,
TextScaled=true,
Text="...",
ThemeTag={
OBJECTS=aD,
TextColor3="Colors.Text.Default",
Font="Font.Bold"
}
})

local aJ={
OBJECTS=aD,
Image="Icons.Dropdown.Open",
ImageColor3="Colors.Icons"
}

local aK=E("ImageLabel",aH,{
Size=UDim2.new(0,15,0,15),
Position=UDim2.new(0,-5,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
ThemeTag=aJ
})

local aL=ak.Dropdown.new(self,aE,aF,aG,aB)
table.insert(SearchIndex,{Title=aw:lower():gsub("[%s%p%c]",""),Kind="dropdown",Tab=self,Frame=aE})

local aM
local aN=false
local aO=false

local aP={}
local aQ={}
local aR={}
local aS={}

aL.DROPDOWN_OPTIONS=aR
aL.Opened=aO local aT=function(

aT, aU)
aJ.ImageColor3=aT
aJ.Image=aU

J(aK,"ImageColor3",w(s.CurrentTheme,aT),0.35):Play()
aK.Image=w(s.CurrentTheme,aU)end local aU=function(


aU)
aO=aU
aL.Opened=aU

local aV=aU and"Colors.Primary"or"Colors.Icons"
local aW=aU and"Icons.Dropdown.Close"or"Icons.Dropdown.Open"
aT(aV,aW)end local aV=function()



aU(false)end local aW=function()



local aW={}
for aX,aY in aQ do
if not aY then continue end
aW[#aW+1]=aX
end
return aW end local aX=function(


aX)
local aY=type(aX)=="table"and table.concat(aX,", ")or(aX or"")

if#aY>=100 then
aY=aY:sub(1,97).."..."
end

aI.Text=#aY~=0 and aY or"..."end local aY=function()



aN=false

local aY=aC and aW()or aM and aM.Name
G(aB,aC and aQ or aY)
aX(aY)

if ay~=nil then
ae[ay]=aY
end end local aZ=function()



if not aN then
aN=true
task.delay(0.1,aY)
end end local a_=function(


a_)
if aC then
local a0=not a_.Selected
X.SetOptionValue(a_,a0)
aQ[a_.Name]=a0
else
if aM==a_ then
return nil
elseif aM~=nil then
X.SetOptionValue(aM,false)
end

aM=a_
X.SetOptionValue(a_,true)
end

aZ()end local a0=function(


a0)
a0=tostring(a0)
if aS[a0]then return end

local a1={
Name=a0,
DisplayName=a0,
Selected=false
}

if aC and aQ[a0]==nil then
aQ[a0]=false
end

aS[a0]=a1
aR[#aR+1]=a1
return a1 end local a1=function(


a1)
if aO==a1 then return end

if not X then
X=ap()
end

if a1 then
if not X.OpenDropdown(aV)then return end

X.SetHolder(aH)
X.SetMultiSelect(aC)
X.SetOnClicked(a_)
X.SetOptions(aR)
else
X.CloseDropdown()
end

aU(a1)end local a2=function(


a2, a3)
if a3 and type(a2)=="boolean"then
return a2==true and aR[a3]
end

return if type(a2)=="number"then aR[a2]else aS[tostring(a2)]end local a3=function(


a3)
a3.Selected=true

if aC then
aQ[a3.Name]=true
else
aM=a3
end end local a4=function(...)



local a4=a2(...)

if a4 then
a3(a4)
elseif aC and type(...)=="string"then
aP[select(1,...)]=true
end end local a5=function()



if not aA then return end

for a5=1,(aC and#aA or 1)do
a4(aA[a5],a5)
end end local a6=function(


a6)
local a7=table.find(aR,a6)

if a7 then
table.remove(aR,a7)
end

if a6.Instance then
a6.Instance:Destroy()
end

aS[a6.Name]=nil end local a7=function(


a7)
if aC then
local a8=a7.Name
return(aQ[a8]or aP[a8])==true
else
return aM and aM.Name==a7.Name
end end


aL.ADD_DROPDOWN_OPTION=function(a8)
if type(a8)=="table"then
for a9=1,#a8 do
aL:Add(a8[a9])
end

return nil
end

local a9=a0(a8)

if a9 then
if aL.Opened then
X.CreateOptionTemplate(a9,true)
end

if a7(a9)then
a3(a9)

if a9.Instance then
X.SetOptionValue(a9,a9.Selected)
end
end

aZ()
end
end

aL.REMOVE_DROPDOWN_OPTION=function(a8)
local a9=aS[tostring(a8)]
if a9 then
a6(a9)
end
end

aL.CLEAR_DROPDOWN=function()
for a8=#aR,1,-1 do
local a9=aR[a8]
if a9.Instance then
a9.Instance:Destroy()
end

aS[a9.Name]=nil
aR[a8]=nil
end

if aL.Opened then
X.Clear()
end
end

do
if az then
for a8=1,#az do
a0(az[a8])
end
end

if type(aA)=="table"then
a5()
elseif type(aA)=="string"or type(aA)=="number"then
local a8=a2(aA)

if a8 then
a3(a8)
end
end

if aC then
local a8=aW()
task.defer(G,aB,aQ)
aX(a8)
else
local a8=aM
local a9=a8 and a8.Name or""
task.defer(G,aB,a9)
aX(a9)
end
end

u(aE.Activated,function()
a1(not aO)
end)

return aL
end

function ah:Destroy()
assert(type(self)=="table"and self.IS_A_TAB,`"Tab.Destroy". {tostring(self)} is not a tab`)
if self.IS_DESTROYED then return end
local av=table.find(S,self)
assert(av,`"Tab.Destroy". failed to destroy '{self.Title}'`)

table.remove(S,av)

for i = #SearchIndex, 1, -1 do
    if SearchIndex[i].Tab == self then
        table.remove(SearchIndex, i)
    end
end

for aw,ax in T[self]do
ax:Destroy()
end

V[self]:destroy()

T[self]=nil
V[self]=nil

setmetatable(self,nil)
end

function ah:SetVisible(av)
assert(type(av)=="boolean",`"Tab.SetVisible[param 1]". 'boolean' extected, got {typeof(av)}`)

for aw,ax in T[self]do
ax.Visible=av
end
end

-- Chọn tab: LUÔN chỉ 1 tab hiển thị (đã bỏ chế độ chọn 2 tab)
function ah:Select()
local aw=self.Parent
local ax=aw.SelectedTabs or{}

if #ax==1 and ax[1]==self then
return nil
end

for ay=#ax,1,-1 do
local az=ax[ay]

if az~=self then
table.remove(ax,ay)
U[az].Unselect()
end
end

if #ax==0 then
table.insert(ax,self)
end

ac=self
U[self].Select()
aw:RefreshSplit()
end

function ai:SetTitle(av)
assert(type(av)=="string",`"Option.SetTitle". 'string' expected, got {typeof(av)}`)
assert(self.TITLE_LABEL,`"Option.SetTitle". cannot change this option name {self.KIND}:{self.Title}`)

self.TITLE_LABEL.Text=av
self.Title=av
return self
end

function ai:SetDescription(av)
assert(av==nil or type(av)=="string",`"Option.SetDescription". 'string', or 'nil' expected, got {typeof(av)}`)
assert(self.DESCRIPTION_LABEL,`"Option.SetDescription". cannot change this option description {self.KIND}:{self.Title}`)

self.DESCRIPTION_LABEL.Text=av
self.Description=av
return self
end

function ai:SetVisible(av)
assert(typeof(self.VISIBLE_ELEMENT)=="Instance",`"Option.SetVisible". cannot change this option visibility {self.KIND}:{self.Title}`)
assert(type(av)=="boolean",`"Option.SetVisible". 'boolean' expected, got {typeof(av)}`)

self.VISIBLE_ELEMENT.Visible=av
end

function ai:Destroy()
    assert(typeof(self.DESTROY_ELEMENT)=="Instance",`"Option.Destroy". cannot destroy this option {self.KIND}:{self.Title}`)

    for i = #SearchIndex, 1, -1 do
        if SearchIndex[i].Frame == self.DESTROY_ELEMENT then
            table.remove(SearchIndex, i)
            break
        end
    end

    self.DESTROY_ELEMENT:Destroy()
    setmetatable(self,nil)
    self.Destroyed=true
end

function ai:AddCallback(av)
assert(self.CALLBACKS,"\"Option.AddCallback\". cannot add callback to this option.")
assert(type(av)=="function",`"Option.AddCallback[param 1]". 'function' expected, got {typeof(av)}`)

table.insert(self.CALLBACKS,av)
return self
end

ai.NewCallback=ai.AddCallback
ai.SetContent=ai.SetDescription
ai.SetDesc=ai.SetDescription

function aj:CreateMobileMinimizer(av)
-- Quầng sáng mềm phía sau viên bi (tạo trước để nằm dưới nút)
local aH=E("Frame","MobileMinimizerGlow",I,{
Size=UDim2.fromOffset(62,62),
Position=UDim2.fromScale(0.17,0.28),
AnchorPoint=Vector2.new(0.5,0.5),
BackgroundColor3=Color3.fromRGB(126,255,182),
BackgroundTransparency=0.5,
BorderSizePixel=0,
ZIndex=0,
Elements={
Corner=UDim.new(1,0),
Gradient={
Rotation=90,
ThemeTag={Color="Glass.LineGradient",Transparency="Glass.LineTransparency"}
}
}
})

-- Viên bi TRÒN LIQUID GLASS: nút đóng/mở UI nổi trên màn hình (kéo được)
local aw=E("ImageButton","MobileMinimizer",I,{
Size=UDim2.fromOffset(46,46),
Position=UDim2.fromScale(0.17,0.28),
AnchorPoint=Vector2.new(0.5,0.5),
AutoButtonColor=false,
BackgroundColor3=Color3.fromRGB(120,255,180),
BackgroundTransparency=0.45,
ScaleType=Enum.ScaleType.Fit,
ZIndex=1,
Elements={
Corner=UDim.new(1,0),
Padding={
PaddingLeft=UDim.new(0,9),
PaddingRight=UDim.new(0,9),
PaddingTop=UDim.new(0,9),
PaddingBottom=UDim.new(0,9)
},
Gradient={
Rotation=90,
ThemeTag={Color="Glass.TabSheen"}
},
Stroke={
ThemeTag={Color="Glass.Neon"},
Thickness=1.5,
Transparency=0.2
}
},
Childs={
E("Frame","Sheen",{
Size=UDim2.new(1,-10,0,15),
Position=UDim2.new(0,5,0,4),
BackgroundColor3=Color3.fromRGB(255,255,255),
BackgroundTransparency=0.35,
BorderSizePixel=0,
Elements={
Corner=UDim.new(1,0),
Gradient={
Rotation=90,
ThemeTag={Color="Glass.Sheen",Transparency="Glass.SheenTransparency"}
}
}
})
}
})

u(aw.Activated,function()
ag:Minimize()
end)

-- halo bám theo viên bi khi kéo + nhuộm theo màu BackgroundColor3 người dùng truyền
u(aw:GetPropertyChangedSignal("Position"),function()
aH.Position=aw.Position
end)
u(aw:GetPropertyChangedSignal("BackgroundColor3"),function()
aH.BackgroundColor3=aw.BackgroundColor3
end)

-- halo "thở": mờ rồi sáng tuần hoàn bằng 1 tween lặp, không tốn thread
local aP=j:Create(aH,TweenInfo.new(1.8,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{
BackgroundTransparency=0.72
})
aP:Play()

av.Elements={}

if av.Corner then
local aQ=aw:FindFirstChildOfClass("UICorner")
if aQ then
aQ.CornerRadius=av.Corner
else
av.Elements.Corner=av.Corner
end
av.Corner=nil
end

if av.Stroke then
local aQ=aw:FindFirstChildOfClass("UIStroke")
if aQ then
D.SetProperties(aQ,av.Stroke)
else
av.Elements.Stroke=av.Stroke
end
av.Stroke=nil
end

D.Draggable(aw,ad,0.5)
D.SetProperties(aw,av)
aH.Position=aw.Position
aH.BackgroundColor3=aw.BackgroundColor3

return aw
end

function aj:SetKeyCode(av)
assert(au(av),`"Minimizer.SetKeyCode[param 1]". 'KeyCode' expected, got {typeof(av)}`)

self.KeyCode=av
end

function ag:SelectTab(av)
local aw=type(av)=="number"and S[av]

if type(av)=="table"and av.IS_A_TAB then
aw=av
end

if aw then
aw:Select()
elseif not aw then
assert(type(av)=="number",`"Window.SelectTab" number or tab expected, got {typeof(av)}`)
assert(av>0,`"Window.SelectTab" the number must be greater than 0, value: {av}`)
assert(av==math.floor(av),`"Winow.SelectTab" floor number expected, got {av}`)

self.SelectedTab=av
end
end

function ag:Minimize()
ab.Visible=not ab.Visible
end

-- Mỗi lúc chỉ 1 container tab được hiển thị, luôn full panel
function ag:RefreshSplit()
local aw=self.SelectedTabs or{}
local ay=self:GetElements().ContainerHolder

for az=1,#aw do
local aA=aw[az]
local aB=T[aA]and T[aA].Container

if aB then
aB.Parent=ay
aB.AnchorPoint=Vector2.new(0,0)
aB.Position=UDim2.new(0,0,0,0)
aB.Size=UDim2.new(1,0,1,0)
end
end
end

function ag:MakeTab(av)
local aw=av[1]or av.Name or av.Title
local ax=av[2]or av.Icon or av.Image

assert(type(aw)=="string",`"Tab.Title" 'string' expected, got {typeof(aw)}`)
assert(ax==nil or type(ax)=="string",`"Tab.Icon" 'string' expected, got {typeof(ax)}`)

local ay=setmetatable({
Selected=self.SelectedTab==#S+1,
Icon=s:GetIconByName(ax),
Title=aw,

Parent=self,
IS_A_TAB=true
},ah)

local az=self:GetElements()
local aA=az.TabsContainer
local aB=az.ContainerHolder

local aC,aD,aE=al(self,ay,aA)

local aH=0.45

local aI={
J(aE,"BackgroundTransparency",0,aH)
}

local aJ={
J(aE,"BackgroundTransparency",1,aH)
}

local aK=C:new()
V[ay]=aK local aL=function(

aL)
for aM=1,#aL do
aL[aM]:Play()
end end local aM=function()


aL(aI)
J(aC,"BackgroundTransparency",0.32,aH):Play()
ay.Selected=true
aK:changeRendering(true)
aK:update()
aD.Parent=aB
end local aN=function()



aL(aJ)
J(aC,"BackgroundTransparency",1,aH):Play()
ay.Selected=false
aD.Parent=nil
aK:changeRendering(false)end


U[ay]=table.freeze{
Unselect=aN,
Select=aM
}

T[ay]=table.freeze{
SelectTabButton=aC,
Container=aD
}

table.insert(S,ay)

u(aC.Activated,function()
ay:Select()
end)

if ay.Selected then
ay:Select()
end

return ay
end

function ag:StartWindow(av)
local aw=av.MinimizeButton
local ax=av.MainFrame
local ay=av.Resizers
local az=av.TopBar

local aA=av.SubTitle
local aB=av.Title

Y=av.Dropdowns
ab=av.MainFrame
ad=av.UIScale
ae=av.Flags

local aC=ax.Size
local aD=0

function ag:MinimizeButton()
if(tick()-aD)<0 then
return false
end

if self.Minimized then
aw.Image="rbxassetid://10734896206"
J(ax,"Size",aC,0.25):Play()
else
aC=ax.Size
aw.Image="rbxassetid://10734924532"
J(ax,"Size",UDim2.fromOffset(ax.Size.X.Offset,az.Size.Y.Offset),0.25):Play()
end

for aE,aF in ay do
aF.Visible=self.Minimized
end

self.Minimized=not self.Minimized
aD=tick()+0.5

return true
end

function ag:GetTitle()
return aB.Text
end

function ag:GetSubTitle()
return aA.Text
end

function ag:SetTitle(aE)
assert(type(aE)=="string",`"Window.SetTitle". 'string' expected, got {typeof(aE)}`)
assert(#aE>0,"\"Window.SetTitle\". the new 'Title' is too short.")

aB.Text=aE
end

function ag:SetSubTitle(aE)
assert(type(aE)=="string",`"Window.SetSubTitle". 'string' expected, got {typeof(aE)}`)
assert(#aE>0,"\"Window.SetSubTitle\". the new 'SubTitle' is too short.")

aA.Text=aE
end

W=E("Frame",I,{
Size=UDim2.new(0,280,1,0),
Position=UDim2.fromScale(1,0),
AnchorPoint=Vector2.new(1,0),
BackgroundTransparency=1,
Elements={
Padding={
PaddingBottom=UDim.new(0,20)
},
ListLayout={
HorizontalAlignment=Enum.HorizontalAlignment.Center,
VerticalAlignment=Enum.VerticalAlignment.Bottom,
SortOrder=Enum.SortOrder.LayoutOrder,
Padding=UDim.new(0,20)
}
}
})

aa=E("TextButton","OutBox",{
Size=UDim2.fromScale(1,1),
BackgroundTransparency=0.35,
AutoButtonColor=false,
Text="",
ThemeTag={
BackgroundColor3="Glass.Scrim"
},
Childs={
ax:FindFirstChildOfClass"UICorner":Clone(),
E("Frame","Template",{
Size=UDim2.new(0.35,60,0.20,80),
Position=UDim2.fromScale(0.5,0.5),
AnchorPoint=Vector2.new(0.5,0.5),
Active=true,
BackgroundColor3=Color3.new(1,1,1),
BackgroundTransparency=0.06,
Elements={
Corner=UDim.new(0,14),
Stroke={
ThemeTag={Color="Glass.Edge"},
Thickness=1.5,
Transparency=0.22
},
Gradient={
Rotation=125,
ThemeTag={
Color="Glass.Panel"
}
}
},
Childs={
-- Lớp bóng loáng liquid glass cho dialog
E("Frame","GlassSheen",{
Size=UDim2.fromScale(1,1),
BackgroundColor3=Color3.fromRGB(230,255,242),
BorderSizePixel=0,
ZIndex=0,
Elements={
Gradient={
Rotation=118,
ThemeTag={Color="Glass.Sheen",Transparency="Glass.SheenTransparency"}
}
}
}),
E("TextLabel","Title",{
Size=UDim2.new(1,-20,0,20),
TextTruncate=Enum.TextTruncate.AtEnd,
TextSize=15,
Position=UDim2.new(0.5,0,0,28),
AnchorPoint=Vector2.new(0.5,0),
BackgroundTransparency=1,
ThemeTag={
Font="Font.ExtraBold",
TextColor3="Colors.Text.Default"
}
}),
E("TextLabel","Description",{
Position=UDim2.new(0.5,0,0,46),
Size=UDim2.new(1,-20,0,0),
AnchorPoint=Vector2.new(0.5,0),
TextWrapped=true,
TextSize=11,
AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,
ThemeTag={
TextColor3="Colors.Text.Darker",
Font="Font.Medium"
}
}),
E("Frame","Options",{
Size=UDim2.new(1,-20,0.15,18),
Position=UDim2.new(0.5,0,1,-10),
AnchorPoint=Vector2.new(0.5,1),
BackgroundTransparency=1,
Elements={
Padding={
PaddingLeft=UDim.new(0,10),
PaddingRight=UDim.new(0,10),
PaddingBottom=UDim.new(0,30),
PaddingTop=UDim.new(0,30)
},
ListLayout={
HorizontalAlignment=Enum.HorizontalAlignment.Right,
VerticalAlignment=Enum.VerticalAlignment.Center,
FillDirection=Enum.FillDirection.Horizontal
}
}
})
}
})
}
})

aa.Template:SetAttribute("OriginalSize",aa.Template.Size)

u(aa.Activated,function()
if Z~=nil and not Z.Closing and not Z.Closed then
Z:Close()
end
end)

ag.StartWindow=nil
end

function ag:DeleteFlags()
return ae()
end

function ag:SetFlag(av,aw)
assert(type(av)=="string",`"Window.SetFlag[param 1]". 'string' expected, got {typeof(av)}`)

if at[typeof(aw)]~=true then
local ax={}

for ay,az in at do
table.insert(ax,ay)
end

return error(`"Window.SetFlag[param 2]". '{table.concat(ax,"', '")}' expected, got {typeof(aw)}`,2)
end

ae[av]=aw
end

function ag:GetFlag(av)
return ae[av]
end

function ag:ReadFile(av)
assert(type(av)=="string",`"Window.ReadFile[param 1]". 'string' expected, got {typeof(av)}`)
av=`{self.ScriptFolder}/{av}`

if f~=nil and(isfile==nil or not isfile(av))then
return f(av)
end
end

function ag:WriteFile(av,aw)
assert(type(av)=="string",`"Window.WriteFile[param 1]". 'string' expected, got {typeof(av)}`)
av=`{self.ScriptFolder}/{av}`

if aw~=nil and type(aw)~="string"then
error(`"Window.WriteFile[param 2]". 'string', or 'nil' expected, got {typeof(aw)}`,2)
end

if aw==nil then
if c~=nil then
c(`{self.ScriptFolder}/{av}`)
return true
end
else
if e~=nil then
z(`{self.ScriptFolder}/{av}`)
return true
end
end

return false
end

function ag:NewMinimizer(av)
local aw=type(av)=="table"and(av[1]or av.KeyCode)or av

if not au(aw)then
error(`"Window.NewMinimizer.KeyCode". 'KeyCode' expected, got {typeof(aw)}`,2)
end

local ax=setmetatable({
KeyCode=aw
},aj)

u(i.InputBegan,function(ay)
if ay.KeyCode==ax.KeyCode then
ag:Minimize()
end
end)

return ax
end

function ag:Dialog(av)
if self.Minimized then
while not self:MinimizeButton()do task.wait()end
end

if Z then
Z:Close(true)
end

local aw=av.Title or av.Name
local ax=av.Content or av.Description
local ay=av.Options

assert(type(aw)=="string",`"Window.Dialog.Title". 'string' expected, got {typeof(aw)}`)
assert(type(ax)=="string",`"Window.Dialog.Content". 'string' expected, got {typeof(ax)}`)
assert(type(ay)=="table",`"Window.Dialog.Options". 'table' expected, got {typeof(ay)}`)
assert(#ay>0,"\"Window.Dialog.Options\". requires one or more options.")local az=function()


local az=aa.Template
local aA=az.Description
local aB=az.Title

local aC=az:GetAttribute"OriginalSize"
local aD=UDim2.new(aC.X.Scale*1.2,aC.X.Offset,aC.Y.Scale*1.2,aC.Y.Offset)

az.Size=aD
aa.Parent=ab
aA.Text=ax
aB.Text=aw

J(az,"Size",aC,0.3):Play()

local aE=ak.Dialog.new(aA,aB)
aE.NEW_SIZE=aD
aE.TEMPLATE=az

for aF,aG in az.Options:GetChildren()do
if aG:IsA"GuiObject"then
aG:Destroy()
end
end

for aF=#ay,1,-1 do
aE:NewOption(ay[aF])
end

return aE end


Z=az()
return Z
end

function ag:SetNotifyDefaultIcon(av)
assert(type(av)=="string",`"Window.SetNotifyDefaultIcon[param 1]". 'string' expected, got {typeof(av)}`)

af=av
end

function ag:Notify(av)
if type(av)~="table"then
av={}
end

local aw=av[1]or av.Name or av.Title
local ax=av[2]or av.Content
local ay=av[3]or av.Icon or av.Image
local az=av[4]or av.Duration or av.Countdown or av.Time

if self.NOTIFICATION_GROUP then
if az==nil then az=self.Duration end
if ax==nil then ax=self.Content end
if aw==nil then aw=self.Title end
if ay==nil then ay=self.Icon end
end

assert(type(aw)=="string",`"Window.Notify.Title". 'string' expected, got {typeof(aw)}`)
assert(type(ax)=="string",`"Window.Notify.Content". 'string' expected, got {typeof(aw)}`)
assert(ay==nil or type(ay)=="string",`"Window.Notify.Icon". 'nil' or 'string' expected, got {typeof(ay)}`)

if az~=nil and type(az)~="number"then
error(`"Window.Notify.Time". 'number', or 'nil' expected, got {typeof(az)}`,2)
elseif az==nil then
az=5
end

local aA=E("Frame","Notification",W,{
Size=UDim2.new(0.85,0,0,60),
BackgroundTransparency=1,
AutomaticSize=Enum.AutomaticSize.Y
})

local aB=E("TextButton",aA,{
AutomaticSize=Enum.AutomaticSize.Y,
Size=UDim2.fromScale(1,1),
AutoButtonColor=false,
Text="",
BackgroundColor3=Color3.new(1,1,1),
BackgroundTransparency=0.06,
Elements={
Corner=UDim.new(0,10),
Stroke={
ThemeTag={Color="Glass.Edge"},
Thickness=1,
Transparency=0.35
},
Gradient={
Rotation=125,
ThemeTag={
Color="Glass.Panel"
}
}
}
})

local aC=E("UIScale",aA)

local aD=E("Frame","Holder",aB,{
AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,
Size=UDim2.fromScale(1,1),
Elements={
ListLayout={
SortOrder=Enum.SortOrder.LayoutOrder,
VerticalAlignment=Enum.VerticalAlignment.Center,
Padding=UDim.new(0,4)
},
Padding={
PaddingBottom=UDim.new(0,8),
PaddingTop=UDim.new(0,8),
PaddingLeft=UDim.new(0,40)
}
}
})

local aE=E("TextLabel",aD,{
Size=UDim2.new(1,0,0,20),
TextTruncate=Enum.TextTruncate.AtEnd,
TextXAlignment=Enum.TextXAlignment.Left,
TextYAlignment=Enum.TextYAlignment.Bottom,
BackgroundTransparency=1,
TextSize=14,
ThemeTag={
TextColor3="Colors.Text.Default",
Font="Font.Bold"
}
})

local aF=E("TextLabel",aD,{
Size=UDim2.new(1,0,0,20),
TextXAlignment=Enum.TextXAlignment.Left,
TextYAlignment=Enum.TextYAlignment.Top,
AutomaticSize=Enum.AutomaticSize.Y,
BackgroundTransparency=1,
TextWrapped=true,
TextSize=12,
ThemeTag={
TextColor3="Colors.Text.Dark",
Font="Font.Normal"
}
})

local aG=E("ImageLabel",aB,{
Size=UDim2.fromOffset(24,24),
Position=UDim2.new(0,8,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
BackgroundTransparency=1,
ThemeTag={
ImageColor3="Colors.Icons"
}
})

local aH=E("TextLabel",aB,{
Size=UDim2.new(0,40,0,16),
Position=UDim2.new(1,-10,0,8),
AnchorPoint=Vector2.new(1,0),
BackgroundTransparency=1,
TextSize=10,
ThemeTag={
TextColor3="Colors.Text.Darker",
Font="Font.Normal"
}
})

local aI=false

local aJ=J(aC,"Scale",1.22,0.35)
local aK=J(aC,"Scale",1.00,0.35)

local aL=setmetatable({
TITLE_LABEL=aE,
DESCRIPTION_LABEL=aF,
VISIBLE_ELEMENT=aA,
DESTROY_ELEMENT=aA,
NOTIFICATION=aB,

Kind="Notification",
Closed=false,
Parent=self
},ai)

function aL:Close()
if self.Closed==true then return end

self:Destroy()
self.Closed=true

local aM=J(aB,"Position",UDim2.fromScale(3,0),0.8)
aM:Play()
aM.Completed:Wait()
aA:Destroy()
end local aM=function()


ay=s:GetIconByName(ay or af)
aG.Image=ay

if not O(ay)then
aG.Visible=false
aD.UIPadding.PaddingLeft=UDim.new(0,15)
end

aB.Position=UDim2.fromScale(3,0)
J(aB,"Position",UDim2.fromScale(0,0),0.35):Play()

aE.Text=aw
aF.Text=ax

local aM=aB.MouseLeave

while az>0 do
aH.Text=Q(az)
if aI==true then aM:Wait()end
az-=task.wait()
end

aL:Close()end


u(aB.MouseButton1Down,function()aJ:Play()aI=true end)
u(aB.MouseLeave,function()aK:Play()aI=false end)

task.defer(aM)

return aL
end

function ag:NewNotifyGroup(av)
local aw=av[1]or av.Name or av.Title
local ax=av[2]or av.Content
local ay=av[3]or av.Icon or av.Image
local az=av[4]or av.Duration or av.Countdown or av.Time

if aw~=nil and type(aw)~="string"then
error(`"Window.NewNotifyGroup.Title". 'string', or 'nil' expected, got {typeof(aw)}`,2)
end

if ax~=nil and type(ax)~="string"then
error(`"Window.NewNotifyGroup.Content". 'string', or 'nil' expected, got {typeof(ax)}`,2)
end

if ay~=nil and type(ay)~="string"then
error(`"Window.NewNotifyGroup.Icon". 'string', or 'nil' expected, got {typeof(ay)}`,2)
end

if az~=nil and type(az)~="number"then
error(`"Window.NewNotifyGroup.Time". 'number', or 'nil' expected, got {typeof(az)}`,2)
end

return{
NOTIFICATION_GROUP=true,
Notify=ag.Notify,

Duration=az,
Content=ax,
Title=aw,
Icon=ay,
}
end

function ag:GetTabByTitle(av)
assert(type(av)=="string",`"Window.GetTabByTitle[param 1]". 'string' expected, got {typeof(av)}`)

for aw=1,#S do
if S[aw].Title==av then
return S[aw]
end
end
end

ag.NewNotificationGroup=ag.NewNotifyGroup
ag.SetDefaultNotifyIcon = ag.SetNotifyDefaultIcon
ag.GetTabByName=ag.GetTabByTitle
ag.Notificafion=ag.Notify

function ag:PerformSearch(query)
    local q = query:lower():gsub("[%s%p%c]","")

    if q == "" then
        for _,item in SearchIndex do
            if item.searchHidden then
                item.Frame.Visible = true
                item.searchHidden = false
            end
        end
        for _,tab in S do
            if tabHiddenState[tab] then
                T[tab].SelectTabButton.Visible = true
               tabHiddenState[tab] = nil
            end
        end
        return
    end

    local tabHasMatch = {}
    local sectionHasMatch = {} 
    local elementMatches = {}
    local currentSectionPerTab = {}

    -- BƯỚC 1: Quét toàn bộ để tìm các phần tử khớp và đánh dấu Section của chúng
    for _,item in SearchIndex do
        if item.IsSection then
            -- Lưu lại Section gần nhất của Tab này để gán cho các item bên dưới
            currentSectionPerTab[item.Tab] = item
            
            -- Nếu bản thân tên Section khớp với từ khóa tìm kiếm
            local matched = item.Title:find(q,1,true) ~= nil
            if matched then
                elementMatches[item] = true
                tabHasMatch[item.Tab] = true
                sectionHasMatch[item] = true
            end
        else
            -- Logic tìm kiếm bình thường cho Toggle, Button, Slider...
            local matched = item.Title:find(q,1,true) ~= nil
                         or item.Kind:find(q,1,true) ~= nil
            
            if matched then
                elementMatches[item] = true
                tabHasMatch[item.Tab] = true
                
                -- Đánh dấu Section chứa item này là có kết quả, cần được hiển thị
                local parentSection = currentSectionPerTab[item.Tab]
                if parentSection then
                    sectionHasMatch[parentSection] = true
                end
            end
        end
    end

    -- BƯỚC 2: Cập nhật trạng thái Ẩn/Hiện dựa vào kết quả quét ở Bước 1
    for _,item in SearchIndex do
        local shouldBeVisible = false
        
        if item.IsSection then
            -- Section chỉ hiện nếu bản thân nó khớp từ khóa HOẶC có con khớp từ khóa
            shouldBeVisible = sectionHasMatch[item] == true
        else
            -- Phần tử bình thường hiện nếu bản thân nó khớp
            shouldBeVisible = elementMatches[item] == true
        end

        if shouldBeVisible then
            if item.searchHidden or not item.Frame.Visible then
                item.Frame.Visible = true
                item.searchHidden = false
            end
        else
            if not item.searchHidden or item.Frame.Visible then
                item.Frame.Visible = false
                item.searchHidden = true
            end
        end
    end

    -- Ẩn/hiện nút tab bên trái
    local firstVisible = nil
    for _,tab in S do
        local visible = tabHasMatch[tab] == true
        local btn = T[tab].SelectTabButton
        if not visible and btn.Visible then
            btn.Visible = false
            tabHiddenState[tab] = true
        elseif visible and tabHiddenState[tab] then
            btn.Visible = true
            tabHiddenState[tab] = nil
        end
        if visible and not firstVisible then
            firstVisible = tab
        end
    end

    if ac and not tabHasMatch[ac] and firstVisible then
        firstVisible:Select()
    end
end

R.Window=ag
end local aa=function(
 
aa, ab)
local ac=ab.Size.Y.Offset
-- Bề ngang sidebar tab (lưu trong LibrarySettings.json, mặc định 160)
local aT=(aa~=nil and type(aa.SidebarWidth)=="number")and math.clamp(aa.SidebarWidth,120,240)or 160

local ad=UDim2.new(0,aT,1,-ac)
local ae=UDim2.new(1,-(aT+12),1,-(ac+12))

-- Danh sách tab: cột dọc bên trái, cuộn được
local af=E("ScrollingFrame","TabsScroll",{
AutomaticCanvasSize=Enum.AutomaticSize.Y,
ScrollingDirection=Enum.ScrollingDirection.Y,
Position=UDim2.new(0,0,0,ac),
ScrollBarThickness=2,
BackgroundColor3=Color3.fromRGB(120,255,180),
BackgroundTransparency=0.93,
ScrollBarImageTransparency=0.2,
CanvasSize=UDim2.new(),
BorderSizePixel=0,
Size=ad,
ThemeTag={
ScrollBarImageColor3="Glass.Neon"
},
Elements={
Padding={
PaddingLeft=UDim.new(0,8),
PaddingRight=UDim.new(0,8),
PaddingTop=UDim.new(0,8),
PaddingBottom=UDim.new(0,8)
},
ListLayout={
FillDirection=Enum.FillDirection.Vertical,
HorizontalAlignment=Enum.HorizontalAlignment.Left,
VerticalAlignment=Enum.VerticalAlignment.Top,
SortOrder=Enum.SortOrder.LayoutOrder,
Padding=UDim.new(0,4)
}
}
})

-- Panel nội dung bên phải
local ag=E("Frame","Containers",{
Size=ae,
Position=UDim2.new(0,aT+6,0,ac+6),
BackgroundColor3=Color3.fromRGB(150,255,200),
BackgroundTransparency=0.945,
ClipsDescendants=true,
Elements={
Corner=UDim.new(0,8)
}
})

return af,ag end


function s:GetIconByName(ab)
if ab==nil then return end
assert(ab,`"Library.GetIconByName". 'string' expected, got {typeof(ab)}`)

if O(ab)or#ab==0 then
return ab
end

local ac=M(ab)

if self.Icons[ac]then
return"rbxassetid://"..self.Icons[ac]
end

for ad,ae in self.Icons do
if ad:find(ac,1,true)then
return"rbxassetid://"..ae
end
end
end

function s:IsValidTheme(ab)
assert(type(ab)=="string",`"Library.IsValidTheme". string extected, got {typeof(ab)}`)

return self.Themes[ab]~=nil
end

function s:GetThemes()
local ab={}
for ac,ad in self.Themes do
table.insert(ab,ac)
end
return ab
end

function s:GetTheme(ab)
assert(ab==nil or type(ab)=="string",`"Library.GetTheme". 'string' expected, got {typeof(ab)}`)

if ab==nil then
return self.CurrentTheme
end

local ac=self.Themes[ab]
assert(ac~=nil,`"Library.GetTheme". theme not found: {ab}`)
return ac
end

function s:SetTheme(ab)
assert(type(ab)=="string",`"Library.SetTheme". string extected, got {typeof(ab)}`)
local ac=self.Themes[ab]
assert(ac,`"Library.SetTheme". theme not found: {ab}`)

self.CurrentTheme=ac
self.WindowSettings.SelectedTheme=ac.Name

C:update()
end

function s:SetUIScale(ab)
local ac=B.MIN_SCALE
local ad=B.MAX_SCALE

assert(type(ab)=="number",`"Library.SetUIScale". 'number' expected, got {typeof(ab)}`)
assert(ab>=ac and ab<=ad,`"Library.SetUIScale". Min Scale: {ac}, Max Scale: {ad}`)

I.Scale.Scale=P(ab)
end

function s:GetMaxScale()
return B.MAX_SCALE
end

function s:GetMinScale()
return B.MIN_SCALE
end

function s:GetCurrentTheme()
if not self.LOADED_UI_LIBRARY then
return error("failed to get current theme: UI is not loaded",2)
end
return self.CurrentTheme
end

function s:Destroy()
for ab,ac in self.Connections do
ac:Disconnect()
end

if I and I:GetAttribute"UID"==self.SCREENGUI_UID then
pcall(I.Destroy,I)
end
end

function s:MakeWindow(ab)
if self.LOADED_UI_LIBRARY then
return error("you can create only 1 Window",2)
end

local ac=math.random()
I:SetAttribute("UID",ac)
self.SCREENGUI_UID=ac
I:ClearAllChildren()

local ad=E("UIScale","Scale",I,{
Scale=P(1)
})

local ae={
Title=ab[1]or ab.Name or ab.Title,
SubTitle=ab[2]or ab.SubName or ab.SubTitle,
ScriptFolder=ab[3]or ab.ScriptFolder or ab.FolderName
}

assert(type(ae.Title)=="string",`"Window.Title". 'string' expected, got {typeof(ae.Title)}`)
assert(type(ae.SubTitle)=="string",`"Window.SubTitle". 'string' expected, got {typeof(ae.SubTitle)}`)

if ae.ScriptFolder~=nil and type(ae.ScriptFolder)~="string"then
return error(`"Window.ScriptFolder". 'string', or nil expected, got {typeof(ae.ScriptFolder)}`,2)
end

if ae.ScriptFolder~=nil and string.find(ae.ScriptFolder,"/")then
return error("\"Window.ScriptFolder\" is not valid, unexpected char \"/\"",2)
end

local af=(function()
local af=ae.ScriptFolder
local ag=false

local ah,ai=pcall(function()
return af and k:JSONDecode(f(`{af}/LibrarySettings.json`))
end)

if type(ai)~="table"then
ai={}
end local aj=function()


ag=false

return pcall(function()
return z(`{af}/LibrarySettings.json`,k:JSONEncode(ai))
end)end local ak=function(


ak, al, am)
rawset(ai,al,am)

if af and not ag then
ag=true
task.delay(0.5,aj)
end end


return setmetatable({},{
__newindex=ak,
__index=ai
})
end)()

local ag=(function()
local ag=ae.ScriptFolder
local ah=false

local ai,aj=pcall(function()
return ag and k:JSONDecode(f(`{ag}/ScriptFlags.json`))
end)

if type(aj)~="table"then
aj={}
end local ak=function()


ah=false

return pcall(function()
z(`{ag}/ScriptFlags.json`,k:JSONEncode(aj))
end)end local al=function(


al, am, an)
rawset(aj,am,an)

if ag and not ah then
ah=true
task.delay(0.5,ak)
end end local am=function()



table.clear(aj)
return pcall(function()
return ag and c(`{ag}/ScriptFlags.json`)
end)end


return setmetatable({},{
__newindex=al,
__call=am,
__index=aj
})
end)()

self.ThemesObjects=C
self.WindowSettings=af
self.Flags=ag

self.Icons=(function()
local ah=ae.ScriptFolder

local ai,aj=pcall(function()
return loadstring(f(`{ah}/Icons.lua`))()
end)

if ai and type(aj)=="table"then
return aj
end

local ak=`https://raw.githubusercontent.com/{self.Information.GitHubOwner}`
local al=`{ak}/Library/refs/heads/main/redz-V5-remake/Utils/Icons.lua`
local am local an=function()


return z(`{ah}/Icons.lua`,am)end


local ao,ap=pcall(function()
am=game:HttpGet(al)
return loadstring(am)()
end)

if ao and type(ap)=="table"then
if type(am)=="string"then
pcall(an)
end

return ap
end

return{}
end)()

if type(af.SelectedTheme)=="string"and self:IsValidTheme(af.SelectedTheme)then
self:SetTheme(af.SelectedTheme)
else
self:SetTheme(self.Default.Theme)
end

self.LOADED_UI_LIBRARY=true

local ah=self.Default.UISize

if af and type(af.UISize)=="table"then
local ak,al=unpack(af.UISize)

if type(ak)=="number"and type(al)=="number"then
local am=I.AbsoluteSize
ak=math.clamp(ak,430,1000)
al=math.clamp(al,200,500)
ah=UDim2.fromOffset(ak,al)
end
end

local ak=E("Frame","Window",I,{
Position=UDim2.new(0.5,-ah.X.Offset/2,0.5,-ah.Y.Offset/2),
Active=true,
Size=ah,
ClipsDescendants=true,
BackgroundColor3=Color3.new(1,1,1),
BackgroundTransparency=0.1,
Elements={
Corner=UDim.new(0,14),
Stroke={
ThemeTag={Color="Glass.Edge"},
Thickness=1.5,
Transparency=0.22
},
Gradient={
Rotation=125,
ThemeTag={
Color="Glass.Window"
}
}
},
Childs={
-- Vệt sáng chéo (sheen) - linh hồn của liquid glass
E("Frame","GlassSheen",{
Size=UDim2.fromScale(1,1),
BackgroundColor3=Color3.fromRGB(230,255,242),
BorderSizePixel=0,
ZIndex=0,
Elements={
Gradient={
Rotation=118,
ThemeTag={Color="Glass.Sheen",Transparency="Glass.SheenTransparency"}
}
}
}),
-- Viền sáng mảnh ở cạnh trên khung kính
E("Frame","GlassRimLight",{
Size=UDim2.new(1,0,0,1),
BackgroundColor3=Color3.fromRGB(240,255,248),
BorderSizePixel=0,
ZIndex=0,
Elements={
Gradient={
Rotation=0,
Color=ColorSequence.new{
ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),
ColorSequenceKeypoint.new(1,Color3.fromRGB(170,255,210))
},
Transparency=NumberSequence.new{
NumberSequenceKeypoint.new(0.00,0.30),
NumberSequenceKeypoint.new(0.45,0.75),
NumberSequenceKeypoint.new(1.00,1.00)
}
}
}
})
}
}
)

-- Quầng sáng neon mềm bao quanh khung kính
E("UIStroke","GlassGlow",ak,{
ThemeTag={Color="Glass.Neon"},
Thickness=4,
Transparency=0.88
})

u(ak.Destroying,function()
self:Destroy()
end)

u(I:GetAttributeChangedSignal"UID",function()
self:Destroy()
ak:Destroy()
end)

D.Draggable(ak,ad,0.5)

local al=E("Folder","Components",ak)
local am=E("Folder","Dropdowns",I)

local an=E("Frame","TopBar",al,{
Size=UDim2.new(1,0,0,32),
BackgroundTransparency=1
})

local ao=E("TextLabel","Title",an,{
TextXAlignment=Enum.TextXAlignment.Left,
AutomaticSize=Enum.AutomaticSize.XY,
Position=UDim2.new(0,15,0.5,0),
AnchorPoint=Vector2.new(0,0.5),
Text=ae.Title,
TextSize=13,
BackgroundTransparency=1,
ThemeTag={
TextColor3="Glass.Text",
Font="Font.ExtraBold"
},
Childs={
E("TextLabel","SubTitle",{
Size=UDim2.fromScale(0,1),
AutomaticSize="X",
AnchorPoint=Vector2.new(0,1),
Position=UDim2.new(1,6,0.9),
Text=ae.SubTitle,
BackgroundTransparency=1,
TextXAlignment="Left",
TextYAlignment="Bottom",
TextSize=9,
ThemeTag={
TextColor3="Glass.TextDim",
Font="Font.Normal"
}
})
}
})

local ap=E("Folder","Buttons",an,{
Childs={
E("ImageButton","Close",{
Size=UDim2.new(0,18,0,18),
Position=UDim2.new(1,-10,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=1,
BackgroundColor3=Color3.fromRGB(255,35,35),
AutoButtonColor=false,
ThemeTag={
Image="Icons.Close"
},
Elements={
Corner=UDim.new(0.2,0)
}
}),
-- Nút mở/thu UI: viên bi tròn LIQUID GLASS phát sáng
E("ImageButton","Minimize",{
Size=UDim2.new(0,24,0,24),
Position=UDim2.new(1,-38,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundColor3=Color3.fromRGB(120,255,180),
BackgroundTransparency=0.62,
Image="rbxassetid://10734896206",
ImageColor3=Color3.fromRGB(238,255,246),
ScaleType=Enum.ScaleType.Fit,
AutoButtonColor=false,
Elements={
Corner=UDim.new(1,0),
Padding={
PaddingLeft=UDim.new(0,5),
PaddingRight=UDim.new(0,5),
PaddingTop=UDim.new(0,5),
PaddingBottom=UDim.new(0,5)
},
Gradient={
Rotation=90,
ThemeTag={Color="Glass.TabSheen"}
},
Stroke={
ThemeTag={Color="Glass.Neon"},
Thickness=1,
Transparency=0.25
}
},
ThemeTag={
BackgroundColor3="Glass.Tab"
}
})
}
})

local aq=ap.Minimize
local ar=ap.Close

-- Quầng sáng mềm sau viên bi mở UI
E("Frame","MinimizeGlow",an,{
Size=UDim2.new(0,34,0,34),
Position=UDim2.new(1,-33,0.5),
AnchorPoint=Vector2.new(1,0.5),
BackgroundTransparency=0.55,
BackgroundColor3=Color3.fromRGB(126,255,182),
BorderSizePixel=0,
ZIndex=0,
Elements={
Corner=UDim.new(1,0),
Gradient={
Rotation=90,
ThemeTag={Color="Glass.LineGradient",Transparency="Glass.LineTransparency"}
}
}
})
aq.ZIndex=1

local as=setmetatable(ae,{
__index=R.Window
})

as.SelectedTabs={}

local at,au=aa(af,an)

at.Parent=al
au.Parent=al

-- Viền kính phát sáng bao quanh panel Content
E("UIStroke","ContentStroke",au,{
ThemeTag={Color="Glass.Neon"},
Thickness=1,
Transparency=0.4,
ApplyStrokeMode=Enum.ApplyStrokeMode.Border
})

-- Đường kẻ phát sáng dưới TopBar (ngăn header với thanh tab)
E("Frame","TopBarSeparator",an,{
Size=UDim2.new(1,0,0,1),
Position=UDim2.new(0,0,1,-1),
AnchorPoint=Vector2.new(0,1),
BorderSizePixel=0,
BackgroundTransparency=0.25,
Elements={
Gradient={
Rotation=0,
ThemeTag={Color="Glass.LineGradient",Transparency="Glass.LineTransparency"}
}
},
ThemeTag={BackgroundColor3="Glass.White"}
})

-- Đường kẻ phát sáng DỌC ngăn cách sidebar tab và panel Content
E("Frame","TabBarSeparator",al,{
Size=UDim2.new(0,1,1,-(an.Size.Y.Offset+13)),
Position=UDim2.new(0,at.Size.X.Offset,0,an.Size.Y.Offset+5),
AnchorPoint=Vector2.new(0.5,0),
BorderSizePixel=0,
BackgroundTransparency=0.25,
Elements={
Gradient={
Rotation=90,
ThemeTag={Color="Glass.LineGradient",Transparency="Glass.LineTransparency"}
}
},
ThemeTag={BackgroundColor3="Glass.White"}
})

local av=table.freeze{
ContainerHolder=au,
TabsContainer=at,
Components=al,
MainFrame=ak
}

function as:GetElements()
return av
end

local aw=E("Frame","ControlWindowSize",ak,{
Size=UDim2.new(0,35,0,35),
Position=ak.Size,
AnchorPoint=Vector2.new(0.8,0.8),
BackgroundTransparency=1,
Active=true,
Elements={
Corner=UDim.new(0,6)
},
ThemeTag={
BackgroundColor3="Glass.Neon"
}
})

-- Tay nắm DỌC: kéo ngang để đổi bề rộng sidebar tab
local ax=E("Frame","ControlTabsSize",ak,{
Size=UDim2.new(0,6,1,-(an.Size.Y.Offset+16)),
Position=UDim2.new(0,at.Size.X.Offset+3,0,an.Size.Y.Offset+8),
AnchorPoint=Vector2.new(0.5,0),
BackgroundTransparency=1,
Active=true,
Elements={
Corner=UDim.new(1,0)
},
ThemeTag={
BackgroundColor3="Glass.Neon"
}
})local ay=function(

ay)
local az=ay:GetAttribute"Resizing"
ay:SetAttribute("Resizing",tick())

if az and(tick()-az)<=0.1 then
return nil
end

J(ay,"BackgroundTransparency",0.5,0.3):Play()
while tick()-ay:GetAttribute"Resizing"<=0.1 do task.wait()end
J(ay,"BackgroundTransparency",1,0.4):Play()end


u(aw:GetPropertyChangedSignal"Position",function()
ay(aw)
local az=aw.Position
ak.Size=az
af.UISize={az.X.Offset,az.Y.Offset}
end)

u(ax:GetPropertyChangedSignal"Position",function()
ay(ax)
local az=ax.Position
local aB=math.clamp(az.X.Offset-3,96,240)
at.Size=UDim2.new(0,aB,1,-an.Size.Y.Offset)
au.Size=UDim2.new(1,-(aB+12),1,-(an.Size.Y.Offset+12))
au.Position=UDim2.new(0,aB+6,0,an.Size.Y.Offset+6)
af.SidebarWidth=aB
local aC=al.TabBarSeparator
if aC then
aC.Position=UDim2.new(0,aB,0,an.Size.Y.Offset+5)
end
end)

D.Draggable(aw,ad,0.68,function(az,aA,aB,aC)
return UDim2.fromOffset(math.clamp(aA,430,1000),math.clamp(aC,200,500))
end)

D.Draggable(ax,ad,0.68,function(aA,aB,aC,aD)
return UDim2.new(0,math.clamp(aB,99,243),aC,aD)
end)

local aA={
Title="Close Window?",
Content="You Want Close UI?",
Options={
{
Title="YES",
Callback=function()self:Destroy()end
},
{
Title="NO"
}
}
}

u(aq.MouseEnter,function()aq.BackgroundTransparency=0.38 end)
u(aq.MouseLeave,function()aq.BackgroundTransparency=0.62 end)

u(ar.MouseEnter,function()ar.BackgroundTransparency=0.65 end)
u(ar.MouseLeave,function()ar.BackgroundTransparency=1.00 end)

as.SetUIScale=self.SetUIScale
as.SUBTITLE_LABEL=ao.SubTitle
as.TITLE_LABEL=ao

local aB=as:StartWindow{
Resizers={aw,ax},
MinimizeButton=aq,
Dropdowns=am,
MainFrame=ak,
TopBar=an,

SubTitle=ao.SubTitle,
Title=ao,

UIScale=ad,
Flags=ag
}

u(aq.Activated,function()
as:MinimizeButton()
end)

u(ar.Activated,function()
    as:Dialog(aA)
end)

local searchContainerHeight = 22

local searchContainer = E("Frame", "SearchContainer", an, {
    Size = UDim2.new(0, 170, 0, searchContainerHeight),
    Position = UDim2.new(1, -59, 0.5, 0), -- Nằm giữa subtitle và nút thu nhỏ (-)
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundTransparency = 1,
    ZIndex = 5
})

-- Background của Search Box (màu nền bo góc) + viền xanh
local searchInputBg = E("Frame", "SearchBg", searchContainer, {
    Size = UDim2.fromScale(1, 1),
    ThemeTag = {
        BackgroundColor3 = "Colors.Stroke"
    },
    Elements = {
        Corner = UDim.new(0, 6),
        Stroke = {
            ThemeTag = {Color = "Colors.Border.Green"},
            Thickness = 1
        }
    }
})

-- Ô nhập Text tìm kiếm
local searchInput = E("TextBox", "SearchBar", searchInputBg, {
    Size = UDim2.new(1, -25, 1, 0), -- Chiều rộng trừ đi khoảng trống cho Icon
    Position = UDim2.new(0, 8, 0, 0), -- Cách lề trái 8px
    BackgroundTransparency = 1,
    PlaceholderText = "Search Section And Function",
    Text = "",
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = true, 
    ThemeTag = {
        TextColor3 = "Colors.Text.Default",
        PlaceholderColor3 = "Colors.Text.Darker",
        Font = "Font.Normal"
    }
})

-- Icon kính lúp nằm bên phải
E("ImageLabel", "SearchIcon", searchInputBg, {
    Size = UDim2.new(0, 14, 0, 14),
    Position = UDim2.new(1, -8, 0.5, 0), -- Nằm sát lề phải
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundTransparency = 1,
    ThemeTag = {
        Image = "Icons.Search",
        ImageColor3 = "Colors.Icons"
    }
})

u(searchInput:GetPropertyChangedSignal("Text"), function()
    as:PerformSearch(searchInput.Text)
end)

return as   
end

return s
 
-- ===== END EMBEDDED REDZ LIBRARY V5 =====
        end)()
    end)
    if __okEmb and __resEmb ~= nil then
        redzlib = __resEmb
    else
        __DIO_libErr = "[EMBED] " .. tostring(__resEmb)
    end
end
if redzlib == nil then
    -- Fallback: neu ban nhung chay loi thi moi thu tai tu mang
    for _, __DIO_libURL in ipairs({
        "https://raw.githubusercontent.com/DIO482/Script-/refs/heads/main/Library-Redz-Pulic-Source.txt",
        "https://cdn.jsdelivr.net/gh/DIO482/Script-@main/Library-Redz-Pulic-Source.txt",
    }) do
        local __ok, __res = pcall(function()
            return loadstring(game:HttpGet(__DIO_libURL))()
        end)
        if __ok and __res ~= nil then
            redzlib = __res
            break
        end
        __DIO_libErr = tostring(__DIO_libErr or "") .. " | [" .. tostring(__DIO_libURL:match("https?://([^/]+)")) .. "] " .. tostring(__res)
    end
end
if redzlib == nil then
    -- [EMBED-LIB] Library da duoc nhung vao file nen binh thuong KHONG can mang.
    -- Neu van that bai => doc ly do that su ben duoi (dung doan mang/DNS nua).
    local __msg = "Khong tai duoc Library (ban nhung trong file cung loi).\nLy do: " .. tostring(__DIO_libErr)
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
    Travel = Window:MakeTab({ Title = "Teleport Island", Icon = "" }),
    Settings = Window:MakeTab({ Title = "Setting", Icon = "" }),
    Main = Window:MakeTab({ Title = "Farming", Icon = "" }),
    Quests = Window:MakeTab({ Title = "Quest And Item", Icon = "" }),
    SeaEvent = Window:MakeTab({ Title = "Sea Event", Icon = "" }),
    Race = Window:MakeTab({ Title = "Mirage And Race", Icon = "" }),
    Prehistoric = Window:MakeTab({ Title = "Prehistoric Event", Icon = "" }),
    Fish = Window:MakeTab({ Title = "Fishing", Icon = "" }),
    Esp = Window:MakeTab({ Title = "Stats And Esp", Icon = "" }),
    Raids = Window:MakeTab({ Title = "Fruit And Raid", Icon = "" }),
    Hop = Window:MakeTab({ Title = "Remove", Icon = "" }),
    Combat = Window:MakeTab({ Title = "PvP", Icon = "" }),
    Misc = Window:MakeTab({ Title = "Misc", Icon = "" })
}
__DIO_T = setmetatable({
    ["FIX LAG "] = "FIX LAG ",
    ["Select Weapon"] = "Select Weapon",
    ["UI Scale"] = "UI Scale",
    ["Farm"] = "Farm",
    ["Start Farm"] = "Start Farm",
    ["Accept Quest Level/Cake/Bone"] = "Accept Quest Level/Cake/Bone",
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
    ["Auto Dough King [Fully]"] = "Auto Dough King [Fully]",
    ["Auto Farm Dough King + Hop"] = "Auto Farm Dough King + Hop",
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
    ["Fast Attack"] = "Fast Attack",
    ["Auto Use Skill Melee/Sword If lag Mob or Ghost Mob"] = "Auto Use Skill Melee/Sword If lag Mob or Ghost Mob",
    ["Tween speed 600 if near"] = "Tween speed 600 if near",
    ["Bring Mobs"] = "Bring Mobs",
    ["Up Y When Low Health"] = "Up Y When Low Health",
    ["Fast Attack Delay"] = "Fast Attack Delay",
    ["Mode Farm"] = "Mode Farm",
    ["Orbit Speed"] = "Orbit Speed",
    ["Orbit Height"] = "Orbit Height",
    ["mobs Bring"] = "mobs Bring",
    ["Bring Distance"] = "Bring Distance",
    ["Farm Distance"] = "Farm Distance",
    ["Speed Tween"] = "Speed Tween",
    ["Hop Delay (Minutes)"] = "Hop Delay (Minutes)",
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
    ["Dodge Sea Beast / Terror Shark"] = "Dodge Sea Beast / Terror Shark",
    ["Dodge Height (Y)"] = "Dodge Height (Y)",
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
    ["Shot Leviathan Heart [Beta]"] = "Shot Leviathan Heart [Beta]",
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
    ["Select Chip"] = "Select Chip",
    ["Get Fruit In Inventory Below 1M"] = "Get Fruit In Inventory Below 1M",
    ["Auto Buy Chip [Beli]"] = "Auto Buy Chip [Beli]",
    ["Auto Buy Chip [Devil Fruit]"] = "Auto Buy Chip [Devil Fruit]",
    ["Auto Start Raid"] = "Auto Start Raid",
    ["Auto Raid + Next Island"] = "Auto Raid + Next Island",
    ["Auto Awakening"] = "Auto Awakening",
    ["Auto Teleport To Lab"] = "Auto Teleport To Lab",
    ["Buy Microchip Law"] = "Buy Microchip Law",
    ["Start Law Raids"] = "Start Law Raids",
    ["Auto Buy Microchip Law"] = "Auto Buy Microchip Law",
    ["Auto Start Law Raids"] = "Auto Start Law Raids",
    ["Auto Kill Law"] = "Auto Kill Law",
    ["Auto Farm Dungeon"] = "Auto Farm Dungeon",
    ["TP Exit (1)"] = "TP Exit (1)",
    ["TP Exit (2)"] = "TP Exit (2)",
    ["TP Exit (3)"] = "TP Exit (3)",
    ["TP Exit (4)"] = "TP Exit (4)",
    ["Select Players"] = "Select Players",
    ["Teleport To Select Players"] = "Teleport To Select Players",
    ["Spectate Select Players"] = "Spectate Select Players",
    ["Select Aim Method"] = "Select Aim Method",
    ["Aimbot Method Skills"] = "Aimbot Method Skills",
    ["Aimbot Camera Closet Players"] = "Aimbot Camera Closet Players",
    ["Auto Enable PvP"] = "Auto Enable PvP",
    ["Auto Safe Mode"] = "Auto Safe Mode",
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
    ["Rain Fruits (Client)"] = "Rain Fruits (Client)",
    ["Turn on Full Bright"] = "Turn on Full Bright",
    ["Remove Hit VFX"] = "Remove Hit VFX",
    ["Remove Death & Respawned VFX"] = "Remove Death & Respawned VFX",
    ["Disable Notify"] = "Disable Notify",
    ["Select Time"] = "Select Time",
    ["Turn on Time"] = "Turn on Time",
    ["Turn on Walk on Water"] = "Turn on Walk on Water",
    ["Turn on Ice Walk"] = "Turn on Ice Walk",
}, { __index = function(_, k) return k end })
__DIO_BOOT("Load Hub 99%...")
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
                if _G.DIO_AutoRestore == true and Setting and saved ~= nil then
                    Setting.Default = saved
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
                        if Value == true then
                            __DIO_TweenActivateImmediate()
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
                            local __newFlag = false
                            for __k in pairs(__ownedFlags or {}) do __newFlag = true break end
                            local __onNow = __DIO_TweenOnIfAnyFlag()
                            if __onNow then
                                __DIO_FalseSince = nil
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
                            if __ownedFlags then
                                for k in pairs(__ownedFlags) do
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
                                local __stillOn = (type(__DIO_AnyFeatureOn) == "function") and __DIO_AnyFeatureOn() or false
                                if __stillOn or __DIO_FlyBusy == true then
                                    if type(__DIO_TweenSync) == "function" then pcall(__DIO_TweenSync) end
                                    return
                                end
                                __DIO_TweenTarget = nil
                                __DIO_TweenArmedFlags = nil
                                __DIO_LastTweenTarget = nil
                                __DIO_TweenArmedT = 0
                                __DIO_FalseSince = nil
                                __DIO_Parked = false
                                __DIO_DropPendT = 0
                                __DIO_DropPendReason = nil
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
                        __DIO_TweenAllowT = tick()
                        __DIO_TweenBlockT = 0
                        __DIO_FalseSince = nil
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
                                __DIO_FalseSince = nil
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
                if Setting and saved ~= nil then
                    Setting.Default = saved
                end
                local origCb = Setting and Setting.Callback
                local __userTouched = false
                if Setting and origCb then
                    Setting.Callback = function(Value)
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
                        __DIO_TweenAllowT = tick()
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
Tabs.Hop:AddSection("Fps Booster")
__DIO_PerfMode = nil
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
    __DIO_PerfMode = mode
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
Tabs.Hop:AddDropdown({
    Name = __DIO_T["FIX LAG "],
    Description = "Note that these are fixed parameters that may change",
    Options = {"OFF", "Fps 30-60", "Fps 30-40", "Fps 40-60", "Delete All (40-45 Fps) "},
    Default = "OFF",
    Callback = function(Value)
        __DIO_ApplyPerf(Value)
    end
})
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
WeaponDropdown = Tabs.Main:AddDropdown({
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
    for mob in pairs(__DIO_GhostSkip) do
        if not mob.Parent or (mob:FindFirstChild("Humanoid") and mob.Humanoid.Health <= 0) then
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
    return __DIO_GhostSkip[mob] == true
end
local __DIO_LastGhostMob = nil
local function __DIO_FireGhostSkill(mob)
    task.spawn(function()
        pcall(function()
            if not mob or not mob.Parent then return end
            local __gh = mob:FindFirstChild("Humanoid")
            if not __gh or __gh.Health <= 0 then return end
            local __aHRP = mob:FindFirstChild("HumanoidRootPart")
            if __aHRP then
                MousePos = __aHRP.Position + Vector3.new(0, 2, 0)
                _G.DIO_SkillAim = true
                task.spawn(function() __DIO_wait(0.7) _G.DIO_SkillAim = false end)
            end
            __DIO_EquipFarmWeapon()
            local eq = plr.Character and plr.Character:FindFirstChildOfClass("Tool")
            local wt = eq and eq.ToolTip or "Melee"
            if wt == "Sword" then
                Useskills("Sword","Z") __DIO_wait(0.15)
                Useskills("Sword","X")
            elseif wt == "Blox Fruit" then
                Useskills("Blox Fruit","Z") __DIO_wait(0.15)
                Useskills("Blox Fruit","X") __DIO_wait(0.15)
                Useskills("Blox Fruit","C")
            elseif wt == "Gun" then
                Useskills("Gun","Z") __DIO_wait(0.15)
                Useskills("Gun","X")
            else
                Useskills("Melee","Z") __DIO_wait(0.15)
                Useskills("Melee","X") __DIO_wait(0.15)
                Useskills("Melee","C")
            end
        end)
    end)
end
local function __DIO_GhostCheck(mob)
    if not mob or not mob.Parent then return true end
    __DIO_LastGhostMob = mob
    local hum = mob:FindFirstChild("Humanoid")
    if not hum or hum.Health <= 0 then
        __DIO_GhostData[mob] = nil
        return false
    end
    local curHp = hum.Health
    local d = __DIO_GhostData[mob]
    if not d then
        __DIO_GhostData[mob] = { hp = curHp, t = tick(), skill = false }
        return false
    end
    if curHp ~= d.hp then
        d.hp    = curHp
        d.t     = tick()
        d.skill = false
        return false
    end
    local elapsed = tick() - d.t
    if elapsed >= 6 then
        __DIO_GhostSkip[mob] = true
        __DIO_GhostData[mob] = nil
        return true
    end
    if elapsed >= 3 and not d.skill then
        if _G.AutoSkillGhost then
            d.skill = true
            __DIO_FireGhostSkill(mob)
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
    teleporting       = false
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
    __DIO_TweenAllowT = tick()
end
function __DIO_ApplyAcceptQuest()
    local __on   = (_G.AcceptQuest == true)
    local __mode = _G.FarmMode
    _G.AcceptQuestL = __on and __mode == "Farm Level"
    _G.AcceptQuestC = __on and __mode == "Farm Cake"
    _G.AcceptQuestB = __on and __mode == "Farm Bone"
    if not __on then
        StopTween(false)
        __DIO_CurTarget = nil
        if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
    end
end
function __DIO_SyncMasteryIsland()
    SelectIsland = (_G.FarmMode == "Farm Cake") and "Cake" or "Bone"
end
__DIO_SyncMasteryIsland()
Tabs.Main:AddDropdown({
    Name = __DIO_T["Farm"],
    Description = "",
    Options = {"Farm Level", "Farm Bone", "Farm Cake", "Farm Tyrant", "Farm Nearest"},
    Default = "Farm Level",
    Callback = function(Value)
        _G.FarmMode = Value
        __DIO_SyncMasteryIsland()
        if _G.StartFarm then
            __DIO_ApplyFarmMode()
        end
        __DIO_ApplyAcceptQuest()
    end
})
StartFarmToggle = Tabs.Main:AddToggle({
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
    Name = __DIO_T["Accept Quest Level/Cake/Bone"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AcceptQuest = Value
        __DIO_ApplyAcceptQuest()
    end
})
local function IsInSubmergedIsland()
    local char = plr.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local islandXZ = Vector3.new(11520.8017578125, 0, 9829.513671875)
    local playerXZ = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
    return (playerXZ - islandXZ).Magnitude < 2000
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
                local mainGui = plr.PlayerGui:FindFirstChild("Main")
                local qGUI = mainGui and mainGui:FindFirstChild("Quest")
                if not qGUI then return end
                local questTitle = ""
                if qGUI.Visible then
                    local t = qGUI:FindFirstChild("Container")
                    t = t and t:FindFirstChild("QuestTitle")
                    t = t and t:FindFirstChild("Title")
                    questTitle = t and t.Text or ""
                end
                if level >= 2600 and not inSub then
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
                local questData = QuestNeta()
                if not questData or not questData[1] then
                    __DIO_wait(1)
                    return
                end
                if _G.AcceptQuestL and qGUI.Visible and questTitle ~= ""
                   and not string.find(questTitle, questData[1]) then
                    replicated.Remotes.CommF_:InvokeServer("AbandonQuest")
                    __DIO_wait(0.3)
                    return
                end
                if _G.AcceptQuestL and not qGUI.Visible then
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
                        while _G.Level and not qGUI.Visible
                           and (RootF.Position - PosQ.Position).Magnitude > 50
                           and tick() - t0 < 15 do
                            __DIO_wait(0.25)
                            _tp(PosQ)
                        end
                        if (RootF.Position - PosQ.Position).Magnitude > 50 then
                            __qBlock = true
                        end
                    end
                    if not __qBlock then
                        if tick() - __DIO_LvlQTryT > 8 then
                            __DIO_LvlQTryT = tick()
                            pcall(function()
                                replicated.Remotes.CommF_:InvokeServer("StartQuest", questData[3], questData[2])
                            end)
                            __DIO_wait(1)
                        end
                    end
                    if __qBlock then
                        return
                    end
                end
                pcall(__DIO_GhostClean)
                local enemyName = questData[1]
                local target = __DIO_NearestMob(enemyName, RootF.Position)
                if target then
                    local switched = false
                    repeat
                        __DIO_wait(Sec)
                        if not _G.Level then break end
                        local curRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if not curRoot then break end
                        if not target.Parent then break end
                        local th = target:FindFirstChild("Humanoid")
                        local tr = target:FindFirstChild("HumanoidRootPart")
                        if not th or not tr then break end
                        if th.Health <= 0 then break end
                        Attack.Kill(target, _G.Level)
                        if not qGUI.Visible then break end
                        if __DIO_GhostCheck(target) then switched = true break end
                    until not target.Parent
                       or not target:FindFirstChild("Humanoid")
                       or target.Humanoid.Health <= 0
                    if not switched then
                        __DIO_wait(0.8)
                    end
                    return
                end
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
            teleporting = false
            alreadyTeleported = false
        end
    end
end, "L3585")
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.AutoFarmNear then
        for i,v in pairs(workspace.Enemies:GetChildren()) do
          if v:FindFirstChild("Humanoid") or v:FindFirstChild("HumanoidRootPart") then
            if v.Humanoid.Health > 0 then
              repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoFarmNear) until not _G.AutoFarmNear or not v.Parent or v.Humanoid.Health <= 0
            end
          end
        end
      end
    end)
  end
end, "L3773")
FactoryRaids = Tabs.Main:AddToggle({
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
          until v.Humanoid.Health <= 0 or _G.AutoFactory == false
        else
          _tp(CFrame.new(448.46756, 199.356781, -441.389252))
        end
      end
    end)
  end
end, "L3795")
RanBone = Tabs.Main:AddToggle({
Name = __DIO_T["Auto Random Bones"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Random_Bone = Value
end})
CastleRaids = Tabs.Main:AddToggle({
Name = __DIO_T["Auto Pirate Raid"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoRaidCastle = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.AutoRaidCastle then
      pcall(function()
      local CFrameCastleRaid = CFrame.new(-5496.17432, 313.768921, -2841.53027, 0.924894512, 7.37058015e-09, 0.380223751, 3.5881019e-08, 1, -1.06665446e-07, -0.380223751, 1.12297109e-07, 0.924894512)
        if (CFrame.new(-5539.3115234375, 313.800537109375, -2972.372314453125).Position - Root.Position).Magnitude <= 500 then
          for i,v in pairs(workspace.Enemies:GetChildren()) do
            if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
              if v.Name then
                if (v.HumanoidRootPart.Position - Root.Position).Magnitude <= 2000 then
                  repeat __DIO_wait(0.25) Attack.Kill(v,_G.AutoRaidCastle) until not _G.AutoRaidCastle or not v.Parent or v.Humanoid.Health <= 0 or not workspace.Enemies:FindFirstChild(v.Name)
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
Ecto = Tabs.Main:AddToggle({
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
		  repeat __DIO_wait(0.25) Attack.Kill(v, _G.AutoEctoplasm)until not _G.AutoEctoplasm or not v.Parent or v.Humanoid.Health <= 0
	    else
	      replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(923.21252441406, 126.9760055542, 32852.83203125))
	    end
      end
    end)
  end
end, "L3863")
Tabs.Main:AddSection("Chest")
ChestTW = Tabs.Main:AddToggle({
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
ChestBP = Tabs.Main:AddToggle({
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
StopI = Tabs.Main:AddToggle({
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
            __DIO_TweenAllowT = tick()
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
        CFrame = CFrame.new(-16200, 90, -17300),
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
    while __DIO_wait(1) do
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
            and v:FindFirstChild("Humanoid")
            and v:FindFirstChild("HumanoidRootPart")
            and v.Humanoid.Health > 0 then
                found = true
                repeat
                    __DIO_wait(0.25)
                    _tp(v.HumanoidRootPart.CFrame * CFrame.new(0,10,0))
                    Attack.Kill(v, true)
                    if __DIO_GhostCheck(v) then break end
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
			local okDec, data = pcall(Http.JSONDecode, Http, result)
			if not okDec then data = nil end
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
__DIO_SafeLoop(function()
	while __DIO_wait(1) do
		pcall(function()
			if _G.FarmEliteH then
				local questGui = plr.PlayerGui.Main.Quest
				local __qE2 = __DIO_GetCurrentQuest()
				local questTitle = __qE2.QuestText or ""
				if not __qE2.IsActive then
					local result = replicated.Remotes.CommF_:InvokeServer("EliteHunter")
					if result == nil or string.find(result, "Cooldown") then
						HopServer()
						return
					end
					__DIO_wait(1)
				else
					local eliteName = nil
					for _, name in pairs({"Diablo", "Urban", "Deandre"}) do
						if string.find(questTitle, name) then
							eliteName = name
							break
						end
					end
					if eliteName then
						local boss = nil
						for _, v in pairs(replicated:GetChildren()) do
							if v.Name == eliteName and v:FindFirstChild("HumanoidRootPart") then
								boss = v
								break
							end
						end
						for _, v in pairs(workspace.Enemies:GetChildren()) do
							if v.Name == eliteName and Attack.Alive(v) then
								boss = v
								break
							end
						end
						if boss and boss:FindFirstChild("HumanoidRootPart") then
							_tp(boss.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0))
							repeat
								__DIO_wait(0.25)
								Attack.Kill(boss, _G.FarmEliteH)
							until not _G.FarmEliteH or not boss.Parent or boss.Humanoid.Health <= 0 or not questGui.Visible
						else
							__DIO_wait(5)
							HopServer()
						end
					else
						replicated.Remotes.CommF_:InvokeServer("AbandonQuest")
						__DIO_wait(1)
						HopServer()
					end
				end
			end
		end)
	end
end, "L4601")
Tabs.Main:AddSection("Farm Cake")
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
__DIO_CakeQuestT = 0
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.Auto_Cake_Prince then
            pcall(function()
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local enemies = workspace:FindFirstChild("Enemies")
                if not enemies then return end
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
                            __DIO_wait(Sec)
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
                        __DIO_wait(Sec)
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
                    until not _G.Auto_Cake_Prince or not bestMob.Parent
                       or (bestMob:FindFirstChild("Humanoid") and bestMob.Humanoid.Health <= 0)
                    return
                end
                if _G.AcceptQuestC then
                    local __qm = plr.PlayerGui:FindFirstChild("Main")
                    __qm = __qm and __qm:FindFirstChild("Quest")
                    if not (__qm and __qm.Visible) then
                        if (__DIO_CakeQuestCF.Position - hrp.Position).Magnitude > 40 then
                            TeleportConditional(hrp, __DIO_CakeQuestCF, TELEPORT_DISTANCE_THRESHOLD)
                            return
                        end
                        if tick() - __DIO_CakeQuestT > 6 then
                            __DIO_CakeQuestT = tick()
                            local q = {
                                { "StartQuest", "CakeQuest2", 2 },
                                { "StartQuest", "CakeQuest2", 1 },
                                { "StartQuest", "CakeQuest1", 1 },
                                { "StartQuest", "CakeQuest1", 2 }
                            }
                            replicated.Remotes.CommF_:InvokeServer(unpack(q[math.random(1, 4)]))
                            __DIO_wait(1)
                        end
                    end
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
local __dkWasHunting = false
local function __DIO_DKHasItem(itemName)
    local ok, item = pcall(GetBP, itemName)
    return ok and item ~= nil
end
local function __DIO_DKSetChestSearch(enabled)
    if enabled then
        pcall(__DIO_BorrowFlag, "AutoDoughKing", "AutoFarmChest")
    else
        pcall(__DIO_ReleaseFlag, "AutoDoughKing", "AutoFarmChest")
    end
end
local function __DIO_DKHasChalice()
    return __DIO_DKHasItem("God's Chalice") or __DIO_DKHasItem("Sweet Chalice")
end
__DIO_DKMode, __DIO_DKModeT = nil, 0
__DIO_DKSetMode = function(mode, force)
    if mode == __DIO_DKMode and not force then return end
    if not force and __DIO_DKMode ~= nil and (tick() - (__DIO_DKModeT or 0)) < 2 then return end
    __DIO_DKMode  = mode
    __DIO_DKModeT = tick()
    if mode == "elite" then
        pcall(function() __DIO_BorrowFlag("AutoDoughKing", "FarmEliteHunt") end)
        __DIO_DKSetChestSearch(false)
    elseif mode == "chest" then
        pcall(function() __DIO_ReleaseFlag("AutoDoughKing", "FarmEliteHunt") end)
        __DIO_DKSetChestSearch(true)
    else
        pcall(function() __DIO_ReleaseFlag("AutoDoughKing", "FarmEliteHunt") end)
        __DIO_DKSetChestSearch(false)
    end
end
Tabs.Main:AddToggle({
    Name = __DIO_T["Auto Dough King [Fully]"],
    Default = false,
    Callback = function(Value)
        _G.AutoDoughKing = (Value == true)
        if _G.AutoDoughKing then
            __DIO_TweenAllowT = tick()
            __DIO_TweenBlockT = 0
            __DIO_FalseSince = nil
            __dkWasHunting = false
            if not __DIO_DKHasChalice() then
                __DIO_DKSetMode("chest", true)
            end
            pcall(function() __DIO_TweenOnIfAnyFlag() end)
            pcall(function() __DIO_Wake(true) end)
        else
            __dkWasHunting = false
            pcall(function() __DIO_DKSetMode("off", true) end)
            pcall(function() __DIO_ReleaseAll("AutoDoughKing") end)
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoDoughKing then
            pcall(function()
                local __bossDK = GetConnectionEnemies("Dough King")
                if __bossDK then
                    repeat
                        __DIO_wait(0.25)
                        if not _G.AutoDoughKing then break end
                        if not __bossDK.Parent or not __DIO_MobAliveRoot(__bossDK) then break end
                        Attack.Kill(__bossDK, true)
                    until not _G.AutoDoughKing or not __bossDK.Parent or not __DIO_MobAliveRoot(__bossDK)
                    return
                end
                local __mapDK = workspace:FindFirstChild("Map")
                local __cakeLoaf = __mapDK and __mapDK:FindFirstChild("CakeLoaf")
                if not __cakeLoaf then
                    __DIO_TweenDrop()
                    return
                end
                if not __cakeLoaf:FindFirstChild("RedDoor") then
                    if GetBP("Red Key") then
                        replicated.Remotes.CommF_:InvokeServer("CakeScientist", "Check")
                        replicated.Remotes.CommF_:InvokeServer("RaidsNpc", "Check")
                    end
                elseif GetBP("Red Key") then
                    repeat
                        __DIO_wait(0.25)
                        _tp(CFrame.new(-2681.97998, 64.3921585, -12853.7363,0.149007782, -1.87902192e-08, 0.98883605,3.60619588e-08, 1, 1.35681812e-08,-0.98883605, 3.36376011e-08, 0.149007782))
                    until not _G.AutoDoughKing or (plr.Character.HumanoidRootPart.Position - CFrame.new(-2681.97998, 64.3921585, -12853.7363,0.149007782, -1.87902192e-08, 0.98883605,3.60619588e-08, 1, 1.35681812e-08,-0.98883605, 3.36376011e-08, 0.149007782).Position).Magnitude <= 5
                    EquipWeapon("Red Key")
                end
                if GetBP("Sweet Chalice") then
                    replicated.Remotes.CommF_:InvokeServer("CakePrinceSpawner", true)
                    __DIO_ReleaseFlag("AutoDoughKing","FarmEliteHunt")
                    pcall(function() __DIO_ReleaseFlag("AutoDoughKing","AutoFarmChest") end)
                    __dkWasHunting = false
                    return
                end
                pcall(function()
                    if GetBP("God's Chalice") and GetM("Conjured Cocoa") >= 10 then
                        replicated.Remotes.CommF_:InvokeServer("SweetChaliceNpc")
                        __DIO_wait(0.5)
                    end
                end)
                local __eliteSpawnedDK = false
                pcall(function()
                    __eliteSpawnedDK = (__SVC_RS:FindFirstChild("Diablo")
                        or __SVC_RS:FindFirstChild("Deandre")
                        or __SVC_RS:FindFirstChild("Urban")
                        or __SVC_WS.Enemies:FindFirstChild("Diablo")
                        or __SVC_WS.Enemies:FindFirstChild("Deandre")
                        or __SVC_WS.Enemies:FindFirstChild("Urban")) ~= nil
                end)
                local __hasChaliceDK = __DIO_DKHasChalice()
                if not __hasChaliceDK then
                    __DIO_DKSetMode(__eliteSpawnedDK and "elite" or "chest")
                    if __dkWasHunting == false then
                        __dkWasHunting = true
                        __DIO_TweenDrop("dk-no-cakeloaf")
                        pcall(function() __DIO_Wake(true) end)
                    end
                    return
                end
                __dkWasHunting = false
                pcall(function() __DIO_DKSetMode("off") end)
                __DIO_DKSetChestSearch(false)
                if GetM("Conjured Cocoa") <= 10 then
                    local v = GetConnectionEnemies{"Cocoa Warrior", "Chocolate Bar Battler"}
                    if v then
                        repeat
                            __DIO_wait(0.25)
                            if not _G.AutoDoughKing then break end
                            if not v.Parent or not __DIO_MobAliveRoot(v) then break end
                            Attack.Kill(v, true)
                        until _G.AutoDoughKing == false or not v.Parent or not __DIO_MobAliveRoot(v)
                    else
                        _tp(CFrame.new(402.7189025878906, 81.06050109863281, -12259.54296875))
                    end
                else
                    local __waitDK = CFrame.new(-1943.6765, 251.5095, -12337.8809)
                    local __hrpDK = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                    if __hrpDK and (__waitDK.Position - __hrpDK.Position).Magnitude > 20 then
                        _tp(__waitDK)
                    end
                end
            end)
        end
    end
end, "L4855")
Tabs.Main:AddToggle({
    Name = __DIO_T["Auto Farm Dough King + Hop"],
    Default = false,
    Callback = function(Value)
        _G.AutoHop_Dough = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoHop_Dough then
            pcall(function()
                local v = GetConnectionEnemies("Dough King")
                if v then
                    repeat
                        __DIO_wait(0.25)
                        Attack.Kill(v, _G.AutoHop_Dough)
                    until not _G.AutoHop_Dough or not v.Parent or v.Humanoid.Health <= 0
                else
                    _tp(CFrame.new(-1943.6765, 251.5095, -12337.8809))
                    __DIO_wait(2)
                    local checkAgain = GetConnectionEnemies("Dough King")
                    if not checkAgain and _G.AutoHop_Dough then
                        HopServer()
                    end
                end
            end)
        end
    end
end, "L4947")
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
__DIO_BoneQuestT = 0
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoFarm_Bone then
            pcall(function()
                local char = plr.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                if hrp:FindFirstChild("AntiFall") then hrp.AntiFall:Destroy() end
                local mainGui = plr.PlayerGui:FindFirstChild("Main")
                local QuestUI = mainGui and mainGui:FindFirstChild("Quest")
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
                        __DIO_wait(Sec)
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
                    until not _G.AutoFarm_Bone or not mob.Parent
                       or (mob:FindFirstChild("Humanoid") and mob.Humanoid.Health <= 0)
                    return
                end
                if _G.AcceptQuestB and QuestUI and not QuestUI.Visible then
                    local npcD = (__DIO_BoneNpcCF.Position - hrp.Position).Magnitude
                    if npcD <= 10 then
                        if tick() - __DIO_BoneQuestT > 6 then
                            __DIO_BoneQuestT = tick()
                            local quests = {
                                { "StartQuest", "HauntedQuest1", 1 },
                                { "StartQuest", "HauntedQuest1", 2 },
                                { "StartQuest", "HauntedQuest2", 1 },
                                { "StartQuest", "HauntedQuest2", 2 }
                            }
                            __SVC_RS.Remotes.CommF_:InvokeServer(unpack(quests[math.random(1, #quests)]))
                            __DIO_wait(1)
                        end
                        if (__DIO_BoneSpawn.Position - hrp.Position).Magnitude > 10 then
                            _tp(__DIO_BoneSpawn)
                        end
                        return
                    elseif tick() - __DIO_BoneQuestT > 6 then
                        _tp(__DIO_BoneNpcCF)
                        return
                    end
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
__DIO_SafeLoop(function()
    while __DIO_wait(Sec) do
        if _G.FarmTyrant then
            pcall(function()
                if not plr.Character then return end
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local boss = workspace.Enemies:FindFirstChild("Tyrant of the Skies")
                if boss and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health > 0 then
                    repeat
                        if not _G.FarmTyrant then break end
                        if Attack and Attack.Kill then
                            Attack.Kill(boss, _G.FarmTyrant)
                        end
                        __DIO_wait(0.25)
                    until not _G.FarmTyrant or not boss.Parent or boss.Humanoid.Health <= 0
                    return
                end
                local mobList = {"Serpent Hunter","Skull Slayer","Isle Champion","Sun-kissed Warrior"}
                local __farmedMob = false
                for _, mobName in ipairs(mobList) do
                    if not _G.FarmTyrant then return end
                    for _, mob in pairs(workspace.Enemies:GetChildren()) do
                        if not _G.FarmTyrant then return end
                        if mob and mob.Name == mobName and mob:FindFirstChild("HumanoidRootPart") and mob:FindFirstChild("Humanoid") and mob.Humanoid.Health > 0 then
                            __farmedMob = true
                            if (hrp.Position - mob.HumanoidRootPart.Position).Magnitude > 5000 then
                                _tp(mob.HumanoidRootPart.CFrame * CFrame.new(0,30,0))
                                local t0 = tick()
                                repeat __DIO_wait(0.25) hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") until not _G.FarmTyrant or not hrp or (hrp.Position - mob.HumanoidRootPart.Position).Magnitude <= 6 or tick() - t0 > 8
                            end
                            repeat
                                if not _G.FarmTyrant then break end
                                if Attack and Attack.Kill then
                                    Attack.Kill(mob, _G.FarmTyrant)
                                end
                                __DIO_wait(0.25)
                            until not _G.FarmTyrant or not mob.Parent or mob.Humanoid.Health <= 0
                        end
                    end
                end
                if __farmedMob then return end
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
Test = Tabs.Main:AddDropdown({
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
		BossDropdown = Tabs.Main:AddDropdown({
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
BossQ = Tabs.Main:AddToggle({
    Name = __DIO_T["Accept Quests"],
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
FarmAllBoss = Tabs.Main:AddToggle({
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
      pcall(function()
        pcall(__DIO_SyncMasteryIsland)
        if SelectIsland == "Cake" then
          local v = GetConnectionEnemies(mastery1)
		  if v then
		    repeat __DIO_wait()
		      if not v.Parent then break end
		      if not __DIO_MobAliveRoot(v) then break end
		      __DIO_EquipFarmWeapon(v)
		      MousePos = v.HumanoidRootPart.Position
		      Attack.Mas(v,_G.FarmMastery_Dev)
		    until _G.FarmMastery_Dev == false or v.Humanoid.Health <= 0 or not v.Parent
		  else
		    _tp(CFrame.new(-1943.676513671875, 251.5095672607422, -12337.880859375))
		  end
		elseif SelectIsland == "Bone" then
          local v = GetConnectionEnemies(mastery2)
		  if v then
		    repeat __DIO_wait()
		      if not v.Parent then break end
		      if not __DIO_MobAliveRoot(v) then break end
		      __DIO_EquipFarmWeapon(v)
		      MousePos = v.HumanoidRootPart.Position
		      Attack.Mas(v,_G.FarmMastery_Dev)
		    until _G.FarmMastery_Dev == false or v.Humanoid.Health <= 0 or not v.Parent
		  else
		    _tp(CFrame.new(-9495.6806640625, 453.58624267578125, 5977.3486328125))
		  end
        end
      end)
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
      pcall(function()
        pcall(__DIO_SyncMasteryIsland)
        if SelectIsland == "Cake" then
          local v = GetConnectionEnemies(mastery1)
		  if v then
		    repeat __DIO_wait(0.1)
		      if not v.Parent then break end
		      if not __DIO_MobAliveRoot(v) then break end
		      MousePos = v.HumanoidRootPart.Position
		      Attack.Masgun(v,_G.FarmMastery_G)
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
                  vim1:SendMouseButtonEvent(0, 0, 0, true, game, 1);__DIO_wait(0.05)
                  vim1:SendMouseButtonEvent(0, 0, 0, false, game, 1);__DIO_wait(0.05)
                end
              else
                SoulGuitar = false
                local __mods = replicated:FindFirstChild("Modules")
                local __net  = __mods and __mods:FindFirstChild("Net")
                local __shoot = __net and __net:FindFirstChild("RE/ShootGunEvent")
                if __shoot and __hr and _G.FarmMastery_G then
                  pcall(function() __shoot:FireServer(MousePos, { __hr }) end)
                  vim1:SendMouseButtonEvent(0, 0, 0, true, game, 1);__DIO_wait(0.05)
                  vim1:SendMouseButtonEvent(0, 0, 0, false, game, 1);__DIO_wait(0.05)
                end
              end
		    until _G.FarmMastery_G == false or not v.Parent or (v:FindFirstChild("Humanoid") and v.Humanoid.Health <= 0)
		    SoulGuitar = false
		  else
		    _tp(CFrame.new(-1943.676513671875, 251.5095672607422, -12337.880859375))
	  	  end
		elseif SelectIsland == "Bone" then
          local v = GetConnectionEnemies(mastery2)
		  if v then
		    repeat __DIO_wait(0.1)
		      if not v.Parent then break end
		      if not __DIO_MobAliveRoot(v) then break end
		      MousePos = v.HumanoidRootPart.Position
		      Attack.Masgun(v,_G.FarmMastery_G)
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
                  vim1:SendMouseButtonEvent(0, 0, 0, true, game, 1);__DIO_wait(0.05)
                  vim1:SendMouseButtonEvent(0, 0, 0, false, game, 1);__DIO_wait(0.05)
                end
              else
                SoulGuitar = false
                local __mods = replicated:FindFirstChild("Modules")
                local __net  = __mods and __mods:FindFirstChild("Net")
                local __shoot = __net and __net:FindFirstChild("RE/ShootGunEvent")
                if __shoot and __hr and _G.FarmMastery_G then
                  pcall(function() __shoot:FireServer(MousePos, { __hr }) end)
                  vim1:SendMouseButtonEvent(0, 0, 0, true, game, 1);__DIO_wait(0.05)
                  vim1:SendMouseButtonEvent(0, 0, 0, false, game, 1);__DIO_wait(0.05)
                end
              end
		    until _G.FarmMastery_G == false or not v.Parent or (v:FindFirstChild("Humanoid") and v.Humanoid.Health <= 0)
		    SoulGuitar = false
		  else
		    _tp(CFrame.new(-9495.6806640625, 453.58624267578125, 5977.3486328125))
	  	  end
        end
      end)
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
    pcall(function()
      if _G.FarmMastery_S then
        pcall(__DIO_SyncMasteryIsland)
        if SelectIsland == "Cake" then
          for _, v in next, GetInventoryCached() do
            if type(v) == "table" then
              if v.Type == "Sword" then
                local __m = tonumber(v.Mastery) or 0
                if __m < 600 then
                  SwordName = v.Name
                  local vm = GetConnectionEnemies(mastery1)
                  if GetBP(SwordName) then
                    if vm then
                      repeat __DIO_wait(0.25)
                        if not vm.Parent or not __DIO_MobAliveRoot(vm) then break end
                        Attack.Sword(vm,_G.FarmMastery_S)
                      until _G.FarmMastery_S == false or not vm.Parent or (vm:FindFirstChild("Humanoid") and vm.Humanoid.Health <= 0)
                    else
                      _tp(CFrame.new(-1943.676513671875, 251.5095672607422, -12337.880859375))
                    end
                  else
                    replicated.Remotes.CommF_:InvokeServer("LoadItem",SwordName)
                  end
                  break
                end
              end
            end
          end
        elseif SelectIsland == "Bone" then
          for _, v in next, GetInventoryCached() do
            if type(v) == "table" then
              if v.Type == "Sword" then
                local __m = tonumber(v.Mastery) or 0
                if __m < 600 then
                  SwordName = v.Name
                  local vm = GetConnectionEnemies(mastery2)
                  if GetBP(SwordName) then
                    if vm then
                      repeat __DIO_wait(0.25)
                        if not vm.Parent or not __DIO_MobAliveRoot(vm) then break end
                        Attack.Sword(vm,_G.FarmMastery_S)
                      until _G.FarmMastery_S == false or not vm.Parent or (vm:FindFirstChild("Humanoid") and vm.Humanoid.Health <= 0)
                    else
                      _tp(CFrame.new(-9495.6806640625, 453.58624267578125, 5977.3486328125))
                    end
                  else
                    replicated.Remotes.CommF_:InvokeServer("LoadItem",SwordName)
                  end
                  break
                end
              end
            end
          end
        end
      end
    end)
  end
end, "L5655")
Tabs.Settings:AddSection("Settings Farm")
Initialize = Tabs.Settings:AddToggle({
Name = __DIO_T["Fast Attack"],
Description = "",
Default = true,
Callback = function(Value)
  _G.Seriality = Value
end})
SkilluserFarm = Tabs.Settings:AddToggle({
Name = __DIO_T["Auto Use Skill Melee/Sword If lag Mob or Ghost Mob"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoSkillGhost = Value
  if Value then
      pcall(function()
          local mob = __DIO_PickSkillTarget and __DIO_PickSkillTarget()
          if mob then
              local d = __DIO_GhostData and __DIO_GhostData[mob]
              if d then d.skill = true d.t = tick() end
              if __DIO_FireMeleeSwordNow then __DIO_FireMeleeSwordNow(mob) end
          end
      end)
  end
end})
_G.AutoSkillGhost = GetSetting("UI/Settings/Auto Use Skill Melee/Sword If lag Mob or Ghost Mob", false)
__DIO_PickSkillTarget = function()
    local function __ok(m)
        if m == nil then return nil end
        local ok, r = pcall(function()
            if not m.Parent then return nil end
            local h = m:FindFirstChild("Humanoid")
            local hrp = m:FindFirstChild("HumanoidRootPart")
            if h and hrp and h.Health > 0 then return m end
            return nil
        end)
        if ok then return r end
        return nil
    end
    local m = __ok(__DIO_LastGhostMob)
    if m then return m end
    m = __ok(__DIO_CurTarget)
    if m then return m end
    local char = plr.Character
    local hrp0 = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp0 then return nil end
    local en = workspace:FindFirstChild("Enemies")
    if not en then return nil end
    local best, bestD = nil, 150
    for _, e in ipairs(en:GetChildren()) do
        local h = e:FindFirstChild("Humanoid")
        local r = e:FindFirstChild("HumanoidRootPart")
        if h and r and h.Health > 0 then
            local d = (r.Position - hrp0.Position).Magnitude
            if d < bestD then bestD = d best = e end
        end
    end
    return best
end
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
__DIO_SafeLoop(function()
    while __DIO_wait(1.5) do
        if not _G.AutoSkillGhost then continue end
        pcall(function()
            local c = plr.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if hum and hum.Sit then return end
            local mob = __DIO_PickSkillTarget and __DIO_PickSkillTarget()
            if mob then __DIO_FireMeleeSwordNow(mob) end
        end)
    end
end, "L5829")
Neartween = Tabs.Settings:AddToggle({
Name = __DIO_T["Tween speed 600 if near"],
Description = "",
Default = true,
Callback = function(Value)
  _G.Neartween = (Value == true)
end})
_G.Neartween = (GetSetting("UI/Settings/Tween speed 600 if near", true) == true)
_B = true  -- [MOBHOLD] khoi tao mac dinh ON (truong hop UI khong goi callback luc tao toggle)
Bringmob = Tabs.Settings:AddToggle({
Name = __DIO_T["Bring Mobs"],
Description = "",
Default = true,
Callback = function(Value)
  _B = Value
end})
FastAttackModule = FastAttackModule or {}
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
Tabs.Settings:AddSlider({
    Name = __DIO_T["Fast Attack Delay"],
    Min = 1,
    Max = 30,
    Default = 1,
    Increment = 1,
    Callback = function(Value)
        FastAttackModule.Rate = math.clamp(Value, 1, 30) / 100
    end
})
SafeModes = Tabs.Settings:AddToggle({
Name = __DIO_T["Safe Mode"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Safemode = Value
end})
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
    end
})
_G.TweenSpeed = math.clamp(math.floor((tonumber(GetSetting("UI/Settings/Speed Tween", 190)) or 190) + 0.5), 1, 500)
Tabs.Settings:AddSection("Settings / Configure")
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoHopServer then
            pcall(function()
                if not _G.HopTimer then
                    _G.HopTimer = tick()
                end
                if tick() - _G.HopTimer >= _G.HopDelay then
                    _G.HopTimer = tick()
                    if getgenv().AutoExecutor == true and type(__DIO_QueueAutoExec) == "function" then
                        pcall(__DIO_QueueAutoExec)
                    elseif syn and syn.queue_on_teleport then
                        syn.queue_on_teleport(
                            "loadstring(game:HttpGet('https://pastefy.app/6hROay1y/raw'))()"
                        )
                    end
                    __SVC_TP
                        :Teleport(game.PlaceId, game.Players.LocalPlayer)
                end
            end)
        end
    end
end, "L5975")
Tabs.Settings:AddSlider({
    Name = __DIO_T["Hop Delay (Minutes)"],
    Min = 5,
    Max = 120,
    Default = 30,
    Increment = 1,
    Callback = function(Value)
        _G.HopDelay = Value * 60
    end
})
CakeSM = Tabs.Settings:AddToggle({
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
BusuAura = Tabs.Settings:AddToggle({
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
RaceV3Aura = Tabs.Settings:AddToggle({
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
RaceV4Aura = Tabs.Settings:AddToggle({
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
RandomAround = Tabs.Settings:AddToggle({
Name = __DIO_T["Auto Turn on Spin (x,y,z) "],
Description = "",
Default = false,
Callback = function(Value)
  RandomCFrame = Value
end})
SafeModes = Tabs.Settings:AddToggle({
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
    Name = __DIO_T["Auto Anti - Admin Join Server"],
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
                        "drip_mama", "layandikit12", "Hingoi"
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
StatusSelect = Tabs.Esp:AddSlider({
Name = __DIO_T["Stats Value"],
Description = "",
Default = 10,
Min = 0,
Max = 1000,
Rounding = 1,
Callback = function(Value)
  pSats = Value
end})
StatsUpg = Tabs.Esp:AddToggle({
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
StatsUpg = Tabs.Esp:AddToggle({
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
StatsUpg = Tabs.Esp:AddToggle({
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
StatsUpg = Tabs.Esp:AddToggle({
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
StatsUpg = Tabs.Esp:AddToggle({
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
BaitDropdown = Tabs.Fish:AddDropdown({
    Name = __DIO_T["Select Bait"],
    Description = "",
    Options = {"Basic Bait", "Kelp Bait", "Good Bait", "Abyssal Bait", "Frozen Bait", "Epic Bait", "Carnivore Bait"},
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
BuyBaitToggle = Tabs.Fish:AddToggle({
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
FishingToggle = Tabs.Fish:AddToggle({
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
FishingQ = Tabs.Fish:AddToggle({
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
QuestToggle = Tabs.Fish:AddToggle({
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
SellFishToggle = Tabs.Fish:AddToggle({
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
SpamSkillZ = Tabs.Fish:AddToggle({
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
TravelDress = Tabs.Quests:AddToggle({
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
Zou = Tabs.Quests:AddToggle({
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
Lucky = Tabs.Quests:AddToggle({
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
Pray = Tabs.Quests:AddToggle({
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
    _G.FarmEliteHunt = Value
end})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            if _G.FarmEliteHunt then
                local questGui = plr.PlayerGui.Main.Quest
                local __qE1 = __DIO_GetCurrentQuest()
                local questTitle = __qE1.QuestText or ""
                if not __qE1.IsActive then
                    local result = replicated.Remotes.CommF_:InvokeServer("EliteHunter")
                    if result == nil or string.find(result, "Cooldown") then
                        __DIO_wait(10)
                        return
                    end
                    __DIO_wait(1)
                else
                    local eliteName = nil
                    for _, name in pairs({"Diablo", "Urban", "Deandre"}) do
                        if string.find(questTitle, name) then
                            eliteName = name
                            break
                        end
                    end
                    if eliteName then
                        local boss = nil
                        for _, v in pairs(replicated:GetChildren()) do
                            if v.Name == eliteName and v:FindFirstChild("HumanoidRootPart") then
                                boss = v
                                break
                            end
                        end
                        for _, v in pairs(Enemies:GetChildren()) do
                            if v.Name == eliteName and Attack.Alive(v) then
                                boss = v
                                break
                            end
                        end
                        if boss and boss:FindFirstChild("HumanoidRootPart") then
                            _tp(boss.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0))
                            repeat
                                __DIO_wait(0.25)
                                Attack.Kill(boss, _G.FarmEliteHunt)
                            until not _G.FarmEliteHunt or not boss.Parent or boss.Humanoid.Health <= 0 or not questGui.Visible
                        else
                            __DIO_wait(5)
                        end
                    else
                        replicated.Remotes.CommF_:InvokeServer("AbandonQuest")
                    end
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
	_G.FarmEliteH = Value
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
Q = Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Tushita Sword"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Tushita = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Auto_Tushita then
        if workspace.Map.Turtle:FindFirstChild("TushitaGate") then
          if not GetBP("Holy Torch") then
            _tp(CFrame.new(5148.03613, 162.352493, 910.548218))
            __DIO_wait(0.7)
          else
            EquipWeapon("Holy Torch")
            __DIO_wait(1)
            repeat __DIO_wait(0.25) _tp(CFrame.new(-10752, 417, -9366)) until not _G.Auto_Tushita or (CFrame.new(-10752, 417, -9366).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 10
            __DIO_wait(.7)
            repeat __DIO_wait(0.25) _tp(CFrame.new(-11672, 334, -9474)) until not _G.Auto_Tushita or (CFrame.new(-11672, 334, -9474).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 10
            __DIO_wait(.7)
            repeat __DIO_wait(0.25) _tp(CFrame.new(-12132, 521, -10655)) until not _G.Auto_Tushita or (CFrame.new(-12132, 521, -10655).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 10
            __DIO_wait(.7)
            repeat __DIO_wait(0.25) _tp(CFrame.new(-13336, 486, -6985)) until not _G.Auto_Tushita or (CFrame.new(-13336, 486, -6985).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 10
            __DIO_wait(.7)
            repeat __DIO_wait(0.25) _tp(CFrame.new(-13489, 332, -7925)) until not _G.Auto_Tushita or (CFrame.new(-13489, 332, -7925).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 10
          end
        else
          local v = GetConnectionEnemies("Longma")
          if v then repeat __DIO_wait(Sec) Attack.Kill(v,_G.Auto_Tushita) until v.Humanoid.Health <= 0 or not _G.Auto_Tushita or not v.Parent
          else
          if replicated:FindFirstChild("Longma") then _tp(replicated:FindFirstChild("Longma").HumanoidRootPart.CFrame * CFrame.new(0,40,0)) end
          end
        end
      end
    end)
  end
end, "L6981")
Q = Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Yama Sword"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Yama = Value
  if not Value then __DIO_ReleaseAll("Auto_Yama") StopTween(false) end
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Auto_Yama then
	    if replicated.Remotes.CommF_:InvokeServer("EliteHunter", "Progress") < 30 then
	      __DIO_BorrowFlag("Auto_Yama","FarmEliteHunt")
	    elseif replicated.Remotes.CommF_:InvokeServer("EliteHunter", "Progress") > 30 then
	      __DIO_ReleaseFlag("Auto_Yama","FarmEliteHunt")
	      if (workspace.Map.Waterfall.SealedKatana.Handle.Position-plr.Character.HumanoidRootPart.Position).Magnitude >= 20 then
            _tp(workspace.Map.Waterfall.SealedKatana.Handle.CFrame)
            local zx = GetConnectionEnemies("Ghost")
            if zx then
              repeat __DIO_wait(0.25) Attack.Kill(zx,_G.Auto_Yama) until zx.Humanoid.Health <= 0 or not zx.Parent or not _G.Auto_Yama
			  fireclickdetector(workspace.Map.Waterfall.SealedKatana.Handle.ClickDetector)
            end
          end
	    end
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
             Quest1 = true;
             Quest2 = false;
             Quest3 = false;
             Quest4 = false;
             local v = GetConnectionEnemies("Living Zombie")
             if v then repeat __DIO_wait(Sec) Attack.Kill(v,_G.Auto_Soul_Guitar) until not _G.Auto_Soul_Guitar or v.Humanoid.Health <= 0 or not v.Parent or workspace.Map["Haunted Castle"].SwampWater.Color ~= Color3.fromRGB(117, 0, 0)
             else _tp(CFrame.new(-10170.7275390625, 138.6524658203125, 5934.26513671875))
             end
           elseif replicated.Remotes.CommF_:InvokeServer("GuitarPuzzleProgress","Check").Gravestones == false then
             Quest1 = false;
             Quest2 = true;
             Quest3 = false;
             Quest4 = false;
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
             Quest1 = false;
             Quest2 = false;
             Quest3 = true;
             Quest4 = false;
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
            Quest1 = false;
            Quest2 = false;
            Quest3 = false;
            Quest4 = true;
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
              QuestYama_1 = true QuestYama_2 = false QuestYama_3 = false
              repeat __DIO_wait(Sec)
                if not workspace.Enemies:FindFirstChild("Forest Pirate") then
                  _tp(CFrame.new(-13223.521484375, 428.1938171386719, -7766.06787109375))
                else
                  local v = GetConnectionEnemies("Forest Pirate")
                  if v then _tp(workspace.Enemies:FindFirstChild("Forest Pirate").HumanoidRootPart.CFrame)end
                end
              until tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == 1 or not _G.CDK_YM
            elseif tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Evil"]) == -4 then
              QuestYama_1 = false QuestYama_2 = true QuestYama_3 = false
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
              QuestYama_1 = false QuestYama_2 = false QuestYama_3 = true
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
Q = Tabs.Quests:AddToggle({
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
              QuestTushita_1 = true
              QuestTushita_2 = false
              QuestTushita_3 = false
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
                    QuestTushita_1 = false
                    QuestTushita_2 = true
                    QuestTushita_3 = false
                    repeat __DIO_wait(0.25)
                      _G.AutoRaidCastle = true
                    until not _G.CDK_TS or tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == 2
                      _G.AutoRaidCastle = false
                  elseif tonumber(replicated.Remotes.CommF_:InvokeServer("CDKQuest","Progress")["Good"]) == -5 then
                    QuestTushita_1 = false
                    QuestTushita_2 = false
                    QuestTushita_3 = true
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
Q = Tabs.Quests:AddToggle({
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
Tabs.Quests:AddSection("Pole / God Enal's")
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Rengoku Sword"],
Description = "",
Default = false,
Callback = function(Value)
  _G.IceBossRen = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.IceBossRen then
        local v = GetConnectionEnemies("Awakened Ice Admiral")
        if v then repeat __DIO_wait(Sec) Attack.Kill(v,_G.IceBossRen)until _G.IceBossRen == false or not v.Parent or v.Humanoid.Health <= 0
        else __DIO_FlyTo(CFrame.new(5668.9780273438, 28.519989013672, -6483.3520507813), 10)
        end
      end
    end)
  end
end, "L7880")
Q = Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Key Rengoku"],
Description = "",
Default = false,
Callback = function(Value)
  _G.KeysRen = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.KeysRen then
        if plr.Backpack:FindFirstChild(RenMon[3]) or plr.Character:FindFirstChild(RenMon[3]) then
          EquipWeapon(RenMon[3]) __DIO_wait(.1)
          _tp(CFrame.new(6571.1201171875, 299.23028564453, -6967.841796875))
        else
          local v = GetConnectionEnemies(RenMon)
          if v then repeat __DIO_wait(Sec) Attack.Kill(v,_G.KeysRen)until plr.Backpack:FindFirstChild(RenMon[3]) or _G.KeysRen == false or not v.Parent or v.Humanoid.Health <= 0
          else _tp(CFrame.new(5439.716796875, 84.420944213867, -6715.1635742188))
          end
        end
      end
    end)
  end
end, "L7900")
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
		    for _,x in pairs(v) do
		      if _ == "Name" then
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
Name = __DIO_T["Auto Twin Hooks"],
Description = "",
Default = false,
Callback = function(Value)
  _G.TwinHook = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.TwinHook then
        local v = GetConnectionEnemies("Captain Elephant")
	    if v then repeat __DIO_wait(0.25)Attack.Kill(v,_G.TwinHook)until not _G.TwinHook or v.Humanoid.Health <= 0
	    else
          replicated.Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-12471.169921875, 374.94024658203, -7551.677734375)) __DIO_wait(.2)
          _tp(CFrame.new(-13376.7578125, 433.28689575195, -8071.392578125))
	    end
      end
    end)
  end
end, "L8164")
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
BerryH = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
    local __main = plr and plr.PlayerGui and plr.PlayerGui:FindFirstChild("Main")
    local __q = __main and __main:FindFirstChild("Quest")
    if not (__q and __q.Visible) then return { IsActive = false } end
    local __t = __q:FindFirstChild("Container")
    __t = __t and __t:FindFirstChild("QuestTitle")
    __t = __t and __t:FindFirstChild("Title")
    local __text = (__t and __t.Text) or ""
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
Q = Tabs.Quests:AddToggle({
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
      local Qbart = plr.PlayerGui.Main.Quest
        if replicated.Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 0 then
          __DIO_SetFlag("Level","Bartilo_Quest",true,true)
          if Qbart.Visible == true then
            local v = GetConnectionEnemies("Swan Pirate")
            if v then
              local x = GetConnectionEnemies(BartMon)
              if x then
                repeat __DIO_wait(Sec)
                  if not string.find(__DIO_GetCurrentQuest().QuestText or "", "Swan Pirate", 1, true)then replicated.Remotes.CommF_:InvokeServer("AbandonQuest")
                  else Attack.Kill(x,_G.Bartilo_Quest)end
                until _G.Bartilo_Quest == false or not x.Parent or x.Humanoid.Health <= 0 or Qbart.Visible == false or not x:FindFirstChild("HumanoidRootPart")
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
              repeat __DIO_wait(Sec) Attack.Kill(je,_G.Bartilo_Quest) until _G.Bartilo_Quest == false or not je.Parent or je.Humanoid.Health <= 0 or Qbart.Visible == false or not je:FindFirstChild("HumanoidRootPart")
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
CitizenQ = Tabs.Quests:AddToggle({
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
Q = Tabs.Quests:AddToggle({
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
__DIO_BuyKick = function()
    if __DIO_BuyDriverStart then pcall(__DIO_BuyDriverStart) end
end
Tabs.Shop:AddSection("Fighting Melee Styles")
__DIO_BuyMeleeToggles.BuyBlackLeg = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  BlackLeg"],
Description = "",
Default = false,
Callback = function(Value)
  _G.BuyMelee_BuyBlackLeg = (Value == true)
  if Value then
    shouldTween = true
    __DIO_BuyKick()
  else
    StopTween(false)
    __DIO_CurTarget = nil
    if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
  end
end})
__DIO_BuyMeleeToggles.BuyElectro = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  Electro"],
Description = "",
Default = false,
Callback = function(Value)
  _G.BuyMelee_BuyElectro = (Value == true)
  if Value then
    shouldTween = true
    __DIO_BuyKick()
  else
    StopTween(false)
    __DIO_CurTarget = nil
    if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
  end
end})
__DIO_BuyMeleeToggles.BuyFishmanKarate = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  FishmanKarate"],
Description = "",
Default = false,
Callback = function(Value)
  _G.BuyMelee_BuyFishmanKarate = (Value == true)
  if Value then
    shouldTween = true
    __DIO_BuyKick()
  else
    StopTween(false)
    __DIO_CurTarget = nil
    if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
  end
end})
__DIO_BuyMeleeToggles.BuyDragonClaw = Tabs.Shop:AddToggle({
Name = __DIO_T["Buy  DragonClaw"],
Description = "",
Default = false,
Callback = function(Value)
  _G.BuyMelee_BuyDragonClaw = (Value == true)
  if Value then
    shouldTween = true
    __DIO_BuyKick()
  else
    StopTween(false)
    __DIO_CurTarget = nil
    if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
  end
end})
SuperHuman = Tabs.Shop:AddToggle({
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
          if M_Beli >= 150000 and __DIO_FlyTo(__DIO_MeleeCF("BuyBlackLeg"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BuyBlackLeg") end
          return
        elseif GetBP("Black Leg").Level.Value < 300 then __DIO_BorrowFlag("Auto_SuperHuman","Level") return
        else __DIO_ReleaseFlag("Auto_SuperHuman","Level") end
        if not GetBP("Electro") then
          if M_Beli >= 500000 and __DIO_FlyTo(__DIO_MeleeCF("BuyElectro"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BuyElectro") end
          return
        elseif GetBP("Electro").Level.Value < 300 then __DIO_BorrowFlag("Auto_SuperHuman","Level") return
        else __DIO_ReleaseFlag("Auto_SuperHuman","Level") end
        if not GetBP("Fishman Karate") then
          if M_Beli >= 750000 and __DIO_FlyTo(__DIO_MeleeCF("BuyFishmanKarate"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BuyFishmanKarate") end
          return
        elseif GetBP("Fishman Karate").Level.Value < 300 then __DIO_BorrowFlag("Auto_SuperHuman","Level") return
        else __DIO_ReleaseFlag("Auto_SuperHuman","Level") end
        if not GetBP("Dragon Claw") then
          if M_Frag >= 1500 and __DIO_FlyTo(__DIO_MeleeCF("BlackbeardReward"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BlackbeardReward","DragonClaw","2") end
          return
        elseif GetBP("Dragon Claw").Level.Value < 300 then __DIO_BorrowFlag("Auto_SuperHuman","Level") return
        else __DIO_ReleaseFlag("Auto_SuperHuman","Level") end
        if __DIO_FlyTo(__DIO_MeleeCF("BuySuperhuman"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BuySuperhuman") end
      end)
    end
  end
end, "L8787")
DeathStep = Tabs.Shop:AddToggle({
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
          if __DIO_FlyTo(__DIO_MeleeCF("BuyBlackLeg"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BuyBlackLeg") end
          return
        end
        if GetBP("Black Leg").Level.Value >= 400 then
          if GetBP("Library Key") then
            if __DIO_FlyTo(__DIO_MeleeCF("BuyDeathStep"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BuyDeathStep") end
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
SharkManV2 = Tabs.Shop:AddToggle({
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
          if __DIO_FlyTo(__DIO_MeleeCF("BuyFishmanKarate"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BuyFishmanKarate") end
          return
        end
        if GetBP("Fishman Karate").Level.Value < 400 then
          __DIO_BorrowFlag("Auto_SharkMan_Karate","Level")
          return
        end
        __DIO_ReleaseFlag("Auto_SharkMan_Karate","Level")
        if GetBP("Water Key") then
          if __DIO_FlyTo(__DIO_MeleeCF("BuySharkmanKarate"), 15, __on) then
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
ElectricClaw = Tabs.Shop:AddToggle({
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
          if __DIO_FlyTo(__DIO_MeleeCF("BuyElectro"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BuyElectro") end
          return
        end
        if GetBP("Electro").Level.Value >= 400 then
          if replicated.Remotes.CommF_:InvokeServer("BuyElectricClaw", "Start") == nil then __DIO_FlyTo(CFrame.new(-12548, 337, -7481), 10, __on) end
          if __DIO_FlyTo(__DIO_MeleeCF("BuyElectricClaw"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BuyElectricClaw") end
        else
          __DIO_BorrowFlag("Auto_Electric_Claw","AutoFarm_Bone")
          repeat __DIO_wait(0.25) until not _G.Auto_Electric_Claw or GetBP("Electric Claw") or not plr.Character
          __DIO_ReleaseFlag("Auto_Electric_Claw","AutoFarm_Bone")
        end
      end)
    end
  end
end, "L8913")
DragonTalon = Tabs.Shop:AddToggle({
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
          if __DIO_FlyTo(__DIO_MeleeCF("BlackbeardReward"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BlackbeardReward","DragonClaw","2") end
          return
        end
        if GetBP("Dragon Claw").Level.Value >= 400 then
          if __DIO_FlyTo(__DIO_MeleeCF("BuyDragonTalon"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("Bones","Buy",1,1) replicated.Remotes.CommF_:InvokeServer("BuyDragonTalon") end
        else
          __DIO_BorrowFlag("AutoDragonTalon","AutoFarm_Bone")
          repeat __DIO_wait(0.25) until not _G.AutoDragonTalon or GetBP("Dragon Talon") or not plr.Character
          __DIO_ReleaseFlag("AutoDragonTalon","AutoFarm_Bone")
        end
      end)
    end
  end
end, "L8945")
Godhuman = Tabs.Shop:AddToggle({
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
              Lv = 1575
              __DIO_BorrowFlag("Auto_God_Human","Level")
            else
              replicated.Remotes.CommF_:InvokeServer("TravelZou")
            end
          elseif GetM("Fish Tail") == false or GetM("Fish Tail") < 20 then
            if World3 then
              Lv = 1775
              __DIO_BorrowFlag("Auto_God_Human","Level")
            else
              replicated.Remotes.CommF_:InvokeServer("TravelZou")
            end
          elseif GetM("Mystic Droplet") == false or GetM("Mystic Droplet") < 10 then
            if World2 then
              Lv = 1425
              __DIO_BorrowFlag("Auto_God_Human","Level")
            else
              replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
            end
          elseif GetM("Magma Ore") == false or GetM("Magma Ore") < 20 then
            if World2 then
              Lv = 1175
              __DIO_BorrowFlag("Auto_God_Human","Level")
            else
              replicated.Remotes.CommF_:InvokeServer("TravelDressrosa")
            end
          end
        elseif __need == 3 then
          return nil
        else
          if __DIO_FlyTo(__DIO_MeleeCF("BuyGodhuman"), 15, __on) then replicated.Remotes.CommF_:InvokeServer("BuyGodhuman") end
        end
      end
    end)
  end
end, "L8975")
SanguineArt = Tabs.Shop:AddToggle({
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
        else if __DIO_FlyTo(__DIO_MeleeCF("BuySanguineArt"), 15, function() return not _G.Snaguine end) then replicated.Remotes.CommF_:InvokeServer("BuySanguineArt") end
        end
      end)
    end
  end
end, "L9029")
Tabs.Race:AddSection("Mystic Island / Full Moon")
local FullMOOn = Tabs.Race:AddParagraph("FullMoon Status", "")
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
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Find Mirage Island"],
Description = "",
Default = false,
Callback = function(Value)
  _G.FindMirage = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.FindMirage then
      pcall(function()
        local __wo = workspace:FindFirstChild("_WorldOrigin")
        local __loc = __wo and __wo:FindFirstChild("Locations")
        local __found = __loc and __loc:FindFirstChild("Mirage Island", true)
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
            _tp(CFrame.new(__dest.Position.X, __DIO_FindCruiseY(), __dest.Position.Z))
            __found = __loc and __loc:FindFirstChild("Mirage Island", true)
          until not _G.FindMirage or __found or (__dest.Position - __hrpR.Position).Magnitude <= 10 or not __humR.Sit
          pcall(function()
            local __chE = plr.Character
            local __humE = __chE and __chE:FindFirstChildOfClass("Humanoid")
            if __humE then __humE.Sit = false end
          end)
        else
          local __mapM = workspace:FindFirstChild("Map")
          local __mi = __mapM and __mapM:FindFirstChild("MysticIsland")
          if __mi and __mi:FindFirstChild("Center") then
            _tp(__mi.Center.CFrame * CFrame.new(0, 300, 0))
          else
            _tp(__found.CFrame * CFrame.new(0, 300, 0))
          end
        end
      end)
    end
  end
end, "L9119")
Tabs.Race:AddToggle({
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
Tabs.Race:AddToggle({
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
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Tween To Highest Point"],
Description = "",
Default = false,
Callback = function(Value)
  _G.HighestMirage = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.HighestMirage then
      pcall(function()
      if workspace["_WorldOrigin"].Locations:FindFirstChild("Mirage Island",true) then _tp(workspace.Map.MysticIsland.Center.CFrame*CFrame.new(0,400,0))end
      end)
    end
  end
end, "L9262")
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Collect Gear"],
Description = "",
Default = false,
Callback = function(Value)
  _G.TPGEAR = Value
end})
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
Tabs.Race:AddToggle({
Name = __DIO_T["Change Transparency can see"],
Description = "",
Default = false,
Callback = function(Value)
  _G.can = Value
end})
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
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Tween Advanced Fruit Dealer"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Addealer = Value
end})
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
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Collect Mirage Chest"],
Description = "",
Default = false,
Callback = function(Value)
  _G.FarmChestM = Value
end})
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
Tabs.Race:AddButton({
Name = __DIO_T["Talk With Stone"],
Description = "",
Callback = function()
  replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("RaceV4Progress","Begin")
  replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("RaceV4Progress","Check")
  replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("RaceV4Progress","Teleport")
  replicated:WaitForChild("Remotes"):WaitForChild("CommF_"):InvokeServer("RaceV4Progress","Continue")
end})
Tabs.Race:AddToggle({
Name = __DIO_T["Auto Look At Moon"],
Description = "",
Default = false,
Callback = function(Value)
  LookM = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if LookM then
      pcall(MoveCamtoMoon)
      __DIO_wait(.1)
      replicated.Remotes.CommE:FireServer("ActivateAbility")
    end
  end
end, "L9398")
Tabs.Race:AddToggle({
    Name = __DIO_T["Look Moon + Auto V3"],
    Description = "",
    Default = false,
    Callback = function(Value)
        LookMV3 = Value
    end
})
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
RaceMink = Tabs.Race:AddToggle({
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
RaceHuman = Tabs.Race:AddToggle({
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
RaceSky = Tabs.Race:AddToggle({
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
RaceFish = Tabs.Race:AddToggle({
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
PullLv = Tabs.Race:AddToggle({
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
Train = Tabs.Race:AddToggle({
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
Doors = Tabs.Race:AddToggle({
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
Trials = Tabs.Race:AddToggle({
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
AutoKill = Tabs.Race:AddToggle({
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
DojoQ = Tabs.Prehistoric:AddToggle({
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
        if debug == false and not progress and not NameBelt then
          _tp(CFrame.new(5865.0234375, 1208.3154296875, 871.15185546875))
          debug = true
        elseif debug == true and (CFrame.new(5865.0234375, 1208.3154296875, 871.15185546875).Position - plr.Character.HumanoidRootPart.Position).Magnitude <= 50 then
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
          debug = false
          local args = {[1] = {["NPC"] = "Dojo Trainer",["Command"] = "ClaimQuest"}}
          replicated.Modules.Net:FindFirstChild("RF/InteractDragonQuest"):InvokeServer(unpack(args))
        end
      end)
    end
  end
end, "L9893")
BlazeEM = Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Dragon Hunter"],
Description = "",
Default = false,
Callback = function(Value)
  _G.FarmBlazeEM = Value
end})
checkQuesta=function()local a={[1]={["Context"]="Check"}}local b=nil;pcall(function()local c={[1]={["Context"]="RequestQuest"}}__SVC_RS:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/DragonHunter"):InvokeServer(unpack(c))end)local d,e=pcall(function()b=__SVC_RS:WaitForChild("Modules"):WaitForChild("Net"):WaitForChild("RF/DragonHunter"):InvokeServer(unpack(a))end)local f=false;local g;local h;local i;if b then if b.Text then f=true;local j=b.Text;if string.find(tostring(j),"Defeat")then i=1;g=string.sub(tostring(j),8,9)g=tonumber(g)local k={"Hydra Enforcer","Venomous Assailant"}for l,m in pairs(k)do if string.find(j,m)then h=m;break end end elseif string.find(tostring(j),"Destroy")then g=10;i=2;h=nil end end end;return f,h,g,i end
BackTODoJo=function()for a,b in pairs(__SVC_PLR.LocalPlayer.PlayerGui.Notifications:GetChildren())do if b.Name=="NotificationTemplate"then if string.find(b.Text,"Head back to the Dojo to complete more tasks")then return true end end end;return false end
DragonMobClear=function(a,b,c)if workspace.Enemies:FindFirstChild(b)then for d,e in pairs(workspace.Enemies:GetChildren())do if e.Name==b and Attack.Alive(e)then if a then Attack.Kill(e,a)end end end else _tp(c)end end
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.FarmBlazeEM then
      pcall(function()
        local a,v,h,x = checkQuesta()
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
fireflower = Tabs.Prehistoric:AddToggle({
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
dragoTpVolcano = Tabs.Prehistoric:AddToggle({
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
bdrago = Tabs.Prehistoric:AddToggle({
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
UpTalon = Tabs.Prehistoric:AddToggle({
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
Tabs.Prehistoric:AddSection("Volcanic Crafting")
Tabs.Prehistoric:AddButton({
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
Tabs.Prehistoric:AddButton({
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
Tabs.Prehistoric:AddButton({
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
Tabs.Prehistoric:AddButton({
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
Tabs.Prehistoric:AddSection("Prehistoric Island")
Tabs.Prehistoric:AddButton({
    Name = __DIO_T["Craft Volcanic Magnet"],
    Callback = function()
        local RF = __SVC_RS.Modules.Net["RF/Craft"]
        RF:InvokeServer(
            "PossibleHardcode",
            "Volcanic Magnet"
        )
    end
})
Tabs.Prehistoric:AddToggle({
    Name = __DIO_T["Craft Volcanic Magnet"],
    Default = false,
    Callback = function(Value)
        getgenv().AutoCraftVolcanic = Value
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
Tabs.Prehistoric:AddToggle({
    Name = __DIO_T["Auto Find Prehistoric Island"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.Prehis_Find = Value
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
            if _G.Prehis_Find then
                local char = plr.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then return end
                local Locations = workspace["_WorldOrigin"].Locations
                local prehistoricLoc = Locations:FindFirstChild("Prehistoric Island", true)
                if not prehistoricLoc then
                    if __DIO_BoatAssist() ~= "sitting" then return end
                    local seaCFrame = CFrame.new(-10000000, 31, 37016.25)
                    targetDestination = seaCFrame
                    __DIO_NoClipShipNow()
                    _tp(CFrame.new(seaCFrame.Position.X, __DIO_FindCruiseY(), seaCFrame.Position.Z))
                else
                    local stoneHead =
                        prehistoricLoc:FindFirstChild("HeadTeleport", true)
                        or prehistoricLoc:FindFirstChild("Teleport_Head", true)
                        or prehistoricLoc:FindFirstChild("Head", true)
                    if stoneHead then
                        local headCF = stoneHead.CFrame
                        local safePos =
                            headCF.Position
                            - headCF.LookVector * 40
                            + Vector3.new(0, 20, 0)
                        if (safePos - hrp.Position).Magnitude > 30 then
                            _tp(CFrame.new(safePos))
                        end
                    else
                        local islandPos = prehistoricLoc.CFrame.Position
                        local dir = (islandPos - hrp.Position).Unit
                        local safePos = islandPos - dir * 250 + Vector3.new(0, 60, 0)
                        _tp(CFrame.new(safePos))
                    end
                end
            end
        end)
    end
end, "L10385")
Tabs.Prehistoric:AddToggle({
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
Tabs.Prehistoric:AddToggle({
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
Kaura = Tabs.Prehistoric:AddToggle({
    Name = __DIO_T["Kill Aura"],
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
Vocan = Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Collect Dino Bones"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Prehis_DB = Value
end})
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
Vocan = Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Collect Dragon Eggs"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Prehis_DE = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    pcall(function()
      if _G.Prehis_DE then
      if workspace.Map.PrehistoricIsland.Core.SpawnedDragonEggs:FindFirstChild("DragonEgg") then _tp(workspace.Map.PrehistoricIsland.Core.SpawnedDragonEggs:FindFirstChild("DragonEgg").Molten.CFrame) fireproximityprompt(workspace.Map.PrehistoricIsland.Core.SpawnedDragonEggs.DragonEgg.Molten.ProximityPrompt, 30) end
      end
    end)
  end
end, "L10709")
Toggle = Tabs.Prehistoric:AddToggle({
Name = __DIO_T["Auto Reset When Complete Volcano"],
Description = "",
Default = false,
Callback = function(Value)
  _G.ResetPH = Value
end})
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
Q = Tabs.SeaEvent:AddDropdown({
    Name = __DIO_T["Select Weapon Sea Event"],
    Options = __DIO_SeaWpOpts,
    Default = _G.SeaEventWeaponList,
    MultiSelect = true,
    Callback = function(Value)
        _G.SeaEventWeaponList = __DIO_SeaNormList(Value, __DIO_SeaWpOpts, "Melee")
    end
})
Q = Tabs.SeaEvent:AddDropdown({
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
Q = Tabs.SeaEvent:AddDropdown({
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
            end
        end
    end
})
Q = Tabs.SeaEvent:AddDropdown({
Name = __DIO_T["Select Sea Level"],
Options = ListSeaZone,
Default = "Lv 6",
Callback = function(Value)
  _G.DangerSc = Value
end})
Q = Tabs.SeaEvent:AddDropdown({
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
            local __any = getgenv().NoClipShip or getgenv().FindPrehistoric
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
    end
})
_G.BoatTweenSpeed = math.clamp(math.floor((tonumber(GetSetting("UI/SeaEvent/Boat Speed Tween", 165)) or 165) + 0.5), 1, 300)
_G.SelectedBoat = _G.SelectedBoat or GetSetting("UI/SeaEvent/Select Boats", "Guardian") or "Guardian"
_G.DangerSc = _G.DangerSc or GetSetting("UI/SeaEvent/Select Sea Level", "Lv 6") or "Lv 6"
Tabs.SeaEvent:AddSection("Skill And Boat Sea Event")
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
Tabs.SeaEvent:AddToggle({
Name = __DIO_T["Dodge Sea Beast / Terror Shark"],
Description = "",
Default = true,
Callback = function(Value)
  _G.DodgeSeaBeast = Value
  if not Value then __DIO_Dodging = false end
end})
Tabs.SeaEvent:AddSlider({
    Name = __DIO_T["Dodge Height (Y)"],
    Min = 100,
    Max = 400,
    Default = 200,
    Callback = function(Value)
        _G.DodgeHeight = tonumber(Value) or 200
    end
})
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
        _G.TeleportYSlider = Value
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
Q = Tabs.SeaEvent:AddToggle({
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
                    __DIO_LastDist = nil __DIO_LastHRPPos = nil
                    __hrpV7.AssemblyLinearVelocity = Vector3.new(0, -15, 0)
                    return
                end
            end
            local boatSeatCFrame = __seatV4.CFrame * CFrame.new(0, 1, 0)
            _tp(boatSeatCFrame)
          else
            if _G.DangerSc == "Lv 1" then CFrameSelectedZone = CFrame.new(-21998.375, 30.0006084, -682.309143)
            elseif _G.DangerSc == "Lv 2" then CFrameSelectedZone = CFrame.new(-26779.5215, 30.0005474, -822.858032)
            elseif _G.DangerSc == "Lv 3" then CFrameSelectedZone = CFrame.new(-31171.957, 30.0001011, -2256.93774)
            elseif _G.DangerSc == "Lv 4" then CFrameSelectedZone = CFrame.new(-34054.6875, 30.2187767, -2560.12012)
            elseif _G.DangerSc == "Lv 5" then CFrameSelectedZone = CFrame.new(-38887.5547, 30.0004578, -2162.99023)
            elseif _G.DangerSc == "Lv 6" then CFrameSelectedZone = CFrame.new(-44541.7617, 30.0003204, -1244.8584)
            elseif _G.DangerSc == "Lv Infinite" then CFrameSelectedZone = CFrame.new(-10000000, 31, 37016.25)
            end
            CFrameSelectedZone = CFrameSelectedZone or CFrame.new(-44541.7617, 30.0003204, -1244.8584)
            repeat __DIO_wait(0.25)
              local __seaS = __DIO_SeaScan()
              if (not _G.FishBoat and __seaS.fish) or (not _G.PGB and __seaS.pgb) or (not _G.TerrorShark and __seaS.terror) then
                _tp(CFrameSelectedZone * CFrame.new(0,150,0))
              else
                _tp(CFrameSelectedZone)
              end
            until _G.SailBoats==false or ((_G.Shark and __seaS.shark) or (_G.TerrorShark and __seaS.terror) or (_G.MobCrew and __seaS.crew) or (_G.Piranha and __seaS.piranha))or (_G.SeaBeast1 and CheckSeaBeast()) or (_G.FishBoat and __seaS.fish) or (_G.Leviathan1 and CheckLeviathan()) or (_G.HCM and __seaS.crew) or (_G.PGB and __seaS.pgb) or plr.Character:WaitForChild("Humanoid").Sit==false plr.Character.Humanoid.Sit = false
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
__DIO_FlyBoatY = function()
    return math.clamp(math.floor(tonumber(_G.FlyBoatY) or 150), 30, 500)
end
__DIO_SeaAnyHoldT = __DIO_SeaAnyHoldT or 0
__DIO_SeaScanAny = function()
    local __chk = {
        CheckEnemiesBoat, CheckPirateGrandBrigade, CheckTerrorShark, CheckShark,
        CheckFishCrew, CheckPiranha, CheckSeaBeast, CheckHauntedCrew,
    }
    for __i = 1, #__chk do
        local __fn = __chk[__i]
        if type(__fn) == "function" then
            local __okC, __res = pcall(__fn)
            if __okC and __res then
                __DIO_SeaAnyHoldT = tick()
                return true
            end
        end
    end
    return false
end
__DIO_FindCruiseY = function()
    if _G.TeleportYSlider and __DIO_SeaScanAny() then
        return math.clamp(math.floor(tonumber(_G.SeaTeleportY) or 150), 150, 600)
    end
    if _G.TeleportYSlider and (tick() - (__DIO_SeaAnyHoldT or 0)) < 3 then
        return math.clamp(math.floor(tonumber(_G.SeaTeleportY) or 150), 150, 600)
    end
    return __DIO_FlyBoatY()
end
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
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.Shark then local a={"Shark"}if CheckShark()then for b,c in pairs(workspace.Enemies:GetChildren())do if table.find(a,c.Name)then if Attack.Alive(c)then repeat __DIO_wait(Sec) Attack.Kill(c,_G.Shark)until _G.Shark==false or not c.Parent or c.Humanoid.Health<=0 end end end end end
      if _G.TerrorShark then local a={"Terrorshark"}if CheckTerrorShark()then for b,c in pairs(workspace.Enemies:GetChildren())do if table.find(a,c.Name)then if Attack.Alive(c)then repeat __DIO_wait(Sec) Attack.KillSea(c,_G.TerrorShark)until _G.TerrorShark==false or not c.Parent or c.Humanoid.Health<=0 end end end end end
      if _G.Piranha then local a={"Piranha"}if CheckPiranha()then for b,c in pairs(workspace.Enemies:GetChildren())do if table.find(a,c.Name)then if Attack.Alive(c)then repeat __DIO_wait(Sec) Attack.Kill(c,_G.Piranha)until _G.Piranha==false or not c.Parent or c.Humanoid.Health<=0 end end end end end
      if _G.MobCrew then local a={"Fish Crew Member"}if CheckFishCrew()then for b,c in pairs(workspace.Enemies:GetChildren())do if table.find(a,c.Name)then if Attack.Alive(c)then repeat __DIO_wait(Sec) Attack.Kill(c,_G.MobCrew)until _G.MobCrew==false or not c.Parent or c.Humanoid.Health<=0 end end end end end
      if _G.HCM then local a={"Haunted Crew Member"}if CheckHauntedCrew()then for b,c in pairs(workspace.Enemies:GetChildren())do if table.find(a,c.Name)then if Attack.Alive(c)then repeat __DIO_wait(Sec) Attack.Kill(c,_G.HCM)until _G.HCM==false or not c.Parent or c.Humanoid.Health<=0 end end end end end
      if _G.SeaBeast1 then if workspace:FindFirstChild("SeaBeasts") and workspace.SeaBeasts:FindFirstChild("SeaBeast1")then for a,b in pairs(workspace.SeaBeasts:GetChildren())do if b:FindFirstChild("HumanoidRootPart")and b:FindFirstChild("Health")and b.Health.Value>0 then repeat __DIO_wait(0.25)_tp(CFrame.new(b.HumanoidRootPart.Position.X,__DIO_WaterY()+200,b.HumanoidRootPart.Position.Z))if plr:DistanceFromCharacter(b.HumanoidRootPart.CFrame.Position)<=500 then AitSeaSkill_Custom=b.HumanoidRootPart.CFrame;MousePos=AitSeaSkill_Custom.Position;__DIO_SeaSkillAtk() end until _G.SeaBeast1==false or not b:FindFirstChild("HumanoidRootPart")or not b.Parent or b.Health.Value<=0 end end end end
      if _G.Leviathan1 then if workspace:FindFirstChild("SeaBeasts") and workspace.SeaBeasts:FindFirstChild("Leviathan")then for a,b in pairs(workspace.SeaBeasts:GetChildren())do if b:FindFirstChild("HumanoidRootPart")and b:FindFirstChild("Leviathan Segment")and b:FindFirstChild("Health")and b.Health.Value>0 then repeat __DIO_wait(0.25)_tp(CFrame.new(b.HumanoidRootPart.Position.X,__DIO_WaterY()+200,b.HumanoidRootPart.Position.Z))if plr:DistanceFromCharacter(b.HumanoidRootPart.CFrame.Position)<=500 then MousePos=b:FindFirstChild("Leviathan Segment").Position;__DIO_SeaSkillAtk() end until _G.Leviathan1==false or not b:FindFirstChild("HumanoidRootPart")or not b.Parent or b.Health.Value<=0 end end end end
      if _G.FishBoat then
        if CheckEnemiesBoat() then
            for a,b in pairs(workspace.Enemies:GetChildren()) do
                if b:FindFirstChild("Health") and b.Health.Value > 0 and b:FindFirstChild("VehicleSeat") then
                repeat
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
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    if _G.AutofindKitIs then
      pcall(function()
        local __wo = workspace:FindFirstChild("_WorldOrigin")
        local __loc = __wo and __wo:FindFirstChild("Locations")
        local __found = __loc and __loc:FindFirstChild("Kitsune Island", true)
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
            _tp(CFrame.new(__dest.Position.X, __DIO_FindCruiseY(), __dest.Position.Z))
            __found = __loc and __loc:FindFirstChild("Kitsune Island", true)
          until not _G.AutofindKitIs or __found or (__dest.Position - __hrpR.Position).Magnitude <= 10 or not __humR.Sit
          pcall(function()
            local __chE = plr.Character
            local __humE = __chE and __chE:FindFirstChildOfClass("Humanoid")
            if __humE then __humE.Sit = false end
          end)
        else
          _tp(__found.CFrame * CFrame.new(0, 500, 0))
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
                if false then
                    SPYING:SetDesc("Spy Leviathan : Already Done!!")
                end
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
              __DIO_LastTweenTarget = nil
              if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
              continue
            end
            _tp(CFrame.new(__dest.Position.X, __DIO_FindCruiseY(), __dest.Position.Z))
            __found = __loc and __loc:FindFirstChild("Frozen Dimension", true)
          until not _G.FrozenDimension or __found or (__dest.Position - __hrpR.Position).Magnitude <= 10 or not __humR.Sit
          pcall(function()
            local __chE = plr.Character
            local __humE = __chE and __chE:FindFirstChildOfClass("Humanoid")
            if __humE then __humE.Sit = false end
          end)
        else
          local __mapF = workspace:FindFirstChild("Map")
          local __gate = __mapF and __mapF:FindFirstChild("LeviathanGate")
          local __gCenter = __gate and __gate:FindFirstChild("Center")
          if __gCenter then
            _tp(__gCenter.CFrame * CFrame.new(0, 300, 0))
          else
            _tp(__found.CFrame * CFrame.new(0, 300, 0))
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
 Name = __DIO_T["Shot Leviathan Heart [Beta]"],
 Description = "",
 Default = false,
Callback = function(Value)
   _G.ShotHL = Value
end})
local isRunning = false
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.ShotHL and not isRunning then
            isRunning = true
            pcall(function()
                local boat = getBeastHunter()
                local heartModel, heartPart = getLeviathanHeart()
                local character = plr.Character 
                if not boat or not heartPart or not character then return end
                local boatRoot = boat.PrimaryPart
                    or boat:FindFirstChild("VehicleSeat")
                    or boat:FindFirstChildWhichIsA("BasePart")
                local hrp = character:FindFirstChild("HumanoidRootPart")
                local humanoid = character:FindFirstChild("Humanoid")
                if not boatRoot or not hrp or not humanoid then return end
                local lookCFrame = CFrame.lookAt(boatRoot.Position, heartPart.Position)
                boat:PivotTo(lookCFrame)
                __DIO_wait(0.3)
                local harpoonSeat = boat:FindFirstChild("HarpoonSeat", true)
                    or boat:FindFirstChild("Seat", true)
                if not harpoonSeat then return end
                local tween = TweenService:Create(hrp,
                    TweenInfo.new(0.8, Enum.EasingStyle.Linear),
                    {CFrame = harpoonSeat.CFrame}
                )
                tween:Play()
                tween.Completed:Wait()
                harpoonSeat:Sit(humanoid)
                __DIO_wait(0.4)
                for _, obj in pairs(boat:GetDescendants()) do
                    if obj:IsA("RemoteEvent") then
                        print("RemoteEvent:", obj.Name, "|", obj:GetFullName())
                    end
                end
                workspace.CurrentCamera.CFrame = CFrame.lookAt(
                    workspace.CurrentCamera.CFrame.Position,
                    heartPart.Position
                )
                __DIO_wait(0.1)
                local screenPos, onScreen = workspace.CurrentCamera
                    :WorldToScreenPoint(heartPart.Position)
                if onScreen then
                    VirtualInputManager:SendMouseButtonEvent(
                        screenPos.X, screenPos.Y, 0, true, game, 1)
                    __DIO_wait(0.1)
                    VirtualInputManager:SendMouseButtonEvent(
                        screenPos.X, screenPos.Y, 0, false, game, 1)
                else
                    print("Not Have Heart Levi")
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
                local sanitizedFullName = Chest:GetFullName():gsub("[^%w_]", "_")
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
RandomFF = Tabs.Raids:AddToggle({
Name = __DIO_T["Auto Random Fruit"],
Description = "Drop FPS If you keep turning on the function",
Default = false,
Callback = function(Value)
  _G.Random_Auto = (Value == true)
end})
__DIO_GACHA_NAME  = "ZiolesGacha"
__DIO_GachaBusy   = false
__DIO_GachaWarnT  = 0
__DIO_GachaModules = nil
__DIO_GachaGetModules = function()
    if __DIO_GachaModules ~= nil then return __DIO_GachaModules end
    local ok, res = pcall(function()
        local rs = game:GetService("ReplicatedStorage")
        return {
            Client = require(rs.Controllers.GachaClient),
            Window = require(rs.Controllers.UI.GachaWindow),
        }
    end)
    if ok and type(res) == "table" and res.Client and res.Window then
        __DIO_GachaModules = res
    else
        __DIO_GachaModules = false
    end
    return __DIO_GachaModules
end
__DIO_GachaRollOnce = function()
    if __DIO_GachaBusy then return false end
    __DIO_GachaBusy = true
    local __rolled = false
    task.spawn(function()
        pcall(function()
            local mods = __DIO_GachaGetModules()
            if not mods then
                if tick() - (__DIO_GachaWarnT or 0) > 60 then
                    __DIO_GachaWarnT = tick()
                    pcall(function() __DIO_TNotify("Auto Random Fruit", "Khong tim thay module Gacha (Controllers.GachaClient) trong game nay.", 5) end)
                end
                return
            end
            local GachaClient, GachaWindow = mods.Client, mods.Window
            local success, gachaData = pcall(function()
                return GachaClient.CheckGachaAsync(__DIO_GACHA_NAME)
            end)
            if not (success and gachaData and gachaData.Level and gachaData.Level.RequirementMet) then
                if tick() - (__DIO_GachaWarnT or 0) > 60 then
                    __DIO_GachaWarnT = tick()
                    pcall(function() __DIO_TNotify("Auto Random Fruit", "Chua du dieu kien cap do de roll " .. __DIO_GACHA_NAME .. " - tam dung.", 5) end)
                end
                return
            end
            local priceArg = {
                ["Name"]  = "Money",
                ["Value"] = (gachaData.Price and gachaData.Price.Value) or 0,
            }
            local playerGui = plr:FindFirstChild("PlayerGui")
            if not playerGui then return end
            local snapshotBefore = {}
            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    snapshotBefore[gui] = gui.Enabled
                end
            end
            pcall(function()
                GachaWindow:Open(__DIO_GACHA_NAME, priceArg)
            end)
            __DIO_wait(1.2)
            if not _G.Random_Auto then return end
            local targetGuis = {}
            for _, gui in ipairs(playerGui:GetChildren()) do
                if gui:IsA("ScreenGui") then
                    local before = snapshotBefore[gui]
                    if before == nil or (before == false and gui.Enabled) then
                        table.insert(targetGuis, gui)
                    end
                end
            end
            if #targetGuis == 0 then
                for _, method in ipairs({ "Roll", "Spin", "Buy", "Purchase", "Confirm", "Draw", "Pull" }) do
                    if type(GachaWindow[method]) == "function" then
                        local ok = pcall(GachaWindow[method], GachaWindow, __DIO_GACHA_NAME, priceArg)
                        if ok then
                            __rolled = true
                            return
                        end
                    end
                end
                return
            end
            local guiBlacklist = { "chat", "topbar", "leaderboard", "serverlist", "notification", "robux", "coregui" }
            local btnBlacklist = { "close", "exit", "back", "cancel", "robux", "server", "list", "no", "x" }
            local btnKeywords  = { "roll", "spin", "random", "buy", "confirm", "draw", "pull", "play", "start", "purchase" }
            local function listHas(list, str)
                str = string.lower(tostring(str or ""))
                for _, v in ipairs(list) do
                    if #v <= 2 then
                        if str == v then return true end
                    elseif string.find(str, v, 1, true) then
                        return true
                    end
                end
                return false
            end
            local function fireBtn(btn)
                if getconnections then
                    local fired = false
                    for _, conn in ipairs(getconnections(btn.MouseButton1Click)) do conn:Fire() fired = true end
                    for _, conn in ipairs(getconnections(btn.Activated))       do conn:Fire() fired = true end
                    if fired then return true end
                end
                if firesignal then
                    pcall(function()
                        firesignal(btn.MouseButton1Click)
                        firesignal(btn.Activated)
                    end)
                    return true
                end
                pcall(function() btn:Activate() end)
                return false
            end
            local clicked = false
            for _, gui in ipairs(targetGuis) do
                if not listHas(guiBlacklist, gui.Name) then
                    local allBtns = {}
                    for _, btn in ipairs(gui:GetDescendants()) do
                        if (btn:IsA("TextButton") or btn:IsA("ImageButton")) and btn.Visible then
                            local name = btn.Name
                            local text = (btn:IsA("TextButton") and btn.Text) or ""
                            if not listHas(btnBlacklist, name) and not listHas(btnBlacklist, text) then
                                table.insert(allBtns, { btn = btn, name = name, text = text })
                            end
                        end
                    end
                    for _, b in ipairs(allBtns) do
                        if listHas(btnKeywords, b.name) or listHas(btnKeywords, b.text) then
                            if fireBtn(b.btn) then clicked = true break end
                        end
                    end
                    if not clicked and getconnections then
                        local best, bestCount = nil, 0
                        for _, b in ipairs(allBtns) do
                            local n = #getconnections(b.btn.MouseButton1Click)
                            if n > bestCount then bestCount = n best = b end
                        end
                        if best and bestCount > 0 then
                            if fireBtn(best.btn) then clicked = true end
                        end
                    end
                    if not clicked then
                        for _, b in ipairs(allBtns) do
                            if fireBtn(b.btn) then clicked = true break end
                        end
                    end
                end
                if clicked then break end
            end
            __rolled = clicked
        end)
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
DropF = Tabs.Raids:AddToggle({
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
StoredF = Tabs.Raids:AddToggle({
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
TwF = Tabs.Raids:AddToggle({
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
BringF = Tabs.Raids:AddToggle({
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
__RAID_BUY_CF = CFrame.new(-5059.1748, 314.863464, -2923.36108)
function __RaidBuyEnsure()
    local plr = game.Players.LocalPlayer
    local char = plr and plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local cf = __RAID_BUY_CF
    if not World3 then
        local rs = workspace.Map and workspace.Map:FindFirstChild("CircleIsland")
        rs = rs and rs:FindFirstChild("RaidSummon2")
        local bt = rs and rs:FindFirstChild("Button")
        local main = bt and bt:FindFirstChild("Main")
        local pp = main and (main:IsA("BasePart") and main or main:FindFirstChildWhichIsA("BasePart"))
        if pp then cf = pp.CFrame * CFrame.new(0, 2, 0) end
    end
    if (root.Position - cf.Position).Magnitude <= 12 then return end
    _tp(cf)
    local t0 = tick()
    repeat
        __DIO_wait(0.2)
        local c2 = plr.Character
        local r2 = c2 and c2:FindFirstChild("HumanoidRootPart")
        if (r2 and (r2.Position - cf.Position).Magnitude <= 12) or (tick() - t0 > 8) then break end
    until false
    __DIO_wait(0.2)
end
function __ChipFruitBase(sel)
    local b = tostring(sel or ""):match("^[^:]*:%s*(.+)$") or tostring(sel or "")
    return b:gsub("%s+", ""):lower()
end
function __PickFruitForChip(maxPrice)
    local want = __ChipFruitBase(_G.SelectChip)
    local fallback = nil
    local fruits = replicated:WaitForChild("Remotes").CommF_:InvokeServer("GetFruits")
    if type(fruits) ~= "table" then return nil end
    for _, f in next, fruits do
        if type(f) == "table" and f.Name and (not maxPrice or (tonumber(f.Price) or 0) <= maxPrice) then
            if not fallback then fallback = f.Name end
            if want ~= "" and tostring(f.Name):lower():find(want, 1, true) then
                return f.Name
            end
        end
    end
    return fallback
end
Tabs.Raids:AddSection("Dungeon and Raid")
DungeonTables = {"Flame","Ice","Quake","Light","Dark","String","Rumble","Magma","Human: Buddha","Sand","Bird: Phoenix","Dough"}
_G.SelectChip = _G.SelectChip or "Flame"
Q = Tabs.Raids:AddDropdown({
Name = __DIO_T["Select Chip"],
Description = "",
Options = DungeonTables,
Callback = function(Value)
  _G.SelectChip = Value
end})
Tabs.Raids:AddToggle({
    Name = __DIO_T["Get Fruit In Inventory Below 1M"],
    Default = false,
    Callback = function(Value)
        getgenv().AutoGetFruit = Value
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            if getgenv().AutoGetFruit then
                local fruits = {
                    "Rocket-Rocket", "Spin-Spin", "Chop-Chop", "Spring-Spring", "Bomb-Bomb", "Smoke-Smoke",
                    "Spike-Spike", "Flame-Flame", "Falcon-Falcon", "Ice-Ice", "Sand-Sand", "Dark-Dark",
                    "Ghost-Ghost", "Diamond-Diamond", "Light-Light", "Rubber-Rubber", "Barrier-Barrier"
                }
                for _, fruit in ipairs(fruits) do
                    if not getgenv().AutoGetFruit then break end
                    local args = {
                        [1] = "LoadFruit",
                        [2] = fruit
                    }
                    __SVC_RS.Remotes.CommF_:InvokeServer(unpack(args))
                end
            end
        end)
    end
end, "L12479")
AutoChipBeli = Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Buy Chip [Beli]"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoChipBeli = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if _G.AutoChipBeli then
            pcall(function()
                if GetBP("Special Microchip") then return end
                __RaidBuyEnsure()
                replicated.Remotes.CommF_:InvokeServer("RaidsNpc", "Select", _G.SelectChip)
            end)
        end
    end
end, "L12514")
AutoChipFruit = Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Buy Chip [Devil Fruit]"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoChipFruit = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    local lastCand = nil
    local lastTry = 0
    while __DIO_wait(1) do
        if not _G.AutoChipFruit then continue end
        pcall(function()
            if GetBP("Special Microchip") then return end
            __RaidBuyEnsure()
            local cand = __PickFruitForChip(490000)
            if not cand then return end
            if cand ~= lastCand or tick() - lastTry >= 4 then
                lastCand = cand
                lastTry = tick()
                replicated.Remotes.CommF_:InvokeServer("LoadFruit", tostring(cand))
                replicated.Remotes.CommF_:InvokeServer("RaidsNpc", "Select", _G.SelectChip)
            end
        end)
    end
end, "L12540")
StartR = Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Start Raid"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.Auto_StartRaid = Value
        if Value then
            shouldTween = true
        else
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
__DIO_SafeLoop(function()
    local __raidWarnedSea1 = false
    local __raidFireCD = 0
    local __raidChipNotifyT = 0
    while __DIO_wait(0.5) do
        if not _G.Auto_StartRaid then continue end
        pcall(function()
            local plr2 = game.Players.LocalPlayer
            local char = plr2 and plr2.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then return end
            local gui = plr2:FindFirstChild("PlayerGui")
            local main = gui and gui:FindFirstChild("Main")
            local top = main and main:FindFirstChild("TopHUDList")
            local raidTimer = top and top:FindFirstChild("RaidTimer")
            if raidTimer and raidTimer.Visible then return end
            local btn
            if World2 then
                local ci = workspace.Map and workspace.Map:FindFirstChild("CircleIsland")
                local rs = ci and ci:FindFirstChild("RaidSummon2")
                local bt = rs and rs:FindFirstChild("Button")
                btn = bt and bt:FindFirstChild("Main")
            elseif World3 then
                local bc = workspace.Map and workspace.Map:FindFirstChild("Boat Castle")
                local rs = bc and bc:FindFirstChild("RaidSummon2")
                local bt = rs and rs:FindFirstChild("Button")
                btn = bt and bt:FindFirstChild("Main")
            end
            local btnCF
            if btn then
                if btn:IsA("BasePart") then
                    btnCF = btn.CFrame
                elseif btn:IsA("Model") then
                    btnCF = btn:GetPivot()
                else
                    local pp = btn:FindFirstChildWhichIsA("BasePart", true)
                    if pp then btnCF = pp.CFrame end
                end
            end
            if not btnCF then
                if World1 and not __raidWarnedSea1 then
                    __raidWarnedSea1 = true
                    pcall(function() __DIO_TNotify("Auto Start Raid", "Sea 1 khong co Raid - sang Sea 2/3.", 4) end)
                end
                return
            end
            __raidWarnedSea1 = false
            if not GetBP("Special Microchip") then
                local standChip = btnCF * CFrame.new(0, 3, 0)
                if (root.Position - standChip.Position).Magnitude > 12 then
                    _tp(standChip)
                end
                if tick() - __raidChipNotifyT > 15 then
                    __raidChipNotifyT = tick()
                    pcall(function() __DIO_TNotify("Auto Start Raid", "Chua co Special Microchip - bat 'Auto Buy Chip' de mua chip. Da den gan nut Raid, co chip se tu bat.", 4) end)
                end
                return
            end
            local standCF = btnCF * CFrame.new(0, 3, 0)
            if (root.Position - standCF.Position).Magnitude > 12 then
                _tp(standCF)
                return
            end
            if tick() - __raidFireCD < 2 then return end
            __raidFireCD = tick()
            local prompt = btn:FindFirstChild("ProximityPrompt", true)
            local clicker = btn:FindFirstChild("ClickDetector", true)
            if prompt then
                fireproximityprompt(prompt)
            elseif clicker then
                fireclickdetector(clicker)
            end
        end)
    end
end, "L12578")
Raiding = Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Raid + Next Island"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.Raiding = Value
        if not Value then
            _G.KillAuraFull = false
        end
    end
})
__DIO_SafeLoop(function()
    local locations = workspace["_WorldOrigin"].Locations
    local islands = {"Island 1","Island 2","Island 3","Island 4","Island 5"}
    local currentIsland = nil
    while __DIO_wait(1) do
        if not _G.Raiding then
            _G.KillAuraFull = false
            continue
        end
        local gui = plr.PlayerGui.Main.TopHUDList.RaidTimer
        if not gui or not gui.Visible then
            _G.KillAuraFull = false
            continue
        end
        local char = plr.Character
        if not char then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then continue end
        if hum.Sit or hum.PlatformStand or root.Anchored then continue end
        local closestDist = 999999
        for _, name in ipairs(islands) do
            local loc = locations:FindFirstChild(name)
            if loc then
                local dist = (root.Position - loc.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    currentIsland = name
                end
            end
        end
        if not currentIsland then continue end
        if currentIsland == "Island 4" or currentIsland == "Island 5" then
            _G.KillAuraFull = true
        else
            _G.KillAuraFull = false
        end
        local islandPos = locations:FindFirstChild(currentIsland)
        if not islandPos then continue end
        local foundEnemies = false
        for _, mob in ipairs(workspace.Enemies:GetChildren()) do
            local eh = mob:FindFirstChild("Humanoid")
            local ehrp = mob:FindFirstChild("HumanoidRootPart")
            if eh and ehrp and eh.Health > 0 then
                if (ehrp.Position - islandPos.Position).Magnitude < 450 then
                    foundEnemies = true
                    repeat
                        __DIO_wait(0.25)
                        Attack.Kill(mob, _G.Raiding)
                    until not _G.Raiding or not mob.Parent or eh.Health <= 0
                end
            end
        end
        if not foundEnemies then
            if currentIsland == "Island 5" then
                _G.KillAuraFull = false
            end
            local idx = table.find(islands, currentIsland)
            if idx and islands[idx+1] then
                local nxt = locations:FindFirstChild(islands[idx+1])
                if nxt then
                    local safePos = nxt.CFrame * CFrame.new(0, 45, 120)
                    _tp(safePos)
                end
                currentIsland = islands[idx+1]
                __DIO_wait(1)
            end
        end
    end
end, "L12668")
Tabs.Raids:AddToggle({
Name = __DIO_T["Auto Awakening"],
Description = "",
Default = false,
Callback = function(Value)
  _G.Auto_Awakener = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
      if _G.Auto_Awakener then
        replicated.Remotes.CommF_:InvokeServer("Awakener","Check")
        replicated.Remotes.CommF_:InvokeServer("Awakener","Awaken")
      end
    end)
  end
end, "L12760")
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Teleport To Lab"],
    Default = false,
    Callback = function(Value)
        _G.TpLab = Value
        StopTween(_G.TpLab)
        __DIO_SafeLoop(function()
        while _G.TpLab do
            __DIO_wait(0.5)
            if _G.TpLab then
                if World2 and _G.TpLab then
                    topos(CFrame.new(-6438.73535, 250.645355, -4501.50684))
                elseif World3 and _G.TpLab then
                    topos(CFrame.new(-5017.40869, 314.844055, -2823.0127,-0.925743818, 4.48217499e-08, -0.378151238,4.55503146e-09, 1, 1.07377559e-07,0.378151238, 9.7681621e-08, -0.925743818))
                end
            end
        end
        end, "L12777")
    end
})
Tabs.Raids:AddSection("Boss Law")
Tabs.Raids:AddButton({
Name = __DIO_T["Buy Microchip Law"],
Description = "",
Callback = function()
  replicated.Remotes.CommF_:InvokeServer("BlackbeardReward","Microchip","2")
end})
Tabs.Raids:AddButton({
Name = __DIO_T["Start Law Raids"],
Description = "",
Callback = function()
  local __mapR = workspace:FindFirstChild("Map")
  local __ci = __mapR and __mapR:FindFirstChild("CircleIsland")
  local __btn = __ci and __ci:FindFirstChild("RaidSummon")
  __btn = __btn and __btn:FindFirstChild("Button")
  __btn = __btn and __btn:FindFirstChild("Main")
  local __cd = __btn and __btn:FindFirstChild("ClickDetector")
  if __cd then fireclickdetector(__cd) end
end})
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Buy Microchip Law"],
    Description = "",
    Default = false,
    Callback = function(Value)
        getgenv().AutoBuyMicrochipLaw = Value
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if getgenv().AutoBuyMicrochipLaw then
            pcall(function()
                __SVC_RS.Remotes.CommF_:InvokeServer("BlackbeardReward","Microchip","2")
            end)
        end
    end
end, "L12816")
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Start Law Raids"],
    Description = "",
    Default = false,
    Callback = function(Value)
        getgenv().AutoStartLawRaids = Value
    end
})
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if getgenv().AutoStartLawRaids then
            pcall(function()
                fireclickdetector(workspace.Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
            end)
        end
    end
end, "L12835")
Tabs.Raids:AddToggle({
Name = __DIO_T["Auto Kill Law"],
Description = "",
Default = false,
Callback = function(Value)
  _G.AutoLawKak = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(Sec) do
    if _G.AutoLawKak then
      pcall(function()
        local v = GetConnectionEnemies("Order")
        if v then repeat __DIO_wait(Sec) Attack.Kill(v, _G.AutoLawKak) until _G.AutoLawKak == false or not v.Parent or v.Humanoid.Health <= 0
        else _tp(CFrame.new(-6217.2021484375, 28.047645568848, -5053.1357421875))
        end
      end)
    end
  end
end, "L12852")
Tabs.Raids:AddSection("Raids Dungeons")
local plr = game.Players.LocalPlayer
local function GetHRP()
    local char = plr.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end
Tabs.Raids:AddToggle({
    Name = __DIO_T["Auto Farm Dungeon"],
    Description = "",
    Default = false,
    Callback = function(Value)
        _G.AutoFarmDungeon = Value
        if not Value then
            StopTween(false)
            __DIO_CurTarget = nil
            if __DIO_LastTween then pcall(function() __DIO_LastTween:Cancel() end) __DIO_LastTween = nil end
        end
    end
})
local FARM_RANGE = 5000
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if not _G.AutoFarmDungeon then continue end
        pcall(function()
            local plr = game.Players.LocalPlayer
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum or hum.Health <= 0 then return end
            for _, mob in pairs(workspace.Enemies:GetChildren()) do
                if not _G.AutoFarmDungeon then break end
                local mh = mob:FindFirstChild("Humanoid")
                local mhrp = mob:FindFirstChild("HumanoidRootPart")
                if mh and mhrp and mh.Health > 0 then
                    local dist = (mhrp.Position - hrp.Position).Magnitude
                    if dist <= FARM_RANGE then
                        repeat
                            __DIO_wait(0.25)
                            Attack.Kill(mob, true)
                        until not _G.AutoFarmDungeon
                            or not mob.Parent
                            or mh.Health <= 0
                    end
                end
            end
        end)
    end
end, "L12890")
Tabs.Raids:AddToggle({
    Name = __DIO_T["TP Exit (1)"],
    Default = false,
    Callback = function(v)
        _G.TPFloor1 = v
    end
})
local tp1Done = false
local function GetCurrentFloor()
    local hrp = GetHRP()
    if not hrp then return end
    for _, floor in pairs(workspace.Map.Dungeon:GetChildren()) do
        local exit = floor:FindFirstChild("ExitTeleporter")
        if exit and exit:FindFirstChild("Root") then
            if (hrp.Position - exit.Root.Position).Magnitude < 200 then
                return exit.Root
            end
        end
    end
end
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if not _G.TPFloor1 then
            tp1Done = false
            continue
        end
        if not tp1Done then
            local root = GetCurrentFloor()
            if root then
                root = root.CFrame * CFrame.new(0,3,0)
                GetHRP().CFrame = root
                __DIO_TweenSet(GetHRP().CFrame)
                tp1Done = true
            end
        end
    end
end, "L12947")
Tabs.Raids:AddToggle({
    Name = __DIO_T["TP Exit (2)"],
    Default = false,
    Callback = function(v)
        _G.TPFloor2 = v
    end
})
local tp2Done = false
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if not _G.TPFloor2 then
            tp2Done = false
            continue
        end
        if tp2Done then continue end
        local hrp = GetHRP()
        if not hrp then continue end
        for _, floor in pairs(workspace.Map.Dungeon:GetChildren()) do
            local ent = floor:FindFirstChild("EntranceTeleporter")
            local ext = floor:FindFirstChild("ExitTeleporter")
            if ent and ext and ent:FindFirstChild("Root") and ext:FindFirstChild("Root") then
                if (hrp.Position - ent.Root.Position).Magnitude < 100 then
                    hrp.CFrame = ext.Root.CFrame * CFrame.new(0,3,0)
                    __DIO_TweenSet(hrp.CFrame)
                    tp2Done = true
                    break
                end
            end
        end
    end
end, "L12976")
Tabs.Raids:AddToggle({
    Name = __DIO_T["TP Exit (3)"],
    Default = false,
    Callback = function(v)
        _G.TPFloor3 = v
    end
})
local tp3Done = false
local function GetHighestFloor()
    local max
    for _, floor in pairs(workspace.Map.Dungeon:GetChildren()) do
        local n = tonumber(floor.Name)
        if n and (not max or n > tonumber(max.Name)) then
            max = floor
        end
    end
    return max
end
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if not _G.TPFloor3 then
            tp3Done = false
            continue
        end
        if not tp3Done then
            local floor = GetHighestFloor()
            if floor and floor:FindFirstChild("ExitTeleporter")
            and floor.ExitTeleporter:FindFirstChild("Root") then
                GetHRP().CFrame =
                    floor.ExitTeleporter.Root.CFrame * CFrame.new(0,3,0)
                __DIO_TweenSet(GetHRP().CFrame)
                tp3Done = true
            end
        end
    end
end, "L13025")
Tabs.Raids:AddToggle({
    Name = __DIO_T["TP Exit (4)"],
    Default = false,
    Callback = function(v)
        _G.TPFloor4 = v
    end
})
local tp4Done = false
local function GetNearestExit()
    local hrp = GetHRP()
    if not hrp then return end
    local nearest, dist = nil, math.huge
    for _, floor in pairs(workspace.Map.Dungeon:GetChildren()) do
        local exit = floor:FindFirstChild("ExitTeleporter")
        if exit and exit:FindFirstChild("Root") then
            local d = (hrp.Position - exit.Root.Position).Magnitude
            if d < dist then
                dist = d
                nearest = exit.Root
            end
        end
    end
    return nearest
end
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        if not _G.TPFloor4 then
            tp4Done = false
            continue
        end
        if not tp4Done then
            local root = GetNearestExit()
            if root then
                GetHRP().CFrame = root.CFrame * CFrame.new(0,3,0)
                __DIO_TweenSet(GetHRP().CFrame)
                tp4Done = true
            end
        end
    end
end, "L13075")
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
                            Useskill = true
                            _tp(target.HumanoidRootPart.CFrame * CFrame.new(1, 7, 3))
                            target.HumanoidRootPart.Size = Vector3.new(60, 60, 60)
                            __SVC_VU:CaptureController()
                            __SVC_VU:Button1Down(Vector2.new(1280, 672))
                        until _G.AutoPlayerHunter == false or target.Humanoid.Health <= 0
                        Useskill = false
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
Tabs.Combat:AddToggle({
    Name = __DIO_T["Dash No Cooldown"],
    Default = false,
    Callback = function(Value)
        getgenv().DodgeNoCD = Value
    end
})
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
Travelllll = Tabs.Travel:AddDropdown({
Name = __DIO_T["Select Islands"],
Description = "",
Options = Location,
Callback = function(Value)
  _G.Island = Value
end})
GoIsland = Tabs.Travel:AddToggle({
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
NPCsPos = Tabs.Travel:AddDropdown({
Name = __DIO_T["Select NPCs"],
Options = NPCList,
Callback = function(Value)
  NPClist = Value
end})
GoNPCs = Tabs.Travel:AddToggle({
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
__DIO_FlyTo = function(targetCF, arriveDist, cancelFn)
    if not targetCF then return false end
    local __c = plr.Character
    local __h = __c and __c:FindFirstChild("HumanoidRootPart")
    if not __h then return false end
    arriveDist = arriveDist or 15
    local __hum = __c:FindFirstChildOfClass("Humanoid")
    if __hum and __hum.Sit then __hum.Sit = false end
    block.CFrame = __h.CFrame
    local __old = shouldTween
    shouldTween = true
    __DIO_FlyBusy = true
    __DIO_FlyBusyT = tick()
    __DIO_TweenAllowT = tick()
    local __t0 = tick()
    local __spd = math.max(tonumber(_G.TweenSpeed) or 300, 1)
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
__DIO_BuyBusyT = nil
BuyMelee = function(npcNames, cancelFn, ...)
    local key, buyArgs
    if type(cancelFn) == "function" then
        key = (...)
        buyArgs = { ... }
    else
        key = cancelFn
        buyArgs = { cancelFn, ... }
        cancelFn = nil
    end
    local entry = __DIO_BUY_MELEE_CF[key]
    if not entry then
        pcall(function() __DIO_TNotify("Buy Melee", "Khong co toa do teacher cho: " .. tostring(key), 3) end)
        return
    end
    local targetCF = nil
    if sea1 then targetCF = entry.sea1 elseif sea2 then targetCF = entry.sea2 else targetCF = entry.sea3 end
    if not targetCF then
        pcall(function() __DIO_TNotify("Buy Melee", "Khong co toa do cho sea hien tai: " .. tostring(key), 3) end)
        return
    end
    if __DIO_BuyBusy then return end
    __DIO_BuyBusy = true
    __DIO_BuyBusyT = tick()
    task.spawn(function()
        local __released = false
        local function __release()
            if __released then return end
            __released = true
            __DIO_BuyFlying = false
            __DIO_BuyBusy = false
        end
        pcall(function()
            local __c0 = plr.Character
            local __h0 = __c0 and __c0:FindFirstChild("HumanoidRootPart")
            if not __h0 then __release() return end
            local standCF = targetCF * CFrame.new(0, 0, 4)
            local dist0 = (standCF.Position - __h0.Position).Magnitude
            pcall(function() __DIO_TNotify("Buy Melee", "Dang bay den " .. tostring(npcNames[1]) .. " (" .. string.format("%.0f", dist0) .. " studs)", 3) end)
            local __spd = math.max(tonumber(_G.TweenSpeed) or 300, 1)
            local __timeout = math.min(math.max(dist0 / __spd + 25, 15), 300)
            local __t0 = tick()
            local __arrived, __cancelled = false, false
            __DIO_BuyFlying = true
            __DIO_wait(0.15)
            while true do
                local __stop = false
                pcall(function()
                    if cancelFn and cancelFn() then __cancelled = true __stop = true return end
                    local c2 = plr.Character
                    local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                    if not h2 then return end
                    if (h2.Position - standCF.Position).Magnitude <= 15 then __arrived = true __stop = true return end
                    if tick() - __t0 > __timeout then __stop = true return end
                    _tp(standCF)
                end)
                if __stop then break end
                __DIO_wait(0.5)
            end
            __release()
            if __cancelled then
                pcall(function() __DIO_TNotify("Buy Melee", "Da huy (toggle tat) - khong tween/mua nua.", 3) end)
            elseif __arrived then
                local __bok = pcall(function() replicated.Remotes.CommF_:InvokeServer(unpack(buyArgs)) end)
                pcall(function()
                    __DIO_TNotify("Buy Melee", tostring(npcNames[1]) .. ": " .. (__bok and "Da den noi, da goi mua." or "Den noi nhung remote mua lo - kiem tra lai."), 3)
                end)
            else
                pcall(function() __DIO_TNotify("Buy Melee", "Khong den duoc teacher trong 300s - chua mua. Bat lai toggle de thu lai.", 4) end)
            end
        end)
        __release()
    end)
end
__DIO_SafeLoop(function()
    while __DIO_wait(5) do
        if __DIO_BuyBusy and __DIO_BuyBusyT and (tick() - __DIO_BuyBusyT) > 320 then
            __DIO_BuyBusy = false
            __DIO_BuyFlying = false
            __DIO_BuyBusyT = nil
            pcall(function() __DIO_TNotify("Buy Melee", "Phat hien tween bi ket - da tu phu hoi. Bat lai toggle de tiep tuc.", 4) end)
        end
    end
end, "L14031")
__DIO_BuyJobs = {
    { flag = "BuyMelee_BuyBlackLeg",      key = "BuyBlackLeg",      owned = "Black Leg",      npc = {"Dark Step Teacher"},    beli = 150000, args = {"BuyBlackLeg"} },
    { flag = "BuyMelee_BuyElectro",       key = "BuyElectro",       owned = "Electro",        npc = {"Mad Scientist"},        beli = 500000, args = {"BuyElectro"} },
    { flag = "BuyMelee_BuyFishmanKarate", key = "BuyFishmanKarate", owned = "Fishman Karate", npc = {"Water Kung Fu Teacher"},beli = 750000, args = {"BuyFishmanKarate"} },
    { flag = "BuyMelee_BuyDragonClaw",    key = "BuyDragonClaw",    owned = "Dragon Claw",    npc = {"Sabi"},                 frag = 1500,   args = {"BlackbeardReward","DragonClaw","2"} },
}
__DIO_BuyJobT = {}
__DIO_BUY_RETRY = 8
do
    local __warned = {}
    local function __Owned(n)
        local ok, v = pcall(GetBP, n)
        if ok then return v ~= nil end
        return false
    end
    __DIO_BuyAnyOn = function()
        for _, j in ipairs(__DIO_BuyJobs) do
            if _G[j.flag] then return true end
        end
        return false
    end
    __DIO_BuyDriverRunning = false
    __DIO_BuyDriverStart = function()
        if __DIO_BuyDriverRunning then return end
        __DIO_BuyDriverRunning = true
        spawn(function()
            while __DIO_BuyAnyOn() do
                pcall(function()
                    local ch = plr.Character
                    if not ch or not ch:FindFirstChild("HumanoidRootPart") then return end
                    if not plr:FindFirstChild("WeaponAssetCache") and tick() - __DIO_BootT0 < 15 then return end
                    if __DIO_BuyBusy then return end
                    local beli = (plr.Data and plr.Data.Beli and plr.Data.Beli.Value) or 0
                    local frag = (plr.Data and plr.Data.Fragments and plr.Data.Fragments.Value) or 0
                    for _, j in ipairs(__DIO_BuyJobs) do
                        if _G[j.flag] then
                            if __Owned(j.owned) then
                                if not __warned[j.key] then
                                    __warned[j.key] = true
                                    pcall(function() __DIO_TNotify("Buy Melee", "Da co " .. j.owned .. " - khong con phai bay/mua (co the tat toggle).", 4) end)
                                end
                            else
                                __warned[j.key] = nil
                                local enough = (not j.beli or beli >= j.beli) and (not j.frag or frag >= j.frag)
                                if enough then
                                    __warned[j.key .. "_poor"] = nil
                                elseif not __warned[j.key .. "_poor"] then
                                    __warned[j.key .. "_poor"] = true
                                    pcall(function() __DIO_TNotify("Buy Melee", "Thieu " .. (j.beli and ("Beli " .. j.beli) or ("Fragments " .. j.frag)) .. " de mua " .. tostring(j.owned) .. " - khong bay (bay den cung khong mua duoc).", 4) end)
                                end
                                if enough and (not __DIO_BuyJobT[j.key] or (tick() - __DIO_BuyJobT[j.key]) >= __DIO_BUY_RETRY) then
                                    __DIO_BuyJobT[j.key] = tick()
                                    BuyMelee(j.npc, function() return not _G[j.flag] end, unpack(j.args))
                                    break
                                end
                            end
                        end
                    end
                end)
                __DIO_wait(0.5)
            end
            __DIO_BuyDriverRunning = false
        end)
    end
end
__DIO_SafeLoop(function()
    while __DIO_wait(1) do
        pcall(function()
            if __DIO_BuyAnyOn() and not __DIO_BuyDriverRunning and __DIO_BuyDriverStart then
                __DIO_BuyDriverStart()
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
Tabs.SeaEvent:AddSection("Crafting Items")
Tabs.SeaEvent:AddButton({
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
Tabs.SeaEvent:AddButton({
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
Tabs.SeaEvent:AddButton({
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
Tabs.SeaEvent:AddButton({
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
Tabs.SeaEvent:AddButton({
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
Tabs.SeaEvent:AddButton({
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
Tabs.SeaEvent:AddButton({
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
Tabs.SeaEvent:AddButton({
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
  else
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
DisbleChat = Tabs.Misc:AddToggle({
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
DisbleLeaderB = Tabs.Misc:AddToggle({
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
UnPortal = Tabs.Misc:AddToggle({
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
HakiStat = Tabs.Misc:AddDropdown({
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
rtxM = Tabs.Hop:AddToggle({
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
  OldTintColore = e.TintColor
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
Tabs.Hop:AddButton({
Name = __DIO_T["Turn on Fast Mode"],
Description = "",
Callback = function()
  for _,zx in next, workspace:GetDescendants() do
  if table.find(Past, zx.ClassName) then  zx.Material = "Plastic" end
  end
end})
Tabs.Hop:AddButton({
Name = __DIO_T["Turn on Low CPU"],
Description = "",
Callback = function()
  LowCpu()
end})
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
Tabs.Hop:AddButton({
Name = __DIO_T["No Fog"],
Description = "",
Callback = function()
  if Lighting:FindFirstChild("LightingLayers") then Lighting.LightingLayers:Destroy() end
  if Lighting:FindFirstChild("SeaTerrorCC") then Lighting.SeaTerrorCC:Destroy() end
  if Lighting:FindFirstChild("FantasySky") then Lighting.FantasySky:Destroy() end
end})
Tabs.Misc:AddSection("Rain - God")
Tabs.Misc:AddButton({
Name = __DIO_T["Rain Fruits (Client)"],
Description = "",
Callback = function()
  pcall(function() 
    local __chRF = plr.Character
    local __ppRF = (__chRF and __chRF:FindFirstChild("PrimaryPart")) or (__chRF and __chRF:FindFirstChild("HumanoidRootPart"))
    if not __ppRF then return end
    local __objsRF = nil
    pcall(function() __objsRF = game:GetObjects("rbxassetid://14759368201") end)
    local __model = __objsRF and __objsRF[1]
    if not __model then return end
    for _, v in pairs(__model:GetChildren()) do
      pcall(function()
        v.Parent = game.Workspace.Map
        v:MoveTo(__ppRF.Position + Vector3.new(math.random(-50, 50), 100, math.random(-50, 50)))
        local __fruit = v:FindFirstChild("Fruit")
        local __acc = __fruit and __fruit:FindFirstChild("AnimationController")
        if __acc then
          local __idle = __fruit:FindFirstChild("Idle")
          if __idle then __acc:LoadAnimation(__idle):Play() end
        end
        local __handle = v:FindFirstChild("Handle")
        if __handle then
          __handle.Touched:Connect(function(otherPart)
            if otherPart.Parent == plr.Character then
              v.Parent = plr.Backpack
              local __humRF = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
              if __humRF then __humRF:EquipTool(v) end
            end
          end)
        end
      end)
    end
  end)
end})
briggt1 = Tabs.Hop:AddToggle({
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
DisableHitVFX = Tabs.Hop:AddToggle({
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
RmvVFX = Tabs.Hop:AddToggle({
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
DisblesNotify = Tabs.Hop:AddToggle({
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
DayN = Tabs.Misc:AddDropdown({
Name = __DIO_T["Select Time"],
Description = "",
Options = {"Day", "Night"},
Default = "Day",
Callback = function(Value)
  _G.SelectDN = Value
end})
dayornight = Tabs.Misc:AddToggle({
Name = __DIO_T["Turn on Time"],
Description = "",
Default = false,
Callback = function(Value)
  _G.daylightN = Value
end})
__DIO_SafeLoop(function()
  while __DIO_wait(1) do
    pcall(function()
    if _G.daylightN then
      if _G.SelectDN == "Day" then
        Lighting.ClockTime = 12
      elseif _G.SelectDN == "Night" then
        Lighting.ClockTime = 0
      end
    end
    end)
  end
end, "L14912")
walkWater = Tabs.Misc:AddToggle({
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
iceWalk = Tabs.Misc:AddToggle({
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
__DIO_VolleyGate = function(gap)
    local n = tick()
    if n - (__DIO_LastVolley or 0) < gap then return false end
    __DIO_LastVolley = n
    return true
end
pcall(function()
    local u = game:GetService("ReplicatedStorage"):FindFirstChild("Util")
    u = u and u:FindFirstChild("CameraShaker")
    if u then
        CameraShakerR = require(u)
        if CameraShakerR and CameraShakerR.Stop then CameraShakerR:Stop() end
    end
end)
get_Monster = function() 
    local __chGM = plr and plr.Character
    local __hrpGM = __chGM and __chGM:FindFirstChild("HumanoidRootPart")
    if not __hrpGM then return end
    local __enemiesFolder = workspace:FindFirstChild("Enemies")
    if __enemiesFolder then
        for _, b in pairs(__enemiesFolder:GetChildren()) do
            local c = b:FindFirstChild("UpperTorso") or b:FindFirstChild("Head")
            if b:FindFirstChild("HumanoidRootPart", true) and c then
                if (c.Position - __hrpGM.Position).Magnitude <= 50 then return true, c.Position end
            end
        end
    end
    local __seaBeasts = workspace:FindFirstChild("SeaBeasts")
    if __seaBeasts then
        for _, d in pairs(__seaBeasts:GetChildren()) do
            if d:FindFirstChild("HumanoidRootPart") and d:FindFirstChild("Health") and d.Health.Value > 0 then
                return true, d.HumanoidRootPart.Position
            end
        end
    end
    if __enemiesFolder then
        for _, d in pairs(__enemiesFolder:GetChildren()) do
            if d:FindFirstChild("Health") and d.Health.Value > 0 and d:FindFirstChild("VehicleSeat") and d:FindFirstChild("Engine") then
                return true, d.Engine.Position
            end
        end
    end
end
Actived=function()local a=game.Players.LocalPlayer.Character:FindFirstChildOfClass("Tool")if not a then return end
if a.Name == (__DIO_LastActivedTool or "") then return end
__DIO_LastActivedTool = a.Name
if getconnections then pcall(function() for b,c in next,getconnections(a.Activated) do if typeof(c.Function) == "function" then getupvalues(c.Function) end end end) end 
end 
task.spawn(function()
  RunSer.Heartbeat:Connect(function()
    pcall(function()
      if not _G.Seriality then return end
      if tick() - (_G.__DIONoCdLast or 0) < 0.25 then return end
      _G.__DIONoCdLast = tick()
      local Pretool = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Tool")
      local ToolTip = Pretool and Pretool.ToolTip
      if tick() - (__DIO_LastGM or 0) >= 0.3 then
        __DIO_LastGM = tick()
        __DIO_GMa, __DIO_GMb = get_Monster()
      end
      local MobAura, Mon = __DIO_GMa, __DIO_GMb
      if ToolTip == "Blox Fruit" then
        if MobAura then
          local LeftClickRemote = Pretool:FindFirstChild('LeftClickRemote');
          if LeftClickRemote then Actived() LeftClickRemote:FireServer(Vector3.new(0.01,-500,0.01),1,true);LeftClickRemote:FireServer(false)end
        end
      end
    end)
  end)
end)
FastAttackModule = FastAttackModule or {}
__DIO_BOOT("Fast Attack Module Last")
FastAttackModule.Rate = FastAttackModule.Rate or 0.03
FastAttackModule.Enabled = true
local __FA_attackEvent, __FA_hitEvent
__FA_GetTargets = function(playerPos)
    local targets = {}
    local __cFA = plr.Character
    local __hFA = __cFA and __cFA:FindFirstChildOfClass("Humanoid")
    if not __cFA or not __hFA or __hFA.Sit or __hFA.Health <= 0 then
        return targets
    end
    local enemies = workspace.Enemies:GetChildren()
    for i = 1, #enemies do
        local enemy = enemies[i]
        local hum = enemy:FindFirstChild("Humanoid")
        local hrp = enemy:FindFirstChild("HumanoidRootPart")
        if hum and hrp and hum.Health > 0 then
            if (hrp.Position - playerPos).Magnitude <= 75 then
                table.insert(targets, {enemy, hrp})
                if #targets >= 6 then break end
            end
        end
    end
    if #targets < 6 then
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p ~= plr and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChild("Humanoid") then
                local hum = p.Character.Humanoid
                local hrp = p.Character.HumanoidRootPart
                if hum.Health > 0 then
                    local canAttack = true
                    if _G.NoAimTeam and p.Team == plr.Team then canAttack = false end
                    if canAttack and (hrp.Position - playerPos).Magnitude <= 75 then
                        table.insert(targets, {p.Character, hrp})
                        if #targets >= 6 then break end
                    end
                end
            end
        end
    end
    if #targets < 6 and workspace:FindFirstChild("Characters") then
        for _, m in ipairs(workspace.Characters:GetChildren()) do
            if m ~= plr.Character then
                local hum = m:FindFirstChild("Humanoid")
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    if (hrp.Position - playerPos).Magnitude <= 75 then
                        local owner = game.Players:GetPlayerFromCharacter(m)
                        local canAttack = true
                        if owner and _G.NoAimTeam and owner.Team == plr.Team then canAttack = false end
                        if canAttack then
                            table.insert(targets, {m, hrp})
                            if #targets >= 6 then break end
                        end
                    end
                end
            end
        end
    end
    return targets
end
function FastAttackModule.ExecuteFastAttack()
    local character = plr.Character
    if not character then return end
    local __humFA = character:FindFirstChildOfClass("Humanoid")
    if __humFA and (__humFA.Sit or __humFA.Health <= 0) then return end
    if not __DIO_VolleyGate(math.max(FastAttackModule.Rate or 0.1, 0.01)) then return end
    local tool = character:FindFirstChildOfClass("Tool")
    if not tool then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not __FA_attackEvent then
        local modules = replicated:FindFirstChild("Modules")
        if not modules then return end
        local net = modules:FindFirstChild("Net")
        if not net then return end
        __FA_attackEvent = net:FindFirstChild("RE/RegisterAttack")
        __FA_hitEvent = net:FindFirstChild("RE/RegisterHit")
        if not __FA_attackEvent or not __FA_hitEvent then __FA_attackEvent, __FA_hitEvent = nil, nil return end
    end
    local targets = __FA_GetTargets(hrp.Position)
    if #targets == 0 then return end
    __FA_attackEvent:FireServer(0)
    __FA_hitEvent:FireServer(targets[1][2], targets)
end
task.spawn(function()
    while true do
        if FastAttackModule.Enabled and _G.Seriality then
            pcall(function() FastAttackModule.ExecuteFastAttack() end)
            __DIO_wait(math.max(FastAttackModule.Rate or 0.1, 0.01))
        else
            __DIO_wait(0.25)
        end
    end
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
getLeviathanHeart = function()
    for _, obj in pairs(workspace:GetDescendants()) do 
        if obj:IsA("Model") and string.find(obj.Name, "Leviathan Heart") then
            local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if root then
                return obj, root
            end
        end
    end
    return nil, nil
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
pcall(__DIO_QueueAutoExec)
if getgenv().HideUi == true then
    pcall(function() Window:Minimize() end)
end
__DIO_BOOT("DIO HUB READY NOW")
end
__DIO_QueueAutoExec = function()
    if getgenv().AutoExecutor ~= true then return end
    local __url = getgenv().DIO_SelfUrl
        or "https://raw.githubusercontent.com/DIO482/Script-/refs/heads/main/DIO_Hub_Fixed%20(1)(6)%20FIXED.txt"
    local __esc = function(v)
        return tostring(v or ""):gsub("\\", "\\\\"):gsub('"', '\\"')
    end
    local __code = 'getgenv().Team="' .. __esc(getgenv().Team or "Pirates") .. '"'
        .. '\ngetgenv().SaveSettings=' .. tostring(getgenv().SaveSettings ~= false)
        .. '\ngetgenv().Key="' .. __esc(getgenv().Key) .. '"'
        .. '\ngetgenv().AutoExecutor=true'
        .. '\ngetgenv().HideUi=' .. tostring(getgenv().HideUi == true)
        .. '\nloadstring(game:HttpGet("' .. __url .. '"))()'
    pcall(function()
        if type(queue_on_teleport) == "function" then
            queue_on_teleport(__code)
        elseif syn and syn.queue_on_teleport then
            syn.queue_on_teleport(__code)
        else
            warn("[DIO] AutoExecutor ON nhung executor khong co queue_on_teleport -> khong tu chay lai khi hop")
        end
    end)
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
    local okFluent, errFluent = pcall(function()
        Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
    end)
    if not okFluent or not Fluent then
        warn("[DIO] Failed to load Fluent UI, loading hub anyway for debug")
        __DIO_SafeStart("fluent-fallback")
        return
    end
    local Window = Fluent:CreateWindow({
        Title = "DIO Hub Get Key",
        SubTitle = "By DIO",
        TabWidth = 155,
        Size = UDim2.fromOffset(470, 380),
        Acrylic = false,
        Theme = "Dark",
        MinimizeKey = Enum.KeyCode.RightControl
    })
    local Tabs = {
        Info = Window:AddTab({ Title = "Discord", Icon = "message-circle" }),
        GetKey = Window:AddTab({ Title = "Get Key", Icon = "key" }),
    }
    Tabs.Info:AddParagraph({
        Title = "Join the Community",
        Content = "Join our Discord server for updates, support, and new scripts! Key is valid for 10 hours per device."
    })
    Tabs.Info:AddButton({
        Title = "Copy Discord Link",
        Description = "Copies the invite link to your clipboard.",
        Callback = function()
            pcall(function() setclipboard("https://discord.gg/NZm9MXzmzn") end) 
            Fluent:Notify({
                Title = "Copied!",
                Content = "Discord link has been copied to your clipboard.",
                Duration = 5
            })
        end
    })
    Tabs.GetKey:AddParagraph({
        Title = "Key System",
        Content = "Click the button below to get your key, then paste it into the text box.\n"
            .. "Link lay key: " .. tostring(_DIO_ResolveLinkgetkey(false)) .. "\n"
            .. "Key cua ban: " .. _DIO_KeyLabel() .. "\n"
            .. "Cache lasts 10 hours.\n\n"
            .. "----- CHAN DOAN KEY -----\n" .. _DIO_KeyStatusText()
    })
    Tabs.GetKey:AddButton({
        Title = "Get Key Link",
        Description = "Copies key link to clipboard.",
        Callback = function()
            local __link = _DIO_ResolveLinkgetkey(true)
            if type(__link) ~= "string" or #__link <= 12 then
                __link = "https://link4sub.com/notes/eRcc"
            end
            pcall(function() setclipboard(__link) end) 
            Fluent:Notify({
                Title = "Copied!",
                Content = "Key link copied to clipboard!",
                Duration = 5
            })
        end
    })
    local KeyInput = Tabs.GetKey:AddInput("KeyInput", {
        Title = "Enter Key",
        Default = "",
        Placeholder = "Paste your key here...",
        Numeric = false,
        Finished = false,
        Callback = function(Value) end
    })
    Tabs.GetKey:AddButton({
        Title = "Check Key",
        Description = "Verifies your key.",
        Callback = function()
            local enteredKey = KeyInput.Value
            if _SEC_VerifyKey(enteredKey) then
                Fluent:Notify({
                    Title = "Success",
                    Content = "Valid Key! Loading Hub... (saved 10h)",
                    Duration = 3
                })
                _DIO_SetKey(enteredKey)
                saveKeyCache()
                task.wait(0.5)
                Window:Destroy()
                task.wait(0.2)
                __DIO_SafeStart("check-key-button")
            else
                warn("[DIO KEY] Key nhap tay khong khop. Bam 'Get Key Link' de lay key moi (key cu co the da doi/het han).")
                Fluent:Notify({
                    Title = "Error",
                    Content = "Invalid Key! " .. (_DIO_ApiOnline
                        and ("Key tren Api: " .. table.concat(_DIO_ApiKeys, ", "))
                        or "Khong doc duoc Api (bam Test Api / xem console F9)"),
                    Duration = 3
                })
            end
        end
    })
    Tabs.GetKey:AddButton({
        Title = "Use getgenv().Key",
        Description = "Check key from getgenv().Key config",
        Callback = function()
            if _SEC_VerifyKey(tostring(getgenv().Key)) then
                Fluent:Notify({Title="Success", Content="getgenv().Key valid! Loading...", Duration=3})
                saveKeyCache()
                task.wait(0.5)
                Window:Destroy()
                task.wait(0.2)
                __DIO_SafeStart("getgenv-key-button")
            else
                Fluent:Notify({Title="Error", Content="getgenv().Key invalid or empty. Enter key manually.", Duration=3})
            end
        end
    })

    -- [KEY-FIX] 2 nut tien ich: xoa cache key + test Api (in log ra console F9)
    Tabs.GetKey:AddButton({
        Title = "Xoa cache Key (Reset)",
        Description = "Xoa KeyCache.json + getgenv().Key de nhap lai key moi",
        Callback = function()
            _DIO_ResetKeyCache()
            Fluent:Notify({
                Title = "Da xoa cache key",
                Content = "Nhap key moi roi bam Check Key.",
                Duration = 5
            })
        end
    })
    Tabs.GetKey:AddButton({
        Title = "Test Api (xem log F9)",
        Description = "In ra console: Api tra ve gi, cache dang luu gi",
        Callback = function()
            local data = _DIO_ResolvePendingFromPastefy()
            print("[DIO KEY][TEST] Online=" .. tostring(_DIO_ApiOnline)
                .. " | Keys=" .. table.concat(_DIO_ApiKeys, " | ")
                .. " | Pending=" .. tostring(_DIO_PendingKey))
            print("[DIO KEY][TEST] Raw=" .. tostring(_DIO_ApiRaw):sub(1, 300))
            print("[DIO KEY][TEST] " .. _DIO_KeyStatusText():gsub("\n", " | "))
            Fluent:Notify({
                Title = "Test Api xong",
                Content = _DIO_ApiOnline and "Api doc duoc - xem console (F9)" or "KHONG doc duoc Api - xem console (F9)",
                Duration = 6
            })
        end
    })
    pcall(function() Window:SelectTab(2) end)
    pcall(function()
        Fluent:Notify({
            Title = "DIO Hub",
            Content = "Key System Loaded - Please enter key",
            Duration = 5
        })
    end)
end
