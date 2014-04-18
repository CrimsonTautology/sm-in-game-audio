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

#define PLUGIN_VERSION "1.2"

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

new Handle:g_MenuItems = INVALID_HANDLE;
new g_MenuId;

new bool:g_IsInCooldown[MAXPLAYERS+1] = {false, ...};
new bool:g_IsPallEnabled[MAXPLAYERS+1] = {false, ...};
new String:g_CurrentPallDescription[64];
new String:g_CurrentPallPath[64];
new String:g_CurrentPlastSongId[64];
new g_PNextFree[MAXPLAYERS+1] = {0, ...};
new g_PallNextFree = 0;
new g_Volume[MAXPLAYERS+1] = {4, ...};


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

    CreateNative("IGA_RegisterMenuItem", Native_RegisterMenuItem);
    CreateNative("IGA_UnregisterMenuItem", Native_UnregisterMenuItem);

    return APLRes_Success;
}

public OnPluginStart()
{
    LoadTranslations("in_game_audio.phrases");

    g_Cvar_IGAApiKey = CreateConVar("sm_iga_api_key", "", "API Key for your IGA webpage");
    g_Cvar_IGAUrl = CreateConVar("sm_iga_url", "", "URL to your IGA webpage");
    g_Cvar_IGAEnabled = CreateConVar("sm_iga_enabled", "1", "Whether or not pall is enabled");
    g_Cvar_IGARequestCooldownTime = CreateConVar("sm_iga_request_cooldown_time", "2.0", "How long in seconds before a client can send another http request");

    RegConsoleCmd("sm_vol", Command_Vol, "Adjust your play volume");
    RegConsoleCmd("sm_nopall", Command_Nopall, "Turn off pall for yourself");
    RegConsoleCmd("sm_yespall", Command_Yespall, "Turn on pall for yourself");
    RegConsoleCmd("sm_authorize_iga", Command_AuthorizeIGA, "Declare that you want to upload songs to the website.  This will set you as an uploader.");
    RegConsoleCmd("sm_iga", Command_IGA, "Bring up the IGA settings and control menu");

    g_Cookie_Volume = RegClientCookie("iga_volume", "Volume to play at [0-10]; 0 muted, 10 loudest", CookieAccess_Private);
    g_Cookie_PallEnabled = RegClientCookie("iga_pall_enabled", "Whether you want pall enabled or not. If yes, you will hear music when other players call !pall", CookieAccess_Private);

    g_MenuItems = CreateArray();

}

public OnClientConnected(client)
{
    if(IsFakeClient(client))
    {
        return;
    }
    g_IsInCooldown[client] = false;
    g_PNextFree[client] = 0;
    g_Volume[client] = 4;
    g_IsPallEnabled[client] = true;

    //Disable pall by default for quickplayers
    new String:connect_method[5];
    GetClientInfo(client, "cl_connectmethod", connect_method, sizeof(connect_method));
    if( strncmp("quick", connect_method, 5, false) == 0 ||
            strncmp("match", connect_method, 5, false) == 0)
    {
        g_IsPallEnabled[client] = false;
    }

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
        ChangeVolumeMenu(client);
        return Plugin_Handled;
    }

    if(client && IsClientAuthorized(client))
    {
        decl String:buffer[11];
        new volume;
        GetCmdArgString(buffer, sizeof(buffer));
        volume = StringToInt(buffer);
        SetClientVolume(client, volume);
    }

    return Plugin_Handled;
}

public Action:Command_Nopall(client, args)
{
    if (client && IsClientAuthorized(client))
    {
        SetPallEnabled(client, false);
    }
    return Plugin_Handled;
}

public Action:Command_Yespall(client, args)
{
    if (client && IsClientAuthorized(client))
    {
        SetPallEnabled(client, true);
    }
    return Plugin_Handled;
}

