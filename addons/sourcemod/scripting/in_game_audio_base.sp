/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio_base
 * Handles http calls to the In Game Audio website to query and play songs to
 * users through the MOTD popup panel.
 *
 * Copyright 2013 CrimsonTautology
 * =============================================================================
 *
 */

#pragma semicolon 1

#include <sourcemod>
#include <in_game_audio>
#include <clientprefs>
#include <steamtools>
#include <smjansson>

#define PLUGIN_VERSION "0.2"

public Plugin:myinfo =
{
    name = "In Game Audio Base",
    author = "CrimsonTautology",
    description = "Interact with the In Game Audio web api",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};


new Handle:g_Cvar_IGAApiKey = INVALID_HANDLE;
new Handle:g_Cvar_IGAUrl = INVALID_HANDLE;
new Handle:g_Cvar_IGAEnabled = INVALID_HANDLE;
new Handle:g_Cvar_IGARequestCooldownTime = INVALID_HANDLE;

new Handle:g_Cookie_PallEnabled = INVALID_HANDLE;
new Handle:g_Cookie_Volume = INVALID_HANDLE;

new bool:g_IsInCooldown[MAXPLAYERS+1];
new bool:g_IsPallEnabled[MAXPLAYERS+1];
new String:g_CurrentPallDescription[64];
new String:g_CurrentPallPath[64];
new String:g_CurrentPlastSongId[64];
new g_PNextFree[MAXPLAYERS+1];
new g_PallNextFree = 0;
new g_Volume[MAXPLAYERS+1];


public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    if (LibraryExists("in_game_audio"))
    {
        strcopy(error, err_max, "InGameAudio already loaded, aborting.");
        return APLRes_Failure;
    }

    RegPluginLibrary("in_game_audio"); 

    CreateNative("AuthorizeUser", Native_AuthorizeUser);
    CreateNative("ClientHasPallEnabled", Native_ClientHasPallEnabled);
    CreateNative("SetPallEnabled", Native_SetPallEnabled);
    CreateNative("IsInP", Native_IsInP);
    CreateNative("IsInPall", Native_IsInPall);
    CreateNative("PlaySong", Native_PlaySong);
    CreateNative("PlaySongAll", Native_PlaySongAll);
    CreateNative("StopSong", Native_StopSong);
    CreateNative("StopSongAll", Native_StopSongAll);
    CreateNative("SongList", Native_SongList);
    CreateNative("QuerySong", Native_QuerySong);
    CreateNative("MapTheme", Native_MapTheme);
    CreateNative("UserTheme", Native_UserTheme);
    CreateNative("StartCoolDown", Native_StartCoolDown);
    CreateNative("IsClientInCooldown", Native_IsClientInCooldown);
    CreateNative("IsIGAEnabled", Native_IsIGAEnabled);

    return APLRes_Success;
}

public OnPluginStart()
{

    g_Cvar_IGAApiKey = CreateConVar("sm_iga_api_key", "", "API Key for your IGA webpage");
    g_Cvar_IGAUrl = CreateConVar("sm_iga_url", "", "URL to your IGA webpage");
    g_Cvar_IGAEnabled = CreateConVar("sm_iga_enabled", "1", "Whether or not pall is enabled");
    g_Cvar_IGARequestCooldownTime = CreateConVar("sm_iga_request_cooldown_time", "2.0", "How long in seconds before a client can send another http request");

    RegConsoleCmd("sm_vol", Command_Vol, "Adjust your play volume");
    RegConsoleCmd("sm_nopall", Command_Nopall, "Turn off pall for yourself");
    RegConsoleCmd("sm_yespall", Command_Yespall, "Turn on pall for yourself");
    RegConsoleCmd("sm_authorize_iga", Command_AuthorizeIGA, "Declare that you want to upload songs to the website.  This will set you as an uploader.");

    g_Cookie_Volume = RegClientCookie("iga_volume", "Volume to play at [0-10]; 0 muted, 10 loudest", CookieAccess_Private);
    g_Cookie_PallEnabled = RegClientCookie("iga_pall_enabled", "Whether you want pall enabled or not. If yes, you will hear music when other players call !pall", CookieAccess_Private);

}

public OnClientConnected(client)
{
    g_IsInCooldown[client] = false;
    g_PNextFree[client] = 0;
    g_Volume[client] = 7;
    g_IsPallEnabled[client] = true;

}

