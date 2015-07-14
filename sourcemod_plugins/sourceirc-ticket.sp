/*
       This file is part of SourceIRC.

    SourceIRC is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    SourceIRC is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with SourceIRC.  If not, see <http://www.gnu.org/licenses/>.
*/
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <sourceirc>
#include <spraymanager>
#include <sourcepunish>


#pragma semicolon 1

new String:ReportString[MAXPLAYERS+1][512];

new Handle:kv;
new String:SPRAY_REPLY_PREFIX[20] = "\x01[\x04Report\x01]";

new blockedPlayers[MAXPLAYERS+1]; // SourcePunish: Logged-in players who aren't allowed to use the report function

public Plugin:myinfo = {
	name = "SourceIRC -> Ticket",
	author = "Azelphur / Monster Killer / Alex",
	description = "Adds a report command in game for players to report problems to staff in an IRC channel",
	version = IRC_VERSION,
	url = "http://Azelphur.com/project/sourceirc"
};

public OnPluginStart() {	
	LoadTranslations("common.phrases");
	LoadTranslations("spraymanager.phrases");
	RegConsoleCmd("report", Command_Support);
	RegConsoleCmd("reply", Command_Reply);
	kv = CreateKeyValues("SourceIRC");
	decl String:file[512];
	BuildPath(Path_SM, file, sizeof(file), "configs/sourceirc.cfg");
	FileToKeyValues(kv, file);
}

public OnAllPluginsLoaded() {
	if (LibraryExists("sourceirc"))
		IRC_Loaded();
	if (LibraryExists("sourcepunish"))
		Punish_Loaded();
}

public OnLibraryAdded(const String:name[]) {
	if (StrEqual(name, "sourceirc"))
		IRC_Loaded();
	if (StrEqual(name, "sourcepunish"))
		Punish_Loaded();
}

IRC_Loaded() {
	IRC_CleanUp(); // Call IRC_CleanUp as this function can be called more than once.
	IRC_RegCmd("report", Command_IRCReport, "report <nick> [reason] - Reports player from IRC");
	IRC_RegAdminCmd("to", Command_To, ADMFLAG_CHAT, "to <name|#userid> <text> - Send a message to a player");
}

Punish_Loaded() {
	RegisterPunishment("silencereports", "Silence report", SilencePlayerReports, UnsilencePlayerReports, 0, ADMFLAG_CHAT);
}

public OnClientDisconnect(client) {
	blockedPlayers[client] = false;
}

public SilencePlayerReports(client, String:reason[], String:adminName[]) {
	blockedPlayers[client] = true;
}

public UnsilencePlayerReports(client) {
	blockedPlayers[client] = false;
}

public Action:Command_IRCReport(const String:nick[], args) {
	if (args < 2)
	{
		IRC_ReplyToCommand(nick, "Usage: !report <name> [reason]");
		return Plugin_Handled;
	}
	if ((KvJumpToKey(kv, "Ticket")) && (KvJumpToKey(kv, "Settings"))) {
		decl String:irc_reports[10];
		KvGetString(kv, "irc_reports", irc_reports, sizeof(irc_reports), "");
		if(StrEqual(irc_reports, "1"))
		{
			decl String:destination[64], String:text[IRC_MAXLEN], String:mynick[64];
			IRC_GetCmdArgString(text, sizeof(text));
			IRC_GetNick(mynick, sizeof(mynick));
			new startpos = BreakString(text, destination, sizeof(destination));
			decl String:custom_msg[IRC_MAXLEN];
			KvGetString(kv, "custom_msg", custom_msg, sizeof(custom_msg), "");
			if (!StrEqual(custom_msg, "")) {
				IRC_MsgFlaggedChannels("ticket", custom_msg);
			}
			KvRewind(kv);
			IRC_MsgFlaggedChannels("ticket", "[IRC] %s has reported %s for %s in IRC", nick, destination, text[startpos]);
			IRC_MsgFlaggedChannels("ticket", "[IRC] Use /query %s - To reply", nick);
			IRC_ReplyToCommand(nick, "You have reported %s for %s. An admin has been notified.", destination, text[startpos]);
		} else {
			IRC_ReplyToCommand(nick, "Reports from IRC is not enabled.");
		}
	}
	KvRewind(kv);
	return Plugin_Handled;
}

public Action:Command_Reply(client, args) {
	if (blockedPlayers[client]) {
		return Plugin_Handled;
	}
	decl String:Args[256], String:name[64], String:auth[64];
	GetCmdArgString(Args, sizeof(Args));
	if (StrEqual(Args, ""))
		return Plugin_Handled;
	GetClientName(client, name, sizeof(name));
	GetClientAuthString(client, auth, sizeof(auth));
	IRC_MsgFlaggedChannels("ticket", "%s (%s) :  %s", name, auth, Args);
	PrintToChat(client, "To ADMIN :  %s", Args);
	return Plugin_Handled;
}

public Action:Command_To(const String:nick[], args) {
	decl String:destination[64], String:text[IRC_MAXLEN];
	IRC_GetCmdArgString(text, sizeof(text));
	new startpos = BreakString(text, destination, sizeof(destination));
	new target = FindTarget(0, destination, true, false);
	if (target != -1) {
		PrintToChat(target, "\x01[\x04IRC\x01] \x03(ADMIN) %s\x01 :  %s", nick, text[startpos]);
	}
	else {
		IRC_ReplyToCommand(nick, "Unable to find %s", destination);
	}
	return Plugin_Handled;
}

