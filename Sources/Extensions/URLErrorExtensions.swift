// Copyright © 2024 Jonas Frey. All rights reserved.

import Foundation

extension URLError: LocalizedError {
    public var errorDescription: String? {
        return "URLError(code: \(self.code.description), localizedDescription: \(self.localizedDescription), userInfo: \(self.userInfo), " +
        "errorUserInfo: \(self.errorUserInfo), failureURL: \(self.failureURLString ?? "nil"))"
    }
}

extension URLError.Code {
    var description: String {
        switch self {
        case .appTransportSecurityRequiresSecureConnection:
            return "appTransportSecurityRequiresSecureConnection"
        case .backgroundSessionInUseByAnotherProcess:
            return "backgroundSessionInUseByAnotherProcess"
        case .backgroundSessionRequiresSharedContainer:
            return "backgroundSessionRequiresSharedContainer"
        case .backgroundSessionWasDisconnected:
            return "backgroundSessionWasDisconnected"
        case .badServerResponse:
            return "badServerResponse"
        case .badURL:
            return "badURL"
        case .callIsActive:
            return "callIsActive"
        case .cancelled:
            return "cancelled"
        case .cannotCloseFile:
            return "cannotCloseFile"
        case .cannotConnectToHost:
            return "cannotConnectToHost"
        case .cannotCreateFile:
            return "cannotCreateFile"
        case .cannotDecodeContentData:
            return "cannotDecodeContentData"
        case .cannotDecodeRawData:
            return "cannotDecodeRawData"
        case .cannotFindHost:
            return "cannotFindHost"
        case .cannotLoadFromNetwork:
            return "cannotLoadFromNetwork"
        case .cannotMoveFile:
            return "cannotMoveFile"
        case .cannotOpenFile:
            return "cannotOpenFile"
        case .cannotParseResponse:
            return "cannotParseResponse"
        case .cannotRemoveFile:
            return "cannotRemoveFile"
        case .cannotWriteToFile:
            return "cannotWriteToFile"
        case .clientCertificateRejected:
            return "clientCertificateRejected"
        case .clientCertificateRequired:
            return "clientCertificateRequired"
        case .dataLengthExceedsMaximum:
            return "dataLengthExceedsMaximum"
        case .dataNotAllowed:
            return "dataNotAllowed"
        case .dnsLookupFailed:
            return "dnsLookupFailed"
        case .downloadDecodingFailedMidStream:
            return "downloadDecodingFailedMidStream"
        case .downloadDecodingFailedToComplete:
            return "downloadDecodingFailedToComplete"
        case .fileDoesNotExist:
            return "fileDoesNotExist"
        case .fileIsDirectory:
            return "fileIsDirectory"
        case .httpTooManyRedirects:
            return "httpTooManyRedirects"
        case .internationalRoamingOff:
            return "internationalRoamingOff"
        case .networkConnectionLost:
            return "networkConnectionLost"
        case .noPermissionsToReadFile:
            return "noPermissionsToReadFile"
        case .notConnectedToInternet:
            return "notConnectedToInternet"
        case .redirectToNonExistentLocation:
            return "redirectToNonExistentLocation"
        case .requestBodyStreamExhausted:
            return "requestBodyStreamExhausted"
        case .resourceUnavailable:
            return "resourceUnavailable"
        case .secureConnectionFailed:
            return "secureConnectionFailed"
        case .serverCertificateHasBadDate:
            return "serverCertificateHasBadDate"
        case .serverCertificateHasUnknownRoot:
            return "serverCertificateHasUnknownRoot"
        case .serverCertificateNotYetValid:
            return "serverCertificateNotYetValid"
        case .serverCertificateUntrusted:
            return "serverCertificateUntrusted"
        case .timedOut:
            return "timedOut"
        case .unknown:
            return "unknown"
        case .unsupportedURL:
            return "unsupportedURL"
        case .userAuthenticationRequired:
            return "userAuthenticationRequired"
        case .userCancelledAuthentication:
            return "userCancelledAuthentication"
        case .zeroByteResource:
            return "zeroByteResource"
        default:
            return "unknown(\(self.rawValue))"
        }
    }
}
