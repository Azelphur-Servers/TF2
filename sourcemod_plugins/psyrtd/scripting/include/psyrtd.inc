#if defined _psyrtd_included_
	#endinput
#endif
#define _psy_included_

#define PSYRTDAPIVERSION 2

#define psyRTDEffectType_Bad 0
#define psyRTDEffectType_Good 1

enum psyRTDAction {
	psyRTD_Continue,       // accept the roll
	psyRTD_NotApplicable,  // effect doesn't work on or apply to current player (ex. because of class/team/game/state)
	                       //   this will trigger a re-roll automatically if psyrtd_allowunusable is set to 0 (default)
	psyRTD_Reroll          // re-roll (usually because effect is disabled. return the former value if effect just doesn't apply
};

enum psyRTDGame {
	psyRTDGame_Unknown = -1,
	psyRTDGame_CSS,
	psyRTDGame_DODS,
	psyRTDGame_L4D,
	psyRTDGame_L4D2,
	psyRTDGame_TF,
	psyRTDGame_HL2MP,
	psyRTDGame_INSMOD,  // Insurgency
	psyRTDGame_FF,      // Fortress Forever
	psyRTDGame_ZPS,     // Zombie Panic: Source
	psyRTDGame_AOC,     // Age of Chivalry
	psyRTDGame_FOF,     // Fistful of Frags
	psyRTDGame_GES,     // Goldeneye: Source
	psyRTDGame_DM       // Dark Messiah
};

enum psyRTDEffectEndReason {
	psyRTDEndReason_Unknown,
	psyRTDEndReason_TimeExpired,
	psyRTDEndReason_PlayerDied,
	psyRTDEndReason_PlayerLeft  //  uses OnClientDisconnect
};

functag psyRTDEffectCallback psyRTDAction:public(client);

functag psyRTDEffectEndCallback public(client, psyRTDEffectEndReason:reason);

/**
 * Register an RTD effect
 * 
 * @param effectType	Type of effect, good or bad.
 * @param func			Callback to use for RTD effect.
 * @return				RTD effect id to use when unregistering.
 */
native psyRTD_RegisterEffect(type, const String:name[], psyRTDEffectCallback:callback);

native psyRTD_RegisterTimedEffect(type, const String:name[], Float:duration, psyRTDEffectCallback:starteffect, psyRTDEffectEndCallback:killeffect);

native psyRTD_ChangeEffectDuration(iRTDEffectId, effectType, Float:duration);

/**
 * Unregister an RTD effect
 *
 * @param iRTDEffectId	The RTD effect id to remove.
 * @return				Nothing.
 */
native psyRTD_UnregisterEffect(iRTDEffectId, effectType);

/**
 * Unregisters all RTD effects registered by calling plugin
 *
 * @return				Nothing.
 */
native psyRTD_UnregisterAllEffects();

/**
 * Prints a message with the RTD tag
 *
 * @param client		Client index.
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */
native psyRTD_PrintToChat(client, const String:format[], any:...);
 
/**
 * Prints a message to all clients in the chat area.
 *
 * @param format		Formatting rules.
 * @param ...			Variable number of format parameters.
 * @noreturn
 */
stock psyRTD_PrintToChatAll(const String:format[], any:...)
{
	decl String:buffer[192];
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetGlobalTransTarget(i);
			VFormat(buffer, sizeof(buffer), format, 2);
			PrintToChat(i, "%s", buffer);
		}
	}
}

/**
 * Get game that server is running
 *
 * @return				Server game.
 */
native psyRTDGame:psyRTD_GetGame();


public SharedPlugin:__pl_psyrtd = 
{
	name = "psyrtd",
	file = "psyrtd.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};