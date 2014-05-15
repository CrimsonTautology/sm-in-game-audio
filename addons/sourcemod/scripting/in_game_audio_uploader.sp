/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio_uploader
 * Allows users to upload songs via the MOTD browser
 *
 * Copyright 2014 CrimsonTautology
 * =============================================================================
 *
 */

#pragma semicolon 1

#include <sourcemod>
#include <in_game_audio>

#define PLUGIN_VERSION "1.0"

public Plugin:myinfo =
{
    name = "In Game Audio Music Uploader",
    author = "CrimsonTautology",
    description = "Allow users to upload music to IGA via the MOTD browser",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

public OnPluginStart()
{
    LoadTranslations("in_game_audio.phrases");

    RegConsoleCmd("sm_upload", Command_Upload, "Upload a song to IGA");

}

public OnAllPluginsLoaded()
{
    IGA_RegisterMenuItem("Upload songs", UploadSongMenu);
}


public Action:Command_Upload(client, args)
{
    if(IsClientInCooldown(client))
    {
        ReplyToCommand(client, "\x04%t", "user_in_cooldown");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        decl String:path[MAX_SONG_LENGTH];
        GetCmdArgString(path, sizeof(path));
        UploadSong(client, path);
    }

    return Plugin_Handled;
}

public IGAMenu:UploadSongMenu(client) UploadSong(client);

UploadSong(client, String:path[])
{
}

