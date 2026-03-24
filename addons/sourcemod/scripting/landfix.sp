#include <sdktools>
#include <sdkhooks>
#include <dhooks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "LandFix",
	author = "olivia",
	description = "FiH landfix edited for KawaiiClan servers, released for all.. as all things should be",
	version = "c:",
	url = "https://KawaiiClan.com"
}

Handle g_hCheckJumpButtonHookPre;

public void OnPluginStart()
{
    RegConsoleCmd("sm_landfixtype", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_landingfix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_landfix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_landing", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_lf", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_64fix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_64", Command_LandFix, "Landfix");

	GameData gd = LoadGameConfigFile("landfix.games");
	StartPrepSDKCall(SDKCall_Static);
	if(!PrepSDKCall_SetFromConf(gd, SDKConf_Signature, "CreateInterface"))
		SetFailState("Failed to get CreateInterface");

	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Pointer, VDECODE_FLAG_ALLOWNULL);
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
	Handle CreateInterface = EndPrepSDKCall();

	if(CreateInterface == null)
		SetFailState("Unable to prepare SDKCall for CreateInterface");

	char interfaceName[64];
	if(!GameConfGetKeyValue(gd, "IGameMovement", interfaceName, sizeof(interfaceName)))
		SetFailState("Failed to get IGameMovement interface name");

	Address IGameMovement = SDKCall(CreateInterface, interfaceName, 0);
	if(!IGameMovement)
		SetFailState("Failed to get IGameMovement pointer");

	int offset = GameConfGetOffset(gd, "CheckJumpButton");
	if(offset == -1)
		SetFailState("Failed to get CheckJumpButton offset");

	g_hCheckJumpButtonHookPre = DHookCreate(offset, HookType_Raw, ReturnType_Bool, ThisPointer_Address, DHook_CheckJumpButtonPre);
	DHookRaw(g_hCheckJumpButtonHookPre, false, IGameMovement);

	delete gd;
	delete CreateInterface;
}

public Action Command_LandFix(int client, int args)
{
	if(client == 0) return Plugin_Handled;
	PrintToChat(client, "[SM] This LandFix is always enabled and does NOT cause time loss, so no need to enable or change it (:");
	return Plugin_Handled;
}

MRESReturn DHook_CheckJumpButtonPre(Address pThis, Handle hParams)
{
	Address mv = view_as<Address>(LoadFromAddress(pThis + view_as<Address>(0x8), NumberType_Int32));
	int client = LoadFromAddress(mv + view_as<Address>(0x4), NumberType_Int32) & 0xFFFF;

	if(IsFakeClient(client) || !IsPlayerAlive(client))
		return MRES_Ignored;

	if(!GetEntPropFloat(client, Prop_Data, "m_flWaterJumpTime"))
	{
		if(GetEntProp(client, Prop_Data, "m_nWaterLevel") >= 2 || GetEntPropEnt(client, Prop_Data, "m_hGroundEntity") == -1)
			return MRES_Ignored;

		int mv_old_buttons = LoadFromAddress(mv + view_as<Address>(0x28), NumberType_Int32);
		if(mv_old_buttons & IN_JUMP || mv_old_buttons & IN_DUCK)
			return MRES_Ignored;

		float origin[3];
		float grndPos[3];
		origin[0] = view_as<float>(LoadFromAddress(mv + view_as<Address>(0x9C + 0x0), NumberType_Int32));
		origin[1] = view_as<float>(LoadFromAddress(mv + view_as<Address>(0x9C + 0x4), NumberType_Int32));
		origin[2] = view_as<float>(LoadFromAddress(mv + view_as<Address>(0x9C + 0x8), NumberType_Int32));
		GetGroundPosition(client, origin, grndPos);

		float diff = FloatAbs(grndPos[2] - origin[2]);
		if(diff < 0.49)
		{
			origin[2] = grndPos[2] + 0.49;
			StoreToAddress(mv + view_as<Address>(0x9C + 0x0), view_as<int>(origin[0]), NumberType_Int32);
			StoreToAddress(mv + view_as<Address>(0x9C + 0x4), view_as<int>(origin[1]), NumberType_Int32);
			StoreToAddress(mv + view_as<Address>(0x9C + 0x8), view_as<int>(origin[2]), NumberType_Int32);
		}
		else if(diff > 1.5 && diff < 2.0)
		{
			origin[2] = grndPos[2] + 1.5;
			StoreToAddress(mv + view_as<Address>(0x9C + 0x0), view_as<int>(origin[0]), NumberType_Int32);
			StoreToAddress(mv + view_as<Address>(0x9C + 0x4), view_as<int>(origin[1]), NumberType_Int32);
			StoreToAddress(mv + view_as<Address>(0x9C + 0x8), view_as<int>(origin[2]), NumberType_Int32);
		}
	}
	return MRES_Ignored;
}

void GetGroundPosition(int client, float origin[3], float out[3])
{
	float originBelow[3], landingMins[3], landingMaxs[3];
	GetEntPropVector(client, Prop_Data, "m_vecMins", landingMins);
	GetEntPropVector(client, Prop_Data, "m_vecMaxs", landingMaxs);

	originBelow[0] = origin[0];
	originBelow[1] = origin[1];
	originBelow[2] = origin[2] - 2.0;

	TR_TraceHullFilter(origin, originBelow, landingMins, landingMaxs, MASK_PLAYERSOLID, PlayerFilter, client);
	if(!TR_DidHit())
		return;

	TR_GetEndPosition(out, null);
}

public bool PlayerFilter(int entity, int mask)
{
	return !(1 <= entity <= MaxClients);
}
