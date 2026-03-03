import SwiftUI

// MARK: - Overview
//
// Table uses a two-pass layout system. The first pass renders cells which emit their bounds via
// preferences. The second pass collects all cell bounds, transforms them from anchor coordinates
// to geometry coordinates, and creates a TableLayout that styles can use for rendering borders
// and backgrounds with precise cell positions.
//
// 横向滚动实现说明：
//
// 1. Grid 上加 fixedSize(horizontal: true, vertical: false)
//    → 让 Grid 按各列自然宽度布局，不被外层 AnyView 压缩为屏幕宽，
//      文字不换行，backgroundPreferenceValue 能量到真实宽度（如 741.7pt）。
//
// 2. backgroundPreferenceValue + GeometryReader 量到真实宽度后写入 @State tableLayout，
//    触发第二次渲染，此时 tableLayout.bounds.width = 741.7pt。
//
// 3. ScrollView content 加 .frame(minWidth: tableLayout.bounds.width)
//    → 显式告知 ScrollView 内容宽度（AnyView 不传播 fixedSize ideal-size）。
//
// 4. ScrollView 背景上报 OverflowFrameKey（仿照 Overflow view）
//    → UITextInteractionView 将此区域列为排除区，水平滑动手势不再被文本选择层拦截。

extension StructuredText {
  struct Table: View {
    @Environment(\.tableStyle) private var tableStyle

    @State private var spacing = TableCell.Spacing()
    @State private var tableLayout = TableLayout()

    private let intent: PresentationIntent.IntentType?
    private let content: AttributedSubstring
    private let columns: [PresentationIntent.TableColumn]

    init(
      intent: PresentationIntent.IntentType?,
      content: AttributedSubstring,
      columns: [PresentationIntent.TableColumn]
    ) {
      self.intent = intent
      self.content = content
      self.columns = columns
    }

    var body: some View {
      // tableLayout.bounds.width > 0 说明已经完成第一次量测，可以用作 minWidth
      let measuredWidth = tableLayout.bounds.width > 0 ? tableLayout.bounds.width : nil

      let configuration = TableStyleConfiguration(
        label: .init(label),
        indentationLevel: indentationLevel,
        layout: tableLayout
      )
      let resolvedStyle = tableStyle.resolve(configuration: configuration)
        .onPreferenceChange(TableCell.SpacingKey.self) { @MainActor in
          spacing = $0
        }

      ScrollView(.horizontal, showsIndicators: false) {
        AnyView(resolvedStyle)
          // minWidth 是关键：AnyView 不会将内层 Grid 的 fixedSize ideal-size 上报给 ScrollView，
          // 所以 ScrollView 默认以屏幕宽为 content size，无法滚动。
          // 用已量到的 tableLayout.bounds.width 显式设置 minWidth，
          // 让 ScrollView 知道真实内容宽度。
          .frame(minWidth: measuredWidth, alignment: .leading)
          // 清空外层 overflowFrames，避免外层排除区（StructuredText 坐标系）
          // 被内层 UITextInteractionView 用错坐标系做触控排除。
          .environment(\.overflowFrames, [])
          // 为滚动区域内的文字启用本地文本选择（与 Overflow 保持一致）
          .modifier(TextSelectionInteraction())
          // 清除外层文本选择的布局信息，避免与内层文本选择冲突
          .transformPreference(Text.LayoutKey.self) { $0 = [] }
      }
      // 上报滚动区域 frame 为文本选择排除区，与 Overflow 保持一致。
      // UITextInteractionView.point(inside:with:) 会对此区域返回 false，
      // 使水平滑动手势能被内层 ScrollView 捕获，而不被文本选择覆盖层拦截。
      .background(
        GeometryReader { geometry in
          Color.clear
            .preference(
              key: OverflowFrameKey.self,
              value: [geometry.frame(in: .textContainer)]
            )
        }
      )
    }

    @ViewBuilder
    private var label: some View {
      let rowRuns = content.blockRuns(parent: intent)

      Grid(horizontalSpacing: spacing.horizontal, verticalSpacing: spacing.vertical) {
        ForEach(rowRuns.indices, id: \.self) { rowIndex in
          let rowRun = rowRuns[rowIndex]
          let rowContent = content[rowRun.range]
          let columnRuns = rowContent.blockRuns(parent: rowRun.intent)

          GridRow {
            let cellsByColumn: [Int: AttributedSubstring] = {
              var result: [Int: AttributedSubstring] = [:]
              for cellRun in columnRuns {
                if case .tableCell(let colIdx) = cellRun.intent?.kind {
                  result[colIdx] = rowContent[cellRun.range]
                }
              }
              return result
            }()

            ForEach(0..<columns.count, id: \.self) { columnIndex in
              if let cellContent = cellsByColumn[columnIndex] {
                TableCell(cellContent, row: rowIndex, column: columnIndex)
                  .gridColumnAlignment(alignment(for: columnIndex))
              } else {
                Color.clear
                  .anchorPreference(key: TableCell.BoundsKey.self, value: .bounds) { anchor in
                    [TableCell.Identifier(row: rowIndex, column: columnIndex): anchor]
                  }
                  .gridColumnAlignment(alignment(for: columnIndex))
              }
            }
          }
        }
      }
      // fixedSize 让 Grid 按各列内容自然宽度渲染，不被外层 AnyView 压缩为屏幕宽。
      // 这确保第一次渲染时 backgroundPreferenceValue 能量到真实宽度。
      .fixedSize(horizontal: true, vertical: false)
      .backgroundPreferenceValue(TableCell.BoundsKey.self) { values in
        GeometryReader { geometry in
          Color.clear
            .onChange(of: values, initial: true) { _, newValue in
              let layout = TableLayout(newValue.mapValues { geometry[$0] })

              // 用 1pt 精度做容差比较，避免 Anchor<CGRect> 每帧创建新对象导致
              // CGFloat 有极微小浮点差异，造成无限渲染循环
              let sameSize = Int(layout.bounds.width) == Int(tableLayout.bounds.width)
                && Int(layout.bounds.height) == Int(tableLayout.bounds.height)
                && layout.numberOfColumns == tableLayout.numberOfColumns
                && layout.numberOfRows == tableLayout.numberOfRows
              guard !sameSize else { return }

              tableLayout = layout
            }
        }
      }
    }

    private var indentationLevel: Int {
      content.runs.first?.presentationIntent?.indentationLevel ?? 0
    }

    private func alignment(for columnIndex: Int) -> HorizontalAlignment {
      guard columnIndex < columns.count else {
        return .leading
      }

      switch columns[columnIndex].alignment {
      case .left:
        return .leading
      case .center:
        return .center
      case .right:
        return .trailing
      @unknown default:
        return .leading
      }
    }
  }
}
