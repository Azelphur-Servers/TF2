/*
 * SourceMod !radio & !browse command
 * access them by typing !radio or using !browse www.site.com
 *
 * Coded by dubbeh - www.yegods.net
 *
 * Licensed under the GPLv3
 *
 */

#pragma semicolon 1
#include <sourcemod>
#include <clientprefs>

#define PLUGIN_VERSION			"1.0.0.14"
#define STATIONSFILE			"cfg/sourcemod/radiostations.ini"
#define MAX_STATION_NAME_SIZE	32
#define MAX_STATION_URL_SIZE	192 // MOTD message size can be 192 bytes maximum

public Plugin:SourceModRadio = 
{
	name = "SourceMod Radio", 
	author = "dubbeh", 
	description = "Radio stations plugin for sourcemod", 
	version = PLUGIN_VERSION, 
	url = "http://www.yegods.net/"
};

/* cVar Handles */
new Handle:g_cVarRadioEnable = INVALID_HANDLE;
new Handle:g_cVarRadioStationAdvert = INVALID_HANDLE;
new Handle:g_cVarWelcomeMsg = INVALID_HANDLE;
new Handle:g_cVarLogging = INVALID_HANDLE;
new Handle:g_cVarRadioAutoplay = INVALID_HANDLE;

/* Radio station vars */
new Handle:g_hRadioStationsMenu = INVALID_HANDLE;
new String:g_szRadioOffPage[MAX_STATION_URL_SIZE] = "about:blank";
new Handle:g_hArrayRadioStationNames = INVALID_HANDLE;
new Handle:g_hArrayRadioStationURLs = INVALID_HANDLE;
new String:g_szConfigFile[] = "sourcemod/plugin.radio.cfg";
new bool:g_bIsCSGO = false; // CS:GO automatically displays invisible MOTD panels
new String:g_szCSGOWrapperURL[MAX_STATION_URL_SIZE] = "about:blank";
new Handle:g_hCookieSavedStation = INVALID_HANDLE;



