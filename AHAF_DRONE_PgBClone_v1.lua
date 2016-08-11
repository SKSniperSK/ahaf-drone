function(allstates, event, ...)
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

        -- parse drone information table
        local display = ""
        -- system call
        if di.type == "s" then
            -- react to hide call
            if di.msg == "hide" then
                -- hide specific id if passed or everything if not
                if di.id then
                    if allstates[di.id] then
                        allstates[di.id].changed = true
                        allstates[di.id].show = false
                    end
                else
                    for _, v in pairs(allstates) do
                        v.changed = true
                        v.show = false
                    end
                end
            end
            return true
        -- progress bar call (primary function of this drone child aura)
        elseif di.type == "p" then
            -- only react if call is meant for this drone
            if di.tar == "ALL" or GetUnitName("player") == di.tar then

              -- use id if passed for current state or create new state
              local id = di.id or #allstates + 1
              allstates[id] = allstates[id] or {}
              local state = allstates[id]
              state.changed = true

                -- react to individual hide call, hide specific id if passed or everything if not
                if di.msg == "hide" then
                    if di.id then
                        state.show = false
                    else
                        for _, v in pairs(allstates) do
                            v.changed = true
                            v.show = false
                        end
                    end
                    return true
                end

                -- prepare variables for current state
                local dur, exp, ico, msg, arr, stk, name

                -- parse duration information
                if di.dur then
                    state.progressType = "timed"
                    state.autoHide = true
                    -- default values
                    dur = 5
                    exp = GetTime() + dur
                    -- duration info as single numnber
                    if type(di.dur) == "number" then
                        dur = di.dur
                        exp = GetTime() + dur
                    end
                    -- duration info as 2-value table duration/expiration
                    if type(di.dur) == "table" and #di.dur == 2 then
                        dur = di.dur[1]
                        -- if latency is passed use it to compensate for event delay
                        if di.lat and type(di.lat) == "number" then
                            local homeLat, worldLat = select(3, GetNetStats())
                            -- latency in ms and /2 because of roundtrip value
                            exp = GetTime() + di.dur[2] + ((di.lat + homeLat) / 2 / 1000)
                        else
                            exp = GetTime() + di.dur[2]
                        end
                    end
                end
                -- parse icon information
                if di.ico then
                    -- if icon is a number use it as spellId else expect valid icon string
                    if type(di.ico) == "number" then
                        ico = select(3, GetSpellInfo(di.ico))
                    else
                        ico = di.ico
                    end
                end
                -- parse message (text) information
                if di.msg then
                    msg = di.msg
                end
                -- parse name (text) information
                if di.name then
                    name = di.name
                end
                -- parse arrow information table (Exorsus needed)
                if di.arr and GExRT then
                    -- arrow type based on first table entry ('M'apCoord, 'C'oord or 'P'layer)
                    if di.arr[1] == "M" then
                        arr = function() return GExRT.F.ArrowTextMapCoord(di.arr[2], di.arr[3], di.arr[4]) end
                    end
                    if di.arr[1] == "C" then
                        arr = function() return GExRT.F.ArrowTextCoord(di.arr[2], di.arr[3], di.arr[4]) end
                    end
                    if di.arr[1] == "P" then
                        arr = function() return GExRT.F.ArrowTextPlayer(di.arr[2], di.arr[3]) end
                    end
                end
                -- parse stack information
                if di.stk and type(di.stk) == 'number' then
                    stk = di.stk
                end
                -- parse countdown information (only useable if duration/expiration information was also passed)
                if di.ctd and type(di.ctd) == "number" and exp then
                    local duration = exp - GetTime()
                    -- create timer for each of the last x seconds to create a visible (say) countdown message
                    for i = di.ctd, 1, -1 do
                        local delay = i + 0.2
                        local cTime = duration - delay
                        if cTime > 0 then
                            C_Timer.After(duration - delay, function() SendChatMessage(i) end)
                        end
                    end
                end

                -- set state values
                state.duration = dur
                state.expirationTime = exp
                state.icon = ico
                state.stacks = stk
                state.name = name
                state.arrow = arr
                display = msg
                -- replace {rtX} with raid target marker X icon
                state.display = ("%s"):format(display:gsub("{rt([1-8])}", "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%1:0|t"))
                state.show = true
                return true
            else
                return false
            end
        else
            return false
        end
    end
    return false
end
