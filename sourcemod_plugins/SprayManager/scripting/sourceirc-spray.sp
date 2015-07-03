#undef REQUIRE_PLUGIN
#pragma semicolon 1

#include <sourceirc>
#include <spraymanager>
#include <sourcemod>
#include <sdktools>

new String:SPRAY_REPLY_PREFIX[20] = "\x01[\x04Spray\x01]";

public Plugin:myinfo = 
{
	name = "SourceIRC -> Spray Manager",
	author = "Monster Killer",
	description = "Remove, Block and View Sprays",
	version = "1.4.1",
	url = "http://MonsterProjects.org/"
};

public OnPluginStart() {	
	LoadTranslations("common.phrases");
	LoadTranslations("spraymanager.phrases");
}

public OnAllPluginsLoaded() {
	if (LibraryExists("sourceirc"))
		IRC_Loaded();
}

public OnLibraryAdded(const String:name[]) {
	if (StrEqual(name, "sourceirc"))
		IRC_Loaded();
}

IRC_Loaded() {
	IRC_CleanUp(); // Call IRC_CleanUp as this function can be called more than once.
	IRC_RegAdminCmd("playerspray", Command_PlayerSpray, ADMFLAG_KICK, "playerspray <#id|name> - view a players spray");
	IRC_RegAdminCmd("removespray", Command_RemoveSpray, ADMFLAG_KICK, "removespray <#id|name> - removes a players spray");
	IRC_RegAdminCmd("blockspray", Command_BlockSpray, ADMFLAG_KICK, "blockspray <#id|name> - blocks and removes a players spray");
	IRC_RegAdminCmd("unblockspray", Command_UnBlockSpray, ADMFLAG_KICK, "unblockspray <#id|name> - unblocks a players spray");
	IRC_RegAdminCmd("blocksprayfile", Command_BlockSprayFile, ADMFLAG_KICK, "blocksprayfile <spray file> - blocks a spray file");
	IRC_RegAdminCmd("unblocksprayfile", Command_UnBlockSprayFile, ADMFLAG_KICK, "unblocksprayfile <spray file> - unblocks a spray file");
	IRC_RegAdminCmd("warnspray", Command_SprayWarn, ADMFLAG_KICK, "blockspray <#id|name> - blocks a players spray and warns");
}

public Action:Command_PlayerSpray(const String:nick[], args)
{
	decl String:reply[255];
	
	new bool:IsViewDisabled = Spray_IsViewDisabled();
	if(IsViewDisabled) {
		Format(reply, sizeof(reply), "%t", "Spray Cmd Disabled");
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	}
	
	if (args < 1) {
		Format(reply, sizeof(reply), "%t", "Spray No Args");
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	}
	
	decl String:Player[255], String:text[IRC_MAXLEN];
	IRC_GetCmdArgString(text, sizeof(text));
	BreakString(text, Player, sizeof(Player));
	new target = FindTarget(0, Player, true, false);
	
	if(target == -1)
	{
		Format(reply, sizeof(reply), "%t", "Spray No Player" );
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	} else {
		new TargetUserID = GetClientUserId(target);
		if(Spray_HasUserSprayed(TargetUserID) == false)
		{
			Format(reply, sizeof(reply), "%t", "Spray No Spray" );
			IRC_ReplyToCommand(nick, reply);
			return Plugin_Handled;
		}
		decl String:TargetName[100], String:sprayurl[255];
		GetClientName(target, TargetName, sizeof(TargetName));
		
		new bool:GotSpray = Spray_GenURL(TargetUserID, sprayurl, sizeof(sprayurl));
		
		if(!GotSpray) {
			Format(reply, sizeof(reply), "%t", "Spray No Find");
		} else {
			Format(reply, sizeof(reply), "%s's Spray: %s", TargetName, sprayurl);
		}
		IRC_ReplyToCommand(nick, reply);
		
		return Plugin_Handled;
	}
}

public Action:Command_RemoveSpray(const String:nick[], args)
{
	decl String:reply[100];
	
	if (args < 1) {
		Format(reply, sizeof(reply), "%t", "Spray No Args" );
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	}
	
	decl String:Player[255], String:text[IRC_MAXLEN];
	IRC_GetCmdArgString(text, sizeof(text));
	BreakString(text, Player, sizeof(Player));
	new target = FindTarget(0, Player, true, false);
	
	if(target == -1)
	{
		Format(reply, sizeof(reply), "%t", "Spray No Player" );
		IRC_ReplyToCommand(nick, reply);
	} else {
		new TargetUserID = GetClientUserId(target);
		if(Spray_HasUserSprayed(TargetUserID) == false)
		{
			Format(reply, sizeof(reply), "%t", "Spray No Spray" );
			IRC_ReplyToCommand(nick, reply);
			return Plugin_Handled;
		}
		ReSprayDecal(target, nick);
	}
	return Plugin_Handled;
}

public ReSprayDecal(client, const String:nick[])
{
	new RemoveSpray = Spray_Remove(GetClientUserId(client));
	
	decl String:reply[100];
	
	if(RemoveSpray == 1)
	{
		Format(reply, sizeof(reply), "%t", "Spray No Spray" );
		IRC_ReplyToCommand(nick, reply);
	} else if(RemoveSpray == 0) 
	{
		Format(reply, sizeof(reply), "%t", "Spray Removed" );
		IRC_ReplyToCommand(nick, reply);
	} else if(RemoveSpray == 2)
	{
		Format(reply, sizeof(reply), "%t", "Spray Not Ingame" );
		IRC_ReplyToCommand(nick, reply);
	} else {
		Format(reply, sizeof(reply), "%t", "Spray Error", "Error removing spray!" );
		IRC_ReplyToCommand(nick, reply);
	}
}

