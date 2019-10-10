--�ر����ð��
module("richmansystem", package.seeall)

--[[��������
1.��ȡ����
  param:{{type=0,id=1,count=1},...}, ��������һ��
  exparam:{[Ȧ��]={type=0,id=1,count=1},...},��ָ��Ȧ,�̶��Ľ���
2.ȫ���������(�������)
  param:{{type=0,id=1,count=1},...}, ��������һ��
  exparam: Ϊ��
3.������
  param: 10, ���͵��ĸ���λ��
  exparam: Ϊ��
4.��������
  param: 1,���Ӹ���
  exparam:Ϊ��
]]
local ActionType = {
	GetAward = 1,
	AllRandAward = 2,
	MoveTo = 3,
	GetTouzi = 4,
}

--[[������ݶ���
data={
	diceNum = 0 --���ӵĸ���
	gridData = { --����������ݱ���
		[����λ��]=�����������,-1��ʾ���й�
	},
	curIdx = 1,��ǰ���ڵĸ���,��ס:ȱʡֵ�� 1
	round=0,--�Ѿ�����ڼ�Ȧ,��һ���Ǵ�0��ʼ����
	randAward = {grid=����λ��,idx=�ڼ�������} --�����Ȧ����������2
	roundAward = 0, --��λ�洢��Ȧ�����������Ƿ���ȡ
}
]]
--��ȡ��̬����
local function getData(actor)
	local data = LActor.getStaticVar(actor)
	if nil == data then return nil end
	if nil == data.richmansystem then data.richmansystem = {} end
	return data.richmansystem
end

--�ⲿ�ı����������Ľӿ�
function changeTouZi(actor, num)
	local var = getData(actor)
	var.diceNum = (var.diceNum or 0) + num
	
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_RichMan, Protocol.sRichManCmd_UpdateTouzi)
	--�����������
	LDataPack.writeShort(npack, var.diceNum)
	LDataPack.writeShort(npack, var.round or 0) --�ڼ�Ȧ
	LDataPack.writeInt(npack, var.roundAward or 0)
	LDataPack.flush(npack)
end
_G.changeTouZi = changeTouZi

