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
#include <steamtools>
#include <base64>
#include <smjansson>

#define PLUGIN_VERSION "0.1"

public Plugin:myinfo =
{
    name = "InGameAudio",
    author = "CrimsonTautology",
    description = "Interact with the In Game Audio web api",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

#define QUERY_SONG_ROUTE "/v1/api/query_song"
#define RANDOM_SONG_ROUTE ""
#define SONGS_ROUTE "/songs"

#define MAX_STEAMID_LENGTH 21 
#define MAX_SONG_LENGTH 64

new Handle:g_Cvar_IGAApiKey = INVALID_HANDLE;
new Handle:g_Cvar_IGAUrl = INVALID_HANDLE;
new Handle:g_Cvar_IGAport = INVALID_HANDLE;
new Handle:g_Cvar_IGADonatorsOnly = INVALID_HANDLE;
new Handle:g_Cvar_IGAEnabled = INVALID_HANDLE;
new Handle:g_Cvar_IGARequestCooldownTime = INVALID_HANDLE;

new bool:g_IsInCooldown[MAXPLAYERS+1];
new g_PallNextFree = 0;

public OnPluginStart()
{
    
    g_Cvar_IGAApiKey = CreateConVar(sm_iga_api_key, "", "API Key for your IGA webpage");
    g_Cvar_IGAUrl = CreateConVar(sm_iga_url, "", "URL to your IGA webpage");
    g_Cvar_IGADonatorsOnly = CreateConVar(sm_iga_donators_only, "1", "Whether or not only donators have access to pall");
    g_Cvar_IGAEnabled = CreateConVar(sm_iga_enabled, "1", "Whether or not pall is enabled");
    g_Cvar_IGARequestCooldownTime = CreateConVar("sm_iga_request_cooldown_time", "2.0", "How long in seconds before a client can send another http request");
    
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
    if (args < 1)
    {
        ReplyToCommand(client, "[IGA] Usage: !p <song>");
        return Plugin_Handled;
    }
    if(IsClientInCooldown(client))
    {
        ReplyToCommand(client, "[IGA] User in cooldown");
        return Plugin_Handled;
    }

    if(!GetConVarBool(g_Cvar_IGAEnabled))
    {
        ReplyToCommand(client, "[IGA] IGA not enabled");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        decl String:song[MAX_SONG_LENGTH];
        GetCmdArgString(song, sizeof(song));
        QuerySong(client, song, ACTION_P);
    }

    return Plugin_Handled;
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

public Steam_SetHTTPRequestGetOrPostParameterInt(&HTTPRequestHandle:request, const String:param[], value)
{
    new String:tmp[64];
    IntToString(value, tmp, sizeof(tmp));
    Steam_SetHTTPRequestGetOrPostParameter(request, param, tmp);
}

public SetAccessCode(&HTTPRequestHandle:request)
{
    decl String:api_key[128];
    GetConVarString(g_Cvar_IGAApiKey, api_key, sizeof(api_key));
    Steam_SetHTTPRequestGetOrPostParameter(request, "access_token", api_key);
}

public HTTPRequestHandle:CreateIGARequest(const String:route[])
{
    decl String:base_url[256], String:url[512];
    GetConVarString(g_Cvar_IGAUrl, base_url, sizeof(base_url));
    TrimString(base_url);
    new trim_length = strlen(base_url) - 1;

    if(trim_length < 0)
    {
        //IGA Url not set
        return INVALID_HTTP_HANDLE;
    }

    //check for forward slash after base_url;
    if(base_url[trim_length] == '/')
    {
        strcopy(base_url, trim_length + 1, base_url);
    }

    Format(url, sizeof(url),
            "%s%s", base_url, route);

    new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_POST, url);
    SetAccessCode(request);

    return request;
}

public StartCooldown(client)
{
    //Ignore the server console
    if (client == 0)
        return;

    g_IsInCooldown[client] = true;
    CreateTimer(GetConVarFloat(g_Cvar_IGARequestCooldownTime), RemoveCooldown, client);
}

public bool:IsClientInCooldown(client)
{
    if(client == 0)
        return false;
    else
        return g_IsInCooldown[client];
}

public Action:RemoveCooldown(Handle:timer, any:client)
{
    g_IsInCooldown[client] = false;
}

public QuerySong(client, String:song[MAX_SONG_LENGTH], bool:pall=false, client_theme=0, map_theme="")
{
    decl String:uid[MAX_COMMUNITYID_LENGTH];
    Steam_GetCSteamIDForClient(client, uid, sizeof(uid));

    new HTTPRequestHandle:request = CreateIGARequest(QUERY_SONG_ROUTE);

    if(request == INVALID_HTTP_HANDLE)
    {
        ReplyToCommand(client, "[IGA] sm_iga_url invalid; cannot create HTTP request");
        return;
    }

    Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);
    Steam_SetHTTPRequestGetOrPostParameterInt(request, "pall", pall);
    Steam_SetHTTPRequestGetOrPostParameterInt(request, "player", GetClientUserId(client));
    Steam_SetHTTPRequestGetOrPostParameter(request, "song", song);

    if(client_theme > 0)
    {
        //Find the user's theme
        decl String:uid_theme[MAX_COMMUNITYID_LENGTH];
        Steam_GetCSteamIDForClient(client, uid_theme, sizeof(uid_theme));
        Steam_SetHTTPRequestGetOrPostParameter(request, "uid_theme", uid_theme);
    }else if(strlen(map_theme) > 0){
        //Find the map's theme
        Steam_SetHTTPRequestGetOrPostParameter(request, "map_theme", map_theme);
    }

    Steam_SendHTTPRequest(request, ReceiveSongQuery, GetClientUserId(client));

    StartCooldown(client);
}

