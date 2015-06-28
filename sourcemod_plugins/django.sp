#pragma semicolon 1

#pragma dynamic 32767 //Increase memory limit to avoid crashes, according to cURL example plugin source

#include <sourcemod>
#include <socket>

#define PLUGIN_VERSION "0.1"
#define ADMIN_GROUP "Premium"

public Plugin:myinfo = {
  name = "Donor admin backend",
  author = "Azelphur",
  description = "Reads all players players who have donated, gives them relevant admin flags.",
  version = PLUGIN_VERSION,
  url = ""
};

new String:temp_cache_path[PLATFORM_MAX_PATH];
new bool:headers = true;

public OnPluginStart() {
    decl String:cache_dir_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, cache_dir_path, sizeof(cache_dir_path), "data/premium-cache/");
    BuildPath(Path_SM, temp_cache_path, sizeof(temp_cache_path), "data/premium-cache/cache.vdf");
    if (OpenDirectory(cache_dir_path) == INVALID_HANDLE) {
        if (!CreateDirectory(cache_dir_path, 511)) {
            SetFailState("Error accessing or creating cache directory: %s", cache_dir_path);
        }
    }
}

public OnRebuildAdminCache(AdminCachePart:part) {
    if (AdminCachePart:part == AdminCache_Admins) {
        GetPremiums();
    }
}

public GetPremiums()
{
    // create a new tcp socket
    new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
    // open a file handle for writing the result
    new Handle:hFile = OpenFile(temp_cache_path, "wb");
    // pass the file handle to the callbacks
    SocketSetArg(socket, hFile);
    // connect the socket
    SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, "game.azelphur.com", 80);
}

public OnSocketConnected(Handle:socket, any:arg) {
    // socket is connected, send the http request

    decl String:requestStr[100];
    Format(requestStr, sizeof(requestStr), "GET /%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\n\r\n", "api/premiumList", "game.azelphur.com");
    SocketSend(socket, requestStr);
}

public OnSocketReceive(Handle:socket, String:receiveData[], const dataSize, any:hFile) {
    // receive another chunk and write it to <modfolder>/dl.htm
    // we could strip the http response header here, but for example's sake we'll leave it in
    if (headers) {
        new pos = StrContains(receiveData, "\r\n\r\n");
        if (pos != -1) {
            WriteFileString(hFile, receiveData[pos+4], false);
        }
    }
    else {
        WriteFileString(hFile, receiveData, false);
    }
}

public OnSocketDisconnected(Handle:socket, any:hFile) {
    // Connection: close advises the webserver to close the connection when the transfer is finished
    // we're done here

    CloseHandle(hFile);
    CloseHandle(socket);
    headers = true;
    new Handle:smc = SMC_CreateParser();
    SMC_SetReaders(smc, SMC_NewSection, SMC_KeyValue, SMC_EndSection);
    SMC_ParseFile(smc, temp_cache_path);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:hFile) {
    // a socket error occured

    LogError("socket error %d (errno %d)", errorType, errorNum);
    CloseHandle(hFile);
    CloseHandle(socket);
}

public SMCResult:SMC_KeyValue(Handle:smc, const String:key[], const String:value[], bool:key_quotes, bool:value_quotes)
{
    new GroupId:admin_group_id;
    if ((admin_group_id = FindAdmGroup(ADMIN_GROUP)) == INVALID_GROUP_ID) {
        SetFailState("Premium admin group not found");
    }
    new AdminId:admin;
    if ((admin = FindAdminByIdentity("steam", key)) == INVALID_ADMIN_ID) {
        admin = CreateAdmin(key);
        AdminInheritGroup(admin, admin_group_id);
        BindAdminIdentity(admin, "steam", key);
        decl String:szAuth[64];
        for (new i=1; i <= MaxClients; i++) {
            if (IsClientConnected(i) && IsClientAuthorized(i)) {
                GetClientAuthString(i, szAuth, sizeof(szAuth));
                if (StrEqual(szAuth, key))
                    SetUserAdmin(i, admin);
            }
        }
    }

    return SMCParse_Continue;
}

public SMCResult:SMC_NewSection(Handle:smc, const String:name[], bool:opt_quotes) {}

public SMCResult:SMC_EndSection(Handle:smc) {}