--ˢ�¸����������
local function refreshGridData(actor)
	local var = getData(actor)
	var.gridData = {}
	for index,cfg in ipairs(RichManGridConfig) do
		if cfg.action == ActionType.GetAward then
			var.gridData[index] = math.random(1,#(cfg.param))
		end
	end
	var.randAward = nil
end

local actionFunc = {}
actionFunc[ActionType.GetAward] = function(actor, var, cfg)
	if var.gridData[var.curIdx or 1] == -1 then
		return
	end
	local award = nil
	if cfg.exparam and cfg.exparam[var.round or 0] then --���жϵ�ǰȦ�Ƿ�Ҫ���⽱��
		award = cfg.exparam[var.round or 0]
	elseif var.randAward then--����ж��Ƿ���Ҫȫ�̽���
		award = RichManGridConfig[var.randAward.grid].param[var.randAward.idx]
	else
		award = cfg.param[var.gridData[var.curIdx or 1]]
	end
	LActor.giveAwards(actor, {award} , "richman")
	var.gridData[var.curIdx or 1] = -1
end

actionFunc[ActionType.AllRandAward] = function(actor, var, cfg)
	if var.gridData[var.curIdx or 1] == -1 then
		return
	end
	--���ԭ���Ѿ������������
	if var.randAward then
		local award = RichManGridConfig[var.randAward.grid].param[var.randAward.idx]
		LActor.giveAwards(actor, {award} , "richman")
		return
	end
	local idx = math.random(1, #(cfg.param))
	if not var.randAward then var.randAward = {} end
	var.randAward.grid = var.curIdx
	var.randAward.idx = idx
	var.gridData[var.curIdx or 1] = -1
	--֪ͨ�������
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_RichMan, Protocol.sRichManCmd_AllRand)
	--�����������
	LDataPack.writeShort(npack, var.randAward and var.randAward.grid or 0)
	LDataPack.writeByte(npack, var.randAward and var.randAward.idx or 0)
	LDataPack.flush(npack)	
end

actionFunc[ActionType.MoveTo] = function(actor, var, cfg)
	var.curIdx = tonumber(cfg.param)
end

actionFunc[ActionType.GetTouzi] = function(actor, var, cfg)
	if var.gridData[var.curIdx or 1] == -1 then
		return
	end
	changeTouZi(actor, tonumber(cfg.param))
	var.gridData[var.curIdx or 1] = -1
end

--ִ�е�ǰ���Ӷ���
local function DoAction(actor)
	local var = getData(actor)
	--��ȡ��ǰ���ӵ�����
	local cfg = RichManGridConfig[var.curIdx or 1]
	if not cfg then
		print(LActor.getActorId(actor).." richmansystem.DoAction not cfg, id:"..tostring(var.curIdx or 1))
		return
	end
	--��������
	local func = actionFunc[cfg.action]
	if not func then
		print(LActor.getActorId(actor).." richmansystem.DoAction not action, action:"..tostring(cfg.action))
		return
	end
	return func(actor, var, cfg)
end

--�����ȡ��������
local function reqGetInfo(actor, packet)
	local var = getData(actor)
	if not var.gridData then 
	--��һ��Ϊnil,��Ҫ��ʼ��
		refreshGridData(actor)
	end
	
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_RichMan, Protocol.sRichManCmd_Info)
	LDataPack.writeShort(npack, var.diceNum or 0) --���ӵĸ���
	LDataPack.writeShort(npack, var.curIdx or 1) --��ǰ����λ��
	LDataPack.writeShort(npack, var.round or 0) --�ڼ�Ȧ
	LDataPack.writeInt(npack, var.roundAward or 0)
	--�����������
	LDataPack.writeShort(npack, var.randAward and var.randAward.grid or 0)
	LDataPack.writeByte(npack, var.randAward and var.randAward.idx or 0)
	--���̵�����
	LDataPack.writeShort(npack, #RichManGridConfig)
	for index,cfg in ipairs(RichManGridConfig) do
		LDataPack.writeShort(npack, var.gridData[index] or 0)
	end
	LDataPack.flush(npack)
end

--����ҡ����
local function reqTurnStep(actor, packet)
	local var = getData(actor)
	--�������
	if (var.diceNum or 0) <= 0 then
		--����Ԫ��
		if RichManBaseConfig.dicePrice > LActor.getCurrency(actor, NumericType_YuanBao) then
			print(LActor.getActorId(actor).." richmansystem.reqTurnStep yuanbao insufficient")
			return
		end
		LActor.changeYuanBao(actor, 0-(RichManBaseConfig.dicePrice), "richman")
	else
		--��������
		changeTouZi(actor, -1)
	end
	--ҡ��������
	local rand = math.random(1,6)
	--���㵱ǰ�ߵ��ĸ���
	var.curIdx = (var.curIdx or 1) + rand
	--�ж��Ƿ������
	local isAs = 0
	if var.curIdx > #(RichManGridConfig) then
		--��Ȧ��; Ҫˢ�¸�������
		refreshGridData(actor)
		--Ȧ����һ
		var.round = (var.round or 0) + 1
		actorevent.onEvent(actor, aeRichManCircle, 1)
		--�������µ�λ��
		var.curIdx = var.curIdx - #(RichManGridConfig)
		--��Ȧ,������
		changeTouZi(actor, RichManBaseConfig.kqDice or 0)
		--�·���������
		reqGetInfo(actor, nil)
		isAs = 1
	end
	--�����������Ķ���
	DoAction(actor)
	--��Ӧ�ͻ���
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_RichMan, Protocol.sRichManCmd_TurnStep)
	LDataPack.writeByte(npack, isAs) --�Ƿ��Խ�����
	LDataPack.writeShort(npack, var.curIdx or 1) --��ǰ����λ��
	LDataPack.writeByte(npack, rand) --ҡ���ĵ���
	LDataPack.flush(npack)
