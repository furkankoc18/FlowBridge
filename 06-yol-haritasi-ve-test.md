# Yol Haritası ve Test Planı

> Bu belge uzun vadeli yol haritasıdır. Güncel elle test adımları için `docs/TESTING.tr.md` dosyasına bakın.

## 1. Gerçekçi geliştirme sırası

Çok sayıda özelliği aynı anda geliştirmek yerine önce fare/klavye hissi ve bağlantı güvenilirliği kanıtlanmalıdır.

### Faz 0 — Problem doğrulama (2 hafta)

- 10–15 Mac + Windows kullanıcısıyla görüşme
- Kullandıkları mevcut çözümü ve bırakma nedenlerini öğrenme
- Kurulum videosu veya tıklanabilir prototiple değer önerisini test etme
- Ücret ödeme isteğini değil, mevcut problemi çözmek için harcadıkları zamanı ölçme

Çıkış kriteri:

- En az 8 kullanıcı problemi son bir ay içinde yaşamış olmalı.
- En az 5 kullanıcı prototipi kendi cihazlarında denemeyi kabul etmeli.

### Faz 1 — Teknik risk prototipi (3–5 hafta)

- macOS giriş yakalama
- Windows giriş üretme
- Ters yön
- LAN üzerinde basit bağlantı
- Sağ/sol ekran geçişi
- Bağlantı kopunca yerel kontrole dönüş

Bu sürümde güzel arayüz, dosya aktarımı ve otomatik güncelleme yapılmaz.

Çıkış kriteri:

- 30 dakikalık kullanımda kontrol kaybı olmaması
- Medyan giriş gecikmesinin hedef donanımda 15 ms altında olması
- Wi-Fi kesildiğinde yerel girişin 500 ms içinde geri dönmesi

### Faz 2 — Alpha (4–6 hafta)

- Cihaz keşfi
- Güvenli eşleştirme
- Kalıcı cihaz kimliği
- Ekran düzeni arayüzü
- Temel pano paylaşımı
- İzin sihirbazı
- Menü çubuğu ve sistem tepsisi

Çıkış kriteri:

- Beş test kullanıcısının yardım almadan eşleştirme yapabilmesi
- Uyku/uyanma sonrası otomatik bağlantı
- En az iki macOS ve iki Windows sürümünde günlük kullanım

### Faz 3 — Private beta (5–7 hafta)

- Dosya ve klasör aktarımı
- Devam ettirme ve hash doğrulaması
- İnsan dilinde teşhis
- Otomatik güncelleme
- İmzalı ve noter onaylı paketler
- Çökme raporlama ve açık rızalı anonim ölçüm

Çıkış kriteri:

- 20 beta kullanıcısında en az iki haftalık kullanım
- Kritik veri kaybı olmaması
- Dosya aktarım başarı oranının %99 üzerinde olması
- Eşleştirme başarı oranının %90 üzerinde olması

### Faz 4 — Public beta ve v1 (4–6 hafta)

- Kurulum akışı iyileştirmeleri
- Türkçe ve İngilizce arayüz
- Erişilebilirlik kontrolleri
- Dokümantasyon ve destek akışı
- Güvenlik incelemesi
- Ücretlendirme deneyi

Toplam tahmin: tam zamanlı küçük bir ekip için yaklaşık 4–6 ay. Tek geliştiriciyle donanım testi ve platform uzmanlığına bağlı olarak daha uzun sürebilir.

## 2. Test matrisi

### macOS

- Apple Silicon: M1, M2/M3 veya daha yeni bir cihaz
- En az macOS 13 ve güncel macOS sürümü
- Tek ve çift monitör
- Retina ve haricî 1080p/4K ekran
- Wi-Fi ve Ethernet
- Türkçe Q ve US klavye

### Windows

- Windows 10 22H2
- Windows 11 güncel kararlı sürüm
- x64; ARM64 daha sonraki aşamada
- %100, %125, %150 ve %200 ekran ölçekleri
- Tek ve çift monitör
- Yönetici ve standart kullanıcı hesabı

### Çevre birimleri

- Standart USB klavye/fare
- Bluetooth klavye/fare
- Apple Magic Keyboard/Trackpad
- Logitech mouse
- Yüksek polling rate oyuncu mouse'u
- Yatay kaydırmalı cihaz

### Ağ

- Aynı Wi-Fi erişim noktası
- Mac Wi-Fi / Windows Ethernet
- IP değişimi
- Uyku/uyanma
- Paket kaybı: %1, %5, %10
- Gecikme: 10, 50, 100 ms
- Ağ geçişi ve kısa süreli kopma
- İstemci izolasyonu açık misafir ağı
- Firewall port engeli

## 3. Otomatik testler

- Protokol kodlama/çözme testleri
- Farklı sürümler arası uyumluluk testleri
- Durum makinesi property testleri
- Ağ kesintisi ve paket sıralama testleri
- Dosya aktarımı bütünlük testleri
- Path traversal ve bozuk manifesto testleri
- Klavye düzeni dönüşüm tabloları
- DPI/koordinat dönüşümü testleri
- Uzun süreli soak test: 8, 24 ve 72 saat

## 4. Manuel kritik senaryolar

1. Fare Mac'ten Windows'a geçerken ağ kablosunu çıkar.
2. Uzak cihaz kontrol edilirken uygulamayı zorla kapat.
3. macOS Accessibility iznini çalışma sırasında kaldır.
4. 10 GB klasör aktarırken Wi-Fi'yi kapatıp aç.
5. Aynı isimli dosyayı iki kez gönder.
6. Kaynak bilgisayarı uyut ve tekrar aç.
7. Farklı klavye düzenlerinde özel karakterleri yaz.
8. Tam ekran oyun sırasında kenara hızlı hareket et.
9. Bir saldırgan cihazın eşleştirme olmadan paket göndermesini dene.
10. Eski istemciyle yeni protokol sürümünü bağlamayı dene.

## 5. Ekip ihtiyacı

Minimum ideal ekip:

- 1 Rust/ağ ve protokol geliştiricisi
- 1 macOS/Swift geliştiricisi
- 1 Windows geliştiricisi
- Yarı zamanlı ürün tasarımcısı
- Beta aşamasında güvenlik danışmanı ve QA desteği

Tek geliştiriciyle başlanabilir; bu durumda ilk hedef iki yönlü tam ürün değil, Mac ana cihaz → Windows istemci şeklinde daraltılmalıdır.
