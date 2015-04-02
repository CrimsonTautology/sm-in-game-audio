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

#define PLUGIN_VERSION "1.8.1"
#define PLUGIN_NAME "In Game Audio Karaoke" 

#define MAX_KARAOKE_SONGS 64

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

public OnPluginStart()
{
    LoadTranslations("in_game_audio.phrases");

    CreateConVar("sm_iga_karaoke_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);
}

public OnMapStart()
{
    ReadKaraokeSongs();
}

ReadKaraokeSongs()
{
    g_KaraokeSongCount = 0;

    new Handle:kv = CreateKeyValues("Karaoke");

    decl String:path[PLATFORM_MAX_PATH];
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
    KvGetNum(kv, "song_id", g_KaraokeSongId[index], 0);

    index++;
}

ParseLRCFile(const String:file_name[])
{
}

