# CLAUDE.md

此檔案提供 Claude Code (claude.ai/code) 在此程式庫中工作時的指引。

## 專案概述

NetworkKit 是一個 Swift Package Manager 函式庫，提供基於協定導向設計的 HTTP 網路層，支援 iOS 14+。採用現代化的 Swift async/await 模式，並實作責任鏈模式來處理請求建構與回應處理。支援可取消的網路請求。

## 建置與測試指令

建置套件：
```bash
swift build
```

執行所有測試：
```bash
swift test
```

執行測試並顯示詳細輸出：
```bash
swift test --verbose
```

執行特定測試：
```bash
swift test --filter <測試名稱>
```

## 架構設計

### 核心協定與責任鏈模式

此函式庫建構在兩個協同運作的協定階層之上：

1. **請求協定** (`HTTPRequest` → `HTTPParamRequest` → `RESTFulHTTPRequest`, `GraphQLRequest`)
2. **建構器/處理器鏈** 依序處理請求與回應

### 請求建構流程

請求透過一連串的 `RequestBuilder` 協定建構：

1. `PathBuilder` - 從 baseURL 與 path 建構 URL
2. `HTTPMethodBuilder` - 設定 HTTP 方法（GET、POST 等）
3. `HTTPHeaderBuilder` - 新增標頭
4. `RequestContentBuilder` - 根據方法與 content type 編碼參數：
   - GET/DELETE → 透過 `URLQueryDataBuilder` 產生 URL query 參數
   - POST/PUT/PATCH → 根據 content-type 編碼 Body：
     - `.json` → `JSONRequestDataBuilder`
     - `.url` → `URLRequestDataBuilder`
     - `.formData` → `FormDataRequestDataBuilder`

此鏈透過 `HTTPRequest.buildRequest()` 執行，會對 `requestBuilders` 陣列進行 reduce 操作 (Request/Builder/RequestBuilder.swift:27)。

### 回應處理流程

回應會流經一連串的 `ResponseHandler` 協定，可執行以下動作：
- `.continue(data, response)` - 將修改過的 data/response 傳給下一個處理器
- `.restart` - 重試請求
- `.error(Error)` - 以失敗結束
- `.done(ResponseType)` - 以成功結束

預設處理器鏈 (HTTPRequest.swift:41-51)：
1. `ServerErrorResponseHandler` - 檢查 5xx 錯誤
2. `RequestFormatErrorResponseHandler` - 檢查 4xx 錯誤
3. `TimeoutResponseHandler` - 處理逾時錯誤
4. `BadResponseHandler` - 驗證回應結構
5. `DataMappingHandler` - 將空回應轉換為 `{}`
6. `DecodeResponseHandler` - 將 JSON 解碼為 `ResponseType`

GraphQL 請求使用不同的鏈 (GraphQLRequest.swift:31-37)：
1. `TimeoutResponseHandler`
2. `ClientErrorResponseHandler`
3. `ServerErrorResponseHandler`
4. `BadResponseHandler`
5. `GraphQLResponseHandler` - 解開 GraphQL 封裝並提取 data/errors

此鏈在 `HTTPClient.handleResponse()` 中執行 (HTTPClient.swift:44-73)，會先檢查每個處理器的 `shouldApply()` 再呼叫 `apply()`。

### 請求協定特化

**`HTTPRequest`** (基礎協定)：
- 必須實作：`baseURL`、`path`、`method`、`contentType`、`header`、`ResponseType`、`decoder`
- 提供：預設的 `requestBuilders` 與 `responseHandlers` 陣列
- 用於：無參數的簡單請求

**`HTTPParamRequest`** (擴充自 `HTTPRequest`)：
- 新增：`parameters: RequestType` (Encodable)、`encoder: JSONEncoder`
- 自動使用 `RequestContentBuilder` 編碼參數
- 用於：帶有 JSON/form/URL-encoded body 的請求

**`RESTFulHTTPRequest`** (擴充自 `HTTPParamRequest`)：
- 新增：`resource`、`resourceId`
- 使用 `RESTFulRequestBuilder` 建構 RESTful 路徑，如 `/users/{id}`
- 預設 `path` 為空（由 RESTFulRequestBuilder 處理）
- 用於：遵循 resource/id 模式的 REST API 端點

**`GraphQLRequest`** (擴充自 `HTTPRequest`)：
- 新增：`variables: VariableType` (Encodable)、`operationString: String`
- 固定 `method` = POST，`path` 為空
- 使用 `GraphQLRequestBuilder` 建構 GraphQL 請求 body
- 客製化的回應處理流程，使用 `GraphQLResponseHandler`
- Decoder 使用 `.convertFromSnakeCase` key 策略
- 用於：GraphQL queries/mutations

### HTTPClient 執行流程

HTTPClient 提供兩種發送請求的方式：

**方式 1: `send()` - 基本請求**
1. 呼叫 `request.buildRequest()` 套用建構器鏈
2. 發出 URLSession 請求（iOS 15+ 支援 delegate）
3. 驗證 HTTPURLResponse
4. 呼叫 `handleResponse()` 遞迴套用處理器鏈
5. 回傳 `Result<ResponseType, Error>`

**方式 2: `sendTask()` - 可取消請求**
1. 將 `send()` 包裝在 `Task` 中
2. 回傳 `NetworkTask<ResponseType>`，可隨時呼叫 `.cancel()` 取消
3. 透過 `await task.result` 或 `try await task.value()` 取得結果
4. 取消時會回傳 `URLError.cancelled`

**NetworkTask API**：
- `cancel()` - 取消請求
- `isCancelled` - 檢查是否已取消
- `result` - 取得 `Result<T, Error>`（async）
- `value()` - 取得值或拋出錯誤（async throws）

## 關鍵實作模式

**協定導向設計**：功能透過協定擴充與預設實作組合，而非類別繼承。

**建構器模式**：請求建構使用可組合的建構器，透過鏈對 URLRequest 進行調整。

**責任鏈模式**：請求建構與回應處理都使用有序鏈，每個元件都可以轉換或中斷流程。

**關聯型別**：請求協定使用 `associatedtype ResponseType: Decodable` 在允許泛型處理的同時維持型別安全。

**向下相容**：為 iOS <15 提供客製化的 async/await shim，使用 `withCheckedThrowingContinuation` 與 `withTaskCancellationHandler` (HTTPClient.swift:100-120)。

**Task 包裝模式**：`NetworkTask` 包裝 Swift Concurrency 的 `Task`，提供請求取消能力。當 `cancel()` 被呼叫時，底層的 URLSessionTask 也會被取消。

## 常見陷阱

- `responseHandlers` 陣列的順序很重要 - 處理器會依序執行且可能中斷後續處理
- `GraphQLResponseHandler` 永遠會套用（`shouldApply` 回傳 true），必須放在鏈的最後
- 空回應會在解碼前被 `DataMappingHandler` 轉換為 `{}`
- 請求參數會先透過 JSON 編碼轉換為 dictionary，再轉回適當格式
- `RESTFulRequestBuilder` 與 `GraphQLRequestBuilder` 會覆寫基礎的路徑建構行為
- 使用 `sendTask()` 時，應適當處理 `URLError.cancelled`，這通常不是真正的錯誤
- 當 View 或 ViewController 被釋放時，應該取消對應的 `NetworkTask` 以避免浪費資源
- 發送新請求前應先取消舊的 `NetworkTask`（如搜尋場景）
