/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio_vip_intro
 * Plays a user's theme song when they join the server if they are a VIP (has adminflag 'O').
 * A user's theme is set through the In Game Audio website.
 *
 * Copyright 2013 Crimsontautology
 * =============================================================================
 *
 */


#pragma semicolon 1

#include <sourcemod>
#include <in_game_audio>

#define PLUGIN_VERSION "1.10.0"
#define PLUGIN_NAME "In Game Audio VIP Intro"


new bool:g_CanIntroPlay[MAXPLAYERS+1];

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "Play VIP's theme song when they join the server",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

public OnPluginStart()
{
    LoadTranslations("in_game_audio.phrases");

    CreateConVar("sm_iga_vip_intro_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

    AddCommandListener(Event_JoinClass, "joinclass");
}

public OnClientPostAdminCheck(client)   
{  
    new flags = GetUserFlagBits(client);  
    if ((flags & ADMFLAG_CUSTOM1)) // Everyone with the flag "O"
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

