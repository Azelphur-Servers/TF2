#pragma semicolon 1

/* SM Includes */
#include <sourcemod>
#include <socket>
#include <smac>
#undef REQUIRE_PLUGIN
#tryinclude <updater>

/* Plugin Info */
public Plugin:myinfo =
{
	name = "SMAC KAC Global Banlist",
	author = SMAC_AUTHOR,
	description = "Kicks players on the KAC global banlist",
	version = SMAC_VERSION,
	url = "www.kigenac.com"
};

/* Globals */
#define UPDATE_URL	"http://smac.sx/updater/smac_kac_banlist.txt"

#define KAC_HOSTNAME	"kigenac.com"
#define KAC_QUERY		"api/check.php?id="

enum BanType {
	Ban_None = 0,
	Ban_KAC,
};

new Handle:g_hCvarKick = INVALID_HANDLE;
new Handle:g_hBanlist = INVALID_HANDLE;
new bool:g_bLateLoad = false;

/* Plugin Functions */
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLateLoad = late;
	return APLRes_Success;
}

public OnPluginStart()
{
	LoadTranslations("smac.phrases");
	
	// Convars.
	g_hCvarKick = SMAC_CreateConVar("smac_kac_kick", "1", "Automatically kick players on the KAC banlist.", FCVAR_PLUGIN, true, 0.0, true, 1.0);
	
	// Initialize.
	g_hBanlist = CreateTrie();
	
	if (g_bLateLoad)
	{
		decl String:sAuthID[MAX_AUTHID_LENGTH];
		
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientAuthorized(i) && GetClientAuthString(i, sAuthID, sizeof(sAuthID), false))
			{
				OnClientAuthorized(i, sAuthID);
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

public OnClientAuthorized(client, const String:auth[])
{
	if (IsFakeClient(client))
		return;
	
	// Workaround for universe digit change on L4D+ engines.
	decl String:sAuthID[MAX_AUTHID_LENGTH];
	FormatEx(sAuthID, sizeof(sAuthID), "STEAM_0:%s", auth[8]);
	
	// Check the cache first.
	new BanType:banValue = Ban_None;
	
	if (GetTrieValue(g_hBanlist, sAuthID, banValue))
	{
		if (banValue == Ban_KAC && GetConVarBool(g_hCvarKick) && SMAC_CheatDetected(client, Detection_GlobalBanned_KAC, INVALID_HANDLE) == Plugin_Continue)
		{
			KickClient(client, "%t", "SMAC_GlobalBanned", "KAC", "www.kigenac.com");
		}
		
		return;
	}
	
	// Clear a large cache to prevent slowdowns. Shouldn't reach this size anyway.
	if (GetTrieSize(g_hBanlist) > 50000)
		ClearTrie(g_hBanlist);
	
	// Check the banlist.
	new Handle:hPack = CreateDataPack();
	WritePackCell(hPack, GetClientUserId(client));
	WritePackString(hPack, sAuthID);
	
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketSetArg(socket, hPack);
	SocketSetOption(socket, ConcatenateCallbacks, 4096);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, KAC_HOSTNAME, 80);
}

public OnSocketConnected(Handle:socket, any:hPack)
{
	decl String:sAuthID[MAX_AUTHID_LENGTH], String:sRequest[256];
	SetPackPosition(hPack, 8);
	ReadPackString(hPack, sAuthID, sizeof(sAuthID));
	FormatEx(sRequest, sizeof(sRequest), "GET /%s%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", KAC_QUERY, sAuthID, KAC_HOSTNAME);
	SocketSend(socket, sRequest);
}

public OnSocketReceive(Handle:socket, String:data[], const size, any:hPack)
{
	SetPackPosition(hPack, 0);
	
	new client = GetClientOfUserId(ReadPackCell(hPack));
	
	if (IS_CLIENT(client))
	{
		decl String:sAuthID[MAX_AUTHID_LENGTH];
		ReadPackString(hPack, sAuthID, sizeof(sAuthID));
		
		if (StrContains(data, "_BAN") != -1)
		{
			SetTrieValue(g_hBanlist, sAuthID, Ban_KAC);
			
			if (SMAC_CheatDetected(client, Detection_GlobalBanned_KAC, INVALID_HANDLE) == Plugin_Continue)
			{
				SMAC_PrintAdminNotice("%N | %s | KAC Ban", client, sAuthID);
				
				if (GetConVarBool(g_hCvarKick))
				{
					SMAC_LogAction(client, "was kicked.");
					KickClient(client, "%t", "SMAC_GlobalBanned", "KAC", "www.kigenac.com");
				}
				else
				{
					SMAC_LogAction(client, "is on the banlist.");
				}
			}
		}
		else
		{
			SetTrieValue(g_hBanlist, sAuthID, Ban_None);
		}
	}
}

public OnSocketDisconnected(Handle:socket, any:hPack)
{
	CloseHandle(hPack);
	CloseHandle(socket);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:hPack)
{
	CloseHandle(hPack);
	CloseHandle(socket);
}