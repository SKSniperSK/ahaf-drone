function(event, ...)
    if event == "AHAF_DRONE_WA_EVT" then
        -- expecting target and drone information table
        local target, di = ...
        if not target or not di then return false end

        -- find the right channel for the SendAddonMessage call
        local channel
        local InInstance, InstanceType = IsInInstance()
        if IsInRaid() then
            channel = (not IsInRaid(LE_PARTY_CATEGORY_HOME) and IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "RAID"
        elseif IsInGroup() then
            channel = (not IsInGroup(LE_PARTY_CATEGORY_HOME) and IsInGroup(LE_PARTY_CATEGORY_INSTANCE)) and "INSTANCE_CHAT" or "PARTY"
        elseif (InInstance and InstanceType == "pvp") then
            channel = "BATTLEGROUND"
        elseif IsInGuild() then
            channel = "GUILD"
        end

        if not channel then
            return false
        else
            aura_env.drone_channel = channel
        end

        -- check for special cases
        if target == "ALL" then
            -- case 'version check'
            if di.type == "s" and di.msg == "vCheck" then
              -- initialize result table for version check and if in group create placeholders for missing drones
              aura_env.player_list = {}
              -- version check placeholder to identify slacking raid members without WA
              -- use channel as group type identification as logic has already been done above
              if channel == "RAID" then
                local raid_member_count = GetNumGroupMembers()
                for i = 1, raid_member_count do
                    local name, server = strsplit("-",select(1,GetRaidRosterInfo(i)))
                    aura_env.player_list[name] = string.format("|cffff0000%s|r", "missing")
                end
              end
              -- pass expected drone version (if needed on drone side) and channel used to communicate
              di.ver = aura_env.drone_version
              di.channel = channel
            end
        end

        -- add target to drone information
        di.tar = target

        -- serialize drone information table and send it to drones
        local Serializer = LibStub:GetLibrary("AceSerializer-3.0")
        aura_env.drone_target = target
        aura_env.drone_message = Serializer:Serialize(di)
        -- check for max string length allowed for SendAddonMessage
        if #aura_env.drone_message > 255 then
            print(string.format("|cFFFF0000AHAF DRONE ERROR: Serialized string is too long!|r"))
            return false
        end
        SendAddonMessage(aura_env.my_prefix, aura_env.drone_message, aura_env.drone_channel, aura_env.drone_target)
        return false
    end

    if event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = ...
        local my_prefix = aura_env.my_prefix or "AHAF_DRONE_WA"
        -- only respond to own drone messages
        if prefix == my_prefix then
            if not message then return false end

            -- deserialize drone information and check for success
            local Serializer = LibStub:GetLibrary("AceSerializer-3.0");
            local success, di = Serializer:Deserialize(message)
            if not success then
                print(string.format("|cFFFF0000AHAF DRONE ERROR: Deserialize failed!|r"))
                return false
            end
            if not di then return false end

            -- check for version check response
            if di.type == "s" then
                if di.msg == "vCheckResult" then
                    -- get result table and fill in response value
                    local pl = aura_env.player_list
                    if di.version < aura_env.drone_version then
                        pl[di.player] = string.format("|cffff0000%s|r", di.version)
                    else
                        pl[di.player] = string.format("%s", di.version)
                    end
                    return true
                end
                -- hide aura on request
                if di.msg == "vCheckResultHide" then
                    return false
                end
            end
        end

    end

    return false
end
