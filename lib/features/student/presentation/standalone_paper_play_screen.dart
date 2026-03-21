/**
 * WHAT:
 * StandalonePaperPlayScreen runs the student-facing standalone Test and Exam
 * delivery flow.
 * WHY:
 * Standalone papers need timed, one-question-at-a-time delivery with autosave,
 * leave-page integrity checks, and manual or automatic submission without
 * touching the mission player.
 * HOW:
 * Start or resume the student's paper session from the backend, render one
 * item at a time, autosave responses, heartbeat the server, and react to
 * timer expiry or integrity locks in real time.
 */
// ignore_for_file: dangling_library_doc_comments, slash_for_doc_comments

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_palette.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/focus_mission_api.dart';
import '../../../shared/models/focus_mission_models.dart';
import '../../../shared/widgets/focus_scaffold.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/soft_panel.dart';
import 'standalone_paper_focus_monitor_stub.dart'
    if (dart.library.html) 'standalone_paper_focus_monitor_web.dart';
import 'student_result_report_screen.dart';

class StandalonePaperPlayScreen extends StatefulWidget {
  const StandalonePaperPlayScreen({
    super.key,
    required this.session,
    required this.paperId,
    this.initialAvailability,
    this.api,
  });

  final AuthSession session;
  final String paperId;
  final StandalonePaperAvailability? initialAvailability;
  final FocusMissionApi? api;

  @override
  State<StandalonePaperPlayScreen> createState() =>
      _StandalonePaperPlayScreenState();
}

