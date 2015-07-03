#include <sourcemod>
#include <sdktools>

public Plugin:myinfo =
{
	name = "Spamless Slap",
	author = "Monster Killer",
	description = "Lets you slap players without spamming text chat",
	version = "1.0"
};

public OnPluginStart()
{
	RegAdminCmd("sm_slslap", Command_SpamlessSlap, ADMFLAG_KICK, "Slap all players")
}

public Action:Command_SpamlessSlap(client, args)
{
	for (new i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			SlapPlayer(i, 0, true)
		}
	}
	return Plugin_Handled
}
