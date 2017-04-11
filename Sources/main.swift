//
//  main.swift
//  GPX Namer
//
//  Created by Wade Tregaskis on 9/4/17.
//  Copyright © 2017 Wade Tregaskis. All rights reserved.
//

import AEXML
import CommandLineKit
import Dispatch
import Foundation
import XCGLogger


let log = XCGLogger.default
log.setup(level: .debug, showFunctionName: true, showThreadName: true, showLevel: true, showFileNames: false, showLineNumbers: true)


let cli = CommandLineKit(arguments: CommandLine.arguments)

enum ArgumentError: Error {
    case missingTarget(String)
}

let helpFlag = BoolOption(shortFlag: "h", longFlag: "help", helpMessage: "Prints basic usage information.")

cli.addOptions(helpFlag)

do {
    try cli.parse(strict: true)
} catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}

if helpFlag.value {
    cli.printUsage()
    exit(EX_OK)
}

if cli.unparsedArguments.isEmpty {
    cli.printUsage(ArgumentError.missingTarget("At least one GPX file, or folder of GPX files, is required as an argument."))
    exit(EX_USAGE)
}


let RFC3339DateFormatter = DateFormatter()
RFC3339DateFormatter.locale = Locale(identifier: "en_US_POSIX")
RFC3339DateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
RFC3339DateFormatter.timeZone = TimeZone(secondsFromGMT: 0)


