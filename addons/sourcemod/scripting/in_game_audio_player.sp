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
#undef REQUIRE_PLUGIN
#include <donator>

#define PLUGIN_VERSION "0.2"

public Plugin:myinfo =
{
    name = "In Game Audio Player",
    author = "CrimsonTautology",
    description = "User commands to play and stop songs",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

new Handle:g_Cvar_IGADonatorsOnly = INVALID_HANDLE;
new bool:g_IsDonator[MAXPLAYERS+1];
new bool:g_DonatorLibrary = false;

public OnPluginStart()
{
    RegConsoleCmd("sm_p", Command_P, "Play a song for yourself");
    RegConsoleCmd("sm_pall", Command_Pall, "Play a song for everyone");
    RegConsoleCmd("sm_plist", Command_Plist, "Pop-up the song list");
    RegConsoleCmd("sm_stop", Command_Stop, "Stop the current song");
    RegAdminCmd("sm_fstop", Command_Fstop, ADMFLAG_VOTE, "[ADMIN] Stop the current pall for everyone");
    RegAdminCmd("sm_fpall", Command_Fpall, ADMFLAG_VOTE, "[ADMIN] Force everyone to listen to a song");
    RegConsoleCmd("sm_plast", Command_Plast, "Play the last played song for yourself");

    g_DonatorLibrary = LibraryExists("donators");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "donators"))
	{
		g_DonatorLibrary = false;
	}
}
 
public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "donators"))
	{
		g_DonatorLibrary = true;
	}
}

public OnPostDonatorCheck(client)
{
    g_IsDonator[client] = true;
}

public OnClientDisconnect(client)
{
    g_IsDonator[client] = false;
}

public Action:Command_P(client, args)
{
    if(IsClientInCooldown(client))
    {
        ReplyToCommand(client, "[IGA] User in cooldown.");
        return Plugin_Handled;
    }

    if(!GetConVarBool(g_Cvar_IGAEnabled))
    {
        ReplyToCommand(client, "[IGA] IGA not enabled.");
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
        ReplyToCommand(client, "[IGA] User in cooldown.");
        return Plugin_Handled;
    }

    if(!GetConVarBool(g_Cvar_IGAEnabled))
    {
        ReplyToCommand(client, "[IGA] IGA not enabled.");
        return Plugin_Handled;
    }

    if(!DonatorCheck(client))
    {
        ReplyToCommand(client, "[IGA] Only donators can use this command.");
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
        SongList(client);
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
    if(client && IsClientAuthorized(client)){
        decl String:path[MAX_SONG_LENGTH];
        GetCmdArgString(path, sizeof(path));
        QuerySong(client, path, true, true);
    }

    return Plugin_Handled;
}

public Action:Command_Plast(client, args)
{
    if (client && IsClientAuthorized(client))
    {
        PlaySong(client, g_CurrentPlastSongId);
    }
    return Plugin_Handled;
}

//True if client can use a donator action. If donations are not enabled this
//will always be true, otherwise check if client is a donator.
public bool:DonatorCheck(client)
{
    if(!g_DonatorLibrary || !GetConVarBool(g_Cvar_IGADonatorsOnly))
        return true;
    else
        return g_IsDonator[client];
}




public SongList(client)
{
    decl String:url[256], String:base_url[128];
    GetConVarString(g_Cvar_IGAUrl, base_url, sizeof(base_url));

    TrimString(base_url);
    new trim_length = strlen(base_url) - 1;

    if(base_url[trim_length] == '/')
    {
        strcopy(base_url, trim_length + 1, base_url);
    }

    Format(url, sizeof(url),
            "%s%s", base_url, DIRECTORIES_ROUTE);

    ShowMOTDPanel(client, "Song List", url, MOTDPANEL_TYPE_URL);

}
