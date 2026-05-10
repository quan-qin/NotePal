using NotePalWindows.Models;
using NotePalWindows.Services;
using NotePalWindows.Windows;
using System.Drawing;
using System.Windows;
using System.Windows.Controls;

namespace NotePalWindows;

public partial class App : Application
{
    private LocalDataStore? _dataStore;
    private SettingsStore? _settingsStore;
    private PetAssetStore? _assetStore;
    private NoteStore? _noteStore;
    private TodoStore? _todoStore;
    private WellnessReminderStore? _wellnessStore;
    private ReminderService? _reminderService;
    private WellnessReminderManager? _wellnessReminderManager;
    private MentorDialogueManager? _mentorDialogueManager;
    private SpeechBubbleManager? _speechBubbleManager;
    private PetInteractionManager? _petInteractionManager;
    private PetWindow? _petWindow;
    private NotesPanelWindow? _panelWindow;
    private SpeechBubbleWindow? _speechBubbleWindow;
    private System.Windows.Forms.NotifyIcon? _notifyIcon;
    private bool _reminderWaitingForTodoOpen;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        ShutdownMode = ShutdownMode.OnExplicitShutdown;

        _dataStore = new LocalDataStore();
        _settingsStore = new SettingsStore();
        _assetStore = new PetAssetStore();
        _noteStore = new NoteStore(_dataStore);
        _todoStore = new TodoStore(_dataStore);
        _wellnessStore = new WellnessReminderStore(_dataStore);
        _petInteractionManager = new PetInteractionManager(_settingsStore);

        _petWindow = new PetWindow(_todoStore, _settingsStore, _assetStore, _petInteractionManager);
        _panelWindow = new NotesPanelWindow(_noteStore, _todoStore, _wellnessStore);
        _speechBubbleWindow = new SpeechBubbleWindow();
        _speechBubbleManager = new SpeechBubbleManager(_settingsStore, PresentSpeechBubble);
        _mentorDialogueManager = new MentorDialogueManager(_settingsStore);

        ConfigurePetEvents();
        ConfigureStoreEvents();
        ConfigureTrayIcon();

        _reminderService = new ReminderService(_todoStore);
        _reminderService.ReminderDue += OnReminderDue;
        _reminderService.Start();

        _wellnessReminderManager = new WellnessReminderManager(_wellnessStore);
        _wellnessReminderManager.ReminderDue += OnWellnessReminderDue;
        _wellnessReminderManager.Start();

        _mentorDialogueManager.DialogueDue += (_, phrase) => ShowNonCriticalDialogue(phrase, SpeechBubbleMessage.MessageKind.Mentor, TimeSpan.FromSeconds(5));
        _mentorDialogueManager.Start();

        _petWindow.Show();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _reminderService?.Stop();
        _wellnessReminderManager?.Stop();
        _mentorDialogueManager?.Stop();
        if (_notifyIcon is not null)
        {
            _notifyIcon.Visible = false;
            _notifyIcon.Dispose();
        }

