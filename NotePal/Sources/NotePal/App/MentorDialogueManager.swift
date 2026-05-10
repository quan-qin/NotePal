import Foundation

@MainActor
final class MentorDialogueManager {
    private let themeProvider: () -> PetTheme
    private let onDialogue: (String) -> Void
    private var timer: Timer?
    private var lastPhrase: String?

    init(
        themeProvider: @escaping () -> PetTheme,
        onDialogue: @escaping (String) -> Void
    ) {
        self.themeProvider = themeProvider
        self.onDialogue = onDialogue
    }

    func start() {
        stop()
        scheduleNextDialogue()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func randomPhrase() -> String {
        let theme = themeProvider()
        let phrases = Self.phrases(for: theme)
        let candidates = phrases.filter { $0 != lastPhrase }
        let phrase = candidates.randomElement() ?? phrases.randomElement() ?? theme.defaultGreeting
        lastPhrase = phrase
        return phrase
    }

    private func scheduleNextDialogue() {
        let interval = TimeInterval.random(in: 600...1_800)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else {
                    return
                }

                self.onDialogue(self.randomPhrase())
                self.scheduleNextDialogue()
            }
        }
        timer.tolerance = 30
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private static func phrases(for theme: PetTheme) -> [String] {
        switch theme {
        case .newton:
            return newtonPhrases
        case .confucius:
            return confuciusPhrases
        case .specialA:
            return specialAPhrases
        case .specialB:
            return specialBPhrases
        }
    }

    private static let newtonPhrases = [
        "若我看得更远，是因为站在巨人的肩上。",
        "自然的法则写在数学之中。",
        "F = ma：力让运动改变。",
        "万有引力把苹果和月亮连在一起。",
        "每一个作用，都有一个相等且相反的反作用。",
        "惯性让物体保持原来的状态。",
        "微积分关心变化本身。",
        "Δv/Δt 指向加速度的秘密。",
        "不要猜测，先看证据。",
        "把复杂问题拆成可计算的部分。",
        "光穿过棱镜，也会说出自己的颜色。",
        "耐心是发现的另一半。",
        "真理常藏在简单规律里。",
        "先定义清楚，再开始推导。",
        "Gm₁m₂/r²，距离改变吸引。",
        "没有测量，结论只是想象。",
        "让公式为现象负责。",
        "从一颗苹果想到整片天空。",
        "速度改变，力就留下痕迹。",
        "圆轨道背后也有向心的理由。",
        "微小变化，累积成大规律。",
        "观察要细，判断要慢。",
        "数学是自然哲学的骨架。",
        "别怕空白，把第一步写下来。",
        "简洁的假设，接受严格的检验。",
        "把误差也记录下来。",
        "时间流动，运动留下方程。",
        "斜率告诉你变化的方向。",
        "面积也能回答累积的问题。",
        "先做实验，再修正模型。",
        "今天的疑问，是明天的定律雏形。",
        "保持谦逊，规律比我们更大。"
    ]

    private static let confuciusPhrases = [
        "学而时习之，不亦说乎。",
        "温故而知新。",
        "三人行，必有我师。",
        "己所不欲，勿施于人。",
        "君子和而不同。",
        "知之为知之，不知为不知。",
        "学而不思则罔，思而不学则殆。",
        "见贤思齐焉。",
        "过而不改，是谓过矣。",
        "君子坦荡荡。",
        "巧言令色，鲜矣仁。",
        "人无远虑，必有近忧。",
        "不患人之不己知，患不知人也。",
        "君子喻于义。",
        "仁者爱人。",
        "敏而好学，不耻下问。",
        "言必信，行必果。",
        "德不孤，必有邻。",
        "欲速则不达。",
        "工欲善其事，必先利其器。",
        "岁寒，然后知松柏之后凋也。",
        "其身正，不令而行。",
        "听其言而观其行。",
        "不迁怒，不贰过。",
        "朝闻道，夕死可矣。",
        "礼之用，和为贵。",
        "有教无类。",
        "学如不及，犹恐失之。",
        "君子求诸己。",
        "慎终追远，民德归厚矣。"
    ]

    private static let specialAPhrases = [
        "先喝口水，再继续。",
        "最近进展如何？",
        "先把思路写清楚。",
        "休息一下眼睛，再继续。",
        "今天的小目标是什么？",
        "把关键结果记下来。",
        "慢一点也没关系。",
        "完成一步，也是一种推进。"
    ]

    private static let specialBPhrases = [
        "先喝口水，再继续。",
        "最近进展如何？",
        "先把思路写清楚。",
        "休息一下眼睛，再继续。",
        "今天的小目标是什么？",
        "把关键结果记下来。",
        "慢一点也没关系。",
        "完成一步，也是一种推进。"
    ]
}
