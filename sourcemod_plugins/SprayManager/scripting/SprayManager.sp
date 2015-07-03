#pragma semicolon 1

#include <spraymanager>
#include <sourcemod>
#include <sdktools>

new Handle:cvar_sprayurl;
new Handle:hDatabase = INVALID_HANDLE;

new String:SPRAY_REPLY_PREFIX[20] = "\x01[\x04Spray\x01]";

new SprayIsBlocked[MAXPLAYERS+1];
new Float:SprayLocation[MAXPLAYERS+1][3];
new bool:PlayerUsedSpray[MAXPLAYERS+1];
new ClientTargetUserID[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "Spray Manager",
	author = "Monster Killer",
	description = "Remove, Block and View Sprays",
	version = "1.4.1",
	url = "http://MonsterProjects.org/"
};

public OnPluginStart()
{
	RegAdminCmd("sm_removespray", Command_RemoveSpray, ADMFLAG_KICK, "removespray <name|#id>");
	RegAdminCmd("sm_spray", Command_Spray, ADMFLAG_KICK, "spray");
	RegAdminCmd("sm_playerspray", Command_PlayerSpray, ADMFLAG_KICK, "playerspray <name|#id>");
	RegAdminCmd("sm_blockspray", Command_BlockSpray, ADMFLAG_KICK, "blockspray <name|#id>");
	RegAdminCmd("sm_unblockspray", Command_UnBlockSpray, ADMFLAG_KICK, "unblockspray <name|#id>");
	RegAdminCmd("sm_warnspray", Command_WarnSpray, ADMFLAG_KICK, "warnspray <name|#id>");
	RegAdminCmd("sm_blocksprayfile", Command_BlockSprayFile, ADMFLAG_KICK, "blocksprayfile <spray filename>");
	RegAdminCmd("sm_unblocksprayfile", Command_UnBlockSprayFile, ADMFLAG_KICK, "unblocksprayfile <spray filename>");
	
	SQL_TConnect(GotSprayDatabase, "spraytracker");

	AddTempEntHook("Player Decal", PlayerSpray);
	
	LoadTranslations("common.phrases");
	LoadTranslations("spraymanager.phrases");
	
	cvar_sprayurl = CreateConVar("spray_url", "", "Set the spray manager URL"); //E.G. http://yoursite.com/spray.php?spray={SPRAY}&id={STEAMID}
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("Spray_IsViewDisabled", Native_Spray_IsViewDisabled); // Native for checking is spray viewing is enabled
	CreateNative("Spray_GenURL", Native_Spray_GenURL); // Native for generating spray URL
	CreateNative("Spray_Remove", Native_Spray_Remove); // Native for removing a spray file
	CreateNative("Spray_GetFile", Native_Spray_File); // Native for getting spray file name
	CreateNative("Spray_SprayBlock", Native_Spray_Block); // Native for blocking spray
	CreateNative("Spray_TraceSpray", Native_Spray_Trace); // Native for getting where the player is looking
	CreateNative("Spray_HasUserSprayed", Native_Spray_HasSprayed); // Native for checking if a player has sprayed their spray
	return APLRes_Success;
}

public GotSprayDatabase(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if(hndl == INVALID_HANDLE)
	{
		hDatabase = INVALID_HANDLE;
		LogError("Could not connect to database: %s", error);
	} else {
		hDatabase = hndl;
		Command_CreateTables();
	}
}

public Command_CreateTables()
{
	decl String:query[330];
	query = "CREATE TABLE IF NOT EXISTS `player_sprays` ( `id` int(11) NOT NULL AUTO_INCREMENT, `name` varchar(64) NOT NULL, `steamid` varchar(20) NOT NULL, `spray_file` varchar(11) NOT NULL, `times_sprayed` int(11) NOT NULL DEFAULT '0', `last_sprayed` int(18) NOT NULL, `blocked` ENUM( '0', '1' ) NOT NULL DEFAULT '0', PRIMARY KEY (`id`) );";
	SQL_TQuery(hDatabase, T_DoNothing, query, 0);
}

