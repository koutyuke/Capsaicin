import Foundation

/// 要求と応答を JSON にする。読むときにバージョンと値の範囲を確かめる。
public enum IPCCoding {
    public enum DecodingFailure: Error, Hashable {
        /// バージョンが違う。値はメッセージのバージョン。
        case unsupportedVersion(Int)
        /// JSON として読めないか、値が範囲外。
        case malformed
    }

    private struct VersionProbe: Decodable {
        var version: Int
    }

    public static func encode(_ value: some Encodable) throws -> Data {
        try JSONEncoder().encode(value)
    }

    public static func decodeRequest(_ data: Data) throws(DecodingFailure) -> IPCRequest {
        try decode(IPCRequest.self, from: data)
    }

    public static func decodeResponse(_ data: Data) throws(DecodingFailure) -> IPCResponse {
        try decode(IPCResponse.self, from: data)
    }

    /// バージョンを先に確かめ、違えば中身を読まない。
    private static func decode<T: Decodable>(_: T.Type, from data: Data) throws(DecodingFailure) -> T {
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(VersionProbe.self, from: data) else { throw .malformed }
        guard probe.version == IPCProtocol.version else { throw .unsupportedVersion(probe.version) }
        guard let value = try? decoder.decode(T.self, from: data) else { throw .malformed }
        return value
    }
}
