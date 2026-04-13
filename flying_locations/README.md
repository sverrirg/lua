# flyloc.lua
Small app that keeps a list of slopes and their wind directions, perfect to use with the [F3F Tool](https://github.com/frank-sc).

## Description
Flying Locations — Jeti DC/DS transmitter app\
Should be compatible with all Jeti transmitters on firmware 4.22+\
Remember to set the starting point on the slope!\
\
File layout on the transmitter:\
   Apps/flyloc.lua\
   Apps/flyloc/flyloc.jsn\
\
Version: 1.2.1\
\
flyloc.jsn can be edited on your computer before uploading to the transmitter. It is in a standard json format.\
Slope names are truncated at 25 characters when displayed in the list to keep the cells from overflowing.\
A compiled .lc version of the app is included if needed but most should be able to run the .lua file.

## Installation

1. Copy `flyloc.lua` to `Apps/` folder on the transmitter
2. Create the folder `Apps/flyloc/`
3. Copy `flyloc.jsn` to `Apps/flyloc/`
4. On the transmitter go to Applications → User Applications → + to activate

If you have another version of the F3F Tool or have made changes to the file structure you can edit the location on line 24.\
_local F3F_FILE  = "Apps/f3fTool-21/slopeData.jsn"_

## Screenshots

After you add the application under User Applications it appears under Applications.\
\
![Screen1](docs/images/fl1.png)

**Main screen is a list of slopes, that you can add, edit or delete from.**\
Click the scroll wheel to send a slope over to the F3F Tool, remember to set your starting point afterwards.
* F1 - Change the sort order, * indicates which sort is active, default is by slope
* F2 - Edit selected slope
* F3 - Add new slope
* F4 - Delete selected slope

![Screen1](docs/images/fl2b.png)

Add new slope.\
\
![Screen1](docs/images/fl3.png)

Edit an existing slope.\
\
![Screen1](docs/images/fl4.png)
\

## Video
<a href="https://youtube.com/shorts/IBiKjQXWeew">
    <img src="docs/images/fl6_ytv.png" alt="Flying Locations and F3F Tool working together" width="400">
  </a>

## Files

### flyloc.lua
Uncompiled code, human readable can be run on the transmitter but takes more memory space.

### flyloc.lc
Compiled code, takes less space in the transmitters memory.

## Project support
If you found this helpful and would like to donate to my coffee fund, you can do so here [https://paypal.me/sverrirgu](https://paypal.me/sverrirgu).
