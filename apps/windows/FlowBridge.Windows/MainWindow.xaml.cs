using System.Windows;
using System.Windows.Controls;
using FlowBridge.Windows.Models;
using FlowBridge.Windows.ViewModels;

namespace FlowBridge.Windows;

public partial class MainWindow : Window
{
    private readonly MainViewModel _viewModel = new();

    public MainWindow()
    {
        InitializeComponent();
        DataContext = _viewModel;
    }

    private void Navigate_Click(object sender, RoutedEventArgs args)
    {
        if (sender is not Button { Tag: string target }) return;
        OverviewPanel.Visibility = target == nameof(OverviewPanel) ? Visibility.Visible : Visibility.Collapsed;
        DevicesPanel.Visibility = target == nameof(DevicesPanel) ? Visibility.Visible : Visibility.Collapsed;
        PrivacyPanel.Visibility = target == nameof(PrivacyPanel) ? Visibility.Visible : Visibility.Collapsed;
        DiagnosticsPanel.Visibility = target == nameof(DiagnosticsPanel) ? Visibility.Visible : Visibility.Collapsed;
    }

    private void ToggleRunning_Click(object sender, RoutedEventArgs args) => _viewModel.ToggleRunning();

    private async void ConfigureFirewall_Click(object sender, RoutedEventArgs args) =>
        await _viewModel.ConfigureFirewallAsync();

    private async void PeerAction_Click(object sender, RoutedEventArgs args)
    {
        if (sender is not Button { DataContext: PeerDevice peer }) return;
        if (peer.IsTrusted)
        {
            await _viewModel.RemoveTrustAsync(peer);
            return;
        }
        if (peer.IsPairingPending) return;

        await _viewModel.StartPairingAsync(peer);
    }

    protected override void OnClosed(EventArgs args)
    {
        _viewModel.Dispose();
        base.OnClosed(args);
    }
}
