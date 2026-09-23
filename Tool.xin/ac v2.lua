-- ══════════════════════════════════════════════════════════════════════════
-- //  TTJY Studio — Anti-Cheat Tracker & Analyzer
-- //  Version  : 2.0
-- //  Author   : TTJY Studio
-- //  NOTE     : DO NOT USE API.M
-- ══════════════════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────────────────
-- // Settings
-- ────────────────────────────────────────────────────────────────────────
local Settings = {
    ShowAllOutputs     = false;  -- พิมพ์ผล debug ทั้งหมด
    BlockLoopCrash     = true;   -- ตั้ง ScriptContext timeout เพื่อป้องกัน loop crash
    BlockAutisticError = false;  -- (reserved)
    DisableLogService  = true;   -- ปิด LogService connections
    AllowHookmeta      = false;  -- hook __namecall เพื่อดัก FindService ผ่าน meta
}

-- ────────────────────────────────────────────────────────────────────────
-- // Internal State
-- ────────────────────────────────────────────────────────────────────────
local LogServiceFound       = {}
local deepNames             = {}
local AlreadyRF, callbacRF  = {}, {}

local ACs = {
    FindService   = {};
    hasRFCallback = false;
}
local ACInfo = {}

local Flags = {
    DetectStrings     = false;
    AdonisMeta        = false;
    compareTables     = false;
    erroroverflow     = false;
    IsMetaFindService = false;
    BindableHook      = false;
    RemoteEventHook   = false;
}
local source_overflowerror = nil
local source_compareTables = nil

-- Services ที่ AC นิยมตรวจ
local SuspiciousServices = {
    "VirtualUser",
    "VirtualInputManager",
    "UGCValidationService",
    "CoreGui",
    "NetworkClient",
}

-- ────────────────────────────────────────────────────────────────────────
-- // Helpers
-- ────────────────────────────────────────────────────────────────────────
local function cout(...)
    if Settings.ShowAllOutputs then print(...) end
end

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then cout("[safeCall error]", err) end
end

local LINE = string.rep("─", 60)

local function header(text)
    warn(LINE)
    warn("//  " .. text)
    warn(LINE)
end

local function found(tag, detail)
    warn(string.format("  [✔ FOUND]  %-30s %s", "<"..tag..">", detail or ""))
end

local function patched(msg)
    warn("       [✔ Patched] " .. (msg or "Successfully!"))
end

local function notFound(tag)
    warn(string.format("  [✘ CLEAN]  <%s>", tag))
end

local function info(...)
    warn("       [INFO]", ...)
end

-- ────────────────────────────────────────────────────────────────────────
-- // 1. Disable LogService Connections
-- ────────────────────────────────────────────────────────────────────────
if Settings.DisableLogService then
    safeCall(function()
        for _, v in pairs(getconnections(game:GetService("LogService").MessageOut)) do
            table.insert(LogServiceFound, v)
            -- v:Disable()  -- uncomment เพื่อ disable จริง
        end
    end)
end

-- ────────────────────────────────────────────────────────────────────────
-- // 2. Block Loop Crash (ScriptContext Timeout)
-- ────────────────────────────────────────────────────────────────────────
if Settings.BlockLoopCrash then
    safeCall(function()
        game:GetService("ScriptContext"):SetTimeout(1)
    end)
end