public OnClientCookiesCached(client)
{
    new String:buffer[11];

    GetClientCookie(client, g_Cookie_Volume, buffer, sizeof(buffer));
    if (strlen(buffer) > 0){
        g_Volume[client] = StringToInt(buffer);
    }

    GetClientCookie(client, g_Cookie_PallEnabled, buffer, sizeof(buffer));
    if (strlen(buffer) > 0){
        g_IsPallEnabled[client] = bool:StringToInt(buffer);
    }
}


public OnMapStart()
{
    g_PallNextFree = 0;
}

public Action:Command_Vol(client, args)
{
    if (client && args != 1)
    {
        ReplyToCommand(client, "[IGA] usage \"!vol [0-10]\".  Currently %d.", g_Volume[client]);
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client))
    {
        decl String:buffer[11];
        new volume;
        GetCmdArgString(buffer, sizeof(buffer));
        volume = StringToInt(buffer);
        if (volume >=0 && volume <= 10)
        {
            SetClientCookie(client, g_Cookie_Volume, buffer);
            g_Volume[client] = volume;
            ReplyToCommand(client, "[IGA] Set volume to %d.", volume);
        }else{
            ReplyToCommand(client, "[IGA] usage \"!vol [0-10]\".");
        }
    }

    return Plugin_Handled;
}

public Action:Command_Nopall(client, args)
{
    if (client && IsClientAuthorized(client))
    {
        SetClientCookie(client, g_Cookie_PallEnabled, "0");
        g_IsPallEnabled[client] = false;
        ReplyToCommand(client, "[IGA] Disabled pall.  Type !yespall to renable it.");
    }
    return Plugin_Handled;
}

public Action:Command_Yespall(client, args)
{
    if (client && IsClientAuthorized(client))
    {
        SetClientCookie(client, g_Cookie_PallEnabled, "1");
        g_IsPallEnabled[client] = true;
        ReplyToCommand(client, "[IGA] Enabled pall.  Type !nopall to disable it.");
    }
    return Plugin_Handled;
}

public Action:Command_AuthorizeIGA(client, args)
{
    if (client && IsClientAuthorized(client))
    {
        InternalAuthorizeUser(client);
    }
    return Plugin_Handled;
}

Steam_SetHTTPRequestGetOrPostParameterInt(&HTTPRequestHandle:request, const String:param[], value)
{
    new String:tmp[64];
    IntToString(value, tmp, sizeof(tmp));
    Steam_SetHTTPRequestGetOrPostParameter(request, param, tmp);
}

SetAccessCode(&HTTPRequestHandle:request)
{
    decl String:api_key[128];
    GetConVarString(g_Cvar_IGAApiKey, api_key, sizeof(api_key));
    Steam_SetHTTPRequestGetOrPostParameter(request, "access_token", api_key);
}

HTTPRequestHandle:CreateIGARequest(const String:route[])
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

public Native_StartCoolDown(Handle:plugin, args) { InternalStartCooldown(GetNativeCell(1)); }
InternalStartCooldown(client)
{
    //Ignore the server console
    if (client == 0)
        return;

    g_IsInCooldown[client] = true;
    CreateTimer(GetConVarFloat(g_Cvar_IGARequestCooldownTime), RemoveCooldown, client);
}

public Native_IsIGAEnabled(Handle:plugin, args) { return _:InternalIsIGAEnabled(); }
bool:InternalIsIGAEnabled()
{
    return GetConVarBool(g_Cvar_IGAEnabled);
}
public Native_ClientHasPallEnabled(Handle:plugin, args) { return _:InternalClientHasPallEnabled(GetNativeCell(1)); }
bool:InternalClientHasPallEnabled(client)
{
    return g_IsPallEnabled[client];
}

public Native_SetPallEnabled(Handle:plugin, args) { InternalSetPallEnabled(GetNativeCell(1), GetNativeCell(2)); }
InternalSetPallEnabled(client, bool:val)
{
    g_IsPallEnabled[client] = val;
}

public Native_IsClientInCooldown(Handle:plugin, args) { return _:InternalIsClientInCooldown(GetNativeCell(1)); }
bool:InternalIsClientInCooldown(client)
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

public Native_IsInPall(Handle:plugin, args) { return _:InternalIsInPall(); }
bool:InternalIsInPall()
{
    return GetTime() < g_PallNextFree;
}

public Native_IsInP(Handle:plugin, args) { return _:InternalIsInP(GetNativeCell(1)); }
bool:InternalIsInP(client)
{
    return GetTime() < g_PNextFree[client];
}

