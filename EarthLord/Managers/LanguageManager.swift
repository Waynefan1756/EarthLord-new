//
//  LanguageManager.swift
//  EarthLord
//
//  Created by Wayne Fan on 2026/1/3.
//

import SwiftUI
import Combine

/// App 支持的语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case system = "system"
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    /// 显示名称（使用对应语言显示）
    var displayName: String {
        switch self {
        case .system:
            // 根据当前系统语言决定显示文本
            let systemLang = Locale.preferredLanguages.first ?? "en"
            return systemLang.hasPrefix("zh") ? "跟随系统" : "Follow System"
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    /// 本地化标识符
    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil // 使用系统语言
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

/// 语言管理器
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    /// 当前选择的语言
    @Published var currentLanguage: AppLanguage = .system

    /// 当前实际使用的语言代码
    @Published var currentLanguageCode: String = ""

    private let languageKey = "app_language"
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        }

        // 延迟初始化语言设置，避免启动时的竞态条件
        DispatchQueue.main.async { [weak self] in
            self?.updateAppLanguage()
        }

        // 监听语言变化
        $currentLanguage
            .dropFirst() // 跳过初始值
            .sink { [weak self] _ in
                self?.saveLanguage()
                self?.updateAppLanguage()
            }
            .store(in: &cancellables)
    }

    /// 保存语言设置到 UserDefaults
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
    }

    /// 更新 App 语言
    private func updateAppLanguage() {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateAppLanguage()
            }
            return
        }

        let languageCode: String

        if let localeIdentifier = currentLanguage.localeIdentifier {
            languageCode = localeIdentifier
        } else {
            // 跟随系统，获取系统首选语言
            languageCode = Locale.preferredLanguages.first ?? "en"
        }

        currentLanguageCode = languageCode

        // 设置 Bundle 的本地化语言
        Bundle.setLanguage(languageCode)

        // 设置 UserDefaults 的 AppleLanguages
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        print("🌐 语言已切换至: \(currentLanguage.displayName) (\(languageCode))")

        // 触发视图更新
        objectWillChange.send()
    }

    /// 获取当前语言的实际显示文本
    var currentLanguageDisplayText: String {
        switch currentLanguage {
        case .system:
            // 获取系统当前语言
            let systemLang = Locale.preferredLanguages.first ?? "en"
            let followSystem = currentLanguageCode.hasPrefix("zh") ? "跟随系统" : "Follow System"
            if systemLang.hasPrefix("zh") {
                return followSystem + " (简体中文)"
            } else {
                return followSystem + " (English)"
            }
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }
}

/// 扩展 Bundle 以支持动态语言切换
extension Bundle {
    private static var bundleKey: UInt8 = 0
    private static var hasSwizzled = false

    /// 获取本地化 Bundle
    static var localizedBundle: Bundle? {
        objc_getAssociatedObject(Bundle.main, &bundleKey) as? Bundle
    }

    /// 设置本地化 Bundle
    static func setLanguage(_ languageCode: String) {
        // 只在第一次调用时进行 swizzling
        if !hasSwizzled {
            object_setClass(Bundle.main, PrivateBundle.self)
            hasSwizzled = true
        }

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            objc_setAssociatedObject(Bundle.main, &bundleKey, bundle, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else {
            // 如果找不到对应语言包，移除关联对象
            objc_setAssociatedObject(Bundle.main, &bundleKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private class PrivateBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        // 如果有自定义的语言 Bundle，使用它
        if let bundle = Bundle.localizedBundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        // 否则使用父类的实现（避免无限递归）
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

/// String 扩展，提供便捷的本地化方法
extension String {
    /// 本地化字符串
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    /// 带参数的本地化字符串
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}
