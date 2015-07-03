/*
-----------------------------------------------------------------------------
SCARY GMAN SCREAMER FACE - SOURCEMOD PLUGIN
-----------------------------------------------------------------------------
Code Written By Michelle Sleeper (c) 2010
Inspired by Azelphur / Plex (game.azelphur.com)
Visit http://www.msleeper.com/ for more info!
-----------------------------------------------------------------------------
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "1.1"

#define SCREAMER_SOUND "npc/stalker/go_alert2a.wav"

// Plugin Info
public Plugin:myinfo =
{
	name = "Scary Gman Screamer Face",
	author = "msleeper",
	description = "Scares players shitless",
	version = PLUGIN_VERSION,
	url = "http://www.msleeper.com/"
};

// Here we go!
public OnPluginStart()
{
	RegAdminCmd("sm_screamer", Command_Screamer, ADMFLAG_SLAY, "sm_screamer <#userid|name>");
}

public OnMapStart()
{
	PrecacheSound(SCREAMER_SOUND, true);
}

public Action:Command_Screamer(client, args)
{
	if ( args < 1 )
	{
		ReplyToCommand(client, "[SM] Usage: sm_screamer <client>");
		return Plugin_Handled;
	}

	decl String:player[64];
	GetCmdArg(1, player, sizeof(player));

	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count;
	new bool:tn_is_ml;
 
	if ( (target_count = ProcessTargetString(
			player,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_BOTS,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0 )
	{
		ReplyToCommand(client, "[SM] No matching client");
		return Plugin_Handled;
	}

	for ( new i=0; i<target_count; i++ )
	{
		Screamer(client, target_list[i]);
	}

	return Plugin_Handled;
}

stock Screamer(client, target)
{
	new Handle:cvarCheats;
	cvarCheats = FindConVar("sv_cheats");

	if ( target > 0 && target <= MaxClients )
	{
		if ( IsClientConnected(target) && IsClientInGame(target) )
		{
			EmitSoundToClient(target, SCREAMER_SOUND);

			SendConVarValue(target, cvarCheats, "1");
			ClientCommand(target, "r_screenoverlay models/gman/gman_facehirez");
			SendConVarValue(target, cvarCheats, "0");

			CreateTimer(0.20, Timer_Screamer, target, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action:Timer_Screamer(Handle:timer, any:client)
{
	new Handle:cvarCheats;
	cvarCheats = FindConVar("sv_cheats");

	if ( IsClientConnected(client) && IsClientInGame(client) )
	{
		SendConVarValue(client, cvarCheats, "1");
		ClientCommand(client, "r_screenoverlay off");
		SendConVarValue(client, cvarCheats, "0");
	}
}


