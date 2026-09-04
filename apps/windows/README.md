# FlowBridge for Windows 0.4.0

## Kurulum

Kurulum için `FlowBridge-Windows-x64-Setup.exe`, taşınabilir kullanım için ZIP içindeki `FlowBridge.exe` dosyasını kullanın. Windows 10/11 x64 desteklenir ve ayrıca .NET kurulumu gerekmez.

İmzasız topluluk paketinde SmartScreen uyarısı çıkabilir. Yalnızca paketi güvenilir GitHub Release kaynağından indirip SHA-256 değerini doğruladıysanız **Ek bilgi → Yine de çalıştır** seçeneğini kullanın.

FlowBridge'te **Teşhis → Özel ağ izni ver** seçeneğine basın ve yönetici onayını tamamlayın. Kural yalnızca bu uygulamaya, Özel ağ profilinde UDP `5353`, `45874` ve `45875` portları için gelen bağlantı izni verir.

## Eşleştirme ve fare geçişi

İki cihaz aynı güvenilir yerel ağdayken FlowBridge'i ikisinde de açın. Cihazlar ekranında yalnızca bir tarafta **Eşleştir** deyin. Otomatik açılan iki penceredeki altı haneli kod aynıysa iki tarafta da onaylayın.

Mac–Windows eşinde Mac sağ kenardan Windows'a, Windows sol kenardan Mac'e geçer. Windows–Windows eşinde iki cihaz, tamamlayıcı sol/sağ kenarları otomatik seçer. Hedefte geldiğiniz kenara geri itmek kontrolü kaynağa döndürür. Kaynak Windows klavyesindeki global `Esc` acil dönüş kısayoludur.

Hareket, tıklama ve kaydırma AES-256-GCM ile doğrulanır. Eşleştirme anahtarı geçerli olmadan olay uygulanmaz. Anahtarlar Windows DPAPI ile mevcut kullanıcıya bağlı şekilde korunur. Ağ/uygulama kesilirse heartbeat failsafe yaklaşık 500 ms içinde yerel fare kontrolünü geri verir.

Pano, dosya ve klavye paylaşımı 0.4.0 sürümünde uygulanmamıştır.

## Kaynaktan derleme

.NET 8 SDK ile depo kökünde:

```powershell
dotnet run --project .\apps\windows\FlowBridge.Windows.CoreTests\FlowBridge.Windows.CoreTests.csproj -c Release
.\scripts\build-windows.ps1
```

Kurulum EXE'si için Inno Setup 6 kurduktan sonra:

```powershell
& "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" .\installer\FlowBridge.iss
```
