import Foundation

struct L10n: Equatable, Sendable {
  var language: AppLanguage

  func t(_ zh: String, _ en: String) -> String {
    language == .chinese ? zh : en
  }

  var ok: String { t("好", "OK") }
  var done: String { t("完成", "Done") }
  var cancel: String { t("取消", "Cancel") }
  var close: String { t("关闭", "Close") }
  var save: String { t("保存", "Save") }
  var saving: String { t("保存中…", "Saving…") }
  var remove: String { t("移除", "Remove") }
  var skip: String { t("跳过", "Skip") }
  var continueAction: String { t("继续", "Continue") }
  var tryAgain: String { t("重试", "Try again") }
  var unknownError: String { t("未知错误", "Unknown error") }
  var somethingWentWrong: String { t("出了点问题", "Something went wrong") }
  var loadingCourtVoice: String { t("正在打开 CourtVoice", "Loading CourtVoice") }
  var scoringError: String { t("记分出错", "Scoring error") }

  var tabHome: String { t("主页", "Home") }
  var tabMatches: String { t("比赛", "Matches") }
  var tabSettings: String { t("设置", "Settings") }

  var onboardingSkip: String { skip }
  var onboardingContinue: String { continueAction }
  var onboardingStart: String { t("开始使用 CourtVoice", "Start using CourtVoice") }
  var onboardingTitle1: String { t("像场边一样自然报分", "Call the score naturally") }
  var onboardingDetail1: String {
    t(
      "开赛后交给语音智能体记分。CourtVoice 只在比赛进行时聆听。",
      "Start a match, then let the voice agent keep score. CourtVoice listens only while the match is active."
    )
  }
  var onboardingTitle2: String { t("规则先于 AI", "Rules before AI") }
  var onboardingDetail2: String {
    t(
      "语音和大模型只提出意图。只有确定性网球规则引擎能改官方比分。",
      "Speech produces a candidate action. A deterministic tennis rules engine is the only component allowed to change the official score."
    )
  }
  var onboardingTitle3: String { t("底线也能看清", "Readable from the baseline") }
  var onboardingDetail3: String {
    t(
      "场上用大号横屏记分牌，也可以 AirPlay 投屏，赛后分享比赛摘要。",
      "Use the large landscape scoreboard on court, mirror it with AirPlay, or share a match summary afterward."
    )
  }

  var homeHeroTitle: String { t("不打断节奏，也能记分", "Score without breaking your rhythm") }
  var homeHeroDetail: String {
    t(
      "开赛后由语音智能体和规则引擎记分。直播页可看记分牌、转写和模型思考。",
      "Start a match, then let the voice agent and tennis rules engine keep score. Watch the live board, transcript, and model thinking."
    )
  }
  var startMatch: String { t("开始比赛", "Start match") }
  var analyzeRecordedMatch: String { t("分析录制的比赛", "Analyze a recorded match") }
  var analyzeRecordedMatchDetail: String {
    t(
      "导入视频或音频，生成带时间戳、经规则校验的记分草稿。",
      "Import video or audio and build a timestamped, rules-checked score draft."
    )
  }
  var privateByDefault: String { t("默认本地私密", "Private by default") }
  var privateByDefaultDetail: String {
    t(
      "比赛历史留在本机。记分流程不会保存原始麦克风音频。",
      "Match history stays on this device. Raw microphone audio is not stored by the scoring workflow."
    )
  }

  var matchStatusNotStarted: String { t("未开始", "Not started") }
  var matchStatusInProgress: String { t("进行中", "In progress") }
  var matchStatusPaused: String { t("已暂停", "Paused") }
  var matchStatusCompleted: String { t("已结束", "Completed") }
  var matchStatusAgentScoring: String { t("智能体记分中", "Agent scoring") }

  func winner(_ name: String) -> String {
    t("胜者：\(name)", "Winner: \(name)")
  }

