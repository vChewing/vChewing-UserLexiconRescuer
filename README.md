# VCUserLexiconRescuer

vChewing 使用者詞庫救援工具。

## 功能

此工具用於修復因使用者詞庫資料異常而導致的輸入法組字錯誤問題。執行以下操作：

1. **刪除 Override Model 資料檔案**：清除漸退記憶模組（Perception Override Model）的資料
2. **清理單漢字記錄**：從使用者詞庫檔案（`userdata-cht.txt` 與 `userdata-chs.txt`）中移除所有單漢字 unigram 記錄
3. **重設相關設定**：移除 `AllowBoostingSingleKanjiAsUserPhrase` 設定

## 建置

```bash
cd VALUEADD/VCUserLexiconRescuer
xcodebuild -project VCUserLexiconRescuer.xcodeproj -scheme VCUserLexiconRescuer -configuration Release build
```

## 使用

1. 執行 VCUserLexiconRescuer.app
2. 閱讀說明後點擊「執行救援」按鈕
3. 等待操作完成
4. 重新啟動 vChewing 輸入法

## 注意事項

- 此操作不可逆，執行前請確認
- 此工具不需要沙盒權限，可直接存取使用者資料目錄
- 執行完成後需重新啟動輸入法以套用變更

## 授權

MIT-NTL License
