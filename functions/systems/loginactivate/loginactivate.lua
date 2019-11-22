--开服激活角色奖励
module("loginactivate",package.seeall)


--[[
--个人数据
loginActivateData = {
	status  1表示可以参与领取奖励，0不满足条件
	loginDays  登陆天数，创角开始算
	reward 0未领取，1领取过
}
]]


--获取玩家信息
local function getStaticData(actor)
	local var = LActor.getStaticVar(actor)
	if nil == var.loginActivateData then var.loginActivateData = {} end

	return var.loginActivateData
end

local function sendData(actor)
	local data = getStaticData(actor)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_RoleActivate, Protocol.sRoleActivateCMD_Info)

	LDataPack.writeByte(npack, data.reward or 0)
	LDataPack.writeShort(npack, data.loginDays or 0)
	LDataPack.writeByte(npack, data.status or 0)

	LDataPack.flush(npack)
end

local function getReward(actor)
	local data = getStaticData(actor)
	local actorId = LActor.getActorId(actor)
	-- 赠送VIP20
	LActor.setVipLevel(actor, 20)
	local npack = LDataPack.allocPacket(actor, Protocol.CMD_Vip, Protocol.sVipCmd_UpdateExp)
    LDataPack.writeShort(npack, 20)
    LDataPack.writeInt(npack, 0)
    LDataPack.writeShort(npack, 0)
    LDataPack.flush(npack)
    -- 赠送物品
	local mail_data = {}
	mail_data.head = '新人礼包'
	mail_data.context = '上线就送:VIP20,99999元宝,100000000金币!!'
	mail_data.tAwardList = {{type=0,id=1,count=100000000},{type=0,id=2,count=99999}}
	mailsystem.sendMailById(LActor.getActorId(actor),mail_data)
	data.reward = 1
	sendData(actor)
	return true
end

local function onGetReward(actor)
	local isReward = getReward(actor)

	local npack = LDataPack.allocPacket(actor, Protocol.CMD_RoleActivate, Protocol.sRoleActivateCMD_Reward)
	LDataPack.writeByte(npack, isReward and 1 or 0)
	LDataPack.flush(npack)
end
local function onLogin(actor)
	local data = getStaticData(actor)
	print(data.reward)
	if(data.reward==nil) then
		onGetReward(actor)
	end
end


local function initGlobalData()

	actorevent.reg(aeUserLogin, onLogin)

end

table.insert(InitFnTable, initGlobalData)

