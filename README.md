# GPX-Namer
This is a simple tool that scratches a simple itch - GPX files that you might get from various sources might have junky file names, even though embedded within the files themselves are much more meaningful names / descriptions.

In the original author's case, this occurred when bulk-downloading all GPX tracks from Strava.  It names them something like `20141220-225528-Walk.gpx`.  Not very helpful.  This GPX Namer tool quickly renames them to e.g. `The local park (19/12/2014).gpx`, and as a bonus sets the creation date of the GPX file to the start time of its recording, so that you can intuitively sort by creation time in the Finder.

## Setup
### Configure Google Maps API key
GPX Namer handles times & dates correctly.  This means it converts them from the UTC times in the GPX file to the actual timezone each GPX track was recorded in, and uses *that* date in the filename.

In order to do this, it relies on the Google Maps Time Zone API to determine the timezone for a given point in time & space (using the first point in the GPX file for reference).

To use this awesome and free Google API, you need to create a free API key and insert it into the code before building it.  Instructions are in the code (and it will fail to compile at the relevant point - you can't miss it).

#### Disclaimer:  The original author of GPX Namer works for Google (though this project is unaffiliated).  Awesomeness may be subject to personal opinion.

### Building
The simplest way is to simply run `swift build` from the command line while inside the GPX Namer folder.

Alternatively, you can run `swift package generate-xcodeproj` to create an Xcode project file, open that in Xcode, then build (debug, etc) as normal.

### Installation
There's no predefined installation routine.  You're free to copy the built binary (found in `.build/debug/GPX Namer` by default, if you built with `swift build`) to wherever you'd like (e.g. `/usr/local/bin`).

## Improvements & Extensions
Please do send pull requests for improvements, fixes, or whatever other changes you make.

You are welcome to file issue reports, whether for bugs or as feature requests, though no promises are made that they'll be addressed.

## Sidenote:  How to download all your tracks from Strava.
1. Log in to [the website](https://www.strava.com/).
2. Click your avatar in the top-right corner, and choose 'Settings'.
3. Click the `Download all your activities` button at the bottom of the right-hand sidebar.
4. Wait a little bit for Strava to send you an email with the download link.
5. Click the link in the email.
6. Profit.
