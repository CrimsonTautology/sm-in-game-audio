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
#include <donator>

#define PLUGIN_VERSION "0.2"

new Handle:g_DelayTimer[MAXPLAYERS+1] = {INVALID_HANDLE, ...};

new bool:g_CanIntroPlay[MAXPLAYERS+1];

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
}

public OnPostDonatorCheck(client)
{
    g_CanIntroPlay[client] = IsPlayerDonator(client);
}

public Action:Event_JoinClass(client, const String:command[], args)
{
    if(g_CanIntroPlay[client])
    {
        g_DelayTimer[client] = CreateTimer(1.0, PlayDonatorIntro, client);
        g_CanIntroPlay[client] = false;
    }

    return Plugin_Continue;
}

public Action:PlayDonatorIntro(Handle:Timer, any:client)
{
    UserTheme(client);
    g_DelayTimer[client] = INVALID_HANDLE; //TODO is this needed?
}