/* ------------------
 + Native Functions +
------------------ */

public Native_Spray_IsViewDisabled(Handle:plugin, numParams)
{
	decl String:SprayCvar[255];
	GetConVarString(cvar_sprayurl, SprayCvar, sizeof(SprayCvar));
	if(StrEqual(SprayCvar, "", false))
	{
		return true; //Spray viewing disabled
	} else {
		return false; //Spray viewing enabled
	}
}

public Native_Spray_GenURL(Handle:plugin, numParams)
{
	decl String:decalfile[11], String:sprayurl[255], String:steamid[20];
	new userid = GetNativeCell(1);
	
	new GetDecal = Spray_GetFile(userid, decalfile, sizeof(decalfile));
	if(!GetDecal)
	{
		return false; //Spray not found
	}
	
	new client = GetClientOfUserId(userid);
	GetClientAuthString(client, steamid, sizeof(steamid));
	
	GetConVarString(cvar_sprayurl, sprayurl, sizeof(sprayurl));
	ReplaceString(sprayurl, sizeof(sprayurl), "{SPRAY}", decalfile);
	ReplaceString(sprayurl, sizeof(sprayurl), "{STEAMID}", steamid);
	
	SetNativeString(2, sprayurl, GetNativeCell(3));
	return true;
}

public Native_Spray_Remove(Handle:plugin, numParams)
{
	new userid = GetNativeCell(1);
	new target = GetClientOfUserId(userid);
	new Float:vecPos[3];
	vecPos[0] = -999999999.0;
	vecPos[1] = -999999999.0;
	vecPos[2] = -999999999.0;
	
	
	if(PlayerUsedSpray[target] == false)
	{
		return 1; //Player has not sprayed their spray
	} else if(IsClientInGame(target))
	{
		TE_Start("Player Decal");
		TE_WriteVector("m_vecOrigin", vecPos);
		TE_WriteNum("m_nEntity", 0);
		TE_WriteNum("m_nPlayer", target);
		TE_SendToAll();
		
		PlayerUsedSpray[target] = false;
		
		return 0; //Spray removed
	} else {
		return 2; //Player is not in-game, the spray cant be removed
	}
}

public Native_Spray_File(Handle:plugin, numParams)
{
	decl String:decalfile[20];
	
	new userid = GetNativeCell(1);
	new target = GetClientOfUserId(userid);
	if (!target)
		return false;
	
	new GetDecal = GetPlayerDecalFile(target, decalfile, sizeof(decalfile));
	if(!GetDecal)
	{
		return false; //Spray not found
	}
	
	SetNativeString(2, decalfile, GetNativeCell(3));
	return true;
}

public Native_Spray_Block(Handle:plugin, numParams)
{
	decl String:SprayFile[20], String:query[255];
	GetNativeString(1, SprayFile, sizeof(SprayFile));
	new UserID = GetNativeCell(2);
	new target = GetClientOfUserId(UserID);
	new Block = GetNativeCell(3);
	
	if(UserID != -1)
	{
		if(Block == 1)
		{
			SprayIsBlocked[target] = 1;
		} else {
			SprayIsBlocked[target] = 0;
		}
	}
	
	if(hDatabase != INVALID_HANDLE) {
		Format(query, sizeof(query), "UPDATE player_sprays SET blocked = '%d' WHERE spray_file = '%s'", Block, SprayFile);
		SQL_TQuery(hDatabase, T_DoNothing, query, -1);
	}
}

public Native_Spray_Trace(Handle:plugin, numParams)
{
	new clientid = GetNativeCell(1);
	new client = GetClientOfUserId(clientid);
 	new Float:pos[3];
	if(GetPlayerEye(client, pos) >= 1){
		new Float:MaxDis = 50.0;
	 	for(new i = 1; i<= MAXPLAYERS; i++) {
			if(GetVectorDistance(pos, SprayLocation[i]) <= MaxDis)
				return GetClientUserId(i);
		}
	}
	return 0;
}

