# Ürün ve Kullanıcı Analizi

> Bu belge ürün araştırmasıdır ve gelecek hedefleri içerir. Uygulanmış özellikler için kök `README.md` dosyasına bakın.

## 1. Problem

Birçok kullanıcı aynı masada hem Mac hem Windows bilgisayar kullanıyor. Her bilgisayar için ayrı klavye/fare kullanmak, fiziksel KVM düğmesine basmak veya dosyaları bulut/e-posta yoluyla taşımak çalışma akışını bölüyor.

Mevcut çözümlerden bazıları teknik kurulum gerektiriyor, bazıları yalnızca tek işletim sisteminde çalışıyor, bazıları belirli donanıma bağlı ve bazıları klavye/fare paylaşsa da dosya transferini desteklemiyor.

FlowBridge şu üç işi tek deneyimde birleştirir:

1. Klavye ve fare paylaşımı
2. Pano paylaşımı
3. Dosya ve klasör aktarımı

## 2. Hedef kullanıcılar

### Birincil persona: Mac + Windows kullanan profesyonel

- MacBook üzerinde iletişim, tasarım veya kişisel işler yapar.
- Windows masaüstünde geliştirme, kurumsal uygulama, oyun veya özel yazılım kullanır.
- İki cihazı aynı masada ve aynı ağda tutar.
- Teknik ayarlarla uğraşmadan imleci diğer ekrana geçirmek ister.

### İkincil persona: İçerik üreticisi ve yayıncı

- Bir bilgisayarda oyun veya render, diğerinde yayın/yönetim araçları çalıştırır.
- Dosya, bağlantı ve metinleri hızlı taşımak ister.
- Tam ekran uygulamalarda yanlışlıkla bilgisayar değiştirmek istemez.

### İkincil persona: Yazılımcı ve test uzmanı

- Farklı işletim sistemlerinde test yapar.
- Kod parçaları, ekran görüntüleri ve build çıktıları taşır.
- Klavye düzenlerinin ve kısayolların doğru çevrilmesine ihtiyaç duyar.

### Daha sonraki persona: Küçük teknik ekip

- Aynı çalışma alanındaki birden fazla cihazı yönetir.
- Merkezi ayar, cihaz politikası ve teşhis kaydı ister.
- Bu persona ilk MVP kapsamında değildir.

## 3. Yapılacak işler (Jobs to be Done)

- “Fareyi ekranın kenarına götürdüğümde diğer bilgisayara anında geçmek istiyorum.”
- “Mac'te kopyaladığım metni Windows'ta doğrudan yapıştırmak istiyorum.”
- “Bir klasörü diğer ekrana sürükleyerek göndermek istiyorum.”
- “Bilgisayar uyuyup uyandığında tekrar IP ayarı yapmak istemiyorum.”
- “Bağlantının neden çalışmadığını teknik log okumadan anlamak istiyorum.”
- “Parola yöneticisinden kopyaladığım şifrenin otomatik olarak diğer cihaza gitmesini istemiyorum.”

## 4. Değer önerisi

### Kullanıcıya verilen söz

İki bilgisayara kur, kodla eşleştir, ekranları yerleştir ve kullanmaya başla.

### Ürünün duygusal faydası

İki ayrı bilgisayar, kullanıcının gözünde tek ve kesintisiz bir çalışma alanına dönüşür.

### Ürünün işlevsel faydası

- Masa üzerindeki donanım kalabalığı azalır.
- Bağlam değiştirme süresi kısalır.
- Küçük dosyalar için bulut, mesajlaşma veya USB bellek ihtiyacı azalır.

## 5. Ürün ilkeleri

1. **Bağlanmak görünmez olmalı:** İlk kurulumdan sonra manuel IP girişi gerekmemeli.
2. **Güvenlik varsayılan olmalı:** Şifreleme açılan bir seçenek değil, temel davranış olmalı.
3. **Hatalar insan dilinde olmalı:** Hata kodu yerine çözüm gösterilmeli.
4. **Fare hissi kusursuz olmalı:** Gecikmeli fare, çok özellikli üründen daha büyük başarısızlıktır.
5. **Yerel öncelikli olmalı:** Hesap açmadan ve bulut servisi olmadan LAN üzerinde çalışmalı.
6. **İzinler açıklanmalı:** İşletim sistemi izinlerinin neden istendiği kurulurken gösterilmeli.

## 6. Başarı ölçütleri

### Aktivasyon

- Yeni kullanıcıların en az %80'i iki cihazı 3 dakika içinde eşleştirebilmeli.
- Eşleşen kullanıcıların en az %90'ı ilk fare geçişini gerçekleştirebilmeli.

### Kalite

- Normal LAN koşullarında giriş gecikmesi medyanı 15 ms altında hedeflenmeli.
- Uyku/uyanma veya Wi-Fi değişiminden sonra 10 saniye içinde otomatik bağlantı hedeflenmeli.
- Dosya aktarımında uçtan uca hash doğrulaması zorunlu olmalı.

### Kullanım

- Haftalık aktif kullanıcı başına en az 3 aktif gün.
- Kurulumdan 7 gün sonra kullanıcıların en az %35'inin ürünü çalıştırmaya devam etmesi.

Bu değerler ürün hipotezidir; beta verisiyle güncellenecektir.

## 7. Kapsam dışı işler

- Ekran görüntüsü veya uzaktan masaüstü aktarımı
- Bilgisayarı internet üzerinden teknik destek amacıyla kontrol etme
- Mobil cihazı ikinci ekran yapma
- Oyun kumandası veya ses aktarımı
- İlk sürümde Linux desteği
- İlk sürümde üçten fazla bilgisayar düzeni