  var newMatch: String { t("新比赛", "New match") }
  var players: String { t("选手", "Players") }
  var playerOrTeam1: String { t("选手或队伍 1", "Player or team 1") }
  var playerOrTeam2: String { t("选手或队伍 2", "Player or team 2") }
  var defaultPlayer1: String { t("选手 1", "Player 1") }
  var defaultPlayer2: String { t("选手 2", "Player 2") }
  var discipline: String { t("项目", "Discipline") }
  var singles: String { t("单打", "Singles") }
  var doubles: String { t("双打", "Doubles") }
  var team1Members: String { t("1 队队员，逗号分隔", "Team 1 members, comma-separated") }
  var team2Members: String { t("2 队队员，逗号分隔", "Team 2 members, comma-separated") }
  var matchFormat: String { t("赛制", "Match format") }
  var sets: String { t("盘数", "Sets") }
  var oneSet: String { t("一盘定胜负", "1 set") }
  var bestOf3: String { t("三盘两胜", "Best of 3") }
  var bestOf5: String { t("五盘三胜", "Best of 5") }
  var gameScoring: String { t("局内计分", "Game scoring") }
  var advantage: String { t("占先", "Advantage") }
  var noAd: String { t("无占先", "No-Ad") }
  var decidingTiebreak: String { t("决胜盘 10 分抢七", "10-point match tiebreak in deciding set") }
  var firstServer: String { t("先发球方", "First server") }
  var server: String { t("发球方", "Server") }
  var start: String { t("开始", "Start") }
  var matchSetupHint: String {
    t(
      "开始后由语音智能体驱动记分。只有网球规则引擎能改官方比分。",
      "After you start, the voice agent drives scoring. Only the tennis rules engine can change the official score."
    )
  }

  var liveMatch: String { t("现场比赛", "LIVE MATCH") }
  var closeMatch: String { t("关闭比赛", "Close match") }
  var tennisScoreboard: String { t("网球记分牌", "Tennis scoreboard") }
  var playerColumn: String { t("选手", "PLAYER") }
  var gameColumn: String { t("局", "GAME") }
  var pointColumn: String { t("分", "POINT") }
  var serving: String { t("发球", "Serving") }
  var receiving: String { t("接发", "Receiving") }
  var transcript: String { t("转写", "TRANSCRIPT") }
  var transcriptEmpty: String {
    t("场边报分会显示在这里。", "The agent will transcribe court calls here as they arrive.")
  }
  var transcriptFinal: String { t("确定", "Final") }
  var transcriptLive: String { t("实时", "Live") }
  var pauseAgent: String { t("暂停智能体", "Pause agent") }
  var startVoiceAgent: String { t("启动语音智能体", "Start voice agent") }
  var reasoningEmpty: String {
    t(
      "报分稳定后，这里会显示 DeepSeek 思考。它只能提出意图，官方比分仍由规则引擎决定。",
      "DeepSeek thinking appears here after a final transcript. It can propose an intent; only the rules engine may change the score."
    )
  }

  func speechState(_ state: SpeechSessionState) -> String {
    switch state {
    case .idle:
      t("语音未开", "Voice off")
    case .requestingPermission:
      t("正在请求权限", "Requesting permission")
    case .preparing(let provider):
      t("正在准备 \(provider)", "Preparing \(provider)")
    case .listening(let provider):
      t("正在听 · \(provider)", "Listening · \(provider)")
    case .processing(let provider):
      t("正在处理 · \(provider)", "Processing · \(provider)")
    case .interrupted(let reason):
      t("已中断 · \(reason)", "Interrupted · \(reason)")
    case .failed(let reason):
      t("语音不可用 · \(reason)", "Voice unavailable · \(reason)")
    }
  }

  func reasoningPhase(_ phase: ScoreReasoningPhase) -> String {
    switch phase {
    case .idle: t("模型空闲", "Model idle")
    case .thinking: t("模型思考中", "Model thinking")
    case .answering: t("模型作答中", "Model answering")
    case .complete: t("模型提议", "Model proposal")
    case .failed: t("模型不可用", "Model unavailable")
    }
  }

  func liveAction(_ action: LiveScoreAction) -> String {
    switch action {
    case .matchReady:
      t("比赛已就绪", "Match ready")
    case .matchRestored:
      t("已恢复比赛", "Match restored")
    case .agentScored(let text):
      t("智能体记分：\(text)", "Agent scored: \(text)")
    case .heldUnclear:
      t("先听清再改分。", "Held: the agent needs a clearer call before changing the score.")
    case .held(let reason):
      t("未改分：\(localizedHeldReason(reason))", "Held: \(reason)")
    case .heardCurrent:
      t("听到的是当前比分，无需改分", "Heard the current score; no change")
    case .undone:
      t("已撤销上一分", "Last scoring action undone")
    case .ignored(let reason):
      localizedHeldReason(reason)
    }
  }