public Native_Spray_HasSprayed(Handle:plugin, numParams)
{
	new userid = GetNativeCell(1);
	new target = GetClientOfUserId(userid);
	if (!target)
		return false;
	
	if(PlayerUsedSpray[target] == true)
		return true;
	else
		return false;
}

/* ------------------
 + Global Functions +
------------------ */

public OnClientConnected(client)
{
	PlayerUsedSpray[client] = false;
	SprayIsBlocked[client] = 0;
}

stock GetPlayerEye(client, Float:pos[3])
{
	new Float:vAngles[3], Float:vOrigin[3];
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
	
	if(TR_DidHit(trace)) {
		TR_GetEndPosition(pos, trace);
		if(GetVectorDistance(pos, vOrigin) <= 128.0)
			return 2;
		return 1;
	}
	return 0;
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
 	new String:classname[64];
 	GetEntityNetClass(entity, classname, 64);
 	return !StrEqual(classname, "CTFPlayer");
}

public ReSprayDecal(client, remover)
{
	new RemoveSpray = Spray_Remove(GetClientUserId(client));
	
	if(RemoveSpray == 0)
	{
		PrintToChat(remover, "%s %t", SPRAY_REPLY_PREFIX, "Spray Removed");
		return 0;
	} else if(RemoveSpray == 1)
	{
		PrintToChat(remover, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Spray");
		return 1;
	} else if(RemoveSpray == 2)
	{
		PrintToChat(remover, "%s %t", SPRAY_REPLY_PREFIX, "Spray Not Ingame");
		return 2;
	} else {
		PrintToChat(remover, "%s %t", SPRAY_REPLY_PREFIX, "Spray Error", "Error removing spray!");
		return 3;
	}
}

public ViewSpray(client, target)
{
	decl String:TargetName[255], String:sprayurl[255], String:TargetSteamID[100], String:TargetUserIDString[100];
	GetClientName(target, TargetName, sizeof(TargetName));
	GetClientAuthString(target, TargetSteamID, sizeof(TargetSteamID));
	new TargetUserID = GetClientUserId(target);
	IntToString(TargetUserID, TargetUserIDString, sizeof(TargetUserIDString));
	
	new Handle:h1Menu = CreateMenu(MenuHandler_SprayView);
	SetMenuTitle(h1Menu, "Spray By:");
	AddMenuItem(h1Menu, TargetName, TargetName, ITEMDRAW_DISABLED);
	AddMenuItem(h1Menu, TargetSteamID, TargetSteamID, ITEMDRAW_DISABLED);
	AddMenuItem(h1Menu, TargetUserIDString, "Actions");
	DisplayMenu(h1Menu, client, MENU_TIME_FOREVER);

	new bool:IsViewDisabled = Spray_IsViewDisabled();
	if(!IsViewDisabled)
	{
		Spray_GenURL(TargetUserID, sprayurl, sizeof(sprayurl));	
		ShowMOTDPanel(client, "View Spray", sprayurl, MOTDPANEL_TYPE_URL);
	}
	return true;
}

/* ---------------
 + SQL Callbacks +
 -------------- */

public T_SprayCallback(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!client)
		return;
	
	if (hndl == INVALID_HANDLE)
	{
		LogError("Error in T_SprayCallback: %s",error);
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Error", "Database action failed!");
		return;
	} else if (!SQL_FetchRow(hndl)) {
		decl String:Name_Safe[64], String:Name[64], String:SteamID[20], String:SteamID_Safe[50], String:SprayFile[11], String:query[255]; 
		GetClientName(client, Name, sizeof(Name));
		GetClientAuthString(client, SteamID, sizeof(SteamID));
		
		SQL_EscapeString(hDatabase, Name, Name_Safe, sizeof(Name_Safe));
		SQL_EscapeString(hDatabase, SteamID, SteamID_Safe, sizeof(SteamID_Safe));
		
		new GetDecal = Spray_GetFile(userid, SprayFile, sizeof(SprayFile));
		if(!GetDecal)
		{
			return; //Spray not found
		}
		
		Format(query, sizeof(query), "INSERT INTO player_sprays (name, steamid, spray_file, times_sprayed, last_sprayed) VALUES ('%s', '%s', '%s', 1, UNIX_TIMESTAMP(now()))", Name_Safe, SteamID_Safe, SprayFile);
		SQL_TQuery(hDatabase, T_DoNothing, query, GetClientUserId(client));
		return;
	} else {
		if(SQL_FetchInt(hndl, 2) == 1)
		{
			if(SprayIsBlocked[client] == 0)
			{
				Spray_Remove(userid);
				PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Blocked");
			}
			SprayIsBlocked[client] = 1;
		} else {
			SprayIsBlocked[client] = 0;
			decl String:Name_Safe[64], String:Name[64], String:SprayFile[11], String:query[255], String:steamid[20], String:steamid_safe[50]; 
			GetClientName(client, Name, sizeof(Name));
			SQL_EscapeString(hDatabase, Name, Name_Safe, sizeof(Name_Safe));
			
			GetClientAuthString(client, steamid, sizeof(steamid));
			SQL_EscapeString(hDatabase, steamid, steamid_safe, sizeof(steamid_safe));
			SQL_FetchString(hndl, 0, SprayFile, sizeof(SprayFile));
			
			new TimesSprayed = SQL_FetchInt(hndl, 1);
			TimesSprayed += 1;
			
			Format(query, sizeof(query), "UPDATE player_sprays SET name = '%s', times_sprayed = %d, last_sprayed = UNIX_TIMESTAMP(now()) WHERE spray_file = '%s' AND steamid = '%s' LIMIT 1", Name_Safe, TimesSprayed, SprayFile, steamid_safe);
			SQL_TQuery(hDatabase, T_DoNothing, query, GetClientUserId(client));
			return;
		}
	}
}

