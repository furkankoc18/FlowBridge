# Güvenlik ve Gizlilik Analizi

> Bu belge hedef güvenlik gereksinimlerini içerir. Uygulanmış `0.4.0` güvenlik sınırları için `SECURITY.md` ve `docs/ARCHITECTURE.md` dosyalarına bakın.

## 1. Neden kritik?

FlowBridge klavye girişine, fareye, panoya ve dosyalara erişir. Bu yetkiler yanlış tasarlanırsa parola, özel mesaj, müşteri verisi veya dosya sızıntısına yol açabilir. Güvenlik sonradan eklenen bir özellik değil, ürünün kullanılabilmesinin ön şartıdır.

## 2. Tehdit modeli

### Korunacak varlıklar

- Klavye girişleri
- Pano içeriği
- Aktarılan dosyalar
- Cihaz kimlik anahtarları
- Eşleşmiş cihaz listesi
- Teşhis kayıtları

### Olası saldırganlar

- Aynı Wi-Fi ağındaki kötü niyetli cihaz
- Kullanıcının daha önce eşleştirdiği fakat artık güvenmediği cihaz
- Sahte FlowBridge istemcisi
- Dosya adı/yolu üzerinden alıcı sistemi hedefleyen saldırgan
- Güncelleme kanalını ele geçirmeye çalışan saldırgan

## 3. Güvenlik gereksinimleri

- Tüm oturumlar TLS 1.3 ile şifrelenmeli.
- Cihazlar yalnızca kullanıcı onaylı eşleştirme sonrasında güvenilir olmalı.
- Karşılıklı cihaz kimliği doğrulanmalı.
- Özel anahtarlar macOS Keychain ve Windows DPAPI/Credential Manager ile korunmalı.
- Uygulama, eşleşmemiş cihazdan gelen giriş olaylarını hiçbir zaman uygulamamalı.
- Güncelleme paketleri kod imzalı ve manifestoları kriptografik olarak doğrulanmış olmalı.
- Şifrelemeyi kapatma seçeneği sunulmamalı.
- Yerel ağ dışından bağlantı varsayılan olarak reddedilmeli.

## 4. Pano gizliliği

Varsayılan davranış:

- Pano yalnızca eşleşmiş ve bağlı cihaza aktarılır.
- Pano geçmişi diske yazılmaz.
- İçerik uygulama sunucularına gönderilmez.
- Belirli süre sonra aktarım belleği temizlenir.

Hassas içerik koruması:

- İşletim sisteminin “geçici/hassas pano” işaretleri destekleniyorsa bunlara uyulur.
- Kullanıcı parola yöneticilerini ve uygulamaları engel listesine ekleyebilir.
- Tek tıkla “10 dakika pano paylaşımını durdur” seçeneği bulunur.
- Büyük veya ikili pano içeriğinde karşı tarafta onay istenebilir.

İçeriği analiz eden yapay zekâ veya bulut tabanlı hassas veri tespiti MVP'de kullanılmamalı.

## 5. Dosya güvenliği

- Alıcı, varsayılan bir hedef klasör dışına yazmaya zorlanamaz.
- `../`, mutlak yol, UNC yolu ve aygıt yolu gibi kaçışlar reddedilir.
- Sembolik bağlantılar ilk sürümde kabul edilmez.
- Çalıştırılabilir dosyalarda işletim sisteminin karantina/itibar mekanizmaları korunur.
- Alıcıda yeterli disk alanı aktarım başlamadan kontrol edilir.
- Dosya tamamlanmadan gerçek adıyla görünmez.
- Hash doğrulaması başarısızsa dosya “başarılı” gösterilmez.

## 6. Güvenli hata davranışı

- Ağ koparsa fare ve klavye kontrolü anında yerel cihaza döner.
- Erişilebilirlik izni kaldırılırsa giriş yakalama güvenli biçimde durur.
- Uygulama çökerse işletim sistemi girişleri normal çalışmaya devam eder.
- Kullanıcı her zaman fiziksel klavyeden acil durdurma kombinasyonu kullanabilir.
- Oturum zaman aşımı, tekrar oynatma ve sıra dışı paket akışı korunmalıdır.

## 7. Log ve telemetri

Loglarda bulunmaması gerekenler:

- Basılan tuşlar
- Pano içeriği
- Dosya içeriği
- Tam yerel dosya yolları
- Kullanıcı adı ve hassas cihaz adı
- Özel anahtarlar veya oturum sırları

Ölçülebilecek anonim olaylar:

- Eşleştirme başarı/başarısızlık nedeni
- Bağlantı kurulma süresi
- Yeniden bağlantı sayısı
- Gecikme yüzdelikleri
- Dosya transferi başarı oranı ve boyut aralığı
- İzin sihirbazında terk edilen adım

Telemetri açık rızaya dayanmalı ve kapatılabilmelidir. Yerel teşhis paketi kullanıcı göndermeden cihazdan çıkmamalıdır.

## 8. Yayın öncesi güvenlik kapıları

- Bağımlılık ve lisans taraması
- Statik analiz ve secret taraması
- Protokol mesajlarına fuzz testi
- Dosya yolu ve arşiv açma testleri
- Eşleştirme ve anahtar değişimi için bağımsız güvenlik incelemesi
- macOS/Windows kod imzası doğrulaması
- Güncelleme kanalında rollback ve sahte paket testleri
- Haricî penetrasyon testi