public Action:Command_AuthorizeIGA(client, args)
{
    if(InternalIsClientInCooldown(client))
    {
        ReplyToCommand(client, "\x04%t", "user_in_cooldown");
        return Plugin_Handled;
    }

    if (client && IsClientAuthorized(client))
    {
        InternalAuthorizeUser(client);
    }
    return Plugin_Handled;
}

public Action:Command_IGA(client, args)
{
    if(client && IsClientAuthorized(client))
    {
        ShowIGAMenu(client);
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
    if(val)
    {
        SetClientCookie(client, g_Cookie_PallEnabled, "1");
        g_IsPallEnabled[client] = true;
        ReplyToCommand(client, "\x04%t", "enabled_pall");

    }else{
        SetClientCookie(client, g_Cookie_PallEnabled, "0");
        g_IsPallEnabled[client] = false;
        ReplyToCommand(client, "\x04%t", "disabled_pall");

    }
}

SetClientVolume(client, volume)
{
    if (volume >=0 && volume <= 10)
    {
        new String:tmp[11];
        IntToString(volume, tmp, sizeof(tmp));
        SetClientCookie(client, g_Cookie_Volume, tmp);
        g_Volume[client] = volume;
        ReplyToCommand(client, "\x04%t", "volume_set", volume);
    }else{
        ReplyToCommand(client, "\x04%t", "volume_usage", g_Volume[client]);
    }

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
    if (!InternalIsIGAEnabled())
    {
        PrintToConsole(0, "%t", "not_enabled");
    }

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
        ReplyToCommand(client, "\x04%t", "url_invalid");
        return;
    }

    Steam_SetHTTPRequestGetOrPostParameterInt(request, "pall", pall);
    Steam_SetHTTPRequestGetOrPostParameterInt(request, "force", force);
    Steam_SetHTTPRequestGetOrPostParameter(request, "path", path);

    //Send caller's steamid64
    decl String:uid[MAX_COMMUNITYID_LENGTH];
    Steam_GetCSteamIDForClient(client, uid, sizeof(uid));
    Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);

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
        new String:song_id[64], String:full_path[64], String:description[64], String:duration_formated[64], String:access_token[128];
        json_object_get_string(json, "song_id", song_id, sizeof(song_id));
        json_object_get_string(json, "full_path", full_path, sizeof(full_path));
        json_object_get_string(json, "description", description, sizeof(description));
        json_object_get_string(json, "duration_formated", duration_formated, sizeof(duration_formated));
        json_object_get_string(json, "access_token", access_token, sizeof(access_token));

        if(pall)
        {
            if(!InternalIsInPall())
            {
                g_PNextFree[client]=0;
                g_PallNextFree = duration + GetTime();

                PrintToChatAll("%t", "started_playing_to_all", description);
                PrintToChatAll("%t", "duration", duration_formated);
                PrintToChatAll("%t", "to_stop_all");

                strcopy(g_CurrentPallPath, 64, full_path);
                strcopy(g_CurrentPallDescription, 64, description);

                InternalPlaySongAll(song_id, access_token, force);
            }else{
                new minutes = (g_PallNextFree - GetTime()) / 60;
                new seconds = (g_PallNextFree - GetTime());

                if (minutes > 1)
                    PrintToChat(client, "\x04%t", "pall_currently_playing", g_CurrentPallPath, g_CurrentPallDescription, minutes, "minutes");
                else
                    PrintToChat(client, "\x04%t", "pall_currently_playing", g_CurrentPallPath, g_CurrentPallDescription, seconds, "seconds");
            }
        }else if(client > 0){
            decl String:name[64];
            GetClientName(client, name, sizeof(name));

            g_PNextFree[client] = duration + GetTime();

            PrintToChatAll("%t", "started_playing_to_self", name, description, full_path);
            PrintToChat(client, "%t", "duration", duration_formated);
            PrintToChat(client, "%t", "to_stop");

            strcopy(g_CurrentPlastSongId, 64, song_id);

            InternalPlaySong(client, song_id, access_token);
        }
    }else{
        PrintToChat(client, "%t", "not_found");
    }

    CloseHandle(json);
}

