--礼包兑换码
module("giftcode", package.seeall)

--[[

 giftCodeData = {
    [id]= 1 已领取
 }
--]]
local CODE_SUCCESS = 0
local CODE_INVALID = 1 --已被使用
local CODE_NOTEXIST = 2
local CODE_USED = 3 --已使用过同类型
local CODE_ERR = 4

local function getStaticData(actor)
    local var = LActor.getStaticVar(actor)
    if var == nil then
        print("get gift code data error.")
    end

    if var.giftCodeData == nil then
        var.giftCodeData = {}
    end
    return var.giftCodeData
end
function stripfilename(filename)
    return string.match(filename, "(.+)/[^/]*%.%w+$")
end
local function getCodeId(code)
    --[[local len = string.byte(string.sub(code, -1)) - 97
    local pos = string.byte(string.sub(code, -2,-2)) - 97

    local str = string.sub(code, pos + 1, pos + len)
    local id = 0
    for i=1, string.len(str) do
        id = id * 10 + (math.abs(string.byte(string.sub(str, i, i)) - 97))
    end
    return id--]]
    local oneLoc = string.byte(string.sub(code, 1,1))-65+1
    local twoLoc = string.byte(string.sub(code, 2,2))-65+1
    local threeLoc = string.byte(string.sub(code, -2,-2))-65+1
    local fourLoc = string.byte(string.sub(code, -1))-65+1
    local one = string.byte(string.sub(code, oneLoc,oneLoc))-97
    local two = string.byte(string.sub(code, twoLoc,twoLoc))-97
    local three = string.byte(string.sub(code, threeLoc,threeLoc))-97
    local four = string.byte(string.sub(code, fourLoc,fourLoc))-97

    local id = tonumber(one..two..three..four)
    return id
end

local function checkCode(actor, code)
    if string.len(code) ~= 16 then
        return CODE_ERR
    end
    local id = getCodeId(code)
    if id == 0 then
        return CODE_ERR
    end

    local conf = GiftCodeConfig[id]
    if conf == nil or conf.gift == nil then
        print("gift code config is nil :"..tostring(id))
        return CODE_ERR
    end

    local data = getStaticData(actor)
    if (data[id] or 0) >= (conf.count or 1) then
        return CODE_USED
    end

    return CODE_SUCCESS, id
end

--处理web返回
local function onResultCheck(params, retParams)
    local actor = LActor.getActorById(params[1])
    if actor == nil then return end

    local content = retParams[1]
    local ret = retParams[2]
    if ret ~= 0 then return end

    local res = tonumber(content)
    if res == nil then
        print("onGiftCode response nil.")
        print("content:"..content)
        return
    end

    if res == CODE_SUCCESS then
        local id = params[2]
        local code = params[3]
        local data = getStaticData(actor)

        local conf = GiftCodeConfig[id]
        if conf == nil or conf.gift == nil then
            print("gift code config is nil :"..tostring(id))
            return
        end

        if (data[id] or 0) >= (conf.count or 1) then
            print("onGiftCode result check count:"..(data[id] or 0))
            return
        end --再次检查是否使用过,因为异步问题

        data[id] = (data[id] or 0) + 1

        --LActor.giveAwards(actor, conf.gift, "gift code "..tostring(id))

        --发邮件
        local mailData = {head=conf.mailTitle, context=conf.mailContent, tAwardList=conf.gift}
        mailsystem.sendMailById(LActor.getActorId(actor), mailData)
    end

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
    if npack == nil then return end

    LDataPack.writeByte(npack, res)
    LDataPack.flush(npack)
end

local function checkChannelCode(actor, code)
    if code == nil or code == "" then
        return CODE_ERR
    end
    if string.len(code) > 28 then
        return CODE_ERR
    end

    local conf = ChannelGiftCodeConfig[code]
    if conf == nil or conf.gift == nil then
        return CODE_ERR
    end

    local data = getStaticData(actor)
    if (data[code] or 0) >= 1 then
        return CODE_USED
    end

    if data.pf ~= nil and data.pf ~= LActor.getPf(actor) then
        return CODE_ERR
    end

    -- if conf.appid ~= nil and tostring(conf.appid) ~= LActor.getAppid(actor) then
    --  return CODE_ERR
    -- end

    return CODE_SUCCESS
end

