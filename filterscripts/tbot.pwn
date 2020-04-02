// TBot for moviemaking by Troner (v2)
// based on Kurence In-Game NPC editor(knpc)
//

#include <a_samp>
#include <filemanager.inc>

#define MAX_BOTS 50
#define TBOT_STR_ID TBot%d


/*
TODO
enum BOT_STRUCT{
	playerid,
	car,
	skin,
	single,
	...
}

new bots[MAX_BOTS][BOT_STRUCT];

bots[botId][] = {27,520,240,false,...};

*/

new bots[MAX_BOTS];//bots absolute id (-1 if not connected)
new botCar[MAX_BOTS];
new botSkin[MAX_BOTS];
new Text3D:botNicks[MAX_BOTS];
new isNicksSee = false;
new isSingle[MAX_BOTS] = false;//is single shot or repeating
new isBotRecording[MAX_BOTS] = false;//for confict recordings
new botThatPlayerRecording[MAX_PLAYERS];//idBot
new isPlayerRecording[MAX_PLAYERS];//0-none,1-car,2-foot
new timerId;

forward refresh();

initCreateCfgIfNotExist(){
 	for(new i=0;i<MAX_BOTS;i++){
		new filename[64],scriptname[32];
		format(filename,sizeof(filename),"tbotcar%d.cfg",i);
		format(scriptname,sizeof(scriptname),"scriptfiles/tbotcar%d.cfg",i);
		if(!fexist(filename)) file_create(scriptname);
		format(filename,sizeof(filename),"tbotskin%d.cfg",i);
		format(scriptname,sizeof(scriptname),"scriptfiles/tbotskin%d.cfg",i);
		if(!fexist(filename)) file_create(scriptname);
	}
}

