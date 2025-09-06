@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

echo === Step 0: 切換到腳本所在資料夾 ===
cd /d "%~dp0"
echo 當前路徑: %CD%

echo === Step 1: 檢查 Git 與版本庫 ===
git --version || (echo [錯誤] 未安裝 Git 或未加入 PATH。& exit /b 1)
git rev-parse --is-inside-work-tree >nul 2>&1 || (
  echo [錯誤] 這不是一個 Git 版本庫。請把 .bat 放在 repo 根目錄或在 repo 內執行。
  exit /b 1
)

for /f "tokens=*" %%i in ('git rev-parse --abbrev-ref HEAD') do set BR=%%i
if /I "!BR!"=="HEAD" (
  echo [錯誤] 目前是 detached HEAD（沒有在任何分支）。請切回分支後再執行。
  exit /b 1
)
echo 當前分支: !BR!

echo === Step 2: 新增所有變更到暫存 ===
git add -A

echo 目前變更（簡要）:
git status -s

echo === Step 3: 檢查是否有可提交的變更（staged）===
git diff --cached --quiet
if %errorlevel%==0 (
  echo [訊息] 暫存區沒有變更可提交。
  goto maybe_push
)

echo === Step 4: 產生 commit 訊息（含 diff 摘要，避免過長）===
set "DIFF_FILE=%TEMP%\git_diff_%RANDOM%.txt"
set "MSG_FILE=%TEMP%\commit_msg_%RANDOM%.txt"

REM 只寫入 name-status + shortstat，比較精簡
git diff --cached --name-status > "%DIFF_FILE%"
echo.>> "%DIFF_FILE%"
git diff --cached --shortstat >> "%DIFF_FILE%"

(
  echo Auto-commit on %DATE% %TIME% ^(branch: !BR!^)
  echo.
  echo ==== Diff (staged changes) ====
  type "%DIFF_FILE%"
) > "%MSG_FILE%"

echo 產生的 commit 訊息預覽:
type "%MSG_FILE%"

echo === Step 5: 提交 ===
git commit -F "%MSG_FILE%" || (
  echo [錯誤] commit 失敗。
  del "%DIFF_FILE%" "%MSG_FILE%" >nul 2>&1
  exit /b 1
)

del "%DIFF_FILE%" "%MSG_FILE%" >nul 2>&1

:maybe_push
echo === Step 6: 確認遠端與上游分支 ===
for /f "tokens=1" %%r in ('git remote') do set REMOTE=%%r
if not defined REMOTE (
  echo [錯誤] 沒有設定任何遠端（remote）。請先執行：git remote add origin <URL>
  exit /b 1
)
echo 使用遠端: !REMOTE!

REM 嘗試讀取 upstream，如果沒有就待會 push -u
set UPSTREAM_OK=1
git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>&1 || set UPSTREAM_OK=0

echo === Step 7: 決定是否需要推送 ===
REM 如果沒有 commit，但本地已經 ahead 也要 push；反之沒 ahead 就不必
for /f "tokens=* delims=" %%s in ('git status -sb') do set STATUS_LINE=%%s
echo 狀態: !STATUS_LINE!

echo !STATUS_LINE! | findstr /C:"ahead" >nul
if errorlevel 1 (
  echo [訊息] 沒有東西需要推送（本地沒有超前遠端）。
  goto done
)

echo === Step 8: 推送 ===
if "!UPSTREAM_OK!"=="1" (
  echo 執行：git push
  git push || (echo [錯誤] push 失敗，請檢查權限/網路/保護規則。& exit /b 1)
) else (
  echo 未設定上游分支，執行：git push -u !REMOTE! !BR!
  git push -u "!REMOTE!" "!BR!" || (echo [錯誤] push 失敗，請檢查遠端 URL 或權限。& exit /b 1)
)

:done
echo === 完成 ===
endlocal