class _StandalonePaperPlayScreenState extends State<StandalonePaperPlayScreen>
    with WidgetsBindingObserver {
  static const Duration _heartbeatInterval = Duration(seconds: 8);
  static const Duration _integrityEventCooldown = Duration(seconds: 2);
  static const Duration _textAutosaveDelay = Duration(milliseconds: 700);

  late final FocusMissionApi _api;
  late final StandalonePaperFocusMonitor _focusMonitor;

  StandalonePaperPlayerPaper? _paper;
  StandalonePaperSessionState? _sessionState;
  final Map<int, TextEditingController> _textControllers =
      <int, TextEditingController>{};
  final Map<int, Timer> _textAutosaveTimers = <int, Timer>{};
  final Map<String, DateTime> _recentIntegrityEvents = <String, DateTime>{};
  Timer? _heartbeatTimer;
  Timer? _countdownTimer;
  DateTime _clockTick = DateTime.now();

  int _currentIndex = 0;
  bool _showUnitText = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isIntegrityRequestRunning = false;
  bool _isSyncingSession = false;
  bool _immersiveModeEnabled = false;
  bool _awaitingBeginConsent = false;
  String? _errorMessage;
  String _sessionMessage = '';

  StandalonePaperPlayerPaper get _paperOrThrow => _paper!;
  StandalonePaperSessionState get _sessionOrThrow => _sessionState!;

  bool get _hasLoadedPaper => _paper != null && _sessionState != null;
  bool get _isExam => _paper?.isExam == true;
  bool get _isSessionActive => _sessionState?.isActive == true;
  bool get _isSessionLocked => _sessionState?.isLocked == true;
  bool get _isSessionSubmitted => _sessionState?.isSubmitted == true;
  int get _totalItems => _paper?.items.length ?? 0;
  bool get _isLastItem => _currentIndex >= _totalItems - 1;
  double get _progressValue =>
      _totalItems <= 0 ? 0 : (_currentIndex + 1) / _totalItems;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? FocusMissionApi();
    _focusMonitor = createStandalonePaperFocusMonitor();
    WidgetsBinding.instance.addObserver(this);
    if (_shouldShowBeforeBeginGate(widget.initialAvailability)) {
      _awaitingBeginConsent = true;
      _isLoading = false;
    } else {
      _startOrResumePaper();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRuntimeMonitors();
    _restoreSystemUiMode();
    for (final timer in _textAutosaveTimers.values) {
      timer.cancel();
    }
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isSessionActive) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // WHY: Tests and exams only should audit when the app loses foreground,
      // because the server decides whether the paper warns or locks.
      _recordIntegrityEvent('app_backgrounded', detail: state.name);
    }
  }

  Future<void> _startOrResumePaper() async {
    setState(() {
      _isLoading = true;
      _awaitingBeginConsent = false;
      _errorMessage = null;
    });

    try {
      final started = await _api.startStandalonePaperSession(
        token: widget.session.token,
        studentId: widget.session.user.id,
        paperId: widget.paperId,
      );

      if (!mounted) {
        return;
      }

      _applyStartedSession(started);
      setState(() => _isLoading = false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _applyStartedSession(StartedStandalonePaperSession started) {
    _paper = started.paper;
    _sessionState = started.session;
    _sessionMessage = started.message.trim();
    _syncControllersFromSession();
    _currentIndex = _safeItemIndex(started.session.currentItemIndex);
    _updateRuntimeMonitors();
    if (_sessionMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _sessionMessage.isEmpty) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_sessionMessage)));
        _sessionMessage = '';
      });
    }
  }

  void _syncControllersFromSession() {
    final session = _sessionState;
    if (session == null) {
      return;
    }
    final expectedIndexes = <int>{};
    for (final response in session.responses) {
      final itemType = response.itemType.trim().toUpperCase();
      if (itemType == 'OBJECTIVE') {
        continue;
      }
      expectedIndexes.add(response.itemIndex);
      _textControllers.putIfAbsent(
        response.itemIndex,
        () => TextEditingController(text: response.textAnswer),
      );
      final controller = _textControllers[response.itemIndex]!;
      if (controller.text != response.textAnswer) {
        controller.text = response.textAnswer;
      }
    }

    final staleIndexes = _textControllers.keys
        .where((index) => !expectedIndexes.contains(index))
        .toList(growable: false);
    for (final index in staleIndexes) {
      _textAutosaveTimers.remove(index)?.cancel();
      _textControllers.remove(index)?.dispose();
    }
  }

  void _updateRuntimeMonitors() {
    _stopRuntimeMonitors();
    if (!_isSessionActive) {
      _restoreSystemUiMode();
      return;
    }

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _sendHeartbeat();
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _clockTick = DateTime.now());
      if (_secondsRemaining == 0) {
        _refreshSessionFromServer();
      }
    });
    _focusMonitor.start(
      onTabHidden: () => _recordIntegrityEvent('tab_hidden'),
      onWindowBlur: () => _recordIntegrityEvent('window_blur'),
      onFullscreenExit: () {
        if (_isExam) {
          _recordIntegrityEvent('fullscreen_exit');
        }
      },
    );

    if (_isExam) {
      _enableSystemUiMode();
    } else {
      _restoreSystemUiMode();
    }
  }

  void _stopRuntimeMonitors() {
    _heartbeatTimer?.cancel();
    _countdownTimer?.cancel();
    _heartbeatTimer = null;
    _countdownTimer = null;
    _focusMonitor.dispose();
  }

  Future<void> _enableSystemUiMode() async {
    if (_immersiveModeEnabled) {
      return;
    }
    _immersiveModeEnabled = true;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _restoreSystemUiMode() async {
    if (!_immersiveModeEnabled) {
      return;
    }
    _immersiveModeEnabled = false;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _sendHeartbeat() async {
    final session = _sessionState;
    if (session == null || !_isSessionActive || session.id.trim().isEmpty) {
      return;
    }

    try {
      final started = await _api.recordStandalonePaperHeartbeat(
        token: widget.session.token,
        studentId: widget.session.user.id,
        sessionId: session.id,
      );
      if (!mounted) {
        return;
      }
      setState(() => _applyStartedSession(started));
    } catch (_) {
      // WHY: Heartbeat failure should not crash the sitting UI. The next save
      // or refresh will reconcile with the backend if the network blips.
    }
  }

  Future<void> _refreshSessionFromServer() async {
    final session = _sessionState;
    if (session == null || session.id.trim().isEmpty || _isSyncingSession) {
      return;
    }

    _isSyncingSession = true;
    try {
      final started = await _api.getStandalonePaperSession(
        token: widget.session.token,
        studentId: widget.session.user.id,
        sessionId: session.id,
      );
      if (!mounted) {
        return;
      }
      setState(() => _applyStartedSession(started));
    } catch (_) {
      // WHY: The runner keeps the local answer state visible during transient
      // refresh failures so the student does not lose confidence mid-paper.
    } finally {
      _isSyncingSession = false;
    }
  }

  Future<void> _recordIntegrityEvent(
    String eventType, {
    String detail = '',
  }) async {
    final session = _sessionState;
    if (session == null ||
        session.id.trim().isEmpty ||
        !_isSessionActive ||
        _isIntegrityRequestRunning) {
      return;
    }

    final lastAt = _recentIntegrityEvents[eventType];
    if (lastAt != null &&
        DateTime.now().difference(lastAt) < _integrityEventCooldown) {
      return;
    }
    _recentIntegrityEvents[eventType] = DateTime.now();
    _isIntegrityRequestRunning = true;

    try {
      final started = await _api.recordStandalonePaperIntegrityEvent(
        token: widget.session.token,
        studentId: widget.session.user.id,
        sessionId: session.id,
        eventType: eventType,
        detail: detail,
      );
      if (!mounted) {
        return;
      }
      setState(() => _applyStartedSession(started));
    } catch (_) {
      // WHY: Integrity reporting is best-effort from the client side. The
      // backend remains the source of truth when the event call succeeds.
    } finally {
      _isIntegrityRequestRunning = false;
    }
  }

  Future<void> _saveObjectiveAnswer(
    int itemIndex,
    int selectedOptionIndex,
  ) async {
    final session = _sessionState;
    if (session == null || !_isSessionActive) {
      return;
    }

    try {
      final started = await _api.saveStandalonePaperSessionProgress(
        token: widget.session.token,
        studentId: widget.session.user.id,
        sessionId: session.id,
        itemIndex: itemIndex,
        selectedOptionIndex: selectedOptionIndex,
        flagged: _responseFor(itemIndex)?.flagged,
        currentItemIndex: _currentIndex,
      );
      if (!mounted) {
        return;
      }
      setState(() => _applyStartedSession(started));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _scheduleTextAutosave(int itemIndex) {
    if (!_isSessionActive) {
      return;
    }

    _textAutosaveTimers[itemIndex]?.cancel();
    _textAutosaveTimers[itemIndex] = Timer(_textAutosaveDelay, () {
      _saveTextAnswer(itemIndex);
    });
  }

  Future<void> _saveTextAnswer(int itemIndex) async {
    final session = _sessionState;
    final controller = _textControllers[itemIndex];
    if (session == null ||
        controller == null ||
        !_isSessionActive ||
        session.id.trim().isEmpty) {
      return;
    }

    try {
      final started = await _api.saveStandalonePaperSessionProgress(
        token: widget.session.token,
        studentId: widget.session.user.id,
        sessionId: session.id,
        itemIndex: itemIndex,
        textAnswer: controller.text,
        flagged: _responseFor(itemIndex)?.flagged,
        currentItemIndex: _currentIndex,
      );
      if (!mounted) {
        return;
      }
      setState(() => _applyStartedSession(started));
    } catch (_) {}
  }

  Future<void> _toggleFlag(int itemIndex) async {
    final session = _sessionState;
    if (session == null || !_isSessionActive) {
      return;
    }
    final response = _responseFor(itemIndex);
    if (response == null) {
      return;
    }

    final itemType = _paperOrThrow.items[itemIndex].itemType
        .trim()
        .toUpperCase();
    try {
      final started = await _api.saveStandalonePaperSessionProgress(
        token: widget.session.token,
        studentId: widget.session.user.id,
        sessionId: session.id,
        itemIndex: itemIndex,
        selectedOptionIndex: itemType == 'OBJECTIVE'
            ? response.selectedOptionIndex
            : null,
        textAnswer: itemType == 'OBJECTIVE'
            ? null
            : _textControllers[itemIndex]?.text ?? response.textAnswer,
        flagged: !response.flagged,
        currentItemIndex: _currentIndex,
      );
      if (!mounted) {
        return;
      }
      setState(() => _applyStartedSession(started));
    } catch (_) {}
  }

  Future<void> _goToItem(int nextIndex) async {
    final clampedIndex = _safeItemIndex(nextIndex);
    if (clampedIndex == _currentIndex || !_hasLoadedPaper) {
      setState(() => _currentIndex = clampedIndex);
      return;
    }

    final currentItem = _paperOrThrow.items[_currentIndex];
    if (currentItem.itemType.trim().toUpperCase() != 'OBJECTIVE') {
      await _saveTextAnswer(_currentIndex);
    }

    setState(() => _currentIndex = clampedIndex);
    if (_isSessionActive) {
      final session = _sessionState;
      if (session != null) {
        try {
          final started = await _api.saveStandalonePaperSessionProgress(
            token: widget.session.token,
            studentId: widget.session.user.id,
            sessionId: session.id,
            itemIndex: clampedIndex,
            textAnswer:
                _paperOrThrow.items[clampedIndex].itemType
                        .trim()
                        .toUpperCase() ==
                    'OBJECTIVE'
                ? null
                : _textControllers[clampedIndex]?.text ??
                      _responseFor(clampedIndex)?.textAnswer,
            selectedOptionIndex:
                _paperOrThrow.items[clampedIndex].itemType
                        .trim()
                        .toUpperCase() ==
                    'OBJECTIVE'
                ? _responseFor(clampedIndex)?.selectedOptionIndex
                : null,
            flagged: _responseFor(clampedIndex)?.flagged,
            currentItemIndex: clampedIndex,
          );
          if (!mounted) {
            return;
          }
          setState(() => _applyStartedSession(started));
        } catch (_) {}
      }
    }
  }

  Future<void> _submitPaper() async {
    final session = _sessionState;
    final paper = _paper;
    if (session == null || paper == null || _isSubmitting) {
      return;
    }

    if (paper.items[_currentIndex].itemType.trim().toUpperCase() !=
        'OBJECTIVE') {
      await _saveTextAnswer(_currentIndex);
    }
    if (!mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Submit ${paper.isExam ? 'Exam' : 'Test'}'),
          content: Text(
            'Your answers will be locked when you submit. You can still come back to view the result later.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep working'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit now'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final started = await _api.submitStandalonePaperSession(
        token: widget.session.token,
        studentId: widget.session.user.id,
        sessionId: session.id,
      );
      if (!mounted) {
        return;
      }
      setState(() => _applyStartedSession(started));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openResult() async {
    final resultPackageId = _sessionState?.resultPackageId.trim() ?? '';
    if (resultPackageId.isEmpty) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StudentResultReportScreen(
          session: widget.session,
          resultPackageId: resultPackageId,
          api: _api,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _refreshSessionFromServer();
  }

  int _safeItemIndex(int index) {
    if (_totalItems <= 0) {
      return 0;
    }
    if (index < 0) {
      return 0;
    }
    if (index >= _totalItems) {
      return _totalItems - 1;
    }
    return index;
  }

  StandalonePaperSessionResponse? _responseFor(int itemIndex) {
    final responses =
        _sessionState?.responses ?? const <StandalonePaperSessionResponse>[];
    for (final response in responses) {
      if (response.itemIndex == itemIndex) {
        return response;
      }
    }
    return null;
  }

  int? get _secondsRemaining {
    final endsAt = _sessionState?.endsAt;
    if (endsAt == null || endsAt.trim().isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(endsAt);
    if (parsed == null) {
      return null;
    }
    return parsed.difference(_clockTick).inSeconds.clamp(0, 1 << 31);
  }

  bool _shouldShowBeforeBeginGate(StandalonePaperAvailability? availability) {
    if (availability == null) {
      return false;
    }
    final latestSession = availability.latestSession;
    if (latestSession == null) {
      return true;
    }
    return latestSession.status.trim().toLowerCase() == 'reset_by_teacher';
  }

  Future<bool> _handleBackNavigation() async {
    if (!_isSessionActive) {
      return true;
    }
    await _recordIntegrityEvent('back_navigation_attempt');
    if (!mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isExam
              ? 'Leaving this exam is locked. Stay on the paper or ask your teacher to reopen it later.'
              : 'Leaving this test is logged. Stay on the paper or submit when you are done.',
        ),
      ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSessionActive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handleBackNavigation();
      },
      child: FocusScaffold(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _awaitingBeginConsent &&
                  widget.initialAvailability != null &&
                  !_hasLoadedPaper
            ? _StandaloneBeforeBeginShell(
                paper: widget.initialAvailability!,
                onBack: () => Navigator.of(context).pop(),
                onBegin: _startOrResumePaper,
              )
            : _errorMessage != null
            ? _StandalonePaperErrorState(
                message: _errorMessage!,
                onBack: () => Navigator.of(context).pop(),
                onRetry: _startOrResumePaper,
              )
            : !_hasLoadedPaper
            ? _StandalonePaperErrorState(
                message: 'This paper could not be loaded.',
                onBack: () => Navigator.of(context).pop(),
                onRetry: _startOrResumePaper,
              )
            : _buildLoadedState(context),
      ),
    );
  }

  Widget _buildLoadedState(BuildContext context) {
    final paper = _paperOrThrow;
    final session = _sessionOrThrow;
    final item = paper.items[_currentIndex];
    final response = _responseFor(_currentIndex);

    if (_isSessionLocked) {
      return _StandalonePaperStatusShell(
        title: '${paper.isExam ? 'Exam' : 'Test'} locked',
        subtitle:
            'This ${paper.isExam ? 'exam' : 'test'} was locked after the focus rules were broken. Ask your teacher to reset it before trying again.',
        primaryLabel: 'Back to dashboard',
        onPrimary: () => Navigator.of(context).pop(),
        secondaryLabel: session.resultPackageId.trim().isEmpty
            ? null
            : 'Open result',
        onSecondary: session.resultPackageId.trim().isEmpty
            ? null
            : _openResult,
        pills: <String>[
          paper.subject?.name ?? 'Subject',
          _paperKindLabel(paper),
          'Leaves ${session.leaveCount}',
        ],
      );
    }

    if (_isSessionSubmitted) {
      final reviewStatus = session.reviewStatus.trim().isEmpty
          ? 'submitted'
          : session.reviewStatus;
      return _StandalonePaperStatusShell(
        title: _secondsRemaining == 0 && session.status == 'time_expired'
            ? 'Time is up'
            : '${paper.isExam ? 'Exam' : 'Test'} submitted',
        subtitle: session.status == 'time_expired'
            ? 'Time expired, so your answers were submitted automatically and are now locked.'
            : 'Your answers are submitted. You can open the result now and come back later if theory review is still pending.',
        primaryLabel: session.resultPackageId.trim().isEmpty
            ? 'Back to dashboard'
            : 'Open result',
        onPrimary: session.resultPackageId.trim().isEmpty
            ? () => Navigator.of(context).pop()
            : _openResult,
        secondaryLabel: session.resultPackageId.trim().isEmpty
            ? null
            : 'Back to dashboard',
        onSecondary: session.resultPackageId.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop(),
        pills: <String>[
          paper.subject?.name ?? 'Subject',
          _paperKindLabel(paper),
          _reviewStatusLabel(reviewStatus),
        ],
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _handleBackNavigation(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paper.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${paper.subject?.name ?? 'Subject'} · ${_paperKindLabel(paper)} · Question ${_currentIndex + 1} of ${paper.items.length}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.item),
            SoftPanel(
              colors: paper.isExam
                  ? const [Color(0xFFFFFBF3), Color(0xFFFFF0D8)]
                  : const [Color(0xFFF4FBFF), Color(0xFFE8F6FF)],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _StandalonePaperPill(label: _paperKindLabel(paper)),
                      _StandalonePaperPill(
                        label: _sessionTypeLabel(paper.sessionType),
                      ),
                      _StandalonePaperPill(
                        label: _secondsRemaining == null
                            ? 'No timer'
                            : 'Time left ${_formatCountdown(_secondsRemaining!)}',
                      ),
                      _StandalonePaperPill(
                        label:
                            'Answered ${session.answeredCount}/${session.totalItems}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _progressValue,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: Colors.white.withValues(alpha: 0.72),
                  ),
                  if (_sessionMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: paper.isExam
                            ? const Color(0xFFFFF4E1)
                            : const Color(0xFFEAF3FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(_sessionMessage),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.item),
            if (paper.sourceUnitText.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.item),
                child: SoftPanel(
                  colors: const [Color(0xFFFFFFFF), Color(0xFFF5F9FF)],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Unit text',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _showUnitText = !_showUnitText),
                            child: Text(
                              _showUnitText ? 'Hide text' : 'Show text',
                            ),
                          ),
                        ],
                      ),
                      if (_showUnitText) ...[
                        const SizedBox(height: 8),
                        Text(
                          paper.sourceUnitText,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            SoftPanel(
              colors: const [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${_currentIndex + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  if (item.learningText.trim().isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF7FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        item.learningText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    item.prompt,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.item),
                  if (item.itemType.trim().toUpperCase() == 'OBJECTIVE')
                    ...item.options.asMap().entries.map((entry) {
                      final optionIndex = entry.key;
                      final selected =
                          response?.selectedOptionIndex == optionIndex;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () =>
                              _saveObjectiveAnswer(_currentIndex, optionIndex),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFEAF3FF)
                                  : Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? AppPalette.primaryBlue
                                    : const Color(0xFFDCE7F8),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppPalette.primaryBlue
                                        : const Color(0xFFEAF2FF),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Center(
                                    child: Text(
                                      String.fromCharCode(65 + optionIndex),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: selected
                                                ? Colors.white
                                                : AppPalette.navy,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    })
                  else ...[
                    TextFormField(
                      controller: _textControllers.putIfAbsent(
                        _currentIndex,
                        () => TextEditingController(
                          text: response?.textAnswer ?? '',
                        ),
                      ),
                      minLines: item.itemType.trim().toUpperCase() == 'THEORY'
                          ? 8
                          : 3,
                      maxLines: item.itemType.trim().toUpperCase() == 'THEORY'
                          ? 12
                          : 4,
                      decoration: InputDecoration(
                        labelText:
                            item.itemType.trim().toUpperCase() == 'THEORY'
                            ? 'Write your answer'
                            : 'Fill the gap answer',
                      ),
                      onChanged: (_) => _scheduleTextAutosave(_currentIndex),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _StandalonePaperPill(
                          label:
                              'Words ${(_textControllers[_currentIndex]?.text.trim().isEmpty ?? true) ? 0 : _textControllers[_currentIndex]!.text.trim().split(RegExp(r"\\s+")).where((word) => word.trim().isNotEmpty).length}',
                        ),
                        if (item.itemType.trim().toUpperCase() == 'THEORY')
                          _StandalonePaperPill(
                            label: 'Minimum ${item.minWordCount}',
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _toggleFlag(_currentIndex),
                    icon: Icon(
                      response?.flagged == true
                          ? Icons.flag_rounded
                          : Icons.outlined_flag_rounded,
                    ),
                    label: Text(
                      response?.flagged == true
                          ? 'Question flagged'
                          : 'Flag question',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.item),
            SoftPanel(
              colors: const [Color(0xFFF7FBFF), Color(0xFFEAF5FF)],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question navigator',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List<Widget>.generate(_totalItems, (index) {
                      final itemResponse = _responseFor(index);
                      final answered = itemResponse == null
                          ? false
                          : itemResponse.itemType.trim().toUpperCase() ==
                                'OBJECTIVE'
                          ? itemResponse.selectedOptionIndex >= 0
                          : itemResponse.textAnswer.trim().isNotEmpty;
                      final flagged = itemResponse?.flagged == true;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _goToItem(index),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: index == _currentIndex
                                ? AppPalette.primaryBlue
                                : answered
                                ? const Color(0xFFE8FFF0)
                                : Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: flagged
                                  ? const Color(0xFFE58E3F)
                                  : index == _currentIndex
                                  ? AppPalette.primaryBlue
                                  : const Color(0xFFDCE7F8),
                              width: flagged ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: index == _currentIndex
                                        ? Colors.white
                                        : AppPalette.navy,
                                  ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.item),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _currentIndex == 0
                        ? null
                        : () => _goToItem(_currentIndex - 1),
                    child: const Text('Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GradientButton(
                    label: _isSubmitting
                        ? 'Submitting...'
                        : _isLastItem
                        ? 'Submit ${paper.isExam ? 'Exam' : 'Test'}'
                        : 'Next question',
                    colors: paper.isExam
                        ? const [Color(0xFFF0B45D), Color(0xFFE58E3F)]
                        : AppPalette.studentGradient,
                    onPressed: _isSubmitting
                        ? () {}
                        : _isLastItem
                        ? _submitPaper
                        : () => _goToItem(_currentIndex + 1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StandalonePaperStatusShell extends StatelessWidget {
  const _StandalonePaperStatusShell({
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onPrimary,
    required this.pills,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String subtitle;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final List<String> pills;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: SoftPanel(
              colors: const [Color(0xFFFFFFFF), Color(0xFFF5FAFF)],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: pills
                        .map((pill) => _StandalonePaperPill(label: pill))
                        .toList(growable: false),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  GradientButton(
                    label: primaryLabel,
                    colors: AppPalette.studentGradient,
                    onPressed: onPrimary,
                  ),
                  if ((secondaryLabel ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: onSecondary,
                      child: Text(secondaryLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StandaloneBeforeBeginShell extends StatelessWidget {
  const _StandaloneBeforeBeginShell({
    required this.paper,
    required this.onBack,
    required this.onBegin,
  });

  final StandalonePaperAvailability paper;
  final VoidCallback onBack;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final isExam = paper.isExam;
    final timerLabel = paper.durationMinutes > 0
        ? '${paper.durationMinutes} minute timer'
        : 'No timer set';
    final rules = isExam
        ? <String>[
            'Do not leave this page or switch apps after you begin.',
            'If a timer is set, it keeps running until the exam ends.',
            'Leaving the page or app locks the exam immediately.',
            'Keep fullscreen on where possible during the exam.',
          ]
        : <String>[
            'Do not leave this page after you begin.',
            'If a timer is set, it keeps running until the test ends.',
            'Leaving once gives a warning.',
            'Leaving a second time locks the test.',
          ];

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screen),
            child: SoftPanel(
              colors: isExam
                  ? const [Color(0xFFFFFBF3), Color(0xFFFFF0D8)]
                  : const [Color(0xFFF4FBFF), Color(0xFFE8F7FF)],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Before you begin',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    paper.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Read the rules before starting this ${isExam ? 'exam' : 'test'}. Once you press begin, the session starts for real.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppPalette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.item),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _StandalonePaperPill(
                        label: isExam ? 'Exam mode' : 'Test mode',
                      ),
                      _StandalonePaperPill(
                        label: paper.subject?.name ?? 'Subject',
                      ),
                      _StandalonePaperPill(
                        label: _sessionTypeLabel(paper.sessionType),
                      ),
                      _StandalonePaperPill(label: timerLabel),
                    ],
                  ),
                  if (paper.teacherNote.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.item),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        paper.teacherNote,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.navy,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.section),
                  ...rules.map(
                    (rule) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_circle_outline_rounded,
                              size: 20,
                              color: AppPalette.navy,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rule,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: onBack,
                        child: const Text('Back'),
                      ),
                      GradientButton(
                        label: 'I understand, begin',
                        colors: isExam
                            ? const [Color(0xFFF0B45D), Color(0xFFE58E3F)]
                            : AppPalette.studentGradient,
                        onPressed: onBegin,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StandalonePaperErrorState extends StatelessWidget {
  const _StandalonePaperErrorState({
    required this.message,
    required this.onBack,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screen),
          child: SoftPanel(
            colors: const [Color(0xFFFFFBF5), Color(0xFFFFF0E1)],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paper unavailable',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(message),
                const SizedBox(height: AppSpacing.item),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: onBack,
                      child: const Text('Back'),
                    ),
                    GradientButton(
                      label: 'Try again',
                      colors: AppPalette.studentGradient,
                      onPressed: onRetry,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StandalonePaperPill extends StatelessWidget {
  const _StandalonePaperPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

String _paperKindLabel(StandalonePaperPlayerPaper paper) =>
    paper.isExam ? 'Exam' : 'Test';

String _sessionTypeLabel(String value) =>
    value.trim().toLowerCase() == 'afternoon' ? 'Afternoon' : 'Morning';

String _reviewStatusLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'pending_review':
      return 'Pending review';
    case 'scored':
      return 'Reviewed';
    default:
      return 'Submitted';
  }
}

String _formatCountdown(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final remainderSeconds = (seconds % 60).toString().padLeft(2, '0');
  return '$minutes:$remainderSeconds';
}
