/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio_donator_intro
 * Plays a user's theme song when they join the server if they are a donator.
 * A user's theme is set through the In Game Audio website.
 *
 * Copyright 2013 Crimsontautology
 * =============================================================================
 *
 */


#pragma semicolon 1

#include <sourcemod>
#include <in_game_audio>
#include <steamtools>
#include <smjansson>
#undef REQUIRE_PLUGIN
#include <donator>

#define PLUGIN_VERSION "1.4"

new bool:g_CanIntroPlay[MAXPLAYERS+1];
new bool:g_DonatorLibraryExists = false;

public Plugin:myinfo =
{
    name = "In Game Audio Donator Intro",
    author = "CrimsonTautology",
    description = "Play donator's theme song when they join the server",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

public OnPluginStart()
{
    LoadTranslations("in_game_audio.phrases");
    AddCommandListener(Event_JoinClass, "joinclass");
    g_DonatorLibraryExists = LibraryExists("donator.core");
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
    MarkNativeAsOptional("IsPlayerDonator");
    MarkNativeAsOptional("Donator_RegisterMenuItem");
    return APLRes_Success;
}

public OnAllPluginsLoaded()
{
    if (g_DonatorLibraryExists)
    {
        Donator_RegisterMenuItem("Donator Intro Song", DonatorIntroMenu);
    }
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
        g_CanIntroPlay[client] = IsPlayerDonator(client);
    }
}

public OnClientConnected(client)
{
    if (!g_DonatorLibraryExists)
    {
        g_CanIntroPlay[client] = true;
    }
}

public OnClientDisconnect(client)
{
    g_CanIntroPlay[client] = false;
}


public Action:Event_JoinClass(client, const String:command[], args)
{
    if(g_CanIntroPlay[client])
    {
        UserTheme(client);
        g_CanIntroPlay[client] = false;
    }

    return Plugin_Continue;
}

public DonatorMenu:DonatorIntroMenu(client) UserThemesPage(client);

/**
 * Gets the auto-login token for a client so they can use the IGA
 * website via the MOTD without logging in.
 */
UserThemesPage(client)
{
    new HTTPRequestHandle:request = CreateIGARequest(GENERATE_LOGIN_TOKEN_ROUTE);
    new player = client > 0 ? GetClientUserId(client) : 0;

    if(request == INVALID_HTTP_HANDLE)
    {
        ReplyToCommand(client, "\x04%t", "url_invalid");
        return;
    }

    decl String:uid[MAX_COMMUNITYID_LENGTH];
    Steam_GetCSteamIDForClient(client, uid, sizeof(uid));
    Steam_SetHTTPRequestGetOrPostParameter(request, "uid", uid);

    Steam_SendHTTPRequest(request, callback, player);
}
public ReceiveUserThemesPage(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid)
{
    new client = GetClientOfUserId(userid);
    if(!successful || code != HTTPStatusCode_OK)
    {
        LogError("[IGA] Error at UserThemesPage (HTTP Code %d; success %d)", code, successful);
        Steam_ReleaseHTTPRequest(request);
        return;
    }

    if(client)
    {
        decl String:data[4096];
        Steam_GetHTTPResponseBodyData(request, data, sizeof(data));
        Steam_ReleaseHTTPRequest(request);

        new Handle:json = json_load(data);
        new String:uid[128], String:login_token[128];
        json_object_get_string(json, "uid", uid, sizeof(uid));
        json_object_get_string(json, "login_token", login_token, sizeof(login_token));

        //Popup webpage
        decl String:args[256]="";
        Format(args, sizeof(args),
                "/%s/themes?login_token=%s", uid, login_token);
        CreateIGAPopup(client, USERS_ROUTE, args);

        CloseHandle(json);
    }else{
        Steam_ReleaseHTTPRequest(request);
    }
}
