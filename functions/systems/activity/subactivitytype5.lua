--第5类子活动
--累积登陆活动
module("subactivitytype5", package.seeall)

local subType = 5
local prot = Protocol

--检查是否投资
function checkISInvest(actor, id)
    print("checkISInvest")
    local var = activitysystem.getSubVar(actor,id)
    --table.print(var)
    print(var.investStatus)
    if var.investStatus == 0 or var.investStatus == nil then
        print("false")
        return false
    else
        print("true")
        return true
    end        
end

--投资
function investment(actor, id)
    print("investment")
    local var = activitysystem.getSubVar(actor,id)
    var.investStatus = true
    local investStatus = 0
    if(var.investStatus) then
        investStatus = 1
    end
    local npack = LDataPack.allocPacket(actor, Protocol.CMD_Activity, 31)
    LDataPack.writeInt(npack, investStatus)
    LDataPack.flush(npack)
end


function loginLogin(actor, id)
    local var = activitysystem.getSubVar(actor, id)
    if var.loginTime == nil then var.loginTime = 0 end
    if var.days == nil then var.days = 0 end
    local now_t = System.getNowTime()
    if not System.isSameDay(var.loginTime, now_t) then
        var.days = var.days + 1
        var.loginTime = now_t
    end

    --检查是否投资
    local investStatus = checkISInvest(actor,id)
    if var.investStatus == nil then var.investStatus = 0 end
    if(investStatus) then
        var.investStatus = 1
    end

    local npack = LDataPack.allocPacket(actor, prot.CMD_Activity, prot.sActivityCmd_SendLoginDaysData)
    LDataPack.writeInt(npack, id)
    LDataPack.writeInt(npack, var.days or 0)
    LDataPack.flush(npack)

    if id==1005 then
        local npack1 = LDataPack.allocPacket(actor, Protocol.CMD_Activity, 31)
        LDataPack.writeInt(npack1, var.investStatus or 0)
        LDataPack.flush(npack1)
    end


end

--下发记录信息
local function writeRecord(npack, record, conf)
    if npack == nil then return end
    local v = record and record.rewardsRecord or 0
    LDataPack.writeInt(npack, v)
end

--领奖协议回调
subactivities.getRewardFuncs[subType] = function(id, typeconfig, actor, record, packet)
    print("getRewardFuncs")
    print("subType "..subType)
    print("id "..id)
    if id==1005 then
        if checkISInvest(actor,id)==false then
            LActor.sendTipWithId(actor, 8)
            return
        end
    end
    local idx = LDataPack.readShort(packet)
    local conf = typeconfig[id]
    if conf == nil then return end
    if conf[idx] == nil then return end

    if record == nil then return end
    local days = record.days or 0

    if record.rewardsRecord == nil then record.rewardsRecord = 0 end
    --是否已领
    if days < conf[idx].day then return end
    if System.bitOPMask(record.rewardsRecord, idx) then return end
    if LActor.canGiveAwards(actor, conf[idx].rewards) then

        record.rewardsRecord = System.bitOpSetMask(record.rewardsRecord, idx, true)
        LActor.giveAwards(actor, conf[idx].rewards, "activity type5 rewards")

        local npack = LDataPack.allocPacket(actor, prot.CMD_Activity, prot.sActivityCmd_GetRewardResult)
        LDataPack.writeByte(npack, 1)
        LDataPack.writeInt(npack, id)
        LDataPack.writeShort(npack, idx)
        LDataPack.writeInt(npack, record.rewardsRecord or 0)
        LDataPack.flush(npack)
    else
        LActor.sendTipWithId(actor, 1)
    end
end

--玩家登陆回调（在发送所有活动的基础信息(协议25-1)之后）
subactivities.actorLoginFuncs[subType] = function(actor, type, id)
    if activitysystem.activityTimeIsEnd(id) then return end
    loginLogin(actor, id)
end

local function onNewDayLogin(id, conf)
    return function(actor)
        if activitysystem.activityTimeIsEnd(id) then return end

        loginLogin(actor, id)
    end
end

local function initFunc(id, conf)
	actorevent.reg(aeNewDayArrive, onNewDayLogin(id, conf))
end

--注册一类活动配置
subactivities.regConf(subType, ActivityType5Config)
subactivities.regInitFunc(subType, initFunc)
subactivities.regWriteRecordFunc(subType, writeRecord)

