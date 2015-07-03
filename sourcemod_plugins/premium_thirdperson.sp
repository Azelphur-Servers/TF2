#pragma semicolon 1

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#undef REQUIRE_PLUGIN


new Handle:g_hThirdpersonState;
new bool:g_bIsPremium[MAXPLAYERS+1];
new bool:g_bTPEnabled[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "ThirdPerson",
	author = "MonsterKiller",
	description = "Allows ThirdPerson",
	version = "1.0",
	url = "http://monsterprojects.org"
};


public OnPluginStart()
{
	RegAdminCmd("sm_thirdperson", Command_Thirdperson, ADMFLAG_CUSTOM1, "Toggle thirdperson");
	HookEvent("player_spawn", OnPlayerSpawned);
	HookEvent("player_class", OnPlayerSpawned);
	g_hThirdpersonState = RegClientCookie("thirdperson", "Turns thirdperson on/off", CookieAccess_Public);
}

public OnClientPostAdminCheck(client)
{
	new AdminId:iId = GetUserAdmin(client);
	if (iId != INVALID_ADMIN_ID)
	{
		new iFlags = GetAdminFlags(iId, Access_Effective);
		if (iFlags & ADMFLAG_CUSTOM1 || iFlags & ADMFLAG_ROOT)
		{
			g_bIsPremium[client] = true;
			return;
		}
	}
	g_bIsPremium[client] = false;
}

public OnClientCookiesCached(client)
{
	decl String:szCookie[64];
	GetClientCookie(client, g_hThirdpersonState, szCookie, sizeof(szCookie));
	if (StrEqual(szCookie, "Turn thirdperson on [thirdperson on]"))
	{
		g_bTPEnabled[client] = false;
	}
	else
	{
		g_bTPEnabled[client] = true;
	}
}

public Action:OnPlayerSpawned(Handle:event, const String:name[], bool:dontBroadcast)
{
	new userid = GetEventInt(event, "userid");
	if(g_bTPEnabled[GetClientOfUserId(userid)] && g_bIsPremium[GetClientOfUserId(userid)])
	{
		CreateTimer(0.2, SetTPOnSpawn, userid);
	}
}

public Action:SetTPOnSpawn(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (client != 0)
	{
		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
	} 
}

public Action:Command_Thirdperson(client, args)
{
	decl String:szChatString[64];
	GetClientCookie(client, g_hThirdpersonState, szChatString, sizeof(szChatString));
	if (StrEqual(szChatString, "Turn thirdperson on [thirdperson on]"))
	{
		SetClientCookie(client, g_hThirdpersonState, "Turn thirdperson off [thirdperson off]");
		SetVariantInt(1);
		AcceptEntityInput(client, "SetForcedTauntCam");
		g_bTPEnabled[client] = true;
		return Plugin_Handled;
	}
	else
	{
		SetClientCookie(client, g_hThirdpersonState, "Turn thirdperson on [thirdperson on]");
		SetVariantInt(0);
		AcceptEntityInput(client, "SetForcedTauntCam");
		g_bTPEnabled[client] = false;
		return Plugin_Handled;
	}
}
