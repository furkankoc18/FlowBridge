# MVP Kapsamı ve Gereksinimler

> Bu belge hedef kapsamı anlatır; tamamlanmış özellik listesi değildir. Güncel sürüm durumu için kök `README.md` dosyasına bakın.

## 1. MVP hedefi

Mac ve Windows bilgisayarı üç dakika içinde eşleştirip, tek klavye/fare kullanımı ile güvenli dosya aktarımını günlük kullanıma uygun kalitede sunmak.

## 2. Temel kullanıcı akışı

1. Kullanıcı uygulamayı Mac ve Windows'a kurar.
2. Her iki cihazda kısa bir izin ve güvenlik açıklaması görür.
3. Cihazlar mDNS üzerinden birbirini bulur.
4. Bir cihazda çıkan QR/kısa kod diğer cihazda onaylanır.
5. Kullanıcı cihaz kartlarını solda/sağda olacak şekilde sürükler.
6. Test ekranında fareyi diğer cihaza geçirir.
7. FlowBridge menü çubuğu/sistem tepsisine küçülür ve açılışta çalışır.
8. Kullanıcı metin kopyalar veya dosyayı ekran kenarındaki gönderim alanına bırakır.

## 3. P0 — Yayın için zorunlu özellikler

### Kurulum ve izinler

- İmzalı macOS DMG/PKG ve Windows yükleyici
- macOS Accessibility ve Input Monitoring izin sihirbazı
- Windows Firewall kuralının açık ve kontrollü biçimde oluşturulması
- Uygulamanın girişte otomatik başlatılabilmesi
- Güncelleme mekanizması

### Cihaz keşfi ve eşleştirme

- Aynı ağdaki cihazları mDNS/DNS-SD ile bulma
- Cihaz adı, işletim sistemi ve bağlantı kalitesini gösterme
- Kısa kodla karşılıklı eşleştirme
- Her cihaz için kalıcı kimlik anahtarı
- Eşleşmeyi iki taraftan da kaldırma

### Klavye ve fare

- Fare hareketi, tıklama, tekerlek ve yatay kaydırma
- Temel klavye tuşları ve tuş basılı tutma
- Mac `Command` / Windows `Ctrl` için varsayılan eşleme
- Kullanıcının cihazları sağ/sol yerleştirmesi
- Ekran kenarında geçiş gecikmesi ve köşe engeli ayarı
- Tam ekran oyun/uygulama sırasında geçişi kilitleme kısayolu
- Acil durumda kontrolü yerel bilgisayara döndüren güvenli kısayol

### Pano

- Düz metin ve zengin metin
- Tek görsel
- Pano boyutu sınırı
- Pano paylaşımını geçici kapatma
- Parola yöneticileri için hassas pano engelleme altyapısı

### Dosya ve klasör aktarımı

- Tek veya çoklu dosya
- Klasör aktarımı
- Aktarım ilerlemesi, hız ve kalan süre
- İptal ve devam ettirme
- Aynı isimli dosya için sor/üzerine yaz/yeniden adlandır seçenekleri
- Aktarım sonunda SHA-256 doğrulaması
- Varsayılan indirilenler klasörü ve her seferinde sor seçeneği

### Teşhis

- İzin eksikliği tespiti
- Firewall/port erişimi testi
- Aynı ağda olup olmadığını gösterme
- TLS/eşleştirme hatasını kullanıcı dilinde açıklama
- Kişisel veri temizlenmiş teşhis paketi dışa aktarma

## 4. P1 — MVP sonrasındaki özellikler

- Üç veya daha fazla bilgisayar
- Çok monitörlü karmaşık ekran yerleşimi
- Pano geçmişi
- Kişiselleştirilebilir tuş eşlemeleri
- Ağ profiline göre farklı masa düzenleri
- Ethernet ile Wi-Fi arasında kesintisiz geçiş
- Dosyayı doğrudan açık klasöre sürükleyip bırakma
- Otomatik kalite ölçümü ve bağlantı yolu seçimi

## 5. P2 — Daha sonraki fırsatlar

- Linux desteği
- İnternet üzerinden uçtan uca şifreli relay
- iPad/Android yardımcı istemcisi
- Merkezi ekip yönetimi
- Politika dağıtımı ve cihaz envanteri
- USB bağlantısını ağ alternatifi olarak kullanma
- Ses veya özel çevre birimi paylaşımı

## 6. Fonksiyonel kabul kriterleri

### Eşleştirme

- Yeni iki cihaz aynı ağdaysa 10 saniye içinde birbirini listeler.
- Kullanıcı bir tarafta eşleştirmeyi reddederse bağlantı kurulmaz.
- Daha önce eşleşmemiş istemciden gelen giriş olayları işlenmez.
- IP adresi değişse de cihaz kimliği korunur.

### Fare geçişi

- İmleç tanımlı ekran kenarını geçtiğinde kontrol hedef cihaza aktarılır.
- Bağlantı koparsa kontrol en geç 500 ms içinde yerel cihaza döner.
- Kullanıcı tanımlı acil dönüş kısayolu her zaman yerel olarak yakalanır.
- Farklı DPI/ölçek oranlarında koordinat dönüşümü ekran sınırını aşmaz.

### Dosya aktarımı

- Alıcı açıkça eşleşmiş değilse dosya kabul edilmez.
- Yarım kalan aktarım, dosya parçası doğrulanarak devam eder.
- Hash uyuşmazsa dosya tamamlandı olarak gösterilmez.
- Dosya yolu alıcı tarafından normalize edilir; kaynak cihaz alıcıda keyfî konum yazamaz.

## 7. İlk sürümde yapılmayacaklar

- Uzak masaüstü ve ekran görüntüsü
- Kullanıcı hesabı zorunluluğu
- Bulutta pano veya dosya saklama
- İşletim sistemi kilit ekranında tam kontrol
- Yönetici izni olmadan güvenlik kontrollerini aşma
- Şifreleme kapatma seçeneği
