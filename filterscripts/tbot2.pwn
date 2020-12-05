// TBot for moviemaking by Troner (v2)
// based on Kurence In-Game NPC editor(knpc)
//

#include <a_samp>
#include <filemanager.inc>

#define MAX_BOTS 50
#define TBOT_STR_ID TBot%d


enum TBOT_STRUCT{
	E_playerid,//it means bot id in game, -1 bot doesn't exists
	E_groupId,
	E_nickname[32],
	Text3D:E_textNick,//0 if not shown
	E_skin,
	E_car,//-1 - on foot
	bool:E_isSingle,//
	bool:E_isRecording,
};
new bots[MAX_BOTS][TBOT_STRUCT];//bots absolute id (-1 if not connected)

enum TPLAYER_STRUCT{
	E_plgroupid,
	E_botId,//-1 if not recording
	E_playerRecType,
};

new tplayers[MAX_PLAYERS][TPLAYER_STRUCT];

/*
bots[botId][] = {27,520,240,false,...};

*/

// TODO chains - https://wiki.sa-mp.com/wiki/NPC:OnPlayerText

new botChain[MAX_BOTS]; // Work in progress


//new botGroup[MAX_BOTS];

//new botCar[MAX_BOTS];
//new botSkin[MAX_BOTS];
//new Text3D:botNicks[MAX_BOTS];
new isNicksSee = false;
//new isSingle[MAX_BOTS];//is single shot or repeating
//new isBotRecording[MAX_BOTS];//for confict recordings
//new playerGroup[MAX_PLAYERS];
//new botThatPlayerRecording[MAX_PLAYERS];//idBot
//new isPlayerRecording[MAX_PLAYERS];//0-none,1-car,2-foot
new timerId;

forward refresh();

tb_NotSingleDestructor(i){
//TODO fully del
/*
  		if(bots[i][E_car] != -1){
			new filename[128];
			format(filename,sizeof(filename),"npcmodes/recordings/tbotcar%d.rec",i);
			if(file_exists(filename)){
				file_delete(filename);
			}
		} else {
  			new filename[128];
			format(filename,sizeof(filename),"npcmodes/recordings/tbotfoot%d.rec",i);
			if(file_exists(filename)){
				file_delete(filename);
			}
		}
		*/
		bots[i][E_playerid] = -1;
		bots[i][E_groupId] = -1;
		bots[i][E_nickname] = 0;
		bots[i][E_skin] = -1;
	    bots[i][E_car] = -1;
	    bots[i][E_isSingle] = false;
	    bots[i][E_isRecording] = false;
}

initCreateCfgIfNotExist(){
 	for(new i=0;i<MAX_BOTS;i++){
		new filename[64];
		format(filename,sizeof(filename),"scriptfiles/tbotcar%d.cfg",i);
  		if(!file_exists(filename)){
  			file_create(filename);
		}
		format(filename,sizeof(filename),"scriptfiles/tbotskin%d.cfg",i);
		if(!file_exists(filename)){
			file_create(filename);
		}
	}
}

