#include <sourcemod>

ArrayList g_RestrictedPlayers;
ArrayList g_PlayerTiers;

typedef struct {
    char steamID[32];
    char weapon[32];
} RestrictedInfo;

typedef struct {
    char steamID[32];
    char tier[32];
} PlayerTier;

char g_TierWeapons[4][128][32];
int g_TierWeaponCount[4];

enum Tier {
    MASTER,
    GOLD,
    SILVER,
    BRONZE,
    TIER_COUNT
};

public void OnPluginStart() {
    g_RestrictedPlayers = new ArrayList(sizeof(RestrictedInfo));
    g_PlayerTiers = new ArrayList(sizeof(PlayerTier));

    LoadTierWeapons("master");
    LoadTierWeapons("gold");
    LoadTierWeapons("silver");
    LoadTierWeapons("bronze");

    RegAdminCmd("sm_restrict", Cmd_RestrictWeapon, ADMFLAG_GENERIC, "Restrict a weapon for a player");
    RegAdminCmd("sm_unrestrictall", Cmd_UnrestrictAll, ADMFLAG_GENERIC, "Remove all weapon restrictions");
    RegAdminCmd("sm_restrict_tier", Cmd_RestrictTier, ADMFLAG_GENERIC, "Restrict all players in a specific tier");
    RegAdminCmd("sm_settier", Cmd_SetTier, ADMFLAG_GENERIC, "Set the tier for a player");
}

public Action Cmd_RestrictWeapon(int client, int args) {
    if (args < 2) {
        ReplyToCommand(client, "Usage: sm_restrict <weapon> <steamID>");
        return Plugin_Handled;
    }

    RestrictedInfo info;
    GetCmdArg(0, info.weapon, sizeof(info.weapon));
    GetCmdArg(1, info.steamID, sizeof(info.steamID));

    g_RestrictedPlayers.Push(info);
    ReplyToCommand(client, "Restricted weapon %s for SteamID: %s", info.weapon, info.steamID);

    return Plugin_Handled;
}

public Action Cmd_UnrestrictAll(int client, int args) {
    g_RestrictedPlayers.Clear();
    ReplyToCommand(client, "All weapon restrictions removed!");
    return Plugin_Handled;
}

public Action Cmd_RestrictTier(int client, int args) {
    if (args < 1) {
        ReplyToCommand(client, "Usage: sm_restrict_tier <tier_name>");
        return Plugin_Handled;
    }

    char tierName[32];
    GetCmdArg(0, tierName, sizeof(tierName));
    int tierIndex = GetTierIndexByName(tierName);
    if (tierIndex == -1) {
        ReplyToCommand(client, "Unknown tier: %s", tierName);
        return Plugin_Handled;
    }

    for (int i = 0; i < g_PlayerTiers.Length; i++) {
        PlayerTier playerTier;
        g_PlayerTiers.GetArray(i, playerTier);
        if (StrEqual(playerTier.tier, tierName)) {
            for (int j = 0; j < g_TierWeaponCount[tierIndex]; j++) {
                RestrictedInfo info;
                strcopy(info.steamID, sizeof(info.steamID), playerTier.steamID);
                strcopy(info.weapon, sizeof(info.weapon), g_TierWeapons[tierIndex][j]);
                g_RestrictedPlayers.Push(info);
            }
        }
    }

    ReplyToCommand(client, "All players in tier %s have been restricted!", tierName);
    return Plugin_Handled;
}

public Action Cmd_SetTier(int client, int args) {
    if (args < 2) {
        ReplyToCommand(client, "Usage: sm_settier <steamID> <tier_name>");
        return Plugin_Handled;
    }

    char sSteamID[32], sTier[32];
    GetCmdArg(0, sSteamID, sizeof(sSteamID));
    GetCmdArg(1, sTier, sizeof(sTier));

    if (GetTierIndexByName(sTier) == -1) {
        ReplyToCommand(client, "Unknown tier: %s. Available tiers: master, gold, silver, bronze.", sTier);
        return Plugin_Handled;
    }

    int playerTierIndex = FindPlayerTierIndex(sSteamID);
    if (playerTierIndex != -1) {
        PlayerTier playerTier;
        g_PlayerTiers.GetArray(playerTierIndex, playerTier);
        strcopy(playerTier.tier, sizeof(playerTier.tier), sTier);
        g_PlayerTiers.SetArray(playerTierIndex, playerTier);
    } else {
        PlayerTier newTier;
        strcopy(newTier.steamID, sizeof(newTier.steamID), sSteamID);
        strcopy(newTier.tier, sizeof(newTier.tier), sTier);
        g_PlayerTiers.Push(newTier);
    }

    ReplyToCommand(client, "Set tier %s for SteamID: %s", sTier, sSteamID);
    return Plugin_Handled;
}

public int GetTierIndexByName(const char[] tierName) {
    if (StrEqual(tierName, "master")) return MASTER;
    if (StrEqual(tierName, "gold")) return GOLD;
    if (StrEqual(tierName, "silver")) return SILVER;
    if (StrEqual(tierName, "bronze")) return BRONZE;
    return -1;
}

public int FindPlayerTierIndex(const char[] steamID) {
    for (int i = 0; i < g_PlayerTiers.Length; i++) {
        PlayerTier playerTier;
        g_PlayerTiers.GetArray(i, playerTier);
        if (StrEqual(playerTier.steamID, steamID)) {
            return i;
        }
    }
    return -1;
}

public void LoadTierWeapons(const char[] tierName) {
    char path[128];
    Format(path, sizeof(path), "configs/tier_%s.cfg", tierName);

    File file = OpenFile(path, "r");
    if (file == null) {
        LogError("Failed to load tier weapons from: %s", path);
        return;
    }

    int tierIndex = GetTierIndexByName(tierName);
    if (tierIndex == -1) {
        CloseHandle(file);
        return;
    }

    char line[32];
    int count = 0;
    while (!file.EndOfFileReached() && count < 128) {
        file.ReadLine(line, sizeof(line));
        TrimString(line);
        if (strlen(line) > 0) {
            strcopy(g_TierWeapons[tierIndex][count], sizeof(g_TierWeapons[tierIndex][count]), line);
            count++;
        }
    }

    g_TierWeaponCount[tierIndex] = count;
    CloseHandle(file);
}
