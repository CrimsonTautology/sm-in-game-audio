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

#define QUERY_SONG_ROUTE "/v1/api/query_song"
#define RANDOM_SONG_ROUTE ""
#define SONGS_ROUTE "/songs"

#define BAD_API_KEY 0
#define NO_SONG 1
#define ACTION_P 2
#define ACTION_PALL 3
#define ACTION_FPALL 4

#define MAX_STEAMID_LENGTH 21 
#define MAX_SONG_LENGTH 64

new Handle:g_Cvar_IGAApiKey = INVALID_HANDLE;
new Handle:g_Cvar_IGAUrl = INVALID_HANDLE;
new Handle:g_Cvar_IGAport = INVALID_HANDLE;
new Handle:g_Cvar_IGADonatorsOnly = INVALID_HANDLE;
new Handle:g_Cvar_IGAEnabled = INVALID_HANDLE;
new Handle:g_Cvar_IGARequestCooldownTime = INVALID_HANDLE;
new Handle:g_Cvar_IGANominationsName = INVALID_HANDLE;

new g_PallNextFree = 0;

public OnPluginStart()
{
    
    g_Cvar_IGAApiKey = CreateConVar(sm_iga_api_key, "", "API Key for your IGA webpage");
    g_Cvar_IGAUrl = CreateConVar(sm_iga_url, "", "URL to your IGA webpage");
    g_Cvar_IGADonatorsOnly = CreateConVar(sm_iga_donators_only, "1", "Whether or not only donators have access to pall");
    g_Cvar_IGAEnabled = CreateConVar(sm_iga_enabled, "1", "Whether or not pall is enabled");
    g_Cvar_IGANominationsName = CreateConVar("sm_iga_nominations_plugin", "nominations.smx", "The nominations plugin used by the server");
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

public OnSocketConnected(Handle:socket, any:headers_pack)
{
    decl String:request_string[1024];

    ResetPack(headers_pack);
    ReadPackString(headers_pack, request_string, sizeof(request_string));

    SocketSend(socket, request_string);
}

public OnSocketReceive(Handle:socket, String:receive_data[], const data_size, any:headers_pack) {
    new Handle:json = json_load(recieve_data);
    new action = json_object_get_int(json, "action");
    if(action == BAD_API_KEY)
    {
        LogError("[IGA] Invalid API key");
    }else if (action == NO_SONG)
    {
        new String:song[MAX_SONG_LENGTH], String:steamid[MAX_STEAMID_LENGTH]
        json_object_get_string(json, "song", song, MAX_SONG_LENGTH);
        json_object_get_string(json, "steamid", steamid, MAX_STEAMID_LENGTH);
        new client = GetClientAuthString(steamid);
        PrintToChat(client, "[IGA] %s was not found");
    }else{
    //CASE ACTION_P
    //CASE ACTION_PALL
    //CASE ACTION_FPALL
        new String:title[64], String:song[MAX_SONG_LENGTH], String:steamid[MAX_STEAMID_LENGTH]
        json_object_get_string(json, "title", title, sizeof(title));
        json_object_get_string(json, "song", song, MAX_SONG_LENGTH);
        json_object_get_string(json, "steamid", steamid, MAX_STEAMID_LENGTH);
        new duration = json_object_get_int(json, "duration");
        new client = GetClientAuthString(steamid);

        if(action == ACTION_P)
        {
            PlaySong(client, song);
        }
        if(action == ACTION_PALL)
        {
            if(current_time < g_PallNextFree)
            {
                PrintToChat(client, "Sorry, pall is currently in use");
            }else
            {
                g_PallNextFree = current_time + duration + 100;
                PlaySongAll(song);
            }
        }
        if(action == ACTION_FPALL)
        {
            g_PallNextFree = current_time + duration + 100;
            PlaySongAll(song);
        }

    }
    CloseHandle(json);
    PrintToConsole(0,"%s", receive_data);//TODO
}

public OnSocketDisconnected(Handle:socket, any:headers_pack) {
    // Connection: close advises the webserver to close the connection when the transfer is finished
    // we're done here
    CloseHandle(headers_pack);
    CloseHandle(socket);
}

public OnSocketError(Handle:socket, const error_type, const error_num, any:headers_pack) {
    // a socket error occured
    if(error_type == EMPTY_HOST )
    {
        LogError("[IGA] Empty Host (errno %d)", error_num);
    } else if (error_type == NO_HOST )
    {
        LogError("[IGA] No Host (errno %d)", error_num);
    } else if (error_type == CONNECT_ERROR )
    {
        LogError("[IGA] Connection Error (errno %d)", error_num);
    } else if (error_type == SEND_ERROR )
    {
        LogError("[IGA] Send Error (errno %d)", error_num);
    } else if (error_type == BIND_ERROR )
    {
        LogError("[IGA] Bind Error (errno %d)", error_num);
    } else if (error_type == RECV_ERROR )
    {
        LogError("[IGA] Recieve Error (errno %d)", error_num);
    } else if (error_type == LISTEN_ERROR )
    {
        LogError("[IGA] Listen Error (errno %d)", error_num);
    } else
    {
        LogError("[IGA] socket error %d (errno %d)", errorType, error_num);
    }

    CloseHandle(headers_pack);
    CloseHandle(socket);
}



public Action:Command_P(client, args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[IGA] Usage: !p <song>");
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client)){
        decl String:song[MAX_SONG_LENGTH];
        GetCmdArgString(song, sizeof(song));
        QuerySong(client, song, ACTION_P);
    }
    
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

