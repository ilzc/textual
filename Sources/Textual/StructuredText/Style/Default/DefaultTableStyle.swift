import SwiftUI

extension StructuredText {
  /// The default table style used by ``StructuredText/DefaultStyle``.
  public struct DefaultTableStyle: TableStyle {
    private static let borderWidth: CGFloat = 1

    /// Creates the default table style.
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
      // fixedSize(horizontal:) 确保 AnyView 向后续修饰器正确报告内容宽度，
      // 而不是报告被压缩后的屏幕宽，避免 overlay Canvas 按错误宽度绘制分隔线。
      configuration.label
        .fixedSize(horizontal: true, vertical: false)
        .overlay {
          Canvas { context, _ in
            for divider in configuration.layout.dividers() {
              context.fill(
                Path(divider),
                with: .style(DynamicColor.grayTertiary)
              )
            }
          }
        }
        .textual.tableCellSpacing(horizontal: Self.borderWidth, vertical: Self.borderWidth)
        .textual.blockSpacing(.fontScaled(top: 1.6, bottom: 1.6))
        .padding(Self.borderWidth)
    }
  }
}

extension StructuredText.TableStyle where Self == StructuredText.DefaultTableStyle {
  /// The default table style.
  public static var `default`: Self {
    .init()
  }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
#Preview {
  StructuredText(
    markdown: """
      The sky above the port was the color of television, tuned to a dead channel.

      Sloth speed  | Description
      ------------ | -------------------------------------
      `slow`       | Moves slightly faster than a snail
      `medium`     | Moves at an average speed
      `fast`       | Moves faster than a hare
      `supersonic` | Moves faster than the speed of sound

      It was a bright cold day in April, and the clocks were striking thirteen.
      """
  )
  .padding()
  .textual.textSelection(.enabled)
}
