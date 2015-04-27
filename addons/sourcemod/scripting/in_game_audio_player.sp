/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio_player
 * Allows players to play songs to themselves and to others with !p and !pall
 * as well as commands to stop the currently playing song with !stop.  Includes
 * admin commands to force stop and force play songs with !fstop and !fpall.
 *
 * Copyright 2013 ???
 * =============================================================================
 *
 */

#pragma semicolon 1

#include <sourcemod>
#include <in_game_audio>
#include <morecolors>

#define PLUGIN_VERSION "1.8.4"
#define PLUGIN_NAME "In Game Audio Player"

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "User commands to play and stop songs",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

new Handle:g_Cvar_VIPsOnly = INVALID_HANDLE;
new bool:g_IsVIP[MAXPLAYERS+1];

public OnPluginStart()
{
    LoadTranslations("in_game_audio.phrases");

    CreateConVar("sm_iga_player_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
    g_Cvar_VIPsOnly = CreateConVar("sm_iga_vips_only", "0", "Whether only VIPs can use pall");

    RegConsoleCmd("sm_p", Command_P, "Play a song for yourself");
    RegConsoleCmd("sm_pall", Command_Pall, "Play a song for everyone");
    RegConsoleCmd("sm_plist", Command_Plist, "Pop-up the song list");
    RegConsoleCmd("sm_stop", Command_Stop, "Stop the current song");
    RegAdminCmd("sm_fstop", Command_Fstop, ADMFLAG_VOTE, "[ADMIN] Stop the current pall for everyone");
    RegAdminCmd("sm_fpall", Command_Fpall, ADMFLAG_VOTE, "[ADMIN] Force everyone to listen to a song");
}

public OnAllPluginsLoaded()
{
    IGA_RegisterMenuItem("View Song List (!plist)", SongListMenu);
    IGA_RegisterMenuItem("How To Play Songs", TutorialMenu);
}

public OnClientPostAdminCheck(client)   
{  
    new flags = GetUserFlagBits(client);  
    if ((flags & ADMFLAG_CUSTOM1)) // Everyone with the flag "O"
    {  
        g_IsVIP[client] = true;
    }  
}  

public OnClientDisconnect(client)
{
    g_IsVIP[client] = false;
}

public Action:Command_P(client, args)
{
    if(IsClientInCooldown(client))
    {
        CReplyToCommand(client, "%t", "user_in_cooldown");
        return Plugin_Handled;
    }

    if(!IsIGAEnabled())
    {
        CReplyToCommand(client, "%t", "not_enabled");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        decl String:path[MAX_SONG_LENGTH];
        GetCmdArgString(path, sizeof(path));
        QuerySong(client, path, false);
    }

    return Plugin_Handled;
}

public Action:Command_Pall(client, args)
{
    if(IsClientInCooldown(client))
    {
        CReplyToCommand(client, "%t", "user_in_cooldown");
        return Plugin_Handled;
    }

    if(!IsIGAEnabled())
    {
        CReplyToCommand(client, "%t", "not_enabled");
        return Plugin_Handled;
    }

    if(!VIPCheck(client))
    {
        CReplyToCommand(client, "%t", "vips_only");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        decl String:path[MAX_SONG_LENGTH];
        GetCmdArgString(path, sizeof(path));
        QuerySong(client, path, true);
    }

    return Plugin_Handled;
}

public Action:Command_Plist(client, args)
{
    if(client && IsClientAuthorized(client)){
        decl String:search[MAX_SONG_LENGTH];
        GetCmdArgString(search, sizeof(search));
        SongList(client, search);
    }

    return Plugin_Handled;
}

public Action:Command_Stop(client, args)
{
    StopSong(client);
    return Plugin_Handled;
}

public Action:Command_Fstop(client, args)
{
    StopSongAll();
    return Plugin_Handled;
}

public Action:Command_Fpall(client, args)
{
    if(!IsIGAEnabled())
    {
        CReplyToCommand(client, "%t", "not_enabled");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        decl String:path[MAX_SONG_LENGTH];
        GetCmdArgString(path, sizeof(path));
        QuerySong(client, path, true, true);
    }

    return Plugin_Handled;
}

//True if client can use a VIP action. If VIPs are not enabled this
//will always be true, otherwise check if client is a VIP.
public bool:VIPCheck(client)
{
    if(!GetConVarBool(g_Cvar_VIPsOnly))
        return true;
    else
        return g_IsVIP[client];
}

public SongList(client, String:search[])
{

    //Use a song search if given a search key
    if(strlen(search) > 0)
    {
        decl String:args[256]="";
        Format(args, sizeof(args),
                "?search=%s", search);
        CreateIGAPopup(client, SONGS_ROUTE, args);
    }else{
        CreateIGAPopup(client, DIRECTORIES_ROUTE);
    }
}

public IGAMenu:SongListMenu(client) SongList(client, "");

public IGAMenu:TutorialMenu(client)
{
    new Handle:menu = CreateMenu(TutorialMenuHandler);

    SetMenuTitle(menu, "How to play music");

    AddMenuItem(menu, "0", "!p         Play a random song");
    AddMenuItem(menu, "0", "!p search  Display a list of songs that contain \"search\"");
    AddMenuItem(menu, "0", "!p c       Play a random song in category c");
    AddMenuItem(menu, "0", "!p c/name  Play a specific song name in category c");
    AddMenuItem(menu, "0", "!pall      Same as !p except it plays to everyone on the server");
    AddMenuItem(menu, "0", "!plist     Use to find a song or category");
    AddMenuItem(menu, "0", "!stop      Stop currently playing song");
    AddMenuItem(menu, "0", "!ptoo      Replay the most recenlty played song for yourself");

    DisplayMenu(menu, client, 20);
}

public TutorialMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_End: CloseHandle(menu);
    }
}