  func accessibilityScore(team: String, isServing: Bool, games: Int, points: String) -> String {
    let role = isServing ? serving : receiving
    return t(
      "\(team)，\(role)，\(games) 局，\(points) 分",
      "\(team), \(isServing ? "serving" : "receiving"), \(games) games, \(points) points"
    )
  }

  var noMatchesYet: String { t("还没有比赛", "No matches yet") }
  var noMatchesDetail: String {
    t("本机保存的比赛历史会显示在这里。", "Your locally saved match history will appear here.")
  }
  var resume: String { t("继续", "Resume") }
  var liveBadge: String { t("进行中", "LIVE") }
  var matchDetails: String { t("比赛详情", "Match details") }
  var format: String { t("赛制", "Format") }
  var events: String { t("事件", "Events") }
  var totalPoints: String { t("总得分", "Total points") }
  var started: String { t("开始时间", "Started") }
  var shareMatchJSON: String { t("分享比赛 JSON", "Share match JSON") }
  var prepareMatchExport: String { t("准备导出", "Prepare match export") }
  var exportFailed: String { t("导出失败", "Export failed") }

  func formatDescription(isSingles: Bool, bestOfSets: Int, isAdvantage: Bool) -> String {
    let discipline = isSingles ? singles : doubles
    let scoring = isAdvantage ? advantage : noAd
    return t(
      "\(discipline)，\(bestOfSets) 盘，\(scoring)",
      "\(discipline), best of \(bestOfSets), \(scoring)"
    )
  }

  var settings: String { t("设置", "Settings") }
  var subscription: String { t("订阅", "Subscription") }
  var proActive: String { t("CourtVoice Pro 已开通", "CourtVoice Pro active") }
  var upgradeToPro: String { t("升级 CourtVoice Pro", "Upgrade to CourtVoice Pro") }
  var status: String { t("状态", "Status") }
  var active: String { t("已开通", "Active") }
  var free: String { t("免费", "Free") }
  var scoring: String { t("记分", "Scoring") }
  var speechAndAIModels: String { t("语音与 AI 模型", "Speech & AI models") }
  var defaultMode: String { t("默认模式", "Default mode") }
  var recognitionLanguageLabel: String { t("识别语言", "Language") }
  var appLanguage: String { t("界面语言", "App language") }
  var privacy: String { t("隐私", "Privacy") }
  var privacyAudio: String { t("不保存现场原始音频", "Raw live audio is not saved") }
  var privacyHistory: String { t("比赛历史只留在本机", "Match history stays on device") }
  var privacyKeys: String { t("自带密钥只存在钥匙串", "BYOK credentials stay in Keychain") }
  var about: String { t("关于", "About") }
  var version: String { t("版本", "Version") }
  var sourceRepository: String { t("源码仓库", "Source repository") }