public Native_UserTheme(Handle:plugin, args) { InternalUserTheme(GetNativeCell(1)); }
InternalUserTheme(client)
{
    if (!InternalIsIGAEnabled())
    {
        PrintToConsole(0, "%t", "not_enabled");
    }

    new HTTPRequestHandle:request = CreateIGARequest(USER_THEME_ROUTE);

    if(request == INVALID_HTTP_HANDLE)
    {
        PrintToConsole(0, "%t", "url_invalid");
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
    GetNativeStringLength(2, len);
    new String:map[len+1];
    GetNativeString(2, map, len+1);

    InternalMapTheme(GetNativeCell(1), map);
}
InternalMapTheme(bool:force=true, String:map[] ="")
{
    if (!InternalIsIGAEnabled())
    {
        PrintToConsole(0, "%t", "not_enabled");
    }

    new HTTPRequestHandle:request = CreateIGARequest(MAP_THEME_ROUTE);

    if(request == INVALID_HTTP_HANDLE)
    {
        PrintToConsole(0, "%t", "url_invalid");
        return;
    }

    Steam_SetHTTPRequestGetOrPostParameterInt(request, "force", force);
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
        new String:song_id[64], String:access_token[128];
        json_object_get_string(json, "song_id", song_id, sizeof(song_id));
        json_object_get_string(json, "access_token", access_token, sizeof(access_token));

        if(force || !InternalIsInPall())
        {
            g_PallNextFree = 0;
            InternalPlaySongAll(song_id, access_token, force);
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
        ReplyToCommand(client, "\x04%t", "url_invalid");
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
        PrintToChat(client, "%t", "now_authorized_to_upload");
    }
}

public Native_PlaySongAll(Handle:plugin, args)
{
    new len;
    GetNativeStringLength(1, len);
    new String:song[len+1];
    GetNativeString(1, song, len+1);

    GetNativeStringLength(2, len);
    new String:access_token[len+1];
    GetNativeString(2, access_token, len+1);

    InternalPlaySongAll(song, access_token, GetNativeCell(3));
}
InternalPlaySongAll(String:song[], String:access_token[], bool:force)
{
    for (new client=1; client <= MaxClients; client++)
    {
        //Ignore players who can't hear this
        if(!IsClientInGame(client) || IsFakeClient(client) || g_Volume[client] < 1)
            continue;

        if ( InternalClientHasPallEnabled(client) )
        {
            if(force || !InternalIsInP(client))
            {
                InternalPlaySong(client, song, access_token);
            }

        }else{
            //Mention that pall is not enabled
            PrintToChat(client, "\x04%t", "pall_not_enabled");
        }
    }
}

public Native_PlaySong(Handle:plugin, args)
{
    new len;
    GetNativeStringLength(2, len);
    new String:song[len+1];
    GetNativeString(2, song, len+1);

    GetNativeStringLength(3, len);
    new String:access_token[len+1];
    GetNativeString(3, access_token, len+1);

    InternalPlaySong(GetNativeCell(1), song, access_token);
}
InternalPlaySong(client, String:song_id[], String:access_token[])
{
    //Don't play song if client is a bot or has a muted volume
    if(!IsClientInGame(client) || IsFakeClient(client) || g_Volume[client] < 1)
    {
        return;
    }
    decl String:url[256], String:base_url[128];
    GetConVarString(g_Cvar_IGAUrl, base_url, sizeof(base_url));

    //TODO make a pop-under motd method
    //Format http string
    //TODO store this on cvar change
    TrimString(base_url);
    new trim_length = strlen(base_url) - 1;

    if(base_url[trim_length] == '/')
    {
        strcopy(base_url, trim_length + 1, base_url);
    }

    Format(url, sizeof(url),
            "%s%s/%s/play?access_token=%s&volume=%f", base_url, SONGS_ROUTE, song_id, access_token, (g_Volume[client] / 10.0));

    new Handle:panel = CreateKeyValues("data");
    KvSetString(panel, "title", "In Game Audio");
    KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);
    KvSetString(panel, "msg", url);

    ShowVGUIPanel(client, "info", panel, false);
    CloseHandle(panel);
}

