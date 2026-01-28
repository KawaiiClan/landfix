#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <shavit>

#pragma semicolon 1
#pragma newdecls required

chatstrings_t gS_ChatStrings;

public Plugin myinfo = 
{
	name = "LandFix",
	author = "Haze, olivia",
	description = "Landfix edited for KawaiiClan",
	version = "c:",
	url = ""
}

//ConVar gCV_Units = null;
Handle gH_CookieEnabled = null;

bool gB_Enabled[MAXPLAYERS+1] = {false, ...};

int gI_LastGroundEntity[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_landfix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_landfixtype", Command_LandFixType, "There is only one real landfix u.u");
	RegConsoleCmd("sm_64", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_64fix", Command_LandFix, "Landfix");
	//gCV_Units = CreateConVar("landfix_units", "1.5", "", 0, true, 0.0, true, 2.0);
	
	gH_CookieEnabled = RegClientCookie("landfix_enabled", "landfix_enabled", CookieAccess_Protected);
	//AutoExecConfig();
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
	
	Shavit_OnChatConfigLoaded();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Landfix_GetLandfixEnabled", Native_GetLandfixEnabled);
	RegPluginLibrary("modern-landfix");
	return APLRes_Success;
}

int Native_GetLandfixEnabled(Handle handler, int numParams)
{
	return gB_Enabled[GetNativeCell(1)];
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessagePrefix, gS_ChatStrings.sPrefix, sizeof(chatstrings_t::sPrefix));
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, sizeof(chatstrings_t::sText));
	Shavit_GetChatStrings(sMessageWarning, gS_ChatStrings.sWarning, sizeof(chatstrings_t::sWarning));
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, sizeof(chatstrings_t::sVariable));
	Shavit_GetChatStrings(sMessageVariable2, gS_ChatStrings.sVariable2, sizeof(chatstrings_t::sVariable2));
	Shavit_GetChatStrings(sMessageStyle, gS_ChatStrings.sStyle, sizeof(chatstrings_t::sStyle));
}

public void OnClientCookiesCached(int client)
{
	char sCookie[8];
	
	GetClientCookie(client, gH_CookieEnabled, sCookie, sizeof(sCookie));
	gB_Enabled[client] = view_as<bool>(StringToInt(sCookie));
}

public Action Command_LandFix(int client, int args)
{
	if(client == 0) return Plugin_Handled;

	gB_Enabled[client] = !gB_Enabled[client];
	SetClientCookie(client, gH_CookieEnabled, gB_Enabled[client] ? "1" : "0");
	Shavit_PrintToChat(client, "LandFix %s%s", gS_ChatStrings.sVariable, gB_Enabled[client] ? "enabled" : "disabled");
	return Plugin_Handled;
}

public Action Command_LandFixType(int client, int args)
{
	if(client == 0) return Plugin_Handled;

	Shavit_PrintToChat(client, "There is only one LandFix (Haze), use %s!landfix %sto enable/disable it!", gS_ChatStrings.sVariable, gS_ChatStrings.sText);
	return Plugin_Handled;
}

//Thanks MARU for the idea/http://steamcommunity.com/profiles/76561197970936804
float GetGroundUnits(int client)
{
	if (!IsPlayerAlive(client)) return 0.0;
	if (GetEntityMoveType(client) != MOVETYPE_WALK) return 0.0;
	if (GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1) return 0.0;

	float origin[3], originBelow[3], landingMins[3], landingMaxs[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
	GetEntPropVector(client, Prop_Data, "m_vecMins", landingMins);
	GetEntPropVector(client, Prop_Data, "m_vecMaxs", landingMaxs);
	
	originBelow[0] = origin[0];
	originBelow[1] = origin[1];
	originBelow[2] = origin[2] - 2.0;

	TR_TraceHullFilter(origin, originBelow, landingMins, landingMaxs, MASK_PLAYERSOLID, PlayerFilter, client);

	if(!TR_DidHit())
	{
		return 0.0;
	}

	TR_GetEndPosition(originBelow, null);

	float defaultHeight = originBelow[2] - RoundToFloor(originBelow[2]);
	if(defaultHeight > 0.03125) 
	{
		defaultHeight = 0.03125;
	}

	return (origin[2] - originBelow[2] + defaultHeight);
}

/*public Action Shavit_PreOnKeyHintHUD(int client, int target, char[] keyhint, int keyhintlength, int track, int style, bool &forceUpdate)
{
	if(gB_Enabled[client])
	{
		Format(keyhint, keyhintlength, "Landfix\n\n", gB_Enabled[client] ? "On":"Off");
		forceUpdate = true;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}*/

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	int iGroundEnt = GetEntPropEnt(client, Prop_Data, "m_hGroundEntity");

	if(gB_Enabled[client]) 
	{
		if(iGroundEnt != gI_LastGroundEntity[client] && iGroundEnt != -1)
		{
			if(HasEntProp(iGroundEnt, Prop_Data, "m_currentSound")) //retrowave mega fix
			{
				return Plugin_Continue;
			}

			bool bHasVelocityProp = HasEntProp(iGroundEnt, Prop_Data, "m_vecVelocity");

			if(bHasVelocityProp)
			{
				float fVelocity[3];
				GetEntPropVector(iGroundEnt, Prop_Data, "m_vecVelocity", fVelocity);

				// ground is moving
				if(fVelocity[2] != 0.0)
				{
					return Plugin_Continue;
				}
			}

			if(!(buttons & IN_DUCK))
			{
				//float difference = (gCV_Units.FloatValue - GetGroundUnits(client)), origin[3];
				float difference = (1.50 - GetGroundUnits(client)), origin[3];
				GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
				origin[2] += difference;
				SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
			}
		}
	}

	gI_LastGroundEntity[client] = iGroundEnt;

	return Plugin_Continue;
}

public bool PlayerFilter(int entity, int mask)
{
	return !(1 <= entity <= MaxClients);
}