  var speechAndAI: String { t("语音与 AI", "Speech & AI") }
  var voiceMode: String { t("语音模式", "Voice mode") }
  var provider: String { t("提供方", "Provider") }
  var recognitionLanguage: String { t("识别语言", "Recognition language") }
  var automaticAcceptance: String { t("自动落分阈值", "Automatic acceptance") }
  var automaticAcceptanceHint: String {
    t(
      "低于此置信度不会改官方比分。报分说稳并短暂停顿后就会提交，即使识别器还没标成最终结果。",
      "Calls below this confidence do not change the official score. A short pause after a stable call commits it for scoring and model thinking, even if the recognizer has not marked the transcript final."
    )
  }
  var openAIEndpoint: String { t("HTTPS 转写接口", "HTTPS transcription endpoint") }
  var transcriptionModel: String { t("转写模型", "Transcription model") }
  var apiKey: String { t("API 密钥", "API key") }
  func apiKeySavedReplace(_ provider: String) -> String {
    t("\(provider) 密钥已保存，输入即可替换", "API key saved — enter to replace")
  }
  var saveKey: String { t("保存密钥", "Save key") }
  var openAIBYOK: String { t("OpenAI 兼容自带密钥", "OpenAI-compatible BYOK") }
  var openAIBYOKFooter: String {
    t(
      "短语音片段会从本机直接发到你配置的接口。费用由你的账号承担。CourtVoice 不会把密钥写入日志或比赛导出。",
      "Short voice segments are sent directly from this device to the configured endpoint. The provider may bill your own account. CourtVoice never adds the key to logs or match exports."
    )
  }
  var model: String { t("模型", "Model") }
  var languageCodeOrMulti: String { t("语言代码或 multi", "Language code or multi") }
  var deepgramBYOK: String { t("Deepgram 自带密钥", "Deepgram BYOK") }
  var deepgramFooter: String {
    t(
      "智能体聆听时，会把 16 kHz 单声道 PCM 直接推到 Deepgram。暂停或关闭比赛即停止采集。",
      "While the voice agent is listening, 16 kHz mono PCM is streamed directly to Deepgram. Stopping the agent or closing the match stops capture."
    )
  }
  var streamThinking: String { t("在直播记分牌展示思考", "Stream thinking on the live board") }
  var httpsChatEndpoint: String { t("HTTPS 对话接口", "HTTPS chat endpoint") }
  var deepSeekReasoning: String { t("DeepSeek 比分推理", "DeepSeek score reasoning") }
  var deepSeekFooter: String {
    t(
      "DeepSeek 是思考模型，不是转写器。它会在比赛页流式展示推理，并可能提出结构化意图。只有规则引擎能改官方比分。密钥只存在本机钥匙串。",
      "DeepSeek is the live thinking model, not the transcriber. It streams reasoning on the match screen and may propose a structured intent. Only the tennis rules engine can change the official score. The key stays in this device's Keychain."
    )
  }
  var liveAudioNotStored: String {
    t("现场记分流程不会保存原始麦克风音频。", "Raw microphone audio is not stored by the live scoring workflow.")
  }
  var openAIKeySaved: String { t("OpenAI 兼容密钥已写入本机钥匙串。", "OpenAI-compatible key saved in the device-only Keychain.") }
  var deepSeekKeySaved: String { t("DeepSeek 密钥已写入本机钥匙串。", "DeepSeek key saved in the device-only Keychain.") }
  var deepgramKeySaved: String { t("Deepgram 密钥已写入本机钥匙串。", "Deepgram key saved in the device-only Keychain.") }
  var credentialRemoved: String { t("密钥已移除。", "Credential removed.") }
  var invalidOpenAIEndpoint: String {
    t("OpenAI 兼容转写接口必须是有效的 HTTPS 地址。", "The OpenAI-compatible transcription endpoint must be a valid HTTPS URL.")
  }
  var invalidAcceptanceRange: String {
    t("自动落分阈值超出支持范围。", "The automatic-acceptance threshold is outside the supported range.")
  }
  var invalidDeepSeekEndpoint: String {
    t("DeepSeek 接口必须是有效的 HTTPS 地址。", "The DeepSeek endpoint must be a valid HTTPS URL.")
  }

  func providerTitle(_ kind: SpeechProviderKind) -> String {
    switch kind {
    case .automatic: t("自动", "Automatic")
    case .appleOnDevice: t("Apple 端侧", "Apple on-device")
    case .openAICompatible: t("OpenAI 兼容自带密钥", "OpenAI-compatible BYOK")
    case .deepgram: t("Deepgram 自带密钥", "Deepgram BYOK")
    }
  }

  func providerSubtitle(_ kind: SpeechProviderKind) -> String {
    switch kind {
    case .automatic:
      t("优先私密端侧识别，必要时再回退到你配置的个人服务。", "Prefer private on-device recognition, then fall back to a configured personal provider.")
    case .appleOnDevice:
      t("不产生服务商账单，CourtVoice 也不上传原始音频。可用性取决于设备和语言。", "No provider bill and no raw audio uploaded by CourtVoice. Availability depends on device and language.")
    case .openAICompatible:
      t("短语音片段会直接发到你的 HTTPS 转写接口。", "Short voice segments are sent directly to your HTTPS transcription endpoint.")
    case .deepgram:
      t("聆听期间把 16 kHz 单声道音频直接推到 Deepgram。", "16 kHz mono audio is streamed directly to Deepgram while listening is active.")
    }
  }

