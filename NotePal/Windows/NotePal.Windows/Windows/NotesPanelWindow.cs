using NotePalWindows.Models;
using NotePalWindows.Services;
using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Shapes;

namespace NotePalWindows.Windows;

public sealed class NotesPanelWindow : Window
{
    private readonly NoteStore _noteStore;
    private readonly TodoStore _todoStore;
    private readonly WellnessReminderStore _wellnessStore;
    private readonly Canvas _root;
    private readonly Border _body;
    private readonly Polygon _tail;
    private readonly Brush _panelBrush = new SolidColorBrush(Color.FromArgb(246, 248, 248, 250));
    private PanelTab _selectedTab = PanelTab.Notes;
    private TodoFilter _todoFilter = TodoFilter.All;

    public NotesPanelWindow(
        NoteStore noteStore,
        TodoStore todoStore,
        WellnessReminderStore wellnessStore)
    {
        _noteStore = noteStore;
        _todoStore = todoStore;
        _wellnessStore = wellnessStore;
        _noteStore.Changed += (_, _) => RebuildContentIfVisible();
        _todoStore.Changed += (_, _) => RebuildContentIfVisible();
        _wellnessStore.Changed += (_, _) => RebuildContentIfVisible();

        Title = "NotePal";
        Width = 414;
        Height = 520;
        WindowStartupLocation = WindowStartupLocation.Manual;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        Topmost = true;
        IsVisibleChanged += (_, _) => VisibilityChanged?.Invoke(IsVisible);
        KeyDown += (_, eventArgs) =>
        {
            if (eventArgs.Key == Key.Escape)
            {
                Hide();
                eventArgs.Handled = true;
            }
        };

        _root = new Canvas
        {
            Width = Width,
            Height = Height,
            Background = Brushes.Transparent
        };

        _tail = new Polygon
        {
            Width = 18,
            Height = 30,
            Fill = _panelBrush,
            Stroke = new SolidColorBrush(Color.FromArgb(64, 255, 255, 255)),
            StrokeThickness = 0.7
        };

        _body = new Border
        {
            Width = 390,
            Height = 520,
            CornerRadius = new CornerRadius(22),
            Background = _panelBrush,
            BorderBrush = new SolidColorBrush(Color.FromArgb(64, 255, 255, 255)),
            BorderThickness = new Thickness(0.7),
            Padding = new Thickness(14),
            Effect = new DropShadowEffect
            {
                BlurRadius = 22,
                ShadowDepth = 10,
                Direction = 270,
                Opacity = 0.16
            }
        };

        _root.Children.Add(_tail);
        _root.Children.Add(_body);
        Content = _root;
        UpdateChrome(tailOnLeft: true, tailCenterY: 92);
        RebuildContent();
    }

    public event Action<bool>? VisibilityChanged;

    public void ShowNear(Rect petBounds, PanelTab? preferredTab)
    {
        if (preferredTab is not null)
        {
            _selectedTab = preferredTab.Value;
        }

        RebuildContent();
        PositionNear(petBounds);
        Show();
        Activate();
    }

    public void PositionNear(Rect petBounds)
    {
        var workArea = SystemParameters.WorkArea;
        const double gap = 6;
        var placeOnRight = petBounds.Right + gap + Width <= workArea.Right;
        var left = placeOnRight
            ? petBounds.Right + gap
            : petBounds.Left - Width - gap;

        var top = petBounds.Top + (petBounds.Height / 2) - (Height / 2);
        top = Math.Clamp(top, workArea.Top + 12, workArea.Bottom - Height - 12);
        var tailCenterY = Math.Clamp(petBounds.Top + (petBounds.Height / 2) - top, 54, Height - 54);

        UpdateChrome(placeOnRight, tailCenterY);
        Left = left;
        Top = top;
    }

    private void RebuildContentIfVisible()
    {
        if (IsVisible)
        {
            RebuildContent();
        }
    }

