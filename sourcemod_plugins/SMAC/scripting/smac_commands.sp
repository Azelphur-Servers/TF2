#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <smac>
#undef REQUIRE_PLUGIN
#tryinclude <updater>

/* Plugin Info */
public Plugin:myinfo =
{
	name = "SMAC Command Monitor",
	author = SMAC_AUTHOR,
	description = "Blocks general command exploits",
	version = SMAC_VERSION,
	url = SMAC_URL
};

/* Globals */
#define UPDATE_URL	"http://smac.sx/updater/smac_commands.txt"

new Handle:g_hBlockedCmds = INVALID_HANDLE;
new Handle:g_hIgnoredCmds = INVALID_HANDLE;
new g_iCmdSpam = 30;
new g_iCmdCount[MAXPLAYERS+1] = {0, ...};
new Handle:g_hCvarCmdSpam = INVALID_HANDLE;

/* Plugin Functions */
public OnPluginStart()
{
	LoadTranslations("smac.phrases");
	
	// Convars.
	g_hCvarCmdSpam = SMAC_CreateConVar("smac_antispam_cmds", "30", "Amount of commands allowed in one second before kick. (0 = Disabled)", FCVAR_PLUGIN, true, 0.0);
	OnSettingsChanged(g_hCvarCmdSpam, "", "");
	HookConVarChange(g_hCvarCmdSpam, OnSettingsChanged);

	// Hooks.
	AddCommandListener(Commands_FilterSay, "say");
	AddCommandListener(Commands_FilterSay, "say_team");
	
	switch (SMAC_GetGameType())
	{
		case Game_INSMOD:
		{
			AddCommandListener(Commands_FilterSay, "say2");
		}
		case Game_ND:
		{
			AddCommandListener(Commands_FilterSay, "say_squad");
		}
	}
	
	AddCommandListener(Commands_BlockExploit, "sm_menu");
	
	// Exploitable needed commands.  Sigh....
	AddCommandListener(Commands_BlockEntExploit, "ent_create");
	AddCommandListener(Commands_BlockEntExploit, "ent_fire");
	
	// L4D2 uses this for confogl.
	if (SMAC_GetGameType() != Game_L4D2)
	{
		AddCommandListener(Commands_BlockEntExploit, "give");
	}
	
	// Block name disconnect exploit.
	new EngineVersion:iEngineVersion = GetEngineVersion();
	
	if (iEngineVersion == Engine_Original || 
		iEngineVersion == Engine_DarkMessiah || 
		iEngineVersion == Engine_SourceSDK2006 || 
		iEngineVersion == Engine_SourceSDK2007 || 
		iEngineVersion == Engine_BloodyGoodTime || 
		iEngineVersion == Engine_EYE)
	{
		HookEvent("player_disconnect", Commands_EventDisconnect, EventHookMode_Pre);
	}
	
	// Init...
	g_hBlockedCmds = CreateTrie();
	g_hIgnoredCmds = CreateTrie();

	//- Blocked Commands -// Note: True sets them to ban, false does not.
	SetTrieValue(g_hBlockedCmds, "ai_test_los", 			false);
	SetTrieValue(g_hBlockedCmds, "changelevel", 			true);
	SetTrieValue(g_hBlockedCmds, "cl_fullupdate",			false);
	SetTrieValue(g_hBlockedCmds, "dbghist_addline", 		false);
	SetTrieValue(g_hBlockedCmds, "dbghist_dump", 			false);
	SetTrieValue(g_hBlockedCmds, "drawcross",			false);
	SetTrieValue(g_hBlockedCmds, "drawline",			false);
	SetTrieValue(g_hBlockedCmds, "dump_entity_sizes", 		false);
	SetTrieValue(g_hBlockedCmds, "dump_globals", 			false);
	SetTrieValue(g_hBlockedCmds, "dump_panels", 			false);
	SetTrieValue(g_hBlockedCmds, "dump_terrain", 			false);
	SetTrieValue(g_hBlockedCmds, "dumpcountedstrings", 		false);
	SetTrieValue(g_hBlockedCmds, "dumpentityfactories", 		false);
	SetTrieValue(g_hBlockedCmds, "dumpeventqueue", 			false);
	SetTrieValue(g_hBlockedCmds, "dumpgamestringtable", 		false);
	SetTrieValue(g_hBlockedCmds, "editdemo", 			false);
	SetTrieValue(g_hBlockedCmds, "endround", 			false);
	SetTrieValue(g_hBlockedCmds, "groundlist", 			false);
	SetTrieValue(g_hBlockedCmds, "listdeaths", 			false);
	SetTrieValue(g_hBlockedCmds, "listmodels", 			false);
	SetTrieValue(g_hBlockedCmds, "map_showspawnpoints",		false);
	SetTrieValue(g_hBlockedCmds, "mem_dump", 			false);
	SetTrieValue(g_hBlockedCmds, "mp_dump_timers", 			false);
	SetTrieValue(g_hBlockedCmds, "npc_ammo_deplete", 		false);
	SetTrieValue(g_hBlockedCmds, "npc_heal", 			false);
	SetTrieValue(g_hBlockedCmds, "npc_speakall", 			false);
	SetTrieValue(g_hBlockedCmds, "npc_thinknow", 			false);
	SetTrieValue(g_hBlockedCmds, "physics_budget",			false);
	SetTrieValue(g_hBlockedCmds, "physics_debug_entity", 		false);
	SetTrieValue(g_hBlockedCmds, "physics_highlight_active", 	false);
	SetTrieValue(g_hBlockedCmds, "physics_report_active", 		false);
	SetTrieValue(g_hBlockedCmds, "physics_select", 			false);
	SetTrieValue(g_hBlockedCmds, "q_sndrcn", 			true);
	SetTrieValue(g_hBlockedCmds, "report_entities", 		false);
	SetTrieValue(g_hBlockedCmds, "report_touchlinks", 		false);
	SetTrieValue(g_hBlockedCmds, "report_simthinklist", 		false);
	SetTrieValue(g_hBlockedCmds, "respawn_entities",		false);
	SetTrieValue(g_hBlockedCmds, "rr_reloadresponsesystems", 	false);
	SetTrieValue(g_hBlockedCmds, "scene_flush", 			false);
	SetTrieValue(g_hBlockedCmds, "send_me_rcon", 			true);
	SetTrieValue(g_hBlockedCmds, "snd_digital_surround",		false);
	SetTrieValue(g_hBlockedCmds, "snd_restart", 			false);
	SetTrieValue(g_hBlockedCmds, "soundlist", 			false);
	SetTrieValue(g_hBlockedCmds, "soundscape_flush", 		false);
	SetTrieValue(g_hBlockedCmds, "speed.toggle", 			true);
	SetTrieValue(g_hBlockedCmds, "sv_benchmark_force_start", 	false);
	SetTrieValue(g_hBlockedCmds, "sv_findsoundname", 		false);
	SetTrieValue(g_hBlockedCmds, "sv_soundemitter_filecheck", 	false);
	SetTrieValue(g_hBlockedCmds, "sv_soundemitter_flush", 		false);
	SetTrieValue(g_hBlockedCmds, "sv_soundscape_printdebuginfo", 	false);
	SetTrieValue(g_hBlockedCmds, "wc_update_entity", 		false);
	
	//- Game Specific -//
	switch (SMAC_GetGameType())
	{
		case Game_L4D:
		{
			SetTrieValue(g_hBlockedCmds, "demo_returntolobby", 	false);
			
			SetTrieValue(g_hIgnoredCmds, "choose_closedoor", 	true);
			SetTrieValue(g_hIgnoredCmds, "choose_opendoor",		true);
		}
		case Game_L4D2:
		{
			SetTrieValue(g_hIgnoredCmds, "choose_closedoor", 	true);
			SetTrieValue(g_hIgnoredCmds, "choose_opendoor",		true);
		}
		case Game_ND:
		{
			SetTrieValue(g_hIgnoredCmds, "bitcmd", 	true);
			SetTrieValue(g_hIgnoredCmds, "sg", 		true);
		}
		case Game_HL2DM:
		{
			SetTrieValue(g_hBlockedCmds, "impulse 51",	false);
		}
	}

	//- Ignored Commands -//
	SetTrieValue(g_hIgnoredCmds, "buy",				true);
	SetTrieValue(g_hIgnoredCmds, "buyammo1",			true);
	SetTrieValue(g_hIgnoredCmds, "buyammo2",			true);
	SetTrieValue(g_hIgnoredCmds, "spec_mode",			true);
	SetTrieValue(g_hIgnoredCmds, "spec_next",			true);
	SetTrieValue(g_hIgnoredCmds, "spec_prev",			true);
	SetTrieValue(g_hIgnoredCmds, "use",				true);
	SetTrieValue(g_hIgnoredCmds, "vmodenable",			true);
	SetTrieValue(g_hIgnoredCmds, "vban",				true);

	CreateTimer(1.0, Timer_CountReset, _, TIMER_REPEAT);
	
	AddCommandListener(Commands_CommandListener);

	RegAdminCmd("smac_addcmd",          Commands_AddCmd,           ADMFLAG_ROOT,  "Adds a command to be blocked by SMAC.");
	RegAdminCmd("smac_addignorecmd",    Commands_AddIgnoreCmd,     ADMFLAG_ROOT,  "Adds a command to ignore on command spam.");
	RegAdminCmd("smac_removecmd",       Commands_RemoveCmd,        ADMFLAG_ROOT,  "Removes a command from the block list.");
	RegAdminCmd("smac_removeignorecmd", Commands_RemoveIgnoreCmd,  ADMFLAG_ROOT,  "Remove a command to ignore.");
	
#if defined _updater_included
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
#endif
}

