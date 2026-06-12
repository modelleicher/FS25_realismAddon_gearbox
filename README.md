# FS25_realismAddon_gearbox

RealismAddon Gearbox for FS25 - converted and updated - fixing everything around transmissions Giants didn't get right.

We are back in FS25! Unfortunately Giants did not fix any of the issues regarding manual transmissions and the clutch so this Mod is still needed for anybody and everybody that plays with manual or manual & clutch Setting in FS25. Especially if you play with an actual Shifter and Pedals.

The goal with this mod is to fix all the large and little problems realism players have with the default Farm Sim transmissions. This is again a BETA Version as of right now - I have been playing with it for about 2-3 weeks now this being one of the first things I converted.
I also added and updated and fixed a few things compared to FS22, otherwise it mainly works the same as in FS22. I have a list of Changes between FS22 and FS25 below.
The goal this time is to actually get this Mod out if Beta which I never did in FS22 simply not because it wasn't working properly but because I always had Ideas and Stuff I wanted to add or improve but never got around to it.
So for now the features are final I think - at least for a first final version. All I need to do is fix eventual bugs.

# Credits

- Modelleicher
- bases on Giants stuff
- AckermannM (secondGroup Lever animations, Github Release Build)

# How do Download and Use

Download FS25_realismAddon_gearbox.zip from the releases section and put it into your mods folder.


# Feature List FS25

