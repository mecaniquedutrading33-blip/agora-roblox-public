-- Agora Admin Loader v16.0 - Mode StarterGui direct (ScreenGui deja dans StarterGui)
-- Place ce Script dans ServerScriptService/TON_DOSSIER/
-- Place le ScreenGui (avec LocalScript DEDANS) dans StarterGui

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local isStudio = RunService:IsStudio()

-- 1) Trouver Settings.lua dans le dossier actuel
local scriptFolder = script.Parent
print("[AGORA v16] Chargement depuis dossier : " .. scriptFolder.Name)

local settingsFile = scriptFolder:FindFirstChild("Settings")
if not settingsFile then
    for _, child in ipairs(scriptFolder:GetDescendants()) do
        if child.Name == "Settings" and child:IsA("ModuleScript") then
            settingsFile = child
            break
        end
    end
end

if not settingsFile then
    error("[AGORA] Settings.lua introuvable dans " .. scriptFolder.Name .. ". Mets-le dans le meme dossier que le Loader.")
    return
end

local SETTINGS
local ok, err = pcall(function()
    SETTINGS = require(settingsFile)
end)
if not ok then
    error("[AGORA] Erreur require Settings.lua : " .. tostring(err))
    return
end

print("[AGORA] Settings charges : theme=" .. tostring(SETTINGS.Theme) .. " prefix=" .. tostring(SETTINGS.Prefix))

-- 2) CREER SystemRemotes s'il n'existe pas
local SystemRemotes = ReplicatedStorage:FindFirstChild("SystemRemotes")
if not SystemRemotes then
    SystemRemotes = Instance.new("Folder")
    SystemRemotes.Name = "SystemRemotes"
    SystemRemotes.Parent = ReplicatedStorage
    print("[AGORA] SystemRemotes cree dans ReplicatedStorage")
end

local function ensureRemote(name, class)
    local r = SystemRemotes:FindFirstChild(name)
    if not r then
        r = Instance.new(class)
        r.Name = name
        r.Parent = SystemRemotes
        print("[AGORA] Remote cree : " .. name .. " (" .. class .. ")")
    end
    return r
end

ensureRemote("GetCmdsFunc", "RemoteFunction")
ensureRemote("RefreshEvent", "RemoteEvent")
ensureRemote("NotifEvent", "RemoteEvent")
ensureRemote("FlyEvent", "RemoteEvent")
ensureRemote("SettingsEvent", "RemoteEvent")
ensureRemote("CmdBarEvent", "RemoteEvent")

print("[AGORA] 6 remotes verifies dans SystemRemotes")

-- 3) Charger MainModule (local ou distant)
local function loadMainModule()
    local module = scriptFolder:FindFirstChild("MainModule")
    if module then
        print("[AGORA] MainModule LOCAL trouve dans dossier")
        return require(module)
    end

    if isStudio then
        warn("[AGORA] MainModule absent et on est en Studio. Creer un MainModule basique local.")
        return {
            Init = function() print("[MainModule] Init local (stub)") end,
            GetCommands = function() return {} end,
            ExecCommand = function() return nil, "Stub" end
        }
    end

    print("[AGORA] MainModule local absent. Tentative HTTP...")
    local success = pcall(function()
        module = game:GetService("InsertService"):LoadAsset(123456789)
    end)
    if success and module then
        return require(module)
    end

    warn("[AGORA] MainModule introuvable. Serveur minimal actif.")
    return {
        Init = function() end,
        GetCommands = function() return {} end,
        ExecCommand = function() return nil, "MainModule absent" end
    }
end

local MainModule = loadMainModule()
if MainModule.Init then
    local ok2, err2 = pcall(MainModule.Init, SystemRemotes, SETTINGS)
    if not ok2 then warn("[AGORA] Erreur MainModule.Init : " .. tostring(err2)) end
end

-- 4) Setup commandes pour RemoteFunction
local GetCmdsFunc = SystemRemotes:FindFirstChild("GetCmdsFunc")
if GetCmdsFunc then
    GetCmdsFunc.OnServerInvoke = function(player)
        local cmds = {}
        if MainModule.GetCommands then
            local ok3, res = pcall(MainModule.GetCommands)
            if ok3 then cmds = res or {} end
        end
        print("[AGORA] GetCmdsFunc invoque par " .. player.Name .. " -> " .. #cmds .. " commandes")
        return cmds
    end
end

-- 5) Handle ExecCommand via RefreshEvent (backward compat)
local RefreshEvent = SystemRemotes:FindFirstChild("RefreshEvent")
if RefreshEvent then
    RefreshEvent.OnServerEvent:Connect(function(player, cmdData)
        if type(cmdData) ~= "table" or not cmdData.cmd then return end
        if MainModule.ExecCommand then
            local ok4, res = pcall(MainModule.ExecCommand, player, cmdData.cmd, cmdData.args or {})
            if not ok4 then warn("[AGORA] ExecCommand erreur : " .. tostring(res)) end
        end
    end)
end

-- 6) Log tous les joueurs qui joignent (verification que tout est pret)
Players.PlayerAdded:Connect(function(plr)
    print("[AGORA] Joueur connecte : " .. plr.Name)
    local pg = plr:WaitForChild("PlayerGui", 5)
    if pg then
        local gui = pg:FindFirstChild("AgoraAdmin") or pg:FindFirstChild("ScreenGui") or pg:FindFirstChild("OpenButton")
        if gui then
            print("[AGORA] PlayerGui OK pour " .. plr.Name .. " : " .. gui.Name)
        else
            warn("[AGORA] AUCUN ScreenGui dans PlayerGui de " .. plr.Name .. "!")
        end
    end
end)

print("=========================================")
print("[AGORA v16] SERVEUR PRET")
print("[AGORA v16] ScreenGui doit etre dans StarterGui avec le LocalScript DEDANS")
print("=========================================")