public T_DoNothing(Handle:owner, Handle:hndl, const String:error[], any:userid)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("Error in T_DoNothing: %s",error);
		
		new client = GetClientOfUserId(userid);
		if (!client)
			return;
			
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Error", "Database action failed!");
		return;
	}	
}

/* ----------
 + Commands +
 ----------*/

public Action:PlayerSpray(const String:te_name[],const clients[],client_count,Float:delay)
{
	new client = TE_ReadNum("m_nPlayer");
	
	if(SprayIsBlocked[client] == 1)
	{
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Blocked");
		return Plugin_Handled;
	}
	
	TE_ReadVector("m_vecOrigin", SprayLocation[client]);
	PlayerUsedSpray[client] = true;
	
	decl String:query[255], String:decalfile[11], String:decalfile_safe[20], String:steamid[20], String:steamid_safe[50];
	
	GetClientAuthString(client, steamid, sizeof(steamid));
	
	new userid = GetClientUserId(client);
	
	new GetDecal = Spray_GetFile(userid, decalfile, sizeof(decalfile));
	if(GetDecal && hDatabase != INVALID_HANDLE)
	{
		SQL_EscapeString(hDatabase, decalfile, decalfile_safe, sizeof(decalfile_safe));
		SQL_EscapeString(hDatabase, steamid, steamid_safe, sizeof(steamid_safe));
		Format(query, sizeof(query), "SELECT spray_file, times_sprayed, blocked FROM player_sprays WHERE spray_file = '%s' AND steamid = '%s' LIMIT 1", decalfile_safe, steamid_safe);
		SQL_TQuery(hDatabase, T_SprayCallback, query, userid);
	}
	return Plugin_Continue;
}

public Action:Command_RemoveSpray(client, args)
{
	if (args < 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Args");
		return Plugin_Handled;
	}
	
	if (args > 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Invalid Command");
		return Plugin_Handled;
	}
	
	decl String:Player[255];
	GetCmdArg(1, Player, sizeof(Player));
	new target = FindTarget(0, Player, true, false);
	
	if(target == -1)
	{
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Player");
		return Plugin_Handled;
	} else {
		if(PlayerUsedSpray[target] == false)
		{
			PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Spray");
			return Plugin_Handled;
		}
		ReSprayDecal(target, client);
		return Plugin_Handled;
	}
}

