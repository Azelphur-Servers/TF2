#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <smac>
#undef REQUIRE_PLUGIN
#tryinclude <updater>

/* Plugin Info */
public Plugin:myinfo =
{
	name = "SMAC ConVar Checker",
	author = SMAC_AUTHOR,
	description = "Checks for players using exploitative cvars",
	version = SMAC_VERSION,
	url = SMAC_URL
};

/* Globals */
#define UPDATE_URL	"http://smac.sx/updater/smac_cvars.txt"

#define CELL_NAME	0
#define CELL_COMPTYPE	1
#define CELL_HANDLE	2
#define CELL_ACTION	3
#define CELL_VALUE	4
#define CELL_VALUE2	5
#define CELL_ALT	6
#define CELL_PRIORITY	7
#define CELL_CHANGED	8

#define ACTION_WARN	0 // Warn Admins
#define ACTION_MOTD	1 // Display MOTD with Alternate URL
#define ACTION_MUTE	2 // Mute the player.
#define ACTION_KICK	3 // Kick the player.
#define ACTION_BAN	4 // Ban the player.

#define COMP_EQUAL	0 // CVar should equal
#define COMP_GREATER	1 // CVar should be equal to or greater than
#define COMP_LESS	2 // CVar should be equal to or less than
#define COMP_BOUND	3 // CVar should be in-between two numbers.
#define COMP_STRING	4 // Cvar should string equal.
#define COMP_NONEXIST	5 // CVar shouldn't exist.

#define PRIORITY_NORMAL	0
#define PRIORITY_MEDIUM	1
#define PRIORITY_HIGH	3

// Array Index Documentation
// Arrays that come from g_hCVars are index like below.
// 1. CVar Name
// 2. Comparison Type
// 3. CVar Handle - If this is defined then the engine will ignore the Comparison Type and Values as this should be only for FCVAR_REPLICATED CVars.
// 4. Action Type - Determines what action the engine takes.
// 5. Value - The value that the cvar is expected to have.
// 6. Value 2 - Only used as the high bound for COMP_BOUND.
// 7. Important - Defines the importance of the CVar in the ordering of the checks.
// 8. Was Changed - Defines if this CVar was changed recently.

new Handle:g_hCVars = INVALID_HANDLE;
new Handle:g_hCVarIndex = INVALID_HANDLE;
new Handle:g_hCurrentQuery[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
new Handle:g_hReplyTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
new Handle:g_hPeriodicTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};
new String:g_sQueryResult[][] = {"Okay", "Not found", "Not valid", "Protected"};
new g_iCurrentIndex[MAXPLAYERS+1] = {0, ...};
new g_iRetryAttempts[MAXPLAYERS+1] = {0, ...};
new g_iSize = 0;
new bool:g_bMapStarted = false;

