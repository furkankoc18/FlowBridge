using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace FlowBridge.Windows.Models;

public sealed class PeerDevice : INotifyPropertyChanged
{
    private bool _isTrusted;
    private bool _isPairingPending;

    public required string Id { get; init; }
    public required string Name { get; set; }
    public required string Platform { get; set; }
    public required string ServiceName { get; set; }

    public bool IsTrusted
    {
        get => _isTrusted;
        set
        {
            if (_isTrusted == value) return;
            _isTrusted = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(Status));
            OnPropertyChanged(nameof(ActionTitle));
        }
    }

    public bool IsPairingPending
    {
        get => _isPairingPending;
        set
        {
            if (_isPairingPending == value) return;
            _isPairingPending = value;
            OnPropertyChanged();
            OnPropertyChanged(nameof(Status));
            OnPropertyChanged(nameof(ActionTitle));
        }
    }

    public string Status => IsTrusted
        ? "İki cihazda eşleşti"
        : IsPairingPending
            ? "Karşı cihazın onayı bekleniyor"
            : $"Yeni cihaz · {Platform}";
    public string ActionTitle => IsTrusted
        ? "Eşleşmeyi kaldır"
        : IsPairingPending ? "Onay bekleniyor" : "Eşleştir";

    public event PropertyChangedEventHandler? PropertyChanged;

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