public Native_StopSong(Handle:plugin, args) { InternalStopSong(GetNativeCell(1)); }
InternalStopSong(client)
{
    if(!IsClientInGame(client) || IsFakeClient(client))
    {
        return;
    }
    g_PNextFree[client] = 0;
    decl String:url[256], String:base_url[128];
    GetConVarString(g_Cvar_IGAUrl, base_url, sizeof(base_url));

    //Format http string
    //TODO store this on cvar change
    TrimString(base_url);
    new trim_length = strlen(base_url) - 1;

    if(base_url[trim_length] == '/')
    {
        strcopy(base_url, trim_length + 1, base_url);
    }


    Format(url, sizeof(url),
            "%s%s", base_url, STOP_ROUTE);

    new Handle:panel = CreateKeyValues("data");
    KvSetString(panel, "title", "In Game Audio");
    KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);
    KvSetString(panel, "msg", url);

    ShowVGUIPanel(client, "info", panel, false);
    CloseHandle(panel);
}

public Native_StopSongAll(Handle:plugin, args) { InternalStopSongAll(); }
InternalStopSongAll()
{
    g_PallNextFree = 0;
    for (new client=1; client <= MaxClients; client++)
    {
        if ( !InternalIsInP(client) ) 
        {
            InternalStopSong(client);
        }
    }
}

public Native_SongList(Handle:plugin, args)
{
    new len;
    GetNativeStringLength(2, len);
    new String:search[len+1];
    GetNativeString(2, search, len+1);

    InternalSongList(GetNativeCell(1), search); 
}
public InternalSongList(client, String:search[])
{
    decl String:url[256], String:base_url[128];
    GetConVarString(g_Cvar_IGAUrl, base_url, sizeof(base_url));

    //Format http string
    //TODO store this on cvar change
    TrimString(base_url);
    new trim_length = strlen(base_url) - 1;

    if(base_url[trim_length] == '/')
    {
        strcopy(base_url, trim_length + 1, base_url);
    }

    //Use a song search if given a search key
    if(strlen(search) > 0)
    {
        Format(url, sizeof(url),
                "%s%s?search=%s", base_url, SONGS_ROUTE, search);
    }else{
        Format(url, sizeof(url),
                "%s%s", base_url, DIRECTORIES_ROUTE);
    }

    new Handle:panel = CreateKeyValues("data");
    KvSetString(panel, "title", "In Game Audio");
    KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);
    KvSetString(panel, "msg", url);
    KvSetNum(panel, "customsvr", 1); //Sets motd to be fullscreen

    ShowVGUIPanel(client, "info", panel, true);
    CloseHandle(panel);

}


//Menu Logic

public Native_RegisterMenuItem(Handle:plugin, args)
{
    decl String:plugin_name[PLATFORM_MAX_PATH];
    GetPluginFilename(plugin, plugin_name, sizeof(plugin_name));

    new Handle:plugin_forward = CreateForward(ET_Single, Param_Cell, Param_CellByRef);	
    if (!AddToForward(plugin_forward, plugin, GetNativeCell(2)))
        ThrowError("Failed to add forward from %s", plugin_name);

    new len;
    GetNativeStringLength(1, len);
    new String:title[len+1];
    GetNativeString(1, title, len+1);

    new Handle:new_item = CreateArray(15);
    new id = g_MenuId++;

    PushArrayString(new_item, plugin_name);
    PushArrayString(new_item, title);
    PushArrayCell(new_item, id);
    PushArrayCell(new_item, plugin_forward);
    PushArrayCell(g_MenuItems, new_item);

    return id;
}


