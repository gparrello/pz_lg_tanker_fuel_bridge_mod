# LG Tanker Fuel Bridge

An optional automation add-on for Project Zomboid Build 42.20. It connects fuel from these supported tankers to a stationary barrel in **LG Extended Plumbing's** building supply, which **LG Extended Electricity** can then use to refuel a generator:

- **rSemiTruck W900 cistern:** the gasoline tank part `2000TankG` must be installed (not the water tank).
- **82 Oshkosh M967 tanker trailer:** the `1000FuelTank` must be installed.
- **ISO Containers M3 tanker trailer:** its `GasTank` must be installed.

## In-game setup

1. **Set up a supported tanker.** Install its gasoline tank part and park the tanker near the base. It must remain stationary; the bridge checks its position over consecutive server intervals.
2. **Prepare a stationary collector barrel.** Empty it, then use a pipe wrench and select **Plumb into house supply** on the collector. The bridge only offers auto-refill for a collector already included in LG Extended Plumbing's supply. The barrel must be empty or contain petrol only; other liquids are never replaced.
3. **Enable auto-refill.** Right-click the barrel and choose **Enable cistern auto-refill**. The option changes to **Disable cistern auto-refill** when it is active.
4. **Plumb the generator into the building.** Right-click the generator and select **Plumb generator** from LG Extended Electricity. The generator must also be plugged in and usable.
5. Keep the tanker within **5 tiles of the barrel** on the same level. The server transfers up to **10 L of petrol every 10 in-game minutes**. After the tanker is first loaded or observed, it may take up to two 10-minute checks to confirm it is parked and begin transferring. The generator can then draw petrol from the building supply.

The rSemiTruck mod also has a manual alternative: right-click its W900 cistern and choose **Drain Cistern** to transfer fuel into a nearby placed fluid container.

## Notes and troubleshooting

- The tanker must be loaded in the world, parked, have fuel in its supported tank, and be within range. Auto-refill does not run while the tanker/barrel's chunks are unloaded.
- The barrel must be an LG Extended Plumbing collector, be plumbed into the building, and be empty or petrol-only. Empty water from it before enabling the bridge.
- If **Enable cistern auto-refill** is missing, check that the barrel is in the LG Extended Plumbing supply and accepts petrol, and that all required mods are enabled.
- Transfer is server-authoritative in multiplayer. It only moves fuel that is actually in the tanker and stops when the tanker is empty or the barrel is full.
- Ordinary cars' and boats' engine tanks are deliberately not supported as tanker sources.

Required mods: `rSemiTruck`, `LGExtendedPlumbing`, and `LGExtendedElectricity`. `82oshkoshM911` and `isoContainers` are optional; their supported tanker trailers are recognized when those mods are installed and enabled.

The transfer range and rate are set in `42.20/media/lua/shared/LGTankerFuelBridge/Bridge.lua` (`RANGE` and `RATE_LITRES_PER_TEN_MINUTES`).
