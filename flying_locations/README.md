# flyloc.lua
Small app that keeps a list of slopes and their wind directions, perfect to use with the [F3F Tool](https://github.com/frank-sc).

## Description
Flying Locations — Jeti DC/DS transmitter app\
Should be compatible with all Jeti transmitters on firmware 4.22+\
\
File layout on SD card:\
   Apps/flyloc.lua\
   Apps/flyloc/flyloc.jsn\
\
Version: 1.1\
\
flyloc.jsn can be edited on your computer before uploading to the transmitter. It is in a standard json format.

## Installation

1. Copy `flyloc.lua` to `Apps/` on the transmitter
2. Create the folder `Apps/flyloc/`
3. Copy `flyloc.jsn` to `Apps/flyloc/`
4. On the transmitter go to Applications → User Applications → + to activate

If you have another version of the F3F Tool or have made changes to the file structure you can edit the location on line 24.\
_local F3F_FILE  = "Apps/f3fTool-21/slopeData.jsn"_

## Screenshots

After you add the application under User Applications it appears under Applications.\
\
![Screen1](docs/images/fl1.png)

**Main screen is a list of slopes, that you can add, edit or delete from.**
* F1 - Send slope to F3F Tool *
* F2 - Edit selected slope
* F3 - Add new slope
* F4 - Delete selected slope


![Screen1](docs/images/fl2.png)

Add new slope.\
\
![Screen1](docs/images/fl3.png)

Edit an existing slope.\
\
![Screen1](docs/images/fl4.png)
\
\
*_Please note that for the send to F3F Tool option to work with the current version you need to go to User Applications and reload the Lua apps using the F2 button. Doing that forces the F3F Tool to read the slopeData file as this app can not reload other lua apps. So at the moment you might as well go directly to the Course Setup in the F3F Tool. However I've found a way to make it work with a small addition to the F3F Tool's code and I've sent Frank a pull request to look at the changes and see if he would like to include them in the offical code base._\
\
![Screen1](docs/images/fl5.png)

## Video

![https://youtube.com/shorts/USY6QJld7JA](docs/images/fl5.png)

## Files

### flyloc.lua
Uncompiled code, human readable can be run on the transmitter but takes more memory space.

### flyloc.lc
Compiled code, takes less space in the transmitters memory.

## Project support
If you found this helpful and would like to donate to my coffee fund, you can do so here [https://paypal.me/sverrirgu](https://paypal.me/sverrirgu).
