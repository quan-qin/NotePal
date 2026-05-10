namespace NotePalWindows.Models;

public sealed class AppSettings
{
    public bool AnimationsEnabled { get; set; } = true;
    public bool ReducedMotionMode { get; set; }
    public bool MuteNonCriticalDialogue { get; set; }
    public double IdleToSleepSeconds { get; set; } = 300;
    public double ReminderBubbleSeconds { get; set; } = 8;
    public double GeneralBubbleSeconds { get; set; } = 4;
    public double PetSize { get; set; } = 96;
    public PetTheme SelectedPetTheme { get; set; } = PetTheme.Newton;
    public HashSet<PetTheme> UnlockedSpecialThemes { get; set; } = [];
}
