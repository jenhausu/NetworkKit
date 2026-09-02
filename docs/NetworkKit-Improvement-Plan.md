# NetworkKit 優先改進清單

根據實用性、影響力和實作難度評估

---

## 🔴 極高優先級（立即需要）

### 1. Request Interceptor（請求攔截器）⭐⭐⭐⭐⭐

**為什麼最重要**：
- 幾乎每個實際專案都需要
- 解決最常見的痛點：auth token、API versioning、logging
- 沒有它就需要在每個請求手動處理，容易出錯

**目前問題**：
```swift
// ❌ 現在需要在每個 request 手動加 token
struct UserRequest: HTTPRequest {
    var header: HTTPHeader {
        HTTPHeader(["Authorization": "Bearer \(TokenManager.shared.token)"])
    }
}

struct PostRequest: HTTPRequest {
    var header: HTTPHeader {
        HTTPHeader(["Authorization": "Bearer \(TokenManager.shared.token)"])
    }
}
// 重複程式碼，容易忘記，難以維護
```

**有了 Interceptor**：
```swift
// ✅ 在一個地方設定，全 app 生效
HTTPClient.shared.addInterceptor(AuthInterceptor())

struct UserRequest: HTTPRequest {
    // 不用手動加 token，interceptor 自動處理
}
```

**影響力**：⭐⭐⭐⭐⭐
**實用性**：⭐⭐⭐⭐⭐
**實作難度**：🟢 中等（2-3 天）

**使用場景**：
- ✅ 自動添加 Authorization header
- ✅ 統一添加 API version header
- ✅ 記錄所有請求日誌
- ✅ 修改 base URL（如切換環境）
- ✅ 添加通用參數（如 device_id）

---

### 2. Retry Policy（智能重試策略）⭐⭐⭐⭐⭐

**為什麼重要**：
- 大幅提升 app 可靠性
- 自動處理網路不穩定（timeout、503 等）
- 使用者體驗更好（不會因為暫時的網路問題就失敗）

**目前問題**：
```swift
// ❌ 只有 408 timeout 會自動重試
// ❌ 沒有延遲（立即重試可能還是失敗）
// ❌ 不能自訂重試次數
// ❌ 其他錯誤（500、503、網路斷線）不會重試

// TimeoutResponseHandler.swift
struct TimeoutResponseHandler: ResponseHandler {
    func shouldApply(...) -> Bool {
        response.statusCode == 408  // 只處理 408
    }

    func apply(...) -> ResponseAction<Req> {
        .restart  // 立即重試，沒有延遲
    }
}
```

**需要的功能**：
```swift
let retryPolicy = RetryPolicy(
    maxRetries: 3,
    retryableStatusCodes: [408, 500, 502, 503, 504],
    retryableErrors: [.timedOut, .networkConnectionLost],
    delayStrategy: .exponential(base: 2)  // 1s, 2s, 4s
)

HTTPClient.shared.setRetryPolicy(retryPolicy)
```

**影響力**：⭐⭐⭐⭐⭐
**實用性**：⭐⭐⭐⭐⭐
**實作難度**：🟡 中等偏難（3-4 天）

**實際效益**：
- Server 暫時過載（503）→ 等幾秒後重試 → 成功
- 網路暫時斷線 → 重試 → 成功
- 減少 90% 的「請求失敗」錯誤

---

### 3. Network Logger / Event Monitor（日誌與監控）⭐⭐⭐⭐

**為什麼重要**：
- Debug 時最需要
- 了解 API 效能瓶頸
- 追蹤錯誤原因

**目前問題**：
```swift
// ❌ 只在 DEBUG 模式印出 JSON
// ❌ 沒有請求資訊（URL、headers、耗時）
// ❌ 無法自訂 log 格式或輸出位置

// ResponseHandler.swift:16-28
public extension ResponseHandler {
    func printJSON(data: Data) {
        #if DEBUG
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return }
        print(dict)  // 只印出 response body
        #endif
    }
}
```

**需要的功能**：
```swift
let logger = NetworkLogger(level: .verbose)
HTTPClient.shared.addEventMonitor(logger)

// 輸出範例：
// 📤 [GET] https://api.example.com/users/123
//    Headers: ["Authorization": "Bearer xxx", "User-Agent": "MyApp/1.0"]
//    Body: (none)
//
// 📥 [200] 156ms
//    Body: {"id": "123", "name": "John"}
//
// ❌ [500] 2.3s
//    Error: Internal Server Error
```

