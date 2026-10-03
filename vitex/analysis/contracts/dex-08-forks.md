# Excerpt: mainnet fork heights (final build) - which contract map is active
# Sources: common/upgrade/upgrade_init.go (NewMainnetUpgradeBox); common/upgrade/face.go 149-192

func NewMainnetUpgradeBox() *upgradeBox {
	return newUpgradeBox([]*UpgradePoint{
		{
			Name:    "SeedFork",
			Height:  3488471,
			Version: 1,
		},
		{
			Name:    "DexFork",
			Height:  5442723,
			Version: 2,
		},
		{
			Name:    "DexFeeFork",
			Height:  8013367,
			Version: 3,
		},
		{
			Name:    "StemFork",
			Height:  8403110,
			Version: 4,
		},
		{
			Name:    "LeafFork",
			Height:  9413600,
			Version: 5,
		},
		{
			Name:    "EarthFork",
			Height:  16634530,
			Version: 6,
		},
		{
			Name:    "DexMiningFork",
			Height:  17142720,
			Version: 7,
		},
		{
			Name:    "DexRobotFork",
			Height:  31305900,
			Version: 8,
		},
		{
			Name:    "DexStableMarketFork",
			Height:  39694000,
			Version: 9,
		},
		{
			Name:    "Version10",
			Height:  77106666,
			Version: 10,
		},
		{
			Name:    "Version11",
			Height:  101320000,
			Version: 11,
		},
		{
			Name:    "Version12",
			Height:  116480000,
			Version: 12,
		},
		{
			Name:    "Version13",
			Height:  166869900,
			Version: 13,
		},
		{
			Name:    "VersionX",
			Height:  EndlessHeight,
			Version: 14,
		},
	})
}

func IsEarthUpgrade(sHeight uint64) bool {
	assertUpgradeNotNil()
	return upgrade.isActive(6, sHeight)
}

func IsDexMiningUpgrade(sHeight uint64) bool {
	assertUpgradeNotNil()
	return upgrade.isActive(7, sHeight)
}

func IsDexRobotUpgrade(sHeight uint64) bool {
	assertUpgradeNotNil()
	return upgrade.isActive(8, sHeight)
}

func IsDexStableMarketUpgrade(sHeight uint64) bool {
	assertUpgradeNotNil()
	return upgrade.isActive(9, sHeight)
}

func IsVersion10Upgrade(sHeight uint64) bool {
	assertUpgradeNotNil()
	return upgrade.isActive(10, sHeight)
}

func IsVersion11Upgrade(sHeight uint64) bool {
	assertUpgradeNotNil()
	return upgrade.isActive(11, sHeight)
}

func IsVersion12Upgrade(sHeight uint64) bool {
	assertUpgradeNotNil()
	return upgrade.isActive(12, sHeight)
}

func IsVersion13Upgrade(sHeight uint64) bool {
	assertUpgradeNotNil()
	return upgrade.isActive(13, sHeight)
}

func IsVersionXUpgrade(sHeight uint64) bool {
	assertUpgradeNotNil()
	return upgrade.isActive(14, sHeight)
}