public Native_QuerySong(Handle:plugin, args) {
    new len;
    GetNativeStringLength(2, len);
    new String:path[len+1];
    GetNativeString(2, path, len+1);

    InternalQuerySong(GetNativeCell(1), path, GetNativeCell(3), GetNativeCell(4));
}
InternalQuerySong(client, String:path[], bool:pall, bool:force)
{
    new HTTPRequestHandle:request = CreateIGARequest(QUERY_SONG_ROUTE);
    new player = client > 0 ? GetClientUserId(client) : 0;

    if(request == INVALID_HTTP_HANDLE)
    {
        ReplyToCommand(client, "[IGA] sm_iga_url invalid; cannot create HTTP request");
        return;
    }

    Steam_SetHTTPRequestGetOrPostParameterInt(request, "pall", pall);
    Steam_SetHTTPRequestGetOrPostParameterInt(request, "force", force);
    Steam_SetHTTPRequestGetOrPostParameter(request, "path", path);

    Steam_SendHTTPRequest(request, ReceiveQuerySong, player);

    InternalStartCooldown(client);
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
        new bool:force = json_object_get_bool(json, "force");
        new String:song_id[64], String:full_path[64], String:description[64], String:duration_formated[64];
        json_object_get_string(json, "song_id", song_id, sizeof(song_id));
        json_object_get_string(json, "full_path", full_path, sizeof(full_path));
        json_object_get_string(json, "description", description, sizeof(description));
        json_object_get_string(json, "duration_formated", duration_formated, sizeof(duration_formated));

        if(pall)
        {
            if(!InternalIsInPall())
            {
                g_PallNextFree = duration + GetTime();

                PrintToChatAll("[IGA] Started Playing \"%s\" to all.", description);
                PrintToChatAll("Duration %s.", duration_formated);
                PrintToChatAll("Type !stop to cancel or !nopall to mute.");

                strcopy(g_CurrentPallPath, 64, full_path);
                strcopy(g_CurrentPallDescription, 64, description);

                InternalPlaySongAll(song_id, force);
            }else{
                new minutes = (g_PallNextFree - GetTime()) / 60;
                new seconds = (g_PallNextFree - GetTime()) % 60;

                if (minutes > 1)
                    PrintToChat(client, "[IGA] pall currently playing %s \"%s\". Please wait %d more minutes.", g_CurrentPallPath, g_CurrentPallDescription, minutes);
                else
                    PrintToChat(client, "[IGA] pall currently playing %s \"%s\". Please wait %d more seconds.", g_CurrentPallPath, g_CurrentPallDescription, seconds);
            }
        }else if(client > 0){
            decl String:name[64];
            GetClientName(client, name, sizeof(name));

            g_PNextFree[client] = duration + GetTime();

            //PrintToChat(client, "[IGA] Started Playing \"%s\"", description);
            PrintToChatAll("[IGA] %s is currently playing \"%s\", type !p %s to play for yourself.", name, description, full_path);
            PrintToChat(client, "Duration %s.", duration_formated);
            PrintToChat(client, "Type !stop to cancel.");

            strcopy(g_CurrentPlastSongId, 64, song_id);

            InternalPlaySong(client, song_id);
        }
    }else{
        PrintToChat(client, "[IGA] Could not find specified sound or directory.");
    }

    CloseHandle(json);
}

public Native_UserTheme(Handle:plugin, args) { InternalUserTheme(GetNativeCell(1)); }
InternalUserTheme(client)
{
    new HTTPRequestHandle:request = CreateIGARequest(USER_THEME_ROUTE);

    if(request == INVALID_HTTP_HANDLE)
    {
        PrintToConsole(0, "[IGA] sm_iga_url invalid; cannot create HTTP request");
        return;
    }

    //Find the user's theme
    decl String:uid[MAX_COMMUNITYID_LENGTH];
    Steam_GetCSteamIDForClient(client, uid, sizeof(uid));
    Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);

    Steam_SendHTTPRequest(request, ReceiveTheme, 0);
}

public Native_MapTheme(Handle:plugin, args)
{
    new len;
    GetNativeStringLength(1, len);
    new String:map[len+1];
    GetNativeString(1, map, len+1);

    InternalMapTheme(map);
}
InternalMapTheme(String:map[] ="")
{
    new HTTPRequestHandle:request = CreateIGARequest(MAP_THEME_ROUTE);

    if(request == INVALID_HTTP_HANDLE)
    {
        PrintToConsole(0, "[IGA] sm_iga_url invalid; cannot create HTTP request");
        return;
    }

    Steam_SetHTTPRequestGetOrPostParameter(request, "map", map);
    Steam_SendHTTPRequest(request, ReceiveTheme, 0);
}