**影響力**：⭐⭐⭐⭐
**實用性**：⭐⭐⭐⭐⭐
**實作難度**：🟢 簡單（1-2 天）

---

## 🟡 高優先級（近期需要）

### 4. Progress Tracking（進度追蹤）⭐⭐⭐⭐

**為什麼重要**：
- 檔案上傳/下載必需
- 使用者體驗（顯示進度條）
- 大請求必備（讓使用者知道還在進行中）

**目前問題**：
```swift
// ❌ 完全沒有進度追蹤
// 使用者不知道上傳/下載進度
// 無法顯示進度條
```

**需要的功能**：
```swift
struct UploadRequest: HTTPRequest {
    var progressHandler: ((Progress) -> Void)?
}

let request = UploadRequest()
let task = HTTPClient.shared.sendTask(request)

task.uploadProgress { progress in
    print("已上傳: \(progress.fractionCompleted * 100)%")
    updateProgressBar(progress.fractionCompleted)
}
```

**影響力**：⭐⭐⭐⭐
**實用性**：⭐⭐⭐⭐
**實作難度**：🟡 中等（2-3 天）

**使用場景**：
- 上傳圖片/影片
- 下載大檔案
- 批次操作

---

### 5. File Upload Support（完整檔案上傳）⭐⭐⭐⭐

**為什麼重要**：
- 目前的 FormData 只支援簡單欄位
- 無法上傳檔案（圖片、影片、文件）
- 這是很常見的需求

**目前問題**：
```swift
// FormDataRequestDataBuilder.swift
// ❌ 只能傳 String value
for (key, value) in param {
    body.appendString("--\(boundary)\r\n")
    body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
    body.appendString("\(value)\r\n")  // 只能 String！
}
```

**需要的功能**：
```swift
struct UploadImageRequest: MultipartRequest {
    let image: UIImage
    let description: String

    func buildMultipartFormData(_ formData: inout MultipartFormData) {
        // 上傳檔案
        formData.append(
            image.jpegData(compressionQuality: 0.8)!,
            withName: "photo",
            fileName: "photo.jpg",
            mimeType: "image/jpeg"
        )

        // 一般欄位
        formData.append(description, withName: "description")
    }
}
```

**影響力**：⭐⭐⭐⭐
**實用性**：⭐⭐⭐⭐
**實作難度**：🟡 中等（3-4 天）

---

### 6. 可配置的 URLSessionConfiguration⭐⭐⭐

**為什麼重要**：
- 不同場景需要不同配置（timeout、cache）
- 目前寫死 `URLSession.shared`

**目前問題**：
```swift
// ❌ 寫死配置，無法自訂
public init(session: URLSession = .shared) {
    self.session = session
}

// 想要設定 timeout = 60 秒？無法做到
// 想要關閉快取？無法做到
```

**需要的功能**：
```swift
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 60
config.requestCachePolicy = .reloadIgnoringLocalCacheData

let client = HTTPClient(configuration: config)

// 或者修改 shared 的配置
HTTPClient.configureShared { config in
    config.timeoutIntervalForRequest = 60
}
```

**影響力**：⭐⭐⭐
**實用性**：⭐⭐⭐
**實作難度**：🟢 簡單（1 天）

---

## 🟢 中優先級（未來可以考慮）

### 7. Mock/Stub Support（測試支援）⭐⭐⭐

**實作難度**：🟡 中等
**影響力**：⭐⭐⭐（主要是測試）

### 8. Combine Publisher⭐⭐

**實作難度**：🟢 簡單
**影響力**：⭐⭐（有些專案會用到）

### 9. Certificate Pinning⭐⭐

**實作難度**：🔴 難
**影響力**：⭐⭐（企業需求）

### 10. Network Reachability⭐⭐

**實作難度**：🟢 簡單
**影響力**：⭐⭐（可用第三方庫）

---

## 📊 總結對比表

