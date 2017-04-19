#include <sourcemod>
#include <SteamWorks>

#pragma semicolon 1
#pragma newdecls required

//Defines
#define VERSION "1.00"
#define TRACKER_INITIATE_TIME 15.0
#define RETRY_WAIT_TIME 5.0

//Convars
ConVar cvar_identitylogger_secret = null;
ConVar cvar_identitylogger_updateurl = null;
ConVar cvar_identitylogger_trackerurl = null;
ConVar cvar_identitylogger_settrackingidurl = null;

public Plugin myinfo =
{
  name = "Identity Logger",
  author = "Invex | Byte",
  description = "Record various identity attributes for in-game players.",
  version = VERSION,
  url = "http://www.invexgaming.com.au"
};

// Plugin Start
public void OnPluginStart()
{
  //Flags
  CreateConVar("sm_identitylogger_version", VERSION, "", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_CHEAT|FCVAR_DONTRECORD);
  
  //Convars
  cvar_identitylogger_secret = CreateConVar("sm_identitylogger_secret", "", "A randomly generated secret key which is used to authorize update requests");
  cvar_identitylogger_updateurl = CreateConVar("sm_identitylogger_updateurl", "http://www.example.com/update.php", "Full URL path to update script");
  cvar_identitylogger_trackerurl = CreateConVar("sm_identitylogger_trackerurl", "http://www.example.com/tracker.php", "Full URL path to tracker script");
  cvar_identitylogger_settrackingidurl = CreateConVar("sm_identitylogger_settrackingidurl", "http://www.example.com/settrackingid.php", "Full URL path to settrackingid script");
  
  //Console commands
  RegAdminCmd("sm_identitylogger_setclienttrackingid", Command_SetClientTrackingId, ADMFLAG_ROOT, "See plugin description.");
  
  //Create config file
  AutoExecConfig(true, "identitylogger");
}

public void OnClientPutInServer(int client)
{
  //Call timer to begin storing tracking id
  CreateTimer(TRACKER_INITIATE_TIME, StoreTrackingId, client);
}

//Call script which will store the tracking id in a temporary database table
public Action StoreTrackingId(Handle timer, int client)
{
  //Ignore server
  if (client == 0)
    return Plugin_Handled;
  
  //Ignore if player disconnected or is a bot
  if (!IsClientConnected(client) || !IsClientInGame(client) || IsFakeClient(client))
    return Plugin_Handled;
    
  if (!IsClientAuthorized(client)) {
    //We need to delay slightly
    CreateTimer(RETRY_WAIT_TIME, StoreTrackingId, client);
    return Plugin_Handled;
  }
  
  //Get client steamid64
  char steamid64[18];
  GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
  
  //Show hidden VGUI Panel
  Handle panel = CreateKeyValues("data");
  
  KvSetString(panel, "title", "IdentityLogger");
  KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);
  
  //Prepare tracking url
  char trackerUrl[2048];
  cvar_identitylogger_trackerurl.GetString(trackerUrl, sizeof(trackerUrl));
  
  Format(trackerUrl, sizeof(trackerUrl), "%s?steamid64=%s", trackerUrl, steamid64);
  
  KvSetString(panel, "msg", trackerUrl);
  
  ShowVGUIPanel(client, "info", panel, false);
  CloseHandle(panel);
  
  //Now call logging function
  CreateTimer(RETRY_WAIT_TIME, LogIdentityInfo, client);
  
  return Plugin_Handled;
}

