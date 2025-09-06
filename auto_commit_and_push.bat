@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

echo === Step 0: 切換到腳本所在資料夾 ===
cd /d "%~dp0"
echo 當前路徑: %CD%

echo === Step 1: 檢查 Git 與版本庫 ===
git --version || (echo [錯誤] 未安裝 Git 或未加入 PATH。& exit /b 1)
git rev-parse --is-inside-work-tree >nul 2>&1 || (
  echo [錯誤] 這不是 Git 版本庫。請在 repo 根目錄執行。
  exit /b 1
)

for /f "tokens=*" %%i in ('git rev-parse --abbrev-ref HEAD') do set BR=%%i
if /I "!BR!"=="HEAD" (
  echo [錯誤] 目前是 detached HEAD。請切回分支後再執行。
  exit /b 1
)
echo 當前分支: !BR!

echo === Step 2: 新增所有變更到暫存 ===
git add -A

echo 目前變更（簡要）:
git status -s

echo === Step 3: 檢查是否有可提交的變更 ===
git diff --cached --quiet
if %errorlevel%==0 (
  echo [訊息] 沒有可提交的變更。
  goto maybe_push
)

echo === Step 4: 產生 commit 訊息（限制 100 字） ===
set "SUMMARY="

for /f "delims=" %%s in ('git diff --cached --name-status') do (
  set "SUMMARY=!SUMMARY! %%s;"
)

REM 加上統計資訊
for /f "delims=" %%s in ('git diff --cached --shortstat') do (
  set "SUMMARY=!SUMMARY! %%s"
)

REM 加上時間戳
set "PREFIX=Auto-commit on %DATE% %TIME% (branch: %BR%) -"
set "FULL_MSG=!PREFIX! !SUMMARY!"

REM 截斷到 100 字
set "COMMIT_MSG=!FULL_MSG:~0,100!"

echo 使用 commit 訊息:
echo !COMMIT_MSG!

echo === Step 5: 提交 ===
git commit -m "!COMMIT_MSG!"
if errorlevel 1 (
  echo [錯誤] commit 失敗。
  exit /b 1
)

:maybe_push
echo === Step 6: 確認遠端並推送 ===
for /f "tokens=1" %%r in ('git remote') do set REMOTE=%%r
if not defined REMOTE (
  echo [錯誤] 沒有設定遠端 remote。請先：git remote add origin <URL>
  exit /b 1
)
echo 使用遠端: !REMOTE!

set UPSTREAM_OK=1
git rev-parse --abbrev-ref --symbolic-full-name @{u} >nul 2>&1 || set UPSTREAM_OK=0

echo 狀態檢查...
for /f "tokens=* delims=" %%s in ('git status -sb') do set STATUS_LINE=%%s
echo !STATUS_LINE!

echo !STATUS_LINE! | findstr /C:"ahead" >nul
if errorlevel 1 (
  echo [訊息] 沒有東西需要推送。
  goto done
)

if "!UPSTREAM_OK!"=="1" (
  echo 執行：git push
  git push || (echo [錯誤] push 失敗。& exit /b 1)
) else (
  echo 未設定上游，執行：git push -u !REMOTE! !BR!
  git push -u "!REMOTE!" "!BR!" || (echo [錯誤] push 失敗。& exit /b 1)
)

:done
echo === 完成 ===
endlocal