public Action:Command_Support(client, args) {
	if (blockedPlayers[client]) {
		return;
	}
	new Handle:hMenu=CreateMenu(MenuHandler_Report);
	SetMenuTitle(hMenu,"What do you want to report for?");
	if (!KvJumpToKey(kv, "Ticket")) return;
	if (!KvJumpToKey(kv, "Menu")) return;
	if (!KvGotoFirstSubKey(kv, false)) return;
	decl String:key[64], String:value[64];
	do
	{
		KvGetSectionName(kv, key, sizeof(key));
		KvGetString(kv, NULL_STRING, value, sizeof(value));
		AddMenuItem(hMenu, key, value);
	} while (KvGotoNextKey(kv, false));

	KvRewind(kv);
	
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_Report(Handle:hMenu, MenuAction:action, param1, param2) {
	if(action==MenuAction_Select) {
		GetMenuItem(hMenu, param2, ReportString[param1], sizeof(ReportString[]));
		if (StrEqual(ReportString[param1], "{Special:Spray}"))
			SprayMenu(param1);
		else
			ShowPlayerList(param1);
	}
}

SprayMenu(client) {
	new Handle:hMenu = CreateMenu(MenuHandler_SprayMenu);
	SetMenuTitle(hMenu, "Aim at the spray you wish to report, then press ok.");
	AddMenuItem(hMenu, "Ok", "Ok");
	SetMenuExitBackButton(hMenu, true);
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_SprayMenu(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
		Command_Support(param1, 0);
	}
	else if (action == MenuAction_Select) {
		new spraytargetUserID= Spray_TraceSpray(GetClientUserId(param1));
		new target = GetClientOfUserId(spraytargetUserID);
		if (!target) {
			PrintToChat(param1, "%s %t", SPRAY_REPLY_PREFIX, "Spray Pos Not Found");
			SprayMenu(param1);
		}
		else {
			decl String:sprayurl[255];
			new TargetUserID = GetClientUserId(target);

			new SprayGenUrl = Spray_GenURL(TargetUserID, sprayurl, sizeof(sprayurl));
			
			if(!SprayGenUrl)
			{
				PrintToChat(param1, "%s %t", SPRAY_REPLY_PREFIX, "Spray No Find");
			} else {
				Format(ReportString[param1], sizeof(ReportString[]), "Bad spray: %s", sprayurl);
				Report(param1, target, ReportString[param1]);
			}
		}
	}
}

ShowPlayerList(client) {
	new Handle:hMenu = CreateMenu(MenuHandler_PlayerList);
	decl String:title[256];
	Format(title, sizeof(title), "Who do you want to report for %s", ReportString[client]);
	SetMenuTitle(hMenu, title);
	SetMenuExitBackButton(hMenu, true);
	new maxclients = GetMaxClients();
	decl String:disp[64], String:info[64];
	for (new i = 1; i <= maxclients; i++) {
		if (IsClientConnected(i) && !IsFakeClient(i)) {
			GetClientName(i, disp, sizeof(disp));
			IntToString(GetClientUserId(i), info, sizeof(info));
			AddMenuItem(hMenu, info, disp);
		}
	}
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public MenuHandler_PlayerList(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
		Command_Support(param1, 0);
	}
	else if (action == MenuAction_Select) {
		decl String:info[32];
		GetMenuItem(menu, param2, info, sizeof(info));
		new client = GetClientOfUserId(StringToInt(info));

		if (!client) {
			PrintToChat(param1, "Player disconnected, sorry!");
		}
		else {
			Report(param1, client, ReportString[param1]);
		}
	}
}

Report(client, target, String:info[]) {
	decl String:name[64], String:auth[64], String:targetname[64], String:targetauth[64], String:mynick[64];
	GetClientName(client, name, sizeof(name));
	GetClientAuthString(client, auth, sizeof(auth));
	GetClientName(target, targetname, sizeof(targetname));
	GetClientAuthString(target, targetauth, sizeof(targetauth));
	IRC_GetNick(mynick, sizeof(mynick));
	if ((KvJumpToKey(kv, "Ticket")) && (KvJumpToKey(kv, "Settings"))) {
		decl String:custom_msg[IRC_MAXLEN];
		KvGetString(kv, "custom_msg", custom_msg, sizeof(custom_msg), "");
		if (!StrEqual(custom_msg, "")) {
			IRC_MsgFlaggedChannels("ticket", custom_msg);
		}
	}
	KvRewind(kv);

	new ClientTeam;
	if (target != 0 && IsClientConnected(client))
		ClientTeam = IRC_GetTeamColor(GetClientTeam(client));
	else
		ClientTeam = 0;
	new TargetTeam;
	if (target != 0 && IsClientConnected(target))
		TargetTeam = IRC_GetTeamColor(GetClientTeam(target));
	else
		TargetTeam = 0;

	IRC_MsgFlaggedChannels("ticket", "\x03%02d%s\x03 (%s) has reported \x03%02d%s\x03 (%s) for %s", ClientTeam, name, auth, TargetTeam, targetname, targetauth, info);
	IRC_MsgFlaggedChannels("ticket", "use %s to #%d <message> - To reply", mynick, GetClientUserId(client));
	PrintToChat(client, "\x01Your report has been sent. Type \x04/reply your message here\x01 to chat with the admins.");
}

public OnPluginEnd() {
	IRC_CleanUp();
}

// http://bit.ly/defcon
