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

public Plugin:myinfo =
{
    name = "In Game Audio Donator Intro",
    author = "CrimsonTautology",
    description = "Play donator's theme song when they join the server",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

public OnPostDonatorCheck(client)
{
    if(IsIGAEnabled())
    {
        UserTheme(client);
    }
}
