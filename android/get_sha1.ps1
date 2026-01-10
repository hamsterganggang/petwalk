# SHA-1 Certificate Fingerprint Script
# This script retrieves SHA-1 fingerprints for debug and release keystores

$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Debug Keystore SHA-1 ===" -ForegroundColor Green
$debugKeyStore = "$env:USERPROFILE\.android\debug.keystore"
if (Test-Path $debugKeyStore) {
    Write-Host "Found debug keystore. Extracting SHA-1..." -ForegroundColor Yellow
    $result = keytool -list -v -keystore $debugKeyStore -alias androiddebugkey -storepass android -keypass android 2>&1
    $sha1Line = $result | Select-String "SHA1"
    if ($sha1Line) {
        Write-Host $sha1Line -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Copy the SHA-1 value above (the hex string after SHA1:)" -ForegroundColor Yellow
    } else {
        Write-Host "Could not find SHA1 in output. Full output:" -ForegroundColor Red
        Write-Host $result
    }
} else {
    Write-Host "Debug keystore not found at: $debugKeyStore" -ForegroundColor Red
    Write-Host "This is normal if you haven't built the app yet." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Release Keystore SHA-1 ===" -ForegroundColor Green
Write-Host "If you have a release keystore, run this command:" -ForegroundColor Yellow
Write-Host "keytool -list -v -keystore [keystore-path] -alias [alias-name]" -ForegroundColor White

Write-Host ""
Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Copy the SHA-1 value(s) from above" -ForegroundColor White
Write-Host "2. Go to Firebase Console > Project Settings > General tab" -ForegroundColor White
Write-Host "3. Select your Android app in 'Your apps' section" -ForegroundColor White
Write-Host "4. Click 'Add fingerprint' and add all SHA-1 values" -ForegroundColor White
Write-Host "5. Download the updated google-services.json and replace the file in android/app/" -ForegroundColor White
Write-Host ""
Write-Host "=== Alternative: Use Gradle ===" -ForegroundColor Cyan
Write-Host "You can also run: .\gradlew signingReport" -ForegroundColor Yellow
Write-Host "This will show SHA-1 for all build variants" -ForegroundColor White