public ReceiveQuerySong(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    new client = GetClientOfUserId(userid);
    if(!successful || code != HTTPStatusCode_OK)
    {
        LogError("[IGA] Error at RecivedQuerySong (HTTP Code %d; success %d)", code, successful);
        Steam_ReleaseHTTPRequest(request);
        return;
    }

    decl String:data[4096];
    Steam_GetHTTPResponseBodyData(request, data, sizeof(data));
    Steam_ReleaseHTTPRequest(request);

    new Handle:json = json_load(data);
    new bool:found = json_object_get_bool(json, "found");

    if(found)
    {
        new duration = json_object_get_int(json, "duration");
        new bool:pall = json_object_get_bool(json, "pall");
        new String:song[MAX_SONG_LENGTH], String:description[64];
        json_object_get_string(json, "song", song, sizeof(song));
        json_object_get_string(json, "description", description, sizeof(description));

        if(pall)
        {
            PrintToChatAll("Now Playing: %s", description)
                PlaySongAll(song);
        }else if(client > 0){
            PrintToChat(client, "Now Playing: %s", description)
                PlaySong(client, song);
        }
    }

    CloseHandle(json);
    Steam_ReleaseHTTPRequest(request);
}


public PlaySongAll(song[MAX_SONG_LENGTH])
{
    //TODO update PALL duration
    for (new client=1; client <= MaxClients; client++)
    {
        if (ClientHasPallEnabled(client))
        {
            PlaySong(client, song);
        }
    }
}

public PlaySong(client, song[MAX_SONG_LENGTH])
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
            "%s%s/%s", base_url, SONGS_ROUTE, song);

    new Handle:panel = CreateKeyValues("data");
    KvSetString(panel, "title", "In Game Audio");
    KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);
    KvSetString(panel, "msg", url);
 
    ShowVGUIPanel(client, "info", panel, false);
    CloseHandle(panel);
    return;
}

public bool:ClientHasPallEnabled(client)
{
    //TODO do cookie check
    return IsClientAuthorized(client);
}