end

--������ȡȦ������
local function reqGetRoundAward(actor, packet)
	local idx = LDataPack.readByte(packet)
	--��ȡ����
	local cfg = RichManRoundAwardConfig[idx]
	if not cfg then
		print(LActor.getActorId(actor).." richmansystem.reqGetRoundAward cfg is nil, idx:"..idx)
		return
	end
	local var = getData(actor)
	--�ж�Ȧ���Ƿ�����
	if (cfg.round or 0) > (var.round or 0) then
		print(LActor.getActorId(actor).." richmansystem.reqGetRoundAward cfg.round:"..tostring(cfg.round).." > var.round:"..tostring(var.round))
		return
	end
	--�ж��Ƿ��Ѿ���ȡ
	if System.bitOPMask(var.roundAward or 0, idx) then
		print(LActor.getActorId(actor).." richmansystem.reqGetRoundAward is received, idx:"..idx)
		return
	end
	--��ý���
	LActor.giveAwards(actor, cfg.award, "richman round")
	--���Ϊ����ȡ
	var.roundAward = System.bitOpSetMask((var.roundAward or 0), idx, true)
	--��Ӧ�ͻ���
	local npack =  LDataPack.allocPacket(actor, Protocol.CMD_RichMan, Protocol.sRichManCmd_RoundAward)
	LDataPack.writeByte(npack, idx)
	LDataPack.writeInt(npack, var.roundAward)
	LDataPack.flush(npack)
end

--�������δ��Ľ���,ͨ���ʼ�����
local function checkAllNotReceivedAwardToMail(actor)
	local var = getData(actor)
	local awards = {}
	for idx, cfg in pairs(RichManRoundAwardConfig) do
		if not System.bitOPMask(var.roundAward or 0, idx) and (cfg.round or 0) <= (var.round or 0) then
			for _,v in ipairs(cfg.award) do
				table.insert(awards, v)
			end
		end
	end
	if #awards <= 0 then return end
	--�����ʼ�
	local mailData = {
		head=RichManBaseConfig.mailHead, 
		context=RichManBaseConfig.mailContent,
		tAwardList=awards
	}
	mailsystem.sendMailById(LActor.getActorId(actor), mailData)
end

--��½��ʱ��
local function onLogin(actor)
	local var = getData(actor)
	if not var.gridData then 
	--��һ��Ϊnil,��Ҫ��ʼ��
		refreshGridData(actor)
	end
	changeTouZi(actor, 0)
end

--�µ�һ��ص�
local function onNewDay(actor)
	local var = getData(actor)
	checkAllNotReceivedAwardToMail(actor)
	refreshGridData(actor) --����ȫ����ʼ��
	var.roundAward = nil
	var.round = nil
	var.curIdx = nil
	var.diceNum = RichManBaseConfig.diceNum
end

--��ʼ��ȫ������
local function initGlobalData()
	actorevent.reg(aeUserLogin, onLogin)
	actorevent.reg(aeNewDayArrive, onNewDay)
	
	netmsgdispatcher.reg(Protocol.CMD_RichMan, Protocol.cRichManCmd_ReqGetInfo, reqGetInfo) --�����ȡ��������
	netmsgdispatcher.reg(Protocol.CMD_RichMan, Protocol.cRichManCmd_ReqTurnStep, reqTurnStep) --����ҡ����
	netmsgdispatcher.reg(Protocol.CMD_RichMan, Protocol.cRichManCmd_ReqGetRoundAward, reqGetRoundAward) --������ȡȦ������
end

table.insert(InitFnTable, initGlobalData)

--rich
function gmHandle(actor, arg)
	local param = arg[1]
	if param == "add" then
		changeTouZi(actor, 1)
	else
		reqTurnStep(actor, nil)
	end
end