- removes all unnatural/automatic braking, only adding back Engine Braking depending on gearRatio
- add constant rpm regulation (vehicle will drive at idle and not only if the gas pedal is pressed)
- linear gas pedal (50% throttle pedal means 50% rpm not 80-90% like with Giants Default where the pedal is a acceleration pedal not throttle pedal)
- real physical rpm everywhere (means wheels, sound, visual(Hud), engine rpm are all synchronized and the same - default Giants is that the sound/visual rpm is completely seperate from the actual physics calculation)
- added proper clutch calculation which allows clutch slipping and proper clutch feel
- added hand throttle (it doesn't automatically raise RPM when PTO is turned on anymore)
- removed artifical rpm drop each time gas is liftet and hit again (Giants artifically lowered sound/visual rpm by about 200rpm each time you get off and on the gas even if its just a second)
- remove automatic full brake when clutching in reverse bug
- added support for axis shifting for FPS transmissions
- added handbrake
- added support for second Group-Set so the usual Gears, Groups and second Group can be simulated. (for example Gears, R, L, H Group and L / H Powershift) Inputs need to be configured, nothing set by default
- added optional Inputs for group5 to group8 since Giants default only allows 1-4


# Changelog in FS25

###### V 0.9.3.3
only backup of current state, not working, no release creation, DO NOT USE 
- bugfixing/improving on GUI/Settings but no result

###### V 0.9.3.2
- hotfix removed debug print

###### V 0.9.3.1
- fixed Vehicle Debug Torque Curve being displayed wrongly (moved to another function to overwrite for clutch torque)
- fixed infinite torque bug right at 10% clutch engagement
- changed clutch closed range (deadzone) from 5% to 10%

###### V 0.9.3.0
- major overhaul, addition of multiple seperate specializations specific to each task separated from realismAddon_gearbox_spec
- added keyboard clutch feature, vehicle will open clutch when pressing the brake, close when accelerating again. (Select Shiftmode MANUAL)
- added automatic clutch closing slowly depending on rpm when keyboard clutch is active (Select Shiftmode MANUAL)
- added 1. Gen Fendt Vario CVT simulation including realistic Joystick Simulation
- started on a GUI, not yet implemented/in use 
--------------------------------------------------
- when playing on Keyboard, you MUST select Shiftmode MANUAL and NOT MANUAL WITH CLUTCH!! Clutch using a Button won't work in MANUAL WITH CLUTCH anymore!!
--------------------------------------------------

###### V 0.9.2.1
- hotfix removed fluidClutch debug print
- hotfix manual cvt error attempt to index nil with 'cvtPercent'

###### V 0.9.2.0
- addition of fluidClutch (Fendt Turbomatik for example) - see examples.xml
- fixed division by zero error in combination with FS25_gearboxExtension

###### V 0.9.1.0
- new clutch using torque limiting instead of gear ratios for clutch effect (BETA)
- added manual cvt control feature for old combines in combination with gears
- added examples.xml for examples on how to add cvt or secondGroup 

###### V 0.9.0.6
- added MB Trac 700-900 and Highland Fishing Fastrac 2000 Configs (also fixed steering angle for Fastrac 2000)
- MoreRealistic Mod compatible

###### V 0.9.0.5
- fixed automatic transmissions not working
- added automatic clutch opening when stopped on automatic transmissions so they can be used without clutch still 
- added optional Inputs for group5 to group8 since Giants default only allows 1-4

###### V 0.9.0.4

- added animations of secondGroup Levers
- added possibility for modders to add `motorized > gearLevers > gearLever(n) > state(n) #secondGroup` property to trigger animations based on selected second group
- adjusted xml overrides to add secondGroup animations to John Deere 3650

###### V 0.9.0.3

- added "P" for parking brake to gear hud instead of additional P to simplify hud

###### V 0.9.0.2

- Fixed FPS Axis not working

###### V 0.9.0.1

- Fixed wrong modDesc descVersion

###### V 0.9.0.0

- Initial Github Release: For a full Feature list look at the Feature List above

###### V 0.9.0.0

- Initial Github Release: For a full Feature list look at the Feature List above


# Changes between FS22 and FS25 conversion

- added parkbrake/handbrake function. Since at the time of converting there were no other mods with this feature it was neccessary to add it.
  As EnhancedVehicle is now released the EV parking brake should work again and the REA-GB parking brake disable itself. If you don't use EV you have to set the Key Binds for the REA GB Parking Brake
- added XML Support to change basegame Vehicle Gearbox Settings (currently inclueded are John Deere 3650, Zetor Proxima 120HD, Zetor Forterra HSX140 and Zetor Crystal, more will be added later)
- fixed MP synchronization where Gears shifted with a Gear Lever were only synchronized up to Gear 7 making all Vehicles with H/L Gears in one impossible to play


# Changelog in FS22

###### V 0.5.3.0

- fixed clutch animation not working

###### V 0.5.2.9

- analog handthrottle axis multiplayer synch fixed

###### V 0.5.2.8

- removed debug print calculation clutch ratio
- fixed hand throttle not working

###### V 0.5.2.7

- fixed Error when in Manual with Auto Clutch and CVT vehicle :: realismAddon_gearbox_overrides.lua:104: attempt to index field 'currentGears' (a nil value)

###### V 0.5.2.6

- addition of second group set
- fixed compatability with automatic gears like in the default Valtra

###### V 0.5.1.0

-- currentGearRatio set to 0 if in neutral, remove jerking when clutch is released in neutral
-- added smoothing of acceleration value to stabilize rpm and load and lastAcceleratorPedal (not good.. better.. maybe? Now acc pedal reaction is slow)

###### V 0.5.0.0

- Initial Github Release for FS22, 19th or April 2022

# Features (FS22)

###### Features Update 0.5.2.6

- addition of second group set (see examples.xml on how to implement it)

###### Features of the initial release

- displayed and sound-rpm is as close to the actual/physical rpm as possible, no fake rpm drop and lagging behind anymore
- clutch and engine rpm is matched if clutch is released
- new clutch calculation that allows the clutch to actually slip, clutch feel of RMT is back
- new rpm calculation, 50% throttle means 50% rpm as long as the engine has the power for it (linear throttle pedal)
- idle rpm is kept even if vehicle is under load or clutch is released (no need to hit the throttle in order for the vehicle to start moving anymore)
- if in neutral or clutch pressed engine can archieve load when accelerating (hitting the throttle while down/upshifting for nice sound like IRL)
- hand throttle added thats physically identical to throttle pedal so it works like it should (buttons for up/down and alternative axis input)
- implements don't raise RPM automatically, you have to set whatever rpm you want to work at manually with the hand throttle
- gear-shift-axis for FPS transmissions added (to use an axis for shifting through the gears on old FPS transmissions)

All of that should be familier with people who player RMT in FS19 as it is pretty much the same :)
