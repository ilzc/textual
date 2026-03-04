#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import SwiftUI
  import os
  import UniformTypeIdentifiers

  // MARK: - Overview
  //
  // `UITextInteractionView` implements selection and link interaction on iOS-family platforms.
  //
  // The view sits in an overlay above one or more rendered `Text` fragments. It uses
  // `TextSelectionModel` to translate touch locations into URLs and selection ranges, and it
  // respects `exclusionRects` so embedded scrollable regions can continue to handle gestures.
  // Selection UI is provided by `UITextInteraction` configured for non-editable content.

  final class UITextInteractionView: UIView {
    override var canBecomeFirstResponder: Bool {
      true
    }

    var model: TextSelectionModel
    var exclusionRects: [CGRect]
    var openURL: OpenURLAction

    /// 外部注入的自定义菜单项（最多 customActionSelectors.count 个）。
    /// 赋值时自动同步 UIMenuController，标题和可见性均由注入方控制。
    var textSelectionActions: [TextSelectionAction] = [] {
      didSet { updateCustomMenuItems() }
    }

    weak var inputDelegate: (any UITextInputDelegate)?

    let logger = Logger(category: .textInteraction)

    private(set) lazy var _tokenizer = UITextInputStringTokenizer(textInput: self)
    private let selectionInteraction: UITextInteraction

    // 固定 selector 池：最多支持 3 个自定义操作。
    // 之所以使用静态池而非动态 selector，是因为 Objective-C 不支持运行时创建方法。
    private static let customActionSelectors: [Selector] = [
      #selector(customAction0(_:)),
      #selector(customAction1(_:)),
      #selector(customAction2(_:)),
    ]

    init(
      model: TextSelectionModel,
      exclusionRects: [CGRect],
      openURL: OpenURLAction
    ) {
      self.model = model
      self.exclusionRects = exclusionRects
      self.openURL = openURL
      self.selectionInteraction = UITextInteraction(for: .nonEditable)

      super.init(frame: .zero)
      self.backgroundColor = .clear

      setUp()
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
      for exclusionRect in exclusionRects {
        if exclusionRect.contains(point) {
          return false
        }
      }
      return super.point(inside: point, with: event)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
      let hasSelection = !(model.selectedRange?.isCollapsed ?? true)
      switch action {
      case #selector(copy(_:)), #selector(share(_:)):
        return hasSelection
      default:
        // 自定义 action：检查 selector 是否在池中且对应 index 有已注入的操作
        if hasSelection,
           let index = Self.customActionSelectors.firstIndex(of: action),
           index < textSelectionActions.count
        {
          return true
        }
        return false
      }
    }

    override func copy(_ sender: Any?) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      let attributedText = model.attributedText(in: selectedRange)
      let formatter = Formatter(attributedText)

      UIPasteboard.general.setItems(
        [
          [
            UTType.plainText.identifier: formatter.plainText(),
            UTType.html.identifier: formatter.html(),
          ]
        ]
      )
    }

    private func setUp() {
      model.selectionWillChange = { [weak self] in
        guard let self else { return }
        self.inputDelegate?.selectionWillChange(self)
      }
      model.selectionDidChange = { [weak self] in
        guard let self else { return }
        self.inputDelegate?.selectionDidChange(self)
      }

      let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
      addGestureRecognizer(tapGesture)

      selectionInteraction.textInput = self
      selectionInteraction.delegate = self

      for gesture in selectionInteraction.gesturesForFailureRequirements {
        tapGesture.require(toFail: gesture)
      }

      addInteraction(selectionInteraction)
    }

    /// 将当前 textSelectionActions 同步到 UIMenuController。
    /// UIMenuController 在 iOS 16+ 已废弃但仍可用；canPerformAction 控制实际可见性。
    private func updateCustomMenuItems() {
      let items = zip(textSelectionActions, Self.customActionSelectors).map { action, selector in
        UIMenuItem(title: action.title, action: selector)
      }
      UIMenuController.shared.menuItems = items
    }

    // MARK: - 自定义 action 响应（selector 池）

    @objc private func customAction0(_ sender: Any?) { triggerCustomAction(at: 0) }
    @objc private func customAction1(_ sender: Any?) { triggerCustomAction(at: 1) }
    @objc private func customAction2(_ sender: Any?) { triggerCustomAction(at: 2) }

    private func triggerCustomAction(at index: Int) {
      guard let selectedRange = model.selectedRange,
            index < textSelectionActions.count
      else { return }

      let attributedText = model.attributedText(in: selectedRange)
      let text = Formatter(attributedText).plainText()
        .trimmingCharacters(in: .whitespacesAndNewlines)
      guard !text.isEmpty else { return }

      textSelectionActions[index](text)
    }

    // MARK: - 系统 action 响应

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
      let location = gesture.location(in: self)
      guard let url = model.url(for: location) else {
        return
      }
      openURL(url)
    }

    @objc private func share(_ sender: Any?) {
      guard let selectedRange = model.selectedRange else {
        return
      }

      let attributedText = model.attributedText(in: selectedRange)
      let itemSource = TextActivityItemSource(attributedString: attributedText)

      let activityViewController = UIActivityViewController(
        activityItems: [itemSource],
        applicationActivities: nil
      )

      if let popover = activityViewController.popoverPresentationController {
        let rect =
          model.selectionRects(for: selectedRange)
          .last?.rect.integral ?? .zero
        popover.sourceView = self
        popover.sourceRect = rect
      }

      if let windowScene = window?.windowScene,
        let viewController = windowScene.windows.first?.rootViewController
      {
        viewController.present(activityViewController, animated: true)
      }
    }
  }

  extension UITextInteractionView: UITextInteractionDelegate {
    func interactionShouldBegin(_ interaction: UITextInteraction, at point: CGPoint) -> Bool {
      logger.debug("interactionShouldBegin(at: \(point.logDescription)) -> true")
      return true
    }

    func interactionWillBegin(_ interaction: UITextInteraction) {
      logger.debug("interactionWillBegin")
      _ = self.becomeFirstResponder()
    }

    func interactionDidEnd(_ interaction: UITextInteraction) {
      logger.debug("interactionDidEnd")
    }
  }

  extension Logger.Textual.Category {
    fileprivate static let textInteraction = Self(rawValue: "textInteraction")
  }
#endif
