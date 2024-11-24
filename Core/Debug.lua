local SB = select(2, ...)

local Debug = {}
SB.Debug = Debug

local private = {}


-- wow api
local GetChatWindowInfo = 
GetChatWindowInfo

-- lua api
local type, tostring, string, pairs =
type, tostring, string, pairs


function Debug.Log(msg, ...)
    local chatFrame = private.GetDebugChatFrame()
    if chatFrame then
        SB:Printf(chatFrame, msg, ...)
    end
end

function Debug.TableToString ( t )
    local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            SB.Debug.Log(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        SB.Debug.Log(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        SB.Debug.Log(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        SB.Debug.Log(indent.."["..pos..'] => "'..val..'"')
                    else
                        SB.Debug.Log(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                SB.Debug.Log(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        SB.Debug.Log(tostring(t).." {")
        sub_print_r(t,"  ")
        SB.Debug.Log("}")
    else
        sub_print_r(t,"  ")
    end
    SB.Debug.Log("")
end


function private.GetDebugChatFrame() -- private
    local tab = -1
    for i = 1, 10 do
        if GetChatWindowInfo(i)=="SBDebug" then
            tab = i
            break
        end
    end

    if(tab ~= -1) then
        return _G["ChatFrame"..tab]
    end
end