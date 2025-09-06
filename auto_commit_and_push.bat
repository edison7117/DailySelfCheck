@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM 切到這個 .bat 所在資料夾（建議放在 repo 根目錄）
cd /d "%~dp0"

REM 確認已安裝 Git
git --version >nul 2>&1
if errorlevel 1 (
  echo 找不到 Git，請先安裝 Git 並加入 PATH。
  exit /b 1
)

REM 1) 加入所有變更
git add -A

REM 沒有變更就跳過
git diff --cached --quiet
if %errorlevel%==0 (
  echo 沒有可提交的變更，跳過 commit。
  goto do_push
)

REM ===== Diff 內容設定 =====
REM 1 = 完整 diff；0 = 只輸出檔案摘要
set USE_FULL_DIFF=0
REM =========================

set "DIFF_FILE=%TEMP%\git_diff_%RANDOM%.txt"
set "MSG_FILE=%TEMP%\commit_msg_%RANDOM%.txt"

if "%USE_FULL_DIFF%"=="1" (
  git diff --cached > "%DIFF_FILE%"
) else (
  git diff --cached --name-status > "%DIFF_FILE%"
  echo.>> "%DIFF_FILE%"
  git diff --cached --shortstat >> "%DIFF_FILE%"
)

REM 組合 commit 訊息
set "TODAY=%DATE%"
set "NOW=%TIME%"

(
  echo Auto-commit on %TODAY% %NOW%
  echo.
  echo ==== Diff (staged changes) ====
  type "%DIFF_FILE%"
) > "%MSG_FILE%"

REM 2) commit
git commit -F "%MSG_FILE%"
if errorlevel 1 (
  echo commit 失敗。
  del "%DIFF_FILE%" "%MSG_FILE%" >nul 2>&1
  exit /b 1
)

:do_push
REM 3) push
echo 執行 git push...
git push
if errorlevel 1 (
  echo push 失敗，請檢查遠端設定或權限。
  del "%DIFF_FILE%" "%MSG_FILE%" >nul 2>&1
  exit /b 1
)

echo 完成。
del "%DIFF_FILE%" "%MSG_FILE%" >nul 2>&1
endlocal