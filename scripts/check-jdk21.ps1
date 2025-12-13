# Script to verify Java 21 is installed and Gradle is using Java 21
# Usage: Open powershell, cd to repo root and run: .\scripts\check-jdk21.ps1

Write-Host "--- Java version reported by 'java -version' ---"
try {
    java -version 2>&1 | ForEach-Object { Write-Host $_ }
} catch {
    Write-Host "Java not found on PATH." -ForegroundColor Yellow
}

Write-Host "\n--- Gradle version and Java used by Gradle (from android/gradlew.bat) ---"
Push-Location -Path "./android"
try {
    .\gradlew.bat -v 2>&1 | ForEach-Object { Write-Host $_ }
} catch {
    Write-Host "Could not run ./gradlew.bat - check that Gradle wrapper exists and you have rights to run it." -ForegroundColor Yellow
}

Write-Host "\n--- Gradle properties (android/gradle.properties) ---"
Get-Content -Path "./gradle.properties" | ForEach-Object { Write-Host $_ }

Write-Host "\n--- Recommendation ---"
Write-Host "If Java 21 is not installed, install a JDK 21 (Temurin/Adoptium recommended) and set JAVA_HOME to its path, or set org.gradle.java.home in android/gradle.properties to the JDK 21 installation directory." -ForegroundColor Cyan

Pop-Location
