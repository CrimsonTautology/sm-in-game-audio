/**
 * vim: set ts=4 :
 * =============================================================================
 * in_game_audio_karaoke
 * Karaoke player for IGA
 *
 * Copyright 2013 CrimsonTautology
 * =============================================================================
 *
 */


#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <steamworks>
#include <smjansson>
#include <in_game_audio>
#include <morecolors>

#define PLUGIN_VERSION "1.8.3"
#define PLUGIN_NAME "In Game Audio Karaoke" 

#define MAX_KARAOKE_SONGS    64
#define MAX_LRC_LINE_LENGTH  256
#define MAX_KARAOKE_LYRICS   1024

#define SOUND_ATTENTION "vo/announcer_attention.mp3"

public Plugin:myinfo =
{
    name = PLUGIN_NAME,
    author = "CrimsonTautology",
    description = "Karaoke player for IGA",
    version = PLUGIN_VERSION,
    url = "https://github.com/CrimsonTautology/sm_in_game_audio"
};

//Parallel arrays to store karaoke songs
new String:g_KaraokeName[MAX_KARAOKE_SONGS][PLATFORM_MAX_PATH];
new String:g_KaraokeLRCPath[MAX_KARAOKE_SONGS][PLATFORM_MAX_PATH];
new g_KaraokeSongId[MAX_KARAOKE_SONGS];
new g_KaraokeSongCount = 0;

new String:g_KaraokeLyrics[MAX_KARAOKE_LYRICS][MAX_LRC_LINE_LENGTH];
new Float:g_KaraokeTimestamps[MAX_KARAOKE_LYRICS];

