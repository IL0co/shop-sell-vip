#include <sourcemod>
#include <shop>
#include <vip_core>

#pragma newdecls required
#pragma semicolon 1

KeyValues kv;
ItemId gItemId;
CategoryId iLastSeeCategory[MAXPLAYERS+1];
bool iInInventory[MAXPLAYERS+1];

public Plugin myinfo =
{
	name		= "[SHOP] Sell Vip",
	author	  	= "ღ λŌK0ЌЭŦ ღ ™",
	description = "",
	version	 	= "1.0.0",
	url			= "iLoco#7631"
};

public void OnPluginEnd()
{
	Shop_UnregisterMe();
}

public void OnPluginStart()
{
	if(Shop_IsStarted()) 
		Shop_Started();

	if(VIP_IsVIPLoaded())
	{
		for(int i = 1; i <= MaxClients; i++)	if(IsClientAuthorized(i) && IsClientInGame(i) && !IsFakeClient(i) && VIP_IsClientVIP(i))
			VIP_OnVIPClientLoaded(i);
	}

	LoadTranslations("shop_sell_vip.phrases");
	LoadTranslations("core.phrases");
}

public void Shop_Started()
{   
	if(kv) 
	{
		Shop_UnregisterMe();
		delete kv;
	}
	kv = new KeyValues("Shop_Vip");

	char buff[256];
	BuildPath(Path_SM, buff, sizeof(buff), "configs/shop/sell_vip.txt");

	if (!kv.ImportFromFile(buff)) 
		SetFailState("File '%s' is not found", buff);

	CategoryId category = Shop_RegisterCategory("stuff", "", "", Shop_CategoryDisplay);
	if(Shop_StartItem(category, "sell_vip"))
	{
		Shop_SetInfo("sell_vip", "", 1, -1, Item_Togglable);
		Shop_SetCallbacks(Shop_OnItemRegistered, Shop_OnItemToggle, Shop_OnItemShould, Shop_ItemDisplay, Shop_OnItemDescription2);
		Shop_EndItem();
	}
}

public bool Shop_CategoryDisplay(int client, CategoryId category_id, const char[] category, const char[] name, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", "Menu. Category Name", client);
	return true;
}

public bool Shop_ItemDisplay(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, bool &disabled, const char[] name, char[] buffer, int maxlen)
{
	FormatEx(buffer, maxlen, "%T", "Menu. Item Name", client);
	return true;
}

public bool Shop_OnItemDescription2(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu, const char[] description, char[] buffer, int maxlen)
{
	iLastSeeCategory[client] = category_id;
	iInInventory[client] = (menu == Menu_Inventory);

	CreateTimer(0.01, Timer_DelayShowMenu, client);
	return true;
}

public Action Timer_DelayShowMenu(Handle timer, int client)
{
	Panle_SellVip(client);
}

public ShopAction Shop_OnItemToggle(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
		return Shop_UseOff;
		
	return Shop_UseOn;
}

public void Shop_OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	gItemId = item_id;
}

public bool Shop_OnItemShould(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, ShopMenu menu)
{
	if(VIP_IsClientVIP(client))
	{
		kv.Rewind();

		char buff[64];
		VIP_GetClientVIPGroup(client, buff, sizeof(buff));

		int time = -1;

		if(kv.JumpToKey(buff) && (GetClientVipTime(client, time) || time >= 0))
			return true;
	}

	return false;
}

public void VIP_OnVIPClientAdded(int client, int admin)
{
	Shop_GiveClientItem(client, gItemId, 0);
}

public void VIP_OnVIPClientRemoved(int client, const char[] reason, int admin)
{
	if(Shop_IsClientHasItem(client, gItemId))
		Shop_RemoveClientItem(client, gItemId);
}

public void VIP_OnVIPClientLoaded(int client)
{
	if(!Shop_IsClientHasItem(client, gItemId))
		Shop_GiveClientItem(client, gItemId, 0);
	else if(!VIP_IsClientVIP(client))
		Shop_RemoveClientItem(client, gItemId);
}

public void Panle_SellVip(int client)
{
	Panel panel = new Panel();

	char translate[128];
	
	Format(translate, sizeof(translate), "%T", "Menu. Confirm", client);
	panel.SetTitle(translate);

	Format(translate, sizeof(translate), "%T", "Menu. Sell Price", client, GetClientVipSellPrice(client));
	panel.DrawText(translate);

	panel.CurrentKey = 1;
	Format(translate, sizeof(translate), "%T", "Menu. Ok", client);
	panel.DrawItem(translate);

	panel.CurrentKey = 7;
	Format(translate, sizeof(translate), "%T", "Back", client);
	panel.DrawItem(translate);

	panel.CurrentKey = 9;
	Format(translate, sizeof(translate), "%T", "Exit", client);
	panel.DrawItem(translate);
	
	panel.Send(client, PanelHendler_SellVip, 0);
	delete panel;
}

public int PanelHendler_SellVip(Menu panel, MenuAction action, int client, int item)
{
	if(action == MenuAction_Select)
	{
		if(item == 1)
		{
			Shop_GiveClientCredits(client, GetClientVipSellPrice(client));
			VIP_RemoveClientVIP2(0, client, true, false);

			Shop_ShowItemsOfCategory(client, iLastSeeCategory[client], iInInventory[client]);
		}

		if(item != 9)
			Shop_ShowItemsOfCategory(client, iLastSeeCategory[client], iInInventory[client]);
	}
}

stock int GetClientVipSellPrice(int client)
{
	char buff[64];
	kv.Rewind();
	VIP_GetClientVIPGroup(client, buff, sizeof(buff));
	kv.JumpToKey(buff);

	int vip_time;
	GetClientVipTime(client, vip_time);

	if(vip_time)
		return RoundToCeil(vip_time * kv.GetFloat("sell price", 1.0));

	return kv.GetNum("infinity price", 1);
}

stock bool GetClientVipTime(int client, int &time = 0)
{
	int myTime = VIP_GetClientAccessTime(client);

	if(myTime)
	{
		time = myTime - GetTime();
		return true;
	}
	
	time = 0;
	return false;
}
