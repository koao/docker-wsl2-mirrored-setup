@echo off
wsl -d Docker --exec docker info >nul 2>&1 && goto :ready
echo Starting Docker distro... 1>&2
start "" /b wsl -d Docker -- sh -c "exec sleep infinity"
wsl -d Docker --exec sh -c "while ! docker info >/dev/null 2>&1; do sleep 0.5; done"
:ready
setlocal enabledelayedexpansion
set "ARGS="
set "NEXT_IS_VOL=0"
:parse
if "%~1"=="" goto :run
set "ARG=%~1"

rem -v VALUE / --volume VALUE (スペース区切り)
if "%ARG%"=="-v" (
    set "NEXT_IS_VOL=1"
    set "ARGS=!ARGS! -v"
    shift
    goto :parse
)
if "%ARG%"=="--volume" (
    set "NEXT_IS_VOL=1"
    set "ARGS=!ARGS! --volume"
    shift
    goto :parse
)

rem -v=VALUE (=区切り)
if not "!ARG:~0,3!"=="-v=" goto :not_short_eq
set "VOL=!ARG:~3!"
call :convert_vol
set "ARGS=!ARGS! -v=!VOL!"
shift
goto :parse
:not_short_eq

rem --volume=VALUE (=区切り)
if not "!ARG:~0,9!"=="--volume=" goto :not_long_eq
set "VOL=!ARG:~9!"
call :convert_vol
set "ARGS=!ARGS! --volume=!VOL!"
shift
goto :parse
:not_long_eq

rem 直前が -v / --volume だった場合、この引数をボリューム値として変換
if not "!NEXT_IS_VOL!"=="1" goto :not_vol
set "NEXT_IS_VOL=0"
set "VOL=%~1"
call :convert_vol
set "ARGS=!ARGS! !VOL!"
shift
goto :parse
:not_vol

set "ARGS=!ARGS! %1"
shift
goto :parse

:run
wsl -d Docker --cd "%cd%" --exec docker !ARGS!
goto :eof

rem --- ボリュームマウントパスの変換サブルーチン ---
rem VOL 変数を読み取り、Windows パスなら /mnt/x/... 形式に変換して VOL に書き戻す
:convert_vol
rem 2文字目が : でなければ名前付きボリュームなので変換しない
set "SECOND_CHAR=!VOL:~1,1!"
if not "!SECOND_CHAR!"==":" goto :eof
rem ドライブレターを取得して小文字化
set "DRIVE=!VOL:~0,1!"
for %%L in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    if /i "!DRIVE!"=="%%L" set "DRIVE=%%L"
)
rem C: 以降を取得 (C:\foo... → \foo..., C:/foo... → /foo...)
set "REST=!VOL:~2!"
rem バックスラッシュをスラッシュに変換 (\foo... → /foo...)
set "REST=!REST:\=/!"
rem /mnt/x/... 形式に組み立て
set "VOL=/mnt/!DRIVE!!REST!"
goto :eof