public Action:Command_PlayerSpray(client, args)
{
	new bool:IsViewDisabled = Spray_IsViewDisabled();
	if(IsViewDisabled)
	{
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Cmd Disabled");
		return Plugin_Handled;
	}
	
	if (args < 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Args");
		return Plugin_Handled;
	}
	
	if (args > 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Invalid Command");
		return Plugin_Handled;
	}
	
	decl String:Player[255];
	GetCmdArg(1, Player, sizeof(Player));
	new target = FindTarget(0, Player, true, false);
	
	if(target == -1)
	{
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Player");
		return Plugin_Handled;
	} else {
		if(PlayerUsedSpray[target] == false)
		{
			PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Spray");
			return Plugin_Handled;
		}
		ViewSpray(client, target);
		return Plugin_Handled;
	}
}

public Action:Command_BlockSpray(client, args)
{
	if (args < 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Args");
		return Plugin_Handled;
	}
	
	if (args > 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Invalid Command");
		return Plugin_Handled;
	}
	
	decl String:Player[255];
	GetCmdArg(1, Player, sizeof(Player));
	new target = FindTarget(0, Player, true, false);
	
	if(target == -1)
	{
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Player");
	} else {
		Spray_Remove(GetClientUserId(target));
		decl String:SprayFile[20];
		Spray_GetFile(GetClientUserId(target), SprayFile, sizeof(SprayFile));
		Spray_SprayBlock(SprayFile, GetClientUserId(target), true);
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Block Attempt");
	}
	return Plugin_Handled;
}

public Action:Command_UnBlockSpray(client, args)
{
	if (args < 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Args");
		return Plugin_Handled;
	}
	
	if (args > 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Invalid Command");
		return Plugin_Handled;
	}
	
	decl String:Player[255];
	GetCmdArg(1, Player, sizeof(Player));
	new target = FindTarget(0, Player, true, false);
	
	if(target == -1)
	{
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Player");
	} else {
		Spray_Remove(GetClientUserId(target));
		decl String:SprayFile[20];
		Spray_GetFile(GetClientUserId(target), SprayFile, sizeof(SprayFile));
		Spray_SprayBlock(SprayFile, GetClientUserId(target), false);
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray UnBlock Attempt");
	}
	return Plugin_Handled;
}

public Action:Command_WarnSpray(client, args)
{
	if (args < 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Args");
		return Plugin_Handled;
	}
	
	if (args > 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Invalid Command");
		return Plugin_Handled;
	}
	
	decl String:Player[255];
	GetCmdArg(1, Player, sizeof(Player));
	new target = FindTarget(0, Player, true, false);
	
	if(target == -1)
	{
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Player");
		return Plugin_Handled;
	} else {
		PrintToChat(target, "%s %t", SPRAY_REPLY_PREFIX, "Spray Player Warning");
		new TargetUserID = GetClientUserId(target);
		decl String:SprayFile[20];
		Spray_GetFile(TargetUserID, SprayFile, sizeof(SprayFile));
		Spray_Remove(TargetUserID);
		Spray_SprayBlock(SprayFile, TargetUserID, true);
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Block Attempt");
		return Plugin_Handled;
	}
}

public Action:Command_BlockSprayFile(client, args)
{
	if (args < 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Args Spray File");
		return Plugin_Handled;
	}
	
	if (args > 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Invalid Command");
		return Plugin_Handled;
	}
	
	decl String:SprayFile[10];
	GetCmdArg(1, SprayFile, sizeof(SprayFile));
	
	if(strlen(SprayFile) < 8 || strlen(SprayFile) > 10 )
	{
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Invalid Command");
		return Plugin_Handled;
	}
	
	Spray_SprayBlock(SprayFile, -1, true);
	PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Block Attempt");
	return Plugin_Handled;
}

