--[[ 
Altoholic Account Sharing Module (Vanilla)
Adds multi-account data synchronization via a user-defined private channel.
You must be joined to the specified channel (/join <channel> <password>) before syncing.
]]

local PREFIX = "AltoholicShare"
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

local SYNC_INTERVAL = 600 -- seconds (10 minutes)

local function GetSettings()
    if not AltoholicDB.global then AltoholicDB.global = {} end
    if not AltoholicDB.global.AccountSharing then AltoholicDB.global.AccountSharing = {} end
    return AltoholicDB.global.AccountSharing
end

local function FindChannelIdByName(name)
    if not name or name == "" then return nil end
    local channels = { GetChannelList() }
    for i = 1, #channels, 3 do
        local chanId, chanName = channels[i], channels[i+1]
        if chanName and string.lower(chanName) == string.lower(name) then
            return chanId
        end
    end
    return nil
end

local function GetSyncData()
    local db = AltoholicDB or {}
    local syncData = {}
    if db and db.global and db.global.Characters then
        syncData.global = { Characters = db.global.Characters }
    end
    return LibSerialize:Serialize(syncData)
end

local function MergeSyncData(newData)
    if not AltoholicDB.global then AltoholicDB.global = {} end
    if newData.global and newData.global.Characters then
        for k, v in pairs(newData.global.Characters) do
            AltoholicDB.global.Characters[k] = v
        end
        print("Altoholic: Inventory/Bank data imported from channel sync.")
    else
        print("Altoholic: No valid data received for import.")
    end
end

local function SendSyncData()
    local settings = GetSettings()
    if not settings.Channel or settings.Channel == "" then
        print("Altoholic: Please set a sync channel with /alto_setchannel <channel>.")
        return
    end
    local channelId = FindChannelIdByName(settings.Channel)
    if not channelId then
        print("Altoholic: Sync channel '"..settings.Channel.."' not joined. Join with /join "..settings.Channel.." <password>")
        return
    end
    local data = GetSyncData()
    C_ChatInfo.SendAddonMessage(PREFIX, data, "CHANNEL", channelId)
    print("Altoholic: Inventory/Bank data broadcasted to channel '" .. settings.Channel .. "'.")
end

-- Periodic Sync
local syncTimer = nil
local function PeriodicSync()
    local settings = GetSettings()
    if settings.AutoSync and settings.Channel and settings.Channel ~= "" then
        local channelId = FindChannelIdByName(settings.Channel)
        if channelId then
            SendSyncData()
        else
            print("Altoholic: Not in sync channel '"..settings.Channel.."', skipping periodic sync.")
        end
        -- Schedule next sync
        syncTimer = C_Timer.After(SYNC_INTERVAL, PeriodicSync)
    else
        syncTimer = nil
    end
end

local function StartAutoSync()
    local settings = GetSettings()
    if not settings.AutoSync then
        settings.AutoSync = true
        print("Altoholic: Auto-sync enabled.")
    end
    if not syncTimer then
        syncTimer = C_Timer.After(SYNC_INTERVAL, PeriodicSync)
    end
end

local function StopAutoSync()
    local settings = GetSettings()
    settings.AutoSync = false
    if syncTimer then
        syncTimer = nil
    end
    print("Altoholic: Auto-sync disabled.")
end

-- Event Frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(self, event, prefix, msg, channel, sender, ...)
    if event == "CHAT_MSG_ADDON" and prefix == PREFIX and channel == "CHANNEL" then
        local settings = GetSettings()
        local channelId = FindChannelIdByName(settings.Channel)
        if channelId then
            local success, data = LibSerialize:Deserialize(msg)
            if success then
                MergeSyncData(data)
            end
        end
    end
end)

-- Slash Commands
SLASH_ALTOHOLICSHARE1 = "/alto_share"
SlashCmdList["ALTOHOLICSHARE"] = function()
    SendSyncData()
end

SLASH_ALTOSETCHANNEL1 = "/alto_setchannel"
SlashCmdList["ALTOSETCHANNEL"] = function(msg)
    msg = msg:match("^%s*(.-)%s*$")
    if msg and msg ~= "" then
        local settings = GetSettings()
        settings.Channel = msg
        print("Altoholic: Account sharing channel set to '" .. msg .. "'. Please /join this channel on all accounts. (Password must be set manually.)")
    else
        print("Usage: /alto_setchannel <channel>")
    end
end

SLASH_ALTOAUTOSYNC1 = "/alto_sync_on"
SlashCmdList["ALTOAUTOSYNC"] = function()
    StartAutoSync()
end

SLASH_ALTOAUTOSYNCOFF1 = "/alto_sync_off"
SlashCmdList["ALTOAUTOSYNCOFF"] = function()
    StopAutoSync()
end

-- Initialization: resume auto-sync if enabled
C_Timer.After(5, function()
    local settings = GetSettings()
    if settings.AutoSync then
        StartAutoSync()
    end
end)
