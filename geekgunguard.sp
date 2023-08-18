#include <sourcemod>
#include <cstrike>

// Version 0.5
// Author: Edgespresso

new Handle:g_RestrictedPlayers;

/**
 * Initialization function.
 */
public void OnPluginStart() {
    g_RestrictedPlayers = CreateArray(32);

    // Register admin commands
    RegAdminCmd("sm_restrict", Cmd_RestrictWeapon, ADMFLAG_GENERIC, "Restrict a weapon for a player");
    RegAdminCmd("sm_unrestrictall", Cmd_UnrestrictAll, ADMFLAG_GENERIC, "Remove all weapon restrictions");
    RegAdminCmd("sm_restrictlist", Cmd_ListRestrictions, ADMFLAG_GENERIC, "List all weapon restrictions");
}

/**
 * Command function to unrestrict all weapons.
 */
public Action Cmd_UnrestrictAll(int client, int args) {
    while (GetArraySize(g_RestrictedPlayers) > 0) {
        RemoveFromArray(g_RestrictedPlayers, 0);
    }
    ReplyToCommand(client, "All weapon restrictions removed!");
    return Plugin_Handled;
}

/**
 * Utility function to get the client index from a SteamID.
 */
public int GetClientOfSteamID(const char[] steamID) {
    for (int i = 1; i <= MaxClients; i++) {
        char checkSteamID[32];
        GetClientAuthId(i, AuthId_Steam3, checkSteamID, sizeof(checkSteamID));
        if (StrEqual(steamID, checkSteamID)) {
            return i;
        }
    }
    return 0;
}

/**
 * Utility function to extract the weapon name from the restriction string.
 */
public void ExtractWeaponFromRestriction(const char[] sRestricted, char[] sWeapon) {
    int delimiterPos = StrContains(sRestricted, "_");
    if (delimiterPos != -1) {
        int k = 0;
        for (int j = delimiterPos + 1; j < strlen(sRestricted) && sRestricted[j] != '\0'; j++, k++) {
            sWeapon[k] = sRestricted[j];
        }
        sWeapon[k] = '\0';
    }
}

/**
 * Utility function to extract the SteamID from the restriction string.
 */
public void ExtractSteamIDFromRestriction(const char[] sRestricted, char[] sSteamID) {
    int delimiterPos = StrContains(sRestricted, "_");
    if (delimiterPos != -1) {
        for (int j = 0; j < delimiterPos && j < strlen(sRestricted); j++) {
            sSteamID[j] = sRestricted[j];
        }
        sSteamID[delimiterPos] = '\0';  // Terminate the string at the delimiter
    }
}

/**
 * Command function to restrict a weapon for players.
 */
public Action Cmd_RestrictWeapon(int client, int args) {
    if (args < 2) {
        ReplyToCommand(client, "Usage: sm_restrict <weapon> <playerID | T | CT | all>");
        return Plugin_Handled;
    }

    char sWeapon[32], sTarget[32], sRestricted[64];
    GetCmdArg(1, sWeapon, sizeof(sWeapon));
    GetCmdArg(2, sTarget, sizeof(sTarget));

    if (StrEqual(sTarget, "T") || StrEqual(sTarget, "CT") || StrEqual(sTarget, "all")) {
        for (int i = 1; i <= MaxClients; i++) {
            if (!IsClientInGame(i)) continue;

            char sSteamID[32];
            GetClientAuthId(i, AuthId_Steam3, sSteamID, sizeof(sSteamID));

            // Skip if the player is a bot
            if (StrEqual(sSteamID, "BOT")) continue;

            if ((StrEqual(sTarget, "T") && GetClientTeam(i) == 2) || 
                (StrEqual(sTarget, "CT") && GetClientTeam(i) == 3) || 
                StrEqual(sTarget, "all")) {

                Format(sRestricted, sizeof(sRestricted), "%s_%s", sSteamID, sWeapon);
                PushArrayString(g_RestrictedPlayers, sRestricted);
            }
        }
    } else {
        // Restrict for a specific player's SteamID
        Format(sRestricted, sizeof(sRestricted), "%s_%s", sTarget, sWeapon);
        PushArrayString(g_RestrictedPlayers, sRestricted);
    }

    return Plugin_Handled;
}

/**
 * Command function to list the weapon restrictions.
 */
public Action Cmd_ListRestrictions(int client, int args) {
    int arraySize = GetArraySize(g_RestrictedPlayers);
    
    if (arraySize == 0) {
        ReplyToCommand(client, "No weapon restrictions set.");
        return Plugin_Handled;
    }

    for (int i = 0; i < arraySize; i++) {
        char sRestricted[64];
        GetArrayString(g_RestrictedPlayers, i, sRestricted, sizeof(sRestricted));
        
        char sWeapon[32], sSteamID[32];
        ExtractSteamIDFromRestriction(sRestricted, sSteamID);
        ExtractWeaponFromRestriction(sRestricted, sWeapon);

        if (sSteamID[0] == 'B' && sSteamID[1] == 'O' && sSteamID[2] == 'T') continue;  // Skip bots

        int target = GetClientOfSteamID(sSteamID);
        if (target > 0) {
            char playerName[64];
            GetClientName(target, playerName, sizeof(playerName));
            ReplyToCommand(client, "%s %s", sWeapon, playerName);
        }
    }

    return Plugin_Handled;
}