public OnLibraryAdded(const String:name[])
{
#if defined _updater_included
	if (StrEqual(name, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
#endif
}

public Action:Commands_EventDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl String:sReason[512], String:sTemp[512], iLength, client;
	client = GetClientOfUserId(GetEventInt(event, "userid"));
	GetEventString(event, "reason", sReason, sizeof(sReason));
	GetEventString(event, "name", sTemp, sizeof(sTemp));
	iLength = strlen(sReason)+strlen(sTemp);
	GetEventString(event, "networkid", sTemp, sizeof(sTemp));
	iLength += strlen(sTemp);
	
	if (iLength > 235)
	{
		if (IS_CLIENT(client) && IsClientConnected(client))
		{
			SMAC_LogAction(client, "submitted a bad disconnect reason, length %d, \"%s\"", iLength, sReason);
		}
		else
		{
			SMAC_Log("Bad disconnect reason, length %d, \"%s\"", iLength, sReason);
		}
		
		SetEventString(event, "reason", "Bad disconnect message");
		return Plugin_Continue;
	}
	
	iLength = strlen(sReason);
	
	for (new i = 0; i < iLength; i++)
	{
		if (sReason[i] < 32 && sReason[i] != '\n')
		{
			if (IS_CLIENT(client) && IsClientConnected(client))
			{
				SMAC_LogAction(client, "submitted a bad disconnect reason, \"%s\" len = %d. Possible corruption or attack.", sReason, iLength);
			}
			else
			{
				SMAC_Log("Bad disconnect reason, \"%s\" len = %d. Possible corruption or attack.", sReason, iLength);
			}
			
			SetEventString(event, "reason", "Bad disconnect message");
			return Plugin_Continue;
		}
	}
	
	return Plugin_Continue;
}

//- Admin Commands -//

public Action:Commands_AddCmd(client, args)
{
	if (args != 2)
	{
		ReplyToCommand(client, "Usage: smac_addcmd <command name> <ban (1 or 0)>");
		return Plugin_Handled;
	}

	decl String:sCmdName[64], String:sTemp[8];
	GetCmdArg(1, sCmdName, sizeof(sCmdName));
	GetCmdArg(2, sTemp, sizeof(sTemp));
	
	new bool:bBan = (StringToInt(sTemp) != 0 || StrEqual(sTemp, "ban") || StrEqual(sTemp, "yes") || StrEqual(sTemp, "true"));
	
	if (SetTrieValue(g_hBlockedCmds, sCmdName, bBan))
	{
		ReplyToCommand(client, "You have successfully added %s to the command block list.", sCmdName);
	}
	else
	{
		ReplyToCommand(client, "%s already exists in the command block list.", sCmdName);
	}
	
	return Plugin_Handled;
}

public Action:Commands_AddIgnoreCmd(client, args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "Usage: smac_addignorecmd <command name>");
		return Plugin_Handled;
	}

	decl String:sCmdName[64];
	GetCmdArg(1, sCmdName, sizeof(sCmdName));

	if (SetTrieValue(g_hIgnoredCmds, sCmdName, true))
	{
		ReplyToCommand(client, "You have successfully added %s to the command ignore list.", sCmdName);
	}
	else
	{
		ReplyToCommand(client, "%s already exists in the command ignore list.", sCmdName);
	}
	
	return Plugin_Handled;
}

