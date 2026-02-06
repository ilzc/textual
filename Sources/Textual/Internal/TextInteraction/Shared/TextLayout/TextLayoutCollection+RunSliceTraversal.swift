#if TEXTUAL_ENABLE_TEXT_SELECTION
  import Foundation

  extension TextLayoutCollection {
    func indexPathsForRunSlices(in range: TextRange) -> some Sequence<IndexPath> {
      IndexPathSequence(
        range: range,
        next: self.indexPathForRunSlice(after:),
        previous: self.indexPathForRunSlice(before:)
      )
    }
  }

  extension TextLayoutCollection {
    fileprivate func indexPathForRunSlice(after indexPath: IndexPath) -> IndexPath? {
      guard indexPath.layout < layouts.count else { return nil }
      let layout = layouts[indexPath.layout]
      guard indexPath.line < layout.lines.count else { return nil }
      let line = layout.lines[indexPath.line]
      guard indexPath.run < line.runs.count else { return nil }
      let run = line.runs[indexPath.run]

      if indexPath.runSlice + 1 < run.slices.count {
        return IndexPath(
          runSlice: indexPath.runSlice + 1,
          run: indexPath.run,
          line: indexPath.line,
          layout: indexPath.layout
        )
      }

      if indexPath.run + 1 < line.runs.count {
        return IndexPath(
          run: indexPath.run + 1,
          line: indexPath.line,
          layout: indexPath.layout
        )
      }

      if indexPath.line + 1 < layout.lines.count {
        return IndexPath(
          line: indexPath.line + 1,
          layout: indexPath.layout
        )
      }

      if indexPath.layout + 1 < layouts.count {
        return IndexPath(layout: indexPath.layout + 1)
      }

      return nil
    }

    fileprivate func indexPathForRunSlice(before indexPath: IndexPath) -> IndexPath? {
      if indexPath.runSlice > 0 {
        return IndexPath(
          runSlice: indexPath.runSlice - 1,
          run: indexPath.run,
          line: indexPath.line,
          layout: indexPath.layout
        )
      }

      if indexPath.run > 0 {
        guard indexPath.layout < layouts.count,
              indexPath.line < layouts[indexPath.layout].lines.count,
              indexPath.run - 1 < layouts[indexPath.layout].lines[indexPath.line].runs.count
        else { return nil }
        let previousRun = layouts[indexPath.layout].lines[indexPath.line].runs[indexPath.run - 1]
        return IndexPath(
          runSlice: previousRun.slices.endIndex - 1,
          run: indexPath.run - 1,
          line: indexPath.line,
          layout: indexPath.layout
        )
      }

      if indexPath.line > 0 {
        guard indexPath.layout < layouts.count,
              indexPath.line - 1 < layouts[indexPath.layout].lines.count
        else { return nil }
        let previousLine = layouts[indexPath.layout].lines[indexPath.line - 1]
        guard !previousLine.runs.isEmpty else { return nil }
        let lastRunIndex = previousLine.runs.endIndex - 1
        let lastRun = previousLine.runs[lastRunIndex]

        return IndexPath(
          runSlice: lastRun.slices.endIndex - 1,
          run: lastRunIndex,
          line: indexPath.line - 1,
          layout: indexPath.layout
        )
      }

      if indexPath.layout > 0 {
        guard indexPath.layout - 1 < layouts.count else { return nil }
        let previousLayout = layouts[indexPath.layout - 1]
        guard !previousLayout.lines.isEmpty else { return nil }
        let lastLineIndex = previousLayout.lines.endIndex - 1
        let lastLine = previousLayout.lines[lastLineIndex]
        guard !lastLine.runs.isEmpty else { return nil }
        let lastRunIndex = lastLine.runs.endIndex - 1
        let lastRun = lastLine.runs[lastRunIndex]
        return IndexPath(
          runSlice: lastRun.slices.endIndex - 1,
          run: lastRunIndex,
          line: lastLineIndex,
          layout: indexPath.layout - 1
        )
      }

      return nil
    }
  }
#endif
