
scales: {"build_scale":2.5,"production":{"build":5.0,"wait":5.0,"work":5.0},"travel_scale":1.3,"work_scale":6.25}
work_scale() 31.2500  wait_scale() 5.0000  build_scale() 12.5000  momo x1.00

| building | variety / recipe | stage | data s | player s | Momo s | data wait | wait s | wait floor s |
|---|---|---|---|---|---|---|---|---|
| farm | base | sow | 1.0 | 31.2 | 31.2 | 0.0 | 0.0 | - |
| farm | base | water | 1.0 | 31.2 | 31.2 | 2.0 | 10.0 | 2.5 |
| farm | base | harvest | 1.0 | 31.2 | 31.2 | 0.0 | 0.0 | - |
| farm | hardy | sow | 1.0 | 31.2 | 31.2 | 0.0 | 0.0 | - |
| farm | hardy | water | 1.0 | 31.2 | 31.2 | 2.0 | 10.0 | 2.5 |
| farm | hardy | harvest | 1.0 | 31.2 | 31.2 | 0.0 | 0.0 | - |
| farm | millet | sow | 1.0 | 31.2 | 31.2 | 6.0 | 30.0 | 10.0 |
| farm | millet | harvest | 1.0 | 31.2 | 31.2 | 0.0 | 0.0 | - |
| research | - | study | 3.0 | 93.8 | 93.8 | 6.0 | 30.0 | 15.0 |
| lumberyard | - | chop | 4.0 | 125.0 | 125.0 | 0.0 | 0.0 | - |
| lumberyard | - | replant | 2.0 | 62.5 | 62.5 | 10.0 | 50.0 | 20.0 |
| mine | - | dig | 4.0 | 125.0 | 125.0 | 6.0 | 30.0 | 10.0 |
| smelter | copper_ingot | smelt | 10.0 | 312.5 | 312.5 | 5.0 | 25.0 | 10.0 |
| smelter | iron_ingot | smelt | 14.0 | 437.5 | 437.5 | 6.0 | 30.0 | 10.0 |
| smelter | gold_ingot | smelt | 12.0 | 375.0 | 375.0 | 6.0 | 30.0 | 10.0 |
| steam_engine | - | stoke | 3.0 | 93.8 | 93.8 | 27.0 | 135.0 | - |
| game_studio | - | design | 20.0 | 625.0 | 625.0 | 0.0 | 0.0 | - |
| game_studio | - | develop | 40.0 | 1250.0 | 1250.0 | 0.0 | 0.0 | - |
| game_studio | - | release | 10.0 | 312.5 | 312.5 | 30.0 | 150.0 | - |
| car_factory | - | assemble | 30.0 | 937.5 | 937.5 | 10.0 | 50.0 | - |

| construction | data s | built in s |
|---|---|---|
| farm | 3.0 | 37.5 |
| research | 5.0 | 62.5 |
| lumberyard | 5.0 | 62.5 |
| mine | 8.0 | 100.0 |
| smelter | 20.0 | 250.0 |
| solar_panel | 12.0 | 150.0 |
| wind_turbine | 15.0 | 187.5 |
| steam_engine | 15.0 | 187.5 |
| water_wheel | 15.0 | 187.5 |
| office | 20.0 | 250.0 |
| villa | 12.0 | 150.0 |
| apartment | 25.0 | 312.5 |
| park | 8.0 | 100.0 |
| pub | 15.0 | 187.5 |
| community_center | 25.0 | 312.5 |
| game_studio | 30.0 | 375.0 |
| car_factory | 40.0 | 500.0 |
| clock_tower | 30.0 | 375.0 |
| school | 25.0 | 312.5 |
| momo_monument | 40.0 | 500.0 |

| scenario | seconds |
|---|---|
| farm cycle by a new Momo (work 93.8 + wait 10.0) | 103.8 |
| farm cycle by hand (work 93.8 + wait 10.0) | 103.8 |
| farm water, no research | 31.25 |
| farm: the wait after watering (crop ripens), no research | 10.00 |
| mine dig, no research | 125.00 |
| farm water, Watering Can Lv1 | 18.75 |
| mine dig, Pickaxes Lv1 | 93.75 |
| farm: the wait after watering, Drip Irrigation (x0.8 of the wait) | 8.00 |
| mine dig, Pickaxes Lv1 + a master Momo (x0.72) | 67.50 |
| farm water, Watering Can Lv1 + the Clock Tower burst (on) | 15.62 |

| research topic (not building production) | seconds |
|---|---|
| watering_can | 135 |
| drip_irrigation | 270 |
| pickaxes | 90 |
