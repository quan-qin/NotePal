using System.Windows.Threading;

namespace NotePalWindows.Services;

public enum PetState
{
    Idle,
    Happy,
    Thinking,
    Sleeping,
    Surprised,
    Reminding,
    Focused,
    Celebrating
}

public sealed class PetInteractionManager
{
    private readonly SettingsStore _settingsStore;
    private readonly DispatcherTimer _sleepTimer = new();
    private readonly DispatcherTimer _temporaryTimer = new();
    private bool _panelOpen;
    private bool _reminderActive;

    public PetInteractionManager(SettingsStore settingsStore)
    {
        _settingsStore = settingsStore;
        _sleepTimer.Tick += (_, _) => EnterSleep();
        _temporaryTimer.Tick += (_, _) =>
        {
            _temporaryTimer.Stop();
            ReturnToBaseState();
        };
        ScheduleSleepTimer();
    }

    public event EventHandler? Changed;
    public Action? SleepStarted { get; set; }
    public PetState State { get; private set; } = PetState.Idle;
    public bool IsHovering { get; private set; }

    public void UserActivity()
    {
        if (State == PetState.Sleeping)
        {
            SetTemporaryState(PetState.Happy, TimeSpan.FromSeconds(1.4));
        }

        ScheduleSleepTimer();
    }

    public void Clicked()
    {
        UserActivity();
        SetTemporaryState(PetState.Focused, TimeSpan.FromSeconds(0.8));
    }

    public void DoubleClicked()
    {
        UserActivity();
        SetTemporaryState(PetState.Happy, TimeSpan.FromSeconds(1.8));
    }

    public void RightClicked()
    {
        UserActivity();
        SetTemporaryState(PetState.Surprised, TimeSpan.FromSeconds(1.0));
    }

    public void Dragging()
    {
        UserActivity();
        SetState(PetState.Focused);
    }

    public void DragEnded()
    {
        ReturnToBaseState();
    }

    public void SetHovering(bool hovering)
    {
        IsHovering = hovering;
        if (hovering)
        {
            UserActivity();
        }

        Changed?.Invoke(this, EventArgs.Empty);
    }

    public void SetPanelOpen(bool isOpen)
    {
        _panelOpen = isOpen;
        UserActivity();
        ReturnToBaseState();
    }

    public void ReminderStarted()
    {
        _reminderActive = true;
        UserActivity();
        SetState(PetState.Reminding);
    }

    public void ReminderAcknowledged()
    {
        _reminderActive = false;
        UserActivity();
        ReturnToBaseState();
    }

    public void TodoCompleted()
    {
        UserActivity();
        SetTemporaryState(PetState.Celebrating, TimeSpan.FromSeconds(2));
    }

    public void SaveFailed()
    {
        UserActivity();
        SetTemporaryState(PetState.Surprised, TimeSpan.FromSeconds(1.8));
    }

    private void SetTemporaryState(PetState state, TimeSpan duration)
    {
        _temporaryTimer.Stop();
        SetState(state);
        _temporaryTimer.Interval = duration;
        _temporaryTimer.Start();
    }

    private void ReturnToBaseState()
    {
        if (_reminderActive)
        {
            SetState(PetState.Reminding);
        }
        else if (_panelOpen)
        {
            SetState(PetState.Thinking);
        }
        else
        {
            SetState(PetState.Idle);
        }
    }

    private void ScheduleSleepTimer()
    {
        _sleepTimer.Stop();
        if (_settingsStore.IdleToSleepDuration <= TimeSpan.Zero)
        {
            return;
        }

        _sleepTimer.Interval = _settingsStore.IdleToSleepDuration;
        _sleepTimer.Start();
    }

    private void EnterSleep()
    {
        if (_panelOpen || _reminderActive)
        {
            ScheduleSleepTimer();
            return;
        }

        _temporaryTimer.Stop();
        SetState(PetState.Sleeping);
        SleepStarted?.Invoke();
    }

    private void SetState(PetState state)
    {
        State = state;
        Changed?.Invoke(this, EventArgs.Empty);
    }
}
