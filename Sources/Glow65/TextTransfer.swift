import Foundation

/// テキストを、端末から打ったときと同じバイト列にする(貼り付けとテキストファイルの送信で使う)。
///
/// - 改行(LF、CRLF、CR)は CR 1 つにする。モニタ、BASIC、GAME65G は CR で行を終える。
/// - タブは空白にする。そのほかの制御文字は捨てる。
/// - ASCII 以外の文字は `?` にする(端末は 7 ビット ASCII)。
public enum TextTransfer {
    /// `endWithNewline` が true なら、末尾が改行でないときに CR を足す(最後の行も入力されるように)。
    public static func bytes(from text: String, endWithNewline: Bool = false) -> [UInt8] {
        var out: [UInt8] = []
        var previousWasCR = false
        for scalar in text.unicodeScalars {
            let v = scalar.value
            defer { previousWasCR = v == 0x0D }
            switch v {
            case 0x0D:
                out.append(0x0D)
            case 0x0A:
                if !previousWasCR { out.append(0x0D) }
            case 0x09:
                out.append(0x20)
            case 0x20..<0x7F:
                out.append(UInt8(v))
            case 0..<0x20, 0x7F:
                break
            default:
                out.append(UInt8(ascii: "?"))
            }
        }
        if endWithNewline, let last = out.last, last != 0x0D {
            out.append(0x0D)
        }
        return out
    }

    /// テキストファイルを読み、送るバイト列にする(末尾に CR を補う)。
    public static func bytes(contentsOf url: URL) throws -> [UInt8] {
        let data = try Data(contentsOf: url)
        return bytes(from: String(decoding: data, as: UTF8.self), endWithNewline: true)
    }
}