public Action:Command_UnBlockSprayFile(client, args)
{
	if (args < 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Args Spray File");
		return Plugin_Handled;
	}
	
	if (args > 1) {
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Invalid Command");
		return Plugin_Handled;
	}
	
	decl String:SprayFile[10];
	GetCmdArg(1, SprayFile, sizeof(SprayFile));
	
	if(strlen(SprayFile) < 8 || strlen(SprayFile) > 10 )
	{
		PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray Invalid Command");
		return Plugin_Handled;
	}

	Spray_SprayBlock(SprayFile, -1, false);
	PrintToChat(client, "%s %t", SPRAY_REPLY_PREFIX, "Spray UnBlock Attempt");
	return Plugin_Handled;
}

public Action:Command_Spray(client, args)
{
	SprayMenu(client);
}

/* -------
 + Menus +
 -------*/

SprayMenu(client)
{
	new Handle:hMenu = CreateMenu(MenuHandler_SprayMenu);
	SetMenuTitle(hMenu, "Aim at the spray you wish to view");
	AddMenuItem(hMenu, "Ok", "Ok");
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_SprayMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select) {
		new targetUserID= Spray_TraceSpray(GetClientUserId(param1));
		new target = GetClientOfUserId(targetUserID);
		if (!target) {
			PrintToChat(param1, "%s %t", SPRAY_REPLY_PREFIX, "Spray Pos Not Found");
			SprayMenu(param1);
		} else {
			ViewSpray(param1, target);
		}
	}
}

public MenuHandler_SprayView(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:GetTarget[100];
		GetMenuItem(menu, param2, GetTarget, sizeof(GetTarget));
		new target = GetClientOfUserId(StringToInt(GetTarget));
		
		decl String:TargetName[255], String:TargetSteamID[100];
		GetClientName(target, TargetName, sizeof(TargetName));
		GetClientAuthString(target, TargetSteamID, sizeof(TargetSteamID));
		
		new TargetUserID = GetClientUserId(target);
		ClientTargetUserID[param1] = TargetUserID;
	
		new Handle:hMenu = CreateMenu(MenuHandler_SprayActions);
		SetMenuTitle(hMenu, "Spray By:");
		AddMenuItem(hMenu, TargetName, TargetName, ITEMDRAW_DISABLED);
		AddMenuItem(hMenu, "1", "Remove Spray");
		AddMenuItem(hMenu, "2", "Remove and Warn Player");
		AddMenuItem(hMenu, "3", "Remove and Block Spray");
		AddMenuItem(hMenu, "4", "Remove, Block and Warn Player");
		DisplayMenu(hMenu, param1, MENU_TIME_FOREVER);
	}
}

public MenuHandler_SprayActions(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		new GetMenuParam = StringToInt(info); 
		new target = GetClientOfUserId(ClientTargetUserID[param1]);
		
		switch(GetMenuParam)
		{
			case 1: //Remove
			{
				ReSprayDecal(target, param1);
			}
			case 2: //Remove and warn
			{
				ReSprayDecal(target, param1);
				PrintToChat(target, "%s %t", SPRAY_REPLY_PREFIX, "Spray Player Warning");
			}
			case 3: //Remove and block
			{
				ReSprayDecal(target, param1);
				decl String:SprayFile[20];
				Spray_GetFile(ClientTargetUserID[param1], SprayFile, sizeof(SprayFile));
				Spray_SprayBlock(SprayFile, ClientTargetUserID[param1], true);
			}
			case 4: //Remove, block and warn
			{
				ReSprayDecal(target, param1);
				PrintToChat(target, "%s %t", SPRAY_REPLY_PREFIX, "Spray Player Warning");
				decl String:SprayFile[20];
				Spray_GetFile(ClientTargetUserID[param1], SprayFile, sizeof(SprayFile));
				Spray_SprayBlock(SprayFile, ClientTargetUserID[param1], true);
			} 
		}
	}
}