        base.OnExit(e);
    }

    private void ConfigurePetEvents()
    {
        if (_petWindow is null || _panelWindow is null || _petInteractionManager is null || _settingsStore is null)
        {
            return;
        }

        _panelWindow.VisibilityChanged += visible => _petInteractionManager.SetPanelOpen(visible);
        _petInteractionManager.SleepStarted = () =>
            ShowNonCriticalDialogue(_settingsStore.SelectedPetTheme.SleepyPhrase(), SpeechBubbleMessage.MessageKind.Sleepy, _settingsStore.GeneralBubbleDuration);

        _petWindow.TogglePanelRequested += () => TogglePanel(null);
        _petWindow.GreetingRequested += ShowGreeting;
        _petWindow.NewNoteRequested += CreateNote;
        _petWindow.NewTodoRequested += CreateTodo;
        _petWindow.ShowNotesRequested += () => ShowPanel(PanelTab.Notes);
        _petWindow.ShowTodosRequested += () => ShowPanel(PanelTab.Todos);
        _petWindow.ShowWellnessRequested += () => ShowPanel(PanelTab.Wellness);
        _petWindow.HideNotesRequested += HidePanel;
        _petWindow.UnlockThemeRequested += UnlockTheme;
        _petWindow.SelectThemeRequested += SelectTheme;
        _petWindow.ToggleMuteRequested += () => _settingsStore.SetMuteNonCriticalDialogue(!_settingsStore.MuteNonCriticalDialogue);
        _petWindow.ToggleAnimationsRequested += () => _settingsStore.SetAnimationsEnabled(!_settingsStore.AnimationsEnabled);
        _petWindow.QuitRequested += Shutdown;
        _petWindow.PetMoved += petBounds =>
        {
            if (_panelWindow.IsVisible)
            {
                _panelWindow.PositionNear(petBounds);
            }

            if (_speechBubbleWindow?.IsVisible == true)
            {
                _speechBubbleWindow.PositionNear(petBounds);
            }
        };
    }

    private void ConfigureStoreEvents()
    {
        if (_noteStore is null || _todoStore is null || _wellnessStore is null || _petInteractionManager is null || _settingsStore is null)
        {
            return;
        }

        _noteStore.ErrorRaised = ShowSaveError;
        _todoStore.ErrorRaised = ShowSaveError;
        _wellnessStore.ErrorRaised = ShowSaveError;
        _todoStore.TodoCompleted += (_, _) =>
        {
            _petInteractionManager.TodoCompleted();
            ShowNonCriticalDialogue(
                _settingsStore.SelectedPetTheme.CompletionPhrase(),
                SpeechBubbleMessage.MessageKind.Completion,
                _settingsStore.GeneralBubbleDuration);
        };
    }

    private void ConfigureTrayIcon()
    {
        var menu = new System.Windows.Forms.ContextMenuStrip();
        menu.Items.Add("新建笔记", null, (_, _) => Dispatcher.Invoke(CreateNote));
        menu.Items.Add("新建待办", null, (_, _) => Dispatcher.Invoke(CreateTodo));
        menu.Items.Add("显示笔记", null, (_, _) => Dispatcher.Invoke(() => ShowPanel(PanelTab.Notes)));
        menu.Items.Add("显示待办", null, (_, _) => Dispatcher.Invoke(() => ShowPanel(PanelTab.Todos)));
        menu.Items.Add("显示养生", null, (_, _) => Dispatcher.Invoke(() => ShowPanel(PanelTab.Wellness)));
        menu.Items.Add("隐藏面板", null, (_, _) => Dispatcher.Invoke(HidePanel));
        menu.Items.Add(new System.Windows.Forms.ToolStripSeparator());
        menu.Items.Add("退出 NotePal", null, (_, _) => Dispatcher.Invoke(Shutdown));

        _notifyIcon = new System.Windows.Forms.NotifyIcon
        {
            Text = "NotePal",
            Icon = PetAssetStore.LoadApplicationIcon() ?? SystemIcons.Application,
            ContextMenuStrip = menu,
            Visible = true
        };
        _notifyIcon.DoubleClick += (_, _) => Dispatcher.Invoke(() => TogglePanel(null));
    }

    private void CreateNote()
    {
        _petInteractionManager?.UserActivity();
        _noteStore?.CreateNote();
        ShowPanel(PanelTab.Notes);
    }

    private void CreateTodo()
    {
        _petInteractionManager?.UserActivity();
        _todoStore?.CreateTodo();
        ShowPanel(PanelTab.Todos);
    }

    private void TogglePanel(PanelTab? preferredTab)
    {
        if (_reminderWaitingForTodoOpen)
        {
            _reminderWaitingForTodoOpen = false;
            ShowPanel(PanelTab.Todos);
            return;
        }

        if (_panelWindow?.IsVisible == true)
        {
            HidePanel();
        }
        else
        {
            ShowPanel(preferredTab);
        }
    }

    private void ShowPanel(PanelTab? preferredTab)
    {
        if (_panelWindow is null || _petWindow is null)
        {
            return;
        }

        if (preferredTab == PanelTab.Todos)
        {
            _reminderWaitingForTodoOpen = false;
            _petInteractionManager?.ReminderAcknowledged();
        }

        _petInteractionManager?.UserActivity();
        _panelWindow.ShowNear(_petWindow.Bounds, preferredTab);
    }

    private void HidePanel()
    {
        _panelWindow?.Hide();
    }

    private void ShowGreeting()
    {
        if (_mentorDialogueManager is null)
        {
            return;
        }

        ShowNonCriticalDialogue(_mentorDialogueManager.RandomPhrase(), SpeechBubbleMessage.MessageKind.Mentor, TimeSpan.FromSeconds(5));
    }

    private void SelectTheme(PetTheme theme)
    {
        if (_settingsStore?.SelectTheme(theme) == true)
        {
            _petWindow?.RefreshTheme();
            ShowNonCriticalDialogue(theme.DefaultGreeting(), SpeechBubbleMessage.MessageKind.Mentor, TimeSpan.FromSeconds(4));
            return;
        }

        ShowCriticalBubble("这个主题还没有解锁。", TimeSpan.FromSeconds(4));
    }

    private void UnlockTheme()
    {
        if (_assetStore is null || _settingsStore is null)
        {
            return;
        }

        var key = PromptForThemeKey();
        if (string.IsNullOrWhiteSpace(key))
        {
            return;
        }

        var theme = _assetStore.UnlockSpecialTheme(key);
        if (theme is null)
        {
            ShowCriticalBubble("没有匹配的特殊主题密钥。", TimeSpan.FromSeconds(5));
            return;
        }

        _settingsStore.Unlock(theme.Value);
        _petWindow?.RefreshTheme();
        ShowCriticalBubble($"已解锁 {theme.Value.DisplayName()}。", TimeSpan.FromSeconds(4));
    }

    private string? PromptForThemeKey()
    {
        var dialog = new Window
        {
            Title = "解锁特殊主题",
            Width = 300,
            Height = 150,
            WindowStartupLocation = WindowStartupLocation.CenterOwner,
            ResizeMode = ResizeMode.NoResize,
            Owner = _petWindow,
            Topmost = true
        };

        var panel = new StackPanel { Margin = new Thickness(16) };
        panel.Children.Add(new TextBlock
        {
            Text = "输入主题密钥",
            Margin = new Thickness(0, 0, 0, 8)
        });
        var textBox = new TextBox { MinWidth = 240 };
        panel.Children.Add(textBox);
        var row = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 14, 0, 0)
        };
        var cancel = new Button { Content = "取消", Width = 72, Margin = new Thickness(0, 0, 8, 0) };
        var ok = new Button { Content = "解锁", Width = 72, IsDefault = true };
        cancel.Click += (_, _) => dialog.DialogResult = false;
        ok.Click += (_, _) => dialog.DialogResult = true;
        row.Children.Add(cancel);
        row.Children.Add(ok);
        panel.Children.Add(row);
        dialog.Content = panel;
        textBox.Focus();

        return dialog.ShowDialog() == true ? textBox.Text : null;
    }

    private void OnReminderDue(object? sender, ReminderEventArgs e)
    {
        _reminderWaitingForTodoOpen = true;
        _petInteractionManager?.ReminderStarted();
        EnqueueBubble(new SpeechBubbleMessage
        {
            Kind = SpeechBubbleMessage.MessageKind.Reminder,
            Text = e.Message,
            Duration = _settingsStore?.ReminderBubbleDuration ?? TimeSpan.FromSeconds(8),
            IsCritical = true,
            OnClick = () =>
            {
                _reminderWaitingForTodoOpen = false;
                _petInteractionManager?.ReminderAcknowledged();
                ShowPanel(PanelTab.Todos);
            }
        });
    }

    private void OnWellnessReminderDue(object? sender, WellnessReminderEventArgs e)
    {
        EnqueueBubble(new SpeechBubbleMessage
        {
            Kind = SpeechBubbleMessage.MessageKind.Reminder,
            Text = e.Message,
            Duration = TimeSpan.FromSeconds(10),
            IsCritical = true,
            OnClick = () => ShowPanel(PanelTab.Wellness)
        });
    }

    private void ShowSaveError(string message)
    {
        _petInteractionManager?.SaveFailed();
        ShowCriticalBubble(message, (_settingsStore?.GeneralBubbleDuration ?? TimeSpan.FromSeconds(4)) + TimeSpan.FromSeconds(2));
    }

    private void ShowCriticalBubble(string message, TimeSpan duration)
    {
        EnqueueBubble(new SpeechBubbleMessage
        {
            Kind = SpeechBubbleMessage.MessageKind.Error,
            Text = message,
            Duration = duration,
            IsCritical = true
        });
    }

    private void ShowNonCriticalDialogue(string message, SpeechBubbleMessage.MessageKind kind, TimeSpan duration)
    {
        EnqueueBubble(new SpeechBubbleMessage
        {
            Kind = kind,
            Text = message,
            Duration = duration,
            IsCritical = false
        });
    }

    private void EnqueueBubble(SpeechBubbleMessage message)
    {
        _speechBubbleManager?.Enqueue(message);
    }

    private bool PresentSpeechBubble(SpeechBubbleMessage message, Action<bool> completion)
    {
        if (_speechBubbleWindow is null || _petWindow is null)
        {
            return false;
        }

        return _speechBubbleWindow.ShowMessage(
            message.Text,
            _petWindow.Bounds,
            message.Duration,
            message.OnClick,
            completion);
    }
}
