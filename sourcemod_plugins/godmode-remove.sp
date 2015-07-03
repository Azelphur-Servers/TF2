#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

public Plugin:myinfo = 
{
	name = "Remove GodMode",
	author = "Monster Killer",
	description = "Removed Godmode bonus on tensile",
	version = "1.0",
	url = "http://monsterprojects.org"
};

public OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
}

public OnMapStart()
{ 
	RemoveEntity();
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	RemoveEntity();
}

public RemoveEntity()
{
	PrintToServer("****************Remove triggered****************");
	new i = -1;
	while ((i = FindEntityByClassname(i, "filter_damage_type")) != -1) {
		decl String:className[35]; 
		GetEntPropString(i, Prop_Data, "m_iName", className, sizeof(className));
		if(StrEqual(className, "filter_godmode", false)) {
			PrintToServer("Removing filter_damage_type! %s", className);
			AcceptEntityInput(i, "kill");
			break;
		}
	}
	i = -1;
	while ((i = FindEntityByClassname(i, "point_template")) != -1) {
		decl String:className[35]; 
		GetEntPropString(i, Prop_Data, "m_iName", className, sizeof(className));
		if(StrEqual(className, "godmode_template", false)) {
			PrintToServer("Removing point_template! %s", className);
			AcceptEntityInput(i, "kill");
			break;
		}
	}
}