func timeZoneForPlaceAndTime(latitude: String, longitude: String, time: Date) -> TimeZone? {
    // TODO: Before you can use this tool, you'll need to create your own Google Maps API key, and insert it into the constant below.
    //
    // You can create the key at https://developers.google.com/maps/documentation/timezone/get-api-key
    //
    // API documentation:  https://developers.google.com/maps/documentation/timezone/intro

    let GoogleMapsAPIKey = <INSERT KEY HERE>

    var result: TimeZone? = nil

    let GoogleTimeZoneAPIURL = "https://maps.googleapis.com/maps/api/timezone/json?key=\(GoogleMapsAPIKey)&location=\(latitude),\(longitude)&timestamp=\(time.timeIntervalSince1970)"
    log.debug("Google TimeZone API URL: \(GoogleTimeZoneAPIURL)")

    if let apiURL = URL(string: GoogleTimeZoneAPIURL) {
        let session = URLSession.shared

        var request = URLRequest(url: apiURL, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        session.dataTask(with: request, completionHandler: { (maybeData, maybeResponse, maybeError) in
            if let error = maybeError {
                log.error("An error occurred while utilising the Google TimeZone API for URL \"\(apiURL)\": \(error)")
            } else {
                if let response = maybeResponse {
                    if let HTTPResponse = response as? HTTPURLResponse {
                        if 200 == HTTPResponse.statusCode {
                            if let data = maybeData {
                                let maybeParsedResponse: Any?

                                do {
                                    maybeParsedResponse = try JSONSerialization.jsonObject(with: data)
                                } catch {
                                    log.error("Unable to parse JSON response from Google TimeZone API for URL \"\(apiURL)\":\n\(response)\nError: \(error)")
                                    maybeParsedResponse = nil
                                }

                                if let parsedResponse = maybeParsedResponse {
                                    if let responseDictionary = parsedResponse as? NSDictionary {
                                        if let status = responseDictionary["status"] as? String {
                                            if .orderedSame == status.caseInsensitiveCompare("OK") {
                                                if let timeZoneID = responseDictionary["timeZoneId"] as? String {
                                                    result = TimeZone(identifier: timeZoneID)

                                                    if nil == result {
                                                        log.error("Unable to interpret timezone ID \"\(timeZoneID)\", as returned from the Google TimeZone API for URL \"\(apiURL)\".  Complete response was:\n\(parsedResponse)")
                                                    }
                                                } else {
                                                    log.error("Unexpected response format from Google TimeZone API for URL \"\(apiURL)\" - expected a 'timeZoneId' to be included, but got only:\n\(parsedResponse)")
                                                }
                                            } else {
                                                log.error("Error (status \"\(status)\") returned from Google TimeZone API for URL \"\(apiURL)\":\n\(parsedResponse)")
                                            }
                                        } else {
                                            log.error("Unexpected response format from Google TimeZone API for URL \"\(apiURL)\" - expected a 'status' to be included, but got only:\n\(parsedResponse)")
                                        }
                                    } else {
                                        log.error("Unexpected response format from Google TimeZone API for URL \"\(apiURL)\" - expected a top level dictionary, but got:\n\(parsedResponse)")
                                    }
                                }
                            } else {
                                log.error("No data returned in response from the Google TimeZone API for URL \"\(apiURL)\".")
                            }
                        } else {
                            log.error("HTTP error \(HTTPResponse.statusCode) returned by the Google TimeZone API for URL \"\(apiURL)\".")
                        }
                    } else {
                        log.error("Unrecognised response type - \"\(response)\" - received via URLSession API while trying to use the Google TimeZone API for URL \"\(apiURL)\".")
                    }
                } else {
                    log.error("No response received from Google TimeZone API for URL \"\(apiURL)\".")
                }
            }

            dispatchGroup.leave()
        }).resume()

        dispatchGroup.wait()
    } else {
        log.error("Unable to create URL for \"\(GoogleTimeZoneAPIURL)\".")
    }

    return result
}


func processFile(_ file: URL) {
    log.debug("Processing: \(file)")

    let fileContents: Data

    do {
        fileContents = try Data(contentsOf: file)
    } catch {
        log.error("Unable to read contents of file \"\(file)\", because: \(error).")
        return
    }

    let document: AEXMLDocument

    do {
        document = try AEXMLDocument(xml: fileContents)
    } catch {
        log.error("Unable to parse contents of presumed GPX file \"\(file)\", because: \(error).")
        return
    }

    // Example:
    //
    // <gpx creator="strava.com iPhone" version="1.1" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
    //   <metadata>
    //     <time>2014-08-23T15:42:12Z</time>
    //   </metadata>
    //   <trk>
    //     <name>Sal's Branch Trail, William B. Umstead State Park, North Carolina</name>
    //     <trkseg>
    //       <trkpt lat="35.8808490" lon="-78.7584300">
    //       …

    let gpx = document.root

    guard nil == gpx.error else {
        log.error("Error fetching root node in purported GPX file \"\(file)\": \(gpx.error).")
        return
    }

    if .orderedSame != gpx.name.caseInsensitiveCompare("gpx") {
        log.warning("Root element in purported GPX file \"\(file)\" is not a \"gpx\" node, but instead \"\(gpx.name)\".")
    }

    let creationTimeAsString = gpx["metadata"]["time"].string

    if !creationTimeAsString.isEmpty {
        if let creationTime = RFC3339DateFormatter.date(from: creationTimeAsString) {
            let recordingName = gpx["trk"]["name"].string

            if !recordingName.isEmpty {
                let firstPoint = gpx["trk"]["trkseg"]["trkpt"]

                if let latitudeAsString = firstPoint.attributes["lat"] {
                    if !latitudeAsString.isEmpty {
                        if let longitudeAsString = firstPoint.attributes["lon"] {
                            if !longitudeAsString.isEmpty {
                                if let timezone = timeZoneForPlaceAndTime(latitude: latitudeAsString, longitude: longitudeAsString, time: creationTime) {

                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateStyle = .short
                                    dateFormatter.timeStyle = .none
                                    dateFormatter.timeZone = timezone

                                    let dateAsString = dateFormatter.string(from: creationTime)

                                    log.debug("Timezone for {\(latitudeAsString), \(longitudeAsString)} at \(creationTime) (corresponding to \"\(recordingName)\" [\"\(file)\"]) is apparently \(timezone), and thus the accurate date is \"\(dateAsString)\".")

                                    let newFileNameSansExtension = "\(recordingName) (\(dateAsString))"

                                    // We can't pre-encoded the forward-slashes, because all the URL & String methods just fucking blindly double-encode them (which is not in itself necessarily bad, but what is stupid is that there is seemingly not a single way around that default behaviour).
                                    //
                                    // However, for local file systems at least, on HFS+, there's a magic & arbitrary remapping of colons to slashes, which we can take advantage of.
                                    //
                                    // This is a historical left-over from when MacOS X (and 'Classic' MacOS before it) used colons as path delimiters, not slashes.
                                    let sanitisedNewFileNameSansExtension = newFileNameSansExtension.replacingOccurrences(of: "/", with: ":")

                                    var uniqueIndex = 1

                                    repeat {
                                        var newFileName = sanitisedNewFileNameSansExtension

                                        if 1 < uniqueIndex {
                                            newFileName.append(" #\(uniqueIndex)")
                                        }

                                        if !file.pathExtension.isEmpty {
                                            newFileName.append(".\(file.pathExtension)")
                                        }

                                        var newURL = file.deletingLastPathComponent().appendingPathComponent(newFileName, isDirectory: false)

                                        if file != newURL {
                                            log.debug("Proposed new file name: \"\(newFileName)\" (in URL form: \(newURL)).")

                                            do {
                                                try FileManager.default.moveItem(at: file, to: newURL)
                                            } catch CocoaError.fileWriteFileExists {
                                                uniqueIndex += 1
                                                continue
                                            } catch {
                                                log.error("Unable to rename \"file\" to \"newURL\", error: \(error).")
                                            }
                                        } else {
                                            log.debug("Leaving \"\(file)\" named as it is.")
                                        }

                                        var newFileAttributes = URLResourceValues()
                                        newFileAttributes.creationDate = creationTime

                                        do {
                                            try newURL.setResourceValues(newFileAttributes)
                                        } catch {
                                            log.error("Unable to set the creation time of \"\(newURL)\" to \(creationTime), error: \(error).")
                                        }

                                        break
                                    } while true
                                } else {
                                    log.error("Unable to determine the timezone for {\(latitudeAsString), \(longitudeAsString)} at \(creationTime).")
                                }
                            } else {
                                log.error("No longitude found in the first point in \"\(file)\":\n\(firstPoint.xml)")
                            }
                        } else {
                            log.error("Unable to find longitude on first point in GPX file \"\(file)\":\n\(firstPoint.xml)")
                        }
                    } else {
                        log.error("No latitude found in the first point in \"\(file)\":\n\(firstPoint.xml)")
                    }
                } else {
                    log.error("Unable to find latitude on first point in GPX file \"\(file)\":\n\(firstPoint.xml)")
                }
            } else {
                log.error("No recording name found in \"\(file)\", with parsed contents of:\n\(document.xml)")
            }
        } else {
            log.error("Unable to parse GPX creation time of \"\(creationTimeAsString)\".")
        }
    } else {
        log.error("No creation time found in \"\(file)\", with parsed contents of:\n\(document.xml)")
    }
}


for target in cli.unparsedArguments {
    let baseURL = URL(fileURLWithPath: target).resolvingSymlinksInPath()
    log.debug("Base URL: \(baseURL)")

    let maybeIsDirectory: Bool?

    do {
        maybeIsDirectory = try baseURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
    } catch {
        log.error("Unable to determine if \"(\(baseURL)\" refers to a folder or not (error \(error)) - assuming it does.")
        maybeIsDirectory = nil
    }

    if nil == maybeIsDirectory || maybeIsDirectory! {
        if let fileEnumerator = FileManager.default.enumerator(at: baseURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles], errorHandler: { (URL, error) -> Bool in
            NSLog("Error enumerating \"\(URL)\" (under \"\(baseURL)\": \(error)")
            return true
        }) {
            for file in fileEnumerator {
                log.debug("\tSub-URL: \(file)")

                if let fileAsURL = file as? URL {
                    processFile(fileAsURL)
                } else {
                    log.error("Don't know what type of object the file path (\"\(file)\") was returned as. 😞")
                }
            }
        } else {
            log.error("Unable to enumerate file(s) \"\(baseURL)\".")
        }
    } else {
        processFile(baseURL)
    }
}
