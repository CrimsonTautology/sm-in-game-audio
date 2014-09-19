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
#undef REQUIRE_PLUGIN
#include <donator>

#define PLUGIN_VERSION "1.6.1"
#define PLUGIN_NAME "In Game Audio Player"

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "User commands to play and stop songs",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

new Handle:g_Cvar_IGADonatorsOnly = INVALID_HANDLE;
new bool:g_IsDonator[MAXPLAYERS+1];
new bool:g_DonatorLibraryExists = false;

public OnPluginStart()
{
    LoadTranslations("in_game_audio.phrases");

    CreateConVar("sm_iga_player_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
    g_Cvar_IGADonatorsOnly = CreateConVar("sm_iga_donators_only", "0", "Whether only dontaors can use pall");

    RegConsoleCmd("sm_p", Command_P, "Play a song for yourself");
    RegConsoleCmd("sm_pall", Command_Pall, "Play a song for everyone");
    RegConsoleCmd("sm_plist", Command_Plist, "Pop-up the song list");
    RegConsoleCmd("sm_stop", Command_Stop, "Stop the current song");
    RegAdminCmd("sm_fstop", Command_Fstop, ADMFLAG_VOTE, "[ADMIN] Stop the current pall for everyone");
    RegAdminCmd("sm_fpall", Command_Fpall, ADMFLAG_VOTE, "[ADMIN] Force everyone to listen to a song");

    g_DonatorLibraryExists = LibraryExists("donator.core");
}

public OnAllPluginsLoaded()
{
    IGA_RegisterMenuItem("View Play List (!plist)", SongListMenu);
    IGA_RegisterMenuItem("How to play songs", TutorialMenu);
}


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    MarkNativeAsOptional("IsPlayerDonator");
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
        g_IsDonator[client] = IsPlayerDonator(client);
    }
}

public OnClientDisconnect(client)
{
    g_IsDonator[client] = false;
}

public Action:Command_P(client, args)
{
    if(IsClientInCooldown(client))
    {
        ReplyToCommand(client, "\x04%t", "user_in_cooldown");
        return Plugin_Handled;
    }

    if(!IsIGAEnabled())
    {
        ReplyToCommand(client, "\x04%t", "not_enabled");
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
        ReplyToCommand(client, "\x04%t", "user_in_cooldown");
        return Plugin_Handled;
    }

    if(!IsIGAEnabled())
    {
        ReplyToCommand(client, "\x04%t", "not_enabled");
        return Plugin_Handled;
    }

    if(!DonatorCheck(client))
    {
        ReplyToCommand(client, "\x04%t", "donators_only");
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
        ReplyToCommand(client, "\x04%t", "not_enabled");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        decl String:path[MAX_SONG_LENGTH];
        GetCmdArgString(path, sizeof(path));
        QuerySong(client, path, true, true);
    }

    return Plugin_Handled;
}

//True if client can use a donator action. If donations are not enabled this
//will always be true, otherwise check if client is a donator.
public bool:DonatorCheck(client)
{
    if(!g_DonatorLibraryExists || !GetConVarBool(g_Cvar_IGADonatorsOnly))
        return true;
    else
        return g_IsDonator[client];
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
    AddMenuItem(menu, "0", "!p c       Play a random song in category c");
    AddMenuItem(menu, "0", "!p c/name  Play a specific song name in category c");
    AddMenuItem(menu, "0", "!pall      Same as !p except it plays to everyone on the server");
    AddMenuItem(menu, "0", "!plist     Use to find a song or category");
    AddMenuItem(menu, "0", "!stop      Stop currently playing song");

    DisplayMenu(menu, client, 20);
}

public TutorialMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_End: CloseHandle(menu);
    }
}