public ReceiveTheme(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    if(!successful || code != HTTPStatusCode_OK)
    {
        LogError("[IGA] Error at RecivedTheme (HTTP Code %d; success %d)", code, successful);
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
        new bool:force = json_object_get_bool(json, "force");
        new String:song_id[64];
        json_object_get_string(json, "song_id", song_id, sizeof(song_id));

        if(force || !InternalIsInPall())
        {
            g_PallNextFree = 0;
            InternalPlaySongAll(song_id, force);
        }
    }

    CloseHandle(json);
}


public Native_AuthorizeUser(Handle:plugin, args) { InternalAuthorizeUser(GetNativeCell(1)); }
InternalAuthorizeUser(client)
{
    new HTTPRequestHandle:request = CreateIGARequest(AUTHORIZE_USER_ROUTE);
    new player = client > 0 ? GetClientUserId(client) : 0;

    if(request == INVALID_HTTP_HANDLE)
    {
        ReplyToCommand(client, "[IGA] sm_iga_url invalid; cannot create HTTP request");
        return;
    }

    decl String:uid[MAX_COMMUNITYID_LENGTH];
    Steam_GetCSteamIDForClient(client, uid, sizeof(uid));
    Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);

    Steam_SendHTTPRequest(request, ReceiveAuthorizeUser, player);

    InternalStartCooldown(client);
}

public ReceiveAuthorizeUser(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    new client = GetClientOfUserId(userid);
    if(!successful || code != HTTPStatusCode_OK)
    {
        LogError("[IGA] Error at RecivedAuthorizeUser (HTTP Code %d; success %d)", code, successful);
        Steam_ReleaseHTTPRequest(request);
        return;
    }

    Steam_ReleaseHTTPRequest(request);
    if(client)
    {
        PrintToChat(client, "[IGA] You are now authorized to upload songs.");
    }
}

public Native_PlaySongAll(Handle:plugin, args)
{
    new len;
    GetNativeStringLength(1, len);
    new String:song[len+1];
    GetNativeString(1, song, len+1);

    InternalPlaySongAll(song, GetNativeCell(2));
}
InternalPlaySongAll(String:song[], bool:force)
{
    for (new client=1; client <= MaxClients; client++)
    {
        if ( InternalClientHasPallEnabled(client) && (force || !InternalIsInP(client)) )
        {
            InternalPlaySong(client, song);
        }
    }
}

public Native_PlaySong(Handle:plugin, args)
{
    new len;
    GetNativeStringLength(2, len);
    new String:song[len+1];
    GetNativeString(2, song, len+1);

    InternalPlaySong(GetNativeCell(1), song);
}
InternalPlaySong(client, String:song_id[])
{
    if(!IsClientInGame(client))
    {
        return;
    }
    decl String:url[256], String:base_url[128];
    GetConVarString(g_Cvar_IGAUrl, base_url, sizeof(base_url));

    TrimString(base_url);
    new trim_length = strlen(base_url) - 1;

    if(base_url[trim_length] == '/')
    {
        strcopy(base_url, trim_length + 1, base_url);
    }

    decl String:api_key[128];
    GetConVarString(g_Cvar_IGAApiKey, api_key, sizeof(api_key));

    Format(url, sizeof(url),
            "%s%s/%s/play?access_token=%s&volume=%f", base_url, SONGS_ROUTE, song_id, api_key, (g_Volume[client] / 10.0));

    new Handle:panel = CreateKeyValues("data");
    KvSetString(panel, "title", "In Game Audio");
    KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);
    KvSetString(panel, "msg", url);

    ShowVGUIPanel(client, "info", panel, false);
    CloseHandle(panel);
    return;
}

public Native_StopSong(Handle:plugin, args) { InternalStopSong(GetNativeCell(1)); }
InternalStopSong(client)
{
    g_PNextFree[client] = 0;
    InternalPlaySong(client, "stop");//TODO
}

public Native_StopSongAll(Handle:plugin, args) { InternalStopSongAll(); }
InternalStopSongAll()
{
    g_PallNextFree = 0;
    InternalPlaySongAll("stop", true);//TODO
}

public Native_SongList(Handle:plugin, args) { InternalSongList(GetNativeCell(1)); }
public InternalSongList(client)
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