-- ────────────────────────────────────────────────────────────────────────
-- // 3. Patch "overflow" Error Constant (C Closure pcall/xpcall Guard)
-- ────────────────────────────────────────────────────────────────────────
safeCall(function()
    for _, v in pairs(getgc(true)) do
        if typeof(v) == "function" and islclosure(v) then
            local consts = getconstants(v)
            local idx = table.find(consts, "overflow")
            if idx and not table.find(consts, "__index") then
                setconstant(v, idx, "niggaua")
                Flags.erroroverflow  = true
                source_overflowerror = getinfo(v)
                cout("[Patched] overflow at const index", idx)
            end
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────
-- // 4. Hook game.FindService — ดัก Suspicious Service Lookups
-- ────────────────────────────────────────────────────────────────────────
local _origFindService
safeCall(function()
    _origFindService = hookfunction(game.FindService, function(self, service)
        cout("[FindService called]", service)
        if table.find(SuspiciousServices, service) then
            table.insert(ACs.FindService, service)
            ACInfo[service] = getcallingscript()
            return nil
        end
        return _origFindService(self, service)
    end)
end)

-- ────────────────────────────────────────────────────────────────────────
-- // 5. Detect islclosure String Table (executor env fingerprint)
-- ────────────────────────────────────────────────────────────────────────
safeCall(function()
    for _, v in pairs(getgc(true)) do
        if typeof(v) == "table" and table.find(v, "islclosure") then
            deepNames = table.clone(v)
            table.clear(v)
            Flags.DetectStrings = true
            cout("[Detected] islclosure string table cleared")
            break
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────
-- // 6. Detect Adonis Meta Table
-- ────────────────────────────────────────────────────────────────────────
safeCall(function()
    for _, v in getgc(true) do
        if
            typeof(v) == "table"
            and rawget(v, "indexInstance")
            and rawget(v, "newindexInstance")
            and rawget(v, "namecallInstance")
            and type(rawget(v, "newindexInstance")) == "table"
        then
            Flags.AdonisMeta = true
            cout("[Detected] Adonis meta table")
            break
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────
-- // 7. Patch compareTables (Adonis / Generic AC Integrity Check)
-- ────────────────────────────────────────────────────────────────────────
safeCall(function()
    for _, v in getgc(true) do
        if typeof(v) == "function" and getinfo(v).name == "compareTables" then
            local gvinfo = getinfo(v)
            if string.find(gvinfo.source, "Anti") then
                local _orig; _orig = hookfunction(v, function()
                    return true
                end)
                Flags.compareTables  = true
                source_compareTables = gvinfo.source
                cout("[Patched] compareTables in", gvinfo.source)
                break
            end
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────
-- // 8. Hook __namecall via hookmetamethod (Optional, Settings.AllowHookmeta)
-- ────────────────────────────────────────────────────────────────────────
if Settings.AllowHookmeta then
    safeCall(function()
        local _origMeta; _origMeta = hookmetamethod(game, "__namecall", function(self, ...)
            if not checkcaller() then
                if getnamecallmethod() == "FindService" then
                    local svc = select(1, ...)
                    if table.find(SuspiciousServices, svc) then
                        Flags.IsMetaFindService = true
                        return nil
                    end
                end
            end
            return _origMeta(self, ...)
        end)
    end)
end

-- ────────────────────────────────────────────────────────────────────────
-- // 9. Detect RemoteFunction OnClientInvoke Callbacks
-- ────────────────────────────────────────────────────────────────────────
local function ValidateRF(v)
    if table.find(AlreadyRF, v) then return end
    table.insert(AlreadyRF, v)
    local callback = getcallbackvalue(v, "OnClientInvoke")
    if callback then
        ACs.hasRFCallback = true
        callbacRF[v]      = callback
        cout("[RF Callback detected]", tostring(v))
    end
end

safeCall(function()
    local instas = getinstances()
    for i = 1, #instas do
        local v = instas[i]
        if v and v:IsA("RemoteFunction") then ValidateRF(v) end
    end
end)

-- ────────────────────────────────────────────────────────────────────────
-- // 10. [NEW] Detect BindableFunction.OnInvoke ที่มี AC source
-- ────────────────────────────────────────────────────────────────────────
safeCall(function()
    local instas = getinstances()
    for i = 1, #instas do
        local v = instas[i]
        if v and v:IsA("BindableFunction") then
            local cb = getcallbackvalue(v, "OnInvoke")
            if cb and islclosure(cb) then
                local src = getinfo(cb).source or ""
                if src:find("Anti") or src:find("Cheat") or src:find("AC") then
                    Flags.BindableHook = true
                    cout("[BindableFunction AC listener]", tostring(v), src)
                end
            end
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────
-- // 11. [NEW] Detect RemoteEvent.OnClientEvent ที่มี AC source
-- ────────────────────────────────────────────────────────────────────────
safeCall(function()
    local instas = getinstances()
    for i = 1, #instas do
        local v = instas[i]
        if v and v:IsA("RemoteEvent") then
            local conns = getconnections(v.OnClientEvent)
            for _, conn in pairs(conns) do
                local fn = conn.Function
                if fn and islclosure(fn) then
                    local src = getinfo(fn).source or ""
                    if src:find("Anti") or src:find("Cheat") then
                        Flags.RemoteEventHook = true
                        cout("[RemoteEvent AC listener]", tostring(v), src)
                    end
                end
            end
        end
    end
end)

-- ────────────────────────────────────────────────────────────────────────
-- // ACTest — Hook Speed/Timing Tester
-- ────────────────────────────────────────────────────────────────────────
getgenv().ACTest = {
    ---@param target string  "index" | "namecall" | "newindex"
    TryHook = function(self, target)
        assert(type(target) == "string", "TryHook: target must be a string")
        for i = 1, 2 do
            safeCall(function()
                local _o; _o = hookmetamethod(game, "__" .. target, newcclosure(function(...)
                    return _o(...)
                end))
            end)
        end
        warn("[ACTest] TryHook __" .. target .. " done (x2 pass)")
    end,
}

-- ────────────────────────────────────────────────────────────────────────
-- // Tool — Public Anti-Cheat Report API
-- ────────────────────────────────────────────────────────────────────────
getgenv().Tool = {

    --- พิมพ์รายงาน AC ทั้งหมด
    GetAntiCheat = function(self)
        header("TTJY Studio | Anti-Cheat Scan Report")

        -- FindService (function hook)
        if #ACs.FindService > 0 then
            found("FindService", "(" .. #ACs.FindService .. " service(s))")
            for _, svc in ipairs(ACs.FindService) do
                warn("         [@]", svc)
                local caller = ACInfo[svc]
                if caller then
                    info("Script:", caller, "—", caller:GetFullName())
                end
            end
        else
            notFound("FindService")
        end

        -- FindService via __namecall meta
        if Flags.IsMetaFindService then
            found("FindService @ __namecall")
        end

        -- String table (executor env log)
        if Flags.DetectStrings then
            found("StringTable (islclosure)", "Possible executor env fingerprint")
            info("Run Tool:ShowDetectStrings() to inspect contents")
        end

        -- compareTables
        if Flags.compareTables then
            if Flags.AdonisMeta then
                found("compareTables + Adonis meta", "[indexInstance|newindexInstance|namecallInstance]")
                info("Source:", source_compareTables)
                patched("compareTables → always returns true")
            else
                found("compareTables", "Unknown origin — possibly custom AC")
            end
        end

        -- overflow constant patch
        if Flags.erroroverflow then
            found("overflow constant", "C-closure pcall/xpcall guard detected")
            patched("'overflow' string replaced → error guard disabled")
            if source_overflowerror then
                for k, v in pairs(source_overflowerror) do
                    info(tostring(k), "=", tostring(v))
                end
            end
        end

        -- LogService
        if #LogServiceFound > 0 then
            found("LogService.MessageOut", #LogServiceFound .. " connection(s) captured")
        else
            notFound("LogService connections")
        end

        -- RemoteFunction OnClientInvoke
        if ACs.hasRFCallback then
            found("RemoteFunction.OnClientInvoke", #AlreadyRF .. " RF(s) with callback")
            info("Run Tool:RFCheck(n, bool) for deep-dive")
            for rf, cb in pairs(callbacRF) do
                local idx = table.find(AlreadyRF, rf)
                warn(string.format("         [%s @ %s] : %s",
                    tostring(idx), tostring(rf), tostring(cb)))
            end
        else
            notFound("RemoteFunction.OnClientInvoke  (Safer)")
        end

        -- BindableFunction hooks
        if Flags.BindableHook then
            found("BindableFunction.OnInvoke", "AC script listener matched")
        else
            notFound("BindableFunction AC hooks")
        end

        -- RemoteEvent AC listeners
        if Flags.RemoteEventHook then
            found("RemoteEvent.OnClientEvent", "AC source string matched")
        else
            notFound("RemoteEvent AC listeners")
        end

        -- ScriptContext timeout
        if Settings.BlockLoopCrash then
            found("ScriptContext Timeout", "Active — loop crash mitigated")
            info("Loop crash will still appear in console if triggered")
        end

        warn(LINE)
        warn("//  Tool:Explain('name')  for function documentation")
        warn(LINE)
    end,

    --- Decompile script ที่ดักจับมาจาก FindService
    ---@param service string
    Decompile = function(self, service)
        local script = ACInfo[service]
        if not script then
            warn("[Decompile] No script recorded for service:", service)
            return
        end
        return decompile(script)
    end,

    --- แสดง string ทั้งหมดใน islclosure string table ที่ดักได้
    ShowDetectStrings = function(self)
        if not Flags.DetectStrings then
            warn("[ShowDetectStrings] Nothing was captured.")
            return
        end
        header("Captured Strings — islclosure Table")
        table.foreach(deepNames, function(i, v)
            warn("  [" .. tostring(i) .. "]", tostring(v))
        end)
    end,

    --- ตรวจสอบ RF callback อย่างละเอียด
    ---@param num   number   index ใน AlreadyRF (จาก GetAntiCheat report)
    ---@param setcl boolean  ถ้า true จะ copy deep-dive snippet ไป clipboard
    RFCheck = function(self, num, setcl)
        local rf = AlreadyRF[num]
        if not rf then
            warn("[RFCheck] No RemoteFunction at index:", num)
            return
        end
        local cb = callbacRF[rf]
        if not cb then
            warn("[RFCheck] RF exists but has no recorded callback:", tostring(rf))
            return
        end

        header(string.format("RFCheck  [%d @ %s]", num, tostring(rf)))
        local ups = getupvalues(cb)
        local cos = getconstants(cb)
        warn("  Upvalues  :", #ups)
        warn("  Constants :", #cos)
        warn("  Callback  :", tostring(cb))

        if setcl then
            local snippet = string.format([[
for i,v in pairs(getinstances()) do
    if v.Name == "%s" then
        local cb = getcallbackvalue(v, "OnClientInvoke")
        if cb and tostring(cb) == "%s" then
            print(debug.info(cb, "slanf"))
            if islclosure(cb) then
                local ups = getupvalues(cb)
                local cos = getconstants(cb)
                local pro = getprotos(cb)
            end
        end
    end
end]], tostring(rf), tostring(cb))
            pcall(setclipboard, snippet)
            warn("  [Clipboard] Deep-dive snippet copied!")
        end
    end,

    --- อธิบาย API ของ Tool / ACTest
    ---@param name string
    Explain = function(self, name)
        local docs = {
            TryHook = {
                "ACTest:TryHook(target)  — Hooks a metamethod twice to test detection speed.",
                "Some ACs flag you based on how quickly __index/__namecall are hooked.",
                "If flagged: consider spoofing os.clock() or tick() timing.",
                "Valid targets: 'index'  |  'namecall'  |  'newindex'",
            },
            RFCheck = {
                "Tool:RFCheck(n, setCB)  — Deep-inspects a captured RF callback.",
                "  n     = index shown in GetAntiCheat() report",
                "  setCB = true → copies a reusable debug snippet to clipboard",
            },
            GetAntiCheat = {
                "Tool:GetAntiCheat()  — Prints the full AC scan report.",
                "Lists all detected anti-cheat vectors found during initialization.",
            },
            ShowDetectStrings = {
                "Tool:ShowDetectStrings()  — Dumps captured strings from islclosure table.",
                "Useful to identify which executor API names the AC is logging.",
            },
        }
        local entry = docs[tostring(name)]
        if entry then
            header("Explain: " .. tostring(name))
            for _, line in ipairs(entry) do warn("  " .. line) end
        else
            warn("[Explain] Unknown name:", tostring(name))
            warn("  Available: TryHook, RFCheck, GetAntiCheat, ShowDetectStrings")
        end
    end,
}

-- ────────────────────────────────────────────────────────────────────────
-- // Startup Banner
-- ────────────────────────────────────────────────────────────────────────
header("TTJY Studio | AC Tracker v2.0 — Ready")
warn("  Tool:GetAntiCheat()            Full scan report")
warn("  Tool:RFCheck(n, bool)          RF callback detail")
warn("  Tool:ShowDetectStrings()       islclosure string dump")
warn("  Tool:Decompile('ServiceName')  Decompile AC script")
warn("  Tool:Explain('name')           API documentation")
warn("  ACTest:TryHook('index')        Hook speed test")
warn(LINE)
