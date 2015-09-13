#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <sdktools>
#include <smac>
#undef REQUIRE_EXTENSIONS
#tryinclude <connect>
#undef REQUIRE_PLUGIN
#tryinclude <updater>

/* Plugin Info */
public Plugin:myinfo =
{
	name = "SMAC Client Protection",
	author = SMAC_AUTHOR,
	description = "Blocks general client exploits",
	version = SMAC_VERSION,
	url = SMAC_URL
};

/* Globals */
#define UPDATE_URL	"http://smac.sx/updater/smac_client.txt"

new Handle:g_hCvarConnectSpam = INVALID_HANDLE;
new Handle:g_hCvarValidateAuth = INVALID_HANDLE;
new Handle:g_hClientConnections = INVALID_HANDLE;
new Float:g_fTeamJoinTime[MAXPLAYERS+1][6];
new g_iNameChanges[MAXPLAYERS+1];
new bool:g_bMapStarted = false;
new bool:g_bConnectExt = false;

/* Plugin Functions */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bMapStarted = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("smac.phrases");
	
	// Convars.
	g_hCvarConnectSpam = SMAC_CreateConVar("smac_antispam_connect", "2", "Seconds to prevent someone from restablishing a connection. (0 = Disabled)", FCVAR_PLUGIN, true, 0.0);
	g_hCvarValidateAuth = SMAC_CreateConVar("smac_validate_auth", "0", "Kick clients that fail to authenticate within 10 seconds of joining the server.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	g_hClientConnections = CreateTrie();
	
	// Hooks.
	if (SMAC_GetGameType() == Game_CSS || SMAC_GetGameType() == Game_TF2)
	{
		HookUserMessage(GetUserMessageId("TextMsg"), Hook_TextMsg, true);
	}
	
	HookEventEx("player_team", Event_PlayerTeam, EventHookMode_Pre);
	HookEvent("player_changename", Event_PlayerChangeName, EventHookMode_Post);
	AddCommandListener(Command_Autobuy, "autobuy");
	
	// Check all clients.
	if (g_bMapStarted)
	{
		decl String:sReason[256];

		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && !OnClientConnect(i, sReason, sizeof(sReason)))
			{
				KickClient(i, "%s", sReason);
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

public OnMapStart()
{
	// Give time for players to connect before we start checking for spam.
	CreateTimer(20.0, Timer_MapStarted, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_MapStarted(Handle:timer)
{
	g_bMapStarted = true;
	return Plugin_Stop;
}

public OnMapEnd()
{
	g_bMapStarted = false;
	ClearTrie(g_hClientConnections);
}

public bool:OnClientPreConnectEx(const String:name[], String:password[255], const String:ip[], const String:steamID[], String:rejectReason[255])
{
	g_bConnectExt = true;
	
	if (IsConnectSpamming(ip))
	{
		if (ShouldLogIP(ip))
		{
			SMAC_Log("%s (ID: %s | IP: %s) was temporarily banned for connection spam.", name, steamID, ip);
		}
		
		BanIdentity(ip, 1, BANFLAG_IP, "Spam Connecting", "SMAC");
		FormatEx(rejectReason, sizeof(rejectReason), "%T.", "SMAC_PleaseWait", LANG_SERVER);
		return false;
	}

	return true;
}

public bool:OnClientConnect(client, String:rejectmsg[], size)
{
	if (IsFakeClient(client))
	{
		return true;
	}
	
	if (!g_bConnectExt)
	{
		decl String:sIP[17];
		GetClientIP(client, sIP, sizeof(sIP));
		
		if (IsConnectSpamming(sIP))
		{
			if (ShouldLogIP(sIP))
			{
				SMAC_LogAction(client, "was temporarily banned for connection spam.");
			}
			
			BanIdentity(sIP, 1, BANFLAG_IP, "Spam Connecting", "SMAC");
			FormatEx(rejectmsg, size, "%T", "SMAC_PleaseWait", client);
			return false;
		}
	}

	if (!IsClientNameValid(client))
	{
		FormatEx(rejectmsg, size, "%T", "SMAC_ChangeName", client);
		return false;
	}

	return true;
}

public OnClientPutInServer(client)
{
	if (IsClientNew(client))
	{
		g_iNameChanges[client] = 0;
	}
	
	// Give the client 10s to fully authenticate.
	if (!IsFakeClient(client) && !IsClientAuthorized(client) && GetConVarBool(g_hCvarValidateAuth))
	{
		CreateTimer(10.0, Timer_ValidateAuth, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:Timer_ValidateAuth(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	
	if (IS_CLIENT(client) && IsClientInGame(client) && !IsClientAuthorized(client))
	{
		KickClient(client, "%t", "SMAC_FailedAuth");
	}
	
	return Plugin_Stop;
}

public OnClientSettingsChanged(client)
{
	if (!IsFakeClient(client) && !IsClientNameValid(client))
	{
		KickClient(client, "%t", "SMAC_ChangeName");
	}
}

public OnClientDisconnect_Post(client)
{
	for (new i = 0; i < sizeof(g_fTeamJoinTime[]); i++)
	{
		g_fTeamJoinTime[client][i] = 0.0;
	}
}

public Action:Hook_TextMsg(UserMsg:msg_id, Handle:bf, const players[], playersNum, bool:reliable, bool:init)
{
	// Name spam notices will only be sent to the offending client.
	if (!reliable || playersNum != 1)
		return Plugin_Continue;
	
	// The message we are looking for is sent to chat.
	new destination = BfReadByte(bf);
	
	if (destination != 3)
		return Plugin_Continue;
	
	decl String:sBuffer[64];
	BfReadString(bf, sBuffer, sizeof(sBuffer));
	
	if (StrEqual(sBuffer, "#Name_change_limit_exceeded"))
	{
		new client = players[0];
		
		if (!IsFakeClient(client) && SMAC_CheatDetected(client, Detection_NameChangeSpam, INVALID_HANDLE) == Plugin_Continue)
		{
			SMAC_LogAction(client, "was kicked for name change spam.");
			KickClient(client, "%t", "SMAC_CommandSpamKick");
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (dontBroadcast)
		return Plugin_Continue;
	
	// Don't broadcast team changes if they're being spammed.
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IS_CLIENT(client))
	{
		new Float:fGameTime = GetGameTime();
		new team = GetEventInt(event, "team");
		
		if (team < 0 || team >= sizeof(g_fTeamJoinTime[]))
			team = 0;
		
		if (g_fTeamJoinTime[client][team] > fGameTime)
		{
			SetEventBroadcast(event, true);
		}
		
		g_fTeamJoinTime[client][team] = fGameTime + 30.0;
	}
	
	return Plugin_Continue;
}

public Event_PlayerChangeName(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	new client = GetClientOfUserId(userid);
	
	if (IS_CLIENT(client) && IsClientInGame(client) && !IsFakeClient(client))
	{
		// Expire this detection after 10 seconds.
		g_iNameChanges[client]++;
		CreateTimer(10.0, Timer_DecreaseCount, userid);
		
		if (g_iNameChanges[client] >= 5)
		{
			if (SMAC_CheatDetected(client, Detection_NameChangeSpam, INVALID_HANDLE) == Plugin_Continue)
			{
				SMAC_LogAction(client, "was kicked for name change spam.");
				KickClient(client, "%t", "SMAC_CommandSpamKick");
			}
			
			g_iNameChanges[client] = 0;
		}
	}
}

public Action:Command_Autobuy(client, const String:command[], args)
{
	if (!IS_CLIENT(client))
		return Plugin_Continue;
	
	if (!IsClientInGame(client))
		return Plugin_Handled;

	decl String:sAutobuy[256], String:sArg[64];
	new i, t;
	
	GetClientInfo(client, "cl_autobuy", sAutobuy, sizeof(sAutobuy));
	
	if (strlen(sAutobuy) > 255)
	{
		return Plugin_Handled;
	}

	i = 0;
	t = BreakString(sAutobuy, sArg, sizeof(sArg));
	
	while (t != -1)
	{
		if (strlen(sArg) > 30)
		{
			return Plugin_Handled;
		}

		i += t;
		t = BreakString(sAutobuy[i], sArg, sizeof(sArg));
	}

	if (strlen(sArg) > 30)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action:Timer_DecreaseCount(Handle:timer, any:userid)
{
	/* Decrease the name change detection count by 1. */
	new client = GetClientOfUserId(userid);
	
	if (IS_CLIENT(client) && g_iNameChanges[client])
	{
		g_iNameChanges[client]--;
	}
	
	return Plugin_Stop;
}

bool:IsClientNameValid(client)
{
	decl String:sName[MAX_NAME_LENGTH], String:sChar;

	GetClientName(client, sName, sizeof(sName));
	new iSize = strlen(sName);

	if (iSize < 1 || sName[0] == '&' || IsCharSpace(sName[0]) || IsCharSpace(sName[iSize-1]))
	{
		return false;
	}

	for (new i = 0; i < iSize; i++)
	{
		sChar = sName[i];
		
		// Check unicode characters.
		new bytes = IsCharMB(sChar);
		
		if (bytes > 1)
		{
			if (!IsMBCharValid(sName[i], bytes))
			{
				return false;
			}
			else
			{
				i += bytes - 1;
				continue;
			}
		}
		else if (sChar < 32 || sChar == '%' || sChar == 0x7F)
		{
			return false;
		}
	}
	
	return true;
}

bool:IsMBCharValid(const String:mbchar[], numbytes)
{
	/*
	* A blacklist of unicode characters.
	* Mostly a variation of zero-width and spaces.
	*/
	new c;
	
	// Ugly but fast for covering ranges.
	if (numbytes == 2)
	{
		c = mbchar[0];
		
		if (c == 0xC2)
		{
			c = mbchar[1];
			
			// U+0080 to U+00A0
			if (c >= 0x80 && c <= 0xA0)
			{
				return false;
			}
		}
	}
	else if (numbytes == 3)
	{
		c = mbchar[0];
		
		if (c == 0xE0)
		{
			c = mbchar[1];
			
			if (c == 0xB8)
			{
				c = mbchar[2];
				
				// U+0E34
				if (c == 0xB4)
				{
					return false;
				}
			}
		}
		else if (c == 0xE1)
		{
			c = mbchar[1];
			
			if (c == 0x85)
			{
				c = mbchar[2];
				
				// U+115F and U+1160
				if (c == 0x9F || c == 0xA0)
				{
					return false;
				}
			}
			else if (c == 0x8D)
			{
				c = mbchar[2];
				
				// U+135F
				if (c == 0x9F)
				{
					return false;
				}
			}
			else if (c == 0xA0)
			{
				c = mbchar[2];
				
				// U+180B to U+180F
				if (c >= 0x8B && c <= 0x8F)
				{
					return false;
				}
			}
		}
		else if (c == 0xE2)
		{
			c = mbchar[1];
			
			if (c == 0x80)
			{
				c = mbchar[2];
				
				// U+2000 to U+200F
				if (c >= 0x80 && c <= 0x8F)
				{
					return false;
				}
				
				// U+2028 to U+202F
				else if (c >= 0xA8 && c <= 0xAF)
				{
					return false;
				}
			}
			else if (c == 0x81)
			{
				c = mbchar[2];
				
				// U+205F to U+206F
				if (c >= 0x9F && c <= 0xAF)
				{
					return false;
				}
			}
		}
		else if (c == 0xE3)
		{
			c = mbchar[1];
			
			if (c == 0x80)
			{
				c = mbchar[2];
				
				// U+3000
				if (c == 0x80)
				{
					return false;
				}
			}
			else if (c == 0x85)
			{
				c = mbchar[2];
				
				// U+3164
				if (c == 0xA4)
				{
					return false;
				}
			}
		}
		else if (c == 0xEF)
		{
			c = mbchar[1];
			
			if (c == 0xBB)
			{
				c = mbchar[2];
				
				// U+FEFF
				if (c == 0xBF)
				{
					return false;
				}
			}
			else if (c == 0xBE)
			{
				c = mbchar[2];
				
				// U+FFA0
				if (c == 0xA0)
				{
					return false;
				}
			}
			else if (c == 0xBB)
			{
				c = mbchar[2];
				
				// U+FFF9 to U+FFFF
				if (c >= 0xB9)
				{
					return false;
				}
			}
		}
	}
	
	return true;
}

bool:IsConnectSpamming(const String:ip[])
{
	if (!g_bMapStarted || !IsServerProcessing())
		return false;
	
	static Handle:hIgnoreList = INVALID_HANDLE;
	
	if (hIgnoreList == INVALID_HANDLE)
	{
		hIgnoreList = CreateTrie();
	}
	
	new Float:fSpamTime = GetConVarFloat(g_hCvarConnectSpam);
	
	if (fSpamTime > 0.0)
	{
		decl String:sTempIP[17], dummy;
		
		// Add any LAN IPs to the ignore list.
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientAuthorized(i) && GetClientIP(i, sTempIP, sizeof(sTempIP)) && StrEqual(ip, sTempIP))
			{
				SetTrieValue(hIgnoreList, ip, 1);
				break;
			}
		}
		
		if (!GetTrieValue(hIgnoreList, ip, dummy))
		{
			if (GetTrieValue(g_hClientConnections, ip, dummy))
			{
				return true;
			}
			else if (SetTrieValue(g_hClientConnections, ip, 1))
			{
				CreateTimer(fSpamTime, Timer_AntiSpamConnect, IPToLong(ip));
			}
		}
	}
	
	return false;
}

bool:ShouldLogIP(const String:ip[])
{
	/* Only log each IP once to prevent log spam. */
	static Handle:hLogList = INVALID_HANDLE;
	
	if (hLogList == INVALID_HANDLE)
	{
		hLogList = CreateTrie();
	}
	
	decl dummy;
	
	if (GetTrieValue(hLogList, ip, dummy))
	{
		return false;
	}
	
	SetTrieValue(hLogList, ip, 1);
	return true;
}

public Action:Timer_AntiSpamConnect(Handle:timer, any:ip)
{
	decl String:sIP[17];
	LongToIP(ip, sIP, sizeof(sIP));
	RemoveFromTrie(g_hClientConnections, sIP);

	return Plugin_Stop;
}