    private void RebuildContent()
    {
        var panel = new DockPanel { LastChildFill = true };
        var header = BuildHeader();
        DockPanel.SetDock(header, Dock.Top);
        panel.Children.Add(header);

        var tabs = BuildTabs();
        DockPanel.SetDock(tabs, Dock.Top);
        panel.Children.Add(tabs);

        var error = BuildErrorText();
        if (error is not null)
        {
            DockPanel.SetDock(error, Dock.Top);
            panel.Children.Add(error);
        }

        panel.Children.Add(_selectedTab switch
        {
            PanelTab.Notes => BuildNotesList(),
            PanelTab.Todos => BuildTodoList(),
            PanelTab.Wellness => BuildWellnessList(),
            _ => BuildNotesList()
        });
        _body.Child = panel;
    }

    private UIElement BuildHeader()
    {
        var grid = new Grid { Margin = new Thickness(0, 0, 0, 12) };
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var titleStack = new StackPanel { Orientation = Orientation.Vertical };
        titleStack.Children.Add(new TextBlock
        {
            Text = "NotePal",
            FontSize = 17,
            FontWeight = FontWeights.SemiBold,
            Foreground = Brushes.Black
        });
        titleStack.Children.Add(new TextBlock
        {
            Text = Subtitle(),
            FontSize = 12,
            Foreground = new SolidColorBrush(Color.FromRgb(104, 104, 104))
        });
        grid.Children.Add(titleStack);

        if (_selectedTab != PanelTab.Wellness)
        {
            var addButton = new Button
            {
                Content = "+",
                Width = 28,
                Height = 28,
                FontSize = 16,
                FontWeight = FontWeights.SemiBold,
                Background = new SolidColorBrush(Color.FromArgb(32, 0, 122, 255)),
                BorderBrush = Brushes.Transparent,
                ToolTip = _selectedTab == PanelTab.Notes ? "新建笔记" : "新建待办"
            };
            addButton.Click += (_, _) => AddCurrentItem();
            Grid.SetColumn(addButton, 1);
            grid.Children.Add(addButton);
        }

        return grid;
    }

    private string Subtitle()
    {
        return _selectedTab switch
        {
            PanelTab.Notes => "快速笔记",
            PanelTab.Todos => "待办事项",
            PanelTab.Wellness => "养生提醒",
            _ => ""
        };
    }

    private UIElement BuildTabs()
    {
        var grid = new UniformGrid
        {
            Columns = 3,
            Margin = new Thickness(0, 0, 0, 10)
        };
        grid.Children.Add(TabButton("笔记", PanelTab.Notes));
        grid.Children.Add(TabButton("待办", PanelTab.Todos));
        grid.Children.Add(TabButton("养生", PanelTab.Wellness));
        return grid;
    }

    private Button TabButton(string text, PanelTab tab)
    {
        var selected = _selectedTab == tab;
        var button = new Button
        {
            Content = text,
            Height = 30,
            Background = selected
                ? new SolidColorBrush(Color.FromRgb(225, 236, 250))
                : new SolidColorBrush(Color.FromArgb(90, 255, 255, 255)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(40, 0, 0, 0)),
            Foreground = Brushes.Black
        };
        button.Click += (_, _) =>
        {
            _selectedTab = tab;
            RebuildContent();
        };
        return button;
    }

