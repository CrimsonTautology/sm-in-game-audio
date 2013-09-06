/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio
 * TODO - Add your project's description
 *
 * Copyright 2013 ???
 * =============================================================================
 *
 */


#pragma semicolon 1

#include <sourcemod>
#include <socket>
#include <base64>
#include <smjansson>

#define PLUGIN_VERSION "0.1"

public Plugin:myinfo =
{
    name = "",
    author = "",
    description = "",
    version = PLUGIN_VERSION,
    url = ""
};

new Handle:g_Cvar_IGAApiKey = INVALID_HANDLE;
new Handle:g_Cvar_IGAUrl = INVALID_HANDLE;
new Handle:g_Cvar_IGADonatorsOnly = INVALID_HANDLE;
new Handle:g_Cvar_IGAEnabled = INVALID_HANDLE;

public OnPluginStart()
{
    
    g_Cvar_IGAApiKey = CreateConVar(sm_iga_api_key, "", "API Key for your IGA webpage");
    g_Cvar_IGAUrl = CreateConVar(sm_iga_url, "", "URL to your IGA webpage");
    g_Cvar_IGADonatorsOnly = CreateConVar(sm_iga_donators_only, "1", "Whether or not only donators have access to pall");
    g_Cvar_IGAEnabled = CreateConVar(sm_iga_enabled, "1", "Whether or not pall is enabled");
    
    RegConsoleCmd("sm_p", Command_P, "Play a song for yourself");
    RegConsoleCmd("sm_pall", Command_Pall, "Play a song for everyone");
    RegConsoleCmd("sm_plist", Command_Plist, "Pop-up the song list");
    RegConsoleCmd("sm_stop", Command_Stop, "Stop the current song");
    RegConsoleCmd("sm_fstop", Command_Fstop, "[ADMIN] Stop the current pall for everyone");
    RegConsoleCmd("sm_fpall", Command_Fpall, "[ADMIN] Force everyone to listen to a song");
    RegConsoleCmd("sm_vol", Command_Vol, "Adjust your play volume");
    RegConsoleCmd("sm_nopall", Command_Nopall, "Turn off pall for yourself");
    RegConsoleCmd("sm_plast", Command_Plast, "Play the last played song for yourself");
    
    HookEvent("map_change", Event_MapChange);
    HookEvent("client_connect", Event_ClientConnect);
}


public Action:Command_P(client, args)
{
    //TODO
}

public Action:Command_Pall(client, args)
{
    //TODO
}

public Action:Command_Plist(client, args)
{
    //TODO
}

public Action:Command_Stop(client, args)
{
    //TODO
}

public Action:Command_Fstop(client, args)
{
    //TODO
}

public Action:Command_Fpall(client, args)
{
    //TODO
}

public Action:Command_Vol(client, args)
{
    //TODO
}

public Action:Command_Nopall(client, args)
{
    //TODO
}

public Action:Command_Plast(client, args)
{
    //TODO
}


public Event_MapChange(Handle:event, const String:name[], bool:dontBroadcast)
{
    //TODO
}

public Event_ClientConnect(Handle:event, const String:name[], bool:dontBroadcast)
{
    //TODO
}