public Action:Commands_RemoveCmd(client, args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "Usage: smac_removecmd <command name>");
		return Plugin_Handled;
	}

	decl String:sCmdName[64];
	GetCmdArg(1, sCmdName, sizeof(sCmdName));

	if (RemoveFromTrie(g_hBlockedCmds, sCmdName))
	{
		ReplyToCommand(client, "You have successfully removed %s from the command block list.", sCmdName);
	}
	else
	{
		ReplyToCommand(client, "%s is not in the command block list.", sCmdName);
	}
	
	return Plugin_Handled;
}

public Action:Commands_RemoveIgnoreCmd(client, args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "Usage: smac_removeignorecmd <command name>");
		return Plugin_Handled;
	}

	decl String:sCmdName[64];
	GetCmdArg(1, sCmdName, sizeof(sCmdName));

	if (RemoveFromTrie(g_hIgnoredCmds, sCmdName))
	{
		ReplyToCommand(client, "You have successfully removed %s from the command ignore list.", sCmdName);
	}
	else
	{
		ReplyToCommand(client, "%s is not in the command ignore list.", sCmdName);
	}
	
	return Plugin_Handled;
}

//- Console Commands -//

public Action:Commands_BlockExploit(client, const String:command[], args)
{
	if (args > 0)
	{
		decl String:sArg[64];
		GetCmdArg(1, sArg, sizeof(sArg));
		
		if (StrEqual(sArg, "rcon_password"))
		{
			decl String:sCmdString[256];
			GetCmdArgString(sCmdString, sizeof(sCmdString));
			SMAC_PrintAdminNotice("%N was banned for command usage violation of command: sm_menu %s", client, sCmdString);
			SMAC_LogAction(client, "was banned for command usage violation of command: sm_menu %s", sCmdString);
			SMAC_Ban(client, "Exploit violation");
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public Action:Commands_FilterSay(client, const String:command[], args)
{
	if (!IS_CLIENT(client))
		return Plugin_Continue;

	new iSpaceNum;
	decl String:sMsg[256], String:sChar;
	new iLen = GetCmdArgString(sMsg, sizeof(sMsg));
	
	for (new i = 0; i < iLen; i++)
	{
		sChar = sMsg[i];
		
		if (sChar == ' ')
		{
			if (iSpaceNum++ >= 64)
			{
				PrintToChat(client, "%t", "SMAC_SayBlock");
				return Plugin_Stop;
			}
		}
			
		if (sChar < 32 && !IsCharMB(sChar))
		{
			PrintToChat(client, "%t", "SMAC_SayBlock");
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

public Action:Commands_BlockEntExploit(client, const String:command[], args)
{
	if (!IS_CLIENT(client))
		return Plugin_Continue;
	
	if (!IsClientInGame(client))
		return Plugin_Stop;
	
	decl String:sCmd[512];
	
	if (GetCmdArgString(sCmd, sizeof(sCmd)) > 500)
		return Plugin_Stop; // Too long to process.
	
	if (StrContains(sCmd, "point_servercommand") != -1 	|| StrContains(sCmd, "point_clientcommand") != -1 
	  || StrContains(sCmd, "logic_timer") != -1 	   	|| StrContains(sCmd, "quit", false) != -1
	  || StrContains(sCmd, "sm") != -1 		   	|| StrContains(sCmd, "quti") != -1 
	  || StrContains(sCmd, "restart", false) != -1 		|| StrContains(sCmd, "alias", false) != -1
	  || StrContains(sCmd, "admin") != -1 		|| StrContains(sCmd, "ma_") != -1 
	  || StrContains(sCmd, "rcon", false) != -1 			|| StrContains(sCmd, "sv_", false) != -1 
	  || StrContains(sCmd, "mp_", false) != -1 			|| StrContains(sCmd, "meta") != -1 
	  || StrContains(sCmd, "taketimer") != -1 		|| StrContains(sCmd, "logic_relay") != -1 
	  || StrContains(sCmd, "logic_auto") != -1 		|| StrContains(sCmd, "logic_autosave") != -1 
	  || StrContains(sCmd, "logic_branch") != -1 		|| StrContains(sCmd, "logic_case") != -1 
	  || StrContains(sCmd, "logic_collision_pair") != -1  || StrContains(sCmd, "logic_compareto") != -1 
	  || StrContains(sCmd, "logic_lineto") != -1 		|| StrContains(sCmd, "logic_measure_movement") != -1 
	  || StrContains(sCmd, "logic_multicompare") != -1 	|| StrContains(sCmd, "logic_navigation") != -1)
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Action:Commands_CommandListener(client, const String:command[], argc)
{
	if (!IS_CLIENT(client) || (IsClientConnected(client) && IsFakeClient(client)))
		return Plugin_Continue;
		
	if (!IsClientInGame(client))
		return Plugin_Stop;

	decl bool:bBan, String:sCmd[64];
	
	strcopy(sCmd, sizeof(sCmd), command);
	StringToLower(sCmd);

	// Check to see if this person is command spamming.
	if (g_iCmdSpam && !GetTrieValue(g_hIgnoredCmds, sCmd, bBan) && ++g_iCmdCount[client] > g_iCmdSpam)
	{
		decl String:sCmdString[128];
		GetCmdArgString(sCmdString, sizeof(sCmdString));
		
		new Handle:info = CreateKeyValues("");
		KvSetString(info, "command", command);
		KvSetString(info, "cmdstring", sCmdString);
		
		if (SMAC_CheatDetected(client, Detection_CommandSpamming, info) == Plugin_Continue)
		{
			SMAC_PrintAdminNotice("%N was kicked for command spamming: %s %s", client, command, sCmdString);
			SMAC_LogAction(client, "was kicked for command spamming: %s %s", command, sCmdString);
			KickClient(client, "%t", "SMAC_CommandSpamKick");
		}
		
		CloseHandle(info);
		
		return Plugin_Stop;
	}

	if (GetTrieValue(g_hBlockedCmds, sCmd, bBan))
	{
		decl String:sCmdString[256];
		GetCmdArgString(sCmdString, sizeof(sCmdString));
		
		new Handle:info = CreateKeyValues("");
		KvSetString(info, "command", command);
		KvSetString(info, "cmdstring", sCmdString);
		
		if (bBan && SMAC_CheatDetected(client, Detection_BannedCommand, info) == Plugin_Continue)
		{
			SMAC_PrintAdminNotice("%N was banned for command usage violation of command: %s %s", client, command, sCmdString);
			SMAC_LogAction(client, "was banned for command usage violation of command: %s %s", command, sCmdString);
			SMAC_Ban(client, "Command %s violation", command);
		}
		
		CloseHandle(info);
		
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

//- Timers -//

public Action:Timer_CountReset(Handle:timer, any:args)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		g_iCmdCount[i] = 0;
	}
	
	return Plugin_Continue;
}

public OnSettingsChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	g_iCmdSpam = GetConVarInt(convar);
}