  var paywallTitle: String { t("CourtVoice Pro", "CourtVoice Pro") }
  var paywallHero: String { t("每块场地都能像正式比赛一样就绪", "Every court can feel match-ready") }
  var paywallHeroDetail: String {
    t(
      "Pro 提供托管云用量、完整导出、无限历史、网页直播记分牌和跨设备服务。开赛和观看直播记分牌无需 Pro。",
      "Pro adds managed cloud usage, complete exports, unlimited history, live web scoreboards and cross-device services. Starting a match and watching the live board remain available without Pro."
    )
  }
  var benefitCloud: String { t("托管云识别额度", "Managed cloud recognition allowance") }
  var benefitHistory: String { t("无限比赛历史与审计导出", "Unlimited match history and audit exports") }
  var benefitWebBoard: String { t("只读网页直播记分牌链接", "Read-only live web scoreboard links") }
  var benefitFallback: String { t("自动切换识别服务", "Automatic provider fallback") }
  var benefitSync: String { t("后续跨设备同步", "Future cross-device synchronization") }
  var bestValue: String { t("最划算", "BEST VALUE") }
  var restorePurchases: String { t("恢复购买", "Restore purchases") }
  var loadingProducts: String { t("正在加载 App Store 商品…", "Loading App Store products…") }
  var proIsActive: String { t("CourtVoice Pro 已开通", "CourtVoice Pro is active") }
  var proVerified: String {
    t("已在本机通过 StoreKit 验证订阅权益。", "Your entitlement was verified from StoreKit on this device.")
  }
  var productsUnavailable: String { t("商品暂不可用", "Products are unavailable") }
  var productsUnavailableDetail: String {
    t(
      "请在 Xcode 使用仓库内的 StoreKit 测试配置，或在 App Store Connect 配置对应商品 ID。",
      "Use the checked-in StoreKit test configuration in Xcode, or configure matching product identifiers in App Store Connect."
    )
  }
  var subscriptionLegal: String {
    t(
      "订阅会自动续期，除非取消。计费、优惠资格和本地化价格由 App Store 控制。",
      "Subscriptions renew automatically unless cancelled. Billing, eligibility for introductory offers and localized prices are controlled by the App Store."
    )
  }
  var terms: String { t("条款", "Terms") }

  var analyzeMatchMedia: String { t("分析比赛录像", "Analyze match media") }
  var createReviewableTimeline: String { t("生成可复核的记分时间线", "Create a reviewable score timeline") }
  var mediaIntro: String {
    t(
      "CourtVoice 会提取音轨、转写带时间戳的报分，并只提交合法分。含糊的句子会留下来供复核。",
      "CourtVoice extracts the audio track, transcribes timestamped score calls, and commits only legal transitions. Ambiguous phrases remain visible for review."
    )
  }
  var matchIdentity: String { t("比赛信息", "Match identity") }
  var mediaProvider: String { t("媒体识别服务", "Media provider") }
  var cancelAnalysis: String { t("取消分析", "Cancel analysis") }
  var chooseVideoOrAudio: String { t("选择视频或音频", "Choose video or audio") }
  var chooseAnotherFile: String { t("另选文件", "Choose another file") }
  var transcriptReview: String { t("转写复核", "Transcript review") }
  func acceptedAndReview(accepted: Int, review: Int) -> String {
    t("\(accepted) 已接受 · \(review) 待复核", "\(accepted) accepted · \(review) review")
  }
  var saveAcceptedTimeline: String { t("保存已接受的时间线", "Save accepted timeline") }
  var timelineSaved: String { t("已接受的记分时间线已保存到比赛历史。", "The accepted score timeline was saved to Match History.") }

  func mediaPhase(_ phase: MediaAnalysisViewModel.Phase) -> String {
    switch phase {
    case .idle: t("就绪", "Ready")
    case .copying: t("正在准备所选媒体", "Preparing selected media")
    case .extractingAudio: t("正在提取音频", "Extracting audio")
    case .transcribing(let provider): t("正在用 \(provider) 转写", "Transcribing with \(provider)")
    case .resolving: t("正在校验网球记分事件", "Validating tennis score events")
    case .complete: t("分析完成", "Analysis complete")
    case .failed: t("分析失败", "Analysis failed")
    }
  }

  func mediaOutcome(_ outcome: MediaAnalysisOutcome) -> String {
    switch outcome {
    case .accepted: t("已接受", "ACCEPTED")
    case .needsReview: t("待复核", "REVIEW")
    case .ignored: t("已忽略", "IGNORED")
    case .rejected: t("已拒绝", "REJECTED")
    }
  }

  private func localizedHeldReason(_ reason: String) -> String {
    switch reason {
    case "The reported score is not a reachable score in the current game.":
      t("当前这一局追不到这个比分。", reason)
    case "The reported score is not a single legal point transition from the current state.":
      t("这不是从当前比分出发的合法下一分。", reason)
    default:
      reason
    }
  }
}
