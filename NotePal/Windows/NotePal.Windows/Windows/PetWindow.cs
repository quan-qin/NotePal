using NotePalWindows.Models;
using NotePalWindows.Services;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Shapes;

namespace NotePalWindows.Windows;

public sealed class PetWindow : Window
{
    private readonly TodoStore _todoStore;
    private readonly SettingsStore _settingsStore;
    private readonly PetAssetStore _assetStore;
    private readonly PetInteractionManager _interactionManager;
    private readonly Image _image;
    private readonly TextBlock _badgeText;
    private readonly Border _badge;
    private readonly TextBlock _cue;
    private Point _dragStartScreen;
    private Point _windowStart;
    private bool _didDrag;
    private bool _isMouseCapturedForDrag;

    public PetWindow(
        TodoStore todoStore,
        SettingsStore settingsStore,
        PetAssetStore assetStore,
        PetInteractionManager interactionManager)
    {
        _todoStore = todoStore;
        _settingsStore = settingsStore;
        _assetStore = assetStore;
        _interactionManager = interactionManager;
        _todoStore.Changed += (_, _) => UpdateBadge();
        _settingsStore.Changed += (_, _) => UpdateTheme();
        _interactionManager.Changed += (_, _) => UpdateCue();

        Title = "NotePal";
        Width = 117;
        Height = 117;
        WindowStartupLocation = WindowStartupLocation.Manual;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        Topmost = true;

        var root = new Grid
        {
            Width = Width,
            Height = Height,
            Background = Brushes.Transparent
        };

        var shadow = new Ellipse
        {
            Width = 50,
            Height = 7,
            Fill = new SolidColorBrush(Color.FromArgb(38, 0, 0, 0)),
            Effect = new BlurEffect { Radius = 3 },
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Bottom,
            Margin = new Thickness(0, 0, 8, 6)
        };
        root.Children.Add(shadow);

        _image = new Image
        {
            Stretch = Stretch.Uniform,
            Width = Math.Min(114, _settingsStore.PetSize * 1.185),
            Height = Math.Min(114, _settingsStore.PetSize * 1.185),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        RenderOptions.SetBitmapScalingMode(_image, BitmapScalingMode.HighQuality);
        root.Children.Add(_image);

        _cue = new TextBlock
        {
            FontSize = 13,
            FontWeight = FontWeights.Bold,
            Foreground = new SolidColorBrush(Color.FromRgb(58, 58, 58)),
            Background = new SolidColorBrush(Color.FromArgb(190, 255, 255, 255)),
            Padding = new Thickness(5, 1, 5, 2),
            HorizontalAlignment = HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(8, 12, 0, 0),
            Effect = new DropShadowEffect { BlurRadius = 4, ShadowDepth = 1, Opacity = 0.16 }
        };
        root.Children.Add(_cue);

        _badgeText = new TextBlock
        {
            Foreground = Brushes.White,
            FontSize = 10,
            FontWeight = FontWeights.Bold,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };
        _badge = new Border
        {
            Width = 18,
            Height = 18,
            CornerRadius = new CornerRadius(9),
            Background = new SolidColorBrush(Color.FromRgb(122, 186, 255)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(220, 255, 255, 255)),
            BorderThickness = new Thickness(1),
            Child = _badgeText,
            HorizontalAlignment = HorizontalAlignment.Right,
            VerticalAlignment = VerticalAlignment.Top,
            Margin = new Thickness(0, 6, 6, 0),
            Effect = new DropShadowEffect
            {
                BlurRadius = 4,
                Direction = 270,
                ShadowDepth = 1,
                Opacity = 0.18
            }
        };
        root.Children.Add(_badge);

        Content = root;
        ContextMenuOpening += (_, _) => ContextMenu = BuildContextMenu();
        Loaded += (_, _) => PlaceInitialWindow();
        MouseLeftButtonDown += OnMouseLeftButtonDown;
        MouseMove += OnMouseMove;
        MouseLeftButtonUp += OnMouseLeftButtonUp;
        MouseEnter += (_, _) => _interactionManager.SetHovering(true);
        MouseLeave += (_, _) => _interactionManager.SetHovering(false);
        MouseRightButtonUp += (_, eventArgs) =>
        {
            _interactionManager.RightClicked();
            ContextMenu = BuildContextMenu();
            ContextMenu.IsOpen = true;
            eventArgs.Handled = true;
        };

        UpdateTheme();
        UpdateBadge();
        UpdateCue();
    }

    public event Action? TogglePanelRequested;
    public event Action? GreetingRequested;
    public event Action? NewNoteRequested;
    public event Action? NewTodoRequested;
    public event Action? ShowNotesRequested;
    public event Action? ShowTodosRequested;
    public event Action? ShowWellnessRequested;
    public event Action? HideNotesRequested;
    public event Action? UnlockThemeRequested;
    public event Action<PetTheme>? SelectThemeRequested;
    public event Action? ToggleMuteRequested;
    public event Action? ToggleAnimationsRequested;
    public event Action? QuitRequested;
    public event Action<Rect>? PetMoved;

    public Rect Bounds => new(Left, Top, Width, Height);

    public void RefreshTheme()
    {
        UpdateTheme();
    }

    private ContextMenu BuildContextMenu()
    {
        var menu = new ContextMenu();
        menu.Items.Add(MenuItem("新建笔记", () => NewNoteRequested?.Invoke()));
        menu.Items.Add(MenuItem("新建待办", () => NewTodoRequested?.Invoke()));
        menu.Items.Add(new Separator());
        menu.Items.Add(MenuItem("显示笔记", () => ShowNotesRequested?.Invoke()));
        menu.Items.Add(MenuItem("显示待办", () => ShowTodosRequested?.Invoke()));
        menu.Items.Add(MenuItem("显示养生", () => ShowWellnessRequested?.Invoke()));
        menu.Items.Add(MenuItem("隐藏面板", () => HideNotesRequested?.Invoke()));
        menu.Items.Add(new Separator());
        menu.Items.Add(ThemeMenu());
        menu.Items.Add(MenuItem("解锁特殊主题...", () => UnlockThemeRequested?.Invoke()));
        menu.Items.Add(new Separator());
        menu.Items.Add(CheckMenuItem(
            _settingsStore.MuteNonCriticalDialogue ? "已静音闲聊" : "静音闲聊",
            _settingsStore.MuteNonCriticalDialogue,
            () => ToggleMuteRequested?.Invoke()));
        menu.Items.Add(CheckMenuItem(
            _settingsStore.AnimationsEnabled ? "动画已启用" : "动画已关闭",
            _settingsStore.AnimationsEnabled,
            () => ToggleAnimationsRequested?.Invoke()));
        menu.Items.Add(new Separator());
        menu.Items.Add(MenuItem("退出 NotePal", () => QuitRequested?.Invoke()));
        return menu;
    }

    private MenuItem ThemeMenu()
    {
        var themeMenu = new MenuItem { Header = "主题" };
        foreach (var theme in Enum.GetValues<PetTheme>())
        {
            var item = CheckMenuItem(
                theme.DisplayName(),
                _settingsStore.SelectedPetTheme == theme,
                () => SelectThemeRequested?.Invoke(theme));
            item.IsEnabled = _settingsStore.IsUnlocked(theme);
            themeMenu.Items.Add(item);
        }

        return themeMenu;
    }

    private static MenuItem MenuItem(string header, Action action)
    {
        var item = new MenuItem { Header = header };
        item.Click += (_, _) => action();
        return item;
    }

    private static MenuItem CheckMenuItem(string header, bool isChecked, Action action)
    {
        var item = new MenuItem
        {
            Header = header,
            IsCheckable = true,
            IsChecked = isChecked
        };
        item.Click += (_, _) => action();
        return item;
    }

    private void PlaceInitialWindow()
    {
        var workArea = SystemParameters.WorkArea;
        Left = workArea.Right - Width - 64;
        Top = workArea.Bottom - Height - 120;
        PetMoved?.Invoke(Bounds);
    }

    private void UpdateTheme()
    {
        _image.Width = Math.Min(114, _settingsStore.PetSize * 1.185);
        _image.Height = Math.Min(114, _settingsStore.PetSize * 1.185);
        _image.Source = _assetStore.ImageFor(_settingsStore.SelectedPetTheme)
            ?? _assetStore.ImageFor(PetTheme.Newton);
    }

    private void UpdateBadge()
    {
        var count = _todoStore.IncompleteCount;
        _badge.Visibility = count > 0 ? Visibility.Visible : Visibility.Collapsed;
        _badge.Width = count > 9 ? 24 : 18;
        _badgeText.Text = count > 99 ? "99+" : count.ToString();
    }

    private void UpdateCue()
    {
        _cue.Text = _interactionManager.State switch
        {
            PetState.Happy => "♥",
            PetState.Thinking => "...",
            PetState.Sleeping => "Zz",
            PetState.Surprised => "!",
            PetState.Reminding => "铃",
            PetState.Focused => ">_",
            PetState.Celebrating => "✓",
            _ => _interactionManager.IsHovering ? "·" : ""
        };
        _cue.Visibility = string.IsNullOrWhiteSpace(_cue.Text) ? Visibility.Collapsed : Visibility.Visible;
    }

    private void OnMouseLeftButtonDown(object sender, MouseButtonEventArgs eventArgs)
    {
        if (eventArgs.ClickCount >= 2)
        {
            _interactionManager.DoubleClicked();
            GreetingRequested?.Invoke();
            eventArgs.Handled = true;
            return;
        }

        _dragStartScreen = PointToScreen(eventArgs.GetPosition(this));
        _windowStart = new Point(Left, Top);
        _didDrag = false;
        _isMouseCapturedForDrag = CaptureMouse();
        eventArgs.Handled = true;
    }

    private void OnMouseMove(object sender, MouseEventArgs eventArgs)
    {
        if (!_isMouseCapturedForDrag || eventArgs.LeftButton != MouseButtonState.Pressed)
        {
            return;
        }

        var currentScreen = PointToScreen(eventArgs.GetPosition(this));
        var deltaX = currentScreen.X - _dragStartScreen.X;
        var deltaY = currentScreen.Y - _dragStartScreen.Y;

        if (Math.Abs(deltaX) + Math.Abs(deltaY) > 4)
        {
            _didDrag = true;
        }

        if (_didDrag)
        {
            _interactionManager.Dragging();
            Left = _windowStart.X + deltaX;
            Top = _windowStart.Y + deltaY;
            PetMoved?.Invoke(Bounds);
        }
    }

    private void OnMouseLeftButtonUp(object sender, MouseButtonEventArgs eventArgs)
    {
        if (_isMouseCapturedForDrag)
        {
            ReleaseMouseCapture();
        }

        _isMouseCapturedForDrag = false;

        if (!_didDrag)
        {
            _interactionManager.Clicked();
            TogglePanelRequested?.Invoke();
        }
        else
        {
            _interactionManager.DragEnded();
            PetMoved?.Invoke(Bounds);
        }

        _didDrag = false;
        eventArgs.Handled = true;
    }
}