/* Plugin Functions */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bMapStarted = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("smac.phrases");
	
	decl Handle:hConCommand, String:sName[64], bool:bIsCommand, iFlags, Handle:hConVar;

	g_hCVars = CreateArray(64);
	g_hCVarIndex = CreateTrie();

	//- High Priority -//  Note: We kick them out before hand because we don't want to have to ban them.
	CVars_AddCVar("0penscript",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("aim_bot",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("aim_fov",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("bat_version", 		COMP_NONEXIST, 	ACTION_KICK, 	"0.0",	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("beetlesmod_version", 	COMP_NONEXIST,  ACTION_KICK, 	"0.0",  0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("est_version", 		COMP_NONEXIST, 	ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("eventscripts_ver", 	COMP_NONEXIST, 	ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("fm_attackmode",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("lua_open",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("Lua-Engine",		COMP_NONEXIST, 	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("mani_admin_plugin_version", COMP_NONEXIST, ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("ManiAdminHacker",	COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("ManiAdminTakeOver",	COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("metamod_version", 	COMP_NONEXIST, 	ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("openscript",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("openscript_version",	COMP_NONEXIST,	ACTION_BAN, 	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("runnscript",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("SmAdminTakeover", 	COMP_NONEXIST, 	ACTION_BAN,	"0.0", 	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("sourcemod_version", 	COMP_NONEXIST, 	ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	CVars_AddCVar("tb_enabled",		COMP_NONEXIST,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_HIGH);
	CVars_AddCVar("zb_version", 		COMP_NONEXIST, 	ACTION_KICK, 	"0.0", 	0.0, 	PRIORITY_HIGH);

	//- Medium Priority -// Note: Now the client should be clean of any third party server side plugins.  Now we can start really checking.
	CVars_AddCVar("sv_cheats", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_MEDIUM);
	//CVars_AddCVar("sv_gravity", 		COMP_EQUAL, 	ACTION_BAN, 	"800.0", 0.0, 	PRIORITY_MEDIUM);
	CVars_AddCVar("r_drawothermodels", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_MEDIUM);
	
	// Consistency check has been reworked in some engines.
	new EngineVersion:iEngineVersion = GetEngineVersion();
	
	if (iEngineVersion != Engine_CSS && 
		iEngineVersion != Engine_DODS && 
		iEngineVersion != Engine_HL2DM && 
		iEngineVersion != Engine_TF2)
	{
		CVars_AddCVar("sv_consistency", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_MEDIUM);
	}

	//- Normal Priority -//
	CVars_AddCVar("cl_clock_correction", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("cl_leveloverview", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("cl_overdraw_test", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("cl_phys_timescale", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("cl_showevents", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);

	if (SMAC_GetGameType() == Game_INSMOD)
	{
		CVars_AddCVar("fog_enable", 		COMP_EQUAL, 	ACTION_KICK, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	}
	else
	{
		CVars_AddCVar("fog_enable", 		COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	}
	
	// This doesn't exist on FoF
	if (SMAC_GetGameType() == Game_FOF)
	{
		CVars_AddCVar("host_timescale", 	COMP_NONEXIST, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_HIGH);
	}
	else
	{
		CVars_AddCVar("host_timescale", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	}
	
	CVars_AddCVar("mat_dxlevel", 		COMP_GREATER, 	ACTION_KICK, 	"80.0", 0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("mat_fillrate", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("mat_measurefillrate",	COMP_EQUAL,	ACTION_BAN,	"0.0", 	0.0,	PRIORITY_NORMAL);
	CVars_AddCVar("mat_proxy", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("mat_showlowresimage",	COMP_EQUAL, 	ACTION_BAN,	"0.0",	0.0,	PRIORITY_NORMAL);
	CVars_AddCVar("mat_wireframe", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("mem_force_flush", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("snd_show", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("snd_visualize", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_aspectratio", 		COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_colorstaticprops", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_DispWalkable", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_DrawBeams", 		COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawbrushmodels", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawclipbrushes", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawdecals", 		COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawentities", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawmodelstatsoverlay",COMP_EQUAL,	ACTION_BAN,	"0.0",	0.0,	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawopaqueworld", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawparticles", 	COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawrenderboxes", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawskybox",		COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_drawtranslucentworld", COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_shadowwireframe", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_skybox", 		COMP_EQUAL, 	ACTION_BAN, 	"1.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("r_visocclusion", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);
	CVars_AddCVar("vcollide_wireframe", 	COMP_EQUAL, 	ACTION_BAN, 	"0.0", 	0.0, 	PRIORITY_NORMAL);

	//- Replication Protection -//
	hConCommand = FindFirstConCommand(sName, sizeof(sName), bIsCommand, iFlags);
	
	if (hConCommand == INVALID_HANDLE)
	{
		SetFailState("Failed getting first ConVar");
	}

	do
	{
		if (bIsCommand)
			continue;
		
		if (!(iFlags & FCVAR_REPLICATED))
			continue;
		
		// SMAC will not always be the first to load and many plugins (mistakenly) put
		//  FCVAR_REPLICATED on their version cvar (in addition to FCVAR_PLUGIN)
		if (iFlags & FCVAR_PLUGIN)
			continue;
		
		hConVar = FindConVar(sName);
		
		if (hConVar == INVALID_HANDLE)
			continue;
		
		// ToDo: Check if replicate code is needed at all on L4D+ engines.
		if (SMAC_GetGameType() == Game_L4D2 && StrEqual(sName, "mp_gamemode"))
			continue;
		
		CVars_ReplicateConVar(hConVar);
		HookConVarChange(hConVar, CVars_Replicate);
		
	} while (FindNextConCommand(hConCommand, sName, sizeof(sName), bIsCommand, iFlags));

	CloseHandle(hConCommand);

	//- Register Admin Commands -//
	RegAdminCmd("smac_addcvar",      CVars_CmdAddCVar,  ADMFLAG_ROOT,    "Adds a CVar to the check list.");
	RegAdminCmd("smac_removecvar",   CVars_CmdRemCVar,  ADMFLAG_ROOT,    "Removes a CVar from the check list.");
	RegAdminCmd("smac_cvars_status", CVars_CmdStatus,  ADMFLAG_GENERIC,  "Shows the status of all in-game clients.");
	
	// Start on all clients.
	if (g_bMapStarted)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsClientAuthorized(i))
			{
				OnClientPostAdminCheck(i);
			}
		}
	}

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

public OnClientPostAdminCheck(client)
{
	if (!IsFakeClient(client))
	{
		CVars_SetTimer(g_hPeriodicTimer[client], CreateTimer(0.1, CVars_PeriodicTimer, client));
	}
}

public OnClientDisconnect(client)
{
	g_iCurrentIndex[client] = 0;
	g_iRetryAttempts[client] = 0;

	CVars_SetTimer(g_hPeriodicTimer[client], INVALID_HANDLE);
	CVars_SetTimer(g_hReplyTimer[client], INVALID_HANDLE);
}

public OnMapStart()
{
	g_bMapStarted = true;
}

public OnMapEnd()
{
	g_bMapStarted = false;
}

//- Admin Commands -//

public Action:CVars_CmdStatus(client, args)
{
	if (IS_CLIENT(client) && !IsClientInGame(client))
		return Plugin_Handled;

	decl String:sAuth[MAX_AUTHID_LENGTH], String:sCVarName[64];
	new Handle:hTemp;

	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && GetClientAuthString(i, sAuth, sizeof(sAuth), false))
		{
			hTemp = g_hCurrentQuery[i];
			
			if (hTemp == INVALID_HANDLE)
			{
				if (g_hPeriodicTimer[i] == INVALID_HANDLE)
				{
					LogError("%N (%s) doesn't have a periodic timer running and no active queries.", i, sAuth);
					ReplyToCommand(client, "ERROR: %N (%s) didn't have a periodic timer running nor active queries.", i, sAuth);
					CVars_SetTimer(g_hPeriodicTimer[i], CreateTimer(0.1, CVars_PeriodicTimer, i));
					continue;
				}
				ReplyToCommand(client, "%N (%s) is waiting for new query. Current Index: %d.", i, sAuth, g_iCurrentIndex[i]);
			}
			else
			{
				GetArrayString(hTemp, CELL_NAME, sCVarName, sizeof(sCVarName));
				ReplyToCommand(client, "%N (%s) has active query on %s. Current Index: %d. Retry Attempts: %d.", i, sAuth, sCVarName, g_iCurrentIndex[i], g_iRetryAttempts[i]);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action:CVars_CmdAddCVar(client, args)
{
	if (args != 4 && args != 5)
	{
		ReplyToCommand(client, "Usage: smac_addcvar <cvar name> <comparison type> <action> <value> <value2 if bound>");
		return Plugin_Handled;
	}

	decl String:sCVarName[64], String:sTemp[64], iCompType, iAction, String:sValue[64], Float:fValue2;
	GetCmdArg(1, sCVarName, sizeof(sCVarName));
	
	if (!CVars_IsValidName(sCVarName))
	{
		ReplyToCommand(client, "The ConVar name \"%s\" is invalid and cannot be used.", sCVarName);
		return Plugin_Handled;
	}

	GetCmdArg(2, sTemp, sizeof(sTemp));

	if (StrEqual(sTemp, "equal"))
		iCompType = COMP_EQUAL;
	else if (StrEqual(sTemp, "greater"))
		iCompType = COMP_GREATER;
	else if (StrEqual(sTemp, "less"))
		iCompType = COMP_LESS;
	else if (StrEqual(sTemp, "between"))
		iCompType = COMP_BOUND;
	else if (StrEqual(sTemp, "strequal"))
		iCompType = COMP_STRING;
	else if (StrEqual(sTemp, "nonexist"))
		iCompType = COMP_NONEXIST;
	else
	{
		ReplyToCommand(client, "Unrecognized comparison type \"%s\", acceptable values: \"equal\", \"greater\", \"less\", \"between\", \"strequal\", or \"nonexist\".", sTemp);
		return Plugin_Handled;
	}
	
	if (iCompType == COMP_BOUND && args < 5)
	{
		ReplyToCommand(client, "Bound comparison type needs two values to compare with.");
		return Plugin_Handled;
	}

	GetCmdArg(3, sTemp, sizeof(sTemp));

	if (StrEqual(sTemp, "warn"))
		iAction = ACTION_WARN;
	else if (StrEqual(sTemp, "motd"))
		iAction = ACTION_MOTD;
	else if (StrEqual(sTemp, "mute"))
		iAction = ACTION_MUTE;
	else if (StrEqual(sTemp, "kick"))
		iAction = ACTION_KICK;
	else if (StrEqual(sTemp, "ban"))
		iAction = ACTION_BAN;
	else
	{
		ReplyToCommand(client, "Unrecognized action type \"%s\", acceptable values: \"warn\", \"mute\", \"kick\", or \"ban\".", sTemp);
		return Plugin_Handled;
	}

	GetCmdArg(4, sValue, sizeof(sValue));

	if (iCompType == COMP_BOUND)
	{
		GetCmdArg(5, sTemp, sizeof(sTemp));
		fValue2 = StringToFloat(sTemp);
	}

	if (CVars_AddCVar(sCVarName, iCompType, iAction, sValue, fValue2, PRIORITY_NORMAL))
	{
		if (IS_CLIENT(client))
		{
			SMAC_LogAction(client, "added convar %s to the check list.", sCVarName);
		}
		
		ReplyToCommand(client, "Successfully added ConVar %s to the check list.", sCVarName);
	}
	else
	{
		ReplyToCommand(client, "Failed to add ConVar %s to the check list.", sCVarName);
	}
	
	return Plugin_Handled;
}

public Action:CVars_CmdRemCVar(client, args)
{
	if (args != 1)
	{
		ReplyToCommand(client, "Usage: smac_removecvar <cvar name>");
		return Plugin_Handled;
	}

	decl String:sCVarName[64];
	GetCmdArg(1, sCVarName, sizeof(sCVarName));

	if (CVars_RemoveCVar(sCVarName))
	{
		if (IS_CLIENT(client))
		{
			SMAC_LogAction(client, "removed convar %s from the check list.", sCVarName);
		}
		else
		{
			SMAC_Log("Console removed convar %s from the check list.", sCVarName);
		}
		
		ReplyToCommand(client, "ConVar %s was successfully removed from the check list.", sCVarName);
	}
	else
	{
		ReplyToCommand(client, "Unable to find ConVar %s in the check list.", sCVarName);
	}
	
	return Plugin_Handled;
}

//- Timers -//

public Action:CVars_PeriodicTimer(Handle:timer, any:client)
{
	if (g_hPeriodicTimer[client] == INVALID_HANDLE)
		return Plugin_Stop;

	g_hPeriodicTimer[client] = INVALID_HANDLE;

	if (!IsClientConnected(client))
		return Plugin_Stop;

	decl String:sName[64], Handle:hCVar, iIndex;

	if (g_iSize < 1)
	{
		PrintToServer("Nothing in convar list");
		CreateTimer(10.0, CVars_PeriodicTimer, client);
		return Plugin_Stop;
	}

	iIndex = g_iCurrentIndex[client]++;
	
	if (iIndex >= g_iSize)
	{
		iIndex = 0;
		g_iCurrentIndex[client] = 1;
	}

	hCVar = GetArrayCell(g_hCVars, iIndex);

	if (GetArrayCell(hCVar, CELL_CHANGED) == INVALID_HANDLE)
	{
		GetArrayString(hCVar, 0, sName, sizeof(sName));
		g_hCurrentQuery[client] = hCVar;
		QueryClientConVar(client, sName, CVars_QueryCallback, client);
		
		// We'll wait 30 seconds for a reply.
		CVars_SetTimer(g_hReplyTimer[client], CreateTimer(30.0, CVars_ReplyTimer, GetClientUserId(client)));
	}
	else
	{
		CVars_SetTimer(g_hPeriodicTimer[client], CreateTimer(0.1, CVars_PeriodicTimer, client));
	}
	
	return Plugin_Stop;
}

public Action:CVars_ReplyTimer(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	
	if (!IS_CLIENT(client) || g_hReplyTimer[client] == INVALID_HANDLE)
		return Plugin_Stop;
		
	g_hReplyTimer[client] = INVALID_HANDLE;
	
	if (!IsClientConnected(client) || g_hPeriodicTimer[client] != INVALID_HANDLE)
		return Plugin_Stop;

	if (g_iRetryAttempts[client]++ > 3)
	{
		KickClient(client, "%t", "SMAC_FailedToReply");
	}
	else
	{
		decl String:sName[64], Handle:hCVar;

		if (g_iSize < 1)
		{
			PrintToServer("Nothing in convar list");
			CreateTimer(10.0, CVars_PeriodicTimer, client);
			return Plugin_Stop;
		}

		hCVar = g_hCurrentQuery[client];

		if (GetArrayCell(hCVar, CELL_CHANGED) == INVALID_HANDLE)
		{
			GetArrayString(hCVar, 0, sName, sizeof(sName));
			QueryClientConVar(client, sName, CVars_QueryCallback, client);
			
			// We'll wait 15 seconds for a reply.
			CVars_SetTimer(g_hReplyTimer[client], CreateTimer(15.0, CVars_ReplyTimer, GetClientUserId(client)));
		}
		else
		{
			CVars_SetTimer(g_hPeriodicTimer[client], CreateTimer(0.1, CVars_PeriodicTimer, client));
		}
	}

	return Plugin_Stop;
}

public Action:CVars_ReplicateTimer(Handle:timer, any:hConVar)
{
	decl String:sName[64];
	GetConVarName(hConVar, sName, sizeof(sName));
	
	if (StrEqual(sName, "sv_cheats") && GetConVarInt(hConVar) != 0)
	{
		SetConVarInt(hConVar, 0);
	}
	
	CVars_ReplicateConVar(hConVar);
	return Plugin_Stop;
}

public Action:CVars_ReplicateCheck(Handle:timer, any:hIndex)
{
	SetArrayCell(hIndex, CELL_CHANGED, INVALID_HANDLE);
	return Plugin_Stop;
}

//- ConVar Query Reply -//

public CVars_QueryCallback(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[])
{
	if (!IsClientConnected(client))
		return;

	decl String:sCVarName[64], Handle:hConVar, Handle:hTemp, iCompType, iAction, String:sValue[64], Float:fValue2, String:sAlternative[128], iSize, bool:bContinue;

	bContinue = (g_hPeriodicTimer[client] == INVALID_HANDLE);
	hConVar = g_hCurrentQuery[client];

	// We weren't expecting a reply or convar we queried is no longer valid and we cannot find it.
	if (hConVar == INVALID_HANDLE && !GetTrieValue(g_hCVarIndex, cvarName, hConVar))
	{
		 // Client doesn't have active query or a timer active for them?  Ballocks!
		if (bContinue)
		{
			CVars_SetTimer(g_hPeriodicTimer[client], CreateTimer(MT_GetRandomFloat(0.5, 2.0), CVars_PeriodicTimer, client));
		}
		
		return;
	}

	GetArrayString(hConVar, CELL_NAME, sCVarName, sizeof(sCVarName));

	/* Make sure this query replied correctly. */
	// CVar not expected.
	if (!StrEqual(cvarName, sCVarName))
	{
		 // CVar doesn't exist in our list.
		if (!GetTrieValue(g_hCVarIndex, cvarName, hConVar))
		{
			SMAC_LogAction(client, "was kicked for a corrupted return with convar name \"%s\" (expecting \"%s\") with value \"%s\".", cvarName, sCVarName, cvarValue);
			KickClient(client, "%t", "SMAC_ClientCorrupt");
			return;
		}
		else
		{
			bContinue = false;
		}
		
		GetArrayString(hConVar, CELL_NAME, sCVarName, sizeof(sCVarName));
	}

	iCompType = GetArrayCell(hConVar, CELL_COMPTYPE);
	iAction = GetArrayCell(hConVar, CELL_ACTION);

	if (bContinue)
	{
		g_hCurrentQuery[client] = INVALID_HANDLE;
		g_iRetryAttempts[client] = 0;
		CVars_SetTimer(g_hReplyTimer[client], INVALID_HANDLE);
	}

	// Check if it should exist.
	if (iCompType == COMP_NONEXIST)
	{
		new Handle:info = CreateKeyValues("");
		KvSetString(info, "cvar", cvarName);
		KvSetString(info, "value", cvarValue);
		KvSetString(info, "query", g_sQueryResult[result]);
		
		if (result != ConVarQuery_NotFound && SMAC_CheatDetected(client, Detection_CvarPlugin, info) == Plugin_Continue)
		{
			SMAC_PrintAdminNotice("%t", "SMAC_HasPlugin", client, sCVarName);
			
			switch (iAction)
			{
				case ACTION_MOTD:
				{
					GetArrayString(hConVar, CELL_ALT, sAlternative, sizeof(sAlternative));
					ShowMOTDPanel(client, "", sAlternative);
				}
				case ACTION_MUTE:
				{
					PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", client);
					ServerCommand("sm_mute #%d", GetClientUserId(client));
				}
				case ACTION_KICK:
				{
					SMAC_LogAction(client, "was kicked for returning with plugin convar \"%s\" (value \"%s\", return %s).", cvarName, cvarValue, g_sQueryResult[result]);
					KickClient(client, "%t", "SMAC_RemovePlugins");
					CloseHandle(info);
					return;
				}
				case ACTION_BAN:
				{
					SMAC_LogAction(client, "has convar \"%s\" (value \"%s\", return %s) when it shouldn't exist.", cvarName, cvarValue, g_sQueryResult[result]);
					SMAC_Ban(client, "ConVar %s violation", cvarName);
					CloseHandle(info);
					return;
				}
			}
		}
		
		CloseHandle(info);
		
		if (bContinue)
		{
			CVars_SetTimer(g_hPeriodicTimer[client], CreateTimer(MT_GetRandomFloat(1.0, 3.0), CVars_PeriodicTimer, client));
		}
		
		return;
	}

	 // ConVar should exist.
	if (result != ConVarQuery_Okay)
	{
		SMAC_LogAction(client, "returned query result \"%s\" (expected Okay) on convar \"%s\" (value \"%s\").", g_sQueryResult[result], cvarName, cvarValue);
		SMAC_Ban(client, "ConVar %s violation (bad query result)", cvarName);
		return;
	}

	// Check if the ConVar was recently changed.
	if (GetArrayCell(hConVar, CELL_CHANGED) != INVALID_HANDLE)
	{
		CVars_SetTimer(g_hPeriodicTimer[client], CreateTimer(MT_GetRandomFloat(1.0, 3.0), CVars_PeriodicTimer, client));
		return;
	}

	hTemp = GetArrayCell(hConVar, CELL_HANDLE);
	
	if (hTemp == INVALID_HANDLE || iCompType != COMP_EQUAL)
	{
		GetArrayString(hConVar, CELL_VALUE, sValue, sizeof(sValue));
	}
	else
	{
		GetConVarString(hTemp, sValue, sizeof(sValue));
	}

	if (iCompType == COMP_BOUND)
	{
		fValue2 = GetArrayCell(hConVar, CELL_VALUE2);
	}

	if (iCompType != COMP_STRING)
	{
		iSize = strlen(cvarValue);
		
		for (new i = 0; i < iSize; i++)
		{
			if (!IsCharNumeric(cvarValue[i]) && cvarValue[i] != '.')
			{
				SMAC_LogAction(client, "was kicked for returning a corrupted value on %s (%s), value set at \"%s\" (expected \"%s\").", sCVarName, cvarName, cvarValue, sValue);
				KickClient(client, "%t", "SMAC_ClientCorrupt");
				return;
			}
		}
	}
	
	new Handle:info = CreateKeyValues("");
	KvSetString(info, "cvar", sCVarName);
	KvSetString(info, "value", cvarValue);
	KvSetString(info, "expected", sValue);
	
	switch (iCompType)
	{
		case COMP_EQUAL:
		{
			if (StringToFloat(sValue) != StringToFloat(cvarValue) && SMAC_CheatDetected(client, Detection_CvarNotEqual, info) == Plugin_Continue)
			{
				SMAC_PrintAdminNotice("%t", "SMAC_HasNotEqual", client, sCVarName, cvarValue, sValue);
				
				switch (iAction)
				{
					case ACTION_MOTD:
					{
						GetArrayString(hConVar, CELL_ALT, sAlternative, sizeof(sAlternative));
						ShowMOTDPanel(client, "", sAlternative);
					}
					case ACTION_MUTE:
					{
						PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", client);
						ServerCommand("sm_mute #%d", GetClientUserId(client));
					}
					case ACTION_KICK:
					{
						SMAC_LogAction(client, "was kicked for returning with convar \"%s\" set to value \"%s\" when it should be \"%s\".", cvarName, cvarValue, sValue);
						KickClient(client, "\n%t", "SMAC_ShouldEqual", cvarName, sValue, cvarValue);
						CloseHandle(info);
						return;
					}
					case ACTION_BAN:
					{
						SMAC_LogAction(client, "has convar \"%s\" set to value \"%s\" (should be \"%s\") when it should equal.", cvarName, cvarValue, sValue);
						SMAC_Ban(client, "ConVar %s violation", cvarName);
						CloseHandle(info);
						return;
					}
				}
			}
		}
		case COMP_GREATER:
		{
			if (StringToFloat(sValue) > StringToFloat(cvarValue) && SMAC_CheatDetected(client, Detection_CvarNotGreater, info) == Plugin_Continue)
			{
				SMAC_PrintAdminNotice("%t", "SMAC_HasNotGreater", client, sCVarName, cvarValue, sValue);
				
				switch (iAction)
				{
					case ACTION_MOTD:
					{
						GetArrayString(hConVar, CELL_ALT, sAlternative, sizeof(sAlternative));
						ShowMOTDPanel(client, "", sAlternative);
					}
					case ACTION_MUTE:
					{
						PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", client);
						ServerCommand("sm_mute #%d", GetClientUserId(client));
					}
					case ACTION_KICK:
					{
						SMAC_LogAction(client, "was kicked for returning with convar \"%s\" set to value \"%s\" when it should be greater than or equal to \"%s\".", cvarName, cvarValue, sValue);
						KickClient(client, "\n%t", "SMAC_ShouldBeGreater", cvarName, sValue, cvarValue);
						CloseHandle(info);
						return;
					}
					case ACTION_BAN:
					{
						SMAC_LogAction(client, "has convar \"%s\" set to value \"%s\" (should be \"%s\") when it should greater than or equal to.", cvarName, cvarValue, sValue);
						SMAC_Ban(client, "ConVar %s violation", cvarName);
						CloseHandle(info);
						return;
					}
				}
			}
		}
		case COMP_LESS:
		{
			if (StringToFloat(sValue) < StringToFloat(cvarValue) && SMAC_CheatDetected(client, Detection_CvarNotLess, info) == Plugin_Continue)
			{
				SMAC_PrintAdminNotice("%t", "SMAC_HasNotLess", client, sCVarName, cvarValue, sValue);
				
				switch (iAction)
				{
					case ACTION_MOTD:
					{
						GetArrayString(hConVar, CELL_ALT, sAlternative, sizeof(sAlternative));
						ShowMOTDPanel(client, "", sAlternative);
					}
					case ACTION_MUTE:
					{
						PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", client);
						ServerCommand("sm_mute #%d", GetClientUserId(client));
					}
					case ACTION_KICK:
					{
						SMAC_LogAction(client, "was kicked for returning with convar \"%s\" set to value \"%s\" when it should be less than or equal to \"%s\".", cvarName, cvarValue, sValue);
						KickClient(client, "\n%t", "SMAC_ShouldBeLess", cvarName, sValue, cvarValue);
						CloseHandle(info);
						return;
					}
					case ACTION_BAN:
					{
						SMAC_LogAction(client, "has convar \"%s\" set to value \"%s\" (should be \"%s\") when it should be less than or equal to.", cvarName, cvarValue, sValue);
						SMAC_Ban(client, "ConVar %s violation", cvarName);
						CloseHandle(info);
						return;
					}
				}
			}
		}
		case COMP_BOUND:
		{
			if (StringToFloat(cvarValue) < StringToFloat(sValue) || StringToFloat(cvarValue) > fValue2 && SMAC_CheatDetected(client, Detection_CvarNotBound, info) == Plugin_Continue)
			{
				SMAC_PrintAdminNotice("%t", "SMAC_HasNotBound", client, sCVarName, cvarValue, sValue, fValue2);
				
				switch (iAction)
				{
					case ACTION_MOTD:
					{
						GetArrayString(hConVar, CELL_ALT, sAlternative, sizeof(sAlternative));
						ShowMOTDPanel(client, "", sAlternative);
					}
					case ACTION_MUTE:
					{
						PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", client);
						ServerCommand("sm_mute #%d", GetClientUserId(client));
					}
					case ACTION_KICK:
					{
						SMAC_LogAction(client, "was kicked for returning with convar \"%s\" set to value \"%s\" when it should be between \"%s\" and \"%f\".", cvarName, cvarValue, sValue, fValue2);
						KickClient(client, "\n%t", "SMAC_ShouldBound", cvarName, sValue, fValue2, cvarValue);
						CloseHandle(info);
						return;
					}
					case ACTION_BAN:
					{
						SMAC_LogAction(client, "has convar \"%s\" set to value \"%s\" when it should be between \"%s\" and \"%f\".", cvarName, cvarValue, sValue, fValue2);
						SMAC_Ban(client, "ConVar %s violation", cvarName);
						CloseHandle(info);
						return;
					}
				}
			}
		}
		case COMP_STRING:
		{
			if (!StrEqual(sValue, cvarValue) && SMAC_CheatDetected(client, Detection_CvarNotEqual, info) == Plugin_Continue)
			{
				SMAC_PrintAdminNotice("%t", "SMAC_HasNotEqual", client, sCVarName, cvarValue, sValue);
				
				switch (iAction)
				{
					case ACTION_MOTD:
					{
						GetArrayString(hConVar, CELL_ALT, sAlternative, sizeof(sAlternative));
						ShowMOTDPanel(client, "", sAlternative);
					}
					case ACTION_MUTE:
					{
						PrintToChatAll("%t%t", "SMAC_Tag", "SMAC_Muted", client);
						ServerCommand("sm_mute #%d", GetClientUserId(client));
					}
					case ACTION_KICK:
					{
						SMAC_LogAction(client, "was kicked for returning with convar \"%s\" set to value \"%s\" when it should be \"%s\".", cvarName, cvarValue, sValue);
						KickClient(client, "\n%t", "SMAC_ShouldEqual", cvarName, sValue, cvarValue);
						CloseHandle(info);
						return;
					}
					case ACTION_BAN:
					{
						SMAC_LogAction(client, "has convar \"%s\" set to value \"%s\" (should be \"%s\") when it should equal.", cvarName, cvarValue, sValue);
						SMAC_Ban(client, "ConVar %s violation", cvarName);
						CloseHandle(info);
						return;
					}
				}
			}
		}
	}
	
	CloseHandle(info);
	
	if (bContinue)
	{
		CVars_SetTimer(g_hPeriodicTimer[client], CreateTimer(MT_GetRandomFloat(0.5, 2.0), CVars_PeriodicTimer, client));
	}
}

//- Hook -//

public CVars_Replicate(Handle:convar, const String:oldvalue[], const String:newvalue[])
{
	decl String:sName[64], Handle:hCVarIndex;
	GetConVarName(convar, sName, sizeof(sName));
	
	if (GetTrieValue(g_hCVarIndex, sName, hCVarIndex))
	{
		new Handle:hTimer = GetArrayCell(hCVarIndex, CELL_CHANGED);
		
		CVars_SetTimer(hTimer, CreateTimer(30.0, CVars_ReplicateCheck, hCVarIndex));
		SetArrayCell(hCVarIndex, CELL_CHANGED, hTimer);
	}
	
	// The delay is so that nothing interferes with the replication.
	CreateTimer(0.1, CVars_ReplicateTimer, convar);
}

//- Private Functions -//

stock bool:CVars_IsValidName(const String:sName[])
{
	if (sName[0] == '\0')
		return false;
	
	new len = strlen(sName);
	
	for (new i = 0; i < len; i++)
	{
		if (!IsValidConVarChar(sName[i]))
			return false;
	}
	
	return true;
}

bool:CVars_AddCVar(String:sName[], iComparisonType, iAction, const String:sValue[], Float:fValue2, iImportance, const String:sAlternative[] = "")
{
	new Handle:hConVar = INVALID_HANDLE, Handle:hArray;
	StringToLower(sName);
	hConVar = FindConVar(sName);
	
	if (hConVar != INVALID_HANDLE && (GetConVarFlags(hConVar) & FCVAR_REPLICATED) && (iComparisonType == COMP_EQUAL || iComparisonType == COMP_STRING))
	{
		iComparisonType = COMP_EQUAL;
	}
	else
	{
		hConVar = INVALID_HANDLE;
	}
	
	// Check if CVar check already exists.
	if (GetTrieValue(g_hCVarIndex, sName, hArray))
	{
		SetArrayString(hArray, CELL_NAME, sName);			// Name			0
		SetArrayCell(hArray, CELL_COMPTYPE, iComparisonType);	// Comparison Type	1
		SetArrayCell(hArray, CELL_HANDLE, hConVar);			// CVar Handle		2
		SetArrayCell(hArray, CELL_ACTION, iAction);			// Action Type		3
		SetArrayString(hArray, CELL_VALUE, sValue);			// Value		4
		SetArrayCell(hArray, CELL_VALUE2, fValue2);			// Value2		5
		SetArrayString(hArray, CELL_ALT, sAlternative);		// Alternative Info	6
		// We will not change the priority.
		// Nor will we change the "changed" cell either.
	}
	else
	{
		hArray = CreateArray(64);
		PushArrayString(hArray, sName);		// Name			0
		PushArrayCell(hArray, iComparisonType);	// Comparison Type	1
		PushArrayCell(hArray, hConVar);		// CVar Handle		2
		PushArrayCell(hArray, iAction);		// Action Type		3
		PushArrayString(hArray, sValue);		// Value		4
		PushArrayCell(hArray, fValue2);		// Value2		5
		PushArrayString(hArray, sAlternative);	// Alternative Info	6
		PushArrayCell(hArray, iImportance);		// Importance		7
		PushArrayCell(hArray, INVALID_HANDLE);	// Changed		8

		if (!SetTrieValue(g_hCVarIndex, sName, hArray))
		{
			CloseHandle(hArray);
			SMAC_Log("Unable to add convar to Trie link list %s.", sName);
			return false;
		}

		PushArrayCell(g_hCVars, hArray);
		g_iSize = GetArraySize(g_hCVars);

		if (iImportance != PRIORITY_NORMAL && g_bMapStarted)
		{
			CVars_CreateNewOrder();
		}
	}

	return true;
}

stock bool:CVars_RemoveCVar(String:sName[])
{
	decl Handle:hConVar, iIndex;

	if (!GetTrieValue(g_hCVarIndex, sName, hConVar))
		return false;

	iIndex = FindValueInArray(g_hCVars, hConVar);
	
	if (iIndex == -1)
		return false;

	for (new i = 0; i <= MaxClients; i++)
	{
		if (g_hCurrentQuery[i] == hConVar)
			g_hCurrentQuery[i] = INVALID_HANDLE;
	}

	RemoveFromArray(g_hCVars, iIndex);
	RemoveFromTrie(g_hCVarIndex, sName);
	CloseHandle(hConVar);
	g_iSize = GetArraySize(g_hCVars);
	
	return true;
}

CVars_CreateNewOrder()
{
	new Handle:hOrder[g_iSize], iCurrent;
	new Handle:hPHigh, Handle:hPMedium, Handle:hPNormal, Handle:hCurrent;
	new iHigh, iMedium, iNormal, iTemp;

	hPHigh = CreateArray(64);
	hPMedium = CreateArray(64);
	hPNormal = CreateArray(64);

	// Get priorities.
	for (new i = 0; i < g_iSize; i++)
	{
		hCurrent = GetArrayCell(g_hCVars, i);
		iTemp = GetArrayCell(hCurrent, CELL_PRIORITY);
		
		if (iTemp == PRIORITY_NORMAL)
			PushArrayCell(hPNormal, hCurrent);
		else if (iTemp == PRIORITY_MEDIUM)
			PushArrayCell(hPMedium, hCurrent);
		else if (iTemp == PRIORITY_HIGH)
			PushArrayCell(hPHigh, hCurrent);
	}

	iHigh = GetArraySize(hPHigh)-1;
	iMedium = GetArraySize(hPMedium)-1;
	iNormal = GetArraySize(hPNormal)-1;

	// Start randomizing!
	while (iHigh > -1)
	{
		iTemp = GetRandomInt(0, iHigh);
		hOrder[iCurrent++] = GetArrayCell(hPHigh, iTemp);
		RemoveFromArray(hPHigh, iTemp);
		iHigh--;
	}

	while (iMedium > -1)
	{
		iTemp = GetRandomInt(0, iMedium);
		hOrder[iCurrent++] = GetArrayCell(hPMedium, iTemp);
		RemoveFromArray(hPMedium, iTemp);
		iMedium--;
	}

	while (iNormal > -1)
	{
		iTemp = GetRandomInt(0, iNormal);
		hOrder[iCurrent++] = GetArrayCell(hPNormal, iTemp);
		RemoveFromArray(hPNormal, iTemp);
		iNormal--;
	}

	ClearArray(g_hCVars);

	for (new i = 0; i < g_iSize; i++)
	{
		PushArrayCell(g_hCVars, hOrder[i]);
	}
	
	CloseHandle(hPHigh);
	CloseHandle(hPMedium);
	CloseHandle(hPNormal);
}

CVars_ReplicateConVar(Handle:hConVar)
{
	decl String:sValue[64];
	GetConVarString(hConVar, sValue, sizeof(sValue));
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			SendConVarValue(i, hConVar, sValue);
	}
}

CVars_SetTimer(&Handle:hTimer, Handle:hNewTimer=INVALID_HANDLE)
{
	new Handle:hTemp = hTimer;
	hTimer = hNewTimer;
	
	if (hTemp != INVALID_HANDLE)
	{
		CloseHandle(hTemp);
	}
}