public Action:Command_BlockSpray(const String:nick[], args)
{
	decl String:reply[100];
	
	if (args < 1) {
		Format(reply, sizeof(reply), "%t", "Spray No Args" );
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	}
	
	decl String:Player[255], String:text[IRC_MAXLEN];
	IRC_GetCmdArgString(text, sizeof(text));
	BreakString(text, Player, sizeof(Player));
	new target = FindTarget(0, Player, true, false);
	
	if(target == -1)
	{
		Format(reply, sizeof(reply), "%t", "Spray No Player" );
		IRC_ReplyToCommand(nick, reply);
	} else {
		new TargetUserID = GetClientUserId(target);
		decl String:SprayFile[20];
		Spray_GetFile(TargetUserID, SprayFile, sizeof(SprayFile));
		Spray_Remove(TargetUserID);
		Spray_SprayBlock(SprayFile, TargetUserID, true);
		Format(reply, sizeof(reply), "%t", "Spray Block Attempt" );
		IRC_ReplyToCommand(nick, reply);
	}
	return Plugin_Handled;
}

public Action:Command_UnBlockSpray(const String:nick[], args)
{
	decl String:reply[100];
	
	if (args < 1) {
		Format(reply, sizeof(reply), "%t", "Spray No Args" );
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	}
	
	decl String:Player[255], String:text[IRC_MAXLEN];
	IRC_GetCmdArgString(text, sizeof(text));
	BreakString(text, Player, sizeof(Player));
	new target = FindTarget(0, Player, true, false);
	
	if(target == -1)
	{
		Format(reply, sizeof(reply), "%t", "Spray No Player" );
		IRC_ReplyToCommand(nick, reply);
	} else {
		new TargetUserID = GetClientUserId(target);
		decl String:SprayFile[20];
		Spray_GetFile(TargetUserID, SprayFile, sizeof(SprayFile));
		Spray_SprayBlock(SprayFile, TargetUserID, false);
		Format(reply, sizeof(reply), "%t", "Spray UnBlock Attempt" );
		IRC_ReplyToCommand(nick, reply);
	}
	return Plugin_Handled;
}

public Action:Command_BlockSprayFile(const String:nick[], args)
{
	decl String:reply[100];
	
	if (args < 1) {
		Format(reply, sizeof(reply), "%t", "Spray No Args Spray File" );
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	}
	
	decl String:SprayFile[10];
	IRC_GetCmdArg(1, SprayFile, sizeof(SprayFile));

	if(strlen(SprayFile) < 8 || strlen(SprayFile) > 10)
	{
		Format(reply, sizeof(reply), "%t", "Spray Invalid Command");
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	}
	
	Spray_SprayBlock(SprayFile, -1, true);
	Format(reply, sizeof(reply), "%t", "Spray Block Attempt" );
	IRC_ReplyToCommand(nick, reply);
	return Plugin_Handled;
}

public Action:Command_UnBlockSprayFile(const String:nick[], args)
{
	decl String:reply[100];
	
	if (args < 1) {
		Format(reply, sizeof(reply), "%t", "Spray No Args Spray File");
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	}
	
	decl String:SprayFile[10];
	IRC_GetCmdArg(1, SprayFile, sizeof(SprayFile));

	if(strlen(SprayFile) < 8 || strlen(SprayFile) > 10)
	{
		Format(reply, sizeof(reply), "%t", "Spray Invalid Command" );
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	}

	Spray_SprayBlock(SprayFile, -1, false);
	Format(reply, sizeof(reply), "%t", "Spray UnBlock Attempt" );
	IRC_ReplyToCommand(nick, reply);
	return Plugin_Handled;
}

public Action:Command_SprayWarn(const String:nick[], args)
{
	decl String:reply[100];
	
	if (args < 1) {
		Format(reply, sizeof(reply), "%t", "Spray No Args" );
		IRC_ReplyToCommand(nick, reply);
		return Plugin_Handled;
	}
	
	decl String:Player[255], String:text[IRC_MAXLEN];
	IRC_GetCmdArgString(text, sizeof(text));
	BreakString(text, Player, sizeof(Player));
	new target = FindTarget(0, Player, true, false);
	
	if(target == -1)
	{
		Format(reply, sizeof(reply), "%t", "Spray No Player" );
		IRC_ReplyToCommand(nick, reply);
	} else {
		PrintToChat(target, "%s %t", SPRAY_REPLY_PREFIX, "Spray Player Warning");
		new TargetUserID = GetClientUserId(target);
		decl String:SprayFile[20];
		Spray_GetFile(TargetUserID, SprayFile, sizeof(SprayFile));
		Spray_Remove(TargetUserID);
		Spray_SprayBlock(SprayFile, GetClientUserId(target), true);
		Format(reply, sizeof(reply), "%t", "Spray Block Attempt" );
		IRC_ReplyToCommand(nick, reply);
	}
	return Plugin_Handled;
}

public OnPluginEnd() {
	IRC_CleanUp();
}