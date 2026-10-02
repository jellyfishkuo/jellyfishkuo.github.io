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
  var toastEl = document.getElementById("toast");
  var toastTimer = null;
  var toastHideTimer = null;

  var historyList = document.getElementById("history-list");
  var recordCountEl = document.getElementById("record-count");
  var emptyMsg = document.getElementById("empty-msg");
  var dailyChart = document.getElementById("daily-chart");
  var monthlyChart = document.getElementById("monthly-chart");
  var dailyChartEmpty = document.getElementById("daily-chart-empty");
  var monthlyChartEmpty = document.getElementById("monthly-chart-empty");

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
      date: normalizeDate(r.date) || r.date,
      time: normalizeTime(r.time) || r.time,
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
      showToast("儲存失敗，裝置儲存空間可能已滿或瀏覽器不支援本機儲存。", { type: "error", duration: 4000 });
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

  function sortRecordsAsc(list) {
    return list.slice().sort(function (a, b) {
      var ka = sortKey(a);
      var kb = sortKey(b);
      return ka === kb
        ? (a.createdAt || "").localeCompare(b.createdAt || "")
        : ka < kb ? -1 : 1;
    });
  }

  /**
   * 兩次讀數之間用了幾度。電表只有 4 位數，9999 之後會回到 0000，
   * 所以「前一筆接近 9999、這一筆接近 0000」視為繞了一圈，而不是讀數變少。
   * 其他讀數變少的情況回傳負數，交給畫面提醒使用者確認。
   */
  var METER_MAX = 10000;
  function usageBetween(previous, current) {
    var diff = Number(current) - Number(previous);
    if (diff < 0 && Number(previous) >= 9000 && Number(current) < 1000) diff += METER_MAX;
    return diff;
  }

  /**
   * 每筆紀錄與「前一筆（依時間）」的差值，回傳 { id: 差值 }。
   * 第一筆沒有前一筆，不會出現在結果裡。
   */
  function getDiffMap() {
    var ascending = sortRecordsAsc(records);
    var map = {};
    for (var i = 1; i < ascending.length; i++) {
      map[ascending[i].id] = usageBetween(ascending[i - 1].reading, ascending[i].reading);
    }
    return map;
  }

  /** 新增一筆後，用來顯示在提示裡的說明文字 */
  function describeDiff(id) {
    var diff = getDiffMap()[id];
    if (diff === undefined) return { text: "（第一筆紀錄）", warn: false };
    if (diff < 0) return { text: "，比前一筆還少，請確認讀數", warn: true };
    return { text: "，比前一筆多用了 " + diff + " 度", warn: false };
  }

  // ---------------------------------------------------------
  // 提示（Toast）：顯示一段時間後自動消失
  // ---------------------------------------------------------

  /**
   * @param {string} message 要顯示的文字
   * @param {{type?: "success"|"warn"|"error", duration?: number, onHide?: Function}} opts
   */
  function showToast(message, opts) {
    opts = opts || {};
    clearTimeout(toastTimer);
    clearTimeout(toastHideTimer);

    toastEl.textContent = message;
    toastEl.className = "toast toast-" + (opts.type || "success");
    // 強制 reflow，讓連續觸發時動畫也能重新播放
    void toastEl.offsetWidth;
    toastEl.classList.add("show");

    toastTimer = setTimeout(function () {
      toastEl.classList.remove("show");
      // 等淡出動畫結束再執行後續動作（例如捲動到紀錄）
      toastHideTimer = setTimeout(function () {
        if (typeof opts.onHide === "function") opts.onHide();
      }, 250);
    }, opts.duration || 2000);
  }

  /** 捲動到指定紀錄，並短暫高亮 */
  function scrollToRecord(id) {
    var items = historyList.querySelectorAll(".history-item");
    var target = null;
    for (var i = 0; i < items.length; i++) {
      if (items[i].dataset.id === id) {
        target = items[i];
        break;
      }
    }
    if (!target) return;

    target.scrollIntoView({ behavior: "smooth", block: "center" });
    target.classList.remove("highlight");
    void target.offsetWidth;
    target.classList.add("highlight");
  }

  /** 新增紀錄成功後的共同流程：提示 → 提示消失 → 捲到該筆紀錄 */
  function announceNewRecord(record) {
    var info = describeDiff(record.id);
    showToast("已記錄 " + record.reading + info.text, {
      type: info.warn ? "warn" : "success",
      duration: info.warn ? 3000 : 2000,
      onHide: function () {
        scrollToRecord(record.id);
      }
    });
  }

  // ---------------------------------------------------------
  // 畫面渲染
  // ---------------------------------------------------------

  function render() {
    var sorted = sortRecordsDesc(records);
    var diffMap = getDiffMap();

    historyList.innerHTML = "";
    renderCharts();

    if (sorted.length === 0) {
      emptyMsg.classList.remove("hidden");
      recordCountEl.textContent = "";
    } else {
      emptyMsg.classList.add("hidden");
      recordCountEl.textContent = "（共 " + sorted.length + " 筆）";
    }

    sorted.forEach(function (r) {
      historyList.appendChild(buildHistoryItem(r, diffMap[r.id]));
    });
  }

  /** 'YYYY-MM-DD' + 'HH:MM' → 當地時間的 Date */
  function toLocalDate(date, time) {
    var d = date.split("-").map(Number);
    var t = time.split(":").map(Number);
    return new Date(d[0], d[1] - 1, d[2], t[0] || 0, t[1] || 0);
  }

  function dayKey(dt) {
    return dt.getFullYear() + "-" + pad2(dt.getMonth() + 1) + "-" + pad2(dt.getDate());
  }

  /**
   * 依日或月統計用電。兩次讀數之間的用電量，依經過的時間平均分到跨過的每一天，
   * 例如週一晚上和週三早上各抄一次，中間的度數會分給週一、週二、週三，
   * 而不是全部算在週一。
   */
  function getUsageByPeriod(periodLength) {
    var ascending = sortRecordsAsc(records);
    var usage = {};

    for (var i = 1; i < ascending.length; i++) {
      var used = usageBetween(ascending[i - 1].reading, ascending[i].reading);
      if (!Number.isFinite(used) || used < 0) continue;

      var start = toLocalDate(ascending[i - 1].date, ascending[i - 1].time);
      var end = toLocalDate(ascending[i].date, ascending[i].time);
      var span = end - start;
      if (!(span > 0)) {
        var key0 = dayKey(end);
        if (periodLength === "month") key0 = key0.slice(0, 7);
        usage[key0] = (usage[key0] || 0) + used;
        continue;
      }

      var cursor = start;
      while (cursor < end) {
        var nextDay = new Date(cursor.getFullYear(), cursor.getMonth(), cursor.getDate() + 1);
        var sliceEnd = nextDay < end ? nextDay : end;
        var key = dayKey(cursor);
        if (periodLength === "month") key = key.slice(0, 7);
        usage[key] = (usage[key] || 0) + used * (sliceEnd - cursor) / span;
        cursor = sliceEnd;
      }
    }

    return Object.keys(usage).sort().map(function (label) {
      return { label: label, value: usage[label] };
    }).slice(-12);
  }

  /** 圖表上的數字：整數就顯示整數，否則留一位小數 */
  function formatUsage(value) {
    var rounded = Math.round(value * 10) / 10;
    return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1);
  }

  function formatChartLabel(label, periodLength) {
    return periodLength === "month"
      ? label.slice(5) + "月"
      : label.slice(5).replace("-", "/");
  }

  function renderCharts() {
    var daily = getUsageByPeriod("day");
    var monthly = getUsageByPeriod("month");
    drawUsageChart(dailyChart, daily, "day", dailyChartEmpty);
    drawUsageChart(monthlyChart, monthly, "month", monthlyChartEmpty);
  }

  function drawUsageChart(canvas, data, periodLength, emptyMessage) {
    var context = canvas.getContext("2d");
    var scrollBox = canvas.parentElement;
    var height = 210;
    var padding = { top: 28, right: 18, bottom: 44, left: 34 };
    var minBarWidth = 44;
    var width = Math.max(scrollBox.clientWidth || 300, padding.left + padding.right + data.length * minBarWidth);
    var ratio = window.devicePixelRatio || 1;
    canvas.width = width * ratio;
    canvas.height = height * ratio;
    canvas.style.width = width + "px";
    canvas.style.height = height + "px";
    context.setTransform(ratio, 0, 0, ratio, 0, 0);
    context.clearRect(0, 0, width, height);

    if (data.length === 0) {
      canvas.classList.add("hidden");
      emptyMessage.classList.remove("hidden");
      return;
    }

    canvas.classList.remove("hidden");
    emptyMessage.classList.add("hidden");
    var maxValue = Math.max.apply(null, data.map(function (item) { return item.value; })) || 1;
    var plotWidth = width - padding.left - padding.right;
    var plotHeight = height - padding.top - padding.bottom;
    var barGap = 10;
    var barWidth = (plotWidth - barGap * (data.length - 1)) / data.length;
    var textColor = getComputedStyle(document.documentElement).getPropertyValue("--text-secondary");
    var primaryColor = getComputedStyle(document.documentElement).getPropertyValue("--primary");
    var borderColor = getComputedStyle(document.documentElement).getPropertyValue("--border");

    context.font = "12px sans-serif";
    context.textAlign = "center";
    context.strokeStyle = borderColor;
    context.lineWidth = 1;
    [0, 0.5, 1].forEach(function (step) {
      var gridY = padding.top + plotHeight - plotHeight * step;
      context.beginPath();
      context.moveTo(padding.left, gridY + 0.5);
      context.lineTo(width - padding.right, gridY + 0.5);
      context.stroke();
    });

    data.forEach(function (item, index) {
      var barHeight = item.value / maxValue * plotHeight;
      var x = padding.left + index * (barWidth + barGap);
      var y = padding.top + plotHeight - barHeight;
      context.fillStyle = primaryColor;
      var radius = Math.min(7, barWidth / 2, barHeight / 2);
      context.beginPath();
      context.moveTo(x + radius, y);
      context.arcTo(x + barWidth, y, x + barWidth, y + barHeight, radius);
      context.arcTo(x + barWidth, y + barHeight, x, y + barHeight, radius);
      context.arcTo(x, y + barHeight, x, y, radius);
      context.arcTo(x, y, x + barWidth, y, radius);
      context.fill();
      context.fillStyle = textColor;
      context.fillText(formatChartLabel(item.label, periodLength), x + barWidth / 2, height - 16);
      context.fillStyle = primaryColor;
      context.font = "bold 11px sans-serif";
      if (item.value >= 0.05) context.fillText(formatUsage(item.value), x + barWidth / 2, Math.max(14, y - 7));
      context.font = "12px sans-serif";
    });
  }

  window.addEventListener("resize", renderCharts);

  /** 使用 DOM API 建立節點，避免 innerHTML 字串拼接造成 XSS 風險 */
  function buildHistoryItem(r, diff) {
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

    if (diff !== undefined) {
      var diffEl = document.createElement("span");
      diffEl.className = "record-diff" + (diff < 0 ? " negative" : "");
      diffEl.textContent = diff < 0 ? "讀數變少？" : "+" + diff + " 度";
      readingEl.appendChild(diffEl);
    }

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
    if (quickInput.value.length === 4) handleQuickSave();
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
      quickInput.blur();
      announceNewRecord(record);
    } else {
      records.pop();
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
      announceNewRecord(record);
    } else {
      records.pop();
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

    var before = { reading: record.reading, date: record.date, time: record.time };
    record.reading = reading;
    record.date = date;
    record.time = time;

    if (saveRecords(records)) {
      var editedId = record.id;
      render();
      closeEditModal();
      showToast("已更新為 " + reading, {
        onHide: function () {
          scrollToRecord(editedId);
        }
      });
    } else {
      record.reading = before.reading;
      record.date = before.date;
      record.time = before.time;
    }
  });

  // 點擊 modal 外層背景可關閉編輯視窗
  editModal.addEventListener("click", function (e) {
    if (e.target === editModal) closeEditModal();
  });

  // 按 Esc 關閉任何開著的視窗
  document.addEventListener("keydown", function (e) {
    if (e.key !== "Escape") return;
    if (!editModal.classList.contains("hidden")) closeEditModal();
    if (!confirmModal.classList.contains("hidden")) closeConfirm();
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
      var previous = records;
      records = records.filter(function (r) {
        return r.id !== id;
      });
      if (saveRecords(records)) {
        render();
        showToast("已刪除這筆紀錄");
      } else {
        records = previous;
      }
    });
  }

  clearAllBtn.addEventListener("click", function () {
    if (records.length === 0) return;
    showConfirm("確定要清除「全部」紀錄嗎？此動作無法復原！", function () {
      var previous = records;
      records = [];
      if (saveRecords(records)) {
        render();
        showToast("已清除全部紀錄");
      } else {
        records = previous;
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
      showToast("目前沒有紀錄可以匯出", { type: "warn" });
      return;
    }
    var sorted = sortRecordsDesc(records);
    var json = JSON.stringify(sorted, null, 2);
    downloadBlob(
      json,
      "electricity-records-" + timestampForFilename() + ".json",
      "application/json"
    );
    showToast("已匯出 " + sorted.length + " 筆紀錄（JSON）");
  });

  exportCsvBtn.addEventListener("click", function () {
    if (records.length === 0) {
      showToast("目前沒有紀錄可以匯出", { type: "warn" });
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
    showToast("已匯出 " + sorted.length + " 筆紀錄（CSV）");
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
        showToast("匯入失敗，檔案格式無法辨識", { type: "error", duration: 3500 });
      } finally {
        // 清空 value，讓使用者可以重複選同一個檔案
        importFileInput.value = "";
      }
    };
    reader.onerror = function () {
      showToast("讀取檔案時發生錯誤", { type: "error", duration: 3500 });
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

  /**
   * CSV 用 Excel 開過再存檔，日期常會變成 2026/9/5、時間變成 8:05 或 08:05:00。
   * 這裡統一轉回 YYYY-MM-DD 與 HH:MM；不是合法日期時間就回傳空字串。
   */
  function normalizeDate(value) {
    var m = /^(\d{4})[-\/.](\d{1,2})[-\/.](\d{1,2})$/.exec(String(value == null ? "" : value).trim());
    if (!m) return "";
    var y = Number(m[1]), mo = Number(m[2]), d = Number(m[3]);
    var check = new Date(y, mo - 1, d);
    if (check.getFullYear() !== y || check.getMonth() !== mo - 1 || check.getDate() !== d) return "";
    return y + "-" + pad2(mo) + "-" + pad2(d);
  }

  function normalizeTime(value) {
    var m = /^(\d{1,2}):(\d{2})(?::\d{2})?$/.exec(String(value == null ? "" : value).trim());
    if (!m || Number(m[1]) > 23 || Number(m[2]) > 59) return "";
    return pad2(m[1]) + ":" + m[2];
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
      var date = normalizeDate(raw.date);
      var time = normalizeTime(raw.time);

      if (readingRaw == null || !date || !time) {
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
      if (!saveRecords(records)) {
        records = records.slice(0, records.length - added);
        return;
      }
      render();
    }

    var msg = "匯入完成：新增 " + added + " 筆";
    if (skipped > 0) msg += "，略過重複 " + skipped + " 筆";
    if (invalid > 0) msg += "，忽略格式錯誤 " + invalid + " 筆";
    showToast(msg, { duration: 3500, type: added > 0 ? "success" : "warn" });
  }

  // ---------------------------------------------------------
  // 初始渲染
  // ---------------------------------------------------------
  render();
})();
