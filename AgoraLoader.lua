-- Agora Admin Loader v15.0 - Corrige function-return MainModule
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local loaderScript = script
local folder = loaderScript.Parent

print("[AGORA] Loader v15.0 demarrage...")

-- 1. SETTINGS (optionnel)
local cfg = {}
local settingsModule = folder:FindFirstChild("Settings")
if settingsModule then
    local ok, result = pcall(require, settingsModule)
    if ok and type(result) == "table" then
        cfg = result
        print("[AGORA] Settings charge")
    else
        warn("[AGORA] Settings invalide, config vide utilisee")
    end
end

-- Valeurs par defaut
if type(cfg) ~= "table" then cfg = {} end
if not cfg.Founders then cfg.Founders = {} end
if not cfg.Prefix then cfg.Prefix = ";" end
if not cfg.WebhookURL then cfg.WebhookURL = "" end
if not cfg.FounderNames then cfg.FounderNames = {} end

-- 2. Fonctions _G placeholders (evite "Profil non reconnu")
_G.Agora_getPlayerRole = function() return "Joueurs" end
_G.Agora_isFounder     = function() return false end
_G.Agora_isOwner       = function() return false end
_G.Agora_isAdmin       = function() return false end
_G.Agora_isMod         = function() return false end
_G.Agora_isPremium     = function() return false end

-- 3. Clone UI dans StarterGui / StarterPlayerScripts
local function setupUI()
    -- Chercher ScreenGui dans le dossier ou les descendants
    local screenGui = folder:FindFirstChild("AgoraAdmin") or folder:FindFirstChild("ScreenGui")
    if not screenGui then
        for _, child in ipairs(folder:GetDescendants()) do
            if child:IsA("ScreenGui") then
                screenGui = child
                break
            end
        end
    end

    if screenGui then
        -- Supprimer l'ancien dans StarterGui s'il existe
        local old = StarterGui:FindFirstChild("AgoraAdmin")
        if old then old:Destroy() end

        local clone = screenGui:Clone()
        clone.Name = "AgoraAdmin"  -- Forcer le nom attendu par le client
        clone.Parent = StarterGui
        print("[AGORA] ScreenGui clone dans StarterGui")

        -- Play Solo : le joueur local est déjà connecté, StarterGui ne réplique pas
        for _, plr in ipairs(Players:GetPlayers()) do
            local pg = plr:WaitForChild("PlayerGui", 3)
            if pg then
                local oldGui = pg:FindFirstChild("AgoraAdmin")
                if oldGui then oldGui:Destroy() end
                local localClone = screenGui:Clone()
                localClone.Name = "AgoraAdmin"
                localClone.Parent = pg
                print("[AGORA] ScreenGui clone dans PlayerGui de " .. plr.Name)
            end
        end
    else
        warn("[AGORA] ScreenGui introuvable dans le dossier")
    end

    -- Chercher LocalScript client
    local clientScript = folder:FindFirstChild("AgoraClient")
    if not clientScript then
        for _, child in ipairs(folder:GetDescendants()) do
            if child:IsA("LocalScript") then
                clientScript = child
                break
            end
        end
    end

    if clientScript then
        local old = StarterPlayer:WaitForChild("StarterPlayerScripts", 2)
        if old then
            local oldClient = old:FindFirstChild(clientScript.Name)
            if oldClient then oldClient:Destroy() end
        end

        local clone = clientScript:Clone()
        clone.Parent = StarterPlayer.StarterPlayerScripts
        print("[AGORA] LocalScript clone dans StarterPlayerScripts")
    else
        warn("[AGORA] LocalScript client introuvable")
    end
end

setupUI()

-- 4. Fetch proxy
local PROXY = "https://sagefoquydjxkgjyhqrm.supabase.co/functions/v1/agora-proxy"

local function fetchFile(name)
    local url = PROXY .. "?file=" .. name .. "&nocache=" .. tick()
    print("[AGORA] Fetch " .. name .. " ...")
    local success, result = pcall(HttpService.GetAsync, HttpService, url, true)
    if not success then
        warn("[AGORA] HTTP FAIL " .. name .. ": " .. tostring(result))
        return nil
    end
    if not result or result:find("File not found") or #result < 50 then
        warn("[AGORA] Fichier vide/introuvable: " .. name)
        return nil
    end
    print("[AGORA] " .. name .. " recu (" .. #result .. " chars)")
    return result
end

local mainSrc = fetchFile("MainModule.lua")
if not mainSrc then error("[AGORA] Impossible de charger MainModule") end

local cmdSrc = fetchFile("Commands.lua")
if not cmdSrc then error("[AGORA] Impossible de charger Commands") end

-- 5. loadstring
local okMm, MainModule = pcall(loadstring, mainSrc)
if not okMm or typeof(MainModule) ~= "function" then
    error("[AGORA] loadstring MainModule invalide")
end

local okCmd, commandsFn = pcall(loadstring, cmdSrc)
if not okCmd or typeof(commandsFn) ~= "function" then
    error("[AGORA] loadstring Commands invalide")
end

local commands = commandsFn()

-- 6. Lancer MainModule
local ok, mm = pcall(MainModule, cfg, commands, folder)

if not ok then
    warn("[AGORA] MainModule crash: " .. tostring(mm))
    return
end

if typeof(mm) == "function" then
    -- MainModule retourne une fonction (return function(...) end)
    local ok2, result = pcall(mm, cfg, commands, folder)
    if ok2 then
        if typeof(result) == "table" and typeof(result.Init) == "function" then
            result:Init({Settings = cfg, ScriptRef = loaderScript})
            print("[AGORA] v15.0 INIT OK (table mode)")
        else
            print("[AGORA] v15.0 INIT OK (function mode)")
        end
    else
        warn("[AGORA] MainModule init crash: " .. tostring(result))
    end
elseif typeof(mm) == "table" and typeof(mm.Init) == "function" then
    mm:Init({Settings = cfg, ScriptRef = loaderScript})
    print("[AGORA] v15.0 INIT OK (table mode)")
else
    print("[AGORA] v15.0 INIT OK (inline mode)")
end
