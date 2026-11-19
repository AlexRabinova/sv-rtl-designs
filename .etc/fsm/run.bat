@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: CONFIGURABLE PATHS & SETTINGS
:: ==========================================
set "BUILD_DIR=sim_build"
set "PRJ_FILE=compile.prj"
set "TB_DIR=tb"

echo ==========================================
echo [1/4] Cleaning and preparing build folder...
echo ==========================================
if exist %BUILD_DIR% rmdir /s /q %BUILD_DIR%
mkdir %BUILD_DIR%
del /q *.log *.jou *.pb >nul 2>&1

:: Move into build directory
pushd %BUILD_DIR%

echo ==========================================
echo [2/4] Compiling with xvlog...
echo ==========================================
call xvlog -sv -prj ../%PRJ_FILE%
if %errorlevel% neq 0 goto error_pop

echo ==========================================
echo [3/4] Finding Testbench and Elaborating...
echo ==========================================
:: Automatically find the first .sv or .v file inside the ../tb folder to use as top-level
set "TB_TOP="
for %%f in ("..\!TB_DIR!\*.sv" "..\!TB_DIR!\*.v") do (
    if "!TB_TOP!"=="" set "TB_TOP=%%~nf"
)

if "%TB_TOP%"=="" (
    echo [ERROR] No testbench file found in the %TB_DIR% folder!
    goto error_pop
)

echo Detected Testbench Top-Level: %TB_TOP%
call xelab -debug typical %TB_TOP% -s %TB_TOP%_snapshot
if %errorlevel% neq 0 goto error_pop

echo ==========================================
echo [4/4] Running Simulation with xsim...
echo ==========================================
call xsim %TB_TOP%_snapshot -R
if %errorlevel% neq 0 goto error_pop

:: Return to project root
popd

echo.
echo ==========================================
echo SUCCESS: Simulation complete! Clean root folder.
echo ==========================================
goto end

:error_pop
popd

:error
echo.
echo [ERROR] Simulation flow failed!

:end
endlocal
pause