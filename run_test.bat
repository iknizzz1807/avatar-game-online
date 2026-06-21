@echo off
REM Set the path to your Godot executable here if it's not in your PATH
REM For example: set GODOT_EXEC="C:\Program Files\Godot\Godot_v4.x-stable_win64.exe"
set GODOT_EXEC="C:\Users\ADMIN\OneDrive\Desktop\Godot_v4.6.1-stable_win64.exe"

echo Starting Go REST Server...
cd server
start "Go REST Server" cmd /c "go run . || pause"
cd ..

timeout /t 2 /nobreak >nul

echo Starting Godot Dedicated Server...
start "Godot Server" cmd /c "%GODOT_EXEC% --headless --server || pause"

timeout /t 2 /nobreak >nul

echo Starting Client 1...
start "Godot Client 1" cmd /c "%GODOT_EXEC% || pause"

echo Starting Client 2...
start "Godot Client 2" cmd /c "%GODOT_EXEC% || pause"

echo All processes started!