initCreateBotsFromCfg(){
    for(new i=0;i<MAX_BOTS;i++){
		new filename[128],nickname[32],scriptname[32];
		
		format(filename,sizeof(filename),"scriptfiles/tbotcar%d.cfg",i);
		new File:fileHandler = f_open(filename, "r");
		new value[32];
	    f_read(fileHandler,value);
	    f_close(fileHandler);
		new carId = strval(value);
		if(!carId){
			bots[i][E_car] = -1;
		} else {
			bots[i][E_car] = carId;
		}
		
		new tbotsingleFile[128];
		format(tbotsingleFile,sizeof(tbotsingleFile),"scriptfiles/tbotsingle%d.cfg",i);
		if(file_exists(tbotsingleFile)){
			new grIdStr[16];
			new File:fileSingleHandler = f_open(tbotsingleFile, "r");
			f_read(fileSingleHandler,grIdStr);
		    f_close(fileSingleHandler);
			new groupId = strval(grIdStr);
			bots[i][E_isSingle] = true;
			bots[i][E_groupId] = groupId;
		}

	    format(filename,sizeof(filename),"scriptfiles/tbotskin%d.cfg",i);
		fileHandler=f_open(filename, "r");
	    f_read(fileHandler,value);
	    f_close(fileHandler);

	    bots[i][E_skin]=strval(value);

		format(nickname,sizeof(nickname),#TBOT_STR_ID,i);
		bots[i][E_nickname]=nickname;

		format(filename,sizeof(filename),"npcmodes/recordings/tbotcar%d.rec",i);
		format(scriptname,sizeof(scriptname),"tbotcar%d",i);
		if(file_exists(filename) && !bots[i][E_isSingle]){
			ConnectNPC(nickname,scriptname);
		}
	    format(filename,sizeof(filename),"npcmodes/recordings/tbotfoot%d.rec",i);
	    format(scriptname,sizeof(scriptname),"tbotfoot%d",i);
		if(file_exists(filename) && !bots[i][E_isSingle]){
			ConnectNPC(nickname,scriptname);
		}
	}
}

tb_IsRecCorrect(playerid,botId,isHaveArg){
	if(!isHaveArg || botId>=MAX_BOTS || botId<0) {
		SendClientMessage(playerid,0xFF000000,"Использование: /tbot [ID] - 0-49");
		return 0;
	}
	if(bots[botId][E_isRecording] && tplayers[playerid][E_botId] != botId){
		SendClientMessage(playerid,0xFF000000,"Кто-то уже записывает бота с таким ID!");
		return 0;
	}
	return 1;
}

tb_StartRecord(playerid,botId){
	if(bots[botId][E_playerid] != -1){
		Kick(bots[botId][E_playerid]);
	}
	
	new debugMessage[32];
	format(debugMessage,sizeof(debugMessage),"Создаю бота №%d",botId);
	SendClientMessage(playerid,0xFF000000,debugMessage);

	new playerState = GetPlayerState(playerid);
	tplayers[playerid][E_playerRecType] = playerState == PLAYER_STATE_DRIVER ? PLAYER_RECORDING_TYPE_DRIVER : PLAYER_RECORDING_TYPE_ONFOOT;
	tplayers[playerid][E_botId] = botId;
	bots[botId][E_groupId] = tplayers[playerid][E_plgroupid];
	
	bots[botId][E_isRecording] = true;

	new recFile[16];
	if(playerState == PLAYER_STATE_ONFOOT){
		bots[botId][E_car] = -1;
		format(recFile,sizeof(recFile),"tbotfoot%d",botId);
		StartRecordingPlayerData(playerid,PLAYER_RECORDING_TYPE_ONFOOT,recFile);
	} else if (playerState == PLAYER_STATE_DRIVER){
		bots[botId][E_car] = GetPlayerVehicleID(playerid);

        format(recFile,sizeof(recFile),"tbotcar%d",botId);
		StartRecordingPlayerData(playerid,PLAYER_RECORDING_TYPE_DRIVER,recFile);

		new carFilename[48];
		format(carFilename,sizeof(carFilename),"scriptfiles/tbotcar%d.cfg",botId);
		new File:carFile = f_open(carFilename,"w");
		new carId[16];
		format(carId,sizeof(carId),"%d",bots[botId][E_car]);
		f_write(carFile,carId);
		f_close(carFile);
	}
}

//TODO tfulldel - delete fully tsingle
//TODO tgfulldel - delete fully group of tsingle
tb_StopRecord(playerid,botId){
	new debugMessage[32];
    format(debugMessage,sizeof(debugMessage),"Запись бота окончена №%d",botId);
	SendClientMessage(playerid,0xFF000000,debugMessage);

	StopRecordingPlayerData(playerid);

	new botScript[32];
	new botName[10];
	format(botName,sizeof(botName),#TBOT_STR_ID,botId);
	
	new toDelete[64];
	format(toDelete,sizeof(toDelete),"npcmodes/recordings/tbotfoot%d.rec",botId);
	file_delete(toDelete);
	format(toDelete,sizeof(toDelete),"npcmodes/recordings/tbotcar%d.rec",botId);
	file_delete(toDelete);
	
	if(bots[botId][E_isSingle]){
 	    new singleFile[64];
		format(singleFile,sizeof(singleFile),"scriptfiles/tbotsingle%d.cfg",botId);
		if(file_exists(singleFile)){
			file_delete(singleFile);
		}
		file_create(singleFile);
		new File:fileHandler = f_open(singleFile, "w");
		new grId[16];
		format(grId,sizeof(grId),"%d",bots[botId][E_groupId]);
		f_write(fileHandler,grId);
		f_close(fileHandler);
	}

	new scriptToMove1[64],scriptToMove2[64];

	new playerState = GetPlayerState(playerid);
	if(playerState == PLAYER_STATE_ONFOOT){
		
		format(scriptToMove1,sizeof(scriptToMove1),"scriptfiles/tbotfoot%d.rec",botId);
		format(scriptToMove2,sizeof(scriptToMove2),"npcmodes/recordings/tbotfoot%d.rec",botId);
		file_move(scriptToMove1,scriptToMove2);

		if( !bots[botId][E_isSingle] ){
			format(botScript,sizeof(botScript),"tbotfoot%d",botId);
			ConnectNPC(botName,botScript);
		}
	} else if (playerState == PLAYER_STATE_DRIVER){
		
        format(scriptToMove1,sizeof(scriptToMove1),"scriptfiles/tbotcar%d.rec",botId);
		format(scriptToMove2,sizeof(scriptToMove2),"npcmodes/recordings/tbotcar%d.rec",botId);
		file_move(scriptToMove1,scriptToMove2);
		
        if( !bots[botId][E_isSingle] ){
		  	format(botScript,sizeof(botScript),"tbotcar%d",botId);
			ConnectNPC(botName,botScript);
		}
	}
	bots[botId][E_skin] = GetPlayerSkin(playerid);
	tplayers[playerid][E_botId] = -1;
	tplayers[playerid][E_playerRecType] = PLAYER_RECORDING_TYPE_NONE;
	bots[botId][E_isRecording] = false;
	new skinFilename[32];
	format(skinFilename,sizeof(skinFilename),"scriptfiles/tbotskin%d.cfg",botId);
	new File:skinFile = f_open(skinFilename,"w");
	new skinId[4];
	format(skinId,sizeof(skinId),"%d",bots[botId][E_skin]);
	f_write(skinFile,skinId);
	f_close(skinFile);
}

tb_AttachBotNick(botId){
	new botNick[24];
	format(botNick,sizeof(botNick),#TBOT_STR_ID,botId);
	bots[botId][E_textNick] = Create3DTextLabel(botNick,0x28BA9AFF,0,0,0,200,-1,0);
	Attach3DTextLabelToPlayer(bots[botId][E_textNick],bots[botId][E_playerid],0,0,0.3);
}

tb_SendHelp(playerid){
    SendClientMessage(playerid,0xFF000000,"Боты для машиним by Troner");
	SendClientMessage(playerid,0x00FF0000,"Команды:");
	SendClientMessage(playerid,0x00FF0000,"/tbot [ID 0-49] - начало/конец записи бота (бесконечное повторение)");
	SendClientMessage(playerid,0x00FF0000,"/tsingle [ID 0-49] - записать бота без зацикливания");
	SendClientMessage(playerid,0x00FF0000,"/trs [ID 0-49] - перезапустить бота");
	SendClientMessage(playerid,0x00FF0000,"/tgrs [group ID] - перезапустить группу ботов");
	SendClientMessage(playerid,0x00FF0000,"/tlist - список ботов");
	SendClientMessage(playerid,0x00FF0000,"/tdel [ID 0-49] - удалить бота по id или /tdel all - удалить всех");
	SendClientMessage(playerid,0x00FF0000,"/tnicks - включить ники ботов");
	SendClientMessage(playerid,0x00FF0000,"/tg [group ID] - установить группу");
	SendClientMessage(playerid,0x00FF0000,"/tgdel [group ID] - удалить группу");
	return 1;
}


public OnPlayerCommandText(playerid, cmdtext[])
{
	new cmd[64], idx;
	cmd = strtok(cmdtext,idx);
	if ( !strcmp("/thelp",cmdtext) ){
		tb_SendHelp(playerid);
		return 1;
		
	} else if ( !strcmp("/tlist",cmdtext) ){
		for(new i = 0;i<MAX_BOTS;i++){
			if(bots[i][E_playerid] != -1){
				new botList[128];
				format(botList,sizeof(botList),"TBot%d - ID: %d, GROUP: %d, SKIN_ID: %d, SINGLE: %d",i,bots[i][E_playerid],bots[i][E_groupId],bots[i][E_skin],bots[i][E_isSingle]);
				SendClientMessage(playerid,0x00FF0000,botList);
			} else if(bots[i][E_isSingle]){
    			new filename[64];
				format(filename,sizeof(filename),"scriptfiles/tbotsingle%d.cfg",i);
				if(file_exists(filename)){
					new File:fileHandler = f_open(filename, "r");
					new value[32];
	    			f_read(fileHandler,value);
   					f_close(fileHandler);
					new grId = strval(value);
					new botList[128];
					format(botList,sizeof(botList),"SINGLE %d: GROUP: %d",i,grId);
					SendClientMessage(playerid,0xFF000000,botList);
				}
			}
		}
		return 1;

	} else if ( !strcmp("/tbot",cmd) ){
		new botIdStr[32];
		botIdStr = strtok(cmdtext,idx);
	    new isHaveArg = strlen(botIdStr);
	    new botId = strval(botIdStr);

		if(tplayers[playerid][E_playerRecType] == PLAYER_RECORDING_TYPE_NONE){
			if(tb_IsRecCorrect(playerid,botId,isHaveArg)){
				//bot was single so override him and delete tbotsingle.cfg
				if(bots[botId][E_isSingle]){
					new singleFile[64];
					format(singleFile,sizeof(singleFile),"scriptfiles/tbotsingle%d.cfg",botId);
					if(file_exists(singleFile)){
						file_delete(singleFile);
					}
				}
				bots[botId][E_isSingle] = false;
				tb_StartRecord(playerid,botId);
			}
		} else {
			tb_StopRecord(playerid,botId);
		}
		return 1;
		
	} else if( !strcmp("/tg",cmd)){
	    new groupIdStr[32];
		groupIdStr = strtok(cmdtext,idx);
		new groupMessage[32];
		if(!strlen(groupIdStr)){
			format(groupMessage,sizeof(groupMessage),"Текущая группа №%d",tplayers[playerid][E_plgroupid]);
		} else {
			new groupId = strval(groupIdStr);
			if( groupId < 0 ){
            	SendClientMessage(playerid,0xFF000000,"ID группы должен быть положительным числом");
				return 1;
			}
			tplayers[playerid][E_plgroupid] = groupId;
			format(groupMessage,sizeof(groupMessage),"Установлена группа №%d",groupId);
		}
		SendClientMessage(playerid,0xFF000000,groupMessage);
		return 1;

/* else if( !strcmp("/tgplay",cmd)){
		

		for(new botId = 0;botId<MAX_BOTS;botId++){
		    if(bots[botId][E_groupId] == groupId){
				new botName[16];
				format(botName,sizeof(botName),#TBOT_STR_ID,botId);
				new scriptName[48];
				if(bots[botId][E_car] != -1){
					format(scriptName,sizeof(scriptName),"tbotcarsingle%d",botId);
				} else {
		            format(scriptName,sizeof(scriptName),"tbotfootsingle%d",botId);
				}
				ConnectNPC(botName,scriptName);
			}
		}
		return 1;

	}
*/
	} else if ( !strcmp("/tgrs",cmd) ){
		new groupIdStr[32];
		groupIdStr = strtok(cmdtext,idx);
		new groupId;
		if( !strlen(groupIdStr) ){
            groupId = tplayers[playerid][E_plgroupid];
		} else {
		 	groupId = strval(groupIdStr);
		 	if( groupId < 0 ){
            	SendClientMessage(playerid,0xFF000000,"ID группы должен быть положительным числом");
				return 1;
			}
	 	}
		for(new botId = 0;botId<MAX_BOTS;botId++){
			//skip for regular tbot
			if( ! bots[botId][E_isSingle]){
				continue;
			}
			if(bots[botId][E_groupId] == groupId){
				if(bots[botId][E_playerid] != -1){
					Kick(bots[botId][E_playerid]);
				}
				new scriptName[48];
				if(bots[botId][E_car] != -1){
					format(scriptName,sizeof(scriptName),"tbotcarsingle%d",botId);
				} else {
			    	format(scriptName,sizeof(scriptName),"tbotfootsingle%d",botId);
				}
				new botName[10];
				format(botName,sizeof(botName),#TBOT_STR_ID,botId);
				ConnectNPC(botName,scriptName);
			}
		}
		return 1;

	} else if ( !strcmp("/trs",cmd) ){
		new botIdStr[32];
		botIdStr = strtok(cmdtext,idx);
		if( !strlen(botIdStr) ){
            SendClientMessage(playerid,0xFF000000,"Использование: /trs [ID] - запуск/перезапуск бота записанного коммандой /tsingle");
			return 1;
		}
		new botId = strval(botIdStr);
		if( !bots[botId][E_isSingle] ){
            SendClientMessage(playerid,0xFF000000,"Бот не был записан при помощи /tsingle");
			return 1;
		}
		if(bots[botId][E_playerid] != -1){
			Kick(bots[botId][E_playerid]);
		}
		new scriptName[48];
		if(bots[botId][E_car] != -1){
			format(scriptName,sizeof(scriptName),"tbotcarsingle%d",botId);
		} else {
            format(scriptName,sizeof(scriptName),"tbotfootsingle%d",botId);
		}
		new botName[10];
		format(botName,sizeof(botName),#TBOT_STR_ID,botId);
		ConnectNPC(botName,scriptName);

		return 1;

	} else if ( !strcmp("/tnicks",cmd) ){
		if(isNicksSee == 0){
      		isNicksSee = 1;
			for(new i=0; i<MAX_BOTS;i++){
			    if(bots[i][E_playerid] != -1){
					tb_AttachBotNick(i);
				}
			}
		} else {
			isNicksSee = 0;
			for(new i=0; i<MAX_BOTS;i++){
			    if(bots[i][E_playerid] != -1){
					Delete3DTextLabel(bots[i][E_textNick]);
				}
			}
		}
		return 1;

	//TODO unite with /tgrs
	} else if ( !strcmp("/tsingle",cmd) ){
		new botIdStr[32];
		botIdStr = strtok(cmdtext,idx);
	    new isHaveArg = strlen(botIdStr);
	    new botId = strval(botIdStr);

		if(tplayers[playerid][E_playerRecType] == PLAYER_RECORDING_TYPE_NONE){
			//???
			if(tb_IsRecCorrect(playerid,botId,isHaveArg)){
				bots[botId][E_isSingle] = true;
				tb_StartRecord(playerid,botId);
			}
		} else {
			tb_StopRecord(playerid,botId);
		}
		return 1;

	} else if ( !strcmp("/tgdel",cmd) ){
        new grIdStr[32];
		grIdStr = strtok(cmdtext,idx);
		if( !strlen(grIdStr) ){
            SendClientMessage(playerid,0xFF000000,"Использование: /tgdel [ID группы]");
			return 1;
		}
		new grId = strval(grIdStr);

		if(grId < 0){
			SendClientMessage(playerid,0xFF000000,"ID группы должен быть положительным числом");
			return 1;
		}
	 	for(new i = 0;i<MAX_BOTS;i++){
			if(bots[i][E_groupId] == grId && bots[i][E_playerid] != -1){
				Kick(bots[i][E_playerid]);
			}
  		}
		return 1;
//BOTS ONLY
	} else if ( !strcmp("/tdel",cmd) ){
        new botIdStr[32];
		botIdStr = strtok(cmdtext,idx);
		if( !strlen(botIdStr) ){
            SendClientMessage(playerid,0xFF000000,"Использование: /tdel [ID] - диапазон 0-49 или /tdel all");
			return 1;
		}
		if( !strcmp("all",botIdStr,false,3) ){
            SendClientMessage(playerid,0xFF000000,"Удаляем всех ботов");
            for(new i = 0;i<MAX_BOTS;i++){
				if(bots[i][E_playerid] != -1){
					if(!bots[i][E_isSingle]){
					    if(bots[i][E_car] != -1){
							new filename[128];
							format(filename,sizeof(filename),"npcmodes/recordings/tbotcar%d.rec",i);
							if(file_exists(filename)) file_delete(filename);
						} else {
                            new filename[128];
							format(filename,sizeof(filename),"npcmodes/recordings/tbotfoot%d.rec",i);
							if(file_exists(filename)) file_delete(filename);
						}
					}
					Kick(bots[i][E_playerid]);
				}
			}
			return 1;
		}
		new botId = strval(botIdStr);
		
		if((botId >=MAX_BOTS || botId < 0) ){
			SendClientMessage(playerid,0xFF000000,"Неверный диапазон! Использование: /tdel [ID] - диапазон 0-49 или /tdel all");
			return 1;
		}
		if(bots[botId][E_playerid] != -1){
			Kick(bots[botId][E_playerid]);
		}
		return 1;
//BOTS ONLY
	} else if( !strcmp("/bot_next_chain",cmdtext)){
	/*
		new thisIsBot = false;
		new botId = -1;
		for(new i =0;i<MAX_BOTS;i++){
			if(bots[i] == playerid){
			    botId = i;
                thisIsBot = true;
				break;
			}
		}
		if(!thisIsBot){
		    //player send that command so send him unknown command message
			return 0;
		}
		
		TODO
		new nextBot = botChain[botId];
		???
		ConnectNPC()
		*/
		return 1;
	}
	return 0;
}

public OnFilterScriptInit(){
	print("\n--------------------------------------");
	print("            Troner bots loaded          ");
	print("--------------------------------------\n");
	for(new i = 0;i<MAX_BOTS;i++){
		bots[i][E_playerid] = -1;
		bots[i][E_groupId] = 0;
		bots[i][E_nickname] = 0;
		bots[i][E_skin] = -1;
	    bots[i][E_car] = -1;
	    bots[i][E_isSingle] = false;
	    bots[i][E_isRecording] = false;
	}
	for(new i = 0;i<MAX_PLAYERS;i++){
		tplayers[i][E_plgroupid] = 0;
        tplayers[i][E_botId] = -1;
        tplayers[i][E_playerRecType] = PLAYER_RECORDING_TYPE_NONE;
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
		if(bots[i][E_playerid] != -1)Kick(bots[i][E_playerid]);
	}
	return 1;
}

public OnPlayerConnect(playerid){

	if( IsPlayerNPC(playerid)) {
		SpawnPlayer(playerid);
        new botName[24];
		GetPlayerName(playerid,botName,sizeof(botName));
		if(!strcmp("TBot",botName,false,4)){

			new nameSplit[24][2];
			split(botName,nameSplit,'t');
			new botId = strval(nameSplit[1]);

			bots[botId][E_playerid] = playerid;
			
			if(isNicksSee == 1){
				tb_AttachBotNick(botId);
			}
			if(GetVehicleModel(bots[botId][E_car]) != -1 ){
				PutPlayerInVehicle(playerid,bots[botId][E_car],0);
			}
   			new skinFilename[64];
   			new skinid[24];
			format(skinFilename,sizeof(skinFilename),"scriptfiles/tbotskin%d.cfg",botId);
			new File:fileHandler=f_open(skinFilename, "r");
	    	f_read(fileHandler,skinid);
	    	f_close(fileHandler);
	    	bots[botId][E_skin]=strval(skinid);
		}
	} else {
        tplayers[playerid][E_plgroupid] = 0;
		tplayers[playerid][E_playerRecType] = PLAYER_RECORDING_TYPE_NONE;
		bots[tplayers[playerid][E_botId]][E_isRecording] = false;
		tplayers[playerid][E_botId] = -1;
	}
	return 1;
}

//TODO public OnPlayerEnterVehicle(playerid,vehicleid){}
//TODO public OnPlayerStateChange(playerid,newstate,oldstate){}

public OnPlayerDisconnect(playerid,reason){
	new botName[32];
	GetPlayerName(playerid,botName,sizeof(botName));
	//check if player has nickname Tbot but its not npc
	if(!strcmp("TBot",botName,false,4) && IsPlayerNPC(playerid)){
        new nameSplit[24][2];
		split(botName,nameSplit,'t');
		new botId = strval(nameSplit[1]);
		
		if(bots[botId][E_playerid] == playerid){
			if(isNicksSee==1){
				Delete3DTextLabel(bots[botId][E_textNick]);
			}
			if( ! bots[botId][E_isSingle]){
                tb_NotSingleDestructor(botId);
			}
  		}
	}
	if(tplayers[playerid][E_playerRecType] != PLAYER_RECORDING_TYPE_NONE){
		StopRecordingPlayerData(playerid);
		tplayers[playerid][E_playerRecType] = PLAYER_RECORDING_TYPE_NONE;
		bots[tplayers[playerid][E_botId]][E_isRecording] = false;
		tplayers[playerid][E_botId] = -1;
	}
}

public refresh(){
	for(new i = 0; i < MAX_BOTS;i++){
	    if(bots[i][E_playerid] != -1){
			if(GetPlayerSkin(bots[i][E_playerid]) != bots[i][E_skin]){
				SetPlayerSkin(bots[i][E_playerid],bots[i][E_skin]);
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
