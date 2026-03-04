import SwiftUI

// MARK: - TextSelectionAction
//
// 文本选择菜单的自定义操作。注入 Textual 环境后，文本选中时弹出的编辑菜单会出现
// 对应标题的自定义选项，点击后以选中文字为参数调用 handler。
//
// Textual 对操作语义无感知，具体行为完全由注入方定义。
//
// 用法示例：
//   StructuredText(markdown: content)
//     .environment(\.textSelectionActions, [
//       TextSelectionAction(title: "图中查找") { selectedText in
//         // 执行自定义逻辑
//       }
//     ])
//
// 说明：
// - 最多支持 3 个自定义操作（受 UIMenuController selector 池限制）
// - 默认值为空数组，不显示任何自定义菜单项

/// 文本选择菜单的自定义操作项。
public struct TextSelectionAction: Sendable {
  public let title: String
  let handler: @MainActor @Sendable (String) -> Void

  public init(title: String, _ handler: @escaping @MainActor @Sendable (String) -> Void) {
    self.title = title
    self.handler = handler
  }

  @MainActor
  public func callAsFunction(_ text: String) {
    handler(text)
  }
}

extension EnvironmentValues {
  /// 文本选择菜单的自定义操作列表（最多 3 项）。
  /// 空数组时不显示任何自定义菜单项（默认值）。
  @Entry public var textSelectionActions: [TextSelectionAction] = []
}