public OnPluginStart()
{
    LoadTranslations("in_game_audio.phrases");
    RegAdminCmd("sm_karaoke", Command_Karaoke, ADMFLAG_SLAY, "[ADMIN] Start a karaoke.");

    CreateConVar("sm_iga_karaoke_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
}

public OnMapStart()
{
    ReadKaraokeSongs();

    PrecacheSound(SOUND_ATTENTION);
    PrecacheSound("vo/announcer_begins_1sec.mp3");
    PrecacheSound("vo/announcer_begins_2sec.mp3");
    PrecacheSound("vo/announcer_begins_3sec.mp3");
    PrecacheSound("vo/announcer_begins_4sec.mp3");
    PrecacheSound("vo/announcer_begins_5sec.mp3");
}

public Action:Command_Karaoke(client, args)
{
    if(!IsIGAEnabled())
    {
        CReplyToCommand(client, "%t", "not_enabled");
        return Plugin_Handled;
    }

    if(IsInPall())
    {
        CReplyToCommand(client, "%t", "pall_currently_in_use");
        return Plugin_Handled;
    }

    KaraokeMenu(client);

    return Plugin_Handled;
}

public Action:Timer_DisplayLyric(Handle:timer, any:index)
{
    PrintCenterTextAll("%s", g_KaraokeLyrics[index]);
}

public Action:Timer_StartKaraokeQuery(Handle:timer, any:selected)
{
    QueryKaraoke(selected, g_KaraokeSongId[selected]);
}

public Action:Timer_CountDown(Handle:timer, any:second)
{
    decl String:sound[PLATFORM_MAX_PATH];
    FormatEx(sound, sizeof(sound), "vo/announcer_begins_%dsec.mp3", second);
    EmitSoundToAll(sound);
}

SteamWorks_SetHTTPRequestGetOrPostParameterInt(&Handle:request, const String:param[], value)
{
    new String:tmp[64];
    IntToString(value, tmp, sizeof(tmp));
    SteamWorks_SetHTTPRequestGetOrPostParameter(request, param, tmp);
}


ReadKaraokeSongs()
{
    g_KaraokeSongCount = 0;

    new Handle:kv = CreateKeyValues("Karaoke");

    decl String:path[PLATFORM_MAX_PATH], String:tmp[PLATFORM_MAX_PATH], String:game_folder[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/iga.karaoke.cfg");//TODO make this path a cvar

    if(FileExists(path))
    {
        FileToKeyValues(kv, path);
        KvGotoFirstSubKey(kv);

        do
        {
            KvGetSectionName(kv, tmp, sizeof(tmp));
            if(StrEqual(tmp, "Song") )
            {
                KvGetKaraokeSong(kv, g_KaraokeSongCount);
            }

        } while(KvGotoNextKey(kv) && g_KaraokeSongCount < MAX_KARAOKE_SONGS);

    } else {
        LogError("File Not Found: %s", path);
    }

    CloseHandle(kv);
}

KvGetKaraokeSong(Handle:kv, &index)
{
    KvGetString(kv, "name", g_KaraokeName[index], PLATFORM_MAX_PATH);
    KvGetString(kv, "lrc_file", g_KaraokeLRCPath[index], PLATFORM_MAX_PATH);
    g_KaraokeSongId[index] = KvGetNum(kv, "song_id", 0);

    index++;
}

ParseLRCFile(const String:file_name[], String:lyrics[][], Float:timestamps[])
{
    decl String:path[PLATFORM_MAX_PATH];
    new total_lyrics = 0;
    BuildPath(Path_SM, path, sizeof(path), "data/karaoke/%s", file_name);

    if(FileExists(path))
    {
        new Handle:file = OpenFile(path, "r");

        //Line by line reading
        decl String:line[MAX_LRC_LINE_LENGTH], index, split, Float:timestamp;
        while (total_lyrics < MAX_KARAOKE_LYRICS && !IsEndOfFile(file) && ReadFileLine(file, line, sizeof(line)))
        {
            //Skip non timestamp lines
            if(SimpleRegexMatch(line, "\\[[0-9]{2}\\:[0-6][0-9](\\.[0-6][0-9])?\\]([\\w:\\s]+)") <= 0) continue;

            //Strip linefeeds and returns
            ReplaceString(line, sizeof(line), "\r", "");
            ReplaceString(line, sizeof(line), "\n", "");
            ReplaceString(line, sizeof(line), "\xEF\xBB\xBF", ""); // UTF-8 "BOM"

            //Parse out timestamp and lyric
            index = FindCharInString(line, ']');
            if(index <= 0) continue; //Skip invalid line

            line[index] = '\0';
            split = FindCharInString(line, ':');

            g_KaraokeTimestamps[total_lyrics] = StringToInt(line[1]) * 60 + StringToFloat(line[split + 1]);
            strcopy(g_KaraokeLyrics[total_lyrics], MAX_LRC_LINE_LENGTH, line[index + 1]);

            total_lyrics++;
        }

    } else {
        LogError("Karaoke Lyrics File Not Found: %s", path);
    }

    return total_lyrics;
}

StartKaraokeCountDown(selected, Float:delay)
{
    EmitSoundToAll(SOUND_ATTENTION);
    PrintCenterTextAll("%s\nKaraoke Will Begin in 15 Seconds\nAdjust your volume now if needed!", g_KaraokeName[selected]);

    CreateTimer(delay - 5.0, Timer_CountDown, 5);
    CreateTimer(delay - 4.0, Timer_CountDown, 4);
    CreateTimer(delay - 3.0, Timer_CountDown, 3);
    CreateTimer(delay - 2.0, Timer_CountDown, 2);
    CreateTimer(delay - 1.0, Timer_CountDown, 1);

    CreateTimer(delay, Timer_StartKaraokeQuery, selected);
}

StartKaraokeLyricsDisplay(selected)
{
    new total, i;
    total = ParseLRCFile(g_KaraokeLRCPath[selected], g_KaraokeLyrics, g_KaraokeTimestamps);

    //Build timers to display lyrics for each parsed lyric
    for(i=0; i < total; i++)
    {
        CreateTimer(g_KaraokeTimestamps[i], Timer_DisplayLyric, i, TIMER_FLAG_NO_MAPCHANGE);
    }

}

QueryKaraoke(selected, song_id)
{
    if(IsInPall()) return;

    new Handle:request = CreateIGARequest(QUERY_SONG_ROUTE);

    SteamWorks_SetHTTPRequestGetOrPostParameter(request, "path", "");
    SteamWorks_SetHTTPRequestGetOrPostParameterInt(request, "pall", 1);
    SteamWorks_SetHTTPRequestGetOrPostParameterInt(request, "force", 1);

    SteamWorks_SetHTTPRequestGetOrPostParameterInt(request, "song_id", song_id);
    SteamWorks_SetHTTPRequestGetOrPostParameter(request, "uid", "76561197960804942");

    SteamWorks_SetHTTPCallbacks(request, ReceiveQueryKaraoke);
    SteamWorks_SetHTTPRequestContextValue(request, selected);
    SteamWorks_SendHTTPRequest(request);
}

public ReceiveQueryKaraoke(Handle:request, bool:failure, bool:successful, EHTTPStatusCode:code, any:selected)
{
    if(!successful || code != k_EHTTPStatusCode200OK)
    {
        LogError("[IGA] Error at RecivedQueryKaraoke (HTTP Code %d; success %d)", code, successful);
        CloseHandle(request);
        return;
    }


    new size = 0;
    SteamWorks_GetHTTPResponseBodySize(request, size);
    new String:data[size];
    SteamWorks_GetHTTPResponseBodyData(request, data, size);
    CloseHandle(request);

    new Handle:json = json_load(data);
    new bool:found = json_object_get_bool(json, "found");

    if(found)
    {
        //Found a matching song
        new duration = json_object_get_int(json, "duration");
        new bool:pall = json_object_get_bool(json, "pall");
        new bool:force = json_object_get_bool(json, "force");
        new String:song_id[64], String:full_path[64], String:description[64], String:duration_formated[64], String:access_token[128];
        json_object_get_string(json, "song_id", song_id, sizeof(song_id));
        json_object_get_string(json, "full_path", full_path, sizeof(full_path));
        json_object_get_string(json, "description", description, sizeof(description));
        json_object_get_string(json, "duration_formated", duration_formated, sizeof(duration_formated));
        json_object_get_string(json, "access_token", access_token, sizeof(access_token));

        CPrintToChatAll("%t", "started_playing_to_all", description);
        CPrintToChatAll("%t", "duration", duration_formated);

        RegisterPall(duration, full_path, description);

        StartKaraokeLyricsDisplay(selected);
        PlaySongAll(song_id, access_token, force);
    }else{
        CPrintToChatAll("%t", "not_found");
    }

    CloseHandle(json);
}

KaraokeMenu(client)
{
    new Handle:menu = CreateMenu(KaraokeMenuHandler);

    SetMenuTitle(menu, "Choose Karaoke Song");

    decl String:buf[16];
    for(new i=0; i < g_KaraokeSongCount && i < MAX_KARAOKE_SONGS; i++)
    {
        IntToString(i, buf, sizeof(buf));
        AddMenuItem(menu,
                buf,
                g_KaraokeName[i],
                ITEMDRAW_DEFAULT);
    }

    DisplayMenu(menu, client, 20);
}

public KaraokeMenuHandler(Handle:menu, MenuAction:action, param1, param2)
{
    switch (action)
    {
        case MenuAction_Select:
            {
                new client = param1;
                new String:info[32];
                GetMenuItem(menu, param2, info, sizeof(info));
                new selected = StringToInt(info);

                StartKaraokeCountDown(selected, 15.0);
            }
        case MenuAction_End: CloseHandle(menu);
    }
}
