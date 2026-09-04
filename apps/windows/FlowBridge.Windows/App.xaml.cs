using System.Windows;
using System.Threading;

namespace FlowBridge.Windows;

public partial class App : Application
{
    private Mutex? _singleInstance;
    private bool _ownsSingleInstance;

    protected override void OnStartup(StartupEventArgs e)
    {
        _singleInstance = new Mutex(true, "Local\\FlowBridge.Desktop.SingleInstance", out var created);
        _ownsSingleInstance = created;
        if (!created)
        {
            MessageBox.Show(
                "FlowBridge zaten çalışıyor.",
                "FlowBridge",
                MessageBoxButton.OK,
                MessageBoxImage.Information
            );
            Shutdown();
            return;
        }
        base.OnStartup(e);
        new MainWindow().Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (_ownsSingleInstance) _singleInstance?.ReleaseMutex();
        _singleInstance?.Dispose();
        base.OnExit(e);
    }
}
