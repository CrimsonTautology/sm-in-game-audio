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

#define PLUGIN_VERSION "1.8.3"
#define PLUGIN_NAME "In Game Audio Donator Intro"


new bool:g_CanIntroPlay[MAXPLAYERS+1];
new bool:g_DonatorLibraryExists = false;

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "Play donator's theme song when they join the server",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

public OnPluginStart()
{
    LoadTranslations("in_game_audio.phrases");

    CreateConVar("sm_iga_donator_intro_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

    AddCommandListener(Event_JoinClass, "joinclass");
    g_DonatorLibraryExists = LibraryExists("donator.core");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    MarkNativeAsOptional("IsPlayerDonator");
    MarkNativeAsOptional("Donator_RegisterMenuItem");
    return APLRes_Success;
}

public OnLibraryRemoved(const String:name[])
{
    if (StrEqual(name, "donator.core"))
    {
        g_DonatorLibraryExists = false;
    }
}

public OnLibraryAdded(const String:name[])
{
    if (StrEqual(name, "donator.core"))
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

public OnClientConnected(client)
{
    if (!g_DonatorLibraryExists)
    {
        g_CanIntroPlay[client] = true;
    }
}

public OnClientDisconnect(client)
{
    g_CanIntroPlay[client] = false;
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