local function giveChannelCodeReward(actor, code)
    local conf = ChannelGiftCodeConfig[code]
    if conf == nil then return end
    local data = getStaticData(actor)
    if data == nil then return end

    data.pf = LActor.getPf(actor)
    data[code] = (data[code] or 0) + 1

    --发邮件
    local mailData = {head=conf.mailTitle, context=conf.mailContent, tAwardList=conf.gift}
    mailsystem.sendMailById(LActor.getActorId(actor), mailData)

    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
    if npack == nil then return end

    LDataPack.writeByte(npack, CODE_SUCCESS)
    LDataPack.flush(npack)
end
--写验证码文件
local function writeFile(dataBuffer,dir)
    local writeHandle = assert(io.open(dir, "a+"), "not the file");
    if writeHandle then
        writeHandle:write(dataBuffer);
        writeHandle:write("\n");
        print("true");
    else
        print("false");
    end
    writeHandle:close();
end
-- 读取验证码文件
local function readFile(dir)
    local fileHandle = assert(io.open(dir, "r"), "not the file");
    local result = {};
    for line in fileHandle:lines() do
        result[#result+1] = line;
    end
    fileHandle:close(errorInfo);
    return result
end
--发送web验证
local function postCodeCheck(code, aid, id, pf, appid)
    local uri = "/"..tostring(pf).."/Cdk?type=2&cdkey="..code.."&appid="..appid
    sendMsgToWeb(uri, onResultCheck, {aid, id, code})
end

local function getChannelCode(actor, code)
    local ret, id = checkChannelCode(actor, code)
    if ret ~= CODE_SUCCESS then
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
        if npack == nil then return end

        LDataPack.writeByte(npack, ret)
        LDataPack.flush(npack)
        return
    end
    giveChannelCodeReward(actor, code)
end

local function getNormalCode(actor, code)
    local info = debug.getinfo(1,"S")
    --获取当前路径
    local pathinfo = info.short_src
    -- local obj=io.popen("cd") --如果不在交互模式下，前面可以添加local
    -- local path=obj:read("*all"):sub(1,-2) --path存放当前路径
    local ret, id = checkCode(actor, code)
    if ret ~= CODE_SUCCESS then
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
        if npack == nil then return end

        LDataPack.writeByte(npack, ret)
        LDataPack.flush(npack)
        return 
    end
    -- postCodeCheck(code, LActor.getActorId(actor), id, LActor.getPf(actor), LActor.getAppid(actor))
    --验证此激活码是否被别人用过
    local invalidCDKey = readFile(stripfilename(pathinfo).."/InvalidCDKey.txt")
    local used = isContain(code,invalidCDKey)
    if used then
        print("used ")
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
        if npack == nil then return end

        LDataPack.writeByte(npack, CODE_INVALID)
        LDataPack.flush(npack)
        return 
    end 
    --验证此激活码自己是否使用过
    local conf = GiftCodeConfig[id]
    local data = getStaticData(actor)
    if (data[id] or 0) >= (conf.count or 1) then
        print("onGiftCode result check count:"..(data[id] or 0))
        return 
    end --再次检查是否使用过,因为异步问题

    --发邮件
    print("send mail AwardList")
    local mailData = {head=conf.mailTitle, context=conf.mailContent, tAwardList=conf.gift}
    mailsystem.sendMailById(LActor.getActorId(actor), mailData)
    
    --将此验证码写入文件
    writeFile(code,stripfilename(pathinfo).."/InvalidCDKey.txt")
    data[id] = (data[id] or 0) + 1
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
    if npack == nil then return end
    LDataPack.writeByte(npack, CODE_SUCCESS)
    LDataPack.flush(npack)
    return

end
--是否包含次验证码
function isContain(str,arr)
    for k,v in pairs(arr) do
        if(str == v) then
            return true
        end
    end
    return false
end

local function isChannelCode(code)
    local conf = ChannelGiftCodeConfig[code]
    if conf then
        return true
    end
    return false
end

local function onGetGift(actor, packet)
    local code = LDataPack.readString(packet)
    if not code then return end
    if isChannelCode(code) then
        getChannelCode(actor, code)
    else
        getNormalCode(actor, code)
    end
end

function gmTest(actor, code)
    local ret, id = checkCode(actor, code)
    if ret ~= CODE_SUCCESS then
        local npack = LDataPack.allocPacket(actor, Protocol.CMD_Gift, Protocol.sGiftCodeCmd_Result)
        if npack == nil then return end
        LDataPack.writeByte(npack, ret)
        LDataPack.flush(npack)
        return
    end
    postCodeCheck(code, LActor.getActorId(actor), id, LActor.getPf(actor), LActor.getAppid(actor))
end


netmsgdispatcher.reg(Protocol.CMD_Gift, Protocol.cGiftCodeCmd_GetGift, onGetGift)
