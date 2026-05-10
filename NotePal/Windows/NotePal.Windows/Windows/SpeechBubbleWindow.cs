using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Shapes;
using System.Windows.Threading;

namespace NotePalWindows.Windows;

public sealed class SpeechBubbleWindow : Window
{
    private readonly DispatcherTimer _dismissTimer = new();
    private Action? _clickAction;
    private Action<bool>? _dismissed;
    private bool _completed;

    public SpeechBubbleWindow()
    {
        Title = "NotePal 提醒";
        Width = 260;
        Height = 76;
        WindowStartupLocation = WindowStartupLocation.Manual;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        Topmost = true;
        MouseLeftButtonUp += OnMouseLeftButtonUp;
        _dismissTimer.Tick += (_, _) => HideBubble(clicked: false);
    }

    public bool ShowMessage(
        string message,
        Rect petBounds,
        TimeSpan duration,
        Action? onClick,
        Action<bool>? onDismiss)
    {
        _dismissTimer.Stop();
        _clickAction = onClick;
        _dismissed = onDismiss;
        _completed = false;
        Width = Math.Clamp(message.Length * 7 + 56, 220, 340);
        Height = 76;
        Content = BuildContent(message);
        PositionNear(petBounds);
        Show();
        Activate();

        if (duration > TimeSpan.Zero)
        {
            _dismissTimer.Interval = duration;
            _dismissTimer.Start();
        }

        return true;
    }

    public void PositionNear(Rect petBounds)
    {
        var workArea = SystemParameters.WorkArea;
        var left = petBounds.Left + (petBounds.Width / 2) - (Width / 2);
        left = Math.Clamp(left, workArea.Left + 12, workArea.Right - Width - 12);

        var top = petBounds.Top - Height - 6;
        if (top < workArea.Top + 12)
        {
            top = petBounds.Bottom + 6;
        }

        Left = left;
        Top = top;
    }

    private UIElement BuildContent(string message)
    {
        var canvas = new Canvas
        {
            Width = Width,
            Height = Height,
            Background = Brushes.Transparent
        };

        var bubble = new Border
        {
            Width = Width,
            Height = 58,
            CornerRadius = new CornerRadius(14),
            Background = new SolidColorBrush(Color.FromArgb(245, 248, 248, 250)),
            Padding = new Thickness(14, 10, 14, 10),
            Effect = new DropShadowEffect
            {
                BlurRadius = 14,
                ShadowDepth = 4,
                Direction = 270,
                Opacity = 0.18
            },
            Child = new TextBlock
            {
                Text = message,
                FontSize = 13,
                FontWeight = FontWeights.Medium,
                Foreground = new SolidColorBrush(Color.FromRgb(34, 34, 34)),
                TextWrapping = TextWrapping.Wrap,
                MaxHeight = 38
            }
        };
        canvas.Children.Add(bubble);

        var tail = new Polygon
        {
            Points = new PointCollection
            {
                new(0, 0),
                new(9, 10),
                new(18, 0)
            },
            Fill = new SolidColorBrush(Color.FromArgb(245, 248, 248, 250))
        };
        Canvas.SetLeft(tail, 34);
        Canvas.SetTop(tail, 57);
        canvas.Children.Add(tail);

        return canvas;
    }

    private void OnMouseLeftButtonUp(object sender, MouseButtonEventArgs eventArgs)
    {
        var action = _clickAction;
        HideBubble(clicked: true);
        action?.Invoke();
        eventArgs.Handled = true;
    }

    private void HideBubble(bool clicked)
    {
        _dismissTimer.Stop();
        Hide();
        if (_completed)
        {
            return;
        }

        _completed = true;
        _dismissed?.Invoke(clicked);
        _clickAction = null;
        _dismissed = null;
    }
}