public OnPluginStart()
{
	CreateConVar("sm_radio_version", PLUGIN_VERSION, "SourceMod Radio version", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	g_cVarRadioEnable = CreateConVar("sm_radio_enable", "1.0", "Enable SourceMod Radio", 0, true, 0.0, true, 1.0);
	g_cVarRadioStationAdvert = CreateConVar("sm_radio_advert", "1.0", "Enable advertising the users radio station choice", 0, true, 0.0, true, 1.0);
	g_cVarWelcomeMsg = CreateConVar("sm_radio_welcome", "1.0", "Enable the welcome message", 0, true, 0.0, true, 1.0);
	g_cVarLogging = CreateConVar("sm_radio_logging", "1.0", "Enable logging to the server console and log file", 0, true, 0.0, true, 1.0);
	g_cVarRadioAutoplay = CreateConVar("sm_radio_autoplay", "1.0", "Enable auto playing a users radio choice on map change", 0, true, 0.0, true, 1.0);
	
	if ((g_cVarRadioEnable == INVALID_HANDLE) || 
		(g_cVarRadioStationAdvert == INVALID_HANDLE) || 
		(g_cVarWelcomeMsg == INVALID_HANDLE) || 
		(g_cVarLogging == INVALID_HANDLE))
	SetFailState("[SM-RADIO] Error - Unable to create a console var");
	
	if (((g_hArrayRadioStationNames = CreateArray(MAX_STATION_NAME_SIZE + 1, 0)) == INVALID_HANDLE) || 
		((g_hArrayRadioStationURLs = CreateArray(MAX_STATION_URL_SIZE + 1, 0)) == INVALID_HANDLE))
	{
		SetFailState("[SM-RADIO] Error - Unable to create the station arrays");
	}
	
	/* load translations */
	LoadTranslations("radio.phrases");
	
	RegConsoleCmd("sm_radio", Command_Radio);
	RegConsoleCmd("sm_radiooff", Command_RadioOff);
	RegConsoleCmd("sm_browse", Command_Browse);
	
	ServerCommand("exec %s", g_szConfigFile);
	
	g_hCookieSavedStation = RegClientCookie("SourceMod Radio", "SourceMod Radio Saved Station", CookieAccess_Protected);
	
	g_bIsCSGO = IsCSGO();
}

bool:IsCSGO()
{
	decl String:szGameDir[32];
	
	GetGameFolderName(szGameDir, sizeof(szGameDir));
	if ((szGameDir[0] == 'c') && (szGameDir[1] == 's') && (szGameDir[2] == 'g') && (szGameDir[3] == 'o'))
	{
		if (GetConVarInt(g_cVarLogging))
			LogMessage("[SM-RADIO] Running under CS:GO detected");
		return true;
	}
	return false;
}

public OnPluginEnd()
{
	ClearArray(g_hArrayRadioStationNames);
	FreeHandle(g_hArrayRadioStationNames);
	ClearArray(g_hArrayRadioStationURLs);
	FreeHandle(g_hArrayRadioStationURLs);
}

public OnMapStart()
{
	ServerCommand("exec %s", g_szConfigFile);
	strcopy(g_szRadioOffPage, sizeof(g_szRadioOffPage), "about:blank");
	GetRadioStationsFromFile();
	if ((g_hRadioStationsMenu = CreateRadioStationsMenu()) == INVALID_HANDLE)
		SetFailState("[SM-RADIO] Error - Radio stations menu handle is invalid");
}

public OnMapEnd()
{
	FreeHandle(g_hRadioStationsMenu);
}

public OnClientPutInServer(client)
{
	if ((client == 0) || !GetConVarInt(g_cVarRadioEnable) || !IsClientConnected(client))
		return;
	
	CreateTimer(30.0, WelcomeAdvertTimer, client);
}

public Action:WelcomeAdvertTimer(Handle:timer, any:client)
{
	decl String:szClientName[MAX_NAME_LENGTH] = "";
	decl String:szRadioStation[MAX_STATION_URL_SIZE] = "";
	
	if (IsClientConnected(client) && IsClientInGame(client))
	{
		if (GetConVarInt(g_cVarWelcomeMsg))
		{
			GetClientName(client, szClientName, sizeof(szClientName));
			PrintToChat(client, "\x01\x04[SM-RADIO]\x01 %T", "Welcome", LANG_SERVER, szClientName);
			PrintToChat(client, "\x01\x04[SM-RADIO]\x01 %T", "Radio Command Info", LANG_SERVER);
		}
		
		if (GetConVarInt(g_cVarRadioAutoplay) && AreClientCookiesCached(client))
		{
			GetClientCookie(client, g_hCookieSavedStation, szRadioStation, sizeof(szRadioStation));
			LoadMOTDPanel(client, "SourceMod Radio", szRadioStation, false);
		}
	}
	
	return Plugin_Stop;
}

stock FreeHandle(Handle:hHandle)
{
	if (hHandle != INVALID_HANDLE)
	{
		CloseHandle(hHandle);
		hHandle = INVALID_HANDLE;
	}
}

GetRadioStationsFromFile()
{
	decl String:szLineBuffer[256] = "";
	decl String:szTempBuffer[128] = "";
	static iIndex = 0, iPos = -1, iNumOfStations = 0;
	new Handle:hMapFile = INVALID_HANDLE;
	
	if (GetConVarInt(g_cVarLogging))
		LogMessage("[SM-RADIO] Loading the radio stations from \"%s\"", STATIONSFILE);
	
	ClearArray(g_hArrayRadioStationNames);
	ClearArray(g_hArrayRadioStationURLs);
	iNumOfStations = 0;
	
	if ((hMapFile = OpenFile(STATIONSFILE, "r")) != INVALID_HANDLE)
	{
		while (!IsEndOfFile(hMapFile) && ReadFileLine(hMapFile, szLineBuffer, sizeof(szLineBuffer)))
		{
			TrimString(szLineBuffer);
			
			if ((szLineBuffer[0] != '\0') && (szLineBuffer[0] != ';') && (szLineBuffer[0] != '/') && (szLineBuffer[1] != '/') && (szLineBuffer[0] == '"') && (szLineBuffer[0] != '\n') && (szLineBuffer[1] != '\n'))
			{
				iIndex = 0;
				if ((iPos = BreakString(szLineBuffer[iIndex], szTempBuffer, sizeof(szTempBuffer))) != -1)
				{
					iIndex += iPos;
					
					if (!strcmp("Off Page", szTempBuffer, false))
					{
						strcopy(g_szRadioOffPage, sizeof(g_szRadioOffPage), szLineBuffer[iIndex]);
					}
					else if (!strcmp("CS:GO Wrapper", szTempBuffer, false))
					{
						strcopy(g_szCSGOWrapperURL, sizeof(g_szCSGOWrapperURL), szLineBuffer[iIndex]);
					}
					else
					{
						PushArrayString(g_hArrayRadioStationNames, szTempBuffer);
						PushArrayString(g_hArrayRadioStationURLs, szLineBuffer[iIndex]);
						iNumOfStations++;
					}
				}
			}
		}
		
		CloseHandle(hMapFile);
		if (GetConVarInt(g_cVarLogging))
			LogMessage("[SM-RADIO] Finishing parsing \"%s\" - Found %d radio stations", STATIONSFILE, iNumOfStations);
		return;
	}
	
	if (GetConVarInt(g_cVarLogging))
		LogMessage("[SM-RADIO] Unable to open \"%s\"", STATIONSFILE);
	SetFailState("[SM-RADIO] Unable to open the radiostations.ini file");
	return;
}

public Handler_PlayRadioStation(Handle:menu, MenuAction:action, client, param)
{
	if (action == MenuAction_Select)
	{
		decl String:szRadioStationIndex[10] = "", String:szClientName[MAX_NAME_LENGTH] = "";
		decl String:szStationName[MAX_STATION_NAME_SIZE] = "", String:szStationURL[MAX_STATION_URL_SIZE] = "";
		static iStation = 0;
		
		GetMenuItem(menu, param, szRadioStationIndex, sizeof(szRadioStationIndex));
		
		iStation = StringToInt(szRadioStationIndex);
		GetArrayString(g_hArrayRadioStationNames, iStation, szStationName, sizeof(szStationName));
		GetArrayString(g_hArrayRadioStationURLs, iStation, szStationURL, sizeof(szStationURL));
		
		if (GetConVarInt(g_cVarRadioStationAdvert))
		{
			GetClientName(client, szClientName, sizeof(szClientName));
			PrintToChatAll("\x01\x04[SM-RADIO]\x01 %T", "Started Listening", LANG_SERVER, szClientName, szStationName);
		}
		
		if (g_bIsCSGO)
			LoadMOTDPanel(client, "SourceMod Radio", szStationURL, false);
		else
			ShowMOTDPanel(client, "SourceMod Radio", szStationURL, MOTDPANEL_TYPE_URL);
		SetClientCookie(client, g_hCookieSavedStation, szStationURL);
		
	}
}

Handle:CreateRadioStationsMenu()
{
	new Handle:hMenu = INVALID_HANDLE;
	static iIndex = 0, iArraySize = 0;
	decl String:szStationIndex[11] = "", String:szTranslation[64] = "", String:szStationName[MAX_STATION_NAME_SIZE] = "";
	
	hMenu = CreateMenu(Handler_PlayRadioStation);
	Format(szTranslation, sizeof(szTranslation), "%T:", "Stations Menu Title", LANG_SERVER);
	SetMenuTitle(hMenu, szTranslation);
	
	iArraySize = GetArraySize(g_hArrayRadioStationNames);
	
	for (iIndex = 0; iIndex < iArraySize; iIndex++)
	{
		GetArrayString(g_hArrayRadioStationNames, iIndex, szStationName, sizeof(szStationName));
		Format(szStationIndex, sizeof(szStationIndex), "%d", iIndex);
		AddMenuItem(hMenu, szStationIndex, szStationName);
	}
	
	return hMenu;
}


public Action:Command_Radio(client, args)
{
	if (GetConVarInt(g_cVarRadioEnable))
		DisplayMenu(g_hRadioStationsMenu, client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

public Action:Command_Browse(client, args)
{
	if (GetConVarInt(g_cVarRadioEnable))
	{
		if (args == 1)
		{
			decl String:szWebsite[128] = "";
			
			GetCmdArg(1, szWebsite, sizeof(szWebsite));
			
			if (g_bIsCSGO)
				ShowMOTDPanel(client, "SourceMod Browse", CSGO_Browse_Fix(szWebsite), MOTDPANEL_TYPE_URL);
			else
				ShowMOTDPanel(client, "SourceMod Browse", szWebsite, MOTDPANEL_TYPE_URL);
		}
		else
		{
			ReplyToCommand(client, "[SM-RADIO] Invalid browse format");
			ReplyToCommand(client, "[SM-RADIO] Usage: sm_browse \"www.website.com\"");
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_RadioOff(client, args)
{
	decl String:szClientName[MAX_NAME_LENGTH] = "";
	
	if (GetConVarInt(g_cVarRadioEnable))
	{
		//if (g_bIsCSGO)
		//	ShowMOTDPanel(client, "SourceMod Radio", CSGO_MOTD_Fix(g_szRadioOffPage), MOTDPANEL_TYPE_URL);
		//else
		LoadMOTDPanel(client, "SourceMod Radio", g_szRadioOffPage, false);
		
		SetClientCookie(client, g_hCookieSavedStation, "");
		
		if (GetConVarInt(g_cVarRadioStationAdvert))
		{
			GetClientName(client, szClientName, sizeof(szClientName));
			PrintToChatAll("\x01\x04[SM-RADIO]\x01 %T", "Stopped Listening", LANG_SERVER, szClientName);
		}
	}
	
	return Plugin_Handled;
}

public LoadMOTDPanel(client, String:title[], String:page[], bool:display)
{
	new Handle:kv = CreateKeyValues("data");
	
	KvSetString(kv, "title", title);
	KvSetNum(kv, "type", MOTDPANEL_TYPE_URL);
	KvSetString(kv, "msg", page);
	ShowVGUIPanel(client, "info", kv, display);
	CloseHandle(kv);
}


stock String:CSGO_Browse_Fix(String:szStationName[])
{
	decl String:szWrappedStation[MAX_STATION_URL_SIZE] = "";
	
	Format(szWrappedStation, sizeof(szWrappedStation), "%s?radiourl=%s", g_szCSGOWrapperURL, szStationName);
	return szWrappedStation;
}