public QuerySong(client, String:song[MAX_SONG_LENGTH], action)
{
    decl String:steamid[MAX_STEAMID_LENGTH]
    GetClientAuthString(client, steamid, sizeof(steamid));

    decl String:query_params[512];
    Format(query_params, sizeof(query_params),
            "action=%d&steamid=%s&song=%s", action, steamid, song);

    IGAApiCall(QUERY_SONG_ROUTE, query_params);
}
public IGAApiCall(String:route[128], String:query_params[512])
{
    new port= GetConVarInt(g_Cvar_IGAPort);
    decl String:base_url[128], String:api_key[128];
    GetConVarString(g_Cvar_IGAUrl, base_url, sizeof(base_url));
    GetConVarString(g_Cvar_IGAApiKey, api_key, sizeof(api_key));

    ReplaceString(base_url, sizeof(base_url), "http://", "", false);
    ReplaceString(base_url, sizeof(base_url), "https://", "", false);

    Format(query_params, sizeof(query_params), "%s&access_token=%s", query_params, api_key);

    HTTPPost(base_url, route, query_params, port);
}

public HTTPPost(String:base_url[128], String:route[128], String:query_params[512], port)
{
    new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);

    //This Formats the headers needed to make a HTTP/1.1 POST request.
    new String:request_string[1024];
    Format(request_string, sizeof(request_string), "POST %s HTTP/1.1\r\nHost: %s\r\nConnection: close\r\nContent-type: application/x-www-form-urlencoded\r\nContent-length: %d\r\n\r\n%s", route, base_url, strlen(headers), headers);

    new Handle:headers_pack = CreateDataPack();
    WritePackString(headers_pack, request_string);
    SocketSetArg(socket, headers_pack);

    SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, base_url, port);
}

public PlaySongAll(song[MAX_SONG_LENGTH])
{
    //TODO update PALL duration
     for (new client=1; client <= MaxClients; client++)
     {
        if (DoesClientHavePallEnabled(client))
        {
            PlaySong(client, song);
        }
     }
}

public PlaySong(client, song[MAX_SONG_LENGTH])
{
        decl String:url[256], String:base_url[128];
        GetConVarString(g_Cvar_IGAUrl, base_url, sizeof(base_url));
        ReplaceString(base_url, sizeof(base_url), "http://", "", false);
        ReplaceString(base_url, sizeof(base_url), "https://", "", false);

        Format(url, sizeof(url),
                "http://%s%s/%s", base_url, SONGS_ROUTE, song);

        //TODO make popunder
        ShowMOTDPanel(client, "Song Player", url, MOTDPANEL_TYPE_URL);

}

public bool:DoesClientHavePallEnabled(client)
{
    //TODO do cookie check
    return IsClientAuthorized(client);
}
