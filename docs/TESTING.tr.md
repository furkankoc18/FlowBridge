# FlowBridge 0.4.0 test planı

Bu planı yayın paketleriyle, mümkünse temiz kullanıcı hesaplarında uygula. Her testte iki cihazın da aynı sürüm olduğunu doğrula.

## 1. Paket ve kimlik doğrulama

1. GitHub Release sayfasındaki `.sha256` dosyasını indir.
2. macOS'ta `shasum -a 256 FlowBridge-macOS.dmg`, Windows'ta `Get-FileHash .\FlowBridge-Windows-x64-Setup.exe -Algorithm SHA256` çalıştır.
3. Sonucun yayınlanan checksum ile aynı olduğunu doğrula.
4. macOS DMG'den Applications'a sürükle; Windows Setup ile kur.
5. Dock ve taskbar/başlat menüsünde FlowBridge logosunun göründüğünü doğrula.

## 2. İzinler ve ağ

1. İki cihazı aynı güvenilir Wi-Fi/Ethernet ağına bağla. Misafir ağı veya istemci izolasyonu kullanma.
2. Mac'te Erişilebilirlik ve Giriş İzleme izinlerini ver; uygulamayı tamamen kapatıp aç.
   İmzasız uygulama yeni bir derlemeyle değiştirildiyse eski FlowBridge satırını iki izin listesinden kaldır, `/Applications/FlowBridge.app` dosyasını yeniden ekle ve uygulamayı aç.
3. Windows'ta ağ profilini Özel yap. Teşhis → Özel ağ izni ver düğmesine basıp yönetici onayını ver.
4. Teşhis ekranında keşif ve Mac izinlerinin hazır göründüğünü doğrula.

## 3. Keşif ve eşleştirme

1. FlowBridge'i iki cihazda aç. Cihazlar ekranında karşı cihaz en geç yaklaşık 5 saniye içinde görünmeli.
2. Yalnızca bir tarafta Eşleştir'e bas.
3. Diğer tarafta onay penceresi otomatik açılmalı; iki tarafta aynı altı haneli kod görünmeli.
4. İki tarafta onayla. İkisinde de “İki cihazda eşleşti” görünmeli.
5. Uygulamaları kapatıp aç; eşleşmenin korunmasını doğrula.
6. Bir tarafta Eşleşmeyi kaldır; diğer tarafta da eşleşmenin kalktığını doğrula.
7. Tekrar eşleştirip fare testlerine geç.

Not: macOS `0.3.x` geliştirme sürümünden `0.4.0` yayın kimliğine ilk geçişte Keychain ve uygulama kimliği değiştiği için bir kez yeniden eşleştirme gerekir.

## 4. Yön kombinasyonları

Aşağıdaki erişebildiğin kombinasyonları ayrı ayrı dene:

- Mac → Windows ve Windows → Mac
- Mac → Mac ve ters yön
- Windows → Windows ve ters yön

Mac–Windows eşinde Mac'in sağ kenarı Windows'a, Windows'un sol kenarı Mac'e geçer. Aynı-platform eşinde uygulamanın Genel Bakış ekranında söylediği kenarı kullan.

Her yönde şunları doğrula:

1. İşaretçiyi belirtilen kenardan kararlı biçimde it; hedef ekranda aynı yükseklikte görünmeli.
2. Hızlı/yavaş ve çapraz hareketlerde takılma veya çift hareket olmamalı.
3. Sol, sağ ve orta tıklama yalnızca hedefte çalışmalı; kaynakta tıklama olmamalı.
4. Dikey kaydırma yalnızca hedefte çalışmalı.
5. Hedefte geldiğin kenara geri it; imleç kaynak cihaza dönmeli.
6. Tekrar hedefe geçip kaynak bilgisayarın klavyesinde `Esc` bas; imleç kaynakta geri gelmeli.

## 5. Failsafe ve yaşam döngüsü

1. Fare uzaktayken hedef cihazın Wi-Fi'ını kapat. Kaynak kontrolü yaklaşık 500 ms içinde geri almalı.
2. Fare uzaktayken hedef FlowBridge'i kapat. Kaynak kontrolü yaklaşık 500 ms içinde geri almalı.
3. Bir tıklamayı basılı tutarken bağlantıyı kes. Hedefte tuş basılı kalmamalı.
4. “Paylaşımı durdur”u hedefte seç. Kaynaktan gelen hareket/tıklama uygulanmamalı.
5. Paylaşımı tekrar başlat; uygulamaları yeniden eşleştirmeden kullanım devam etmeli.
6. Kaynak uygulamayı yeniden başlat, hedefi açık bırak. Fare paketleri yeniden başlatma sonrasında kabul edilmeli.

## 6. Olumsuz testler

1. Farklı ağlardayken cihazların görünmediğini doğrula.
2. Kodlar farklıysa onaylama; iptal sonrası cihaz güvenilir olmamalı.
3. İkinci FlowBridge örneğini Windows'ta açmayı dene; uygulama zaten çalışıyor uyarısı çıkmalı.
4. Mac izinlerinden birini kapat; ortak fare etkinleşmemeli ve eksik izin görünmeli.

## 7. Sonuç kaydı

Her hata için kaynak/hedef işletim sistemi sürümünü, ekran ölçeklendirmesini, kablolu/kablosuz ağı, mouse modelini, izlenen adımları ve mümkünse ekran kaydını ekle. Cihaz kimliği, eşleştirme anahtarı veya kişisel veri paylaşma.
