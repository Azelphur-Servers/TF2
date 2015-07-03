#pragma semicolon 1
#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
	name = "The Killer",
	author = "Monster Killer",
	description = "Type !kill or !explode to kill yourself.",
	version = "1.0",
	url = "http://monsterprojects.org"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_kill", Command_Kill, "Kill yourself");
	RegConsoleCmd("sm_explode", Command_Explode, "Explode into a billion pieces");
}

public Action:Command_Kill(client, args)
{
	if(IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))
    {
        ForcePlayerSuicide(client);
    }

	return Plugin_Handled;
}

public Action:Command_Explode(client, args)
{
	if(IsClientConnected(client) && IsClientInGame(client) && IsPlayerAlive(client))
    {
        FakeClientCommandEx(client, "explode");
    }

	return Plugin_Handled;
}