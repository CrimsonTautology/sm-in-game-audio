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

#define SONG_INFO_ROUTE "/v1/api/song_info"
#define SONGS_ROUTE "/songs"

new Handle:g_Cvar_IGAApiKey = INVALID_HANDLE;
new Handle:g_Cvar_IGAUrl = INVALID_HANDLE;
new Handle:g_Cvar_IGAport = INVALID_HANDLE;
new Handle:g_Cvar_IGADonatorsOnly = INVALID_HANDLE;
new Handle:g_Cvar_IGAEnabled = INVALID_HANDLE;

public OnPluginStart()
{
    
    g_Cvar_IGAApiKey = CreateConVar(sm_iga_api_key, "", "API Key for your IGA webpage");
    g_Cvar_IGAUrl = CreateConVar(sm_iga_url, "", "URL to your IGA webpage");
    g_Cvar_IGAPort = CreateConVar("sm_iga_port", "80", "HTTP Port used");
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

public OnSocketConnected(Handle:socket, any:headers_pack)
{
    decl String:request_string[1024];

    ResetPack(headers_pack);
    ReadPackString(headers_pack, request_string, sizeof(request_string));

    SocketSend(socket, request_string);
}

public OnSocketReceive(Handle:socket, String:receive_data[], const data_size, any:headers_pack) {
    //TODO parse JSON response
    //Used for data received back
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