| 功能 | 影響力 | 實用性 | 實作難度 | 優先級 | 預估時間 |
|------|--------|--------|----------|--------|----------|
| **Request Interceptor** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 🟡 中等 | 🔴 極高 | 2-3 天 |
| **Retry Policy** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 🟡 中等偏難 | 🔴 極高 | 3-4 天 |
| **Event Monitor/Logger** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 🟢 簡單 | 🔴 極高 | 1-2 天 |
| **Progress Tracking** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 🟡 中等 | 🟡 高 | 2-3 天 |
| **File Upload** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 🟡 中等 | 🟡 高 | 3-4 天 |
| **Configurable URLSession** | ⭐⭐⭐ | ⭐⭐⭐ | 🟢 簡單 | 🟡 高 | 1 天 |
| Mock/Stub Support | ⭐⭐⭐ | ⭐⭐⭐ | 🟡 中等 | 🟢 中 | 2-3 天 |
| Combine Publisher | ⭐⭐ | ⭐⭐ | 🟢 簡單 | 🟢 中 | 1 天 |
| Certificate Pinning | ⭐⭐ | ⭐⭐ | 🔴 難 | 🟢 低 | 5+ 天 |
| Network Reachability | ⭐⭐ | ⭐⭐ | 🟢 簡單 | 🟢 低 | 1 天 |

---

## 🎯 建議實作順序

### Sprint 1（1 週）
1. **Event Monitor/Logger**（1-2 天）- 立即改善開發體驗
2. **Request Interceptor**（2-3 天）- 解決最大痛點
3. **Configurable URLSession**（1 天）- 順便改善

### Sprint 2（1 週）
4. **Retry Policy**（3-4 天）- 提升可靠性
5. **Progress Tracking**（2-3 天）- 為檔案上傳做準備

### Sprint 3（1 週）
6. **File Upload Support**（3-4 天）- 完整的檔案上傳功能

---

## 💡 為什麼這個順序？

### 1. Event Monitor/Logger 先做
- **最簡單**（1-2 天）
- **立即價值**：Debug 更方便
- **為後續功能鋪路**：Interceptor 和 Retry 都會用到

### 2. Request Interceptor 第二
- **最高價值**
- **解決 80% 的常見需求**
- 有了 Logger，實作和測試更容易

### 3. Retry Policy 第三
- **提升可靠性**
- 需要 Event Monitor 來追蹤重試行為
- 可能與 Interceptor 互動（如 401 refresh token）

### 4. Progress + File Upload 最後
- 相對獨立的功能
- 有了前面的基礎，實作更順暢

---

## 🚀 如果只能選三個

1. **Request Interceptor** - 沒有它就像沒有插座的房子
2. **Retry Policy** - 讓 app 更可靠
3. **Event Monitor/Logger** - Debug 和監控的基礎

這三個實作完後，NetworkKit 就能滿足 90% 的實際專案需求！

---

## 📝 與 Alamofire 功能完整度對比

| 功能類別 | Alamofire | NetworkKit (當前) | 加上建議改進後 |
|---------|-----------|-------------------|----------------|
| 基本請求 | ✅ | ✅ | ✅ |
| Async/Await | ✅ | ✅ | ✅ |
| Request Cancellation | ✅ | ✅ | ✅ |
| Request Interceptor | ✅ | ❌ | ✅ |
| Retry Policy | ✅ | ⚠️ (只有 408) | ✅ |
| Event Monitor | ✅ | ❌ | ✅ |
| Progress Tracking | ✅ | ❌ | ✅ |
| File Upload | ✅ | ⚠️ (簡單) | ✅ |
| GraphQL | ⚠️ (需第三方) | ✅ | ✅ |
| Certificate Pinning | ✅ | ❌ | ❌ |
| Network Reachability | ✅ | ❌ | ❌ |
| Combine/Rx | ✅ | ❌ | ⚠️ |

**完成度**：
- 當前：**50%**
- 完成 Sprint 1-3 後：**85%**

---

## 總結

NetworkKit 目前最缺乏的三大核心功能：

1. 🥇 **Request Interceptor** - 統一處理 auth、logging、versioning
2. 🥈 **Retry Policy** - 自動重試，提升可靠性
3. 🥉 **Event Monitor** - 可觀測性和除錯

實作完這三個後，NetworkKit 就能從「玩具專案」升級到「可用於生產環境的框架」！

---

## 🐛 既有設計缺陷與潛在地雷（2026-09 稽核）

上面是「還缺哪些功能」，這一節是「現有實作哪裡會咬人」。起因是取消照片按讚（`DELETE /photos/{id}/like`，server 回 204）在 `HTTPClient.handleResponse` 撞上 `fatalError` 閃退。

### 已修

