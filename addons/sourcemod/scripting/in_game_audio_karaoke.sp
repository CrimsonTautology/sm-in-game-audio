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
#include <in_game_audio>
#include <morecolors>

#define PLUGIN_VERSION "1.8.1"
#define PLUGIN_NAME "In Game Audio Karaoke" 

#define MAX_KARAOKE_SONGS    64
#define MAX_LRC_LINE_LENGTH  256
#define MAX_KARAOKE_LYRICS   1024

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

    new total, Float:delay=10.0, song_id=726;
    total = ParseLRCFile("example.lrc", g_KaraokeLyrics, g_KaraokeTimestamps);//TODO

    //Build timers to display lyrics for each parsed lyric
    new i = 0;
    for(i=0; i < total; i++)
    {
        CreateTimer(g_KaraokeTimestamps[i] + delay, Timer_DisplayLyric, i, TIMER_FLAG_NO_MAPCHANGE);
    }

    CreateTimer(delay, Timer_StartSong, song_id);

    return Plugin_Handled;
}

public Action:Timer_DisplayLyric(Handle:timer, any:index)
{
    PrintToConsole(0, "%s", g_KaraokeLyrics[index]); //TODO
    //PrintCenterTextAll("%s", g_KaraokeLyrics[index]);
}

public Action:Timer_StartSong(Handle:timer, any:song_id)
{
    QuerySong(0, "", true, true, song_id);
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
    KvGetNum(kv, "song_id", g_KaraokeSongId[index]);

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

