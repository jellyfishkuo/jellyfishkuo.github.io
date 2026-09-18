/* =========================================================
   電費紀錄 - script.js
   純前端邏輯，資料只存在瀏覽器 localStorage，不會呼叫任何外部 API。
   ========================================================= */

(function () {
  "use strict";

  // ---------------------------------------------------------
  // 常數設定
  // ---------------------------------------------------------
  var STORAGE_KEY = "electricityMeterRecords_v1";

  // ---------------------------------------------------------
  // DOM 節點快取
  // ---------------------------------------------------------
  var quickInput = document.getElementById("quick-reading");
  var quickError = document.getElementById("quick-error");
  var quickSaveBtn = document.getElementById("quick-save-btn");

  var toggleManualBtn = document.getElementById("toggle-manual-btn");
  var manualForm = document.getElementById("manual-form");
  var manualReading = document.getElementById("manual-reading");
  var manualDate = document.getElementById("manual-date");
  var manualTime = document.getElementById("manual-time");
  var manualError = document.getElementById("manual-error");
  var manualSaveBtn = document.getElementById("manual-save-btn");
  var manualCancelBtn = document.getElementById("manual-cancel-btn");

  var exportJsonBtn = document.getElementById("export-json-btn");
  var exportCsvBtn = document.getElementById("export-csv-btn");
  var importFileInput = document.getElementById("import-file");
  var clearAllBtn = document.getElementById("clear-all-btn");
  var importStatus = document.getElementById("import-status");

  var historyList = document.getElementById("history-list");
  var recordCountEl = document.getElementById("record-count");
  var emptyMsg = document.getElementById("empty-msg");

  var editModal = document.getElementById("edit-modal");
  var editReading = document.getElementById("edit-reading");
  var editDate = document.getElementById("edit-date");
  var editTime = document.getElementById("edit-time");
  var editError = document.getElementById("edit-error");
  var editSaveBtn = document.getElementById("edit-save-btn");
  var editCancelBtn = document.getElementById("edit-cancel-btn");
  var editingId = null;

  var confirmModal = document.getElementById("confirm-modal");
  var confirmMessage = document.getElementById("confirm-message");
  var confirmOkBtn = document.getElementById("confirm-ok-btn");
  var confirmCancelBtn = document.getElementById("confirm-cancel-btn");
  var pendingConfirmAction = null;

  // ---------------------------------------------------------
  // 資料存取（localStorage）
  // ---------------------------------------------------------

  /**
   * 從 localStorage 讀取所有紀錄。
   * 任何讀取失敗、格式錯誤都會被安全地忽略，回傳空陣列，
   * 不會讓整個網頁因此壞掉。
   */
  function loadRecords() {
    var raw;
    try {
      raw = window.localStorage.getItem(STORAGE_KEY);
    } catch (e) {
      // 例如無痕模式或瀏覽器封鎖 localStorage
      console.warn("無法讀取 localStorage：", e);
      return [];
    }

    if (!raw) return [];

    var parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      console.warn("localStorage 內容不是合法的 JSON，已忽略：", e);
      return [];
    }

    if (!Array.isArray(parsed)) return [];

    // 過濾掉格式不正確的資料，避免壞資料造成畫面錯誤
    return parsed.filter(isValidRecordShape).map(normalizeRecord);
  }

  function isValidRecordShape(r) {
    return (
      r &&
      typeof r === "object" &&
      typeof r.reading === "string" &&
      typeof r.date === "string" &&
      typeof r.time === "string"
    );
  }

  function normalizeRecord(r) {
    return {
      id: typeof r.id === "string" && r.id ? r.id : generateId(),
      reading: normalizeReading(r.reading),
      date: r.date,
      time: r.time,
      createdAt:
        typeof r.createdAt === "string" && r.createdAt
          ? r.createdAt
          : new Date().toISOString()
    };
  }

  function saveRecords(records) {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(records));
      return true;
    } catch (e) {
      console.error("儲存到 localStorage 失敗：", e);
      alert("儲存失敗，裝置儲存空間可能已滿或瀏覽器不支援本機儲存。");
      return false;
    }
  }

  // 記憶體中的紀錄陣列（每次操作後與 localStorage 同步）
  var records = loadRecords();

  // ---------------------------------------------------------
  // 工具函式
  // ---------------------------------------------------------

  function generateId() {
    if (window.crypto && typeof window.crypto.randomUUID === "function") {
      return window.crypto.randomUUID();
    }
    return "id-" + Date.now() + "-" + Math.random().toString(16).slice(2);
  }

  /** 電表讀數固定以「字串」保存，確保前導零不會遺失 */
  function normalizeReading(value) {
    var digits = String(value).replace(/\D/g, "");
    if (digits.length >= 4) return digits.slice(0, 4);
    return digits.padStart(4, "0");
  }

  function isValidReadingInput(value) {
    return /^\d{4}$/.test(value);
  }

  function pad2(n) {
    return String(n).padStart(2, "0");
  }

  /** 回傳目前時間的 { date: 'YYYY-MM-DD', time: 'HH:MM' } */
  function getNowParts() {
    var now = new Date();
    return {
      date:
        now.getFullYear() +
        "-" +
        pad2(now.getMonth() + 1) +
        "-" +
        pad2(now.getDate()),
      time: pad2(now.getHours()) + ":" + pad2(now.getMinutes())
    };
  }

  /** 將 YYYY-MM-DD 轉成 YYYY/MM/DD 顯示用格式 */
  function formatDateDisplay(dateStr) {
    return String(dateStr).replace(/-/g, "/");
  }

  /** 排序用的字串鍵值，日期+時間字串本身就能正確排序 */
  function sortKey(r) {
    return r.date + " " + r.time;
  }

  function sortRecordsDesc(list) {
    return list.slice().sort(function (a, b) {
      var ka = sortKey(a);
      var kb = sortKey(b);
      if (ka === kb) {
        // 日期時間相同時，用建立時間排序，較新的在上面
        return (b.createdAt || "").localeCompare(a.createdAt || "");
      }
      return ka > kb ? -1 : 1;
    });
  }

  // ---------------------------------------------------------
  // 畫面渲染
  // ---------------------------------------------------------

  function render() {
    var sorted = sortRecordsDesc(records);

    historyList.innerHTML = "";

    if (sorted.length === 0) {
      emptyMsg.classList.remove("hidden");
      recordCountEl.textContent = "";
    } else {
      emptyMsg.classList.add("hidden");
      recordCountEl.textContent = "（共 " + sorted.length + " 筆）";
    }

    sorted.forEach(function (r) {
      historyList.appendChild(buildHistoryItem(r));
    });
  }

  /** 使用 DOM API 建立節點，避免 innerHTML 字串拼接造成 XSS 風險 */
  function buildHistoryItem(r) {
    var li = document.createElement("li");
    li.className = "history-item";
    li.dataset.id = r.id;

    var info = document.createElement("div");
    info.className = "record-info";

    var readingEl = document.createElement("div");
    readingEl.className = "record-reading";
    readingEl.textContent = r.reading;

    var datetimeEl = document.createElement("div");
    datetimeEl.className = "record-datetime";
    datetimeEl.textContent = formatDateDisplay(r.date) + " " + r.time;

    info.appendChild(readingEl);
    info.appendChild(datetimeEl);

    var actions = document.createElement("div");
    actions.className = "record-actions";

    var editBtn = document.createElement("button");
    editBtn.type = "button";
    editBtn.className = "icon-btn";
    editBtn.setAttribute("aria-label", "編輯這筆紀錄");
    editBtn.textContent = "✎";
    editBtn.addEventListener("click", function () {
      openEditModal(r.id);
    });

    var deleteBtn = document.createElement("button");
    deleteBtn.type = "button";
    deleteBtn.className = "icon-btn danger";
    deleteBtn.setAttribute("aria-label", "刪除這筆紀錄");
    deleteBtn.textContent = "🗑";
    deleteBtn.addEventListener("click", function () {
      confirmDeleteRecord(r.id);
    });

    actions.appendChild(editBtn);
    actions.appendChild(deleteBtn);

    li.appendChild(info);
    li.appendChild(actions);
    return li;
  }

  // ---------------------------------------------------------
  // 快速新增（首頁主要流程）
  // ---------------------------------------------------------

  quickInput.addEventListener("input", function () {
    quickInput.value = quickInput.value.replace(/\D/g, "").slice(0, 4);
    quickError.textContent = "";
  });

  quickInput.addEventListener("keydown", function (e) {
    if (e.key === "Enter") {
      e.preventDefault();
      handleQuickSave();
    }
  });

  quickSaveBtn.addEventListener("click", handleQuickSave);

  function handleQuickSave() {
    var value = quickInput.value.trim();
    if (!isValidReadingInput(value)) {
      quickError.textContent = "請輸入 4 位數字，例如 0123";
      quickInput.focus();
      return;
    }

    var now = getNowParts();
    var record = {
      id: generateId(),
      reading: value,
      date: now.date,
      time: now.time,
      createdAt: new Date().toISOString()
    };

    records.push(record);
    if (saveRecords(records)) {
      render();
      quickInput.value = "";
      quickError.textContent = "";
      // 稍微延遲再 focus，避免部分手機瀏覽器鍵盤收合動畫卡頓
      setTimeout(function () {
        quickInput.focus();
      }, 50);
    }
  }

  // ---------------------------------------------------------
  // 手動新增歷史紀錄
  // ---------------------------------------------------------

  toggleManualBtn.addEventListener("click", function () {
    var isHidden = manualForm.classList.contains("hidden");
    if (isHidden) {
      var now = getNowParts();
      manualReading.value = "";
      manualDate.value = now.date;
      manualTime.value = now.time;
      manualError.textContent = "";
      manualForm.classList.remove("hidden");
      toggleManualBtn.textContent = "▲ 收合手動新增";
    } else {
      manualForm.classList.add("hidden");
      toggleManualBtn.textContent = "➕ 手動新增歷史紀錄";
    }
  });

  manualCancelBtn.addEventListener("click", function () {
    manualForm.classList.add("hidden");
    toggleManualBtn.textContent = "➕ 手動新增歷史紀錄";
  });

  manualReading.addEventListener("input", function () {
    manualReading.value = manualReading.value.replace(/\D/g, "").slice(0, 4);
  });

  manualSaveBtn.addEventListener("click", function () {
    var reading = manualReading.value.trim();
    var date = manualDate.value;
    var time = manualTime.value;

    if (!isValidReadingInput(reading)) {
      manualError.textContent = "請輸入 4 位數字，例如 0123";
      return;
    }
    if (!date) {
      manualError.textContent = "請選擇日期";
      return;
    }
    if (!time) {
      manualError.textContent = "請選擇時間";
      return;
    }

    var record = {
      id: generateId(),
      reading: reading,
      date: date,
      time: time,
      createdAt: new Date().toISOString()
    };

    records.push(record);
    if (saveRecords(records)) {
      render();
      manualError.textContent = "";
      manualForm.classList.add("hidden");
      toggleManualBtn.textContent = "➕ 手動新增歷史紀錄";
    }
  });

  // ---------------------------------------------------------
  // 編輯紀錄
  // ---------------------------------------------------------

  function openEditModal(id) {
    var record = records.find(function (r) {
      return r.id === id;
    });
    if (!record) return;

    editingId = id;
    editReading.value = record.reading;
    editDate.value = record.date;
    editTime.value = record.time;
    editError.textContent = "";
    editModal.classList.remove("hidden");
  }

  function closeEditModal() {
    editModal.classList.add("hidden");
    editingId = null;
  }

  editReading.addEventListener("input", function () {
    editReading.value = editReading.value.replace(/\D/g, "").slice(0, 4);
  });

  editCancelBtn.addEventListener("click", closeEditModal);

  editSaveBtn.addEventListener("click", function () {
    if (!editingId) return;

    var reading = editReading.value.trim();
    var date = editDate.value;
    var time = editTime.value;

    if (!isValidReadingInput(reading)) {
      editError.textContent = "請輸入 4 位數字，例如 0123";
      return;
    }
    if (!date) {
      editError.textContent = "請選擇日期";
      return;
    }
    if (!time) {
      editError.textContent = "請選擇時間";
      return;
    }

    var record = records.find(function (r) {
      return r.id === editingId;
    });
    if (!record) {
      closeEditModal();
      return;
    }

    record.reading = reading;
    record.date = date;
    record.time = time;

    if (saveRecords(records)) {
      render();
      closeEditModal();
    }
  });

  // 點擊 modal 外層背景可關閉編輯視窗
  editModal.addEventListener("click", function (e) {
    if (e.target === editModal) closeEditModal();
  });

  // ---------------------------------------------------------
  // 刪除紀錄 / 清除全部（共用確認 Modal）
  // ---------------------------------------------------------

  function showConfirm(message, onConfirm) {
    confirmMessage.textContent = message;
    pendingConfirmAction = onConfirm;
    confirmModal.classList.remove("hidden");
  }

  function closeConfirm() {
    confirmModal.classList.add("hidden");
    pendingConfirmAction = null;
  }

  confirmCancelBtn.addEventListener("click", closeConfirm);

  confirmModal.addEventListener("click", function (e) {
    if (e.target === confirmModal) closeConfirm();
  });

  confirmOkBtn.addEventListener("click", function () {
    var action = pendingConfirmAction;
    closeConfirm();
    if (typeof action === "function") action();
  });

  function confirmDeleteRecord(id) {
    showConfirm("確定要刪除這筆紀錄嗎？此動作無法復原。", function () {
      records = records.filter(function (r) {
        return r.id !== id;
      });
      if (saveRecords(records)) render();
    });
  }

  clearAllBtn.addEventListener("click", function () {
    if (records.length === 0) return;
    showConfirm("確定要清除「全部」紀錄嗎？此動作無法復原！", function () {
      records = [];
      if (saveRecords(records)) {
        render();
        importStatus.textContent = "已清除全部紀錄";
      }
    });
  });

  // ---------------------------------------------------------
  // 匯出 JSON / CSV
  // ---------------------------------------------------------

  function downloadBlob(content, filename, mimeType) {
    var blob = new Blob([content], { type: mimeType });
    var url = URL.createObjectURL(blob);
    var a = document.createElement("a");
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () {
      URL.revokeObjectURL(url);
    }, 1000);
  }

  function timestampForFilename() {
    var now = new Date();
    return (
      now.getFullYear() +
      pad2(now.getMonth() + 1) +
      pad2(now.getDate()) +
      "-" +
      pad2(now.getHours()) +
      pad2(now.getMinutes())
    );
  }

  exportJsonBtn.addEventListener("click", function () {
    if (records.length === 0) {
      importStatus.textContent = "目前沒有紀錄可以匯出";
      return;
    }
    var sorted = sortRecordsDesc(records);
    var json = JSON.stringify(sorted, null, 2);
    downloadBlob(
      json,
      "electricity-records-" + timestampForFilename() + ".json",
      "application/json"
    );
    importStatus.textContent = "已匯出 " + sorted.length + " 筆紀錄（JSON）";
  });

  exportCsvBtn.addEventListener("click", function () {
    if (records.length === 0) {
      importStatus.textContent = "目前沒有紀錄可以匯出";
      return;
    }
    var sorted = sortRecordsDesc(records);
    var header = ["id", "reading", "date", "time", "createdAt"];
    var lines = [header.join(",")];

    sorted.forEach(function (r) {
      lines.push(
        [
          csvEscape(r.id),
          csvEscape(r.reading),
          csvEscape(r.date),
          csvEscape(r.time),
          csvEscape(r.createdAt)
        ].join(",")
      );
    });

    // 加上 UTF-8 BOM，避免 Excel 開啟中文檔名 / 內容時亂碼
    var csv = "\uFEFF" + lines.join("\r\n");
    downloadBlob(
      csv,
      "electricity-records-" + timestampForFilename() + ".csv",
      "text/csv;charset=utf-8"
    );
    importStatus.textContent = "已匯出 " + sorted.length + " 筆紀錄（CSV）";
  });

  function csvEscape(value) {
    var str = String(value == null ? "" : value);
    if (/[",\r\n]/.test(str)) {
      return '"' + str.replace(/"/g, '""') + '"';
    }
    return str;
  }

  // ---------------------------------------------------------
  // 匯入 JSON / CSV（含去重複）
  // ---------------------------------------------------------

  importFileInput.addEventListener("change", function () {
    var file = importFileInput.files && importFileInput.files[0];
    if (!file) return;

    var reader = new FileReader();
    reader.onload = function () {
      try {
        var text = String(reader.result || "");
        var isJson =
          /\.json$/i.test(file.name) || text.trim().startsWith("[");
        var incoming = isJson ? parseJsonImport(text) : parseCsvImport(text);
        mergeImportedRecords(incoming);
      } catch (err) {
        console.error("匯入失敗：", err);
        importStatus.textContent = "匯入失敗，檔案格式無法辨識";
      } finally {
        // 清空 value，讓使用者可以重複選同一個檔案
        importFileInput.value = "";
      }
    };
    reader.onerror = function () {
      importStatus.textContent = "讀取檔案時發生錯誤";
      importFileInput.value = "";
    };
    reader.readAsText(file, "utf-8");
  });

  function parseJsonImport(text) {
    var data = JSON.parse(text);
    if (!Array.isArray(data)) {
      throw new Error("JSON 內容必須是陣列");
    }
    return data;
  }

  function parseCsvImport(text) {
    // 移除可能存在的 UTF-8 BOM
    text = text.replace(/^\uFEFF/, "");
    var lines = text
      .split(/\r\n|\n|\r/)
      .filter(function (line) {
        return line.trim().length > 0;
      });
    if (lines.length < 2) return [];

    var headers = parseCsvLine(lines[0]).map(function (h) {
      return h.trim();
    });

    var rows = [];
    for (var i = 1; i < lines.length; i++) {
      var cells = parseCsvLine(lines[i]);
      var obj = {};
      headers.forEach(function (h, idx) {
        obj[h] = cells[idx] != null ? cells[idx] : "";
      });
      rows.push(obj);
    }
    return rows;
  }

  /** 簡易 CSV 單行解析，支援雙引號內含逗號 / 逸出雙引號 */
  function parseCsvLine(line) {
    var result = [];
    var cur = "";
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      var ch = line[i];
      if (inQuotes) {
        if (ch === '"') {
          if (line[i + 1] === '"') {
            cur += '"';
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          cur += ch;
        }
      } else {
        if (ch === '"') {
          inQuotes = true;
        } else if (ch === ",") {
          result.push(cur);
          cur = "";
        } else {
          cur += ch;
        }
      }
    }
    result.push(cur);
    return result;
  }

  function mergeImportedRecords(incoming) {
    var existingIds = new Set(
      records.map(function (r) {
        return r.id;
      })
    );
    var existingKeys = new Set(
      records.map(function (r) {
        return r.reading + "|" + r.date + "|" + r.time + "|" + r.createdAt;
      })
    );

    var added = 0;
    var skipped = 0;
    var invalid = 0;

    incoming.forEach(function (raw) {
      if (!raw || typeof raw !== "object") {
        invalid++;
        return;
      }

      var readingRaw = raw.reading;
      var date = typeof raw.date === "string" ? raw.date.trim() : "";
      var time = typeof raw.time === "string" ? raw.time.trim() : "";

      if (readingRaw == null || date === "" || time === "") {
        invalid++;
        return;
      }

      var reading = normalizeReading(readingRaw);
      if (!/^\d{4}$/.test(reading)) {
        invalid++;
        return;
      }

      var createdAt =
        typeof raw.createdAt === "string" && raw.createdAt
          ? raw.createdAt
          : new Date().toISOString();

      var id = typeof raw.id === "string" && raw.id ? raw.id : generateId();
      var key = reading + "|" + date + "|" + time + "|" + createdAt;

      if (existingIds.has(id) || existingKeys.has(key)) {
        skipped++;
        return;
      }

      // 若剛好 id 撞到（理論上機率極低），重新產生一個新的 id
      while (existingIds.has(id)) {
        id = generateId();
      }

      records.push({
        id: id,
        reading: reading,
        date: date,
        time: time,
        createdAt: createdAt
      });
      existingIds.add(id);
      existingKeys.add(key);
      added++;
    });

    if (added > 0) {
      saveRecords(records);
      render();
    }

    var msg = "匯入完成：新增 " + added + " 筆";
    if (skipped > 0) msg += "，略過重複 " + skipped + " 筆";
    if (invalid > 0) msg += "，忽略格式錯誤 " + invalid + " 筆";
    importStatus.textContent = msg;
  }

  // ---------------------------------------------------------
  // 初始渲染
  // ---------------------------------------------------------
  render();

  function focusQuickInput() {
    if (document.activeElement === quickInput) return;
    try {
      quickInput.focus({ preventScroll: true });
    } catch (e) {
      quickInput.focus();
    }
  }

  // 讓輸入框在頁面載入後盡快取得焦點，方便手機使用者立刻輸入
  // （部分行動瀏覽器基於安全性限制，仍需使用者先點擊一下才會跳出鍵盤）
  window.addEventListener("load", function () {
    focusQuickInput();
  });

  // 行動瀏覽器只允許在使用者手勢期間開啟軟體鍵盤。
  document.addEventListener("pointerdown", function (e) {
    if (e.target.closest("button, a, input, select, textarea, label")) return;
    focusQuickInput();
  }, { passive: true });
})();