initCreateBotsFromCfg(){
    for(new i=0;i<MAX_BOTS;i++){
		new filename[64],nickname[32],scriptname[32];
		format(filename,sizeof(filename),"tbotcar%d.cfg",i);
		new File:fileHandler = fopen(filename, io_read);
		new value[32];
	    fread(fileHandler,value);
	    fclose(fileHandler);
	    botCar[i] = strval(value);

	    format(filename,sizeof(filename),"tbotskin%d.cfg",i);
		fileHandler=fopen(filename, io_read);
	    fread(fileHandler,value);
	    fclose(fileHandler);
	    botSkin[i]=strval(value);

		format(filename,sizeof(filename),"npcmodes/recordings/tbotcar%d.rec",i);
		format(nickname,sizeof(nickname),#TBOT_STR_ID,i);
		format(scriptname,sizeof(scriptname),"tbotcar%d",i);
		if(file_exists(filename)) ConnectNPC(nickname,scriptname);
	    format(filename,sizeof(filename),"npcmodes/recordings/tbotfoot%d.rec",i);
	    format(scriptname,sizeof(scriptname),"tbotfoot%d",i);
		if(file_exists(filename)) ConnectNPC(nickname,scriptname);
	}
}

tb_IsRecCorrect(playerid,botId,isHaveArg){
	if(!isHaveArg || botId>=MAX_BOTS || botId<0) {
		SendClientMessage(playerid,0xFF000000,"Использование: /tbot [ID] - 0-49");
		return 0;
	}
	if(isBotRecording[botId]){
		SendClientMessage(playerid,0xFF000000,"Кто-то уже записывает бота с таким ID!");
		return 0;
	}
	return 1;
}

tb_StartRecord(playerid,botId,playerState){

	new debugMessage[32];
	format(debugMessage,sizeof(debugMessage),"Создаю бота №%d",botId);
	SendClientMessage(playerid,0xFF000000,debugMessage);

	botThatPlayerRecording[playerid] = botId;
	botSkin[botId] = GetPlayerSkin(playerid);
	isPlayerRecording[playerid] = playerState == PLAYER_STATE_DRIVER ? PLAYER_RECORDING_TYPE_DRIVER : PLAYER_RECORDING_TYPE_ONFOOT;
	isBotRecording[botId] = true;

	new recFile[16];
	if(playerState == PLAYER_STATE_ONFOOT){
		botCar[botId] = 0;
		format(recFile,sizeof(recFile),"tbotfoot%d",botId);
		StartRecordingPlayerData(playerid,PLAYER_RECORDING_TYPE_ONFOOT,recFile);
	} else if (playerState == PLAYER_STATE_DRIVER){
		botCar[botId] = GetPlayerVehicleID(playerid);
        format(recFile,sizeof(recFile),"tbotcar%d",botId);
		StartRecordingPlayerData(playerid,PLAYER_RECORDING_TYPE_DRIVER,recFile);

		new carFilename[48];
		format(carFilename,sizeof(carFilename),"tbotcar%d.cfg",botId);
		new File:carFile = fopen(carFilename,io_write);
		new carId[16];
		format(carId,sizeof(carId),"%d",botCar[botId]);
		fwrite(carFile,carId);
		fclose(carFile);
	}

	new skinFilename[32];
	format(skinFilename,sizeof(skinFilename),"tbotskin%d.cfg",botId);

	new File: skinFile = fopen(skinFilename,io_write);
	new skinId[4];
	format(skinId,sizeof(skinId),"%d",botSkin[botId]);
	fwrite(skinFile,skinId);
	fclose(skinFile);

	if(bots[botId] != -1) Kick(bots[botId]);
}

tb_StopRecord(playerid,botId,playerState){
	StopRecordingPlayerData(playerid);
	new botScript[32];
	new botName[10];
	format(botName,sizeof(botName),#TBOT_STR_ID,botId);

	new toDelete[64];
	format(toDelete,sizeof(toDelete),"npcmodes/recordings/tbotfoot%d.rec",botId);
	file_delete(toDelete);
	format(toDelete,sizeof(toDelete),"npcmodes/recordings/tbotcar%d.rec",botId);
	file_delete(toDelete);
	format(toDelete,sizeof(toDelete),"npcmodes/recordings/tbotfootsingle%d.rec",botId);
	file_delete(toDelete);
	format(toDelete,sizeof(toDelete),"npcmodes/recordings/tbotcarsingle%d.rec",botId);
	file_delete(toDelete);

	new scriptToMove1[64],scriptToMove2[64];
	if(playerState == PLAYER_STATE_ONFOOT){
		format(scriptToMove1,sizeof(scriptToMove1),"scriptfiles/tbotfoot%d.rec",botId);
		format(scriptToMove2,sizeof(scriptToMove2),"npcmodes/recordings/tbotfoot%d.rec",botId);
		file_move(scriptToMove1,scriptToMove2);

		format(botScript,sizeof(botScript),"tbotfoot%d",botId);
		ConnectNPC(botName,botScript);
	} else if (playerState == PLAYER_STATE_DRIVER){
        format(scriptToMove1,sizeof(scriptToMove1),"scriptfiles/tbotcar%d.rec",botId);
		format(scriptToMove2,sizeof(scriptToMove2),"npcmodes/recordings/tbotcar%d.rec",botId);
		file_move(scriptToMove1,scriptToMove2);

		format(botScript,sizeof(botScript),"tbotcar%d",botId);
		ConnectNPC(botName,botScript);
		//???????? put in car here? but it must call when bot connects to server
	}

	botThatPlayerRecording[playerid] = -1;

	isPlayerRecording[playerid] = PLAYER_RECORDING_TYPE_NONE;

	isSingle[botId] = false;//???????????????????HERE?OR IN OTHER PLACE

	isBotRecording[botId] = false;
}

tb_AttachBotNick(botId){
	new botNick[24];
	format(botNick,sizeof(botNick),#TBOT_STR_ID,botId);
	botNicks[botId] = Create3DTextLabel(botNick,0x28BA9AFF,0,0,0,200,-1,0);
	Attach3DTextLabelToPlayer(botNicks[botId],bots[botId],0,0,0.3);
}

tb_SendHelp(playerid){
    SendClientMessage(playerid,0xFF000000,"Боты для машиним by Troner");
	SendClientMessage(playerid,0x00FF0000,"Комманды:");
	SendClientMessage(playerid,0x00FF0000,"/tbot [ID 0-49] - начало/конец записи бота (бесконечное повторение)");
	SendClientMessage(playerid,0x00FF0000,"/tsingle [ID 0-49] - ");
	SendClientMessage(playerid,0x00FF0000,"/tstart [ID 0-49] - ");
	SendClientMessage(playerid,0x00FF0000,"/trs [ID 0-49] - ");
	SendClientMessage(playerid,0x00FF0000,"/tlist - ");
	SendClientMessage(playerid,0x00FF0000,"/tdel [ID 0-49] - удалить бота по id или /tdel all - удалить всех");
	SendClientMessage(playerid,0x00FF0000,"/tnicks - ");
	SendClientMessage(playerid,0x00FF0000,"/tgroup [group ID] - ");
	SendClientMessage(playerid,0x00FF0000,"/tgplay [group ID] - ");
	return 1;
}


public OnPlayerCommandText(playerid, cmdtext[])
{
	new cmd[64], idx;
	cmd = strtok(cmdtext,idx);
	if ( !strcmp("/thelp",cmdtext) ){
		tb_SendHelp(playerid);
		return 1;

	} else if ( !strcmp("/tbot",cmd) ){
		new botIdStr[32];
		botIdStr = strtok(cmdtext,idx);
	    new isHaveArg = strlen(botIdStr);
	    new botId = strval(botIdStr);

		if(isPlayerRecording[playerid] == PLAYER_RECORDING_TYPE_NONE){
			//старт записи бота
			if(tb_IsRecCorrect(playerid,botId,isHaveArg)){
				isSingle[botId] = false;
				tb_StartRecord(playerid,botId,GetPlayerState(playerid));
			}
		} else {
			tb_StopRecord(playerid,botId,GetPlayerState(playerid));
		}
		return 1;
	} else if ( !strcmp("/tdel",cmd) ){
        new botIdStr[32];
		botIdStr = strtok(cmdtext,idx);
		if( !strlen(botIdStr) ){
            SendClientMessage(playerid,0xFF000000,"Использование: /tremove [ID] - диапазон 0-49 или /tremove all");
			return 1;
		}
		if( !strcmp("all",botIdStr,false,3) ){
            SendClientMessage(playerid,0xFF000000,"Удаляем всех ботов");
            for(new i = 0;i<MAX_BOTS;i++){
				if(bots[i] != -1){
					Kick(bots[i]);
					bots[i] = -1;
				}
			}
			return 1;
		}
		new botId = strval(botIdStr);

		if((botId >=MAX_BOTS || botId < 0) ){
            SendClientMessage(playerid,0xFF000000,"Неверный диапазон! Использование: /tremove [ID] - диапазон 0-49 или /tremove all");
			return 1;
		}

		if(bots[botId] != -1){
			Kick(bots[botId]);
			bots[botId] = -1;
		}
		return 1;
	}
	return 0;
}

public OnFilterScriptInit(){
	print("\n--------------------------------------");
	print("            Troner bots loaded          ");
	print("--------------------------------------\n");
	for(new i = 0;i<MAX_BOTS;i++){
	    bots[i] = -1;
	    botCar[i] = 0;
	}
	for(new i = 0;i<MAX_PLAYERS;i++){
        botThatPlayerRecording[i] = -1;
        isPlayerRecording[i] = PLAYER_RECORDING_TYPE_NONE;
 	}

	initCreateCfgIfNotExist();
	initCreateBotsFromCfg();
	timerId = SetTimer("refresh",1000,1);

	return 1;
}

public OnFilterScriptExit(){
	print("\n--------------------------------------");
	print("          Troner bots unloaded          ");
	print("--------------------------------------\n");
	KillTimer(timerId);
	for(new i = 0;i<MAX_BOTS;i++){
		if(bots[i] != -1)Kick(bots[i]);
	}
	return 1;
}

public OnPlayerConnect(playerid){
	if(IsPlayerNPC(playerid)) {
		SpawnPlayer(playerid);
        new botName[24];
		GetPlayerName(playerid,botName,sizeof(botName));
		if(!strcmp("TBot",botName,false,4)){

			new nameSplit[24][2];
			split(botName,nameSplit,'t');
			new botId = strval(nameSplit[1]);

			bots[botId] = playerid;

			if(isNicksSee == 1){
				tb_AttachBotNick(botId);
			}
			if(GetVehicleModel(botCar[botId]) != 0 ){
				PutPlayerInVehicle(playerid,botCar[botId],0);
			}
		}
	} else {
		isPlayerRecording[playerid] = PLAYER_RECORDING_TYPE_NONE;
		isBotRecording[botThatPlayerRecording[playerid]] = false;
		botThatPlayerRecording[playerid] = -1;
	}
	return 1;
}


//TODO public OnPlayerEnterVehicle(playerid,vehicleid){}
//TODO public OnPlayerStateChange(playerid,newstate,oldstate){}

public OnPlayerDisconnect(playerid,reason){
	new botName[32];
	GetPlayerName(playerid,botName,sizeof(botName));
	if(!strcmp("TBot",botName,false,4) && IsPlayerNPC(playerid)){
        new nameSplit[24][2];
		split(botName,nameSplit,'t');
		new botId = strval(nameSplit[1]);
		for(new i = 0;i<MAX_PLAYERS;i++){
			if(bots[botId] == playerid){
				if(isNicksSee==1){
					Delete3DTextLabel(botNicks[i]);
				}
				bots[botId] = -1;
				break;
			}
		}
	}
	if(isPlayerRecording[playerid] != PLAYER_RECORDING_TYPE_NONE){
		StopRecordingPlayerData(playerid);
		isPlayerRecording[playerid] = PLAYER_RECORDING_TYPE_NONE;
		isBotRecording[botThatPlayerRecording[playerid]] = false;
		botThatPlayerRecording[playerid] = -1;
	}
}

public refresh(){
	for(new i = 0; i < MAX_BOTS;i++){
	    if(bots[i] != -1){
			if(GetPlayerSkin(bots[i]) != botSkin[i]){
				SetPlayerSkin(bots[i],botSkin[i]);
			}
		}
	}
}

strtok(const string[], &index)
{
	new length = strlen(string);
	while ((index < length) && (string[index] <= ' '))
	{
		index++;
	}

	new offset = index;
	new result[20];
	while ((index < length) && (string[index] > ' ') && ((index - offset) < (sizeof(result) - 1)))
	{
		result[index - offset] = string[index];
		index++;
	}
	result[index - offset] = EOS;
	return result;
}
stock split(const strsrc[], strdest[][], delimiter)
{
    new i, li;
    new aNum;
    new len;
    while(i <= strlen(strsrc))
    {
        if(strsrc[i] == delimiter || i == strlen(strsrc))
        {
            len = strmid(strdest[aNum], strsrc, li, i, 128);
            strdest[aNum][len] = 0;
            li = i+1;
            aNum++;
        }
        i++;
    }
    return 1;
}
