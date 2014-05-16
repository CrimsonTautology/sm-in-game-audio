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
#include <steamtools>
#include <smjansson>

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
        GenerateLoginToken(client, ReceiveGenerateLoginToken);
    }

    return Plugin_Handled;
}

public IGAMenu:UploadSongMenu(client) GenerateLoginToken(client, ReceiveGenerateLoginToken);

public ReceiveGenerateLoginToken(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    new client = GetClientOfUserId(userid);
    if(!successful || code != HTTPStatusCode_OK)
    {
        LogError("[IGA] Error at RecivedGenerateLoginToken (HTTP Code %d; success %d)", code, successful);
        Steam_ReleaseHTTPRequest(request);
        return;
    }

    if(client)
    {
        decl String:data[4096];
        Steam_GetHTTPResponseBodyData(request, data, sizeof(data));
        Steam_ReleaseHTTPRequest(request);

        new Handle:json = json_load(data);
        new String:login_token[128];
        json_object_get_string(json, "login_token", login_token, sizeof(login_token));

        UploadPage(client, login_token);

        CloseHandle(json);
    }else{
        Steam_ReleaseHTTPRequest(request);
    }
}

UploadPage(client, String:login_token[])
{
    decl String:args[256]="";
    Format(args, sizeof(args),
            "?login_token=%s", login_token);
    CreateIGAPopup(client, NEW_SONGS_ROUTE, args);
}
