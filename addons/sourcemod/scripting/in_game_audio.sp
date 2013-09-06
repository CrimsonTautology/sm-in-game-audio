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

#define PLUGIN_VERSION "0.1"

public Plugin:myinfo =
{
    name = "",
    author = "",
    description = "",
    version = PLUGIN_VERSION,
    url = ""
};

new Handle:g_Cvar_DonatorsOnly = INVALID_HANDLE;
new Handle:g_Cvar_ApiKey = INVALID_HANDLE;
new Handle:g_Cvar_ApiUrl = INVALID_HANDLE;
new Handle:g_Cvar_Enabled = INVALID_HANDLE;

public OnPluginStart()
{
    
    g_Cvar_DonatorsOnly = CreateConVar(sm_donators_only, "1", "TODO - Add a description for this cvar");
    g_Cvar_ApiKey = CreateConVar(sm_api_key, "1", "TODO - Add a description for this cvar");
    g_Cvar_ApiUrl = CreateConVar(sm_api_url, "1", "TODO - Add a description for this cvar");
    g_Cvar_Enabled = CreateConVar(sm_enabled, "1", "TODO - Add a description for this cvar");
    
    RegConsoleCmd("sm_p", Command_P, "TODO - Add a description for this cmd");
    RegConsoleCmd("sm_pall", Command_Pall, "TODO - Add a description for this cmd");
    RegConsoleCmd("sm_plist", Command_Plist, "TODO - Add a description for this cmd");
    RegConsoleCmd("sm_stop", Command_Stop, "TODO - Add a description for this cmd");
    RegConsoleCmd("sm_fstop", Command_Fstop, "TODO - Add a description for this cmd");
    RegConsoleCmd("sm_fpall", Command_Fpall, "TODO - Add a description for this cmd");
    RegConsoleCmd("sm_vol", Command_Vol, "TODO - Add a description for this cmd");
    RegConsoleCmd("sm_nopall", Command_Nopall, "TODO - Add a description for this cmd");
    RegConsoleCmd("sm_plast", Command_Plast, "TODO - Add a description for this cmd");
    
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
