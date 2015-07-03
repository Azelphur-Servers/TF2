// Spray manager include file

#if defined _spraymanager_included
  #endinput
#endif
#define _spraymanager_included

/**
 * Check if spray viewing is enabled
 *
 * @return					True if disabled, else false.
 */

native bool:Spray_IsViewDisabled();

/**
 * Creates the spray tracker url for a spray
 *
 * @param userid			UserID of the sprays owner.
 * @param sprayurl			String to store spray URL in.
 * @param maxlength			Maximum length of the buffer.
 * @return					False if spray file isnt found, else true.
 */

native bool:Spray_GenURL(userid, String:sprayurl[], maxlength);

/**
 * Removes a players spray
 *
 * @param userid			UserID of the sprays owner.
 * @return					0 if spray was removed, 1 if player has not sprayed, 2 if the player is not in-game
 */

native Spray_Remove(userid);

/**
 * Gets a players spray file name
 *
 * @param userid			UserID of the sprays owner.
 * @param filename			String to store file name in.
 * @param maxlength			Maximum length of the buffer.
 * @return					False if spray file isnt found, else true.
 */

native Spray_GetFile(userid, String:filename[], maxlength);

/**
 * Gets the target userid of a spray the player is looking at
 *
 * @param userid			UserID of the client running the command.
 * @return					UserID of the target if spray found, else 0.
 */

native Spray_TraceSpray(userid);

/**
 * Blocks a players spray
 *
 * @param sprayfile			File name of the spray to block.
 * @param userid			UserID of the sprays owner, set to -1 is n/a.
 * @param addblock			If set to true, a block will attempted, if false an unblock will be attempted.
 * @no_return
 */

native Spray_SprayBlock(String:sprayfile[], userid, bool:addblock);

/**
 * Gets a players spray file name
 *
 * @param userid			UserID of the sprays owner.
 * @return					True if spray has been used, else false.
 */

native bool:Spray_HasUserSprayed(userid);

