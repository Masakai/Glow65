import Foundation

/// 画面に出す文言を、アプリの言語(日本語・英語)で返す。キーは英語の文言。
/// 引数には、位置を指定できる書式(`%1$@`、`%2$lld`)を使う。訳は `Localization/*.lproj/Localizable.strings`。
/// 訳がない言語、または `swift run` のように `.lproj` を持たない実行では、キーの英語がそのまま出る。
func loc(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    return args.isEmpty ? format : String(format: format, arguments: args)
}