public Action LogIdentityInfo(Handle timer, int client)
{
  //Ignore server
  if (client == 0)
    return Plugin_Handled;
  
  //Ignore if player disconnected or is a bot
  if (!IsClientConnected(client) || !IsClientInGame(client) || IsFakeClient(client))
    return Plugin_Handled;
    
  if (!IsClientAuthorized(client)) {
    //We need to delay slightly
    CreateTimer(RETRY_WAIT_TIME, LogIdentityInfo, client);
    return Plugin_Handled;
  }
  
  //We can now log the information we need
  //Fetch alias, steamid64 and ipaddress of client
  char alias[64];
  char steamid64[18];
  char ipaddress[16];
  char serverip[16];
  char serverport[6];
  
  GetClientName(client, alias, sizeof(alias));
  GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64));
  GetClientIP(client, ipaddress, sizeof(ipaddress));
  
  int m_unIP = GetConVarInt(FindConVar("hostip"));
  Format(serverip, sizeof(serverip), "%d.%d.%d.%d", (m_unIP >> 24) & 0x000000FF, (m_unIP >> 16) & 0x000000FF, (m_unIP >> 8) & 0x000000FF, m_unIP & 0x000000FF);
  int m_unPort = GetConVarInt(FindConVar("hostport"));
  Format(serverport, sizeof(serverport), "%d", m_unPort);
  
  //Get update URL and secret key
  char updateURL[2048];
  char secretKey[256];
  cvar_identitylogger_updateurl.GetString(updateURL, sizeof(updateURL));
  cvar_identitylogger_secret.GetString(secretKey, sizeof(secretKey));
  
  //Send a connection update request to the update script
  Handle HTTPRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, updateURL);
  bool setsecret = SteamWorks_SetHTTPRequestHeaderValue(HTTPRequest, "IdentityLogger-Secret", secretKey);
  
  //Set POST parameters
  bool setalias = SteamWorks_SetHTTPRequestGetOrPostParameter(HTTPRequest, "alias", alias);
  bool setsteamid64 = SteamWorks_SetHTTPRequestGetOrPostParameter(HTTPRequest, "steamid64", steamid64);
  bool setipaddress = SteamWorks_SetHTTPRequestGetOrPostParameter(HTTPRequest, "ipaddress", ipaddress);
  bool setserverip = SteamWorks_SetHTTPRequestGetOrPostParameter(HTTPRequest, "serverip", serverip);
  bool setserverport = SteamWorks_SetHTTPRequestGetOrPostParameter(HTTPRequest, "serverport", serverport);
  
  bool setcallback = SteamWorks_SetHTTPCallbacks(HTTPRequest, IdentityLoggerHTTPCallback);
  
  if(!HTTPRequest || !setsecret || !setalias || !setsteamid64 || !setipaddress || !setserverip || !setserverport || !setcallback) {
    LogError("Error in setting IdentityLogger request properties, cannot send request.");
    CloseHandle(HTTPRequest);
    return Plugin_Handled;
  }
  
  bool sendrequest = SteamWorks_SendHTTPRequest(HTTPRequest);
  if(!sendrequest) {
    LogError("Error in sending IdentityLogger request, cannot send request.");
    CloseHandle(HTTPRequest);
    return Plugin_Handled;
  }
  
  SteamWorks_PrioritizeHTTPRequest(HTTPRequest);
  
  return Plugin_Handled;
}

//Disregard callback
public int IdentityLoggerHTTPCallback(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, any data1)
{
  if (!bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK) {
    //Log error
    LogError("Error in receiving 200 code OK response. Update may have failed.");
  }

  CloseHandle(hRequest);
}

//Set trackingid of client with a particular targetsteamid64
public Action Command_SetClientTrackingId(int client, int args)
{
  //Not enough arguments
  if (args != 2) {
    return Plugin_Handled;
  }
  
  //Get arguments
  char targetsteamid64[18];
  char trackingid[65];
  
  GetCmdArg(1, targetsteamid64, sizeof(targetsteamid64));
  GetCmdArg(2, trackingid, sizeof(trackingid));
  
  //Set the clients tracking id
  SetClientTrackingId(targetsteamid64, trackingid);
  
  return Plugin_Handled;
}

void SetClientTrackingId(char[] targetsteamid64, char[] trackingid)
{
  if (strlen(trackingid) == 0)
    return;
    
  //Find the right client to target
  for (int i = 1; i <= MaxClients; ++i) {
    if (!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i) || !IsClientAuthorized(i)) {
      continue;
    }
    
    //Get client steamid64
    char steamid64[18];
    GetClientAuthId(i, AuthId_SteamID64, steamid64, sizeof(steamid64));
    
    //Compare steamid64 to target steamid64
    if (StrEqual(steamid64, targetsteamid64)) {
      //Match found, set tracking cookie
      //Show hidden VGUI Panel
      Handle panel = CreateKeyValues("data");
      
      KvSetString(panel, "title", "IdentityLogger");
      KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);
      
      //Prepare settrackingid url
      char setTrackingIdUrl[2048];
      cvar_identitylogger_settrackingidurl.GetString(setTrackingIdUrl, sizeof(setTrackingIdUrl));
      
      Format(setTrackingIdUrl, sizeof(setTrackingIdUrl), "%s?trackingid=%s", setTrackingIdUrl, trackingid);
      
      KvSetString(panel, "msg", setTrackingIdUrl);
      
      ShowVGUIPanel(i, "info", panel, false);
      CloseHandle(panel);
      
      break; //leave for loop
    }
  }
}