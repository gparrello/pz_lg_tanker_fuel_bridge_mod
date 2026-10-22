# LG Tanker Fuel Bridge

An optional automation add-on for the installed **rSemiTruck**, **LG Extended Plumbing**, and **LG Extended Electricity** mods (Project Zomboid Build 42.20).

The rSemiTruck mod already lets you manually drain its W900 cistern into a nearby placed fluid container (right-click the cistern and choose **Drain Cistern**). This add-on adds an opt-in automatic top-up for a stationary barrel already included in LG Extended Plumbing's building supply:

1. Install the cistern's gasoline tank (`2000TankG`) and park the W900 cistern beside the base.
2. Empty a stationary rain collector/barrel, then add it to the LG Extended Plumbing supply with the pipe wrench.
3. Right-click the barrel and choose **Enable cistern auto-refill**. The barrel must be empty or already contain only petrol; other liquids are never overwritten.
4. After confirming the cistern is parked, the server transfers up to 10 L of petrol into the barrel every 10 in-game minutes while the tanker and barrel are within 5 tiles and loaded. Generators plumbed into the building can then draw that petrol through LG Extended Electricity.

The feature is server-authoritative in multiplayer. It only transfers petrol the cistern actually contains, never overwrites a barrel's other liquids, and stops when either tank is empty/full. Disable it from the same barrel context menu. It does not run across unloaded chunks.

Dependencies: `rSemiTruck`, `LGExtendedPlumbing`, `LGExtendedElectricity`.

The transfer interval and amount are currently set in `42.20/media/lua/shared/LGTankerFuelBridge/Bridge.lua` (`RATE_LITRES_PER_TEN_MINUTES`).
