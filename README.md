# LG Tanker Fuel Bridge

An optional automation add-on for Project Zomboid Build 42.20. It transfers petrol between supported tanker mods and stationary barrels in **LG Extended Plumbing's** building supply, which **LG Extended Electricity** can use to refuel a generator:

- **rSemiTruck W900 cistern:** the gasoline tank part `2000TankG` must be installed (not the water tank).
- **82 Oshkosh M967 tanker trailer:** the `1000FuelTank` must be installed.
- **ISO Containers M3 tanker trailer:** its `GasTank` must be installed.

## In-game setup

1. **Set up a supported tanker.** Install its gasoline tank part and park the tanker near the base. It must remain stationary; the bridge checks its position over consecutive server intervals.
2. **Prepare a stationary collector barrel.** Use a pipe wrench and select **Plumb into house supply** on the collector. The bridge only offers transfer modes for a collector already included in LG Extended Plumbing's supply. It must be empty or contain petrol only; other liquids are never replaced.
3. **Choose a transfer mode.** Right-click the barrel and open its fluid-container submenu:
   - Use **Fuel direction** to choose tanker → barrel or barrel → tanker.
   - Use **Enable fuel transfer** / **Disable fuel transfer** to start or pause the selected direction. Direction and on/off are independent controls.
   - Tanker → barrel requires an empty or petrol-only barrel. Barrel → tanker requires petrol in the barrel and free capacity in the tanker.
4. **Plumb the generator into the building.** Right-click the generator and select **Plumb generator** from LG Extended Electricity. The generator must also be plugged in and usable.
5. Keep the tanker within the configured range of the barrel on the same level. **Barrel/tanker transfer range** is adjustable from **1 to 20 tiles** (default: 5), and **Fuel transferred per 10 minutes** from **1 to 1,000 L** (default: 10). Both settings are under **Sandbox Options → LG Tanker Fuel Bridge**. After the tanker is first loaded or observed, it may take up to two 10-minute checks to confirm it is parked and begin transferring. The generator can then draw petrol from the building supply.

The rSemiTruck mod also has a manual alternative: right-click its W900 cistern and choose **Drain Cistern** to transfer fuel into a nearby placed fluid container.

### Emptying a barrel to move it

1. Put a supported tanker within range with free capacity in its gasoline tank.
2. Right-click the petrol barrel, open its fluid-container submenu, set **Fuel direction** to **barrel to tanker**, and choose **Enable fuel transfer**.
3. Leave the tanker parked until the barrel is empty. The bridge automatically turns transfer off when empty.
4. Disable/disconnect the barrel from the house supply with the pipe wrench, then pick it up and move it.

## Notes and troubleshooting

- The tanker must be loaded in the world, parked, and within range. Refilling requires fuel in the tanker; draining into it requires free tank capacity. Neither direction runs while the tanker/barrel's chunks are unloaded.
- The barrel must be an LG Extended Plumbing collector, be plumbed into the building, and be empty or petrol-only. Empty water from it before enabling the bridge.
- If the **Fuel direction** or **Enable fuel transfer** option is missing, check that the barrel is in the LG Extended Plumbing supply and contains only petrol (or is empty for tanker-to-barrel), and that the required mods are enabled.
- For troubleshooting, enable **Log fuel-transfer checks** in the same Sandbox Options page. After a few in-game minutes, look in `console.txt` for `[LGTankerFuelBridge]` lines. The summary shows whether the tanker, tank, and barrel are being detected and how much fuel moved.
- Transfer is server-authoritative in multiplayer and conserves fuel: only petrol actually removed from one container is credited to the other. Refill stops when the tanker is empty or the barrel is full; draining stops when the barrel is empty or the tanker is full.
- Ordinary cars' and boats' engine tanks are deliberately not supported as tanker sources.

Required mods: `LGExtendedPlumbing` and `LGExtendedElectricity`. The tanker mods (`rSemiTruck`, `82oshkoshM911`, and `isoContainers`) are optional; their supported tanker trailers are recognized when those mods are installed and enabled.

The transfer range and rate are sandbox options: `RefillRange` and `LitresPerTenMinutes`.