#### A. 204 No Content 沒有終端 handler（已修，commit `2f9194c`）

handler 鏈裡 `DecodeResponseHandler` 只認 `== 200`、`BadResponseHandler` 只認非 2xx，
204 這種「成功但沒 body」會穿過整條鏈，最後在 `HTTPClient` 用光 handler。

修法：新增 `NoContentResponseHandler`（`statusCode == 204` → 視為成功 → decode 呼叫端宣告的空回應型別），
插在 `DataMappingHandler` 之後、`DecodeResponseHandler` 之前。

一次修好 4 個會踩到的端點：`UnlikePhoto`、`RemoveBookmark`、`DeleteAccount`、`MergeMember`。

#### B. `handleResponse` 用 `fatalError` 兜底（已修，commit `3c7afb4`）

`HTTPClient.swift:166` 原本 `fatalError("No handler left but did not reach a stop.")`。
「伺服器回了預期外但合法的 HTTP 回應」是執行期狀況，不是 programmer error，
函式庫不該讓宿主 App crash。

修法：改回 `.failure(HTTPResponseError.error(statusCode:))`。
所有現在與未來的 handler 鏈縫隙，從「閃退」變成「App 能 `catch` 的錯誤」。
這比逐一補 handler 更根本——兩個都做：204 給正確語意、`fatalError` 兜底當安全網。

### 潛在但目前沒踩到

#### C. 2xx 但非 200 / 204（201 / 202 / 206…）

`DecodeResponseHandler` 只認 `== 200`，其餘 2xx 全落空。有了修正 B 之後不會再 crash，
但會變成 `.failure`，語意仍不對（201 Created 應該是成功）。

- server 目前唯一的 201 是 `PhotoReportController` 的 `.created`（檢舉照片）
- iOS 的 `reportPhoto` 是手刻 `URLRequest`、沒走 NetworkKit，所以現在剛好沒事
- 只要哪天有人加一個走 NetworkKit、server 回 201 的端點，就是下一顆地雷

建議：把 `DecodeResponseHandler` 的條件放寬成 `200...299`，或補一個 `SuccessResponseHandler` 收整個 2xx 區間。

#### 不受影響的（沒走 NetworkKit）

`getMyPhotos` / `uploadPhoto` / `deletePhoto` / `reportPhoto` 都是手刻 `URLRequest`、
自己 `switch statusCode`，204 各自有處理。

### 其他可改善點

#### D. `TimeoutResponseHandler` 回 `.restart` → 無限重試

`.restart` 會走 `performSend(retryCount: 0)`：408 會無限重試，沒有次數上限、沒有 backoff、
還把 `retryCount` 歸零。server 若持續 408 就活鎖。應該納入 `RetryPolicy` 的次數/退避控制。

#### E. `HTTPClient` 的執行緒安全

`eventMonitors` / `interceptors` 是可變陣列，`addInterceptor` / `addEventMonitor` 沒有同步保護，
和進行中的請求併發存取就是 data race；`HTTPClient.shared` 又是 `var`。
Swift 6 concurrency 檢查會直接報。

#### F. 兩套不協調的重試機制

`performSend` 的 `retryPolicy`（狀態碼重試）vs handler 的 `.restart`，兩者彼此不知道對方，
`retryCount` 的語意在 `.restart` 路徑會遺失。應該統一到單一重試入口。

#### G. iOS 14 的 deprecated `URLSession.data` fallback extension

`Package.swift` 已要求 iOS 14，可考慮直接拿掉 fallback（視是否還支援 iOS 14）。

### 對應表

| # | 問題 | 嚴重度 | 狀態 |
|---|------|--------|------|
| A | 204 沒有終端 handler | 🔴 會 crash | ✅ 已修 `2f9194c` |
| B | `handleResponse` 用 `fatalError` 兜底 | 🔴 會 crash | ✅ 已修 `3c7afb4` |
| C | 2xx 非 200/204 語意不對 | 🟡 潛在 | ⬜ 待處理 |
| D | `TimeoutResponseHandler` 無限重試 | 🟡 活鎖風險 | ⬜ 待處理 |
| E | `HTTPClient` data race | 🟡 Swift 6 會擋 | ⬜ 待處理 |
| F | 兩套重試機制不協調 | 🟢 技術債 | ⬜ 待處理 |
| G | iOS 14 deprecated fallback | 🟢 清理 | ⬜ 待處理 |
