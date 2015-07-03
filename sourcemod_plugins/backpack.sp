#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <csteamid>

public Plugin:myinfo =
{
    name = "MOTD backpack",
    author = "Monster Killer",
    description = "Opens player backpack in MOTD",
    version = "1.0",
    url = "http://monsterprojects.org"
}
public OnPluginStart()
{	
	RegConsoleCmd("sm_backpack", Command_Backpack, "!bp or !backpack [playername]");
	RegConsoleCmd("sm_bp", Command_Backpack, "!bp or !backpack [playername]");
	
	LoadTranslations("common.phrases");
}

public Action:Command_Backpack(client, args) {
	if (args == 0)
	{
		DisplayBackpackMenu(client);
		return Plugin_Handled;
	}
	
	decl String:argstring[128];
	GetCmdArgString(argstring, sizeof(argstring));
	new target = FindTarget(client, argstring, true, false);
	
	if (target == -1) 
	{
		return Plugin_Handled;
    }
	DisplayBackpack(client, target);
	return Plugin_Handled;
}

DisplayBackpackMenu(client)
{
	new Handle:menu = CreateMenu(MenuHandler_Backpack);
	SetMenuTitle(menu, "Choose a player");
	SetMenuExitBackButton(menu, true);
	
	decl String:disp[64], String:info[64];
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && !IsFakeClient(i)) {
			GetClientName(i, disp, sizeof(disp));
			IntToString(GetClientUserId(i), info, sizeof(info));
			AddMenuItem(menu, info, disp);
		}
	}
	//AddTargetsToMenu(menu, 0, true, false);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Backpack(Handle:menu, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
		case MenuAction_Select:
		{
			decl String:info[32];
			new userid, target;
			
			GetMenuItem(menu, param2, info, sizeof(info));
			userid = StringToInt(info);

			if ((target = GetClientOfUserId(userid)) == 0)
			{
				PrintToChat(param1, "%t", "Player no longer available");
			}
			else
			{
				DisplayBackpack(param1, target);
			}
		}
	}
}

public DisplayBackpack(client, target) {
	decl String:steamid[32];
	decl String:itemsurl[128];

	GetClientAuthString(target, steamid, sizeof(steamid));
	
	decl String:Steam64[60];
	new bool:Convert = SteamIDToCSteamID(steamid, Steam64, sizeof(Steam64));
	
	if(Convert) {
		Format(itemsurl, sizeof(itemsurl), "http://tf2b.com/?id=%s&nano=true", Steam64);
		ShowMOTDPanel(client, "Backpack", itemsurl, MOTDPANEL_TYPE_URL);
	} else {
		LogError("Failed to convert steamid: %s", steamid);
		PrintToChat(client, "Unable to get this players backpack in-game.");
	}
}