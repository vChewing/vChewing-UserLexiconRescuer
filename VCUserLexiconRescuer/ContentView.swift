// (c) 2025 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

struct ContentView: View {
  @State private var statusMessage: String = ""
  @State private var isProcessing: Bool = false
  @State private var showAlert: Bool = false
  @State private var alertTitle: String = ""
  @State private var alertMessage: String = ""

  private let windowSize = CGSize(width: 800, height: 600)

  var body: some View {
    VStack(spacing: 20) {
      HStack {
        VStack {
          Text("vChewing 使用者詞庫救援工具")
            .font(.title)
            .fontWeight(.bold)

          Text(
            """
            此工具將執行以下操作：

            1. 刪除 vChewing 的 Override Model 資料檔案
               （漸退記憶模組的資料）

            2. 從使用者詞庫檔案中移除所有單漢字記錄
               （userdata-cht.txt 與 userdata-chs.txt）

            3. 重設「允許單漢字加入使用者詞庫」的設定

            4. 結束 vChewing 輸入法進程

            ⚠️ 此操作不可逆，請確認後再執行。
            """
          )
          .font(.body)
          .multilineTextAlignment(.leading)
          .padding()
          .background(Color.secondary.opacity(0.1))
          .cornerRadius(8)

          Button(action: performRescue) {
            if isProcessing {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
            } else {
              Text("執行救援")
                .fontWeight(.semibold)
            }
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .disabled(isProcessing)
        }

        if !statusMessage.isEmpty {
          ScrollView {
            Text(statusMessage)
              .font(.system(.body, design: .monospaced))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding()
          }
          .frame(maxHeight: 200)
          .background(Color.black.opacity(0.05))
          .cornerRadius(8)
        }
      }
    }
    .padding(30)
    .frame(width: windowSize.width, height: windowSize.height)
    .alert(alertTitle, isPresented: $showAlert) {
      Button("確定", role: .cancel) {}
    } message: {
      Text(alertMessage)
    }
  }

  private func performRescue() {
    isProcessing = true
    statusMessage = ""

    DispatchQueue.global(qos: .userInitiated).async {
      var log: [String] = []

      // Step 1: 取得使用者辭典目錄
      log.append("正在讀取 vChewing 設定...")
      let userDataFolderPath = getUserDataFolderPath()
      log.append("使用者辭典目錄：\(userDataFolderPath)")

      // Step 2: 刪除 Override Model 檔案（兩個目錄）
      log.append("\n正在刪除 Override Model 資料...")
      let pomResults = deleteOverrideModelFiles(at: userDataFolderPath)
      log.append(contentsOf: pomResults)

      // Step 2b: 清理沙盒容器目錄（POM 檔案在 Application Support 根目錄）
      let sandboxAppSupportPath =
        NSHomeDirectory()
        + "/Library/Containers/org.atelierInmu.inputmethod.vChewing/Data/Library/Application Support/"
      log.append("\n正在清理沙盒容器目錄...")
      let sandboxPomResults = deleteOverrideModelFiles(at: sandboxAppSupportPath)
      log.append(contentsOf: sandboxPomResults)
      // 沙盒中的 userdata 檔案在 vChewing 子目錄
      let sandboxVChewingPath = sandboxAppSupportPath + "vChewing/"
      let sandboxCleanupResults = cleanupUserDataFiles(at: sandboxVChewingPath)
      log.append(contentsOf: sandboxCleanupResults)

      // Step 3: 清理使用者詞庫中的單漢字記錄
      log.append("\n正在清理使用者詞庫中的單漢字記錄...")
      let cleanupResults = cleanupUserDataFiles(at: userDataFolderPath)
      log.append(contentsOf: cleanupResults)

      // Step 4: 重設 UserDefaults 設定
      log.append("\n正在重設 UserDefaults 設定...")
      let resetResult = resetUserDefaults()
      log.append(resetResult)

      // Step 5: 結束 vChewing 進程
      log.append("\n正在結束 vChewing 進程...")
      let killResult = terminateVChewingProcess()
      log.append(killResult)

      log.append("\n✅ 救援操作完成！")
      log.append("vChewing 輸入法將會在您下次切換輸入法時自動重新啟動。")

      DispatchQueue.main.async {
        statusMessage = log.joined(separator: "\n")
        isProcessing = false
        alertTitle = "完成"
        alertMessage = "救援操作已完成。vChewing 將在您下次切換輸入法時自動重新啟動。"
        showAlert = true
      }
    }
  }

  /// 從 vChewing 的 UserDefaults 取得使用者辭典目錄路徑
  private func getUserDataFolderPath() -> String {
    let vChewingDefaults = UserDefaults(suiteName: "org.atelierInmu.vChewing")
    if let specifiedPath = vChewingDefaults?.string(forKey: "UserDataFolderSpecified"),
      !specifiedPath.isEmpty
    {
      return specifiedPath
    }
    // 預設路徑
    let defaultPath =
      NSHomeDirectory()
      + "/Library/Containers/org.atelierInmu.inputmethod.vChewing/Data/Library/Application Support/vChewing/"
    return defaultPath
  }

  /// 刪除 Override Model 資料檔案
  private func deleteOverrideModelFiles(at basePath: String) -> [String] {
    var results: [String] = []
    let fileManager = FileManager.default
    let appSupportPath = basePath.hasSuffix("/") ? basePath : basePath + "/"

    let pomFiles = [
      "vChewing_override-model-data-cht.dat",
      "vChewing_override-model-data-chs.dat",
      "vChewing_override-model-data-cht.dat.journal",
      "vChewing_override-model-data-chs.dat.journal",
    ]

    for fileName in pomFiles {
      let filePath = appSupportPath + fileName
      if fileManager.fileExists(atPath: filePath) {
        do {
          try fileManager.removeItem(atPath: filePath)
          results.append("  ✓ 已刪除：\(fileName)")
        } catch {
          results.append("  ✗ 刪除失敗：\(fileName) - \(error.localizedDescription)")
        }
      } else {
        results.append("  - 不存在：\(fileName)")
      }
    }

    return results
  }

  /// 清理使用者詞庫檔案中的單漢字記錄
  private func cleanupUserDataFiles(at folderPath: String) -> [String] {
    var results: [String] = []
    let fileManager = FileManager.default

    let userDataFiles = [
      "userdata-cht.txt",
      "userdata-chs.txt",
    ]

    for fileName in userDataFiles {
      let filePath = folderPath + fileName
      if fileManager.fileExists(atPath: filePath) {
        do {
          let content = try String(contentsOfFile: filePath, encoding: .utf8)
          let lines = content.components(separatedBy: .newlines)

          var keptLines: [String] = []
          var removedCount = 0

          for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            // 跳過空行和註解行
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
              keptLines.append(line)
              continue
            }

            // 解析格式：讀音 詞值 [權重]
            // 單漢字的特徵是：詞值只有一個字元
            let components = trimmedLine.split(
              separator: " ",
              maxSplits: 2,
              omittingEmptySubsequences: true
            )
            if components.count >= 2 {
              let value = String(components[1])
              let keyChain = components[0].split(separator: "-")
              let conditions: [Bool] = [
                value.count == 1,
                keyChain.count == 1,
                keyChain.allSatisfy({ !$0.hasPrefix("_") && !$0.isEmpty }),
              ]
              let allConditionsMet = conditions.reduce(true, { $0 && $1 })
              // 判斷是否為單漢字（一個 Unicode 字元）且讀音串長度為1、讀音不包含標點符號。
              if allConditionsMet {
                removedCount += 1
                continue  // 跳過這一行，不保留
              }
            }

            keptLines.append(line)
          }

          // 寫回檔案
          let newContent = keptLines.joined(separator: "\n")
          try newContent.write(toFile: filePath, atomically: true, encoding: .utf8)
          results.append("  ✓ \(fileName)：移除了 \(removedCount) 筆單漢字記錄")

        } catch {
          results.append("  ✗ 處理失敗：\(fileName) - \(error.localizedDescription)")
        }
      } else {
        results.append("  - 不存在：\(fileName)")
      }
    }

    return results
  }

  /// 重設 UserDefaults 中的相關設定
  private func resetUserDefaults() -> String {
    let vChewingDefaults = UserDefaults(suiteName: "org.atelierInmu.vChewing")
    vChewingDefaults?.removeObject(forKey: "AllowBoostingSingleKanjiAsUserPhrase")
    vChewingDefaults?.synchronize()
    return "  ✓ 已重設 AllowBoostingSingleKanjiAsUserPhrase 設定"
  }

  /// 結束 vChewing 進程
  private func terminateVChewingProcess() -> String {
    let task = Process()
    task.launchPath = "/usr/bin/pkill"
    task.arguments = ["-9", "-f", "vChewing"]
    do {
      try task.run()
      task.waitUntilExit()
      return "  ✓ 已結束 vChewing 進程"
    } catch {
      return "  ✗ 結束進程失敗：\(error.localizedDescription)"
    }
  }
}

#Preview {
  ContentView()
}
