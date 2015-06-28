public Plugin:myinfo =
{
	name = "Buttons",
	author = "Azelphur",
	description = "Press buttons by shooting",
	version = "1.0",
	url = "http://Azelphur.com/"
};

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon) {
	if (buttons & IN_ATTACK || buttons & IN_ATTACK2 || buttons & IN_RELOAD)
		buttons |= IN_USE;
	return Plugin_Continue;
}