public Native_UnregisterMenuItem(Handle:plugin, args)
{
    new Handle:tmp;
    for (new i = 0; i < GetArraySize(g_MenuItems); i++)
    {
        tmp = GetArrayCell(g_MenuItems, i);
        new id = GetArrayCell(tmp, 2);
        if (id == GetNativeCell(1))
        {
            RemoveFromArray(g_MenuItems, i);
            return true;
        }
    }
    return false;
}

ShowIGAMenu(client)
{
    new Handle:menu = CreateMenu(IGAMenuSelected);
    SetMenuTitle(menu,"IGA Menu");

    decl Handle:item, String:tmp[64], String:item_number[4];

    for(new i = 0; i < GetArraySize(g_MenuItems); i++)
    {
        FormatEx(item_number, sizeof(item_number), "%i", i);
        item = GetArrayCell(g_MenuItems, i);
        GetArrayString(item, 1, tmp, sizeof(tmp));

        AddMenuItem(menu, item_number, tmp, ITEMDRAW_DEFAULT);
    }

    DisplayMenu(menu, client, 20);
}


public IGAMenuSelected(Handle:menu, MenuAction:action, param1, param2)
{
    decl String:tmp[32], selected;
    GetMenuItem(menu, param2, tmp, sizeof(tmp));
    selected = StringToInt(tmp);

    switch (action)
    {
        case MenuAction_Select:
            {
                new Handle:item = GetArrayCell(g_MenuItems, selected);
                new Handle:plugin_forward = GetArrayCell(item, 3);
                new bool:result;
                Call_StartForward(plugin_forward);
                Call_PushCell(param1);
                Call_Finish(result);
            }
        case MenuAction_End: CloseHandle(menu);
    }
}

public IGAMenu:ChangeVolumeMenu(client)
{
    new Handle:menu = CreateMenu(ChangeVolumeMenuHandler);
    new volume_state = g_Volume[client];//TODO
    new String:tmp[32];

    SetMenuTitle(menu, "Set IGA volume");

    AddMenuItem(menu, "1",  " █         (min)");
    AddMenuItem(menu, "2",  " ██");
    AddMenuItem(menu, "3",  " ███");
    AddMenuItem(menu, "4",  " ████");
    AddMenuItem(menu, "5",  " █████");
    AddMenuItem(menu, "6",  " ██████");
    AddMenuItem(menu, "7",  " ███████");
    AddMenuItem(menu, "8",  " ████████");
    AddMenuItem(menu, "9",  " █████████");
    AddMenuItem(menu, "10", " ██████████(max)");

    SetMenuExitButton(menu, false);
    SetMenuPagination(menu, MENU_NO_PAGINATION);

    DisplayMenu(menu, client, 20);
}


// Menu Handler
public ChangeVolumeMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
            {
                new String:info[32];
                GetMenuItem(menu, param2, info, sizeof(info));
                new volume = StringToInt(info);
                new client = param1;
                SetClientVolume(client, volume);
            }
        case MenuAction_End: CloseHandle(menu);
    }
}

public IGAMenu:PallEnabledMenu(client)
{
    new Handle:menu = CreateMenu(PallEnabledMenuHandler);
    new pall_enabled_state = g_IsPallEnabled[client];//TODO
    new String:tmp[32];

    SetMenuTitle(menu, "Listen To Unrequested Music?");

    AddMenuItem(menu, "1", "Yes (!yespall)");
    AddMenuItem(menu, "0", "No  (!nopall)");

    DisplayMenu(menu, client, 20);
}


// Menu Handler
public PallEnabledMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
            {
                new String:info[32];
                GetMenuItem(menu, param2, info, sizeof(info));
                new bool:val = bool:StringToInt(info);
                new client = param1;
                SetPallEnabled(client, val);
            }
        case MenuAction_End: CloseHandle(menu);
    }
}
