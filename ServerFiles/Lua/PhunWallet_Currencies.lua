return {
	-- the items PhunWallet will consider "Currencies"
	{
		type = "PhunMart.SilverDollar",
		zedSpawnChance = 1,
		zedSprinterSpawnChance = 20,
		spawnMin = 1,
		spawnMax = 3,
		removeFromContainers = true,
		removeFromZeds = false
	},
	{
		type = "PhunMart.CheeseToken",
		boa = false,
		zedSpawnChance = 0,
		zedSprinterSpawnChance = 1,
		spawnMin = 1,
		spawnMax = 3,
		removeFromContainers = true,
		removeFromZeds = false
	},
	{
		type = "PhunWallet.TraiterToken",
		boa = true,
		zedSpawnChance = 0,
		zedSprinterSpawnChance = 1,
		spawnMin = 1,
		spawnMax = 3,
		removeFromContainers = true,
		removeFromZeds = false
	}
}