    private TextBlock? BuildErrorText()
    {
        var message = _noteStore.LastError ?? _todoStore.LastError ?? _wellnessStore.LastError;
        if (string.IsNullOrWhiteSpace(message))
        {
            return null;
        }

        return new TextBlock
        {
            Text = message,
            FontSize = 12,
            Foreground = Brushes.IndianRed,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 0, 0, 8)
        };
    }

    private UIElement BuildNotesList()
    {
        var stack = new StackPanel { Orientation = Orientation.Vertical };
        if (_noteStore.Notes.Count == 0)
        {
            stack.Children.Add(EmptyText("还没有笔记。"));
        }
        else
        {
            foreach (var note in _noteStore.Notes)
            {
                stack.Children.Add(BuildNoteCard(note));
            }
        }

        return Scroll(stack);
    }

    private UIElement BuildNoteCard(Note note)
    {
        var card = Card();
        var stack = new StackPanel { Orientation = Orientation.Vertical };
        var titleRow = new Grid();
        titleRow.ColumnDefinitions.Add(new ColumnDefinition());
        titleRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var titleBox = new TextBox
        {
            Text = note.Title,
            BorderThickness = new Thickness(0),
            FontSize = 14,
            FontWeight = FontWeights.SemiBold,
            Background = Brushes.Transparent
        };
        titleBox.LostFocus += (_, _) =>
        {
            var updated = note.Clone();
            updated.Title = string.IsNullOrWhiteSpace(titleBox.Text) ? "未命名笔记" : titleBox.Text.Trim();
            _noteStore.UpdateNote(updated);
        };
        titleRow.Children.Add(titleBox);

        var delete = SmallButton("删除");
        delete.Click += (_, _) => _noteStore.DeleteNote(note.Id);
        Grid.SetColumn(delete, 1);
        titleRow.Children.Add(delete);
        stack.Children.Add(titleRow);

        var bodyBox = new TextBox
        {
            Text = note.Body,
            AcceptsReturn = true,
            TextWrapping = TextWrapping.Wrap,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto,
            MinHeight = 72,
            Margin = new Thickness(0, 8, 0, 8)
        };
        bodyBox.LostFocus += (_, _) =>
        {
            var updated = note.Clone();
            updated.Body = bodyBox.Text;
            _noteStore.UpdateNote(updated);
        };
        stack.Children.Add(bodyBox);

        stack.Children.Add(MetaText($"创建 {note.CreatedAt.LocalDateTime:g}   更新 {note.UpdatedAt.LocalDateTime:g}"));
        card.Child = stack;
        return card;
    }

    private UIElement BuildTodoList()
    {
        var outer = new DockPanel { LastChildFill = true };
        var filter = new ComboBox
        {
            ItemsSource = new[] { "全部", "进行中", "已完成", "今日到期" },
            SelectedIndex = (int)_todoFilter,
            Margin = new Thickness(0, 0, 0, 8),
            Height = 28
        };
        filter.SelectionChanged += (_, _) =>
        {
            if (filter.SelectedIndex >= 0)
            {
                _todoFilter = (TodoFilter)filter.SelectedIndex;
                RebuildContent();
            }
        };
        DockPanel.SetDock(filter, Dock.Top);
        outer.Children.Add(filter);

        var stack = new StackPanel { Orientation = Orientation.Vertical };
        var todos = FilterTodos().ToList();
        if (todos.Count == 0)
        {
            stack.Children.Add(EmptyText("这里还没有待办。"));
        }
        else
        {
            foreach (var todo in todos)
            {
                stack.Children.Add(BuildTodoCard(todo));
            }
        }

        outer.Children.Add(Scroll(stack));
        return outer;
    }

    private IEnumerable<TodoItem> FilterTodos()
    {
        return _todoFilter switch
        {
            TodoFilter.Active => _todoStore.Todos.Where(todo => !todo.IsCompleted),
            TodoFilter.Completed => _todoStore.Todos.Where(todo => todo.IsCompleted),
            TodoFilter.DueToday => _todoStore.Todos.Where(todo =>
                !todo.IsCompleted && todo.DueDate?.LocalDateTime.Date == DateTime.Today),
            _ => _todoStore.Todos
        };
    }

    private UIElement BuildTodoCard(TodoItem todo)
    {
        var card = Card();
        card.Opacity = todo.IsCompleted ? 0.62 : 1;
        var stack = new StackPanel { Orientation = Orientation.Vertical };
        var titleRow = new Grid();
        titleRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        titleRow.ColumnDefinitions.Add(new ColumnDefinition());
        titleRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var completeBox = new CheckBox
        {
            IsChecked = todo.IsCompleted,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(0, 0, 8, 0)
        };
        completeBox.Checked += (_, _) => SetTodoCompleted(todo, true);
        completeBox.Unchecked += (_, _) => SetTodoCompleted(todo, false);
        titleRow.Children.Add(completeBox);

        var titleBox = new TextBox
        {
            Text = todo.Title,
            BorderThickness = new Thickness(0),
            FontSize = 14,
            FontWeight = FontWeights.SemiBold,
            Background = Brushes.Transparent
        };
        titleBox.LostFocus += (_, _) =>
        {
            var updated = todo.Clone();
            updated.Title = string.IsNullOrWhiteSpace(titleBox.Text) ? "新待办" : titleBox.Text.Trim();
            _todoStore.UpdateTodo(updated);
        };
        Grid.SetColumn(titleBox, 1);
        titleRow.Children.Add(titleBox);

        var delete = SmallButton("删除");
        delete.Click += (_, _) => _todoStore.DeleteTodo(todo.Id);
        Grid.SetColumn(delete, 2);
        titleRow.Children.Add(delete);
        stack.Children.Add(titleRow);

        var descriptionBox = new TextBox
        {
            Text = todo.Description ?? "",
            AcceptsReturn = true,
            TextWrapping = TextWrapping.Wrap,
            MinHeight = 44,
            Margin = new Thickness(0, 8, 0, 8)
        };
        descriptionBox.LostFocus += (_, _) =>
        {
            var updated = todo.Clone();
            updated.Description = string.IsNullOrWhiteSpace(descriptionBox.Text) ? null : descriptionBox.Text;
            _todoStore.UpdateTodo(updated);
        };
        stack.Children.Add(descriptionBox);
        stack.Children.Add(BuildDueControls(todo));
        stack.Children.Add(MetaText($"创建 {todo.CreatedAt.LocalDateTime:g}   更新 {todo.UpdatedAt.LocalDateTime:g}"));
        card.Child = stack;
        return card;
    }

    private void SetTodoCompleted(TodoItem todo, bool isCompleted)
    {
        if (todo.IsCompleted == isCompleted)
        {
            return;
        }

        var updated = todo.Clone();
        updated.IsCompleted = isCompleted;
        _todoStore.UpdateTodo(updated);
    }

    private UIElement BuildDueControls(TodoItem todo)
    {
        var dueRow = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Margin = new Thickness(0, 0, 0, 8)
        };
        dueRow.Children.Add(new TextBlock
        {
            Text = "截止",
            Width = 44,
            VerticalAlignment = VerticalAlignment.Center,
            Foreground = new SolidColorBrush(Color.FromRgb(104, 104, 104))
        });
        var dueBox = new TextBox
        {
            Text = FormatDueDate(todo.DueDate),
            Width = 160,
            ToolTip = "格式：yyyy-MM-dd HH:mm，留空表示无截止时间。"
        };
        dueBox.LostFocus += (_, _) =>
        {
            if (!TryParseDueDate(dueBox.Text, out var dueDate))
            {
                dueBox.BorderBrush = Brushes.IndianRed;
                return;
            }

            var updated = todo.Clone();
            updated.DueDate = dueDate;
            _todoStore.UpdateTodo(updated);
        };
        dueRow.Children.Add(dueBox);

        if (todo.DueDate is not null)
        {
            dueRow.Children.Add(new TextBlock
            {
                Text = todo.DueDate <= DateTimeOffset.Now && !todo.IsCompleted ? "已到期" : "待提醒",
                Margin = new Thickness(8, 0, 0, 0),
                VerticalAlignment = VerticalAlignment.Center,
                Foreground = todo.DueDate <= DateTimeOffset.Now && !todo.IsCompleted
                    ? Brushes.IndianRed
                    : new SolidColorBrush(Color.FromRgb(104, 104, 104))
            });
        }

        return dueRow;
    }

    private UIElement BuildWellnessList()
    {
        var stack = new StackPanel { Orientation = Orientation.Vertical };
        foreach (var reminder in _wellnessStore.Reminders)
        {
            stack.Children.Add(BuildWellnessCard(reminder));
        }

        return Scroll(stack);
    }

    private UIElement BuildWellnessCard(WellnessReminder reminder)
    {
        var card = Card();
        var stack = new StackPanel { Orientation = Orientation.Vertical };

        var enabledBox = new CheckBox
        {
            Content = reminder.Title,
            IsChecked = reminder.IsEnabled,
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
            Margin = new Thickness(0, 0, 0, 8)
        };
        enabledBox.Checked += (_, _) => _wellnessStore.SetEnabled(reminder.Kind, true);
        enabledBox.Unchecked += (_, _) => _wellnessStore.SetEnabled(reminder.Kind, false);
        stack.Children.Add(enabledBox);

        var intervalRow = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            Margin = new Thickness(0, 0, 0, 8)
        };
        intervalRow.Children.Add(new TextBlock
        {
            Text = "每",
            Width = 28,
            VerticalAlignment = VerticalAlignment.Center
        });
        var intervalBox = new TextBox
        {
            Text = reminder.EffectiveIntervalMinutes.ToString(CultureInfo.InvariantCulture),
            Width = 56,
            IsEnabled = reminder.IsEnabled,
            ToolTip = "提醒间隔分钟数，范围 5-1440。"
        };
        intervalBox.LostFocus += (_, _) =>
        {
            if (!int.TryParse(intervalBox.Text.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out var minutes))
            {
                intervalBox.BorderBrush = Brushes.IndianRed;
                return;
            }

            _wellnessStore.SetInterval(reminder.Kind, minutes);
        };
        intervalRow.Children.Add(intervalBox);
        intervalRow.Children.Add(new TextBlock
        {
            Text = "分钟提醒",
            Margin = new Thickness(6, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center
        });
        stack.Children.Add(intervalRow);

        stack.Children.Add(MetaText(reminder.IsEnabled
            ? $"下次 {reminder.NextReminderAt.LocalDateTime:g}"
            : "已关闭"));

        card.Child = stack;
        return card;
    }

    private void AddCurrentItem()
    {
        if (_selectedTab == PanelTab.Notes)
        {
            _noteStore.CreateNote();
        }
        else if (_selectedTab == PanelTab.Todos)
        {
            _todoStore.CreateTodo();
        }
    }

    private static ScrollViewer Scroll(UIElement child)
    {
        return new ScrollViewer
        {
            Content = child,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto
        };
    }

    private static Border Card()
    {
        return new Border
        {
            CornerRadius = new CornerRadius(10),
            Background = new SolidColorBrush(Color.FromArgb(140, 255, 255, 255)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(28, 0, 0, 0)),
            BorderThickness = new Thickness(1),
            Padding = new Thickness(10),
            Margin = new Thickness(0, 0, 0, 10)
        };
    }

    private static Button SmallButton(string text)
    {
        return new Button
        {
            Content = text,
            FontSize = 11,
            Padding = new Thickness(8, 2, 8, 2),
            Margin = new Thickness(8, 0, 0, 0)
        };
    }

    private static TextBlock EmptyText(string text)
    {
        return new TextBlock
        {
            Text = text,
            FontSize = 14,
            Foreground = new SolidColorBrush(Color.FromRgb(116, 116, 116)),
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 120, 0, 0)
        };
    }

    private static TextBlock MetaText(string text)
    {
        return new TextBlock
        {
            Text = text,
            FontSize = 10,
            Foreground = new SolidColorBrush(Color.FromRgb(120, 120, 120))
        };
    }

    private void UpdateChrome(bool tailOnLeft, double tailCenterY)
    {
        Canvas.SetLeft(_body, tailOnLeft ? 18 : 0);
        Canvas.SetTop(_body, 0);

        _tail.Points = tailOnLeft
            ? new PointCollection { new(18, 0), new(0, 15), new(18, 30) }
            : new PointCollection { new(0, 0), new(18, 15), new(0, 30) };
        Canvas.SetLeft(_tail, tailOnLeft ? 0 : 390);
        Canvas.SetTop(_tail, tailCenterY - 15);
    }

    private static string FormatDueDate(DateTimeOffset? dueDate)
    {
        return dueDate?.LocalDateTime.ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture) ?? "";
    }

    private static bool TryParseDueDate(string text, out DateTimeOffset? dueDate)
    {
        dueDate = null;
        if (string.IsNullOrWhiteSpace(text))
        {
            return true;
        }

        var formats = new[] { "yyyy-MM-dd HH:mm", "yyyy/M/d H:mm", "yyyy-M-d H:mm" };
        if (DateTime.TryParseExact(
            text.Trim(),
            formats,
            CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeLocal,
            out var parsed))
        {
            dueDate = new DateTimeOffset(parsed);
            return true;
        }

        if (DateTimeOffset.TryParse(text.Trim(), CultureInfo.CurrentCulture, DateTimeStyles.AssumeLocal, out var parsedOffset))
        {
            dueDate = parsedOffset;
            return true;
        }

        return false;
    }
}
