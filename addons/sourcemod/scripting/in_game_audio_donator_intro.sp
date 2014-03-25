/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio_donator_intro
 * Plays a user's theme song when they join the server if they are a donator.
 * A user's theme is set through the In Game Audio website.
 *
 * Copyright 2013 Crimsontautology
 * =============================================================================
 *
 */


#pragma semicolon 1

#include <sourcemod>
#include <in_game_audio>
#undef REQUIRE_PLUGIN
#include <donator>

#define PLUGIN_VERSION "1.0"

new bool:g_CanIntroPlay[MAXPLAYERS+1];
new bool:g_DonatorLibraryExists = false;

public Plugin:myinfo =
{
    name = "In Game Audio Donator Intro",
    author = "CrimsonTautology",
    description = "Play donator's theme song when they join the server",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

public OnPluginStart()
{
    AddCommandListener(Event_JoinClass, "joinclass");
    g_DonatorLibraryExists = LibraryExists("donators");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("IsPlayerDonator");
	return APLRes_Success;
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "donators"))
	{
		g_DonatorLibraryExists = false;
	}
}
 
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "donators"))
	{
		g_DonatorLibraryExists = true;
	}
}

public OnPostDonatorCheck(client)
{
    if (g_DonatorLibraryExists)
    {
        g_CanIntroPlay[client] = IsPlayerDonator(client);
    }
}

public Action:Event_JoinClass(client, const String:command[], args)
{
    if(g_CanIntroPlay[client])
    {
        UserTheme(client);
        g_CanIntroPlay[client] = false;
    }

    return Plugin_Continue;
}
